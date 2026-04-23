local component = require("component")
local serialization = require("serialization")
local term = require("term")

assert(component.isAvailable("geolyzer"), "No geolyzer found")
assert(component.isAvailable("hologram"), "No hologram projector found")

local g = component.geolyzer
local h = component.hologram

local CFG_PATH = "/home/geo_local_ui.cfg"

local defaults = {
  mode = "solid",

  offsetX = -8,
  offsetZ = -8,
  sizeX = 16,
  sizeZ = 16,

  yMin = -4,
  yMax = 11,
  dstYBase = 9,

  center = true,
  flipX = false,
  flipZ = false,
  swapXZ = false,

  airMax = 0.05,
  denseMin = 4.0,

  scale = 1,

  color1 = 0x00FF00,
  color2 = 0x00FFFF,
  color3 = 0xFF4040,
}

local RANGE_HINTS = {
  mode = "solid | void | dense | bands",
  offsetX = "recommended: -24..24 (script allows -128..127)",
  offsetZ = "recommended: -24..24 (script allows -128..127)",
  sizeX = "1..48",
  sizeZ = "1..48",
  yMin = "-32..31",
  yMax = "-32..31",
  dstYBase = "1..32",
  airMax = "recommended: 0.00..0.20",
  denseMin = "recommended: 2.0..6.0",
  scale = "0.33..3",
  color = "0x000000..0xFFFFFF",
}

local cfg = {}

local function holoDepth()
  if h.maxDepth then
    local ok, depth = pcall(h.maxDepth)
    if ok and type(depth) == "number" then
      return depth
    end
  end
  return 1
end

local function copyDefaults()
  for k, v in pairs(defaults) do
    if cfg[k] == nil then
      cfg[k] = v
    end
  end
end

local function loadCfg()
  local f = io.open(CFG_PATH, "r")
  if not f then
    cfg = {}
    copyDefaults()
    return
  end

  local raw = f:read("*a")
  f:close()

  local ok, data = pcall(serialization.unserialize, raw)
  if ok and type(data) == "table" then
    cfg = data
  else
    cfg = {}
  end
  copyDefaults()
end

local function saveCfg()
  local f, err = io.open(CFG_PATH, "w")
  if not f then
    io.stderr:write("Failed to save config: " .. tostring(err) .. "\n")
    return false
  end
  f:write(serialization.serialize(cfg))
  f:close()
  return true
end

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function promptNumber(label, current, minv, maxv, integerOnly, hint)
  if hint then print(label .. " range: " .. hint) end
  io.write(string.format("%s [%s]: ", label, tostring(current)))
  local s = io.read()
  if not s or s == "" then return current end
  local n = tonumber(s)
  if not n then return current end
  if integerOnly then n = math.floor(n) end
  if minv then n = math.max(minv, n) end
  if maxv then n = math.min(maxv, n) end
  return n
end

local function promptBool(label, current)
  io.write(string.format("%s [%s] (y/n): ", label, current and "y" or "n"))
  local s = io.read()
  if not s or s == "" then return current end
  s = s:lower()
  if s == "y" or s == "yes" or s == "1" or s == "true" then return true end
  if s == "n" or s == "no" or s == "0" or s == "false" then return false end
  return current
end

local function promptHex(label, current)
  print(label .. " range: " .. RANGE_HINTS.color)
  io.write(string.format("%s [0x%06X]: ", label, current))
  local s = io.read()
  if not s or s == "" then return current end
  s = s:gsub("^0[xX]", "")
  local n = tonumber(s, 16)
  if not n then return current end
  return clamp(math.floor(n), 0x000000, 0xFFFFFF)
end

local modes = { "solid", "void", "dense", "bands" }

