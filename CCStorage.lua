-- Initialize variables
local storage = {}

-- Function to scan and update storage table
function scanInventories()
    local peripherals = {peripheral.find("inventory")}
    if #peripherals > 0 then
        for _, inv in pairs(peripherals) do
            local items = inv.list()
            if items then
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
    else
        print("No inventory peripherals found!")
    end
end

-- Function to display paginated inventory
function displayInventory(page, filter)
    term.clear()
    term.setCursorPos(1, 1)
    local itemsPerPage = 5
    local currentPage = page or 1
    local startItem = (currentPage - 1) * itemsPerPage + 1
    local endItem = startItem + itemsPerPage - 1
    local displayedItems = {}

    for name, data in pairs(storage) do
        if (not filter) or (filter and (name:find(filter) or data.mod == filter)) then
            table.insert(displayedItems, {name = name, count = data.count, mod = data.mod})
        end
    end

    if #displayedItems == 0 then
        term.write("No items found.")
        return
    end

    for i = startItem, math.min(endItem, #displayedItems) do
        local item = displayedItems[i]
        term.write("Item: " .. item.name .. ", Count: " .. item.count .. ", Mod: " .. item.mod .. "\n")
        term.setCursorPos(1, select(2, term.getCursorPos()) + 1)
    end

    term.write("Page " .. currentPage .. " of " .. math.ceil(#displayedItems / itemsPerPage) .. "\n")
end

-- Function to search and filter items
function searchInventory()
    term.clear()
    term.setCursorPos(1, 1)
    term.write("Enter filter or search term: ")
    local filter = read()

    displayInventory(1, filter)
end

-- Main Program Loop
while true do
    scanInventories()
    term.clear()
    term.setCursorPos(1, 1)
    term.write("Inventory System\n")
    term.write("1. View Inventory\n")
    term.write("2. Search Inventory\n")
    term.write("3. Exit\n")
    term.write("Choose an option: ")

    local choice = read()

    if choice == "1" then
        local page = 1
        while true do
            displayInventory(page)
            term.write("\nPress [n] for next page, [p] for previous page, or [q] to quit: ")
            local action = read()
            if action == "n" then
                page = page + 1
            elseif action == "p" then
                page = math.max(1, page - 1)
            elseif action == "q" then
                break
            end
        end
    elseif choice == "2" then
        searchInventory()
    elseif choice == "3" then
        break
    end

    os.sleep(1)
end
