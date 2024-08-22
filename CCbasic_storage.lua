-- Modular Storage System with Deposit Functionality
-- Written for Minecraft 1.12.2 with ComputerCraft

local storageDB = {}
local itemDB = {}
local itemsPerPage = 10
local currentPage = 1
local filteredItems = {}

-- Scan and wrap all connected inventories
function scanInventories()
    local peripherals = peripheral.getNames()
    for _, name in ipairs(peripherals) do
        -- Attempt to wrap the peripheral and check if it has an inventory size
        local p = peripheral.wrap(name)
        if p and p.size then
            storageDB[name] = p
        end
    end
end

-- Populate database with item details
function updateDatabase()
    itemDB = {} -- Clear the database before scanning
    for name, inventory in pairs(storageDB) do
        for slot = 1, inventory.size() do
            local item = inventory.getItem(slot)
            if item and item.name then
                if not itemDB[item.name] then
                    itemDB[item.name] = {count = 0, locations = {}}
                end
                itemDB[item.name].count = itemDB[item.name].count + item.count
                table.insert(itemDB[item.name].locations, {peripheral = name, slot = slot, count = item.count})
            end
        end
    end
end

-- Display a specific page of items
function displayItems()
    term.clear()
    term.setCursorPos(1, 1)
    print("Items in Storage:")
    
    for itemName, itemDetails in pairs(itemDB) do
        print(itemName .. ": " .. itemDetails.count .. " items")
    end
end

-- Retrieve an item from the storage system
function retrieveItem(itemName, count)
    if not itemDB[itemName] then
        print("Item not found in storage")
        return
    end

    local needed = count
    for _, detail in ipairs(itemDB[itemName].locations) do
        local inventory = storageDB[detail.peripheral]
        local retrieved = math.min(needed, detail.count)
        inventory.pushItems(peripheral.getName(), detail.slot, retrieved)
        needed = needed - retrieved
        if needed <= 0 then break end
    end
end

-- Deposit an item from the turtle into the storage system
function depositItems()
    for i = 1, 16 do
        local item = turtle.getItemDetail(i)
        if item then
            local count = item.count
            for name, inventory in pairs(storageDB) do
                count = count - inventory.pullItems(peripheral.getName(), i, count)
                if count <= 0 then break end
            end
        end
    end
end

-- Handle user input for viewing, retrieving, and depositing items
function handleUserInput()
    while true do
        print("\n1. View Items")
        print("2. Retrieve Item")
        print("3. Deposit Items")
        print("R to Refresh, Q to Quit")
        local choice = read()

        if choice == "1" then
            displayItems()
        elseif choice == "2" then
            print("Enter item name:")
            local itemName = read()
            print("Enter quantity:")
            local count = tonumber(read())
            retrieveItem(itemName, count)
        elseif choice == "3" then
            depositItems()
            print("Items deposited.")
        elseif choice:lower() == "r" then
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
    scanInventories()
    updateDatabase()
    handleUserInput()
end

-- Start the main loop
main()
