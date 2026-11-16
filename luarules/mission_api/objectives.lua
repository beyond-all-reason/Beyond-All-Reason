---
--- Shared helpers for objective progress/completion and stage advancement.
---
--- An objective with a trigger is watched by its condition record (see
--- objectives_loader); this module only decides what activation, progress and
--- completion mean. Objectives without a trigger are driven by actions alone.
---
--- Completion is latched: a completed objective never becomes incomplete again,
--- even if the metric it watched moves back out of range.
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
			.. " | target: "
			.. tostring(objective.target)
			.. " | active: "
			.. tostring(objective.active)
			.. " | completed: "
			.. tostring(objective.completed)
			.. (objective.failed and " (failed)" or "")
			.. (objective.canceled and " (canceled)" or "")
			.. (objective.hidden and " (hidden)" or "")
	)
end

local function setObjectiveActive(objectiveID, active)
	GG["MissionAPI"].Objectives[objectiveID].active = active

	local triggerID = GG["MissionAPI"].ObjectiveTriggers[objectiveID]
	if not triggerID then
		return
	end

	local trigger = GG["MissionAPI"].Triggers[triggerID]
	trigger.settings.active = active

	-- A metric only reports when its value changes. One that was already in range
	-- while the objective was inactive would otherwise wait for the next change.
	if active and trigger.lastValue ~= nil then
		GG["MissionAPI"].EvaluateMetric(trigger, trigger.lastValue)
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

-- `hidden` is an override by the mission author for presentation state.
local function hideObjective(objectiveID)
	local objective = GG["MissionAPI"].Objectives[objectiveID]
	if objective.hidden then
		return
	end

	objective.hidden = true
	activateEventTrigger(objective.onHidden)
	echoObjectiveUpdate(objectiveID, objective)
end

local function showObjective(objectiveID)
	local objective = GG["MissionAPI"].Objectives[objectiveID]
	if not objective.hidden then
		return
	end

	objective.hidden = false
	activateEventTrigger(objective.onShown)
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

local function completeObjective(objectiveID)
	local objective = GG["MissionAPI"].Objectives[objectiveID]
	if objective.completed then
		return
	end

	objective.canceled = false
	objective.completed = true
	objective.progress = objective.target
	runExitRoutes(objective, objective.onCompleted)
	echoObjectiveUpdate(objectiveID, objective)
end

--- Progress that did not complete the objective. Events report how many
--- occurrences have been tallied towards their amount; metrics report the value last
--- sampled against the level they must reach. Metrics are sampled often,
--- so only a changed value counts as progress.
local function reportProgress(objectiveID, progress)
	local objective = GG["MissionAPI"].Objectives[objectiveID]
	if objective.completed or objective.progress == progress then
		return
	end

	objective.progress = progress
	activateEventTrigger(objective.onProgress)
	echoObjectiveUpdate(objectiveID, objective)
end

--- One step of progress towards the amount, for objectives that actions drive.
local function updateObjective(objectiveID)
	local objective = GG["MissionAPI"].Objectives[objectiveID]
	if objective.completed or not objective.active then
		return
	end

	local progress = (objective.progress or 0) + 1
	if progress >= objective.target then
		completeObjective(objectiveID)
	else
		reportProgress(objectiveID, progress)
	end
end

return {
	ActivateStage = activateStage,
	ChangeStage = changeStage,
	TryAdvanceStage = tryAdvanceStage,
	ActivateObjective = activateObjective,
	CancelObjective = cancelObjective,
	UpdateObjective = updateObjective,
	ReportProgress = reportProgress,
	CompleteObjective = completeObjective,
	FailObjective = failObjective,
	HideObjective = hideObjective,
	ShowObjective = showObjective,
	EchoObjectiveUpdate = echoObjectiveUpdate,
}
