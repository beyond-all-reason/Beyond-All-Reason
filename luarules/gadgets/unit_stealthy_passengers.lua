
local gadget = gadget ---@type Gadget

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

if not gadgetHandler:IsSyncedCode() then
	return false
end

local spGetUnitDefID = Spring.GetUnitDefID
local spSetUnitStealth = Spring.SetUnitStealth

local stealthyUnits = {}
local stealthyTransports = {
	[UnitDefNames.armdfly.id] = true,
}
for udid, ud in pairs(UnitDefs) do
	for id, v in pairs(stealthyTransports) do
		if string.find(ud.name, UnitDefs[id].name) then
			stealthyTransports[udid] = v
		end
	end
	if ud.stealth then
		stealthyUnits[udid] = true
	end
end

function gadget:UnitLoaded(uID, uDefID, uTeam, transID, transTeam)
	if not stealthyUnits[uDefID] and stealthyTransports[spGetUnitDefID(transID)] then
		spSetUnitStealth(uID, true)
	end
end

function gadget:UnitUnloaded(uID, uDefID, tID, transID)
	if not stealthyUnits[uDefID] and stealthyTransports[spGetUnitDefID(transID)] then
		spSetUnitStealth(uID, false)
	end
end
