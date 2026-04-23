local component = require("component")
local event = require("event")
local serialization = require("serialization")
local computer = require("computer")
local term = require("term")

--------------------------------------------------------------------------------
-- HOLO-NET PROJECTOR NODE v3.1
-- Built-in persistent config editor.
--
-- Usage:
--   lua projector_node.lua         -- normal run (press S during startup prompt)
--   lua projector_node.lua setup   -- open config editor
--   lua projector_node.lua showcfg -- print current config
--   lua projector_node.lua resetcfg-- restore defaults and save
--------------------------------------------------------------------------------

local CFG_FILE = "/home/holonet_projector.cfg"

local DEFAULT_CFG = {
  NODE_ID = "projector-1",
  NODE_LABEL = "Projector 1",
  PORT = 3413,
  MODEM_STRENGTH = 400,

  TILE_X = 0,
  TILE_Y = 48,
  TILE_Z = 0,
  WIDTH = 48,
  HEIGHT = 32,
  DEPTH = 48,

  SCALE = 1.0,
  TRANSLATE_X = 0,
  TRANSLATE_Y = 0,
  TRANSLATE_Z = 0,

  PALETTE = {
    [1] = 0x00FFFF,
    [2] = 0x00FF00,
    [3] = 0xFF4040,
  },

  ANNOUNCE_INTERVAL = 10,
}

local function cloneTable(src)
  if type(src) ~= "table" then return src end
  local dst = {}
  for k, v in pairs(src) do dst[k] = cloneTable(v) end
  return dst
end

local function mergeInto(dst, src)
  if type(dst) ~= "table" or type(src) ~= "table" then return dst end
  for k, v in pairs(src) do
    if type(v) == "table" and type(dst[k]) == "table" then
      mergeInto(dst[k], v)
    else
      dst[k] = v
    end
  end
  return dst
end

local function trim(s)
  return tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function loadConfig()
  local cfg = cloneTable(DEFAULT_CFG)
  local f = io.open(CFG_FILE, "r")
  if f then
    local text = f:read("*a")
    f:close()
    local ok, data = pcall(serialization.unserialize, text)
    if ok and type(data) == "table" then
      mergeInto(cfg, data)
    end
  end
  return cfg
end

local function saveConfig(cfg)
  local f, err = io.open(CFG_FILE, "w")
  if not f then return false, err end
  f:write(serialization.serialize(cfg))
  f:close()
  return true
end

local CFG = loadConfig()

local function clear()
  pcall(term.clear)
  pcall(term.setCursor, 1, 1)
end

local function ask(prompt, default)
  io.write(prompt)
  if default ~= nil then io.write(" [" .. tostring(default) .. "]") end
  io.write(": ")
  local line = term.read() or ""
  line = trim((line:gsub("\n", "")))
  if line == "" then return default end
  return line
end

local function askNumber(prompt, default)
  local v = ask(prompt, default)
  local n = tonumber(v)
  if n == nil then return default end
  return n
end

local function askHex(prompt, default)
  local shown = string.format("0x%06X", tonumber(default) or 0)
  local v = trim(ask(prompt, shown) or "")
  if v == "" then return default end
  v = v:gsub("^0x", "")
  local n = tonumber(v, 16)
  if not n then return default end
  return n
end

local function pressAnyKey()
  print()
  print("Press any key to continue...")
  event.pull("key_down")
end

