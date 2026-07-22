local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name      = "Reclaim Field Highlight",
		desc      = "Highlights clusters of reclaimable material",
		author    = "ivand, refactored by esainane, edited for BAR by Lexon, efrec and Floris",
		date      = "2024",
		license   = "public",
		layer     = 1270000,
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
--[[
	From settings (gui_options.lua)
	1 - always enabled
	2 - resource view only
	3 - reclaimer selected
	4 - resbot selected
	5 - reclaim order active
	6 - disabled

	-- Pre-gamestart: shows both metal+energy always regardless of these settings
]]
local showOption = 3
local showEnergyOption = 3 -- Same options as showOption, but for energy fields
local showEnergyFields = true -- Show energy reclaim fields separately

--Metal value font
local numberColor = {0.9, 0.9, 0.9, 1}
local energyNumberColor = {1.0, 0.9, 0.1, 1}

-- Resource icons (shown in front of each metal/energy value label)
local showResourceIcons = false -- Enabled at runtime only in scenario games
local iconSizeRatio = 1.0    -- Icon size relative to text font size
local iconGapRatio  = 0.0     -- Gap between icon and text relative to font size
local fontSizeMin = 25
local fontSizeMax = 75

--Field color
local reclaimColor = {0, 0, 0, 0.16}
local reclaimEdgeColor = {1, 1, 1, 0.18}

--Energy field color (yellowish tint)
local energyReclaimColor = {0.8, 0.8, 0, 0.16}
local energyReclaimEdgeColor = {1, 0.9, 0, 0.18}

--Energy field settings
local energyOpacityMultiplier = 0.44 -- Multiplier for energy field opacity (relative to metal fields)
local energyTextSizeMultiplier = 0.5 -- Multiplier for energy text size (relative to metal text)

--Fill settings
local fillAlpha = 0.055 -- Base fill layer opacity
local gradientAlpha = 0.13 -- Gradient fill layer opacity at edges
local gradientInnerRadius = 0.75 -- Distance from center where gradient starts (0.25 = 25% from center, 75% towards center from edge)

--Field expansion settings
local expansionMultiplier = 0.3 -- Global multiplier for all field expansions (adjust to make fields larger/smaller)

--Smoothing settings
local smoothingSegments = 4 -- Number of segments per edge
-- Note: Smoothing can be toggled at runtime via:
--   WG['reclaimfieldhighlight'].setSmoothingSegments(value)
-- Lower values = better performance, sharper edges (e.g., 4-8 for low-end systems)
-- Higher values = smoother, more organic shapes (e.g., 20-30 for high-end systems)

local checkFrequencyMult = 1

local epsilon = 300 -- Clustering distance - increased to merge nearby fields and prevent overlaps

local minFeatureValue = 9

-- Maximum cluster size in elmos - clusters larger than this will be split into sub-clusters
local maxClusterSize = 3000 -- Adjust this value: smaller = more sub-clusters, larger = fewer but bigger fields

-- Distance-based fade settings (in elmos - Spring units)
local fadeStartDistance = 4500 -- Distance where fields start to fade out
local fadeEndDistance = 7000 -- Distance where fields stop rendering completely (must be > fadeStartDistance)

-- Always show fields regardless of distance
local alwaysShowFields = true -- When true, fields will always be visible at full opacity regardless of camera distance
local alwaysShowFieldsMinThreshold = 500 -- Minimum metal value threshold
local alwaysShowFieldsMaxThreshold = 4000 -- Maximum metal value threshold
local alwaysShowFieldsThreshold = 500 -- Current threshold (auto-calculated based on map metal)
local totalMapMetal = 0 -- Total metal available on the map (calculated after clustering)

-- Animation settings (fade in/out + expand/shrink pulse). All packed into one
-- table to keep top-level local count under Lua's 200-upvalue limit.
local animCfg = {
	fadeInDuration = 0.18,
	fadeOutDuration = 0.18,
	pulseExpandDuration = 0.25,
	pulseShrinkDuration = 0.25,
	pulseExpandScale = 1.03,
	pulseShrinkScale = 0.97,
	toggleFadeDuration = 0.18,
	-- Cluster identity matching: required overlap fraction (intersection / max(old,new))
	identityMinOverlap = 0.34,
	-- Alpha delta beyond which we recreate the gradient display list. Kept in
	-- step with the alpha quantization used in CreateClusterDisplayList (~32
	-- buckets), so slowly-fading fields (e.g. distance fade while panning) don't
	-- recompute a state hash and rebuild a display list almost every frame. The
	-- fill/gradient alphas are tiny (~0.05-0.13) so ~32 steps stays smooth.
	rebuildThreshold = 0.03,
	-- Minimum relative change in cluster resource value to trigger a pulse
	-- animation. Smaller changes (e.g. a single small wreck added/removed from
	-- a large field) are ignored so the field only pulses on meaningful changes.
	pulseMinRelativeChange = 0.12,
	-- Per-frame budget for alpha-driven display-list rebuilds. The widget now
	-- keeps this high enough that visible fades track camera motion closely.
	maxRebuildsPerFrame = 64,
	rebuildBudgetFrame = -1,
	rebuildBudgetRemaining = 0,
	-- Camera-motion aware rebuild throttling. Distance fade makes every field's
	-- alpha drift while the camera pans; baking that alpha into the gradient
	-- display list meant continuous panning rebuilt dozens of lists per frame
	-- (a big CPU spike + stutter). While the camera is moving we only allow a
	-- small trickle of alpha-only rebuilds (geometry-missing rebuilds always go
	-- through). The exact fade opacity isn't noticeable mid-pan, and the fields
	-- snap to their correct opacity within a few frames once the camera settles.
	cameraMoveDraw = -999,       -- drawCounter of the last detected camera move
	cameraSettleDraws = 6,       -- draws of stillness before full-rate rebuilds resume
	movingRebuildsPerFrame = 4,  -- alpha-only rebuild budget while the camera moves
	-- Budget for building brand-new geometry (missing display lists). After a
	-- full recluster hundreds of clusters need fresh lists; building them a few
	-- per frame spreads that cost instead of stuttering in a single frame.
	newBuildsPerFrame = 24,
	newBuildBudgetRemaining = 0,
	-- High-quality font object (loaded in Initialize/ViewResize via WG['fonts'])
	font = nil,
}

local gameStarted = Spring.GetGameFrame() > 0
local lastCheckFrame = Spring.GetGameFrame() - 999
local lastCheckFrameClock = os.clock() - 99
local lastClusterRebuildClock = os.clock() - 99
local lastProcessedFrame = -1
local vsx, vsy = Spring.GetViewGeometry()

--------------------------------------------------------------------------------
-- Speedups
--------------------------------------------------------------------------------

local tableSort = table.sort

local abs = math.abs
local floor = math.floor
local min = math.min
local max = math.max
local clamp = math.clamp
local sqrt = math.sqrt
local mathHuge = math.huge
local cos = math.cos
local sin = math.sin
local rad = math.rad
local atan = math.atan
local tan = math.tan

local glBeginEnd = gl.BeginEnd
local glBlending = gl.Blending
local glCallList = gl.CallList
local glColor = gl.Color
local glCreateList = gl.CreateList
local glDeleteList = gl.DeleteList
local glDepthTest = gl.DepthTest
local glLineWidth = gl.LineWidth
local glMultMatrix = gl.MultMatrix
local glPopMatrix = gl.PopMatrix
local glPushMatrix = gl.PushMatrix
local glScale = gl.Scale
local glText = gl.Text
local glTranslate = gl.Translate
local glVertex = gl.Vertex

local spGetCameraPosition = Spring.GetCameraPosition
local spGetFeaturePosition = Spring.GetFeaturePosition
local spGetFeatureResources = Spring.GetFeatureResources
local spGetFeatureVelocity = Spring.GetFeatureVelocity
local spGetFeatureRadius = Spring.GetFeatureRadius
local spValidFeatureID = Spring.ValidFeatureID
local spGetGroundHeight = Spring.GetGroundHeight
local spIsGUIHidden = Spring.IsGUIHidden
local spTraceScreenRay = Spring.TraceScreenRay
local spGetActiveCommand = Spring.GetActiveCommand
local spGetMapDrawMode = Spring.GetMapDrawMode
local spGetUnitDefID = Spring.GetUnitDefID
local spGetCameraVectors = Spring.GetCameraVectors
local spGetGameFrame = Spring.GetGameFrame

-- TIMING INSTRUMENTATION (set to true, or via WG['reclaimfieldhighlight'].
-- setDebugTiming(true), to enable a periodic timing echo that shows whether the
-- per-frame cost is the update pass or the display-list rebuilds while drawing).
local debugTiming = false
local osClock = os.clock
local timingAccum = {
	updateReclaim = 0, drawWorldText = 0, drawPreUnit = 0, updateFunc = 0,
	rebuilds = 0, -- gradient/edge display-list rebuilds since the last echo
	deferPending = 0,          -- ProcessDeferredFeatures + ProcessPendingFeatureChanges
	reclaimPoll = 0,           -- UpdateFeatureReclaim
	clusterSlice = 0,          -- single-frame coroutine resume slices
	clusterFinalize = 0,       -- finalize step after coroutine completes
	redrawLists = 0,           -- RecreateDisplayListsForVisibleClusters
	maxUpdateReclaim = 0,
	maxDrawPreUnit = 0,
	maxClusterSlice = 0,
	maxClusterFinalize = 0,
	maxRedrawLists = 0,
	spikeMs = 8.0,             -- emit a spike echo when a timed chunk exceeds this
	spikeMinGap = 0.25,        -- min seconds between spike echoes
	lastSpikeClock = -99,
}
local timingCount = 0
local timingInterval = 120 -- echo every N draw calls

--------------------------------------------------------------------------------
-- Helper Functions for Culling and Fading
--------------------------------------------------------------------------------

-- Cached camera state to avoid recalculating every frame
local cachedCameraX, cachedCameraY, cachedCameraZ = 0, 0, 0
local cachedCamFwdX, cachedCamFwdY, cachedCamFwdZ = 0, 0, 1
local cachedCosFrustumAngle = 0 -- Pre-computed cosine of frustum half-angle (avoids trig per-call)
local drawCounter = 0 -- Increments every draw call; works even when game is paused (unlike spGetGameFrame)
local lastCameraUpdateDraw = -999
local cameraMovementThreshold = 10 -- Minimum distance to consider camera moved (in elmos)
local cameraRotationThreshold = 0.01 -- Minimum dot product change to consider camera rotated
local cameraGeneration = 0 -- Increments when camera moves to invalidate visibility cache

-- Check if a point is within the camera view frustum
local function IsInCameraView(x, y, z, radius, currentDrawCount)
	-- Update camera state cache (do this only once per draw call)
	if currentDrawCount ~= lastCameraUpdateDraw then
		local newCamX, newCamY, newCamZ = spGetCameraPosition()
		local camVectors = spGetCameraVectors()
		local newCamForward = camVectors.forward

		-- Check if camera has moved significantly (compare against cached old position)
		local dx = newCamX - cachedCameraX
		local dy = newCamY - cachedCameraY
		local dz = newCamZ - cachedCameraZ
		local moved = (dx*dx + dy*dy + dz*dz) > cameraMovementThreshold * cameraMovementThreshold

		-- Check if camera has rotated significantly (dot product change)
		local oldDot = cachedCamFwdX * newCamForward[1] + cachedCamFwdY * newCamForward[2] + cachedCamFwdZ * newCamForward[3]
		local rotated = oldDot < (1 - cameraRotationThreshold)

		-- Increment cache generation if camera moved or rotated
		if moved or rotated then
			cameraGeneration = cameraGeneration + 1
			-- Record the move so gradient rebuilds can back off while panning.
			animCfg.cameraMoveDraw = currentDrawCount
		end

		-- Update cached camera state
		cachedCameraX, cachedCameraY, cachedCameraZ = newCamX, newCamY, newCamZ
		cachedCamFwdX, cachedCamFwdY, cachedCamFwdZ = newCamForward[1], newCamForward[2], newCamForward[3]

		-- Pre-compute frustum cone cosine (avoids trig per-call)
		local aspect = vsx / vsy
		local vertFOV = rad(45)
		local horizFOV = 2 * atan(tan(vertFOV * 0.5) * aspect)
		local maxHalfAngle = max(vertFOV, horizFOV) * 0.5
		cachedCosFrustumAngle = cos(maxHalfAngle)
		lastCameraUpdateDraw = currentDrawCount
	end

	-- Vector from camera to point
	local dx = x - cachedCameraX
	local dy = y - cachedCameraY
	local dz = z - cachedCameraZ
	local distSq = dx*dx + dy*dy + dz*dz
	local dist = sqrt(distSq)

	-- Skip if too far away (beyond fade distance + radius) - early out
	if dist > fadeEndDistance + radius then
		return false, dist
	end

	-- Normalize direction vector
	if dist < 0.01 then return true, dist end -- Camera is at the point
	local invDist = 1.0 / dist
	dx, dy, dz = dx * invDist, dy * invDist, dz * invDist

	-- Check if point is behind camera (dot product with forward vector)
	local dotForward = dx * cachedCamFwdX + dy * cachedCamFwdY + dz * cachedCamFwdZ
	if dotForward < 0.2 then
		return false, dist
	end

	-- Frustum check: compare dot product directly against pre-computed cosine threshold
	-- cos(angle) > cos(limit) means angle < limit (cosine is decreasing)
	-- Add small margin for cluster radius
	local radiusMargin = radius * invDist * 0.5
	if dotForward < cachedCosFrustumAngle - radiusMargin then
		return false, dist
	end

	return true, dist
end

-- Calculate auto-scaled threshold based on total map metal
local function CalculateAlwaysShowThreshold()
	if totalMapMetal <= 0 then
		return alwaysShowFieldsMinThreshold
	end

	-- Scale threshold based on total map metal
	-- Maps with little metal (e.g., 10k) -> use min threshold (500)
	-- Maps with lots of metal (e.g., 100k+) -> use max threshold (2000)
	local lowMetalMap = 10000 -- Maps with this much or less use min threshold
	local highMetalMap = 100000 -- Maps with this much or more use max threshold

	if totalMapMetal <= lowMetalMap then
		return alwaysShowFieldsMinThreshold
	elseif totalMapMetal >= highMetalMap then
		return alwaysShowFieldsMaxThreshold
	else
		-- Linear interpolation between min and max
		local ratio = (totalMapMetal - lowMetalMap) / (highMetalMap - lowMetalMap)
		local threshold = alwaysShowFieldsMinThreshold + ratio * (alwaysShowFieldsMaxThreshold - alwaysShowFieldsMinThreshold)
		return floor(threshold)
	end
end

-- Calculate opacity multiplier based on distance.
-- bypassFade=true forces full opacity (used for big metal fields that are
-- flagged as always-visible). All other fields smoothly fade between
-- fadeStartDistance and fadeEndDistance so they don't pop in/out on zoom.
local function GetDistanceFadeMultiplier(dist, bypassFade)
	if bypassFade then
		return 1.0
	end

	if dist <= fadeStartDistance then
		return 1.0 -- Full opacity
	elseif dist >= fadeEndDistance then
		return 0.0 -- Completely faded
	else
		-- Linear fade between start and end
		local fadeRange = fadeEndDistance - fadeStartDistance
		local fadeProgress = (dist - fadeStartDistance) / fadeRange
		return 1.0 - fadeProgress
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Data

local screenx, screeny
local dirty = {
	needCluster = false,
	needRedraw = false,
	forceFullRedraw = false,
	regions = {},          -- Track which regions need reclustering
	clusters = {},         -- Track which specific clusters need redrawing
	energyClusters = {},   -- Track which specific energy clusters need redrawing
	useRegional = true,    -- Enable regional optimization
	-- Adaptive reclaim backoff: a decaying tally of how much reclaim churn is
	-- happening (features depleted + cluster values changed per sampled pass).
	-- The busier the map is with reclaimers, the larger this grows, and the
	-- longer we wait between the expensive recluster + display-list rebuild
	-- passes. It decays back to 0 (=> fully responsive) when reclaim stops.
	reclaimChurn = 0,
	reclaimChurnClock = 0,
	removedSinceCluster = 0, -- removals accumulated since last full recluster
}

-- Batch queues and deferred update state (consolidated)
local batch = {
	toRemove = {},              -- Reusable table for batching feature removals
	pendDestructions = {},      -- Queue for batching FeatureDestroyed calls
	pendDestrCount = 0,         -- Count of pending destructions
	pendDestrHead = 0,          -- Cursor into the destruction queue (budgeted drain)
	pendCreations = {},         -- Queue for batching FeatureCreated calls
	pendCreateCount = 0,        -- Count of pending creations
	pendCreateHead = 0,         -- Cursor into the creation queue (budgeted drain)
	affectedFeatures = {},      -- Reusable table for regional clustering
	affectedClusters = {},      -- Reusable table for regional clustering
	deferCreations = {},        -- Features created outside view
	deferDestructions = {},     -- Features destroyed outside view
	deferCreateCount = 0,
	deferDestrCount = 0,
	deferOutOfView = true,      -- Config: defer processing features outside view
	outOfViewMargin = 350,      -- Elmos margin beyond fade distance to still process immediately
	lastDeferFrame = 0,
	deferInterval = 60,         -- Process deferred updates every 60 frames (~2 seconds)
	-- Time-sliced (coroutine) reclustering. A full recluster of a big map (this
	-- one has ~9k features) stalls a frame badly, so the rebuild runs inside a
	-- coroutine that yields once it has spent `clusterJobBudget` seconds this
	-- frame. The previous fields stay on screen until the new set is ready.
	clusterJobActive = false,
	clusterJobCo = nil,
	clusterJobStart = 0,
	clusterJobBudget = 0.002,  -- default clustering slice budget (seconds)
	clusterJobBudgetMin = 0.001,
	clusterJobBudgetMax = 0.0025,
	-- When a hidden layer becomes visible while its clusters are stale, keep it
	-- hidden until the pending time-sliced rebuild atomically swaps in fresh data.
	waitForFreshMetal = false,
	waitForFreshEnergy = false,
	metalRevealPending = false,
	energyRevealPending = false,
	reusedMetalHulls = 0,
	reusedEnergyHulls = 0,
	partialReusedMetalHulls = 0,
	partialReusedEnergyHulls = 0,
	copiedEnergyHulls = 0,
	clusterJobCpu = 0,
	lastClusterJobCpu = 0,
	terrainGeneration = 0,
	clusterJobTerrainGeneration = 0,
	clusterEnergyPositiveCount = 0,
	clusterTracyPhase = nil,
	clusterTracyResource = nil,
	clusterTracyZoneActive = false,
	clusterTracyNames = {
		setup = "W:ReclaimField:Cluster:Setup",
		graph = "W:ReclaimField:Cluster:Graph",
		stats = "W:ReclaimField:Cluster:Stats",
		reuse = "W:ReclaimField:Cluster:ReuseHull",
		partialReuse = "W:ReclaimField:Cluster:PartialReuseHull",
		copyHull = "W:ReclaimField:Cluster:CopyHull",
		sort = "W:ReclaimField:Cluster:Sort",
		split = "W:ReclaimField:Cluster:Split",
		condition = "W:ReclaimField:Cluster:HullCondition",
		monotone = "W:ReclaimField:Cluster:MonotoneHull",
		bounding = "W:ReclaimField:Cluster:BoundingBox",
		subdivide = "W:ReclaimField:Cluster:Subdivide",
		expand = "W:ReclaimField:Cluster:Expand",
		catmull = "W:ReclaimField:Cluster:CatmullRom",
		swap = "W:ReclaimField:Cluster:SwapRecycle",
		text = "W:ReclaimField:Cluster:TextAnchors",
	},
}

-- Tracy zones must not span coroutine suspension. Keep one clustering phase
-- open at a time, close it before yielding, and reopen it on the next resume.
batch.openClusterTracyZone = function()
	if batch.clusterTracyPhase and not batch.clusterTracyZoneActive then
		tracy.ZoneBeginN(batch.clusterTracyPhase)
		batch.clusterTracyZoneActive = true
		if batch.clusterTracyResource then
			tracy.ZoneText(batch.clusterTracyResource)
		end
	end
end

batch.closeClusterTracyZone = function()
	if batch.clusterTracyZoneActive then
		tracy.ZoneEnd()
		batch.clusterTracyZoneActive = false
	end
end

batch.setClusterTracyPhase = function(phase)
	if batch.clusterTracyPhase == phase and batch.clusterTracyZoneActive then
		return
	end
	batch.closeClusterTracyZone()
	batch.clusterTracyPhase = phase
	batch.openClusterTracyZone()
end

batch.finishClusterTracy = function()
	batch.closeClusterTracyZone()
	batch.clusterTracyPhase = nil
	batch.clusterTracyResource = nil
end

batch.yieldClusterJob = function()
	batch.closeClusterTracyZone()
	coroutine.yield()
	batch.openClusterTracyZone()
end

-- Cache to avoid redundant Spring API calls
local lastFlyingCheckFrame = 0 -- Track when we last checked flying features
local validityCheckCounter = 0 -- Rotating counter for validity checks in GameFrame
local lastCameraCheckClock = 0 -- Track when we last checked camera up vector (clock-based for pause support)

-- Per-frame visibility and distance cache to avoid redundant calculations
local clusterVisibilityCache = {} -- {[cid] = {frame, inView, dist, fadeMult}}
local energyClusterVisibilityCache = {} -- {[energyCid] = {frame, inView, dist, fadeMult}}

-- Get cached visibility for a cluster (call once per frame per cluster)
-- Forward declare this early since it's used in draw functions
local GetClusterVisibility

local epsilonSq = epsilon*epsilon
local checkFrequency = 30
local lastFeatureCount = 0
local cachedKnownFeaturesCount = 0 -- Cached count to avoid iterating all features
local featureReclaimScanCounter = 0 -- Rotating cursor for sampled feature-resource checks
local knownFeatureIDs = {} -- Dense feature-ID list for bounded reclaim scans

