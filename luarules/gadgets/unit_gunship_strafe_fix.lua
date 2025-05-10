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
			if
				(unitDef.canFly or unitDef.isAirUnit)
				and (unitDef.gunship or unitDef.isHoveringAirUnit or unitDef.hoverattack)
				and #unitDef.weapons > 0
			then
				gunshipDefs[defID] = {
					name = unitDef.name,
					weapons = unitDef.weapons,
					weaponCount = #unitDef.weapons,
				}
			end
		end
	end

	-- Unit tracking
	function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
		-- Called when a unit is created
		if gunshipDefs[unitDefID] then
			-- Initialize previous command for new hover attacker unit ID
			gunshipsToTrack[unitID] = {
				unitDefID = unitDefID,
				prevHasTarget = false,
			}
		end
	end

	function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID)
		-- Called when a unit is destroyed
		gunshipsToTrack[unitID] = nil
	end

	-- Game frame update (called every simulation frame)
	function gadget:GameFrame(frameNum)
		if frameNum % 100 ~= 0 then
			return
		end

		for unitID, currentGunship in pairs(gunshipsToTrack) do
			local unitDefID = currentGunship.unitDefID
			local hasTarget = isTargettingUnit(unitID, unitDefID)
			local numCommands = #Spring.GetUnitCommands(unitID, 2)

			Spring.Echo(gunshipDefs[unitDefID].name .. " " .. unitID .. ": " .. "numCommands", numCommands)
			Spring.Echo(gunshipDefs[unitDefID].name .. " " .. unitID .. ": " .. "hasTarget", hasTarget)
			Spring.Echo(
				gunshipDefs[unitDefID].name .. " " .. unitID .. ": " .. "prevHasTarget",
				currentGunship.prevHasTarget
			)
			-- If the unit no longer has a target, then tell it to stop
			if not hasTarget and currentGunship.prevHasTarget and numCommands == 0 then
				Spring.GiveOrderToUnit(unitID, CMD.STOP, {}, cmdOptions)
			end
			-- update previous target tracked
			currentGunship.prevHasTarget = hasTarget
		end
	end

	function isTargettingUnit(unitID, unitDefID)
		local weaponCount = gunshipDefs[unitDefID].weaponCount

		for weaponNum = 1, weaponCount do
			local targetType, isUserTarget, targetID = Spring.GetUnitWeaponTarget(unitID, weaponNum)
			Spring.Echo(gunshipDefs[unitDefID].name .. " " .. unitID .. ": " .. "targetType", targetType)
			Spring.Echo(gunshipDefs[unitDefID].name .. " " .. unitID .. ": " .. "targetID", targetID)
			if targetType == 1 and targetID then
				return true
			end
		end
		return false
	end
else
end
