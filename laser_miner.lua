-- Find the manipulator block
local manipulator = peripheral.find("manipulator")
if not manipulator then
    error("Cannot find manipulator", 0)
end
 
-- Check for required modules
if not manipulator.hasModule("plethora:laser") then
    error("Cannot find laser", 0)
end
if not manipulator.hasModule("plethora:introspection") then
    error("Cannot find introspection module", 0)
end
 
-- Set the desired hole size
local holeSize = 3 -- Change this value to 5, 7, or any odd number to adjust the hole size
 
-- Function to fire the laser at a specific position
local function fireLaserAt(x, y, z)
    local distance = math.sqrt(x^2 + y^2 + z^2) -- Calculate the distance to the target
    if distance > 0 then
        local yaw = math.deg(math.atan2(x, z)) -- Calculate yaw to target the specific block
        local pitch = -math.deg(math.atan2(y, math.sqrt(x^2 + z^2))) -- Calculate pitch to target downward
        local potency = math.min(5.0, math.max(0.5, distance)) -- Clamp potency between 0.5 and 5.0
        manipulator.fire(yaw, pitch, potency)
        sleep(0.2) -- Wait for the laser to recharge
    end
end
 
-- Function to mine an NxN area layer by layer down to bedrock
local function mineLayerByLayer()
    local halfSize = math.floor((holeSize - 1) / 2) -- Calculate half the size to determine loop range
    for y = -1, -255, -1 do -- Loop from one block below the manipulator to bedrock (local Y axis)
        for offsetX = -halfSize, halfSize do -- Iterate over each row in the X direction
            for offsetZ = -halfSize, halfSize do -- Iterate over each column in the Z direction
                fireLaserAt(offsetX, y, offsetZ) -- Fire laser at the specific block in the layer
            end
        end
    end
end
 
-- Main mining loop
while true do
    mineLayerByLayer()
    sleep(1) -- Allow some delay between operations to handle possible lag or reloads
end
