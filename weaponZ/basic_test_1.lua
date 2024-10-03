-- Initialization
local fuelThreshold = 200  -- Minimum fuel level before refueling

-- Function to refuel the turtle
function refuelIfNeeded()
    if turtle.getFuelLevel() < fuelThreshold then
        for slot = 1, 16 do
            turtle.select(slot)
            if turtle.refuel(0) then  -- Check if this slot has fuel
                turtle.refuel()
                print("Refueled with slot " .. slot)
            end
        end
    end
end

-- Function to dig down to bedrock
function mineDownToBedrock()
    print("Mining down to bedrock.")
    while true do
        -- Check if there is a block below
        local success, data = turtle.inspectDown()
        if success and data.name == "minecraft:bedrock" then
            print("Reached bedrock.")
            break
        end

        -- Dig and move down
        if turtle.detectDown() then
            turtle.digDown()
        end
        
        if not turtle.down() then
            print("Unable to move down.")
            break
        end
    end
end

-- Function to move up a specific number of blocks
function moveUp(yLevel)
    print("Moving up " .. yLevel .. " levels.")
    for i = 1, yLevel do
        while turtle.detectUp() do
            turtle.digUp()  -- Clear the way if there's a block above
        end
        if not turtle.up() then
            print("Unable to move up.")
            return false
        end
    end
    print("Moved up " .. yLevel .. " blocks.")
    return true
end

-- Main function to run the turtle operations
function main()
    refuelIfNeeded()

    -- Step 1: Mine to bedrock
    mineDownToBedrock()

    -- Step 2: Move up 100 blocks
    local success = moveUp(100)
    if not success then
        print("Failed to move up completely.")
    end

    print("Operation complete.")
end

-- Run the main function
main()