-- Spatial hash grid for O(k) neighbour queries.
--
-- Previously, adding a feature scanned *every* known feature to find neighbours
-- within `epsilon` (O(n) per add => O(n^2) when a burst of wrecks/eggs spawns,
-- e.g. during game load, big battles or area-reclaim). That O(n^2) burst is the
-- primary source of the reported freezes. The grid buckets features into cells
-- of size `epsilon` so a neighbour lookup only has to visit the 3x3 block of
-- cells around a point (provably exhaustive when cell size == search radius).
--
-- Everything is packed onto one `grid` table (cells + helpers) to keep the main
-- chunk under Lua's 200 local/upvalue limit (see the batch/anim tables above).
-- `grid.buildNeighbors` is assigned later, once `featureNeighborsMatrix` exists.
local grid = {
	cells = {}, -- [cellKey] = { [fid] = feature }
}

do
	local GRID_OFFSET = 8192  -- keeps cell indices non-negative
	local GRID_STRIDE = 32768 -- > 2*GRID_OFFSET so keys never collide
	local cellSize = epsilon
	local cells = grid.cells

	grid.insert = function(featureID, feature)
		local cx = floor(feature.x / cellSize) + GRID_OFFSET
		local cz = floor(feature.z / cellSize) + GRID_OFFSET
		local key = cx * GRID_STRIDE + cz
		local cell = cells[key]
		if not cell then
			cell = {}
			cells[key] = cell
		end
		cell[featureID] = feature
		feature.gridKey = key
	end

	grid.remove = function(featureID, feature)
		local key = feature.gridKey
		if key == nil then return end
		local cell = cells[key]
		if cell then
			cell[featureID] = nil
			if next(cell) == nil then
				cells[key] = nil
			end
		end
		feature.gridKey = nil
	end
end

local featureCountMultiplier = 1 -- Multiplier based on feature count

local allEnergyFieldsDrained = false -- Track if all energy has been reclaimed to skip energy rendering

local minTextAreaLength = (epsilon / 2 + fontSizeMin) / 2
local areaTextMin = 3000
local areaTextRange = (1.75 * minTextAreaLength * (fontSizeMax / fontSizeMin)) ^ 2 - areaTextMin

local drawEnabled = false
local drawEnergyEnabled = false
local actionActive = false
local reclaimerSelected = false
local resBotSelected = false
local IsActiveReclaimCommand

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

-- Populate `featureNeighborsMatrix` for a newly-added feature by visiting only
-- the 3x3 block of grid cells around it. Mirrors the previous full-scan logic,
-- but at O(k) instead of O(n).
-- Assigned here (rather than next to grid.insert/remove) so it captures the
-- `featureNeighborsMatrix` module local instead of a global.
do
	local GRID_OFFSET = 8192
	local GRID_STRIDE = 32768
	local cellSize = epsilon
	local cells = grid.cells

	grid.buildNeighbors = function(featureID, x, z, M_newFeature)
		local M = featureNeighborsMatrix
		local cx = floor(x / cellSize) + GRID_OFFSET
		local cz = floor(z / cellSize) + GRID_OFFSET
		for gx = cx - 1, cx + 1 do
			local base = gx * GRID_STRIDE
			for gz = cz - 1, cz + 1 do
				local cell = cells[base + gz]
				if cell then
					for fid2, feat2 in pairs(cell) do
						local dx = x - feat2.x
						local dz = z - feat2.z
						local distSq = dx * dx + dz * dz
						if distSq <= epsilonSq then
							local row = M[fid2]
							if row then
								row[featureID] = true
								M_newFeature[fid2] = true
							end
						end
					end
				end
			end
		end
	end
end

-- Energy field tables (separate clustering)
local energyFeatureClusters
local energyFeatureConvexHulls

-- Per-cluster display lists for incremental updates
local clusterDisplayLists = {} -- {[cid] = {gradient = listID, edge = listID, text = listID}}
local energyClusterDisplayLists = {} -- {[energyCid] = {gradient = listID, edge = listID, text = listID}}

-- Per-cluster state tracking to detect when recreating display lists is actually needed
local clusterStateHashes = {} -- {[cid] = hash} - tracks cluster data state
local energyClusterStateHashes = {} -- {[energyCid] = hash} - tracks energy cluster data state

--------------------------------------------------------------------------------
-- Animation / identity tracking
--------------------------------------------------------------------------------
-- Each cluster gets a stable uid that survives reclustering (when membership
-- overlap is high enough). New uids fade in; lost uids fade out (rendered from
-- a captured snapshot of their hull); changed uids briefly pulse expand/shrink.
-- All anim state packed into one table to stay under Lua's 200-upvalue limit.

local animState = {
	nextUID = 1,

	-- Per-uid live anim state: {alpha, scale, animType, animT0, animDur}
	clusterAnims = {},        -- metal, [uid] = state
	energyClusterAnims = {},  -- energy, [uid] = state

	-- Snapshot of clusters from the previous clustering pass (for identity match).
	-- Feature-to-uid ownership lives directly on each feature, avoiding a reverse
	-- index rebuild over every snapshot member after each clustering job.
	prevSnapshot = {},        -- metal, [uid] = {fidCount, value}
	prevEnergySnapshot = {},  -- energy

	-- Clusters that disappeared and are currently fading out. They own their
	-- own hull copies and display lists.
	fading = {},              -- metal, [uid] = entry
	fadingEnergy = {},        -- energy

	-- Group toggle fade (fields turning on/off as a whole). 0..1
	toggleMetal = 0,
	toggleMetalTarget = 0,
	toggleEnergy = 0,
	toggleEnergyTarget = 0,

	lastTickClock = os.clock(),

	-- Pre-clustering snapshot of hulls (deep-copied) so we can render fadeout
	-- for clusters that disappear after the next clustering pass.
	preHullCopies = {},        -- metal, [uid] = {hull, center, text, font, textX, textZ, alpha, isEnergy}
	preEnergyHullCopies = {},  -- energy

	-- Forward-declared functions (filled in below). Stored on the table to
	-- avoid creating extra upvalues in the chunk.
	CapturePreClusteringSnapshot = nil,
	SyncClusterIdentitiesAfterClustering = nil,
	TickClusterAnimations = nil,
	DeleteFadingCluster = nil,
	GetClusterAnimAlphaAndScale = nil,
	CreateFadingClusterDisplayList = nil,
}

-- Helper function to compute a simple hash/signature of cluster state
local function ComputeClusterStateHash(cluster, hull)
	if not cluster or not hull then return 0 end
	-- Hash based on: member count, total value, center position, hull vertex count
	-- This is a simple hash - not cryptographic, just for change detection
	local memberCount = cluster.members and #cluster.members or 0
	local value = cluster.metal or cluster.energy or 0
	local cx = cluster.center and cluster.center.x or 0
	local cy = cluster.center and cluster.center.y or 0
	local cz = cluster.center and cluster.center.z or 0
	local hullSize = #hull

	-- Simple hash combination (good enough for change detection)
	return memberCount * 1000000 + floor(value) * 1000 + floor(cx + cz) + hullSize * 100 + floor(cy)
end

--------------------------------------------------------------------------------
-- Animation helpers
--------------------------------------------------------------------------------

-- Smoothstep ease for animation curves
local function easeInOut(t)
	if t <= 0 then return 0 end
	if t >= 1 then return 1 end
	return t * t * (3 - 2 * t)
end

-- Pulse curve: 0 -> 1 -> 0 over [0,1] (peak at 0.5). Smooth.
local function pulseCurve(t)
	if t <= 0 or t >= 1 then return 0 end
	-- sin(pi * t) gives a nice 0->1->0 hump
	return sin(t * 3.14159265)
end

-- Forward declarations referenced inside hooks below
-- (Stored on animState to avoid eating top-level upvalue slots.)

-- Reusable scratch table for syncSide() overlap tallies (cleared per cluster).
local sharedTally = {}

-- Capture the current cluster state so that, if any clusters disappear after
-- the upcoming reclustering, we can keep rendering them while they fade out.
--
-- The reclustering replaces the global featureClusters/featureConvexHulls
-- arrays with brand-new tables, and the prior cluster/hull tables are kept
-- alive solely by the references we save here. So we only need to remember
-- references (no deep copies). syncSide() promotes the small subset that
-- actually disappeared into long-lived fading entries.
animState.CapturePreClusteringSnapshot = function()
	local clusterAnims = animState.clusterAnims
	local energyClusterAnims = animState.energyClusterAnims
	local preHullCopies = animState.preHullCopies
	local preEnergyHullCopies = animState.preEnergyHullCopies
	-- Metal
	for cid = 1, #featureClusters do
		local cluster = featureClusters[cid]
		local hull = featureConvexHulls[cid]
		if cluster and cluster.uid and hull and cluster.center then
			local a = clusterAnims[cluster.uid]
			local entry = preHullCopies[cluster.uid]
			if entry then
				entry.cluster = cluster
				entry.hull = hull
				entry.alpha = (a and a.alpha) or 1
			else
				preHullCopies[cluster.uid] = {
					cluster = cluster,
					hull = hull,
					alpha = (a and a.alpha) or 1,
				}
			end
		end
	end
	-- Energy
	if showEnergyFields then
		for cid = 1, #energyFeatureClusters do
			local cluster = energyFeatureClusters[cid]
			local hull = energyFeatureConvexHulls[cid]
			if cluster and cluster.uid and hull and cluster.center then
				local a = energyClusterAnims[cluster.uid]
				local entry = preEnergyHullCopies[cluster.uid]
				if entry then
					entry.cluster = cluster
					entry.hull = hull
					entry.alpha = (a and a.alpha) or 1
				else
					preEnergyHullCopies[cluster.uid] = {
						cluster = cluster,
						hull = hull,
						alpha = (a and a.alpha) or 1,
					}
				end
			end
		end
	end
end

-- Match new clusters to previous snapshot uids, assign uids, register animations,
-- and convert dropped uids into fading-out entries.
local function syncSide(isEnergy)
	local clusters = isEnergy and energyFeatureClusters or featureClusters
	local snapshot = isEnergy and animState.prevEnergySnapshot or animState.prevSnapshot
	local newSnapshot = {}
	local anims = isEnergy and animState.energyClusterAnims or animState.clusterAnims
	local hullCopies = isEnergy and animState.preEnergyHullCopies or animState.preHullCopies
	local fading = isEnergy and animState.fadingEnergy or animState.fading
	local uidField = isEnergy and "energyClusterUid" or "metalClusterUid"

	local now = os.clock()
	local matchedOldUids = {}

	for cid = 1, #clusters do
		local cluster = clusters[cid]
		-- Skip "split parent" placeholders (font==0 indicates a cluster that was
		-- split into sub-clusters; only the children carry visible geometry).
		if cluster and (cluster.font ~= 0) and cluster.members then
			local members = cluster.members
			local count = #members
			local exactUid = cluster.identityUid
			local membersAlreadyOwned = cluster.identityMembersCurrent
			cluster.identityUid = nil
			cluster.identityMembersCurrent = nil
			-- Tally overlap with each old uid (reuse a single table across
			-- iterations to avoid one tally allocation per cluster).
			local bestOldUid, bestOverlap
			if exactUid and snapshot[exactUid] and not matchedOldUids[exactUid] then
				bestOldUid, bestOverlap = exactUid, count
			else
				bestOverlap = 0
				local tally = sharedTally
				for k in pairs(tally) do tally[k] = nil end
				for i = 1, count do
					local oldUid = members[i][uidField]
					if oldUid and snapshot[oldUid] and not matchedOldUids[oldUid] then
						tally[oldUid] = (tally[oldUid] or 0) + 1
					end
				end
				for oldUid, overlap in pairs(tally) do
					if overlap > bestOverlap then
						bestOverlap = overlap
						bestOldUid = oldUid
					end
				end
			end

			local uid
			local pulseDir = 0  -- -1 shrink, +1 expand, 0 no pulse
			if bestOldUid then
				local oldSnap = snapshot[bestOldUid]
				local oldCount = oldSnap.fidCount
				local maxCount = oldCount
				if count > maxCount then maxCount = count end
				if maxCount > 0 and (bestOverlap / maxCount) >= animCfg.identityMinOverlap then
					uid = bestOldUid
					matchedOldUids[bestOldUid] = true
					-- Pulse only on meaningful resource change. Compare new vs
					-- old cluster value (metal or energy depending on side).
					local newValue = (isEnergy and cluster.energy or cluster.metal) or 0
					local oldValue = oldSnap.value or 0
					local denom = oldValue
					if newValue > denom then denom = newValue end
					if denom > 0 then
						local rel = (newValue - oldValue) / denom
						if rel >= animCfg.pulseMinRelativeChange then
							pulseDir = 1
						elseif rel <= -animCfg.pulseMinRelativeChange then
							pulseDir = -1
						end
					end
				end
			end

			if not uid then
				uid = animState.nextUID
				animState.nextUID = animState.nextUID + 1
				-- New cluster: fade in
				anims[uid] = {
					alpha = 0,
					scale = 1,
					animType = "fadein",
					animT0 = now,
					animDur = animCfg.fadeInDuration,
				}
			else
				-- Surviving cluster: keep existing anim entry; trigger pulse if value changed enough
				local a = anims[uid]
				if not a then
					a = { alpha = 1, scale = 1 }
					anims[uid] = a
				end
				if pulseDir ~= 0 then
					a.animType = (pulseDir > 0) and "pulseExpand" or "pulseShrink"
					a.animT0 = now
					a.animDur = (pulseDir > 0) and animCfg.pulseExpandDuration or animCfg.pulseShrinkDuration
				end
				hullCopies[uid] = nil
			end

			cluster.uid = uid
			if not membersAlreadyOwned or uid ~= exactUid then
				for i = 1, count do
					members[i][uidField] = uid
				end
			end
			newSnapshot[uid] = {
				fidCount = count,
				value = (isEnergy and cluster.energy or cluster.metal) or 0,
			}
		end
	end

	-- Any remaining hull copies are clusters that disappeared -> fade them out.
	-- The snapshot only holds references; promote the few vanished entries into
	-- self-contained fading records by pulling fields off the saved cluster ref.
	for oldUid, hc in pairs(hullCopies) do
		if not matchedOldUids[oldUid] then
			if not fading[oldUid] then
				local startAlpha = hc.alpha or 1
				local liveAnim = anims[oldUid]
				if liveAnim and liveAnim.alpha then
					startAlpha = liveAnim.alpha
				end
				if startAlpha > 0.01 then
					local oldCluster = hc.cluster
					local center = oldCluster.center
					fading[oldUid] = {
						hullCopy = hc.hull,
						center = center,
						text = oldCluster.text,
						font = oldCluster.font or fontSizeMin,
						textX = oldCluster.textX or (center and center.x),
						textZ = oldCluster.textZ or (center and center.z),
						isEnergy = isEnergy,
						t0 = now,
						duration = animCfg.fadeOutDuration,
						startAlpha = startAlpha,
						alpha = startAlpha,
					}
				end
			end
			anims[oldUid] = nil
		end
		hullCopies[oldUid] = nil
	end

	-- Drop anim entries whose uid no longer corresponds to a live cluster and
	-- isn't being tracked by fading either.
	for uid in pairs(anims) do
		if not newSnapshot[uid] and not fading[uid] then
			anims[uid] = nil
		end
	end

	if isEnergy then
		animState.prevEnergySnapshot = newSnapshot
	else
		animState.prevSnapshot = newSnapshot
	end
end

animState.SyncClusterIdentitiesAfterClustering = function()
	syncSide(false)
	if showEnergyFields then
		syncSide(true)
	else
		for uid in pairs(animState.preEnergyHullCopies) do
			animState.preEnergyHullCopies[uid] = nil
		end
		for uid, entry in pairs(animState.fadingEnergy) do
			-- Force quick fadeout when energy has been disabled
			if entry.t0 then entry.t0 = entry.t0 - entry.duration end
		end
	end
end

-- Delete display lists belonging to a fading cluster entry
animState.DeleteFadingCluster = function(uid, isEnergy)
	local fading = isEnergy and animState.fadingEnergy or animState.fading
	local entry = fading[uid]
	if not entry then return end
	if entry.displayLists then
		if entry.displayLists.gradient then glDeleteList(entry.displayLists.gradient) end
		if entry.displayLists.edge then glDeleteList(entry.displayLists.edge) end
		if entry.displayLists.text then glDeleteList(entry.displayLists.text) end
		entry.displayLists = nil
	end
	fading[uid] = nil
end

-- Compute the current effective per-cluster alpha (animation alpha * group toggle fade
-- * smoothed distance/frustum visibility) and current pulse scale. Returns alpha, scale.
animState.GetClusterAnimAlphaAndScale = function(uid, isEnergy)
	local anims = isEnergy and animState.energyClusterAnims or animState.clusterAnims
	local toggle = isEnergy and animState.toggleEnergy or animState.toggleMetal
	local a = uid and anims[uid]
	if not a then
		-- No anim entry: assume fully visible at the current toggle level.
		return toggle, 1
	end
	local vis = a.vis or 1
	return a.alpha * toggle * vis, a.scale or 1
end

-- Inline per-cluster anim tick logic (called for both metal and energy
-- collections). Hoisted to module scope so it isn't reallocated as a closure
-- on every TickClusterAnimations call.
local _tickAnimsVisInStep = 0
local _tickAnimsVisOutStep = 0
local _tickAnimsCurrentDraw = 0
local _tickAnimsNow = 0
local function _tickAnimsApply(anims)
	local now = _tickAnimsNow
	local visInStep = _tickAnimsVisInStep
	local visOutStep = _tickAnimsVisOutStep
	local currentDraw = _tickAnimsCurrentDraw
	local pulseExpandDelta = animCfg.pulseExpandScale - 1
	local pulseShrinkDelta = 1 - animCfg.pulseShrinkScale
	for _uid, a in pairs(anims) do
		local t = a.animType
		if t == "fadein" then
			local p = (now - a.animT0) / a.animDur
			if p >= 1 then
				a.alpha = 1
				a.animType = nil
			else
				a.alpha = easeInOut(p)
			end
		elseif t == "pulseExpand" then
			local p = (now - a.animT0) / a.animDur
			if p >= 1 then
				a.scale = 1
				a.animType = nil
			else
				a.scale = 1 + pulseExpandDelta * pulseCurve(p)
			end
		elseif t == "pulseShrink" then
			local p = (now - a.animT0) / a.animDur
			if p >= 1 then
				a.scale = 1
				a.animType = nil
			else
				a.scale = 1 - pulseShrinkDelta * pulseCurve(p)
			end
		else
			if not a.alpha or a.alpha < 1 then a.alpha = 1 end
			if not a.scale or a.scale ~= 1 then a.scale = 1 end
		end

		-- Smoothed visibility (handles distance fade + frustum pop-in/out).
		-- If GetClusterVisibility hasn't observed this cluster within the
		-- last frame, treat it as hidden so it fades out cleanly.
		local target = a.visTarget or 0
		local vf = a.visFrame
		if not vf or (currentDraw - vf) > 1 then
			target = 0
		end
		local vis = a.vis or 0
		if vis ~= target then
			if vis < target then
				vis = vis + visInStep
				if vis > target then vis = target end
			else
				vis = vis - visOutStep
				if vis < target then vis = target end
			end
			a.vis = vis
		end
	end
end

-- Tick all animations. Called once per draw.
animState.TickClusterAnimations = function(now)
	local dt = now - animState.lastTickClock
	if dt <= 0 then return end
	animState.lastTickClock = now
	local toggleStep = dt / animCfg.toggleFadeDuration

	-- Toggle fades (metal/energy group)
	if animState.toggleMetal ~= animState.toggleMetalTarget then
		if animState.toggleMetal < animState.toggleMetalTarget then
			animState.toggleMetal = animState.toggleMetal + toggleStep
			if animState.toggleMetal > animState.toggleMetalTarget then animState.toggleMetal = animState.toggleMetalTarget end
		else
			animState.toggleMetal = animState.toggleMetal - toggleStep
			if animState.toggleMetal < animState.toggleMetalTarget then animState.toggleMetal = animState.toggleMetalTarget end
		end
	end
	if animState.toggleEnergy ~= animState.toggleEnergyTarget then
		if animState.toggleEnergy < animState.toggleEnergyTarget then
			animState.toggleEnergy = animState.toggleEnergy + toggleStep
			if animState.toggleEnergy > animState.toggleEnergyTarget then animState.toggleEnergy = animState.toggleEnergyTarget end
		else
			animState.toggleEnergy = animState.toggleEnergy - toggleStep
			if animState.toggleEnergy < animState.toggleEnergyTarget then animState.toggleEnergy = animState.toggleEnergyTarget end
		end
	end

	-- Stash per-tick parameters into module locals so the hoisted apply fn
	-- doesn't need them as upvalues from a per-call closure.
	_tickAnimsNow = now
	_tickAnimsVisInStep = dt / animCfg.fadeInDuration
	_tickAnimsVisOutStep = dt / animCfg.fadeOutDuration
	_tickAnimsCurrentDraw = drawCounter
	_tickAnimsApply(animState.clusterAnims)
	_tickAnimsApply(animState.energyClusterAnims)

	-- Fading-out clusters: progress alpha and remove when finished.
	local DeleteFading = animState.DeleteFadingCluster
	for uid, entry in pairs(animState.fading) do
		local p = (now - entry.t0) / entry.duration
		if p >= 1 then
			DeleteFading(uid, false)
		else
			entry.alpha = entry.startAlpha * (1 - easeInOut(p))
		end
	end
	for uid, entry in pairs(animState.fadingEnergy) do
		local p = (now - entry.t0) / entry.duration
		if p >= 1 then
			DeleteFading(uid, true)
		else
			entry.alpha = entry.startAlpha * (1 - easeInOut(p))
		end
	end
end

-- Visibility caching helper function

