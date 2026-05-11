local validation = VFS.Include('luarules/mission_api/validation.lua')
local triggersSchema = VFS.Include('luarules/mission_api/triggers_schema.lua')
local parameterTypes = VFS.Include('luarules/mission_api/parameter_types.lua')
local objectiveUtils = VFS.Include('luarules/mission_api/objectives.lua')

--[[
	objectiveID = {
		text = "Complete this objective.",
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

local function makeObjectiveProgressCallback(objectiveID, amount, nextStage, stages, parameters)
	local count = 0
	return function(eventTeamID, eventUnitDefName, eventUnitNames, direction)
		if parameters.unitDefName and eventUnitDefName ~= parameters.unitDefName then return end
		if parameters.unitName and not eventUnitNames[parameters.unitName] then return end
		if eventTeamID ~= parameters.teamID then return end

		-- Track count regardless of stage:
		count = count + direction

		if next(stages) and not table.contains(stages, GG['MissionAPI'].CurrentStageID) then return end

		local objective = GG['MissionAPI'].Objectives[objectiveID]
		if objective.completed then return end

		objective.progress = count

		local isComplete
		if amount == nil then
			isComplete = true
		elseif amount == 0 then
			isComplete = count == 0
		else
			isComplete = count >= amount
		end

		objective.completed = isComplete
		objectiveUtils.TryAdvanceStage(objective, nextStage)

		objectiveUtils.EchoObjectiveUpdate(objectiveID, objective)
	end
end

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
				-- Managed objective: register a callback directly; no trigger or action synthesis.
				table.ensureTable(GG['MissionAPI'].ObjectiveTriggers, triggerType)
				table.insert(GG['MissionAPI'].ObjectiveTriggers[triggerType],
					makeObjectiveProgressCallback(objectiveID, amount, objective.nextStage, objective.stages, triggerParameters))
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
