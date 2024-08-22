-- Simple Modular Storage System - Final Direct Fix

local storageDB = {}
local itemDB = {}

-- Scan and wrap all connected inventories
function scanInventories()
    local peripherals = peripheral.getNames()
    for _, name in ipairs(peripherals) do
        local p = peripheral.wrap(name)
        if p and p.size then
            storageDB[name] = p
        end
    end
end

-- Populate database with item details
function updateDatabase()
    itemDB = {}
    for name, inventory in pairs(storageDB) do
        for slot = 1, inventory.size() do
            local item = inventory.getItem(slot)
            if item and item.name and item.count then -- Check for nil values
                local itemName = item.name
                local itemCount = item.count

                if not itemDB[itemName] then
                    itemDB[itemName] = {count = 0, locations = {}}
                end
                itemDB[itemName].count = itemDB[itemName].count + itemCount
                table.insert(itemDB[itemName].locations, {peripheral = name, slot = slot, count = itemCount})
            end
        end
    end
end

-- Display items in storage
function displayItems()
    term.clear()
    term.setCursorPos(1, 1)
    print("Items in Storage:")
    for itemName, itemDetails in pairs(itemDB) do
        print(itemName .. ": " .. itemDetails.count .. " items")
    end
end

-- Handle user input
function handleUserInput()
    while true do
        print("\n1. View Items")
        print("R to Refresh, Q to Quit")
        local choice = read()

        if choice == "1" then
            displayItems()
        elseif choice == "r" then
            updateDatabase()
            print("Database refreshed.")
        elseif choice:lower() == "q" then
            return
        end
    end
end

-- Main program loop
function main()
    scanInventories()
    updateDatabase()
    handleUserInput()
end

main()
