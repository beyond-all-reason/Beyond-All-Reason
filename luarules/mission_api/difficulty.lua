---
--- Difficulty-dependent parameter values for Mission API triggers, actions, and objectives.
---
--- Any parameter may be authored as { difficulties = { <difficultyName> = <value>, ... } }
--- instead of a plain value. Resolution replaces with the value for the current difficulty,
--- else the highest-ranked entry below the current rank, else the lowest-ranked entry.
---

local difficulties = GG["MissionAPI"].Modules.ParameterTypes.Enums.Difficulty
local objectivesLoader = VFS.Include("luarules/mission_api/objectives_loader.lua")

local function isDifficultiesTable(value)
	return type(value) == "table" and value.difficulties ~= nil
end

--- Every value a parameter can take, across all difficulties. Validation checks them all,
--- since the difficulty is only known once the mission runs.
local function possibleValues(value)
	if not isDifficultiesTable(value) then
		return { value }
	end

	local values = {}
	if type(value.difficulties) == "table" then
		for _, difficultyValue in pairs(value.difficulties) do
			values[#values + 1] = difficultyValue
		end
	end
	return values
end

--- Only called on validated missions, so every name in value.difficulties is a difficulty.
local function resolve(value)
	local currentDifficulty = GG["MissionAPI"].Difficulty

	local chosenDifficulty, chosenValue, lowestDifficulty, lowestValue
	for difficultyName, difficultyValue in pairs(value.difficulties) do
		local difficulty = difficulties[difficultyName]
		if difficulty == currentDifficulty then
			return difficultyValue
		end

		if lowestDifficulty == nil or difficulty < lowestDifficulty then
			lowestDifficulty, lowestValue = difficulty, difficultyValue
		end
		if difficulty < currentDifficulty and (chosenDifficulty == nil or difficulty > chosenDifficulty) then
			chosenDifficulty, chosenValue = difficulty, difficultyValue
		end
	end

	if chosenDifficulty ~= nil then
		return chosenValue
	end
	return lowestValue
end

local function resolveParameters(parameters)
	if parameters == nil then -- e.g. Event triggers declare no parameters
		return
	end
	for name, value in pairs(parameters) do
		if isDifficultiesTable(value) then
			parameters[name] = resolve(value)
		end
	end
end

local thresholdFields = { "count", "atLeast", "atMost" }

local function resolveThresholds(condition)
	for _, fieldName in ipairs(thresholdFields) do
		if isDifficultiesTable(condition[fieldName]) then
			condition[fieldName] = resolve(condition[fieldName])
		end
	end
end

--- Resolve trigger parameters, and convert the settings.difficulties names into difficulty
--- values for the runtime check in api_missions_triggers.lua.
local function resolveTriggers(triggers)
	for _, trigger in pairs(triggers) do
		resolveParameters(trigger.parameters)
		resolveThresholds(trigger)

		local triggerDifficulties = trigger.settings.difficulties
		if triggerDifficulties ~= nil then
			for i, difficultyName in ipairs(triggerDifficulties) do
				triggerDifficulties[i] = difficulties[difficultyName]
			end
		end
	end
end

local function resolveActions(actions)
	for _, action in pairs(actions) do
		resolveParameters(action.parameters)
	end
end

local function resolveCutscenes(cutscenes)
	for _, cutscene in pairs(cutscenes) do
		resolveParameters(cutscene)
	end
end

--- Resolve objective fields and the parameters of their trigger in place.
--- objectives_loader built each condition record before the difficulty was known, so
--- the resolved amount is copied onto it here as its threshold.
local function resolveObjectives(objectives)
	for objectiveID, objective in pairs(objectives) do
		for fieldName, value in pairs(objective) do
			if fieldName ~= "trigger" and isDifficultiesTable(value) then
				objective[fieldName] = resolve(value)
			end
		end
		resolveParameters(objective.trigger and objective.trigger.parameters)
		objectivesLoader.ApplyThresholds(objectiveID, objective, GG["MissionAPI"].Triggers)
	end
end

---@param name string?
---@return integer
local function fromName(name)
	if name ~= nil and difficulties[name] ~= nil then
		return difficulties[name]
	end
	if name ~= nil then
		Spring.Log("difficulty.lua", LOG.ERROR, "[Mission API] Unknown difficulty: " .. tostring(name))
	end

	return table.reduce(difficulties, function(lowest, difficulty)
		return math.min(lowest, difficulty)
	end, math.huge)
end

return {
	FromName = fromName,
	IsDifficultiesTable = isDifficultiesTable,
	PossibleValues = possibleValues,
	ResolveTriggers = resolveTriggers,
	ResolveActions = resolveActions,
	ResolveObjectives = resolveObjectives,
	ResolveCutscenes = resolveCutscenes,
}
