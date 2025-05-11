local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Gunship Strafe Fix",
		desc = "When gunships stop attacking their target unit with no followup command, forces them to stop strafing and enter idle behavior",
		author = "JRTaylord: https://github.com/JRTaylord",
		date = "May 7, 2025",
		license = "GNU GPL, v2 or later",
		layer = 0, -- Lower layers execute first
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
local CMD = Spring.Utilities.getTableFromNamedTable("CMD")
local FRAME_CHECK_FREQUENCY = 20
local GUNSHIP_STATES = {
	IDLE = 1,
	HAS_TARGET = 2,
	READY_TO_STOP = 3,
}
local STATE_NAMES = {
	[GUNSHIP_STATES.IDLE] = "IDLE",
	[GUNSHIP_STATES.HAS_TARGET] = "HAS_TARGET",
	[GUNSHIP_STATES.READY_TO_STOP] = "READY_TO_STOP",
}
local CMD_OPTIONS = { internal = false }

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

local function debugPrintGunshipState(state, unitID, unitDefID)
	spEcho(gunshipDefs[unitDefID].name .. " " .. unitID .. " state: " .. STATE_NAMES[state])
end

local function registerGunship(unitID) end

function gadget:Initialize()
	-- Find all gunship units
	for defID, unitDef in pairs(UnitDefs) do
		-- Todo: see if drones need to be excluded
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

	-- Register any existing gunships to ensure this fix works when loading scenarios or saved games
	local allUnits = spGetAllUnits()
	for i = 1, #allUnits do
		local unitID = allUnits[i]
		local unitDefID = spGetUnitDefID(unitID)
		if gunshipDefs[unitDefID] then
			local initState = GUNSHIP_STATES.IDLE
			if isTargettingUnit(unitID, unitDefID) then
				initState = GUNSHIP_STATES.HAS_TARGET
			end
			-- Initialize previous command for new gunship unit ID
			gunshipsToTrack[unitID] = {
				unitDefID = unitDefID,
				state = initState,
			}
		end
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	-- Called when a unit is created
	local unitDefID = spGetUnitDefID(unitID)
	if gunshipDefs[unitDefID] then
		-- Initialize previous command for new gunship unit ID
		gunshipsToTrack[unitID] = {
			unitDefID = unitDefID,
			state = GUNSHIP_STATES.IDLE,
		}
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID)
	-- Called when a unit is destroyed
	gunshipsToTrack[unitID] = nil
end

-- Game frame update (called every simulation frame)
function gadget:GameFrame(frameNum)
	-- Only call this once every 20 frames
	if frameNum % FRAME_CHECK_FREQUENCY ~= 0 then
		return
	end

	for unitID, currentGunship in pairs(gunshipsToTrack) do
		local unitDefID = currentGunship.unitDefID
		local hasTarget = isTargettingUnit(unitID, unitDefID)
		local numCommands = #spGetUnitCommands(unitID, 1)

		if hasTarget and currentGunship.state ~= GUNSHIP_STATES.HAS_TARGET then
			-- When the gunship has a target, update state to match
			currentGunship.state = GUNSHIP_STATES.HAS_TARGET
		elseif not hasTarget and currentGunship.state == GUNSHIP_STATES.HAS_TARGET then
			-- When the gunship loses a target, update the state so it is ready to stop in the next cycle
			currentGunship.state = GUNSHIP_STATES.READY_TO_STOP
		elseif currentGunship.state == GUNSHIP_STATES.READY_TO_STOP and numCommands == 0 then
			-- When the gunship is out of commands and ready to stop, tell it to stop and put in the idle state
			spGiveOrderToUnit(unitID, CMD.STOP, {}, CMD_OPTIONS)
			currentGunship.state = GUNSHIP_STATES.IDLE
		end

		-- Debug print statement for the gunship's state
		debugPrintGunshipState(currentGunship.state, unitID, unitDefID)
	end
end
