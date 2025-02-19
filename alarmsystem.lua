-------------------------------
-- Entity Alert & Radar System
-- Using DiscordHook for sending/polling Discord commands.
-- Uses the manipulator's sensor module.
-- Player detection via meta.food.hunger
-- Prompts for channel/token/url on first startup.
-- 'debugdiscord' prints raw JSON locally or in Discord.
-------------------------------

local DEBUG = true  -- Set to false if you don't want debug prints in the console.

-------------------------------
-- CONFIGURATION FILE HANDLING
-------------------------------
local configFile = "config"
local config = {
  whitelist = {},
  pulseMob = true,
  pulsePlayer = true,
  radarMode = false,
  discordEnabled = true,
  webhookURL = "https://discord.com/api/webhooks/your_webhook_here",
  botName = "Base Defence Bot",
  botAvatar = nil,
  discordChannel = "your_channel_id_here",
  botToken = "your_bot_token_here",
  origin = { x = 0, y = 0, z = 0 },
  radarRotation = 0,
  displayWhitelistedOnRadar = true
}

local function loadConfig()
  if fs.exists(configFile) then
    local file = fs.open(configFile, "r")
    local data = file.readAll()
    file.close()
    local conf = textutils.unserialize(data)
    if conf then config = conf end
  end
end

local function saveConfig()
  local file = fs.open(configFile, "w")
  file.write(textutils.serialize(config))
  file.close()
end

-------------------------------
-- PROMPT FOR DISCORD SETTINGS
-------------------------------
local function promptDiscordSettings()
  -- Only prompt if the placeholders are still present or empty
  local needsPrompt = false

  if not config.discordChannel or config.discordChannel == "" or config.discordChannel == "your_channel_id_here" then
    needsPrompt = true
  end
  if not config.botToken or config.botToken == "" or config.botToken == "your_bot_token_here" then
    needsPrompt = true
  end
  if not config.webhookURL or config.webhookURL == "" or config.webhookURL == "https://discord.com/api/webhooks/your_webhook_here" then
    needsPrompt = true
  end

  if needsPrompt then
    print("=== Discord Setup ===")
    print("It seems this is your first time running or your config is incomplete.")
    print("Please enter your Discord channel ID, bot token, and webhook URL.")
    print()

    if not config.discordChannel or config.discordChannel == "" or config.discordChannel == "your_channel_id_here" then
      write("Enter your Discord channel ID: ")
      config.discordChannel = read()
    end

    if not config.botToken or config.botToken == "" or config.botToken == "your_bot_token_here" then
      write("Enter your Discord bot token: ")
      config.botToken = read()
    end

    if not config.webhookURL or config.webhookURL == "" or config.webhookURL == "https://discord.com/api/webhooks/your_webhook_here" then
      write("Enter your Discord webhook URL: ")
      config.webhookURL = read()
    end

    saveConfig()
    print("Settings saved to config file.")
    print("Please restart the program to apply changes if needed.")
    print()
  end
end

-------------------------------
-- LOAD CONFIG + PROMPT
-------------------------------
loadConfig()
promptDiscordSettings()
-- Reload config in case we just saved new values.
loadConfig()

-------------------------------
-- PERIPHERAL SETUP
-------------------------------
local modules = peripheral.find("manipulator")
if not modules then error("Cannot find manipulator") end

if not modules.hasModule("plethora:sensor") then
  error("Cannot find entity sensor module on the manipulator")
end

local function scanEntities()
  return modules.sense()
end

local function getMeta(entity)
  if entity and entity.id then
    return modules.getMetaByID(entity.id)
  end
  return nil
end

local monitor = peripheral.find("monitor")
if not monitor then error("Monitor not found!") end

if not redstone then error("Redstone API not available!") end

-------------------------------
-- DISCORD INTEGRATION (sending)
-------------------------------
local DiscordHook = require("DiscordHook")
local hookSuccess, hook = DiscordHook.createWebhook(config.webhookURL)
if not hookSuccess then
  error("Webhook connection failed! Reason: " .. hook)
end

local function discordSendMessage(message)
  if config.discordEnabled then
    local success, err = pcall(function()
      hook.send(message, config.botName, config.botAvatar)
    end)
    if DEBUG and not success then
      print("DEBUG: Error sending message to Discord: " .. tostring(err))
    end
  end
end

-------------------------------
-- FORWARD DECLARATION
-------------------------------
local processCommand

-------------------------------
-- DISCORD POLLER (for receiving commands)
-------------------------------
local lastMessageID = nil
local lastDiscordRaw = ""

