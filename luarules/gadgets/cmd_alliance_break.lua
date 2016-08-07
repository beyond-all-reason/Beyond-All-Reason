function gadget:GetInfo()
	return {
		name      = "Unally on demand",
		desc      = "Removes an alliance when a dynamic ally attemps to backstab",
		author    = "BD",
		date      = "-",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true  --  loaded by default?
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if (not gadgetHandler:IsSyncedCode()) then
  return
end

if Spring.GetModOptions() and tonumber(Spring.GetModOptions().fixedallies) and (tonumber(Spring.GetModOptions().fixedallies) ~= 0) then
	return --no use if alliances are disabled
end

local GetUnitDefID = Spring.GetUnitDefID
local AreTeamsAllied = Spring.AreTeamsAllied
local GetUnitsInSphere = Spring.GetUnitsInSphere
local GetUnitTeam = Spring.GetUnitTeam
local GetUnitAllyTeam = Spring.GetUnitAllyTeam
local GetTeamList = Spring.GetTeamList
local GetAllyTeamList = Spring.GetAllyTeamList
local GetUnitHealth = Spring.GetUnitHealth
local GetUnitsInCylinder = Spring.GetUnitsInCylinder
local SendMessageToTeam = Spring.SendMessageToTeam
local GetTeamInfo = Spring.GetTeamInfo
local GetPlayerInfo = Spring.GetPlayerInfo
local SetAlly = Spring.SetAlly
local ValidUnitID = Spring.ValidUnitID
local min = math.min

local CMD_UNIT_SET_TARGET = 34923
local CMD_UNIT_SET_TARGET_RECTANGLE = 34925
local CMD_ATTACK = CMD.ATTACK
local CMD_LOOPBACKATTACK = CMD.LOOPBACKATTACK
local CMD_MANUALFIRE = CMD.MANUALFIRE

local UPDATE_RATE = 3 --in times per second ( max one time per sim frame )
local UPDATE_FRAMES = math.floor(Game.gameSpeed/UPDATE_RATE)

local attackAOEs = {}
local attackDamages = {}
local allianceStatus = {}


for unitDefID, unitDef in pairs(UnitDefs) do
	for weaponIndex, weaponProperties in pairs(unitDef.weapons) do
		local weaponDef = WeaponDefs[weaponProperties.weaponDef]
		if weaponDef.damageAreaOfEffect > (attackAOEs[unitDefID] or 0) then
			attackAOEs[unitDefID] = weaponDef.damageAreaOfEffect
			attackDamages[unitDefID] = weaponDef.damages
		end
	end
end

function getTeamLeaderName(teamID)
	return GetPlayerInfo(select(2,GetTeamInfo(teamID)))
end

function gadget:GameFrame(n)
	if n%UPDATE_FRAMES ~= 0 then
		return
	end
	for _,allyTeamAID in pairs(GetAllyTeamList()) do
		for _,allyTeamBID in pairs(GetAllyTeamList()) do
			if allyTeamAID ~= allyTeamBID then
				for _,teamAID in pairs(GetTeamList(allyTeamAID)) do
					for _,teamBID in pairs(GetTeamList(allyTeamBID)) do
						allianceStatus[teamAID] = allianceStatus[teamAID] or {}
						allianceStatus[teamBID] = allianceStatus[teamBID] or {}
						local AalliedToB = AreTeamsAllied(teamBID,teamAID)
						local BalliedToA = AreTeamsAllied(teamAID,teamBID)
						--if teamB's cached value is allied back with A, and new teamB's allied status is not allied, means the enemy broke alliance with us
						if allianceStatus[teamBID][teamAID] and not BalliedToA then
							if AalliedToB then
								--if we're allied, break our alliance back
								SetAlly(teamBID,teamAID,false)
								SendMessageToTeam(teamAID,"Team " .. teamBID .. " (" .. getTeamLeaderName(teamBID) ..  ") has unallied with you, breaking dynamic alliance.")
							else
								SendMessageToTeam(teamAID,"Team " .. teamBID .. " (" .. getTeamLeaderName(teamBID) ..  ") broke his alliance with you.")
							end
						end
						--if teamB wasn't allied with teamA, and now it is, inform teamA about the change
						if  not allianceStatus[teamBID][teamAID] and BalliedToA then
							SendMessageToTeam(teamAID,"Team " .. teamBID .. " (" .. getTeamLeaderName(teamBID) ..  ") has allied with you.")
						end
						allianceStatus[teamAID][teamBID] = AalliedToB
					end
				end
			end
		end
	end
end

function checkAndBreakAlliance(attackerTeam,targetTeam,attackerAllyTeam,targetAllyTeam)
	if AreTeamsAllied(attackerTeam,targetTeam) and targetAllyTeam ~= attackerAllyTeam then
		SetAlly(attackerTeam,targetTeam,false)
		SendMessageToTeam(targetTeam,"Team " .. attackerTeam .. " (" .. getTeamLeaderName(attackerTeam) ..  ") attempted to attack you, breaking dynamic alliance.")
		return true
	end
end


function gadget:UnitCommand(unitID, unitDefID, attackerTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	if #cmdParams == 1 and (cmdID == CMD_ATTACK or cmdID == CMD_LOOPBACKATTACK or cmdID == CMD_MANUALFIRE) then
		local targetID = cmdParams[1]
		if ValidUnitID(targetID) then
			checkAndBreakAlliance(attackerTeam,GetUnitTeam(targetID),GetUnitAllyTeam(unitID),GetUnitAllyTeam(targetID))
		end
	elseif #cmdParams >= 3 and (cmdID == CMD_ATTACK or cmdID == CMD_LOOPBACKATTACK or cmdID == CMD_SET_TARGET or cmdID == CMD_UNIT_SET_TARGET_RECTANGLE or cmdID == CMD_MANUALFIRE ) then
		local attackAOE = attackAOEs[unitDefID]
		if not attackAOE then
			return
		end
		local targetAllyTeamIDs = {}
		local attackerAllyTeam = GetUnitAllyTeam(unitID)
		local totalDamageSum = 0
		local targetAllyTeamToTeam = {}
		for _,targetID in pairs(GetUnitsInSphere(cmdParams[1],cmdParams[2],cmdParams[3],attackAOE)) do
			local targetAllyTeam = GetUnitAllyTeam(targetID)
			local targetDefID = GetUnitDefID(targetID)
			local targetDef = UnitDefs[targetDefID]
			local targetHp = GetUnitHealth(targetID)
			local targetDamage = min(targetHp,attackDamages[unitDefID][targetDef.armorType])
			totalDamageSum = totalDamageSum + targetDamage
			targetAllyTeamIDs[targetAllyTeam] = (targetAllyTeamIDs[targetAllyTeam] or 0) + targetDamage
		end
		--if an allyteam receives more damage than the others, and it's allied to the attacker, de-ally
		for targetAllyTeam,damage in pairs(targetAllyTeamIDs) do
			damage = damage / totalDamageSum
			if damage > 0.5 then
				for _,targetTeam in pairs(GetTeamList(targetAllyTeam)) do
					checkAndBreakAlliance(attackerTeam,targetTeam,attackerAllyTeam,targetAllyTeam)
				end
				break
			end
		end
	elseif #cmdParams == 4 and (cmdID == CMD_ATTACK or cmdID == CMD_LOOPBACKATTACK) then
		local attackerAllyTeam = GetUnitAllyTeam(unitID)
		for _,targetID in pairs(GetUnitsInCylinder(cmdParams[1],cmdParams[3],cmdParams[4])) do
			checkAndBreakAlliance(attackerTeam,GetUnitTeam(targetID),attackerAllyTeam,GetUnitAllyTeam(targetID))
		end
	end
end



--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
