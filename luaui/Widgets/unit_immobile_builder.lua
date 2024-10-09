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
	enabled		= true
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
local spGetCommandQueue     = Spring.GetCommandQueue
local spGetSpectatingState	= Spring.GetSpectatingState

local hmsx = Game.mapSizeX/2
local hmsz = Game.mapSizeZ/2

local myTeamID = spGetMyTeamID()

local gameStarted

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- set immobile builders (nanotowers?) to the MANEUVER movestate,
-- and give them a FIGHT order, too close to the unit will drop the order so we add 50 distance

local isImmobileBuilder = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.isBuilder and not unitDef.canMove and not unitDef.isFactory then
		isImmobileBuilder[unitDefID] = true
	end
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
        widgetHandler:RemoveWidget()
    end
end

function widget:GameStart()
    gameStarted = true
    maybeRemoveSelf()
end

function widget:PlayerChanged(playerID)
    maybeRemoveSelf()
	myTeamID = spGetMyTeamID()
end

function widget:Initialize()
    if Spring.IsReplay() or Spring.GetGameFrame() > 0 then
        maybeRemoveSelf()
    end
	for _,unitID in ipairs(spGetTeamUnits(spGetMyTeamID())) do
		local unitDefID = spGetUnitDefID(unitID)
		if isImmobileBuilder[unitDefID] then
			spGiveOrderToUnit(unitID, CMD_MOVE_STATE, { 1 }, 0)
			SetupUnit(unitID)
		end
	end
end


function widget:UnitCreated(unitID, unitDefID, unitTeam)
	if unitTeam ~= spGetMyTeamID() then
		return
	end
	if isImmobileBuilder[unitDefID] then
		spGiveOrderToUnit(unitID, CMD_MOVE_STATE, { 1 }, 0)
		SetupUnit(unitID)
	end
end


function widget:UnitGiven(unitID, unitDefID, unitTeam)
	widget:UnitCreated(unitID, unitDefID, unitTeam)
end



function widget:UnitIdle(unitID, unitDefID, unitTeam)
	if unitTeam ~= myTeamID then
		return
	end
	if isImmobileBuilder[unitDefID] then
		SetupUnit(unitID)
	end
end

function widget:UnitCommand(unitID, unitDefID, _, cmdID, _, cmdOpts)
	if isImmobileBuilder[unitDefID] and cmdOpts.shift and cmdID ~= CMD_FIGHT then
		local commandQueue = spGetCommandQueue(unitID, -1)
		local lastCommand = commandQueue[#commandQueue]
		if lastCommand and lastCommand.id == CMD_FIGHT then
			spGiveOrderToUnit(unitID, CMD.REMOVE, { lastCommand.tag }, 0)
		end
	end
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
