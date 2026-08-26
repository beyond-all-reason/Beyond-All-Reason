---
--- Stage state for the Mission API.
---
--- Owns CurrentStageID. Objectives ask this module to advance; nothing else
--- writes the current stage.
---

local function announce(stageID)
	Spring.Echo("Stage set to: " .. stageID)
end

local function getCurrentStageID()
	return GG["MissionAPI"].CurrentStageID
end

local function changeStage(stageID)
	GG["MissionAPI"].CurrentStageID = stageID
	announce(stageID)
end

--- Sets the opening stage without re-announcing it; api_missions announces once
--- everything is loaded.
local function setInitialStage(stageID)
	GG["MissionAPI"].CurrentStageID = stageID
end

local function getStage(stageID)
	return GG["MissionAPI"].Stages[stageID]
end

--- Objective IDs active in the given stage (defaults to the current stage).
local function getObjectiveIDs(stageID)
	local stage = getStage(stageID or getCurrentStageID())
	return stage and stage.objectives or {}
end

return {
	Announce = announce,
	GetCurrentStageID = getCurrentStageID,
	ChangeStage = changeStage,
	SetInitialStage = setInitialStage,
	GetStage = getStage,
	GetObjectiveIDs = getObjectiveIDs,
}