local function pollDiscordMessages()
  while true do
    local url = "https://discord.com/api/v9/channels/" .. config.discordChannel .. "/messages?limit=5"
    if lastMessageID then
      url = url .. "&after=" .. lastMessageID
    end
    local headers = {
      ["Authorization"] = "Bot " .. config.botToken,
      ["User-Agent"] = "DiscordBot (ComputerCraft, 1.0)"
    }
    local response = http.get(url, headers)
    if response then
      local body = response.readAll()
      lastDiscordRaw = body
      response.close()
      local success, messages = pcall(textutils.unserializeJSON, body)
      if success and type(messages) == "table" then
        local toProcess = {}
        for i = #messages, 1, -1 do
          local msg = messages[i]
          if not msg.author.bot then
            table.insert(toProcess, msg)
          end
          if (not lastMessageID) or (tonumber(msg.id) > tonumber(lastMessageID)) then
            lastMessageID = msg.id
          end
        end
        for _, msg in ipairs(toProcess) do
          local content = msg.content:gsub("^%s*(.-)%s*$", "%1")
          if DEBUG then
            print("DEBUG: Received Discord command -> [" .. content .. "]")
          end
          processCommand(content, "discord")
        end
      else
        if DEBUG then print("DEBUG: Error decoding Discord response.") end
      end
    else
      if DEBUG then print("DEBUG: Failed to poll Discord messages.") end
    end
    sleep(3)
  end
end

-------------------------------
-- UTILITY FUNCTIONS
-------------------------------
local function computeDistance(x, y, z)
  return math.sqrt(x*x + y*y + z*z)
end

local function pulseRedstone(entityType)
  if entityType == "mob" and config.pulseMob then
    redstone.setOutput("left", true)
    sleep(0.5)
    redstone.setOutput("left", false)
  elseif entityType == "player" and config.pulsePlayer then
    redstone.setOutput("right", true)
    sleep(0.5)
    redstone.setOutput("right", false)
  end
end

-------------------------------
-- COMMAND PROCESSING
-------------------------------
processCommand = function(cmd, source)
  local command, rest = cmd:match("^(%S+)%s*(.*)$")
  command = command and command:lower() or ""
  rest = rest or ""

  if DEBUG then
    print("DEBUG: processCommand -> command=[" .. command .. "], rest=[" .. rest .. "], source=[" .. source .. "]")
  end

  if command == "addwhitelist" then
    if rest ~= "" then
      config.whitelist[rest] = true
      saveConfig()
      if source == "discord" then
        discordSendMessage("Whitelist updated: added " .. rest)
      end
    else
      print("Usage: addwhitelist <entityName>")
    end

  elseif command == "removewhitelist" then
    if rest ~= "" then
      config.whitelist[rest] = nil
      saveConfig()
      if source == "discord" then
        discordSendMessage("Whitelist updated: removed " .. rest)
      end
    else
      print("Usage: removewhitelist <entityName>")
    end

  elseif command == "togglepulse" then
    if rest:lower() == "mob" then
      config.pulseMob = not config.pulseMob
      saveConfig()
      if source == "discord" then
        discordSendMessage("Mob pulse toggled: " .. tostring(config.pulseMob))
      end
    elseif rest:lower() == "player" then
      config.pulsePlayer = not config.pulsePlayer
      saveConfig()
      if source == "discord" then
        discordSendMessage("Player pulse toggled: " .. tostring(config.pulsePlayer))
      end
    else
      print("Usage: togglepulse mob|player")
    end

  elseif command == "override" then
    if rest:lower() == "mob" then
      pulseRedstone("mob")
      if source == "discord" then
        discordSendMessage("Manual override: mob pulse triggered")
      end
    elseif rest:lower() == "player" then
      pulseRedstone("player")
      if source == "discord" then
        discordSendMessage("Manual override: player pulse triggered")
      end
    else
      print("Usage: override mob|player")
    end

  elseif command == "toggleradar" then
    config.radarMode = not config.radarMode
    saveConfig()
    if source == "discord" then
      discordSendMessage("Radar mode toggled: " .. tostring(config.radarMode))
    end

  elseif command == "setorigin" then
    local x, y, z = rest:match("^(%-?%d+)%s+(%-?%d+)%s+(%-?%d+)$")
    if x and y and z then
      config.origin = { x = tonumber(x), y = tonumber(y), z = tonumber(z) }
      saveConfig()
      if source == "discord" then
        discordSendMessage("Origin updated to: (" .. x .. ", " .. y .. ", " .. z .. ")")
      end
    else
      print("Usage: setorigin <x> <y> <z>")
    end

  elseif command == "setrotation" then
    local angle = tonumber(rest)
    if angle and (angle == 0 or angle == 90 or angle == 180 or angle == 270) then
      config.radarRotation = angle
      saveConfig()
      if source == "discord" then
        discordSendMessage("Radar rotation updated to: " .. angle .. " degrees")
      end
    else
      print("Usage: setrotation <0|90|180|270>")
    end

  elseif command == "setwebhook" then
    if rest ~= "" then
      config.webhookURL = rest
      saveConfig()
      local success, newHook = DiscordHook.createWebhook(config.webhookURL)
      if success then
        hook = newHook
        if source == "discord" then
          discordSendMessage("Webhook URL updated.")
        end
      end
    else
      print("Usage: setwebhook <url>")
    end

  elseif command == "setbotname" then
    if rest ~= "" then
      config.botName = rest
      saveConfig()
      if source == "discord" then
        discordSendMessage("Bot name updated to: " .. rest)
      end
    else
      print("Usage: setbotname <name>")
    end

  elseif command == "listsensor" then
    local entities = scanEntities()
    local output = textutils.serialize(entities)
    if source == "discord" then
      discordSendMessage("Sensor Data: " .. output)
    else
      print("Sensor Data:")
      print(output)
    end

  elseif command == "listsensormeta" then
    local entities = scanEntities()
    local metaOutput = ""
    for i, e in ipairs(entities) do
      local meta = getMeta(e)
      metaOutput = metaOutput .. ("Entity " .. i .. ":\n")
      if meta then
        metaOutput = metaOutput .. (textutils.serialize(meta) .. "\n")
      else
        metaOutput = metaOutput .. ("No meta data.\n")
      end
    end
    if source == "discord" then
      discordSendMessage("Sensor Meta:\n" .. metaOutput)
    else
      print(metaOutput)
    end

  elseif command == "debugdiscord" then
    if source == "discord" then
      local snippet = lastDiscordRaw:sub(1,512)
      discordSendMessage("Full Discord Raw JSON (first 512 chars): " .. snippet)
    else
      -- typed locally
      print("Local debugdiscord requested.")
      print("Full Discord Raw JSON:")
      print(lastDiscordRaw)
    end

  else
    print("Unknown command: " .. cmd)
  end
