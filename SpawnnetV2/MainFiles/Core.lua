-- SpawnNet Unified Platform RC7 - Core Upgrade
-- In-place upgrade: preserves the existing RC6 Core, state, GUI and services.
local SERVICE=[==[-- SpawnNet package service - Unified Platform RC7
local util=dofile('/spawnnet/lib/util.lua')
local C=dofile('/spawnnet/server/services/common.lua')
local auth=dofile('/spawnnet/server/auth.lua')
local crypto=dofile('/spawnnet/lib/crypto.lua')
local M={}
local MAX_APP_FILES=64
local MAX_APP_FILE_BYTES=65536
local MAX_APP_TOTAL=220000
local MAX_SYSTEM_FILES=128
local MAX_SYSTEM_FILE_BYTES=131072
local MAX_SYSTEM_TOTAL=240000
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
  return crypto.sha256(table.concat(parts,'\0'))
end
local function appManifest(pkg)
  if not pkg then return nil end
  return {domain=pkg.domain,name=pkg.name,title=pkg.title,version=pkg.version,description=pkg.description,publisher=pkg.publisher,permissions=util.deepcopy(pkg.permissions or{}),entry=pkg.entry,service=pkg.service,commands=util.deepcopy(pkg.commands or{}),files=count(pkg.files),totalBytes=pkg.totalBytes or 0,hash=pkg.hash,published=pkg.published,updated=pkg.updated,runAfterInstall=pkg.runAfterInstall and true or false}
end
local function systemManifest(pkg)
  if not pkg then return nil end
  return {name=pkg.name,version=pkg.version,description=pkg.description,owner=pkg.owner,component=pkg.component or pkg.name,channel=pkg.channel or'stable',restartRequired=pkg.restartRequired and true or false,files=count(pkg.files),totalBytes=pkg.totalBytes or 0,hash=pkg.hash,published=pkg.published,updated=pkg.updated}
end
local function siteOwner(state,d,ctx)
  local s=state.sites and state.sites[d];return s and ctx and s.owner==ctx.user
end
local function appBucket(state,d)
  state.appPackages=state.appPackages or{};state.appPackages[d]=state.appPackages[d]or{};return state.appPackages[d]
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
local function publishSystem(state,p,ctx)
  if not auth.isAdmin(ctx)then return 403,nil,'Admin required'end
  local name=cleanName(p.name);if name==''then return 400,nil,'Package name required'end
  local version=C.cleanText(p.version or'',24);if version==''then return 400,nil,'Version required'end
  local files,e,total=normalizeFiles(p.files,MAX_SYSTEM_FILES,MAX_SYSTEM_FILE_BYTES,MAX_SYSTEM_TOTAL);if not files then return 400,nil,e end
  local pkg={name=name,version=version,description=C.cleanText(p.description or'',240),files=files,totalBytes=total,owner=ctx.user,component=C.cleanText(p.component or name,24),channel=C.cleanText(p.channel or'stable',16),restartRequired=p.restartRequired and true or false,published=util.now(),updated=util.now()}
  local old=state.packages and state.packages[name];if old and old.published then pkg.published=old.published end
  pkg.hash=systemHash(pkg);state.packages=state.packages or{};state.packages[name]=pkg
  return 201,{package=systemManifest(pkg)},true
end
local function stageCore(state,p,ctx)
  if not auth.isAdmin(ctx)then return 403,nil,'Admin required'end
  local name=cleanName(p.name or'core');if name~='core'then return 400,nil,'Only the core system package may be staged on the Core'end
  local pkg=state.packages and state.packages[name];if not pkg then return 404,nil,'Core update package not found'end
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
    if a=='manifest'then local pkg=bucket[name];if not pkg then return 404,nil,'Package not found'end;return 200,{package=appManifest(pkg)},false end
    if a=='get'then local pkg=bucket[name];if not pkg then return 404,nil,'Package not found'end;return 200,{package=util.deepcopy(pkg)},false end
    if a=='list'then local out={};for _,pkg in pairs(bucket)do out[#out+1]=appManifest(pkg)end;table.sort(out,function(x,y)return tostring(x.title)<tostring(y.title)end);return 200,{domain=d,packages=out},false end
    if a=='publish'then return publishApp(state,p,ctx)end
    if a=='delete'then if not siteOwner(state,d,ctx)then return 403,nil,'Only the site owner can delete application packages'end;if not bucket[name]then return 404,nil,'Package not found'end;bucket[name]=nil;return 200,{deleted=name},true end
    return 404,nil,'Unknown package action'
  end
  state.packages=state.packages or{}
  if a=='manifest'then local name=cleanName(p.name or'client');local pkg=state.packages[name];if not pkg then return 404,nil,'Package not found'end;return 200,{package=systemManifest(pkg),name=name,version=pkg.version,description=pkg.description,files=count(pkg.files)},false end
  if a=='get'then local name=cleanName(p.name or'client');local pkg=state.packages[name];if not pkg then return 404,nil,'Package not found'end;return 200,{package=util.deepcopy(pkg)},false end
  if a=='listSystem'then local out={};for _,pkg in pairs(state.packages)do out[#out+1]=systemManifest(pkg)end;table.sort(out,function(x,y)return tostring(x.name)<tostring(y.name)end);return 200,{packages=out},false end
  if a=='publish'then return publishSystem(state,p,ctx)end
  if a=='stageCore'then return stageCore(state,p,ctx)end
  return 404,nil,'Unknown package action'
end
return M
]==]
local NODE_BRANCH=[==[  elseif msg.type=='node_update_manifest' or msg.type=='node_update_get' then -- SPAWNNET_RC7_NODE_UPDATE
    local n=state.nodes[sid]
    if not(n and n.approved and n.token==msg.token)then return true,false end
    local pkg=state.packages and state.packages['node']
    local res={network='spawnnet',version=2,type='node_update_response',networkId=M._networkId,requestId=msg.requestId,token=msg.token,ok=false}
    if not pkg then res.error='Node update package not published'
    else
      res.ok=true
      if msg.type=='node_update_manifest'then
        local files=0;for _ in pairs(pkg.files or{})do files=files+1 end
        res.package={name=pkg.name or'node',version=pkg.version,description=pkg.description,component=pkg.component or'node',channel=pkg.channel or'stable',restartRequired=pkg.restartRequired and true or false,files=files,totalBytes=pkg.totalBytes or 0,hash=pkg.hash}
      else res.package=util.deepcopy(pkg)end
    end
    wire.send(sender,res,activeProtocol())
    return true,false
]==]
local CORE_UPDATER=[==[-- SpawnNet Core staged updater - RC7
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
  return p:sub(1,16)=='spawnnet/server/'or p:sub(1,13)=='spawnnet/lib/'or p=='spawnnet.lua'or p=='spawnnet-status.lua'or p=='spawnnet-core-update.lua'
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
]==]
local CORE_WRAPPER=[==[local a={...};os.run({},'/spawnnet/server/core_updater.lua',a[1]or'update')
]==]
local PKG='/spawnnet/server/services/package.lua'
local CLUSTER='/spawnnet/server/cluster.lua'
local function ensure(path)if path==''or path=='/'or fs.exists(path)then return end;local p=fs.getDir(path);if p and p~=''then ensure(p)end;fs.makeDir(path)end
local function read(path)local h=fs.open(path,'r');if not h then return nil end;local s=h.readAll();h.close();return s end
local function write(path,data)ensure(fs.getDir(path));local tmp=path..'.rc7tmp';if fs.exists(tmp)then fs.delete(tmp)end;local h=assert(fs.open(tmp,'w'));h.write(data);h.close();if fs.exists(path)then fs.delete(path)end;fs.move(tmp,path)end
local function valid(code,name)local f,e=loadstring(code,'@'..name);if not f then error('Embedded '..name..' failed CraftOS syntax validation: '..tostring(e),0)end end
term.clear();term.setCursorPos(1,1);term.setTextColor(colors.yellow);print('SPAWNNET UNIFIED PLATFORM RC7');term.setTextColor(colors.white);print('Core in-place upgrade');print('Preserves your current SpawnNet Core and data.');print()
if not fs.exists('/spawnnet/server/server.lua')then error('SpawnNet Core is not installed here',0)end
valid(SERVICE,PKG);valid(CORE_UPDATER,'/spawnnet/server/core_updater.lua');valid(CORE_WRAPPER,'/spawnnet-core-update.lua')
local cluster=assert(read(CLUSTER),'Cannot read '..CLUSTER)
local candidate=cluster
if not cluster:find('SPAWNNET_RC7_NODE_UPDATE',1,true)then
  local anchors={"  elseif msg.type=='node_heartbeat' then","  elseif msg.type=='node_heartbeat'then","elseif msg.type=='node_heartbeat' then","elseif msg.type=='node_heartbeat'then"}
  local done=false
  for _,a in ipairs(anchors)do local x=candidate:find(a,1,true);if x then candidate=candidate:sub(1,x-1)..NODE_BRANCH..candidate:sub(x);done=true;break end end
  if not done then error('Current cluster.lua layout not recognized. No files were changed.',0)end
end
valid(candidate,CLUSTER)
ensure('/spawnnet/update/backups/platform-rc7')
for _,p in ipairs({PKG,CLUSTER})do if fs.exists(p)then local b='/spawnnet/update/backups/platform-rc7/'..p:gsub('^/',''):gsub('/','__');if not fs.exists(b)then fs.copy(p,b)end end end
write(PKG,SERVICE);write(CLUSTER,candidate);write('/spawnnet/server/core_updater.lua',CORE_UPDATER);write('/spawnnet-core-update.lua',CORE_WRAPPER);ensure('/spawnnet/features');write('/spawnnet/features/unified-platform-rc7','Unified Platform RC7\n')
term.setTextColor(colors.lime);print('CORE UPGRADE COMPLETE');term.setTextColor(colors.white);print('Included: fixed App Platform, system releases, Core staging, Node update channel.');print('Restart the SpawnNet Core once so package.lua/cluster.lua reload.')
