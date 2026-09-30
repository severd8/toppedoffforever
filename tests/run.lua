-- Runs the ToppedOff Forever test suite outside the game.
-- From the repo root:  lua5.1 tests/run.lua
-- Exits with code 1 (and prints the error) if any test fails.

ADDON_DIR = "."
local realPrint = print

dofile("tests/wowstub.lua")   -- fake WoW API (replaces print with a logger)

local ok, err = xpcall(function() dofile("tests/run_tests.lua") end, debug.traceback)

for _, line in ipairs(LOG) do
    if line:find("^STEP") or line:find("PASSED") then realPrint(line) end
end
if not ok then
    realPrint("FAILED: " .. tostring(err))
    os.exit(1)
end
