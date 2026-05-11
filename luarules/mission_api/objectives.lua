---
--- Shared helpers for objective progress/completion and stage advancement.
---

local function changeStage(stageID)
	GG['MissionAPI'].CurrentStageID = stageID
	Spring.Echo("Stage set to: " .. stageID)
end

--- Advance to nextStage if the objective is completed and every other objective
--- in the current stage with the same nextStage is also complete.
local function tryAdvanceStage(objective, nextStage)
	if not objective.completed then return end
	if not nextStage then return end

	local currentStageID = GG['MissionAPI'].CurrentStageID
	for _, other in pairs(GG['MissionAPI'].Objectives) do
		if table.contains(other.stages or {}, currentStageID)
			and other.nextStage == nextStage
			and not other.completed then
			return
		end
	end
	changeStage(nextStage)
end

-- placeholder until UI widget exists
local function echoObjectiveUpdate(objectiveID, objective)
	Spring.Echo("Objective updated: " .. objectiveID
		.. " | " .. (objective.text or '')
		.. " | progress: " .. tostring(objective.progress)
		.. " | amount: " .. tostring(objective.amount)
		.. " | completed: " .. tostring(objective.completed))
end

return {
	ChangeStage         = changeStage,
	TryAdvanceStage     = tryAdvanceStage,
	EchoObjectiveUpdate = echoObjectiveUpdate,
}
