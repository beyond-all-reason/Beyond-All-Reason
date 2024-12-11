function gadget:GetInfo()
	return {
		name    = 'Disable Assist Ally Construction',
		desc    = 'Disable assisting allied units (e.g. labs and units/buildings under construction) when modoption is enabled',
		author  = 'Rimilel',
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
if	not (Spring.GetModOptions().disable_assist_ally_construction
	-- tax force enables this
	or (Spring.GetModOptions().tax_resource_sharing_amount or 0) ~= 0) then
	return false
end

local function isComplete(u)
	local _,_,_,_,buildProgress=Spring.GetUnitHealth(u)
	if buildProgress and buildProgress>=1 then
		return true
	else
		return false
	end
end



-- table of all mex unitDefIDs
local isMex = {} 
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.extractsMetal > 0 then
		isMex[unitDefID] = true
	end
end

local function existsNonOwnedMex(myTeam, x, y, z)
    local units = Spring.GetUnitsInCylinder(x, z, 10)
    for k, unitID in ipairs(units) do
        if isMex[Spring.GetUnitDefID(unitID)] then
            if Spring.GetUnitTeam(unitID) ~= myTeam then
                return unitID
            end
        end
    end
    return false
end

-- table of all geo unitDefIDs
local isGeo = {} 
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.customParams.geothermal then
		isGeo[unitDefID] = true
	end
end


local function existsNonOwnedGeo(myTeam, x, y, z)
    local units = Spring.GetUnitsInCylinder(x, z, 10)
    for k, unitID in ipairs(units) do
        if isGeo[Spring.GetUnitDefID(unitID)] then
            if Spring.GetUnitTeam(unitID) ~= myTeam then
                return unitID
            end
        end
    end
    return false
end

function gadget:AllowUnitCreation(unitDefID, builderID, builderTeam, x, y, z)
	-- Disallow upgrading allied mexes
	if isMex[unitDefID] then
		if existsNonOwnedMex(builderTeam, x, y, z) then
			return false
		end
	end
	-- Disallow upgrading allied geos
	if isGeo[unitDefID] then
		if existsNonOwnedGeo(builderTeam, x, y, z) then
			return false
		end
	end
end


function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)

	-- Disallow guard commands onto labs, units that have buildOptions or can assist

	if (cmdID == CMD.GUARD) then
		local targetID = cmdParams[1]
		local targetTeam = Spring.GetUnitTeam(targetID)
		local targetUnitDef = UnitDefs[Spring.GetUnitDefID(targetID)]
		
		if (unitTeam ~= Spring.GetUnitTeam(targetID)) and Spring.AreTeamsAllied(unitTeam, targetTeam) then
			if #targetUnitDef.buildOptions > 0 or targetUnitDef.canAssist then
				return false
			end
		end
		return true
	end

	-- Also disallow assisting building (caused by a repair command) units under construction 
	-- Area repair doesn't cause assisting, so it's fine that we can't properly filter it

	if (cmdID == CMD.REPAIR and #cmdParams == 1) then
		local targetID = cmdParams[1]
		local targetTeam = Spring.GetUnitTeam(targetID)

		if (unitTeam ~= Spring.GetUnitTeam(targetID)) and Spring.AreTeamsAllied(unitTeam, targetTeam) then
			if(not isComplete(targetID)) then
				return false
			end
		end
		return true
	end



	return true
end
