local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Reclaim Field Highlight",
		desc = "Highlights clusters of reclaimable material",
		author = "ivand, refactored by esainane, edited for BAR by Lexon, efrec and Floris",
		date = "2024",
		license = "public",
		layer = 1270000,
		enabled = true,
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
local numberColor = { 0.9, 0.9, 0.9, 1 }
local energyNumberColor = { 0.95, 0.9, 0, 1 }
local fontSizeMin = 30
local fontSizeMax = 110

--Field color
local reclaimColor = { 0, 0, 0, 0.16 }
local reclaimEdgeColor = { 1, 1, 1, 0.18 }

--Energy field color (yellowish tint)
local energyReclaimColor = { 0.8, 0.8, 0, 0.16 }
local energyReclaimEdgeColor = { 1, 1, 0, 0.18 }

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
	-- Alpha delta beyond which we recreate the gradient display list
	rebuildThreshold = 0.06,
	-- Minimum relative change in cluster resource value to trigger a pulse
	-- animation. Smaller changes (e.g. a single small wreck added/removed from
	-- a large field) are ignored so the field only pulses on meaningful changes.
	pulseMinRelativeChange = 0.12,
}

local gameStarted = SpringShared.GetGameFrame() > 0
local lastCheckFrame = SpringShared.GetGameFrame() - 999
local lastCheckFrameClock = os.clock() - 99
local lastProcessedFrame = -1
local vsx, vsy = SpringUnsynced.GetViewGeometry()

--------------------------------------------------------------------------------
-- Speedups
--------------------------------------------------------------------------------

local tableSort = table.sort

local insert = table.insert
local remove = table.remove

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

local spGetCameraPosition = SpringUnsynced.GetCameraPosition
local spGetFeaturePosition = SpringShared.GetFeaturePosition
local spGetFeatureResources = SpringShared.GetFeatureResources
local spGetFeatureVelocity = SpringShared.GetFeatureVelocity
local spGetFeatureRadius = SpringShared.GetFeatureRadius
local spValidFeatureID = SpringShared.ValidFeatureID
local spGetGroundHeight = SpringShared.GetGroundHeight
local spIsGUIHidden = SpringUnsynced.IsGUIHidden
local spTraceScreenRay = SpringUnsynced.TraceScreenRay
local spGetActiveCommand = SpringUnsynced.GetActiveCommand
local spGetMapDrawMode = SpringUnsynced.GetMapDrawMode
local spGetUnitDefID = SpringShared.GetUnitDefID
local spGetCameraVectors = SpringUnsynced.GetCameraVectors
local spGetGameFrame = SpringShared.GetGameFrame

-- TIMING INSTRUMENTATION (set to true to enable periodic timing echo)
local debugTiming = false
local osClock = os.clock
local timingAccum = {
	updateReclaim = 0,
	drawWorldText = 0,
	drawPreUnit = 0,
	updateFunc = 0,
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

-- Text display list caching - tracks last camera facing angle for text rotation
local minTextUpdateIntervalFrames = 15 -- Minimum frames between text display list recreations per cluster (~0.5s at 30fps)
local immediateFadeChangeThreshold = 0.05 -- Small fade changes above this should update immediately for responsiveness

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
		local moved = (dx * dx + dy * dy + dz * dz) > cameraMovementThreshold * cameraMovementThreshold

		-- Check if camera has rotated significantly (dot product change)
		local oldDot = cachedCamFwdX * newCamForward[1] + cachedCamFwdY * newCamForward[2] + cachedCamFwdZ * newCamForward[3]
		local rotated = oldDot < (1 - cameraRotationThreshold)

		-- Increment cache generation if camera moved or rotated
		if moved or rotated then
			cameraGeneration = cameraGeneration + 1
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
	local distSq = dx * dx + dy * dy + dz * dz
	local dist = sqrt(distSq)

	-- Skip if too far away (beyond fade distance + radius) - early out
	if dist > fadeEndDistance + radius then
		return false, dist
	end

	-- Normalize direction vector
	if dist < 0.01 then
		return true, dist
	end -- Camera is at the point
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
	regions = {}, -- Track which regions need reclustering
	clusters = {}, -- Track which specific clusters need redrawing
	energyClusters = {}, -- Track which specific energy clusters need redrawing
	useRegional = true, -- Enable regional optimization
}

-- Batch queues and deferred update state (consolidated)
local batch = {
	toRemove = {}, -- Reusable table for batching feature removals
	pendDestructions = {}, -- Queue for batching FeatureDestroyed calls
	pendDestrCount = 0, -- Count of pending destructions
	pendCreations = {}, -- Queue for batching FeatureCreated calls
	pendCreateCount = 0, -- Count of pending creations
	affectedFeatures = {}, -- Reusable table for regional clustering
	affectedClusters = {}, -- Reusable table for regional clustering
	deferCreations = {}, -- Features created outside view
	deferDestructions = {}, -- Features destroyed outside view
	deferCreateCount = 0,
	deferDestrCount = 0,
	deferOutOfView = true, -- Config: defer processing features outside view
	outOfViewMargin = 350, -- Elmos margin beyond fade distance to still process immediately
	lastDeferFrame = 0,
	deferInterval = 60, -- Process deferred updates every 60 frames (~2 seconds)
}

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

local epsilonSq = epsilon * epsilon
local checkFrequency = 30
local lastFeatureCount = 0
local cachedKnownFeaturesCount = 0 -- Cached count to avoid iterating all features

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
	clusterAnims = {}, -- metal, [uid] = state
	energyClusterAnims = {}, -- energy, [uid] = state

	-- Snapshot of clusters from the previous clustering pass (for identity match)
	prevSnapshot = {}, -- metal, [uid] = {fids, fidCount}
	prevEnergySnapshot = {}, -- energy

	-- Clusters that disappeared and are currently fading out. They own their
	-- own hull copies and display lists.
	fading = {}, -- metal, [uid] = entry
	fadingEnergy = {}, -- energy

	-- Group toggle fade (fields turning on/off as a whole). 0..1
	toggleMetal = 0,
	toggleMetalTarget = 0,
	toggleEnergy = 0,
	toggleEnergyTarget = 0,

	lastTickClock = os.clock(),

	-- Pre-clustering snapshot of hulls (deep-copied) so we can render fadeout
	-- for clusters that disappear after the next clustering pass.
	preHullCopies = {}, -- metal, [uid] = {hull, center, text, font, textX, textZ, alpha, isEnergy}
	preEnergyHullCopies = {}, -- energy

	-- Forward-declared functions (filled in below). Stored on the table to
	-- avoid creating extra upvalues in the chunk.
	CapturePreClusteringSnapshot = nil,
	SyncClusterIdentitiesAfterClustering = nil,
	TickClusterAnimations = nil,
	DeleteFadingCluster = nil,
	GetClusterAnimAlphaAndScale = nil,
	CreateFadingClusterDisplayList = nil,
	CreateFadingClusterTextDisplayList = nil,
}

-- Helper function to compute a simple hash/signature of cluster state
local function ComputeClusterStateHash(cluster, hull)
	if not cluster or not hull then
		return 0
	end
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
	if t <= 0 then
		return 0
	end
	if t >= 1 then
		return 1
	end
	return t * t * (3 - 2 * t)
end

-- Pulse curve: 0 -> 1 -> 0 over [0,1] (peak at 0.5). Smooth.
local function pulseCurve(t)
	if t <= 0 or t >= 1 then
		return 0
	end
	-- sin(pi * t) gives a nice 0->1->0 hump
	return sin(t * 3.14159265)
end

-- Forward declarations referenced inside hooks below
-- (Stored on animState to avoid eating top-level upvalue slots.)

-- Reusable scratch table for syncSide() overlap tallies (cleared per cluster).
local sharedTally = {}

-- Build a {fid=true,...} set from a cluster's members
local function BuildFidSet(members)
	local set, count = {}, 0
	if members then
		for i = 1, #members do
			local m = members[i]
			if m and m.fid then
				set[m.fid] = true
				count = count + 1
			end
		end
	end
	return set, count
