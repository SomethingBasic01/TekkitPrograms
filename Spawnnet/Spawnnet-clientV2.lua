-- SpawnNet App Platform 1.0.0 - Client Upgrade
-- Adds native install/download confirmation to the EXISTING browser without replacing the rest of the browser.
local PM=[==[-- SpawnNet native package manager 1.0.0
-- Website code can REQUEST install/download, but this module owns the confirmation UI and cannot be bypassed by page scripts.
local util=dofile('/spawnnet/lib/util.lua')
local net=dofile('/spawnnet/client/net.lua')
local crypto=dofile('/spawnnet/lib/crypto.lua')
local M={}
local ROOT='/spawnnet/apps'
local DB=ROOT..'/installed.db'
local DATA='/spawnnet/appdata'
local DOWNLOADS='/downloads'
local C=colors
local PERM_LABELS={filesystem='Read/write local files',peripheral='Access attached peripherals',modem='Use wired/wireless modems',rednet='Use Rednet/network messages',shell='Launch other programs',http='Use HTTP/WebSocket APIs',startup='Run background/startup code',commands='Create local command launchers'}
local function ensure(path)if path==''or path=='/'then return end;if fs.exists(path)then return end;local p=fs.getDir(path);if p and p~=''then ensure(p)end;fs.makeDir(path)end
local function safe(v,n)return util.safeName(v or'',n or32)end
local function cleanFilePath(path)
  path=tostring(path or''):gsub('\\','/'):gsub('^/+','');if path==''then return nil end
  for part in path:gmatch('[^/]+')do if part==''or part=='.'or part=='..'then return nil end end;return path
end
local function canonicalHash(pkg)
  local paths={};for p in pairs(pkg.files or{})do paths[#paths+1]=p end;table.sort(paths)
  local parts={tostring(pkg.domain or''),tostring(pkg.name or''),tostring(pkg.version or''),tostring(pkg.title or''),tostring(pkg.entry or''),tostring(pkg.service or'')}
  local perms={};for _,p in ipairs(pkg.permissions or{})do perms[#perms+1]=p end;table.sort(perms);for _,p in ipairs(perms)do parts[#parts+1]='perm:'..p end
  local cmds={};for n in pairs(pkg.commands or{})do cmds[#cmds+1]=n end;table.sort(cmds);for _,n in ipairs(cmds)do parts[#parts+1]='cmd:'..n..'='..tostring(pkg.commands[n])end
  for _,p in ipairs(paths)do parts[#parts+1]='file:'..p..':'..crypto.sha256(tostring(pkg.files[p]or''))end
  return crypto.sha256(table.concat(parts,'\0'))
end
local function manifest(domain,name)
  return net.call('package','manifest',{domain=safe(domain),name=safe(name)},{noAuth=true})
end
local function getPackage(domain,name)
  return net.call('package','get',{domain=safe(domain),name=safe(name)},{noAuth=true})
end
local function installed()return util.loadTable(DB,{})end
local function saveInstalled(t)ensure(ROOT);util.saveTable(DB,t)end
local function key(d,n)return safe(d)..'/'..safe(n)end
local function hasPerm(m,p)for _,x in ipairs(m.permissions or{})do if x==p then return true end end;return false end
local function wrap(s,w)local out={};s=tostring(s or'');while #s>w do local cut=w;local p=s:sub(1,w):match('^.*()%s');if p and p>8 then cut=p end;out[#out+1]=s:sub(1,cut):gsub('%s+$','');s=s:sub(cut+1):gsub('^%s+','')end;if s~=''then out[#out+1]=s end;return out end
local function nativeConfirm(kind,m,source,newPerms)
  term.setBackgroundColor(C.black);term.clear();term.setCursorPos(1,1);local w,h=term.getSize()
  term.setBackgroundColor(kind=='INSTALL'and C.blue or C.gray);term.setTextColor(C.white);term.clearLine();write((' '..kind..' APPLICATION - SPAWNNET SECURITY '):sub(1,w))
  term.setBackgroundColor(C.black);term.setTextColor(C.yellow);term.setCursorPos(2,3);print(tostring(m.title or m.name))
  term.setTextColor(C.lightGray);print('Version: '..tostring(m.version or'?'));print('Publisher: '..tostring(m.publisher or'?'));print('Site: spn://'..tostring(m.domain or'?'))
  if source then print('Requested by: '..tostring(source):sub(1,w-15))end
  print('Files: '..tostring(m.files or'?')..'   Size: '..tostring(m.totalBytes or'?')..' bytes')
  term.setTextColor(C.white);print();print('Permissions requested:')
  if #(m.permissions or{})==0 then term.setTextColor(C.lime);print('  None declared')else for _,p in ipairs(m.permissions or{})do term.setTextColor((newPerms and newPerms[p])and C.orange or C.white);print('  - '..tostring(PERM_LABELS[p]or p))end end
  if newPerms and next(newPerms)then term.setTextColor(C.orange);print();print('WARNING: This update requests NEW permissions.')end
  term.setTextColor(C.lightGray);print();for _,line in ipairs(wrap('Installed Lua is trusted code. SpawnNet will never approve this screen for the website; only you can.',w-4))do print('  '..line)end
  term.setCursorPos(1,h);term.setBackgroundColor(C.gray);term.setTextColor(C.white);term.clearLine();write(' N cancel                                      Y confirm')
  while true do local e,k=os.pullEvent('key');if k==keys.y then return true elseif k==keys.n or k==keys.q or k==keys.escape then return false end end
end
local function writePackage(pkg)
  local d,n=safe(pkg.domain),safe(pkg.name);if d==''or n==''then return nil,'Invalid package identity'end
  if canonicalHash(pkg)~=tostring(pkg.hash or'')then return nil,'Package integrity check failed'end
  local root=ROOT..'/'..d..'/'..n;local app=root..'/app';if fs.exists(app)then fs.delete(app)end;ensure(app)
  for path,data in pairs(pkg.files or{})do local cp=cleanFilePath(path);if not cp then return nil,'Unsafe package path: '..tostring(path)end;local target=fs.combine(app,cp);ensure(fs.getDir(target));local h=assert(fs.open(target,'w'));h.write(tostring(data or''));h.close()end
  ensure(DATA..'/'..d..'/'..n)
  local db=installed();db[key(d,n)]={domain=d,name=n,title=pkg.title,version=pkg.version,publisher=pkg.publisher,permissions=pkg.permissions or{},entry=pkg.entry,service=pkg.service,commands=pkg.commands or{},hash=pkg.hash,installed=os.clock()};saveInstalled(db)
  return root
end
local function runInstalled(rec)
  if not rec or not rec.entry then return nil,'Package has no entry program'end
  local path=ROOT..'/'..rec.domain..'/'..rec.name..'/app/'..rec.entry;if not fs.exists(path)then return nil,'Entry file missing'end
  local ok=os.run({},path,'spawnnet-package');if not ok then return nil,'Program exited with an error'end;return true
end
local function doInstall(domain,name,source,updating)
  local p,e=manifest(domain,name);if not p then return nil,e end;local m=p.package or p
  local db=installed();local old=db[key(domain,name)];local newPerms={}
  if old then local have={};for _,x in ipairs(old.permissions or{})do have[x]=true end;for _,x in ipairs(m.permissions or{})do if not have[x]then newPerms[x]=true end end end
  if not nativeConfirm(updating and'UPDATE'or'INSTALL',m,source,newPerms)then return nil,'Cancelled'end
  local got,ge=getPackage(domain,name);if not got then return nil,ge end;local pkg=got.package or got
  local root,we=writePackage(pkg);if not root then return nil,we end
  term.setBackgroundColor(C.black);term.clear();term.setCursorPos(1,2);term.setTextColor(C.lime);print((updating and'UPDATED: 'or'INSTALLED: ')..tostring(pkg.title or pkg.name)..' '..tostring(pkg.version));term.setTextColor(C.white);print('Location: '..root)
  if pkg.entry then print();write('Run it now? Y/n: ');local a=read():lower();if a~='n'and a~='no'then local rec=installed()[key(domain,name)];local ok,re=runInstalled(rec);if not ok then printError(re)end end end
  return true
end
function M.installFromSite(domain,name,source)return doInstall(domain,name,source,false)end
function M.downloadFromSite(domain,name,source)
  local p,e=manifest(domain,name);if not p then return nil,e end;local m=p.package or p;if not nativeConfirm('DOWNLOAD',m,source)then return nil,'Cancelled'end
  local got,ge=getPackage(domain,name);if not got then return nil,ge end;local pkg=got.package or got;if canonicalHash(pkg)~=tostring(pkg.hash or'')then return nil,'Package integrity check failed'end
  ensure(DOWNLOADS);local file=DOWNLOADS..'/'..safe(domain)..'-'..safe(name)..'-'..tostring(pkg.version or'package'):gsub('[^%w%.%-_]','_')..'.spkg';local h=assert(fs.open(file,'w'));h.write(textutils.serialize(pkg));h.close();return file
end
function M.run(domain,name)local rec=installed()[key(domain,name)];if not rec then return nil,'Not installed'end;return runInstalled(rec)end
function M.uninstall(domain,name)
  local db=installed();local k=key(domain,name);local rec=db[k];if not rec then return nil,'Not installed'end
  term.clear();term.setCursorPos(1,2);term.setTextColor(C.yellow);print('UNINSTALL '..tostring(rec.title or rec.name)..'?');term.setTextColor(C.lightGray);print('Application files will be removed. App data is kept.');print();write('Type UNINSTALL: ');if read()~='UNINSTALL'then return nil,'Cancelled'end
  local root=ROOT..'/'..rec.domain..'/'..rec.name;if fs.exists(root)then fs.delete(root)end;db[k]=nil;saveInstalled(db);return true
end
local function menu()
  while true do
    local db=installed();local list={};for _,r in pairs(db)do list[#list+1]=r end;table.sort(list,function(a,b)return tostring(a.title or a.name)<tostring(b.title or b.name)end)
    term.setBackgroundColor(C.black);term.clear();term.setCursorPos(1,1);term.setTextColor(C.yellow);print('SPAWNNET INSTALLED APPS');term.setTextColor(C.white)
    if #list==0 then print();print('No SpawnNet application packages installed.')else for i,r in ipairs(list)do print(i..') '..tostring(r.title or r.name)..'  '..tostring(r.version))end end
    print();print('R # run   U # update   X # uninstall   Q quit');write('> ');local line=read();local c,n=line:match('^(%a)%s*(%d*)');c=c and c:lower();local r=list[tonumber(n)or0]
    if c=='q'then return elseif c=='r'and r then runInstalled(r)elseif c=='u'and r then local ok,e=doInstall(r.domain,r.name,'Installed Apps',true);if not ok and e~='Cancelled'then printError(e);sleep(1.5)end elseif c=='x'and r then local ok,e=M.uninstall(r.domain,r.name);if not ok and e~='Cancelled'then printError(e);sleep(1.5)end end
  end
end
M.menu=menu
return M
]==]
local PMPATH='/spawnnet/client/package_manager.lua'
local BROWSER='/spawnnet/client/browser.lua'
local SDK='/spawnnet/client/sdk.lua'
local MARKER='/spawnnet/features/app-platform-1.0.0-client'
local function ensure(path)if path==''or path=='/'then return end;if fs.exists(path)then return end;local p=fs.getDir(path);if p and p~=''then ensure(p)end;fs.makeDir(path)end
local function read(path)local h=fs.open(path,'r');if not h then return nil end;local s=h.readAll();h.close();return s end
local function write(path,data)ensure(fs.getDir(path));local h=assert(fs.open(path,'w'));h.write(data);h.close()end
local function replaceOnce(s,needle,repl)local a,b=s:find(needle,1,true);if not a then return nil end;return s:sub(1,a-1)..repl..s:sub(b+1)end
term.clear();term.setCursorPos(1,1);term.setTextColor(colors.yellow);print('SPAWNNET APP PLATFORM 1.0.0');term.setTextColor(colors.white);print('Client upgrade - native website downloads / installs');print()
if not fs.exists(BROWSER)then error('SpawnNet Client is not installed on this computer',0)end
write(PMPATH,PM);write('/spawnnet-packages.lua',[=[local M=dofile('/spawnnet/client/package_manager.lua')
local a={...}
if a[1]=='install'then local ok,e=M.installFromSite(a[2],a[3],'command line');if not ok and e~='Cancelled'then printError(e)end
elseif a[1]=='download'then local f,e=M.downloadFromSite(a[2],a[3],'command line');if f then print('Saved: '..f)elseif e~='Cancelled'then printError(e)end
elseif a[1]=='run'then local ok,e=M.run(a[2],a[3]);if not ok then printError(e)end
elseif a[1]=='uninstall'then local ok,e=M.uninstall(a[2],a[3]);if not ok and e~='Cancelled'then printError(e)end
else M.menu()end
]=])
local s=assert(read(BROWSER),'Cannot read browser.lua')
if not s:find('SPAWNNET_APP_PLATFORM_PM',1,true)then
  local anchors={"local config=dofile('/spawnnet/lib/config.lua')","local config = dofile('/spawnnet/lib/config.lua')",'local config=dofile("/spawnnet/lib/config.lua")'}
  local done=false
  for _,a in ipairs(anchors)do local x=replaceOnce(s,a,a.."\nlocal pkgmgr=dofile('/spawnnet/client/package_manager.lua') -- SPAWNNET_APP_PLATFORM_PM");if x then s=x;done=true;break end end
  if not done then error('Browser layout not recognized: config import anchor missing. Nothing was changed.',0)end
  local cases={"elseif a.type=='search'then","elseif a.type=='search' then",'elseif a.type=="search"then','elseif a.type=="search" then'}
  done=false
  for _,a in ipairs(cases)do
    local inject="elseif a.type=='install'then local ok,e=pkgmgr.installFromSite(domain,a.package or a.name or'',address);if not ok and e~='Cancelled'then status='Install: '..tostring(e)end\n  elseif a.type=='download'then local f,e=pkgmgr.downloadFromSite(domain,a.package or a.name or'',address);if f then status='Downloaded: '..tostring(f)elseif e~='Cancelled'then status='Download: '..tostring(e)end\n  "..a
    local x=replaceOnce(s,a,inject);if x then s=x;done=true;break end
  end
  if not done then error('Browser layout not recognized: action handler anchor missing. Nothing was changed.',0)end
  if not fs.exists(BROWSER..'.pre-app-platform')then fs.copy(BROWSER,BROWSER..'.pre-app-platform')end
  write(BROWSER,s);print('Browser install/download action support added.')
else print('Browser is already App Platform enabled.')end
if fs.exists(SDK)then
  local k=read(SDK)
  if k and not k:find('M.packages=',1,true)then
    local pos=k:match('()return M%s*$')
    if pos then
      local add="M.packages={manifest=function(domain,name)return net.call('package','manifest',{domain=domain,name=name},{noAuth=true})end,get=function(domain,name)return net.call('package','get',{domain=domain,name=name},{noAuth=true})end,publish=function(domain,name,spec)spec=spec or{};spec.domain=domain;spec.name=name;return net.call('package','publish',spec)end,delete=function(domain,name)return net.call('package','delete',{domain=domain,name=name})end}\n"
      if not fs.exists(SDK..'.pre-app-platform')then fs.copy(SDK,SDK..'.pre-app-platform')end;k=k:sub(1,pos-1)..add..k:sub(pos);write(SDK,k);print('SDK package publishing helpers added.')
    end
  end
end
write(MARKER,'SpawnNet App Platform 1.0.0\n')
print();term.setTextColor(colors.lime);print('CLIENT UPGRADE COMPLETE');term.setTextColor(colors.white)
print('Website buttons may now use:')
print("  action={type='install',package='myapp'}")
print("  action={type='download',package='myapp'}")
print('Both ALWAYS open a SpawnNet-owned confirmation screen.')
print('Installed apps manager: spawnnet-packages')
