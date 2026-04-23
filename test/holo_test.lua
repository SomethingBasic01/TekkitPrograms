local c = require("component")
assert(c.isAvailable("hologram"), "No hologram projector found")

local h = c.hologram
h.clear()
pcall(h.setScale, 1)

for x = 20, 28 do
  for y = 10, 18 do
    for z = 20, 28 do
      h.set(x, y, z, 1)
    end
  end
end

print("Hologram cube drawn.")
