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

--- Only called on validated missions, so `value` is a wrapper and every name is a difficulty.
local function resolve(value)
	local currentDifficulty = GG["MissionAPI"].Difficulty or 0
	local entries = value.difficulties

	local chosenName
	for difficultyName in pairs(entries) do
		if difficulties[difficultyName] == currentDifficulty then
			return entries[difficultyName]
		end
		if chosenName == nil or difficulties[difficultyName] < difficulties[chosenName] then
			chosenName = difficultyName
		end
	end

	-- No exact match: take the highest entry below the current difficulty, if any is below.
	for difficultyName in pairs(entries) do
		local difficulty = difficulties[difficultyName]
		if difficulty <= currentDifficulty and difficulty > difficulties[chosenName] then
			chosenName = difficultyName
		end
	end

	return entries[chosenName]
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

--- Resolve trigger parameters, and convert the settings.difficulties array of names into a
--- set keyed by difficulty for the runtime check in api_missions_triggers.lua. An empty
--- array enables the trigger on every difficulty, like omitting the setting.
local function resolveTriggers(triggers)
	for _, trigger in pairs(triggers) do
		resolveParameters(trigger.parameters)

		local names = trigger.settings.difficulties
		if names ~= nil then
			local enabled = nil
			for _, difficultyName in ipairs(names) do
				enabled = enabled or {}
				enabled[difficulties[difficultyName]] = true
			end
			trigger.settings.difficulties = enabled
		end
	end
end

local function resolveActions(actions)
	for _, action in pairs(actions) do
		resolveParameters(action.parameters)
	end
end

--- Resolve objective fields, inline trigger parameters, and managed objective metadata in
--- place. objectives_loader ran before validation, so it could not consume a wrapped amount;
--- the maxRepeats it derives from amount is filled in here for synthesized triggers. The
--- 'trigger' field itself does not support difficulties (validation rejects a wrapper there).
local function resolveObjectives(objectives)
	for objectiveID, objective in pairs(objectives) do
		if type(objective) == "table" then
			local amountWasWrapped = isDifficultiesTable(objective.amount)
			for fieldName, value in pairs(objective) do
				if fieldName ~= "trigger" and isDifficultiesTable(value) then
					objective[fieldName] = resolve(value)
				end
			end
			if type(objective.trigger) == "table" then
				resolveParameters(objective.trigger.parameters)
			end

			if amountWasWrapped then
				local triggerID = GG["MissionAPI"].ObjectiveTriggers[objectiveID]
				local trigger = triggerID and GG["MissionAPI"].Triggers[triggerID]
				if trigger then
					local amount = objective.amount
					trigger.settings.maxRepeats = type(amount) == "number" and amount > 1 and (amount - 1) or nil
				end
			end
		end
	end

	for _, entries in pairs(GG["MissionAPI"].ManagedObjectives) do
		for _, metadata in ipairs(entries) do
			if isDifficultiesTable(metadata.amount) then
				metadata.amount = resolve(metadata.amount)
			end
			if isDifficultiesTable(metadata.nextStage) then
				metadata.nextStage = resolve(metadata.nextStage)
			end
		end
	end
end

return {
	IsDifficultiesTable = isDifficultiesTable,
	ResolveTriggers = resolveTriggers,
	ResolveActions = resolveActions,
	ResolveObjectives = resolveObjectives,
}
