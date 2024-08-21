-- Clear the terminal to start fresh
term.clear()
term.setCursorPos(1, 1)

-- List all connected peripherals
local peripherals = peripheral.getNames()

if #peripherals > 0 then
    term.write("Connected Peripherals:\n")
    for i, name in ipairs(peripherals) do
        term.write("- " .. name .. "\n")
        term.setCursorPos(1, select(2, term.getCursorPos()) + 1)  -- Move to the next line
    end
else
    term.write("No peripherals detected.\n")
    term.setCursorPos(1, select(2, term.getCursorPos()) + 1)
end

-- Attempt to wrap the chest
local chest = peripheral.wrap("right")  -- Change "right" to the correct side
if chest then
    term.write("Chest found on 'right' side.\n")
    term.setCursorPos(1, select(2, term.getCursorPos()) + 1)
    local items = chest.list()
    if items then
        term.write("Items found:\n")
        term.setCursorPos(1, select(2, term.getCursorPos()) + 1)
        for slot, item in pairs(items) do
            term.write("Slot: " .. slot .. ", Item: " .. item.name .. ", Count: " .. item.count .. "\n")
            term.setCursorPos(1, select(2, term.getCursorPos()) + 1)
        end
    else
        term.write("Chest is empty or inaccessible.\n")
        term.setCursorPos(1, select(2, term.getCursorPos()) + 1)
    end
else
    term.write("Failed to wrap the chest!\n")
    term.setCursorPos(1, select(2, term.getCursorPos()) + 1)
end
