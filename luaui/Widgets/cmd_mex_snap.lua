
function widget:GetInfo()
	return {
		name      = "Mex Snap",
		desc      = "Snaps mexes to give 100% metal",
		author    = "Niobium",
		version   = "v1.2",
		date      = "November 2010",
		license   = "GNU GPL, v2 or later",
		layer     = -1,
		enabled   = true,
		handler   = true
	}
end

local maxCommands = 100

local Game_extractorRadius = Game.extractorRadius
local Game_extractorRadiusSq = Game_extractorRadius * Game_extractorRadius

local spGetModKeyState = Spring.GetModKeyState
local spGetMyTeamID = Spring.GetMyTeamID

local spGetBuildFacing = Spring.GetBuildFacing
local spPos2BuildPos = Spring.Pos2BuildPos
local spGetUnitCommands = Spring.GetUnitCommands
local spGetActiveCommand = Spring.GetActiveCommand
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetMouseState = Spring.GetMouseState
local spTraceScreenRay = Spring.TraceScreenRay
local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
local spGetUnitMetalExtraction = Spring.GetUnitMetalExtraction
local spGiveOrder = Spring.GiveOrder
local math_pi = math.pi
local preGamestartPlayer = Spring.GetGameFrame() == 0 and not Spring.GetSpectatingState()

local activeCmdID, bx, by, bz, bface
local unitshape
local curPosition

local isMex = {}
local unitSizesQuad = {}
for uDefID, uDef in pairs(UnitDefs) do
	if uDef.extractsMetal > 0 then
		isMex[uDefID] = uDef.extractsMetal * 1000
		unitSizesQuad[uDefID] = {uDef.xsize*4, uDef.zsize*4}
	end
end
local isMexConstructor = {}
for uDefID, uDef in pairs(UnitDefs) do
	if uDef.buildOptions then
		for _, option in ipairs(uDef.buildOptions) do
			if isMex[option] then
				isMexConstructor[uDefID] = uDef.buildOptions
				break
			end
		end
	end
end

local function GetExtractionAmount(spot, metalExtracts, orders)
	local spotWorth = spot.worth/1000.0
	local remainingMetal = spotWorth * metalExtracts

	for _, unit in pairs(spGetUnitsInCylinder(spot.x, spot.z, Game_extractorRadius)) do
		local mMakes = spGetUnitMetalExtraction(unit)

		if mMakes then
			remainingMetal = remainingMetal - mMakes
		end
	end

	for _, order in pairs(orders) do
		local ox, oz = order[1][1], order[1][3]

		local dx, dz = ox - spot.x, oz - spot.z

		if dx*dx + dz*dz < Game_extractorRadiusSq then
			remainingMetal = remainingMetal - order[2] * spotWorth
		end
	end

	return remainingMetal
end

local function GetBuildingDimensions(uDefID, facing)
	if facing % 2 == 1 then
		return unitSizesQuad[uDefID][2], unitSizesQuad[uDefID][1]
	else
		return unitSizesQuad[uDefID][1], unitSizesQuad[uDefID][2]
	end
end

local function DoBuildingsClash(buildData1, buildData2)

	local w1, h1 = GetBuildingDimensions(buildData1[1], buildData1[5])
	local w2, h2 = GetBuildingDimensions(buildData2[1], buildData2[5])

	return math.abs(buildData1[2] - buildData2[2]) < w1 + w2 and
		math.abs(buildData1[4] - buildData2[4]) < h1 + h2
end

local function GetClashingOrdersPreGame()
	if not (WG['pregame-build'] and WG['pregame-build'].getPreGameDefID and WG['pregame-build'].getBuildQueue) then return {} end


	local buildFacing = spGetBuildFacing() or 1
	local orders = {}
	local ordersCount = 0

	for _, order in pairs(WG['pregame-build'].getBuildQueue()) do
		local orderDefID = order[1]
		local extractsMetal = isMex[orderDefID]

		if extractsMetal then
			ordersCount = ordersCount + 1
			orders[ordersCount] = { { order[2], order[3], order[4], order[5] }, extractsMetal }

			local obx, _, obz = spPos2BuildPos(orderDefID, order[2], order[3], order[4])
			local buildData = { -activeCmdID, obx, nil, obz, order[5] or buildFacing }
			local buildData2 = { orderDefID, bx, nil, bz, buildFacing }

			if DoBuildingsClash(buildData, buildData2) then
				return nil
			end
		end
	end

	return orders
