--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    unit_factory_guard.lua
--  brief:   assigns new builder units to guard their source factory
--  author:  Dave Rodgers
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "FactoryGuard",
    desc      = "Assigns new builders to assist their source factory",
    author    = "trepan",
    date      = "Jan 8, 2007",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = false  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Automatically generated local definitions

local CMD_GUARD            = CMD.GUARD
local CMD_MOVE             = CMD.MOVE
local spGetMyTeamID        = Spring.GetMyTeamID
local spGetUnitBuildFacing = Spring.GetUnitBuildFacing
local spGetUnitGroup       = Spring.GetUnitGroup
local spGetUnitPosition    = Spring.GetUnitPosition
local spGetUnitRadius      = Spring.GetUnitRadius
local spGiveOrderToUnit    = Spring.GiveOrderToUnit
local spSetUnitGroup       = Spring.SetUnitGroup


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function ClearGroup(unitID, factID)
  -- clear the unit's group if it's the same as the factory's
  local unitGroup = spGetUnitGroup(unitID)
  if (not unitGroup) then
    return
  end
  local factGroup = spGetUnitGroup(factID)
  if (not factGroup) then
    return
  end
  if (unitGroup == factGroup) then
    spSetUnitGroup(unitID, -1)
  end
end


local function GuardFactory(unitID, unitDefID, factID, factDefID)
  -- is this a factory?
  local fd = UnitDefs[factDefID]
  if (not (fd and fd.isFactory)) then
    return 
  end

  -- can this unit assist?
  local ud = UnitDefs[unitDefID]
  if (not (ud and ud.isBuilder and ud.canAssist)) then
    return
  end

  local x, y, z = spGetUnitPosition(factID)
  if (not x) then
    return
  end

  local radius = spGetUnitRadius(factID)
  if (not radius) then
    return
  end
  local dist = radius * 2

  local facing = spGetUnitBuildFacing(factID)
  if (not facing) then
    return
  end

  -- facing values { S = 0, E = 1, N = 2, W = 3 }  
  local dx, dz -- down vector
  local rx, rz -- right vector
  if (facing == 0) then
    -- south
    dx, dz =  0,  dist
    rx, rz =  dist,  0
  elseif (facing == 1) then
    -- east
    dx, dz =  dist,  0
    rx, rz =  0, -dist
  elseif (facing == 2) then
    -- north
    dx, dz =  0, -dist
    rx, rz = -dist,  0
  else
    -- west
    dx, dz = -dist,  0
    rx, rz =  0,  dist
  end
  
  local OrderUnit = spGiveOrderToUnit

  OrderUnit(unitID, CMD_MOVE,  { x + dx, y, z + dz }, { "" })
  if Spring.TestMoveOrder(unitDefID, x + dx + rx, y, z + dz + rz) then
	OrderUnit(unitID, CMD_MOVE,  { x + dx + rx, y, z + dz + rz }, { "shift" })
		  if Spring.TestMoveOrder(unitDefID, x + rx, y, z + rz ) then
			OrderUnit(unitID, CMD_MOVE,  { x + rx, y, z + rz }, { "shift" })
		  end
  elseif Spring.TestMoveOrder(unitDefID, x + dx - rx, y, z + dz - rz) then
    OrderUnit(unitID, CMD_MOVE,  { x + dx - rx, y, z + dz - rz }, { "shift" })
		  if Spring.TestMoveOrder(unitDefID, x - rx, y, z - rz ) then
			OrderUnit(unitID, CMD_MOVE,  { x - rx, y, z - rz  }, { "shift" })
		  end
  end
  OrderUnit(unitID, CMD_GUARD, { factID },            { "shift" })
end


--------------------------------------------------------------------------------

function widget:UnitFromFactory(unitID, unitDefID, unitTeam,
                                factID, factDefID, userOrders)
  if (unitTeam ~= spGetMyTeamID()) then
    return -- not my unit
  end
  
  ClearGroup(unitID, factID)

  if (userOrders) then
    return -- already has user assigned orders
  end

  GuardFactory(unitID, unitDefID, factID, factDefID)
end


--------------------------------------------------------------------------------

function widget:GameStart()
  widget:PlayerChanged()
end

function widget:PlayerChanged(playerID)
    if Spring.GetSpectatingState() and Spring.GetGameFrame() > 0 then
        widgetHandler:RemoveWidget(self)
    end
end

function widget:Initialize()
    if Spring.IsReplay() or Spring.GetGameFrame() > 0 then
        widget:PlayerChanged()
    end
end