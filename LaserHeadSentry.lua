------------------------------------------------
-- Neural Interface & Module Checks
------------------------------------------------
local modules = peripheral.find("neuralInterface")
if not modules then
    error("Must have a neural interface", 0)
end

if not modules.hasModule("plethora:laser") then
    error("Cannot find laser", 0)
end
if not modules.hasModule("plethora:sensor") then
    error("Cannot find entity sensor", 0)
end

------------------------------------------------
-- Global Variables & Utility Functions
------------------------------------------------
local running = true          -- Global flag for stopping loops
local entityScroll = 0        -- Scroll offset for the tracked entity list
local buttons = {}            -- Stores clickable button definitions

-- Targeting mode options and index (for cycling)
local targetingModes = { "closest", "furthest", "random" }
local currentTargetingModeIndex = 1

local function degrees(radians)
    return math.deg(radians)
end

local function getDistance(entity)
    return math.sqrt(entity.x^2 + entity.y^2 + entity.z^2)
end

local function buildLookup(entities)
    local lookup = {}
    for i = 1, #entities do
        lookup[entities[i]] = true
    end
    return lookup
end

------------------------------------------------
-- Configuration Module
------------------------------------------------
local Config = {}
Config.filename = "sentry_config"

function Config.save(isSentryOn, trackedEntities)
    local config = {
        isSentryOn = isSentryOn,
        trackedEntities = trackedEntities
    }
    local file = fs.open(Config.filename, "w")
    if not file then
        print("Error: Could not open file for writing!")
        return
    end
    file.write(textutils.serialize(config))
    file.close()
    print("Configuration saved.")
end

function Config.load()
    if fs.exists(Config.filename) then
        local file = fs.open(Config.filename, "r")
        if not file then
            print("Error: Could not open file for reading!")
            return nil
        end
        local data = file.readAll()
        file.close()
        local config = textutils.unserialize(data)
        if type(config) == "table" and config.trackedEntities and config.isSentryOn ~= nil then
            print("Configuration loaded.")
            return config
        else
            print("Error: Invalid configuration file.")
        end
    else
        print("No configuration file found.")
    end
    return nil
end

------------------------------------------------
-- Sentry Module
------------------------------------------------
local Sentry = {}
Sentry.isSentryOn = true
Sentry.trackedEntities = { "corruption_avatar", "Creeper", "Zombie", "Skeleton" }
Sentry.mobLookup = buildLookup(Sentry.trackedEntities)
Sentry.targetingMode = targetingModes[currentTargetingModeIndex]  -- default "closest"
Sentry.powerSetting = 5  -- Default laser power

function Sentry.addEntity(entity)
    if not Sentry.mobLookup[entity] then
        table.insert(Sentry.trackedEntities, entity)
        Sentry.mobLookup[entity] = true
    end
end

function Sentry.removeEntity(entity)
    if Sentry.mobLookup[entity] then
        for i = #Sentry.trackedEntities, 1, -1 do
            if Sentry.trackedEntities[i] == entity then
                table.remove(Sentry.trackedEntities, i)
            end
        end
        Sentry.mobLookup[entity] = nil
    end
end

function Sentry.toggle()
    Sentry.isSentryOn = not Sentry.isSentryOn
end

------------------------------------------------
-- Laser Firing & Targeting
------------------------------------------------
local function fire(entity)
    local x, y, z = entity.x, entity.y, entity.z
    local pitch = -math.atan2(y, math.sqrt(x*x + z*z))
    local yaw = math.atan2(-x, z)
    modules.fire(degrees(yaw), degrees(pitch), Sentry.powerSetting)
    sleep(0.2)
end

