
if not gadgetHandler:IsSyncedCode() then
	return
end


local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name      = "Factory Assist Fix",
		desc      = "Fixes factory assist so that builders don't leave to repair damaged finished units",
		author    = "TheDujin",
		date      = "Jun 2025",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true
	}
end

local isAssistBuilder = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.isBuilder and unitDef.canAssist then
		isAssistBuilder[unitDefID] = true
	end
end

-- If this builder unit is repairing the newly built unit when it should
-- instead be guarding the factory, remove the repair command
local function maybeRemoveRepairCmd(builderUnitID, builtUnitID, factID)
	local commands = Spring.GetUnitCommands(builderUnitID, 2)
	if (#commands >= 2) then
		local firstCmd = commands[1]
		local secondCmd = commands[2]
		if (firstCmd.id == CMD.REPAIR
			and secondCmd.id == CMD.GUARD) then
				local isRepairingBuiltUnit = firstCmd.params[1] == builtUnitID
				local isGuardingFactory = secondCmd.params[1] == factID
				if (isRepairingBuiltUnit and isGuardingFactory) then
					Spring.GiveOrderToUnit(builderUnitID, CMD.REMOVE, {firstCmd.id}, CMD.OPT_ALT)
				end
		end
	end
end

function gadget:UnitFromFactory(unitID, unitDefID, _,
								factID, _, _)
	local unitHealth, unitMaxHealth, _, _, _ = Spring.GetUnitHealth(unitID)
	if (unitHealth >= unitMaxHealth) then
		return -- if unit comes out with full health, guard works just fine
	end
	
	for _, otherUnitID in ipairs(Spring.GetAllUnits()) do
		local otherUnitDefID = Spring.GetUnitDefID(otherUnitID)
		if (isAssistBuilder[otherUnitDefID]) then
			maybeRemoveRepairCmd(otherUnitID, unitDefID, factID)
		end
	end
end
