local particle = peripheral.find("particle")

if not particle then
    print("Particle peripheral not found.")
    return
end

local particles = {}
local running = false

local function saveConfiguration()
    print("Enter a name for this configuration:")
    local configName = read()

    local file = fs.open(configName .. ".txt", "w")
    file.write(textutils.serialize(particles))
    file.close()
    print("Configuration '" .. configName .. "' saved.")
end

local function loadConfiguration(configName)
    if fs.exists(configName .. ".txt") then
        local file = fs.open(configName .. ".txt", "r")
        particles = textutils.unserialize(file.readAll())
        file.close()
        print("Configuration '" .. configName .. "' loaded.")
        return true
    else
        print("Configuration '" .. configName .. "' not found.")
        return false
    end
end

local function saveDefaultConfigName(configName)
    local file = fs.open("default_config.txt", "w")
    file.write(configName)
    file.close()
    print("Default configuration '" .. configName .. "' set for auto-load on launch.")
end

local function getDefaultConfigName()
    if fs.exists("default_config.txt") then
        local file = fs.open("default_config.txt", "r")
        local configName = file.readAll()
        file.close()
        return configName
    else
        return nil
    end
end

local function addParticle()
    print("Enter a unique ID for this particle:")
    local id = read()

    if particles[id] then
        print("Particle " .. id .. " already exists. Use 'Edit Particle' to modify it.")
        return
    end

    print("Enter the particle name (e.g., minecraft:flame):")
    local name = read()

    print("Enter X, Y, Z coordinates separated by spaces (e.g., 0 1 0):")
    local x, y, z = string.match(read(), "(%-?%d+)%s+(%-?%d+)%s+(%-?%d+)")

    print("Enter velocities for X, Y, Z separated by spaces (e.g., 0.1 0.5 0):")
    local vx, vy, vz = string.match(read(), "(%-?%d*%.?%d+)%s+(%-?%d*%.?%d+)%s+(%-?%d*%.?%d+)")

    print("Enter delay between spawns (0-999, in seconds):")
    local delay = tonumber(read())

    particles[id] = {
        name = name,
        x = tonumber(x),
        y = tonumber(y),
        z = tonumber(z),
        vx = tonumber(vx),
        vy = tonumber(vy),
        vz = tonumber(vz),
        delay = math.min(delay, 999)
    }

    print("Particle " .. id .. " added.")
end

local function editParticle()
    print("Enter the ID of the particle to edit:")
    local id = read()

    if not particles[id] then
        print("Particle ID not found. Use 'Add Particle' to create a new one.")
        return
    end

    while true do
        print("\nEditing Particle: " .. id)
        print("1. Edit Particle Type (" .. particles[id].name .. ")")
        print("2. Edit Coordinates (X: " .. particles[id].x .. ", Y: " .. particles[id].y .. ", Z: " .. particles[id].z .. ")")
        print("3. Edit Velocities (VX: " .. particles[id].vx .. ", VY: " .. particles[id].vy .. ", VZ: " .. particles[id].vz .. ")")
        print("4. Edit Delay (" .. particles[id].delay .. " seconds)")
        print("5. Done Editing")
        print("Enter a choice (1-5):")

        local choice = read()

        if choice == "1" then
            print("Enter the new particle name (e.g., minecraft:flame):")
            particles[id].name = read()
        elseif choice == "2" then
            print("Enter new X, Y, Z coordinates separated by spaces (e.g., 0 1 0):")
            local x, y, z = string.match(read(), "(%-?%d+)%s+(%-?%d+)%s+(%-?%d+)")
            particles[id].x, particles[id].y, particles[id].z = tonumber(x), tonumber(y), tonumber(z)
        elseif choice == "3" then
            print("Enter new velocities for X, Y, Z separated by spaces (e.g., 0.1 0.5 0):")
            local vx, vy, vz = string.match(read(), "(%-?%d*%.?%d+)%s+(%-?%d*%.?%d+)%s+(%-?%d*%.?%d+)")
            particles[id].vx, particles[id].vy, particles[id].vz = tonumber(vx), tonumber(vy), tonumber(vz)
        elseif choice == "4" then
            print("Enter new delay between spawns (0-999, in seconds):")
            particles[id].delay = tonumber(read())
        elseif choice == "5" then
            print("Finished editing particle " .. id .. ".")
            break
        else
            print("Invalid choice. Please enter a number between 1 and 5.")
        end
    end
end

local function deleteParticle()
    print("Enter the ID of the particle to delete:")
    local id = read()
    if particles[id] then
        particles[id] = nil
        print("Particle " .. id .. " deleted.")
    else
        print("Particle ID not found.")
    end
end

local function spawnParticles()
    while true do
        if running then
            for id, p in pairs(particles) do
                particle.spawn(p.name, p.x, p.y, p.z, p.vx, p.vy, p.vz)
                sleep(p.delay)
            end
        else
            sleep(0.1)
        end
    end
end

local function displayMenu()
    print("\nParticle Controller Menu")
    print("1. Add Particle")
    print("2. Edit Particle")
    print("3. Delete Particle")
    print("4. Save Configuration")
    print("5. Load Configuration")
    print("6. Set Default Configuration for Auto-Load")
    print("7. Start Spawning")
    print("8. Stop Spawning")
    print("9. Exit")
    print("Enter a choice (1-9):")
end

local function manageParticles()
    while true do
        displayMenu()
        local choice = read()
        
        if choice == "1" then
            addParticle()
        elseif choice == "2" then
            editParticle()
        elseif choice == "3" then
            deleteParticle()
        elseif choice == "4" then
            saveConfiguration()
        elseif choice == "5" then
            print("Enter the name of the configuration to load:")
            local configName = read()
            loadConfiguration(configName)
        elseif choice == "6" then
            print("Enter the name of the configuration to set as default:")
            local configName = read()
            saveDefaultConfigName(configName)
        elseif choice == "7" then
            running = true
            print("Spawning started.")
        elseif choice == "8" then
            running = false
            print("Spawning paused. Press any key to return to the menu.")
            os.pullEvent("key")  -- Wait for any key press to return to the menu
        elseif choice == "9" then
            print("Exiting program.")
            running = false
            break
        else
            print("Invalid choice. Please enter a number between 1 and 9.")
        end
    end
end

local defaultConfig = getDefaultConfigName()
if defaultConfig and loadConfiguration(defaultConfig) then
    running = true
    print("Auto-spawning started with configuration '" .. defaultConfig .. "'.")
end

parallel.waitForAny(spawnParticles, manageParticles)
