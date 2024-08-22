-- Modular Storage System with Enhanced Functionality
-- Written for Minecraft 1.12.2 with ComputerCraft

local storageDB = {}
local itemDB = {}
local itemsPerPage = 10
local currentPage = 1
local filteredItems = {}
local filterMode = "none" -- Options: "none", "amount"

-- Scan and wrap all connected inventories
function scanInventories()
    local peripherals = peripheral.getNames()
    for _, name in ipairs(peripherals) do
        if peripheral.getType(name) == "minecraft:chest" or peripheral.getType(name) == "inventory" then
            storageDB[name] = peripheral.wrap(name)
        end
    end
end

-- Populate database with item details
function updateDatabase()
    itemDB = {} -- Clear the database before scanning
    for name, inventory in pairs(storageDB) do
        local items = inventory.list()
        for slot, item in pairs(items) do
            if not itemDB[item.name] then
                itemDB[item.name] = {count = 0, locations = {}}
            end
            itemDB[item.name].count = itemDB[item.name].count + item.count
            table.insert(itemDB[item.name].locations, {peripheral = name, slot = slot, count = item.count})
        end
    end
end

-- Apply filtering and sorting based on the mode
function applyFilter()
    filteredItems = {}

    for itemName, itemDetails in pairs(itemDB) do
        table.insert(filteredItems, {name = itemName, count = itemDetails.count})
    end

    if filterMode == "amount" then
        table.sort(filteredItems, function(a, b) return a.count > b.count end)
    end
end

-- Display a specific page of items
function displayPage(page)
    term.clear()
    term.setCursorPos(1, 1)
    print("Items in Storage (Page " .. page .. "):")
    
    local startIdx = (page - 1) * itemsPerPage + 1
    local endIdx = math.min(startIdx + itemsPerPage - 1, #filteredItems)
    
    for i = startIdx, endIdx do
        local item = filteredItems[i]
        print(i .. ". " .. item.name .. ": " .. item.count .. " items")
    end

    print("\nPress N for Next, P for Previous")
    print("F to Filter, R to Refresh, Q to Quit")
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

-- Handle user input for page navigation and filtering
function handleUserInput()
    while true do
        local event, key = os.pullEvent("key")

        if key == keys.n and currentPage * itemsPerPage < #filteredItems then
            currentPage = currentPage + 1
            displayPage(currentPage)
        elseif key == keys.p and currentPage > 1 then
            currentPage = currentPage - 1
            displayPage(currentPage)
        elseif key == keys.f then
            print("Select Filter: 1. None, 2. Amount (Most First)")
            local choice = tonumber(read())
            if choice == 1 then
                filterMode = "none"
            elseif choice == 2 then
                filterMode = "amount"
            end
            applyFilter()
            currentPage = 1
            displayPage(currentPage)
        elseif key == keys.r then
            updateDatabase()
            applyFilter()
            currentPage = 1
            displayPage(currentPage)
        elseif key == keys.q then
            return
        end
    end
end

-- Main program loop
function main()
    scanInventories()
    updateDatabase()
    applyFilter()
    displayPage(currentPage)
    handleUserInput()
end

-- Start the main loop
main()
