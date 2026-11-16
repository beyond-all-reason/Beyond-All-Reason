---
--- Mission variables, and the parameters that read them.
---
--- Parameters and fields in mission scripts can receive values like { variable = <key> }.
--- References resolve in-place after difficulties do and before any other parameter changes.
--- Action and trigger paramters then re-resolve whenever their variables are written into,
--- so trigger and action code receive plain values. Objective fields populate only at init.
---

local referencingParameters = {} ---@type table<string, { parameters:table, name:string, type:string, raw:any }?>
local processParameterValue ---@type (fun(parameterType:string, value:any):any)?

local function isVariableReference(value)
	return type(value) == "table" and value.variable ~= nil
end

local function hasVariableReference(value)
	if type(value) ~= "table" then
		return false
	elseif isVariableReference(value) then
		return true
	end
	for _, nested in pairs(value) do
		if hasVariableReference(nested) then
			return true
		end
	end
	return false
end

local function callOnVariableKeys(value, func)
	if isVariableReference(value) then
		func(value.variable)
	elseif type(value) == "table" then
		for _, nested in pairs(value) do
			callOnVariableKeys(nested, func)
		end
	end
end

local function resolveValue(value)
	if isVariableReference(value) then
		local variableValue = GG["MissionAPI"].Variables[value.variable]
		return type(variableValue) == "table" and table.copy(variableValue) or variableValue
	elseif type(value) ~= "table" then
		return value
	end
	local resolved = {}
	for key, nested in pairs(value) do
		resolved[key] = resolveValue(nested)
	end
	return resolved
end

local function hasUnsetVariable(value)
	if isVariableReference(value) then
		return GG["MissionAPI"].Variables[value.variable] == nil
	elseif type(value) ~= "table" then
		return false
	end
	for _, nested in pairs(value) do
		if hasUnsetVariable(nested) then
			return true
		end
	end
	return false
end

local function registerParameters(parameters, schema, registered)
	if parameters == nil or registered[parameters] then
		return
	end
	registered[parameters] = true

	for _, parameter in ipairs(schema or {}) do
		local value = parameters[parameter.name]
		if hasVariableReference(value) then
			local reference = {
				parameters = parameters,
				name = parameter.name,
				type = parameter.type,
				raw = value,
			}
			callOnVariableKeys(value, function(key)
				local references = table.ensureTable(referencingParameters, key)
				if references[#references] ~= reference then
					references[#references + 1] = reference
				end
			end)
			parameters[parameter.name] = resolveValue(value)
		end
	end
end

--- Objective fields resolve once. objectives_loader ran before validation, when amount was not
--- resolvable yet, so the maxRepeats it derives from amount is filled in here for synthesized triggers.
local function resolveObjectiveFields(objectives, triggers)
	for objectiveID, objective in pairs(objectives) do
		local amountIsReference = hasVariableReference(objective.amount)
		for fieldName, value in pairs(objective) do
			if fieldName ~= "trigger" and hasVariableReference(value) then
				objective[fieldName] = resolveValue(value)
			end
		end

		if amountIsReference and type(objective.amount) == "number" then
			local triggerID = GG["MissionAPI"].ObjectiveTriggers[objectiveID]
			local trigger = triggerID and triggers[triggerID]
			if trigger then
				trigger.settings.maxRepeats = objective.amount > 1 and (objective.amount - 1) or nil
			end
		end
	end

	for _, managedObjectives in pairs(GG["MissionAPI"].ManagedObjectives) do
		for _, metadata in ipairs(managedObjectives) do
			if hasVariableReference(metadata.amount) then
				metadata.amount = resolveValue(metadata.amount)
			end
			if hasVariableReference(metadata.nextStage) then
				metadata.nextStage = resolveValue(metadata.nextStage)
			end
		end
	end
end

--- Resolves every reference in validated triggers, actions, and objectives, after difficulties.
--- processValue(parameterType, value) is rerun on each write within parameter_processing.
local function resolveReferences(triggers, actions, objectives, processValue)
	processParameterValue = processValue

	local registered = {}
	local triggerSchema = GG["MissionAPI"].TriggerDefinitions.Parameters
	for _, trigger in pairs(triggers) do
		registerParameters(trigger.parameters, triggerSchema[trigger.type], registered)
	end
	local actionSchema = GG["MissionAPI"].ActionDefinitions.Parameters
	for _, action in pairs(actions) do
		registerParameters(action.parameters, actionSchema[action.type], registered)
	end
	for _, objective in pairs(objectives) do
		local trigger = objective.trigger
		if type(trigger) == "table" then
			registerParameters(trigger.parameters, triggerSchema[trigger.type], registered)
		end
	end

	resolveObjectiveFields(objectives, triggers)
end

local function getVariable(key)
	return GG["MissionAPI"].Variables[key]
end

--- Write to the variable and rebuild action and trigger parameters that reference it.
---
--- A nil write works as though the mission omitted it. Optional parameters stop applying.
--- Required ones are passed as nil, which validation already warned about at load-time.
local function setVariable(key, value)
	GG["MissionAPI"].Variables[key] = value

	for _, reference in ipairs(referencingParameters[key] or {}) do
		local resolved = resolveValue(reference.raw)
		if resolved ~= nil and processParameterValue then
			resolved = processParameterValue(reference.type, resolved)
		end
		reference.parameters[reference.name] = resolved
	end
end

return {
	IsVariableReference = isVariableReference,
	HasVariableReference = hasVariableReference,
	CallOnVariableKeys = callOnVariableKeys,
	HasUnsetVariable = hasUnsetVariable,
	ResolveValue = resolveValue,
	ResolveReferences = resolveReferences,
	Get = getVariable,
	Set = setVariable,
}
