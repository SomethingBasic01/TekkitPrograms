--------------------------------------------------------------------------------
-- Modular Inventory Transfer Program with Live Config Management and Debug Toggle
-- Features:
--   • Create, save, load, and list configurations.
--   • Activate/deactivate specific configurations for item transfer.
--   • Live background scheduler that runs active transfers concurrently with UI.
--   • Automatic peripheral (inventory) detection.
--   • Toggleable debug output.
--------------------------------------------------------------------------------

-- Global Variables
local allConfigs = {}      -- Stores all configuration objects.
local running = true       -- Global flag for the background scheduler.
local configDir = "configs"  -- Directory to store config files
local debugMode = false    -- Debug output is off by default.

-- Ensure the configuration directory exists.
if not fs.exists(configDir) then
    fs.makeDir(configDir)
end

--------------------------------------------------------------------------------
-- UTILITY FUNCTIONS
--------------------------------------------------------------------------------

-- Returns a list of peripheral names that support the "list" method.
local function getInventories()
    local invs = {}
    for _, name in ipairs(peripheral.getNames()) do
        local ok, list = pcall(peripheral.call, name, "list")
        if ok and type(list) == "table" then
            table.insert(invs, name)
        end
    end
    return invs
end

-- Draws a simple menu with a title and list of options.
local function drawMenu(title, options)
    term.clear()
    term.setCursorPos(1,1)
    print("==== " .. title .. " ====")
    for i, option in ipairs(options) do
        print(i .. ". " .. option)
    end
    print("\nSelect an option:")
end

-- Reads a numeric choice and validates it is within 1..numOptions.
local function getChoice(numOptions)
    local choice = tonumber(read())
    if choice and choice >= 1 and choice <= numOptions then
        return choice
    end
    return nil
end

-- Debug print: prints only if debug mode is enabled.
local function debugLog(message)
    if debugMode then
        print(message)
    end
end

-- Toggle debug mode on/off.
local function toggleDebugMode()
    debugMode = not debugMode
    print("Debug mode is now " .. (debugMode and "ON" or "OFF"))
    sleep(1)
end

--------------------------------------------------------------------------------
-- CONFIGURATION HANDLING (SAVE / LOAD / CREATE)
--------------------------------------------------------------------------------

-- Save current configurations to a file in configDir.
local function saveConfigurations()
    term.clear()
    term.setCursorPos(1,1)
    print("Enter a name for the configuration file (without extension):")
    local name = read()
    local fileName = fs.combine(configDir, name .. ".cfg")
    local file = fs.open(fileName, "w")
    if file then
        file.write(textutils.serialize(allConfigs))
        file.close()
        print("Configurations saved to " .. fileName)
    else
        print("Error: Could not open file for writing.")
    end
    print("Press any key to continue...")
    os.pullEvent("key")
end

-- Returns a list of configuration files (ending in .cfg) from configDir.
local function listConfigFiles()
    local files = fs.list(configDir)
    local cfgFiles = {}
    for _, file in ipairs(files) do
        if file:sub(-4) == ".cfg" then
            table.insert(cfgFiles, file)
        end
    end
    return cfgFiles
end

