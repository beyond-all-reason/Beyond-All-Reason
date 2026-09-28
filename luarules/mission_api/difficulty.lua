---
--- Difficulty-dependent parameter values for Mission API triggers, actions, and objectives.
---
--- Any parameter may be authored as { difficulties = { <difficultyName> = <value>, ... } }
--- instead of a plain value. Resolution replaces the wrapper with the value for the current
--- difficulty (GG['MissionAPI'].Difficulty, a rank from difficulties.json): an exact rank
--- match, else the highest-ranked entry below the current rank, else the lowest-ranked entry.
---

local difficultyRanks = VFS.Include("luarules/mission_api/parameter_types.lua").Enums.Difficulty

-- Deliberately not a plain type check: many parameter types are tables (Area, Orders, ...).
local function isDifficultiesTable(value)
	return type(value) == "table" and value.difficulties ~= nil
end

--- Resolve a possibly difficulty-wrapped value; non-wrapped values pass through unchanged.
--- Entries with unknown difficulty names are ignored here; validation reports them.
local function resolve(value)
	if not isDifficultiesTable(value) then
		return value
	end
	if type(value.difficulties) ~= "table" then
		return nil -- malformed wrapper; validation reports it
	end

	local currentRank = GG["MissionAPI"].Difficulty or 0
	local best, bestRank, lowest, lowestRank
	for difficultyName, difficultyValue in pairs(value.difficulties) do
		local rank = difficultyRanks[difficultyName]
		if rank then
			if lowestRank == nil or rank < lowestRank then
				lowest, lowestRank = difficultyValue, rank
			end
			if rank <= currentRank and (bestRank == nil or rank > bestRank) then
				best, bestRank = difficultyValue, rank
			end
		end
	end

	if bestRank ~= nil then
		return best
	end
	return lowest
end

local function resolveParameters(parameters)
	if type(parameters) ~= "table" then
		return
	end
	for name, value in pairs(parameters) do
		if isDifficultiesTable(value) then
			parameters[name] = resolve(value)
		end
	end
end

--- Resolve trigger parameters, and rekey the settings.difficulties gate from names to ranks
--- so the runtime check in api_missions_triggers.lua can index it by the current rank.
local function resolveTriggers(triggers)
	for _, trigger in pairs(triggers) do
		resolveParameters(trigger.parameters)

		local difficulties = trigger.settings and trigger.settings.difficulties
		if type(difficulties) == "table" then
			local byRank = {}
			for difficultyName, enabled in pairs(difficulties) do
				local rank = difficultyRanks[difficultyName]
				if rank then
					byRank[rank] = enabled
				end
			end
			trigger.settings.difficulties = byRank
		end
	end
end

local function resolveActions(actions)
	for _, action in pairs(actions) do
		resolveParameters(action.parameters)
	end
end

--- Resolve objective fields and inline trigger parameters in place. The inline parameters
--- table is shared with ManagedObjectives metadata, which is thereby resolved too. The
--- 'trigger' field itself does not support difficulties (validation rejects a wrapper there).
local function resolveObjectives(objectives)
	for _, objective in pairs(objectives) do
		if type(objective) == "table" then
			for fieldName, value in pairs(objective) do
				if fieldName ~= "trigger" and isDifficultiesTable(value) then
					objective[fieldName] = resolve(value)
				end
			end
			if type(objective.trigger) == "table" then
				resolveParameters(objective.trigger.parameters)
			end
		end
	end
end

return {
	IsDifficultiesTable = isDifficultiesTable,
	Resolve = resolve,
	ResolveTriggers = resolveTriggers,
	ResolveActions = resolveActions,
	ResolveObjectives = resolveObjectives,
}
