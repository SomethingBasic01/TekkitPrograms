local component = require("component")
local event = require("event")
local serialization = require("serialization")
local computer = require("computer")
local term = require("term")
local unicode = require("unicode")
local filesystem = require("filesystem")

--------------------------------------------------------------------------------
-- HOLO-NET CONSOLE
-- Put this on your main control terminal.
-- It discovers scanner nodes and projector nodes, captures scenes, saves/loads
-- them, and projects them through all connected projector nodes.
--------------------------------------------------------------------------------

local CFG = {
  PORT = 3413,
  MODEM_STRENGTH = 400,
  SCENE_DIR = "/home/holonet_scenes",
  DISCOVERY_INTERVAL = 12,
  LIVE_DEFAULT_INTERVAL = 5,
  PROJECT_BATCH_VOXELS = 120,
  CAPTURE_TIMEOUT = 20,

  DEFAULT_BOX = {x = -24, z = -24, y = -16, w = 48, d = 48, h = 32},
  DEFAULT_MODE = "bands",
}

local modem = component.modem
assert(modem, "No modem found")
modem.open(CFG.PORT)
if modem.isWireless and modem.isWireless() and modem.setStrength then
  pcall(modem.setStrength, CFG.MODEM_STRENGTH)
end
pcall(filesystem.makeDirectory, CFG.SCENE_DIR)

math.randomseed(math.floor(computer.uptime() * 1000) % 2147483647)

local scanners = {}   -- nodeId -> info
local projectors = {} -- nodeId -> info
local scenes = {}     -- array of scene tables
local pendingByRequest = {}
local selected = 1
local status = "Ready. Press R to discover nodes."
local nextDiscovery = 0
local live = {
  enabled = false,
  sceneName = nil,
  mode = nil,
  box = nil,
  target = "*",
  interval = CFG.LIVE_DEFAULT_INTERVAL,
  autoProject = true,
  inFlight = false,
  nextAt = 0,
}

local gpu = component.isAvailable("gpu") and component.gpu or nil

local function nowString()
  local ok, value = pcall(os.date, "%Y-%m-%d %H:%M:%S")
  if ok then return value end
  return string.format("uptime %.1fs", computer.uptime())
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

local function trim(s)
  return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
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

local function safeName(s)
  s = trim(s or "scene")
  if s == "" then s = "scene" end
  s = s:gsub("[^%w%-%._ ]", "_")
  return s
end

local function setStatus(text)
  status = text
end

local function sortedSceneNames()
  local names = {}
  for i = 1, #scenes do names[i] = scenes[i].name end
  return names
end

