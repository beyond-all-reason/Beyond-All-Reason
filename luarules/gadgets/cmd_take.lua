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
	return
end

local ModeEnums = VFS.Include("modes/sharing_mode_enums.lua")
local Shared = VFS.Include("common/luaUtilities/sharing/unit_transfer_shared.lua")
local TakeComms = VFS.Include("common/luaUtilities/sharing/take_comms.lua")

local TAKE_MSG = "take_cmd"

local takePolicy = TakeComms.GetPolicy(Spring.GetModOptions())
local takeMode = takePolicy.mode
local takeDelaySeconds = takePolicy.delaySeconds
local takeDelayCategory = takePolicy.delayCategory

local pendingDelayedTakes = {}

local function hasActivePlayer(otherTeamID)
	for _, pID in ipairs(Spring.GetPlayerList()) do
		local _, active, spectator, pTeamID = Spring.GetPlayerInfo(pID)
		if active and not spectator and pTeamID == otherTeamID then
			return true
		end
	end
	return false
end

local function transferResources(fromTeamID, toTeamID)
	local metal = GG.GetTeamResources and GG.GetTeamResources(fromTeamID, "metal")
	local energy = GG.GetTeamResources and GG.GetTeamResources(fromTeamID, "energy")
	if metal and metal > 0 and GG.ShareTeamResource then
		GG.ShareTeamResource(fromTeamID, toTeamID, "metal", metal)
	end
	if energy and energy > 0 and GG.ShareTeamResource then
		GG.ShareTeamResource(fromTeamID, toTeamID, "energy", energy)
	end
end

local function matchesCategory(unitDefID, category)
	if category == ModeEnums.UnitFilterCategory.All then
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
	if leaderID then
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

