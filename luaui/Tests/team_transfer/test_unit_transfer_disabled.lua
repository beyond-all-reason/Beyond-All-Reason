---@diagnostic disable: lowercase-global, undefined-field, duplicate-set-field

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

	SyncedRun(function()
		_G._origGetModOptions = _G._origGetModOptions or Spring.GetModOptions
		Spring.GetModOptions = function()
			local opts = _G._origGetModOptions()
			opts.unit_sharing_mode = "none"
			return opts
		end
	end, 60)

	-- Wait for the unit transfer controller's policy cache to refresh (every 150 frames)
	Test.waitFrames(160)
end

function cleanup()
	SyncedRun(function()
		if _G._origGetModOptions then
			Spring.GetModOptions = _G._origGetModOptions
			_G._origGetModOptions = nil
		end
	end, 60)

	-- Let the cache refresh back to the real mod options
	Test.waitFrames(160)

	Test.clearMap()
end

function test()
	local team0 = Spring.GetMyTeamID()
	local team1 = GetAlliedTargetTeamID(team0)
	assert(team1 ~= nil, "expected at least one allied target team for transfer test")

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

	assert(Spring.GetUnitTeam(unitID) == team0,
		"unit should still belong to team0 when sharing is disabled, got team: " .. tostring(Spring.GetUnitTeam(unitID)))
end
