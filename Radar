-- Load the DiscordHook library
local DiscordHook = require("DiscordHook")

-- Define the configuration file path
local configFilePath = "config.txt"

-- Define default values
local config = {
    webhookURL = "",
    manipX = 0,
    manipY = 0,
    manipZ = 0,
    whitelist = {}
}

-- Save the configuration to file
local function saveConfig()
    local file = fs.open(configFilePath, "w")
    file.write(textutils.serialize(config))
    file.close()
end

-- Request updated configuration from the user
local function requestConfig()
    print("Enter Discord Webhook URL (must start with http:// or https://):")
    local webhookURL = read()
    while not (webhookURL:match("^https?://")) do
        print("Invalid URL format. Please enter a valid webhook URL (must start with http:// or https://):")
        webhookURL = read()
    end
    config.webhookURL = webhookURL

    print("Enter Manipulator X Coordinate:")
    config.manipX = tonumber(read())
    print("Enter Manipulator Y Coordinate:")
    config.manipY = tonumber(read())
    print("Enter Manipulator Z Coordinate:")
    config.manipZ = tonumber(read())

    print("Configuration saved.")
    saveConfig()
end

-- Load the configuration from file
local function loadConfig()
    if fs.exists(configFilePath) then
        local file = fs.open(configFilePath, "r")
        local content = file.readAll()
        config = textutils.unserialize(content) or config
        file.close()
    else
        -- If config file does not exist, create it with default settings
        requestConfig() -- Prompt the user for config if it does not exist
    end
end

-- Load the configuration
loadConfig()

-- Create the webhook object
print("Creating webhook...")
local success, hook = DiscordHook.createWebhook(config.webhookURL)

if not success then
    error("Webhook connection failed! Reason: " .. hook)
else
    print("Webhook created successfully!")
end

-- Wrap the manipulator peripheral (replace with the correct side or name of the manipulator)
local manipulator = peripheral.wrap("back") -- Replace "back" with the correct peripheral side (left, right, etc.)

if not manipulator then
    error("Manipulator not found! Ensure it is connected.")
end

-- Define the side for the redstone output
local redstoneSide = "top" -- Replace with the side you want to output the redstone signal (e.g., "top", "bottom", "left", "right")

-- Function to send a Discord notification when a player is detected
function sendDiscordNotification(message)
    print("Sending message to Discord...")
    local result = hook.send(message)

    if result then
        print("Notification sent successfully!")
    else
        print("Failed to send Discord notification.")
    end
end

-- Function to manage redstone output based on player detection
local function setRedstoneOutput(state)
    redstone.setOutput(redstoneSide, state)
    if state then
        print("Redstone signal turned ON.")
    else
        print("Redstone signal turned OFF.")
    end
end

-- Function to scan and print the world position of players only
function scanPlayers()
    local entities = manipulator.sense()
    local nonWhitelistedPlayerFound = false

    for _, entity in pairs(entities) do
        -- Check if the entity is a player by comparing name and displayName
        if entity.name and entity.displayName and entity.name == entity.displayName then
            -- Check if the player is on the whitelist
            if config.whitelist[entity.name] then
                print("Player " .. entity.name .. " is whitelisted, ignoring detection.")
            else
                nonWhitelistedPlayerFound = true

                -- Calculate world coordinates using manipulator coordinates + relative entity coordinates
                local worldX = config.manipX + entity.x
                local worldY = config.manipY + entity.y
                local worldZ = config.manipZ + entity.z

                -- Print the world coordinates of the detected player
                print(string.format("Player detected - Name: %s, World Position: X: %.2f, Y: %.2f, Z: %.2f",
                    entity.name, worldX, worldY, worldZ))

                -- Prepare the Discord message
                local message = string.format(
                    "Alert: Player '%s' detected near your base! Estimated position: X: %.2f, Y: %.2f, Z: %.2f",
                    entity.name, worldX, worldY, worldZ
                )

                -- Send the notification to Discord
                sendDiscordNotification(message)
            end
        end
    end

    -- Set redstone output based on whether non-whitelisted players were found
    if nonWhitelistedPlayerFound then
        setRedstoneOutput(true)
    else
        setRedstoneOutput(false)
    end
end

-- Function to add a player to the whitelist
function addPlayerToWhitelist(playerName)
    config.whitelist[playerName] = true
    saveConfig()
    print("Player '" .. playerName .. "' has been added to the whitelist.")
end

-- Function to remove a player from the whitelist
function removePlayerFromWhitelist(playerName)
    config.whitelist[playerName] = nil
    saveConfig()
    print("Player '" .. playerName .. "' has been removed from the whitelist.")
end

-- Main loop to continuously scan for players and handle commands
parallel.waitForAny(
    function()  -- Scan players loop
        while true do
            scanPlayers()
            os.sleep(5)  -- Scan every 5 seconds
        end
    end,
    function()  -- Command handling loop
        while true do
            print("Enter a command (add/remove/exit):")
            local command = read()
            if command == "add" then
                print("Enter player name to add to whitelist:")
                local playerName = read()
                addPlayerToWhitelist(playerName)
            elseif command == "remove" then
                print("Enter player name to remove from whitelist:")
                local playerName = read()
                removePlayerFromWhitelist(playerName)
            elseif command == "exit" then
                print("Exiting command loop. The detection process will continue running.")
                break
            else
                print("Unknown command. Please enter 'add', 'remove', or 'exit'.")
            end
        end
    end
)
