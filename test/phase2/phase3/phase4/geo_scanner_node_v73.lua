local component = require('component')
local serialization = require('serialization')
local event = require('event')
local term = require('term')
local computer = require('computer')

assert(component.isAvailable('modem'), 'No modem found')
assert(component.isAvailable('geolyzer'), 'No geolyzer found')

local modem = component.modem
local PORT = 3413
local CFG_PATH = '/home/geo_scanner_node_v73.cfg'
local CHUNK_VOXELS = 32

local cfg = {
  nodeId = nil,
  groupName = nil,
  label = nil,
  geolyzers = {},
  slots = {},
  defaults = {
    mode = 'solid',
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

local function clear() term.clear(); term.setCursor(1,1) end
local function short(a) return a and tostring(a):sub(1,8) or '?' end
local function pause(msg) print(''); io.write(msg or 'Press Enter...'); io.read() end

local function clone(v)
  if type(v) ~= 'table' then return v end
  local out = {}
  for k,vv in pairs(v) do out[k] = clone(vv) end
  return out
end

local function loadCfg()
  local f = io.open(CFG_PATH, 'r')
  if not f then return false end
  local raw = f:read('*a')
  f:close()
  local ok, data = pcall(serialization.unserialize, raw)
  if ok and type(data) == 'table' then
    cfg = data
    cfg.geolyzers = cfg.geolyzers or {}
    cfg.slots = cfg.slots or {}
    cfg.defaults = cfg.defaults or {}
    return true
  end
  return false
end

local function saveCfg()
  local f, err = io.open(CFG_PATH, 'w')
  if not f then return false, err end
  f:write(serialization.serialize(cfg))
  f:close()
  return true
end

local function promptString(label, current)
  io.write(string.format('%s [%s]: ', label, tostring(current or '')))
  local s = io.read()
  if not s or s == '' then return current end
  return s
end

local function promptNumber(label, current, minv, maxv)
  io.write(string.format('%s [%s]: ', label, tostring(current or '')))
  local s = io.read()
  if not s or s == '' then return current end
  local n = tonumber(s)
  if not n then return current end
  if minv and n < minv then n = minv end
  if maxv and n > maxv then n = maxv end
  return math.floor(n)
end

local function promptFloat(label, current, minv, maxv)
  io.write(string.format('%s [%s]: ', label, tostring(current or '')))
  local s = io.read()
  if not s or s == '' then return current end
  local n = tonumber(s)
  if not n then return current end
  if minv and n < minv then n = minv end
  if maxv and n > maxv then n = maxv end
  return n
end

local function promptBool(label, current)
  io.write(string.format('%s [%s] (y/n): ', label, current and 'y' or 'n'))
  local s = io.read()
  if not s or s == '' then return current end
  s = s:lower()
  if s == 'y' or s == 'yes' or s == '1' or s == 'true' then return true end
  if s == 'n' or s == 'no' or s == '0' or s == 'false' then return false end
  return current
end

local function discoverGeolyzers()
  local found = {}
  for addr in component.list('geolyzer', true) do found[#found+1] = addr end
  table.sort(found)
  return found
end

local function ensureGeolyzerEntries()
  local found = discoverGeolyzers()
  local byAddr = {}
  for i=1,#(cfg.geolyzers or {}) do byAddr[cfg.geolyzers[i].address] = cfg.geolyzers[i] end
  local newList = {}
  for i=1,#found do
    local addr = found[i]
    local entry = byAddr[addr] or {address = addr, alias = 'Geo'..tostring(i), enabled = true}
    newList[#newList+1] = entry
  end
  cfg.geolyzers = newList
end

local function geolyzerEntryByAlias(alias)
  for i=1,#(cfg.geolyzers or {}) do
    local e = cfg.geolyzers[i]
    if e.alias == alias and e.enabled ~= false then return e end
  end
  return nil
end

local function chooseGeolyzerEntry()
  while true do
    clear()
    print('Choose geolyzer')
    print('---------------')
    for i=1,#(cfg.geolyzers or {}) do
      local g = cfg.geolyzers[i]
      print(string.format('%d) %s [%s] enabled=%s', i, tostring(g.alias), short(g.address), tostring(g.enabled ~= false)))
    end
    print('0) Back')
    io.write('> ')
    local n = tonumber(io.read() or '')
    if n == 0 then return nil end
    if n and cfg.geolyzers[n] then return cfg.geolyzers[n] end
  end
end

local function slotMeta(slot)
  return {
    name = slot.name,
    geoAlias = slot.geoAlias,
    sizeX = tonumber(slot.sizeX or 0),
    sizeY = tonumber((slot.yMax or 0) - (slot.yMin or 0) + 1),
    sizeZ = tonumber(slot.sizeZ or 0),
    mode = slot.mode,
  }
end

local function announce(toAddr)
  local slots = {}
  for i=1,#(cfg.slots or {}) do slots[#slots+1] = slotMeta(cfg.slots[i]) end
  local packet = {t='geo.announce', nodeId=cfg.nodeId, groupName=cfg.groupName, label=cfg.label, geolyzers=cfg.geolyzers or {}, slots=slots}
  local data = serialization.serialize(packet)
  if toAddr then modem.send(toAddr, PORT, data) else modem.broadcast(PORT, data) end
end

local function normalizeSlot(slot)
  local entry = geolyzerEntryByAlias(slot.geoAlias)
  if not entry then return nil, 'Missing geolyzer '..tostring(slot.geoAlias) end
  local proxy = component.proxy(entry.address)
  if not proxy or type(proxy.scan) ~= 'function' then return nil, 'Bad geolyzer proxy for '..tostring(slot.geoAlias) end

  local yMin = math.max(-32, math.min(31, tonumber(slot.yMin or cfg.defaults.yMin or -4)))
  local yMax = math.max(-32, math.min(31, tonumber(slot.yMax or cfg.defaults.yMax or 11)))
  if yMin > yMax then yMin, yMax = yMax, yMin end
  if (yMax - yMin + 1) > 32 then yMax = yMin + 31 end

  return {
    slotName = slot.name,
    geoAlias = entry.alias,
    geo = proxy,
    ox = tonumber(slot.offsetX or cfg.defaults.offsetX or -8),
    oz = tonumber(slot.offsetZ or cfg.defaults.offsetZ or -8),
    sizeX = math.max(1, math.min(48, tonumber(slot.sizeX or cfg.defaults.sizeX or 16))),
    sizeZ = math.max(1, math.min(48, tonumber(slot.sizeZ or cfg.defaults.sizeZ or 16))),
    yMin = yMin,
    yMax = yMax,
    sizeY = yMax - yMin + 1,
    mode = tostring(slot.mode or cfg.defaults.mode or 'solid'),
    airMax = tonumber(slot.airMax or cfg.defaults.airMax or 0.05),
    denseMin = tonumber(slot.denseMin or cfg.defaults.denseMin or 4.0),
    slotRef = slot,
  }
end

local function classify(meta, value)
  value = tonumber(value) or 0
  if meta.mode == 'void' then
    return (value <= meta.airMax) and 1 or 0
  elseif meta.mode == 'dense' then
    return (value >= meta.denseMin) and 1 or 0
  elseif meta.mode == 'bands' then
    if value <= meta.airMax then return 0 end
    if value < meta.denseMin then return 2 end
    return 3
  end
  return (value <= meta.airMax) and 0 or 1
end

local function streamSlot(slot, callbacks)
  local meta, err = normalizeSlot(slot)
  if not meta then return false, err end
  callbacks = callbacks or {}
  if callbacks.begin then callbacks.begin(clone(meta)) end

  local count = 0
  local chunk = {}
  for hx = 1, meta.sizeX do
    local rx = meta.ox + hx - 1
    for hz = 1, meta.sizeZ do
      local rz = meta.oz + hz - 1
      local col = meta.geo.scan(rx, rz, false)
      for relY = meta.yMin, meta.yMax do
        local idx = relY + 33
        local val = col and col[idx] or nil
        local v = classify(meta, val)
        if v ~= 0 then
          chunk[#chunk+1] = {x=hx, y=relY-meta.yMin+1, z=hz, v=v}
          count = count + 1
          if #chunk >= CHUNK_VOXELS then
            if callbacks.chunk then callbacks.chunk(chunk, clone(meta), count) end
            chunk = {}
          end
        end
      end
    end
    if callbacks.progress then callbacks.progress(hx, meta.sizeX, count, clone(meta)) end
  end
  if #chunk > 0 and callbacks.chunk then callbacks.chunk(chunk, clone(meta), count) end

  meta.slotRef.lastUpdated = computer.uptime()
  meta.slotRef.lastCount = count
  saveCfg()

  if callbacks.finish then callbacks.finish(count, clone(meta)) end
  return true, {count=count, meta=meta}
end

local function editDefaults()
  clear()
  print('Group defaults')
  print('--------------')
  cfg.defaults.mode = promptString('mode', cfg.defaults.mode or 'solid')
  cfg.defaults.offsetX = promptNumber('offsetX', cfg.defaults.offsetX or -8, -128, 127)
  cfg.defaults.offsetZ = promptNumber('offsetZ', cfg.defaults.offsetZ or -8, -128, 127)
  cfg.defaults.sizeX = promptNumber('sizeX', cfg.defaults.sizeX or 16, 1, 48)
  cfg.defaults.sizeZ = promptNumber('sizeZ', cfg.defaults.sizeZ or 16, 1, 48)
  cfg.defaults.yMin = promptNumber('yMin', cfg.defaults.yMin or -4, -32, 31)
  cfg.defaults.yMax = promptNumber('yMax', cfg.defaults.yMax or 11, -32, 31)
  cfg.defaults.airMax = promptFloat('airMax', cfg.defaults.airMax or 0.05, -5, 5)
  cfg.defaults.denseMin = promptFloat('denseMin', cfg.defaults.denseMin or 4.0, -5, 999999)
  saveCfg()
end

local function editGeolyzers()
  while true do
    clear()
    print('Geolyzers on this node')
    print('----------------------')
    for i=1,#(cfg.geolyzers or {}) do
      local g = cfg.geolyzers[i]
      print(string.format('%d) %s [%s] enabled=%s', i, tostring(g.alias), short(g.address), tostring(g.enabled ~= false)))
    end
    print('')
    print('E edit one')
    print('Q back')
    io.write('> ')
    local c = (io.read() or ''):lower()
    if c == 'q' then return end
    if c == 'e' then
      local e = chooseGeolyzerEntry()
      if e then
        clear()
        print('Edit geolyzer: '..tostring(e.alias))
        e.alias = promptString('alias', e.alias)
        e.enabled = promptBool('enabled', e.enabled ~= false)
        saveCfg()
      end
    end
  end
end

local function editSlot(slot)
  local useDefaults = promptBool('Start from group defaults', true)
  if useDefaults then
    slot.mode = cfg.defaults.mode
    slot.offsetX = cfg.defaults.offsetX
    slot.offsetZ = cfg.defaults.offsetZ
    slot.sizeX = cfg.defaults.sizeX
    slot.sizeZ = cfg.defaults.sizeZ
    slot.yMin = cfg.defaults.yMin
    slot.yMax = cfg.defaults.yMax
    slot.airMax = cfg.defaults.airMax
    slot.denseMin = cfg.defaults.denseMin
  end
  slot.name = promptString('slot name', slot.name)
  local geo = chooseGeolyzerEntry()
  if not geo then return nil end
  slot.geoAlias = geo.alias
  slot.mode = promptString('mode', slot.mode or 'solid')
  slot.offsetX = promptNumber('offsetX', slot.offsetX or -8, -128, 127)
  slot.offsetZ = promptNumber('offsetZ', slot.offsetZ or -8, -128, 127)
  slot.sizeX = promptNumber('sizeX', slot.sizeX or 16, 1, 48)
  slot.sizeZ = promptNumber('sizeZ', slot.sizeZ or 16, 1, 48)
  slot.yMin = promptNumber('yMin', slot.yMin or -4, -32, 31)
  slot.yMax = promptNumber('yMax', slot.yMax or 11, -32, 31)
  slot.airMax = promptFloat('airMax', slot.airMax or 0.05, -5, 5)
  slot.denseMin = promptFloat('denseMin', slot.denseMin or 4.0, -5, 999999)
  return slot
end

local function testSlotLocal(slot)
  clear()
  print('Local slot test')
  print('---------------')
  print('Slot: '..tostring(slot.name))
  local ok, res = streamSlot(slot, {
    progress = function(done, total, count, meta)
      term.setCursor(1,5)
      io.write(string.format('Geo=%s  %d/%d columns  voxels=%d      ', tostring(meta.geoAlias), done, total, count))
    end
  })
  term.setCursor(1,7)
  if ok then
    print('Success.')
    print('Voxels: '..tostring(res.count))
  else
    print('Failed: '..tostring(res))
  end
  pause()
end

local function manageSlots()
  while true do
    clear()
    print('Scan slots')
    print('----------')
    for i=1,#(cfg.slots or {}) do
      local s = cfg.slots[i]
      print(string.format('%d) %s -> %s size=%dx%dx%d mode=%s', i, tostring(s.name), tostring(s.geoAlias), tonumber(s.sizeX or 0), tonumber((s.yMax or 0)-(s.yMin or 0)+1), tonumber(s.sizeZ or 0), tostring(s.mode)))
    end
    print('')
    print('A add slot')
    print('E edit slot')
    print('D delete slot')
    print('T test capture one slot locally')
    print('Q back')
    io.write('> ')
    local c = (io.read() or ''):lower()
    if c == 'q' then return end
    if c == 'a' then
      local slot = editSlot({})
      if slot and slot.name and slot.geoAlias then cfg.slots[#cfg.slots+1] = slot; saveCfg() end
    elseif c == 'e' then
      local idx = promptNumber('Slot number', 1, 1, #cfg.slots)
      if cfg.slots[idx] then local s = editSlot(cfg.slots[idx]); if s then cfg.slots[idx] = s; saveCfg() end end
    elseif c == 'd' then
      local idx = promptNumber('Slot number', 1, 1, #cfg.slots)
      if cfg.slots[idx] then table.remove(cfg.slots, idx); saveCfg() end
    elseif c == 't' then
      local idx = promptNumber('Slot number', 1, 1, #cfg.slots)
      if cfg.slots[idx] then testSlotLocal(cfg.slots[idx]) end
    end
  end
end

local function setupWizard()
  ensureGeolyzerEntries()
  clear()
  print('Geo Scanner Node V73 setup')
  print('--------------------------')
  cfg.nodeId = promptString('nodeId', cfg.nodeId or ('geo_'..short(computer.address())))
  cfg.groupName = promptString('group name', cfg.groupName or cfg.nodeId)
  cfg.label = promptString('label', cfg.label or cfg.groupName)
  editGeolyzers()
  editDefaults()
  manageSlots()
  saveCfg()
  announce(nil)
end

loadCfg()
ensureGeolyzerEntries()
if not cfg.nodeId or (...) == 'setup' then
  setupWizard()
else
  clear()
  print('Geo Scanner Node V73')
  print('--------------------')
  print('Press S then Enter for setup, or Enter to continue.')
  io.write('> ')
  local ans = io.read()
  if ans and ans:lower() == 's' then setupWizard() end
end

pcall(modem.open, PORT)
announce(nil)

clear()
print('Geo Scanner Node V73')
print('--------------------')
print('nodeId:     '..tostring(cfg.nodeId))
print('groupName:  '..tostring(cfg.groupName))
print('geolyzers:  '..tostring(#(cfg.geolyzers or {})))
print('scan slots: '..tostring(#(cfg.slots or {})))
print('port:       '..tostring(PORT))
print('')
print('Listening...')

while true do
  local _, _, fromAddr, port, _, msg = event.pull('modem_message')
  if port == PORT and type(msg) == 'string' then
    local ok, packet = pcall(serialization.unserialize, msg)
    if ok and type(packet) == 'table' then
      if packet.t == 'geo.discover' then
        announce(fromAddr)
      elseif packet.t == 'geo.snapshot.request' then
        local wanted = {}
        if type(packet.slots) == 'table' and #packet.slots > 0 then
          local byName = {}
          for i=1,#(cfg.slots or {}) do byName[cfg.slots[i].name] = cfg.slots[i] end
          for i=1,#packet.slots do if byName[packet.slots[i]] then wanted[#wanted+1] = byName[packet.slots[i]] end end
        else
          for i=1,#(cfg.slots or {}) do wanted[#wanted+1] = cfg.slots[i] end
        end

        modem.send(fromAddr, PORT, serialization.serialize({t='geo.snapshot.start', requestId=packet.requestId, totalSlots=#wanted}))
        for i=1,#wanted do
          local slot = wanted[i]
          local sentAnyBegin = false
          local okScan, result = streamSlot(slot, {
            begin = function(meta)
              sentAnyBegin = true
              modem.send(fromAddr, PORT, serialization.serialize({
                t='geo.slot.begin', requestId=packet.requestId, slotName=meta.slotName, geoAlias=meta.geoAlias,
                sizeX=meta.sizeX, sizeY=meta.sizeY, sizeZ=meta.sizeZ, mode=meta.mode, updatedAt=computer.uptime(),
              }))
            end,
            chunk = function(chunk, meta)
              modem.send(fromAddr, PORT, serialization.serialize({t='geo.slot.chunk', requestId=packet.requestId, slotName=meta.slotName, voxels=chunk}))
            end,
            progress = function(done, total, count, meta)
              if done == 1 or (done % 4) == 0 or done == total then
                modem.send(fromAddr, PORT, serialization.serialize({t='geo.slot.progress', requestId=packet.requestId, slotName=meta.slotName, columnsDone=done, columnsTotal=total, count=count}))
              end
              term.setCursor(1,10)
              io.write(string.format('Serving %s: %d/%d columns vox=%d     ', tostring(meta.slotName), done, total, count))
            end,
            finish = function(count, meta)
              if not sentAnyBegin then
                modem.send(fromAddr, PORT, serialization.serialize({
                  t='geo.slot.begin', requestId=packet.requestId, slotName=meta.slotName, geoAlias=meta.geoAlias,
                  sizeX=meta.sizeX, sizeY=meta.sizeY, sizeZ=meta.sizeZ, mode=meta.mode, updatedAt=computer.uptime(),
                }))
              end
              modem.send(fromAddr, PORT, serialization.serialize({t='geo.slot.end', requestId=packet.requestId, slotName=meta.slotName, count=count, updatedAt=computer.uptime()}))
            end
          })
          if not okScan then
            modem.send(fromAddr, PORT, serialization.serialize({t='geo.slot.end', requestId=packet.requestId, slotName=slot.name, count=0, error=result}))
          end
        end
        modem.send(fromAddr, PORT, serialization.serialize({t='geo.snapshot.done', requestId=packet.requestId}))
        saveCfg()
      end
    end
  end
end
