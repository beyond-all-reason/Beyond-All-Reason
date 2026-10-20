-- SPDX-License-Identifier: GPL-2.0-or-later
-- Run from the game root with lua5.1 tools/portal_worlds/test_recording_mode.lua.
local function Load(spectator, enabled)
	gadget = {}
	VFS = {FileExists=function() return false end}
	Spring = {GetModOptions=function() return {portal_record=enabled and "1" or "0"} end,
		GetPlayerList=function() return {0} end,
		GetPlayerInfo=function() return "Local",true,spectator end}
	gadgetHandler = {IsSyncedCode=function() return false end}
	return assert(loadfile("tools/portal_worlds/dots/recorder.lua"))()
end
assert(Load(true,true) == nil and gadget.Initialize)
assert(Load(false,true) == false and gadget.Initialize == nil)
assert(Load(true,false) == false and gadget.Initialize == nil)
print("AI recording mode checks passed")
