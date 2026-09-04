---
--- Shared helpers for objective progress/completion and stage advancement.
---

local stageChanges = 0

local function setObjectiveActive(objectiveID, active)
	GG["MissionAPI"].Objectives[objectiveID].active = active

	local triggerID = GG["MissionAPI"].ObjectiveTriggers[objectiveID]
	if triggerID then
		GG["MissionAPI"].Triggers[triggerID].settings.active = active
	end
end

--- Enables progress, display, and any synthesized triggers on an objective.
local function activateObjective(objectiveID)
	if GG["MissionAPI"].Objectives[objectiveID].completed then
		return
	end

	local stages = GG["MissionAPI"].ObjectiveStages[objectiveID]
	if stages and not table.contains(stages, GG["MissionAPI"].CurrentStageID) then
		return
	end

	setObjectiveActive(objectiveID, true)
end

local function activateStage(stageID)
	local stage = GG["MissionAPI"].Stages[stageID]
	if not stage then
		return
	end

	GG["MissionAPI"].CurrentStageID = stageID
	Spring.Echo("Stage set to: " .. stageID)

	for _, objectiveID in ipairs(stage.objectives) do
		activateObjective(objectiveID)
	end
end

--- Disables progress, display, and any synthesized triggers on an objective.
local function deactivateObjective(objectiveID)
	setObjectiveActive(objectiveID, false)
end

local function deactivateStage(stageID)
	local stage = GG["MissionAPI"].Stages[stageID]
	if not stage then
		return
	end

	for _, objectiveID in ipairs(stage.objectives) do
		deactivateObjective(objectiveID)
	end
end

local function changeStage(stageID)
	if not GG["MissionAPI"].Stages[stageID] then
		return
	end

	stageChanges = stageChanges + 1
	deactivateStage(GG["MissionAPI"].CurrentStageID)
	activateStage(stageID)
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
			.. " | active: "
			.. tostring(objective.active)
			.. " | completed: "
			.. tostring(objective.completed)
			.. (objective.failed and " (failed)" or "")
	)
end

--- Activates every trigger of the given type watching the objective.
local function notifyObservers(objectiveID, triggerType)
	local observers = GG["MissionAPI"].ObjectiveObservers[objectiveID]
	local triggers = observers and observers[triggerType]
	if not triggers then
		return
	end

	local activateTrigger = GG["MissionAPI"].ActivateTrigger
	for i = 1, #triggers do
		activateTrigger(triggers[i])
	end
end

--- Run the stage's exit routes for an objective that has just completed or failed.
--- This runs in a fixed order: observer triggers of triggerType, then nextStage.
local function runExitRoutes(objectiveID, objective, triggerType)
	local stageChangesBefore = stageChanges
	notifyObservers(objectiveID, triggerType)
	if stageChanges == stageChangesBefore then
		tryAdvanceStage(objective)
	end
end

local function onObjectiveCompleted(objectiveID, objective)
	runExitRoutes(objectiveID, objective, GG["MissionAPI"].TriggerDefinitions.Types.ObjectiveCompleted)
end

local function failObjective(objectiveID)
	local objective = GG["MissionAPI"].Objectives[objectiveID]
	if objective.completed then
		return
	end

	objective.completed = true
	objective.failed = true
	runExitRoutes(objectiveID, objective, GG["MissionAPI"].TriggerDefinitions.Types.ObjectiveFailed)
	echoObjectiveUpdate(objectiveID, objective)
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
	if objective.completed or not objective.active then
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
		onObjectiveCompleted(objectiveID, objective)
	end

	echoObjectiveUpdate(objectiveID, objective)
end

return {
	ActivateStage = activateStage,
	ChangeStage = changeStage,
	TryAdvanceStage = tryAdvanceStage,
	ActivateObjective = activateObjective,
	DeactivateObjective = deactivateObjective,
	FailObjective = failObjective,
	UpdateObjectiveProgress = updateObjectiveProgress,
	OnObjectiveCompleted = onObjectiveCompleted,
	EchoObjectiveUpdate = echoObjectiveUpdate,
}
