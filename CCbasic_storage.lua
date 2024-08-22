-- Modular Storage System Program
-- Written for Minecraft 1.12.2 with ComputerCraft

local storageDB = {}
local itemDB = {}

-- Scan and wrap all connected chests
function scanInventories()
    local peripherals = peripheral.getNames()
    for _, name in ipairs(peripherals) do
        if peripheral.getType(name) == "minecraft:chest" then
            storageDB[name] = peripheral.wrap(name)
        end
    end
end

-- Populate database with item details
function updateDatabase()
    itemDB = {} -- Clear the database before scanning
    for name, chest in pairs(storageDB) do
        local items = chest.list()
        for slot, item in pairs(items) do
            if not itemDB[item.name] then
                itemDB[item.name] = {}
            end
            table.insert(itemDB[item.name], {peripheral = name, slot = slot, count = item.count})
        end
    end
end

-- Display all items in the storage system
function displayItems()
    print("Items in Storage:")
    for itemName, itemDetails in pairs(itemDB) do
        local total = 0
        for _, detail in ipairs(itemDetails) do
            total = total + detail.count
        end
        print(itemName .. ": " .. total .. " items")
    end
end

-- Retrieve an item from the storage system
function retrieveItem(itemName, count)
    if not itemDB[itemName] then
        print("Item not found in storage")
        return
    end

    local needed = count
    for _, detail in ipairs(itemDB[itemName]) do
        local chest = storageDB[detail.peripheral]
        local retrieved = math.min(needed, detail.count)
        chest.pushItems(peripheral.getName(), detail.slot, retrieved)
        needed = needed - retrieved
        if needed <= 0 then break end
    end
end

-- Main program loop
function main()
    scanInventories()
    updateDatabase()

    while true do
        print("1. View Items")
        print("2. Retrieve Item")
        print("3. Deposit Item")
        print("4. Refresh Database")
        print("Enter choice:")
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
            print("Deposit items by placing them in the turtle's inventory.")
            -- Placeholder: If you're using a turtle, the deposit function would go here
        elseif choice == "4" then
            updateDatabase()
            print("Database refreshed.")
        else
            print("Invalid choice.")
        end
    end
end

-- Start the main loop
main()