local function sceneAt(index)
  if #scenes == 0 then return nil end
  if index < 1 then index = 1 end
  if index > #scenes then index = #scenes end
  selected = index
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
    scene.index = {}
    scene.pending = false
    scene.expected = {}
    scene.done = {}
    scene.autoProject = false
    scene.updatedAt = nowString()
    selected = idx
    return scene
  end

  scene = {
    name = name,
    mode = mode,
    box = box,
    index = {},
    pending = false,
    expected = {},
    done = {},
    autoProject = false,
    updatedAt = nowString(),
  }
  scenes[#scenes + 1] = scene
  selected = #scenes
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
  for i = 1, #flat, 4 do
    local x, y, z, v = flat[i], flat[i + 1], flat[i + 2], flat[i + 3]
    if x and y and z and v then
      scene.index[string.format("%d:%d:%d", x, y, z)] = v
    end
  end
  scene.updatedAt = nowString()
end

local function saveScene(scene)
  if not scene then
    setStatus("No scene selected.")
    return
  end
  local path = string.format("%s/%s.scene", CFG.SCENE_DIR, safeName(scene.name))
  local payload = {
    name = scene.name,
    mode = scene.mode,
    box = scene.box,
    updatedAt = scene.updatedAt,
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

local function loadSceneByFile(path)
  local f, err = io.open(path, "r")
  if not f then
    setStatus("Load failed: " .. tostring(err))
    return
  end
  local text = f:read("*a")
  f:close()
  local ok, data = pcall(serialization.unserialize, text)
  if not ok or type(data) ~= "table" then
    setStatus("Load failed: invalid scene file")
    return
  end
  local scene = ensureScene(data.name or filesystem.name(path) or "loaded-scene", data.mode or "loaded", data.box)
  addFlat(scene, data.voxels or {})
  scene.pending = false
  scene.updatedAt = data.updatedAt or nowString()
  setStatus("Loaded scene " .. scene.name)
end

local function deleteSelectedScene()
  if #scenes == 0 then
    setStatus("No scene to delete.")
    return
  end
  local name = scenes[selected].name
  table.remove(scenes, selected)
  if selected > #scenes then selected = #scenes end
  if selected < 1 then selected = 1 end
  setStatus("Deleted scene " .. name .. " from memory.")
end

local function discover()
  broadcastPacket("announce.request", {from = "console"})
  nextDiscovery = computer.uptime() + CFG.DISCOVERY_INTERVAL
  setStatus("Discovery broadcast sent.")
end

local function scannerList()
  local ids = {}
  for id in pairs(scanners) do ids[#ids + 1] = id end
  table.sort(ids)
  return ids
end

local function projectorList()
  local ids = {}
  for id in pairs(projectors) do ids[#ids + 1] = id end
  table.sort(ids)
  return ids
end

local function startCapture(opts)
  opts = opts or {}
  local target = opts.target or "*"
  local name = safeName(opts.name or ("scene-" .. tostring(math.floor(computer.uptime()))))
  local mode = opts.mode or CFG.DEFAULT_MODE
  local box = opts.box or CFG.DEFAULT_BOX
  local requestId = string.format("req-%06d", math.random(0, 999999))

  local matched = {}
  local ids = scannerList()
  for i = 1, #ids do
    local id = ids[i]
    if target == "*" or target == id then
      matched[#matched + 1] = scanners[id]
    end
  end

  if #matched == 0 then
    setStatus("No matching scanners found.")
    return nil
  end

  local scene = ensureScene(name, mode, box)
  scene.index = {}
  scene.pending = true
  scene.expected = {}
  scene.done = {}
  scene.requestId = requestId
  scene.autoProject = opts.autoProject and true or false
  scene.updatedAt = nowString()
  scene.lastActivity = computer.uptime()
  pendingByRequest[requestId] = scene

  local payload = {
    requestId = requestId,
    scene = name,
    mode = mode,
    box = box,
  }

  for i = 1, #matched do
    local info = matched[i]
    scene.expected[info.id] = true
    sendPacketTo(info.address, "scan.capture", payload)
  end

  setStatus(string.format("Capture started: %s (%s) on %d scanner(s)", name, mode, #matched))
  return scene
end

local function sceneFinished(scene)
  for nodeId in pairs(scene.expected or {}) do
    if not scene.done[nodeId] then
      return false
    end
  end
  return true
end

local function projectScene(scene)
  if not scene then
    setStatus("No scene selected.")
    return
  end
  local flat = packIndex(scene)
  local projectorCount = #projectorList()
  if projectorCount == 0 then
    setStatus("No projector nodes discovered.")
    return
  end

  broadcastPacket("project.scene.begin", {
    scene = scene.name,
    mode = scene.mode,
    updatedAt = scene.updatedAt,
  })

  local batch = {}
  local batchNo = 1
  for i = 1, #flat, 4 do
    batch[#batch + 1] = flat[i]
    batch[#batch + 1] = flat[i + 1]
    batch[#batch + 1] = flat[i + 2]
    batch[#batch + 1] = flat[i + 3]
    if (#batch / 4) >= CFG.PROJECT_BATCH_VOXELS then
      broadcastPacket("project.scene.chunk", {
        scene = scene.name,
        batch = batchNo,
        voxels = batch,
      })
      batch = {}
      batchNo = batchNo + 1
    end
  end

  if #batch > 0 then
    broadcastPacket("project.scene.chunk", {
      scene = scene.name,
      batch = batchNo,
      voxels = batch,
    })
  end

  broadcastPacket("project.scene.end", {
    scene = scene.name,
    updatedAt = scene.updatedAt,
  })
  setStatus(string.format("Projected scene %s to %d projector(s).", scene.name, projectorCount))
end

local function clearProjectors()
  broadcastPacket("project.clear", {})
  setStatus("Clear command sent to all projectors.")
end

local function drawHeader(w)
  if gpu then
    pcall(gpu.setBackground, 0x003344)
    pcall(gpu.setForeground, 0xFFFFFF)
    pcall(gpu.fill, 1, 1, w, 1, " ")
  end
  term.setCursor(2, 1)
  io.write("HOLO-NET CONSOLE")
  if gpu then
    pcall(gpu.setBackground, 0x000000)
    pcall(gpu.setForeground, 0xFFFFFF)
  end
end

local function draw()
  local w, h = 80, 25
  if gpu then
    local ok, gw, gh = pcall(gpu.getResolution)
    if ok then
      w, h = gw, gh
    end
  end

  pcall(term.clear)
  pcall(term.setCursor, 1, 1)
  drawHeader(w)

  term.setCursor(2, 3)
  print(string.rep("=", math.max(10, w - 2)))
  print(" Status : " .. tostring(status))
  print(" Time   : " .. nowString())
  print(" Live   : " .. (live.enabled and ("ON  [scene=" .. tostring(live.sceneName) .. "]") or "OFF"))
  print(string.rep("=", math.max(10, w - 2)))

  print(" Scanners:")
  local sIds = scannerList()
  if #sIds == 0 then
    print("   (none discovered)")
  else
    for i = 1, math.min(#sIds, 6) do
      local info = scanners[sIds[i]]
      local world = info.world or {}
      print(string.format("   - %-14s @ %s  (%s,%s,%s)", info.id, info.address or "?", tostring(world.x or "?"), tostring(world.y or "?"), tostring(world.z or "?")))
    end
  end

  print("\n Projectors:")
  local pIds = projectorList()
  if #pIds == 0 then
    print("   (none discovered)")
  else
    for i = 1, math.min(#pIds, 6) do
      local info = projectors[pIds[i]]
      local tile = info.tile or {}
      print(string.format("   - %-14s tile (%s,%s,%s)", info.id, tostring(tile.x or "?"), tostring(tile.y or "?"), tostring(tile.z or "?")))
    end
  end

  print("\n Scenes:")
  if #scenes == 0 then
    print("   (none loaded or captured)")
  else
    for i = 1, math.min(#scenes, 8) do
      local scene = scenes[i]
      local marker = (i == selected) and ">" or " "
      local flags = {}
      if scene.pending then flags[#flags + 1] = "CAPTURING" end
      if live.enabled and live.sceneName == scene.name then flags[#flags + 1] = "LIVE" end
      local flatCount = 0
      for _ in pairs(scene.index or {}) do flatCount = flatCount + 1 end
      print(string.format(" %s %-18s mode=%-6s vox=%-6d %s", marker, scene.name, tostring(scene.mode or "?"), flatCount, table.concat(flags, ",")))
    end
  end

  print("\n Keys: C capture  L live  P project  S save  O open  X delete  N/B select  K clear  R discover  Q quit")
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

local function promptCapture(autoProject)
  local name = ask("scene name", "scene-" .. tostring(math.floor(computer.uptime())))
  local mode = ask("mode (void/solid/dense/bands)", CFG.DEFAULT_MODE)
  local target = ask("scanner target (* for all)", "*")
  local box = promptBox(CFG.DEFAULT_BOX)
  startCapture({name = name, mode = mode, target = target, box = box, autoProject = autoProject})
end

local function toggleLive()
  if live.enabled then
    live.enabled = false
    live.inFlight = false
    setStatus("Live mode stopped.")
    return
  end

  local name = ask("live scene name", live.sceneName or "live-scene")
  local mode = ask("live mode (void/solid/dense/bands)", live.mode or CFG.DEFAULT_MODE)
  local target = ask("scanner target (* for all)", live.target or "*")
  local interval = tonumber(ask("refresh interval seconds", live.interval or CFG.LIVE_DEFAULT_INTERVAL)) or CFG.LIVE_DEFAULT_INTERVAL
  local box = promptBox(live.box or CFG.DEFAULT_BOX)

  live.enabled = true
  live.sceneName = safeName(name)
  live.mode = mode
  live.target = target
  live.interval = math.max(1, interval)
  live.box = box
  live.autoProject = true
  live.inFlight = false
  live.nextAt = 0
  setStatus("Live mode armed for scene " .. live.sceneName)
end

local function handleHello(remoteAddress, payload)
  if payload.role == "scanner" then
    scanners[payload.id] = {
      id = payload.id,
      address = remoteAddress,
      world = payload.world,
      lastSeen = computer.uptime(),
      modes = payload.modes,
    }
  elseif payload.role == "projector" then
    projectors[payload.id] = {
      id = payload.id,
      address = remoteAddress,
      tile = payload.tile,
      lastSeen = computer.uptime(),
      scale = payload.scale,
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
    scene.pending = false
    pendingByRequest[payload.requestId] = nil
    setStatus("Capture complete: " .. scene.name)
    if live.enabled and live.sceneName == scene.name then
      live.inFlight = false
      live.nextAt = computer.uptime() + live.interval
    end
    if scene.autoProject then
      projectScene(scene)
    end
  end
end

local function reapTimeouts()
  local now = computer.uptime()
  for requestId, scene in pairs(pendingByRequest) do
    if now - (scene.lastActivity or now) > CFG.CAPTURE_TIMEOUT then
      scene.pending = false
      pendingByRequest[requestId] = nil
      if live.enabled and live.sceneName == scene.name then
        live.inFlight = false
        live.nextAt = now + live.interval
      end
      setStatus("Capture timed out: " .. scene.name .. " (partial scene kept)")
    end
  end
end

local function handleKey(ch)
  if ch == "q" then
    return false
  elseif ch == "r" then
    discover()
  elseif ch == "c" then
    promptCapture(false)
  elseif ch == "l" then
    toggleLive()
  elseif ch == "p" then
    projectScene(sceneAt(selected))
  elseif ch == "s" then
    saveScene(sceneAt(selected))
  elseif ch == "o" then
    local file = ask("scene file path", CFG.SCENE_DIR .. "/example.scene")
    if file then loadSceneByFile(file) end
  elseif ch == "x" then
    deleteSelectedScene()
  elseif ch == "n" then
    if #scenes > 0 then selected = math.min(#scenes, selected + 1) end
    setStatus("Selected next scene.")
  elseif ch == "b" then
    if #scenes > 0 then selected = math.max(1, selected - 1) end
    setStatus("Selected previous scene.")
  elseif ch == "k" then
    clearProjectors()
  end
  return true
end

local function maybeRunLive()
  if not live.enabled then return end
  if live.inFlight then return end
  if computer.uptime() < (live.nextAt or 0) then return end
  local scene = startCapture({
    name = live.sceneName,
    mode = live.mode,
    target = live.target,
    box = live.box,
    autoProject = live.autoProject,
  })
  if scene then
    live.inFlight = true
  else
    live.nextAt = computer.uptime() + live.interval
  end
end

discover()

local running = true
while running do
  draw()
  maybeRunLive()
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
        elseif kind == "pong" then
          -- optional
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

pcall(term.clear)
pcall(term.setCursor, 1, 1)
print("HOLO-NET console closed.")
