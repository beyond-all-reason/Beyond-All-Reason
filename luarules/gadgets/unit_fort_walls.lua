--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
  return {
    name      = "Fortification Walls",
    desc      = "Implements fortification walls as units",
    author    = "Bluestone", 
    date      = "Feb 2015",
    license   = "Bacon",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

-- make them neutral, radar stealthy, not appear on the minimap
-- make them vulnerable while being built
-- once built, prevent them from being healed

-- would be good if they were omitted from area attacks but this is not currently possible

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if gadgetHandler:IsSyncedCode() then

local isWall = {
    [UnitDefNames["armdrag"].id] = true,
    [UnitDefNames["cordrag"].id] = true,
    [UnitDefNames["armfort"].id] = true,
    [UnitDefNames["corfort"].id] = true,
    [UnitDefNames["corfdrag"].id] = true,
    [UnitDefNames["armfdrag"].id] = true,
}

local gaiaTeamID = Spring.GetGaiaTeamID()
local spValidUnitID = Spring.ValidUnitID
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitHealth = Spring.GetUnitHealth
local CMD_REPAIR = CMD.REPAIR
local CMD_INSERT = CMD.INSERT
local max = math.max

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)
	if cmdID ~= CMD_REPAIR and cmdID ~= CMD_INSERT then return true end
	if not cmdParams then return true end
    
    local targetID
    if cmdID == CMD_REPAIR then
        if not cmdParams[1] then return true end
        if cmdParams[2] then return true end -- area repair
        targetID = cmdParams[1]
    else
        if not cmdParams[1] or not cmdParams then return true end
        if cmdParams[1]~=CMD_RECLAIM then return true end
        if cmdParams[4] then return true end -- insert area repair
        if not cmdParams[3] then return true end
        targetID = cmdParams[3]    
    end

    if not spValidUnitID(targetID) then return true end
    local targetDefID = spGetUnitDefID(targetID)
    local _,_,_,_,p = Spring.GetUnitHealth(targetID)

    if isWall[targetDefID] and p==1 then
        return false
    end

	return true
end

function gadget:UnitCreated(unitID, unitDefID, teamID, builderID)
    if isWall[unitDefID] and Spring.ValidUnitID(unitID) then
        --Spring.TransferUnit(unitID, gaiaTeamID, false) --could transfer to gaia to avoid counting towards unit limit, but then you can area attack your own walls :/
        --local _,_,_,_,_,aID = Spring.GetTeamInfo(teamID)
        --Spring.SetUnitLosMask(unitID, aID, 1)
        Spring.SetUnitStealth(unitID, true)
        Spring.SetUnitSonarStealth(unitID, true)
        Spring.SetUnitNeutral(unitID, true)
    end
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
    if isWall[unitDefID] then
        local health,maxHealth,_,_,buildProgress = Spring.GetUnitHealth(unitID)
        if buildProgress < 0.99 then
            return max(damage,maxHealth/3), nil
        end
    end
    return damage, nil 
end

else --UNSYNCED

local isWall = {
    [UnitDefNames["armdrag"].id] = true,
    [UnitDefNames["cordrag"].id] = true,
    [UnitDefNames["armfort"].id] = true,
    [UnitDefNames["corfort"].id] = true,
    [UnitDefNames["corfdrag"].id] = true,
    [UnitDefNames["armfdrag"].id] = true,
}

local CMD_MOVE = CMD.MOVE
local CMD_REPAIR = CMD.REPAIR
local spGetMouseState = Spring.GetMouseState
local spTraceScreenRay = Spring.TraceScreenRay
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitIsActive = Spring.GetUnitIsActive

local mx,my,s,uID,sDefID
function gadget:DefaultCommand()
	mx,my = spGetMouseState()
	s,uID = spTraceScreenRay(mx,my)
	if s ~= "unit" then return end
	sDefID = spGetUnitDefID(uID)
	if isWall[sDefID] then 
        local _,_,_,_,p = Spring.GetUnitHealth(uID)
        if p==1 then
            return CMD_MOVE
        end
    end
	return
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
    if isWall[unitDefID] and Spring.ValidUnitID(unitID) then
        Spring.SetUnitNoMinimap(unitID, true)
    end
end

end

