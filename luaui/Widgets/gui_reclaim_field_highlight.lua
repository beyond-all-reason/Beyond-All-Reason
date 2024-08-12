
function widget:GetInfo()
	return {
		name      = "Reclaim Field Highlight",
		desc      = "Highlights clusters of reclaimable material",
		author    = "ivand, refactored by esainane, edited for BAR by Lexon",
		date      = "2022",
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

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Priority Queue

local abs = math.abs
local min = math.min
local max = math.max
local mathHuge = math.huge
local sqrt = math.sqrt

local insert = table.insert
local remove = table.remove

local PriorityQueue = {}

function PriorityQueue.new(cmp, initial)
	local pq = setmetatable({}, {
		__index = {
			cmp = cmp or function(a,b) return a < b end,
			push = function(self, v)
				insert(self, v)
				local next = #self
				local prev = (next-next%2)/2
				while next > 1 and cmp(self[next], self[prev]) do
					self[next], self[prev] = self[prev], self[next]
					next = prev
					prev = (next-next%2)/2
				end
			end,
			pop = function(self)
				if #self < 2 then
					return remove(self)
				end
				local root = 1
				local r = self[root]
				self[root] = remove(self)
				local size = #self
				if size > 1 then
					local child = 2*root
					while child <= size do
						local aBool =   cmp(self[root],self[child]);
						local bBool =   true;
						local cBool =   true;
						if child+1 <= size then
							bBool =   cmp( self[root],self[child+1]);
							cBool =   cmp(self[child], self[child+1]);
						end
						if aBool and bBool then
							break;
						elseif cBool then
							self[root], self[child] = self[child], self[root]
							root = child
						else
							self[root], self[child+1] = self[child+1], self[root]
							root = child+1
						end
						child = 2*root
					end
				end
				return r
			end,
			peek = function(self)
				return self[1]
			end,
		}
	})

	for _,el in ipairs(initial or {}) do
		pq:push(el)
	end

	return pq
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Optics

local function DistSq(p1, p2)
	return (p1.x - p2.x)^2 + (p1.z - p2.z)^2
end

local Optics = {}
function Optics.new(incPoints, incNeighborMatrix, incMinPoints)
	local object = setmetatable({}, {
		__index = {
			points = incPoints or {},
			neighborMatrix  = incNeighborMatrix or {},
			minPoints = incMinPoints,

			pointByfID = {},

			unprocessed = {},
			ordered = {},

			-- Get ready for a clustering run
			_Setup = function(self)
				local points, unprocessed = self.points, self.unprocessed

				for pIdx, point in pairs(points) do
					point.rd = nil
					point.cd = nil
					point.processed = nil
					unprocessed[point] = true
					self.pointByfID[point.fID] = point
				end
			end,

			-- Distance from a point to its nth neighbor (n = minPoints - 1)
			_CoreDistance = function(self, point, neighbors)
				if point.cd then
					return point.cd
				end

				if #neighbors >= self.minPoints - 1 then --(minPoints - 1) because point is also part of minPoints
					local distTable = {}
					for i = 1, #neighbors do
						local neighbor = neighbors[i]
						distTable[#distTable + 1] = DistSq(point, neighbor)
					end
					table.sort(distTable)

					point.cd = distTable[self.minPoints - 1] --return (minPoints - 1) farthest distance as CoreDistance
					return point.cd
				end
				return nil
			end,

			-- Neighbors for a point within eps
			_Neighbors = function(self, pIdx)
				local neighbors = {}

				for pIdx2, _ in pairs(self.neighborMatrix[pIdx]) do
					neighbors[#neighbors + 1] = self.pointByfID[pIdx2]
				end

				return neighbors
			end,

			-- Mark a point as processed
			_Processed = function(self, point)
				point.processed = true
				self.unprocessed[point] = nil

				local ordered = self.ordered
				ordered[#ordered + 1] = point
			end,

			-- Update seeds if a smaller reachability distance is found
			_Update = function(self, neighbors, point, seedsPQ)
				for ni = 1, #neighbors do
					local n = neighbors[ni]
					if not n.processed then
						--Spring.Echo("newRD")
						local newRd = max(point.cd, DistSq(point, n))
						if n.rd == nil then
							n.rd = newRd
							--this is a bug!!!!
							seedsPQ:push({newRd, n})
						elseif newRd < n.rd then
							--this is a bug!!!!
							n.rd = newRd
						end
					end
				end
				--return seedsPQ
			end,

			-- run the OPTICS algorithm
			Run = function(self)
				self:_Setup()

				local unprocessed = self.unprocessed
				while next(unprocessed) do
					local point = next(unprocessed)

					-- mark p as processed
					self:_Processed(point)

					-- find p's neighbors
					local neighbors = self:_Neighbors(point.fID)

					-- if p has a core_distance, i.e has min_cluster_size - 1 neighbors
					if self:_CoreDistance(point, neighbors) then
						--Spring.Echo("if self:_CoreDistance(point, neighbors) then")
						local seedsPQ = PriorityQueue.new( function(a,b) return a[1] < b[1] end )
						--seedsPQ = self:_Update(neighbors, point, seedsPQ)
						self:_Update(neighbors, point, seedsPQ)
						while seedsPQ:peek() do
							-- seeds.sort(key=lambda n: n.rd)
							local n = seedsPQ:pop()[2] --because we don't need priority

							-- mark n as processed
							self:_Processed(n)

							-- find n's neighbors
							local nNeighbors = self:_Neighbors(n.fID)

							-- if p has a core_distance...
							if self:_CoreDistance(n, nNeighbors) then
								--seedsPQ = self:_Update(nNeighbors, n, seedsPQ)
								self:_Update(nNeighbors, n, seedsPQ)
							end
						end
					end
				end

				-- when all points have been processed
				-- return the ordered list
				--Spring.Echo("#ordered", #self.ordered)
				return self.ordered
			end,

			-- ???
			Clusterize = function(self, clusterThreshold)
				local clusters = {}
				local separators = {}

				local clusterThresholdSq = clusterThreshold^2

				local ordered = self.ordered

				for i = 1, #ordered do
					local thisP = ordered[i]
					local thisRD = thisP.rd or mathHuge

					-- use an upper limit to separate the clusters

					if thisRD > clusterThresholdSq then
						separators[#separators + 1] = i
					end
				end
				separators[#separators + 1] = #ordered + 1

				for j = 1, #separators - 1 do
					local sepStart = separators[j]
					local sepEnd = separators[j + 1]
					--print(sepEnd, sepStart, sepEnd - sepStart, self.minPoints)
					if sepEnd - sepStart >= self.minPoints then
						local clPoints = {}
						for si = sepStart, sepEnd - 1 do
							clPoints[#clPoints + 1] = ordered[si].fID
						end

						clusters[#clusters + 1] = {}
						clusters[#clusters].members = clPoints
					end
				end
				return clusters
			end,
		}
	})
	return object
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Convex Hull

local function cross(p, q, r)
	return (q.z - p.z) * (r.x - q.x)
		 - (q.x - p.x) * (r.z - q.z)
end

--- JARVIS MARCH

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

	MonotoneChain = function (points)
		local numPoints = #points
		if numPoints < 3 then return end
	
		table.sort(points, sortMonotonic)

		local lower = {}
		for i = 1, numPoints do
			while (#lower >= 2 and cross(lower[#lower - 1], lower[#lower], points[i]) <= 0) do
				table.remove(lower)
			end
	
			table.insert(lower, points[i])
		end
	
		local upper = {}
		for i = numPoints, 1, -1 do
			while (#upper >= 2 and cross(upper[#upper - 1], upper[#upper], points[i]) <= 0) do
				table.remove(upper)
			end
	
			table.insert(upper, points[i])
		end
	
		table.remove(upper)
		table.remove(lower)
		for _, point in ipairs(lower) do
			table.insert(upper, point)
		end
		return upper
	end
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Speedups

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
local spGetAllFeatures = Spring.GetAllFeatures
local spGetCameraPosition = Spring.GetCameraPosition
local spGetFeatureHeight = Spring.GetFeatureHeight
local spGetFeaturePosition = Spring.GetFeaturePosition
local spGetFeatureResources = Spring.GetFeatureResources
local spGetFeatureTeam = Spring.GetFeatureTeam
local spGetGaiaTeamID = Spring.GetGaiaTeamID
local spGetGameFrame = Spring.GetGameFrame
local spGetGroundHeight = Spring.GetGroundHeight
local spIsGUIHidden = Spring.IsGUIHidden
local spTraceScreenRay = Spring.TraceScreenRay
local spValidFeatureID = Spring.ValidFeatureID
local spGetActiveCommand = Spring.GetActiveCommand
local spGetActiveCmdDesc = Spring.GetActiveCmdDesc
local spGetMapDrawMode = Spring.GetMapDrawMode
local spGetUnitDefID = Spring.GetUnitDefID
local spGetCameraVectors = Spring.GetCameraVectors

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Data

local screenx, screeny
local gaiaTeamId = spGetGaiaTeamID()
local clusterizingNeeded = false -- Used to check if clusterizing neds to be run, set by FeatureCreated/Removed
local redrawingNeeded = false

local minDistance = 300
local minSqDistance = minDistance^2
local minPoints = 2
local minFeatureMetal = 9 -- Tick
local E2M = 1 / 70 -- Converter ratio
local minDim = 100

local checkFrequency = 1 * Game.gameSpeed

local drawEnabled = true
local actionActive = false
local knownFeatures = {}

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

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- State update

local function enableHighlight()
	actionActive = true
end

local function disableHighlight()
	actionActive = false
end

local function UpdateDrawEnabled()
	local ecoView = spGetMapDrawMode() == 'metal'

	if actionActive then return true end
	if showOption == 1 then return true end
	if showOption == 2 then return ecoView or ecoView end
	if showOption == 3 then return reclaimerSelected or ecoView end
	if showOption == 4 then return resBotSelected or ecoView end
	if showOption == 5 then
		local currentCmd = spGetActiveCommand()
		if currentCmd then
			local activeCmdDesc = spGetActiveCmdDesc(currentCmd)
			return (activeCmdDesc and (activeCmdDesc.name == "Reclaim")) or ecoView
		end
	end
	if showOption == 6 then widgetHandler:RemoveWidget() end

	return false
end

function widget:SelectionChanged(units)
	local udefID
	reclaimerSelected = false
	resBotSelected = false
	for _, v in pairs(units) do
		udefID = spGetUnitDefID(v)
		if canResurrect[udefID] then
			resBotSelected = true
			reclaimerSelected = true
			return
		elseif canReclaim[udefID] then
			reclaimerSelected = true
			return
		end
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Feature Tracking

local featureNeighborsMatrix = {}
local featureClusters = {}
local featureConvexHulls = {}

---To update a feature's entire neighborhood, flag it as both added and removed.
local function UpdateFeatureNeighborsMatrix(fID, added, removed)
	local fInfo = knownFeatures[fID]

	if removed then
		for fID2 in pairs(featureNeighborsMatrix[fID]) do
			featureNeighborsMatrix[fID2][fID] = nil
			featureNeighborsMatrix[fID][fID2] = nil
		end
	end

	if added then
		local fx, fz = fInfo.x, fInfo.z
		featureNeighborsMatrix[fID] = {}
		for fID2, fInfo2 in pairs(knownFeatures) do
			if fID2 ~= fID then --don't include self into featureNeighborsMatrix[][]
				local sqDist = (fx - fInfo2.x)^2 + (fz - fInfo2.z)^2
				if sqDist <= minSqDistance then
					featureNeighborsMatrix[fID][fID2] = true
					featureNeighborsMatrix[fID2][fID] = true
				end
			end
		end
	end
end

local function UpdateFeatures()
	for fID, fInfo in pairs(knownFeatures) do
		-- local metal, _, energy = spGetFeatureResources(fID)
		-- if includeEnergy then metal = metal + energy * E2M end
		local metal = spGetFeatureResources(fID)
		if metal >= minFeatureMetal then
			-- -- @efrec testing whether this is still needed
			-- local fx, _, fz = spGetFeaturePosition(fID)
			-- local fy = spGetGroundHeight(fx, fz)
			-- if fInfo.x ~= fx or fInfo.y ~= fy or fInfo.z ~= fz then
			-- 	fInfo.x = fx
			-- 	fInfo.y = fy
			-- 	fInfo.z = fz
			-- 	fInfo.drawAlt = ((fy > 0 and fy) or 0) --+ fInfo.height
			-- 	UpdateFeatureNeighborsMatrix(fID, true, true)
			-- end

			if fInfo.metal ~= metal then
				if fInfo.clID then
					local thisCluster = featureClusters[fInfo.clID]
					thisCluster.metal = thisCluster.metal - fInfo.metal
					-- Okay but we've already established that it's >= min
					-- if metal >= minFeatureMetal then
						thisCluster.metal = thisCluster.metal + metal
						fInfo.metal = metal
					-- So this would never execute
					-- else
					-- 	UpdateFeatureNeighborsMatrix(fID, false, true)
					-- 	knownFeatures[fID] = nil
					-- end
				end
			end
		else
			knownFeatures[fID] = nil
			clusterizingNeeded = true
		end
	end

	for fID, fInfo in pairs(knownFeatures) do
		if fInfo.isGaia and spValidFeatureID(fID) == false then
			UpdateFeatureNeighborsMatrix(fID, false, true)
			fInfo = nil
			knownFeatures[fID] = nil
		else
			fInfo.clID = nil
		end
	end
end

local function ClusterizeFeatures()
	local pointsTable = {}
	local unclusteredPoints  = {}

	for fID, fInfo in pairs(knownFeatures) do
		pointsTable[#pointsTable + 1] = {
			x = fInfo.x,
			z = fInfo.z,
			fID = fID,
		}
		unclusteredPoints[fID] = true
	end

	local opticsObject = Optics.new(pointsTable, featureNeighborsMatrix, minPoints)
	opticsObject:Run()

	featureClusters = opticsObject:Clusterize(minDistance)

	for i = 1, #featureClusters do
		local thisCluster = featureClusters[i]		
		local members = thisCluster.members
		local xmin, xmax, zmin, zmax = -mathHuge, mathHuge, -mathHuge, mathHuge
		local metal = 0
		for j = 1, #members do
			local fID = members[j]
			local fInfo = knownFeatures[fID]

			local x = fInfo.x
			local z = fInfo.z
			xmin = min(xmin, x)
			xmax = max(xmax, x)
			zmin = min(zmin, z)
			zmax = max(zmax, z)

			metal = metal + fInfo.metal
			fInfo.clID = i
			unclusteredPoints[fID] = nil
		end

		thisCluster.metal = metal
		thisCluster.xmin = xmin
		thisCluster.xmax = xmax
		thisCluster.zmin = zmin
		thisCluster.zmax = zmax
	end

	for fID in pairs(unclusteredPoints) do
		local fInfo = knownFeatures[fID]
		local thisCluster = {}

		thisCluster.members = { fID }
		thisCluster.metal = fInfo.metal

		thisCluster.xmin = fInfo.x
		thisCluster.xmax = fInfo.x
		thisCluster.zmin = fInfo.z
		thisCluster.zmax = fInfo.z

		featureClusters[#featureClusters + 1] = thisCluster
		fInfo.clID = #featureClusters
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

local function ClustersToConvexHull()
	featureConvexHulls = {}
	for fc = 1, #featureClusters do
		local clusterPoints = {}
		local members = featureClusters[fc].members

		for fcm = 1, #members do
			local fID = members[fcm]
			clusterPoints[#clusterPoints + 1] = {
				x = knownFeatures[fID].x,
				y = knownFeatures[fID].drawAlt,
				z = knownFeatures[fID].z
			}
			--Spring.MarkerAddPoint(knownFeatures[fID].x, 0, knownFeatures[fID].z, string.format("%i(%i)", fc, fcm))
		end

		--- TODO perform pruning as described in the article below, if convex hull algo will start to choke out
		-- http://mindthenerd.blogspot.ru/2012/05/fastest-convex-hull-algorithm-ever.html

		local convexHull
		local hullArea = (#clusterPoints >= 3 and pointArea(clusterPoints)) or nil
		if hullArea ~= nil and hullArea >= 3000 then
			--spEcho("#clusterPoints >= 3")
			--convexHull = ConvexHull.JarvisMarch(clusterPoints)
			convexHull = MonotoneChain(clusterPoints) --twice faster
		else
			--spEcho("not #clusterPoints >= 3")
			local thisCluster = featureClusters[fc]

			local xmin, xmax, zmin, zmax = thisCluster.xmin, thisCluster.xmax, thisCluster.zmin, thisCluster.zmax

			local dx, dz = xmax - xmin, zmax - zmin

			if dx < minDim then
				xmin = xmin - (minDim - dx) / 2
				xmax = xmax + (minDim - dx) / 2
			end

			if dz < minDim then
				zmin = zmin - (minDim - dz) / 2
				zmax = zmax + (minDim - dz) / 2
			end

			local height = clusterPoints[1].y
			if #clusterPoints == 2 then
				height = max(height, clusterPoints[2].y)
			end

			convexHull = {
				{x = xmin, y = height, z = zmin},
				{x = xmax, y = height, z = zmin},
				{x = xmax, y = height, z = zmax},
				{x = xmin, y = height, z = zmax},
			}
			hullArea = minDim * minDim
		end

		local cx, cz, cy = 0, 0, 0
		for i = 1, #convexHull do
			local convexHullPoint = convexHull[i]
			cx = cx + convexHullPoint.x
			cz = cz + convexHullPoint.z
			cy = max(cy, convexHullPoint.y)
		end

		convexHull.area = hullArea
		convexHull.center = {x = cx/#convexHull, z = cz/#convexHull, y = cy + 1}

		featureConvexHulls[fc] = convexHull

--[[
		for i = 1, #convexHull do
			Sppring.MarkerAddPoint(convexHull[i].x, convexHull[i].y, convexHull[i].z, string.format("C%i(%i)", fc, i))
		end
]]--
	end
end

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

	for _, fID in ipairs(spGetAllFeatures()) do
		widget:FeatureCreated(fID)
	end
end

function widget:FeatureCreated(featureID, allyTeamID)
	-- local metal, _, energy = spGetFeatureResources(fID)
	-- if includeEnergy then metal = metal + energy * E2M end
	local metal = spGetFeatureResources(featureID)
	if (not knownFeatures[featureID]) and (metal >= minFeatureMetal) then
		local fx, fy, fz = spGetFeaturePosition(featureID)
		knownFeatures[featureID] = {
			x = fx,
			y = fy, -- spGetGroundHeight(fx, fz) -- befrwmrn
			z = fz,
			metal = metal,
			drawAlt = ((fy > 0 and fy) or 0),
			height = spGetFeatureHeight(featureID),
			isGaia = (spGetFeatureTeam(featureID) == gaiaTeamId),
		}

		UpdateFeatureNeighborsMatrix(featureID, true, false)
		clusterizingNeeded = true
	end
end

function widget:FeatureDestroyed(featureID, allyTeamID)
	if knownFeatures[featureID] then
		knownFeatures[featureID] = nil
		clusterizingNeeded = true
	end
end

function widget:GetConfigData(data)
    return {
        showOption = showOption
    }
end

function widget:SetConfigData(data)
	if data.showOption ~= nil then
		showOption = data.showOption
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
	for i = 1, #featureConvexHulls do
		glPushMatrix()

		local center = featureConvexHulls[i].center

		glTranslate(center.x, center.y, center.z)
		glRotate(-90, 1, 0, 0)

		-- Rotate text based on camera rotation
		if camUpVector[1] and camUpVector[3] then
			local rotationAngle = math.atan2(-camUpVector[1], -camUpVector[3]) * (180 / math.pi)
			glRotate(rotationAngle, 0, 0, 1)
		end

		local fontSize = fontSizeMin * fontScaling
		local area = featureConvexHulls[i].area
		fontSize = sqrt(area) * fontSize / minDim
		fontSize = min(fontSize, fontSizeMax)
		fontSize = max(fontSize, fontSizeMin)

		local metalText = string.formatSI(featureClusters[i].metal)

		glColor(numberColor)

		glText(metalText, 0, 0, fontSize, "cv") --cvo for outline

		glPopMatrix()
	end
end


function widget:Update(dt)
	drawEnabled = UpdateDrawEnabled()
	if not drawEnabled then return end

	local cx, cy, cz = spGetCameraPosition()

	local desc, w = spTraceScreenRay(screenx / 2, screeny / 2, true)
	if desc then
		local cameraDist = min( 8000, sqrt( (cx-w[1])^2 + (cy-w[2])^2 + (cz-w[3])^2 ) )
		cameraScale = sqrt((cameraDist / 600)) --number is an "optimal" view distance
	else
		cameraScale = 1.0
	end
end

function widget:GameFrame(frame)
	if not drawEnabled or frame % checkFrequency ~= 0 then
		return
	end

	local camUpVectorCurrent = spGetCameraVectors().up
	if drawFeatureClusterTextList == nil or camUpVectorCurrent ~= camUpVector then
		camUpVector = camUpVectorCurrent
		if drawFeatureClusterTextList ~= nil then
			glDeleteList(drawFeatureClusterTextList)
			drawFeatureClusterTextList = nil
		end
		drawFeatureClusterTextList = glCreateList(DrawFeatureClusterText)
	end

	if redrawingNeeded then
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

	UpdateFeatures()

	if clusterizingNeeded then
		ClusterizeFeatures()
		ClustersToConvexHull()
		clusterizingNeeded = false
		redrawingNeeded = true
	end
end

function widget:ViewResize(viewSizeX, viewSizeY)
	screenx, screeny = widgetHandler:GetViewSizes()
end

function widget:DrawWorld()
	if spIsGUIHidden() or not drawEnabled then
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
	if spIsGUIHidden() or not drawEnabled then
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

function widget:Shutdown()
	if drawFeatureConvexHullSolidList then
		glDeleteList(drawFeatureConvexHullSolidList)
	end
	if drawFeatureConvexHullEdgeList then
		glDeleteList(drawFeatureConvexHullEdgeList)
	end
	if drawFeatureClusterTextList then
		glDeleteList(drawFeatureClusterTextList)
	end
end
