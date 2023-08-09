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
local armTshipUnitDefID = UnitDefNames["armtship"].id
local coreTshipUnitDefID = UnitDefNames["cortship"].id
local armThoverUnitDefID = UnitDefNames["armthovr"].id
local coreThoverUnitDefID = UnitDefNames["corthovr"].id
local coreIntrUnitDefID = UnitDefNames["corintr"].id

local GiveOrderToUnit = Spring.GiveOrderToUnit
local GetUnitPosition = Spring.GetUnitPosition
local GetUnitDirection = Spring.GetUnitDirection
local GetMyTeamID = Spring.GetMyTeamID
local GetUnitDefID = Spring.GetUnitDefID
local Echo = Spring.Echo

local CMD_MOVE = CMD.MOVE

--------------------------------------------------------------------------------
local waterlevel
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
 waterlevel = Spring.GetModOptions().map_waterlevel


	Echo("Initializin with unit moves away scrip ####..." ..armTshipUnitDefID)

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
	if teamID ~= myTeamID then
		return
	end

	local transportDefId =GetUnitDefID(transportID)


	--only run this script if it from a sea or hover or ground transport
	if transportDefId == coreIntrUnitDefID or transportDefId == armTshipUnitDefID or transportDefId==coreTshipUnitDefID or transportDefId == coreThoverUnitDefID or transportDefId==armThoverUnitDefID then

		Echo("Unlloaded ".. unitID.. " from "..transportDefId)

		local x, y, z = GetUnitPosition(unitID)

		local t_x, t_y, t_z = GetUnitPosition(transportID)

		--calc the angle Dif so we know what direction to unload in
		local dx,dy,dz = GetUnitDirection(transportID)

		local moveDist = 100
		local new_x = x+dx*moveDist;
		local new_z=z+dz*moveDist;

		--if for some reason the destination is underwater, we need a different target destination
		local groundLevel=Spring.GetGroundHeight( new_x, new_z )
		if	groundLevel <= waterlevel then
			new_x = x+dx-moveDist;
			new_z=z+dz-moveDist;
		end


		GiveOrderToUnit(unitID, CMD_MOVE, {new_x, y, new_z}, 0)
		--//end

	end
end






--------------------------------------------------------------------------------
