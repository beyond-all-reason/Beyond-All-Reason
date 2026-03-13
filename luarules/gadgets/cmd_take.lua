function gadget:GetInfo()
	return {
		name      = "Take Command",
		desc      = "Implements /take command to transfer units/resources from empty allied teams",
		author    = "Antigravity",
		date      = "2024",
		license   = "GPL-v2",
		layer     = 0,
		enabled   = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local ModeEnums = VFS.Include("modes/sharing_mode_enums.lua")
local Shared = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_shared.lua")
local TakeComms = VFS.Include("common/luaUtilities/team_transfer/take_comms.lua")

local TAKE_MSG = "take_cmd"

local modOptions = Spring.GetModOptions()
local takeMode = modOptions[ModeEnums.ModOptions.TakeMode] or ModeEnums.TakeMode.Enabled
local takeDelaySeconds = tonumber(modOptions[ModeEnums.ModOptions.TakeDelaySeconds]) or 30
local takeDelayCategory = modOptions[ModeEnums.ModOptions.TakeDelayCategory] or ModeEnums.UnitCategory.Resource

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
	if spec then return end

	if takeMode == ModeEnums.TakeMode.Disabled then
		notify(playerID, { mode = takeMode, takerName = takerName, sourceName = "", transferred = 0, stunned = 0, delayed = 0, total = 0, category = takeDelayCategory, delaySeconds = takeDelaySeconds })
		return
	end

	Spring.SetGameRulesParam("isTakeInProgress", 1)

	local allyTeamID = Spring.GetTeamAllyTeamID(teamID)
	local teamList = Spring.GetTeamList(allyTeamID)
	local currentFrame = Spring.GetGameFrame()

	for _, otherTeamID in ipairs(teamList) do
		if otherTeamID ~= teamID and not hasActivePlayer(otherTeamID) then
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
end

function gadget:RecvLuaMsg(msg, playerID)
	if msg == TAKE_MSG then
		ExecuteTake(playerID)
		return true
	end
end
