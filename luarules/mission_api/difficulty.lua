---
--- Difficulty-dependent parameter values for Mission API triggers, actions, and objectives.
---
--- Any parameter may be authored as { difficulties = { <difficultyName> = <value>, ... } }
--- instead of a plain value. Resolution replaces with the value for the current difficulty,
--- else the highest-ranked entry below the current rank, else the lowest-ranked entry.
---

local difficulties = GG["MissionAPI"].Modules.ParameterTypes.Enums.Difficulty

local function isDifficultiesTable(value)
	return type(value) == "table" and value.difficulties ~= nil
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

--- Resolve trigger parameters, and convert the settings.difficulties names into difficulty
--- values for the runtime check in api_missions_triggers.lua.
local function resolveTriggers(triggers)
	for _, trigger in pairs(triggers) do
		resolveParameters(trigger.parameters)

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

--- Resolve objective fields, inline trigger parameters, and managed objective metadata in
--- place. objectives_loader ran before validation, when amount was not resolvable yet, so
--- the maxRepeats it derives from amount is filled in here for synthesized triggers.
local function resolveObjectives(objectives)
	for objectiveID, objective in pairs(objectives) do
		if isDifficultiesTable(objective.amount) then
			objective.amount = resolve(objective.amount)

			local triggerID = GG["MissionAPI"].ObjectiveTriggers[objectiveID]
			local trigger = triggerID and GG["MissionAPI"].Triggers[triggerID]
			if trigger then
				trigger.settings.maxRepeats = objective.amount > 1 and (objective.amount - 1) or nil
			end
		end

		for fieldName, value in pairs(objective) do
			if fieldName ~= "trigger" and isDifficultiesTable(value) then
				objective[fieldName] = resolve(value)
			end
		end
		resolveParameters(objective.trigger and objective.trigger.parameters)
	end

	for _, managedObjectives in pairs(GG["MissionAPI"].ManagedObjectives) do
		for _, metadata in ipairs(managedObjectives) do
			if isDifficultiesTable(metadata.amount) then
				metadata.amount = resolve(metadata.amount)
			end
			if isDifficultiesTable(metadata.nextStage) then
				metadata.nextStage = resolve(metadata.nextStage)
			end
		end
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
	ResolveTriggers = resolveTriggers,
	ResolveActions = resolveActions,
	ResolveObjectives = resolveObjectives,
}
