local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Scenario Script",
		desc = "Controller for Scenarios basic script & triggers",
		author = "Damgam",
		date = "2021",
		license = "GNU GPL, v2 or later",
		layer = 999999,
		enabled = true,
	}
end

if gadgetHandler:IsSyncedCode() then
	isSynced = true
else
	isSynced = false
end

local decodeModoption = require("common/luaUtilities/modoption_payload").Decode

local function GetScenarioID()
	if Spring.GetModOptions().scenariooptions then
		local scenariooptions = decodeModoption(Spring.GetModOptions().scenariooptions)
		if not scenariooptions then
			Spring.Log(gadget:GetInfo().name, LOG.ERROR, "Could not decode scenariooptions")
			return nil
		end
		return scenariooptions.scenarioid
	end
	return nil
end

local scenarioid = GetScenarioID()
if not scenarioid then
	return
end

if not VFS.FileExists("singleplayer/scenarios/scenarioscripts/" .. scenarioid .. ".lua") then
	return
end

Spring.Echo("Scenario ID: " .. scenarioid)
VFS.Include("singleplayer/scenarios/scenarioscripts/" .. scenarioid .. ".lua")
