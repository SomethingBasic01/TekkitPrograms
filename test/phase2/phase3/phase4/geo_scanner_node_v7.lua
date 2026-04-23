
local component = require("component")
local serialization = require("serialization")
local event = require("event")
local term = require("term")
local computer = require("computer")

assert(component.isAvailable("modem"), "No modem found")
assert(component.isAvailable("geolyzer"), "No geolyzer found")

local modem = component.modem
local PORT = 3413
local CFG_PATH = "/home/geo_scanner_node_v7.cfg"
local CHUNK_VOXELS = 48

local cfg = {
  nodeId = nil,
  groupName = nil,
  label = nil,
  geolyzers = {},
  slots = {},
  defaults = {
    mode = "solid",
    offsetX = -8,
    offsetZ = -8,
    sizeX = 16,
    sizeZ = 16,
    yMin = -4,
    yMax = 11,
    airMax = 0.05,
    denseMin = 4.0,
  },
}

local function short(addr)
  if not addr then return "?" end
  return tostring(addr):sub(1, 8)
end

local function depth()
  return 1
end

local function clone(v)
  if type(v) ~= "table" then return v end
  local out = {}
  for k, vv in pairs(v) do out[k] = clone(vv) end
  return out
end

local function loadCfg()
  local f = io.open(CFG_PATH, "r")
  if not f then return false end
  local raw = f:read("*a")
  f:close()
  local ok, data = pcall(serialization.unserialize, raw)
  if ok and type(data) == "table" then
    cfg = data
    cfg.geolyzers = cfg.geolyzers or {}
    cfg.slots = cfg.slots or {}
    cfg.defaults = cfg.defaults or {}
    return true
  end
  return false
end

local function saveCfg()
  local f, err = io.open(CFG_PATH, "w")
  if not f then return false, err end
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

local function promptNumber(label, current, minv, maxv)
  io.write(string.format("%s [%s]: ", label, tostring(current or "")))
  local s = io.read()
  if not s or s == "" then return current end
  local n = tonumber(s)
  if not n then return current end
  if minv and n < minv then n = minv end
  if maxv and n > maxv then n = maxv end
  return math.floor(n)
end

local function promptFloat(label, current, minv, maxv)
  io.write(string.format("%s [%s]: ", label, tostring(current or "")))
  local s = io.read()
  if not s or s == "" then return current end
  local n = tonumber(s)
  if not n then return current end
  if minv and n < minv then n = minv end
  if maxv and n > maxv then n = maxv end
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

local function clear()
  term.clear()
  term.setCursor(1, 1)
end

local function pause(msg)
  print("")
  io.write(msg or "Press Enter...")
  io.read()
end