-- Check if a position is within view + margin (for deferred updates)
local function IsPositionNearView(x, y, z)
	if not batch.deferOutOfView then
		return true -- Always process if deferring is disabled
	end

	local dx, dy, dz = x - cachedCameraX, y - cachedCameraY, z - cachedCameraZ
	local distSq = dx * dx + dy * dy + dz * dz
	local maxDist = fadeEndDistance + batch.outOfViewMargin

	-- Quick distance check - if beyond max distance, definitely out of view
	if distSq > maxDist * maxDist then
		return false
	end

	-- If within fade start distance, definitely process it
	if distSq <= fadeStartDistance * fadeStartDistance then
		return true
	end

	-- Use cached camera forward vector for frustum check
	local dist = sqrt(distSq)
	if dist > 0.001 then
		local invDist = 1.0 / dist
		local dotProduct = dx * invDist * cachedCamFwdX + dy * invDist * cachedCamFwdY + dz * invDist * cachedCamFwdZ
		if dotProduct < -0.3 then
			return false
		end
	end

	return true -- Close enough and in front, process immediately
end

-- Get cached visibility for a cluster (call once per frame per cluster)
GetClusterVisibility = function(cid, isEnergy, currentDrawCount)
	local cache = isEnergy and energyClusterVisibilityCache or clusterVisibilityCache
	local clusters = isEnergy and energyFeatureClusters or featureClusters

	-- Check if we have a valid cache for this draw call AND camera generation
	local cached = cache[cid]
	if cached and cached.frame == currentDrawCount and cached.generation == cameraGeneration then
		return cached.inView, cached.dist, cached.fadeMult
	end

	-- Compute visibility for this cluster
	local cluster = clusters[cid]
	if not cluster or not cluster.center then
		return false, 0, 0
	end

	-- Pre-gamestart: show all metal fields regardless of camera position/distance
	if not gameStarted and not isEnergy then
		local entry = cache[cid]
		if entry then
			entry.frame = currentDrawCount
			entry.generation = cameraGeneration
			entry.inView = true
			entry.dist = 0
			entry.fadeMult = 1
		else
			cache[cid] = { frame = currentDrawCount, generation = cameraGeneration, inView = true, dist = 0, fadeMult = 1 }
		end
		return true, 0, 1
	end

	local center = cluster.center
	-- Pre-compute cluster radius once (cache it in the cluster if not present)
	if not cluster.radius then
		local cdx = cluster.dx or 0
		local cdz = cluster.dz or 0
		cluster.radius = sqrt(cdx*cdx + cdz*cdz) * 0.5
	end

	-- For metal fields with alwaysShowFields enabled, bypass distance culling if above threshold
	local inView, dist
	local meetsThreshold = not isEnergy and cluster.metal and cluster.metal >= alwaysShowFieldsThreshold
	if alwaysShowFields and not isEnergy and meetsThreshold then
		-- Always in view for metal fields when option is enabled and above threshold
		local dx = center.x - cachedCameraX
		local dy = center.y - cachedCameraY
		local dz = center.z - cachedCameraZ
		dist = sqrt(dx*dx + dy*dy + dz*dz)
		inView = true
	else
		inView, dist = IsInCameraView(center.x, center.y, center.z, cluster.radius, currentDrawCount)
	end

	local fadeMult = 0

	if inView then
		-- Only big metal fields above the always-show threshold bypass distance
		-- fade; small fields fade smoothly so they don't pop on zoom.
		local bypassFade = alwaysShowFields and not isEnergy and meetsThreshold
		fadeMult = GetDistanceFadeMultiplier(dist, bypassFade)
		-- Early reject if too faded (but not for metal fields with alwaysShowFields above threshold)
		if fadeMult < 0.01 and not bypassFade then
			inView = false
		end
	end

	-- Cache the result (reuse existing table to reduce GC pressure)
	local cached = cache[cid]
	if cached then
		cached.frame = currentDrawCount
		cached.generation = cameraGeneration
		cached.inView = inView
		cached.dist = dist
		cached.fadeMult = fadeMult
	else
		cache[cid] = {
			frame = currentDrawCount,
			generation = cameraGeneration,
			inView = inView,
			dist = dist,
			fadeMult = fadeMult
		}
	end

	-- Push the latest visibility target into the per-cluster anim entry so
	-- TickClusterAnimations can smoothly tween the cluster's vis multiplier
	-- (handles distance fade and frustum culling without popping).
	if cluster.uid then
		local anims = isEnergy and animState.energyClusterAnims or animState.clusterAnims
		local a = anims[cluster.uid]
		if a then
			local target = inView and fadeMult or 0
			-- Snap on first observation OR after a long absence (cluster was
			-- off-screen, draw was toggled off, or otherwise not ticked for a
			-- while). Without this, after a deselect/reselect cycle `vis` is
			-- stuck near 0 and the text takes the full fadeIn duration on top
			-- of the group toggle fade to become visible — appearing as a
			-- multi-second delay.
			local prevFrame = a.visFrame
			if a.vis == nil or not prevFrame or (currentDrawCount - prevFrame) > 2 then
				a.vis = target
			end
			a.visTarget = target
			a.visFrame = currentDrawCount
		end
	end

	return inView, dist, fadeMult
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Cluster post-processing
-- Convex hull outlines and text areas

