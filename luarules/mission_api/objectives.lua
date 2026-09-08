---
--- Shared helpers for objective progress/completion and stage advancement.
---

local stageChanges = 0

local function activateEventTrigger(triggerID)
	if not triggerID then
		return
	end
	GG["MissionAPI"].ActivateTrigger(GG["MissionAPI"].Triggers[triggerID])
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
			.. (objective.canceled and " (canceled)" or "")
	)
end

local function setObjectiveActive(objectiveID, active)
	GG["MissionAPI"].Objectives[objectiveID].active = active

	local triggerID = GG["MissionAPI"].ObjectiveTriggers[objectiveID]
	if triggerID then
		GG["MissionAPI"].Triggers[triggerID].settings.active = active
	end
end

local function activateObjective(objectiveID)
	local objective = GG["MissionAPI"].Objectives[objectiveID]
	if objective.active or objective.completed then
		return
	end

	local stages = GG["MissionAPI"].ObjectiveStages[objectiveID]
	if stages and not table.contains(stages, GG["MissionAPI"].CurrentStageID) then
		return
	end

	objective.canceled = false
	setObjectiveActive(objectiveID, true)
	activateEventTrigger(objective.onActivated)
end

local function cancelObjective(objectiveID)
	local objective = GG["MissionAPI"].Objectives[objectiveID]
	if objective.completed or objective.canceled then
		return
	end

	objective.canceled = true
	setObjectiveActive(objectiveID, false)
	activateEventTrigger(objective.onCanceled)
	echoObjectiveUpdate(objectiveID, objective)
end

local function activateStage(stageID, carriedOver)
	local stage = GG["MissionAPI"].Stages[stageID]
	if not stage then
		return
	end

	GG["MissionAPI"].CurrentStageID = stageID
	Spring.Echo("Stage set to: " .. stageID)

	for _, objectiveID in ipairs(stage.objectives) do
		if not (carriedOver and carriedOver[objectiveID]) then
			activateObjective(objectiveID)
		end
	end
end

--- Leaving a stage cancels what it lists and did not finish.
local function exitStage(stageID, carriedOver)
	local stage = GG["MissionAPI"].Stages[stageID]
	if not stage then
		return
	end

	for _, objectiveID in ipairs(stage.objectives) do
		if carriedOver and carriedOver[objectiveID] then
			-- continue
		elseif GG["MissionAPI"].Objectives[objectiveID].completed then
			setObjectiveActive(objectiveID, false)
		else
			cancelObjective(objectiveID)
		end
	end
end

local function getCarriedObjectives(nextStage)
	local carriedOver = {}
	local currentStage = GG["MissionAPI"].Stages[GG["MissionAPI"].CurrentStageID]
	if not currentStage then
		return carriedOver
	end

	local listed = {}
	for _, objectiveID in ipairs(currentStage.objectives) do
		listed[objectiveID] = true
	end
	for _, objectiveID in ipairs(nextStage.objectives) do
		if listed[objectiveID] then
			carriedOver[objectiveID] = true
		end
	end
	return carriedOver
end

local function changeStage(stageID)
	local stage = GG["MissionAPI"].Stages[stageID]
	if not stage then
		return
	end

	local carriedOver = getCarriedObjectives(stage)

	stageChanges = stageChanges + 1
	exitStage(GG["MissionAPI"].CurrentStageID, carriedOver)
	activateStage(stageID, carriedOver)
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

--- Run the stage's exit routes for an objective that has completed or failed.
--- This runs in a fixed order: the objective's event trigger, then nextStage.
local function runExitRoutes(objective, eventTriggerID)
	local stageChangesBefore = stageChanges
	activateEventTrigger(eventTriggerID)
	if stageChanges == stageChangesBefore then
		tryAdvanceStage(objective)
	end
end

local function failObjective(objectiveID)
	local objective = GG["MissionAPI"].Objectives[objectiveID]
	if objective.completed then
		return
	end

	objective.canceled = false
	objective.completed = true
	objective.failed = true
	runExitRoutes(objective, objective.onFailed)
	echoObjectiveUpdate(objectiveID, objective)
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
		onObjectiveCompleted(objective)
	end

	echoObjectiveUpdate(objectiveID, objective)
end

return {
	ActivateStage = activateStage,
	ChangeStage = changeStage,
	TryAdvanceStage = tryAdvanceStage,
	ActivateObjective = activateObjective,
	CancelObjective = cancelObjective,
	UpdateObjectiveProgress = updateObjectiveProgress,
	FailObjective = failObjective,
	OnObjectiveCompleted = onObjectiveCompleted,
	EchoObjectiveUpdate = echoObjectiveUpdate,
}
