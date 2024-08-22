-- Modular Storage System

local storageDB = {}
local itemDB = {}

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

-- Populate database with item details from all chests
function updateDatabase()
    itemDB = {}
    for name, chest in pairs(storageDB) do
        local items = chest.list()
        for slot, item in pairs(items) do
            local key = item.name .. ":" .. (item.damage or 0)  -- Create a unique key for each item type
            if not itemDB[key] then
                itemDB[key] = {count = 0, name = item.name, damage = item.damage}
            end
            itemDB[key].count = itemDB[key].count + item.count
        end
    end
end

-- Display combined items in storage
function displayItems()
    term.clear()
    term.setCursorPos(1, 1)
    print("Combined Items in Storage:")
    for _, item in pairs(itemDB) do
        print(item.name .. " (Damage: " .. (item.damage or 0) .. "): " .. item.count)
    end
end

-- Main program loop
function main()
    scanInventories()
    updateDatabase()
    displayItems()
end

main()
