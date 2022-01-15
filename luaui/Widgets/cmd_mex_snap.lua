
function widget:GetInfo()
	return {
		name      = "Mex Snap",
		desc      = "Snaps mexes to give 100% metal",
		author    = "Niobium",
		version   = "v1.2",
		date      = "November 2010",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true,
		handler   = true
	}
end

local mapBlackList = { "Brazillian_Battlefield_Remake_V2"  }

local spGetActiveCommand = Spring.GetActiveCommand
local spGetMouseState = Spring.GetMouseState
local spTraceScreenRay = Spring.TraceScreenRay
local math_pi = math.pi

local unitshape

local isMex = {}
for uDefID, uDef in pairs(UnitDefs) do
	if uDef.extractsMetal > 0 then
		isMex[uDefID] = true
	end
end

local function GetClosestMetalSpot(x, z)
	local bestSpot
	local bestDist = math.huge
	local metalSpots = WG.metalSpots
	for i = 1, #metalSpots do
		local spot = metalSpots[i]
		local dx, dz = x - spot.x, z - spot.z
		local dist = dx*dx + dz*dz
		if dist < bestDist then
			bestSpot = spot
			bestDist = dist
		end
	end
	return bestSpot
end

local function GetClosestMexPosition(spot, x, z, uDefID, facing)
	local bestPos
	local bestDist = math.huge
	local positions = WG.GetMexPositions(spot, uDefID, facing, true)
	for i = 1, #positions do
		local pos = positions[i]
		local dx, dz = x - pos[1], z - pos[3]
		local dist = dx*dx + dz*dz
		if dist < bestDist then
			bestPos = pos
			bestDist = dist
		end
	end
	return bestPos
end

local function GiveNotifyingOrder(cmdID, cmdParams, cmdOpts)
	if widgetHandler:CommandNotify(cmdID, cmdParams, cmdOpts) then
		return
	end
	Spring.GiveOrder(cmdID, cmdParams, cmdOpts.coded)
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
	if not WG.DrawUnitShapeGL4 then
		widgetHandler:RemoveWidget()
	end
	WG.MexSnap = {}
	if not WG.metalSpots then
		Spring.Echo("<Snap Mex> This widget requires the 'Metalspot Finder' widget to run.")
		widgetHandler:RemoveWidget()
	end

	for key,value in ipairs(mapBlackList) do
		if Game.mapName == value then
			Spring.Echo("<Snap Mex> This map is incompatible - removing mex snap widget.")
			widgetHandler:RemoveWidget()
		end
	end
end

function widget:Shutdown()
	if WG.StopDrawUnitShapeGL4 then
		clearShape()
	end
end


function widget:DrawWorld()
	if not WG.DrawUnitShapeGL4 then
		widget:Shutdown()
	end

	-- Check command is to build a mex
	local _, cmdID = spGetActiveCommand()
	if not (cmdID and isMex[-cmdID]) then
		clearShape()
		return
	end

	-- Attempt to get position of command
	local mx, my = spGetMouseState()
	local _, pos = spTraceScreenRay(mx, my, true)
	if not pos then
		clearShape()
		return
	end

	-- Find build position and check if it is valid (Would get 100% metal)
	local bx, by, bz = Spring.Pos2BuildPos(-cmdID, pos[1], pos[2], pos[3])
	local closestSpot = GetClosestMetalSpot(bx, bz)
	if not closestSpot or WG.IsMexPositionValid(closestSpot, bx, bz) then
		clearShape()
		return
	end

	-- Get the closet position that would give 100%
	local bface = Spring.GetBuildFacing()
	local bestPos = GetClosestMexPosition(closestSpot, bx, bz, -cmdID, bface)
	if not bestPos then
		WG.MexSnap.curPosition = nil
		clearShape()
		return
	end

	WG.MexSnap.curPosition = bestPos

	-- Draw line
	gl.DepthTest(false)
	gl.LineWidth(1.49)
	gl.Color(1, 1, 0, 0.4)
	gl.BeginEnd(GL.LINE_STRIP, DoLine, bx, by, bz, bestPos[1], bestPos[2], bestPos[3])
	gl.LineWidth(1.0)
	gl.DepthTest(true)

	-- Add/update unit shape rendering
	local newUnitshape = {-cmdID, bestPos[1], bestPos[2], bestPos[3], bface}
	if not unitshape or (unitshape[1]~= newUnitshape[1] or unitshape[2]~= newUnitshape[2] or unitshape[3]~= newUnitshape[3] or unitshape[4]~= newUnitshape[4] or unitshape[5]~= newUnitshape[5]) then
		clearShape()
		unitshape = newUnitshape
		unitshape[6] = WG.DrawUnitShapeGL4(unitshape[1], unitshape[2], unitshape[3], unitshape[4], unitshape[5]*math_pi, 0.66, Spring.GetMyTeamID(), 0.15, 0.3)
	end
end

function widget:CommandNotify(cmdID, cmdParams, cmdOpts)
	if isMex[-cmdID] then
		local bx, bz = cmdParams[1], cmdParams[3]
		local closestSpot = GetClosestMetalSpot(bx, bz)
		if closestSpot and not WG.IsMexPositionValid(closestSpot, bx, bz) then

			local bface = cmdParams[4]
			local bestPos = GetClosestMexPosition(closestSpot, bx, bz, -cmdID, bface)
			if bestPos then

				GiveNotifyingOrder(cmdID, {bestPos[1], bestPos[2], bestPos[3], bface}, cmdOpts)
				return true
			end
		end
	end
end
