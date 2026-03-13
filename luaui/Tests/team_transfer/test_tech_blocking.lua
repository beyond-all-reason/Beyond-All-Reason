---@diagnostic disable: lowercase-global, undefined-field

function skip()
	return Spring.GetGameFrame() <= 0
end

function setup()
	Test.clearMap()
	Test.waitFrames(5)
end

function cleanup()
	Test.clearMap()
end

function test()
	local teamID = Spring.GetMyTeamID()
	local modOptions = Spring.GetModOptions()

	local t2PerPlayer = tonumber(modOptions.t2_tech_threshold)
	assert(t2PerPlayer, "t2_tech_threshold mod option must be set")

	-- tech_t2_threshold is per-player value * active allied team count
	local teamT2 = tonumber(Spring.GetTeamRulesParam(teamID, "tech_t2_threshold"))
	assert(teamT2 and teamT2 >= t2PerPlayer,
		"team rules threshold should be mod option * team count, perPlayer=" .. tostring(t2PerPlayer) .. " team=" .. tostring(teamT2))

	assert(tonumber(Spring.GetTeamRulesParam(teamID, "tech_level")) == 1,
		"tech_level should start at 1")
	assert(tonumber(Spring.GetTeamRulesParam(teamID, "tech_points")) == 0,
		"tech_points should start at 0")

	local armfusDefID = UnitDefNames["armfus"].id
	local blockedBefore = Spring.GetTeamRulesParam(teamID, "unitdef_blocked_" .. armfusDefID)
	assert(blockedBefore, "T2 unit (armfus) should be build-blocked at tech level 1")

	-- threshold = t2TechPerPlayer * activePlayerCount, so create enough catalysts
	local needed = math.ceil(teamT2 / 1)
	SyncedRun(function(locals)
		local x, z = Game.mapSizeX / 2, Game.mapSizeZ / 2
		local y = Spring.GetGroundHeight(x, z)
		for i = 1, locals.needed do
			Spring.CreateUnit("armcatalyst", x + (i * 64), y, z, "south", locals.teamID)
		end
	end, 60)

	Test.waitFrames(60)

	assert(tonumber(Spring.GetTeamRulesParam(teamID, "tech_level")) >= 2,
		"tech_level should advance to at least 2 after catalyst")

	local blockedAfter = Spring.GetTeamRulesParam(teamID, "unitdef_blocked_" .. armfusDefID)
	assert(not blockedAfter or blockedAfter == "",
		"T2 unit (armfus) should be unblocked after tech advancement")
end
