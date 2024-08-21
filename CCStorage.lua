-- Initialize variables
local storage = {}

-- Function to scan and update storage table
function scanInventories()
    local peripherals = peripheral.find("inventory")
    for _, inv in pairs(peripherals) do
        local items = inv.list()
        for slot, item in pairs(items) do
            local name = item.name
            local mod = name:match("([^:]+):")
            if storage[name] then
                storage[name].count = storage[name].count + item.count
                table.insert(storage[name].locations, {peripheral = inv, slot = slot})
            else
                storage[name] = {
                    count = item.count,
                    mod = mod,
                    locations = {{peripheral = inv, slot = slot}}
                }
            end
        end
    end
end

-- Function to display inventory
function displayInventory(filter)
    term.clear()
    term.setCursorPos(1, 1)
    for name, data in pairs(storage) do
        if filter == nil or name:find(filter) or data.mod == filter then
            print(name .. " x" .. data.count .. " [" .. data.mod .. "]")
        end
    end
end

-- Main Program Loop
while true do
    scanInventories()
    displayInventory()
    -- Wait for user input or action
end
