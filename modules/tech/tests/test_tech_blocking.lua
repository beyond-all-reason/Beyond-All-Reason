---@diagnostic disable: lowercase-global, undefined-field

local function skip()
	if Spring.GetGameFrame() <= 0 then
		return true
	end
	-- tech is live under the Tech Core preset alone; elsewhere its gadget and policies are not loaded
	local live = VFS.Include("modules/module_handler.lua").LiveModulesFor(Spring.GetModOptions())
	return not live.tech
end

local function setup()
	Test.clearMap()
	Test.waitFrames(5)
end

local function cleanup()
	Test.clearMap()
end

local function test()
	local teamID = Spring.GetLocalTeamID()
	local modOptions = Spring.GetModOptions()

	local t2PerPlayer = tonumber(modOptions.t2_tech_threshold)
	assert(t2PerPlayer, "t2_tech_threshold mod option must be set")

	local teamT2 = tonumber(Spring.GetTeamRulesParam(teamID, "tech_t2_threshold"))
	assert(
		teamT2 and teamT2 >= t2PerPlayer,
		"team rules threshold should be mod option * team count, perPlayer="
			.. tostring(t2PerPlayer)
			.. " team="
			.. tostring(teamT2)
	)

	assert(tonumber(Spring.GetTeamRulesParam(teamID, "tech_level")) == 1, "tech_level should start at 1")
	assert(tonumber(Spring.GetTeamRulesParam(teamID, "tech_points")) == 0, "tech_points should start at 0")

	local armalabDefID = UnitDefNames.armalab.id
	local blockedBefore = Spring.GetTeamRulesParam(teamID, "unitdef_blocked_" .. armalabDefID)
	assert(blockedBefore, "T2 lab (armalab) should be build-blocked at tech level 1")

	-- the defs step: a general T1 constructor builds the Keystone, and the T2 lab came cheaper
	local keystoneDefID = UnitDefNames.armkeystone.id
	local conBuildsKeystone = false
	for _, buildDefID in ipairs(UnitDefNames.armck.buildOptions) do
		if buildDefID == keystoneDefID then
			conBuildsKeystone = true
		end
	end
	assert(conBuildsKeystone, "armck should build armkeystone under tech_blocking")
	assert(UnitDefNames.armalab.metalCost == 1700, "armalab should cost 1700 metal under tech_blocking")

	local needed = math.ceil(teamT2 / 1)
	local keystoneHasLuaScript = SyncedRun(function(locals)
		local x, z = Game.mapSizeX / 2, Game.mapSizeZ / 2
		local y = Spring.GetGroundHeight(x, z)
		local first
		for i = 1, locals.needed do
			local unitID = Spring.CreateUnit("armkeystone", x + (i * 64), y, z, "south", locals.teamID)
			first = first or unitID
		end
		-- the module ships the Keystone's script (modules/tech/scripts/): the unit script framework found it
		return first ~= nil and Spring.UnitScript.GetScriptEnv(first) ~= nil
	end, 60)
	assert(keystoneHasLuaScript, "the Keystone should run its module's Lua unit script")

	Test.waitFrames(60)

	assert(
		tonumber(Spring.GetTeamRulesParam(teamID, "tech_level")) >= 2,
		"tech_level should advance to at least 2 after keystone"
	)

	local blockedAfter = Spring.GetTeamRulesParam(teamID, "unitdef_blocked_" .. armalabDefID)
	assert(not blockedAfter or blockedAfter == "", "T2 lab (armalab) should be unblocked after tech advancement")
end

return {
	skip = skip,
	setup = setup,
	cleanup = cleanup,
	test = test,
}
