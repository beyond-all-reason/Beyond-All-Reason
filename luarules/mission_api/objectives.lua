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
		.. " | " .. (objective.textKey or '')
		.. " | progress: " .. tostring(objective.progress)
		.. " | amount: " .. tostring(objective.amount)
		.. " | completed: " .. tostring(objective.completed))
end

--- Update objective progress for a managed (statistics-based) objective.
--- Called when the trigger's event fires with updated counts.
local function updateObjectiveProgress(objectiveID, eventTeamID, eventUnitDefName, eventUnitNames, direction, managedObjMetadata)
	if eventTeamID ~= managedObjMetadata.parameters.teamID then return end
	if managedObjMetadata.parameters.unitDefName and eventUnitDefName ~= managedObjMetadata.parameters.unitDefName then return end
	if managedObjMetadata.parameters.unitName and not (eventUnitNames or {})[managedObjMetadata.parameters.unitName] then return end

	-- Track count regardless of stage:
	managedObjMetadata._count = (managedObjMetadata._count or 0) + direction

	if next(managedObjMetadata.stages) and not table.contains(managedObjMetadata.stages, GG['MissionAPI'].CurrentStageID) then return end

	local objective = GG['MissionAPI'].Objectives[objectiveID]
	if objective.completed then return end

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
	tryAdvanceStage(objective, managedObjMetadata.nextStage)

	echoObjectiveUpdate(objectiveID, objective)
end

return {
	ChangeStage             = changeStage,
	TryAdvanceStage         = tryAdvanceStage,
	UpdateObjectiveProgress = updateObjectiveProgress,
	EchoObjectiveUpdate     = echoObjectiveUpdate,
}
