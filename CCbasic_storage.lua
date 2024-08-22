-- Modular Storage System with Turtle Scanning and Direct Display Name Usage
-- Author: OpenAI ChatGPT
-- Description: This program scans items from the turtle's inventory,
-- uses their display name directly if available, deposits items into a chest below,
-- and displays aggregated inventory from all connected chests.

local storageDB = {}
local itemDB = {}

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
            local friendlyName = item.displayName or item.name
            print("Scanned: " .. friendlyName)
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
            local friendlyName = item.displayName or item.name
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

-- Main program loop
local function main()
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
