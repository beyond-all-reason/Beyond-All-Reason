function widget:GetInfo()
	return {
		name      = "Reclaim Field Highlight",
		desc      = "Highlights clusters of reclaimable material",
		author    = "ivand, refactored by esainane, edited for BAR by Lexon and efrec",
		date      = "2024",
		license   = "public",
		layer     = 1000,
		enabled   = true
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Options

--[[----------------------------------------------------------------------------
	When to show reclaim highlight?
	In addition to options below you can bind "reclaim_highlight" action to a key
	and show reclaim when that key is pressed
------------------------------------------------------------------------------]]
local showOption = 3
--[[
	From settings (gui_options.lua)
	1 - always enabled
	2 - resource view only
	3 - reclaimer selected
	4 - resbot selected
	5 - reclaim order active
	6 - disabled
]]

--If true energy reclaim will be converted into metal (1 / 70) and added to the reclaim field value
-- local includeEnergy = false

--Metal value font
local numberColor = {1, 1, 1, 0.75}
local fontSizeMin = 30
local fontSizeMax = 200
local fontScaling = 0.45

--Field color
local reclaimColor = {0, 0, 0, 0.16}
local reclaimEdgeColor = {1, 1, 1, 0.18}

--Update rate, in seconds
local checkFrequency = 1/3

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Speedups

local insert = table.insert
local remove = table.remove

local abs = math.abs
local floor = math.floor
local min = math.min
local max = math.max
local sqrt = math.sqrt
local mathHuge = math.huge

local glBeginEnd = gl.BeginEnd
local glBlending = gl.Blending
local glCallList = gl.CallList
local glColor = gl.Color
local glCreateList = gl.CreateList
local glDeleteList = gl.DeleteList
local glDepthTest = gl.DepthTest
local glLineWidth = gl.LineWidth
local glPolygonMode = gl.PolygonMode
local glPopMatrix = gl.PopMatrix
local glPushMatrix = gl.PushMatrix
local glRotate = gl.Rotate
local glText = gl.Text
local glTranslate = gl.Translate
local glVertex = gl.Vertex

local spGetCameraPosition = Spring.GetCameraPosition
local spGetFeaturePosition = Spring.GetFeaturePosition
local spGetFeatureResources = Spring.GetFeatureResources
local spIsGUIHidden = Spring.IsGUIHidden
local spTraceScreenRay = Spring.TraceScreenRay
local spGetActiveCommand = Spring.GetActiveCommand
local spGetActiveCmdDesc = Spring.GetActiveCmdDesc
local spGetMapDrawMode = Spring.GetMapDrawMode
local spGetUnitDefID = Spring.GetUnitDefID
local spGetCameraVectors = Spring.GetCameraVectors

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Data

local screenx, screeny
local clusterizingNeeded = false
local redrawingNeeded = false

local epsilon = 300
local epsilonSq = epsilon^2
local minFeatureMetal = 9 -- armflea reclaim value
if UnitDefNames.armflea then
	local tragic = FeatureDefNames[UnitDefNames.armflea.corpse]
	minFeatureMetal = max(minFeatureMetal, tragic.metal or 0)
end
local minTextAreaLength = 100
checkFrequency = math.round(checkFrequency * Game.gameSpeed)

local drawEnabled = false
local actionActive = false
local reclaimerSelected = false
local resBotSelected = false

local canReclaim = {}
local canResurrect = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.canResurrect then
		canResurrect[unitDefID] = true
	end
	if unitDef.isBuilder and not unitDef.isBuilding then
		canReclaim[unitDefID] = true
	end
end

-- Information tables
local knownFeatures
local featureClusters
local featureConvexHulls
local featureNeighborsMatrix
local opticsObject

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Priority Queue

local PriorityQueue = {}
do
	-- local function less(a, b) return a[1] < b[1] end

	local function push(self, pair)
		insert(self, pair)
		local n = #self
		local p = floor(n * 0.5)
		while n > 1 and self[n][1] < self[p][1] do
			self[n], self[p] = self[p], self[n]
			n = p
			p = floor(n * 0.5)
		end
	end

	local function pop(self)
		local el = remove(self, 1)
		if #self > 1 then
			local root = 1
			local size = #self
			local aBool, bBool, cBool
			if size > 1 then
				local child = 2*root
				while child <= size do
					aBool = self[root][1] < self[child][1]
					if child+1 <= size then
						bBool =  self[root][1] < self[child+1][1]
						cBool = self[child][1] < self[child+1][1]
					else
						bBool = true
						cBool = true
					end
					if aBool == true and bBool == true then
						break;
					elseif cBool == true then
						self[root], self[child] = self[child], self[root]
						root = child
					else
						self[root], self[child+1] = self[child+1], self[root]
						root = child+1
					end
					child = 2*root
				end
			end
		end
		return el
	end

	local function peek(self)
		return self[1]
	end

	function PriorityQueue.new()
		local pq = setmetatable({}, {
			__index = {
				push   = push,
				pop    = pop,
				peek   = peek,
			},
		})
		return pq
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Cluster post-processing
-- Convex hull outlines and text areas

local function GetClusterStats(cluster, members)
	local metal = 0
	for j = 1, #members do
		local feature = members[j]
		metal = metal + feature.metal
	end
	cluster.metal = metal
end

local GetConvexHull
do
	--- MONOTONE CHAIN
	-- https://gist.githubusercontent.com/sixFingers/ee5c1dce72206edc5a42b3246a52ce2e/raw/b2d51e5236668e5408d24b982eec9c339dc94065/Lua%2520Convex%2520Hull

	-- Andrew's monotone chain convex hull algorithm
	-- https://en.wikibooks.org/wiki/Algorithm_Implementation/Geometry/Convex_hull/Monotone_chain
	-- Direct port from Javascript version

	local MonotoneChain
	do
		local function sortMonotonic(a, b)
			return (a.x > b.x) or (a.x == b.x and a.z > b.z)
		end

		local function cross(p, q, r)
			return (q.z - p.z) * (r.x - q.x) -
				(q.x - p.x) * (r.z - q.z)
		end

		MonotoneChain = function (points)
			local numPoints = #points
			if numPoints < 3 then return end
			table.sort(points, sortMonotonic)

			local lower = {}
			for i = 1, numPoints do
				local point = points[i]
				while (#lower >= 2 and cross(lower[#lower - 1], lower[#lower], point) <= 0) do
					remove(lower)
				end
				insert(lower, point)
			end

			local upper = {}
			for i = numPoints, 1, -1 do
				local point = points[i]
				while (#upper >= 2 and cross(upper[#upper - 1], upper[#upper], point) <= 0) do
					remove(upper)
				end
				insert(upper, point)
			end

			remove(upper)
			remove(lower)
			for i = 1, #lower do
				insert(upper, lower[i])
			end
			return upper
		end
	end

	local function pointArea(points)
		local totalArea = 0
		-- Determinant area, triangle form
		local x1, z1 = points[1].x, points[1].z
		local x2, z2
		local x3, z3 = points[2].x, points[2].z
		for i = 2, #points - 1 do
			x2 = x3
			z2 = z3
			x3 = points[i + 1].x
			z3 = points[i + 1].z
			totalArea = totalArea + 0.5 * abs(x1 * (z2 - z3) + x2 * (z3 - z1) + x3 * (z1 - z2))
		end
		return totalArea
	end

	GetConvexHull = function (cluster, clusterID, members)
		-- Pre-process the input points.
		local candidatePoints

		if #members < 3 then
			candidatePoints = members -- We just make a bounding box around the points.
		else
			-- We may need to remove points from the set, so make a copy.
			candidatePoints = {}
			for ii = 1, #members do
				candidatePoints[ii] = members[ii]
			end

			if #candidatePoints > 30 then
				-- With uniformly random data, this should prune down to around 20% the original set.
				-- Pruning is O(n) and monotone chain is about O(nlogn) so this is likely worthwhile.
				-- Credit to mindthenerd.blogspot.ru/2012/05/fastest-convex-hull-algorithm-ever.html
				-- Also www-cgrl.cs.mcgill.ca/~godfried/publications/fast.convex.hull.algorithm.pdf
				local hullPoints = {}

				local feature = candidatePoints[1]
				local x, z = feature.x, feature.z
	
				-- (1) Create a 45deg-aligned quadrilateral by expanding to cover each point, one by one.
				local ax, az, a_xzs_max = x, z, x - z -- Choose A to maximize x - z.
				local bx, bz, b_xza_max = x, z, x + z -- Choose B to maximize x + z.
				local cx, cz, c_xzs_min = x, z, x - z -- Choose C to minimize x - z.
				local dx, dz, d_xza_min = x, z, x + z -- Choose D to minimize x + z.
	
				-- (2) Find the 90deg-aligned rectangle inscribed in that quadrilateral.
				-- This isn't a maximal-area rectangle; it's the fastest to construct.
				local rxmin, rxmax = x, x -- R_x_min = max(cx, dx); R_x_max = min(ax, bx).
				local rzmin, rzmax = z, z -- R_z_min = max(az, dz); R_z_max = min(bz, cz).
	
				-- The algorithm performs a double-pass, starting on the full set.
				-- The first pass gradually expands the quadrilateral while pruning points.
				for ii = 2, #candidatePoints do
					local feature = candidatePoints[ii]
					local x, z = feature.x, feature.z
					-- (3) Add points to the result set that fall outside the inscribed rectangle.
					if x < rxmin or x > rxmax or z < rzmin or z > rzmax then
						hullPoints[#hullPoints+1] = feature
						-- Spring.MarkerAddPoint(x, 0, z)
						-- (4) Update A, B, C, D and the rectangle inscribed by them.
						-- A point could satisfy up to two of these conditionals;
						-- the greatest increase probably should be taken. Maybe later.
						local xzs = x - z
						local xza = x + z
						if     xzs >= a_xzs_max then -- update A
							a_xzs_max = xzs
							ax, az = x, z
							if x > rxmax then
								rxmax = min(x, bx)
							end
							if z < rzmin then
								rzmin = max(z, dz)
							end
						elseif xza >= b_xza_max then -- update B
							b_xza_max = xza
							bx, bz = x, z
							if x > rxmax then
								rxmax = min(x, ax)
							end
							if z > rzmax then
								rzmax = min(z, cz)
							end
						elseif xzs <= c_xzs_min then -- update C
							c_xzs_min = xzs
							cx, cz = x, z
							if x < rxmin then
								rxmin = max(x, dx)
							end
							if z > rzmax then
								rzmax = min(z, bz)
							end
						elseif xza <= d_xza_min then -- update D
							d_xza_min = xza
							dx, dz = x, z
							if x < rxmin then
								rxmin = max(x, cx)
							end
							if z < rzmin then
								rzmin = max(z, az)
							end
						end
					end
				end
	
				-- (5) Remove all points that fall within the final rectangle.
				for jj = #hullPoints - 1, 1, -1 do
					local feature = hullPoints[jj]
					local x, z = feature.x, feature.z
					if (x > rxmin and x < rxmax) and (z > rzmin and z < rzmax) then
						remove(hullPoints, jj)
					end
				end

				-- Replace the unprocessed candidates set with the pruned set.
				candidatePoints = hullPoints
			end
		end

		-- Create the convex hull around the set of candidates.
		local convexHull

		local hullArea = (#candidatePoints >= 3 and pointArea(candidatePoints)) or 0
		if hullArea >= 3000 then
			convexHull = MonotoneChain(candidatePoints)
		else
			local xmin, xmax, zmin, zmax = mathHuge, -mathHuge, mathHuge, -mathHuge
			for j = 1, #candidatePoints do
				local feature = candidatePoints[j]
				local x = feature.x
				local z = feature.z
				xmin = min(xmin, x)
				xmax = max(xmax, x)
				zmin = min(zmin, z)
				zmax = max(zmax, z)
			end

			local dx, dz = xmax - xmin, zmax - zmin

			if dx < minTextAreaLength then
				xmin = xmin - (minTextAreaLength - dx) / 2
				xmax = xmax + (minTextAreaLength - dx) / 2
				dx = dx + minTextAreaLength
			end

			if dz < minTextAreaLength then
				zmin = zmin - (minTextAreaLength - dz) / 2
				zmax = zmax + (minTextAreaLength - dz) / 2
				dz = dz + minTextAreaLength
			end

			hullArea = dx * dz

			local ymax = candidatePoints[1].y
			if #candidatePoints == 2 then
				ymax = max(ymax, candidatePoints[2].y)
			end

			convexHull = {
				{x = xmin, y = ymax, z = zmin},
				{x = xmax, y = ymax, z = zmin},
				{x = xmax, y = ymax, z = zmax},
				{x = xmin, y = ymax, z = zmax},
			}
		end

		local cx, cz, cy = 0, 0, 0
		for i = 1, #convexHull do
			local convexHullPoint = convexHull[i]
			cx = cx + convexHullPoint.x
			cz = cz + convexHullPoint.z
			cy = max(cy, convexHullPoint.y)
		end

		convexHull.area = hullArea
		convexHull.center = { x = cx/#convexHull, z = cz/#convexHull, y = cy + 1 }

		featureConvexHulls[clusterID] = convexHull
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- OPTICS clustering
-- Note @efrec I'm ngl to you this wasn't OPTICS before and very much is not now.
-- This should have been a total rewrite to reduce confusion over shared details.

local Optics = {}
do
	local unprocessed -- Intermediate table for processing points

	---Get ready for a clustering run
	local function Setup()
		-- Fully reset cluster processing.
		unprocessed = {}
		for fid, feature in pairs(knownFeatures) do
			unprocessed[fid] = true
			local reachDistSq = feature.rd
			reachDistSq = (reachDistSq ~= nil and reachDistSq <= epsilonSq and reachDistSq) or nil
			feature.rd = reachDistSq
		end
		convexHullTable = {}
	end

	---Distance from a point to its nearest neighbor.
	local function Reachability(point, neighbors)
		if point.rd ~= nil then
			return point.rd
		end
		-- This function was changed from its generic implementation because
		-- the special case where minPoints == 2 has a much faster evaluation.
		-- Note also that we have to guarantee the epsilon neighbors matrix.
		local reachDistSq = mathHuge
		for fid, distSq in pairs(neighbors) do
			if unprocessed[fid] == nil and distSq < reachDistSq then -- ? not sure about unproc here
				reachDistSq = distSq
			end
		end
		-- Fine to double-check epsilon here since we remove mathHuge anyway.
		if reachDistSq <= epsilonSq then
			point.rd = reachDistSq
			return reachDistSq
		end
	end

	---Update seeds if a smaller reachability distance is found.
	local function Update(neighbors, point, seedsPQ)
		-- We maintain the epsilon neighborhoods during callins, now.
		-- local M_point = featureNeighborsMatrix[point.fid]
		for fid, distSq in pairs(neighbors) do
			-- Bugged: Something is causing points to re-process.
			if unprocessed[fid] == true then
				unprocessed[fid] = nil -- Bugged: So I'm doing this.
				local np = knownFeatures[fid]
				seedsPQ:push({ np.rd, np })
			end
		end
	end

	---Run the OPTICS sequencing step (now identical to a single-link chain algo).
	---This is combined with the previous Clusterize fn step to produce clusters.
	---It also leaves no point un-clusterized; solo points form their own cluster.
	---This has allowed all processing to occur in one place and in a single pass.
	local function Run()
		Setup()

		featureClusters = {}
		local clusterID = 0

		local fid = next(unprocessed)
		while fid ~= nil do
			-- Start a new cluster.
			local point = knownFeatures[fid]
			local members = { point }
			local cluster = { members = members }
			featureClusters[clusterID] = cluster
			clusterID = clusterID + 1

			-- Process visited points, like so.
			point.cid = clusterID
			unprocessed[fid] = nil

			-- Process immediate neighbors.
			local neighbors = featureNeighborsMatrix[fid]
			if neighbors ~= nil and Reachability(point, neighbors) ~= nil then
				local seedsPQ = PriorityQueue.new()
				Update(neighbors, point, seedsPQ)

				-- Continue to spread through neighbors
				-- by moving to the next nearest point.
				local neighbor = seedsPQ:pop()
				while neighbor ~= nil do
					local point = neighbor[2] -- [1] = priority, [2] = point
					members[#members+1] = point

					point.cid = clusterID
					unprocessed[point.fid] = nil

					local nextNeighbors = featureNeighborsMatrix[point.fid]
					if nextNeighbors ~= nil and Reachability(point, nextNeighbors) ~= nil then
						Update(nextNeighbors, point, seedsPQ)
					end
					neighbor = seedsPQ:pop()
				end
			end

			fid = next(unprocessed)
		end

		for ii = 1, clusterID do
			-- Post-process each cluster.
			local cluster = featureClusters[ii]
			GetClusterStats(cluster, cluster.members)
			GetConvexHull(cluster, ii, cluster.members)
		end
	end

	function Optics.new()
		local object = setmetatable({}, {
			__index = { Run = Run, }
		})
		return object
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Feature Tracking

local function UpdateFeatureReclaim()
	for fid, fInfo in pairs(knownFeatures) do
		local metal = spGetFeatureResources(fid)
		if metal >= minFeatureMetal then
			if fInfo.metal ~= metal then
				if fInfo.cid ~= nil then
					local thisCluster = featureClusters[fInfo.cid]
					thisCluster.metal = thisCluster.metal - fInfo.metal + metal
				end
				fInfo.metal = metal
			end
		else
			knownFeatures[fid] = nil
			clusterizingNeeded = true
		end
	end
end

local function ClusterizeFeatures()
	opticsObject:Run()
	clusterizingNeeded = false
	redrawingNeeded = true
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- State update

local function enableHighlight()
	actionActive = true
end

local function disableHighlight()
	actionActive = false
end

local UpdateDrawEnabled -- Uses the showOption setting to pick a function call.
do
	local function always()
		return true
	end

	local function onMapDrawMode()
		-- todo: would be nice to set only when it changes
		-- todo: eg widget:MapDrawModeChanged(newMode, oldMode)
		return actionActive == true or spGetMapDrawMode() == 'metal'
	end

	local function onSelectReclaimer()
		return actionActive == true or reclaimerSelected == true or onMapDrawMode() == true
	end

	local function onSelectResurrector()
		return actionActive == true or resBotSelected == true or onMapDrawMode() == true
	end

	local function onActiveCommand()
		if actionActive == true or onMapDrawMode() == true then
			return true
		else
			local currentCmd = spGetActiveCommand()
			if currentCmd ~= nil then
				local activeCmdDesc = spGetActiveCmdDesc(currentCmd)
				return activeCmdDesc ~= nil and activeCmdDesc.name == "Reclaim"
			else
				return false
			end
		end
	end

	local showOptionFunctions = {
		--[[1]] always,
		--[[2]] onMapDrawMode,
		--[[3]] onSelectReclaimer,
		--[[4]] onSelectResurrector,
		--[[5]] onActiveCommand,
		--[[6]] widgetHandler:RemoveWidget(),
	}

	UpdateDrawEnabled = function ()
		drawEnabled = showOptionFunctions[showOption]()
		return drawEnabled
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Drawing

local camUpVector
local cameraScale

local function DrawHullVertices(hull)
	for j = 1, #hull do
		glVertex(hull[j].x, hull[j].y, hull[j].z)
	end
end

local drawFeatureConvexHullSolidList
local function DrawFeatureConvexHullSolid()
	glPolygonMode(GL.FRONT_AND_BACK, GL.FILL)
	for i = 1, #featureConvexHulls do
		glBeginEnd(GL.TRIANGLE_FAN, DrawHullVertices, featureConvexHulls[i])
	end
end

local drawFeatureConvexHullEdgeList
local function DrawFeatureConvexHullEdge()
	glPolygonMode(GL.FRONT_AND_BACK, GL.LINE)
	for i = 1, #featureConvexHulls do
		glBeginEnd(GL.LINE_LOOP, DrawHullVertices, featureConvexHulls[i])
	end
	glPolygonMode(GL.FRONT_AND_BACK, GL.FILL)
end

local drawFeatureClusterTextList
local function DrawFeatureClusterText()
	for clusterID = 1, #featureClusters do
		glPushMatrix()

		local center = featureConvexHulls[clusterID].center

		glTranslate(center.x, center.y, center.z)
		glRotate(-90, 1, 0, 0)

		-- Rotate text based on camera rotation
		if camUpVector[1] ~= nil and camUpVector[3] ~= nil then
			local rotationAngle = math.atan2(-camUpVector[1], -camUpVector[3]) * (180 / math.pi)
			glRotate(rotationAngle, 0, 0, 1)
		end

		local fontSize = fontSizeMin * fontScaling
		local area = featureConvexHulls[clusterID].area
		fontSize = sqrt(area) * fontSize / minTextAreaLength
		fontSize = min(fontSize, fontSizeMax)
		fontSize = max(fontSize, fontSizeMin)

		local metalText = string.formatSI(featureClusters[clusterID].metal)

		glColor(numberColor)

		glText(metalText, 0, 0, fontSize, "cv") --cvo for outline

		glPopMatrix()
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Widget call-ins

function widget:Initialize()
	screenx, screeny = widgetHandler:GetViewSizes()

	widgetHandler:AddAction("reclaim_highlight", enableHighlight, nil, "p")
	widgetHandler:AddAction("reclaim_highlight", disableHighlight, nil, "r")

	WG['reclaimfieldhighlight'] = {}
	WG['reclaimfieldhighlight'].getShowOption = function()
		return showOption
	end
	WG['reclaimfieldhighlight'].setShowOption = function(value)
		showOption = value
	end

	-- Start/restart feature clustering.
	knownFeatures = {}
	featureNeighborsMatrix = {}
	featureClusters = {}
	featureConvexHulls = {}
	opticsObject = Optics.new()

	for _, featureID in ipairs(Spring.GetAllFeatures()) do
		widget:FeatureCreated(featureID)
	end
end

function widget:Shutdown()
	widgetHandler:RemoveAction("reclaim_highlight", "p")
	widgetHandler:RemoveAction("reclaim_highlight", "r")

	WG['reclaimfieldhighlight'] = nil -- todo: register/deregister, right?

	if drawFeatureConvexHullSolidList ~= nil then
		glDeleteList(drawFeatureConvexHullSolidList)
	end
	if drawFeatureConvexHullEdgeList ~= nil then
		glDeleteList(drawFeatureConvexHullEdgeList)
	end
	if drawFeatureClusterTextList ~= nil then
		glDeleteList(drawFeatureClusterTextList)
	end
end

function widget:GetConfigData(data)
    return { showOption = showOption }
end

function widget:SetConfigData(data)
	if data.showOption ~= nil then
		showOption = data.showOption
	end
end

function widget:Update(dt)
	if UpdateDrawEnabled() == true then
		local cx, cy, cz = spGetCameraPosition()
		local desc, w = spTraceScreenRay(screenx / 2, screeny / 2, true)
		if desc ~= nil then
			local cameraDist = min( 8000, sqrt( (cx-w[1])^2 + (cy-w[2])^2 + (cz-w[3])^2 ) )
			cameraScale = sqrt((cameraDist / 600)) --number is an "optimal" view distance
		else
			cameraScale = 1.0
		end
	end
end

function widget:GameFrame(frame)
	if drawEnabled == false or frame % checkFrequency ~= 0 then
		return
	end

	UpdateFeatureReclaim()

	if clusterizingNeeded == true then
		ClusterizeFeatures()
	end

	if redrawingNeeded == true then
		if drawFeatureConvexHullSolidList ~= nil then
			glDeleteList(drawFeatureConvexHullSolidList)
			drawFeatureConvexHullSolidList = nil
		end
		if drawFeatureConvexHullEdgeList ~= nil then
			glDeleteList(drawFeatureConvexHullEdgeList)
			drawFeatureConvexHullEdgeList = nil
		end
		drawFeatureConvexHullSolidList = glCreateList(DrawFeatureConvexHullSolid) -- number, list id
		drawFeatureConvexHullEdgeList = glCreateList(DrawFeatureConvexHullEdge)
		redrawingNeeded = false
	end

	-- Text is always redrawn to rotate it facing the camera.
	local camUpVectorCurrent = spGetCameraVectors().up
	if drawFeatureClusterTextList == nil or camUpVectorCurrent ~= camUpVector then
		camUpVector = camUpVectorCurrent
		if drawFeatureClusterTextList ~= nil then
			glDeleteList(drawFeatureClusterTextList)
			drawFeatureClusterTextList = nil
		end
		drawFeatureClusterTextList = glCreateList(DrawFeatureClusterText)
	end
end

function widget:FeatureCreated(featureID, allyTeamID)
	local metal = spGetFeatureResources(featureID)
	if metal >= minFeatureMetal then
		local x, y, z = spGetFeaturePosition(featureID)

		local M = featureNeighborsMatrix
		local M_newFeature = {}
		local reachDistSq = mathHuge
		for fid2, feat2 in pairs(knownFeatures) do
			local distSq = (x - feat2.x)^2 + (z - feat2.z)^2
			if distSq <= epsilonSq then
				M[fid2][featureID] = distSq
				M_newFeature[fid2] = distSq
				if distSq < reachDistSq then
					reachDistSq = distSq
				end
				if feat2.rd == nil or distSq < feat2.rd then
					feat2.rd = distSq
				end
			end
		end
		featureNeighborsMatrix[featureID] = M_newFeature

		knownFeatures[featureID] = {
			fid   = featureID,
			metal = metal,
			rd    = (reachDistSq < epsilonSq and reachDistSq) or nil,
			x     = x,
			y     = max(0, y), -- spGetGroundHeight(x, z) seems unneeded
			z     = z,
		}

		clusterizingNeeded = true
	end
end

function widget:FeatureDestroyed(featureID, allyTeamID)
	if knownFeatures[featureID] ~= nil then
		local neighbors = featureNeighborsMatrix[featureID]
		for fid, distSq in pairs(neighbors) do
			-- Update the reachability of neighbors linked through this point.
			local neighbor = knownFeatures[fid]
			if neighbor ~= nil and neighbor.rd == distSq then
				local nextNeighbors = featureNeighborsMatrix[fid]
				nextNeighbors[featureID] = nil
				local reachDistSq = mathHuge
				for fid2, distSq2 in pairs(nextNeighbors) do
					if distSq2 < reachDistSq then
						reachDistSq = distSq2
					end
				end
				neighbor.rd = (reachDistSq <= epsilonSq and reachDistSq) or nil
			else
				featureNeighborsMatrix[fid][featureID] = nil
			end
		end
		featureNeighborsMatrix[featureID] = nil
		knownFeatures[featureID] = nil
		clusterizingNeeded = true
	end
end

function widget:SelectionChanged(units)
	local uDefID
	reclaimerSelected = false
	resBotSelected = false
	for _, unitID in pairs(units) do
		uDefID = spGetUnitDefID(unitID)
		if canResurrect[uDefID] == true then
			resBotSelected = true
			reclaimerSelected = true
			return
		elseif canReclaim[uDefID] == true then
			reclaimerSelected = true
			return
		end
	end
end

function widget:ViewResize(viewSizeX, viewSizeY)
	screenx, screeny = widgetHandler:GetViewSizes()
end

function widget:DrawWorld()
	if drawEnabled == false or spIsGUIHidden() == true then
		return
	end

	glDepthTest(false)

	glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)

	if drawFeatureClusterTextList then
		glCallList(drawFeatureClusterTextList)
	end

	glDepthTest(true)
end

function widget:DrawWorldPreUnit()
	if drawEnabled == false or spIsGUIHidden() == true then
		return
	end

	glDepthTest(false)

	glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	if drawFeatureConvexHullSolidList then
		glColor(reclaimColor)
		glCallList(drawFeatureConvexHullSolidList)
	end

	if drawFeatureConvexHullEdgeList then
		glLineWidth(6.0 / cameraScale)
		glColor(reclaimEdgeColor)
		glCallList(drawFeatureConvexHullEdgeList)
		glLineWidth(1.0)
	end

	glDepthTest(true)
end
