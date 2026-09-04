local parameterTypes = VFS.Include("luarules/mission_api/parameter_types.lua")
local schemaUtils = VFS.Include("luarules/mission_api/schema_utils.lua")

--[[
	objectiveID = {
		textKey = "complete_objective",
		amount = 3,
		trigger = {
			type = triggerTypes.TimeElapsed,
			parameters = {
				seconds = 3,
			},
		},
		nextStage = 'secondStage',
		coop = true,
	},
]]

local function processRawObjectives(rawObjectives, rawTriggers, rawActions, stages)
	local objectives = rawObjectives or {}

	local actionTypes = GG["MissionAPI"].ActionDefinitions.Types
	local triggerTypesWithQuantity = schemaUtils.GetTypesWithParameterType(
		GG["MissionAPI"].TriggerDefinitions.Parameters,
		parameterTypes.Types.Quantity
	)

	-- Build objective-to-stages mapping from stages structure
	local objectiveToStages = GG["MissionAPI"].ObjectiveStages
	for stageID, stageData in pairs(stages or {}) do
		if type(stageData) == "table" and type(stageData.objectives) == "table" then
			for _, objectiveID in ipairs(stageData.objectives) do
				if not objectiveToStages[objectiveID] then
					objectiveToStages[objectiveID] = {}
				end
				table.insert(objectiveToStages[objectiveID], stageID)
			end
		end
	end

	for objectiveID, objective in pairs(objectives) do
		local objectiveStages = objectiveToStages[objectiveID] or {}

		if type(objective) == "table" then
			objective.active = false
		end

		if type(objectiveID) == "string" and type(objective) == "table" and type(objective.trigger) == "table" then
			local amount = objective.amount
			local triggerType = objective.trigger.type
			local triggerParameters = type(objective.trigger.parameters) == "table" and objective.trigger.parameters
				or {}

			if triggerTypesWithQuantity[triggerType] then
				-- Managed objective: register metadata for lookaside lookup; no trigger or action synthesis.
				table.ensureTable(GG["MissionAPI"].ManagedObjectives, triggerType)
				table.insert(GG["MissionAPI"].ManagedObjectives[triggerType], {
					objectiveID = objectiveID,
					amount = amount,
					nextStage = objective.nextStage,
					stages = objectiveStages,
					parameters = triggerParameters,
				})
			else
				-- Non-managed objective: synthesize trigger + action as usual.
				local isRepeating = amount ~= nil
				local maxRepeats = type(amount) == "number" and amount > 1 and (amount - 1) or nil
				local triggerID = "__objective_" .. objectiveID
				local actionID = "__updateObjective_" .. objectiveID

				rawTriggers[triggerID] = {
					type = triggerType,
					parameters = triggerParameters,
					settings = {
						stages = objectiveStages,
						repeating = isRepeating,
						maxRepeats = maxRepeats,
						active = false,
					},
					actions = { actionID },
				}

				rawActions[actionID] = {
					type = actionTypes.UpdateObjective,
					parameters = {
						objectiveID = objectiveID,
					},
				}

				GG["MissionAPI"].ObjectiveTriggers[objectiveID] = triggerID
			end
		end
	end

	return objectives
end

local function processObjectiveObservers(triggers)
	local objectiveIDParameters = schemaUtils.GetNamesWithParameterType(
		GG["MissionAPI"].TriggerDefinitions.Parameters,
		parameterTypes.Types.ObjectiveID
	)

	local observers = {}
	for _, trigger in pairs(triggers) do
		local parameterName = objectiveIDParameters[trigger.type]

		if parameterName then
			local objectiveID = trigger.parameters[parameterName]
			local byType = table.ensureTable(observers, objectiveID)
			local sequence = table.ensureTable(byType, trigger.type)
			sequence[#sequence + 1] = trigger
		end
	end

	return observers
end

return {
	ProcessRawObjectives = processRawObjectives,
	ProcessObjectiveObservers = processObjectiveObservers,
}
