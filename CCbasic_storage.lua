-- Modular Storage System with Enhanced Debugging and Safeguards

local storageDB = {}
local itemDB = {}
local itemsPerPage = 10
local currentPage = 1
local filteredItems = {}

-- Scan and wrap all connected inventories
function scanInventories()
    print("Scanning inventories...")
    local peripherals = peripheral.getNames()
    for _, name in ipairs(peripherals) do
        print("Checking peripheral: " .. name)
        local p = peripheral.wrap(name)
        if p and p.size then
            storageDB[name] = p
            print("Found inventory: " .. name)
        end
    end
    print("Finished scanning inventories.")
end

-- Populate database with item details
function updateDatabase()
    print("Updating database...")
    itemDB = {} -- Clear the database before scanning
    for name, inventory in pairs(storageDB) do
        print("Scanning inventory: " .. name)
        for slot = 1, inventory.size() do
            local item = inventory.getItem(slot)
            if item then
                local count = item.count or 0 -- Safeguard: Default to 0 if count is nil
                print("Item found: " .. (item.name or "unknown item") .. " x " .. count .. " in slot " .. slot)
                if not itemDB[item.name] then
                    itemDB[item.name] = {count = 0, locations = {}}
                end
                itemDB[item.name].count = itemDB[item.name].count + count
                table.insert(itemDB[item.name].locations, {peripheral = name, slot = slot, count = count})
            else
                print("Slot " .. slot .. " is empty.")
            end
        end
    end
    print("Finished updating database. Items found:")
    for itemName, itemDetails in pairs(itemDB) do
        print(itemName .. ": " .. itemDetails.count .. " items")
    end
end

-- Display items in storage
function displayItems()
    term.clear()
    term.setCursorPos(1, 1)
    print("Items in Storage:")
    
    local hasItems = false
    for itemName, itemDetails in pairs(itemDB) do
        print(itemName .. ": " .. itemDetails.count .. " items")
        hasItems = true
    end
    
    if not hasItems then
        print("No items found in storage.")
    end
end

-- Handle user input for viewing, retrieving, and depositing items
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
        else
            print("Invalid choice.")
        end
    end
end

-- Main program loop
function main()
    print("Starting program...")
    scanInventories()
    updateDatabase()
    handleUserInput()
end

-- Start the main loop
main()
