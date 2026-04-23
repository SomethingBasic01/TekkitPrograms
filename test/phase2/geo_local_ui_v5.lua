
local component = require("component")
local serialization = require("serialization")
local term = require("term")
local filesystem = require("filesystem")
local event = require("event")
local computer = require("computer")

assert(component.isAvailable("geolyzer"), "No geolyzer found")
assert(component.isAvailable("hologram"), "No hologram projector found")

local g = component.geolyzer
local h = component.hologram
local modem = component.isAvailable("modem") and component.modem or nil

local CFG_PATH = "/home/geo_local_ui.cfg"
local SNAP_DIR = "/home/geo_snapshots"
local PROJECTOR_DB_PATH = "/home/geo_projectors.cfg"

local NET_PORT = 3413
local NET_CHUNK_VOXELS = 32

local defaults = {
  mode = "solid",

  offsetX = -8,
  offsetZ = -8,
  sizeX = 16,
  sizeZ = 16,

  yMin = -4,
  yMax = 11,
  dstYBase = 9,

  center = true,
  flipX = false,
  flipZ = false,
  swapXZ = false,

  airMax = 0.05,
  denseMin = 4.0,

  scale = 1,

  color1 = 0x00FF00,
  color2 = 0x00FFFF,
  color3 = 0xFF4040,
}

local RANGE_HINTS = {
  mode = "solid | void | dense | bands",
  offsetX = "recommended: -24..24 (script allows -128..127)",
  offsetZ = "recommended: -24..24 (script allows -128..127)",
  sizeX = "1..48",
  sizeZ = "1..48",
  yMin = "-32..31",
  yMax = "-32..31",
  dstYBase = "1..32",
  airMax = "recommended: 0.00..0.20",
  denseMin = "recommended: 2.0..6.0",
  scale = "0.33..3",
  color = "0x000000..0xFFFFFF",
}

local cfg = {}
local lastScan = nil
local loadedScenes = {}
local loadedSceneOrder = {}
local activeSceneName = nil

local knownProjectors = {}
local projectorOrder = {}

local function ensureSnapshotDir()
  if not filesystem.exists(SNAP_DIR) then
    filesystem.makeDirectory(SNAP_DIR)
  end
end

local function holoDepth()
  if h.maxDepth then
    local ok, depth = pcall(h.maxDepth)
    if ok and type(depth) == "number" then
      return depth
    end
  end
  return 1
end

local function cloneTable(t)
  if type(t) ~= "table" then return t end
  local out = {}
  for k, v in pairs(t) do
    if type(v) == "table" then
      out[k] = cloneTable(v)
    else
      out[k] = v
    end
  end
  return out
end

local function copyDefaults()
  for k, v in pairs(defaults) do
    if cfg[k] == nil then
      cfg[k] = v
    end
  end
end

local function loadCfg()
  local f = io.open(CFG_PATH, "r")
  if not f then
    cfg = {}
    copyDefaults()
    return
  end

  local raw = f:read("*a")
  f:close()

  local ok, data = pcall(serialization.unserialize, raw)
  if ok and type(data) == "table" then
    cfg = data
  else
    cfg = {}
  end
  copyDefaults()
end

local function saveCfg()
  local f, err = io.open(CFG_PATH, "w")
  if not f then
    io.stderr:write("Failed to save config: " .. tostring(err) .. "\n")
    return false
  end
  f:write(serialization.serialize(cfg))
  f:close()
  return true
end

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function pause(msg)
  print("")
  io.write(msg or "Press Enter...")
  io.read()
end

local function promptString(label, current, hint)
  if hint then print(label .. ": " .. hint) end
  io.write(string.format("%s [%s]: ", label, tostring(current or "")))
  local s = io.read()
  if not s or s == "" then return current end
  return s
end

local function promptNumber(label, current, minv, maxv, integerOnly, hint)
  if hint then print(label .. " range: " .. hint) end
  io.write(string.format("%s [%s]: ", label, tostring(current)))
  local s = io.read()
  if not s or s == "" then return current end
  local n = tonumber(s)
  if not n then return current end
  if integerOnly then n = math.floor(n) end
  if minv then n = math.max(minv, n) end
  if maxv then n = math.min(maxv, n) end
  return n
end

local function promptBool(label, current)
  io.write(string.format("%s [%s] (y/n): ", label, current and "y" or "n"))
  local s = io.read()
  if not s or s == "" then return current end
  s = s:lower()
  if s == "y" or s == "yes" or s == "1" or s == "true" then return true end
  if s == "n" or s == "no" or s == "0" or s == "false" then return false end
  return current
end

local function promptHex(label, current)
  print(label .. " range: " .. RANGE_HINTS.color)
  io.write(string.format("%s [0x%06X]: ", label, current))
  local s = io.read()
  if not s or s == "" then return current end
  s = s:gsub("^0[xX]", "")
  local n = tonumber(s, 16)
  if not n then return current end
  return clamp(math.floor(n), 0x000000, 0xFFFFFF)
end

local modes = { "solid", "void", "dense", "bands" }

