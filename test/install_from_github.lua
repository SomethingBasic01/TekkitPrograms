-- Simple GitHub installer/updater for HOLO-NET v3.
-- Edit BASE to your raw GitHub folder URL, then run:
--   lua install_from_github.lua
--
-- Example BASE:
-- https://raw.githubusercontent.com/YourUser/YourRepo/main/holonet_v3

local component = require("component")
local internet = require("internet")
local filesystem = require("filesystem")

assert(component.isAvailable("internet"), "No internet card found")

local BASE = "https://github.com/SomethingBasic01/TekkitPrograms/tree/d54166ae5f03b60bf99a91676ca097f9f598262a/test"
local FILES = {
  "console.lua",
  "scan_node.lua",
  "projector_node.lua",
  "README.txt",
}

local function fetch(url)
  local handle, err = internet.request(url)
  assert(handle, err or "request failed")
  local chunks = {}
  for chunk in handle do
    chunks[#chunks + 1] = chunk
  end
  return table.concat(chunks)
end

for i = 1, #FILES do
  local name = FILES[i]
  local url = BASE .. "/" .. name
  print("Downloading " .. url)
  local data = fetch(url)
  local f = assert(io.open("/home/" .. name, "w"))
  f:write(data)
  f:close()
end

print("Done. Files saved to /home/")
