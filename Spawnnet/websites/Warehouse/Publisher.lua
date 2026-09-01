-- WarehouseOS 1.1.0 SpawnNet Publisher
local net=dofile('/spawnnet/client/net.lua')
local auth=dofile('/spawnnet/client/auth_client.lua')
local util=dofile('/spawnnet/lib/util.lua')
local C=colors
local DOMAIN='warehouse'
local function die(s)term.setTextColor(C.red);print('ERROR: '..tostring(s));term.setTextColor(C.white);error(s,0)end
local function call(service,action,payload,opts)local p,e=net.call(service,action,payload or{},opts);if not p then die(service..'.'..action..': '..tostring(e))end;return p end
if not net.loadSession()then local s,e=auth.ensureLogin();if not s then die(e)end end
local existing=net.call('dns','resolve',{domain=DOMAIN},{noAuth=true})
if not existing then call('dns','register',{domain=DOMAIN,title='WarehouseOS'})else local me=call('users','me',{});local user=me.account and me.account.username or(net.loadSession()and net.loadSession().user);if existing.owner~=user then die('spn://'..DOMAIN..' belongs to '..tostring(existing.owner)..', not '..tostring(user))end end

local function add(p,e)p.elements[#p.elements+1]=e;return e end
local function base(title,subtitle,mode,width)
  width=width or 45
  local p={title=title,background=C.black,elements={},liveInterval=1,liveServerEvent='poll_job'}
  add(p,{type='input',id='pageMode',x=1,y=1,w=1,value=mode or'',visible=false})
  add(p,{type='input',id='jobId',x=1,y=1,w=1,value='',visible=false})
  add(p,{type='panel',x=1,y=1,w='100%',h=4,bg=C.gray,children={
    {type='heading',x=2,y=1,w=width,h=1,text='WAREHOUSEOS',fg=C.lime,bg=C.gray,align='center'},
    {type='text',x=2,y=2,w=width,h=1,text=subtitle or'ME-style storage over SpawnNet',fg=C.lightGray,bg=C.gray,align='center'}
  }})
  return p
end
local function nav(p,y,w)
  add(p,{type='button',x=3,y=y,w=10,text='HOME',bg=C.gray,action={type='navigate',target='spn://warehouse/'}})
  add(p,{type='button',x=14,y=y,w=12,text='MY STORAGE',bg=C.blue,action={type='navigate',target='spn://warehouse/my'}})
  add(p,{type='button',x=27,y=y,w=10,text='POCKET',bg=C.purple,action={type='navigate',target='spn://warehouse/pocket'}})
  add(p,{type='button',x=38,y=y,w=11,text='HELP',bg=C.gray,action={type='navigate',target='spn://warehouse/help'}})
end
local function hidden(p,id,value)add(p,{type='input',id=id,x=1,y=1,w=1,value=value or'',visible=false})end

local pages={}
-- Home
local p=base('WarehouseOS','Hosted virtual warehouses for SpawnNet','home');p.liveServerEvent='home_refresh'
nav(p,5)
add(p,{type='badge',id='hostState',x=3,y=8,w=45,text='HOST: CHECKING...',bg=C.orange,fg=C.black,align='center'})
add(p,{type='text',id='hostStats',x=3,y=10,w=45,h=2,text='Connecting to the WarehouseOS host...',fg=C.lightGray})
add(p,{type='heading',x=3,y=13,w=45,text='ONE STORAGE NETWORK. EVERY CHEST.',fg=C.yellow})
add(p,{type='text',x=3,y=15,w=45,h=5,text='WarehouseOS turns a wired network of ComputerCraft-visible inventories into one searchable virtual warehouse. Use the website from a computer or pocket computer, search by item/mod/amount, withdraw to an output terminal, auto-deposit, share access, and audit every movement.'})
add(p,{type='button',x=3,y=21,w=22,text='REGISTER PROFILE',bg=C.lime,fg=C.black,action={type='server',event='profile_register'}})
add(p,{type='button',x=27,y=21,w=22,text='CREATE WAREHOUSE',bg=C.purple,action={type='navigate',target='spn://warehouse/create'}})
add(p,{type='button',x=3,y=23,w=46,text='OPEN MY WAREHOUSES',bg=C.blue,action={type='navigate',target='spn://warehouse/my'}})
add(p,{type='text',id='profileStatus',x=3,y=26,w=45,h=2,text='WarehouseOS uses your existing SpawnNet identity. No second password.'})
add(p,{type='heading',x=3,y=30,w=45,text='OPEN A WAREHOUSE DIRECTLY',fg=C.yellow})
add(p,{type='input',id='openId',x=3,y=32,w=32,placeholder='Warehouse ID, e.g. highland-a1b2'})
add(p,{type='button',x=36,y=32,w=13,text='OPEN',bg=C.cyan,fg=C.black,action={type='event',event='open_manual'}})
pages['/']=p

-- Create
p=base('Create Warehouse','Create the virtual warehouse, then pair the physical controller','create');nav(p,5)
add(p,{type='heading',x=3,y=9,w=45,text='CREATE A NEW WAREHOUSE',fg=C.yellow})
add(p,{type='text',x=3,y=11,w=45,h=3,text='Give the warehouse a name. WarehouseOS will create a private warehouse ID and one-time controller pairing code.'})
add(p,{type='input',id='warehouseName',x=3,y=15,w=45,placeholder='Highland Storage'})
add(p,{type='button',x=3,y=18,w=45,text='CREATE WAREHOUSE',bg=C.lime,fg=C.black,action={type='server',event='create_submit'}})
add(p,{type='badge',id='createStatus',x=3,y=21,w=45,text='READY',bg=C.gray,fg=C.white,align='center'})
add(p,{type='text',id='createId',x=3,y=24,w=45,h=2,text='Warehouse ID: -'})
add(p,{type='text',id='createPair',x=3,y=27,w=45,h=2,text='Controller pair code: -'})
add(p,{type='text',x=3,y=31,w=45,h=4,text='Next: install WarehouseOS on the computer connected to your wired inventory network, run warehouse-controller, enter the pair code, then choose the main output and optional deposit inventory.'})
pages['/create']=p

-- My warehouses
p=base('My Warehouses','Warehouses you own or have been granted access to','my');nav(p,5);hidden(p,'listPage','1')
add(p,{type='heading',x=3,y=9,w=45,text='MY WAREHOUSES',fg=C.yellow})
add(p,{type='text',id='whPageText',x=3,y=11,w=45,h=1,text='Loading...'})
for i=1,8 do hidden(p,'wid'..i,'');hidden(p,'wname'..i,'');add(p,{type='button',id='wh'..i,x=3,y=12+i*2,w=45,text='-',bg=i%2==0 and C.gray or C.blue,visible=false,action={type='event',event='open_wh'..i}})end
add(p,{type='button',x=3,y=30,w=22,text='< PREVIOUS',bg=C.gray,action={type='event',event='list_prev'}})
add(p,{type='button',x=27,y=30,w=22,text='NEXT >',bg=C.gray,action={type='event',event='list_next'}})
add(p,{type='heading',x=3,y=34,w=45,text='DIRECT ACCESS',fg=C.yellow})
add(p,{type='input',id='openId',x=3,y=36,w=32,placeholder='Warehouse ID'})
add(p,{type='button',x=36,y=36,w=13,text='OPEN',bg=C.cyan,fg=C.black,action={type='event',event='open_manual'}})
pages['/my']=p

local function terminalPage(pocket)
  local width=pocket and 29 or 45;local x=3
  local qWidth=pocket and 20 or 24
  local pg=base(pocket and'WarehouseOS Pocket'or'Warehouse Terminal',pocket and'Compact handheld access'or'Search, filter, withdraw and deposit','terminal',width)
  hidden(pg,'warehouseId','');hidden(pg,'selectedItem','');hidden(pg,'selectedName','');hidden(pg,'searchPage','1');hidden(pg,'searchSort','amount')
  for i=1,8 do hidden(pg,'item'..i,'');hidden(pg,'itemName'..i,'');hidden(pg,'itemAmount'..i,'');hidden(pg,'itemRaw'..i,'');hidden(pg,'itemOriginal'..i,'');hidden(pg,'itemMeta'..i,'0');hidden(pg,'itemCustom'..i,'')end
  hidden(pg,'selectedRaw','');hidden(pg,'selectedOriginal','');hidden(pg,'selectedMeta','0')
  if not pocket then nav(pg,5) end
  local y=pocket and 5 or 9
  add(pg,{type='badge',id='warehouseTitle',x=x,y=y,w=width,text='NO WAREHOUSE SELECTED',bg=C.blue,fg=C.white,align='center'});y=y+2
  add(pg,{type='text',id='warehouseSummary',x=x,y=y,w=width,h=2,text='Loading warehouse status...'});y=y+3
  add(pg,{type='input',id='query',x=x,y=y,w=qWidth,placeholder='Search items...'});add(pg,{type='input',id='modFilter',x=x+qWidth+1,y=y,w=pocket and 8 or 12,placeholder='mod'});if not pocket then add(pg,{type='input',id='minAmount',x=41,y=y,w=8,value='0',placeholder='min'})else hidden(pg,'minAmount','0')end;y=y+2
  if not pocket then
    add(pg,{type='button',x=x,y=y,w=14,text='SORT: AMOUNT',bg=C.gray,action={type='event',event='sort_amount'}});add(pg,{type='button',x=18,y=y,w=14,text='SORT: NAME',bg=C.gray,action={type='event',event='sort_name'}});add(pg,{type='button',x=33,y=y,w=16,text='SORT: MOD',bg=C.gray,action={type='event',event='sort_mod'}});y=y+2
  end
  add(pg,{type='button',x=x,y=y,w=width,text='SEARCH INVENTORY',bg=C.lime,fg=C.black,action={type='server',event='search_submit'}});y=y+2
  add(pg,{type='text',id='searchStatus',x=x,y=y,w=width,h=1,text='Search results will appear below.'});y=y+2
  local count=pocket and 6 or 8
  for i=1,count do add(pg,{type='button',id='itemBtn'..i,x=x,y=y,w=width,text='-',bg=i%2==0 and C.black or C.gray,visible=false,action={type='event',event='pick_item'..i}});y=y+2 end
  add(pg,{type='button',x=x,y=y,w=math.floor((width-1)/2),text='< PAGE',bg=C.gray,action={type='event',event='search_prev'}});add(pg,{type='button',x=x+math.floor((width-1)/2)+1,y=y,w=width-math.floor((width-1)/2)-1,text='PAGE >',bg=C.gray,action={type='event',event='search_next'}});y=y+3
  add(pg,{type='badge',id='selectedText',x=x,y=y,w=width,text='SELECT AN ITEM',bg=C.orange,fg=C.black,align='center'});y=y+2
  if not pocket then
    add(pg,{type='text',id='selectedDetails',x=x,y=y,w=width,h=2,text='Original item name / registry ID / metadata will appear here.',fg=C.lightGray});y=y+3
    add(pg,{type='input',id='aliasName',x=x,y=y,w=width,placeholder='Custom display name (owner/admin)'});y=y+2
    add(pg,{type='button',x=x,y=y,w=22,text='SAVE DISPLAY NAME',bg=C.purple,action={type='server',event='alias_save'}});add(pg,{type='button',x=x+23,y=y,w=22,text='RESET NAME',bg=C.gray,action={type='server',event='alias_reset'}});y=y+3
  else hidden(pg,'aliasName','') end
  add(pg,{type='input',id='quantity',x=x,y=y,w=pocket and 12 or 15,value='64'});add(pg,{type='input',id='terminal',x=x+(pocket and 13 or 16),y=y,w=pocket and 16 or 29,value='main',placeholder='terminal id'});y=y+2
  add(pg,{type='button',x=x,y=y,w=width,text='WITHDRAW TO TERMINAL',bg=C.lime,fg=C.black,action={type='server',event='withdraw_submit'}});y=y+2
  add(pg,{type='button',x=x,y=y,w=width,text='DEPOSIT FROM TERMINAL',bg=C.cyan,fg=C.black,action={type='server',event='deposit_submit'}});y=y+2
  add(pg,{type='text',id='operationStatus',x=x,y=y,w=width,h=2,text='Terminal: main. Use Settings to pair remote terminals.'});y=y+3
  if not pocket then
    add(pg,{type='button',x=3,y=y,w=14,text='MEMBERS',bg=C.purple,action={type='navigate',target='spn://warehouse/members'}});add(pg,{type='button',x=18,y=y,w=14,text='HISTORY',bg=C.gray,action={type='navigate',target='spn://warehouse/history'}});add(pg,{type='button',x=33,y=y,w=16,text='SETTINGS',bg=C.gray,action={type='navigate',target='spn://warehouse/settings'}})
  else add(pg,{type='button',x=x,y=y,w=width,text='FULL TERMINAL',bg=C.gray,action={type='navigate',target='spn://warehouse/terminal'}})end
  return pg
end
pages['/terminal']=terminalPage(false);pages['/pocket']=terminalPage(true)

-- Members
p=base('Warehouse Members','Share a warehouse with other SpawnNet accounts','members');nav(p,5);hidden(p,'warehouseId','');hidden(p,'removeUser','');for i=1,8 do hidden(p,'memberUser'..i,'')end
add(p,{type='badge',id='warehouseTitle',x=3,y=9,w=45,text='WAREHOUSE',bg=C.purple,align='center'})
add(p,{type='heading',x=3,y=12,w=45,text='ADD / UPDATE MEMBER',fg=C.yellow})
add(p,{type='input',id='memberName',x=3,y=14,w=27,placeholder='SpawnNet username'});add(p,{type='input',id='memberRole',x=31,y=14,w=18,value='viewer',placeholder='role'})
add(p,{type='text',x=3,y=16,w=45,h=2,text='Roles: admin, operator, withdrawer, depositor, viewer'})
add(p,{type='button',x=3,y=19,w=45,text='GRANT ACCESS',bg=C.lime,fg=C.black,action={type='server',event='invite_submit'}})
add(p,{type='text',id='memberStatus',x=3,y=21,w=45,h=2,text='Loading members...'})
for i=1,8 do add(p,{type='button',id='member'..i,x=3,y=23+i*2,w=45,text='-',bg=i%2==0 and C.black or C.gray,visible=false,action={type='event',event='pick_member'..i}})end
add(p,{type='button',x=3,y=41,w=45,text='REMOVE SELECTED MEMBER',bg=C.red,action={type='server',event='remove_member_submit'}})
pages['/members']=p

-- History
p=base('Warehouse History','Auditable item movement','history');nav(p,5);hidden(p,'warehouseId','')
add(p,{type='badge',id='warehouseTitle',x=3,y=9,w=45,text='WAREHOUSE',bg=C.gray,align='center'})
add(p,{type='text',id='historyStatus',x=3,y=12,w=45,h=1,text='Loading recent activity...'})
for i=1,8 do add(p,{type='text',id='history'..i,x=3,y=13+i*3,w=45,h=2,text='-',fg=i%2==0 and C.lightGray or C.white})end
add(p,{type='button',x=3,y=39,w=45,text='REFRESH HISTORY',bg=C.gray,action={type='server',event='history_submit'}})
pages['/history']=p

-- Settings / pairing
p=base('Warehouse Settings','Controller and remote terminal pairing','settings');nav(p,5);hidden(p,'warehouseId','')
add(p,{type='badge',id='warehouseTitle',x=3,y=9,w=45,text='WAREHOUSE',bg=C.gray,align='center'})
add(p,{type='text',id='settingsSummary',x=3,y=12,w=45,h=4,text='Loading controller and terminal status...'})
add(p,{type='text',x=3,y=15,w=45,h=2,text='Custom item display names are edited from the Warehouse Terminal after selecting an item.',fg=C.lightGray})
add(p,{type='heading',x=3,y=17,w=45,text='PHYSICAL CONTROLLER',fg=C.yellow})
add(p,{type='button',x=3,y=19,w=45,text='GENERATE CONTROLLER PAIR CODE',bg=C.orange,fg=C.black,action={type='server',event='controller_code_submit'}})
add(p,{type='text',id='controllerPair',x=3,y=21,w=45,h=2,text='Controller pair code: -'})
add(p,{type='heading',x=3,y=25,w=45,text='WIRELESS REMOTE TERMINAL',fg=C.yellow})
add(p,{type='button',x=3,y=27,w=45,text='GENERATE REMOTE TERMINAL PAIR CODE',bg=C.cyan,fg=C.black,action={type='server',event='terminal_code_submit'}})
add(p,{type='text',id='terminalPair',x=3,y=29,w=45,h=2,text='Remote terminal pair code: -'})
add(p,{type='text',id='terminal1',x=3,y=33,w=45,h=1,text='Terminal 1: -'});add(p,{type='text',id='terminal2',x=3,y=35,w=45,h=1,text='Terminal 2: -'});add(p,{type='text',id='terminal3',x=3,y=37,w=45,h=1,text='Terminal 3: -'});add(p,{type='text',id='terminal4',x=3,y=39,w=45,h=1,text='Terminal 4: -'})
pages['/settings']=p

-- Help
p=base('WarehouseOS Help','Setup in minutes, then use it like a networked ME terminal','help');nav(p,5)
add(p,{type='heading',x=3,y=9,w=45,text='1. CENTRAL HOST - ADMIN SETUP ONCE',fg=C.yellow})
add(p,{type='text',x=3,y=11,w=45,h=4,text='On one always-loaded spawn computer, install WarehouseOS and run warehouse-host. The first launch signs into the account which owns spn://warehouse and creates a tightly-scoped Host API key automatically.'})
add(p,{type='heading',x=3,y=17,w=45,text='2. CREATE YOUR WAREHOUSE',fg=C.yellow})
add(p,{type='text',x=3,y=19,w=45,h=3,text='Register a WarehouseOS profile, create a warehouse here, and copy the one-time controller pair code.'})
add(p,{type='heading',x=3,y=24,w=45,text='3. WIRE THE INVENTORIES',fg=C.yellow})
add(p,{type='text',x=3,y=26,w=45,h=5,text='Connect the warehouse computer to a wired modem/cable network containing your chests, crates, barrels or any peripheral which answers list(). Add a wireless modem for the Host control link. Run warehouse-controller, enter the pair code, choose Main Output and optional Main Deposit. Every other detected inventory becomes storage automatically. WarehouseOS then continues in the background, so you can use this same computer as a SpawnNet terminal.'})
add(p,{type='heading',x=3,y=33,w=45,text='4. USE IT',fg=C.yellow})
add(p,{type='text',x=3,y=35,w=45,h=5,text='Open My Warehouses, choose one, search/filter, click an item, choose a quantity and withdraw. Put items in Main Deposit and press Deposit or leave auto-deposit enabled. Pocket Mode gives the same search/withdraw controls in a compact layout.'})
add(p,{type='heading',x=3,y=42,w=45,text='CUSTOM ITEM NAMES',fg=C.yellow})
add(p,{type='text',x=3,y=44,w=45,h=4,text='If a mod reports useless names such as ProjectRed Component, select that exact item variant in the terminal and set a custom display name. WarehouseOS keeps the real registry ID + metadata internally so withdrawals still target the correct item.'})
add(p,{type='heading',x=3,y=49,w=45,text='REMOTE TERMINALS',fg=C.yellow})
add(p,{type='text',x=3,y=51,w=45,h=6,text='Owners/admins can generate a remote-terminal pair code in Settings. Run warehouse-terminal on another computer with a wireless modem and local chest. WarehouseOS will attempt direct inventory-name transfer across the two computers. If your TekkitSMP peripheral layer exposes those remote inventory names globally, withdrawal/deposit works wirelessly; otherwise the terminal remains a control endpoint and reports that no physical item path exists rather than faking movement.'})
pages['/help']=p

local clientScript=[=[
event load
  call input.get "pageMode" -> mode
  if $mode == "my"
    call server.run "list_warehouses"
  endif
  if $mode == "terminal"
    call local.get "warehouse.selected" -> wid
    call local.get "warehouse.name" -> name
    if $wid == nil
      call ui.alert "Choose a warehouse from My Warehouses first."
      call ui.navigate "spn://warehouse/my"
    else
      call ui.setValue "warehouseId" $wid
      call ui.setText "warehouseTitle" $name
      call server.run "summary_submit"
    endif
  endif
  if $mode == "members"
    call local.get "warehouse.selected" -> wid
    call local.get "warehouse.name" -> name
    call ui.setValue "warehouseId" $wid
    call ui.setText "warehouseTitle" $name
    call server.run "members_submit"
  endif
  if $mode == "history"
    call local.get "warehouse.selected" -> wid
    call local.get "warehouse.name" -> name
    call ui.setValue "warehouseId" $wid
    call ui.setText "warehouseTitle" $name
    call server.run "history_submit"
  endif
  if $mode == "settings"
    call local.get "warehouse.selected" -> wid
    call local.get "warehouse.name" -> name
    call ui.setValue "warehouseId" $wid
    call ui.setText "warehouseTitle" $name
    call server.run "summary_submit"
  endif
end

event open_manual
  call input.get "openId" -> wid
  if $wid == ""
    call ui.alert "Enter a Warehouse ID first."
  else
    call local.set "warehouse.selected" $wid
    call local.set "warehouse.name" $wid
    call ui.navigate "spn://warehouse/terminal"
  endif
end

event list_prev
  call input.get "listPage" -> p
  math p $p - 1
  if $p < 1
    set p 1
  endif
  call ui.setValue "listPage" $p
  call server.run "list_warehouses"
end

event list_next
  call input.get "listPage" -> p
  math p $p + 1
  call ui.setValue "listPage" $p
  call server.run "list_warehouses"
end

event sort_amount
  call ui.setValue "searchSort" "amount"
  call ui.setValue "searchPage" 1
  call server.run "search_submit"
end

event sort_name
  call ui.setValue "searchSort" "name"
  call ui.setValue "searchPage" 1
  call server.run "search_submit"
end

event sort_mod
  call ui.setValue "searchSort" "mod"
  call ui.setValue "searchPage" 1
  call server.run "search_submit"
end

event search_prev
  call input.get "searchPage" -> p
  math p $p - 1
  if $p < 1
    set p 1
  endif
  call ui.setValue "searchPage" $p
  call server.run "search_submit"
end

event search_next
  call input.get "searchPage" -> p
  math p $p + 1
  call ui.setValue "searchPage" $p
  call server.run "search_submit"
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
  call input.get "item1" -> id
  call input.get "itemName1" -> name
  call input.get "itemRaw1" -> raw
  call input.get "itemOriginal1" -> original
  call input.get "itemMeta1" -> meta
  call input.get "itemCustom1" -> custom
  call ui.setValue "selectedItem" $id
  call ui.setValue "selectedName" $name
  call ui.setValue "selectedRaw" $raw
  call ui.setValue "selectedOriginal" $original
  call ui.setValue "selectedMeta" $meta
  call ui.setValue "aliasName" $custom
  call ui.setText "selectedText" $name
  concat info "Original: " $original " | " $raw " | meta " $meta
  call ui.setText "selectedDetails" $info
end
event pick_item2
  call input.get "item2" -> id
  call input.get "itemName2" -> name
  call input.get "itemRaw2" -> raw
  call input.get "itemOriginal2" -> original
  call input.get "itemMeta2" -> meta
  call input.get "itemCustom2" -> custom
  call ui.setValue "selectedItem" $id
  call ui.setValue "selectedName" $name
  call ui.setValue "selectedRaw" $raw
  call ui.setValue "selectedOriginal" $original
  call ui.setValue "selectedMeta" $meta
  call ui.setValue "aliasName" $custom
  call ui.setText "selectedText" $name
  concat info "Original: " $original " | " $raw " | meta " $meta
  call ui.setText "selectedDetails" $info
end
event pick_item3
  call input.get "item3" -> id
  call input.get "itemName3" -> name
  call input.get "itemRaw3" -> raw
  call input.get "itemOriginal3" -> original
  call input.get "itemMeta3" -> meta
  call input.get "itemCustom3" -> custom
  call ui.setValue "selectedItem" $id
  call ui.setValue "selectedName" $name
  call ui.setValue "selectedRaw" $raw
  call ui.setValue "selectedOriginal" $original
  call ui.setValue "selectedMeta" $meta
  call ui.setValue "aliasName" $custom
  call ui.setText "selectedText" $name
  concat info "Original: " $original " | " $raw " | meta " $meta
  call ui.setText "selectedDetails" $info
end
event pick_item4
  call input.get "item4" -> id
  call input.get "itemName4" -> name
  call input.get "itemRaw4" -> raw
  call input.get "itemOriginal4" -> original
  call input.get "itemMeta4" -> meta
  call input.get "itemCustom4" -> custom
  call ui.setValue "selectedItem" $id
  call ui.setValue "selectedName" $name
  call ui.setValue "selectedRaw" $raw
  call ui.setValue "selectedOriginal" $original
  call ui.setValue "selectedMeta" $meta
  call ui.setValue "aliasName" $custom
  call ui.setText "selectedText" $name
  concat info "Original: " $original " | " $raw " | meta " $meta
  call ui.setText "selectedDetails" $info
end
event pick_item5
  call input.get "item5" -> id
  call input.get "itemName5" -> name
  call input.get "itemRaw5" -> raw
  call input.get "itemOriginal5" -> original
  call input.get "itemMeta5" -> meta
  call input.get "itemCustom5" -> custom
  call ui.setValue "selectedItem" $id
  call ui.setValue "selectedName" $name
  call ui.setValue "selectedRaw" $raw
  call ui.setValue "selectedOriginal" $original
  call ui.setValue "selectedMeta" $meta
  call ui.setValue "aliasName" $custom
  call ui.setText "selectedText" $name
  concat info "Original: " $original " | " $raw " | meta " $meta
  call ui.setText "selectedDetails" $info
end
event pick_item6
  call input.get "item6" -> id
  call input.get "itemName6" -> name
  call input.get "itemRaw6" -> raw
  call input.get "itemOriginal6" -> original
  call input.get "itemMeta6" -> meta
  call input.get "itemCustom6" -> custom
  call ui.setValue "selectedItem" $id
  call ui.setValue "selectedName" $name
  call ui.setValue "selectedRaw" $raw
  call ui.setValue "selectedOriginal" $original
  call ui.setValue "selectedMeta" $meta
  call ui.setValue "aliasName" $custom
  call ui.setText "selectedText" $name
  concat info "Original: " $original " | " $raw " | meta " $meta
  call ui.setText "selectedDetails" $info
end
event pick_item7
  call input.get "item7" -> id
  call input.get "itemName7" -> name
  call input.get "itemRaw7" -> raw
  call input.get "itemOriginal7" -> original
  call input.get "itemMeta7" -> meta
  call input.get "itemCustom7" -> custom
  call ui.setValue "selectedItem" $id
  call ui.setValue "selectedName" $name
  call ui.setValue "selectedRaw" $raw
  call ui.setValue "selectedOriginal" $original
  call ui.setValue "selectedMeta" $meta
  call ui.setValue "aliasName" $custom
  call ui.setText "selectedText" $name
  concat info "Original: " $original " | " $raw " | meta " $meta
  call ui.setText "selectedDetails" $info
end
event pick_item8
  call input.get "item8" -> id
  call input.get "itemName8" -> name
  call input.get "itemRaw8" -> raw
  call input.get "itemOriginal8" -> original
  call input.get "itemMeta8" -> meta
  call input.get "itemCustom8" -> custom
  call ui.setValue "selectedItem" $id
  call ui.setValue "selectedName" $name
  call ui.setValue "selectedRaw" $raw
  call ui.setValue "selectedOriginal" $original
  call ui.setValue "selectedMeta" $meta
  call ui.setValue "aliasName" $custom
  call ui.setText "selectedText" $name
  concat info "Original: " $original " | " $raw " | meta " $meta
  call ui.setText "selectedDetails" $info
end

event pick_member1
  call input.get "memberUser1" -> u
  call ui.setValue "removeUser" $u
  call ui.setText "memberStatus" "Selected: ${u}"
end
event pick_member2
  call input.get "memberUser2" -> u
  call ui.setValue "removeUser" $u
  call ui.setText "memberStatus" "Selected: ${u}"
end
event pick_member3
  call input.get "memberUser3" -> u
  call ui.setValue "removeUser" $u
  call ui.setText "memberStatus" "Selected: ${u}"
end
event pick_member4
  call input.get "memberUser4" -> u
  call ui.setValue "removeUser" $u
  call ui.setText "memberStatus" "Selected: ${u}"
end
event pick_member5
  call input.get "memberUser5" -> u
  call ui.setValue "removeUser" $u
  call ui.setText "memberStatus" "Selected: ${u}"
end
event pick_member6
  call input.get "memberUser6" -> u
  call ui.setValue "removeUser" $u
  call ui.setText "memberStatus" "Selected: ${u}"
end
event pick_member7
  call input.get "memberUser7" -> u
  call ui.setValue "removeUser" $u
  call ui.setText "memberStatus" "Selected: ${u}"
end
event pick_member8
  call input.get "memberUser8" -> u
  call ui.setValue "removeUser" $u
  call ui.setText "memberStatus" "Selected: ${u}"
end
]=]

local serverScript=[=[
event home_refresh
  call telemetry.last "host" -> h
  if $h == nil
    call ui.setText "hostState" "HOST OFFLINE"
    call ui.setText "hostStats" "The WarehouseOS Host is not publishing telemetry. Existing physical controllers may still be online, but website requests will queue until the Host returns."
  else
    call ui.setText "hostState" "HOST ONLINE - COMPUTER #${h._computer}"
    call ui.setText "hostStats" "Warehouses: ${h.warehouses} | Controllers online: ${h.controllers} | Indexed items: ${h.totalItems}"
  endif
  if $input.jobId != ""
    call jobs.status $input.jobId -> j
    if $j != nil
      if $j.status == "failed"
        call ui.setText "profileStatus" "FAILED: ${j.error}"
        call ui.setValue "jobId" ""
      endif
      if $j.status == "completed"
        call ui.setText "profileStatus" "WarehouseOS profile ready for ${j.result.user}."
        call ui.setValue "jobId" ""
      endif
    endif
  endif
end

event profile_register
  call user.name -> who
  if $who == nil
    call ui.alert "Sign in to SpawnNet first."
  else
    call jobs.submit "host" "profile_register" "register" 0 "" -> jid
    call ui.setValue "jobId" $jid
    call ui.setText "profileStatus" "Registering WarehouseOS profile..."
  endif
end

event create_submit
  call user.name -> who
  if $who == nil
    call ui.alert "Sign in first."
  else
    call jobs.submit "host" "create" $input.warehouseName 0 "" -> jid
    call ui.setValue "jobId" $jid
    call ui.setText "createStatus" "CREATING..."
  endif
end

event list_warehouses
  call jobs.submit "host" "list" $input.listPage 0 "" -> jid
  call ui.setValue "jobId" $jid
  call ui.setText "whPageText" "Loading warehouses..."
end

event summary_submit
  call jobs.submit "host" "summary" $input.warehouseId 0 "" -> jid
  call ui.setValue "jobId" $jid
end

event search_submit
  concat req $input.warehouseId "|" $input.query "|" $input.modFilter "|" $input.minAmount "|" $input.searchSort "|" $input.searchPage
  call jobs.submit "host" "search" $req 0 "" -> jid
  call ui.setValue "jobId" $jid
  call ui.setText "searchStatus" "Searching indexed inventories..."
end

event alias_save
  if $input.selectedItem == ""
    call ui.alert "Select an item first."
  else
    concat req $input.warehouseId "|" $input.selectedItem
    call jobs.submit "host" "alias_set" $req 0 $input.aliasName -> jid
    call ui.setValue "jobId" $jid
    call ui.setText "operationStatus" "Saving custom display name..."
  endif
end

event alias_reset
  if $input.selectedItem == ""
    call ui.alert "Select an item first."
  else
    concat req $input.warehouseId "|" $input.selectedItem
    call jobs.submit "host" "alias_set" $req 0 "" -> jid
    call ui.setValue "jobId" $jid
    call ui.setText "operationStatus" "Resetting display name..."
  endif
end

event withdraw_submit
  if $input.selectedItem == ""
    call ui.alert "Select an item first."
  else
    concat req $input.warehouseId "|" $input.selectedItem "|" $input.terminal
    call jobs.submit "host" "withdraw" $req $input.quantity "" -> jid
    call ui.setValue "jobId" $jid
    call ui.setText "operationStatus" "Withdrawal queued..."
  endif
end

event deposit_submit
  concat req $input.warehouseId "|deposit|" $input.terminal
  call jobs.submit "host" "deposit" $req 1 "" -> jid
  call ui.setValue "jobId" $jid
  call ui.setText "operationStatus" "Deposit sweep queued..."
end

event invite_submit
  concat req $input.warehouseId "|" $input.memberName "|" $input.memberRole
  call jobs.submit "host" "invite" $req 0 "" -> jid
  call ui.setValue "jobId" $jid
  call ui.setText "memberStatus" "Granting access..."
end

event members_submit
  call jobs.submit "host" "members" $input.warehouseId 0 "" -> jid
  call ui.setValue "jobId" $jid
end

event remove_member_submit
  concat req $input.warehouseId "|" $input.removeUser
  call jobs.submit "host" "remove_member" $req 0 "" -> jid
  call ui.setValue "jobId" $jid
end

event history_submit
  call jobs.submit "host" "history" $input.warehouseId 0 "" -> jid
  call ui.setValue "jobId" $jid
end

event terminal_code_submit
  call jobs.submit "host" "terminal_code" $input.warehouseId 0 "" -> jid
  call ui.setValue "jobId" $jid
end

event controller_code_submit
  call jobs.submit "host" "controller_code" $input.warehouseId 0 "" -> jid
  call ui.setValue "jobId" $jid
end

event poll_job
  if $input.jobId != ""
    call jobs.status $input.jobId -> j
    if $j != nil
      if $j.status == "failed"
        call ui.setText "operationStatus" "FAILED: ${j.error}"
        call ui.setText "createStatus" "FAILED: ${j.error}"
        call ui.setText "memberStatus" "FAILED: ${j.error}"
        call ui.setText "searchStatus" "FAILED: ${j.error}"
        call ui.setValue "jobId" ""
      endif
      if $j.status == "completed"
        if $j.action == "profile_register"
          call ui.setText "profileStatus" "WarehouseOS profile ready for ${j.result.user}."
        endif
        if $j.action == "create"
          call ui.setText "createStatus" "WAREHOUSE CREATED"
          call ui.setText "createId" "Warehouse ID: ${j.result.warehouseId}"
          call ui.setText "createPair" "Controller pair code: ${j.result.pairCode}"
        endif
        if $j.action == "list"
          call ui.setText "whPageText" "Warehouses: ${j.result.count} | Page ${j.result.page}/${j.result.pages}"
          call ui.setVisible "wh1" false
          call ui.setVisible "wh2" false
          call ui.setVisible "wh3" false
          call ui.setVisible "wh4" false
          call ui.setVisible "wh5" false
          call ui.setVisible "wh6" false
          call ui.setVisible "wh7" false
          call ui.setVisible "wh8" false
          if $j.result.id1 != nil
            call ui.setValue "wid1" $j.result.id1
            call ui.setValue "wname1" $j.result.name1
            call ui.setText "wh1" $j.result.label1
            call ui.setVisible "wh1" true
          endif
          if $j.result.id2 != nil
            call ui.setValue "wid2" $j.result.id2
            call ui.setValue "wname2" $j.result.name2
            call ui.setText "wh2" $j.result.label2
            call ui.setVisible "wh2" true
          endif
          if $j.result.id3 != nil
            call ui.setValue "wid3" $j.result.id3
            call ui.setValue "wname3" $j.result.name3
            call ui.setText "wh3" $j.result.label3
            call ui.setVisible "wh3" true
          endif
          if $j.result.id4 != nil
            call ui.setValue "wid4" $j.result.id4
            call ui.setValue "wname4" $j.result.name4
            call ui.setText "wh4" $j.result.label4
            call ui.setVisible "wh4" true
          endif
          if $j.result.id5 != nil
            call ui.setValue "wid5" $j.result.id5
            call ui.setValue "wname5" $j.result.name5
            call ui.setText "wh5" $j.result.label5
            call ui.setVisible "wh5" true
          endif
          if $j.result.id6 != nil
            call ui.setValue "wid6" $j.result.id6
            call ui.setValue "wname6" $j.result.name6
            call ui.setText "wh6" $j.result.label6
            call ui.setVisible "wh6" true
          endif
          if $j.result.id7 != nil
            call ui.setValue "wid7" $j.result.id7
            call ui.setValue "wname7" $j.result.name7
            call ui.setText "wh7" $j.result.label7
            call ui.setVisible "wh7" true
          endif
          if $j.result.id8 != nil
            call ui.setValue "wid8" $j.result.id8
            call ui.setValue "wname8" $j.result.name8
            call ui.setText "wh8" $j.result.label8
            call ui.setVisible "wh8" true
          endif
        endif
        if $j.action == "summary"
          call ui.setText "warehouseTitle" "${j.result.name} [${j.result.role}]"
          call ui.setText "warehouseSummary" "${j.result.total} items | ${j.result.types} item types | ${j.result.inventories} storage inventories | Controller ${j.result.online}"
          call ui.setText "settingsSummary" "Role: ${j.result.role} | Controller online: ${j.result.online} | Storage inventories: ${j.result.inventories} | Output: ${j.result.output} | Deposit: ${j.result.deposit}"
          call ui.setText "terminal1" "Terminal 1: ${j.result.terminal1}"
          call ui.setText "terminal2" "Terminal 2: ${j.result.terminal2}"
          call ui.setText "terminal3" "Terminal 3: ${j.result.terminal3}"
          call ui.setText "terminal4" "Terminal 4: ${j.result.terminal4}"
        endif
        if $j.action == "search"
          call ui.setText "searchStatus" "Matches: ${j.result.count} | Page ${j.result.page}/${j.result.pages}"
          call ui.setValue "searchPage" $j.result.page
          call ui.setVisible "itemBtn1" false
          call ui.setVisible "itemBtn2" false
          call ui.setVisible "itemBtn3" false
          call ui.setVisible "itemBtn4" false
          call ui.setVisible "itemBtn5" false
          call ui.setVisible "itemBtn6" false
          call ui.setVisible "itemBtn7" false
          call ui.setVisible "itemBtn8" false
          if $j.result.id1 != nil
            call ui.setValue "item1" $j.result.id1
            call ui.setValue "itemName1" $j.result.name1
            call ui.setValue "itemAmount1" $j.result.amount1
            call ui.setValue "itemRaw1" $j.result.raw1
            call ui.setValue "itemOriginal1" $j.result.original1
            call ui.setValue "itemMeta1" $j.result.meta1
            call ui.setValue "itemCustom1" $j.result.custom1
            call ui.setText "itemBtn1" $j.result.label1
            call ui.setVisible "itemBtn1" true
          endif
          if $j.result.id2 != nil
            call ui.setValue "item2" $j.result.id2
            call ui.setValue "itemName2" $j.result.name2
            call ui.setValue "itemAmount2" $j.result.amount2
            call ui.setValue "itemRaw2" $j.result.raw2
            call ui.setValue "itemOriginal2" $j.result.original2
            call ui.setValue "itemMeta2" $j.result.meta2
            call ui.setValue "itemCustom2" $j.result.custom2
            call ui.setText "itemBtn2" $j.result.label2
            call ui.setVisible "itemBtn2" true
          endif
          if $j.result.id3 != nil
            call ui.setValue "item3" $j.result.id3
            call ui.setValue "itemName3" $j.result.name3
            call ui.setValue "itemAmount3" $j.result.amount3
            call ui.setValue "itemRaw3" $j.result.raw3
            call ui.setValue "itemOriginal3" $j.result.original3
            call ui.setValue "itemMeta3" $j.result.meta3
            call ui.setValue "itemCustom3" $j.result.custom3
            call ui.setText "itemBtn3" $j.result.label3
            call ui.setVisible "itemBtn3" true
          endif
          if $j.result.id4 != nil
            call ui.setValue "item4" $j.result.id4
            call ui.setValue "itemName4" $j.result.name4
            call ui.setValue "itemAmount4" $j.result.amount4
            call ui.setValue "itemRaw4" $j.result.raw4
            call ui.setValue "itemOriginal4" $j.result.original4
            call ui.setValue "itemMeta4" $j.result.meta4
            call ui.setValue "itemCustom4" $j.result.custom4
            call ui.setText "itemBtn4" $j.result.label4
            call ui.setVisible "itemBtn4" true
          endif
          if $j.result.id5 != nil
            call ui.setValue "item5" $j.result.id5
            call ui.setValue "itemName5" $j.result.name5
            call ui.setValue "itemAmount5" $j.result.amount5
            call ui.setValue "itemRaw5" $j.result.raw5
            call ui.setValue "itemOriginal5" $j.result.original5
            call ui.setValue "itemMeta5" $j.result.meta5
            call ui.setValue "itemCustom5" $j.result.custom5
            call ui.setText "itemBtn5" $j.result.label5
            call ui.setVisible "itemBtn5" true
          endif
          if $j.result.id6 != nil
            call ui.setValue "item6" $j.result.id6
            call ui.setValue "itemName6" $j.result.name6
            call ui.setValue "itemAmount6" $j.result.amount6
            call ui.setValue "itemRaw6" $j.result.raw6
            call ui.setValue "itemOriginal6" $j.result.original6
            call ui.setValue "itemMeta6" $j.result.meta6
            call ui.setValue "itemCustom6" $j.result.custom6
            call ui.setText "itemBtn6" $j.result.label6
            call ui.setVisible "itemBtn6" true
          endif
          if $j.result.id7 != nil
            call ui.setValue "item7" $j.result.id7
            call ui.setValue "itemName7" $j.result.name7
            call ui.setValue "itemAmount7" $j.result.amount7
            call ui.setValue "itemRaw7" $j.result.raw7
            call ui.setValue "itemOriginal7" $j.result.original7
            call ui.setValue "itemMeta7" $j.result.meta7
            call ui.setValue "itemCustom7" $j.result.custom7
            call ui.setText "itemBtn7" $j.result.label7
            call ui.setVisible "itemBtn7" true
          endif
          if $j.result.id8 != nil
            call ui.setValue "item8" $j.result.id8
            call ui.setValue "itemName8" $j.result.name8
            call ui.setValue "itemAmount8" $j.result.amount8
            call ui.setValue "itemRaw8" $j.result.raw8
            call ui.setValue "itemOriginal8" $j.result.original8
            call ui.setValue "itemMeta8" $j.result.meta8
            call ui.setValue "itemCustom8" $j.result.custom8
            call ui.setText "itemBtn8" $j.result.label8
            call ui.setVisible "itemBtn8" true
          endif
        endif
        if $j.action == "alias_set"
          call ui.setText "selectedText" $j.result.name
          call ui.setValue "selectedName" $j.result.name
          call ui.setText "operationStatus" "DISPLAY NAME UPDATED: ${j.result.name}"
        endif
        if $j.action == "withdraw"
          call ui.setText "operationStatus" "WITHDRAW COMPLETE: ${j.result.moved} ${j.result.name} -> ${j.result.terminal}"
        endif
        if $j.action == "deposit"
          call ui.setText "operationStatus" "DEPOSIT COMPLETE: ${j.result.moved} items from ${j.result.terminal}"
        endif
        if $j.action == "invite"
          call ui.setText "memberStatus" "Granted ${j.result.role} access to ${j.result.user}."
        endif
        if $j.action == "remove_member"
          call ui.setText "memberStatus" "Removed ${j.result.user}."
        endif
        if $j.action == "members"
          call ui.setText "memberStatus" "Members: ${j.result.count}"
          call ui.setVisible "member1" false
          call ui.setVisible "member2" false
          call ui.setVisible "member3" false
          call ui.setVisible "member4" false
          call ui.setVisible "member5" false
          call ui.setVisible "member6" false
          call ui.setVisible "member7" false
          call ui.setVisible "member8" false
          if $j.result.label1 != nil
            call ui.setText "member1" $j.result.label1
            call ui.setValue "memberUser1" $j.result.user1
            call ui.setVisible "member1" true
          endif
          if $j.result.label2 != nil
            call ui.setText "member2" $j.result.label2
            call ui.setValue "memberUser2" $j.result.user2
            call ui.setVisible "member2" true
          endif
          if $j.result.label3 != nil
            call ui.setText "member3" $j.result.label3
            call ui.setValue "memberUser3" $j.result.user3
            call ui.setVisible "member3" true
          endif
          if $j.result.label4 != nil
            call ui.setText "member4" $j.result.label4
            call ui.setValue "memberUser4" $j.result.user4
            call ui.setVisible "member4" true
          endif
          if $j.result.label5 != nil
            call ui.setText "member5" $j.result.label5
            call ui.setValue "memberUser5" $j.result.user5
            call ui.setVisible "member5" true
          endif
          if $j.result.label6 != nil
            call ui.setText "member6" $j.result.label6
            call ui.setValue "memberUser6" $j.result.user6
            call ui.setVisible "member6" true
          endif
          if $j.result.label7 != nil
            call ui.setText "member7" $j.result.label7
            call ui.setValue "memberUser7" $j.result.user7
            call ui.setVisible "member7" true
          endif
          if $j.result.label8 != nil
            call ui.setText "member8" $j.result.label8
            call ui.setValue "memberUser8" $j.result.user8
            call ui.setVisible "member8" true
          endif
        endif
        if $j.action == "history"
          call ui.setText "historyStatus" "Recent transactions: ${j.result.count}"
          call ui.setText "history1" $j.result.label1
          call ui.setText "history2" $j.result.label2
          call ui.setText "history3" $j.result.label3
          call ui.setText "history4" $j.result.label4
          call ui.setText "history5" $j.result.label5
          call ui.setText "history6" $j.result.label6
          call ui.setText "history7" $j.result.label7
          call ui.setText "history8" $j.result.label8
        endif
        if $j.action == "terminal_code"
          call ui.setText "terminalPair" "Remote terminal pair code: ${j.result.pairCode}"
        endif
        if $j.action == "controller_code"
          call ui.setText "controllerPair" "Controller pair code: ${j.result.pairCode}"
        endif
        call ui.setValue "jobId" ""
      endif
    endif
  endif
end
]=]

local existingSite=net.call('web','getSite',{domain=DOMAIN})
if existingSite and existingSite.site and existingSite.site.draft and existingSite.site.draft.pages then for path in pairs(existingSite.site.draft.pages)do if not pages[path]then net.call('web','deletePage',{domain=DOMAIN,path=path})end end end
local order={};for path in pairs(pages)do order[#order+1]=path end;table.sort(order)
term.clear();term.setCursorPos(1,1);term.setTextColor(C.lime);print('WAREHOUSEOS PUBLISHER 1.1.0');term.setTextColor(C.white)
for _,path in ipairs(order)do write(('Saving %-14s'):format(path));call('web','savePage',{domain=DOMAIN,path=path,page=pages[path]});print(' OK')end
write('Saving WarehouseOS scripts... ');call('web','saveScripts',{domain=DOMAIN,clientScript=clientScript,serverScript=serverScript});print('OK')
call('web','settings',{domain=DOMAIN,title='WarehouseOS',description='Hosted ME-style warehouses: search, filter, shared permissions, physical inventory controllers and pocket access.',tags={'warehouse','storage','inventory','me','computercraft','spawnnet'}})
write('Publishing... ');call('web','publish',{domain=DOMAIN,note='WarehouseOS 1.1.0 variant-safe aliases + background service UX'});print('OK')
print();term.setTextColor(C.lime);print('WAREHOUSEOS PUBLISHED');term.setTextColor(C.white);print('Open: spn://'..DOMAIN);print();print('Next, install WarehouseOS on an always-loaded computer and run:');print('  warehouse-host')