end

local function GetClashingOrdersGame()
	local buildFacing = spGetBuildFacing() or 1
	local orders = {}
	local ordersCount = 0

	--local mexConstructor = WG['resource_spot_builder'].GetMexConstructor

	for _, unitID in pairs(spGetSelectedUnits()) do
		local udef = Spring.GetUnitDefID(unitID)
		if isMexConstructor[udef] then
			local canBuild = false
			for _, buildOption in pairs(isMexConstructor[udef]) do
				if buildOption == -activeCmdID then canBuild = true; break end
			end
			if canBuild then
				local unitOrders = spGetUnitCommands(unitID, maxCommands)

				for _, order in pairs(unitOrders) do
					local orderDefID = -order["id"]
					local extractsMetal = isMex[orderDefID]

					if extractsMetal then
						local params = order["params"]
						ordersCount = ordersCount + 1
						orders[ordersCount] = { params, extractsMetal }

						local obx, _, obz = spPos2BuildPos(orderDefID, params[1], params[2], params[3])
						local buildData = { -activeCmdID, obx, nil, obz, params[4] or buildFacing }
						local buildData2 = { orderDefID, bx, nil, bz, buildFacing }

						if DoBuildingsClash(buildData, buildData2) then
							return nil
						end
					end
				end
			end
		end
	end

	return orders
end

local function GetClashingOrders()
	return preGamestartPlayer and GetClashingOrdersPreGame() or GetClashingOrdersGame()
end

local function GetClosestMex(x, z, positions, metalExtracts, orders)
	local bestPos
	local bestDist = math.huge
	for i = 1, #positions do
		local pos = positions[i]
		if pos.x then
			local dx, dz = x - pos.x, z - pos.z
			local dist = dx * dx + dz * dz
			if dist < bestDist and GetExtractionAmount(pos, metalExtracts, orders) > 0 then
				bestPos = pos
				bestDist = dist
			end
		end
	end
	return bestPos
end

local function GetClosestPosition(x, z, positions)
	local bestPos
	local bestDist = math.huge
	for i = 1, #positions do
		local pos = positions[i]
		if pos.x then
			local dx, dz = x - pos.x, z - pos.z
			local dist = dx * dx + dz * dz
			if dist < bestDist then
				bestPos = pos
				bestDist = dist
			end
		end
	end
	return bestPos
end

local function GiveNotifyingOrder(cmdID, cmdParams, cmdOpts)
	if widgetHandler:CommandNotify(cmdID, cmdParams, cmdOpts) then
		return
	end

	spGiveOrder(cmdID, cmdParams, cmdOpts)
end

local function DoLine(x1, y1, z1, x2, y2, z2)
	gl.Vertex(x1, y1, z1)
	gl.Vertex(x2, y2, z2)
end

local function clearShape()
	if unitshape then
		WG.StopDrawUnitShapeGL4(unitshape[6])
		unitshape = nil
	end
end

function widget:Initialize()
	WG.MexSnap = {}
	if not WG.DrawUnitShapeGL4 then
		widgetHandler:RemoveWidget()
	end
	if not WG['resource_spot_finder'] or not WG['resource_spot_finder'].metalSpotsList then
		Spring.Echo("<Snap Mex> This widget requires the 'Metalspot Finder' widget to run.")
		widgetHandler:RemoveWidget()
	end
end

function widget:Shutdown()
	if WG.StopDrawUnitShapeGL4 then
		clearShape()
	end
	WG.MexSnap = nil
end

function widget:GameStart()
	preGamestartPlayer = false
end

local function clearCurPosition()
	curPosition = nil
	WG.MexSnap.curPosition = curPosition
