-- Modular Storage System with Turtle Scanning and Automated Name Mapping

local storageDB = {}
local itemDB = {}
local damageToNameMap = {}  -- Initially empty, will be populated by the turtle

-- Scan and wrap all connected inventories
function scanInventories()
    local peripherals = peripheral.getNames()
    for _, name in ipairs(peripherals) do
        local p = peripheral.wrap(name)
        if p and p.list then
            storageDB[name] = p
        end
    end
end

-- Function to have the turtle scan an item and update the map
function scanAndMapItem()
    for slot = 1, 16 do  -- Turtle has 16 slots
        local item = turtle.getItemDetail(slot)
        if item then
            local key = item.name .. ":" .. (item.damage or 0)
            if not damageToNameMap[key] then
                damageToNameMap[key] = item.name  -- Update the map with the correct name
                print("Mapped " .. item.name .. " with damage " .. (item.damage or 0))
            end
            turtle.dropDown()  -- Drop the item into the network (assuming chest is below the turtle)
        end
    end
end

-- Populate database with item details from all chests
function updateDatabase()
    itemDB = {}
    for name, chest in pairs(storageDB) do
        local items = chest.list()
        for slot, item in pairs(items) do
            local key = item.name .. ":" .. (item.damage or 0)
            local friendlyName = damageToNameMap[key] or item.name
            
            if not itemDB[friendlyName] then
                itemDB[friendlyName] = {count = 0, name = friendlyName}
            end
            itemDB[friendlyName].count = itemDB[friendlyName].count + item.count
        end
    end
end

-- Display combined items in storage
function displayItems()
    term.clear()
    term.setCursorPos(1, 1)
    print("Combined Items in Storage:")
    for _, item in pairs(itemDB) do
        print(item.name .. ": " .. item.count)
    end
end

-- Main program loop with live updates and turtle scanning
function main()
    scanInventories()
    while true do
        scanAndMapItem()  -- Scan items with the turtle before updating
        updateDatabase()
        displayItems()
        sleep(5)  -- Update every 5 seconds
    end
end

main()
