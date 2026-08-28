---
--- Publishes mission state to unsynced, and settles interactions answered from there.
---
--- Four channels reach the player, and the audience decides which one is legal:
---   * rules params  - state a late consumer must re-render; the only audience the engine enforces
---   * SendToUnsynced - moments; broadcast, so never audience-sensitive
---   * unsynced callouts from synced (Spring.PlaySoundFile) - broadcast, same restriction
---   * SendLuaRulesMsg - the reply path, handled in api_missions.lua
---

local OBJECTIVES_PARAM = "missionObjectives"
local VERSION_PARAM = "missionObjectivesVersion"
local STAGE_PARAM = "missionStage"
local INTERACTION_PARAM = "missionInteraction"

local PRIVATE = { private = true }

local version = 0
local interactions = {}
local lastInteractionID = 0

---STUB: everyone, always. Returns a list of playerIDs, or `nil` meaning the whole game.
---Coop fills this in; the audience parameter is already threaded everywhere it is needed.
---@param audience table? `nil` for everyone
---@return integer[]? playerIDs `nil` means everyone
local function resolveAudience(audience)
	return nil
end

---The one place a mission rules param is written. `SetPlayerRulesParam` with private
---access is the only audience the engine enforces; anything on a broadcast channel can
---be read by a replaced widget regardless of what the payload claims.
local function publish(name, value, audience)
	local playerIDs = resolveAudience(audience)
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
	local playerIDs = resolveAudience(audience)
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

---Display order is the current stage's objective list, which is the only order the
---author wrote down. Anything not listed there follows, sorted, so the order is stable.
local function orderedObjectiveIDs()
	local objectives = GG["MissionAPI"].Objectives or {}
	local stage = (GG["MissionAPI"].Stages or {})[GG["MissionAPI"].CurrentStageID]

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

---Hidden objectives are filtered here, in synced, and never in the widget: widgets are
---replaceable by design, so unsynced must not hold what the player should not see.
local function publishObjectives(audience)
	local objectives = GG["MissionAPI"].Objectives or {}
	local rows = {}
	for _, objectiveID in ipairs(orderedObjectiveIDs()) do
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

---A moment: losing it on a `/luaui reload` changes nothing afterwards, so it goes on the
---broadcast channel. Anything with an audience must be state instead.
local function sendMessage(textKey, audience)
	SendToUnsynced("MissionMessage", textKey)
end

---An open interaction is *state*, not a moment: reloading the UI mid-prompt has to bring
---it back. Its dismissal is the moment, and that arrives on the reply path.
---@return integer interactionID
local function raiseInteraction(kind, textKey, options, audience, onEnd)
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

---Settle an interaction from a reply. `RecvLuaMsg` is unauthenticated - any client can
---claim to answer anything - so the sender must be in the audience. That check is not a
---stub; only the audience it consults is.
---@return boolean accepted
local function endInteraction(interactionID, playerID, choice)
	local interaction = interactions[interactionID]
	if not interaction then
		return false
	end
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
	Publish = publish,
	IsInAudience = isInAudience,
	PublishObjectives = publishObjectives,
	PublishStage = publishStage,
	SendMessage = sendMessage,
	RaiseInteraction = raiseInteraction,
	EndInteraction = endInteraction,
}
