---
--- Mission data from the game setup: the `missionoptions` modoption and the
--- `name` and `dummy` custom keys the client writes on teams and allyteams.
---

local ModoptionPayload = VFS.Include("common/luaUtilities/modoption_payload.lua")

----------------------------------------------------------------
--- Module internals -------------------------------------------

local function isDummyTeam(customKeys)
	-- NB: The engine lowercases keys from start scripts.
	return customKeys.dummy == "1" or customKeys.dummy == "true"
end

local function readMissionOptions()
	local raw = Spring.GetModOptions().missionoptions
	if raw == nil then
		return nil
	end

	local missionOptions = ModoptionPayload.Decode(raw)
	if missionOptions == nil then
		Spring.Log("game_setup.lua", LOG.ERROR, "[Mission API] Could not decode missionoptions")
	end
	return missionOptions
end

-- Gaia's team ID is the team count, which changes when the client adds a team, so missions use this name,
-- for Gaia's team and for its allyteam.
local GAIA_TEAM_NAME = "gaia"

local function readTeams()
	local teamNames, dummyTeams, errors = {}, {}, {}
	for _, teamID in ipairs(Spring.GetTeamList()) do
		local _, _, _, _, _, allyTeamID, _, customKeys = Spring.GetTeamInfo(teamID, true)
		if customKeys ~= nil then
			if isDummyTeam(customKeys) then
				dummyTeams[allyTeamID] = teamID
			elseif customKeys.name == GAIA_TEAM_NAME then
				errors[#errors + 1] = "Team "
					.. teamID
					.. " is named '"
					.. GAIA_TEAM_NAME
					.. "', the name reserved for Gaia"
			elseif customKeys.name ~= nil then
				teamNames[teamID] = customKeys.name
			end
		end
	end

	local gaiaTeamID = Spring.GetGaiaTeamID()
	if gaiaTeamID == nil then
		errors[#errors + 1] = "Missions need Gaia's team, but the start script sets luagaia=0"
	else
		teamNames[gaiaTeamID] = GAIA_TEAM_NAME
	end

	return teamNames, dummyTeams, errors
end

local function readAllyTeamNames(errors)
	local allyTeamNames = {}
	for _, allyTeamID in ipairs(Spring.GetAllyTeamList()) do
		local customKeys = Spring.GetAllyTeamInfo(allyTeamID)
		if customKeys ~= nil and customKeys.name == GAIA_TEAM_NAME then
			errors[#errors + 1] = "Allyteam "
				.. allyTeamID
				.. " is named '"
				.. GAIA_TEAM_NAME
				.. "', the name reserved for Gaia"
		elseif customKeys ~= nil and customKeys.name ~= nil then
			allyTeamNames[allyTeamID] = customKeys.name
		end
	end

	local gaiaTeamID = Spring.GetGaiaTeamID()
	if gaiaTeamID ~= nil then
		local _, _, _, _, _, gaiaAllyTeamID = Spring.GetTeamInfo(gaiaTeamID)
		allyTeamNames[gaiaAllyTeamID] = GAIA_TEAM_NAME
	end

	return allyTeamNames
end

local function toReversibleMap(namesByID)
	return table.merge(namesByID, table.invert(namesByID))
end

local function toKeySet(tbl)
	return table.map(tbl, function()
		return true
	end)
end

----------------------------------------------------------------
--- Module exports ---------------------------------------------

---@class MissionGameSetup
---@field entryPoint string
---@field difficulty string?
---@field options table
---@field variables table
---@field persistentVariables table<string, true> the keys of the variables that came from the save
---@field teams table<integer|string, string|integer> team ID to name, and name to team ID, Gaia's team as "gaia"
---@field alliances table<integer|string, string|integer> allyteam ID to name, and name to allyteam ID, Gaia's allyteam as "gaia"
---@field dummyTeams table<integer, integer> allyteam ID to its dummy team ID
---@field errors string[] what the start script gets wrong for a mission, reported by validation

local missionOptions = readMissionOptions()
if missionOptions == nil or missionOptions.entryPoint == nil then
	return
end

local teamNames, dummyTeams, errors = readTeams()
local allyTeamNames = readAllyTeamNames(errors)
local variables = missionOptions.variables or {}

return {
	entryPoint = missionOptions.entryPoint,
	difficulty = missionOptions.difficulty,
	options = missionOptions.options or {},
	variables = variables,
	persistentVariables = toKeySet(variables),
	teams = toReversibleMap(teamNames),
	alliances = toReversibleMap(allyTeamNames),
	dummyTeams = dummyTeams,
	errors = errors,
}
