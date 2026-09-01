-- SpawnNet 2.0.0 Storage Node Installer
local files={
  ["/spawnnet-node/node.lua"]=[=[local ROOT='/spawnnet-node'
local cfgPath=ROOT..'/node.cfg'
local util=dofile(ROOT..'/util.lua')
local wire=dofile(ROOT..'/wire.lua')
local cfg=util.loadTable(cfgPath,nil)
if type(cfg)~='table'then error('Missing '..cfgPath)end
local discovery='spawnnet:discovery:v2'
local backbone='spawnnet:backbone:'..cfg.networkId..':v2'
local fragments={}
local function findModem()
 if cfg.modem and peripheral.isPresent(cfg.modem)and peripheral.getType(cfg.modem)=='modem'then return cfg.modem end
 for _,n in ipairs(peripheral.getNames())do if peripheral.getType(n)=='modem'then return n end end
end
local modem=findModem();if not modem then error('Storage node requires a modem')end;if not rednet.isOpen(modem)then rednet.open(modem)end;cfg.modem=modem;util.saveTable(cfgPath,cfg)
local function objectPath(id)local safe=tostring(id):gsub('[^%w%-_]','_');local dir=ROOT..'/objects/'..safe:sub(1,2);util.ensureDir(dir);return dir..'/'..safe..'.obj'end
local function stats()
 local free='?';local ok,v=pcall(fs.getFreeSpace,ROOT);if ok then free=v end
 local cap=nil;if fs.getCapacity then local ok2,c=pcall(fs.getCapacity,ROOT);if ok2 then cap=c end end
 local count=0;if fs.exists(ROOT..'/objects')then local function walk(p)for _,n in ipairs(fs.list(p))do local x=fs.combine(p,n);if fs.isDir(x)then walk(x)else count=count+1 end end end;walk(ROOT..'/objects')end
 return free,cap,count
end
local function discoverCore()
 local nonce=util.id('node-discover');rednet.broadcast({network='spawnnet',version=2,type='discover',nonce=nonce},discovery);local timer=os.startTimer(1.5)
 while true do local ev={os.pullEvent()};if ev[1]=='timer'and ev[2]==timer then return nil end;if ev[1]=='rednet_message'then local sender,msg,proto=ev[2],ev[3],ev[4];if proto==discovery and type(msg)=='table'and msg.type=='advertise'and msg.nonce==nonce and msg.networkId==cfg.networkId then cfg.coreId=sender;cfg.networkName=msg.name;util.saveTable(cfgPath,cfg);return sender end end end
end
if not cfg.coreId then discoverCore()end
local function hello()
 if not cfg.coreId then if not discoverCore()then return end end
 local free,cap,count=stats();rednet.send(cfg.coreId,{network='spawnnet',version=2,type='node_hello',networkId=cfg.networkId,pairCode=cfg.pairCode,name=cfg.name,free=free,capacity=cap,objects=count},backbone)
end
local function heartbeat()
 if not cfg.coreId or not cfg.token then return end;local free,cap,count=stats();rednet.send(cfg.coreId,{network='spawnnet',version=2,type='node_heartbeat',networkId=cfg.networkId,token=cfg.token,name=cfg.name,free=free,capacity=cap,objects=count},backbone)
end
local function respond(to,req,ok,payload,err)
 local r={network='spawnnet',version=2,type='cluster_response',networkId=cfg.networkId,requestId=req.requestId,ok=ok~=false,error=err};for k,v in pairs(payload or{})do r[k]=v end;wire.send(to,r,backbone)
end
local function handle(sender,msg)
 if sender~=cfg.coreId or type(msg)~='table'or msg.networkId~=cfg.networkId or msg.token~=cfg.token then return end
 local op=msg.op;local id=tostring(msg.objectId or'');if id==''then respond(sender,msg,false,nil,'bad object id');return end;local path=objectPath(id)
 if op=='put'then local data=tostring(msg.data or'');local ok,e=pcall(util.writeFile,path,data);if not ok then respond(sender,msg,false,nil,tostring(e));return end;local free=stats();respond(sender,msg,true,{size=#data,free=free})
 elseif op=='get'then local data=util.readFile(path);if data==nil then respond(sender,msg,false,nil,'object missing')else respond(sender,msg,true,{data=data,size=#data})end
 elseif op=='delete'then if fs.exists(path)then fs.delete(path)end;respond(sender,msg,true,{ok=true})
 elseif op=='ping'then local free,cap,count=stats();respond(sender,msg,true,{free=free,capacity=cap,objects=count})
 else respond(sender,msg,false,nil,'unknown op')end
end
term.clear();term.setCursorPos(1,1);print('SpawnNet Storage Node 2.0.0');print('Network: '..tostring(cfg.networkName or cfg.networkId)..' ['..cfg.networkId..']');print('Node: #'..os.getComputerID()..' '..tostring(cfg.name));print('Pair code: '..tostring(cfg.pairCode));print(cfg.token and'PAIRED / ONLINE'or'WAITING FOR ADMIN APPROVAL');print();print('Keep this computer loaded. Ctrl+T stops node.')
hello();local timer=os.startTimer(cfg.token and 10 or 4)
while true do local ev={os.pullEvent()};if ev[1]=='timer'and ev[2]==timer then if cfg.token then heartbeat()else hello()end;timer=os.startTimer(cfg.token and 10 or 4)
 elseif ev[1]=='rednet_message'then local sender,msg,proto=ev[2],ev[3],ev[4];if proto==backbone then
   if type(msg)=='table'and msg.type=='node_approved'and sender==cfg.coreId and msg.networkId==cfg.networkId then cfg.token=msg.token;cfg.name=msg.name or cfg.name;util.saveTable(cfgPath,cfg);print('APPROVED! Node is now active.');heartbeat()
   elseif cfg.token then local complete=wire.accept(sender,msg,fragments);wire.purge(fragments);if complete then handle(sender,complete)end end
 end end end
]=],
  ["/spawnnet-node/util.lua"]=[=[local M = {}

function M.trim(s)
  return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

function M.startsWith(s, prefix)
  return tostring(s):sub(1, #prefix) == prefix
end

function M.endsWith(s, suffix)
  s, suffix = tostring(s), tostring(suffix)
  return suffix == "" or s:sub(-#suffix) == suffix
end

function M.split(s, sep, plain)
  local out = {}
  s = tostring(s or "")
  sep = sep or "%s+"
  if sep == "" then
    for i = 1, #s do out[#out+1] = s:sub(i,i) end
    return out
  end
  if plain then
    local pos = 1
    while true do
      local a,b = s:find(sep, pos, true)
      if not a then out[#out+1] = s:sub(pos); break end
      out[#out+1] = s:sub(pos,a-1)
      pos = b+1
    end
  else
    for part in s:gmatch("[^" .. sep .. "]+") do out[#out+1] = part end
  end
  return out
end

function M.deepcopy(v, seen)
  if type(v) ~= "table" then return v end
  seen = seen or {}
  if seen[v] then return seen[v] end
  local c = {}
  seen[v] = c
  for k,val in pairs(v) do c[M.deepcopy(k,seen)] = M.deepcopy(val,seen) end
  return c
end

function M.shallowcopy(v)
  local c = {}
  for k,val in pairs(v or {}) do c[k]=val end
  return c
end

function M.keys(t)
  local out={}
  for k in pairs(t or {}) do out[#out+1]=k end
  table.sort(out, function(a,b) return tostring(a)<tostring(b) end)
  return out
end

function M.count(t)
  local n=0; for _ in pairs(t or {}) do n=n+1 end; return n
end

function M.clamp(v,a,b)
  v=tonumber(v) or 0
  if v<a then return a elseif v>b then return b else return v end
end

function M.now()
  if os.epoch then return math.floor(os.epoch("utc")/1000) end
  return math.floor((os.time and os.time() or 0)*3600 + (os.clock and os.clock() or 0))
end

function M.id(prefix)
  prefix = prefix or "id"
  local cid = os.getComputerID and os.getComputerID() or 0
  local t = M.now()
  -- LuaJ/old CC cannot safely do math.random(0, 0x7fffffff):
  -- the internal Java bound overflows. Build 31 random bits safely.
  local r = math.random(0, 0x3fffffff) * 2 + math.random(0, 1)
  return string.format("%s-%x-%x-%x", prefix, cid, t % 0xffffffff, r)
end

function M.safeName(s, maxLen)
  s = M.trim(s):lower():gsub("[^a-z0-9_-]", "-"):gsub("%-+","-")
  s = s:gsub("^[-_]",""):gsub("[-_]$","")
  if maxLen then s=s:sub(1,maxLen) end
  return s
end

function M.ensureDir(path)
  if not fs.exists(path) then fs.makeDir(path) end
end

function M.readFile(path)
  if not fs.exists(path) then return nil end
  local h=fs.open(path,"r"); if not h then return nil end
  local s=h.readAll(); h.close(); return s
end

function M.writeFile(path, data)
  data=tostring(data or "")
  local dir=fs.getDir(path)
  if dir and dir~="" then M.ensureDir(dir) end

  local old=fs.exists(path) and fs.getSize(path) or 0
  local okFree,free=pcall(fs.getFreeSpace,path)
  if not okFree then free=nil end

  -- Prefer an atomic temp-file replacement when there is room.
  local canTemp = free=="unlimited" or free==nil or
    (type(free)=="number" and free>=#data+1024)

  if canTemp then
    local tmp=path..".tmp"
    if fs.exists(tmp) then fs.delete(tmp) end
    local h=assert(fs.open(tmp,"w"))
    h.write(data)
    h.close()
    if fs.exists(path) then fs.delete(path) end
    fs.move(tmp,path)
    return
  end

  -- Low-space fallback: the new serialized value already exists in memory.
  -- Only replace in-place if deleting the old file makes enough room.
  if type(free)=="number" and free+old<#data+1024 then
    error("Not enough disk space to save "..path..
      " need="..tostring(#data).." free="..tostring(free)..
      " reclaimable="..tostring(old))
  end

  if fs.exists(path) then fs.delete(path) end
  local h=assert(fs.open(path,"w"))
  h.write(data)
  h.close()
end

function M.writeIfChanged(path,data)
  data=tostring(data or "")
  local old=M.readFile(path)
  if old==data then return false end
  M.writeFile(path,data)
  return true
end

function M.loadTable(path, default)
  local s=M.readFile(path); if not s then return M.deepcopy(default or {}) end
  local ok,val=pcall(textutils.unserialize,s)
  if ok and type(val)=="table" then return val end
  return M.deepcopy(default or {})
end

function M.saveTable(path,t)
  M.writeFile(path,textutils.serialize(t))
end

local function canonicalValue(v, seen)
  local tv=type(v)
  if tv=="nil" then return "n;" end
  if tv=="boolean" then return v and "b1;" or "b0;" end
  if tv=="number" then return "d"..string.format("%.17g",v)..";" end
  if tv=="string" then return "s"..#v..":"..v..";" end
  if tv~="table" then return "x"..tv..":"..tostring(v)..";" end
  seen=seen or {}
  if seen[v] then error("recursive table") end
  seen[v]=true
  local ks={}
  for k in pairs(v) do ks[#ks+1]=k end
  table.sort(ks,function(a,b) return canonicalValue(a,{}) < canonicalValue(b,{}) end)
  local out={"{"}
  for _,k in ipairs(ks) do
    out[#out+1]=canonicalValue(k,{})
    out[#out+1]=canonicalValue(v[k],seen)
  end
  out[#out+1]="}"
  seen[v]=nil
  return table.concat(out)
end
M.canonical = canonicalValue

function M.wrapText(text,width)
  width=math.max(1,tonumber(width) or 1)
  local lines={}
  for raw in (tostring(text or "").."\n"):gmatch("(.-)\n") do
    if raw=="" then lines[#lines+1]="" else
      local line=""
      for word in raw:gmatch("%S+") do
        if #word>width then
          if line~="" then lines[#lines+1]=line; line="" end
          while #word>width do lines[#lines+1]=word:sub(1,width); word=word:sub(width+1) end
          line=word
        elseif line=="" then line=word
        elseif #line+1+#word<=width then line=line.." "..word
        else lines[#lines+1]=line; line=word end
      end
      lines[#lines+1]=line
    end
  end
  if #lines>0 and lines[#lines]=="" and tostring(text or ""):sub(-1)~="\n" then table.remove(lines) end
  return lines
end

function M.containsInsensitive(haystack, needle)
  return tostring(haystack or ""):lower():find(tostring(needle or ""):lower(),1,true) ~= nil
end

function M.tablePathGet(root,path,default)
  local cur=root
  for part in tostring(path or ""):gmatch("[^%.]+") do
    if type(cur)~="table" then return default end
    cur=cur[part]
    if cur==nil then return default end
  end
  return cur
end

function M.tablePathSet(root,path,value)
  local parts={}; for p in tostring(path or ""):gmatch("[^%.]+") do parts[#parts+1]=p end
  local cur=root
  for i=1,#parts-1 do local p=parts[i]; if type(cur[p])~="table" then cur[p]={} end; cur=cur[p] end
  if #parts>0 then cur[parts[#parts]]=value end
end

function M.limitArray(arr,max)
  while #arr>max do table.remove(arr,1) end
  return arr
end

return M
]=],
  ["/spawnnet-node/wire.lua"]=[=[local util=dofile('/spawnnet-node/util.lua')
local M={};local MAX=262144;local FRAG=6000;local TIMEOUT=15
function M.send(recipient,message,protocol)
 local ok,raw=pcall(textutils.serialize,message);if not ok then return false,'serialize failed'end;if #raw>MAX then return false,'logical packet too large'end
 if #raw<=FRAG then return rednet.send(recipient,message,protocol)end
 local id=util.id('frag');local total=math.ceil(#raw/FRAG);for i=1,total do local chunk=raw:sub((i-1)*FRAG+1,i*FRAG);local env={network='spawnnet',version=2,type='fragment',fragmentId=id,index=i,total=total,data=chunk};local sent=rednet.send(recipient,env,protocol);if not sent then return false,'rednet send failed'end end;return true
end
function M.accept(sender,msg,buckets)
 if type(msg)~='table'or msg.network~='spawnnet'or msg.type~='fragment'then return msg end
 if type(msg.fragmentId)~='string'or type(msg.index)~='number'or type(msg.total)~='number'or type(msg.data)~='string'then return nil,nil,'malformed fragment'end
 if msg.total<1 or msg.total>math.ceil(MAX/FRAG)+2 or msg.index<1 or msg.index>msg.total then return nil,nil,'bad fragment range'end
 local key=tostring(sender)..':'..msg.fragmentId;local b=buckets[key];if not b then b={created=os.clock(),total=msg.total,parts={},count=0,bytes=0};buckets[key]=b end
 if b.total~=msg.total then buckets[key]=nil;return nil,nil,'fragment total mismatch'end;if not b.parts[msg.index]then b.parts[msg.index]=msg.data;b.count=b.count+1;b.bytes=b.bytes+#msg.data end;if b.bytes>MAX then buckets[key]=nil;return nil,nil,'fragment payload too large'end
 if b.count==b.total then local chunks={};for i=1,b.total do if not b.parts[i]then return nil end;chunks[i]=b.parts[i]end;buckets[key]=nil;local raw=table.concat(chunks);local ok,obj=pcall(textutils.unserialize,raw);if not ok or type(obj)~='table'then return nil,nil,'fragment decode failed'end;return obj,true end;return nil,false
end
function M.purge(buckets)local now=os.clock();for k,b in pairs(buckets)do if now-(b.created or now)>TIMEOUT then buckets[k]=nil end end end
return M
]=],
}
local function ensure(path)
  if path=='' or path=='/' then return end
  if fs.exists(path) then return end
  local parent=fs.getDir(path); if parent and parent~='' then ensure(parent) end
  fs.makeDir(path)
end
local function writeFile(path,data)
  ensure(fs.getDir(path)); if fs.exists(path) then fs.delete(path) end
  local h=assert(fs.open(path,'w'));h.write(data);h.close()
end
local function cleanup(paths) for _,p in ipairs(paths or {})do if fs.exists(p)then pcall(fs.delete,p)end end end
local running=(shell and shell.getRunningProgram and shell.getRunningProgram())or nil

for path,data in pairs(files)do writeFile(path,data)end
local util=dofile('/spawnnet-node/util.lua')
term.clear();term.setCursorPos(1,1);print('SpawnNet Storage Node Installer 2.0.0');print('Adds this always-loaded computer to a SpawnNet storage cluster.');print()
print('Available modems:');local mods={};for _,n in ipairs(peripheral.getNames())do if peripheral.getType(n)=='modem'then mods[#mods+1]=n;print('  '..n)end end;local default=mods[1]or'';write('Modem ['..default..']: ');local modem=read();if modem==''then modem=default end;if modem==''then error('A modem is required')end;if not rednet.isOpen(modem)then rednet.open(modem)end
local discovery='spawnnet:discovery:v2';local nonce=util.id('discover');rednet.broadcast({network='spawnnet',version=2,type='discover',nonce=nonce},discovery);local timer=os.startTimer(1.5);local found={}
while true do local ev={os.pullEvent()};if ev[1]=='timer'and ev[2]==timer then break end;if ev[1]=='rednet_message'then local sender,msg,proto=ev[2],ev[3],ev[4];if proto==discovery and type(msg)=='table'and msg.type=='advertise'and msg.nonce==nonce then found[msg.networkId]={id=msg.networkId,name=msg.name,coreId=sender,visibility=msg.visibility};print('Found: '..msg.networkId..' - '..msg.name..' core #'..sender)end end end
local defaultId='public';for id in pairs(found)do defaultId=id break end;write('Network ID ['..defaultId..']: ');local nid=util.safeName(read(),32);if nid==''then nid=defaultId end;local f=found[nid];local coreId=f and f.coreId or nil;if not coreId then write('Core computer ID: ');coreId=tonumber(read())end;if not coreId then error('Core ID required')end
local defaultName='Storage #'..os.getComputerID();write('Node name ['..defaultName..']: ');local name=read();if name==''then name=defaultName end;local pair=tostring(math.random(100000,999999));util.saveTable('/spawnnet-node/node.cfg',{networkId=nid,networkName=f and f.name or nid,coreId=coreId,name=name,modem=modem,pairCode=pair,token=nil})
writeFile('/spawnnet-node.lua',"shell.run('/spawnnet-node/node.lua')\n")
print();print('Node installed.');print('Network: '..nid);print('Core: #'..coreId);print('PAIR CODE: '..pair);print();print('On an ADMIN SpawnNet client:');print('  spawnnet nodes');print('Approve computer #'..os.getComputerID()..' with pair code '..pair);print();write('Install node as /startup.lua? y/N: ');if read():lower()=='y'then if fs.exists('/startup.lua')then if fs.exists('/startup.pre-spawnnet-node.lua')then fs.delete('/startup.pre-spawnnet-node.lua')end;fs.copy('/startup.lua','/startup.pre-spawnnet-node.lua')end;writeFile('/startup.lua',"shell.run('/spawnnet-node/node.lua')\n")end;print('Run now: spawnnet-node')
if running and fs.exists(running)then write('Delete this installer to reclaim disk space? Y/n: ');local ans=read():lower();if ans~='n'and ans~='no'then pcall(fs.delete,running)end end
