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

local spCallAsUnit = Spring.UnitScript.CallAsUnit
local spGetScriptEnv = Spring.UnitScript.GetScriptEnv

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
		local scriptEnv = spGetScriptEnv(unitID)
		-- we already made sure the unit was a mine so it HAS mine_lus loaded
		-- so I don't think it's worth nil-checking
		-- I don't think it's worth caching the scriptEnv.FireStateChange functions
		-- because we don't CMD.FIRE_STATE that often anyway
		spCallAsUnit(unitID, scriptEnv.FireStateChange, toFireState)
	end
end
