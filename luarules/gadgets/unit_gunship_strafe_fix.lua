local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Gunship Strafe Fix",
		desc = "When gunships stop attacking their target unit with no followup command, forces them to stop strafing and enter idle behavior",
		author = "JRTaylord: https://github.com/JRTaylord",
		date = "May 7, 2025",
		license = "GNU GPL, v2 or later",
		layer = 0, -- Todo: ask which layer should this be on
		enabled = true,
	}
end

local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetUnitWeaponTarget = Spring.GetUnitWeaponTarget
local spGetUnitCommands = Spring.GetUnitCommands
local spGetAllUnits = Spring.GetAllUnits
local spGetUnitDefID = Spring.GetUnitDefID
local spEcho = Spring.Echo

-- Constants
-- Todo figure out options to make the command silent
local CMD_OPTIONS = CMD.OPT_INTERNAL

-- Gadget variables
local gunshipDefs = {}
local gunshipsToTrack = {}

-- Only run in synced code
if not gadgetHandler:IsSyncedCode() then
	return false
end

-- Helper functions
local function isTargettingUnit(unitID, unitDefID)
	local weaponCount = gunshipDefs[unitDefID].weaponCount
	for weaponNum = 1, weaponCount do
		local targetType, _, targetID = spGetUnitWeaponTarget(unitID, weaponNum)
		if targetType == 1 and targetID then
			return true
		end
	end
	return false
end

local function stopGunshipIfNoCmdAndTarget(unitId, unitDefID)
	local numCommands = #spGetUnitCommands(unitID, 1)
	local hasTarget = isTargettingUnit(unitID, unitDefID)
	if numCommands == 0 and not hasTarget then
		spGiveOrderToUnit(unitID, CMD.STOP, {}, CMD_OPTIONS)
	end
end

function gadget:Initialize()
	-- Find all gunship units
	for defID, unitDef in pairs(UnitDefs) do
		if
			(unitDef.canFly or unitDef.isAirUnit)
			and (unitDef.gunship or unitDef.isHoveringAirUnit or unitDef.hoverattack)
			and #unitDef.weapons > 0
		then
			gunshipDefs[defID] = {
				name = unitDef.name,
				weaponCount = #unitDef.weapons,
			}
		end
	end

	-- Register any existing gunships and stops them if already idle to ensure this fix works when loading scenarios or saved games
	local allUnits = spGetAllUnits()
	for i = 1, #allUnits do
		local unitID = allUnits[i]
		local unitDefID = spGetUnitDefID(unitID)
		if gunshipDefs[unitDefID] then
			stopGunshipIfNoCmdAndTarget(unitID, unitDefID)
			gunshipsToTrack[unitID] = true
		end
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	-- Called when a unit is created
	local unitDefID = spGetUnitDefID(unitID)
	if gunshipDefs[unitDefID] then
		-- Initialize previous command for new gunship unit ID
		gunshipsToTrack[unitID] = true
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID)
	-- Called when a unit is destroyed
	gunshipsToTrack[unitID] = nil
end

function gadget:UnitCmdDone(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	if gunshipsToTrack[unitID] and cmdID == CMD.ATTACK then
		stopGunshipIfNoCmdAndTarget(unitID, unitDefID)
	end
end