local function nextMode()
  for i = 1, #modes do
    if modes[i] == cfg.mode then
      cfg.mode = modes[(i % #modes) + 1]
      return
    end
  end
  cfg.mode = modes[1]
end

local function pause(msg)
  print("")
  io.write((msg or "Press Enter...") )
  io.read()
end

local function setPalette()
  local depth = holoDepth()
  pcall(h.setPaletteColor, 1, cfg.color1)
  if depth > 1 then
    pcall(h.setPaletteColor, 2, cfg.color2)
    pcall(h.setPaletteColor, 3, cfg.color3)
  end
end

local function classify(v)
  v = tonumber(v) or 0
  local depth = holoDepth()

  if cfg.mode == "void" then
    if v <= cfg.airMax then
      return 1
    end
    return 0
  end

  if cfg.mode == "solid" then
    if v <= cfg.airMax then
      return 0
    end
    return 1
  end

  if cfg.mode == "dense" then
    if v >= cfg.denseMin then
      return depth > 1 and 3 or 1
    end
    return 0
  end

  -- bands
  if v <= cfg.airMax then
    return 0
  end

  if depth <= 1 then
    return 1
  end

  if v < 1.5 then
    return 1
  elseif v < cfg.denseMin then
    return 2
  else
    return 3
  end
end

local function mapXZ(hx, hz)
  local sizeDrawX = cfg.swapXZ and cfg.sizeZ or cfg.sizeX
  local sizeDrawZ = cfg.swapXZ and cfg.sizeX or cfg.sizeZ

  local drawX, drawZ = hx, hz

  if cfg.swapXZ then
    drawX, drawZ = drawZ, drawX
  end

  if cfg.flipX then
    drawX = sizeDrawX - drawX + 1
  end

  if cfg.flipZ then
    drawZ = sizeDrawZ - drawZ + 1
  end

  local baseX, baseZ = 1, 1
  if cfg.center then
    baseX = math.floor((48 - sizeDrawX) / 2) + 1
    baseZ = math.floor((48 - sizeDrawZ) / 2) + 1
  end

  return baseX + drawX - 1, baseZ + drawZ - 1
end

local function drawScan()
  cfg.sizeX = clamp(math.floor(cfg.sizeX), 1, 48)
  cfg.sizeZ = clamp(math.floor(cfg.sizeZ), 1, 48)
  cfg.yMin = clamp(math.floor(cfg.yMin), -32, 31)
  cfg.yMax = clamp(math.floor(cfg.yMax), -32, 31)

  if cfg.yMin > cfg.yMax then
    cfg.yMin, cfg.yMax = cfg.yMax, cfg.yMin
  end

  local height = cfg.yMax - cfg.yMin + 1
  if height > 32 then
    cfg.yMax = cfg.yMin + 31
    height = 32
  end

  cfg.dstYBase = clamp(math.floor(cfg.dstYBase), 1, 32)

  term.clear()
  term.setCursor(1, 1)
  print("Scanning...")
  print(string.format("mode=%s  x=%d..%d  z=%d..%d  y=%d..%d",
    cfg.mode,
    cfg.offsetX, cfg.offsetX + cfg.sizeX - 1,
    cfg.offsetZ, cfg.offsetZ + cfg.sizeZ - 1,
    cfg.yMin, cfg.yMax))
  print(string.format("projector depth=%d  scale=%.2f", holoDepth(), cfg.scale))

  h.clear()
  pcall(h.setScale, cfg.scale)
  setPalette()

  local total = 0

  for hx = 1, cfg.sizeX do
    local rx = cfg.offsetX + hx - 1

    for hz = 1, cfg.sizeZ do
      local rz = cfg.offsetZ + hz - 1
      local col = g.scan(rx, rz, false)

      for srcY = cfg.yMin, cfg.yMax do
        local idx = srcY + 33
        local val = col and col[idx] or nil
        local voxel = classify(val)

        if voxel ~= 0 then
          local hy = cfg.dstYBase + (srcY - cfg.yMin)
          if hy >= 1 and hy <= 32 then
            local drawX, drawZ = mapXZ(hx, hz)
            if drawX >= 1 and drawX <= 48 and drawZ >= 1 and drawZ <= 48 then
              h.set(drawX, hy, drawZ, voxel)
              total = total + 1
            end
          end
        end
      end
    end

    term.setCursor(1, 5)
    io.write(string.format("Progress: %d/%d columns   ", hx, cfg.sizeX))
  end

  term.setCursor(1, 7)
  print("Done. Voxels drawn: " .. total)
  if holoDepth() <= 1 then
    print("Tier 1 projector detected: only color1 can be shown.")
  else
    print("Tier 2 projector detected: bands/dense can use up to 3 colors.")
  end
  pause()
end

local function clearHolo()
  h.clear()
  term.clear()
  term.setCursor(1, 1)
  print("Hologram cleared.")
  pause()
end

local function editArea()
  term.clear()
  term.setCursor(1, 1)
  print("Edit horizontal scan area")
  print("")
  cfg.offsetX = promptNumber("offsetX", cfg.offsetX, -128, 127, true, RANGE_HINTS.offsetX)
  cfg.offsetZ = promptNumber("offsetZ", cfg.offsetZ, -128, 127, true, RANGE_HINTS.offsetZ)
  cfg.sizeX   = promptNumber("sizeX",   cfg.sizeX,   1, 48, true, RANGE_HINTS.sizeX)
  cfg.sizeZ   = promptNumber("sizeZ",   cfg.sizeZ,   1, 48, true, RANGE_HINTS.sizeZ)
  saveCfg()
end

local function editVertical()
  term.clear()
  term.setCursor(1, 1)
  print("Edit vertical scan range")
  print("")
  cfg.yMin = promptNumber("yMin", cfg.yMin, -32, 31, true, RANGE_HINTS.yMin)
  cfg.yMax = promptNumber("yMax", cfg.yMax, -32, 31, true, RANGE_HINTS.yMax)
  cfg.dstYBase = promptNumber("dstYBase", cfg.dstYBase, 1, 32, true, RANGE_HINTS.dstYBase)
  saveCfg()
end

local function editThresholds()
  term.clear()
  term.setCursor(1, 1)
  print("Edit thresholds")
  print("")
  cfg.airMax = promptNumber("airMax", cfg.airMax, -10, 10, false, RANGE_HINTS.airMax)
  cfg.denseMin = promptNumber("denseMin", cfg.denseMin, -10, 999999, false, RANGE_HINTS.denseMin)
  saveCfg()
end

local function editView()
  term.clear()
  term.setCursor(1, 1)
  print("Edit projector/view settings")
  print("")
  print("scale range: " .. RANGE_HINTS.scale)
  cfg.center = promptBool("center", cfg.center)
  cfg.flipX = promptBool("flipX", cfg.flipX)
  cfg.flipZ = promptBool("flipZ", cfg.flipZ)
  cfg.swapXZ = promptBool("swapXZ", cfg.swapXZ)
  cfg.scale = promptNumber("scale", cfg.scale, 0.33, 3, false, RANGE_HINTS.scale)
  saveCfg()
end

local function editColors()
  term.clear()
  term.setCursor(1, 1)
  print("Edit palette colors")
  print("")
  print("Projector color depth: " .. holoDepth())
  if holoDepth() <= 1 then
    print("This is a tier 1 projector: only color1 is visible.")
  else
    print("This is a tier 2 projector: color1/color2/color3 are available.")
  end
  print("")
  cfg.color1 = promptHex("color1", cfg.color1)
  cfg.color2 = promptHex("color2", cfg.color2)
  cfg.color3 = promptHex("color3", cfg.color3)
  saveCfg()
end

local function resetDefaults()
  cfg = {}
  copyDefaults()
  saveCfg()
  term.clear()
  term.setCursor(1, 1)
  print("Config reset to defaults.")
  pause()
end

local function showHelp()
  term.clear()
  term.setCursor(1, 1)
  print("Geo Local UI - Help")
  print("-------------------")
  print("Modes:")
  print("  solid : show non-air blocks")
  print("  void  : show air/caves")
  print("  dense : show only high-hardness blocks")
  print("  bands : 1/2/3-color density bands on tier 2 projectors")
  print("")
  print("Ranges:")
  print("  offsetX, offsetZ : " .. RANGE_HINTS.offsetX)
  print("  sizeX, sizeZ     : " .. RANGE_HINTS.sizeX)
  print("  yMin, yMax       : " .. RANGE_HINTS.yMin)
  print("  dstYBase         : " .. RANGE_HINTS.dstYBase)
  print("  scale            : " .. RANGE_HINTS.scale)
  print("  airMax           : " .. RANGE_HINTS.airMax)
  print("  denseMin         : " .. RANGE_HINTS.denseMin)
  print("  colors           : " .. RANGE_HINTS.color)
  print("")
  print("Notes:")
  print("  - Tier 1 holograms only display color1.")
  print("  - Tier 2 holograms can display up to 3 colors.")
  print("  - If the map looks mirrored, toggle flipX/flipZ/swapXZ.")
  pause()
end

local function showStatus()
  term.clear()
  term.setCursor(1, 1)
  print("Geo Local UI v2")
  print("---------------")
  print("Projector depth: " .. holoDepth() .. (holoDepth() > 1 and " (tier 2 / multi-color)" or " (tier 1 / single-color)"))
  print("Mode:      " .. cfg.mode .. " [" .. RANGE_HINTS.mode .. "]")
  print("Area:      x=" .. cfg.offsetX .. " z=" .. cfg.offsetZ .. " size=" .. cfg.sizeX .. "x" .. cfg.sizeZ)
  print("Y range:   " .. cfg.yMin .. " .. " .. cfg.yMax .. "  -> dstYBase=" .. cfg.dstYBase)
  print("View:      center=" .. tostring(cfg.center)
      .. " flipX=" .. tostring(cfg.flipX)
      .. " flipZ=" .. tostring(cfg.flipZ)
      .. " swapXZ=" .. tostring(cfg.swapXZ))
  print("Threshold: airMax=" .. tostring(cfg.airMax) .. " denseMin=" .. tostring(cfg.denseMin))
  print("Scale:     " .. tostring(cfg.scale))
  print(string.format("Colors:    1=0x%06X  2=0x%06X  3=0x%06X", cfg.color1, cfg.color2, cfg.color3))
  print("")
  print("1  Scan now")
  print("2  Cycle mode")
  print("3  Edit area")
  print("4  Edit vertical range")
  print("5  Edit thresholds")
  print("6  Edit view/orientation")
  print("7  Edit colors")
  print("8  Clear hologram")
  print("9  Save config")
  print("H  Help / ranges")
  print("R  Reset defaults")
  print("0  Quit")
  print("")
  io.write("> ")
end

loadCfg()

while true do
  showStatus()
  local choice = io.read()
  if choice then choice = tostring(choice):lower() end

  if choice == "1" then
    drawScan()
  elseif choice == "2" then
    nextMode()
    saveCfg()
  elseif choice == "3" then
    editArea()
  elseif choice == "4" then
    editVertical()
  elseif choice == "5" then
    editThresholds()
  elseif choice == "6" then
    editView()
  elseif choice == "7" then
    editColors()
  elseif choice == "8" then
    clearHolo()
  elseif choice == "9" then
    term.clear()
    term.setCursor(1, 1)
    if saveCfg() then
      print("Config saved to " .. CFG_PATH)
    else
      print("Failed to save config.")
    end
    pause()
  elseif choice == "h" then
    showHelp()
  elseif choice == "r" then
    resetDefaults()
  elseif choice == "0" then
    term.clear()
    term.setCursor(1, 1)
    break
  end
end
