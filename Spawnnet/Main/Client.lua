-- SpawnNet 2.2.1 COMPLETE CLIENT
-- Fresh install OR in-place upgrade. No hotfix chain required.
-- Preserves network configuration, sessions, installed apps and app data on upgrade.
local files={
  ["/spawnnet/client/account.lua"]=[=[local gui=dofile('/spawnnet/client/gui.lua')
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
  local pw=gui.prompt('CREATE ACCOUNT','Choose a password:','','*');if pw==''then return end
  local pw2=gui.prompt('CREATE ACCOUNT','Confirm password:','','*');if pw~=pw2 then gui.toast('Passwords do not match.',2,false);return end
  local s,e=auth.register(u,pw,display);if s then gui.clear();gui.bar('ACCOUNT CREATED');gui.text(3,5,45,'Welcome to SpawnNet, '..tostring(s.user)..'.',C.lime,C.black);gui.text(3,7,45,'You are already signed in on this network.',C.white,C.black);gui.status('Press any key');os.pullEvent('key')else gui.toast(tostring(e),2,false)end
end
while true do
  local s=net.loadSession();local n=net.activeNetwork();local items={}
  if s then
    items={{label='Signed in as '..tostring(s.user),disabled=true},{label='Log out',action='logout'},{label='Switch account',action='switch'},{label='Back',action='back'}}
  else
    items={{label='SIGN IN',action='login'},{label='CREATE ACCOUNT',action='register'},{label='Back',action='back'}}
  end
  local m=gui.menu('SPAWNNET ACCOUNT','Network: '..tostring(n.name or n.id),items)
  if not m or m.action=='back'then break elseif m.action=='login'then login()elseif m.action=='register'then register()elseif m.action=='logout'then auth.logout();gui.toast('Signed out.',1)elseif m.action=='switch'then auth.logout();login()end
end
gui.clear()]=],
  ["/spawnnet-packages.lua"]=[=[local M=dofile('/spawnnet/client/package_manager.lua');local a={...};if a[1]=='install'then local ok,e=M.installFromSite(a[2],a[3],'command line');if not ok and e~='Cancelled'then printError(e)end elseif a[1]=='download'then local f,e=M.downloadFromSite(a[2],a[3],'command line');if f then print('Saved: '..f)elseif e~='Cancelled'then printError(e)end elseif a[1]=='run'then local ok,e=M.run(a[2],a[3]);if not ok then printError(e)end elseif a[1]=='uninstall'then local ok,e=M.uninstall(a[2],a[3]);if not ok and e~='Cancelled'then printError(e)end else M.menu()end
]=],
  ["/spawnnet-release.lua"]=[=[os.run({},'/spawnnet/client/release_manager.lua')
]=],
  ["/spawnnet.lua"]=[=[local a={...};shell.run('/spawnnet/client/spawnnet.lua',unpack(a))
]=],
  ["/spawnnet/client/api_explorer.lua"]=[=[local gui=dofile('/spawnnet/client/gui.lua')
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
]=],
  ["/spawnnet/client/apps.lua"]=[=[local gui=dofile('/spawnnet/client/gui.lua')
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
]=],
  ["/spawnnet/client/apps_chat.lua"]=[=[local net=dofile('/spawnnet/client/net.lua');local auth=dofile('/spawnnet/client/auth_client.lua');local ui=dofile('/spawnnet/client/ui.lua')
local sess=net.loadSession();if sess then local me=net.call('users','me',{});if not me then sess=nil end end;if not sess then local s,e=auth.ensureLogin();if not s then ui.error(e)return end end
local room=(...) or 'global'
while true do local p,e=net.call('chat','read',{room=room,limit=18});ui.clear('CHAT #'..room..'   /quit /room name /refresh');if p then for _,m in ipairs(p.messages)do print(('<%s> %s'):format(m.user,m.text))end else ui.error(e)end;term.setCursorPos(1,select(2,term.getSize()));term.clearLine();write('> ');local msg=read();if msg=='/quit'then break elseif msg:sub(1,6)=='/room 'then room=msg:sub(7)elseif msg~='/refresh'and msg~=''then net.call('chat','send',{room=room,text=msg})end end
ui.clear()
]=],
  ["/spawnnet/client/apps_forum.lua"]=[=[local gui=dofile('/spawnnet/client/gui.lua')
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
gui.clear()]=],
  ["/spawnnet/client/apps_keys.lua"]=[=[local net=dofile('/spawnnet/client/net.lua');local auth=dofile('/spawnnet/client/auth_client.lua');local ui=dofile('/spawnnet/client/ui.lua')
local sess=net.loadSession();if sess then local me=net.call('users','me',{});if not me then sess=nil end end;if not sess then local s,e=auth.ensureLogin();if not s then ui.error(e)return end end
while true do local p,e=net.call('auth','listKeys',{});ui.clear('API KEYS');if p then for i,k in ipairs(p.keys)do print(i..') '..k.label..' '..k.id..(k.revoked and' [REVOKED]'or''));print('   scopes: '..table.concat(k.scopes or {},','))end else ui.error(e)end;print();print('1 Create  2 Revoke  0 Back');local c=read();if c=='0'then break elseif c=='1'then local label=ui.prompt('Label','Machine key');local scopes=ui.prompt('Scopes comma-separated','telemetry.*');local ss={};for x in scopes:gmatch('[^,]+')do ss[#ss+1]=x:gsub('%s+','')end;local x,er=auth.createKey(label,ss);ui.clear('NEW API KEY');if x then print('ID:     '..x.id);print('SECRET: '..x.secret);print();print('This secret is shown ONCE. Save it in the machine config.')else ui.error(er)end;ui.pause()
elseif c=='2'then local n=tonumber(ui.prompt('Key #',''));local k=p and p.keys[n or 0];if k then net.call('auth','revokeKey',{id=k.id})end end end
ui.clear()
]=],
  ["/spawnnet/client/apps_mail.lua"]=[=[local gui=dofile('/spawnnet/client/gui.lua')
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
gui.clear()]=],
  ["/spawnnet/client/auth_client.lua"]=[=[local util=dofile('/spawnnet/lib/util.lua')
local crypto=dofile('/spawnnet/lib/crypto.lua')
local net=dofile('/spawnnet/client/net.lua')
local M={}
function M.verifier(username,password,salt) return crypto.sha256(util.safeName(username,24)..':'..tostring(password or '')..':'..tostring(salt or '')) end
function M.register(username,password,displayName)
  username=util.safeName(username,24); local salt=crypto.randomHex(12); local verifier=M.verifier(username,password,salt)
  local p,e=net.call('auth','register',{username=username,verifier=verifier,salt=salt,displayName=displayName},{noAuth=true}); if not p then return nil,e end
  return M.login(username,password)
end
function M.login(username,password)
  username=util.safeName(username,24); local begin,e=net.call('auth','begin',{username=username},{noAuth=true}); if not begin then return nil,e end
  local verifier=M.verifier(username,password,begin.salt or ''); local cid=os.getComputerID(); local proof=crypto.hmac(verifier,begin.nonce..':'..tostring(cid))
  local done,e2=net.call('auth','login',{username=username,proof=proof},{noAuth=true}); if not done then return nil,e2 end
  local key=crypto.hmac(verifier,done.challenge..':'..done.serverNonce..':'..done.id)
  local session={id=done.id,user=done.user,key=key,seq=0}; net.setSession(session); return session
end
function M.createKey(label,scopes) return net.call('auth','createKey',{label=label,scopes=scopes or {'*'}}) end
function M.apiLogin(id,secret)
  local begin,e=net.call('auth','apiBegin',{id=id},{noAuth=true}); if not begin then return nil,e end
  local verifier=crypto.sha256(tostring(secret or '')); local proof=crypto.hmac(verifier,begin.nonce..':'..tostring(os.getComputerID()))
  local done,e2=net.call('auth','apiLogin',{id=id,proof=proof},{noAuth=true}); if not done then return nil,e2 end
  local key=crypto.hmac(verifier,done.challenge..':'..done.serverNonce..':'..done.id); local session={id=done.id,user=done.user,key=key,seq=0,apiKey=id}; net.setSession(session); return session
end
function M.logout() local p,e=net.call('auth','logout',{}); net.setSession(nil); return p,e end
function M.ensureLogin()
  local s=net.loadSession(); if s then return s end
  write('SpawnNet username: '); local u=read(); write('Password: '); local pw=read('*'); local sess,e=M.login(u,pw); if not sess then return nil,e end; return sess
end
return M
]=],
  ["/spawnnet/client/browser.lua"]=[=[local util=dofile('/spawnnet/lib/util.lua')
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
end
local function draw()
  local sw,sh=term.getSize();local n=net.activeNetwork();term.setBackgroundColor(colors.gray);term.setTextColor(colors.white);term.setCursorPos(1,1);term.clearLine();write(('< > R H G S P N  '..tostring(n.name or n.id)):sub(1,sw))
  term.setCursorPos(1,2);term.setBackgroundColor(colors.lightGray);term.setTextColor(colors.black);term.clearLine();write((' '..address..'  | '..tostring(status or'')):sub(1,sw));term.setBackgroundColor(colors.black);term.setTextColor(colors.white)
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
end
term.setBackgroundColor(colors.black);term.setTextColor(colors.white);term.clear();term.setCursorPos(1,1)
]=],
  ["/spawnnet/client/desktop.lua"]=[=[local gui=dofile('/spawnnet/client/gui.lua')
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
  local s=validSession();local n=net.activeNetwork();local w,h=term.getSize();gui.clear();gui.bar('SPAWNNET '..config.version,tostring(n.name or n.id))
  local regions={};local y0
  if not s then
    gui.text(3,3,w-5,'You are browsing as a guest.',C.yellow,C.black)
    gui.text(3,4,w-5,'Sign in or create an account to publish, use Mail, and manage apps.',C.lightGray,C.black)
    local half=math.floor((w-7)/2);local a=gui.button(3,6,half,'SIGN IN',true,C.blue);a.action='account';regions[#regions+1]=a;local b=gui.button(5+half,6,w-half-7,'CREATE ACCOUNT',true,C.lime);b.action='account';regions[#regions+1]=b;y0=9
  else
    gui.text(3,3,w-5,'Signed in as '..tostring(s.user),C.lime,C.black)
    gui.text(3,4,w-5,'Websites, apps, packages, networks and real peripherals.',C.lightGray,C.black)
    y0=7
  end
  local apps={
    {title='WEB',sub='Browse SpawnNet',path='/spawnnet/client/browser.lua',arg='spn://home',bg=C.blue},
    {title='MAIL',sub='Messages',path='/spawnnet/client/apps_mail.lua',bg=C.cyan},
    {title='SEARCH',sub='Find websites',special='search',bg=C.blue},
    {title='STUDIO',sub='Build websites',path='/spawnnet/client/studio_easy.lua',bg=C.purple},
    {title='NETWORKS',sub='Connect / intranets',path='/spawnnet/client/networks.lua',bg=C.gray},
    {title='APPS',sub='Pinned websites',path='/spawnnet/client/apps.lua',bg=C.blue},
    {title='LABS',sub='Showcase demos',path='/spawnnet/client/labs.lua',bg=C.orange},
    {title='DEV TOOLS',sub='SDK / API / Studio',path='/spawnnet/client/developer.lua',bg=C.gray},
    {title='PACKAGES',sub='Installed software',path='/spawnnet-packages.lua',bg=C.green},
    {title='PERIPHERALS',sub='Hardware tools',path='/spawnnet/client/machines.lua',bg=C.cyan},
    {title='ACCOUNT',sub=s and tostring(s.user)or'Login / register',path='/spawnnet/client/account.lua',bg=C.gray},
    {title='SETTINGS',sub='Network / updates',path='/spawnnet/client/settings.lua',bg=C.gray},
  }
  local cols=3;local gap=2;local left=2;local bw=math.floor((w-left-1-gap*(cols-1))/cols);local tileH=3;local rows=4
  if h<26 then tileH=2 end
  for i,a in ipairs(apps)do local col=(i-1)%cols;local row=math.floor((i-1)/cols);local x=left+col*(bw+gap);local y=y0+row*(tileH+1);local r=gui.tile(x,y,bw,tileH,a.title,tileH>=3 and a.sub or'',a.bg,true);r.app=i;regions[#regions+1]=r end
  gui.status('Click an app   Q quits')
  local ev={os.pullEvent()}
  if ev[1]=='key'and ev[2]==keys.q then break
  elseif ev[1]=='mouse_click'then local r=gui.hit(regions,ev[3],ev[4]);if r then
    if r.action=='account'then run('/spawnnet/client/account.lua')elseif r.app then local a=apps[r.app];if a.special=='search'then local q=gui.prompt('SEARCH','Search SpawnNet:','');if q~=''then run('/spawnnet/client/search.lua',q)end else run(a.path,a.arg)end end
  end end
end
gui.clear()]=],
  ["/spawnnet/client/developer.lua"]=[=[local gui=dofile('/spawnnet/client/gui.lua')
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
]=],
  ["/spawnnet/client/doctor.lua"]=[=[local config=dofile('/spawnnet/lib/config.lua');local net=dofile('/spawnnet/client/net.lua');local ui=dofile('/spawnnet/client/ui.lua')
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
]=],
  ["/spawnnet/client/gui.lua"]=[=[local M={}
local C=colors
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
function M.clear(bg)term.setBackgroundColor(bg or C.black);term.setTextColor(C.white);term.clear();term.setCursorPos(1,1)end
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
  local w=select(1,term.getSize());M.text(1,1,w,'',C.white,C.gray)
  local rs=right and tostring(right)or'';local rw=math.min(#rs,math.max(0,math.floor(w*.48)));local lw=math.max(1,w-rw-4)
  M.text(2,1,lw,title or'SpawnNet',C.yellow,C.gray)
  if rw>0 then M.text(w-rw,1,rw,rs,C.lightGray,C.gray,'right')end
end
function M.status(text,good)
  local w,h=term.getSize();M.text(1,h,w,' '..tostring(text or''),good==false and C.red or C.lightGray,C.gray)
end
function M.button(x,y,w,label,enabled,bg)
  local b=enabled==false and C.gray or(bg or C.blue);local fg=enabled==false and C.lightGray or C.white
  M.text(x,y,w,tostring(label or''),fg,b,'center');return{x1=x,y1=y,x2=x+w-1,y2=y,label=label,enabled=enabled~=false}
end
function M.tile(x,y,w,h,title,subtitle,bg,enabled)
  h=math.max(2,h or 3);local b=enabled==false and C.gray or(bg or C.blue);local fg=enabled==false and C.lightGray or C.white
  for yy=y,y+h-1 do M.text(x,yy,w,'',fg,b)end
  M.text(x,y,w,title,fg,b,'center')
  if h>=3 and subtitle and subtitle~=''then M.text(x+1,y+1,w-2,subtitle,C.lightGray,b,'center')end
  return{x1=x,y1=y,x2=x+w-1,y2=y+h-1,enabled=enabled~=false}
end
function M.box(x,y,w,h,title,bg)
  bg=bg or C.black;if w<2 or h<2 then return end
  M.text(x,y,w,string.rep('-',w),C.lightGray,bg);for yy=y+1,y+h-2 do M.text(x,yy,w,'|'..string.rep(' ',math.max(0,w-2))..'|',C.lightGray,bg)end;M.text(x,y+h-1,w,string.rep('-',w),C.lightGray,bg)
  if title then M.text(x+2,y,math.min(w-4,#tostring(title)),title,C.yellow,bg)end
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
  local w=select(1,term.getSize());M.clear();M.bar(title or'INPUT');M.wrapped(3,4,w-5,2,label or'',C.white,C.black);M.text(3,7,w-5,'',C.black,C.lightGray)
  local v=editLine(4,7,w-7,default,mask);term.setBackgroundColor(C.black);term.setTextColor(C.white)
  return v==nil and''or v
end
function M.confirm(title,message)
  local w=select(1,term.getSize());M.clear();M.bar(title or'CONFIRM');M.wrapped(3,4,w-5,10,message,C.white,C.black);M.text(3,16,w-5,'Y confirm     N cancel',C.yellow,C.black)
  while true do local e,k=os.pullEvent('key');if k==keys.y or k==keys.enter then return true elseif k==keys.n or k==keys.q or k==keys.escape then return false end end
end
function M.menu(title,subtitle,items,opts)
  opts=opts or{};local selected=1;items=items or{}
  while true do
    local w,h=term.getSize();M.clear(opts.bg or C.black);M.bar(title,opts.right)
    if subtitle then M.text(3,3,w-5,subtitle,C.lightGray,C.black,'center')end
    local start=opts.startY or 5;local visible=math.max(1,h-start-1);if #items==0 then M.text(3,start,w-5,'Nothing here yet.',C.lightGray,C.black);M.status('Q back');local _,k=os.pullEvent('key');if k==keys.q or k==keys.backspace or k==keys.escape then return nil end else
      selected=clamp(selected,1,#items);local first=math.max(1,math.min(selected-math.floor(visible/2),math.max(1,#items-visible+1)));local regions={}
      for row=0,visible-1 do local i=first+row;if i>#items then break end;local it=items[i];local sel=i==selected;local bg=sel and C.blue or C.black;local fg=it.disabled and C.gray or(sel and C.white or C.lightGray);M.text(3,start+row,w-5,(sel and'> 'or'  ')..tostring(it.label or it.id or i),fg,bg);regions[#regions+1]={x1=2,y1=start+row,x2=w-1,y2=start+row,index=i,enabled=not it.disabled}end
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
return M]=],
  ["/spawnnet/client/labs.lua"]=[=[local gui=dofile('/spawnnet/client/gui.lua')
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
]=],
  ["/spawnnet/client/machines.lua"]=[=[local gui=dofile('/spawnnet/client/gui.lua')
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
gui.clear()]=],
  ["/spawnnet/client/net.lua"]=[=[local config=dofile('/spawnnet/lib/config.lua')
local util=dofile('/spawnnet/lib/util.lua')
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
  n.name=tostring(info.name or n.name or id):sub(1,48)
  n.visibility=info.visibility or n.visibility or 'public'
  n.coreId=tonumber(info.coreId) or n.coreId
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
          local n=M.addNetwork({id=id,name=msg.name or id,visibility=msg.visibility or 'public',coreId=sender,protocol=msg.protocol,lastSeen=util.now()})
          found[id]=util.deepcopy(n)
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
  if n.key and n.key~='' then req.networkKey=n.key end
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
            if sess and msg.status~=401 and not packet.verifyResponse(msg,sess.key) then return nil,'Invalid SpawnNet response signature' end
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
  local deadline=os.startTimer(opts.timeout or cfg.timeout or config.requestTimeout)
  while true do
    local ev={os.pullEvent()}
    if ev[1]=='timer' and ev[2]==deadline then
      -- Cached core IDs can become stale when a network moves. Forget it once.
      if not opts._retried then n.coreId=nil; saveRegistry(); opts._retried=true; return M.request(service,action,payload,opts) end
      return nil,'SpawnNet request timed out'
    end
    if ev[1]=='rednet_message' then
      local sender,msg,rproto=ev[2],ev[3],ev[4]
      if rproto==proto and sender==id then
        local complete=wire.accept(sender,msg,M._fragments); wire.purge(M._fragments); msg=complete
        if type(msg)=='table' and msg.network=='spawnnet' and msg.type=='response' then
          if msg.requestId==req.requestId then
            if sess and msg.status~=401 and not packet.verifyResponse(msg,sess.key) then return nil,'Invalid SpawnNet response signature' end
            if msg.status==401 and sess then
              M.setSession(nil)
              if opts.allowGuest then local retry=util.deepcopy(opts);retry.allowGuest=nil;retry.noAuth=true;return M.request(service,action,payload,retry) end
            end
            return msg
          else M._inbox[msg.requestId]=msg end
        end
      end
    end
  end
end
function M.call(service,action,payload,opts)
  local r,e=M.request(service,action,payload,opts); if not r then return nil,e end
  if (r.status or 500)>=400 then return nil,r.error or ('SpawnNet error '..tostring(r.status)),r end
  return r.payload,nil,r
end
return M
]=],
  ["/spawnnet/client/network_lab.lua"]=[=[local gui=dofile('/spawnnet/client/gui.lua')
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
]=],
  ["/spawnnet/client/networks.lua"]=[=[local gui=dofile('/spawnnet/client/gui.lua')
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
]=],
  ["/spawnnet/client/nodes.lua"]=[=[local gui=dofile('/spawnnet/client/gui.lua')
local net=dofile('/spawnnet/client/net.lua')
local function load()
  local p,e=net.call('nodes','summary',{});if not p then gui.toast(e or 'Admin login required',2);return nil end;return p
end
while true do
  local p=load();if not p then break end
  local items={}
  for _,n in ipairs(p.nodes or {})do items[#items+1]={label='ONLINE  #'..tostring(n.id)..'  '..tostring(n.name or '')..'  free='..tostring(n.free or '?'),node=n}end
  for _,n in ipairs(p.pendingNodes or {})do items[#items+1]={label='PENDING #'..tostring(n.id)..' code='..tostring(n.pairCode or '?'),pending=n}end
  items[#items+1]={label='Rebalance / replicate objects',action='rebalance'};items[#items+1]={label='Refresh',action='refresh'};items[#items+1]={label='Back',action='back'}
  local sub='Nodes '..tostring(p.online or 0)..'/'..tostring(p.totalNodes or 0)..'  objects '..tostring(p.objects or 0)..'  free '..tostring(p.free or 0)
  local m=gui.menu('STORAGE CLUSTER',sub,items)
  if not m or m.action=='back'then break
  elseif m.action=='rebalance'then local r,e=net.call('nodes','rebalance',{});gui.toast(r and('Added '..tostring(r.copiesAdded)..' replica(s)')or e,2)
  elseif m.pending then
    local n=m.pending;if gui.confirm('APPROVE NODE','Approve storage node #'..tostring(n.id)..'\nPair code: '..tostring(n.pairCode)..'?')then local name=gui.prompt('NODE NAME','Name:',n.name or ('Storage #'..n.id));local ok,e=net.call('nodes','approve',{id=n.id,name=name});gui.toast(ok and 'Node approved' or e,2)end
  elseif m.node then
    if gui.confirm('NODE #'..m.node.id,'Remove this node from the cluster?')then local ok,e=net.call('nodes','remove',{id=m.node.id});gui.toast(ok and 'Node removed' or e,2)end
  end
end
]=],
  ["/spawnnet/client/package_manager.lua"]=[=[-- SpawnNet native application package manager 2.2.1
local util=dofile('/spawnnet/lib/util.lua')
local net=dofile('/spawnnet/client/net.lua')
local crypto=dofile('/spawnnet/lib/crypto.lua')
local sm=dofile('/spawnnet/client/service_manager.lua')
local M={};local ROOT='/spawnnet/apps';local DB=ROOT..'/installed.db';local DATA='/spawnnet/appdata';local DOWNLOADS='/downloads';local C=colors
local PERM_LABELS={filesystem='Read/write local files',peripheral='Access attached peripherals',modem='Use wired/wireless modems',rednet='Use Rednet/network messages',shell='Launch other programs',http='Use HTTP/WebSocket APIs',startup='Run a background service at startup',commands='Create local command launchers'}
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
local function manifest(domain,name)return net.call('package','manifest',{domain=safe(domain),name=safe(name)},{noAuth=true})end
local function getPackage(domain,name)return net.call('package','get',{domain=safe(domain),name=safe(name)},{noAuth=true})end
local function installed()return util.loadTable(DB,{})end
local function saveInstalled(t)ensure(ROOT);util.saveTable(DB,t)end
local function key(d,n)return safe(d)..'/'..safe(n)end
local function hasPerm(m,p)for _,x in ipairs(m.permissions or{})do if x==p then return true end end;return false end
local function wrap(s,w)local out={};s=tostring(s or'');while #s>w do local cut=w;local p=s:sub(1,w):match('^.*()%s');if p and p>8 then cut=p end;out[#out+1]=s:sub(1,cut):gsub('%s+$','');s=s:sub(cut+1):gsub('^%s+','')end;if s~=''then out[#out+1]=s end;return out end
local function nativeConfirm(kind,m,source,newPerms)
  term.setBackgroundColor(C.black);term.clear();term.setCursorPos(1,1);local w,h=term.getSize();term.setBackgroundColor(kind=='INSTALL'and C.blue or C.gray);term.setTextColor(C.white);term.clearLine();write((' '..kind..' APPLICATION - SPAWNNET SECURITY '):sub(1,w));term.setBackgroundColor(C.black);term.setTextColor(C.yellow);term.setCursorPos(2,3);print(tostring(m.title or m.name));term.setTextColor(C.lightGray);print('Version: '..tostring(m.version or'?'));print('Publisher: '..tostring(m.publisher or'?'));print('Site: spn://'..tostring(m.domain or'?'));if source then print('Requested by: '..tostring(source):sub(1,math.max(1,w-15)))end;print('Files: '..tostring(m.files or'?')..'   Size: '..tostring(m.totalBytes or'?')..' bytes');term.setTextColor(C.white);print();print('Permissions requested:');if #(m.permissions or{})==0 then term.setTextColor(C.lime);print('  None declared')else for _,p in ipairs(m.permissions or{})do term.setTextColor((newPerms and newPerms[p])and C.orange or C.white);print('  - '..tostring(PERM_LABELS[p]or p))end end;if newPerms and next(newPerms)then term.setTextColor(C.orange);print();print('WARNING: This update requests NEW permissions.')end;term.setTextColor(C.lightGray);print();for _,line in ipairs(wrap('Installed Lua is trusted code. The website cannot approve this screen; only you can.',math.max(10,w-4)))do print('  '..line)end;term.setCursorPos(1,h);term.setBackgroundColor(C.gray);term.setTextColor(C.white);term.clearLine();write(' N cancel                                      Y confirm');while true do local _,k=os.pullEvent('key');if k==keys.y then return true elseif k==keys.n or k==keys.q or k==keys.escape then return false end end
end
local function ensureStartupBridge()
  local target='/startup.lua';local marker='SPAWNNET_SERVICE_BRIDGE_2.2.1';local current='';if fs.exists(target)then local h=fs.open(target,'r');if h then current=h.readAll();h.close()end end;if current:find(marker,1,true)then return true end;if current~=''and not fs.exists('/startup.pre-spawnnet.lua')then fs.copy(target,'/startup.pre-spawnnet.lua')end;local h=assert(fs.open(target,'w'));h.write("-- SPAWNNET_SERVICE_BRIDGE_2.2.1\nos.run({},'/spawnnet/client/startup_bridge.lua')\n");h.close();return true
end
local function commandPath(name)return '/'..safe(name)..'.lua'end
local function commandBody(domain,name,rel)local app=ROOT..'/'..domain..'/'..name..'/app/'..rel;return "-- SPAWNNET_APP_COMMAND "..domain..'/'..name.."\nlocal a={...};os.run({},"..string.format('%q',app)..",unpack(a))\n"end
local function preflightCommands(pkg)
  if not hasPerm(pkg,'commands')then return true end
  for name,rel in pairs(pkg.commands or{})do local p=commandPath(name);if fs.exists(p)then local h=fs.open(p,'r');local s=h and h.readAll()or'';if h then h.close()end;if not s:find('SPAWNNET_APP_COMMAND '..safe(pkg.domain)..'/'..safe(pkg.name),1,true)then return nil,'Command already exists: '..name end end;if not pkg.files[rel]then return nil,'Command target missing: '..rel end end;return true
end
local function syncCommands(pkg,old)
  if old then for n in pairs(old.commands or{})do if not(pkg.commands and pkg.commands[n])then local p=commandPath(n);if fs.exists(p)then local h=fs.open(p,'r');local s=h and h.readAll()or'';if h then h.close()end;if s:find('SPAWNNET_APP_COMMAND '..safe(pkg.domain)..'/'..safe(pkg.name),1,true)then fs.delete(p)end end end end end
  if hasPerm(pkg,'commands')then for n,rel in pairs(pkg.commands or{})do local h=assert(fs.open(commandPath(n),'w'));h.write(commandBody(safe(pkg.domain),safe(pkg.name),rel));h.close()end end
end
local function syncService(pkg)
  local d,n=safe(pkg.domain),safe(pkg.name);if pkg.service and hasPerm(pkg,'startup')then local path=ROOT..'/'..d..'/'..n..'/app/'..pkg.service;sm.register(d,n,pkg.title,path);ensureStartupBridge()else sm.unregister(d,n)end
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
local function runInstalled(rec)if not rec or not rec.entry then return nil,'Package has no entry program'end;local path=ROOT..'/'..rec.domain..'/'..rec.name..'/app/'..rec.entry;if not fs.exists(path)then return nil,'Entry file missing'end;local ok=os.run({},path,'spawnnet-package');if not ok then return nil,'Program exited with an error'end;return true end
local function doInstall(domain,name,source,updating)
  local p,e=manifest(domain,name);if not p then return nil,e end;local m=p.package or p;local db=installed();local old=db[key(domain,name)];local newPerms={};if old then local have={};for _,x in ipairs(old.permissions or{})do have[x]=true end;for _,x in ipairs(m.permissions or{})do if not have[x]then newPerms[x]=true end end end;if not nativeConfirm(updating and'UPDATE'or'INSTALL',m,source,newPerms)then return nil,'Cancelled'end;local got,ge=getPackage(domain,name);if not got then return nil,ge end;local pkg=got.package or got;local root,we=writePackage(pkg);if not root then return nil,we end;term.setBackgroundColor(C.black);term.clear();term.setCursorPos(1,2);term.setTextColor(C.lime);print((updating and'UPDATED: 'or'INSTALLED: ')..tostring(pkg.title or pkg.name)..' '..tostring(pkg.version));term.setTextColor(C.white);print('Location: '..root);if pkg.entry then print();write('Run it now? Y/n: ');local a=read():lower();if a~='n'and a~='no'then local rec=installed()[key(domain,name)];local rok,re=runInstalled(rec);if not rok then printError(re)end end end;return true
end
function M.installFromSite(domain,name,source)return doInstall(domain,name,source,false)end
function M.downloadFromSite(domain,name,source)local p,e=manifest(domain,name);if not p then return nil,e end;local m=p.package or p;if not nativeConfirm('DOWNLOAD',m,source)then return nil,'Cancelled'end;local got,ge=getPackage(domain,name);if not got then return nil,ge end;local pkg=got.package or got;if canonicalHash(pkg)~=tostring(pkg.hash or'')then return nil,'Package integrity check failed'end;ensure(DOWNLOADS);local file=DOWNLOADS..'/'..safe(domain)..'-'..safe(name)..'-'..tostring(pkg.version or'package'):gsub('[^%w%.%-_]','_')..'.spkg';local h=assert(fs.open(file,'w'));h.write(textutils.serialize(pkg));h.close();return file end
function M.run(domain,name)local rec=installed()[key(domain,name)];if not rec then return nil,'Not installed'end;return runInstalled(rec)end
function M.uninstall(domain,name)local db=installed();local k=key(domain,name);local rec=db[k];if not rec then return nil,'Not installed'end;term.clear();term.setCursorPos(1,2);term.setTextColor(C.yellow);print('UNINSTALL '..tostring(rec.title or rec.name)..'?');term.setTextColor(C.lightGray);print('Application files will be removed. App data is kept.');print();write('Type UNINSTALL: ');if read()~='UNINSTALL'then return nil,'Cancelled'end;sm.unregister(rec.domain,rec.name);for n in pairs(rec.commands or{})do local p=commandPath(n);if fs.exists(p)then local h=fs.open(p,'r');local s=h and h.readAll()or'';if h then h.close()end;if s:find('SPAWNNET_APP_COMMAND '..rec.domain..'/'..rec.name,1,true)then fs.delete(p)end end end;local root=ROOT..'/'..rec.domain..'/'..rec.name;if fs.exists(root)then fs.delete(root)end;db[k]=nil;saveInstalled(db);return true end
function M.menu()while true do local db=installed();local list={};for _,r in pairs(db)do list[#list+1]=r end;table.sort(list,function(a,b)return tostring(a.title or a.name)<tostring(b.title or b.name)end);term.setBackgroundColor(C.black);term.clear();term.setCursorPos(1,1);term.setTextColor(C.yellow);print('SPAWNNET INSTALLED APPS');term.setTextColor(C.white);if #list==0 then print();print('No SpawnNet application packages installed.')else for i,r in ipairs(list)do print(i..') '..tostring(r.title or r.name)..'  '..tostring(r.version))end end;print();print('R # run   U # update   X # uninstall   Q quit');write('> ');local line=read();local c,num=line:match('^(%a)%s*(%d*)');c=c and c:lower();local r=list[tonumber(num) or 0];if c=='q'then return elseif c=='r'and r then runInstalled(r)elseif c=='u'and r then local ok,e=doInstall(r.domain,r.name,'Installed Apps',true);if not ok and e~='Cancelled'then printError(e);sleep(1.5)end elseif c=='x'and r then local ok,e=M.uninstall(r.domain,r.name);if not ok and e~='Cancelled'then printError(e);sleep(1.5)end end end end
return M
]=],
  ["/spawnnet/client/peripheral_lab.lua"]=[=[local gui=dofile('/spawnnet/client/gui.lua')
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
]=],
  ["/spawnnet/client/release_manager.lua"]=[=[-- SpawnNet release manager 2.2.1
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
]=],
  ["/spawnnet/client/renderer.lua"]=[=[local util=dofile('/spawnnet/lib/util.lua')
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
]=],
  ["/spawnnet/client/sdk.lua"]=[=[local net=dofile('/spawnnet/client/net.lua')
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
]=],
  ["/spawnnet/client/search.lua"]=[=[local gui=dofile('/spawnnet/client/gui.lua')
local net=dofile('/spawnnet/client/net.lua')
local q=(...) or ''
if q==''then q=gui.prompt('SEARCH','Search network:','')end
if q==''then return end
local p,e=net.call('search','query',{q=q},{noAuth=true});if not p then gui.toast(e,2)return end
local items={};for _,r in ipairs(p.results or {})do items[#items+1]={label=tostring(r.domain)..' - '..tostring(r.title),domain=r.domain}end;items[#items+1]={label='Back',action='back'}
local m=gui.menu('SEARCH: '..q,tostring(#(p.results or {}))..' result(s)',items);if m and m.domain then shell.run('/spawnnet/client/browser.lua','spn://'..m.domain)end
]=],
  ["/spawnnet/client/service_manager.lua"]=[=[-- SpawnNet application service manager 2.2.1
local util=dofile('/spawnnet/lib/util.lua')
local M={};local DB='/spawnnet/services.db';local LOG='/spawnnet/service-errors.log'
local function load()return util.loadTable(DB,{})end
local function save(t)util.saveTable(DB,t)end
local function key(d,n)return tostring(d)..'/'..tostring(n)end
function M.register(domain,name,title,path)
  local t=load();t[key(domain,name)]={domain=domain,name=name,title=title or name,path=path,enabled=true};save(t);return true
end
function M.unregister(domain,name)local t=load();t[key(domain,name)]=nil;save(t);return true end
function M.list()return load()end
local function log(s)local h=fs.open(LOG,'a');if h then h.writeLine(tostring(s));h.close()end end
local function runOne(s)
  while true do
    if s.enabled and s.path and fs.exists(s.path)then local ok,err=pcall(function()return os.run({},s.path,'spawnnet-service')end);if not ok then log(os.date and os.date()or tostring(os.clock())..' '..tostring(s.title)..': '..tostring(err))end end
    sleep(2)
  end
end
function M.runAll()
  local t=load();local funcs={}
  for _,s in pairs(t)do funcs[#funcs+1]=function()runOne(s)end end
  if #funcs==0 then while true do os.pullEventRaw()end end
  parallel.waitForAll(unpack(funcs))
end
return M
]=],
  ["/spawnnet/client/settings.lua"]=[=[local gui=dofile('/spawnnet/client/gui.lua')
local net=dofile('/spawnnet/client/net.lua')
while true do
  local s=net.loadSession();local n=net.activeNetwork();local items={
    {label='Account - '..(s and tostring(s.user)or'Guest'),action='account'},
    {label='Network Manager',action='net'},
    {label='Installed Applications / Packages',action='packages'},
    {label='Diagnostics',action='doctor'},
    {label='Check for SpawnNet update',action='update'},
    {label='Back',action='back'},
  }
  local m=gui.menu('SPAWNNET SETTINGS','Active: '..tostring(n.name or n.id)..' ['..tostring(n.id)..']',items)
  if not m or m.action=='back'then break elseif m.action=='account'then shell.run('/spawnnet/client/account.lua')elseif m.action=='net'then shell.run('/spawnnet/client/networks.lua')elseif m.action=='packages'then shell.run('/spawnnet-packages.lua')elseif m.action=='doctor'then shell.run('/spawnnet/client/doctor.lua')elseif m.action=='update'then shell.run('/spawnnet/client/updater.lua','client')end
end
gui.clear()]=],
  ["/spawnnet/client/spawnnet.lua"]=[=[local ui=dofile('/spawnnet/client/ui.lua')
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
 print('  spawnnet labs                  showcase labs')
 print('  spawnnet dev                   developer workbench')
end]=],
  ["/spawnnet/client/startup_bridge.lua"]=[=[-- SpawnNet service startup bridge 2.2.1
local sm=dofile('/spawnnet/client/service_manager.lua')
local function services()sm.runAll()end
local function userSession()
  if fs.exists('/startup.pre-spawnnet.lua')then pcall(function()os.run({},'/startup.pre-spawnnet.lua')end)end
  while true do os.run({},'rom/programs/shell.lua')end
end
parallel.waitForAll(services,userSession)
]=],
  ["/spawnnet/client/studio.lua"]=[=[shell.run('/spawnnet/client/studio_easy.lua')
]=],
  ["/spawnnet/client/studio_advanced.lua"]=[=[local util=dofile('/spawnnet/lib/util.lua')
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
]=],
  ["/spawnnet/client/studio_easy.lua"]=[=[local gui=dofile('/spawnnet/client/gui.lua')
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
gui.clear()]=],
  ["/spawnnet/client/telemetry_agent.lua"]=[=[local net=dofile('/spawnnet/client/net.lua');local auth=dofile('/spawnnet/client/auth_client.lua');local util=dofile('/spawnnet/lib/util.lua')
local cfgPath='/spawnnet/telemetry.cfg'
local cfg=util.loadTable(cfgPath,{domain='mysite',stream='machines',interval=10,apiKeyId='',apiKeySecret='',fields={example={peripheral='left',method='getEnergyStored'}}})
if not fs.exists(cfgPath)then util.saveTable(cfgPath,cfg);print('Created '..cfgPath..'. Edit it, then run again.');return end
if not net.loadSession()then local s,e;if cfg.apiKeyId and cfg.apiKeyId~=''and cfg.apiKeySecret and cfg.apiKeySecret~=''then s,e=auth.apiLogin(cfg.apiKeyId,cfg.apiKeySecret)else write('SpawnNet username: ');local u=read();write('Password: ');s,e=auth.login(u,read('*'))end;if not s then printError(e)return end end
print('Telemetry agent -> spn://'..cfg.domain..' / '..cfg.stream)
while true do local data={};for name,f in pairs(cfg.fields or {})do local ok,val=pcall(peripheral.call,f.peripheral,f.method,unpack(f.args or {}));data[name]=ok and val or {error=tostring(val)} end;data.online=true;data.computer=os.getComputerID();local p,e=net.call('telemetry','push',{domain=cfg.domain,stream=cfg.stream,data=data,computer=os.getComputerID()});if not p then printError(e)else print('pushed '..tostring(os.time()))end;sleep(tonumber(cfg.interval)or 10)end
]=],
  ["/spawnnet/client/templates.lua"]=[=[local M={}
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
]=],
  ["/spawnnet/client/ui.lua"]=[=[local M={}
function M.clear(title)
  term.setBackgroundColor(colors.black); term.setTextColor(colors.white); term.clear(); term.setCursorPos(1,1)
  if title then term.setBackgroundColor(colors.gray); term.clearLine(); term.setCursorPos(2,1); write(title); term.setBackgroundColor(colors.black) end
end
function M.center(y,text,fg,bg)
  local w=select(1,term.getSize()); text=tostring(text or ''); term.setCursorPos(math.max(1,math.floor((w-#text)/2)+1),y); if fg then term.setTextColor(fg) end; if bg then term.setBackgroundColor(bg) end; write(text); term.setTextColor(colors.white); term.setBackgroundColor(colors.black)
end
function M.prompt(label,default,mask)
  term.setTextColor(colors.lightGray); write(label..': '); term.setTextColor(colors.white); if default and default~='' then write('['..default..'] ') end
  local v=read(mask); if v=='' and default~=nil then v=default end; return v
end
function M.menu(title,items)
  while true do
    M.clear(title); for i,item in ipairs(items) do term.setCursorPos(2,i+2); write(('%d) %s'):format(i,item.label or tostring(item))) end; term.setCursorPos(2,#items+4); write('Choice: ')
    local n=tonumber(read()); if n and items[n] then return n,items[n] end
  end
end
function M.pause(msg) print(msg or 'Press any key...'); os.pullEvent('key') end
function M.error(msg) term.setTextColor(colors.red); print(tostring(msg)); term.setTextColor(colors.white) end
function M.success(msg) term.setTextColor(colors.lime); print(tostring(msg)); term.setTextColor(colors.white) end
return M
]=],
  ["/spawnnet/client/updater.lua"]=[=[-- SpawnNet transactional system updater 2.2.1
local net=dofile('/spawnnet/client/net.lua')
local util=dofile('/spawnnet/lib/util.lua')
local crypto=dofile('/spawnnet/lib/crypto.lua')
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
local function hash(pkg)local paths={};for p in pairs(pkg.files or{})do paths[#paths+1]=p end;table.sort(paths);local parts={tostring(pkg.name or''),tostring(pkg.version or''),tostring(pkg.component or''),tostring(pkg.channel or''),tostring(pkg.restartRequired and true or false)};for _,p in ipairs(paths)do parts[#parts+1]='file:'..p..':'..crypto.sha256(tostring(pkg.files[p]or''))end;return crypto.sha256(table.concat(parts,'\0'))end
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
local m,e=net.call('package','manifest',{name=NAME},{noAuth=true})
if not m then print('No published '..NAME..' release: '..tostring(e));return end
local man=m.package or m
local localv=(readText(VERSION)or'unknown'):gsub('%s+$','')
print('SpawnNet '..NAME..' release')
print('Installed: '..localv)
print('Available: '..tostring(man.version))
if mode=='check'then return end
if localv==tostring(man.version)then print('Already current.');return end
write('Update now? Y/n: ');local a=read():lower();if a=='n'or a=='no'then return end
local got,ge=net.call('package','get',{name=NAME},{noAuth=true});if not got then error(ge,0)end
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
]=],
  
  ["/spawnnet/lib/config.lua"]=[=[return {
  version = "2.2.1",
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
  siteStorageKeys = 768,
  databaseCollectionRows = 1000,
  telemetryPoints = 480,
  maxJobsPerDomain = 500,
  jobRetention = 250,
  nodeHeartbeatTimeout = 35,
  objectReplicas = 2,
  remoteAssetThreshold = 4096,
  defaultHome = "spn://home",
}
]=],
  ["/spawnnet/lib/crypto.lua"]=[=[-- Pure-Lua SHA-256/HMAC adapter for ComputerCraft's bit/bit32 APIs.
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
function M.randomHex(bytes)
  bytes=bytes or 16
  local seed=(os.getComputerID and os.getComputerID() or 0)*1103515245 + (os.time and math.floor(os.time()*1000) or 0) + math.floor((os.clock and os.clock() or 0)*100000)
  math.randomseed(seed % 2147483647)
  local t={}
  for i=1,bytes do t[i]=string.format("%02x",math.random(0,255)) end
  return table.concat(t)
end
return M
]=],
  ["/spawnnet/lib/packet.lua"]=[=[local util=dofile("/spawnnet/lib/util.lua")
local crypto=dofile("/spawnnet/lib/crypto.lua")
local config=dofile("/spawnnet/lib/config.lua")
local M={}
function M.new(service,action,payload)
  return {network="spawnnet",version=config.packetVersion or 2,type="request",requestId=util.id("req"),service=service,action=action,payload=payload or {}}
end
function M.signingString(p)
  return table.concat({p.network or "",tostring(p.version or ""),p.networkId or "",p.type or "",p.requestId or "",p.service or "",p.action or "",util.canonical(p.payload or {}),p.auth and p.auth.session or "",p.auth and tostring(p.auth.seq or "") or ""},"|")
end
function M.attachAuth(p,session)
  if not session then return p end
  session.seq=(session.seq or 0)+1
  p.auth={user=session.user,session=session.id,seq=session.seq}
  p.auth.sig=crypto.hmac(session.key,M.signingString(p))
  return p
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
  return table.concat({p.network or '',tostring(p.version or ''),p.type or '',p.requestId or '',p.service or '',p.action or '',tostring(p.status or ''),util.canonical(p.payload or {}),p.error or ''},'|')
end
function M.signResponse(p,key) p.responseSig=crypto.hmac(key,M.responseSigningString(p)); return p end
function M.verifyResponse(p,key) return type(p.responseSig)=='string' and crypto.constantTimeEq(p.responseSig,crypto.hmac(key,M.responseSigningString(p))) end
function M.isResponseFor(p,requestId)
  return type(p)=="table" and p.network=="spawnnet" and p.version==(config.packetVersion or 2) and p.type=="response" and p.requestId==requestId
end
return M
]=],
  ["/spawnnet/lib/spawnscript.lua"]=[=[-- SpawnScript: bounded, interpreted scripting for hosted SpawnNet applications.
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
]=],
  ["/spawnnet/lib/util.lua"]=[=[local M = {}

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
  ["/spawnnet/lib/wire.lua"]=[=[local util=dofile('/spawnnet/lib/util.lua')
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
]=],
  ["/studio.lua"]=[=[shell.run('/spawnnet/client/studio_easy.lua')
]=],
  ["/web.lua"]=[=[local a={...};shell.run('/spawnnet/client/browser.lua',a[1]or'spn://home')
]=],
}

local VERSION='2.2.1'
local function ensure(path)
  if path==''or path=='/'or fs.exists(path)then return end
  local parent=fs.getDir(path);if parent and parent~=''then ensure(parent)end;fs.makeDir(path)
end
local function writeFile(path,data)
  ensure(fs.getDir(path));local tmp=path..'.install-tmp'
  if fs.exists(tmp)then fs.delete(tmp)end
  local h=assert(fs.open(tmp,'w'));h.write(data);h.close()
  if fs.exists(path)then fs.delete(path)end;fs.move(tmp,path)
end
local function validateAll()
  local count=0
  for path,data in pairs(files)do
    if path:sub(-4)=='.lua'then
      local f,e=loadstring(data,'@'..path)
      if not f then error('REFUSING INSTALL: embedded '..path..' has a Lua syntax error: '..tostring(e),0)end
      count=count+1
    end
  end
  return count
end
term.clear();term.setCursorPos(1,1);term.setTextColor(colors.yellow);print('SPAWNNET CLIENT '..VERSION);term.setTextColor(colors.white)
local upgrading=fs.exists('/spawnnet/client/net.lua')
print(upgrading and'Complete in-place upgrade detected.'or'Fresh complete client install.')
print('Validating every embedded Lua program BEFORE writing...')
local checked=validateAll();print('Lua validation: '..checked..' files OK')
for path,data in pairs(files)do writeFile(path,data)end
local util=dofile('/spawnnet/lib/util.lua')
local config=dofile('/spawnnet/lib/config.lua')
local net=dofile('/spawnnet/client/net.lua')
ensure('/spawnnet/version');writeFile('/spawnnet/version/client-release.txt',VERSION..'\n')
if not upgrading then
  local cfg=util.loadTable(config.clientConfig,{transport='rednet',modem=nil,timeout=config.requestTimeout,wsUrl=nil})
  write('Transport rednet/websocket ['..tostring(cfg.transport or'rednet')..']: ')
  local t=read();if t~=''then cfg.transport=t end
  if cfg.transport~='rednet'and cfg.transport~='websocket'then error('Transport must be rednet or websocket',0)end
  if cfg.transport=='websocket'then write('WebSocket URL ['..tostring(cfg.wsUrl or'')..']: ');local u=read();if u~=''then cfg.wsUrl=u end end
  util.saveTable(config.clientConfig,cfg)
  if cfg.transport=='rednet'then
    print();print('Discovering nearby SpawnNet networks...')
    local found,e=net.discoverNetworks(1.5)
    if found then
      for _,n in ipairs(found)do print('  '..n.id..' - '..n.name..' ['..n.visibility..'] core #'..tostring(n.coreId))end
      if #found==1 then
        net.addNetwork(found[1]);net.setActiveNetwork(found[1].id);print('Auto-selected '..tostring(found[1].name or found[1].id))
      end
    else print('Discovery: '..tostring(e))end
  end
  local reg=net.registry();local active=reg.active or'public'
  write('Default network ['..active..']: ');local chosen=util.safeName(read(),32)
  if chosen~=''then if not reg.networks[chosen]then net.addNetwork({id=chosen,name=chosen})end;net.setActiveNetwork(chosen)end
  local n=net.activeNetwork()
  if n.visibility=='private'and(not n.key or n.key=='')then write('Join code for '..n.name..': ');local key=read('*');net.addNetwork({id=n.id,name=n.name,visibility=n.visibility,coreId=n.coreId,key=key})end
else
  print('Preserved:')
  print('  /spawnnet/client.cfg')
  print('  /spawnnet/networks.db')
  print('  /spawnnet/sessions/*')
  print('  /spawnnet/apps/*')
  print('  /spawnnet/appdata/*')
end
for _,p in ipairs({'/SpawnNet-App-Platform-Client-1.0.0.lua','/SpawnNet-App-Platform-Client-1.0.1.lua','/clienthotfixV1.txt','/spawnnet/client/warehouse_agent.lua','/spawnnet/machines/warehouse.cfg'})do if fs.exists(p)then pcall(fs.delete,p)end end
print();term.setTextColor(colors.lime);print(upgrading and'CLIENT UPGRADE COMPLETE'or'CLIENT INSTALL COMPLETE');term.setTextColor(colors.white)
print('Run: spawnnet')
print('Guest users can click CREATE ACCOUNT directly from the Desktop.')
print('Packages: spawnnet packages')
print('Update later: spawnnet update')
print('Rollback client update: spawnnet update rollback')
