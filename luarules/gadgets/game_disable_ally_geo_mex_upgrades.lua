local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = 'Disable ally extractor upgrade',
		desc    = 'Removes the ability for players to upgrade teammate mexes and geos in-place',
		author  = 'Hobo Joe',
		date    = 'August 2025',
		license = 'GNU GPL, v2 or later',
		layer   = 1,
		enabled = true
	}
end

----------------------------------------------------------------
-- Decide whether to activate
----------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then
	return false
end

local UnitTransfer = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_synced.lua")
local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")

local mode = Spring.GetModOptions().unit_sharing_mode
local modeUnitTypes = UnitTransfer.GetModeUnitTypes(mode)
local enableShare = table.contains(modeUnitTypes, SharedEnums.UnitType.Utility)

if enableShare then
	return false
end

----------------------------------------------------------------
-- Caching
----------------------------------------------------------------
local extractorRadius = Game.extractorRadius

local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitTeam = Spring.GetUnitTeam

-- create a table of all mex and geo unitDefIDs
local isMex = {}
local isGeo = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.extractsMetal > 0 then
		isMex[unitDefID] = true
	end
	if unitDef.customParams.geothermal then
		isGeo[unitDefID] = true
	end
end

----------------------------------------------------------------
-- Main behavior
----------------------------------------------------------------

local function mexBlocked(myTeam, x, y, z)
	local units = spGetUnitsInCylinder(x, z, extractorRadius)
	for _, unitID in ipairs(units) do
		if isMex[spGetUnitDefID(unitID)] then
			if spGetUnitTeam(unitID) ~= myTeam then
				return true
			end
		end
	end
	return false
end

local function geoBlocked(myTeam, x, y, z)
	local units = spGetUnitsInCylinder(x, z, extractorRadius)
	for _, unitID in ipairs(units) do
		if isGeo[spGetUnitDefID(unitID)] then
			if spGetUnitTeam(unitID) ~= myTeam then
				return true
			end
		end
	end
	return false
end

function gadget:AllowUnitCreation(unitDefID, builderID, builderTeam, x, y, z)
	-- Disallow upgrading allied mexes and allied geos
	if isMex[unitDefID] then
		return not mexBlocked(builderTeam, x, y, z)
	elseif isGeo[unitDefID] then
		return not geoBlocked(builderTeam, x, y, z)
	end
	return true
end
