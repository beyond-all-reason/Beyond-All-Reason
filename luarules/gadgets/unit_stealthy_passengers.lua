local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Stealthy Passengers",
		desc = "Makes passengers of stealthy transports stealthy themselves",
		author = "Niobium",
		date = "Jul 24, 2007",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local ATTRIBUTE_SOURCE = "stealthy_passengers"

local spGetUnitDefID = Spring.GetUnitDefID

local stealthyUnits = {}
local stealthyTransports = {}
for udid, ud in pairs(UnitDefs) do
	if ud.customParams.stealths_passengers then
		stealthyTransports[udid] = true
	end
	if ud.stealth then
		stealthyUnits[udid] = true
	end
end

function gadget:UnitLoaded(uID, uDefID, uTeam, transID, transTeam)
	if not stealthyUnits[uDefID] and stealthyTransports[spGetUnitDefID(transID)] then
		GG.UnitAttributes.SetUnitAttribute(uID, "stealth", true, ATTRIBUTE_SOURCE)
	end
end

function gadget:UnitUnloaded(uID, uDefID, tID, transID)
	if not stealthyUnits[uDefID] and stealthyTransports[spGetUnitDefID(transID)] then
		GG.UnitAttributes.SetUnitAttribute(uID, "stealth", nil, ATTRIBUTE_SOURCE)
	end
end

function gadget:Initialize()
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		local transportID = Spring.GetUnitTransporter(unitID)
		if transportID then
			gadget:UnitLoaded(unitID, spGetUnitDefID(unitID), nil, transportID)
		end
	end
end
