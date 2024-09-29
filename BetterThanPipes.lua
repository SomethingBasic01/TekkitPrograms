-- Inventory Transfer Program with Auto Startup Configuration Loading, Multiple Config Saving/Loading, and Parallel Execution

local configurations = {}

-- Function to move items between multiple source and target slots
local function moveItem(config)
    local sourceInventory = peripheral.wrap(config.sourceName)
    local targetInventory = peripheral.wrap(config.targetName)

    if not sourceInventory or not targetInventory then
        error("Source or target inventory not found. Check your peripheral setup.")
    end

    local sourceItems = sourceInventory.list()
    
    -- Move through each source slot
    for _, sourceSlot in ipairs(config.sourceSlots) do
        local item = sourceItems[sourceSlot]
        
        if item then
            -- Move the specified amount (or the maximum if amount is not provided)
            local transferAmount = config.amount or item.count

            -- Iterate through each target slot
            for _, targetSlot in ipairs(config.targetSlots) do
                -- Try moving items from the source slot to the current target slot
                local success = sourceInventory.pushItems(peripheral.getName(targetInventory), sourceSlot, transferAmount, targetSlot)

                if success > 0 then
                    print("Moved " .. success .. " items from slot " .. sourceSlot .. " to slot " .. targetSlot .. " in the target inventory.")
                    break -- Exit the loop if the transfer was successful
                else
                    print("Failed to move items from slot " .. sourceSlot .. " to slot " .. targetSlot .. " in the target inventory.")
                end
            end

        else
            print("No item found in slot " .. sourceSlot .. " of the source inventory.")
        end
    end
end

-- Function to save configurations to a specific file
local function saveConfigurations(fileName)
    local file = fs.open(fileName, "w")
    file.write(textutils.serialize(configurations))
    file.close()
    print("Configurations saved to " .. fileName .. "!")
end

-- Function to load configurations from a specific file
local function loadConfigurations(fileName)
    if fs.exists(fileName) then
        local file = fs.open(fileName, "r")
        local loadedConfigurations = textutils.unserialize(file.readAll())
        file.close()

        -- Append loaded configurations to existing configurations
        for _, config in ipairs(loadedConfigurations) do
            table.insert(configurations, config)
        end

        print("Configurations loaded from " .. fileName .. "! Total configurations: " .. #configurations)
    else
        print("No saved configurations found with name: " .. fileName)
    end
end

-- Function to add a new configuration
local function addConfiguration(sourceName, targetName, sourceSlots, targetSlots, amount, loop, speed)
    local config = {
        sourceName = sourceName,
        targetName = targetName,
        sourceSlots = sourceSlots or {1},  -- Default to slot 1 if none provided
        targetSlots = targetSlots or {1},  -- Default to slot 1 if none provided
        amount = amount or nil,  -- The amount of items to transfer
        loop = loop or false,    -- Whether to loop the transfer
        speed = speed or 1       -- Time (in seconds) between each loop
    }
    table.insert(configurations, config)
    print("Configuration added! Total configurations: " .. #configurations)
end

-- Function to run a configuration with optional looping
local function runConfiguration(config)
    repeat
        moveItem(config)
        if config.loop then
            sleep(config.speed)  -- Wait for the defined speed before running again
        end
    until not config.loop
end

-- Function to run multiple configurations in parallel
local function startConfigurations()
    local configRunners = {}
    for _, config in ipairs(configurations) do
        table.insert(configRunners, function() runConfiguration(config) end)
    end
    parallel.waitForAny(table.unpack(configRunners)) -- Wait for any to stop, allowing looping configurations to keep running
end

-- Function to handle automatic startup configuration loading
local function startupConfiguration()
    -- Check if a startup configuration file exists
    local startupFileName = "startup_config.txt"
    if fs.exists(startupFileName) then
        loadConfigurations(startupFileName)

        -- Start running the configuration automatically
        parallel.waitForAny(
            function()
                -- Start running the configurations
                while true do
                    startConfigurations()
                end
            end,
            function()
                -- Listen for the 'x' key press to exit
                while true do
                    local event, key = os.pullEvent("key")
                    if key == keys.x then
                        print("Exiting startup configuration...")
                        break
                    end
                end
            end
        )

        return true -- Indicate that we loaded and started a configuration
    end

    return false -- No startup configuration was loaded
end

-- GUI to interact with the program
local function configurationMenu()
    while true do
        term.clear()
        term.setCursorPos(1, 1)
        print("==== Configuration Manager ====")
        print("1. Add New Configuration")
        print("2. Start Configurations")
        print("3. Save Configurations")
        print("4. Load Configurations")
        print("5. Exit")
        print("===============================")
        local choice = tonumber(read())

        if choice == 1 then
            -- Add new configuration
            print("Enter source inventory name (e.g., 'minecraft:chest_1'):")
            local sourceName = read()
            print("Enter target inventory name (e.g., 'minecraft:chest_2'):")
            local targetName = read()
            
            print("Enter source slots (comma-separated, e.g., '1,2,3' or leave blank for default slot 1):")
            local sourceSlotInput = read()
            local sourceSlots = {}
            if sourceSlotInput == "" then
                sourceSlots = {1}
            else
                for slot in string.gmatch(sourceSlotInput, "%d+") do
                    table.insert(sourceSlots, tonumber(slot))
                end
            end
            
            print("Enter target slots (comma-separated, e.g., '1,2,3' or leave blank for default slot 1):")
            local targetSlotInput = read()
            local targetSlots = {}
            if targetSlotInput == "" then
                targetSlots = {1}
            else
                for slot in string.gmatch(targetSlotInput, "%d+") do
                    table.insert(targetSlots, tonumber(slot))
                end
            end
            
            print("Enter number of items to move (or leave blank for full stack):")
            local itemAmount = tonumber(read()) or nil
            
            print("Enable looping? (yes/no)")
            local loopInput = read()
            local loop = (loopInput == "yes")
            
            print("Enter speed in seconds (for looping configurations):")
            local speed = tonumber(read()) or 1
            
            addConfiguration(sourceName, targetName, sourceSlots, targetSlots, itemAmount, loop, speed)

        elseif choice == 2 then
            -- Start configurations
            startConfigurations()

        elseif choice == 3 then
            -- Save configurations
            print("Enter a file name to save the configurations (e.g., 'config1.txt'):")
            local fileName = read()
            saveConfigurations(fileName)

        elseif choice == 4 then
            -- Load configurations
            print("Enter a file name to load configurations from (e.g., 'config1.txt'):")
            local fileName = read()
            loadConfigurations(fileName)

        elseif choice == 5 then
            break

        else
            print("Invalid choice.")
        end
    end
end

-- Main program logic
local function main()
    -- Automatically load and start the configuration on startup
    if not startupConfiguration() then
        -- If no configuration was started, show the regular menu
        configurationMenu()
    end
end

-- Run the main function
main()
