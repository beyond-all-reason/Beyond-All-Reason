---@diagnostic disable: lowercase-global, undefined-field

local LuaRulesMsg = VFS.Include("common/luaUtilities/lua_rules_msg.lua")
local TransferEnums = VFS.Include("common/luaUtilities/team_transfer/transfer_enums.lua")

local function GetAlliedTargetTeamID(myTeamID)
	local teamList = Spring.GetTeamList()
	for _, teamID in ipairs(teamList) do
		if teamID ~= myTeamID and Spring.AreTeamsAllied(myTeamID, teamID) then
			return teamID
		end
	end
	return nil
end

function skip()
	return Spring.GetGameFrame() <= 0
end

function setup()
	Test.clearMap()

	assert(Game.gameEconomy == true,
		"this test requires the ProcessEconomy engine path (Game.gameEconomy must be true)")

	local team0 = Spring.GetMyTeamID()
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

	-- ProcessEconomy fires each frame; policy cache refreshes every POLICY_UPDATE_RATE (30) frames.
	-- Wait two full cycles so the controller sees our resource state and recalculates canShare.
	Test.waitFrames(65)
end

function cleanup()
	Test.clearMap()
end

function test()
	local team0 = Spring.GetMyTeamID()
	local team1 = GetAlliedTargetTeamID(team0)
	assert(team1 ~= nil, "expected at least one allied target team for transfer test")

	local modOptions = Spring.GetModOptions()
	local rse = modOptions.resource_sharing_enabled
	assert(rse == "1" or rse == 1 or rse == true,
		"startscript should set resource_sharing_enabled=1, got: " .. tostring(rse))

	local metalBefore = Spring.GetTeamResources(team0, "metal")
	assert(metalBefore and metalBefore > 0, "team0 should have metal to share")

	local metalSentBefore = tonumber(Spring.GetTeamRulesParam(team0, "metal_share_cumulative_sent")) or 0

	Spring.SendLuaRulesMsg(LuaRulesMsg.SerializeResourceShare(team0, team1, "metal", 100))
	Test.waitFrames(2)

	local metalSentAfter = tonumber(Spring.GetTeamRulesParam(team0, "metal_share_cumulative_sent")) or 0
	assert(metalSentAfter > metalSentBefore,
		"metal cumulative sent should increase after share, before=" .. tostring(metalSentBefore) .. " after=" .. tostring(metalSentAfter))

	local energySentBefore = tonumber(Spring.GetTeamRulesParam(team0, "energy_share_cumulative_sent")) or 0

	Spring.SendLuaRulesMsg(LuaRulesMsg.SerializeResourceShare(team0, team1, "energy", 100))
	Test.waitFrames(2)

	local energySentAfter = tonumber(Spring.GetTeamRulesParam(team0, "energy_share_cumulative_sent")) or 0
	assert(energySentAfter > energySentBefore,
		"energy cumulative sent should increase after share, before=" .. tostring(energySentBefore) .. " after=" .. tostring(energySentAfter))
end
