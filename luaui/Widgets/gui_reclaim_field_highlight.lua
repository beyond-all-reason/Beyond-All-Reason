local widget = widget ---@type Widget

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


-- Localized functions for performance
local tableSort = table.sort

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

--Metal value font
local numberColor = {1, 1, 1, 0.75}
local fontSizeMin = 30
local fontSizeMax = 180

--Field color
local reclaimColor = {0, 0, 0, 0.16}
local reclaimEdgeColor = {1, 1, 1, 0.18}

--Update rate, in seconds
local checkFrequency = 1/2

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Speedups

local insert = table.insert
local remove = table.remove

local abs = math.abs
local floor = math.floor
local min = math.min
local max = math.max
local clamp = math.clamp
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
local spGetFeatureVelocity = Spring.GetFeatureVelocity
local spGetGroundHeight = Spring.GetGroundHeight
local spIsGUIHidden = Spring.IsGUIHidden
local spTraceScreenRay = Spring.TraceScreenRay
local spGetActiveCommand = Spring.GetActiveCommand
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
local epsilonSq = epsilon*epsilon
local minFeatureMetal = 9 -- armflea reclaim value, probably
if UnitDefNames.armflea then
	local small = FeatureDefNames[UnitDefNames.armflea.corpse]
	minFeatureMetal = small and small.metal or minFeatureMetal
end
checkFrequency = math.round(checkFrequency * Game.gameSpeed)

local minTextAreaLength = (epsilon / 2 + fontSizeMin) / 2
local areaTextMin = 3000
local areaTextRange = (1.75 * minTextAreaLength * (fontSizeMax / fontSizeMin)) ^ 2 - areaTextMin

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
	if unitDef.canReclaim and not unitDef.isBuilding then
		canReclaim[unitDefID] = true
	end
end

-- Information tables
local knownFeatures
local flyingFeatures
local featureClusters
local featureConvexHulls
local featureNeighborsMatrix
local opticsObject

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Priority Queue

local PriorityQueue = {}
do
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

