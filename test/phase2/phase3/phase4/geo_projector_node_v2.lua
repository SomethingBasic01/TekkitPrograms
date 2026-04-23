
local component = require("component")
local serialization = require("serialization")
local event = require("event")
local term = require("term")
local computer = require("computer")

assert(component.isAvailable("modem"), "No modem found")
assert(component.isAvailable("hologram"), "No hologram projector found")

local modem = component.modem
local PORT = 3413
local CFG_PATH = "/home/geo_projector_node_v2.cfg"
local CHUNK_VOXELS = 48

local cfg = {
  nodeId = nil,
  groupName = nil,
  label = nil,
  defaults = {
    scale = 1,
    color1 = 0x00FF00,
    color2 = 0x00FFFF,
    color3 = 0xFF4040,
  },
  projectors = {},
}

local function short(addr)
  if not addr then return "?" end
  return tostring(addr):sub(1, 8)
end

local function loadCfg()
  local f = io.open(CFG_PATH, "r")
  if not f then return false end
  local raw = f:read("*a")
  f:close()
  local ok, data = pcall(serialization.unserialize, raw)
  if ok and type(data) == "table" then
    cfg = data
    cfg.defaults = cfg.defaults or {}
    cfg.projectors = cfg.projectors or {}
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
  return n
end

local function promptHex(label, current)
  io.write(string.format("%s [0x%06X]: ", label, tonumber(current or 0)))
  local s = io.read()
  if not s or s == "" then return current end
  s = s:gsub("^0[xX]", "")
  local n = tonumber(s, 16)
  if not n then return current end
  if n < 0 then n = 0 end
  if n > 0xFFFFFF then n = 0xFFFFFF end
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

local function clear()
  term.clear()
  term.setCursor(1, 1)
end

local function pause(msg)
  print("")
  io.write(msg or "Press Enter...")
  io.read()
end

