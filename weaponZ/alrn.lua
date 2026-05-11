# alrn.lua

```lua
--[[
ALRN - Autonomous Logistics & Resource Network
CC:Tweaked 1.12.2
Single-file bounded industrial colony system.

INSTALL:
1. Paste this file as: /alrn.lua
2. Ensure modem is attached/equipped.
3. Run:

    alrn init

This system is intentionally bounded:
- No stealth/evasion logic
- No anti-player attacks
- No hidden persistence
- No uncontrolled replication

]]

--------------------------------------------------
-- CONFIG
--------------------------------------------------

local CONFIG = {
    VERSION = "1.0.0",
    PROTOCOL = "ALRN_V1",

    HEARTBEAT_INTERVAL = 5,
    NODE_TIMEOUT = 20,
    SAVE_INTERVAL = 15,

    MAX_TOTAL_UNITS = 64,
    MAX_HARVESTERS = 24,
    MAX_FORGES = 8,
    MAX_RELAYS = 12,
    MAX_NEXUS = 4,

    MAX_RADIUS = 4000,

    TARGET_RESOURCES = {
        ["minecraft:coal"] = 2048,
        ["minecraft:iron_ingot"] = 1024,
        ["minecraft:redstone"] = 512
    },

    TRUSTED_OPERATORS = {
        ["PlayerName"] = true
    }
}

--------------------------------------------------
-- GLOBAL STATE
--------------------------------------------------

local STATE = {
    initialized = false,
    role = "genesis",
    nodeId = os.getComputerID(),
    label = nil,

    position = {
        x = 0,
        y = 0,
        z = 0,
        facing = 0
    },

    resources = {},
    tasks = {},
    nodes = {},
    votes = {},
    snapshots = {},

    networkKey = nil,

    fleet = {
        total = 0,
        harvesters = 0,
        forges = 0,
        relays = 0,
        nexus = 0
    }
}

--------------------------------------------------
-- UTILITY
--------------------------------------------------

local function saveState()
    if not fs.exists("/alrn") then
        fs.makeDir("/alrn")
    end

    local h = fs.open("/alrn/state.tbl", "w")
    h.write(textutils.serialize(STATE))
    h.close()
end

local function loadState()
    if not fs.exists("/alrn/state.tbl") then
        return false
    end

    local h = fs.open("/alrn/state.tbl", "r")
    local data = h.readAll()
    h.close()

    local ok, result = pcall(textutils.unserialize, data)

    if ok and result then
        STATE = result
        return true
    end

    return false
end

local function log(...)
    print("[ALRN]", ...)
end

local function now()
    return os.epoch("utc")
end

--------------------------------------------------
-- MODEM / NETWORK
--------------------------------------------------

local function openModem()
    for _, side in ipairs(rs.getSides()) do
        if peripheral.getType(side) == "modem" then
            rednet.open(side)
            return true
        end
    end

    return false
end

local function packet(kind, payload)
    return {
        protocol = CONFIG.PROTOCOL,
        kind = kind,
        from = STATE.nodeId,
        time = now(),
        payload = payload or {},
        key = STATE.networkKey
    }
end

local function broadcast(kind, payload)
    rednet.broadcast(packet(kind, payload), CONFIG.PROTOCOL)
end

local function send(id, kind, payload)
    rednet.send(id, packet(kind, payload), CONFIG.PROTOCOL)
end

--------------------------------------------------
-- INVENTORY
--------------------------------------------------

local function inventorySummary()
    local out = {}

    if not turtle then
        return out
    end

    for slot = 1, 16 do
        local d = turtle.getItemDetail(slot)

        if d then
            out[d.name] = (out[d.name] or 0) + d.count
        end
    end

    return out
end

local function countItem(name)
    local count = 0

    for slot = 1, 16 do
        local d = turtle.getItemDetail(slot)

        if d and d.name == name then
            count = count + d.count
        end
    end

    return count
end

--------------------------------------------------
-- MOVEMENT
--------------------------------------------------

local function refuel()
    if turtle.getFuelLevel() == "unlimited" then
        return true
    end

    if turtle.getFuelLevel() > 100 then
        return true
    end

    for slot = 1, 16 do
        turtle.select(slot)

        if turtle.refuel(1) then
            return true
        end
    end

    return false
end

local function forward()
    refuel()

    while turtle.detect() do
        turtle.dig()
        sleep(0.2)
    end

    if turtle.forward() then
        local f = STATE.position.facing

        if f == 0 then
            STATE.position.z = STATE.position.z - 1
        elseif f == 1 then
            STATE.position.x = STATE.position.x + 1
        elseif f == 2 then
            STATE.position.z = STATE.position.z + 1
        elseif f == 3 then
            STATE.position.x = STATE.position.x - 1
        end

        return true
    end

    return false
end

local function turnLeft()
    turtle.turnLeft()
    STATE.position.facing = (STATE.position.facing + 3) % 4
end

local function turnRight()
    turtle.turnRight()
    STATE.position.facing = (STATE.position.facing + 1) % 4
end

--------------------------------------------------
-- TASK SYSTEM
--------------------------------------------------

local function addTask(role, action, payload, priority)
    local id = tostring(now()) .. "-" .. tostring(math.random(1000, 9999))

    STATE.tasks[id] = {
        id = id,
        role = role,
        action = action,
        payload = payload or {},
        priority = priority or 1,
        status = "open",
        created = now()
    }

    broadcast("task", STATE.tasks[id])

    saveState()
end

local function nextTask(role)
    local best = nil

    for _, task in pairs(STATE.tasks) do
        if task.status == "open" and task.role == role then
            if not best or task.priority > best.priority then
                best = task
            end
        end
    end

    return best
end

--------------------------------------------------
-- HEARTBEAT
--------------------------------------------------

local function heartbeatLoop()
    while true do
        STATE.nodes[STATE.nodeId] = {
            id = STATE.nodeId,
            role = STATE.role,
            lastSeen = now(),
            active = true
        }

        broadcast("heartbeat", {
            role = STATE.role,
            resources = inventorySummary()
        })

        sleep(CONFIG.HEARTBEAT_INTERVAL)
    end
end

--------------------------------------------------
-- RECEIVER
--------------------------------------------------

local function receiverLoop()
    while true do
        local sender, msg = rednet.receive(CONFIG.PROTOCOL, 2)

        if sender and type(msg) == "table" then
            if msg.key == STATE.networkKey then
                if msg.kind == "heartbeat" then
                    STATE.nodes[sender] = {
                        id = sender,
                        role = msg.payload.role,
                        active = true,
                        lastSeen = now()
                    }
                elseif msg.kind == "task" then
                    local task = msg.payload
                    STATE.tasks[task.id] = task
                end
            end
        end
    end
end

--------------------------------------------------
-- RESOURCE REPORTING
--------------------------------------------------

local function resourceLoop()
    while true do
        local inv = inventorySummary()

        for item, count in pairs(inv) do
            STATE.resources[item] = (STATE.resources[item] or 0) + count
        end

        saveState()

        sleep(CONFIG.SAVE_INTERVAL)
    end
end

--------------------------------------------------
-- NEXUS ROLE
--------------------------------------------------

local function nexusLoop()
    while true do
        local coal = STATE.resources["minecraft:coal"] or 0
        local iron = STATE.resources["minecraft:iron_ingot"] or 0

        if coal < CONFIG.TARGET_RESOURCES["minecraft:coal"] then
            addTask("harvester", "mine", {
                target = "coal"
            }, 5)
        end

        if iron < CONFIG.TARGET_RESOURCES["minecraft:iron_ingot"] then
            addTask("harvester", "mine", {
                target = "iron"
            }, 5)
        end

        sleep(10)
    end
end

--------------------------------------------------
-- HARVESTER ROLE
--------------------------------------------------

local function mineBranch(length)
    local moved = 0

    for i = 1, length do
        if forward() then
            moved = moved + 1

            turtle.digUp()
            turtle.digDown()
        end
    end

    turnLeft()
    turnLeft()

    for i = 1, moved do
        turtle.forward()
    end

    turnLeft()
    turnLeft()
end

local function harvesterLoop()
    while true do
        local task = nextTask("harvester")

        if task then
            task.status = "claimed"

            if task.action == "mine" then
                mineBranch(32)
            end

            task.status = "done"

            saveState()
        end

        sleep(2)
    end
end

--------------------------------------------------
-- FORGE ROLE
--------------------------------------------------

local function craftItem()
    turtle.craft()
end

local function forgeLoop()
    while true do
        local task = nextTask("forge")

        if task then
            task.status = "claimed"

            if task.action == "craft" then
                craftItem()
            end

            task.status = "done"

            saveState()
        end

        sleep(2)
    end
end

--------------------------------------------------
-- SAPPER ROLE
--------------------------------------------------

local function digRoom(width, height, depth)
    for z = 1, depth do
        for y = 1, height do
            for x = 1, width - 1 do
                turtle.dig()
                turtle.forward()
            end

            if y < height then
                turtle.digUp()
                turtle.up()
            end
        end
    end
end

local function sapperLoop()
    while true do
        local task = nextTask("sapper")

        if task then
            task.status = "claimed"

            if task.action == "build_room" then
                digRoom(5, 3, 5)
            end

            task.status = "done"
        end

        sleep(2)
    end
end

--------------------------------------------------
-- GENESIS
--------------------------------------------------

local function bootstrapRoom()
    for i = 1, 8 do
        forward()
    end

    digRoom(5, 3, 5)
end

local function bootstrapMining()
    while countItem("minecraft:coal") < 32 do
        mineBranch(16)
    end
end

local function initializeColony()
    if not openModem() then
        error("No modem attached")
    end

    STATE.networkKey = tostring(math.random(100000, 999999))

    STATE.initialized = true
    STATE.role = "nexus"
    STATE.label = "ALRN-" .. tostring(STATE.nodeId)

    os.setComputerLabel(STATE.label)

    bootstrapRoom()
    bootstrapMining()

    addTask("sapper", "build_room", {}, 3)
    addTask("harvester", "mine", {}, 5)

    saveState()

    log("ALRN initialized")
end

--------------------------------------------------
-- COMMANDS
--------------------------------------------------

local function status()
    print(textutils.serialize({
        role = STATE.role,
        nodes = STATE.nodes,
        resources = STATE.resources,
        fleet = STATE.fleet
    }))
end

local function runRole()
    parallel.waitForAny(
        heartbeatLoop,
        receiverLoop,
        resourceLoop,

        function()
            if STATE.role == "nexus" then
                nexusLoop()
            elseif STATE.role == "harvester" then
                harvesterLoop()
            elseif STATE.role == "forge" then
                forgeLoop()
            elseif STATE.role == "sapper" then
                sapperLoop()
            end
        end
    )
end

--------------------------------------------------
-- MAIN
--------------------------------------------------

local args = {...}

math.randomseed(os.time())

loadState()

local cmd = args[1]

if cmd == "init" then
    initializeColony()
    runRole()

elseif cmd == "run" then
    runRole()

elseif cmd == "status" then
    status()

else
    print("ALRN")
    print("Usage:")
    print("  alrn init")
    print("  alrn run")
    print("  alrn status")
end
```
