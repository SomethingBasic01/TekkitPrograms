-- Clear the terminal to start fresh
term.clear()
term.setCursorPos(1, 1)

-- List all connected peripherals
local peripherals = peripheral.getNames()

if #peripherals > 0 then
    term.write("Connected Peripherals:\n")
    for i, name in ipairs(peripherals) do
        term.write("- " .. name .. "\n")
    end
else
    term.write("No peripherals detected.\n")
end

-- Attempt to wrap the chest
local chest = peripheral.wrap("right")  -- Change "right" to the correct side
if chest then
    term.write("Chest found on 'right' side.\n")
    local items = chest.list()
    if items then
        term.write("Items found:\n")
        for slot, item in pairs(items) do
            term.write("Slot: " .. slot .. ", Item: " .. item.name .. ", Count: " .. item.count .. "\n")
        end
    else
        term.write("Chest is empty or inaccessible.\n")
    end
else
    term.write("Failed to wrap the chest!\n")
end
