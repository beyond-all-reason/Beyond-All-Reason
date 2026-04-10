
local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = "Stockpile Script",
        desc      = "makes unit stockpile status known to unit scripts",
        author    = "Floris",
        date      = "July 2022",
        license   = "GNU GPL, v2 or later",
        layer     = 0,
        enabled   = true
    }
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local hasSetStockpile  = {}
for udid, ud in pairs(UnitDefs) do
	if ud.canStockpile then
		hasSetStockpile[udid] = true
	end
end

local spGetUnitStockpile = SpringShared.GetUnitStockpile
local spCallCOBScript = SpringSynced.CallCOBScript
local spGetCOBScriptID = SpringSynced.GetCOBScriptID

function gadget:Initialize()
    for i, unitID in pairs(SpringShared.GetAllUnits()) do
        gadget:UnitCreated(unitID, SpringShared.GetUnitDefID(unitID))
		if hasSetStockpile[SpringShared.GetUnitDefID(unitID)] then
			spCallCOBScript(unitID, 'SetStockpile', 0, spGetUnitStockpile(unitID))
		end
    end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	if hasSetStockpile[unitDefID] ~= nil then
		hasSetStockpile[unitDefID] = spGetCOBScriptID(unitID, 'SetStockpile') and true or false
	end
end

function gadget:StockpileChanged(unitID, unitDefID, unitTeam, weaponNum, oldCount, newCount)
	if hasSetStockpile[unitDefID] then
		spCallCOBScript(unitID, 'SetStockpile', 0, newCount)
	end
end