local processCluster
do
	local function getReclaimTotal(cluster, points)
		local metal = 0
		for j = 1, #points do
			metal = metal + points[j].metal
		end
		cluster.metal = metal
		cluster.text = string.formatSI(metal)
	end

	local function getClusterDimensions(cluster, points)
		local xmin, xmax, zmin, zmax = mathHuge, -mathHuge, mathHuge, -mathHuge
		local cx, cz = 0, 0
		for j = 1, #points do
			local x, z = points[j].x, points[j].z
			xmin = min(xmin, x)
			xmax = max(xmax, x)
			zmin = min(zmin, z)
			zmax = max(zmax, z)
			cx, cz = cx + x, cz + z
		end

		-- The average of vertices is a very unstable estimate of the centroid.
		-- The bounds change slowly, so we can use them to stabilize our guess:
		cx, cz = cx / #points, cz / #points
		cx, cz = (xmin + 2 * cx + xmax) / 4, (zmin + 2 * cz + zmax) / 4
		cluster.center = { x = cx, y = max(0, spGetGroundHeight(cx, cz)) + 2, z = cz }

		-- I keep shuffling this around to different places. Just do it here:
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
		cluster.xmin = xmin
		cluster.xmax = xmax
		cluster.zmin = zmin
		cluster.zmax = zmax
		cluster.dx = dx
		cluster.dz = dz
	end

	local function sortMonotonic(a, b)
		return (a.x > b.x) or (a.x == b.x and a.z > b.z)
	end

	---Filter a set of points to give a much smaller set of candidates for constructing
	---the convex hull of the entire set. This can save time on building the hull.
	---Credit: mindthenerd.blogspot.ru/2012/05/fastest-convex-hull-algorithm-ever.html
	---Also: www-cgrl.cs.mcgill.ca/~godfried/publications/fast.convex.hull.algorithm.pdf
	local function convexSetConditioning(points)
		-- tableSort(points, sortMonotonic) -- Moved to previous, shared step.
		local remaining = { points[1] }
		local x, z = points[1].x, points[1].z

		-- (1) Cover all points by expanding a quadrilateral to follow these rules:
		local ax,  az,  a_xzs_max  =  x,  z,  x - z  -- Choose point A to maximize x - z.
		local bx,  bz,  b_xza_max  =  x,  z,  x + z  -- Choose point B to maximize x + z.
		local cx,  cz,  c_xzs_min  =  x,  z,  x - z  -- Choose point C to minimize x - z.
		local dx,  dz,  d_xza_min  =  x,  z,  x + z  -- Choose point D to minimize x + z.

		-- (2) Find the XZ-aligned rectangle inscribed in that quadrilateral:
		local rxmin, rxmax = x, x  -- Rx_min = max(Cx, Dx); Rx_max = min(Ax, Bx).
		local rzmin, rzmax = z, z  -- Rz_min = max(Az, Dz); Rz_max = min(Bz, Cz).

		-- (3) The algorithm performs two passes, with the first covering the full set.
		for ii = 2, #points do
			local point = points[ii]
			local x, z = point.x, point.z
			if x <= rxmin or x >= rxmax or z <= rzmin or z >= rzmax then
				-- Keep points that fall outside the inscribed rectangle.
				remaining[#remaining+1] = point

				-- Update points A, B, C, D and the inner rectangle bounds.
				local xzs = x - z
				local xza = x + z
				if xzs > a_xzs_max then
					a_xzs_max = xzs
					ax, az = x, z
					if x > rxmax and x < bx then
						rxmax = x
					end
					if z < rzmin and z > dz then
						rzmin = z
					end
				end
				if xza > b_xza_max then
					b_xza_max = xza
					bx, bz = x, z
					if x > rxmax and x < ax then
						rxmax = x
					end
					if z > rzmax and z < cz then
						rzmax = z
					end
				end
				if xzs < c_xzs_min then
					c_xzs_min = xzs
					cx, cz = x, z
					if x < rxmin and x > dx then
						rxmin = x
					end
					if z > rzmax and z < bz then
						rzmax = z
					end
				end
				if xza < d_xza_min then
					d_xza_min = xza
					dx, dz = x, z
					if x < rxmin and x > cx then
						rxmin = x
					end
					if z < rzmin and z > az then
						rzmin = z
					end
				end
			end
		end

		-- (4) The second pass removes remaining points that are inside the inner rectangle.
		for jj = #remaining - 1, 1, -1 do
			local x, z = remaining[jj].x, remaining[jj].z
			if x > rxmin and x < rxmax and z > rzmin and z < rzmax then
				remove(remaining, jj)
			end
		end

		return remaining
	end

	--- MONOTONE CHAIN
	-- https://gist.githubusercontent.com/sixFingers/ee5c1dce72206edc5a42b3246a52ce2e/raw/b2d51e5236668e5408d24b982eec9c339dc94065/Lua%2520Convex%2520Hull

	-- Andrew's monotone chain convex hull algorithm
	-- https://en.wikibooks.org/wiki/Algorithm_Implementation/Geometry/Convex_hull/Monotone_chain
	-- Direct port from Javascript version

	local MonotoneChain
	do
		local function cross(p, q, r)
			return (q.z - p.z) * (r.x - q.x) -
			       (q.x - p.x) * (r.z - q.z)
		end

		MonotoneChain = function (points)
			local numPoints = #points
			if numPoints < 3 then return end
			-- tableSort(points, sortMonotonic) -- Moved to previous, shared step.

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

	local function BoundingBox(cluster, points)
		local ymax = points[1].y
		if #points == 2 then
			ymax = max(ymax, points[2].y)
		end

		local convexHull = {
			{ x = cluster.xmin, y = ymax, z = cluster.zmin },
			{ x = cluster.xmax, y = ymax, z = cluster.zmin },
			{ x = cluster.xmax, y = ymax, z = cluster.zmax },
			{ x = cluster.xmin, y = ymax, z = cluster.zmax },
		}

		local hullArea = cluster.dx * cluster.dz

		return convexHull, hullArea
	end

	local function polygonArea(points)
		if #points < 3 then return 0 end
		local totalArea = 0
		for ii = 1, #points - 1 do
			totalArea = totalArea + points[ii].x * points[ii+1].z - points[ii].z * points[ii+1].x
		end
		return 0.5 * abs(totalArea + points[#points].x * points[1].z - points[#points].z * points[1].x)
	end

	processCluster = function (cluster, clusterID, points)
		getReclaimTotal(cluster, points)

		local convexHull, hullArea
		if #points >= 3 then
			tableSort(points, sortMonotonic) -- Moved to avoid repeating the sort.
			if #points >= 60 then
				convexHull = MonotoneChain(convexSetConditioning(points))
			else
				convexHull = MonotoneChain(points)
			end
			hullArea = polygonArea(convexHull)
			getClusterDimensions(cluster, convexHull)
		else
			hullArea = 0
			getClusterDimensions(cluster, points)
		end

		-- Replace lines and sets of one or two with a bounding box.
		if hullArea < areaTextMin then
			convexHull, hullArea = BoundingBox(cluster, points)
		end

		featureConvexHulls[clusterID] = convexHull

		cluster.area = hullArea
		local areaSize = clamp((hullArea - 2 * areaTextMin) / areaTextRange, 0, 1)
		cluster.font = fontSizeMin + (fontSizeMax - fontSizeMin) * areaSize
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Clustering method

local Optics = {}
do
	local unprocessed -- Intermediate table for processing points

	---Get ready for a clustering run
	local function Setup()
		featureClusters = {}
		featureConvexHulls = {}
		unprocessed = {}
		for fid, feature in pairs(knownFeatures) do
			unprocessed[fid] = true
		end
	end

	---Update the priority queue to contain the list of neighbors.
	local function Update(neighbors, point, seedsPQ)
		for fid, distSq in pairs(neighbors) do
			if unprocessed[fid] == true then
				unprocessed[fid] = nil
				local np = knownFeatures[fid]
				seedsPQ:push({ np.rd, np })
			end
		end
	end

	---Runs a both simplified and augmented OPTICS sequencing step.
	---This is combined with the previous Clusterize fn step to produce clusters.
	---It also leaves no point un-clusterized; solo points form their own cluster.
	---This has allowed all processing to occur in one place and in a single pass.
	local function Run()
		Setup()

		local clusterID = #featureClusters
		local featureID = next(unprocessed)
		while featureID do
			-- Start a new cluster.
			local point = knownFeatures[featureID]
			local members = { point }
			local cluster = { members = members }
			clusterID = clusterID + 1
			featureClusters[clusterID] = cluster

			-- Process visited points, like so.
			point.cid = clusterID
			unprocessed[featureID] = nil

			-- Process immediate neighbors.
			local neighbors = featureNeighborsMatrix[featureID]
			local seedsPQ = PriorityQueue.new()
			Update(neighbors, point, seedsPQ)

			-- Spread through next-neighbors by moving to the nearest point.
			local neighbor = seedsPQ:pop()
			while neighbor do
				local point = neighbor[2] -- [1] = priority, [2] = point
				members[#members+1] = point
				point.cid = clusterID

				local nextNeighbors = featureNeighborsMatrix[point.fid]
				Update(nextNeighbors, point, seedsPQ)
				neighbor = seedsPQ:pop()
			end

			featureID = next(unprocessed)
		end

		-- Post-process each cluster.
		for cid = 1, clusterID do
			local cluster = featureClusters[cid]
			processCluster(cluster, cid, cluster.members)
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

local function RemoveFeature(featureID)
	local neighbors = featureNeighborsMatrix[featureID]
	local epsilonSq = epsilonSq
	for nid, distSq in pairs(neighbors) do
		-- Update the reachability of neighbors linked through this point.
		local neighbor = knownFeatures[nid]
		if neighbor.rd == distSq then
			local nextNeighbors = featureNeighborsMatrix[nid]
			nextNeighbors[featureID] = nil
			local reachDistSq = mathHuge
			for fid2, distSq2 in pairs(nextNeighbors) do
				if distSq2 < reachDistSq then
					reachDistSq = distSq2
				end
			end
			neighbor.rd = (reachDistSq <= epsilonSq and reachDistSq) or nil
		else
			featureNeighborsMatrix[nid][featureID] = nil
		end
	end
	featureNeighborsMatrix[featureID] = nil
	knownFeatures[featureID] = nil
end

local function UpdateFeatureReclaim()
	local dirty, removed = {}, false
	for fid, fInfo in pairs(knownFeatures) do
		local metal = spGetFeatureResources(fid)
		if metal >= minFeatureMetal then
			if fInfo.metal ~= metal then
				if fInfo.cid then
					dirty[fInfo.cid] = true
					local thisCluster = featureClusters[fInfo.cid]
					thisCluster.metal = thisCluster.metal - fInfo.metal + metal
				end
				fInfo.metal = metal
			end
		else
			RemoveFeature(fid)
			removed = true
		end
	end

	if removed then
		clusterizingNeeded = true
	elseif next(dirty) then
		redrawingNeeded = true
		for ii in pairs(dirty) do
			featureClusters[ii].text = string.formatSI(featureClusters[ii].metal)
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
			local _, _, _, cmdName = spGetActiveCommand()
			return (cmdName and cmdName == 'Reclaim')
		end
	end

	local showOptionFunctions = {
		--[[1]] always,
		--[[2]] onMapDrawMode,
		--[[3]] onSelectReclaimer,
		--[[4]] onSelectResurrector,
		--[[5]] onActiveCommand,
		--[[6]] widgetHandler.RemoveWidget,
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
local cameraScale = 1

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
	local cameraFacing = math.atan2(-camUpVector[1], -camUpVector[3]) * (180 / math.pi)
	for clusterID = 1, #featureClusters do
		local center = featureClusters[clusterID].center

		glPushMatrix()

		glTranslate(center.x, center.y, center.z)
		glRotate(-90, 1, 0, 0)
		glRotate(cameraFacing, 0, 0, 1)

		glColor(numberColor)
		glText(featureClusters[clusterID].text, 0, 0, featureClusters[clusterID].font, "cv") --cvo for outline

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
	flyingFeatures = {}
	featureNeighborsMatrix = {}
	featureClusters = {}
	featureConvexHulls = {}
	opticsObject = Optics.new()

	for _, featureID in ipairs(Spring.GetAllFeatures()) do
		widget:FeatureCreated(featureID)
	end

	camUpVector = spGetCameraVectors().up
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
			local cameraDist = min(64000000, (cx-w[1])^2 + (cy-w[2])^2 + (cz-w[3])^2)
			cameraScale = sqrt(sqrt(cameraDist) / 600) --number is an "optimal" view distance
		else
			cameraScale = 1.0
		end
	end
end

function widget:GameFrame(frame)
	if drawEnabled == false or frame % checkFrequency ~= 0 then
		return
	end

	local featuresAdded = false
	for featureID, fInfo in pairs(flyingFeatures) do
		local _,_,_, vw = spGetFeatureVelocity(featureID)
		if vw <= 1e-3 then
			flyingFeatures[featureID] = nil
			local x, y, z = spGetFeaturePosition(featureID)
			fInfo.x, fInfo.y, fInfo.z = x, y, z
			local M = featureNeighborsMatrix
			local M_newFeature = {}
			local reachDistSq, epsilonSq = mathHuge, epsilonSq
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
			if reachDistSq < epsilonSq then
				fInfo.rd = reachDistSq
			end
			knownFeatures[featureID] = fInfo
			featuresAdded = true
		end
	end

	if featuresAdded or clusterizingNeeded then
		for fid, fInfo in pairs(knownFeatures) do
			local metal = spGetFeatureResources(fid)
			if metal < minFeatureMetal then
				RemoveFeature(fid)
			end
		end
		ClusterizeFeatures()
	else
		UpdateFeatureReclaim()
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
	end

	-- Text is always redrawn to rotate it facing the camera.
	local camUpVectorNew = spGetCameraVectors().up
	if redrawingNeeded or camUpVector[1] ~= camUpVectorNew[1] or camUpVector[3] ~= camUpVector[3] then
		camUpVector = camUpVectorNew
		if drawFeatureClusterTextList ~= nil then
			glDeleteList(drawFeatureClusterTextList)
			drawFeatureClusterTextList = nil
		end
		drawFeatureClusterTextList = glCreateList(DrawFeatureClusterText)
	end

	redrawingNeeded = false
end

function widget:FeatureCreated(featureID, allyTeamID)
	local metal = spGetFeatureResources(featureID)
	if metal >= minFeatureMetal then
		local x, y, z = spGetFeaturePosition(featureID)
		local feature = {
			fid   = featureID,
			metal = metal,
			x     = x,
			y     = max(0, y),
			z     = z,
		}

		-- To deal with e.g. raptor eggs spawning at altitude ~20:
		if y > 0 then
			local elevation = spGetGroundHeight(x, z)
			if elevation > 0 and y > elevation + 2 then
				flyingFeatures[featureID] = feature
				return -- Delay clusterizing until stationary.
			end
		end

		-- Assuming the feature's motion is highly likely negligible:
		local M = featureNeighborsMatrix
		local M_newFeature = {}
		local reachDistSq, epsilonSq = mathHuge, epsilonSq
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
		if reachDistSq < epsilonSq then
			feature.rd = reachDistSq
		end
		knownFeatures[featureID] = feature
		clusterizingNeeded = true
	end
end

function widget:FeatureDestroyed(featureID, allyTeamID)
	if knownFeatures[featureID] ~= nil then
		RemoveFeature(featureID)
		clusterizingNeeded = true
	else
		flyingFeatures[featureID] = nil
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

	if drawFeatureClusterTextList ~= nil then
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
	if drawFeatureConvexHullSolidList ~= nil then
		glColor(reclaimColor)
		glCallList(drawFeatureConvexHullSolidList)
	end

	if drawFeatureConvexHullEdgeList ~= nil then
		glLineWidth(6.0 / cameraScale)
		glColor(reclaimEdgeColor)
		glCallList(drawFeatureConvexHullEdgeList)
		glLineWidth(1.0)
	end

	glDepthTest(true)
end
