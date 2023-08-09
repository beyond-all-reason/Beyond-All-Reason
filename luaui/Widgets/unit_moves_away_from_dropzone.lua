--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--	file:		CMD.unit_moves_away_From_dropzone.lua
--	brief:
--	author:	Owen Martindell
--
--	Copyright (C) 2007.
--	Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name		= "Unit Moves away from Dropzone",
		desc		= "when a unit is unloaded, it moves away from the DZ to prevent scrunched up units and overlaps",
		author		= "Sefi",
		date		= "August 10,2023",
		license		= "GNU GPL, v2 or later",
		layer		= 0,
		enabled		= true	--	loaded by default?
	}
end

local GiveOrderToUnit = Spring.GiveOrderToUnit
local GetUnitPosition = Spring.GetUnitPosition
local GetUnitDirection = Spring.GetUnitDirection
local GetMyTeamID = Spring.GetMyTeamID
local GetUnitDefID = Spring.GetUnitDefID
local Echo = Spring.Echo

local CMD_MOVE = CMD.MOVE

--------------------------------------------------------------------------------

local myTeamID = GetMyTeamID()
local moveUnitsDefs = {}
local gameStarted

function maybeRemoveSelf()
	if Spring.GetSpectatingState() and (Spring.GetGameFrame() > 0 or gameStarted) then
		widgetHandler:RemoveWidget()
	end
end

function widget:GameStart()
	gameStarted = true
	Echo("Starting with unit moves away scrip ####...")

	maybeRemoveSelf()
end

function widget:PlayerChanged(playerID)
	maybeRemoveSelf()
end

function widget:Initialize()

	Echo("Initializin with unit moves away scrip ####...")

	if Spring.IsReplay() or Spring.GetGameFrame() > 0 then
		maybeRemoveSelf()
	end
	--for unitDefID,unitDef in pairs(UnitDefs) do
	--	if unitDef.canMove and unitDef.speed > 0 then --mobile builder
	--				moveUnitsDefs[buildeeDefID] = true --mark the mobile unit
	--		end
	--	end

	--local units = Spring.GetTeamUnits(myTeamID);
	--for i=1,#units do
	--	local unitID = units[i]
	--	widget:UnitCreated(unitID,GetUnitDefID(unitID),myTeamID)
	--end
end


function widget:UnitUnloaded(unitID, unitDefID, teamID, transportID)
--function widget:UnitCreated(unitID, unitDefID, unitTeam,builderID)
	Echo("Unit Unloaded YYYYY")


	--if unitTeam ~= myTeamID then
	--	return
	--end
	Echo("Unit Unloaded XXXX")

	--//if  moveUnitsDefs[unitDefID]then

		Echo("Moving The unit away after uploading...")

		local x, y, z = GetUnitPosition(unitID)
		local dx,dy,dz = GetUnitDirection(transportID)
		local moveDist = 100


		GiveOrderToUnit(unitID, CMD_MOVE, {x+dx*moveDist, y, z+dz*moveDist}, 0)
	--//end
end


--function widget:UnitGiven(unitID, unitDefID, newTeam, oldTeamID)
--	widget:UnitDestroyed(unitID)
--	widget:UnitCreated(unitID, unitDefID, newTeam)
--end
--
--function widget:UnitTaken(unitID, unitDefID, oldTeamID, newTeam)
--	widget:UnitDestroyed(unitID)
--	widget:UnitCreated(unitID, unitDefID, newTeam)
--end




--------------------------------------------------------------------------------
