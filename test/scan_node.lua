local component = require("component")
local event = require("event")
local serialization = require("serialization")
local computer = require("computer")
local term = require("term")

--------------------------------------------------------------------------------
-- HOLO-NET SCANNER NODE v3
-- Put this on a computer connected to:
--   * a geolyzer
--   * a wireless modem or linked network path
-- Optional:
--   * a hologram projector for local Geo2holo-style preview mode
--------------------------------------------------------------------------------

local CFG = {
  NODE_ID = "scanner-1",
  NODE_LABEL = "Scanner 1",
  PORT = 3413,
  MODEM_STRENGTH = 400,

  WORLD_X = -211,
  WORLD_Y = 4,
  WORLD_Z = -1178,

  AIR_MAX = 0.05,
  DENSE_MIN = 4.0,
  BATCH_VOXELS = 32,
  SEND_PAUSE = 0.02,
  ANNOUNCE_INTERVAL = 10,

  PREVIEW_SCALE = 1.0,
  PREVIEW_PALETTE = {
    [1] = 0x00FFFF,
    [2] = 0x00FF00,
    [3] = 0xFF4040,
  },
}

local modem = component.modem
local geo = component.geolyzer
local holo = component.isAvailable("hologram") and component.hologram or nil

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
  print(center("HOLO-NET SCANNER NODE v3"))
  print(center(CFG.NODE_ID .. " / " .. CFG.NODE_LABEL))
  print(string.rep("-", 60))
  print("Geolyzer position :", CFG.WORLD_X, CFG.WORLD_Y, CFG.WORLD_Z)
  print("Port / strength   :", CFG.PORT, CFG.MODEM_STRENGTH)
  print("Preview holo      :", holo and "YES" or "NO")
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
    label = CFG.NODE_LABEL,
    world = {x = CFG.WORLD_X, y = CFG.WORLD_Y, z = CFG.WORLD_Z},
    modes = {"void", "solid", "dense", "bands"},
    preview = holo and true or false,
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
  if #batch == 0 then return batchNo, true end
  local ok = sendPacket(replyTo, "scan.chunk", {
    requestId = requestId,
    scene = sceneName,
    nodeId = CFG.NODE_ID,
    voxels = batch,
    batch = batchNo,
  })
  if os and os.sleep and CFG.SEND_PAUSE and CFG.SEND_PAUSE > 0 then
    pcall(os.sleep, CFG.SEND_PAUSE)
  end
  for i = 1, #batch do batch[i] = nil end
  return batchNo + 1, ok ~= false
end

local function scanBox(box, mode, onVoxel)
  local rx = tonumber(box.x) or -24
  local rz = tonumber(box.z) or -24
  local ry = tonumber(box.y) or -16
  local w  = math.max(1, tonumber(box.w) or 48)
  local d  = math.max(1, tonumber(box.d) or 48)
  local h  = math.max(1, tonumber(box.h) or 32)

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
                  onVoxel(rx + ox + xx, ry + oy + yy, rz + oz + zz, v)
                end
              end
            end
          end
        end
      end
    end
  end

  return rx, ry, rz, w, d, h
end

