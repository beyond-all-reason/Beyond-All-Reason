--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--	file:		CMD.unit_mover.lua
--	brief:	 Allows combat engineers to use repeat when building mobile units (use 2 or more build spots)
--	author:	Owen Martindell
--
--	Copyright (C) 2007.
--	Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name		= "Unit Mover",
		desc		= "Allows combat engineers to use repeat when building mobile units (use 2 or more build spots)",
		author		= "TheFatController",
		date		= "Mar 20, 2007",
		license		= "GNU GPL, v2 or later",
		layer		= 0,
		enabled		= false	--	loaded by default?
	}
end
local GetSpectatingState = Spring.GetSpectatingState
local GiveOrderToUnit = Spring.GiveOrderToUnit
local GetUnitPosition = Spring.GetUnitPosition
local GetUnitDirection = Spring.GetUnitDirection
local GetMyTeamID = Spring.GetMyTeamID
local GetSelectedUnits = Spring.GetSelectedUnits
local GetUnitDefID = Spring.GetUnitDefID


local CMD_MOVE = CMD.MOVE


--------------------------------------------------------------------------------

local myTeamID = GetMyTeamID()
local engineers = {}
local engineerDefs = {}
local moveUnitsDefs = {}

function widget:PlayerChanged()
	if GetSpectatingState() then
		widgetHandler:RemoveWidget()
	end
end

function widget:Initialize()
	widget:PlayerChanged()
	for unitDefID,unitDef in pairs(UnitDefs) do
		if unitDef.canMove and unitDef.speed > 0 then --mobile builder
			for _,buildeeDefID in pairs(unitDef.buildOptions) do
				local buildeeDef = UnitDefs[buildeeDefID]
				if buildeeDef.canMove and buildeeDef.speed > 0 then -- can build a mobile unit
					engineerDefs[unitDefID] = true -- mark the engineer
					moveUnitsDefs[buildeeDefID] = true --mark the mobile unit
				end
			end
		end
	end
	for _,unitID in pairs(Spring.GetTeamUnits(myTeamID)) do
		widget:UnitCreated(unitID,GetUnitDefID(unitID),myTeamID)
	end
end



function widget:UnitCreated(unitID, unitDefID, unitTeam,builderID)
	if unitTeam ~= myTeamID then
		return
	end
	if engineerDefs[unitDefID] then
		engineers[unitID] = {}
	end
	if builderID and moveUnitsDefs[unitDefID] and engineers[builderID] then
		local x, y, z = GetUnitPosition(unitID)
		local dx,dy,dz = GetUnitDirection(unitID)
		local moveDist = 50
		GiveOrderToUnit(unitID, CMD_MOVE, {x+dx*moveDist, y, z+dz*moveDist}, { "" })
	end
end

function widget:UnitDestroyed(unitID)
	engineers[unitID] = nil
end

function widget:UnitGiven(unitID, unitDefID, newTeam, oldTeamID)
	widget:UnitDestroyed(unitID)
	widget:UnitCreated(unitID, unitDefID, newTeam)
end

function widget:UnitTaken(unitID, unitDefID, oldTeamID, newTeam)
	widget:UnitDestroyed(unitID)
	widget:UnitCreated(unitID, unitDefID, newTeam)
end




--------------------------------------------------------------------------------
