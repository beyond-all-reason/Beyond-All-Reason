
local widget = widget ---@type Widget
function widget:GetInfo()
	return {
		name			= "Area Reclaim Enemy",
		desc			= "Hold down Alt an give area reclaim order on the ground or enemy.",
		author			= "NemoTheHero",
		date			= "May 16, 2025",
		license			= "GNU GPL, v2 or later",
		layer			= 0,
		enabled			= true
	}
end

local team = Spring.GetMyTeamID()
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

local gameStarted


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
end

function widget:Initialize()
    if Spring.IsReplay() or Spring.GetGameFrame() > 0 then
        maybeRemoveSelf()
    end
end

---Finds the average position of passed in units
---@param units table selected units
---@return table { x, z }
local function getAvgPositionOfUnits(units)
	local unitCount = 0
	local tX, tZ = 0, 0
	for i = 1, #units do
		local id = units[i]
		local x, _, z = spGetUnitPosition(id)
		if z then
			tX, tZ = tX+x, tZ+z
			unitCount = unitCount + 1
		end
	end
	if unitCount == 0 then return end
	return { x = tX / unitCount, z = tZ / unitCount }
end



function widget:CommandNotify(id, params, options)
	-- RECLAIM with area affect
	if id ~= CMD_RECLAIM or #params ~= 4 then
		return
	end
	-- holding alt key
	if options.alt then
		
		local cx, cy, cz = params[1], params[2], params[3]

		local mx,my,mz = spWorldToScreenCoords(cx, cy, cz)
		local cType,id = spTraceScreenRay(mx,my)

		if cType == "unit" or cType == "ground" then

			local cr = params[4]
			-- x,y,radius of command
			local unitsWithReclaim = spGetSelectedUnits()
			if #unitsWithReclaim == 0 then
				return
			end
			local averagePosUnits = getAvgPositionOfUnits(unitsWithReclaim)

			local areaUnits = spGetUnitsInCylinder(cx, cz, cr)
			local enemyUnits = {}
			for i=1,#areaUnits do
				local unitID    = areaUnits[i]
				local enemyUnit = spGetUnitAllyTeam(unitID) ~= allyTeam
				if enemyUnit then
					table.insert(enemyUnits, unitID)
				end
			end

			if #enemyUnits == 0 then
				return
			end

			-- sort enemyUnits by distance from averagePoint
			table.sort(enemyUnits,
				function (unit1, unit2)
					local x1, _, z1 = spGetUnitPosition(unit1)
					local x2, _, z2 = spGetUnitPosition(unit2)
					--distance formula
					return (((averagePosUnits.x-x1)^2)+((averagePosUnits.z-z1)^2))^.5 <
					(((averagePosUnits.x-x2)^2)+((averagePosUnits.z-z2)^2))^.5
				end
			)
			
			local count = 0
			for i=1,#enemyUnits do
				local unitID = enemyUnits[i]
				local cmdOpts = {"meta", "ctrl"}
				if count ~= 0 or options.shift then
					cmdOpts = {"shift", "meta", "ctrl"}
				end
				spGiveOrderToUnitArray( unitsWithReclaim, CMD_RECLAIM, {unitID}, cmdOpts)
				count = count + 1
			end
			return true
		end
	end
end


