-- SpawnNet 2.3.0 COMPLETE STORAGE NODE
-- Fresh install or in-place upgrade. No base installer or hotfix chain.
local files={
  ["/spawnnet-node.lua"]=[==[local a={...}
if a[1]=='update'then os.run({},'/spawnnet-node/updater.lua',a[2]or'update')
elseif a[1]=='status'then local u=dofile('/spawnnet-node/util.lua');local c=u.loadTable('/spawnnet-node/node.cfg',{});print('SN// STORAGE VAULT 2.3.0');print('Network: '..tostring(c.networkName or c.networkId));print('Core: #'..tostring(c.coreId or'?'));print('Paired: '..tostring(c.token~=nil));print('Read-only: '..tostring(c.readOnly==true))
else os.run({},'/spawnnet-node/node.lua')end
]==],
  ["/spawnnet-node/crypto.lua"]=[==[-- Pure-Lua SHA-256/HMAC adapter for ComputerCraft's bit/bit32 APIs.
local M={}
local b=_G.bit32 or _G.bit
if not b then error("SpawnNet crypto requires ComputerCraft bit or bit32 API") end
local band=b.band
local bor=b.bor
local bxor=b.bxor
local bnot=b.bnot
local lshift=b.lshift or b.blshift
local rshift=b.rshift or b.blogic_rshift or b.brshift
local rrotate=b.rrotate
if not rrotate then
  rrotate=function(x,n) n=n%32; return bor(rshift(x,n),lshift(x,32-n)) end
end
local function xor3(a,c,d) return bxor(bxor(a,c),d) end
local MOD=4294967296
local function u32(x) return x % MOD end
local K={
  0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
  0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
  0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
  0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
  0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
  0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
  0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
  0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2
}
local function wordToBytes(x)
  return string.char(rshift(x,24)%256,rshift(x,16)%256,rshift(x,8)%256,x%256)
end
local function bytesToWord(s,i)
  local a,b1,c,d=s:byte(i,i+3)
  return u32(a*16777216+b1*65536+c*256+d)
end
function M.sha256bin(msg)
  msg=tostring(msg or "")
  local bitLen=#msg*8
  msg=msg..string.char(0x80)
  local pad=(56-(#msg%64))%64
  msg=msg..string.rep("\0",pad)
  local hi=math.floor(bitLen/MOD)
  local lo=bitLen%MOD
  msg=msg..wordToBytes(hi)..wordToBytes(lo)
  local h0,h1,h2,h3,h4,h5,h6,h7=0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19
  local w={}
  for chunk=1,#msg,64 do
    for i=0,15 do w[i]=bytesToWord(msg,chunk+i*4) end
    for i=16,63 do
      local x=w[i-15]; local y=w[i-2]
      local s0=xor3(rrotate(x,7),rrotate(x,18),rshift(x,3))
      local s1=xor3(rrotate(y,17),rrotate(y,19),rshift(y,10))
      w[i]=u32(w[i-16]+s0+w[i-7]+s1)
    end
    local a,bv,c,d,e,f,g,h=h0,h1,h2,h3,h4,h5,h6,h7
    for i=0,63 do
      local S1=xor3(rrotate(e,6),rrotate(e,11),rrotate(e,25))
      local ch=bxor(band(e,f),band(bnot(e),g))
      local t1=u32(h+S1+ch+K[i+1]+w[i])
      local S0=xor3(rrotate(a,2),rrotate(a,13),rrotate(a,22))
      local maj=xor3(band(a,bv),band(a,c),band(bv,c))
      local t2=u32(S0+maj)
      h=g; g=f; f=e; e=u32(d+t1); d=c; c=bv; bv=a; a=u32(t1+t2)
    end
    h0=u32(h0+a); h1=u32(h1+bv); h2=u32(h2+c); h3=u32(h3+d)
    h4=u32(h4+e); h5=u32(h5+f); h6=u32(h6+g); h7=u32(h7+h)
  end
  return wordToBytes(h0)..wordToBytes(h1)..wordToBytes(h2)..wordToBytes(h3)..wordToBytes(h4)..wordToBytes(h5)..wordToBytes(h6)..wordToBytes(h7)
end
function M.toHex(s) return (s:gsub('.',function(c) return string.format('%02x',c:byte()) end)) end
function M.sha256(msg) return M.toHex(M.sha256bin(msg)) end
function M.hmac(key,msg)
  key=tostring(key or ""); msg=tostring(msg or "")
  if #key>64 then key=M.sha256bin(key) end
  key=key..string.rep("\0",64-#key)
  local opad,ipad={},{}
  for i=1,64 do local c=key:byte(i); opad[i]=string.char(bxor(c,0x5c)); ipad[i]=string.char(bxor(c,0x36)) end
  return M.toHex(M.sha256bin(table.concat(opad)..M.sha256bin(table.concat(ipad)..msg)))
end
function M.constantTimeEq(a,bv)
  a=tostring(a or ""); bv=tostring(bv or "")
  if #a~=#bv then return false end
  local diff=0
  for i=1,#a do diff=bor(diff,bxor(a:byte(i),bv:byte(i))) end
  return diff==0
end
local randomCounter=0
local randomState=M.sha256(table.concat({
  'SpawnNet-RNG-v2',tostring(os.getComputerID and os.getComputerID()or 0),
  tostring(os.epoch and os.epoch('utc')or''),tostring(os.clock and os.clock()or''),
  tostring(os.time and os.time()or''),tostring({})
},'\0'))
function M.randomHex(bytes)
  bytes=math.max(1,math.floor(tonumber(bytes)or 16));local out={};local have=0
  while have<bytes do
    randomCounter=randomCounter+1
    local jitter=table.concat({tostring(os.epoch and os.epoch('utc')or''),tostring(os.clock and os.clock()or''),tostring(math.random()),tostring(randomCounter)},'\0')
    randomState=M.sha256(randomState..'\0'..jitter);out[#out+1]=randomState;have=have+32
  end
  return table.concat(out):sub(1,bytes*2)
end

function M.fromHex(s)
  s=tostring(s or'')
  if #s%2~=0 or s:find('[^0-9a-fA-F]')then return nil,'invalid hex'end
  return(s:gsub('..',function(x)return string.char(tonumber(x,16))end))
end

-- Deliberately slower than a single SHA-256. Existing 2.2.x accounts retain
-- their legacy verifier until the next successful login upgrades them.
function M.passwordVerifier(username,password,salt,rounds)
  rounds=math.max(1,math.min(4096,math.floor(tonumber(rounds)or 1)))
  local v=M.sha256('SpawnNet-PW\0'..tostring(username or'')..'\0'..tostring(password or'')..'\0'..tostring(salt or''))
  for i=2,rounds do v=M.sha256(v..'\0'..tostring(salt or'')..'\0'..tostring(i))end
  return v
end

local function xorBytes(data,keyStream)
  local out={}
  for i=1,#data do out[i]=string.char(bxor(data:byte(i),keyStream:byte(i)))end
  return table.concat(out)
end
local function stream(key,nonce,length)
  local out={};local have=0;local counter=1
  while have<length do
    local block=assert(M.fromHex(M.hmac(key,'block\0'..nonce..'\0'..tostring(counter))))
    out[#out+1]=block;have=have+#block;counter=counter+1
  end
  return table.concat(out):sub(1,length)
end
function M.seal(key,plain,aad)
  key=tostring(key or'');plain=tostring(plain or'');aad=tostring(aad or'')
  local nonce=M.randomHex(16);local enc=M.hmac(key,'enc');local mac=M.hmac(key,'mac')
  local cipher=xorBytes(plain,stream(enc,nonce,#plain));local hex=M.toHex(cipher)
  return{nonce=nonce,data=hex,tag=M.hmac(mac,aad..'\0'..nonce..'\0'..hex)}
end
function M.open(key,box,aad)
  if type(box)~='table'or type(box.nonce)~='string'or type(box.data)~='string'or type(box.tag)~='string'then return nil,'invalid secure envelope'end
  local mac=M.hmac(tostring(key or''),'mac');local expected=M.hmac(mac,tostring(aad or'')..'\0'..box.nonce..'\0'..box.data)
  if not M.constantTimeEq(expected,box.tag)then return nil,'secure envelope authentication failed'end
  local cipher,e=M.fromHex(box.data);if not cipher then return nil,e end
  return xorBytes(cipher,stream(M.hmac(tostring(key or''),'enc'),box.nonce,#cipher))
end
function M.sealTable(key,value,aad)
  local ok,raw=pcall(textutils.serialize,value or{});if not ok then return nil,'secure serialization failed'end
  return M.seal(key,raw,aad)
end
function M.openTable(key,box,aad)
  local raw,e=M.open(key,box,aad);if not raw then return nil,e end
  local ok,value=pcall(textutils.unserialize,raw);if not ok or type(value)~='table'then return nil,'secure payload decode failed'end
  return value
end
return M
]==],
  ["/spawnnet-node/node.lua"]=[==[local VERSION='2.3.0';local ROOT='/spawnnet-node';local cfgPath=ROOT..'/node.cfg'
local util=dofile(ROOT..'/util.lua');local wire=dofile(ROOT..'/wire.lua');local crypto=dofile(ROOT..'/crypto.lua')
local cfg=util.loadTable(cfgPath,nil);if type(cfg)~='table'then error('Missing '..cfgPath,0)end
local discovery='spawnnet:discovery:v2';local backbone='spawnnet:backbone:'..cfg.networkId..':v2';local fragments={};local boot=crypto.randomHex(8);local nodeSeq=0
local function save()util.saveTable(cfgPath,cfg)end
local function findModem()if cfg.modem and peripheral.isPresent(cfg.modem)and peripheral.getType(cfg.modem)=='modem'then return cfg.modem end;for _,n in ipairs(peripheral.getNames())do if peripheral.getType(n)=='modem'then return n end end end
local modem=findModem();if not modem then error('Storage Node requires a modem',0)end;if not rednet.isOpen(modem)then rednet.open(modem)end;cfg.modem=modem;save()
local function objectPath(id)local safe=tostring(id):gsub('[^%w%-_]','_');local dir=ROOT..'/objects/'..safe:sub(1,2);util.ensureDir(dir);return dir..'/'..safe..'.obj'end
local function stats()local free='?';local ok,v=pcall(fs.getFreeSpace,ROOT);if ok then free=v end;local cap=nil;if fs.getCapacity then local ok2,c=pcall(fs.getCapacity,ROOT);if ok2 then cap=c end end;local count=0;if fs.exists(ROOT..'/objects')then local function walk(p)for _,n in ipairs(fs.list(p))do local x=fs.combine(p,n);if fs.isDir(x)then walk(x)else count=count+1 end end end;walk(ROOT..'/objects')end;return free,cap,count end
local function signing(msg)return table.concat({tostring(msg.networkId or''),tostring(msg.type or''),tostring(msg.boot or''),tostring(msg.seq or''),tostring(msg.requestId or''),tostring(msg.op or''),tostring(msg.objectId or''),crypto.sha256(tostring(msg.data or'')),tostring(msg.free or''),tostring(msg.capacity or''),tostring(msg.objects or''),tostring(msg.packageHash or''),tostring(msg.ok),tostring(msg.error or'')},'|')end
local function sign(msg)msg.sig=crypto.hmac(cfg.token,signing(msg));return msg end
local function verify(msg)local sig=msg.sig;msg.sig=nil;local ok=crypto.constantTimeEq(sig,crypto.hmac(cfg.token,signing(msg)));msg.sig=sig;return ok end
local function discoverCore()
  local nonce=util.id('node-discover');rednet.broadcast({network='spawnnet',version=2,type='discover',nonce=nonce},discovery);local timer=os.startTimer(1.5)
  while true do local ev={os.pullEvent()};if ev[1]=='timer'and ev[2]==timer then return nil end;if ev[1]=='rednet_message'then local sender,msg,proto=ev[2],ev[3],ev[4];if proto==discovery and type(msg)=='table'and msg.type=='advertise'and msg.nonce==nonce and msg.networkId==cfg.networkId then
    if cfg.coreIdentity and msg.coreIdentity and cfg.coreIdentity~=msg.coreIdentity then cfg.identityConflict={expected=cfg.coreIdentity,received=msg.coreIdentity,computer=sender};save();return nil end
    cfg.coreId=sender;cfg.networkName=msg.name;cfg.coreIdentity=msg.coreIdentity or cfg.coreIdentity;save();return sender
  end end end
end
if not cfg.coreId then discoverCore()end
local function hello()
  if not cfg.coreId and not discoverCore()then return end;local free,cap,count=stats();local msg={network='spawnnet',version=2,type='node_hello',networkId=cfg.networkId,name=cfg.name,free=free,capacity=cap,objects=count,nodeVersion=VERSION}
  if cfg.pairKey then local nonce=crypto.randomHex(10);msg.pairId=cfg.pairKey:sub(1,12);msg.helloNonce=nonce;msg.proof=crypto.hmac(cfg.pairKey,table.concat({cfg.networkId,tostring(os.getComputerID()),nonce,msg.pairId},'|'))
  elseif cfg.token and cfg.pairCode then msg.pairCode=cfg.pairCode
  else cfg.pairCode=cfg.pairCode or crypto.randomHex(16);cfg.pairKey=crypto.sha256(cfg.pairCode);save();local nonce=crypto.randomHex(10);msg.pairId=cfg.pairKey:sub(1,12);msg.helloNonce=nonce;msg.proof=crypto.hmac(cfg.pairKey,table.concat({cfg.networkId,tostring(os.getComputerID()),nonce,msg.pairId},'|'))end
  rednet.send(cfg.coreId,msg,backbone)
end
local function heartbeat()
  if not cfg.coreId or not cfg.token then return end;nodeSeq=nodeSeq+1;local free,cap,count=stats();local msg={network='spawnnet',version=2,type='node_heartbeat',networkId=cfg.networkId,token=cfg.token,boot=boot,seq=nodeSeq,name=cfg.name,free=free,capacity=cap,objects=count,nodeVersion=VERSION};sign(msg);rednet.send(cfg.coreId,msg,backbone);util.writeFile(ROOT..'/runtime.heartbeat',tostring(os.clock()))
end
local function respond(to,req,ok,payload,err)local r={network='spawnnet',version=2,type='cluster_response',networkId=cfg.networkId,requestId=req.requestId,token=cfg.token,boot=req.boot,seq=req.seq,ok=ok~=false,error=err};for k,v in pairs(payload or{})do r[k]=v end;sign(r);wire.send(to,r,backbone)end
local function handle(sender,msg)
  if sender~=cfg.coreId or type(msg)~='table'or msg.networkId~=cfg.networkId or msg.token~=cfg.token or not verify(msg)then return end
  if cfg.lastCoreBoot~=msg.boot then cfg.lastCoreBoot=msg.boot;cfg.lastCoreSeq=0 end;if(tonumber(msg.seq)or 0)<=(cfg.lastCoreSeq or 0)then return end;cfg.lastCoreSeq=msg.seq;save()
  local op=msg.op;local id=tostring(msg.objectId or'');if id==''then respond(sender,msg,false,nil,'bad object id');return end;local path=objectPath(id)
  if op=='put'then local data=tostring(msg.data or'');if cfg.readOnly then respond(sender,msg,false,nil,'node is read-only');return end;if msg.dataHash and msg.dataHash~=crypto.sha256(data)then respond(sender,msg,false,nil,'payload hash mismatch');return end;local ok,e=pcall(util.writeFile,path,data);if not ok then respond(sender,msg,false,nil,tostring(e));return end;local free=stats();respond(sender,msg,true,{size=#data,free=free})
  elseif op=='get'then local data=util.readFile(path);if data==nil then respond(sender,msg,false,nil,'object missing')else respond(sender,msg,true,{data=data,size=#data,dataHash=crypto.sha256(data)})end
  elseif op=='delete'then if cfg.readOnly then respond(sender,msg,false,nil,'node is read-only');return end;if fs.exists(path)then fs.delete(path)end;respond(sender,msg,true,{ok=true})
  elseif op=='ping'then local free,cap,count=stats();respond(sender,msg,true,{free=free,capacity=cap,objects=count})else respond(sender,msg,false,nil,'unknown op')end
end
local function paint()
  term.setBackgroundColor(colors.black);term.clear();term.setCursorPos(1,1);term.setBackgroundColor(colors.purple);term.setTextColor(colors.white);term.clearLine();write(' SN// STORAGE VAULT 2.3.0 ');term.setBackgroundColor(colors.black);term.setCursorPos(2,3);term.setTextColor(colors.cyan);print('NODE '..tostring(cfg.name or('#'..os.getComputerID())));term.setTextColor(colors.lightGray);print('Network     '..tostring(cfg.networkName or cfg.networkId));print('Core        #'..tostring(cfg.coreId or'SEARCHING'));print('Identity    '..tostring(cfg.coreIdentity or'UNPINNED'):sub(1,16));print('Mode        '..(cfg.readOnly and'READ ONLY'or'REPLICATING'));term.setTextColor(cfg.token and colors.lime or colors.orange);print();print(cfg.token and'[+] SECURE LINK ONLINE'or'[ ] WAITING FOR CORE APPROVAL');if not cfg.token then term.setTextColor(colors.white);print();print('PAIR CODE (enter on Core)');term.setTextColor(colors.yellow);print(tostring(cfg.pairCode or''))end;term.setCursorPos(1,select(2,term.getSize()));term.setBackgroundColor(colors.gray);term.setTextColor(colors.white);term.clearLine();write(' Ctrl+T stop   spawnnet-node update ')
end
paint();hello();local timer=os.startTimer(cfg.token and 10 or 4)
while true do local ev={os.pullEvent()};if ev[1]=='timer'and ev[2]==timer then if cfg.token then heartbeat()else hello();paint()end;timer=os.startTimer(cfg.token and 10 or 4)
elseif ev[1]=='rednet_message'then local sender,msg,proto=ev[2],ev[3],ev[4];if proto==backbone then
  if type(msg)=='table'and msg.type=='node_approved'and sender==cfg.coreId and msg.networkId==cfg.networkId then cfg.pairKey=cfg.pairKey or(cfg.pairCode and crypto.sha256(cfg.pairCode));local token,e=crypto.open(cfg.pairKey,msg.tokenBox,cfg.networkId..'|'..tostring(os.getComputerID()));if token then cfg.token=token;cfg.name=msg.name or cfg.name;cfg.coreIdentity=msg.coreIdentity or cfg.coreIdentity;cfg.pairCode=nil;save();paint();heartbeat()else printError('Approval authentication failed: '..tostring(e))end
  elseif cfg.token then local complete=wire.accept(sender,msg,fragments);wire.purge(fragments);if complete then handle(sender,complete)end end
end end end
]==],
  ["/spawnnet-node/startup.lua"]=[==[-- Dedicated Storage Node watchdog. A crash restarts the node without creating
-- nested CraftOS shells or rerunning /startup.lua.
while true do
  local ok,err=pcall(function()if not os.run({},'/spawnnet-node/node.lua')then error('node process exited with failure',0)end end)
  if not ok then local h=fs.open('/spawnnet-node/crash.log','a');if h then h.writeLine(tostring(os.clock())..' '..tostring(err));h.close()end end
  term.setBackgroundColor(colors.black);term.setTextColor(colors.orange);term.clear();term.setCursorPos(2,3);print('SN// STORAGE VAULT RESTARTING');print(tostring(err or'process exited'));sleep(3)
end
]==],
  ["/spawnnet-node/updater.lua"]=[==[-- SpawnNet Storage Node updater 2.3.0
local ROOT='/spawnnet-node'
local util=dofile(ROOT..'/util.lua')
local wire=dofile(ROOT..'/wire.lua')
local crypto=dofile(ROOT..'/crypto.lua')
local cfg=util.loadTable(ROOT..'/node.cfg',nil)
if type(cfg)~='table'or not cfg.token then error('Node must be paired before it can update',0)end
local mode=(...)or'update'
local LAST=ROOT..'/last-update.db'
local modem=cfg.modem
if not(modem and peripheral.isPresent(modem)and peripheral.getType(modem)=='modem')then
  for _,n in ipairs(peripheral.getNames())do if peripheral.getType(n)=='modem'then modem=n;break end end
end
if not modem then error('No modem',0)end
if not rednet.isOpen(modem)then rednet.open(modem)end
local proto='spawnnet:backbone:'..cfg.networkId..':v2'
local frags={}
local boot=crypto.randomHex(8);local seq=0
local function signing(msg)return table.concat({tostring(msg.networkId or''),tostring(msg.type or''),tostring(msg.boot or''),tostring(msg.seq or''),tostring(msg.requestId or''),tostring(msg.op or''),tostring(msg.objectId or''),crypto.sha256(tostring(msg.data or'')),tostring(msg.free or''),tostring(msg.capacity or''),tostring(msg.objects or''),tostring(msg.packageHash or''),tostring(msg.ok),tostring(msg.error or'')},'|')end
local function sign(msg)msg.sig=crypto.hmac(cfg.token,signing(msg));return msg end
local function verify(msg)local sig=msg.sig;msg.sig=nil;local ok=crypto.constantTimeEq(sig,crypto.hmac(cfg.token,signing(msg)));msg.sig=sig;return ok end

local function request(kind)
  local id=util.id('node-update')
  seq=seq+1;local outbound={network='spawnnet',version=2,type=kind,networkId=cfg.networkId,token=cfg.token,requestId=id,boot=boot,seq=seq};sign(outbound)
  local ok,e=wire.send(cfg.coreId,outbound,proto)
  if not ok then return nil,e end
  local timer=os.startTimer(7)
  while true do
    local ev={os.pullEvent()}
    if ev[1]=='timer'and ev[2]==timer then return nil,'Core update request timed out'end
    if ev[1]=='rednet_message'and ev[2]==cfg.coreId and ev[4]==proto then
      local body=wire.accept(ev[2],ev[3],frags);wire.purge(frags)
      if type(body)=='table'and body.type=='node_update_response'and body.requestId==id and body.token==cfg.token and body.seq==seq and verify(body)then
        if body.ok==false then return nil,body.error or'update unavailable'end
        return body.package
      end
    end
  end
end

local function clean(p)
  p=tostring(p or''):gsub('\\','/'):gsub('^/+','')
  if p==''then return nil end
  for x in p:gmatch('[^/]+')do if x=='.'or x=='..'then return nil end end
  return p
end
local function allowed(p)
  return p:sub(1,14)=='spawnnet-node/'or p=='spawnnet-node.lua'
end
local function systemHash(pkg)
  local paths={};for p in pairs(pkg.files or{})do paths[#paths+1]=p end;table.sort(paths)
  local parts={tostring(pkg.name or''),tostring(pkg.version or''),tostring(pkg.component or''),tostring(pkg.channel or''),tostring(pkg.restartRequired and true or false)}
  for _,p in ipairs(paths)do parts[#parts+1]='file:'..p..':'..crypto.sha256(tostring(pkg.files[p]or''))end
  local managed={};for _,p in ipairs(pkg.managedFiles or{})do managed[#managed+1]=p end;table.sort(managed);for _,p in ipairs(managed)do parts[#parts+1]='managed:'..p end
  return crypto.sha256(table.concat(parts,'\0'))
end
local function restore(info)
  if type(info)~='table'or not info.backup then return nil,'No node rollback is available'end
  for _,r in ipairs(info.files or{})do
    local target='/'..r.path
    local src=info.backup..'/'..r.path
    if r.existed then
      if not fs.exists(src)then return nil,'Backup file missing: '..r.path end
      util.writeFile(target,util.readFile(src)or'')
    elseif fs.exists(target)then
      fs.delete(target)
    end
  end
  if info.previousVersion then util.writeFile(ROOT..'/version.txt',tostring(info.previousVersion)..'\n')end
  return true
end

if mode=='rollback'then
  local info=util.loadTable(LAST,nil)
  local ok,e=restore(info)
  if not ok then error(e,0)end
  term.setTextColor(colors.lime);print('NODE ROLLED BACK');term.setTextColor(colors.white)
  print('Restart spawnnet-node.')
  return
end

local man,e=request('node_update_manifest')
if not man then printError(e);return end
local localv=(util.readFile(ROOT..'/version.txt')or'2.3.0'):gsub('%s+$','')
print('SpawnNet Node update')
print('Installed: '..localv)
print('Available: '..tostring(man.version))
if mode=='check'then return end
if localv==tostring(man.version)then print('Already current.');return end
write('Update now? Y/n: ')
local a=read():lower();if a=='n'or a=='no'then return end

local pkg,ge=request('node_update_get')
if not pkg then printError(ge);return end
if not pkg.hash or systemHash(pkg)~=tostring(pkg.hash)then error('Node release integrity check failed',0)end

local files={}
for p,data in pairs(pkg.files or{})do
  local cp=clean(p)
  if not cp or not allowed(cp)or cp=='spawnnet-node/node.cfg'or cp:sub(1,22)=='spawnnet-node/objects/'then
    error('Unsafe node update target: '..tostring(p),0)
  end
  data=tostring(data or'')
  if cp:sub(-4)=='.lua'then
    local f,se=loadstring(data,'@/'..cp)
    if not f then error('Node update syntax error in '..cp..': '..tostring(se),0)end
  end
  files[#files+1]={path=cp,data=data}
end
if #files==0 then error('Node release contains no files',0)end

local ver=tostring(pkg.version or'update'):gsub('[^%w%.%-_]','_')
local backup=ROOT..'/backups/'..ver
util.ensureDir(backup)
local records={}
for _,f in ipairs(files)do
  local target='/'..f.path
  local existed=fs.exists(target)
  records[#records+1]={path=f.path,existed=existed}
  if existed then
    local dest=backup..'/'..f.path
    util.ensureDir(fs.getDir(dest))
    if fs.exists(dest)then fs.delete(dest)end
    fs.copy(target,dest)
  end
end

local info={backup=backup,files=records,previousVersion=localv,version=pkg.version}
local ok,err=pcall(function()
  for _,f in ipairs(files)do util.writeFile('/'..f.path,f.data)end
  util.writeFile(ROOT..'/version.txt',tostring(pkg.version)..'\n')
  util.saveTable(LAST,info)
end)
if not ok then
  pcall(restore,info)
  error('Node update failed and was rolled back: '..tostring(err),0)
end
term.setTextColor(colors.lime);print('NODE UPDATED -> '..tostring(pkg.version));term.setTextColor(colors.white)
print('Restart spawnnet-node.')
]==],
  ["/spawnnet-node/util.lua"]=[==[local M={}
function M.trim(s)return(tostring(s or''):gsub('^%s+',''):gsub('%s+$',''))end
function M.safeName(s,n)s=M.trim(s):lower():gsub('[^a-z0-9_-]','-'):gsub('%-+','-'):gsub('^[-_]',''):gsub('[-_]$','');if n then s=s:sub(1,n)end;return s end
function M.ensureDir(p)if p and p~=''and not fs.exists(p)then local q=fs.getDir(p);if q and q~=''then M.ensureDir(q)end;fs.makeDir(p)end end
function M.readFile(p)if not fs.exists(p)then return nil end;local h=fs.open(p,'r');if not h then return nil end;local s=h.readAll();h.close();return s end
function M.writeFile(p,d)d=tostring(d or'');M.ensureDir(fs.getDir(p));local t=p..'.tmp';if fs.exists(t)then fs.delete(t)end;local h=assert(fs.open(t,'w'));h.write(d);h.close();if fs.exists(p)then fs.delete(p)end;fs.move(t,p)end
function M.loadTable(p,default)local s=M.readFile(p);if not s then return default or{}end;local ok,v=pcall(textutils.unserialize,s);if ok and type(v)=='table'then return v end;return default or{}end
function M.saveTable(p,t)M.writeFile(p,textutils.serialize(t))end
function M.now()if os.epoch then return math.floor(os.epoch('utc')/1000)end;return math.floor((os.time and os.time()or 0)*3600+(os.clock and os.clock()or 0))end
function M.id(prefix)local cid=os.getComputerID and os.getComputerID()or 0;local r=math.random(0,0x3fffffff)*2+math.random(0,1);return string.format('%s-%x-%x-%x',prefix or'id',cid,M.now()%0xffffffff,r)end
return M
]==],
  ["/spawnnet-node/wire.lua"]=[==[local util=dofile('/spawnnet-node/util.lua');local M={};local MAX=262144;local FRAG=6000;local TIMEOUT=15
function M.send(recipient,message,protocol)local ok,raw=pcall(textutils.serialize,message);if not ok then return false,'serialize failed'end;if #raw>MAX then return false,'logical packet too large'end;if #raw<=FRAG then return rednet.send(recipient,message,protocol)end;local id=util.id('frag');local total=math.ceil(#raw/FRAG);for i=1,total do local chunk=raw:sub((i-1)*FRAG+1,i*FRAG);local env={network='spawnnet',version=2,type='fragment',fragmentId=id,index=i,total=total,data=chunk};local sent=rednet.send(recipient,env,protocol);if not sent then return false,'rednet send failed'end end;return true end
function M.accept(sender,msg,buckets)if type(msg)~='table'or msg.network~='spawnnet'or msg.type~='fragment'then return msg end;if type(msg.fragmentId)~='string'or type(msg.index)~='number'or type(msg.total)~='number'or type(msg.data)~='string'then return nil,nil,'malformed fragment'end;if msg.total<1 or msg.total>math.ceil(MAX/FRAG)+2 or msg.index<1 or msg.index>msg.total then return nil,nil,'bad fragment range'end;local key=tostring(sender)..':'..msg.fragmentId;local b=buckets[key];if not b then b={created=os.clock(),total=msg.total,parts={},count=0,bytes=0};buckets[key]=b end;if b.total~=msg.total then buckets[key]=nil;return nil,nil,'fragment total mismatch'end;if not b.parts[msg.index]then b.parts[msg.index]=msg.data;b.count=b.count+1;b.bytes=b.bytes+#msg.data end;if b.bytes>MAX then buckets[key]=nil;return nil,nil,'fragment payload too large'end;if b.count==b.total then local chunks={};for i=1,b.total do if not b.parts[i]then return nil end;chunks[i]=b.parts[i]end;buckets[key]=nil;local raw=table.concat(chunks);local ok,obj=pcall(textutils.unserialize,raw);if not ok or type(obj)~='table'then return nil,nil,'fragment decode failed'end;return obj,true end;return nil,false end
function M.purge(b)local now=os.clock();for k,v in pairs(b)do if now-(v.created or now)>TIMEOUT then b[k]=nil end end end
return M
]==],
}

local VERSION='2.3.0'
local function ensure(p)if p==''or p=='/'or fs.exists(p)then return end;local q=fs.getDir(p);if q and q~=''then ensure(q)end;fs.makeDir(p)end
local function writeFile(p,d)ensure(fs.getDir(p));local t=p..'.install-tmp';if fs.exists(t)then fs.delete(t)end;local h=assert(fs.open(t,'w'));h.write(d);h.close();if fs.exists(p)then fs.delete(p)end;fs.move(t,p)end
local function validate(map,label)local n=0;for p,d in pairs(map)do if p:sub(-4)=='.lua'then local f,e=loadstring(d,'@'..p);if not f then error('REFUSING INSTALL: '..label..' '..p..': '..tostring(e),0)end;n=n+1 end end;return n end
local function count(t)local n=0;for _ in pairs(t or{})do n=n+1 end;return n end
local function install(map,component)
  local stamp=tostring(os.getComputerID())..'-'..tostring(math.floor((os.epoch and os.epoch('utc')or os.clock()*1000)))
  local backup='/spawnnet/backups/install-'..component..'-'..stamp;local records={}
  for p in pairs(map)do local existed=fs.exists(p);records[#records+1]={path=p,existed=existed};if existed then local dest=backup..p;ensure(fs.getDir(dest));fs.copy(p,dest)end end
  local ok,e=pcall(function()for p,d in pairs(map)do writeFile(p,d)end end)
  if not ok then for _,r in ipairs(records)do if r.existed then writeFile(r.path,(function()local h=assert(fs.open(backup..r.path,'r'));local x=h.readAll();h.close();return x end)())elseif fs.exists(r.path)then fs.delete(r.path)end end;error('Install failed and code was restored: '..tostring(e),0)end
  return backup
end
local function startup(target,line,marker)
  local old='';if fs.exists(target)then local h=fs.open(target,'r');old=h and h.readAll()or'';if h then h.close()end end
  if old~=''and not old:find('SPAWNNET_',1,true)and not fs.exists('/startup.pre-spawnnet.lua')then fs.copy(target,'/startup.pre-spawnnet.lua')end
  writeFile(target,'-- '..marker..'\n'..line..'\n')
end

term.setBackgroundColor(colors.black);term.clear();term.setCursorPos(1,1);term.setBackgroundColor(colors.purple);term.setTextColor(colors.white);term.clearLine();print(' SN// STORAGE VAULT INSTALLER 2.3.0 ');term.setBackgroundColor(colors.black);term.setTextColor(colors.white)
local upgrading=fs.exists('/spawnnet-node/node.lua');print(upgrading and'IN-PLACE UPGRADE // OBJECTS + IDENTITY PRESERVED'or'FRESH VAULT // PREPARING PAIRING');print('Validated '..validate(files,'Node')..' embedded Lua programs.');local backup=install(files,'node')
local util=dofile('/spawnnet-node/util.lua');local cfg=util.loadTable('/spawnnet-node/node.cfg',{});if not upgrading then write('Network ID [public]: ');local n=read();cfg.networkId=n~=''and n or'public';write('Node name [Storage #'..os.getComputerID()..']: ');local name=read();cfg.name=name~=''and name or('Storage #'..os.getComputerID());local modem=nil;for _,p in ipairs(peripheral.getNames())do if peripheral.getType(p)=='modem'then modem=p;break end end;write('Modem ['..tostring(modem or'')..']: ');local m=read();cfg.modem=m~=''and m or modem;if not cfg.modem then error('A modem is required',0)end end
cfg.networkId=cfg.networkId or'public';cfg.name=cfg.name or('Storage #'..os.getComputerID());util.saveTable('/spawnnet-node/node.cfg',cfg);writeFile('/spawnnet-node/version.txt',VERSION..'\n');startup('/startup.lua',"shell.run('/spawnnet-node/startup.lua')",'SPAWNNET_NODE_STARTUP_2.3.0')
print();term.setTextColor(colors.lime);print('STORAGE VAULT ARMED // '..VERSION);term.setTextColor(colors.lightGray);print('Objects, pairing token and Core identity preserved.');print('Auto-restart watchdog installed. Backup: '..backup);print('Run now: spawnnet-node');if not cfg.token then print('Then enter the displayed pair code in SpawnNet Admin.')end
