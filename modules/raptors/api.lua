local DefsBuild = VFS.Include("modules/raptors/lib/defs_build.lua")
local Hooks = VFS.Include("modules/raptors/lib/hooks.lua")
local Packs = VFS.Include("modules/raptors/lib/packs.lua")
local SpecBuild = VFS.Include("modules/raptors/lib/spec_build.lua")

local LOG_TAG = "raptors"

-- How much of the map a mission's origin claims, as a fraction per side.
local ORIGIN_REACH = 0.125

-- The canary for "were the raptor unit defs loaded in this game".
local HIVE_DEF = "raptor_hive"

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

---@class RaptorsStartRequest
---@field pack string the director name, "raptors.<builder>"
---@field builder string which pack preset
---@field against integer the team the pressure is aimed at
---@field againstAllyTeam integer its ally team
---@field origin { fx: number, fz: number }|nil where it comes from, as map fractions
---@field intensity number|nil

---@param request RaptorsStartRequest
---@return WaveSpec|nil
api.BuildSpec = function(request)
	if Packs.Presets[request.builder] == nil then
		Spring.Log(LOG_TAG, LOG.ERROR, "no such raptors pack: " .. tostring(request.builder))
		return nil
	end
	-- The raptor defs load only when a raptors AI is on the field or every
	-- unit is forced in; a mission has to say so in its game setup.
	if UnitDefNames[HIVE_DEF] == nil then
		Spring.Log(
			LOG_TAG,
			LOG.ERROR,
			"the raptor unit defs are not in this game, so no raptors can spawn."
				.. " The Mission mode pins forceallunits, which loads them; a raw game"
				.. " setup without the mode needs forceallunits=1 itself."
		)
		return nil
	end

	local teamID, allyTeamID = directorTeam(request.againstAllyTeam)
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
		hooks = Hooks.New(config, SpecBuild.Behaviours(config.raptorBehaviours)),
	})
	spec.burrows.box = originBox(request.origin)
	spec.specRef = { module = "raptors", builder = request.builder, overrides = {} }
	return spec
end

---@param request RaptorsStartRequest
---@return boolean started
api.Start = function(request)
	if GG.Waves == nil then
		Spring.Log(LOG_TAG, LOG.ERROR, "GG.Waves missing; the wave director gadget is not running")
		return false
	end
	if GG.Waves.IsActive(request.pack) then
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
