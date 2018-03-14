--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  brief:   sets immobile builders to MANEUVERING, and gives them a FIGHT order
--  author:  Dave Rodgers
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
	name		= "ImmobileBuilder",
	desc		= "Sets immobile builders to MANEUVER, with a FIGHT command",
	author		= "trepan",
	date		= "Jan 8, 2007",
	license		= "GNU GPL, v2 or later",
	layer		= 0,
	enabled		= true  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local CMD_MOVE_STATE		= CMD.MOVE_STATE
local CMD_FIGHT				= CMD.FIGHT
local spGetMyTeamID			= Spring.GetMyTeamID
local spGetTeamUnits		= Spring.GetTeamUnits
local spGetUnitDefID		= Spring.GetUnitDefID
local spGetUnitPosition		= Spring.GetUnitPosition
local spGiveOrderToUnit		= Spring.GiveOrderToUnit
local spGetSpectatingState	= Spring.GetSpectatingState

local hmsx = Game.mapSizeX/2
local hmsz = Game.mapSizeZ/2


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- set immobile builders (nanotowers?) to the MANEUVER movestate,
-- and give them a FIGHT order, too close to the unit will drop the order so we add 50 distance


local function IsImmobileBuilder(ud)
	return ud and ud.isBuilder and not ud.canMove and not ud.isFactory
end


local function SetupUnit(unitID)
	local x, y, z = spGetUnitPosition(unitID)
	if x and y and z then
	    if (x > hmsx) then -- avoid to issue commands outside map
	      x = x - 50
	    else
	      x = x + 50
	    end
	    if (z > hmsz) then
	      z = z - 50
	    else
	      z = z + 50
	    end	
		-- meta enables reclaim enemy units, alt autoresurrect ( if available )
		spGiveOrderToUnit(unitID, CMD_FIGHT, { x, y, z }, {"meta"})
	end
end

function maybeRemoveSelf()
    if Spring.GetSpectatingState() and (Spring.GetGameFrame() > 0 or gameStarted) then
        widgetHandler:RemoveWidget(self)
    end
end

function widget:GameStart()
    gameStarted = true
    maybeRemoveSelf()
end

function widget:PlayerChanged(playerID)
    maybeRemoveSelf()
end

function widget:Initialize()
    if Spring.IsReplay() or Spring.GetGameFrame() > 0 then
        maybeRemoveSelf()
    end
	for _,unitID in ipairs(spGetTeamUnits(spGetMyTeamID())) do
		local unitDefID = spGetUnitDefID(unitID)
		if IsImmobileBuilder(UnitDefs[unitDefID]) then
			spGiveOrderToUnit(unitID, CMD_MOVE_STATE, { 1 }, {})
			SetupUnit(unitID)
		end
	end
end


function widget:UnitCreated(unitID, unitDefID, unitTeam)
	if unitTeam ~= spGetMyTeamID() then
		return
	end
	if IsImmobileBuilder(UnitDefs[unitDefID]) then
		spGiveOrderToUnit(unitID, CMD_MOVE_STATE, { 1 }, {})
		SetupUnit(unitID)
	end
end


function widget:UnitGiven(unitID, unitDefID, unitTeam)
	widget:UnitCreated(unitID, unitDefID, unitTeam)
end



function widget:UnitIdle(unitID, unitDefID, unitTeam)
	if unitTeam ~= spGetMyTeamID() then
		return
	end
	if IsImmobileBuilder(UnitDefs[unitDefID]) then
		SetupUnit(unitID)
	end
end



--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