local cameraScale = 1
local processCluster
local recycleHull
local FormatResourceText
do
	local maybeYieldClusterWork
	local function getClusterStats(cluster, points, resourceType)
		batch.setClusterTracyPhase(batch.clusterTracyNames.stats)
		local total = 0
		local maxRadius = 0
		local xmin, xmax, zmin, zmax = mathHuge, -mathHuge, mathHuge, -mathHuge
		for j = 1, #points do
			local point = points[j]
			total = total + point[resourceType]
			if point.radius and point.radius > maxRadius then
				maxRadius = point.radius
			end
			local x, z = point.x, point.z
			if x < xmin then xmin = x end
			if x > xmax then xmax = x end
			if z < zmin then zmin = z end
			if z > zmax then zmax = z end
			maybeYieldClusterWork(1)
		end
		cluster[resourceType] = total
		cluster.text = FormatResourceText(total)
		return max(maxRadius, 20), xmin, xmax, zmin, zmax
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

		-- Store dimensions for potential splitting later
		cluster.width = xmax - xmin
		cluster.depth = zmax - zmin

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

	-- Shared cluster-job yield helper for heavy hull construction loops.
	local clusterHotLoopCounter = 0
	maybeYieldClusterWork = function(step)
		if not batch.clusterJobActive then return end
		clusterHotLoopCounter = clusterHotLoopCounter + (step or 1)
		if clusterHotLoopCounter >= 64 then
			clusterHotLoopCounter = 0
			if osClock() - batch.clusterJobStart >= batch.clusterJobBudget then
				batch.yieldClusterJob()
			end
		end
	end

	---Filter a set of points to give a much smaller set of candidates for constructing
	---the convex hull of the entire set. This can save time on building the hull.
	---Credit: mindthenerd.blogspot.ru/2012/05/fastest-convex-hull-algorithm-ever.html
	---Also: www-cgrl.cs.mcgill.ca/~godfried/publications/fast.convex.hull.algorithm.pdf
	local function convexSetConditioning(points)
		batch.setClusterTracyPhase(batch.clusterTracyNames.condition)
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
			maybeYieldClusterWork(1)
		end

		-- (4) The second pass removes remaining points that are inside the inner
		-- rectangle. Compact in place instead of repeatedly shifting the array.
		-- The last point is intentionally retained, matching the previous reverse
		-- removal loop which stopped at #remaining - 1.
		local remainingCount = #remaining
		local lastPoint = remaining[remainingCount]
		local writeIndex = 1
		for readIndex = 1, remainingCount - 1 do
			local point = remaining[readIndex]
			local x, z = point.x, point.z
			if not (x > rxmin and x < rxmax and z > rzmin and z < rzmax) then
				remaining[writeIndex] = point
				writeIndex = writeIndex + 1
			end
			maybeYieldClusterWork(1)
		end
		remaining[writeIndex] = lastPoint
		for i = writeIndex + 1, remainingCount do
			remaining[i] = nil
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
			batch.setClusterTracyPhase(batch.clusterTracyNames.monotone)
			local numPoints = #points
			if numPoints < 3 then return end
			-- tableSort(points, sortMonotonic) -- Moved to previous, shared step.

			local lower = {}
			for i = 1, numPoints do
				local point = points[i]
				while (#lower >= 2 and cross(lower[#lower - 1], lower[#lower], point) <= 0) do
					lower[#lower] = nil
				end
				lower[#lower + 1] = point
				maybeYieldClusterWork(1)
			end

			local upper = {}
			for i = numPoints, 1, -1 do
				local point = points[i]
				while (#upper >= 2 and cross(upper[#upper - 1], upper[#upper], point) <= 0) do
					upper[#upper] = nil
				end
				upper[#upper + 1] = point
				maybeYieldClusterWork(1)
			end

			upper[#upper] = nil
			lower[#lower] = nil
			for i = 1, #lower do
				upper[#upper + 1] = lower[i]
			end
			return upper
		end
	end

	-- Point recycling pool: eliminates GC pressure from hull point tables
	local pointPool = {}
	local pointPoolTop = 0

	local function acquirePoint(x, y, z)
		if pointPoolTop > 0 then
			local pt = pointPool[pointPoolTop]
			pointPoolTop = pointPoolTop - 1
			pt.x, pt.y, pt.z = x, y, z
			return pt
		end
		return {x = x, y = y, z = z}
	end

	recycleHull = function(hull)
		if not hull then return end
		for i = 1, #hull do
			local pt = hull[i]
			if pt and not pt.fid then
				pointPoolTop = pointPoolTop + 1
				pointPool[pointPoolTop] = pt
			end
			hull[i] = nil
		end
	end

	local function BoundingBox(cluster, points, maxRadius)
		batch.setClusterTracyPhase(batch.clusterTracyNames.bounding)
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
				convexHull[i + 1] = acquirePoint(
					x,
					max(0, spGetGroundHeight(x, z)),
					z
				)
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
					acquirePoint(x1, max(0, spGetGroundHeight(x1, z1)), z1),
					acquirePoint(x2, max(0, spGetGroundHeight(x2, z2)), z2),
					acquirePoint(x3, max(0, spGetGroundHeight(x3, z3)), z3),
					acquirePoint(x4, max(0, spGetGroundHeight(x4, z4)), z4)
				}
			else
				-- Fall back to simple box if points are too close
				local expandDist = maxRadius * 1.2 + 10
				local xmin = cluster.xmin - expandDist
				local xmax = cluster.xmax + expandDist
				local zmin = cluster.zmin - expandDist
				local zmax = cluster.zmax + expandDist

				convexHull = {
					acquirePoint(xmin, max(0, spGetGroundHeight(xmin, zmin)), zmin),
					acquirePoint(xmax, max(0, spGetGroundHeight(xmax, zmin)), zmin),
					acquirePoint(xmax, max(0, spGetGroundHeight(xmax, zmax)), zmax),
					acquirePoint(xmin, max(0, spGetGroundHeight(xmin, zmax)), zmax)
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

	-- Reusable buffers for hull processing (reduces GC pressure)
	local subdividedBuf = {}
	local subdividedBufLen = 0
	local expandedBuf = {}
	local catmullBasis = {}
	local catmullBasisSegments = 0
	local function getGeometrySegments()
		if smoothingSegments <= 0 then
			return 0
		end
		local zoomBonus = cameraScale <= 1.5 and 2 or (cameraScale <= 2.5 and 1 or 0)
		return smoothingSegments + zoomBonus
	end

	local function getCatmullBasis(segmentsPerEdge)
		if catmullBasisSegments == segmentsPerEdge then
			return catmullBasis
		end

		local previousCount = catmullBasisSegments
		for seg = 0, segmentsPerEdge - 1 do
			local t = seg / segmentsPerEdge
			local t2 = t * t
			local t3 = t2 * t
			local coefficients = catmullBasis[seg + 1]
			if not coefficients then
				coefficients = {}
				catmullBasis[seg + 1] = coefficients
			end
			coefficients[1] = -0.5 * t3 + t2 - 0.5 * t
			coefficients[2] = 1.5 * t3 - 2.5 * t2 + 1.0
			coefficients[3] = -1.5 * t3 + 2.0 * t2 + 0.5 * t
			coefficients[4] = 0.5 * t3 - 0.5 * t2
		end
		for i = segmentsPerEdge + 1, previousCount do
			catmullBasis[i] = nil
		end
		catmullBasisSegments = segmentsPerEdge
		return catmullBasis
	end

	-- Subdivide long edges in hull to ensure smooth expansion
	local function subdivideHull(hull, maxEdgeLength)
		batch.setClusterTracyPhase(batch.clusterTracyNames.subdivide)
		if not hull or #hull < 3 then return hull end

		local count = 0
		local n = #hull

		for i = 1, n do
			local curr = hull[i]
			local next = hull[i == n and 1 or i + 1]

			-- Add current vertex
			count = count + 1
			local entry = subdividedBuf[count]
			if entry then
				entry.x = curr.x
				entry.y = curr.y
				entry.z = curr.z
			else
				subdividedBuf[count] = {x = curr.x, y = curr.y, z = curr.z}
			end

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
					count = count + 1
					local entry2 = subdividedBuf[count]
					if entry2 then
						entry2.x = interpX
						entry2.y = max(0, spGetGroundHeight(interpX, interpZ))
						entry2.z = interpZ
					else
						subdividedBuf[count] = {
							x = interpX,
							y = max(0, spGetGroundHeight(interpX, interpZ)),
							z = interpZ
						}
					end
					maybeYieldClusterWork(1)
				end
			end
			maybeYieldClusterWork(1)
		end

		-- Clear excess entries from previous larger use
		for i = count + 1, subdividedBufLen do
			subdividedBuf[i] = nil
		end
		subdividedBufLen = count

		return subdividedBuf
	end

	-- Expand hull outward by a margin and create rounded corners with Catmull-Rom smoothing
	local function expandAndSmoothHull(hull, expandDist, segmentsPerEdge)
		if not hull or #hull < 3 then return hull end

		-- Subdivide long edges first to ensure smooth, even expansion
		-- Use expandDist as guide for max edge length (want multiple points per expansion distance)
		local maxEdgeLength = max(expandDist * 1.5, 80)  -- At least one subdivision per ~expansion distance
		hull = subdivideHull(hull, maxEdgeLength)

		batch.setClusterTracyPhase(batch.clusterTracyNames.expand)
		local n = #hull

		-- Calculate centroid for radial expansion
		local cx, cz = 0, 0
		for i = 1, n do
			cx = cx + hull[i].x
			cz = cz + hull[i].z
			maybeYieldClusterWork(1)
		end
		cx = cx / n
		cz = cz / n

		-- First pass: expand all vertices outward using a blend of radial and normal-based expansion
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

			local entry = expandedBuf[i]
			if entry then
				entry.x = newX
				entry.y = max(0, spGetGroundHeight(newX, newZ))
				entry.z = newZ
			else
				expandedBuf[i] = {
					x = newX,
					y = max(0, spGetGroundHeight(newX, newZ)),
					z = newZ
				}
			end
			maybeYieldClusterWork(1)
		end

		-- If smoothing disabled, copy from buffer (can't return shared buffer)
		if segmentsPerEdge <= 0 then
			local result = {}
			for i = 1, n do
				local e = expandedBuf[i]
				result[i] = acquirePoint(e.x, e.y, e.z)
				maybeYieldClusterWork(1)
			end
			return result
		end

		-- Second pass: Apply Catmull-Rom spline interpolation for smooth curves
		batch.setClusterTracyPhase(batch.clusterTracyNames.catmull)
		local smoothed = {}
		local basis = getCatmullBasis(segmentsPerEdge)

		for i = 1, n do
			local p0 = expandedBuf[i == 1 and n or i - 1]
			local p1 = expandedBuf[i]
			local p2 = expandedBuf[i == n and 1 or i + 1]
			local p3 = expandedBuf[(i + 1) % n + 1]

			-- Catmull-Rom spline between p1 and p2
			for seg = 0, segmentsPerEdge - 1 do
				local coefficients = basis[seg + 1]
				local c0, c1, c2, c3 = coefficients[1], coefficients[2], coefficients[3], coefficients[4]

				local newX = c0 * p0.x + c1 * p1.x + c2 * p2.x + c3 * p3.x
				local newZ = c0 * p0.z + c1 * p1.z + c2 * p2.z + c3 * p3.z
				-- Interpolate Y smoothly using the spline
				local newY = c0 * p0.y + c1 * p1.y + c2 * p2.y + c3 * p3.y

				smoothed[#smoothed + 1] = acquirePoint(newX, newY, newZ)
				maybeYieldClusterWork(1)
			end
			maybeYieldClusterWork(1)
		end

		return smoothed
	end

	-- Split a large cluster into smaller sub-clusters using spatial subdivision
	local function splitLargeCluster(points, clusterWidth, clusterDepth, xmin, xmax, zmin, zmax)
		batch.setClusterTracyPhase(batch.clusterTracyNames.split)
		-- Calculate how many subdivisions we need
		local xDivisions = math.ceil(clusterWidth / maxClusterSize)
		local zDivisions = math.ceil(clusterDepth / maxClusterSize)

		-- If no splitting needed, return nil
		if xDivisions <= 1 and zDivisions <= 1 then
			return nil
		end

		-- Create grid cells
		local cellWidth = (xmax - xmin) / xDivisions
		local cellDepth = (zmax - zmin) / zDivisions
		local subClusters = {}

		-- Assign each point to a grid cell
		for i = 1, #points do
			local point = points[i]
			local cellX = math.min(math.floor((point.x - xmin) / cellWidth), xDivisions - 1)
			local cellZ = math.min(math.floor((point.z - zmin) / cellDepth), zDivisions - 1)
			local cellKey = cellX * zDivisions + cellZ + 1

			if not subClusters[cellKey] then
				subClusters[cellKey] = {}
			end
			table.insert(subClusters[cellKey], point)
			maybeYieldClusterWork(1)
		end

		return subClusters
	end

	processCluster = function (
		cluster, clusterID, points, resourceType, targetHulls, targetClusters, nextClusterId,
		previousCluster, previousHull, alternateCluster, alternateHull
	)
		local maxRadius, xmin, xmax, zmin, zmax
		if cluster.statsMaxRadius then
			maxRadius = cluster.statsMaxRadius
			xmin, xmax = cluster.statsXmin, cluster.statsXmax
			zmin, zmax = cluster.statsZmin, cluster.statsZmax
			cluster.statsMaxRadius = nil
			cluster.statsXmin, cluster.statsXmax = nil, nil
			cluster.statsZmin, cluster.statsZmax = nil, nil
		else
			maxRadius, xmin, xmax, zmin, zmax = getClusterStats(cluster, points, resourceType or "metal")
		end
		local geometrySegments = getGeometrySegments()
		local exactPreviousMembership = previousCluster
			and previousCluster.members
			and #previousCluster.members == #points
		if exactPreviousMembership and previousCluster.uid then
			cluster.identityUid = previousCluster.uid
			cluster.identityMembersCurrent = true
		end

		-- Feature positions and radii are immutable after entering knownFeatures.
		-- If membership and smoothing quality are unchanged, transfer the old hull
		-- instead of repeating sorting, hull construction, ground queries and spline
		-- generation. Resource totals above are still refreshed from current values.
		local reusableCluster, reusableHull, copyHull, partialReuse
		if previousCluster and previousHull
			and previousCluster.font ~= 0
			and previousCluster.geometrySegments == geometrySegments
			and previousCluster.geometryTerrainGeneration == batch.terrainGeneration
		then
			if exactPreviousMembership then
				reusableCluster, reusableHull = previousCluster, previousHull
			elseif previousCluster.geometryMaxRadius == maxRadius
				and previousCluster.geometryDependencyFids
			then
				local cidField = resourceType == "energy" and "energyCid" or "cid"
				local dependenciesPresent = true
				for i = 1, #previousCluster.geometryDependencyFids do
					local feature = knownFeatures[previousCluster.geometryDependencyFids[i]]
					if not feature or feature[cidField] ~= clusterID then
						dependenciesPresent = false
						break
					end
				end
				if dependenciesPresent then
					reusableCluster, reusableHull, partialReuse = previousCluster, previousHull, true
				end
			end
		end
		if not reusableCluster and alternateCluster and alternateHull
			and alternateCluster.font ~= 0
			and alternateCluster.geometrySegments == geometrySegments
			and alternateCluster.geometryTerrainGeneration == batch.terrainGeneration
			and alternateCluster.members and #alternateCluster.members == #points
		then
			reusableCluster, reusableHull, copyHull = alternateCluster, alternateHull, true
		end

		if reusableCluster then
			local reusePhase = batch.clusterTracyNames.reuse
			if copyHull then
				reusePhase = batch.clusterTracyNames.copyHull
			elseif partialReuse then
				reusePhase = batch.clusterTracyNames.partialReuse
			end
			batch.setClusterTracyPhase(reusePhase)
			if not partialReuse then
				cluster.members = reusableCluster.members
			end
			cluster.center = reusableCluster.center
			cluster.width = reusableCluster.width
			cluster.depth = reusableCluster.depth
			cluster.xmin = reusableCluster.xmin
			cluster.xmax = reusableCluster.xmax
			cluster.zmin = reusableCluster.zmin
			cluster.zmax = reusableCluster.zmax
			cluster.dx = reusableCluster.dx
			cluster.dz = reusableCluster.dz
			cluster.area = reusableCluster.area
			cluster.font = reusableCluster.font
			cluster.radius = reusableCluster.radius
			cluster.geometrySegments = geometrySegments
			cluster.geometryTerrainGeneration = batch.terrainGeneration
			cluster.geometryMaxRadius = reusableCluster.geometryMaxRadius
			cluster.geometryDependencyFids = reusableCluster.geometryDependencyFids
			if copyHull then
				local hullCopy = {}
				for i = 1, #reusableHull do
					local point = reusableHull[i]
					hullCopy[i] = acquirePoint(point.x, point.y, point.z)
					maybeYieldClusterWork(1)
				end
				targetHulls[clusterID] = hullCopy
			else
				targetHulls[clusterID] = reusableHull
				reusableCluster.hullReused = true
			end
			return nil, true, copyHull, partialReuse
		end

		local convexHull, hullArea
		local usedBoundingBox = false

		if #points >= 3 then
			if not cluster.membersSorted then
				batch.setClusterTracyPhase(batch.clusterTracyNames.sort)
				tableSort(points, sortMonotonic)
				cluster.membersSorted = true
			end

			local clusterWidth = xmax - xmin
			local clusterDepth = zmax - zmin
			if targetClusters and nextClusterId and (clusterWidth > maxClusterSize or clusterDepth > maxClusterSize) then
				-- The parent is hidden whenever splitting succeeds, so avoid building
				-- a convex hull that would immediately be discarded. Points are sorted
				-- first exactly as before, preserving child insertion and output order.
				local subClusters = splitLargeCluster(points, clusterWidth, clusterDepth, xmin, xmax, zmin, zmax)
				if subClusters then
					local newClusters = {}
					local subClusterIndex = nextClusterId
					for _, subPoints in pairs(subClusters) do
						if #subPoints >= 3 then
							local subCluster = { members = subPoints }
							processCluster(subCluster, subClusterIndex, subPoints, resourceType, targetHulls, nil, nil)
							newClusters[#newClusters + 1] = subCluster
							subClusterIndex = subClusterIndex + 1
						end
						maybeYieldClusterWork(1)
					end
					if #newClusters > 0 then
						targetHulls[clusterID] = nil
						cluster.font = 0
						return newClusters
					end
				end
			end

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
			local boundingConvex, boundingArea = BoundingBox(cluster, points, maxRadius)
			-- Only replace if BoundingBox succeeded
			if boundingConvex and #boundingConvex >= 3 then
				convexHull, hullArea = boundingConvex, boundingArea
				usedBoundingBox = true
			elseif not convexHull or #convexHull < 3 then
				-- Fallback: create simple box from cluster dimensions if no hull exists
				local expandDist = maxRadius * 1.2 + 10
				local xmin = cluster.xmin - expandDist
				local xmax = cluster.xmax + expandDist
				local zmin = cluster.zmin - expandDist
				local zmax = cluster.zmax + expandDist
				convexHull = {
					acquirePoint(xmin, max(0, spGetGroundHeight(xmin, zmin)), zmin),
					acquirePoint(xmax, max(0, spGetGroundHeight(xmax, zmin)), zmin),
					acquirePoint(xmax, max(0, spGetGroundHeight(xmax, zmax)), zmax),
					acquirePoint(xmin, max(0, spGetGroundHeight(xmin, zmax)), zmax)
				}
				hullArea = (xmax - xmin) * (zmax - zmin)
				usedBoundingBox = true
			end
		end

		-- Apply expansion and smoothing to make blob-like shapes
		-- Apply to all cases including BoundingBox for smooth organic shapes
		-- expandDist: how much to expand outward (in elmos)
		if convexHull and #convexHull >= 3 then
			local geometryDependencyFids = {}
			for i = 1, #convexHull do
				local fid = convexHull[i].fid
				if fid then
					geometryDependencyFids[#geometryDependencyFids + 1] = fid
				end
			end
			if #geometryDependencyFids == 0 then
				for i = 1, #points do
					geometryDependencyFids[i] = points[i].fid
				end
			end
			cluster.geometryDependencyFids = geometryDependencyFids
			cluster.geometryMaxRadius = maxRadius
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
			cluster.geometrySegments = geometrySegments
			cluster.geometryTerrainGeneration = batch.terrainGeneration
			local expandedHull = expandAndSmoothHull(convexHull, expansion, geometrySegments)
			-- Ensure we don't lose the hull if expansion fails
			if expandedHull and #expandedHull >= 3 then
				convexHull = expandedHull
			end
		end

		targetHulls[clusterID] = convexHull

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
	local rootCandidates = {}
	local rootCandidateCount = 0
	local currentResourceType -- Track which resource type we're clustering for

	---Get ready for a clustering run
	local function Setup()
		-- Note: featureClusters/featureConvexHulls are set externally
		if not unprocessed then
			unprocessed = {}
		end
		local energyPositiveCount = 0
		for fid, feature in pairs(knownFeatures) do
			if currentResourceType == "energy" and feature.energy and feature.energy > 0 then
				energyPositiveCount = energyPositiveCount + 1
			end
			-- Only include features that have this resource type
			if feature[currentResourceType] and feature[currentResourceType] >= minFeatureValue then
				unprocessed[fid] = true
			end
		end
		if currentResourceType == "energy" then
			batch.clusterEnergyPositiveCount = energyPositiveCount
		end

		-- Materialize the table's native iteration order once. Repeated
		-- next(unprocessed) calls restart at the first hash slot for every
		-- component; on maps with many energy components that repeatedly walks the
		-- already-cleared prefix. This list preserves the same root order.
		local previousCount = rootCandidateCount
		rootCandidateCount = 0
		for fid in pairs(unprocessed) do
			rootCandidateCount = rootCandidateCount + 1
			rootCandidates[rootCandidateCount] = fid
		end
		for i = rootCandidateCount + 1, previousCount do
			rootCandidates[i] = nil
		end
	end

	---Add unprocessed neighbors to the component worklist.
	local function AddNeighbors(neighbors, worklist, workCount)
		for fid in pairs(neighbors) do
			if unprocessed[fid] == true then
				unprocessed[fid] = nil
				workCount = workCount + 1
				worklist[workCount] = knownFeatures[fid]
			end
		end
		return workCount
	end

	---Runs a both simplified and augmented OPTICS sequencing step.
	---This is combined with the previous Clusterize fn step to produce clusters.
	---It also leaves no point un-clusterized; solo points form their own cluster.
	---This has allowed all processing to occur in one place and in a single pass.
	---
	---Builds into the supplied staging tables (not the live globals) and, when
	---run inside a reclustering coroutine, yields once the per-frame time budget
	---is spent so a ~9k-feature rebuild is spread across frames without stutter.
	local function Run(_self, targetClusters, targetHulls, alternateClusters, alternateHulls)
		batch.clusterTracyResource = currentResourceType
		batch.setClusterTracyPhase(batch.clusterTracyNames.setup)
		Setup()

		local cidField, previousClusters, previousHulls, alternateCidField, alternateResourceType
		if currentResourceType == "energy" then
			cidField = "energyCid"
			previousClusters = energyFeatureClusters
			previousHulls = energyFeatureConvexHulls
			if alternateClusters then
				alternateCidField = "cid"
				alternateResourceType = "metal"
			end
		else
			cidField = "cid"
			previousClusters = featureClusters
			previousHulls = featureConvexHulls
		end

		local clusterID = #targetClusters
		local worklist = {}
		local workCount = 0
		local rootIndex = 1
		local spreadSinceCheck = 0
		clusterHotLoopCounter = 0
		local function maybeYield()
			if batch.clusterJobActive and (osClock() - batch.clusterJobStart >= batch.clusterJobBudget) then
				batch.yieldClusterJob()
			end
		end
		batch.setClusterTracyPhase(batch.clusterTracyNames.graph)
		while rootIndex <= rootCandidateCount do
			local featureID = rootCandidates[rootIndex]
			rootIndex = rootIndex + 1
			if unprocessed[featureID] == true then
				-- Start a new cluster.
				local point = knownFeatures[featureID]
				local previousCid = point[cidField]
				local samePreviousCluster = previousCid ~= nil
				local alternateCid = alternateCidField
					and point[alternateResourceType] >= minFeatureValue
					and point[alternateCidField]
				local sameAlternateCluster = alternateCid ~= nil
				local members = { point }
				local pointRadius = point.radius or 0
				local resourceTotal = point[currentResourceType]
				local cluster = {
					members = members,
					previousCid = previousCid,
					alternateCid = alternateCid,
					statsMaxRadius = pointRadius,
					statsXmin = point.x,
					statsXmax = point.x,
					statsZmin = point.z,
					statsZmax = point.z,
				}
				clusterID = clusterID + 1
				targetClusters[clusterID] = cluster

				-- Process visited points, like so.
				point[cidField] = clusterID
				unprocessed[featureID] = nil

				-- Process immediate neighbors.
				local neighbors = featureNeighborsMatrix[featureID]
				workCount = AddNeighbors(neighbors, worklist, workCount)

				-- Spread through the entire epsilon-connected component.
				while workCount > 0 do
					local pt = worklist[workCount]
					worklist[workCount] = nil
					workCount = workCount - 1
					members[#members+1] = pt
					resourceTotal = resourceTotal + pt[currentResourceType]
					local radius = pt.radius or 0
					if radius > cluster.statsMaxRadius then cluster.statsMaxRadius = radius end
					local x, z = pt.x, pt.z
					if x < cluster.statsXmin then cluster.statsXmin = x end
					if x > cluster.statsXmax then cluster.statsXmax = x end
					if z < cluster.statsZmin then cluster.statsZmin = z end
					if z > cluster.statsZmax then cluster.statsZmax = z end
					if pt[cidField] ~= previousCid then
						samePreviousCluster = false
					end
					if sameAlternateCluster and (
						pt[alternateResourceType] < minFeatureValue
						or pt[alternateCidField] ~= alternateCid
					) then
						sameAlternateCluster = false
					end
					pt[cidField] = clusterID

					local nextNeighbors = featureNeighborsMatrix[pt.fid]
					workCount = AddNeighbors(nextNeighbors, worklist, workCount)

					-- The expansion loop can walk thousands of points for one connected
					-- reclaim field; check budget periodically so one resume never blocks.
					spreadSinceCheck = spreadSinceCheck + 1
					if spreadSinceCheck >= 8 then
						spreadSinceCheck = 0
						maybeYield()
					end
				end
				if not samePreviousCluster then
					cluster.previousCid = nil
				end
				if not sameAlternateCluster then
					cluster.alternateCid = nil
				end
				cluster.statsMaxRadius = max(cluster.statsMaxRadius, 20)
				cluster[currentResourceType] = resourceTotal
				cluster.text = FormatResourceText(resourceTotal)

				maybeYield()
			end
		end

		-- Post-process each cluster (convex hulls + smoothing = the heavy part).
		local nextClusterId = clusterID + 1 -- Track next available cluster ID for splits
		for cid = 1, clusterID do
			local cluster = targetClusters[cid]
			local previousCid = cluster.previousCid
			local alternateCid = cluster.alternateCid
			cluster.previousCid = nil
			cluster.alternateCid = nil
			local previousCluster = previousCid and previousClusters[previousCid]
			local previousHull = previousCid and previousHulls[previousCid]
			if previousCluster and previousCluster.membersSorted and #cluster.members >= 3 then
				-- Removal-only components are subsets of their previous component.
				-- Filter the already sorted member array in place instead of sorting
				-- the graph traversal order again. This also handles components split
				-- by a removed connector while preserving exact hull input order.
				local members = cluster.members
				for i = #members, 1, -1 do
					members[i] = nil
				end
				local previousMembers = previousCluster.members
				for i = 1, #previousMembers do
					local member = previousMembers[i]
					if member[cidField] == cid then
						members[#members + 1] = member
					end
				end
				cluster.membersSorted = true
			end
			local alternateCluster = alternateCid and alternateClusters[alternateCid]
			local alternateHull = alternateCid and alternateHulls[alternateCid]
			if alternateCluster and #alternateCluster.members ~= #cluster.members then
				alternateCluster = nil
				alternateHull = nil
			end
			local newClusters, reusedHull, copiedHull, partialReuse = processCluster(
				cluster, cid, cluster.members, currentResourceType,
				targetHulls, targetClusters, nextClusterId,
				previousCluster, previousHull, alternateCluster, alternateHull
			)
			if reusedHull then
				if currentResourceType == "energy" then
					batch.reusedEnergyHulls = batch.reusedEnergyHulls + 1
				else
					batch.reusedMetalHulls = batch.reusedMetalHulls + 1
				end
				if copiedHull then
					batch.copiedEnergyHulls = batch.copiedEnergyHulls + 1
				end
				if partialReuse then
					if currentResourceType == "energy" then
						batch.partialReusedEnergyHulls = batch.partialReusedEnergyHulls + 1
					else
						batch.partialReusedMetalHulls = batch.partialReusedMetalHulls + 1
					end
				end
			end
			if newClusters then
				-- Cluster was split - add sub-clusters to arrays
				for i = 1, #newClusters do
					targetClusters[nextClusterId] = newClusters[i]
					nextClusterId = nextClusterId + 1
				end
			end

			-- Hull/smoothing work can also spike on big clusters, so check each iteration.
			maybeYield()
		end
		-- Note: the caller swaps the staging tables into the live globals once
		-- both metal and energy passes have completed.
	end

	function Optics.new()
		local object = setmetatable({}, {
			__index = {
				Run = Run,
				SetResourceType = function(self, resourceType)
					currentResourceType = resourceType
				end
			}
		})
		return object
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Feature Tracking

local function MarkRegionDirty(x, z, radius)
	-- Mark a spatial region as needing reclustering
	if not dirty.useRegional then return end

	local newRadius = radius or epsilon * 2
	local merged = false

	-- Try to merge with existing dirty regions to reduce fragmentation
	for i = 1, #dirty.regions do
		local region = dirty.regions[i]
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
		dirty.regions[#dirty.regions + 1] = {x = x, z = z, radius = newRadius}
	end
end

local function IsInDirtyRegion(x, z)
	if not dirty.useRegional or #dirty.regions == 0 then return true end
	for i = 1, #dirty.regions do
		local region = dirty.regions[i]
		local dx, dz = x - region.x, z - region.z
		if dx * dx + dz * dz <= region.radius * region.radius then
			return true
		end
	end
	return false
end

-- Forward declarations for per-cluster display list management
local DeleteClusterDisplayList
local CreateClusterDisplayList

local function AddFeature(featureID)
	local metal, _, energy = spGetFeatureResources(featureID)
	if (not metal or metal < minFeatureValue) and (not energy or energy < minFeatureValue) then
		return
	end

	local x, y, z = spGetFeaturePosition(featureID)
	if not x then return end

	-- Mark region as dirty for regional reclustering
	MarkRegionDirty(x, z)

	local radius = spGetFeatureRadius(featureID) or 0
	local feature = {
		fid   = featureID,
		metal = metal or 0,
		energy = energy or 0,
		x     = x,
		y     = max(0, y),
		z     = z,
		radius = radius,
	}

	-- Reset drained flag when adding a feature with energy
	if energy and energy > 0 and allEnergyFieldsDrained then
		allEnergyFieldsDrained = false
	end

	-- To deal with e.g. raptor eggs spawning at altitude ~20:
	if y > 0 then
		local elevation = spGetGroundHeight(x, z)
		if elevation and elevation > 0 and y > elevation + 2 then
			flyingFeatures[featureID] = feature
			return -- Delay clusterizing until stationary.
		end
	end

	-- Assuming the feature's motion is highly likely negligible:
	local M_newFeature = {}
	grid.buildNeighbors(featureID, x, z, M_newFeature)
	featureNeighborsMatrix[featureID] = M_newFeature
	knownFeatures[featureID] = feature
	grid.insert(featureID, feature)
	knownFeatureIDs[#knownFeatureIDs + 1] = featureID
	feature.scanIndex = #knownFeatureIDs
	cachedKnownFeaturesCount = cachedKnownFeaturesCount + 1
end

local function RemoveFeature(featureID)
	local feature = knownFeatures[featureID]
	if not feature then return end

	-- Mark region as dirty for regional reclustering
	MarkRegionDirty(feature.x, feature.z)

	-- Mark metal cluster as dirty for redrawing
	-- Don't delete display list here - it will be recreated in the redrawing section
	if feature.cid then
		local cluster = featureClusters[feature.cid]
		if cluster and cluster.metal then
			cluster.metal = max(0, cluster.metal - (feature.metal or 0))
			cluster.text = FormatResourceText(cluster.metal)
		end
		dirty.clusters[feature.cid] = true
		dirty.needRedraw = true
	end

	-- Mark energy cluster as dirty for redrawing
	-- Don't delete display list here - it will be recreated in the redrawing section
	if feature.energyCid then
		local energyCluster = energyFeatureClusters[feature.energyCid]
		if energyCluster and energyCluster.energy then
			energyCluster.energy = max(0, energyCluster.energy - (feature.energy or 0))
			energyCluster.text = FormatResourceText(energyCluster.energy)
		end
		dirty.energyClusters[feature.energyCid] = true
		dirty.needRedraw = true
	end

	local neighbors = featureNeighborsMatrix[featureID]
	for nid in pairs(neighbors) do
		local neighborRow = featureNeighborsMatrix[nid]
		if neighborRow then
			neighborRow[featureID] = nil
		end
	end
	featureNeighborsMatrix[featureID] = nil
	grid.remove(featureID, feature)
	knownFeatures[featureID] = nil
	local scanIndex = feature.scanIndex
	if scanIndex then
		local lastIndex = #knownFeatureIDs
		local lastFeatureID = knownFeatureIDs[lastIndex]
		knownFeatureIDs[scanIndex] = lastFeatureID
		knownFeatureIDs[lastIndex] = nil
		if lastFeatureID and lastFeatureID ~= featureID then
			local lastFeature = knownFeatures[lastFeatureID]
			if lastFeature then
				lastFeature.scanIndex = scanIndex
			end
		end
		feature.scanIndex = nil
		if featureReclaimScanCounter > lastIndex then
			featureReclaimScanCounter = 1
		end
	end
	cachedKnownFeaturesCount = cachedKnownFeaturesCount - 1
end

local function UpdateFeatureReclaim()
	-- Check a rotating subset of features each frame to bound the cost of
	-- Spring.GetFeatureResources() on large maps.
	local removed = false
	local removeCount = 0
	local dirtyCount = 0
	local dirtyEnergyCount = 0

	local featureCount = cachedKnownFeaturesCount
	local maxChecksPerFrame = 8
	if featureCount > 2500 then
		maxChecksPerFrame = 4
	end
	if actionActive or IsActiveReclaimCommand() then
		maxChecksPerFrame = 48
	end
	if featureCount < maxChecksPerFrame then
		maxChecksPerFrame = featureCount
	end

	local scanIndex = featureReclaimScanCounter
	-- Determine what needs updating based on visibility
	-- Use cached values to avoid function call overhead
	local needMetalUpdates = drawEnabled
	local needEnergyUpdates = drawEnergyEnabled

	for _ = 1, maxChecksPerFrame do
		if featureCount == 0 then
			break
		end
		scanIndex = scanIndex + 1
		if scanIndex > featureCount then
			scanIndex = 1
		end
		local fid = knownFeatureIDs[scanIndex]
		local fInfo = fid and knownFeatures[fid]
		if fInfo then
			local metal, _, energy = spGetFeatureResources(fid)

			-- Only remove feature when BOTH metal AND energy are below threshold
			-- This prevents energy fields from disappearing when only metal is reclaimed
			local metalDepleted = not metal or metal < minFeatureValue
			local energyDepleted = not energy or energy < minFeatureValue
			if metalDepleted and energyDepleted then
				removeCount = removeCount + 1
				batch.toRemove[removeCount] = fid
				removed = true
			else
				-- Update metal if changed (only if metal fields are visible)
				if needMetalUpdates and metal and fInfo.metal ~= metal then
					if fInfo.cid then
						local cid = fInfo.cid
						if not dirty.clusters[cid] then
							dirtyCount = dirtyCount + 1
							dirty.clusters[cid] = true
							-- Don't delete display list here - let it continue showing old visuals
							-- until the new one is created (prevents flickering)
						end
						local thisCluster = featureClusters[cid]
						if thisCluster then
							thisCluster.metal = thisCluster.metal - fInfo.metal + metal
						end
					end
					fInfo.metal = metal
				end
				-- Update energy if changed (only if energy fields are visible)
				if needEnergyUpdates and energy and fInfo.energy ~= energy then
					if fInfo.energyCid then
						local energyCid = fInfo.energyCid
						local thisCluster = energyFeatureClusters[energyCid]
						if thisCluster then
							if not dirty.energyClusters[energyCid] then
								dirtyEnergyCount = dirtyEnergyCount + 1
								dirty.energyClusters[energyCid] = true
								-- Don't delete display list here - let it continue showing old visuals
								-- until the new one is created (prevents flickering)
							end
							-- Incremental update: subtract old value, add new value
							thisCluster.energy = thisCluster.energy - fInfo.energy + energy
						end
					end
					fInfo.energy = energy
				end
			end
		end
	end
	featureReclaimScanCounter = scanIndex

	-- Remove in separate loop to avoid iterator issues
	for i = 1, removeCount do
		RemoveFeature(batch.toRemove[i])
	end

	-- Clear reusable table
	for i = 1, removeCount do
		batch.toRemove[i] = nil
	end

	if removed then
		dirty.removedSinceCluster = dirty.removedSinceCluster + removeCount
		local reclusterThreshold = 8
		if featureCount > 3000 then
			reclusterThreshold = 16
		end
		if featureCount > 6000 then
			reclusterThreshold = 28
		end
		if featureCount > 8500 then
			reclusterThreshold = 40
		end

		-- If the cluster count changed a lot after recent rebuilds, avoid constantly
		-- restarting full reclusters and batch removals into larger updates.
		if dirty.removedSinceCluster >= reclusterThreshold then
			dirty.needCluster = true
			dirty.removedSinceCluster = 0
		end
	elseif dirtyCount > 0 or dirtyEnergyCount > 0 then
		dirty.needRedraw = true

		-- Update metal cluster text (only if metal fields are visible)
		if needMetalUpdates then
			for cid in pairs(dirty.clusters) do
				local cluster = featureClusters[cid]
				if cluster then
					cluster.text = FormatResourceText(cluster.metal)
				end
			end
		end

		-- Update energy cluster text (only if energy fields are visible)
		if needEnergyUpdates then
			for energyCid in pairs(dirty.energyClusters) do
				local energyCluster = energyFeatureClusters[energyCid]
				if energyCluster then
					energyCluster.text = FormatResourceText(energyCluster.energy)
				end
			end
		end
	end

	-- Feed the adaptive backoff tally. Depletions (removeCount) trigger a
	-- recluster (the most expensive path), so they count for more than plain
	-- value changes. This is normalized per sampled pass, so it reflects how
	-- widespread reclaim is regardless of how often we happen to poll.
	local churnThisCall = removeCount * 3 + dirtyCount + dirtyEnergyCount
	if churnThisCall > 0 then
		dirty.reclaimChurn = dirty.reclaimChurn + churnThisCall
	end
end

-- Check if all energy fields have been drained
local function CheckAllEnergyDrained(featuresWithEnergy)
	if not showEnergyFields then
		return -- Energy fields disabled
	end

	if featuresWithEnergy > 0 then
		-- Found energy, not all drained
		allEnergyFieldsDrained = false
		return
	end

	-- All energy is drained, disable energy rendering
	allEnergyFieldsDrained = true

	-- Clean up energy display lists
	if drawEnergyConvexHullEdgeList ~= nil then
		glDeleteList(drawEnergyConvexHullEdgeList)
		drawEnergyConvexHullEdgeList = nil
	end

	-- Clear energy data structures
	energyFeatureClusters = {}
	for _, hull in pairs(energyFeatureConvexHulls) do recycleHull(hull) end
	energyFeatureConvexHulls = {}
end

-- Track text positions to avoid overlaps
local drawnTextPositions = {
	grid = {},
	cellSize = fontSizeMax * 1.5,
}
local drawnTextPositionCount = 0

local function WouldTextOverlap(x, z, fontSize)
	local thresholdSq = (fontSize * 1.5) ^ 2
	local cellSize = drawnTextPositions.cellSize
	local cellX = floor(x / cellSize)
	local cellZ = floor(z / cellSize)
	local cellRange = math.ceil(sqrt(thresholdSq) / cellSize)
	local grid = drawnTextPositions.grid
	for gx = cellX - cellRange, cellX + cellRange do
		local row = grid[gx]
		if row then
			for gz = cellZ - cellRange, cellZ + cellRange do
				local bucket = row[gz]
				if bucket then
					for i = 1, #bucket do
						local pos = bucket[i]
						local dx = x - pos.x
						local dz = z - pos.z
						if dx * dx + dz * dz < thresholdSq then
							return true, pos
						end
					end
				end
			end
		end
	end
	return false, nil
end

local function ResetDrawnTextPositions()
	drawnTextPositionCount = 0
	local grid = drawnTextPositions.grid
	for cellX in pairs(grid) do
		grid[cellX] = nil
	end
end

local function AddDrawnTextPosition(x, z, fontSize)
	drawnTextPositionCount = drawnTextPositionCount + 1
	local posEntry = drawnTextPositions[drawnTextPositionCount]
	if posEntry then
		posEntry.x = x
		posEntry.z = z
		posEntry.fontSize = fontSize
	else
		posEntry = {x = x, z = z, fontSize = fontSize}
		drawnTextPositions[drawnTextPositionCount] = posEntry
	end

	local cellSize = drawnTextPositions.cellSize
	local cellX = floor(x / cellSize)
	local cellZ = floor(z / cellSize)
	local grid = drawnTextPositions.grid
	local row = grid[cellX]
	if not row then
		row = {}
		grid[cellX] = row
	end
	local bucket = row[cellZ]
	if not bucket then
		bucket = {}
		row[cellZ] = bucket
	end
	bucket[#bucket + 1] = posEntry
end

-- Pre-computed offset multipliers (avoid table allocation per call)
local overlapOffsetMults = {
	{0, 1.5}, {0, -1.5}, {1.5, 0}, {-1.5, 0},
	{1.2, 1.2}, {-1.2, 1.2}, {1.2, -1.2}, {-1.2, -1.2},
}

local function FindNonOverlappingPosition(baseX, baseZ, fontSize)
	for i = 1, #overlapOffsetMults do
		local m = overlapOffsetMults[i]
		local testX = baseX + m[1] * fontSize
		local testZ = baseZ + m[2] * fontSize
		if not WouldTextOverlap(testX, testZ, fontSize) then
			return testX, testZ
		end
	end
	return baseX + fontSize * 2.5, baseZ
end

FormatResourceText = function(value)
	local v = value or 0
	if string.formatSI then
		local ok, txt = pcall(string.formatSI, v, 0)
		if ok and txt then return txt end
		ok, txt = pcall(string.formatSI, v)
		if ok and txt then return txt end
	end
	if v >= 1000000 then
		return string.format("%.1fM", v / 1000000)
	elseif v >= 1000 then
		return string.format("%.1fK", v / 1000)
	end
	return string.format("%d", floor(v + 0.5))
end

local function EnsureClusterTextAnchors()
	ResetDrawnTextPositions()
	for cid = 1, #featureClusters do
		local cluster = featureClusters[cid]
		if cluster and cluster.center and cluster.font and cluster.font > 0 then
			if not cluster.text then
				cluster.text = FormatResourceText(cluster.metal or 0)
			end
			local fontSize = cluster.font
			local textX, textZ = cluster.center.x, cluster.center.z
			if WouldTextOverlap(textX, textZ, fontSize) then
				textX, textZ = FindNonOverlappingPosition(textX, textZ, fontSize)
			end
			cluster.textX = textX
			cluster.textZ = textZ
			AddDrawnTextPosition(textX, textZ, fontSize)
		end
	end
	if showEnergyFields then
		for cid = 1, #energyFeatureClusters do
			local cluster = energyFeatureClusters[cid]
			if cluster and cluster.center and cluster.font and cluster.font > 0 then
				if not cluster.text then
					cluster.text = FormatResourceText(cluster.energy or 0)
				end
				local fontSize = cluster.font * energyTextSizeMultiplier
				local textX, textZ = cluster.center.x, cluster.center.z
				if WouldTextOverlap(textX, textZ, fontSize) then
					textX, textZ = FindNonOverlappingPosition(textX, textZ, fontSize)
				end
				cluster.textX = textX
				cluster.textZ = textZ
				AddDrawnTextPosition(textX, textZ, fontSize)
			end
		end
	end
end

local function ClusterizeFeatures()
	-- Runs as a coroutine body (see the driver in UpdateReclaimFields). Builds a
	-- fresh clustering into staging tables so the previous fields keep rendering
	-- until the new set is ready, then swaps atomically. Optics.Run yields to the
	-- driver periodically so a ~9k-feature rebuild is spread over frames instead
	-- of stalling one frame.
	local stagingClusters = {}
	local stagingHulls = {}
	opticsObject:SetResourceType("metal")
	opticsObject:Run(stagingClusters, stagingHulls)

	local stagingEnergyClusters, stagingEnergyHulls
	if showEnergyFields then
		stagingEnergyClusters = {}
		stagingEnergyHulls = {}
		opticsObject:SetResourceType("energy")
		opticsObject:Run(stagingEnergyClusters, stagingEnergyHulls, stagingClusters, stagingHulls)
	end

	-- Atomic swap: recycle the old hulls and point the live globals at the new
	-- staging tables. (Pre-clustering snapshots still hold the old hull refs for
	-- fade-out, matching the previous synchronous recycle-then-sync ordering.)
	batch.clusterTracyResource = nil
	batch.setClusterTracyPhase(batch.clusterTracyNames.swap)
	for cid, hull in pairs(featureConvexHulls) do
		local oldCluster = featureClusters[cid]
		if oldCluster and oldCluster.hullReused then
			oldCluster.hullReused = nil
		else
			recycleHull(hull)
		end
	end
	featureClusters = stagingClusters
	featureConvexHulls = stagingHulls
	if showEnergyFields then
		for cid, hull in pairs(energyFeatureConvexHulls) do
			local oldCluster = energyFeatureClusters[cid]
			if oldCluster and oldCluster.hullReused then
				oldCluster.hullReused = nil
			else
				recycleHull(hull)
			end
		end
		energyFeatureClusters = stagingEnergyClusters
		energyFeatureConvexHulls = stagingEnergyHulls
	end

	-- A full rebuild supersedes any pending regional/incremental dirty state.
	for i = 1, #dirty.regions do
		dirty.regions[i] = nil
	end
	for cid in pairs(dirty.clusters) do
		dirty.clusters[cid] = nil
	end
	for cid in pairs(dirty.energyClusters) do
		dirty.energyClusters[cid] = nil
	end

	dirty.needCluster = false
	dirty.needRedraw = true

	-- Calculate total map metal and update auto-scaled threshold
	totalMapMetal = 0
	for i = 1, #featureClusters do
		local cluster = featureClusters[i]
		if cluster and cluster.metal then
			totalMapMetal = totalMapMetal + cluster.metal
		end
	end
	alwaysShowFieldsThreshold = CalculateAlwaysShowThreshold()

	-- Check if all energy has been drained after clustering
	if showEnergyFields then
		CheckAllEnergyDrained(batch.clusterEnergyPositiveCount)
	end

	-- Pre-compute overlap-adjusted text positions for all clusters
	batch.setClusterTracyPhase(batch.clusterTracyNames.text)
	ResetDrawnTextPositions()
	for cid = 1, #featureClusters do
		local cluster = featureClusters[cid]
		if cluster and cluster.center then
			local fontSize = cluster.font
			local textX, textZ = cluster.center.x, cluster.center.z
			if WouldTextOverlap(textX, textZ, fontSize) then
				textX, textZ = FindNonOverlappingPosition(textX, textZ, fontSize)
			end
			cluster.textX = textX
			cluster.textZ = textZ
			AddDrawnTextPosition(textX, textZ, fontSize)
		end
	end
	if showEnergyFields then
		for cid = 1, #energyFeatureClusters do
			local cluster = energyFeatureClusters[cid]
			if cluster and cluster.center then
				local fontSize = cluster.font * energyTextSizeMultiplier
				local textX, textZ = cluster.center.x, cluster.center.z
				if WouldTextOverlap(textX, textZ, fontSize) then
					textX, textZ = FindNonOverlappingPosition(textX, textZ, fontSize)
				end
				cluster.textX = textX
				cluster.textZ = textZ
				AddDrawnTextPosition(textX, textZ, fontSize)
			end
		end
	end
	batch.finishClusterTracy()
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

IsActiveReclaimCommand = function()
	local _, _, _, cmdName = spGetActiveCommand()
	return cmdName == 'Reclaim'
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
		local previousDrawEnabled = drawEnabled
		-- Before game starts, always enable drawing regardless of user settings
		if not gameStarted then
			drawEnabled = true
		else
			drawEnabled = showOptionFunctions[showOption]()
		end
		-- If visibility changed from false to true, force a full display list recreation
		if not previousDrawEnabled and drawEnabled then
			dirty.needRedraw = true
			batch.metalRevealPending = true
			batch.waitForFreshMetal = gameStarted and (
				batch.clusterJobActive or dirty.needCluster
				or batch.pendCreateCount > batch.pendCreateHead
				or batch.pendDestrCount > batch.pendDestrHead
			)
		elseif not drawEnabled then
			batch.metalRevealPending = false
			batch.waitForFreshMetal = false
		end
		-- Track the toggle fade target so the group fades smoothly in/out.
		animState.toggleMetalTarget = drawEnabled and not batch.waitForFreshMetal and 1 or 0
		return drawEnabled
	end
end

local UpdateDrawEnergyEnabled -- Similar to UpdateDrawEnabled but for energy fields
do
	local function always()
		return true
	end

	local function onMapDrawMode()
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

	local showEnergyOptionFunctions = {
		--[[1]] always,
		--[[2]] onMapDrawMode,
		--[[3]] onSelectReclaimer,
		--[[4]] onSelectResurrector,
		--[[5]] onActiveCommand,
		--[[6]] function() return false end, -- disabled
	}

	UpdateDrawEnergyEnabled = function ()
		local previousDrawEnergyEnabled = drawEnergyEnabled
		if not showEnergyFields then
			drawEnergyEnabled = false
			batch.energyRevealPending = false
			batch.waitForFreshEnergy = false
			animState.toggleEnergyTarget = 0
			return false
		end
		drawEnergyEnabled = showEnergyOptionFunctions[showEnergyOption]()
		-- If visibility changed from false to true, force a full display list recreation
		if not previousDrawEnergyEnabled and drawEnergyEnabled then
			dirty.needRedraw = true
			batch.energyRevealPending = true
			batch.waitForFreshEnergy = gameStarted and (
				batch.clusterJobActive or dirty.needCluster
				or batch.pendCreateCount > batch.pendCreateHead
				or batch.pendDestrCount > batch.pendDestrHead
			)
		elseif not drawEnergyEnabled then
			batch.energyRevealPending = false
			batch.waitForFreshEnergy = false
		end
		animState.toggleEnergyTarget = drawEnergyEnabled and not batch.waitForFreshEnergy and 1 or 0
		return drawEnergyEnabled
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Drawing

local camUpVector

local function DrawHullVertices(hull)
	for j = 1, #hull do
		glVertex(hull[j].x, hull[j].y, hull[j].z)
	end
end

-- Reusable buffer for DrawHullVerticesGradient inner points
local innerPointsBuf = {}

-- Draw gradient fill from center (transparent) to configurable radius (gradientAlpha)
-- Also fills the inner area with fillAlpha
local function DrawHullVerticesGradient(hull, center, colors)
	local hullCount = #hull
	if hullCount < 3 then return end

	-- Use provided colors or default to metal colors
	local reclaimCol = colors and colors.fill or reclaimColor
	local r, g, b = reclaimCol[1], reclaimCol[2], reclaimCol[3]
	local cx, cy, cz = center.x, center.y, center.z
	local innerRadius = gradientInnerRadius

	-- Use custom alpha values if provided, otherwise use defaults
	local fillAlphaValue = colors and colors.fillAlpha or fillAlpha
	local gradientAlphaValue = colors and colors.gradientAlpha or gradientAlpha

	-- Calculate the inner boundary using configurable radius
	for i = 1, hullCount do
		local hullPoint = hull[i]
		local dx = hullPoint.x - cx
		local dz = hullPoint.z - cz
		local entry = innerPointsBuf[i]
		if entry then
			entry.x = cx + dx * innerRadius
			entry.y = hullPoint.y
			entry.z = cz + dz * innerRadius
		else
			innerPointsBuf[i] = {
				x = cx + dx * innerRadius,
				y = hullPoint.y,
				z = cz + dz * innerRadius
			}
		end
	end
	local innerPoints = innerPointsBuf

	-- First, fill the inner area with solid fillAlpha (fan triangulation from center)
	glColor(r, g, b, fillAlphaValue)
	for j = 1, hullCount do
		local nextIdx = (j == hullCount) and 1 or (j + 1)
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
		glColor(r, g, b, fillAlphaValue)
		glVertex(inner.x, inner.y, inner.z)

		glColor(r, g, b, gradientAlphaValue)
		glVertex(outer.x, outer.y, outer.z)

		glColor(r, g, b, fillAlphaValue)
		glVertex(innerNext.x, innerNext.y, innerNext.z)

		-- Triangle 2: inner[next] -> outer[j] -> outer[next]
		glColor(r, g, b, fillAlphaValue)
		glVertex(innerNext.x, innerNext.y, innerNext.z)

		glColor(r, g, b, gradientAlphaValue)
		glVertex(outer.x, outer.y, outer.z)

		glColor(r, g, b, gradientAlphaValue)
		glVertex(outerNext.x, outerNext.y, outerNext.z)
	end
end

-- Allocation-free display-list recording scratch.
--
-- gl.CreateList() records its callback immediately, so the geometry/colours it
-- reads only need to be valid *during* that call. Previously each rebuild
-- allocated a fresh colours table plus a fresh closure per list; during fades
-- (up to maxRebuildsPerFrame per frame) that was a steady stream of garbage.
-- We now stash the transient inputs on one reusable `dlScratch` table and hand
-- gl.CreateList a pair of persistent recorder functions instead. Packed onto a
-- single table to respect the file's 200 local/upvalue budget.
local dlScratch = {
	hull = nil,
	center = nil,
	colors = { fill = nil, fillAlpha = 0, gradientAlpha = 0 },
}
dlScratch.emitGradient = function()
	glBeginEnd(GL.TRIANGLES, DrawHullVerticesGradient, dlScratch.hull, dlScratch.center, dlScratch.colors)
end
dlScratch.emitEdge = function()
	glBeginEnd(GL.LINE_LOOP, DrawHullVertices, dlScratch.hull)
end

-- Helper functions for per-cluster display list management
DeleteClusterDisplayList = function(cid, isEnergy, keepText)
	-- keepText (optional) when true will preserve the text display list to avoid
	-- repeated recreate costs when clusters oscillate in/out of view.
	local displayLists = isEnergy and energyClusterDisplayLists or clusterDisplayLists
	local stateHashes = isEnergy and energyClusterStateHashes or clusterStateHashes
	local clusterData = displayLists[cid]
	if clusterData then
		if clusterData.gradient then
			glDeleteList(clusterData.gradient)
			clusterData.gradient = nil
		end
		if clusterData.edge then
			glDeleteList(clusterData.edge)
			clusterData.edge = nil
		end
		if not keepText then
			if clusterData.text then
				glDeleteList(clusterData.text)
				clusterData.text = nil
			end
			-- Remove the table entirely when not preserving text
			displayLists[cid] = nil
		else
			-- Preserve the table entry for potential reuse
			displayLists[cid] = clusterData
		end
	end
	-- Clear state hash too so next creation will re-evaluate
	stateHashes[cid] = nil
end

CreateClusterDisplayList = function(cid, isEnergy, alphaMult)
	local displayLists = isEnergy and energyClusterDisplayLists or clusterDisplayLists
	local clusters = isEnergy and energyFeatureClusters or featureClusters
	local hulls = isEnergy and energyFeatureConvexHulls or featureConvexHulls
	local stateHashes = isEnergy and energyClusterStateHashes or clusterStateHashes

	local cluster = clusters[cid]
	local hull = hulls[cid]
	if not cluster or not hull or not cluster.center then
		return
	end

	alphaMult = alphaMult or 1.0
	if alphaMult < 0 then alphaMult = 0 end
	if alphaMult > 1 then alphaMult = 1 end

	-- Compute geometry hash (alpha-independent) plus a full hash with quantized
	-- alpha, so the gradient rebuilds on fade while the edge list can be reused.
	local geomHash = ComputeClusterStateHash(cluster, hull)
	-- Quantize alpha to ~32 buckets so we don't rebuild every tiny change
	local newHash = geomHash + floor(alphaMult * 32 + 0.5) * 0.0001
	local oldHash = stateHashes[cid]

	-- Only recreate if state actually changed
	if oldHash and oldHash == newHash then
		return -- No change, keep existing display list
	end
	tracy.ZoneBeginN("W:ReclaimField:CompileDisplayList")

	if debugTiming then timingAccum.rebuilds = timingAccum.rebuilds + 1 end

	-- Prepare clusterData table; if it exists preserve text (we'll recreate geometry only)
	local clusterData = displayLists[cid]
	if not clusterData then
		clusterData = {}
		displayLists[cid] = clusterData
	else
		-- Remove the existing gradient list (alpha is baked in, so it always
		-- rebuilds). The edge list is shape-only and is rebuilt below only when
		-- the geometry actually changed.
		if clusterData.gradient then
			glDeleteList(clusterData.gradient)
			clusterData.gradient = nil
		end
	end

	-- Fill the reusable scratch colours table (alpha baked in). Safe to reuse
	-- because gl.CreateList records DrawHullVerticesGradient immediately below.
	local scratchColors = dlScratch.colors
	if isEnergy then
		scratchColors.fill = energyReclaimColor
		scratchColors.fillAlpha = fillAlpha * energyOpacityMultiplier * alphaMult
		scratchColors.gradientAlpha = gradientAlpha * energyOpacityMultiplier * alphaMult
	else
		scratchColors.fill = reclaimColor
		scratchColors.fillAlpha = fillAlpha * alphaMult
		scratchColors.gradientAlpha = gradientAlpha * alphaMult
	end
	dlScratch.hull = hull
	dlScratch.center = cluster.center

	-- Create gradient fill display list (alpha baked in) using the shared,
	-- non-allocating recorder function.
	clusterData.gradient = glCreateList(dlScratch.emitGradient)

	-- Create the edge display list only when the geometry actually changed; its
	-- opacity is applied via glColor at draw time, so alpha-only fades reuse it.
	if not clusterData.edge or clusterData.geomHash ~= geomHash then
		if clusterData.edge then glDeleteList(clusterData.edge) end
		clusterData.edge = glCreateList(dlScratch.emitEdge)
		clusterData.geomHash = geomHash
	end

	-- Track the alpha used for the current gradient list so we can decide later
	-- whether to rebuild on subsequent fade ticks.
	clusterData.bakedAlpha = alphaMult

	displayLists[cid] = clusterData

	-- Update state hash after successful recreation
	stateHashes[cid] = newHash
	tracy.ZoneEnd()
end

-- Build (or rebuild) display lists for a single fading-out cluster entry.
-- Bakes the entry's current alpha into the gradient list so we get a real fade.
local function CreateFadingClusterDisplayList(uid, isEnergy)
	local fading = isEnergy and animState.fadingEnergy or animState.fading
	local entry = fading[uid]
	if not entry then return end
	local hull = entry.hullCopy
	local center = entry.center
	if not hull or #hull < 3 or not center then return end

	local alphaMult = entry.alpha or entry.startAlpha or 1
	if alphaMult < 0 then alphaMult = 0 end
	if alphaMult > 1 then alphaMult = 1 end
	tracy.ZoneBeginN("W:ReclaimField:CompileFadingDisplayList")

	-- Reuse table if present; otherwise allocate
	local dl = entry.displayLists
	if not dl then
		dl = {}
		entry.displayLists = dl
	end
	if dl.gradient then glDeleteList(dl.gradient); dl.gradient = nil end

	-- Fill the shared scratch colours (see dlScratch): gl.CreateList records
	-- immediately, so reusing the table across calls is safe and allocation-free.
	local scratchColors = dlScratch.colors
	if isEnergy then
		scratchColors.fill = energyReclaimColor
		scratchColors.fillAlpha = fillAlpha * energyOpacityMultiplier * alphaMult
		scratchColors.gradientAlpha = gradientAlpha * energyOpacityMultiplier * alphaMult
	else
		scratchColors.fill = reclaimColor
		scratchColors.fillAlpha = fillAlpha * alphaMult
		scratchColors.gradientAlpha = gradientAlpha * alphaMult
	end
	dlScratch.hull = hull
	dlScratch.center = center

	dl.gradient = glCreateList(dlScratch.emitGradient)
	-- Edge geometry is fixed for the life of the fade; build it once and reuse
	-- it across every alpha tick (opacity comes from glColor at draw time).
	if not dl.edge then
		dl.edge = glCreateList(dlScratch.emitEdge)
	end
	entry.lastBakedAlpha = alphaMult
	tracy.ZoneEnd()
end

local cachedCameraFacing = 0

-- Process deferred features that may have come into view
local function ProcessDeferredFeatures(frame)
	if (batch.deferCreateCount == 0 and batch.deferDestrCount == 0) or
	   (frame - batch.lastDeferFrame < batch.deferInterval and frame % 10 ~= 0) then
		return
	end

	batch.lastDeferFrame = frame

	-- Process deferred creations - check if they're now in view
	local remainingDeferred = 0
	for i = 1, batch.deferCreateCount do
		local featureID = batch.deferCreations[i]
		if featureID then
			local x, y, z = spGetFeaturePosition(featureID)
			if x and IsPositionNearView(x, y, z) then
				-- Now in view, process it
				batch.pendCreateCount = batch.pendCreateCount + 1
				batch.pendCreations[batch.pendCreateCount] = featureID
				batch.deferCreations[i] = nil
			else
				-- Still out of view, keep it deferred but compact array
				remainingDeferred = remainingDeferred + 1
				if remainingDeferred ~= i then
					batch.deferCreations[remainingDeferred] = featureID
					batch.deferCreations[i] = nil
				end
			end
		end
	end
	batch.deferCreateCount = remainingDeferred

	-- Process deferred destructions - check if they're now in view
	remainingDeferred = 0
	for i = 1, batch.deferDestrCount do
		local featureID = batch.deferDestructions[i]
		if featureID then
			local feature = knownFeatures[featureID]
			if not feature or IsPositionNearView(feature.x, feature.y, feature.z) then
				-- Now in view or feature no longer exists, process it
				if knownFeatures[featureID] then
					batch.pendDestrCount = batch.pendDestrCount + 1
					batch.pendDestructions[batch.pendDestrCount] = featureID
				end
				batch.deferDestructions[i] = nil
			else
				-- Still out of view, keep it deferred but compact array
				remainingDeferred = remainingDeferred + 1
				if remainingDeferred ~= i then
					batch.deferDestructions[remainingDeferred] = featureID
					batch.deferDestructions[i] = nil
				end
			end
		end
	end
	batch.deferDestrCount = remainingDeferred
end

-- Helper: Process pending feature changes
--
-- Feature creations/destructions are batched (see FeatureCreated/Destroyed) and
-- drained here once per game frame. A large burst (game load, big battle,
-- area-reclaim, mass spawns) can queue thousands of items at once; processing
-- the whole queue in a single frame is the classic freeze. We therefore drain a
-- bounded number per call and keep the rest for subsequent frames. The overlay
-- catches up within a fraction of a second instead of stalling the game.
--
-- Pre-gamestart we intentionally drain everything at once (during the load /
-- placement phase, where a one-off spike is invisible) so all metal fields are
-- discovered immediately, preserving the prior behaviour.
local function ProcessPendingFeatureChanges()
	-- Bounded drain per frame in-game; unbounded pre-gamestart (see above).
	-- Removals can be O(k^2) in dense clusters (reachability re-scan), so their
	-- budget is kept a touch lower than creations.
	local createBudget, destroyBudget
	if gameStarted then
		createBudget = 96
		destroyBudget = 96
		if cachedKnownFeaturesCount > 4000 then
			createBudget = 64
			destroyBudget = 64
		end
		if cachedKnownFeaturesCount > 8000 then
			createBudget = 48
			destroyBudget = 48
		end

		local pendingCreates = batch.pendCreateCount - batch.pendCreateHead
		local pendingDestrs = batch.pendDestrCount - batch.pendDestrHead
		if pendingCreates > 2000 then
			createBudget = min(createBudget, 24)
		end
		if pendingCreates > 5000 then
			createBudget = min(createBudget, 16)
		end
		if batch.deferCreateCount > 1000 then
			createBudget = min(createBudget, 12)
		end
		if batch.deferCreateCount > 3000 then
			createBudget = min(createBudget, 8)
		end
		if pendingDestrs > 1000 then
			destroyBudget = min(destroyBudget, 32)
		end
	else
		createBudget = mathHuge
		destroyBudget = mathHuge
	end

	-- Process batched feature creations first
	if batch.pendCreateCount > batch.pendCreateHead then
		local head = batch.pendCreateHead
		local tail = batch.pendCreateCount
		local limit = head + createBudget
		if limit > tail then limit = tail end
		local creations = batch.pendCreations
		for i = head + 1, limit do
			local featureID = creations[i]
			creations[i] = nil
			if featureID then
				AddFeature(featureID)
			end
		end
		if limit >= tail then
			batch.pendCreateHead = 0
			batch.pendCreateCount = 0
		else
			batch.pendCreateHead = limit
		end
		dirty.needCluster = true
	end

	-- Process batched feature destructions
	if batch.pendDestrCount > batch.pendDestrHead then
		local head = batch.pendDestrHead
		local tail = batch.pendDestrCount
		local limit = head + destroyBudget
		if limit > tail then limit = tail end
		local destructions = batch.pendDestructions
		for i = head + 1, limit do
			local featureID = destructions[i]
			destructions[i] = nil
			if featureID and knownFeatures[featureID] then
				RemoveFeature(featureID)
			end
		end
		if limit >= tail then
			batch.pendDestrHead = 0
			batch.pendDestrCount = 0
		else
			batch.pendDestrHead = limit
		end
		dirty.needCluster = true
	end
end

-- Helper: Process flying features
local function ProcessFlyingFeatures(frame)
	if not next(flyingFeatures) or (frame - lastFlyingCheckFrame) < 3 then
		return false
	end

	lastFlyingCheckFrame = frame
	local featuresAdded = false

	for featureID, fInfo in pairs(flyingFeatures) do
		-- Quick validation before API call
		if spValidFeatureID(featureID) then
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

						local M_newFeature = {}
						grid.buildNeighbors(featureID, x, z, M_newFeature)
						featureNeighborsMatrix[featureID] = M_newFeature
						knownFeatures[featureID] = fInfo
						grid.insert(featureID, fInfo)
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

	return featuresAdded
end

-- Helper: Validate and remove invalid features
local function ValidateAndRemoveInvalidFeatures()
	-- Incremental scan: validating every known feature before each recluster can
	-- itself become a frame spike on large maps. We scan a bounded slice each
	-- call and rely on repeated passes + UpdateFeatureReclaim for convergence.
	local removeCount = 0
	local featureCount = cachedKnownFeaturesCount
	if featureCount <= 0 then
		return
	end

	local maxChecks = 96
	if featureCount > 4000 then maxChecks = 64 end
	if featureCount > 7000 then maxChecks = 48 end

	for _ = 1, maxChecks do
		validityCheckCounter = validityCheckCounter + 1
		if validityCheckCounter > featureCount then
			validityCheckCounter = 1
		end
		local fid = knownFeatureIDs[validityCheckCounter]
		if fid then
			if not spValidFeatureID(fid) then
				removeCount = removeCount + 1
				batch.toRemove[removeCount] = fid
			else
				local metal, _, energy = spGetFeatureResources(fid)
				local metalDepleted = not metal or metal < minFeatureValue
				local energyDepleted = not energy or energy < minFeatureValue
				if metalDepleted and energyDepleted then
					removeCount = removeCount + 1
					batch.toRemove[removeCount] = fid
				end
			end
		end
	end

	for i = 1, removeCount do
		RemoveFeature(batch.toRemove[i])
	end

	for i = 1, removeCount do
		batch.toRemove[i] = nil
	end

	if validityCheckCounter > #knownFeatureIDs then
		validityCheckCounter = 0
	end
end

-- Helper: Recreate display lists for visible clusters
local function RecreateDisplayListsForVisibleClusters()
	UpdateDrawEnabled()
	UpdateDrawEnergyEnabled()

	local dirtyMetalCount = 0
	local dirtyEnergyCount = 0
	for _ in pairs(dirty.clusters) do
		dirtyMetalCount = dirtyMetalCount + 1
	end
	for _ in pairs(dirty.energyClusters) do
		dirtyEnergyCount = dirtyEnergyCount + 1
	end

	local useIncrementalUpdate = not dirty.forceFullRedraw and ((dirtyMetalCount > 0 and dirtyMetalCount < 20) or (dirtyEnergyCount > 0 and dirtyEnergyCount < 20))

	if useIncrementalUpdate then
		for cid in pairs(dirty.clusters) do
			if featureClusters[cid] then
				local inView, dist, fadeMult = GetClusterVisibility(cid, false, drawCounter)
				if (not gameStarted and inView) or (inView and fadeMult > 0.01) then
					CreateClusterDisplayList(cid, false)
				else
					if clusterDisplayLists[cid] then
						DeleteClusterDisplayList(cid, false, true)
					end
				end
			end
		end

		for cid in pairs(dirty.energyClusters) do
			if energyFeatureClusters[cid] then
				local inView, dist, fadeMult = GetClusterVisibility(cid, true, drawCounter)
				if inView and fadeMult > 0.01 then
					CreateClusterDisplayList(cid, true)
				else
					if energyClusterDisplayLists[cid] then
						DeleteClusterDisplayList(cid, true, true)
					end
				end
			end
		end
	else
		for cid in pairs(clusterDisplayLists) do
			DeleteClusterDisplayList(cid, false)
		end
		for cid in pairs(energyClusterDisplayLists) do
			DeleteClusterDisplayList(cid, true)
		end

		if drawEnabled then
			for cid = 1, #featureClusters do
				if featureClusters[cid] then
					local inView, dist, fadeMult = GetClusterVisibility(cid, false, drawCounter)
					if (not gameStarted and inView) or (inView and fadeMult > 0.01) then
						CreateClusterDisplayList(cid, false)
					end
				end
			end
		end

		if drawEnergyEnabled and showEnergyFields and not allEnergyFieldsDrained then
			for cid = 1, #energyFeatureClusters do
				if energyFeatureClusters[cid] then
					local inView, dist, fadeMult = GetClusterVisibility(cid, true, drawCounter)
					if inView and fadeMult > 0.01 then
						CreateClusterDisplayList(cid, true)
					end
				end
			end
		end
	end

	for cid in pairs(dirty.clusters) do
		dirty.clusters[cid] = nil
	end
	for cid in pairs(dirty.energyClusters) do
		dirty.energyClusters[cid] = nil
	end

	dirty.forceFullRedraw = false
end

local function UpdateReclaimFields()
	local frame = spGetGameFrame()
	local now = os.clock()

	-- (A) A time-sliced recluster coroutine is in flight: feed it one time-slice
	-- and skip everything else. Feature mutation stays suspended (we return
	-- before ProcessPendingFeatureChanges / UpdateFeatureReclaim) so the
	-- coroutine reads a stable feature set; the previous fields keep rendering.
	if batch.clusterJobActive then
		local tClusterSlice0 = debugTiming and osClock() or 0
		local dynamicBudget = batch.clusterJobBudget
		if cachedKnownFeaturesCount >= 8000 then
			dynamicBudget = min(dynamicBudget, 0.0016)
		elseif cachedKnownFeaturesCount >= 5000 then
			dynamicBudget = min(dynamicBudget, 0.0019)
		end
		if dirty.needRedraw then
			dynamicBudget = min(dynamicBudget, 0.0015)
		end
		batch.clusterJobBudget = clamp(dynamicBudget, batch.clusterJobBudgetMin, batch.clusterJobBudgetMax)
		batch.clusterJobStart = osClock()
		local ok, err = coroutine.resume(batch.clusterJobCo)
		if debugTiming then
			local dt = osClock() - tClusterSlice0
			timingAccum.clusterSlice = timingAccum.clusterSlice + dt
			batch.clusterJobCpu = batch.clusterJobCpu + dt
			if dt > timingAccum.maxClusterSlice then timingAccum.maxClusterSlice = dt end
			if dt * 1000 >= timingAccum.spikeMs and (now - timingAccum.lastSpikeClock) >= timingAccum.spikeMinGap then
				timingAccum.lastSpikeClock = now
				Spring.Echo(string.format(
					"[ReclaimField SPIKE] cluster-slice=%.2fms  features=%d  pendingCreate=%d/%d  pendingDestr=%d/%d",
					dt * 1000,
					cachedKnownFeaturesCount,
					batch.pendCreateCount - batch.pendCreateHead,
					batch.pendCreateCount,
					batch.pendDestrCount - batch.pendDestrHead,
					batch.pendDestrCount
				))
			end
		end
		if not ok then
			batch.finishClusterTracy()
			Spring.Echo("[ReclaimFieldHighlight] cluster job error: " .. tostring(err))
			batch.clusterJobActive = false
			batch.clusterJobCo = nil
			for cid = 1, #featureClusters do
				featureClusters[cid].hullReused = nil
			end
			for cid = 1, #energyFeatureClusters do
				energyFeatureClusters[cid].hullReused = nil
			end
			batch.waitForFreshMetal = false
			batch.waitForFreshEnergy = false
			batch.metalRevealPending = false
			batch.energyRevealPending = false
			UpdateDrawEnabled()
			UpdateDrawEnergyEnabled()
		elseif coroutine.status(batch.clusterJobCo) == "dead" then
			local tFinalize0 = debugTiming and osClock() or 0
			batch.lastClusterJobCpu = batch.clusterJobCpu
			-- Build finished this frame: adopt the new clusters, match identities
			-- for fade animations. Don't force a full display-list rebuild here:
			-- it can spike this frame on large maps. The normal incremental redraw
			-- path below will rebuild visible clusters gradually.
			batch.clusterJobActive = false
			batch.clusterJobCo = nil
			batch.waitForFreshMetal = false
			batch.waitForFreshEnergy = false
			batch.metalRevealPending = false
			batch.energyRevealPending = false
			dirty.removedSinceCluster = 0
			if batch.clusterJobTerrainGeneration ~= batch.terrainGeneration then
				dirty.needCluster = true
			end
			tracy.ZoneBeginN("W:ReclaimField:Cluster:IdentitySync")
			animState.SyncClusterIdentitiesAfterClustering()
			tracy.ZoneEnd()
			lastClusterRebuildClock = now
			lastCheckFrame = frame
			lastCheckFrameClock = now
			UpdateDrawEnabled()
			UpdateDrawEnergyEnabled()
			dirty.needRedraw = true
			if debugTiming then
				local dt = osClock() - tFinalize0
				timingAccum.clusterFinalize = timingAccum.clusterFinalize + dt
				if dt > timingAccum.maxClusterFinalize then timingAccum.maxClusterFinalize = dt end
				Spring.Echo(string.format(
					"[ReclaimField CLUSTER] cpu=%.2fms finalize=%.2fms clusters=%d/%d reused=%d/%d partial=%d/%d copiedE=%d",
					batch.lastClusterJobCpu * 1000,
					dt * 1000,
					#featureClusters,
					#energyFeatureClusters,
					batch.reusedMetalHulls,
					batch.reusedEnergyHulls,
					batch.partialReusedMetalHulls,
					batch.partialReusedEnergyHulls,
					batch.copiedEnergyHulls
				))
				if dt * 1000 >= timingAccum.spikeMs and (now - timingAccum.lastSpikeClock) >= timingAccum.spikeMinGap then
					timingAccum.lastSpikeClock = now
					Spring.Echo(string.format(
						"[ReclaimField SPIKE] cluster-finalize=%.2fms  metalClusters=%d  energyClusters=%d  reused=%d/%d",
						dt * 1000,
						#featureClusters,
						#energyFeatureClusters,
						batch.reusedMetalHulls,
						batch.reusedEnergyHulls
					))
				end
			end
		end
		return
	end

	-- Process deferred features periodically or when they come into view
	if frame ~= lastProcessedFrame then
		local tDefer0 = debugTiming and osClock() or 0
		lastProcessedFrame = frame
		tracy.ZoneBeginN("W:ReclaimField:ProcessFeatureQueues")
		ProcessDeferredFeatures(frame)
		ProcessPendingFeatureChanges()
		tracy.ZoneEnd()
		if debugTiming then
			timingAccum.deferPending = timingAccum.deferPending + (osClock() - tDefer0)
		end
	end

	-- Refresh draw state before checking early return (avoid stale cached values)
	UpdateDrawEnabled()
	UpdateDrawEnergyEnabled()
	local overlayVisible = drawEnabled or (showEnergyFields and drawEnergyEnabled and not allEnergyFieldsDrained)
	local refreshPending = dirty.needCluster
		or batch.pendCreateCount > batch.pendCreateHead
		or batch.pendDestrCount > batch.pendDestrHead
	if batch.metalRevealPending then
		batch.waitForFreshMetal = gameStarted and refreshPending
		batch.metalRevealPending = false
	end
	if batch.energyRevealPending then
		batch.waitForFreshEnergy = gameStarted and refreshPending
		batch.energyRevealPending = false
	end
	if batch.waitForFreshMetal then animState.toggleMetalTarget = 0 end
	if batch.waitForFreshEnergy then animState.toggleEnergyTarget = 0 end

	-- Keep background clustering alive even when overlay is hidden, so first
	-- selection doesn't need to do all clustering/text prep in one stall.
	if not overlayVisible and not dirty.needCluster and not dirty.forceFullRedraw then
		return
	end

	-- Deferred until after the early-return: this hits spGetActiveCommand every
	-- frame, so we skip it entirely while the overlay is hidden (background mode).
	local activeReclaim = actionActive or IsActiveReclaimCommand()

	-- Decay the reclaim-churn tally toward 0 (~1.2s half-life). It is topped up
	-- in UpdateFeatureReclaim whenever features deplete / cluster values change.
	local churn = dirty.reclaimChurn
	if churn > 0 then
		local dtc = now - dirty.reclaimChurnClock
		if dtc > 0 then
			churn = churn * (0.5 ^ (dtc / 1.2))
			if churn < 0.05 then churn = 0 end
			dirty.reclaimChurn = churn
		end
	end
	dirty.reclaimChurnClock = now

	-- Adaptive backoff: the busier the map is with reclaimers, the longer we
	-- wait between the expensive recluster + display-list rebuild passes. Light
	-- reclaim stays snappy; heavy multi-reclaimer churn adds up to ~1.1s extra.
	local churnDelay = min(churn * 0.05, 1.1)

	local clusterRebuildDue
	if activeReclaim then
		-- Throttle the whole (poll + recluster + redraw) pass adaptively instead
		-- of running it every frame while a reclaim command / order is active.
		-- Base 0.12s (=> ~8 Hz) already cuts a lot versus the old every-frame path.
		if not dirty.forceFullRedraw and (now - lastCheckFrameClock) < (0.12 + churnDelay) then
			return
		end
		clusterRebuildDue = dirty.needCluster
	else
		-- Not actively reclaiming: relaxed base cadence, still stretched further
		-- when background reclaimers are churning fields all over the map.
		clusterRebuildDue = dirty.needCluster and (dirty.forceFullRedraw or (now - lastClusterRebuildClock) >= (0.75 + churnDelay))
		if not clusterRebuildDue and not dirty.forceFullRedraw and frame - lastCheckFrame < checkFrequency and now - lastCheckFrameClock < (checkFrequency/30) then
			return
		end
	end
	lastCheckFrame = spGetGameFrame()
	lastCheckFrameClock = now

	-- Adjust frequency based on feature count thresholds
	local currentFeatureCount = cachedKnownFeaturesCount
	if currentFeatureCount ~= lastFeatureCount then
		lastFeatureCount = currentFeatureCount
		if currentFeatureCount < 500 then
			featureCountMultiplier = 1
		elseif currentFeatureCount < 1500 then
			featureCountMultiplier = 2
		elseif currentFeatureCount < 3000 then
			featureCountMultiplier = 3
		else
			featureCountMultiplier = 4
		end
		checkFrequency = math.max(30, math.ceil(30 * featureCountMultiplier * checkFrequencyMult))
	end

	-- Process flying features
	local featuresAdded = ProcessFlyingFeatures(frame)

	-- Only poll feature reclaim values while overlay is visible; hidden mode is
	-- used for background clustering/prefetch and should stay cheap.
	if overlayVisible then
		local tPoll0 = debugTiming and osClock() or 0
		tracy.ZoneBeginN("W:ReclaimField:UpdateFeatureReclaim")
		UpdateFeatureReclaim()
		tracy.ZoneEnd()
		if debugTiming then
			timingAccum.reclaimPoll = timingAccum.reclaimPoll + (osClock() - tPoll0)
		end
	end

	local pendingCreates = batch.pendCreateCount - batch.pendCreateHead
	local pendingDestrs = batch.pendDestrCount - batch.pendDestrHead
	local pendingBacklog = pendingCreates + pendingDestrs
	local clusterCooldown = 0.22
	if activeReclaim then
		clusterCooldown = 0.30
	end
	if cachedKnownFeaturesCount >= 7000 then
		clusterCooldown = clusterCooldown + 0.10
	end
	local clusterStartAllowed = dirty.forceFullRedraw or ((now - lastClusterRebuildClock) >= clusterCooldown)

	if (featuresAdded or clusterRebuildDue) and (pendingBacklog == 0 or dirty.forceFullRedraw) and clusterStartAllowed then
		-- Kick off a time-sliced recluster instead of doing it all now. Block (A)
		-- above feeds the coroutine a slice per frame and finalizes it when done;
		-- the existing fields keep rendering until the new set is ready.
		tracy.ZoneBeginN("W:ReclaimField:Cluster:ValidateSnapshot")
		ValidateAndRemoveInvalidFeatures()
		animState.CapturePreClusteringSnapshot()
		tracy.ZoneEnd()
		batch.reusedMetalHulls = 0
		batch.reusedEnergyHulls = 0
		batch.partialReusedMetalHulls = 0
		batch.partialReusedEnergyHulls = 0
		batch.copiedEnergyHulls = 0
		batch.clusterJobCpu = 0
		batch.clusterJobTerrainGeneration = batch.terrainGeneration
		batch.clusterJobCo = coroutine.create(ClusterizeFeatures)
		batch.clusterJobActive = true
		dirty.removedSinceCluster = 0
	end

	if overlayVisible then
		local missingTextAnchors = false
		for cid = 1, #featureClusters do
			local cluster = featureClusters[cid]
			if cluster and cluster.center and cluster.font and cluster.font > 0 and (cluster.textX == nil or cluster.text == nil) then
				missingTextAnchors = true
				break
			end
		end
		if not missingTextAnchors and showEnergyFields and drawEnergyEnabled then
			for cid = 1, #energyFeatureClusters do
				local cluster = energyFeatureClusters[cid]
				if cluster and cluster.center and cluster.font and cluster.font > 0 and (cluster.textX == nil or cluster.text == nil) then
					missingTextAnchors = true
					break
				end
			end
		end
		if missingTextAnchors then
			tracy.ZoneBeginN("W:ReclaimField:EnsureTextAnchors")
			EnsureClusterTextAnchors()
			tracy.ZoneEnd()
			dirty.needRedraw = true
		end
	end

	if dirty.needRedraw == true then
		local tRedraw0 = debugTiming and osClock() or 0
		tracy.ZoneBeginN("W:ReclaimField:RecreateDisplayLists")
		RecreateDisplayListsForVisibleClusters()
		tracy.ZoneEnd()
		if debugTiming then
			local dt = osClock() - tRedraw0
			timingAccum.redrawLists = timingAccum.redrawLists + dt
			if dt > timingAccum.maxRedrawLists then timingAccum.maxRedrawLists = dt end
			if dt * 1000 >= timingAccum.spikeMs and (now - timingAccum.lastSpikeClock) >= timingAccum.spikeMinGap then
				timingAccum.lastSpikeClock = now
				Spring.Echo(string.format(
					"[ReclaimField SPIKE] redraw-lists=%.2fms  rebuildsThisFrame=%d  clusters=%d",
					dt * 1000,
					timingAccum.rebuilds,
					#featureClusters
				))
			end
		end
	end

	-- Update camera facing vector (used for text rotation in DrawWorld)
	local now = os.clock()
	if dirty.needRedraw or (now - (lastCameraCheckClock or 0)) >= 0.15 then
		local camUpVectorNew = spGetCameraVectors().up
		if camUpVector[1] ~= camUpVectorNew[1] or camUpVector[3] ~= camUpVectorNew[3] then
			camUpVector = camUpVectorNew
		end
		lastCameraCheckClock = now
	end

	dirty.needRedraw = false
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Widget call-ins

function widget:Initialize()
	gameStarted = Spring.GetGameFrame() > 0
	showResourceIcons = Spring.GetModOptions().scenariooptions ~= nil
	screenx, screeny = widgetHandler:GetViewSizes()
	local f = WG['fonts'] and WG['fonts'].getFont(2, 1.5)
	animCfg.font = f
	animCfg.getTextWidth = (f and f.GetTextWidth) and function(text) return f:GetTextWidth(text) end or gl.GetTextWidth

	-- Initialize camera scale early to avoid thick lines on first draw
	local cx, cy, cz = spGetCameraPosition()
	local desc, w = spTraceScreenRay(screenx / 2, screeny / 2, true)
	if desc ~= nil then
		local cameraDist = min(64000000, (cx-w[1])^2 + (cy-w[2])^2 + (cz-w[3])^2)
		cameraScale = sqrt(sqrt(cameraDist) / 600)
	else
		cameraScale = 1.0
	end

	widgetHandler:AddAction("reclaim_highlight", enableHighlight, nil, "p")
	widgetHandler:AddAction("reclaim_highlight", disableHighlight, nil, "r")

	WG['reclaimfieldhighlight'] = {}
	WG['reclaimfieldhighlight'].getShowOption = function()
		return showOption
	end
	WG['reclaimfieldhighlight'].setShowOption = function(value)
		showOption = value
	end
	WG['reclaimfieldhighlight'].getSmoothingSegments = function()
		return smoothingSegments
	end
	WG['reclaimfieldhighlight'].setSmoothingSegments = function(value)
		smoothingSegments = clamp(value, 4, 40) -- Clamp to reasonable range
		dirty.needCluster = true -- Force recluster with new settings
	end
	WG['reclaimfieldhighlight'].getShowEnergyFields = function()
		return showEnergyFields
	end
	WG['reclaimfieldhighlight'].setShowEnergyFields = function(value)
		showEnergyFields = value
		dirty.needCluster = true -- Force recluster with new settings
	end
	WG['reclaimfieldhighlight'].getShowEnergyOption = function()
		return showEnergyOption
	end
	WG['reclaimfieldhighlight'].setShowEnergyOption = function(value)
		showEnergyOption = value
	end
	WG['reclaimfieldhighlight'].getFadeStartDistance = function()
		return fadeStartDistance
	end
	WG['reclaimfieldhighlight'].setFadeStartDistance = function(value)
		fadeStartDistance = max(100, value)
		-- Ensure start < end
		if fadeStartDistance >= fadeEndDistance then
			fadeEndDistance = fadeStartDistance + 1000
		end
	end
	WG['reclaimfieldhighlight'].getFadeEndDistance = function()
		return fadeEndDistance
	end
	WG['reclaimfieldhighlight'].setFadeEndDistance = function(value)
		fadeEndDistance = max(fadeStartDistance + 100, value)
	end

	WG['reclaimfieldhighlight'].getAlwaysShowFields = function()
		return alwaysShowFields
	end
	WG['reclaimfieldhighlight'].setAlwaysShowFields = function(value)
		alwaysShowFields = value
	end

	WG['reclaimfieldhighlight'].getAlwaysShowFieldsThreshold = function()
		return alwaysShowFieldsThreshold
	end
	WG['reclaimfieldhighlight'].setAlwaysShowFieldsThreshold = function(value)
		-- Deprecated - threshold is now auto-calculated
		-- This function kept for backwards compatibility
	end

	WG['reclaimfieldhighlight'].getAlwaysShowFieldsMinThreshold = function()
		return alwaysShowFieldsMinThreshold
	end
	WG['reclaimfieldhighlight'].setAlwaysShowFieldsMinThreshold = function(value)
		alwaysShowFieldsMinThreshold = max(0, value)
		alwaysShowFieldsThreshold = CalculateAlwaysShowThreshold()
	end

	WG['reclaimfieldhighlight'].getAlwaysShowFieldsMaxThreshold = function()
		return alwaysShowFieldsMaxThreshold
	end
	WG['reclaimfieldhighlight'].setAlwaysShowFieldsMaxThreshold = function(value)
		alwaysShowFieldsMaxThreshold = max(alwaysShowFieldsMinThreshold, value)
		alwaysShowFieldsThreshold = CalculateAlwaysShowThreshold()
	end

	WG['reclaimfieldhighlight'].getTotalMapMetal = function()
		return totalMapMetal
	end

	-- Deferred update settings
	WG['reclaimfieldhighlight'].getDeferOutOfViewUpdates = function()
		return batch.deferOutOfView
	end
	WG['reclaimfieldhighlight'].setDeferOutOfViewUpdates = function(value)
		batch.deferOutOfView = value
	end
	WG['reclaimfieldhighlight'].getOutOfViewMargin = function()
		return batch.outOfViewMargin
	end
	WG['reclaimfieldhighlight'].setOutOfViewMargin = function(value)
		batch.outOfViewMargin = max(0, value)
	end

	-- Diagnostics: toggle a periodic timing echo (per-call ms for the update
	-- pass vs the draw/rebuild passes, plus display-list rebuilds per frame) so
	-- it's easy to confirm whether updating or drawing is the per-frame cost.
	WG['reclaimfieldhighlight'].getDebugTiming = function()
		return debugTiming
	end
	WG['reclaimfieldhighlight'].setDebugTiming = function(value)
		debugTiming = value and true or false
	end
	WG['reclaimfieldhighlight'].getTimingInterval = function()
		return timingInterval
	end
	WG['reclaimfieldhighlight'].setTimingInterval = function(value)
		timingInterval = max(10, floor(tonumber(value) or timingInterval))
	end
	WG['reclaimfieldhighlight'].getTimingSpikeMs = function()
		return timingAccum.spikeMs
	end
	WG['reclaimfieldhighlight'].setTimingSpikeMs = function(value)
		timingAccum.spikeMs = max(0.5, tonumber(value) or timingAccum.spikeMs)
	end
	WG['reclaimfieldhighlight'].getClusterSliceBudgetMs = function()
		return floor((batch.clusterJobBudget or 0) * 1000 + 0.5)
	end
	WG['reclaimfieldhighlight'].setClusterSliceBudgetMs = function(value)
		local ms = tonumber(value)
		if not ms then return end
		batch.clusterJobBudget = clamp(ms * 0.001, batch.clusterJobBudgetMin, batch.clusterJobBudgetMax)
	end
	WG['reclaimfieldhighlight'].printTimingNow = function()
		local denom = timingCount > 0 and timingCount or 1
		Spring.Echo(string.format(
			"[ReclaimField TIMING NOW] avg(ms): UpdReclaim=%.3f DrawText=%.3f DrawPre=%.3f Update=%.3f DefPend=%.3f Poll=%.3f Slice=%.3f Final=%.3f Redraw=%.3f | max(ms): Upd=%.2f DrawPre=%.2f Slice=%.2f Final=%.2f Redraw=%.2f | DL/frame=%.1f lastJob=%.2fms reuse=%d/%d partial=%d/%d copiedE=%d",
			timingAccum.updateReclaim / denom * 1000,
			timingAccum.drawWorldText / denom * 1000,
			timingAccum.drawPreUnit / denom * 1000,
			timingAccum.updateFunc / denom * 1000,
			timingAccum.deferPending / denom * 1000,
			timingAccum.reclaimPoll / denom * 1000,
			timingAccum.clusterSlice / denom * 1000,
			timingAccum.clusterFinalize / denom * 1000,
			timingAccum.redrawLists / denom * 1000,
			timingAccum.maxUpdateReclaim * 1000,
			timingAccum.maxDrawPreUnit * 1000,
			timingAccum.maxClusterSlice * 1000,
			timingAccum.maxClusterFinalize * 1000,
			timingAccum.maxRedrawLists * 1000,
			timingAccum.rebuilds / denom,
			batch.lastClusterJobCpu * 1000,
			batch.reusedMetalHulls,
			batch.reusedEnergyHulls,
			batch.partialReusedMetalHulls,
			batch.partialReusedEnergyHulls,
			batch.copiedEnergyHulls
		))
	end

	-- Start/restart feature clustering.
	knownFeatures = {}
	flyingFeatures = {}
	featureNeighborsMatrix = {}
	knownFeatureIDs = {}
	featureClusters = {}
	featureConvexHulls = {}
	energyFeatureClusters = {}
	energyFeatureConvexHulls = {}
	opticsObject = Optics.new()
	cachedKnownFeaturesCount = 0 -- Reset cached count
	featureReclaimScanCounter = 0

	-- Reset the spatial grid and the batched-change queues so a widget reload
	-- doesn't leave stale cells/cursors behind.
	for k in pairs(grid.cells) do grid.cells[k] = nil end
	batch.pendCreateCount = 0
	batch.pendCreateHead = 0
	batch.pendDestrCount = 0
	batch.pendDestrHead = 0
	batch.deferCreateCount = 0
	batch.deferDestrCount = 0
	-- Drop any in-flight time-sliced recluster coroutine from a previous load.
	batch.clusterJobActive = false
	batch.clusterJobCo = nil
	batch.waitForFreshMetal = false
	batch.waitForFreshEnergy = false
	batch.metalRevealPending = false
	batch.energyRevealPending = false

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

	-- Clean up per-cluster display lists
	for cid in pairs(clusterDisplayLists) do
		DeleteClusterDisplayList(cid, false)
	end
	for cid in pairs(energyClusterDisplayLists) do
		DeleteClusterDisplayList(cid, true)
	end

	-- Clean up fading-out cluster display lists
	for uid in pairs(animState.fading) do
		animState.DeleteFadingCluster(uid, false)
	end
	for uid in pairs(animState.fadingEnergy) do
		animState.DeleteFadingCluster(uid, true)
	end

	-- Clean up old monolithic display lists (for compatibility)
	if drawFeatureConvexHullGradientList ~= nil then
		glDeleteList(drawFeatureConvexHullGradientList)
	end
	if drawFeatureConvexHullEdgeList ~= nil then
		glDeleteList(drawFeatureConvexHullEdgeList)
	end
	if drawEnergyConvexHullEdgeList ~= nil then
		glDeleteList(drawEnergyConvexHullEdgeList)
	end
end

function widget:GetConfigData(data)
    return {
		showOption = showOption,
		showEnergyOption = showEnergyOption,
		smoothingSegments = smoothingSegments,
		showEnergyFields = showEnergyFields,
		fadeStartDistance = fadeStartDistance,
		fadeEndDistance = fadeEndDistance,
		alwaysShowFields = alwaysShowFields,
		alwaysShowFieldsMinThreshold = alwaysShowFieldsMinThreshold,
		alwaysShowFieldsMaxThreshold = alwaysShowFieldsMaxThreshold
	}
end

function widget:SetConfigData(data)
	if data.showOption ~= nil then
		showOption = data.showOption
	end
	if data.showEnergyOption ~= nil then
		showEnergyOption = data.showEnergyOption
	end
	if data.showEnergyFields ~= nil then
		showEnergyFields = data.showEnergyFields
	end
	if data.alwaysShowFields ~= nil then
		alwaysShowFields = data.alwaysShowFields
	end
	if data.alwaysShowFieldsMinThreshold ~= nil then
		alwaysShowFieldsMinThreshold = data.alwaysShowFieldsMinThreshold
	end
	if data.alwaysShowFieldsMaxThreshold ~= nil then
		alwaysShowFieldsMaxThreshold = data.alwaysShowFieldsMaxThreshold
	end
	-- Legacy support for old fixed threshold
	if data.alwaysShowFieldsThreshold ~= nil and data.alwaysShowFieldsMinThreshold == nil then
		alwaysShowFieldsMinThreshold = data.alwaysShowFieldsThreshold
	end
	if data.fadeStartDistance ~= nil then
		--fadeStartDistance = data.fadeStartDistance
	end
	if data.fadeEndDistance ~= nil then
		--fadeEndDistance = data.fadeEndDistance
	end
	-- if data.smoothingSegments ~= nil then
	-- 	smoothingSegments = clamp(data.smoothingSegments, 2, 10)
	-- end
end

function widget:GameStart()
	-- Update gameStarted flag when game transitions from lobby to active
	gameStarted = true
	-- Force draw state update to respect showOption settings now that game has started
	UpdateDrawEnabled()
	UpdateDrawEnergyEnabled()
	-- Force full redraw with new draw state
	dirty.needRedraw = true
	dirty.forceFullRedraw = true
end

function widget:Update(dt)
	local tU0 = osClock()
	-- Update camera scale when enabled
	-- Always call both to keep cached draw states current (avoid short-circuit skipping)
	local metalEnabled = UpdateDrawEnabled()
	local energyEnabled = UpdateDrawEnergyEnabled()
	if metalEnabled or energyEnabled then
		local cx, cy, cz = spGetCameraPosition()
		-- Only recompute cameraScale if camera actually moved
		local dx, dy, dz = cx - cachedCameraX, cy - cachedCameraY, cz - cachedCameraZ
		if dx*dx + dy*dy + dz*dz > 1 then
			local desc, w = spTraceScreenRay(screenx / 2, screeny / 2, true)
			local cameraDist = 35000000
			if desc ~= nil then
				cameraDist = min(64000000, (cx-w[1])^2 + (cy-w[2])^2 + (cz-w[3])^2)
			end
			cameraScale = sqrt(sqrt(cameraDist) / 600)
		end
	end
	if debugTiming then
		timingAccum.updateFunc = timingAccum.updateFunc + (osClock() - tU0)
	end
end

function widget:FeatureCreated(featureID, allyTeamID)
	-- Check if feature is near the camera view
	local x, y, z = spGetFeaturePosition(featureID)
	-- Pre-gamestart: process all features immediately to discover all metal fields
	if x and gameStarted and batch.deferOutOfView and not IsPositionNearView(x, y, z) then
		-- Defer processing for out-of-view features
		batch.deferCreateCount = batch.deferCreateCount + 1
		batch.deferCreations[batch.deferCreateCount] = featureID
		return
	end

	-- Batch feature creations instead of processing immediately
	-- This significantly improves performance during catch-up when hundreds of features are created per frame
	batch.pendCreateCount = batch.pendCreateCount + 1
	batch.pendCreations[batch.pendCreateCount] = featureID
end

function widget:FeatureDestroyed(featureID, allyTeamID)
	-- Check if feature is near the camera view (use known position if available)
	local feature = knownFeatures[featureID]
	-- Pre-gamestart: process all features immediately to discover all metal fields
	if feature and gameStarted and batch.deferOutOfView and not IsPositionNearView(feature.x, feature.y, feature.z) then
		-- Defer processing for out-of-view features
		batch.deferDestrCount = batch.deferDestrCount + 1
		batch.deferDestructions[batch.deferDestrCount] = featureID
		return
	end

	-- Batch feature destructions instead of processing immediately
	-- This significantly improves performance during catch-up when hundreds of features are destroyed per frame
	if knownFeatures[featureID] ~= nil then
		batch.pendDestrCount = batch.pendDestrCount + 1
		batch.pendDestructions[batch.pendDestrCount] = featureID
	elseif flyingFeatures[featureID] then
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
	vsx, vsy = Spring.GetViewGeometry()
	local f = WG['fonts'] and WG['fonts'].getFont(2, 1.5)
	animCfg.font = f
	animCfg.getTextWidth = (f and f.GetTextWidth) and function(text) return f:GetTextWidth(text) end or gl.GetTextWidth
end

function widget:UnsyncedHeightMapUpdate()
	batch.terrainGeneration = batch.terrainGeneration + 1
	dirty.needCluster = true
end

--------------------------------------------------------------------------------
-- Per-cluster draw helpers (hoisted to module scope so widget:DrawWorldPreUnit
-- doesn't reallocate them as closures every frame).
--------------------------------------------------------------------------------

local function DrawLiveCluster(cid, isEnergy, drawGradient)
	local clusters = isEnergy and energyFeatureClusters or featureClusters
	local cluster = clusters[cid]
	if not cluster then return 0 end

	-- Drive the smoothed visibility tween: query GetClusterVisibility on the
	-- gradient pass each frame so the anim entry's visTarget stays current.
	if drawGradient then
		GetClusterVisibility(cid, isEnergy, drawCounter)
	end

	local effAlpha, animScale = animState.GetClusterAnimAlphaAndScale(cluster.uid, isEnergy)
	if effAlpha <= 0.001 then return 0 end

	local clusterData
	if isEnergy then
		clusterData = energyClusterDisplayLists[cid]
	else
		clusterData = clusterDisplayLists[cid]
	end
	if drawGradient then
		local needRebuild = false
		local mustRebuild = false
		if not clusterData or not clusterData.gradient then
			needRebuild = true
			mustRebuild = true -- nothing to draw yet, must build geometry now
		elseif not clusterData.bakedAlpha or abs(effAlpha - clusterData.bakedAlpha) > animCfg.rebuildThreshold then
			needRebuild = true
		end
		if needRebuild then
			-- Refresh the per-frame rebuild budgets on the first request this frame.
			if animCfg.rebuildBudgetFrame ~= drawCounter then
				animCfg.rebuildBudgetFrame = drawCounter
				-- While the camera is panning, throttle alpha-only rebuilds hard
				-- (distance fade would otherwise rebuild dozens of lists/frame).
				local cameraMoving = (drawCounter - animCfg.cameraMoveDraw) <= animCfg.cameraSettleDraws
				animCfg.rebuildBudgetRemaining = cameraMoving and animCfg.movingRebuildsPerFrame or animCfg.maxRebuildsPerFrame
				animCfg.newBuildBudgetRemaining = animCfg.newBuildsPerFrame
			end
			-- Split budgets: brand-new geometry (mustRebuild) is spread with its
			-- own budget so a fresh recluster's hundreds of lists build over a few
			-- frames; alpha-only fade rebuilds use the (camera-aware) fade budget.
			local doBuild = false
			if mustRebuild then
				if animCfg.newBuildBudgetRemaining > 0 then
					animCfg.newBuildBudgetRemaining = animCfg.newBuildBudgetRemaining - 1
					doBuild = true
				end
			elseif animCfg.rebuildBudgetRemaining > 0 then
				animCfg.rebuildBudgetRemaining = animCfg.rebuildBudgetRemaining - 1
				doBuild = true
			end
			if doBuild then
				if isEnergy then energyClusterStateHashes[cid] = nil else clusterStateHashes[cid] = nil end
				CreateClusterDisplayList(cid, isEnergy, effAlpha)
				clusterData = isEnergy and energyClusterDisplayLists[cid] or clusterDisplayLists[cid]
			end
		end
		if clusterData and clusterData.gradient then
			if animScale ~= 1 then
				local center = cluster.center
				local cx, cz = center.x, center.z
				glPushMatrix()
				glTranslate(cx, 0, cz)
				glScale(animScale, 1, animScale)
				glTranslate(-cx, 0, -cz)
				glCallList(clusterData.gradient)
				glPopMatrix()
			else
				glCallList(clusterData.gradient)
			end
		end
	else
		if clusterData and clusterData.edge then
			local edgeCol = isEnergy and energyReclaimEdgeColor or reclaimEdgeColor
			if isEnergy then
				glColor(edgeCol[1], edgeCol[2], edgeCol[3], edgeCol[4] * energyOpacityMultiplier * effAlpha)
			else
				glColor(edgeCol[1], edgeCol[2], edgeCol[3], edgeCol[4] * effAlpha)
			end
			if animScale ~= 1 then
				local center = cluster.center
				local cx, cz = center.x, center.z
				glPushMatrix()
				glTranslate(cx, 0, cz)
				glScale(animScale, 1, animScale)
				glTranslate(-cx, 0, -cz)
				glCallList(clusterData.edge)
				glPopMatrix()
			else
				glCallList(clusterData.edge)
			end
		end
	end
	return effAlpha
end

local function DrawFadingCluster(uid, entry, drawGradient)
	local alpha = entry.alpha or 0
	if alpha <= 0.001 then return end
	local center = entry.center
	if not center then return end
	local inView = IsInCameraView(center.x, center.y, center.z, 600, drawCounter)
	if not inView then return end

	if drawGradient then
		local dl = entry.displayLists
		local mustRebuild = not dl or not dl.gradient
		local wantRebuild = mustRebuild
			or not entry.lastBakedAlpha or abs(alpha - entry.lastBakedAlpha) > animCfg.rebuildThreshold
		if wantRebuild then
			if animCfg.rebuildBudgetFrame ~= drawCounter then
				animCfg.rebuildBudgetFrame = drawCounter
				local cameraMoving = (drawCounter - animCfg.cameraMoveDraw) <= animCfg.cameraSettleDraws
				animCfg.rebuildBudgetRemaining = cameraMoving and animCfg.movingRebuildsPerFrame or animCfg.maxRebuildsPerFrame
			end
			if mustRebuild or animCfg.rebuildBudgetRemaining > 0 then
				if not mustRebuild then
					animCfg.rebuildBudgetRemaining = animCfg.rebuildBudgetRemaining - 1
				end
				CreateFadingClusterDisplayList(uid, entry.isEnergy)
				dl = entry.displayLists
			end
		end
		if dl and dl.gradient then
			glCallList(dl.gradient)
		end
	else
		local dl = entry.displayLists
		if dl and dl.edge then
			local edgeCol = entry.isEnergy and energyReclaimEdgeColor or reclaimEdgeColor
			if entry.isEnergy then
				glColor(edgeCol[1], edgeCol[2], edgeCol[3], edgeCol[4] * energyOpacityMultiplier * alpha)
			else
				glColor(edgeCol[1], edgeCol[2], edgeCol[3], edgeCol[4] * alpha)
			end
			glCallList(dl.edge)
		end
	end
end

function widget:DrawWorld()
	if spIsGUIHidden() == true then return end

	local hasFadingMetal = next(animState.fading) ~= nil
	local hasFadingEnergy = next(animState.fadingEnergy) ~= nil
	local showMetal = not batch.waitForFreshMetal
		and (drawEnabled or animState.toggleMetal > 0.005 or hasFadingMetal)
	local showEnergy = not batch.waitForFreshEnergy
		and ((showEnergyFields and drawEnergyEnabled and not allEnergyFieldsDrained)
			or (showEnergyFields and animState.toggleEnergy > 0.005)
			or hasFadingEnergy)
	if not showMetal and not showEnergy then return end

	local t0 = debugTiming and osClock() or 0

	glDepthTest(false)
	glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)

	-- Compute rotation components directly from camUpVector
	local upX, upZ = -camUpVector[1], -camUpVector[3]
	local lenSq = upX * upX + upZ * upZ
	local cosF, sinF
	if lenSq > 0.0001 then
		local invLen = 1 / sqrt(lenSq)
		cosF = upZ * invLen
		sinF = upX * invLen
	else
		cosF, sinF = 1, 0
	end
	local negSinF = -sinF
	local negCosF = -cosF

	-- Draw text using high-quality font in IMMEDIATE mode (no outer Begin/End).
	-- Inside a Begin/End block the font batches all quads and flushes them at
	-- End() with whatever modelview is current then (identity -> origin). In
	-- immediate mode each Print flushes with the current GL matrix, so our
	-- ground-plane glMultMatrix applies and text lies flat like the icons.
	tracy.ZoneBeginN("W:ReclaimField:DrawLabels")
	local widgetFont = animCfg.font
	if widgetFont then
		if showMetal then
			local nc = numberColor
			for clusterID = 1, #featureClusters do
				local cluster = featureClusters[clusterID]
				if cluster and cluster.textX then
					local effAlpha = animState.GetClusterAnimAlphaAndScale(cluster.uid, false)
					if effAlpha > 0.001 then
						local drawAlpha = max(effAlpha, 0.2)
						widgetFont:SetOutlineColor(0, 0, 0, 0.7 * drawAlpha)
						widgetFont:SetTextColor(nc[1], nc[2], nc[3], nc[4] * drawAlpha)
						local fs = cluster.font
						local textOX = showResourceIcons and (fs * (iconSizeRatio + iconGapRatio)) * 0.5 or 0
						glPushMatrix()
						glMultMatrix(cosF, 0, negSinF, 0, negSinF, 0, negCosF, 0, 0, 1, 0, 0, cluster.textX, cluster.center.y, cluster.textZ, 1)
						widgetFont:Print(cluster.text, textOX, 0, fs, "cov")
						glPopMatrix()
					end
				end
			end
			for uid, entry in pairs(animState.fading) do
				local alpha = entry.alpha or 0
				if alpha > 0.001 and entry.text then
						local drawAlpha = max(alpha, 0.2)
					widgetFont:SetOutlineColor(0, 0, 0, 0.7 * drawAlpha)
					widgetFont:SetTextColor(nc[1], nc[2], nc[3], nc[4] * drawAlpha)
					local fs = entry.font or fontSizeMin
					local textOX = showResourceIcons and (fs * (iconSizeRatio + iconGapRatio)) * 0.5 or 0
					glPushMatrix()
					glMultMatrix(cosF, 0, negSinF, 0, negSinF, 0, negCosF, 0, 0, 1, 0, 0, entry.textX, entry.center.y, entry.textZ, 1)
					widgetFont:Print(entry.text, textOX, 0, fs, "cov")
					glPopMatrix()
				end
			end
		end
		if showEnergy then
			local enc = energyNumberColor
			for clusterID = 1, #energyFeatureClusters do
				local cluster = energyFeatureClusters[clusterID]
				if cluster and cluster.textX then
					local effAlpha = animState.GetClusterAnimAlphaAndScale(cluster.uid, true)
					if effAlpha > 0.001 then
						local drawAlpha = max(effAlpha, 0.2)
						widgetFont:SetOutlineColor(0, 0, 0, 0.7 * drawAlpha)
						widgetFont:SetTextColor(enc[1], enc[2], enc[3], enc[4] * drawAlpha)
						local fs = cluster.font * energyTextSizeMultiplier
						local textOX = showResourceIcons and (fs * (iconSizeRatio + iconGapRatio)) * 0.5 or 0
						glPushMatrix()
						glMultMatrix(cosF, 0, negSinF, 0, negSinF, 0, negCosF, 0, 0, 1, 0, 0, cluster.textX, cluster.center.y, cluster.textZ, 1)
						widgetFont:Print(cluster.text, textOX, 0, fs, "cov")
						glPopMatrix()
					end
				end
			end
			for uid, entry in pairs(animState.fadingEnergy) do
				local alpha = entry.alpha or 0
				if alpha > 0.001 and entry.text then
						local drawAlpha = max(alpha, 0.2)
					widgetFont:SetOutlineColor(0, 0, 0, 0.7 * drawAlpha)
					widgetFont:SetTextColor(enc[1], enc[2], enc[3], enc[4] * drawAlpha)
					local fs = (entry.font or fontSizeMin) * energyTextSizeMultiplier
					local textOX = showResourceIcons and (fs * (iconSizeRatio + iconGapRatio)) * 0.5 or 0
					glPushMatrix()
					glMultMatrix(cosF, 0, negSinF, 0, negSinF, 0, negCosF, 0, 0, 1, 0, 0, entry.textX, entry.center.y, entry.textZ, 1)
					widgetFont:Print(entry.text, textOX, 0, fs, "cov")
					glPopMatrix()
				end
			end
		end
	else
		-- Fallback to gl.Text if font handler not available
		if showMetal then
			for clusterID = 1, #featureClusters do
				local cluster = featureClusters[clusterID]
				if cluster and cluster.textX then
					local effAlpha = animState.GetClusterAnimAlphaAndScale(cluster.uid, false)
					if effAlpha > 0.01 then
						local nc = numberColor
						glColor(nc[1], nc[2], nc[3], nc[4] * effAlpha)
						glPushMatrix()
						glMultMatrix(cosF, 0, negSinF, 0, negSinF, 0, negCosF, 0, 0, 1, 0, 0, cluster.textX, cluster.center.y, cluster.textZ, 1)
						glText(cluster.text, 0, 0, cluster.font, "co")
						glPopMatrix()
					end
				end
			end
			for uid, entry in pairs(animState.fading) do
				local alpha = entry.alpha or 0
				if alpha > 0.01 and entry.text then
					local nc = numberColor
					glColor(nc[1], nc[2], nc[3], nc[4] * alpha)
					glPushMatrix()
					glMultMatrix(cosF, 0, negSinF, 0, negSinF, 0, negCosF, 0, 0, 1, 0, 0, entry.textX, entry.center.y, entry.textZ, 1)
					glText(entry.text, 0, 0, entry.font or fontSizeMin, "co")
					glPopMatrix()
				end
			end
		end
		if showEnergy then
			for clusterID = 1, #energyFeatureClusters do
				local cluster = energyFeatureClusters[clusterID]
				if cluster and cluster.textX then
					local effAlpha = animState.GetClusterAnimAlphaAndScale(cluster.uid, true)
					if effAlpha > 0.01 then
						local enc = energyNumberColor
						glColor(enc[1], enc[2], enc[3], enc[4] * effAlpha)
						glPushMatrix()
						glMultMatrix(cosF, 0, negSinF, 0, negSinF, 0, negCosF, 0, 0, 1, 0, 0, cluster.textX, cluster.center.y, cluster.textZ, 1)
						glText(cluster.text, 0, 0, cluster.font * energyTextSizeMultiplier, "co")
						glPopMatrix()
					end
				end
			end
			for uid, entry in pairs(animState.fadingEnergy) do
				local alpha = entry.alpha or 0
				if alpha > 0.01 and entry.text then
					local enc = energyNumberColor
					glColor(enc[1], enc[2], enc[3], enc[4] * alpha)
					glPushMatrix()
					glMultMatrix(cosF, 0, negSinF, 0, negSinF, 0, negCosF, 0, 0, 1, 0, 0, entry.textX, entry.center.y, entry.textZ, 1)
					glText(entry.text, 0, 0, (entry.font or fontSizeMin) * energyTextSizeMultiplier, "co")
					glPopMatrix()
				end
			end
		end
	end
	tracy.ZoneEnd()

	-- Draw resource icons (ground-plane quads to the left of each value label,
	-- using the same matrix as the text so they lie flat like the labels do)
	if showResourceIcons then
		tracy.ZoneBeginN("W:ReclaimField:DrawResourceIcons")
		local glTexRect = gl.TexRect
		local glTexture = gl.Texture
		local getTextWidth = animCfg.getTextWidth or gl.GetTextWidth
		if showMetal then
			glTexture(":l:LuaUI/Images/metal.png")
			for clusterID = 1, #featureClusters do
				local cluster = featureClusters[clusterID]
				if cluster and cluster.textX and cluster.text then
					local effAlpha = animState.GetClusterAnimAlphaAndScale(cluster.uid, false)
					if effAlpha > 0.01 then
						local fs = cluster.font
						local is = fs * iconSizeRatio
						local tw = getTextWidth(cluster.text) * fs
						local ix1 = -(tw + fs * iconGapRatio + is) * 0.5
						glPushMatrix()
						glMultMatrix(cosF, 0, negSinF, 0, negSinF, 0, negCosF, 0, 0, 1, 0, 0, cluster.textX, cluster.center.y, cluster.textZ, 1)
						glColor(numberColor[1], numberColor[2], numberColor[3], numberColor[4] * max(effAlpha, 0.2))
						glTexRect(ix1, -is * 0.5, ix1 + is, is * 0.5)
						glPopMatrix()
					end
				end
			end
			for uid, entry in pairs(animState.fading) do
				local alpha = entry.alpha or 0
				if alpha > 0.01 and entry.text then
					local fs = entry.font or fontSizeMin
					local is = fs * iconSizeRatio
					local tw = getTextWidth(entry.text) * fs
					local ix1 = -(tw + fs * iconGapRatio + is) * 0.5
					glPushMatrix()
					glMultMatrix(cosF, 0, negSinF, 0, negSinF, 0, negCosF, 0, 0, 1, 0, 0, entry.textX, entry.center.y, entry.textZ, 1)
					glColor(numberColor[1], numberColor[2], numberColor[3], numberColor[4] * max(alpha, 0.2))
					glTexRect(ix1, -is * 0.5, ix1 + is, is * 0.5)
					glPopMatrix()
				end
			end
			glTexture(false)
		end
		if showEnergy then
			glTexture(":l:LuaUI/Images/energy.png")
			for clusterID = 1, #energyFeatureClusters do
				local cluster = energyFeatureClusters[clusterID]
				if cluster and cluster.textX and cluster.text then
					local effAlpha = animState.GetClusterAnimAlphaAndScale(cluster.uid, true)
					if effAlpha > 0.01 then
						local fs = cluster.font * energyTextSizeMultiplier
						local is = fs * iconSizeRatio
						local tw = getTextWidth(cluster.text) * fs
						local ix1 = -(tw + fs * iconGapRatio + is) * 0.5
						glPushMatrix()
						glMultMatrix(cosF, 0, negSinF, 0, negSinF, 0, negCosF, 0, 0, 1, 0, 0, cluster.textX, cluster.center.y, cluster.textZ, 1)
						glColor(energyNumberColor[1], energyNumberColor[2], energyNumberColor[3], energyNumberColor[4] * max(effAlpha, 0.2))
						glTexRect(ix1, -is * 0.5, ix1 + is, is * 0.5)
						glPopMatrix()
					end
				end
			end
			for uid, entry in pairs(animState.fadingEnergy) do
				local alpha = entry.alpha or 0
				if alpha > 0.01 and entry.text then
					local fs = (entry.font or fontSizeMin) * energyTextSizeMultiplier
					local is = fs * iconSizeRatio
					local tw = getTextWidth(entry.text) * fs
					local ix1 = -(tw + fs * iconGapRatio + is) * 0.5
					glPushMatrix()
					glMultMatrix(cosF, 0, negSinF, 0, negSinF, 0, negCosF, 0, 0, 1, 0, 0, entry.textX, entry.center.y, entry.textZ, 1)
					glColor(energyNumberColor[1], energyNumberColor[2], energyNumberColor[3], energyNumberColor[4] * max(alpha, 0.2))
					glTexRect(ix1, -is * 0.5, ix1 + is, is * 0.5)
					glPopMatrix()
				end
			end
			glTexture(false)
		end
		tracy.ZoneEnd()
	end

	glDepthTest(true)
	if debugTiming then
		timingAccum.drawWorldText = timingAccum.drawWorldText + (osClock() - t0)
	end
end

function widget:DrawWorldPreUnit()
	drawCounter = drawCounter + 1

	local frame = spGetGameFrame()
	local sameGameFrameAsLastDraw = (frame == batch.lastUpdateDrawFrame)
	local hadRenderOnlyDraw = batch.sawRenderOnlyDraw
	batch.lastUpdateDrawFrame = frame
	batch.sawRenderOnlyDraw = sameGameFrameAsLastDraw
	local shouldUpdateReclaim = sameGameFrameAsLastDraw or not hadRenderOnlyDraw
	if shouldUpdateReclaim then
		local tUpd0 = debugTiming and osClock() or 0
		tracy.ZoneBeginN("W:ReclaimField:UpdateReclaimFields")
		UpdateReclaimFields()
		tracy.ZoneEnd()
		if debugTiming then
			local dt = osClock() - tUpd0
			timingAccum.updateReclaim = timingAccum.updateReclaim + dt
			if dt > timingAccum.maxUpdateReclaim then timingAccum.maxUpdateReclaim = dt end
			if dt * 1000 >= timingAccum.spikeMs and (osClock() - timingAccum.lastSpikeClock) >= timingAccum.spikeMinGap then
				timingAccum.lastSpikeClock = osClock()
				Spring.Echo(string.format(
					"[ReclaimField SPIKE] UpdateReclaimFields=%.2fms  features=%d  metalClusters=%d  energyClusters=%d",
					dt * 1000,
					cachedKnownFeaturesCount,
					#featureClusters,
					#energyFeatureClusters
				))
			end
		end
	end

	-- Tick animations once per draw using a wall-clock dt (works while paused)
	tracy.ZoneBeginN("W:ReclaimField:TickAnimations")
	animState.TickClusterAnimations(osClock())
	tracy.ZoneEnd()

	-- Before gamestart, always show; after gamestart, check drawEnabled
	if spIsGUIHidden() == true then
		return
	end

	-- Determine if we need to draw anything. We continue rendering during
	-- toggle-fade-out, and we always render currently fading-out clusters.
	local hasFadingMetal = next(animState.fading) ~= nil
	local hasFadingEnergy = next(animState.fadingEnergy) ~= nil
	local showMetal = not batch.waitForFreshMetal
		and (drawEnabled or animState.toggleMetal > 0.005 or hasFadingMetal)
	local showEnergy = not batch.waitForFreshEnergy
		and ((showEnergyFields and drawEnergyEnabled and not allEnergyFieldsDrained)
			or (showEnergyFields and animState.toggleEnergy > 0.005)
			or hasFadingEnergy)

	if not showMetal and not showEnergy then
		return
	end

	-- Reset GL state at the start
	glDepthTest(false)
	glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	glLineWidth((1 + ((vsy / 1440) * 2.5)) / cameraScale)

	local tVis0 = debugTiming and osClock() or 0

	-- Draw metal fields (gradient + edge)
	if showMetal then
		-- Gradient layer (pushed down by 1 unit)
		tracy.ZoneBeginN("W:ReclaimField:DrawMetalGradient")
		glPushMatrix()
		glTranslate(0, -1, 0)
		for cid = 1, #featureClusters do
			DrawLiveCluster(cid, false, true)
		end
		-- Fading-out metal clusters
		for uid, entry in pairs(animState.fading) do
			DrawFadingCluster(uid, entry, true)
		end
		glPopMatrix()
		tracy.ZoneEnd()

		-- Edge layer (reuse cached visibility from gradient pass)
		tracy.ZoneBeginN("W:ReclaimField:DrawMetalEdge")
		for cid = 1, #featureClusters do
			DrawLiveCluster(cid, false, false)
		end
		for uid, entry in pairs(animState.fading) do
			DrawFadingCluster(uid, entry, false)
		end
		tracy.ZoneEnd()
	end

	-- Draw energy fields (gradient + edge)
	if showEnergy then
		tracy.ZoneBeginN("W:ReclaimField:DrawEnergyGradient")
		glPushMatrix()
		glTranslate(0, -1, 0)
		for cid = 1, #energyFeatureClusters do
			DrawLiveCluster(cid, true, true)
		end
		for uid, entry in pairs(animState.fadingEnergy) do
			DrawFadingCluster(uid, entry, true)
		end
		glPopMatrix()
		tracy.ZoneEnd()

		tracy.ZoneBeginN("W:ReclaimField:DrawEnergyEdge")
		for cid = 1, #energyFeatureClusters do
			DrawLiveCluster(cid, true, false)
		end
		for uid, entry in pairs(animState.fadingEnergy) do
			DrawFadingCluster(uid, entry, false)
		end
		tracy.ZoneEnd()
	end

	glLineWidth(1.0)
	glDepthTest(true)

	if debugTiming then
		local dt = osClock() - tVis0
		timingAccum.drawPreUnit = timingAccum.drawPreUnit + dt
		if dt > timingAccum.maxDrawPreUnit then timingAccum.maxDrawPreUnit = dt end
	end

	-- Periodic timing report
	timingCount = timingCount + 1
	if debugTiming and timingCount >= timingInterval then
		local div = timingCount
		Spring.Echo(string.format(
			"[ReclaimField TIMING] avg(ms): UpdReclaim=%.3f DrawText=%.3f DrawPre=%.3f Update=%.3f DefPend=%.3f Poll=%.3f Slice=%.3f Final=%.3f Redraw=%.3f | max(ms): Upd=%.2f DrawPre=%.2f Slice=%.2f Final=%.2f Redraw=%.2f | DL/frame=%.1f clusters=%d features=%d pendC=%d pendD=%d defC=%d defD=%d job=%s lastJob=%.2fms reuse=%d/%d partial=%d/%d copiedE=%d",
			timingAccum.updateReclaim / div * 1000,
			timingAccum.drawWorldText / div * 1000,
			timingAccum.drawPreUnit / div * 1000,
			timingAccum.updateFunc / div * 1000,
			timingAccum.deferPending / div * 1000,
			timingAccum.reclaimPoll / div * 1000,
			timingAccum.clusterSlice / div * 1000,
			timingAccum.clusterFinalize / div * 1000,
			timingAccum.redrawLists / div * 1000,
			timingAccum.maxUpdateReclaim * 1000,
			timingAccum.maxDrawPreUnit * 1000,
			timingAccum.maxClusterSlice * 1000,
			timingAccum.maxClusterFinalize * 1000,
			timingAccum.maxRedrawLists * 1000,
			timingAccum.rebuilds / div,
			#featureClusters,
			cachedKnownFeaturesCount,
			batch.pendCreateCount - batch.pendCreateHead,
			batch.pendDestrCount - batch.pendDestrHead,
			batch.deferCreateCount,
			batch.deferDestrCount,
			batch.clusterJobActive and "1" or "0",
			batch.lastClusterJobCpu * 1000,
			batch.reusedMetalHulls,
			batch.reusedEnergyHulls,
			batch.partialReusedMetalHulls,
			batch.partialReusedEnergyHulls,
			batch.copiedEnergyHulls
		))
		timingAccum.updateReclaim = 0
		timingAccum.drawWorldText = 0
		timingAccum.drawPreUnit = 0
		timingAccum.updateFunc = 0
		timingAccum.rebuilds = 0
		timingAccum.deferPending = 0
		timingAccum.reclaimPoll = 0
		timingAccum.clusterSlice = 0
		timingAccum.clusterFinalize = 0
		timingAccum.redrawLists = 0
		timingAccum.maxUpdateReclaim = 0
		timingAccum.maxDrawPreUnit = 0
		timingAccum.maxClusterSlice = 0
		timingAccum.maxClusterFinalize = 0
		timingAccum.maxRedrawLists = 0
		timingCount = 0
	end
end
