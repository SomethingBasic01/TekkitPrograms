-- Modular Storage System with Scrolling and Filtering
-- Written for Minecraft 1.12.2 with ComputerCraft

local storageDB = {}
local itemDB = {}
local itemsPerPage = 10
local currentPage = 1
local filteredItems = {}
local filterMode = "none" -- Options: "none", "amount", "mod"

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

-- Apply filtering
function applyFilter()
    filteredItems = {}

    for itemName, itemDetails in pairs(itemDB) do
        local total = 0
        for _, detail in ipairs(itemDetails) do
            total = total + detail.count
        end

        if filterMode == "none" then
            table.insert(filteredItems, {name = itemName, count = total})
        elseif filterMode == "amount" and total >= 10 then -- Example: Filter by items with >= 10 count
            table.insert(filteredItems, {name = itemName, count = total})
        elseif filterMode == "mod" and string.match(itemName, "modid") then -- Example: Filter by modid
            table.insert(filteredItems, {name = itemName, count = total})
        end
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
            print("Select Filter: 1. None, 2. Amount >= 10, 3. By Mod")
            local choice = tonumber(read())
            if choice == 1 then
                filterMode = "none"
            elseif choice == 2 then
                filterMode = "amount"
            elseif choice == 3 then
                filterMode = "mod"
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
