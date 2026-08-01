local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name      = "Transported building Ghost Remover",
		desc      = "Removes the ghosts left by transported buildings",
		author    = "Chronographer",
		date      = "Nov 2025",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true
	}
end

spSetUnitLeavesGhost = Spring.SetUnitLeavesGhost

if not gadgetHandler:IsSyncedCode() then return end

local leavesGhost = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.leavesGhost == true then
		leavesGhost[unitDefID] = true
	end
end

function gadget:UnitLoaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	if leavesGhost[unitDefID] then
		spSetUnitLeavesGhost(unitID, false, true) -- Old ghost persists until position re-enters LOS 
	end
end

function gadget:UnitUnloaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	if leavesGhost[unitDefID] then
		spSetUnitLeavesGhost(unitID, true)
	end
end
