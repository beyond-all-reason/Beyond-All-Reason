local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Unally on demand",
		desc = "Removes an alliance when a dynamic ally attemps to backstab",
		author = "BrainDamage",
		date = "-",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

if Spring.GetModOptions().fixedallies then
	return -- no use if alliances are disabled
end

if gadgetHandler:IsSyncedCode() then

	local GetUnitDefID = Spring.GetUnitDefID
	local AreTeamsAllied = Spring.AreTeamsAllied
	local GetUnitsInSphere = Spring.GetUnitsInSphere
	local GetUnitTeam = Spring.GetUnitTeam
	local GetUnitAllyTeam = Spring.GetUnitAllyTeam
	local GetTeamList = Spring.GetTeamList
	local GetUnitHealth = Spring.GetUnitHealth
	local GetUnitsInCylinder = Spring.GetUnitsInCylinder
	local SetAlly = Spring.SetAlly
	local ValidUnitID = Spring.ValidUnitID
	local min = math.min

	local CMD_UNIT_SET_TARGET = GameCMD.UNIT_SET_TARGET
	local CMD_UNIT_SET_TARGET_RECTANGLE = GameCMD.UNIT_SET_TARGET_RECTANGLE
	local CMD_ATTACK = CMD.ATTACK
	local CMD_LOOPBACKATTACK = CMD.LOOPBACKATTACK
	local CMD_MANUALFIRE = CMD.MANUALFIRE

	local UPDATE_RATE = 3 --in times per second ( max one time per sim frame )
	local UPDATE_FRAMES = math.floor(Game.gameSpeed / UPDATE_RATE)

	local allyTeamList = Spring.GetAllyTeamList()

	local attackAOEs = {}
	local attackDamages = {}
	local allianceStatus = {}
	local unitArmorType = {}
	for unitDefID, unitDef in pairs(UnitDefs) do
		local weapons = unitDef.weapons
		if #weapons > 0 then
			for i = 1, #weapons do
				local weaponDef = WeaponDefs[weapons[i].weaponDef]
				if weaponDef.damageAreaOfEffect > (attackAOEs[unitDefID] or 0) then
					attackAOEs[unitDefID] = weaponDef.damageAreaOfEffect
					attackDamages[unitDefID] = weaponDef.damages
				end
			end
		end
		unitArmorType[unitDefID] = unitDef.armorType
	end

	function gadget:GameFrame(n)
		if n % UPDATE_FRAMES ~= 0 then
			return
		end
		for _, allyTeamAID in pairs(allyTeamList) do
			for _, allyTeamBID in pairs(allyTeamList) do
				if allyTeamAID ~= allyTeamBID then
					for _, teamAID in pairs(GetTeamList(allyTeamAID)) do
						allianceStatus[teamAID] = allianceStatus[teamAID] or {}
						for _, teamBID in pairs(GetTeamList(allyTeamBID)) do
							allianceStatus[teamBID] = allianceStatus[teamBID] or {}
							local AalliedToB = AreTeamsAllied(teamBID, teamAID)
							local BalliedToA = AreTeamsAllied(teamAID, teamBID)
							-- if teamB's cached value is allied back with A, and new teamB's allied status is not allied, means the enemy broke alliance with us
							if allianceStatus[teamBID][teamAID] and not BalliedToA then
								if AalliedToB then
									-- if we're allied, break our alliance back
									SetAlly(teamBID, teamAID, false)
								end
								SendToUnsynced("AllianceBroken", teamAID, teamBID)
							end
							-- if teamB wasn't allied with teamA, and now it is, inform teamA about the change
							if not allianceStatus[teamBID][teamAID] and BalliedToA then
								SendToUnsynced("AllianceMade", teamAID, teamBID)
							end
							allianceStatus[teamAID][teamBID] = AalliedToB
						end
					end
				end
			end
		end
	end

	local function checkAndBreakAlliance(attackerTeam, targetTeam, attackerAllyTeam, targetAllyTeam)
		if AreTeamsAllied(attackerTeam, targetTeam) and targetAllyTeam ~= attackerAllyTeam then
			SetAlly(attackerTeam, targetTeam, false)
			SendToUnsynced("Backstab", targetTeam, attackerTeam)
			return true
		end
	end

	function gadget:UnitCommand(unitID, unitDefID, attackerTeam, cmdID, cmdParams, cmdOpts, cmdTag, playerID, fromSynced, fromLua)
		if #cmdParams == 1 and (cmdID == CMD_ATTACK or cmdID == CMD_LOOPBACKATTACK or cmdID == CMD_MANUALFIRE) then
			local targetID = cmdParams[1]
			if ValidUnitID(targetID) then
				checkAndBreakAlliance(attackerTeam, GetUnitTeam(targetID), GetUnitAllyTeam(unitID), GetUnitAllyTeam(targetID))
			end
		elseif #cmdParams >= 3 and (cmdID == CMD_ATTACK or cmdID == CMD_LOOPBACKATTACK or cmdID == CMD_UNIT_SET_TARGET or cmdID == CMD_UNIT_SET_TARGET_RECTANGLE or cmdID == CMD_MANUALFIRE) then
			local attackAOE = attackAOEs[unitDefID]
			if not attackAOE then
				return
			end
			local targetAllyTeamIDs = {}
			local attackerAllyTeam = GetUnitAllyTeam(unitID)
			local totalDamageSum = 0
			local units = GetUnitsInSphere(cmdParams[1], cmdParams[2], cmdParams[3], attackAOE)
			for i = 1, #units do
				local targetID = units[i]
				local targetAllyTeam = GetUnitAllyTeam(targetID)
				local targetDamage = min(GetUnitHealth(targetID), attackDamages[unitDefID][unitArmorType[GetUnitDefID(targetID)]])
				totalDamageSum = totalDamageSum + targetDamage
				targetAllyTeamIDs[targetAllyTeam] = (targetAllyTeamIDs[targetAllyTeam] or 0) + targetDamage
			end
			--if an allyteam receives more damage than the others, and it's allied to the attacker, de-ally
			for targetAllyTeam, damage in pairs(targetAllyTeamIDs) do
				damage = damage / totalDamageSum
				if damage > 0.5 then
					for _, targetTeam in pairs(GetTeamList(targetAllyTeam)) do
						checkAndBreakAlliance(attackerTeam, targetTeam, attackerAllyTeam, targetAllyTeam)
					end
					break
				end
			end
		elseif #cmdParams == 4 and (cmdID == CMD_ATTACK or cmdID == CMD_LOOPBACKATTACK) then
			local attackerAllyTeam = GetUnitAllyTeam(unitID)
			local units = GetUnitsInCylinder(cmdParams[1], cmdParams[3], cmdParams[4])
			for i = 1, #units do
				local targetID = units[i]
				checkAndBreakAlliance(attackerTeam, GetUnitTeam(targetID), attackerAllyTeam, GetUnitAllyTeam(targetID))
			end
		end
	end

