local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name      = "Reclaim Field Highlight",
		desc      = "Highlights clusters of reclaimable material",
		author    = "ivand, refactored by esainane, edited for BAR by Lexon, efrec and Floris",
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
local numberColor = {1, 1, 1, 0.9}
local fontSizeMin = 30
local fontSizeMax = 140

--Field color
local reclaimColor = {0, 0, 0, 0.16}
local reclaimEdgeColor = {1, 1, 1, 0.18}

--Fill settings
local fillAlpha = 0.06 -- Base fill layer opacity
local gradientAlpha = 0.14 -- Gradient fill layer opacity at edges
local gradientInnerRadius = 0.75 -- Distance from center where gradient starts (0.25 = 25% from center, 75% towards center from edge)

--Field expansion settings
local expansionMultiplier = 0.35 -- Global multiplier for all field expansions (adjust to make fields larger/smaller)

--Smoothing settings
local enableSmoothing = true -- Enable smooth rounded edges with Catmull-Rom interpolation
local smoothingSegments = 5 -- Number of segments per edge
-- Note: Smoothing can be toggled at runtime via:
--   WG['reclaimfieldhighlight'].setEnableSmoothing(true/false)
--   WG['reclaimfieldhighlight'].setSmoothingSegments(value)
-- Lower values = better performance, sharper edges (e.g., 4-8 for low-end systems)
-- Higher values = smoother, more organic shapes (e.g., 20-30 for high-end systems)

--Update rate, in seconds
local checkFrequency = 0.5

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
local spGetFeatureRadius = Spring.GetFeatureRadius
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
local dirtyRegions = {} -- Track which regions need reclustering
local dirtyClusters = {} -- Track which specific clusters need redrawing
local useRegionalUpdates = true -- Enable regional optimization

-- Reusable tables to reduce allocations in GameFrame
local toRemoveFeatures = {} -- Reusable table for batching feature removals
local dirtyClustersList = {} -- Reusable table for dirty clusters in UpdateFeatureReclaim
local affectedFeaturesList = {} -- Reusable table for regional clustering
local affectedClustersList = {} -- Reusable table for regional clustering

-- Cache to avoid redundant Spring API calls
local lastFlyingCheckFrame = 0 -- Track when we last checked flying features
local validityCheckCounter = 0 -- Rotating counter for validity checks in GameFrame
local lastCameraCheckFrame = 0 -- Track when we last checked camera up vector

local epsilon = 340 -- Clustering distance - increased to merge nearby fields and prevent overlaps
local epsilonSq = epsilon*epsilon
local minFeatureMetal = 9 -- armflea reclaim value, probably
if UnitDefNames.armflea then
	local small = FeatureDefNames[UnitDefNames.armflea.corpse]
	minFeatureMetal = small and small.metal or minFeatureMetal
