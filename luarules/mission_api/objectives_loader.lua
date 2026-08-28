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
	local actionTypes = GG["MissionAPI"].ActionDefinitions.Types
	local triggerTypesWithQuantity = schemaUtils.GetTypesWithParameterType(
		GG["MissionAPI"].TriggerDefinitions.Parameters,
		parameterTypes.Types.Quantity
	)

	-- Build objective-to-stages mapping from stages structure
	local objectiveToStages = {}
	for stageID, stageData in pairs(stages) do
		for _, objectiveID in ipairs(stageData.objectives) do
			table.insert(table.ensureTable(objectiveToStages, objectiveID), stageID)
		end
	end

	for objectiveID, objective in pairs(rawObjectives) do
		-- An objective without a trigger is completed by an UpdateObjective action instead.
		if type(objective.trigger) == "table" then
			local objectiveStages = objectiveToStages[objectiveID] or {}
			local amount = objective.amount
			local triggerType = objective.trigger.type
			local triggerParameters = objective.trigger.parameters or {}

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
				local maxRepeats = amount and amount > 1 and (amount - 1) or nil
				local triggerID = "__objective_" .. objectiveID
				local actionID = "__updateObjective_" .. objectiveID

				rawTriggers[triggerID] = {
					type = triggerType,
					parameters = triggerParameters,
					settings = {
						stages = objectiveStages,
						repeating = isRepeating,
						maxRepeats = maxRepeats,
					},
					actions = { actionID },
				}

				rawActions[actionID] = {
					type = actionTypes.UpdateObjective,
					parameters = {
						objectiveID = objectiveID,
					},
				}
			end
		end
	end

	return rawObjectives
end

return {
	ProcessRawObjectives = processRawObjectives,
}
