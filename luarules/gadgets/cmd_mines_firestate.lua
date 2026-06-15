local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Mines fire state",
		desc = "Maps fire state commands to mines LUS functions",
		author = "DoodVanDaag",
		date = "15/06/2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local handledUnitDefIDs = {}

for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.customParams.mine then
		handledUnitDefIDs[unitDefID] = true
	end
end

function gadget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	if not handledUnitDefIDs[unitDefID] then
		return
	end
	if cmdID == CMD.FIRE_STATE then
		local toFireState = cmdParams[1]
		local scriptEnv = Spring.UnitScript.GetScriptEnv(unitID)
		if scriptEnv and scriptEnv.FireStateChange then
			Spring.UnitScript.CallAsUnit(unitID, scriptEnv.FireStateChange, toFireState)
		end
	end
end
