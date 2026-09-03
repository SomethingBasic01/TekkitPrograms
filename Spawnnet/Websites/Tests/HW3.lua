-- WarehouseOS 2.5.2 - SpawnNet 2.3.0 Citadel Edition
local net=dofile('/spawnnet/client/net.lua')
local auth=dofile('/spawnnet/client/auth_client.lua')
local C=colors
local DOMAIN='warehouse'
if not fs.exists('/spawnnet/client/package_manager.lua')then error('WarehouseOS 2.5.2 requires SpawnNet 2.3.0+ with native application packages.',0)end
if not net.loadSession()then local s,e=auth.ensureLogin();if not s then error(e,0)end end
local function call(s,a,p,o)local x,e=net.call(s,a,p or{},o);if not x then error(tostring(e),0)end;return x end
local existing=net.call('dns','resolve',{domain=DOMAIN},{noAuth=true})
if not existing then call('dns','register',{domain=DOMAIN,title='WarehouseOS'})else local mine=net.call('web','getSite',{domain=DOMAIN});if not mine then error('spn://warehouse exists but is not owned by this account',0)end end
local packageProbe,packageErr=net.call('package','list',{domain=DOMAIN},{noAuth=true});if not packageProbe then error('SpawnNet package service unavailable: '..tostring(packageErr),0)end

