local component = require("component")
local event = require("event")
local serialization = require("serialization")
local computer = require("computer")
local term = require("term")
local unicode = require("unicode")
local filesystem = require("filesystem")

--------------------------------------------------------------------------------
-- HOLO-NET CONSOLE v3
-- Main control terminal for scanner nodes and projector nodes.
--
-- New in v3:
-- * Friendly projector aliases
-- * Projector groups
-- * Scene groups
-- * Scene -> projector / projector-group bindings
-- * Multiple live profiles
-- * Local preview command for scanner nodes that also have a hologram
--------------------------------------------------------------------------------

local CFG = {
  PORT = 3413,
  MODEM_STRENGTH = 400,
  SCENE_DIR = "/home/holonet_scenes",
  DB_FILE = "/home/holonet_registry.db",
  DISCOVERY_INTERVAL = 12,
  CAPTURE_TIMEOUT = 20,
  PROJECT_BATCH_VOXELS = 32,
  PROJECT_SEND_PAUSE = 0.02,

  DEFAULT_BOX = {x = -24, z = -24, y = -16, w = 48, d = 48, h = 32},
  DEFAULT_MODE = "bands",
  DEFAULT_LIVE_INTERVAL = 5,
}

local modem = component.modem
assert(modem, "No modem found")
modem.open(CFG.PORT)
if modem.isWireless and modem.isWireless() and modem.setStrength then
  pcall(modem.setStrength, CFG.MODEM_STRENGTH)
end

pcall(filesystem.makeDirectory, CFG.SCENE_DIR)
math.randomseed(math.floor(computer.uptime() * 1000) % 2147483647)

local gpu = component.isAvailable("gpu") and component.gpu or nil

local scanners = {}   -- discovered scanner nodes by id
local projectors = {} -- discovered projector nodes by id
local scenes = {}     -- loaded/captured scenes
local pendingByRequest = {}
local selectedScene = 1
local status = "Ready."
local nextDiscovery = 0

local db = {
  projectorMeta = {},    -- id -> {alias=""}
  projectorGroups = {},  -- name -> {"projector-1","projector-2"}
  sceneBindings = {},    -- sceneName -> {projectors={}, groups={}}
  sceneGroups = {},      -- groupName -> {"scene1","scene2"}
  liveProfiles = {},     -- profileName -> {sceneName, mode, scannerTargets, box, interval, autoProject, enabled}
}

local function nowString()
  local ok, value = pcall(os.date, "%Y-%m-%d %H:%M:%S")
  if ok then return value end
  return string.format("uptime %.1fs", computer.uptime())
end

local function trim(s)
  return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function safeName(s, fallback)
  s = trim(s or fallback or "item")
  if s == "" then s = fallback or "item" end
  s = s:gsub("[^%w%-%._ ]", "_")
  return s
end

local function setStatus(text)
  status = tostring(text or "")
end

local function cloneTable(src)
  if type(src) ~= "table" then return src end
  local dst = {}
  for k, v in pairs(src) do
    if type(v) == "table" then
      dst[k] = cloneTable(v)
    else
      dst[k] = v
    end
  end
  return dst
end

local function sortArray(list)
  table.sort(list, function(a, b) return tostring(a) < tostring(b) end)
  return list
end

