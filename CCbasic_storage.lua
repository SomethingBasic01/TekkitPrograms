-- Modular Storage System with Dispenser as Deposit Chest

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

-- Function to find an appropriate slot for the item in the storage system
local function findSlotForItem(chest, item)
    local items = chest.list()
    for slot, storedItem in pairs(items) do
        if storedItem.name == item.name and storedItem.damage == item.damage and (not storedItem.nbt or storedItem.nbt == item.nbt) then
            return slot
        end
    end
    for slot = 1, chest.size() do
        if not items[slot] then
            return slot
        end
    end
    return nil
end

-- Function to pull items from the dispenser and place them in the storage network
local function pullItemsFromDispenser(dispenser)
    local items = dispenser.list()
    for slot, item in pairs(items) do
        local placed = false
        for _, chest in pairs(storageDB) do
            local targetSlot = findSlotForItem(chest, item)
            if targetSlot then
                dispenser.pushItems(peripheral.getName(chest), slot, item.count, targetSlot)
                placed = true
                break
            end
        end
        if not placed then
            print("No available slots for " .. (userNamesMap[createUniqueKey(item)] or item.name) .. ". More storage needed!")
            return false
        end
    end
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
        local dispenser = nil
        for _, name in ipairs(peripheral.getNames()) do
            if peripheral.getType(name) == "minecraft:dispenser" then
                dispenser = peripheral.wrap(name)
                break
            end
        end
        if dispenser then
            local success = pullItemsFromDispenser(dispenser)
            if success then
                updateDatabase()
                displayItems()
            end
        else
            print("Dispenser not found!")
        end
        sleep(5) -- Update interval in seconds
    end
end

-- Run the program
main()
