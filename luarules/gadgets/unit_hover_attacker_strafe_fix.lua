local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Hover Attackr Strafe Fix",
		desc = "When gunship aircraft stop attacking their target unit with no followup command, forces them to stop strafing and enter idle behavior",
		author = "JRTaylord: https://github.com/JRTaylord",
		date = "May 7, 2025",
		license = "GNU GPL, v2 or later",
		layer = 0, -- Lower layers execute first
		enabled = true,
	}
end

local gunshipDefs = {}
local gunshipsToTrack = {}

-- Synced code (runs on all clients in sync, handles game logic)
if gadgetHandler:IsSyncedCode() then
	-- Initialization
	function gadget:Initialize()
		-- Find all Hoverattack units
		Spring.Echo("Hover fix starting")
		for defID, unitDef in pairs(UnitDefs) do
			if
				(unitDef.canFly or unitDef.isAirUnit)
				and (unitDef.gunship or unitDef.isHoveringAirUnit)
				and #unitDef.weapons > 0
			then
				Spring.Echo("Adding unit", unitDef.name)
				Spring.Echo("Adding unit with weapons for " .. unitDef.name, #unitDef.weapons)
				gunshipDefs[defID] = {
					name = unitDef.name,
					weapons = unitDef.weapons,
					weaponCount = #unitDef.weapons,
				}
			end

			-- if (unitDef.canFly or unitDef.isAirUnit) and (unitDef.gunship or unitDef.isHoveringAirUnit) then
			-- 	for name, param in unitDef:pairs() do
			-- 		Spring.Echo(unitDef.name .. ": " .. name, param)
			-- 	end
			-- end
		end
	end

	-- Unit tracking
	function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
		-- Called when a unit is created
		-- Spring.Echo("Creating Unit ID: " .. unitID)
		if gunshipDefs[unitDefID] then
			-- Initialize previous command for new hover attacker unit ID
			-- Spring.Echo("Creating Hovering Unit ID: " .. unitID)
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
		if frameNum % 20 ~= 0 then
			return
		end
		-- Spring.Echo("Hoverfix frameNum", frameNum)

		for unitID, previousCmd in pairs(gunshipsToTrack) do
			-- Spring.Echo("Checking Hovering Unit ID", unitID)
			local currentGunship = gunshipsToTrack[unitID]
			-- local currentCmdID, currentCmdOpts, currentCmdParams = Spring.GetUnitCurrentCommand(unitID)

			local unitDefID = currentGunship.unitDefID

			local hasTarget = isTargettingUnit(unitID, unitDefID)
			Spring.Echo(gunshipDefs[unitDefID].name .. " " .. unitID .. ": " .. "hasTarget", hasTarget)

			local numCommands = #Spring.GetUnitCommands(unitID, 5)
			-- Spring.Echo(gunshipDefs[unitDefID].name .. " " .. unitID .. ": " .. "numCommands", numCommands)

			-- If the unit no longer has a target, then tell it to stop
			if not hasTarget and currentGunship.prevHasTarget and numCommands == 0 then
				Spring.Echo(gunshipDefs[unitDefID].name .. " " .. unitID .. ": " .. "shouldStop", true)
				Spring.GiveOrderToUnit(unitID, CMD.STOP, {}, {})
			else
				Spring.Echo(gunshipDefs[unitDefID].name .. " " .. unitID .. ": " .. "shouldStop", false)
			end
			-- update previous target tracked
			gunshipsToTrack[unitID].prevHasTarget = hasTarget
		end
	end

	function isTargettingUnit(unitID, unitDefID)
		local weaponCount = gunshipDefs[unitDefID].weaponCount

		Spring.Echo(gunshipDefs[unitDefID].name .. " " .. unitID .. ": " .. "weaponCount", weaponCount)
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