local function showConfig(cfg)
  clear()
  print("HOLO-NET PROJECTOR NODE v3.1")
  print(string.rep("-", 60))
  print("Config file      : " .. CFG_FILE)
  print("NODE_ID          : " .. tostring(cfg.NODE_ID))
  print("NODE_LABEL       : " .. tostring(cfg.NODE_LABEL))
  print("PORT             : " .. tostring(cfg.PORT))
  print("MODEM_STRENGTH   : " .. tostring(cfg.MODEM_STRENGTH))
  print("TILE_X/Y/Z       : " .. tostring(cfg.TILE_X) .. ", " .. tostring(cfg.TILE_Y) .. ", " .. tostring(cfg.TILE_Z))
  print("WIDTH/HEIGHT/DEPTH: " .. tostring(cfg.WIDTH) .. ", " .. tostring(cfg.HEIGHT) .. ", " .. tostring(cfg.DEPTH))
  print("SCALE            : " .. tostring(cfg.SCALE))
  print("TRANSLATE X/Y/Z  : " .. tostring(cfg.TRANSLATE_X) .. ", " .. tostring(cfg.TRANSLATE_Y) .. ", " .. tostring(cfg.TRANSLATE_Z))
  print("ANNOUNCE_INTERVAL: " .. tostring(cfg.ANNOUNCE_INTERVAL))
  print("PALETTE          : " .. string.format("1=%06X 2=%06X 3=%06X",
    tonumber(cfg.PALETTE[1]) or 0,
    tonumber(cfg.PALETTE[2]) or 0,
    tonumber(cfg.PALETTE[3]) or 0))
end

local function editIdentity(cfg)
  clear()
  print("Projector identity / network")
  print(string.rep("-", 40))
  cfg.NODE_ID = trim(ask("Node ID", cfg.NODE_ID))
  cfg.NODE_LABEL = trim(ask("Node label", cfg.NODE_LABEL))
  cfg.PORT = math.floor(askNumber("Port", cfg.PORT) or cfg.PORT)
  cfg.MODEM_STRENGTH = askNumber("Wireless strength", cfg.MODEM_STRENGTH)
  cfg.ANNOUNCE_INTERVAL = math.max(1, math.floor(askNumber("Announce interval", cfg.ANNOUNCE_INTERVAL) or cfg.ANNOUNCE_INTERVAL))
end

local function editTile(cfg)
  clear()
  print("Projector tile / bounds")
  print(string.rep("-", 40))
  print("These are global world-space coordinates for this projector tile.")
  cfg.TILE_X = askNumber("Tile X", cfg.TILE_X)
  cfg.TILE_Y = askNumber("Tile Y", cfg.TILE_Y)
  cfg.TILE_Z = askNumber("Tile Z", cfg.TILE_Z)
  cfg.WIDTH = math.max(1, math.floor(askNumber("Width", cfg.WIDTH) or cfg.WIDTH))
  cfg.HEIGHT = math.max(1, math.floor(askNumber("Height", cfg.HEIGHT) or cfg.HEIGHT))
  cfg.DEPTH = math.max(1, math.floor(askNumber("Depth", cfg.DEPTH) or cfg.DEPTH))
end

local function editDisplay(cfg)
  clear()
  print("Projector display settings")
  print(string.rep("-", 40))
  cfg.SCALE = askNumber("Scale", cfg.SCALE)
  cfg.TRANSLATE_X = askNumber("Translate X", cfg.TRANSLATE_X)
  cfg.TRANSLATE_Y = askNumber("Translate Y", cfg.TRANSLATE_Y)
  cfg.TRANSLATE_Z = askNumber("Translate Z", cfg.TRANSLATE_Z)
  cfg.PALETTE[1] = askHex("Palette 1 hex", cfg.PALETTE[1])
  cfg.PALETTE[2] = askHex("Palette 2 hex", cfg.PALETTE[2])
  cfg.PALETTE[3] = askHex("Palette 3 hex", cfg.PALETTE[3])
end

