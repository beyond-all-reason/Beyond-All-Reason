---
--- Stage state for the Mission API.
---
--- Owns CurrentStageID. Entering a stage activates the objectives it lists, and
--- leaving one cancels the ones it listed but did not finish. What an objective
--- does once activated or canceled belongs to objectives.lua.
---

-- Counts every stage change, so a caller can tell whether something it ran
-- (an objective's event trigger, say) already moved the mission on.
local changeCount = 0

local function getObjectives()
	return GG["MissionAPI"].Modules.Objectives
end

local function getCurrentStageID()
	return GG["MissionAPI"].CurrentStageID
end

local function getChangeCount()
	return changeCount
end

--- Sets the opening stage without activating it; api_missions activates it once
--- the loadout has spawned.
local function setInitialStage(stageID)
	GG["MissionAPI"].CurrentStageID = stageID
end

local function getStage(stageID)
	return GG["MissionAPI"].Stages[stageID]
end

local function activateStage(stageID, carriedOver)
	local stage = getStage(stageID)
	if not stage then
		return
	end

	GG["MissionAPI"].CurrentStageID = stageID

	local objectives = getObjectives()
	for _, objectiveID in ipairs(stage.objectives) do
		if not (carriedOver and carriedOver[objectiveID]) then
			objectives.ActivateObjective(objectiveID)
		end
	end
end

--- Leaving a stage cancels what it lists and did not finish.
local function exitStage(stageID, carriedOver)
	local stage = getStage(stageID)
	if not stage then
		return
	end

	local objectives = getObjectives()
	for _, objectiveID in ipairs(stage.objectives) do
		if carriedOver and carriedOver[objectiveID] then
			-- continue
		elseif GG["MissionAPI"].Objectives[objectiveID].completed then
			objectives.SetObjectiveActive(objectiveID, false)
		else
			objectives.CancelObjective(objectiveID)
		end
	end
end

--- Objectives listed in both the current and the next stage carry over untouched.
local function getCarriedObjectives(nextStage)
	local carriedOver = {}
	local currentStage = getStage(getCurrentStageID())
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
	local stage = getStage(stageID)
	if not stage then
		return
	end

	local carriedOver = getCarriedObjectives(stage)

	changeCount = changeCount + 1
	exitStage(getCurrentStageID(), carriedOver)
	activateStage(stageID, carriedOver)
end

return {
	GetCurrentStageID = getCurrentStageID,
	GetChangeCount = getChangeCount,
	SetInitialStage = setInitialStage,
	GetStage = getStage,
	ActivateStage = activateStage,
	ChangeStage = changeStage,
}