-- Load configurations from a file chosen by the user.
local function loadConfigurations()
    local cfgFiles = listConfigFiles()
    if #cfgFiles == 0 then
        print("No configuration files found in " .. configDir)
        sleep(2)
        return
    end

    drawMenu("Load Configurations", cfgFiles)
    local choice = getChoice(#cfgFiles)
    if not choice then
        print("Invalid selection.")
        sleep(1)
        return
    end
    local fileName = fs.combine(configDir, cfgFiles[choice])
    local file = fs.open(fileName, "r")
    if file then
        local data = file.readAll()
        file.close()
        local loaded = textutils.unserialize(data)
        if loaded then
            term.clear()
            print("Load Options:")
            print("1. Replace current configurations")
            print("2. Append to current configurations")
            local opt = tonumber(read())
            if opt == 1 then
                allConfigs = loaded
                print("Configurations replaced.")
            elseif opt == 2 then
                for _, cfg in ipairs(loaded) do
                    table.insert(allConfigs, cfg)
                end
                print("Configurations appended.")
            else
                print("Invalid option. Aborting load.")
            end
        else
            print("Error: Could not parse configuration file.")
        end
    else
        print("Error: Could not open file for reading.")
    end
    print("Press any key to continue...")
    os.pullEvent("key")
end

-- Create a new configuration by prompting the user for details.
local function createConfiguration()
    term.clear()
    term.setCursorPos(1,1)
    print("=== Create New Configuration ===")
    
    -- Select Source Inventory
    print("Select the SOURCE inventory:")
    local inventories = getInventories()
    if #inventories == 0 then
        print("No inventories detected. Please connect a peripheral.")
        sleep(2)
        return nil
    end
    for i, inv in ipairs(inventories) do
        print(i .. ". " .. inv)
    end
    local srcChoice = getChoice(#inventories)
    if not srcChoice then
        print("Invalid selection.")
        sleep(1)
        return nil
    end
    local sourceName = inventories[srcChoice]

    -- Select Target Inventory
    print("Select the TARGET inventory:")
    for i, inv in ipairs(inventories) do
        print(i .. ". " .. inv)
    end
    local tgtChoice = getChoice(#inventories)
    if not tgtChoice then
        print("Invalid selection.")
        sleep(1)
        return nil
    end
    local targetName = inventories[tgtChoice]

    -- Input source slots
    print("Enter source slot(s) (comma-separated, or blank for slot 1):")
    local srcSlotsInput = read()
    local sourceSlots = {}
    if srcSlotsInput == "" then
        sourceSlots = {1}
    else
        for num in string.gmatch(srcSlotsInput, "%d+") do
            table.insert(sourceSlots, tonumber(num))
        end
    end

    -- Input target slots
    print("Enter target slot(s) (comma-separated, or blank for slot 1):")
    local tgtSlotsInput = read()
    local targetSlots = {}
    if tgtSlotsInput == "" then
        targetSlots = {1}
    else
        for num in string.gmatch(tgtSlotsInput, "%d+") do
            table.insert(targetSlots, tonumber(num))
        end
    end

    -- Input number of items to move
    print("Enter number of items to move (blank for full stack):")
    local amtInput = read()
    local amount = tonumber(amtInput) or nil

    -- Looping option
    print("Should this configuration loop? (yes/no):")
    local loopInput = read():lower()
    local loop = (loopInput == "yes")
    local speed = 1
    if loop then
        print("Enter speed (seconds) between transfers:")
        speed = tonumber(read()) or 1
    end

    -- Build and return the configuration object.
    local config = {
        sourceName = sourceName,
        targetName = targetName,
        sourceSlots = sourceSlots,
        targetSlots = targetSlots,
        amount = amount,
        loop = loop,
        speed = speed,
        active = false,   -- Not active by default.
        lastRun = 0       -- Timestamp for scheduling.
    }
    return config
end

--------------------------------------------------------------------------------
-- ITEM TRANSFER LOGIC
--------------------------------------------------------------------------------

-- Performs the item transfer for a given configuration.
local function moveItem(config)
    local sourceInv = peripheral.wrap(config.sourceName)
    local targetInv = peripheral.wrap(config.targetName)
    if not sourceInv or not targetInv then
        print("Error: Could not wrap one or both peripherals for config: " .. config.sourceName .. " -> " .. config.targetName)
        return
    end

    local sourceItems = sourceInv.list()
    for _, srcSlot in ipairs(config.sourceSlots) do
        local item = sourceItems[srcSlot]
        if item then
            local transferAmount = config.amount or item.count
            for _, tgtSlot in ipairs(config.targetSlots) do
                local moved = sourceInv.pushItems(peripheral.getName(targetInv), srcSlot, transferAmount, tgtSlot)
                if moved > 0 then
                    debugLog("Moved " .. moved .. " item(s) from slot " .. srcSlot .. " to slot " .. tgtSlot)
                    break  -- Exit the target loop on success.
                else
                    debugLog("Failed to move items from slot " .. srcSlot .. " to slot " .. tgtSlot)
                end
            end
        else
            debugLog("No item found in source slot " .. srcSlot)
        end
    end
end

--------------------------------------------------------------------------------
-- BACKGROUND SCHEDULER
-- Runs continuously in the background and processes only active configurations.
--------------------------------------------------------------------------------

local function backgroundRunner()
    while running do
        local now = os.clock()
        for _, config in ipairs(allConfigs) do
            if config.active then
                if config.loop then
                    -- For looping configs, run if enough time has passed.
                    if now - (config.lastRun or 0) >= config.speed then
                        moveItem(config)
                        config.lastRun = now
                    end
                else
                    -- For one-off configs, run once then deactivate.
                    moveItem(config)
                    config.active = false
                end
            end
        end
        sleep(0.1)
    end
end

--------------------------------------------------------------------------------
-- USER INTERFACE / MENU SYSTEM
--------------------------------------------------------------------------------

-- Lists all configurations and shows details.
local function listConfigs()
    term.clear()
    term.setCursorPos(1,1)
    print("=== Current Configurations ===")
    if #allConfigs == 0 then
        print("(none)")
    else
        for i, config in ipairs(allConfigs) do
            local status = config.active and "Active" or "Inactive"
            print(string.format("%d. [%s] %s -> %s | Src: %s | Tgt: %s | Amt: %s | Loop: %s | Speed: %s",
                i,
                status,
                config.sourceName,
                config.targetName,
                table.concat(config.sourceSlots, ","),
                table.concat(config.targetSlots, ","),
                config.amount or "full",
                tostring(config.loop),
                config.speed
            ))
        end
    end
    print("\nPress any key to continue...")
    os.pullEvent("key")
end

-- Activates a configuration so that the scheduler will run it.
local function activateConfig()
    term.clear()
    term.setCursorPos(1,1)
    print("=== Activate Configuration ===")
    local inactiveConfigs = {}
    for i, config in ipairs(allConfigs) do
        if not config.active then
            table.insert(inactiveConfigs, {index = i, config = config})
        end
    end
    if #inactiveConfigs == 0 then
        print("No inactive configurations available.")
        sleep(2)
        return
    end
    for i, entry in ipairs(inactiveConfigs) do
        local cfg = entry.config
        print(string.format("%d. %s -> %s", i, cfg.sourceName, cfg.targetName))
    end
    print("Select a configuration to activate:")
    local choice = getChoice(#inactiveConfigs)
    if not choice then
        print("Invalid selection.")
        sleep(1)
        return
    end
    local sel = inactiveConfigs[choice]
    sel.config.active = true
    sel.config.lastRun = os.clock()
    print("Configuration activated!")
    sleep(1)
end

-- Deactivates a configuration so it will no longer run.
local function deactivateConfig()
    term.clear()
    term.setCursorPos(1,1)
    print("=== Deactivate Configuration ===")
    local activeConfigs = {}
    for i, config in ipairs(allConfigs) do
        if config.active then
            table.insert(activeConfigs, {index = i, config = config})
        end
    end
    if #activeConfigs == 0 then
        print("No active configurations.")
        sleep(2)
        return
    end
    for i, entry in ipairs(activeConfigs) do
        local cfg = entry.config
        print(string.format("%d. %s -> %s", i, cfg.sourceName, cfg.targetName))
    end
    print("Select a configuration to deactivate:")
    local choice = getChoice(#activeConfigs)
    if not choice then
        print("Invalid selection.")
        sleep(1)
        return
    end
    local sel = activeConfigs[choice]
    sel.config.active = false
    print("Configuration deactivated!")
    sleep(1)
end

-- Main UI menu.
local function uiMenu()
    while true do
        term.clear()
        term.setCursorPos(1,1)
        print("==== Modular Inventory Transfer Manager ====")
        print("1. Create New Configuration")
        print("2. List All Configurations")
        print("3. Activate a Configuration")
        print("4. Deactivate a Configuration")
        print("5. Save Configurations")
        print("6. Load Configurations")
        print("7. Toggle Debug Mode (currently " .. (debugMode and "ON" or "OFF") .. ")")
        print("8. Exit")
        print("============================================")
        local choice = read()
        if choice == "1" then
            local cfg = createConfiguration()
            if cfg then
                table.insert(allConfigs, cfg)
                print("Configuration created and added.")
                sleep(1)
            end
        elseif choice == "2" then
            listConfigs()
        elseif choice == "3" then
            activateConfig()
        elseif choice == "4" then
            deactivateConfig()
        elseif choice == "5" then
            saveConfigurations()
        elseif choice == "6" then
            loadConfigurations()
        elseif choice == "7" then
            toggleDebugMode()
        elseif choice == "8" then
            running = false
            break
        else
            print("Invalid selection. Try again.")
            sleep(1)
        end
    end
end

--------------------------------------------------------------------------------
-- MAIN PROGRAM LOGIC
--------------------------------------------------------------------------------

local function main()
    -- Run the UI menu and background scheduler concurrently.
    parallel.waitForAny(uiMenu, backgroundRunner)
    term.clear()
    term.setCursorPos(1,1)
    print("Exiting program. Goodbye!")
end

main()
