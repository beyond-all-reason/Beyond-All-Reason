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

local spGetUnitCOBValue = Spring.GetUnitCOBValue
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitDefID = Spring.GetUnitDefID
local spAreTeamsAllied = Spring.AreTeamsAllied
local spGetTeamList = Spring.GetTeamList

local COB_ARMORED = COB.ARMORED
local armoredTurrets = {}
local discoveredUnits = {}

for unitDefID, unitDef in ipairs(UnitDefs) do
	if unitDef.customParams and unitDef.customParams.concealed_when_closed then
		armoredTurrets[unitDefID] = true
	end
end	

local function flagTeamAndAllies(unitID, teamID)
	discoveredUnits[unitID] = discoveredUnits[unitID] or {}

	if discoveredUnits[unitID][teamID] then
		return
	end

	local teamList = spGetTeamList()
	for i = 1, #teamList do
		local checkedTeamID = teamList[i]
		if spAreTeamsAllied(teamID, checkedTeamID) then
			discoveredUnits[unitID][checkedTeamID] = true
		end
	end
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

	local cobValue = spGetUnitCOBValue(targetID, COB_ARMORED)
	if cobValue and cobValue == 0 then
		flagTeamAndAllies(targetID, attackerTeamID)
		return true, priority
	end

	local hasDiscovery = discoveredUnits[targetID] and discoveredUnits[targetID][attackerTeamID] or false
	return hasDiscovery, priority
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	discoveredUnits[unitID] = nil
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if armoredTurrets[unitDefID] then
		discoveredUnits[unitID] = {}
	end
end