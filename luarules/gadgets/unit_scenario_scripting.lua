

APIFilesList = VFS.DirList('luarules/configs/scenarioscripts/API/','*.lua')
for i = 1,#APIFilesList do
	VFS.Include(APIFilesList[i])
	Spring.Echo("Scenario API File Directory: " ..APIFilesList[i])
end

if gadgetHandler:IsSyncedCode() then
	isSynced = true
else
	isSynced = false
end

local function GetScenarioID()
    if Spring.GetModOptions().scenariooptions then
        local scenariooptions = string.base64Decode(Spring.GetModOptions().scenariooptions)
        scenariooptions = Spring.Utilities.json.decode(scenariooptions)
        return scenariooptions.scenarioid
    end
    return nil
end

local scenarioid = GetScenarioID()
if not scenarioid then
	return
end

if not VFS.FileExists("luarules/configs/scenarioscripts/"..scenarioid..".lua") then
   return
end


function gadget:GetInfo()
	return {
		name      = "Scenario Scripting",
		desc      = "Controller for Scenarios, including NPC and AI controllers and objective triggers",
		author    = "Damgam",
		date      = "2021",
		license   = "CC BY NC ND",
		layer     = 1000000,
		enabled   = true,
	}
end


Spring.Echo("Scenario ID: "..scenarioid)
VFS.Include("luarules/configs/scenarioscripts/"..scenarioid..".lua")
