local validation = VFS.Include('luarules/mission_api/validation.lua')
local triggersSchema = VFS.Include('luarules/mission_api/triggers_schema.lua')
local parameterTypes = VFS.Include('luarules/mission_api/parameter_types.lua')
local objectiveUtils = VFS.Include('luarules/mission_api/objectives.lua')

--[[
	objectiveID = {
		textKey = "complete_objective",
		amount = 3,
		stages = { 'firstStage' },
		trigger = {
			type = triggerTypes.TimeElapsed,
			parameters = {
				gameFrame = 90,
			},
		},
		nextStage = 'secondStage',
		coop = true,
	},
]]

local triggerTypesWithQuantity = validation.GetTypesWithParameterType(triggersSchema.Parameters, parameterTypes.Types.Quantity)


local function processRawObjectives(rawObjectives, rawTriggers, rawActions, initialStage)
	local objectives = table.map(rawObjectives, table.copy)

	local actionTypes = GG['MissionAPI'].ActionTypes

	for objectiveID, objective in pairs(objectives) do
		objective.stages = objective.stages or {}

		if objective.trigger then
			local amount = objective.amount
			local triggerType = objective.trigger.type
			local triggerParameters = table.copy(objective.trigger.parameters or {})

			if triggerTypesWithQuantity[triggerType] then
				-- Managed objective: register metadata for lookaside lookup; no trigger or action synthesis.
				table.ensureTable(GG['MissionAPI'].ManagedObjectives, triggerType)
				table.insert(GG['MissionAPI'].ManagedObjectives[triggerType], {
					objectiveID = objectiveID,
					amount = amount,
					nextStage = objective.nextStage,
					stages = objective.stages,
					parameters = triggerParameters,
				})
			else
				-- Non-managed objective: synthesize trigger + action as usual.
				local isRepeating = amount ~= nil
				local triggerID = '__objective_' .. objectiveID
				local actionID  = '__updateObjective_' .. objectiveID

				rawTriggers[triggerID] = {
					type       = triggerType,
					parameters = triggerParameters,
					settings   = {
						stages     = objective.stages,
						repeating  = isRepeating,
						maxRepeats = isRepeating and amount > 1 and (amount - 1) or nil,
					},
					actions = { actionID },
				}

				rawActions[actionID] = {
					type       = actionTypes.UpdateObjective,
					parameters = {
						objectiveID = objectiveID,
						nextStage   = objective.nextStage,
					},
				}
			end
		end
	end

	validation.ValidateObjectives(objectives)
	validation.ValidateInitialStage(initialStage)

	return objectives
end

return {
	ProcessRawObjectives = processRawObjectives,
}
