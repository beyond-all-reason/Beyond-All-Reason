
local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name		= "Specific Unit Loader",
		desc		= "Hold down Alt or Ctrl and give an area load order, centered on a unit of the type to load.",
		author		= "Google Frog, doo edit for load commands",
		date		= "May 12, 2008",
		license	 	= "GNU GPL, v2 or later",
		layer		= 0,
		enabled	 	= true
	}
end

local team = Spring.GetMyTeamID()
local allyTeam = Spring.GetMyAllyTeamID()

-- Speedups

local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGiveOrderToUnitArray = Spring.GiveOrderToUnitArray
local spGetUnitCommands = Spring.GetUnitCommands
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
local spWorldToScreenCoords = Spring.WorldToScreenCoords
local spTraceScreenRay = Spring.TraceScreenRay
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetModKeyState = Spring.GetModKeyState

local reclaimEnemy = Game.reclaimAllowEnemies

local CMD_LOAD_UNITS = CMD.LOAD_UNITS
local CMD_STOP = CMD.STOP

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

function widget:CommandNotify(id, params, options)

	if id ~= CMD_LOAD_UNITS or #params ~= 4 then
		return
	end
	if options.alt or options.ctrl then

		local cx, cy, cz = params[1], params[2], params[3]

		local mx,my,mz = spWorldToScreenCoords(cx, cy, cz)
		local cType,id = spTraceScreenRay(mx,my)

		if cType == "unit" then

			local cr = params[4]

			local selUnits = spGetSelectedUnits()

			local targetEnemy = reclaimEnemy and spGetUnitAllyTeam(id) ~= allyTeam
			local unitDef = spGetUnitDefID(id)
			local preareaUnits
			local countarea = 0
			local areaUnits = {}
			if targetEnemy then
				areaUnits = spGetUnitsInCylinder(cx, cz, cr, -4)
			else
				preareaUnits = spGetUnitsInCylinder(cx, cz, cr, team)
				for i=1,#preareaUnits do
					local unitID = preareaUnits[i]
					if (options.alt and spGetUnitDefID(unitID) == unitDef) or options.ctrl then
						countarea = countarea + 1
						areaUnits[countarea] = unitID
					end
				end
			end
			for ct=1,#selUnits do
				local unitID = selUnits[ct]
				for i=1,#areaUnits do
					local areaUnitID = areaUnits[i]
					local cmdOpts = {}
					if options.shift then
						cmdOpts = {"shift"}
					end
					if i%#areaUnits == ct%#areaUnits or ct%#selUnits == i%#selUnits then
						Spring.GiveOrderToUnit(unitID, CMD_LOAD_UNITS, {areaUnitID}, cmdOpts)
					end

				end
			end
			return true

		end
	end


end