local function runSetupMenu(cfg)
  while true do
    showConfig(cfg)
    print(string.rep("-", 60))
    print("1) Identity / network")
    print("2) Tile / bounds")
    print("3) Display settings")
    print("4) Save config")
    print("5) Save and continue")
    print("6) Reset to defaults")
    print("7) Exit without saving")
    print()
    local choice = trim(ask("Choice", "5") or "5")
    if choice == "1" then
      editIdentity(cfg)
    elseif choice == "2" then
      editTile(cfg)
    elseif choice == "3" then
      editDisplay(cfg)
    elseif choice == "4" then
      local ok, err = saveConfig(cfg)
      clear()
      print(ok and "Config saved." or ("Save failed: " .. tostring(err)))
      pressAnyKey()
    elseif choice == "5" then
      local ok, err = saveConfig(cfg)
      clear()
      print(ok and "Config saved. Starting projector..." or ("Save failed: " .. tostring(err)))
      if not ok then pressAnyKey() end
      return ok
    elseif choice == "6" then
      cfg = cloneTable(DEFAULT_CFG)
      CFG = cfg
      local ok, err = saveConfig(cfg)
      clear()
      print(ok and "Defaults restored and saved." or ("Reset save failed: " .. tostring(err)))
      pressAnyKey()
    elseif choice == "7" then
      return false
    end
  end
end

local function maybeStartupSetup(cfg)
  clear()
  print("HOLO-NET PROJECTOR NODE v3.1")
  print("Config: " .. CFG_FILE)
  print("Press S within 3 seconds for setup, or wait to start.")
  local name, _, char = event.pull(3, "key_down")
  if name == "key_down" and (char == string.byte("s") or char == string.byte("S")) then
    return runSetupMenu(cfg)
  end
  return true
end

local argv = _G.arg or {}
local cmd = trim(argv[1] or "")
if cmd == "showcfg" then
  showConfig(CFG)
  return
elseif cmd == "resetcfg" then
  CFG = cloneTable(DEFAULT_CFG)
  local ok, err = saveConfig(CFG)
  if ok then
    print("Projector config reset to defaults: " .. CFG_FILE)
  else
    error("Failed to reset config: " .. tostring(err))
  end
  return
elseif cmd == "setup" then
  runSetupMenu(CFG)
elseif cmd ~= "nostartprompt" then
  maybeStartupSetup(CFG)
end

local modem = component.modem
local holo = component.hologram
assert(modem, "No modem found")
assert(holo, "No hologram projector found")

modem.open(CFG.PORT)
if modem.isWireless and modem.isWireless() and modem.setStrength then
  pcall(modem.setStrength, CFG.MODEM_STRENGTH)
end

