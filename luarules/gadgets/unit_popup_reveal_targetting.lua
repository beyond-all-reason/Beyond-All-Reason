local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name      = "Popup Reveal Targetting",
		desc      = "Blocks targeting of concealed turrets when closed",
		author    = "SethDGamre",
		date      = "11 09 2025",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local spGetUnitArmored = Spring.GetUnitArmored
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitDefID = Spring.GetUnitDefID
local spAreTeamsAllied = Spring.AreTeamsAllied
local armoredTurrets = {}
local discoveredUnits = {}
local armoredStates = {}

local UNKNOWN = -1
local UNARMORED = 0
local ARMORED = 1
local CHECK_INTERVAL = math.floor(Game.gameSpeed * 0.5)

for unitDefID, unitDef in ipairs(UnitDefs) do
	if unitDef.customParams and unitDef.customParams.decoy_when_closed then
		armoredTurrets[unitDefID] = true
	end
end	

local function flagTeamAndAllies(unitID, teamID)
	if not discoveredUnits[unitID] then
		discoveredUnits[unitID] = {}
	end
	if discoveredUnits[unitID][teamID] then
		return
	end
	for _, checkedTeamID in ipairs(Spring.GetTeamList()) do
		if spAreTeamsAllied(teamID, checkedTeamID) then
			discoveredUnits[unitID][checkedTeamID] = true
		end
	end
	armoredStates[unitID] = UNKNOWN
end

function gadget:Initialize()
	for weaponDefID, weaponDef in pairs(WeaponDefs) do
		if weaponDef.range > 0 and not weaponDef.name:find("fake") then
			Script.SetWatchAllowTarget(weaponDefID, true)
		end
	end
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		if not Spring.GetUnitIsBeingBuilt(unitID) then
			local unitDefID = spGetUnitDefID(unitID)
			if armoredTurrets[unitDefID] then
				discoveredUnits[unitID] = {}
			end
		end
	end
end

function gadget:AllowWeaponTarget(attackerID, targetID, attackerWeaponNum, attackerWeaponDefID, defPriority)
	local priority = defPriority or 1.0
	local targetDefID = spGetUnitDefID(targetID)
	if not targetDefID or not armoredTurrets[targetDefID] then
		return true, priority
	end

	local attackerTeamID = spGetUnitTeam(attackerID)
	local state = armoredStates[targetID]

	if not state or state == UNKNOWN then
		local isArmored = spGetUnitArmored(targetID)
		state = isArmored and ARMORED or UNARMORED
		armoredStates[targetID] = state
	end

	if state == UNARMORED then
		flagTeamAndAllies(targetID, attackerTeamID)
		return true, priority
	end

	return (discoveredUnits[targetID] and discoveredUnits[targetID][attackerTeamID]) or false, priority
end

function gadget:GameFrame(frame)
	if frame % CHECK_INTERVAL == 0 then
		for unitID, state in pairs(armoredStates) do
			if state ~= UNARMORED then
				local isArmored = spGetUnitArmored(unitID)
				armoredStates[unitID] = isArmored and ARMORED or UNARMORED
			end
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	discoveredUnits[unitID] = nil
	armoredStates[unitID] = nil
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if armoredTurrets[unitDefID] then
		discoveredUnits[unitID] = {}
	end
end