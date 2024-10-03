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
                return true
            end
        end
        print("WARNING: Out of fuel! Unable to proceed.")
        return false
    end
    return true
end

-- Function to dig down to bedrock
function mineDownToBedrock()
    print("Mining down to bedrock.")
    while true do
        -- Check fuel level before any action
        if not refuelIfNeeded() then
            print("Stopping due to lack of fuel.")
            return false
        end

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
            return false
        end
    end
    return true
end

-- Function to move up a specific number of blocks with retry logic
function moveUpWithRetry(yLevel)
    local retries = 0
    while retries < 5 do  -- Allow multiple retries before giving up
        print("Attempting to move up " .. yLevel .. " blocks.")
        local success = true
        for i = 1, yLevel do
            -- Check fuel level before any action
            if not refuelIfNeeded() then
                print("Stopping due to lack of fuel.")
                return false
            end

            -- Clear any blocks above before moving up
            while turtle.detectUp() do
                turtle.digUp()  -- Clear the way if there's a block above
            end

            if not turtle.up() then
                print("Unable to move up on block " .. i .. ", retrying.")
                success = false
                break
            end
        end

        if success then
            print("Moved up " .. yLevel .. " blocks successfully.")
            return true
        end

        -- If unsuccessful, retry by returning to bedrock
        retries = retries + 1
        print("Retry #" .. retries .. ": Returning to bedrock to retry moving up.")
        if not mineDownToBedrock() then
            print("Failed to reach bedrock during retry, stopping.")
            return false
        end
    end

    print("Exceeded maximum retries. Operation failed.")
    return false
end

-- Main function to run the turtle operations
function main()
    refuelIfNeeded()

    -- Step 1: Mine to bedrock
    local reachedBedrock = mineDownToBedrock()
    if not reachedBedrock then
        print("Failed to reach bedrock due to an issue.")
        return
    end

    -- Step 2: Move up 15 blocks (best Y level for coal, gold, iron, redstone)
    local success = moveUpWithRetry(15)
    if not success then
        print("Failed to move up completely.")
    end

    print("Operation complete.")
end

-- Run the main function
main()

-- Run the main function
main()

