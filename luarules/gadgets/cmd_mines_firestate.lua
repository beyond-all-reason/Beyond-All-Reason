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

-- setting Spring.UnitScript locals fails here, maybe due to alphabetical order of loading?
-- due to the relatively low expected number of mines firestates changes, i'm not bothering with optimizations here.

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
	-- Engine sets firestate and movestates via an internal command upon unit creation, right before calling UnitCreated()
	-- We therefor still need to nilcheck the scriptEnv, as it might not "exist" yet
	-- But in that case, cmdParams[1] is just the UnitDef's default firestate
	-- so we can safely ignore that first command, as the script already expects that firestate starting value
		local toFireState = cmdParams[1]
		local scriptEnv = Spring.UnitScript.GetScriptEnv(unitID)
		if not scriptEnv then
			return
		end
		Spring.UnitScript.CallAsUnit(unitID, scriptEnv.FireStateChange, toFireState)
	end
end