end

function widget:Update()
	if preGamestartPlayer then
		activeCmdID = WG['pregame-build'] and WG['pregame-build'].getPreGameDefID()
		if activeCmdID then activeCmdID = -activeCmdID end
	else
		_, activeCmdID = spGetActiveCommand()
	end

	if not activeCmdID then
		clearCurPosition()
		return
	end

	local metalExtracts = isMex[-activeCmdID]
	if not metalExtracts then
		clearCurPosition()
		return
	end

	-- Attempt to get position of command
	local mx, my = spGetMouseState()
	local _, pos = spTraceScreenRay(mx, my, true)
	if not pos then
		clearCurPosition()
		return
	end

	-- Find build position and check if it is available (Would get 100% metal)
	bx, by, bz = spPos2BuildPos(-activeCmdID, pos[1], pos[2], pos[3])
	local shift = select(4, spGetModKeyState())
	local orders = shift and GetClashingOrders() or {}
	if not orders then
		clearCurPosition()
		return
	end

	local closestSpot = GetClosestMex(bx, bz, WG['resource_spot_finder'].metalSpotsList, metalExtracts, orders)
	if not closestSpot or WG['resource_spot_finder'].IsMexPositionValid(closestSpot, bx, bz) then
		clearCurPosition()
		return
	end

	-- Get the closest position that would give 100%
	bface = spGetBuildFacing()
	local mexPositions = WG['resource_spot_finder'].GetBuildingPositions(closestSpot, -activeCmdID, bface, true)
	local bestPos = GetClosestPosition(bx, bz, mexPositions)
	if not bestPos then
		clearCurPosition()
		return
	end

	curPosition = bestPos
	WG.MexSnap.curPosition = curPosition
end

function widget:DrawWorld()
	if not WG.DrawUnitShapeGL4 then
		return
	end

	local bestPos = curPosition
	if not bestPos then
		clearShape()
		return
	end

	-- Draw line
	gl.DepthTest(false)
	gl.LineWidth(1.49)
	gl.Color(1, 1, 0, 0.45)
	gl.BeginEnd(GL.LINE_STRIP, DoLine, bx, by, bz, bestPos.x, bestPos.y, bestPos.z)
	gl.LineWidth(1.0)
	gl.DepthTest(true)

	-- Add/update unit shape rendering
	local newUnitshape = {-activeCmdID, bestPos.x, bestPos.y, bestPos.z, bface}
	if not unitshape or (unitshape[1]~= newUnitshape[1] or unitshape[2]~= newUnitshape[2] or unitshape[3]~= newUnitshape[3] or unitshape[4]~= newUnitshape[4] or unitshape[5]~= newUnitshape[5]) then
		clearShape()
		unitshape = newUnitshape
		unitshape[6] = WG.DrawUnitShapeGL4(unitshape[1], unitshape[2], unitshape[3], unitshape[4], unitshape[5]*math_pi, 0.66, spGetMyTeamID(), 0.15, 0.3)
	end
end

function widget:CommandNotify(cmdID, cmdParams, cmdOpts)
	local metalExtracts = isMex[-cmdID]

	if not metalExtracts then return end
	if cmdOpts.mexsnap then return end -- notifying order

	local cbx, cbz = cmdParams[1], cmdParams[3]

	local orders = cmdOpts.shift and GetClashingOrders() or {}
	local closestSpot = GetClosestMex(bx, bz, WG['resource_spot_finder'].metalSpotsList, metalExtracts, orders)

	if closestSpot and not WG['resource_spot_finder'].IsMexPositionValid(closestSpot, cbx, cbz) then
		local cbface = cmdParams[4]
		local mexPositions = WG['resource_spot_finder'].GetBuildingPositions(closestSpot, -cmdID, cbface, true)
		local bestPos = GetClosestPosition(bx, bz, mexPositions)
		if bestPos then
			cmdOpts.mexsnap = true
			GiveNotifyingOrder(cmdID, {bestPos.x, bestPos.y, bestPos.z, bface}, cmdOpts)
			return true
		end
	end
end
