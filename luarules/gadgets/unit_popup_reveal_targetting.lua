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
local spSetUnitRulesParam = Spring.SetUnitRulesParam
local spGetTeamList = Spring.GetTeamList
local armoredTurrets = {}
local discoveredUnits = {}
local watchList = {}
local CHECK_INTERVAL = math.floor(Game.gameSpeed * 0.5)
local allyTeamRepresentative = {}

for _, allyTeamID in ipairs(Spring.GetAllyTeamList()) do
	local teamIDs = Spring.GetTeamList(allyTeamID)
	if teamIDs and #teamIDs > 0 then
		local representativeTeam = teamIDs[1]
		allyTeamRepresentative[allyTeamID] = representativeTeam
	end
end

for unitDefID, unitDef in ipairs(UnitDefs) do
	if unitDef.customParams and unitDef.customParams.decoy_when_closed and unitDef.customParams.decoyfor then
		armoredTurrets[unitDefID] = true
	end
end	

local function flagAllyTeam(unitID, allyTeamID)
	if not discoveredUnits[unitID] then
		discoveredUnits[unitID] = {}
	end

	local teamIDs = spGetTeamList(allyTeamID)
	if not teamIDs then
		return
	end

	local unitDefID = spGetUnitDefID(unitID)
	for _, teamID in ipairs(teamIDs) do
		discoveredUnits[unitID][teamID] = true
		local paramKey = "decoyRevealed_team" .. teamID
		spSetUnitRulesParam(unitID, paramKey, unitDefID, { public = true })
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
				for _, teamID in ipairs(Spring.GetTeamList()) do
					local paramKey = "decoyRevealed_team" .. teamID
					spSetUnitRulesParam(unitID, paramKey, nil)
				end
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
	local canTarget = (discoveredUnits[targetID] and discoveredUnits[targetID][attackerTeamID]) or false
	return canTarget, priority
end

function gadget:GameFrame(frame)
	if frame % CHECK_INTERVAL == 0 then
		for unitID, allyTeams in pairs(watchList) do
			if not spGetUnitArmored(unitID) then
				for allyTeam in pairs(allyTeams) do
					flagAllyTeam(unitID, allyTeam)
				end
				watchList[unitID] = nil
			end
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	discoveredUnits[unitID] = nil
	watchList[unitID] = nil
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if armoredTurrets[unitDefID] then
		discoveredUnits[unitID] = {}
	end
end

function gadget:UnitEnteredLos(unitID, unitTeam, allyTeam, unitDefID)
	if not armoredTurrets[unitDefID] then
		return
	end

	local representativeTeam = allyTeamRepresentative[allyTeam]
	if not representativeTeam or discoveredUnits[unitID] and representativeTeam and discoveredUnits[unitID][representativeTeam] then
		return
	end

	if not spGetUnitArmored(unitID) then
		flagAllyTeam(unitID, allyTeam)
	else
		watchList[unitID] = watchList[unitID] or {}
		watchList[unitID][allyTeam] = true
	end
end

function gadget:UnitLeftLos(unitID, unitTeam, allyTeam, unitDefID)
	if not armoredTurrets[unitDefID] then
		return
	end

	if watchList[unitID] then
		watchList[unitID][allyTeam] = nil
	end
end