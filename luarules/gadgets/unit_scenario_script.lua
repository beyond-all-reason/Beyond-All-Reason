local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name      = "Scenario Script",
		desc      = "Controller for Scenarios basic script & triggers",
		author    = "Damgam",
		date      = "2021",
		license   = "GNU GPL, v2 or later",
		layer     = 999999,
		enabled   = true,
	}
end

if gadgetHandler:IsSyncedCode() then
    isSynced = true
else
    isSynced = false
end

local function GetScenarioID()
    if SpringShared.GetModOptions().scenariooptions then
        local scenariooptions = string.base64Decode(SpringShared.GetModOptions().scenariooptions)
        scenariooptions = Json.decode(scenariooptions)
        return scenariooptions.scenarioid
    end
    return nil
end

local scenarioid = GetScenarioID()
if not scenarioid then
	return
end

if not VFS.FileExists("singleplayer/scenarios/scenarioscripts/"..scenarioid..".lua") then
   return
end

SpringShared.Echo("Scenario ID: "..scenarioid)
VFS.Include("singleplayer/scenarios/scenarioscripts/"..scenarioid..".lua")