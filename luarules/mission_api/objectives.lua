---
--- Shared helpers for objective progress/completion and stage advancement.
---

local stageChanges = 0

local function changeStage(stageID)
	stageChanges = stageChanges + 1
	GG["MissionAPI"].CurrentStageID = stageID
	Spring.Echo("Stage set to: " .. stageID)
end

--- Advance to nextStage if the objective is completed and every other objective
--- in the current stage with the same nextStage is also complete.
local function tryAdvanceStage(objective)
	local nextStage = objective.nextStage

	if not objective.completed then
		return
	end
	if not nextStage then
		return
	end

	local currentStageID = GG["MissionAPI"].CurrentStageID
	local currentStage = GG["MissionAPI"].Stages[currentStageID]
	if not currentStage then
		return
	end

	for _, otherObjectiveID in pairs(currentStage.objectives) do
		local otherObjective = GG["MissionAPI"].Objectives[otherObjectiveID]
		if otherObjective.nextStage == nextStage and not otherObjective.completed then
			return
		end
	end

	changeStage(nextStage)
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
			.. (objective.failed and " (failed)" or "")
	)
end

local function activateEventTrigger(triggerID)
	if not triggerID then
		return
	end
	GG["MissionAPI"].ActivateTrigger(GG["MissionAPI"].Triggers[triggerID])
end

local function failObjective(objectiveID)
	local objective = GG["MissionAPI"].Objectives[objectiveID]
	if objective.completed then
		return
	end

	objective.completed = true
	objective.failed = true
	runExitRoutes(objective, objective.onFailed)
	echoObjectiveUpdate(objectiveID, objective)
end

--- Run the stage's exit routes for an objective that has completed or failed.
--- This runs in a fixed order: the objective's event trigger, then nextStage.
local function runExitRoutes(objective, eventTriggerID)
	local stageChangesBefore = stageChanges
	activateEventTrigger(eventTriggerID)
	if stageChanges == stageChangesBefore then
		tryAdvanceStage(objective)
	end
end

local function onObjectiveCompleted(objective)
	runExitRoutes(objective, objective.onCompleted)
end

--- Update objective progress for a managed (statistics-based) objective.
--- Called when the trigger's event fires with updated counts.
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

	-- Track count regardless of stage:
	managedObjMetadata._count = (managedObjMetadata._count or 0) + direction

	if
		next(managedObjMetadata.stages)
		and not table.contains(managedObjMetadata.stages, GG["MissionAPI"].CurrentStageID)
	then
		return
	end

	local objective = GG["MissionAPI"].Objectives[objectiveID]
	if objective.completed then
		return
	end

	objective.progress = managedObjMetadata._count

	local isComplete
	local amount = managedObjMetadata.amount
	if amount == nil then
		isComplete = true
	elseif amount == 0 then
		isComplete = managedObjMetadata._count == 0
	else
		isComplete = managedObjMetadata._count >= amount
	end

	objective.completed = isComplete
	if isComplete then
		onObjectiveCompleted(objective)
	end

	echoObjectiveUpdate(objectiveID, objective)
end

return {
	ChangeStage = changeStage,
	TryAdvanceStage = tryAdvanceStage,
	FailObjective = failObjective,
	UpdateObjectiveProgress = updateObjectiveProgress,
	OnObjectiveCompleted = onObjectiveCompleted,
	EchoObjectiveUpdate = echoObjectiveUpdate,
}
