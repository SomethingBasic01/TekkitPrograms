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
 
    -- Draw header
    term.setTextColor(colors.cyan)
    term.setBackgroundColor(colors.black)
    term.write("Zetta Industries Battery Monitor")
    term.setCursorPos(1, 2)
    term.write(string.rep("-", 30))
 
    -- Draw energy bar
    term.setCursorPos(1, 4)
    local energyStored = battery.getEnergyStored()
    local maxEnergy = battery.getMaxEnergyStored()
    local energyPercentage = energyStored / maxEnergy
    local barLength = 26
    local filledLength = math.floor(energyPercentage * barLength)
 
    term.write("Energy: [")
    term.setBackgroundColor(colors.green)
    term.write(string.rep(" ", filledLength))
    term.setBackgroundColor(colors.red)
    term.write(string.rep(" ", barLength - filledLength))
    term.setBackgroundColor(colors.black)
    term.write("]")
 
    -- Display energy stats
    term.setCursorPos(1, 6)
    term.setTextColor(colors.white)
    print("Stored RF: " .. formatNumber(energyStored) .. " / " .. formatNumber(maxEnergy) .. " RF")
 
    -- Calculate RF per tick
    local energyChangePerTick = energyStored - previousEnergy
    previousEnergy = energyStored
 
    local rfPerTickIn = energyChangePerTick > 0 and energyChangePerTick or 0
    local rfPerTickOut = energyChangePerTick < 0 and math.abs(energyChangePerTick) or 0
 
    -- Display RF/t stats
    term.setCursorPos(1, 8)
    term.setTextColor(colors.lime)
    print("RF/t Incoming: " .. formatNumber(rfPerTickIn))
    term.setCursorPos(1, 9)
    term.setTextColor(colors.red)
    print("RF/t Outgoing: " .. formatNumber(rfPerTickOut))
 
    sleep(1)
end
