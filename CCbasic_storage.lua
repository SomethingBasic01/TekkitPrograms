-- Modular Storage System with Turtle Scanning and Deposit Chest Integration
-- Author: OpenAI ChatGPT
-- Description: This program scans items from the turtle's inventory,
-- updates a name mapping, deposits items into a chest below, and displays
-- aggregated inventory from all connected chests.

-- Define global tables
local storageDB = {}
local itemDB = {}
local damageToNameMap = {}

-- File to store the name mappings
local nameMapFile = "nameMap.lua"

-- Load existing name mappings from file
local function loadNameMap()
    if fs.exists(nameMapFile) then
        local handle = fs.open(nameMapFile, "r")
        local data = handle.readAll()
        handle.close()
        local func = loadstring("return " .. data)
        if func then
            damageToNameMap = func()
            print("Name mappings loaded successfully.")
        else
            print("Error loading name mappings.")
        end
    else
        print("No existing name mappings found. Starting fresh.")
    end
end

-- Save current name mappings to file
local function saveNameMap()
    local handle = fs.open(nameMapFile, "w")
    handle.write(textutils.serialize(damageToNameMap))
    handle.close()
    print("Name mappings saved successfully.")
end

-- Scan and wrap all connected inventories
local function scanInventories()
    storageDB = {}
    local peripherals = peripheral.getNames()
    for _, name in ipairs(peripherals) do
        local p = peripheral.wrap(name)
        if p and p.list then
            storageDB[name] = p
        end
    end
    print("Inventories scanned: " .. tostring(#peripherals))
end

-- Function for the turtle to scan items and update the name map
local function scanAndMapItems()
    for slot = 1, 16 do
        local item = turtle.getItemDetail(slot)
        if item then
            local key = item.name .. ":" .. (item.damage or 0)
            if not damageToNameMap[key] then
                -- Attempt to get a readable name, defaulting to item.name
                local displayName = item.displayName or item.name
                damageToNameMap[key] = displayName
                print("Mapped: " .. key .. " => " .. displayName)
            end
        end
    end
    saveNameMap()
end

-- Function for the turtle to deposit items into the chest below
local function depositItems()
    for slot = 1, 16 do
        turtle.select(slot)
        if turtle.getItemCount(slot) > 0 then
            local success = turtle.dropDown()
            if not success then
                print("Failed to deposit items from slot " .. slot .. ". Is there a chest below?")
                return false
            end
        end
    end
    turtle.select(1) -- Reset to slot 1
    print("All items deposited successfully.")
    return true
end

-- Update the item database by aggregating items from all inventories
local function updateDatabase()
    itemDB = {}
    for _, chest in pairs(storageDB) do
        local items = chest.list()
        for slot, item in pairs(items) do
            local key = item.name .. ":" .. (item.damage or 0)
            local friendlyName = damageToNameMap[key] or item.name
            if not itemDB[friendlyName] then
                itemDB[friendlyName] = item.count
            else
                itemDB[friendlyName] = itemDB[friendlyName] + item.count
            end
        end
    end
end

-- Display the aggregated items neatly on the terminal
local function displayItems()
    term.clear()
    term.setCursorPos(1, 1)
    print("=== Combined Items in Storage ===")
    local itemList = {}
    for name, count in pairs(itemDB) do
        table.insert(itemList, {name = name, count = count})
    end
    table.sort(itemList, function(a, b) return a.name < b.name end)
    for _, item in ipairs(itemList) do
        print(string.format("%-30s : %d", item.name, item.count))
    end
end

-- Main program loop without 'goto'
local function main()
    loadNameMap()
    scanInventories()
    while true do
        scanAndMapItems()
        local depositSuccess = depositItems()
        if not depositSuccess then
            print("Waiting for Deposit Chest to be available...")
            sleep(5)
        else
            updateDatabase()
            displayItems()
        end
        sleep(5) -- Update interval in seconds
    end
end

-- Run the program
main()
