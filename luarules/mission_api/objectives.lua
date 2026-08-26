---
--- Objective progress and completion for the Mission API.
---
--- One engine for both condition kinds. The objective's condition record does
--- the watching (see objectives_loader); this module only decides what a
--- completion means.
---
--- Completion is latched: a completed objective never becomes incomplete again,
--- even if the metric it watched moves back out of range.
---

local function getStages()
	return GG["MissionAPI"].Modules.Stages
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
			.. " | completed: "
			.. tostring(objective.completed)
	)
end

--- Advances to onComplete.nextStage once every objective in the current stage
--- that shares that nextStage is also complete.
local function tryAdvanceStage(objective)
	local nextStage = objective.onComplete and objective.onComplete.nextStage

	if not objective.completed then
		return
	end
	if not nextStage then
		return
	end

	local stages = getStages()
	local currentStage = stages.GetStage(stages.GetCurrentStageID())
	if not currentStage then
		return
	end

	for _, otherObjectiveID in pairs(currentStage.objectives) do
		local otherObjective = GG["MissionAPI"].Objectives[otherObjectiveID]
		local otherNextStage = otherObjective and otherObjective.onComplete and otherObjective.onComplete.nextStage
		if otherNextStage == nextStage and not otherObjective.completed then
			return
		end
	end

	stages.ChangeStage(nextStage)
end

local function runCompletionActions(objective)
	local actionIDs = objective.onComplete and objective.onComplete.actions
	if not actionIDs then
		return
	end

	local dispatcher = GG["MissionAPI"].Modules.ActionsDispatcher
	if not dispatcher then
		return
	end

	for _, actionID in ipairs(actionIDs) do
		dispatcher.Invoke(actionID)
	end
end

--- Records progress for the UI. Events report how many occurrences have been
--- tallied out of `count`; metrics report the value last sampled against the
--- bound they are being compared with.
local function reportProgress(objectiveID, progress)
	local objective = GG["MissionAPI"].Objectives[objectiveID]
	if not objective or objective.completed then
		return
	end

	objective.progress = progress
	echoObjectiveUpdate(objectiveID, objective)
end

--- Called when an objective's condition is satisfied.
local function complete(objectiveID)
	local objective = GG["MissionAPI"].Objectives[objectiveID]
	if not objective or objective.completed then
		return
	end

	objective.completed = true
	objective.progress = objective.target

	runCompletionActions(objective)
	tryAdvanceStage(objective)
	echoObjectiveUpdate(objectiveID, objective)
end

--- Author-facing UpdateObjective action: set completion and/or text directly.
local function update(objectiveID, completed, textKey)
	local objective = GG["MissionAPI"].Objectives[objectiveID]
	if not objective or objective.completed then
		return
	end

	if textKey then
		objective.textKey = textKey
	end

	if completed then
		complete(objectiveID)
		return
	end

	if completed == nil and textKey == nil then
		complete(objectiveID)
		return
	end

	echoObjectiveUpdate(objectiveID, objective)
end

return {
	Complete = complete,
	Update = update,
	ReportProgress = reportProgress,
	TryAdvanceStage = tryAdvanceStage,
	EchoObjectiveUpdate = echoObjectiveUpdate,
}
