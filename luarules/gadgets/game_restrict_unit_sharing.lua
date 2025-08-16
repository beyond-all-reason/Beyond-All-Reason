local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = 'Restrict Unit Sharing',
		desc    = 'Restrict unit sharing',
		author  = 'Hobo Joe',
		date    = 'April 2024',
		license = 'GNU GPL, v2 or later',
		layer   = 0,
		enabled = true
	}
end

----------------------------------------------------------------
-- Synced only
----------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then
	return false
end

local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt

local whitelist = {}
local blacklist = {}
local allowSharingUnitsUnderConstruction = true

function gadget:AllowUnitTransfer(unitID, unitDefID, fromTeamID, toTeamID, capture)
	if (capture) then
		return true
	end
	if not allowSharingUnitsUnderConstruction and spGetUnitIsBeingBuilt(unitID) then
		return false
	end
	if (blacklist[unitDefID]) then
		return false
	end
	if (whitelist[unitDefID]) then
		return true
	end
	if (#blacklist > 0) then
		return true
	end
	if (#whitelist > 0) then
		return false
	end
	return true
end


function gadget:Initialize()
	GG['restrict_unit_sharing'] = {}
	GG['restrict_unit_sharing'].setWhitelist = function(units)
		blacklist = {}
		whitelist = units
	end
	GG['restrict_unit_sharing'].setBlacklist = function(units)
		whitelist = {}
		blacklist = units
		Spring.Echo("set sharing blacklist", #units)
	end
	GG['restrict_unit_sharing'].setAllowSharingUnitsUnderConstruction = function(value)
		allowSharingUnitsUnderConstruction = value
	end
end
