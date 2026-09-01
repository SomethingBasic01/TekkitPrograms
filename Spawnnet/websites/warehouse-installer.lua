-- WarehouseOS 1.0.0 Installer
local files={
  ["/warehouse-controller.lua"]=[=[shell.run('/warehouseos/controller.lua')
]=],
  ["/warehouse-host.lua"]=[=[shell.run('/warehouseos/host.lua')
]=],
  ["/warehouse-terminal.lua"]=[=[shell.run('/warehouseos/terminal.lua')
]=],
  ["/warehouse.lua"]=[=[shell.run('/warehouseos/menu.lua')
]=],
  ["/warehouseos/controller.lua"]=[=[local gui=dofile('/spawnnet/client/gui.lua')
local util=dofile('/spawnnet/lib/util.lua')
local wire=dofile('/warehouseos/lib/wire.lua')
local common=dofile('/warehouseos/lib/common.lua')
local C=colors
local CFG='/warehouseos/controller.db';local cfg=util.loadTable(CFG,nil);local protocol=common.protocol()
local modem=common.findWirelessModem();if not modem then error('WarehouseOS Controller needs a wireless modem',0)end;if not rednet.isOpen(modem)then rednet.open(modem)end
math.randomseed(os.getComputerID()*761+math.floor(os.clock()*1000))
local function inventoryNames()
  local out={};for _,name in ipairs(peripheral.getNames())do local ok,list=pcall(peripheral.call,name,'list');if ok and type(list)=='table'then out[#out+1]=name end end;table.sort(out);return out
end
local function choose(title,names,allowNone)
  local items={};if allowNone then items[#items+1]={label='(none)',name=false}end;for _,n in ipairs(names)do items[#items+1]={label=n..'  ['..tostring(peripheral.getType(n))..']',name=n}end;local m=gui.menu(title,'Select an inventory peripheral.',items);return m and m.name or nil
end
local function pair()
  local code=gui.prompt('PAIR WAREHOUSE CONTROLLER','Pair code from spn://warehouse:','');if code==''then return nil end
  local name=gui.prompt('CONTROLLER NAME','Name:','Warehouse Controller #'..os.getComputerID())
  gui.toast('Looking for WarehouseOS Host...',1)
  local deadline=os.clock()+8;local lastSend=-10
  while os.clock()<deadline do if os.clock()-lastSend>=1 then lastSend=os.clock();rednet.broadcast({type='pair',code=code,name=name},protocol)end;local sender,msg,proto=rednet.receive(protocol,.5);if sender then local obj,done=wire.accept(sender,msg);if done and obj then if obj.type=='pair_ok'then return{warehouseId=obj.warehouseId,warehouseName=obj.warehouseName,token=obj.token,host=sender,name=name} elseif obj.type=='pair_error'then gui.toast(obj.error,3);return nil end end end end
  gui.toast('No WarehouseOS Host answered',3);return nil
end
if not cfg or not cfg.token then cfg=pair();if not cfg then return end
  local names=inventoryNames();if #names<2 then gui.toast('Connect at least storage inventories plus an output inventory, then rerun setup.',4)end
  cfg.output=choose('MAIN OUTPUT INVENTORY',names,false)
  local depNames={};for _,n in ipairs(names)do if n~=cfg.output then depNames[#depNames+1]=n end end
  cfg.deposit=choose('MAIN DEPOSIT INVENTORY',depNames,true);cfg.autoDeposit=true;util.saveTable(CFG,cfg)
end
local function methods(name)local set={};local ok,a=pcall(peripheral.getMethods,name);if ok and type(a)=='table'then for _,m in ipairs(a)do set[m]=true end end;return set end
local detailCache={}
local function detail(inv,slot,item)
  if detailCache[item.name]then return detailCache[item.name]end
  local d=nil;if methods(inv).getItemDetail then local ok,x=pcall(peripheral.call,inv,'getItemDetail',slot);if ok and type(x)=='table'then d=x end end
  local name=(d and(d.displayName or d.name))or common.displayName(item.name);local x={name=name,mod=common.modName(item.name)};detailCache[item.name]=x;return x
end
local function storageNames()
  local a={};for _,n in ipairs(inventoryNames())do if n~=cfg.output and n~=cfg.deposit then a[#a+1]=n end end;return a
end
local index={};local lastScan=0
local function scan()
  local idx={};local stores=storageNames();for _,inv in ipairs(stores)do local ok,list=pcall(peripheral.call,inv,'list');if ok and type(list)=='table'then for slot,item in pairs(list)do if type(item)=='table'and item.name then local id=tostring(item.name);local it=idx[id];if not it then local d=detail(inv,slot,item);it={id=id,name=d.name,mod=d.mod,amount=0,stacks=0,locations={}};idx[id]=it end;local count=tonumber(item.count)or 0;it.amount=it.amount+count;it.stacks=it.stacks+1;it.locations[#it.locations+1]={inv=inv,slot=tonumber(slot),count=count}end end end end;index=idx;lastScan=os.clock();return stores
end
local function publicIndex(stores)local a={};for _,it in pairs(index)do a[#a+1]={id=it.id,name=it.name,mod=it.mod,amount=it.amount,stacks=it.stacks}end;table.sort(a,function(x,y)return x.name<y.name end);return{type='index',warehouseId=cfg.warehouseId,token=cfg.token,items=a,inventories=#stores}end
local function push(src,target,slot,amount)
  local ok,n=pcall(peripheral.call,src,'pushItems',target,slot,amount);if ok and tonumber(n)then return tonumber(n)end
  local mt=methods(target);local size=nil;if mt.size then local o,s=pcall(peripheral.call,target,'size');if o then size=tonumber(s)end end
  if size then local total=0;for to=1,size do if total>=amount then break end;local o,x=pcall(peripheral.call,src,'pushItems',target,slot,amount-total,to);if o and tonumber(x)then total=total+tonumber(x)end end;return total end
  return 0
end
local function withdraw(itemId,amount,target)
  if not target or target==''then target=cfg.output end;if not target then return false,0,'No output inventory configured'end
  local it=index[itemId];if not it then return false,0,'Item not found'end;local left=amount;local moved=0
  for _,loc in ipairs(it.locations or{})do if left<=0 then break end;local n=push(loc.inv,target,loc.slot,math.min(left,loc.count));moved=moved+n;left=left-n end
  scan();if moved<=0 then return false,0,'No items could be transferred. Target may be full or not visible on this wired network.'end
  return true,moved,moved<amount and('Partial withdrawal: '..moved..'/'..amount)or('Withdrew '..moved..' '..it.name),it.name
end
local function deposit(source)
  source=source or cfg.deposit;if not source then return false,0,'No deposit inventory configured'end
  local ok,list=pcall(peripheral.call,source,'list');if not ok or type(list)~='table'then return false,0,'Deposit inventory unavailable'end
  local moved=0;local stores=storageNames();for slot,item in pairs(list)do local left=tonumber(item.count)or 0;for _,target in ipairs(stores)do if left<=0 then break end;local n=push(source,target,tonumber(slot),left);moved=moved+n;left=left-n end end
  scan();return moved>0,moved,moved>0 and('Deposited '..moved..' items')or'Nothing moved from deposit inventory'
end
local stores=scan()
local function heartbeat()
  local names={};for _,n in ipairs(storageNames())do names[n]=true end
  wire.send(cfg.host,{type='heartbeat',warehouseId=cfg.warehouseId,token=cfg.token,inventories=#storageNames(),output=cfg.output,deposit=cfg.deposit,storageNames=names},protocol)
end
local function sendIndex()stores=scan();wire.send(cfg.host,publicIndex(stores),protocol)end
local pendingResults={}
local function sendResult(result) pendingResults[result.requestId]={msg=result,last=os.clock(),created=os.clock()};wire.send(cfg.host,result,protocol)end
local function handle(msg)
  if msg.type=='command_ack'and msg.warehouseId==cfg.warehouseId and msg.token==cfg.token then pendingResults[msg.requestId]=nil;return end
  if msg.type~='command'or msg.warehouseId~=cfg.warehouseId or msg.token~=cfg.token then return end
  if pendingResults[msg.requestId]then wire.send(cfg.host,pendingResults[msg.requestId].msg,protocol);return end
  if msg.action=='withdraw'then local ok,moved,message,name=withdraw(msg.item,tonumber(msg.amount)or 1,msg.targetName or(msg.terminal=='main'and cfg.output or nil));sendResult({type='command_result',warehouseId=cfg.warehouseId,token=cfg.token,requestId=msg.requestId,ok=ok,moved=moved,message=message,error=ok and nil or message,name=name});sendIndex()
  elseif msg.action=='deposit'then local ok,moved,message=deposit(cfg.deposit);sendResult({type='command_result',warehouseId=cfg.warehouseId,token=cfg.token,requestId=msg.requestId,ok=ok,moved=moved,message=message,error=ok and nil or message});sendIndex()
  elseif msg.action=='rescan'then sendIndex()end
end
local function draw()
  local total,types=0,0;for _,it in pairs(index)do total=total+it.amount;types=types+1 end;gui.clear();gui.bar('WAREHOUSE CONTROLLER',cfg.warehouseName or cfg.warehouseId);local w=select(1,term.getSize());gui.text(3,4,w-5,'ONLINE',C.lime,C.black,'center');gui.text(3,6,w-5,'Storage inventories: '..#storageNames()..'   Item types: '..types..'   Items: '..common.comma(total),C.white,C.black,'center');gui.text(3,9,w-5,'Output: '..tostring(cfg.output or'none'),C.lightGray,C.black,'center');gui.text(3,10,w-5,'Deposit: '..tostring(cfg.deposit or'none')..'   Auto deposit: '..tostring(cfg.autoDeposit==true),C.lightGray,C.black,'center');gui.status('R rescan   D deposit now   A auto-deposit   Q stop')
end
local t=os.startTimer(1);local lastHeartbeat=0;local lastIndex=0;local lastAuto=0;draw()
while true do local ev={os.pullEvent()};if ev[1]=='rednet_message'and ev[2]==cfg.host and ev[4]==protocol then local obj,done=wire.accept(ev[2],ev[3]);if done and obj then handle(obj);draw()end
  elseif ev[1]=='timer'and ev[2]==t then local now=os.clock();wire.purge();for id,r in pairs(pendingResults)do if now-r.created>12 then pendingResults[id]=nil elseif now-r.last>=1 then r.last=now;wire.send(cfg.host,r.msg,protocol)end end;if now-lastHeartbeat>4 then lastHeartbeat=now;heartbeat()end;if now-lastIndex>5 then lastIndex=now;sendIndex()end;if cfg.autoDeposit and cfg.deposit and now-lastAuto>3 then lastAuto=now;local ok,m=deposit(cfg.deposit);if ok and m>0 then sendIndex()end end;draw();t=os.startTimer(1)
  elseif ev[1]=='key'then if ev[2]==keys.q or ev[2]==keys.escape then break elseif ev[2]==keys.r then sendIndex()elseif ev[2]==keys.d then local ok,m,msg=deposit(cfg.deposit);gui.toast(msg,2);if ok then sendIndex()end elseif ev[2]==keys.a then cfg.autoDeposit=not cfg.autoDeposit;util.saveTable(CFG,cfg);draw()end end end
gui.clear()
]=],
  ["/warehouseos/host.lua"]=[=[local gui=dofile('/spawnnet/client/gui.lua')
local net=dofile('/spawnnet/client/net.lua')
local auth=dofile('/spawnnet/client/auth_client.lua')
local util=dofile('/spawnnet/lib/util.lua')
local crypto=dofile('/spawnnet/lib/crypto.lua')
local wire=dofile('/warehouseos/lib/wire.lua')
local common=dofile('/warehouseos/lib/common.lua')
local C=colors
local DOMAIN='warehouse'
local CFG='/warehouseos/host.auth'
local DB='/warehouseos/host.db'
local protocol=common.protocol()
local state=util.loadTable(DB,{profiles={},warehouses={},pairCodes={},terminalCodes={},pending={},stats={jobs=0,withdrawals=0,deposits=0}})
state.profiles=state.profiles or{};state.warehouses=state.warehouses or{};state.stats=state.stats or{jobs=0,withdrawals=0,deposits=0}
-- os.clock resets when this computer reboots. Never trust persisted online/pending state.
state.pairCodes={};state.terminalCodes={};state.pending={}
for _,w in pairs(state.warehouses)do
  w.pairCode=nil;w.pairExpires=nil
  if w.controller then w.controller.lastSeen=nil end
  for _,t in pairs(w.terminals or{})do t.lastSeen=nil end
end

local function save()util.saveTable(DB,state)end
local function toast(s,t)gui.toast(s,t or 2)end
local function loginHost()
  local cfg=util.loadTable(CFG,nil)
  if cfg and cfg.id and cfg.secret then
    local s,e=auth.apiLogin(cfg.id,cfg.secret);if s then return true end
    toast('Stored host key failed: '..tostring(e),3)
  end
  gui.clear();gui.bar('WAREHOUSEOS HOST SETUP',common.networkId())
  gui.text(3,4,45,'The Host must authenticate as the SpawnNet account which owns spn://'..DOMAIN,C.white,C.black)
  local user=gui.prompt('HOST SETUP','SpawnNet owner username:','')
  if user==''then return false end
  local pw=gui.prompt('HOST SETUP','Password:','','*')
  local s,e=auth.login(user,pw);if not s then toast(e,3);return false end
  local r,er=net.call('dns','resolve',{domain=DOMAIN},{noAuth=true});if not r then toast(er,3);return false end
  if r.owner~=s.user then toast('Logged in as '..tostring(s.user)..' but spn://'..DOMAIN..' belongs to '..tostring(r.owner),4);return false end
  local scopes={'jobs.poll','jobs.claim','jobs.progress','jobs.complete','jobs.fail','mail.send','users.profile','telemetry.push'}
  local k,ke=auth.createKey('WarehouseOS Host #'..os.getComputerID(),scopes);if not k then toast(ke,3);return false end
  util.saveTable(CFG,{id=k.id,secret=k.secret,owner=s.user,domain=DOMAIN,network=common.networkId()})
  local api,ae=auth.apiLogin(k.id,k.secret);if not api then toast(ae,3);return false end
  return true
end
if not loginHost()then return end

local modem=common.findWirelessModem()
if not modem then error('WarehouseOS Host needs a wireless modem',0)end
if not rednet.isOpen(modem)then rednet.open(modem)end
math.randomseed((os.getComputerID()*997)+math.floor(os.clock()*1000))

local function code(n)return crypto.randomHex(math.ceil((n or 8)/2)):sub(1,n or 8):upper()end
local function newId(name)
  local base=common.safe(name,18);if base==''then base='warehouse'end
  local id=base..'-'..crypto.randomHex(2)
  while state.warehouses[id]do id=base..'-'..crypto.randomHex(2)end
  return id
end
local function warehouse(id)return state.warehouses[tostring(id or'')]end
local function role(w,user)
  if not w or not user then return nil end
  if w.owner==user then return'owner'end
  return w.members and w.members[user]or nil
end
local function online(w)return w and w.controller and w.controller.lastSeen and(os.clock()-w.controller.lastSeen<15)end
local function totalStats(w)
  local total,types=0,0
  for _,it in pairs(w and w.index or{})do total=total+(tonumber(it.amount)or 0);types=types+1 end
  return total,types
end
local function publicSummary(w,user)
  local total,types=totalStats(w);local c=w.controller or{}
  return{id=w.id,name=w.name,role=role(w,user),online=online(w),total=total,types=types,inventories=tonumber(c.inventories)or 0,output=c.output or'main',deposit=c.deposit or'none',lastSeen=c.lastSeen or 0}
end
local function complete(id,result,message)
  local p,e=net.call('jobs','complete',{domain=DOMAIN,id=id,result=result or{},message=message or'Completed'});return p,e
end
local function fail(id,err)net.call('jobs','fail',{domain=DOMAIN,id=id,error=tostring(err or'Failed')})end
local function mail(to,subject,body)net.call('mail','send',{to=to,subject=subject,body=body})end
local function ensureProfile(user)if user and user~=''then state.profiles[user]=state.profiles[user]or{created=os.clock()};return state.profiles[user]end end
local function listFor(user,page)
  ensureProfile(user);local a={}
  for _,w in pairs(state.warehouses)do local r=role(w,user);if r then local x=publicSummary(w,user);a[#a+1]=x end end
  table.sort(a,function(x,y)return tostring(x.name)<tostring(y.name)end)
  page=math.max(1,tonumber(page)or 1);local size=8;local pages=math.max(1,math.ceil(#a/size));if page>pages then page=pages end
  local out={count=#a,page=page,pages=pages}
  for i=1,size do local x=a[(page-1)*size+i];if x then out['id'..i]=x.id;out['name'..i]=x.name;out['label'..i]=x.name..'  ['..x.role..']  '..(x.online and'ONLINE'or'OFFLINE')end end
  return out
end
local function search(w,q,mod,min,sort,page)
  q=tostring(q or''):lower();mod=tostring(mod or''):lower();if mod=='all'or mod=='*'then mod=''end;min=tonumber(min)or 0
  local a={};for _,it in pairs(w.index or{})do local hay=(tostring(it.name)..' '..tostring(it.id)):lower();local imod=tostring(it.mod or''):lower();if(q==''or hay:find(q,1,true))and(mod==''or imod:find(mod,1,true))and(tonumber(it.amount)or 0)>=min then a[#a+1]=it end end
  if sort=='name'then table.sort(a,function(x,y)return tostring(x.name)<tostring(y.name)end)
  elseif sort=='mod'then table.sort(a,function(x,y)if x.mod==y.mod then return x.name<y.name end;return tostring(x.mod)<tostring(y.mod)end)
  else table.sort(a,function(x,y)if x.amount==y.amount then return x.name<y.name end;return(tonumber(x.amount)or 0)>(tonumber(y.amount)or 0)end)end
  page=math.max(1,tonumber(page)or 1);local size=8;local pages=math.max(1,math.ceil(#a/size));if page>pages then page=pages end
  local out={count=#a,page=page,pages=pages}
  for i=1,size do local it=a[(page-1)*size+i];if it then out['id'..i]=it.id;out['name'..i]=it.name;out['amount'..i]=it.amount;out['mod'..i]=it.mod;out['label'..i]=it.name..'  x'..common.comma(it.amount)..'  ['..it.mod..']'end end
  return out
end
local function addHistory(w,row)
  w.history=w.history or{};table.insert(w.history,1,row);while#w.history>120 do table.remove(w.history)end
end
local function sendController(w,msg)
  if not w.controller or not w.controller.computer or not online(w)then return false,'Controller offline'end
  msg.warehouseId=w.id;msg.token=w.controller.token
  return wire.send(w.controller.computer,msg,protocol)
end
local function terminalById(w,id)if not w or not w.terminals then return nil end;return w.terminals[tostring(id or'')]end

local function immediateJob(j)
  local action=j.action;local user=j.submitter;local item=tostring((j.payload or{}).item or'');local parts=common.split(item,'|')
  ensureProfile(user);state.stats.jobs=(state.stats.jobs or 0)+1
  if action=='profile_register'then save();return complete(j.id,{user=user},'Warehouse profile registered')
  elseif action=='list'then return complete(j.id,listFor(user,tonumber(parts[1])or 1),'Warehouses loaded')
  elseif action=='create'then
    local name=common.trim(item);if name==''then return fail(j.id,'Warehouse name required')end
    local owned=0;for _,x in pairs(state.warehouses)do if x.owner==user then owned=owned+1 end end;if owned>=10 then return fail(j.id,'Warehouse limit reached')end
    local id=newId(name);local pair=code(8);local w={id=id,name=name:sub(1,40),owner=user,members={},created=os.clock(),index={},history={},terminals={},pairCode=pair,pairExpires=os.clock()+1800}
    state.warehouses[id]=w;state.pairCodes[pair]=id;save();return complete(j.id,{warehouseId=id,name=w.name,pairCode=pair},'Warehouse created - pair a controller')
  elseif action=='summary'then
    local w=warehouse(parts[1]);local r=role(w,user);if not common.roleCan(r,'view')then return fail(j.id,'No access to this warehouse')end
    local out=publicSummary(w,user);out.memberCount=1;for _ in pairs(w.members or{})do out.memberCount=out.memberCount+1 end
    local ti=0;for id,t in pairs(w.terminals or{})do ti=ti+1;if ti<=4 then out['terminal'..ti]=id..' - '..tostring(t.name or t.inventory or'Wireless terminal')end end;out.terminalCount=ti
    return complete(j.id,out,'Warehouse summary')
  elseif action=='search'then
    local w=warehouse(parts[1]);local r=role(w,user);if not common.roleCan(r,'view')then return fail(j.id,'No access to this warehouse')end
    return complete(j.id,search(w,parts[2],parts[3],parts[4],parts[5],parts[6]),'Inventory search complete')
  elseif action=='invite'then
    local w=warehouse(parts[1]);local r=role(w,user);if r~='owner'and r~='admin'then return fail(j.id,'Admin permission required')end
    local target=common.safe(parts[2],24);local newRole=parts[3]or'viewer';if not({admin=true,operator=true,withdrawer=true,depositor=true,viewer=true})[newRole]then return fail(j.id,'Invalid role')end
    local prof,pe=net.call('users','profile',{user=target});if not prof then return fail(j.id,pe or'Unknown user')end
    w.members[target]=newRole;save();mail(target,'WarehouseOS access granted',user..' granted you '..newRole..' access to '..w.name..' ['..w.id..']. Open spn://warehouse and choose My Warehouses.')
    return complete(j.id,{user=target,role=newRole},'Member added')
  elseif action=='members'then
    local w=warehouse(parts[1]);local r=role(w,user);if not common.roleCan(r,'view')then return fail(j.id,'No access')end
    local a={{user=w.owner,role='owner'}};for u,rr in pairs(w.members or{})do a[#a+1]={user=u,role=rr}end;table.sort(a,function(x,y)return x.user<y.user end)
    local out={count=#a};for i=1,math.min(8,#a)do out['label'..i]=a[i].user..'  ['..a[i].role..']';out['user'..i]=a[i].user end;return complete(j.id,out,'Members loaded')
  elseif action=='remove_member'then
    local w=warehouse(parts[1]);local r=role(w,user);if r~='owner'and r~='admin'then return fail(j.id,'Admin permission required')end
    local target=parts[2];if target==w.owner then return fail(j.id,'Owner cannot be removed')end;w.members[target]=nil;save();return complete(j.id,{user=target},'Member removed')
  elseif action=='history'then
    local w=warehouse(parts[1]);local r=role(w,user);if not common.roleCan(r,'view')then return fail(j.id,'No access')end
    local out={count=#(w.history or{})};for i=1,math.min(8,#(w.history or{}))do local h=w.history[i];out['label'..i]=tostring(h.user)..'  '..tostring(h.action):upper()..'  '..tostring(h.amount)..' '..tostring(h.name or h.item)..' -> '..tostring(h.terminal or'main')end;return complete(j.id,out,'History loaded')
  elseif action=='controller_code'then
    local w=warehouse(parts[1]);local r=role(w,user);if r~='owner'and r~='admin'then return fail(j.id,'Admin permission required')end
    local pc=code(8);w.pairCode=pc;w.pairExpires=os.clock()+1800;state.pairCodes[pc]=w.id;save();return complete(j.id,{pairCode=pc},'Controller pair code created')
  elseif action=='terminal_code'then
    local w=warehouse(parts[1]);local r=role(w,user);if r~='owner'and r~='admin'then return fail(j.id,'Admin permission required')end
    local pc=code(8);state.terminalCodes[pc]={warehouseId=w.id,owner=user,expires=os.clock()+1800};save();return complete(j.id,{pairCode=pc},'Remote terminal pair code created')
  elseif action=='withdraw'or action=='deposit'then
    local w=warehouse(parts[1]);local needed=action=='withdraw'and'withdraw'or'deposit';local r=role(w,user);if not common.roleCan(r,needed)then return fail(j.id,'Permission denied')end
    local amount=math.max(1,math.floor(tonumber((j.payload or{}).count)or 1));local target=parts[3]or'main';local req=crypto.randomHex(8);local msg={type='command',requestId=req,action=action,item=parts[2],amount=amount,terminal=target,user=user}
    if action=='deposit'and target~='main'then
      local t=terminalById(w,target);if not t or not t.lastSeen or os.clock()-t.lastSeen>15 then return fail(j.id,'Remote terminal offline')end
      local first=nil;for name in pairs(w.controller and w.controller.storageNames or{})do first=name break end
      if not first then return fail(j.id,'Warehouse storage unavailable')end
      local ok,e=wire.send(t.computer,{type='terminal_command',warehouseId=w.id,token=t.token,requestId=req,action='deposit',targetName=first},protocol);if not ok then return fail(j.id,e)end
      state.pending[req]={jobId=j.id,wid=w.id,action=action,user=user,item='deposit',amount=amount,terminal=target,started=os.clock(),kind='terminal'};return true
    end
    if target~='main'then local t=terminalById(w,target);if not t or not t.lastSeen or os.clock()-t.lastSeen>15 then return fail(j.id,'Remote terminal offline')end;msg.targetName=t.inventory end
    local ok,e=sendController(w,msg);if not ok then return fail(j.id,e)end
    state.pending[req]={jobId=j.id,wid=w.id,action=action,user=user,item=parts[2],amount=amount,terminal=target,started=os.clock(),kind='controller'};return true
  end
  return fail(j.id,'Unknown WarehouseOS job '..tostring(action))
end

local function handleController(sender,msg)
  if msg.type=='discover_host'then wire.send(sender,{type='host_here',network=common.networkId(),computer=os.getComputerID()},protocol);return end
  if msg.type=='pair'then
    local wid=state.pairCodes[tostring(msg.code or'')];local w=warehouse(wid)
    if not w or not w.pairCode or w.pairCode~=msg.code or(os.clock()>w.pairExpires)then wire.send(sender,{type='pair_error',error='Invalid or expired pair code'},protocol);return end
    if w.controller and w.controller.pairCodeUsed==msg.code then
      if w.controller.computer~=sender then wire.send(sender,{type='pair_error',error='Pair code already used'},protocol);return end
      w.controller.lastSeen=os.clock();wire.send(sender,{type='pair_ok',warehouseId=w.id,warehouseName=w.name,token=w.controller.token,host=os.getComputerID()},protocol);return
    end
    local token=crypto.randomHex(24);w.controller={computer=sender,token=token,lastSeen=os.clock(),name=msg.name or('Controller #'..sender),inventories=0,storageNames={},pairCodeUsed=msg.code};save();wire.send(sender,{type='pair_ok',warehouseId=w.id,warehouseName=w.name,token=token,host=os.getComputerID()},protocol);return
  end
  if msg.type=='terminal_pair'then
    local rec=state.terminalCodes[tostring(msg.code or'')];local w=rec and warehouse(rec.warehouseId)
    if not rec or not w or os.clock()>rec.expires then wire.send(sender,{type='terminal_pair_error',error='Invalid or expired terminal pair code'},protocol);return end
    if rec.terminalId then
      local t=w.terminals and w.terminals[rec.terminalId]
      if not t or t.computer~=sender then wire.send(sender,{type='terminal_pair_error',error='Terminal pair code already used'},protocol);return end
      t.lastSeen=os.clock();wire.send(sender,{type='terminal_pair_ok',warehouseId=w.id,warehouseName=w.name,terminalId=t.id,token=t.token,host=os.getComputerID()},protocol);return
    end
    local id='remote-'..crypto.randomHex(2);local token=crypto.randomHex(24);w.terminals[id]={id=id,computer=sender,token=token,inventory=msg.inventory,name=msg.name or id,lastSeen=os.clock()};rec.terminalId=id;rec.sender=sender;save();wire.send(sender,{type='terminal_pair_ok',warehouseId=w.id,warehouseName=w.name,terminalId=id,token=token,host=os.getComputerID()},protocol);return
  end
  local w=warehouse(msg.warehouseId);if not w then return end
  if msg.type=='heartbeat'or msg.type=='index'or msg.type=='command_result'then
    local c=w.controller;if not c or c.computer~=sender or c.token~=msg.token then return end;c.lastSeen=os.clock()
    if msg.type=='heartbeat'then c.inventories=msg.inventories or c.inventories;c.output=msg.output or c.output;c.deposit=msg.deposit or c.deposit;c.storageNames=msg.storageNames or c.storageNames or{}
    elseif msg.type=='index'then w.index={};for _,it in ipairs(msg.items or{})do if it.id then w.index[it.id]=it end end;c.inventories=msg.inventories or c.inventories;c.lastScan=os.clock()
    elseif msg.type=='command_result'then
      wire.send(sender,{type='command_ack',warehouseId=w.id,token=c.token,requestId=msg.requestId},protocol)
      local p=state.pending[msg.requestId];if p and p.wid==w.id then
        state.pending[msg.requestId]=nil
        if msg.ok then
          addHistory(w,{time=os.clock(),user=p.user,action=p.action,item=p.item,name=msg.name or p.item,amount=msg.moved or p.amount,terminal=p.terminal});if p.action=='withdraw'then state.stats.withdrawals=(state.stats.withdrawals or 0)+1 else state.stats.deposits=(state.stats.deposits or 0)+1 end;save();complete(p.jobId,{moved=msg.moved or 0,name=msg.name or p.item,terminal=p.terminal},msg.message or'Physical operation complete')
        else fail(p.jobId,msg.error or msg.message or'Physical operation failed')end
      end
    end
    return
  end
  if msg.type=='terminal_heartbeat'or msg.type=='terminal_result'then
    local t=terminalById(w,msg.terminalId);if not t or t.computer~=sender or t.token~=msg.token then return end;t.lastSeen=os.clock();t.inventory=msg.inventory or t.inventory;t.name=msg.name or t.name
    if msg.type=='terminal_result'then wire.send(sender,{type='terminal_ack',warehouseId=w.id,terminalId=t.id,token=t.token,requestId=msg.requestId},protocol);local p=state.pending[msg.requestId];if p then state.pending[msg.requestId]=nil;if msg.ok then addHistory(w,{time=os.clock(),user=p.user,action='deposit',item='remote deposit',name='Remote deposit',amount=msg.moved or 0,terminal=p.terminal});save();complete(p.jobId,{moved=msg.moved or 0,terminal=p.terminal},msg.message or'Remote deposit complete');sendController(w,{type='command',requestId=crypto.randomHex(8),action='rescan',user=p.user})else fail(p.jobId,msg.error or'Remote deposit failed')end end end
  end
end

local lastPoll=0;local lastTelemetry=0;local lastSave=os.clock();local running=true
local function pollJobs()
  local p,e=net.call('jobs','poll',{domain=DOMAIN,queue='host',limit=20});if not p then return end
  for _,j in ipairs(p.jobs or{})do local c=net.call('jobs','claim',{domain=DOMAIN,id=j.id,worker='WarehouseOS Host #'..os.getComputerID()});if c then immediateJob(j)end end
end
local function pushTelemetry()
  local onlineCount,totalItems=0,0;for _,w in pairs(state.warehouses)do if online(w)then onlineCount=onlineCount+1 end;local t=totalStats(w);totalItems=totalItems+t end
  net.call('telemetry','push',{domain=DOMAIN,stream='host',computer=os.getComputerID(),data={online=true,warehouses=(function()local n=0;for _ in pairs(state.warehouses)do n=n+1 end;return n end)(),controllers=onlineCount,totalItems=totalItems,jobs=state.stats.jobs or 0}})
end
local function draw()
  local wh,controllers,items=0,0,0;for _,w in pairs(state.warehouses)do wh=wh+1;if online(w)then controllers=controllers+1 end;local t=totalStats(w);items=items+t end
  gui.clear();gui.bar('WAREHOUSEOS HOST','spn://'..DOMAIN);local w=select(1,term.getSize());gui.text(3,4,w-5,'ONLINE',C.lime,C.black,'center');gui.text(3,6,w-5,'Warehouses: '..wh..'   Controllers: '..controllers..'   Indexed items: '..common.comma(items),C.white,C.black,'center');gui.text(3,9,w-5,'Host computer #'..os.getComputerID()..'  |  '..protocol,C.lightGray,C.black,'center');gui.text(3,12,w-5,'This computer is the central WarehouseOS directory/search/permission host.',C.lightGray,C.black,'center');gui.status('Q stop host   Jobs '..tostring(state.stats.jobs or 0)..'   Withdrawals '..tostring(state.stats.withdrawals or 0)..'   Deposits '..tostring(state.stats.deposits or 0))
end
draw();local timer=os.startTimer(.5)
while running do
  local ev={os.pullEvent()}
  if ev[1]=='rednet_message'and ev[4]==protocol then local msg,done=wire.accept(ev[2],ev[3]);if done and msg then handleController(ev[2],msg)end
  elseif ev[1]=='timer'and ev[2]==timer then
    wire.purge();pollJobs();local now=os.clock()
    for id,p in pairs(state.pending)do if now-(p.started or now)>12 then state.pending[id]=nil;fail(p.jobId,'Warehouse operation timed out')end end
    if now-lastTelemetry>4 then lastTelemetry=now;pushTelemetry()end
    if now-lastSave>20 then lastSave=now;save()end
    draw();timer=os.startTimer(.5)
  elseif ev[1]=='key'and(ev[2]==keys.q or ev[2]==keys.escape)then running=false end
end
save();gui.clear()
]=],
  ["/warehouseos/lib/common.lua"]=[=[local M={}
function M.safe(s,n)
  s=tostring(s or''):lower():gsub('[^%w%-_]','-'):gsub('%-+','-'):gsub('^%-',''):gsub('%-$','')
  return s:sub(1,n or 32)
end
function M.trim(s)return tostring(s or''):match('^%s*(.-)%s*$')end
function M.split(s,sep)
  local out={};s=tostring(s or'');sep=sep or'|';local p=1
  while true do local i,j=s:find(sep,p,true);if not i then out[#out+1]=s:sub(p);break end;out[#out+1]=s:sub(p,i-1);p=j+1 end
  return out
end
function M.join(a,sep)return table.concat(a or{},sep or'|')end
function M.comma(n)
  local s=tostring(math.floor(tonumber(n)or 0));local sign='';if s:sub(1,1)=='-' then sign='-';s=s:sub(2) end
  while true do local x,k=s:gsub('^(%d+)(%d%d%d)','%1,%2');s=x;if k==0 then break end end
  return sign..s
end
function M.displayName(id)
  local path=tostring(id or''):match(':(.+)$') or tostring(id or'item')
  path=path:gsub('[_%-]+',' ')
  path=path:gsub('(%a)([%w]*)',function(a,b)return a:upper()..b:lower()end)
  return path
end
function M.modName(id)
  local x=tostring(id or''):match('^([^:]+):') or'unknown'
  return M.displayName(x)
end
function M.roleCan(role,action)
  role=tostring(role or'')
  if role=='owner' or role=='admin' then return true end
  if action=='view' then return role=='operator'or role=='withdrawer'or role=='depositor'or role=='viewer' end
  if action=='withdraw' then return role=='operator'or role=='withdrawer' end
  if action=='deposit' then return role=='operator'or role=='depositor' end
  return false
end
function M.findWirelessModem()
  for _,name in ipairs(peripheral.getNames())do
    if peripheral.getType(name)=='modem'then
      local ok,w=pcall(peripheral.call,name,'isWireless')
      if ok and w then return name end
    end
  end
  return nil
end
function M.networkId()
  local ok,net=pcall(dofile,'/spawnnet/client/net.lua')
  if ok and net and net.activeNetwork then local n=net.activeNetwork();return tostring(n.id or'public')end
  return'public'
end
function M.protocol()return'warehouseos:'..M.networkId()..':v1'end
return M
]=],
  ["/warehouseos/lib/wire.lua"]=[=[local M={}
local buckets={}
local FRAG=5600
local MAX=240000
local function rid()
  return tostring(os.getComputerID())..'-'..tostring(math.floor(os.clock()*1000))..'-'..tostring(math.random(100000,999999))
end
function M.send(to,msg,protocol)
  local ok,raw=pcall(textutils.serialize,msg)
  if not ok then return false,'serialize failed: '..tostring(raw) end
  if #raw>MAX then return false,'packet too large: '..tostring(#raw) end
  if #raw<=FRAG then return rednet.send(to,msg,protocol) end
  local id=rid();local total=math.ceil(#raw/FRAG)
  for i=1,total do
    local env={__warehouse_fragment=true,id=id,index=i,total=total,data=raw:sub((i-1)*FRAG+1,i*FRAG)}
    local sent=rednet.send(to,env,protocol)
    if not sent then return false,'fragment send failed' end
  end
  return true
end
function M.accept(sender,msg)
  if type(msg)~='table' or msg.__warehouse_fragment~=true then return msg,true end
  if type(msg.id)~='string' or type(msg.index)~='number' or type(msg.total)~='number' or type(msg.data)~='string' then return nil,false,'bad fragment' end
  if msg.total<1 or msg.total>100 or msg.index<1 or msg.index>msg.total then return nil,false,'bad fragment range' end
  local key=tostring(sender)..':'..msg.id
  local b=buckets[key]
  if not b then b={total=msg.total,parts={},count=0,bytes=0,created=os.clock()};buckets[key]=b end
  if b.total~=msg.total then buckets[key]=nil;return nil,false,'fragment mismatch' end
  if not b.parts[msg.index] then b.parts[msg.index]=msg.data;b.count=b.count+1;b.bytes=b.bytes+#msg.data end
  if b.bytes>MAX then buckets[key]=nil;return nil,false,'fragment payload too large' end
  if b.count<b.total then return nil,false end
  local parts={};for i=1,b.total do if not b.parts[i] then return nil,false end;parts[i]=b.parts[i] end
  buckets[key]=nil
  local ok,obj=pcall(textutils.unserialize,table.concat(parts))
  if not ok or type(obj)~='table' then return nil,false,'decode failed' end
  return obj,true
end
function M.purge()
  local now=os.clock();for k,b in pairs(buckets)do if now-(b.created or now)>20 then buckets[k]=nil end end
end
return M
]=],
  ["/warehouseos/menu.lua"]=[=[local gui=dofile('/spawnnet/client/gui.lua')
while true do local m=gui.menu('WAREHOUSEOS','ME-style storage over SpawnNet + ComputerCraft inventories.',{
 {label='Open WarehouseOS website',action='web'},{label='Run central Host',action='host'},{label='Run warehouse Controller',action='controller'},{label='Run wireless Remote Terminal',action='terminal'},{label='Reset Controller pairing',action='resetc'},{label='Reset Terminal pairing',action='resett'},{label='Back',action='back'}})
 if not m or m.action=='back'then break elseif m.action=='web'then shell.run('/spawnnet/client/browser.lua','spn://warehouse')elseif m.action=='host'then shell.run('/warehouseos/host.lua')elseif m.action=='controller'then shell.run('/warehouseos/controller.lua')elseif m.action=='terminal'then shell.run('/warehouseos/terminal.lua')elseif m.action=='resetc'then if fs.exists('/warehouseos/controller.db')then fs.delete('/warehouseos/controller.db')end;gui.toast('Controller pairing cleared',1)elseif m.action=='resett'then if fs.exists('/warehouseos/terminal.db')then fs.delete('/warehouseos/terminal.db')end;gui.toast('Terminal pairing cleared',1)end end
gui.clear()
]=],
  ["/warehouseos/terminal.lua"]=[=[local gui=dofile('/spawnnet/client/gui.lua')
local util=dofile('/spawnnet/lib/util.lua')
local wire=dofile('/warehouseos/lib/wire.lua')
local common=dofile('/warehouseos/lib/common.lua')
local C=colors
local CFG='/warehouseos/terminal.db';local cfg=util.loadTable(CFG,nil);local protocol=common.protocol();local modem=common.findWirelessModem();if not modem then error('WarehouseOS Remote Terminal needs a wireless modem',0)end;if not rednet.isOpen(modem)then rednet.open(modem)end
local function inventories()local a={};for _,n in ipairs(peripheral.getNames())do local ok,l=pcall(peripheral.call,n,'list');if ok and type(l)=='table'then a[#a+1]=n end end;table.sort(a);return a end
local function pair()
  local code=gui.prompt('REMOTE TERMINAL PAIR','Pair code from WarehouseOS Settings:','');if code==''then return nil end
  local a=inventories();if#a==0 then gui.toast('Connect a chest/inventory to this computer first.',3);return nil end
  local items={};for _,n in ipairs(a)do items[#items+1]={label=n..' ['..tostring(peripheral.getType(n))..']',name=n}end;local m=gui.menu('REMOTE I/O INVENTORY','This inventory is the physical remote terminal.',items);if not m then return nil end
  local name=gui.prompt('TERMINAL NAME','Display name:','Remote Terminal #'..os.getComputerID())
  local deadline=os.clock()+8;local lastSend=-10;while os.clock()<deadline do if os.clock()-lastSend>=1 then lastSend=os.clock();rednet.broadcast({type='terminal_pair',code=code,inventory=m.name,name=name},protocol)end;local sender,msg=rednet.receive(protocol,.5);if sender then local obj,done=wire.accept(sender,msg);if done and obj then if obj.type=='terminal_pair_ok'then return{warehouseId=obj.warehouseId,warehouseName=obj.warehouseName,terminalId=obj.terminalId,token=obj.token,host=sender,inventory=m.name,name=name}elseif obj.type=='terminal_pair_error'then gui.toast(obj.error,3);return nil end end end end;gui.toast('No WarehouseOS Host answered',3);return nil
end
if not cfg or not cfg.token then cfg=pair();if not cfg then return end;util.saveTable(CFG,cfg)end
local function methods(name)local s={};local ok,a=pcall(peripheral.getMethods,name);if ok and type(a)=='table'then for _,m in ipairs(a)do s[m]=true end end;return s end
local function push(src,target,slot,amount)local ok,n=pcall(peripheral.call,src,'pushItems',target,slot,amount);if ok and tonumber(n)then return tonumber(n)end;return 0 end
local function deposit(target)
  local ok,list=pcall(peripheral.call,cfg.inventory,'list');if not ok then return false,0,'Local terminal inventory offline'end;local moved=0;for slot,item in pairs(list or{})do local n=push(cfg.inventory,target,tonumber(slot),tonumber(item.count)or 64);moved=moved+n end;if moved==0 then return false,0,'No item path to warehouse target. The remote peripheral name is not reachable from this computer.'end;return true,moved,'Sent '..moved..' items toward warehouse storage'
end
local function count()local ok,list=pcall(peripheral.call,cfg.inventory,'list');local n=0;if ok then for _,it in pairs(list or{})do n=n+(tonumber(it.count)or 0)end end;return n end
local function heartbeat()wire.send(cfg.host,{type='terminal_heartbeat',warehouseId=cfg.warehouseId,terminalId=cfg.terminalId,token=cfg.token,inventory=cfg.inventory,name=cfg.name,count=count()},protocol)end
local pendingResults={}
local function sendResult(r)pendingResults[r.requestId]={msg=r,last=os.clock(),created=os.clock()};wire.send(cfg.host,r,protocol)end
local function handle(msg)if msg.type=='terminal_ack'and msg.warehouseId==cfg.warehouseId and msg.token==cfg.token then pendingResults[msg.requestId]=nil;return end;if msg.type~='terminal_command'or msg.warehouseId~=cfg.warehouseId or msg.token~=cfg.token then return end;if pendingResults[msg.requestId]then wire.send(cfg.host,pendingResults[msg.requestId].msg,protocol);return end;if msg.action=='deposit'then local ok,moved,message=deposit(msg.targetName);sendResult({type='terminal_result',warehouseId=cfg.warehouseId,terminalId=cfg.terminalId,token=cfg.token,requestId=msg.requestId,ok=ok,moved=moved,message=message,error=ok and nil or message})end end
local function draw()gui.clear();gui.bar('WAREHOUSE REMOTE TERMINAL',cfg.terminalId);local w=select(1,term.getSize());gui.text(3,4,w-5,cfg.warehouseName or cfg.warehouseId,C.yellow,C.black,'center');gui.text(3,7,w-5,'Inventory: '..tostring(cfg.inventory),C.white,C.black,'center');gui.text(3,9,w-5,'Items currently in terminal: '..common.comma(count()),C.lightGray,C.black,'center');gui.text(3,12,w-5,'Wireless control link: ONLINE',C.lime,C.black,'center');gui.status('Q stop   Keep this computer and its wireless modem online')end
local t=os.startTimer(1);local last=0;draw();while true do local ev={os.pullEvent()};if ev[1]=='rednet_message'and ev[2]==cfg.host and ev[4]==protocol then local obj,done=wire.accept(ev[2],ev[3]);if done and obj then handle(obj);draw()end elseif ev[1]=='timer'and ev[2]==t then local now=os.clock();for id,r in pairs(pendingResults)do if now-r.created>12 then pendingResults[id]=nil elseif now-r.last>=1 then r.last=now;wire.send(cfg.host,r.msg,protocol)end end;if now-last>4 then last=now;heartbeat()end;draw();t=os.startTimer(1)elseif ev[1]=='key'and(ev[2]==keys.q or ev[2]==keys.escape)then break end end;gui.clear()
]=],
}
local function mkdirFor(path) local d=fs.getDir(path);if d~=''and not fs.exists(d)then fs.makeDir(d)end end
term.clear();term.setCursorPos(1,1);term.setTextColor(colors.lime);print('WAREHOUSEOS 1.0.0');term.setTextColor(colors.white);print('Installing ME-style storage tools for SpawnNet...');print()
if not fs.exists('/spawnnet/client/net.lua')then error('SpawnNet client must be installed first.',0)end
for path,data in pairs(files)do mkdirFor(path);local h=fs.open(path,'w');if not h then error('Cannot write '..path,0)end;h.write(data);h.close();print('  '..path)end
print();term.setTextColor(colors.lime);print('INSTALL COMPLETE');term.setTextColor(colors.white);print();print('Commands:');print('  warehouse             WarehouseOS menu');print('  warehouse-host        Central always-loaded host');print('  warehouse-controller  Physical warehouse controller');print('  warehouse-terminal    Wireless remote terminal');print();print('Publish the website separately with WarehouseOS-Publisher-1.0.0.lua')
