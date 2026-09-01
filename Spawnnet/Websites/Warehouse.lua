-- WarehouseOS 2.0.0 - SpawnNet Core-Hosted Edition
local net=dofile('/spawnnet/client/net.lua')
local auth=dofile('/spawnnet/client/auth_client.lua')
local util=dofile('/spawnnet/lib/util.lua')
local C=colors
local DOMAIN='warehouse'
if not net.loadSession()then local s,e=auth.ensureLogin();if not s then error(e,0)end end
local function call(s,a,p,o)local x,e=net.call(s,a,p or{},o);if not x then error(tostring(e),0)end;return x end
local existing=net.call('dns','resolve',{domain=DOMAIN},{noAuth=true})
if not existing then call('dns','register',{domain=DOMAIN,title='WarehouseOS'})else local mine=net.call('web','getSite',{domain=DOMAIN});if not mine then error('spn://warehouse exists but is not owned by this account',0)end end
local function add(p,e)p.elements[#p.elements+1]=e;return e end
local function hidden(p,id,v)add(p,{type='input',id=id,x=1,y=1,w=1,value=v or'',visible=false})end
local function base(title,sub,mode)local p={title=title,background=C.black,elements={}};hidden(p,'pageMode',mode or'');add(p,{type='panel',x=1,y=1,w='100%',h=4,bg=C.gray,children={{type='heading',x=2,y=1,w=47,text='WAREHOUSEOS 2',fg=C.yellow,bg=C.gray},{type='text',x=2,y=2,w=47,text=sub or title,fg=C.lightGray,bg=C.gray,align='center'}}});return p end
local function nav(p)y=5;add(p,{type='button',x=1,y=y,w=9,text='HOME',bg=C.blue,action={type='navigate',target='spn://warehouse/'}});add(p,{type='button',x=11,y=y,w=9,text='CREATE',bg=C.blue,action={type='navigate',target='spn://warehouse/create'}});add(p,{type='button',x=21,y=y,w=9,text='MY',bg=C.purple,action={type='navigate',target='spn://warehouse/my'}});add(p,{type='button',x=31,y=y,w=9,text='INSTALL',bg=C.lime,fg=C.black,action={type='install',package='warehouseos'}});add(p,{type='button',x=41,y=y,w=9,text='HELP',bg=C.gray,action={type='navigate',target='spn://warehouse/help'}})end
local pages={}
do local p=base('WarehouseOS','Turn wired chests into a SpawnNet ME-style storage network','home');nav(p)
 add(p,{type='badge',x=3,y=9,w=45,text='NO DEDICATED HOST COMPUTER REQUIRED',bg=C.lime,fg=C.black,align='center'})
 add(p,{type='heading',x=3,y=12,w=45,text='YOUR STORAGE. ONE TERMINAL.',fg=C.yellow})
 add(p,{type='text',x=3,y=14,w=45,h=5,text='Create a warehouse, install WarehouseOS directly from this website, pair the computer attached to your chests, choose Output + Deposit, and every other detected inventory becomes storage.'})
 add(p,{type='button',x=3,y=20,w=22,text='CREATE WAREHOUSE',bg=C.blue,action={type='navigate',target='spn://warehouse/create'}})
 add(p,{type='button',x=27,y=20,w=22,text='INSTALL WAREHOUSEOS',bg=C.lime,fg=C.black,action={type='install',package='warehouseos'}})
 add(p,{type='button',x=3,y=23,w=45,text='MY WAREHOUSES',bg=C.purple,action={type='navigate',target='spn://warehouse/my'}})
 add(p,{type='heading',x=3,y=28,w=45,text='REMOTE TERMINALS',fg=C.yellow})
 add(p,{type='text',x=3,y=30,w=45,h=4,text='At another location: open this site, install the same WarehouseOS package, pair it as a Remote Terminal, choose its local chest, and use it as a delivery/deposit endpoint.'})
 pages['/']=p end

do local p=base('Create Warehouse','The backend lives on the SpawnNet Core','create');nav(p)
 add(p,{type='heading',x=3,y=9,w=45,text='CREATE A NEW WAREHOUSE',fg=C.yellow})
 add(p,{type='input',id='warehouseName',x=3,y=12,w=45,value='My Warehouse',placeholder='Warehouse name'})
 add(p,{type='button',x=3,y=15,w=45,text='CREATE WAREHOUSE',bg=C.lime,fg=C.black,action={type='server',event='create_submit'}})
 add(p,{type='badge',id='createStatus',x=3,y=18,w=45,text='READY',bg=C.gray,align='center'})
 add(p,{type='text',id='createId',x=3,y=21,w=45,h=2,text='Warehouse ID: -'})
 add(p,{type='text',id='createPair',x=3,y=24,w=45,h=2,text='Controller pair code: -'})
 add(p,{type='button',x=3,y=28,w=45,text='INSTALL WAREHOUSEOS ON THIS COMPUTER',bg=C.blue,action={type='install',package='warehouseos'}})
 add(p,{type='text',x=3,y=31,w=45,h=5,text='After install, run the setup when SpawnNet asks. Choose Warehouse Controller, enter the pair code above, select Main Output and Main Deposit. All remaining connected inventories are storage.'})
 pages['/create']=p end

do local p=base('My Warehouses','Open a warehouse terminal','my');nav(p);for i=1,8 do hidden(p,'wid'..i,'');hidden(p,'wname'..i,'')end
 add(p,{type='heading',x=3,y=9,w=45,text='MY WAREHOUSES',fg=C.yellow})
 for i=1,8 do add(p,{type='button',id='wh'..i,x=3,y=10+i*3,w=45,text='-',bg=i%2==0 and C.gray or C.blue,visible=false,action={type='event',event='open_wh'..i}})end
 add(p,{type='text',x=3,y=36,w=45,h=2,text='Shows the first eight warehouses linked to your SpawnNet account.'})
 pages['/my']=p end

do local p=base('Warehouse Terminal','Search, withdraw, deposit and rename items','terminal');nav(p);p.liveInterval=2;p.liveServerEvent='terminal_refresh';hidden(p,'warehouseId','');hidden(p,'selectedItemKey','');hidden(p,'terminal','main');hidden(p,'searchPage','1');for i=1,8 do hidden(p,'itemKey'..i,'');hidden(p,'itemName'..i,'')end;for i=1,4 do hidden(p,'terminalId'..i,'')end
 add(p,{type='badge',id='warehouseTitle',x=3,y=8,w=45,text='WAREHOUSE',bg=C.purple,align='center'})
 add(p,{type='text',id='warehouseState',x=3,y=10,w=45,h=1,text='Waiting for controller...'})
 add(p,{type='input',id='searchText',x=3,y=12,w=23,value='',placeholder='Search item/name/id'})
 add(p,{type='input',id='searchMod',x=27,y=12,w=12,value='',placeholder='Mod'})
 add(p,{type='input',id='searchMin',x=40,y=12,w=9,value='0',placeholder='Min'})
 add(p,{type='select',id='searchSort',x=3,y=14,w=15,value='name',options={'name','amount'}})
 add(p,{type='button',x=19,y=14,w=30,text='SEARCH / REFRESH',bg=C.blue,action={type='server',event='query_submit'}})
 add(p,{type='text',id='searchState',x=3,y=16,w=45,text='Search results appear below.'})
 for i=1,8 do add(p,{type='button',id='item'..i,x=3,y=16+i*2,w=45,text='-',bg=i%2==0 and C.gray or C.black,visible=false,action={type='event',event='pick_item'..i}})end
 add(p,{type='text',id='selectedItem',x=3,y=34,w=45,text='Selected: none'})
 add(p,{type='input',id='aliasName',x=3,y=36,w=29,value='',placeholder='Custom display name'})
 add(p,{type='button',x=33,y=36,w=16,text='SAVE NAME',bg=C.purple,action={type='server',event='alias_save'}})
 add(p,{type='input',id='quantity',x=3,y=39,w=12,value='64'})
 add(p,{type='button',x=16,y=39,w=16,text='WITHDRAW',bg=C.lime,fg=C.black,action={type='server',event='withdraw_submit'}})
 add(p,{type='button',x=33,y=39,w=16,text='DEPOSIT',bg=C.cyan,fg=C.black,action={type='server',event='deposit_submit'}})
 add(p,{type='text',id='targetState',x=3,y=42,w=45,text='Delivery target: Main Warehouse'})
 add(p,{type='button',x=3,y=44,w=14,text='MAIN',bg=C.blue,action={type='event',event='target_main'}})
 add(p,{type='button',id='target1',x=18,y=44,w=15,text='-',visible=false,bg=C.gray,action={type='event',event='target_1'}})
 add(p,{type='button',id='target2',x=34,y=44,w=15,text='-',visible=false,bg=C.gray,action={type='event',event='target_2'}})
 add(p,{type='button',id='target3',x=18,y=46,w=15,text='-',visible=false,bg=C.gray,action={type='event',event='target_3'}})
 add(p,{type='button',id='target4',x=34,y=46,w=15,text='-',visible=false,bg=C.gray,action={type='event',event='target_4'}})
 add(p,{type='text',id='operationStatus',x=3,y=49,w=45,h=2,text='Ready.'})
 add(p,{type='button',x=3,y=53,w=14,text='MEMBERS',bg=C.purple,action={type='navigate',target='spn://warehouse/members'}})
 add(p,{type='button',x=18,y=53,w=14,text='HISTORY',bg=C.gray,action={type='navigate',target='spn://warehouse/history'}})
 add(p,{type='button',x=33,y=53,w=16,text='SETTINGS',bg=C.gray,action={type='navigate',target='spn://warehouse/settings'}})
 pages['/terminal']=p end

do local p=base('Warehouse Settings','Pair controllers and remote terminals','settings');nav(p);hidden(p,'warehouseId','')
 add(p,{type='badge',id='warehouseTitle',x=3,y=9,w=45,text='WAREHOUSE',bg=C.gray,align='center'})
 add(p,{type='text',id='settingsSummary',x=3,y=12,w=45,h=3,text='Loading...'})
 add(p,{type='button',x=3,y=17,w=45,text='GENERATE NEW CONTROLLER PAIR CODE',bg=C.orange,fg=C.black,action={type='server',event='controller_code_submit'}})
 add(p,{type='text',id='controllerPair',x=3,y=20,w=45,text='Controller pair code: -'})
 add(p,{type='button',x=3,y=24,w=45,text='GENERATE REMOTE TERMINAL PAIR CODE',bg=C.cyan,fg=C.black,action={type='server',event='terminal_code_submit'}})
 add(p,{type='text',id='terminalPair',x=3,y=27,w=45,text='Remote terminal pair code: -'})
 add(p,{type='button',x=3,y=30,w=45,text='INSTALL WAREHOUSEOS HERE',bg=C.lime,fg=C.black,action={type='install',package='warehouseos'}})
 add(p,{type='text',id='terminal1',x=3,y=34,w=45,text='-'});add(p,{type='text',id='terminal2',x=3,y=36,w=45,text='-'});add(p,{type='text',id='terminal3',x=3,y=38,w=45,text='-'});add(p,{type='text',id='terminal4',x=3,y=40,w=45,text='-'})
 add(p,{type='heading',x=3,y=44,w=45,text='DANGER ZONE',fg=C.red});add(p,{type='input',id='deleteConfirm',x=3,y=47,w=45,value='',placeholder='Type DELETE'});add(p,{type='button',x=3,y=50,w=45,text='DELETE WAREHOUSE',bg=C.red,action={type='server',event='delete_warehouse_submit'}});add(p,{type='text',id='deleteStatus',x=3,y=53,w=45,h=2,text='Physical chest contents are never deleted.'})
 pages['/settings']=p end

do local p=base('Members','Warehouse access roles','members');nav(p);hidden(p,'warehouseId','')
 add(p,{type='badge',id='warehouseTitle',x=3,y=9,w=45,text='WAREHOUSE',bg=C.purple,align='center'});add(p,{type='input',id='memberName',x=3,y=13,w=28,placeholder='SpawnNet username'});add(p,{type='select',id='memberRole',x=32,y=13,w=17,value='viewer',options={'viewer','depositor','withdrawer','operator','admin'}});add(p,{type='button',x=3,y=16,w=45,text='GRANT / UPDATE ACCESS',bg=C.lime,fg=C.black,action={type='server',event='invite_submit'}});add(p,{type='text',id='memberStatus',x=3,y=19,w=45,h=3,text='Owner/admin can share this warehouse.'});pages['/members']=p end

do local p=base('History','Recent warehouse operations','history');nav(p);hidden(p,'warehouseId','');for i=1,8 do add(p,{type='text',id='history'..i,x=3,y=8+i*3,w=45,h=2,text='-'})end;add(p,{type='button',x=3,y=35,w=45,text='REFRESH',bg=C.gray,action={type='server',event='history_refresh'}});pages['/history']=p end

do local p=base('WarehouseOS Help','The simple setup flow','help');nav(p)
 add(p,{type='heading',x=3,y=9,w=45,text='MAIN WAREHOUSE',fg=C.yellow});add(p,{type='text',x=3,y=11,w=45,h=8,text='1. Connect chests to one computer with wired modems/cable. 2. Create a warehouse on this site. 3. Click INSTALL WAREHOUSEOS and approve the native SpawnNet popup. 4. Run setup, choose Warehouse Controller, enter the pair code, choose Output and Deposit. 5. Every other visible inventory is storage. The SpawnNet Core stores warehouse accounts, pairing, commands and website state - there is NO separate WarehouseOS Host.'})
 add(p,{type='heading',x=3,y=21,w=45,text='REMOTE TERMINAL',fg=C.yellow});add(p,{type='text',x=3,y=23,w=45,h=7,text='On another computer, open Warehouse Settings, generate a Remote Terminal code, click INSTALL WAREHOUSEOS, choose Remote Terminal, enter the code and select its local chest. It appears as a delivery target on the main terminal page.'})
 add(p,{type='heading',x=3,y=33,w=45,text='CUSTOM ITEM NAMES',fg=C.yellow});add(p,{type='text',x=3,y=35,w=45,h=5,text='Select an item and give it a custom display name. WarehouseOS keeps registry ID + metadata/NBT identity internally, so ProjectRed components with identical generic names remain distinct physical items.'})
 add(p,{type='button',x=3,y=42,w=45,text='INSTALL WAREHOUSEOS',bg=C.lime,fg=C.black,action={type='install',package='warehouseos'}});pages['/help']=p end

local clientScript=[==[
event load
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
    call server.run "members_refresh"
  endif
  if $mode == "history"
    call local.get "warehouse.selected" -> wid
    call local.get "warehouse.name" -> name
    call ui.setValue "warehouseId" $wid
    call ui.setText "warehouseTitle" $name
    call server.run "history_refresh"
  endif
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
  call ui.setValue "selectedItemKey" $k
  call ui.setText "selectedItem" "Selected: ${n}"
end
event pick_item2
  call input.get "itemKey2" -> k
  call input.get "itemName2" -> n
  call ui.setValue "selectedItemKey" $k
  call ui.setText "selectedItem" "Selected: ${n}"
end
event pick_item3
  call input.get "itemKey3" -> k
  call input.get "itemName3" -> n
  call ui.setValue "selectedItemKey" $k
  call ui.setText "selectedItem" "Selected: ${n}"
end
event pick_item4
  call input.get "itemKey4" -> k
  call input.get "itemName4" -> n
  call ui.setValue "selectedItemKey" $k
  call ui.setText "selectedItem" "Selected: ${n}"
end
event pick_item5
  call input.get "itemKey5" -> k
  call input.get "itemName5" -> n
  call ui.setValue "selectedItemKey" $k
  call ui.setText "selectedItem" "Selected: ${n}"
end
event pick_item6
  call input.get "itemKey6" -> k
  call input.get "itemName6" -> n
  call ui.setValue "selectedItemKey" $k
  call ui.setText "selectedItem" "Selected: ${n}"
end
event pick_item7
  call input.get "itemKey7" -> k
  call input.get "itemName7" -> n
  call ui.setValue "selectedItemKey" $k
  call ui.setText "selectedItem" "Selected: ${n}"
end
event pick_item8
  call input.get "itemKey8" -> k
  call input.get "itemName8" -> n
  call ui.setValue "selectedItemKey" $k
  call ui.setText "selectedItem" "Selected: ${n}"
end

event target_main
  call ui.setValue "terminal" "main"
  call ui.setText "targetState" "Delivery target: Main Warehouse"
end
event target_1
  call input.get "terminalId1" -> t
  call ui.setValue "terminal" $t
  call ui.setText "targetState" "Delivery target: ${t}"
end
event target_2
  call input.get "terminalId2" -> t
  call ui.setValue "terminal" $t
  call ui.setText "targetState" "Delivery target: ${t}"
end
event target_3
  call input.get "terminalId3" -> t
  call ui.setValue "terminal" $t
  call ui.setText "targetState" "Delivery target: ${t}"
end
event target_4
  call input.get "terminalId4" -> t
  call ui.setValue "terminal" $t
  call ui.setText "targetState" "Delivery target: ${t}"
end
]==]
local serverScript=[==[
event create_submit
  call user.name -> who
  if $who == nil
    call ui.alert "Sign in to SpawnNet first."
  else
    random rid 100000 999999
    random pair 10000000 99999999
    concat wid "wh-" $rid
    call time.now -> now
    set wh.id $wid
    set wh.name $input.warehouseName
    set wh.owner $who
    set wh.created $now
    set wh.deleted false
    call db.set "warehouses" $wid $wh
    set role.role "owner"
    call db.set "roles-${wid}" $who $role
    set link.id $wid
    set link.name $input.warehouseName
    set link.role "owner"
    call db.insert "user-${who}" $link -> linkIndex
    set pr.warehouseId $wid
    set pr.kind "controller"
    set pr.owner $who
    call db.set "paircodes" $pair $pr
    call ui.setText "createStatus" "WAREHOUSE CREATED"
    call ui.setText "createId" "Warehouse ID: ${wid}"
    call ui.setText "createPair" "Controller pair code: ${pair}"
  endif
end

event list_warehouses
  call user.name -> who
  if $who == nil
    call ui.alert "Sign in first."
  else
    call db.list "user-${who}" -> links
    call ui.setText "wh1" "${links.1.name}"
    call ui.setValue "wid1" $links.1.id
    call ui.setValue "wname1" $links.1.name
    call ui.setVisible "wh1" $links.1.id
    call ui.setText "wh2" "${links.2.name}"
    call ui.setValue "wid2" $links.2.id
    call ui.setValue "wname2" $links.2.name
    call ui.setVisible "wh2" $links.2.id
    call ui.setText "wh3" "${links.3.name}"
    call ui.setValue "wid3" $links.3.id
    call ui.setValue "wname3" $links.3.name
    call ui.setVisible "wh3" $links.3.id
    call ui.setText "wh4" "${links.4.name}"
    call ui.setValue "wid4" $links.4.id
    call ui.setValue "wname4" $links.4.name
    call ui.setVisible "wh4" $links.4.id
    call ui.setText "wh5" "${links.5.name}"
    call ui.setValue "wid5" $links.5.id
    call ui.setValue "wname5" $links.5.name
    call ui.setVisible "wh5" $links.5.id
    call ui.setText "wh6" "${links.6.name}"
    call ui.setValue "wid6" $links.6.id
    call ui.setValue "wname6" $links.6.name
    call ui.setVisible "wh6" $links.6.id
    call ui.setText "wh7" "${links.7.name}"
    call ui.setValue "wid7" $links.7.id
    call ui.setValue "wname7" $links.7.name
    call ui.setVisible "wh7" $links.7.id
    call ui.setText "wh8" "${links.8.name}"
    call ui.setValue "wid8" $links.8.id
    call ui.setValue "wname8" $links.8.name
    call ui.setVisible "wh8" $links.8.id
  endif
end

event controller_pair
  call db.get "paircodes" $input.code -> pr
  if $pr == nil
    set out.ok false
    set out.error "Pair code not found or already used."
  else
    if $pr.kind != "controller"
      set out.ok false
      set out.error "That is not a controller pair code."
    else
      call db.get "warehouses" $pr.warehouseId -> wh
      set ctrl.token $input.token
      set ctrl.computerId $input.computerId
      set ctrl.name $input.name
      call time.now -> now
      set ctrl.lastSeen $now
      call db.set "controllers" $pr.warehouseId $ctrl
      call db.set "paircodes" $input.code nil
      set out.ok true
      set out.warehouseId $pr.warehouseId
      set out.warehouseName $wh.name
    endif
  endif
  return $out
end

event controller_heartbeat
  call db.get "controllers" $input.warehouseId -> ctrl
  if $ctrl == nil
    set out.ok false
    set out.error "Controller is not paired."
  else
    if $ctrl.token != $input.token
      set out.ok false
      set out.error "Controller token rejected."
    else
      call time.now -> now
      set ctrl.token $input.token
      set ctrl.computerId $input.computerId
      set ctrl.name $input.name
      set ctrl.output $input.output
      set ctrl.deposit $input.deposit
      set ctrl.firstStorage $input.firstStorage
      set ctrl.inventories $input.inventories
      set ctrl.totalItems $input.totalItems
      set ctrl.lastSeen $now
      call db.set "controllers" $input.warehouseId $ctrl
      call db.set "views" $input.warehouseId $input.view
      call db.get "commands" $input.warehouseId -> cmd
      call db.get "queries" $input.warehouseId -> query
      call db.list "aliases-${input.warehouseId}-feed" -> aliases
      set out.ok true
      set out.command $cmd
      set out.query $query
      set out.aliases $aliases
    endif
  endif
  return $out
end

event controller_result
  call db.get "controllers" $input.warehouseId -> ctrl
  if $ctrl != nil
    if $ctrl.token == $input.token
      set res.requestId $input.requestId
      set res.ok $input.ok
      set res.moved $input.moved
      set res.message $input.message
      set res.action $input.action
      set res.item $input.item
      set res.user $input.user
      call time.now -> now
      set res.time $now
      call db.set "results" $input.warehouseId $res
      call db.set "commands" $input.warehouseId nil
      call db.insert "history-${input.warehouseId}" $res -> hx
    endif
  endif
  set out.ok true
  return $out
end

event terminal_pair
  call db.get "paircodes" $input.code -> pr
  if $pr == nil
    set out.ok false
    set out.error "Remote-terminal pair code not found or already used."
  else
    if $pr.kind != "terminal"
      set out.ok false
      set out.error "That is not a remote-terminal pair code."
    else
      random rn 1000 9999
      concat tid "remote-" $rn
      call db.get "warehouses" $pr.warehouseId -> wh
      set t.id $tid
      set t.token $input.token
      set t.computerId $input.computerId
      set t.name $input.name
      set t.inventory $input.inventory
      call time.now -> now
      set t.lastSeen $now
      call db.set "terminal-${pr.warehouseId}" $tid $t
      call db.insert "terminals-${pr.warehouseId}" $t -> ti
      call db.set "paircodes" $input.code nil
      set out.ok true
      set out.warehouseId $pr.warehouseId
      set out.warehouseName $wh.name
      set out.terminalId $tid
    endif
  endif
  return $out
end

event terminal_heartbeat
  call db.get "terminal-${input.warehouseId}" $input.terminalId -> t
  if $t == nil
    set out.ok false
  else
    if $t.token != $input.token
      set out.ok false
    else
      set t.id $input.terminalId
      set t.token $input.token
      set t.name $input.name
      set t.inventory $input.inventory
      set t.computerId $input.computerId
      set t.count $input.count
      call time.now -> now
      set t.lastSeen $now
      call db.set "terminal-${input.warehouseId}" $input.terminalId $t
      concat ck $input.warehouseId ":" $input.terminalId
      call db.get "terminalcommands" $ck -> cmd
      set out.ok true
      set out.command $cmd
    endif
  endif
  return $out
end

event terminal_result
  call db.get "terminal-${input.warehouseId}" $input.terminalId -> t
  if $t != nil
    if $t.token == $input.token
      concat ck $input.warehouseId ":" $input.terminalId
      call db.set "terminalcommands" $ck nil
      set res.requestId $input.requestId
      set res.ok $input.ok
      set res.moved $input.moved
      set res.message $input.message
      set res.action $input.action
      set res.user $input.user
      call time.now -> now
      set res.time $now
      call db.set "results" $input.warehouseId $res
      call db.insert "history-${input.warehouseId}" $res -> hx
    endif
  endif
  set out.ok true
  return $out
end

event query_submit
  call user.name -> who
  call db.get "roles-${input.warehouseId}" $who -> role
  if $role == nil
    call ui.alert "You do not have access to this warehouse."
  else
    set q.text $input.searchText
    set q.mod $input.searchMod
    set q.min $input.searchMin
    set q.sort $input.searchSort
    set q.page $input.searchPage
    call db.set "queries" $input.warehouseId $q
    call ui.setText "searchState" "Searching physical inventory..."
  endif
end

event terminal_refresh
  call user.name -> who
  call db.get "roles-${input.warehouseId}" $who -> role
  if $role == nil
    call ui.setText "warehouseState" "NO ACCESS"
  else
    call db.get "controllers" $input.warehouseId -> ctrl
    call db.get "views" $input.warehouseId -> view
    call db.get "results" $input.warehouseId -> res
    call ui.setText "warehouseState" "ONLINE - ${ctrl.inventories} storage inventories / ${ctrl.totalItems} items"
    call ui.setText "searchState" "Page ${view.page}/${view.pages} - ${view.total} matching item types"
    call db.get "aliases-${input.warehouseId}" $view.item1.key -> a1
    call db.get "aliases-${input.warehouseId}" $view.item2.key -> a2
    call db.get "aliases-${input.warehouseId}" $view.item3.key -> a3
    call db.get "aliases-${input.warehouseId}" $view.item4.key -> a4
    call db.get "aliases-${input.warehouseId}" $view.item5.key -> a5
    call db.get "aliases-${input.warehouseId}" $view.item6.key -> a6
    call db.get "aliases-${input.warehouseId}" $view.item7.key -> a7
    call db.get "aliases-${input.warehouseId}" $view.item8.key -> a8
    call ui.setText "item1" "${view.item1.name}  x${view.item1.amount}"
    call ui.setValue "itemKey1" $view.item1.key
    call ui.setValue "itemName1" $view.item1.name
    call ui.setVisible "item1" $view.item1.key
    call ui.setText "item2" "${view.item2.name}  x${view.item2.amount}"
    call ui.setValue "itemKey2" $view.item2.key
    call ui.setValue "itemName2" $view.item2.name
    call ui.setVisible "item2" $view.item2.key
    call ui.setText "item3" "${view.item3.name}  x${view.item3.amount}"
    call ui.setValue "itemKey3" $view.item3.key
    call ui.setValue "itemName3" $view.item3.name
    call ui.setVisible "item3" $view.item3.key
    call ui.setText "item4" "${view.item4.name}  x${view.item4.amount}"
    call ui.setValue "itemKey4" $view.item4.key
    call ui.setValue "itemName4" $view.item4.name
    call ui.setVisible "item4" $view.item4.key
    call ui.setText "item5" "${view.item5.name}  x${view.item5.amount}"
    call ui.setValue "itemKey5" $view.item5.key
    call ui.setValue "itemName5" $view.item5.name
    call ui.setVisible "item5" $view.item5.key
    call ui.setText "item6" "${view.item6.name}  x${view.item6.amount}"
    call ui.setValue "itemKey6" $view.item6.key
    call ui.setValue "itemName6" $view.item6.name
    call ui.setVisible "item6" $view.item6.key
    call ui.setText "item7" "${view.item7.name}  x${view.item7.amount}"
    call ui.setValue "itemKey7" $view.item7.key
    call ui.setValue "itemName7" $view.item7.name
    call ui.setVisible "item7" $view.item7.key
    call ui.setText "item8" "${view.item8.name}  x${view.item8.amount}"
    call ui.setValue "itemKey8" $view.item8.key
    call ui.setValue "itemName8" $view.item8.name
    call ui.setVisible "item8" $view.item8.key
    call ui.setText "operationStatus" "${res.message}"
    call db.list "terminals-${input.warehouseId}" -> terms
    call ui.setText "target1" "${terms.1.name}"
    call ui.setValue "terminalId1" $terms.1.id
    call ui.setVisible "target1" $terms.1.id
    call ui.setText "target2" "${terms.2.name}"
    call ui.setValue "terminalId2" $terms.2.id
    call ui.setVisible "target2" $terms.2.id
    call ui.setText "target3" "${terms.3.name}"
    call ui.setValue "terminalId3" $terms.3.id
    call ui.setVisible "target3" $terms.3.id
    call ui.setText "target4" "${terms.4.name}"
    call ui.setValue "terminalId4" $terms.4.id
    call ui.setVisible "target4" $terms.4.id
  endif
end

event withdraw_submit
  call user.name -> who
  call db.get "roles-${input.warehouseId}" $who -> role
  if $role == nil
    call ui.alert "No warehouse access."
  else
    if $role.role == "viewer"
      call ui.alert "Viewer role cannot withdraw."
    else
      if $role.role == "depositor"
        call ui.alert "Depositor role cannot withdraw."
      else
        random req 10000000 99999999
        set cmd.requestId $req
        set cmd.action "withdraw"
        set cmd.item $input.selectedItemKey
        set cmd.amount $input.quantity
        set cmd.terminal $input.terminal
        set cmd.user $who
        if $input.terminal != "main"
          call db.get "terminal-${input.warehouseId}" $input.terminal -> t
          set cmd.targetName $t.inventory
        endif
        call db.set "commands" $input.warehouseId $cmd
        call ui.setText "operationStatus" "Withdrawal queued for ${input.terminal}."
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
      call ui.alert "Viewer role cannot deposit."
    else
      if $role.role == "withdrawer"
        call ui.alert "Withdrawer role cannot deposit."
      else
        random req 10000000 99999999
        if $input.terminal == "main"
          set cmd.requestId $req
          set cmd.action "deposit"
          set cmd.user $who
          call db.set "commands" $input.warehouseId $cmd
        else
          call db.get "controllers" $input.warehouseId -> ctrl
          concat ck $input.warehouseId ":" $input.terminal
          set cmd.requestId $req
          set cmd.action "deposit"
          set cmd.user $who
          set cmd.targetName $ctrl.firstStorage
          call db.set "terminalcommands" $ck $cmd
        endif
        call ui.setText "operationStatus" "Deposit queued from ${input.terminal}."
      endif
    endif
  endif
end

event alias_save
  call user.name -> who
  call db.get "roles-${input.warehouseId}" $who -> role
  if $role.role == "owner"
    set a.key $input.selectedItemKey
    set a.name $input.aliasName
    call db.set "aliases-${input.warehouseId}" $input.selectedItemKey $input.aliasName
    call db.insert "aliases-${input.warehouseId}-feed" $a -> ai
    call ui.setText "operationStatus" "Display name saved."
  else
    if $role.role == "admin"
      set a.key $input.selectedItemKey
      set a.name $input.aliasName
      call db.set "aliases-${input.warehouseId}" $input.selectedItemKey $input.aliasName
      call db.insert "aliases-${input.warehouseId}-feed" $a -> ai
      call ui.setText "operationStatus" "Display name saved."
    else
      call ui.alert "Owner/admin required to rename items."
    endif
  endif
end

event alias_reset
  call user.name -> who
  call db.get "roles-${input.warehouseId}" $who -> role
  if $role.role == "owner"
    call db.set "aliases-${input.warehouseId}" $input.selectedItemKey ""
    set a.key $input.selectedItemKey
    set a.name ""
    call db.insert "aliases-${input.warehouseId}-feed" $a -> ai
    call ui.setValue "aliasName" ""
    call ui.setText "operationStatus" "Custom display name removed."
  else
    if $role.role == "admin"
      call db.set "aliases-${input.warehouseId}" $input.selectedItemKey ""
      set a.key $input.selectedItemKey
      set a.name ""
      call db.insert "aliases-${input.warehouseId}-feed" $a -> ai
      call ui.setValue "aliasName" ""
      call ui.setText "operationStatus" "Custom display name removed."
    else
      call ui.alert "Owner/admin required."
    endif
  endif
end

event settings_refresh
  call user.name -> who
  call db.get "roles-${input.warehouseId}" $who -> role
  call db.get "controllers" $input.warehouseId -> ctrl
  call db.list "terminals-${input.warehouseId}" -> terms
  call ui.setText "settingsSummary" "Controller: ${ctrl.name} | Output: ${ctrl.output} | Deposit: ${ctrl.deposit}"
  call ui.setText "terminal1" "${terms.1.id} - ${terms.1.name}"
  call ui.setText "terminal2" "${terms.2.id} - ${terms.2.name}"
  call ui.setText "terminal3" "${terms.3.id} - ${terms.3.name}"
  call ui.setText "terminal4" "${terms.4.id} - ${terms.4.name}"
end

event controller_code_submit
  call user.name -> who
  call db.get "roles-${input.warehouseId}" $who -> role
  if $role.role == "owner"
    random pair 10000000 99999999
    set pr.warehouseId $input.warehouseId
    set pr.kind "controller"
    call db.set "paircodes" $pair $pr
    call ui.setText "controllerPair" "Controller pair code: ${pair}"
  else
    call ui.alert "Owner required."
  endif
end

event terminal_code_submit
  call user.name -> who
  call db.get "roles-${input.warehouseId}" $who -> role
  if $role.role == "owner"
    random pair 10000000 99999999
    set pr.warehouseId $input.warehouseId
    set pr.kind "terminal"
    call db.set "paircodes" $pair $pr
    call ui.setText "terminalPair" "Remote terminal pair code: ${pair}"
  else
    if $role.role == "admin"
      random pair 10000000 99999999
      set pr.warehouseId $input.warehouseId
      set pr.kind "terminal"
      call db.set "paircodes" $pair $pr
      call ui.setText "terminalPair" "Remote terminal pair code: ${pair}"
    else
      call ui.alert "Owner/admin required."
    endif
  endif
end

event invite_submit
  call user.name -> who
  call db.get "roles-${input.warehouseId}" $who -> role
  if $role.role == "owner"
    set nr.role $input.memberRole
    call db.set "roles-${input.warehouseId}" $input.memberName $nr
    call db.get "warehouses" $input.warehouseId -> wh
    set link.id $input.warehouseId
    set link.name $wh.name
    set link.role $input.memberRole
    call db.insert "user-${input.memberName}" $link -> li
    call ui.setText "memberStatus" "Access granted to ${input.memberName}."
  else
    if $role.role == "admin"
      set nr.role $input.memberRole
      call db.set "roles-${input.warehouseId}" $input.memberName $nr
      call db.get "warehouses" $input.warehouseId -> wh
      set link.id $input.warehouseId
      set link.name $wh.name
      set link.role $input.memberRole
      call db.insert "user-${input.memberName}" $link -> li
      call ui.setText "memberStatus" "Access granted to ${input.memberName}."
    else
      call ui.alert "Owner/admin required."
    endif
  endif
end

event members_refresh
  call db.list "roles-${input.warehouseId}" -> roles
  call ui.setText "memberStatus" "Use Grant Access to add/update members."
end

event history_refresh
  call db.list "history-${input.warehouseId}" -> h
  call ui.setText "history1" "${h.1.action}: ${h.1.message}"
  call ui.setText "history2" "${h.2.action}: ${h.2.message}"
  call ui.setText "history3" "${h.3.action}: ${h.3.message}"
  call ui.setText "history4" "${h.4.action}: ${h.4.message}"
  call ui.setText "history5" "${h.5.action}: ${h.5.message}"
  call ui.setText "history6" "${h.6.action}: ${h.6.message}"
  call ui.setText "history7" "${h.7.action}: ${h.7.message}"
  call ui.setText "history8" "${h.8.action}: ${h.8.message}"
end

event delete_warehouse_submit
  call user.name -> who
  call db.get "warehouses" $input.warehouseId -> wh
  if $wh.owner != $who
    call ui.alert "Only the warehouse owner can delete it."
  else
    if $input.deleteConfirm != "DELETE"
      call ui.alert "Type DELETE exactly first."
    else
      set wh.deleted true
      call db.set "warehouses" $input.warehouseId $wh
      call db.set "controllers" $input.warehouseId nil
      call db.set "commands" $input.warehouseId nil
      call db.set "views" $input.warehouseId nil
      call ui.setText "deleteStatus" "WAREHOUSE DELETED. Physical items were not touched."
    endif
  endif
end
]==]
local appFiles={
  ['setup.lua']=[==[local gui=dofile('/spawnnet/client/gui.lua')
local common=dofile('/spawnnet/apps/warehouse/warehouseos/app/common.lua')
local APP='/spawnnet/apps/warehouse/warehouseos/app/'
while true do
 local m=gui.menu('WAREHOUSEOS 2','No dedicated Host computer. SpawnNet Core stores the backend.',{
  {label='Set up this computer as WAREHOUSE CONTROLLER',action='controller'},
  {label='Set up this computer as REMOTE TERMINAL',action='terminal'},
  {label='Install / repair automatic background startup',action='startup'},
  {label='Start WarehouseOS services now',action='start'},
  {label='Open spn://warehouse',action='web'},
  {label='Exit',action='exit'}})
 if not m or m.action=='exit'then return elseif m.action=='controller'then os.run({},APP..'controller.lua','setup')elseif m.action=='terminal'then os.run({},APP..'terminal.lua','setup')elseif m.action=='startup'then common.installStartup();gui.toast('Startup service installed. WarehouseOS will launch on reboot.',3)elseif m.action=='start'then common.installStartup();os.run({},APP..'service.lua','handoff');return elseif m.action=='web'then os.run({},'/spawnnet/client/browser.lua','spn://warehouse')end
end]==],
  ['common.lua']=[==[local M={}
local DATA='/spawnnet/appdata/warehouse/warehouseos'
function M.dataPath(name)return DATA..'/'..tostring(name)end
function M.ensure(path)if path==''or path=='/'then return end;if fs.exists(path)then return end;local p=fs.getDir(path);if p and p~=''then M.ensure(p)end;fs.makeDir(path)end
function M.load(name,default)local p=M.dataPath(name);if not fs.exists(p)then return default end;local h=fs.open(p,'r');if not h then return default end;local s=h.readAll();h.close();local t=textutils.unserialize(s);if t==nil then return default end;return t end
function M.save(name,t)M.ensure(DATA);local h=assert(fs.open(M.dataPath(name),'w'));h.write(textutils.serialize(t));h.close()end
function M.trim(s)return tostring(s or''):match('^%s*(.-)%s*$')end
function M.comma(n)local s=tostring(math.floor(tonumber(n)or 0));while true do local x,k=s:gsub('^(%d+)(%d%d%d)','%1,%2');s=x;if k==0 then break end end;return s end
function M.displayName(id)local p=tostring(id or''):match(':(.+)$')or tostring(id or'item');p=p:gsub('[_%-]+',' '):gsub('(%a)([%w]*)',function(a,b)return a:upper()..b:lower()end);return p end
function M.modName(id)local x=tostring(id or''):match('^([^:]+):')or'unknown';return M.displayName(x)end
function M.inventoryNames()local a={};for _,n in ipairs(peripheral.getNames())do local ok,l=pcall(peripheral.call,n,'list');if ok and type(l)=='table'then a[#a+1]=n end end;table.sort(a);return a end
function M.findWirelessModem()for _,n in ipairs(peripheral.getNames())do if peripheral.getType(n)=='modem'then local ok,w=pcall(peripheral.call,n,'isWireless');if ok and w then return n end end end end
function M.web(event,input)local net=dofile('/spawnnet/client/net.lua');return net.call('web','runAction',{domain='warehouse',event=event,input=input or{},args={}},{noAuth=true})end
function M.installStartup()
 M.ensure(DATA)
 local startup='/startup.lua';local user=M.dataPath('startup.user.lua')
 if fs.exists(startup)then local h=fs.open(startup,'r');local s=h and h.readAll()or'';if h then h.close()end;if s:find('WAREHOUSEOS_2_SERVICE',1,true)then return true end;if not fs.exists(user)then fs.copy(startup,user)end end
 local h=assert(fs.open(startup,'w'));h.write("-- WAREHOUSEOS_2_SERVICE\\nos.run({},'/spawnnet/apps/warehouse/warehouseos/app/service.lua','startup')\\n");h.close();return true
end
return M]==],
  ['controller.lua']=[==[local gui=dofile('/spawnnet/client/gui.lua')
local util=dofile('/spawnnet/lib/util.lua')
local crypto=dofile('/spawnnet/lib/crypto.lua')
local common=dofile('/spawnnet/apps/warehouse/warehouseos/app/common.lua')
local mode=(...)or'setup';local service=mode=='service';local CFG='controller.db';local cfg=common.load(CFG,nil)
local C=colors
local function choose(title,subtitle,names,allowNone)
 local items={};if allowNone then items[#items+1]={label='(none)',name=false}end
 for _,n in ipairs(names)do items[#items+1]={label=n..'  ['..tostring(peripheral.getType(n))..']',name=n}end
 local m=gui.menu(title,subtitle,items);return m and m.name or nil
end
local function setup()
 if not common.findWirelessModem()then gui.toast('Attach a WIRELESS modem so this computer can reach SpawnNet.',4);return false end
 local code=gui.prompt('PAIR WAREHOUSE','Controller pair code from spn://warehouse:','');if code==''then return false end
 local name=gui.prompt('CONTROLLER NAME','Friendly name:','Warehouse Controller #'..os.getComputerID())
 local token=crypto.randomHex(24)
 local p,e=common.web('controller_pair',{code=code,token=token,computerId=os.getComputerID(),name=name})
 if not p or type(p.result)~='table'or not p.result.ok then gui.toast((p and p.result and p.result.error)or e or'Pair failed',4);return false end
 local names=common.inventoryNames();if #names<2 then gui.toast('Connect at least an OUTPUT inventory and one STORAGE inventory.',4);return false end
 local output=choose('MAIN OUTPUT','Website withdrawals appear in this inventory.',names,false);if not output then return false end
 local rest={};for _,n in ipairs(names)do if n~=output then rest[#rest+1]=n end end
 local deposit=choose('MAIN DEPOSIT','Players put deposits here. Every other inventory becomes storage.',rest,true)
 cfg={warehouseId=p.result.warehouseId,warehouseName=p.result.warehouseName,token=token,name=name,output=output,deposit=deposit,autoDeposit=true}
 common.save(CFG,cfg);common.installStartup();gui.toast('Paired to '..tostring(cfg.warehouseName)..'. WarehouseOS will run at startup.',3);return true
end
if not cfg or not cfg.token then if service then return end;if not setup()then return end end
if not service then return true end
local function methods(name)local s={};local ok,a=pcall(peripheral.getMethods,name);if ok and type(a)=='table'then for _,m in ipairs(a)do s[m]=true end end;return s end
local detailCache={}
local function tinyHash(v)local raw='';if v~=nil then local ok,x=pcall(textutils.serialize,v);raw=ok and x or tostring(v)end;if raw==''then return''end;local h=5381;for i=1,#raw do h=(h*33+raw:byte(i))%4294967296 end;return string.format('%08x',h)end
local function itemInfo(inv,slot,item)
 local d=nil;if methods(inv).getItemDetail then local ok,x=pcall(peripheral.call,inv,'getItemDetail',slot);if ok and type(x)=='table'then d=x end end
 local raw=tostring(item.name or(d and d.name)or'unknown:item');local meta=tonumber(item.damage or item.metadata or item.dmg or(d and(d.damage or d.metadata or d.dmg)))or 0;local nh=tinyHash(item.nbt or(d and d.nbt));local key=raw..'@'..meta..(nh~=''and('~'..nh)or'')
 local x=detailCache[key];if x then return x end;local original=(d and(d.displayName or d.label))or item.displayName or common.displayName(raw);x={key=key,id=raw,meta=meta,nbtHash=nh,originalName=tostring(original),mod=common.modName(raw)};detailCache[key]=x;return x
end
local function storageNames()local a={};for _,n in ipairs(common.inventoryNames())do if n~=cfg.output and n~=cfg.deposit then a[#a+1]=n end end;return a end
local index={}
local function scan()
 local idx={};local stores=storageNames()
 for _,inv in ipairs(stores)do local ok,list=pcall(peripheral.call,inv,'list');if ok and type(list)=='table'then for slot,item in pairs(list)do if type(item)=='table'and item.name then local d=itemInfo(inv,slot,item);local it=idx[d.key];if not it then it={key=d.key,id=d.id,meta=d.meta,nbtHash=d.nbtHash,originalName=d.originalName,mod=d.mod,amount=0,stacks=0,locations={}};idx[d.key]=it end;local c=tonumber(item.count)or 0;it.amount=it.amount+c;it.stacks=it.stacks+1;it.locations[#it.locations+1]={inv=inv,slot=tonumber(slot),count=c}end end end end
 index=idx;return stores
end
local function aliasMap(rows)local m={};for _,r in ipairs(type(rows)=='table'and rows or{})do if type(r)=='table'and r.key then m[r.key]=tostring(r.name or'')end end;return m end
local currentQuery={text='',mod='',min=0,sort='name',page=1};local aliases={}
local function makeView()
 local q=tostring(currentQuery.text or''):lower();local mod=tostring(currentQuery.mod or''):lower();local min=tonumber(currentQuery.min)or 0;local a={}
 for _,it in pairs(index)do local alias=aliases[it.key];local name=(alias and alias~='')and alias or it.originalName;local hay=(name..' '..it.originalName..' '..it.id..' '..it.mod):lower();if(q==''or hay:find(q,1,true))and(mod==''or tostring(it.mod):lower():find(mod,1,true))and it.amount>=min then a[#a+1]={key=it.key,name=name,originalName=it.originalName,id=it.id,meta=it.meta,mod=it.mod,amount=it.amount,stacks=it.stacks}end end
 if currentQuery.sort=='amount'then table.sort(a,function(x,y)if x.amount==y.amount then return x.name<y.name end;return x.amount>y.amount end)else table.sort(a,function(x,y)return tostring(x.name)<tostring(y.name)end)end
 local page=math.max(1,math.floor(tonumber(currentQuery.page)or 1));local start=(page-1)*8+1;local v={total=#a,page=page,pages=math.max(1,math.ceil(#a/8))};for i=1,8 do v['item'..i]=a[start+i-1]end;return v
end
local function push(src,target,slot,amount)local ok,n=pcall(peripheral.call,src,'pushItems',target,slot,amount);if ok and tonumber(n)then return tonumber(n)end;return 0 end
local function withdraw(key,amount,target)
 target=target or cfg.output;local it=index[key];if not it then return false,0,'Item is not currently in storage'end;local left=amount;local moved=0;for _,loc in ipairs(it.locations)do if left<=0 then break end;local n=push(loc.inv,target,loc.slot,math.min(left,loc.count));moved=moved+n;left=left-n end;scan();if moved<=0 then return false,0,'Nothing moved. Output/remote target may be full or unreachable.'end;return true,moved,'Withdrew '..moved..' '..tostring((aliases[key]and aliases[key]~=''and aliases[key])or it.originalName)
end
local function deposit(source)
 source=source or cfg.deposit;if not source then return false,0,'No deposit inventory configured'end;local ok,list=pcall(peripheral.call,source,'list');if not ok then return false,0,'Deposit inventory unavailable'end;local stores=storageNames();local moved=0;for slot,item in pairs(list or{})do local left=tonumber(item.count)or 0;for _,t in ipairs(stores)do if left<=0 then break end;local n=push(source,t,tonumber(slot),left);moved=moved+n;left=left-n end end;scan();return moved>0,moved,moved>0 and('Deposited '..moved..' items')or'Nothing moved'
end
local lastCmd=nil;local lastAuto=0;scan()
while true do
 local stores=storageNames();local total=0;for _,it in pairs(index)do total=total+it.amount end
 local view=makeView();local p=common.web('controller_heartbeat',{warehouseId=cfg.warehouseId,token=cfg.token,computerId=os.getComputerID(),name=cfg.name,output=cfg.output,deposit=cfg.deposit,firstStorage=stores[1],inventories=#stores,totalItems=total,view=view})
 local r=p and p.result;if type(r)=='table'and r.ok then if type(r.query)=='table'then currentQuery=r.query end;aliases=aliasMap(r.aliases);local cmd=r.command;if type(cmd)=='table'and cmd.requestId and cmd.requestId~=lastCmd then lastCmd=cmd.requestId;local ok,moved,msg;if cmd.action=='withdraw'then ok,moved,msg=withdraw(cmd.item,tonumber(cmd.amount)or 1,cmd.targetName or(cfg.output))elseif cmd.action=='deposit'then ok,moved,msg=deposit(cfg.deposit)elseif cmd.action=='rescan'then scan();ok,moved,msg=true,0,'Rescanned warehouse'end;common.web('controller_result',{warehouseId=cfg.warehouseId,token=cfg.token,requestId=cmd.requestId,action=cmd.action,ok=ok,moved=moved or 0,message=msg or'Complete',item=cmd.item,user=cmd.user});end end
 local now=os.clock();if cfg.autoDeposit and cfg.deposit and now-lastAuto>3 then lastAuto=now;local ok,m=deposit(cfg.deposit);if ok and m>0 then scan()end end
 sleep(1.5)
end]==],
  ['terminal.lua']=[==[local gui=dofile('/spawnnet/client/gui.lua')
local crypto=dofile('/spawnnet/lib/crypto.lua')
local common=dofile('/spawnnet/apps/warehouse/warehouseos/app/common.lua')
local mode=(...)or'setup';local service=mode=='service';local CFG='terminal.db';local cfg=common.load(CFG,nil)
local function setup()
 if not common.findWirelessModem()then gui.toast('Attach a WIRELESS modem first.',4);return false end
 local code=gui.prompt('PAIR REMOTE TERMINAL','Remote terminal pair code from Warehouse Settings:','');if code==''then return false end
 local invs=common.inventoryNames();if #invs==0 then gui.toast('Connect a local terminal chest/inventory first.',4);return false end
 local items={};for _,n in ipairs(invs)do items[#items+1]={label=n..' ['..tostring(peripheral.getType(n))..']',name=n}end;local pick=gui.menu('REMOTE TERMINAL INVENTORY','Withdrawals arrive here; deposits are taken from here.',items);if not pick then return false end
 local name=gui.prompt('TERMINAL NAME','Friendly name:','Remote Terminal #'..os.getComputerID());local token=crypto.randomHex(24)
 local p,e=common.web('terminal_pair',{code=code,token=token,computerId=os.getComputerID(),name=name,inventory=pick.name})
 if not p or type(p.result)~='table'or not p.result.ok then gui.toast((p and p.result and p.result.error)or e or'Pair failed',4);return false end
 cfg={warehouseId=p.result.warehouseId,warehouseName=p.result.warehouseName,terminalId=p.result.terminalId,token=token,name=name,inventory=pick.name};common.save(CFG,cfg);common.installStartup();gui.toast('Remote terminal '..cfg.terminalId..' paired.',3);return true
end
if not cfg or not cfg.token then if service then return end;if not setup()then return end end
if not service then return true end
local function push(src,target,slot,amount)local ok,n=pcall(peripheral.call,src,'pushItems',target,slot,amount);if ok and tonumber(n)then return tonumber(n)end;return 0 end
local function count()local ok,l=pcall(peripheral.call,cfg.inventory,'list');local n=0;if ok then for _,it in pairs(l or{})do n=n+(tonumber(it.count)or 0)end end;return n end
local function deposit(target)local ok,l=pcall(peripheral.call,cfg.inventory,'list');if not ok then return false,0,'Local terminal inventory offline'end;local moved=0;for slot,it in pairs(l or{})do moved=moved+push(cfg.inventory,target,tonumber(slot),tonumber(it.count) or 64)end;if moved<=0 then return false,0,'No physical item path to warehouse storage.'end;return true,moved,'Deposited '..moved..' items from '..cfg.name end
local lastCmd=nil
while true do
 local p=common.web('terminal_heartbeat',{warehouseId=cfg.warehouseId,terminalId=cfg.terminalId,token=cfg.token,computerId=os.getComputerID(),name=cfg.name,inventory=cfg.inventory,count=count()});local r=p and p.result
 if type(r)=='table'and r.ok and type(r.command)=='table'and r.command.requestId and r.command.requestId~=lastCmd then local cmd=r.command;lastCmd=cmd.requestId;local ok,moved,msg;if cmd.action=='deposit'then ok,moved,msg=deposit(cmd.targetName)else ok,moved,msg=false,0,'Unsupported remote command'end;common.web('terminal_result',{warehouseId=cfg.warehouseId,terminalId=cfg.terminalId,token=cfg.token,requestId=cmd.requestId,action=cmd.action,ok=ok,moved=moved,message=msg,user=cmd.user})end
 sleep(1.5)
end]==],
  ['service.lua']=[==[local common=dofile('/spawnnet/apps/warehouse/warehouseos/app/common.lua')
local APP='/spawnnet/apps/warehouse/warehouseos/app/'
local haveController=common.load('controller.db',nil)~=nil;local haveTerminal=common.load('terminal.db',nil)~=nil
local function workers()
 local funcs={};if haveController then funcs[#funcs+1]=function()while true do local ok=os.run({},APP..'controller.lua','service');if not ok then sleep(2)else sleep(1)end end end end;if haveTerminal then funcs[#funcs+1]=function()while true do local ok=os.run({},APP..'terminal.lua','service');if not ok then sleep(2)else sleep(1)end end end end
 if #funcs==0 then while true do sleep(60)end elseif #funcs==1 then funcs[1]()else parallel.waitForAll(unpack(funcs))end
end
local function foreground()
 local user=common.dataPath('startup.user.lua');if fs.exists(user)then pcall(os.run,{},user)end
 while true do os.run({},'rom/programs/shell.lua')end
end
parallel.waitForAny(workers,foreground)]==]
}
print('Publishing WarehouseOS 2 website...')
local current=net.call('web','getSite',{domain=DOMAIN})
if current and current.site and current.site.draft and current.site.draft.pages then for path in pairs(current.site.draft.pages)do if not pages[path]then net.call('web','deletePage',{domain=DOMAIN,path=path})end end end
local order={};for path in pairs(pages)do order[#order+1]=path end;table.sort(order)
for _,path in ipairs(order)do local x,e=net.call('web','savePage',{domain=DOMAIN,path=path,page=pages[path]});if not x then error('savePage '..path..': '..tostring(e),0)end end
call('web','saveScripts',{domain=DOMAIN,clientScript=clientScript,serverScript=serverScript})
call('web','settings',{domain=DOMAIN,title='WarehouseOS',description='ME-style networked storage powered by SpawnNet Core + physical ComputerCraft inventory nodes.',tags={'warehouse','storage','inventory','me','app'}})
call('web','publish',{domain=DOMAIN,note='WarehouseOS 2.0.0 - core-hosted backend + native app install'})
print('Publishing installable WarehouseOS package...')
call('package','publish',{domain=DOMAIN,name='warehouseos',title='WarehouseOS',version='2.0.0',description='Physical warehouse controller + remote terminal software. Backend data and commands are hosted by SpawnNet Core; no dedicated WarehouseOS Host computer.',permissions={'filesystem','peripheral','modem','rednet','shell','startup'},entry='setup.lua',service='service.lua',runAfterInstall=true,files=appFiles})
term.setTextColor(colors.lime);print('WAREHOUSEOS 2.0.0 PUBLISHED');term.setTextColor(colors.white)
print('Open: spn://warehouse')
print('The website can now install WarehouseOS through SpawnNet native confirmation.')
print('No warehouse-host computer is used in this edition.')