local function add(p,e)p.elements[#p.elements+1]=e;return e end
local function hidden(p,id,v)add(p,{type='input',id=id,x=1,y=1,w=1,value=v or'',visible=false})end
local function base(title,sub,mode)
 local p={title=title,background=C.black,elements={}}
 hidden(p,'pageMode',mode or'')
 add(p,{type='panel',x=1,y=1,w='100%',h=4,bg=C.purple,children={
  {type='heading',x=2,y=1,w=47,text='WH// WAREHOUSEOS 2.5.2',fg=C.white,bg=C.purple},
  {type='text',x=2,y=2,w=47,text=sub or title,fg=C.cyan,bg=C.purple,align='center'}}})
 return p
end
local function nav(p)
 add(p,{type='button',x=1,y=5,w=9,text='NEXUS',bg=C.blue,action={type='navigate',target='spn://warehouse/'}})
 add(p,{type='button',x=11,y=5,w=9,text='FORGE',bg=C.blue,action={type='navigate',target='spn://warehouse/create'}})
 add(p,{type='button',x=21,y=5,w=9,text='VAULTS',bg=C.purple,action={type='navigate',target='spn://warehouse/my'}})
 add(p,{type='button',x=31,y=5,w=9,text='DEPLOY',bg=C.lime,fg=C.black,action={type='install',package='warehouseos'}})
 add(p,{type='button',x=41,y=5,w=9,text='INTEL',bg=C.gray,action={type='navigate',target='spn://warehouse/help'}})
end
local pages={}
do
 local p=base('WarehouseOS','Physical inventory command network // SpawnNet Citadel','home');nav(p)
 add(p,{type='badge',x=3,y=9,w=45,text='CORE LINK // ONLINE // PHYSICAL I/O ARMED',bg=C.lime,fg=C.black,align='center'})
 add(p,{type='heading',x=3,y=12,w=45,text='YOUR STORAGE. ONE COMMAND NEXUS.',fg=C.cyan})
 add(p,{type='text',x=3,y=14,w=45,h=6,text='Connect inventories to one computer, create a warehouse, install WarehouseOS from this site, choose Main Output + Main Deposit, and every other detected inventory becomes storage.'})
 add(p,{type='button',x=3,y=21,w=22,text='FORGE NEW VAULT',bg=C.blue,action={type='navigate',target='spn://warehouse/create'}})
 add(p,{type='button',x=27,y=21,w=22,text='DEPLOY CONTROLLER',bg=C.lime,fg=C.black,action={type='install',package='warehouseos'}})
 add(p,{type='button',x=3,y=24,w=45,text='ENTER VAULT COMMAND',bg=C.purple,action={type='navigate',target='spn://warehouse/my'}})
 add(p,{type='heading',x=3,y=29,w=45,text='REMOTE COMMAND CONSOLES',fg=C.cyan})
 add(p,{type='text',x=3,y=31,w=45,h=5,text='Pair another computer as a remote access console. It can browse and control this warehouse, but physical items always enter and leave through the main controller inventories.'})
 pages['/']=p
end
do
 local p=base('Vault Forge','Create a secured warehouse identity and controller cipher','create');nav(p)
 hidden(p,'createdId','');hidden(p,'createdName','')
 add(p,{type='heading',x=3,y=9,w=45,text='FORGE A NEW STORAGE VAULT',fg=C.cyan})
 add(p,{type='input',id='warehouseName',x=3,y=12,w=45,value='My Warehouse',placeholder='Warehouse name'})
 add(p,{type='button',x=3,y=15,w=45,text='INITIALIZE VAULT IDENTITY',bg=C.lime,fg=C.black,action={type='server',event='create_submit'}})
 add(p,{type='badge',id='createStatus',x=3,y=18,w=45,text='FORGE READY // AWAITING COMMAND',bg=C.gray,align='center'})
 add(p,{type='text',id='createId',x=3,y=21,w=45,h=2,text='Warehouse ID: -'})
 add(p,{type='text',id='createPair',x=3,y=24,w=45,h=2,text='Controller pair code: -'})
 add(p,{type='button',id='openCreated',x=3,y=27,w=45,text='ENTER NEW VAULT',bg=C.purple,visible=false,action={type='event',event='open_created'}})
 add(p,{type='button',x=3,y=30,w=45,text='DEPLOY WAREHOUSEOS CONTROLLER',bg=C.blue,action={type='install',package='warehouseos'}})
 add(p,{type='text',x=3,y=33,w=45,h=6,text='After installation, run WarehouseOS setup, choose Warehouse Controller, enter the controller pair code, then select Main Output and Main Deposit. Reboot once after first setup so SpawnNet starts the background service.'})
 pages['/create']=p
end
do
 local p=base('Vault Directory','Select an authorized physical storage network','my');nav(p)
 for i=1,8 do hidden(p,'wid'..i,'');hidden(p,'wname'..i,'')end
 add(p,{type='heading',x=3,y=9,w=45,text='AUTHORIZED STORAGE VAULTS',fg=C.cyan})
 for i=1,8 do add(p,{type='button',id='wh'..i,x=3,y=10+i*3,w=45,text='-',bg=i%2==0 and C.gray or C.blue,visible=false,action={type='event',event='open_wh'..i}})end
 add(p,{type='text',x=3,y=36,w=45,h=3,text='Up to eight active warehouse links are shown. Deleted warehouses are hidden automatically.'})
 pages['/my']=p
end
do
 local p=base('Vault Command','Live inventory matrix and physical controller operations','terminal');nav(p);p.liveInterval=0.5
 hidden(p,'warehouseId','');hidden(p,'selectedItemKey','');hidden(p,'searchPage','1')
 for i=1,8 do hidden(p,'itemKey'..i,'');hidden(p,'itemName'..i,'');hidden(p,'itemAlias'..i,'');hidden(p,'itemDetails'..i,'')end
 add(p,{type='badge',id='warehouseTitle',x=3,y=8,w=45,text='VAULT // UNSELECTED',bg=C.purple,align='center'})
 add(p,{type='text',id='warehouseState',x=3,y=10,w=45,h=1,text='LINK STATE // ACQUIRING CONTROLLER...'})
 add(p,{type='input',id='searchText',x=3,y=12,w=28,value='',placeholder='Search...'})
 add(p,{type='select',id='searchField',x=32,y=12,w=17,value='all',options={'all','name','registry'}})
 add(p,{type='input',id='searchMod',x=3,y=14,w=15,value='',placeholder='Mod / namespace'})
 add(p,{type='input',id='searchMin',x=19,y=14,w=8,value='0',placeholder='Min'})
 add(p,{type='input',id='searchMax',x=28,y=14,w=8,value='0',placeholder='Max'})
 add(p,{type='select',id='searchAlias',x=37,y=14,w=12,value='all',options={'all','custom','default'}})
 add(p,{type='select',id='searchSort',x=3,y=16,w=18,value='name_asc',options={'name_asc','name_desc','amount_desc','amount_asc','mod'}})
 add(p,{type='button',x=22,y=16,w=27,text='EXECUTE FILTER MATRIX',bg=C.blue,action={type='event',event='search_apply'}})
 add(p,{type='button',x=3,y=18,w=10,text='RESET',bg=C.gray,action={type='event',event='search_clear'}})
 add(p,{type='button',x=14,y=18,w=9,text='< PAGE',bg=C.gray,action={type='event',event='search_prev'}})
 add(p,{type='text',id='searchState',x=24,y=18,w=15,text='Results',align='center'})
 add(p,{type='button',x=40,y=18,w=9,text='PAGE >',bg=C.gray,action={type='event',event='search_next'}})
 add(p,{type='badge',id='ioState',x=3,y=21,w=45,text='PHYSICAL I/O // MAIN OUTPUT + MAIN DEPOSIT',bg=C.blue,align='center'})
 add(p,{type='text',x=3,y=23,w=45,h=3,text='Remote terminals control this screen only. They never attempt impossible wireless item transfer.'})
 add(p,{type='text',x=3,y=28,w=14,text='Withdraw qty:'})
 add(p,{type='input',id='quantity',x=18,y=28,w=10,value='64'})
 add(p,{type='button',x=30,y=28,w=19,text='INGEST DEPOSIT',bg=C.cyan,fg=C.black,action={type='server',event='deposit_submit'}})
 for i=1,8 do local y=28+i*2;add(p,{type='button',id='item'..i,x=3,y=y,w=33,text='-',bg=i%2==0 and C.gray or C.black,visible=false,action={type='event',event='pick_item'..i}});add(p,{type='button',id='take'..i,x=37,y=y,w=12,text='EXTRACT',bg=C.lime,fg=C.black,visible=false,action={type='event',event='take_item'..i}})end
 add(p,{type='text',id='selectedItem',x=3,y=47,w=45,text='Selected: none'})
 add(p,{type='text',id='selectedDetails',x=3,y=49,w=45,h=2,text='Registry / metadata details appear here.',fg=C.lightGray})
 add(p,{type='input',id='aliasName',x=3,y=52,w=24,value='',placeholder='Custom display name'})
 add(p,{type='button',x=28,y=52,w=10,text='SAVE',bg=C.purple,action={type='server',event='alias_save'}})
 add(p,{type='button',x=39,y=52,w=10,text='RESET',bg=C.gray,action={type='server',event='alias_reset'}})
 add(p,{type='button',x=3,y=55,w=22,text='EXTRACT SELECTED',bg=C.lime,fg=C.black,action={type='server',event='withdraw_submit'}})
 add(p,{type='text',id='operationStatus',x=27,y=55,w=22,h=2,text='COMMAND BUS // READY'})
 add(p,{type='button',x=3,y=59,w=14,text='MEMBERS',bg=C.purple,action={type='navigate',target='spn://warehouse/members'}})
 add(p,{type='button',x=18,y=59,w=14,text='HISTORY',bg=C.gray,action={type='navigate',target='spn://warehouse/history'}})
 add(p,{type='button',x=33,y=59,w=16,text='SETTINGS',bg=C.gray,action={type='navigate',target='spn://warehouse/settings'}})
 pages['/terminal']=p
end
do
 local p=base('Vault Control','Controller policy, pairing ciphers, consoles and deletion','settings');nav(p);hidden(p,'warehouseId','')
 add(p,{type='badge',id='warehouseTitle',x=3,y=9,w=45,text='VAULT CONTROL // UNSELECTED',bg=C.purple,align='center'})
 add(p,{type='text',id='settingsSummary',x=3,y=12,w=45,h=3,text='Loading...'})
 add(p,{type='text',id='autoDepositState',x=3,y=16,w=45,text='Auto-deposit: loading...'})
 add(p,{type='button',x=3,y=18,w=45,text='TOGGLE AUTOMATIC INGEST',bg=C.blue,action={type='server',event='auto_deposit_toggle'}})
 add(p,{type='button',x=3,y=22,w=45,text='ROTATE CONTROLLER PAIR CIPHER',bg=C.orange,fg=C.black,action={type='server',event='controller_code_submit'}})
 add(p,{type='text',id='controllerPair',x=3,y=25,w=45,text='Controller pair code: -'})
 add(p,{type='button',x=3,y=29,w=45,text='AUTHORIZE REMOTE COMMAND CONSOLE',bg=C.cyan,fg=C.black,action={type='server',event='terminal_code_submit'}})
 add(p,{type='text',id='terminalPair',x=3,y=32,w=45,text='Remote terminal pair code: -'})
 add(p,{type='button',x=3,y=35,w=45,text='DEPLOY / UPGRADE WAREHOUSEOS',bg=C.lime,fg=C.black,action={type='install',package='warehouseos'}})
 add(p,{type='heading',x=3,y=39,w=45,text='REMOTE COMMAND CONSOLES',fg=C.cyan})
 add(p,{type='text',id='terminal1',x=3,y=41,w=45,text='-'})
 add(p,{type='text',id='terminal2',x=3,y=43,w=45,text='-'})
 add(p,{type='text',id='terminal3',x=3,y=45,w=45,text='-'})
 add(p,{type='text',id='terminal4',x=3,y=47,w=45,text='-'})
 add(p,{type='heading',x=3,y=51,w=45,text='SCORCHED-EARTH CONTROL',fg=C.red})
 add(p,{type='input',id='deleteConfirm',x=3,y=54,w=45,value='',placeholder='Type DELETE'})
 add(p,{type='button',x=3,y=57,w=45,text='DELETE WAREHOUSE',bg=C.red,action={type='server',event='delete_warehouse_submit'}})
 add(p,{type='text',id='deleteStatus',x=3,y=60,w=45,h=3,text='Deletes the WarehouseOS record. Physical chest contents are NEVER deleted.'})
 pages['/settings']=p
end
do
 local p=base('Access Matrix','Warehouse identity and authority roles','members');nav(p);hidden(p,'warehouseId','')
 add(p,{type='badge',id='warehouseTitle',x=3,y=9,w=45,text='VAULT ACCESS MATRIX',bg=C.purple,align='center'})
 add(p,{type='input',id='memberName',x=3,y=13,w=28,placeholder='SpawnNet username'})
 add(p,{type='select',id='memberRole',x=32,y=13,w=17,value='viewer',options={'viewer','depositor','withdrawer','operator','admin'}})
 add(p,{type='button',x=3,y=16,w=45,text='COMMIT AUTHORIZATION',bg=C.lime,fg=C.black,action={type='server',event='invite_submit'}})
 add(p,{type='text',id='memberStatus',x=3,y=19,w=45,h=3,text='Owner/admin can share this warehouse.'})
 add(p,{type='text',x=3,y=23,w=45,h=6,text='Viewer: browse only. Depositor: browse + deposit. Withdrawer: browse + withdraw. Operator: deposit + withdraw. Admin: operational access + sharing + item aliases.'})
 pages['/members']=p
end
do
 local p=base('Operation Ledger','Newest physical vault operations','history');nav(p);hidden(p,'warehouseId','')
 add(p,{type='text',id='historyStatus',x=3,y=9,w=45,text='Loading...'})
 for i=1,4 do add(p,{type='text',id='history'..i,x=3,y=9+i*3,w=45,h=2,text='-'})end
 add(p,{type='button',x=3,y=24,w=45,text='REFRESH OPERATION LEDGER',bg=C.purple,action={type='server',event='history_refresh'}})
 pages['/history']=p
end
do
 local p=base('Field Manual','Deployment doctrine for physical storage networks','help');nav(p)
 add(p,{type='heading',x=3,y=9,w=45,text='PRIMARY VAULT CONTROLLER',fg=C.cyan})
 add(p,{type='text',x=3,y=11,w=45,h=9,text='1. Wire chests to one computer. 2. Create a warehouse here. 3. Click INSTALL and approve SpawnNet security. 4. Run WarehouseOS setup. 5. Enter the controller pair code. 6. Choose Main Output and optional Main Deposit. 7. Reboot once. WarehouseOS then runs as a SpawnNet-managed background service while the computer remains usable.'})
 add(p,{type='heading',x=3,y=23,w=45,text='REMOTE COMMAND CONSOLE',fg=C.cyan})
 add(p,{type='text',x=3,y=25,w=45,h=8,text='On another computer, generate a Remote Terminal code, install WarehouseOS, choose Remote Terminal, and enter the code. It becomes a named remote access console and opens this warehouse directly. Items still use the controller Main Output and Main Deposit.'})
 add(p,{type='heading',x=3,y=36,w=45,text='ITEM IDENTITY OVERRIDES',fg=C.cyan})
 add(p,{type='text',x=3,y=38,w=45,h=6,text='WarehouseOS identifies variants using registry ID + metadata and an NBT fingerprint when available. You can rename ugly labels like ProjectRed Component without changing the physical item identity.'})
 add(p,{type='button',x=3,y=46,w=45,text='DEPLOY WAREHOUSEOS',bg=C.lime,fg=C.black,action={type='install',package='warehouseos'}})
 pages['/help']=p
end
do
 local p=base('Not Found','WarehouseOS page not found','404');nav(p)
 add(p,{type='heading',x=3,y=11,w=45,text='PAGE NOT FOUND',fg=C.red})
 add(p,{type='button',x=3,y=16,w=45,text='RETURN HOME',bg=C.blue,action={type='navigate',target='spn://warehouse/'}})
 pages['/404']=p
end

local clientScript=[==[event load
call input.get "pageMode" -> mode
if $mode == "my"
call server.run "list_warehouses"
endif
if $mode == "terminal"
call local.get "warehouse.selected" -> wid
call local.get "warehouse.name" -> name
call ui.setValue "warehouseId" $wid
call ui.setText "warehouseTitle" $name
call server.run "query_submit"
endif
if $mode == "settings"
call local.get "warehouse.selected" -> wid
call local.get "warehouse.name" -> name
call ui.setValue "warehouseId" $wid
call ui.setText "warehouseTitle" $name
call server.run "settings_refresh"
endif
if $mode == "members"
call local.get "warehouse.selected" -> wid
call local.get "warehouse.name" -> name
call ui.setValue "warehouseId" $wid
call ui.setText "warehouseTitle" $name
endif
if $mode == "history"
call local.get "warehouse.selected" -> wid
call local.get "warehouse.name" -> name
call ui.setValue "warehouseId" $wid
call ui.setText "warehouseTitle" $name
call server.run "history_refresh"
endif
end
event tick
call input.get "pageMode" -> mode
if $mode == "terminal"
call server.run "terminal_refresh"
endif
if $mode == "settings"
call server.run "settings_refresh"
endif
end
event open_created
call input.get "createdId" -> wid
call input.get "createdName" -> name
call local.set "warehouse.selected" $wid
call local.set "warehouse.name" $name
call ui.navigate "spn://warehouse/terminal"
end
event open_wh1
call input.get "wid1" -> wid
call input.get "wname1" -> name
call local.set "warehouse.selected" $wid
call local.set "warehouse.name" $name
call ui.navigate "spn://warehouse/terminal"
end
event open_wh2
call input.get "wid2" -> wid
call input.get "wname2" -> name
call local.set "warehouse.selected" $wid
call local.set "warehouse.name" $name
call ui.navigate "spn://warehouse/terminal"
end
event open_wh3
call input.get "wid3" -> wid
call input.get "wname3" -> name
call local.set "warehouse.selected" $wid
call local.set "warehouse.name" $name
call ui.navigate "spn://warehouse/terminal"
end
event open_wh4
call input.get "wid4" -> wid
call input.get "wname4" -> name
call local.set "warehouse.selected" $wid
call local.set "warehouse.name" $name
call ui.navigate "spn://warehouse/terminal"
end
event open_wh5
call input.get "wid5" -> wid
call input.get "wname5" -> name
call local.set "warehouse.selected" $wid
call local.set "warehouse.name" $name
call ui.navigate "spn://warehouse/terminal"
end
event open_wh6
call input.get "wid6" -> wid
call input.get "wname6" -> name
call local.set "warehouse.selected" $wid
call local.set "warehouse.name" $name
call ui.navigate "spn://warehouse/terminal"
end
event open_wh7
call input.get "wid7" -> wid
call input.get "wname7" -> name
call local.set "warehouse.selected" $wid
call local.set "warehouse.name" $name
call ui.navigate "spn://warehouse/terminal"
end
event open_wh8
call input.get "wid8" -> wid
call input.get "wname8" -> name
call local.set "warehouse.selected" $wid
call local.set "warehouse.name" $name
call ui.navigate "spn://warehouse/terminal"
end
event pick_item1
call input.get "itemKey1" -> k
call input.get "itemName1" -> n
call input.get "itemAlias1" -> a
call input.get "itemDetails1" -> d
call ui.setValue "selectedItemKey" $k
call ui.setText "selectedItem" "Selected: ${n}"
call ui.setText "selectedDetails" "${d}"
call ui.setValue "aliasName" $a
end
event pick_item2
call input.get "itemKey2" -> k
call input.get "itemName2" -> n
call input.get "itemAlias2" -> a
call input.get "itemDetails2" -> d
call ui.setValue "selectedItemKey" $k
call ui.setText "selectedItem" "Selected: ${n}"
call ui.setText "selectedDetails" "${d}"
call ui.setValue "aliasName" $a
end
event pick_item3
call input.get "itemKey3" -> k
call input.get "itemName3" -> n
call input.get "itemAlias3" -> a
call input.get "itemDetails3" -> d
call ui.setValue "selectedItemKey" $k
call ui.setText "selectedItem" "Selected: ${n}"
call ui.setText "selectedDetails" "${d}"
call ui.setValue "aliasName" $a
end
event pick_item4
call input.get "itemKey4" -> k
call input.get "itemName4" -> n
call input.get "itemAlias4" -> a
call input.get "itemDetails4" -> d
call ui.setValue "selectedItemKey" $k
call ui.setText "selectedItem" "Selected: ${n}"
call ui.setText "selectedDetails" "${d}"
call ui.setValue "aliasName" $a
end
event pick_item5
call input.get "itemKey5" -> k
call input.get "itemName5" -> n
call input.get "itemAlias5" -> a
call input.get "itemDetails5" -> d
call ui.setValue "selectedItemKey" $k
call ui.setText "selectedItem" "Selected: ${n}"
call ui.setText "selectedDetails" "${d}"
call ui.setValue "aliasName" $a
end
event pick_item6
call input.get "itemKey6" -> k
call input.get "itemName6" -> n
call input.get "itemAlias6" -> a
call input.get "itemDetails6" -> d
call ui.setValue "selectedItemKey" $k
call ui.setText "selectedItem" "Selected: ${n}"
call ui.setText "selectedDetails" "${d}"
call ui.setValue "aliasName" $a
end
event pick_item7
call input.get "itemKey7" -> k
call input.get "itemName7" -> n
call input.get "itemAlias7" -> a
call input.get "itemDetails7" -> d
call ui.setValue "selectedItemKey" $k
call ui.setText "selectedItem" "Selected: ${n}"
call ui.setText "selectedDetails" "${d}"
call ui.setValue "aliasName" $a
end
event pick_item8
call input.get "itemKey8" -> k
call input.get "itemName8" -> n
call input.get "itemAlias8" -> a
call input.get "itemDetails8" -> d
call ui.setValue "selectedItemKey" $k
call ui.setText "selectedItem" "Selected: ${n}"
call ui.setText "selectedDetails" "${d}"
call ui.setValue "aliasName" $a
end
event take_item1
call input.get "itemKey1" -> k
call ui.setValue "selectedItemKey" $k
call server.run "withdraw_submit"
end
event take_item2
call input.get "itemKey2" -> k
call ui.setValue "selectedItemKey" $k
call server.run "withdraw_submit"
end
event take_item3
call input.get "itemKey3" -> k
call ui.setValue "selectedItemKey" $k
call server.run "withdraw_submit"
end
event take_item4
call input.get "itemKey4" -> k
call ui.setValue "selectedItemKey" $k
call server.run "withdraw_submit"
end
event take_item5
call input.get "itemKey5" -> k
call ui.setValue "selectedItemKey" $k
call server.run "withdraw_submit"
end
event take_item6
call input.get "itemKey6" -> k
call ui.setValue "selectedItemKey" $k
call server.run "withdraw_submit"
end
event take_item7
call input.get "itemKey7" -> k
call ui.setValue "selectedItemKey" $k
call server.run "withdraw_submit"
end
event take_item8
call input.get "itemKey8" -> k
call ui.setValue "selectedItemKey" $k
call server.run "withdraw_submit"
end
event search_apply
call ui.setValue "searchPage" 1
call server.run "query_submit"
end
event search_clear
call ui.setValue "searchText" ""
call ui.setValue "searchField" "all"
call ui.setValue "searchMod" ""
call ui.setValue "searchMin" 0
call ui.setValue "searchMax" 0
call ui.setValue "searchAlias" "all"
call ui.setValue "searchSort" "name_asc"
call ui.setValue "searchPage" 1
call server.run "query_submit"
end
event search_prev
call input.get "searchPage" -> p
math np $p - 1
if $np < 1
set np 1
endif
call ui.setValue "searchPage" $np
call server.run "query_submit"
end
event search_next
call input.get "searchPage" -> p
math np $p + 1
call ui.setValue "searchPage" $np
call server.run "query_submit"
end
]==]
local serverScript=[==[event create_submit
call user.name -> who
if $who == nil
call ui.alert "Sign in to SpawnNet first."
else
set name $input.warehouseName
if $name == ""
set name "My Warehouse"
endif
call db.list "ul-${who}" -> links
set slot ""
if $links.slot8 == nil
set slot "slot8"
endif
if $links.slot7 == nil
set slot "slot7"
endif
if $links.slot6 == nil
set slot "slot6"
endif
if $links.slot5 == nil
set slot "slot5"
endif
if $links.slot4 == nil
set slot "slot4"
endif
if $links.slot3 == nil
set slot "slot3"
endif
if $links.slot2 == nil
set slot "slot2"
endif
if $links.slot1 == nil
set slot "slot1"
endif
if $slot == ""
call ui.alert "Warehouse list is full (8)."
else
random rid 100000 999999
concat wid "wh-" $rid
call db.get "warehouses" $wid -> exists
if $exists != nil
random rid 100000 999999
concat wid "wh-" $rid
call db.get "warehouses" $wid -> exists
endif
random pair 10000000 99999999
call db.get "paircodes" $pair -> pairUsed
if $pairUsed != nil
random pair 10000000 99999999
call db.get "paircodes" $pair -> pairUsed
endif
if $exists != nil
call ui.alert "Could not allocate warehouse ID. Try again."
else
if $pairUsed != nil
call ui.alert "Could not allocate pair code. Try again."
else
call time.now -> now
set wh.id $wid
set wh.name $name
set wh.owner $who
set wh.created $now
set wh.deleted false
set wh.autoDeposit true
set wh.controllerPair $pair
call db.set "warehouses" $wid $wh
set r.role "owner"
call db.set "roles-${wid}" $who $r
set link.id $wid
set link.name $name
set link.role "owner"
call db.set "ul-${who}" $slot $link
set pr.warehouseId $wid
set pr.kind "controller"
call db.set "paircodes" $pair $pr
call ui.setText "createStatus" "VAULT IDENTITY FORGED // CIPHER READY"
call ui.setText "createId" "Warehouse ID: ${wid}"
call ui.setText "createPair" "Controller pair code: ${pair}"
call ui.setValue "createdId" $wid
call ui.setValue "createdName" $name
call ui.setVisible "openCreated" true
endif
endif
endif
endif
end
event list_warehouses
call ui.setVisible "wh1" false
call ui.setVisible "wh2" false
call ui.setVisible "wh3" false
call ui.setVisible "wh4" false
call ui.setVisible "wh5" false
call ui.setVisible "wh6" false
call ui.setVisible "wh7" false
call ui.setVisible "wh8" false
call user.name -> who
if $who == nil
call ui.alert "Sign in first."
else
call db.list "ul-${who}" -> links
if $links.slot1 != nil
call db.get "warehouses" $links.slot1.id -> wh
if $wh == nil
call db.set "ul-${who}" "slot1" nil
else
if $wh.deleted == true
call db.set "ul-${who}" "slot1" nil
else
call ui.setText "wh1" "${wh.name}  [${links.slot1.role}]"
call ui.setValue "wid1" $wh.id
call ui.setValue "wname1" $wh.name
call ui.setVisible "wh1" true
endif
endif
endif
if $links.slot2 != nil
call db.get "warehouses" $links.slot2.id -> wh
if $wh == nil
call db.set "ul-${who}" "slot2" nil
else
if $wh.deleted == true
call db.set "ul-${who}" "slot2" nil
else
call ui.setText "wh2" "${wh.name}  [${links.slot2.role}]"
call ui.setValue "wid2" $wh.id
call ui.setValue "wname2" $wh.name
call ui.setVisible "wh2" true
endif
endif
endif
if $links.slot3 != nil
call db.get "warehouses" $links.slot3.id -> wh
if $wh == nil
call db.set "ul-${who}" "slot3" nil
else
if $wh.deleted == true
call db.set "ul-${who}" "slot3" nil
else
call ui.setText "wh3" "${wh.name}  [${links.slot3.role}]"
call ui.setValue "wid3" $wh.id
call ui.setValue "wname3" $wh.name
call ui.setVisible "wh3" true
endif
endif
endif
if $links.slot4 != nil
call db.get "warehouses" $links.slot4.id -> wh
if $wh == nil
call db.set "ul-${who}" "slot4" nil
else
if $wh.deleted == true
call db.set "ul-${who}" "slot4" nil
else
call ui.setText "wh4" "${wh.name}  [${links.slot4.role}]"
call ui.setValue "wid4" $wh.id
call ui.setValue "wname4" $wh.name
call ui.setVisible "wh4" true
endif
endif
endif
if $links.slot5 != nil
call db.get "warehouses" $links.slot5.id -> wh
if $wh == nil
call db.set "ul-${who}" "slot5" nil
else
if $wh.deleted == true
call db.set "ul-${who}" "slot5" nil
else
call ui.setText "wh5" "${wh.name}  [${links.slot5.role}]"
call ui.setValue "wid5" $wh.id
call ui.setValue "wname5" $wh.name
call ui.setVisible "wh5" true
endif
endif
endif
if $links.slot6 != nil
call db.get "warehouses" $links.slot6.id -> wh
if $wh == nil
call db.set "ul-${who}" "slot6" nil
else
if $wh.deleted == true
call db.set "ul-${who}" "slot6" nil
else
call ui.setText "wh6" "${wh.name}  [${links.slot6.role}]"
call ui.setValue "wid6" $wh.id
call ui.setValue "wname6" $wh.name
call ui.setVisible "wh6" true
endif
endif
endif
if $links.slot7 != nil
call db.get "warehouses" $links.slot7.id -> wh
if $wh == nil
call db.set "ul-${who}" "slot7" nil
else
if $wh.deleted == true
call db.set "ul-${who}" "slot7" nil
else
call ui.setText "wh7" "${wh.name}  [${links.slot7.role}]"
call ui.setValue "wid7" $wh.id
call ui.setValue "wname7" $wh.name
call ui.setVisible "wh7" true
endif
endif
endif
if $links.slot8 != nil
call db.get "warehouses" $links.slot8.id -> wh
if $wh == nil
call db.set "ul-${who}" "slot8" nil
else
if $wh.deleted == true
call db.set "ul-${who}" "slot8" nil
else
call ui.setText "wh8" "${wh.name}  [${links.slot8.role}]"
call ui.setValue "wid8" $wh.id
call ui.setValue "wname8" $wh.name
call ui.setVisible "wh8" true
endif
endif
endif
endif
end
event controller_pair
set out.ok false
call db.get "pairreceipts" $input.rid -> receipt
if $receipt != nil
if $receipt.t != $input.token
set out.error "Pair request mismatch."
else
if $receipt.c != $input.computerId
set out.error "Pair computer mismatch."
else
set out.ok true
set out.warehouseId $receipt.w
set out.warehouseName $receipt.n
endif
endif
else
call db.get "paircodes" $input.code -> pr
if $pr == nil
set out.error "Pair code unavailable. Generate a fresh code."
else
if $pr.kind != "controller"
set out.error "Not a controller pair code."
else
call db.get "warehouses" $pr.warehouseId -> wh
if $wh == nil
set out.error "Warehouse no longer exists."
else
if $wh.deleted == true
set out.error "Warehouse deleted."
else
set c.token $input.token
set c.computerId $input.computerId
set c.name $input.name
call time.now -> now
set c.lastSeen $now
call db.set "controllers" $pr.warehouseId $c
call db.set "paircodes" $input.code nil
set wh.controllerPair nil
call db.set "warehouses" $pr.warehouseId $wh
set receipt.t $input.token
set receipt.c $input.computerId
set receipt.w $pr.warehouseId
set receipt.n $wh.name
call db.set "pairreceipts" $input.rid $receipt
set out.ok true
set out.warehouseId $pr.warehouseId
set out.warehouseName $wh.name
endif
endif
endif
endif
endif
return $out
end
event controller_heartbeat
set out.ok false
call db.get "warehouses" $input.warehouseId -> wh
if $wh == nil
set out.deleted true
else
if $wh.deleted == true
set out.deleted true
else
call db.get "controllers" $input.warehouseId -> c
if $c == nil
set out.replaced true
else
if $c.token != $input.token
set out.replaced true
else
call time.now -> now
if $input.persist == true
set c.name $input.name
set c.computerId $input.computerId
set c.output $input.output
set c.deposit $input.deposit
set c.outputOnline $input.outputOnline
set c.depositOnline $input.depositOnline
set c.firstStorage $input.firstStorage
set c.inventories $input.inventories
set c.totalItems $input.totalItems
set c.autoDeposit $input.autoDeposit
set c.lastSeen $now
call db.set "controllers" $input.warehouseId $c
endif
if $input.pairRequestId != nil
call db.set "pairreceipts" $input.pairRequestId nil
set out.pairReceiptCleared true
endif
if $input.completedId != nil
math receiptSlot $input.completedId % 64
concat receiptKey "c" $receiptSlot
call db.get "receipts-${input.warehouseId}" $receiptKey -> seen
if $seen != $input.completedId
call db.list "cmdq-${input.warehouseId}" -> doneQueue
if $doneQueue.q1.requestId == $input.completedId
call db.set "cmdq-${input.warehouseId}" "q1" $doneQueue.q2
call db.set "cmdq-${input.warehouseId}" "q2" $doneQueue.q3
call db.set "cmdq-${input.warehouseId}" "q3" $doneQueue.q4
call db.set "cmdq-${input.warehouseId}" "q4" nil
else
if $doneQueue.q2.requestId == $input.completedId
call db.set "cmdq-${input.warehouseId}" "q2" nil
endif
if $doneQueue.q3.requestId == $input.completedId
call db.set "cmdq-${input.warehouseId}" "q3" nil
endif
if $doneQueue.q4.requestId == $input.completedId
call db.set "cmdq-${input.warehouseId}" "q4" nil
endif
endif
set res.requestId $input.completedId
set res.ok $input.completedOk
set res.moved $input.completedMoved
set res.message $input.completedMessage
set res.action $input.completedAction
set res.item $input.completedItem
set res.user $input.completedUser
set res.time $now
call db.get "history-${input.warehouseId}" "h1" -> o1
call db.get "history-${input.warehouseId}" "h2" -> o2
call db.get "history-${input.warehouseId}" "h3" -> o3
call db.set "history-${input.warehouseId}" "h4" $o3
call db.set "history-${input.warehouseId}" "h3" $o2
call db.set "history-${input.warehouseId}" "h2" $o1
call db.set "history-${input.warehouseId}" "h1" $res
call db.set "receipts-${input.warehouseId}" $receiptKey $input.completedId
endif
set out.completedAck $input.completedId
endif
call db.list "cmdq-${input.warehouseId}" -> queue
set cmd nil
if $queue.q4 != nil
set cmd $queue.q4
endif
if $queue.q3 != nil
set cmd $queue.q3
endif
if $queue.q2 != nil
set cmd $queue.q2
endif
if $queue.q1 != nil
set cmd $queue.q1
endif
call db.get "queries" $input.warehouseId -> q
call db.list "aliases-${input.warehouseId}" -> aliases
set out.ok true
if $cmd != nil
set out.commandId $cmd.requestId
set out.commandAction $cmd.action
set out.commandItem $cmd.item
set out.commandAmount $cmd.amount
set out.commandUser $cmd.user
endif
set out.query $q
set out.aliases $aliases
set out.autoDeposit $wh.autoDeposit
endif
endif
endif
endif
return $out
end
event controller_view
set out.ok false
call db.get "controllers" $input.warehouseId -> c
if $c.token == $input.token
if $input.view.user != ""
call db.set "views-${input.warehouseId}" $input.view.user $input.view
endif
set out.ok true
endif
return $out
end
event terminal_pair
set out.ok false
call db.get "pairreceipts" $input.rid -> receipt
if $receipt != nil
if $receipt.t != $input.token
set out.error "Pair request mismatch."
else
if $receipt.c != $input.computerId
set out.error "Pair computer mismatch."
else
set out.ok true
set out.warehouseId $receipt.w
set out.warehouseName $receipt.n
set out.terminalId $receipt.i
set out.terminalSlot $receipt.s
endif
endif
else
call db.get "paircodes" $input.code -> pr
if $pr == nil
set out.error "Terminal code unavailable. Generate a fresh code."
else
if $pr.kind != "terminal"
set out.error "Not a terminal pair code."
else
call db.get "warehouses" $pr.warehouseId -> wh
call db.list "terminalslots-${pr.warehouseId}" -> slots
set slot ""
if $slots.slot4 == nil
set slot "slot4"
endif
if $slots.slot3 == nil
set slot "slot3"
endif
if $slots.slot2 == nil
set slot "slot2"
endif
if $slots.slot1 == nil
set slot "slot1"
endif
if $wh == nil
set out.error "Warehouse no longer exists."
else
if $wh.deleted == true
set out.error "Warehouse deleted."
else
if $slot == ""
set out.error "Remote terminal limit reached (4)."
else
random rn 1000 9999
concat tid "remote-" $rn
call db.get "terminaltokens-${pr.warehouseId}" $tid -> oldToken
if $oldToken != nil
random rn 1000 9999
concat tid "remote-" $rn
call db.get "terminaltokens-${pr.warehouseId}" $tid -> oldToken
endif
if $oldToken != nil
set out.error "Could not allocate terminal ID. Try again."
else
call time.now -> now
call db.set "terminaltokens-${pr.warehouseId}" $tid $input.token
call db.set "terminalnames-${pr.warehouseId}" $tid $input.name
call db.set "terminallast-${pr.warehouseId}" $tid $now
call db.set "terminalcomputers-${pr.warehouseId}" $tid $input.computerId
call db.set "terminalslots-${pr.warehouseId}" $slot $tid
call db.set "paircodes" $input.code nil
set wh.terminalPair nil
call db.set "warehouses" $pr.warehouseId $wh
set receipt.t $input.token
set receipt.c $input.computerId
set receipt.w $pr.warehouseId
set receipt.n $wh.name
set receipt.i $tid
set receipt.s $slot
call db.set "pairreceipts" $input.rid $receipt
set out.ok true
set out.warehouseId $pr.warehouseId
set out.warehouseName $wh.name
set out.terminalId $tid
set out.terminalSlot $slot
endif
endif
endif
endif
endif
endif
endif
return $out
end
event terminal_heartbeat
set out.ok false
call db.get "warehouses" $input.warehouseId -> wh
if $wh == nil
set out.deleted true
else
if $wh.deleted == true
set out.deleted true
else
call db.get "terminaltokens-${input.warehouseId}" $input.terminalId -> token
if $token != $input.token
set out.removed true
else
call time.now -> now
call db.set "terminalnames-${input.warehouseId}" $input.terminalId $input.name
call db.set "terminallast-${input.warehouseId}" $input.terminalId $now
call db.set "terminalcomputers-${input.warehouseId}" $input.terminalId $input.computerId
set out.ok true
endif
endif
endif
return $out
end
event query_submit
call user.name -> who
call db.get "roles-${input.warehouseId}" $who -> role
if $role == nil
call ui.alert "No warehouse access."
else
set q.text $input.searchText
set q.field $input.searchField
set q.mod $input.searchMod
set q.min $input.searchMin
set q.max $input.searchMax
set q.alias $input.searchAlias
set q.sort $input.searchSort
set q.page $input.searchPage
set q.user $who
call db.set "queries" $input.warehouseId $q
call ui.setText "searchState" "FILTER MATRIX // SYNCING WITH CONTROLLER..."
endif
end
event terminal_refresh
call ui.setVisible "item1" false
call ui.setVisible "take1" false
call ui.setVisible "item2" false
call ui.setVisible "take2" false
call ui.setVisible "item3" false
call ui.setVisible "take3" false
call ui.setVisible "item4" false
call ui.setVisible "take4" false
call ui.setVisible "item5" false
call ui.setVisible "take5" false
call ui.setVisible "item6" false
call ui.setVisible "take6" false
call ui.setVisible "item7" false
call ui.setVisible "take7" false
call ui.setVisible "item8" false
call ui.setVisible "take8" false
call user.name -> who
call db.get "roles-${input.warehouseId}" $who -> role
if $role == nil
call ui.setText "warehouseState" "LINK DENIED // IDENTITY NOT AUTHORIZED"
else
call db.get "warehouses" $input.warehouseId -> wh
if $wh.deleted == true
call ui.setText "warehouseState" "WAREHOUSE DELETED"
else
call db.get "controllers" $input.warehouseId -> c
if $c == nil
call ui.setText "warehouseState" "LINK DOWN // CONTROLLER NOT PAIRED"
else
call time.now -> now
math age $now - $c.lastSeen
if $age > 10
call ui.setText "warehouseState" "LINK DOWN // CONTROLLER OFFLINE"
else
call ui.setText "warehouseState" "LINK ONLINE // ${c.inventories} STORAGE BANKS // ${c.totalItems} ITEMS"
endif
endif
call db.get "views-${input.warehouseId}" $who -> v
if $v != nil
call ui.setText "searchState" "MATRIX ${v.page}/${v.pages} // ${v.total} ITEM TYPES"
if $v.item1 != nil
call ui.setText "item1" "${v.item1.name}  x${v.item1.amount}"
call ui.setValue "itemKey1" $v.item1.key
call ui.setValue "itemName1" $v.item1.name
call ui.setValue "itemAlias1" $v.item1.alias
call ui.setValue "itemDetails1" $v.item1.details
call ui.setVisible "item1" true
call ui.setVisible "take1" true
endif
if $v.item2 != nil
call ui.setText "item2" "${v.item2.name}  x${v.item2.amount}"
call ui.setValue "itemKey2" $v.item2.key
call ui.setValue "itemName2" $v.item2.name
call ui.setValue "itemAlias2" $v.item2.alias
call ui.setValue "itemDetails2" $v.item2.details
call ui.setVisible "item2" true
call ui.setVisible "take2" true
endif
if $v.item3 != nil
call ui.setText "item3" "${v.item3.name}  x${v.item3.amount}"
call ui.setValue "itemKey3" $v.item3.key
call ui.setValue "itemName3" $v.item3.name
call ui.setValue "itemAlias3" $v.item3.alias
call ui.setValue "itemDetails3" $v.item3.details
call ui.setVisible "item3" true
call ui.setVisible "take3" true
endif
if $v.item4 != nil
call ui.setText "item4" "${v.item4.name}  x${v.item4.amount}"
call ui.setValue "itemKey4" $v.item4.key
call ui.setValue "itemName4" $v.item4.name
call ui.setValue "itemAlias4" $v.item4.alias
call ui.setValue "itemDetails4" $v.item4.details
call ui.setVisible "item4" true
call ui.setVisible "take4" true
endif
if $v.item5 != nil
call ui.setText "item5" "${v.item5.name}  x${v.item5.amount}"
call ui.setValue "itemKey5" $v.item5.key
call ui.setValue "itemName5" $v.item5.name
call ui.setValue "itemAlias5" $v.item5.alias
call ui.setValue "itemDetails5" $v.item5.details
call ui.setVisible "item5" true
call ui.setVisible "take5" true
endif
if $v.item6 != nil
call ui.setText "item6" "${v.item6.name}  x${v.item6.amount}"
call ui.setValue "itemKey6" $v.item6.key
call ui.setValue "itemName6" $v.item6.name
call ui.setValue "itemAlias6" $v.item6.alias
call ui.setValue "itemDetails6" $v.item6.details
call ui.setVisible "item6" true
call ui.setVisible "take6" true
endif
if $v.item7 != nil
call ui.setText "item7" "${v.item7.name}  x${v.item7.amount}"
call ui.setValue "itemKey7" $v.item7.key
call ui.setValue "itemName7" $v.item7.name
call ui.setValue "itemAlias7" $v.item7.alias
call ui.setValue "itemDetails7" $v.item7.details
call ui.setVisible "item7" true
call ui.setVisible "take7" true
endif
if $v.item8 != nil
call ui.setText "item8" "${v.item8.name}  x${v.item8.amount}"
call ui.setValue "itemKey8" $v.item8.key
call ui.setValue "itemName8" $v.item8.name
call ui.setValue "itemAlias8" $v.item8.alias
call ui.setValue "itemDetails8" $v.item8.details
call ui.setVisible "item8" true
call ui.setVisible "take8" true
endif
call db.get "history-${input.warehouseId}" "h1" -> res
if $res.user == $who
call ui.setText "operationStatus" "${res.message}"
endif
endif
endif
endif
end
event withdraw_submit
call user.name -> who
call db.get "roles-${input.warehouseId}" $who -> role
if $role == nil
call ui.alert "No warehouse access."
else
if $input.selectedItemKey == ""
call ui.alert "Select an item first."
else
if $role.role == "viewer"
call ui.alert "Viewer cannot withdraw."
else
if $role.role == "depositor"
call ui.alert "Depositor cannot withdraw."
else
call db.get "controllers" $input.warehouseId -> c
if $c == nil
call ui.alert "Warehouse controller is not paired."
else
call time.now -> now
math cage $now - $c.lastSeen
if $cage > 12
call ui.alert "Warehouse controller is offline."
else
call db.list "cmdq-${input.warehouseId}" -> queue
set qslot ""
if $queue.q4 == nil
set qslot "q4"
endif
if $queue.q3 == nil
set qslot "q3"
endif
if $queue.q2 == nil
set qslot "q2"
endif
if $queue.q1 == nil
set qslot "q1"
endif
if $qslot == ""
call ui.alert "Controller queue is full. Wait for one operation to finish."
else
random req 10000000 99999999
set cmd.requestId $req
set cmd.action "withdraw"
set cmd.item $input.selectedItemKey
set cmd.amount $input.quantity
set cmd.user $who
call db.set "cmdq-${input.warehouseId}" $qslot $cmd
call ui.setText "operationStatus" "EXTRACTION COMMAND QUEUED"
endif
endif
endif
endif
endif
endif
endif
end
event deposit_submit
call user.name -> who
call db.get "roles-${input.warehouseId}" $who -> role
if $role == nil
call ui.alert "No warehouse access."
else
if $role.role == "viewer"
call ui.alert "Viewer cannot deposit."
else
if $role.role == "withdrawer"
call ui.alert "Withdrawer cannot deposit."
else
call db.get "controllers" $input.warehouseId -> c
if $c == nil
call ui.alert "Warehouse controller is not paired."
else
call time.now -> now
math cage $now - $c.lastSeen
if $cage > 12
call ui.alert "Warehouse controller is offline."
else
call db.list "cmdq-${input.warehouseId}" -> queue
set qslot ""
if $queue.q4 == nil
set qslot "q4"
endif
if $queue.q3 == nil
set qslot "q3"
endif
if $queue.q2 == nil
set qslot "q2"
endif
if $queue.q1 == nil
set qslot "q1"
endif
if $qslot == ""
call ui.alert "Controller queue is full. Wait for one operation to finish."
else
random req 10000000 99999999
set cmd.requestId $req
set cmd.action "deposit"
set cmd.user $who
call db.set "cmdq-${input.warehouseId}" $qslot $cmd
call ui.setText "operationStatus" "INGEST SWEEP QUEUED"
endif
endif
endif
endif
endif
endif
end
event alias_save
call user.name -> who
call db.get "roles-${input.warehouseId}" $who -> role
if $input.selectedItemKey == ""
call ui.alert "Select an item first."
else
set allowed false
if $role.role == "owner"
set allowed true
endif
if $role.role == "admin"
set allowed true
endif
if $allowed == true
call db.set "aliases-${input.warehouseId}" $input.selectedItemKey $input.aliasName
call ui.setText "operationStatus" "ITEM IDENTITY OVERRIDE COMMITTED"
else
call ui.alert "Owner/admin required."
endif
endif
end
event alias_reset
call user.name -> who
call db.get "roles-${input.warehouseId}" $who -> role
if $input.selectedItemKey == ""
call ui.alert "Select an item first."
else
set allowed false
if $role.role == "owner"
set allowed true
endif
if $role.role == "admin"
set allowed true
endif
if $allowed == true
call db.set "aliases-${input.warehouseId}" $input.selectedItemKey nil
call ui.setValue "aliasName" ""
call ui.setText "operationStatus" "ITEM IDENTITY RESTORED"
else
call ui.alert "Owner/admin required."
endif
endif
end
event settings_refresh
call user.name -> who
call db.get "roles-${input.warehouseId}" $who -> role
if $role == nil
call ui.setText "settingsSummary" "NO ACCESS"
else
call db.get "warehouses" $input.warehouseId -> wh
call db.get "controllers" $input.warehouseId -> c
if $c == nil
call ui.setText "settingsSummary" "Controller: NOT PAIRED"
else
call ui.setText "settingsSummary" "Controller: ${c.name} | Output: ${c.output} | Deposit: ${c.deposit}"
endif
if $wh.autoDeposit == false
call ui.setText "autoDepositState" "Auto-deposit: OFF - use DEPOSIT NOW manually"
else
call ui.setText "autoDepositState" "Auto-deposit: ON - deposit chest sweeps automatically"
endif
call db.list "terminalslots-${input.warehouseId}" -> terms
call time.now -> now
call ui.setText "terminal1" "-"
if $terms.slot1 != nil
call db.get "terminalnames-${input.warehouseId}" $terms.slot1 -> tn
call ui.setText "terminal1" "${terms.slot1} - ${tn} [PAIRED ACCESS CONSOLE]"
endif
call ui.setText "terminal2" "-"
if $terms.slot2 != nil
call db.get "terminalnames-${input.warehouseId}" $terms.slot2 -> tn
call ui.setText "terminal2" "${terms.slot2} - ${tn} [PAIRED ACCESS CONSOLE]"
endif
call ui.setText "terminal3" "-"
if $terms.slot3 != nil
call db.get "terminalnames-${input.warehouseId}" $terms.slot3 -> tn
call ui.setText "terminal3" "${terms.slot3} - ${tn} [PAIRED ACCESS CONSOLE]"
endif
call ui.setText "terminal4" "-"
if $terms.slot4 != nil
call db.get "terminalnames-${input.warehouseId}" $terms.slot4 -> tn
call ui.setText "terminal4" "${terms.slot4} - ${tn} [PAIRED ACCESS CONSOLE]"
endif
endif
end
event auto_deposit_toggle
call user.name -> who
call db.get "roles-${input.warehouseId}" $who -> role
set allowed false
if $role.role == "owner"
set allowed true
endif
if $role.role == "admin"
set allowed true
endif
if $allowed == false
call ui.alert "Owner/admin required."
else
call db.get "warehouses" $input.warehouseId -> wh
if $wh.autoDeposit == false
set wh.autoDeposit true
call ui.setText "autoDepositState" "Auto-deposit: ON - deposit chest sweeps automatically"
else
set wh.autoDeposit false
call ui.setText "autoDepositState" "Auto-deposit: OFF - use DEPOSIT NOW manually"
endif
call db.set "warehouses" $input.warehouseId $wh
endif
end
event controller_code_submit
call user.name -> who
call db.get "roles-${input.warehouseId}" $who -> role
if $role.role != "owner"
call ui.alert "Owner required."
else
call db.get "warehouses" $input.warehouseId -> wh
if $wh == nil
call ui.alert "Warehouse no longer exists."
else
if $wh.deleted == true
call ui.alert "Warehouse is deleted."
else
if $wh.controllerPair != nil
call db.set "paircodes" $wh.controllerPair nil
endif
random pair 10000000 99999999
call db.get "paircodes" $pair -> used
if $used != nil
random pair 10000000 99999999
call db.get "paircodes" $pair -> used
endif
if $used != nil
call ui.alert "Could not allocate pair code. Try again."
else
set pr.warehouseId $input.warehouseId
set pr.kind "controller"
call db.set "paircodes" $pair $pr
set wh.controllerPair $pair
call db.set "warehouses" $input.warehouseId $wh
call ui.setText "controllerPair" "Controller pair code: ${pair}"
endif
endif
endif
endif
end
event terminal_code_submit
call user.name -> who
call db.get "roles-${input.warehouseId}" $who -> role
set allowed false
if $role.role == "owner"
set allowed true
endif
if $role.role == "admin"
set allowed true
endif
if $allowed == false
call ui.alert "Owner/admin required."
else
call db.get "warehouses" $input.warehouseId -> wh
if $wh == nil
call ui.alert "Warehouse no longer exists."
else
if $wh.deleted == true
call ui.alert "Warehouse is deleted."
else
if $wh.terminalPair != nil
call db.set "paircodes" $wh.terminalPair nil
endif
random pair 10000000 99999999
call db.get "paircodes" $pair -> used
if $used != nil
random pair 10000000 99999999
call db.get "paircodes" $pair -> used
endif
if $used != nil
call ui.alert "Could not allocate pair code. Try again."
else
set pr.warehouseId $input.warehouseId
set pr.kind "terminal"
call db.set "paircodes" $pair $pr
set wh.terminalPair $pair
call db.set "warehouses" $input.warehouseId $wh
call ui.setText "terminalPair" "Remote terminal pair code: ${pair}"
endif
endif
endif
endif
end
event invite_submit
call user.name -> who
call db.get "roles-${input.warehouseId}" $who -> role
set allowed false
if $role.role == "owner"
set allowed true
endif
if $role.role == "admin"
set allowed true
endif
if $allowed == false
call ui.alert "Owner/admin required."
else
set target $input.memberName
call db.get "warehouses" $input.warehouseId -> wh
if $wh == nil
call ui.alert "Warehouse no longer exists."
else
if $wh.deleted == true
call ui.alert "Warehouse is deleted."
else
if $target == ""
call ui.alert "Enter a username."
else
if $target == $wh.owner
call ui.alert "The owner already has owner access."
else
set safeRole "viewer"
if $input.memberRole == "depositor"
set safeRole "depositor"
endif
if $input.memberRole == "withdrawer"
set safeRole "withdrawer"
endif
if $input.memberRole == "operator"
set safeRole "operator"
endif
if $input.memberRole == "admin"
set safeRole "admin"
endif
call db.list "ul-${target}" -> links
set slot ""
if $links.slot1.id == $input.warehouseId
set slot "slot1"
endif
if $links.slot2.id == $input.warehouseId
set slot "slot2"
endif
if $links.slot3.id == $input.warehouseId
set slot "slot3"
endif
if $links.slot4.id == $input.warehouseId
set slot "slot4"
endif
if $links.slot5.id == $input.warehouseId
set slot "slot5"
endif
if $links.slot6.id == $input.warehouseId
set slot "slot6"
endif
if $links.slot7.id == $input.warehouseId
set slot "slot7"
endif
if $links.slot8.id == $input.warehouseId
set slot "slot8"
endif
if $slot == ""
if $links.slot8 == nil
set slot "slot8"
endif
if $links.slot7 == nil
set slot "slot7"
endif
if $links.slot6 == nil
set slot "slot6"
endif
if $links.slot5 == nil
set slot "slot5"
endif
if $links.slot4 == nil
set slot "slot4"
endif
if $links.slot3 == nil
set slot "slot3"
endif
if $links.slot2 == nil
set slot "slot2"
endif
if $links.slot1 == nil
set slot "slot1"
endif
endif
if $slot == ""
call ui.alert "That user already has 8 warehouse links."
else
call mail.send $target "Warehouse access" "You now have ${safeRole} access to ${wh.name}." -> mid
set nr.role $safeRole
call db.set "roles-${input.warehouseId}" $target $nr
set link.id $input.warehouseId
set link.name $wh.name
set link.role $safeRole
call db.set "ul-${target}" $slot $link
call ui.setText "memberStatus" "Access granted to ${target}."
endif
endif
endif
endif
endif
endif
end
event history_refresh
call user.name -> who
call db.get "roles-${input.warehouseId}" $who -> role
if $role == nil
call ui.setText "historyStatus" "NO ACCESS"
else
call db.list "history-${input.warehouseId}" -> h
call ui.setText "historyStatus" "OPERATION LEDGER // NEWEST FIRST"
call ui.setText "history1" "${h.h1.action}: ${h.h1.message}"
call ui.setText "history2" "${h.h2.action}: ${h.h2.message}"
call ui.setText "history3" "${h.h3.action}: ${h.h3.message}"
call ui.setText "history4" "${h.h4.action}: ${h.h4.message}"
endif
end
event delete_warehouse_submit
call user.name -> who
call db.get "warehouses" $input.warehouseId -> wh
if $wh.owner != $who
call ui.alert "Only the owner can delete this warehouse."
else
if $input.deleteConfirm != "DELETE"
call ui.alert "Type DELETE exactly first."
else
set wh.deleted true
if $wh.controllerPair != nil
call db.set "paircodes" $wh.controllerPair nil
endif
if $wh.terminalPair != nil
call db.set "paircodes" $wh.terminalPair nil
endif
call db.set "warehouses" $input.warehouseId $wh
call db.set "controllers" $input.warehouseId nil
call db.set "commands" $input.warehouseId nil
call db.set "cmdq-${input.warehouseId}" "q1" nil
call db.set "cmdq-${input.warehouseId}" "q2" nil
call db.set "cmdq-${input.warehouseId}" "q3" nil
call db.set "cmdq-${input.warehouseId}" "q4" nil
call db.set "queries" $input.warehouseId nil
call db.set "views" $input.warehouseId nil
call db.set "views-${input.warehouseId}" $who nil
call db.set "results" $input.warehouseId nil
call db.list "ul-${who}" -> links
if $links.slot1.id == $input.warehouseId
call db.set "ul-${who}" "slot1" nil
endif
if $links.slot2.id == $input.warehouseId
call db.set "ul-${who}" "slot2" nil
endif
if $links.slot3.id == $input.warehouseId
call db.set "ul-${who}" "slot3" nil
endif
if $links.slot4.id == $input.warehouseId
call db.set "ul-${who}" "slot4" nil
endif
if $links.slot5.id == $input.warehouseId
call db.set "ul-${who}" "slot5" nil
endif
if $links.slot6.id == $input.warehouseId
call db.set "ul-${who}" "slot6" nil
endif
if $links.slot7.id == $input.warehouseId
call db.set "ul-${who}" "slot7" nil
endif
if $links.slot8.id == $input.warehouseId
call db.set "ul-${who}" "slot8" nil
endif
call ui.setText "deleteStatus" "WAREHOUSE DELETED. Physical items were not touched."
call ui.setText "settingsSummary" "WAREHOUSE DELETED"
endif
endif
end
]==]
local appFiles={
  ['common.lua']=[==[local M={}
local DATA='/spawnnet/appdata/warehouse/warehouseos'
function M.dataPath(name)return DATA..'/'..tostring(name)end
function M.ensure(path)if path==''or path=='/'or fs.exists(path)then return end;local p=fs.getDir(path);if p and p~=''then M.ensure(p)end;fs.makeDir(path)end
function M.load(name,default)local p=M.dataPath(name);if not fs.exists(p)then return default end;local h=fs.open(p,'r');if not h then return default end;local s=h.readAll();h.close();local ok,t=pcall(textutils.unserialize,s);if not ok or t==nil then return default end;return t end
function M.save(name,t)M.ensure(DATA);local p=M.dataPath(name);if t==nil then if fs.exists(p)then fs.delete(p)end;return true end;local raw=textutils.serialize(t);local tmp=p..'.tmp';if fs.exists(tmp)then fs.delete(tmp)end;local h=assert(fs.open(tmp,'w'));h.write(raw);h.close();if fs.exists(p)then fs.delete(p)end;fs.move(tmp,p);return true end
function M.trim(s)return tostring(s or''):match('^%s*(.-)%s*$')end
function M.comma(n)local s=tostring(math.floor(tonumber(n)or 0));while true do local x,k=s:gsub('^(%d+)(%d%d%d)','%1,%2');s=x;if k==0 then break end end;return s end
function M.displayName(id)local p=tostring(id or''):match(':(.+)$')or tostring(id or'item');p=p:gsub('[_%-]+',' '):gsub('(%a)([%w]*)',function(a,b)return a:upper()..b:lower()end);return p end
function M.modName(id)local x=tostring(id or''):match('^([^:]+):')or'unknown';return M.displayName(x)end
function M.inventoryNames()local a={};for _,n in ipairs(peripheral.getNames())do local ok,l=pcall(peripheral.call,n,'list');if ok and type(l)=='table'then a[#a+1]=n end end;table.sort(a);return a end
function M.inventoryLabel(n)local ok,l=pcall(peripheral.call,n,'list');local stacks=0;local items=0;if ok and type(l)=='table'then for _,v in pairs(l)do stacks=stacks+1;items=items+(tonumber(v.count)or 0)end end;return n..' ['..tostring(peripheral.getType(n)or'?')..'] '..stacks..' stacks / '..items..' items'end
function M.findWirelessModem()for _,n in ipairs(peripheral.getNames())do if peripheral.getType(n)=='modem'then local ok,w=pcall(peripheral.call,n,'isWireless');if ok and w then return n end end end end
function M.epoch()if os.epoch then return math.floor(os.epoch('utc')/1000)end;return math.floor(os.clock())end
function M.log(message)M.ensure(DATA);local p=M.dataPath('service.log');local old='';if fs.exists(p)then local h=fs.open(p,'r');if h then old=h.readAll()or'';h.close()end end;old=old..tostring(M.epoch())..' '..tostring(message)..'\n';if #old>12000 then old=old:sub(-10000)end;local h=fs.open(p,'w');if h then h.write(old);h.close()end end
function M.selectWarehouse(id,name)local util=dofile('/spawnnet/lib/util.lua');local p='/spawnnet/local/warehouse.db';local st=util.loadTable(p,{});util.tablePathSet(st,'warehouse.selected',id);util.tablePathSet(st,'warehouse.name',name);util.saveTable(p,st)end
-- SpawnNet 2.3 owns startup and service registration. Native applications must
-- never inspect, replace, or delete another program's startup files.
function M.cleanupLegacyStartup()return true end
function M.web(event,input,timeout)local net=dofile('/spawnnet/client/net.lua');return net.call('web','runAction',{domain='warehouse',event=event,input=input or{},args={}},{noAuth=true,timeout=timeout})end
return M]==],
  ['controller.lua']=[==[local gui=dofile('/spawnnet/client/gui.lua')
local crypto=dofile('/spawnnet/lib/crypto.lua')
local common=dofile('/spawnnet/apps/warehouse/warehouseos/app/common.lua')
local mode=(...)or'setup';local CFG='controller.db';local RUN='controller.runtime';local PENDING='controller.pending';local cfg=common.load(CFG,nil)
local function choose(title,subtitle,names,allowNone,current)
 local items={};if allowNone then items[#items+1]={label='(none)',name=false}end
 for _,n in ipairs(names)do items[#items+1]={label=(n==current and'* 'or'  ')..common.inventoryLabel(n),name=n}end
 local m=gui.menu(title,subtitle,items);return m and m.name or nil
end
local function acceptPair(pending,result)
 cfg={warehouseId=result.warehouseId,warehouseName=result.warehouseName,token=pending.token,pairRequestId=pending.requestId,name=pending.name,output=pending.output,deposit=pending.deposit,autoDeposit=true};common.save(CFG,cfg);common.save(PENDING,nil);common.selectWarehouse(cfg.warehouseId,cfg.warehouseName);common.save(RUN,nil);common.save('controller.result',nil);gui.toast('CIPHER ACCEPTED // '..tostring(cfg.warehouseName)..' ONLINE',3,true);return true
end
local function sendPair(pending)
 local p,e=common.web('controller_pair',{rid=pending.requestId,code=pending.code,token=pending.token,computerId=os.getComputerID(),name=pending.name},12)
 if p and type(p.result)=='table'and p.result.ok then return acceptPair(pending,p.result)end
 return false,(p and p.result and p.result.error)or e or'Pair failed'
end
local function configure(existing)
 if not common.findWirelessModem()then gui.toast('NETWORK LINK ABSENT // attach a wireless modem for SpawnNet data.',4,false);return false end
 if not existing then local pending=common.load(PENDING,nil);if type(pending)=='table'and pending.requestId then gui.toast('PAIR JOURNAL FOUND // RECONCILING CORE STATE',2,true);local ok,e=sendPair(pending);if ok then return true end;if tostring(e):find('timed out',1,true)then gui.toast('PAIR COMMIT STILL UNCONFIRMED // rerun WarehouseOS to reconcile.',4,false);return false end;common.save(PENDING,nil);gui.toast(tostring(e),4,false)end end
 local code=nil
 if not existing then code=gui.prompt('VAULT CIPHER','Controller pair code from Vault Control:','');if code==''then return false end end
 local names=common.inventoryNames();if #names<2 then gui.toast('PHYSICAL I/O INCOMPLETE // connect Output plus Storage.',4,false);return false end
 local output=choose('EXTRACTION PORT','Website withdrawals materialize here. Excluded from storage.',names,false,existing and existing.output);if not output then return false end
 local rest={};for _,n in ipairs(names)do if n~=output then rest[#rest+1]=n end end
 local deposit=choose('INGEST PORT','Automatic/manual deposits enter here. Every other inventory is storage.',rest,true,existing and existing.deposit)
 local name=gui.prompt('CONTROLLER CALLSIGN','Friendly identity:',existing and existing.name or('Vault Controller #'..os.getComputerID()))
 if existing then existing.output=output;existing.deposit=deposit;existing.name=name;existing.autoDeposit=existing.autoDeposit~=false;common.save(CFG,existing);common.selectWarehouse(existing.warehouseId,existing.warehouseName);gui.toast('PHYSICAL I/O MATRIX COMMITTED',2,true);return true end
 local pending={requestId=crypto.randomHex(12),code=code,token=crypto.randomHex(24),name=name,output=output,deposit=deposit};common.save(PENDING,pending);local ok,e=sendPair(pending);if ok then return true end;gui.toast(tostring(e):find('timed out',1,true)and'PAIR COMMIT UNCONFIRMED // rerun WarehouseOS to reconcile safely.'or tostring(e),4,false);return false
end
if mode=='setup'then if cfg and cfg.token then return configure(cfg)else return configure(nil)end end
if mode=='configure'then if not cfg then gui.toast('Controller is not paired yet.',2,false);return false end;return configure(cfg)end
if mode=='reset'then common.save(CFG,nil);common.save(PENDING,nil);common.save(RUN,nil);common.save('controller.result',nil);gui.toast('Controller pairing removed from this computer.',2,true);return true end
if mode~='service'then return end
if not cfg or not cfg.token then return end
local methodCache={}
local function methods(name)local s=methodCache[name];if s then return s end;s={};if peripheral.getMethods then local ok,a=pcall(peripheral.getMethods,name);if ok and type(a)=='table'then for _,m in ipairs(a)do s[m]=true end end end;methodCache[name]=s;return s end
local detailCache={}
local function tinyHash(v)local raw='';if v~=nil then local ok,x=pcall(textutils.serialize,v);raw=ok and x or tostring(v)end;if raw==''then return''end;local h=5381;for i=1,#raw do h=(h*33+raw:byte(i))%4294967296 end;return string.format('%08x',h)end
local function itemInfo(inv,slot,item)
 local d=nil;if methods(inv).getItemDetail then local ok,x=pcall(peripheral.call,inv,'getItemDetail',slot);if ok and type(x)=='table'then d=x end end
 local raw=tostring(item.name or(d and d.name)or'unknown:item');local meta=tonumber(item.damage or item.metadata or item.dmg or(d and(d.damage or d.metadata or d.dmg)))or 0;local nh=tinyHash(item.nbt or(d and d.nbt));local key=raw..'@'..meta..(nh~=''and('~'..nh)or'');local modId=raw:match('^([^:]+):')or'unknown'
 local x=detailCache[key];if x then return x end;local original=(d and(d.displayName or d.label))or item.displayName or common.displayName(raw);x={key=key,id=raw,meta=meta,nbtHash=nh,originalName=tostring(original),mod=common.modName(raw),modId=modId};detailCache[key]=x;return x
end
local function storageNames()local a={};for _,n in ipairs(common.inventoryNames())do if n~=cfg.output and n~=cfg.deposit then a[#a+1]=n end end;return a end
local index={}
local function scan()
 local idx={};local stores=storageNames()
 for _,inv in ipairs(stores)do local ok,list=pcall(peripheral.call,inv,'list');if ok and type(list)=='table'then for slot,item in pairs(list)do if type(item)=='table'and item.name then local d=itemInfo(inv,slot,item);local it=idx[d.key];if not it then it={key=d.key,id=d.id,meta=d.meta,nbtHash=d.nbtHash,originalName=d.originalName,mod=d.mod,modId=d.modId,amount=0,stacks=0,locations={}};idx[d.key]=it end;local c=tonumber(item.count)or 0;it.amount=it.amount+c;it.stacks=it.stacks+1;it.locations[#it.locations+1]={inv=inv,slot=tonumber(slot),count=c}end end end end
 index=idx;return stores
end
local function aliasMap(rows)local m={};if type(rows)=='table'then for k,v in pairs(rows)do if type(k)=='string'then m[k]=tostring(v or'')elseif type(v)=='table'and v.key then m[v.key]=tostring(v.name or'')end end end;return m end
local q={text='',field='all',mod='',min=0,max=0,alias='all',sort='name_asc',page=1,user=''};local aliases={}
local function makeView()
 local text=tostring(q.text or''):lower();local field=tostring(q.field or'all');local mod=tostring(q.mod or''):lower();local min=tonumber(q.min)or 0;local max=tonumber(q.max)or 0;local am=tostring(q.alias or'all');local a={}
 for _,it in pairs(index)do local alias=aliases[it.key]or'';local name=alias~=''and alias or it.originalName;local nh=(name..' '..it.originalName):lower();local ih=(it.id..' '..it.key):lower();local all=(nh..' '..ih..' '..it.mod..' '..it.modId..' '..it.meta):lower();local match=text==''or(field=='name'and nh:find(text,1,true))or(field=='registry'and ih:find(text,1,true))or(field=='all'and all:find(text,1,true));local modok=mod==''or tostring(it.mod):lower():find(mod,1,true)or tostring(it.modId):lower():find(mod,1,true);local maxok=max<=0 or it.amount<=max;local aliasok=am=='all'or(am=='custom'and alias~='')or(am=='default'and alias=='');if match and modok and it.amount>=min and maxok and aliasok then a[#a+1]={key=it.key,name=name,alias=alias,originalName=it.originalName,id=it.id,meta=it.meta,mod=it.mod,amount=it.amount,stacks=it.stacks,details=it.id..'  meta '..it.meta..'  ['..it.modId..']  original: '..it.originalName}end end
 if q.sort=='amount_desc'then table.sort(a,function(x,y)if x.amount==y.amount then return x.name<y.name end;return x.amount>y.amount end)elseif q.sort=='amount_asc'then table.sort(a,function(x,y)if x.amount==y.amount then return x.name<y.name end;return x.amount<y.amount end)elseif q.sort=='name_desc'then table.sort(a,function(x,y)return tostring(x.name)>tostring(y.name)end)elseif q.sort=='mod'then table.sort(a,function(x,y)if x.mod==y.mod then return x.name<y.name end;return x.mod<y.mod end)else table.sort(a,function(x,y)return tostring(x.name)<tostring(y.name)end)end
 local page=math.max(1,math.floor(tonumber(q.page)or 1));local pages=math.max(1,math.ceil(#a/8));if page>pages then page=pages end;local start=(page-1)*8+1;local v={user=q.user,total=#a,page=page,pages=pages};for i=1,8 do v['item'..i]=a[start+i-1]end;return v
end
local function push(src,target,slot,amount)local ok,n=pcall(peripheral.call,src,'pushItems',target,slot,amount);if ok and tonumber(n)then return tonumber(n)end;return 0 end
local function withdraw(key,amount,target)
 amount=math.max(1,math.min(tonumber(amount)or 1,4096));local it=index[key];if not it then return false,0,'Item is not currently in storage'end;local left,moved=amount,0
 for _,loc in ipairs(it.locations)do if left<=0 then break end;local n=push(loc.inv,target,loc.slot,math.min(left,loc.count));moved=moved+n;left=left-n end;scan()
 if moved<=0 then return false,0,'Nothing moved. Target is full or there is no physical item path.'end;return true,moved,'Withdrew '..moved..' '..tostring((aliases[key]and aliases[key]~=''and aliases[key])or it.originalName)
end
local function deposit(source)
 source=source or cfg.deposit;if not source then return false,0,'No deposit inventory configured'end;if not peripheral.isPresent(source)then return false,0,'Deposit inventory is missing'end
 local ok,list=pcall(peripheral.call,source,'list');if not ok then return false,0,'Deposit inventory unavailable'end;local stores=storageNames();local moved=0
 for slot,item in pairs(list or{})do local left=tonumber(item.count)or 0;for _,t in ipairs(stores)do if left<=0 then break end;local n=push(source,t,tonumber(slot),left);moved=moved+n;left=left-n end end;scan();return moved>0,moved,moved>0 and('Deposited '..moved..' items')or'Nothing moved'
end
local RESULT='controller.result'
common.save(RUN,{running=true,started=common.epoch(),warehouseId=cfg.warehouseId})
local lastAuto=0;local lastRuntime=0;local lastView=0;local lastViewHash='';local lastPersist=-99;scan()
while true do
 local fast=false
 local fresh=common.load(CFG,nil);if not fresh then common.save(RESULT,nil);common.save(RUN,nil);return end;cfg=fresh
 local stores=scan()
 local now=os.clock();if cfg.autoDeposit~=false and cfg.deposit and now-lastAuto>2 then lastAuto=now;local a,m=deposit(cfg.deposit);if a and (tonumber(m)or 0)>0 then stores=scan();fast=true end end
 local total=0;for _,it in pairs(index)do total=total+it.amount end
 local runtimeClock=os.clock();if runtimeClock-lastRuntime>=2 then lastRuntime=runtimeClock;common.save(RUN,{running=true,lastSeen=common.epoch(),warehouseId=cfg.warehouseId,totalItems=total,inventories=#stores})end
 local pendingResult=common.load(RESULT,nil)
 local persist=now-lastPersist>=3;if persist then lastPersist=now end
 local heartbeat={warehouseId=cfg.warehouseId,token=cfg.token,pairRequestId=cfg.pairRequestId,persist=persist,computerId=os.getComputerID(),name=cfg.name,output=cfg.output,deposit=cfg.deposit,autoDeposit=cfg.autoDeposit~=false,outputOnline=cfg.output and peripheral.isPresent(cfg.output)or false,depositOnline=cfg.deposit and peripheral.isPresent(cfg.deposit)or false,firstStorage=stores[1],inventories=#stores,totalItems=total}
 if pendingResult then heartbeat.completedId=pendingResult.requestId;heartbeat.completedOk=pendingResult.ok;heartbeat.completedMoved=pendingResult.moved;heartbeat.completedMessage=pendingResult.message;heartbeat.completedAction=pendingResult.action;heartbeat.completedItem=pendingResult.item;heartbeat.completedUser=pendingResult.user end
 local p,netErr=common.web('controller_heartbeat',heartbeat)
 local r=p and p.result
 if type(r)=='table'then
  if r.deleted or r.replaced then common.save(RESULT,nil);common.save(CFG,nil);common.save(RUN,nil);return end
  if r.ok then
   if cfg.pairRequestId and r.pairReceiptCleared then cfg.pairRequestId=nil;common.save(CFG,cfg)end
   if pendingResult and r.completedAck==pendingResult.requestId then common.save(RESULT,nil);pendingResult=nil end
   if type(r.query)=='table'then q=r.query end;aliases=aliasMap(r.aliases);if r.autoDeposit~=nil and cfg.autoDeposit~=r.autoDeposit then cfg.autoDeposit=r.autoDeposit;common.save(CFG,cfg)end
   local cmdId=r.commandId
   if cmdId and not pendingResult then local ok,moved,msg;if r.commandAction=='withdraw'then ok,moved,msg=withdraw(r.commandItem,r.commandAmount,cfg.output)elseif r.commandAction=='deposit'then ok,moved,msg=deposit(cfg.deposit)else ok,moved,msg=false,0,'Unsupported controller action'end;local res={requestId=cmdId,action=r.commandAction,ok=ok,moved=moved or 0,message=msg or'Complete',item=r.commandItem,user=r.commandUser};common.save(RESULT,res);pendingResult=res;stores=scan();fast=true end
   local vnow=os.clock();if vnow-lastView>=0.75 then local view=makeView();local vh=tinyHash(view);if vh~=lastViewHash or vnow-lastView>=5 then local vp=common.web('controller_view',{warehouseId=cfg.warehouseId,token=cfg.token,view=view});if vp then lastView=vnow;lastViewHash=vh end end end
  end
 else common.save(RUN,{running=true,lastSeen=common.epoch(),warehouseId=cfg.warehouseId,totalItems=total,inventories=#stores,lastError=tostring(netErr or'heartbeat failed')})
 end
 sleep(fast and 0.05 or 0.75)
end]==],
  ['terminal.lua']=[==[local gui=dofile('/spawnnet/client/gui.lua')
local crypto=dofile('/spawnnet/lib/crypto.lua')
local common=dofile('/spawnnet/apps/warehouse/warehouseos/app/common.lua')
local mode=(...)or'setup';local CFG='terminal.db';local RUN='terminal.runtime';local PENDING='terminal.pending';local cfg=common.load(CFG,nil)
local function acceptPair(pending,result)cfg={warehouseId=result.warehouseId,warehouseName=result.warehouseName,terminalId=result.terminalId,slot=result.terminalSlot,token=pending.token,name=pending.name};common.save(CFG,cfg);common.save(PENDING,nil);common.selectWarehouse(cfg.warehouseId,cfg.warehouseName);common.save(RUN,nil);common.save('terminal.result',nil);gui.toast('REMOTE COMMAND LINK ESTABLISHED // '..cfg.name,3,true);return true end
local function sendPair(pending)local p,e=common.web('terminal_pair',{rid=pending.requestId,code=pending.code,token=pending.token,computerId=os.getComputerID(),name=pending.name},12);if p and type(p.result)=='table'and p.result.ok then return acceptPair(pending,p.result)end;return false,(p and p.result and p.result.error)or e or'Pair failed'end
local function configure(existing)
 if not common.findWirelessModem()then gui.toast('NETWORK LINK ABSENT // attach a wireless modem for data only.',4,false);return false end
 if not existing then local pending=common.load(PENDING,nil);if type(pending)=='table'and pending.requestId then gui.toast('PAIR JOURNAL FOUND // RECONCILING CORE STATE',2,true);local ok,e=sendPair(pending);if ok then return true end;if tostring(e):find('timed out',1,true)then gui.toast('PAIR COMMIT STILL UNCONFIRMED // rerun WarehouseOS to reconcile.',4,false);return false end;common.save(PENDING,nil);gui.toast(tostring(e),4,false)end end
 local code=nil;if not existing then code=gui.prompt('REMOTE ACCESS CIPHER','Pair code from Vault Control:','');if code==''then return false end end
 local name=gui.prompt('CONSOLE CALLSIGN','Friendly identity:',existing and existing.name or('Remote Console #'..os.getComputerID()))
 if existing then existing.inventory=nil;existing.name=name;common.save(CFG,existing);common.selectWarehouse(existing.warehouseId,existing.warehouseName);gui.toast('Remote access terminal saved. It does not transfer physical items.',3,true);return true end
 local pending={requestId=crypto.randomHex(12),code=code,token=crypto.randomHex(24),name=name};common.save(PENDING,pending);local ok,e=sendPair(pending);if ok then return true end;gui.toast(tostring(e):find('timed out',1,true)and'PAIR COMMIT UNCONFIRMED // rerun WarehouseOS to reconcile safely.'or tostring(e),4,false);return false
end
if mode=='setup'then if cfg and cfg.token then return configure(cfg)else return configure(nil)end end
if mode=='configure'then if not cfg then gui.toast('Remote terminal is not paired.',2,false);return false end;return configure(cfg)end
if mode=='reset'then common.save(CFG,nil);common.save(PENDING,nil);common.save(RUN,nil);common.save('terminal.result',nil);gui.toast('Remote-terminal pairing removed from this computer.',2,true);return true end
return]==],
  ['service.lua']=[==[local mode=(...)
if mode=='startup'then return end
local common=dofile('/spawnnet/apps/warehouse/warehouseos/app/common.lua')
local APP='/spawnnet/apps/warehouse/warehouseos/app/'
while true do
 if common.load('controller.db',nil)then
  common.log('WH// controller watchdog engaging')
  local ok=os.run({},APP..'controller.lua','service')
  common.log(ok and'WH// controller exited; re-engaging'or'WH// controller fault; initiating recovery')
 else sleep(2)end
 sleep(1)
end]==],
  ['setup.lua']=[==[local gui=dofile('/spawnnet/client/gui.lua')
local common=dofile('/spawnnet/apps/warehouse/warehouseos/app/common.lua')
local APP='/spawnnet/apps/warehouse/warehouseos/app/'
common.cleanupLegacyStartup()
-- Installation registers service.lua with SpawnNet's supervisor. Keeping this
-- inside the package boundary prevents applications from controlling services
-- belonging to other packages.
local function ensureAutoStart()return true end
local function diagnostics()
 local c=common.load('controller.db',nil);local t=common.load('terminal.db',nil);local cr=common.load('controller.runtime',nil);local inv=common.inventoryNames();local lines={}
 lines[#lines+1]='WarehouseOS 2.5.2 diagnostics';lines[#lines+1]='Wireless modem: '..tostring(common.findWirelessModem()or'NOT FOUND');lines[#lines+1]='Inventory peripherals: '..#inv
 for _,n in ipairs(inv)do lines[#lines+1]='  '..common.inventoryLabel(n)end
 lines[#lines+1]='';lines[#lines+1]='VAULT CONTROLLER // '..(c and((c.warehouseName or c.warehouseId)..' / '..tostring(c.name))or'NOT CONFIGURED')
 if c then lines[#lines+1]='  Output: '..tostring(c.output);lines[#lines+1]='  Deposit: '..tostring(c.deposit or'(none)');lines[#lines+1]='  Auto-deposit: '..(c.autoDeposit~=false and'ON'or'OFF');lines[#lines+1]='  Worker heartbeat: '..(cr and tostring(math.max(0,common.epoch()-(cr.lastSeen or cr.started or 0)))..'s ago'or'not running')end
 lines[#lines+1]='REMOTE COMMAND // '..(t and((t.warehouseName or t.warehouseId)..' / '..tostring(t.name)..' / '..tostring(t.terminalId))or'NOT CONFIGURED')
 if t then lines[#lines+1]='  Background worker: not required';lines[#lines+1]='  Physical item transfer: DISABLED BY DESIGN'end
 lines[#lines+1]='SpawnNet supervisor: PACKAGE-MANAGED / AUTO-RESTART';lines[#lines+1]='Security boundary: SPAWNNET 2.3 CAPABILITY SANDBOX'
 gui.viewer('WH// SYSTEM DIAGNOSTICS',table.concat(lines,'\n'),'CITADEL LINK // 2.5.2')
end
while true do
 local c=common.load('controller.db',nil);local t=common.load('terminal.db',nil)
 local items={
  {label=(c and'Reconfigure Warehouse Controller'or'Set up Warehouse Controller'),action='controller'},
  {label=(t and'Reconfigure Remote Terminal'or'Set up Remote Terminal'),action='terminal'},
  {label='Diagnostics / detected inventories',action='diag'},
  {label=(c or t)and'Open paired warehouse terminal'or'Open spn://warehouse',action='web'},
 }
 if c then items[#items+1]={label='Reset Controller pairing on this computer',action='resetc'}end
 if t then items[#items+1]={label='Reset Remote Terminal pairing on this computer',action='resett'}end
 items[#items+1]={label='WATCHDOG // ARMED BY SPAWNNET',disabled=true}
 items[#items+1]={label='Exit to Nexus',action='exit'}
 local m=gui.menu('WH// COMMAND CONSOLE 2.5.2','PHYSICAL STORAGE LINK // SUPERVISED // ENCRYPTED',items)
 if not m or m.action=='exit'then return
 elseif m.action=='controller'then os.run({},APP..'controller.lua',c and'configure'or'setup')
 elseif m.action=='terminal'then os.run({},APP..'terminal.lua',t and'configure'or'setup')
 elseif m.action=='diag'then diagnostics()
 elseif m.action=='web'then local x=c or t;if x then common.selectWarehouse(x.warehouseId,x.warehouseName)end;shell.run('/spawnnet/client/browser.lua',x and'spn://warehouse/terminal'or'spn://warehouse')
 elseif m.action=='resetc'then if gui.confirm('RESET CONTROLLER','Remove this computer controller pairing? The warehouse and physical items are not deleted.')then os.run({},APP..'controller.lua','reset')end
 elseif m.action=='resett'then if gui.confirm('RESET REMOTE TERMINAL','Remove this computer remote-terminal pairing?')then os.run({},APP..'terminal.lua','reset')end
 end
end]==],
}

for name,src in pairs(appFiles)do
 if name:sub(-4)=='.lua'then local f,e=loadstring(src,'@warehouseos/'..name);if not f then error('WarehouseOS package syntax error in '..name..': '..tostring(e),0)end end
end
if #clientScript>30000 then error('Client SpawnScript exceeds SpawnNet limit',0)end
if #serverScript>30000 then error('Server SpawnScript exceeds SpawnNet limit',0)end


local function dbGet(col,key)
 local p=net.call('db','get',{domain=DOMAIN,collection=col,key=key})
 return p and p.value or nil
end
local function dbSet(col,key,value)
 local p,e=net.call('db','set',{domain=DOMAIN,collection=col,key=key,value=value})
 if not p then error('WarehouseOS migration db.set '..tostring(col)..'/'..tostring(key)..': '..tostring(e),0)end
 return true
end
local function dbList(col,limit)
 local p,e=net.call('db','list',{domain=DOMAIN,collection=col,limit=limit or 200})
 if not p then error('WarehouseOS migration db.list '..tostring(col)..': '..tostring(e),0)end
 return p.rows or{}
end
local function dbClear(col)
 local p,e=net.call('db','clear',{domain=DOMAIN,collection=col})
 if not p then error('WarehouseOS migration db.clear '..tostring(col)..': '..tostring(e),0)end
 return true
end
local function ensureUserLink(user,wid,name,role)
 if not user or user==''then return end
 local col='ul-'..tostring(user);local empty=nil
 for i=1,8 do
  local k='slot'..i;local v=dbGet(col,k)
  if type(v)=='table'and v.id==wid then dbSet(col,k,{id=wid,name=name,role=role});return end
  if v==nil and not empty then empty=k end
 end
 if empty then dbSet(col,empty,{id=wid,name=name,role=role})end
end
local function migrateExisting()
 local moved=0
 for _,row in ipairs(dbList('warehouses',200))do
  local wh=(type(row)=='table'and row.value)or row
  local wid=(type(row)=='table'and row.key)or(type(wh)=='table'and wh.id)
  if type(wh)=='table'and wid and not wh.deleted then
   if wh.autoDeposit==nil then wh.autoDeposit=true;dbSet('warehouses',wid,wh)end
   local members={};local owner=tostring(wh.owner or'')
   if owner~=''then members[#members+1]={name=owner,role='owner'};ensureUserLink(owner,wid,wh.name or wid,'owner')end
   for _,rr in ipairs(dbList('roles-'..wid,200))do
    local user=type(rr)=='table'and rr.key or nil
    local rv=type(rr)=='table'and rr.value or nil
    local role=type(rv)=='table'and rv.role or tostring(rv or'viewer')
    if user and user~=''and user~=owner then members[#members+1]={name=user,role=role};ensureUserLink(user,wid,wh.name or wid,role)end
   end
   for i=1,math.min(8,#members)do dbSet('members-'..wid,'slot'..i,members[i])end
   local legacySlots=dbList('tslots-'..wid,20)
   if #legacySlots==0 then legacySlots=dbList('terminals-'..wid,20)end
   local fallbackSlot=1
   for _,sr in ipairs(legacySlots)do
    local sk=type(sr)=='table'and sr.key or nil
    local sv=type(sr)=='table'and(sr.value or sr)or nil
    local tid=type(sv)=='table'and sv.id or(type(sv)=='string'and sv or nil)
    if not sk or sk:sub(1,4)~='slot'then sk='slot'..fallbackSlot;fallbackSlot=fallbackSlot+1 end
    if tid and fallbackSlot<=5 then
     local old=dbGet('terms-'..wid,tid);if type(old)~='table'then old=sv end
     dbSet('terminalslots-'..wid,sk,tid)
     if type(old)=='table'then
      if old.token then dbSet('terminaltokens-'..wid,tid,old.token)end
      dbSet('terminalnames-'..wid,tid,old.name or tid)
      dbSet('terminallast-'..wid,tid,tonumber(old.lastSeen)or 0)
      if old.computerId then dbSet('terminalcomputers-'..wid,tid,old.computerId)end
     end
    end
   end
   if not dbGet('history-'..wid,'h1')then
    local oldHist=dbList('history-'..wid,20)
    local hi=1
    for i=#oldHist,1,-1 do if hi>8 then break end;local v=oldHist[i];if type(v)=='table'then dbSet('history-'..wid,'h'..hi,v);hi=hi+1 end end
   end
   moved=moved+1
  end
 end
 return moved
end


local repair240=dbGet('warehouseos-meta','2.5.0-serializer-repair')
if not repair240 then
 -- 2.3.x stored the exact same result table in both results and history. The
 -- SpawnNet backend serializer rejects repeated references. Remove the duplicate
 -- collection first so every later heartbeat and terminal save can persist.
 dbClear('results');dbClear('terminalcommands');dbClear('commands')
 dbSet('warehouseos-meta','2.5.0-serializer-repair',true)
 print('Removed duplicated result references and obsolete remote-transfer queues.')
end

local resetOld=dbGet('warehouseos-meta','2.3.1-state-repair')
if not resetOld then
 dbClear('commands');dbClear('terminalcommands');dbSet('warehouseos-meta','2.3.1-state-repair',true)
 print('Cleared stale WarehouseOS command slots and repaired terminal indexes for 2.3.1.')
end

local resetAck=dbGet('warehouseos-meta','2.2.1-queue-reset')
if not resetAck then
 dbClear('commands');dbClear('terminalcommands');dbSet('warehouseos-meta','2.2.1-queue-reset',true)
 print('Cleared stuck WarehouseOS 2.2.0 acknowledgement slots.')
end

local resetHeartbeat=dbGet('warehouseos-meta','2.3-heartbeat-reset')
if not resetHeartbeat then
 dbClear('commands');dbClear('terminalcommands');dbSet('warehouseos-meta','2.3-heartbeat-reset',true)
 print('Cleared legacy operation locks for heartbeat transaction protocol.')
end

local reset250=dbGet('warehouseos-meta','2.5.0-command-queue-reset')
if not reset250 then
 dbClear('commands');dbClear('views')
 for _,row in ipairs(dbList('warehouses',200))do
  local wh=(type(row)=='table'and row.value)or row
  local wid=(type(row)=='table'and row.key)or(type(wh)=='table'and wh.id)
  if wid then dbClear('cmdq-'..tostring(wid));dbClear('views-'..tostring(wid))end
 end
 dbSet('warehouseos-meta','2.5.0-command-queue-reset',true)
 print('Installed the persistent four-slot controller queue and per-user live views.')
end

print('WarehouseOS 2.5.2 preflight: OK')
local migrated=migrateExisting()
print('Existing active warehouse records migrated/verified: '..tostring(migrated))
print('Publishing WarehouseOS website...')
local current=net.call('web','getSite',{domain=DOMAIN})
if current and current.site and current.site.draft and current.site.draft.pages then
 for path in pairs(current.site.draft.pages)do if not pages[path]then net.call('web','deletePage',{domain=DOMAIN,path=path})end end
end
local order={};for path in pairs(pages)do order[#order+1]=path end;table.sort(order)
for _,path in ipairs(order)do
 local x,e=net.call('web','savePage',{domain=DOMAIN,path=path,page=pages[path]})
 if not x then error('savePage '..path..': '..tostring(e),0)end
 print('  page '..path..' OK')
end
call('web','saveScripts',{domain=DOMAIN,clientScript=clientScript,serverScript=serverScript})
call('web','settings',{domain=DOMAIN,title='WarehouseOS',description='ME-style networked storage powered by SpawnNet Core and physical ComputerCraft inventory nodes.',tags={'warehouse','storage','inventory','me','app'}})
call('web','publish',{domain=DOMAIN,note='WarehouseOS 2.5.2 - crash-safe idempotent pairing, live inventory, queued physical I/O, and controller watchdog'})
print('Publishing installable WarehouseOS package...')
call('package','publish',{
 domain=DOMAIN,name='warehouseos',title='WarehouseOS',version='2.5.2',
 description='Physical warehouse controller with crash-safe pairing, reliable queued I/O, live web inventory, access-only remote consoles, and an automatically supervised controller service.',
 permissions={'filesystem','peripheral','modem','rednet','shell','startup','commands'},
 entry='setup.lua',service='service.lua',runAfterInstall=true,
 commands={warehouseos='setup.lua'},files=appFiles
})
term.setTextColor(colors.lime);print('WAREHOUSEOS 2.5.2 PUBLISHED');term.setTextColor(colors.white)
print('Open: spn://warehouse')
print('Install button: native SpawnNet confirmation -> WarehouseOS package')
print('Local management command after install: warehouseos')
print('Background service: registered with SpawnNet and supervised automatically across worker crashes and reboots.')
