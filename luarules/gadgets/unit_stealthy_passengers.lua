
function gadget:GetInfo()
	return {
		name      = "Stealthy Passengers",
		desc      = "Makes passengers of stealthy transports stealthy themselves",
		author    = "Niobium",
		date      = "Jul 24, 2007",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true
	}
end

----------------------------------------------------------------
-- Synced only
----------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then
	return false
end

----------------------------------------------------------------
-- Vars
----------------------------------------------------------------
local stealthyTransports = {
	[UnitDefNames.armdfly.id] = true,
}
local stealthyUnits = {}

local spGetUnitDefID = Spring.GetUnitDefID
local spSetUnitStealth = Spring.SetUnitStealth

----------------------------------------------------------------
-- Callins
----------------------------------------------------------------
function gadget:Initialize()
	for uDefID, uDef in pairs(UnitDefs) do
		if uDef.stealth then
			stealthyUnits[uDefID] = true
		end
	end
end

function gadget:UnitLoaded(uID, uDefID, uTeam, transID, transTeam)
	if stealthyTransports[spGetUnitDefID(transID)] and not stealthyUnits[uDefID] then
		spSetUnitStealth(uID, true)
	end
end

function gadget:UnitUnloaded(uID, uDefID, tID, transID)
	if stealthyTransports[spGetUnitDefID(transID)] and not stealthyUnits[uDefID] then
		spSetUnitStealth(uID, false)
	end
end