local function nextMode()
  for i = 1, #modes do
    if modes[i] == cfg.mode then
      cfg.mode = modes[(i % #modes) + 1]
      return
    end
  end
  cfg.mode = modes[1]
end

local function setPalette()
  local depth = holoDepth()
  pcall(h.setPaletteColor, 1, cfg.color1)
  if depth > 1 then
    pcall(h.setPaletteColor, 2, cfg.color2)
    pcall(h.setPaletteColor, 3, cfg.color3)
  end
end

local function classify(v)
  v = tonumber(v) or 0
  local depth = holoDepth()

  if cfg.mode == "void" then
    if v <= cfg.airMax then
      return 1
    end
    return 0
  end

  if cfg.mode == "solid" then
    if v <= cfg.airMax then
      return 0
    end
    return 1
  end

  if cfg.mode == "dense" then
    if v >= cfg.denseMin then
      return depth > 1 and 3 or 1
    end
    return 0
  end

  if v <= cfg.airMax then
    return 0
  end

  if depth <= 1 then
    return 1
  end

  if v < 1.5 then
    return 1
  elseif v < cfg.denseMin then
    return 2
  else
    return 3
  end
end

local function mapXZ(hx, hz)
  local sizeDrawX = cfg.swapXZ and cfg.sizeZ or cfg.sizeX
  local sizeDrawZ = cfg.swapXZ and cfg.sizeX or cfg.sizeZ

  local drawX, drawZ = hx, hz

  if cfg.swapXZ then
    drawX, drawZ = drawZ, drawX
  end

  if cfg.flipX then
    drawX = sizeDrawX - drawX + 1
  end

  if cfg.flipZ then
    drawZ = sizeDrawZ - drawZ + 1
  end

  local baseX, baseZ = 1, 1
  if cfg.center then
    baseX = math.floor((48 - sizeDrawX) / 2) + 1
    baseZ = math.floor((48 - sizeDrawZ) / 2) + 1
  end

  return baseX + drawX - 1, baseZ + drawZ - 1
end

local function sanitizeName(name)
  name = tostring(name or "snapshot")
  name = name:gsub("[^%w%-%_%.]", "_")
  name = name:gsub("_+", "_")
  name = name:gsub("^_", "")
  name = name:gsub("_$", "")
  if name == "" then name = "snapshot" end
  return name
end

local function snapshotPath(name)
  return SNAP_DIR .. "/" .. sanitizeName(name) .. ".scan"
end

local function listSnapshotFiles()
  ensureSnapshotDir()
  local out = {}
  for file in filesystem.list(SNAP_DIR) do
    if file:sub(-5) == ".scan" then
      table.insert(out, file)
    end
  end
  table.sort(out)
  return out
end

local function renderSnapshotData(data)
  if type(data) ~= "table" or type(data.voxels) ~= "table" then
    return false, "Invalid snapshot data"
  end

  h.clear()
  pcall(h.setScale, cfg.scale)
  setPalette()

  local total = 0
  for i = 1, #data.voxels do
    local v = data.voxels[i]
    if type(v) == "table" and v.x and v.y and v.z and v.v then
      if v.x >= 1 and v.x <= 48 and v.y >= 1 and v.y <= 32 and v.z >= 1 and v.z <= 48 then
        h.set(v.x, v.y, v.z, v.v)
        total = total + 1
      end
    end
  end
  return true, total
end

local function rebuildSceneOrder()
  loadedSceneOrder = {}
  for name, _ in pairs(loadedScenes) do
    table.insert(loadedSceneOrder, name)
  end
  table.sort(loadedSceneOrder)
  if activeSceneName and not loadedScenes[activeSceneName] then
    activeSceneName = nil
  end
  if not activeSceneName and #loadedSceneOrder > 0 then
    activeSceneName = loadedSceneOrder[1]
  end
end

local function addSceneToMemory(name, data)
  name = sanitizeName(name or data.name or ("scene_" .. tostring(#loadedSceneOrder + 1)))
  local copy = cloneTable(data)
  copy.name = name
  loadedScenes[name] = copy
  rebuildSceneOrder()
  activeSceneName = name
  return name
end

local function chooseLoadedScene(actionText)
  rebuildSceneOrder()
  term.clear()
  term.setCursor(1, 1)
  print(actionText)
  print(string.rep("-", #actionText))
  if #loadedSceneOrder == 0 then
    print("No loaded scenes in memory.")
    pause()
    return nil
  end
  for i = 1, #loadedSceneOrder do
    local name = loadedSceneOrder[i]
    local scene = loadedScenes[name]
    local marker = (name == activeSceneName) and "*" or " "
    print(string.format("%s%2d  %s  (%d voxels)", marker, i, name, tonumber(scene.count or (scene.voxels and #scene.voxels) or 0)))
  end
  print("")
  io.write("Choose number (blank to cancel): ")
  local s = io.read()
  if not s or s == "" then return nil end
  local n = tonumber(s)
  if not n then return nil end
  n = math.floor(n)
  if n < 1 or n > #loadedSceneOrder then return nil end
  return loadedSceneOrder[n]
end

local function buildScanData(total)
  return {
    format = "geo_local_snapshot_v1",
    name = nil,
    savedAt = os.time and os.time() or nil,
    projectorDepth = holoDepth(),
    settings = {
      mode = cfg.mode,
      offsetX = cfg.offsetX,
      offsetZ = cfg.offsetZ,
      sizeX = cfg.sizeX,
      sizeZ = cfg.sizeZ,
      yMin = cfg.yMin,
      yMax = cfg.yMax,
      dstYBase = cfg.dstYBase,
      center = cfg.center,
      flipX = cfg.flipX,
      flipZ = cfg.flipZ,
      swapXZ = cfg.swapXZ,
      airMax = cfg.airMax,
      denseMin = cfg.denseMin,
      scale = cfg.scale,
      color1 = cfg.color1,
      color2 = cfg.color2,
      color3 = cfg.color3,
    },
    count = total or 0,
    voxels = {},
  }
end

local function renderActiveScene()
  if not activeSceneName or not loadedScenes[activeSceneName] then
    term.clear()
    term.setCursor(1, 1)
    print("No active loaded scene.")
    return pause()
  end

  local scene = loadedScenes[activeSceneName]
  if scene.settings then
    if scene.settings.scale ~= nil then cfg.scale = scene.settings.scale end
    if scene.settings.color1 ~= nil then cfg.color1 = scene.settings.color1 end
    if scene.settings.color2 ~= nil then cfg.color2 = scene.settings.color2 end
    if scene.settings.color3 ~= nil then cfg.color3 = scene.settings.color3 end
  end

  local okRender, result = renderSnapshotData(scene)
  term.clear()
  term.setCursor(1, 1)
  if not okRender then
    print("Failed to render active scene: " .. tostring(result))
  else
    print("Rendered active scene: " .. activeSceneName)
    print("Voxels drawn: " .. tostring(result))
    lastScan = cloneTable(scene)
  end
  pause()
end

local function activateLoadedScene()
  local name = chooseLoadedScene("Activate/render loaded scene")
  if not name then return end
  activeSceneName = name
  renderActiveScene()
end

local function loadedSceneInfo()
  local name = chooseLoadedScene("Loaded scene info")
  if not name then return end
  local data = loadedScenes[name]
  term.clear()
  term.setCursor(1, 1)
  print("Loaded scene info")
  print("-----------------")
  print("Name:   " .. tostring(name))
  print("Count:  " .. tostring(data.count or (data.voxels and #data.voxels) or 0))
  print("Format: " .. tostring(data.format or "unknown"))
  if data.settings then
    print("Mode:   " .. tostring(data.settings.mode))
    print("Area:   x=" .. tostring(data.settings.offsetX) .. " z=" .. tostring(data.settings.offsetZ)
      .. " size=" .. tostring(data.settings.sizeX) .. "x" .. tostring(data.settings.sizeZ))
    print("Y:      " .. tostring(data.settings.yMin) .. ".." .. tostring(data.settings.yMax)
      .. " -> dstYBase=" .. tostring(data.settings.dstYBase))
  end
  print("Active: " .. tostring(name == activeSceneName))
  pause()
end

local function unloadLoadedScene()
  local name = chooseLoadedScene("Unload loaded scene")
  if not name then return end
  term.clear()
  term.setCursor(1, 1)
  print("Unload loaded scene: " .. name)
  print("")
  local sure = promptBool("Are you sure", false)
  if not sure then
    print("Cancelled.")
    return pause()
  end
  loadedScenes[name] = nil
  rebuildSceneOrder()
  print("Unloaded: " .. name)
  pause()
end

local function drawScan()
  cfg.sizeX = clamp(math.floor(cfg.sizeX), 1, 48)
  cfg.sizeZ = clamp(math.floor(cfg.sizeZ), 1, 48)
  cfg.yMin = clamp(math.floor(cfg.yMin), -32, 31)
  cfg.yMax = clamp(math.floor(cfg.yMax), -32, 31)

  if cfg.yMin > cfg.yMax then
    cfg.yMin, cfg.yMax = cfg.yMax, cfg.yMin
  end

  local height = cfg.yMax - cfg.yMin + 1
  if height > 32 then
    cfg.yMax = cfg.yMin + 31
  end

  cfg.dstYBase = clamp(math.floor(cfg.dstYBase), 1, 32)

  term.clear()
  term.setCursor(1, 1)
  print("Scanning...")
  print(string.format("mode=%s  x=%d..%d  z=%d..%d  y=%d..%d",
    cfg.mode,
    cfg.offsetX, cfg.offsetX + cfg.sizeX - 1,
    cfg.offsetZ, cfg.offsetZ + cfg.sizeZ - 1,
    cfg.yMin, cfg.yMax))
  print(string.format("projector depth=%d  scale=%.2f", holoDepth(), cfg.scale))

  h.clear()
  pcall(h.setScale, cfg.scale)
  setPalette()

  local total = 0
  local scanData = buildScanData(0)

  for hx = 1, cfg.sizeX do
    local rx = cfg.offsetX + hx - 1
    for hz = 1, cfg.sizeZ do
      local rz = cfg.offsetZ + hz - 1
      local col = g.scan(rx, rz, false)

      for srcY = cfg.yMin, cfg.yMax do
        local idx = srcY + 33
        local val = col and col[idx] or nil
        local voxel = classify(val)

        if voxel ~= 0 then
          local hy = cfg.dstYBase + (srcY - cfg.yMin)
          if hy >= 1 and hy <= 32 then
            local drawX, drawZ = mapXZ(hx, hz)
            if drawX >= 1 and drawX <= 48 and drawZ >= 1 and drawZ <= 48 then
              h.set(drawX, hy, drawZ, voxel)
              table.insert(scanData.voxels, {x = drawX, y = hy, z = drawZ, v = voxel})
              total = total + 1
            end
          end
        end
      end
    end
    term.setCursor(1, 5)
    io.write(string.format("Progress: %d/%d columns   ", hx, cfg.sizeX))
  end

  scanData.count = total
  lastScan = scanData
  addSceneToMemory("last_scan", scanData)

  term.setCursor(1, 7)
  print("Done. Voxels drawn: " .. total)
  if holoDepth() <= 1 then
    print("Tier 1 projector detected: only color1 can be shown.")
  else
    print("Tier 2 projector detected: bands/dense can use up to 3 colors.")
  end
  print("Snapshot is now in memory and can be saved.")
  pause()
end

local function clearHolo()
  h.clear()
  term.clear()
  term.setCursor(1, 1)
  print("Hologram cleared.")
  pause()
end

local function editArea()
  term.clear()
  term.setCursor(1, 1)
  print("Edit horizontal scan area")
  print("")
  cfg.offsetX = promptNumber("offsetX", cfg.offsetX, -128, 127, true, RANGE_HINTS.offsetX)
  cfg.offsetZ = promptNumber("offsetZ", cfg.offsetZ, -128, 127, true, RANGE_HINTS.offsetZ)
  cfg.sizeX   = promptNumber("sizeX",   cfg.sizeX,   1, 48, true, RANGE_HINTS.sizeX)
  cfg.sizeZ   = promptNumber("sizeZ",   cfg.sizeZ,   1, 48, true, RANGE_HINTS.sizeZ)
  saveCfg()
end

local function editVertical()
  term.clear()
  term.setCursor(1, 1)
  print("Edit vertical scan range")
  print("")
  cfg.yMin = promptNumber("yMin", cfg.yMin, -32, 31, true, RANGE_HINTS.yMin)
  cfg.yMax = promptNumber("yMax", cfg.yMax, -32, 31, true, RANGE_HINTS.yMax)
  cfg.dstYBase = promptNumber("dstYBase", cfg.dstYBase, 1, 32, true, RANGE_HINTS.dstYBase)
  saveCfg()
end

local function editThresholds()
  term.clear()
  term.setCursor(1, 1)
  print("Edit thresholds")
  print("")
  cfg.airMax = promptNumber("airMax", cfg.airMax, -10, 10, false, RANGE_HINTS.airMax)
  cfg.denseMin = promptNumber("denseMin", cfg.denseMin, -10, 999999, false, RANGE_HINTS.denseMin)
  saveCfg()
end

local function editView()
  term.clear()
  term.setCursor(1, 1)
  print("Edit projector/view settings")
  print("")
  print("scale range: " .. RANGE_HINTS.scale)
  cfg.center = promptBool("center", cfg.center)
  cfg.flipX = promptBool("flipX", cfg.flipX)
  cfg.flipZ = promptBool("flipZ", cfg.flipZ)
  cfg.swapXZ = promptBool("swapXZ", cfg.swapXZ)
  cfg.scale = promptNumber("scale", cfg.scale, 0.33, 3, false, RANGE_HINTS.scale)
  saveCfg()
end

local function editColors()
  term.clear()
  term.setCursor(1, 1)
  print("Edit palette colors")
  print("")
  print("Projector color depth: " .. holoDepth())
  if holoDepth() <= 1 then
    print("This is a tier 1 projector: only color1 is visible.")
  else
    print("This is a tier 2 projector: color1/color2/color3 are available.")
  end
  print("")
  cfg.color1 = promptHex("color1", cfg.color1)
  cfg.color2 = promptHex("color2", cfg.color2)
  cfg.color3 = promptHex("color3", cfg.color3)
  saveCfg()
end

local function resetDefaults()
  cfg = {}
  copyDefaults()
  saveCfg()
  term.clear()
  term.setCursor(1, 1)
  print("Config reset to defaults.")
  pause()
end

local function showHelp()
  term.clear()
  term.setCursor(1, 1)
  print("Geo Local UI v5 - Help")
  print("----------------------")
  print("Modes:")
  print("  solid : show non-air blocks")
  print("  void  : show air/caves")
  print("  dense : show only high-hardness blocks")
  print("  bands : 1/2/3-color density bands on tier 2 projectors")
  print("")
  print("Ranges:")
  print("  offsetX, offsetZ : " .. RANGE_HINTS.offsetX)
  print("  sizeX, sizeZ     : " .. RANGE_HINTS.sizeX)
  print("  yMin, yMax       : " .. RANGE_HINTS.yMin)
  print("  dstYBase         : " .. RANGE_HINTS.dstYBase)
  print("  scale            : " .. RANGE_HINTS.scale)
  print("  airMax           : " .. RANGE_HINTS.airMax)
  print("  denseMin         : " .. RANGE_HINTS.denseMin)
  print("  colors           : " .. RANGE_HINTS.color)
  print("")
  print("Networking:")
  print("  - Put geo_projector_node_v1.lua on any remote projector computer.")
  print("  - Use D to discover projectors on port " .. tostring(NET_PORT) .. ".")
  print("  - Use T to send the active loaded scene to one projector.")
  print("  - Use B to broadcast the active loaded scene to all known projectors.")
  print("  - Use M to rename a projector alias locally on this controller.")
  print("")
  print("Notes:")
  print("  - This is the first networking step only: one controller, many display nodes.")
  print("  - Keep using this exact local UI for scanning/saving/loading.")
  print("  - If the map looks mirrored locally, toggle flipX/flipZ/swapXZ.")
  pause()
end

local function saveLastScan()
  term.clear()
  term.setCursor(1, 1)
  if not lastScan then
    print("No scan in memory yet. Run a scan first.")
    return pause()
  end

  ensureSnapshotDir()
  print("Save last scan")
  print("")
  local suggested = computer.uptime and ("scan_" .. tostring(math.floor(computer.uptime()))) or "scan_1"
  local name = promptString("Snapshot name", suggested, "letters/numbers/_/-/. are safest")
  if not name or name == "" then
    print("Cancelled.")
    return pause()
  end

  local path = snapshotPath(name)
  lastScan.name = sanitizeName(name)
  addSceneToMemory(lastScan.name, lastScan)
  lastScan.savedAt = os.time and os.time() or nil
  lastScan.projectorDepth = holoDepth()
  lastScan.settings.scale = cfg.scale
  lastScan.settings.color1 = cfg.color1
  lastScan.settings.color2 = cfg.color2
  lastScan.settings.color3 = cfg.color3

  local f, err = io.open(path, "w")
  if not f then
    print("Failed to save snapshot: " .. tostring(err))
    return pause()
  end
  f:write(serialization.serialize(lastScan))
  f:close()

  print("")
  print("Saved to: " .. path)
  print("Voxel count: " .. tostring(lastScan.count or #lastScan.voxels))
  pause()
end

local function chooseSnapshot(actionText)
  ensureSnapshotDir()
  local files = listSnapshotFiles()
  term.clear()
  term.setCursor(1, 1)
  print(actionText)
  print(string.rep("-", #actionText))
  if #files == 0 then
    print("No snapshots found in " .. SNAP_DIR)
    pause()
    return nil
  end
  for i = 1, #files do
    print(string.format("%2d  %s", i, files[i]))
  end
  print("")
  io.write("Choose number (blank to cancel): ")
  local s = io.read()
  if not s or s == "" then return nil end
  local n = tonumber(s)
  if not n then return nil end
  n = math.floor(n)
  if n < 1 or n > #files then return nil end
  return files[n]
end

local function loadSnapshot()
  local file = chooseSnapshot("Load snapshot")
  if not file then return end

  local path = SNAP_DIR .. "/" .. file
  local f, err = io.open(path, "r")
  if not f then
    term.clear()
    term.setCursor(1, 1)
    print("Failed to open snapshot: " .. tostring(err))
    return pause()
  end
  local raw = f:read("*a")
  f:close()

  local ok, data = pcall(serialization.unserialize, raw)
  if not ok or type(data) ~= "table" then
    term.clear()
    term.setCursor(1, 1)
    print("Snapshot file is invalid.")
    return pause()
  end

  if data.settings then
    if data.settings.scale ~= nil then cfg.scale = data.settings.scale end
    if data.settings.color1 ~= nil then cfg.color1 = data.settings.color1 end
    if data.settings.color2 ~= nil then cfg.color2 = data.settings.color2 end
    if data.settings.color3 ~= nil then cfg.color3 = data.settings.color3 end
  end

  local okRender, result = renderSnapshotData(data)
  term.clear()
  term.setCursor(1, 1)
  if not okRender then
    print("Failed to render snapshot: " .. tostring(result))
  else
    local sceneName = sanitizeName((data.name and tostring(data.name)) or file:gsub("%.scan$", ""))
    addSceneToMemory(sceneName, data)
    print("Loaded snapshot: " .. tostring(file))
    print("Loaded into memory as: " .. tostring(sceneName))
    print("Voxels drawn: " .. tostring(result))
    lastScan = data
  end
  pause()
end

local function deleteSnapshot()
  local file = chooseSnapshot("Delete snapshot")
  if not file then return end

  term.clear()
  term.setCursor(1, 1)
  print("Delete snapshot: " .. file)
  print("")
  local sure = promptBool("Are you sure", false)
  if not sure then
    print("Cancelled.")
    return pause()
  end

  local path = SNAP_DIR .. "/" .. file
  local ok, err = filesystem.remove(path)
  if ok == false then
    print("Failed to delete: " .. tostring(err))
  else
    print("Deleted: " .. file)
  end
  pause()
end

local function snapshotInfo()
  local file = chooseSnapshot("Snapshot info")
  if not file then return end

  local path = SNAP_DIR .. "/" .. file
  local f = io.open(path, "r")
  if not f then
    term.clear()
    term.setCursor(1, 1)
    print("Failed to open snapshot.")
    return pause()
  end
  local raw = f:read("*a")
  f:close()

  local ok, data = pcall(serialization.unserialize, raw)
  term.clear()
  term.setCursor(1, 1)
  if not ok or type(data) ~= "table" then
    print("Snapshot file is invalid.")
    return pause()
  end

  print("Snapshot info")
  print("-------------")
  print("File:   " .. file)
  print("Name:   " .. tostring(data.name or "(none)"))
  print("Count:  " .. tostring(data.count or (data.voxels and #data.voxels) or 0))
  print("Format: " .. tostring(data.format or "unknown"))
  if data.settings then
    print("Mode:   " .. tostring(data.settings.mode))
    print("Area:   x=" .. tostring(data.settings.offsetX) .. " z=" .. tostring(data.settings.offsetZ)
      .. " size=" .. tostring(data.settings.sizeX) .. "x" .. tostring(data.settings.sizeZ))
    print("Y:      " .. tostring(data.settings.yMin) .. ".." .. tostring(data.settings.yMax)
      .. " -> dstYBase=" .. tostring(data.settings.dstYBase))
  end
  pause()
end

local function loadProjectorDb()
  knownProjectors = {}
  local f = io.open(PROJECTOR_DB_PATH, "r")
  if not f then return end
  local raw = f:read("*a")
  f:close()
  local ok, data = pcall(serialization.unserialize, raw)
  if ok and type(data) == "table" then
    knownProjectors = data
  end
end

local function saveProjectorDb()
  local f, err = io.open(PROJECTOR_DB_PATH, "w")
  if not f then
    return false, err
  end
  f:write(serialization.serialize(knownProjectors))
  f:close()
  return true
end

local function projectorDisplayName(p)
  if not p then return "(unknown)" end
  return tostring(p.alias or p.label or p.nodeId or p.address or "(unknown)")
end

local function rebuildProjectorOrder()
  projectorOrder = {}
  for addr, data in pairs(knownProjectors) do
    if type(data) == "table" then
      data.address = addr
      table.insert(projectorOrder, addr)
    end
  end
  table.sort(projectorOrder, function(a, b)
    local pa, pb = knownProjectors[a], knownProjectors[b]
    local na = string.lower(projectorDisplayName(pa))
    local nb = string.lower(projectorDisplayName(pb))
    if na == nb then return a < b end
    return na < nb
  end)
end

local function netOpen()
  if not modem then return false, "No modem found" end
  pcall(modem.open, NET_PORT)
  return true
end

local function netSend(addr, packet)
  if not modem then return false, "No modem found" end
  local payload = serialization.serialize(packet)
  local ok, err = pcall(modem.send, addr, NET_PORT, payload)
  if not ok then
    return false, err
  end
  return true
end

local function netBroadcast(packet)
  if not modem then return false, "No modem found" end
  local payload = serialization.serialize(packet)
  local ok, err = pcall(modem.broadcast, NET_PORT, payload)
  if not ok then
    return false, err
  end
  return true
end

local function parseNetPayload(msg)
  if type(msg) ~= "string" then return nil end
  local ok, data = pcall(serialization.unserialize, msg)
  if ok and type(data) == "table" then
    return data
  end
  return nil
end

local function updateKnownProjector(fromAddr, packet)
  if type(packet) ~= "table" then return end
  local p = knownProjectors[fromAddr] or {}
  p.address = fromAddr
  p.nodeId = packet.nodeId or p.nodeId or fromAddr
  p.label = packet.label or p.label or packet.nodeId
  p.depth = packet.depth or p.depth or 1
  p.width = packet.width or p.width or 48
  p.height = packet.height or p.height or 32
  p.lastSeen = os.time and os.time() or math.floor(computer.uptime())
  if p.alias == nil and p.label ~= nil then
    p.alias = p.label
  end
  knownProjectors[fromAddr] = p
end

local function discoverProjectors()
  term.clear()
  term.setCursor(1, 1)
  local ok, err = netOpen()
  if not ok then
    print("Networking unavailable: " .. tostring(err))
    return pause()
  end

  print("Discovering projectors on port " .. tostring(NET_PORT) .. "...")
  netBroadcast({
    t = "proj.discover",
    replyPort = NET_PORT,
    from = "geo_local_ui_v5",
  })

  local deadline = computer.uptime() + 2.0
  local count = 0
  while computer.uptime() < deadline do
    local timeout = deadline - computer.uptime()
    local evName, localAddr, fromAddr, port, dist, msg = event.pull(timeout, "modem_message")
    if evName then
      local packet = parseNetPayload(msg)
      if packet and packet.t == "proj.announce" then
        updateKnownProjector(fromAddr, packet)
        count = count + 1
      end
    end
  end

  rebuildProjectorOrder()
  saveProjectorDb()

  term.clear()
  term.setCursor(1, 1)
  print("Discovery complete.")
  print("Projectors heard this pass: " .. tostring(count))
  print("Projectors known total: " .. tostring(#projectorOrder))
  if #projectorOrder > 0 then
    print("")
    for i = 1, #projectorOrder do
      local addr = projectorOrder[i]
      local p = knownProjectors[addr]
      print(string.format("%2d  %s  [depth=%s]  %s", i, projectorDisplayName(p), tostring(p.depth or "?"), addr))
    end
  end
  pause()
end

local function chooseProjector(actionText, allowAll)
  rebuildProjectorOrder()
  term.clear()
  term.setCursor(1, 1)
  print(actionText)
  print(string.rep("-", #actionText))

  if #projectorOrder == 0 then
    print("No known projectors. Use D to discover first.")
    pause()
    return nil
  end

  if allowAll then
    print("A  All known projectors")
  end

  for i = 1, #projectorOrder do
    local addr = projectorOrder[i]
    local p = knownProjectors[addr]
    print(string.format("%2d  %s  [depth=%s]  %s", i, projectorDisplayName(p), tostring(p.depth or "?"), addr))
  end
  print("")
  io.write("Choose number" .. (allowAll and " or A" or "") .. " (blank to cancel): ")
  local s = io.read()
  if not s or s == "" then return nil end
  s = tostring(s)
  if allowAll and s:lower() == "a" then
    return "__all__"
  end
  local n = tonumber(s)
  if not n then return nil end
  n = math.floor(n)
  if n < 1 or n > #projectorOrder then return nil end
  return projectorOrder[n]
end

local function remoteProjectorInfo()
  local target = chooseProjector("Projector info", false)
  if not target then return end
  local p = knownProjectors[target]
  term.clear()
  term.setCursor(1, 1)
  print("Projector info")
  print("--------------")
  print("Alias:    " .. tostring(p.alias or "(none)"))
  print("Label:    " .. tostring(p.label or "(none)"))
  print("Node ID:  " .. tostring(p.nodeId or "(none)"))
  print("Address:  " .. tostring(target))
  print("Depth:    " .. tostring(p.depth or "?"))
  print("Last seen:" .. tostring(p.lastSeen or "?"))
  pause()
end

local function renameProjectorAlias()
  local target = chooseProjector("Rename projector alias", false)
  if not target then return end
  local p = knownProjectors[target]
  term.clear()
  term.setCursor(1, 1)
  print("Rename projector alias")
  print("----------------------")
  print("Address: " .. target)
  print("Current alias: " .. tostring(p.alias or p.label or p.nodeId))
  print("")
  local newAlias = promptString("New alias", p.alias or p.label or p.nodeId, "leave blank to keep current")
  if newAlias and newAlias ~= "" then
    p.alias = newAlias
    knownProjectors[target] = p
    rebuildProjectorOrder()
    saveProjectorDb()
    print("Saved.")
  else
    print("Cancelled.")
  end
  pause()
end

local function clearRemoteProjector()
  local target = chooseProjector("Clear remote projector", true)
  if not target then return end

  term.clear()
  term.setCursor(1, 1)
  local ok, err = netOpen()
  if not ok then
    print("Networking unavailable: " .. tostring(err))
    return pause()
  end

  if target == "__all__" then
    for i = 1, #projectorOrder do
      local addr = projectorOrder[i]
      netSend(addr, {t = "proj.clear"})
    end
    print("Clear command sent to all known projectors.")
  else
    netSend(target, {t = "proj.clear"})
    print("Clear command sent to: " .. projectorDisplayName(knownProjectors[target]))
  end
  pause()
end

local function activeSceneData()
  if activeSceneName and loadedScenes[activeSceneName] then
    return loadedScenes[activeSceneName], activeSceneName
  end
  if lastScan then
    return lastScan, lastScan.name or "last_scan"
  end
  return nil, nil
end

local function awaitRenderAck(targetAddr, transferId, timeoutSeconds)
  local deadline = computer.uptime() + (timeoutSeconds or 5)
  while computer.uptime() < deadline do
    local timeout = deadline - computer.uptime()
    local evName, localAddr, fromAddr, port, dist, msg = event.pull(timeout, "modem_message")
    if evName and fromAddr == targetAddr then
      local packet = parseNetPayload(msg)
      if packet then
        if packet.t == "proj.announce" then
          updateKnownProjector(fromAddr, packet)
        elseif packet.t == "proj.rendered" and packet.transferId == transferId then
          return true, packet
        elseif packet.t == "proj.error" and packet.transferId == transferId then
          return false, packet.error or "remote projector error"
        end
      end
    end
  end
  return false, "timeout waiting for projector ack"
end

local function sendSceneToProjector(targetAddr)
  local scene, sceneName = activeSceneData()
  if not scene then
    term.clear()
    term.setCursor(1, 1)
    print("No active scene to send. Scan or load a snapshot first.")
    return pause()
  end

  local ok, err = netOpen()
  if not ok then
    term.clear()
    term.setCursor(1, 1)
    print("Networking unavailable: " .. tostring(err))
    return pause()
  end

  local transferId = tostring(math.floor(computer.uptime() * 1000)) .. "-" .. tostring(math.random(1000, 9999))
  local beginPacket = {
    t = "proj.begin",
    transferId = transferId,
    sceneName = sceneName,
    settings = {
      scale = scene.settings and scene.settings.scale or cfg.scale,
      color1 = scene.settings and scene.settings.color1 or cfg.color1,
      color2 = scene.settings and scene.settings.color2 or cfg.color2,
      color3 = scene.settings and scene.settings.color3 or cfg.color3,
    },
    count = scene.count or (scene.voxels and #scene.voxels) or 0,
  }

  term.clear()
  term.setCursor(1, 1)
  print("Sending scene to projector...")
  print("Target: " .. projectorDisplayName(knownProjectors[targetAddr]))
  print("Scene:  " .. tostring(sceneName))
  print("Voxels: " .. tostring(beginPacket.count))

  local okBegin, errBegin = netSend(targetAddr, beginPacket)
  if not okBegin then
    print("Failed to send begin packet: " .. tostring(errBegin))
    return pause()
  end

  local voxels = scene.voxels or {}
  local sent = 0
  for i = 1, #voxels, NET_CHUNK_VOXELS do
    local chunk = {}
    local last = math.min(i + NET_CHUNK_VOXELS - 1, #voxels)
    for j = i, last do
      chunk[#chunk + 1] = voxels[j]
    end
    local okChunk, errChunk = netSend(targetAddr, {
      t = "proj.chunk",
      transferId = transferId,
      voxels = chunk,
    })
    if not okChunk then
      print("Failed on chunk send: " .. tostring(errChunk))
      return pause()
    end
    sent = last
    term.setCursor(1, 5)
    io.write(string.format("Progress: %d/%d voxels   ", sent, #voxels))
    os.sleep(0.02)
  end

  local okEnd, errEnd = netSend(targetAddr, {
    t = "proj.end",
    transferId = transferId,
  })
  if not okEnd then
    print("Failed to send end packet: " .. tostring(errEnd))
    return pause()
  end

  local okAck, ack = awaitRenderAck(targetAddr, transferId, 6)
  term.setCursor(1, 7)
  if okAck then
    print("Remote projector rendered scene.")
    print("Reported voxels drawn: " .. tostring(ack.count or "?"))
  else
    print("No clean ack from projector: " .. tostring(ack))
    print("The scene may still have rendered, but controller did not confirm it.")
  end
  saveProjectorDb()
  pause()
end

local function sendActiveSceneToOne()
  local target = chooseProjector("Send active scene to projector", false)
  if not target then return end
  sendSceneToProjector(target)
end

local function broadcastActiveScene()
  rebuildProjectorOrder()
  if #projectorOrder == 0 then
    term.clear()
    term.setCursor(1, 1)
    print("No known projectors. Use D to discover first.")
    return pause()
  end

  term.clear()
  term.setCursor(1, 1)
  print("Broadcast active scene to all known projectors?")
  print("")
  if not promptBool("Are you sure", false) then
    print("Cancelled.")
    return pause()
  end

  for i = 1, #projectorOrder do
    sendSceneToProjector(projectorOrder[i])
  end
end

local function showStatus()
  term.clear()
  term.setCursor(1, 1)
  print("Geo Local UI v5")
  print("---------------")
  print("CURRENT MODE: " .. string.upper(cfg.mode))
  print("Projector depth: " .. holoDepth() .. (holoDepth() > 1 and " (tier 2 / multi-color)" or " (tier 1 / single-color)"))
  print("Network:   " .. (modem and ("modem ready on port " .. tostring(NET_PORT)) or "no modem"))
  print("Mode list: " .. RANGE_HINTS.mode)
  print("Area:      x=" .. cfg.offsetX .. " z=" .. cfg.offsetZ .. " size=" .. cfg.sizeX .. "x" .. cfg.sizeZ)
  print("Y range:   " .. cfg.yMin .. " .. " .. cfg.yMax .. "  -> dstYBase=" .. cfg.dstYBase)
  print("View:      center=" .. tostring(cfg.center)
      .. " flipX=" .. tostring(cfg.flipX)
      .. " flipZ=" .. tostring(cfg.flipZ)
      .. " swapXZ=" .. tostring(cfg.swapXZ))
  print("Threshold: airMax=" .. tostring(cfg.airMax) .. " denseMin=" .. tostring(cfg.denseMin))
  print("Scale:     " .. tostring(cfg.scale))
  print(string.format("Colors:    1=0x%06X  2=0x%06X  3=0x%06X", cfg.color1, cfg.color2, cfg.color3))
  print("Snapshots: " .. tostring(#listSnapshotFiles()) .. " saved" .. (lastScan and " | last scan in memory" or " | no scan in memory"))
  print("Scenes:    " .. tostring(#loadedSceneOrder) .. " loaded" .. (activeSceneName and (" | active=" .. activeSceneName) or " | no active scene"))
  print("Projectors:" .. tostring(#projectorOrder) .. " known")
  print("")
  print("1  Scan now")
  print("2  Cycle mode")
  print("3  Edit area")
  print("4  Edit vertical range")
  print("5  Edit thresholds")
  print("6  Edit view/orientation")
  print("7  Edit colors")
  print("8  Clear local hologram")
  print("9  Save config")
  print("S  Save last scan snapshot")
  print("L  Load snapshot")
  print("I  Snapshot info")
  print("D  Discover remote projectors")
  print("A  Activate/render loaded scene")
  print("N  Loaded scene info")
  print("U  Unload loaded scene")
  print("T  Send active scene to one projector")
  print("B  Send active scene to all known projectors")
  print("M  Rename projector alias")
  print("P  Projector info")
  print("X  Clear remote projector(s)")
  print("H  Help / ranges")
  print("R  Reset defaults")
  print("0  Quit")
  print("")
  io.write("> ")
end

math.randomseed(math.floor((computer.uptime() or 0) * 1000))
ensureSnapshotDir()
loadCfg()
loadProjectorDb()
rebuildProjectorOrder()
netOpen()

while true do
  showStatus()
  local choice = io.read()
  if choice then choice = tostring(choice):lower() end

  if choice == "1" then
    drawScan()
  elseif choice == "2" then
    nextMode()
    saveCfg()
  elseif choice == "3" then
    editArea()
  elseif choice == "4" then
    editVertical()
  elseif choice == "5" then
    editThresholds()
  elseif choice == "6" then
    editView()
  elseif choice == "7" then
    editColors()
  elseif choice == "8" then
    clearHolo()
  elseif choice == "9" then
    term.clear()
    term.setCursor(1, 1)
    if saveCfg() then
      print("Config saved to " .. CFG_PATH)
    else
      print("Failed to save config.")
    end
    pause()
  elseif choice == "s" then
    saveLastScan()
  elseif choice == "l" then
    loadSnapshot()
  elseif choice == "i" then
    snapshotInfo()
  elseif choice == "d" then
    discoverProjectors()
  elseif choice == "a" then
    activateLoadedScene()
  elseif choice == "n" then
    loadedSceneInfo()
  elseif choice == "u" then
    unloadLoadedScene()
  elseif choice == "t" then
    sendActiveSceneToOne()
  elseif choice == "b" then
    broadcastActiveScene()
  elseif choice == "m" then
    renameProjectorAlias()
  elseif choice == "p" then
    remoteProjectorInfo()
  elseif choice == "x" then
    clearRemoteProjector()
  elseif choice == "h" then
    showHelp()
  elseif choice == "r" then
    resetDefaults()
  elseif choice == "0" then
    term.clear()
    term.setCursor(1, 1)
    break
  end
end