local function chooseTarget(candidates, mode)
    if mode == "closest" then
        table.sort(candidates, function(a, b)
            return getDistance(a) < getDistance(b)
        end)
        return candidates[1]
    elseif mode == "furthest" then
        table.sort(candidates, function(a, b)
            return getDistance(a) > getDistance(b)
        end)
        return candidates[1]
    elseif mode == "random" then
        return candidates[math.random(1, #candidates)]
    else
        return candidates[1]
    end
end

local function checkAndAttack()
    while running do
        if Sentry.isSentryOn then
            local mobs = modules.sense()
            local candidates = {}
            for i = 1, #mobs do
                local mob = mobs[i]
                if Sentry.mobLookup[mob.name] then
                    table.insert(candidates, mob)
                end
            end

            if #candidates > 0 then
                local target = chooseTarget(candidates, Sentry.targetingMode)
                fire(target)
            else
                sleep(1)
            end
        else
            sleep(1)
        end
    end
end

------------------------------------------------
-- GUI Drawing Functions
------------------------------------------------
local function centerText(text, width)
    local space = math.floor((width - #text) / 2)
    return string.rep(" ", space) .. text
end

-- Draw header (rows 1-3)
local function drawHeader()
    local termWidth, _ = term.getSize()
    term.setBackgroundColor(colors.blue)
    term.setTextColor(colors.white)
    for y = 1, 3 do
        term.setCursorPos(1, y)
        term.clearLine()
    end
    term.setCursorPos(1, 1)
    term.write(centerText(" Sentry System ", termWidth))
    term.setCursorPos(1, 2)
    local statusStr = "Status: " .. (Sentry.isSentryOn and "ON" or "OFF") ..
                      "   Mode: " .. Sentry.targetingMode ..
                      "   Power: " .. Sentry.powerSetting
    term.write(centerText(statusStr, termWidth))
    term.setCursorPos(1, 3)
    term.write(string.rep("-", termWidth))
end

-- Draw the scrollable entity list in the middle.
local function drawEntityList()
    local termWidth, termHeight = term.getSize()
    local listTop = 4
    local listBottom = termHeight - 4  -- Reserve bottom 3 rows for buttons
    local listHeight = listBottom - listTop + 1

    -- Draw border around the list
    term.setBackgroundColor(colors.black)
    paintutils.drawLine(1, listTop, termWidth, listTop, colors.white)
    paintutils.drawLine(1, listBottom, termWidth, listBottom, colors.white)
    for y = listTop, listBottom do
        term.setCursorPos(1, y)
        term.write("|")
        term.setCursorPos(termWidth, y)
        term.write("|")
    end

    -- Draw list title
    local title = " Tracked Entities "
    term.setCursorPos(math.floor((termWidth - #title) / 2), listTop)
    term.write(title)

    -- Clear list area inside border (ensure background is black and text is white)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    for y = listTop + 1, listBottom - 1 do
        term.setCursorPos(2, y)
        term.write(string.rep(" ", termWidth - 2))
    end

    -- Display the tracked entities
    local maxVisible = listHeight - 2
    for i = 1, maxVisible do
        local idx = i + entityScroll
        if idx <= #Sentry.trackedEntities then
            term.setCursorPos(2, listTop + i)
            local text = "- " .. Sentry.trackedEntities[idx]
            if #text > termWidth - 2 then
                text = string.sub(text, 1, termWidth - 5) .. "..."
            end
            term.write(text)
        end
    end
end

-- Draw a bordered button with centered text.
local function drawButton(btn)
    for y = btn.y, btn.y + btn.height - 1 do
        term.setCursorPos(btn.x, y)
        term.setBackgroundColor(colors.lightGray)
        term.write(string.rep(" ", btn.width))
    end
    local textX = btn.x + math.floor((btn.width - #btn.text) / 2)
    local textY = btn.y + math.floor(btn.height / 2)
    term.setCursorPos(textX, textY)
    term.setTextColor(colors.black)
    term.write(btn.text)
    term.setTextColor(colors.white)
end

-- Draw the button area in three rows at the bottom.
local function drawButtons()
    local termWidth, termHeight = term.getSize()
    buttons = {}  -- Reset button list

    local btnMargin = 1
    -- We'll use the bottom 3 rows:
    local row1Y = termHeight - 3
    local row2Y = termHeight - 2
    local row3Y = termHeight - 1

    -- Helper to add a button.
    local function addButton(x, y, width, height, text, callback)
        local btn = { x = x, y = y, width = width, height = height, text = text, callback = callback }
        table.insert(buttons, btn)
        drawButton(btn)
    end

    -- --- Row 1: Primary actions ("Add", "Remove", "Toggle") ---
    local row1Buttons = { 
        { label = "Add", action = function()
            term.setCursorPos(1, termHeight)
            term.clearLine()
            write("Entity to add: ")
            local entity = read()
            Sentry.addEntity(entity)
            drawGUI()
        end},
        { label = "Remove", action = function()
            term.setCursorPos(1, termHeight)
            term.clearLine()
            write("Entity to remove: ")
            local entity = read()
            Sentry.removeEntity(entity)
            drawGUI()
        end},
        { label = "Toggle", action = function()
            Sentry.toggle()
            drawGUI()
        end}
    }
    local row1Count = #row1Buttons
    local btnWidth1 = math.floor((termWidth - ((row1Count + 1) * btnMargin)) / row1Count)
    local xPos = btnMargin
    for _, btnDef in ipairs(row1Buttons) do
        addButton(xPos, row1Y, btnWidth1, 1, btnDef.label, btnDef.action)
        xPos = xPos + btnWidth1 + btnMargin
    end

    -- --- Row 2: File actions ("Save", "Load", "Exit") ---
    local row2Buttons = {
        { label = "Save", action = function()
            Config.save(Sentry.isSentryOn, Sentry.trackedEntities)
            sleep(1)
            drawGUI()
        end},
        { label = "Load", action = function()
            local config = Config.load()
            if config then
                Sentry.isSentryOn = config.isSentryOn
                Sentry.trackedEntities = config.trackedEntities
                Sentry.mobLookup = buildLookup(Sentry.trackedEntities)
            end
            sleep(1)
            drawGUI()
        end},
        { label = "Exit", action = function() running = false end}
    }
    local row2Count = #row2Buttons
    local btnWidth2 = math.floor((termWidth - ((row2Count + 1) * btnMargin)) / row2Count)
    xPos = btnMargin
    for _, btnDef in ipairs(row2Buttons) do
        addButton(xPos, row2Y, btnWidth2, 1, btnDef.label, btnDef.action)
        xPos = xPos + btnWidth2 + btnMargin
    end

    -- --- Row 3: Settings ("Mode", "+Power", "-Power", "Up", "Down") ---
    local row3Buttons = {
        { label = "Mode", action = function()
            currentTargetingModeIndex = (currentTargetingModeIndex % #targetingModes) + 1
            Sentry.targetingMode = targetingModes[currentTargetingModeIndex]
            drawGUI()
        end},
        { label = "+Power", action = function()
            Sentry.powerSetting = Sentry.powerSetting + 1
            drawGUI()
        end},
        { label = "-Power", action = function()
            if Sentry.powerSetting > 1 then
                Sentry.powerSetting = Sentry.powerSetting - 1
            end
            drawGUI()
        end},
        { label = "Up", action = function()
            if entityScroll > 0 then
                entityScroll = entityScroll - 1
            end
            drawGUI()
        end},
        { label = "Down", action = function()
            local listTop = 4
            local listBottom = termHeight - 4
            local listHeight = listBottom - listTop + 1
            local maxVisible = listHeight - 2
            if entityScroll < (#Sentry.trackedEntities - maxVisible) then
                entityScroll = entityScroll + 1
            end
            drawGUI()
        end}
    }
    local row3Count = #row3Buttons
    local btnWidth3 = math.floor((termWidth - ((row3Count + 1) * btnMargin)) / row3Count)
    xPos = btnMargin
    for _, btnDef in ipairs(row3Buttons) do
        addButton(xPos, row3Y, btnWidth3, 1, btnDef.label, btnDef.action)
        xPos = xPos + btnWidth3 + btnMargin
    end
end

-- Redraw the entire GUI.
function drawGUI()
    term.setBackgroundColor(colors.black)
    term.clear()
    drawHeader()
    drawEntityList()
    drawButtons()
end

------------------------------------------------
-- GUI Event Loop
------------------------------------------------
local function guiLoop()
    drawGUI()
    while running do
        local event, p1, p2, p3 = os.pullEvent()
        if event == "mouse_click" then
            local _, x, y = p1, p2, p3
            for _, btn in ipairs(buttons) do
                if x >= btn.x and x < (btn.x + btn.width) and y >= btn.y and y < (btn.y + btn.height) then
                    btn.callback()
                    break
                end
            end
        elseif event == "term_resize" then
            drawGUI()
        end
    end
end

------------------------------------------------
-- Main Execution (Parallel)
------------------------------------------------
parallel.waitForAny(checkAndAttack, guiLoop)
