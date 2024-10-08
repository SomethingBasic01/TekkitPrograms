-- Modular Storage System attempt 27

local storageDB = {}
local itemDB = {}
local userNamesMap = {}
local itemsPerPage = 10  -- Number of items to display per page

local chestNames = {}
local dispenserName

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

-- Scan and wrap all connected inventories and the dispenser
local function scanInventories()
    storageDB = {}
    chestNames = {}
    dispenserName = nil

    local peripherals = peripheral.getNames()
    for _, name in ipairs(peripherals) do
        local p = peripheral.wrap(name)
        if p and p.list then
            if name:find("dispenser") then
                dispenserName = name
            else
                table.insert(chestNames, name)
                storageDB[name] = p
            end
        end
    end

    if dispenserName then
        print("Dispenser found: " .. dispenserName)
    else
        print("Dispenser not found.")
    end

    print("Inventories scanned: " .. tostring(#chestNames))
end

-- Function for the turtle to scan items and add them to the database
local function scanAndMapItems()
    term.clear()
    term.setCursorPos(1, 1)
    print("=== Label Items & Drop into Dispenser ===")
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

-- Function to drop items into the dispenser below the turtle
local function dropItemsIntoDispenser()
    for slot = 1, 16 do
        if turtle.getItemCount(slot) > 0 then
            turtle.select(slot)
            turtle.dropDown()
        end
    end
end

-- Update the item database by aggregating items from all inventories
local function updateDatabase()
    itemDB = {}  -- Clear the database before updating
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

    -- Debugging line to print the item database
    print("Item Database: " .. textutils.serialize(itemDB))
end

-- Display the aggregated items neatly on the terminal with pagination
local function displayItems()
    -- Convert itemDB to a list format for easier pagination
    local itemList = {}
    for name, count in pairs(itemDB) do
        table.insert(itemList, {name = name, count = count})
    end

    -- Sort the list alphabetically
    table.sort(itemList, function(a, b) return a.name < b.name end)

    local totalItems = #itemList
    if totalItems == 0 then
        print("No items in storage.")
        sleep(2)
        return
    end

    local currentPage = 1
    local totalPages = math.ceil(totalItems / itemsPerPage)

    while true do
        term.clear()
        term.setCursorPos(1, 1)
        print("=== Combined Items in Storage ===")

        local startIndex = (currentPage - 1) * itemsPerPage + 1
        local endIndex = math.min(startIndex + itemsPerPage - 1, totalItems)

        for i = startIndex, endIndex do
            local item = itemList[i]
            if item then
                print(string.format("%-30s : %d", item.name, item.count))
            end
        end

        print(string.format("\nPage %d/%d", currentPage, totalPages))
        print("Press [N] for Next page, [P] for Previous page, [Q] to quit.")

        local event, key = os.pullEvent("key")
        if key == keys.n and currentPage < totalPages then
            currentPage = currentPage + 1
        elseif key == keys.p and currentPage > 1 then
            currentPage = currentPage - 1
        elseif key == keys.q then
            break
        end
    end
end

-- Function to run your provided test code when option 3 is selected
local function runTestCode()
    local chestNames = {}
    local dispenserName

    -- Scan and find peripherals dynamically, including all chest types
    local function findPeripherals()
        local peripherals = peripheral.getNames()
        for _, name in ipairs(peripherals) do
            local p = peripheral.wrap(name)
            if p and p.list and name ~= "bottom" then  -- Check for any inventory-like peripheral
                if name:find("dispenser") then
                    dispenserName = name
                else
                    table.insert(chestNames, name)
                end
            end
        end
    end

    -- Function to try and push items into a chest
    local function tryPushToChest(dispenser, slot, count)
        for _, chestName in ipairs(chestNames) do
            local chest = peripheral.wrap(chestName)
            if chest then
                local moved = dispenser.pushItems(peripheral.getName(chest), slot, count)
                if moved > 0 then
                    print("Moved " .. moved .. " items from dispenser to " .. chestName)
                    return true
                end
            end
        end
        return false
    end

    -- Function to transfer items from dispenser to chest
    local function transferItems()
        if dispenserName then
            local dispenser = peripheral.wrap(dispenserName)
            
            if dispenser then
                -- Iterate through the dispenser slots
                for slot, item in pairs(dispenser.list()) do
                    local success = tryPushToChest(dispenser, slot, item.count)
                    if not success then
                        print("Failed to move item from dispenser to any chest. All chests might be full.")
                    end
                end
            else
                print("Failed to wrap the dispenser.")
            end
        else
            print("Dispenser not found.")
        end
    end

    -- Main function to run the program
    local function main()
        findPeripherals()

        -- Check if the peripherals are found
        if #chestNames > 0 and dispenserName then
            print("Chests found: " .. table.concat(chestNames, ", "))
            print("Dispenser found: " .. dispenserName)
            transferItems()
        else
            print("Failed to detect necessary peripherals. Cannot proceed.")
        end
    end

    -- Run the main function
    main()
end

-- Main menu to navigate between different modes
local function mainMenu()
    while true do
        term.clear()
        term.setCursorPos(1, 1)
        print("=== Modular Storage System ===")
        print("1. View Items in Storage")
        print("2. Label Items & Drop into Dispenser")
        print("3. Transfer Items from Dispenser to Chests")
        print("4. Exit Program")
        print("\nSelect an option by typing the number and pressing Enter:")

        local choice = read()

        if choice == "1" then
            updateDatabase()
            displayItems()
        elseif choice == "2" then
            scanAndMapItems()
            dropItemsIntoDispenser()
        elseif choice == "3" then
            runTestCode()  -- This runs your provided test code
            sleep(2)  -- Optional pause before returning to menu
        elseif choice == "4" then
            term.clear()
            term.setCursorPos(1, 1)
            print("Exiting program. Goodbye!")
            break
        else
            print("Invalid choice. Please select a valid option.")
            sleep(2)
        end
    end
end

-- Main program
local function main()
    loadNameMap()
    scanInventories()
    mainMenu()
end

-- Run the program
main()
