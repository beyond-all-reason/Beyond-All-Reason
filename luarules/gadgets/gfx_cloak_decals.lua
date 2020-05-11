function gadget:GetInfo()
	return {
		name      = "Cloak and Decals",
		desc      = "Removes decals upon cloak, restores upon decloak",
		author    = "ivand",
		date      = "2020",
		license   = "PD",
		layer     = 0,
		enabled   = true,
	}
end

-----------------------------------------------------------------
-- Global Acceleration
-----------------------------------------------------------------

local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitPieceList = Spring.GetUnitPieceList
local spGetUnitTeam = Spring.GetUnitTeam
local spSetUnitPieceVisible = Spring.SetUnitPieceVisible
local spGetUnitIsCloaked = Spring.GetUnitIsCloaked

if not gadgetHandler:IsSyncedCode() then -- Unsynced
	return
end

-- SYNCED


function gadget:UnitCloaked(unitID, unitDefID, unitTeam)
	Spring.RemoveObjectDecal(unitID)
end

function gadget:UnitDecloaked(unitID, unitDefID, unitTeam)
	Spring.AddObjectDecal(unitID)
end