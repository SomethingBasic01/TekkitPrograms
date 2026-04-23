
local component = require("component")
local serialization = require("serialization")
local event = require("event")
local term = require("term")
local computer = require("computer")

assert(component.isAvailable("hologram"), "No hologram projector found")
assert(component.isAvailable("modem"), "No modem found")

local h = component.hologram
local modem = component.modem

local CFG_PATH = "/home/geo_projector_node.cfg"
local PORT = 3413

local defaults = {
  nodeId = "projector_1",
  label = "Projector 1",
  scale = 1,
  color1 = 0x00FF00,
  color2 = 0x00FFFF,
  color3 = 0xFF4040,
}

local cfg = {}

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
  local f = io.open(CFG_PATH, "w")
  if not f then return false end
  f:write(serialization.serialize(cfg))
  f:close()
  return true
end

local function promptString(label, current)
  io.write(string.format("%s [%s]: ", label, tostring(current or "")))
  local s = io.read()
  if not s or s == "" then return current end
  return s
end

local function promptHex(label, current)
  io.write(string.format("%s [0x%06X]: ", label, current))
  local s = io.read()
  if not s or s == "" then return current end
  s = s:gsub("^0[xX]", "")
  local n = tonumber(s, 16)
  if not n then return current end
  if n < 0 then n = 0 end
  if n > 0xFFFFFF then n = 0xFFFFFF end
  return math.floor(n)
end

local function setupMenu()
  term.clear()
  term.setCursor(1, 1)
  print("Geo Projector Node setup")
  print("------------------------")
  cfg.nodeId = promptString("nodeId", cfg.nodeId)
  cfg.label = promptString("label", cfg.label)
  cfg.scale = tonumber(promptString("scale", cfg.scale)) or cfg.scale
  cfg.color1 = promptHex("color1", cfg.color1)
  cfg.color2 = promptHex("color2", cfg.color2)
  cfg.color3 = promptHex("color3", cfg.color3)
  saveCfg()
  print("")
  print("Saved to " .. CFG_PATH)
end

local function depth()
  if h.maxDepth then
    local ok, d = pcall(h.maxDepth)
    if ok and type(d) == "number" then return d end
  end
  return 1
end

local function setPalette(settings)
  local d = depth()
  local c1 = settings and settings.color1 or cfg.color1
  local c2 = settings and settings.color2 or cfg.color2
  local c3 = settings and settings.color3 or cfg.color3
  pcall(h.setPaletteColor, 1, c1)
  if d > 1 then
    pcall(h.setPaletteColor, 2, c2)
    pcall(h.setPaletteColor, 3, c3)
  end
end

local function announce(toAddr)
  local packet = serialization.serialize({
    t = "proj.announce",
    nodeId = cfg.nodeId,
    label = cfg.label,
    depth = depth(),
    width = 48,
    height = 32,
  })
  if toAddr then
    modem.send(toAddr, PORT, packet)
  else
    modem.broadcast(PORT, packet)
  end
end

local pending = nil
local lastScene = nil

local function renderPending(fromAddr)
  if not pending then return end
  h.clear()
  pcall(h.setScale, pending.settings and pending.settings.scale or cfg.scale)
  setPalette(pending.settings)
  local count = 0
  for i = 1, #pending.voxels do
    local v = pending.voxels[i]
    if type(v) == "table" and v.x and v.y and v.z and v.v then
      if v.x >= 1 and v.x <= 48 and v.y >= 1 and v.y <= 32 and v.z >= 1 and v.z <= 48 then
        h.set(v.x, v.y, v.z, v.v)
        count = count + 1
      end
    end
  end
  lastScene = {
    name = pending.sceneName,
    count = count,
    at = computer.uptime(),
  }
  modem.send(fromAddr, PORT, serialization.serialize({
    t = "proj.rendered",
    transferId = pending.transferId,
    count = count,
    sceneName = pending.sceneName,
  }))
  pending = nil
end

loadCfg()
if (...) == "setup" then
  setupMenu()
end

pcall(modem.open, PORT)
announce(nil)

term.clear()
term.setCursor(1, 1)
print("Geo Projector Node")
print("------------------")
print("nodeId: " .. tostring(cfg.nodeId))
print("label:  " .. tostring(cfg.label))
print("depth:  " .. tostring(depth()))
print("port:   " .. tostring(PORT))
print("")
print("Listening...")

while true do
  local evName, localAddr, fromAddr, port, dist, msg = event.pull("modem_message")
  local ok, packet = pcall(serialization.unserialize, msg)
  if ok and type(packet) == "table" then
    if packet.t == "proj.discover" then
      announce(fromAddr)
    elseif packet.t == "proj.clear" then
      h.clear()
      pending = nil
    elseif packet.t == "proj.begin" then
      pending = {
        transferId = packet.transferId,
        sceneName = packet.sceneName or "unnamed",
        settings = packet.settings or {},
        expectedCount = packet.count or 0,
        voxels = {},
      }
    elseif packet.t == "proj.chunk" then
      if pending and pending.transferId == packet.transferId and type(packet.voxels) == "table" then
        for i = 1, #packet.voxels do
          pending.voxels[#pending.voxels + 1] = packet.voxels[i]
        end
      end
    elseif packet.t == "proj.end" then
      if pending and pending.transferId == packet.transferId then
        renderPending(fromAddr)
        term.setCursor(1, 8)
        io.write("Last scene: " .. tostring(lastScene and lastScene.name or "?") .. " (" .. tostring(lastScene and lastScene.count or 0) .. " voxels)      ")
      end
    end
  end
end
