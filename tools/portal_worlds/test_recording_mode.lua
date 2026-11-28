-- SPDX-License-Identifier: GPL-2.0-or-later
-- Run from the game root with lua5.1 tools/portal_worlds/test_recording_mode.lua.
local originalSpring = rawget(_G, "Spring")
local function Load(spectator, enabled)
	local env = {
		gadget = {},
		VFS = {
			FileExists = function()
				return false
			end,
		},
		Spring = {
			GetModOptions = function()
				return { portal_record = enabled and "1" or "0" }
			end,
			GetPlayerList = function()
				return { 0 }
			end,
			GetPlayerInfo = function()
				return "Local", true, spectator
			end,
		},
		gadgetHandler = {
			IsSyncedCode = function()
				return false
			end,
		},
	}
	setmetatable(env, { __index = _G })
	local chunk = assert(loadfile("tools/portal_worlds/dots/recorder.lua"))
	setfenv(chunk, env)
	return chunk(), env.gadget
end
local result, loadedGadget = Load(true, true)
assert(result == nil and type(rawget(loadedGadget, "Initialize")) == "function")
result, loadedGadget = Load(false, true)
assert(result == false and rawget(loadedGadget, "Initialize") == nil)
result, loadedGadget = Load(true, false)
assert(result == false and rawget(loadedGadget, "Initialize") == nil)
assert(rawget(_G, "Spring") == originalSpring, "Recorder fixture changed engine globals")
print("AI recording mode checks passed")
