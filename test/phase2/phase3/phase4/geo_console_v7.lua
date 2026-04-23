
local component = require("component")
local serialization = require("serialization")
local term = require("term")
local event = require("event")
local computer = require("computer")
local filesystem = require("filesystem")

assert(component.isAvailable("modem"), "No modem found")

local modem = component.modem

local PORT = 3413
local CFG_PATH = "/home/geo_console_v7.cfg"
local CHUNK_VOXELS = 48
local PAGE_SIZE = 8

local db = {
  geoNodes = {},
  geoOrder = {},
  projectorNodes = {},
  projectorOrder = {},
  scenes = {},
  sceneOrder = {},
  snapshotCache = {},
  activeScene = nil,
}

local function short(addr)
  if not addr then return "?" end
  return tostring(addr):sub(1, 8)
end

local function clone(v)
  if type(v) ~= "table" then return v end
  local out = {}
  for k, vv in pairs(v) do out[k] = clone(vv) end
  return out
end

local function saveDb()
  local f, err = io.open(CFG_PATH, "w")
  if not f then
    return false, err
  end
  f:write(serialization.serialize(db))
  f:close()
  return true
end

local function loadDb()
  local f = io.open(CFG_PATH, "r")
  if not f then return end
  local raw = f:read("*a")
  f:close()
  local ok, data = pcall(serialization.unserialize, raw)
  if ok and type(data) == "table" then
    db = data
    db.geoNodes = db.geoNodes or {}
    db.geoOrder = db.geoOrder or {}
    db.projectorNodes = db.projectorNodes or {}
    db.projectorOrder = db.projectorOrder or {}
    db.scenes = db.scenes or {}
    db.sceneOrder = db.sceneOrder or {}
    db.snapshotCache = db.snapshotCache or {}
  end
end

local function pause(msg)
  print("")
  io.write(msg or "Press Enter...")
  io.read()
end

local function clear()
  term.clear()
  term.setCursor(1, 1)
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

local function promptBool(label, current)
  io.write(string.format("%s [%s] (y/n): ", label, current and "y" or "n"))
  local s = io.read()
  if not s or s == "" then return current end
  s = s:lower()
  if s == "y" or s == "yes" or s == "1" or s == "true" then return true end
  if s == "n" or s == "no" or s == "0" or s == "false" then return false end
  return current
end

