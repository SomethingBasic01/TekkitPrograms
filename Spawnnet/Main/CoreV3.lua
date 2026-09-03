-- SpawnNet 2.3.0 COMPLETE CORE
-- Fresh install or in-place upgrade. No base installer or hotfix chain.
local files={
  ["/spawnnet-admin.lua"]=[==[shell.run('/spawnnet/tools/admin.lua')
]==],
  ["/spawnnet-core-update.lua"]=[==[local a={...};os.run({},'/spawnnet/server/core_updater.lua',a[1]or'update')
]==],
  ["/spawnnet-packages.lua"]=[==[local M=dofile('/spawnnet/client/package_manager.lua');local a={...};if a[1]=='install'then local ok,e=M.installFromSite(a[2],a[3],'command line');if not ok and e~='Cancelled'then printError(e)end elseif a[1]=='download'then local f,e=M.downloadFromSite(a[2],a[3],'command line');if f then print('Saved: '..f)elseif e~='Cancelled'then printError(e)end elseif a[1]=='run'then local ok,e=M.run(a[2],a[3]);if not ok then printError(e)end elseif a[1]=='uninstall'then local ok,e=M.uninstall(a[2],a[3]);if not ok and e~='Cancelled'then printError(e)end else M.menu()end
]==],
  ["/spawnnet-release.lua"]=[==[os.run({},'/spawnnet/client/release_manager.lua')
]==],
  ["/spawnnet-server.lua"]=[==[shell.run('/spawnnet/server/startup.lua')
]==],
  ["/spawnnet-status.lua"]=[==[shell.run('/spawnnet/server/status.lua')
]==],
  ["/spawnnet.lua"]=[==[local a={...};shell.run('/spawnnet/client/spawnnet.lua',unpack(a))
]==],
  ["/spawnnet/client/account.lua"]=[==[local gui=dofile('/spawnnet/client/gui.lua')
local net=dofile('/spawnnet/client/net.lua')
local auth=dofile('/spawnnet/client/auth_client.lua')
local C=colors
local function login()
  local u=gui.prompt('SIGN IN','SpawnNet username:','');if u==''then return end
  local pw=gui.prompt('SIGN IN','Password:','','*');if pw==''then return end
  local s,e=auth.login(u,pw);gui.toast(s and('Signed in as '..tostring(s.user))or tostring(e),2,s~=nil)
end
local function register()
  local u=gui.prompt('CREATE ACCOUNT','Choose a username (3-24 letters/numbers):','');if u==''then return end
  local display=gui.prompt('CREATE ACCOUNT','Display name:',u);if display==''then display=u end
  local pw=gui.prompt('CREATE ACCOUNT','Choose a password (8+ characters):','','*');if pw==''then return end
  if #pw<8 then gui.toast('Use at least 8 characters.',2,false);return end
  local pw2=gui.prompt('CREATE ACCOUNT','Confirm password:','','*');if pw~=pw2 then gui.toast('Passwords do not match.',2,false);return end
  local code=gui.prompt('SECURE ENROLLMENT','Enrollment code from the Core administrator (blank for open networks):','')
  local s,e=auth.register(u,pw,display,code);if s then gui.clear();gui.bar('IDENTITY CREATED');gui.text(3,5,45,'Welcome to SpawnNet, '..tostring(s.user)..'.',C.lime,C.black);gui.text(3,7,45,'Encrypted session established.',C.cyan,C.black);gui.status('Press any key');os.pullEvent('key')else gui.toast(tostring(e),2,false)end
end
while true do
  local s=net.loadSession();local n=net.activeNetwork();local items={}
  if s then
    items={{label='[+] SIGNED IN  '..tostring(s.user),disabled=true},{label='Active devices / sessions',action='sessions'},{label='Switch account',action='switch'},{label='Sign out',action='logout'},{label='Revoke every session',action='revokeall'},{label='Back',action='back'}}
  else
    items={{label='SIGN IN',action='login'},{label='CREATE ACCOUNT',action='register'},{label='Back',action='back'}}
  end
  local m=gui.menu('SPAWNNET ACCOUNT','Network: '..tostring(n.name or n.id),items)
  if not m or m.action=='back'then break elseif m.action=='login'then login()elseif m.action=='register'then register()elseif m.action=='logout'then auth.logout();gui.toast('Signed out.',1)elseif m.action=='switch'then auth.logout();login()
  elseif m.action=='revokeall'then if gui.confirm('REVOKE ALL SESSIONS','Sign out every computer and API session for this account?')then auth.revokeAll();gui.toast('Every session revoked.',1,true)end
  elseif m.action=='sessions'then local p,e=auth.sessions();local lines={};if p then for _,x in ipairs(p.sessions or{})do lines[#lines+1]=(x.current and'[+] THIS DEVICE  'or'[ ] DEVICE      ')..'#'..tostring(x.computer)..'  '..tostring(x.id)..(x.apiKey and'  API'or'')end else lines[1]=tostring(e)end;gui.viewer('ACTIVE SESSIONS',table.concat(lines,'\n'),'SECURE IDENTITY')end
end
gui.clear()
]==],
  ["/spawnnet/client/api_explorer.lua"]=[==[local gui=dofile('/spawnnet/client/gui.lua')
local net=dofile('/spawnnet/client/net.lua')
local auth=dofile('/spawnnet/client/auth_client.lua')
local function ensureLogin()if net.loadSession()then return true end;local s,e=auth.ensureLogin();if not s then gui.toast(e,2);return false end;return true end
local presets={
 {label='Ping / auth',service='auth',action='ping',guest=true},
 {label='My profile',service='users',action='me'},
 {label='My domains',service='dns',action='listMine'},
 {label='Search',service='search',action='query',payload={q='SpawnNet'}},
 {label='Cluster summary',service='nodes',action='summary'},
}
while true do
  local items={};for _,x in ipairs(presets)do items[#items+1]=x end;items[#items+1]={label='Custom request',custom=true};items[#items+1]={label='Back',back=true}
  local m=gui.menu('API EXPLORER','Send live SpawnNet API requests.',items)
  if not m or m.back then break end
  local service,action,payload,guest=m.service,m.action,m.payload or{},m.guest
  if m.custom then
    service=gui.prompt('API EXPLORER','Service:','users')
    action=gui.prompt('API EXPLORER','Action:','me')
    local raw=gui.prompt('API EXPLORER','Payload table body (blank = {}):','')
    if raw~=''then local f,e=loadstring('return {'..raw..'}');if not f then gui.toast(e,2)else local ok,v=pcall(f);if ok and type(v)=='table'then payload=v else gui.toast(v,2)end end end
  end
  if not guest and not ensureLogin()then break end
  gui.clear();gui.bar(service..'.'..action);print('Request: '..textutils.serialize(payload));print()
  local p,e=net.call(service,action,payload,guest and{noAuth=true}or nil)
  if p then print(textutils.serialize(p))else printError(e)end
  gui.status('Press any key');os.pullEvent('key')
end
gui.clear()
]==],
  ["/spawnnet/client/app_runtime.lua"]=[==[-- SpawnNet native application capability runtime 2.3.0.
-- Hosted SpawnScript remains the safer default. Native packages execute here
-- with a deliberately small environment and explicit capability grants.
local M={}
local nativeFs=fs
local function has(rec,p)for _,x in ipairs(rec.permissions or{})do if x==p then return true end end;return false end
local function starts(s,p)return s==p or s:sub(1,#p+1)==p..'/'end
local function clean(path)
  path=tostring(path or''):gsub('\\','/');local out={}
  for part in path:gmatch('[^/]+')do if part=='..'then if #out==0 then return nil end;table.remove(out)elseif part~='.'and part~=''then out[#out+1]=part end end
  return'/'..table.concat(out,'/')
end
local function roots(rec)
  local d=tostring(rec.domain or''):gsub('[^%w_-]','-');local n=tostring(rec.name or''):gsub('[^%w_-]','-')
  return'/spawnnet/apps/'..d..'/'..n..'/app','/spawnnet/appdata/'..d..'/'..n,'/spawnnet/local/'..d..'.db'
end
local function nativeEnsure(p)if p==''or p=='/'or nativeFs.exists(p)then return end;local q=nativeFs.getDir(p);if q and q~=''then nativeEnsure(q)end;nativeFs.makeDir(p)end
local function scopedFs(rec)
  local app,data,localFile=roots(rec)
  nativeEnsure(data);nativeEnsure(nativeFs.getDir(localFile))
  local function resolve(p,write)
    p=tostring(p or'');if p:sub(1,1)~='/'then p=data..'/'..p end;p=clean(p);if not p then error('Unsafe path',3)end
    if starts(p,data)or p==localFile then return p end
    if not write and starts(p,app)then return p end
    error('SpawnNet sandbox denied filesystem path: '..p,3)
  end
  local F={}
  function F.combine(a,b)return nativeFs.combine(a,b)end
  function F.getName(p)return nativeFs.getName(p)end
  function F.getDir(p)return nativeFs.getDir(p)end
  function F.exists(p)return nativeFs.exists(resolve(p,false))end
  function F.isDir(p)return nativeFs.isDir(resolve(p,false))end
  function F.getSize(p)return nativeFs.getSize(resolve(p,false))end
  function F.getFreeSpace(p)return nativeFs.getFreeSpace(resolve(p,false))end
  function F.list(p)return nativeFs.list(resolve(p,false))end
  function F.makeDir(p)return nativeFs.makeDir(resolve(p,true))end
  function F.delete(p)return nativeFs.delete(resolve(p,true))end
  function F.move(a,b)return nativeFs.move(resolve(a,false),resolve(b,true))end
  function F.copy(a,b)return nativeFs.copy(resolve(a,false),resolve(b,true))end
  function F.open(p,mode)local write=mode and(mode:find('w',1,true)or mode:find('a',1,true));return nativeFs.open(resolve(p,write~=nil),mode)end
  function F.complete()return{}end
  return F,resolve,app,data
end
local function safeUtil(F)
  local U={}
  function U.trim(s)return(tostring(s or''):gsub('^%s+',''):gsub('%s+$',''))end
  function U.safeName(s,n)s=U.trim(s):lower():gsub('[^a-z0-9_-]','-'):gsub('%-+','-');return n and s:sub(1,n)or s end
  function U.deepcopy(v,seen)if type(v)~='table'then return v end;seen=seen or{};if seen[v]then return seen[v]end;local o={};seen[v]=o;for k,x in pairs(v)do o[U.deepcopy(k,seen)]=U.deepcopy(x,seen)end;return o end
  function U.clamp(v,a,b)return math.max(a,math.min(b,v))end
  function U.tablePathGet(root,path,default)local cur=root;for p in tostring(path or''):gmatch('[^%.]+')do if type(cur)~='table'then return default end;cur=cur[p]end;if cur==nil then return default end;return cur end
  function U.tablePathSet(root,path,value)local parts={};for p in tostring(path or''):gmatch('[^%.]+')do parts[#parts+1]=p end;local cur=root;for i=1,#parts-1 do if type(cur[parts[i]])~='table'then cur[parts[i]]={}end;cur=cur[parts[i]]end;if #parts>0 then cur[parts[#parts]]=value end end
  function U.loadTable(p,default)local h=F.open(p,'r');if not h then return default or{}end;local raw=h.readAll();h.close();local ok,v=pcall(textutils.unserialize,raw);return ok and type(v)=='table'and v or(default or{})end
  function U.saveTable(p,v)local h=assert(F.open(p,'w'));h.write(textutils.serialize(v));h.close()end
  function U.readFile(p)local h=F.open(p,'r');if not h then return nil end;local s=h.readAll();h.close();return s end
  function U.writeFile(p,v)local h=assert(F.open(p,'w'));h.write(tostring(v or''));h.close()end
  function U.ensureDir(p)if p and p~=''and not F.exists(p)then local q=F.getDir(p);if q and q~=''then U.ensureDir(q)end;F.makeDir(p)end end
  return U
end
local function makeEnv(rec,args)
  local F,resolve,app,data=scopedFs(rec);local env={}
  for _,name in ipairs({'assert','error','ipairs','next','pairs','pcall','select','tonumber','tostring','type','unpack','xpcall','print','printError','write','read','sleep'})do env[name]=_G[name]end
  env.math=math;env.string=string;env.table=table;env.bit32=_G.bit32;env.bit=_G.bit;env.colors=colors;env.colours=colours;env.keys=keys;env.term=term;env.textutils=textutils;env.paintutils=paintutils;env.parallel=parallel;env.window=window;env.fs=F
  env.os={clock=os.clock,time=os.time,day=os.day,epoch=os.epoch,getComputerID=os.getComputerID,getComputerLabel=os.getComputerLabel,startTimer=os.startTimer,cancelTimer=os.cancelTimer,queueEvent=os.queueEvent,pullEvent=os.pullEvent,pullEventRaw=os.pullEventRaw}
  if has(rec,'peripheral')or has(rec,'modem')then
    local P={};local function allowedName(n)local t=peripheral.getType(n);return has(rec,'peripheral')and(t~='modem'or has(rec,'modem'))or(has(rec,'modem')and t=='modem')end
    function P.getNames()local out={};for _,n in ipairs(peripheral.getNames())do if allowedName(n)then out[#out+1]=n end end;return out end
    function P.isPresent(n)return allowedName(n)and peripheral.isPresent(n)or false end
    function P.getType(n)if not allowedName(n)then return nil end;return peripheral.getType(n)end
    function P.getMethods(n)if not allowedName(n)then return nil end;return peripheral.getMethods(n)end
    function P.call(n,m,...)if not allowedName(n)then error('Peripheral capability denied: '..tostring(n),2)end;return peripheral.call(n,m,...)end
    function P.wrap(n)if not allowedName(n)then return nil end;return peripheral.wrap(n)end
    function P.find(t,filter)if t=='modem'and not has(rec,'modem')then return nil end;return peripheral.find(t,filter)end
    env.peripheral=P
  end
  env.rednet=has(rec,'rednet')and rednet or nil;env.http=has(rec,'http')and http or nil
  local function execute(path,...)
    path=clean(path);if not path or not starts(path,app)then return false,'Sandbox may only execute this application' end
    local h=F.open(path,'r');if not h then return false,'Program not found'end;local source=h.readAll();h.close();local fn,e=loadstring(source,'@'..path);if not fn then return false,e end;setfenv(fn,env);return pcall(fn,...)
  end
  env.os.run=function(_,path,...)local ok,a=execute(path,...);if not ok then return false,a end;return true end
  env.shell={run=function(path,...)
    local cp=clean(path);if cp and starts(cp,app)then local ok,e=execute(cp,...);if not ok then error(e,2)end;return true end
    if has(rec,'shell')and(cp=='/spawnnet/client/browser.lua'or cp=='/web.lua')then return shell.run(cp,...)end
    error('SpawnNet sandbox denied shell target',2)
  end}
  local safeU=safeUtil(F)
  env.dofile=function(path)
    local cp=clean(path);if cp and starts(cp,app)then local ok,value=execute(cp);if not ok then error(value,2)end;return value end
    if cp=='/spawnnet/client/gui.lua'then return dofile(cp)end
    if cp=='/spawnnet/lib/crypto.lua'then return dofile(cp)end
    if cp=='/spawnnet/lib/util.lua'then return safeU end
    if cp=='/spawnnet/client/net.lua'and has(rec,'rednet')then
      local n=dofile(cp);return{call=n.call,request=n.request,activeNetwork=function()local x=n.activeNetwork();return{id=x.id,name=x.name,visibility=x.visibility,coreId=x.coreId}end,loadSession=function()local s=n.loadSession();return s and{user=s.user,computer=s.computer,secure=s.secure}or nil end,getSession=function()local s=n.loadSession();return s and{user=s.user,computer=s.computer,secure=s.secure}or nil end}
    end
    if cp=='/spawnnet/client/sdk.lua'and has(rec,'rednet')then return dofile(cp)end
    error('SpawnNet sandbox denied module: '..tostring(path),2)
  end
  env._G=env;env.arg=args or{};return env,execute,data
end
function M.run(rec,path,...)
  if type(rec)~='table'then return false,'Missing application identity'end
  local args={...};local env,execute=makeEnv(rec,args);local ok,value=execute(path,unpack(args));if not ok then return false,value end;return true,value
end
return M
]==],
  ["/spawnnet/client/apps.lua"]=[==[local gui=dofile('/spawnnet/client/gui.lua')
local util=dofile('/spawnnet/lib/util.lua')
local net=dofile('/spawnnet/client/net.lua')
local path='/spawnnet/pins.db'
local pins=util.loadTable(path,{})
local function save()util.saveTable(path,pins)end
while true do
  local items={}
  for i,p in ipairs(pins)do items[#items+1]={label=tostring(p.name or p.url)..'  '..tostring(p.url),pin=i}end
  items[#items+1]={label='+ Pin a website',action='add'}
  items[#items+1]={label='Back',action='back'}
  local m=gui.menu('APPS & PINNED SITES','Websites can live on your SpawnNet desktop.',items,{right=net.activeNetwork().name})
  if not m or m.action=='back'then break
  elseif m.action=='add'then local url=gui.prompt('PIN WEBSITE','Address:','spn://');if url~=''then local name=gui.prompt('PIN WEBSITE','Name:',url:gsub('^spn://',''));pins[#pins+1]={name=name,url=url,network=net.activeNetwork().id};save()end
  elseif m.pin then local p=pins[m.pin];local action=gui.menu('PIN: '..tostring(p.name),p.url,{{label='Open',action='open'},{label='Remove',action='remove'},{label='Back',action='back'}});if action and action.action=='open'then if p.network and net.registry().networks[p.network]then net.setActiveNetwork(p.network)end;shell.run('/spawnnet/client/browser.lua',p.url)elseif action and action.action=='remove'then table.remove(pins,m.pin);save()end end
end
]==],
  ["/spawnnet/client/apps_chat.lua"]=[==[local net=dofile('/spawnnet/client/net.lua');local auth=dofile('/spawnnet/client/auth_client.lua');local ui=dofile('/spawnnet/client/ui.lua')
local sess=net.loadSession();if sess then local me=net.call('users','me',{});if not me then sess=nil end end;if not sess then local s,e=auth.ensureLogin();if not s then ui.error(e)return end end
local room=(...) or 'global'
while true do local p,e=net.call('chat','read',{room=room,limit=18});ui.clear('CHAT #'..room..'   /quit /room name /refresh');if p then for _,m in ipairs(p.messages)do print(('<%s> %s'):format(m.user,m.text))end else ui.error(e)end;term.setCursorPos(1,select(2,term.getSize()));term.clearLine();write('> ');local msg=read();if msg=='/quit'then break elseif msg:sub(1,6)=='/room 'then room=msg:sub(7)elseif msg~='/refresh'and msg~=''then net.call('chat','send',{room=room,text=msg})end end
ui.clear()
]==],
  ["/spawnnet/client/apps_forum.lua"]=[==[local gui=dofile('/spawnnet/client/gui.lua')
local net=dofile('/spawnnet/client/net.lua')
local function needLogin()if net.loadSession()then return true end;shell.run('/spawnnet/client/account.lua');return net.loadSession()~=nil end
local function threadView(board,t)
  while true do
    local p,e=net.call('forum','getThread',{board=board,id=t.id});if not p then gui.toast(tostring(e),2,false);return end;local th=p.thread;local body=tostring(th.author)..':\n'..tostring(th.body)..'\n\n'
    for i,r in ipairs(th.replies or{})do body=body..'--- Reply '..i..' by '..tostring(r.author)..' ---\n'..tostring(r.body)..'\n\n'end
    gui.viewer(th.title,body,board)
    local a=gui.menu('THREAD ACTIONS',tostring(#(th.replies or{}))..' replies',{{label='Reply',action='reply'},{label='Back',action='back'}})
    if not a or a.action=='back'then return elseif a.action=='reply'then local text=gui.multiline('REPLY - F2 TO POST','');if text and text~=''then local ok,er=net.call('forum','reply',{board=board,id=th.id,body=text});if not ok then gui.toast(tostring(er),2,false)end end end
  end
end
local function boardView(board,title)
  local search=''
  while true do
    local p,e=net.call('forum','threads',{board=board});if not p then gui.toast(tostring(e),2,false);return end;local items={}
    for _,t in ipairs(p.threads or{})do if search==''or tostring(t.title):lower():find(search:lower(),1,true)or tostring(t.author):lower():find(search:lower(),1,true)then items[#items+1]={label=tostring(t.title)..'  ['..tostring(t.author)..']  '..tostring(t.replies)..' replies',thread=t}end end
    items[#items+1]={label='+ New thread',action='new'};items[#items+1]={label='Search threads',action='search'};items[#items+1]={label='Back',action='back'}
    local a=gui.menu('FORUM / '..tostring(title or board),search~=''and('Search: '..search)or'Browse threads',items)
    if not a or a.action=='back'then return elseif a.thread then threadView(board,a.thread)elseif a.action=='search'then search=gui.prompt('SEARCH THREADS','Title or author:',search)elseif a.action=='new'then local tt=gui.prompt('NEW THREAD','Title:','');if tt~=''then local body=gui.multiline('NEW THREAD - F2 TO POST','');if body and body~=''then local ok,er=net.call('forum','newThread',{board=board,title=tt,body=body});if not ok then gui.toast(tostring(er),2,false)end end end end
  end
end
if not needLogin()then return end
while true do
  local p,e=net.call('forum','boards',{});if not p then gui.toast(tostring(e),2,false);return end;local items={};for _,b in ipairs(p.boards or{})do items[#items+1]={label=tostring(b.title)..'  ('..tostring(b.count or 0)..' threads)',board=b}end;items[#items+1]={label='Back',action='back'}
  local a=gui.menu('SPAWNNET FORUMS','Boards and threaded discussion',items);if not a or a.action=='back'then break elseif a.board then boardView(a.board.id,a.board.title)end
end
gui.clear()]==],
  ["/spawnnet/client/apps_keys.lua"]=[==[local net=dofile('/spawnnet/client/net.lua');local auth=dofile('/spawnnet/client/auth_client.lua');local ui=dofile('/spawnnet/client/ui.lua')
local sess=net.loadSession();if sess then local me=net.call('users','me',{});if not me then sess=nil end end;if not sess then local s,e=auth.ensureLogin();if not s then ui.error(e)return end end
while true do local p,e=net.call('auth','listKeys',{});ui.clear('API KEYS');if p then for i,k in ipairs(p.keys)do print(i..') '..k.label..' '..k.id..(k.revoked and' [REVOKED]'or''));print('   scopes: '..table.concat(k.scopes or {},','))end else ui.error(e)end;print();print('1 Create  2 Revoke  0 Back');local c=read();if c=='0'then break elseif c=='1'then local label=ui.prompt('Label','Machine key');local scopes=ui.prompt('Scopes comma-separated','telemetry.*');local ss={};for x in scopes:gmatch('[^,]+')do ss[#ss+1]=x:gsub('%s+','')end;local x,er=auth.createKey(label,ss);ui.clear('NEW API KEY');if x then print('ID:     '..x.id);print('SECRET: '..x.secret);print();print('This secret is shown ONCE. Save it in the machine config.')else ui.error(er)end;ui.pause()
elseif c=='2'then local n=tonumber(ui.prompt('Key #',''));local k=p and p.keys[n or 0];if k then net.call('auth','revokeKey',{id=k.id})end end end
ui.clear()
]==],
  ["/spawnnet/client/apps_mail.lua"]=[==[local gui=dofile('/spawnnet/client/gui.lua')
local net=dofile('/spawnnet/client/net.lua')
local auth=dofile('/spawnnet/client/auth_client.lua')
local C=colors
local function needLogin()if net.loadSession()then return true end;shell.run('/spawnnet/client/account.lua');return net.loadSession()~=nil end
local function compose(to,subject,body)
  to=to or gui.prompt('COMPOSE MAIL','To:','');if to==''then return end
  subject=subject or gui.prompt('COMPOSE MAIL','Subject:','');if subject==''then subject='(no subject)'end
  local text=gui.multiline('MAIL BODY - F2 TO SEND',body or'');if text==nil then return end
  local p,e=net.call('mail','send',{to=to,subject=subject,body=text});gui.toast(p and'Message sent.'or tostring(e),2,p~=nil)
end
local function readMessage(m,sent)
  local head=(sent and'To: 'or'From: ')..tostring(sent and m.to or m.from)..'\nTime: '..tostring(m.time or'')..'\n\n'..tostring(m.body or'')
  while true do
    gui.viewer(tostring(m.subject or'Message'),head,sent and'SENT'or'INBOX')
    local items={{label=sent and'Compose another message'or'Reply',action='reply'},{label='Delete',action='delete'},{label='Back',action='back'}}
    local a=gui.menu('MESSAGE ACTIONS',tostring(m.subject or''),items)
    if not a or a.action=='back'then return elseif a.action=='reply'then compose(sent and m.to or m.from,'Re: '..tostring(m.subject or''),'\n\n---\n'..tostring(m.body or''));return elseif a.action=='delete'then local svc=sent and'deleteSent'or'delete';net.call('mail',svc,{id=m.id});return end
  end
end
local function mailbox(sent)
  while true do
    local p,e=net.call('mail',sent and'sent'or'inbox',{limit=100});if not p then gui.toast(tostring(e),2,false);return end
    local list=sent and(p.messages or p.sent or{})or(p.messages or{});local items={}
    for _,m in ipairs(list)do local who=sent and m.to or m.from;items[#items+1]={label=(not sent and not m.read and'* 'or'  ')..tostring(who)..' - '..tostring(m.subject),msg=m}end
    items[#items+1]={label='Refresh',action='refresh'};items[#items+1]={label='Back',action='back'}
    local a=gui.menu(sent and'SENT MAIL'or'INBOX',#list..' message(s)',items)
    if not a or a.action=='back'then return elseif a.msg then if not sent and not a.msg.read then net.call('mail','read',{id=a.msg.id});a.msg.read=true end;readMessage(a.msg,sent)end
  end
end
if not needLogin()then return end
while true do
  local p=net.call('mail','unreadCount',{});local unread=p and p.count or 0
  local m=gui.menu('SPAWNNET MAIL',tostring(unread)..' unread',{{label='Inbox',action='inbox'},{label='Sent',action='sent'},{label='Compose',action='compose'},{label='Back',action='back'}})
  if not m or m.action=='back'then break elseif m.action=='inbox'then mailbox(false)elseif m.action=='sent'then mailbox(true)elseif m.action=='compose'then compose()end
end
gui.clear()]==],
  ["/spawnnet/client/auth_client.lua"]=[==[local util=dofile('/spawnnet/lib/util.lua')
local crypto=dofile('/spawnnet/lib/crypto.lua')
local net=dofile('/spawnnet/client/net.lua')
local config=dofile('/spawnnet/lib/config.lua')
local M={}
function M.verifier(username,password,salt,rounds,scheme)
  username=util.safeName(username,24)
  if scheme=='legacy-sha256'or tonumber(rounds)==1 then return crypto.sha256(username..':'..tostring(password or'')..':'..tostring(salt or''))end
  return crypto.passwordVerifier(username,password,salt,rounds or config.passwordRounds)
end
function M.register(username,password,displayName,enrollmentCode)
  username=util.safeName(username,24)
  if #tostring(password or'')<8 then return nil,'Password must be at least 8 characters'end
  local begin,e=net.call('auth','registerBegin',{username=username},{noAuth=true});if not begin then return nil,e end
  local verifier=M.verifier(username,password,begin.salt,begin.rounds,begin.scheme)
  local payload={username=username,displayName=displayName,nonce=begin.nonce,rounds=begin.rounds,scheme='iterated-sha256-v1',passwordLength=#password}
  if begin.ticketRequired then
    local code=tostring(enrollmentCode or''):gsub('%s',''):lower();if code==''then return nil,'A Core enrollment code is required'end
    payload.ticketId=begin.ticketIdHint and code:sub(1,8)or code:sub(1,8)
    payload.verifierBox=crypto.seal(crypto.sha256('SpawnNet-Enrollment\0'..code),verifier,username..'|'..begin.nonce)
  else payload.verifier=verifier end
  local p,e2=net.call('auth','register',payload,{noAuth=true}); if not p then return nil,e2 end
  return M.login(username,password)
end
function M.login(username,password)
  username=util.safeName(username,24); local begin,e=net.call('auth','begin',{username=username},{noAuth=true}); if not begin then return nil,e end
  local verifier=M.verifier(username,password,begin.salt or'',begin.rounds,begin.scheme); local cid=os.getComputerID(); local proof=crypto.hmac(verifier,begin.nonce..':'..tostring(cid))
  local done,e2=net.call('auth','login',{username=username,proof=proof},{noAuth=true}); if not done then return nil,e2 end
  local key=crypto.hmac(verifier,done.challenge..':'..done.serverNonce..':'..done.id)
  local session={id=done.id,user=done.user,key=key,seq=0,secure=true,computer=cid}; net.setSession(session)
  if begin.scheme=='legacy-sha256'then
    local salt=crypto.randomHex(16);local rounds=config.passwordRounds or 768;local upgraded=M.verifier(username,password,salt,rounds,'iterated-sha256-v1')
    net.call('auth','upgradeVerifier',{salt=salt,rounds=rounds,scheme='iterated-sha256-v1',verifier=upgraded})
  end
  return session
end
function M.createKey(label,scopes) return net.call('auth','createKey',{label=label,scopes=scopes or {'*'}}) end
function M.apiLogin(id,secret)
  local begin,e=net.call('auth','apiBegin',{id=id},{noAuth=true}); if not begin then return nil,e end
  local verifier=crypto.sha256(tostring(secret or '')); local proof=crypto.hmac(verifier,begin.nonce..':'..tostring(os.getComputerID()))
  local done,e2=net.call('auth','apiLogin',{id=id,proof=proof},{noAuth=true}); if not done then return nil,e2 end
  local key=crypto.hmac(verifier,done.challenge..':'..done.serverNonce..':'..done.id); local session={id=done.id,user=done.user,key=key,seq=0,apiKey=id,secure=true,computer=os.getComputerID()}; net.setSession(session); return session
end
function M.logout() local p,e=net.call('auth','logout',{}); net.setSession(nil); return p,e end
function M.sessions()return net.call('auth','listSessions',{})end
function M.revokeAll()local p,e=net.call('auth','revokeAll',{});net.setSession(nil);return p,e end
function M.ensureLogin()
  local s=net.loadSession(); if s then return s end
  write('SpawnNet username: '); local u=read(); write('Password: '); local pw=read('*'); local sess,e=M.login(u,pw); if not sess then return nil,e end; return sess
end
return M
]==],
  ["/spawnnet/client/browser.lua"]=[==[local util=dofile('/spawnnet/lib/util.lua')
local net=dofile('/spawnnet/client/net.lua')
local renderer=dofile('/spawnnet/client/renderer.lua')
local script=dofile('/spawnnet/lib/spawnscript.lua')
local config=dofile('/spawnnet/lib/config.lua')
local pkgmgr=dofile('/spawnnet/client/package_manager.lua') -- SPAWNNET_APP_PLATFORM_PM

local needsLoadEvent=false;local page=nil;local domain=nil;local path='/';local address=config.defaultHome;local scroll=0;local maxScroll=0;local inputs={};local values={};local hits={};local history={};local histPos=0;local clientScript='';local assetCache={};local status='';local liveTimer=nil

local function parseAddress(a)
  a=util.trim(a);if a==''then a=config.defaultHome end;if not util.startsWith(a,'spn://')then a='spn://'..a end
  local rest=a:sub(7);local slash=rest:find('/',1,true);local d,p;if slash then d=rest:sub(1,slash-1);p=rest:sub(slash)else d=rest;p='/'end
  d=util.safeName(d,32);if d==''then d='home'end;return d,p,'spn://'..d..p
end
local function collectDefaults(elements)
  local out={}
  local function walk(xs)
    for _,e in ipairs(xs or {})do
      if e.id then
        if e.type=='input'and e.value~=nil then out[e.id]=e.value
        elseif e.type=='select'then out[e.id]=e.value or(e.options and e.options[1])
        elseif e.type=='checkbox'then out[e.id]=e.checked and true or false end
      end
      if e.children then walk(e.children)end
      if e.tabs then for _,t in ipairs(e.tabs)do walk(t.children)end end
    end
  end
  walk(elements);return out
end
local function scheduleLive()
  liveTimer=nil
  local sec=page and tonumber(page.liveInterval)
  if sec and sec>=0.5 then liveTimer=os.startTimer(sec) end
end
local function loadAsset(name)
  name=tostring(name or ''):gsub('^/assets/','');if assetCache[name]then return assetCache[name]end
  local p=net.call('web','getAsset',{domain=domain,name=name},{noAuth=true});if p then assetCache[name]=p.data;return p.data end;return nil
end
local function errorPage(message)
  return {title='SpawnNet Error',background=colors.black,elements={{type='heading',x=2,y=2,w=47,text='PAGE COULD NOT LOAD',fg=colors.red},{type='text',x=3,y=5,w=45,h=6,text=tostring(message or 'Unknown network error')},{type='text',x=3,y=12,w=45,h=3,text='R retry  G address  H home  N networks',fg=colors.lightGray}}}
end
local function loadAddress(a,addHistory)
  local d,p,norm=parseAddress(a);status='Loading...';local data,e=net.call('web','getPage',{domain=d,path=p},{noAuth=true})
  domain,path,address=d,p,norm;assetCache={};scroll=0
  if not data then status='ERROR: '..tostring(e or'Load failed');page=errorPage(e);clientScript='';inputs={};values={};scheduleLive();return nil,e end
  page=data.page;clientScript=data.clientScript or'';inputs=collectDefaults(page.elements);values={}
  if addHistory~=false then while #history>histPos do table.remove(history)end;history[#history+1]=address;histPos=#history end
  status=data.title or d;needsLoadEvent=true;scheduleLive();return true
end
local function inputSnapshot()local t={};for k,v in pairs(inputs)do t[k]=v end;return t end
local runServerEvent
local function apiCall(method,args,vars)
  if method=='ui.setText'or method=='ui.setValue'or method=='ui.setVisible'then renderer.applyPatch(page,inputs,{method=method,args=args});return true
  elseif method=='ui.alert'then status=tostring(args[1]or'');return true
  elseif method=='ui.navigate'then loadAddress(tostring(args[1]or'home'),true);return true
  elseif method=='input.get'then return inputs[tostring(args[1]or'')]
  elseif method=='local.get'then local st=util.loadTable('/spawnnet/local/'..domain..'.db',{});return util.tablePathGet(st,tostring(args[1]or''),nil)
  elseif method=='local.set'then local f='/spawnnet/local/'..domain..'.db';local st=util.loadTable(f,{});util.tablePathSet(st,tostring(args[1]or''),args[2]);util.saveTable(f,st);return true
  elseif method=='server.run'then if runServerEvent then runServerEvent(tostring(args[1]or''),args[2]or{});return true end
  end
  local map={
    ['storage.get']={'storage','get'},['storage.set']={'storage','set'},['storage.inc']={'storage','inc'},
    ['db.get']={'db','get'},['db.set']={'db','set'},['db.insert']={'db','insert'},['db.list']={'db','list'},
    ['mail.send']={'mail','send'},['event.emit']={'event','emit'},['chat.read']={'chat','read'},['chat.send']={'chat','send'},
    ['telemetry.get']={'telemetry','get'},['telemetry.last']={'telemetry','get'},['search.query']={'search','query'},['jobs.status']={'jobs','status'}
  }
  local m=map[method];if not m then return nil,'Unknown client API '..tostring(method)end
  local payload={}
  if method:sub(1,7)=='storage'then payload={domain=domain,key=args[1],value=args[2],amount=args[2]}
  elseif method:sub(1,2)=='db'then payload={domain=domain,collection=args[1],key=args[2],value=args[3]};if method=='db.insert'then payload.value=args[2];payload.collection=args[1]elseif method=='db.list'then payload.limit=args[2]end
  elseif method=='mail.send'then payload={to=args[1],subject=args[2],body=args[3]}
  elseif method=='event.emit'then payload={to=args[1],type=args[2],data=args[3]}
  elseif method=='chat.read'then payload={room=args[1],limit=args[2]}elseif method=='chat.send'then payload={room=args[1],text=args[2]}
  elseif method=='telemetry.get'or method=='telemetry.last'then payload={domain=args[1]or domain,stream=args[2],limit=method=='telemetry.last'and 1 or args[3]}
  elseif method=='search.query'then payload={q=args[1]}
  elseif method=='jobs.status'then payload={domain=args[1]or domain,id=args[2]or args[1]} end
  local p,e=net.call(m[1],m[2],payload,{allowGuest=true});if not p then return nil,e end
  if method=='telemetry.last'then local pt=p.last;if not pt then return nil end;local d=util.deepcopy(pt.data or{});d._time=pt.time;d._computer=pt.computer;return d end
  return p.value or p.rows or p.messages or p.results or p
end
local function runClientEvent(name,args)
  local result,e=script.run(clientScript,name,{call=apiCall,log=function(msg)status=tostring(msg)end},{vars={input=inputSnapshot(),args=args or{},domain=domain},limit=config.maxScriptInstructions,maxRepeat=config.maxScriptRepeat});if not result then status='Script: '..tostring(e);return nil end;return result
end
runServerEvent=function(name,args)
  local p,e=net.call('web','runAction',{domain=domain,event=name,input=inputSnapshot(),args=args or{}},{allowGuest=true});if not p then status='Server action: '..tostring(e);return end
  for _,patch in ipairs(p.patches or{})do if patch.method=='ui.alert'then status=tostring((patch.args or{})[1]or'')elseif patch.method=='ui.navigate'then loadAddress(tostring((patch.args or{})[1]or'home'),true)else renderer.applyPatch(page,inputs,patch)end end
end
local function search()
  local _,sh=term.getSize();term.setCursorPos(1,sh);term.setBackgroundColor(colors.black);term.clearLine();write('Search: ');local q=read();local p,er=net.call('search','query',{q=q},{noAuth=true});if p then local elements={{type='heading',x=2,y=1,w=47,text='Search: '..q,align='left'}};local y=3;for _,r in ipairs(p.results or{})do elements[#elements+1]={type='button',x=2,y=y,w=47,text=(r.domain..' - '..r.title):sub(1,45),action={type='navigate',target='spn://'..r.domain}};y=y+2 end;page={title='Search',background=colors.black,elements=elements};domain='search';path='/results';address='spn://search?q='..q;clientScript='';inputs={};scroll=0;scheduleLive()else status=er end
end
local function pinCurrent()
  local pins=util.loadTable('/spawnnet/pins.db',{});for _,p in ipairs(pins)do if p.url==address and p.network==net.activeNetwork().id then status='Already pinned';return end end
  pins[#pins+1]={name=status~=''and status or domain,url=address,network=net.activeNetwork().id};util.saveTable('/spawnnet/pins.db',pins);status='Pinned to Apps'
end
local function handleAction(e)
  local a=e.action or{};if type(a)=='string'then a={type='navigate',target=a}end
  if a.type=='navigate'then local target=tostring(a.target or'/');if target:sub(1,1)=='/'then target='spn://'..domain..target end;loadAddress(target,true)
  elseif a.type=='event'then runClientEvent(a.event or a.name,e)
  elseif a.type=='server'then runServerEvent(a.event or a.name,e)
  elseif a.type=='install'then
    local ok,e=pkgmgr.installFromSite(domain,a.package or a.name or'',address)
    if not ok and e~='Cancelled'then status='Install: '..tostring(e)end
  elseif a.type=='download'then
    local f,e=pkgmgr.downloadFromSite(domain,a.package or a.name or'',address)
    if f then status='Downloaded: '..tostring(f)elseif e~='Cancelled'then status='Download: '..tostring(e)end
  elseif a.type=='search'then search()end
  -- A synchronous action may overlap the current Browser timer. Re-arm it so
  -- filters and other live controls cannot strand the page until refresh.
  scheduleLive()
end
local function draw()
  local sw,sh=term.getSize();local n=net.activeNetwork();term.setBackgroundColor(colors.purple);term.setTextColor(colors.white);term.setCursorPos(1,1);term.clearLine();write(('< > R H G S P N  // '..tostring(n.name or n.id)):sub(1,sw))
  term.setCursorPos(1,2);term.setBackgroundColor(colors.gray);term.setTextColor(colors.cyan);term.clearLine();write((' SN:// '..address:sub(7)..'  :: '..tostring(status or'')):sub(1,sw));term.setBackgroundColor(colors.black);term.setTextColor(colors.white)
  if page then hits,maxScroll=renderer.draw(page,{top=3,bottom=sh,scroll=scroll,inputs=inputs,values=values,assetLoader=loadAsset})else for y=3,sh do term.setCursorPos(1,y);term.clearLine()end end
end
local start=(...);if type(start)~='string'then start=config.defaultHome end
loadAddress(start,true)
while true do
  if needsLoadEvent then needsLoadEvent=false;runClientEvent('load',{})end
  draw();local ev={os.pullEvent()};local name=ev[1]
  if name=='timer'and liveTimer and ev[2]==liveTimer then
    liveTimer=nil;if page then if page.liveServerEvent then runServerEvent(page.liveServerEvent,{})end;runClientEvent('tick',{})end;scheduleLive()
  elseif name=='mouse_scroll'then scroll=util.clamp(scroll+ev[2],0,maxScroll)
  elseif name=='mouse_click'then
    local x,y=ev[3],ev[4]
    if y==1 then
      if x<=2 and histPos>1 then histPos=histPos-1;loadAddress(history[histPos],false)
      elseif x<=4 and histPos<#history then histPos=histPos+1;loadAddress(history[histPos],false)
      elseif x<=6 then loadAddress(address,false)
      elseif x<=8 then loadAddress(config.defaultHome,true)
      elseif x<=10 then local _,sh=term.getSize();term.setCursorPos(1,sh);term.clearLine();write('Address: ');loadAddress(read(),true)
      elseif x<=12 then search()
      elseif x<=14 then pinCurrent()
      elseif x<=16 then shell.run('/spawnnet/client/networks.lua');loadAddress(config.defaultHome,true) end
    elseif y==2 then term.setCursorPos(1,2);term.setBackgroundColor(colors.lightGray);term.setTextColor(colors.black);term.clearLine();write(' ');loadAddress(read(),true)
    else local h=renderer.hit(hits,x,y);if h then local e=h.element;if h.kind=='button'then handleAction(e)elseif h.kind=='input'then term.setCursorPos(1,select(2,term.getSize()));term.setBackgroundColor(colors.black);term.clearLine();write((e.label or e.id or'Input')..': ');inputs[e.id]=read()elseif h.kind=='checkbox'then inputs[e.id]=not(inputs[e.id]==nil and e.checked or inputs[e.id])elseif h.kind=='select'then local opts=e.options or{};local cur=inputs[e.id]or e.value or opts[1];local idx=1;for i,v in ipairs(opts)do if v==cur then idx=i end end;if #opts>0 then inputs[e.id]=opts[(idx%#opts)+1]end elseif h.kind=='tab'then e.selected=h.tab end end end
  elseif name=='key'then local k=ev[2];if k==keys.q then break elseif k==keys.up then scroll=math.max(0,scroll-1)elseif k==keys.down then scroll=math.min(maxScroll,scroll+1)elseif k==keys.r then loadAddress(address,false)elseif k==keys.h then loadAddress(config.defaultHome,true)elseif k==keys.g then local _,sh=term.getSize();term.setCursorPos(1,sh);term.clearLine();write('Address: ');loadAddress(read(),true)elseif k==keys.s then search()elseif k==keys.p then pinCurrent()elseif k==keys.n then shell.run('/spawnnet/client/networks.lua');loadAddress(config.defaultHome,true)end
  end
  -- Network calls may overlap the current timer. Always establish a fresh
  -- Browser-owned timer after an action so live pages cannot silently stall.
  scheduleLive()
end
term.setBackgroundColor(colors.black);term.setTextColor(colors.white);term.clear();term.setCursorPos(1,1)
]==],
  ["/spawnnet/client/desktop.lua"]=[==[local gui=dofile('/spawnnet/client/gui.lua')
local net=dofile('/spawnnet/client/net.lua')
local config=dofile('/spawnnet/lib/config.lua')
local C=colors
local function run(path,...)shell.run(path,...)end
local function validSession()
  local s=net.loadSession();if not s then return nil end
  local me=net.call('users','me',{});if not me then net.setSession(nil);return nil end
  return s
end
while true do
  local s=validSession();local n=net.activeNetwork();local w,h=term.getSize();gui.clear();gui.bar('NEXUS DESKTOP '..config.version,'CORE // '..tostring(n.name or n.id))
  local regions={};local y0
  if not s then
    gui.text(3,3,w-5,'GUEST LINK // RESTRICTED',C.orange,C.black)
    gui.text(3,4,w-5,'Establish an identity to unlock encrypted services and native apps.',C.lightGray,C.black)
    local half=math.floor((w-7)/2);local a=gui.button(3,6,half,'AUTHENTICATE',true,C.blue);a.action='account';regions[#regions+1]=a;local b=gui.button(5+half,6,w-half-7,'CREATE IDENTITY',true,C.purple);b.action='account';regions[#regions+1]=b;y0=9
  else
    gui.text(3,3,w-5,'IDENTITY // '..tostring(s.user):upper()..'   SECURE CHANNEL // ACTIVE',C.lime,C.black)
    gui.text(3,4,w-5,'Nexus ready. Select a system.',C.lightGray,C.black)
    y0=7
  end
  local apps={
    {title='BROWSER',sub='Traverse SpawnNet',path='/spawnnet/client/browser.lua',arg='spn://home',bg=C.blue},
    {title='COMMS',sub='Mail / messages',path='/spawnnet/client/apps_mail.lua',bg=C.cyan},
    {title='SEARCH',sub='Index the network',special='search',bg=C.blue},
    {title='FORGE',sub='Build websites',path='/spawnnet/client/studio_easy.lua',bg=C.purple},
    {title='NETWORKS',sub='Cores / intranets',path='/spawnnet/client/networks.lua',bg=C.gray},
    {title='FAVORITES',sub='Pinned destinations',path='/spawnnet/client/apps.lua',bg=C.blue},
    {title='LABS',sub='Interactive systems',path='/spawnnet/client/labs.lua',bg=C.orange},
    {title='DEVELOPER',sub='SDK / API / debug',path='/spawnnet/client/developer.lua',bg=C.gray},
    {title='SOFTWARE',sub='Native applications',path='/spawnnet-packages.lua',bg=C.green},
    {title='HARDWARE',sub='Peripheral systems',path='/spawnnet/client/machines.lua',bg=C.cyan},
    {title='IDENTITY',sub=s and tostring(s.user)or'Login / register',path='/spawnnet/client/account.lua',bg=C.gray},
    {title='CONTROL',sub='Settings / security',path='/spawnnet/client/settings.lua',bg=C.purple},
  }
  local cols=3;local gap=2;local left=2;local bw=math.floor((w-left-1-gap*(cols-1))/cols);local tileH=3;local rows=4
  if h<26 then tileH=2 end
  for i,a in ipairs(apps)do local col=(i-1)%cols;local row=math.floor((i-1)/cols);local x=left+col*(bw+gap);local y=y0+row*(tileH+1);local r=gui.tile(x,y,bw,tileH,a.title,tileH>=3 and a.sub or'',a.bg,true);r.app=i;regions[#regions+1]=r end
  gui.status('CLICK engage system   Q exit to CraftOS')
  local ev={os.pullEvent()}
  if ev[1]=='key'and ev[2]==keys.q then break
  elseif ev[1]=='mouse_click'then local r=gui.hit(regions,ev[3],ev[4]);if r then
    if r.action=='account'then run('/spawnnet/client/account.lua')elseif r.app then local a=apps[r.app];if a.special=='search'then local q=gui.prompt('SEARCH','Search SpawnNet:','');if q~=''then run('/spawnnet/client/search.lua',q)end else run(a.path,a.arg)end end
  end end
end
gui.clear()
]==],
  ["/spawnnet/client/developer.lua"]=[==[local gui=dofile('/spawnnet/client/gui.lua')
while true do
 local m=gui.menu('DEVELOPER WORKBENCH','Build, inspect and test without memorizing commands.',{
  {label='Advanced Studio',path='/spawnnet/client/studio_advanced.lua'},
  {label='API Explorer',path='/spawnnet/client/api_explorer.lua'},
  {label='API Credentials',path='/spawnnet/client/apps_keys.lua'},
  {label='Peripheral Lab',path='/spawnnet/client/peripheral_lab.lua'},
  {label='Network Lab',path='/spawnnet/client/network_lab.lua'},
  {label='Diagnostics',path='/spawnnet/client/doctor.lua'},
  {label='Installed Packages',path='/spawnnet-packages.lua'},
  {label='Lua Shell',shell=true},
  {label='Back',back=true},
 })
 if not m or m.back then break
 elseif m.shell then shell.run('shell')
 else shell.run(m.path)end
end
gui.clear()
]==],
  ["/spawnnet/client/doctor.lua"]=[==[local config=dofile('/spawnnet/lib/config.lua');local net=dofile('/spawnnet/client/net.lua');local ui=dofile('/spawnnet/client/ui.lua')
ui.clear('SPAWNNET DOCTOR '..config.version)
local n=net.activeNetwork();print('Network: '..tostring(n.name)..' ['..tostring(n.id)..']')
print('Visibility: '..tostring(n.visibility or '?'))
local modem,e=net.open();print('Modem: '..(modem or('FAIL '..tostring(e))))
local id,er=net.discover(true);print('Core: '..(id and('#'..id)or('FAIL '..tostring(er))))
if id then local p,x=net.call('auth','ping',{}, {noAuth=true});print('Ping: '..(p and('OK server '..tostring(p.version))or('FAIL '..tostring(x))))end
local s=net.loadSession();print('Session: '..(s and('user '..s.user)or'not logged in'))
print('Protocol: '..tostring((net.activeNetwork()).protocol or net.protocolFor(n.id)))
print('Discovery: '..config.discoveryProtocol)
print('Computer ID: '..os.getComputerID())
print();print('N opens Network Manager. Multiple SpawnNet cores can coexist safely in v2.');ui.pause()
]==],
  ["/spawnnet/client/gui.lua"]=[==[local M={}
local C=colors
local T=dofile('/spawnnet/client/theme.lua')
local function clamp(v,a,b)if v<a then return a elseif v>b then return b else return v end end
local function trimTo(s,n)
  s=tostring(s or'');n=math.max(0,tonumber(n)or 0)
  if #s<=n then return s end
  if n<=3 then return s:sub(1,n)end
  return s:sub(1,n-3)..'...'
end
local function wrap(s,w)
  s=tostring(s or'');w=math.max(1,tonumber(w)or 1);local out={}
  for raw in (s..'\n'):gmatch('(.-)\n')do
    if raw==''then out[#out+1]=''else
      local line=raw
      while #line>w do
        local cut=w;local p=line:sub(1,w):match('^.*()%s')
        if p and p>1 then cut=p end
        out[#out+1]=line:sub(1,cut):gsub('%s+$','')
        line=line:sub(cut+1):gsub('^%s+','')
      end
      out[#out+1]=line
    end
  end
  if #out>1 and out[#out]==''then table.remove(out)end
  return out
end
M.wrap=wrap
function M.clear(bg)term.setBackgroundColor(bg or T.void);term.setTextColor(T.ink);term.clear();term.setCursorPos(1,1)end
function M.text(x,y,w,text,fg,bg,align)
  local sw,sh=term.getSize();x=math.floor(tonumber(x)or 1);y=math.floor(tonumber(y)or 1);w=math.floor(tonumber(w)or #tostring(text or''))
  if y<1 or y>sh or x>sw or w<=0 then return end
  x=math.max(1,x);w=math.min(w,sw-x+1);if w<=0 then return end
  local s=trimTo(text,w)
  if align=='center'then s=string.rep(' ',math.max(0,math.floor((w-#s)/2)))..s elseif align=='right'then s=string.rep(' ',math.max(0,w-#s))..s end
  s=s..string.rep(' ',math.max(0,w-#s))
  term.setCursorPos(x,y);term.setTextColor(fg or C.white);term.setBackgroundColor(bg or C.black);write(s:sub(1,w))
end
function M.wrapped(x,y,w,h,text,fg,bg)
  local lines=wrap(text,w);for i=1,math.min(#lines,h or #lines)do M.text(x,y+i-1,w,lines[i],fg,bg)end;return #lines
end
function M.bar(title,right)
  local w=select(1,term.getSize());M.text(1,1,w,'',T.ink,T.chrome)
  local rs=right and tostring(right)or'';local rw=math.min(#rs,math.max(0,math.floor(w*.48)));local lw=math.max(1,w-rw-4)
  local name=tostring(title or'SPAWNNET');if not name:find('SN//',1,true)then name='SN// '..name end
  M.text(2,1,lw,name,T.ink,T.chrome)
  if rw>0 then M.text(w-rw,1,rw,rs,T.muted,T.chrome,'right')end
end
function M.status(text,good)
  local w,h=term.getSize();M.text(1,h,w,' :: '..tostring(text or''),good==false and T.danger or T.muted,T.panel)
end
function M.button(x,y,w,label,enabled,bg)
  local b=enabled==false and T.dim or(bg or T.hot);local fg=enabled==false and T.muted or T.ink
  M.text(x,y,w,'[ '..tostring(label or'')..' ]',fg,b,'center');return{x1=x,y1=y,x2=x+w-1,y2=y,label=label,enabled=enabled~=false}
end
function M.tile(x,y,w,h,title,subtitle,bg,enabled)
  h=math.max(2,h or 3);local b=enabled==false and T.dim or(bg or T.hot);local fg=enabled==false and T.muted or T.ink
  M.text(x,y,w,'// '..tostring(title or''),fg,b)
  for yy=y+1,y+h-1 do M.text(x,yy,w,'',fg,T.panel)end
  if h>=3 and subtitle and subtitle~=''then M.text(x+2,y+1,w-3,subtitle,T.muted,T.panel)end
  M.text(x,y+h-1,w,' '..string.rep('-',math.max(0,w-2)),b,T.void)
  return{x1=x,y1=y,x2=x+w-1,y2=y+h-1,enabled=enabled~=false}
end
function M.box(x,y,w,h,title,bg)
  bg=bg or T.void;if w<2 or h<2 then return end
  M.text(x,y,w,'+'..string.rep('-',math.max(0,w-2))..'+',T.accent,bg);for yy=y+1,y+h-2 do M.text(x,yy,w,'|'..string.rep(' ',math.max(0,w-2))..'|',T.dim,bg)end;M.text(x,y+h-1,w,'+'..string.rep('-',math.max(0,w-2))..'+',T.dim,bg)
  if title then M.text(x+2,y,math.min(w-4,#tostring(title)+3),' '..tostring(title)..' ',T.ink,T.chrome)end
end
function M.hit(regions,x,y)for i=#regions,1,-1 do local r=regions[i];if r.enabled~=false and x>=r.x1 and x<=r.x2 and y>=r.y1 and y<=r.y2 then return r end end end
local function editLine(x,y,w,default,mask)
  local value=tostring(default or'');local pos=#value+1
  local function draw()
    local shown=mask and string.rep(mask,#value)or value;local start=1
    if pos>w then start=pos-w end
    local view=shown:sub(start,start+w-1);M.text(x,y,w,view,C.black,C.lightGray)
    local cx=clamp(x+(pos-start),x,x+w-1);term.setCursorPos(cx,y);term.setCursorBlink(true)
  end
  draw()
  while true do
    local ev={os.pullEvent()};local name=ev[1]
    if name=='char'then local ch=ev[2];value=value:sub(1,pos-1)..ch..value:sub(pos);pos=pos+#ch;draw()
    elseif name=='paste'then local ch=tostring(ev[2]or'');value=value:sub(1,pos-1)..ch..value:sub(pos);pos=pos+#ch;draw()
    elseif name=='key'then local k=ev[2]
      if k==keys.enter then term.setCursorBlink(false);return value
      elseif k==keys.escape then term.setCursorBlink(false);return nil
      elseif k==keys.backspace and pos>1 then value=value:sub(1,pos-2)..value:sub(pos);pos=pos-1;draw()
      elseif k==keys.delete and pos<=#value then value=value:sub(1,pos-1)..value:sub(pos+1);draw()
      elseif k==keys.left then pos=math.max(1,pos-1);draw()
      elseif k==keys.right then pos=math.min(#value+1,pos+1);draw()
      elseif k==keys.home then pos=1;draw()
      elseif k==keys['end'] then pos=#value+1;draw()end
    end
  end
end
function M.prompt(title,label,default,mask)
  local w=select(1,term.getSize());M.clear();M.bar(title or'INPUT','SECURE CONSOLE');M.box(2,3,w-2,7,'INPUT');M.wrapped(4,5,w-7,2,label or'',T.ink,T.void);M.text(4,8,w-7,'',C.black,T.field)
  local v=editLine(5,8,w-9,default,mask);term.setBackgroundColor(T.void);term.setTextColor(T.ink)
  return v==nil and''or v
end
function M.confirm(title,message)
  local w=select(1,term.getSize());M.clear();M.bar(title or'CONFIRM','AUTHORIZATION REQUIRED');M.box(2,3,w-2,14,'DECISION GATE');M.wrapped(4,5,w-7,9,message,T.ink,T.void);M.text(4,15,w-7,'[Y] AUTHORIZE     [N] ABORT',T.warning,T.void)
  while true do local e,k=os.pullEvent('key');if k==keys.y or k==keys.enter then return true elseif k==keys.n or k==keys.q or k==keys.escape then return false end end
end
function M.menu(title,subtitle,items,opts)
  opts=opts or{};local selected=1;items=items or{}
  while true do
    local w,h=term.getSize();M.clear(opts.bg or C.black);M.bar(title,opts.right)
    if subtitle then M.text(3,3,w-5,subtitle,C.lightGray,C.black,'center')end
    local start=opts.startY or 5;local visible=math.max(1,h-start-1);if #items==0 then M.text(3,start,w-5,'Nothing here yet.',C.lightGray,C.black);M.status('Q back');local _,k=os.pullEvent('key');if k==keys.q or k==keys.backspace or k==keys.escape then return nil end else
      selected=clamp(selected,1,#items);local first=math.max(1,math.min(selected-math.floor(visible/2),math.max(1,#items-visible+1)));local regions={}
      for row=0,visible-1 do local i=first+row;if i>#items then break end;local it=items[i];local sel=i==selected;local bg=sel and T.hot or T.void;local fg=it.disabled and T.dim or(sel and T.ink or T.muted);M.text(2,start+row,w-2,(sel and' >> 'or'    ')..tostring(it.label or it.id or i),fg,bg);if sel then M.text(1,start+row,1,' ',T.ink,T.accent)end;regions[#regions+1]={x1=1,y1=start+row,x2=w,y2=start+row,index=i,enabled=not it.disabled}end
      M.status(opts.footer or'Up/Down select   Enter open   Q back')
      local ev={os.pullEvent()};if ev[1]=='key'then local k=ev[2];if k==keys.up then selected=math.max(1,selected-1)elseif k==keys.down then selected=math.min(#items,selected+1)elseif k==keys.pageUp then selected=math.max(1,selected-visible)elseif k==keys.pageDown then selected=math.min(#items,selected+visible)elseif k==keys.home then selected=1 elseif k==keys['end']then selected=#items elseif k==keys.enter and not items[selected].disabled then return items[selected],selected elseif k==keys.q or k==keys.backspace or k==keys.escape then return nil end
      elseif ev[1]=='mouse_scroll'then selected=clamp(selected+ev[2],1,#items)
      elseif ev[1]=='mouse_click'then local r=M.hit(regions,ev[3],ev[4]);if r then selected=r.index;return items[selected],selected end end
    end
  end
end
function M.toast(message,seconds,good)
  local w,h=term.getSize();M.text(2,h-2,w-2,' '..tostring(message)..' ',C.black,good==false and C.red or C.yellow,'center');sleep(seconds or 1)
end
function M.viewer(title,text,meta)
  local lines={};for _,raw in ipairs(wrap(text,math.max(10,select(1,term.getSize())-4)))do lines[#lines+1]=raw end;local scroll=0
  while true do local w,h=term.getSize();local body=math.max(1,h-6);scroll=clamp(scroll,0,math.max(0,#lines-body));M.clear();M.bar(title,meta);for i=1,body do local line=lines[scroll+i];if not line then break end;M.text(3,3+i,w-5,line,C.white,C.black)end;M.status('Up/Down/Page scroll   Q back   '..tostring(scroll+1)..'/'..math.max(1,#lines));local ev={os.pullEvent()};if ev[1]=='key'then local k=ev[2];if k==keys.q or k==keys.backspace or k==keys.escape then return elseif k==keys.up then scroll=scroll-1 elseif k==keys.down then scroll=scroll+1 elseif k==keys.pageUp then scroll=scroll-body elseif k==keys.pageDown then scroll=scroll+body elseif k==keys.home then scroll=0 elseif k==keys['end']then scroll=#lines-body end elseif ev[1]=='mouse_scroll'then scroll=scroll+ev[2]end end
end
function M.multiline(title,initial)
  local lines={};local src=tostring(initial or'');for line in (src..'\n'):gmatch('(.-)\n')do lines[#lines+1]=line end;if #lines==0 then lines={''}end
  local row,col=1,#lines[1]+1;local top=1
  while true do
    local w,h=term.getSize();local body=math.max(3,h-5);if row<top then top=row elseif row>=top+body then top=row-body+1 end
    M.clear();M.bar(title or'EDITOR','F2 SAVE');for i=0,body-1 do local n=top+i;if n>#lines then break end;M.text(2,3+i,3,tostring(n),C.gray,C.black,'right');M.text(6,3+i,w-6,lines[n],n==row and C.white or C.lightGray,n==row and C.gray or C.black)end;M.status('F2 save   Esc cancel   Enter new line')
    term.setCursorPos(clamp(5+col,6,w),3+row-top);term.setCursorBlink(true)
    local ev={os.pullEvent()};if ev[1]=='char'then local ch=ev[2];local s=lines[row];lines[row]=s:sub(1,col-1)..ch..s:sub(col);col=col+#ch
    elseif ev[1]=='paste'then local ch=tostring(ev[2]or'');local s=lines[row];lines[row]=s:sub(1,col-1)..ch..s:sub(col);col=col+#ch
    elseif ev[1]=='key'then local k=ev[2]
      if k==keys.f2 then term.setCursorBlink(false);return table.concat(lines,'\n')
      elseif k==keys.escape then term.setCursorBlink(false);return nil
      elseif k==keys.enter then local s=lines[row];local rest=s:sub(col);lines[row]=s:sub(1,col-1);table.insert(lines,row+1,rest);row=row+1;col=1
      elseif k==keys.backspace then if col>1 then local s=lines[row];lines[row]=s:sub(1,col-2)..s:sub(col);col=col-1 elseif row>1 then local prev=#lines[row-1]+1;lines[row-1]=lines[row-1]..lines[row];table.remove(lines,row);row=row-1;col=prev end
      elseif k==keys.delete then local s=lines[row];if col<=#s then lines[row]=s:sub(1,col-1)..s:sub(col+1)elseif row<#lines then lines[row]=s..lines[row+1];table.remove(lines,row+1)end
      elseif k==keys.left then if col>1 then col=col-1 elseif row>1 then row=row-1;col=#lines[row]+1 end
      elseif k==keys.right then if col<=#lines[row]then col=col+1 elseif row<#lines then row=row+1;col=1 end
      elseif k==keys.up then row=math.max(1,row-1);col=math.min(col,#lines[row]+1)
      elseif k==keys.down then row=math.min(#lines,row+1);col=math.min(col,#lines[row]+1)
      elseif k==keys.home then col=1 elseif k==keys['end']then col=#lines[row]+1 end
    end
  end
end
return M
]==],
  ["/spawnnet/client/labs.lua"]=[==[local gui=dofile('/spawnnet/client/gui.lua')
local net=dofile('/spawnnet/client/net.lua')
local util=dofile('/spawnnet/lib/util.lua')
local C=colors

local function signalBreaker()
  local score=0;local target=math.random(1,9);local untilTime=os.clock()+20
  while os.clock()<untilTime do
    gui.clear();gui.bar('LAB 01 - SIGNAL BREAKER','Score '..score)
    gui.text(2,3,47,'Hit the highlighted pad before time expires.',C.lightGray)
    local regs={};local i=0
    for r=0,2 do for c=0,2 do i=i+1;local x=4+c*15;local y=7+r*4
      local bg=i==target and C.lime or C.gray;gui.text(x,y,12,'['..i..']',i==target and C.black or C.white,bg,'center')
      regs[#regs+1]={x1=x,y1=y,x2=x+11,y2=y,index=i}
    end end
    gui.status('Mouse or 1-9   Q exits')
    local timer=os.startTimer(.5);local ev={os.pullEvent()}
    if ev[1]=='mouse_click'then local h=gui.hit(regs,ev[3],ev[4]);if h and h.index==target then score=score+1;target=math.random(1,9)end
    elseif ev[1]=='key'then if ev[2]==keys.q then break end;local n=ev[2]-keys.one+1;if n>=1 and n<=9 and n==target then score=score+1;target=math.random(1,9)end end
  end
  gui.clear();gui.bar('SIGNAL BREAKER COMPLETE');print('Score: '..score);gui.status('Press any key');os.pullEvent('key')
end

local function peripheralXray()shell.run('/spawnnet/client/peripheral_lab.lua')end
local function storageCluster()shell.run('/spawnnet/client/nodes.lua')end
local function networkLab()shell.run('/spawnnet/client/network_lab.lua')end
local function chestPulse()
  gui.clear();gui.bar('LAB 04 - CHEST PULSE')
  local inv={}
  for _,n in ipairs(peripheral.getNames())do local ok=pcall(peripheral.call,n,'list');if ok then inv[#inv+1]=n end end
  print('Inventory peripherals detected: '..#inv);for _,n in ipairs(inv)do print('  '..n)end
  print();print('This lab is deliberately local and temporary.')
  print('Use Peripheral Lab to inspect list/pushItems methods.')
  gui.status('Press any key');os.pullEvent('key')
end
while true do
  local m=gui.menu('SPAWNNET LABS','Escalating demos: zero setup to real hardware.',{
    {label='01 Signal Breaker - zero setup game',action='signal'},
    {label='02 Shared Grid - hosted persistence',url='spn://wiki/labs/grid'},
    {label='03 Mail Heist - SpawnNet identity/mail',url='spn://wiki/labs/mail'},
    {label='04 Chest Pulse - inventory hardware',action='chest'},
    {label='05 Peripheral X-Ray',action='px'},
    {label='06 Storage Cluster',action='cluster'},
    {label='07 Private Intranet / Network Lab',action='net'},
    {label='Back',back=true},
  })
  if not m or m.back then break
  elseif m.action=='signal'then signalBreaker()
  elseif m.action=='chest'then chestPulse()
  elseif m.action=='px'then peripheralXray()
  elseif m.action=='cluster'then storageCluster()
  elseif m.action=='net'then networkLab()
  elseif m.url then shell.run('/spawnnet/client/browser.lua',m.url)end
end
gui.clear()
]==],
  ["/spawnnet/client/machines.lua"]=[==[local gui=dofile('/spawnnet/client/gui.lua')
while true do
  local m=gui.menu('PERIPHERALS & AUTOMATION','SpawnNet provides the tools. Installed apps decide what your machines do.',{
    {label='Peripheral Lab - inspect attached hardware',path='/spawnnet/client/peripheral_lab.lua'},
    {label='Network Lab - inspect SpawnNet transport',path='/spawnnet/client/network_lab.lua'},
    {label='API Credentials - keys and scopes',path='/spawnnet/client/apps_keys.lua'},
    {label='Telemetry Publisher - generic sensor feed',path='/spawnnet/client/telemetry_agent.lua'},
    {label='API Explorer - jobs / telemetry / storage',path='/spawnnet/client/api_explorer.lua'},
    {label='Installed Applications',path='/spawnnet-packages.lua'},
    {label='Back',back=true},
  })
  if not m or m.back then break else shell.run(m.path)end
end
gui.clear()]==],
  ["/spawnnet/client/net.lua"]=[==[local config=dofile('/spawnnet/lib/config.lua')
local util=dofile('/spawnnet/lib/util.lua')
local crypto=dofile('/spawnnet/lib/crypto.lua')
local packet=dofile('/spawnnet/lib/packet.lua')
local wire=dofile('/spawnnet/lib/wire.lua')
local M={_inbox={},_session=nil,_fragments={},_ws=nil}

local cfg=util.loadTable(config.clientConfig,{transport='rednet',modem=nil,timeout=config.requestTimeout,wsUrl=nil})
local registry=util.loadTable(config.networkRegistry,{active='public',networks={}})
registry.networks=registry.networks or {}
if not registry.active then registry.active='public' end
if not registry.networks.public then
  registry.networks.public={id='public',name='Public SpawnNet',visibility='public'}
end

local function protocolFor(id) return config.protocolPrefix..tostring(id)..':v2' end
local function backboneFor(id) return config.backbonePrefix..tostring(id)..':v2' end
local function sessionPath(id) return '/spawnnet/sessions/'..util.safeName(id,32)..'.db' end
local function saveRegistry() util.saveTable(config.networkRegistry,registry) end

local function findModem()
  if cfg.modem and peripheral.isPresent(cfg.modem) and peripheral.getType(cfg.modem)=='modem' then return cfg.modem end
  for _,name in ipairs(peripheral.getNames()) do if peripheral.getType(name)=='modem' then return name end end
end

local function wsConnect()
  if M._ws then return M._ws end
  if not http or not http.websocket then return nil,'HTTP/WebSocket API unavailable' end
  if not cfg.wsUrl or cfg.wsUrl=='' then return nil,'client.cfg wsUrl is not configured' end
  local ws,err=http.websocket(cfg.wsUrl); if not ws then return nil,err or 'WebSocket connect failed' end
  ws.send(textutils.serializeJSON({type='register',id=tostring(os.getComputerID())}))
  M._ws=ws; return ws
end

function M.saveConfig() util.saveTable(config.clientConfig,cfg); saveRegistry() end
function M.config() return cfg end
function M.registry() return registry end
function M.protocolFor(id) return protocolFor(id) end
function M.backboneFor(id) return backboneFor(id) end
function M.activeNetwork()
  local n=registry.networks[registry.active]
  if not n then n={id=registry.active or 'public',name=registry.active or 'public',visibility='public'}; registry.networks[n.id]=n end
  n.protocol=n.protocol or protocolFor(n.id)
  n.backboneProtocol=n.backboneProtocol or backboneFor(n.id)
  return n
end
function M.networks()
  local out={}
  for _,n in pairs(registry.networks) do out[#out+1]=util.deepcopy(n) end
  table.sort(out,function(a,b)return tostring(a.name or a.id)<tostring(b.name or b.id)end)
  return out
end
function M.setActiveNetwork(id)
  id=util.safeName(id,32); if id=='' then return nil,'Bad network ID' end
  if not registry.networks[id] then return nil,'Unknown network '..id end
  registry.active=id; M._session=nil; M._inbox={}; M._fragments={}; saveRegistry(); return registry.networks[id]
end
function M.addNetwork(info)
  if type(info)~='table' then return nil,'Bad network' end
  local id=util.safeName(info.id,32); if id=='' then return nil,'Bad network ID' end
  local n=registry.networks[id] or {id=id}
  if n.coreIdentity and info.coreIdentity and n.coreIdentity~=info.coreIdentity then n.identityConflict={expected=n.coreIdentity,received=info.coreIdentity,computer=info.coreId,time=util.now()};saveRegistry();return nil,'CORE IDENTITY CHANGED for '..id end
  n.name=tostring(info.name or n.name or id):sub(1,48)
  n.visibility=info.visibility or n.visibility or 'public'
  n.coreId=tonumber(info.coreId) or n.coreId
  n.coreIdentity=info.coreIdentity or n.coreIdentity
  n.key=info.key~=nil and tostring(info.key) or n.key
  n.protocol=info.protocol or protocolFor(id)
  n.backboneProtocol=info.backboneProtocol or backboneFor(id)
  n.lastSeen=info.lastSeen or n.lastSeen
  registry.networks[id]=n; saveRegistry(); return n
end
function M.removeNetwork(id)
  id=util.safeName(id,32); if id=='public' then return nil,'The default public profile cannot be removed' end
  registry.networks[id]=nil
  if registry.active==id then registry.active='public' end
  saveRegistry(); return true
end

function M.open()
  local modem=findModem(); if not modem then return nil,'No modem attached' end
  cfg.modem=modem; if not rednet.isOpen(modem) then rednet.open(modem) end; M.saveConfig(); return modem
end

function M.discoverNetworks(timeout)
  local modem,err=M.open(); if not modem then return nil,err end
  local nonce=util.id('discover')
  rednet.broadcast({network='spawnnet',version=2,type='discover',nonce=nonce,computer=os.getComputerID()},config.discoveryProtocol)
  local timer=os.startTimer(timeout or config.discoveryTimeout or 1.25)
  local found={}
  while true do
    local ev={os.pullEvent()}
    if ev[1]=='timer' and ev[2]==timer then break end
    if ev[1]=='rednet_message' then
      local sender,msg,proto=ev[2],ev[3],ev[4]
      if proto==config.discoveryProtocol and type(msg)=='table' and msg.network=='spawnnet' and msg.version==2 and msg.type=='advertise' and msg.nonce==nonce then
        local id=util.safeName(msg.networkId,32)
        if id~='' then
          local n=M.addNetwork({id=id,name=msg.name or id,visibility=msg.visibility or'public',coreId=sender,coreIdentity=msg.coreIdentity,protocol=msg.protocol,lastSeen=util.now()})
          if n then found[id]=util.deepcopy(n)end
        end
      end
    end
  end
  local out={}; for _,n in pairs(found) do out[#out+1]=n end
  table.sort(out,function(a,b)return tostring(a.name)<tostring(b.name)end)
  return out
end

function M.discover(force)
  local n=M.activeNetwork()
  if cfg.transport=='websocket' then
    if not n.coreId then return nil,'WebSocket transport requires a core ID for the active network' end
    local ws,err=wsConnect(); if not ws then return nil,err end
    return n.coreId
  end
  local modem,err=M.open(); if not modem then return nil,err end
  if n.coreId and not force then return n.coreId end
  local found,e=M.discoverNetworks(config.discoveryTimeout)
  if not found then return nil,e end
  n=registry.networks[registry.active]
  if n and n.coreId then return n.coreId end
  return nil,'Network "'..tostring(registry.active)..'" not found. Open Networks and discover/join it.'
end

function M.setSession(s)
  local n=M.activeNetwork(); M._session=s
  util.ensureDir('/spawnnet/sessions')
  local path=sessionPath(n.id)
  if s then util.saveTable(path,s) elseif fs.exists(path) then fs.delete(path) end
end
function M.loadSession()
  -- Refresh from disk every time. SpawnNet apps are commonly nested with shell.run(),
  -- so another app may have advanced the authenticated request sequence.
  local path=sessionPath(M.activeNetwork().id)
  if fs.exists(path) then M._session=util.loadTable(path,nil) else M._session=nil end
  return M._session
end
function M.getSession() return M.loadSession() end
function M.clearAllSessions()
  M._session=nil
  if fs.exists('/spawnnet/sessions') then fs.delete('/spawnnet/sessions') end
  util.ensureDir('/spawnnet/sessions')
end

function M.request(service,action,payload,opts)
  opts=opts or {}; local n=M.activeNetwork(); local id,err=M.discover(false); if not id then return nil,err end
  n=registry.networks[registry.active] or n
  local req=packet.new(service,action,payload or {})
  req.networkId=n.id
  if n.key and n.key~=''then local stamp=util.now();req.networkAuth={time=stamp,proof=crypto.hmac(crypto.sha256(n.key),table.concat({n.id,req.requestId,service,action,tostring(stamp)},'|'))}end
  local sess=opts.noAuth and nil or M.loadSession()
  if sess then packet.attachAuth(req,sess); util.saveTable(sessionPath(n.id),sess) end
  local proto=n.protocol or protocolFor(n.id)
  local pending=M._inbox[req.requestId]; if pending then M._inbox[req.requestId]=nil; return pending end

  if cfg.transport=='websocket' then
    local ws,wsErr=wsConnect(); if not ws then return nil,wsErr end
    ws.send(textutils.serializeJSON({type='message',to=tostring(id),protocol=proto,body=textutils.serialize(req)}))
    while true do
      local raw,why=ws.receive(); if not raw then M._ws=nil; return nil,why or 'WebSocket closed' end
      local env=textutils.unserializeJSON(raw)
      if type(env)=='table' and env.type=='message' and tostring(env.from)==tostring(id) and env.protocol==proto and env.body then
        local msg=textutils.unserialize(env.body)
        if type(msg)=='table' and msg.type=='response' then
          if msg.requestId==req.requestId then
            if sess and msg.responseSig and not packet.verifyResponse(msg,sess.key)then return nil,'Invalid SpawnNet response signature'end
            if sess and msg.secure then local opened,oe=packet.openResponse(msg,sess.key);if not opened then return nil,oe end end
            if msg.status==401 and sess then
              M.setSession(nil)
              if opts.allowGuest then local retry=util.deepcopy(opts);retry.allowGuest=nil;retry.noAuth=true;return M.request(service,action,payload,retry) end
            end
            return msg
          else M._inbox[msg.requestId]=msg end
        end
      elseif type(env)=='table' and env.type=='error' then return nil,env.error or 'relay error' end
    end
  end

  local sent,sendErr=wire.send(id,req,proto); if not sent then return nil,sendErr or 'Rednet is not open' end
  local deferred={}
  local function replay()for _,event in ipairs(deferred)do os.queueEvent(unpack(event))end;deferred={}end
  local deadline=os.startTimer(opts.timeout or cfg.timeout or config.requestTimeout)
  while true do
    local ev={os.pullEvent()}
    if ev[1]=='timer' and ev[2]==deadline then
      -- Cached core IDs can become stale when a network moves. Forget it once.
      replay();if not opts._retried then n.coreId=nil;saveRegistry();opts._retried=true;return M.request(service,action,payload,opts)end
      return nil,'SpawnNet request timed out'
    end
    if ev[1]=='rednet_message' then
      local sender,msg,rproto=ev[2],ev[3],ev[4]
      if rproto==proto and sender==id then
        local complete=wire.accept(sender,msg,M._fragments); wire.purge(M._fragments); msg=complete
        if type(msg)=='table' and msg.network=='spawnnet' and msg.type=='response' then
          if msg.requestId==req.requestId then
            if sess and msg.responseSig and not packet.verifyResponse(msg,sess.key)then replay();return nil,'Invalid SpawnNet response signature'end
            if sess and msg.secure then local opened,oe=packet.openResponse(msg,sess.key);if not opened then replay();return nil,oe end end
            if msg.status==401 and sess then
              M.setSession(nil)
              if opts.allowGuest then replay();local retry=util.deepcopy(opts);retry.allowGuest=nil;retry.noAuth=true;return M.request(service,action,payload,retry) end
            end
            replay();return msg
          else M._inbox[msg.requestId]=msg end
        end
      else deferred[#deferred+1]=ev end
    else deferred[#deferred+1]=ev
    end
  end
end
function M.call(service,action,payload,opts)
  local r,e=M.request(service,action,payload,opts); if not r then return nil,e end
  if (r.status or 500)>=400 then return nil,r.error or ('SpawnNet error '..tostring(r.status)),r end
  return r.payload,nil,r
end
return M
]==],
  ["/spawnnet/client/network_lab.lua"]=[==[local gui=dofile('/spawnnet/client/gui.lua')
local net=dofile('/spawnnet/client/net.lua')
local config=dofile('/spawnnet/lib/config.lua')
while true do
  local n=net.activeNetwork();local s=net.loadSession()
  gui.clear();gui.bar('NETWORK LAB',tostring(n.name or n.id))
  print('Active network: '..tostring(n.name or n.id))
  print('Network ID:     '..tostring(n.id))
  print('Core ID:        '..tostring(n.coreId or'unknown'))
  print('Visibility:     '..tostring(n.visibility or'public'))
  print('Protocol:       '..tostring(n.protocol or(config.protocolPrefix..tostring(n.id)..':v2')))
  print('Transport:      '..tostring(net.config and net.config().transport or'?'))
  print('Session user:   '..tostring(s and s.user or'guest'))
  print('Session seq:    '..tostring(s and s.seq or'-'))
  print();print('D discover networks   R refresh   Q back')
  local _,k=os.pullEvent('key')
  if k==keys.q then break elseif k==keys.d then
    gui.clear();gui.bar('DISCOVERY');local found,e=net.discoverNetworks(1.5)
    if found then for _,x in ipairs(found)do print(tostring(x.id)..' - '..tostring(x.name)..' core #'..tostring(x.coreId))end else printError(e)end
    gui.status('Press any key');os.pullEvent('key')
  end
end
gui.clear()
]==],
  ["/spawnnet/client/networks.lua"]=[==[local gui=dofile('/spawnnet/client/gui.lua')
local net=dofile('/spawnnet/client/net.lua')
local function networkItems()
  local active=net.activeNetwork().id;local out={}
  for _,n in ipairs(net.networks())do out[#out+1]={label=(n.id==active and '* 'or'  ')..tostring(n.name or n.id)..' ['..n.id..'] '..tostring(n.visibility or 'public'),network=n}end
  out[#out+1]={label='+ Discover networks',action='discover'}
  out[#out+1]={label='+ Add network manually',action='add'}
  out[#out+1]={label='Cluster / storage nodes',action='nodes'}
  out[#out+1]={label='Back',action='back'}
  return out
end
local function editNetwork(n)
  while true do
    local items={{label='Connect / make active',action='connect'},{label='Set/update private join code',action='key'},{label='Refresh discovery',action='refresh'}}
    if n.id~='public'then items[#items+1]={label='Forget this network',action='remove'}end
    items[#items+1]={label='Back',action='back'}
    local m=gui.menu('NETWORK: '..tostring(n.name),tostring(n.id)..'  core='..tostring(n.coreId or '?'),items)
    if not m or m.action=='back'then return
    elseif m.action=='connect'then local ok,e=net.setActiveNetwork(n.id);if ok then gui.toast('Connected to '..tostring(n.name),1);return else gui.toast(e,2)end
    elseif m.action=='key'then local key=gui.prompt('PRIVATE NETWORK','Join code:','');net.addNetwork({id=n.id,name=n.name,visibility=n.visibility,coreId=n.coreId,key=key});n=net.registry().networks[n.id]
    elseif m.action=='refresh'then net.discoverNetworks();n=net.registry().networks[n.id]or n
    elseif m.action=='remove'then if gui.confirm('FORGET NETWORK','Forget '..n.id..'?')then net.removeNetwork(n.id);return end end
  end
end
while true do
  local m=gui.menu('NETWORK MANAGER','Multiple independent SpawnNet networks can coexist.',networkItems(),{right=net.activeNetwork().name})
  if not m or m.action=='back'then break
  elseif m.network then editNetwork(m.network)
  elseif m.action=='discover'then
    gui.clear();gui.bar('DISCOVERING');gui.text(3,6,45,'Broadcasting for SpawnNet v2 networks...',colors.white,colors.black);local found,e=net.discoverNetworks(1.5);if not found then gui.toast(e or 'Discovery failed',2)else gui.toast('Found '..tostring(#found)..' network(s)',1)end
  elseif m.action=='add'then
    local id=gui.prompt('ADD NETWORK','Network ID:','');if id~=''then local name=gui.prompt('ADD NETWORK','Display name:',id);local key=gui.prompt('ADD NETWORK','Join code (blank for public):','');net.addNetwork({id=id,name=name,key=key,visibility=key~=''and'private'or'public'})end
  elseif m.action=='nodes'then shell.run('/spawnnet/client/nodes.lua') end
end
]==],
  ["/spawnnet/client/nodes.lua"]=[==[local gui=dofile('/spawnnet/client/gui.lua')
local net=dofile('/spawnnet/client/net.lua')
local function load()
  local p,e=net.call('nodes','summary',{});if not p then gui.toast(e or 'Admin login required',2);return nil end;return p
end
while true do
  local p=load();if not p then break end
  local items={}
  for _,n in ipairs(p.nodes or {})do local status=n.quarantined and'QUARANTINE'or(n.draining and'DRAINING'or(n.online and'ONLINE'or'OFFLINE'));items[#items+1]={label=status..'  #'..tostring(n.id)..'  '..tostring(n.name or '')..'  free='..tostring(n.free or '?'),node=n}end
  for _,n in ipairs(p.pendingNodes or {})do items[#items+1]={label='PENDING #'..tostring(n.id)..'  fingerprint='..tostring(n.pairId or'?'),pending=n}end
  items[#items+1]={label='Rebalance / replicate objects',action='rebalance'};items[#items+1]={label='Refresh',action='refresh'};items[#items+1]={label='Back',action='back'}
  local sub='Nodes '..tostring(p.online or 0)..'/'..tostring(p.totalNodes or 0)..'  objects '..tostring(p.objects or 0)..'  free '..tostring(p.free or 0)
  local m=gui.menu('STORAGE CLUSTER',sub,items)
  if not m or m.action=='back'then break
  elseif m.action=='rebalance'then local r,e=net.call('nodes','rebalance',{});gui.toast(r and('Added '..tostring(r.copiesAdded)..' replica(s)')or e,2)
  elseif m.pending then
    local n=m.pending;local code=gui.prompt('VERIFY STORAGE NODE','Enter the pair code displayed on node #'..tostring(n.id)..':','');if code~=''then local name=gui.prompt('NODE NAME','Name:',n.name or('Storage #'..n.id));local ok,e=net.call('nodes','approve',{id=n.id,name=name,pairCode=code});gui.toast(ok and'Node cryptographically paired'or e,2)end
  elseif m.node then
    local n=m.node;local choices={}
    if n.draining then choices[#choices+1]={label='Return node to active duty',action='activate'}else choices[#choices+1]={label='Drain node before maintenance',action='drain'}end
    if n.quarantined then choices[#choices+1]={label='Clear integrity quarantine',action='clearQuarantine'}end
    choices[#choices+1]={label='Permanently remove node',action='remove'};choices[#choices+1]={label='Back',action='back'}
    local pick=gui.menu('VAULT NODE #'..tostring(n.id),tostring(n.quarantineReason or n.name or''),choices)
    if pick and pick.action and pick.action~='back'then
      if pick.action~='remove'or gui.confirm('DECOMMISSION NODE','Remove node metadata? Rebalance first if it stores the only copy.')then local ok,e=net.call('nodes',pick.action,{id=n.id});gui.toast(ok and'Node state updated'or e,2)end
    end
  end
end
]==],
  ["/spawnnet/client/package_manager.lua"]=[==[-- SpawnNet native application package manager 2.3.0
local util=dofile('/spawnnet/lib/util.lua')
local net=dofile('/spawnnet/client/net.lua')
local crypto=dofile('/spawnnet/lib/crypto.lua')
local sm=dofile('/spawnnet/client/service_manager.lua')
local runtime=dofile('/spawnnet/client/app_runtime.lua')
local M={};local ROOT='/spawnnet/apps';local DB=ROOT..'/installed.db';local DATA='/spawnnet/appdata';local DOWNLOADS='/downloads';local C=colors
local PERM_LABELS={filesystem='Private application data storage',peripheral='Access attached peripherals',modem='Use modem hardware',rednet='Use SpawnNet / Rednet',shell='Open approved SpawnNet programs',http='Use HTTP/WebSocket APIs',startup='Run a supervised background service',commands='Create local command launchers'}
local function ensure(path)if path==''or path=='/'or fs.exists(path)then return end;local p=fs.getDir(path);if p and p~=''then ensure(p)end;fs.makeDir(path)end
local function safe(v,n)return util.safeName(v or'',n or 32)end
local function cleanFilePath(path)path=tostring(path or''):gsub('\\','/'):gsub('^/+','');if path==''then return nil end;for part in path:gmatch('[^/]+')do if part==''or part=='.'or part=='..'then return nil end end;return path end
local function canonicalHash(pkg)
  local paths={};for p in pairs(pkg.files or{})do paths[#paths+1]=p end;table.sort(paths)
  local parts={tostring(pkg.domain or''),tostring(pkg.name or''),tostring(pkg.version or''),tostring(pkg.title or''),tostring(pkg.entry or''),tostring(pkg.service or'')}
  local perms={};for _,p in ipairs(pkg.permissions or{})do perms[#perms+1]=p end;table.sort(perms);for _,p in ipairs(perms)do parts[#parts+1]='perm:'..p end
  local cmds={};for n in pairs(pkg.commands or{})do cmds[#cmds+1]=n end;table.sort(cmds);for _,n in ipairs(cmds)do parts[#parts+1]='cmd:'..n..'='..tostring(pkg.commands[n])end
  for _,p in ipairs(paths)do parts[#parts+1]='file:'..p..':'..crypto.sha256(tostring(pkg.files[p]or''))end
  return crypto.sha256(table.concat(parts,'\0'))
end
local function manifest(domain,name)return net.call('package','manifest',{domain=safe(domain),name=safe(name)})end
local function getPackage(domain,name)return net.call('package','get',{domain=safe(domain),name=safe(name)})end
local function installed()return util.loadTable(DB,{})end
local function saveInstalled(t)ensure(ROOT);util.saveTable(DB,t)end
local function key(d,n)return safe(d)..'/'..safe(n)end
local function hasPerm(m,p)for _,x in ipairs(m.permissions or{})do if x==p then return true end end;return false end
local function wrap(s,w)local out={};s=tostring(s or'');while #s>w do local cut=w;local p=s:sub(1,w):match('^.*()%s');if p and p>8 then cut=p end;out[#out+1]=s:sub(1,cut):gsub('%s+$','');s=s:sub(cut+1):gsub('^%s+','')end;if s~=''then out[#out+1]=s end;return out end
local function nativeConfirm(kind,m,source,newPerms)
  term.setBackgroundColor(C.black);term.clear();term.setCursorPos(1,1);local w,h=term.getSize();term.setBackgroundColor(C.purple);term.setTextColor(C.white);term.clearLine();write((' // '..kind..' GATEWAY // VERIFIED USER ACTION '):sub(1,w));term.setBackgroundColor(C.black);term.setTextColor(C.cyan);term.setCursorPos(2,3);print('[+] '..tostring(m.title or m.name));term.setTextColor(C.lightGray);print('  Version   '..tostring(m.version or'?'));print('  Publisher '..tostring(m.publisher or'?'));print('  Origin    spn://'..tostring(m.domain or'?'));if source then print('  Request   '..tostring(source):sub(1,math.max(1,w-13)))end;print('  Payload   '..tostring(m.files or'?')..' files / '..tostring(m.totalBytes or'?')..' bytes');term.setTextColor(C.white);print();print('CAPABILITY MATRIX');if #(m.permissions or{})==0 then term.setTextColor(C.lime);print('  [ ] No optional capabilities')else for _,p in ipairs(m.permissions or{})do term.setTextColor((newPerms and newPerms[p])and C.orange or C.cyan);print('  '..((newPerms and newPerms[p])and'[NEW]  'or'[+]      ')..tostring(PERM_LABELS[p]or p))end end;if newPerms and next(newPerms)then term.setTextColor(C.orange);print();print('NEW CAPABILITIES REQUIRE REVIEW')end;term.setTextColor(C.lightGray);print();for _,line in ipairs(wrap('Native Lua runs inside the SpawnNet capability sandbox. The website cannot approve this screen.',math.max(10,w-4)))do print('  '..line)end;term.setCursorPos(1,h);term.setBackgroundColor(C.purple);term.setTextColor(C.white);term.clearLine();write(' [N] ABORT                              [Y] AUTHORIZE');while true do local _,k=os.pullEvent('key');if k==keys.y then return true elseif k==keys.n or k==keys.q or k==keys.escape then return false end end
end
local function ensureStartupBridge()
  return dofile('/spawnnet/client/startup_config.lua').enable()
end
local function commandPath(name)return '/'..safe(name)..'.lua'end
local function commandBody(domain,name,rel)local app=ROOT..'/'..domain..'/'..name..'/app/'..rel;return "-- SPAWNNET_APP_COMMAND "..domain..'/'..name.."\nlocal rt=dofile('/spawnnet/client/app_runtime.lua');local db=dofile('/spawnnet/lib/util.lua').loadTable('/spawnnet/apps/installed.db',{});local rec=db["..string.format('%q',domain..'/'..name).."];local ok,e=rt.run(rec,"..string.format('%q',app)..",...);if not ok then error(e,0)end\n"end
local function preflightCommands(pkg)
  if not hasPerm(pkg,'commands')then return true end
  for name,rel in pairs(pkg.commands or{})do local p=commandPath(name);if fs.exists(p)then local h=fs.open(p,'r');local s=h and h.readAll()or'';if h then h.close()end;if not s:find('SPAWNNET_APP_COMMAND '..safe(pkg.domain)..'/'..safe(pkg.name),1,true)then return nil,'Command already exists: '..name end end;if not pkg.files[rel]then return nil,'Command target missing: '..rel end end;return true
end
local function syncCommands(pkg,old)
  if old then for n in pairs(old.commands or{})do if not(pkg.commands and pkg.commands[n])then local p=commandPath(n);if fs.exists(p)then local h=fs.open(p,'r');local s=h and h.readAll()or'';if h then h.close()end;if s:find('SPAWNNET_APP_COMMAND '..safe(pkg.domain)..'/'..safe(pkg.name),1,true)then fs.delete(p)end end end end end
  if hasPerm(pkg,'commands')then for n,rel in pairs(pkg.commands or{})do local h=assert(fs.open(commandPath(n),'w'));h.write(commandBody(safe(pkg.domain),safe(pkg.name),rel));h.close()end end
end
local function syncService(pkg)
  local d,n=safe(pkg.domain),safe(pkg.name);if pkg.service and hasPerm(pkg,'startup')then local path=ROOT..'/'..d..'/'..n..'/app/'..pkg.service;sm.register(d,n,pkg.title,path,{permissions=pkg.permissions or{}});ensureStartupBridge()else sm.unregister(d,n)end
end
local function clearOwnedCommands(rec)
  if not rec then return end
  for n in pairs(rec.commands or{})do
    local p=commandPath(n)
    if fs.exists(p)then
      local h=fs.open(p,'r');local s=h and h.readAll()or'';if h then h.close()end
      if s:find('SPAWNNET_APP_COMMAND '..safe(rec.domain)..'/'..safe(rec.name),1,true)then fs.delete(p)end
    end
  end
end
local function writePackage(pkg)
  local d,n=safe(pkg.domain),safe(pkg.name)
  if d==''or n==''then return nil,'Invalid package identity'end
  if canonicalHash(pkg)~=tostring(pkg.hash or'')then return nil,'Package integrity check failed'end
  local okc,ce=preflightCommands(pkg);if not okc then return nil,ce end
  local root=ROOT..'/'..d..'/'..n
  ensure(root)
  local stage=root..'/.stage'
  local prev=root..'/.previous'
  local app=root..'/app'
  if fs.exists(stage)then fs.delete(stage)end
  ensure(stage)

  local staged,stageErr=pcall(function()
    for path,data in pairs(pkg.files or{})do
      local cp=cleanFilePath(path)
      if not cp then error('Unsafe package path: '..tostring(path),0)end
      data=tostring(data or'')
      if cp:sub(-4)=='.lua'then
        local f,e=loadstring(data,'@'..cp)
        if not f then error('Package Lua syntax error in '..cp..': '..tostring(e),0)end
      end
      local target=fs.combine(stage,cp);ensure(fs.getDir(target))
      local h=assert(fs.open(target,'w'));h.write(data);h.close()
    end
  end)
  if not staged then if fs.exists(stage)then fs.delete(stage)end;return nil,'Install staging failed: '..tostring(stageErr)end

  local db=installed()
  local k=key(d,n)
  local old=db[k]
  local oldAppExisted=fs.exists(app)
  if fs.exists(prev)then fs.delete(prev)end
  if oldAppExisted then
    local movedOld,oldErr=pcall(fs.move,app,prev)
    if not movedOld then fs.delete(stage);return nil,'Could not preserve current app: '..tostring(oldErr)end
  end
  local movedNew,newErr=pcall(fs.move,stage,app)
  if not movedNew then
    if oldAppExisted and fs.exists(prev)then pcall(fs.move,prev,app)end
    return nil,'Install commit failed: '..tostring(newErr)
  end

  local newRec={domain=d,name=n,title=pkg.title,version=pkg.version,publisher=pkg.publisher,permissions=pkg.permissions or{},entry=pkg.entry,service=pkg.service,commands=pkg.commands or{},hash=pkg.hash,installed=os.clock()}
  local metaOk,metaErr=pcall(function()
    db[k]=newRec
    saveInstalled(db)
    syncCommands(pkg,old)
    syncService(pkg)
  end)
  if not metaOk then
    local recoverOk,recoverErr=pcall(function()
      clearOwnedCommands(pkg)
      if old then
        syncCommands(old,nil)
        syncService(old)
      else
        sm.unregister(d,n)
      end
      local rdb=installed()
      rdb[k]=old
      saveInstalled(rdb)
      if fs.exists(app)then fs.delete(app)end
      if oldAppExisted and fs.exists(prev)then fs.move(prev,app)end
    end)
    if not recoverOk then
      return nil,'Install metadata failed: '..tostring(metaErr)..' ; automatic recovery also failed: '..tostring(recoverErr)..' ; previous files remain in '..prev
    end
    return nil,'Install metadata failed and previous version was restored: '..tostring(metaErr)
  end
  if fs.exists(prev)then fs.delete(prev)end
  return root
end
local function runInstalled(rec)if not rec or not rec.entry then return nil,'Package has no entry program'end;local path=ROOT..'/'..rec.domain..'/'..rec.name..'/app/'..rec.entry;if not fs.exists(path)then return nil,'Entry file missing'end;local ok,e=runtime.run(rec,path,'spawnnet-package');if not ok then return nil,'Application sandbox: '..tostring(e)end;return true end
local function doInstall(domain,name,source,updating)
  if not net.loadSession()then return nil,'Sign in before installing native applications'end
  local p,e=manifest(domain,name);if not p then return nil,e end;local m=p.package or p;local db=installed();local old=db[key(domain,name)];local newPerms={};if old then local have={};for _,x in ipairs(old.permissions or{})do have[x]=true end;for _,x in ipairs(m.permissions or{})do if not have[x]then newPerms[x]=true end end end;if not nativeConfirm(updating and'UPDATE'or'INSTALL',m,source,newPerms)then return nil,'Cancelled'end;local got,ge=getPackage(domain,name);if not got then return nil,ge end;local pkg=got.package or got;local root,we=writePackage(pkg);if not root then return nil,we end;term.setBackgroundColor(C.black);term.clear();term.setCursorPos(1,2);term.setTextColor(C.lime);print((updating and'UPDATED: 'or'INSTALLED: ')..tostring(pkg.title or pkg.name)..' '..tostring(pkg.version));term.setTextColor(C.white);print('Location: '..root);if pkg.entry then print();write('Run it now? Y/n: ');local a=read():lower();if a~='n'and a~='no'then local rec=installed()[key(domain,name)];local rok,re=runInstalled(rec);if not rok then printError(re)end end end;return true
end
function M.installFromSite(domain,name,source)return doInstall(domain,name,source,false)end
function M.downloadFromSite(domain,name,source)local p,e=manifest(domain,name);if not p then return nil,e end;local m=p.package or p;if not nativeConfirm('DOWNLOAD',m,source)then return nil,'Cancelled'end;local got,ge=getPackage(domain,name);if not got then return nil,ge end;local pkg=got.package or got;if canonicalHash(pkg)~=tostring(pkg.hash or'')then return nil,'Package integrity check failed'end;ensure(DOWNLOADS);local file=DOWNLOADS..'/'..safe(domain)..'-'..safe(name)..'-'..tostring(pkg.version or'package'):gsub('[^%w%.%-_]','_')..'.spkg';local h=assert(fs.open(file,'w'));h.write(textutils.serialize(pkg));h.close();return file end
function M.run(domain,name)local rec=installed()[key(domain,name)];if not rec then return nil,'Not installed'end;return runInstalled(rec)end
function M.uninstall(domain,name)local db=installed();local k=key(domain,name);local rec=db[k];if not rec then return nil,'Not installed'end;term.clear();term.setCursorPos(1,2);term.setTextColor(C.yellow);print('UNINSTALL '..tostring(rec.title or rec.name)..'?');term.setTextColor(C.lightGray);print('Application files will be removed. App data is kept.');print();write('Type UNINSTALL: ');if read()~='UNINSTALL'then return nil,'Cancelled'end;sm.unregister(rec.domain,rec.name);for n in pairs(rec.commands or{})do local p=commandPath(n);if fs.exists(p)then local h=fs.open(p,'r');local s=h and h.readAll()or'';if h then h.close()end;if s:find('SPAWNNET_APP_COMMAND '..rec.domain..'/'..rec.name,1,true)then fs.delete(p)end end end;local root=ROOT..'/'..rec.domain..'/'..rec.name;if fs.exists(root)then fs.delete(root)end;db[k]=nil;saveInstalled(db);return true end
function M.menu()while true do local db=installed();local list={};for _,r in pairs(db)do list[#list+1]=r end;table.sort(list,function(a,b)return tostring(a.title or a.name)<tostring(b.title or b.name)end);term.setBackgroundColor(C.black);term.clear();term.setCursorPos(1,1);term.setTextColor(C.yellow);print('SPAWNNET INSTALLED APPS');term.setTextColor(C.white);if #list==0 then print();print('No SpawnNet application packages installed.')else for i,r in ipairs(list)do print(i..') '..tostring(r.title or r.name)..'  '..tostring(r.version))end end;print();print('R # run   U # update   X # uninstall   Q quit');write('> ');local line=read();local c,num=line:match('^(%a)%s*(%d*)');c=c and c:lower();local r=list[tonumber(num) or 0];if c=='q'then return elseif c=='r'and r then runInstalled(r)elseif c=='u'and r then local ok,e=doInstall(r.domain,r.name,'Installed Apps',true);if not ok and e~='Cancelled'then printError(e);sleep(1.5)end elseif c=='x'and r then local ok,e=M.uninstall(r.domain,r.name);if not ok and e~='Cancelled'then printError(e);sleep(1.5)end end end end
return M
]==],
  ["/spawnnet/client/peripheral_lab.lua"]=[==[local gui=dofile('/spawnnet/client/gui.lua')
local C=colors
local function names()
  local out={}
  for _,n in ipairs(peripheral.getNames())do
    local t=peripheral.getType(n)or'?'
    out[#out+1]={label=n..' ['..t..']',name=n,type=t}
  end
  table.sort(out,function(a,b)return a.label<b.label end)
  return out
end
while true do
  local items=names();items[#items+1]={label='Back',back=true}
  local m=gui.menu('PERIPHERAL LAB','Inspect real attached peripherals and methods.',items)
  if not m or m.back then break end
  local methods=peripheral.getMethods and peripheral.getMethods(m.name)or{}
  local list={}
  for _,method in ipairs(methods or{})do list[#list+1]={label=method,method=method}end
  table.sort(list,function(a,b)return a.label<b.label end);list[#list+1]={label='Back',back=true}
  while true do
    local x=gui.menu('PERIPHERAL: '..m.name,m.type,list)
    if not x or x.back then break end
    gui.clear();gui.bar(x.method)
    print('Peripheral: '..m.name);print('Method: '..x.method);print()
    print('Arguments are optional Lua values, comma separated.')
    write('Args: ');local raw=read();local args={}
    if raw~=''then
      local fn,err=loadstring('return {'..raw..'}')
      if not fn then printError(err);gui.status('Press any key');os.pullEvent('key')
      else
        local ok,val=pcall(fn);if ok and type(val)=='table'then args=val else printError(val);gui.status('Press any key');os.pullEvent('key')end
      end
    end
    local res={pcall(peripheral.call,m.name,x.method,unpack(args))}
    gui.clear();gui.bar('RESULT: '..x.method)
    local ok=table.remove(res,1)
    print(ok and'CALL OK'or'CALL FAILED');print()
    for i,v in ipairs(res)do print(i..': '..(type(v)=='table'and textutils.serialize(v)or tostring(v)))end
    if #res==0 then print('(no return values)')end
    gui.status('Press any key');os.pullEvent('key')
  end
end
gui.clear()
]==],
  ["/spawnnet/client/release_manager.lua"]=[==[-- SpawnNet release manager 2.3.0
local net=dofile('/spawnnet/client/net.lua');local util=dofile('/spawnnet/lib/util.lua')
local function readFile(p)local h=fs.open(p,'r');if not h then return nil end;local s=h.readAll();h.close();return s end
local function collectDir(root,files)
  for _,n in ipairs(fs.list(root))do local p=fs.combine(root,n);if fs.isDir(p)then collectDir(p,files)elseif p:sub(-4)=='.lua'then files[p:gsub('^/','')]=readFile(p)end end
end
local function publishClient()
  local files={};collectDir('/spawnnet/client',files);collectDir('/spawnnet/lib',files)
  for _,p in ipairs({'/spawnnet.lua','/web.lua','/studio.lua','/spawnnet-packages.lua','/spawnnet-release.lua'})do if fs.exists(p)then files[p:gsub('^/','')]=readFile(p)end end
  write('Release version: ');local v=read();if v==''then return end
  local p,e=net.call('package','publish',{name='client',version=v,description='Official SpawnNet client release',component='client',channel='stable',restartRequired=false,files=files});if not p then printError(e)else print('Published client '..v..' ('..tostring(p.package and p.package.files or'?')..' files)')end
end
local function stageCore()local p,e=net.call('package','stageCore',{name='core'});if not p then printError(e)else print('Core update staged: '..tostring(p.version));print('On the Core: stop server, run spawnnet-core-update, restart.')end end
local function status()for _,n in ipairs({'client','node','core'})do local p=net.call('package','manifest',{name=n},{noAuth=true});if p then local m=p.package or p;print(n..': '..tostring(m.version)..' ['..tostring(m.channel or'stable')..']')else print(n..': not published')end end end
while true do term.clear();term.setCursorPos(1,1);term.setTextColor(colors.yellow);print('SPAWNNET RELEASE MANAGER');term.setTextColor(colors.white);print('1) Release status');print('2) Publish THIS upgraded client snapshot');print('3) Stage published Core update');print('4) Back');write('> ');local c=read();if c=='1'then status();print();print('Press key');os.pullEvent('key')elseif c=='2'then publishClient();sleep(2)elseif c=='3'then stageCore();sleep(2)else return end end
]==],
  ["/spawnnet/client/renderer.lua"]=[==[local util=dofile('/spawnnet/lib/util.lua')
local M={}
local hexColors={['0']=colors.white,['1']=colors.orange,['2']=colors.magenta,['3']=colors.lightBlue,['4']=colors.yellow,['5']=colors.lime,['6']=colors.pink,['7']=colors.gray,['8']=colors.lightGray,['9']=colors.cyan,a=colors.purple,b=colors.blue,c=colors.brown,d=colors.green,e=colors.red,f=colors.black}
local function dim(v,parent,default)
  if type(v)=='number' then return math.floor(v) end
  if type(v)=='string' and v:sub(-1)=='%' then return math.max(1,math.floor(parent*(tonumber(v:sub(1,-2)) or 100)/100)) end
  return default
end
local function copyStyle(parent,e)
  return {fg=e.fg or (parent and parent.fg) or colors.white,bg=e.bg or (parent and parent.bg) or colors.black,align=e.align or (parent and parent.align) or 'left'}
end
local function flatten(elements,box,parentStyle,out)
  out=out or {}
  for _,e in ipairs(elements or {}) do
    if e.visible~=false then
      local st=copyStyle(parentStyle,e); local x=box.x+(tonumber(e.x) or 1)-1; local y=box.y+(tonumber(e.y) or 1)-1; local w=dim(e.w,box.w,math.max(1,box.w-(x-box.x))); local h=dim(e.h,box.h,1)
      local item=util.deepcopy(e); item._source=e._original or e; item._x=x; item._y=y; item._w=w; item._h=h; item._style=st
      if e.type=='row' or e.type=='column' then
        if e.type=='panel' then out[#out+1]=item end
        local children=e.children or {}; local cursor=1
        for i,ch in ipairs(children) do
          local cc=util.deepcopy(ch); cc._original=ch._original or ch
          if e.type=='row' then
            cc.x=cc.x or cursor; cc.y=cc.y or 1; cc.w=cc.w or math.max(1,math.floor(w/math.max(1,#children))); cursor=(tonumber(cc.x) or cursor)+dim(cc.w,w,1)
          else
            cc.x=cc.x or 1; cc.y=cc.y or cursor; cc.w=cc.w or w; cc.h=cc.h or 1; cursor=(tonumber(cc.y) or cursor)+dim(cc.h,h,1)
          end
          flatten({cc},{x=x,y=y,w=w,h=h},st,out)
        end
      elseif e.type=='panel' then
        out[#out+1]=item; flatten(e.children or {},{x=x,y=y,w=w,h=h},st,out)
      elseif e.type=='tabs' then
        out[#out+1]=item
        local selected=tonumber(e.selected) or 1; local tab=(e.tabs or {})[selected]; if tab then flatten(tab.children or {},{x=x,y=y+1,w=w,h=math.max(1,h-1)},st,out) end
      else out[#out+1]=item end
    end
  end
  return out
end

local function writeAt(x,y,text,fg,bg,w,align)
  local sw,sh=term.getSize(); if y<1 or y>sh or x>sw then return end
  text=tostring(text or ''); w=math.max(0,math.min(w or #text,sw-x+1)); if w<=0 then return end
  if #text>w then text=text:sub(1,w) end
  if align=='center' then text=string.rep(' ',math.floor((w-#text)/2))..text elseif align=='right' then text=string.rep(' ',math.max(0,w-#text))..text end
  text=text..string.rep(' ',math.max(0,w-#text)); term.setCursorPos(math.max(1,x),y); term.setTextColor(fg or colors.white); term.setBackgroundColor(bg or colors.black); write(text:sub(1,w))
end
local function drawNfp(data,x,y,w,h,clipTop,clipBottom)
  local row=0
  for line in (tostring(data or '')..'\n'):gmatch('(.-)\n') do
    row=row+1; if row>h then break end; local sy=y+row-1
    if sy>=clipTop and sy<=clipBottom then
      for col=1,math.min(#line,w) do local c=line:sub(col,col):lower(); local bg=hexColors[c]; if bg then term.setCursorPos(x+col-1,sy); term.setBackgroundColor(bg); write(' ') end end
    end
  end
end
function M.resolve(page,width)
  width=width or select(1,term.getSize()); return flatten(page.elements or {},{x=1,y=1,w=width,h=9999},{fg=colors.white,bg=page.background or colors.black},{} )
end
function M.draw(page,opts)
  opts=opts or {}; local sw,sh=term.getSize(); local top=opts.top or 3; local bottom=opts.bottom or sh; local vh=bottom-top+1; local scroll=math.max(0,opts.scroll or 0); local bg=page.background or colors.black
  term.setBackgroundColor(bg); term.setTextColor(colors.white); for y=top,bottom do term.setCursorPos(1,y); term.clearLine() end
  local flat=M.resolve(page,sw); local hits={}; local maxY=vh
  for _,e in ipairs(flat) do
    local x=e._x; local vy=e._y; local y=top+vy-1-scroll; local w=e._w; local h=e._h; local st=e._style; maxY=math.max(maxY,vy+h-1)
    if y<=bottom and y+h-1>=top then
      if e.type=='panel' or e.type=='modal' then for yy=math.max(top,y),math.min(bottom,y+h-1) do writeAt(x,yy,'',st.fg,st.bg,w,'left') end; if e.border then local ch=e.borderChar or '#'; writeAt(x,y,string.rep(ch,w),st.fg,st.bg,w,'left'); if h>1 then writeAt(x,y+h-1,string.rep(ch,w),st.fg,st.bg,w,'left') end end
      elseif e.type=='heading' then writeAt(x,y,e.text or '',st.fg,st.bg,w,e.align or 'center')
      elseif e.type=='text' then local lines=util.wrapText(e.text or '',w); for i=1,math.min(h,#lines) do local sy=y+i-1; if sy>=top and sy<=bottom then writeAt(x,sy,lines[i],st.fg,st.bg,w,e.align) end end
      elseif e.type=='button' then local label='['..tostring(e.text or e.label or 'Button')..']'; writeAt(x,y,label,st.fg,e.bg or colors.gray,w,e.align or 'center'); hits[#hits+1]={x1=x,y1=y,x2=x+w-1,y2=y+h-1,element=e._source or e,kind='button'}
      elseif e.type=='input' then local v=(opts.inputs and opts.inputs[e.id]) or e.value or ''; local label=e.placeholder and v=='' and e.placeholder or v; writeAt(x,y,'>'..tostring(label),st.fg,e.bg or colors.gray,w,'left'); hits[#hits+1]={x1=x,y1=y,x2=x+w-1,y2=y+h-1,element=e._source or e,kind='input'}
      elseif e.type=='checkbox' then local v=(opts.inputs and opts.inputs[e.id]); if v==nil then v=e.checked end; writeAt(x,y,(v and '[x] ' or '[ ] ')..tostring(e.text or ''),st.fg,st.bg,w,'left'); hits[#hits+1]={x1=x,y1=y,x2=x+w-1,y2=y,element=e._source or e,kind='checkbox'}
      elseif e.type=='select' then local v=(opts.inputs and opts.inputs[e.id]) or e.value or (e.options and e.options[1]) or ''; writeAt(x,y,'<'..tostring(v)..'>',st.fg,e.bg or colors.gray,w,'left'); hits[#hits+1]={x1=x,y1=y,x2=x+w-1,y2=y,element=e._source or e,kind='select'}
      elseif e.type=='progress' then local val=tonumber((opts.values and opts.values[e.id]) or e.value) or 0; local max=tonumber(e.max) or 100; local inner=math.max(1,w-2); local fill=math.floor(inner*math.max(0,math.min(1,val/max))); writeAt(x,y,'['..string.rep('#',fill)..string.rep('-',inner-fill)..']',st.fg,st.bg,w,'left')
      elseif e.type=='separator' then writeAt(x,y,string.rep(e.char or '-',w),st.fg,st.bg,w,'left')
      elseif e.type=='badge' then writeAt(x,y,' '..tostring(e.text or '')..' ',st.fg,e.bg or colors.gray,w,e.align or 'left')
      elseif e.type=='image' then local data=e.data; if not data and opts.assetLoader and e.src then data=opts.assetLoader(e.src) end; drawNfp(data,x,y,w,h,top,bottom)
      elseif e.type=='list' then local items=e.items or {}; for i=1,math.min(h,#items) do local sy=y+i-1;if sy>=top and sy<=bottom then writeAt(x,sy,(e.bullet or '- ')..tostring(items[i]),st.fg,st.bg,w,'left') end end
      elseif e.type=='table' then
        local rows=e.rows or {}; local widths=e.widths or {}; local yy=y
        for ri,row in ipairs(rows) do if yy>bottom or ri>h then break end; if yy>=top then local cx=x; for ci,cell in ipairs(row) do local cw=widths[ci] or math.max(1,math.floor(w/math.max(1,#row))); writeAt(cx,yy,tostring(cell),st.fg,st.bg,cw,'left'); cx=cx+cw end end; yy=yy+1 end
      elseif e.type=='tabs' then local cx=x; for i,t in ipairs(e.tabs or {}) do local label=' '..tostring(t.title or ('Tab '..i))..' '; writeAt(cx,y,label,st.fg,(i==(tonumber(e.selected) or 1)) and (e.activeBg or colors.gray) or st.bg,#label,'left'); hits[#hits+1]={x1=cx,y1=y,x2=cx+#label-1,y2=y,element=e._source or e,kind='tab',tab=i}; cx=cx+#label+1 end
      end
    end
  end
  term.setBackgroundColor(colors.black); term.setTextColor(colors.white)
  return hits,math.max(0,maxY-vh),flat
end
function M.hit(hits,x,y) for i=#hits,1,-1 do local h=hits[i]; if x>=h.x1 and x<=h.x2 and y>=h.y1 and y<=h.y2 then return h end end end
function M.find(page,id)
  local function walk(arr) for _,e in ipairs(arr or {}) do if e.id==id then return e end; local x=walk(e.children); if x then return x end; for _,t in ipairs(e.tabs or {}) do local z=walk(t.children); if z then return z end end end end
  return walk(page.elements)
end
function M.applyPatch(page,inputs,patch)
  local method=patch.method; local a=patch.args or {}; local e=M.find(page,tostring(a[1] or ''))
  if method=='ui.setText' and e then e.text=tostring(a[2] or '')
  elseif method=='ui.setValue' then if e then e.value=a[2] end;inputs[tostring(a[1])]=a[2]
  elseif method=='ui.setVisible' and e then e.visible=a[2] and true or false end
end
return M
]==],
  ["/spawnnet/client/sdk.lua"]=[==[local net=dofile('/spawnnet/client/net.lua')
local M={}
function M.call(service,action,payload) return net.call(service,action,payload) end
M.network={
  active=function()return net.activeNetwork()end,
  list=function()return net.networks()end,
  discover=function(timeout)return net.discoverNetworks(timeout)end,
  switch=function(id)return net.setActiveNetwork(id)end,
}
M.dns={resolve=function(domain)return net.call('dns','resolve',{domain=domain})end,register=function(domain,title)return net.call('dns','register',{domain=domain,title=title})end,mine=function()return net.call('dns','listMine',{})end}
M.web={get=function(domain,path)return net.call('web','getPage',{domain=domain,path=path or '/'},{noAuth=true})end,action=function(domain,event,input,args)return net.call('web','runAction',{domain=domain,event=event,input=input or {},args=args or {}})end,analytics=function(domain)return net.call('web','analytics',{domain=domain})end}
M.storage={get=function(domain,key)return net.call('storage','get',{domain=domain,key=key})end,set=function(domain,key,value)return net.call('storage','set',{domain=domain,key=key,value=value})end,inc=function(domain,key,amount)return net.call('storage','inc',{domain=domain,key=key,amount=amount})end}
M.db={get=function(domain,c,key)return net.call('db','get',{domain=domain,collection=c,key=key})end,set=function(domain,c,key,value)return net.call('db','set',{domain=domain,collection=c,key=key,value=value})end,insert=function(domain,c,value)return net.call('db','insert',{domain=domain,collection=c,value=value})end,list=function(domain,c,limit)return net.call('db','list',{domain=domain,collection=c,limit=limit})end}
M.mail={send=function(to,subject,body)return net.call('mail','send',{to=to,subject=subject,body=body})end,inbox=function(limit)return net.call('mail','inbox',{limit=limit})end}
M.events={poll=function(limit)return net.call('event','poll',{limit=limit})end,peek=function()return net.call('event','peek',{})end,emit=function(to,t,data)return net.call('event','emit',{to=to,type=t,data=data})end}
M.jobs={
  submit=function(domain,queue,action,payload)return net.call('jobs','submit',{domain=domain,queue=queue,jobAction=action,payload=payload or {}})end,
  poll=function(domain,queue,limit)return net.call('jobs','poll',{domain=domain,queue=queue,limit=limit})end,
  claim=function(domain,id,worker)return net.call('jobs','claim',{domain=domain,id=id,worker=worker})end,
  progress=function(domain,id,progress,message)return net.call('jobs','progress',{domain=domain,id=id,progress=progress,message=message})end,
  complete=function(domain,id,result,message)return net.call('jobs','complete',{domain=domain,id=id,result=result or {},message=message})end,
  fail=function(domain,id,err)return net.call('jobs','fail',{domain=domain,id=id,error=err})end,
  status=function(domain,id)return net.call('jobs','status',{domain=domain,id=id})end,
  list=function(domain,limit)return net.call('jobs','list',{domain=domain,limit=limit})end,
}
M.blob={put=function(domain,key,data,mime,public)return net.call('blob','put',{domain=domain,key=key,data=data,mime=mime,public=public})end,get=function(domain,key)return net.call('blob','get',{domain=domain,key=key})end,list=function(domain)return net.call('blob','list',{domain=domain})end,delete=function(domain,key)return net.call('blob','delete',{domain=domain,key=key})end}
M.search=function(q)return net.call('search','query',{q=q},{noAuth=true})end
M.forum={boards=function()return net.call('forum','boards',{})end,threads=function(board)return net.call('forum','threads',{board=board})end,thread=function(board,id)return net.call('forum','getThread',{board=board,id=id})end,post=function(board,title,body)return net.call('forum','newThread',{board=board,title=title,body=body})end,reply=function(board,id,body)return net.call('forum','reply',{board=board,id=id,body=body})end}
M.chat={read=function(room,limit)return net.call('chat','read',{room=room,limit=limit})end,send=function(room,text)return net.call('chat','send',{room=room,text=text})end}
M.telemetry={push=function(domain,stream,data)return net.call('telemetry','push',{domain=domain,stream=stream,data=data,computer=os.getComputerID()})end,get=function(domain,stream,limit)return net.call('telemetry','get',{domain=domain,stream=stream,limit=limit})end,last=function(domain,stream)local p,e=net.call('telemetry','get',{domain=domain,stream=stream,limit=1});if not p then return nil,e end;return p.last end}
M.nodes={summary=function()return net.call('nodes','summary',{})end,approve=function(id,name)return net.call('nodes','approve',{id=id,name=name})end,rebalance=function()return net.call('nodes','rebalance',{})end,remove=function(id)return net.call('nodes','remove',{id=id})end}
M.packages={
  manifest=function(domain,name)return net.call('package','manifest',{domain=domain,name=name},{noAuth=true})end,
  get=function(domain,name)return net.call('package','get',{domain=domain,name=name},{noAuth=true})end,
  list=function(domain)return net.call('package','list',{domain=domain},{noAuth=true})end,
  publish=function(domain,name,spec)spec=spec or{};spec.domain=domain;spec.name=name;return net.call('package','publish',spec)end,
  delete=function(domain,name)return net.call('package','delete',{domain=domain,name=name})end
}
return M
]==],
  ["/spawnnet/client/search.lua"]=[==[local gui=dofile('/spawnnet/client/gui.lua')
local net=dofile('/spawnnet/client/net.lua')
local q=(...) or ''
if q==''then q=gui.prompt('SEARCH','Search network:','')end
if q==''then return end
local p,e=net.call('search','query',{q=q},{noAuth=true});if not p then gui.toast(e,2)return end
local items={};for _,r in ipairs(p.results or {})do items[#items+1]={label=tostring(r.domain)..' - '..tostring(r.title),domain=r.domain}end;items[#items+1]={label='Back',action='back'}
local m=gui.menu('SEARCH: '..q,tostring(#(p.results or {}))..' result(s)',items);if m and m.domain then shell.run('/spawnnet/client/browser.lua','spn://'..m.domain)end
]==],
  ["/spawnnet/client/service_manager.lua"]=[==[-- SpawnNet application service manager 2.3.0
-- Services are supervised dynamically. Registering/removing a service while the
-- runtime is already active no longer requires a reboot.
local util=dofile('/spawnnet/lib/util.lua')
local M={};local DB='/spawnnet/services.db';local LOG='/spawnnet/service-errors.log';local HEART='/spawnnet/service-runtime.heartbeat'
local function load()return util.loadTable(DB,{})end
local function save(t)util.saveTable(DB,t)end
local function key(d,n)return tostring(d)..'/'..tostring(n)end
function M.register(domain,name,title,path,opts)
  opts=opts or{};local t=load();local old=t[key(domain,name)]or{};t[key(domain,name)]={domain=domain,name=name,title=title or name,path=path,enabled=old.enabled~=false,permissions=opts.permissions or old.permissions or{},restarts=old.restarts or 0};save(t);return true
end
function M.unregister(domain,name)local t=load();t[key(domain,name)]=nil;save(t);return true end
function M.list()return load()end
function M.setEnabled(domain,name,enabled)local t=load();local s=t[key(domain,name)];if not s then return nil,'Unknown service'end;s.enabled=enabled~=false;save(t);return true end
function M.restart(domain,name)local t=load();local s=t[key(domain,name)];if not s then return nil,'Unknown service'end;s.restartNonce=(s.restartNonce or 0)+1;save(t);return true end
local function log(s)local h=fs.open(LOG,'a');if h then h.writeLine(tostring(s));h.close()end end
local function heartbeat()local h=fs.open(HEART,'w');if h then h.write(tostring(os.clock()));h.close()end end
function M.runtimeActive()
  if not fs.exists(HEART)then return false end
  local h=fs.open(HEART,'r');if not h then return false end;local v=tonumber(h.readAll());h.close();local now=os.clock()
  return v~=nil and now>=v and now-v<4
end
local function signature(t)
  local a={};for k,s in pairs(t or{})do a[#a+1]=tostring(k)..'|'..tostring(s.enabled)..'|'..tostring(s.path)..'|'..tostring(s.restartNonce or 0)end;table.sort(a);return table.concat(a,'\n')
end
local function runOne(s)
  local runtime=dofile('/spawnnet/client/app_runtime.lua')
  local installed=util.loadTable('/spawnnet/apps/installed.db',{});local rec=installed[key(s.domain,s.name)];if rec then s.permissions=rec.permissions or s.permissions or{}end
  while true do
    if not(s and s.enabled and s.path and fs.exists(s.path))then return end
    local started=os.clock();local t0=load();local live0=t0[key(s.domain,s.name)];if live0 then live0.running=true;live0.lastStart=started;live0.lastError=nil;save(t0)end
    local ok,err=runtime.run(s,s.path,'spawnnet-service')
    if not ok then log(tostring(os.clock())..' '..tostring(s.title or s.name or s.path)..': '..tostring(err))end
    local t=load();local live=t[key(s.domain,s.name)];if live then live.running=false;live.lastStart=started;live.lastExit=os.clock();live.lastError=ok and'Exited unexpectedly'or tostring(err);live.restarts=(live.restarts or 0)+1;save(t)end
    sleep(2)
  end
end
function M.runAll()
  while true do
    heartbeat()
    local t=load();local sig=signature(t);local funcs={}
    for _,s in pairs(t)do if s.enabled and s.path then local service=s;funcs[#funcs+1]=function()runOne(service)end end end
    funcs[#funcs+1]=function()
      while true do sleep(1);heartbeat();if signature(load())~=sig then return end end
    end
    parallel.waitForAny(unpack(funcs))
    sleep(0)
  end
end
return M
]==],
  ["/spawnnet/client/services.lua"]=[==[local gui=dofile('/spawnnet/client/gui.lua')
local sm=dofile('/spawnnet/client/service_manager.lua')
local function readFile(p)local h=fs.open(p,'r');if not h then return''end;local s=h.readAll();h.close();return s end
while true do
  local reg=sm.list();local items={{label='RUNTIME // '..(sm.runtimeActive()and'ONLINE'or'OFFLINE'),disabled=true}};local names={}
  for k,s in pairs(reg)do names[#names+1]={k=k,s=s}end;table.sort(names,function(a,b)return a.k<b.k end)
  for _,x in ipairs(names)do items[#items+1]={label=(x.s.enabled and(x.s.running and'[LIVE] 'or'[ARMED] ')or'[OFF] ')..tostring(x.s.title or x.k)..'  R'..tostring(x.s.restarts or 0),service=x.s}end
  if not sm.runtimeActive()then items[#items+1]={label='ENGAGE SERVICE RUNTIME',action='start'}end
  items[#items+1]={label='Open failure log',action='log'};items[#items+1]={label='Back',action='back'}
  local m=gui.menu('SERVICE CONTROL','Supervised native application processes',items)
  if not m or m.action=='back'then return
  elseif m.action=='start'then if gui.confirm('ENGAGE SERVICES','Start the SpawnNet supervisor beneath the current CraftOS session?')then shell.run('/spawnnet/client/startup_bridge.lua');return end
  elseif m.action=='log'then local s=readFile('/spawnnet/service-errors.log');gui.viewer('SERVICE FAILURES',s~=''and s or'No recorded service failures.','SPAWNNET 2.3.0')
  elseif m.service then
    local s=m.service;local pick=gui.menu('SERVICE // '..tostring(s.title or s.name),'State: '..(s.enabled and(s.running and'LIVE'or'ARMED')or'DISABLED'),{{label=s.enabled and'Disable service'or'Enable service',action='toggle'},{label='Restart service',action='restart'},{label='Last error: '..tostring(s.lastError or'none'),disabled=true},{label='Back',action='back'}})
    if pick and pick.action=='toggle'then sm.setEnabled(s.domain,s.name,not s.enabled)elseif pick and pick.action=='restart'then sm.restart(s.domain,s.name)end
  end
end
]==],
  ["/spawnnet/client/settings.lua"]=[==[local gui=dofile('/spawnnet/client/gui.lua')
local net=dofile('/spawnnet/client/net.lua')
local util=dofile('/spawnnet/lib/util.lua')
local config=dofile('/spawnnet/lib/config.lua')
local startup=dofile('/spawnnet/client/startup_config.lua')
local function bootMode()
  local c=util.loadTable(config.clientConfig,{});return c.boot or'desktop'
end
local function chooseBoot()
  local m=gui.menu('STARTUP SEQUENCE','Choose the foreground system after boot.',{{label='Nexus Desktop [recommended]',value='desktop'},{label='Browser home',value='browser'},{label='CraftOS shell',value='shell'},{label='Disable SpawnNet startup',value='disabled'},{label='Back'}})
  if m and m.value then local c=util.loadTable(config.clientConfig,{});c.boot=m.value;util.saveTable(config.clientConfig,c);startup.apply(m.value);gui.toast('Startup: '..m.value,1,true)end
end
while true do
  local s=net.loadSession();local n=net.activeNetwork();local items={
    {label='Account - '..(s and tostring(s.user)or'Guest'),action='account'},
    {label='Network Manager',action='net'},
    {label='Installed Applications / Packages',action='packages'},
    {label='Diagnostics',action='doctor'},
    {label='Check for SpawnNet update',action='update'},
    {label='Startup sequence - '..bootMode():upper(),action='boot'},
    {label='Background service control',action='services'},
    {label='Back',action='back'},
  }
  local m=gui.menu('SPAWNNET SETTINGS','Active: '..tostring(n.name or n.id)..' ['..tostring(n.id)..']',items)
  if not m or m.action=='back'then break elseif m.action=='account'then shell.run('/spawnnet/client/account.lua')elseif m.action=='net'then shell.run('/spawnnet/client/networks.lua')elseif m.action=='packages'then shell.run('/spawnnet-packages.lua')elseif m.action=='doctor'then shell.run('/spawnnet/client/doctor.lua')elseif m.action=='update'then shell.run('/spawnnet/client/updater.lua','client')elseif m.action=='boot'then chooseBoot()elseif m.action=='services'then shell.run('/spawnnet/client/services.lua')end
end
gui.clear()
]==],
  ["/spawnnet/client/spawnnet.lua"]=[==[local ui=dofile('/spawnnet/client/ui.lua')
local net=dofile('/spawnnet/client/net.lua')
local auth=dofile('/spawnnet/client/auth_client.lua')
local config=dofile('/spawnnet/lib/config.lua')
local args={...};local cmd=args[1]
if not cmd or cmd==''or cmd=='desktop'then shell.run('/spawnnet/client/desktop.lua')
elseif cmd=='browser'or cmd=='web'then shell.run('/spawnnet/client/browser.lua',args[2]or'spn://home')
elseif cmd=='studio'then shell.run('/spawnnet/client/studio_easy.lua')
elseif cmd=='studio-advanced'then shell.run('/spawnnet/client/studio_advanced.lua')
elseif cmd=='mail'then shell.run('/spawnnet/client/apps_mail.lua')
elseif cmd=='forum'then shell.run('/spawnnet/client/apps_forum.lua')
elseif cmd=='chat'then shell.run('/spawnnet/client/apps_chat.lua',args[2]or'global')
elseif cmd=='search'then shell.run('/spawnnet/client/search.lua',args[2]or'')
elseif cmd=='networks'or cmd=='network'then shell.run('/spawnnet/client/networks.lua')
elseif cmd=='apps'then shell.run('/spawnnet/client/apps.lua')
elseif cmd=='nodes'then shell.run('/spawnnet/client/nodes.lua')
elseif cmd=='machine'or cmd=='machines'or cmd=='peripherals'then shell.run('/spawnnet/client/machines.lua')
elseif cmd=='account'then shell.run('/spawnnet/client/account.lua')
elseif cmd=='keys'then shell.run('/spawnnet/client/apps_keys.lua')
elseif cmd=='doctor'then shell.run('/spawnnet/client/doctor.lua')
elseif cmd=='telemetry'then shell.run('/spawnnet/client/telemetry_agent.lua')
elseif cmd=='update'then shell.run('/spawnnet/client/updater.lua',args[2]or'client')
elseif cmd=='packages'then shell.run('/spawnnet-packages.lua',unpack({select(2,unpack(args))}))
elseif cmd=='services'then shell.run('/spawnnet/client/services.lua')
elseif cmd=='labs'then shell.run('/spawnnet/client/labs.lua')
elseif cmd=='dev'or cmd=='developer'then shell.run('/spawnnet/client/developer.lua')
elseif cmd=='release'then shell.run('/spawnnet-release.lua')
elseif cmd=='register'then local u=args[2]or ui.prompt('Username','');local pw=args[3]or ui.prompt('Password','','*');local s,e=auth.register(u,pw,u);if s then ui.success('Registered and logged in as '..s.user)else ui.error(e)end
elseif cmd=='login'then local u=args[2]or ui.prompt('Username','');local pw=args[3]or ui.prompt('Password','','*');local s,e=auth.login(u,pw);if s then ui.success('Logged in as '..s.user)else ui.error(e)end
elseif cmd=='logout'then auth.logout();print('Logged out.')
else
 print('SpawnNet '..config.version)
 print('  spawnnet                       desktop')
 print('  spawnnet account               login / create account')
 print('  spawnnet web [url]             browser')
 print('  spawnnet studio                no-code website builder')
 print('  spawnnet networks              network manager')
 print('  spawnnet peripherals           peripheral tools')
 print('  spawnnet mail                  mail')
 print('  spawnnet search [text]         search')
 print('  spawnnet doctor                diagnostics')
 print('  spawnnet update [check|rollback]')
 print('  spawnnet packages              installed applications')
 print('  spawnnet services              background application services')
 print('  spawnnet labs                  showcase labs')
 print('  spawnnet dev                   developer workbench')
end]==],
  ["/spawnnet/client/startup_bridge.lua"]=[==[-- SpawnNet unified startup supervisor 2.3.0
-- IMPORTANT: This program MUST be launched by the existing CraftOS shell.
-- Starting rom/programs/shell.lua with os.run({}) creates a root shell, which
-- re-runs startup and recursively launches this bridge. We instead use the
-- parent shell API so the foreground shell inherits parentShell and does not
-- execute startup a second time.
local sm=dofile('/spawnnet/client/service_manager.lua')
local util=dofile('/spawnnet/lib/util.lua')
local config=dofile('/spawnnet/lib/config.lua')
if not shell or not shell.run then error('SpawnNet service bridge requires CraftOS shell context',0)end
local function services()sm.runAll()end
local function userSession()
  if fs.exists('/startup.pre-spawnnet.lua')then
    local h=fs.open('/startup.pre-spawnnet.lua','r');local old=h and h.readAll()or'';if h then h.close()end
    if not old:find('SPAWNNET_SERVICE_BRIDGE_',1,true)then pcall(function()shell.run('/startup.pre-spawnnet.lua')end)end
  end
  local cfg=util.loadTable(config.clientConfig,{boot='desktop'})
  if cfg.boot=='desktop'or cfg.boot==nil then shell.run('/spawnnet/client/spawnnet.lua','desktop')
  elseif cfg.boot=='browser'then shell.run('/spawnnet/client/browser.lua',config.defaultHome)end
  while true do
    local ok=shell.run('shell')
    if not ok then sleep(0.25)end
  end
end
parallel.waitForAll(services,userSession)
]==],
  ["/spawnnet/client/startup_config.lua"]=[==[local M={};local TARGET='/startup.lua';local PREVIOUS='/startup.pre-spawnnet.lua';local MARKER='SPAWNNET_STARTUP_2.3.0'
local function readFile(p)local h=fs.open(p,'r');if not h then return''end;local s=h.readAll();h.close();return s end
local function writeFile(p,s)local h=assert(fs.open(p,'w'));h.write(s);h.close()end
function M.enable()
  local current=readFile(TARGET);if current:find(MARKER,1,true)then return true end
  if current~=''and not current:find('SPAWNNET_',1,true)and not fs.exists(PREVIOUS)then fs.copy(TARGET,PREVIOUS)end
  writeFile(TARGET,"-- "..MARKER.."\nif not shell or not shell.run then error('SpawnNet startup requires CraftOS shell',0)end\nshell.run('/spawnnet/client/startup_bridge.lua')\n");return true
end
function M.disable()
  local current=readFile(TARGET);if not current:find('SPAWNNET_STARTUP_',1,true)then return true end
  fs.delete(TARGET);if fs.exists(PREVIOUS)then fs.copy(PREVIOUS,TARGET)end;return true
end
function M.apply(mode)if mode=='disabled'then return M.disable()end;return M.enable()end
return M
]==],
  ["/spawnnet/client/studio.lua"]=[==[shell.run('/spawnnet/client/studio_easy.lua')
]==],
  ["/spawnnet/client/studio_advanced.lua"]=[==[local util=dofile('/spawnnet/lib/util.lua')
local net=dofile('/spawnnet/client/net.lua')
local auth=dofile('/spawnnet/client/auth_client.lua')
local ui=dofile('/spawnnet/client/ui.lua')
local renderer=dofile('/spawnnet/client/renderer.lua')
local templates=dofile('/spawnnet/client/templates.lua')

local function mustLogin()
  local s=net.loadSession(); if s then return s end
  local x,e=auth.ensureLogin(); if not x then ui.error(e); return nil end; return x
end
local function chooseColor(label,current)
  local names={'white','orange','magenta','lightBlue','yellow','lime','pink','gray','lightGray','cyan','purple','blue','brown','green','red','black'}
  print(label..' current='..tostring(current or 'default'))
  for i,n in ipairs(names) do write(i..':'..n..' ') end; print(); write('Color # (blank keep): '); local v=read(); if v=='' then return current end; local n=names[tonumber(v) or 0]; return n and colors[n] or current
end
local function savePage(domain,path,page)
  local p,e=net.call('web','savePage',{domain=domain,path=path,page=page}); if not p then ui.error(e);ui.pause();return false end; return true
end
local function editAction(e)
  print('Action type: navigate / event / server / none'); write('> '); local t=read(); if t=='' or t=='none' then e.action=nil; return end
  if t=='navigate' then e.action={type='navigate',target=ui.prompt('Target',e.action and e.action.target or '/')}
  elseif t=='event' or t=='server' then e.action={type=t,event=ui.prompt('Event',e.action and e.action.event or 'click')} end
end
local function editElement(e)
  ui.clear('EDIT ELEMENT '..tostring(e.id or '')); print('Type: '..e.type)
  e.id=ui.prompt('ID',e.id or (e.type..math.random(100,999)))
  e.x=tonumber(ui.prompt('X',tostring(e.x or 1))) or e.x or 1; e.y=tonumber(ui.prompt('Y',tostring(e.y or 1))) or e.y or 1
  local w=ui.prompt('Width',tostring(e.w or 20)); e.w=tonumber(w) or w; e.h=tonumber(ui.prompt('Height',tostring(e.h or 1))) or e.h or 1
  if e.type=='text' or e.type=='heading' or e.type=='button' or e.type=='badge' or e.type=='checkbox' then e.text=ui.prompt('Text',e.text or '') end
  if e.type=='input' then e.placeholder=ui.prompt('Placeholder',e.placeholder or '') end
  if e.type=='progress' then e.value=tonumber(ui.prompt('Value',tostring(e.value or 50))) or 0; e.max=tonumber(ui.prompt('Max',tostring(e.max or 100))) or 100 end
  if e.type=='image' then e.src=ui.prompt('Asset name',e.src or 'logo') end
  if e.type=='panel' or e.type=='modal' then e.border=ui.prompt('Border? y/n',e.border and 'y' or 'n'):lower()=='y' end
  if e.type=='list' then local q=ui.prompt('Items | separated',table.concat(e.items or {},'|'));e.items={};for z in q:gmatch('[^|]+')do e.items[#e.items+1]=util.trim(z)end end
  if e.type=='select' then local s=ui.prompt('Options comma-separated',table.concat(e.options or {'One','Two'},','));e.options={};for x in s:gmatch('[^,]+')do e.options[#e.options+1]=util.trim(x) end end
  e.fg=chooseColor('Foreground',e.fg); e.bg=chooseColor('Background',e.bg)
  if e.type=='button' then editAction(e) end
end
local function newElement()
  ui.clear('ADD ELEMENT'); print('text heading button input checkbox select progress image separator panel row column table badge tabs list modal'); write('Type: '); local t=util.trim(read())
  local allowed={text=1,heading=1,button=1,input=1,checkbox=1,select=1,progress=1,image=1,separator=1,panel=1,row=1,column=1,table=1,badge=1,tabs=1,list=1,modal=1}; if not allowed[t] then return nil end
  local e={type=t,id=t..math.random(100,999),x=1,y=1,w=20,h=1,fg=colors.white,bg=colors.black}
  if t=='text' or t=='heading' or t=='button' or t=='badge' or t=='checkbox' then e.text=t end
  if t=='select' then e.options={'One','Two'} end; if t=='progress' then e.value=50;e.max=100 end; if t=='table' then e.rows={{'A','B'},{'1','2'}};e.h=4 end
  if t=='panel' or t=='row' or t=='column' or t=='modal' then e.children={} end; if t=='list' then e.items={'Item one','Item two'};e.h=3 end; if t=='tabs' then e.tabs={{title='Tab 1',children={}}};e.h=6 end
  editElement(e); return e
end
local function preview(page)
  local scroll=0
  while true do ui.clear('PREVIEW - arrows scroll, Q returns'); local _,mx=renderer.draw(page,{top=2,bottom=select(2,term.getSize()),scroll=scroll,inputs={},assetLoader=function()return nil end}); local ev={os.pullEvent('key')}; if ev[2]==keys.q then break elseif ev[2]==keys.up then scroll=math.max(0,scroll-1) elseif ev[2]==keys.down then scroll=math.min(mx,scroll+1) end end
end
local function rawEdit(page)
  util.ensureDir('/spawnnet/tmp'); local f='/spawnnet/tmp/page.lua'; util.writeFile(f,'return '..textutils.serialize(page)); shell.run('edit',f); local fn,err=loadfile(f); if not fn then ui.error(err);ui.pause();return page end; local ok,p=pcall(fn); if not ok or type(p)~='table' then ui.error('Edited page did not return a table');ui.pause();return page end; return p
end
local function pageDesigner(domain,path,page)
  while true do
    ui.clear('STUDIO '..domain..path); print('Title: '..tostring(page.title)); print('Elements: '..#(page.elements or {})); print('1 Preview  2 Add  3 Edit  4 Delete  5 Raw code  6 Page settings  7 Save  0 Back')
    local c=read()
    if c=='0' then return page
    elseif c=='1' then preview(page)
    elseif c=='2' then local e=newElement(); if e then page.elements[#page.elements+1]=e end
    elseif c=='3' then for i,e in ipairs(page.elements) do print(i..') '..tostring(e.type)..' '..tostring(e.id or '')..' @'..tostring(e.x)..','..tostring(e.y)) end; write('Element #: '); local i=tonumber(read()); if i and page.elements[i] then editElement(page.elements[i]) end
    elseif c=='4' then for i,e in ipairs(page.elements) do print(i..') '..tostring(e.type)..' '..tostring(e.id or '')) end;write('Delete #: ');local i=tonumber(read());if i and page.elements[i] then table.remove(page.elements,i) end
    elseif c=='5' then page=rawEdit(page)
    elseif c=='6' then page.title=ui.prompt('Page title',page.title or 'Untitled'); page.background=chooseColor('Page background',page.background or colors.black)
    elseif c=='7' then if savePage(domain,path,page) then ui.success('Draft saved.');ui.pause() end end
  end
end
local function editScripts(domain,site)
  util.ensureDir('/spawnnet/tmp'); local c='/spawnnet/tmp/client.ss';local s='/spawnnet/tmp/server.ss';util.writeFile(c,site.clientScript or 'event load\n  call ui.alert "Welcome"\nend\n');util.writeFile(s,site.serverScript or 'event ping\n  call storage.inc "pings" 1 -> count\n  call ui.alert "Server ping ${count}"\nend\n')
  while true do local _,choice=ui.menu('SCRIPTS',{{label='Edit client SpawnScript'},{label='Edit server SpawnScript'},{label='Save both'},{label='Back'}}); if choice.label:find('client') then shell.run('edit',c) elseif choice.label:find('server') then shell.run('edit',s) elseif choice.label=='Save both' then local p,e=net.call('web','saveScripts',{domain=domain,clientScript=util.readFile(c),serverScript=util.readFile(s)});if p then ui.success('Scripts saved')else ui.error(e)end;ui.pause() else return end end
end
local function assets(domain)
  while true do local p,e=net.call('web','listAssets',{domain=domain});ui.clear('ASSETS '..domain);if p then for i,a in ipairs(p.assets)do print(i..') '..a.name..' '..a.size..'b '..a.mime)end else ui.error(e)end;print();print('1 Upload local file  2 Delete  0 Back');local c=read();if c=='0'then return elseif c=='1'then local path=ui.prompt('Local file path','');if fs.exists(path)then local name=ui.prompt('Asset name',fs.getName(path));local mime=ui.prompt('MIME','image/nfp');local q,er=net.call('web','putAsset',{domain=domain,name=name,mime=mime,data=util.readFile(path)});if not q then ui.error(er)else ui.success('Uploaded')end;ui.pause()else ui.error('File not found');ui.pause()end elseif c=='2'then local name=ui.prompt('Asset name','');net.call('web','deleteAsset',{domain=domain,name=name})end end
end
local function revisions(domain)
  local p,e=net.call('web','history',{domain=domain});ui.clear('REVISION HISTORY');if not p then ui.error(e);ui.pause();return end;for i,r in ipairs(p.revisions)do print(i..') '..r.id..' '..tostring(r.note or ''))end;print();write('Restore # or blank: ');local n=tonumber(read());if n and p.revisions[n]then local q,er=net.call('web','restore',{domain=domain,id=p.revisions[n].id});if q then ui.success('Restored into draft; publish when ready.')else ui.error(er)end;ui.pause()end
end
local function siteDashboard(domain)
  while true do
    local got,e=net.call('web','getSite',{domain=domain}); if not got then ui.error(e);ui.pause();return end; local site=got.site
    local _,m=ui.menu('SITE '..domain,{{label='Pages'},{label='Scripts'},{label='Assets'},{label='Settings'},{label='Publish draft'},{label='Revision history'},{label='Analytics'},{label='Back'}})
    if m.label=='Back' then return
    elseif m.label=='Pages' then
      ui.clear('PAGES'); local paths={};for p in pairs(site.draft.pages or {})do paths[#paths+1]=p end;table.sort(paths);for i,p in ipairs(paths)do print(i..') '..p..' - '..tostring(site.draft.pages[p].title))end;print('N) New page');write('Select: ');local c=read();if c:lower()=='n'then local path=ui.prompt('Path','/new');local pg=templates.blank(ui.prompt('Title','New Page'));pageDesigner(domain,path,pg)else local i=tonumber(c);if i and paths[i]then pageDesigner(domain,paths[i],util.deepcopy(site.draft.pages[paths[i]]))end end
    elseif m.label=='Scripts' then editScripts(domain,site)
    elseif m.label=='Assets' then assets(domain)
    elseif m.label=='Settings' then local title=ui.prompt('Title',site.title);local desc=ui.prompt('Description',site.description or '');local tags=ui.prompt('Tags comma-separated',table.concat(site.tags or {},','));local ta={};for x in tags:gmatch('[^,]+')do ta[#ta+1]=util.trim(x)end;local p2,er=net.call('web','settings',{domain=domain,title=title,description=desc,tags=ta});if not p2 then ui.error(er)end
    elseif m.label=='Publish draft' then local note=ui.prompt('Revision note','');local p2,er=net.call('web','publish',{domain=domain,note=note});if p2 then ui.success('Published '..domain)else ui.error(er)end;ui.pause()
    elseif m.label=='Revision history' then revisions(domain)
    elseif m.label=='Analytics' then local a,er=net.call('web','analytics',{domain=domain});ui.clear('ANALYTICS');if a then print('Views: '..a.analytics.views);print('Unique computers: '..a.analytics.unique);for p,n in pairs(a.analytics.pages or {})do print(p..': '..n)end else ui.error(er)end;ui.pause() end
  end
end
local function createSite()
  ui.clear('CREATE SITE');local domain=ui.prompt('Domain','');local title=ui.prompt('Site title',domain);local p,e=net.call('dns','register',{domain=domain,title=title});if not p then ui.error(e);ui.pause();return end
  print('Template: 1 Personal 2 Shop 3 Company 4 Wiki 5 News 6 Blank');local c=read();local fn=({['1']='personal',['2']='shop',['3']='company',['4']='wiki',['5']='news',['6']='blank'})[c]or'blank';local page=templates[fn](title);savePage(p.domain,'/',page);net.call('web','savePage',{domain=p.domain,path='/about',page=templates.blank('About '..title)});net.call('web','publish',{domain=p.domain,note='Initial site'});ui.success('Created spn://'..p.domain);ui.pause()
end

if not mustLogin() then return end
while true do
  local p,e=net.call('dns','listMine',{}); if not p then ui.error(e);ui.pause();return end
  local items={{label='Create new site'}};for _,d in ipairs(p.domains or {})do items[#items+1]={label=d.domain..' - '..d.title,domain=d.domain}end;items[#items+1]={label='Exit'}
  local _,m=ui.menu('SPAWNNET STUDIO',items);if m.label=='Create new site'then createSite()elseif m.label=='Exit'then break else siteDashboard(m.domain)end
end
ui.clear()
]==],
  ["/spawnnet/client/studio_easy.lua"]=[==[local gui=dofile('/spawnnet/client/gui.lua')
local net=dofile('/spawnnet/client/net.lua')
local auth=dofile('/spawnnet/client/auth_client.lua')
local util=dofile('/spawnnet/lib/util.lua')
local C=colors
local function needLogin()if net.loadSession()then return true end;shell.run('/spawnnet/client/account.lua');return net.loadSession()~=nil end
local function copy(v)if type(v)~='table'then return v end;local o={};for k,x in pairs(v)do o[copy(k)]=copy(x)end;return o end
local function starter(kind,title)
  if kind=='wiki'then return{{kind='heading',text=title},{kind='text',text='Welcome to the knowledge base.'},{kind='button',text='ARTICLES',target='/articles'},{kind='divider'},{kind='text',text='Add headings, paragraphs, images, lists, tables, inputs and links from Easy Studio.'}}
  elseif kind=='dashboard'then return{{kind='heading',text=title},{kind='badge',text='SYSTEM ONLINE'},{kind='progress',value=65},{kind='text',text='Use hosted SpawnScript or Advanced Studio to connect live data.'}}
  elseif kind=='company'then return{{kind='heading',text=title},{kind='text',text='Tell visitors what you build and why it matters.'},{kind='button',text='ABOUT',target='/about'},{kind='button',text='CONTACT',target='/contact'}}
  else return{{kind='heading',text=title},{kind='text',text='Welcome to my SpawnNet site.'},{kind='divider'},{kind='text',text='Edit this page with Easy Studio. No Lua required.'}}end
end
local function render(siteTitle,pageTitle,blocks)
  local e={{type='panel',x=1,y=1,w='100%',h=4,bg=C.gray,children={{type='heading',x=2,y=1,w=47,text=siteTitle,fg=C.yellow,bg=C.gray},{type='text',x=2,y=2,w=47,text=pageTitle,fg=C.lightGray,bg=C.gray,align='center'}}}};local y=6
  for _,b in ipairs(blocks or{})do
    if b.kind=='heading'then e[#e+1]={type='heading',x=3,y=y,w=45,text=b.text or'Heading',fg=C.yellow,align='left'};y=y+2
    elseif b.kind=='text'then local h=math.max(2,#util.wrapText(tostring(b.text or''),45));e[#e+1]={type='text',x=3,y=y,w=45,h=h,text=b.text or''};y=y+h+1
    elseif b.kind=='button'then e[#e+1]={type='button',x=3,y=y,w=45,text=b.text or'LINK',bg=C.blue,action={type='navigate',target=b.target or'/'}};y=y+2
    elseif b.kind=='image'then e[#e+1]={type='image',x=3,y=y,w=tonumber(b.w)or 20,h=tonumber(b.h)or 8,src=b.src or''};y=y+(tonumber(b.h)or 8)+1
    elseif b.kind=='divider'then e[#e+1]={type='divider',x=3,y=y,w=45};y=y+2
    elseif b.kind=='badge'then e[#e+1]={type='badge',x=3,y=y,w=45,text=b.text or'BADGE',bg=C.lime,fg=C.black,align='center'};y=y+2
    elseif b.kind=='input'then e[#e+1]={type='input',id=b.id or('input'..y),x=3,y=y,w=45,value=b.value or'',placeholder=b.placeholder or'Enter text...'};y=y+2
    elseif b.kind=='checkbox'then e[#e+1]={type='checkbox',id=b.id or('check'..y),x=3,y=y,w=45,text=b.text or'Option',checked=b.checked and true or false};y=y+2
    elseif b.kind=='progress'then e[#e+1]={type='progress',id=b.id or('progress'..y),x=3,y=y,w=45,value=tonumber(b.value)or 0,max=tonumber(b.max)or 100};y=y+2
    elseif b.kind=='list'then e[#e+1]={type='list',x=3,y=y,w=45,h=math.max(2,#(b.items or{})),items=copy(b.items or{})};y=y+math.max(2,#(b.items or{}))+1
    elseif b.kind=='table'then e[#e+1]={type='table',x=3,y=y,w=45,h=math.max(3,#(b.rows or{})+1),rows=copy(b.rows or{}),widths=copy(b.widths or{22,23})};y=y+math.max(3,#(b.rows or{})+1)+1 end
  end
  return{title=pageTitle,background=C.black,elements=e,easyBlocks=copy(blocks or{}),easyPageTitle=pageTitle}
end
local function fromPage(page)
  if type(page.easyBlocks)=='table'then return copy(page.easyBlocks),page.easyPageTitle or page.title or'Page'end
  local blocks={};for _,e in ipairs(page.elements or{})do if e.type=='heading'then blocks[#blocks+1]={kind='heading',text=e.text}elseif e.type=='text'then blocks[#blocks+1]={kind='text',text=e.text}elseif e.type=='button'then blocks[#blocks+1]={kind='button',text=e.text,target=e.action and e.action.target or'/'}elseif e.type=='image'then blocks[#blocks+1]={kind='image',src=e.src,w=e.w,h=e.h}elseif e.type=='divider'then blocks[#blocks+1]={kind='divider'}elseif e.type=='badge'then blocks[#blocks+1]={kind='badge',text=e.text}end end;return blocks,page.title or'Page'
end
local function addBlock(blocks)
  local m=gui.menu('ADD BLOCK','Choose a page component.',{{label='Heading',kind='heading'},{label='Paragraph / text',kind='text'},{label='Button / hyperlink',kind='button'},{label='Image asset',kind='image'},{label='Divider',kind='divider'},{label='Badge',kind='badge'},{label='Input field',kind='input'},{label='Checkbox',kind='checkbox'},{label='Progress bar',kind='progress'},{label='List',kind='list'},{label='Table',kind='table'},{label='Cancel'}});if not m or not m.kind then return end
  local b={kind=m.kind}
  if m.kind=='heading'then b.text=gui.prompt('HEADING','Text:','New Heading')
  elseif m.kind=='text'then b.text=gui.multiline('PARAGRAPH - F2 SAVE','Write your text here.');if b.text==nil then return end
  elseif m.kind=='button'then b.text=gui.prompt('BUTTON','Button text:','OPEN PAGE');b.target=gui.prompt('BUTTON','Target URL or /page:','/');
  elseif m.kind=='image'then b.src=gui.prompt('IMAGE','Asset name:','image');b.w=tonumber(gui.prompt('IMAGE','Width:','20'))or 20;b.h=tonumber(gui.prompt('IMAGE','Height:','8'))or 8
  elseif m.kind=='badge'then b.text=gui.prompt('BADGE','Text:','NEW')
  elseif m.kind=='input'then b.id=util.safeName(gui.prompt('INPUT','Field ID:','field'),24);b.placeholder=gui.prompt('INPUT','Placeholder:','Enter text...')
  elseif m.kind=='checkbox'then b.id=util.safeName(gui.prompt('CHECKBOX','Field ID:','option'),24);b.text=gui.prompt('CHECKBOX','Label:','Option')
  elseif m.kind=='progress'then b.id=util.safeName(gui.prompt('PROGRESS','Field ID:','progress'),24);b.value=tonumber(gui.prompt('PROGRESS','Value:','50'))or 50;b.max=tonumber(gui.prompt('PROGRESS','Maximum:','100'))or 100
  elseif m.kind=='list'then local raw=gui.multiline('LIST - ONE ITEM PER LINE','First item\nSecond item');if raw==nil then return end;b.items={};for line in (raw..'\n'):gmatch('(.-)\n')do if line~=''then b.items[#b.items+1]=line end end
  elseif m.kind=='table'then local raw=gui.multiline('TABLE - USE | BETWEEN COLUMNS','Name | Value\nExample | 42');if raw==nil then return end;b.rows={};for line in (raw..'\n'):gmatch('(.-)\n')do if line~=''then local row={};for cell in (line..'|'):gmatch('(.-)%|')do row[#row+1]=util.trim(cell)end;b.rows[#b.rows+1]=row end end;b.widths={22,23}
  end
  blocks[#blocks+1]=b
end
local function editBlock(b)
  if b.kind=='heading'or b.kind=='badge'then b.text=gui.prompt('EDIT '..b.kind:upper(),'Text:',b.text or'')
  elseif b.kind=='text'then local x=gui.multiline('EDIT TEXT - F2 SAVE',b.text or'');if x~=nil then b.text=x end
  elseif b.kind=='button'then b.text=gui.prompt('EDIT BUTTON','Text:',b.text or'');b.target=gui.prompt('EDIT BUTTON','Target:',b.target or'/')
  elseif b.kind=='image'then b.src=gui.prompt('EDIT IMAGE','Asset name:',b.src or'');b.w=tonumber(gui.prompt('EDIT IMAGE','Width:',tostring(b.w or 20)))or b.w;b.h=tonumber(gui.prompt('EDIT IMAGE','Height:',tostring(b.h or 8)))or b.h
  elseif b.kind=='input'then b.placeholder=gui.prompt('EDIT INPUT','Placeholder:',b.placeholder or'')
  elseif b.kind=='checkbox'then b.text=gui.prompt('EDIT CHECKBOX','Label:',b.text or'')
  elseif b.kind=='progress'then b.value=tonumber(gui.prompt('EDIT PROGRESS','Value:',tostring(b.value or 0)))or b.value;b.max=tonumber(gui.prompt('EDIT PROGRESS','Maximum:',tostring(b.max or 100)))or b.max
  elseif b.kind=='list'then local x=gui.multiline('EDIT LIST - F2 SAVE',table.concat(b.items or{},'\n'));if x~=nil then b.items={};for line in (x..'\n'):gmatch('(.-)\n')do if line~=''then b.items[#b.items+1]=line end end end
  elseif b.kind=='table'then local lines={};for _,r in ipairs(b.rows or{})do lines[#lines+1]=table.concat(r,' | ')end;local x=gui.multiline('EDIT TABLE - F2 SAVE',table.concat(lines,'\n'));if x~=nil then b.rows={};for line in (x..'\n'):gmatch('(.-)\n')do if line~=''then local r={};for c in (line..'|'):gmatch('(.-)%|')do r[#r+1]=util.trim(c)end;b.rows[#b.rows+1]=r end end end end
end
local function blockLabel(b,i)return tostring(i)..'. '..tostring(b.kind):upper()..' - '..tostring(b.text or b.src or b.placeholder or'')end
local function pageEditor(domain,site,path,page)
  local blocks,pageTitle=fromPage(page)
  while true do
    local items={};for i,b in ipairs(blocks)do items[#items+1]={label=blockLabel(b,i),index=i}end;items[#items+1]={label='+ Add block',action='add'};items[#items+1]={label='Preview this draft page',action='preview'};items[#items+1]={label='Rename page title',action='title'};items[#items+1]={label='Save page',action='save'};items[#items+1]={label='Back',action='back'}
    local m=gui.menu('PAGE EDITOR '..path,pageTitle..'  |  '..#blocks..' blocks',items)
    if not m or m.action=='back'then return elseif m.action=='add'then addBlock(blocks)elseif m.action=='title'then pageTitle=gui.prompt('PAGE TITLE','Title:',pageTitle)
    elseif m.action=='save'then local p,e=net.call('web','savePage',{domain=domain,path=path,page=render(site.title or domain,pageTitle,blocks)});gui.toast(p and'Page saved to draft.'or tostring(e),2,p~=nil)
    elseif m.action=='preview'then local p,e=net.call('web','savePage',{domain=domain,path=path,page=render(site.title or domain,pageTitle,blocks)});if p then shell.run('/spawnnet/client/browser.lua','spn://'..domain..path)else gui.toast(tostring(e),2,false)end
    elseif m.index then local b=blocks[m.index];local a=gui.menu('BLOCK '..m.index,tostring(b.kind),{{label='Edit',action='edit'},{label='Move up',action='up',disabled=m.index==1},{label='Move down',action='down',disabled=m.index==#blocks},{label='Delete',action='delete'},{label='Back',action='back'}});if a and a.action=='edit'then editBlock(b)elseif a and a.action=='up'then blocks[m.index],blocks[m.index-1]=blocks[m.index-1],blocks[m.index]elseif a and a.action=='down'then blocks[m.index],blocks[m.index+1]=blocks[m.index+1],blocks[m.index]elseif a and a.action=='delete'and gui.confirm('DELETE BLOCK','Delete this '..tostring(b.kind)..' block?')then table.remove(blocks,m.index)end end
  end
end
local function pageManager(domain,site)
  while true do local got,e=net.call('web','getSite',{domain=domain});if not got then gui.toast(tostring(e),2,false);return end;site=got.site;local pages=(site.draft or{}).pages or{};local keys={};for p in pairs(pages)do keys[#keys+1]=p end;table.sort(keys);local items={};for _,p in ipairs(keys)do items[#items+1]={label=p..' - '..tostring(pages[p].title or''),path=p,page=pages[p]}end;items[#items+1]={label='+ Add page',action='add'};items[#items+1]={label='Back',action='back'};local m=gui.menu('PAGES',#keys..' draft page(s)',items);if not m or m.action=='back'then return elseif m.path then pageEditor(domain,site,m.path,m.page)elseif m.action=='add'then local path=gui.prompt('ADD PAGE','Path:','/new-page');if path~=''then if path:sub(1,1)~='/'then path='/'..path end;local title=gui.prompt('ADD PAGE','Page title:','New Page');local pg=render(site.title or domain,title,{{kind='heading',text=title},{kind='text',text='Start writing here.'},{kind='button',text='HOME',target='/'}});local ok,er=net.call('web','savePage',{domain=domain,path=path,page=pg});gui.toast(ok and'Page added.'or tostring(er),2,ok~=nil)end end end
end
local function uploadAsset(domain)
  local path=gui.prompt('UPLOAD IMAGE','Local NFP/text image file path:','');if path==''or not fs.exists(path)then gui.toast('File not found.',2,false);return end;local name=util.safeName(gui.prompt('UPLOAD IMAGE','Asset name:',fs.getName(path)),48);local h=fs.open(path,'r');local data=h and h.readAll()or nil;if h then h.close()end;if not data then gui.toast('Could not read file.',2,false);return end;local ok,e=net.call('web','putAsset',{domain=domain,name=name,mime='image/nfp',data=data});gui.toast(ok and('Uploaded asset '..name)or tostring(e),2,ok~=nil)
end
local function createSite()
  local domain=util.safeName(gui.prompt('CREATE WEBSITE','Domain after spn://',''),32);if domain==''then return end;local title=gui.prompt('CREATE WEBSITE','Site title:',domain);local pick=gui.menu('STARTER','Choose a starting layout.',{{label='Personal',kind='personal'},{label='Company / organization',kind='company'},{label='Wiki / knowledge base',kind='wiki'},{label='Dashboard',kind='dashboard'}});if not pick then return end;local r,e=net.call('dns','register',{domain=domain,title=title});if not r then gui.toast(tostring(e),2,false);return end;local home=render(title,'Home',starter(pick.kind,title));net.call('web','savePage',{domain=domain,path='/',page=home});net.call('web','settings',{domain=domain,title=title,description='Built with SpawnNet Easy Studio',tags={pick.kind,'spawnnet'}});net.call('web','publish',{domain=domain,note='Initial Easy Studio site'});gui.toast('Published spn://'..domain,2,true)
end
local function editSite(domain)
  while true do local got,e=net.call('web','getSite',{domain=domain});if not got then gui.toast(tostring(e),2,false);return end;local site=got.site;local m=gui.menu('STUDIO - '..domain,tostring(site.title or domain),{{label='Pages & block editor',action='pages'},{label='Upload NFP image asset',action='asset'},{label='Preview published site',action='preview'},{label='Publish draft',action='publish'},{label='Advanced Studio / scripts / raw layout',action='advanced'},{label='Back',action='back'}});if not m or m.action=='back'then return elseif m.action=='pages'then pageManager(domain,site)elseif m.action=='asset'then uploadAsset(domain)elseif m.action=='preview'then shell.run('/spawnnet/client/browser.lua','spn://'..domain)elseif m.action=='publish'then local note=gui.prompt('PUBLISH','Revision note:','Easy Studio update');local ok,er=net.call('web','publish',{domain=domain,note=note});gui.toast(ok and'Published.'or tostring(er),2,ok~=nil)elseif m.action=='advanced'then shell.run('/spawnnet/client/studio_advanced.lua')end end
end
if not needLogin()then return end
while true do local p,e=net.call('dns','listMine',{});if not p then gui.toast(tostring(e),2,false);return end;local items={{label='+ Create website',action='create'}};for _,d in ipairs(p.domains or{})do items[#items+1]={label=tostring(d.domain)..' - '..tostring(d.title),domain=d.domain}end;items[#items+1]={label='Back',action='back'};local m=gui.menu('EASY STUDIO','No-code pages with reusable blocks.',items);if not m or m.action=='back'then break elseif m.action=='create'then createSite()elseif m.domain then editSite(m.domain)end end
gui.clear()]==],
  ["/spawnnet/client/telemetry_agent.lua"]=[==[local net=dofile('/spawnnet/client/net.lua');local auth=dofile('/spawnnet/client/auth_client.lua');local util=dofile('/spawnnet/lib/util.lua')
local cfgPath='/spawnnet/telemetry.cfg'
local cfg=util.loadTable(cfgPath,{domain='mysite',stream='machines',interval=10,apiKeyId='',apiKeySecret='',fields={example={peripheral='left',method='getEnergyStored'}}})
if not fs.exists(cfgPath)then util.saveTable(cfgPath,cfg);print('Created '..cfgPath..'. Edit it, then run again.');return end
if not net.loadSession()then local s,e;if cfg.apiKeyId and cfg.apiKeyId~=''and cfg.apiKeySecret and cfg.apiKeySecret~=''then s,e=auth.apiLogin(cfg.apiKeyId,cfg.apiKeySecret)else write('SpawnNet username: ');local u=read();write('Password: ');s,e=auth.login(u,read('*'))end;if not s then printError(e)return end end
print('Telemetry agent -> spn://'..cfg.domain..' / '..cfg.stream)
while true do local data={};for name,f in pairs(cfg.fields or {})do local ok,val=pcall(peripheral.call,f.peripheral,f.method,unpack(f.args or {}));data[name]=ok and val or {error=tostring(val)} end;data.online=true;data.computer=os.getComputerID();local p,e=net.call('telemetry','push',{domain=cfg.domain,stream=cfg.stream,data=data,computer=os.getComputerID()});if not p then printError(e)else print('pushed '..tostring(os.time()))end;sleep(tonumber(cfg.interval)or 10)end
]==],
  ["/spawnnet/client/templates.lua"]=[==[local M={}
local function base(title,subtitle)
  return {title=title,background=colors.black,elements={
    {type='panel',id='header',x=1,y=1,w='100%',h=3,bg=colors.gray,children={
      {type='heading',id='title',x=2,y=1,w=47,h=1,text=title,fg=colors.yellow,bg=colors.gray,align='center'},
      {type='text',id='subtitle',x=2,y=2,w=47,h=1,text=subtitle or '',fg=colors.white,bg=colors.gray,align='center'},
    }},
    {type='text',id='intro',x=3,y=6,w=45,h=4,text='Edit this page in SpawnNet Studio. You can change every element, add images/forms/tables, and attach client or server actions.'},
    {type='button',id='about',x=3,y=12,w=14,text='About',action={type='navigate',target='/about'}},
  }}
end
function M.blank(title) return {title=title or 'Untitled',background=colors.black,elements={}} end
function M.personal(title) local p=base(title,'Personal site'); p.elements[#p.elements+1]={type='badge',x=3,y=14,w=20,text='Welcome!',fg=colors.black,bg=colors.lime}; return p end
function M.company(title) local p=base(title,'Company / organization'); p.elements[#p.elements+1]={type='button',x=19,y=12,w=14,text='Products',action={type='navigate',target='/products'}}; p.elements[#p.elements+1]={type='button',x=35,y=12,w=14,text='Contact',action={type='navigate',target='/contact'}}; return p end
function M.shop(title) local p=base(title,'Storefront / catalog'); p.elements[#p.elements+1]={type='table',id='inventory',x=3,y=11,w=45,h=5,rows={{'Item','Stock','Trade / Price'},{'Example','12','Ask seller'}},widths={21,9,15}}; return p end
function M.wiki(title) local p=base(title,'Knowledge base'); p.elements[#p.elements+1]={type='input',id='searchBox',x=3,y=11,w=30,placeholder='Search wiki...'}; p.elements[#p.elements+1]={type='button',x=35,y=11,w=12,text='Search',action={type='event',event='search'}}; return p end
function M.news(title) local p=base(title,'News / announcements'); p.elements[#p.elements+1]={type='heading',x=3,y=11,w=45,text='Latest Story',align='left'}; p.elements[#p.elements+1]={type='text',x=3,y=13,w=45,h=5,text='Write your latest article here.'}; return p end
return M
]==],
  ["/spawnnet/client/theme.lua"]=[==[local C=colors
return{
  name='VOID SIGNAL',
  void=C.black,ink=C.white,muted=C.lightGray,dim=C.gray,
  chrome=C.purple,accent=C.cyan,hot=C.blue,success=C.lime,
  warning=C.orange,danger=C.red,panel=C.gray,field=C.lightGray,
  logo='SN//',version='2.3.0'
}
]==],
  ["/spawnnet/client/ui.lua"]=[==[-- Compatibility facade: legacy screens now inherit the 2.3 visual system.
local gui=dofile('/spawnnet/client/gui.lua')
local M={}
function M.clear(title)gui.clear();if title then gui.bar(title)end end
function M.center(y,text,fg,bg)local w=select(1,term.getSize());gui.text(1,y,w,text,fg,bg,'center')end
function M.prompt(label,default,mask)return gui.prompt('SN// INPUT',label,default,mask)end
function M.menu(title,items)local item,index=gui.menu(title,nil,items,{footer='UP/DOWN navigate   ENTER engage   Q return'});return index,item end
function M.pause(msg)gui.status(msg or'Press any key to continue');os.pullEvent('key')end
function M.error(msg)local w,h=term.getSize();gui.text(2,math.max(2,h-2),w-2,'ERROR // '..tostring(msg),colors.white,colors.red);sleep(1.25)end
function M.success(msg)local w,h=term.getSize();gui.text(2,math.max(2,h-2),w-2,'SUCCESS // '..tostring(msg),colors.black,colors.lime);sleep(.75)end
return M
]==],
  ["/spawnnet/client/updater.lua"]=[==[-- SpawnNet transactional system updater 2.3.0
local net=dofile('/spawnnet/client/net.lua')
local util=dofile('/spawnnet/lib/util.lua')
local crypto=dofile('/spawnnet/lib/crypto.lua')
local auth=dofile('/spawnnet/client/auth_client.lua')
local arg=(...)or'client'
local mode='update'
if arg=='check'or arg=='rollback'then mode=arg;arg='client'end
local NAME=arg
local UPDATE='/spawnnet/update'
local BACKUPS=UPDATE..'/backups/'..NAME
local LAST=UPDATE..'/last-'..NAME..'.db'
local VERSION='/spawnnet/version/'..NAME..'-release.txt'
local function ensure(path)if path==''or path=='/'or fs.exists(path)then return end;local p=fs.getDir(path);if p and p~=''then ensure(p)end;fs.makeDir(path)end
local function clean(p)p=tostring(p or''):gsub('\\','/'):gsub('^/+','');if p==''then return nil end;for x in p:gmatch('[^/]+')do if x=='.'or x=='..'then return nil end end;return p end
local function allowed(p)return p:sub(1,16)=='spawnnet/client/'or p:sub(1,13)=='spawnnet/lib/'or p=='spawnnet.lua'or p=='web.lua'or p=='studio.lua'or p=='spawnnet-packages.lua'or p=='spawnnet-release.lua'end
local function hash(pkg)local paths={};for p in pairs(pkg.files or{})do paths[#paths+1]=p end;table.sort(paths);local parts={tostring(pkg.name or''),tostring(pkg.version or''),tostring(pkg.component or''),tostring(pkg.channel or''),tostring(pkg.restartRequired and true or false)};for _,p in ipairs(paths)do parts[#parts+1]='file:'..p..':'..crypto.sha256(tostring(pkg.files[p]or''))end;local managed={};for _,p in ipairs(pkg.managedFiles or{})do managed[#managed+1]=p end;table.sort(managed);for _,p in ipairs(managed)do parts[#parts+1]='managed:'..p end;return crypto.sha256(table.concat(parts,'\0'))end
local function readText(p)if not fs.exists(p)then return nil end;local h=fs.open(p,'r');if not h then return nil end;local s=h.readAll();h.close();return s end
local function writeFile(p,d)ensure(fs.getDir(p));local t=p..'.update-tmp';if fs.exists(t)then fs.delete(t)end;local h=assert(fs.open(t,'w'));h.write(d);h.close();if fs.exists(p)then fs.delete(p)end;fs.move(t,p)end
local function restore(info)
  if type(info)~='table'or not info.backup then return nil,'No rollback backup recorded for '..NAME end
  for _,r in ipairs(info.files or{})do
    if type(r)=='string'then r={path=r,existed=true}end
    local target='/'..tostring(r.path or'')
    local src=info.backup..'/'..tostring(r.path or'')
    if r.existed~=false then
      if not fs.exists(src)then return nil,'Backup missing: '..tostring(r.path)end
      writeFile(target,readText(src)or'')
    elseif fs.exists(target)then
      fs.delete(target)
    end
  end
  if info.previousVersion then ensure('/spawnnet/version');writeFile(VERSION,tostring(info.previousVersion)..'\n')end
  return true
end
if mode=='rollback'then
  local info=util.loadTable(LAST,nil)
  local ok,e=restore(info);if not ok then error(e,0)end
  term.setTextColor(colors.lime);print('Rolled back '..NAME);term.setTextColor(colors.white)
  print('Backup: '..tostring(info.backup))
  return
end
if not net.loadSession()then local _,loginErr=auth.ensureLogin();if loginErr then error(loginErr,0)end end
local m,e=net.call('package','manifest',{name=NAME})
if not m then print('No published '..NAME..' release: '..tostring(e));return end
local man=m.package or m
local localv=(readText(VERSION)or'unknown'):gsub('%s+$','')
print('SpawnNet '..NAME..' release')
print('Installed: '..localv)
print('Available: '..tostring(man.version))
if mode=='check'then return end
if localv==tostring(man.version)then print('Already current.');return end
write('Update now? Y/n: ');local a=read():lower();if a=='n'or a=='no'then return end
local got,ge=net.call('package','get',{name=NAME});if not got then error(ge,0)end
local pkg=got.package or got
if not pkg.hash or hash(pkg)~=tostring(pkg.hash)then error('System package integrity check failed',0)end
local files={}
for p,data in pairs(pkg.files or{})do
  local cp=clean(p)
  if not cp or not allowed(cp)then error('Unsafe '..NAME..' update target: '..tostring(p),0)end
  data=tostring(data or'')
  if cp:sub(-4)=='.lua'then local f,se=loadstring(data,'@/'..cp);if not f then error('Refusing update: '..cp..' syntax error: '..tostring(se),0)end end
  files[#files+1]={path=cp,data=data}
end
if #files==0 then error('Release contains no files',0)end
local ver=tostring(pkg.version or'update'):gsub('[^%w%.%-_]','_')
local backup=BACKUPS..'/'..ver
ensure(backup)
local records={}
for _,f in ipairs(files)do
  local target='/'..f.path;local existed=fs.exists(target)
  records[#records+1]={path=f.path,existed=existed}
  if existed then
    local dest=backup..'/'..f.path;ensure(fs.getDir(dest))
    if fs.exists(dest)then fs.delete(dest)end
    fs.copy(target,dest)
  end
end
local info={backup=backup,files=records,version=pkg.version,previousVersion=localv}
local ok,err=pcall(function()
  for _,f in ipairs(files)do writeFile('/'..f.path,f.data)end
  ensure('/spawnnet/version');writeFile(VERSION,tostring(pkg.version)..'\n')
  util.saveTable(LAST,info)
end)
if not ok then
  local rok,rerr=pcall(function()local good,re=restore(info);if not good then error(re,0)end end)
  if not rok then error('Update failed: '..tostring(err)..' ; rollback also failed: '..tostring(rerr),0)end
  error('Update failed and was rolled back: '..tostring(err),0)
end
term.setTextColor(colors.lime);print('UPDATED '..NAME..' -> '..tostring(pkg.version));term.setTextColor(colors.white)
print('Backup: '..backup)
]==],
  ["/spawnnet/lib/config.lua"]=[==[return {
  version = "2.3.0",
  packetVersion = 2,
  discoveryProtocol = "spawnnet:discovery:v2",
  protocolPrefix = "spawnnet:",
  backbonePrefix = "spawnnet:backbone:",
  root = "/spawnnet",
  dataFile = "/spawnnet/data/state.db",
  clientConfig = "/spawnnet/client.cfg",
  networkRegistry = "/spawnnet/networks.db",
  serverConfig = "/spawnnet/server.cfg",
  requestTimeout = 5,
  discoveryTimeout = 1.25,
  maxPacketBytes = 262144,
  fragmentBytes = 6000,
  fragmentTimeout = 15,
  maxSitePages = 96,
  maxAssets = 192,
  maxAssetBytes = 64000,
  maxRevisions = 40,
  maxMailPerUser = 250,
  maxChatMessages = 120,
  maxForumReplies = 200,
  maxScriptInstructions = 1200,
  maxServerScriptInstructions = 800,
  maxScriptRepeat = 150,
  maxPageElements = 300,
  sessionLifetime = 3600,
  passwordRounds = 768,
  loginWindow = 60,
  loginAttempts = 8,
  loginLockSeconds = 90,
  requestWindow = 5,
  requestBurst = 100,
  auditEntries = 600,
  siteStorageKeys = 768,
  databaseCollectionRows = 1000,
  telemetryPoints = 480,
  maxJobsPerDomain = 500,
  jobRetention = 250,
  nodeHeartbeatTimeout = 35,
  objectReplicas = 2,
  nodeRequestTimeout = 2.5,
  nodeRepairInterval = 45,
  remoteAssetThreshold = 4096,
  defaultHome = "spn://home",
}
]==],
  ["/spawnnet/lib/crypto.lua"]=[==[-- Pure-Lua SHA-256/HMAC adapter for ComputerCraft's bit/bit32 APIs.
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
  ["/spawnnet/lib/packet.lua"]=[==[local util=dofile("/spawnnet/lib/util.lua")
local crypto=dofile("/spawnnet/lib/crypto.lua")
local config=dofile("/spawnnet/lib/config.lua")
local M={}
function M.new(service,action,payload)
  return {network="spawnnet",version=config.packetVersion or 2,type="request",requestId=util.id("req"),service=service,action=action,payload=payload or {}}
end
function M.signingString(p)
  return table.concat({p.network or "",tostring(p.version or ""),p.networkId or "",p.type or "",p.requestId or "",p.service or "",p.action or "",util.canonical(p.payload or {}),p.auth and p.auth.session or "",p.auth and tostring(p.auth.seq or "") or "",p.secure and'1'or'0'},"|")
end
function M.requestAAD(p)
  return table.concat({p.network or'',tostring(p.version or''),p.networkId or'',p.type or'',p.requestId or'',p.service or'',p.action or'',p.auth and p.auth.session or'',p.auth and tostring(p.auth.seq or'')or''},'|')
end
function M.attachAuth(p,session)
  if not session then return p end
  session.seq=(session.seq or 0)+1
  p.auth={user=session.user,session=session.id,seq=session.seq}
  local box,e=crypto.sealTable(session.key,p.payload or{},M.requestAAD(p));if not box then error(e,0)end
  p.payload=box;p.secure=true
  p.auth.sig=crypto.hmac(session.key,M.signingString(p))
  return p
end
function M.openRequest(p,key)
  if not p.secure then return nil,'encrypted request required'end
  local value,e=crypto.openTable(key,p.payload,M.requestAAD(p));if not value then return nil,e end
  p.payload=value;p.secure=nil;return true
end
function M.validateShape(p)
  if type(p)~="table" then return false,"packet is not a table" end
  if p.network~="spawnnet" or p.version~=(config.packetVersion or 2) or p.type~="request" then return false,"not SpawnNet v1" end
  if type(p.requestId)~="string" or #p.requestId>96 then return false,"bad requestId" end
  if type(p.service)~="string" or #p.service>32 then return false,"bad service" end
  if type(p.action)~="string" or #p.action>48 then return false,"bad action" end
  if p.payload~=nil and type(p.payload)~="table" then return false,"bad payload" end
  return true
end
function M.response(req,status,payload,errorMessage)
  return {network="spawnnet",version=config.packetVersion or 2,type="response",requestId=req.requestId,service=req.service,action=req.action,status=status or 200,payload=payload or {},error=errorMessage}
end
function M.responseSigningString(p)
  return table.concat({p.network or '',tostring(p.version or ''),p.type or '',p.requestId or '',p.service or '',p.action or '',tostring(p.status or ''),util.canonical(p.payload or {}),p.error or '',p.secure and'1'or'0'},'|')
end
function M.responseAAD(p)return table.concat({p.network or'',tostring(p.version or''),p.type or'',p.requestId or'',p.service or'',p.action or'',tostring(p.status or'')},'|')end
function M.sealResponse(p,key)local box,e=crypto.sealTable(key,{payload=p.payload or{},error=p.error},M.responseAAD(p));if not box then return nil,e end;p.payload=box;p.error=nil;p.secure=true;return p end
function M.signResponse(p,key) p.responseSig=crypto.hmac(key,M.responseSigningString(p)); return p end
function M.verifyResponse(p,key) return type(p.responseSig)=='string' and crypto.constantTimeEq(p.responseSig,crypto.hmac(key,M.responseSigningString(p))) end
function M.openResponse(p,key)local v,e=crypto.openTable(key,p.payload,M.responseAAD(p));if not v then return nil,e end;p.payload=v.payload or{};p.error=v.error;p.secure=nil;return true end
function M.isResponseFor(p,requestId)
  return type(p)=="table" and p.network=="spawnnet" and p.version==(config.packetVersion or 2) and p.type=="response" and p.requestId==requestId
end
return M
]==],
  ["/spawnnet/lib/spawnscript.lua"]=[==[-- SpawnScript: bounded, interpreted scripting for hosted SpawnNet applications.
-- It intentionally cannot access fs, shell, rednet, http, peripherals, os, or arbitrary Lua.
local util=dofile('/spawnnet/lib/util.lua')
local M={}
local LITERAL='\1'

local function tokenize(line)
  local out={}; local i=1; local n=#line
  while i<=n do
    while i<=n and line:sub(i,i):match('%s') do i=i+1 end
    if i>n then break end
    local c=line:sub(i,i)
    if c=='#' then break end
    if c=='"' or c=="'" then
      local q=c; i=i+1; local b={}
      while i<=n do
        c=line:sub(i,i)
        if c=='\\' and i<n then
          local z=line:sub(i+1,i+1); if z=='n' then b[#b+1]='\n' elseif z=='t' then b[#b+1]='\t' else b[#b+1]=z end; i=i+2
        elseif c==q then i=i+1; break
        else b[#b+1]=c; i=i+1 end
      end
      out[#out+1]=LITERAL..table.concat(b)
    else
      local j=i
      while j<=n and not line:sub(j,j):match('%s') do j=j+1 end
      out[#out+1]=line:sub(i,j-1); i=j
    end
  end
  return out
end

local function interpolate(s,vars)
  return (s:gsub('%${([%w_%.%-]+)}',function(k)
    local v=util.tablePathGet(vars,k,'')
    if type(v)=='table' then return textutils.serialize(v) end
    return tostring(v==nil and '' or v)
  end))
end
local function value(tok,vars)
  if tok==nil then return nil end
  if tok:sub(1,1)==LITERAL then return interpolate(tok:sub(2),vars) end
  if tok:sub(1,1)=='$' then return util.tablePathGet(vars,tok:sub(2),nil) end
  if tok=='true' then return true elseif tok=='false' then return false elseif tok=='nil' or tok=='null' then return nil end
  local num=tonumber(tok); if num~=nil then return num end
  return interpolate(tok,vars)
end

function M.parse(source)
  local events={}; local current=nil
  local lineNo=0
  for line in (tostring(source or '')..'\n'):gmatch('(.-)\n') do
    lineNo=lineNo+1; local t=tokenize(util.trim(line))
    if #t>0 then
      if t[1]=='event' then
        if current then return nil,'Nested event at line '..lineNo end
        local name=t[2] and (t[2]:sub(1,1)==LITERAL and t[2]:sub(2) or t[2])
        if not name or name=='' then return nil,'Missing event name at line '..lineNo end
        current={name=name,lines={}}; events[name]=current.lines
      elseif t[1]=='end' and current then current=nil
      elseif current then current.lines[#current.lines+1]={tokens=t,line=lineNo,raw=line}
      else return nil,'Instruction outside event at line '..lineNo end
    end
  end
  if current then return nil,'Unclosed event '..current.name end
  return events
end

local function truth(v) return not (v==nil or v==false or v==0 or v=='') end
local function compare(a,op,b)
  if op=='==' then return a==b elseif op=='!=' or op=='~=' then return a~=b end
  if op=='contains' then return tostring(a or ''):find(tostring(b or ''),1,true)~=nil end
  local na,nb=tonumber(a),tonumber(b); if na~=nil and nb~=nil then a,b=na,nb else a,b=tostring(a or ''),tostring(b or '') end
  if op=='>' then return a>b elseif op=='<' then return a<b elseif op=='>=' then return a>=b elseif op=='<=' then return a<=b end
  return false
end

function M.run(source,eventName,env,opts)
  opts=opts or {}; env=env or {}; local parsed,perr=M.parse(source); if not parsed then return nil,perr end
  local lines=parsed[eventName]; if not lines then return {vars=util.deepcopy(opts.vars or {}),result=nil,steps=0} end
  local vars=util.deepcopy(opts.vars or {}); local pc=1; local steps=0; local limit=opts.limit or 500; local ifs={}; local repeats={}; local ret=nil
  local function active() for _,v in ipairs(ifs) do if not v.active then return false end end return true end
  while pc<=#lines do
    steps=steps+1; if steps>limit then return nil,'Script instruction quota exceeded' end
    local ins=lines[pc]; local t=ins.tokens; local op=t[1]
    if op=='if' then
      local parent=active(); local cond=false
      if parent then cond=compare(value(t[2],vars),t[3] or '==',value(t[4],vars)) end
      ifs[#ifs+1]={active=parent and cond,parent=parent,taken=parent and cond}
    elseif op=='else' then
      local f=ifs[#ifs]; if not f then return nil,'else without if at line '..ins.line end
      f.active=f.parent and not f.taken; f.taken=true
    elseif op=='endif' then
      if #ifs==0 then return nil,'endif without if at line '..ins.line end; table.remove(ifs)
    elseif op=='repeat' then
      local run=active(); local n=run and math.floor(tonumber(value(t[2],vars)) or 0) or 0
      n=math.max(0,math.min(n,opts.maxRepeat or 100)); repeats[#repeats+1]={start=pc+1,remaining=n,executing=run}
      if n==0 then
        local depth=1; local j=pc+1
        while j<=#lines and depth>0 do if lines[j].tokens[1]=='repeat' then depth=depth+1 elseif lines[j].tokens[1]=='endrepeat' then depth=depth-1 end; j=j+1 end
        if depth~=0 then return nil,'Unclosed repeat at line '..ins.line end
        table.remove(repeats); pc=j-1
      end
    elseif op=='endrepeat' then
      local r=repeats[#repeats]; if not r then return nil,'endrepeat without repeat at line '..ins.line end
      r.remaining=r.remaining-1; if r.remaining>0 then pc=r.start-1 else table.remove(repeats) end
    elseif active() then
      if op=='set' then
        local name=t[2]; if not name then return nil,'set needs variable at line '..ins.line end
        util.tablePathSet(vars,name,value(t[3],vars))
      elseif op=='concat' then
        local name=t[2]; local b={}; for i=3,#t do b[#b+1]=tostring(value(t[i],vars) or '') end; util.tablePathSet(vars,name,table.concat(b))
      elseif op=='math' then
        local name=t[2]; local a=tonumber(value(t[3],vars)) or 0; local oper=t[4]; local b=tonumber(value(t[5],vars)) or 0; local x=0
        if oper=='+' then x=a+b elseif oper=='-' then x=a-b elseif oper=='*' then x=a*b elseif oper=='/' then x=b==0 and 0 or a/b elseif oper=='%' then x=b==0 and 0 or a%b else return nil,'Unknown math op at line '..ins.line end
        util.tablePathSet(vars,name,x)
      elseif op=='random' then
        local name=t[2]; local a=math.floor(tonumber(value(t[3],vars)) or 1); local b=math.floor(tonumber(value(t[4],vars)) or a); if b<a then a,b=b,a end; util.tablePathSet(vars,name,math.random(a,b))
      elseif op=='call' then
        local method=t[2]; if not method then return nil,'call needs method at line '..ins.line end
        local arrow=nil; for i=3,#t do if t[i]=='->' then arrow=i; break end end
        local last=(arrow and arrow-1 or #t); local args={}; for i=3,last do args[#args+1]=value(t[i],vars) end
        if type(env.call)~='function' then return nil,'No API environment' end
        local ok,res,err=pcall(env.call,method,args,vars)
        if not ok then return nil,'API '..method..' crashed: '..tostring(res) end
        if res==nil and err then return nil,'API '..method..': '..tostring(err) end
        if arrow and t[arrow+1] then util.tablePathSet(vars,t[arrow+1],res) end
      elseif op=='log' then if env.log then local b={}; for i=2,#t do b[#b+1]=tostring(value(t[i],vars) or '') end; env.log(table.concat(b,' ')) end
      elseif op=='assert' then if not truth(value(t[2],vars)) then return nil,tostring(value(t[3],vars) or ('Assertion failed at line '..ins.line)) end
      elseif op=='return' then ret=value(t[2],vars); break
      else return nil,'Unknown instruction '..tostring(op)..' at line '..ins.line end
    end
    pc=pc+1
  end
  if #ifs>0 then return nil,'Unclosed if block' end
  return {vars=vars,result=ret,steps=steps}
end

return M
]==],
  ["/spawnnet/lib/util.lua"]=[==[local M = {}

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
]==],
  ["/spawnnet/lib/wire.lua"]=[==[local util=dofile('/spawnnet/lib/util.lua')
local config=dofile('/spawnnet/lib/config.lua')
local M={}

-- ComputerCraft's serializer can reject repeated table references as recursive.
-- Convert packets to a pure tree, duplicating repeated references while rejecting
-- true cycles and unsupported values with an exact path.
local function normalize(v,path,stack)
  local tv=type(v)
  if tv=='nil'or tv=='boolean'or tv=='number'or tv=='string'then return v end
  if tv~='table'then return nil,'unsupported '..tv..' at '..path end
  stack=stack or{}
  if stack[v]then return nil,'recursive table at '..path end
  stack[v]=true
  local out={}
  for k,x in pairs(v)do
    local tk=type(k)
    if tk~='string'and tk~='number'and tk~='boolean'then stack[v]=nil;return nil,'unsupported table key '..tk..' at '..path end
    local nv,e=normalize(x,path..'.'..tostring(k),stack)
    if e then stack[v]=nil;return nil,e end
    out[k]=nv
  end
  stack[v]=nil
  return out
end

function M.send(recipient,message,protocol)
  local clean,e=normalize(message,'$',{})
  if not clean then return false,'serialize failed: '..tostring(e) end
  local ok,raw=pcall(textutils.serialize,clean)
  if not ok then return false,'serialize failed: '..tostring(raw) end
  if #raw>config.maxPacketBytes then return false,'logical packet too large ('..#raw..' bytes)' end
  if #raw<=config.fragmentBytes then return rednet.send(recipient,clean,protocol) end
  local id=util.id('frag');local total=math.ceil(#raw/config.fragmentBytes)
  for i=1,total do
    local chunk=raw:sub((i-1)*config.fragmentBytes+1,i*config.fragmentBytes)
    local env={network='spawnnet',version=config.packetVersion or 2,type='fragment',fragmentId=id,index=i,total=total,data=chunk}
    local sent=rednet.send(recipient,env,protocol);if not sent then return false,'rednet send failed' end
  end
  return true
end
function M.accept(sender,msg,buckets)
  if type(msg)~='table'or msg.network~='spawnnet'or msg.type~='fragment'then return msg end
  if type(msg.fragmentId)~='string'or type(msg.index)~='number'or type(msg.total)~='number'or type(msg.data)~='string'then return nil,nil,'malformed fragment' end
  if msg.total<1 or msg.total>math.ceil(config.maxPacketBytes/config.fragmentBytes)+2 or msg.index<1 or msg.index>msg.total then return nil,nil,'bad fragment range' end
  local key=tostring(sender)..':'..msg.fragmentId;local b=buckets[key]
  if not b then b={created=os.clock(),total=msg.total,parts={},count=0,bytes=0};buckets[key]=b end
  if b.total~=msg.total then buckets[key]=nil;return nil,nil,'fragment total mismatch' end
  if not b.parts[msg.index]then b.parts[msg.index]=msg.data;b.count=b.count+1;b.bytes=b.bytes+#msg.data end
  if b.bytes>config.maxPacketBytes then buckets[key]=nil;return nil,nil,'fragment payload too large' end
  if b.count==b.total then
    local chunks={};for i=1,b.total do if not b.parts[i]then return nil end;chunks[i]=b.parts[i]end
    buckets[key]=nil
    local raw=table.concat(chunks);local ok,obj=pcall(textutils.unserialize,raw)
    if not ok or type(obj)~='table'then return nil,nil,'fragment decode failed' end
    return obj,true
  end
  return nil,false
end
function M.purge(buckets)
  local now=os.clock();for k,b in pairs(buckets)do if now-(b.created or now)>config.fragmentTimeout then buckets[k]=nil end end
end
return M
]==],
  ["/spawnnet/server/auth.lua"]=[==[local util=dofile('/spawnnet/lib/util.lua')
local crypto=dofile('/spawnnet/lib/crypto.lua')
local packet=dofile('/spawnnet/lib/packet.lua')
local config=dofile('/spawnnet/lib/config.lua')
local stateLib=dofile('/spawnnet/server/state.lua')
local M={_failures={}}

local function validUser(u)return type(u)=='string'and u:match('^[a-z0-9_%-]+$')and #u>=3 and #u<=24 end
local function serverConfig()return util.loadTable(config.serverConfig,{registrationMode='ticket'})end
local function failureKey(user,sender)return tostring(user)..'@'..tostring(sender)end
local function locked(user,sender)
  local now=os.clock()
  for _,k in ipairs({failureKey(user,sender),'user:'..tostring(user)})do local f=M._failures[k];if f and(f.lockedUntil or 0)>now then return true,math.ceil(f.lockedUntil-now)end end
  return false
end
local function failed(user,sender)
  local now=os.clock();local window=config.loginWindow or 60;local max=config.loginAttempts or 8
  for _,k in ipairs({failureKey(user,sender),'user:'..tostring(user)})do
    local f=M._failures[k]or{start=now,count=0};if now-f.start>window then f={start=now,count=0}end
    f.count=f.count+1;if f.count>=max then f.lockedUntil=now+(config.loginLockSeconds or 90);f.count=0;f.start=now end;M._failures[k]=f
  end
end
local function clearFailures(user,sender)M._failures[failureKey(user,sender)]=nil;M._failures['user:'..tostring(user)]=nil end

function M.publicAction(service,action)
  return service=='auth'and(action=='registerBegin'or action=='register'or action=='begin'or action=='login'or action=='apiBegin'or action=='apiLogin'or action=='ping')
    or(service=='dns'and action=='resolve')or(service=='web'and(action=='getPage'or action=='getAsset'or action=='runAction'))
    or(service=='search'and action=='query')or(service=='package'and(action=='manifest'or action=='get'or action=='list'))
end

function M.handle(state,req,ctx,sender)
  local a=req.action;local p=req.payload or{};state.registrationChallenges=state.registrationChallenges or{};state.registrationTickets=state.registrationTickets or{}
  if a=='ping'then return 200,{ok=true,version=config.version,time=util.now(),secureTransport=true},false end
  if a=='registerBegin'then
    local u=util.safeName(p.username,24);if not validUser(u)then return 400,nil,'Username must be 3-24 chars: a-z 0-9 _ -'end
    if state.accounts[u]then return 409,nil,'Username already exists'end
    local cfg=serverConfig();local nonce=crypto.randomHex(20)..util.id('enroll');local salt=crypto.randomHex(16);local rounds=config.passwordRounds or 768
    state.registrationChallenges[u]={nonce=nonce,salt=salt,rounds=rounds,sender=sender,created=os.clock()}
    return 200,{username=u,nonce=nonce,salt=salt,rounds=rounds,scheme='iterated-sha256-v1',ticketRequired=(cfg.registrationMode or'ticket')~='open'},false
  elseif a=='register'then
    local u=util.safeName(p.username,24);local ch=state.registrationChallenges[u];if not validUser(u)or state.accounts[u]then return 409,nil,'Account cannot be created'end
    if not ch or ch.sender~=sender or ch.nonce~=p.nonce or os.clock()-(ch.created or 0)>60 then return 401,nil,'Enrollment challenge expired'end
    local cfg=serverConfig();local verifier=nil
    if(cfg.registrationMode or'ticket')=='open'then verifier=p.verifier
    else
      local id=tostring(p.ticketId or''):lower();local ticket=state.registrationTickets[id]
      if not ticket or ticket.used or(ticket.expires and ticket.expires<util.now())then return 403,nil,'Invalid or expired enrollment code'end
      verifier=crypto.open(crypto.sha256('SpawnNet-Enrollment\0'..ticket.code),p.verifierBox,u..'|'..ch.nonce)
      if not verifier then return 403,nil,'Enrollment code authentication failed'end
      ticket.used=true;ticket.usedBy=u;ticket.usedAt=util.now();ticket.code=nil
    end
    if type(verifier)~='string'or #verifier~=64 then return 400,nil,'Bad password verifier'end
    state.accounts[u]={username=u,verifier=verifier,salt=ch.salt,kdfRounds=ch.rounds,passwordScheme='iterated-sha256-v1',created=util.now(),roles={},profile={displayName=tostring(p.displayName or u):sub(1,48),bio=''}}
    state.registrationChallenges[u]=nil;stateLib.ensureUser(state,u);return 201,{username=u,secure=true},true
  elseif a=='begin'then
    local u=util.safeName(p.username,24);local isLocked,remain=locked(u,sender);if isLocked then return 429,nil,'Login temporarily locked. Try again in '..tostring(remain)..'s'end
    local acc=state.accounts[u];local salt=acc and acc.salt or crypto.randomHex(16);local nonce=crypto.randomHex(20)..util.id('challenge')
    state.challenges[u]={nonce=nonce,sender=sender,created=os.clock()}
    return 200,{username=u,nonce=nonce,salt=salt,rounds=acc and(acc.kdfRounds or 1)or(config.passwordRounds or 768),scheme=acc and(acc.passwordScheme or'legacy-sha256')or'iterated-sha256-v1'},false
  elseif a=='login'then
    local u=util.safeName(p.username,24);local acc=state.accounts[u];local ch=state.challenges[u];local isLocked,remain=locked(u,sender)
    if isLocked then return 429,nil,'Login temporarily locked. Try again in '..tostring(remain)..'s'end
    if not acc or not ch or ch.sender~=sender or os.clock()-(ch.created or 0)>30 then failed(u,sender);return 401,nil,'Invalid username or password'end
    local expected=crypto.hmac(acc.verifier,ch.nonce..':'..tostring(sender))
    if not crypto.constantTimeEq(expected,p.proof)then state.challenges[u]=nil;failed(u,sender);return 401,nil,'Invalid username or password'end
    clearFailures(u,sender);local sid=crypto.randomHex(18)..util.id('session');local serverNonce=crypto.randomHex(20);local key=crypto.hmac(acc.verifier,ch.nonce..':'..serverNonce..':'..sid)
    state.sessions[sid]={id=sid,user=u,key=key,lastSeq=0,created=os.clock(),lastSeen=os.clock(),computer=sender,secure=true};state.challenges[u]=nil
    return 200,{id=sid,user=u,serverNonce=serverNonce,challenge=ch.nonce,secure=true},true
  elseif a=='apiBegin'then
    local id=tostring(p.id or'');local k=state.apiKeys[id];if not k or k.revoked then return 404,nil,'Unknown API key'end
    local nonce=crypto.randomHex(20)..util.id('api-challenge');state.apiChallenges[id]={nonce=nonce,sender=sender,created=os.clock()};return 200,{id=id,nonce=nonce},true
  elseif a=='apiLogin'then
    local id=tostring(p.id or'');local k=state.apiKeys[id];local ch=state.apiChallenges[id];if not k or not ch or k.revoked then return 401,nil,'No API challenge'end
    if ch.sender~=sender or os.clock()-(ch.created or 0)>30 then state.apiChallenges[id]=nil;return 401,nil,'API challenge expired',true end
    local expected=crypto.hmac(k.verifier,ch.nonce..':'..tostring(sender));if not crypto.constantTimeEq(expected,p.proof)then return 401,nil,'Bad API key proof'end
    local sid=crypto.randomHex(18)..util.id('api-session');local serverNonce=crypto.randomHex(20);local key=crypto.hmac(k.verifier,ch.nonce..':'..serverNonce..':'..sid)
    state.sessions[sid]={id=sid,user=k.owner,key=key,lastSeq=0,created=os.clock(),lastSeen=os.clock(),computer=sender,apiKey=id,scopes=k.scopes,secure=true};state.apiChallenges[id]=nil
    return 200,{id=sid,user=k.owner,serverNonce=serverNonce,challenge=ch.nonce,apiKey=id,secure=true},true
  elseif a=='createKey'then
    if not ctx or not ctx.user then return 401,nil,'Login required'end
    local secret=crypto.randomHex(24);local id=util.id('key');state.apiKeys[id]={id=id,owner=ctx.user,verifier=crypto.sha256(secret),label=tostring(p.label or'API key'):sub(1,48),scopes=p.scopes or{'*'},created=util.now(),revoked=false};return 201,{id=id,secret=secret,label=state.apiKeys[id].label},true
  elseif a=='listKeys'then
    local out={};for id,k in pairs(state.apiKeys)do if k.owner==ctx.user then out[#out+1]={id=id,label=k.label,scopes=k.scopes,created=k.created,revoked=k.revoked}end end;return 200,{keys=out},false
  elseif a=='revokeKey'then
    local k=state.apiKeys[tostring(p.id or'')];if not k or k.owner~=ctx.user then return 404,nil,'API key not found'end;k.revoked=true;for sid,s in pairs(state.sessions)do if s.apiKey==k.id then state.sessions[sid]=nil end end;return 200,{ok=true},true
  elseif a=='upgradeVerifier'then
    if not ctx or not ctx.user then return 401,nil,'Login required'end;if type(p.verifier)~='string'or #p.verifier~=64 then return 400,nil,'Bad verifier'end
    local acc=state.accounts[ctx.user];acc.verifier=p.verifier;acc.salt=tostring(p.salt or'');acc.kdfRounds=math.max(1,math.min(4096,tonumber(p.rounds)or(config.passwordRounds or 768)));acc.passwordScheme='iterated-sha256-v1';return 200,{upgraded=true},true
  elseif a=='listSessions'then
    local out={};for id,s in pairs(state.sessions)do if s.user==ctx.user then out[#out+1]={id=id:sub(1,12),computer=s.computer,created=s.created,lastSeen=s.lastSeen,current=ctx.session and ctx.session.id==id,apiKey=s.apiKey}end end;return 200,{sessions=out},false
  elseif a=='revokeAll'then
    for id,s in pairs(state.sessions)do if s.user==ctx.user then state.sessions[id]=nil end end;return 200,{ok=true},true
  elseif a=='logout'then
    if ctx and ctx.session then state.sessions[ctx.session.id]=nil;return 200,{ok=true},true end;return 200,{ok=true},false
  end
  return 404,nil,'Unknown auth action'
end

function M.authenticate(state,req,sender)
  local isPublic=M.publicAction(req.service,req.action);if isPublic and type(req.auth)~='table'then return{user=nil,public=true}end
  local a=req.auth;if type(a)~='table'or type(a.session)~='string'then return nil,'Login required'end
  local s=state.sessions[a.session];if not s or s.user~=a.user then return nil,'Invalid session'end;if s.computer~=sender then return nil,'Session computer mismatch'end
  if os.clock()-(s.lastSeen or 0)>config.sessionLifetime then state.sessions[a.session]=nil;return nil,'Session expired'end
  local seq=tonumber(a.seq)or 0;if seq<=s.lastSeq then return nil,'Replayed or out-of-order request'end
  local sig=a.sig;a.sig=nil;local expected=crypto.hmac(s.key,packet.signingString(req));a.sig=sig;if not crypto.constantTimeEq(expected,sig)then return nil,'Bad request signature'end
  local opened,openErr=packet.openRequest(req,s.key);if not opened then return nil,openErr end
  if s.apiKey and type(s.scopes)=='table'then local wanted=req.service..'.'..req.action;local serviceWild=req.service..'.*';local allowed=false;for _,scope in ipairs(s.scopes)do if scope=='*'or scope==wanted or scope==serviceWild then allowed=true;break end end;if not allowed then return nil,'API key scope denied'end end
  s.lastSeq=seq;s.lastSeen=os.clock();return{user=s.user,account=state.accounts[s.user],session=s}
end

function M.isAdmin(ctx)if not ctx or not ctx.account then return false end;for _,r in ipairs(ctx.account.roles or{})do if r=='admin'then return true end end;return false end
return M
]==],
  ["/spawnnet/server/cluster.lua"]=[==[local util=dofile('/spawnnet/lib/util.lua')
local crypto=dofile('/spawnnet/lib/crypto.lua')
local config=dofile('/spawnnet/lib/config.lua')
local wire=dofile('/spawnnet/lib/wire.lua')
local M={_deferred={},_fragments={},_networkId='public',_protocol=nil,_coreId=nil,_coreSeq={},_boot=crypto.randomHex(8)}

local LOCAL='/spawnnet/data/objects'
local function safe(s) return tostring(s or ''):gsub('[^%w%-_]','_') end
local function localPath(id) return LOCAL..'/'..safe(id):sub(1,2)..'/'..safe(id)..'.obj' end
local function activeProtocol() return M._protocol or (config.backbonePrefix..M._networkId..':v2') end

function M.configure(networkId,protocol)
  M._networkId=networkId or 'public'; M._protocol=protocol or (config.backbonePrefix..M._networkId..':v2'); M._coreId=os.getComputerID()
  util.ensureDir(LOCAL)
end
function M.defer(ev) M._deferred[#M._deferred+1]=ev end
function M.nextDeferred()
  if #M._deferred==0 then return nil end
  return table.remove(M._deferred,1)
end
function M.onlineNodes(state)
  local out={}; local now=os.clock()
  for id,n in pairs(state.nodes or {}) do
    if n.approved and n.token and not n.quarantined and n.lastSeenClock and now-n.lastSeenClock<(config.nodeHeartbeatTimeout or 35) then
      local x=util.deepcopy(n); x.id=tonumber(id) or id; out[#out+1]=x
    end
  end
  table.sort(out,function(a,b)
    local af=tonumber(a.free) or 0; local bf=tonumber(b.free) or 0
    if af==bf then return tonumber(a.id) < tonumber(b.id) end
    return af>bf
  end)
  return out
end

local function nodeSigning(msg)
  return table.concat({tostring(msg.networkId or''),tostring(msg.type or''),tostring(msg.boot or''),tostring(msg.seq or''),tostring(msg.requestId or''),tostring(msg.op or''),tostring(msg.objectId or''),crypto.sha256(tostring(msg.data or'')),tostring(msg.free or''),tostring(msg.capacity or''),tostring(msg.objects or''),tostring(msg.packageHash or''),tostring(msg.ok),tostring(msg.error or'')},'|')
end
local function sign(token,msg)msg.sig=crypto.hmac(token,nodeSigning(msg));return msg end
local function verify(token,msg)local sig=msg.sig;msg.sig=nil;local good=crypto.constantTimeEq(sig,crypto.hmac(token,nodeSigning(msg)));msg.sig=sig;return good end
function M.summary(state)
  local online=M.onlineNodes(state); local total=0; local free=0
  for _,n in ipairs(online) do total=total+(tonumber(n.capacity) or tonumber(n.free) or 0); free=free+(tonumber(n.free) or 0) end
  local all=0; for _ in pairs(state.nodes or {}) do all=all+1 end
  local pending=0; for _ in pairs(state.pendingNodes or {}) do pending=pending+1 end
  local objects=0; for _ in pairs(state.objects or {}) do objects=objects+1 end
  local onlineSet={};for _,n in ipairs(online)do onlineSet[tostring(n.id)]=true end
  local nodes={};for id,n in pairs(state.nodes or{})do local x=util.deepcopy(n);x.id=tonumber(id)or id;x.online=onlineSet[tostring(id)]and true or false;x.token=nil;x.pairKey=nil;nodes[#nodes+1]=x end
  table.sort(nodes,function(a,b)return tonumber(a.id)<tonumber(b.id)end)
  return {online=#online,totalNodes=all,pending=pending,total=total,free=free,objects=objects,nodes=nodes}
end

local function request(node,msg,timeout)
  msg=util.deepcopy(msg or {}); msg.network='spawnnet'; msg.version=2; msg.type=msg.type or 'cluster_request'; msg.networkId=M._networkId; msg.requestId=msg.requestId or util.id('cluster')
  msg.token=node.token;msg.boot=M._boot;local sid=tostring(node.id);M._coreSeq[sid]=(M._coreSeq[sid]or 0)+1;msg.seq=M._coreSeq[sid];sign(node.token,msg)
  local sent,sendErr=wire.send(tonumber(node.id),msg,activeProtocol()); if not sent then return nil,sendErr or 'send failed' end
  local timer=os.startTimer(timeout or 2.5)
  while true do
    local ev={os.pullEvent()}
    if ev[1]=='timer' and ev[2]==timer then return nil,'node timeout' end
    if ev[1]=='rednet_message' then
      local sender,body,proto=ev[2],ev[3],ev[4]
      if sender==tonumber(node.id) and proto==activeProtocol() then
        local complete,done,wireErr=wire.accept(sender,body,M._fragments);wire.purge(M._fragments);body=complete
        if type(body)=='table'and body.type=='cluster_response'and body.requestId==msg.requestId and body.seq==msg.seq and verify(node.token,body)then
          if body.ok==false then return nil,body.error or 'node error' end
          return body
        elseif body~=nil then M.defer({'rednet_message',sender,body,proto}) end
      else M.defer(ev) end
    else M.defer(ev) end
  end
end

function M.store(state,key,data,opts)
  opts=opts or {}; data=tostring(data or '')
  state.objects=state.objects or {}
  local id=crypto.sha256(tostring(key or '')..'\0'..data)
  local obj=state.objects[id] or {id=id,key=tostring(key or ''),size=#data,created=util.now(),nodes={},localCopy=false}
  obj.size=#data; obj.updated=util.now(); obj.nodes=obj.nodes or {}

  local wanted=tonumber(opts.replicas) or config.objectReplicas or 2
  local nodes=M.onlineNodes(state);local saved=0
  for _,node in ipairs(nodes) do
    if saved>=wanted then break end
    if not node.draining then local res=request(node,{op='put',objectId=id,data=data,dataHash=crypto.sha256(data)})
    if res then obj.nodes[tostring(node.id)]=true; saved=saved+1; node.free=res.free or node.free end
    end
  end

  if opts.requireRemote and saved==0 then return nil,'No storage node accepted object' end
  if opts.keepLocal or saved<wanted then
    local path=localPath(id); util.ensureDir(fs.getDir(path)); util.writeIfChanged(path,data); obj.localCopy=true
  elseif obj.localCopy then
    local p=localPath(id); if fs.exists(p) then fs.delete(p) end; obj.localCopy=false
  end
  state.objects[id]=obj
  return id,obj
end

function M.get(state,id)
  local obj=(state.objects or {})[id]
  if not obj then return nil,'Unknown object' end
  local p=localPath(id)
  if obj.localCopy and fs.exists(p)then local data=util.readFile(p);if crypto.sha256(tostring(obj.key or'')..'\0'..tostring(data or''))==id then return data end end
  local online={};for _,n in ipairs(M.onlineNodes(state))do online[tostring(n.id)]=n end
  for nodeId in pairs(obj.nodes or{})do
    local n=state.nodes and state.nodes[tostring(nodeId)]
    if n and online[tostring(nodeId)]then
      local res=request(n,{op='get',objectId=id})
      if res and res.data~=nil then
        if crypto.sha256(tostring(obj.key or'')..'\0'..tostring(res.data))==id then return res.data end
        n.quarantined=true;n.quarantineReason='Object integrity failure '..id;obj.nodes[tostring(nodeId)]=nil
      end
    end
  end
  return nil,'No replica available'
end

function M.delete(state,id)
  local obj=(state.objects or {})[id]; if not obj then return true end
  local p=localPath(id); if fs.exists(p) then fs.delete(p) end
  for nodeId in pairs(obj.nodes or {}) do
    local n=state.nodes and state.nodes[tostring(nodeId)]
    if n and n.token then request({id=tonumber(nodeId),token=n.token},{op='delete',objectId=id},1.5) end
  end
  state.objects[id]=nil; return true
end

function M.handleBackbone(state,sender,msg)
  if type(msg)~='table' or msg.network~='spawnnet' or msg.version~=2 or msg.networkId~=M._networkId then return false end
  state.nodes=state.nodes or {}; state.pendingNodes=state.pendingNodes or {}
  local sid=tostring(sender)
  if msg.type=='node_hello' then
    local approved=state.nodes[sid]
    if approved and approved.approved and approved.pairCode and approved.pairCode==tostring(msg.pairCode or'')then
      approved.pairKey=crypto.sha256(approved.pairCode);approved.pairId=approved.pairKey:sub(1,12);approved.pairCode=nil;approved.legacy=true
      approved.lastSeen=util.now();approved.lastSeenClock=os.clock();approved.free=msg.free;approved.capacity=msg.capacity or approved.capacity
      local box=crypto.seal(approved.pairKey,approved.token,M._networkId..'|'..sid);rednet.send(sender,{network='spawnnet',version=2,type='node_approved',networkId=M._networkId,tokenBox=box,name=approved.name,coreIdentity=approved.coreIdentity},activeProtocol());return true,true
    end
    if approved and approved.approved and approved.pairKey and type(msg.helloNonce)=='string'and crypto.constantTimeEq(tostring(msg.proof or''),crypto.hmac(approved.pairKey,table.concat({M._networkId,sid,msg.helloNonce,tostring(msg.pairId or'')},'|')))then
      approved.lastSeen=util.now(); approved.lastSeenClock=os.clock(); approved.free=msg.free; approved.capacity=msg.capacity or approved.capacity; approved.name=msg.name or approved.name
      local box=crypto.seal(approved.pairKey,approved.token,M._networkId..'|'..sid);rednet.send(sender,{network='spawnnet',version=2,type='node_approved',networkId=M._networkId,tokenBox=box,name=approved.name,coreIdentity=approved.coreIdentity},activeProtocol())
    else
      state.pendingNodes[sid]={id=sender,pairId=tostring(msg.pairId or''),name=tostring(msg.name or('Storage #'..sid)):sub(1,48),free=msg.free,capacity=msg.capacity,lastSeen=util.now(),lastSeenClock=os.clock()}
    end
    return true,true
  elseif msg.type=='node_update_manifest' or msg.type=='node_update_get' then -- SPAWNNET_220_NODE_UPDATE
    local n=state.nodes[sid]
    if n and n.updateBoot~=msg.boot then n.updateBoot=msg.boot;n.lastUpdateSeq=0 end
    local valid=n and n.approved and n.token==msg.token and(n.legacy or(verify(n.token,msg)and(tonumber(msg.seq)or 0)>(n.lastUpdateSeq or 0)))
    if not valid then return true,false end;if not n.legacy then n.lastUpdateSeq=msg.seq end
    local pkg=nil
    local rp='/spawnnet/releases/node.pkg'
    if fs.exists(rp)then local h=fs.open(rp,'r');if h then local raw=h.readAll();h.close();local ok,v=pcall(textutils.unserialize,raw);if ok and type(v)=='table'then pkg=v end end end
    if not pkg then pkg=state.packages and state.packages['node']end
    local res={network='spawnnet',version=2,type='node_update_response',networkId=M._networkId,requestId=msg.requestId,token=msg.token,ok=false}
    if not pkg then res.error='Node update package not published'
    else
      res.ok=true
      if msg.type=='node_update_manifest'then
        local files=0;for _ in pairs(pkg.files or{})do files=files+1 end
        res.package={name=pkg.name or'node',version=pkg.version,description=pkg.description,component=pkg.component or'node',channel=pkg.channel or'stable',restartRequired=pkg.restartRequired and true or false,files=files,totalBytes=pkg.totalBytes or 0,hash=pkg.hash}
      else res.package=util.deepcopy(pkg)end
    end
    res.seq=msg.seq;res.boot=msg.boot;res.packageHash=pkg and pkg.hash or'';sign(n.token,res);wire.send(sender,res,activeProtocol())
    return true,false
  elseif msg.type=='node_heartbeat' then
    local n=state.nodes[sid]
    if n and n.nodeBoot~=msg.boot then n.nodeBoot=msg.boot;n.lastNodeSeq=0 end
    local signed=n and msg.sig and verify(n.token,msg)and(tonumber(msg.seq)or 0)>(n.lastNodeSeq or 0)
    if n and n.approved and n.token==msg.token and(signed or n.legacy)then
      if signed then n.lastNodeSeq=msg.seq;n.legacy=false end;n.lastSeen=util.now();n.lastSeenClock=os.clock();n.free=msg.free;n.capacity=msg.capacity or n.capacity;n.objects=msg.objects or n.objects
      return true,false
    end
    return true,false
  end
  return false
end

function M.approve(state,id,name,pairCode,coreIdentity)
  id=tostring(id); local p=state.pendingNodes and state.pendingNodes[id]; if not p then return nil,'Pending node not found' end
  local pairKey=crypto.sha256(tostring(pairCode or''):gsub('%s',''):lower());if pairKey:sub(1,12)~=p.pairId then return nil,'Pair code does not match node'end
  state.nodes=state.nodes or {}
  local token=crypto.randomHex(24)
  state.nodes[id]={id=tonumber(id),name=tostring(name or p.name or('Storage #'..id)):sub(1,48),pairId=p.pairId,pairKey=pairKey,token=token,approved=true,lastSeen=p.lastSeen,lastSeenClock=p.lastSeenClock,free=p.free,capacity=p.capacity,objects=0,coreIdentity=coreIdentity}
  state.pendingNodes[id]=nil
  return state.nodes[id]
end
function M.rebalance(state)
  local nodes=M.onlineNodes(state);local moved=0;local checked=0;local wanted=config.objectReplicas or 2
  for id,obj in pairs(state.objects or {}) do
    checked=checked+1;obj.nodes=obj.nodes or{}
    local healthy=0;local onlineSet={};for _,n in ipairs(nodes)do onlineSet[tostring(n.id)]=n;if obj.nodes[tostring(n.id)]then healthy=healthy+1 end end
    local need=math.max(0,math.min(wanted,#nodes)-healthy)
    if need>0 then
      local data=M.get(state,id)
      if data~=nil then
        for _,n in ipairs(nodes)do
          local sid=tostring(n.id)
          if need<=0 then break end
          if not obj.nodes[sid]and not n.draining then local res=request(n,{op='put',objectId=id,data=data,dataHash=crypto.sha256(data)});if res then obj.nodes[sid]=true;need=need-1;moved=moved+1 end end
        end
      end
    end
    healthy=0;for sid in pairs(obj.nodes)do if onlineSet[sid]then healthy=healthy+1 end end
    if healthy>=wanted and obj.localCopy then local p=localPath(id);if fs.exists(p)then fs.delete(p)end;obj.localCopy=false end
  end
  return {checked=checked,copiesAdded=moved,nodes=#nodes}
end

function M.remove(state,id)
  id=tostring(id); if state.nodes then state.nodes[id]=nil end; if state.pendingNodes then state.pendingNodes[id]=nil end
  for _,obj in pairs(state.objects or {}) do if obj.nodes then obj.nodes[id]=nil end end
  return true
end
function M.setDraining(state,id,value)
  id=tostring(id);local n=state.nodes and state.nodes[id];if not n then return nil,'Node not found'end;n.draining=value and true or false;return n
end
function M.clearQuarantine(state,id)
  id=tostring(id);local n=state.nodes and state.nodes[id];if not n then return nil,'Node not found'end;n.quarantined=nil;n.quarantineReason=nil;return n
end
return M
]==],
  ["/spawnnet/server/core_updater.lua"]=[==[-- SpawnNet Core staged updater - 2.3.0
local util=dofile('/spawnnet/lib/util.lua')
local crypto=dofile('/spawnnet/lib/crypto.lua')
local mode=(...)or'update'
local PKG='/spawnnet/update/core-staged.pkg'
local ROOT='/spawnnet/update/backups/core'
local LAST='/spawnnet/update/last-core.db'
local VERSION='/spawnnet/version/core-release.txt'
local function clean(path)
  path=tostring(path or''):gsub('\\','/'):gsub('^/+','')
  if path==''then return nil end
  for p in path:gmatch('[^/]+')do if p=='.'or p=='..'then return nil end end
  return path
end
local function allowed(p)
  return p:sub(1,16)=='spawnnet/server/'or p:sub(1,13)=='spawnnet/lib/'or p:sub(1,15)=='spawnnet/tools/'or p=='spawnnet.lua'or p=='spawnnet-server.lua'or p=='spawnnet-status.lua'or p=='spawnnet-admin.lua'or p=='spawnnet-core-update.lua'
end
local function canonicalHash(pkg)
  local paths={};for p in pairs(pkg.files or{})do paths[#paths+1]=p end;table.sort(paths)
  local parts={tostring(pkg.name or''),tostring(pkg.version or''),tostring(pkg.component or''),tostring(pkg.channel or''),tostring(pkg.restartRequired and true or false)}
  for _,p in ipairs(paths)do parts[#parts+1]='file:'..p..':'..crypto.sha256(tostring(pkg.files[p]or''))end
  return crypto.sha256(table.concat(parts,'\0'))
end
local function ensure(path)if path==''or path=='/'or fs.exists(path)then return end;local p=fs.getDir(path);if p and p~=''then ensure(p)end;fs.makeDir(path)end
local function readText(path)if not fs.exists(path)then return nil end;local h=fs.open(path,'r');if not h then return nil end;local s=h.readAll();h.close();return s end
local function writeFile(path,data)ensure(fs.getDir(path));local tmp=path..'.update-tmp';if fs.exists(tmp)then fs.delete(tmp)end;local h=assert(fs.open(tmp,'w'));h.write(data);h.close();if fs.exists(path)then fs.delete(path)end;fs.move(tmp,path)end
local function restore(info)
  if type(info)~='table'or not info.backup then return nil,'No Core rollback backup is available'end
  for _,r in ipairs(info.files or{})do
    if type(r)=='string'then r={path=r,existed=true}end
    local target='/'..tostring(r.path or'')
    local src=info.backup..'/'..tostring(r.path or'')
    if r.existed~=false then
      if not fs.exists(src)then return nil,'Backup missing: '..tostring(r.path)end
      writeFile(target,readText(src)or'')
    elseif fs.exists(target)then fs.delete(target)end
  end
  if info.previousVersion then ensure('/spawnnet/version');writeFile(VERSION,tostring(info.previousVersion)..'\n')end
  return true
end
if mode=='rollback'then
  local info=util.loadTable(LAST,nil)
  local ok,e=restore(info);if not ok then error(e,0)end
  term.setTextColor(colors.lime);print('CORE ROLLED BACK');term.setTextColor(colors.white)
  print('Restart the SpawnNet Core.')
  return
end
if not fs.exists(PKG)then error('No staged Core update. Stage one from an admin client first.',0)end
local h=assert(fs.open(PKG,'r'));local raw=h.readAll();h.close()
local ok,pkg=pcall(textutils.unserialize,raw);if not ok or type(pkg)~='table'then error('Staged Core package is corrupt',0)end
if tostring(pkg.name or'')~='core'then error('Staged package is not a Core release',0)end
if not pkg.hash or canonicalHash(pkg)~=tostring(pkg.hash)then error('Core package integrity check failed',0)end
local staged={}
for p,data in pairs(pkg.files or{})do
  local cp=clean(p)
  if not cp or not allowed(cp)then error('Unsafe Core update target: '..tostring(p),0)end
  data=tostring(data or'')
  if cp:sub(-4)=='.lua'then local fn,e=loadstring(data,'@/'..cp);if not fn then error('Refusing update: '..cp..' syntax error: '..tostring(e),0)end end
  staged[#staged+1]={path=cp,data=data}
end
if #staged==0 then error('Core update contains no files',0)end
term.clear();term.setCursorPos(1,1);term.setTextColor(colors.yellow);print('SPAWNNET CORE UPDATE');term.setTextColor(colors.white)
print('Version: '..tostring(pkg.version));print('Files: '..#staged);print()
print('STOP the running SpawnNet Core before continuing.')
write('Type UPDATE to apply: ');if read()~='UPDATE'then print('Cancelled.');return end
local previous=(readText(VERSION)or'unknown'):gsub('%s+$','')
local ver=tostring(pkg.version or'update'):gsub('[^%w%.%-_]','_')
local backup=ROOT..'/'..ver;ensure(backup)
local records={}
for _,f in ipairs(staged)do
  local target='/'..f.path;local existed=fs.exists(target)
  records[#records+1]={path=f.path,existed=existed}
  if existed then
    local dest=backup..'/'..f.path;ensure(fs.getDir(dest))
    if fs.exists(dest)then fs.delete(dest)end
    fs.copy(target,dest)
  end
end
local info={backup=backup,files=records,previousVersion=previous,version=pkg.version}
local applyOk,applyErr=pcall(function()
  for _,f in ipairs(staged)do writeFile('/'..f.path,f.data)end
  ensure('/spawnnet/version');writeFile(VERSION,tostring(pkg.version or'unknown')..'\n')
  util.saveTable(LAST,info)
end)
if not applyOk then
  local rok,rerr=pcall(function()local good,re=restore(info);if not good then error(re,0)end end)
  if not rok then error('Core update failed: '..tostring(applyErr)..' ; rollback also failed: '..tostring(rerr),0)end
  error('Core update failed and was rolled back: '..tostring(applyErr),0)
end
fs.delete(PKG)
term.setTextColor(colors.lime);print();print('CORE UPDATE APPLIED');term.setTextColor(colors.white)
print('Restart the SpawnNet Core now.')
print('Backup: '..backup)
]==],
  ["/spawnnet/server/server.lua"]=[==[local config=dofile('/spawnnet/lib/config.lua')
local util=dofile('/spawnnet/lib/util.lua')
local crypto=dofile('/spawnnet/lib/crypto.lua')
local packet=dofile('/spawnnet/lib/packet.lua')
local wire=dofile('/spawnnet/lib/wire.lua')
local auth=dofile('/spawnnet/server/auth.lua')
local stateLib=dofile('/spawnnet/server/state.lua')
local cluster=dofile('/spawnnet/server/cluster.lua')

local services={
  auth=auth,
  users=dofile('/spawnnet/server/services/users.lua'),
  dns=dofile('/spawnnet/server/services/dns.lua'),
  web=dofile('/spawnnet/server/services/web.lua'),
  search=dofile('/spawnnet/server/services/search.lua'),
  storage=dofile('/spawnnet/server/services/storage.lua'),
  db=dofile('/spawnnet/server/services/database.lua'),
  mail=dofile('/spawnnet/server/services/mail.lua'),
  event=dofile('/spawnnet/server/services/events.lua'),
  jobs=dofile('/spawnnet/server/services/jobs.lua'),
  nodes=dofile('/spawnnet/server/services/nodes.lua'),
  blob=dofile('/spawnnet/server/services/blob.lua'),
  package=dofile('/spawnnet/server/services/package.lua'),
  forum=dofile('/spawnnet/server/services/forum.lua'),
  chat=dofile('/spawnnet/server/services/chat.lua'),
  telemetry=dofile('/spawnnet/server/services/telemetry.lua'),
  moderation=dofile('/spawnnet/server/services/moderation.lua'),
}

local serverCfg=util.loadTable(config.serverConfig,{modem=nil,networkId='public',networkName='Public SpawnNet',visibility='public',joinHash='',log='/spawnnet/log/server.log',registrationMode='ticket'})
serverCfg.networkId=util.safeName(serverCfg.networkId or 'public',32); if serverCfg.networkId=='' then serverCfg.networkId='public' end
serverCfg.networkName=tostring(serverCfg.networkName or serverCfg.networkId):sub(1,48)
serverCfg.visibility=serverCfg.visibility=='private' and 'private' or 'public'
serverCfg.registrationMode=serverCfg.registrationMode=='open'and'open'or'ticket'
if type(serverCfg.coreIdentity)~='string'or #serverCfg.coreIdentity<32 then serverCfg.coreIdentity=crypto.randomHex(20)end
local networkProtocol=config.protocolPrefix..serverCfg.networkId..':v2'
local backboneProtocol=config.backbonePrefix..serverCfg.networkId..':v2'
serverCfg.protocol=networkProtocol; serverCfg.backboneProtocol=backboneProtocol
util.saveTable(config.serverConfig,serverCfg)

local function findModem()
  if serverCfg.modem and peripheral.isPresent(serverCfg.modem) and peripheral.getType(serverCfg.modem)=='modem' then return serverCfg.modem end
  for _,name in ipairs(peripheral.getNames()) do if peripheral.getType(name)=='modem' then return name end end
end
local modem=findModem(); if not modem then error('SpawnNet server requires a modem') end
if not rednet.isOpen(modem) then rednet.open(modem) end
pcall(rednet.unhost,networkProtocol)
pcall(rednet.host,networkProtocol,'spawnnet-core-'..serverCfg.networkId)
cluster.configure(serverCfg.networkId,backboneProtocol)
_G.spawnnetCluster=cluster

util.ensureDir('/spawnnet/data'); util.ensureDir('/spawnnet/log')
local state=stateLib.load(config.dataFile); state.nodes=state.nodes or {}; state.pendingNodes=state.pendingNodes or {}; state.objects=state.objects or {}; state.blobs=state.blobs or {}; state.jobs=state.jobs or {}
local fragments={};local rate={};local networkReplay={}

local function log(line)
  pcall(function()
    local path=serverCfg.log or '/spawnnet/log/server.log'; local old=util.readFile(path) or ''
    old=old..string.format('[%s] %s\n',tostring(util.now()),tostring(line)); if #old>30000 then old=old:sub(-24000) end; util.writeFile(path,old)
  end)
end
local function security(event,sender,detail)
  pcall(function()
    local path='/spawnnet/log/security.log';local old=util.readFile(path)or''
    old=old..string.format('[%s] %-18s computer=%s %s\n',tostring(util.now()),tostring(event):sub(1,18),tostring(sender or'-'),tostring(detail or''):gsub('[\r\n]',' '):sub(1,160))
    if #old>60000 then old=old:sub(-50000)end;util.writeFile(path,old)
  end)
end
if stateLib.seedSystem(state,serverCfg.adminUser or 'system') then local ok,e=pcall(stateLib.save,state,config.dataFile); if not ok then error('Unable to seed SpawnNet state: '..tostring(e)) end end

local function safeSize(v)local ok,s=pcall(textutils.serialize,v);if not ok then return config.maxPacketBytes+1 end;return #s end
local function reloadAfterFailure()
  local sessions=state.sessions or {};local challenges=state.challenges or {};local apiChallenges=state.apiChallenges or {}
  local ok,newState=pcall(stateLib.load,config.dataFile);if not ok or type(newState)~='table'then return false end
  newState.sessions=sessions;newState.challenges=challenges;newState.apiChallenges=apiChallenges;state=newState;return true
end
local function networkAllowed(req)
  if req.networkId and util.safeName(req.networkId,32)~=serverCfg.networkId then return false,'Wrong SpawnNet network' end
  if serverCfg.visibility=='private' then
    local a=req.networkAuth;local joinHash=tostring(serverCfg.joinHash or'')
    if type(a)~='table'or type(a.proof)~='string'or joinHash==''then return false,'Private network access denied'end
    local stamp=tonumber(a.time);if not stamp or math.abs(util.now()-stamp)>30 then return false,'Private network proof expired'end
    local message=table.concat({serverCfg.networkId,req.requestId or'',req.service or'',req.action or'',tostring(stamp)},'|')
    if not crypto.constantTimeEq(a.proof,crypto.hmac(joinHash,message))then return false,'Private network access denied'end
    local now=os.clock();for id,t in pairs(networkReplay)do if now-t>90 then networkReplay[id]=nil end end
    if networkReplay[req.requestId]then return false,'Private request replay rejected'end;networkReplay[req.requestId]=now
  end
  return true
end
local function process(sender,req)
  local now=os.clock();local rr=rate[sender]or{start=now,count=0};if now-rr.start>(config.requestWindow or 5)then rr={start=now,count=0}end;rr.count=rr.count+1;rate[sender]=rr
  if rr.count>(config.requestBurst or 100)then security('RATE_LIMIT',sender,'request burst exceeded');return packet.response(type(req)=='table'and req or{requestId='rate',service='unknown',action='unknown'},429,nil,'Rate limit exceeded')end
  local okShape,shapeErr=packet.validateShape(req);if not okShape then return packet.response(type(req)=='table'and req or{requestId='invalid',service='unknown',action='unknown'},400,nil,shapeErr) end
  local allowed,why=networkAllowed(req);if not allowed then return packet.response(req,403,nil,why)end
  if safeSize(req)>config.maxPacketBytes then return packet.response(req,413,nil,'Packet too large') end
  local svc=services[req.service];if not svc or type(svc.handle)~='function'then return packet.response(req,404,nil,'Unknown service')end
  local ctx,authErr=auth.authenticate(state,req,sender);if not ctx then security('AUTH_REJECT',sender,tostring(req.service)..'.'..tostring(req.action)..' '..tostring(authErr));return packet.response(req,401,nil,authErr)end
  if ctx.user and state.moderation.suspendedUsers[ctx.user]then return packet.response(req,403,nil,'Account suspended')end
  local ok,status,payload,changedOrErr,maybeChanged=pcall(svc.handle,state,req,ctx,sender)
  if not ok then log('SERVICE CRASH '..req.service..'.'..req.action..': '..tostring(status));reloadAfterFailure();return packet.response(req,500,nil,'Service error: '..tostring(status))end
  local changed=false;local err=nil;if type(changedOrErr)=='boolean'then changed=changedOrErr elseif type(changedOrErr)=='string'then err=changedOrErr;changed=maybeChanged==true end
  if changed and(req.service=='auth'or req.service=='moderation'or req.service=='nodes'or req.service=='package')then security('SECURITY_CHANGE',sender,tostring(ctx.user or(payload and payload.user)or'guest')..' '..req.service..'.'..req.action)end
  if changed then
    local okSave,saveErr=pcall(stateLib.save,state,config.dataFile)
    if not okSave then local rolled=reloadAfterFailure();local okFree,free=pcall(fs.getFreeSpace,config.dataFile);local detail='Backend save failed: '..tostring(saveErr);if okFree then detail=detail..' [free='..tostring(free)..']'end;if not rolled then detail=detail..' [rollback failed]'end;log('SAVE ERROR '..detail);return packet.response(req,507,nil,detail)end
  end
  return packet.response(req,status or 200,payload or {},err)
end

local function advertise(sender,msg)
  rednet.send(sender,{network='spawnnet',version=2,type='advertise',nonce=msg.nonce,networkId=serverCfg.networkId,name=serverCfg.networkName,visibility=serverCfg.visibility,protocol=networkProtocol,core=os.getComputerID(),coreIdentity=serverCfg.coreIdentity,versionName=config.version},config.discoveryProtocol)
end
local function handleClient(sender,msg)
  local complete,done,wireErr=wire.accept(sender,msg,fragments);wire.purge(fragments);if wireErr then log('WIRE DROP from #'..tostring(sender)..': '..wireErr)end;msg=complete
  if not msg then return end
  local responseKey=nil;if type(msg.auth)=='table'and msg.auth.session and state.sessions[msg.auth.session]then responseKey=state.sessions[msg.auth.session].key end
  local ok,res=pcall(process,sender,msg);if not ok then log('DISPATCH CRASH: '..tostring(res));reloadAfterFailure();if type(msg)=='table'and msg.requestId then res=packet.response(msg,500,nil,'Dispatcher recovered from error')else res=nil end end
  if res then
    if responseKey then local sealed,sealErr=packet.sealResponse(res,responseKey);if not sealed then log('RESPONSE SEAL ERROR: '..tostring(sealErr));return end;packet.signResponse(res,responseKey)end
    local sent,sendErr=wire.send(sender,res,networkProtocol);if not sent then log('SEND ERROR: '..tostring(sendErr))end
  end
end

term.setBackgroundColor(colors.black);term.clear();term.setCursorPos(1,1);term.setBackgroundColor(colors.purple);term.setTextColor(colors.white);term.clearLine();write(' SN// CORE CITADEL '..config.version..' ');term.setBackgroundColor(colors.black);term.setCursorPos(2,3);term.setTextColor(colors.cyan);print('[+] NETWORK ONLINE');term.setTextColor(colors.lightGray);print('  Realm       '..serverCfg.networkName..' ['..serverCfg.networkId..']');print('  Core        #'..os.getComputerID());print('  Identity    '..tostring(serverCfg.coreIdentity):sub(1,20));print('  Modem       '..modem);print('  Client bus  '..networkProtocol);print('  Vault bus   '..backboneProtocol);print('  Visibility  '..serverCfg.visibility:upper());print('  Enrollment  '..serverCfg.registrationMode:upper());term.setTextColor(colors.lime);print();print('  ALL SYSTEMS NOMINAL');term.setCursorPos(1,select(2,term.getSize()));term.setBackgroundColor(colors.gray);term.setTextColor(colors.white);term.clearLine();write(' Ctrl+T shutdown   spawnnet-status diagnostics ')
log('Core online #'..os.getComputerID()..' network='..serverCfg.networkId)
local repairTimer=os.startTimer(config.nodeRepairInterval or 45)

while true do
  local ev=cluster.nextDeferred() or {os.pullEvent()}
  if ev[1]=='timer'and ev[2]==repairTimer then
    local ok,result=pcall(cluster.rebalance,state);if not ok then log('CLUSTER REPAIR ERROR: '..tostring(result))elseif result and(result.copiesAdded or 0)>0 then log('CLUSTER REPAIR added='..tostring(result.copiesAdded));pcall(stateLib.save,state,config.dataFile)end
    repairTimer=os.startTimer(config.nodeRepairInterval or 45)
  elseif ev[1]=='rednet_message' then
    local sender,msg,proto=ev[2],ev[3],ev[4]
    if proto==config.discoveryProtocol and type(msg)=='table'and msg.type=='discover'and msg.version==2 then advertise(sender,msg)
    elseif proto==backboneProtocol then
      local handled=cluster.handleBackbone(state,sender,msg)
      if not handled then -- responses for synchronous calls should normally be consumed by cluster.request
        log('Unknown backbone message from #'..tostring(sender))
      end
    elseif proto==networkProtocol then handleClient(sender,msg) end
  end
end
]==],
  ["/spawnnet/server/services/blob.lua"]=[==[local util=dofile('/spawnnet/lib/util.lua')
local C=dofile('/spawnnet/server/services/common.lua')
local cluster=dofile('/spawnnet/server/cluster.lua')
local M={}
local function siteOwner(state,d,ctx)local s=state.sites[d];return s and ctx and ctx.user==s.owner end
function M.handle(state,req,ctx)
  local p=req.payload or {}; local a=req.action; local d=C.cleanDomain(p.domain); state.blobs=state.blobs or {}; state.blobs[d]=state.blobs[d] or {}
  if a=='put' then
    if not siteOwner(state,d,ctx) then return 403,nil,'Site owner required' end
    local key=util.safeName(p.key,48); if key=='' then return 400,nil,'Bad key' end
    local data=tostring(p.data or ''); if #data>131072 then return 507,nil,'Blob too large' end
    local id,e=cluster.store(state,'blob:'..d..':'..key,data,{replicas=2,keepLocal=false}); if not id then return 507,nil,e end
    local old=state.blobs[d][key]; if old and old.objectId and old.objectId~=id then cluster.delete(state,old.objectId) end
    state.blobs[d][key]={objectId=id,size=#data,mime=C.cleanText(p.mime or 'application/octet-stream',40),public=p.public==true,updated=util.now()}
    return 200,{key=key,size=#data,objectId=id},true
  elseif a=='get' then
    local key=util.safeName(p.key,48); local b=state.blobs[d][key]; if not b then return 404,nil,'Blob not found' end
    if not b.public and not siteOwner(state,d,ctx) then return 403,nil,'Private blob' end
    local data,e=cluster.get(state,b.objectId); if data==nil then return 503,nil,e end
    return 200,{key=key,data=data,mime=b.mime,size=b.size},false
  elseif a=='list' then
    if not siteOwner(state,d,ctx) then return 403,nil,'Site owner required' end
    local out={};for k,b in pairs(state.blobs[d])do out[#out+1]={key=k,size=b.size,mime=b.mime,public=b.public,updated=b.updated}end;table.sort(out,function(x,y)return x.key<y.key end);return 200,{blobs=out},false
  elseif a=='delete' then
    if not siteOwner(state,d,ctx) then return 403,nil,'Site owner required' end
    local key=util.safeName(p.key,48); local b=state.blobs[d][key];if b and b.objectId then cluster.delete(state,b.objectId)end;state.blobs[d][key]=nil;return 200,{ok=true},true
  end
  return 404,nil,'Unknown blob action'
end
return M
]==],
  ["/spawnnet/server/services/chat.lua"]=[==[local util=dofile('/spawnnet/lib/util.lua')
local C=dofile('/spawnnet/server/services/common.lua')
local config=dofile('/spawnnet/lib/config.lua')
local M={}
function M.handle(state,req,ctx)
  local p=req.payload or {}; local a=req.action; local room=util.safeName(p.room or 'global',24)
  state.chats[room]=state.chats[room] or {messages={}}
  local r=state.chats[room]
  if a=='send' then
    local m={id=util.id('chat'),user=ctx.user,text=C.cleanText(p.text,300),time=util.now()}; r.messages[#r.messages+1]=m; util.limitArray(r.messages,config.maxChatMessages); return 201,{message=m},true
  elseif a=='read' then
    local limit=math.min(tonumber(p.limit) or 50,100); local out={}; for i=math.max(1,#r.messages-limit+1),#r.messages do out[#out+1]=r.messages[i] end; return 200,{room=room,messages=out},false
  elseif a=='rooms' then local out={}; for name,v in pairs(state.chats) do out[#out+1]={name=name,count=#v.messages} end; return 200,{rooms=out},false end
  return 404,nil,'Unknown chat action'
end
return M
]==],
  ["/spawnnet/server/services/common.lua"]=[==[local util=dofile('/spawnnet/lib/util.lua')
local M={}
function M.siteOwned(state,domain,user)
  local s=state.sites[domain]
  return s and s.owner==user
end
function M.requireSiteOwner(state,domain,ctx)
  local s=state.sites[domain]
  if not s then return nil,'Unknown site' end
  if not ctx or not ctx.user or s.owner~=ctx.user then return nil,'Not site owner' end
  return s
end
function M.cleanDomain(s) return util.safeName(s,32) end
function M.cleanPath(path)
  path=tostring(path or '/')
  if path=='' then path='/' end
  if path:sub(1,1)~='/' then path='/'..path end
  path=path:gsub('//+','/')
  if path:find('%.%.',1,true) then return nil end
  return path:sub(1,64)
end
function M.cleanText(s,max)
  s=tostring(s or '')
  s=s:gsub('[\0\r]','')
  if max then s=s:sub(1,max) end
  return s
end
function M.findUser(state,u)
  u=util.safeName(u,24)
  if state.accounts[u] then return u end
end
return M
]==],
  ["/spawnnet/server/services/database.lua"]=[==[local util=dofile('/spawnnet/lib/util.lua')
local C=dofile('/spawnnet/server/services/common.lua')
local config=dofile('/spawnnet/lib/config.lua')
local stateLib=dofile('/spawnnet/server/state.lua')
local M={}
local function getCol(state,d,c)
  stateLib.ensureSite(state,d); c=util.safeName(c,32); state.databases[d][c]=state.databases[d][c] or {}; return state.databases[d][c],c
end
function M.handle(state,req,ctx)
  local p=req.payload or {}; local d=C.cleanDomain(p.domain); local s,err=C.requireSiteOwner(state,d,ctx); if not s then return 403,nil,err end
  local col,c=getCol(state,d,p.collection or 'default'); local a=req.action
  if a=='get' then return 200,{value=col[tostring(p.key)]},false
  elseif a=='set' then
    if util.count(col)>=config.databaseCollectionRows and col[tostring(p.key)]==nil then return 507,nil,'Collection quota reached' end
    col[tostring(p.key)]=p.value; return 200,{ok=true},true
  elseif a=='insert' then
    if #col>=config.databaseCollectionRows then return 507,nil,'Collection quota reached' end
    col[#col+1]=p.value; return 201,{index=#col,value=p.value},true
  elseif a=='list' then
    local out={}; local limit=math.min(tonumber(p.limit) or 100,200)
    if #col>0 then for i=math.max(1,#col-limit+1),#col do out[#out+1]=col[i] end else for k,v in pairs(col) do out[#out+1]={key=k,value=v}; if #out>=limit then break end end end
    return 200,{rows=out,collection=c},false
  elseif a=='delete' then col[tostring(p.key)]=nil; return 200,{ok=true},true
  elseif a=='clear' then state.databases[d][c]={}; return 200,{ok=true},true end
  return 404,nil,'Unknown database action'
end
return M
]==],
  ["/spawnnet/server/services/dns.lua"]=[==[local util=dofile('/spawnnet/lib/util.lua')
local C=dofile('/spawnnet/server/services/common.lua')
local stateLib=dofile('/spawnnet/server/state.lua')
local M={}
function M.handle(state,req,ctx)
  local p=req.payload or {}; local a=req.action
  if a=='resolve' then
    local d=C.cleanDomain(p.domain); local r=state.domains[d]
    if not r or state.moderation.suspendedSites[d] then return 404,nil,'Domain not found' end
    return 200,{domain=d,owner=r.owner,title=r.title},false
  elseif a=='register' then
    if not ctx.user then return 401,nil,'Login required' end
    local d=C.cleanDomain(p.domain)
    if #d<2 then return 400,nil,'Domain must be at least 2 characters' end
    if state.domains[d] then return 409,nil,'Domain already registered' end
    state.domains[d]={owner=ctx.user,title=C.cleanText(p.title or d,48),created=util.now()}
    state.sites[d]={owner=ctx.user,title=C.cleanText(p.title or d,48),description='',tags={},draft={pages={}},published={pages={}},revisions={},assets={},clientScript='',serverScript='',publishedClientScript='',publishedServerScript='',settings={theme='default',listed=true}}
    stateLib.ensureSite(state,d)
    return 201,{domain=d},true
  elseif a=='release' then
    local d=C.cleanDomain(p.domain); local site,err=C.requireSiteOwner(state,d,ctx); if not site then return 403,nil,err end
    state.domains[d]=nil; state.sites[d]=nil; state.siteStorage[d]=nil; state.databases[d]=nil; state.telemetry[d]=nil; if state.analytics and state.analytics.sites then state.analytics.sites[d]=nil end
    return 200,{released=d},true
  elseif a=='listMine' then
    local out={}; for d,r in pairs(state.domains) do if r.owner==ctx.user then out[#out+1]={domain=d,title=r.title} end end
    table.sort(out,function(x,y)return x.domain<y.domain end)
    return 200,{domains=out},false
  end
  return 404,nil,'Unknown DNS action'
end
return M
]==],
  ["/spawnnet/server/services/events.lua"]=[==[local util=dofile('/spawnnet/lib/util.lua')
local C=dofile('/spawnnet/server/services/common.lua')
local stateLib=dofile('/spawnnet/server/state.lua')
local M={}
function M.enqueue(state,user,eventType,data,source)
  user=C.findUser(state,user); if not user then return nil,'Unknown user' end
  stateLib.ensureUser(state,user)
  local ev={id=util.id('event'),type=eventType,data=data or {},source=source,time=util.now()}
  state.events[user][#state.events[user]+1]=ev
  while #state.events[user]>300 do table.remove(state.events[user],1) end
  return ev
end
function M.handle(state,req,ctx)
  local p=req.payload or {}; local a=req.action; stateLib.ensureUser(state,ctx.user)
  if a=='poll' then
    local limit=math.min(tonumber(p.limit) or 25,100); local out={}
    for i=1,math.min(limit,#state.events[ctx.user]) do out[#out+1]=table.remove(state.events[ctx.user],1) end
    return 200,{events=out},#out>0
  elseif a=='peek' then return 200,{events=state.events[ctx.user]},false
  elseif a=='emit' then
    local ev,e=M.enqueue(state,p.to,p.type or 'message',p.data,ctx.user); if not ev then return 404,nil,e end
    return 201,{event=ev},true
  end
  return 404,nil,'Unknown event action'
end
return M
]==],
  ["/spawnnet/server/services/forum.lua"]=[==[local util=dofile('/spawnnet/lib/util.lua')
local C=dofile('/spawnnet/server/services/common.lua')
local stateLib=dofile('/spawnnet/server/state.lua')
local config=dofile('/spawnnet/lib/config.lua')
local M={}
function M.handle(state,req,ctx)
  local p=req.payload or {}; local a=req.action
  if a=='boards' then local out={}; for id,b in pairs(state.forums) do out[#out+1]={id=id,title=b.title,count=util.count(b.threads)} end; return 200,{boards=out},false
  elseif a=='createBoard' then
    local id=util.safeName(p.id,24); if state.forums[id] then return 409,nil,'Board exists' end
    state.forums[id]={title=C.cleanText(p.title or id,48),owner=ctx.user,threads={}}; return 201,{id=id},true
  elseif a=='threads' then
    local b=state.forums[util.safeName(p.board,24)]; if not b then return 404,nil,'Board not found' end
    local out={}; for _,t in pairs(b.threads) do out[#out+1]={id=t.id,title=t.title,author=t.author,created=t.created,replies=#t.replies,locked=t.locked} end; table.sort(out,function(x,y)return x.created>y.created end); return 200,{threads=out},false
  elseif a=='newThread' then
    local b=state.forums[util.safeName(p.board or 'general',24)]; if not b then return 404,nil,'Board not found' end
    local id=stateLib.nextId(state,'thread','thread'); local t={id=id,title=C.cleanText(p.title,80),author=ctx.user,body=C.cleanText(p.body,5000),created=util.now(),replies={},locked=false}; b.threads[id]=t; return 201,{thread=t},true
  elseif a=='getThread' then
    local b=state.forums[util.safeName(p.board or 'general',24)]; local t=b and b.threads[p.id]; if not t then return 404,nil,'Thread not found' end; return 200,{thread=t},false
  elseif a=='reply' then
    local b=state.forums[util.safeName(p.board or 'general',24)]; local t=b and b.threads[p.id]; if not t then return 404,nil,'Thread not found' end; if t.locked then return 423,nil,'Thread locked' end
    if #t.replies>=config.maxForumReplies then return 507,nil,'Reply limit reached' end
    local r={id=stateLib.nextId(state,'reply','reply'),author=ctx.user,body=C.cleanText(p.body,3000),created=util.now()}; t.replies[#t.replies+1]=r; return 201,{reply=r},true
  end
  return 404,nil,'Unknown forum action'
end
return M
]==],
  ["/spawnnet/server/services/jobs.lua"]=[==[local util=dofile('/spawnnet/lib/util.lua')
local C=dofile('/spawnnet/server/services/common.lua')
local config=dofile('/spawnnet/lib/config.lua')
local stateLib=dofile('/spawnnet/server/state.lua')
local M={}
local function bucket(state,d)
  state.jobs=state.jobs or {}; state.jobs[d]=state.jobs[d] or {}; return state.jobs[d]
end
local function owner(state,d,ctx)
  local s=state.sites[d]; return s and ctx and ctx.user and s.owner==ctx.user
end
local function publicJob(j)
  if not j then return nil end
  return {id=j.id,domain=j.domain,queue=j.queue,action=j.action,payload=util.deepcopy(j.payload),status=j.status,submitter=j.submitter,worker=j.worker,progress=j.progress,message=j.message,result=util.deepcopy(j.result),error=j.error,created=j.created,updated=j.updated,claimed=j.claimed,completed=j.completed}
end
function M.submitInternal(state,domain,queue,action,payload,submitter)
  domain=C.cleanDomain(domain); queue=util.safeName(queue or 'default',32); action=util.safeName(action or 'run',48)
  local site=state.sites[domain]; if not site then return nil,'Unknown site' end
  local jobs=bucket(state,domain); local count=0; for _ in pairs(jobs)do count=count+1 end
  if count>=config.maxJobsPerDomain then
    local old={};for _,j in pairs(jobs)do if j.status=='completed'or j.status=='failed'or j.status=='cancelled'then old[#old+1]=j end end
    table.sort(old,function(a,b)return(a.updated or 0)<(b.updated or 0)end)
    while count>=config.jobRetention and #old>0 do jobs[old[1].id]=nil;table.remove(old,1);count=count-1 end
    if count>=config.maxJobsPerDomain then return nil,'Job queue full' end
  end
  local id=util.id('job')
  local j={id=id,domain=domain,queue=queue,action=action,payload=util.deepcopy(payload or {}),status='queued',submitter=submitter,worker=nil,progress=0,message='Queued',created=util.now(),updated=util.now()}
  jobs[id]=j; return j
end
function M.handle(state,req,ctx)
  local p=req.payload or {}; local a=req.action; local d=C.cleanDomain(p.domain)
  if a=='submit' then
    if not owner(state,d,ctx) then return 403,nil,'Only the site owner can submit direct machine jobs; public sites should submit through server SpawnScript' end
    local j,e=M.submitInternal(state,d,p.queue,p.jobAction or p.actionName,p.payload,ctx.user); if not j then return 400,nil,e end
    return 201,{job=publicJob(j)},true
  elseif a=='status' then
    local j=bucket(state,d)[tostring(p.id or '')]; if not j then return 404,nil,'Job not found' end
    if not owner(state,d,ctx) and j.submitter~=ctx.user then return 403,nil,'Not allowed' end
    return 200,{job=publicJob(j)},false
  elseif a=='poll' then
    if not owner(state,d,ctx) then return 403,nil,'Site owner/API key required' end
    local queue=util.safeName(p.queue or 'default',32); local out={}
    for _,j in pairs(bucket(state,d))do if j.queue==queue and j.status=='queued'then out[#out+1]=publicJob(j)end end
    table.sort(out,function(x,y)return(x.created or 0)<(y.created or 0)end); while #out>(tonumber(p.limit)or 20)do table.remove(out)end
    return 200,{jobs=out},false
  elseif a=='claim' then
    if not owner(state,d,ctx) then return 403,nil,'Site owner/API key required' end
    local j=bucket(state,d)[tostring(p.id or '')]; if not j then return 404,nil,'Job not found' end
    if j.status~='queued' then return 409,nil,'Job is '..tostring(j.status) end
    j.status='running'; j.worker=tostring(p.worker or ('computer-'..os.getComputerID())); j.claimed=util.now(); j.updated=util.now(); j.message='Claimed by '..j.worker
    return 200,{job=publicJob(j)},true
  elseif a=='progress' or a=='complete' or a=='fail' then
    if not owner(state,d,ctx) then return 403,nil,'Site owner/API key required' end
    local j=bucket(state,d)[tostring(p.id or '')]; if not j then return 404,nil,'Job not found' end
    if a=='progress' then j.progress=math.max(0,math.min(100,tonumber(p.progress)or j.progress or 0));j.message=C.cleanText(p.message or j.message,160);j.updated=util.now()
    elseif a=='complete' then j.status='completed';j.progress=100;j.result=util.deepcopy(p.result or {});j.message=C.cleanText(p.message or 'Completed',160);j.completed=util.now();j.updated=util.now()
    else j.status='failed';j.error=C.cleanText(p.error or 'Worker failed',300);j.message='Failed';j.completed=util.now();j.updated=util.now() end
    return 200,{job=publicJob(j)},true
  elseif a=='cancel' then
    local j=bucket(state,d)[tostring(p.id or '')]; if not j then return 404,nil,'Job not found' end
    if not owner(state,d,ctx) and j.submitter~=ctx.user then return 403,nil,'Not allowed' end
    if j.status=='completed' or j.status=='failed' then return 409,nil,'Job already finished' end
    j.status='cancelled';j.message='Cancelled';j.updated=util.now();return 200,{job=publicJob(j)},true
  elseif a=='list' then
    if not owner(state,d,ctx) then return 403,nil,'Site owner/API key required' end
    local out={};for _,j in pairs(bucket(state,d))do out[#out+1]=publicJob(j)end;table.sort(out,function(x,y)return(x.created or 0)>(y.created or 0)end);while #out>(tonumber(p.limit)or 50)do table.remove(out)end;return 200,{jobs=out},false
  end
  return 404,nil,'Unknown jobs action'
end
return M
]==],
  ["/spawnnet/server/services/mail.lua"]=[==[local util=dofile('/spawnnet/lib/util.lua')
local C=dofile('/spawnnet/server/services/common.lua')
local config=dofile('/spawnnet/lib/config.lua')
local stateLib=dofile('/spawnnet/server/state.lua')
local M={}
local function ensureSent(state,user)state.sentMail=state.sentMail or{};state.sentMail[user]=state.sentMail[user]or{};return state.sentMail[user]end
function M.sendInternal(state,from,to,subject,body,meta)
  to=C.findUser(state,to);if not to then return nil,'Unknown recipient'end;stateLib.ensureUser(state,to);local id=stateLib.nextId(state,'mail','mail');local m={id=id,from=from,to=to,subject=C.cleanText(subject,64),body=C.cleanText(body,6000),time=util.now(),read=false,meta=meta or{}};table.insert(state.mail[to],1,m);while #state.mail[to]>config.maxMailPerUser do table.remove(state.mail[to])end;return m
end
function M.handle(state,req,ctx)
  local p=req.payload or{};local a=req.action;stateLib.ensureUser(state,ctx.user);ensureSent(state,ctx.user)
  if a=='send'then local m,e=M.sendInternal(state,ctx.user,p.to,p.subject,p.body);if not m then return 404,nil,e end;local sent=util.deepcopy(m);sent.read=true;table.insert(state.sentMail[ctx.user],1,sent);while #state.sentMail[ctx.user]>config.maxMailPerUser do table.remove(state.sentMail[ctx.user])end;return 201,{message=m},true
  elseif a=='inbox'then local out={};local limit=math.min(tonumber(p.limit)or 50,100);for i=1,math.min(limit,#state.mail[ctx.user])do out[i]=state.mail[ctx.user][i]end;return 200,{messages=out},false
  elseif a=='sent'then local out={};local box=ensureSent(state,ctx.user);local limit=math.min(tonumber(p.limit)or 50,100);for i=1,math.min(limit,#box)do out[i]=box[i]end;return 200,{messages=out},false
  elseif a=='read'then for _,m in ipairs(state.mail[ctx.user])do if m.id==p.id then m.read=true;return 200,{message=m},true end end;return 404,nil,'Message not found'
  elseif a=='delete'then for i,m in ipairs(state.mail[ctx.user])do if m.id==p.id then table.remove(state.mail[ctx.user],i);return 200,{ok=true},true end end;return 404,nil,'Message not found'
  elseif a=='deleteSent'then local box=ensureSent(state,ctx.user);for i,m in ipairs(box)do if m.id==p.id then table.remove(box,i);return 200,{ok=true},true end end;return 404,nil,'Message not found'
  elseif a=='unreadCount'then local n=0;for _,m in ipairs(state.mail[ctx.user])do if not m.read then n=n+1 end end;return 200,{count=n},false end
  return 404,nil,'Unknown mail action'
end
return M]==],
  ["/spawnnet/server/services/moderation.lua"]=[==[local util=dofile('/spawnnet/lib/util.lua')
local C=dofile('/spawnnet/server/services/common.lua')
local auth=dofile('/spawnnet/server/auth.lua')
local stateLib=dofile('/spawnnet/server/state.lua')
local crypto=dofile('/spawnnet/lib/crypto.lua')
local M={}
function M.handle(state,req,ctx)
  local p=req.payload or {}; local a=req.action
  if a=='report' then
    local id=stateLib.nextId(state,'report','report'); local r={id=id,reporter=ctx.user,targetType=C.cleanText(p.targetType,20),target=C.cleanText(p.target,64),reason=C.cleanText(p.reason,500),time=util.now(),status='open'}; state.moderation.reports[id]=r; return 201,{report=r},true
  end
  if not auth.isAdmin(ctx) then return 403,nil,'Admin required' end
  if a=='reports' then local out={}; for _,r in pairs(state.moderation.reports) do out[#out+1]=r end; return 200,{reports=out},false
  elseif a=='suspendSite' then local d=util.safeName(p.domain,32); state.moderation.suspendedSites[d]=p.suspended~=false; return 200,{domain=d,suspended=state.moderation.suspendedSites[d]},true
  elseif a=='suspendUser' then local u=util.safeName(p.user,24); state.moderation.suspendedUsers[u]=p.suspended~=false; return 200,{user=u,suspended=state.moderation.suspendedUsers[u]},true
  elseif a=='grantRole' then
    local u=util.safeName(p.user,24); local acc=state.accounts[u]; if not acc then return 404,nil,'Unknown user' end; local role=util.safeName(p.role,20); for _,r in ipairs(acc.roles) do if r==role then return 200,{ok=true},false end end; acc.roles[#acc.roles+1]=role; return 200,{ok=true},true
  elseif a=='createEnrollment'then
    state.registrationTickets=state.registrationTickets or{};local code=crypto.randomHex(16);local id=code:sub(1,8);state.registrationTickets[id]={id=id,code=code,created=util.now(),createdBy=ctx.user,expires=util.now()+900,used=false};return 201,{code=code,expiresIn=900},true
  elseif a=='enrollments'then
    local out={};for _,t in pairs(state.registrationTickets or{})do out[#out+1]={id=t.id,created=t.created,expires=t.expires,used=t.used,usedBy=t.usedBy}end;table.sort(out,function(x,y)return(x.created or 0)>(y.created or 0)end);return 200,{tickets=out},false
  elseif a=='revokeEnrollment'then local id=tostring(p.id or''):lower();if(state.registrationTickets or{})[id]then state.registrationTickets[id]=nil;return 200,{ok=true},true end;return 404,nil,'Enrollment not found'
  elseif a=='revokeRole'then
    local u=util.safeName(p.user,24);local role=util.safeName(p.role,20);local acc=state.accounts[u];if not acc then return 404,nil,'Unknown user'end;local out={};for _,r in ipairs(acc.roles or{})do if r~=role then out[#out+1]=r end end;acc.roles=out;return 200,{ok=true},true
  elseif a=='revokePackage'then
    local hash=tostring(p.hash or''):lower();if not hash:match('^[0-9a-f]+$')or #hash~=64 then return 400,nil,'A full 64-character package hash is required'end
    state.packageRevocations=state.packageRevocations or{};state.packageRevocations[hash]={hash=hash,reason=C.cleanText(p.reason or'Administrator revocation',160),time=util.now(),by=ctx.user};return 200,{ok=true,hash=hash},true
  elseif a=='restorePackage'then
    local hash=tostring(p.hash or''):lower();if(state.packageRevocations or{})[hash]then state.packageRevocations[hash]=nil;return 200,{ok=true},true end;return 404,nil,'Revocation not found'
  elseif a=='packageRevocations'then
    local out={};for _,r in pairs(state.packageRevocations or{})do out[#out+1]=r end;table.sort(out,function(x,y)return(x.time or 0)>(y.time or 0)end);return 200,{revocations=out},false
  elseif a=='securityLog'then local h=fs.open('/spawnnet/log/security.log','r');local raw=h and h.readAll()or'';if h then h.close()end;return 200,{log=raw:sub(-24000)},false
  end
  return 404,nil,'Unknown moderation action'
end
return M
]==],
  ["/spawnnet/server/services/nodes.lua"]=[==[local auth=dofile('/spawnnet/server/auth.lua')
local cluster=dofile('/spawnnet/server/cluster.lua')
local util=dofile('/spawnnet/lib/util.lua')
local config=dofile('/spawnnet/lib/config.lua')
local M={}
function M.handle(state,req,ctx)
  if not auth.isAdmin(ctx) then return 403,nil,'Admin required' end
  local p=req.payload or {}; local a=req.action
  if a=='summary' or a=='list' then
    local s=cluster.summary(state)
    local pending={}; for id,n in pairs(state.pendingNodes or {}) do local x={};for k,v in pairs(n)do x[k]=v end;x.id=tonumber(id)or id;pending[#pending+1]=x end
    table.sort(pending,function(x,y)return tonumber(x.id)<tonumber(y.id)end)
    s.pendingNodes=pending
    return 200,s,false
  elseif a=='approve' then
    local sc=util.loadTable(config.serverConfig,{});local n,e=cluster.approve(state,p.id,p.name,p.pairCode,sc.coreIdentity); if not n then return 404,nil,e end
    local out={};for k,v in pairs(n)do if k~='token' then out[k]=v end end
    return 200,{node=out},true
  elseif a=='rebalance' then local r=cluster.rebalance(state);return 200,r,true
  elseif a=='drain'then local n,e=cluster.setDraining(state,p.id,true);if not n then return 404,nil,e end;return 200,{ok=true},true
  elseif a=='activate'then local n,e=cluster.setDraining(state,p.id,false);if not n then return 404,nil,e end;return 200,{ok=true},true
  elseif a=='clearQuarantine'then local n,e=cluster.clearQuarantine(state,p.id);if not n then return 404,nil,e end;return 200,{ok=true},true
  elseif a=='remove' then cluster.remove(state,p.id); return 200,{ok=true},true
  end
  return 404,nil,'Unknown node action'
end
return M
]==],
  ["/spawnnet/server/services/package.lua"]=[==[-- SpawnNet package service - SpawnNet 2.3.0
local util=dofile('/spawnnet/lib/util.lua')
local C=dofile('/spawnnet/server/services/common.lua')
local auth=dofile('/spawnnet/server/auth.lua')
local crypto=dofile('/spawnnet/lib/crypto.lua')
local M={}
local MAX_APP_FILES=64
local MAX_APP_FILE_BYTES=65536
local MAX_APP_TOTAL=220000
local MAX_SYSTEM_FILES=128
local MAX_SYSTEM_FILE_BYTES=262144
local MAX_SYSTEM_TOTAL=700000
local RELEASE_DIR='/spawnnet/releases'
local ALLOWED_PERMS={filesystem=true,peripheral=true,modem=true,rednet=true,shell=true,http=true,startup=true,commands=true}

local function count(t)local n=0;for _ in pairs(t or{})do n=n+1 end;return n end
local function cleanDomain(v)
  if C.cleanDomain then return C.cleanDomain(v) end
  local d=util.safeName(v or'',32);if d==''then return nil end;return d
end
local function cleanName(v)return util.safeName(v or'',32)end
local function cleanFilePath(path)
  path=tostring(path or''):gsub('\\','/'):gsub('^/+','')
  if path==''or #path>160 then return nil end
  for part in path:gmatch('[^/]+')do if part==''or part=='.'or part=='..'then return nil end end
  return path
end
local function normalizePerms(xs)
  local out,seen={},{}
  for _,p in ipairs(type(xs)=='table'and xs or{})do
    p=util.safeName(p,24)
    if ALLOWED_PERMS[p]and not seen[p]then seen[p]=true;out[#out+1]=p end
  end
  table.sort(out);return out
end
local function normalizeCommands(t)
  local out={};if type(t)~='table'then return out end
  for name,path in pairs(t)do
    name=util.safeName(name,32);path=cleanFilePath(path)
    if name~=''and path then out[name]=path end
  end
  return out
end
local function appHash(pkg)
  local paths={};for p in pairs(pkg.files or{})do paths[#paths+1]=p end;table.sort(paths)
  local parts={tostring(pkg.domain or''),tostring(pkg.name or''),tostring(pkg.version or''),tostring(pkg.title or''),tostring(pkg.entry or''),tostring(pkg.service or'')}
  local perms={};for _,p in ipairs(pkg.permissions or{})do perms[#perms+1]=p end;table.sort(perms)
  for _,p in ipairs(perms)do parts[#parts+1]='perm:'..p end
  local cmds={};for n in pairs(pkg.commands or{})do cmds[#cmds+1]=n end;table.sort(cmds)
  for _,n in ipairs(cmds)do parts[#parts+1]='cmd:'..n..'='..tostring(pkg.commands[n])end
  for _,p in ipairs(paths)do parts[#parts+1]='file:'..p..':'..crypto.sha256(tostring(pkg.files[p]or''))end
  return crypto.sha256(table.concat(parts,'\0'))
end
local function systemHash(pkg)
  local paths={};for p in pairs(pkg.files or{})do paths[#paths+1]=p end;table.sort(paths)
  local parts={tostring(pkg.name or''),tostring(pkg.version or''),tostring(pkg.component or''),tostring(pkg.channel or''),tostring(pkg.restartRequired and true or false)}
  for _,p in ipairs(paths)do parts[#parts+1]='file:'..p..':'..crypto.sha256(tostring(pkg.files[p]or''))end
  local managed={};for _,p in ipairs(pkg.managedFiles or{})do managed[#managed+1]=p end;table.sort(managed);for _,p in ipairs(managed)do parts[#parts+1]='managed:'..p end
  return crypto.sha256(table.concat(parts,'\0'))
end
local function appManifest(pkg)
  if not pkg then return nil end
  return {domain=pkg.domain,name=pkg.name,title=pkg.title,version=pkg.version,description=pkg.description,publisher=pkg.publisher,permissions=util.deepcopy(pkg.permissions or{}),entry=pkg.entry,service=pkg.service,commands=util.deepcopy(pkg.commands or{}),files=count(pkg.files),totalBytes=pkg.totalBytes or 0,hash=pkg.hash,published=pkg.published,updated=pkg.updated,runAfterInstall=pkg.runAfterInstall and true or false}
end
local function systemManifest(pkg)
  if not pkg then return nil end
  return {name=pkg.name,version=pkg.version,description=pkg.description,owner=pkg.owner,component=pkg.component or pkg.name,channel=pkg.channel or'stable',restartRequired=pkg.restartRequired and true or false,files=count(pkg.files),totalBytes=pkg.totalBytes or 0,hash=pkg.hash,published=pkg.published,updated=pkg.updated,managedFiles=util.deepcopy(pkg.managedFiles or{})}
end
local function siteOwner(state,d,ctx)
  local s=state.sites and state.sites[d];return s and ctx and s.owner==ctx.user
end
local function appBucket(state,d)
  state.appPackages=state.appPackages or{};state.appPackages[d]=state.appPackages[d]or{};return state.appPackages[d]
end
local function revoked(state,pkg)
  local r=state.packageRevocations and state.packageRevocations[pkg and pkg.hash]
  return r and true or false,r
end
local function normalizeFiles(src,maxFiles,maxFileBytes,maxTotal)
  if type(src)~='table'then return nil,'Package files table required'end
  local files,total,n={};total=0;n=0
  for path,data in pairs(src)do
    local cp=cleanFilePath(path);if not cp then return nil,'Bad package file path: '..tostring(path)end
    data=tostring(data or'');if #data>maxFileBytes then return nil,'Package file too large: '..cp end
    n=n+1;if n>maxFiles then return nil,'Too many package files'end
    total=total+#data;if total>maxTotal then return nil,'Package exceeds '..tostring(maxTotal)..' bytes'end
    files[cp]=data
  end
  if n==0 then return nil,'Package must contain at least one file'end
  return files,nil,total
end
local function publishApp(state,p,ctx)
  local d=cleanDomain(p.domain);if not d then return 400,nil,'Bad domain'end
  if not siteOwner(state,d,ctx)then return 403,nil,'Only the site owner can publish application packages'end
  local name=cleanName(p.name);if name==''then return 400,nil,'Package name required'end
  local version=C.cleanText(p.version or'',24);if version==''then return 400,nil,'Version required'end
  local files,e,total=normalizeFiles(p.files,MAX_APP_FILES,MAX_APP_FILE_BYTES,MAX_APP_TOTAL);if not files then return 400,nil,e end
  local entry=p.entry and cleanFilePath(p.entry)or nil;if entry and not files[entry]then return 400,nil,'Entry file not found in package'end
  local service=p.service and cleanFilePath(p.service)or nil;if service and not files[service]then return 400,nil,'Service file not found in package'end
  local pkg={domain=d,name=name,title=C.cleanText(p.title or name,48),version=version,description=C.cleanText(p.description or'',240),publisher=ctx.user,permissions=normalizePerms(p.permissions),entry=entry,service=service,commands=normalizeCommands(p.commands),files=files,totalBytes=total,published=util.now(),updated=util.now(),runAfterInstall=p.runAfterInstall and true or false}
  pkg.hash=appHash(pkg)
  local bucket=appBucket(state,d);local old=bucket[name];if old and old.published then pkg.published=old.published end;bucket[name]=pkg
  return 201,{package=appManifest(pkg)},true
end
local function ensureDir(path)
  if path==''or path=='/'or fs.exists(path)then return end
  local parent=fs.getDir(path);if parent and parent~=''then ensureDir(parent)end;fs.makeDir(path)
end
local function releasePath(name)return RELEASE_DIR..'/'..cleanName(name)..'.pkg'end
local function loadSystem(state,name)
  name=cleanName(name)
  local path=releasePath(name)
  if fs.exists(path)then
    local h=fs.open(path,'r');if h then local raw=h.readAll();h.close();local ok,v=pcall(textutils.unserialize,raw);if ok and type(v)=='table'then return v end end
  end
  return state.packages and state.packages[name]or nil
end
local function saveSystem(name,pkg)
  ensureDir(RELEASE_DIR);local path=releasePath(name);local tmp=path..'.tmp'
  if fs.exists(tmp)then fs.delete(tmp)end
  local h=assert(fs.open(tmp,'w'));h.write(textutils.serialize(pkg));h.close()
  if fs.exists(path)then fs.delete(path)end;fs.move(tmp,path)
end
local function publishSystem(state,p,ctx)
  if not auth.isAdmin(ctx)then return 403,nil,'Admin required'end
  local name=cleanName(p.name);if name==''then return 400,nil,'Package name required'end
  local version=C.cleanText(p.version or'',24);if version==''then return 400,nil,'Version required'end
  local files,e,total=normalizeFiles(p.files,MAX_SYSTEM_FILES,MAX_SYSTEM_FILE_BYTES,MAX_SYSTEM_TOTAL);if not files then return 400,nil,e end
  local managed={};for path in pairs(files)do managed[#managed+1]=path end;table.sort(managed)
  local pkg={name=name,version=version,description=C.cleanText(p.description or'',240),files=files,managedFiles=managed,totalBytes=total,owner=ctx.user,component=C.cleanText(p.component or name,24),channel=C.cleanText(p.channel or'stable',16),restartRequired=p.restartRequired and true or false,published=util.now(),updated=util.now()}
  local old=state.packages and state.packages[name];if old and old.published then pkg.published=old.published end
  pkg.hash=systemHash(pkg);state.packages=state.packages or{};state.packages[name]={version=pkg.version,description=pkg.description,owner=pkg.owner,published=pkg.published,hash=pkg.hash,component=pkg.component,channel=pkg.channel}
  saveSystem(name,pkg)
  return 201,{package=systemManifest(pkg)},true
end
local function stageCore(state,p,ctx)
  if not auth.isAdmin(ctx)then return 403,nil,'Admin required'end
  local name=cleanName(p.name or'core');if name~='core'then return 400,nil,'Only the core system package may be staged on the Core'end
  local pkg=loadSystem(state,name);if not pkg then return 404,nil,'Core update package not found'end
  local dir='/spawnnet/update';if not fs.exists(dir)then fs.makeDir(dir)end
  local path=dir..'/core-staged.pkg';local tmp=path..'.tmp';if fs.exists(tmp)then fs.delete(tmp)end
  local h=assert(fs.open(tmp,'w'));h.write(textutils.serialize(pkg));h.close();if fs.exists(path)then fs.delete(path)end;fs.move(tmp,path)
  return 200,{staged=true,version=pkg.version,hash=pkg.hash,path=path},false
end
function M.handle(state,req,ctx)
  local p=req.payload or{};local a=req.action
  local hasDomain=p.domain~=nil and tostring(p.domain)~=''
  if hasDomain then
    local d=cleanDomain(p.domain);if not d then return 400,nil,'Bad domain'end
    local name=cleanName(p.name);local bucket=(state.appPackages or{})[d]or{}
    if a=='manifest'then local pkg=bucket[name];if not pkg then return 404,nil,'Package not found'end;if revoked(state,pkg)then return 410,nil,'Package version revoked by a SpawnNet administrator'end;return 200,{package=appManifest(pkg)},false end
    if a=='get'then local pkg=bucket[name];if not pkg then return 404,nil,'Package not found'end;if revoked(state,pkg)then return 410,nil,'Package version revoked by a SpawnNet administrator'end;return 200,{package=util.deepcopy(pkg)},false end
    if a=='list'then local out={};for _,pkg in pairs(bucket)do if not revoked(state,pkg)then out[#out+1]=appManifest(pkg)end end;table.sort(out,function(x,y)return tostring(x.title)<tostring(y.title)end);return 200,{domain=d,packages=out},false end
    if a=='publish'then return publishApp(state,p,ctx)end
    if a=='delete'then if not siteOwner(state,d,ctx)then return 403,nil,'Only the site owner can delete application packages'end;if not bucket[name]then return 404,nil,'Package not found'end;bucket[name]=nil;return 200,{deleted=name},true end
    return 404,nil,'Unknown package action'
  end
  state.packages=state.packages or{}
  if a=='manifest'then local name=cleanName(p.name or'client');local pkg=loadSystem(state,name);if not pkg then return 404,nil,'Package not found'end;if revoked(state,pkg)then return 410,nil,'System release revoked'end;return 200,{package=systemManifest(pkg),name=name,version=pkg.version,description=pkg.description,files=count(pkg.files)},false end
  if a=='get'then local name=cleanName(p.name or'client');local pkg=loadSystem(state,name);if not pkg then return 404,nil,'Package not found'end;if revoked(state,pkg)then return 410,nil,'System release revoked'end;return 200,{package=util.deepcopy(pkg)},false end
  if a=='listSystem'then
    local out,seen={},{}
    if fs.exists(RELEASE_DIR)then for _,f in ipairs(fs.list(RELEASE_DIR))do local n=f:match('^(.-)%.pkg$');if n then local pkg=loadSystem(state,n);if pkg then out[#out+1]=systemManifest(pkg);seen[n]=true end end end end
    for n in pairs(state.packages or{})do if not seen[n]then local pkg=loadSystem(state,n);if pkg and pkg.files then out[#out+1]=systemManifest(pkg)end end end
    table.sort(out,function(x,y)return tostring(x.name)<tostring(y.name)end);return 200,{packages=out},false
  end
  if a=='publish'then return publishSystem(state,p,ctx)end
  if a=='stageCore'then return stageCore(state,p,ctx)end
  return 404,nil,'Unknown package action'
end
return M
]==],
  ["/spawnnet/server/services/search.lua"]=[==[local util=dofile('/spawnnet/lib/util.lua')
local C=dofile('/spawnnet/server/services/common.lua')
local M={}
local function extractPage(page)
  local out={page.title or ''}
  local function walk(elements)
    for _,e in ipairs(elements or {}) do
      if e.text then out[#out+1]=tostring(e.text) end
      if e.label then out[#out+1]=tostring(e.label) end
      if e.children then walk(e.children) end
    end
  end
  walk(page.elements); return table.concat(out,' ')
end
function M.indexSite(site)
  local parts={site.title or '',site.description or '',table.concat(site.tags or {},' ')}
  for path,page in pairs((site.published or {}).pages or {}) do parts[#parts+1]=path; parts[#parts+1]=extractPage(page) end
  site.searchText=table.concat(parts,' '):lower()
end
function M.handle(state,req,ctx)
  if req.action~='query' then return 404,nil,'Unknown search action' end
  local q=C.cleanText((req.payload or {}).q,80):lower(); local tokens={}; for x in q:gmatch('%S+') do tokens[#tokens+1]=x end
  local out={}
  for d,site in pairs(state.sites) do
    if not state.moderation.suspendedSites[d] and (site.settings==nil or site.settings.listed~=false) then
      if not site.searchText then M.indexSite(site) end
      local score=0; for _,t in ipairs(tokens) do if site.searchText:find(t,1,true) then score=score+1 end end
      if q=='' or score>0 then out[#out+1]={domain=d,title=site.title,description=site.description,score=score} end
    end
  end
  table.sort(out,function(a,b) if a.score==b.score then return a.domain<b.domain else return a.score>b.score end end); while #out>50 do table.remove(out) end
  return 200,{results=out},false
end
return M
]==],
  ["/spawnnet/server/services/storage.lua"]=[==[local util=dofile('/spawnnet/lib/util.lua')
local C=dofile('/spawnnet/server/services/common.lua')
local config=dofile('/spawnnet/lib/config.lua')
local stateLib=dofile('/spawnnet/server/state.lua')
local M={}
local function owner(state,d,ctx) local s,e=C.requireSiteOwner(state,d,ctx); if not s then return nil,e end; stateLib.ensureSite(state,d); return s end
function M.handle(state,req,ctx)
  local p=req.payload or {}; local d=C.cleanDomain(p.domain); local a=req.action
  local s,err=owner(state,d,ctx); if not s then return 403,nil,err end
  local st=state.siteStorage[d]
  if a=='get' then return 200,{value=util.tablePathGet(st,p.key,nil)},false
  elseif a=='set' then
    if type(p.key)~='string' or #p.key>80 then return 400,nil,'Bad key' end
    if util.count(st)>=config.siteStorageKeys and util.tablePathGet(st,p.key,nil)==nil then return 507,nil,'Site storage quota reached' end
    util.tablePathSet(st,p.key,p.value); return 200,{ok=true},true
  elseif a=='inc' then
    local v=tonumber(util.tablePathGet(st,p.key,0)) or 0; v=v+(tonumber(p.amount) or 1); util.tablePathSet(st,p.key,v); return 200,{value=v},true
  elseif a=='list' then return 200,{storage=st},false
  elseif a=='delete' then util.tablePathSet(st,p.key,nil); return 200,{ok=true},true end
  return 404,nil,'Unknown storage action'
end
return M
]==],
  ["/spawnnet/server/services/telemetry.lua"]=[==[local util=dofile('/spawnnet/lib/util.lua')
local C=dofile('/spawnnet/server/services/common.lua')
local config=dofile('/spawnnet/lib/config.lua')
local M={}
function M.handle(state,req,ctx)
  local p=req.payload or {}; local a=req.action; local d=C.cleanDomain(p.domain)
  local site=state.sites[d]; if not site then return 404,nil,'Unknown site' end
  state.telemetry[d]=state.telemetry[d] or {}
  if a=='push' then
    if site.owner~=ctx.user then return 403,nil,'Not site owner' end
    local stream=util.safeName(p.stream or 'default',32); state.telemetry[d][stream]=state.telemetry[d][stream] or {}
    local point={time=util.now(),data=p.data or {},computer=p.computer}; local arr=state.telemetry[d][stream]; arr[#arr+1]=point; util.limitArray(arr,config.telemetryPoints); return 201,{point=point},true
  elseif a=='get' then
    local stream=util.safeName(p.stream or 'default',32); local arr=state.telemetry[d][stream] or {}; local n=math.min(tonumber(p.limit) or 30,config.telemetryPoints); local out={}; for i=math.max(1,#arr-n+1),#arr do out[#out+1]=arr[i] end; return 200,{domain=d,stream=stream,points=out,last=arr[#arr]},false
  elseif a=='streams' then local out={}; for name,arr in pairs(state.telemetry[d]) do out[#out+1]={name=name,count=#arr,last=arr[#arr]} end; return 200,{streams=out},false end
  return 404,nil,'Unknown telemetry action'
end
return M
]==],
  ["/spawnnet/server/services/users.lua"]=[==[local util=dofile('/spawnnet/lib/util.lua')
local C=dofile('/spawnnet/server/services/common.lua')
local stateLib=dofile('/spawnnet/server/state.lua')
local M={}
function M.handle(state,req,ctx)
  local p=req.payload or {}; local a=req.action
  if a=='me' then
    local acc=util.deepcopy(state.accounts[ctx.user]); if not acc then return 404,nil,'Unknown user' end; acc.verifier=nil
    stateLib.ensureUser(state,ctx.user); return 200,{account=acc},false
  elseif a=='profile' then
    local u=C.findUser(state,p.user); if not u then return 404,nil,'Unknown user' end; local acc=state.accounts[u]
    return 200,{username=u,profile=util.deepcopy(acc.profile or {}),created=acc.created},false
  elseif a=='update' then
    local acc=state.accounts[ctx.user]; acc.profile=acc.profile or {}
    if p.displayName~=nil then acc.profile.displayName=C.cleanText(p.displayName,32) end
    if p.bio~=nil then acc.profile.bio=C.cleanText(p.bio,300) end
    return 200,{profile=acc.profile},true
  end
  return 404,nil,'Unknown users action'
end
return M
]==],
  ["/spawnnet/server/services/web.lua"]=[==[local util=dofile('/spawnnet/lib/util.lua')
local config=dofile('/spawnnet/lib/config.lua')
local C=dofile('/spawnnet/server/services/common.lua')
local stateLib=dofile('/spawnnet/server/state.lua')
local script=dofile('/spawnnet/lib/spawnscript.lua')
local search=dofile('/spawnnet/server/services/search.lua')
local mail=dofile('/spawnnet/server/services/mail.lua')
local events=dofile('/spawnnet/server/services/events.lua')
local jobs=dofile('/spawnnet/server/services/jobs.lua')
local cluster=dofile('/spawnnet/server/cluster.lua')
local M={}

local function validateElements(elements,count)
  count=count or {n=0}
  if type(elements)~='table' then return false,'elements must be a table' end
  for _,e in ipairs(elements) do
    count.n=count.n+1
    if count.n>config.maxPageElements then return false,'Too many page elements' end
    if type(e)~='table' or type(e.type)~='string' then return false,'Malformed element' end
    local allowed={text=true,heading=true,button=true,input=true,checkbox=true,select=true,progress=true,image=true,separator=true,panel=true,row=true,column=true,table=true,badge=true,tabs=true,list=true,modal=true}
    if not allowed[e.type] then return false,'Unknown element '..tostring(e.type) end
    if e.children then
      local ok,err=validateElements(e.children,count)
      if not ok then return false,err end
    end
  end
  return true
end

local function cleanPage(page)
  if type(page)~='table' then return nil,'Page must be a table' end
  local p=util.deepcopy(page)
  p.title=C.cleanText(p.title or 'Untitled',64)
  p.elements=p.elements or {}
  local ok,e=validateElements(p.elements)
  if not ok then return nil,e end
  return p
end

local function ownerSite(state,d,ctx)
  local s,e=C.requireSiteOwner(state,d,ctx)
  if not s then return nil,e end
  stateLib.ensureSite(state,d)
  return s
end

local function scriptApi(state,domain,caller,patches)
  stateLib.ensureSite(state,domain)
  local owner=state.sites[domain].owner
  local dirty={value=false}
  local function mark() dirty.value=true end
  local function dbcol(name)
    name=util.safeName(name or 'default',32)
    state.databases[domain][name]=state.databases[domain][name] or {}
    return state.databases[domain][name]
  end
  local function ownerIsAdmin()
    local acc=state.accounts[owner]
    for _,r in ipairs((acc and acc.roles) or {}) do if r=='admin' then return true end end
    return false
  end
  local function api(method,args,vars)
    if method=='storage.get' then
      return util.tablePathGet(state.siteStorage[domain],tostring(args[1] or ''),nil)
    elseif method=='storage.set' then
      util.tablePathSet(state.siteStorage[domain],tostring(args[1] or ''),args[2]); mark(); return true
    elseif method=='storage.inc' then
      local k=tostring(args[1] or '')
      local v=tonumber(util.tablePathGet(state.siteStorage[domain],k,0)) or 0
      v=v+(tonumber(args[2]) or 1); util.tablePathSet(state.siteStorage[domain],k,v); mark(); return v
    elseif method=='db.get' then
      return dbcol(args[1])[tostring(args[2])]
    elseif method=='db.set' then
      dbcol(args[1])[tostring(args[2])]=args[3]; mark(); return true
    elseif method=='db.insert' then
      local c=dbcol(args[1]); if #c>=config.databaseCollectionRows then return nil,'collection quota' end
      c[#c+1]=args[2]; mark(); return #c
    elseif method=='db.list' then
      return util.deepcopy(dbcol(args[1]))
    elseif method=='mail.send' then
      local m,e=mail.sendInternal(state,domain..'@site',args[1],args[2],args[3],{domain=domain})
      if not m then return nil,e end; mark(); return m.id
    elseif method=='event.emit' then
      local ev,e=events.enqueue(state,args[1],args[2] or 'site.event',args[3],domain)
      if not ev then return nil,e end; mark(); return ev.id
    elseif method=='jobs.submit' then
      local payload={item=args[3],count=tonumber(args[4]) or args[4],note=args[5]}
      local j,e=jobs.submitInternal(state,domain,args[1] or 'default',args[2] or 'run',payload,caller or 'guest')
      if not j then return nil,e end; mark(); return j.id
    elseif method=='jobs.status' then
      local j=((state.jobs or {})[domain] or {})[tostring(args[1] or '')]
      if not j then return nil end
      return util.deepcopy(j)
    elseif method=='telemetry.last' then
      local stream=util.safeName(args[1] or 'default',32)
      local arr=((state.telemetry[domain] or {})[stream] or {})
      local point=arr[#arr]
      if not point then return nil end
      local data=util.deepcopy(point.data or {})
      data._time=point.time; data._computer=point.computer
      return data
    elseif method=='telemetry.history' then
      local stream=util.safeName(args[1] or 'default',32); local limit=math.min(tonumber(args[2]) or 20,100)
      local arr=((state.telemetry[domain] or {})[stream] or {}); local out={}
      for i=math.max(1,#arr-limit+1),#arr do out[#out+1]=util.deepcopy(arr[i]) end
      return out
    elseif method=='blob.put' then
      if caller~=owner then return nil,'site owner required' end
      local key=util.safeName(args[1] or 'data',48); local data=tostring(args[2] or '')
      state.blobs=state.blobs or {}; state.blobs[domain]=state.blobs[domain] or {}
      local id,e=cluster.store(state,'blob:'..domain..':'..key,data,{replicas=config.objectReplicas or 2,keepLocal=false})
      if not id then return nil,e end
      state.blobs[domain][key]={objectId=id,size=#data,mime='text/plain',public=false,updated=util.now()};mark();return id
    elseif method=='blob.get' then
      local key=util.safeName(args[1] or 'data',48); local b=state.blobs and state.blobs[domain] and state.blobs[domain][key]
      if not b then return nil end
      return cluster.get(state,b.objectId)
    elseif method=='network.cluster' then
      if not ownerIsAdmin() then return nil,'admin-owned site required' end
      return cluster.summary(state)
    elseif method=='user.name' then return caller
    elseif method=='user.isOwner' then return caller~=nil and caller==owner
    elseif method=='user.authenticated' then return caller~=nil
    elseif method=='site.owner' then return owner
    elseif method=='time.now' then return util.now()
    elseif method=='ui.setText' or method=='ui.setValue' or method=='ui.alert' or method=='ui.navigate' or method=='ui.setVisible' then
      patches[#patches+1]={method=method,args=util.deepcopy(args)}; return true
    elseif method=='chat.post' then
      if not caller then return nil,'login required' end
      local room=util.safeName(args[1] or 'global',24); state.chats[room]=state.chats[room] or {messages={}}
      local m={id=util.id('chat'),user=caller,text=C.cleanText(args[2],300),time=util.now()}
      state.chats[room].messages[#state.chats[room].messages+1]=m; util.limitArray(state.chats[room].messages,config.maxChatMessages); mark(); return m.id
    end
    return nil,'unknown API method '..tostring(method)
  end
  return api,dirty
end

function M.handle(state,req,ctx,sender)
  local p=req.payload or {}
  local a=req.action
  local d=C.cleanDomain(p.domain)
  local site=state.sites[d]

  if a=='getPage' then
    if not site or state.moderation.suspendedSites[d] then return 404,nil,'Site not found' end
    local path=C.cleanPath(p.path or '/')
    if not path then return 400,nil,'Bad path' end
    local page=(site.published.pages or {})[path]
    if not page and path~='/' then page=(site.published.pages or {})['/404'] end
    if not page then return 404,nil,'Page not found' end

    -- Analytics are intentionally buffered in memory. A page read must NEVER
    -- force a full persistent backend save.
    stateLib.ensureSite(state,d)
    local an=state.analytics.sites[d]
    an.views=(an.views or 0)+1
    an.pages[path]=(an.pages[path] or 0)+1
    an.uniqueComputers[tostring(sender or 0)]=true

    return 200,{
      domain=d,path=path,title=site.title,page=util.deepcopy(page),
      clientScript=site.publishedClientScript or site.clientScript or '',
      settings=site.settings or {},owner=site.owner,description=site.description
    },false

  elseif a=='getAsset' then
    if not site then return 404,nil,'Site not found' end
    local name=util.safeName(p.name,48)
    local x=site.assets[name]
    if not x then return 404,nil,'Asset not found' end
    local data=stateLib.readAsset(state,d,name,x)
    if data==nil then return 404,nil,'Asset data missing' end
    return 200,{name=name,data=data,mime=x.mime},false

  elseif a=='runAction' then
    if not site or state.moderation.suspendedSites[d] then return 404,nil,'Site not found' end
    local action=util.safeName(p.event,48)
    local patches={}
    local vars={input=p.input or {},args=p.args or {},caller=ctx and ctx.user or nil,domain=d}
    local source=site.publishedServerScript or site.serverScript or ''
    local api,dirty=scriptApi(state,d,ctx and ctx.user or nil,patches)
    local result,err=script.run(source,action,{call=api,log=function() end},{vars=vars,limit=config.maxServerScriptInstructions,maxRepeat=config.maxScriptRepeat})
    if not result then return 400,nil,err end
    return 200,{result=result.result,vars=result.vars,patches=patches,steps=result.steps},dirty.value
  end

  local s,err=ownerSite(state,d,ctx)
  if not s then return 403,nil,err end

  if a=='getSite' then
    return 200,{site=util.deepcopy(s),domain=d,analytics=state.analytics.sites[d]},false

  elseif a=='savePage' then
    local path=C.cleanPath(p.path)
    if not path then return 400,nil,'Bad path' end
    if util.count(s.draft.pages)>=config.maxSitePages and s.draft.pages[path]==nil then
      return 507,nil,'Page quota reached'
    end
    local pg,e=cleanPage(p.page)
    if not pg then return 400,nil,e end
    s.draft.pages[path]=pg
    s.updated=util.now()
    return 200,{path=path},true

  elseif a=='deletePage' then
    local path=C.cleanPath(p.path)
    if not path then return 400,nil,'Bad path' end
    s.draft.pages[path]=nil
    return 200,{ok=true},true

  elseif a=='saveScripts' then
    if p.clientScript~=nil then
      if #tostring(p.clientScript)>30000 then return 507,nil,'Client script too large' end
      local parsed,e=script.parse(p.clientScript)
      if not parsed then return 400,nil,e end
      s.clientScript=tostring(p.clientScript)
    end
    if p.serverScript~=nil then
      if #tostring(p.serverScript)>30000 then return 507,nil,'Server script too large' end
      local parsed,e=script.parse(p.serverScript)
      if not parsed then return 400,nil,e end
      s.serverScript=tostring(p.serverScript)
    end
    return 200,{ok=true},true

  elseif a=='publish' then
    local rev={
      id=util.id('rev'),
      time=util.now(),
      published=util.deepcopy(s.published),
      clientScript=s.publishedClientScript or s.clientScript or '',
      serverScript=s.publishedServerScript or s.serverScript or '',
      note=C.cleanText(p.note,100)
    }
    table.insert(s.revisions,1,rev)
    while #s.revisions>config.maxRevisions do table.remove(s.revisions) end

    s.published=util.deepcopy(s.draft)
    s.publishedClientScript=s.clientScript or ''
    s.publishedServerScript=s.serverScript or ''
    s.publishedAt=util.now()
    search.indexSite(s)
    return 200,{revision=rev.id,publishedAt=s.publishedAt},true

  elseif a=='history' then
    local out={}
    for _,r in ipairs(s.revisions) do
      out[#out+1]={id=r.id,time=r.time,note=r.note}
    end
    return 200,{revisions=out},false

  elseif a=='restore' then
    for _,r in ipairs(s.revisions) do
      if r.id==p.id then
        local snap=nil
        if r.published~=nil then
          snap={published=r.published,clientScript=r.clientScript,serverScript=r.serverScript}
        else
          snap=stateLib.loadRevision(state,d,r.id,r)
        end
        if not snap then return 500,nil,'Revision snapshot missing' end
        s.draft=util.deepcopy(snap.published or {pages={}})
        s.clientScript=snap.clientScript or s.clientScript or ''
        s.serverScript=snap.serverScript or s.serverScript or ''
        return 200,{restored=r.id},true
      end
    end
    return 404,nil,'Revision not found'

  elseif a=='putAsset' then
    local name=util.safeName(p.name,48)
    if name=='' then return 400,nil,'Bad asset name' end
    if util.count(s.assets)>=config.maxAssets and not s.assets[name] then
      return 507,nil,'Asset quota reached'
    end
    local data=tostring(p.data or '')
    if #data>config.maxAssetBytes then return 507,nil,'Asset too large' end
    s.assets[name]={
      data=data,mime=C.cleanText(p.mime or 'text/plain',40),
      updated=util.now(),size=#data
    }
    return 200,{name=name,size=#data},true

  elseif a=='deleteAsset' then
    s.assets[util.safeName(p.name,48)]=nil
    return 200,{ok=true},true

  elseif a=='listAssets' then
    local out={}
    for name,x in pairs(s.assets) do
      local size=x.size
      if size==nil and x.data~=nil then size=#tostring(x.data or '') end
      out[#out+1]={name=name,mime=x.mime,size=size or 0}
    end
    table.sort(out,function(x,y)return x.name<y.name end)
    return 200,{assets=out},false

  elseif a=='settings' then
    if p.title~=nil then
      s.title=C.cleanText(p.title,48)
      state.domains[d].title=s.title
    end
    if p.description~=nil then s.description=C.cleanText(p.description,300) end
    if p.tags~=nil and type(p.tags)=='table' then
      s.tags={}
      for i=1,math.min(12,#p.tags) do
        s.tags[#s.tags+1]=C.cleanText(p.tags[i],24)
      end
    end
    s.settings=s.settings or {}
    if p.listed~=nil then s.settings.listed=p.listed and true or false end
    search.indexSite(s)
    return 200,{ok=true},true

  elseif a=='analytics' then
    local an=util.deepcopy(state.analytics.sites[d])
    an.unique=util.count(an.uniqueComputers or {})
    an.uniqueComputers=nil
    return 200,{analytics=an},false
  end

  return 404,nil,'Unknown web action'
end

return M
]==],
  ["/spawnnet/server/startup.lua"]=[==[while true do
  local ok,err=pcall(function() dofile('/spawnnet/server/server.lua') end)
  if not ok and tostring(err)=='Terminated' then error(err,0) end
  term.setTextColor(colors.red)
  print('SpawnNet core stopped: '..tostring(err))
  term.setTextColor(colors.white)
  sleep(3)
end
]==],
  ["/spawnnet/server/state.lua"]=[==[local util=dofile('/spawnnet/lib/util.lua')
local config=dofile('/spawnnet/lib/config.lua')
local M={}

local ROOT='/spawnnet/data'
local SITE_DIR=ROOT..'/sites'
local STORAGE_DIR=ROOT..'/site_storage'
local DB_DIR=ROOT..'/databases'
local MAIL_DIR=ROOT..'/mail'
local EVENT_DIR=ROOT..'/events'
local TELEMETRY_DIR=ROOT..'/telemetry'
local ANALYTICS_DIR=ROOT..'/analytics'
local JOB_DIR=ROOT..'/jobs'
local REV_DIR=ROOT..'/revisions'
local ASSET_DIR=ROOT..'/assets'
local APP_PACKAGE_DIR=ROOT..'/app_packages'
local keyName,saveSerialized,loadSerialized,deleteTree

local function blank()
  return {
    meta={version=config.version,created=util.now(),nextIds={mail=1,thread=1,reply=1,report=1}},
    accounts={},sessions={},challenges={},apiKeys={},apiChallenges={},registrationChallenges={},registrationTickets={},domains={},sites={},mail={},siteStorage={},databases={},events={},
    forums={general={title='General',threads={}}},chats={global={messages={}}},
    telemetry={},packages={},appPackages={},packageRevocations={},moderation={reports={},suspendedUsers={},suspendedSites={}},analytics={sites={}},jobs={},nodes={},pendingNodes={},objects={},blobs={},
  }
end

local function ensureDirs()
  util.ensureDir(ROOT)
  util.ensureDir(SITE_DIR)
  util.ensureDir(STORAGE_DIR)
  util.ensureDir(DB_DIR)
  util.ensureDir(MAIL_DIR)
  util.ensureDir(EVENT_DIR)
  util.ensureDir(TELEMETRY_DIR)
  util.ensureDir(ANALYTICS_DIR)
  util.ensureDir(JOB_DIR)
  util.ensureDir(REV_DIR)
  util.ensureDir(ASSET_DIR)
  util.ensureDir(APP_PACKAGE_DIR)
end

local function saveAppPackages(map)
  util.ensureDir(APP_PACKAGE_DIR);local wantedDomains={}
  for domain,bucket in pairs(map or{})do
    local dn=keyName(domain);wantedDomains[dn]=true;local dir=APP_PACKAGE_DIR..'/'..dn;util.ensureDir(dir);local wanted={}
    for name,pkg in pairs(bucket or{})do local fn=keyName(name)..'.pkg';wanted[fn]=true;saveSerialized(dir..'/'..fn,pkg)end
    for _,fn in ipairs(fs.list(dir))do if not wanted[fn]then deleteTree(dir..'/'..fn)end end
  end
  for _,dn in ipairs(fs.list(APP_PACKAGE_DIR))do if not wantedDomains[dn]then deleteTree(APP_PACKAGE_DIR..'/'..dn)end end
end
local function loadAppPackages()
  local out={};if not fs.exists(APP_PACKAGE_DIR)then return out end
  for _,domain in ipairs(fs.list(APP_PACKAGE_DIR))do local dir=APP_PACKAGE_DIR..'/'..domain;if fs.isDir(dir)then out[domain]={};for _,fn in ipairs(fs.list(dir))do if fn:sub(-4)=='.pkg'then local pkg=loadSerialized(dir..'/'..fn,nil);if type(pkg)=='table'and pkg.name then out[domain][pkg.name]=pkg end end end end end
  return out
end

keyName=function(k)
  return tostring(k or ''):gsub('[^%w_%-]','_')
end

local function pathKey(path)
  local out={}
  path=tostring(path or '/')
  for i=1,#path do out[#out+1]=string.format('%02x',path:byte(i)) end
  if #out==0 then return 'root' end
  return table.concat(out)
end

local function siteRoot(domain)
  return SITE_DIR..'/'..keyName(domain)
end

local function pagePath(domain,kind,path)
  return siteRoot(domain)..'/'..kind..'/'..pathKey(path)..'.db'
end

local function assetPath(domain,name)
  return ASSET_DIR..'/'..keyName(domain)..'/'..keyName(name)..'.dat'
end

local function revisionPath(domain,id)
  return REV_DIR..'/'..keyName(domain)..'/'..keyName(id)..'.db'
end

saveSerialized=function(path,value)
  return util.writeIfChanged(path,textutils.serialize(value))
end

loadSerialized=function(path,default)
  return util.loadTable(path,default)
end

deleteTree=function(path)
  if fs.exists(path) then fs.delete(path) end
end

local function saveSimpleMap(dir,map)
  util.ensureDir(dir)
  local wanted={}
  for key,value in pairs(map or {}) do
    local name=keyName(key)..'.db'
    wanted[name]=true
    saveSerialized(dir..'/'..name,value)
  end
  for _,name in ipairs(fs.list(dir)) do
    local p=dir..'/'..name
    if not wanted[name] then deleteTree(p) end
  end
end

local function loadSimpleMap(dir)
  local out={}
  if not fs.exists(dir) then return out end
  for _,name in ipairs(fs.list(dir)) do
    local p=dir..'/'..name
    if not fs.isDir(p) and name:sub(-3)=='.db' then
      local key=name:sub(1,-4)
      local value=loadSerialized(p,nil)
      if type(value)=='table' then out[key]=value end
    end
  end
  return out
end

local function cleanPageDir(domain,kind,pages)
  local dir=siteRoot(domain)..'/'..kind
  util.ensureDir(dir)
  local wanted={}
  for path,page in pairs(pages or {}) do
    local name=pathKey(path)..'.db'
    wanted[name]=true
    saveSerialized(dir..'/'..name,page)
  end
  for _,name in ipairs(fs.list(dir)) do
    if not wanted[name] then deleteTree(dir..'/'..name) end
  end
end

local function saveAssets(state,domain,site)
  local dir=ASSET_DIR..'/'..keyName(domain)
  util.ensureDir(dir)
  local wanted={}
  for name,a in pairs(site.assets or {}) do
    local filename=keyName(name)..'.dat'
    wanted[filename]=true
    if type(a)=='table' then
      local data=a.data
      if data==nil and not a.objectId and fs.exists(dir..'/'..filename) then data=util.readFile(dir..'/'..filename) end
      if data~=nil then
        data=tostring(data or '')
        a.size=#data
        local cluster=_G.spawnnetCluster
        local remote=false
        if cluster and #data>=(config.remoteAssetThreshold or 4096) then
          local id=cluster.store(state,'asset:'..domain..':'..name,data,{replicas=config.objectReplicas or 2,keepLocal=false})
          if id then a.objectId=id; remote=true end
        end
        if remote then
          if fs.exists(dir..'/'..filename) then fs.delete(dir..'/'..filename) end
        else
          util.writeIfChanged(dir..'/'..filename,data)
          a.objectId=nil
        end
        a.data=nil
      end
    end
  end
  for _,filename in ipairs(fs.list(dir)) do
    if not wanted[filename] then deleteTree(dir..'/'..filename) end
  end
end

local function saveRevisions(state,domain,site)
  local dir=REV_DIR..'/'..keyName(domain)
  util.ensureDir(dir)
  local wanted={}
  for _,r in ipairs(site.revisions or {}) do
    if r.id then
      local name=keyName(r.id)..'.db'
      wanted[name]=true
      if r.published~=nil or r.clientScript~=nil or r.serverScript~=nil then
        local snapshot={published=r.published or {pages={}},clientScript=r.clientScript or '',serverScript=r.serverScript or ''}
        local raw=textutils.serialize(snapshot)
        local remote=false
        local cluster=_G.spawnnetCluster
        if cluster and #raw>=(config.remoteAssetThreshold or 4096) then
          local id=cluster.store(state,'revision:'..domain..':'..r.id,raw,{replicas=config.objectReplicas or 2,keepLocal=false})
          if id then r.objectId=id;remote=true end
        end
        if remote then
          if fs.exists(dir..'/'..name) then fs.delete(dir..'/'..name) end
          r.file=nil
        else
          saveSerialized(dir..'/'..name,snapshot);r.objectId=nil;r.file=name
        end
        r.published=nil;r.clientScript=nil;r.serverScript=nil
      end
    end
  end
  for _,name in ipairs(fs.list(dir)) do
    if not wanted[name] then deleteTree(dir..'/'..name) end
  end
end

local function saveSite(state,domain,site)
  local dir=siteRoot(domain)
  util.ensureDir(dir)

  site.draft=site.draft or {pages={}}
  site.published=site.published or {pages={}}
  site.draft.pages=site.draft.pages or {}
  site.published.pages=site.published.pages or {}
  site.assets=site.assets or {}
  site.revisions=site.revisions or {}

  cleanPageDir(domain,'draft',site.draft.pages)
  cleanPageDir(domain,'published',site.published.pages)
  saveAssets(state,domain,site)
  saveRevisions(state,domain,site)

  local meta=util.deepcopy(site)
  meta.draft.pages={}
  for path in pairs(site.draft.pages) do meta.draft.pages[path]=true end
  meta.published.pages={}
  for path in pairs(site.published.pages) do meta.published.pages[path]=true end
  for _,a in pairs(meta.assets or {}) do if type(a)=='table' then a.data=nil end end
  for _,r in ipairs(meta.revisions or {}) do
    if type(r)=='table' then
      r.published=nil
      r.clientScript=nil
      r.serverScript=nil
    end
  end
  saveSerialized(dir..'/site.db',meta)
end

local function loadSite(domain,meta)
  if type(meta)~='table' then return nil end
  meta.draft=meta.draft or {pages={}}
  meta.published=meta.published or {pages={}}
  local draftIndex=meta.draft.pages or {}
  local pubIndex=meta.published.pages or {}
  meta.draft.pages={}
  meta.published.pages={}

  for path in pairs(draftIndex) do
    local pg=loadSerialized(pagePath(domain,'draft',path),nil)
    if type(pg)=='table' then meta.draft.pages[path]=pg end
  end
  for path in pairs(pubIndex) do
    local pg=loadSerialized(pagePath(domain,'published',path),nil)
    if type(pg)=='table' then meta.published.pages[path]=pg end
  end
  return meta
end

local function loadSites()
  local out={}
  if not fs.exists(SITE_DIR) then return out end
  for _,domain in ipairs(fs.list(SITE_DIR)) do
    local dir=SITE_DIR..'/'..domain
    if fs.isDir(dir) then
      local meta=loadSerialized(dir..'/site.db',nil)
      local site=loadSite(domain,meta)
      if site then out[domain]=site end
    end
  end
  return out
end

local function saveSites(state)
  local sites=state.sites
  util.ensureDir(SITE_DIR)
  local wanted={}
  for domain,site in pairs(sites or {}) do
    local key=keyName(domain)
    wanted[key]=true
    saveSite(state,domain,site)
  end
  for _,name in ipairs(fs.list(SITE_DIR)) do
    if not wanted[name] then
      deleteTree(SITE_DIR..'/'..name)
      deleteTree(ASSET_DIR..'/'..name)
      deleteTree(REV_DIR..'/'..name)
    end
  end
end

function M.loadRevision(state,domain,id,revision)
  if revision and revision.objectId and _G.spawnnetCluster then
    local raw=_G.spawnnetCluster.get(state,revision.objectId)
    if raw then local ok,v=pcall(textutils.unserialize,raw);if ok and type(v)=='table'then return v end end
  end
  return loadSerialized(revisionPath(domain,id),nil)
end

function M.readAsset(state,domain,name,asset)
  if type(asset)=='table' and asset.data~=nil then return tostring(asset.data or '') end
  local path=assetPath(domain,name)
  if fs.exists(path) then return util.readFile(path) end
  if type(asset)=='table' and asset.objectId and _G.spawnnetCluster then
    return _G.spawnnetCluster.get(state,asset.objectId)
  end
  return nil
end

function M.load(path)
  ensureDirs()
  path=path or config.dataFile
  local state=util.loadTable(path,blank())
  local defaults=blank()
  for k,v in pairs(defaults) do if state[k]==nil then state[k]=v end end
  if not state.meta.nextIds then state.meta.nextIds=defaults.meta.nextIds end
  for k,v in pairs(defaults.meta.nextIds) do
    if state.meta.nextIds[k]==nil then state.meta.nextIds[k]=v end
  end

  -- Load partitioned data, while retaining legacy inline values until the
  -- first 1.1 save migrates them.
  local diskSites=loadSites()
  for d,s in pairs(diskSites) do state.sites[d]=s end

  for _,s in pairs(state.sites or {}) do
    s.draft=s.draft or {pages={}}
    s.published=s.published or {pages={}}
    s.draft.pages=s.draft.pages or {}
    s.published.pages=s.published.pages or {}
    s.assets=s.assets or {}
    s.revisions=s.revisions or {}
    s.settings=s.settings or {listed=true}
    if s.publishedClientScript==nil then s.publishedClientScript=s.clientScript or '' end
    if s.publishedServerScript==nil then s.publishedServerScript=s.serverScript or '' end
    if s.clientScript==nil then s.clientScript=s.publishedClientScript or '' end
    if s.serverScript==nil then s.serverScript=s.publishedServerScript or '' end
  end

  local function mergeMap(dst,src)
    for k,v in pairs(src or {}) do dst[k]=v end
  end
  mergeMap(state.siteStorage,loadSimpleMap(STORAGE_DIR))
  mergeMap(state.databases,loadSimpleMap(DB_DIR))
  mergeMap(state.mail,loadSimpleMap(MAIL_DIR))
  mergeMap(state.events,loadSimpleMap(EVENT_DIR))
  mergeMap(state.telemetry,loadSimpleMap(TELEMETRY_DIR))
  state.analytics=state.analytics or {sites={}}
  state.analytics.sites=state.analytics.sites or {}
  mergeMap(state.analytics.sites,loadSimpleMap(ANALYTICS_DIR))
  mergeMap(state.jobs,loadSimpleMap(JOB_DIR))
  mergeMap(state.appPackages,loadAppPackages())

  -- SpawnNet 2 removes the built-in economy applications. Legacy records are
  -- deliberately discarded; player websites can implement their own markets.
  state.listings=nil; state.orders=nil; state.auctions=nil; state.ledger=nil
  if state.sites.market and state.sites.market.title=='SpawnNet Market' then state.sites.market=nil; state.domains.market=nil end

  -- Never keep package payloads in the main state DB.
  for name,pkg in pairs(state.packages or {}) do
    if type(pkg)=='table' and type(pkg.files)=='table' then
      if name=='client' then
        pkg.fileCount=util.count(pkg.files)
        pkg.files=nil
        pkg.source='builtin'
      else
        util.ensureDir('/spawnnet/packages')
        local p='/spawnnet/packages/'..keyName(name)..'.pkg'
        util.saveTable(p,pkg.files)
        pkg.fileCount=util.count(pkg.files)
        pkg.files=nil
        pkg.filePath=p
        pkg.source='file'
      end
    end
  end

  state.sessions={}
  state.challenges={}
  state.apiChallenges={}
  state.registrationChallenges={}
  state.pendingNodes={}
  for _,n in pairs(state.nodes or {}) do n.lastSeenClock=nil end
  return state
end

function M.save(state,path)
  ensureDirs()
  path=path or config.dataFile
  if fs.exists(path)and(os.clock()-(M._lastBackup or-9999)>300)then
    util.ensureDir('/spawnnet/backups');for i=3,2,-1 do local older='/spawnnet/backups/state-'..tostring(i-1)..'.db';local newer='/spawnnet/backups/state-'..tostring(i)..'.db';if fs.exists(newer)then fs.delete(newer)end;if fs.exists(older)then fs.copy(older,newer)end end
    local first='/spawnnet/backups/state-1.db';if fs.exists(first)then fs.delete(first)end;fs.copy(path,first);M._lastBackup=os.clock()
  end
  state.meta.version=config.version
  state.meta.saved=util.now()

  -- Persist large/high-growth namespaces independently.
  saveSites(state)
  saveSimpleMap(STORAGE_DIR,state.siteStorage)
  saveSimpleMap(DB_DIR,state.databases)
  saveSimpleMap(MAIL_DIR,state.mail)
  saveSimpleMap(EVENT_DIR,state.events)
  saveSimpleMap(TELEMETRY_DIR,state.telemetry)
  saveSimpleMap(ANALYTICS_DIR,(state.analytics or {}).sites or {})
  saveSimpleMap(JOB_DIR,state.jobs or {})
  saveAppPackages(state.appPackages or{})

  local persisted=util.shallowcopy(state)
  persisted.sessions={}
  persisted.challenges={}
  persisted.apiChallenges={}
  persisted.registrationChallenges={}
  persisted.sites={}
  persisted.siteStorage={}
  persisted.databases={}
  persisted.mail={}
  persisted.events={}
  persisted.telemetry={}
  persisted.analytics={sites={}}
  persisted.jobs={}
  persisted.appPackages={}

  persisted.packages={}
  for name,pkg in pairs(state.packages or {}) do
    local p=util.shallowcopy(pkg)
    p.files=nil
    persisted.packages[name]=p
  end

  util.saveTable(path,persisted)
end

function M.nextId(state,kind,prefix)
  local n=state.meta.nextIds[kind] or 1
  state.meta.nextIds[kind]=n+1
  return (prefix or kind)..'-'..tostring(n)
end

function M.ensureUser(state,user)
  state.mail[user]=state.mail[user] or {}
  state.events[user]=state.events[user] or {}
end

function M.ensureSite(state,user)
  state.siteStorage[user]=state.siteStorage[user] or {}
  state.databases[user]=state.databases[user] or {}
  state.analytics=state.analytics or {sites={}}
  state.analytics.sites=state.analytics.sites or {}
  state.analytics.sites[user]=state.analytics.sites[user] or {views=0,uniqueComputers={},pages={}}
end

function M.seedSystem(state,adminUser)
  if state.sites.home then return false end
  local function site(owner,domain,title,body)
    state.domains[domain]={owner=owner,created=util.now(),title=title}
    state.sites[domain]={
      owner=owner,title=title,description=body,tags={'spawnnet','system'},
      draft={pages={}},published={pages={}},revisions={},assets={},
      clientScript='',serverScript='',publishedClientScript='',publishedServerScript='',
      settings={listed=true}
    }
    local page={title=title,background=colors and colors.black or 32768,elements={
      {type='heading',id='title',x=2,y=2,w=47,h=1,text=title,fg=colors and colors.yellow or 16,bg=colors and colors.black or 32768,align='center'},
      {type='text',id='body',x=3,y=5,w=45,h=4,text=body,fg=colors and colors.white or 1,bg=colors and colors.black or 32768},
      {type='button',id='search',x=3,y=11,w=14,h=1,text='Search',action={type='navigate',target='spn://search'}},
      {type='button',id='docs',x=19,y=11,w=14,h=1,text='Docs',action={type='navigate',target='spn://docs'}},
      {type='button',id='labs',x=35,y=11,w=14,h=1,text='Wiki',action={type='navigate',target='spn://wiki'}},
    }}
    state.sites[domain].published.pages['/']=page
    state.sites[domain].draft=util.deepcopy(state.sites[domain].published)
    M.ensureSite(state,domain)
  end
  site(adminUser or 'system','home','SpawnNet','A programmable network platform: websites, apps, mail, machine jobs, telemetry, private networks and distributed storage.')
  site(adminUser or 'system','docs','SpawnNet Docs','Use the browser address bar, or run spawnnet studio to create and publish your own site.')
  site(adminUser or 'system','search','SpawnNet Search','Use the browser search command or the Search button in the browser toolbar.')
  return true
end

function M.stats(state)
  local function count(t) local n=0 for _ in pairs(t or {}) do n=n+1 end return n end
  local size=fs.exists(config.dataFile) and fs.getSize(config.dataFile) or 0
  local ok,free=pcall(fs.getFreeSpace,config.dataFile)
  return {
    stateBytes=size,
    free=ok and free or '?',
    sites=count(state.sites),
    accounts=count(state.accounts)
  }
end

return M
]==],
  ["/spawnnet/server/status.lua"]=[==[local config=dofile('/spawnnet/lib/config.lua')
local util=dofile('/spawnnet/lib/util.lua')
local stateLib=dofile('/spawnnet/server/state.lua')
local state=stateLib.load(config.dataFile)
local cfg=util.loadTable(config.serverConfig,{networkId='public',networkName='Public SpawnNet'})
local function c(t)local n=0;for _ in pairs(t or{})do n=n+1 end;return n end
local jobs=0;for _,b in pairs(state.jobs or{})do jobs=jobs+c(b)end
local objects=c(state.objects)
local approved=c(state.nodes);local pending=c(state.pendingNodes)
term.clear();term.setCursorPos(1,1)
print('SPAWNNET OPERATIONS '..config.version)
print('Network: '..tostring(cfg.networkName)..' ['..tostring(cfg.networkId)..']')
print(('Core ID: %-8d ONLINE'):format(os.getComputerID()))
print('-----------------------------------')
print('Users:       '..c(state.accounts))
print('Domains:     '..c(state.domains))
print('Sites:       '..c(state.sites))
print('Jobs:        '..jobs)
print('Nodes:       '..approved..' approved / '..pending..' pending')
print('Objects:     '..objects)
local mails=0;for _,x in pairs(state.mail or{})do mails=mails+#x end;print('Mail:        '..mails)
local events=0;for _,x in pairs(state.events or{})do events=events+#x end;print('Queued evts: '..events)
local size=fs.exists(config.dataFile)and fs.getSize(config.dataFile)or 0;local ok,free=pcall(fs.getFreeSpace,config.dataFile);print('State DB:    '..size..' bytes');print('Disk free:   '..tostring(ok and free or'?'));print('Saved:       '..tostring(state.meta.saved or'never'))
]==],
  ["/spawnnet/tools/admin.lua"]=[==[local net=dofile('/spawnnet/client/net.lua');local auth=dofile('/spawnnet/client/auth_client.lua');local ui=dofile('/spawnnet/client/ui.lua')
if not net.loadSession()then local s,e=auth.ensureLogin();if not s then ui.error(e)return end end
while true do
 local _,m=ui.menu('SPAWNNET // COMMAND',{{label='Storage node matrix'},{label='Create secure enrollment code'},{label='Enrollment history'},{label='Revoke package hash'},{label='Package revocations'},{label='Suspend/unsuspend site'},{label='Suspend/unsuspend user'},{label='Grant role'},{label='Revoke role'},{label='Security log'},{label='Reports'},{label='Back'}})
 if m.label=='Back'then break
 elseif m.label=='Storage node matrix'then shell.run('/spawnnet/client/nodes.lua')
 elseif m.label=='Create secure enrollment code'then local p,e=net.call('moderation','createEnrollment',{});ui.clear('SECURE ENROLLMENT');if p then print('ONE-TIME CODE');print();print(p.code);print();print('Valid for 15 minutes. Send it outside Rednet.')else ui.error(e)end;ui.pause()
 elseif m.label=='Enrollment history'then local p,e=net.call('moderation','enrollments',{});ui.clear('ENROLLMENT HISTORY');if p then for _,t in ipairs(p.tickets or{})do print(t.id..'  '..(t.used and('USED '..tostring(t.usedBy))or'AVAILABLE'))end else ui.error(e)end;ui.pause()
 elseif m.label=='Revoke package hash'then local hash=ui.prompt('Full SHA-256 hash','');local reason=ui.prompt('Reason','Administrator revocation');local p,e=net.call('moderation','revokePackage',{hash=hash,reason=reason});if not p then ui.error(e)end
 elseif m.label=='Package revocations'then local p,e=net.call('moderation','packageRevocations',{});ui.clear('PACKAGE KILL SWITCH');if p then for _,r in ipairs(p.revocations or{})do print(tostring(r.hash):sub(1,16)..'  '..tostring(r.reason));print('  by '..tostring(r.by))end else ui.error(e)end;ui.pause()
 elseif m.label=='Suspend/unsuspend site'then local d=ui.prompt('Domain','');local s=ui.prompt('Suspend? y/n','y')~='n';local p,e=net.call('moderation','suspendSite',{domain=d,suspended=s});if not p then ui.error(e)end
 elseif m.label=='Suspend/unsuspend user'then local u=ui.prompt('User','');local s=ui.prompt('Suspend? y/n','y')~='n';local p,e=net.call('moderation','suspendUser',{user=u,suspended=s});if not p then ui.error(e)end
 elseif m.label=='Grant role'then local u=ui.prompt('User','');local r=ui.prompt('Role','admin');local p,e=net.call('moderation','grantRole',{user=u,role=r});if not p then ui.error(e)end
 elseif m.label=='Revoke role'then local u=ui.prompt('User','');local r=ui.prompt('Role','admin');local p,e=net.call('moderation','revokeRole',{user=u,role=r});if not p then ui.error(e)end
 elseif m.label=='Security log'then local p,e=net.call('moderation','securityLog',{});ui.clear('SECURITY LOG');if p then print(p.log~=''and p.log or'No security events recorded.')else ui.error(e)end;ui.pause()
 elseif m.label=='Reports'then local p,e=net.call('moderation','reports',{});ui.clear('REPORTS');if p then for _,r in ipairs(p.reports)do print(r.id..' '..r.targetType..':'..r.target..' by '..r.reporter);print('  '..r.reason)end else ui.error(e)end;ui.pause()end
end
]==],
  ["/spawnnet/tools/publish_package.lua"]=[==[local net=dofile('/spawnnet/client/net.lua')
local auth=dofile('/spawnnet/client/auth_client.lua')
local util=dofile('/spawnnet/lib/util.lua')
local args={...};local root=args[1]or'/spawnnet';local name=args[2]or'client';local version=args[3]or'1.0.0'
if not net.loadSession()then local s,e=auth.ensureLogin();if not s then printError(e)return end end
local files={}
local function walk(path,rel)
  for _,n in ipairs(fs.list(path))do local p=fs.combine(path,n);local r=rel==''and n or(rel..'/'..n);if fs.isDir(p)then if not r:match('^data')and not r:match('^log')and not r:match('^tmp')then walk(p,r)end else files['spawnnet/'..r]=util.readFile(p)end end
end
walk(root,'')
local p,e=net.call('package','publish',{name=name,version=version,description='SpawnNet package '..name,files=files});if not p then printError(e)else print('Published '..name..' '..version..' with '..tostring(#(function()local t={}for k in pairs(files)do t[#t+1]=k end return t end)())..' files')end
]==],
  ["/spawnnet/tools/rednet_repeater.lua"]=[==[-- SpawnNet-compatible Rednet repeater for ComputerCraft/CC:Tweaked 1.12.2.
-- Place this on a computer which remains loaded. It repeats every Rednet protocol,
-- not just SpawnNet, while deduplicating message IDs.
local requested=(...)
local modems={}
for _,n in ipairs(peripheral.getNames())do if peripheral.getType(n)=='modem' and (not requested or requested==n)then modems[#modems+1]=n end end
if #modems==0 then error('No modem found')end
for _,m in ipairs(modems)do peripheral.call(m,'open',rednet.CHANNEL_REPEAT)end
local seen={};local timers={};local count=0
print('Rednet repeater online ('..#modems..' modem(s))')
while true do
  local ev={os.pullEvent()}
  if ev[1]=='modem_message' then
    local side,channel,reply,msg=ev[2],ev[3],ev[4],ev[5]
    if channel==rednet.CHANNEL_REPEAT and type(msg)=='table' and msg.nMessageID and type(msg.nRecipient)=='number' and not seen[msg.nMessageID] then
      seen[msg.nMessageID]=true;timers[os.startTimer(30)]=msg.nMessageID
      local dest=msg.nRecipient;if dest~=rednet.CHANNEL_BROADCAST then dest=dest%rednet.MAX_ID_CHANNELS end
      for _,m in ipairs(modems)do peripheral.call(m,'transmit',rednet.CHANNEL_REPEAT,reply,msg);peripheral.call(m,'transmit',dest,reply,msg)end
      count=count+1;term.setCursorPos(1,2);term.clearLine();write(count..' messages repeated')
    end
  elseif ev[1]=='timer' then local id=timers[ev[2]];if id then timers[ev[2]]=nil;seen[id]=nil end end
end
]==],
  ["/spawnnet/tools/ws_gateway.lua"]=[==[-- Optional SpawnNet 2 WebSocket gateway.
-- /spawnnet/ws_gateway.cfg: {url='ws://host:8765',networkId='public',coreId=123,modem='top'}
local config=dofile('/spawnnet/lib/config.lua');local util=dofile('/spawnnet/lib/util.lua');local wire=dofile('/spawnnet/lib/wire.lua')
local cfg=util.loadTable('/spawnnet/ws_gateway.cfg',{url='ws://127.0.0.1:8765',networkId='public',coreId=nil,modem=nil})
cfg.networkId=util.safeName(cfg.networkId or'public',32);local protocol=config.protocolPrefix..cfg.networkId..':v2'
local function findModem()if cfg.modem and peripheral.isPresent(cfg.modem)then return cfg.modem end;for _,n in ipairs(peripheral.getNames())do if peripheral.getType(n)=='modem'then return n end end end
local modem=findModem();if not modem then error('No modem')end;if not rednet.isOpen(modem)then rednet.open(modem)end
local function discover()
 local nonce=util.id('gw');rednet.broadcast({network='spawnnet',version=2,type='discover',nonce=nonce},config.discoveryProtocol);local timer=os.startTimer(1.5)
 while true do local ev={os.pullEvent()};if ev[1]=='timer'and ev[2]==timer then return nil end;if ev[1]=='rednet_message'then local sender,msg,proto=ev[2],ev[3],ev[4];if proto==config.discoveryProtocol and type(msg)=='table'and msg.type=='advertise'and msg.nonce==nonce and msg.networkId==cfg.networkId then return sender end end end
end
local core=cfg.coreId or discover();if not core then error('Core not found for network '..cfg.networkId)end;cfg.coreId=core;cfg.modem=modem;util.saveTable('/spawnnet/ws_gateway.cfg',cfg)
local ws,err=http.websocket(cfg.url);if not ws then error('WebSocket failed: '..tostring(err))end;ws.send(textutils.serializeJSON({type='register',id=tostring(os.getComputerID())}))
local pending={};local fragments={};print('SpawnNet 2 WS gateway #'..os.getComputerID()..' ['..cfg.networkId..'] -> core #'..core)
local function fromWeb()while true do local raw=ws.receive();if not raw then error('WebSocket closed')end;local m=textutils.unserializeJSON(raw);if type(m)=='table'and m.type=='message'and m.protocol==protocol and m.body then local req=textutils.unserialize(m.body);if type(req)=='table'and req.requestId then pending[req.requestId]=tostring(m.from);wire.send(core,req,protocol)end end end end
local function fromCore()while true do local sender,msg,proto=rednet.receive(protocol);if sender==core and proto==protocol then local full=wire.accept(sender,msg,fragments);wire.purge(fragments);msg=full;if type(msg)=='table'and msg.type=='response'and pending[msg.requestId]then local target=pending[msg.requestId];pending[msg.requestId]=nil;ws.send(textutils.serializeJSON({type='message',to=target,protocol=protocol,body=textutils.serialize(msg)}))end end end end
parallel.waitForAny(fromWeb,fromCore)
]==],
  ["/studio.lua"]=[==[shell.run('/spawnnet/client/studio_easy.lua')
]==],
  ["/web.lua"]=[==[local a={...};shell.run('/spawnnet/client/browser.lua',a[1]or'spn://home')
]==],
}
local nodeReleaseFiles={
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

term.setBackgroundColor(colors.black);term.clear();term.setCursorPos(1,1);term.setBackgroundColor(colors.purple);term.setTextColor(colors.white);term.clearLine();print(' SN// CORE CITADEL INSTALLER 2.3.0 ');term.setBackgroundColor(colors.black);term.setTextColor(colors.white)
local upgrading=fs.exists('/spawnnet/server/server.lua');print(upgrading and'IN-PLACE UPGRADE // DATA PRESERVED'or'FRESH CORE // INITIALIZING REALM');print('Validating embedded systems...');print('Validated '..validate(files,'Core')..' Core/Client and '..validate(nodeReleaseFiles,'Node')..' Lua programs.')
local backup=install(files,'core')
local util=dofile('/spawnnet/lib/util.lua');local config=dofile('/spawnnet/lib/config.lua');local crypto=dofile('/spawnnet/lib/crypto.lua');local stateLib=dofile('/spawnnet/server/state.lua')
local defaults={modem=nil,networkId='public',networkName='Public SpawnNet',visibility='public',joinHash='',adminUser=nil,log='/spawnnet/log/server.log',registrationMode='ticket'}
local serverCfg=util.loadTable(config.serverConfig,defaults);for k,v in pairs(defaults)do if serverCfg[k]==nil then serverCfg[k]=v end end;serverCfg.coreIdentity=serverCfg.coreIdentity or crypto.randomHex(32)
local state=stateLib.load(config.dataFile);local function role(acc,r)for _,x in ipairs((acc and acc.roles)or{})do if x==r then return true end end end
local admin=nil;if serverCfg.adminUser and role(state.accounts[serverCfg.adminUser],'admin')then admin=serverCfg.adminUser else for u,a in pairs(state.accounts or{})do if role(a,'admin')then admin=u;break end end end
if count(state.accounts)==0 then print();term.setTextColor(colors.cyan);print('IDENTITY FORGE');term.setTextColor(colors.white);write('Admin username: ');local u=util.safeName(read(),24);write('Admin password (8+ chars): ');local pw=read('*');if #u<3 or #pw<8 then error('Admin username or password too short',0)end;local salt=crypto.randomHex(16);state.accounts[u]={username=u,verifier=crypto.passwordVerifier(u,pw,salt,config.passwordRounds),salt=salt,kdfRounds=config.passwordRounds,passwordScheme='iterated-sha256-v1',created=util.now(),roles={'admin'},profile={displayName=u,bio=''}};stateLib.ensureUser(state,u);admin=u
elseif not admin then error('Existing installation has no administrator. Restore an administrator before upgrading.',0)end
if not upgrading then print();term.setTextColor(colors.cyan);print('REALM CONFIGURATION');term.setTextColor(colors.white);write('Network ID [public]: ');local n=util.safeName(read(),32);serverCfg.networkId=n~=''and n or'public';write('Network name [Public SpawnNet]: ');local nn=read();serverCfg.networkName=nn~=''and nn or'Public SpawnNet';write('Visibility public/private [private]: ');local vis=read():lower();serverCfg.visibility=vis=='public'and'public'or'private';if serverCfg.visibility=='private'then write('Private join code (8+ chars): ');local code=read('*');if #code<8 then error('Private join code must be at least 8 characters',0)end;serverCfg.joinHash=crypto.sha256(code)else serverCfg.joinHash=''end end
local mods={};for _,n in ipairs(peripheral.getNames())do if peripheral.getType(n)=='modem'then mods[#mods+1]=n end end;if not(serverCfg.modem and peripheral.isPresent(serverCfg.modem)and peripheral.getType(serverCfg.modem)=='modem')then local d=mods[1]or'';write('Core modem ['..d..']: ');local m=read();serverCfg.modem=m~=''and m or d;if serverCfg.modem==''then error('A modem is required',0)end end
serverCfg.adminUser=admin;serverCfg.registrationMode=serverCfg.registrationMode or'ticket';serverCfg.protocol=config.protocolPrefix..serverCfg.networkId..':v2';serverCfg.backboneProtocol=config.backbonePrefix..serverCfg.networkId..':v2';util.saveTable(config.serverConfig,serverCfg)
state.meta=state.meta or{};state.meta.networkId=serverCfg.networkId;state.meta.networkName=serverCfg.networkName;stateLib.seedSystem(state,admin)
local function systemHash(pkg)local ps={};for p in pairs(pkg.files)do ps[#ps+1]=p end;table.sort(ps);local q={pkg.name,pkg.version,pkg.component,pkg.channel,tostring(pkg.restartRequired and true or false)};for _,p in ipairs(ps)do q[#q+1]='file:'..p..':'..crypto.sha256(pkg.files[p])end;local ms={};for _,p in ipairs(pkg.managedFiles or{})do ms[#ms+1]=p end;table.sort(ms);for _,p in ipairs(ms)do q[#q+1]='managed:'..p end;return crypto.sha256(table.concat(q,'\0'))end
local function publish(name,component,description,map,restart)local rf,total,managed={},0,{};for p,d in pairs(map)do local r=p:gsub('^/','');rf[r]=d;total=total+#d;managed[#managed+1]=r end;table.sort(managed);local pkg={name=name,version=VERSION,description=description,files=rf,managedFiles=managed,totalBytes=total,owner=admin,component=component,channel='stable',restartRequired=restart and true or false,published=util.now(),updated=util.now()};pkg.hash=systemHash(pkg);ensure('/spawnnet/releases');writeFile('/spawnnet/releases/'..name..'.pkg',textutils.serialize(pkg));state.packages=state.packages or{};state.packages[name]={version=VERSION,description=description,owner=admin,published=pkg.published,hash=pkg.hash,component=component,channel='stable'}end
local clientFiles={};for p,d in pairs(files)do local r=p:gsub('^/','');if r:sub(1,16)=='spawnnet/client/'or r:sub(1,13)=='spawnnet/lib/'or r=='spawnnet.lua'or r=='web.lua'or r=='studio.lua'or r=='spawnnet-packages.lua'or r=='spawnnet-release.lua'then clientFiles[p]=d end end
publish('client','client','Official SpawnNet 2.3.0 client',clientFiles,false);publish('node','node','Official SpawnNet 2.3.0 storage node',nodeReleaseFiles,true);stateLib.save(state,config.dataFile);ensure('/spawnnet/version');writeFile('/spawnnet/version/core-release.txt',VERSION..'\n')
startup('/startup.lua',"shell.run('/spawnnet/server/startup.lua')",'SPAWNNET_CORE_STARTUP_2.3.0')
for _,p in ipairs({'/spawnnet/client/warehouse_agent.lua','/spawnnet/machines/warehouse.cfg'})do if fs.exists(p)then pcall(fs.delete,p)end end
print();term.setTextColor(colors.lime);print('CORE CITADEL ONLINE // '..VERSION);term.setTextColor(colors.lightGray);print('Data preserved. Backup: '..backup);print('Registration: one-time admin enrollment codes');print('Start now: spawnnet-server   Admin: spawnnet-admin');print('Client and Node releases were published to this Core.')
