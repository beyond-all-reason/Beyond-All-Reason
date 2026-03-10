----------------------------------------------------------------
---Broadcast helper functions for mission events
----------------------------------------------------------------

local function objectiveUpdated(objectiveID, text, progress, amount, completed)
	local msg
	if completed then
		msg = "missionObjective|done|" .. objectiveID .. "|" .. (text or '')
	elseif amount ~= nil and amount > 0 then
		msg = "missionObjective|progress|" .. objectiveID .. "|" .. (text or '') .. "|" .. tostring(progress or 0) .. "|" .. tostring(amount)
	elseif amount ~= nil and amount == 0 then
		msg = "missionObjective|remaining|" .. objectiveID .. "|" .. (text or '') .. "|" .. tostring(progress or 0)
	else
		msg = "missionObjective|text|" .. objectiveID .. "|" .. (text or '')
	end
	Spring.SendLuaUIMsg(msg)
end

local function stageChanged(stageID)
	local stageData = GG['MissionAPI'].Stages[stageID]

	-- Broadcast stage change
	local msg = "missionStage|" .. (stageData.title or stageID) .. "|" .. table.concat(stageData.objectives or {}, "|")
	Spring.SendLuaUIMsg(msg)

	-- Broadcast objectives
	for _, objectiveID in ipairs(stageData.objectives) do
		local objective = GG['MissionAPI'].Objectives[objectiveID]
		objectiveUpdated(objectiveID, objective.text, objective.progress, objective.amount, objective.completed)
	end
end

return {
	StageChanged = stageChanged,
	ObjectiveUpdated = objectiveUpdated,
}
