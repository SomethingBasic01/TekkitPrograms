-- SpawnNet 2.3.1 - ENHANCED STORAGE VAULT NODE
local VERSION='2.3.1';local ROOT='/spawnnet-node';local cfgPath=ROOT..'/node.cfg'
local util=dofile(ROOT..'/util.lua');local wire=dofile(ROOT..'/wire.lua');local crypto=dofile(ROOT..'/crypto.lua')
local cfg=util.loadTable(cfgPath,nil);if type(cfg)~='table'then error('Missing '..cfgPath,0)end
local discovery='spawnnet:discovery:v2';local backbone='spawnnet:backbone:'..cfg.networkId..':v2';local fragments={};local boot=crypto.randomHex(8);local nodeSeq=0

local function save()util.saveTable(cfgPath,cfg)end
local function findModem()
  if cfg.modem and peripheral.isPresent(cfg.modem) and peripheral.getType(cfg.modem)=='modem' then return cfg.modem end
  for _,n in ipairs(peripheral.getNames()) do if peripheral.getType(n)=='modem' then return n end end
end
local modem=findModem();if not modem then error('Storage Node requires a modem',0)end
if not rednet.isOpen(modem)then rednet.open(modem)end;cfg.modem=modem;save()

local function objectPath(id)
  local safe=tostring(id):gsub('[^%w%-_]','_')
  local dir=ROOT..'/objects/'..safe:sub(1,2)
  util.ensureDir(dir)
  return dir..'/'..safe..'.obj'
end

local function stats()
  local free='?';local ok,v=pcall(fs.getFreeSpace,ROOT);if ok then free=v end
  local cap=nil;if fs.getCapacity then local ok2,c=pcall(fs.getCapacity,ROOT);if ok2 then cap=c end end
  local count=0;if fs.exists(ROOT..'/objects')then
    local function walk(p)for _,n in ipairs(fs.list(p))do local x=fs.combine(p,n);if fs.isDir(x)then walk(x)else count=count+1 end end end
    walk(ROOT..'/objects')
  end
  return free,cap,count
end

local function drawBar(percent, width)
  local filled = math.floor(percent * width)
  return "[" .. string.rep("=", filled) .. string.rep("-", width - filled) .. "]"
end

local function paint()
  term.setBackgroundColor(colors.black);term.clear();term.setCursorPos(1,1)
  term.setBackgroundColor(colors.purple);term.setTextColor(colors.white);term.clearLine()
  write('  SPAWNNET // STORAGE VAULT NODE v'..VERSION..'  ')
  term.setBackgroundColor(colors.black)
  
  term.setCursorPos(2,3);term.setTextColor(colors.cyan)
  print('Vault Name : '..tostring(cfg.name or('#'..os.getComputerID())))
  term.setTextColor(colors.lightGray)
  print(' Network   : '..tostring(cfg.networkName or cfg.networkId))
  print(' Core ID   : #'..tostring(cfg.coreId or 'DISCOVERING...'))
  print(' Identity  : '..tostring(cfg.coreIdentity or 'UNPINNED'):sub(1,20))
  print(' Mode      : '..(cfg.readOnly and 'READ ONLY' or 'REPLICATING'))
  
  local free, cap, count = stats()
  print(' Objects   : '..tostring(count)..' item payloads')
  if type(free)=='number' and type(cap)=='number' and cap > 0 then
    local used = (cap - free) / cap
    term.setTextColor(colors.yellow)
    print(' Capacity  : '..drawBar(used, 14)..' '..math.floor(used*100)..'%')
  end

  term.setCursorPos(2,11)
  if cfg.token then
    term.setTextColor(colors.lime)
    print('[+] SECURE VAULT LINK ONLINE')
    term.setTextColor(colors.gray)
    print('    Ready for warehouse inventory replication.')
  else
    term.setTextColor(colors.orange)
    print('[!] UNPAIRED - WAITING FOR CORE APPROVAL')
    term.setTextColor(colors.white)
    print('\n PAIR CODE (Enter in Core Admin):')
    term.setTextColor(colors.yellow)
    print(' >> '..tostring(cfg.pairCode or 'GENERATING...')..' <<')
  end

  local _, sh = term.getSize()
  term.setCursorPos(1, sh)
  term.setBackgroundColor(colors.gray);term.setTextColor(colors.white);term.clearLine()
  write(' Ctrl+T Stop | spawnnet-node update | Computer ID: #'..os.getComputerID())