end
local baseCheckFrequency = math.round(checkFrequency * Game.gameSpeed)
checkFrequency = baseCheckFrequency
local lastFeatureCount = 0
local cachedKnownFeaturesCount = 0 -- Cached count to avoid iterating all features

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
		-- Calculate max radius of wrecks
		local maxRadius = 0
		for i = 1, #points do
			if points[i].radius and points[i].radius > maxRadius then
				maxRadius = points[i].radius
			end
		end

		-- Ensure minimum radius for visibility
		maxRadius = max(maxRadius, 20)

		local convexHull

		if #points == 1 then
			-- Single wreck: create a circle-like shape with more points for smoothing
			local cx, cz = points[1].x, points[1].z
			-- Base size on wreck radius with moderate margin
			local radius = maxRadius * 1.2 + 10
			convexHull = {}
			local segments = 8
			for i = 0, segments - 1 do
				local angle = (i / segments) * math.pi * 2
				local x = cx + math.cos(angle) * radius
				local z = cz + math.sin(angle) * radius
				convexHull[i + 1] = {
					x = x,
					y = max(0, spGetGroundHeight(x, z)),
					z = z
				}
			end
		elseif #points == 2 then
			-- Two wrecks: create elongated shape oriented along the line between them
			local p1, p2 = points[1], points[2]
			local cx, cz = (p1.x + p2.x) * 0.5, (p1.z + p2.z) * 0.5

			-- Vector between the two wrecks
			local dx, dz = p2.x - p1.x, p2.z - p1.z
			local dist = sqrt(dx * dx + dz * dz)

			if dist > 0.1 then
				-- Normalize
				dx, dz = dx / dist, dz / dist

				-- Perpendicular vector
				local px, pz = -dz, dx

				-- Width scales with wreck radius
				local width = maxRadius * 1.1 + 8

				local x1 = p1.x + px * width
				local z1 = p1.z + pz * width
				local x2 = p2.x + px * width
				local z2 = p2.z + pz * width
				local x3 = p2.x - px * width
				local z3 = p2.z - pz * width
				local x4 = p1.x - px * width
				local z4 = p1.z - pz * width

				convexHull = {
					{ x = x1, y = max(0, spGetGroundHeight(x1, z1)), z = z1 },
					{ x = x2, y = max(0, spGetGroundHeight(x2, z2)), z = z2 },
					{ x = x3, y = max(0, spGetGroundHeight(x3, z3)), z = z3 },
					{ x = x4, y = max(0, spGetGroundHeight(x4, z4)), z = z4 }
				}
			else
				-- Fall back to simple box if points are too close
				local expandDist = maxRadius * 1.2 + 10
				local xmin = cluster.xmin - expandDist
				local xmax = cluster.xmax + expandDist
				local zmin = cluster.zmin - expandDist
				local zmax = cluster.zmax + expandDist

				convexHull = {
					{ x = xmin, y = max(0, spGetGroundHeight(xmin, zmin)), z = zmin },
					{ x = xmax, y = max(0, spGetGroundHeight(xmax, zmin)), z = zmin },
					{ x = xmax, y = max(0, spGetGroundHeight(xmax, zmax)), z = zmax },
					{ x = xmin, y = max(0, spGetGroundHeight(xmin, zmax)), z = zmax }
				}
			end
		end

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

	-- Subdivide long edges in hull to ensure smooth expansion
	local function subdivideHull(hull, maxEdgeLength)
		if not hull or #hull < 3 then return hull end

		local subdivided = {}
		local n = #hull

		for i = 1, n do
			local curr = hull[i]
			local next = hull[i == n and 1 or i + 1]

			-- Add current vertex
			subdivided[#subdivided + 1] = {x = curr.x, y = curr.y, z = curr.z}

			-- Calculate edge length
			local dx = next.x - curr.x
			local dz = next.z - curr.z
			local edgeLen = sqrt(dx * dx + dz * dz)

			-- If edge is long, subdivide it
			if edgeLen > maxEdgeLength then
				local numSegments = math.ceil(edgeLen / maxEdgeLength)
				for j = 1, numSegments - 1 do
					local t = j / numSegments
					local interpX = curr.x + dx * t
					local interpZ = curr.z + dz * t
					subdivided[#subdivided + 1] = {
						x = interpX,
						y = max(0, spGetGroundHeight(interpX, interpZ)),
						z = interpZ
					}
				end
			end
		end

		return subdivided
	end

	-- Create a smooth elliptical hull based on oriented bounding ellipse
	local function createSmoothEllipse(hull, expandDist)
		if not hull or #hull < 3 then return hull end

		local n = #hull

		-- Calculate centroid
		local cx, cz = 0, 0
		for i = 1, n do
			cx = cx + hull[i].x
			cz = cz + hull[i].z
		end
		cx = cx / n
		cz = cz / n

		-- Calculate covariance matrix for PCA (Principal Component Analysis)
		local covXX, covXZ, covZZ = 0, 0, 0
		for i = 1, n do
			local dx = hull[i].x - cx
			local dz = hull[i].z - cz
			covXX = covXX + dx * dx
			covXZ = covXZ + dx * dz
			covZZ = covZZ + dz * dz
		end
		covXX = covXX / n
		covXZ = covXZ / n
		covZZ = covZZ / n

		-- Calculate eigenvalues and eigenvectors for oriented ellipse
		local trace = covXX + covZZ
		local det = covXX * covZZ - covXZ * covXZ
		local eigenval1 = trace / 2 + sqrt(max(0, trace * trace / 4 - det))
		local eigenval2 = trace / 2 - sqrt(max(0, trace * trace / 4 - det))

		-- Eigenvector for the major axis
		local evx, evz
		if abs(covXZ) > 0.0001 then
			evx = eigenval1 - covZZ
			evz = covXZ
			local evlen = sqrt(evx * evx + evz * evz)
			if evlen > 0 then
				evx, evz = evx / evlen, evz / evlen
			end
		else
			evx, evz = 1, 0
		end

		-- Calculate initial extents along principal axes
		local maxMajor, maxMinor = 0, 0
		for i = 1, n do
			local dx = hull[i].x - cx
			local dz = hull[i].z - cz
			-- Project onto principal axes
			local projMajor = abs(dx * evx + dz * evz)
			local projMinor = abs(-dx * evz + dz * evx)
			if projMajor > maxMajor then maxMajor = projMajor end
			if projMinor > maxMinor then maxMinor = projMinor end
		end

		-- Ensure minimum aspect ratio for very elongated shapes
		if maxMajor > 0 and maxMinor / maxMajor < 0.3 then
			maxMinor = maxMajor * 0.3
		end

		-- Add expansion
		maxMajor = maxMajor + expandDist
		maxMinor = maxMinor + expandDist

		-- Iteratively adjust radii to ensure all points are inside with minimal overshoot
		-- This finds the minimum bounding ellipse that contains all points
		local maxIterations = 5
		for iter = 1, maxIterations do
			local maxExcess = 0
			local needsAdjustment = false

			for i = 1, n do
				local dx = hull[i].x - cx
				local dz = hull[i].z - cz
				-- Project onto principal axes
				local projMajor = dx * evx + dz * evz
				local projMinor = -dx * evz + dz * evx

				-- Calculate how far outside the ellipse this point is
				local normalizedDist = (projMajor * projMajor) / (maxMajor * maxMajor) +
				                       (projMinor * projMinor) / (maxMinor * maxMinor)

				if normalizedDist > 1.0 then
					needsAdjustment = true
					local excess = sqrt(normalizedDist)
					if excess > maxExcess then
						maxExcess = excess
					end
				end
			end

			-- If all points are inside, we're done
			if not needsAdjustment then
				break
			end

			-- Grow the ellipse just enough to contain all points
			-- Use smaller incremental adjustments to avoid overshooting
			local adjustmentFactor = 1.0 + (maxExcess - 1.0) * 0.5  -- Grow by half the needed amount
			maxMajor = maxMajor * adjustmentFactor
			maxMinor = maxMinor * adjustmentFactor
		end

		-- Final safety margin
		maxMajor = maxMajor * 1.02
		maxMinor = maxMinor * 1.02

		-- Generate smooth ellipse points
		local numPoints = enableSmoothing and smoothingSegments * 4 or n
		local ellipse = {}
		for i = 0, numPoints - 1 do
			local angle = (i / numPoints) * 2 * math.pi
			local localX = maxMajor * math.cos(angle)
			local localZ = maxMinor * math.sin(angle)

			-- Rotate back to world orientation
			local worldX = cx + localX * evx - localZ * evz
			local worldZ = cz + localX * evz + localZ * evx

			ellipse[i + 1] = {
				x = worldX,
				y = max(0, spGetGroundHeight(worldX, worldZ)),
				z = worldZ
			}
		end

		return ellipse
	end

	-- Expand hull outward by a margin and create rounded corners with Catmull-Rom smoothing
	local function expandAndSmoothHull(hull, expandDist)
		if not hull or #hull < 3 then return hull end

		-- Subdivide long edges first to ensure smooth, even expansion
		-- Use expandDist as guide for max edge length (want multiple points per expansion distance)
		local maxEdgeLength = max(expandDist * 1.5, 80)  -- At least one subdivision per ~expansion distance
		hull = subdivideHull(hull, maxEdgeLength)

		local n = #hull

		-- Calculate centroid for radial expansion
		local cx, cz = 0, 0
		for i = 1, n do
			cx = cx + hull[i].x
			cz = cz + hull[i].z
		end
		cx = cx / n
		cz = cz / n

		if not enableSmoothing then
			--return hull
		end

		-- First pass: expand all vertices outward using a blend of radial and normal-based expansion
		local expanded = {}
		for i = 1, n do
			local prev = hull[i == 1 and n or i - 1]
			local curr = hull[i]
			local next = hull[i == n and 1 or i + 1]

			-- Calculate edge vectors
			local dx1, dz1 = curr.x - prev.x, curr.z - prev.z
			local len1 = sqrt(dx1 * dx1 + dz1 * dz1)
			if len1 > 0 then dx1, dz1 = dx1 / len1, dz1 / len1 end

			local dx2, dz2 = next.x - curr.x, next.z - curr.z
			local len2 = sqrt(dx2 * dx2 + dz2 * dz2)
			if len2 > 0 then dx2, dz2 = dx2 / len2, dz2 / len2 end

			-- Calculate outward normals
			local nx1, nz1 = -dz1, dx1
			local nx2, nz2 = -dz2, dx2

			-- Average normal (bisector)
			local nx = (nx1 + nx2) * 0.5
			local nz = (nz1 + nz2) * 0.5
			local nlen = sqrt(nx * nx + nz * nz)
			if nlen > 0 then
				nx, nz = nx / nlen, nz / nlen
			end

			-- Radial direction from centroid (for more circular expansion)
			local rx = curr.x - cx
			local rz = curr.z - cz
			local rlen = sqrt(rx * rx + rz * rz)
			if rlen > 0 then
				rx, rz = rx / rlen, rz / rlen
			end

			-- Blend normal and radial directions for smoother, more circular expansion
			-- Higher weight on radial = more circular/blob-like
			local blendWeight = 0.7  -- 70% radial, 30% normal-based
			local finalNx = nx * (1 - blendWeight) + rx * blendWeight
			local finalNz = nz * (1 - blendWeight) + rz * blendWeight
			local finalLen = sqrt(finalNx * finalNx + finalNz * finalNz)
			if finalLen > 0 then
				finalNx, finalNz = finalNx / finalLen, finalNz / finalLen
			end

			-- Use more uniform expansion (less dependency on corner sharpness)
			local dotProduct = dx1 * dx2 + dz1 * dz2
			local angle = math.acos(clamp(dotProduct, -1, 1))
			local sinHalfAngle = math.sin(angle * 0.5)
			-- Reduced the influence of corner sharpness for more uniform expansion
			local expandFactor = sinHalfAngle > 0.4 and (1.0 / sinHalfAngle) or 2.5
			expandFactor = clamp(expandFactor, 1.0, 2.0)  -- Tighter range for more uniformity

			local newX = curr.x + finalNx * expandDist * expandFactor
			local newZ = curr.z + finalNz * expandDist * expandFactor

			expanded[i] = {
				x = newX,
				y = max(0, spGetGroundHeight(newX, newZ)),
				z = newZ
			}
		end

		if not enableSmoothing then
			return expanded
		end

		-- If smoothing disabled, return expanded hull directly
		if smoothingSegments <= 0 then
			return expanded
		end

		-- Second pass: Apply Catmull-Rom spline interpolation for smooth curves
		local smoothed = {}
		local segmentsPerEdge = smoothingSegments

		for i = 1, n do
			local p0 = expanded[i == 1 and n or i - 1]
			local p1 = expanded[i]
			local p2 = expanded[i == n and 1 or i + 1]
			local p3 = expanded[(i + 1) % n + 1]

			-- Catmull-Rom spline between p1 and p2
			for seg = 0, segmentsPerEdge - 1 do
				local t = seg / segmentsPerEdge
				local t2 = t * t
				local t3 = t2 * t

				-- Catmull-Rom basis
				local c0 = -0.5 * t3 + t2 - 0.5 * t
				local c1 = 1.5 * t3 - 2.5 * t2 + 1.0
				local c2 = -1.5 * t3 + 2.0 * t2 + 0.5 * t
				local c3 = 0.5 * t3 - 0.5 * t2

				local newX = c0 * p0.x + c1 * p1.x + c2 * p2.x + c3 * p3.x
				local newZ = c0 * p0.z + c1 * p1.z + c2 * p2.z + c3 * p3.z
				-- Interpolate Y smoothly using the spline
				local newY = c0 * p0.y + c1 * p1.y + c2 * p2.y + c3 * p3.y

				smoothed[#smoothed + 1] = {
					x = newX,
					y = newY,
					z = newZ
				}
			end
		end

		return smoothed
	end

	processCluster = function (cluster, clusterID, points)
		getReclaimTotal(cluster, points)

		local convexHull, hullArea
		local usedBoundingBox = false
		local maxRadius = 0

		-- Calculate max wreck radius for scaling
		for i = 1, #points do
			if points[i].radius and points[i].radius > maxRadius then
				maxRadius = points[i].radius
			end
		end
		maxRadius = max(maxRadius, 20)

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
			usedBoundingBox = true
		end

		-- Apply expansion and smoothing to make blob-like shapes
		-- Apply to all cases including BoundingBox for smooth organic shapes
		-- expandDist: how much to expand outward (in elmos)
		if convexHull and #convexHull >= 3 then
			-- Scale expansion with wreck size for proportional fields
			-- Increased expansion values for more encompassing, uniform fields
			local expansion
			if #points == 1 then
				expansion = (maxRadius * 1.5 + 35) * expansionMultiplier  -- Expansion for single wrecks
			elseif usedBoundingBox then
				expansion = (maxRadius * 1.5 + 40) * expansionMultiplier  -- Expansion for two wrecks
			else
				expansion = (maxRadius * 1.8 + 65) * expansionMultiplier  -- Expansion for clusters
			end

			-- Always use the standard expand+smooth method which follows the hull shape
			-- The ellipse approach was too rigid and caused overshooting
			convexHull = expandAndSmoothHull(convexHull, expansion)
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

local function MarkRegionDirty(x, z, radius)
	-- Mark a spatial region as needing reclustering
	if not useRegionalUpdates then return end

	local newRadius = radius or epsilon * 2
	local merged = false

	-- Try to merge with existing dirty regions to reduce fragmentation
	for i = 1, #dirtyRegions do
		local region = dirtyRegions[i]
		local dx, dz = x - region.x, z - region.z
		local dist = sqrt(dx * dx + dz * dz)

		-- If regions overlap or are very close, merge them
		if dist <= (region.radius + newRadius) then
			-- Expand existing region to cover both
			local furthestDist = dist + newRadius
			if furthestDist > region.radius then
				-- Move center toward the midpoint and expand radius
				local totalRadius = max(region.radius, furthestDist)
				region.radius = totalRadius
			end
			merged = true
			break
		end
	end

	-- Add as new region if not merged
	if not merged then
		dirtyRegions[#dirtyRegions + 1] = {x = x, z = z, radius = newRadius}
	end
end

local function IsInDirtyRegion(x, z)
	if not useRegionalUpdates or #dirtyRegions == 0 then return true end
	for i = 1, #dirtyRegions do
		local region = dirtyRegions[i]
		local dx, dz = x - region.x, z - region.z
		if dx * dx + dz * dz <= region.radius * region.radius then
			return true
		end
	end
	return false
end

local function RemoveFeature(featureID)
	local feature = knownFeatures[featureID]
	if not feature then return end

	-- Mark region as dirty for regional reclustering
	MarkRegionDirty(feature.x, feature.z)

	-- Mark cluster as dirty for redrawing
	if feature.cid then
		dirtyClusters[feature.cid] = true
	end

	local neighbors = featureNeighborsMatrix[featureID]
	local epsilonSq = epsilonSq
	for nid, distSq in pairs(neighbors) do
		-- Update the reachability of neighbors linked through this point.
		local neighbor = knownFeatures[nid]
		if neighbor then
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
	end
	featureNeighborsMatrix[featureID] = nil
	knownFeatures[featureID] = nil
	cachedKnownFeaturesCount = cachedKnownFeaturesCount - 1
end

local function UpdateFeatureReclaim()
	-- Only check a subset of features per frame to reduce API calls
	-- We rotate through features over multiple frames
	local removed = false
	local removeCount = 0
	local dirtyCount = 0

	-- Sample rate: check ~10% of features per frame (or all if < 50 features)
	-- Use cached count instead of iterating all features
	local featureCount = cachedKnownFeaturesCount

	local checkInterval = math.max(1, math.floor(featureCount / 50)) -- Check every Nth feature
	local checkCounter = 0

	for fid, fInfo in pairs(knownFeatures) do
		-- Rotating check: only check some features per frame
		checkCounter = checkCounter + 1
		if checkCounter % checkInterval == 0 or featureCount <= 50 then
			-- Check this feature this frame
			local metal = spGetFeatureResources(fid)
			if not metal or metal < minFeatureMetal then
				removeCount = removeCount + 1
				toRemoveFeatures[removeCount] = fid
				removed = true
			elseif fInfo.metal ~= metal then
				if fInfo.cid then
					local cid = fInfo.cid
					-- Only add to dirty list if not already there
					if not dirtyClustersList[cid] then
						dirtyCount = dirtyCount + 1
						dirtyClustersList[cid] = true
					end
					local thisCluster = featureClusters[cid]
					thisCluster.metal = thisCluster.metal - fInfo.metal + metal
				end
				fInfo.metal = metal
			end
		end
	end

	-- Remove in separate loop to avoid iterator issues
	for i = 1, removeCount do
		RemoveFeature(toRemoveFeatures[i])
	end

	-- Clear reusable table
	for i = 1, removeCount do
		toRemoveFeatures[i] = nil
	end

	if removed then
		clusterizingNeeded = true
	elseif dirtyCount > 0 then
		redrawingNeeded = true
		for cid in pairs(dirtyClustersList) do
			local cluster = featureClusters[cid]
			if cluster then
				cluster.text = string.formatSI(cluster.metal)
			end
			dirtyClustersList[cid] = nil -- Clear as we go
		end
	end
end

local function ClusterizeFeatures()
	if useRegionalUpdates and #dirtyRegions > 0 then
		-- Regional reclustering: only recluster features in dirty regions
		-- Reuse tables instead of allocating new ones
		local affectedCount = 0
		local clusterCount = 0

		-- Find all features in dirty regions
		for fid, feature in pairs(knownFeatures) do
			if IsInDirtyRegion(feature.x, feature.z) then
				affectedCount = affectedCount + 1
				affectedFeaturesList[affectedCount] = fid
				if feature.cid then
					local cid = feature.cid
					if not affectedClustersList[cid] then
						clusterCount = clusterCount + 1
						affectedClustersList[cid] = true
					end
				end
			end
		end

		-- If too many features affected, fall back to full reclustering
		if affectedCount > 200 then -- Threshold for full recluster
			-- Clear reusable tables
			for i = 1, affectedCount do
				affectedFeaturesList[i] = nil
			end
			for cid in pairs(affectedClustersList) do
				affectedClustersList[cid] = nil
			end

			-- Fall through to full clustering
			useRegionalUpdates = false
			opticsObject:Run()
			useRegionalUpdates = true
			-- Clear dirty regions array
			for i = 1, #dirtyRegions do
				dirtyRegions[i] = nil
			end
			-- Clear dirty clusters table
			for cid in pairs(dirtyClusters) do
				dirtyClusters[cid] = nil
			end
			clusterizingNeeded = false
			redrawingNeeded = true
			return
		end

		-- Remove affected clusters and reset cluster IDs for affected features
		for cid in pairs(affectedClustersList) do
			featureClusters[cid] = nil
			featureConvexHulls[cid] = nil
			affectedClustersList[cid] = nil -- Clear as we go
		end

		for i = 1, affectedCount do
			local fid = affectedFeaturesList[i]
			local feature = knownFeatures[fid]
			if feature then
				feature.cid = nil
			end
			affectedFeaturesList[i] = nil -- Clear as we go
		end

		-- Re-run clustering (it will create new cluster IDs)
		opticsObject:Run()

		-- Clear dirty regions array
		for i = 1, #dirtyRegions do
			dirtyRegions[i] = nil
		end
		-- Clear dirty clusters table
		for cid in pairs(dirtyClusters) do
			dirtyClusters[cid] = nil
		end
	else
		-- Full reclustering
		opticsObject:Run()
		-- Clear dirty regions array
		for i = 1, #dirtyRegions do
			dirtyRegions[i] = nil
		end
		-- Clear dirty clusters table
		for cid in pairs(dirtyClusters) do
			dirtyClusters[cid] = nil
		end
	end

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

-- Draw gradient fill from center (transparent) to configurable radius (gradientAlpha)
-- Also fills the inner area with fillAlpha
local function DrawHullVerticesGradient(hull, center)
	local hullCount = #hull
	if hullCount < 3 then return end

	-- Pre-calculate color components to avoid table lookups
	local r, g, b = reclaimColor[1], reclaimColor[2], reclaimColor[3]
	local cx, cy, cz = center.x, center.y, center.z
	local innerRadius = gradientInnerRadius

	-- Calculate the inner boundary using configurable radius
	local innerPoints = {}
	for i = 1, hullCount do
		local hullPoint = hull[i]
		local dx = hullPoint.x - cx
		local dz = hullPoint.z - cz
		-- gradientInnerRadius controls where gradient starts from center
		innerPoints[i] = {
			x = cx + dx * innerRadius,
			y = hullPoint.y,
			z = cz + dz * innerRadius
		}
	end

	-- First, fill the inner area with solid fillAlpha (fan triangulation from center)
	glColor(r, g, b, fillAlpha)
	local innerCount = #innerPoints
	for j = 1, innerCount do
		local nextIdx = (j == innerCount) and 1 or (j + 1)
		local inner = innerPoints[j]
		local innerNext = innerPoints[nextIdx]
		glVertex(cx, cy, cz)
		glVertex(inner.x, inner.y, inner.z)
		glVertex(innerNext.x, innerNext.y, innerNext.z)
	end

	-- Then draw gradient triangles between inner (fillAlpha) and outer (gradientAlpha) rings
	for j = 1, hullCount do
		local nextIdx = (j == hullCount) and 1 or (j + 1)
		local inner = innerPoints[j]
		local innerNext = innerPoints[nextIdx]
		local outer = hull[j]
		local outerNext = hull[nextIdx]

		-- Triangle 1: inner[j] -> outer[j] -> inner[next]
		glColor(r, g, b, fillAlpha)
		glVertex(inner.x, inner.y, inner.z)

		glColor(r, g, b, gradientAlpha)
		glVertex(outer.x, outer.y, outer.z)

		glColor(r, g, b, fillAlpha)
		glVertex(innerNext.x, innerNext.y, innerNext.z)

		-- Triangle 2: inner[next] -> outer[j] -> outer[next]
		glColor(r, g, b, fillAlpha)
		glVertex(innerNext.x, innerNext.y, innerNext.z)

		glColor(r, g, b, gradientAlpha)
		glVertex(outer.x, outer.y, outer.z)

		glColor(r, g, b, gradientAlpha)
		glVertex(outerNext.x, outerNext.y, outerNext.z)
	end
end

local drawFeatureConvexHullGradientList
local function DrawFeatureConvexHullGradient()
	for i = 1, #featureConvexHulls do
		if featureConvexHulls[i] and featureClusters[i].center then
			glBeginEnd(GL.TRIANGLES, DrawHullVerticesGradient, featureConvexHulls[i], featureClusters[i].center)
		end
	end
end

local drawFeatureConvexHullEdgeList
local function DrawFeatureConvexHullEdge()
	for i = 1, #featureConvexHulls do
		local hull = featureConvexHulls[i]
		if hull and #hull > 0 then
			glBeginEnd(GL.LINE_LOOP, DrawHullVertices, hull)
		end
	end
end

local drawFeatureClusterTextList
local cachedCameraFacing = 0
local function DrawFeatureClusterText()
	-- Cache camera facing calculation
	cachedCameraFacing = math.atan2(-camUpVector[1], -camUpVector[3]) * (180 / math.pi)

	for clusterID = 1, #featureClusters do
		local center = featureClusters[clusterID].center

		glPushMatrix()

		glTranslate(center.x, center.y, center.z)
		glRotate(-90, 1, 0, 0)
		glRotate(cachedCameraFacing, 0, 0, 1)

		glColor(numberColor)
		glText(featureClusters[clusterID].text, 0, 0, featureClusters[clusterID].font, "cvo")

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
	WG['reclaimfieldhighlight'].getEnableSmoothing = function()
		return enableSmoothing
	end
	WG['reclaimfieldhighlight'].setEnableSmoothing = function(value)
		enableSmoothing = value
		clusterizingNeeded = true -- Force recluster with new settings
	end
	WG['reclaimfieldhighlight'].getSmoothingSegments = function()
		return smoothingSegments
	end
	WG['reclaimfieldhighlight'].setSmoothingSegments = function(value)
		smoothingSegments = clamp(value, 4, 40) -- Clamp to reasonable range
		clusterizingNeeded = true -- Force recluster with new settings
	end

	-- Start/restart feature clustering.
	knownFeatures = {}
	flyingFeatures = {}
	featureNeighborsMatrix = {}
	featureClusters = {}
	featureConvexHulls = {}
	opticsObject = Optics.new()
	cachedKnownFeaturesCount = 0 -- Reset cached count

	for _, featureID in ipairs(Spring.GetAllFeatures()) do
		widget:FeatureCreated(featureID)
	end

	camUpVector = spGetCameraVectors().up

	widget:SelectionChanged(Spring.GetSelectedUnits())
end

function widget:Shutdown()
	widgetHandler:RemoveAction("reclaim_highlight", "p")
	widgetHandler:RemoveAction("reclaim_highlight", "r")

	WG['reclaimfieldhighlight'] = nil -- todo: register/deregister, right?

	if drawFeatureConvexHullGradientList ~= nil then
		glDeleteList(drawFeatureConvexHullGradientList)
	end
	if drawFeatureConvexHullEdgeList ~= nil then
		glDeleteList(drawFeatureConvexHullEdgeList)
	end
	if drawFeatureClusterTextList ~= nil then
		glDeleteList(drawFeatureClusterTextList)
	end
end

function widget:GetConfigData(data)
    return {
		showOption = showOption,
		enableSmoothing = enableSmoothing,
		smoothingSegments = smoothingSegments
	}
end

function widget:SetConfigData(data)
	if data.showOption ~= nil then
		showOption = data.showOption
	end
	-- if data.enableSmoothing ~= nil then
	-- 	enableSmoothing = data.enableSmoothing
	-- end
	-- if data.smoothingSegments ~= nil then
	-- 	smoothingSegments = clamp(data.smoothingSegments, 4, 40)
	-- end
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
	if drawEnabled == false then
		return
	end

	-- Dynamically adjust check frequency based on feature count
	-- Only recalculate every 30 frames to avoid overhead
	-- Use cached count instead of iterating all features
	if frame % 30 == 0 then
		local currentFeatureCount = cachedKnownFeaturesCount

		-- Adjust frequency based on feature count thresholds
		if currentFeatureCount ~= lastFeatureCount then
			lastFeatureCount = currentFeatureCount
			if currentFeatureCount < 500 then
				checkFrequency = baseCheckFrequency -- Normal frequency
			elseif currentFeatureCount < 1500 then
				checkFrequency = baseCheckFrequency * 2 -- 500-1500 features: 2x slower
			elseif currentFeatureCount < 3000 then
				checkFrequency = baseCheckFrequency * 3 -- 1500-3000 features: 3x slower
			else
				checkFrequency = baseCheckFrequency * 4 -- 3000+ features: 4x slower
			end
		end
	end

	if frame % checkFrequency ~= 0 then
		return
	end

	local featuresAdded = false

	-- Process flying features (check less frequently - every 3 frames)
	-- Flying features are rare, no need to check every single frame
	if next(flyingFeatures) and (frame - lastFlyingCheckFrame) >= 3 then
		lastFlyingCheckFrame = frame
		for featureID, fInfo in pairs(flyingFeatures) do
			-- Quick validation before API call
			if Spring.ValidFeatureID(featureID) then
				local _,_,_, vw = spGetFeatureVelocity(featureID)
				if vw then
					-- Feature still exists and has velocity data
					if vw <= 1e-3 then
						flyingFeatures[featureID] = nil
						local x, y, z = spGetFeaturePosition(featureID)
						if x then -- Validate feature still exists
							fInfo.x, fInfo.y, fInfo.z = x, y, z

							-- Mark region as dirty for regional reclustering
							MarkRegionDirty(x, z)

							local M = featureNeighborsMatrix
							local M_newFeature = {}
							local reachDistSq, epsilonSq = mathHuge, epsilonSq
							for fid2, feat2 in pairs(knownFeatures) do
								local dx, dz = x - feat2.x, z - feat2.z
								local distSq = dx * dx + dz * dz
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
							cachedKnownFeaturesCount = cachedKnownFeaturesCount + 1
							featuresAdded = true
						else
							-- Feature was destroyed while flying
							flyingFeatures[featureID] = nil
						end
					end
				else
					-- Feature no longer exists
					flyingFeatures[featureID] = nil
				end
			else
				-- Feature ID is invalid
				flyingFeatures[featureID] = nil
			end
		end
	end

	if featuresAdded or clusterizingNeeded then
		-- Batch remove invalid features using reusable table
		-- Use rotating checks to avoid checking ALL features every cycle
		local removeCount = 0

		-- Use cached count instead of iterating all features
		local featureCount = cachedKnownFeaturesCount

		-- Calculate check interval: check at minimum 50 features, but sample more if fewer total
		local checkInterval = max(1, floor(featureCount / 50))
		validityCheckCounter = validityCheckCounter + 1

		for fid, fInfo in pairs(knownFeatures) do
			-- Rotating check: only validate a subset of features per frame
			-- Always check if featureCount is small, otherwise use rotating pattern
			if checkInterval == 1 or (validityCheckCounter % checkInterval == 0) then
				-- Quick validity check first (much cheaper than GetFeatureResources)
				if not Spring.ValidFeatureID(fid) then
					removeCount = removeCount + 1
					toRemoveFeatures[removeCount] = fid
				else
					-- Only call GetFeatureResources if feature is valid
					local metal = spGetFeatureResources(fid)
					if not metal or metal < minFeatureMetal then
						removeCount = removeCount + 1
						toRemoveFeatures[removeCount] = fid
					end
				end
			end
			validityCheckCounter = validityCheckCounter + 1
		end

		-- Remove in separate loop to avoid iterator issues
		for i = 1, removeCount do
			RemoveFeature(toRemoveFeatures[i])
		end

		-- Clear the reusable table
		for i = 1, removeCount do
			toRemoveFeatures[i] = nil
		end

		ClusterizeFeatures()
	else
		UpdateFeatureReclaim()
	end

	if redrawingNeeded == true then
		-- Check if we can do incremental redraw
		local dirtyCount = 0
		for _ in pairs(dirtyClusters) do
			dirtyCount = dirtyCount + 1
		end

		-- If only a few clusters changed and we have existing lists, try incremental update
		if dirtyCount > 0 and dirtyCount < 10 and drawFeatureConvexHullGradientList ~= nil then
			-- For now, still do full redraw but this marks where we could optimize further
			-- Future: Could maintain per-cluster display lists
			if drawFeatureConvexHullGradientList ~= nil then
				glDeleteList(drawFeatureConvexHullGradientList)
				drawFeatureConvexHullGradientList = nil
			end
			if drawFeatureConvexHullEdgeList ~= nil then
				glDeleteList(drawFeatureConvexHullEdgeList)
				drawFeatureConvexHullEdgeList = nil
			end
			drawFeatureConvexHullGradientList = glCreateList(DrawFeatureConvexHullGradient)
			drawFeatureConvexHullEdgeList = glCreateList(DrawFeatureConvexHullEdge)
		else
			-- Full redraw
			if drawFeatureConvexHullGradientList ~= nil then
				glDeleteList(drawFeatureConvexHullGradientList)
				drawFeatureConvexHullGradientList = nil
			end
			if drawFeatureConvexHullEdgeList ~= nil then
				glDeleteList(drawFeatureConvexHullEdgeList)
				drawFeatureConvexHullEdgeList = nil
			end
			drawFeatureConvexHullGradientList = glCreateList(DrawFeatureConvexHullGradient)
			drawFeatureConvexHullEdgeList = glCreateList(DrawFeatureConvexHullEdge)
		end

		-- Clear dirtyClusters table instead of reallocating
		for cid in pairs(dirtyClusters) do
			dirtyClusters[cid] = nil
		end
	end

	-- Text is always redrawn to rotate it facing the camera.
	-- Only check camera vector every few frames or when redrawing - it rarely changes
	local cameraChanged = false
	if redrawingNeeded or (frame - lastCameraCheckFrame) >= 5 then
		local camUpVectorNew = spGetCameraVectors().up
		if camUpVector[1] ~= camUpVectorNew[1] or camUpVector[3] ~= camUpVectorNew[3] then
			camUpVector = camUpVectorNew
			cameraChanged = true
		end
		lastCameraCheckFrame = frame
	end

	if cameraChanged or redrawingNeeded then
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
	if not metal or metal < minFeatureMetal then
		return
	end

	local x, y, z = spGetFeaturePosition(featureID)
	if not x then return end

	-- Mark region as dirty for regional reclustering
	MarkRegionDirty(x, z)

	local radius = spGetFeatureRadius(featureID) or 0
	local feature = {
		fid   = featureID,
		metal = metal,
		x     = x,
		y     = max(0, y),
		z     = z,
		radius = radius,
	}

	-- To deal with e.g. raptor eggs spawning at altitude ~20:
	if y > 0 then
		local elevation = spGetGroundHeight(x, z)
		if elevation and elevation > 0 and y > elevation + 2 then
			flyingFeatures[featureID] = feature
			return -- Delay clusterizing until stationary.
		end
	end

	-- Assuming the feature's motion is highly likely negligible:
	local M = featureNeighborsMatrix
	local M_newFeature = {}
	local reachDistSq, epsilonSq = mathHuge, epsilonSq
	for fid2, feat2 in pairs(knownFeatures) do
		local dx, dz = x - feat2.x, z - feat2.z
		local distSq = dx * dx + dz * dz
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
	cachedKnownFeaturesCount = cachedKnownFeaturesCount + 1
	clusterizingNeeded = true
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

	-- Recreate text display list after resize to prevent mangled text
	if drawFeatureClusterTextList ~= nil then
		glDeleteList(drawFeatureClusterTextList)
		drawFeatureClusterTextList = nil
	end
	if #featureClusters > 0 then
		drawFeatureClusterTextList = glCreateList(DrawFeatureClusterText)
	end
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

	-- Draw gradient layer with inner fill
	if drawFeatureConvexHullGradientList ~= nil then
		glPushMatrix()
		glTranslate(0, -1, 0) -- Push down by 1 unit
		glCallList(drawFeatureConvexHullGradientList)
		glPopMatrix()
	end

	-- Draw edge on top at normal height
	if drawFeatureConvexHullEdgeList ~= nil then
		glLineWidth(6.0 / cameraScale)
		glColor(reclaimEdgeColor)
		glCallList(drawFeatureConvexHullEdgeList)
		glLineWidth(1.0)
	end

	glDepthTest(true)
end
