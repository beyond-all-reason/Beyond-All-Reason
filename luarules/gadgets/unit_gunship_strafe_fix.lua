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
local FRAME_CHECK_FREQUENCY = 20
local GUNSHIP_STATES = {
	IDLE = 1,
	HAS_TARGET = 2,
}
local STATE_NAMES = {
	[GUNSHIP_STATES.IDLE] = "IDLE",
	[GUNSHIP_STATES.HAS_TARGET] = "HAS_TARGET",
}
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

local function debugPrintGunshipState(state, unitID, unitDefID)
	spEcho(gunshipDefs[unitDefID].name .. " " .. unitID .. " state: " .. STATE_NAMES[state])
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

	-- Register any existing gunships to ensure this fix works when loading scenarios or saved games
	-- Todo: ask more experienced devs if this is needed and if so, figure out/ask how to test this because save games don't load dev code based on my testing
	local allUnits = spGetAllUnits()
	for i = 1, #allUnits do
		local unitID = allUnits[i]
		local unitDefID = spGetUnitDefID(unitID)
		if gunshipDefs[unitDefID] then
			local initState = GUNSHIP_STATES.IDLE
			local currCommand = spGetUnitCommands(unitID, 1)[1]
			local numCommands = #spGetUnitCommands(unitID, 1)
			if hasTarget or (numCommands > 0 and currCommand.id == CMD.ATTACK) then
				initState = GUNSHIP_STATES.HAS_TARGET
			-- Stops any loaded in gunships that are idle and have no commands to fix gunships that are loaded in the strafe without target state
			elseif initState == GUNSHIP_STATES.IDLE and numCommands == 0 then
				spGiveOrderToUnit(unitID, CMD.STOP, {}, CMD_OPTIONS)
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
		local currCommand = spGetUnitCommands(unitID, 1)[1]
		local numCommands = #spGetUnitCommands(unitID, 1)

		if
			currentGunship.state ~= GUNSHIP_STATES.HAS_TARGET
			and (hasTarget or (numCommands > 0 and currCommand.id == CMD.ATTACK))
		then
			-- When the gunship has a target, update state to match
			currentGunship.state = GUNSHIP_STATES.HAS_TARGET
		elseif not hasTarget and numCommands == 0 and currentGunship.state == GUNSHIP_STATES.HAS_TARGET then
			-- When the gunship loses a target, update the state so it is ready to stop in the next cycle
			spGiveOrderToUnit(unitID, CMD.STOP, {}, CMD_OPTIONS)
			currentGunship.state = GUNSHIP_STATES.IDLE
		end

		-- Debug print statement for the gunship's state
		-- debugPrintGunshipState(currentGunship.state, unitID, unitDefID)
	end
end