end

local function discoverCore()
  local nonce=util.id('node-discover')
  rednet.broadcast({network='spawnnet',version=2,type='discover',nonce=nonce},discovery)
  local timer=os.startTimer(1.5)
  while true do
    local ev={os.pullEvent()}
    if ev[1]=='timer' and ev[2]==timer then return nil end
    if ev[1]=='rednet_message' then
      local sender,msg,proto=ev[2],ev[3],ev[4]
      if proto==discovery and type(msg)=='table' and msg.type=='advertise' and msg.nonce==nonce and msg.networkId==cfg.networkId then
        if cfg.coreIdentity and msg.coreIdentity and cfg.coreIdentity~=msg.coreIdentity then
          cfg.identityConflict={expected=cfg.coreIdentity,received=msg.coreIdentity,computer=sender};save();return nil
        end
        cfg.coreId=sender;cfg.networkName=msg.name;cfg.coreIdentity=msg.coreIdentity or cfg.coreIdentity;save();return sender
      end
    end
  end
end

if not cfg.coreId then discoverCore() end

local function hello()
  if not cfg.coreId and not discoverCore() then return end
  local free,cap,count=stats()
  local msg={network='spawnnet',version=2,type='node_hello',networkId=cfg.networkId,name=cfg.name,free=free,capacity=cap,objects=count,nodeVersion=VERSION}
  
  if not cfg.token then
    if not cfg.pairCode then
      cfg.pairCode = crypto.randomHex(16)
      cfg.pairKey = crypto.sha256(cfg.pairCode)
      save()
    end
    local nonce=crypto.randomHex(10)
    msg.pairId=cfg.pairKey:sub(1,12)
    msg.helloNonce=nonce
    msg.proof=crypto.hmac(cfg.pairKey,table.concat({cfg.networkId,tostring(os.getComputerID()),nonce,msg.pairId},'|'))
  end
  rednet.send(cfg.coreId,msg,backbone)
end

local function heartbeat()
  if not cfg.coreId or not cfg.token then return end
  nodeSeq=nodeSeq+1
  local free,cap,count=stats()
  local msg={network='spawnnet',version=2,type='node_heartbeat',networkId=cfg.networkId,token=cfg.token,boot=boot,seq=nodeSeq,name=cfg.name,free=free,capacity=cap,objects=count,nodeVersion=VERSION}
  sign(msg);rednet.send(cfg.coreId,msg,backbone)
  util.writeFile(ROOT..'/runtime.heartbeat',tostring(os.clock()))
end

local function handleApproved(sender, msg)
  local pairKey = cfg.pairKey or (cfg.pairCode and crypto.sha256(cfg.pairCode))
  if not pairKey then return end
  local token, e = crypto.open(pairKey, msg.tokenBox, cfg.networkId..'|'..tostring(os.getComputerID()))
  if token then
    cfg.token = token
    cfg.name = msg.name or cfg.name
    cfg.coreIdentity = msg.coreIdentity or cfg.coreIdentity
    cfg.coreId = sender
    cfg.pairCode = nil
    cfg.pairKey = nil
    save()
    paint()
    heartbeat()
  else
    printError('Approval authentication failed: '..tostring(e))
  end
end

paint();hello();local timer=os.startTimer(cfg.token and 10 or 4)
while true do
  local ev={os.pullEvent()}
  if ev[1]=='timer' and ev[2]==timer then
    if cfg.token then heartbeat() else hello();paint() end
    timer=os.startTimer(cfg.token and 10 or 4)
  elseif ev[1]=='rednet_message' then
    local sender, rawMsg, proto = ev[2], ev[3], ev[4]
    if proto == backbone then
      -- Unconditionally accept fragment payloads regardless of pair token status
      local msg, isComplete = wire.accept(sender, rawMsg, fragments)
      wire.purge(fragments)
      if isComplete and type(msg) == 'table' then
        if msg.type == 'node_approved' and msg.networkId == cfg.networkId then
          if not cfg.coreId or sender == cfg.coreId then
            handleApproved(sender, msg)
          end
        elseif cfg.token then
          handle(sender, msg)
        end
      end
    end
  end
end
