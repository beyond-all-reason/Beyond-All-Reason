---
--- Publishes mission state to unsynced, and settles interactions answered from there.
---

-- We have four channels available for sending data:
--
-- - RulesParams. State with an optional limited audience.
-- - SendToUnsynced. Uses a broadcast so must not be audience-sensitive.
-- - Unsynced callouts (Spring.PlaySoundFile). These are also broadcasts.
-- - SendLuaRulesMsg. Audience replies, handled in api_missions.lua.
--
-- Where audience limiting generally does not apply to spectators, e.g. for replays.

local PRIVATE = { private = true } ---@type losAccess

local STAGE_PARAM = "missionStage"
local OBJECTIVES_PARAM = "missionObjectives"
local VERSION_PARAM = "missionObjectivesVersion"
local INTERACTION_PARAM = "missionInteraction"

local version = 0
local interactions = {}
local lastInteractionID = 0

---STUB
---@param audience table? `nil` for everyone
---@return integer[]? playerIDs `nil` means everyone
local function getPlayerList(audience)
	return nil
end

local function publish(name, value, audience)
	local playerIDs = getPlayerList(audience)
	if not playerIDs then
		Spring.SetGameRulesParam(name, value)
		return
	end
	for i = 1, #playerIDs do
		Spring.SetPlayerRulesParam(playerIDs[i], name, value, PRIVATE)
	end
end

---@param playerID integer
---@param audience table?
local function isInAudience(playerID, audience)
	local playerIDs = getPlayerList(audience)
	if not playerIDs then
		return true
	end
	for i = 1, #playerIDs do
		if playerIDs[i] == playerID then
			return true
		end
	end
	return false
end

local function objectiveRow(objectiveID, objective)
	return {
		id = objectiveID,
		textKey = objective.textKey,
		completed = objective.completed or false,
		failed = objective.failed or false,
		progress = objective.progress,
		amount = objective.amount,
	}
end

local function orderedObjectiveIDs(missionAPI, objectives)
	local stage = (missionAPI.Stages or {})[missionAPI.CurrentStageID]

	local ordered, listed = {}, {}
	for _, objectiveID in ipairs((stage or {}).objectives or {}) do
		if objectives[objectiveID] and not listed[objectiveID] then
			listed[objectiveID] = true
			ordered[#ordered + 1] = objectiveID
		end
	end

	local rest = {}
	for objectiveID in pairs(objectives) do
		if not listed[objectiveID] then
			rest[#rest + 1] = objectiveID
		end
	end
	table.sort(rest)

	for i = 1, #rest do
		ordered[#ordered + 1] = rest[i]
	end
	return ordered
end

local function publishObjectives(audience)
	local missionAPI = GG["MissionAPI"]
	local objectives = missionAPI.Objectives or {}
	local rows = {}
	for _, objectiveID in ipairs(orderedObjectiveIDs(missionAPI, objectives)) do
		local objective = objectives[objectiveID]
		if not objective.hidden then
			rows[#rows + 1] = objectiveRow(objectiveID, objective)
		end
	end

	version = version + 1
	publish(OBJECTIVES_PARAM, Json.encode(rows), audience)
	publish(VERSION_PARAM, version, audience)
end

local function publishStage(stageID, audience)
	publish(STAGE_PARAM, stageID or "", audience)
end

---For light data that can be lost on `/luaui reload` and has no audience restriction.
local function sendMessage(textKey, audience)
	SendToUnsynced("MissionMessage", textKey)
end

---An open interaction is an ongoing _state_. Reloading UI mid-prompt has to maintain
---or restore state. Its dismissal is the interaction, and arrives on the reply path.
local function openInteraction(kind, textKey, options, audience, onEnd)
	lastInteractionID = lastInteractionID + 1
	local interactionID = lastInteractionID

	interactions[interactionID] = { audience = audience, onEnd = onEnd }
	publish(
		INTERACTION_PARAM,
		Json.encode({ id = interactionID, kind = kind, textKey = textKey, options = options }),
		audience
	)

	return interactionID
end

local function closeInteraction(interactionID, playerID, choice)
	local interaction = interactions[interactionID]
	if not interaction then
		return false
	end
	-- RecvLuaMsg is not authenticated, so verify the sender is in the audience.
	if not isInAudience(playerID, interaction.audience) then
		return false
	end

	interactions[interactionID] = nil
	publish(INTERACTION_PARAM, "", interaction.audience)

	if interaction.onEnd then
		interaction.onEnd(playerID, choice)
	end
	return true
end

return {
	IsInAudience = isInAudience,
	Publish = publish,
	PublishObjectives = publishObjectives,
	PublishStage = publishStage,
	SendMessage = sendMessage,
	OpenInteraction = openInteraction,
	CloseInteraction = closeInteraction,
}