local function center(text)
  local w = 80
  if component.gpu then
    local ok, gw = pcall(component.gpu.getResolution)
    if ok then w = gw end
  end
  local pad = math.max(0, math.floor((w - #text) / 2))
  return string.rep(" ", pad) .. text
end

local function drawStatus(lines)
  clear()
  print(center("HOLO-NET PROJECTOR NODE v3.1"))
  print(center(CFG.NODE_ID .. " / " .. CFG.NODE_LABEL))
  print(string.rep("-", 60))
  print("Config file       :", CFG_FILE)
  print("Tile origin       :", CFG.TILE_X, CFG.TILE_Y, CFG.TILE_Z)
  print("Tile size         :", CFG.WIDTH, CFG.HEIGHT, CFG.DEPTH)
  print("Scale / offset    :", CFG.SCALE, CFG.TRANSLATE_X, CFG.TRANSLATE_Y, CFG.TRANSLATE_Z)
  print("Setup             : lua projector_node.lua setup")
  print(string.rep("-", 60))
  if lines then
    for i = 1, #lines do
      print(lines[i])
    end
  end
end

local function sendPacket(address, kind, payload)
  payload = payload or {}
  local blob = serialization.serialize(payload)
  return modem.send(address, CFG.PORT, "holonet", kind, blob)
end

local function announce(address)
  local packet = {
    role = "projector",
    id = CFG.NODE_ID,
    label = CFG.NODE_LABEL,
    tile = {
      x = CFG.TILE_X,
      y = CFG.TILE_Y,
      z = CFG.TILE_Z,
      w = CFG.WIDTH,
      h = CFG.HEIGHT,
      d = CFG.DEPTH,
    },
    scale = CFG.SCALE,
    depth = holo.maxDepth and holo.maxDepth() or 1,
    uptime = computer.uptime(),
  }
  if address then
    sendPacket(address, "hello", packet)
  else
    modem.broadcast(CFG.PORT, "holonet", "hello", serialization.serialize(packet))
  end
end

local currentScene = "(none)"
local applied = 0

local function applySettings()
  pcall(holo.setScale, CFG.SCALE)
  pcall(holo.setTranslation, CFG.TRANSLATE_X, CFG.TRANSLATE_Y, CFG.TRANSLATE_Z)
  for i = 1, 3 do
    if CFG.PALETTE[i] then
      pcall(holo.setPaletteColor, i, CFG.PALETTE[i])
    end
  end
end

local function resetScene(name)
  currentScene = name or "(unnamed)"
  applied = 0
  pcall(holo.clear)
  applySettings()
  drawStatus({
    "Scene         : " .. currentScene,
    "Status        : waiting for chunks",
  })
end

local function inTile(x, y, z)
  return x >= CFG.TILE_X and x < (CFG.TILE_X + CFG.WIDTH)
     and y >= CFG.TILE_Y and y < (CFG.TILE_Y + CFG.HEIGHT)
     and z >= CFG.TILE_Z and z < (CFG.TILE_Z + CFG.DEPTH)
end

local function applyChunk(payload)
  local voxels = payload.voxels or {}
  for i = 1, #voxels, 4 do
    local gx, gy, gz, v = voxels[i], voxels[i + 1], voxels[i + 2], voxels[i + 3]
    if gx ~= nil and gy ~= nil and gz ~= nil and v ~= nil and inTile(gx, gy, gz) then
      local lx = gx - CFG.TILE_X + 1
      local ly = gy - CFG.TILE_Y + 1
      local lz = gz - CFG.TILE_Z + 1
      if lx >= 1 and lx <= 48 and ly >= 1 and ly <= 32 and lz >= 1 and lz <= 48 then
        pcall(holo.set, lx, ly, lz, v)
        applied = applied + 1
      end
    end
  end

  drawStatus({
    "Scene         : " .. currentScene,
    "Status        : rendering",
    "Applied voxels: " .. tostring(applied),
    "Last batch    : " .. tostring(payload.batch or 0),
  })
end

applySettings()
resetScene("idle")
announce()
local nextAnnounce = computer.uptime() + CFG.ANNOUNCE_INTERVAL

while true do
  local timeout = math.max(0, nextAnnounce - computer.uptime())
  local ev = table.pack(event.pull(timeout, "modem_message"))

  if ev.n == 0 then
    announce()
    nextAnnounce = computer.uptime() + CFG.ANNOUNCE_INTERVAL
  else
    local _, localAddress, remoteAddress, port, distance, proto, kind, blob = table.unpack(ev, 1, ev.n)
    if port == CFG.PORT and proto == "holonet" then
      local ok, payload = pcall(serialization.unserialize, blob or "{}")
      if not ok or type(payload) ~= "table" then payload = {} end

      if kind == "announce.request" then
        announce(remoteAddress)
        nextAnnounce = computer.uptime() + CFG.ANNOUNCE_INTERVAL
      elseif kind == "project.scene.begin" then
        resetScene(payload.scene or "scene")
        nextAnnounce = computer.uptime() + CFG.ANNOUNCE_INTERVAL
      elseif kind == "project.scene.chunk" then
        applyChunk(payload)
        nextAnnounce = computer.uptime() + CFG.ANNOUNCE_INTERVAL
      elseif kind == "project.scene.end" then
        drawStatus({
          "Scene         : " .. currentScene,
          "Status        : complete",
          "Applied voxels: " .. tostring(applied),
        })
        nextAnnounce = computer.uptime() + CFG.ANNOUNCE_INTERVAL
      elseif kind == "project.clear" then
        resetScene("cleared")
        pcall(holo.clear)
        nextAnnounce = computer.uptime() + CFG.ANNOUNCE_INTERVAL
      elseif kind == "ping" then
        sendPacket(remoteAddress, "pong", {id = CFG.NODE_ID, role = "projector"})
      end
    end
  end
end
