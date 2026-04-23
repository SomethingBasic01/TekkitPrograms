local component = require("component")
local event = require("event")
local serialization = require("serialization")
local computer = require("computer")
local term = require("term")

--------------------------------------------------------------------------------
-- HOLO-NET PROJECTOR NODE
-- Put this on a computer connected to:
--   * a hologram projector
--   * a wireless modem (or linked card / network path)
--
-- This projector renders only the tile defined below.
-- Build a larger stitched display by running this program on multiple projector
-- computers with different TILE_* origins and then physically arranging the
-- hologram projectors in the world.
--------------------------------------------------------------------------------

local CFG = {
  NODE_ID = "projector-1",
  PORT = 3413,
  MODEM_STRENGTH = 400,

  -- Global scene region this projector is responsible for.
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

local modem = component.modem
local holo = component.hologram
assert(modem, "No modem found")
assert(holo, "No hologram projector found")

modem.open(CFG.PORT)
if modem.isWireless and modem.isWireless() and modem.setStrength then
  pcall(modem.setStrength, CFG.MODEM_STRENGTH)
end

local function clear()
  pcall(term.clear)
  pcall(term.setCursor, 1, 1)
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
  print(center("HOLO-NET PROJECTOR NODE"))
  print(center(CFG.NODE_ID))
  print(string.rep("-", 60))
  print("Tile origin      :", CFG.TILE_X, CFG.TILE_Y, CFG.TILE_Z)
  print("Tile size        :", CFG.WIDTH, CFG.HEIGHT, CFG.DEPTH)
  print("Scale / offset   :", CFG.SCALE, CFG.TRANSLATE_X, CFG.TRANSLATE_Y, CFG.TRANSLATE_Z)
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
    "Scene        : " .. currentScene,
    "Status       : waiting for chunks",
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
    if gx and gy and gz and v and inTile(gx, gy, gz) then
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
    "Scene        : " .. currentScene,
    "Status       : rendering",
    "Applied voxels: " .. tostring(applied),
    "Last batch   : " .. tostring(payload.batch or 0),
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
        local target = payload.target
        if not target or target == "*" or target == CFG.NODE_ID then
          resetScene(payload.scene or "scene")
          nextAnnounce = computer.uptime() + CFG.ANNOUNCE_INTERVAL
        end
      elseif kind == "project.scene.chunk" then
        local target = payload.target
        if not target or target == "*" or target == CFG.NODE_ID then
          applyChunk(payload)
          nextAnnounce = computer.uptime() + CFG.ANNOUNCE_INTERVAL
        end
      elseif kind == "project.scene.end" then
        local target = payload.target
        if not target or target == "*" or target == CFG.NODE_ID then
          drawStatus({
            "Scene        : " .. currentScene,
            "Status       : complete",
            "Applied voxels: " .. tostring(applied),
          })
          nextAnnounce = computer.uptime() + CFG.ANNOUNCE_INTERVAL
        end
      elseif kind == "project.clear" then
        local target = payload.target
        if not target or target == "*" or target == CFG.NODE_ID then
          resetScene("cleared")
          pcall(holo.clear)
          nextAnnounce = computer.uptime() + CFG.ANNOUNCE_INTERVAL
        end
      elseif kind == "ping" then
        sendPacket(remoteAddress, "pong", {id = CFG.NODE_ID, role = "projector"})
      end
    end
  end
end
