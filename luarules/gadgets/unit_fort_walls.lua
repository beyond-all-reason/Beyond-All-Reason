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
-- make them not auto-attacked by enemy units

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if gadgetHandler:IsSyncedCode() then

local isWall = {
    [UnitDefNames["armdrag"].id] = true,
    [UnitDefNames["cordrag"].id] = true,
    [UnitDefNames["armfort"].id] = true,
    [UnitDefNames["corfort"].id] = true,
}

local spValidUnitID = Spring.ValidUnitID
local spGetUnitDefID = Spring.GetUnitDefID
local CMD_REPAIR = CMD.REPAIR
local CMD_INSERT = CMD.INSERT

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

function UnitCreated(unitID, unitDefID, unitTeam, builderID)
    if isWall[unitDefID] then
          SetUnitNeutral(unitID, true)    
    end
end


else --UNSYNCED

local isWall = {
    [UnitDefNames["armdrag"].id] = true,
    [UnitDefNames["cordrag"].id] = true,
    [UnitDefNames["armfort"].id] = true,
    [UnitDefNames["corfort"].id] = true,
}

-- change the command when hovering over a isWall unit to move

local CMD_MOVE = CMD.MOVE
local spGetMouseState = Spring.GetMouseState
local spTraceScreenRay = Spring.TraceScreenRay
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitIsActive = Spring.GetUnitIsActive

local mx,my,s,uID,sDefID
local changeCMD

-- keep track of if mouse is hovering over (for perf reasons; Update is called much less than DefaultCommand)
function gadget:Update()
	mx,my = spGetMouseState()
	s,uID = spTraceScreenRay(mx,my)
	if s ~= "unit" then return end
	sDefID = spGetUnitDefID(uID)
	if isWall[sDefID] then 
        changeCMD = true
    else
        changeCMD = false
    end
end

function gadget:DefaultCommand()
	if changeCMD then 
		return CMD_MOVE
	end
	return
end




end

