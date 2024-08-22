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
            if item then
                print("Item detected: Name = " .. tostring(item.name) .. ", Count = " .. tostring(item.count) .. ", Slot = " .. slot)
                local itemName = item.name
                local itemCount = item.count

                if not itemDB[itemName] then
                    itemDB[itemName] = {count = 0}
                end
                itemDB[itemName].count = itemDB[itemName].count + itemCount
            else
                print("Empty slot: " .. slot)
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
    if next(itemDB) == nil then
        print("No items found.")
    end
end

-- Main program loop
function main()
    scanInventories()
    updateDatabase()
    displayItems()
end

main()
