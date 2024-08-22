chest = peripheral.wrap("minecraft:chest_8")
items = chest.list()

for slot, item in pairs(items) do
    print("Slot: " .. slot .. " contains " .. item.count .. " of " .. item.name)
end
