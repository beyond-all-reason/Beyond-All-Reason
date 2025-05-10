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

local GUNSHIP_STATES = {
	IDLE = 1,
	HAS_TARGET = 2,
	READY_TO_STOP = 3,
}

local gunshipDefs = {}
local gunshipsToTrack = {}
local cmdOptions = {
	internal = false,
}

-- Synced code (runs on all clients in sync, handles game logic)
if gadgetHandler:IsSyncedCode() then
	-- Initialization
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
	end

	-- Unit tracking
	function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
		-- Called when a unit is created
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
		if frameNum % 20 ~= 0 then
			return
		end

		for unitID, currentGunship in pairs(gunshipsToTrack) do
			local unitDefID = currentGunship.unitDefID
			local hasTarget = isTargettingUnit(unitID, unitDefID)
			local numCommands = #Spring.GetUnitCommands(unitID, 1)

			if hasTarget and not currentGunship.state ~= GUNSHIP_STATES.HAS_TARGET then
				-- When the gunship has a target, update state to match
				currentGunship.state = GUNSHIP_STATES.HAS_TARGET
			elseif not hasTarget and currentGunship.state == GUNSHIP_STATES.HAS_TARGET then
				-- When the gunship loses a target, update the state so it is ready to stop in the next cycle
				currentGunship.state = GUNSHIP_STATES.READY_TO_STOP
			elseif currentGunship.state == GUNSHIP_STATES.READY_TO_STOP and numCommands == 0 then
				-- When the gunship is out of commands and ready to stop, tell it to stop and put in the idle state
				Spring.GiveOrderToUnit(unitID, CMD.STOP, {}, cmdOptions)
				currentGunship.state = GUNSHIP_STATES.IDLE
			end

			-- Debug print statement for the gunship's state
			debugPrintGunshipState(currentGunship.state, unitID, unitDefID)
		end
	end

	function isTargettingUnit(unitID, unitDefID)
		local weaponCount = gunshipDefs[unitDefID].weaponCount
		for weaponNum = 1, weaponCount do
			local targetType, isUserTarget, targetID = Spring.GetUnitWeaponTarget(unitID, weaponNum)
			if targetType == 1 and targetID then
				return true
			end
		end
		return false
	end

	function debugPrintGunshipState(state, unitID, unitDefID)
		local stateStr = ""
		if state == GUNSHIP_STATES.IDLE then
			stateStr = "IDLE"
		elseif state == GUNSHIP_STATES.HAS_TARGET then
			stateStr = "HAS_TARGET"
		else
			stateStr = "READY_TO_STOP"
		end
		Spring.Echo(gunshipDefs[unitDefID].name .. " " .. unitID .. " state", stateStr)
	end
else
end