else
	----------------------------------------------------------------
	-- Unsynced
	----------------------------------------------------------------

	local SendMessageToTeam = Spring.SendMessageToTeam
	local GetTeamInfo = Spring.GetTeamInfo
	local GetPlayerInfo = Spring.GetPlayerInfo

	-- Dynamic alliances are not supported for AI teams
	local function getTeamLeaderName(teamID)
		return GetPlayerInfo(select(2, GetTeamInfo(teamID, false)), false)
	end

	local function allianceMade(_, teamA, teamB)
		if Script.LuaUI('GadgetMessageProxy') then
			local message = Script.LuaUI.GadgetMessageProxy('ui.dynamicAlly.create', { player = getTeamLeaderName(teamB) })
			SendMessageToTeam(teamA, message)
		end
	end

	local function allianceBroken(_, teamA, teamB)
		if Script.LuaUI('GadgetMessageProxy') then
			local message = Script.LuaUI.GadgetMessageProxy('ui.dynamicAlly.destroy', { player = getTeamLeaderName(teamB) })
			SendMessageToTeam(teamA, message)
		end
	end

	local function backstab(_, victimTeam, traitorTeam)
		if Script.LuaUI('GadgetMessageProxy') then
			local message = Script.LuaUI.GadgetMessageProxy('ui.dynamicAlly.backstab', { player = getTeamLeaderName(traitorTeam) })
			SendMessageToTeam(victimTeam, message)
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("AllianceMade", allianceMade)
		gadgetHandler:AddSyncAction("AllianceBroken", allianceBroken)
		gadgetHandler:AddSyncAction("Backstab", backstab)
	end

end
