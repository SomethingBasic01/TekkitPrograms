-- SpawnNet 2.1.0 RC6 Wiki Publisher
local util=dofile('/spawnnet/lib/util.lua')
local net=dofile('/spawnnet/client/net.lua')
local auth=dofile('/spawnnet/client/auth_client.lua')
local C=colors
local function die(s)term.setTextColor(C.red);print('ERROR: '..tostring(s));term.setTextColor(C.white);error(s,0)end
local function call(s,a,p,o)local x,e=net.call(s,a,p or{},o);if not x then die(s..'.'..a..': '..tostring(e))end;return x end
if not net.loadSession()then print('SpawnNet Wiki Publisher');local s,e=auth.ensureLogin();if not s then die(e)end end
term.clear();term.setCursorPos(1,1);term.setTextColor(C.yellow);print('SPAWNNET 2.1 WIKI PUBLISHER');term.setTextColor(C.white);print('Network: '..tostring(net.activeNetwork().name));write('Target domain [wiki]: ');local domain=util.safeName(read(),32);if domain==''then domain='wiki'end
local owned=net.call('web','getSite',{domain=domain})
if not owned then local r=net.call('dns','resolve',{domain=domain},{noAuth=true});if r then die('spn://'..domain..' exists but is not owned by this account')end;call('dns','register',{domain=domain,title='SpawnNet Wiki'})end
local function add(p,e)p.elements[#p.elements+1]=e;return e end
local colorsByName={blue=C.blue,purple=C.purple,gray=C.gray,orange=C.orange,lime=C.lime,green=C.green,cyan=C.cyan}
local function base(title,sub)
 local p={title=title,background=C.black,elements={}}
 add(p,{type='panel',x=1,y=1,w='100%',h=4,bg=C.gray,children={{type='heading',x=2,y=1,w=47,h=1,text='SPAWNNET WIKI',fg=C.yellow,bg=C.gray},{type='text',x=2,y=2,w=47,h=1,text=sub or title,fg=C.lightGray,bg=C.gray,align='center'}}})
 add(p,{type='button',x=1,y=5,w=9,text='HOME',bg=C.blue,action={type='navigate',target='/'}})
 add(p,{type='button',x=11,y=5,w=9,text='START',bg=C.blue,action={type='navigate',target='/start'}})
 add(p,{type='button',x=21,y=5,w=9,text='STUDIO',bg=C.purple,action={type='navigate',target='/studio'}})
 add(p,{type='button',x=31,y=5,w=9,text='LABS',bg=C.orange,action={type='navigate',target='/labs'}})
 add(p,{type='button',x=41,y=5,w=9,text='API',bg=C.gray,action={type='navigate',target='/api'}})
 return p,8
end
local function H(p,y,t)add(p,{type='heading',x=3,y=y,w=45,h=1,text=t,fg=C.yellow,align='left'});return y+2 end
local function P(p,y,t)local h=math.max(1,#util.wrapText(t,45));add(p,{type='text',x=3,y=y,w=45,h=h,text=t,fg=C.white});return y+h+1 end
local function B(p,y,text,path,bg)add(p,{type='button',x=3,y=y,w=45,h=1,text=text,bg=bg or C.blue,fg=C.white,action={type='navigate',target=path}});return y+2 end
local function badge(p,y,t,bg)add(p,{type='badge',x=3,y=y,w=45,h=1,text=t,bg=bg or C.green,fg=C.black,align='center'});return y+2 end
local function code(p,y,title,t)y=H(p,y,title);local h=math.max(1,#util.wrapText(t,41));add(p,{type='panel',x=3,y=y,w=45,h=h+2,bg=C.gray,border=true,borderChar='-',children={{type='text',x=2,y=2,w=41,h=h,text=t,fg=C.white,bg=C.gray}}});return y+h+3 end
local pages={}
local docs={
  ["/"]={title="SpawnNet Wiki",sub="Complete documentation, working demos, and advanced API labs.",sections={
    {t="h",text="Start here"},
    {t="p",text="SpawnNet is a network, website platform, and application environment for ComputerCraft. Casual users can browse and build sites without Lua; advanced users can connect trusted computers, APIs, peripherals, telemetry, durable jobs, private networks, and storage nodes."},
    {t="b",text="NEW USER: GETTING STARTED",path="/start",color="lime"},
    {t="b",text="NO-CODE WEBSITE STUDIO",path="/studio",color="purple"},
    {t="b",text="SPAWNNET LABS",path="/labs",color="orange"},
    {t="b",text="DEVELOPER API",path="/api",color="gray"},
    {t="h",text="Core ideas"},
    {t="p",text="Each SpawnNet network has its own DNS, accounts, websites, data, mail, forums, and services. The active network decides what spn:// addresses resolve to. Public and private networks can coexist in the same wireless modem range."},
    {t="p",text="Websites are hosted by the core and remain available even when their creator is offline. Trusted Lua computers can use the SDK to build workers and machine integrations without giving hosted website scripts direct peripheral access."},
    {t="b",text="FULL INDEX",path="/index",color="gray"},
  }},
  ["/start"]={title="Getting Started",sub="From fresh client to first website.",sections={
    {t="h",text="1. Open SpawnNet"},
    {t="code",text="spawnnet",title="Command"},
    {t="p",text="The Desktop is the normal user interface. CLI commands remain available for diagnostics and power users."},
    {t="h",text="2. Choose a network"},
    {t="p",text="Open NETWORKS. Discover nearby SpawnNet networks, select the one you want, and connect. Accounts and websites are scoped to that network."},
    {t="h",text="3. Create or sign in"},
    {t="p",text="Use the Desktop account screen. You can also use spawnnet register or spawnnet login from the shell."},
    {t="h",text="4. Browse"},
    {t="p",text="Open WEB and enter an address such as spn://wiki. Use mouse, keyboard navigation, scrolling, and browser history."},
    {t="h",text="5. Build"},
    {t="p",text="Open STUDIO, create a domain, choose a starter, add pages and content blocks, preview, and publish."},
    {t="b",text="LEARN STUDIO",path="/studio",color="purple"},
    {t="b",text="TROUBLESHOOTING",path="/troubleshooting",color="gray"},
  }},
  ["/desktop"]={title="Desktop",sub="SpawnNet should feel like an application, not a pile of commands.",sections={
    {t="h",text="What the Desktop does"},
    {t="p",text="The Desktop launches the Browser, Mail, Search, Studio, Networks, Apps, Forums, Chat, developer tools, settings, and account actions from one mouse-driven interface."},
    {t="h",text="Power users"},
    {t="p",text="The shell is still useful for automation and diagnostics. The Desktop does not remove the CLI; it makes the CLI optional for normal use."},
    {t="code",text="spawnnet\nspawnnet web spn://wiki\nspawnnet studio\nspawnnet networks\nspawnnet doctor\nspawnnet update",title="Useful commands"},
  }},
  ["/accounts"]={title="Accounts & Identity",sub="Login belongs to the active SpawnNet network.",sections={
    {t="h",text="Network-scoped identity"},
    {t="p",text="An account created on Public SpawnNet does not automatically exist on a private company network. Switch networks first, then register or log in there."},
    {t="h",text="Sessions"},
    {t="p",text="The client stores a session locally after login. The server validates it on requests. A stale session can be cleared by logging out and signing in again."},
    {t="h",text="API keys"},
    {t="p",text="Trusted machine programs should use scoped API keys instead of storing a normal account password. Create keys in Developer Tools and give them only the permissions the worker needs."},
    {t="b",text="SECURITY MODEL",path="/security",color="gray"},
  }},
  ["/browser"]={title="Browser",sub="Browsing, navigation, inputs, scrolling, live pages, and pinned sites.",sections={
    {t="h",text="Addresses"},
    {t="p",text="SpawnNet addresses use spn://domain/path. The domain is resolved inside the active SpawnNet network."},
    {t="h",text="Navigation"},
    {t="p",text="Pages can contain buttons that navigate to other paths or domains. The Browser also supports back/history, reload, direct address entry, search, scrolling, and site pinning."},
    {t="h",text="Interactive pages"},
    {t="p",text="Inputs, checkboxes, tables, lists, progress bars, images, and buttons can be changed by client SpawnScript or by server SpawnScript responses."},
    {t="h",text="Live pages"},
    {t="p",text="A page may request periodic server refresh events. Use this for dashboards and status pages, but keep refresh intervals reasonable."},
    {t="b",text="SPAWNSCRIPT",path="/spawnscript",color="gray"},
  }},
  ["/studio"]={title="No-Code Studio",sub="A real website editor for users who do not know CC or Lua.",sections={
    {t="h",text="The basic workflow"},
    {t="p",text="Create a site, choose a starter, edit pages as ordered content blocks, add more pages, upload assets, create navigation buttons, preview, then publish."},
    {t="h",text="Content blocks"},
    {t="p",text="Easy Studio supports multiple headings, paragraphs, buttons/links, images, dividers, badges, inputs, checkboxes, progress bars, lists, and tables. Blocks can be edited, reordered, and deleted."},
    {t="h",text="When to use Advanced Studio"},
    {t="p",text="Use Advanced Studio when you need exact layout coordinates, custom element properties, SpawnScript, APIs, or behavior beyond the no-code editor."},
    {t="b",text="PAGES",path="/studio/pages",color="purple"},
    {t="b",text="CONTENT BLOCKS",path="/studio/blocks",color="purple"},
    {t="b",text="IMAGES & ASSETS",path="/studio/images",color="purple"},
    {t="b",text="FORMS",path="/studio/forms",color="purple"},
  }},
  ["/studio/pages"]={title="Studio: Pages",sub="Create as many pages as your site needs and link them together.",sections={
    {t="h",text="Paths"},
    {t="p",text="The home page is /. Other examples are /about, /services, /docs/start, or /contact."},
    {t="h",text="Navigation"},
    {t="p",text="Add a Button/Link block and set its destination to another path such as /about or a full SpawnNet address such as spn://wiki/start."},
    {t="h",text="Page organization"},
    {t="p",text="Keep a clear home page, use consistent navigation, and split long subjects into separate pages instead of forcing everything into one enormous document."},
    {t="h",text="404 page"},
    {t="p",text="Sites can provide /404 for unknown paths. The Wiki uses one so visitors always have a route back to the index."},
  }},
  ["/studio/blocks"]={title="Studio: Content Blocks",sub="Everything the basic editor can insert.",sections={
    {t="h",text="Text"},
    {t="p",text="Heading and Paragraph blocks can be repeated as many times as needed. Paragraphs use the multi-line editor."},
    {t="h",text="Navigation"},
    {t="p",text="Button/Link blocks navigate to another page or SpawnNet site."},
    {t="h",text="Visuals"},
    {t="p",text="Image blocks reference uploaded site assets. Divider and Badge blocks help organize dense pages."},
    {t="h",text="Controls"},
    {t="p",text="Input, Checkbox, Progress, List, and Table blocks are useful for interactive sites and dashboards. Advanced behavior can bind them to SpawnScript events."},
  }},
  ["/studio/images"]={title="Studio: Images & Assets",sub="Upload once, place the same asset on any page.",sections={
    {t="h",text="Upload"},
    {t="p",text="Open Assets in Studio and upload a local file to the site. NFP images are the native image format used by the current renderer."},
    {t="h",text="Reuse"},
    {t="p",text="An uploaded asset is stored by the site and can be placed on multiple pages without re-uploading."},
    {t="h",text="Advanced use"},
    {t="p",text="Advanced pages can request site assets by name. Keep assets reasonably small because ComputerCraft disks and Rednet packets are finite."},
  }},
  ["/studio/forms"]={title="Studio: Forms",sub="Simple forms without writing server code.",sections={
    {t="h",text="Inputs"},
    {t="p",text="Input and Checkbox blocks collect values. A button can trigger an event that reads those values."},
    {t="h",text="No-code vs scripting"},
    {t="p",text="Basic forms can be assembled visually. For validation, databases, mail delivery, durable jobs, or machine control, attach server SpawnScript or use an API-backed worker."},
    {t="b",text="SPAWNSCRIPT",path="/spawnscript",color="gray"},
    {t="b",text="JOBS API",path="/api/jobs",color="gray"},
  }},
  ["/publish"]={title="Publishing & Revisions",sub="Draft first, publish deliberately.",sections={
    {t="h",text="Drafts"},
    {t="p",text="Studio edits the draft version. Visitors continue seeing the published version until you publish."},
    {t="h",text="Publish"},
    {t="p",text="Publishing copies the draft into the public version and records a revision."},
    {t="h",text="Revision history"},
    {t="p",text="Use revision history to restore an older published snapshot into the draft, inspect it, and publish again if desired."},
    {t="h",text="Safety"},
    {t="p",text="Publishing is site-owner controlled. Keep important changes in small revisions so mistakes are easy to identify and reverse."},
  }},
  ["/mail"]={title="Mail",sub="Persistent, scrollable network mail.",sections={
    {t="h",text="Inbox"},
    {t="p",text="Mail is stored on the SpawnNet core. The client presents messages as a scrollable list with unread state rather than printing the whole mailbox into the terminal."},
    {t="h",text="Reading and replying"},
    {t="p",text="Open a message to read it in a scrollable document view, reply, or delete it. Compose and reply use the multi-line editor."},
    {t="h",text="Sent mail"},
    {t="p",text="The client can list messages you sent so conversations do not disappear after delivery."},
    {t="h",text="Programmatic mail"},
    {t="p",text="Trusted Lua can use the SDK mail API, and server SpawnScript can send mail for site workflows."},
    {t="b",text="MAIL API",path="/api/mail",color="gray"},
  }},
  ["/forums"]={title="Forums",sub="Boards, scrolling threads, search, long posts, and replies.",sections={
    {t="h",text="Boards and threads"},
    {t="p",text="Forums are organized into boards. Thread lists are scrollable and show author/reply information."},
    {t="h",text="Reading"},
    {t="p",text="Posts and replies open in a scrollable reader instead of piling everything at the top of the screen."},
    {t="h",text="Writing"},
    {t="p",text="New threads and replies use the multi-line editor."},
    {t="h",text="Search"},
    {t="p",text="Forum search can find matching titles, body text, and authors across the forum service."},
  }},
  ["/chat"]={title="Chat",sub="Lightweight real-time room chat.",sections={
    {t="h",text="Rooms"},
    {t="p",text="Chat is organized into named rooms. The client reads recent messages, lets you post, and switch rooms."},
    {t="h",text="Persistence"},
    {t="p",text="The core keeps a bounded recent message history per room. Chat is for quick conversation; use Mail or Forums for durable long-form communication."},
  }},
  ["/search"]={title="Search",sub="Find published sites by indexed content.",sections={
    {t="h",text="What is indexed"},
    {t="p",text="Published site titles, descriptions, tags, and page text can contribute to search results."},
    {t="h",text="Private networks"},
    {t="p",text="Search only sees the active network. A private intranet has its own isolated search index."},
  }},
  ["/apps"]={title="Apps & Pinned Sites",sub="Turn important websites into one-click desktop entries.",sections={
    {t="h",text="Pinning"},
    {t="p",text="Pin a SpawnNet site from the Browser. The pin remembers the URL and network and appears in the Apps screen."},
    {t="h",text="Website as application"},
    {t="p",text="A rich site can combine forms, server SpawnScript, data, jobs, telemetry, and mail. Pinning it makes that site behave like an app launcher without giving it arbitrary local Lua access."},
    {t="b",text="SIGNAL BREAKER APP-LIKE DEMO",path="/labs/game",color="orange"},
  }},
  ["/networks"]={title="Networks",sub="Independent SpawnNet installations can coexist.",sections={
    {t="h",text="Discovery"},
    {t="p",text="A shared discovery protocol advertises nearby SpawnNet networks. Normal traffic uses a network-specific protocol derived from the network ID."},
    {t="h",text="Isolation"},
    {t="p",text="Accounts, DNS, websites, data, mail, and services are scoped to the selected network."},
    {t="h",text="Switching"},
    {t="p",text="Use Network Manager to discover, add, connect, forget, or supply a private join code."},
    {t="b",text="PRIVATE NETWORKS",path="/networks/private",color="gray"},
  }},
  ["/networks/private"]={title="Private Networks",sub="Build a company intranet or isolated in-house web.",sections={
    {t="h",text="Create"},
    {t="p",text="Install a core with a unique Network ID, choose private visibility, and set a join code."},
    {t="h",text="Join"},
    {t="p",text="Clients discover the network, store the join code locally, and connect. Then create a separate account on that private network."},
    {t="h",text="Same domain, different network"},
    {t="p",text="Public SpawnNet and a private network can both own spn://wiki or spn://home because DNS is isolated by network."},
    {t="b",text="INTRANET LAB",path="/labs/intranet",color="orange"},
  }},
  ["/nodes"]={title="Storage Nodes",sub="Pool spare always-loaded computers without creating competing cores.",sections={
    {t="h",text="Authority stays central"},
    {t="p",text="There is one authoritative core per network. Extra always-loaded computers join as storage nodes instead of competing cores."},
    {t="h",text="Pairing"},
    {t="p",text="Run the Storage Node installer, request enrollment, then approve the pending node from the admin cluster UI."},
    {t="h",text="Replication"},
    {t="p",text="Distributed objects can be copied to multiple approved nodes. If one node disappears, another replica can remain available."},
    {t="h",text="Rebalance"},
    {t="p",text="Admins can request rebalancing/replication as new nodes join or capacity changes."},
    {t="b",text="CLUSTER LAB",path="/labs/cluster",color="orange"},
  }},
  ["/storage"]={title="Data Storage",sub="Where SpawnNet data lives and why 2.x no longer uses one giant database.",sections={
    {t="h",text="Partitioned core data"},
    {t="p",text="Accounts and network metadata remain on the core while sites, pages, assets, revisions, mail, databases, telemetry, and other growing datasets are partitioned instead of rewriting one monolithic state file for every change."},
    {t="h",text="Storage-node objects"},
    {t="p",text="Large/distributed objects can be placed on approved storage nodes with metadata and replicas tracked by the core."},
    {t="h",text="Why this matters"},
    {t="p",text="Partitioning reduces catastrophic full-file rewrites and makes it possible to expand storage with additional always-loaded computers."},
  }},
  ["/data"]={title="Site Storage & Databases",sub="Persistent application state for hosted websites.",sections={
    {t="h",text="Site storage"},
    {t="p",text="Site storage is a small key/value tree useful for counters, preferences, flags, and simple state."},
    {t="h",text="Database collections"},
    {t="p",text="The database service provides collections with get, set, insert, and list operations for structured site data."},
    {t="code",text="local sn=dofile(\"/spawnnet/client/sdk.lua\")\nsn.storage.set(\"mysite\",\"status\",\"online\")\nsn.db.insert(\"mysite\",\"orders\",{item=\"iron\",count=16})",title="SDK examples"},
    {t="h",text="Ownership"},
    {t="p",text="Site data APIs require the site owner or an appropriately scoped trusted API key."},
  }},
  ["/spawnscript"]={title="SpawnScript",sub="Safe hosted scripting for websites.",sections={
    {t="h",text="Why SpawnScript exists"},
    {t="p",text="Hosted websites must not receive arbitrary Lua access to the core filesystem, shell, Rednet, HTTP, or peripherals. SpawnScript exposes a bounded set of operations instead."},
    {t="h",text="Client script"},
    {t="p",text="Client SpawnScript runs in the Browser and handles local UI behavior and per-computer local storage."},
    {t="h",text="Server script"},
    {t="p",text="Server SpawnScript runs through the core service layer and can use site storage, databases, mail, jobs, telemetry reads, identity, and safe UI patches."},
    {t="code",text="event hello\n  call user.name -> who\n  call ui.setText \"greeting\" \"Hello ${who}\"\nend",title="Example"},
    {t="b",text="LANGUAGE REFERENCE",path="/spawnscript/reference",color="gray"},
  }},
  ["/spawnscript/reference"]={title="SpawnScript Reference",sub="Core instructions and control flow.",sections={
    {t="h",text="Events"},
    {t="p",text="Scripts are organized as event NAME ... end blocks. Buttons and live pages invoke named events."},
    {t="h",text="Variables"},
    {t="p",text="Use set to assign values, call METHOD ... -> variable for service calls, and math for numeric expressions."},
    {t="h",text="Control flow"},
    {t="p",text="if / else / endif provide conditional logic. Keep scripts small and treat the service APIs as the boundary for durable work."},
    {t="h",text="UI patches"},
    {t="p",text="Server and client events can update text, values, visibility, lists, tables, selection, progress bars, alerts, and navigation through safe UI methods."},
  }},
  ["/api"]={title="Developer API",sub="Trusted Lua computers get the full SpawnNet SDK.",sections={
    {t="h",text="Developer Workbench"},
    {t="p",text="Open DEV TOOLS from the SpawnNet Desktop. API Explorer provides an SDK reference and live request lab; API Credentials manages scoped keys; Peripheral Lab discovers real modpack peripherals and methods; Network Lab shows routing/protocol/session state; Advanced Studio exposes freeform renderer pages and SpawnScript."},
    {t="h",text="Load the SDK"},
    {t="code",text="local sn=dofile(\"/spawnnet/client/sdk.lua\")",title="Lua"},
    {t="h",text="Major namespaces"},
    {t="p",text="The SDK exposes DNS, web, storage, database, mail, events, search, forums/chat where appropriate, telemetry, durable jobs, network operations, and node administration."},
    {t="h",text="Authentication"},
    {t="p",text="Interactive programs may use a logged-in session. Long-running workers should use scoped API keys. The API Credentials screen includes least-privilege presets and shows each secret only once."},
    {t="b",text="WEB & DATA",path="/api/web",color="gray"},
    {t="b",text="DURABLE JOBS",path="/api/jobs",color="gray"},
    {t="b",text="TELEMETRY",path="/api/telemetry",color="gray"},
    {t="b",text="MAIL & EVENTS",path="/api/mail",color="gray"},
    {t="b",text="NETWORK & NODES",path="/api/network",color="gray"},
  }},
  ["/api/web"]={title="API: Web & Data",sub="Site operations from trusted Lua.",sections={
    {t="code",text="local sn=dofile(\"/spawnnet/client/sdk.lua\")\nlocal p=sn.web.get(\"wiki\",\"/\")",title="Read a page"},
    {t="code",text="sn.storage.set(\"mysite\",\"key\",\"value\")\nlocal v=sn.storage.get(\"mysite\",\"key\")\nsn.storage.inc(\"mysite\",\"counter\",1)",title="Storage"},
    {t="code",text="sn.db.set(\"mysite\",\"users\",\"bob\",{rank=\"member\"})\nsn.db.insert(\"mysite\",\"logs\",{message=\"hello\"})\nlocal rows=sn.db.list(\"mysite\",\"logs\",50)",title="Database"},
    {t="p",text="Use the no-code Studio for normal page editing. The SDK is for trusted programs, automation, migration tools, and integrations."},
  }},
  ["/api/jobs"]={title="API: Durable Jobs",sub="The generic bridge between websites and trusted worker computers.",sections={
    {t="h",text="What a job is"},
    {t="p",text="A job is durable work stored on the core. A website can submit it while the target machine is offline. A trusted worker can later poll, claim, report progress, complete, or fail it."},
    {t="code",text="local sn=dofile(\"/spawnnet/client/sdk.lua\")\nwhile true do\n  local q=sn.jobs.poll(\"mysite\",\"factory\",10)\n  for _,j in ipairs(q.jobs or {}) do\n    sn.jobs.claim(\"mysite\",j.id,\"worker-1\")\n    -- YOUR peripheral/API work here\n    sn.jobs.progress(\"mysite\",j.id,50,\"Halfway\")\n    sn.jobs.complete(\"mysite\",j.id,{ok=true},\"Done\")\n  end\n  sleep(2)\nend",title="Worker skeleton"},
    {t="h",text="Workers are intentionally yours"},
    {t="p",text="SpawnNet supplies the durable queue and scoped authentication; trusted computers supply the machine-specific Lua. Use Peripheral X-Ray to discover the methods your modpack exposes, then build the worker around those methods."},
    {t="b",text="PHYSICAL CHEST SHOWCASE",path="/labs/chest",color="orange"},
    {t="b",text="PERIPHERAL X-RAY",path="/labs/peripheral",color="gray"},
  }},
  ["/api/telemetry"]={title="API: Telemetry",sub="Publish physical machine state for live dashboards.",sections={
    {t="h",text="Push"},
    {t="code",text="sn.telemetry.push(\"mysite\",\"reactor\",{power=18291,temp=722,online=true})",title="Lua"},
    {t="h",text="Read"},
    {t="p",text="Websites or trusted clients can read recent telemetry points for a stream. Use short summaries, not giant raw peripheral dumps."},
    {t="h",text="Physical data"},
    {t="p",text="Read real peripheral methods with peripheral.call or peripheral.wrap, normalize the useful values, then push them into SpawnNet."},
    {t="b",text="LIVE TELEMETRY LAB",path="/labs",color="orange"},
  }},
  ["/api/mail"]={title="API: Mail & Events",sub="Persistent communication primitives.",sections={
    {t="code",text="sn.mail.send(\"bob\",\"Subject\",\"Longer message body\")\nlocal inbox=sn.mail.inbox(25)",title="Mail"},
    {t="code",text="sn.events.emit(\"bob\",\"machine.alert\",{message=\"Over temperature\"})\nlocal events=sn.events.poll(25)",title="Events"},
    {t="p",text="Mail is human-facing and durable. Events are lightweight queued application messages consumed by clients or workers."},
  }},
  ["/api/network"]={title="API: Network & Nodes",sub="Discovery, switching, and admin cluster operations.",sections={
    {t="h",text="Networks"},
    {t="p",text="Trusted clients can inspect known networks, discover nearby advertisements, and switch the active network."},
    {t="h",text="Nodes"},
    {t="p",text="Admin tools can inspect online/pending storage nodes, approve pairing requests, and request replication/rebalancing."},
    {t="p",text="Normal applications should not hardcode Rednet protocols. Use SpawnNet discovery and the active network registry."},
  }},
  ["/security"]={title="Security Model",sub="Public website code and trusted machine code are intentionally different.",sections={
    {t="h",text="Hosted code is sandboxed"},
    {t="p",text="SpawnScript cannot directly open the shell, filesystem, Rednet, HTTP, or arbitrary peripherals."},
    {t="h",text="Trusted workers are powerful"},
    {t="p",text="Lua running on a player-controlled computer can use normal ComputerCraft peripheral APIs plus a scoped SpawnNet API key. This is where physical machine integration belongs."},
    {t="h",text="Least privilege"},
    {t="p",text="Create API keys with only the scopes needed by the worker. Revoke keys that are lost or no longer used."},
    {t="h",text="Private networks"},
    {t="p",text="Private visibility and join codes isolate discovery access, but administrators should still treat the network as a game-server service rather than a high-security real-world system."},
  }},
  ["/protocol"]={title="Protocol & Discovery",sub="How multiple networks avoid stepping on one another.",sections={
    {t="h",text="Discovery"},
    {t="p",text="Clients listen on the shared SpawnNet v2 discovery channel for network advertisements."},
    {t="h",text="Network traffic"},
    {t="p",text="Each network derives its client and backbone protocols from its unique network ID, so multiple cores in modem range do not all answer the same application protocol."},
    {t="h",text="Request matching"},
    {t="p",text="SpawnNet requests include IDs and validate sender/protocol responses so unrelated Rednet traffic is ignored."},
  }},
  ["/admin"]={title="Administration",sub="Core, users, private networks, storage, and diagnostics.",sections={
    {t="h",text="Core"},
    {t="p",text="Keep the authoritative core chunk-loaded whenever the SpawnNet network should be available. Stop it before running a core installer upgrade."},
    {t="h",text="Storage cluster"},
    {t="p",text="Approve only storage nodes you control. Watch free space and replica health in the Nodes screen."},
    {t="h",text="Moderation"},
    {t="p",text="Admin tools can review reports, suspend users/sites, and grant roles."},
    {t="h",text="Diagnostics"},
    {t="code",text="spawnnet-status\nspawnnet doctor\nspawnnet nodes",title="Commands"},
  }},
  ["/update"]={title="Updates",sub="Clients should not require a chain of manually copied hotfixes.",sections={
    {t="h",text="Core first"},
    {t="p",text="Upgrade the core first. The core publishes the official client package for that SpawnNet version."},
    {t="h",text="Clients"},
    {t="code",text="spawnnet update",title="Client update"},
    {t="p",text="Fresh computers can use the matching Client installer directly."},
    {t="h",text="Release candidates"},
    {t="p",text="Test RC builds on one client/core before rolling them out broadly. Do not call an RC public-stable until the real server has exercised the important paths."},
  }},
  ["/troubleshooting"]={title="Troubleshooting",sub="Use diagnostics before editing internal files.",sections={
    {t="h",text="Core not found"},
    {t="p",text="Check that both machines have modems, are in range, and the client is connected to the correct SpawnNet network."},
    {t="h",text="Wrong website/network"},
    {t="p",text="Open Network Manager and verify the active network. The same spn:// domain can exist independently on multiple networks."},
    {t="h",text="Login problems"},
    {t="p",text="Log out and back in. Accounts are network-specific."},
    {t="h",text="Version mismatch"},
    {t="code",text="spawnnet doctor",title="Check"},
    {t="p",text="Update the core first, then run spawnnet update on clients."},
    {t="h",text="Report exact errors"},
    {t="p",text="When reporting a failure, include the full error text and which Core/Client/Wiki build you ran. Line numbers are extremely useful."},
  }},
  ["/labs"]={title="SpawnNet Labs",sub="A playable showcase: zero setup first, real hardware later.",sections={
    {t="badge",text="START WITH A GAME. END WITH REAL DISTRIBUTED INFRASTRUCTURE.",color="orange"},
    {t="p",text="These are not screenshots or theoretical mockups. Each lab is meant to do something you can actually see happen. Labs 01-03 require no setup beyond SpawnNet. Lab 04 needs an inventory peripheral. Later labs deliberately expose the deeper developer and network layers."},
    {t="b",text="LAB 01 - SIGNAL BREAKER GAME  [ZERO SETUP]",path="/labs/game",color="lime"},
    {t="b",text="LAB 02 - SHARED GRID  [ZERO SETUP / MULTIPLAYER]",path="/labs/canvas",color="cyan"},
    {t="b",text="LAB 03 - MAIL HEIST  [ZERO SETUP / CROSS-APP]",path="/labs/vault",color="purple"},
    {t="b",text="LAB 04 - CHEST PULSE  [1 INVENTORY; 2 FOR CYCLING]",path="/labs/chest",color="orange"},
    {t="b",text="LAB 05 - PERIPHERAL X-RAY  [ANY PERIPHERAL]",path="/labs/peripheral",color="gray"},
    {t="b",text="LAB 06 - STORAGE CLUSTER  [ADMIN / NODES]",path="/labs/cluster",color="gray"},
    {t="b",text="LAB 07 - PRIVATE INTRANET  [SECOND CORE]",path="/labs/intranet",color="gray"},
    {t="h",text="Why the progression matters"},
    {t="p",text="Lab 01 proves hosted pages can behave like games. Lab 02 proves visitors can share live server state. Lab 03 crosses Browser, identity and Mail. Lab 04 touches real Minecraft inventory hardware with a temporary demo harness. Lab 05 exposes raw peripheral methods. Labs 06-07 move into distributed storage and isolated networks."},
  }},
  ["/reference"]={title="Command Reference",sub="Useful CLI equivalents for power users.",sections={
    {t="code",text="spawnnet                    Desktop\nspawnnet web spn://domain     Browser\nspawnnet studio               Easy Studio\nspawnnet networks             Network Manager\nspawnnet mail                 Mail\nspawnnet forum                Forums\nspawnnet chat [room]          Chat\nspawnnet doctor               Diagnostics\nspawnnet update               Update client\nspawnnet login / register     Account CLI",title="Client"},
    {t="code",text="spawnnet-server             Start core\nspawnnet-status             Core status\nspawnnet-admin              Admin tools",title="Core"},
    {t="p",text="The Desktop remains the recommended interface for casual users."},
  }},
  ["/about"]={title="About",sub="A low floor and a ridiculous ceiling.",sections={
    {t="h",text="Design goal"},
    {t="p",text="A player who knows nothing about CC or Lua should be able to browse, register, create pages, add text/images/links, publish, use Mail, and use Forums without opening a code editor."},
    {t="h",text="Advanced ceiling"},
    {t="p",text="A developer should be able to build private intranets, live machine dashboards, persistent workers, web-controlled factories, distributed storage integrations, and custom application workflows using the SDK and normal ComputerCraft APIs."},
    {t="p",text="SpawnNet is infrastructure. It should provide the web, identity, data, communication, jobs, telemetry, network isolation, storage, and tools. Players decide what applications to invent on top of it."},
  }},
}

for path,d in pairs(docs)do
 local p,y=base(d.title,d.sub)
 for _,s in ipairs(d.sections)do
  if s.t=='h'then y=H(p,y,s.text)
  elseif s.t=='p'then y=P(p,y,s.text)
  elseif s.t=='code'then y=code(p,y,s.title,s.text)
  elseif s.t=='b'then y=B(p,y,s.text,s.path,colorsByName[s.color]or C.blue)
  elseif s.t=='badge'then y=badge(p,y,s.text,colorsByName[s.color]or C.green)end
 end
 pages[path]=p
end

-- LAB 01: SIGNAL BREAKER. Zero setup; pure hosted client script + persistent global leaderboard.
do
 local p,y=base('LAB 01 - Signal Breaker','A real 20-second browser game. No hardware. No Lua setup.');p.liveInterval=1
 add(p,{type='input',id='labMode',x=1,y=1,w=1,value='game',visible=false})
 add(p,{type='input',id='gameScore',x=1,y=1,w=1,value='0',visible=false})
 add(p,{type='badge',x=3,y=8,w=45,text='ZERO SETUP - CLICK START AND PLAY',bg=C.lime,fg=C.black,align='center'})
 add(p,{type='text',x=3,y=10,w=45,h=2,text='Hit the pad named by TARGET before the 20-second clock expires. Wrong pads cost a point. Your local best stays on this computer; submit a run to challenge the whole network.'})
 add(p,{type='badge',id='gameTarget',x=3,y=13,w=45,text='TARGET: PRESS START',bg=C.orange,fg=C.black,align='center'})
 add(p,{type='button',id='pad1',x=3,y=15,w=22,text='ALPHA',bg=C.blue,action={type='event',event='game_pick'}})
 add(p,{type='button',id='pad2',x=27,y=15,w=22,text='BETA',bg=C.purple,action={type='event',event='game_pick'}})
 add(p,{type='button',id='pad3',x=3,y=17,w=22,text='GAMMA',bg=C.cyan,fg=C.black,action={type='event',event='game_pick'}})
 add(p,{type='button',id='pad4',x=27,y=17,w=22,text='DELTA',bg=C.orange,fg=C.black,action={type='event',event='game_pick'}})
 add(p,{type='progress',id='gameTime',x=3,y=20,w=45,value=20,max=20,fg=C.lime})
 add(p,{type='text',id='gameScoreText',x=3,y=22,w=22,h=1,text='Score: 0'})
 add(p,{type='text',id='gameLocalBest',x=27,y=22,w=22,h=1,text='Local best: 0'})
 add(p,{type='text',id='gameGlobalBest',x=3,y=24,w=45,h=1,text='Network best: loading...',fg=C.yellow})
 add(p,{type='button',x=3,y=26,w=22,text='START / RESTART',bg=C.lime,fg=C.black,action={type='event',event='game_start'}})
 add(p,{type='button',x=27,y=26,w=22,text='SUBMIT SCORE',bg=C.gray,action={type='server',event='game_submit'}})
 y=29;y=H(p,y,'What you just used');y=P(p,y,'Client SpawnScript, one-second ticks, random numbers, computer-local persistence, live UI patches, hidden form state, authenticated identity and server-persistent leaderboard data - all inside a normal spn:// page.')
 pages['/labs/game']=p
end

-- LAB 02: SHARED GRID. Zero setup; every visitor edits the same 4x4 server-backed canvas.
do
 local p,y=base('LAB 02 - Shared Grid','A tiny multiplayer canvas backed by the SpawnNet core.');p.liveInterval=1.5;p.liveServerEvent='canvas_refresh'
 add(p,{type='badge',x=3,y=8,w=45,text='OPEN THIS PAGE ON TWO COMPUTERS',bg=C.cyan,fg=C.black,align='center'})
 add(p,{type='text',x=3,y=10,w=45,h=2,text='Every cell below is shared. Click one here and watch the other computer update on its next live refresh.'})
 local yy=13
 for r=1,4 do
  local xx=3
  for c=1,4 do local id='c'..r..c;add(p,{type='button',id=id,x=xx,y=yy,w=10,text=' . ',bg=C.gray,action={type='server',event='canvas_toggle'}});xx=xx+11 end
  yy=yy+2
 end
 add(p,{type='text',id='canvasInfo',x=3,y=22,w=45,h=2,text='Shared edits: loading...'})
 add(p,{type='button',x=3,y=25,w=45,text='CLEAR THE SHARED GRID',bg=C.red,action={type='server',event='canvas_reset'}})
 y=28;y=H(p,y,'Why this is different from a local game');y=P(p,y,'The grid is not stored in your client. The page sends server actions to the core, the core stores the shared state, and every visitor receives UI patches from live refresh. This is the same primitive a player could use for collaborative boards, live controls, polls or shared dashboards.')
 pages['/labs/canvas']=p
end

-- LAB 03: MAIL HEIST. Zero setup; crosses Browser -> identity -> persistent Mail -> Browser.
do
 local p,y=base('LAB 03 - Mail Heist','Break into the demo vault using a code delivered through real SpawnNet Mail.')
 add(p,{type='badge',x=3,y=8,w=45,text='LOGIN REQUIRED - NO OTHER SETUP',bg=C.purple,fg=C.white,align='center'})
 add(p,{type='text',x=3,y=10,w=45,h=3,text='1) Request an access code. 2) Open Mail without closing this page. 3) Read the message. 4) Return and enter the code. The vault code is generated and stored server-side.'})
 add(p,{type='button',x=3,y=14,w=22,text='BEGIN HEIST',bg=C.orange,fg=C.black,action={type='server',event='vault_begin'}})
 add(p,{type='button',x=27,y=14,w=22,text='OPEN MAIL APP',bg=C.cyan,fg=C.black,action={type='lab',demo='mail'}})
 add(p,{type='input',id='vaultCode',x=3,y=17,w=45,placeholder='Enter the code from your SpawnNet Mail'})
 add(p,{type='button',x=3,y=19,w=45,text='UNLOCK VAULT',bg=C.lime,fg=C.black,action={type='server',event='vault_verify'}})
 add(p,{type='text',id='vaultStatus',x=3,y=22,w=45,h=2,text='Vault armed. Request a code.'})
 add(p,{type='panel',id='vaultSecret',x=3,y=25,w=45,h=8,bg=C.gray,border=true,visible=false,children={
   {type='heading',x=2,y=2,w=41,text='ACCESS GRANTED',fg=C.lime,bg=C.gray,align='center'},
   {type='text',x=2,y=4,w=41,h=3,text='You just crossed Browser -> Core -> Account Identity -> Persistent Mail -> Browser and unlocked UI state.',fg=C.white,bg=C.gray,align='center'}
 }})
 y=35;y=H(p,y,'What to notice');y=P(p,y,'The browser did not fake an inbox. The message appears in the same Mail application players use normally, survives until read/deleted, and the verification happens against server-side site storage tied to your account name.')
 pages['/labs/vault']=p
end

-- LAB 04: CHEST PULSE. Minimal physical setup; temporary local harness, not a production machine integration.
do
 local p,y=base('LAB 04 - Chest Pulse','Put real items in a real inventory and watch this page react.');p.liveInterval=1
 add(p,{type='input',id='labMode',x=1,y=1,w=1,value='chest',visible=false})
 add(p,{type='badge',x=3,y=8,w=45,text='1 INVENTORY = LIVE MIRROR | 2 = PHYSICAL ITEM CYCLING',bg=C.orange,fg=C.black,align='center'})
 add(p,{type='text',x=3,y=10,w=45,h=4,text='Place or connect any inventory that ComputerCraft exposes with list(). Press START HARNESS and choose it. With one inventory the page mirrors its real contents. With two compatible inventories you can move one real item back and forth while watching the counts change.'})
 add(p,{type='button',x=3,y=15,w=45,text='START / RESTART 3-MINUTE CHEST HARNESS',bg=C.lime,fg=C.black,action={type='lab',demo='chest'}})
 add(p,{type='badge',id='chestState',x=3,y=18,w=45,text='HARNESS: NOT STARTED',bg=C.gray,fg=C.white,align='center'})
 add(p,{type='text',id='chestA',x=3,y=21,w=45,h=2,text='A: waiting for inventory...'})
 add(p,{type='text',id='chestB',x=3,y=24,w=45,h=2,text='B: optional second inventory...'})
 add(p,{type='text',id='chestMoves',x=3,y=27,w=45,h=1,text='Physical items moved: 0'})
 add(p,{type='button',id='chestCycle',x=3,y=29,w=22,text='CYCLE ONE ITEM',bg=C.blue,action={type='event',event='chest_cycle'}})
 add(p,{type='button',id='chestAuto',x=27,y=29,w=22,text='AUTO CYCLE: OFF',bg=C.purple,action={type='event',event='chest_auto'}})
 add(p,{type='button',x=3,y=31,w=45,text='STOP LOCAL HARNESS',bg=C.red,action={type='event',event='chest_stop'}})
 y=34;y=H(p,y,'This is deliberately a demo harness');y=P(p,y,'Chest Pulse exists only so a new user can see the trust boundary in minutes: a hosted page changes local demo commands, a temporary trusted client process talks to the real peripheral, and the page mirrors the result. SpawnNet does not install a permanent item-management system. Build production machine workers yourself with the SDK, scoped credentials and the methods exposed by your modpack.')
 y=B(p,y,'NEXT: PERIPHERAL X-RAY','/labs/peripheral',C.gray);pages['/labs/chest']=p
end

-- LAB 05: PERIPHERAL X-RAY. One click opens the real local method explorer.
do
 local p,y=base('LAB 05 - Peripheral X-Ray','Stop guessing what a mod exposes to ComputerCraft.')
 y=badge(p,y,'ANY ATTACHED PERIPHERAL - NO CODE REQUIRED',C.gray)
 y=P(p,y,'Press the button below. SpawnNet opens the local Peripheral Lab, enumerates the actual peripherals on this computer, lists the methods each one exposes, and lets you call a method with Lua-table arguments. Nothing is simulated.')
 add(p,{type='button',x=3,y=y,w=45,text='OPEN PERIPHERAL X-RAY',bg=C.cyan,fg=C.black,action={type='lab',demo='peripheral'}});y=y+2
 y=H(p,y,'The developer leap');y=P(p,y,'Once you discover methods such as list, pushItems, getEnergyStored, getTemperature, setOutput or mod-specific calls, the SDK can connect those real values to websites, telemetry, durable jobs and events. This is where the ceiling stops being predefined by SpawnNet and starts being defined by the modpack.')
 y=B(p,y,'JOBS API','/api/jobs',C.purple);y=B(p,y,'TELEMETRY API','/api/telemetry',C.blue);pages['/labs/peripheral']=p
end

-- LAB 06: CLUSTER FAILOVER. Live status from real backbone.
do
 local p,y=base('LAB 06 - Storage Cluster','Watch the real SpawnNet storage backbone change.');p.liveInterval=2;p.liveServerEvent='cluster_refresh'
 add(p,{type='badge',id='clusterState',x=3,y=8,w=45,text='CLUSTER: checking...',bg=C.orange,fg=C.black,align='center'})
 add(p,{type='text',id='clusterFree',x=3,y=11,w=45,h=2,text='Combined free space: ...'})
 add(p,{type='text',id='clusterObjects',x=3,y=14,w=45,h=2,text='Distributed objects: ...'})
 y=18;y=H(p,y,'Make the numbers move');y=P(p,y,'Pair an always-loaded storage node, approve it, and watch online capacity appear here. Remove or stop a node and the live count drops. Rebalance replicas from the admin cluster screen and object placement changes without creating a second authoritative core.')
 add(p,{type='button',x=3,y=y,w=45,text='OPEN LOCAL NETWORK LAB',bg=C.gray,action={type='lab',demo='network'}});y=y+2
 y=B(p,y,'STORAGE NODE MANUAL','/nodes',C.gray);pages['/labs/cluster']=p
end

-- LAB 07: PRIVATE INTRANET. Advanced network isolation demo.
do
 local p,y=base('LAB 07 - Private Intranet','The same URL can resolve to a completely different world on another SpawnNet network.')
 y=badge(p,y,'ADVANCED - SECOND CORE REQUIRED',C.gray)
 y=H(p,y,'Experiment');y=P(p,y,'Create a second core with a different Network ID and private visibility. Join it from Network Manager and create spn://demo there. Create another spn://demo on the public network. Switch networks: the address stays identical while accounts, DNS, websites and data remain isolated.')
 y=H(p,y,'The point');y=P(p,y,'This is not a browser theme trick. Normal traffic uses a protocol derived from the active network ID, so multiple independent SpawnNet installations can coexist inside wireless range without fighting over one hard-coded core.')
 y=B(p,y,'PRIVATE NETWORK GUIDE','/networks/private',C.gray);pages['/labs/intranet']=p
end

-- Index / 404.
do
 local p,y=base('Wiki Index','All major documentation sections.')
 local links={{'Getting Started','/start'},{'Desktop','/desktop'},{'Accounts','/accounts'},{'Browser','/browser'},{'Studio','/studio'},{'Publishing','/publish'},{'Mail','/mail'},{'Forums','/forums'},{'Search','/search'},{'Apps','/apps'},{'Networks','/networks'},{'Storage Nodes','/nodes'},{'Data Storage','/storage'},{'Site Data','/data'},{'SpawnScript','/spawnscript'},{'Developer API','/api'},{'Security','/security'},{'Admin','/admin'},{'Updates','/update'},{'Troubleshooting','/troubleshooting'},{'Labs','/labs'},{'Reference','/reference'},{'About','/about'}}
 for _,l in ipairs(links)do y=B(p,y,l[1],l[2],C.gray)end;pages['/index']=p
end
do local p,y=base('404','That path does not exist in this wiki.');y=P(p,y,'Use the index or home page to continue.');y=B(p,y,'HOME','/',C.blue);y=B(p,y,'INDEX','/index',C.gray);pages['/404']=p end

local clientScript=[=[
event load
  call input.get "labMode" -> mode
  if $mode == "game"
    call local.get "labs.game.bestLocal" -> best
    if $best == nil
      set best 0
    endif
    call ui.setText "gameLocalBest" "Local best: ${best}"
    call server.run "game_refresh"
  endif
  if $mode == "chest"
    call local.get "labs.chest.status" -> status
    if $status == nil
      set status "Not started. Press START HARNESS."
    endif
    call ui.setText "chestState" "HARNESS: ${status}"
  endif
end

event tick
  call input.get "labMode" -> mode
  if $mode == "game"
    call local.get "labs.game.active" -> active
    if $active == true
      call local.get "labs.game.time" -> time
      if $time == nil
        set time 0
      endif
      math time $time - 1
      call local.set "labs.game.time" $time
      call ui.setProgress "gameTime" $time
      if $time <= 0
        call local.set "labs.game.active" false
        call ui.setText "gameTarget" "TIME! SUBMIT YOUR SCORE"
        call ui.alert "Run complete. Submit the score if you want it on the network leaderboard."
      endif
    endif
  endif
  if $mode == "chest"
    call local.get "labs.chest.status" -> status
    call local.get "labs.chest.active" -> active
    call local.get "labs.chest.inventoryA" -> ia
    call local.get "labs.chest.inventoryB" -> ib
    call local.get "labs.chest.totalA" -> ta
    call local.get "labs.chest.totalB" -> tb
    call local.get "labs.chest.sampleA" -> sa
    call local.get "labs.chest.sampleB" -> sb
    call local.get "labs.chest.moves" -> moves
    call local.get "labs.chest.auto" -> auto
    if $status == nil
      set status "Not started"
    endif
    if $ta == nil
      set ta 0
    endif
    if $tb == nil
      set tb 0
    endif
    if $moves == nil
      set moves 0
    endif
    call ui.setText "chestState" "HARNESS: ${status}"
    call ui.setText "chestA" "A ${ia}: ${ta} items | ${sa}"
    call ui.setText "chestB" "B ${ib}: ${tb} items | ${sb}"
    call ui.setText "chestMoves" "Physical items moved: ${moves}"
    if $auto == true
      call ui.setText "chestAuto" "AUTO CYCLE: ON"
    else
      call ui.setText "chestAuto" "AUTO CYCLE: OFF"
    endif
  endif
end

event game_start
  call local.set "labs.game.active" true
  call local.set "labs.game.time" 20
  call local.set "labs.game.score" 0
  call ui.setProgress "gameTime" 20
  call ui.setText "gameScoreText" "Score: 0"
  call ui.setValue "gameScore" 0
  random target 1 4
  call local.set "labs.game.target" $target
  if $target == 1
    call ui.setText "gameTarget" "TARGET: ALPHA"
  endif
  if $target == 2
    call ui.setText "gameTarget" "TARGET: BETA"
  endif
  if $target == 3
    call ui.setText "gameTarget" "TARGET: GAMMA"
  endif
  if $target == 4
    call ui.setText "gameTarget" "TARGET: DELTA"
  endif
end

event game_pick
  call local.get "labs.game.active" -> active
  if $active != true
    call ui.alert "Press START first."
  else
    call local.get "labs.game.target" -> target
    set picked 0
    if $args.id == "pad1"
      set picked 1
    endif
    if $args.id == "pad2"
      set picked 2
    endif
    if $args.id == "pad3"
      set picked 3
    endif
    if $args.id == "pad4"
      set picked 4
    endif
    call local.get "labs.game.score" -> score
    if $score == nil
      set score 0
    endif
    if $picked == $target
      math score $score + 1
    else
      math score $score - 1
      if $score < 0
        set score 0
      endif
    endif
    call local.set "labs.game.score" $score
    call ui.setValue "gameScore" $score
    call ui.setText "gameScoreText" "Score: ${score}"
    call local.get "labs.game.bestLocal" -> best
    if $best == nil
      set best 0
    endif
    if $score > $best
      set best $score
      call local.set "labs.game.bestLocal" $best
      call ui.setText "gameLocalBest" "Local best: ${best}"
    endif
    random target 1 4
    call local.set "labs.game.target" $target
    if $target == 1
      call ui.setText "gameTarget" "TARGET: ALPHA"
    endif
    if $target == 2
      call ui.setText "gameTarget" "TARGET: BETA"
    endif
    if $target == 3
      call ui.setText "gameTarget" "TARGET: GAMMA"
    endif
    if $target == 4
      call ui.setText "gameTarget" "TARGET: DELTA"
    endif
  endif
end

event chest_cycle
  call local.set "labs.chest.command" "cycle"
  call ui.alert "Cycle command sent to the temporary local harness."
end

event chest_auto
  call local.set "labs.chest.command" "toggle_auto"
end

event chest_stop
  call local.set "labs.chest.command" "stop"
end
]=]

local serverScript=[=[
event game_refresh
  call storage.get "labs.game.best" -> best
  call storage.get "labs.game.holder" -> holder
  if $best == nil
    set best 0
  endif
  if $holder == nil
    set holder "nobody yet"
  endif
  call ui.setText "gameGlobalBest" "Network best: ${best} by ${holder}"
end

event game_submit
  call user.name -> who
  if $who == nil
    call ui.alert "Sign in before submitting a network score."
  else
    math score $input.gameScore + 0
    call storage.get "labs.game.best" -> best
    if $best == nil
      set best 0
    endif
    if $score > $best
      call storage.set "labs.game.best" $score
      call storage.set "labs.game.holder" $who
      call ui.setText "gameGlobalBest" "NEW NETWORK BEST: ${score} by ${who}"
      call ui.alert "New SpawnNet-wide high score!"
    else
      call storage.get "labs.game.holder" -> holder
      call ui.setText "gameGlobalBest" "Network best: ${best} by ${holder}"
      call ui.alert "Score submitted. Beat ${best} to take the record."
    endif
  endif
end

event canvas_toggle
  concat key "labs.canvas." $args.id
  call storage.get $key -> value
  if $value == nil
    set value 0
  endif
  if $value == 1
    call storage.set $key 0
    call ui.setText $args.id " . "
  else
    call storage.set $key 1
    call ui.setText $args.id "###"
  endif
  call storage.inc "labs.canvas.edits" 1 -> edits
  call user.name -> who
  if $who == nil
    set who "Guest"
  endif
  call storage.set "labs.canvas.last" $who
  call ui.setText "canvasInfo" "Shared edits: ${edits} | Last editor: ${who}"
end

event canvas_refresh
  call storage.get "labs.canvas.c11" -> c11
  if $c11 == 1
    call ui.setText "c11" "###"
  else
    call ui.setText "c11" " . "
  endif
  call storage.get "labs.canvas.c12" -> c12
  if $c12 == 1
    call ui.setText "c12" "###"
  else
    call ui.setText "c12" " . "
  endif
  call storage.get "labs.canvas.c13" -> c13
  if $c13 == 1
    call ui.setText "c13" "###"
  else
    call ui.setText "c13" " . "
  endif
  call storage.get "labs.canvas.c14" -> c14
  if $c14 == 1
    call ui.setText "c14" "###"
  else
    call ui.setText "c14" " . "
  endif
  call storage.get "labs.canvas.c21" -> c21
  if $c21 == 1
    call ui.setText "c21" "###"
  else
    call ui.setText "c21" " . "
  endif
  call storage.get "labs.canvas.c22" -> c22
  if $c22 == 1
    call ui.setText "c22" "###"
  else
    call ui.setText "c22" " . "
  endif
  call storage.get "labs.canvas.c23" -> c23
  if $c23 == 1
    call ui.setText "c23" "###"
  else
    call ui.setText "c23" " . "
  endif
  call storage.get "labs.canvas.c24" -> c24
  if $c24 == 1
    call ui.setText "c24" "###"
  else
    call ui.setText "c24" " . "
  endif
  call storage.get "labs.canvas.c31" -> c31
  if $c31 == 1
    call ui.setText "c31" "###"
  else
    call ui.setText "c31" " . "
  endif
  call storage.get "labs.canvas.c32" -> c32
  if $c32 == 1
    call ui.setText "c32" "###"
  else
    call ui.setText "c32" " . "
  endif
  call storage.get "labs.canvas.c33" -> c33
  if $c33 == 1
    call ui.setText "c33" "###"
  else
    call ui.setText "c33" " . "
  endif
  call storage.get "labs.canvas.c34" -> c34
  if $c34 == 1
    call ui.setText "c34" "###"
  else
    call ui.setText "c34" " . "
  endif
  call storage.get "labs.canvas.c41" -> c41
  if $c41 == 1
    call ui.setText "c41" "###"
  else
    call ui.setText "c41" " . "
  endif
  call storage.get "labs.canvas.c42" -> c42
  if $c42 == 1
    call ui.setText "c42" "###"
  else
    call ui.setText "c42" " . "
  endif
  call storage.get "labs.canvas.c43" -> c43
  if $c43 == 1
    call ui.setText "c43" "###"
  else
    call ui.setText "c43" " . "
  endif
  call storage.get "labs.canvas.c44" -> c44
  if $c44 == 1
    call ui.setText "c44" "###"
  else
    call ui.setText "c44" " . "
  endif
  call storage.get "labs.canvas.edits" -> edits
  call storage.get "labs.canvas.last" -> who
  if $edits == nil
    set edits 0
  endif
  if $who == nil
    set who "nobody yet"
  endif
  call ui.setText "canvasInfo" "Shared edits: ${edits} | Last editor: ${who}"
end

event canvas_reset
  call storage.set "labs.canvas.c11" 0
  call storage.set "labs.canvas.c12" 0
  call storage.set "labs.canvas.c13" 0
  call storage.set "labs.canvas.c14" 0
  call storage.set "labs.canvas.c21" 0
  call storage.set "labs.canvas.c22" 0
  call storage.set "labs.canvas.c23" 0
  call storage.set "labs.canvas.c24" 0
  call storage.set "labs.canvas.c31" 0
  call storage.set "labs.canvas.c32" 0
  call storage.set "labs.canvas.c33" 0
  call storage.set "labs.canvas.c34" 0
  call storage.set "labs.canvas.c41" 0
  call storage.set "labs.canvas.c42" 0
  call storage.set "labs.canvas.c43" 0
  call storage.set "labs.canvas.c44" 0
  call ui.setText "c11" " . "
  call ui.setText "c12" " . "
  call ui.setText "c13" " . "
  call ui.setText "c14" " . "
  call ui.setText "c21" " . "
  call ui.setText "c22" " . "
  call ui.setText "c23" " . "
  call ui.setText "c24" " . "
  call ui.setText "c31" " . "
  call ui.setText "c32" " . "
  call ui.setText "c33" " . "
  call ui.setText "c34" " . "
  call ui.setText "c41" " . "
  call ui.setText "c42" " . "
  call ui.setText "c43" " . "
  call ui.setText "c44" " . "
  call storage.inc "labs.canvas.edits" 1 -> edits
  call ui.setText "canvasInfo" "Shared grid cleared | Edit #${edits}"
end

event vault_begin
  call user.name -> who
  if $who == nil
    call ui.setText "vaultStatus" "Sign in first; the code has to be delivered to a real account."
    call ui.alert "This lab requires a logged-in SpawnNet account."
  else
    random code 1000 9999
    concat key "labs.vault." $who
    call storage.set $key $code
    concat body "Your one-time demo vault code is " $code ". Return to spn://wiki/labs/vault and enter it."
    call mail.send $who "SpawnNet Lab: Vault Access" $body -> mid
    call ui.setText "vaultStatus" "Access code sent to ${who}. Open Mail and read message ${mid}."
  endif
end

event vault_verify
  call user.name -> who
  if $who == nil
    call ui.alert "Sign in first."
  else
    concat key "labs.vault." $who
    call storage.get $key -> expected
    math entered $input.vaultCode + 0
    if $expected == nil
      call ui.setText "vaultStatus" "No active code. Press BEGIN HEIST first."
    else
      if $entered == $expected
        call ui.setText "vaultStatus" "ACCESS GRANTED - cross-app challenge complete."
        call ui.setVisible "vaultSecret" true
        call storage.set $key 0
        call storage.inc "labs.vault.opens" 1 -> opens
        call ui.alert "Vault unlocked. Network-wide opens: ${opens}"
      else
        call ui.setText "vaultStatus" "ACCESS DENIED - wrong code."
      endif
    endif
  endif
end

event cluster_refresh
  call network.cluster -> c
  call ui.setText "clusterState" "CLUSTER: ${c.online}/${c.totalNodes} STORAGE NODES ONLINE"
  call ui.setText "clusterFree" "Combined online free space: ${c.free} bytes"
  call ui.setText "clusterObjects" "Tracked distributed objects: ${c.objects}"
end
]=]

local logo=[=[
ffffffffffffffff
f77777777777777f
f7bbbbbbbbbbbb7f
f7b9999999999b7f
f7b99bb99bb99b7f
f7b9bbbbbbbb9b7f
f7b99bb99bb99b7f
f7b9999999999b7f
f7bbbbbbbbbbbb7f
f77777777777777f
ffffffffffffffff
]=]

print('Preparing '..tostring((function()local n=0;for _ in pairs(pages)do n=n+1 end;return n end)())..' wiki pages...')
local current=net.call('web','getSite',{domain=domain})
if current and current.site and current.site.draft and current.site.draft.pages then for path in pairs(current.site.draft.pages)do if not pages[path]then net.call('web','deletePage',{domain=domain,path=path})end end end
local order={};for path in pairs(pages)do order[#order+1]=path end;table.sort(order)
for _,path in ipairs(order)do write(('Saving %-26s'):format(path));local p,e=net.call('web','savePage',{domain=domain,path=path,page=pages[path]});if not p then print(' FAIL');die(e)end;print(' OK')end
write('Saving Wiki scripts... ');call('web','saveScripts',{domain=domain,clientScript=clientScript,serverScript=serverScript});print('OK')
write('Uploading logo... ');call('web','putAsset',{domain=domain,name='spawnnet_logo',mime='image/nfp',data=logo});print('OK')
call('web','settings',{domain=domain,title='SpawnNet Wiki',description='Complete SpawnNet 2.1 manual and escalating interactive showcase labs.',tags={'spawnnet','wiki','docs','api','studio','networks','jobs','telemetry','labs'}})
write('Publishing... ');call('web','publish',{domain=domain,note='SpawnNet 2.1 RC6 showcase labs overhaul'});print('OK')
print();term.setTextColor(C.lime);print('WIKI PUBLISHED');term.setTextColor(C.white);print('Open: spn://'..domain);print('Start: spn://'..domain..'/start');print('First demo: spn://'..domain..'/labs/game');print('Developer labs: spn://'..domain..'/labs')
