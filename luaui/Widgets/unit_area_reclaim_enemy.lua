
local widget = widget ---@type Widget
function widget:GetInfo()
	return {
		name			= "Area Reclaim Enemy",
		desc			= "Hold down Space an give area reclaim order on the ground or enemy to target enemies only during reclaim.",
		author			= "NemoTheHero",
		date			= "July 26, 2025",
		license			= "GNU GPL, v2 or later",
		layer			= 0,
		enabled			= true
	}
end

local allyTeam = Spring.GetMyAllyTeamID()

-- Speedups

local spGiveOrderToUnitArray = Spring.GiveOrderToUnitArray
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
local spWorldToScreenCoords = Spring.WorldToScreenCoords
local spTraceScreenRay = Spring.TraceScreenRay
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetUnitCmdDescs= Spring.GetUnitCmdDescs
local spGetUnitPosition= Spring.GetUnitPosition

local reclaimEnemy = Game.reclaimAllowEnemies

local CMD_RECLAIM = CMD.RECLAIM



function maybeRemoveSelf()
    if Spring.GetSpectatingState() and (Spring.GetGameFrame() > 0) then
        widgetHandler:RemoveWidget()
    end
end

function widget:GameStart()
    maybeRemoveSelf()
end

function widget:PlayerChanged(playerID)
    maybeRemoveSelf()
end

function widget:Initialize()
    if Spring.IsReplay() then
		maybeRemoveSelf()
    end
end

function widget:CommandNotify(id, params, options)
	-- RECLAIM with area affect and holding space key if not default to regular reclaim behavior
	if id ~= CMD_RECLAIM or #params ~= 4 or not options.meta then
		return
	end
	
	local cx, cy, cz, cr = unpack(params)

	local mx,my,mz = spWorldToScreenCoords(cx, cy, cz)
	local cType,id = spTraceScreenRay(mx,my)

	if not ( cType == "unit" or cType == "ground" ) then
		return
	end

	-- x,y,radius of command
	local selectedUnits = spGetSelectedUnits()
	   
	local areaUnits = spGetUnitsInCylinder(cx, cz, cr)
	local enemyUnits = {}
	-- get all enemy units in the area
	for i=1,#areaUnits do
		local unitID = areaUnits[i]
		local enemyUnit = not Spring.AreTeamsAllied(Spring.GetUnitTeam(unitID), Spring.GetMyTeamID())
		if enemyUnit then
			table.insert(enemyUnits, unitID)
		end
	end
	-- if no enemies, we default to regular reclaim behavior
	if #enemyUnits == 0 then
		return
	end

	-- get avg point of selected units
	local avgx, avgy, avgz = Spring.GetUnitArrayCentroid(selectedUnits)
	-- sort enemyUnits by distance from averagePoint of selected units
	table.sort(enemyUnits,
		function (unit1, unit2)
			local x1, _, z1 = spGetUnitPosition(unit1)
			local x2, _, z2 = spGetUnitPosition(unit2)
			--distance formula
			return math.hypot(avgx-x1, avgz-z1) <
			       math.hypot(avgx-x2, avgz-z2)
		end
	)


	-- create array of commands to reclaim each enemy unit
	local newCmds = {}
	for i = 1, #enemyUnits do
		local unitID = enemyUnits[i]
		local cmdOpts = CMD.OPT_META + CMD.OPT_CTRL
		if #newCmds ~= 0 or options.shift then
			cmdOpts = cmdOpts + CMD.OPT_SHIFT
		end
		newCmds[#newCmds + 1] = { CMD_RECLAIM, unitID , cmdOpts }
	end

	-- add the command to all units with reclaim
	if #newCmds > 0 then
		Spring.GiveOrderArrayToUnitArray(selectedUnits, newCmds)
		return true
	end
end


