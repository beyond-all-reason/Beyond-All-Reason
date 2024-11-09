function gadget:GetInfo()
	return {
		name = "Construction Turrets Range Check",
		desc = "Stops construction turrets from getting assigned to guards, repair, reclaim and attacks out of reach.",
		author = "Nehroz",
		date = "2024.11.09", -- update date.
		license = "GNU GPL, v2 or later",
		layer = 0,
		version = "1.0",
		enabled = true,
	}
end

local function isNano(unitDef)
	return unitDef.isFactory == false and unitDef.isStaticBuilder
end

local function isValidCommandID(commandID)
	return (
		   commandID == CMD.REPAIR
		or commandID == CMD.GUARD
		or commandID == CMD.RECLAIM
		or commandID == CMD.ATTACK
	)
end

function gadget:AllowCommand(unitID, unitDefID, _teamID, cmdID, cmdParams, _cmdOptions)
	local unitDef = UnitDefs[unitDefID]
	if not isNano(unitDef) then return true end
	if not isValidCommandID(cmdID) then return true end
	if #cmdParams ~= 1 then return true end -- only handle ID targets, fallthrough for area selects; Let the intended scripts handle, catch resulting commands on ID.
	local targetDef = UnitDefs[Spring.GetUnitDefID(cmdParams[1])]
	if targetDef == nil then return true end -- ignore Features / non units
	if targetDef.canMove then return true end -- ignore movable targets
	local distance = Spring.GetUnitSeparation(unitID, cmdParams[1], false, false)
	if distance > (unitDef.buildDistance + unitDef.radius) then
		return false
	end
	return true
end