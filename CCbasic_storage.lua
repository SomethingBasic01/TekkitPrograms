-- Extremely Simplified Storage System

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
            if item and item.name and item.count then
                local itemName = item.name
                local itemCount = item.count
                if not itemDB[itemName] then
                    itemDB[itemName] = {count = 0}
                end
                itemDB[itemName].count = itemDB[itemName].count + itemCount
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

-- Main program loop
function main()
    scanInventories()
    updateDatabase()
    displayItems()
end

main()
