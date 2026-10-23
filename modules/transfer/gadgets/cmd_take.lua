function gadget:GetInfo()
	return {
		name = "Take Command",
		desc = "Implements /take command to transfer units/resources from empty allied teams",
		author = "Antigravity",
		date = "2024",
		license = "GPL-v2",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	-- What a take moved reaches every ally and spectator as the same "<name> Allies: > key:params" line as
	-- game_message, so gui_chat translates it for each reader.
	local function teamTaken(_, playerID, teamID, units, energy, metal)
		local takerName, _, _, _, takerAllyTeamID = Spring.GetPlayerInfo(playerID, false)
		local leaderID = select(2, Spring.GetTeamInfo(teamID, false))
		local takenName = leaderID and leaderID >= 0 and Spring.GetPlayerInfo(leaderID, false)
		if not takerName or not takenName then
			return
		end
		if takerAllyTeamID == Spring.GetLocalAllyTeamID() or Spring.GetSpectatingState() then
			Spring.SendMessageToPlayer(
				Spring.GetLocalPlayerID(),
				"<"
					.. takerName
					.. "> Allies: > ui.playersList.chat.takeTeamAmount:name="
					.. takenName
					.. ":units="
					.. units
					.. ":energy="
					.. energy
					.. ":metal="
					.. metal
			)
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("TeamTaken", teamTaken)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction("TeamTaken")
	end

	return
end

local ConstructionEnums = require("modules/construction/enums")
local Shared = require("modules/transfer/unit/shared")
local TakeComms = require("modules/transfer/take/comms")
local ResourceTransfer = require("modules/transfer/api_synced").Resources
local TransferEnums = require("modules/transfer/enums")
local EconomyResources = require("modules/economy/api").Resources ---@type EconomyResourcesApi

local TAKE_MSG = "take_cmd"

local takePolicy = TakeComms.GetPolicy(Spring.GetModOptions())
local takeMode = takePolicy.mode
local takeDelaySeconds = takePolicy.delaySeconds
local takeDelayCategory = takePolicy.delayCategory

local pendingDelayedTakes = {} ---@type table<integer, { takerTeamID: integer, expiryFrame: number }|nil>

local function hasActivePlayer(otherTeamID)
	for _, pID in ipairs(Spring.GetPlayerList() or {}) do
		local _, active, spectator, pTeamID = Spring.GetPlayerInfo(pID)
		if active and not spectator and pTeamID == otherTeamID then
			return true
		end
	end
	return false
end

-- Everything the team holds, up to the room under the taker's share slider: a taker above their slider has no room,
-- and a negative amount would send resources back.
---@param fromTeamID integer
---@param toTeamID integer
---@return number energy moved
---@return number metal moved
local function transferResources(fromTeamID, toTeamID)
	local moved = { metal = 0, energy = 0 } ---@type table<string, number>
	for _, resource in ipairs({ "metal", "energy" }) do
		local amount = EconomyResources.Get(Spring --[[@as Recoil.Shared]], fromTeamID, resource) or 0
		local current, storage, _, _, _, shareSlider =
			EconomyResources.Get(Spring --[[@as Recoil.Shared]], toTeamID, resource)
		amount = math.max(0, math.min(amount, (shareSlider or 1) * (storage or 0) - (current or 0)))
		if amount > 0 then
			moved[resource] = ResourceTransfer.Give(resource, amount, toTeamID, fromTeamID)
		end
	end
	return moved.energy, moved.metal
end

-- Units the engine let go, counted; every unit of the team is offered.
---@param fromTeamID integer
---@param toTeamID integer
---@param accept (fun(unitDefID: integer): boolean)|nil which units move this pass; all when nil
---@return integer moved
---@return integer held back
local function transferUnits(fromTeamID, toTeamID, accept)
	local moved, held = 0, 0
	for _, unitID in ipairs(Spring.GetTeamUnits(fromTeamID) or {}) do
		local unitDefID = Spring.GetUnitDefID(unitID)
		if accept == nil or (unitDefID ~= nil and accept(unitDefID)) then
			if Spring.TransferUnit(unitID, toTeamID, true) then
				moved = moved + 1
			end
		else
			held = held + 1
		end
	end
	return moved, held
end

-- What a take moved is announced to the allies and the spectators (see the unsynced half); nothing moved, nothing said.
---@param playerID integer the taker
---@param teamID integer the team taken from
---@param units integer
---@param energy number
---@param metal number
local function announceTaken(playerID, teamID, units, energy, metal)
	if units > 0 or energy > 0 or metal > 0 then
		SendToUnsynced("TeamTaken", playerID, teamID, units, math.floor(energy), math.floor(metal))
	end
end

local function matchesCategory(unitDefID, category)
	if category == ConstructionEnums.UnitFilterCategory.All then
		return true
	end
	return Shared.IsShareableDef(unitDefID, category, UnitDefs)
end

local function stunUnit(unitID, seconds)
	local _, maxHealth = Spring.GetUnitHealth(unitID)
	if maxHealth and maxHealth > 0 then
		Spring.AddUnitDamage(unitID, maxHealth * 5, seconds * 30)
	end
end

local function getPlayerName(playerID)
	local name = Spring.GetPlayerInfo(playerID)
	return name or ("Player " .. playerID)
end

local function getTeamLeaderName(teamID)
	local _, leaderID = Spring.GetTeamInfo(teamID, false)
	if leaderID ~= nil and leaderID >= 0 then
		return getPlayerName(leaderID)
	end
	return "Team " .. teamID
end

local function notify(playerID, result)
	local msg = TakeComms.FormatMessage(result)
	if msg and msg ~= "" then
		Spring.SendMessageToPlayer(playerID, msg)
	end
end

---@param playerID integer
---@param targetTeamID integer|nil only this team, when the chat command names one
local function ExecuteTake(playerID, targetTeamID)
	local takerName, _, spec, teamID = Spring.GetPlayerInfo(playerID)
	if spec then
		return
	end

	if takeMode == TransferEnums.TakeMode.Disabled then
		notify(playerID, {
			mode = takeMode,
			takerName = takerName,
			sourceName = "",
			transferred = 0,
			stunned = 0,
			delayed = 0,
			total = 0,
			category = takeDelayCategory,
			delaySeconds = takeDelaySeconds,
		})
		return
	end

	Spring.SetGameRulesParam("isTakeInProgress", 1)

	local allyTeamID = Spring.GetTeamAllyTeamID(teamID)
	local teamList = Spring.GetTeamList(allyTeamID)
	if targetTeamID ~= nil then
		if Spring.GetTeamAllyTeamID(targetTeamID) ~= allyTeamID then
			Spring.SetGameRulesParam("isTakeInProgress", 0)
			Spring.SendMessageToPlayer(playerID, "Nothing to take: that team is not an ally")
			return
		end
		teamList = { targetTeamID }
	end
	local currentFrame = Spring.GetGameFrame()
	local numTargets = 0

	for _, otherTeamID in ipairs(teamList) do
		if otherTeamID ~= teamID and not hasActivePlayer(otherTeamID) then
			numTargets = numTargets + 1
			local sourceName = getTeamLeaderName(otherTeamID)

			if takeMode == TransferEnums.TakeMode.Enabled then
				local transferred = transferUnits(otherTeamID, teamID)
				local energy, metal = transferResources(otherTeamID, teamID)
				announceTaken(playerID, otherTeamID, transferred, energy, metal)
				notify(playerID, {
					mode = takeMode,
					takerName = takerName,
					sourceName = sourceName,
					transferred = transferred,
					stunned = 0,
					delayed = 0,
					total = transferred,
					category = takeDelayCategory,
					delaySeconds = 0,
				})
			elseif takeMode == TransferEnums.TakeMode.StunDelay then
				local transferred = transferUnits(otherTeamID, teamID)
				local stunned = 0
				if takeDelaySeconds > 0 then
					for _, unitID in ipairs(Spring.GetTeamUnits(teamID) or {}) do
						local unitDefID = Spring.GetUnitDefID(unitID)
						if unitDefID and matchesCategory(unitDefID, takeDelayCategory) then
							stunUnit(unitID, takeDelaySeconds)
							stunned = stunned + 1
						end
					end
				end
				local energy, metal = transferResources(otherTeamID, teamID)
				announceTaken(playerID, otherTeamID, transferred, energy, metal)
				notify(playerID, {
					mode = takeMode,
					takerName = takerName,
					sourceName = sourceName,
					transferred = transferred,
					stunned = stunned,
					delayed = 0,
					total = transferred,
					category = takeDelayCategory,
					delaySeconds = takeDelaySeconds,
				})
			elseif takeMode == TransferEnums.TakeMode.TakeDelay then
				local pending = pendingDelayedTakes[otherTeamID]
				local delayFrames = takeDelaySeconds * 30

				if pending and pending.takerTeamID == teamID then
					if currentFrame >= pending.expiryFrame then
						local transferred = transferUnits(otherTeamID, teamID)
						local energy, metal = transferResources(otherTeamID, teamID)
						announceTaken(playerID, otherTeamID, transferred, energy, metal)
						pendingDelayedTakes[otherTeamID] = nil
						notify(playerID, {
							mode = takeMode,
							takerName = takerName,
							sourceName = sourceName,
							transferred = transferred,
							stunned = 0,
							delayed = 0,
							total = transferred,
							category = takeDelayCategory,
							delaySeconds = takeDelaySeconds,
							isSecondPass = true,
						})
					else
						local remaining = math.ceil((pending.expiryFrame - currentFrame) / 30)
						notify(playerID, {
							mode = takeMode,
							takerName = takerName,
							sourceName = sourceName,
							transferred = 0,
							stunned = 0,
							delayed = 0,
							total = 0,
							category = takeDelayCategory,
							delaySeconds = takeDelaySeconds,
							remainingSeconds = remaining,
						})
					end
				else
					local total = #(Spring.GetTeamUnits(otherTeamID) or {})
					local transferred, delayed = transferUnits(otherTeamID, teamID, function(unitDefID)
						return not matchesCategory(unitDefID, takeDelayCategory)
					end)
					announceTaken(playerID, otherTeamID, transferred, 0, 0)
					pendingDelayedTakes[otherTeamID] = {
						takerTeamID = teamID,
						expiryFrame = currentFrame + delayFrames,
					}
					notify(playerID, {
						mode = takeMode,
						takerName = takerName,
						sourceName = sourceName,
						transferred = transferred,
						stunned = 0,
						delayed = delayed,
						total = total,
						category = takeDelayCategory,
						delaySeconds = takeDelaySeconds,
					})
				end
			end
		end
	end

	Spring.SetGameRulesParam("isTakeInProgress", 0)

	if numTargets == 0 then
		Spring.SendMessageToPlayer(playerID, "Nothing to take: no inactive allied teams")
	end
end

local function resolveExpiredTake(otherTeamID, pending)
	if hasActivePlayer(otherTeamID) then
		pendingDelayedTakes[otherTeamID] = nil
		return
	end
	if not hasActivePlayer(pending.takerTeamID) then
		pendingDelayedTakes[otherTeamID] = nil
		return
	end

	Spring.SetGameRulesParam("isTakeInProgress", 1)
	local transferred = transferUnits(otherTeamID, pending.takerTeamID)
	local energy, metal = transferResources(otherTeamID, pending.takerTeamID)
	Spring.SetGameRulesParam("isTakeInProgress", 0)

	pendingDelayedTakes[otherTeamID] = nil

	local _, leaderID = Spring.GetTeamInfo(pending.takerTeamID, false)
	if leaderID ~= nil and leaderID >= 0 then
		announceTaken(leaderID, otherTeamID, transferred, energy, metal)
		notify(leaderID, {
			mode = takeMode,
			takerName = getPlayerName(leaderID),
			sourceName = getTeamLeaderName(otherTeamID),
			transferred = transferred,
			stunned = 0,
			delayed = 0,
			total = transferred,
			category = takeDelayCategory,
			delaySeconds = takeDelaySeconds,
			isSecondPass = true,
		})
	end
end

function gadget:GameFrame(frame)
	for otherTeamID, pending in pairs(pendingDelayedTakes) do
		if frame >= pending.expiryFrame then
			resolveExpiredTake(otherTeamID, pending)
		end
	end
end

---@return boolean|nil handled
function gadget:RecvLuaMsg(msg, playerID)
	if msg == TAKE_MSG then
		ExecuteTake(playerID)
		return true
	end
end

-- `/luarules take2 [team]`: the player list and the take proxy widget still speak the old command.
local function takeChatAction(_cmd, _line, words, playerID)
	ExecuteTake(playerID, tonumber(words[1]) --[[@as integer|nil]])
end

function gadget:Initialize()
	gadgetHandler:AddChatAction("take2", takeChatAction, "Take control of units and resources from inactive players")
end

function gadget:Shutdown()
	gadgetHandler:RemoveChatAction("take2")
end