local function discoverGeolyzers()
  local found = {}
  for addr in component.list("geolyzer", true) do
    found[#found + 1] = addr
  end
  table.sort(found)
  return found
end

local function ensureGeolyzerEntries()
  local found = discoverGeolyzers()
  local existingByAddr = {}
  for i = 1, #(cfg.geolyzers or {}) do
    existingByAddr[cfg.geolyzers[i].address] = cfg.geolyzers[i]
  end
  local updated = {}
  for i = 1, #found do
    local addr = found[i]
    local entry = existingByAddr[addr] or {
      address = addr,
      alias = "Geo" .. tostring(i),
      enabled = true,
    }
    updated[#updated + 1] = entry
  end
  cfg.geolyzers = updated
end

local function geolyzerProxyByAlias(alias)
  for i = 1, #(cfg.geolyzers or {}) do
    local entry = cfg.geolyzers[i]
    if entry.alias == alias and entry.enabled ~= false then
      return component.proxy(entry.address), entry
    end
  end
  return nil, nil
end

local function chooseGeolyzerEntry()
  while true do
    clear()
    print("Choose geolyzer")
    print("---------------")
    for i = 1, #(cfg.geolyzers or {}) do
      local g = cfg.geolyzers[i]
      print(string.format("%d) %s [%s] enabled=%s", i, tostring(g.alias), short(g.address), tostring(g.enabled ~= false)))
    end
    print("0) Back")
    io.write("> ")
    local choice = tonumber(io.read() or "")
    if choice == 0 then return nil end
    if choice and cfg.geolyzers[choice] then return cfg.geolyzers[choice] end
  end
end

local function slotMeta(slot)
  local sy = (slot.yMax or 0) - (slot.yMin or 0) + 1
  return {
    name = slot.name,
    geoAlias = slot.geoAlias,
    sizeX = slot.sizeX,
    sizeY = sy,
    sizeZ = slot.sizeZ,
    mode = slot.mode,
  }
end

local function announce(toAddr)
  local slots = {}
  for i = 1, #(cfg.slots or {}) do slots[#slots + 1] = slotMeta(cfg.slots[i]) end
  local packet = {
    t = "geo.announce",
    nodeId = cfg.nodeId,
    groupName = cfg.groupName,
    label = cfg.label,
    geolyzers = cfg.geolyzers or {},
    slots = slots,
  }
  local data = serialization.serialize(packet)
  if toAddr then modem.send(toAddr, PORT, data) else modem.broadcast(PORT, data) end
end

local function classify(mode, airMax, denseMin, value)
  value = tonumber(value) or 0
  if mode == "void" then
    if value <= airMax then return 1 end
    return 0
  elseif mode == "dense" then
    if value >= denseMin then return 1 end
    return 0
  elseif mode == "bands" then
    if value <= airMax then
      return 0
    elseif value < denseMin then
      return 2
    else
      return 3
    end
  end
  if value <= airMax then return 0 end
  return 1
end

local function captureSlot(slot)
  local geo, geoEntry = geolyzerProxyByAlias(slot.geoAlias)
  if not geo then return nil, "Missing geolyzer " .. tostring(slot.geoAlias) end

  local sizeX = math.max(1, math.min(48, tonumber(slot.sizeX or 16)))
  local sizeZ = math.max(1, math.min(48, tonumber(slot.sizeZ or 16)))
  local yMin = math.max(-32, math.min(31, tonumber(slot.yMin or -4)))
  local yMax = math.max(-32, math.min(31, tonumber(slot.yMax or 11)))
  if yMin > yMax then yMin, yMax = yMax, yMin end
  if (yMax - yMin + 1) > 32 then yMax = yMin + 31 end
  local mode = slot.mode or "solid"
  local airMax = tonumber(slot.airMax or cfg.defaults.airMax or 0.05)
  local denseMin = tonumber(slot.denseMin or cfg.defaults.denseMin or 4.0)

  local voxels = {}
  local ox = tonumber(slot.offsetX or 0)
  local oz = tonumber(slot.offsetZ or 0)

  for hx = 1, sizeX do
    local rx = ox + hx - 1
    for hz = 1, sizeZ do
      local rz = oz + hz - 1
      local column = geo.scan(rx, rz, false)
      for relY = yMin, yMax do
        local idx = relY + 33
        local value = column and column[idx] or nil
        local v = classify(mode, airMax, denseMin, value)
        if v ~= 0 then
          voxels[#voxels + 1] = {x = hx, y = relY - yMin + 1, z = hz, v = v}
        end
      end
    end
  end

  slot.lastUpdated = computer.uptime()
  slot.lastCount = #voxels

  return {
    slotName = slot.name,
    geoAlias = geoEntry.alias,
    sizeX = sizeX,
    sizeY = yMax - yMin + 1,
    sizeZ = sizeZ,
    mode = mode,
    voxels = voxels,
    updatedAt = slot.lastUpdated,
  }
end

local function sendSnapshotResponse(toAddr, requestId, slots)
  modem.send(toAddr, PORT, serialization.serialize({
    t = "geo.snapshot.start",
    requestId = requestId,
    totalSlots = #slots,
  }))

  for i = 1, #slots do
    local slot = slots[i]
    local snap, err = captureSlot(slot)
    if snap then
      modem.send(toAddr, PORT, serialization.serialize({
        t = "geo.slot.begin",
        requestId = requestId,
        slotName = snap.slotName,
        geoAlias = snap.geoAlias,
        sizeX = snap.sizeX,
        sizeY = snap.sizeY,
        sizeZ = snap.sizeZ,
        mode = snap.mode,
        updatedAt = snap.updatedAt,
      }))
      local idx = 1
      while idx <= #snap.voxels do
        local chunk = {}
        for _ = 1, CHUNK_VOXELS do
          if idx > #snap.voxels then break end
          chunk[#chunk + 1] = snap.voxels[idx]
          idx = idx + 1
        end
        modem.send(toAddr, PORT, serialization.serialize({
          t = "geo.slot.chunk",
          requestId = requestId,
          slotName = snap.slotName,
          voxels = chunk,
        }))
      end
      modem.send(toAddr, PORT, serialization.serialize({
        t = "geo.slot.end",
        requestId = requestId,
        slotName = snap.slotName,
        count = #snap.voxels,
      }))
    else
      modem.send(toAddr, PORT, serialization.serialize({
        t = "geo.slot.end",
        requestId = requestId,
        slotName = slot.name,
        count = 0,
        error = err,
      }))
    end
  end

  modem.send(toAddr, PORT, serialization.serialize({
    t = "geo.snapshot.done",
    requestId = requestId,
  }))
end

local function editDefaults()
  clear()
  print("Group defaults")
  print("--------------")
  cfg.defaults.mode = promptString("mode", cfg.defaults.mode or "solid")
  cfg.defaults.offsetX = promptNumber("offsetX", cfg.defaults.offsetX or -8, -128, 127)
  cfg.defaults.offsetZ = promptNumber("offsetZ", cfg.defaults.offsetZ or -8, -128, 127)
  cfg.defaults.sizeX = promptNumber("sizeX", cfg.defaults.sizeX or 16, 1, 48)
  cfg.defaults.sizeZ = promptNumber("sizeZ", cfg.defaults.sizeZ or 16, 1, 48)
  cfg.defaults.yMin = promptNumber("yMin", cfg.defaults.yMin or -4, -32, 31)
  cfg.defaults.yMax = promptNumber("yMax", cfg.defaults.yMax or 11, -32, 31)
  cfg.defaults.airMax = promptFloat("airMax", cfg.defaults.airMax or 0.05, -5, 5)
  cfg.defaults.denseMin = promptFloat("denseMin", cfg.defaults.denseMin or 4.0, -5, 999999)
  saveCfg()
end

local function editGeolyzers()
  while true do
    clear()
    print("Geolyzers on this node")
    print("----------------------")
    for i = 1, #(cfg.geolyzers or {}) do
      local g = cfg.geolyzers[i]
      print(string.format("%d) %s [%s] enabled=%s", i, tostring(g.alias), short(g.address), tostring(g.enabled ~= false)))
    end
    print("")
    print("E edit one")
    print("Q back")
    io.write("> ")
    local choice = io.read()
    if not choice then return end
    choice = choice:lower()
    if choice == "q" then return
    elseif choice == "e" then
      local entry = chooseGeolyzerEntry()
      if entry then
        clear()
        print("Edit geolyzer: " .. tostring(entry.alias))
        entry.alias = promptString("alias", entry.alias)
        entry.enabled = promptBool("enabled", entry.enabled ~= false)
        saveCfg()
      end
    end
  end
end

local function editSlot(slot)
  local useDefaults = promptBool("Start from group defaults", true)
  if useDefaults then
    slot.mode = slot.mode or cfg.defaults.mode
    slot.offsetX = slot.offsetX or cfg.defaults.offsetX
    slot.offsetZ = slot.offsetZ or cfg.defaults.offsetZ
    slot.sizeX = slot.sizeX or cfg.defaults.sizeX
    slot.sizeZ = slot.sizeZ or cfg.defaults.sizeZ
    slot.yMin = slot.yMin or cfg.defaults.yMin
    slot.yMax = slot.yMax or cfg.defaults.yMax
    slot.airMax = slot.airMax or cfg.defaults.airMax
    slot.denseMin = slot.denseMin or cfg.defaults.denseMin
  end
  slot.name = promptString("slot name", slot.name)
  local geoEntry = chooseGeolyzerEntry()
  if not geoEntry then return nil end
  slot.geoAlias = geoEntry.alias
  slot.mode = promptString("mode", slot.mode or "solid")
  slot.offsetX = promptNumber("offsetX", slot.offsetX or 0, -128, 127)
  slot.offsetZ = promptNumber("offsetZ", slot.offsetZ or 0, -128, 127)
  slot.sizeX = promptNumber("sizeX", slot.sizeX or 16, 1, 48)
  slot.sizeZ = promptNumber("sizeZ", slot.sizeZ or 16, 1, 48)
  slot.yMin = promptNumber("yMin", slot.yMin or -4, -32, 31)
  slot.yMax = promptNumber("yMax", slot.yMax or 11, -32, 31)
  slot.airMax = promptFloat("airMax", slot.airMax or 0.05, -5, 5)
  slot.denseMin = promptFloat("denseMin", slot.denseMin or 4.0, -5, 999999)
  return slot
end

local function manageSlots()
  while true do
    clear()
    print("Scan slots")
    print("----------")
    for i = 1, #(cfg.slots or {}) do
      local s = cfg.slots[i]
      print(string.format("%d) %s -> %s size=%dx%dx%d mode=%s", i, tostring(s.name), tostring(s.geoAlias), tonumber(s.sizeX or 0), tonumber((s.yMax or 0) - (s.yMin or 0) + 1), tonumber(s.sizeZ or 0), tostring(s.mode)))
    end
    print("")
    print("A add slot")
    print("E edit slot")
    print("D delete slot")
    print("T test capture one slot")
    print("Q back")
    io.write("> ")
    local choice = io.read()
    if not choice then return end
    choice = choice:lower()
    if choice == "q" then return
    elseif choice == "a" then
      local slot = editSlot({})
      if slot and slot.name and slot.geoAlias then
        cfg.slots[#cfg.slots + 1] = slot
        saveCfg()
      end
    elseif choice == "e" then
      local idx = promptNumber("Slot number", 1, 1, #cfg.slots)
      if cfg.slots[idx] then
        local edited = editSlot(cfg.slots[idx])
        if edited then cfg.slots[idx] = edited end
        saveCfg()
      end
    elseif choice == "d" then
      local idx = promptNumber("Slot number", 1, 1, #cfg.slots)
      if cfg.slots[idx] then
        table.remove(cfg.slots, idx)
        saveCfg()
      end
    elseif choice == "t" then
      local idx = promptNumber("Slot number", 1, 1, #cfg.slots)
      if cfg.slots[idx] then
        clear()
        print("Capturing " .. tostring(cfg.slots[idx].name) .. " ...")
        local snap, err = captureSlot(cfg.slots[idx])
        if snap then
          print("Success. Voxels: " .. tostring(#snap.voxels))
        else
          print("Failed: " .. tostring(err))
        end
        pause()
      end
    end
  end
end

local function setupWizard()
  ensureGeolyzerEntries()
  clear()
  print("Geo Scanner Node V7 setup")
  print("-------------------------")
  local defaultId = cfg.nodeId or ("geo_" .. short(computer.address()))
  cfg.nodeId = promptString("nodeId", defaultId)
  cfg.groupName = promptString("group name", cfg.groupName or cfg.nodeId)
  cfg.label = promptString("label", cfg.label or cfg.groupName)
  editGeolyzers()
  editDefaults()
  manageSlots()
  saveCfg()
  announce(nil)
end

loadCfg()
ensureGeolyzerEntries()
if not cfg.nodeId or (...) == "setup" then
  setupWizard()
else
  clear()
  print("Geo Scanner Node V7")
  print("-------------------")
  print("Press S then Enter now for setup, or Enter to continue.")
  io.write("> ")
  local ans = io.read()
  if ans and ans:lower() == "s" then
    setupWizard()
  end
end

pcall(modem.open, PORT)
announce(nil)

clear()
print("Geo Scanner Node V7")
print("-------------------")
print("nodeId:     " .. tostring(cfg.nodeId))
print("groupName:  " .. tostring(cfg.groupName))
print("geolyzers:  " .. tostring(#(cfg.geolyzers or {})))
print("scan slots: " .. tostring(#(cfg.slots or {})))
print("port:       " .. tostring(PORT))
print("")
print("Listening...")

while true do
  local ev = {event.pull("modem_message")}
  local _, _, fromAddr, port, _, msg = table.unpack(ev)
  if port == PORT and type(msg) == "string" then
    local ok, packet = pcall(serialization.unserialize, msg)
    if ok and type(packet) == "table" then
      if packet.t == "geo.discover" then
        announce(fromAddr)
      elseif packet.t == "geo.snapshot.request" then
        local wanted = {}
        if type(packet.slots) == "table" and #packet.slots > 0 then
          local byName = {}
          for i = 1, #(cfg.slots or {}) do byName[cfg.slots[i].name] = cfg.slots[i] end
          for i = 1, #packet.slots do
            if byName[packet.slots[i]] then wanted[#wanted + 1] = byName[packet.slots[i]] end
          end
        else
          for i = 1, #(cfg.slots or {}) do wanted[#wanted + 1] = cfg.slots[i] end
        end
        sendSnapshotResponse(fromAddr, packet.requestId, wanted)
        saveCfg()
        term.setCursor(1, 10)
        io.write("Last request: " .. tostring(packet.requestId) .. "                   ")
      end
    end
  end
end
