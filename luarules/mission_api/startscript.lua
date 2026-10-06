---
--- Mission data from the start script. Takes the `missionoptions` modoption
--- and the `name` and `dummy` keys the client writes on team and allyteams.
---
--- requires: common/luaUtilities/modoption_payload.lua
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
		Spring.Log("startscript.lua", LOG.ERROR, "[Mission API] Could not decode missionoptions")
	end
	return missionOptions
end

local function readTeams()
	local teamNames, dummyTeams = {}, {}
	for _, teamID in ipairs(Spring.GetTeamList()) do
		local _, _, _, _, _, allyTeamID, _, customKeys = Spring.GetTeamInfo(teamID, true)
		if customKeys ~= nil then
			if isDummyTeam(customKeys) then
				dummyTeams[allyTeamID] = teamID
			elseif customKeys.name ~= nil then
				teamNames[teamID] = customKeys.name
			end
		end
	end
	return teamNames, dummyTeams
end

local function readAllyTeamNames()
	local allyTeamNames = {}
	for _, allyTeamID in ipairs(Spring.GetAllyTeamList()) do
		local customKeys = Spring.GetAllyTeamInfo(allyTeamID)
		if customKeys ~= nil and customKeys.name ~= nil then
			allyTeamNames[allyTeamID] = customKeys.name
		end
	end
	return allyTeamNames
end

local function toReversibleMap(namesByID)
	return table.merge(namesByID, table.invert(namesByID))
end

----------------------------------------------------------------
--- Module exports ---------------------------------------------

---@class MissionStartScript
---@field entryPoint string
---@field difficulty string?
---@field options table
---@field variables table
---@field persistentVariables string[]
---@field teamNames table<integer, string> team ID to name
---@field allyTeamNames table<integer, string> allyteam ID to name
---@field teams table<integer|string, string|integer> team ID to name, and name to team ID
---@field allyTeams table<integer|string, string|integer> allyteam ID to name, and name to allyteam ID
---@field dummyTeams table<integer, integer> allyteam ID to its dummy team ID

---@return MissionStartScript?
local function read()
	local missionOptions = readMissionOptions()
	if missionOptions == nil or missionOptions.entryPoint == nil then
		return nil
	end

	local teamNames, dummyTeams = readTeams()
	local allyTeamNames = readAllyTeamNames()
	local variables = missionOptions.variables or {}
	local persistentVariables = table.keys(variables)
	table.sort(persistentVariables)

	return {
		entryPoint = missionOptions.entryPoint,
		difficulty = missionOptions.difficulty,
		options = missionOptions.options or {},
		variables = variables,
		persistentVariables = persistentVariables,
		teamNames = teamNames,
		allyTeamNames = allyTeamNames,
		teams = toReversibleMap(teamNames),
		allyTeams = toReversibleMap(allyTeamNames),
		dummyTeams = dummyTeams,
	}
end

return {
	Read = read,
}