end

-------------------------------
-- MAIN DETECTION & DISPLAY LOOP
-------------------------------
local function detectionLoop()
  while true do
    local allEntities = scanEntities()
    local listEntities = {}
    local radarEntities = {}
    
    for _, entity in ipairs(allEntities) do
      local entityName = entity.name or entity.type or "Unknown"
      local sx = entity.x or 0
      local sy = entity.y or 0
      local sz = entity.z or 0
      local distance = computeDistance(sx, sy, sz)

      local worldX = config.origin.x + sx
      local worldY = config.origin.y + sy
      local worldZ = config.origin.z + sz

      local meta = getMeta(entity)
      local etype = "mob"
      if meta and meta.food and type(meta.food.hunger) == "number" then
        etype = "player"
      end

      if not config.whitelist[entityName] then
        local msg = string.format(
          "%s at (%d, %d, %d) - %.1f blocks away.",
          entityName, worldX, worldY, worldZ, distance
        )
        discordSendMessage(msg)
        table.insert(listEntities, {
          name = entityName,
          worldX = worldX,
          worldY = worldY,
          worldZ = worldZ,
          distance = distance
        })
        pulseRedstone(etype)
      end

      table.insert(radarEntities, {
        name = entityName,
        x = worldX,
        z = worldZ
      })
    end

    monitor.clear()
    monitor.setCursorPos(1, 1)
    monitor.write("Entity Alert System")

    if not config.radarMode then
      local line = 2
      for _, entity in ipairs(listEntities) do
        monitor.setCursorPos(1, line)
        local str = string.format(
          "%s: (%d,%d,%d) %.1f blocks",
          entity.name, entity.worldX, entity.worldY, entity.worldZ, entity.distance
        )
        monitor.write(str)
        line = line + 1
      end
    else
      local w, h = monitor.getSize()
      local centerX, centerY = math.floor(w / 2), math.floor(h / 2)
      monitor.clear()
      monitor.setCursorPos(centerX, centerY)
      monitor.write("O")
      for _, entity in ipairs(radarEntities) do
        local dx = entity.x - config.origin.x
        local dz = entity.z - config.origin.z
        local rx, rz = dx, dz
        if config.radarRotation == 90 then
          rx, rz = dz, -dx
        elseif config.radarRotation == 180 then
          rx, rz = -dx, -dz
        elseif config.radarRotation == 270 then
          rx, rz = -dz, dx
        end
        local x = centerX + math.floor(rx)
        local y = centerY + math.floor(rz)
        if x >= 1 and x <= w and y >= 1 and y <= h then
          monitor.setCursorPos(x, y)
          local symbol = "*"
          if config.whitelist[entity.name] then
            symbol = "W"
          end
          monitor.write(symbol)
        end
      end
    end
    
    sleep(1)
  end
end

-------------------------------
-- PARALLEL TASKS
-------------------------------
parallel.waitForAny(
  function()
    while true do
      term.write("> ")
      local input = read()
      processCommand(input, "local")
    end
  end,
  pollDiscordMessages,
  detectionLoop
)
