---
--- Shared helpers for objective progress/completion and stage changes.
---

-- Activating and iterating triggers is handled through the triggers gadget.
local processTriggersOfType, activateTrigger

local function init(dependencies)
	processTriggersOfType = dependencies.processTriggersOfType
	activateTrigger = dependencies.activateTrigger
end

local function changeStage(stageID)
	GG["MissionAPI"].CurrentStageID = stageID
	Spring.Echo("Stage set to: " .. stageID)
end

-- placeholder until UI widget exists
local function echoObjectiveUpdate(objectiveID, objective)
	Spring.Echo(
		"Objective updated: "
			.. objectiveID
			.. " | "
			.. (objective.textKey or "")
			.. " | progress: "
			.. tostring(objective.progress)
			.. " | amount: "
			.. tostring(objective.amount)
			.. " | completed: "
			.. tostring(objective.completed)
	)
end

---@param amount integer? `nil` completes on any progress, `0` only on exactly zero
local function isCompleteAtAmount(progress, amount)
	if amount == nil then
		return true
	elseif amount == 0 then
		return progress == 0
	end
	return progress >= amount
end

---Triggers of type `ObjectiveCompleted` are iterated and activate on a match.
local function notifyObjectiveCompleted(completedObjectiveID)
	if not processTriggersOfType then
		return
	end

	local triggerTypes = (GG["MissionAPI"].TriggerDefinitions or {}).Types
	if not triggerTypes then
		return
	end

	processTriggersOfType(triggerTypes.ObjectiveCompleted, function(trigger)
		if trigger.parameters.objectiveID == completedObjectiveID then
			activateTrigger(trigger)
		end
	end)
end

---Triggers of type `ObjectiveFailed` are iterated and activate on a match.
local function notifyObjectiveFailed(failedObjectiveID)
	if not processTriggersOfType then
		return
	end

	local triggerTypes = (GG["MissionAPI"].TriggerDefinitions or {}).Types
	if not triggerTypes then
		return
	end

	processTriggersOfType(triggerTypes.ObjectiveFailed, function(trigger)
		if trigger.parameters.objectiveID == failedObjectiveID then
			activateTrigger(trigger)
		end
	end)
end

local function evaluateObjective(objectiveID, objective)
	objective.completed = isCompleteAtAmount(objective.progress, objective.amount)
	if objective.completed then
		notifyObjectiveCompleted(objectiveID)
	end
	echoObjectiveUpdate(objectiveID, objective)
end

local function incrementObjective(objectiveID)
	local objective = GG["MissionAPI"].Objectives[objectiveID]
	if objective.completed then
		return
	end

	objective.progress = (objective.progress or 0) + 1
	evaluateObjective(objectiveID, objective)
end

local function completeObjective(objectiveID, completed)
	local objective = GG["MissionAPI"].Objectives[objectiveID]
	if objective.completed then
		return
	end

	objective.completed = completed
	if completed then
		notifyObjectiveCompleted(objectiveID)
	end
	echoObjectiveUpdate(objectiveID, objective)
end

---Update objective progress for a managed (statistics-based) objective.
---Called when the trigger's event fires with updated counts. The count
---accrues in any stage but completion requires the objective's stages.
local function updateObjectiveProgress(
	objectiveID,
	eventTeamID,
	eventUnitDefName,
	eventUnitNames,
	direction,
	managedObjMetadata
)
	if eventTeamID ~= managedObjMetadata.parameters.teamID then
		return
	end
	if managedObjMetadata.parameters.unitDefName and eventUnitDefName ~= managedObjMetadata.parameters.unitDefName then
		return
	end
	if
		managedObjMetadata.parameters.unitName and not (eventUnitNames or {})[managedObjMetadata.parameters.unitName]
	then
		return
	end

	local objective = GG["MissionAPI"].Objectives[objectiveID]
	if objective.completed then
		return
	end

	objective.progress = (objective.progress or 0) + direction

	if
		next(managedObjMetadata.stages)
		and not table.contains(managedObjMetadata.stages, GG["MissionAPI"].CurrentStageID)
	then
		return
	end

	evaluateObjective(objectiveID, objective)
end

return {
	Init = init,
	ChangeStage = changeStage,
	SetObjectiveCompleted = completeObjective,
	IncrementObjectiveProgress = incrementObjective,
	UpdateObjectiveProgress = updateObjectiveProgress,
	NotifyObjectiveFailed = notifyObjectiveFailed,
	EchoObjectiveUpdate = echoObjectiveUpdate,
}
