local peripheralName = "big_battery"

-- Find the battery peripheral, connected via a modem
local battery = peripheral.find(peripheralName)

if not battery then
    print("Battery not found. Ensure the modem is connected to the battery.")
    return
end

-- Function to format numbers with commas for readability
local function formatNumber(n)
    local formatted = tostring(n):reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return formatted:gsub("^,", "")
end

local previousEnergy = battery.getEnergyStored()

while true do
    term.clear()
    term.setCursorPos(1, 1)
    print("Zetta Industries Battery Monitor")
    print("-------------------------------")
    
    local energyStored = battery.getEnergyStored()
    local maxEnergy = battery.getMaxEnergyStored()
    local energyChangePerTick = energyStored - previousEnergy
    previousEnergy = energyStored

    local rfPerTickIn = energyChangePerTick > 0 and energyChangePerTick or 0
    local rfPerTickOut = energyChangePerTick < 0 and math.abs(energyChangePerTick) or 0

    print("Stored RF: " .. formatNumber(energyStored) .. " / " .. formatNumber(maxEnergy) .. " RF")
    print("RF/t Incoming: " .. formatNumber(rfPerTickIn))
    print("RF/t Outgoing: " .. formatNumber(rfPerTickOut))
    
    sleep(1)
end
