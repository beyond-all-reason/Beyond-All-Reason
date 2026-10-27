---
--- Post-validation parameter processing for Mission API actions and triggers.
---

VFS.Include("common/wav.lua")

local ParameterTypes = GG["MissionAPI"].Modules.ParameterTypes.Types
local internalTypes = GG["MissionAPI"].Modules.ParameterTypes.InternalTypes
local internalFields = GG["MissionAPI"].Modules.ParameterTypes.InternalFields
local enumSets = GG["MissionAPI"].Modules.ParameterTypes.EnumSets
local actionDefinitions = GG["MissionAPI"].ActionDefinitions
local actionsSchemaParameters = actionDefinitions.Parameters
local triggersSchemaParameters = GG["MissionAPI"].TriggerDefinitions.Parameters
local unitEntryFields = VFS.Include("luarules/mission_api/loadout_schema.lua").UnitEntryFields
local teams = GG["MissionAPI"].Teams
local alliances = GG["MissionAPI"].Alliances

----------------------------------------------------------------
--- Parameter processors:
----------------------------------------------------------------

local function processPosition(position)
	position.y = position.y or Spring.GetGroundHeight(position.x, position.z)
end

local function processPositions(positions)
	for _, position in ipairs(positions) do
		processPosition(position)
	end
end

local function processDirection(position)
	if position.x and position.z then
		position.y = position.y or Spring.GetGroundHeight(position.x, position.z)
	end
end

local function processOrders(orders)
	for _, order in ipairs(orders) do
		local commandIndex = order[1] == CMD.INSERT and 3 or 1
		local commandID = order[commandIndex]
		if type(commandID) == "string" then
			-- A build order names the unit to build, which the engine takes as a negative ID.
			order[commandIndex] = -UnitDefNames[commandID].id
		end
	end
end

local function processCommand(command)
	if command == CMD.ANY or command == CMD.BUILD then
		return
	end
	if type(command) == "string" then
		local unitDef = UnitDefNames[command]
		if unitDef then
			return -unitDef.id
		end
	end
end

local function processTeamName(teamName)
	return teams[teamName]
end

local function processAllianceName(allianceName)
	return alliances[allianceName]
end

local function processAllianceNames(allianceNames)
	local allyTeamIDs = {}
	for index, allianceName in ipairs(allianceNames) do
		local allyTeamID = processAllianceName(allianceName)
		if allyTeamID == nil then
			return nil
		end
		allyTeamIDs[index] = allyTeamID
	end
	return allyTeamIDs
end

local processParameter ---@type function

local function processUnitLoadout(unitLoadout)
	for _, unit in ipairs(unitLoadout) do
		for _, field in ipairs(unitEntryFields) do
			if internalTypes[field.type] then
				processParameter(unit, field)
			end
		end
	end
end

local function processSoundFile(soundfile)
	GG["MissionAPI"].soundFiles[soundfile] = ReadWAV(soundfile).Length
end

local function processEnumSet(values)
	local valueSet = {}
	for _, value in ipairs(values) do
		valueSet[value] = true
	end
	return valueSet
end

local processors = {
	[ParameterTypes.Position] = processPosition,
	[ParameterTypes.Positions] = processPositions,
	[ParameterTypes.Direction] = processDirection,
	[ParameterTypes.Orders] = processOrders,
	[ParameterTypes.Command] = processCommand,
	[ParameterTypes.SoundFile] = processSoundFile,
	[ParameterTypes.TeamName] = processTeamName,
	[ParameterTypes.AllianceName] = processAllianceName,
	[ParameterTypes.AllianceNames] = processAllianceNames,
	[ParameterTypes.UnitLoadout] = processUnitLoadout,
}
for enumSetType in pairs(enumSets) do
	processors[enumSetType] = processEnumSet
end

----------------------------------------------------------------
--- Public processing functions:
----------------------------------------------------------------

local function processValue(parameterType, value)
	local processor = processors[parameterType]
	if processor == nil then
		return value
	end
	local result = processor(value)
	if internalTypes[parameterType] then
		if result == nil then
			Spring.Log(
				"parameter_processing.lua",
				LOG.ERROR,
				"[Mission API] Unknown " .. parameterType .. " " .. Json.encode(value)
			)
		end
		return result
	end
	if result ~= nil then
		return result
	end
	return value
end

--- A parameter with an internal type is replaced with its internal field.
function processParameter(parameters, parameter)
	local value = parameters[parameter.name]
	if internalTypes[parameter.type] then
		parameters[internalFields[parameter.name]] = value ~= nil and processValue(parameter.type, value) or nil
		parameters[parameter.name] = nil
	elseif value ~= nil then
		parameters[parameter.name] = processValue(parameter.type, value)
	end
end

local function processSchemaParameters(parameters, schema)
	for _, parameter in ipairs(schema or {}) do
		processParameter(parameters, parameter)
	end
end

local function processParameters(actionsOrTriggers, schemaParameters)
	for _, actionOrTrigger in pairs(actionsOrTriggers) do
		processSchemaParameters(actionOrTrigger.parameters or {}, schemaParameters[actionOrTrigger.type])
	end
end

local function processActionParameters(actions)
	processParameters(actions, actionsSchemaParameters)
end

local function processTriggerParameters(triggers)
	processParameters(triggers, triggersSchemaParameters)
end

local function processManagedObjectiveParameters(managedObjectives)
	for triggerType, objectives in pairs(managedObjectives) do
		for _, objective in ipairs(objectives) do
			processSchemaParameters(objective.parameters, triggersSchemaParameters[triggerType])
		end
	end
end

local function renameInternalFields()
	for _, schemaParameters in ipairs({ actionsSchemaParameters, triggersSchemaParameters }) do
		for _, parameters in pairs(schemaParameters) do
			for _, parameter in ipairs(parameters) do
				if internalTypes[parameter.type] then
					parameter.name = internalFields[parameter.name]
				end
			end
		end
	end
end

return {
	ProcessValue = processValue,
	ProcessParameter = processParameter,
	ProcessActionParameters = processActionParameters,
	ProcessTriggerParameters = processTriggerParameters,
	ProcessManagedObjectiveParameters = processManagedObjectiveParameters,
	RenameInternalFields = renameInternalFields,
}
