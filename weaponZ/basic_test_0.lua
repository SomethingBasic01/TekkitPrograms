-- Initialization
local role = "prime"  -- Role can be 'prime', 'secondary', 'tertiary', 'combat'
local fuelThreshold = 200  -- Minimum fuel level before refueling

-- Whitelist of entities to ignore
local whitelist = {
    ["minecraft:cow"] = true,
    ["minecraft:sheep"] = true,
}

-- Utility Functions
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
    while not turtle.detectDown() do
        if not turtle.digDown() then
            print("Blocked below, can't continue digging.")
            break
        end
        if not turtle.down() then
            print("Unable to move down.")
            break
        end
    end
    print("Reached bedrock.")
end

-- Function to move up a specific number of blocks
function moveUp(yLevel)
    for i = 1, yLevel do
        if not turtle.up() then
            print("Unable to move up.")
            break
        end
    end
end

-- Function to detect entities and attack if not whitelisted
function detectAndAttackEntities()
    local sensor = peripheral.find("plethora:sensor")  -- Use Plethora sensor peripheral
    if sensor then
        local entities = sensor.sense()  -- Detect all nearby entities
        for _, entity in pairs(entities) do
            if not whitelist[entity.name] then
                print("Hostile entity detected: " .. entity.name)
                -- Navigate toward the entity (simplified approach)
                -- Assume entity is directly ahead for demonstration purposes
                turtle.select(findSlot("sword"))  -- Select slot with sword
                if turtle.attack() then
                    print("Attacked entity: " .. entity.name)
                else
                    print("Entity out of range or attack failed.")
                end
            end
        end
    else
        print("Sensor not found.")
    end
end

-- Function to locate a specific item in the inventory
function findSlot(itemName)
    for i = 1, 16 do
        local detail = turtle.getItemDetail(i)
        if detail and detail.name:find(itemName) then
            return i
        end
    end
    return nil
end

-- Function to gather resources (gold, iron, coal, redstone)
function gatherResources()
    -- Example for mining around Y=20 level
    print("Gathering resources...")
    for i = 1, 10 do
        if not turtle.dig() then
            turtle.turnRight()
        end
        if not turtle.forward() then
            turtle.turnRight()
        end
        refuelIfNeeded()
    end
end

-- Main Loop
while true do
    refuelIfNeeded()

    -- Step 1: Mine to bedrock for positioning
    print("Mining down to bedrock.")
    mineDownToBedrock()

    -- Step 2: Move up to Y level for mining resources
    print("Moving up to level for resource gathering.")
    moveUp(100)

    -- Step 3: Gather resources at current level
    gatherResources()

    -- Step 4: Move down to Y ≈ 10 for redstone
    print("Moving down to gather redstone.")
    moveUp(-10)

    -- Gather redstone (simplified for now)
    gatherResources()

    -- Step 5: Combat mode - Detect and attack entities
    print("Entering combat mode.")
    detectAndAttackEntities()

    -- Loop repeats
    print("Cycle complete, restarting...")
end
