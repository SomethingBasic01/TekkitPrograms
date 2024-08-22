-- Modular Storage System with User-defined Item Naming
-- Author: OpenAI ChatGPT

local storageDB = {}
local itemDB = {}
local userNamesMap = {}

-- File to store the user-defined names
local nameMapFile = "userNamesMap.lua"

-- Load existing user-defined names from file
local function loadNameMap()
    if fs.exists(nameMapFile) then
        local handle = fs.open(nameMapFile, "r")
        local data = handle.readAll()
        handle.close()
        local func = loadstring("return " .. data)
        if func then
            userNamesMap = func()
            print("User-defined names loaded successfully.")
        else
            print("Error loading user-defined names.")
        end
    else
        print("No existing user-defined names found. Starting fresh.")
    end
end

-- Save current user-defined names to file
local function saveNameMap()
    local handle = fs.open(nameMapFile, "w")
    handle.write(textutils.serialize(userNamesMap))
    handle.close()
    print("User-defined names saved successfully.")
end

-- Function to create a unique key based on name, damage, and NBT
local function createUniqueKey(item)
    local baseKey = item.name .. ":" .. (item.damage or 0)
    if item.nbt then
        baseKey = baseKey .. ":" .. textutils.serialize(item.nbt)
    end
    return baseKey
end

-- Function to get or assign a user-defined name for an item
local function getOrAssignUserName(item)
    local uniqueKey = createUniqueKey(item)
    if not userNamesMap[uniqueKey] then
        print("New item detected: " .. item.name)
        print("Please enter a name for this item:")
        local userName = read()
        userNamesMap[uniqueKey] = userName
        saveNameMap()
    end
    return userNamesMap[uniqueKey]
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

-- Function for the turtle to scan items and add them to the database
local function scanAndMapItems()
    for slot = 1, 16 do
        local item = turtle.getItemDetail(slot)
        if item then
            local userName = getOrAssignUserName(item)
            print("Scanned: " .. userName)
        else
            print("Slot " .. slot .. " is empty.")
        end
    end
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
            local userName = getOrAssignUserName(item)
            if not itemDB[userName] then
                itemDB[userName] = item.count
            else
                itemDB[userName] = itemDB[userName] + item.count
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

-- Main program loop
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
            print("Waiting for network to pull items...")
            sleep(10)  -- Adjust this if needed to give the network time to pull items
            updateDatabase()
            displayItems()
        end
        sleep(5) -- Update interval in seconds
    end
end

-- Run the program
main()
