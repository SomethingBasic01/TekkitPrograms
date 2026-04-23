local c = require("component")
assert(c.isAvailable("geolyzer"), "No geolyzer found")
assert(c.isAvailable("hologram"), "No hologram projector found")

local g = c.geolyzer
local h = c.hologram

-- Small, easy test area around the machine.
local sx, sz = 16, 16
local ox, oz = -8, -8

-- Source Y range around the geolyzer.
local srcY0, srcY1 = -4, 11   -- 16 layers total

-- Push the rendered scan upward so it is not buried in the floor.
local dstYBase = 9

h.clear()
pcall(h.setScale, 1)

if h.maxDepth and h.maxDepth() > 1 then
  pcall(h.setPaletteColor, 1, 0x00FF00)
  pcall(h.setPaletteColor, 2, 0x00FFFF)
  pcall(h.setPaletteColor, 3, 0xFF4040)
end

local function classify(v)
  v = tonumber(v) or 0
  if v <= 0.05 then
    return 0
  elseif v < 3 then
    return 2
  elseif v < 100 then
    return 1
  else
    return 3
  end
end

local total = 0

for hx = 1, sx do
  local rx = ox + hx - 1
  for hz = 1, sz do
    local rz = oz + hz - 1
    local col = g.scan(rx, rz, false)

    for srcY = srcY0, srcY1 do
      local idx = srcY + 33   -- maps relY -32..31 to Lua 1..64
      local val = col[idx]
      local voxel = classify(val)
      if voxel ~= 0 then
        local hy = dstYBase + (srcY - srcY0)
        if hy >= 1 and hy <= 32 then
          h.set(hx, hy, hz, voxel)
          total = total + 1
        end
      end
    end
  end
end

print("Done. Voxels drawn: " .. total)
