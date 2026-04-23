local component = require("component")
local event = require("event")
local serialization = require("serialization")
local computer = require("computer")
local term = require("term")

--------------------------------------------------------------------------------
-- HOLO-NET SCANNER NODE
-- Put this on a computer connected to:
--   * a geolyzer
--   * a wireless modem (or linked card / network path)
--
-- IMPORTANT:
-- WORLD_X / WORLD_Y / WORLD_Z must be the *actual world position of the
-- geolyzer block itself*.
--------------------------------------------------------------------------------

local CFG = {
  NODE_ID = "scanner-1",
  PORT = 3413,
  MODEM_STRENGTH = 400, -- tier 2 wireless default max is 400

  -- Real world coordinates of the geolyzer block.
  WORLD_X = 0,
  WORLD_Y = 64,
  WORLD_Z = 0,

  -- Scan tuning.
  AIR_MAX = 0.05,
  DENSE_MIN = 4.0,
  BATCH_VOXELS = 120,
  ANNOUNCE_INTERVAL = 10,
}

local modem = component.modem
local geo = component.geolyzer
assert(modem, "No modem found")
assert(geo, "No geolyzer found")

modem.open(CFG.PORT)
if modem.isWireless and modem.isWireless() and modem.setStrength then
  pcall(modem.setStrength, CFG.MODEM_STRENGTH)
end

math.randomseed(math.floor(computer.uptime() * 1000) % 2147483647)

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
  print(center("HOLO-NET SCANNER NODE"))
  print(center(CFG.NODE_ID))
  print(string.rep("-", 60))
  print("Geolyzer position :", CFG.WORLD_X, CFG.WORLD_Y, CFG.WORLD_Z)
  print("Port / strength   :", CFG.PORT, CFG.MODEM_STRENGTH)
  print("Modes             : void / solid / dense / bands")
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
    role = "scanner",
    id = CFG.NODE_ID,
    world = {x = CFG.WORLD_X, y = CFG.WORLD_Y, z = CFG.WORLD_Z},
    modes = {"void", "solid", "dense", "bands"},
    uptime = computer.uptime(),
  }
  if address then
    sendPacket(address, "hello", packet)
  else
    modem.broadcast(CFG.PORT, "holonet", "hello", serialization.serialize(packet))
  end
end

local function classify(mode, hardness)
  if mode == "void" then
    if hardness <= CFG.AIR_MAX then return 1 end
  elseif mode == "solid" then
    if hardness > CFG.AIR_MAX then return 1 end
  elseif mode == "dense" then
    if hardness >= CFG.DENSE_MIN then return 2 end
  elseif mode == "bands" then
    if hardness <= CFG.AIR_MAX then
      return 1
    elseif hardness >= CFG.DENSE_MIN then
      return 3
    elseif hardness > 1.5 then
      return 2
    end
  else
    if hardness > CFG.AIR_MAX then return 1 end
  end
  return 0
end

local function flushBatch(replyTo, requestId, sceneName, batch, batchNo)
  if #batch == 0 then return batchNo end
  sendPacket(replyTo, "scan.chunk", {
    requestId = requestId,
    scene = sceneName,
    nodeId = CFG.NODE_ID,
    voxels = batch,
    batch = batchNo,
  })
  for i = 1, #batch do batch[i] = nil end
  return batchNo + 1
end

local function runCapture(replyTo, payload)
  local box = payload.box or {}
  local mode = payload.mode or "solid"
  local requestId = payload.requestId or ("req-" .. tostring(math.random(100000, 999999)))
  local sceneName = payload.scene or ("scene-" .. os.time())

  local rx = tonumber(box.x) or -24
  local rz = tonumber(box.z) or -24
  local ry = tonumber(box.y) or -16
  local w  = math.max(1, tonumber(box.w) or 48)
  local d  = math.max(1, tonumber(box.d) or 48)
  local h  = math.max(1, tonumber(box.h) or 32)

  drawStatus({
    "Job       : scanning",
    "Scene     : " .. sceneName,
    "Request   : " .. requestId,
    string.format("Mode      : %s", mode),
    string.format("Box       : x=%d z=%d y=%d  w=%d d=%d h=%d", rx, rz, ry, w, d, h),
    "Replying  : " .. tostring(replyTo),
  })

  sendPacket(replyTo, "scan.begin", {
    requestId = requestId,
    scene = sceneName,
    nodeId = CFG.NODE_ID,
    world = {x = CFG.WORLD_X, y = CFG.WORLD_Y, z = CFG.WORLD_Z},
    mode = mode,
    box = {x = rx, z = rz, y = ry, w = w, d = d, h = h},
  })

  local batch = {}
  local batchNo = 1
  local sent = 0

  for oy = 0, h - 1, 4 do
    local ch = math.min(4, h - oy)
    for oz = 0, d - 1, 4 do
      local cd = math.min(4, d - oz)
      for ox = 0, w - 1, 4 do
        local cw = math.min(4, w - ox)
        local ok, values = pcall(geo.scan, rx + ox, rz + oz, ry + oy, cw, cd, ch)
        if ok and type(values) == "table" then
          local idx = 1
          for yy = 0, ch - 1 do
            for zz = 0, cd - 1 do
              for xx = 0, cw - 1 do
                local hardness = tonumber(values[idx]) or 0
                idx = idx + 1
                local v = classify(mode, hardness)
                if v ~= 0 then
                  batch[#batch + 1] = CFG.WORLD_X + rx + ox + xx
                  batch[#batch + 1] = CFG.WORLD_Y + ry + oy + yy
                  batch[#batch + 1] = CFG.WORLD_Z + rz + oz + zz
                  batch[#batch + 1] = v
                  sent = sent + 1
                  if (#batch / 4) >= CFG.BATCH_VOXELS then
                    batchNo = flushBatch(replyTo, requestId, sceneName, batch, batchNo)
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  batchNo = flushBatch(replyTo, requestId, sceneName, batch, batchNo)

  sendPacket(replyTo, "scan.end", {
    requestId = requestId,
    scene = sceneName,
    nodeId = CFG.NODE_ID,
    sent = sent,
    finishedAt = computer.uptime(),
  })

  drawStatus({
    "Last job   : complete",
    "Scene      : " .. sceneName,
    "Mode       : " .. mode,
    "Voxels sent: " .. tostring(sent),
  })
end

drawStatus({"Waiting for controller..."})
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
      elseif kind == "scan.capture" then
        local target = payload.target
        if not target or target == "*" or target == CFG.NODE_ID then
          runCapture(remoteAddress, payload)
          nextAnnounce = computer.uptime() + CFG.ANNOUNCE_INTERVAL
        end
      elseif kind == "ping" then
        sendPacket(remoteAddress, "pong", {id = CFG.NODE_ID, role = "scanner"})
      end
    end
  end
end