end

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

	-- Build fid->oldUid index for fast matching
	local fidToOldUid = {}
	for oldUid, snap in pairs(snapshot) do
		for fid in pairs(snap.fids) do
			fidToOldUid[fid] = oldUid
		end
	end

	local now = os.clock()
	local matchedOldUids = {}

	for cid = 1, #clusters do
		local cluster = clusters[cid]
		-- Skip "split parent" placeholders (font==0 indicates a cluster that was
		-- split into sub-clusters; only the children carry visible geometry).
		if cluster and (cluster.font ~= 0) and cluster.members then
			local fids, count = BuildFidSet(cluster.members)
			-- Tally overlap with each old uid (reuse a single table across
			-- iterations to avoid one tally allocation per cluster).
			local bestOldUid, bestOverlap = nil, 0
			local tally = sharedTally
			for k in pairs(tally) do
				tally[k] = nil
			end
			for fid in pairs(fids) do
				local oldUid = fidToOldUid[fid]
				if oldUid and not matchedOldUids[oldUid] then
					tally[oldUid] = (tally[oldUid] or 0) + 1
				end
			end
			for oldUid, overlap in pairs(tally) do
				if overlap > bestOverlap then
					bestOverlap = overlap
					bestOldUid = oldUid
				end
			end

			local uid
			local pulseDir = 0 -- -1 shrink, +1 expand, 0 no pulse
			if bestOldUid then
				local oldSnap = snapshot[bestOldUid]
				local oldCount = oldSnap.fidCount
				local maxCount = oldCount
				if count > maxCount then
					maxCount = count
				end
				if maxCount > 0 and (bestOverlap / maxCount) >= animCfg.identityMinOverlap then
					uid = bestOldUid
					matchedOldUids[bestOldUid] = true
					-- Pulse only on meaningful resource change. Compare new vs
					-- old cluster value (metal or energy depending on side).
					local newValue = (isEnergy and cluster.energy or cluster.metal) or 0
					local oldValue = oldSnap.value or 0
					local denom = oldValue
					if newValue > denom then
						denom = newValue
					end
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
			newSnapshot[uid] = {
				fids = fids,
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
			if entry.t0 then
				entry.t0 = entry.t0 - entry.duration
			end
		end
	end
end

-- Delete display lists belonging to a fading cluster entry
animState.DeleteFadingCluster = function(uid, isEnergy)
	local fading = isEnergy and animState.fadingEnergy or animState.fading
	local entry = fading[uid]
	if not entry then
		return
	end
	if entry.displayLists then
		if entry.displayLists.gradient then
			glDeleteList(entry.displayLists.gradient)
		end
		if entry.displayLists.edge then
			glDeleteList(entry.displayLists.edge)
		end
		if entry.displayLists.text then
			glDeleteList(entry.displayLists.text)
		end
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
			if not a.alpha or a.alpha < 1 then
				a.alpha = 1
			end
			if not a.scale or a.scale ~= 1 then
				a.scale = 1
			end
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
				if vis > target then
					vis = target
				end
			else
				vis = vis - visOutStep
				if vis < target then
					vis = target
				end
			end
			a.vis = vis
		end
	end
end

-- Tick all animations. Called once per draw.
animState.TickClusterAnimations = function(now)
	local dt = now - animState.lastTickClock
	if dt <= 0 then
		return
	end
	animState.lastTickClock = now
	local toggleStep = dt / animCfg.toggleFadeDuration

	-- Toggle fades (metal/energy group)
	if animState.toggleMetal ~= animState.toggleMetalTarget then
		if animState.toggleMetal < animState.toggleMetalTarget then
			animState.toggleMetal = animState.toggleMetal + toggleStep
			if animState.toggleMetal > animState.toggleMetalTarget then
				animState.toggleMetal = animState.toggleMetalTarget
			end
		else
			animState.toggleMetal = animState.toggleMetal - toggleStep
			if animState.toggleMetal < animState.toggleMetalTarget then
				animState.toggleMetal = animState.toggleMetalTarget
			end
		end
	end
	if animState.toggleEnergy ~= animState.toggleEnergyTarget then
		if animState.toggleEnergy < animState.toggleEnergyTarget then
			animState.toggleEnergy = animState.toggleEnergy + toggleStep
			if animState.toggleEnergy > animState.toggleEnergyTarget then
				animState.toggleEnergy = animState.toggleEnergyTarget
			end
		else
			animState.toggleEnergy = animState.toggleEnergy - toggleStep
			if animState.toggleEnergy < animState.toggleEnergyTarget then
				animState.toggleEnergy = animState.toggleEnergyTarget
			end
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

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Priority Queue

local PriorityQueue = {}
do
	local function push(self, priority, value)
		local n = self.size + 1
		self.size = n
		local pris = self.priorities
		local vals = self.values
		pris[n] = priority
		vals[n] = value
		local p = floor(n * 0.5)
		while n > 1 and pris[n] < pris[p] do
			pris[n], pris[p] = pris[p], pris[n]
			vals[n], vals[p] = vals[p], vals[n]
			n = p
			p = floor(n * 0.5)
		end
	end

	local function pop(self)
		local size = self.size
		if size == 0 then
			return nil
		end
		local pris = self.priorities
		local vals = self.values
		local value = vals[1]
		if size == 1 then
			pris[1] = nil
			vals[1] = nil
			self.size = 0
			return value
		end
		pris[1] = pris[size]
		vals[1] = vals[size]
		pris[size] = nil
		vals[size] = nil
		size = size - 1
		self.size = size
		local root = 1
		local child = 2
		while child <= size do
			if child + 1 <= size and pris[child + 1] < pris[child] then
				child = child + 1
			end
			if pris[root] <= pris[child] then
				break
			end
			pris[root], pris[child] = pris[child], pris[root]
			vals[root], vals[child] = vals[child], vals[root]
			root = child
			child = 2 * root
		end
		return value
	end

	local function clear(self)
		local pris = self.priorities
		local vals = self.values
		for i = 1, self.size do
			pris[i] = nil
			vals[i] = nil
		end
		self.size = 0
	end

	local pqMeta = {
		__index = {
			push = push,
			pop = pop,
			clear = clear,
		},
	}

	function PriorityQueue.new()
		return setmetatable({ priorities = {}, values = {}, size = 0 }, pqMeta)
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
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
		cluster.radius = sqrt(cdx * cdx + cdz * cdz) * 0.5
	end

	-- For metal fields with alwaysShowFields enabled, bypass distance culling if above threshold
	local inView, dist
	local meetsThreshold = not isEnergy and cluster.metal and cluster.metal >= alwaysShowFieldsThreshold
	if alwaysShowFields and not isEnergy and meetsThreshold then
		-- Always in view for metal fields when option is enabled and above threshold
		local dx = center.x - cachedCameraX
		local dy = center.y - cachedCameraY
		local dz = center.z - cachedCameraZ
		dist = sqrt(dx * dx + dy * dy + dz * dz)
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
			fadeMult = fadeMult,
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
do
	local function getReclaimTotal(cluster, points, resourceType)
		local total = 0
		for j = 1, #points do
			total = total + points[j][resourceType]
		end
		cluster[resourceType] = total
		cluster.text = string.formatSI(total)
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

	---Filter a set of points to give a much smaller set of candidates for constructing
	---the convex hull of the entire set. This can save time on building the hull.
	---Credit: mindthenerd.blogspot.ru/2012/05/fastest-convex-hull-algorithm-ever.html
	---Also: www-cgrl.cs.mcgill.ca/~godfried/publications/fast.convex.hull.algorithm.pdf
	local function convexSetConditioning(points)
		-- tableSort(points, sortMonotonic) -- Moved to previous, shared step.
		local remaining = { points[1] }
		local x, z = points[1].x, points[1].z

		-- (1) Cover all points by expanding a quadrilateral to follow these rules:
		local ax, az, a_xzs_max = x, z, x - z -- Choose point A to maximize x - z.
		local bx, bz, b_xza_max = x, z, x + z -- Choose point B to maximize x + z.
		local cx, cz, c_xzs_min = x, z, x - z -- Choose point C to minimize x - z.
		local dx, dz, d_xza_min = x, z, x + z -- Choose point D to minimize x + z.

		-- (2) Find the XZ-aligned rectangle inscribed in that quadrilateral:
		local rxmin, rxmax = x, x -- Rx_min = max(Cx, Dx); Rx_max = min(Ax, Bx).
		local rzmin, rzmax = z, z -- Rz_min = max(Az, Dz); Rz_max = min(Bz, Cz).

		-- (3) The algorithm performs two passes, with the first covering the full set.
		for ii = 2, #points do
			local point = points[ii]
			local x, z = point.x, point.z
			if x <= rxmin or x >= rxmax or z <= rzmin or z >= rzmax then
				-- Keep points that fall outside the inscribed rectangle.
				remaining[#remaining + 1] = point

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
			return (q.z - p.z) * (r.x - q.x) - (q.x - p.x) * (r.z - q.z)
		end

		MonotoneChain = function(points)
			local numPoints = #points
			if numPoints < 3 then
				return
			end
			-- tableSort(points, sortMonotonic) -- Moved to previous, shared step.

			local lower = {}
			for i = 1, numPoints do
				local point = points[i]
				while #lower >= 2 and cross(lower[#lower - 1], lower[#lower], point) <= 0 do
					remove(lower)
				end
				insert(lower, point)
			end

			local upper = {}
			for i = numPoints, 1, -1 do
				local point = points[i]
				while #upper >= 2 and cross(upper[#upper - 1], upper[#upper], point) <= 0 do
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
		return { x = x, y = y, z = z }
	end

	recycleHull = function(hull)
		if not hull then
			return
		end
		for i = 1, #hull do
			local pt = hull[i]
			if pt and not pt.fid then
				pointPoolTop = pointPoolTop + 1
				pointPool[pointPoolTop] = pt
			end
			hull[i] = nil
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
				convexHull[i + 1] = acquirePoint(x, max(0, spGetGroundHeight(x, z)), z)
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
					acquirePoint(x4, max(0, spGetGroundHeight(x4, z4)), z4),
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
					acquirePoint(xmin, max(0, spGetGroundHeight(xmin, zmax)), zmax),
				}
			end
		end

		local hullArea = cluster.dx * cluster.dz

		return convexHull, hullArea
	end

	local function polygonArea(points)
		if #points < 3 then
			return 0
		end
		local totalArea = 0
		for ii = 1, #points - 1 do
			totalArea = totalArea + points[ii].x * points[ii + 1].z - points[ii].z * points[ii + 1].x
		end
		return 0.5 * abs(totalArea + points[#points].x * points[1].z - points[#points].z * points[1].x)
	end

	-- Reusable buffers for hull processing (reduces GC pressure)
	local subdividedBuf = {}
	local subdividedBufLen = 0
	local expandedBuf = {}

	-- Subdivide long edges in hull to ensure smooth expansion
	local function subdivideHull(hull, maxEdgeLength)
		if not hull or #hull < 3 then
			return hull
		end

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
				subdividedBuf[count] = { x = curr.x, y = curr.y, z = curr.z }
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
							z = interpZ,
						}
					end
				end
			end
		end

		-- Clear excess entries from previous larger use
		for i = count + 1, subdividedBufLen do
			subdividedBuf[i] = nil
		end
		subdividedBufLen = count

		return subdividedBuf
	end

	-- Expand hull outward by a margin and create rounded corners with Catmull-Rom smoothing
	local function expandAndSmoothHull(hull, expandDist)
		if not hull or #hull < 3 then
			return hull
		end

		-- Subdivide long edges first to ensure smooth, even expansion
		-- Use expandDist as guide for max edge length (want multiple points per expansion distance)
		local maxEdgeLength = max(expandDist * 1.5, 80) -- At least one subdivision per ~expansion distance
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

		-- First pass: expand all vertices outward using a blend of radial and normal-based expansion
		for i = 1, n do
			local prev = hull[i == 1 and n or i - 1]
			local curr = hull[i]
			local next = hull[i == n and 1 or i + 1]

			-- Calculate edge vectors
			local dx1, dz1 = curr.x - prev.x, curr.z - prev.z
			local len1 = sqrt(dx1 * dx1 + dz1 * dz1)
			if len1 > 0 then
				dx1, dz1 = dx1 / len1, dz1 / len1
			end

			local dx2, dz2 = next.x - curr.x, next.z - curr.z
			local len2 = sqrt(dx2 * dx2 + dz2 * dz2)
			if len2 > 0 then
				dx2, dz2 = dx2 / len2, dz2 / len2
			end

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
			local blendWeight = 0.7 -- 70% radial, 30% normal-based
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
			expandFactor = clamp(expandFactor, 1.0, 2.0) -- Tighter range for more uniformity

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
					z = newZ,
				}
			end
		end

		-- If smoothing disabled, copy from buffer (can't return shared buffer)
		if smoothingSegments <= 0 then
			local result = {}
			for i = 1, n do
				local e = expandedBuf[i]
				result[i] = acquirePoint(e.x, e.y, e.z)
			end
			return result
		end

		-- Second pass: Apply Catmull-Rom spline interpolation for smooth curves
		local smoothed = {}
		-- Boost smoothing when zoomed in (at no extra cost since we're already rebuilding)
		local zoomBonus = cameraScale <= 1.5 and 2 or (cameraScale <= 2.5 and 1 or 0)
		local segmentsPerEdge = smoothingSegments + zoomBonus

		for i = 1, n do
			local p0 = expandedBuf[i == 1 and n or i - 1]
			local p1 = expandedBuf[i]
			local p2 = expandedBuf[i == n and 1 or i + 1]
			local p3 = expandedBuf[(i + 1) % n + 1]

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

				smoothed[#smoothed + 1] = acquirePoint(newX, newY, newZ)
			end
		end

		return smoothed
	end

	-- Split a large cluster into smaller sub-clusters using spatial subdivision
	local function splitLargeCluster(points, clusterWidth, clusterDepth)
		-- Calculate how many subdivisions we need
		local xDivisions = math.ceil(clusterWidth / maxClusterSize)
		local zDivisions = math.ceil(clusterDepth / maxClusterSize)

		-- If no splitting needed, return nil
		if xDivisions <= 1 and zDivisions <= 1 then
			return nil
		end

		-- Find bounds of all points
		local xmin, xmax, zmin, zmax = mathHuge, -mathHuge, mathHuge, -mathHuge
		for i = 1, #points do
			local x, z = points[i].x, points[i].z
			xmin = min(xmin, x)
			xmax = max(xmax, x)
			zmin = min(zmin, z)
			zmax = max(zmax, z)
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
		end

		return subClusters
	end

	processCluster = function(cluster, clusterID, points, resourceType, targetHulls, targetClusters, nextClusterId)
		getReclaimTotal(cluster, points, resourceType or "metal")

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

			-- Check if cluster is too large and needs splitting
			if targetClusters and nextClusterId and (cluster.width > maxClusterSize or cluster.depth > maxClusterSize) then
				-- Split this cluster into sub-clusters
				local subClusters = splitLargeCluster(points, cluster.width, cluster.depth)
				if subClusters then
					-- Process each sub-cluster and collect them
					local newClusters = {}
					local subClusterIndex = nextClusterId
					for _, subPoints in pairs(subClusters) do
						if #subPoints >= 3 then -- Only process sub-clusters with enough points
							local subCluster = {}
							subCluster.members = subPoints
							processCluster(subCluster, subClusterIndex, subPoints, resourceType, targetHulls, nil, nil)
							table.insert(newClusters, subCluster)
							subClusterIndex = subClusterIndex + 1
						end
					end
					-- Return sub-clusters to be added to main array
					if #newClusters > 0 then
						-- Don't create hull for original cluster
						targetHulls[clusterID] = nil
						cluster.font = 0 -- Hide text for split cluster
						return newClusters
					end
				end
			end
		else
			hullArea = 0
			getClusterDimensions(cluster, points)
		end

		-- Replace lines and sets of one or two with a bounding box.
		if hullArea < areaTextMin then
			local boundingConvex, boundingArea = BoundingBox(cluster, points)
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
					acquirePoint(xmin, max(0, spGetGroundHeight(xmin, zmax)), zmax),
				}
				hullArea = (xmax - xmin) * (zmax - zmin)
				usedBoundingBox = true
			end
		end

		-- Apply expansion and smoothing to make blob-like shapes
		-- Apply to all cases including BoundingBox for smooth organic shapes
		-- expandDist: how much to expand outward (in elmos)
		if convexHull and #convexHull >= 3 then
			-- Scale expansion with wreck size for proportional fields
			-- Increased expansion values for more encompassing, uniform fields
			local expansion
			if #points == 1 then
				expansion = (maxRadius * 1.5 + 35) * expansionMultiplier -- Expansion for single wrecks
			elseif usedBoundingBox then
				expansion = (maxRadius * 1.5 + 40) * expansionMultiplier -- Expansion for two wrecks
			else
				expansion = (maxRadius * 1.8 + 65) * expansionMultiplier -- Expansion for clusters
			end

			-- Always use the standard expand+smooth method which follows the hull shape
			-- The ellipse approach was too rigid and caused overshooting
			local expandedHull = expandAndSmoothHull(convexHull, expansion)
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
	local currentResourceType -- Track which resource type we're clustering for

	---Get ready for a clustering run
	local function Setup()
		-- Note: featureClusters/featureConvexHulls are set externally
		if not unprocessed then
			unprocessed = {}
		end
		for fid, feature in pairs(knownFeatures) do
			-- Only include features that have this resource type
			if feature[currentResourceType] and feature[currentResourceType] >= minFeatureValue then
				unprocessed[fid] = true
			end
		end
	end

	---Update the priority queue to contain the list of neighbors.
	local function Update(neighbors, point, seedsPQ)
		for fid, distSq in pairs(neighbors) do
			if unprocessed[fid] == true then
				unprocessed[fid] = nil
				local np = knownFeatures[fid]
				seedsPQ:push(np.rd or mathHuge, np)
			end
		end
	end

	---Runs a both simplified and augmented OPTICS sequencing step.
	---This is combined with the previous Clusterize fn step to produce clusters.
	---It also leaves no point un-clusterized; solo points form their own cluster.
	---This has allowed all processing to occur in one place and in a single pass.
	local function Run()
		Setup()

		-- Set the appropriate target tables based on resource type
		local targetClusters, targetHulls
		local cidField
		if currentResourceType == "energy" then
			targetClusters = energyFeatureClusters
			targetHulls = energyFeatureConvexHulls
			cidField = "energyCid"
		else
			targetClusters = featureClusters
			targetHulls = featureConvexHulls
			cidField = "cid"
		end

		local clusterID = #targetClusters
		local seedsPQ = PriorityQueue.new()
		local featureID = next(unprocessed)
		while featureID do
			-- Start a new cluster.
			local point = knownFeatures[featureID]
			local members = { point }
			local cluster = { members = members }
			clusterID = clusterID + 1
			targetClusters[clusterID] = cluster

			-- Process visited points, like so.
			point[cidField] = clusterID
			unprocessed[featureID] = nil

			-- Process immediate neighbors.
			local neighbors = featureNeighborsMatrix[featureID]
			seedsPQ:clear()
			Update(neighbors, point, seedsPQ)

			-- Spread through next-neighbors by moving to the nearest point.
			local pt = seedsPQ:pop()
			while pt do
				members[#members + 1] = pt
				pt[cidField] = clusterID

				local nextNeighbors = featureNeighborsMatrix[pt.fid]
				Update(nextNeighbors, pt, seedsPQ)
				pt = seedsPQ:pop()
			end

			featureID = next(unprocessed)
		end

		-- Post-process each cluster.
		local nextClusterId = clusterID + 1 -- Track next available cluster ID for splits
		for cid = 1, clusterID do
			local cluster = targetClusters[cid]
			local newClusters = processCluster(cluster, cid, cluster.members, currentResourceType, targetHulls, targetClusters, nextClusterId)
			if newClusters then
				-- Cluster was split - add sub-clusters to arrays
				for i = 1, #newClusters do
					targetClusters[nextClusterId] = newClusters[i]
					nextClusterId = nextClusterId + 1
				end
			end
		end

		-- Store results in the correct global tables
		if currentResourceType == "energy" then
			energyFeatureClusters = targetClusters
			energyFeatureConvexHulls = targetHulls
		else
			featureClusters = targetClusters
			featureConvexHulls = targetHulls
		end
	end

	function Optics.new()
		local object = setmetatable({}, {
			__index = {
				Run = Run,
				SetResourceType = function(self, resourceType)
					currentResourceType = resourceType
				end,
			},
		})
		return object
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Feature Tracking

local function MarkRegionDirty(x, z, radius)
	-- Mark a spatial region as needing reclustering
	if not dirty.useRegional then
		return
	end

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
		dirty.regions[#dirty.regions + 1] = { x = x, z = z, radius = newRadius }
	end
end

local function IsInDirtyRegion(x, z)
	if not dirty.useRegional or #dirty.regions == 0 then
		return true
	end
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
	if not x then
		return
	end

	-- Mark region as dirty for regional reclustering
	MarkRegionDirty(x, z)

	local radius = spGetFeatureRadius(featureID) or 0
	local feature = {
		fid = featureID,
		metal = metal or 0,
		energy = energy or 0,
		x = x,
		y = max(0, y),
		z = z,
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
end

local function RemoveFeature(featureID)
	local feature = knownFeatures[featureID]
	if not feature then
		return
	end

	-- Mark region as dirty for regional reclustering
	MarkRegionDirty(feature.x, feature.z)

	-- Mark metal cluster as dirty for redrawing
	-- Don't delete display list here - it will be recreated in the redrawing section
	if feature.cid then
		dirty.clusters[feature.cid] = true
		dirty.needRedraw = true
	end

	-- Mark energy cluster as dirty for redrawing
	-- Don't delete display list here - it will be recreated in the redrawing section
	if feature.energyCid then
		dirty.energyClusters[feature.energyCid] = true
		dirty.needRedraw = true
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
	local dirtyEnergyCount = 0

	-- Sample rate: check ~10% of features per frame (or all if < 50 features)
	-- Use cached count instead of iterating all features
	local featureCount = cachedKnownFeaturesCount

	-- ALWAYS check all features to ensure data consistency
	-- This prevents stale values from causing incorrect cluster totals
	local checkInterval = 1

	local checkCounter = 0
	local featuresChecked = 0

	-- Determine what needs updating based on visibility
	-- Use cached values to avoid function call overhead
	local needMetalUpdates = drawEnabled
	local needEnergyUpdates = drawEnergyEnabled

	for fid, fInfo in pairs(knownFeatures) do
		-- Check features based on interval
		checkCounter = checkCounter + 1
		if checkCounter % checkInterval == 0 or featureCount <= 500 then
			featuresChecked = featuresChecked + 1
			-- Check this feature this frame
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

	-- Remove in separate loop to avoid iterator issues
	for i = 1, removeCount do
		RemoveFeature(batch.toRemove[i])
	end

	-- Clear reusable table
	for i = 1, removeCount do
		batch.toRemove[i] = nil
	end

	if removed then
		dirty.needCluster = true
	elseif dirtyCount > 0 or dirtyEnergyCount > 0 then
		dirty.needRedraw = true

		-- Update metal cluster text (only if metal fields are visible)
		if needMetalUpdates then
			for cid in pairs(dirty.clusters) do
				local cluster = featureClusters[cid]
				if cluster then
					cluster.text = string.formatSI(cluster.metal)
				end
			end
		end

		-- Update energy cluster text (only if energy fields are visible)
		if needEnergyUpdates then
			for energyCid in pairs(dirty.energyClusters) do
				local energyCluster = energyFeatureClusters[energyCid]
				if energyCluster then
					energyCluster.text = string.formatSI(energyCluster.energy)
				end
			end
		end
	end
end

-- Check if all energy fields have been drained
local function CheckAllEnergyDrained()
	if not showEnergyFields then
		return -- Energy fields disabled
	end

	-- Check if there are any features with energy remaining
	local totalEnergy = 0
	local featuresWithEnergy = 0
	for fid, feature in pairs(knownFeatures) do
		if feature.energy and feature.energy > 0 then
			totalEnergy = totalEnergy + feature.energy
			featuresWithEnergy = featuresWithEnergy + 1
		end
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
	for _, hull in pairs(energyFeatureConvexHulls) do
		recycleHull(hull)
	end
	energyFeatureConvexHulls = {}
end

-- Track text positions to avoid overlaps
local drawnTextPositions = {}
local drawnTextPositionCount = 0

local function WouldTextOverlap(x, z, fontSize)
	local thresholdSq = (fontSize * 1.5) ^ 2
	for i = 1, drawnTextPositionCount do
		local pos = drawnTextPositions[i]
		local dx = x - pos.x
		local dz = z - pos.z
		if dx * dx + dz * dz < thresholdSq then
			return true, pos
		end
	end
	return false, nil
end

-- Pre-computed offset multipliers (avoid table allocation per call)
local overlapOffsetMults = {
	{ 0, 1.5 },
	{ 0, -1.5 },
	{ 1.5, 0 },
	{ -1.5, 0 },
	{ 1.2, 1.2 },
	{ -1.2, 1.2 },
	{ 1.2, -1.2 },
	{ -1.2, -1.2 },
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

local function ClusterizeFeatures()
	if dirty.useRegional and #dirty.regions > 0 then
		-- Regional reclustering: only recluster features in dirty regions
		-- Reuse tables instead of allocating new ones
		local affectedCount = 0
		local clusterCount = 0
		local energyClusterCount = 0

		-- Find all features in dirty regions
		for fid, feature in pairs(knownFeatures) do
			if IsInDirtyRegion(feature.x, feature.z) then
				affectedCount = affectedCount + 1
				batch.affectedFeatures[affectedCount] = fid
				if feature.cid then
					local cid = feature.cid
					if not batch.affectedClusters[cid] then
						clusterCount = clusterCount + 1
						batch.affectedClusters[cid] = true
					end
				end
				if feature.energyCid then
					local cid = feature.energyCid
					if not batch.affectedClusters[cid] then
						energyClusterCount = energyClusterCount + 1
						batch.affectedClusters[cid] = true
					end
				end
			end
		end

		-- If too many features affected, fall back to full reclustering
		if affectedCount > 200 then -- Threshold for full recluster
			-- Clear reusable tables
			for i = 1, affectedCount do
				batch.affectedFeatures[i] = nil
			end
			for cid in pairs(batch.affectedClusters) do
				batch.affectedClusters[cid] = nil
			end

			-- Fall through to full clustering
			dirty.useRegional = false

			-- Cluster metal
			featureClusters = {}
			for _, hull in pairs(featureConvexHulls) do
				recycleHull(hull)
			end
			featureConvexHulls = {}
			opticsObject:SetResourceType("metal")
			opticsObject:Run()

			-- Always cluster energy fields when clustering is needed
			if showEnergyFields then
				energyFeatureClusters = {}
				for _, hull in pairs(energyFeatureConvexHulls) do
					recycleHull(hull)
				end
				energyFeatureConvexHulls = {}
				opticsObject:SetResourceType("energy")
				opticsObject:Run()
			end

			dirty.useRegional = true
			-- Clear dirty regions array
			for i = 1, #dirty.regions do
				dirty.regions[i] = nil
			end
			-- Clear dirty clusters table
			for cid in pairs(dirty.clusters) do
				dirty.clusters[cid] = nil
			end
			for cid in pairs(dirty.energyClusters) do
				dirty.energyClusters[cid] = nil
			end
			dirty.needCluster = false
			dirty.needRedraw = true
			return
		end

		-- Remove affected clusters and reset cluster IDs for affected features
		-- Remove affected METAL clusters (batch.affectedClusters contains metal cluster IDs only)
		for cid in pairs(batch.affectedClusters) do
			featureClusters[cid] = nil
			recycleHull(featureConvexHulls[cid])
			featureConvexHulls[cid] = nil
			batch.affectedClusters[cid] = nil -- Clear as we go
		end

		-- Reset cluster IDs for affected features
		for i = 1, affectedCount do
			local fid = batch.affectedFeatures[i]
			local feature = knownFeatures[fid]
			if feature then
				feature.cid = nil
				-- Also reset energy cluster IDs
				if feature.energyCid and energyFeatureClusters[feature.energyCid] then
					energyFeatureClusters[feature.energyCid] = nil
					recycleHull(energyFeatureConvexHulls[feature.energyCid])
					energyFeatureConvexHulls[feature.energyCid] = nil
				end
				feature.energyCid = nil
			end
			batch.affectedFeatures[i] = nil -- Clear as we go
		end

		-- Re-run clustering (it will create new cluster IDs)
		featureClusters = {}
		for _, hull in pairs(featureConvexHulls) do
			recycleHull(hull)
		end
		featureConvexHulls = {}
		opticsObject:SetResourceType("metal")
		opticsObject:Run()

		-- Always cluster energy fields when clustering is needed
		if showEnergyFields then
			energyFeatureClusters = {}
			for _, hull in pairs(energyFeatureConvexHulls) do
				recycleHull(hull)
			end
			energyFeatureConvexHulls = {}
			opticsObject:SetResourceType("energy")
			opticsObject:Run()
		end

		-- Clear dirty regions array
		for i = 1, #dirty.regions do
			dirty.regions[i] = nil
		end
		-- Clear dirty clusters table
		for cid in pairs(dirty.clusters) do
			dirty.clusters[cid] = nil
		end
		for cid in pairs(dirty.energyClusters) do
			dirty.energyClusters[cid] = nil
		end
	else
		-- Full reclustering
		featureClusters = {}
		for _, hull in pairs(featureConvexHulls) do
			recycleHull(hull)
		end
		featureConvexHulls = {}
		opticsObject:SetResourceType("metal")
		opticsObject:Run()

		-- Always cluster energy fields when clustering is needed
		if showEnergyFields then
			energyFeatureClusters = {}
			for _, hull in pairs(energyFeatureConvexHulls) do
				recycleHull(hull)
			end
			energyFeatureConvexHulls = {}
			opticsObject:SetResourceType("energy")
			opticsObject:Run()
		end

		-- Clear dirty regions array
		for i = 1, #dirty.regions do
			dirty.regions[i] = nil
		end
		-- Clear dirty clusters table
		for cid in pairs(dirty.clusters) do
			dirty.clusters[cid] = nil
		end
		for cid in pairs(dirty.energyClusters) do
			dirty.energyClusters[cid] = nil
		end
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
		CheckAllEnergyDrained()
	end

	-- Pre-compute overlap-adjusted text positions for all clusters
	drawnTextPositionCount = 0
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
			drawnTextPositionCount = drawnTextPositionCount + 1
			local posEntry = drawnTextPositions[drawnTextPositionCount]
			if posEntry then
				posEntry.x = textX
				posEntry.z = textZ
				posEntry.fontSize = fontSize
			else
				drawnTextPositions[drawnTextPositionCount] = { x = textX, z = textZ, fontSize = fontSize }
			end
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
				drawnTextPositionCount = drawnTextPositionCount + 1
				local posEntry = drawnTextPositions[drawnTextPositionCount]
				if posEntry then
					posEntry.x = textX
					posEntry.z = textZ
					posEntry.fontSize = fontSize
				else
					drawnTextPositions[drawnTextPositionCount] = { x = textX, z = textZ, fontSize = fontSize }
				end
			end
		end
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

local UpdateDrawEnabled -- Uses the showOption setting to pick a function call.
do
	local function always()
		return true
	end

	local function onMapDrawMode()
		-- todo: would be nice to set only when it changes
		-- todo: eg widget:MapDrawModeChanged(newMode, oldMode)
		return actionActive == true or spGetMapDrawMode() == "metal"
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
			return (cmdName and cmdName == "Reclaim")
		end
	end

	local showOptionFunctions = {
		--[[1]]
		always,
		--[[2]]
		onMapDrawMode,
		--[[3]]
		onSelectReclaimer,
		--[[4]]
		onSelectResurrector,
		--[[5]]
		onActiveCommand,
		--[[6]]
		widgetHandler.RemoveWidget,
	}

	UpdateDrawEnabled = function()
		local previousDrawEnabled = drawEnabled
		-- Before game starts, always enable drawing regardless of user settings
		if not gameStarted then
			drawEnabled = true
		else
			drawEnabled = showOptionFunctions[showOption]()
		end
		-- If visibility changed from false to true, force a full display list recreation
		if not previousDrawEnabled and drawEnabled then
			dirty.needCluster = true
			dirty.needRedraw = true
			dirty.forceFullRedraw = true
		end
		-- Track the toggle fade target so the group fades smoothly in/out.
		animState.toggleMetalTarget = drawEnabled and 1 or 0
		return drawEnabled
	end
end

local UpdateDrawEnergyEnabled -- Similar to UpdateDrawEnabled but for energy fields
do
	local function always()
		return true
	end

	local function onMapDrawMode()
		return actionActive == true or spGetMapDrawMode() == "metal"
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
			return (cmdName and cmdName == "Reclaim")
		end
	end

	local showEnergyOptionFunctions = {
		--[[1]]
		always,
		--[[2]]
		onMapDrawMode,
		--[[3]]
		onSelectReclaimer,
		--[[4]]
		onSelectResurrector,
		--[[5]]
		onActiveCommand,
		--[[6]]
		function()
			return false
		end, -- disabled
	}

	UpdateDrawEnergyEnabled = function()
		local previousDrawEnergyEnabled = drawEnergyEnabled
		if not showEnergyFields then
			drawEnergyEnabled = false
			animState.toggleEnergyTarget = 0
			return false
		end
		drawEnergyEnabled = showEnergyOptionFunctions[showEnergyOption]()
		-- If visibility changed from false to true, force a full display list recreation
		if not previousDrawEnergyEnabled and drawEnergyEnabled then
			dirty.needCluster = true
			dirty.needRedraw = true
			dirty.forceFullRedraw = true
		end
		animState.toggleEnergyTarget = drawEnergyEnabled and 1 or 0
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

-- Pre-allocated energy colors table to avoid per-DL-creation allocation
local energyGradientColors = {
	fill = energyReclaimColor,
	fillAlpha = fillAlpha * energyOpacityMultiplier,
	gradientAlpha = gradientAlpha * energyOpacityMultiplier,
}

-- Reusable buffer for DrawHullVerticesGradient inner points
local innerPointsBuf = {}

-- Draw gradient fill from center (transparent) to configurable radius (gradientAlpha)
-- Also fills the inner area with fillAlpha
local function DrawHullVerticesGradient(hull, center, colors)
	local hullCount = #hull
	if hullCount < 3 then
		return
	end

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
				z = cz + dz * innerRadius,
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
			-- Preserve text; keep the table entry so CreateClusterTextDisplayList can reuse it
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
	if alphaMult < 0 then
		alphaMult = 0
	end
	if alphaMult > 1 then
		alphaMult = 1
	end

	-- Compute new state hash; include quantized alpha so fade rebuilds the list
	local newHash = ComputeClusterStateHash(cluster, hull)
	-- Quantize alpha to ~16 buckets so we don't rebuild every tiny change
	newHash = newHash + floor(alphaMult * 16 + 0.5) * 0.0001
	local oldHash = stateHashes[cid]

	-- Only recreate if state actually changed
	if oldHash and oldHash == newHash then
		return -- No change, keep existing display list
	end

	-- Prepare clusterData table; if it exists preserve text (we'll recreate geometry only)
	local clusterData = displayLists[cid]
	if not clusterData then
		clusterData = {}
		displayLists[cid] = clusterData
	else
		-- Remove existing geometry lists but preserve text
		if clusterData.gradient then
			glDeleteList(clusterData.gradient)
			clusterData.gradient = nil
		end
		if clusterData.edge then
			glDeleteList(clusterData.edge)
			clusterData.edge = nil
		end
	end

	-- Build a colors table with alpha baked in
	local colorsTbl
	if isEnergy then
		colorsTbl = {
			fill = energyReclaimColor,
			fillAlpha = fillAlpha * energyOpacityMultiplier * alphaMult,
			gradientAlpha = gradientAlpha * energyOpacityMultiplier * alphaMult,
		}
	else
		colorsTbl = {
			fill = reclaimColor,
			fillAlpha = fillAlpha * alphaMult,
			gradientAlpha = gradientAlpha * alphaMult,
		}
	end

	-- Capture immutable values into locals so the display list closure doesn't
	-- pick up later mutations of the shared colorsTbl.
	local capturedFillAlpha = colorsTbl.fillAlpha
	local capturedGradientAlpha = colorsTbl.gradientAlpha
	local capturedFill = colorsTbl.fill
	-- We allocate a per-list colors table to avoid the shared table being
	-- mutated before the list is actually executed.
	local listColors = {
		fill = capturedFill,
		fillAlpha = capturedFillAlpha,
		gradientAlpha = capturedGradientAlpha,
	}

	-- Create gradient fill display list
	clusterData.gradient = glCreateList(function()
		glBeginEnd(GL.TRIANGLES, DrawHullVerticesGradient, hull, cluster.center, listColors)
	end)

	-- Create edge display list
	clusterData.edge = glCreateList(function()
		glBeginEnd(GL.LINE_LOOP, DrawHullVertices, hull)
	end)

	-- Track the alpha used for the current gradient list so we can decide later
	-- whether to rebuild on subsequent fade ticks.
	clusterData.bakedAlpha = alphaMult

	displayLists[cid] = clusterData

	-- Update state hash after successful recreation
	stateHashes[cid] = newHash
end

-- Build (or rebuild) display lists for a single fading-out cluster entry.
-- Bakes the entry's current alpha into the gradient list so we get a real fade.
local function CreateFadingClusterDisplayList(uid, isEnergy)
	local fading = isEnergy and animState.fadingEnergy or animState.fading
	local entry = fading[uid]
	if not entry then
		return
	end
	local hull = entry.hullCopy
	local center = entry.center
	if not hull or #hull < 3 or not center then
		return
	end

	local alphaMult = entry.alpha or entry.startAlpha or 1
	if alphaMult < 0 then
		alphaMult = 0
	end
	if alphaMult > 1 then
		alphaMult = 1
	end

	-- Reuse table if present; otherwise allocate
	local dl = entry.displayLists
	if not dl then
		dl = {}
		entry.displayLists = dl
	end
	if dl.gradient then
		glDeleteList(dl.gradient)
		dl.gradient = nil
	end
	if dl.edge then
		glDeleteList(dl.edge)
		dl.edge = nil
	end

	local listColors
	if isEnergy then
		listColors = {
			fill = energyReclaimColor,
			fillAlpha = fillAlpha * energyOpacityMultiplier * alphaMult,
			gradientAlpha = gradientAlpha * energyOpacityMultiplier * alphaMult,
		}
	else
		listColors = {
			fill = reclaimColor,
			fillAlpha = fillAlpha * alphaMult,
			gradientAlpha = gradientAlpha * alphaMult,
		}
	end

	dl.gradient = glCreateList(function()
		glBeginEnd(GL.TRIANGLES, DrawHullVerticesGradient, hull, center, listColors)
	end)
	dl.edge = glCreateList(function()
		glBeginEnd(GL.LINE_LOOP, DrawHullVertices, hull)
	end)
	entry.lastBakedAlpha = alphaMult
end

-- Create / refresh the text list for a fading cluster. The text fades alongside
-- the hull, so we rebuild it when alpha changes meaningfully.
local function CreateFadingClusterTextDisplayList(uid, isEnergy)
	local fading = isEnergy and animState.fadingEnergy or animState.fading
	local entry = fading[uid]
	if not entry or not entry.text then
		return
	end
	local dl = entry.displayLists
	if not dl then
		dl = {}
		entry.displayLists = dl
	end
	if dl.text then
		glDeleteList(dl.text)
		dl.text = nil
	end
	local fontSize = isEnergy and (entry.font * energyTextSizeMultiplier) or entry.font
	local textColor = isEnergy and energyNumberColor or numberColor
	local alphaMult = entry.alpha or 1
	if alphaMult < 0 then
		alphaMult = 0
	end
	if alphaMult > 1 then
		alphaMult = 1
	end
	dl.text = glCreateList(function()
		glColor(textColor[1], textColor[2], textColor[3], textColor[4] * alphaMult)
		glText(entry.text, 0, 0, fontSize, alphaMult >= 0.95 and "cvo" or "cv")
	end)
	entry.lastBakedTextAlpha = alphaMult
end

-- Create text display list for a single cluster
-- Text is rendered at origin (0,0) and positioned via matrix in DrawWorld
local function CreateClusterTextDisplayList(cid, isEnergy, fadeMult)
	local displayLists = isEnergy and energyClusterDisplayLists or clusterDisplayLists
	local clusters = isEnergy and energyFeatureClusters or featureClusters

	local cluster = clusters[cid]
	if not cluster then
		return
	end

	local clusterData = displayLists[cid]
	if not clusterData then
		clusterData = {}
		displayLists[cid] = clusterData
	end

	if clusterData.text then
		glDeleteList(clusterData.text)
		clusterData.text = nil
	end

	local fontSize = isEnergy and (cluster.font * energyTextSizeMultiplier) or cluster.font
	local textColor = isEnergy and energyNumberColor or numberColor
	local textOptions = fadeMult >= 0.95 and "cvo" or "cv"

	clusterData.text = glCreateList(function()
		glColor(textColor[1], textColor[2], textColor[3], textColor[4] * fadeMult)
		glText(cluster.text, 0, 0, fontSize, textOptions)
	end)

	local meta = clusterData.textMeta
	if meta then
		meta.fade = fadeMult
		meta.text = cluster.text
		meta.fontSize = fontSize
		meta.lastUpdateFrame = spGetGameFrame()
	else
		clusterData.textMeta = {
			fade = fadeMult,
			text = cluster.text,
			fontSize = fontSize,
			lastUpdateFrame = spGetGameFrame(),
		}
	end
end

-- Check if text display list needs updating
local function TextDisplayListNeedsUpdate(cid, isEnergy, fadeMult)
	local displayLists = isEnergy and energyClusterDisplayLists or clusterDisplayLists
	local clusterData = displayLists[cid]

	if not clusterData or not clusterData.text or not clusterData.textMeta then
		return true
	end

	local meta = clusterData.textMeta
	local clusters = isEnergy and energyFeatureClusters or featureClusters
	local cluster = clusters[cid]

	if not cluster or meta.text ~= cluster.text then
		return true
	end

	-- Check font size changed (cluster was reclustered)
	local fontSize = isEnergy and (cluster.font * energyTextSizeMultiplier) or cluster.font
	if abs(fontSize - meta.fontSize) > 0.5 then
		return true
	end

	local fadeDiff = abs(fadeMult - meta.fade)
	if fadeMult >= 0.95 and meta.fade >= 0.95 then
		return false
	end
	if fadeDiff > immediateFadeChangeThreshold then
		return true
	end

	local currentFrame = spGetGameFrame()
	if meta.lastUpdateFrame and (currentFrame - meta.lastUpdateFrame) < minTextUpdateIntervalFrames then
		return false
	end

	if fadeDiff > 0.15 then
		return true
	end

	return false
end

local cachedCameraFacing = 0

-- Process deferred features that may have come into view
local function ProcessDeferredFeatures(frame)
	if (batch.deferCreateCount == 0 and batch.deferDestrCount == 0) or (frame - batch.lastDeferFrame < batch.deferInterval and frame % 10 ~= 0) then
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
local function ProcessPendingFeatureChanges()
	-- Process batched feature creations first
	if batch.pendCreateCount > 0 then
		for i = 1, batch.pendCreateCount do
			local featureID = batch.pendCreations[i]
			AddFeature(featureID)
			batch.pendCreations[i] = nil
		end
		batch.pendCreateCount = 0
		dirty.needCluster = true
	end

	-- Process batched feature destructions
	if batch.pendDestrCount > 0 then
		for i = 1, batch.pendDestrCount do
			local featureID = batch.pendDestructions[i]
			if knownFeatures[featureID] then
				RemoveFeature(featureID)
			end
			batch.pendDestructions[i] = nil
		end
		batch.pendDestrCount = 0
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
			local _, _, _, vw = spGetFeatureVelocity(featureID)
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

	return featuresAdded
end

-- Helper: Validate and remove invalid features
local function ValidateAndRemoveInvalidFeatures()
	local removeCount = 0
	local featureCount = cachedKnownFeaturesCount
	local checkInterval = max(1, floor(featureCount / 50))
	validityCheckCounter = validityCheckCounter + 1

	for fid, fInfo in pairs(knownFeatures) do
		if checkInterval == 1 or (validityCheckCounter % checkInterval == 0) then
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
		validityCheckCounter = validityCheckCounter + 1
	end

	for i = 1, removeCount do
		RemoveFeature(batch.toRemove[i])
	end

	for i = 1, removeCount do
		batch.toRemove[i] = nil
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

	-- Process deferred features periodically or when they come into view
	if frame ~= lastProcessedFrame then
		lastProcessedFrame = frame
		ProcessDeferredFeatures(frame)
		ProcessPendingFeatureChanges()
	end

	-- Refresh draw state before checking early return (avoid stale cached values)
	UpdateDrawEnabled()
	UpdateDrawEnergyEnabled()

	if drawEnabled == false and (not showEnergyFields or not drawEnergyEnabled or allEnergyFieldsDrained) then
		return
	end

	if not dirty.needCluster and not dirty.forceFullRedraw and frame - lastCheckFrame < checkFrequency and os.clock() - lastCheckFrameClock < (checkFrequency / 30) then
		return
	end
	lastCheckFrame = spGetGameFrame()
	lastCheckFrameClock = os.clock()

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

	-- Always check for feature value updates so stored values are current
	-- (needed even when clustering is pending, since cluster totals use stored values)
	UpdateFeatureReclaim()

	if featuresAdded or dirty.needCluster then
		ValidateAndRemoveInvalidFeatures()
		animState.CapturePreClusteringSnapshot()
		ClusterizeFeatures()
		animState.SyncClusterIdentitiesAfterClustering()
	end

	if dirty.needRedraw == true then
		RecreateDisplayListsForVisibleClusters()
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
	gameStarted = SpringShared.GetGameFrame() > 0
	screenx, screeny = widgetHandler:GetViewSizes()

	-- Initialize camera scale early to avoid thick lines on first draw
	local cx, cy, cz = spGetCameraPosition()
	local desc, w = spTraceScreenRay(screenx / 2, screeny / 2, true)
	if desc ~= nil then
		local cameraDist = min(64000000, (cx - w[1]) ^ 2 + (cy - w[2]) ^ 2 + (cz - w[3]) ^ 2)
		cameraScale = sqrt(sqrt(cameraDist) / 600)
	else
		cameraScale = 1.0
	end

	widgetHandler:AddAction("reclaim_highlight", enableHighlight, nil, "p")
	widgetHandler:AddAction("reclaim_highlight", disableHighlight, nil, "r")

	WG["reclaimfieldhighlight"] = {}
	WG["reclaimfieldhighlight"].getShowOption = function()
		return showOption
	end
	WG["reclaimfieldhighlight"].setShowOption = function(value)
		showOption = value
	end
	WG["reclaimfieldhighlight"].getSmoothingSegments = function()
		return smoothingSegments
	end
	WG["reclaimfieldhighlight"].setSmoothingSegments = function(value)
		smoothingSegments = clamp(value, 4, 40) -- Clamp to reasonable range
		dirty.needCluster = true -- Force recluster with new settings
	end
	WG["reclaimfieldhighlight"].getShowEnergyFields = function()
		return showEnergyFields
	end
	WG["reclaimfieldhighlight"].setShowEnergyFields = function(value)
		showEnergyFields = value
		dirty.needCluster = true -- Force recluster with new settings
	end
	WG["reclaimfieldhighlight"].getShowEnergyOption = function()
		return showEnergyOption
	end
	WG["reclaimfieldhighlight"].setShowEnergyOption = function(value)
		showEnergyOption = value
	end
	WG["reclaimfieldhighlight"].getFadeStartDistance = function()
		return fadeStartDistance
	end
	WG["reclaimfieldhighlight"].setFadeStartDistance = function(value)
		fadeStartDistance = max(100, value)
		-- Ensure start < end
		if fadeStartDistance >= fadeEndDistance then
			fadeEndDistance = fadeStartDistance + 1000
		end
	end
	WG["reclaimfieldhighlight"].getFadeEndDistance = function()
		return fadeEndDistance
	end
	WG["reclaimfieldhighlight"].setFadeEndDistance = function(value)
		fadeEndDistance = max(fadeStartDistance + 100, value)
	end

	WG["reclaimfieldhighlight"].getAlwaysShowFields = function()
		return alwaysShowFields
	end
	WG["reclaimfieldhighlight"].setAlwaysShowFields = function(value)
		alwaysShowFields = value
	end

	WG["reclaimfieldhighlight"].getAlwaysShowFieldsThreshold = function()
		return alwaysShowFieldsThreshold
	end
	WG["reclaimfieldhighlight"].setAlwaysShowFieldsThreshold = function(value)
		-- Deprecated - threshold is now auto-calculated
		-- This function kept for backwards compatibility
	end

	WG["reclaimfieldhighlight"].getAlwaysShowFieldsMinThreshold = function()
		return alwaysShowFieldsMinThreshold
	end
	WG["reclaimfieldhighlight"].setAlwaysShowFieldsMinThreshold = function(value)
		alwaysShowFieldsMinThreshold = max(0, value)
		alwaysShowFieldsThreshold = CalculateAlwaysShowThreshold()
	end

	WG["reclaimfieldhighlight"].getAlwaysShowFieldsMaxThreshold = function()
		return alwaysShowFieldsMaxThreshold
	end
	WG["reclaimfieldhighlight"].setAlwaysShowFieldsMaxThreshold = function(value)
		alwaysShowFieldsMaxThreshold = max(alwaysShowFieldsMinThreshold, value)
		alwaysShowFieldsThreshold = CalculateAlwaysShowThreshold()
	end

	WG["reclaimfieldhighlight"].getTotalMapMetal = function()
		return totalMapMetal
	end

	-- Deferred update settings
	WG["reclaimfieldhighlight"].getDeferOutOfViewUpdates = function()
		return batch.deferOutOfView
	end
	WG["reclaimfieldhighlight"].setDeferOutOfViewUpdates = function(value)
		batch.deferOutOfView = value
	end
	WG["reclaimfieldhighlight"].getOutOfViewMargin = function()
		return batch.outOfViewMargin
	end
	WG["reclaimfieldhighlight"].setOutOfViewMargin = function(value)
		batch.outOfViewMargin = max(0, value)
	end

	-- Start/restart feature clustering.
	knownFeatures = {}
	flyingFeatures = {}
	featureNeighborsMatrix = {}
	featureClusters = {}
	featureConvexHulls = {}
	energyFeatureClusters = {}
	energyFeatureConvexHulls = {}
	opticsObject = Optics.new()
	cachedKnownFeaturesCount = 0 -- Reset cached count

	for _, featureID in ipairs(SpringShared.GetAllFeatures()) do
		widget:FeatureCreated(featureID)
	end

	camUpVector = spGetCameraVectors().up

	widget:SelectionChanged(SpringUnsynced.GetSelectedUnits())
end

function widget:Shutdown()
	widgetHandler:RemoveAction("reclaim_highlight", "p")
	widgetHandler:RemoveAction("reclaim_highlight", "r")

	WG["reclaimfieldhighlight"] = nil -- todo: register/deregister, right?

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
		alwaysShowFieldsMaxThreshold = alwaysShowFieldsMaxThreshold,
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
		if dx * dx + dy * dy + dz * dz > 1 then
			local desc, w = spTraceScreenRay(screenx / 2, screeny / 2, true)
			local cameraDist = 35000000
			if desc ~= nil then
				cameraDist = min(64000000, (cx - w[1]) ^ 2 + (cy - w[2]) ^ 2 + (cz - w[3]) ^ 2)
			end
			cameraScale = sqrt(sqrt(cameraDist) / 600)
		end
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
	vsx, vsy = SpringUnsynced.GetViewGeometry()
end

--------------------------------------------------------------------------------
-- Per-cluster draw helpers (hoisted to module scope so widget:DrawWorldPreUnit
-- doesn't reallocate them as closures every frame).
--------------------------------------------------------------------------------

local function DrawLiveCluster(cid, isEnergy, drawGradient)
	local clusters = isEnergy and energyFeatureClusters or featureClusters
	local cluster = clusters[cid]
	if not cluster then
		return 0
	end

	-- Drive the smoothed visibility tween: query GetClusterVisibility on the
	-- gradient pass each frame so the anim entry's visTarget stays current.
	if drawGradient then
		GetClusterVisibility(cid, isEnergy, drawCounter)
	end

	local effAlpha, animScale = animState.GetClusterAnimAlphaAndScale(cluster.uid, isEnergy)
	if effAlpha <= 0.005 then
		return 0
	end

	local clusterData
	if isEnergy then
		clusterData = energyClusterDisplayLists[cid]
	else
		clusterData = clusterDisplayLists[cid]
	end
	if drawGradient then
		local needRebuild = false
		if not clusterData or not clusterData.gradient then
			needRebuild = true
		elseif not clusterData.bakedAlpha or abs(effAlpha - clusterData.bakedAlpha) > animCfg.rebuildThreshold then
			needRebuild = true
		end
		if needRebuild then
			if isEnergy then
				energyClusterStateHashes[cid] = nil
			else
				clusterStateHashes[cid] = nil
			end
			CreateClusterDisplayList(cid, isEnergy, effAlpha)
			clusterData = isEnergy and energyClusterDisplayLists[cid] or clusterDisplayLists[cid]
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
	if alpha <= 0.005 then
		return
	end
	local center = entry.center
	if not center then
		return
	end
	local inView = IsInCameraView(center.x, center.y, center.z, 600, drawCounter)
	if not inView then
		return
	end

	if drawGradient then
		local dl = entry.displayLists
		if not dl or not dl.gradient or not entry.lastBakedAlpha or abs(alpha - entry.lastBakedAlpha) > animCfg.rebuildThreshold then
			CreateFadingClusterDisplayList(uid, entry.isEnergy)
			dl = entry.displayLists
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
	if spIsGUIHidden() == true then
		return
	end

	local hasFadingMetal = next(animState.fading) ~= nil
	local hasFadingEnergy = next(animState.fadingEnergy) ~= nil
	local showMetal = drawEnabled or animState.toggleMetal > 0.005 or hasFadingMetal
	local showEnergy = (showEnergyFields and drawEnergyEnabled and not allEnergyFieldsDrained) or (showEnergyFields and animState.toggleEnergy > 0.005) or hasFadingEnergy
	if not showMetal and not showEnergy then
		return
	end

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

	-- Draw metal text (positions pre-computed in ClusterizeFeatures)
	if showMetal then
		for clusterID = 1, #featureClusters do
			local cluster = featureClusters[clusterID]
			if cluster and cluster.textX then
				-- effAlpha already folds in distance/frustum vis (smoothed), anim alpha,
				-- and toggle fade. We don't need the cached.fadeMult anymore.
				local effAlpha = animState.GetClusterAnimAlphaAndScale(cluster.uid, false)
				if effAlpha > 0.01 then
					if TextDisplayListNeedsUpdate(clusterID, false, effAlpha) then
						CreateClusterTextDisplayList(clusterID, false, effAlpha)
					end
					local clusterData = clusterDisplayLists[clusterID]
					if clusterData and clusterData.text then
						glPushMatrix()
						glMultMatrix(cosF, 0, negSinF, 0, negSinF, 0, negCosF, 0, 0, 1, 0, 0, cluster.textX, cluster.center.y, cluster.textZ, 1)
						glCallList(clusterData.text)
						glPopMatrix()
					end
				end
			end
		end
		-- Fading-out metal cluster text
		for uid, entry in pairs(animState.fading) do
			local alpha = entry.alpha or 0
			if alpha > 0.01 and entry.text then
				if not entry.displayLists or not entry.displayLists.text or not entry.lastBakedTextAlpha or abs(alpha - entry.lastBakedTextAlpha) > animCfg.rebuildThreshold then
					CreateFadingClusterTextDisplayList(uid, false)
					entry.lastBakedTextAlpha = alpha
				end
				if entry.displayLists and entry.displayLists.text then
					glPushMatrix()
					glMultMatrix(cosF, 0, negSinF, 0, negSinF, 0, negCosF, 0, 0, 1, 0, 0, entry.textX, entry.center.y, entry.textZ, 1)
					glCallList(entry.displayLists.text)
					glPopMatrix()
				end
			end
		end
	end

	-- Draw energy text (positions pre-computed in ClusterizeFeatures)
	if showEnergy then
		for clusterID = 1, #energyFeatureClusters do
			local cluster = energyFeatureClusters[clusterID]
			if cluster and cluster.textX then
				local effAlpha = animState.GetClusterAnimAlphaAndScale(cluster.uid, true)
				if effAlpha > 0.01 then
					if TextDisplayListNeedsUpdate(clusterID, true, effAlpha) then
						CreateClusterTextDisplayList(clusterID, true, effAlpha)
					end
					local clusterData = energyClusterDisplayLists[clusterID]
					if clusterData and clusterData.text then
						glPushMatrix()
						glMultMatrix(cosF, 0, negSinF, 0, negSinF, 0, negCosF, 0, 0, 1, 0, 0, cluster.textX, cluster.center.y, cluster.textZ, 1)
						glCallList(clusterData.text)
						glPopMatrix()
					end
				end
			end
		end
		-- Fading-out energy cluster text
		for uid, entry in pairs(animState.fadingEnergy) do
			local alpha = entry.alpha or 0
			if alpha > 0.01 and entry.text then
				if not entry.displayLists or not entry.displayLists.text or not entry.lastBakedTextAlpha or abs(alpha - entry.lastBakedTextAlpha) > animCfg.rebuildThreshold then
					CreateFadingClusterTextDisplayList(uid, true)
					entry.lastBakedTextAlpha = alpha
				end
				if entry.displayLists and entry.displayLists.text then
					glPushMatrix()
					glMultMatrix(cosF, 0, negSinF, 0, negSinF, 0, negCosF, 0, 0, 1, 0, 0, entry.textX, entry.center.y, entry.textZ, 1)
					glCallList(entry.displayLists.text)
					glPopMatrix()
				end
			end
		end
	end

	glDepthTest(true)
	if debugTiming then
		timingAccum.drawWorldText = timingAccum.drawWorldText + (osClock() - t0)
	end
end

function widget:DrawWorldPreUnit()
	drawCounter = drawCounter + 1

	local tUpd0 = debugTiming and osClock() or 0
	UpdateReclaimFields()
	if debugTiming then
		timingAccum.updateReclaim = timingAccum.updateReclaim + (osClock() - tUpd0)
	end

	-- Tick animations once per draw using a wall-clock dt (works while paused)
	animState.TickClusterAnimations(osClock())

	-- Before gamestart, always show; after gamestart, check drawEnabled
	if spIsGUIHidden() == true then
		return
	end

	-- Determine if we need to draw anything. We continue rendering during
	-- toggle-fade-out, and we always render currently fading-out clusters.
	local hasFadingMetal = next(animState.fading) ~= nil
	local hasFadingEnergy = next(animState.fadingEnergy) ~= nil
	local showMetal = drawEnabled or animState.toggleMetal > 0.005 or hasFadingMetal
	local showEnergy = (showEnergyFields and drawEnergyEnabled and not allEnergyFieldsDrained) or (showEnergyFields and animState.toggleEnergy > 0.005) or hasFadingEnergy

	if not showMetal and not showEnergy then
		return
	end

	-- Reset GL state at the start
	glDepthTest(false)
	glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	glLineWidth(((vsy / 1440) * 3.3) / cameraScale)

	local tVis0 = debugTiming and osClock() or 0

	-- Draw metal fields (gradient + edge)
	if showMetal then
		-- Gradient layer (pushed down by 1 unit)
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

		-- Edge layer (reuse cached visibility from gradient pass)
		for cid = 1, #featureClusters do
			DrawLiveCluster(cid, false, false)
		end
		for uid, entry in pairs(animState.fading) do
			DrawFadingCluster(uid, entry, false)
		end
	end

	-- Draw energy fields (gradient + edge)
	if showEnergy then
		glPushMatrix()
		glTranslate(0, -1, 0)
		for cid = 1, #energyFeatureClusters do
			DrawLiveCluster(cid, true, true)
		end
		for uid, entry in pairs(animState.fadingEnergy) do
			DrawFadingCluster(uid, entry, true)
		end
		glPopMatrix()

		for cid = 1, #energyFeatureClusters do
			DrawLiveCluster(cid, true, false)
		end
		for uid, entry in pairs(animState.fadingEnergy) do
			DrawFadingCluster(uid, entry, false)
		end
	end

	glLineWidth(1.0)
	glDepthTest(true)

	if debugTiming then
		timingAccum.drawPreUnit = timingAccum.drawPreUnit + (osClock() - tVis0)
	end

	-- Periodic timing report
	timingCount = timingCount + 1
	if debugTiming and timingCount >= timingInterval then
		local div = timingCount
		SpringShared.Echo(string.format("[ReclaimField TIMING] per-call avg (ms): UpdateReclaim=%.3f  DrawWorldText=%.3f  DrawPreUnit=%.3f  | Update()=%.3f  | clusters=%d  features=%d", timingAccum.updateReclaim / div * 1000, timingAccum.drawWorldText / div * 1000, timingAccum.drawPreUnit / div * 1000, timingAccum.updateFunc / div * 1000, #featureClusters, cachedKnownFeaturesCount))
		for k in pairs(timingAccum) do
			timingAccum[k] = 0
		end
		timingCount = 0
	end
end
