---@diagnostic disable: lowercase-global, undefined-field

local LuaRulesMsg = VFS.Include("common/luaUtilities/lua_rules_msg.lua")
local Sharing = VFS.Include("modules/module_handler.lua").Get("sharing")
local TransferEnums = Sharing.TransferEnums

local function GetAlliedTargetTeamID(myTeamID)
	local teamList = Spring.GetTeamList()
	for _, teamID in ipairs(teamList) do
		if teamID ~= myTeamID and Spring.AreTeamsAllied(myTeamID, teamID) then
			return teamID
		end
	end
	return nil
end

local function skip()
	return Spring.GetGameFrame() <= 0
end

local function setup()
	Test.clearMap()

	assert(Game.nativeExcessSharing == false, "this test requires Lua-owned resource sharing (Game.nativeExcessSharing must be false)")

	local team0 = Spring.GetLocalTeamID()
	local team1 = GetAlliedTargetTeamID(team0)
	assert(team1 ~= nil, "expected at least one allied target team for transfer test")
	local metal = TransferEnums.ResourceType.METAL
	local energy = TransferEnums.ResourceType.ENERGY

	SyncedRun(function(locals)
		Spring.SetTeamResource(locals.team0, "ms", 5000)
		Spring.SetTeamResource(locals.team1, "ms", 5000)
		Spring.SetTeamResource(locals.team0, "es", 5000)
		Spring.SetTeamResource(locals.team1, "es", 5000)

		Spring.SetTeamResource(locals.team0, locals.metal, 1000)
		Spring.SetTeamResource(locals.team0, locals.energy, 1000)
		Spring.SetTeamResource(locals.team1, locals.metal, 0)
		Spring.SetTeamResource(locals.team1, locals.energy, 0)
	end, 60)

	-- policy cache refreshes on the redistribution cadence (every 30 frames); wait two cycles
	Test.waitFrames(65)
end

local function cleanup()
	Test.clearMap()
end

local function test()
	local team0 = Spring.GetLocalTeamID()
	local team1 = GetAlliedTargetTeamID(team0)
	assert(team1 ~= nil, "expected at least one allied target team for transfer test")

	local modOptions = Spring.GetModOptions()
	local rse = modOptions.resource_sharing_enabled
	assert(rse == "1" or rse == 1 or rse == true, "startscript should set resource_sharing_enabled=1, got: " .. tostring(rse))

	local metalBefore = Spring.GetTeamResources(team0, "metal")
	assert(metalBefore and metalBefore > 0, "team0 should have metal to share")

	local metalReceivedBefore = Spring.GetTeamResources(team1, "metal") or 0

	Spring.SendLuaRulesMsg(LuaRulesMsg.SerializeResourceShare(team0, team1, "metal", 100))
	Test.waitFrames(2)

	local metalReceivedAfter = Spring.GetTeamResources(team1, "metal") or 0
	assert(metalReceivedAfter > metalReceivedBefore, "team1 metal should increase after share, before=" .. tostring(metalReceivedBefore) .. " after=" .. tostring(metalReceivedAfter))

	local energyReceivedBefore = Spring.GetTeamResources(team1, "energy") or 0

	Spring.SendLuaRulesMsg(LuaRulesMsg.SerializeResourceShare(team0, team1, "energy", 100))
	Test.waitFrames(2)

	local energyReceivedAfter = Spring.GetTeamResources(team1, "energy") or 0
	assert(energyReceivedAfter > energyReceivedBefore, "team1 energy should increase after share, before=" .. tostring(energyReceivedBefore) .. " after=" .. tostring(energyReceivedAfter))
end

return {
	skip = skip,
	setup = setup,
	cleanup = cleanup,
	test = test,
}