local function ExecuteTake(playerID)
	local takerName, _, spec, teamID = Spring.GetPlayerInfo(playerID)
	if spec then
		return
	end

	if takeMode == ModeEnums.TakeMode.Disabled then
		notify(playerID, { mode = takeMode, takerName = takerName, sourceName = "", transferred = 0, stunned = 0, delayed = 0, total = 0, category = takeDelayCategory, delaySeconds = takeDelaySeconds })
		return
	end

	Spring.SetGameRulesParam("isTakeInProgress", 1)

	local allyTeamID = Spring.GetTeamAllyTeamID(teamID)
	local teamList = Spring.GetTeamList(allyTeamID)
	local currentFrame = Spring.GetGameFrame()
	local numTargets = 0

	for _, otherTeamID in ipairs(teamList) do
		-- Take any allied team with no active human player, including AI allies.
		if otherTeamID ~= teamID and not hasActivePlayer(otherTeamID) then
			numTargets = numTargets + 1
			local sourceName = getTeamLeaderName(otherTeamID)

			if takeMode == ModeEnums.TakeMode.Enabled then
				local units = Spring.GetTeamUnits(otherTeamID)
				local transferred = #units
				for _, unitID in ipairs(units) do
					Spring.TransferUnit(unitID, teamID, true)
				end
				transferResources(otherTeamID, teamID)
				notify(playerID, { mode = takeMode, takerName = takerName, sourceName = sourceName, transferred = transferred, stunned = 0, delayed = 0, total = transferred, category = takeDelayCategory, delaySeconds = 0 })
			elseif takeMode == ModeEnums.TakeMode.StunDelay then
				local units = Spring.GetTeamUnits(otherTeamID)
				local transferred = #units
				for _, unitID in ipairs(units) do
					Spring.TransferUnit(unitID, teamID, true)
				end
				local stunned = 0
				if takeDelaySeconds > 0 then
					for _, unitID in ipairs(Spring.GetTeamUnits(teamID)) do
						local unitDefID = Spring.GetUnitDefID(unitID)
						if unitDefID and matchesCategory(unitDefID, takeDelayCategory) then
							stunUnit(unitID, takeDelaySeconds)
							stunned = stunned + 1
						end
					end
				end
				transferResources(otherTeamID, teamID)
				notify(playerID, { mode = takeMode, takerName = takerName, sourceName = sourceName, transferred = transferred, stunned = stunned, delayed = 0, total = transferred, category = takeDelayCategory, delaySeconds = takeDelaySeconds })
			elseif takeMode == ModeEnums.TakeMode.TakeDelay then
				local pending = pendingDelayedTakes[otherTeamID]
				local delayFrames = takeDelaySeconds * 30

				if pending and pending.takerTeamID == teamID then
					if currentFrame >= pending.expiryFrame then
						local units = Spring.GetTeamUnits(otherTeamID)
						local transferred = #units
						for _, unitID in ipairs(units) do
							Spring.TransferUnit(unitID, teamID, true)
						end
						transferResources(otherTeamID, teamID)
						pendingDelayedTakes[otherTeamID] = nil
						notify(playerID, { mode = takeMode, takerName = takerName, sourceName = sourceName, transferred = transferred, stunned = 0, delayed = 0, total = transferred, category = takeDelayCategory, delaySeconds = takeDelaySeconds, isSecondPass = true })
					else
						local remaining = math.ceil((pending.expiryFrame - currentFrame) / 30)
						notify(playerID, { mode = takeMode, takerName = takerName, sourceName = sourceName, transferred = 0, stunned = 0, delayed = 0, total = 0, category = takeDelayCategory, delaySeconds = takeDelaySeconds, remainingSeconds = remaining })
					end
				else
					local units = Spring.GetTeamUnits(otherTeamID)
					local total = #units
					local transferred = 0
					local delayed = 0
					for _, unitID in ipairs(units) do
						local unitDefID = Spring.GetUnitDefID(unitID)
						if unitDefID and not matchesCategory(unitDefID, takeDelayCategory) then
							Spring.TransferUnit(unitID, teamID, true)
							transferred = transferred + 1
						else
							delayed = delayed + 1
						end
					end
					pendingDelayedTakes[otherTeamID] = {
						takerTeamID = teamID,
						expiryFrame = currentFrame + delayFrames,
					}
					notify(playerID, { mode = takeMode, takerName = takerName, sourceName = sourceName, transferred = transferred, stunned = 0, delayed = delayed, total = total, category = takeDelayCategory, delaySeconds = takeDelaySeconds })
				end
			end
		end
	end

	Spring.SetGameRulesParam("isTakeInProgress", 0)

	if numTargets == 0 then
		Spring.SendMessageToPlayer(playerID, "Nothing to take: no inactive allied teams")
	end
end

-- auto-grant held-back units when the delay timer expires; cancel if source regained a player or the taker left
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
	local units = Spring.GetTeamUnits(otherTeamID)
	local transferred = #units
	for _, unitID in ipairs(units) do
		Spring.TransferUnit(unitID, pending.takerTeamID, true)
	end
	transferResources(otherTeamID, pending.takerTeamID)
	Spring.SetGameRulesParam("isTakeInProgress", 0)

	pendingDelayedTakes[otherTeamID] = nil

	local _, leaderID = Spring.GetTeamInfo(pending.takerTeamID, false)
	if leaderID then
		notify(leaderID, { mode = takeMode, takerName = getPlayerName(leaderID), sourceName = getTeamLeaderName(otherTeamID), transferred = transferred, stunned = 0, delayed = 0, total = transferred, category = takeDelayCategory, delaySeconds = takeDelaySeconds, isSecondPass = true })
	end
end

function gadget:GameFrame(frame)
	for otherTeamID, pending in pairs(pendingDelayedTakes) do
		if frame >= pending.expiryFrame then
			resolveExpiredTake(otherTeamID, pending)
		end
	end
end

function gadget:RecvLuaMsg(msg, playerID)
	if msg == TAKE_MSG then
		ExecuteTake(playerID)
		return true
	end
end
