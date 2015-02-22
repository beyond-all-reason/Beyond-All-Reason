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

-- block them from being healed
-- prevent the cursor from offering heal commands as default
-- make them neutral, radar stealthy & not appear on the minimap
-- transfer them all to gaia (to avoid unit limit)
-- make them vulnerable while being built
-- ignore them from area attack commands

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
        if cmdParams[2] then return true end -- area reclaim
        targetID = cmdParams[1]
    else
        if not cmdParams[1] or not cmdParams then return true end
        if cmdParams[1]~=CMD_RECLAIM then return true end
        if cmdParams[4] then return true end -- insert area reclaim
        if not cmdParams[3] then return true end
        targetID = cmdParams[3]    
    end

    if not spValidUnitID(targetID) then return true end
    local targetDefID = spGetUnitDefID(targetID)

    if isWall[targetDefID] then
        return false
    end

	return true
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
    if isWall[unitDefID] and Spring.ValidUnitID(unitID) then
        Spring.TransferUnit(unitID, gaiaTeamID, false)
        Spring.SetUnitStealth(unitID, true)
        Spring.SetUnitSonarStealth(unitID, true)
        Spring.SetUnitNeutral(unitID, true)    
    end
end

function gadgetUnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
    if walls[unitDefID] then
        local health,maxHealth,_,_,buildProgress = Spring.GetUnitHealth(unitID)
        if buildProgress < 0.99 then
            return max(damage,maxHealth/2), nil
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
local spGetMouseState = Spring.GetMouseState
local spTraceScreenRay = Spring.TraceScreenRay
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitIsActive = Spring.GetUnitIsActive

local mx,my,s,uID,sDefID
local changeCMD

function gadget:DefaultCommand()
	mx,my = spGetMouseState()
	s,uID = spTraceScreenRay(mx,my)
	if s ~= "unit" then return end
	sDefID = spGetUnitDefID(uID)
	if isWall[sDefID] then 
        return CMD_MOVE
    end
	return
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
    if isWall[unitDefID] and Spring.ValidUnitID(unitID) then
        Spring.SetUnitNoMinimap(unitID, true)
    end
end


end

