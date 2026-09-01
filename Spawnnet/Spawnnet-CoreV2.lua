-- SpawnNet App Platform 1.0.0 - Core Upgrade
-- Safe in-place feature upgrade: replaces only the package service and preserves all other SpawnNet files/state.
local TARGET='/spawnnet/server/services/package.lua'
local BACKUP='/spawnnet/server/services/package.pre-app-platform.lua'
local MARKER='/spawnnet/features/app-platform-1.0.0'
local SERVICE=[==[-- SpawnNet App Package Service 1.0.0
-- Per-domain application packages. Legacy global/admin packages remain compatible.
local util=dofile('/spawnnet/lib/util.lua')
local C=dofile('/spawnnet/server/services/common.lua')
local auth=dofile('/spawnnet/server/auth.lua')
local crypto=dofile('/spawnnet/lib/crypto.lua')
local M={}

local MAX_FILES=64
local MAX_FILE_BYTES=65536
local MAX_TOTAL_BYTES=220000
local ALLOWED_PERMS={filesystem=true,peripheral=true,modem=true,rednet=true,shell=true,http=true,startup=true,commands=true}

local function count(t)local n=0;for _ in pairs(t or{})do n=n+1 end;return n end
local function cleanDomain(v)
  if C.cleanDomain then return C.cleanDomain(v) end
  local d=util.safeName(v or'',32);if d==''then return nil end;return d
end
local function cleanPkg(v)return util.safeName(v or'',32)end
local function cleanFilePath(path)
  path=tostring(path or''):gsub('\\','/'):gsub('^/+','')
  if path=='' or #path>120 then return nil end
  if path:find('..',1,true) then
    for part in path:gmatch('[^/]+')do if part=='..'then return nil end end
  end
  for part in path:gmatch('[^/]+')do if part=='' or part=='.' or part=='..'then return nil end end
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
local function canonicalHash(pkg)
  local paths={};for p in pairs(pkg.files or{})do paths[#paths+1]=p end;table.sort(paths)
  local parts={tostring(pkg.domain or''),tostring(pkg.name or''),tostring(pkg.version or''),tostring(pkg.title or''),tostring(pkg.entry or''),tostring(pkg.service or'')}
  for _,p in ipairs(pkg.permissions or{})do parts[#parts+1]='perm:'..p end
  local cmds={};for n in pairs(pkg.commands or{})do cmds[#cmds+1]=n end;table.sort(cmds)
  for _,n in ipairs(cmds)do parts[#parts+1]='cmd:'..n..'='..tostring(pkg.commands[n]) end
  for _,p in ipairs(paths)do parts[#parts+1]='file:'..p..':'..crypto.sha256(tostring(pkg.files[p]or'')) end
  return crypto.sha256(table.concat(parts,'\0'))
end
local function manifest(pkg)
  if not pkg then return nil end
  return {domain=pkg.domain,name=pkg.name,title=pkg.title,version=pkg.version,description=pkg.description,publisher=pkg.publisher,
    permissions=util.deepcopy(pkg.permissions or{}),entry=pkg.entry,service=pkg.service,commands=util.deepcopy(pkg.commands or{}),
    files=count(pkg.files),totalBytes=pkg.totalBytes or 0,hash=pkg.hash,published=pkg.published,updated=pkg.updated,runAfterInstall=pkg.runAfterInstall and true or false}
end
local function siteOwner(state,d,ctx)
  local s=state.sites and state.sites[d];return s and ctx and s.owner==ctx.user
end
local function appBucket(state,d)
  state.appPackages=state.appPackages or{};state.appPackages[d]=state.appPackages[d]or{};return state.appPackages[d]
end
local function publishApp(state,p,ctx)
  local d=cleanDomain(p.domain);if not d then return 400,nil,'Bad domain' end
  if not siteOwner(state,d,ctx)then return 403,nil,'Only the site owner can publish application packages' end
  local name=cleanPkg(p.name);if name==''then return 400,nil,'Package name required' end
  local version=C.cleanText(p.version or'',24);if version==''then return 400,nil,'Version required' end
  local src=p.files;if type(src)~='table'then return 400,nil,'Package files table required' end
  local files={};local total=0;local n=0
  for path,data in pairs(src)do
    local cp=cleanFilePath(path);if not cp then return 400,nil,'Bad package file path: '..tostring(path) end
    data=tostring(data or'');if #data>MAX_FILE_BYTES then return 400,nil,'Package file too large: '..cp end
    n=n+1;if n>MAX_FILES then return 400,nil,'Too many package files' end
    total=total+#data;if total>MAX_TOTAL_BYTES then return 400,nil,'Package exceeds '..MAX_TOTAL_BYTES..' bytes' end
    files[cp]=data
  end
  if n==0 then return 400,nil,'Package must contain at least one file' end
  local entry=p.entry and cleanFilePath(p.entry)or nil;if entry and not files[entry]then return 400,nil,'Entry file not found in package' end
  local service=p.service and cleanFilePath(p.service)or nil;if service and not files[service]then return 400,nil,'Service file not found in package' end
  local pkg={domain=d,name=name,title=C.cleanText(p.title or name,48),version=version,description=C.cleanText(p.description or'',240),publisher=ctx.user,
    permissions=normalizePerms(p.permissions),entry=entry,service=service,commands=normalizeCommands(p.commands),files=files,totalBytes=total,
    published=util.now(),updated=util.now(),runAfterInstall=p.runAfterInstall and true or false}
  pkg.hash=canonicalHash(pkg)
  local bucket=appBucket(state,d);local old=bucket[name];if old and old.published then pkg.published=old.published end;bucket[name]=pkg
  return 201,{package=manifest(pkg)},true
end

function M.handle(state,req,ctx)
  local p=req.payload or{};local a=req.action
  local hasDomain=p.domain~=nil and tostring(p.domain)~=''
  if hasDomain then
    local d=cleanDomain(p.domain);if not d then return 400,nil,'Bad domain' end
    local name=cleanPkg(p.name);local bucket=(state.appPackages or{})[d]or{}
    if a=='manifest'then local pkg=bucket[name];if not pkg then return 404,nil,'Package not found' end;return 200,{package=manifest(pkg)},false end
    if a=='get'then local pkg=bucket[name];if not pkg then return 404,nil,'Package not found' end;return 200,{package=util.deepcopy(pkg)},false end
    if a=='list'then local out={};for _,pkg in pairs(bucket)do out[#out+1]=manifest(pkg)end;table.sort(out,function(x,y)return tostring(x.title)<tostring(y.title)end);return 200,{domain=d,packages=out},false end
    if a=='publish'then return publishApp(state,p,ctx)end
    if a=='delete'then if not siteOwner(state,d,ctx)then return 403,nil,'Only the site owner can delete application packages' end;if not bucket[name]then return 404,nil,'Package not found' end;bucket[name]=nil;return 200,{deleted=name},true end
    return 404,nil,'Unknown package action'
  end

  -- Backward-compatible global packages used by SpawnNet's own updater.
  state.packages=state.packages or{}
  if a=='manifest'then
    local name=cleanPkg(p.name or'client');local pkg=state.packages[name];if not pkg then return 404,nil,'Package not found' end
    return 200,{name=name,version=pkg.version,description=pkg.description,files=pkg.files and count(pkg.files)or 0},false
  elseif a=='get'then
    local name=cleanPkg(p.name);local pkg=state.packages[name];if not pkg then return 404,nil,'Package not found' end;return 200,{package=pkg},false
  elseif a=='publish'then
    if not auth.isAdmin(ctx)then return 403,nil,'Admin required' end
    local name=cleanPkg(p.name);state.packages[name]={version=C.cleanText(p.version,24),description=C.cleanText(p.description,200),files=p.files or{},published=util.now(),owner=ctx.user};return 201,{name=name},true
  end
  return 404,nil,'Unknown package action'
end
return M
]==]
local function ensure(path)
  if path==''or path=='/'then return end;if fs.exists(path)then return end;local p=fs.getDir(path);if p and p~=''then ensure(p)end;fs.makeDir(path)
end
local function read(path)local h=fs.open(path,'r');if not h then return nil end;local s=h.readAll();h.close();return s end
local function write(path,data)ensure(fs.getDir(path));local h=assert(fs.open(path,'w'));h.write(data);h.close()end
term.clear();term.setCursorPos(1,1);term.setTextColor(colors.yellow);print('SPAWNNET APP PLATFORM 1.0.0');term.setTextColor(colors.white);print('Core upgrade - native website app packages');print()
if not fs.exists('/spawnnet/server/server.lua')then error('SpawnNet Core is not installed on this computer',0)end
if fs.exists(TARGET)and not fs.exists(BACKUP)then fs.copy(TARGET,BACKUP);print('Backed up existing package service.')end
write(TARGET,SERVICE);write(MARKER,'SpawnNet App Platform 1.0.0\n')
print('Installed per-site package registry and publisher support.')
print('Existing SpawnNet global update packages remain compatible.')
print();term.setTextColor(colors.lime);print('CORE UPGRADE COMPLETE');term.setTextColor(colors.white);print('Restart the SpawnNet Core so it reloads package.lua.')
