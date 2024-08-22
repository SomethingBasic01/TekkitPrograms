-- Modular Storage System with Name Mapping

local storageDB = {}
local itemDB = {}

-- A table to map damage values to friendly names for stone variants
local damageToNameMap = {
    ["minecraft:stone:0"] = "Stone",
    ["minecraft:stone:1"] = "Granite",
    ["minecraft:stone:2"] = "Polished Granite",
    ["minecraft:stone:3"] = "Diorite",
    ["minecraft:stone:4"] = "Polished Diorite",
    ["minecraft:stone:5"] = "Andesite",
    ["minecraft:stone:6"] = "Polished Andesite",
    -- Add more mappings as needed
}

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
            local friendlyName = damageToNameMap[key] or item.name  -- Get the friendly name if available
            
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

-- Main program loop
function main()
    scanInventories()
    updateDatabase()
    displayItems()
end

main()