local function runCapture(replyTo, payload)
  local box = payload.box or {}
  local mode = payload.mode or "solid"
  local requestId = payload.requestId or ("req-" .. tostring(math.random(100000, 999999)))
  local sceneName = payload.scene or ("scene-" .. tostring(math.floor(computer.uptime())))

  drawStatus({
    "Job        : remote capture",
    "Scene      : " .. sceneName,
    "Request    : " .. requestId,
    "Mode       : " .. mode,
  })

  sendPacket(replyTo, "scan.begin", {
    requestId = requestId,
    scene = sceneName,
    nodeId = CFG.NODE_ID,
    world = {x = CFG.WORLD_X, y = CFG.WORLD_Y, z = CFG.WORLD_Z},
    mode = mode,
    box = box,
  })

  local batch = {}
  local batchNo = 1
  local sent = 0
  local failedBatches = 0

  scanBox(box, mode, function(localX, localY, localZ, v)
    batch[#batch + 1] = CFG.WORLD_X + localX
    batch[#batch + 1] = CFG.WORLD_Y + localY
    batch[#batch + 1] = CFG.WORLD_Z + localZ
    batch[#batch + 1] = v
    sent = sent + 1
    if (#batch / 4) >= CFG.BATCH_VOXELS then
      local delivered
      batchNo, delivered = flushBatch(replyTo, requestId, sceneName, batch, batchNo)
      if not delivered then failedBatches = failedBatches + 1 end
    end
  end)

  local delivered
  batchNo, delivered = flushBatch(replyTo, requestId, sceneName, batch, batchNo)
  if not delivered then failedBatches = failedBatches + 1 end

  sendPacket(replyTo, "scan.end", {
    requestId = requestId,
    scene = sceneName,
    nodeId = CFG.NODE_ID,
    sent = sent,
    failedBatches = failedBatches,
    finishedAt = computer.uptime(),
  })

  drawStatus({
    "Last job    : remote capture complete",
    "Scene       : " .. sceneName,
    "Mode        : " .. mode,
    "Voxels sent : " .. tostring(sent),
    "Failed tx   : " .. tostring(failedBatches),
  })
end

local function applyPreviewSettings()
  if not holo then return end
  pcall(holo.setScale, CFG.PREVIEW_SCALE)
  pcall(holo.setTranslation, 0, 0, 0)
  for i = 1, 3 do
    if CFG.PREVIEW_PALETTE[i] then
      pcall(holo.setPaletteColor, i, CFG.PREVIEW_PALETTE[i])
    end
  end
end

local function runLocalPreview(replyTo, payload)
  if not holo then
    if replyTo then
      sendPacket(replyTo, "preview.local.complete", {
        nodeId = CFG.NODE_ID,
        scene = payload.scene or "preview",
        ok = false,
        reason = "No hologram attached",
      })
    end
    return
  end

  local box = payload.box or {}
  local mode = payload.mode or "solid"
  local sceneName = payload.scene or ("preview-" .. tostring(math.floor(computer.uptime())))
  local w = math.max(1, tonumber(box.w) or 48)
  local d = math.max(1, tonumber(box.d) or 48)
  local h = math.max(1, tonumber(box.h) or 32)
  if w > 48 or d > 48 or h > 32 then
    if replyTo then
      sendPacket(replyTo, "preview.local.complete", {
        nodeId = CFG.NODE_ID,
        scene = sceneName,
        ok = false,
        reason = "Preview box must fit 48x32x48",
      })
    end
    drawStatus({
      "Last job    : local preview rejected",
      "Reason      : box must fit 48x32x48",
    })
    return
  end

  drawStatus({
    "Job         : local preview",
    "Scene       : " .. sceneName,
    "Mode        : " .. mode,
    "Dimensions  : " .. tostring(w) .. "x" .. tostring(h) .. "x" .. tostring(d),
  })

  pcall(holo.clear)
  applyPreviewSettings()

  local applied = 0
  scanBox(box, mode, function(localX, localY, localZ, v)
    local lx = localX - (tonumber(box.x) or -24) + 1
    local ly = localY - (tonumber(box.y) or -16) + 1
    local lz = localZ - (tonumber(box.z) or -24) + 1
    if lx >= 1 and lx <= 48 and ly >= 1 and ly <= 32 and lz >= 1 and lz <= 48 then
      pcall(holo.set, lx, ly, lz, v)
      applied = applied + 1
    end
  end)

  if replyTo then
    sendPacket(replyTo, "preview.local.complete", {
      nodeId = CFG.NODE_ID,
      scene = sceneName,
      ok = true,
      applied = applied,
    })
  end

  drawStatus({
    "Last job    : local preview complete",
    "Scene       : " .. sceneName,
    "Mode        : " .. mode,
    "Applied     : " .. tostring(applied),
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
        runCapture(remoteAddress, payload)
        nextAnnounce = computer.uptime() + CFG.ANNOUNCE_INTERVAL
      elseif kind == "preview.local.capture" then
        runLocalPreview(remoteAddress, payload)
        nextAnnounce = computer.uptime() + CFG.ANNOUNCE_INTERVAL
      elseif kind == "ping" then
        sendPacket(remoteAddress, "pong", {id = CFG.NODE_ID, role = "scanner"})
      end
    end
  end
end