local function discoverProjectors()
  local found = {}
  for addr in component.list("hologram", true) do
    found[#found + 1] = addr
  end
  table.sort(found)
  return found
end

local function ensureProjectorEntries()
  local found = discoverProjectors()
  local existingByAddr = {}
  for i = 1, #(cfg.projectors or {}) do existingByAddr[cfg.projectors[i].address] = cfg.projectors[i] end
  local updated = {}
  for i = 1, #found do
    local addr = found[i]
    local p = existingByAddr[addr] or {
      address = addr,
      alias = "Projector" .. tostring(i),
      enabled = true,
      scale = cfg.defaults.scale or 1,
      color1 = cfg.defaults.color1 or 0x00FF00,
      color2 = cfg.defaults.color2 or 0x00FFFF,
      color3 = cfg.defaults.color3 or 0xFF4040,
    }
    updated[#updated + 1] = p
  end
  cfg.projectors = updated
end

local function projectorDepth(proxy)
  if proxy.maxDepth then
    local ok, d = pcall(proxy.maxDepth)
    if ok and type(d) == "number" then return d end
  end
  return 1
end

local function projectorByAlias(alias)
  for i = 1, #(cfg.projectors or {}) do
    local entry = cfg.projectors[i]
    if entry.alias == alias and entry.enabled ~= false then
      return component.proxy(entry.address), entry
    end
  end
  return nil, nil
end

local function announce(toAddr)
  local projectors = {}
  for i = 1, #(cfg.projectors or {}) do
    local entry = cfg.projectors[i]
    local proxy = component.proxy(entry.address)
    projectors[#projectors + 1] = {
      address = entry.address,
      alias = entry.alias,
      enabled = entry.enabled ~= false,
      depth = projectorDepth(proxy),
    }
  end
  local packet = {
    t = "proj.announce",
    nodeId = cfg.nodeId,
    groupName = cfg.groupName,
    label = cfg.label,
    projectors = projectors,
  }
  local data = serialization.serialize(packet)
  if toAddr then modem.send(toAddr, PORT, data) else modem.broadcast(PORT, data) end
end

local function setPalette(proxy, entry)
  local depth = projectorDepth(proxy)
  pcall(proxy.setPaletteColor, 1, entry.color1 or cfg.defaults.color1 or 0x00FF00)
  if depth > 1 then
    pcall(proxy.setPaletteColor, 2, entry.color2 or cfg.defaults.color2 or 0x00FFFF)
    pcall(proxy.setPaletteColor, 3, entry.color3 or cfg.defaults.color3 or 0xFF4040)
  end
end

local transfers = {}

local function clearProjector(alias)
  if alias then
    local proxy = projectorByAlias(alias)
    if proxy then pcall(proxy.clear) end
  else
    for i = 1, #(cfg.projectors or {}) do
      local proxy, entry = projectorByAlias(cfg.projectors[i].alias)
      if proxy and entry then pcall(proxy.clear) end
    end
  end
end

local function renderTransfer(fromAddr, transferId)
  local transfer = transfers[transferId]
  if not transfer then return end
  local proxy, entry = projectorByAlias(transfer.projectorAlias)
  if not proxy or not entry then
    modem.send(fromAddr, PORT, serialization.serialize({
      t = "proj.rendered",
      transferId = transferId,
      error = "Missing projector " .. tostring(transfer.projectorAlias),
    }))
    transfers[transferId] = nil
    return
  end

  pcall(proxy.clear)
  pcall(proxy.setScale, tonumber(entry.scale or cfg.defaults.scale or 1))
  setPalette(proxy, entry)

  local count = 0
  for i = 1, #transfer.voxels do
    local v = transfer.voxels[i]
    if v.x and v.y and v.z and v.v and v.x >= 1 and v.x <= 48 and v.y >= 1 and v.y <= 32 and v.z >= 1 and v.z <= 48 then
      pcall(proxy.set, v.x, v.y, v.z, v.v)
      count = count + 1
    end
  end

  modem.send(fromAddr, PORT, serialization.serialize({
    t = "proj.rendered",
    transferId = transferId,
    projectorAlias = transfer.projectorAlias,
    count = count,
  }))
  transfers[transferId] = nil
end

local function chooseProjectorEntry()
  while true do
    clear()
    print("Choose projector")
    print("----------------")
    for i = 1, #(cfg.projectors or {}) do
      local p = cfg.projectors[i]
      print(string.format("%d) %s [%s] enabled=%s", i, tostring(p.alias), short(p.address), tostring(p.enabled ~= false)))
    end
    print("0) Back")
    io.write("> ")
    local choice = tonumber(io.read() or "")
    if choice == 0 then return nil end
    if choice and cfg.projectors[choice] then return cfg.projectors[choice] end
  end
end

local function editDefaults()
  clear()
  print("Node defaults")
  print("-------------")
  cfg.defaults.scale = promptNumber("scale", cfg.defaults.scale or 1, 0.33, 3)
  cfg.defaults.color1 = promptHex("color1", cfg.defaults.color1 or 0x00FF00)
  cfg.defaults.color2 = promptHex("color2", cfg.defaults.color2 or 0x00FFFF)
  cfg.defaults.color3 = promptHex("color3", cfg.defaults.color3 or 0xFF4040)
  saveCfg()
end

local function editProjectors()
  while true do
    clear()
    print("Projectors on this node")
    print("-----------------------")
    for i = 1, #(cfg.projectors or {}) do
      local p = cfg.projectors[i]
      print(string.format("%d) %s [%s] enabled=%s", i, tostring(p.alias), short(p.address), tostring(p.enabled ~= false)))
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
      local entry = chooseProjectorEntry()
      if entry then
        clear()
        print("Edit projector: " .. tostring(entry.alias))
        entry.alias = promptString("alias", entry.alias)
        entry.enabled = promptBool("enabled", entry.enabled ~= false)
        entry.scale = promptNumber("scale", entry.scale or cfg.defaults.scale or 1, 0.33, 3)
        entry.color1 = promptHex("color1", entry.color1 or cfg.defaults.color1 or 0x00FF00)
        entry.color2 = promptHex("color2", entry.color2 or cfg.defaults.color2 or 0x00FFFF)
        entry.color3 = promptHex("color3", entry.color3 or cfg.defaults.color3 or 0xFF4040)
        saveCfg()
      end
    end
  end
end

local function setupWizard()
  ensureProjectorEntries()
  clear()
  print("Geo Projector Node V2 setup")
  print("---------------------------")
  local defaultId = cfg.nodeId or ("proj_" .. short(computer.address()))
  cfg.nodeId = promptString("nodeId", defaultId)
  cfg.groupName = promptString("group name", cfg.groupName or cfg.nodeId)
  cfg.label = promptString("label", cfg.label or cfg.groupName)
  editDefaults()
  editProjectors()
  saveCfg()
  announce(nil)
end

loadCfg()
ensureProjectorEntries()
if not cfg.nodeId or (...) == "setup" then
  setupWizard()
else
  clear()
  print("Geo Projector Node V2")
  print("---------------------")
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
print("Geo Projector Node V2")
print("---------------------")
print("nodeId:     " .. tostring(cfg.nodeId))
print("groupName:  " .. tostring(cfg.groupName))
print("projectors: " .. tostring(#(cfg.projectors or {})))
print("port:       " .. tostring(PORT))
print("")
print("Listening...")

while true do
  local ev = {event.pull("modem_message")}
  local _, _, fromAddr, port, _, msg = table.unpack(ev)
  if port == PORT and type(msg) == "string" then
    local ok, packet = pcall(serialization.unserialize, msg)
    if ok and type(packet) == "table" then
      if packet.t == "proj.discover" then
        announce(fromAddr)
      elseif packet.t == "proj.clear" then
        clearProjector(packet.projectorAlias)
      elseif packet.t == "proj.begin" then
        transfers[packet.transferId] = {
          projectorAlias = packet.projectorAlias,
          sceneName = packet.sceneName,
          voxels = {},
        }
      elseif packet.t == "proj.chunk" then
        local transfer = transfers[packet.transferId]
        if transfer and transfer.projectorAlias == packet.projectorAlias and type(packet.voxels) == "table" then
          for i = 1, #packet.voxels do
            transfer.voxels[#transfer.voxels + 1] = packet.voxels[i]
          end
        end
      elseif packet.t == "proj.end" then
        renderTransfer(fromAddr, packet.transferId)
        term.setCursor(1, 9)
        io.write("Last transfer: " .. tostring(packet.transferId) .. "                    ")
      end
    end
  end
end
