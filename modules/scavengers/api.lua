local DefsBuild = VFS.Include("modules/scavengers/lib/defs_build.lua")
local Hooks = VFS.Include("modules/scavengers/lib/hooks.lua")
local Packs = VFS.Include("modules/scavengers/lib/packs.lua")
local SpecBuild = VFS.Include("modules/scavengers/lib/spec_build.lua")

local LOG_TAG = "scavengers"

-- How much of the map a mission's origin claims, as a fraction per side. A
-- quarter of the map is big enough for the placement cascade to find ground
-- and small enough that "from the northeast" still means the northeast.
local ORIGIN_REACH = 0.125

-- The canary for "were the scavenger unit defs derived in this game".
local BEACON_DEF = "scavbeacon_t1_scav"

---Falls back to Gaia — always present and nobody's ally — so a mission with no second team
---still gets its pressure.
---@param againstAllyTeam integer
---@return integer teamID
---@return integer allyTeamID
local function directorTeam(againstAllyTeam)
	local gaiaTeamID = Spring.GetGaiaTeamID()
	for _, teamID in ipairs(Spring.GetTeamList()) do
		if teamID ~= gaiaTeamID then
			local _, _, _, _, _, allyTeamID = Spring.GetTeamInfo(teamID, false)
			if allyTeamID ~= againstAllyTeam then
				return teamID, allyTeamID
			end
		end
	end
	return gaiaTeamID, select(6, Spring.GetTeamInfo(gaiaTeamID, false))
end

---@param againstAllyTeam integer
---@return integer
local function targetTeamCount(againstAllyTeam)
	local count = 0
	for _, teamID in ipairs(Spring.GetTeamList()) do
		local _, _, _, _, _, allyTeamID = Spring.GetTeamInfo(teamID, false)
		if allyTeamID == againstAllyTeam and teamID ~= Spring.GetGaiaTeamID() then
			count = count + 1
		end
	end
	return math.max(1, count)
end

---@param origin { fx: number, fz: number }|nil
---@return table|nil box
local function originBox(origin)
	if origin == nil then
		return nil
	end
	local x = origin.fx * Game.mapSizeX
	local z = origin.fz * Game.mapSizeZ
	local reachX = Game.mapSizeX * ORIGIN_REACH
	local reachZ = Game.mapSizeZ * ORIGIN_REACH
	return {
		x1 = math.max(0, x - reachX),
		z1 = math.max(0, z - reachZ),
		x2 = math.min(Game.mapSizeX, x + reachX),
		z2 = math.min(Game.mapSizeZ, z + reachZ),
	}
end

local api = {}

---@return table<string, MissionWavePack>
api.Packs = function()
	return Packs.Nouns
end

---@class ScavengersStartRequest
---@field pack string the director name, "scavengers.<builder>"
---@field builder string which pack preset
---@field against integer the team the pressure is aimed at
---@field againstAllyTeam integer its ally team
---@field origin { fx: number, fz: number }|nil where it comes from, as map fractions
---@field intensity number|nil

---@param request ScavengersStartRequest
---@return WaveSpec|nil
api.BuildSpec = function(request)
	if Packs.Presets[request.builder] == nil then
		Spring.Log(LOG_TAG, LOG.ERROR, "no such scavengers pack: " .. tostring(request.builder))
		return nil
	end
	-- The purple defs are derived at load time and only when the game asks
	-- for them (a scavengers AI on the field, or ruins/forceallunits/zombies).
	-- A mission is none of those, so it has to say so in its game setup —
	-- and finding out here beats finding out as a CreateUnit failure per
	-- cadence for the rest of the match.
	if UnitDefNames[BEACON_DEF] == nil then
		Spring.Echo(
			"[scavengers] NO SCAVENGERS: this game has no scavenger unit defs."
				.. " Launch with the Mission game mode selected — it loads every unit def —"
				.. " and restart. Nothing below is wrong; there is simply nothing to spawn."
		)
		Spring.Log(
			LOG_TAG,
			LOG.ERROR,
			"the scavenger unit defs are not in this game, so no scavengers can spawn."
				.. " The Mission mode pins forceallunits, which derives them; a raw game"
				.. " setup without the mode needs forceallunits=1 itself. NOT ruins=enabled"
				.. " — that derives the defs too, but it also scatters neutral derelict"
				.. " bases across the map, which a mission did not ask for and cannot"
				.. " easily tell apart from its own scenery."
		)
		return nil
	end

	local teamID, allyTeamID = directorTeam(request.againstAllyTeam)
	-- The pack pins its dials by rewriting the snapshot the roster reads, so
	-- a mission's "easy" is exactly the easy rung a lobby would get.
	local modOptions = Packs.ModOptions(request.builder, Spring.GetModOptions())
	local config = DefsBuild.Build({
		modOptions = modOptions,
		teamList = Spring.GetTeamList(),
		getTeamLuaAI = Spring.GetTeamLuaAI,
		unitDefNames = UnitDefNames,
		log = function(level, message)
			Spring.Log(LOG_TAG, level == "error" and LOG.ERROR or LOG.WARNING, message)
		end,
	})

	local spec = SpecBuild.Build({
		name = request.pack,
		config = config,
		modOptions = modOptions,
		teamID = teamID,
		allyTeamID = allyTeamID,
		teamCount = targetTeamCount(request.againstAllyTeam),
		unitCap = math.floor(Game.maxUnits * 0.80),
		hooks = Hooks.New(config, SpecBuild.Behaviours(config.scavBehaviours), { commanders = 0, decoys = 0 }),
	})
	spec.burrows.box = originBox(request.origin)
	spec.specRef = { module = "scavengers", builder = request.builder, overrides = {} }
	return spec
end

---@param request ScavengersStartRequest
---@return boolean started
api.Start = function(request)
	if GG.Waves == nil then
		Spring.Log(LOG_TAG, LOG.ERROR, "GG.Waves missing; the wave director gadget is not running")
		return false
	end
	if GG.Waves.IsActive(request.pack) then
		-- Already running: a second Begin is a no-op, not a second director
		-- on the same name.
		return true
	end
	local spec = api.BuildSpec(request)
	if spec == nil or not GG.Waves.Start(spec) then
		return false
	end
	if request.intensity ~= nil then
		GG.Waves.SetIntensity(request.pack, request.intensity)
	end
	return true
end

return api