local function ensureOrderEntry(order, key)
  for i = 1, #order do
    if order[i] == key then return end
  end
  order[#order + 1] = key
end

local function removeOrderEntry(order, key)
  for i = #order, 1, -1 do
    if order[i] == key then table.remove(order, i) end
  end
end

local function waitPacket(timeout)
  local deadline = computer.uptime() + (timeout or 5)
  while computer.uptime() < deadline do
    local remaining = deadline - computer.uptime()
    local ev = {event.pull(remaining, "modem_message")}
    if #ev > 0 then
      local _, _, fromAddr, port, _, msg = table.unpack(ev)
      if port == PORT and type(msg) == "string" then
        local ok, packet = pcall(serialization.unserialize, msg)
        if ok and type(packet) == "table" then
          return fromAddr, packet
        end
      end
    end
  end
  return nil, nil
end

local function refreshNodeFromPacket(fromAddr, packet)
  if packet.t == "geo.announce" then
    local node = {
      nodeId = packet.nodeId,
      groupName = packet.groupName,
      label = packet.label or packet.groupName or packet.nodeId,
      addr = fromAddr,
      geolyzers = packet.geolyzers or {},
      slots = packet.slots or {},
      lastSeen = computer.uptime(),
    }
    db.geoNodes[node.nodeId] = node
    ensureOrderEntry(db.geoOrder, node.nodeId)
  elseif packet.t == "proj.announce" then
    local node = {
      nodeId = packet.nodeId,
      groupName = packet.groupName,
      label = packet.label or packet.groupName or packet.nodeId,
      addr = fromAddr,
      projectors = packet.projectors or {},
      lastSeen = computer.uptime(),
    }
    db.projectorNodes[node.nodeId] = node
    ensureOrderEntry(db.projectorOrder, node.nodeId)
  end
end

local function discoverNodes()
  clear()
  print("Discovering nodes...")
  pcall(modem.open, PORT)
  modem.broadcast(PORT, serialization.serialize({t = "geo.discover"}))
  modem.broadcast(PORT, serialization.serialize({t = "proj.discover"}))
  local deadline = computer.uptime() + 3
  while computer.uptime() < deadline do
    local fromAddr, packet = waitPacket(deadline - computer.uptime())
    if not packet then break end
    refreshNodeFromPacket(fromAddr, packet)
  end
  saveDb()
  clear()
  print("Discovery complete.")
  print("Geo nodes:       " .. tostring(#db.geoOrder))
  print("Projector nodes: " .. tostring(#db.projectorOrder))
  pause()
end

local function listPaged(title, items, formatter)
  local page = 1
  while true do
    clear()
    print(title)
    print(string.rep("-", #title))
    local totalPages = math.max(1, math.ceil(#items / PAGE_SIZE))
    if page > totalPages then page = totalPages end
    local startIndex = (page - 1) * PAGE_SIZE + 1
    local endIndex = math.min(#items, startIndex + PAGE_SIZE - 1)
    for i = startIndex, endIndex do
      print(string.format("%d) %s", i, formatter(items[i], i)))
    end
    print("")
    print(string.format("Page %d/%d", page, totalPages))
    print("Enter number, N next, P prev, Q back")
    io.write("> ")
    local choice = io.read()
    if not choice then return nil end
    choice = choice:lower()
    if choice == "q" then
      return nil
    elseif choice == "n" then
      if page < totalPages then page = page + 1 end
    elseif choice == "p" then
      if page > 1 then page = page - 1 end
    else
      local num = tonumber(choice)
      if num and num >= 1 and num <= #items then
        return items[num]
      end
    end
  end
end

local function chooseGeoNode(promptTitle)
  local items = {}
  for i = 1, #db.geoOrder do items[#items + 1] = db.geoOrder[i] end
  if #items == 0 then
    clear()
    print("No geo nodes known.")
    pause()
    return nil
  end
  local nodeId = listPaged(promptTitle or "Choose geo node", items, function(nodeId)
    local n = db.geoNodes[nodeId]
    local slots = n and n.slots and #n.slots or 0
    return string.format("%s [%s] slots=%d addr=%s", tostring(n.groupName or n.nodeId), tostring(n.nodeId), slots, short(n.addr))
  end)
  if nodeId then return db.geoNodes[nodeId] end
  return nil
end

local function chooseProjectorNode(promptTitle)
  local items = {}
  for i = 1, #db.projectorOrder do items[#items + 1] = db.projectorOrder[i] end
  if #items == 0 then
    clear()
    print("No projector nodes known.")
    pause()
    return nil
  end
  local nodeId = listPaged(promptTitle or "Choose projector node", items, function(nodeId)
    local n = db.projectorNodes[nodeId]
    local projs = n and n.projectors and #n.projectors or 0
    return string.format("%s [%s] projectors=%d addr=%s", tostring(n.groupName or n.nodeId), tostring(n.nodeId), projs, short(n.addr))
  end)
  if nodeId then return db.projectorNodes[nodeId] end
  return nil
end

local function chooseSlot(node, promptTitle)
  if not node or not node.slots or #node.slots == 0 then
    clear()
    print("No slots available on that geo node.")
    pause()
    return nil
  end
  local slot = listPaged(promptTitle or "Choose slot", node.slots, function(slot)
    return string.format("%s  geo=%s  size=%dx%dx%d", tostring(slot.name), tostring(slot.geoAlias), tonumber(slot.sizeX or 0), tonumber(slot.sizeY or 0), tonumber(slot.sizeZ or 0))
  end)
  return slot
end

local function chooseProjector(node, promptTitle)
  if not node or not node.projectors or #node.projectors == 0 then
    clear()
    print("No projectors available on that node.")
    pause()
    return nil
  end
  local proj = listPaged(promptTitle or "Choose projector", node.projectors, function(proj)
    return string.format("%s  depth=%s  addr=%s", tostring(proj.alias), tostring(proj.depth or "?"), short(proj.address))
  end)
  return proj
end

local function ensureSnapshotCache(nodeId)
  db.snapshotCache[nodeId] = db.snapshotCache[nodeId] or {}
  return db.snapshotCache[nodeId]
end

local function requestSnapshots(node, slotNames)
  if not node or not node.addr then return false, "Node offline" end
  local requestId = "req_" .. tostring(math.floor(computer.uptime() * 1000)) .. "_" .. tostring(math.random(1000, 9999))
  local wanted = nil
  if slotNames then
    wanted = {}
    for i = 1, #slotNames do wanted[#wanted + 1] = slotNames[i] end
  end
  modem.send(node.addr, PORT, serialization.serialize({
    t = "geo.snapshot.request",
    requestId = requestId,
    slots = wanted,
  }))

  local slotTransfers = {}
  local done = false
  local lastPacket = computer.uptime()

  while not done and (computer.uptime() - lastPacket) < 30 do
    local fromAddr, packet = waitPacket(2)
    if packet then
      lastPacket = computer.uptime()
      if fromAddr == node.addr then
        if packet.t == "geo.announce" then
          refreshNodeFromPacket(fromAddr, packet)
        elseif packet.t == "geo.snapshot.start" and packet.requestId == requestId then
          -- no-op
        elseif packet.t == "geo.slot.begin" and packet.requestId == requestId then
          slotTransfers[packet.slotName] = {
            meta = {
              slotName = packet.slotName,
              geoAlias = packet.geoAlias,
              sizeX = packet.sizeX,
              sizeY = packet.sizeY,
              sizeZ = packet.sizeZ,
              mode = packet.mode,
              updatedAt = packet.updatedAt,
            },
            voxels = {},
          }
        elseif packet.t == "geo.slot.chunk" and packet.requestId == requestId then
          local transfer = slotTransfers[packet.slotName]
          if transfer and type(packet.voxels) == "table" then
            for i = 1, #packet.voxels do
              transfer.voxels[#transfer.voxels + 1] = packet.voxels[i]
            end
          end
        elseif packet.t == "geo.slot.end" and packet.requestId == requestId then
          local transfer = slotTransfers[packet.slotName]
          if transfer then
            local cache = ensureSnapshotCache(node.nodeId)
            cache[packet.slotName] = {
              meta = transfer.meta,
              voxels = transfer.voxels,
            }
          end
        elseif packet.t == "geo.snapshot.done" and packet.requestId == requestId then
          done = true
        end
      else
        refreshNodeFromPacket(fromAddr, packet)
      end
    end
  end

  saveDb()
  if done then
    return true
  end
  return false, "Timed out waiting for snapshots"
end

local function rotateVoxel(x, z, sx, sz, rotation)
  rotation = rotation or 0
  if rotation == 90 then
    return (sz - z + 1), x, sz, sx
  elseif rotation == 180 then
    return (sx - x + 1), (sz - z + 1), sx, sz
  elseif rotation == 270 then
    return z, (sx - x + 1), sz, sx
  end
  return x, z, sx, sz
end

local function buildProjectorBatches(scene)
  local batches = {}
  for i = 1, #(scene.placements or {}) do
    local p = scene.placements[i]
    if p.enabled ~= false then
      local cacheNode = db.snapshotCache[p.geoNodeId]
      local snap = cacheNode and cacheNode[p.slotName] or nil
      if snap and snap.meta and snap.voxels then
        local key = p.projectorNodeId .. "::" .. p.projectorAlias
        batches[key] = batches[key] or {
          projectorNodeId = p.projectorNodeId,
          projectorAlias = p.projectorAlias,
          voxels = {},
        }
        local batch = batches[key]
        local sx = tonumber(snap.meta.sizeX or 0)
        local sy = tonumber(snap.meta.sizeY or 0)
        local sz = tonumber(snap.meta.sizeZ or 0)
        local rot = tonumber(p.rotation or 0)
        local outSX, outSZ = sx, sz
        if rot == 90 or rot == 270 then outSX, outSZ = sz, sx end
        local baseX, baseY, baseZ
        if p.center then
          baseX = math.floor((48 - outSX) / 2) + 1 + tonumber(p.offsetX or 0)
          baseY = math.floor((32 - sy) / 2) + 1 + tonumber(p.offsetY or 0)
          baseZ = math.floor((48 - outSZ) / 2) + 1 + tonumber(p.offsetZ or 0)
        else
          baseX = tonumber(p.offsetX or 1)
          baseY = tonumber(p.offsetY or 1)
          baseZ = tonumber(p.offsetZ or 1)
        end
        for vi = 1, #snap.voxels do
          local v = snap.voxels[vi]
          local rx, rz = rotateVoxel(v.x, v.z, sx, sz, rot)
          local tx = baseX + rx - 1
          local ty = baseY + v.y - 1
          local tz = baseZ + rz - 1
          if tx >= 1 and tx <= 48 and ty >= 1 and ty <= 32 and tz >= 1 and tz <= 48 then
            batch.voxels[#batch.voxels + 1] = {x = tx, y = ty, z = tz, v = v.v}
          end
        end
      end
    end
  end
  return batches
end

local function sendBatchToProjector(node, projectorAlias, sceneName, voxels)
  if not node or not node.addr then return false, "Projector node offline" end
  local transferId = "tx_" .. tostring(math.floor(computer.uptime() * 1000)) .. "_" .. tostring(math.random(1000, 9999))
  modem.send(node.addr, PORT, serialization.serialize({
    t = "proj.begin",
    transferId = transferId,
    projectorAlias = projectorAlias,
    sceneName = sceneName,
    count = #voxels,
  }))
  local idx = 1
  while idx <= #voxels do
    local chunk = {}
    for _ = 1, CHUNK_VOXELS do
      if idx > #voxels then break end
      chunk[#chunk + 1] = voxels[idx]
      idx = idx + 1
    end
    modem.send(node.addr, PORT, serialization.serialize({
      t = "proj.chunk",
      transferId = transferId,
      projectorAlias = projectorAlias,
      voxels = chunk,
    }))
  end
  modem.send(node.addr, PORT, serialization.serialize({
    t = "proj.end",
    transferId = transferId,
    projectorAlias = projectorAlias,
  }))

  local deadline = computer.uptime() + 10
  while computer.uptime() < deadline do
    local fromAddr, packet = waitPacket(1)
    if packet then
      if fromAddr == node.addr and packet.t == "proj.rendered" and packet.transferId == transferId then
        return true
      else
        refreshNodeFromPacket(fromAddr, packet)
      end
    end
  end
  return false, "Timed out waiting for projector render ack"
end

local function sceneReferencesNode(scene, nodeId)
  for i = 1, #(scene.placements or {}) do
    local p = scene.placements[i]
    if p.geoNodeId == nodeId then return true end
  end
  return false
end

local function ensureSceneSnapshots(scene)
  local needByNode = {}
  for i = 1, #(scene.placements or {}) do
    local p = scene.placements[i]
    if p.enabled ~= false then
      local cacheNode = db.snapshotCache[p.geoNodeId]
      local have = cacheNode and cacheNode[p.slotName]
      if not have then
        needByNode[p.geoNodeId] = needByNode[p.geoNodeId] or {}
        needByNode[p.geoNodeId][#needByNode[p.geoNodeId] + 1] = p.slotName
      end
    end
  end
  for nodeId, slots in pairs(needByNode) do
    local node = db.geoNodes[nodeId]
    if node then
      local ok, err = requestSnapshots(node, slots)
      if not ok then return false, err end
    else
      return false, "Missing geo node " .. tostring(nodeId)
    end
  end
  return true
end

local function loadScene(scene)
  local ok, err = ensureSceneSnapshots(scene)
  if not ok then
    clear()
    print("Failed to prepare scene: " .. tostring(err))
    pause()
    return
  end

  local touchedNodes = {}
  for i = 1, #(scene.placements or {}) do
    local p = scene.placements[i]
    touchedNodes[p.projectorNodeId] = true
  end
  for nodeId in pairs(touchedNodes) do
    local node = db.projectorNodes[nodeId]
    if node and node.addr then
      modem.send(node.addr, PORT, serialization.serialize({t = "proj.clear"}))
    end
  end

  local batches = buildProjectorBatches(scene)
  local keys = {}
  for key in pairs(batches) do keys[#keys + 1] = key end
  table.sort(keys)

  clear()
  print("Loading scene: " .. tostring(scene.name))
  print("Targets: " .. tostring(#keys))
  local failures = 0

  for i = 1, #keys do
    local batch = batches[keys[i]]
    local node = db.projectorNodes[batch.projectorNodeId]
    term.setCursor(1, 4)
    io.write(string.rep(" ", 70))
    term.setCursor(1, 4)
    io.write(string.format("[%d/%d] %s -> %s (%d voxels)", i, #keys, tostring(node and node.groupName or batch.projectorNodeId), tostring(batch.projectorAlias), #batch.voxels))
    local ok2, err2 = sendBatchToProjector(node, batch.projectorAlias, scene.name, batch.voxels)
    if not ok2 then
      failures = failures + 1
      term.setCursor(1, 6 + failures)
      io.write("Failed: " .. tostring(err2))
    end
  end

  db.activeScene = scene.name
  saveDb()
  print("")
  print("Scene loaded. Failures: " .. tostring(failures))
  pause()
end

local function showSceneInfo(scene)
  clear()
  print("Scene: " .. tostring(scene.name))
  print(string.rep("-", 8 + #tostring(scene.name)))
  print("Placements: " .. tostring(#(scene.placements or {})))
  print("Active:     " .. tostring(db.activeScene == scene.name))
  print("")
  for i = 1, #(scene.placements or {}) do
    local p = scene.placements[i]
    print(string.format("%d) %s/%s -> %s/%s rot=%d center=%s off=(%d,%d,%d)",
      i,
      tostring(p.geoNodeId),
      tostring(p.slotName),
      tostring(p.projectorNodeId),
      tostring(p.projectorAlias),
      tonumber(p.rotation or 0),
      tostring(p.center ~= false),
      tonumber(p.offsetX or 0),
      tonumber(p.offsetY or 0),
      tonumber(p.offsetZ or 0)
    ))
  end
  pause()
end

local function configurePlacement(existing)
  local placement = clone(existing or {})
  local geoNode = placement.geoNodeId and db.geoNodes[placement.geoNodeId] or chooseGeoNode("Choose source geo node")
  if not geoNode then return nil end
  placement.geoNodeId = geoNode.nodeId
  local slot = chooseSlot(geoNode, "Choose source scan slot")
  if not slot then return nil end
  placement.slotName = slot.name

  local projectorNode = placement.projectorNodeId and db.projectorNodes[placement.projectorNodeId] or chooseProjectorNode("Choose target projector node")
  if not projectorNode then return nil end
  placement.projectorNodeId = projectorNode.nodeId
  local projector = chooseProjector(projectorNode, "Choose target projector")
  if not projector then return nil end
  placement.projectorAlias = projector.alias

  clear()
  print("Placement transforms")
  print("--------------------")
  placement.enabled = promptBool("enabled", placement.enabled ~= false)
  placement.center = promptBool("center", placement.center ~= false)
  placement.rotation = promptNumber("rotation (0/90/180/270)", placement.rotation or 0, 0, 270)
  if placement.rotation ~= 0 and placement.rotation ~= 90 and placement.rotation ~= 180 and placement.rotation ~= 270 then
    placement.rotation = 0
  end
  if placement.center then
    placement.offsetX = promptNumber("offsetX (centered)", placement.offsetX or 0, -48, 48)
    placement.offsetY = promptNumber("offsetY (centered)", placement.offsetY or 0, -32, 32)
    placement.offsetZ = promptNumber("offsetZ (centered)", placement.offsetZ or 0, -48, 48)
  else
    placement.offsetX = promptNumber("target start X", placement.offsetX or 1, 1, 48)
    placement.offsetY = promptNumber("target start Y", placement.offsetY or 1, 1, 32)
    placement.offsetZ = promptNumber("target start Z", placement.offsetZ or 1, 1, 48)
  end
  return placement
end

local function editScene(scene)
  while true do
    clear()
    print("Edit scene: " .. tostring(scene.name))
    print("-----------------------------")
    print("Placements: " .. tostring(#(scene.placements or {})))
    for i = 1, #(scene.placements or {}) do
      local p = scene.placements[i]
      print(string.format("%d) %s -> %s", i, tostring(p.slotName), tostring(p.projectorAlias)))
    end
    print("")
    print("A add placement")
    print("E edit placement")
    print("R remove placement")
    print("I info")
    print("Q done")
    io.write("> ")
    local choice = io.read()
    if not choice then return end
    choice = choice:lower()
    if choice == "q" then
      saveDb()
      return
    elseif choice == "a" then
      local p = configurePlacement(nil)
      if p then
        scene.placements = scene.placements or {}
        scene.placements[#scene.placements + 1] = p
      end
    elseif choice == "e" then
      local idx = promptNumber("Placement number", 1, 1, #(scene.placements or {}))
      if scene.placements[idx] then
        local p = configurePlacement(scene.placements[idx])
        if p then scene.placements[idx] = p end
      end
    elseif choice == "r" then
      local idx = promptNumber("Placement number", 1, 1, #(scene.placements or {}))
      if scene.placements[idx] then table.remove(scene.placements, idx) end
    elseif choice == "i" then
      showSceneInfo(scene)
    end
  end
end

local function createScene()
  clear()
  print("Create scene")
  print("------------")
  local name = promptString("Scene name", "")
  if not name or name == "" then return end
  if db.scenes[name] then
    print("Scene already exists.")
    pause()
    return
  end
  local scene = {name = name, placements = {}}
  db.scenes[name] = scene
  ensureOrderEntry(db.sceneOrder, name)
  editScene(scene)
  saveDb()
end

local function chooseScene()
  if #db.sceneOrder == 0 then
    clear()
    print("No scenes available.")
    pause()
    return nil
  end
  local name = listPaged("Choose scene", db.sceneOrder, function(name)
    local s = db.scenes[name]
    return string.format("%s  placements=%d  active=%s", tostring(name), #(s.placements or {}), tostring(db.activeScene == name))
  end)
  if name then return db.scenes[name] end
  return nil
end

local function deleteScene(scene)
  db.scenes[scene.name] = nil
  removeOrderEntry(db.sceneOrder, scene.name)
  if db.activeScene == scene.name then db.activeScene = nil end
  saveDb()
end

local function geoNodeMenu(node)
  while true do
    clear()
    print("Geo node: " .. tostring(node.groupName or node.nodeId))
    print("--------------------------------")
    print("nodeId: " .. tostring(node.nodeId))
    print("addr:   " .. tostring(short(node.addr)))
    print("slots:  " .. tostring(node.slots and #node.slots or 0))
    print("")
    print("1 View slots/geolyzers")
    print("2 Get Live Snapshot (all slots)")
    print("3 Get one slot snapshot")
    print("4 Refresh discovery for this node")
    print("0 Back")
    io.write("> ")
    local choice = io.read()
    if choice == "0" then return
    elseif choice == "1" then
      clear()
      print("Geolyzers:")
      for i = 1, #(node.geolyzers or {}) do
        local g = node.geolyzers[i]
        print(string.format("  %d) %s [%s]", i, tostring(g.alias), short(g.address)))
      end
      print("")
      print("Slots:")
      for i = 1, #(node.slots or {}) do
        local s = node.slots[i]
        print(string.format("  %d) %s -> %s size=%dx%dx%d mode=%s", i, tostring(s.name), tostring(s.geoAlias), tonumber(s.sizeX or 0), tonumber(s.sizeY or 0), tonumber(s.sizeZ or 0), tostring(s.mode or "?")))
      end
      pause()
    elseif choice == "2" then
      clear()
      print("Fetching all snapshots from " .. tostring(node.groupName or node.nodeId) .. "...")
      local ok, err = requestSnapshots(node, nil)
      print(ok and "Done." or ("Failed: " .. tostring(err)))
      if ok and db.activeScene and db.scenes[db.activeScene] and sceneReferencesNode(db.scenes[db.activeScene], node.nodeId) then
        local reload = promptBool("Reload active scene now?", true)
        if reload then loadScene(db.scenes[db.activeScene]) end
      else
        pause()
      end
    elseif choice == "3" then
      local slot = chooseSlot(node, "Choose slot to refresh")
      if slot then
        clear()
        print("Fetching snapshot: " .. tostring(slot.name))
        local ok, err = requestSnapshots(node, {slot.name})
        print(ok and "Done." or ("Failed: " .. tostring(err)))
        if ok and db.activeScene and db.scenes[db.activeScene] and sceneReferencesNode(db.scenes[db.activeScene], node.nodeId) then
          local reload = promptBool("Reload active scene now?", true)
          if reload then loadScene(db.scenes[db.activeScene]) end
        else
          pause()
        end
      end
    elseif choice == "4" then
      modem.send(node.addr, PORT, serialization.serialize({t = "geo.discover"}))
      local fromAddr, packet = waitPacket(2)
      if packet and fromAddr == node.addr and packet.t == "geo.announce" then
        refreshNodeFromPacket(fromAddr, packet)
        node = db.geoNodes[node.nodeId]
        saveDb()
      end
    end
  end
end

local function projectorNodeMenu(node)
  while true do
    clear()
    print("Projector node: " .. tostring(node.groupName or node.nodeId))
    print("------------------------------------------")
    print("nodeId:      " .. tostring(node.nodeId))
    print("addr:        " .. tostring(short(node.addr)))
    print("projectors:  " .. tostring(node.projectors and #node.projectors or 0))
    print("")
    print("1 View projectors")
    print("2 Clear all projectors on this node")
    print("3 Refresh discovery for this node")
    print("0 Back")
    io.write("> ")
    local choice = io.read()
    if choice == "0" then return
    elseif choice == "1" then
      clear()
      for i = 1, #(node.projectors or {}) do
        local p = node.projectors[i]
        print(string.format("%d) %s depth=%s addr=%s", i, tostring(p.alias), tostring(p.depth or "?"), short(p.address)))
      end
      pause()
    elseif choice == "2" then
      if node.addr then
        modem.send(node.addr, PORT, serialization.serialize({t = "proj.clear"}))
      end
      print("Clear sent.")
      pause()
    elseif choice == "3" then
      modem.send(node.addr, PORT, serialization.serialize({t = "proj.discover"}))
      local fromAddr, packet = waitPacket(2)
      if packet and fromAddr == node.addr and packet.t == "proj.announce" then
        refreshNodeFromPacket(fromAddr, packet)
        node = db.projectorNodes[node.nodeId]
        saveDb()
      end
    end
  end
end

local function geoNodesMenu()
  while true do
    local node = chooseGeoNode("Geo Nodes")
    if not node then return end
    geoNodeMenu(node)
  end
end

local function projectorNodesMenu()
  while true do
    local node = chooseProjectorNode("Projector Nodes")
    if not node then return end
    projectorNodeMenu(node)
  end
end

local function scenesMenu()
  while true do
    clear()
    print("Scenes")
    print("------")
    print("Active scene: " .. tostring(db.activeScene or "(none)"))
    print("Count: " .. tostring(#db.sceneOrder))
    print("")
    print("1 Create scene")
    print("2 Edit scene")
    print("3 Load scene")
    print("4 Delete scene")
    print("5 Scene info")
    print("0 Back")
    io.write("> ")
    local choice = io.read()
    if choice == "0" then return
    elseif choice == "1" then
      createScene()
    elseif choice == "2" then
      local scene = chooseScene()
      if scene then editScene(scene) end
    elseif choice == "3" then
      local scene = chooseScene()
      if scene then loadScene(scene) end
    elseif choice == "4" then
      local scene = chooseScene()
      if scene then
        local sure = promptBool("Delete scene " .. tostring(scene.name) .. "?", false)
        if sure then deleteScene(scene) end
      end
    elseif choice == "5" then
      local scene = chooseScene()
      if scene then showSceneInfo(scene) end
    end
  end
end

local function systemMenu()
  while true do
    clear()
    print("System")
    print("------")
    print("1 Discover nodes")
    print("2 Save database")
    print("3 Show cache summary")
    print("0 Back")
    io.write("> ")
    local choice = io.read()
    if choice == "0" then return
    elseif choice == "1" then
      discoverNodes()
    elseif choice == "2" then
      local ok, err = saveDb()
      print(ok and "Saved." or ("Save failed: " .. tostring(err)))
      pause()
    elseif choice == "3" then
      clear()
      print("Snapshot cache")
      print("--------------")
      for nodeId, slots in pairs(db.snapshotCache or {}) do
        local count = 0
        for _ in pairs(slots) do count = count + 1 end
        print(string.format("%s: %d slots cached", tostring(nodeId), count))
      end
      if not next(db.snapshotCache or {}) then
        print("(empty)")
      end
      pause()
    end
  end
end

math.randomseed(math.floor(computer.uptime() * 1000))
loadDb()
pcall(modem.open, PORT)

while true do
  clear()
  print("Geo Console V7")
  print("--------------")
  print("Geo nodes:       " .. tostring(#db.geoOrder))
  print("Projector nodes: " .. tostring(#db.projectorOrder))
  print("Scenes:          " .. tostring(#db.sceneOrder))
  print("Active scene:    " .. tostring(db.activeScene or "(none)"))
  print("")
  print("1 Geo Nodes")
  print("2 Projector Nodes")
  print("3 Scenes")
  print("4 System")
  print("0 Quit")
  io.write("> ")
  local choice = io.read()
  if choice == "0" then
    saveDb()
    clear()
    break
  elseif choice == "1" then
    geoNodesMenu()
  elseif choice == "2" then
    projectorNodesMenu()
  elseif choice == "3" then
    scenesMenu()
  elseif choice == "4" then
    systemMenu()
  end
end
