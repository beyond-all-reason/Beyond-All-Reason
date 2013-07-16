
function widget:GetInfo()
	return {
		name			= "Specific Unit Reclaimer",
		desc			= "Hold down Alt and give an area reclaim order, centered on a unit of the type to reclaim.",
		author		= "Google Frog",
		date			= "May 12, 2008",
		license	 = "GNU GPL, v2 or later",
		layer		 = 0,
		enabled	 = true	--	loaded by default?
	}
end

local team = Spring.GetMyTeamID()
local allyTeam = Spring.GetMyAllyTeamID()

-- Speedups

local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGiveOrderToUnitArray = Spring.GiveOrderToUnitArray
local spGetCommandQueue = Spring.GetCommandQueue
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
local spWorldToScreenCoords = Spring.WorldToScreenCoords
local spTraceScreenRay = Spring.TraceScreenRay
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetModKeyState = Spring.GetModKeyState


local reclaimEnemy = Game.reclaimAllowEnemies

local CMD_RECLAIM = CMD.RECLAIM
local CMD_STOP = CMD.STOP
--

function widget:Initialize()
	if Spring.GetSpectatingState() then
		widgetHandler:RemoveWidget()
		return
	end
end

function widget:PlayerChanged(playerID)
	if Spring.GetSpectatingState() then
		widgetHandler:RemoveWidget()
		return
	end
end

function widget:CommandNotify(id, params, options)

	if id ~= CMD_RECLAIM or #params ~= 4 then
		return
	end
	if not options.alt then 
		return
	end
	
	local cx, cy, cz = params[1], params[2], params[3]

	local mx,my,mz = spWorldToScreenCoords(cx, cy, cz)
	local cType,id = spTraceScreenRay(mx,my) 

	if cType == "unit" then 

		local cr = params[4]

		local selUnits = spGetSelectedUnits()
	
		
		local targetEnemy = reclaimEnemy and spGetUnitAllyTeam(id) ~= allyTeam
		local unitDef = spGetUnitDefID(id)
		local areaUnits = spGetUnitsInCylinder(cx ,cz , cr)
		
		if not targetEnemy and not options.ctrl then
			areaUnits = spGetUnitsInCylinder(cx ,cz , cr, team)
		end
	
		local count = 0
		for i, aid in ipairs(areaUnits) do 
			if (targetEnemy and spGetUnitAllyTeam(aid) ~= allyTeam) or ( not targetEnemy and spGetUnitDefID(aid) == unitDef ) then
				local cmdOpts = {}
				if count ~= 0 or options.shift then
					cmdOpts = {"shift"}
				end
				spGiveOrderToUnitArray( selUnits, CMD_RECLAIM, {aid}, cmdOpts)
				count = count + 1
			end
		end
		return true 
	
	end
	
	
end


