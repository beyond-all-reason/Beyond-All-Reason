function widget:GetInfo()
	return {
		name      = "Geothermal Snap",
		desc      = "Snaps selected geothermal unit to the nearest geo spot",
		author    = "Niobium, Floris",
		version   = "",
		date      = "August 2021",
		license   = "GNU GPL, v2 or later",
		layer     = -1,
		enabled   = true,
	}
end

local spGetActiveCommand = Spring.GetActiveCommand
local spGetMouseState = Spring.GetMouseState
local spTraceScreenRay = Spring.TraceScreenRay
local math_pi = math.pi

local geoSelected = false
local mousePressed = false
local placedDirectly = false

local unitshape

local isGeo = {}
for uDefID, uDef in pairs(UnitDefs) do
	if uDef.needGeo then
		isGeo[uDefID] = true
	end
end

local spots = {}
local showGeothermalUnits = false
local function checkGeothermalFeatures()
	showGeothermalUnits = false
	local geoFeatureDefs = {}
	for defID, def in pairs(FeatureDefs) do
		if def.geoThermal then
			geoFeatureDefs[defID] = true
		end
	end
	spots = {}
	local features = Spring.GetAllFeatures()
	local spotCount = 0
	for i = 1, #features do
		if geoFeatureDefs[Spring.GetFeatureDefID(features[i])] then
			showGeothermalUnits = true
			local x, y, z = Spring.GetFeaturePosition(features[i])
			spotCount = spotCount + 1
			spots[spotCount] = {x, y, z}
		end
	end
end

local function getFootprintPos(value)	-- not entirely acurate, unsure why
	local precision = 16		-- (footprint 1 = 16 map distance)
	return (math.floor(value/precision)*precision)+(precision/2)
end

local function GetClosestSpot(x, z)
	local bestSpot
	local bestDist = math.huge
	for i = 1, #spots do
		local spot = spots[i]
		local dx, dz = x - spot[1], z - spot[3]
		local dist = dx*dx + dz*dz
		if dist < bestDist then
			bestSpot = spot
			bestDist = dist
		end
	end
	if bestSpot[1] then
		bestSpot[1] = getFootprintPos(bestSpot[1])
		bestSpot[3] = getFootprintPos(bestSpot[3])
	end
	return bestSpot
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
	if checkGeothermalFeatures then
		checkGeothermalFeatures()
	end
end

function widget:Shutdown()
	if WG.StopDrawUnitShapeGL4 then
		clearShape()
	end
end

function widget:GameFrame(gf)
	if checkGeothermalFeatures then
		checkGeothermalFeatures()
		checkGeothermalFeatures = nil

		if not showGeothermalUnits then
			widgetHandler:RemoveWidget()
		end
	end
end

function widget:MousePress(x, y, button)
	local cmdID, unitDefID, c, d = Spring.GetActiveCommand()
	--Spring.Echo(cmdID, unitDefID, c, d)
	if unitDefID and isGeo[-unitDefID] then
		geoSelected = true
	end
end

function widget:DrawWorld()
	if not WG.DrawUnitShapeGL4 then
		widget:Shutdown()
		return
	end

	-- command = geo?
	local _, cmdID = spGetActiveCommand()
	if not (cmdID and isGeo[-cmdID]) then
		geoSelected = false
		clearShape()
		return
	end

	-- Attempt to get position of command
	local mx, my, mb, mmb, mrb = spGetMouseState()
	local _, pos = spTraceScreenRay(mx, my, true)
	if not pos then
		clearShape()
		return
	end

	-- Find build position
	local bx, by, bz = Spring.Pos2BuildPos(-cmdID, pos[1], pos[2], pos[3])
	local bestPos = GetClosestSpot(bx, bz)
	if not bestPos then
		clearShape()
		return
	end

	local bface = Spring.GetBuildFacing()
	if geoSelected then
		if mb then
			mousePressed = true
		elseif mousePressed then
			mousePressed = false
			geoSelected = false
			if not placedDirectly then
				local alt, ctrl, meta, shift = Spring.GetModKeyState()
				local opt = {}
				if alt then opt[#opt + 1] = "alt" end
				if ctrl then opt[#opt + 1] = "ctrl" end
				if meta then opt[#opt + 1] = "meta" end
				if shift then opt[#opt + 1] = "shift" end
				Spring.GiveOrder(cmdID, {bestPos[1], bestPos[2], bestPos[3], bface}, opt)
				if not shift then
					Spring.SetActiveCommand(0)
				end
			end
		end
	end
	placedDirectly = false

	-- Draw line
	gl.DepthTest(false)
	gl.LineWidth(1.49)
    gl.Color(1, 1, 0, 0.45)
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
	if isGeo[-cmdID] then
		placedDirectly = true
	end
end