local function uniqueArray(list)
  local seen, out = {}, {}
  for i = 1, #(list or {}) do
    local v = list[i]
    if v ~= nil and not seen[v] then
      seen[v] = true
      out[#out + 1] = v
    end
  end
  return out
end

local function arrayHas(list, value)
  for i = 1, #(list or {}) do
    if list[i] == value then return true end
  end
  return false
end

local function removeFromArray(list, value)
  local out = {}
  for i = 1, #(list or {}) do
    if list[i] ~= value then out[#out + 1] = list[i] end
  end
  return out
end

local function countIndex(scene)
  local n = 0
  for _ in pairs(scene.index or {}) do n = n + 1 end
  return n
end

local function sendPacketTo(address, kind, payload)
  payload = payload or {}
  local blob = serialization.serialize(payload)
  return modem.send(address, CFG.PORT, "holonet", kind, blob)
end

local function broadcastPacket(kind, payload)
  payload = payload or {}
  local blob = serialization.serialize(payload)
  return modem.broadcast(CFG.PORT, "holonet", kind, blob)
end

local function ask(prompt, default)
  io.write(prompt)
  if default ~= nil then
    io.write(" [" .. tostring(default) .. "]")
  end
  io.write(": ")
  local line = term.read() or ""
  line = trim((line:gsub("\n", "")))
  if line == "" then return default end
  return line
end

local function askYesNo(prompt, defaultYes)
  local suffix = defaultYes and "Y/n" or "y/N"
  local v = trim((ask(prompt .. " (" .. suffix .. ")", defaultYes and "y" or "n") or "")):lower()
  return v == "y" or v == "yes" or v == "1" or v == "true"
end

local function promptBox(default)
  local box = {}
  box.x = tonumber(ask("box x", default.x)) or default.x
  box.z = tonumber(ask("box z", default.z)) or default.z
  box.y = tonumber(ask("box y", default.y)) or default.y
  box.w = tonumber(ask("box w", default.w)) or default.w
  box.d = tonumber(ask("box d", default.d)) or default.d
  box.h = tonumber(ask("box h", default.h)) or default.h
  return box
end

local function ensureDbShape()
  db.projectorMeta = db.projectorMeta or {}
  db.projectorGroups = db.projectorGroups or {}
  db.sceneBindings = db.sceneBindings or {}
  db.sceneGroups = db.sceneGroups or {}
  db.liveProfiles = db.liveProfiles or {}
end

local function saveDb()
  ensureDbShape()
  local payload = cloneTable(db)
  for _, profile in pairs(payload.liveProfiles) do
    profile.inFlight = nil
    profile.nextAt = nil
    profile.requestId = nil
    if profile.enabled == nil then
      profile.enabled = false
    end
  end
  local f, err = io.open(CFG.DB_FILE, "w")
  if not f then
    setStatus("Failed to save registry: " .. tostring(err))
    return false
  end
  f:write(serialization.serialize(payload))
  f:close()
  return true
end

local function loadDb()
  ensureDbShape()
  local f = io.open(CFG.DB_FILE, "r")
  if not f then return end
  local text = f:read("*a")
  f:close()
  local ok, data = pcall(serialization.unserialize, text)
  if ok and type(data) == "table" then
    db = data
    ensureDbShape()
    for _, profile in pairs(db.liveProfiles) do
      profile.enabled = profile.enabled and true or false
      profile.inFlight = false
      profile.nextAt = 0
      profile.requestId = nil
      profile.autoProject = profile.autoProject ~= false
      profile.interval = tonumber(profile.interval) or CFG.DEFAULT_LIVE_INTERVAL
    end
  end
end

local function sceneAt(index)
  if #scenes == 0 then return nil end
  if index < 1 then index = 1 end
  if index > #scenes then index = #scenes end
  selectedScene = index
  return scenes[index]
end

local function findSceneByName(name)
  for i = 1, #scenes do
    if scenes[i].name == name then return scenes[i], i end
  end
  return nil, nil
end

local function ensureScene(name, mode, box)
  local scene, idx = findSceneByName(name)
  if scene then
    scene.mode = mode or scene.mode
    scene.box = box or scene.box
    scene.pending = false
    scene.expected = {}
    scene.done = {}
    scene.requestId = nil
    scene.autoProject = false
    scene.updatedAt = nowString()
    scene.scannerTargets = scene.scannerTargets or {}
    selectedScene = idx
    return scene
  end

  scene = {
    name = safeName(name, "scene"),
    mode = mode or CFG.DEFAULT_MODE,
    box = cloneTable(box or CFG.DEFAULT_BOX),
    index = {},
    pending = false,
    expected = {},
    done = {},
    requestId = nil,
    autoProject = false,
    updatedAt = nowString(),
    scannerTargets = {},
  }
  scenes[#scenes + 1] = scene
  selectedScene = #scenes
  return scene
end

local function packIndex(scene)
  local keys = {}
  for key in pairs(scene.index or {}) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  local flat = {}
  for i = 1, #keys do
    local key = keys[i]
    local x, y, z = key:match("^(-?%d+):(-?%d+):(-?%d+)$")
    flat[#flat + 1] = tonumber(x)
    flat[#flat + 1] = tonumber(y)
    flat[#flat + 1] = tonumber(z)
    flat[#flat + 1] = scene.index[key]
  end
  return flat
end

local function addFlat(scene, flat)
  scene.index = scene.index or {}
  for i = 1, #(flat or {}), 4 do
    local x, y, z, v = flat[i], flat[i + 1], flat[i + 2], flat[i + 3]
    if x ~= nil and y ~= nil and z ~= nil and v ~= nil then
      scene.index[string.format("%d:%d:%d", x, y, z)] = v
    end
  end
  scene.updatedAt = nowString()
end

local function loadSceneByFile(path)
  local f, err = io.open(path, "r")
  if not f then
    setStatus("Load failed: " .. tostring(err))
    return nil
  end
  local text = f:read("*a")
  f:close()
  local ok, data = pcall(serialization.unserialize, text)
  if not ok or type(data) ~= "table" then
    setStatus("Load failed: invalid scene file")
    return nil
  end
  local scene = ensureScene(data.name or filesystem.name(path) or "loaded-scene", data.mode or CFG.DEFAULT_MODE, data.box or CFG.DEFAULT_BOX)
  scene.index = {}
  addFlat(scene, data.voxels or {})
  scene.pending = false
  scene.updatedAt = data.updatedAt or nowString()
  scene.scannerTargets = uniqueArray(data.scannerTargets or scene.scannerTargets or {})
  setStatus("Loaded scene " .. scene.name)
  return scene
end

local function saveScene(scene)
  if not scene then
    setStatus("No scene selected.")
    return
  end
  local path = string.format("%s/%s.scene", CFG.SCENE_DIR, safeName(scene.name, "scene"))
  local payload = {
    name = scene.name,
    mode = scene.mode,
    box = scene.box,
    updatedAt = scene.updatedAt,
    scannerTargets = scene.scannerTargets or {},
    voxels = packIndex(scene),
  }
  local f, err = io.open(path, "w")
  if not f then
    setStatus("Save failed: " .. tostring(err))
    return
  end
  f:write(serialization.serialize(payload))
  f:close()
  setStatus("Saved scene to " .. path)
end

local function loadAllScenes()
  scenes = {}
  if not filesystem.exists(CFG.SCENE_DIR) then
    pcall(filesystem.makeDirectory, CFG.SCENE_DIR)
  end
  for name in filesystem.list(CFG.SCENE_DIR) do
    if tostring(name):match("%.scene$") then
      loadSceneByFile(CFG.SCENE_DIR .. "/" .. tostring(name))
    end
  end
  if selectedScene < 1 then selectedScene = 1 end
  if selectedScene > #scenes then selectedScene = #scenes end
end

local function deleteSelectedScene()
  local scene = sceneAt(selectedScene)
  if not scene then
    setStatus("No scene selected.")
    return
  end
  local removeDisk = askYesNo("Delete scene file from disk too?", false)
  if removeDisk then
    local path = string.format("%s/%s.scene", CFG.SCENE_DIR, safeName(scene.name, "scene"))
    if filesystem.exists(path) then
      pcall(filesystem.remove, path)
    end
  end
  for groupName, members in pairs(db.sceneGroups) do
    db.sceneGroups[groupName] = removeFromArray(members, scene.name)
  end
  db.sceneBindings[scene.name] = nil
  table.remove(scenes, selectedScene)
  if selectedScene > #scenes then selectedScene = #scenes end
  if selectedScene < 1 then selectedScene = 1 end
  saveDb()
  setStatus("Deleted scene " .. scene.name)
end

local function projectorAlias(id, fallback)
  local meta = db.projectorMeta[id]
  if meta and trim(meta.alias or "") ~= "" then
    return meta.alias
  end
  if projectors[id] and trim(projectors[id].label or "") ~= "" then
    return projectors[id].label
  end
  return fallback or id
end

local function scannerLabel(id)
  local info = scanners[id]
  if not info then return id end
  if trim(info.label or "") ~= "" then return info.label end
  return id
end

local function scannerIds()
  local ids = {}
  for id in pairs(scanners) do ids[#ids + 1] = id end
  sortArray(ids)
  return ids
end

local function projectorIds()
  local ids = {}
  for id in pairs(projectors) do ids[#ids + 1] = id end
  table.sort(ids, function(a, b)
    return projectorAlias(a):lower() < projectorAlias(b):lower()
  end)
  return ids
end

local function groupNames(map)
  local names = {}
  for name in pairs(map or {}) do names[#names + 1] = name end
  sortArray(names)
  return names
end

local function parseSelection(input, maxCount)
  input = trim(input or "")
  if input == "" then return {} end
  if input == "*" or input:lower() == "all" then
    local all = {}
    for i = 1, maxCount do all[#all + 1] = i end
    return all
  end
  local seen, out = {}, {}
  for part in input:gmatch("[^,]+") do
    part = trim(part)
    local a, b = part:match("^(%d+)%-(%d+)$")
    if a and b then
      a, b = tonumber(a), tonumber(b)
      if a > b then a, b = b, a end
      for i = a, b do
        if i >= 1 and i <= maxCount and not seen[i] then
          seen[i] = true
          out[#out + 1] = i
        end
      end
    else
      local n = tonumber(part)
      if n and n >= 1 and n <= maxCount and not seen[n] then
        seen[n] = true
        out[#out + 1] = n
      end
    end
  end
  table.sort(out)
  return out
end

local function chooseIdsFromList(title, entries, defaultInput, allowAll)
  if #entries == 0 then
    print(title .. ": none available.")
    return {}
  end
  print(title .. ":")
  for i = 1, #entries do
    print(string.format("  %2d) %s", i, entries[i].text))
  end
  local hint = allowAll and "numbers, range, or *" or "numbers or range"
  local input = ask("Select " .. hint, defaultInput or (allowAll and "*" or "1"))
  local indices = parseSelection(input, #entries)
  local ids = {}
  for i = 1, #indices do
    ids[#ids + 1] = entries[indices[i]].id
  end
  return ids
end

local function bindingForScene(sceneName)
  local binding = db.sceneBindings[sceneName]
  if not binding then
    binding = {projectors = {}, groups = {}}
    db.sceneBindings[sceneName] = binding
  end
  binding.projectors = uniqueArray(binding.projectors or {})
  binding.groups = uniqueArray(binding.groups or {})
  return binding
end

local function resolveProjectorTargets(binding)
  local ids, seen = {}, {}
  binding = binding or {projectors = {}, groups = {}}
  for i = 1, #(binding.projectors or {}) do
    local id = binding.projectors[i]
    if projectors[id] and not seen[id] then
      seen[id] = true
      ids[#ids + 1] = id
    end
  end
  for i = 1, #(binding.groups or {}) do
    local g = binding.groups[i]
    for _, id in ipairs(db.projectorGroups[g] or {}) do
      if projectors[id] and not seen[id] then
        seen[id] = true
        ids[#ids + 1] = id
      end
    end
  end
  table.sort(ids, function(a, b)
    return projectorAlias(a):lower() < projectorAlias(b):lower()
  end)
  return ids
end

local function sceneGroupMembers(groupName)
  return db.sceneGroups[groupName] or {}
end

local function discover()
  broadcastPacket("announce.request", {from = "console"})
  nextDiscovery = computer.uptime() + CFG.DISCOVERY_INTERVAL
  setStatus("Discovery broadcast sent.")
end

local function sceneFinished(scene)
  for nodeId in pairs(scene.expected or {}) do
    if not scene.done[nodeId] then
      return false
    end
  end
  return true
end

local function startCapture(opts)
  opts = opts or {}
  local targetIds = uniqueArray(opts.targetIds or {})
  if #targetIds == 0 then
    targetIds = scannerIds()
  end
  if #targetIds == 0 then
    setStatus("No matching scanners found.")
    return nil
  end

  local name = safeName(opts.name or ("scene-" .. tostring(math.floor(computer.uptime()))), "scene")
  local mode = opts.mode or CFG.DEFAULT_MODE
  local box = cloneTable(opts.box or CFG.DEFAULT_BOX)
  local requestId = string.format("req-%06d", math.random(0, 999999))

  local scene = ensureScene(name, mode, box)
  scene.index = {}
  scene.pending = true
  scene.expected = {}
  scene.done = {}
  scene.requestId = requestId
  scene.autoProject = opts.autoProject and true or false
  scene.updatedAt = nowString()
  scene.lastActivity = computer.uptime()
  scene.scannerTargets = cloneTable(targetIds)
  pendingByRequest[requestId] = scene

  local payload = {
    requestId = requestId,
    scene = name,
    mode = mode,
    box = box,
  }

  local sentCount = 0
  for i = 1, #targetIds do
    local id = targetIds[i]
    local info = scanners[id]
    if info then
      scene.expected[id] = true
      sendPacketTo(info.address, "scan.capture", payload)
      sentCount = sentCount + 1
    end
  end

  if sentCount == 0 then
    pendingByRequest[requestId] = nil
    scene.pending = false
    setStatus("No discovered scanners matched the request.")
    return nil
  end

  setStatus(string.format("Capture started: %s (%s) on %d scanner(s)", name, mode, sentCount))
  return scene
end

local function projectScene(scene, overrideTargets)
  if not scene then
    setStatus("No scene selected.")
    return false
  end
  local targetIds = uniqueArray(overrideTargets or resolveProjectorTargets(bindingForScene(scene.name)))
  if #targetIds == 0 then
    targetIds = projectorIds()
  end
  if #targetIds == 0 then
    setStatus("No projector nodes discovered.")
    return false
  end

  local flat = packIndex(scene)
  local beginPayload = {
    scene = scene.name,
    mode = scene.mode,
    updatedAt = scene.updatedAt,
  }

  for i = 1, #targetIds do
    local info = projectors[targetIds[i]]
    if info then
      sendPacketTo(info.address, "project.scene.begin", beginPayload)
    end
  end

  local batch = {}
  local batchNo = 1
  local function flushBatch()
    if #batch == 0 then return end
    for i = 1, #targetIds do
      local info = projectors[targetIds[i]]
      if info then
        sendPacketTo(info.address, "project.scene.chunk", {
          scene = scene.name,
          batch = batchNo,
          voxels = batch,
        })
      end
    end
    if os and os.sleep and CFG.PROJECT_SEND_PAUSE and CFG.PROJECT_SEND_PAUSE > 0 then
      pcall(os.sleep, CFG.PROJECT_SEND_PAUSE)
    end
    batch = {}
    batchNo = batchNo + 1
  end

  for i = 1, #flat, 4 do
    batch[#batch + 1] = flat[i]
    batch[#batch + 1] = flat[i + 1]
    batch[#batch + 1] = flat[i + 2]
    batch[#batch + 1] = flat[i + 3]
    if (#batch / 4) >= CFG.PROJECT_BATCH_VOXELS then
      flushBatch()
    end
  end
  flushBatch()

  for i = 1, #targetIds do
    local info = projectors[targetIds[i]]
    if info then
      sendPacketTo(info.address, "project.scene.end", {
        scene = scene.name,
        updatedAt = scene.updatedAt,
      })
    end
  end

  setStatus(string.format("Projected scene %s to %d projector(s).", scene.name, #targetIds))
  return true
end

local function projectSceneGroup(groupName)
  local members = sceneGroupMembers(groupName)
  local sent = 0
  for i = 1, #members do
    local scene = findSceneByName(members[i])
    if scene then
      if projectScene(scene) then
        sent = sent + 1
      end
    end
  end
  setStatus(string.format("Projected %d scene(s) from group %s.", sent, groupName))
end

local function clearProjectors(targetIds)
  local ids = uniqueArray(targetIds or projectorIds())
  if #ids == 0 then
    setStatus("No projector nodes discovered.")
    return
  end
  for i = 1, #ids do
    local info = projectors[ids[i]]
    if info then
      sendPacketTo(info.address, "project.clear", {})
    end
  end
  setStatus("Clear command sent to " .. tostring(#ids) .. " projector(s).")
end

local function startLocalPreview()
  local entries = {}
  local ids = scannerIds()
  for i = 1, #ids do
    local info = scanners[ids[i]]
    if info and info.preview then
      entries[#entries + 1] = {
        id = info.id,
        text = string.format("%s (%s)", scannerLabel(info.id), info.id),
      }
    end
  end
  if #entries == 0 then
    setStatus("No preview-capable scanner nodes discovered.")
    return
  end
  local chosen = chooseIdsFromList("Preview-capable scanners", entries, "1", false)
  local id = chosen[1]
  if not id then
    setStatus("Local preview cancelled.")
    return
  end
  local name = ask("preview label", "preview-" .. tostring(math.floor(computer.uptime())))
  local mode = ask("preview mode (void/solid/dense/bands)", CFG.DEFAULT_MODE)
  local box = promptBox(CFG.DEFAULT_BOX)

  if (tonumber(box.w) or 0) > 48 or (tonumber(box.d) or 0) > 48 or (tonumber(box.h) or 0) > 32 then
    setStatus("Local preview box must fit inside 48x32x48.")
    return
  end

  local info = scanners[id]
  if not info then
    setStatus("Scanner is no longer discovered.")
    return
  end

  sendPacketTo(info.address, "preview.local.capture", {
    scene = safeName(name, "preview"),
    mode = mode,
    box = box,
  })
  setStatus("Local preview command sent to " .. scannerLabel(id))
end

local function promptCapture(autoProject)
  local name = ask("scene name", "scene-" .. tostring(math.floor(computer.uptime())))
  local mode = ask("mode (void/solid/dense/bands)", CFG.DEFAULT_MODE)

  local entries = {}
  local ids = scannerIds()
  for i = 1, #ids do
    local info = scanners[ids[i]]
    local world = info.world or {}
    entries[#entries + 1] = {
      id = info.id,
      text = string.format("%s (%s @ %s,%s,%s)", scannerLabel(info.id), info.id, tostring(world.x or "?"), tostring(world.y or "?"), tostring(world.z or "?")),
    }
  end
  local targetIds = chooseIdsFromList("Scanners", entries, "*", true)
  local box = promptBox(CFG.DEFAULT_BOX)
  startCapture({
    name = name,
    mode = mode,
    targetIds = targetIds,
    box = box,
    autoProject = autoProject,
  })
end

local function liveProfileNames()
  return groupNames(db.liveProfiles)
end

local function normalizeLiveProfile(profile)
  profile.sceneName = safeName(profile.sceneName or "live-scene", "live-scene")
  profile.mode = profile.mode or CFG.DEFAULT_MODE
  profile.scannerTargets = uniqueArray(profile.scannerTargets or {})
  profile.box = cloneTable(profile.box or CFG.DEFAULT_BOX)
  profile.interval = math.max(1, tonumber(profile.interval) or CFG.DEFAULT_LIVE_INTERVAL)
  profile.autoProject = profile.autoProject ~= false
  profile.enabled = profile.enabled and true or false
  profile.inFlight = profile.inFlight and true or false
  profile.nextAt = tonumber(profile.nextAt) or 0
  profile.requestId = profile.requestId
  return profile
end

local function createOrEditLiveProfile(existingName)
  local profile
  if existingName and db.liveProfiles[existingName] then
    profile = cloneTable(db.liveProfiles[existingName])
  else
    profile = {
      sceneName = "live-" .. tostring(math.floor(computer.uptime())),
      mode = CFG.DEFAULT_MODE,
      scannerTargets = {},
      box = cloneTable(CFG.DEFAULT_BOX),
      interval = CFG.DEFAULT_LIVE_INTERVAL,
      autoProject = true,
      enabled = false,
      inFlight = false,
      nextAt = 0,
    }
  end
  normalizeLiveProfile(profile)

  local newName = safeName(ask("profile name", existingName or ("live-profile-" .. tostring(math.random(100, 999)))), existingName or "live-profile")
  profile.sceneName = safeName(ask("scene name", profile.sceneName), "live-scene")
  profile.mode = ask("mode (void/solid/dense/bands)", profile.mode)

  local entries = {}
  local ids = scannerIds()
  for i = 1, #ids do
    local info = scanners[ids[i]]
    entries[#entries + 1] = {
      id = info.id,
      text = string.format("%s (%s)", scannerLabel(info.id), info.id),
    }
  end
  local defaultTargetInput = (#profile.scannerTargets == 0) and "*" or nil
  profile.scannerTargets = chooseIdsFromList("Scanners for this live profile", entries, defaultTargetInput, true)
  if #profile.scannerTargets == 0 then
    profile.scannerTargets = scannerIds()
  end

  profile.interval = tonumber(ask("refresh interval seconds", profile.interval)) or profile.interval
  profile.box = promptBox(profile.box)
  profile.autoProject = askYesNo("Auto-project scene after each refresh?", profile.autoProject)
  profile.enabled = askYesNo("Enable this live profile now?", profile.enabled)
  profile.inFlight = false
  profile.nextAt = 0

  if existingName and existingName ~= newName then
    db.liveProfiles[existingName] = nil
  end
  db.liveProfiles[newName] = normalizeLiveProfile(profile)
  saveDb()
  setStatus("Saved live profile " .. newName)
end

local function deleteLiveProfile()
  local names = liveProfileNames()
  if #names == 0 then
    setStatus("No live profiles defined.")
    return
  end
  local entries = {}
  for i = 1, #names do
    local p = db.liveProfiles[names[i]]
    entries[#entries + 1] = {
      id = names[i],
      text = string.format("%s -> scene=%s %s", names[i], tostring(p.sceneName or "?"), p.enabled and "[ON]" or "[OFF]"),
    }
  end
  local chosen = chooseIdsFromList("Live profiles", entries, "1", false)
  local name = chosen[1]
  if not name then
    setStatus("Delete live profile cancelled.")
    return
  end
  db.liveProfiles[name] = nil
  saveDb()
  setStatus("Deleted live profile " .. name)
end

local function toggleLiveProfile()
  local names = liveProfileNames()
  if #names == 0 then
    setStatus("No live profiles defined.")
    return
  end
  local entries = {}
  for i = 1, #names do
    local p = db.liveProfiles[names[i]]
    entries[#entries + 1] = {
      id = names[i],
      text = string.format("%s -> scene=%s %s", names[i], tostring(p.sceneName or "?"), p.enabled and "[ON]" or "[OFF]"),
    }
  end
  local chosen = chooseIdsFromList("Live profiles", entries, "1", false)
  local name = chosen[1]
  if not name then
    setStatus("Toggle live profile cancelled.")
    return
  end
  local p = db.liveProfiles[name]
  p.enabled = not p.enabled
  p.inFlight = false
  p.nextAt = 0
  saveDb()
  setStatus(string.format("Live profile %s is now %s.", name, p.enabled and "ON" or "OFF"))
end

local function manageLiveProfiles()
  while true do
    print("")
    print("Live profiles:")
    local names = liveProfileNames()
    if #names == 0 then
      print("  (none)")
    else
      for i = 1, #names do
        local p = db.liveProfiles[names[i]]
        print(string.format("  %2d) %-18s scene=%-18s interval=%-3s %s", i, names[i], tostring(p.sceneName or "?"), tostring(p.interval or "?"), p.enabled and "ON" or "OFF"))
      end
    end
    print("  A) Add profile")
    print("  E) Edit profile")
    print("  T) Toggle profile")
    print("  D) Delete profile")
    print("  Q) Back")
    local ch = unicode.lower(unicode.char((select(3, event.pull("key_down")) or 0)))
    if ch == "a" then
      createOrEditLiveProfile(nil)
    elseif ch == "e" then
      local names2 = liveProfileNames()
      if #names2 > 0 then
        local input = tonumber(ask("Edit profile number", "1"))
        local name = names2[input or 0]
        if name then createOrEditLiveProfile(name) else setStatus("Invalid profile number.") end
      else
        setStatus("No live profiles defined.")
      end
    elseif ch == "t" then
      toggleLiveProfile()
    elseif ch == "d" then
      deleteLiveProfile()
    elseif ch == "q" then
      return
    end
  end
end

local function renameProjector()
  local ids = projectorIds()
  if #ids == 0 then
    setStatus("No projectors discovered.")
    return
  end
  local entries = {}
  for i = 1, #ids do
    entries[#entries + 1] = {
      id = ids[i],
      text = string.format("%s (%s)", projectorAlias(ids[i]), ids[i]),
    }
  end
  local chosen = chooseIdsFromList("Projectors", entries, "1", false)
  local id = chosen[1]
  if not id then
    setStatus("Rename cancelled.")
    return
  end
  db.projectorMeta[id] = db.projectorMeta[id] or {}
  db.projectorMeta[id].alias = safeName(ask("Alias", projectorAlias(id, id)), id)
  saveDb()
  setStatus("Saved alias for projector " .. id)
end

local function createOrEditProjectorGroup(existing)
  local name = safeName(ask("Projector group name", existing or "group"), existing or "group")
  local ids = projectorIds()
  local entries = {}
  for i = 1, #ids do
    entries[#entries + 1] = {
      id = ids[i],
      text = string.format("%s (%s)", projectorAlias(ids[i]), ids[i]),
    }
  end
  local selected = chooseIdsFromList("Projectors in this group", entries, "*", true)
  if existing and existing ~= name then
    db.projectorGroups[existing] = nil
  end
  db.projectorGroups[name] = uniqueArray(selected)
  saveDb()
  setStatus("Saved projector group " .. name)
end

local function deleteProjectorGroup()
  local names = groupNames(db.projectorGroups)
  if #names == 0 then
    setStatus("No projector groups defined.")
    return
  end
  local entries = {}
  for i = 1, #names do
    entries[#entries + 1] = {id = names[i], text = names[i]}
  end
  local chosen = chooseIdsFromList("Projector groups", entries, "1", false)
  local name = chosen[1]
  if not name then
    setStatus("Delete cancelled.")
    return
  end
  db.projectorGroups[name] = nil
  for _, binding in pairs(db.sceneBindings) do
    binding.groups = removeFromArray(binding.groups or {}, name)
  end
  saveDb()
  setStatus("Deleted projector group " .. name)
end

local function manageProjectors()
  while true do
    print("")
    print("Projector manager:")
    local ids = projectorIds()
    if #ids == 0 then
      print("  (no projectors discovered)")
    else
      for i = 1, #ids do
        local id = ids[i]
        local info = projectors[id]
        local tile = info.tile or {}
        print(string.format("  %2d) %-18s (%s) tile=%s,%s,%s", i, projectorAlias(id), id, tostring(tile.x or "?"), tostring(tile.y or "?"), tostring(tile.z or "?")))
      end
    end
    local groups = groupNames(db.projectorGroups)
    if #groups == 0 then
      print("  Groups: (none)")
    else
      print("  Groups:")
      for i = 1, #groups do
        print(string.format("     - %s [%d]", groups[i], #(db.projectorGroups[groups[i]] or {})))
      end
    end
    print("  R) Rename projector")
    print("  A) Add/Edit projector group")
    print("  D) Delete projector group")
    print("  C) Clear all projectors")
    print("  Q) Back")
    local ch = unicode.lower(unicode.char((select(3, event.pull("key_down")) or 0)))
    if ch == "r" then
      renameProjector()
    elseif ch == "a" then
      local existing = ask("Existing group to replace/rename (blank for new)", "")
      if trim(existing) == "" then existing = nil end
      createOrEditProjectorGroup(existing)
    elseif ch == "d" then
      deleteProjectorGroup()
    elseif ch == "c" then
      clearProjectors()
    elseif ch == "q" then
      return
    end
  end
end

local function createOrEditSceneGroup(existing)
  local name = safeName(ask("Scene group name", existing or "group"), existing or "group")
  local entries = {}
  for i = 1, #scenes do
    entries[#entries + 1] = {
      id = scenes[i].name,
      text = scenes[i].name,
    }
  end
  local selected = chooseIdsFromList("Scenes in this group", entries, "*", true)
  if existing and existing ~= name then
    db.sceneGroups[existing] = nil
  end
  db.sceneGroups[name] = uniqueArray(selected)
  saveDb()
  setStatus("Saved scene group " .. name)
end

local function deleteSceneGroup()
  local names = groupNames(db.sceneGroups)
  if #names == 0 then
    setStatus("No scene groups defined.")
    return
  end
  local entries = {}
  for i = 1, #names do
    entries[#entries + 1] = {id = names[i], text = names[i]}
  end
  local chosen = chooseIdsFromList("Scene groups", entries, "1", false)
  local name = chosen[1]
  if not name then
    setStatus("Delete cancelled.")
    return
  end
  db.sceneGroups[name] = nil
  saveDb()
  setStatus("Deleted scene group " .. name)
end

local function manageSceneGroups()
  while true do
    print("")
    print("Scene groups:")
    local names = groupNames(db.sceneGroups)
    if #names == 0 then
      print("  (none)")
    else
      for i = 1, #names do
        print(string.format("  %2d) %-18s [%d]", i, names[i], #(db.sceneGroups[names[i]] or {})))
      end
    end
    print("  A) Add/Edit group")
    print("  D) Delete group")
    print("  P) Project group")
    print("  Q) Back")
    local ch = unicode.lower(unicode.char((select(3, event.pull("key_down")) or 0)))
    if ch == "a" then
      local existing = ask("Existing group to replace/rename (blank for new)", "")
      if trim(existing) == "" then existing = nil end
      createOrEditSceneGroup(existing)
    elseif ch == "d" then
      deleteSceneGroup()
    elseif ch == "p" then
      local names2 = groupNames(db.sceneGroups)
      if #names2 == 0 then
        setStatus("No scene groups defined.")
      else
        local n = tonumber(ask("Project group number", "1"))
        local name = names2[n or 0]
        if name then projectSceneGroup(name) else setStatus("Invalid group number.") end
      end
    elseif ch == "q" then
      return
    end
  end
end

local function bindSelectedScene()
  local scene = sceneAt(selectedScene)
  if not scene then
    setStatus("No scene selected.")
    return
  end
  local binding = bindingForScene(scene.name)

  local pEntries = {}
  local ids = projectorIds()
  for i = 1, #ids do
    pEntries[#pEntries + 1] = {
      id = ids[i],
      text = string.format("%s (%s)", projectorAlias(ids[i]), ids[i]),
    }
  end
  local chosenProjectors = chooseIdsFromList("Direct projectors for scene " .. scene.name, pEntries, (#binding.projectors > 0) and nil or "", true)

  local gEntries = {}
  local gNames = groupNames(db.projectorGroups)
  for i = 1, #gNames do
    gEntries[#gEntries + 1] = {
      id = gNames[i],
      text = string.format("%s [%d projector(s)]", gNames[i], #(db.projectorGroups[gNames[i]] or {})),
    }
  end
  local chosenGroups = chooseIdsFromList("Projector groups for scene " .. scene.name, gEntries, (#binding.groups > 0) and nil or "", true)

  binding.projectors = uniqueArray(chosenProjectors)
  binding.groups = uniqueArray(chosenGroups)
  saveDb()
  setStatus("Updated projection binding for scene " .. scene.name)
end

local function handleHello(remoteAddress, payload)
  if payload.role == "scanner" then
    scanners[payload.id] = {
      id = payload.id,
      label = payload.label,
      address = remoteAddress,
      world = payload.world,
      lastSeen = computer.uptime(),
      modes = payload.modes,
      preview = payload.preview and true or false,
    }
  elseif payload.role == "projector" then
    projectors[payload.id] = {
      id = payload.id,
      label = payload.label,
      address = remoteAddress,
      tile = payload.tile,
      lastSeen = computer.uptime(),
      scale = payload.scale,
      depth = payload.depth,
    }
  end
end

local function handleScanBegin(payload)
  local scene = pendingByRequest[payload.requestId]
  if scene then
    scene.updatedAt = nowString()
    scene.lastActivity = computer.uptime()
  end
end

local function handleScanChunk(payload)
  local scene = pendingByRequest[payload.requestId]
  if scene then
    addFlat(scene, payload.voxels or {})
    scene.lastActivity = computer.uptime()
  end
end

local function handleScanEnd(payload)
  local scene = pendingByRequest[payload.requestId]
  if not scene then return end
  scene.done[payload.nodeId] = true
  scene.updatedAt = nowString()
  scene.lastActivity = computer.uptime()
  if sceneFinished(scene) then
    local shouldProject = scene.autoProject and true or false
    local matchedProfileName = nil

    scene.pending = false
    pendingByRequest[payload.requestId] = nil
    saveScene(scene)
    setStatus("Capture complete: " .. scene.name)

    for profileName, profile in pairs(db.liveProfiles) do
      if profile.requestId == payload.requestId then
        profile.inFlight = false
        profile.requestId = nil
        profile.nextAt = computer.uptime() + profile.interval
        shouldProject = shouldProject or (profile.autoProject and true or false)
        matchedProfileName = profileName
      end
    end

    if shouldProject then
      projectScene(scene)
    end

    if matchedProfileName then
      setStatus("Live refresh complete: " .. matchedProfileName)
    else
      setStatus("Capture complete: " .. scene.name)
    end
  end
end

local function handlePreviewComplete(payload)
  if payload.ok == false then
    setStatus("Local preview failed on " .. tostring(payload.nodeId or "scanner") .. ": " .. tostring(payload.reason or "unknown error"))
  else
    setStatus("Local preview complete on " .. tostring(payload.nodeId or "scanner") .. " for " .. tostring(payload.scene or "preview"))
  end
end

local function reapTimeouts()
  local now = computer.uptime()
  for requestId, scene in pairs(pendingByRequest) do
    if now - (scene.lastActivity or now) > CFG.CAPTURE_TIMEOUT then
      scene.pending = false
      pendingByRequest[requestId] = nil
      local voxelCount = countIndex(scene)
      for profileName, profile in pairs(db.liveProfiles) do
        if profile.requestId == requestId then
          profile.inFlight = false
          profile.requestId = nil
          profile.nextAt = now + profile.interval
          setStatus(string.format("Live profile %s timed out; kept %d voxel(s).", profileName, voxelCount))
        end
      end
      setStatus(string.format("Capture timed out: %s (kept %d voxel(s))", scene.name, voxelCount))
    end
  end
end

local function maybeRunLiveProfiles()
  local now = computer.uptime()
  for profileName, profile in pairs(db.liveProfiles) do
    normalizeLiveProfile(profile)
    if profile.enabled and not profile.inFlight and now >= (profile.nextAt or 0) then
      local scene = startCapture({
        name = profile.sceneName,
        mode = profile.mode,
        targetIds = profile.scannerTargets,
        box = profile.box,
        autoProject = profile.autoProject,
      })
      if scene then
        profile.inFlight = true
        profile.requestId = scene.requestId
        profile.nextAt = now + profile.interval
        setStatus("Live profile started: " .. profileName)
      else
        profile.nextAt = now + profile.interval
      end
    end
  end
end

local function drawHeader(w)
  if gpu then
    pcall(gpu.setBackground, 0x003344)
    pcall(gpu.setForeground, 0xFFFFFF)
    pcall(gpu.fill, 1, 1, w, 1, " ")
  end
  term.setCursor(2, 1)
  io.write("HOLO-NET CONSOLE v3")
  if gpu then
    pcall(gpu.setBackground, 0x000000)
    pcall(gpu.setForeground, 0xFFFFFF)
  end
end

local function draw()
  local w, h = 80, 25
  if gpu then
    local ok, gw, gh = pcall(gpu.getResolution)
    if ok then w, h = gw, gh end
  end

  pcall(term.clear)
  pcall(term.setCursor, 1, 1)
  drawHeader(w)

  term.setCursor(2, 3)
  print(string.rep("=", math.max(10, w - 2)))
  print(" Status : " .. tostring(status))
  print(" Time   : " .. nowString())
  local enabledCount = 0
  for _, p in pairs(db.liveProfiles) do if p.enabled then enabledCount = enabledCount + 1 end end
  print(" Live   : " .. tostring(enabledCount) .. " profile(s) active")
  print(string.rep("=", math.max(10, w - 2)))

  print(" Scanners:")
  local sIds = scannerIds()
  if #sIds == 0 then
    print("   (none discovered)")
  else
    for i = 1, math.min(#sIds, 5) do
      local info = scanners[sIds[i]]
      local world = info.world or {}
      print(string.format("   - %-14s (%s,%s,%s)%s", scannerLabel(info.id), tostring(world.x or "?"), tostring(world.y or "?"), tostring(world.z or "?"), info.preview and " [preview]" or ""))
    end
  end

  print("")
  print(" Projectors:")
  local pIds = projectorIds()
  if #pIds == 0 then
    print("   (none discovered)")
  else
    for i = 1, math.min(#pIds, 5) do
      local info = projectors[pIds[i]]
      local tile = info.tile or {}
      print(string.format("   - %-18s tile=(%s,%s,%s)", projectorAlias(info.id), tostring(tile.x or "?"), tostring(tile.y or "?"), tostring(tile.z or "?")))
    end
  end

  print("")
  print(" Scenes:")
  if #scenes == 0 then
    print("   (none loaded or captured)")
  else
    for i = 1, math.min(#scenes, 7) do
      local scene = scenes[i]
      local marker = (i == selectedScene) and ">" or " "
      local flags = {}
      if scene.pending then flags[#flags + 1] = "CAP" end
      local binding = bindingForScene(scene.name)
      local boundTargets = #resolveProjectorTargets(binding)
      print(string.format(" %s %-18s mode=%-6s vox=%-6d bind=%-3d %s", marker, scene.name, tostring(scene.mode or "?"), countIndex(scene), boundTargets, table.concat(flags, ",")))
    end
  end

  print("")
  print(" Keys: C capture  V local preview  P project  J bind scene  M projectors")
  print("       G scene groups  Y live profiles  S save  O open  T reload  X delete")
  print("       N/B select  K clear projectors  R discover  Q quit")
end

local function handleKey(ch)
  if ch == "q" then
    return false
  elseif ch == "r" then
    discover()
  elseif ch == "c" then
    promptCapture(false)
  elseif ch == "v" then
    startLocalPreview()
  elseif ch == "p" then
    projectScene(sceneAt(selectedScene))
  elseif ch == "j" then
    bindSelectedScene()
  elseif ch == "m" then
    manageProjectors()
  elseif ch == "g" then
    manageSceneGroups()
  elseif ch == "y" then
    manageLiveProfiles()
  elseif ch == "s" then
    saveScene(sceneAt(selectedScene))
  elseif ch == "o" then
    local file = ask("scene file path", CFG.SCENE_DIR .. "/example.scene")
    if file then loadSceneByFile(file) end
  elseif ch == "t" then
    loadAllScenes()
    setStatus("Reloaded scenes from disk.")
  elseif ch == "x" then
    deleteSelectedScene()
  elseif ch == "n" then
    if #scenes > 0 then selectedScene = math.min(#scenes, selectedScene + 1) end
    setStatus("Selected next scene.")
  elseif ch == "b" then
    if #scenes > 0 then selectedScene = math.max(1, selectedScene - 1) end
    setStatus("Selected previous scene.")
  elseif ch == "k" then
    clearProjectors()
  end
  return true
end

loadDb()
loadAllScenes()
discover()

local running = true
while running do
  draw()
  maybeRunLiveProfiles()
  reapTimeouts()

  local ev = table.pack(event.pull(0.25))
  if ev.n > 0 then
    local name = ev[1]
    if name == "modem_message" then
      local _, localAddress, remoteAddress, port, distance, proto, kind, blob = table.unpack(ev, 1, ev.n)
      if port == CFG.PORT and proto == "holonet" then
        local ok, payload = pcall(serialization.unserialize, blob or "{}")
        if not ok or type(payload) ~= "table" then payload = {} end

        if kind == "hello" then
          handleHello(remoteAddress, payload)
        elseif kind == "scan.begin" then
          handleScanBegin(payload)
        elseif kind == "scan.chunk" then
          handleScanChunk(payload)
        elseif kind == "scan.end" then
          handleScanEnd(payload)
        elseif kind == "preview.local.complete" then
          handlePreviewComplete(payload)
        elseif kind == "pong" then
          -- no-op
        end
      end
    elseif name == "key_down" then
      local charCode = ev[3]
      if charCode and charCode > 0 then
        local ch = unicode.lower(unicode.char(charCode))
        running = handleKey(ch)
      end
    elseif name == "interrupted" then
      running = false
    end
  end

  if computer.uptime() >= nextDiscovery then
    discover()
  end
end

saveDb()
pcall(term.clear)
pcall(term.setCursor, 1, 1)
print("HOLO-NET console closed.")
