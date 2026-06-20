---@diagnostic disable: lowercase-global, undefined-field

local UnitTransferUnsynced = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_unsynced.lua")

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
end

function cleanup()
	Test.clearMap()
end

function test()
	local team0 = Spring.GetMyTeamID()
	local team1 = GetAlliedTargetTeamID(team0)
	assert(team1 ~= nil, "expected at least one allied target team for transfer test")

	local modOptions = Spring.GetModOptions()
	assert(modOptions.unit_sharing_mode == "all",
		"startscript should set unit_sharing_mode=all, got: " .. tostring(modOptions.unit_sharing_mode))
	assert(modOptions.take_mode == "enabled",
		"startscript should set take_mode=enabled, got: " .. tostring(modOptions.take_mode))

	local unitID = SyncedRun(function(locals)
		local x, z = Game.mapSizeX / 2, Game.mapSizeZ / 2
		local y = Spring.GetGroundHeight(x, z)
		return Spring.CreateUnit("armpw", x, y, z, "south", locals.team0)
	end, 60)

	assert(unitID, "unit should have been created")
	assert(Spring.GetUnitTeam(unitID) == team0, "unit should start on team0")

	Spring.SelectUnitArray({unitID})
	UnitTransferUnsynced.ShareUnits(team1)

	Test.waitFrames(10)

	assert(Spring.GetUnitTeam(unitID) == team1,
		"unit should belong to team1 after sharing, got team: " .. tostring(Spring.GetUnitTeam(unitID)))
end
