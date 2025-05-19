local gadget = gadget ---@type Gadget

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

local allowAssist = not Spring.GetModOptions().disable_assist_ally_construction

if allowAssist then
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


local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitTeam = Spring.GetUnitTeam
local spAreTeamsAllied = Spring.AreTeamsAllied
local spValidUnitID = Spring.ValidUnitID
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetUnitStates = Spring.GetUnitStates

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

local function existsNonOwnedMex(myTeam, x, y, z)
    local units = Spring.GetUnitsInCylinder(x, z, 10)
    for k, unitID in ipairs(units) do
        if isMex[Spring.GetUnitDefID(unitID)] then
            if Spring.GetUnitTeam(unitID) ~= myTeam then
                return true
            end
        end
    end
    return false
end

local function existsNonOwnedGeo(myTeam, x, y, z)
    local units = Spring.GetUnitsInCylinder(x, z, 10)
    for k, unitID in ipairs(units) do
        if isGeo[Spring.GetUnitDefID(unitID)] then
            if Spring.GetUnitTeam(unitID) ~= myTeam then
                return true
            end
        end
    end
    return false
end

function gadget:AllowUnitCreation(unitDefID, builderID, builderTeam, x, y, z)
	-- Disallow upgrading allied mexes and allied geos
	if isMex[unitDefID] then
		return not existsNonOwnedMex(builderTeam, x, y, z)
	elseif isGeo[unitDefID] then
		return not existsNonOwnedGeo(builderTeam, x, y, z)
	end
	return true
end


function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)

	-- Disallow guard commands onto labs, units that have buildOptions or can assist

	if (cmdID == CMD.GUARD) then
		local targetID = cmdParams[1]
		local targetTeam = spGetUnitTeam(targetID)
		local targetUnitDef = UnitDefs[spGetUnitDefID(targetID)]
		
		if (unitTeam ~= Spring.GetUnitTeam(targetID)) and spAreTeamsAllied(unitTeam, targetTeam) then
			if #targetUnitDef.buildOptions > 0 or targetUnitDef.canAssist then
				return false
			end
		end
		return true
	end

	-- Disallow assisting blueprints (caused by a repair command)
	-- Area repair doesn't cause assisting, so it's fine that we can't properly filter it

	if (cmdID == CMD.REPAIR and #cmdParams == 1) then
		local targetID = cmdParams[1]

		if not Spring.ValidUnitID(targetID) then
			return true
		end

		local targetTeam = Spring.GetUnitTeam(targetID)
		
		if (unitTeam ~= spGetUnitTeam(targetID)) and spAreTeamsAllied(unitTeam, targetTeam) then
			if(not isComplete(targetID)) then
				return false
			end
		end
		return true
	end

	-- Disallow changing the move_state value of non-factory builders to ROAM (move_state of roam causes builders to auto-assist ally construction)
	local unitDef = UnitDefs[unitDefID]
	if (cmdID == CMD.MOVE_STATE and cmdParams[1] == 2 and unitDef.isBuilder and not unitDef.isFactory) then
		spGiveOrderToUnit(unitID, CMD.MOVE_STATE, 0) -- make toggling still work between Hold and Maneuver
		return false
	end
	return true
end


function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	local unitDef = UnitDefs[unitDefID]
	if unitDef.isBuilder and not unitDef.isFactory and spGetUnitStates(unitID).movestate == 2 then -- prevent non-factory builders from being created with move_state ROAM
		spGiveOrderToUnit(unitID, CMD.MOVE_STATE, 0)
	end
end


function gadget:AllowUnitTransfer(unitID, unitDefID, fromTeamID, toTeamID, capture) -- prevent players from sharing unfinished blueprints, which would allow two players to work on the same construction
	if(capture) then
		return true
	end
	return not Spring.GetUnitIsBeingBuilt(unitID)
end

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD.GUARD)
	gadgetHandler:RegisterAllowCommand(CMD.REPAIR)
	gadgetHandler:RegisterAllowCommand(CMD.MOVE_STATE)
end