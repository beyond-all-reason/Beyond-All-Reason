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
local GetUnitHealth = Spring.GetUnitHealth
local GetUnitsInCylinder = Spring.GetUnitsInCylinder
local SendMessageToTeam = Spring.SendMessageToTeam
local SetAlly = Spring.SetAlly
local min = math.min

local CMD_UNIT_SET_TARGET = 34923
local CMD_UNIT_SET_TARGET_RECTANGLE = 34925
local CMD_ATTACK = CMD.ATTACK
local CMD_LOOPBACKATTACK = CMD.LOOPBACKATTACK

local attackAOEs = {}
local attackDamages = {}

for unitDefID, unitDef in pairs(UnitDefs) do
	for weaponIndex, weaponProperties in pairs(unitDef.weapons) do
		local weaponDef = WeaponDefs[weaponProperties.weaponDef]
		if weaponDef.damageAreaOfEffect > (attackAOEs[unitDefID] or 0) then
			attackAOEs[unitDefID] = weaponDef.damageAreaOfEffect
			attackDamages[unitDefID] = weaponDef.damages
		end
	end
end


function gadget:UnitCommand(unitID, unitDefID, teamID, cmdID, cmdOpts, cmdParams,cmdTag)
	if #cmdParams == 1 and (cmdID == CMD_ATTACK or cmdID == CMD_LOOPBACKATTACK) then
		local targetID = cmdParams[1]
		local attackerAllyTeam = GetUnitAllyTeam(unitID)
		local targetTeam = GetUnitTeam(targetID)
		local targetAllyTeam = GetUnitAllyTeam(targetID)
		if AreTeamsAllied(teamID,targetTeam) and targetAllyTeam ~= attackerAllyTeam then
			SetAlly(teamID,targetTeam,false)
			SendMessageToTeam(targetTeam,"Team " .. teamID .. " attempted to attack you, breaking dynamic alliance")
		end
	elseif #cmdParams >= 3 and (cmdID == CMD_ATTACK or cmdID == CMD_LOOPBACKATTACK or cmdID == CMD_SET_TARGET or cmdID == CMD_UNIT_SET_TARGET_RECTANGLE ) then
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
					if AreTeamsAllied(teamID,targetTeam) and targetAllyTeam ~= attackerAllyTeam then
						SendMessageToTeam(targetTeam,"Team " .. teamID .. " attempted to attack you, breaking dynamic alliance")
						SetAlly(teamID,targetTeam,false)
					end 
				end
				break
			end
		end
	elseif #cmdParams == 4 and (cmdID == CMD_ATTACK or cmdID == CMD_LOOPBACKATTACK) then
		local attackerAllyTeam = GetUnitAllyTeam(unitID)
		for _,targetID in pairs(GetUnitsInCylinder(cmdParams[1],cmdParams[3],cmdParams[4])) do
			local targetTeam = GetUnitTeam(targetID)
			local targetAllyTeam = GetUnitAllyTeam(targetID)
			if AreTeamsAllied(teamID,targetTeam) and targetAllyTeam ~= attackerAllyTeam then
				SendMessageToTeam(targetTeam,"Team " .. teamID .. " attempted to attack you, breaking dynamic alliance")
				SetAlly(teamID,targetTeam,false)
			end
		end
	end
end



--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
