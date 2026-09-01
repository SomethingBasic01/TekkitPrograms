-- SpawnNet 2.1.0 RC6 self-extracting client installer
local files={
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
  ["/spawnnet/client/apps_forum.lua"]=[=[local net=dofile('/spawnnet/client/net.lua')
local auth=dofile('/spawnnet/client/auth_client.lua')
local gui=dofile('/spawnnet/client/gui.lua')

local function login()
  if net.loadSession()then local me=net.call('users','me',{});if me then return true end end
  local u=gui.prompt('FORUM LOGIN','Username:','');if u==''then return false end
  local pw=gui.prompt('FORUM LOGIN','Password:','','*');local s,e=auth.login(u,pw);if not s then gui.toast(e,2);return false end;return true
end

local function threadText(t)
  local out={'POSTED BY '..tostring(t.author),'',tostring(t.body or''),'','------------------------------'}
  for i,r in ipairs(t.replies or{})do out[#out+1]='REPLY '..i..' - '..tostring(r.author);out[#out+1]='';out[#out+1]=tostring(r.body or'');out[#out+1]='';out[#out+1]='------------------------------'end
  return table.concat(out,'\n')
end

local function openThread(board,id)
  while true do
    local p,e=net.call('forum','getThread',{board=board,id=id});if not p then gui.toast(e,2);return end;local t=p.thread
    local m=gui.menu(tostring(t.title),tostring(t.author)..'  |  '..tostring(#(t.replies or{}))..' repl'..(#(t.replies or{})==1 and'y'or'ies'),{{label='Read thread',action='read'},{label='Reply',action='reply',disabled=t.locked},{label='Back',action='back'}})
    if not m or m.action=='back'then return
    elseif m.action=='read'then gui.viewer(tostring(t.title),threadText(t),{meta='Board: '..tostring(board)..'  Thread: '..tostring(t.id)})
    elseif m.action=='reply'then local body=gui.editor('REPLY TO '..tostring(t.title),'');if body~=nil and body~=''then local q,er=net.call('forum','reply',{board=board,id=id,body=body});gui.toast(q and'Reply posted' or er,2)end end
  end
end

local function newThread(board)
  local title=gui.prompt('NEW THREAD','Title:','');if title==''then return end
  local body=gui.editor('NEW THREAD - '..title,'');if body==nil then return end
  local p,e=net.call('forum','newThread',{board=board,title=title,body=body});if p then gui.toast('Thread posted',1);openThread(board,p.thread.id)else gui.toast(e,2)end
end

local function boardView(board,title)
  local selected=1
  while true do
    local p,e=net.call('forum','threads',{board=board,limit=100,offset=0});if not p then gui.toast(e,2);return end
    local items={{label='+ New thread',action='new'}}
    for _,t in ipairs(p.threads or{})do items[#items+1]={label=t.title..'  ['..t.author..']  ('..t.replies..')',thread=t}end
    items[#items+1]={label='Back',action='back'}
    local m,idx=gui.menu('FORUM: '..tostring(title or board),tostring(p.total or 0)..' thread(s)',items,{selected=selected});selected=idx or selected
    if not m or m.action=='back'then return elseif m.action=='new'then newThread(board)elseif m.thread then openThread(board,m.thread.id)end
  end
end

local function search()
  local q=gui.prompt('SEARCH FORUMS','Title, body, or author:','');if q==''then return end
  local p,e=net.call('forum','search',{q=q});if not p then gui.toast(e,2);return end
  local items={};for _,t in ipairs(p.results or{})do items[#items+1]={label='['..t.board..'] '..t.title..' - '..t.author,thread=t}end;items[#items+1]={label='Back',action='back'}
  local m=gui.menu('FORUM SEARCH','Results for: '..q,items);if m and m.thread then openThread(m.thread.board,m.thread.id)end
end

if not login()then return end
while true do
  local p,e=net.call('forum','boards',{});if not p then gui.toast(e,2);return end
  local items={{label='Search all forums',action='search'}}
  for _,b in ipairs(p.boards or{})do items[#items+1]={label=b.title..'  ('..b.count..' threads)',board=b}end
  items[#items+1]={label='Back',action='back'}
  local m=gui.menu('SPAWNNET FORUMS','Choose a board. Lists scroll instead of flooding the terminal.',items,{right=net.activeNetwork().name})
  if not m or m.action=='back'then break elseif m.action=='search'then search()elseif m.board then boardView(m.board.id,m.board.title)end
end
gui.clear()
]=],
  ["/spawnnet/client/apps_keys.lua"]=[=[local net=dofile('/spawnnet/client/net.lua')
local auth=dofile('/spawnnet/client/auth_client.lua')
local gui=dofile('/spawnnet/client/gui.lua')
local util=dofile('/spawnnet/lib/util.lua')
local C=colors

local function login()
  local s=net.loadSession();if s then local me=net.call('users','me',{});if me then return true end end
  local u=gui.prompt('API KEY LOGIN','Username:','');if u==''then return false end
  local pw=gui.prompt('API KEY LOGIN','Password:','','*');local x,e=auth.login(u,pw);if not x then gui.toast(e,2);return false end;return true
end

local presets={
  {label='Telemetry publisher',desc='Push and read telemetry streams',scopes={'telemetry.*'}},
  {label='Machine worker',desc='Claim jobs and publish telemetry',scopes={'jobs.*','telemetry.*'}},
  {label='Site data integration',desc='Site storage, database and web actions',scopes={'storage.*','db.*','web.*'}},
  {label='Mail / event integration',desc='Send mail and use persistent events',scopes={'mail.*','event.*'}},
  {label='Full developer key',desc='All SpawnNet services. Use sparingly.',scopes={'*'}},
  {label='Custom scopes',desc='Choose exact service.action or service.* scopes',custom=true},
}

local function cleanLabel(s)local x=util.safeName(tostring(s or'key'),36);if x==''then x='key'end;return x end
local function showNewKey(k,scopes)
  while true do
    local text='KEY ID\n'..tostring(k.id)..'\n\nSECRET - SHOWN ONCE\n'..tostring(k.secret)..'\n\nSCOPES\n'..table.concat(scopes or{},'\n')..'\n\nTreat this secret like a password. Revoking the key immediately invalidates it.'
    local m=gui.menu('NEW API KEY','The secret will not be available from SpawnNet again.',{
      {label='View credentials',action='view'},
      {label='Save credentials on this computer',action='save'},
      {label='Done - I stored the secret',action='done'}},{right='ONE-TIME SECRET'})
    if not m or m.action=='done'then return
    elseif m.action=='view'then gui.viewer('API KEY CREDENTIALS',text,{meta=tostring(k.label or'API key')})
    elseif m.action=='save'then
      util.ensureDir('/spawnnet/keys');local path='/spawnnet/keys/'..cleanLabel(k.label)..'.key'
      if fs.exists(path)and not gui.confirm('OVERWRITE KEY FILE','A local key file already exists. Replace it?')then
      else util.saveTable(path,{id=k.id,secret=k.secret,label=k.label,scopes=scopes,network=net.activeNetwork().id});gui.toast('Saved locally: '..path,2)end
    end
  end
end

local function createKey()
  local m=gui.menu('CREATE API KEY','Start with the smallest permissions the program needs.',presets)
  if not m then return end
  local scopes=m.scopes
  if m.custom then
    local raw=gui.editor('CUSTOM API SCOPES','telemetry.*\njobs.poll\njobs.claim')
    if raw==nil then return end;scopes={};for line in (raw..'\n'):gmatch('(.-)\n')do line=util.trim(line);if line~=''then scopes[#scopes+1]=line end end
    if #scopes==0 then gui.toast('At least one scope is required',2);return end
  end
  local label=gui.prompt('CREATE API KEY','Label:','Developer key')
  if label==''then return end
  local summary='Label: '..label..'\nScopes:\n  '..table.concat(scopes,'\n  ')
  if not gui.confirm('CREATE API KEY',summary..'\n\nCreate this credential?')then return end
  local k,e=auth.createKey(label,scopes);if not k then gui.toast(e,2);return end;k.label=label;showNewKey(k,scopes)
end

local function keyDetail(k)
  while true do
    local state=k.revoked and'REVOKED'or'ACTIVE'
    local m=gui.menu('KEY: '..tostring(k.label),state..'  |  '..tostring(k.id),{
      {label='View permissions / metadata',action='view'},
      {label='Revoke key permanently',action='revoke',disabled=k.revoked},
      {label='Back',action='back'}},{right=state})
    if not m or m.action=='back'then return
    elseif m.action=='view'then
      gui.viewer('API KEY DETAILS','ID: '..tostring(k.id)..'\nLabel: '..tostring(k.label)..'\nStatus: '..state..'\nCreated: '..tostring(k.created or'?')..'\n\nScopes:\n  '..table.concat(k.scopes or{},'\n  '),{meta='Secret is never returned after creation'})
    elseif m.action=='revoke'then
      if gui.confirm('REVOKE API KEY','Programs using this key will immediately lose access. Continue?')then local p,e=net.call('auth','revokeKey',{id=k.id});if p then k.revoked=true;gui.toast('Key revoked',1)else gui.toast(e,2)end end
    end
  end
end

if not login()then return end
while true do
  local p,e=net.call('auth','listKeys',{});if not p then gui.toast(e,2);return end
  table.sort(p.keys or{},function(a,b)return tostring(a.label)<tostring(b.label)end)
  local active,revoked=0,0;local items={{label='+ Create scoped API key',action='create'}}
  for _,k in ipairs(p.keys or{})do if k.revoked then revoked=revoked+1 else active=active+1 end;items[#items+1]={label=(k.revoked and'REVOKED  'or'ACTIVE   ')..tostring(k.label)..'  ['..tostring(k.id)..']',key=k}end
  items[#items+1]={label='Open API Explorer',action='api'};items[#items+1]={label='Back',action='back'}
  local m=gui.menu('API CREDENTIALS','Scoped keys let trusted computers authenticate without your account password.  Active '..active..' / Revoked '..revoked,items,{right=net.loadSession()and net.loadSession().user or''})
  if not m or m.action=='back'then break elseif m.action=='create'then createKey()elseif m.action=='api'then shell.run('/spawnnet/client/dev_api.lua')elseif m.key then keyDetail(m.key)end
end
gui.clear()
]=],
  ["/spawnnet/client/apps_mail.lua"]=[=[local net=dofile('/spawnnet/client/net.lua')
local auth=dofile('/spawnnet/client/auth_client.lua')
local gui=dofile('/spawnnet/client/gui.lua')

local function login()
  if net.loadSession()then local me=net.call('users','me',{});if me then return true end end
  local u=gui.prompt('MAIL LOGIN','Username:','');if u==''then return false end
  local pw=gui.prompt('MAIL LOGIN','Password:','','*');local s,e=auth.login(u,pw);if not s then gui.toast(e,2);return false end;return true
end

local function compose(replyTo,replySubject)
  local to=gui.prompt('COMPOSE MAIL','To:',replyTo or'');if to==''then return end
  local subject=gui.prompt('COMPOSE MAIL','Subject:',replySubject or'');local body=gui.editor('MESSAGE BODY','')
  if body==nil then return end
  if body==''and not gui.confirm('SEND EMPTY MESSAGE','The message body is empty. Send anyway?')then return end
  local p,e=net.call('mail','send',{to=to,subject=subject,body=body});gui.toast(p and'Message sent' or e,2)
end

local function viewMessage(m,sent)
  if not sent and not m.read then net.call('mail','read',{id=m.id});m.read=true end
  local meta=(sent and('To: '..tostring(m.to))or('From: '..tostring(m.from)))..'  |  '..tostring(m.id or'')
  while true do
    local choice=gui.menu(tostring(m.subject or'(no subject)'),meta,{{label='Read message',action='read'},{label='Reply',action='reply',disabled=sent and false or false},{label='Delete from inbox',action='delete',disabled=sent},{label='Back',action='back'}})
    if not choice or choice.action=='back'then return
    elseif choice.action=='read'then gui.viewer(tostring(m.subject or'(no subject)'),m.body or'',{meta=meta})
    elseif choice.action=='reply'then local sub=tostring(m.subject or'');if sub:sub(1,3):lower()~='re:'then sub='Re: '..sub end;compose(sent and m.to or m.from,sub)
    elseif choice.action=='delete'then if gui.confirm('DELETE MESSAGE','Delete this message from your inbox?')then local p,e=net.call('mail','delete',{id=m.id});gui.toast(p and'Deleted' or e,1);return end end
  end
end

local function folder(kind)
  local selected=1
  while true do
    local action=kind=='sent'and'sent'or'inbox';local p,e=net.call('mail',action,{limit=100,offset=0});if not p then gui.toast(e,2);return end
    local items={}
    for _,m in ipairs(p.messages or{})do
      local mark=(not kind=='sent'and not m.read)and'* 'or''
      if kind=='sent'then items[#items+1]={label='To '..tostring(m.to)..' | '..tostring(m.subject or'(no subject)'),message=m}
      else items[#items+1]={label=(m.read and'  'or'* ')..tostring(m.from)..' | '..tostring(m.subject or'(no subject)'),message=m}end
    end
    items[#items+1]={label='Back',action='back'}
    local subtitle=(kind=='sent'and('Sent: '..tostring(p.total or#items))or('Inbox: '..tostring(p.total or 0)..'  Unread: '..tostring(p.unread or 0)))
    local m,idx=gui.menu(kind=='sent'and'SENT MAIL'or'INBOX',subtitle,items,{selected=selected})
    selected=idx or selected
    if not m or m.action=='back'then return elseif m.message then viewMessage(m.message,kind=='sent')end
  end
end

if not login()then return end
while true do
  local count=net.call('mail','unreadCount',{});local unread=count and count.count or 0
  local m=gui.menu('SPAWNNET MAIL','Persistent mail on '..tostring(net.activeNetwork().name),{{label='Inbox ('..tostring(unread)..' unread)',action='inbox'},{label='Compose',action='compose'},{label='Sent mail',action='sent'},{label='Back',action='back'}},{right=net.loadSession()and net.loadSession().user or'Guest'})
  if not m or m.action=='back'then break elseif m.action=='inbox'then folder('inbox')elseif m.action=='sent'then folder('sent')elseif m.action=='compose'then compose()end
end
gui.clear()
]=],
  ["/spawnnet/client/asset_manager.lua"]=[=[local gui=dofile('/spawnnet/client/gui.lua')
local net=dofile('/spawnnet/client/net.lua')
local util=dofile('/spawnnet/lib/util.lua')
local C=colors
local M={}

local function totalSize(list)local n=0;for _,a in ipairs(list or{})do n=n+(tonumber(a.size)or 0)end;return n end
local function mimeChoice(current)
  local m=gui.menu('ASSET TYPE','Choose a common type or enter one manually.',{
    {label='NFP image  (image/nfp)',mime='image/nfp'},
    {label='Plain text  (text/plain)',mime='text/plain'},
    {label='SpawnNet data  (application/spawnnet)',mime='application/spawnnet'},
    {label='Binary / opaque  (application/octet-stream)',mime='application/octet-stream'},
    {label='Custom MIME type',custom=true},
    {label='Cancel',cancel=true}})
  if not m or m.cancel then return nil end
  if m.custom then return gui.prompt('CUSTOM TYPE','MIME type:',current or'application/octet-stream') end
  return m.mime
end

local function previewNfp(domain,a)
  local p,e=net.call('web','getAsset',{domain=domain,name=a.name},{noAuth=true});if not p then gui.toast(e,2);return end
  util.ensureDir('/spawnnet/tmp');local path='/spawnnet/tmp/asset-preview.nfp';util.writeFile(path,p.data or'')
  local ok,img=pcall(paintutils.loadImage,path);if not ok or not img then gui.toast('NFP image could not be decoded',2);return end
  local w,h=term.getSize();gui.clear();gui.bar('IMAGE PREVIEW',a.name)
  term.setBackgroundColor(C.black);term.setTextColor(C.white)
  local okDraw,err=pcall(paintutils.drawImage,img,2,3)
  if not okDraw then gui.toast(err,2);return end
  gui.status('Preview only   Press any key to return');os.pullEvent('key')
end

local function inspect(domain,a)
  while true do
    local m=gui.menu('ASSET: '..a.name,tostring(a.mime or'?')..'  |  '..tostring(a.size or 0)..' bytes',{
      {label='Preview',action='preview'},
      {label='View metadata / asset name',action='meta'},
      {label='Delete asset',action='delete'},
      {label='Back',action='back'}})
    if not m or m.action=='back'then return false
    elseif m.action=='preview'then
      if tostring(a.mime)=='image/nfp'then previewNfp(domain,a)
      else local p,e=net.call('web','getAsset',{domain=domain,name=a.name},{noAuth=true});if not p then gui.toast(e,2)else gui.viewer('ASSET PREVIEW',tostring(p.data or''),{meta=tostring(a.mime or'unknown')})end end
    elseif m.action=='meta'then gui.viewer('ASSET METADATA','Name: '..a.name..'\nMIME: '..tostring(a.mime or'?')..'\nSize: '..tostring(a.size or 0)..' bytes\n\nUse this exact name as the src field for image elements.',{meta='spn://'..domain})
    elseif m.action=='delete'then
      if gui.confirm('DELETE ASSET','Delete '..a.name..' from the site? Existing pages that reference it will no longer render it.')then local p,e=net.call('web','deleteAsset',{domain=domain,name=a.name});gui.toast(p and'Deleted' or e,2);return p and true or false end
    end
  end
end

local function upload(domain)
  local path=gui.prompt('UPLOAD ASSET','Local file path:','');if path==''then return end
  if not fs.exists(path)or fs.isDir(path)then gui.toast('File not found',2);return end
  local size=fs.getSize(path);local name=gui.prompt('UPLOAD ASSET','Asset name:',fs.getName(path));if name==''then return end
  local mime=mimeChoice('image/nfp');if not mime or mime==''then return end
  if not gui.confirm('UPLOAD ASSET','Name: '..name..'\nType: '..mime..'\nSize: '..tostring(size)..' bytes\n\nUpload to spn://'..domain..'?')then return end
  local p,e=net.call('web','putAsset',{domain=domain,name=name,mime=mime,data=util.readFile(path)});gui.toast(p and('Uploaded '..name)or e,2)
end

function M.run(domain)
  while true do
    local p,e=net.call('web','listAssets',{domain=domain});if not p then gui.toast(e,2);return end
    table.sort(p.assets or{},function(a,b)return tostring(a.name)<tostring(b.name)end)
    local items={{label='+ Upload local file',action='upload'}}
    for _,a in ipairs(p.assets or{})do items[#items+1]={label=tostring(a.name)..'  |  '..tostring(a.mime or'?')..'  |  '..tostring(a.size or 0)..'b',asset=a}end
    items[#items+1]={label='Back',action='back'}
    local m=gui.menu('SITE ASSETS','Files '..tostring(#(p.assets or{}))..'  |  Total '..tostring(totalSize(p.assets))..' bytes  |  spn://'..domain,items)
    if not m or m.action=='back'then return elseif m.action=='upload'then upload(domain)elseif m.asset then inspect(domain,m.asset)end
  end
end

function M.choose(domain)
  while true do
    local p,e=net.call('web','listAssets',{domain=domain});if not p then gui.toast(e,2);return nil end
    table.sort(p.assets or{},function(a,b)return tostring(a.name)<tostring(b.name)end)
    local items={};for _,a in ipairs(p.assets or{})do items[#items+1]={label=tostring(a.name)..'  ['..tostring(a.mime or'?')..']',asset=a}end
    items[#items+1]={label='+ Upload an asset',upload=true};items[#items+1]={label='Cancel',cancel=true}
    local m=gui.menu('CHOOSE ASSET','Select an existing site file.',items)
    if not m or m.cancel then return nil elseif m.upload then upload(domain)else return m.asset and m.asset.name end
  end
end
return M
]=],
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
local gui=dofile('/spawnnet/client/gui.lua')

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
  if method=='ui.setText'or method=='ui.setValue'or method=='ui.setVisible'or method=='ui.setItems'or method=='ui.setRows'or method=='ui.setProgress'or method=='ui.setSelected'then renderer.applyPatch(page,inputs,{method=method,args=args});return true
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
  local q=gui.prompt('SPAWNNET SEARCH','Search this network:','');if q==''then return end
  local p,er=net.call('search','query',{q=q},{noAuth=true});if p then
    local elements={{type='heading',x=2,y=1,w=47,text='Search: '..q,align='left'}};local y=3
    for _,r in ipairs(p.results or{})do elements[#elements+1]={type='button',x=2,y=y,w=47,text=(r.domain..' - '..r.title):sub(1,45),action={type='navigate',target='spn://'..r.domain}};y=y+2 end
    if #(p.results or{})==0 then elements[#elements+1]={type='text',x=2,y=4,w=47,h=2,text='No results found.'}end
    page={title='Search',background=colors.black,elements=elements};domain='search';path='/results';address='spn://search?q='..q;clientScript='';inputs={};scroll=0;scheduleLive();status=tostring(#(p.results or{}))..' result(s)'
  else status=er end
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
  elseif a.type=='search'then search()
  elseif a.type=='lab'then
    if domain~='wiki'then status='Built-in labs can only be launched from spn://wiki'
    else
      local demo=tostring(a.demo or a.name or'')
      local allowed={chest=true,mail=true,peripheral=true,network=true,game=true,canvas=true,vault=true}
      if not allowed[demo]then status='Unknown built-in lab: '..demo
      else shell.run('/spawnnet/client/labs.lua',demo);status='Returned from lab: '..demo end
    end
  end
end
local function draw()
  local sw,sh=term.getSize();local n=net.activeNetwork()
  term.setBackgroundColor(colors.gray);term.setTextColor(colors.white);term.setCursorPos(1,1);term.clearLine()
  local controls=' <  >  R  H  G  S  P  N ';write(controls:sub(1,sw))
  if sw>#controls+2 then term.setCursorPos(#controls+2,1);term.setTextColor(colors.lightGray);write(gui.clip(tostring(n.name or n.id),sw-#controls-2))end
  term.setCursorPos(1,2);term.setBackgroundColor(colors.lightGray);term.setTextColor(colors.black);term.clearLine();write(gui.clip(' '..address,sw))
  term.setBackgroundColor(colors.black);term.setTextColor(colors.white)
  if page then hits,maxScroll=renderer.draw(page,{top=3,bottom=sh-1,scroll=scroll,inputs=inputs,values=values,assetLoader=loadAsset})else for y=3,sh-1 do term.setCursorPos(1,y);term.clearLine()end end
  gui.status((status or'')..'  |  Scroll '..tostring(scroll)..'/'..tostring(maxScroll)..'  |  Q exit')
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
      if x<=3 and histPos>1 then histPos=histPos-1;loadAddress(history[histPos],false)
      elseif x<=6 and histPos<#history then histPos=histPos+1;loadAddress(history[histPos],false)
      elseif x<=9 then loadAddress(address,false)
      elseif x<=12 then loadAddress(config.defaultHome,true)
      elseif x<=15 then local a=gui.prompt('GO TO ADDRESS','SpawnNet address:',address);if a~=''then loadAddress(a,true)end
      elseif x<=18 then search()
      elseif x<=21 then pinCurrent()
      elseif x<=24 then shell.run('/spawnnet/client/networks.lua');loadAddress(config.defaultHome,true) end
    elseif y==2 then local a=gui.prompt('GO TO ADDRESS','SpawnNet address:',address);if a~=''then loadAddress(a,true)end
    else local h=renderer.hit(hits,x,y);if h then local e=h.element;if h.kind=='button'then handleAction(e)elseif h.kind=='input'then inputs[e.id]=gui.prompt('PAGE INPUT',e.label or e.placeholder or e.id or'Input',tostring(inputs[e.id]or e.value or''))elseif h.kind=='checkbox'then inputs[e.id]=not(inputs[e.id]==nil and e.checked or inputs[e.id])elseif h.kind=='select'then local opts=e.options or{};local cur=inputs[e.id]or e.value or opts[1];local idx=1;for i,v in ipairs(opts)do if v==cur then idx=i end end;if #opts>0 then inputs[e.id]=opts[(idx%#opts)+1]end elseif h.kind=='tab'then e.selected=h.tab end end end
  elseif name=='key'then local k=ev[2];if k==keys.q then break elseif k==keys.up then scroll=math.max(0,scroll-1)elseif k==keys.down then scroll=math.min(maxScroll,scroll+1)elseif k==keys.r then loadAddress(address,false)elseif k==keys.h then loadAddress(config.defaultHome,true)elseif k==keys.g then local a=gui.prompt('GO TO ADDRESS','SpawnNet address:',address);if a~=''then loadAddress(a,true)end elseif k==keys.s then search()elseif k==keys.p then pinCurrent()elseif k==keys.n then shell.run('/spawnnet/client/networks.lua');loadAddress(config.defaultHome,true)end
  end
end
term.setBackgroundColor(colors.black);term.setTextColor(colors.white);term.clear();term.setCursorPos(1,1)
]=],
  ["/spawnnet/client/desktop.lua"]=[=[local gui=dofile('/spawnnet/client/gui.lua')
local net=dofile('/spawnnet/client/net.lua')
local auth=dofile('/spawnnet/client/auth_client.lua')
local config=dofile('/spawnnet/lib/config.lua')

local function run(path,...)shell.run(path,...)end
local function session()return net.loadSession()end
local function accountMenu()
  local s=session()
  if s then
    local m=gui.menu('ACCOUNT',s.user..' on '..tostring(net.activeNetwork().name),{{label='Stay signed in',action='back'},{label='Sign out',action='logout'}})
    if m and m.action=='logout'then auth.logout();gui.toast('Signed out',1)end
  else
    local m=gui.menu('WELCOME TO SPAWNNET','Sign in for mail, websites and private data. Browsing public sites works as Guest.',{{label='Sign in',action='login'},{label='Create account',action='register'},{label='Continue as Guest',action='back'}})
    if m and(m.action=='login'or m.action=='register')then
      local u=gui.prompt(m.action=='register'and'CREATE ACCOUNT'or'SIGN IN','Username:','');if u==''then return end
      local pw=gui.prompt(m.action=='register'and'CREATE ACCOUNT'or'SIGN IN','Password:','','*')
      local x,e;if m.action=='register'then x,e=auth.register(u,pw,u)else x,e=auth.login(u,pw)end
      gui.toast(x and('Signed in as '..x.user)or e,2)
    end
  end
end

if session()then local me=net.call('users','me',{});if not me then net.setSession(nil)end end
while true do
  local n=net.activeNetwork();local s=session();local w,h=term.getSize();gui.clear();gui.bar('SPAWNNET '..config.version,tostring(n.name or n.id))
  gui.text(2,3,w-2,'Websites, communication, labs and network tools',colors.lightGray,colors.black,'center')
  local regions={};local buttons={
    {'BROWSER','/spawnnet/client/browser.lua','spn://home',colors.blue},
    {'STUDIO','/spawnnet/client/studio_easy.lua',nil,colors.purple},
    {'LABS','/spawnnet/client/labs.lua',nil,colors.lime},
    {'MAIL','/spawnnet/client/apps_mail.lua',nil,colors.cyan},
    {'FORUMS','/spawnnet/client/apps_forum.lua',nil,colors.orange},
    {'APPS','/spawnnet/client/apps.lua',nil,colors.green},
    {'NETWORKS','/spawnnet/client/networks.lua',nil,colors.blue},
    {'SEARCH','search',nil,colors.cyan},
    {'DEV TOOLS','/spawnnet/client/developer.lua',nil,colors.purple},
    {s and('USER: '..s.user)or'ACCOUNT','account',nil,s and colors.green or colors.gray},
  }
  local cols=w>=48 and 3 or 2;local gap=1;local bw=math.floor((w-(cols+1)*gap)/cols);local y0=5;local rowGap=3
  for i,b in ipairs(buttons)do local col=((i-1)%cols);local row=math.floor((i-1)/cols);local x=gap+1+col*(bw+gap);local y=y0+row*rowGap;if y<h then local r=gui.button(x,y,bw,b[1],true,b[4]);r.index=i;regions[#regions+1]=r end end
  local user=s and s.user or'Guest';gui.status(user..'  |  '..tostring(n.id)..'  |  Mouse to open  |  Q quits')
  local ev={os.pullEvent()}
  if ev[1]=='key'and(ev[2]==keys.q or ev[2]==keys.escape)then break
  elseif ev[1]=='mouse_click'then local r=gui.hit(regions,ev[3],ev[4]);if r then local b=buttons[r.index]
    if b[2]=='search'then local q=gui.prompt('SEARCH','Search '..tostring(n.name)..':','');if q~=''then run('/spawnnet/client/search.lua',q)end
    elseif b[2]=='account'then accountMenu()
    else run(b[2],b[3])end
  end end
end
gui.clear()
]=],
  ["/spawnnet/client/dev_api.lua"]=[==[local gui=dofile('/spawnnet/client/gui.lua')
local net=dofile('/spawnnet/client/net.lua')
local C=colors

local docs={
 {label='SDK quickstart',title='SDK QUICKSTART',body=[=[local sn = dofile('/spawnnet/client/sdk.lua')

-- The SDK uses the active SpawnNet network and current session.
local me = sn.call('users','me',{})
print(me.user)

-- Site APIs are namespaced by domain.
local value = sn.storage.get('mysite','status')

-- For unattended computers, create a scoped API key and use auth_client.apiLogin.]=]},
 {label='Web / sites',title='WEB API',body=[=[sn.web.get(domain,path)
sn.web.action(domain,event,input,args)
sn.web.analytics(domain)

Common raw calls:
web.getPage        public read
web.runAction      invoke hosted server event
web.savePage       site owner
web.saveScripts    site owner
web.publish        site owner
web.history        site owner
web.restore        site owner
web.listAssets     site owner
web.putAsset       site owner
web.getAsset       public read]=]},
 {label='Storage / database / blobs',title='DATA APIS',body=[=[sn.storage.get(domain,key)
sn.storage.set(domain,key,value)
sn.storage.inc(domain,key,amount)

sn.db.get(domain,collection,key)
sn.db.set(domain,collection,key,value)
sn.db.insert(domain,collection,value)
sn.db.list(domain,collection,limit)

sn.blob.put(domain,key,data,mime,public)
sn.blob.get(domain,key)
sn.blob.list(domain)
sn.blob.delete(domain,key)

Use Storage for small named values, DB for records, and Blob for larger opaque data.]=]},
 {label='Jobs',title='JOBS API',body=[=[local sn=dofile('/spawnnet/client/sdk.lua')

-- Website/server code submits work.
local j=sn.jobs.submit('factory','production','craft',{item='circuit',count=64})

-- A trusted player-written worker polls it.
local q=sn.jobs.poll('factory','production',10)
for _,job in ipairs(q.jobs or {}) do
  sn.jobs.claim('factory',job.id,'worker-1')
  -- YOUR peripheral / machine code here.
  sn.jobs.progress('factory',job.id,50,'Halfway')
  sn.jobs.complete('factory',job.id,{made=64},'Done')
end

SpawnNet intentionally does not ship a warehouse worker. Jobs are generic infrastructure.]=]},
 {label='Telemetry',title='TELEMETRY API',body=[=[sn.telemetry.push(domain,stream,data)
sn.telemetry.get(domain,stream,limit)
sn.telemetry.last(domain,stream)

Example:
sn.telemetry.push('powerco','reactor1',{
  online=true,
  temperature=peripheral.call('left','getTemperature'),
  output=peripheral.call('left','getEnergyProducedLastTick')
})

Use Peripheral Lab to discover the methods your actual modpack exposes.]=]},
 {label='Mail / events',title='COMMUNICATION APIS',body=[=[sn.mail.send(to,subject,body)
sn.mail.inbox(limit,offset)
sn.mail.sent(limit,offset)

sn.events.emit(to,type,data)
sn.events.poll(limit)
sn.events.peek()

Events are durable until polled and are useful for asynchronous workflows. Mail is user-facing communication.]=]},
 {label='Networks / nodes',title='NETWORK APIS',body=[=[sn.network.active()
sn.network.list()
sn.network.discover(timeout)
sn.network.switch(id)

sn.nodes.summary()
sn.nodes.approve(id,name)
sn.nodes.rebalance()
sn.nodes.remove(id)

Node management requires appropriate admin authorization. Networks are isolated by network ID and protocol.]=]},
}

local function requestLab()
  local service=gui.prompt('REQUEST LAB','Service:','auth');if service==''then return end
  local action=gui.prompt('REQUEST LAB','Action:','ping');if action==''then return end
  local raw=gui.editor('REQUEST PAYLOAD','{}');if raw==nil then return end
  local payload=textutils.unserialize(raw);if type(payload)~='table'then gui.toast('Payload must be a serialized Lua table, e.g. {}',2);return end
  local noAuth=gui.confirm('REQUEST AUTH','Send without account/API authentication?\n\nChoose YES for public endpoints such as auth.ping.')
  local p,e,r=net.call(service,action,payload,noAuth and{noAuth=true}or nil)
  local body
  if p then body='STATUS: '..tostring(r and r.status or 200)..'\n\n'..textutils.serialize(p)
  else body='ERROR\n'..tostring(e)..'\n\nRaw response:\n'..textutils.serialize(r or{}) end
  gui.viewer('REQUEST RESULT',body,{meta=service..'.'..action})
end

while true do
  local items={{label='LIVE REQUEST LAB - call a service now',action='lab'}}
  for _,d in ipairs(docs)do items[#items+1]={label=d.label,doc=d}end
  items[#items+1]={label='API credentials',action='keys'}
  items[#items+1]={label='Peripheral Lab',action='periph'}
  items[#items+1]={label='Open full API manual on Wiki',action='wiki'}
  items[#items+1]={label='Back',action='back'}
  local m=gui.menu('API EXPLORER','Reference, examples and a live request console for advanced users.',items,{right=net.activeNetwork().name})
  if not m or m.action=='back'then break elseif m.action=='lab'then requestLab()elseif m.doc then gui.viewer(m.doc.title,m.doc.body,{meta='SpawnNet SDK'})elseif m.action=='keys'then shell.run('/spawnnet/client/apps_keys.lua')elseif m.action=='periph'then shell.run('/spawnnet/client/dev_peripherals.lua')elseif m.action=='wiki'then shell.run('/spawnnet/client/browser.lua','spn://wiki/api')end
end
gui.clear()
]==],
  ["/spawnnet/client/dev_network.lua"]=[=[local gui=dofile('/spawnnet/client/gui.lua')
local net=dofile('/spawnnet/client/net.lua')
local config=dofile('/spawnnet/lib/config.lua')

local function snapshot()
  local n=net.activeNetwork();local modem,me=net.open();local core,ce=net.discover(false);local ping,pe
  if core then ping,pe=net.call('auth','ping',{}, {noAuth=true})end
  local s=net.loadSession()
  local lines={
    'ACTIVE NETWORK',
    'Name: '..tostring(n.name),
    'ID: '..tostring(n.id),
    'Visibility: '..tostring(n.visibility or'?'),
    '',
    'ROUTING',
    'Core ID: '..tostring(core or n.coreId or'?'),
    'Client protocol: '..tostring(n.protocol or net.protocolFor(n.id)),
    'Discovery protocol: '..tostring(config.discoveryProtocol),
    'Modem: '..tostring(modem or('ERROR '..tostring(me))),
    '',
    'SESSION',
    s and('User: '..tostring(s.user))or'Guest / no authenticated session',
    s and('Session: '..tostring(s.id))or'',
    s and('Sequence: '..tostring(s.seq or 0))or'',
    '',
    'CORE HEALTH',
    ping and('Ping: OK - server '..tostring(ping.version))or('Ping: FAIL - '..tostring(pe or ce or'unknown')),
    '',
    'LOCAL COMPUTER',
    'Computer ID: '..tostring(os.getComputerID()),
    'Client version: '..tostring(config.version),
  }
  return table.concat(lines,'\n')
end

while true do
  local n=net.activeNetwork();local m=gui.menu('NETWORK LAB','Inspect the active network without editing config files.',{
    {label='Live network snapshot',action='snap'},
    {label='Discover nearby SpawnNet networks',action='discover'},
    {label='Open Network Manager',action='manager'},
    {label='Protocol / packet reference',action='proto'},
    {label='Back',action='back'}},{right=tostring(n.id)})
  if not m or m.action=='back'then break
  elseif m.action=='snap'then gui.viewer('NETWORK SNAPSHOT',snapshot(),{meta=tostring(n.name)})
  elseif m.action=='discover'then local found,e=net.discoverNetworks(1.5);if not found then gui.toast(e,2)else local lines={};for _,x in ipairs(found)do lines[#lines+1]=tostring(x.name)..' ['..tostring(x.id)..']  core #'..tostring(x.coreId)..'  '..tostring(x.visibility)end;if #lines==0 then lines={'No networks answered discovery.'}end;gui.viewer('DISCOVERY RESULTS',table.concat(lines,'\n'),{meta=tostring(#found)..' network(s)'})end
  elseif m.action=='manager'then shell.run('/spawnnet/client/networks.lua')
  elseif m.action=='proto'then gui.viewer('PROTOCOL MODEL','Discovery uses one shared protocol:\n  '..tostring(config.discoveryProtocol)..'\n\nEach network then uses an isolated client protocol:\n  spawnnet:<network-id>:v2\n\nand an isolated storage backbone:\n  spawnnet:backbone:<network-id>:v2\n\nRequests include networkId, requestId, service, action, payload and optional signed authentication. Large logical packets are fragmented and reassembled by SpawnNet wire transport.',{meta='SpawnNet v2'}) end
end
gui.clear()
]=],
  ["/spawnnet/client/dev_peripherals.lua"]=[=[local gui=dofile('/spawnnet/client/gui.lua')
local util=dofile('/spawnnet/lib/util.lua')

local function valText(v)
  if type(v)=='table'then local ok,s=pcall(textutils.serialize,v);return ok and s or'<table>' end
  return tostring(v)
end

local function callMethod(name,method)
  local raw=gui.editor('CALL '..method,'{}');if raw==nil then return end
  local args=textutils.unserialize(raw);if type(args)~='table'then gui.toast('Arguments must be a serialized Lua table, e.g. {} or {64}',2);return end
  local result={pcall(peripheral.call,name,method,unpack(args))};local ok=table.remove(result,1)
  if not ok then gui.viewer('CALL FAILED',tostring(result[1]),{meta=name..'.'..method});return end
  local lines={'Returned '..tostring(#result)..' value(s):',''};for i,v in ipairs(result)do lines[#lines+1]=tostring(i)..': '..valText(v)end
  gui.viewer('METHOD RESULT',table.concat(lines,'\n'),{meta=name..'.'..method})
end

local function inspect(name)
  while peripheral.isPresent(name)do
    local methods=peripheral.getMethods(name)or{};table.sort(methods)
    local items={{label='Overview / type',action='overview'}};for _,m in ipairs(methods)do items[#items+1]={label=m,method=m}end;items[#items+1]={label='Back',action='back'}
    local m=gui.menu('PERIPHERAL: '..name,tostring(peripheral.getType(name))..'  |  '..tostring(#methods)..' method(s)',items)
    if not m or m.action=='back'then return elseif m.action=='overview'then gui.viewer('PERIPHERAL OVERVIEW','Name: '..name..'\nType: '..tostring(peripheral.getType(name))..'\n\nMethods:\n  '..table.concat(methods,'\n  '),{meta='Use a method entry to test it'})elseif m.method then
      local x=gui.menu('METHOD: '..m.method,'Call this real peripheral method from the current computer.',{{label='Call with arguments',action='call'},{label='View API pattern',action='help'},{label='Back',action='back'}})
      if x and x.action=='call'then callMethod(name,m.method)elseif x and x.action=='help'then gui.viewer('PERIPHERAL CALL','Direct Lua:\nperipheral.call("'..name..'","'..m.method..'", ...)\n\nWrapped:\nlocal p=peripheral.wrap("'..name..'")\np.'..m.method..'( ... )\n\nUse this with the SpawnNet Jobs and Telemetry APIs to build your own machine integrations.')end
    end
  end
  gui.toast('Peripheral disconnected',1)
end

while true do
  local names=peripheral.getNames();table.sort(names);local items={}
  for _,n in ipairs(names)do items[#items+1]={label=n..'  ['..tostring(peripheral.getType(n))..']',name=n}end
  if #names==0 then items[#items+1]={label='No peripherals detected',disabled=true}end
  items[#items+1]={label='Refresh',action='refresh'};items[#items+1]={label='Open Jobs API guide',action='jobs'};items[#items+1]={label='Back',action='back'}
  local m=gui.menu('PERIPHERAL LAB','Discover what this modpack actually exposes. SpawnNet does not assume a specific storage or machine mod.',items,{right=tostring(#names)..' attached'})
  if not m or m.action=='back'then break elseif m.name then inspect(m.name)elseif m.action=='jobs'then shell.run('/spawnnet/client/dev_api.lua')end
end
gui.clear()
]=],
  ["/spawnnet/client/developer.lua"]=[=[local gui=dofile('/spawnnet/client/gui.lua')
local net=dofile('/spawnnet/client/net.lua')
local config=dofile('/spawnnet/lib/config.lua')
local C=colors

local tools={
  {title='ADVANCED STUDIO',desc='Freeform pages, scripts, assets and revisions',path='/spawnnet/client/studio_advanced.lua',accent=C.purple},
  {title='API EXPLORER',desc='SDK reference plus a live request laboratory',path='/spawnnet/client/dev_api.lua',accent=C.cyan},
  {title='API KEYS',desc='Create scoped credentials for trusted computers',path='/spawnnet/client/apps_keys.lua',accent=C.orange},
  {title='PERIPHERAL LAB',desc='Discover devices, methods and test real calls',path='/spawnnet/client/dev_peripherals.lua',accent=C.green},
  {title='NETWORK LAB',desc='Core, protocol, discovery and session inspection',path='/spawnnet/client/dev_network.lua',accent=C.blue},
  {title='DIAGNOSTICS',desc='Run connection and client health checks',path='/spawnnet/client/doctor.lua',accent=C.red},
  {title='API WIKI',desc='Open the complete SpawnNet developer manual',url='spn://wiki/api',accent=C.lightBlue},
  {title='LUA SHELL',desc='Drop to CraftOS Lua for unrestricted local work',shell=true,accent=C.gray},
}

local selected=1
local function draw()
  local w,h=term.getSize();gui.clear();local n=net.activeNetwork();gui.bar('DEVELOPER WORKBENCH',tostring(n.name or n.id))
  gui.text(2,3,w-2,'Build, inspect and test. Nothing here is required for normal browsing.',C.lightGray,C.black,'center')
  local cols=w>=46 and 2 or 1;local gap=1;local cardW=math.floor((w-(cols+1)*gap)/cols);local cardH=3;local startY=4;local regions={}
  for i,t in ipairs(tools)do
    local col=(i-1)%cols;local row=math.floor((i-1)/cols);local x=gap+1+col*(cardW+gap);local y=startY+row*(cardH+1)
    if y+cardH-1<h then
      local active=i==selected;local bg=active and C.gray or C.black
      gui.box(x,y,cardW,cardH,nil,bg)
      gui.text(x+1,y+1,cardW-2,t.title,active and C.white or t.accent,bg,'left')
      gui.text(x+1,y+2,cardW-2,t.desc,C.lightGray,bg,'left')
      regions[#regions+1]={x1=x,y1=y,x2=x+cardW-1,y2=y+cardH-1,index=i}
    end
  end
  gui.status('Arrows / mouse select   Enter open   Q back   '..config.version)
  return regions,cols
end

while true do
  local regions,cols=draw();local ev={os.pullEvent()}
  if ev[1]=='key'then local k=ev[2]
    if k==keys.q or k==keys.escape then break
    elseif k==keys.left then selected=math.max(1,selected-1)
    elseif k==keys.right then selected=math.min(#tools,selected+1)
    elseif k==keys.up then selected=math.max(1,selected-cols)
    elseif k==keys.down then selected=math.min(#tools,selected+cols)
    elseif k==keys.enter then
      local t=tools[selected]
      if t.shell then shell.run('shell') elseif t.url then shell.run('/spawnnet/client/browser.lua',t.url) else shell.run(t.path) end
    end
  elseif ev[1]=='mouse_click'then
    local r=gui.hit(regions,ev[3],ev[4]);if r then selected=r.index;local t=tools[selected];if t.shell then shell.run('shell')elseif t.url then shell.run('/spawnnet/client/browser.lua',t.url)else shell.run(t.path)end end
  elseif ev[1]=='mouse_scroll'then selected=math.max(1,math.min(#tools,selected+ev[2])) end
end
gui.clear()
]=],
  ["/spawnnet/client/doctor.lua"]=[=[local config=dofile('/spawnnet/lib/config.lua')
local net=dofile('/spawnnet/client/net.lua')
local gui=dofile('/spawnnet/client/gui.lua')

local function report()
  local n=net.activeNetwork();local lines={}
  local function row(name,value,ok)lines[#lines+1]=(ok==false and'[FAIL] 'or ok==true and'[ OK ] 'or'       ')..name..': '..tostring(value)end
  row('Client version',config.version,true)
  row('Network',tostring(n.name)..' ['..tostring(n.id)..']',true)
  row('Visibility',n.visibility or'?',true)
  local modem,me=net.open();row('Modem',modem or me,modem~=nil)
  local core,ce=net.discover(true);row('Core',core and('#'..core)or ce,core~=nil)
  if core then local p,e=net.call('auth','ping',{}, {noAuth=true});row('Core ping',p and('server '..tostring(p.version))or e,p~=nil)end
  local s=net.loadSession();row('Account',s and s.user or'Guest',true)
  row('Protocol',n.protocol or net.protocolFor(n.id),true)
  row('Discovery',config.discoveryProtocol,true)
  row('Computer ID',os.getComputerID(),true)
  row('Free disk',fs.getFreeSpace('/'),true)
  lines[#lines+1]='';lines[#lines+1]='If Core and Ping are OK, client-to-core networking is healthy.'
  return table.concat(lines,'\n')
end

while true do
  local m=gui.menu('SPAWNNET DIAGNOSTICS','Connection checks and useful recovery tools.',{
    {label='Run health report',action='run'},
    {label='Network Manager',action='network'},
    {label='Developer Network Lab',action='lab'},
    {label='Check client update',action='update'},
    {label='Back',action='back'}},{right=config.version})
  if not m or m.action=='back'then break elseif m.action=='run'then gui.viewer('HEALTH REPORT',report(),{meta='Computer #'..os.getComputerID()})elseif m.action=='network'then shell.run('/spawnnet/client/networks.lua')elseif m.action=='lab'then shell.run('/spawnnet/client/dev_network.lua')elseif m.action=='update'then shell.run('/spawnnet/client/updater.lua','client')end
end
gui.clear()
]=],
  ["/spawnnet/client/gui.lua"]=[=[local M={}
local C=colors

local function tostringSafe(v) return tostring(v==nil and '' or v) end

function M.clip(text,width)
  local s=tostringSafe(text)
  width=math.max(0,tonumber(width) or 0)
  if #s<=width then return s end
  if width<=3 then return s:sub(1,width) end
  return s:sub(1,width-3)..'...'
end

function M.wrap(text,width)
  width=math.max(1,tonumber(width) or 1)
  local out={}
  local src=tostringSafe(text)
  for raw in (src..'\n'):gmatch('(.-)\n') do
    if raw=='' then
      out[#out+1]=''
    else
      local line=''
      for word in raw:gmatch('%S+') do
        while #word>width do
          if line~='' then out[#out+1]=line;line='' end
          out[#out+1]=word:sub(1,width)
          word=word:sub(width+1)
        end
        if word~='' then
          if line=='' then line=word
          elseif #line+1+#word<=width then line=line..' '..word
          else out[#out+1]=line;line=word end
        end
      end
      out[#out+1]=line
    end
  end
  if #out>1 and out[#out]=='' and src:sub(-1)~='\n' then table.remove(out) end
  return out
end

function M.clear(bg)
  term.setBackgroundColor(bg or C.black)
  term.setTextColor(C.white)
  term.clear()
  term.setCursorPos(1,1)
end

function M.text(x,y,w,text,fg,bg,align)
  local sw,sh=term.getSize()
  x=math.max(1,math.floor(tonumber(x) or 1));y=math.floor(tonumber(y) or 1)
  if y<1 or y>sh or x>sw then return end
  w=math.max(0,math.min(math.floor(tonumber(w) or #tostringSafe(text)),sw-x+1))
  if w<=0 then return end
  local s=M.clip(text,w)
  if align=='center' then s=string.rep(' ',math.max(0,math.floor((w-#s)/2)))..s
  elseif align=='right' then s=string.rep(' ',math.max(0,w-#s))..s end
  s=s..string.rep(' ',math.max(0,w-#s))
  term.setCursorPos(x,y);term.setTextColor(fg or C.white);term.setBackgroundColor(bg or C.black)
  write(s:sub(1,w))
end

function M.paragraph(x,y,w,h,text,fg,bg)
  local lines=M.wrap(text,w)
  local max=math.min(#lines,math.max(0,tonumber(h) or #lines))
  for i=1,max do M.text(x,y+i-1,w,lines[i],fg,bg,'left') end
  return max,#lines
end

function M.bar(title,right)
  local w=select(1,term.getSize())
  M.text(1,1,w,'',C.white,C.gray)
  local r=tostringSafe(right)
  local rw=(r~='' and math.min(#r+1,math.floor(w*.42)) or 0)
  if rw>0 then M.text(w-rw+1,1,rw,r,C.lightGray,C.gray,'right') end
  local tw=math.max(1,w-rw-2)
  M.text(2,1,tw,title or 'SpawnNet',C.yellow,C.gray,'left')
end

function M.status(text,good)
  local w,h=term.getSize()
  M.text(1,h,w,' '..tostringSafe(text),good==false and C.red or C.lightGray,C.gray,'left')
end

function M.rule(y,ch,fg,bg)
  local w=select(1,term.getSize())
  M.text(1,y,w,string.rep(ch or '-',w),fg or C.gray,bg or C.black)
end

function M.button(x,y,w,label,enabled,accent)
  local bg=enabled==false and C.gray or accent or C.blue
  local fg=enabled==false and C.lightGray or C.white
  local inner=math.max(0,w-2)
  M.text(x,y,w,'['..M.clip(label or '',inner)..']',fg,bg,'center')
  return{x1=x,y1=y,x2=x+w-1,y2=y,label=label,enabled=enabled~=false}
end

function M.box(x,y,w,h,title,bg)
  bg=bg or C.black
  if w<2 or h<2 then return end
  M.text(x,y,w,'+'..string.rep('-',math.max(0,w-2))..'+',C.lightGray,bg)
  for yy=y+1,y+h-2 do M.text(x,yy,w,'|'..string.rep(' ',math.max(0,w-2))..'|',C.lightGray,bg) end
  M.text(x,y+h-1,w,'+'..string.rep('-',math.max(0,w-2))..'+',C.lightGray,bg)
  if title and w>6 then M.text(x+2,y,math.min(w-4,#tostringSafe(title)),title,C.yellow,bg) end
end

function M.hit(regions,x,y)
  for i=#regions,1,-1 do
    local r=regions[i]
    if r.enabled~=false and x>=r.x1 and x<=r.x2 and y>=r.y1 and y<=r.y2 then return r end
  end
end

local function editLine(initial,mask,x,y,width)
  local value=tostringSafe(initial);local cursor=#value+1;local offset=0
  width=math.max(1,tonumber(width) or 1)
  local function redraw()
    cursor=math.max(1,math.min(cursor,#value+1))
    if cursor-1<offset then offset=cursor-1 end
    if cursor-1>offset+width-1 then offset=cursor-width end
    offset=math.max(0,offset)
    local shown=mask and string.rep(mask,#value) or value
    local visible=shown:sub(offset+1,offset+width)
    term.setCursorPos(x,y);term.setTextColor(C.black);term.setBackgroundColor(C.lightGray)
    write(visible..string.rep(' ',math.max(0,width-#visible)))
    local cx=x+(cursor-1-offset);cx=math.max(x,math.min(x+width-1,cx))
    term.setCursorPos(cx,y);term.setCursorBlink(true)
  end
  redraw()
  while true do
    local ev={os.pullEvent()}
    if ev[1]=='char' then
      local s=ev[2] or '';value=value:sub(1,cursor-1)..s..value:sub(cursor);cursor=cursor+#s
    elseif ev[1]=='paste' then
      local s=tostringSafe(ev[2]):gsub('[\r\n]',' ');value=value:sub(1,cursor-1)..s..value:sub(cursor);cursor=cursor+#s
    elseif ev[1]=='key' then
      local k=ev[2]
      if k==keys.enter then break
      elseif k==keys.backspace and cursor>1 then value=value:sub(1,cursor-2)..value:sub(cursor);cursor=cursor-1
      elseif k==keys.delete and cursor<=#value then value=value:sub(1,cursor-1)..value:sub(cursor+1)
      elseif k==keys.left and cursor>1 then cursor=cursor-1
      elseif k==keys.right and cursor<=#value then cursor=cursor+1
      elseif k==keys.home then cursor=1
      elseif k==keys['end'] then cursor=#value+1 end
    end
    redraw()
  end
  term.setCursorBlink(false)
  return value
end

function M.prompt(title,label,default,mask)
  local w=term.getSize();M.clear();M.bar(title or 'INPUT')
  M.paragraph(3,4,w-5,2,label or '',C.white,C.black)
  M.text(3,7,w-5,'',C.black,C.lightGray)
  M.text(3,7,2,'> ',C.black,C.lightGray)
  local v=editLine(default or '',mask,5,7,math.max(1,w-7))
  term.setCursorBlink(false);term.setBackgroundColor(C.black);term.setTextColor(C.white)
  return v
end

function M.confirm(title,message)
  local w,h=term.getSize();M.clear();M.bar(title or 'CONFIRM')
  M.paragraph(3,4,w-5,math.max(1,h-8),message,C.white,C.black)
  M.text(3,h-3,w-5,'Y = Yes     N = No',C.yellow,C.black,'center')
  M.status('Confirm with Y/N')
  while true do
    local ev={os.pullEvent('key')};local k=ev[2]
    if k==keys.y then return true elseif k==keys.n or k==keys.escape then return false end
  end
end

function M.menu(title,subtitle,items,opts)
  opts=opts or {};local selected=math.max(1,math.min(opts.selected or 1,math.max(1,#items)))
  while true do
    local w,h=term.getSize();M.clear(opts.bg or C.black);M.bar(title,opts.right)
    local start=3
    if subtitle and subtitle~='' then
      local used,total=M.paragraph(2,3,w-2,2,subtitle,C.lightGray,C.black)
      start=3+math.min(2,math.max(1,used))+1
      if total>2 then M.text(w-4,4,3,'...',C.gray,C.black,'right') end
    end
    start=opts.startY or start
    local visible=math.max(1,h-start-1);local regions={}
    if selected<1 then selected=1 end;if selected>#items then selected=#items end
    local first=math.max(1,math.min(selected-math.floor(visible/2),math.max(1,#items-visible+1)))
    local last=math.min(#items,first+visible-1)
    for row=0,visible-1 do
      local i=first+row;if i>#items then break end
      local it=items[i];local bg=i==selected and C.blue or C.black
      local fg=it.disabled and C.gray or(i==selected and C.white or C.lightGray)
      local prefix=i==selected and '> 'or'  '
      M.text(2,start+row,w-2,prefix..tostringSafe(it.label or it.id or i),fg,bg)
      regions[#regions+1]={x1=1,y1=start+row,x2=w,y2=start+row,index=i,enabled=not it.disabled}
    end
    local footer=opts.footer or ('Items '..tostring(first)..'-'..tostring(last)..'/'..tostring(#items)..'  Up/Down/PgUp/PgDn/Enter  Q back')
    M.status(footer)
    local ev={os.pullEvent()}
    if ev[1]=='key' then
      local k=ev[2]
      if k==keys.up then selected=math.max(1,selected-1)
      elseif k==keys.down then selected=math.min(#items,selected+1)
      elseif k==keys.pageUp then selected=math.max(1,selected-visible)
      elseif k==keys.pageDown then selected=math.min(#items,selected+visible)
      elseif k==keys.home then selected=1
      elseif k==keys['end'] then selected=#items
      elseif k==keys.enter and items[selected] and not items[selected].disabled then return items[selected],selected
      elseif k==keys.q or k==keys.escape then return nil end
    elseif ev[1]=='mouse_scroll' then
      selected=math.max(1,math.min(#items,selected+ev[2]))
    elseif ev[1]=='mouse_click' then
      local r=M.hit(regions,ev[3],ev[4]);if r then selected=r.index;return items[selected],selected end
    end
  end
end

function M.viewer(title,text,opts)
  opts=opts or {};local scroll=0
  while true do
    local w,h=term.getSize();local top=opts.meta and 5 or 3;local bottom=h-1;local vh=math.max(1,bottom-top+1)
    local lines=M.wrap(text,w-4);local maxScroll=math.max(0,#lines-vh)
    scroll=math.max(0,math.min(scroll,maxScroll));M.clear();M.bar(title,opts.right)
    if opts.meta then M.text(2,3,w-2,opts.meta,C.lightGray,C.black);M.rule(4,'-',C.gray,C.black) end
    for row=1,vh do local line=lines[scroll+row];if line then M.text(3,top+row-1,w-5,line,C.white,C.black) end end
    M.status('Scroll '..tostring(scroll+1)..'/'..tostring(math.max(1,#lines))..'  Up/Down/PgUp/PgDn  Q back')
    local ev={os.pullEvent()}
    if ev[1]=='key' then local k=ev[2]
      if k==keys.q or k==keys.escape or k==keys.backspace then return
      elseif k==keys.up then scroll=scroll-1 elseif k==keys.down then scroll=scroll+1
      elseif k==keys.pageUp then scroll=scroll-vh elseif k==keys.pageDown then scroll=scroll+vh
      elseif k==keys.home then scroll=0 elseif k==keys['end'] then scroll=maxScroll end
    elseif ev[1]=='mouse_scroll' then scroll=scroll+ev[2] end
  end
end

function M.editor(title,initial,opts)
  opts=opts or {};local width=math.max(8,(select(1,term.getSize()))-4)
  local lines={};local src=tostringSafe(initial)
  for line in (src..'\n'):gmatch('(.-)\n') do lines[#lines+1]=line end
  if #lines==0 then lines={''} end
  local row=1;local col=#lines[1]+1;local top=1
  local function normalize()
    if #lines==0 then lines={''} end
    row=math.max(1,math.min(row,#lines));col=math.max(1,math.min(col,#lines[row]+1))
  end
  while true do
    normalize();local w,h=term.getSize();local viewTop=3;local viewBottom=h-2;local vh=math.max(1,viewBottom-viewTop+1)
    if row<top then top=row elseif row>top+vh-1 then top=row-vh+1 end
    top=math.max(1,math.min(top,math.max(1,#lines-vh+1)))
    M.clear();M.bar(title or 'TEXT EDITOR',opts.right)
    for i=0,vh-1 do local idx=top+i;if idx>#lines then break end;local marker=idx==row and '> 'or'  ';M.text(1,viewTop+i,w,marker..lines[idx],idx==row and C.white or C.lightGray,idx==row and C.gray or C.black) end
    M.status('F2 save  Esc cancel  Enter newline  Arrows move  '..row..':'..col)
    local shown=lines[row];local off=0;if col+2>w then off=col-(w-3) end;local cx=3+col-1-off;local cy=viewTop+(row-top)
    if cy>=viewTop and cy<=viewBottom then term.setCursorPos(math.max(3,math.min(w,cx)),cy);term.setCursorBlink(true) end
    local ev={os.pullEvent()}
    if ev[1]=='char' then local s=ev[2] or '';local line=lines[row];lines[row]=line:sub(1,col-1)..s..line:sub(col);col=col+#s
    elseif ev[1]=='paste' then
      local s=tostringSafe(ev[2]):gsub('\r','');local first=true
      for part in (s..'\n'):gmatch('(.-)\n') do
        if first then local line=lines[row];lines[row]=line:sub(1,col-1)..part..line:sub(col);col=col+#part;first=false
        elseif part~='' then table.insert(lines,row+1,part);row=row+1;col=#part+1 end
      end
    elseif ev[1]=='key' then local k=ev[2]
      if k==keys.f2 then term.setCursorBlink(false);return table.concat(lines,'\n')
      elseif k==keys.escape then term.setCursorBlink(false);return nil
      elseif k==keys.enter then local line=lines[row];local left=line:sub(1,col-1);local right=line:sub(col);lines[row]=left;table.insert(lines,row+1,right);row=row+1;col=1
      elseif k==keys.backspace then
        if col>1 then local line=lines[row];lines[row]=line:sub(1,col-2)..line:sub(col);col=col-1
        elseif row>1 then local prev=#lines[row-1]+1;lines[row-1]=lines[row-1]..lines[row];table.remove(lines,row);row=row-1;col=prev end
      elseif k==keys.delete then
        local line=lines[row];if col<=#line then lines[row]=line:sub(1,col-1)..line:sub(col+1)
        elseif row<#lines then lines[row]=line..lines[row+1];table.remove(lines,row+1) end
      elseif k==keys.left then if col>1 then col=col-1 elseif row>1 then row=row-1;col=#lines[row]+1 end
      elseif k==keys.right then if col<=#lines[row] then col=col+1 elseif row<#lines then row=row+1;col=1 end
      elseif k==keys.up then row=math.max(1,row-1);col=math.min(col,#lines[row]+1)
      elseif k==keys.down then row=math.min(#lines,row+1);col=math.min(col,#lines[row]+1)
      elseif k==keys.home then col=1 elseif k==keys['end'] then col=#lines[row]+1
      elseif k==keys.pageUp then row=math.max(1,row-vh);col=math.min(col,#lines[row]+1)
      elseif k==keys.pageDown then row=math.min(#lines,row+vh);col=math.min(col,#lines[row]+1) end
    elseif ev[1]=='mouse_scroll' then row=math.max(1,math.min(#lines,row+ev[2])) end
  end
end

function M.toast(message,seconds)
  local w,h=term.getSize()
  local width=math.max(12,w-4)
  local lines=M.wrap(tostring(message or ''),math.max(1,width-2))
  while #lines>3 do table.remove(lines) end
  local y=math.max(2,h-#lines-2)
  for i=1,#lines do M.text(3,y+i-1,width,' '..lines[i]..' ',C.black,C.yellow,'center') end
  sleep(seconds or 1)
end

return M
]=],
  ["/spawnnet/client/labs.lua"]=[==[local gui=dofile('/spawnnet/client/gui.lua')
local util=dofile('/spawnnet/lib/util.lua')
local C=colors

local function hasMethod(name,wanted)
  local ok,methods=pcall(peripheral.getMethods,name)
  if not ok or type(methods)~='table' then return false end
  for _,m in ipairs(methods)do if m==wanted then return true end end
  return false
end

local function inventories()
  local out={}
  for _,name in ipairs(peripheral.getNames())do
    if hasMethod(name,'list') then
      out[#out+1]={name=name,type=tostring(peripheral.getType(name)or'unknown'),push=hasMethod(name,'pushItems'),pull=hasMethod(name,'pullItems')}
    end
  end
  table.sort(out,function(a,b)return a.name<b.name end)
  return out
end

local function chooseInventory(title,items,skip)
  local opts={}
  for _,x in ipairs(items)do if x.name~=skip then opts[#opts+1]={label=x.name..'  ['..x.type..']',inv=x}end end
  opts[#opts+1]={label='Cancel',cancel=true}
  local m=gui.menu(title,'Choose an inventory peripheral.',opts)
  return m and m.inv or nil
end

local function launchChest()
  local invs=inventories()
  if #invs==0 then
    gui.viewer('CHEST PULSE - SETUP',[=[No inventory peripheral is visible to this computer.

The demo needs any inventory which ComputerCraft can see with a list() method. Depending on your modpack this may be a chest beside the computer, a chest attached through a wired modem, or another inventory peripheral.

Once an inventory appears in Peripheral Lab, return here and launch Chest Pulse again.]=],{meta='No inventory detected'})
    return
  end
  local a=chooseInventory('CHEST PULSE - INVENTORY A',invs)
  if not a then return end
  local b=nil
  if #invs>1 then
    local q=gui.menu('OPTIONAL SECOND INVENTORY','One inventory gives a live mirror. Two inventories unlock visible item cycling.',{{label='Choose a second inventory',action='choose'},{label='Use one inventory only',action='one'},{label='Cancel',action='cancel'}})
    if not q or q.action=='cancel'then return end
    if q.action=='choose'then b=chooseInventory('CHEST PULSE - INVENTORY B',invs,a.name) end
  end
  local text='Inventory A: '..a.name..' ['..a.type..']\nInventory B: '..(b and(b.name..' ['..b.type..']')or'none - mirror mode')..'\n\nThe temporary lab harness will run for 3 minutes. It only scans the selected inventories unless you explicitly press CYCLE or AUTO CYCLE on the Wiki page.'
  if not gui.confirm('START CHEST PULSE',text..'\n\nStart the demo?')then return end
  util.ensureDir('/spawnnet/labs')
  local token=util.id('chestlab')
  util.saveTable('/spawnnet/labs/chest.cfg',{a=a.name,b=b and b.name or nil,duration=180,started=os.clock(),token=token})
  local st=util.loadTable('/spawnnet/local/wiki.db',{})
  util.tablePathSet(st,'labs.chest.command','')
  util.tablePathSet(st,'labs.chest.active',true)
  util.tablePathSet(st,'labs.chest.status','Starting temporary lab harness...')
  util.saveTable('/spawnnet/local/wiki.db',st)
  if not multishell or not multishell.launch then
    gui.toast('Chest Pulse needs an Advanced Computer/multishell for the background demo.',3)
    return
  end
  local env=(getfenv and getfenv())or _ENV or{}
  local current=multishell.getCurrent and multishell.getCurrent()or nil
  local tab=multishell.launch(env,'/spawnnet/client/labs_chest_worker.lua')
  if tab and multishell.setTitle then pcall(multishell.setTitle,tab,'SpawnNet Chest Pulse')end
  if current and multishell.setFocus then pcall(multishell.setFocus,current)end
  gui.toast('Chest Pulse running in background. Return to the lab page.',2)
end

local function open(url)shell.run('/spawnnet/client/browser.lua',url)end
local arg=(...)
if arg=='chest'then launchChest();return
elseif arg=='mail'then shell.run('/spawnnet/client/apps_mail.lua');return
elseif arg=='peripheral'then shell.run('/spawnnet/client/dev_peripherals.lua');return
elseif arg=='network'then shell.run('/spawnnet/client/dev_network.lua');return
elseif arg=='game'then open('spn://wiki/labs/game');return
elseif arg=='canvas'then open('spn://wiki/labs/canvas');return
elseif arg=='vault'then open('spn://wiki/labs/vault');return end

while true do
  local m=gui.menu('SPAWNNET LABS','Start simple. End with real peripherals and distributed infrastructure.',{
    {label='01  SIGNAL BREAKER       zero-setup browser game',action='game'},
    {label='02  SHARED GRID          zero-setup multiplayer state',action='canvas'},
    {label='03  MAIL HEIST           zero-setup cross-app challenge',action='vault'},
    {label='04  CHEST PULSE          1 inventory; 2 for item cycling',action='chestpage'},
    {label='05  PERIPHERAL X-RAY     inspect real modded hardware',action='periph'},
    {label='06  CLUSTER FAILOVER     storage-node live demo',action='cluster'},
    {label='07  PRIVATE INTRANET     multi-core advanced lab',action='intranet'},
    {label='Open complete Labs index',action='index'},
    {label='Back',action='back'},
  })
  if not m or m.action=='back'then break
  elseif m.action=='game'then open('spn://wiki/labs/game')
  elseif m.action=='canvas'then open('spn://wiki/labs/canvas')
  elseif m.action=='vault'then open('spn://wiki/labs/vault')
  elseif m.action=='chestpage'then open('spn://wiki/labs/chest')
  elseif m.action=='periph'then open('spn://wiki/labs/peripheral')
  elseif m.action=='cluster'then open('spn://wiki/labs/cluster')
  elseif m.action=='intranet'then open('spn://wiki/labs/intranet')
  elseif m.action=='index'then open('spn://wiki/labs')end
end
]==],
  ["/spawnnet/client/labs_chest_worker.lua"]=[=[local util=dofile('/spawnnet/lib/util.lua')
local cfg=util.loadTable('/spawnnet/labs/chest.cfg',nil)
if type(cfg)~='table'or not cfg.a then return end
local statePath='/spawnnet/local/wiki.db'
local running=true
local auto=false
local moves=0
local direction=1
local lastMove=0
local endAt=os.clock()+(tonumber(cfg.duration)or 180)

local function methods(name)
  local set={};local ok,t=pcall(peripheral.getMethods,name)
  if ok and type(t)=='table'then for _,m in ipairs(t)do set[m]=true end end
  return set
end
local ma=methods(cfg.a);local mb=cfg.b and methods(cfg.b)or{}

local function readState()return util.loadTable(statePath,{})end
local function writeFields(fields)
  local st=readState()
  for k,v in pairs(fields)do util.tablePathSet(st,'labs.chest.'..k,v)end
  util.saveTable(statePath,st)
end
local function scan(name)
  if not name or not peripheral.isPresent(name)then return nil,'offline' end
  local ok,list=pcall(peripheral.call,name,'list')
  if not ok or type(list)~='table'then return nil,tostring(list)end
  local total,stacks=0,0;local sample='(empty)';local first=nil
  for slot,item in pairs(list)do
    if type(item)=='table'then
      local count=tonumber(item.count)or 0;total=total+count;stacks=stacks+1
      if not first then first=tonumber(slot);sample=tostring(item.name or item.displayName or'item')..' x'..tostring(count)end
    end
  end
  return {list=list,total=total,stacks=stacks,sample=sample,first=first}
end
local function firstSlot(list)
  local best=nil;for slot in pairs(list or{})do slot=tonumber(slot);if slot and(not best or slot<best)then best=slot end end;return best
end
local function transfer(from,to,mfrom,mto)
  local s=scan(from);if not s or not s.first then return 0,'Source empty' end
  if mfrom.pushItems then
    local ok,n=pcall(peripheral.call,from,'pushItems',to,s.first,1)
    if ok then return tonumber(n)or 0,(tonumber(n)or 0)>0 and'Moved with pushItems' or'No item moved'end
  end
  if mto and mto.pullItems then
    local ok,n=pcall(peripheral.call,to,'pullItems',from,s.first,1)
    if ok then return tonumber(n)or 0,(tonumber(n)or 0)>0 and'Moved with pullItems' or'No item moved'end
  end
  return 0,'No compatible transfer method'
end
local function selfCycle(name,m)
  local s=scan(name);if not s or not s.first then return 0,'Inventory empty' end
  if not m.pushItems then return 0,'Mirror mode: inventory has no pushItems method' end
  local size=nil;if m.size then local ok,n=pcall(peripheral.call,name,'size');if ok then size=tonumber(n)end end
  if not size then return 0,'Mirror mode: one inventory detected; add a second for item cycling' end
  local empty=nil;for i=1,size do if not s.list[i]then empty=i;break end end
  if not empty then return 0,'No empty slot available for self-cycle' end
  local ok,n=pcall(peripheral.call,name,'pushItems',name,s.first,1,empty)
  if ok and tonumber(n)and tonumber(n)>0 then return tonumber(n),'Moved one item to slot '..empty end
  return 0,'This inventory does not support self-transfer; add a second inventory'
end
local function cycle()
  local n,msg
  if cfg.b then
    if direction==1 then n,msg=transfer(cfg.a,cfg.b,ma,mb)else n,msg=transfer(cfg.b,cfg.a,mb,ma)end
    if n and n>0 then direction=direction==1 and 2 or 1 end
  else n,msg=selfCycle(cfg.a,ma)end
  if n and n>0 then moves=moves+n end
  return msg or'Cycle attempted'
end

writeFields({active=true,status='Harness online - scanning real inventory',inventoryA=cfg.a,inventoryB=cfg.b or'none',moves=0,auto=false})
while running and os.clock()<endAt do
  local latest=util.loadTable('/spawnnet/labs/chest.cfg',{})
  if cfg.token and latest.token~=cfg.token then running=false break end
  local st=readState();local cmd=util.tablePathGet(st,'labs.chest.command','')
  if cmd~=''then
    util.tablePathSet(st,'labs.chest.command','');util.saveTable(statePath,st)
    if cmd=='cycle'then writeFields({status=cycle()})
    elseif cmd=='toggle_auto'then auto=not auto;writeFields({auto=auto,status=auto and'Auto cycle enabled' or'Auto cycle paused'})
    elseif cmd=='stop'then running=false end
  end
  if auto and os.clock()-lastMove>=1.5 then lastMove=os.clock();writeFields({status=cycle()})end
  local a,ae=scan(cfg.a);local b,be=cfg.b and scan(cfg.b)or nil,nil
  writeFields({active=true,auto=auto,moves=moves,totalA=a and a.total or 0,stacksA=a and a.stacks or 0,sampleA=a and a.sample or('ERROR: '..tostring(ae)),totalB=b and b.total or 0,stacksB=b and b.stacks or 0,sampleB=cfg.b and(b and b.sample or('ERROR: '..tostring(be)))or'No second inventory'})
  sleep(0.5)
end
local latest=util.loadTable('/spawnnet/labs/chest.cfg',{})
if not cfg.token or latest.token==cfg.token then writeFields({active=false,auto=false,status=running and 'Lab harness expired after 3 minutes' or 'Lab harness stopped'})end
]=],
  ["/spawnnet/client/net.lua"]=[=[local config=dofile('/spawnnet/lib/config.lua')
local util=dofile('/spawnnet/lib/util.lua')
local packet=dofile('/spawnnet/lib/packet.lua')
local wire=dofile('/spawnnet/lib/wire.lua')
local M={_inbox={},_session=nil,_fragments={},_ws=nil}

local cfg=util.loadTable(config.clientConfig,{transport='rednet',modem=nil,timeout=config.requestTimeout,wsUrl=nil})
local registry=util.loadTable(config.networkRegistry,{active='public',networks={}})
registry.networks=registry.networks or {}
if not registry.active then registry.active='public' end
if not registry.networks.public and next(registry.networks)==nil then
  registry.networks.public={id='public',name='Public SpawnNet',visibility='public',placeholder=true}
end

local function protocolFor(id) return config.protocolPrefix..tostring(id)..':v2' end
local function backboneFor(id) return config.backbonePrefix..tostring(id)..':v2' end
local function sessionPath(id) return '/spawnnet/sessions/'..util.safeName(id,32)..'.db' end
local function saveRegistry() util.saveTable(config.networkRegistry,registry) end
local function normalizeRegistry()
  registry.networks=registry.networks or {}
  registry.active=registry.active or 'public'
  local p=registry.networks.public
  if p and p.placeholder and registry.active~='public' then registry.networks.public=nil end
  if next(registry.networks)==nil then
    registry.networks.public={id='public',name='Public SpawnNet',visibility='public',placeholder=true}
    registry.active='public'
  end
end
local function syncRegistry()
  local before=registry.active
  local disk=util.loadTable(config.networkRegistry,nil)
  if type(disk)=='table' then
    registry.active=disk.active or registry.active or 'public'
    registry.networks=type(disk.networks)=='table' and disk.networks or registry.networks or {}
  end
  normalizeRegistry()
  if before~=registry.active then
    M._session=nil;M._sessionNetwork=nil;M._inbox={};M._fragments={}
  end
  return registry
end

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

function M.saveConfig() util.saveTable(config.clientConfig,cfg) end
function M.config() return cfg end
function M.registry() syncRegistry(); return registry end
function M.protocolFor(id) return protocolFor(id) end
function M.backboneFor(id) return backboneFor(id) end
function M.activeNetwork()
  syncRegistry()
  local n=registry.networks[registry.active]
  if not n then
    n={id=registry.active or 'public',name=registry.active or 'public',visibility='public'}
    registry.networks[n.id]=n
  end
  n.protocol=n.protocol or protocolFor(n.id)
  n.backboneProtocol=n.backboneProtocol or backboneFor(n.id)
  return n
end
function M.networks()
  syncRegistry()
  local out={}
  for _,n in pairs(registry.networks) do out[#out+1]=util.deepcopy(n) end
  table.sort(out,function(a,b)return tostring(a.name or a.id)<tostring(b.name or b.id)end)
  return out
end
function M.setActiveNetwork(id)
  syncRegistry()
  id=util.safeName(id,32); if id=='' then return nil,'Bad network ID' end
  if not registry.networks[id] then return nil,'Unknown network '..id end
  registry.active=id; M._session=nil; M._sessionNetwork=nil; M._inbox={}; M._fragments={}
  local p=registry.networks.public
  if p and p.placeholder and id~='public' then registry.networks.public=nil end
  saveRegistry(); return registry.networks[id]
end
function M.addNetwork(info)
  syncRegistry()
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
  n.placeholder=nil
  registry.networks[id]=n
  local p=registry.networks.public
  if p and p.placeholder and id~='public' and registry.active~='public' then registry.networks.public=nil end
  saveRegistry(); return n
end
function M.removeNetwork(id)
  syncRegistry()
  id=util.safeName(id,32); if id=='public' then return nil,'The default public profile cannot be removed' end
  registry.networks[id]=nil
  if registry.active==id then
    local replacement=nil
    for nid in pairs(registry.networks) do replacement=nid break end
    registry.active=replacement or 'public'
  end
  normalizeRegistry(); saveRegistry(); return true
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
  if #out==1 then
    local cur=registry.networks[registry.active]
    if cur and cur.placeholder and not cur.coreId then
      registry.active=out[1].id
      if registry.networks.public and registry.networks.public.placeholder and out[1].id~='public' then registry.networks.public=nil end
      saveRegistry()
      M._session=nil;M._sessionNetwork=nil;M._inbox={};M._fragments={}
    end
  end
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
  local n=M.activeNetwork(); M._session=s; M._sessionNetwork=n.id
  util.ensureDir('/spawnnet/sessions')
  local path=sessionPath(n.id)
  if s then util.saveTable(path,s) elseif fs.exists(path) then fs.delete(path) end
end
local function refreshSessionFromDisk()
  local n=M.activeNetwork()
  if M._sessionNetwork and M._sessionNetwork~=n.id then M._session=nil;M._sessionNetwork=nil end
  local path=sessionPath(n.id)
  if fs.exists(path) then
    local disk=util.loadTable(path,nil)
    if type(disk)=='table' then M._session=disk;M._sessionNetwork=n.id else M._session=nil;M._sessionNetwork=nil end
  else M._session=nil;M._sessionNetwork=nil end
  return M._session
end
function M.getSession() return refreshSessionFromDisk() end
function M.loadSession() return refreshSessionFromDisk() end
function M.clearAllSessions()
  M._session=nil;M._sessionNetwork=nil
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
      elseif e.type=='panel' or e.type=='modal' then
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
  elseif method=='ui.setVisible' and e then e.visible=a[2] and true or false
  elseif method=='ui.setItems' and e then e.items=type(a[2])=='table' and util.deepcopy(a[2]) or {}
  elseif method=='ui.setRows' and e then e.rows=type(a[2])=='table' and util.deepcopy(a[2]) or {}
  elseif method=='ui.setProgress' and e then e.value=tonumber(a[2]) or 0
  elseif method=='ui.setSelected' and e then e.selected=tonumber(a[2]) or 1 end
end
return M
]=],
  ["/spawnnet/client/sdk.lua"]=[=[local net=dofile('/spawnnet/client/net.lua')
local M={}
function M.call(service,action,payload)return net.call(service,action,payload)end
M.network={active=function()return net.activeNetwork()end,list=function()return net.networks()end,discover=function(timeout)return net.discoverNetworks(timeout)end,switch=function(id)return net.setActiveNetwork(id)end}
M.dns={resolve=function(domain)return net.call('dns','resolve',{domain=domain})end,register=function(domain,title)return net.call('dns','register',{domain=domain,title=title})end,mine=function()return net.call('dns','listMine',{})end}
M.web={get=function(domain,path)return net.call('web','getPage',{domain=domain,path=path or'/'},{noAuth=true})end,action=function(domain,event,input,args)return net.call('web','runAction',{domain=domain,event=event,input=input or{},args=args or{}})end,analytics=function(domain)return net.call('web','analytics',{domain=domain})end}
M.storage={get=function(domain,key)return net.call('storage','get',{domain=domain,key=key})end,set=function(domain,key,value)return net.call('storage','set',{domain=domain,key=key,value=value})end,inc=function(domain,key,amount)return net.call('storage','inc',{domain=domain,key=key,amount=amount})end}
M.db={get=function(domain,c,key)return net.call('db','get',{domain=domain,collection=c,key=key})end,set=function(domain,c,key,value)return net.call('db','set',{domain=domain,collection=c,key=key,value=value})end,insert=function(domain,c,value)return net.call('db','insert',{domain=domain,collection=c,value=value})end,list=function(domain,c,limit)return net.call('db','list',{domain=domain,collection=c,limit=limit})end}
M.mail={send=function(to,subject,body)return net.call('mail','send',{to=to,subject=subject,body=body})end,inbox=function(limit,offset)return net.call('mail','inbox',{limit=limit,offset=offset})end,sent=function(limit,offset)return net.call('mail','sent',{limit=limit,offset=offset})end}
M.events={poll=function(limit)return net.call('event','poll',{limit=limit})end,peek=function()return net.call('event','peek',{})end,emit=function(to,t,data)return net.call('event','emit',{to=to,type=t,data=data})end}
M.jobs={submit=function(domain,queue,action,payload)return net.call('jobs','submit',{domain=domain,queue=queue,jobAction=action,payload=payload or{}})end,poll=function(domain,queue,limit)return net.call('jobs','poll',{domain=domain,queue=queue,limit=limit})end,claim=function(domain,id,worker)return net.call('jobs','claim',{domain=domain,id=id,worker=worker})end,progress=function(domain,id,progress,message)return net.call('jobs','progress',{domain=domain,id=id,progress=progress,message=message})end,complete=function(domain,id,result,message)return net.call('jobs','complete',{domain=domain,id=id,result=result or{},message=message})end,fail=function(domain,id,err)return net.call('jobs','fail',{domain=domain,id=id,error=err})end,status=function(domain,id)return net.call('jobs','status',{domain=domain,id=id})end,list=function(domain,limit)return net.call('jobs','list',{domain=domain,limit=limit})end}
M.blob={put=function(domain,key,data,mime,public)return net.call('blob','put',{domain=domain,key=key,data=data,mime=mime,public=public})end,get=function(domain,key)return net.call('blob','get',{domain=domain,key=key})end,list=function(domain)return net.call('blob','list',{domain=domain})end,delete=function(domain,key)return net.call('blob','delete',{domain=domain,key=key})end}
M.search=function(q)return net.call('search','query',{q=q},{noAuth=true})end
M.forum={boards=function()return net.call('forum','boards',{})end,threads=function(board,limit,offset)return net.call('forum','threads',{board=board,limit=limit,offset=offset})end,search=function(q)return net.call('forum','search',{q=q})end,thread=function(board,id)return net.call('forum','getThread',{board=board,id=id})end,post=function(board,title,body)return net.call('forum','newThread',{board=board,title=title,body=body})end,reply=function(board,id,body)return net.call('forum','reply',{board=board,id=id,body=body})end}
M.chat={read=function(room,limit)return net.call('chat','read',{room=room,limit=limit})end,send=function(room,text)return net.call('chat','send',{room=room,text=text})end}
M.telemetry={push=function(domain,stream,data)return net.call('telemetry','push',{domain=domain,stream=stream,data=data,computer=os.getComputerID()})end,get=function(domain,stream,limit)return net.call('telemetry','get',{domain=domain,stream=stream,limit=limit})end,last=function(domain,stream)local p,e=net.call('telemetry','get',{domain=domain,stream=stream,limit=1});if not p then return nil,e end;return p.last end}
M.nodes={summary=function()return net.call('nodes','summary',{})end,approve=function(id,name)return net.call('nodes','approve',{id=id,name=name})end,rebalance=function()return net.call('nodes','rebalance',{})end,remove=function(id)return net.call('nodes','remove',{id=id})end}
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
  ["/spawnnet/client/settings.lua"]=[=[local gui=dofile('/spawnnet/client/gui.lua')
local net=dofile('/spawnnet/client/net.lua')
local auth=dofile('/spawnnet/client/auth_client.lua')
local function signIn(register)
  local u=gui.prompt(register and'CREATE ACCOUNT'or'SIGN IN','Username:','');if u==''then return end
  local pw=gui.prompt(register and'CREATE ACCOUNT'or'SIGN IN','Password:','','*');local x,e
  if register then x,e=auth.register(u,pw,u)else x,e=auth.login(u,pw)end
  gui.toast(x and('Signed in as '..x.user)or e,2)
end
while true do
  local s=net.loadSession();local n=net.activeNetwork();local items={{label='Network manager',action='net'}}
  if s then items[#items+1]={label='Sign out '..s.user,action='logout'}else items[#items+1]={label='Sign in',action='login'};items[#items+1]={label='Create account',action='register'}end
  items[#items+1]={label='Connection diagnostics',action='doctor'};items[#items+1]={label='Check for client update',action='update'};items[#items+1]={label='Back',action='back'}
  local m=gui.menu('SPAWNNET SETTINGS','Active network: '..tostring(n.name)..' ['..n.id..']',items)
  if not m or m.action=='back'then break elseif m.action=='net'then shell.run('/spawnnet/client/networks.lua')elseif m.action=='doctor'then shell.run('/spawnnet/client/doctor.lua')elseif m.action=='update'then shell.run('/spawnnet/client/updater.lua','client')elseif m.action=='logout'then auth.logout();gui.toast('Signed out',1)elseif m.action=='login'then signIn(false)elseif m.action=='register'then signIn(true)end
end
]=],
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
elseif cmd=='labs'then shell.run('/spawnnet/client/labs.lua',args[2])
elseif cmd=='developer'or cmd=='dev'then shell.run('/spawnnet/client/developer.lua')
elseif cmd=='nodes'then shell.run('/spawnnet/client/nodes.lua')
elseif cmd=='keys'then shell.run('/spawnnet/client/apps_keys.lua')
elseif cmd=='doctor'then shell.run('/spawnnet/client/doctor.lua')
elseif cmd=='telemetry'then shell.run('/spawnnet/client/telemetry_agent.lua')
elseif cmd=='api'then shell.run('/spawnnet/client/browser.lua','spn://wiki/api')
elseif cmd=='update'then shell.run('/spawnnet/client/updater.lua',args[2]or'client')
elseif cmd=='register'then local u=args[2]or ui.prompt('Username','');local pw=args[3]or ui.prompt('Password','','*');local s,e=auth.register(u,pw,u);if s then ui.success('Registered and logged in as '..s.user)else ui.error(e)end
elseif cmd=='login'then local u=args[2]or ui.prompt('Username','');local pw=args[3]or ui.prompt('Password','','*');local s,e=auth.login(u,pw);if s then ui.success('Logged in as '..s.user)else ui.error(e)end
elseif cmd=='logout'then auth.logout();print('Logged out.')
else
 print('SpawnNet '..config.version)
 print('  spawnnet                 desktop')
 print('  spawnnet web [url]       browser')
 print('  spawnnet studio          no-code site builder')
 print('  spawnnet mail            mail')
 print('  spawnnet forum           forums')
 print('  spawnnet networks        network manager')
 print('  spawnnet labs            interactive demos')
 print('  spawnnet dev             developer workbench')
 print('  spawnnet api             API documentation')
 print('  spawnnet login/register  account')
 print('  spawnnet doctor          diagnostics')
 print('  spawnnet update          update client')
end
]=],
  ["/spawnnet/client/studio.lua"]=[=[shell.run('/spawnnet/client/studio_easy.lua')
]=],
  ["/spawnnet/client/studio_advanced.lua"]=[=[local util=dofile('/spawnnet/lib/util.lua')
local net=dofile('/spawnnet/client/net.lua')
local auth=dofile('/spawnnet/client/auth_client.lua')
local gui=dofile('/spawnnet/client/gui.lua')
local renderer=dofile('/spawnnet/client/renderer.lua')
local templates=dofile('/spawnnet/client/templates.lua')
local assets=dofile('/spawnnet/client/asset_manager.lua')
local C=colors

local function login()
  local s=net.loadSession();if s then local me=net.call('users','me',{});if me then return true end end
  local u=gui.prompt('ADVANCED STUDIO LOGIN','Username:','');if u==''then return false end
  local pw=gui.prompt('ADVANCED STUDIO LOGIN','Password:','','*');local x,e=auth.login(u,pw);if not x then gui.toast(e,2);return false end;return true
end

local colorNames={'white','orange','magenta','lightBlue','yellow','lime','pink','gray','lightGray','cyan','purple','blue','brown','green','red','black'}
local function colorName(v)for _,n in ipairs(colorNames)do if colors[n]==v then return n end end;return tostring(v or'default')end
local function chooseColor(title,current)
  local items={{label='Keep current: '..colorName(current),value=current}}
  for _,n in ipairs(colorNames)do items[#items+1]={label=n,value=colors[n]}end
  local m=gui.menu(title,'Choose a ComputerCraft color.',items);return m and m.value or current
end

local function savePage(domain,path,page)
  local p,e=net.call('web','savePage',{domain=domain,path=path,page=page});if not p then gui.toast(e,2);return false end;return true
end

local function editSerialized(title,value)
  local raw=gui.editor(title,textutils.serialize(value));if raw==nil then return value,false end
  local x=textutils.unserialize(raw);if type(x)~='table'then gui.toast('The edited value must deserialize to a Lua table.',2);return value,false end
  return x,true
end

local function editAction(e)
  local current=e.action and tostring(e.action.type)or'none'
  local m=gui.menu('BUTTON ACTION','Current: '..current,{
    {label='Navigate to page / spn:// address',kind='navigate'},
    {label='Run client SpawnScript event',kind='event'},
    {label='Run server SpawnScript event',kind='server'},
    {label='Open SpawnNet search',kind='search'},
    {label='No action',kind='none'},
    {label='Back',kind='back'}})
  if not m or m.kind=='back'then return end
  if m.kind=='none'then e.action=nil
  elseif m.kind=='navigate'then e.action={type='navigate',target=gui.prompt('NAVIGATION','Target:','/about')}
  elseif m.kind=='event'or m.kind=='server'then e.action={type=m.kind,event=gui.prompt('SPAWNSCRIPT EVENT','Event name:','click')}
  elseif m.kind=='search'then e.action={type='search'}end
end

local function editContent(domain,e)
  if e.type=='text'then local v=gui.editor('TEXT CONTENT',e.text or'');if v~=nil then e.text=v end
  elseif e.type=='heading'or e.type=='button'or e.type=='badge'or e.type=='checkbox'then e.text=gui.prompt('CONTENT','Text:',e.text or'')
  elseif e.type=='input'then e.placeholder=gui.prompt('INPUT','Placeholder:',e.placeholder or'')
  elseif e.type=='image'then local s=assets.choose(domain);if s then e.src=s end
  elseif e.type=='progress'then e.value=tonumber(gui.prompt('PROGRESS','Value:',tostring(e.value or 0)))or 0;e.max=tonumber(gui.prompt('PROGRESS','Maximum:',tostring(e.max or 100)))or 100
  elseif e.type=='list'then local v=gui.editor('LIST ITEMS',table.concat(e.items or{},'\n'));if v~=nil then e.items={};for line in(v..'\n'):gmatch('(.-)\n')do if line~=''then e.items[#e.items+1]=line end end end
  elseif e.type=='select'then local v=gui.editor('SELECT OPTIONS',table.concat(e.options or{},'\n'));if v~=nil then e.options={};for line in(v..'\n'):gmatch('(.-)\n')do if line~=''then e.options[#e.options+1]=line end end end
  elseif e.type=='table'then local lines={};for _,r in ipairs(e.rows or{})do lines[#lines+1]=table.concat(r,'|')end;local v=gui.editor('TABLE - | separates columns',table.concat(lines,'\n'));if v~=nil then e.rows={};for line in(v..'\n'):gmatch('(.-)\n')do if line~=''then local row={};for cell in(line..'|'):gmatch('(.-)|')do row[#row+1]=cell end;e.rows[#e.rows+1]=row end end end
  elseif e.type=='separator'then local s=gui.prompt('DIVIDER','Character:',e.char or'-');e.char=s:sub(1,1)
  elseif e.type=='panel'or e.type=='row'or e.type=='column'or e.type=='modal'or e.type=='tabs'then gui.toast('Use Raw Element for nested child structures.',2)end
end

local function geometry(e)
  e.x=tonumber(gui.prompt('GEOMETRY','X:',tostring(e.x or 1)))or e.x or 1
  e.y=tonumber(gui.prompt('GEOMETRY','Y:',tostring(e.y or 1)))or e.y or 1
  local w=gui.prompt('GEOMETRY','Width (number or 100%):',tostring(e.w or 20));e.w=tonumber(w)or w
  e.h=tonumber(gui.prompt('GEOMETRY','Height:',tostring(e.h or 1)))or e.h or 1
end

local function style(e)
  while true do
    local m=gui.menu('ELEMENT STYLE','Foreground '..colorName(e.fg)..'  |  Background '..colorName(e.bg),{
      {label='Foreground color',action='fg'},{label='Background color',action='bg'},
      {label='Alignment: '..tostring(e.align or'left'),action='align'},
      {label='Border: '..tostring(e.border==true),action='border'},
      {label='Back',action='back'}})
    if not m or m.action=='back'then return elseif m.action=='fg'then e.fg=chooseColor('FOREGROUND',e.fg)elseif m.action=='bg'then e.bg=chooseColor('BACKGROUND',e.bg)
    elseif m.action=='align'then local a=gui.menu('ALIGNMENT','',{{label='left',v='left'},{label='center',v='center'},{label='right',v='right'}});if a then e.align=a.v end
    elseif m.action=='border'then e.border=not(e.border==true)end
  end
end

local function elementSummary(e)
  return tostring(e.type)..'  #'..tostring(e.id or'?')..'  @'..tostring(e.x or'?')..','..tostring(e.y or'?')..'  '..tostring(e.w or'?')..'x'..tostring(e.h or'?')
end

local function inspectElement(domain,e)
  while true do
    local m=gui.menu('ELEMENT INSPECTOR',elementSummary(e),{
      {label='Content / data',action='content'},
      {label='Geometry / size',action='geometry'},
      {label='Style / colors',action='style'},
      {label='ID: '..tostring(e.id or''),action='id'},
      {label='Button action',action='action',disabled=e.type~='button'},
      {label='Raw element table',action='raw'},
      {label='Back',action='back'}})
    if not m or m.action=='back'then return
    elseif m.action=='content'then editContent(domain,e)
    elseif m.action=='geometry'then geometry(e)
    elseif m.action=='style'then style(e)
    elseif m.action=='id'then e.id=gui.prompt('ELEMENT ID','ID:',e.id or(e.type..'1'))
    elseif m.action=='action'then editAction(e)
    elseif m.action=='raw'then local x,ok=editSerialized('RAW ELEMENT TABLE',e);if ok then for k in pairs(e)do e[k]=nil end;for k,v in pairs(x)do e[k]=v end end end
  end
end

local elementTypes={'text','heading','button','input','checkbox','select','progress','image','separator','panel','row','column','table','badge','tabs','list','modal'}
local function newElement(domain)
  local items={};for _,t in ipairs(elementTypes)do items[#items+1]={label=t,type=t}end;items[#items+1]={label='Cancel',cancel=true}
  local m=gui.menu('ADD ELEMENT','Choose a renderer element. Complex structures can be finished in Raw Element.',items);if not m or m.cancel then return nil end
  local t=m.type;local e={type=t,id=t..tostring(math.random(100,999)),x=2,y=2,w=20,h=1,fg=C.white,bg=C.black}
  if t=='text'then e.text='Text';e.h=2 elseif t=='heading'or t=='button'or t=='badge'or t=='checkbox'then e.text=t
  elseif t=='input'then e.placeholder='Type here...' elseif t=='select'then e.options={'One','Two'} elseif t=='progress'then e.value=50;e.max=100
  elseif t=='image'then e.src=assets.choose(domain)or'';e.h=6 elseif t=='table'then e.rows={{'A','B'},{'1','2'}};e.h=4
  elseif t=='list'then e.items={'Item one','Item two'};e.h=3 elseif t=='panel'or t=='row'or t=='column'or t=='modal'then e.children={};e.h=5
  elseif t=='tabs'then e.tabs={{title='Tab 1',children={}}};e.h=6 elseif t=='separator'then e.char='-'end
  inspectElement(domain,e);return e
end

local function preview(domain,page)
  local cache={};local function loader(name)if cache[name]then return cache[name]end;local p=net.call('web','getAsset',{domain=domain,name=name},{noAuth=true});if p then cache[name]=p.data;return p.data end end
  local scroll=0
  while true do gui.clear();gui.bar('DRAFT PREVIEW',domain);local _,mx=renderer.draw(page,{top=2,bottom=select(2,term.getSize())-1,scroll=scroll,inputs={},assetLoader=loader});gui.status('Up/Down scroll   Q back');local ev={os.pullEvent()};if ev[1]=='key'then if ev[2]==keys.q or ev[2]==keys.escape then return elseif ev[2]==keys.up then scroll=math.max(0,scroll-1)elseif ev[2]==keys.down then scroll=math.min(mx,scroll+1)end elseif ev[1]=='mouse_scroll'then scroll=math.max(0,math.min(mx,scroll+ev[2]))end end
end

local function elements(domain,page)
  page.elements=page.elements or{};local selected=1
  while true do
    local items={{label='+ Add element',action='add'}};for i,e in ipairs(page.elements)do items[#items+1]={label=tostring(i)..'. '..elementSummary(e),index=i}end;items[#items+1]={label='Back',action='back'}
    local m,idx=gui.menu('PAGE ELEMENTS',tostring(#page.elements)..' top-level element(s)',items,{selected=selected});selected=idx or selected
    if not m or m.action=='back'then return elseif m.action=='add'then local e=newElement(domain);if e then page.elements[#page.elements+1]=e end
    elseif m.index then local i=m.index;local a=gui.menu('ELEMENT '..i,elementSummary(page.elements[i]),{{label='Inspect / edit',action='edit'},{label='Duplicate',action='dup'},{label='Move up',action='up',disabled=i==1},{label='Move down',action='down',disabled=i==#page.elements},{label='Delete',action='delete'},{label='Back',action='back'}})
      if a and a.action=='edit'then inspectElement(domain,page.elements[i])elseif a and a.action=='dup'then table.insert(page.elements,i+1,util.deepcopy(page.elements[i]))elseif a and a.action=='up'and i>1 then page.elements[i],page.elements[i-1]=page.elements[i-1],page.elements[i]elseif a and a.action=='down'and i<#page.elements then page.elements[i],page.elements[i+1]=page.elements[i+1],page.elements[i]elseif a and a.action=='delete'and gui.confirm('DELETE ELEMENT','Delete '..elementSummary(page.elements[i])..'?')then table.remove(page.elements,i)end
    end
  end
end

local function pageEditor(domain,path,page)
  while true do
    local m=gui.menu('FREEFORM PAGE: '..path,tostring(page.title or'Untitled')..'  |  '..tostring(#(page.elements or{}))..' element(s)',{
      {label='Preview draft',action='preview'},
      {label='Elements / inspector',action='elements'},
      {label='Page title',action='title'},
      {label='Page background',action='bg'},
      {label='Raw page table',action='raw'},
      {label='Save draft',action='save'},
      {label='Back',action='back'}})
    if not m or m.action=='back'then return
    elseif m.action=='preview'then preview(domain,page)
    elseif m.action=='elements'then elements(domain,page)
    elseif m.action=='title'then page.title=gui.prompt('PAGE TITLE','Title:',page.title or'Untitled')
    elseif m.action=='bg'then page.background=chooseColor('PAGE BACKGROUND',page.background or C.black)
    elseif m.action=='raw'then local x,ok=editSerialized('RAW PAGE TABLE',page);if ok then page=x end
    elseif m.action=='save'then if savePage(domain,path,page)then gui.toast('Draft saved',1)end end
  end
end

local function pages(domain,site)
  while true do
    local got,e=net.call('web','getSite',{domain=domain});if not got then gui.toast(e,2);return end;site=got.site
    local paths={};for p in pairs((site.draft or{}).pages or{})do paths[#paths+1]=p end;table.sort(paths)
    local items={{label='+ New freeform page',action='new'}};for _,p in ipairs(paths)do local pg=site.draft.pages[p];items[#items+1]={label=p..'  |  '..tostring(pg.title or'Untitled')..'  |  '..tostring(#(pg.elements or{}))..' elements',path=p}end;items[#items+1]={label='Back',action='back'}
    local m=gui.menu('ADVANCED PAGES','Exact coordinates, renderer elements and raw tables.',items)
    if not m or m.action=='back'then return elseif m.action=='new'then local p=gui.prompt('NEW PAGE','Path:','/new');if p~=''then if p:sub(1,1)~='/'then p='/'..p end;local pg=templates.blank(gui.prompt('NEW PAGE','Title:','New Page'));if savePage(domain,p,pg)then gui.toast('Draft page created',1)end end elseif m.path then pageEditor(domain,m.path,util.deepcopy(site.draft.pages[m.path]))end
  end
end

local function scripts(domain,site)
  local client=site.clientScript or'';local server=site.serverScript or''
  while true do
    local m=gui.menu('SPAWNSCRIPT: '..domain,'Edit hosted client and server scripts with the built-in full-screen editor.',{
      {label='Edit client script  ('..tostring(#client)..' chars)',action='client'},
      {label='Edit server script  ('..tostring(#server)..' chars)',action='server'},
      {label='Save both scripts to draft',action='save'},
      {label='Open SpawnScript manual',action='wiki'},
      {label='Back',action='back'}})
    if not m or m.action=='back'then return elseif m.action=='client'then local x=gui.editor('CLIENT SPAWNSCRIPT',client);if x~=nil then client=x end elseif m.action=='server'then local x=gui.editor('SERVER SPAWNSCRIPT',server);if x~=nil then server=x end elseif m.action=='save'then local p,e=net.call('web','saveScripts',{domain=domain,clientScript=client,serverScript=server});gui.toast(p and'Scripts saved to draft'or e,2)elseif m.action=='wiki'then shell.run('/spawnnet/client/browser.lua','spn://wiki/spawnscript')end
  end
end

local function revisions(domain)
  while true do
    local p,e=net.call('web','history',{domain=domain});if not p then gui.toast(e,2);return end
    local items={};for _,r in ipairs(p.revisions or{})do items[#items+1]={label=tostring(r.id)..'  |  '..tostring(r.note or'(no note)'),rev=r}end;items[#items+1]={label='Back',action='back'}
    local m=gui.menu('REVISION HISTORY','Restore creates a draft. It does not publish automatically.',items)
    if not m or m.action=='back'then return elseif m.rev then local a=gui.menu('REVISION '..tostring(m.rev.id),tostring(m.rev.note or''),{{label='Restore into draft',action='restore'},{label='Back',action='back'}});if a and a.action=='restore'and gui.confirm('RESTORE REVISION','Replace the current draft with revision '..tostring(m.rev.id)..'?')then local q,er=net.call('web','restore',{domain=domain,id=m.rev.id});gui.toast(q and'Restored into draft'or er,2)end end
  end
end

local function analytics(domain)
  local a,e=net.call('web','analytics',{domain=domain});if not a then gui.toast(e,2);return end
  local lines={'Views: '..tostring(a.analytics.views or 0),'Unique computers: '..tostring(a.analytics.unique or 0),'','PAGE VIEWS'};local arr={};for p,n in pairs(a.analytics.pages or{})do arr[#arr+1]={p=p,n=n}end;table.sort(arr,function(x,y)return x.n>y.n end);for _,x in ipairs(arr)do lines[#lines+1]=tostring(x.n)..'  '..x.p end;gui.viewer('SITE ANALYTICS',table.concat(lines,'\n'),{meta='spn://'..domain})
end

local function settings(domain,site)
  local title=gui.prompt('SITE SETTINGS','Title:',site.title or domain);local desc=gui.editor('SITE DESCRIPTION',site.description or'');if desc==nil then return end;local tags=gui.prompt('SITE SETTINGS','Tags, comma-separated:',table.concat(site.tags or{},','));local ta={};for x in tags:gmatch('[^,]+')do ta[#ta+1]=util.trim(x)end;local p,e=net.call('web','settings',{domain=domain,title=title,description=desc,tags=ta});gui.toast(p and'Settings saved'or e,2)
end

local function dashboard(domain)
  while true do
    local got,e=net.call('web','getSite',{domain=domain});if not got then gui.toast(e,2);return end;local site=got.site;local pageCount=0;for _ in pairs((site.draft or{}).pages or{})do pageCount=pageCount+1 end
    local m=gui.menu('ADVANCED STUDIO: '..domain,tostring(site.title or domain)..'  |  '..pageCount..' pages',{
      {label='Pages / freeform designer',action='pages'},
      {label='SpawnScript',action='scripts'},
      {label='Assets / images',action='assets'},
      {label='Revision history',action='revisions'},
      {label='Analytics',action='analytics'},
      {label='Site settings',action='settings'},
      {label='Publish current draft',action='publish'},
      {label='Open API Explorer',action='api'},
      {label='Back',action='back'}},{right='POWER USER'})
    if not m or m.action=='back'then return elseif m.action=='pages'then pages(domain,site)elseif m.action=='scripts'then scripts(domain,site)elseif m.action=='assets'then assets.run(domain)elseif m.action=='revisions'then revisions(domain)elseif m.action=='analytics'then analytics(domain)elseif m.action=='settings'then settings(domain,site)elseif m.action=='publish'then local note=gui.prompt('PUBLISH','Revision note:','Advanced Studio update');local p,er=net.call('web','publish',{domain=domain,note=note});gui.toast(p and'Published successfully'or er,2)elseif m.action=='api'then shell.run('/spawnnet/client/dev_api.lua')end
  end
end

if not login()then return end
while true do
  local p,e=net.call('dns','listMine',{});if not p then gui.toast(e,2);return end
  local items={};for _,d in ipairs(p.domains or{})do items[#items+1]={label=tostring(d.domain)..'  |  '..tostring(d.title or''),domain=d.domain}end;items[#items+1]={label='Open no-code Studio',action='easy'};items[#items+1]={label='Back to Developer Workbench',action='back'}
  local m=gui.menu('ADVANCED STUDIO','Freeform renderer, raw tables, SpawnScript, revisions and analytics.',items,{right=net.activeNetwork().name})
  if not m or m.action=='back'then break elseif m.action=='easy'then shell.run('/spawnnet/client/studio_easy.lua')elseif m.domain then dashboard(m.domain)end
end
gui.clear()
]=],
  ["/spawnnet/client/studio_easy.lua"]=[==[local gui=dofile('/spawnnet/client/gui.lua')
local net=dofile('/spawnnet/client/net.lua')
local auth=dofile('/spawnnet/client/auth_client.lua')
local util=dofile('/spawnnet/lib/util.lua')
local C=colors

local themes={
  midnight={name='Midnight',bg=C.black,panel=C.gray,accent=C.blue,text=C.white,muted=C.lightGray,title=C.yellow},
  terminal={name='Terminal',bg=C.black,panel=C.gray,accent=C.green,text=C.lime,muted=C.lightGray,title=C.lime},
  ocean={name='Ocean',bg=C.blue,panel=C.gray,accent=C.cyan,text=C.white,muted=C.lightBlue,title=C.yellow},
  royal={name='Royal',bg=C.black,panel=C.purple,accent=C.magenta,text=C.white,muted=C.lightGray,title=C.yellow},
  warm={name='Warm',bg=C.brown,panel=C.gray,accent=C.orange,text=C.white,muted=C.lightGray,title=C.yellow},
}

local function login()
  if net.loadSession() then local me=net.call('users','me',{});if me then return true end end
  local u=gui.prompt('STUDIO LOGIN','Username:','');if u=='' then return false end
  local pw=gui.prompt('STUDIO LOGIN','Password:','','*');local s,e=auth.login(u,pw)
  if not s then gui.toast(e,2);return false end;return true
end

local function blockId(blocks)
  local used={};for _,b in ipairs(blocks or{})do if b.id then used[b.id]=true end end
  local n=1;while used['block'..n]do n=n+1 end;return 'block'..n
end

local function textHeight(text,width,max)
  local n=#gui.wrap(text,width);return math.max(1,math.min(max or 12,n))
end

local function renderPage(page,siteTitle)
  local easy=page.easy or{};local t=themes[easy.theme]or themes.midnight;local elements={}
  elements[#elements+1]={type='panel',id='easy_header',x=1,y=1,w='100%',h=3,bg=t.panel,children={
    {type='heading',x=2,y=1,w=47,h=1,text=page.title or siteTitle or'Untitled',fg=t.title,bg=t.panel,align='center'},
    {type='text',x=2,y=2,w=47,h=1,text=siteTitle or'',fg=t.muted,bg=t.panel,align='center'},
  }}
  local y=5
  for _,b in ipairs(easy.blocks or{})do
    local id=b.id
    if b.kind=='heading'then elements[#elements+1]={type='heading',id=id,x=3,y=y,w=45,h=1,text=b.text or'Heading',fg=b.fg or t.title,bg=t.bg,align=b.align or'left'};y=y+2
    elseif b.kind=='text'then local h=textHeight(b.text or'',45,14);elements[#elements+1]={type='text',id=id,x=3,y=y,w=45,h=h,text=b.text or'',fg=b.fg or t.text,bg=t.bg,align=b.align or'left'};y=y+h+1
    elseif b.kind=='button'then elements[#elements+1]={type='button',id=id,x=3,y=y,w=45,h=1,text=b.text or'Open',fg=C.white,bg=b.bg or t.accent,action=util.deepcopy(b.action or{type='navigate',target=b.target or'/'})};y=y+2
    elseif b.kind=='image'then local h=math.max(2,math.min(12,tonumber(b.h)or 6));elements[#elements+1]={type='image',id=id,x=3,y=y,w=45,h=h,src=b.src or''};y=y+h+1
    elseif b.kind=='separator'then elements[#elements+1]={type='separator',id=id,x=3,y=y,w=45,h=1,char=b.char or'-',fg=b.fg or t.muted,bg=t.bg};y=y+2
    elseif b.kind=='badge'then elements[#elements+1]={type='badge',id=id,x=3,y=y,w=45,h=1,text=b.text or'Badge',fg=C.white,bg=b.bg or t.accent,align='center'};y=y+2
    elseif b.kind=='input'then elements[#elements+1]={type='input',id=id,x=3,y=y,w=45,h=1,value=b.value or'',placeholder=b.placeholder or'Type here...',fg=t.text,bg=C.gray};y=y+2
    elseif b.kind=='checkbox'then elements[#elements+1]={type='checkbox',id=id,x=3,y=y,w=45,h=1,text=b.text or'Option',checked=b.checked==true,fg=t.text,bg=t.bg};y=y+2
    elseif b.kind=='progress'then elements[#elements+1]={type='progress',id=id,x=3,y=y,w=45,h=1,value=tonumber(b.value)or 0,max=tonumber(b.max)or 100,fg=b.fg or t.accent,bg=t.bg};y=y+2
    elseif b.kind=='list'then local items=b.items or{};local h=math.max(1,math.min(12,#items));elements[#elements+1]={type='list',id=id,x=3,y=y,w=45,h=h,items=util.deepcopy(items),bullet=b.bullet or'- ',fg=t.text,bg=t.bg};y=y+h+1
    elseif b.kind=='table'then local rows=b.rows or{};local h=math.max(1,math.min(12,#rows));elements[#elements+1]={type='table',id=id,x=3,y=y,w=45,h=h,rows=util.deepcopy(rows),widths=util.deepcopy(b.widths),fg=t.text,bg=t.bg};y=y+h+1 end
  end
  page.background=t.bg;page.elements=elements;return page
end

local function newEasyPage(title,theme,blocks)
  local p={title=title or'New Page',easy={version=2,theme=theme or'midnight',blocks=blocks or{}}}
  return renderPage(p,title)
end

local function savePage(domain,pagePath,page,siteTitle)
  renderPage(page,siteTitle)
  local p,e=net.call('web','savePage',{domain=domain,path=pagePath,page=page})
  if not p then gui.toast(e,2);return false end;return true
end

local function chooseTheme(current)
  local items={};for id,t in pairs(themes)do items[#items+1]={label=(id==current and'* 'or'  ')..t.name,id=id}end
  table.sort(items,function(a,b)return a.label<b.label end);local m=gui.menu('PAGE THEME','Choose a clean color preset.',items);return m and m.id or current
end

local function assets(domain)
  while true do
    local p,e=net.call('web','listAssets',{domain=domain});if not p then gui.toast(e,2);return end
    local items={{label='+ Upload image / asset',action='upload'}}
    for _,a in ipairs(p.assets or{})do items[#items+1]={label=a.name..'  '..tostring(a.size)..' bytes',asset=a}end
    items[#items+1]={label='Back',action='back'}
    local m=gui.menu('ASSETS: '..domain,'Upload NFP images or other site files.',items)
    if not m or m.action=='back'then return
    elseif m.action=='upload'then
      local path=gui.prompt('UPLOAD ASSET','Local file path:','');if path~=''and fs.exists(path)and not fs.isDir(path)then
        local name=gui.prompt('UPLOAD ASSET','Asset name:',fs.getName(path));local mime=gui.prompt('UPLOAD ASSET','Type:','image/nfp')
        local q,er=net.call('web','putAsset',{domain=domain,name=name,mime=mime,data=util.readFile(path)});gui.toast(q and'Uploaded '..name or er,2)
      elseif path~=''then gui.toast('File not found',2)end
    elseif m.asset then
      local a=gui.menu('ASSET: '..m.asset.name,tostring(m.asset.size)..' bytes',{{label='Delete asset',action='delete'},{label='Back',action='back'}})
      if a and a.action=='delete'and gui.confirm('DELETE ASSET','Delete '..m.asset.name..'?')then net.call('web','deleteAsset',{domain=domain,name=m.asset.name})end
    end
  end
end

local function chooseAsset(domain)
  local p,e=net.call('web','listAssets',{domain=domain});if not p then gui.toast(e,2);return nil end
  local items={};for _,a in ipairs(p.assets or{})do items[#items+1]={label=a.name..'  ['..tostring(a.mime or'?')..']',name=a.name}end
  items[#items+1]={label='+ Upload first',upload=true};items[#items+1]={label='Cancel',cancel=true}
  local m=gui.menu('CHOOSE IMAGE','NFP images render directly in the browser.',items)
  if not m or m.cancel then return nil elseif m.upload then assets(domain);return chooseAsset(domain)end;return m.name
end

local function splitLines(s)
  local out={};for line in (tostring(s or'')..'\n'):gmatch('(.-)\n')do if line~=''then out[#out+1]=line end end;return out
end
local function splitTable(s)
  local rows={};for line in (tostring(s or'')..'\n'):gmatch('(.-)\n')do if line~=''then local row={};for cell in (line..'|'):gmatch('(.-)|')do row[#row+1]=cell end;rows[#rows+1]=row end end;return rows
end

local function editBlock(domain,b)
  if b.kind=='heading'then local v=gui.prompt('EDIT HEADING','Heading text:',b.text or'');if v~=nil then b.text=v end
  elseif b.kind=='text'then local v=gui.editor('EDIT PARAGRAPH',b.text or'');if v~=nil then b.text=v end
  elseif b.kind=='button'then
    b.text=gui.prompt('EDIT BUTTON','Button label:',b.text or'Open')
    local m=gui.menu('BUTTON ACTION','What should this button do?',{{label='Open page / address',action='nav'},{label='Open SpawnNet search',action='search'},{label='Cancel',action='cancel'}})
    if m and m.action=='nav'then b.target=gui.prompt('BUTTON LINK','Target, e.g. /about or spn://wiki: ',b.target or'/');b.action={type='navigate',target=b.target}
    elseif m and m.action=='search'then b.action={type='search'}end
  elseif b.kind=='image'then local src=chooseAsset(domain);if src then b.src=src end;b.h=tonumber(gui.prompt('IMAGE','Image height in rows:',tostring(b.h or 6)))or 6
  elseif b.kind=='separator'then b.char=(gui.prompt('DIVIDER','Character:',b.char or'-'):sub(1,1));if b.char==''then b.char='-'end
  elseif b.kind=='badge'then b.text=gui.prompt('EDIT BADGE','Badge text:',b.text or'Badge')
  elseif b.kind=='input'then b.placeholder=gui.prompt('EDIT INPUT','Placeholder:',b.placeholder or'Type here...')
  elseif b.kind=='checkbox'then b.text=gui.prompt('EDIT CHECKBOX','Label:',b.text or'Option')
  elseif b.kind=='progress'then b.value=tonumber(gui.prompt('EDIT PROGRESS','Current value:',tostring(b.value or 0)))or 0;b.max=tonumber(gui.prompt('EDIT PROGRESS','Maximum:',tostring(b.max or 100)))or 100
  elseif b.kind=='list'then local v=gui.editor('EDIT LIST',table.concat(b.items or{},'\n'));if v~=nil then b.items=splitLines(v)end
  elseif b.kind=='table'then
    local lines={};for _,r in ipairs(b.rows or{})do lines[#lines+1]=table.concat(r,'|')end
    local v=gui.editor('EDIT TABLE - use | between columns',table.concat(lines,'\n'));if v~=nil then b.rows=splitTable(v)end
  end
end

local function newBlock(domain,blocks)
  local m=gui.menu('ADD CONTENT','Everything here is no-code and can be reordered later.',{
    {label='Heading',kind='heading'},{label='Paragraph / multi-line text',kind='text'},{label='Button / hyperlink',kind='button'},
    {label='Image from site assets',kind='image'},{label='Divider',kind='separator'},{label='Badge / callout',kind='badge'},
    {label='Input field',kind='input'},{label='Checkbox',kind='checkbox'},{label='Progress bar',kind='progress'},
    {label='List',kind='list'},{label='Table',kind='table'},{label='Cancel',cancel=true}})
  if not m or m.cancel then return nil end
  local b={kind=m.kind,id=blockId(blocks)}
  if b.kind=='heading'then b.text=gui.prompt('ADD HEADING','Text:','New Heading')
  elseif b.kind=='text'then local v=gui.editor('ADD PARAGRAPH','Write as many lines as you need.');if v==nil then return nil end;b.text=v
  elseif b.kind=='button'then b.text=gui.prompt('ADD BUTTON','Label:','Open page');b.target=gui.prompt('ADD BUTTON','Target:','/');b.action={type='navigate',target=b.target}
  elseif b.kind=='image'then b.src=chooseAsset(domain);if not b.src then return nil end;b.h=tonumber(gui.prompt('ADD IMAGE','Height in rows:','6'))or 6
  elseif b.kind=='separator'then b.char='-'
  elseif b.kind=='badge'then b.text=gui.prompt('ADD BADGE','Text:','Important')
  elseif b.kind=='input'then b.placeholder=gui.prompt('ADD INPUT','Placeholder:','Type here...')
  elseif b.kind=='checkbox'then b.text=gui.prompt('ADD CHECKBOX','Label:','Option')
  elseif b.kind=='progress'then b.value=50;b.max=100
  elseif b.kind=='list'then local v=gui.editor('ADD LIST','First item\nSecond item\nThird item');if v==nil then return nil end;b.items=splitLines(v)
  elseif b.kind=='table'then local v=gui.editor('ADD TABLE - use | between columns','Name|Value\nExample|123');if v==nil then return nil end;b.rows=splitTable(v)end
  return b
end

local function blockLabel(b,i)
  local s=b.kind
  if b.kind=='heading'or b.kind=='text'or b.kind=='badge'or b.kind=='checkbox'then s=s..': '..tostring(b.text or'')
  elseif b.kind=='button'then s='button: '..tostring(b.text or'')..' -> '..tostring(b.target or'')
  elseif b.kind=='image'then s='image: '..tostring(b.src or'')
  elseif b.kind=='input'then s='input: '..tostring(b.placeholder or'')
  elseif b.kind=='list'then s='list: '..tostring(#(b.items or{}))..' item(s)'
  elseif b.kind=='table'then s='table: '..tostring(#(b.rows or{}))..' row(s)'end
  return tostring(i)..'. '..s
end

local function editBlocks(domain,path,page,siteTitle)
  page.easy=page.easy or{version=2,theme='midnight',blocks={}};page.easy.blocks=page.easy.blocks or{}
  while true do
    local blocks=page.easy.blocks;local items={{label='+ Add content block',action='add'}}
    for i,b in ipairs(blocks)do items[#items+1]={label=blockLabel(b,i),block=i}end
    items[#items+1]={label='Back',action='back'}
    local m=gui.menu('PAGE CONTENT: '..path,'Blocks flow top-to-bottom automatically. No coordinates.',items)
    if not m or m.action=='back'then savePage(domain,path,page,siteTitle);return
    elseif m.action=='add'then local b=newBlock(domain,blocks);if b then blocks[#blocks+1]=b;savePage(domain,path,page,siteTitle)end
    elseif m.block then
      local i=m.block;local b=blocks[i];local a=gui.menu('BLOCK '..i..': '..b.kind,blockLabel(b,i),{{label='Edit',action='edit'},{label='Move up',action='up',disabled=i==1},{label='Move down',action='down',disabled=i==#blocks},{label='Delete',action='delete'},{label='Back',action='back'}})
      if a and a.action=='edit'then editBlock(domain,b);savePage(domain,path,page,siteTitle)
      elseif a and a.action=='up'and i>1 then blocks[i],blocks[i-1]=blocks[i-1],blocks[i];savePage(domain,path,page,siteTitle)
      elseif a and a.action=='down'and i<#blocks then blocks[i],blocks[i+1]=blocks[i+1],blocks[i];savePage(domain,path,page,siteTitle)
      elseif a and a.action=='delete'and gui.confirm('DELETE BLOCK','Delete this '..b.kind..' block?')then table.remove(blocks,i);savePage(domain,path,page,siteTitle)end
    end
  end
end

local function importPage(old)
  local blocks={}
  local function walk(arr)
    for _,e in ipairs(arr or{})do
      local b=nil
      if e.type=='heading'then b={kind='heading',text=e.text}
      elseif e.type=='text'then b={kind='text',text=e.text}
      elseif e.type=='button'then b={kind='button',text=e.text or e.label,target=e.action and e.action.target,action=e.action}
      elseif e.type=='image'then b={kind='image',src=e.src,h=e.h}
      elseif e.type=='separator'then b={kind='separator',char=e.char}
      elseif e.type=='badge'then b={kind='badge',text=e.text}
      elseif e.type=='input'then b={kind='input',placeholder=e.placeholder,value=e.value}
      elseif e.type=='checkbox'then b={kind='checkbox',text=e.text,checked=e.checked}
      elseif e.type=='progress'then b={kind='progress',value=e.value,max=e.max}
      elseif e.type=='list'then b={kind='list',items=util.deepcopy(e.items or{})}
      elseif e.type=='table'then b={kind='table',rows=util.deepcopy(e.rows or{}),widths=util.deepcopy(e.widths)}end
      if b then b.id=blockId(blocks);blocks[#blocks+1]=b end
      if e.children then walk(e.children)end
    end
  end
  walk(old.elements);return {title=old.title or'Page',easy={version=2,theme='midnight',blocks=blocks}}
end

local function pageEditor(domain,path,page,site)
  if not page.easy then
    local m=gui.menu('FREEFORM PAGE',path..' was made with the old or Advanced editor.',{{label='Preview',action='preview'},{label='Import visible content into Easy Editor',action='import'},{label='Open Advanced Studio',action='advanced'},{label='Back',action='back'}})
    if not m or m.action=='back'then return elseif m.action=='preview'then shell.run('/spawnnet/client/browser.lua','spn://'..domain..path);return
    elseif m.action=='advanced'then shell.run('/spawnnet/client/studio_advanced.lua');return
    elseif m.action=='import'then if not gui.confirm('IMPORT PAGE','Easy Editor will rebuild this page as a flowing block layout. Your published version is unchanged until you publish. Continue?')then return end;page=importPage(page);savePage(domain,path,page,site.title)end
  end
  while true do
    local count=#((page.easy and page.easy.blocks)or{})
    local m=gui.menu('EDIT PAGE: '..path,(page.title or'Page')..'  |  '..count..' content block(s)',{{label='Content blocks',action='blocks'},{label='Page title',action='title'},{label='Theme / colors',action='theme'},{label='Preview draft layout',action='preview'},{label='Add page-link button',action='link'},{label='Delete page',action='delete',disabled=path=='/'},{label='Back',action='back'}})
    if not m or m.action=='back'then return
    elseif m.action=='blocks'then editBlocks(domain,path,page,site.title)
    elseif m.action=='title'then page.title=gui.prompt('PAGE TITLE','Title:',page.title or'Page');savePage(domain,path,page,site.title)
    elseif m.action=='theme'then page.easy.theme=chooseTheme(page.easy.theme);savePage(domain,path,page,site.title)
    elseif m.action=='preview'then savePage(domain,path,page,site.title);shell.run('/spawnnet/client/browser.lua','spn://'..domain..path)
    elseif m.action=='link'then local b={kind='button',id=blockId(page.easy.blocks),text=gui.prompt('PAGE LINK','Button label:','Open page'),target=gui.prompt('PAGE LINK','Target path or URL:','/'),action={type='navigate'}};b.action.target=b.target;page.easy.blocks[#page.easy.blocks+1]=b;savePage(domain,path,page,site.title)
    elseif m.action=='delete'then if gui.confirm('DELETE PAGE','Delete draft page '..path..'?')then local p,e=net.call('web','deletePage',{domain=domain,path=path});gui.toast(p and'Page deleted' or e,2);return end end
  end
end

local function createPage(domain,site)
  local path=gui.prompt('NEW PAGE','Path, e.g. /about:','/new-page');if path==''then return end;if path:sub(1,1)~='/'then path='/'..path end
  local title=gui.prompt('NEW PAGE','Page title:','New Page');local theme='midnight'
  local p=newEasyPage(title,theme,{{kind='heading',id='block1',text=title},{kind='text',id='block2',text='Start writing here.'},{kind='button',id='block3',text='Back to home',target='/',action={type='navigate',target='/'}}})
  if savePage(domain,path,p,site.title)then gui.toast('Page added to draft',1)end
end

local function pages(domain,site)
  while true do
    local got,e=net.call('web','getSite',{domain=domain});if not got then gui.toast(e,2);return end;site=got.site
    local paths={};for p in pairs((site.draft or{}).pages or{})do paths[#paths+1]=p end;table.sort(paths)
    local items={{label='+ New page',action='new'}};for _,p in ipairs(paths)do local pg=site.draft.pages[p];items[#items+1]={label=p..'  -  '..tostring(pg.title or'Untitled'),path=p}end;items[#items+1]={label='Back',action='back'}
    local m=gui.menu('PAGES: '..domain,tostring(#paths)..' draft page(s)',items)
    if not m or m.action=='back'then return elseif m.action=='new'then createPage(domain,site)elseif m.path then pageEditor(domain,m.path,site.draft.pages[m.path],site)end
  end
end

local function contactWizard(domain,site)
  local path=gui.prompt('CONTACT FORM','Page path:','/contact');if path==''then return end;if path:sub(1,1)~='/'then path='/'..path end
  local p={title='Contact '..tostring(site.title or domain),background=C.black,elements={
    {type='heading',x=3,y=2,w=45,h=1,text='CONTACT',fg=C.yellow},{type='text',x=3,y=5,w=45,h=2,text='Send a message to the owner of this site.'},
    {type='input',id='contactName',x=3,y=8,w=45,placeholder='Your name'},{type='input',id='contactMsg',x=3,y=10,w=45,placeholder='Message'},
    {type='button',x=3,y=13,w=22,text='SEND',bg=C.lime,fg=C.black,action={type='server',event='easy_contact_submit'}},{type='button',x=27,y=13,w=22,text='HOME',action={type='navigate',target='/'}},
    {type='text',id='contactStatus',x=3,y=16,w=45,h=2,text='Ready.'}}}
  local source=tostring(site.serverScript or'')
  if not source:find('event easy_contact_submit',1,true)then source=source..[=[

event easy_contact_submit
  call site.owner -> owner
  call mail.send $owner "Website contact" "${input.contactName}: ${input.contactMsg}" -> mailid
  call ui.setText "contactStatus" "Message sent. Mail ID: ${mailid}"
  call ui.alert "Delivered through SpawnNet Mail"
end
]=]end
  local a,e=net.call('web','savePage',{domain=domain,path=path,page=p});if not a then gui.toast(e,2);return end
  local b,er=net.call('web','saveScripts',{domain=domain,clientScript=site.clientScript or'',serverScript=source});gui.toast(b and'Contact form added to draft' or er,2)
end

local function settings(domain,site)
  local title=gui.prompt('SITE SETTINGS','Site title:',site.title or domain);local desc=gui.editor('SITE DESCRIPTION',site.description or'');if desc==nil then desc=site.description or''end
  local tags=gui.prompt('SITE SETTINGS','Tags, comma separated:',table.concat(site.tags or{},','));local arr={};for t in tags:gmatch('[^,]+')do arr[#arr+1]=util.trim(t)end
  local p,e=net.call('web','settings',{domain=domain,title=title,description=desc,tags=arr});gui.toast(p and'Settings saved' or e,2)
end

local function createSite()
  local domain=util.safeName(gui.prompt('CREATE WEBSITE','Domain (spn://____):',''),32);if domain==''then return end
  local title=gui.prompt('CREATE WEBSITE','Site title:',domain)
  local m=gui.menu('STARTER','Pick a starting point. You can change every block.',{{label='Personal / profile',kind='personal'},{label='Company / organization',kind='company'},{label='Wiki / knowledge base',kind='wiki'},{label='Dashboard / control panel',kind='dashboard'},{label='Blank page',kind='blank'}});if not m then return end
  local theme=chooseTheme('midnight')or'midnight';local intro=gui.editor('HOME PAGE INTRO','Welcome to '..title..'.\n\nUse Studio to add text, images, buttons, lists, forms and more.');if intro==nil then return end
  local p,e=net.call('dns','register',{domain=domain,title=title});if not p then gui.toast(e,2);return end
  local blocks={{kind='heading',id='block1',text=title},{kind='text',id='block2',text=intro}}
  if m.kind~='blank'then blocks[#blocks+1]={kind='badge',id=blockId(blocks),text=m.kind:upper()}end
  blocks[#blocks+1]={kind='button',id=blockId(blocks),text='About',target='/about',action={type='navigate',target='/about'}}
  local home=newEasyPage(title,theme,blocks)
  if not savePage(domain,'/',home,title)then net.call('dns','release',{domain=domain});gui.toast('Website creation failed; empty domain rolled back.',2);return end
  local about=newEasyPage('About '..title,theme,{{kind='heading',id='block1',text='About'},{kind='text',id='block2',text='Tell visitors about this site.'},{kind='button',id='block3',text='Home',target='/',action={type='navigate',target='/'}}})
  if not savePage(domain,'/about',about,title)then net.call('dns','release',{domain=domain});gui.toast('Website creation failed; empty domain rolled back.',2);return end
  local setOk,setErr=net.call('web','settings',{domain=domain,title=title,description='Built with SpawnNet Studio',tags={m.kind,'spawnnet'}})
  if not setOk then net.call('dns','release',{domain=domain});gui.toast(setErr or'Website setup failed; domain rolled back.',2);return end
  local pub,pe=net.call('web','publish',{domain=domain,note='Created with SpawnNet Studio 2.1'});if not pub then gui.toast('Draft saved but publish failed: '..tostring(pe),3);return end
  gui.clear();gui.bar('WEBSITE PUBLISHED');gui.text(3,6,45,'Your site is live:',C.lime,C.black,'center');gui.text(3,8,45,'spn://'..domain,C.yellow,C.black,'center');gui.paragraph(3,11,45,4,'Open it now, or keep editing pages and content blocks. Nothing in Easy Studio requires Lua.',C.lightGray,C.black);gui.status('Press any key');os.pullEvent('key')
end

local function editSite(domain)
  while true do
    local got,e=net.call('web','getSite',{domain=domain});if not got then gui.toast(e,2);return end;local site=got.site;local pagesCount=0;for _ in pairs((site.draft or{}).pages or{})do pagesCount=pagesCount+1 end
    local m=gui.menu('STUDIO: '..domain,tostring(site.title or domain)..'  |  '..pagesCount..' page(s)',{{label='Pages & page editor',action='pages'},{label='Images & assets',action='assets'},{label='Add contact form',action='contact'},{label='Site settings',action='settings'},{label='Preview published site',action='preview'},{label='Publish draft',action='publish'},{label='Advanced Studio / scripts / raw layout',action='advanced'},{label='Back',action='back'}})
    if not m or m.action=='back'then return
    elseif m.action=='pages'then pages(domain,site)
    elseif m.action=='assets'then assets(domain)
    elseif m.action=='contact'then contactWizard(domain,site)
    elseif m.action=='settings'then settings(domain,site)
    elseif m.action=='preview'then shell.run('/spawnnet/client/browser.lua','spn://'..domain)
    elseif m.action=='publish'then local note=gui.prompt('PUBLISH','Revision note:','Updated in Studio');local p,er=net.call('web','publish',{domain=domain,note=note});gui.toast(p and'Published successfully' or er,2)
    elseif m.action=='advanced'then shell.run('/spawnnet/client/studio_advanced.lua')end
  end
end

if not login()then return end
while true do
  local p,e=net.call('dns','listMine',{});if not p then gui.toast(e,2);return end
  local items={{label='+ Create a website',action='create'}}
  for _,d in ipairs(p.domains or{})do items[#items+1]={label=d.domain..'  -  '..tostring(d.title or''),domain=d.domain}end
  items[#items+1]={label='Back to Desktop',action='back'}
  local m=gui.menu('SPAWNNET STUDIO','No-code block editor. Advanced Studio is always available.',items,{right=net.activeNetwork().name})
  if not m or m.action=='back'then break elseif m.action=='create'then createSite()elseif m.domain then editSite(m.domain)end
end
gui.clear()
]==],
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
  ["/spawnnet/client/updater.lua"]=[=[local net=dofile('/spawnnet/client/net.lua')
local util=dofile('/spawnnet/lib/util.lua')
local ui=dofile('/spawnnet/client/ui.lua')
local config=dofile('/spawnnet/lib/config.lua')

local name=(...) or 'client'
local manifest,e=net.call('package','manifest',{name=name},{noAuth=true})
if not manifest then ui.error(e); return end

print('Local:  '..tostring(config.version))
print('Server: '..tostring(manifest.version))
if name=='client' and tostring(manifest.version)==tostring(config.version) then
  print('Already up to date.')
  return
end

local p,err=net.call('package','get',{name=name},{noAuth=true})
if not p then ui.error(err); return end
local pkg=p.package
print('Installing '..name..' '..tostring(pkg.version)..' ...')

local count=0
for path,data in pairs(pkg.files or {}) do
  local target='/'..tostring(path):gsub('^/','')
  util.writeFile(target,data)
  count=count+1
  print('  '..target)
end

for _,old in ipairs({'/spawnnet/client/machines.lua','/spawnnet/client/warehouse_agent.lua','/spawnnet/client/apps_market.lua','/spawnnet/client/apps_auction.lua','/spawnnet/client/apps_bank.lua'})do if fs.exists(old)then pcall(fs.delete,old)end end
print('Updated '..count..' files.')
print('Restart SpawnNet commands to use '..tostring(pkg.version)..'.')
]=],
  ["/spawnnet/lib/config.lua"]=[=[return {
  version = "2.1.0-rc6",
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

-- ComputerCraft 1.8/CC:Tweaked's serializer rejects repeated table references,
-- even when they are not truly recursive. Network payloads are data, not object
-- graphs, so normalise them into a pure tree before serialisation. This also gives
-- callers a useful path when they accidentally try to send functions/userdata/etc.
local function cloneData(v,active,path)
  local tv=type(v)
  if tv=='nil' or tv=='string' or tv=='number' or tv=='boolean' then return v end
  if tv~='table' then return nil,'unsupported '..tv..' at '..tostring(path) end
  if active[v] then return nil,'recursive table at '..tostring(path) end
  active[v]=true
  local out={}
  for k,value in pairs(v) do
    local kt=type(k)
    if kt~='string' and kt~='number' and kt~='boolean' then
      active[v]=nil
      return nil,'unsupported '..kt..' table key at '..tostring(path)
    end
    local child,err=cloneData(value,active,tostring(path)..'['..tostring(k)..']')
    if err then active[v]=nil;return nil,err end
    out[k]=child
  end
  active[v]=nil
  return out
end

function M.prepare(message)
  return cloneData(message,{},'$')
end

function M.send(recipient,message,protocol)
  local clean,cleanErr=M.prepare(message)
  if not clean then return false,'serialize failed: '..tostring(cleanErr) end
  local ok,raw=pcall(textutils.serialize,clean)
  if not ok then return false,'serialize failed: '..tostring(raw) end
  if #raw>config.maxPacketBytes then return false,'logical packet too large ('..tostring(#raw)..' bytes)' end
  if #raw<=config.fragmentBytes then return rednet.send(recipient,clean,protocol) end
  local id=util.id('frag'); local total=math.ceil(#raw/config.fragmentBytes)
  for i=1,total do
    local chunk=raw:sub((i-1)*config.fragmentBytes+1,i*config.fragmentBytes)
    local env={network='spawnnet',version=config.packetVersion or 2,type='fragment',fragmentId=id,index=i,total=total,data=chunk}
    local okSend=rednet.send(recipient,env,protocol); if not okSend then return false,'fragment send failed' end
  end
  return true
end
function M.accept(sender,msg,buckets)
  if type(msg)~='table' or msg.network~='spawnnet' or msg.type~='fragment' then return msg end
  if type(msg.fragmentId)~='string' or type(msg.index)~='number' or type(msg.total)~='number' or type(msg.data)~='string' then return nil,nil,'malformed fragment' end
  if msg.total<1 or msg.total>math.ceil(config.maxPacketBytes/config.fragmentBytes)+2 or msg.index<1 or msg.index>msg.total then return nil,nil,'bad fragment range' end
  local key=tostring(sender)..':'..msg.fragmentId; local b=buckets[key]
  if not b then b={created=os.clock(),total=msg.total,parts={},count=0,bytes=0};buckets[key]=b end
  if b.total~=msg.total then buckets[key]=nil;return nil,nil,'fragment total mismatch' end
  if not b.parts[msg.index] then b.parts[msg.index]=msg.data;b.count=b.count+1;b.bytes=b.bytes+#msg.data end
  if b.bytes>config.maxPacketBytes then buckets[key]=nil;return nil,nil,'fragment payload too large' end
  if b.count==b.total then
    local chunks={};for i=1,b.total do if not b.parts[i]then return nil end;chunks[i]=b.parts[i]end;buckets[key]=nil
    local raw=table.concat(chunks);local ok,obj=pcall(textutils.unserialize,raw);if not ok or type(obj)~='table'then return nil,nil,'fragment decode failed'end;return obj,true
  end
  return nil,false
end
function M.purge(buckets)
  local now=os.clock();for k,b in pairs(buckets)do if now-(b.created or now)>config.fragmentTimeout then buckets[k]=nil end end
end
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

local oldCfg=nil;if fs.exists('/spawnnet/client.cfg')then local h=fs.open('/spawnnet/client.cfg','r');if h then local raw=h.readAll();h.close();oldCfg=textutils.unserialize(raw)end end
for path,data in pairs(files)do writeFile(path,data)end
local util=dofile('/spawnnet/lib/util.lua');local config=dofile('/spawnnet/lib/config.lua');local net=dofile('/spawnnet/client/net.lua')
term.clear();term.setCursorPos(1,1);print('SpawnNet Client Installer '..config.version);print('Desktop + Showcase Labs + Developer Workbench');print()
local cfg=util.loadTable(config.clientConfig,{transport='rednet',modem=nil,timeout=config.requestTimeout,wsUrl=nil});if oldCfg and oldCfg.serverId then local reg=util.loadTable(config.networkRegistry,{active='public',networks={}});reg.networks=reg.networks or{};reg.networks.public=reg.networks.public or{id='public',name='Public SpawnNet',visibility='public'};reg.networks.public.coreId=reg.networks.public.coreId or oldCfg.serverId;util.saveTable(config.networkRegistry,reg)end
write('Transport rednet/websocket ['..tostring(cfg.transport or'rednet')..']: ');local t=read();if t~=''then cfg.transport=t end;if cfg.transport~='rednet'and cfg.transport~='websocket'then error('Transport must be rednet or websocket')end
if cfg.transport=='websocket'then write('WebSocket URL ['..tostring(cfg.wsUrl or'')..']: ');local u=read();if u~=''then cfg.wsUrl=u end end;util.saveTable(config.clientConfig,cfg)
if cfg.transport=='rednet'then print();print('Discovering nearby SpawnNet 2 networks...');local found,e=net.discoverNetworks(1.5);if found then for _,n in ipairs(found)do print('  '..n.id..' - '..n.name..' ['..n.visibility..'] core #'..tostring(n.coreId))end else print('  Discovery failed: '..tostring(e))end end
local reg=net.registry();local active=reg.active or'public';write('Default network ['..active..']: ');local chosen=util.safeName(read(),32);if chosen~=''then if not reg.networks[chosen]then net.addNetwork({id=chosen,name=chosen})end;net.setActiveNetwork(chosen)end
local n=net.activeNetwork();if n.visibility=='private'and(not n.key or n.key=='')then write('Join code for '..n.name..': ');local key=read('*');net.addNetwork({id=n.id,name=n.name,visibility=n.visibility,coreId=n.coreId,key=key})end
net.clearAllSessions();if fs.exists('/spawnnet/session.db')then fs.delete('/spawnnet/session.db')end
writeFile('/spawnnet.lua',"local a={...};shell.run('/spawnnet/client/spawnnet.lua',unpack(a))\n");writeFile('/web.lua',"local a={...};shell.run('/spawnnet/client/browser.lua',a[1]or'spn://home')\n");writeFile('/studio.lua',"shell.run('/spawnnet/client/studio_easy.lua')\n")
cleanup({'/spawnnet/client/apps_market.lua','/spawnnet/client/apps_auction.lua','/spawnnet/client/apps_bank.lua','/spawnnet/client/machines.lua','/spawnnet/client/warehouse_agent.lua','/SpawnNet-1.0.1-Hotfix.lua','/hotfix102.lua'})
print();print('SpawnNet Client '..config.version..' installed.');print('Run: spawnnet');print('That opens the SpawnNet Desktop.');print('Diagnostics: spawnnet doctor');print('Network manager: spawnnet networks');print('API manual: spawnnet api');print('Future 2.x client releases: spawnnet update')
if running and fs.exists(running)then write('Delete this installer to reclaim disk space? Y/n: ');local ans=read():lower();if ans~='n'and ans~='no'then pcall(fs.delete,running);print('Installer deleted.')end end
