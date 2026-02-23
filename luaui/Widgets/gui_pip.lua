local devUI = Spring.Utilities.ShowDevUI()
local isSinglePlayer = Spring.Utilities.Gametype.IsSinglePlayer()
local isSpectator = Spring.GetSpectatingState()
local pipEnabled = Spring.GetModOptions().pip

-- When pipEnabled: always load
-- When not pipEnabled: only load if devUI AND (spectator OR singleplayer)
if not pipEnabled then
	if not devUI then
		return
	end
	if not isSinglePlayer and not isSpectator then
		return
	end
end

pipNumber = pipNumber or 1

-- Special mode flags
local isMinimapMode = (pipNumber == 0)  -- When pipNumber == 0, act as minimap replacement
local minimapModeMinZoom = nil  -- Calculated zoom to fit entire map (only used in minimap mode)
local pipModeMinZoom = nil  -- Dynamic min zoom calculated from PIP/map dimensions (normal PIP mode)

-- Minimap mode API upvalues (updated each frame, avoids per-frame closure allocations)
local minimapApiNormLeft, minimapApiNormRight, minimapApiNormBottom, minimapApiNormTop = 0, 1, 1, 0
local minimapApiZoomLevel = 1
local minimapApiGetNormalizedVisibleArea = function()
	return minimapApiNormLeft, minimapApiNormRight, minimapApiNormBottom, minimapApiNormTop
end
local minimapApiGetZoomLevel = function()
	return minimapApiZoomLevel
end

-- Helper function to get effective zoom minimum (accounts for minimap mode)
local function GetEffectiveZoomMin()
	if isMinimapMode and minimapModeMinZoom then
		return minimapModeMinZoom
	end
	return pipModeMinZoom or 0.04
end

-- Helper function to get effective zoom maximum (accounts for minimap mode)
local function GetEffectiveZoomMax()
	-- In minimap mode, still allow zooming IN (higher zoom values)
	return 0.95  -- Default config.zoomMax value
end

-- Helper function to check if at minimum zoom (fully zoomed out) in minimap mode
local function IsAtMinimumZoom(zoom)
	if isMinimapMode and minimapModeMinZoom then
		return zoom <= minimapModeMinZoom * 1.02  -- 2% tolerance for floating point and smooth zooming
	end
	return false
end

-- Forward declaration (defined after config and cameraState)
local IsLeftClickPanActive

function widget:GetInfo()
	return {
		name      = "Picture-in-Picture",
		desc      = "",
		author    = "Floris", -- (original by Niobium created in 2010)
		version   = "2.0",
		date      = "October 2025",
		license   = "GNU GPL, v2 or later",
		layer     = -(99020-pipNumber),
		enabled   = true,
		handler   = true,
	}
end
----------------------------------------------------------------------------------------------------
-- Keyboard config for hotkey display
----------------------------------------------------------------------------------------------------
local keyConfig = VFS.Include("luaui/configs/keyboard_layouts.lua")

----------------------------------------------------------------------------------------------------
-- GL4 instanced rendering support (for efficient icon drawing with many units)
-- Uses raw VBO + direct array writes for zero per-frame allocations.
----------------------------------------------------------------------------------------------------
local currentKeyboardLayout = Spring.GetConfigString("KeyboardLayout", "qwerty")

-- Helper function to get a formatted hotkey string for an action
local function getActionHotkey(action)
	local hotkeys = Spring.GetActionHotKeys(action)
	if not hotkeys or #hotkeys == 0 then
		return ""
	end
	-- Find shortest hotkey
	local key = hotkeys[1]
	for i = 2, #hotkeys do
		if hotkeys[i]:len() < key:len() then
			key = hotkeys[i]
		end
	end
	return keyConfig.sanitizeKey(key, currentKeyboardLayout):gsub("%+", " + ")
end

----------------------------------------------------------------------------------------------------
-- Todo
----------------------------------------------------------------------------------------------------
-- Add rendering building on cursor when active command is a building (incl. indicator of valid build location)
-- Add rendering of buildings that are in queues
-- Fix unit y positioning (Requires fixed perspective)
-- Icons don't get under construction outline

----------------------------------------------------------------------------------------------------
-- Config
----------------------------------------------------------------------------------------------------
local config = {
	-- UI colors and sizing
	panelBorderColorLight = {0.75, 0.75, 0.75, 1},
	panelBorderColorDark = {0.2, 0.2, 0.2, 1},
	minPanelSize = 330,
	maxPanelSizeVsy = 0.4,  -- Maximum size as fraction of vertical screen resolution
	buttonSize = 50,
	
	-- Zoom settings
	zoomWheel = 1.22,
	zoomRate = 15,
	zoomSmoothness = 10,
	centerSmoothness = 15,
	trackingSmoothness = 8,
	playerTrackingSmoothness = 4.5,
	switchSmoothness = 30,
	zoomMin = 0.04,
	zoomMax = 1,
	zoomFeatures = 0.2,
	zoomFeaturesFadeRange = 0.06,  -- Zoom range over which features fade in/out
	zoomProjectileDetail = 0.12,
	zoomExplosionDetail = 0.12,  -- Legacy, now using graduated visibility
	drawExplosions = true,  -- Separate from projectiles
	drawPlasmaTrails = true,  -- Show fading trails behind plasma/artillery projectiles
	explosionOverlay = true,  -- Re-render explosions on top of unit icons (additive glow)
	explosionOverlayAlpha = 0.66,  -- Strength of the above-icons explosion overlay (0-1)
	healthDarkenMax = 0.2,  -- Maximum darkening for damaged units on GL4 icons (0-1, 0.18 = 18%)
	activityFocusIgnoreSpectators = true,  -- Don't trigger camera focus for spectator map markers
	activityFocusHideForSpectators = true,  -- Hide the activity focus button when spectating (default: disabled for spectators)
	activityFocusDuration = 1.8,  -- Seconds to hold focus on a marker before restoring camera
	activityFocusZoom = 0.28,  -- Zoom level when focusing on a marker (higher = more zoomed in)
	activityFocusShowMinimap = true,  -- Temporarily show pip-minimap overlay while focused on a map marker
	activityFocusBlockIgnoredPlayers = true,  -- Completely block activity focus for players on your ignore list (WG.ignoredAccounts)
	activityFocusCooldown = 3,  -- Minimum seconds between focus triggers from the same player
	activityFocusThrottleWindow = 10,  -- Time window (seconds) to count markers from a player
	activityFocusThrottleCount = 3,  -- After this many markers in the window, ignore that player temporarily
	activityFocusThrottleDuration = 15,  -- Seconds to ignore a throttled player
	activityFocusMuteCount = 6,  -- After this many markers in the window, mute that player entirely
	activityFocusMuteDuration = 60,  -- Seconds to mute a heavily spamming player
	-- TV mode settings (spectator auto-camera)
	tvModeSpectatorsOnly = true,  -- Only allow TV mode for spectators
	tvMaxZoom = 0.63,              -- Maximum zoom level for TV mode (never close enough for unitpics)
	tvMinZoom = 0.08,             -- Minimum zoom level for TV overview shots
	tvOverviewZoom = 0.07,        -- Zoom level for periodic overview shots (wider view of the map)
	tvCloseupZoom = 0.45,         -- Zoom level for close-up action shots
	tvFocusDuration = 6.0,        -- Base seconds to hold focus on a hotspot before considering switch
	tvOverviewDuration = 2.5,     -- Seconds to hold an overview shot
	tvOverviewInterval = 18,      -- Seconds between periodic overview shots
	tvSwitchCooldown = 3.5,       -- Minimum seconds between camera switches
	tvEventDecayTime = 12,        -- Seconds for events to fully decay
	tvHotspotRadius = 800,        -- World units: events within this distance merge into one hotspot
	tvMaxEvents = 200,            -- Max tracked events (ring buffer)
	tvVarietyBonus = 0.3,         -- Weight bonus for unvisited areas (0-1)
	tvPanSpeed = 3.0,             -- Camera pan smoothness (higher = faster convergence)
	tvZoomSpeed = 2.5,            -- Camera zoom smoothness
	tvUnitFinishedCostThreshold = 800,  -- Minimum unit cost to trigger a "big unit finished" event

	drawDecals = true,  -- Show ground decals (explosion scars, footprints) from the decals GL4 widget
	drawCommandFX = true,  -- Show brief fading command lines when orders are given (like Commands FX widget)
	commandFXIgnoreNewUnits = true,  -- Ignore commands given to newly finished units (rally point orders)
	commandFXOpacity = 0.3,  -- Initial opacity of command FX lines
	commandFXDuration = 0.66,  -- Seconds for command FX lines to fully fade out
	
	-- Feature and overlay settings
	hideEnergyOnlyFeatures = false,
	showLosOverlay = true,
	showLosRadar = true,
	losOverlayOpacity = 0.6,
	allowCommandsWhenSpectating = false,  -- Allow giving commands as spectator when god mode is enabled
	
	-- Rendering settings
	iconRadius = 40,
	showUnitpics = true,      -- Show unitpics instead of icons when zoomed in
	unitpicZoomThreshold = 0.7, -- Zoom level at which to switch to unitpics (higher = more zoomed in)
	leftButtonPansCamera = isMinimapMode and (Spring.GetConfigInt("MinimapLeftClickMove", 1) == 1) or false,
	maximizeSizemult = 1.25,
	screenMargin = 0.045,
	drawProjectiles = true,
	zoomToCursor = true,
	mapEdgeMargin = 0,
	showButtonsOnHoverOnly = true,
	switchInheritsTracking = false,
	switchTransitionTime = 0.15,
	showMapRuler = false,
	cancelPlayerTrackingOnPan = true,  -- Cancel player camera tracking when trying to pan or ALT+drag
	pipMinimapCorner = 3,  -- Corner for pip minimap: 1=bottom-left, 2=bottom-right, 3=top-left, 4=top-right
	minimapHeightPercent = 0.12,  -- Minimap height as percent of PIP height (maintains aspect ratio)
	minimapHoverHeightPercent = 0.15,  -- Minimap height when hovering over PIP
	
	-- Performance settings
	showPipFps = false,
	showPipTimers = false,  -- Echo per-section timing breakdown to Spring.Echo (debug)
	contentResolutionScale = 2,  -- Render texture at this multiple of PIP size (1 = 1:1, 2 = 2x resolution for (marginally) sharper content)
	smoothCameraMargin = 0.05,  -- Oversized texture margin for expensive layers (units, features, projectiles)
	smoothCameraMarginCheap = 0.15,  -- Oversized texture margin for cheap layers (ground, water, LOS) — larger since rendering is cheap
	pipFloorUpdateRate = 10,	-- Minimum update rate for PIP content when performance is poor (will be smoothly applied based on measured frame times)
	pipMinUpdateRate = 30,		-- Minimum update rate for PIP content when zoomed out
	pipMaxUpdateRate = 120,		-- Maximum update rate for PIP content when zoomed in
	pipZoomThresholdMin = 0.15,
	pipZoomThresholdMax = 0.4,
	pipTargetDrawTime = 0.0025,
	pipPerformanceAdjustSpeed = 0.1,	-- Exponential smoothing factor (0-1) for the performance rate-limiter. Each frame, contentPerformanceFactor lerps toward its target by this fraction: higher = faster reaction to GPU load spikes, lower = smoother but slower adaptation.
	pipFrameTimeThreshold = 0.007,  -- threshold before starting to lower FPS
	pipFrameTimeHistorySize = 10,  -- Number of frames to average
	
	radarWobbleSpeed = 1,
	CMD_AREA_MEX = GameCMD and GameCMD.AREA_MEX or 10000,

	-- Middle-click teleport settings (click without drag moves world camera to clicked position)
	middleClickTeleport = true,  -- Enable middle-click to teleport world camera
	middleClickZoomMin = 0.2,    -- Maximum zoom in for teleport (lower = more zoomed in)
	middleClickZoomMax = 0.95,    -- Maximum zoom out for teleport (higher = more zoomed out)
	middleClickZoomOffset = -0.18,  -- Teleport slightly more zoomed out than PIP (0 = same as PIP)
	minimapMiddleClickZoomMin = 0.2,  -- auto zoom in to this zoom level
	minimapMiddleClickZoomMax = 0.95,  -- auto zoom out to this zoom level
	
	-- Minimap mode settings (when pipNumber == 0)
	minimapModeMaxHeight = 0.32,  -- Default max height (will be overridden by user's minimap config if available)
	minimapModeMaxWidth = 0.26,   -- Max width as fraction of screen width
	minimapModeScreenMargin = 0,  -- No margin in minimap mode (edge-to-edge)
	minimapModeShowButtons = false,  -- Hide buttons in minimap mode
	minimapModeStartMinimized = false,  -- Don't start minimized in minimap mode
	minimapModeHideMoveResize = true,  -- Hide move and resize buttons in minimap mode
	hideAICommands = true,  -- Hide command queues from AI players (default: enabled)
	showSpectatorPings = true,  -- Show map pings from spectators on the PIP minimap
	showViewRectangleOnMinimap = false,  -- Show the PIP view rectangle on the engine minimap
	showViewRectangleInWorld = false,  -- Show the PIP view rectangle as an outline in the 3D world
}

-- State variables
local state = {
	losViewEnabled = false,
	losViewAllyTeam = nil,
}

----------------------------------------------------------------------------------------------------
-- Globals
----------------------------------------------------------------------------------------------------

-- Consolidated rendering state
local render = {
	uiScale = tonumber(Spring.GetConfigFloat("ui_scale", 1) or 1),
	vsx = nil,
	vsy = nil,
	widgetScale = nil,
	usedButtonSize = nil,
	elementPadding = nil,
	elementCorner = nil,
	RectRound = nil,
	UiElement = nil,
	RectRoundOutline = nil,
	dim = {},  -- Panel dimensions: left, right, bottom, top
	world = {l=0, r=0, b=0, t=0},  -- World coordinate boundaries
	ground = { view = {l=0, r=0, b=0, t=0}, coord = {l=0, r=1, b=1, t=0} },  -- Ground texture view and texture coordinates
	minModeDlist = nil,  -- Display list for minimized mode button
	mapRulerDlist = nil,  -- Display list for map ruler marks
	mapRulerCacheKey = nil,  -- Cache key to detect when ruler needs regeneration
	mapRulerMarkDlists = {},  -- Reusable mark pattern display lists
	mapRulerLastMarkSize = nil,  -- Track mark size changes
	minimapRotation = 0,  -- Current minimap rotation in radians
	guishaderDlist = nil,  -- Display list for guishader blur with rounded corners
}

-- Initialize render dimensions
render.vsx, render.vsy = Spring.GetViewGeometry()
render.widgetScale = (render.vsy / 2000) * render.uiScale
render.usedButtonSize = math.floor(config.buttonSize * render.widgetScale * render.uiScale)
render.dim.l = math.floor(render.vsx*0.7)
render.dim.r = math.floor((render.vsx*0.7)+(config.minPanelSize*render.widgetScale*1.4))
render.dim.b = math.floor(render.vsy*0.7)
render.dim.t = math.floor((render.vsy*0.7)+(config.minPanelSize*render.widgetScale*1.2))

-- Consolidated camera state
local cameraState = {
	zoom = 0.55,  -- Current zoom level
	targetZoom = 0.55,
	wcx = 1000,
	wcz = 1000,
	targetWcx = 1000,
	targetWcz = 1000,
	mySpecState = Spring.GetSpectatingState(),
	lastTrackedCameraState = nil,
	zoomToCursorActive = false,
	zoomToCursorWorldX = 0,
	zoomToCursorWorldZ = 0,
	zoomToCursorScreenX = 0,
	zoomToCursorScreenY = 0,
}

-- Consolidated UI state
local uiState = {
	inMinMode = false,
	minModeL = nil,
	minModeB = nil,
	savedDimensions = {},
	isAnimating = false,
	animationProgress = 0,
	animationDuration = 0.22,
	animStartDim = {},
	animEndDim = {},
	drawingGround = true,
	areResizing = false,
}

-- Render-to-texture state (consolidated to reduce local variable count)
local pipR2T = {
	contentTex = nil,
	contentNeedsUpdate = true,
	contentLastUpdateTime = 0,
	contentCurrentUpdateRate = config.pipMinUpdateRate,
	contentLastWidth = 0,
	contentLastHeight = 0,
	contentTexWidth = 0,  -- Actual oversized texture width in pixels
	contentTexHeight = 0,  -- Actual oversized texture height in pixels
	contentWcx = 0,  -- Camera X when contentTex was rendered
	contentWcz = 0,  -- Camera Z when contentTex was rendered
	contentZoom = 0,  -- Zoom when contentTex was rendered
	contentRotation = 0,  -- Rotation when contentTex was rendered
	contentLastDrawTime = 0,  -- Last measured draw time for performance monitoring
	contentDrawTimeHistory = {},  -- Ring buffer of last 6 frame times
	contentDrawTimeHistoryIndex = 0,  -- Current index in ring buffer
	contentDrawTimeAverage = 0,  -- Average of last 6 frame times
	contentPerformanceFactor = 1.0,  -- Multiplier applied to update rate based on performance (1.0 = no adjustment)
	frameBackgroundTex = nil,
	frameButtonsTex = nil,
	frameNeedsUpdate = true,
	frameLastWidth = 0,
	frameLastHeight = 0,
	-- Content mask for rounded corners
	contentMaskDlist = nil,
	contentMaskLastWidth = 0,
	contentMaskLastHeight = 0,
	contentMaskLastL = 0,
	contentMaskLastB = 0,
	-- LOS texture state
	losTex = nil,
	losNeedsUpdate = true,
	losLastUpdateTime = 0,
	losUpdateRate = 0.4,  -- Update every 0.4 seconds
	losTexScale = 96,  -- 96:1 ratio of map size to LOS texture size
	losLastMode = nil,  -- Track whether last update used engine or manual LOS
	losEngineDelayFrames = 0,  -- Delay frames before switching to engine LOS to let it update
	-- Map ruler texture state
	rulerTex = nil,
	rulerNeedsUpdate = true,
	rulerCacheKey = nil,  -- Cache key to detect significant changes
	-- Tracked player overlay cache
	resbarTextDlist = nil,
	resbarTextLastUpdate = 0,
	resbarTextUpdateRate = 0.5,  -- Update resource text at 2 FPS
	resbarTextLastPlayerID = nil,
	playerNameDlist = nil,
	playerNameLastPlayerID = nil,
	playerNameLastName = nil,
	-- Smooth camera: oversized units texture for camera-transition interpolation
	unitsTex = nil,  -- Oversized FBO for expensive content (units, features, projectiles, etc.)
	unitsTexWidth = 0,  -- Actual texture width in pixels
	unitsTexHeight = 0,  -- Actual texture height in pixels
	unitsLastWidth = 0,  -- Last PIP width used to create unitsTex
	unitsLastHeight = 0,  -- Last PIP height used to create unitsTex
	unitsWorld = { l = 0, r = 0, b = 0, t = 0 },  -- World coordinates when unitsTex was rendered
	unitsZoom = 0,  -- Camera zoom when unitsTex was rendered
	unitsRotation = 0,  -- Minimap rotation when unitsTex was rendered
	unitsWcx = 0,  -- Camera X position when unitsTex was rendered
	unitsWcz = 0,  -- Camera Z position when unitsTex was rendered
	unitsNeedsUpdate = true,  -- Flag to force unitsTex re-render
	unitsLastUpdateTime = 0,  -- Last time unitsTex was rendered
	-- Decal overlay texture state (render-to-texture)
	decalTex = nil,
	decalLastCheckFrame = 0,  -- last frame we ran the dirty check
	decalCheckInterval = 30,  -- game frames between dirty checks (~1 second)
	decalTexScale = 5,  -- X:1 ratio of map size to decal texture size
}
render.minModeDlist = nil  -- Display list for minimized mode button

-- Consolidated interaction state
local interactionState = {
	areDragging = false,
	arePanning = false,
	panStartX = 0,
	panStartY = 0,
	panToggleMode = false,
	middleMousePressed = false,
	middleMouseMoved = false,
	middleMousePressX = 0,
	middleMousePressY = 0,
	leftMousePressed = false,
	rightMousePressed = false,
	areCentering = false,
	areDecreasingZoom = false,  -- Pulling back (decreasing zoom value)
	areIncreasingZoom = false,  -- Getting closer (increasing zoom value)
	areTracking = nil,
	trackingPlayerID = nil,
	lastTrackedTeammate = nil,  -- Track last cycled teammate for proper cycling order
	areBoxSelecting = false,
	areBoxDeselecting = false,
	boxSelectStartX = 0,
	boxSelectStartY = 0,
	boxSelectEndX = 0,
	boxSelectEndY = 0,
	lastBoxSelectUpdate = 0,
	lastModifierState = {false, false, false, false},
	selectionBeforeBox = nil, -- Store selection before box selection starts
	areFormationDragging = false,
	formationDragStartX = 0,
	formationDragStartY = 0,
	formationDragShouldQueue = false,
	areBuildDragging = false,
	buildDragStartX = 0,
	buildDragStartY = 0,
	buildDragPositions = {},
	areAreaDragging = false,
	areaCommandStartX = 0,
	areaCommandStartY = 0,
	lastMapDrawX = nil,
	lastMapDrawZ = nil,
	clickHandledInPanMode = false,
	isMouseOverPip = false,
	lastHoverCheckTime = 0,
	lastHoverCheckX = 0,
	lastHoverCheckY = 0,
	minimizeButtonDragging = false,  -- Whether we're dragging via minimize button to move PIP window
	minimizeButtonClickStartX = 0,  -- Screen X when we started clicking minimize button
	minimizeButtonClickStartY = 0,  -- Screen Y when we started clicking minimize button
	pipMinimapBounds = nil,  -- {l, r, b, t} bounds of pip-minimap when visible, nil otherwise
	pipMinimapDragging = false,  -- Whether we're dragging the pip-minimap to move camera
	worldCameraDragging = false,  -- Whether we're left-click dragging to move the world camera (leftButtonPansCamera mode)
	lastHoverCursorCheckTime = 0,  -- Throttle timer for GetUnitAtPoint hover checks
	lastHoveredUnitID = nil,       -- Last unit found under cursor (for cursor icon updates)
	lastHoveredFeatureID = nil,    -- Last feature found under cursor (for info widget)
}

-- Helper: leftButtonPansCamera only active when at minimum zoom (fully zoomed out) and not tracking a player
IsLeftClickPanActive = function()
	return config.leftButtonPansCamera and IsAtMinimumZoom(cameraState.zoom) and not interactionState.trackingPlayerID
end

-- Consolidated misc state
local miscState = {
	startX = nil,
	startZ = nil,
	isProcessingMapDraw = false,
	mapmarkInitScreenX = nil,
	mapmarkInitScreenY = nil,
	mapmarkInitTime = 0,
	backupTracking = nil,
	isSwitchingViews = false,
	hadSavedConfig = false,
	savedGameID = nil,  -- GameID from saved config for new game detection
	hasOpenedPIPThisGame = false,  -- Whether PIP has been opened/maximized at least once this game
	pipUnits = {},
	pipFeatures = {},
	mapMarkers = {},  -- Table to store active map markers
	minimapWidgetDisabled = false,  -- Whether we've disabled the old minimap widget (for minimap mode)
	minimapCameraRestored = false,  -- Whether minimap camera state was restored from config (for luaui reload)
	minimapMinimized = false,  -- Whether the minimap is hidden via MinimapMinimize config (minimap mode only)
	crashingUnits = {},  -- Units that are crashing (no icon should be drawn)
	gameOverZoomingOut = false,  -- True while GameOver zoom-out animation is in progress
	isGameOver = false,  -- True after GameOver callin fires (disables takeable blink etc.)
	-- Activity focus: briefly pan camera to map markers then restore
	activityFocusEnabled = isMinimapMode,  -- Toggle state for the button (default on for minimap mode)
	activityFocusSavedWcx = nil,   -- Saved camera X before focus
	activityFocusSavedWcz = nil,   -- Saved camera Z before focus
	activityFocusSavedZoom = nil,  -- Saved zoom before focus
	activityFocusTime = 0,         -- os.clock() when we started focusing on a marker
	activityFocusActive = false,   -- True while camera is focused on a marker (waiting to restore)
	activityFocusTargetX = nil,    -- World X of the marker being focused on
	activityFocusTargetZ = nil,    -- World Z of the marker being focused on
	activityFocusPlayerHistory = {},  -- Per-player spam tracking: [playerID] = { timestamps={}, mutedUntil=0, throttledUntil=0 }
	lastFullview = nil,  -- Previous fullview state, used to detect fullview ON→OFF transitions
	specGhostScanDone = false,  -- Whether we've done a full ghost scan while fullview is ON
	specGhostScanTime = 0,  -- Last time we ran the ghost scan (to throttle periodic rescans)
	tvEnabled = false,  -- TV mode toggle state
}

----------------------------------------------------------------------------------------------------
-- TV Mode: Automatic spectator camera that tracks areas of interest
-- Architecture: Event Tracker → Hotspot Clustering → Director (selects target) → Camera Controller
----------------------------------------------------------------------------------------------------
local pipTV = {
	-- Event ring buffer: { x, z, weight, time, type }
	events = {},
	eventHead = 0,       -- Next write index (wraps at config.tvMaxEvents)
	eventCount = 0,      -- Total events currently stored

	-- Hotspot clustering: rebuilt each director tick from recent events
	hotspots = {},       -- { x, z, weight, eventCount, lastEventTime }
	hotspotCount = 0,

	-- Director state: decides WHAT to look at
	director = {
		currentHotspotX = nil,    -- World X of current focus
		currentHotspotZ = nil,    -- World Z of current focus
		currentWeight = 0,        -- Weight of current focus
		focusStartTime = 0,       -- When we started focusing on current target
		lastSwitchTime = 0,       -- When we last switched targets
		lastOverviewTime = 0,     -- When we last did an overview shot
		isOverviewShot = false,   -- Currently doing a wide overview
		visitedAreas = {},        -- Recently visited positions for variety [{x,z,time}]
		visitedCount = 0,
		idle = true,              -- No interesting events yet
		peakActivity = 0,         -- Highest hotspot weight seen so far (tracks game intensity)
	},

	-- Camera controller: manages HOW to move the camera (smooth interpolation)
	camera = {
		targetX = nil,   -- World X target (set by director)
		targetZ = nil,   -- World Z target
		targetZoom = 0.2,  -- Zoom target
		active = false,  -- Whether TV camera is currently controlling the PIP camera
		savedWcx = nil,  -- Saved camera before TV mode
		savedWcz = nil,
		savedZoom = nil,
		directorTimer = 0,   -- Throttle director ticks (runs at ~7 Hz, not every frame)
		lastPublishX = 0,    -- Last published camera X for WG.pipTVFocus (reduce writes)
		lastPublishZ = 0,    -- Last published camera Z
	},
}

-- TV Mode: Add an event to the ring buffer
-- type: 'combat', 'explosion', 'death', 'finished', 'marker'
function pipTV.AddEvent(x, z, weight, eventType)
	if not miscState.tvEnabled then return end
	if not x or not z then return end
	local maxEv = config.tvMaxEvents
	pipTV.eventHead = (pipTV.eventHead % maxEv) + 1
	local idx = pipTV.eventHead
	local ev = pipTV.events[idx]
	if not ev then
		ev = {}
		pipTV.events[idx] = ev
	end
	ev.x = x
	ev.z = z
	ev.weight = weight or 1
	ev.time = os.clock()
	ev.type = eventType or 'combat'
	if pipTV.eventCount < maxEv then
		pipTV.eventCount = pipTV.eventCount + 1
	end
end

-- TV Mode: Rebuild hotspot clusters from recent events
-- @param now: cached os.clock() from caller to avoid redundant system call
function pipTV.BuildHotspots(now)
	local decayTime = config.tvEventDecayTime
	local radius = config.tvHotspotRadius
	local radiusSq = radius * radius
	local hs = pipTV.hotspots
	local hsCount = 0

	-- When LOS view is enabled, only consider events visible to the tracked allyteam
	local losFilter = state.losViewEnabled and state.losViewAllyTeam

	-- Clear old hotspots
	for i = 1, #hs do hs[i] = nil end

	-- Process each event, merge into nearby hotspot or create new one
	local events = pipTV.events
	for i = 1, pipTV.eventCount do
		local ev = events[i]
		if ev then
			local age = now - ev.time
			if age < decayTime and (not losFilter or Spring.IsPosInLos(ev.x, 0, ev.z, losFilter)) then
				-- Time-based decay: linear falloff
				local decayFactor = 1 - (age / decayTime)
				local w = ev.weight * decayFactor

				-- Try to merge into existing hotspot
				local merged = false
				for j = 1, hsCount do
					local h = hs[j]
					local dx = h.x - ev.x
					local dz = h.z - ev.z
					if dx * dx + dz * dz < radiusSq then
						-- Weighted average position
						local totalW = h.weight + w
						h.x = (h.x * h.weight + ev.x * w) / totalW
						h.z = (h.z * h.weight + ev.z * w) / totalW
						h.weight = totalW
						h.eventCount = h.eventCount + 1
						if ev.time > h.lastEventTime then
							h.lastEventTime = ev.time
						end
						merged = true
						break
					end
				end

				if not merged then
					hsCount = hsCount + 1
					local h = hs[hsCount]
					if not h then
						h = {}
						hs[hsCount] = h
					end
					h.x = ev.x
					h.z = ev.z
					h.weight = w
					h.eventCount = 1
					h.lastEventTime = ev.time
				end
			end
		end
	end
	pipTV.hotspotCount = hsCount
end

-- TV Mode: Calculate variety bonus (areas not recently visited get a boost)
-- Optimized: pre-compute squared threshold, sqrt only for entries that pass
-- @param now: cached os.clock() from caller
function pipTV.GetVarietyBonus(x, z, now)
	local visited = pipTV.director.visitedAreas
	local maxPenalty = 0
	local varietyRadius = config.tvHotspotRadius * 2
	local varietyRadiusSq = varietyRadius * varietyRadius
	for i = 1, pipTV.director.visitedCount do
		local v = visited[i]
		if v then
			local age = now - v.time
			if age < 30 then  -- 30s memory for visited areas
				local dx = v.x - x
				local dz = v.z - z
				local distSq = dx * dx + dz * dz
				if distSq < varietyRadiusSq then
					-- Closer and more recent = more penalty (sqrt only on hit)
					local dist = math.sqrt(distSq)
					local distFactor = 1 - (dist / varietyRadius)
					local timeFactor = 1 - (age / 30)
					local penalty = distFactor * timeFactor
					if penalty > maxPenalty then maxPenalty = penalty end
				end
			end
		end
	end
	return config.tvVarietyBonus * (1 - maxPenalty)
end

-- TV Mode: Record that we visited an area
function pipTV.RecordVisit(x, z)
	local dir = pipTV.director
	local idx = (dir.visitedCount % 20) + 1  -- Keep last 20 visits
	local v = dir.visitedAreas[idx]
	if not v then
		v = {}
		dir.visitedAreas[idx] = v
	end
	v.x = x
	v.z = z
	v.time = os.clock()
	if dir.visitedCount < 20 then
		dir.visitedCount = dir.visitedCount + 1
	end
end

-- TV Mode: Director tick — selects the best hotspot to focus on
-- Called from Update(), returns targetX, targetZ, targetZoom or nil if nothing interesting
function pipTV.DirectorTick(dt)
	local now = os.clock()
	local dir = pipTV.director

	-- Rebuild hotspots from recent events (pass cached clock to avoid redundant syscall)
	pipTV.BuildHotspots(now)

	-- Early game ramp: blend of time and activity level
	-- Time factor: 0→1 over first 2 minutes (baseline)
	-- Activity factor: 0→1 as peak hotspot weight reaches combat levels (~10+)
	-- Use whichever is higher — so early fights on small maps instantly ramp up
	local gameFrame = Spring.GetGameFrame()
	local timeFactor = math.min(1, gameFrame / (30 * 60 * 2))  -- 0→1 over 2 minutes

	-- Track peak activity across all current hotspots
	for i = 1, pipTV.hotspotCount do
		local hw = pipTV.hotspots[i].weight
		if hw > dir.peakActivity then dir.peakActivity = hw end
	end
	-- Activity ramp: light skirmishes (weight ~5) → 0.5, real combat (weight ~10+) → 1.0
	local activityFactor = math.min(1, dir.peakActivity / 10)
	local gameMinutes = math.max(timeFactor, activityFactor)

	-- Helper: check if a position is too close to another PIP's TV focus or planned target
	-- Returns a multiplier 0..1 (0 = fully overlapping, 1 = no overlap)
	-- Checks both current focus AND planned next target of other PIPs
	-- Higher-numbered PIPs use a larger exclusion radius to stay further away
	local pipRole = pipNumber or 0  -- pip0 (minimap) = main camera, pip1+ = B-roll cameras
	local coordRadiusMult = 4 + pipRole * 2  -- pip0: 4x, pip1: 6x, pip2: 8x, pip3: 10x
	-- Pre-compute squared radii to avoid sqrt in distance comparisons
	local hotspotRadiusSq = config.tvHotspotRadius * config.tvHotspotRadius
	local coordRadius = config.tvHotspotRadius * coordRadiusMult
	local coordRadiusSq = coordRadius * coordRadius
	local nearbyDriftRadiusSq = (config.tvHotspotRadius * 1.5) * (config.tvHotspotRadius * 1.5)
	local function getCoordinationFactor(x, z)
		local tvFoci = WG.pipTVFocus
		if not tvFoci then return 1 end
		local worstFactor = 1
		for otherPip, focus in pairs(tvFoci) do
			if otherPip ~= pipNumber then
				-- Higher-numbered PIPs yield harder to lower-numbered ones
				local yieldBonus = (otherPip < (pipNumber or 1)) and 1.0 or 0.7

				-- PRIMARY CHECK: Is this hotspot inside what the other PIP is actually showing?
				-- Uses the real camera position + zoom-derived view radius
				if focus.camX and focus.viewRadius then
					local cdx = x - focus.camX
					local cdz = z - focus.camZ
					local cdistSq = cdx * cdx + cdz * cdz
					local vr = focus.viewRadius * (1 + pipRole * 0.3)
					if cdistSq < vr * vr then
						-- Inside the other PIP's view — sqrt only needed for overlap ratio
						local overlap = 1 - (math.sqrt(cdistSq) / vr)
						local penalty = overlap * overlap * yieldBonus
						local penalized = 1 - penalty * 0.98
						if penalized < worstFactor then worstFactor = penalized end
					end
				end

				-- SECONDARY CHECK: Director target focus (squared distance, sqrt only on hit)
				local fdx = x - focus.x
				local fdz = z - focus.z
				local fdistSq = fdx * fdx + fdz * fdz
				if fdistSq < coordRadiusSq then
					local overlap = 1 - (math.sqrt(fdistSq) / coordRadius)
					local factor = overlap * overlap * yieldBonus
					local penalized = 1 - factor * 0.97
					if penalized < worstFactor then worstFactor = penalized end
				end
				-- Also check planned target (squared distance, sqrt only on hit)
				if focus.plannedX then
					local pdx = x - focus.plannedX
					local pdz = z - focus.plannedZ
					local pdistSq = pdx * pdx + pdz * pdz
					if pdistSq < coordRadiusSq then
						local overlap = 1 - (math.sqrt(pdistSq) / coordRadius)
						local factor = overlap * overlap * yieldBonus
						local penalized = 1 - factor * 0.85
						if penalized < worstFactor then worstFactor = penalized end
					end
				end
			end
		end
		return worstFactor
	end

	-- No hotspots at all — idle mode, do a slow overview
	if pipTV.hotspotCount == 0 then
		if dir.idle then return nil end
		dir.idle = true
		-- Stagger overview position per PIP to avoid identical views
		local offsetX = (pipNumber or 0) * Game.mapSizeX * 0.15
		local overviewX = math.min(Game.mapSizeX * 0.85, Game.mapSizeX / 2 + offsetX)
		return overviewX, Game.mapSizeZ / 2, config.tvOverviewZoom
	end

	dir.idle = false

	-- Check if it's time for a periodic overview shot
	-- Stagger overview timing per PIP so they don't all overview simultaneously
	-- Early game: overview every ~6s instead of every ~18s, scaling up as game progresses
	local overviewInterval = (config.tvOverviewInterval * (0.3 + 0.7 * gameMinutes)) + (pipNumber or 0) * 3
	local timeSinceOverview = now - dir.lastOverviewTime
	if timeSinceOverview >= overviewInterval and not dir.isOverviewShot then
		dir.isOverviewShot = true
		dir.focusStartTime = now
		dir.lastSwitchTime = now
		dir.lastOverviewTime = now
		local offsetX = (pipNumber or 0) * Game.mapSizeX * 0.15
		local overviewX = math.min(Game.mapSizeX * 0.85, Game.mapSizeX / 2 + offsetX)
		return overviewX, Game.mapSizeZ / 2, config.tvOverviewZoom
	end

	-- If in overview, check if duration expired
	if dir.isOverviewShot then
		if (now - dir.focusStartTime) >= config.tvOverviewDuration then
			dir.isOverviewShot = false
			-- Fall through to pick a hotspot
		else
			return nil  -- Keep current overview
		end
	end

	-- Time since last switch
	local timeSinceSwitch = now - dir.lastSwitchTime
	local focusTime = now - dir.focusStartTime

	-- Don't switch too fast
	if timeSinceSwitch < config.tvSwitchCooldown then
		-- Keep re-asserting current target if we have one (in case hotspot moved)
		if dir.currentHotspotX then
			-- If another PIP is now watching our area, skip cooldown and force re-evaluation
			local coordFactor = getCoordinationFactor(dir.currentHotspotX, dir.currentHotspotZ)
			if coordFactor < 0.3 then
				-- Another PIP is very close — break cooldown and fall through to scoring
				dir.lastSwitchTime = 0  -- Allow immediate switch
			else
				-- Find the closest hotspot to our current focus to track drift
				local bestDist = math.huge
				local bestH = nil
				for i = 1, pipTV.hotspotCount do
					local h = pipTV.hotspots[i]
					local dx = h.x - dir.currentHotspotX
					local dz = h.z - dir.currentHotspotZ
					local d = dx * dx + dz * dz
					if d < bestDist then
						bestDist = d
						bestH = h
					end
				end
				if bestH and bestDist < config.tvHotspotRadius * config.tvHotspotRadius then
					dir.currentHotspotX = bestH.x
					dir.currentHotspotZ = bestH.z
					dir.currentWeight = bestH.weight
				end
				-- Calculate zoom based on weight: heavier events = closer
				-- Early game: stay more zoomed out
				local cooldownWeightForZoom = dir.currentWeight / (15 + (1 - gameMinutes) * 25)
				local zoom = config.tvOverviewZoom + (config.tvCloseupZoom - config.tvOverviewZoom) *
					math.min(1, cooldownWeightForZoom)
				zoom = math.min(zoom, config.tvMaxZoom)
				return dir.currentHotspotX, dir.currentHotspotZ, zoom
			end
		end
		if dir.currentHotspotX then return nil end  -- Still in cooldown, no coord conflict
		return nil
	end

	-- Score each hotspot
	-- Higher-numbered PIPs act as "B-roll cameras": they prefer secondary/minor action
	-- pipRole 0 (pip1) = main camera, scores normally
	-- pipRole 1+ = B-roll, dampens high weights and boosts low weights (seeks secondary action)
	local bestScore = -math.huge
	local bestH = nil
	local secondBestScore = -math.huge
	local secondBestH = nil
	for i = 1, pipTV.hotspotCount do
		local h = pipTV.hotspots[i]
		local score = h.weight

		-- B-roll scoring: higher PIPs prefer less dominant hotspots
		-- Compress weight range: score = weight^(1/(1+pipRole))
		-- pip1: score = weight^1 (unchanged), pip2: score = weight^0.5 (sqrt), pip3: weight^0.33
		if pipRole > 0 then
			score = math.pow(math.max(score, 0.01), 1 / (1 + pipRole))
		end

		-- Recency boost: hotspots with very recent events get a big boost
		local recency = now - h.lastEventTime
		if recency < 2 then
			score = score * (2 - recency)  -- Up to 2x for events < 2s ago
		end

		-- Variety bonus: areas we haven't visited recently score higher
		-- Higher PIPs get stronger variety bonus to roam more
		score = score + pipTV.GetVarietyBonus(h.x, h.z, now) * (1 + pipRole * 0.5)

		-- Cross-PIP coordination: heavily penalize hotspots watched by another PIP
		score = score * getCoordinationFactor(h.x, h.z)

		-- Penalty for being too close to current focus (encourage switching)
		-- Uses squared distance to avoid sqrt
		if dir.currentHotspotX and focusTime > config.tvFocusDuration then
			local dx = h.x - dir.currentHotspotX
			local dz = h.z - dir.currentHotspotZ
			if dx * dx + dz * dz < hotspotRadiusSq then
				score = score * 0.5  -- Penalize staying on same spot too long
			end
		end

		if score > bestScore then
			secondBestScore = bestScore
			secondBestH = bestH
			bestScore = score
			bestH = h
		elseif score > secondBestScore then
			secondBestScore = score
			secondBestH = h
		end
	end

	if not bestH then return nil end

	-- Publish our planned next target so other PIPs can avoid it
	if WG.pipTVFocus and WG.pipTVFocus[pipNumber] then
		WG.pipTVFocus[pipNumber].plannedX = bestH.x
		WG.pipTVFocus[pipNumber].plannedZ = bestH.z
		-- Also publish 2nd-best as fallback info
		if secondBestH then
			WG.pipTVFocus[pipNumber].altX = secondBestH.x
			WG.pipTVFocus[pipNumber].altZ = secondBestH.z
		end
	end

	-- Decide whether to switch from current target
	-- Higher-numbered PIPs stay longer on their (secondary) targets
	local effectiveFocusDuration = config.tvFocusDuration * (1 + pipRole * 0.5)  -- pip2: 1.5x, pip3: 2x
	local shouldSwitch = false
	if not dir.currentHotspotX then
		shouldSwitch = true
	elseif focusTime >= effectiveFocusDuration then
		-- Time to consider switching
		-- Switch if new target is significantly more interesting OR we've been here too long
		if bestScore > dir.currentWeight * 1.3 or focusTime > effectiveFocusDuration * 2 then
			shouldSwitch = true
		end
	elseif bestScore > dir.currentWeight * 3.5 then
		-- Emergency switch: something much more interesting happened elsewhere
		shouldSwitch = true
	end

	if shouldSwitch then
		-- Proximity check: if the new target is close to current, just drift there
		-- without resetting focus timer (avoids unnecessary "switch" churn)
		-- Uses pre-computed nearbyDriftRadiusSq to avoid sqrt
		local isNearbyDrift = false
		if dir.currentHotspotX then
			local sdx = bestH.x - dir.currentHotspotX
			local sdz = bestH.z - dir.currentHotspotZ
			if sdx * sdx + sdz * sdz < nearbyDriftRadiusSq then
				isNearbyDrift = true
			end
		end

		dir.currentHotspotX = bestH.x
		dir.currentHotspotZ = bestH.z
		dir.currentWeight = bestH.weight
		-- Always reset lastSwitchTime to enforce cooldown even for nearby drifts.
		-- Without this, two close hotspots trading "best" score ping-pong every
		-- director tick (~0.15s) because the cooldown check never triggers.
		dir.lastSwitchTime = now
		if not isNearbyDrift then
			-- Full switch: also reset focus timer and record visit
			dir.focusStartTime = now
			pipTV.RecordVisit(bestH.x, bestH.z)
		end
		-- Update shared focus for cross-PIP coordination
		if WG.pipTVFocus and WG.pipTVFocus[pipNumber] then
			WG.pipTVFocus[pipNumber].x = bestH.x
			WG.pipTVFocus[pipNumber].z = bestH.z
		end
	else
		-- Not switching: keep currentWeight up to date with the hotspot's live weight
		-- so the switch threshold stays calibrated (prevents stale-weight easy switches)
		if dir.currentHotspotX then
			for i = 1, pipTV.hotspotCount do
				local h = pipTV.hotspots[i]
				local dx = h.x - dir.currentHotspotX
				local dz = h.z - dir.currentHotspotZ
				if dx * dx + dz * dz < config.tvHotspotRadius * config.tvHotspotRadius then
					dir.currentWeight = math.max(dir.currentWeight, h.weight)
					break
				end
			end
		end
	end

	-- Calculate zoom based on weight: heavier hotspot = zoom in closer
	-- Early game: stay more zoomed out (need more weight to zoom in)
	local weightForZoom = dir.currentWeight / (15 + (1 - gameMinutes) * 25)  -- early: need ~40 weight for max zoom
	local zoom = config.tvOverviewZoom + (config.tvCloseupZoom - config.tvOverviewZoom) *
		math.min(1, weightForZoom)
	zoom = math.min(zoom, config.tvMaxZoom)

	return dir.currentHotspotX, dir.currentHotspotZ, zoom
end

-- TV Mode: Camera controller tick — smoothly moves PIP camera toward director target
-- This is separate from the director; it only handles interpolation
function pipTV.CameraUpdate(dt)
	if not pipTV.camera.active then return end

	-- Throttle director: run heavy decision-making (hotspot clustering + scoring) at ~7 Hz
	-- Camera interpolation still runs every frame for smooth movement
	local cam = pipTV.camera
	cam.directorTimer = cam.directorTimer + dt
	if cam.directorTimer >= 0.15 then
		cam.directorTimer = 0
		local tx, tz, tzoom = pipTV.DirectorTick(dt)
		if tx then
			cam.targetX = tx
			cam.targetZ = tz
			local newZoom = math.max(tzoom, GetEffectiveZoomMin())
			-- Low-pass filter on zoom target: blend 60% toward the new value per director tick.
			-- This prevents momentary weight spikes (big explosion → decay) from causing
			-- abrupt zoom target jumps that the camera then has to chase and reverse.
			-- Takes ~3 director ticks (~0.45s) to converge on a sustained change.
			if cam.targetZoom then
				cam.targetZoom = cam.targetZoom + (newZoom - cam.targetZoom) * 0.6
			else
				cam.targetZoom = newZoom
			end
		end
	end

	-- Smoothly interpolate camera position and zoom toward director targets
	-- Uses exponential smoothing (1 - exp(-dt * speed)) which is frame-rate independent
	-- and produces clean deceleration without stepping artifacts at the tail end
	if cam.targetX then
		local dx = cam.targetX - cameraState.targetWcx
		local dz = cam.targetZ - cameraState.targetWcz
		local distSq = dx * dx + dz * dz
		local dZoom = cam.targetZoom - cameraState.targetZoom

		-- Position smoothing (use distSq to avoid sqrt)
		if distSq < 1 then
			cameraState.targetWcx = cam.targetX
			cameraState.targetWcz = cam.targetZ
		else
			local panFactor = 1 - math.exp(-dt * config.tvPanSpeed)
			cameraState.targetWcx = cameraState.targetWcx + dx * panFactor
			cameraState.targetWcz = cameraState.targetWcz + dz * panFactor
		end

		-- Zoom smoothing (asymmetric: zoom-in is responsive, zoom-out is gentle)
		-- Prevents the "zoom in far then snap back out" artifact when hotspot weight
		-- spikes temporarily from an explosion then decays
		if math.abs(dZoom) < 0.0005 then
			cameraState.targetZoom = cam.targetZoom
		else
			-- dZoom > 0 means zooming in (higher zoom = closer), use normal speed
			-- dZoom < 0 means zooming out, use 35% speed for a graceful pullback
			local speed = dZoom > 0 and config.tvZoomSpeed or (config.tvZoomSpeed * 0.35)
			local zoomFactor = 1 - math.exp(-dt * speed)
			cameraState.targetZoom = cameraState.targetZoom + dZoom * zoomFactor
		end

		-- For TV mode, also drive .zoom and .wcx/.wcz directly to bypass the main loop's
		-- linear lerp (which causes stepping). We are the sole authority on camera position.
		cameraState.zoom = cameraState.targetZoom

		-- Clamp position to map bounds so we never show void outside the map
		local pipWidth = render.dim.r - render.dim.l
		local pipHeight = render.dim.t - render.dim.b
		if render.minimapRotation then
			local rotDeg = math.abs(render.minimapRotation * 180 / math.pi) % 180
			if rotDeg > 45 and rotDeg < 135 then
				pipWidth, pipHeight = pipHeight, pipWidth
			end
		end
		local visW = pipWidth / cameraState.zoom
		local visH = pipHeight / cameraState.zoom
		local marginFrac = config.mapEdgeMargin or 0
		-- Clamp X axis
		local marginX = visW * marginFrac
		local minX = visW / 2 - marginX
		local maxX = Game.mapSizeX - (visW / 2 - marginX)
		if minX >= maxX then
			cameraState.targetWcx = Game.mapSizeX / 2
		else
			cameraState.targetWcx = math.min(math.max(cameraState.targetWcx, minX), maxX)
		end
		-- Clamp Z axis
		local marginZ = visH * marginFrac
		local minZ = visH / 2 - marginZ
		local maxZ = Game.mapSizeZ - (visH / 2 - marginZ)
		if minZ >= maxZ then
			cameraState.targetWcz = Game.mapSizeZ / 2
		else
			cameraState.targetWcz = math.min(math.max(cameraState.targetWcz, minZ), maxZ)
		end
		cameraState.wcx = cameraState.targetWcx
		cameraState.wcz = cameraState.targetWcz
	end

	-- Publish actual camera position + view radius for cross-PIP coordination
	-- Only update when position changed significantly (>50 world units) to reduce table writes
	if WG.pipTVFocus and WG.pipTVFocus[pipNumber] then
		local pubDx = cameraState.targetWcx - cam.lastPublishX
		local pubDz = cameraState.targetWcz - cam.lastPublishZ
		if pubDx * pubDx + pubDz * pubDz > 2500 then  -- 50^2
			cam.lastPublishX = cameraState.targetWcx
			cam.lastPublishZ = cameraState.targetWcz
			WG.pipTVFocus[pipNumber].camX = cameraState.targetWcx
			WG.pipTVFocus[pipNumber].camZ = cameraState.targetWcz
			local zoom = cameraState.targetZoom or 0.15
			WG.pipTVFocus[pipNumber].viewRadius = 1200 / math.max(zoom, 0.05)
		end
	end
end

-- Ghost building cache: enemy buildings seen but no longer in direct LOS
-- Position is static (buildings don't move), drawn from cache when out of LOS
-- Mirrors engine minimap ghost building behavior at last known position
-- key = unitID, value = { defID = unitDefID, x = worldX, z = worldZ, teamID = teamID }
local ghostBuildings = {}

-- Building position caches: buildings never move, avoiding per-frame GetUnitBasePosition
local ownBuildingPosX = {}  -- [unitID] = worldX
local ownBuildingPosZ = {}  -- [unitID] = worldZ

local drawData = {
	hoveredUnitID = nil,
	lastSelectionboxEnabled = nil,
}

-- Reusable table pools to reduce GC pressure
-- These tables are reused across frames instead of being allocated/deallocated repeatedly
-- This significantly reduces garbage collection overhead in performance-critical draw paths
local pools = {
	selectableUnits = {}, -- Reused for GetUnitsInBox results
	fragmentsByTexture = {}, -- Reused for icon shatter fragments grouping (DrawIconShatters)
	unitsToShow = {}, -- Reused for DrawCommandQueuesOverlay unit list
	commandLine = {}, -- Reused for batched command line vertices
	commandMarker = {}, -- Reused for batched command marker vertices
	stillAlive = {}, -- Reused for UpdateTracking alive units
	cmdOpts = {alt=false, ctrl=false, meta=false, shift=false, right=false}, -- Reused for GetCmdOpts
	buildPositions = {}, -- Reused for CalculateBuildDragPositions
	buildsByTexture = {}, -- Reused for DrawQueuedBuilds texture grouping
	buildCountByTexture = {}, -- Reused for DrawQueuedBuilds counts
	savedDim = {l=0, r=0, b=0, t=0}, -- Reused for R2T dimension backup
	projectileColor = {1, 0.5, 0, 1}, -- Reused for DrawProjectile default color
	yellowColor = {1, 1, 0, 1}, -- Reused for non-blaster weapon projectile color
	greyColor = {0.7, 0.7, 0.7, 1}, -- Reused for debris projectile color
	trackingMerge = {}, -- Reused for tracking unit merge operations
	trackingTempSet = {}, -- Reused for tracking unit deduplication
	activeTrails = {}, -- Reused for tracking active missile trails
}

-- Command queue waypoint cache: avoids calling GetUnitCommands every frame.
-- GetUnitCommands allocates ~60 tables per unit per call (outer + cmd + params tables),
-- which causes massive GC pressure. Caching and only refreshing every N frames eliminates this.
local CMD_CACHE_INTERVAL = 6  -- refresh commands every 6 draw frames (~100ms at 60fps)
local cmdQueueCache = {
	waypoints = {},       -- [unitID] = { n = wpCount, [1]={x,z,cmdID}, [2]={x,z,cmdID}, ... }
	counter = 0,          -- draw-call counter for throttling
	lastUnitHash = 0,     -- quick hash for unit list change detection
}

----------------------------------------------------------------------------------------------------
-- GL4 Instanced Icon Rendering State
----------------------------------------------------------------------------------------------------
-- GPU-driven icon rendering: replaces the CPU-heavy DrawUnit+DrawIcons pipeline with a single
-- instanced draw call via a texture atlas + VBO + geometry shader.
-- Benefits: eliminates per-icon texture switches, per-icon draw calls, and most per-unit API calls.
local gl4Icons = {
	INSTANCE_STEP = 12,       -- floats per icon instance (3 x vec4)
	MAX_INSTANCES = 16384,    -- pre-allocated capacity (covers 16k units without resize)
	LAYER_STRUCTURE = 0,      -- structures drawn first (bottom)
	LAYER_GROUND = 1,         -- ground mobile units
	LAYER_AIR = 2,            -- air units above ground
	LAYER_COMMANDER = 3,      -- commanders drawn last (top, above air)
	enabled = false,          -- Set true after successful init
	atlas = nil,              -- Engine '$icons' texture string
	atlasUVs = {},            -- [unitDefID] = {u0, v0, u1, v1} (UV rect in atlas, Y-flipped)
	defaultUV = nil,          -- UV for PipBlip fallback icon
	vbo = nil,                -- Raw GL VBO (no InstanceVBOTable overhead)
	vao = nil,                -- VAO with VBO attached
	shader = nil,             -- Compiled GLSL shader program
	uniformLocs = {},         -- Cached uniform locations
	unitDefCache = {},        -- [unitID] = unitDefID (lazy-populated, cleared on unit death/give)
	unitTeamCache = {},       -- [unitID] = teamID (lazy-populated, cleared on unit give)
	unitDefLayer = {},        -- [unitDefID] = layer (0=structure,1=ground,2=air,3=commander) — built once at init
	instanceData = nil,       -- Pre-allocated flat float array (MAX_INSTANCES * INSTANCE_STEP)
	sortKeys = {},            -- [unitID] = sortKey (layer*1e6 + x+z) for stable position-based draw order
	cachedPosX = {},          -- [unitID] = worldX (cached from sort pass, reused in processUnit)
	cachedPosZ = {},          -- [unitID] = worldZ (cached from sort pass, reused in processUnit)
	_buildingBuf = {},        -- Reused buffer: immobile building IDs for current frame
	_mobileBuf = {},          -- Reused buffer: mobile unit IDs for current frame
	_bldgSortedCache = {},    -- Cached sorted building IDs (re-sorted only when set changes)
	_lastBldgHash = 0,        -- Additive hash of building ID set for change detection
	_lastBldgCount = 0,       -- Count of buildings for change detection
	_prevBuildingLen = 0,     -- Previous frame building buffer length (for stale-clear)
	_prevMobileLen = 0,       -- Previous frame mobile buffer length (for stale-clear)
}

-- Persistent sort comparator for icon draw order (avoids per-frame closure allocation)
-- Two-level: primary key (layer + Z depth), tiebreaker is unitID (always unique → deterministic)
local gl4IconSortKeys = gl4Icons.sortKeys
local function gl4IconSortCmp(a, b)
	local ka, kb = gl4IconSortKeys[a], gl4IconSortKeys[b]
	if ka ~= kb then return ka < kb end
	return a < b
end

-- Cached factors for WorldToPipCoords (performance optimization)
-- Declared here (before GL4 primitive code) so GL4 helper functions can close over them.
local wtp = { scaleX = 1, scaleZ = 1, offsetX = 0, offsetZ = 0 }

-- GL4 Primitive Rendering (explosions, projectiles, beams, command lines)
local gl4Prim = {
	LINE_STEP = 6,            -- floats per vertex: worldX, worldZ, r, g, b, a
	LINE_MAX = 16384,         -- max vertices (8192 line segments)
	CIRCLE_STEP = 12,         -- floats per instance: 3 x vec4
	CIRCLE_MAX = 2048,        -- max circle instances
	QUAD_STEP = 12,           -- floats per instance: 3 x vec4
	QUAD_MAX = 4096,          -- max quad instances
	enabled = false,
	-- Circles (explosions, plasma, flame, lightning impacts)
	circles = {
		vbo = nil, vao = nil, shader = nil,
		data = nil, count = 0,
		uniformLocs = {},
	},
	-- Quads (missiles, blasters)
	quads = {
		vbo = nil, vao = nil, shader = nil,
		data = nil, count = 0,
		uniformLocs = {},
	},
	-- Lines by width category (each has own VBO/VAO, shared shader)
	glowLines = { vbo = nil, vao = nil, data = nil, count = 0 },   -- thick (beam/lightning glow)
	coreLines = { vbo = nil, vao = nil, data = nil, count = 0 },   -- medium (beam/lightning core)
	normLines = { vbo = nil, vao = nil, data = nil, count = 0 },   -- thin (trails, commands)
	lineShader = nil,
	lineUniformLocs = {},
}

-- Consolidated cache tables
local cache = {
	noModelFeatures = {},
	xsizes = {},
	zsizes = {},
	unitIcon = {},
	unitPic = {},  -- Unit picture paths for detailed view
	isFactory = {},
	radiusSqs = {},
	featureRadiusSqs = {},
	projectileSizes = {},
	explosions = {},
	laserBeams = {},
	iconShatters = {},
	seismicPings = {},
	-- Transport-related properties
	isTransport = {},
	transportCapacity = {},
	transportSize = {},
	transportMass = {},
	minTransportSize = {},
	cantBeTransported = {},
	unitMass = {},
	unitTransportSize = {},
	-- Movement properties
	canMove = {},
	canFly = {},
	isBuilding = {},
	isCommander = {},
	unitCost = {},
	-- Combat properties
	canAttack = {},
	maxIconShatters = 20,
	weaponIsLaser = {},
	weaponIsBlaster = {},
	weaponIsPlasma = {},
	weaponIsMissile = {},
	weaponIsStarburst = {},
	weaponIsLightning = {},
	weaponIsFlame = {},
	flameLifetime = {},   -- [wDefID] = seconds, estimated particle lifetime for flame weapons
	flameBirthTime = {},  -- [pID] = gameTime, when we first saw this flame particle
	flameSeeds = {},      -- [pID] = {offX, offZ, baseSize, v1, v2, v3} — stable per-particle variation
	weaponIsBomb = {},
	weaponIsParalyze = {},
	weaponIsAA = {},
	weaponIsJuno = {},
	weaponIsTorpedo = {},
	missileTrails = {},  -- Stores trail positions for missiles {[pID] = {positions = {{x,z,time},...}, lastUpdate = time}}
	missileColors = {},  -- [wDefID] = {bodyR,bodyG,bodyB, noseR,noseG,noseB, finR,finG,finB, exhR,exhG,exhB}
	plasmaTrails = {},   -- Stores trail positions for plasma/artillery projectiles (simpler, shorter trails)
	weaponPlasmaTrailColor = {},  -- {r, g, b} per wDefID, based on cegTag
	weaponSize = {},
	weaponRange = {},
	weaponThickness = {},
	weaponColor = {},
	weaponExplosionRadius = {},
	weaponSkipExplosion = {},
}

local gameTime = 0 -- Accumulated game time (pauses when game is paused)
local wallClockTime = 0 -- Wall-clock time (always advances, even when paused)

-- Pre-defined descending sort comparator (avoids per-call closure allocation)
local function sortDescending(a, b) return a > b end

-- Cached takeable teams (leaderless, alive, non-AI) — invalidated by PlayerChanged
local cachedTakeableTeams = nil  -- nil = needs rebuild

-- Performance timers: per-section timing for the expensive render pass
-- Smoothed with exponential moving average for stable debug readout
local perfTimers = {
	units = 0,
	features = 0,
	projectiles = 0,
	explosions = 0,
	icons = 0,
	commands = 0,
	shatters = 0,
	total = 0,
	lastEchoTime = 0,
	itemCount = 0,  -- total items rendered this frame (units+projectiles+explosions+decals)
	-- Icon sub-timers (breakdown of the icons phase)
	icGhost = 0,      -- ghost building pass
	icKeysort = 0,    -- sort key computation + building/mobile split
	icSort = 0,       -- table.sort calls
	icProcess = 0,    -- processUnit loop
	icProcBldg = 0,   -- processUnit: buildings sub-loop
	icProcMobile = 0, -- processUnit: mobile units sub-loop
	icProcBldgN = 0,  -- count of buildings processed
	icProcMobileN = 0,-- count of mobile units processed
	icUploadDraw = 0, -- VBO upload + shader setup + draw calls
	icUnitpics = 0,   -- unitpic overlay rendering
}
local PERF_SMOOTH = 0.1  -- EMA smoothing factor

-- Dynamic detail caps: reduce max explosions/projectiles when workload is high
-- Returns adjusted cap based on last frame's item count
local function GetDetailCap(baseCap)
	local items = perfTimers.itemCount
	if items < 400 then return baseCap end
	if items < 800 then return math.floor(baseCap * 0.7) end
	if items < 1200 then return math.floor(baseCap * 0.5) end
	return math.floor(baseCap * 0.3)
end

-- Damage flash effect: units briefly flash red when taking damage
-- damageFlash[unitID] = {time = gameTime, intensity = clamp(damage/maxHP)}
-- Fade duration in seconds, intensity proportional to damage relative to max health
local damageFlash = {}
local DAMAGE_FLASH_DURATION = 0.4  -- seconds to fade from full red to normal

-- Self-destruct tracking: event-driven set of units with active self-destruct countdown
-- Maintained via UnitCommand callin + periodic refresh (every ~30 frames)
-- selfDUnits[unitID] = true when unit has an active self-destruct countdown
local selfDUnits = {}
local selfDRefreshCounter = 0
local SELFD_REFRESH_INTERVAL = 30  -- frames between full refresh scans

-- Command FX: brief fading command lines when orders are given (like Commands FX widget)
-- Each entry: {unitID, targetX, targetZ, cmdID, time, unitX, unitZ}
local commandFX = {
	list = {},       -- array of active command FX entries
	count = 0,
	lastTarget = {}, -- [unitID] = {x, z, time} — last command FX target per unit for chaining
	newUnits = {},   -- [unitID] = gameTime — tracks recently finished units to suppress rally commands
	MAX = 300,       -- max simultaneous FX entries
}

local unitOutlineList = nil
local radarDotList = nil
local seismicPingDlists = {
	outerArcs = {},
	middleArcs = {},
	innerArcs = {},
	centerCircle = nil,
	outerOutlines = {},
	middleOutlines = {},
	innerOutlines = {},
}
local gameHasStarted
local gaiaTeamID = Spring.GetGaiaTeamID()
local gaiaAllyTeamID = select(6, Spring.GetTeamInfo(gaiaTeamID))

-- Build AI team lookup tables at load time
-- aiTeams: all AI-controlled teams (for optional hiding)
-- scavRaptorTeams: scavenger/raptor AI teams (always hidden regardless of setting)
local aiTeams = {}
local scavRaptorTeams = {}
do
	local teamList = Spring.GetTeamList()
	for i = 1, #teamList do
		local teamID = teamList[i]
		local _, _, _, isAI = Spring.GetTeamInfo(teamID, false)
		if isAI then
			aiTeams[teamID] = true
			local luaAI = Spring.GetTeamLuaAI(teamID) or ''
			if string.find(luaAI, 'Scavenger') or string.find(luaAI, 'Raptor') then
				scavRaptorTeams[teamID] = true
			end
		end
	end
end

-- Command colors
local cmdColors = {
	unknown			= {1.0, 1.0, 1.0, 0.7},
	[CMD.STOP]		= {0.0, 0.0, 0.0, 0.7},
	[CMD.WAIT]		= {0.5, 0.5, 0.5, 0.7},
	-- [CMD.BUILD]		= {0.0, 1.0, 0.0, 0.3}, -- BUILD handled by specific build commands
	[CMD.MOVE]		= {0.5, 1.0, 0.5, 0.3},
	[CMD.ATTACK]	= {1.0, 0.2, 0.2, 0.3},
	[CMD.FIGHT]		= {1.0, 0.2, 1.0, 0.3},
	[CMD.GUARD]		= {0.6, 1.0, 1.0, 0.3},
	[CMD.PATROL]	= {0.2, 0.5, 1.0, 0.3},
	[CMD.CAPTURE]	= {1.0, 1.0, 0.3, 0.6},
	[CMD.REPAIR]	= {1.0, 0.9, 0.2, 0.6},
	[CMD.RECLAIM]	= {0.5, 1.0, 0.4, 0.3},
	[CMD.RESTORE]	= {0.0, 1.0, 0.0, 0.3},
	[CMD.RESURRECT]	= {0.9, 0.5, 1.0, 0.5},
	[CMD.LOAD_UNITS]= {0.4, 0.9, 0.9, 0.7},
	[CMD.UNLOAD_UNIT] = {1.0, 0.8, 0.0, 0.7},
	[CMD.UNLOAD_UNITS]= {1.0, 0.8, 0.0, 0.7},
	[GameCMD.UNIT_SET_TARGET_NO_GROUND] = {1.0, 0.75, 0.0, 0.3},
}

-- Command ID to cursor name mapping
local cmdCursors = {
	[CMD.ATTACK] = 'Attack',
	[CMD.GUARD] = 'Guard',
	[CMD.REPAIR] = 'Repair',
	[CMD.RECLAIM] = 'Reclaim',
	[CMD.CAPTURE] = 'Capture',
	[CMD.RESURRECT] = 'Resurrect',
	[CMD.RESTORE] = 'Restore',
	[CMD.PATROL] = 'Patrol',
	[CMD.FIGHT] = 'Fight',
	[CMD.LOAD_UNITS] = 'Load units',
	[CMD.UNLOAD_UNIT] = 'Unload units',
	[CMD.UNLOAD_UNITS] = 'Unload units',
	[CMD.DGUN] = 'Attack',	-- DGun cursor doesnt work, use Attack instead
	[GameCMD.UNIT_SET_TARGET_NO_GROUND] = 'settarget',
}



-- What commands are issued at a position or unit/feature ID (Only used by GetUnitPosition)
local positionCmds = {
	[CMD.MOVE]=true,		[CMD.ATTACK]=true,		[CMD.RECLAIM]=true,		[CMD.RESTORE]=true,		[CMD.RESURRECT]=true,
	[CMD.PATROL]=true,		[CMD.CAPTURE]=true,		[CMD.FIGHT]=true, 		[CMD.DGUN]=true,		[38521]=true, -- jump
	[CMD.UNLOAD_UNIT]=true,	[CMD.UNLOAD_UNITS]=true,[CMD.LOAD_UNITS]=true,	[CMD.GUARD]=true,
}


----------------------------------------------------------------------------------------------------
-- Speedups
----------------------------------------------------------------------------------------------------

-- GL constants
local GL_LINE_SMOOTH = 0x0B20  -- OpenGL GL_LINE_SMOOTH enum value
local glConst = {
	LINE_STRIP = GL.LINE_STRIP,
	LINES = GL.LINES,
	TRIANGLES = GL.TRIANGLES,
	TRIANGLE_FAN = GL.TRIANGLE_FAN,
	QUADS = GL.QUADS,
	LINE_LOOP = GL.LINE_LOOP,
}

-- GL function speedups
local glFunc = {
	Color = gl.Color,
	TexCoord = gl.TexCoord,
	Texture = gl.Texture,
	TexRect = gl.TexRect,
	Vertex = gl.Vertex,
	BeginEnd = gl.BeginEnd,
	PushMatrix = gl.PushMatrix,
	PopMatrix = gl.PopMatrix,
	Translate = gl.Translate,
	Rotate = gl.Rotate,
	Scale = gl.Scale,
	CallList = gl.CallList,
	LineWidth = gl.LineWidth,
}

-- Spring function speedups
local spFunc = {
	GetGroundHeight = Spring.GetGroundHeight,
	GetUnitsInRectangle = Spring.GetUnitsInRectangle,
	GetUnitPosition = Spring.GetUnitPosition,
	GetUnitBasePosition = Spring.GetUnitBasePosition,
	GetUnitTeam = Spring.GetUnitTeam,
	GetUnitDefID = Spring.GetUnitDefID,
	GetTeamInfo = Spring.GetTeamInfo,
	IsPosInLos = Spring.IsPosInLos,
	IsPosInRadar = Spring.IsPosInRadar,
	GetUnitLosState = Spring.GetUnitLosState,
	GetFeatureDefID = Spring.GetFeatureDefID,
	GetFeatureDirection = Spring.GetFeatureDirection,
	GetFeaturePosition = Spring.GetFeaturePosition,
	GetFeatureTeam = Spring.GetFeatureTeam,
	GetFeaturesInRectangle = Spring.GetFeaturesInRectangle,
	IsUnitSelected = Spring.IsUnitSelected,
	GetUnitHealth = Spring.GetUnitHealth,
	GetMouseState = Spring.GetMouseState,
	GetProjectilesInRectangle = Spring.GetProjectilesInRectangle,
	GetProjectilePosition = Spring.GetProjectilePosition,
	GetProjectileDefID = Spring.GetProjectileDefID,
	GetProjectileTarget = Spring.GetProjectileTarget,
	GetProjectileOwnerID = Spring.GetProjectileOwnerID,
	GetProjectileVelocity = Spring.GetProjectileVelocity,
	GetUnitCommands = Spring.GetUnitCommands,
	GetPlayerInfo = Spring.GetPlayerInfo,
	GetUnitIsStunned = Spring.GetUnitIsStunned,
	GetTeamAllyTeamID = Spring.GetTeamAllyTeamID,
	GetUnitSelfDTime = Spring.GetUnitSelfDTime,
}

local success, mapinfo = pcall(VFS.Include,"mapinfo.lua")
local voidWater = false
if success and mapinfo then
	voidWater = mapinfo.voidwater
end
-- Map/game constants
local mapInfo = {
	rad2deg = 180 / math.pi,
	atan2 = math.atan2,
	mapSizeX = Game.mapSizeX,
	mapSizeZ = Game.mapSizeZ,
	minGroundHeight = nil,
	maxGroundHeight = nil,
	hasWater = false,
	isLava = false,
	voidWater = voidWater
}
mapInfo.minGroundHeight, mapInfo.maxGroundHeight = Spring.GetGroundExtremes()
local waterIsLava = Spring.GetModOptions().map_waterislava
mapInfo.isLava = Spring.Lava.isLavaMap or (waterIsLava and waterIsLava ~= 0 and waterIsLava ~= "0")
mapInfo.hasWater = mapInfo.minGroundHeight < 0 or mapInfo.isLava
mapInfo.dynamicWaterLevel = nil  -- current water/lava level (nil = static sea level = 0)
mapInfo.lastCheckedWaterLevel = nil  -- for change detection

-- Eagerly read lava level if available (avoids wrong first R2T render on lava maps)
if mapInfo.isLava or mapInfo.hasWater then
	local initLavaLevel = Spring.GetGameRulesParam("lavaLevel")
	if initLavaLevel and initLavaLevel ~= -99999 then
		mapInfo.dynamicWaterLevel = initLavaLevel
	end
end




----------------------------------------------------------------------------------------------------

-- Buttons (Must be declared after variables)
local buttons = {
	{
		texture = 'LuaUI/Images/pip/PipCopy.png',
		tooltipKey = 'ui.pip.copy',
		command = 'pip_copy',
		shortcut = 'Alt + Q',
		OnPress = function()
				local sizex, sizez = Spring.GetWindowGeometry()
				local _, pos = Spring.TraceScreenRay(sizex/2, sizez/2, true)
				if pos and pos[2] > -10000 then
					-- Set PIP camera to main camera position with rounding to match switch behavior
					local copiedX = math.floor(pos[1] + 0.5)
					local copiedZ = math.floor(pos[3] + 0.5)
					-- Set target for smooth transition (don't set cameraState.wcx/cameraState.wcz directly)
					cameraState.targetWcx, cameraState.targetWcz = copiedX, copiedZ
					miscState.isSwitchingViews = true -- Enable fast transition for pip_copy
					RecalculateWorldCoordinates()
					RecalculateGroundTextureCoordinates()
					-- Disable tracking when copying camera
					interactionState.areTracking = nil
					interactionState.trackingPlayerID = nil
					-- Store the copied position in backup so switching maintains same position
					miscState.backupTracking = {
						tracking = nil,
						trackingPlayerID = nil,
						camX = copiedX,
						camZ = copiedZ
					}
				end
			end
	},
	{
		texture = 'LuaUI/Images/pip/PipSwitch.png',
		tooltipKey = 'ui.pip.switch',
		command = 'pip_switch',
		shortcut = 'Shift + Q',
		OnPress = function()
				local sizex, sizez = Spring.GetWindowGeometry()
				local _, pos = Spring.TraceScreenRay(sizex/2, sizez/2, true)
				if pos and pos[2] > -10000 then
					-- Always read the current main camera position
					local mainCamX = math.floor(pos[1] + 0.5)
					local mainCamZ = math.floor(pos[3] + 0.5)

					-- Calculate the actual center of tracked units (if tracking) for main view camera
					local pipCameraTargetX, pipCameraTargetZ = math.floor(cameraState.wcx + 0.5), math.floor(cameraState.wcz + 0.5)
					if config.switchInheritsTracking and interactionState.areTracking and #interactionState.areTracking > 0 then
						-- Calculate average position of tracked units (not margin-corrected camera)
						local uCount = 0
						local ax, az = 0, 0
						for i = 1, #interactionState.areTracking do
							local uID = interactionState.areTracking[i]
							local ux, uy, uz = spFunc.GetUnitBasePosition(uID)
							if ux then
								ax = ax + ux
								az = az + uz
								uCount = uCount + 1
							end
						end
						if uCount > 0 then
							pipCameraTargetX = math.floor((ax / uCount) + 0.5)
							pipCameraTargetZ = math.floor((az / uCount) + 0.5)
						end

						-- First untrack anything in main view
						Spring.SendCommands("track")
						-- Then track the PIP units in main view
						for i = 1, #interactionState.areTracking do
							Spring.SendCommands("track " .. interactionState.areTracking[i])
						end
					else
						-- If not tracking in PIP or feature disabled, untrack in main view
						Spring.SendCommands("track")
					end

				-- Swap tracking state: current PIP tracking <-> backup
				-- This ensures toggling switch restores previous tracking states
				local currentPipTracking = interactionState.areTracking
				local currentPipTrackingPlayerID = interactionState.trackingPlayerID
				local currentPipCamX = pipCameraTargetX
				local currentPipCamZ = pipCameraTargetZ

				-- Restore tracking from backup to PIP view (or set to nil if no backup)
				if miscState.backupTracking then
					interactionState.areTracking = miscState.backupTracking.tracking
					interactionState.trackingPlayerID = miscState.backupTracking.trackingPlayerID
				else
					interactionState.areTracking = nil
					interactionState.trackingPlayerID = nil
				end

				-- Save current PIP state to backup for next switch
				miscState.backupTracking = {
					tracking = currentPipTracking,
					trackingPlayerID = currentPipTrackingPlayerID,
					camX = currentPipCamX,
					camZ = currentPipCamZ
				}				-- Switch camera positions - use rounded coordinates
				Spring.SetCameraTarget(pipCameraTargetX, 0, pipCameraTargetZ, config.switchTransitionTime)
				-- Set PIP camera target for smooth transition (don't set cameraState.wcx/cameraState.wcz directly)
				cameraState.targetWcx, cameraState.targetWcz = mainCamX, mainCamZ
				miscState.isSwitchingViews = true -- Enable fast transition for pip_switch
				RecalculateWorldCoordinates()
				RecalculateGroundTextureCoordinates()

					-- If feature is disabled, ensure main camera is not tracking
					if not config.switchInheritsTracking then
						Spring.SendCommands("track")
					end
				end
			end
	},
	{
		texture = 'LuaUI/Images/pip/PipT.png',
		tooltipKey = 'ui.pip.track',
		tooltipActiveKey = 'ui.pip.untrack',
		command = 'pip_track',
		shortcut = 'Alt + A',
		OnPress = function()
			local selectedUnits = Spring.GetSelectedUnits()
			if #selectedUnits > 0 then
				-- Add selected units to tracking (or start tracking if not already)
				if interactionState.areTracking then
					-- Merge with existing tracked units using pooled tables
					-- Clear temp set pool
					for k in pairs(pools.trackingTempSet) do
						pools.trackingTempSet[k] = nil
					end
					for _, unitID in ipairs(interactionState.areTracking) do
						pools.trackingTempSet[unitID] = true
					end
					-- Add new units
					for _, unitID in ipairs(selectedUnits) do
						pools.trackingTempSet[unitID] = true
					end
					-- Convert back to array using pooled array
					for i = #pools.trackingMerge, 1, -1 do
						pools.trackingMerge[i] = nil
					end
					for unitID in pairs(pools.trackingTempSet) do
						pools.trackingMerge[#pools.trackingMerge + 1] = unitID
					end
					interactionState.areTracking = pools.trackingMerge
					-- Create new pool for next merge
					pools.trackingMerge = {}
				else
					-- Create a copy of selectedUnits to avoid reference issues
					local trackingUnits = {}
					for i = 1, #selectedUnits do
						trackingUnits[i] = selectedUnits[i]
					end
					interactionState.areTracking = trackingUnits
				end
				-- Disable zoom-to-cursor when tracking is enabled
				cameraState.zoomToCursorActive = false
			else
				-- No selection: clear tracking
				interactionState.areTracking = nil
			end
		end
	},
	{
		texture = 'LuaUI/Images/pip/PipView.png',
		tooltipKey = 'ui.pip.view',
		tooltipActiveKey = 'ui.pip.unview',
		command = 'pip_view',
		OnPress = function()
			state.losViewEnabled = not state.losViewEnabled
			if state.losViewEnabled then
				-- Store the current allyteam when enabling LOS view
				state.losViewAllyTeam = Spring.GetMyAllyTeamID()
				-- Immediately scan enemy buildings the viewed allyteam knows about
				-- Only include buildings the allyteam has seen (LOS_INLOS or LOS_PREVLOS)
				if cameraState.mySpecState then
					for k in pairs(ghostBuildings) do ghostBuildings[k] = nil end
					local scanAllyTeam = state.losViewAllyTeam
					local allUnits = Spring.GetAllUnits()
					for _, uID in ipairs(allUnits) do
						local defID = Spring.GetUnitDefID(uID)
						if defID and cache.isBuilding[defID] then
							local uTeam = Spring.GetUnitTeam(uID)
							local uAllyTeam = Spring.GetTeamAllyTeamID(uTeam)
							if uAllyTeam ~= scanAllyTeam then
								-- Only ghost buildings the viewed allyteam has ever seen
								local losBits = Spring.GetUnitLosState(uID, scanAllyTeam, true)
								if losBits and (losBits % 2 >= 1 or losBits % 8 >= 4) then
									local x, _, z = Spring.GetUnitBasePosition(uID)
									if x then
										ghostBuildings[uID] = { defID = defID, x = x, z = z, teamID = uTeam }
									end
								end
							end
						end
					end
				end
			else
				state.losViewAllyTeam = nil
				-- Clear ghost buildings when disabling LOS view as spectator
				-- (spectators with full view see everything, ghosts are meaningless)
				if cameraState.mySpecState then
					for k in pairs(ghostBuildings) do ghostBuildings[k] = nil end
				end
			end
			pipR2T.losNeedsUpdate = true
			pipR2T.frameNeedsUpdate = true
			pipR2T.unitsNeedsUpdate = true
			pipR2T.contentNeedsUpdate = true
		end
	},
	{
		texture = 'LuaUI/Images/pip/PipCam.png',
		tooltipKey = 'ui.pip.camera',
		tooltipActiveKey = 'ui.pip.uncamera',
		command = 'pip_trackplayer',
		OnPress = function()
			if interactionState.trackingPlayerID then
				-- Stop tracking player
				interactionState.trackingPlayerID = nil
				pipR2T.frameNeedsUpdate = true
			else
				local _, _, isSpec = spFunc.GetPlayerInfo(Spring.GetMyPlayerID(), false)
				
				if isSpec then
					-- Spectator: Track team leader (keep existing behavior)
					local myTeamID = Spring.GetMyTeamID()
					local targetPlayerID = nil

					-- Get the team leader's player ID from team info
					local _, leaderPlayerID = spFunc.GetTeamInfo(myTeamID, false)

					-- Verify this player is active and not self
					if leaderPlayerID then
						local myPlayerID = Spring.GetMyPlayerID()
						if leaderPlayerID ~= myPlayerID then
							local name, active = spFunc.GetPlayerInfo(leaderPlayerID, false)
							if name and active then
								targetPlayerID = leaderPlayerID
							end
						end
					end

					if targetPlayerID then
						interactionState.trackingPlayerID = targetPlayerID
						-- Clear unit tracking when starting player tracking
						interactionState.areTracking = nil
						pipR2T.frameNeedsUpdate = true
						pipR2T.contentNeedsUpdate = true
					end
				else
					-- Non-spectator: Cycle through alive teammates
					local teammates = GetAliveTeammates()
					if #teammates > 0 then
						-- Find current index or start at beginning
						local currentIndex = 0
						for i, playerID in ipairs(teammates) do
							if playerID == interactionState.lastTrackedTeammate then
								currentIndex = i
								break
							end
						end
						
						-- Cycle to next teammate
						currentIndex = (currentIndex % #teammates) + 1
						local targetPlayerID = teammates[currentIndex]
						
						-- Double-check we're not tracking ourselves
						if targetPlayerID ~= Spring.GetMyPlayerID() then
							interactionState.trackingPlayerID = targetPlayerID
							interactionState.lastTrackedTeammate = targetPlayerID
							-- Clear unit tracking when starting player tracking
							interactionState.areTracking = nil
							pipR2T.frameNeedsUpdate = true
							pipR2T.contentNeedsUpdate = true
						end
					end
				end
			end
		end
	},
	{
		texture = 'LuaUI/Images/pip/PipTV.png',
		tooltipKey = 'ui.pip.tv',
		tooltipActiveKey = 'ui.pip.untv',
		command = 'pip_tv',
		OnPress = function()
			miscState.tvEnabled = not miscState.tvEnabled
			if miscState.tvEnabled then
				-- Save current camera and activate TV camera
				pipTV.camera.savedWcx = cameraState.targetWcx
				pipTV.camera.savedWcz = cameraState.targetWcz
				pipTV.camera.savedZoom = cameraState.targetZoom
				pipTV.camera.active = true
				pipTV.director.idle = true
				pipTV.director.lastOverviewTime = os.clock()
				-- Register in shared focus table for cross-PIP coordination
				if not WG.pipTVFocus then WG.pipTVFocus = {} end
				WG.pipTVFocus[pipNumber] = { x = cameraState.targetWcx, z = cameraState.targetWcz }
				-- Disable activity focus and player tracking when TV mode is on
				if miscState.activityFocusActive then
					miscState.activityFocusActive = false
				end
				interactionState.trackingPlayerID = nil
				interactionState.areTracking = nil
			else
				-- Restore camera
				if pipTV.camera.savedWcx then
					cameraState.targetWcx = pipTV.camera.savedWcx
					cameraState.targetWcz = pipTV.camera.savedWcz
					cameraState.targetZoom = pipTV.camera.savedZoom
				end
				pipTV.camera.active = false
				-- Unregister from shared focus table
				if WG.pipTVFocus then
					WG.pipTVFocus[pipNumber] = nil
					if not next(WG.pipTVFocus) then WG.pipTVFocus = nil end
				end
			end
			pipR2T.frameNeedsUpdate = true
		end
	},
	{
		texture = 'LuaUI/Images/pip/PipActivity.png',
		tooltipKey = 'ui.pip.activity',
		tooltipActiveKey = 'ui.pip.unactivity',
		command = 'pip_activity',
		OnPress = function()
			miscState.activityFocusEnabled = not miscState.activityFocusEnabled
			if not miscState.activityFocusEnabled and miscState.activityFocusActive then
				-- Immediately restore camera when disabling
				if miscState.activityFocusSavedWcx then
					cameraState.targetWcx = miscState.activityFocusSavedWcx
					cameraState.targetWcz = miscState.activityFocusSavedWcz
					cameraState.targetZoom = miscState.activityFocusSavedZoom
				end
				miscState.activityFocusActive = false
			end
			pipR2T.frameNeedsUpdate = true
		end
	},
	{
		texture = 'LuaUI/Images/pip/PipMove.png',
		tooltipKey = 'ui.pip.move',  -- No command, no shortcut
		command = nil,
		OnPress = function() 
			interactionState.areDragging = true
		end
	},
}

-- Consolidated shader table (LOS overlay, minimap shading, water overlay)
local shaders = {
	-- LOS overlay: outputs darkening amount for reverse-subtract compositing
	-- Matches engine's additive-bias method: result = ground - darkening
	los = nil,
	losCode = {
		vertex = [[
			varying vec2 texCoord;
			void main() {
				texCoord = gl_MultiTexCoord0.st;
				gl_Position = gl_Vertex;
			}
		]],
		fragment = [[
			uniform sampler2D losTex;
			uniform sampler2D radarTex;
			uniform float losScale;
			uniform float showRadar;
			varying vec2 texCoord;
			void main() {
				// Red channel of LOS texture: LOS (0.2-1.0 = in LOS, <0.2 = not in LOS)
				float losValue = texture2D(losTex, texCoord).r;
				// Red channel of radar texture: Radar coverage
				float radarValue = texture2D(radarTex, texCoord).r;
				
				// Engine-like additive-bias: output darkening amount
				// (0 = no change, positive = darken by that amount)
				// Composited via GL_FUNC_REVERSE_SUBTRACT: result = ground - darken
				float darken = (1.0 - losValue) * losScale * 0.28;
				
				// Extra darkening for areas with neither LOS nor radar
				if (showRadar > 0.5 && losValue < 0.2 && radarValue < 0.2) {
					darken = darken + losScale * 0.1;
				}

				gl_FragColor = vec4(darken, darken, darken, 1.0);
			}
		]],
		uniformFloat = {
			losScale = config.losOverlayOpacity,  -- Controls darkening intensity
			showRadar = config.showLosRadar and 1.0 or 0.0,
		},
		uniformInt = {
			losTex = 0,
			radarTex = 1,
		},
	},
	-- Minimap shading: composites minimap + shading in a single pass (matches engine MiniMapFragProg.glsl)
	minimapShading = nil,
	minimapShadingCode = {
		vertex = [[
			varying vec2 texCoord;
			void main() {
				texCoord = gl_MultiTexCoord0.st;
				gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
			}
		]],
		fragment = [[
			uniform sampler2D minimapTex;
			uniform sampler2D shadingTex;
			varying vec2 texCoord;
			void main() {
				vec4 minimapColor = texture2D(minimapTex, texCoord, -2.0);
				vec4 shadingColor = texture2D(shadingTex, texCoord);
				gl_FragColor = vec4(minimapColor.rgb * shadingColor.rgb, 1.0);
			}
		]],
		uniformInt = {
			minimapTex = 0,
			shadingTex = 1,
		},
	},
	-- GL4 instanced decal overlay: GPU computes alpha fade, single draw call
	-- Vertex reads per-instance decal data, geometry shader expands to rotated textured quad
	-- Fragment converts atlas alpha to darkening value matching world shader appearance
	-- Used with GL_MIN blending to avoid overlap edge artifacts
	decal = nil,
	decalCode = {
		vertex = [[
#version 330
// Per-instance decal data (one point = one decal)
layout(location = 0) in vec4 posRot;        // worldX, worldZ, rotation (rad), maxalpha
layout(location = 1) in vec4 sizeAlpha;     // halfLengthX, halfWidthZ, alphastart, alphadecay
layout(location = 2) in vec4 uvCoords;      // p, q, s, t (atlas UV rect)
layout(location = 3) in vec4 spawnParams;   // spawnframe, 0, 0, 0

uniform float gameFrame;
uniform vec2 invMapSize;  // 2/mapSizeX, 2/mapSizeZ (factor of 2 because NDC spans -1..1)

out float v_alpha;
out vec4 v_uv;        // p, q, s, t
out vec2 v_halfWorld; // half-size in WORLD units (rotation must happen before NDC conversion)
out float v_cosR;
out float v_sinR;

void main() {
	// Compute current alpha on GPU (same formula as decals widget)
	float lifetonow = gameFrame - spawnParams.x;
	float currentAlpha = sizeAlpha.z - lifetonow * sizeAlpha.w;
	currentAlpha = clamp(currentAlpha, 0.0, posRot.w);

	// Skip expired/invisible decals
	if (currentAlpha < 0.01) {
		v_alpha = 0.0;
		gl_Position = vec4(2.0, 2.0, 0.0, 1.0);  // off-screen
		return;
	}

	v_alpha = currentAlpha;
	v_uv = uvCoords;

	// World position to NDC (-1..1)
	vec2 ndc = posRot.xy * invMapSize - 1.0;
	gl_Position = vec4(ndc, 0.0, 1.0);

	// Pass world-space half-sizes; geometry shader rotates THEN converts to NDC
	v_halfWorld = sizeAlpha.xy;

	v_cosR = cos(posRot.z);
	v_sinR = sin(posRot.z);
}
		]],
		geometry = [[
#version 330
layout(points) in;
layout(triangle_strip, max_vertices = 4) out;

uniform vec2 invMapSize;

in float v_alpha[];
in vec4 v_uv[];
in vec2 v_halfWorld[];
in float v_cosR[];
in float v_sinR[];

out vec2 f_texCoord;
out float f_alpha;

void main() {
	float alpha = v_alpha[0];
	if (alpha < 0.01) return;  // culled in vertex shader

	vec4 c = gl_in[0].gl_Position;
	vec2 hs = v_halfWorld[0];  // world-space half-sizes
	vec4 uv = v_uv[0];  // p, q, s, t
	float ca = v_cosR[0];
	float sa = v_sinR[0];
	f_alpha = alpha;

	// Rotate in world space (equal X/Z scale), THEN convert to NDC per-component.
	// Component-wise multiply (*invMapSize) applies correct scale to each axis,
	// preventing elliptical distortion on non-square maps.
	vec2 dx = vec2(ca, sa) * hs.x * invMapSize;
	vec2 dy = vec2(-sa, ca) * hs.y * invMapSize;

	// BL: UV(p, s)
	gl_Position = vec4(c.xy - dx - dy, 0.0, 1.0);
	f_texCoord = vec2(uv.x, uv.z);
	EmitVertex();
	// BR: UV(q, s)
	gl_Position = vec4(c.xy + dx - dy, 0.0, 1.0);
	f_texCoord = vec2(uv.y, uv.z);
	EmitVertex();
	// TL: UV(p, t)
	gl_Position = vec4(c.xy - dx + dy, 0.0, 1.0);
	f_texCoord = vec2(uv.x, uv.w);
	EmitVertex();
	// TR: UV(q, t)
	gl_Position = vec4(c.xy + dx + dy, 0.0, 1.0);
	f_texCoord = vec2(uv.y, uv.w);
	EmitVertex();

	EndPrimitive();
}
		]],
		fragment = [[
#version 330
uniform sampler2D atlasTex;
in vec2 f_texCoord;
in float f_alpha;
out vec4 fragColor;

void main() {
	vec4 tex = texture(atlasTex, f_texCoord);
	// Square alpha to match world decal shader (soft edge falloff)
	float a = tex.a * tex.a * 0.999 * f_alpha;
	// Brighten scar color toward mid-gray (world does tex * minimap * 2 + lighting)
	vec3 scarColor = mix(tex.rgb, vec3(0.5), 0.35);
	// Lerp from white toward scar color
	vec3 result = mix(vec3(1.0), scarColor, a);
	fragColor = vec4(result, 1.0);
}
		]],
		uniformInt = {
			atlasTex = 0,
		},
	},
	-- Water overlay: renders water/lava tinting based on heightmap
	water = nil,
	waterCode = {
		vertex = [[
			varying vec2 texCoord;
			void main() {
				texCoord = gl_MultiTexCoord0.st;
				gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
			}
		]],
		fragment = [[
			uniform sampler2D heightTex;
			uniform vec4 waterColor;
			uniform float waterLevel;  // water/lava surface level in elmos (world height units)
			varying vec2 texCoord;
			void main() {
				float height = texture2D(heightTex, texCoord).r;  // raw height in elmos
				
				// Depth below water/lava surface (positive = submerged)
				float depth = waterLevel - height;
				
				// Smooth transition over 10 elmos depth for gradual coverage
				float waterAmount = clamp(depth / 10.0, 0.0, 1.0);
				
				// Use waterColor.a to control overall intensity:
				// Low alpha (0.5 = normal water) gets subtle tinting via * 0.05
				// High alpha (1.0 = void/lava) gets strong coverage
				float alphaScale = mix(0.05, 1.0, waterColor.a);
				gl_FragColor = vec4(waterColor.rgb, waterAmount * alphaScale);
			}
		]],
		uniformInt = {
			heightTex = 0,
		},
		uniformFloat = {
			waterColor = {0, 0.04, 0.25, 0.5},
			waterLevel = 0,
		},
	},
}

local teamColors = {}
local teamAllyTeamCache = {}  -- teamID -> allyTeamID mapping (avoids per-unit GetTeamInfo calls)
local teamList = Spring.GetTeamList()
for i = 1, #teamList do
	local tID = teamList[i]
	teamColors[tID] = {Spring.GetTeamColor(tID)}
	teamAllyTeamCache[tID] = select(6, Spring.GetTeamInfo(tID, false))
end

----------------------------------------------------------------------------------------------------
-- GL4 Icon Shader + Initialization
----------------------------------------------------------------------------------------------------
-- GLSL shader for instanced icon rendering: points → quads via geometry shader
gl4Icons.shaderCode = {
	vertex = [[
#version 330
layout(location = 0) in vec4 worldPos_size;  // worldX, worldZ, iconSizeScale, flags (bitfield)
layout(location = 1) in vec4 atlasUV;         // u0, v0, u1, v1
layout(location = 2) in vec4 colorFlags;      // r, g, b, wobblePhase + flashFactor*100*7

uniform vec2 wtp_scale;      // worldToPipScaleX, worldToPipScaleZ
uniform vec2 wtp_offset;     // worldToPipOffsetX, worldToPipOffsetZ
uniform vec2 ndcScale;       // 2/fboW, 2/fboH
uniform vec2 rotSC;          // sin(mapRotation), cos(mapRotation)
uniform vec2 rotCenter;      // rotation center in PIP pixels
uniform float iconBaseSize;  // iconRadiusZoomDistMult (PIP pixels)
uniform float gameTime;      // for radar wobble (pauses with game)
uniform float wallClockTime;  // for blink/pulse animations (always advances)
uniform float outlinePass;   // 0 = normal icon draw, 1 = tracked unit outline pass
uniform float healthDarkenMax;  // max darkening fraction for damaged units

out vec4 v_atlasUV;
out vec4 v_color;
out vec2 v_halfSizeNDC;
flat out float v_flash;

void main() {
// Decode bitfield flags: bits 0-4 = status flags, bits 5+ = health percentage (0-100)
// Packed as: healthPct * 32 + bitFlags
float flags = worldPos_size.w;
float bitFlags = mod(flags, 32.0);
float healthPct = floor(flags / 32.0);  // 0-100
float healthFrac = clamp(healthPct / 100.0, 0.0, 1.0);  // 0.0-1.0
float isRadar    = mod(floor(bitFlags      ), 2.0);  // bit 0
float isTakeable = mod(floor(bitFlags / 2.0 ), 2.0);  // bit 1
float isStunned  = mod(floor(bitFlags / 4.0 ), 2.0);  // bit 2
float isTracked  = mod(floor(bitFlags / 8.0 ), 2.0);  // bit 3
float isSelfD    = mod(floor(bitFlags / 16.0), 2.0);  // bit 4

// Decode wobble phase and damage flash from packed value
// wobblePhase in [0, 2pi), packed as: phase + floor(flash*100) * 7.0
float packedW = colorFlags.w;
float flashFactor = floor(packedW / 7.0) / 100.0;
float phase = mod(packedW, 7.0);

// World to PIP pixel coordinates
vec2 pipPos;
pipPos.x = wtp_offset.x + worldPos_size.x * wtp_scale.x;
pipPos.y = wtp_offset.y + worldPos_size.y * wtp_scale.y;

// Radar wobble (only for radar-only icons)
float wobbleAmp = iconBaseSize * 0.3 * isRadar;
pipPos.x += sin(gameTime * 3.0 + phase) * wobbleAmp;
pipPos.y += cos(gameTime * 2.7 + phase * 1.3) * wobbleAmp;

// Map rotation around center
vec2 d = pipPos - rotCenter;
pipPos = rotCenter + vec2(
d.x * rotSC.y - d.y * rotSC.x,
d.x * rotSC.x + d.y * rotSC.y
);

// PIP pixels to NDC
gl_Position = vec4(pipPos * ndcScale - 1.0, 0.0, 1.0);

v_atlasUV = atlasUV;

// Start with base color and alpha
vec3 col = colorFlags.rgb;
float alpha = 1.0 - 0.25 * isRadar;  // radar icons at 75% alpha

// Takeable blink: full on/off cycle at ~1.5Hz
float takeableBlink = step(0.0, sin(wallClockTime * 9.42));  // square wave ~1.5Hz
alpha *= mix(1.0, takeableBlink, isTakeable);

// Health indication: darken damaged units (darkening only, no color shift)
float damage = 1.0 - healthFrac;  // 0=full health, 1=dead
col = max(col - vec3(damage * healthDarkenMax), vec3(0.0));  // flat darken

// Stunned: subtle white-blue tint pulse (~2Hz, gentle)
float stunnedPulse = 0.5 + 0.5 * sin(wallClockTime * 12.57);  // ~2Hz sine
col = mix(col, vec3(0.82, 0.85, 1.0), 0.45 * stunnedPulse * isStunned);

// Self-destruct: red-orange pulsing tint (~3Hz, urgent)
float selfDPulse = 0.55 + 0.45 * sin(wallClockTime * 18.85);  // ~3Hz sine
col = mix(col, vec3(1.0, 0.25, 0.0), 0.7 * selfDPulse * isSelfD);

// Outline pass: tracked icons get white outline, selfD icons get red-orange pulsing outline
if (outlinePass > 0.5) {
  float hasOutline = max(isTracked, isSelfD);
  if (hasOutline < 0.5) {
    alpha = 0.0;  // cull icons without outlines
  } else if (isSelfD > 0.5) {
    // Self-destruct: red-orange pulsing outline
    float selfDOutlinePulse = 0.5 + 0.5 * sin(wallClockTime * 18.85);
    col = vec3(1.0, 0.3, 0.0);
    alpha = 0.4 + 0.4 * selfDOutlinePulse;
  } else {
    col = vec3(1.0, 1.0, 1.0);
    alpha = 0.5;
  }
}

v_color = vec4(col, alpha);
v_flash = flashFactor;
// Expand icon size slightly for outline pass (tracked or selfD units)
float hasOutline = max(isTracked, isSelfD);
float sizeExpand = 1.0 + 0.12 * outlinePass * hasOutline;
v_halfSizeNDC = vec2(iconBaseSize * worldPos_size.z * sizeExpand) * ndcScale;
}
	]],
	geometry = [[
		#version 330
		layout(points) in;
		layout(triangle_strip, max_vertices = 4) out;

		in vec4 v_atlasUV[];
		in vec4 v_color[];
		in vec2 v_halfSizeNDC[];
		flat in float v_flash[];

		out vec2 f_texCoord;
		out vec4 f_color;
		flat out float f_flash;

		void main() {
			vec4 c = gl_in[0].gl_Position;
			vec4 uv = v_atlasUV[0];
			vec2 hs = v_halfSizeNDC[0];
			f_color = v_color[0];
			f_flash = v_flash[0];

			// Bottom-left
			gl_Position = vec4(c.x - hs.x, c.y - hs.y, c.z, 1.0);
			f_texCoord = vec2(uv.x, uv.y);
			EmitVertex();
			// Bottom-right
			gl_Position = vec4(c.x + hs.x, c.y - hs.y, c.z, 1.0);
			f_texCoord = vec2(uv.z, uv.y);
			EmitVertex();
			// Top-left
			gl_Position = vec4(c.x - hs.x, c.y + hs.y, c.z, 1.0);
			f_texCoord = vec2(uv.x, uv.w);
			EmitVertex();
			// Top-right
			gl_Position = vec4(c.x + hs.x, c.y + hs.y, c.z, 1.0);
			f_texCoord = vec2(uv.z, uv.w);
			EmitVertex();

			EndPrimitive();
		}
	]],
	fragment = [[
		#version 330
		uniform sampler2D iconAtlas;
		in vec2 f_texCoord;
		in vec4 f_color;
		flat in float f_flash;
		out vec4 fragColor;

		void main() {
			vec4 texColor = texture(iconAtlas, f_texCoord);
			vec4 result = texColor * f_color;
			// Brighten dark (black) parts of the icon texture during damage flash
			result.rgb += f_color.rgb * f_flash * (1.0 - texColor.rgb);
			if (result.a < 0.01) discard;  // cull non-tracked icons during outline pass
			fragColor = result;
		}
	]],
	uniformInt = {
		iconAtlas = 0,
	},
}

----------------------------------------------------------------------------------------------------
-- GL4 Primitive Shaders (circles, quads, lines)
----------------------------------------------------------------------------------------------------

-- Circle shader: point → screen-space quad → pixel-perfect gradient circle in fragment shader
gl4Prim.circleShaderCode = {
	vertex = [[
		#version 330
		layout(location = 0) in vec4 posRadius;    // worldX, worldZ, radius, alpha
		layout(location = 1) in vec4 coreColor;    // coreR, coreG, coreB, edgeAlpha
		layout(location = 2) in vec4 edgeColor;    // edgeR, edgeG, edgeB, blendMode (0=normal, 1=additive)

		uniform vec2 wtp_scale;
		uniform vec2 wtp_offset;
		uniform vec2 ndcScale;
		uniform vec2 rotSC;
		uniform vec2 rotCenter;

		out vec4 v_coreColor;
		out vec4 v_edgeColor;
		out vec2 v_halfSizeNDC;
		out float v_blendMode;

		void main() {
			vec2 pipPos = wtp_offset + posRadius.xy * wtp_scale;
			vec2 d = pipPos - rotCenter;
			pipPos = rotCenter + vec2(d.x*rotSC.y - d.y*rotSC.x, d.x*rotSC.x + d.y*rotSC.y);
			gl_Position = vec4(pipPos * ndcScale - 1.0, 0.0, 1.0);

			float radiusPIP = posRadius.z * abs(wtp_scale.x);
			v_halfSizeNDC = vec2(radiusPIP) * ndcScale;
			v_coreColor = vec4(coreColor.rgb, posRadius.w);
			v_edgeColor = vec4(edgeColor.rgb, coreColor.w);
			v_blendMode = edgeColor.w;
		}
	]],
	geometry = [[
		#version 330
		layout(points) in;
		layout(triangle_strip, max_vertices = 4) out;

		in vec4 v_coreColor[];
		in vec4 v_edgeColor[];
		in vec2 v_halfSizeNDC[];
		in float v_blendMode[];

		out vec2 f_localCoord;
		out vec4 f_coreColor;
		out vec4 f_edgeColor;
		flat out float f_blendMode;

		void main() {
			vec4 c = gl_in[0].gl_Position;
			vec2 hs = v_halfSizeNDC[0];
			f_coreColor = v_coreColor[0];
			f_edgeColor = v_edgeColor[0];
			f_blendMode = v_blendMode[0];

			gl_Position = vec4(c.x - hs.x, c.y - hs.y, 0, 1);
			f_localCoord = vec2(-1.0, -1.0);
			EmitVertex();
			gl_Position = vec4(c.x + hs.x, c.y - hs.y, 0, 1);
			f_localCoord = vec2(1.0, -1.0);
			EmitVertex();
			gl_Position = vec4(c.x - hs.x, c.y + hs.y, 0, 1);
			f_localCoord = vec2(-1.0, 1.0);
			EmitVertex();
			gl_Position = vec4(c.x + hs.x, c.y + hs.y, 0, 1);
			f_localCoord = vec2(1.0, 1.0);
			EmitVertex();
			EndPrimitive();
		}
	]],
	fragment = [[
		#version 330
		in vec2 f_localCoord;
		in vec4 f_coreColor;
		in vec4 f_edgeColor;
		flat in float f_blendMode;
		out vec4 fragColor;

		void main() {
			float dist = length(f_localCoord);
			if (dist > 1.0) discard;
			float t = smoothstep(0.0, 1.0, dist);
			fragColor = mix(f_coreColor, f_edgeColor, t);
		}
	]],
}

-- Quad shader: point → rotated quad
gl4Prim.quadShaderCode = {
	vertex = [[
		#version 330
		layout(location = 0) in vec4 posSizeIn;     // worldX, worldZ, halfWidth, halfHeight
		layout(location = 1) in vec4 colorIn;        // r, g, b, a
		layout(location = 2) in vec4 angleFlags;     // angleDeg, 0, 0, 0

		uniform vec2 wtp_scale;
		uniform vec2 wtp_offset;
		uniform vec2 ndcScale;
		uniform vec2 rotSC;
		uniform vec2 rotCenter;

		out vec4 v_color;
		out vec2 v_halfSizePx;
		out float v_angle;
		out vec2 v_ndcScale;
		out vec2 v_rotSC;

		void main() {
			vec2 pipPos = wtp_offset + posSizeIn.xy * wtp_scale;
			vec2 d = pipPos - rotCenter;
			pipPos = rotCenter + vec2(d.x*rotSC.y - d.y*rotSC.x, d.x*rotSC.x + d.y*rotSC.y);
			gl_Position = vec4(pipPos * ndcScale - 1.0, 0.0, 1.0);

			float scalePIP = abs(wtp_scale.x);
			v_halfSizePx = vec2(posSizeIn.z * scalePIP, posSizeIn.w * scalePIP);
			v_ndcScale = ndcScale;
			v_rotSC = rotSC;
			v_color = colorIn;
			v_angle = radians(angleFlags.x);
		}
	]],
	geometry = [[
		#version 330
		layout(points) in;
		layout(triangle_strip, max_vertices = 4) out;

		in vec4 v_color[];
		in vec2 v_halfSizePx[];
		in float v_angle[];
		in vec2 v_ndcScale[];
		in vec2 v_rotSC[];

		out vec4 f_color;

		void main() {
			vec4 c = gl_in[0].gl_Position;
			vec2 hs = v_halfSizePx[0];
			vec2 ndc = v_ndcScale[0];
			vec2 rsc = v_rotSC[0];
			f_color = v_color[0];
			float a = v_angle[0];
			float sa = sin(a), ca = cos(a);

			// Combine quad rotation with map rotation to get total rotation
			// sin(a+m) = sa*cos(m) + ca*sin(m), cos(a+m) = ca*cos(m) - sa*sin(m)
			float sT = sa * rsc.y + ca * rsc.x;
			float cT = ca * rsc.y - sa * rsc.x;

			// Rotate in pixel space (uniform coordinates) to avoid aspect-ratio distortion
			vec2 dx = vec2(cT, sT) * hs.x;
			vec2 dy = vec2(-sT, cT) * hs.y;

			// Convert pixel offsets to NDC
			gl_Position = vec4(c.xy + (-dx - dy) * ndc, 0, 1); EmitVertex();
			gl_Position = vec4(c.xy + ( dx - dy) * ndc, 0, 1); EmitVertex();
			gl_Position = vec4(c.xy + (-dx + dy) * ndc, 0, 1); EmitVertex();
			gl_Position = vec4(c.xy + ( dx + dy) * ndc, 0, 1); EmitVertex();
			EndPrimitive();
		}
	]],
	fragment = [[
		#version 330
		in vec4 f_color;
		out vec4 fragColor;
		void main() {
			fragColor = f_color;
		}
	]],
}

-- Line shader: simple world-space → NDC vertex transform with per-vertex color
gl4Prim.lineShaderCode = {
	vertex = [[
		#version 330
		layout(location = 0) in vec2 worldPos;
		layout(location = 1) in vec4 vertColor;

		uniform vec2 wtp_scale;
		uniform vec2 wtp_offset;
		uniform vec2 ndcScale;
		uniform vec2 rotSC;
		uniform vec2 rotCenter;

		out vec4 f_color;

		void main() {
			vec2 pipPos = wtp_offset + worldPos * wtp_scale;
			vec2 d = pipPos - rotCenter;
			pipPos = rotCenter + vec2(d.x*rotSC.y - d.y*rotSC.x, d.x*rotSC.x + d.y*rotSC.y);
			gl_Position = vec4(pipPos * ndcScale - 1.0, 0.0, 1.0);
			f_color = vertColor;
		}
	]],
	fragment = [[
		#version 330
		in vec4 f_color;
		out vec4 fragColor;
		void main() {
			fragColor = f_color;
		}
	]],
}

-- Initialize GL4 icon rendering: use engine $icons atlas, create VBO, shader
-- atlasUVs is keyed by unitDefID for uniform lookup.
local function InitGL4Icons()
	if not gl.GetVAO or not gl.GetVBO then
		Spring.Echo("[PIP] GL4 icons: VAO/VBO not available, falling back to legacy")
		return
	end

	if not Spring.GetIconData then
		Spring.Echo("[PIP] GL4 icons: Spring.GetIconData not available, falling back to legacy")
		return
	end

	local defaultIconData = Spring.GetIconData("default")
	if not defaultIconData or not defaultIconData.atlasTexCoords then
		Spring.Echo("[PIP] GL4 icons: Engine icon atlas data not available, falling back to legacy")
		return
	end

	local iconsTexInfo = gl.TextureInfo('$icons')
	if not iconsTexInfo or iconsTexInfo.xsize <= 0 then
		Spring.Echo("[PIP] GL4 icons: $icons texture not available, falling back to legacy")
		return
	end

	local dtc = defaultIconData.atlasTexCoords
	gl4Icons.defaultUV = {dtc.x0, dtc.y1, dtc.x1, dtc.y0}

	for uDefID, uDef in pairs(UnitDefs) do
		local iconName = uDef.iconType or "default"
		local iconInfo = Spring.GetIconData(iconName)
		if iconInfo and iconInfo.atlasTexCoords then
			local atc = iconInfo.atlasTexCoords
			gl4Icons.atlasUVs[uDefID] = {atc.x0, atc.y1, atc.x1, atc.y0}
		else
			gl4Icons.atlasUVs[uDefID] = gl4Icons.defaultUV
		end
	end

	gl4Icons.atlas = '$icons'
	--Spring.Echo("[PIP] GL4 icons: Using engine icon atlas ($icons, " .. iconsTexInfo.xsize .. "x" .. iconsTexInfo.ysize .. ")")

	-- Create raw VBO directly (no InstanceVBOTable — avoids per-frame table allocations)
	-- Layout: 12 floats per instance (3 vec4 attributes)
	local vboLayout = {
		{id = 0, name = 'worldPos_size', size = 4},   -- worldX, worldZ, sizeScale, isRadar
		{id = 1, name = 'atlasUV',       size = 4},   -- u0, v0, u1, v1
		{id = 2, name = 'colorFlags',    size = 4},   -- r, g, b, wobblePhase
	}
	local vbo = gl.GetVBO(GL.ARRAY_BUFFER, true)
	if not vbo then
		Spring.Echo("[PIP] GL4 icons: Failed to create VBO")
		gl4Icons.atlas = nil
		return
	end
	vbo:Define(gl4Icons.MAX_INSTANCES, vboLayout)

	-- Pre-allocate instance data array (avoids per-frame GC)
	local instanceData = {}
	for i = 1, gl4Icons.MAX_INSTANCES * gl4Icons.INSTANCE_STEP do
		instanceData[i] = 0
	end
	gl4Icons.instanceData = instanceData
	gl4Icons.vbo = vbo

	-- Create VAO: attach VBO as vertex buffer (geometry shader expands points → quads)
	local vao = gl.GetVAO()
	if not vao then
		Spring.Echo("[PIP] GL4 icons: Failed to create VAO")
		vbo:Delete()
		gl4Icons.atlas = nil
		gl4Icons.vbo = nil
		return
	end
	vao:AttachVertexBuffer(vbo)
	gl4Icons.vao = vao

	-- Compile shader
	local shader = gl.CreateShader(gl4Icons.shaderCode)
	if not shader then
		Spring.Echo("[PIP] GL4 icons: Shader compilation failed: " .. tostring(gl.GetShaderLog()))
		vao:Delete()
		vbo:Delete()
		gl4Icons.atlas = nil
		gl4Icons.vbo = nil
		gl4Icons.vao = nil
		return
	end
	gl4Icons.shader = shader

	-- Cache uniform locations for per-frame updates
	gl4Icons.uniformLocs = {
		wtp_scale    = gl.GetUniformLocation(shader, "wtp_scale"),
		wtp_offset   = gl.GetUniformLocation(shader, "wtp_offset"),
		ndcScale     = gl.GetUniformLocation(shader, "ndcScale"),
		rotSC        = gl.GetUniformLocation(shader, "rotSC"),
		rotCenter    = gl.GetUniformLocation(shader, "rotCenter"),
		iconBaseSize = gl.GetUniformLocation(shader, "iconBaseSize"),
		gameTime     = gl.GetUniformLocation(shader, "gameTime"),
		wallClockTime = gl.GetUniformLocation(shader, "wallClockTime"),
		outlinePass  = gl.GetUniformLocation(shader, "outlinePass"),
		healthDarkenMax = gl.GetUniformLocation(shader, "healthDarkenMax"),
	}

	gl4Icons.enabled = true
	--Spring.Echo("[PIP] GL4 instanced icon rendering enabled (" .. atlasSize .. "x" .. atlasSize .. " atlas)")
end

-- Cleanup GL4 icon resources
local function DestroyGL4Icons()
	if gl4Icons.shader then
		gl.DeleteShader(gl4Icons.shader)
		gl4Icons.shader = nil
	end
	if gl4Icons.vao then
		gl4Icons.vao:Delete()
		gl4Icons.vao = nil
	end
	if gl4Icons.vbo then
		gl4Icons.vbo:Delete()
		gl4Icons.vbo = nil
	end
	if gl4Icons.atlas then
		gl4Icons.atlas = nil
	end
	gl4Icons.enabled = false
end

----------------------------------------------------------------------------------------------------
-- GL4 Primitive Init / Destroy / Helpers
----------------------------------------------------------------------------------------------------

local function CreateLineVBOSet(maxVertices)
	local vboLayout = {
		{id = 0, name = 'worldPos', size = 2},   -- worldX, worldZ
		{id = 1, name = 'vertColor', size = 4},   -- r, g, b, a
	}
	local vbo = gl.GetVBO(GL.ARRAY_BUFFER, true)
	if not vbo then return nil, nil, nil end
	vbo:Define(maxVertices, vboLayout)
	local vao = gl.GetVAO()
	if not vao then vbo:Delete(); return nil, nil, nil end
	vao:AttachVertexBuffer(vbo)
	local data = {}
	for i = 1, maxVertices * gl4Prim.LINE_STEP do data[i] = 0 end
	return vbo, vao, data
end

local function InitGL4Primitives()
	if not gl.GetVAO or not gl.GetVBO then return end

	-- Circle VBO/VAO
	local circleLayout = {
		{id = 0, name = 'posRadius',  size = 4},   -- worldX, worldZ, radius, alpha
		{id = 1, name = 'coreColor',  size = 4},   -- coreR, coreG, coreB, edgeAlpha
		{id = 2, name = 'edgeColor',  size = 4},   -- edgeR, edgeG, edgeB, blendMode
	}
	local cVbo = gl.GetVBO(GL.ARRAY_BUFFER, true)
	if not cVbo then return end
	cVbo:Define(gl4Prim.CIRCLE_MAX, circleLayout)
	local cVao = gl.GetVAO()
	if not cVao then cVbo:Delete(); return end
	cVao:AttachVertexBuffer(cVbo)
	local cData = {}
	for i = 1, gl4Prim.CIRCLE_MAX * gl4Prim.CIRCLE_STEP do cData[i] = 0 end
	gl4Prim.circles.vbo = cVbo
	gl4Prim.circles.vao = cVao
	gl4Prim.circles.data = cData

	-- Quad VBO/VAO
	local quadLayout = {
		{id = 0, name = 'posSizeIn',   size = 4},  -- worldX, worldZ, halfWidth, halfHeight
		{id = 1, name = 'colorIn',     size = 4},  -- r, g, b, a
		{id = 2, name = 'angleFlags',  size = 4},  -- angleDeg, 0, 0, 0
	}
	local qVbo = gl.GetVBO(GL.ARRAY_BUFFER, true)
	if not qVbo then cVao:Delete(); cVbo:Delete(); return end
	qVbo:Define(gl4Prim.QUAD_MAX, quadLayout)
	local qVao = gl.GetVAO()
	if not qVao then qVbo:Delete(); cVao:Delete(); cVbo:Delete(); return end
	qVao:AttachVertexBuffer(qVbo)
	local qData = {}
	for i = 1, gl4Prim.QUAD_MAX * gl4Prim.QUAD_STEP do qData[i] = 0 end
	gl4Prim.quads.vbo = qVbo
	gl4Prim.quads.vao = qVao
	gl4Prim.quads.data = qData

	-- Line VBOs (3 categories share same shader)
	local glVbo, glVao, glData = CreateLineVBOSet(gl4Prim.LINE_MAX)
	if not glVbo then qVao:Delete(); qVbo:Delete(); cVao:Delete(); cVbo:Delete(); return end
	gl4Prim.glowLines.vbo, gl4Prim.glowLines.vao, gl4Prim.glowLines.data = glVbo, glVao, glData

	local clVbo, clVao, clData = CreateLineVBOSet(gl4Prim.LINE_MAX)
	if not clVbo then
		glVao:Delete(); glVbo:Delete(); qVao:Delete(); qVbo:Delete(); cVao:Delete(); cVbo:Delete()
		return
	end
	gl4Prim.coreLines.vbo, gl4Prim.coreLines.vao, gl4Prim.coreLines.data = clVbo, clVao, clData

	local nlVbo, nlVao, nlData = CreateLineVBOSet(gl4Prim.LINE_MAX)
	if not nlVbo then
		clVao:Delete(); clVbo:Delete(); glVao:Delete(); glVbo:Delete()
		qVao:Delete(); qVbo:Delete(); cVao:Delete(); cVbo:Delete()
		return
	end
	gl4Prim.normLines.vbo, gl4Prim.normLines.vao, gl4Prim.normLines.data = nlVbo, nlVao, nlData

	-- Compile shaders
	local cShader = gl.CreateShader(gl4Prim.circleShaderCode)
	if not cShader then
		Spring.Echo("[PIP] GL4 circle shader failed: " .. tostring(gl.GetShaderLog()))
		-- cleanup all
		nlVao:Delete(); nlVbo:Delete(); clVao:Delete(); clVbo:Delete()
		glVao:Delete(); glVbo:Delete(); qVao:Delete(); qVbo:Delete()
		cVao:Delete(); cVbo:Delete()
		return
	end
	gl4Prim.circles.shader = cShader

	local qShader = gl.CreateShader(gl4Prim.quadShaderCode)
	if not qShader then
		Spring.Echo("[PIP] GL4 quad shader failed: " .. tostring(gl.GetShaderLog()))
		gl.DeleteShader(cShader)
		nlVao:Delete(); nlVbo:Delete(); clVao:Delete(); clVbo:Delete()
		glVao:Delete(); glVbo:Delete(); qVao:Delete(); qVbo:Delete()
		cVao:Delete(); cVbo:Delete()
		return
	end
	gl4Prim.quads.shader = qShader

	local lShader = gl.CreateShader(gl4Prim.lineShaderCode)
	if not lShader then
		Spring.Echo("[PIP] GL4 line shader failed: " .. tostring(gl.GetShaderLog()))
		gl.DeleteShader(qShader); gl.DeleteShader(cShader)
		nlVao:Delete(); nlVbo:Delete(); clVao:Delete(); clVbo:Delete()
		glVao:Delete(); glVbo:Delete(); qVao:Delete(); qVbo:Delete()
		cVao:Delete(); cVbo:Delete()
		return
	end
	gl4Prim.lineShader = lShader

	-- Cache uniform locations
	local function cacheUniforms(shader)
		return {
			wtp_scale  = gl.GetUniformLocation(shader, "wtp_scale"),
			wtp_offset = gl.GetUniformLocation(shader, "wtp_offset"),
			ndcScale   = gl.GetUniformLocation(shader, "ndcScale"),
			rotSC      = gl.GetUniformLocation(shader, "rotSC"),
			rotCenter  = gl.GetUniformLocation(shader, "rotCenter"),
		}
	end
	gl4Prim.circles.uniformLocs = cacheUniforms(cShader)
	gl4Prim.quads.uniformLocs = cacheUniforms(qShader)
	gl4Prim.lineUniformLocs = cacheUniforms(lShader)

	gl4Prim.enabled = true
	--Spring.Echo("[PIP] GL4 primitive rendering enabled (circles, quads, lines)")
end

local function DestroyGL4Primitives()
	if gl4Prim.circles.shader then gl.DeleteShader(gl4Prim.circles.shader); gl4Prim.circles.shader = nil end
	if gl4Prim.quads.shader   then gl.DeleteShader(gl4Prim.quads.shader);   gl4Prim.quads.shader = nil end
	if gl4Prim.lineShader      then gl.DeleteShader(gl4Prim.lineShader);      gl4Prim.lineShader = nil end

	for _, sub in ipairs({gl4Prim.circles, gl4Prim.quads, gl4Prim.glowLines, gl4Prim.coreLines, gl4Prim.normLines}) do
		if sub.vao then sub.vao:Delete(); sub.vao = nil end
		if sub.vbo then sub.vbo:Delete(); sub.vbo = nil end
	end
	gl4Prim.enabled = false
end

-- Reset per-frame counters
local function GL4ResetPrimCounts()
	gl4Prim.circles.count = 0
	gl4Prim.quads.count = 0
	gl4Prim.glowLines.count = 0
	gl4Prim.coreLines.count = 0
	gl4Prim.normLines.count = 0
end

-- Helper: add a gradient circle (explosion, plasma, etc.)
local function GL4AddCircle(worldX, worldZ, radius, alpha, coreR, coreG, coreB, edgeR, edgeG, edgeB, edgeAlpha, blendMode)
	local c = gl4Prim.circles
	if c.count >= gl4Prim.CIRCLE_MAX then return end
	local off = c.count * gl4Prim.CIRCLE_STEP
	local d = c.data
	d[off+1] = worldX;  d[off+2] = worldZ; d[off+3] = radius; d[off+4] = alpha or 1
	d[off+5] = coreR;   d[off+6] = coreG;  d[off+7] = coreB;  d[off+8] = edgeAlpha or 0
	d[off+9] = edgeR;   d[off+10] = edgeG; d[off+11] = edgeB; d[off+12] = blendMode or 0
	c.count = c.count + 1
end

-- Helper: add an oriented quad (missile, blaster)
local function GL4AddQuad(worldX, worldZ, halfW, halfH, angleDeg, r, g, b, a)
	local q = gl4Prim.quads
	if q.count >= gl4Prim.QUAD_MAX then return end
	local off = q.count * gl4Prim.QUAD_STEP
	local d = q.data
	d[off+1] = worldX; d[off+2] = worldZ; d[off+3] = halfW;  d[off+4] = halfH
	d[off+5] = r;      d[off+6] = g;      d[off+7] = b;      d[off+8] = a or 1
	d[off+9] = angleDeg or 0; d[off+10] = 0; d[off+11] = 0; d[off+12] = 0
	q.count = q.count + 1
end

-- Helper: add a line vertex pair to a specific line category
local function GL4AddLineToCategory(cat, x1, z1, x2, z2, r, g, b, a, r2, g2, b2, a2)
	if cat.count + 2 > gl4Prim.LINE_MAX then return end
	local off = cat.count * gl4Prim.LINE_STEP
	local d = cat.data
	-- First vertex
	d[off+1] = x1; d[off+2] = z1
	d[off+3] = r;  d[off+4] = g; d[off+5] = b; d[off+6] = a or 1
	-- Second vertex
	d[off+7] = x2; d[off+8] = z2
	d[off+9] = r2 or r; d[off+10] = g2 or g; d[off+11] = b2 or b; d[off+12] = a2 or a or 1
	cat.count = cat.count + 2
end

local function GL4AddGlowLine(x1, z1, x2, z2, r, g, b, a, r2, g2, b2, a2)
	GL4AddLineToCategory(gl4Prim.glowLines, x1, z1, x2, z2, r, g, b, a, r2, g2, b2, a2)
end
local function GL4AddCoreLine(x1, z1, x2, z2, r, g, b, a, r2, g2, b2, a2)
	GL4AddLineToCategory(gl4Prim.coreLines, x1, z1, x2, z2, r, g, b, a, r2, g2, b2, a2)
end
local function GL4AddNormLine(x1, z1, x2, z2, r, g, b, a, r2, g2, b2, a2)
	GL4AddLineToCategory(gl4Prim.normLines, x1, z1, x2, z2, r, g, b, a, r2, g2, b2, a2)
end

-- Set shared uniforms on a shader
local function GL4SetPrimUniforms(shader, ulocs)
	gl.UseShader(shader)
	gl.UniformFloat(ulocs.wtp_scale, wtp.scaleX, wtp.scaleZ)
	gl.UniformFloat(ulocs.wtp_offset, wtp.offsetX, wtp.offsetZ)
	local fboW = render.dim.r - render.dim.l
	local fboH = render.dim.t - render.dim.b
	gl.UniformFloat(ulocs.ndcScale, 2.0 / fboW, 2.0 / fboH)
	local rot = render.minimapRotation or 0
	gl.UniformFloat(ulocs.rotSC, math.sin(rot), math.cos(rot))
	gl.UniformFloat(ulocs.rotCenter, fboW * 0.5, fboH * 0.5)
end

-- Draw all collected circles, quads, and effect lines (called after PopMatrix in DrawUnitsAndFeatures)
local function GL4FlushEffects()
	if not gl4Prim.enabled then return end

	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)

	-- Circles
	if gl4Prim.circles.count > 0 then
		local c = gl4Prim.circles
		c.vbo:Upload(c.data, nil, 0, 1, c.count * gl4Prim.CIRCLE_STEP)
		GL4SetPrimUniforms(c.shader, c.uniformLocs)
		c.vao:DrawArrays(GL.POINTS, c.count)
		gl.UseShader(0)
	end

	-- Quads
	if gl4Prim.quads.count > 0 then
		local q = gl4Prim.quads
		q.vbo:Upload(q.data, nil, 0, 1, q.count * gl4Prim.QUAD_STEP)
		GL4SetPrimUniforms(q.shader, q.uniformLocs)
		q.vao:DrawArrays(GL.POINTS, q.count)
		gl.UseShader(0)
	end

	-- Lines (3 width categories, same shader)
	local resScale = render.contentScale or 1
	local zoomScale = math.max(0.5, cameraState.zoom / 70)
	local glowWidth = math.max(2, 5 * zoomScale) * resScale
	local coreWidth = math.max(1, 2 * zoomScale) * resScale
	local normWidth = 1 * resScale

	local anyLines = gl4Prim.glowLines.count > 0 or gl4Prim.coreLines.count > 0 or gl4Prim.normLines.count > 0
	if anyLines then
		GL4SetPrimUniforms(gl4Prim.lineShader, gl4Prim.lineUniformLocs)

		if gl4Prim.glowLines.count > 0 then
			local ln = gl4Prim.glowLines
			ln.vbo:Upload(ln.data, nil, 0, 1, ln.count * gl4Prim.LINE_STEP)
			glFunc.LineWidth(glowWidth)
			ln.vao:DrawArrays(GL.LINES, ln.count)
		end
		if gl4Prim.coreLines.count > 0 then
			local ln = gl4Prim.coreLines
			ln.vbo:Upload(ln.data, nil, 0, 1, ln.count * gl4Prim.LINE_STEP)
			glFunc.LineWidth(coreWidth)
			ln.vao:DrawArrays(GL.LINES, ln.count)
		end
		if gl4Prim.normLines.count > 0 then
			local ln = gl4Prim.normLines
			ln.vbo:Upload(ln.data, nil, 0, 1, ln.count * gl4Prim.LINE_STEP)
			glFunc.LineWidth(normWidth)
			ln.vao:DrawArrays(GL.LINES, ln.count)
		end

		glFunc.LineWidth(1 * resScale)
		gl.UseShader(0)
	end
end

-- Flush only circles with a caller-controlled blend mode (used for explosion overlay)
local function GL4FlushCirclesOnly()
	if not gl4Prim.enabled then return end
	if gl4Prim.circles.count == 0 then return end
	local c = gl4Prim.circles
	c.vbo:Upload(c.data, nil, 0, 1, c.count * gl4Prim.CIRCLE_STEP)
	GL4SetPrimUniforms(c.shader, c.uniformLocs)
	c.vao:DrawArrays(GL.POINTS, c.count)
	gl.UseShader(0)
end

-- Flush only command lines (called at end of DrawCommandQueuesOverlay)
local function GL4FlushCommandLines()
	if not gl4Prim.enabled then return end
	if gl4Prim.normLines.count == 0 then return end

	local resScale = render.contentScale or 1
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	GL4SetPrimUniforms(gl4Prim.lineShader, gl4Prim.lineUniformLocs)

	local ln = gl4Prim.normLines
	ln.vbo:Upload(ln.data, nil, 0, 1, ln.count * gl4Prim.LINE_STEP)
	glFunc.LineWidth(1 * resScale)
	ln.vao:DrawArrays(GL.LINES, ln.count)

	glFunc.LineWidth(1 * resScale)
	gl.UseShader(0)
end

----------------------------------------------------------------------------------------------------
-- Local functions
----------------------------------------------------------------------------------------------------
-- Utility

-- (worldToPipScale/Offset are declared earlier, before GL4 primitive code)

-- Get PIP dimensions for world coordinate calculations, accounting for rotation
-- When rotated 90°/270°, width and height are swapped for world calculations
local function GetEffectivePipDimensions()
	local pipWidth = render.dim.r - render.dim.l
	local pipHeight = render.dim.t - render.dim.b
	if render.minimapRotation then
		local rotDeg = math.abs(render.minimapRotation * 180 / math.pi) % 180
		if rotDeg > 45 and rotDeg < 135 then
			return pipHeight, pipWidth  -- Swapped
		end
	end
	return pipWidth, pipHeight
end

-- Clamp a camera position along one axis, centering when view exceeds the map
-- marginFraction: fraction of visibleSize allowed past map edge (e.g. 0.15)
local function ClampCameraAxis(pos, visibleSize, mapSize, marginFraction)
	local margin = visibleSize * marginFraction
	local minPos = visibleSize / 2 - margin
	local maxPos = mapSize - (visibleSize / 2 - margin)
	if minPos >= maxPos then
		return mapSize / 2
	end
	return math.min(math.max(pos, minPos), maxPos)
end

function RecalculateWorldCoordinates()
	-- Guard against uninitialized render dimensions
	if not render.dim.l or not render.dim.r or not render.dim.b or not render.dim.t then return end
	
	-- Use contentScale to calculate world bounds correctly when rendering to higher-res texture
	-- (render.dim is scaled for scissoring, but world bounds should use logical dimensions)
	local scale = render.contentScale or 1
	local hw, hh = 0.5 * (render.dim.r - render.dim.l) / (cameraState.zoom * scale), 0.5 * (render.dim.t - render.dim.b) / (cameraState.zoom * scale)
	
	-- At 90/270 degrees, the content is rotated inside the rectangular PIP window
	-- So we need to swap what the world considers width/height
	local isRotated90 = false
	if render.minimapRotation then
		local rotDeg = math.abs(render.minimapRotation * 180 / math.pi) % 180
		if rotDeg > 45 and rotDeg < 135 then
			hw, hh = hh, hw
			isRotated90 = true
		end
	end
	
	render.world.l, render.world.r, render.world.b, render.world.t = cameraState.wcx - hw, cameraState.wcx + hw, cameraState.wcz + hh, cameraState.wcz - hh

	-- Precalculate factors for WorldToPipCoords (performance)
	-- At 90/270 degrees, use swapped dimensions to match ground texture
	local worldWidth = render.world.r - render.world.l
	local worldHeight = render.world.t - render.world.b
	if worldWidth ~= 0 and worldHeight ~= 0 then
		if isRotated90 then
			-- Use swapped dimensions around center
			local centerX = (render.dim.l + render.dim.r) / 2
			local centerY = (render.dim.b + render.dim.t) / 2
			local halfWidth = (render.dim.r - render.dim.l) / 2
			local halfHeight = (render.dim.t - render.dim.b) / 2
			local dimL = centerX - halfHeight
			local dimR = centerX + halfHeight
			local dimB = centerY - halfWidth
			local dimT = centerY + halfWidth
			wtp.scaleX = (dimR - dimL) / worldWidth
			wtp.scaleZ = (dimT - dimB) / worldHeight
			wtp.offsetX = dimL - render.world.l * wtp.scaleX
			wtp.offsetZ = dimB - render.world.b * wtp.scaleZ
		else
			wtp.scaleX = (render.dim.r - render.dim.l) / worldWidth
			wtp.scaleZ = (render.dim.t - render.dim.b) / worldHeight
			wtp.offsetX = render.dim.l - render.world.l * wtp.scaleX
			wtp.offsetZ = render.dim.b - render.world.b * wtp.scaleZ
		end
	end
end

function RecalculateGroundTextureCoordinates()
	-- At 90/270 degrees with rectangular PIP, we need to use swapped dimensions
	-- so that after rotation the content fills the window correctly
	local dimL, dimR, dimB, dimT = render.dim.l, render.dim.r, render.dim.b, render.dim.t
	
	if render.minimapRotation then
		local rotDeg = math.abs(render.minimapRotation * 180 / math.pi) % 180
		if rotDeg > 45 and rotDeg < 135 then
			-- Swap dimensions around center for ground texture calculation
			local centerX = (render.dim.l + render.dim.r) / 2
			local centerY = (render.dim.b + render.dim.t) / 2
			local halfWidth = (render.dim.r - render.dim.l) / 2
			local halfHeight = (render.dim.t - render.dim.b) / 2
			-- Swap: use height as width and width as height
			dimL = centerX - halfHeight
			dimR = centerX + halfHeight
			dimB = centerY - halfWidth
			dimT = centerY + halfWidth
		end
	end
	
	if render.world.l < 0 then
		render.ground.view.l = dimL + (dimR - dimL) * (-render.world.l / (render.world.r - render.world.l))
		render.ground.coord.l = 0
	else
		render.ground.view.l = dimL
		render.ground.coord.l = render.world.l / mapInfo.mapSizeX
	end
	if render.world.r > mapInfo.mapSizeX then
		render.ground.view.r = dimR - (dimR - dimL) * ((render.world.r - mapInfo.mapSizeX) / (render.world.r - render.world.l))
		render.ground.coord.r = 1
	else
		render.ground.view.r = dimR
		render.ground.coord.r = math.ceil(render.world.r) / mapInfo.mapSizeX  -- Use ceil for right edge
	end
	if render.world.t < 0 then
		render.ground.view.t = dimT - (dimT - dimB) * (-render.world.t / (render.world.b - render.world.t))
		render.ground.coord.t = 0
	else
		render.ground.view.t = dimT
		render.ground.coord.t = render.world.t / mapInfo.mapSizeZ
	end
	if render.world.b > mapInfo.mapSizeZ then
		render.ground.view.b = dimB + (dimT - dimB) * ((render.world.b - mapInfo.mapSizeZ) / (render.world.b - render.world.t))
		render.ground.coord.b = 1
	else
		render.ground.view.b = dimB
		render.ground.coord.b = math.ceil(render.world.b) / mapInfo.mapSizeZ  -- Use ceil for bottom edge (which is top in Z)
	end
end

local function CorrectScreenPosition()
	-- Guard against uninitialized render dimensions
	if not render.dim.l or not render.dim.r or not render.dim.b or not render.dim.t then return end

	-- In minimap mode, use different margin and allow edge-to-edge positioning
	local screenMarginPx
	if isMinimapMode then
		screenMarginPx = math.floor(config.minimapModeScreenMargin * render.vsy)
	else
		screenMarginPx = math.floor(config.screenMargin * render.vsy)
	end
	local minSize = math.floor(config.minPanelSize * render.widgetScale)

	-- Calculate current window dimensions
	local windowWidth = render.dim.r - render.dim.l
	local windowHeight = render.dim.t - render.dim.b

	-- Enforce minimum panel size (skip in minimap mode - sizing is determined differently)
	if not isMinimapMode then
		if windowWidth < minSize then
			windowWidth = minSize
			render.dim.r = render.dim.l + windowWidth
		end
		if windowHeight < minSize then
			windowHeight = minSize
			render.dim.t = render.dim.b + windowHeight
		end
	end

	-- Check and correct left boundary
	if render.dim.l < screenMarginPx then
		render.dim.l = screenMarginPx
		render.dim.r = render.dim.l + windowWidth
	end

	-- Check and correct right boundary
	if render.dim.r > render.vsx - screenMarginPx then
		render.dim.r = render.vsx - screenMarginPx
		render.dim.l = render.dim.r - windowWidth
	end

	-- Check and correct bottom boundary
	if render.dim.b < screenMarginPx then
		render.dim.b = screenMarginPx
		render.dim.t = render.dim.b + windowHeight
	end

	-- Check and correct top boundary
	if render.dim.t > render.vsy - screenMarginPx then
		render.dim.t = render.vsy - screenMarginPx
		render.dim.b = render.dim.t - windowHeight
	end
end

local function IsFiniteNumber(value)
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function AreDimensionsValid(dim, minWidth, minHeight)
	if type(dim) ~= "table" then
		return false
	end

	local l, r, b, t = dim.l, dim.r, dim.b, dim.t
	if not (IsFiniteNumber(l) and IsFiniteNumber(r) and IsFiniteNumber(b) and IsFiniteNumber(t)) then
		return false
	end

	minWidth = minWidth or 1
	minHeight = minHeight or 1
	return (r - l) >= minWidth and (t - b) >= minHeight
end

local function AreExpandedDimensionsValid(dim)
	local minSize = math.floor(config.minPanelSize * render.widgetScale)
	return AreDimensionsValid(dim, minSize, minSize) and dim.r > minSize and dim.t > minSize
end

local function BuildDefaultExpandedDimensions()
	local defaultL = math.floor(render.vsx * 0.7)
	local defaultB = math.floor(render.vsy * 0.7)
	local defaultW = math.floor(config.minPanelSize * render.widgetScale * 1.4)
	local defaultH = math.floor(config.minPanelSize * render.widgetScale * 1.2)

	return {
		l = defaultL,
		r = defaultL + defaultW,
		b = defaultB,
		t = defaultB + defaultH,
	}
end

local function EnsureSavedExpandedDimensions()
	if AreExpandedDimensionsValid(uiState.savedDimensions) then
		return uiState.savedDimensions
	end

	local recoveredDimensions
	if not uiState.inMinMode and AreExpandedDimensionsValid(render.dim) then
		recoveredDimensions = {
			l = render.dim.l,
			r = render.dim.r,
			b = render.dim.b,
			t = render.dim.t,
		}
	else
		recoveredDimensions = BuildDefaultExpandedDimensions()
	end

	uiState.savedDimensions = recoveredDimensions
	return uiState.savedDimensions
end

local UpdateTracking  -- forward declaration (called in StartMaximizeAnimation, defined later)
local InitGL4Decals   -- forward declaration (called in Initialize, defined after decalGL4 table)
local DestroyGL4Decals -- forward declaration (called in Shutdown, defined after decalGL4 table)
local decalGL4        -- forward declaration (referenced in DrawDecalsOverlay, defined later)

local function StartMaximizeAnimation()
	local buttonSize = math.floor(render.usedButtonSize * config.maximizeSizemult)
	local screenMarginPx = math.floor(config.screenMargin * render.vsy)

	if not IsFiniteNumber(uiState.minModeL) or not IsFiniteNumber(uiState.minModeB) then
		uiState.minModeL = render.vsx - buttonSize - screenMarginPx
		uiState.minModeB = render.vsy - buttonSize - screenMarginPx
	end

	local expandedDimensions = EnsureSavedExpandedDimensions()
	render.dim.l = expandedDimensions.l
	render.dim.r = expandedDimensions.r
	render.dim.b = expandedDimensions.b
	render.dim.t = expandedDimensions.t
	CorrectScreenPosition()

	-- Keep the clamped dimensions as the persisted expanded target.
	uiState.savedDimensions = {
		l = render.dim.l,
		r = render.dim.r,
		b = render.dim.b,
		t = render.dim.t,
	}

	if interactionState.areTracking then
		UpdateTracking()
	end
	RecalculateWorldCoordinates()
	RecalculateGroundTextureCoordinates()

	uiState.animStartDim = {
		l = uiState.minModeL,
		r = uiState.minModeL + buttonSize,
		b = uiState.minModeB,
		t = uiState.minModeB + buttonSize
	}
	uiState.animEndDim = {
		l = render.dim.l,
		r = render.dim.r,
		b = render.dim.b,
		t = render.dim.t
	}
	uiState.animationProgress = 0
	uiState.isAnimating = true
	uiState.inMinMode = false
	miscState.hasOpenedPIPThisGame = true
end

local function RecoverInvalidAnimationState()
	uiState.isAnimating = false

	if uiState.inMinMode then
		local buttonSize = math.floor(render.usedButtonSize * config.maximizeSizemult)
		local screenMarginPx = math.floor(config.screenMargin * render.vsy)

		if not IsFiniteNumber(uiState.minModeL) or not IsFiniteNumber(uiState.minModeB) then
			uiState.minModeL = render.vsx - buttonSize - screenMarginPx
			uiState.minModeB = render.vsy - buttonSize - screenMarginPx
		end

		render.dim.l = uiState.minModeL
		render.dim.r = uiState.minModeL + buttonSize
		render.dim.b = uiState.minModeB
		render.dim.t = uiState.minModeB + buttonSize
	else
		local expandedDimensions = EnsureSavedExpandedDimensions()
		render.dim.l = expandedDimensions.l
		render.dim.r = expandedDimensions.r
		render.dim.b = expandedDimensions.b
		render.dim.t = expandedDimensions.t
		CorrectScreenPosition()

		uiState.savedDimensions = {
			l = render.dim.l,
			r = render.dim.r,
			b = render.dim.b,
			t = render.dim.t,
		}
	end

	RecalculateWorldCoordinates()
	RecalculateGroundTextureCoordinates()
	pipR2T.contentNeedsUpdate = true
	pipR2T.frameNeedsUpdate = true
	UpdateGuishaderBlur()
end

local function UpdateGuishaderBlur()
	if WG['guishader'] then
		-- When minimap is hidden via MinimapMinimize, remove blur entirely
		if isMinimapMode and miscState.minimapMinimized then
			if render.guishaderDlist then
				gl.DeleteList(render.guishaderDlist)
				render.guishaderDlist = nil
			end
			if WG['guishader'].RemoveDlist then
				WG['guishader'].RemoveDlist('pip'..pipNumber)
			elseif WG['guishader'].RemoveRect then
				WG['guishader'].RemoveRect('pip'..pipNumber)
			end
			return
		end
		-- Determine the correct bounds based on mode
		local blurL, blurB, blurR, blurT
		if uiState.inMinMode and not uiState.isAnimating then
			-- Use minimized button position
			local buttonSize = math.floor(render.usedButtonSize * config.maximizeSizemult)
			blurL = uiState.minModeL - render.elementPadding
			blurB = uiState.minModeB - render.elementPadding
			blurR = uiState.minModeL + buttonSize + render.elementPadding
			blurT = uiState.minModeB + buttonSize + render.elementPadding
		else
			-- Use regular PIP dimensions
			blurL = render.dim.l - render.elementPadding
			blurB = render.dim.b - render.elementPadding
			blurR = render.dim.r + render.elementPadding
			blurT = render.dim.t + render.elementPadding
		end
		
		-- Use InsertDlist for rounded corner blur support
		if WG['guishader'].InsertDlist then
			-- Clean up old dlist ourselves before creating new one
			if render.guishaderDlist then
				gl.DeleteList(render.guishaderDlist)
				render.guishaderDlist = nil
			end
			-- Create new dlist with rounded rectangle
			render.guishaderDlist = gl.CreateList(function()
				render.RectRound(blurL, blurB, blurR, blurT, render.elementCorner)
			end)
			-- Use force=true to ensure immediate stencil texture update
			WG['guishader'].InsertDlist(render.guishaderDlist, 'pip'..pipNumber, true)
		elseif WG['guishader'].InsertRect then
			-- Fallback to InsertRect if InsertDlist not available
			WG['guishader'].InsertRect(blurL, blurB, blurR, blurT, 'pip'..pipNumber)
		end
	end
end

local function UpdateCentering(mx, my)
	-- In minimap mode at minimum zoom, don't allow centering - keep centered on map
	if IsAtMinimumZoom(cameraState.zoom) then
		cameraState.wcx = mapInfo.mapSizeX / 2
		cameraState.wcz = mapInfo.mapSizeZ / 2
		cameraState.targetWcx = cameraState.wcx
		cameraState.targetWcz = cameraState.wcz
		return
	end
	
	local _, pos = Spring.TraceScreenRay(mx, my, true)
	if pos and pos[2] > -10000 then
		cameraState.wcx, cameraState.wcz = pos[1], pos[3]
		cameraState.targetWcx, cameraState.targetWcz = cameraState.wcx, cameraState.wcz  -- Set targets instantly for centering
		RecalculateWorldCoordinates()
		RecalculateGroundTextureCoordinates()
	end
end

UpdateTracking = function()
	local uCount = 0
	local ax, az = 0, 0
	local stillAlive = {}

	for t = 1, #interactionState.areTracking do
		local uID = interactionState.areTracking[t]
		local ux, uy, uz = spFunc.GetUnitBasePosition(uID)
		if ux then
			ax = ax + ux
			az = az + uz
			uCount = uCount + 1
			stillAlive[uCount] = uID
		end
	end

	if uCount > 0 then
		-- Calculate target camera position (average of tracked units)
		local newTargetWcx = ax / uCount
		local newTargetWcz = az / uCount

		-- Apply map edge margin constraints
		-- Use TARGET zoom level so panning and zooming are in sync when tracking near edges
		local pipWidth, pipHeight = GetEffectivePipDimensions()
		local visibleWorldWidth = pipWidth / cameraState.targetZoom
		local visibleWorldHeight = pipHeight / cameraState.targetZoom

		-- Set only the target positions for smooth camera transition, clamped to margins
		cameraState.targetWcx = ClampCameraAxis(newTargetWcx, visibleWorldWidth, mapInfo.mapSizeX, config.mapEdgeMargin)
		cameraState.targetWcz = ClampCameraAxis(newTargetWcz, visibleWorldHeight, mapInfo.mapSizeZ, config.mapEdgeMargin)

		-- Don't update cameraState.wcx/cameraState.wcz immediately - let the smooth interpolation system handle it
		-- RecalculateWorldCoordinates() and RecalculateGroundTextureCoordinates() will be called in Update()

		interactionState.areTracking = stillAlive
	else
		interactionState.areTracking = nil
	end
end

-- Helper function to get player skill/rating
local function GetPlayerSkill(playerID)
	local customtable = select(11, spFunc.GetPlayerInfo(playerID))
	if type(customtable) == 'table' and customtable.skill then
		local tsMu = customtable.skill
		local skill = tsMu and tonumber(tsMu:match("-?%d+%.?%d*"))
		return skill or 0
	end
	return 0
end

-- Helper function to get alive teammates (excluding self and AI)
local function GetAliveTeammates()
	local myPlayerID = Spring.GetMyPlayerID()
	local _, _, _, myTeamID = spFunc.GetPlayerInfo(myPlayerID, false)
	if not myTeamID then
		return {}
	end
	
	local teammates = {}
	local playerList = Spring.GetPlayerList()
	
	for _, playerID in ipairs(playerList) do
		if playerID ~= myPlayerID then
			local _, active, isSpec, playerTeamID = spFunc.GetPlayerInfo(playerID, false)
			if active and not isSpec and playerTeamID and playerTeamID == myTeamID then
				-- Check if this team is controlled by AI
				local _, _, isDead, isAI = spFunc.GetTeamInfo(playerTeamID, false)
				if not isAI and not isDead then
					table.insert(teammates, playerID)
				end
			end
		end
	end
	
	return teammates
end

-- Helper function to find the next best player on the same team
local function FindNextBestTeamPlayer(excludePlayerID)
	-- Get the team and allyteam of the excluded player
	local _, _, _, excludeTeamID = spFunc.GetPlayerInfo(excludePlayerID, false)
	if not excludeTeamID then
		return nil
	end

	local _, _, _, _, _, excludeAllyTeamID = spFunc.GetTeamInfo(excludeTeamID, false)
	if not excludeAllyTeamID then
		return nil
	end

	-- Find all active players on the same allyteam
	local playerList = Spring.GetPlayerList()
	local candidatePlayers = {}

	for _, playerID in ipairs(playerList) do
		if playerID ~= excludePlayerID then
			local _, active, isSpec, playerTeamID = spFunc.GetPlayerInfo(playerID, false)
			if active and not isSpec and playerTeamID then
				local _, _, _, _, _, playerAllyTeamID = spFunc.GetTeamInfo(playerTeamID, false)
				if playerAllyTeamID == excludeAllyTeamID then
					-- This player is on the same allyteam
					local skill = GetPlayerSkill(playerID)
					table.insert(candidatePlayers, {playerID = playerID, skill = skill})
				end
			end
		end
	end

	-- Sort by skill (highest first)
	if #candidatePlayers > 0 then
		table.sort(candidatePlayers, function(a, b)
			return a.skill > b.skill
		end)
		return candidatePlayers[1].playerID
	end

	return nil
end

local function UpdatePlayerTracking()
	if not interactionState.trackingPlayerID then
		return
	end

	-- Check if the tracked player has become a spectator or left
	local playerName, active, isSpec = spFunc.GetPlayerInfo(interactionState.trackingPlayerID, false)
	if not playerName then
		-- Player left the game, try to find next best player on the same team
		local nextPlayerID = FindNextBestTeamPlayer(interactionState.trackingPlayerID)
		interactionState.trackingPlayerID = nextPlayerID
		pipR2T.frameNeedsUpdate = true
		if not nextPlayerID then
			return
		end
		-- Continue tracking the new player
	elseif isSpec then
		-- Player became a spectator (died), try to find next best player on the same team
		local nextPlayerID = FindNextBestTeamPlayer(interactionState.trackingPlayerID)
		interactionState.trackingPlayerID = nextPlayerID
		pipR2T.frameNeedsUpdate = true
		if not nextPlayerID then
			return
		end
		-- Continue tracking the new player
	end

	-- Get player camera state from lockcamera widget's stored broadcasts
	if WG.lockcamera and WG.lockcamera.GetPlayerCameraState then
		-- Get the stored camera state for this player
		local playerCamState = WG.lockcamera.GetPlayerCameraState(interactionState.trackingPlayerID)

		if not playerCamState then
			-- Player stopped broadcasting - this can happen when:
			-- 1. Player actually stopped broadcasting (we should keep tracking)
			-- 2. Spectator disabled fullview (broadcasts filtered by gadget, keep tracking)
			-- Keep tracking and use last known position - tracking will resume when broadcasts return
			return
		end

		if playerCamState then
			-- Store camera state for tracking (but don't force immediate updates - let frame rate limiting handle it)
			cameraState.lastTrackedCameraState = playerCamState

			-- Extract position from camera state (different camera modes have different field names)
			-- Camera state can have: px, py, pz (spring/ta camera), x, y, z (free camera), etc.
			local camX, camY, camZ

			-- Try different camera mode field names
			if playerCamState.px then
				camX, camY, camZ = playerCamState.px, playerCamState.py, playerCamState.pz
			elseif playerCamState.x then
				camX, camY, camZ = playerCamState.x, playerCamState.y, playerCamState.z
			end

			-- Validate camera position - if invalid, skip this update and use last known position
			if not (camX and camZ and camX > 0 and camZ > 0 and camX < mapInfo.mapSizeX and camZ < mapInfo.mapSizeZ) then
				-- Invalid camera state, don't update anything this frame
				return
			end

			if camX and camZ then
				-- For tilted cameras, we need to project the view direction onto the ground
				-- Get camera direction/rotation if available
				local rx = playerCamState.rx or 0  -- Camera rotation around X axis (tilt) - in radians
				local ry = playerCamState.ry or 0  -- Camera rotation around Y axis (heading) - in radians
				local dist = playerCamState.dist  -- Camera distance (may be nil)
				local height = playerCamState.height or camY or 500

				-- Calculate ground point that camera is looking at
				-- For spring/overhead camera: the px,pz is roughly the point being looked at
				-- For other cameras, we need to project forward
				local lookAtX, lookAtZ = camX, camZ

				-- If camera has distance parameter, it's likely overhead/spring mode
				-- In that case, px/pz is already the ground point we want
				-- Apply forward offset for tilted cameras regardless of mode
				-- Calculate forward offset based on tilt angle
				-- rx is in radians, typically negative for looking down (e.g., -1.2 rad = ~69 degrees down)
				local tiltFromVertical = math.abs(rx)  -- How much tilted from straight down (0 = straight down, pi/2 = horizontal)
				local effectiveHeight = dist or height or 500
				if tiltFromVertical > 0.1 and effectiveHeight > 100 then
					-- Calculate forward offset: more tilt = more offset
					-- Use the effective viewing distance (dist or height)
					-- tan(tilt) gives the ratio of forward distance to height
					local forwardOffset = math.tan(tiltFromVertical) * effectiveHeight * -0.2
					
					-- Apply offset in the direction camera is facing (ry = heading/yaw in radians)
					-- Subtract to shift view toward where camera is actually looking
					--lookAtX = camX - math.sin(ry) * forwardOffset
					lookAtZ = camZ - math.cos(ry) * forwardOffset
				end

				cameraState.targetWcx = lookAtX
				cameraState.targetWcz = lookAtZ

				-- Adjust zoom based on camera distance/height to approximate the view scale
				-- Try to use actual camera zoom/distance/height from the player's camera
				-- The camera state might have: dist, height, or we can use camY
				local zoomValue = nil

				-- Calculate PIP size relative to main screen for accurate player view representation
				-- The tracked player's view is their full screen, so we need to adjust zoom
				-- based on how much smaller/larger the PIP is compared to their likely screen size
				local pipWidth = render.dim.r - render.dim.l
				local pipHeight = render.dim.t - render.dim.b
				local pipDiagonal = math.sqrt(pipWidth * pipWidth + pipHeight * pipHeight)
				-- Reference: assume tracked player has similar screen size to us
				local screenDiagonal = math.sqrt(render.vsx * render.vsx + render.vsy * render.vsy)
				-- Size ratio: if PIP is smaller, we need higher zoom to show same area
				-- pipSizeRatio < 1 means PIP is smaller than screen
				local pipSizeRatio = pipDiagonal / screenDiagonal

				-- First priority: use dist if available (spring/ta camera)
				-- Validate dist is reasonable (100-20000 range for overview support)
				if dist and dist > 100 and dist < 16000 then
					-- Spring camera distance scales inversely with zoom
					-- Typical range: 500-3000 for normal play, up to 15000+ for overview
					-- Base zoom from player's camera distance
					-- Higher constant = more zoomed in result
					local baseZoom = 2000 / dist
					-- Adjust zoom based on PIP size: smaller PIP = lower zoom to show same world area
					-- If PIP is half screen size, zoom should be halved to fit same view in smaller space
					zoomValue = baseZoom * pipSizeRatio
					-- Clamp to valid zoom range instead of discarding
					zoomValue = math.max(GetEffectiveZoomMin(), math.min(GetEffectiveZoomMax(), zoomValue))
				end

				-- Second priority: use height if dist not available
				-- Validate height is reasonable (100-15000 range for overview support)
				if not zoomValue and height and height > 100 and height < 15000 then
					-- Camera height scales inversely with zoom
					local baseZoom = 2400 / height
					-- Adjust zoom based on PIP size
					zoomValue = baseZoom * pipSizeRatio
					-- Clamp to valid zoom range instead of discarding
					zoomValue = math.max(GetEffectiveZoomMin(), math.min(GetEffectiveZoomMax(), zoomValue))
				end

				-- Apply zoom if we calculated one, but only if change is significant
				-- This prevents jitter from small floating-point variations
				if zoomValue then
					local zoomChangeThreshold = 0.05  -- Only update if zoom changes by more than 5%
					local zoomDiff = math.abs(zoomValue - cameraState.targetZoom)
					if zoomDiff > (cameraState.targetZoom * zoomChangeThreshold) then
						cameraState.targetZoom = zoomValue
					end
				end
			end
		end

		-- Apply map edge margin constraints
		local pipWidth, pipHeight = GetEffectivePipDimensions()
		local visibleWorldWidth = pipWidth / cameraState.targetZoom
		local visibleWorldHeight = pipHeight / cameraState.targetZoom

		cameraState.targetWcx = ClampCameraAxis(cameraState.targetWcx, visibleWorldWidth, mapInfo.mapSizeX, config.mapEdgeMargin)
		cameraState.targetWcz = ClampCameraAxis(cameraState.targetWcz, visibleWorldHeight, mapInfo.mapSizeZ, config.mapEdgeMargin)
	end
end

local function PipToWorldCoords(mx, my)
	-- Get current minimap rotation (must fetch fresh, not use cached render.minimapRotation)
	local minimapRotation = Spring.GetMiniMapRotation and Spring.GetMiniMapRotation() or 0
	
	-- Convert screen coordinates to normalized PIP coordinates (0-1)
	local normX = (mx - render.dim.l) / (render.dim.r - render.dim.l)
	local normY = (my - render.dim.b) / (render.dim.t - render.dim.b)
	
	-- Apply inverse rotation if minimap is rotated
	if minimapRotation ~= 0 then
		-- Translate to center (0.5, 0.5)
		local dx = normX - 0.5
		local dy = normY - 0.5
		
		-- Rotate back (inverse rotation = negative angle)
		local cosR = math.cos(-minimapRotation)
		local sinR = math.sin(-minimapRotation)
		local rotatedX = dx * cosR - dy * sinR
		local rotatedY = dx * sinR + dy * cosR
		
		-- Translate back
		normX = rotatedX + 0.5
		normY = rotatedY + 0.5
	end
	
	-- Convert normalized coordinates to world coordinates
	return render.world.l + (render.world.r - render.world.l) * normX,
		   render.world.b + (render.world.t - render.world.b) * normY
end
local function WorldToPipCoords(wx, wz)
	-- Use precalculated factors for performance (avoids repeated division)
	-- Rotation is now handled by matrix transformation in RenderPipContents
	return wtp.offsetX + wx * wtp.scaleX,
		   wtp.offsetZ + wz * wtp.scaleZ
end

-- Drawing
local function ResizeHandleVertices()
	glFunc.Vertex(render.dim.r, render.dim.b)
	glFunc.Vertex(render.dim.r - render.usedButtonSize, render.dim.b)
	glFunc.Vertex(render.dim.r, render.dim.b + render.usedButtonSize)
end
local function GroundTextureVertices()
	glFunc.TexCoord(render.ground.coord.l, render.ground.coord.b); glFunc.Vertex(render.ground.view.l, render.ground.view.b)
	glFunc.TexCoord(render.ground.coord.r, render.ground.coord.b); glFunc.Vertex(render.ground.view.r, render.ground.view.b)
	glFunc.TexCoord(render.ground.coord.r, render.ground.coord.t); glFunc.Vertex(render.ground.view.r, render.ground.view.t)
	glFunc.TexCoord(render.ground.coord.l, render.ground.coord.t); glFunc.Vertex(render.ground.view.l, render.ground.view.t)
end



-- Helper function to compute chamfered corner params based on screen bounds
-- Returns tl, tr, br, bl (TopLeft, TopRight, BottomRight, BottomLeft)
-- Corners are disabled (0) when the element touches or exceeds screen bounds
local function GetChamferedCorners(l, b, r, t)
	local atLeft = l <= 0
	local atBottom = b <= 0
	local atRight = r >= render.vsx
	local atTop = t >= render.vsy
	
	-- tl (TopLeft) - disabled if at left or top edge
	local tl = (atLeft or atTop) and 0 or 1
	-- tr (TopRight) - disabled if at right or top edge
	local tr = (atRight or atTop) and 0 or 1
	-- br (BottomRight) - disabled if at right or bottom edge
	local br = (atRight or atBottom) and 0 or 1
	-- bl (BottomLeft) - disabled if at left or bottom edge
	local bl = (atLeft or atBottom) and 0 or 1
	
	return tl, tr, br, bl
end

local function DrawGroundLine(x1, z1, x2, z2)
	local dx, dz = x2 - x1, z2 - z1
	for s = 0, 1, 0.0625 do
		local tx, tz = x1 + dx * s, z1 + dz * s
		glFunc.Vertex(tx, spFunc.GetGroundHeight(tx, tz) + 5.0, tz)
	end
end

local function DrawGroundBox(l, r, b, t, cornerSize)
	-- Draw octagon with corners cut off by 16 world units
	
	-- Handle coordinate system (b and t might be swapped depending on view)
	local minZ = math.min(b, t)
	local maxZ = math.max(b, t)
	
	-- Clamp corner size if rectangle is too small
	local width = r - l
	local height = maxZ - minZ
	local maxCorner = math.min(width, height) / 2
	local c = math.min(cornerSize, maxCorner)
	
	-- Draw 8 edges (going clockwise from top-left)
	-- Top edge (at maxZ)
	DrawGroundLine(l + c, maxZ, r - c, maxZ)
	-- Top-right corner cut
	DrawGroundLine(r - c, maxZ, r, maxZ - c)
	-- Right edge
	DrawGroundLine(r, maxZ - c, r, minZ + c)
	-- Bottom-right corner cut
	DrawGroundLine(r, minZ + c, r - c, minZ)
	-- Bottom edge (at minZ)
	DrawGroundLine(r - c, minZ, l + c, minZ)
	-- Bottom-left corner cut
	DrawGroundLine(l + c, minZ, l, minZ + c)
	-- Left edge
	DrawGroundLine(l, minZ + c, l, maxZ - c)
	-- Top-left corner cut
	DrawGroundLine(l, maxZ - c, l + c, maxZ)
end


local function DrawFeature(fID, noTextures)
	local fDefID = spFunc.GetFeatureDefID(fID)
	if not fDefID or cache.noModelFeatures[fDefID] then return end

	-- Skip energy-only features if option is enabled
	if hideEnergyOnlyFeatures then
		local fDef = FeatureDefs[fDefID]
		if fDef and (not fDef.metal or fDef.metal <= 0) and fDef.energy and fDef.energy > 0 then
			return
		end
	end

	local fx, fy, fz = spFunc.GetFeaturePosition(fID)
	if not fx then return end  -- Early exit if position is invalid

	local dirx, _, dirz = spFunc.GetFeatureDirection(fID)
	local uHeading = dirx and mapInfo.atan2(dirx, dirz) * mapInfo.rad2deg or 0

	glFunc.PushMatrix()
		glFunc.Translate(fx - cameraState.wcx, cameraState.wcz - fz, 0)
		glFunc.Rotate(90, 1, 0, 0)
		glFunc.Rotate(uHeading, 0, 1, 0)
		if not noTextures then
			glFunc.Texture(0, '%-' .. fDefID .. ':0')
		end
		gl.FeatureShape(fDefID, spFunc.GetFeatureTeam(fID))
	glFunc.PopMatrix()
end

-- Shared state for beam line drawing (avoids per-beam closure allocation)
local _line = {}
local function drawLine()
	glFunc.Vertex(_line.x1, _line.y1, 0)
	glFunc.Vertex(_line.x2, _line.y2, 0)
end

-- Shared state for per-vertex-colored line drawing (plasma trails)
local function drawColoredLine()
	glFunc.Color(_line.r, _line.g, _line.b, _line.a1)
	glFunc.Vertex(_line.x1, _line.y1, 0)
	glFunc.Color(_line.r, _line.g, _line.b, _line.a2)
	glFunc.Vertex(_line.x2, _line.y2, 0)
end

local function DrawProjectile(pID)
	local mSin, mCos, mAtan2, mMin, mMax, mLog = math.sin, math.cos, math.atan2, math.min, math.max, math.log
	local px, py, pz = spFunc.GetProjectilePosition(pID)
	if not px then return end

	local resScale = render.contentScale or 1

	-- Get projectile DefID - all projectiles from weapons will have this
	local pDefID = spFunc.GetProjectileDefID(pID)

	-- Get projectile size from cache or calculate it
	local size = 4 -- Default size
	-- Reuse color table (reset to default orange)
	pools.projectileColor[1], pools.projectileColor[2], pools.projectileColor[3], pools.projectileColor[4] = 1, 0.5, 0, 1
	local color = pools.projectileColor
	local width, height, isMissile, angle -- Initialize these early for blaster and missile handling

	if pDefID then
		-- This is a weapon projectile

		-- Check if this is a laser weapon (instant beam like BeamLaser - using cached data)
		if cache.weaponIsLaser[pDefID] then
			-- Get origin (owner unit position) and target
			local ownerID = spFunc.GetProjectileOwnerID(pID)
			local targetType, targetID = spFunc.GetProjectileTarget(pID)

			if ownerID then
				-- Use unit center as origin for lasers
				local ox, oy, oz = spFunc.GetUnitPosition(ownerID)

				if ox then
					local tx, ty, tz
					local hasValidTarget = false

					-- Try to get actual target position
					if targetType and targetID then
						if targetType == string.byte('u') then -- unit target
							local targetX, targetY, targetZ = spFunc.GetUnitPosition(targetID)
							if targetX then
								tx, ty, tz = targetX, targetY, targetZ
								hasValidTarget = true
							end
						elseif targetType == string.byte('f') then -- feature target
							local targetX, targetY, targetZ = spFunc.GetFeaturePosition(targetID)
							if targetX then
								tx, ty, tz = targetX, targetY, targetZ
								hasValidTarget = true
							end
						elseif targetType == string.byte('p') then -- projectile target
							local targetX, targetY, targetZ = spFunc.GetProjectilePosition(targetID)
							if targetX then
								tx, ty, tz = targetX, targetY, targetZ
								hasValidTarget = true
							end
						elseif targetType == string.byte('g') then -- ground target
							-- For ground targets, targetID is actually a table {x, y, z}
							if type(targetID) == "table" and #targetID >= 3 then
								tx, ty, tz = targetID[1], targetID[2], targetID[3]
								hasValidTarget = true
							end
						end
					end

					-- If no valid target, extend beam from origin through projectile to max range
					if not hasValidTarget then
						-- Calculate direction from unit origin to projectile
						local dx, dy, dz = px - ox, py - oy, pz - oz
						local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
						if dist > 0.1 then
							-- Normalize direction and extend to weapon range (using cached data)
							local range = cache.weaponRange[pDefID]
							local scale = range / dist
							tx = ox + dx * scale
							ty = oy + dy * scale
							tz = oz + dz * scale
						else
							-- Fallback if projectile is at origin
							local range = cache.weaponRange[pDefID]
							tx = ox + range
							ty = oy
							tz = oz
						end
					end

					-- Get weapon color and thickness from cached data
					local colorData = cache.weaponColor[pDefID]
					local thickness = cache.weaponThickness[pDefID]

					-- Store laser beam for rendering (with short lifetime)
					table.insert(cache.laserBeams, {
						ox = ox,
						oz = oz,
						tx = tx,
						tz = tz,
						r = colorData[1],
						g = colorData[2],
						b = colorData[3],
						thickness = thickness,
						startTime = gameTime
					})

					return -- Don't draw as a projectile
				end
			end
		end

		-- Check if this is a lightning weapon (LightningCannon - instant electric bolt)
		if cache.weaponIsLightning[pDefID] then
			-- Get origin (owner unit position) and target
			local ownerID = spFunc.GetProjectileOwnerID(pID)
			local targetType, targetID = spFunc.GetProjectileTarget(pID)

			if ownerID then
				-- Use unit center as origin for lightning
				local ox, oy, oz = spFunc.GetUnitPosition(ownerID)

				if ox then
					local tx, ty, tz
					local hasValidTarget = false

					-- Try to get actual target position
					if targetType and targetID then
						if targetType == string.byte('u') then -- unit target
							local targetX, targetY, targetZ = spFunc.GetUnitPosition(targetID)
							if targetX then
								tx, ty, tz = targetX, targetY, targetZ
								hasValidTarget = true
							end
						elseif targetType == string.byte('f') then -- feature target
							local targetX, targetY, targetZ = spFunc.GetFeaturePosition(targetID)
							if targetX then
								tx, ty, tz = targetX, targetY, targetZ
								hasValidTarget = true
							end
						elseif targetType == string.byte('g') then -- ground target
							-- For ground targets, targetID is actually a table {x, y, z}
							if type(targetID) == "table" and #targetID >= 3 then
								tx, ty, tz = targetID[1], targetID[2], targetID[3]
								hasValidTarget = true
							end
						end
					end

					-- If no valid target, use projectile position as target
					if not hasValidTarget then
						tx, ty, tz = px, py, pz
					end

					-- Get weapon color and thickness from cached data
					local colorData = cache.weaponColor[pDefID]
					local thickness = cache.weaponThickness[pDefID]

					-- Draw lightning bolt directly (no caching)
					-- Generate lightning bolt path with jagged segments
					local segmentSeed = pID * 12345.6789
					local numSegments = 10
					local dx = (tx - ox) / numSegments
					local dz = (tz - oz) / numSegments
					local dist2D = math.sqrt(dx*dx + dz*dz)
					local boltJitter = dist2D * 0.25

					-- Precompute zoom-dependent scaling
					local zoomScale = math.max(0.5, cameraState.zoom / 70)
					local baseOuterWidth = thickness * 9 * zoomScale * resScale
					local baseInnerWidth = thickness * 2.2 * zoomScale * resScale

					-- Draw segments
					local prevX = ox
					local prevZ = oz
					local prevBrightness = 0.7 + math.sin(segmentSeed) * 0.3

					for i = 1, numSegments do
						local segX, segZ, brightness

						if i == numSegments then
							segX, segZ = tx, tz
							brightness = 1.2
						else
							local baseX = ox + dx * i
							local baseZ = oz + dz * i
							local perpX = -dz / dist2D
							local perpZ = dx / dist2D
							local jitter = math.sin((segmentSeed + i) * 43758.5453) * boltJitter
							brightness = 0.5 + math.abs(math.sin((segmentSeed + i * 7.1234) * 12.9898)) * 1.0

							segX = baseX + perpX * jitter
							segZ = baseZ + perpZ * jitter
						end

						local avgBrightness = (prevBrightness + brightness) * 0.5

						if gl4Prim.enabled then
							local coreR = 0.9 + colorData[1] * 0.1
							local coreG = 0.9 + colorData[2] * 0.1
							local coreB = 0.95 + colorData[3] * 0.05
							GL4AddGlowLine(prevX, prevZ, segX, segZ,
								colorData[1], colorData[2], colorData[3], 0.4 * avgBrightness)
							GL4AddCoreLine(prevX, prevZ, segX, segZ,
								coreR, coreG, coreB, 0.98 * avgBrightness)
						end

						-- Move to next segment
						prevX, prevZ = segX, segZ
						prevBrightness = brightness
					end

					glFunc.LineWidth(1 * resScale)

					-- Draw small explosion effect at target point immediately
					local explosionRadius = 8
					local baseRadius = explosionRadius * 1.0
					local alpha = 1.0
					local r, g, b = 0.9, 0.95, 1

					if gl4Prim.enabled then
						local glowRadius = baseRadius * 5.8
						GL4AddCircle(tx, tz, glowRadius, alpha * 0.5,
							r*0.7, g*0.7, b*0.8,  r*0.4, g*0.4, b*0.5,  0, 0)
						local coreRadius = baseRadius * 0.4
						GL4AddCircle(tx, tz, coreRadius, alpha * 0.95,
							1, 1, 1,  r*0.8, g*0.8, b,  alpha * 0.5, 0)
					end

					return -- Don't draw as a projectile
				end
			end
		end

		-- Check if this is a flame weapon (Flame - particle stream effect)
		if cache.weaponIsFlame[pDefID] then
			-- Get or create cached per-particle seeds (computed once at birth, not every frame)
			local seeds = cache.flameSeeds[pID]
			if not seeds then
				local ps = pID * 789.012
				seeds = {
					(mSin(ps * 12.9898) * 2 - 1) * 4,   -- offX
					(mSin(ps * 78.233) * 2 - 1) * 4,    -- offZ
					10 + (mSin(ps * 43.758) % 1) * 4,   -- baseSize (abs via modulo)
					(mSin(ps * 91.321) % 1),            -- v1 (0-1)
					(mSin(ps * 37.819) % 1),            -- v2 (0-1)
					mSin(ps * 63.241),                   -- v3 (-1 to 1)
				}
				cache.flameSeeds[pID] = seeds
				cache.flameBirthTime[pID] = gameTime
			end
			local offsetX, offsetZ, particleSize = seeds[1], seeds[2], seeds[3]
			local v1, v2, v3 = seeds[4], seeds[5], seeds[6]

			-- Compute age from cached birth time
			local lifetime = cache.flameLifetime[pDefID] or 1.0
			local elapsed = gameTime - cache.flameBirthTime[pID]
			local age = elapsed < lifetime and elapsed / lifetime or 1

			local r, g, b, alpha

			if age < 0.35 then
				-- FRONT: white-hot to bright yellow — the active flame, longest phase
				local t = age / 0.35
				r = 1.0
				g = 0.95 - t * (0.15 + v2 * 0.05)
				b = 0.65 - t * (0.55 + v1 * 0.08)
				alpha = 1.0
			elseif age < 0.65 then
				-- MID: yellow → orange → red, with variation
				local t = (age - 0.35) / 0.3
				r = 1.0 - t * 0.08 * v2
				g = (0.75 - t * 0.5) * (0.7 + v1 * 0.3)
				b = 0.1 * (1 - t) * v2
				-- Occasionally inject brighter yellow patches
				if v3 > 0.4 then
					g = g + 0.12
				end
				alpha = 0.95 - t * 0.1
			else
				-- TAIL: dark red with heavy variation (age 0.65 → 1.0)
				local t = (age - 0.65) / 0.35
				local darkening = 0.25 + t * 0.5
				-- Base: dark smoky red
				r = (0.8 - darkening) * (0.6 + v1 * 0.4)
				g = (0.15 - t * 0.1) * (0.3 + v2 * 0.7)
				b = 0.02 * (1 - t)
				-- Random flame bursts: some particles stay red-yellow
				if v3 > 0.45 then
						r = mMin(1, r + 0.35)
					g = g + 0.15 * (1 - t)
				end
				-- Random near-black: some particles go very dark
				if v3 < -0.3 then
					r = r * 0.35
					g = g * 0.25
				end
				alpha = 0.8 - t * 0.35
			end

			-- Grow particles as they age
			particleSize = particleSize * (1 + age * 0.6)

			if gl4Prim.enabled then
				GL4AddCircle(px + offsetX, pz - offsetZ, particleSize, alpha,
					mMin(1, r*1.2), mMin(1, g*1.2), mMin(1, b*1.2),
					r, g, b, 0.55 * alpha, 0)
			end
			return -- Don't draw as regular projectile
		end

		-- Check if this is a blaster weapon (LaserCannon - traveling projectile)
		if cache.weaponIsBlaster[pDefID] then
			-- Get weapon color from cached data
			local colorData = cache.weaponColor[pDefID]
			color = {colorData[1], colorData[2], colorData[3], 1}

			-- Bolt dimensions based on weapon size + damage (explosion radius as proxy)
			local wSize = cache.weaponSize[pDefID] or 1
			local explosionR = cache.weaponExplosionRadius[pDefID] or 10
			-- Damage factor: small lasers (AOE<20) ~0.7, medium ~1.0, heavy (AOE>80) ~1.4
			local damageFactor = 0.6 + math.min(0.8, explosionR * 0.01)

			-- Gentle zoom boost: keeps bolts visible when zoomed out without ballooning
			-- zoom 0.02: ~2.2x, zoom 0.05: ~1.8x, zoom 0.1: ~1.5x, zoom 0.3: ~1.2x
			local blasterZoom = 1.6 + 0.6 / (cameraState.zoom + 0.1)

			-- Bolt width: narrow but visible, proportional to damage
			width = wSize * 0.5 * damageFactor * blasterZoom
			-- Bolt length: elongated, proportional to damage
			height = wSize * 2.5 * damageFactor * blasterZoom

			-- Calculate angle from velocity direction
			local vx, vy, vz = spFunc.GetProjectileVelocity(pID)
			if vx and (vx ~= 0 or vz ~= 0) then
				angle = mAtan2(vx, vz) * mapInfo.rad2deg
			end
		-- Non-laser, non-blaster weapon projectiles - use cached size data
		elseif not cache.projectileSizes[pDefID] then
			-- Get size from cached weapon data
			local wSize = cache.weaponSize[pDefID]
			if wSize then
				-- Scale smaller projectiles up more; diminishing returns for large ones
				if wSize < 2 then
					cache.projectileSizes[pDefID] = wSize * 1.2 -- Small projectiles: scale by 1.2
				elseif wSize < 4 then
					cache.projectileSizes[pDefID] = wSize * 1.5 -- Medium-small: scale by 1.5
				elseif wSize < 6 then
					cache.projectileSizes[pDefID] = wSize * 1.8 -- Medium: scale by 1.8
				else
					-- Large projectiles: logarithmic scaling to prevent oversized missiles
					-- wSize 6 → 10.8, wSize 10 → 14.5, wSize 20 → 19.3
					cache.projectileSizes[pDefID] = 6 * 1.8 * (1 + mLog(wSize / 6) * 0.55)
				end
			else
				cache.projectileSizes[pDefID] = 4
			end
		size = cache.projectileSizes[pDefID]
	else
		size = cache.projectileSizes[pDefID]
	end

	-- Only set color for non-blaster weapons
		if not cache.weaponIsBlaster[pDefID] then
			color = pools.yellowColor
		end
	else
		-- This is debris or other non-weapon projectile
		size = 2
		color = pools.greyColor
	end

	-- Draw projectile as a quad (rectangular for missiles, square for others)
	-- Initialize dimensions if not already set (by blaster code)
	if not width then
		width = size
		height = size
	end
	if not isMissile then
		isMissile = false
	end
	if not angle then
		angle = 0
	end

	-- Scale projectiles to be visible at all zoom levels (smooth, no hard thresholds)
	-- Low zoom (zoomed out): inversely scale so projectiles stay visible
	-- High zoom (zoomed in): scale up proportionally
	-- zoom 0.02: ~3.5x, zoom 0.05: ~2.7x, zoom 0.1: ~2.1x, zoom 0.2: ~1.7x, zoom 0.5: ~1.4x, zoom 0.8: ~2.6x
	local zoomScale = 1 + (cameraState.zoom * 2) + 0.15 / (cameraState.zoom + 0.05)
	-- Blasters handle their own sizing (fixed world-scale bolts); skip general zoom scaling
	if not (pDefID and cache.weaponIsBlaster[pDefID]) then
		width = width * zoomScale
		height = height * zoomScale
	end

	-- Make missiles longer rectangles and calculate orientation (using cached data)
	if pDefID and cache.weaponIsMissile[pDefID] then
		isMissile = true

		-- Check if this is a nuke missile (large explosion radius)
		local isNuke = cache.weaponExplosionRadius[pDefID] and cache.weaponExplosionRadius[pDefID] > 150

		if isNuke then
			-- Nuke missiles are smaller - they're already visually impressive (15% smaller)
			height = size * 2 * 1.7 * 1.4 * 1.33 * 0.6 * 0.85
			width = size * 0.6 * 1.33 * 0.6 * 0.85
		else
			-- Normal missiles (15% smaller)
			height = size * 2 * 1.7 * 1.4 * 1.33 * 0.85
			width = size * 0.6 * 1.33 * 0.85
		end

		-- Calculate orientation based on actual velocity direction (not target)
		-- This ensures missiles face where they're actually going, even if they miss
		local vx, vy, vz = spFunc.GetProjectileVelocity(pID)
		if vx and (vx ~= 0 or vz ~= 0) then
			-- Calculate angle based on velocity direction
			angle = mAtan2(vx, vz) * mapInfo.rad2deg
		elseif cache.weaponIsStarburst[pDefID] then
			-- Starburst missiles launching straight up (only vy) should point upward
			angle = 180
		end
		
		-- Add smoke trail for missiles (including starburst)
		-- Skip trails for small missiles when zoomed out (they're just tiny dots)
		local missileSize = cache.weaponSize[pDefID] or 1
		local showTrail = missileSize >= 3 or cameraState.zoom >= 0.15 or isNuke
		if showTrail then
		do
			-- Get or create trail data for this projectile
			local trail = cache.missileTrails[pID]
			local isStarburst = cache.weaponIsStarburst[pDefID]
			local isAA = cache.weaponIsAA[pDefID]
			local isTorpedo = cache.weaponIsTorpedo[pDefID]
			local isParalyze = cache.weaponIsParalyze[pDefID]
			local isJuno = cache.weaponIsJuno[pDefID]
			if not trail then
				-- Pre-allocate position slots to avoid repeated table creation
				-- Use ring buffer pattern: positions stored at indices, head points to newest
				local missileSize = cache.weaponSize[pDefID] or 1

				-- Trail lifetime determines visual length; ring buffer must hold enough
				-- positions to fill it. Derive both from speed.
				local trailLen
				local projSpeed = 10  -- default fallback (elmos/frame)
				local wDef = WeaponDefs and WeaponDefs[pDefID]
				if wDef and wDef.projectilespeed then
					projSpeed = wDef.projectilespeed * 30
				end

				-- Slower missiles get longer-lingering trails
				-- speed 3 → 3.5s, speed 10 → 2.3s, speed 20+ → 1.0s
				local trailLife
				local trailInterval
				if isStarburst then
					trailLife = 3.0
					trailInterval = 0.12
				else
					trailLife = math.max(1.0, 3.5 - projSpeed * 0.125)
					trailInterval = 0.04
				end
				-- Enough ring buffer slots to cover the full lifetime + small margin
				trailLen = math.ceil(trailLife / trailInterval) + 2

				trail = {positions = {}, head = 0, count = 0, maxLen = trailLen,
					lastUpdate = 0, isStarburst = isStarburst, isAA = isAA, isTorpedo = isTorpedo, isParalyze = isParalyze, isJuno = isJuno, size = missileSize,
					speed = projSpeed, trailLife = trailLife}
				cache.missileTrails[pID] = trail
			end
			
			local maxTrailLength = trail.maxLen
			local now = os.clock()
			
			-- Add current position to trail using ring buffer (O(1) instead of O(n))
			-- Starburst missiles use 3x longer update interval for longer trails without more positions
			local trailUpdateInterval = isStarburst and 0.12 or 0.04
			if now - trail.lastUpdate >= trailUpdateInterval then
				trail.head = trail.head + 1
				if trail.head > maxTrailLength then trail.head = 1 end
				
				-- Reuse existing position table or create new one
				local pos = trail.positions[trail.head]
				if pos then
					pos.x, pos.z, pos.time = px, pz, now
				else
					trail.positions[trail.head] = {x = px, z = pz, time = now}
				end
				
				trail.lastUpdate = now
				if trail.count < maxTrailLength then
					trail.count = trail.count + 1
				end
			end
			
			-- Draw smoke trail (dark semi-transparent lines fading away)
			local trailCount = trail.count
			if trailCount >= 2 then
				-- Trail lifetime stored per-trail at creation (derived from missile speed)
				local trailLifetime, invTrailLifetime, trailColorR, trailColorG, trailColorB
				trailLifetime = trail.trailLife
				invTrailLifetime = 1 / trailLifetime
				if trail.isStarburst then
					trailColorR, trailColorG, trailColorB = 0.12, 0.12, 0.12  -- Darker smoke
				elseif trail.isJuno then
					trailColorR, trailColorG, trailColorB = 0.2, 0.45, 0.2  -- Green Juno trail
				elseif trail.isAA then
					trailColorR, trailColorG, trailColorB = 0.85, 0.45, 0.55  -- Rose pink
				elseif trail.isParalyze then
					trailColorR, trailColorG, trailColorB = 0.4, 0.35, 0.75  -- Blue-violet paralyzer trail
				elseif trail.isTorpedo then
					trailColorR, trailColorG, trailColorB = 0.25, 0.3, 0.42  -- Grey-blue bubble trail
				else
					trailColorR, trailColorG, trailColorB = 0.22, 0.22, 0.22
				end
				local wcx, wcz = cameraState.wcx, cameraState.wcz
				local positions = trail.positions
				local head = trail.head
				local trailNow = os.clock()
				
				-- Set line width proportional to missile body size
				-- Missile bodies bypass zoomScale (fixed world-unit size), so trails should too
				-- Gentle zoom factor: thin when zoomed out (matching tiny missile dots),
				-- slightly wider when zoomed in
				local resScale = render.contentScale or 1
				local trailZoom = 0.8 + cameraState.zoom * 2  -- 0.85 at zoom 0.024, 1.0 at 0.1, 1.8 at 0.5
				local trailWidth = math.max(1.0 * resScale, trail.size * 0.5 * trailZoom * resScale)
				glFunc.LineWidth(trailWidth)

				-- Batch all trail lines in a single BeginEnd call
				glFunc.BeginEnd(glConst.LINES, function()
					for i = 0, trailCount - 2 do
						-- Ring buffer indexing: head is newest, go backwards
						local idx1 = head - i
						if idx1 < 1 then idx1 = idx1 + maxTrailLength end
						local idx2 = head - i - 1
						if idx2 < 1 then idx2 = idx2 + maxTrailLength end
						
						local p1 = positions[idx1]
						local p2 = positions[idx2]
						if p1 and p2 then
							-- Calculate fade based on wall-clock time
							local fade1 = 1 - (trailNow - p1.time) * invTrailLifetime
							local fade2 = 1 - (trailNow - p2.time) * invTrailLifetime
							if fade1 < 0 then fade1 = 0 end
							if fade2 < 0 then fade2 = 0 end
							
							if fade1 > 0 or fade2 > 0 then
								glFunc.Color(trailColorR, trailColorG, trailColorB, 0.7 * fade1)
								glFunc.Vertex(p1.x - wcx, wcz - p1.z, 0)
								glFunc.Color(trailColorR, trailColorG, trailColorB, 0.7 * fade2)
								glFunc.Vertex(p2.x - wcx, wcz - p2.z, 0)
							end
						end
					end
				end)
				glFunc.LineWidth(1 * resScale)
			end
		end
		end -- showTrail
	end

	-- GL4 path: add projectile shapes directly in world coords
	if pDefID and cache.weaponIsBlaster[pDefID] then
		-- Outer glow: slightly wider and longer than core, semi-transparent weapon color
		GL4AddQuad(px, pz, width * 1.6, height * 1.1, angle, color[1], color[2], color[3], color[4] * 0.35)
		-- Inner core: narrow bright bolt, white-shifted for hot center
		local whiteness = 0.7
		local coreR = color[1] * (1 - whiteness) + whiteness
		local coreG = color[2] * (1 - whiteness) + whiteness
		local coreB = color[3] * (1 - whiteness) + whiteness
		GL4AddQuad(px, pz, width * 0.7, height * 0.85, angle, coreR, coreG, coreB, color[4] * 0.95)
	elseif pDefID and cache.weaponIsMissile[pDefID] then
		-- Missile shape: body + nose + tail fins offset along flight direction
		local rad = angle * 0.01745329  -- pi/180
		local sinA = mSin(rad)
		local cosA = mCos(rad)

		-- Color variants from cache (computed once at init)
		local mc = cache.missileColors[pDefID]
		if not mc then mc = cache.missileColors[0] end  -- fallback default
		local bodyR, bodyG, bodyB = mc[1], mc[2], mc[3]
		local noseR, noseG, noseB = mc[4], mc[5], mc[6]
		local finR, finG, finB = mc[7], mc[8], mc[9]

		-- Main body: shifted 0.2*height forward (matching legacy -0.7h to +0.3h center)
		local bodyFwd = height * 0.2
		GL4AddQuad(px + sinA * bodyFwd, pz + cosA * bodyFwd,
			width, height * 0.5, angle, bodyR, bodyG, bodyB, color[4])

		-- Nose cone: narrow tapered quad at the front tip
		local noseFwd = height * 0.82
		GL4AddQuad(px + sinA * noseFwd, pz + cosA * noseFwd,
			width * 0.3, height * 0.2, angle, noseR, noseG, noseB, color[4])

		-- Tail fins: wider short quad at the back, swept shape
		local finFwd = -height * 0.18
		GL4AddQuad(px + sinA * finFwd, pz + cosA * finFwd,
			width * 2.0, height * 0.18, angle, finR, finG, finB, color[4] * 0.85)

		-- Exhaust glow at the very back
		local exhFwd = -height * 0.38
		local exhR, exhG, exhB = mc[10], mc[11], mc[12]
		GL4AddQuad(px + sinA * exhFwd, pz + cosA * exhFwd,
			width * 0.5, height * 0.1, angle, exhR, exhG, exhB, color[4] * 0.6)
	elseif pDefID and cache.weaponIsBomb[pDefID] then
		-- Aircraft bomb: grey-white rectangle with pointy nose
		local vx, vy, vz = spFunc.GetProjectileVelocity(pID)
		local bombAngle = 0
		if vx and (vx ~= 0 or vz ~= 0) then
			bombAngle = mAtan2(vx, vz) * mapInfo.rad2deg
		end

		-- Scale bomb size with explosion radius as damage proxy (bigger AOE = bigger bomb)
		local explosionR = cache.weaponExplosionRadius[pDefID] or 10
		local damageFactor = 0.6 + mMin(0.6, explosionR * 0.004) -- 0.64 (small) to 1.2 (big AOE)
		local bombSize = (cache.weaponSize[pDefID] or 2) * 0.7 * damageFactor
		local bombW = bombSize * 1.3 * zoomScale
		local bombH = bombSize * 1.8 * zoomScale

		-- Main body: grey-white rectangle
		local rad = bombAngle * 0.01745329
		local sinA = mSin(rad)
		local cosA = mCos(rad)

		GL4AddQuad(px, pz, bombW, bombH * 0.45, bombAngle, 0.73, 0.73, 0.71, 1.0)

		-- Pointy nose cone: narrow tapered quad at the front
		local noseFwd = bombH * 0.6
		GL4AddQuad(px + sinA * noseFwd, pz + cosA * noseFwd,
			bombW * 0.33, bombH * 0.18, bombAngle, 0.73, 0.73, 0.71, 1.0)

		-- Tail fins: wider short quad at the back
		-- local finFwd = -bombH * 0.35
		-- GL4AddQuad(px + sinA * finFwd, pz + cosA * finFwd,
		-- 	bombW * 1.6, bombH * 0.12, bombAngle, 0.64, 0.64, 0.62, 0.9)
	elseif pDefID and cache.weaponIsPlasma[pDefID] then
		-- Plasma gradient circle (reduce size when zoomed in to stay proportional to world scale)
		local plasmaZoomReduction = mMin(1, 0.45 + 0.55 * (1 - cameraState.zoom))
		local radius = mMax(width, height) * plasmaZoomReduction
		local coreWhiteness = 0.9
		local coreR, coreG, coreB, outerR, outerG, outerB
		if cache.weaponIsAA[pDefID] then
			-- AA plasma: rose pink tint (matching AA missile trails)
			coreR = 1.0; coreG = 0.85; coreB = 0.9
			outerR = 0.9; outerG = 0.4; outerB = 0.55
		else
			coreR = color[1] * (1 - coreWhiteness) + coreWhiteness
			coreG = color[2] * (1 - coreWhiteness) + coreWhiteness
			coreB = color[3] * (1 - coreWhiteness) + coreWhiteness
			local orangeTint = 0.4
			outerR = math.min(1, color[1] + orangeTint)
			outerG = math.max(0, color[2] - orangeTint * 0.3)
			outerB = math.max(0, color[3] - orangeTint * 0.5)
		end
		GL4AddCircle(px, pz, radius, color[4], coreR, coreG, coreB, outerR, outerG, outerB, color[4], 0)

		-- Plasma trail: short fading trail for artillery/cannon projectiles with CEG trails
		-- Uses game frames instead of os.clock() so trails don't elongate during catchup
		local trailColor = config.drawPlasmaTrails and cache.weaponPlasmaTrailColor[pDefID]
		if trailColor then
			local trail = cache.plasmaTrails[pID]
			local gameFrame = Spring.GetGameFrame()
			if not trail then
				-- Short ring buffer: 6 slots for max ~4 visible line segments
				local projSpeed = 10
				local wDef = WeaponDefs and WeaponDefs[pDefID]
				if wDef and wDef.projectilespeed then
					projSpeed = wDef.projectilespeed * 30
				end
				-- Slower projectiles get slightly longer trails (in game frames, 30fps)
				-- speed 3 → 18 frames (0.6s), speed 10 → ~15 frames (0.5s), speed 20+ → ~8 frames (0.25s)
				local trailLifeFrames = mMax(8, mMin(18, math.floor((0.8 - projSpeed * 0.03) * 30)))
				local trailUpdateInterval = 2  -- Record position every 2 game frames
				trail = {positions = {}, head = 0, count = 0, maxLen = 6,
					lastUpdate = 0, trailLifeFrames = trailLifeFrames,
					updateInterval = trailUpdateInterval,
					size = cache.weaponSize[pDefID] or 1}
				cache.plasmaTrails[pID] = trail
			end

			-- Update position ring buffer (game frame based)
			if gameFrame - trail.lastUpdate >= trail.updateInterval then
				trail.head = trail.head + 1
				if trail.head > trail.maxLen then trail.head = 1 end
				local pos = trail.positions[trail.head]
				if pos then
					pos.x, pos.z, pos.frame = px, pz, gameFrame
				else
					trail.positions[trail.head] = {x = px, z = pz, frame = gameFrame}
				end
				trail.lastUpdate = gameFrame
				if trail.count < trail.maxLen then trail.count = trail.count + 1 end
			end

			-- Draw trail lines — each segment gets its own width (diminishing 15% per step)
			local trailCount = trail.count
			if trailCount >= 2 then
				local invLife = 1 / trail.trailLifeFrames
				local tR, tG, tB = trailColor[1], trailColor[2], trailColor[3]
				local wcx, wcz = cameraState.wcx, cameraState.wcz
				local positions = trail.positions
				local head = trail.head
				local maxLen = trail.maxLen
				local resScale = render.contentScale or 1
				-- Trail width = plasma ball's on-screen pixel diameter (via world-to-pixel scale)
				-- wtp.scaleX converts world units to screen pixels; naturally shrinks when zoomed out
				local baseWidth = mMin(radius * wtp.scaleX * 2, 14 * resScale)
				if baseWidth < 1.5 * resScale then baseWidth = 1.5 * resScale end
				local minSegW = 1.0 * resScale
				local segDecay = 1.0
				_line.r, _line.g, _line.b = tR, tG, tB

				for j = 0, trailCount - 2 do
					local idx1 = head - j
					if idx1 < 1 then idx1 = idx1 + maxLen end
					local idx2 = head - j - 1
					if idx2 < 1 then idx2 = idx2 + maxLen end
					local p1 = positions[idx1]
					local p2 = positions[idx2]
					if p1 and p2 then
						local fade1 = 1 - (gameFrame - p1.frame) * invLife
						local fade2 = 1 - (gameFrame - p2.frame) * invLife
						if fade1 < 0 then fade1 = 0 end
						if fade2 < 0 then fade2 = 0 end
						if fade1 > 0 or fade2 > 0 then
							local segWidth = baseWidth * segDecay
							if segWidth < minSegW then segWidth = minSegW end
							_line.x1 = p1.x - wcx
							_line.y1 = wcz - p1.z
							_line.x2 = p2.x - wcx
							_line.y2 = wcz - p2.z
							_line.a1 = 0.75 * fade1
							_line.a2 = 0.75 * fade2
							glFunc.LineWidth(segWidth)
							glFunc.BeginEnd(glConst.LINES, drawColoredLine)
						end
					end
					segDecay = segDecay * 0.85
				end
				glFunc.LineWidth(1 * resScale)
			end
		end
	end
end

local function DrawLaserBeams()
	if #cache.laserBeams == 0 then return end
	local mMax, mMin = math.max, math.min

	local n = #cache.laserBeams
	local i = 1

	-- Precompute zoom-dependent scaling once
	local resScale = render.contentScale or 1
	-- Zoom-dependent beam width: scale down when zoomed out so beams don't dominate the view
	-- At zoom 0.024 (full map): ~0.55, at zoom 0.1: ~0.85, at zoom 0.3+: ~1.0
	local zoomScale = mMin(1.0, 0.4 + cameraState.zoom * 4)
	local wcx_cached = cameraState.wcx  -- Cache these for loop
	local wcz_cached = cameraState.wcz

	-- Cache world boundaries for culling
	local worldLeft = render.world.l
	local worldRight = render.world.r
	local worldTop = render.world.t
	local worldBottom = render.world.b

	while i <= n do
		local beam = cache.laserBeams[i]
		local age = gameTime - beam.startTime

		-- Remove beams older than 0.15 seconds (swap-to-end compaction)
		if age > 0.15 then
			cache.laserBeams[i] = cache.laserBeams[n]
			cache.laserBeams[n] = nil
			n = n - 1
		else
			-- Check if beam is within visible world bounds (with small margin for beam thickness)
			local margin = 50
			local beamMinX, beamMaxX, beamMinZ, beamMaxZ
			if beam.isLightning then
				-- For lightning, check all segments
				beamMinX, beamMaxX = math.huge, -math.huge
				beamMinZ, beamMaxZ = math.huge, -math.huge
				for j = 1, #beam.segments do
					local seg = beam.segments[j]
					if seg.x < beamMinX then beamMinX = seg.x end
					if seg.x > beamMaxX then beamMaxX = seg.x end
					if seg.z < beamMinZ then beamMinZ = seg.z end
					if seg.z > beamMaxZ then beamMaxZ = seg.z end
				end
			else
				-- For regular beams, check origin and target
				beamMinX = beam.ox < beam.tx and beam.ox or beam.tx
				beamMaxX = beam.ox > beam.tx and beam.ox or beam.tx
				beamMinZ = beam.oz < beam.tz and beam.oz or beam.tz
				beamMaxZ = beam.oz > beam.tz and beam.oz or beam.tz
			end

		-- Skip if beam is completely outside visible area
		-- Check that at least one endpoint (origin OR target) overlaps the visible area
		local beamMargin = 200
		if beamMaxX < worldLeft - beamMargin or beamMinX > worldRight + beamMargin or
		   beamMaxZ < worldTop - beamMargin or beamMinZ > worldBottom + beamMargin then
			i = i + 1
		else
			-- Check if this is a lightning bolt (segmented) or regular laser beam
			if beam.isLightning then
				-- Draw lightning bolt with jagged segments
				local alpha = 1 - (age / 0.15) -- Fade out over lifetime
				local glowLW = mMax(1, beam.thickness * 4.5 * zoomScale * resScale)
				local coreLW = mMax(1, beam.thickness * 1.4 * zoomScale * resScale)
				local coreR = 0.9 + beam.r * 0.1
				local coreG = 0.9 + beam.g * 0.1
				local coreB = 0.95 + beam.b * 0.05

				for j = 1, #beam.segments - 1 do
					local seg1 = beam.segments[j]
					local seg2 = beam.segments[j + 1]
					local avgBrightness = (seg1.brightness + seg2.brightness) * 0.5
					_line.x1 = seg1.x - cameraState.wcx
					_line.y1 = cameraState.wcz - seg1.z
					_line.x2 = seg2.x - cameraState.wcx
					_line.y2 = cameraState.wcz - seg2.z

					glFunc.LineWidth(glowLW)
					glFunc.Color(beam.r, beam.g, beam.b, alpha * 0.4 * avgBrightness)
					glFunc.BeginEnd(GL.LINES, drawLine)
					glFunc.LineWidth(coreLW)
					glFunc.Color(coreR, coreG, coreB, alpha * 0.98 * avgBrightness)
					glFunc.BeginEnd(GL.LINES, drawLine)
				end
			else
				-- Draw regular laser beam as a line with glow effect
				local alpha = 1 - (age / 0.15) -- Fade out over lifetime
				local thickness = beam.thickness or 2
				-- Scale thickness: thin beams stay thin, thick beams get moderate presence
				local scaledThickness = (0.4 + thickness * 0.3) * zoomScale

				-- Transform world coords to PushMatrix local coords
				_line.x1 = beam.ox - cameraState.wcx
				_line.y1 = cameraState.wcz - beam.oz
				_line.x2 = beam.tx - cameraState.wcx
				_line.y2 = cameraState.wcz - beam.tz

				-- Glow layer (outer, colored, additive-like via alpha)
				local glowWidth = mMax(1, mMin(8 * resScale, scaledThickness * 2.8 * resScale))
				glFunc.LineWidth(glowWidth)
				glFunc.Color(beam.r, beam.g, beam.b, alpha * 0.35)
				glFunc.BeginEnd(GL.LINES, drawLine)

				-- Core layer (inner, whitened, bright) — use higher proportion for big lasers
				local whiteness = 0.4 + (thickness / 10) * 0.4
				local coreR = beam.r * (1 - whiteness) + whiteness
				local coreG = beam.g * (1 - whiteness) + whiteness
				local coreB = beam.b * (1 - whiteness) + whiteness
				local coreWidth = mMax(1, mMin(3 * resScale, scaledThickness * 1.2 * resScale))
				glFunc.LineWidth(coreWidth)
				glFunc.Color(coreR, coreG, coreB, alpha * 0.98)
				glFunc.BeginEnd(GL.LINES, drawLine)
			end

				i = i + 1
			end
		end
	end

	-- Reset line width once at the end
	glFunc.LineWidth(1 * resScale)
end

-- Shared state for fragment quad drawing (avoids per-fragment closure allocation)
local _frag = {}
local function drawFragQuad()
	local hs = _frag.hs
	glFunc.TexCoord(_frag.uvx1, _frag.uvy2)
	glFunc.Vertex(-hs, -hs, 0)
	glFunc.TexCoord(_frag.uvx2, _frag.uvy2)
	glFunc.Vertex(hs, -hs, 0)
	glFunc.TexCoord(_frag.uvx2, _frag.uvy1)
	glFunc.Vertex(hs, hs, 0)
	glFunc.TexCoord(_frag.uvx1, _frag.uvy1)
	glFunc.Vertex(-hs, hs, 0)
end

-- Octagon vertex helper (untextured, for borders) — module-level to avoid per-frame re-definition
local function drawOctagonVertices(cx, cy, s, c)
	glFunc.Vertex(cx, cy, 0)
	glFunc.Vertex(cx - s + c, cy - s, 0)
	glFunc.Vertex(cx + s - c, cy - s, 0)
	glFunc.Vertex(cx + s, cy - s + c, 0)
	glFunc.Vertex(cx + s, cy + s - c, 0)
	glFunc.Vertex(cx + s - c, cy + s, 0)
	glFunc.Vertex(cx - s + c, cy + s, 0)
	glFunc.Vertex(cx - s, cy + s - c, 0)
	glFunc.Vertex(cx - s, cy - s + c, 0)
	glFunc.Vertex(cx - s + c, cy - s, 0)
end

-- Textured octagon vertex helper (for unitpic texture, Y-flipped) — module-level
local function drawTexturedOctagonVertices(cx, cy, s, c, texIn)
	local t0, t1 = texIn, 1 - texIn
	local tRange = t1 - t0
	local tMid = (t0 + t1) * 0.5
	local inv2s = 1 / (2 * s)
	glFunc.TexCoord(tMid, tMid)
	glFunc.Vertex(cx, cy, 0)
	local tx, ty
	tx = t0 + tRange * (-s + c + s) * inv2s
	ty = t1 - tRange * (-s + s) * inv2s
	glFunc.TexCoord(tx, ty)
	glFunc.Vertex(cx - s + c, cy - s, 0)
	tx = t0 + tRange * (s - c + s) * inv2s
	glFunc.TexCoord(tx, ty)
	glFunc.Vertex(cx + s - c, cy - s, 0)
	tx = t0 + tRange * (s + s) * inv2s
	ty = t1 - tRange * (-s + c + s) * inv2s
	glFunc.TexCoord(tx, ty)
	glFunc.Vertex(cx + s, cy - s + c, 0)
	ty = t1 - tRange * (s - c + s) * inv2s
	glFunc.TexCoord(tx, ty)
	glFunc.Vertex(cx + s, cy + s - c, 0)
	tx = t0 + tRange * (s - c + s) * inv2s
	ty = t1 - tRange * (s + s) * inv2s
	glFunc.TexCoord(tx, ty)
	glFunc.Vertex(cx + s - c, cy + s, 0)
	tx = t0 + tRange * (-s + c + s) * inv2s
	glFunc.TexCoord(tx, ty)
	glFunc.Vertex(cx - s + c, cy + s, 0)
	tx = t0 + tRange * (-s + s) * inv2s
	ty = t1 - tRange * (s - c + s) * inv2s
	glFunc.TexCoord(tx, ty)
	glFunc.Vertex(cx - s, cy + s - c, 0)
	ty = t1 - tRange * (-s + c + s) * inv2s
	glFunc.TexCoord(tx, ty)
	glFunc.Vertex(cx - s, cy - s + c, 0)
	tx = t0 + tRange * (-s + c + s) * inv2s
	ty = t1 - tRange * (-s + s) * inv2s
	glFunc.TexCoord(tx, ty)
	glFunc.Vertex(cx - s + c, cy - s, 0)
end

local function DrawIconShatters()
	if #cache.iconShatters == 0 then return end

	local wcx_cached = cameraState.wcx
	local wcz_cached = cameraState.wcz

	gl.DepthTest(false)

	-- Cache math functions for better performance
	local floor = math.floor

	-- Cache world boundaries for culling
	local worldLeft = render.world.l
	local worldRight = render.world.r
	local worldTop = render.world.t
	local worldBottom = render.world.b

	-- Reuse pooled table to minimize allocations
	local fragmentsByTexture = pools.fragmentsByTexture

	-- Clear pool from previous call
	for k in pairs(fragmentsByTexture) do
		local t = fragmentsByTexture[k]
		for i = 1, #t do
			t[i] = nil
		end
	end

	local n = #cache.iconShatters
	local i = 1
	while i <= n do
		local shatter = cache.iconShatters[i]
		local age = gameTime - shatter.startTime
		local progress = age / shatter.duration

		-- Remove old shatters (swap-to-end compaction)
		if progress >= 1 then
			cache.iconShatters[i] = cache.iconShatters[n]
			cache.iconShatters[n] = nil
			n = n - 1
		else
			local fade = 1 - progress			-- Calculate scale: stays at 1.0 for first 50% of duration, then shrinks to 0 (earlier than before)
			local scale
			if progress < 0.5 then
				scale = 1.0
			else
				-- Shrink from 1.0 to 0 over the last 50% of duration
				local shrinkProgress = (progress - 0.5) / 0.5
				scale = 1.0 - shrinkProgress
			end			-- Precalculate common values
			local decel = 0.85 + 0.15 * fade
			local velocityDamping = 0.94 + 0.04 * fade
			local zoomInv = 1 / shatter.zoom

			-- Group fragments by texture
			local bitmap = shatter.icon.bitmap
			local texGroup = fragmentsByTexture[bitmap]
			local texGroupSize
			if not texGroup then
				texGroup = {}
				texGroupSize = 0
				fragmentsByTexture[bitmap] = texGroup
			else
				texGroupSize = #texGroup
			end

			-- Update fragment physics
			-- Compute per-shatter flash factor: inherited damage flash fading out
			-- Cubic decay + slight linear tail, so it's bright initially then lingers
			local flashFactor = 0
			if shatter.flashIntensity > 0 then
				local ft = progress  -- 0 at birth, 1 at expiry
				flashFactor = shatter.flashIntensity * math.min(1, (1-ft)*(1-ft)*(1-ft) * 1.3 + (1-ft) * 0.08)
			end

			local fragments = shatter.fragments
			local fragCount = #fragments
			for j = 1, fragCount do
				local frag = fragments[j]
				-- Update fragment world position with deceleration that increases towards end
				frag.wx = frag.wx + frag.vx * decel * 0.016
				frag.wz = frag.wz + frag.vz * decel * 0.016
				frag.vx = frag.vx * velocityDamping
				frag.vz = frag.vz * velocityDamping
				frag.rot = frag.rot + frag.rotSpeed * decel

				-- Convert world coordinates to PiP-local coordinates
				local pipX = frag.wx - wcx_cached
				local pipZ = wcz_cached - frag.wz

				-- Calculate current size with scale, compensating for the glFunc.Scale(zoom) in the matrix
				local currentSize = frag.size * scale * zoomInv
				local halfSize = currentSize * 0.5

				-- Mix team color towards white based on flash factor
				local fr, fg, fb = shatter.teamR, shatter.teamG, shatter.teamB
				if flashFactor > 0.01 then
					fr = fr + (1 - fr) * flashFactor
					fg = fg + (1 - fg) * flashFactor
					fb = fb + (1 - fb) * flashFactor
				end

				-- Add to batch for this texture (use counter instead of #texGroup)
				texGroupSize = texGroupSize + 1
				texGroup[texGroupSize] = {
					x = pipX,
					z = pipZ,
					rot = frag.rot,
					halfSize = halfSize,
					uvx1 = frag.uvx1,
					uvy1 = frag.uvy1,
					uvx2 = frag.uvx2,
					uvy2 = frag.uvy2,
					r = fr,
					g = fg,
					b = fb
				}
			end

			i = i + 1
		end -- end of else (progress < 1)
	end -- end of while loop

	-- Draw all fragments grouped by texture
	for bitmap, frags in pairs(fragmentsByTexture) do
		glFunc.Texture(bitmap)
		local fragCount = #frags
		for i = 1, fragCount do
			local frag = frags[i]
			glFunc.PushMatrix()
				glFunc.Translate(frag.x, frag.z, 0)
				glFunc.Rotate(frag.rot, 0, 0, 1)
				glFunc.Color(frag.r, frag.g, frag.b, 1.0)
				_frag.hs = frag.halfSize
				_frag.uvx1 = frag.uvx1
				_frag.uvy1 = frag.uvy1
				_frag.uvx2 = frag.uvx2
				_frag.uvy2 = frag.uvy2
				glFunc.BeginEnd(glConst.QUADS, drawFragQuad)
			glFunc.PopMatrix()
		end
	end
	glFunc.Texture(false)

	gl.DepthTest(true)
end

-- Draw seismic pings as animated rotating arcs (matching the gadget draw style)
local function DrawSeismicPings()
	if #cache.seismicPings == 0 then return end
	
	local i = 1
	local wcx_cached = cameraState.wcx
	local wcz_cached = cameraState.wcz

	-- Cache world boundaries for culling
	local worldLeft = render.world.l
	local worldRight = render.world.r
	local worldTop = render.world.t
	local worldBottom = render.world.b

	-- Get tracked player's allyteam if tracking
	local trackedAllyTeam = nil
	if interactionState.trackingPlayerID then
		local _, _, _, _, trackedPlayerAllyTeam = spFunc.GetPlayerInfo(interactionState.trackingPlayerID, false)
		trackedAllyTeam = trackedPlayerAllyTeam
	end

	local pingLifetime = 0.95
	local baseRadius = 16
	local maxRadius = 22

	local n = #cache.seismicPings

	while i <= n do
		local ping = cache.seismicPings[i]
		local age = gameTime - ping.startTime

		if age > pingLifetime then
			cache.seismicPings[i] = cache.seismicPings[n]
			cache.seismicPings[n] = nil
			n = n - 1
		else
			-- Filter by allyteam if tracking a player
			if trackedAllyTeam and ping.allyTeam and ping.allyTeam ~= trackedAllyTeam then
				i = i + 1
			-- Check if ping is within visible world bounds
			elseif ping.x + ping.maxRadius < worldLeft or ping.x - ping.maxRadius > worldRight or
				ping.z + ping.maxRadius < worldTop or ping.z - ping.maxRadius > worldBottom then
				i = i + 1
			else
				local progress = age / pingLifetime

				-- Convert world to screen coordinates (matrix already has zoom applied)
				local screenX = ping.x - wcx_cached
				local screenY = wcz_cached - ping.z

				local radius = (baseRadius + (maxRadius - baseRadius) * progress)

				glFunc.PushMatrix()
				glFunc.Translate(screenX, screenY, 0)

				-- Calculate rotation and alpha values for each ring
				local rotation1 = gameTime * 70
				local outerProgress = math.min(1, progress * 1.3)
				local outerAlpha = math.max(0, (1 - outerProgress) * 0.7)
				local outerRadius = radius * 1.15 - (radius * progress * 0.25)

				local rotation2 = -gameTime * 150
				local middleProgress = math.max(0, math.min(1, (progress - 0.1) / 0.9))
				local middleAlpha = math.max(0, (1 - middleProgress) * 0.85)
				local middleRadius = radius + (radius * progress * 0.4)

				local rotation3 = gameTime * 90
				local innerProgress = math.max(0, math.min(1, (progress - 0.15) / 0.85))
				local innerAlpha = math.max(0, (1 - innerProgress))
				local innerRadius = radius - (radius * progress * 0.45)

				gl.Scale(2.3,2.3,0)	-- scale up so it is visible in pip

				-- PASS 1: Draw all dark outlines with normal blending
				if cameraState.zoom > 0.5 then
					gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)

					-- Outer outlines
					glFunc.Color(0.09, 0, 0, outerAlpha * 0.25)
					for j = 0, 3 do
						glFunc.PushMatrix()
						glFunc.Rotate(rotation1, 0, 0, 1)
						glFunc.Scale(outerRadius, outerRadius, 1)
						glFunc.CallList(seismicPingDlists.outerOutlines[j])
						glFunc.PopMatrix()
					end

					-- Middle outlines
					glFunc.Color(0.09, 0, 0, middleAlpha * 0.25)
					for j = 0, 2 do
						glFunc.PushMatrix()
						glFunc.Rotate(rotation2, 0, 0, 1)
						glFunc.Scale(middleRadius, middleRadius, 1)
						glFunc.CallList(seismicPingDlists.middleOutlines[j])
						glFunc.PopMatrix()
					end

					-- Inner outlines
					glFunc.Color(0.07, 0, 0, innerAlpha * 0.25)
					for j = 0, 1 do
						glFunc.PushMatrix()
						glFunc.Rotate(rotation3, 0, 0, 1)
						glFunc.Scale(innerRadius, innerRadius, 1)
						glFunc.CallList(seismicPingDlists.innerOutlines[j])
						glFunc.PopMatrix()
					end
				end

				-- PASS 2: Draw all bright arcs with additive blending
				gl.Blending(GL.SRC_ALPHA, GL.ONE)

				-- Outer ring - 4 arcs rotating clockwise
				glFunc.Color(1, 0.1, 0.09, outerAlpha)
				for j = 0, 3 do
					glFunc.PushMatrix()
					glFunc.Rotate(rotation1, 0, 0, 1)
					glFunc.Scale(outerRadius, outerRadius, 1)
					glFunc.CallList(seismicPingDlists.outerArcs[j])
					glFunc.PopMatrix()
				end

				-- Middle ring - 3 arcs rotating counter-clockwise
				glFunc.Color(1, 0.22, 0.2, middleAlpha)
				for j = 0, 2 do
					glFunc.PushMatrix()
					glFunc.Rotate(rotation2, 0, 0, 1)
					glFunc.Scale(middleRadius, middleRadius, 1)
					glFunc.CallList(seismicPingDlists.middleArcs[j])
					glFunc.PopMatrix()
				end

				-- Inner ring - 2 arcs rotating clockwise
				glFunc.Color(1, 0.37, 0.33, innerAlpha)
				for j = 0, 1 do
					glFunc.PushMatrix()
					glFunc.Rotate(rotation3, 0, 0, 1)
					glFunc.Scale(innerRadius, innerRadius, 1)
					glFunc.CallList(seismicPingDlists.innerArcs[j])
					glFunc.PopMatrix()
				end

				-- Center dot (shrinks from large to small with fade in/out)
				local centerProgress = math.min(1, progress * 1.8)
				local centerScale = baseRadius * 0.82 * (1 - centerProgress)
				if centerScale > 0.1 then
					local centerAlphaMultiplier
					if centerProgress < 0.2 then
						centerAlphaMultiplier = centerProgress / 0.2
					else
						centerAlphaMultiplier = (1 - centerProgress) / 0.8
					end
					local centerAlpha = math.max(0, centerAlphaMultiplier * 0.6)
					glFunc.Color(1, 0.25, 0.23, centerAlpha)
					glFunc.PushMatrix()
					glFunc.Scale(centerScale, centerScale, 1)
					glFunc.CallList(seismicPingDlists.centerCircle)
					glFunc.PopMatrix()
				end

				gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
				glFunc.PopMatrix()
				i = i + 1
			end
		end
	end

	glFunc.Color(1, 1, 1, 1)
end

local function DrawExplosions()
	if #cache.explosions == 0 then return end

	local resScale = render.contentScale or 1
	local i = 1
	local wcx_cached = cameraState.wcx
	local wcz_cached = cameraState.wcz

	mapInfo.rad2deg = 57.29577951308232 -- Precompute radians to degrees conversion

	-- Cache world boundaries for culling
	local worldLeft = render.world.l
	local worldRight = render.world.r
	local worldTop = render.world.t
	local worldBottom = render.world.b

	-- When too many explosions, compute minimum radius threshold to keep ~cap
	local MAX_EXPLOSIONS = GetDetailCap(150)
	local explosionMinRadius = 0
	if #cache.explosions > MAX_EXPLOSIONS then
		-- Collect all radii, sort descending, pick threshold
		local radii = pools.explosionRadii
		if not radii then
			radii = {}
			pools.explosionRadii = radii
		end
		local rCount = 0
		for j = 1, #cache.explosions do
			local e = cache.explosions[j]
			if e and e.x then
				rCount = rCount + 1
				radii[rCount] = e.radius
			end
		end
		table.sort(radii, sortDescending)
		explosionMinRadius = radii[MAX_EXPLOSIONS] or 0
		for j = rCount + 1, #radii do radii[j] = nil end
	end

	local currentFrame = Spring.GetGameFrame()

	local n = #cache.explosions
	while i <= n do
		local explosion = cache.explosions[i]
		if not explosion or not explosion.x then
			cache.explosions[i] = cache.explosions[n]
			cache.explosions[n] = nil
			n = n - 1
		else
		-- Age in seconds derived from game frames (freezes when paused)
		local age = (currentFrame - explosion.startFrame) / 30

		-- Remove explosions older than 0.8 seconds (longer for large explosions)
		local lifetime = 0.4 + explosion.radius / 200 -- Base lifetime calculation

		-- Lightning explosions have shorter lifetime
		if explosion.isLightning then
			lifetime = 0.25 -- Short, snappy lightning flash
			-- Nuke explosions linger much longer
		elseif explosion.radius > 150 then
			lifetime = math.min(1.5, lifetime * 2) -- Nukes last up to 1.5 seconds
		elseif explosion.radius > 80 then
			lifetime = math.min(1.0, lifetime * 1.5) -- Large explosions up to 1 second
		else
			lifetime = math.min(0.8, lifetime) -- Normal explosions up to 0.8 seconds
		end

		-- Unit death explosions last 40% longer
		if explosion.isUnitExplosion then
			lifetime = lifetime * 1.4
		end

		if age > lifetime then
			cache.explosions[i] = cache.explosions[n]
			cache.explosions[n] = nil
			n = n - 1
		-- Skip small explosions when over budget (but still expire them above)
		elseif explosionMinRadius > 0 and explosion.radius < explosionMinRadius then
			i = i + 1
		else
			-- Check if explosion is within visible world bounds
			local explosionRadius = explosion.radius * 2 -- Account for expansion
			if explosion.x + explosionRadius < worldLeft or explosion.x - explosionRadius > worldRight or
				explosion.z + explosionRadius < worldTop or explosion.z - explosionRadius > worldBottom then
				-- Skip invisible explosion
				i = i + 1
			else
				-- Draw explosion as expanding, fading circle
				local actualProgress = (age / lifetime)
				local progress = 0.3 + (age / lifetime) * 0.7 -- Start at 33%, end at 100%

				-- Calculate segments based on explosion size and progress
				-- Smaller early explosions use fewer segments, larger/progressed use more
				local baseRadius = explosion.radius * (0.3 + progress * 1.7)
				local segments = math.max(8, math.min(32, math.floor(8 + baseRadius * 0.15)))
				local angleStep = (2 * math.pi) / segments

				-- Check if this is a lightning explosion
				if explosion.isLightning then
					-- Lightning explosion: small white-blue flash with sparks
					local baseRadius = 16.2 * (0.5 + progress * 2.0) -- 35% larger (12 * 1.35 = 16.2)
					local alpha = (1 - progress) * (1 - progress) -- Faster fade
					local r, g, b = 0.9, 0.95, 1

					if gl4Prim.enabled then
						-- GL4 path: two gradient circles (glow + core)
						local glowAlpha = alpha * 0.5
						local glowRadius = baseRadius * 1.8
						GL4AddCircle(explosion.x, explosion.z, glowRadius, glowAlpha,
							r*0.7, g*0.7, b*0.8,  r*0.4, g*0.4, b*0.5,  0, 0)
						local coreAlpha = alpha * 0.95
						local edgeAlpha = alpha * 0.5
						local coreRadius = baseRadius * 0.4
						GL4AddCircle(explosion.x, explosion.z, coreRadius, coreAlpha,
							1, 1, 1,  r*0.8, g*0.8, b,  edgeAlpha, 0)
						-- GL4 sparks as norm lines
						for k = 1, #explosion.particles do
							local particle = explosion.particles[k]
							local particleAge = age
							local particleProgress = particleAge / particle.life
							if particleProgress < 1 then
								particle.x = particle.x + particle.vx * (1/30)
								particle.z = particle.z + particle.vz * (1/30)
								local sparkAlpha = (1 - particleProgress) * 0.9
								local sparkDirX = particle.vx * 0.3
								local sparkDirZ = particle.vz * 0.3
								-- Sparks use PIP-local Y coords (= -worldZ), so flip Z for GL4 world coords
								GL4AddNormLine(
									explosion.x + particle.x - sparkDirX, explosion.z - particle.z + sparkDirZ,
									explosion.x + particle.x + sparkDirX, explosion.z - particle.z - sparkDirZ,
									r, g, b, sparkAlpha)
							end
						end
					end
				else
					-- Normal explosion rendering
					-- Scale down big explosions by 25% (multiply radius by 0.75)
					local effectiveRadius = explosion.radius
					if explosion.radius > 80 then
						effectiveRadius = explosion.radius * 0.75
					end

					-- Unit death explosions are 33% larger
					if explosion.isUnitExplosion then
						effectiveRadius = effectiveRadius * 1.33
					end

					-- Fireball radius (20% smaller than before)
					local baseRadius = effectiveRadius * (0.27 + progress * 1.8)
					local alpha = 1 - progress                  -- Fades out

					-- Color: outer fireball (darker, smoky edge) and inner core (bright, hot)
				-- Per-explosion random tint variation using stored seed
				local seed = explosion.randomSeed
				local rVar = math.sin(seed * 12.9898) * 0.06   -- ±0.06
				local gVar = math.sin(seed * 78.233) * 0.08    -- ±0.08 (more warmth variety)
				local bVar = math.sin(seed * 43.758) * 0.03    -- ±0.03

				local r, g, b       -- Outer fireball color
				local cr, cg, cb    -- Inner core color (hotter)
				if explosion.isJuno then
					r, g, b = 0.3, 0.75, 0.35
					cr, cg, cb = 0.6, 1, 0.65
				elseif explosion.isParalyze then
					r, g, b = 0.5, 0.6, 0.85
					cr, cg, cb = 0.8, 0.9, 1
				elseif explosion.radius > 150 then
					-- Nuke: bright orange-yellow
					r = 0.9 + rVar
					g = 0.55 + gVar
					b = 0.15 + bVar
					cr, cg, cb = 1, 0.95, 0.7
				elseif explosion.radius > 80 then
					-- Large: warm orange (less red than before)
					r = 0.92 + rVar
					g = 0.5 + gVar
					b = 0.1 + bVar
					cr = 1
					cg = 0.88 + gVar * 0.5
					cb = 0.4 + bVar
				else
					-- Small-to-medium: orange with gentle red shift (much less than before)
					local sizeRatio = explosion.radius / 200
					r = 0.92 + rVar
					g = 0.55 - sizeRatio * 0.15 + gVar  -- Gentle shift (was 0.5 - sizeRatio)
					b = 0.05 + bVar
					cr = 1
					cg = 0.92 - sizeRatio * 0.25 + gVar * 0.5
					cb = 0.2 + bVar
					end

					-- Bigger explosions are more opaque
					local coreAlpha = alpha
					local edgeAlpha = alpha * 0.7
					if explosion.radius > 150 then
						coreAlpha = math.min(1, alpha * 1.2)
						edgeAlpha = math.min(1, alpha * 0.95)
					elseif explosion.radius > 80 then
						coreAlpha = math.min(1, alpha * 1.1)
						edgeAlpha = math.min(1, alpha * 0.85)
					end

					if gl4Prim.enabled then
						-- Layer 1: Outer fireball body (dark edge → mid color)
						GL4AddCircle(explosion.x, explosion.z, baseRadius, coreAlpha,
							r, g, b,  r * 0.4, g * 0.25, b * 0.15,  edgeAlpha * 0.5, 0)

						-- Layer 2: Inner hot core (bright center → fireball color)
						local coreRadius = baseRadius * 0.5
						local innerAlpha = math.min(1, coreAlpha * 1.15)
						GL4AddCircle(explosion.x, explosion.z, coreRadius, innerAlpha,
							cr, cg, cb,  r, g, b,  coreAlpha * 0.8, 0)

						-- Layer 3: Initial flash (fast white-hot burst, first 20% of lifetime)
						if actualProgress < 0.2 then
							local flashT = actualProgress / 0.2
							local flashAlpha = (1 - flashT * flashT) * 0.95  -- Quadratic falloff, brighter peak
							local flashRadius = baseRadius * (0.8 + flashT * 0.9)
							if explosion.isJuno then
								GL4AddCircle(explosion.x, explosion.z, flashRadius, flashAlpha,
									0.7, 1, 0.75,  0.4, 0.85, 0.5,  flashAlpha * 0.4, 0)
							elseif explosion.isParalyze then
								GL4AddCircle(explosion.x, explosion.z, flashRadius, flashAlpha,
									0.85, 0.9, 1,  0.65, 0.75, 1,  flashAlpha * 0.4, 0)
							else
								GL4AddCircle(explosion.x, explosion.z, flashRadius, flashAlpha,
									1, 1, 1,  1, 0.95, 0.7,  flashAlpha * 0.35, 0)
							end
						end

						-- Layer 4: Nuke secondary flash (lingers longer)
						if explosion.radius > 150 and actualProgress < 0.5 then
							local flashProgress = actualProgress / 0.5
							local flashAlpha = (1 - flashProgress) * alpha * 0.6
							local flashRadius = baseRadius * 0.85
							GL4AddCircle(explosion.x, explosion.z, flashRadius, flashAlpha,
								1, 1, 1,  1, 0.95, 0.8,  flashAlpha * 0.4, 0)
						end

						-- Layer 5: Big white flash (nukes, commanders, fusions)
						-- Fades fast initially (cubic) then lingers slightly (linear tail)
						-- Flash runs at 1.7x speed so it fades out before the fireball ends
						if explosion.isBigFlash and actualProgress < 0.75 then
							local ft = actualProgress / 0.75  -- compress into 75% of explosion lifetime
							-- Cubic decay + small linear tail for gentle linger
							local fa = math.min(1, (1-ft)*(1-ft)*(1-ft) * 1.2 + (1-ft) * 0.12)
							-- Outer white pulse: starts large, expands slowly
							local flashR = effectiveRadius * (1.8 + ft * 1.5)
							GL4AddCircle(explosion.x, explosion.z, flashR, fa * 0.85,
								1, 1, 1,  1, 0.97, 0.92,  fa * 0.25, 0)
							-- Inner bright core: tight, fades faster
							if ft < 0.45 then
								local cft = ft / 0.45
								local cfa = (1 - cft * cft) * 0.95
								local coreR = effectiveRadius * (0.4 + cft * 0.6)
								GL4AddCircle(explosion.x, explosion.z, coreR, cfa,
									1, 1, 1,  1, 1, 0.97,  cfa * 0.5, 0)
							end
						end
					end
				end
				i = i + 1
			end
		end
		end -- end of "if not explosion" else block
	end
	glFunc.LineWidth(1 * resScale)
end

-- Simplified re-render of active explosions for the above-icons overlay pass.
-- Does NOT remove expired entries (DrawExplosions already handled that this frame).
-- Adds a single soft glow circle per explosion at reduced opacity.
local function DrawExplosionOverlay()
	if #cache.explosions == 0 then return end
	if not gl4Prim.enabled then return end

	local currentFrame = Spring.GetGameFrame()

	for i = 1, #cache.explosions do
		local explosion = cache.explosions[i]
		if explosion and explosion.x and not explosion.isLightning then
			local age = (currentFrame - explosion.startFrame) / 30

			-- Replicate lifetime logic from DrawExplosions
			local lifetime = 0.4 + explosion.radius / 200
			if explosion.radius > 150 then
				lifetime = math.min(1.5, lifetime * 2)
			elseif explosion.radius > 80 then
				lifetime = math.min(1.0, lifetime * 1.5)
			else
				lifetime = math.min(0.8, lifetime)
			end

			-- Unit death explosions last 40% longer
			if explosion.isUnitExplosion then
				lifetime = lifetime * 1.4
			end

			if age <= lifetime then
				local progress = 0.3 + (age / lifetime) * 0.7
				local effectiveRadius = explosion.radius
				if effectiveRadius > 80 then effectiveRadius = effectiveRadius * 0.75 end
				if explosion.isUnitExplosion then effectiveRadius = effectiveRadius * 1.33 end
				local baseRadius = effectiveRadius * (0.24 + progress * 1.36)
				local fade = 1 - (age / lifetime)

				-- Saturated colored glow (additive blend adds these to the scene)
				-- Use low green/blue to avoid washing out to white
				local overlayAlpha = fade * config.explosionOverlayAlpha
				local r, g, b
				if explosion.isJuno then
					r, g, b = 0.15, 0.8, 0.25  -- Green tint
				elseif explosion.isParalyze then
					r, g, b = 0.25, 0.35, 0.9  -- Blue-purple tint
				else
					-- Warm orange-red: high R, moderate G, minimal B
					local seed = explosion.randomSeed
					local hueShift = math.sin(seed * 12.9898) * 0.08
					r = 0.95
					g = 0.4 + hueShift  -- 0.32-0.48: orange range
					b = 0.05            -- Very little blue keeps it saturated
				end
				GL4AddCircle(explosion.x, explosion.z, baseRadius * 0.85, overlayAlpha,
					r, g, b,  r * 0.3, g * 0.2, b * 0.1,  0, 0)

				-- Big flash overlay: white glow above icons for nukes/commanders/fusions
				-- Flash runs at 1.7x speed matching Layer 5 timing
				if explosion.isBigFlash and age / lifetime < 0.75 then
					local ft = (age / lifetime) / 0.75  -- compress into 75% of explosion lifetime
					local fa = math.min(1, (1-ft)*(1-ft)*(1-ft) * 1.2 + (1-ft) * 0.12)
					local flashR = effectiveRadius * (1.4 + ft * 1.2)
					GL4AddCircle(explosion.x, explosion.z, flashR * 0.7, fa * config.explosionOverlayAlpha * 0.6,
						1, 1, 1,  0.95, 0.93, 0.88,  0, 0)
				end
			end
		end
	end
end

local function GetUnitAtPoint(wx, wz)
	-- Calculate click radius based on current zoom
	-- At high zoom (3D models), use a fixed tight radius; at low zoom, use distMult for easier clicking
	local clickRadius
	if cameraState.zoom > 0.9 then
		-- High zoom: use a fixed small radius that doesn't scale with zoom
		clickRadius = config.iconRadius * 0.4
	else
		-- Low zoom: use distMult for easier clicking on small icons
		local distMult = math.min(math.max(1, 2.2-(cameraState.zoom*3.3)), 3)
		clickRadius = config.iconRadius * cameraState.zoom * distMult * 0.8
	end

	-- Determine which allyTeam's visibility to check
	local checkAllyTeamID
	if interactionState.trackingPlayerID and cameraState.mySpecState then
		-- Tracking a player as spectator
		local _, _, _, teamID = spFunc.GetPlayerInfo(interactionState.trackingPlayerID, false)
		checkAllyTeamID = select(6, spFunc.GetTeamInfo(teamID, false))
	else
		checkAllyTeamID = cameraState.myAllyTeamID
	end

	local factoryID
	local radarUnitID  -- Store highest priority radar-only unit
	
	-- Iterate backwards to respect draw order (units drawn last are on top)
	for i = #miscState.pipUnits, 1, -1 do
		local uID = miscState.pipUnits[i]
		local ux, uy, uz = spFunc.GetUnitPosition(uID)
		if ux then
			local uDefID = spFunc.GetUnitDefID(uID)
			local dx, dz = ux - wx, uz - wz

			-- Use the calculated click radius or unit radius, whichever is larger
			local unitClickRadius = clickRadius
			if cache.unitIcon[uDefID] then
				-- If unit has a custom icon, scale the click radius by its size
				unitClickRadius = clickRadius * cache.unitIcon[uDefID].size
			end

			-- Also consider the actual unit radius, use whichever is larger for easier clicking
			local unitRadiusSq = cache.radiusSqs[uDefID] or (config.iconRadius*config.iconRadius)
			local clickRadiusSq = math.max(unitClickRadius * unitClickRadius, unitRadiusSq)

			if dx*dx + dz*dz < clickRadiusSq then
				-- Check if this unit is only visible via radar (not in LOS)
				local losState = spFunc.GetUnitLosState(uID, checkAllyTeamID)
				local isRadarOnly = losState and losState.radar and not losState.los
				
				if isRadarOnly then
					-- Radar-only units have highest priority (drawn on top)
					if not radarUnitID then
						radarUnitID = uID
					end
				elseif cache.isFactory[uDefID] then
					-- Factories have lower priority, remember but keep searching
					if not factoryID then
						factoryID = uID
					end
				else
					-- Non-factory unit found, return immediately if we don't have a radar unit yet
					if not radarUnitID then
						return uID
					end
				end
			end
		end
	end
	
	-- Return in priority order: radar units > regular units > factories
	return radarUnitID or factoryID
end

local function GetFeatureAtPoint(wx, wz)
	for i = 1, #miscState.pipFeatures do
		local fID = miscState.pipFeatures[i]
		local fx, fy, fz = spFunc.GetFeaturePosition(fID)
		if fx then
			local dx, dz = fx - wx, fz - wz
			if dx*dx + dz*dz < cache.featureRadiusSqs[spFunc.GetFeatureDefID(fID)] then
				return fID
			end
		end
	end
end

local function GetIDAtPoint(wx, wz)
	local uID = GetUnitAtPoint(wx, wz)
	if uID then return uID end
	local fID = GetFeatureAtPoint(wx, wz)
	if fID then return fID + Game.maxUnits end
end

local function GetUnitsInBox(x1, y1, x2, y2)
	-- Convert screen coordinates to world coordinates
	local wx1, wz1 = PipToWorldCoords(x1, y1)
	local wx2, wz2 = PipToWorldCoords(x2, y2)

	-- Ensure proper ordering (min, max)
	local minWx = math.min(wx1, wx2)
	local maxWx = math.max(wx1, wx2)
	local minWz = math.min(wz1, wz2)
	local maxWz = math.max(wz1, wz2)

	-- Get all units in the world rectangle
	local unitsInRect = spFunc.GetUnitsInRectangle(minWx, minWz, maxWx, maxWz)

	-- Reuse pool table to avoid allocations
	local selectableUnits = pools.selectableUnits
	local count = 0

	for i = 1, #unitsInRect do
		local uID = unitsInRect[i]
		local ux, uy, uz = spFunc.GetUnitPosition(uID)
		if ux then
			-- Check if unit is within the actual world bounds visible in PIP
			if ux >= render.world.l and ux <= render.world.r and uz >= render.world.t and uz <= render.world.b then
				count = count + 1
				selectableUnits[count] = uID
			end
		end
	end

	-- Clear any leftover entries from previous calls
	for i = count + 1, #selectableUnits do
		selectableUnits[i] = nil
	end

	return selectableUnits
end

local function UnitQueueVertices(uID)
	-- Try cached waypoints first (populated by DrawCommandQueuesOverlay, ~1 frame old)
	-- Avoids GetUnitCommands allocation (~60 tables per unit per call)
	local cached = cmdQueueCache.waypoints[uID]
	if cached and cached.n > 0 then
		local ux, _, uz = spFunc.GetUnitPosition(uID)
		if not ux then return end
		local px, pz = WorldToPipCoords(ux, uz)
		for i = 1, cached.n do
			local wp = cached[i]
			local nx, nz = WorldToPipCoords(wp[1], wp[2])
			glFunc.Color(cmdColors[wp[3]] or cmdColors.unknown)
			glFunc.Vertex(px, pz)
			glFunc.Vertex(nx, nz)
			px, pz = nx, nz
		end
		return
	end
	
	-- Fallback: fetch commands directly (first frame or uncached unit)
	local uCmds = spFunc.GetUnitCommands(uID, 50)
	if not uCmds or #uCmds == 0 then return end
	local ux, uy, uz = spFunc.GetUnitPosition(uID)
	local px, pz = WorldToPipCoords(ux, uz)
	for i = 1, #uCmds do
		local cmd = uCmds[i]
		if (cmd.id < 0) or positionCmds[cmd.id] then
			local cx, cy, cz
			local paramCount = #cmd.params
			if paramCount == 3 or cmd.id == 10 then	-- with a little drag its 6
				-- Regular positional command
				cx, cy, cz = cmd.params[1], cmd.params[2], cmd.params[3]
			elseif paramCount == 4 then
				-- Area command: {x, y, z, radius} - use x and z
				cx, cy, cz = cmd.params[1], cmd.params[2], cmd.params[3]
			elseif paramCount == 5 then
				-- 5 params could be: {targetID, x, y, z, radius} for set-target area commands
				-- Check if first param is a valid unit/feature ID (large number)
				if cmd.params[1] > 0 and cmd.params[1] < 1000000 then
					-- It's a target ID command, get the target's position
					if cmd.params[1] > Game.maxUnits then
						cx, cy, cz = spFunc.GetFeaturePosition(cmd.params[1] - Game.maxUnits)
					else
						cx, cy, cz = spFunc.GetUnitPosition(cmd.params[1])
					end
				else
					-- Treat as positional: use x, y, z from params 2, 3, 4
					cx, cy, cz = cmd.params[2], cmd.params[3], cmd.params[4]
				end
			elseif paramCount == 1 then
				if cmd.params[1] > Game.maxUnits then
					cx, cy, cz = spFunc.GetFeaturePosition(cmd.params[1] - Game.maxUnits)
				else
					cx, cy, cz = spFunc.GetUnitPosition(cmd.params[1])
				end
			end
			if cx then
				local nx, nz = WorldToPipCoords(cx, cz)
				glFunc.Color(cmdColors[cmd.id] or cmdColors.unknown)
				glFunc.Vertex(px, pz)
				glFunc.Vertex(nx, nz)
				px, pz = nx, nz
			end
		end
	end
end

local function GetCmdOpts(alt, ctrl, meta, shift, right)
	-- Reuse opts table
	pools.cmdOpts.alt = alt
	pools.cmdOpts.ctrl = ctrl
	pools.cmdOpts.meta = meta
	pools.cmdOpts.shift = shift
	pools.cmdOpts.right = right
	local coded = 0

	if alt   then coded = coded + CMD.OPT_ALT   end
	if ctrl  then coded = coded + CMD.OPT_CTRL  end
	if meta  then coded = coded + CMD.OPT_META  end
	if shift then coded = coded + CMD.OPT_SHIFT end
	if right then coded = coded + CMD.OPT_RIGHT end

	pools.cmdOpts.coded = coded
	return pools.cmdOpts
end

local function GiveNotifyingOrder(cmdID, cmdParams, cmdOpts)

	if widgetHandler:CommandNotify(cmdID, cmdParams, cmdOpts) then
		return
	end

	Spring.GiveOrder(cmdID, cmdParams, cmdOpts.coded)
end

local function GetBuildingDimensions(uDefID, facing)
	local bDef = UnitDefs[uDefID]
	if not bDef then return 32, 32 end
	if (facing % 2 == 1) then
		return 4 * bDef.zsize, 4 * bDef.xsize
	else
		return 4 * bDef.xsize, 4 * bDef.zsize
	end
end

local function DoBuildingsOverlap(x1, z1, x2, z2, width, height)
	-- Check if two buildings with same dimensions would overlap
	return math.abs(x1 - x2) < width and math.abs(z1 - z2) < height
end

local function FindMyCommander()
	-- Find the player's starting commander unit
	local myTeamID = Spring.GetMyTeamID()
	if not myTeamID then return nil end

	local teamUnits = Spring.GetTeamUnits(myTeamID)
	if not teamUnits then return nil end

	-- Look for commander units (they have customParams.iscommander or are named *com)
	for i = 1, #teamUnits do
		local unitID = teamUnits[i]
		local unitDefID = spFunc.GetUnitDefID(unitID)
		if unitDefID then
			local unitDef = UnitDefs[unitDefID]
			if unitDef then
				-- Check if it's a commander by name pattern or custom params
				if unitDef.name and (string.find(unitDef.name, "com") or unitDef.customParams.iscommander) then
					return unitID
				end
			end
		end
	end

	return nil
end

local function CalculateBuildDragPositions(startWX, startWZ, endWX, endWZ, buildDefID, alt, ctrl, shift)
	-- Clear and reuse positions table
	for i = #pools.buildPositions, 1, -1 do
		pools.buildPositions[i] = nil
	end
	local buildFacing = Spring.GetBuildFacing()
	local buildWidth, buildHeight = GetBuildingDimensions(buildDefID, buildFacing)

	-- Snap ONLY the start position - this becomes our anchor
	local sx, sy, sz = Spring.Pos2BuildPos(buildDefID, startWX, spFunc.GetGroundHeight(startWX, startWZ), startWZ)

	-- For end position, snap it too to know the intended area
	local ex, ey, ez = Spring.Pos2BuildPos(buildDefID, endWX, spFunc.GetGroundHeight(endWX, endWZ), endWZ)

	-- Calculate direction and distance
	local dx = ex - sx
	local dz = ez - sz
	local distance = math.sqrt(dx * dx + dz * dz)

	if distance < 1 then
		-- Too short, just return start position
		pools.buildPositions[1] = {wx = sx, wz = sz}
		return pools.buildPositions
	end

	-- Shift+Ctrl: Only horizontal or vertical line (lock to strongest axis)
	if shift and ctrl and not alt then
		if math.abs(dx) > math.abs(dz) then
			ez = sz -- Lock to horizontal
			dz = 0
		else
			ex = sx -- Lock to vertical
			dx = 0
		end
		distance = math.sqrt(dx * dx + dz * dz)
	end

	-- Shift alone or Shift+Ctrl: Line of buildings
	if shift and not alt then
		local dirX = distance > 0 and dx / distance or 0
		local dirZ = distance > 0 and dz / distance or 0

		-- Always add the first position (already snapped)
		positions[#positions + 1] = {wx = sx, wz = sz}

		-- Calculate spacing based on building size
		local baseSpacing = math.max(buildWidth, buildHeight) * 2

		-- Detect how diagonal the line is
		local absDX = math.abs(dx)
		local absDZ = math.abs(dz)
		local minAxis = math.min(absDX, absDZ)
		local maxAxis = math.max(absDX, absDZ)
		local diagonalRatio = maxAxis > 0 and (minAxis / maxAxis) or 0

		-- Scale thresholds smoothly based on diagonal ratio
		-- diagonalRatio: 0.0 = straight line, 1.0 = perfect 45° diagonal
		-- For straight lines (ratio ~0): tight spacing (0.95x), no extra overlap check (1.0x)
		-- For diagonal lines (ratio ~1): looser spacing (1.2x), stricter overlap check (1.8x)
		local minSpacingMultiplier = 0.95 + (diagonalRatio * 0.25)  -- 0.95 to 1.2
		local overlapCheckMultiplier = 1.0 + (diagonalRatio * 0.8)  -- 1.0 to 1.8

		-- For diagonal lines, we need to find snap points that stay near the line
		-- Search along the line with small steps and snap each point
		local searchStep = buildWidth * 0.5  -- Small search increment
		local lastPlacedDist = 0

		for searchDist = searchStep, distance, searchStep do
			local testX = sx + dirX * searchDist
			local testZ = sz + dirZ * searchDist

			-- Snap this test position
			local snappedX, _, snappedZ = Spring.Pos2BuildPos(buildDefID, testX, spFunc.GetGroundHeight(testX, testZ), testZ)

			-- Check distance from last placed building
			local lastPos = positions[#positions]
			local distFromLast = math.sqrt((snappedX - lastPos.wx)^2 + (snappedZ - lastPos.wz)^2)

			-- Only place if we're far enough from the last building
			if distFromLast >= baseSpacing * minSpacingMultiplier then
				-- Check if too close to any other position
				local tooClose = false
				for j = 1, #positions do
					local dist = math.sqrt((snappedX - positions[j].wx)^2 + (snappedZ - positions[j].wz)^2)
					if dist < buildWidth * overlapCheckMultiplier then
						tooClose = true
						break
					end
				end

				if not tooClose then
					positions[#positions + 1] = {wx = snappedX, wz = snappedZ}
					lastPlacedDist = searchDist
				end
			end
		end

	-- Shift+Alt: Filled grid
	elseif shift and alt and not ctrl then
		-- Use snapped positions as bounds
		local minX = math.min(sx, ex)
		local maxX = math.max(sx, ex)
		local minZ = math.min(sz, ez)
		local maxZ = math.max(sz, ez)

		-- Calculate number of buildings in each direction
		-- Engine appears to require about 2x building dimension spacing
		local spacingX = buildWidth * 2
		local spacingZ = buildHeight * 2
		-- First building at minX, then each subsequent building is spacingX away
		local numX = math.floor((maxX - minX) / spacingX) + 1
		local numZ = math.floor((maxZ - minZ) / spacingZ) + 1

		for row = 0, numZ - 1 do
			for col = 0, numX - 1 do
				-- Calculate ideal position
				local wx = minX + col * spacingX
				local wz = minZ + row * spacingZ

				-- Snap each position to engine's build grid
				local snappedX, _, snappedZ = Spring.Pos2BuildPos(buildDefID, wx, spFunc.GetGroundHeight(wx, wz), wz)

				-- Check if this snapped position is too close to a previous one (engine would reject it)
				local tooClose = false
				for i = 1, #positions do
					local dist = math.sqrt((snappedX - positions[i].wx)^2 + (snappedZ - positions[i].wz)^2)
					if dist < buildWidth then  -- Stricter: full width apart
						tooClose = true
						break
					end
				end

				if not tooClose then
					positions[#positions + 1] = {wx = snappedX, wz = snappedZ}
				end
			end
		end

	-- Shift+Alt+Ctrl: Hollow rectangle (only perimeter)
	elseif shift and alt and ctrl then
		local minX = math.min(sx, ex)
		local maxX = math.max(sx, ex)
		local minZ = math.min(sz, ez)
		local maxZ = math.max(sz, ez)

		-- Buildings need about 2x spacing
		local spacingX = buildWidth * 2
		local spacingZ = buildHeight * 2
		local numX = math.floor((maxX - minX) / spacingX) + 1
		local numZ = math.floor((maxZ - minZ) / spacingZ) + 1

		for row = 0, numZ - 1 do
			for col = 0, numX - 1 do
				-- Only place on perimeter
				if row == 0 or row == numZ - 1 or col == 0 or col == numX - 1 then
					local wx = minX + col * spacingX
					local wz = minZ + row * spacingZ

					-- Snap each position to engine's build grid
					local snappedX, _, snappedZ = Spring.Pos2BuildPos(buildDefID, wx, spFunc.GetGroundHeight(wx, wz), wz)

					-- Check if too close to previous
					local tooClose = false
					for i = 1, #positions do
						local dist = math.sqrt((snappedX - positions[i].wx)^2 + (snappedZ - positions[i].wz)^2)
						if dist < buildWidth then  -- Stricter check
							tooClose = true
							break
						end
					end

					if not tooClose then
						positions[#positions + 1] = {wx = snappedX, wz = snappedZ}
					end
				end
			end
		end
	else
		-- No valid modifier combination, return end position (cursor location)
		positions[#positions + 1] = {wx = ex, wz = ez}
	end

	return positions
end

-- Helper function to check if a transport can load a target unit
local function CanTransportLoadUnit(transportUnitID, targetUnitID)
	if not transportUnitID or not targetUnitID then
		return false
	end

	local transportDefID = spFunc.GetUnitDefID(transportUnitID)
	local targetDefID = spFunc.GetUnitDefID(targetUnitID)

	if not transportDefID or not targetDefID then
		return false
	end

	-- Check if transport can carry units (using cache)
	if not cache.isTransport[transportDefID] or (cache.transportCapacity[transportDefID] or 0) <= 0 then
		return false
	end

	-- Check if target can be transported (using cache)
	if cache.cantBeTransported[targetDefID] then
		return false
	end

	-- Check transport size compatibility (using cache)
	local transportSize = cache.transportSize[transportDefID]
	local targetTransportSize = cache.unitTransportSize[targetDefID]
	if transportSize and targetTransportSize then
		if targetTransportSize > transportSize then
			return false
		end
	end

	-- Check transport mass compatibility (using cache)
	local transportMass = cache.transportMass[transportDefID]
	local targetMass = cache.unitMass[targetDefID]
	if transportMass and targetMass then
		if targetMass > transportMass then
			return false
		end
	end

	-- Check if transport can carry this type (minTransportSize) (using cache)
	local minTransportSize = cache.minTransportSize[transportDefID]
	if minTransportSize and targetTransportSize then
		if targetTransportSize < minTransportSize then
			return false
		end
	end

	return true
end

local function IssueCommandAtPoint(cmdID, wx, wz, usingRMB, forceQueue, radius)

	local alt, ctrl, meta, shift = Spring.GetModKeyState()
	-- Force queue commands when explicitly requested (e.g., during formation drags)
	if forceQueue then
		shift = true
	end
	local cmdOpts = GetCmdOpts(alt, ctrl, meta, shift, usingRMB)

	-- For build commands (negative cmdID), don't check for units at the position
	-- We want to build AT the position, not command any unit that might be there
	-- Also for PATROL and FIGHT, always target ground position instead of units
	local id = nil
	if cmdID > 0 and cmdID ~= CMD.PATROL and cmdID ~= CMD.FIGHT then
		id = GetIDAtPoint(wx, wz)

		-- For ATTACK command, only target if it's an enemy unit
		if id and cmdID == CMD.ATTACK then
			if Spring.IsUnitAllied(id) then
				id = nil  -- Don't target allied units with ATTACK, use ground position instead
			end
		end

		-- For area RECLAIM command (radius > 0), don't target enemy units
		if id and cmdID == CMD.RECLAIM and radius and radius > 0 then
			if not Spring.IsUnitAllied(id) then
				id = nil  -- Don't target enemy units with area RECLAIM
			end
		end

		-- For area REPAIR command (radius > 0), don't target enemy units
		if id and cmdID == CMD.REPAIR and radius and radius > 0 then
			if not Spring.IsUnitAllied(id) then
				id = nil  -- Don't target enemy units with area REPAIR
			end
		end
	end

	if id then
		-- For LOAD_UNITS command, give order only to transport units
		if cmdID == CMD.LOAD_UNITS then
			local selectedUnits = Spring.GetSelectedUnits()
			local transports = {}

			-- Collect all transport units (using cache)
			for i = 1, #selectedUnits do
				local unitDefID = spFunc.GetUnitDefID(selectedUnits[i])
				if unitDefID and cache.isTransport[unitDefID] and (cache.transportCapacity[unitDefID] or 0) > 0 then
					transports[#transports + 1] = selectedUnits[i]
				end
			end			if #transports > 0 then
				-- If multiple transports, convert to area command so they load different units
				if #transports > 1 then
					local ux, uy, uz = spFunc.GetUnitPosition(id)
					if ux then
						-- Use a small radius area command so transports will find different nearby units
						local smallRadius = 150
						for i = 1, #transports do
							Spring.GiveOrderToUnit(transports[i], cmdID, {ux, uy, uz, smallRadius}, cmdOpts.coded)
						end
					end
				else
					-- Single transport, give direct unit target
					Spring.GiveOrderToUnit(transports[1], cmdID, {id}, cmdOpts.coded)
				end
			end
		else
			GiveNotifyingOrder(cmdID, {id}, cmdOpts)
		end
	else
		if cmdID > 0 then
			-- For SET_TARGET command, only allow targeting units, not ground
			local setTargetCmd = GameCMD and GameCMD.UNIT_SET_TARGET_NO_GROUND
			if setTargetCmd and cmdID == setTargetCmd then
				-- No unit found at target position, don't issue command
				return
			end

			-- Add radius for area commands if provided
			if radius and radius > 0 then
				-- For area LOAD_UNITS command, give order only to transport units individually
				if cmdID == CMD.LOAD_UNITS then
					local selectedUnits = Spring.GetSelectedUnits()

					-- Give order to each transport unit individually (using cache)
					-- This allows the engine to distribute targets naturally across multiple transports
					for i = 1, #selectedUnits do
						local unitDefID = spFunc.GetUnitDefID(selectedUnits[i])
						if unitDefID and cache.isTransport[unitDefID] and (cache.transportCapacity[unitDefID] or 0) > 0 then
							Spring.GiveOrderToUnit(selectedUnits[i], cmdID, {wx, spFunc.GetGroundHeight(wx, wz), wz, radius}, cmdOpts.coded)
						end
					end
				else
					GiveNotifyingOrder(cmdID, {wx, spFunc.GetGroundHeight(wx, wz), wz, radius}, cmdOpts)
				end
			else
				GiveNotifyingOrder(cmdID, {wx, spFunc.GetGroundHeight(wx, wz), wz}, cmdOpts)
			end
		else
			-- Build command - check if it's an extractor/geo that needs spot snapping
			local buildDefID = -cmdID
			local resourceSpotFinder = WG["resource_spot_finder"]
			local resourceSpotBuilder = WG["resource_spot_builder"]

			if resourceSpotFinder and resourceSpotBuilder then
				local mexBuildings = resourceSpotBuilder.GetMexBuildings()
				local geoBuildings = resourceSpotBuilder.GetGeoBuildings()
				local isMex = mexBuildings and mexBuildings[buildDefID]
				local isGeo = geoBuildings and geoBuildings[buildDefID]
				local metalMap = resourceSpotFinder.isMetalMap

				-- Handle extractor snapping (skip on metal maps for mexes)
				if (isMex and not metalMap) or isGeo then
					local spot
					if isMex then
						-- Find nearest unoccupied metal spot
						local metalSpots = resourceSpotFinder.metalSpotsList
						spot = resourceSpotBuilder.FindNearestValidSpotForExtractor(wx, wz, metalSpots, buildDefID)
					else
						-- Find nearest unoccupied geo spot
						local geoSpots = resourceSpotFinder.geoSpotsList
						spot = resourceSpotBuilder.FindNearestValidSpotForExtractor(wx, wz, geoSpots, buildDefID)
					end

					if spot then
						-- Use PreviewExtractorCommand to get proper build position
						local pos = {wx, spFunc.GetGroundHeight(wx, wz), wz}
						local cmd = resourceSpotBuilder.PreviewExtractorCommand(pos, buildDefID, spot)

						if cmd and #cmd > 0 then
							-- Apply the command using ApplyPreviewCmds
							local constructors = isMex and resourceSpotBuilder.GetMexConstructors() or resourceSpotBuilder.GetGeoConstructors()
							resourceSpotBuilder.ApplyPreviewCmds({cmd}, constructors, shift)
							return
						end
					end
					-- If no valid spot found, don't build anything
					return
				end
			end

			-- Regular building - just pass the position as-is (no additional snapping)
			-- The position should already be snapped from CalculateBuildDragPositions
			GiveNotifyingOrder(cmdID, {wx, spFunc.GetGroundHeight(wx, wz), wz, Spring.GetBuildFacing()}, cmdOpts)
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Callins
----------------------------------------------------------------------------------------------------

-- Helper: Draw a thick arc as geometry (for display list creation)
local function DrawThickArcVertices(innerRadius, outerRadius, startAngle, endAngle, segments)
	local angleStep = (endAngle - startAngle) / segments
	local cos, sin = math.cos, math.sin
	for i = 0, segments - 1 do
		local angle1 = startAngle + i * angleStep
		local angle2 = startAngle + (i + 1) * angleStep
		local cos1, sin1 = cos(angle1), sin(angle1)
		local cos2, sin2 = cos(angle2), sin(angle2)
		glFunc.Vertex(cos1 * innerRadius, sin1 * innerRadius, 0)
		glFunc.Vertex(cos1 * outerRadius, sin1 * outerRadius, 0)
		glFunc.Vertex(cos2 * outerRadius, sin2 * outerRadius, 0)
		glFunc.Vertex(cos2 * innerRadius, sin2 * innerRadius, 0)
	end
end

-- Create display lists for seismic ping rotating arcs
local function CreateSeismicPingDlists()
	local pi = math.pi
	local pi2 = pi * 2
	local baseRadius = 16
	local baseThickness = 2.4

	-- Proportional thicknesses (relative to unit radius 1.0)
	local outerThicknessRatio = baseThickness * 1.05 / baseRadius
	local middleThicknessRatio = baseThickness * 0.8 / baseRadius
	local innerThicknessRatio = baseThickness * 1 / baseRadius
	local centerThicknessRatio = baseThickness * 1.8 / baseRadius
	local outlineExtra = 0.02

	-- Outer arcs: 4 arcs, 60 degrees each
	local outerInner = 1.08 - outerThicknessRatio / 2
	local outerOuter = 1.08 + outerThicknessRatio / 2
	for i = 0, 3 do
		local startAngle = (i * 90) * pi / 180
		local arcLength = 60 * pi / 180
		-- Outline
		seismicPingDlists.outerOutlines[i] = gl.CreateList(function()
			glFunc.BeginEnd(glConst.QUADS, DrawThickArcVertices, outerInner - outlineExtra, outerOuter + outlineExtra, startAngle - 0.02, startAngle + arcLength + 0.02, 12)
		end)
		-- Main arc
		seismicPingDlists.outerArcs[i] = gl.CreateList(function()
			glFunc.BeginEnd(glConst.QUADS, DrawThickArcVertices, outerInner, outerOuter, startAngle, startAngle + arcLength, 12)
		end)
	end

	-- Middle arcs: 3 arcs, 80 degrees each, at 0.85 of unit radius
	local middleRadiusRatio = 0.85
	local middleInner = middleRadiusRatio - middleThicknessRatio / 2
	local middleOuter = middleRadiusRatio + middleThicknessRatio / 2
	for i = 0, 2 do
		local startAngle = (i * 120) * pi / 180
		local arcLength = 80 * pi / 180
		-- Outline
		seismicPingDlists.middleOutlines[i] = gl.CreateList(function()
			glFunc.BeginEnd(glConst.QUADS, DrawThickArcVertices, middleInner - outlineExtra, middleOuter + outlineExtra, startAngle - 0.02, startAngle + arcLength + 0.02, 12)
		end)
		-- Main arc
		seismicPingDlists.middleArcs[i] = gl.CreateList(function()
			glFunc.BeginEnd(glConst.QUADS, DrawThickArcVertices, middleInner, middleOuter, startAngle, startAngle + arcLength, 12)
		end)
	end

	-- Inner arcs: 2 arcs, 120 degrees each, at 0.66 of unit radius
	local innerRadiusRatio = 0.66
	local innerInner = innerRadiusRatio - innerThicknessRatio / 2
	local innerOuter = innerRadiusRatio + innerThicknessRatio / 2
	for i = 0, 1 do
		local startAngle = (i * 180) * pi / 180
		local arcLength = 120 * pi / 180
		-- Outline
		seismicPingDlists.innerOutlines[i] = gl.CreateList(function()
			glFunc.BeginEnd(glConst.QUADS, DrawThickArcVertices, innerInner - outlineExtra, innerOuter + outlineExtra, startAngle - 0.02, startAngle + arcLength + 0.02, 16)
		end)
		-- Main arc
		seismicPingDlists.innerArcs[i] = gl.CreateList(function()
			glFunc.BeginEnd(glConst.QUADS, DrawThickArcVertices, innerInner, innerOuter, startAngle, startAngle + arcLength, 16)
		end)
	end

	-- Center circle: full circle
	local centerInner = 1 - centerThicknessRatio / 1.3
	local centerOuter = 1.25 + centerThicknessRatio / 1.3
	seismicPingDlists.centerCircle = gl.CreateList(function()
		glFunc.BeginEnd(glConst.QUADS, DrawThickArcVertices, centerInner, centerOuter, 0, pi2, 20)
	end)
end

-- Delete seismic ping display lists
local function DeleteSeismicPingDlists()
	for i = 0, 3 do
		if seismicPingDlists.outerArcs[i] then gl.DeleteList(seismicPingDlists.outerArcs[i]) end
		if seismicPingDlists.outerOutlines[i] then gl.DeleteList(seismicPingDlists.outerOutlines[i]) end
	end
	for i = 0, 2 do
		if seismicPingDlists.middleArcs[i] then gl.DeleteList(seismicPingDlists.middleArcs[i]) end
		if seismicPingDlists.middleOutlines[i] then gl.DeleteList(seismicPingDlists.middleOutlines[i]) end
	end
	for i = 0, 1 do
		if seismicPingDlists.innerArcs[i] then gl.DeleteList(seismicPingDlists.innerArcs[i]) end
		if seismicPingDlists.innerOutlines[i] then gl.DeleteList(seismicPingDlists.innerOutlines[i]) end
	end
	if seismicPingDlists.centerCircle then gl.DeleteList(seismicPingDlists.centerCircle) end
end

function widget:Initialize()

	-- Create seismic ping display lists
	CreateSeismicPingDlists()

	unitOutlineList = gl.CreateList(function()
		glFunc.BeginEnd(GL.LINE_LOOP, function()
			glFunc.Vertex( 1, 0, 1)
			glFunc.Vertex( 1, 0,-1)
			glFunc.Vertex(-1, 0,-1)
			glFunc.Vertex(-1, 0, 1)
		end)
	end)

	radarDotList = gl.CreateList(function()
		glFunc.Texture('LuaUI/Images/pip/PipBlip.png')
		glFunc.BeginEnd(glConst.QUADS, function()
			glFunc.Vertex( config.iconRadius, config.iconRadius)
			glFunc.Vertex( config.iconRadius,-config.iconRadius)
			glFunc.Vertex(-config.iconRadius,-config.iconRadius)
			glFunc.Vertex(-config.iconRadius, config.iconRadius)
		end)
		glFunc.Texture(false)
	end)

	local iconTypes = VFS.Include("gamedata/icontypes.lua")
	for uDefID, uDef in pairs(UnitDefs) do
		cache.xsizes[uDefID] = uDef.xsize * 4
		cache.zsizes[uDefID] = uDef.zsize * 4
		cache.radiusSqs[uDefID] = uDef.radius * uDef.radius
		if uDef.isFactory then
			cache.isFactory[uDefID] = true
		end
		if uDef.iconType and iconTypes[uDef.iconType] and iconTypes[uDef.iconType].bitmap then
			cache.unitIcon[uDefID] = iconTypes[uDef.iconType]
		end
		-- Cache unitpic path using engine's #unitDefID syntax (handles all buildpic variations automatically)
		cache.unitPic[uDefID] = '#' .. uDefID

		-- Cache transport properties
		if uDef.isTransport then
			cache.isTransport[uDefID] = true
			cache.transportCapacity[uDefID] = uDef.transportCapacity or 0
			cache.transportSize[uDefID] = uDef.transportSize
			cache.transportMass[uDefID] = uDef.transportMass
			cache.minTransportSize[uDefID] = uDef.minTransportSize
		end
		if uDef.cantBeTransported then
			cache.cantBeTransported[uDefID] = true
		end
		cache.unitMass[uDefID] = uDef.mass
		cache.unitTransportSize[uDefID] = uDef.transportSize

		-- Cache movement properties
		if uDef.canMove then
			cache.canMove[uDefID] = true
		end
		if uDef.canFly then
			cache.canFly[uDefID] = true
		end
		if uDef.isBuilding then
			cache.isBuilding[uDefID] = true
		end
		if uDef.customParams and uDef.customParams.iscommander then
			cache.isCommander[uDefID] = true
		end
		cache.unitCost[uDefID] = uDef.metalCost + uDef.energyCost / 60

		-- Pre-compute icon draw layer for GL4 rendering (determines render order)
		if uDef.canFly then
			gl4Icons.unitDefLayer[uDefID] = gl4Icons.LAYER_AIR
		elseif uDef.customParams and uDef.customParams.iscommander then
			gl4Icons.unitDefLayer[uDefID] = gl4Icons.LAYER_COMMANDER
		elseif uDef.isBuilding then
			gl4Icons.unitDefLayer[uDefID] = gl4Icons.LAYER_STRUCTURE
		else
			gl4Icons.unitDefLayer[uDefID] = gl4Icons.LAYER_GROUND
		end
		
		-- Cache combat properties
		if uDef.weapons and #uDef.weapons > 0 then
			-- Check if unit has any non-shield weapons
			for _, weapon in ipairs(uDef.weapons) do
				local weaponDef = WeaponDefs[weapon.weaponDef]
				if weaponDef and not weaponDef.isShield then
					cache.canAttack[uDefID] = true
					break
				end
			end
		end
	end

	for fDefID, fDef in pairs(FeatureDefs) do
		if fDef.modelname == '' then
			cache.noModelFeatures[fDefID] = true
		end
		local fx, fz = 8 * fDef.xsize, 8 * fDef.zsize
		cache.featureRadiusSqs[fDefID] = fx*fx + fz*fz
	end

	-- Initialize LOS texture (a fraction of map size)
	local losTexWidth = math.max(1, math.floor(mapInfo.mapSizeX / pipR2T.losTexScale))
	local losTexHeight = math.max(1, math.floor(mapInfo.mapSizeZ / pipR2T.losTexScale))
	pipR2T.losTex = gl.CreateTexture(losTexWidth, losTexHeight, {
		target = GL.TEXTURE_2D,
		format = GL.RGBA8,  -- RGBA for proper greyscale rendering
		fbo = true,
		min_filter = GL.LINEAR,  -- Use linear filtering for smooth/blurred appearance
		mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
	})

	-- Initialize decal overlay texture (covers full map at reduced resolution)
	-- White clear = multiply identity (no darkening); circles darken where decals exist
	local decalTexWidth = math.max(1, math.floor(mapInfo.mapSizeX / pipR2T.decalTexScale))
	local decalTexHeight = math.max(1, math.floor(mapInfo.mapSizeZ / pipR2T.decalTexScale))
	pipR2T.decalTex = gl.CreateTexture(decalTexWidth, decalTexHeight, {
		target = GL.TEXTURE_2D,
		format = GL.RGBA8,
		fbo = true,
		min_filter = GL.LINEAR,
		mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
	})

	-- Initialize LOS shader for red-to-greyscale conversion
	shaders.los = gl.CreateShader(shaders.losCode)
	if not shaders.los then
		Spring.Echo("PIP: Failed to compile LOS shader, LOS overlay will be disabled")
		Spring.Echo("PIP: Shader log: " .. (gl.GetShaderLog() or "no log"))
		if pipR2T.losTex then
			gl.DeleteTexture(pipR2T.losTex)
			pipR2T.losTex = nil
		end
	end
	
	-- Initialize decal overlay shader + GL4 VBO/VAO
	shaders.decal = gl.CreateShader(shaders.decalCode)
	if not shaders.decal then
		Spring.Echo("PIP: Failed to compile decal shader")
		Spring.Echo("PIP: Shader log: " .. (gl.GetShaderLog() or "no log"))
	else
		InitGL4Decals()
	end

	-- Initialize minimap+shading compositing shader
	shaders.minimapShading = gl.CreateShader(shaders.minimapShadingCode)
	if not shaders.minimapShading then
		Spring.Echo("PIP: Failed to compile minimap shading shader")
		Spring.Echo("PIP: Shader log: " .. (gl.GetShaderLog() or "no log"))
	end

	-- Initialize water shader if map has water
	if mapInfo.hasWater then
		shaders.water = gl.CreateShader(shaders.waterCode)
		if not shaders.water then
			Spring.Echo("PIP: Failed to compile water shader")
			Spring.Echo("PIP: Shader log: " .. (gl.GetShaderLog() or "no log"))
		end
	end

	-- Localize weapon data for performance
	-- Default missile colors fallback (wDefID 0)
	cache.missileColors[0] = {0.88,0.88,0.84, 0.92,0.92,0.88, 0.82,0.82,0.78, 1.0,0.7,0.3}
	for wDefID, wDef in pairs(WeaponDefs) do
		-- Check weapon type
		if wDef.type == "BeamLaser" then
			cache.weaponIsLaser[wDefID] = true
		elseif wDef.type == "LaserCannon" then
			cache.weaponIsBlaster[wDefID] = true -- LaserCannon = traveling blaster bolt
		elseif wDef.type == "Cannon" then
			cache.weaponIsPlasma[wDefID] = true -- Cannon/PlasmaCannon = traveling ball projectile
		elseif wDef.type == "MissileLauncher" or wDef.type == "StarburstLauncher" or wDef.type == "TorpedoLauncher" then
			cache.weaponIsMissile[wDefID] = true
			if wDef.type == "StarburstLauncher" then
				cache.weaponIsStarburst[wDefID] = true
			end
			if wDef.type == "TorpedoLauncher" then
				cache.weaponIsTorpedo[wDefID] = true
			end
		elseif wDef.type == "LightningCannon" then
			cache.weaponIsLightning[wDefID] = true
		elseif wDef.type == "Flame" then
			cache.weaponIsFlame[wDefID] = true
			-- Actual flame particle flight time: range / speed in game frames, / 30 for seconds
			local pSpeed = wDef.projectilespeed or 3
			local range = wDef.range or 300
			cache.flameLifetime[wDefID] = (range / pSpeed) / 30
		elseif wDef.type == "AircraftBomb" then
			cache.weaponIsBomb[wDefID] = true
		end

		-- Cache weapon properties
		cache.weaponSize[wDefID] = wDef.size or 1
		cache.weaponRange[wDefID] = wDef.range or 500

		-- Get weapon thickness
		if wDef.visuals and wDef.visuals.thickness then
			cache.weaponThickness[wDefID] = math.max(1, math.min(8, wDef.visuals.thickness))
		else
			cache.weaponThickness[wDefID] = math.max(1, math.min(8, (wDef.size or 1) * 0.5))
		end

		-- Get weapon color
		if wDef.visuals and wDef.visuals.colorR then
			cache.weaponColor[wDefID] = {
				wDef.visuals.colorR,
				wDef.visuals.colorG or 0,
				wDef.visuals.colorB or 0
			}
		elseif wDef.rgbColor then
			-- Parse rgbColor table {r, g, b}
			cache.weaponColor[wDefID] = {
				wDef.rgbColor[1] or 1,
				wDef.rgbColor[2] or 1,
				wDef.rgbColor[3] or 1
			}
		else
			cache.weaponColor[wDefID] = {1, 0.2, 0.2} -- Default red
		end

		-- Get explosion radius (allow much larger explosions for nukes, etc.)
		cache.weaponExplosionRadius[wDefID] = math.max(5, math.min(400, wDef.damageAreaOfEffect or wDef.size or 10))

		-- Check if weapon should skip explosion rendering (e.g., footstep effects)
		if wDef.name and string.find(string.lower(wDef.name), "footstep") then
			cache.weaponSkipExplosion[wDefID] = true
		end
	
	-- Check if weapon is paralyze damage
	if wDef.damages and wDef.damages.paralyzeDamageTime and wDef.damages.paralyzeDamageTime > 0 then
		cache.weaponIsParalyze[wDefID] = true
	end
	
	-- Check if weapon is anti-air via cegTag
	if wDef.cegTag and string.find(wDef.cegTag, 'aa') then
		cache.weaponIsAA[wDefID] = true
	end

	-- Check if weapon is Juno via cegTag
	if wDef.cegTag and string.find(wDef.cegTag, 'juno') then
		cache.weaponIsJuno[wDefID] = true
	end

	-- Cache missile body/nose/fin/exhaust colors per-wDefID (avoids per-frame branching)
	if cache.weaponIsMissile[wDefID] then
		if cache.weaponIsJuno[wDefID] then
			cache.missileColors[wDefID] = {0.3,0.8,0.3, 0.4,0.9,0.4, 0.25,0.7,0.25, 0.3,1.0,0.3}
		elseif cache.weaponIsParalyze[wDefID] then
			cache.missileColors[wDefID] = {0.45,0.5,0.95, 0.6,0.65,1.0, 0.35,0.4,0.85, 0.6,0.5,1.0}
		elseif cache.weaponIsTorpedo[wDefID] then
			cache.missileColors[wDefID] = {0.7,0.78,0.9, 0.75,0.82,0.95, 0.6,0.7,0.85, 0.5,0.7,1.0}
		else
			cache.missileColors[wDefID] = {0.8,0.8,0.76, 0.84,0.84,0.8, 0.74,0.74,0.7, 1.0,0.7,0.3}
		end
	end

	-- Classify plasma trail color by cegTag (for plasma/cannon weapons with visible trails)
	if wDef.type == "Cannon" and wDef.cegTag and wDef.cegTag ~= '' then
		local tag = wDef.cegTag
		if string.find(tag, 'flak') or string.find(tag, 'aa') then
			-- AA flak: no trail (too small/fast)
		elseif string.find(tag, 'botrail') then
			cache.weaponPlasmaTrailColor[wDefID] = {0.44, 0.48, 0.9}   -- Blue bot trail
		elseif string.find(tag, 'railgun') then
			cache.weaponPlasmaTrailColor[wDefID] = {0.55, 0.42, 0.88}  -- Purple railgun
		elseif string.find(tag, 'starfire') or string.find(tag, 'ministarfire') then
			cache.weaponPlasmaTrailColor[wDefID] = {0.5, 0.55, 0.85}   -- Blue-white starfire
		elseif string.find(tag, 'impulse') then
			cache.weaponPlasmaTrailColor[wDefID] = {0.8, 0.6, 0.25}    -- Warm yellow impulse
		elseif string.find(tag, 'Heavy') then
			cache.weaponPlasmaTrailColor[wDefID] = {0.85, 0.5, 0.18}   -- Orange heavy plasma
		elseif string.find(tag, 'arty') or string.find(tag, 'cannon') then
			cache.weaponPlasmaTrailColor[wDefID] = {0.82, 0.52, 0.2}   -- Warm orange artillery
		else
			-- Generic cannon with a cegTag: subtle warm trail
			cache.weaponPlasmaTrailColor[wDefID] = {0.7, 0.5, 0.25}
		end
	end
end

gameHasStarted = (Spring.GetGameFrame() > 0)
miscState.startX, _, miscState.startZ = Spring.GetTeamStartPosition(Spring.GetMyTeamID())

-- Initialize GL4 instanced icon rendering (after cache is built so unitIcon data is available)
InitGL4Icons()
InitGL4Primitives()

-- Ghost building sharing: merge data from any already-running sibling PIP
-- This ensures all PIP instances share the same ghost history even on partial reload
for n = 0, 4 do
	if n ~= pipNumber and WG['pip' .. n] and WG['pip' .. n].GetGhostBuildings then
		local siblingGhosts = WG['pip' .. n].GetGhostBuildings()
		if siblingGhosts then
			for gID, ghost in pairs(siblingGhosts) do
				if not ghostBuildings[gID] then
					ghostBuildings[gID] = { defID = ghost.defID, x = ghost.x, z = ghost.z, teamID = ghost.teamID }
				end
			end
			break  -- All PIPs share the same LOS perspective, one source is sufficient
		end
	end
end

-- Scan currently-visible enemy buildings for ghost tracking (handles luaui reload mid-game)
-- UnitEnteredLos won't fire for units already in LOS at widget init, so we pre-populate here
-- For spectators with LOS view, also pre-scan to populate ghosts on reload
do
local initScanAllyTeam = nil
local initScanIsSpec, initScanFullview = Spring.GetSpectatingState()
if not initScanIsSpec then
	initScanAllyTeam = Spring.GetMyAllyTeamID()
elseif state.losViewEnabled and state.losViewAllyTeam then
	initScanAllyTeam = state.losViewAllyTeam
elseif initScanIsSpec and not initScanFullview then
	-- Spectator without fullview: scan ghosts from their allyteam's perspective
	initScanAllyTeam = Spring.GetMyAllyTeamID()
end
if initScanAllyTeam then
	local allUnits = Spring.GetAllUnits()
	for _, uID in ipairs(allUnits) do
		local defID = Spring.GetUnitDefID(uID)
		if defID and cache.isBuilding[defID] then
			local uTeam = Spring.GetUnitTeam(uID)
			local uAllyTeam = Spring.GetTeamAllyTeamID(uTeam)
			if uAllyTeam ~= initScanAllyTeam then
				if initScanIsSpec then
					-- As spectator, only ghost buildings the viewed allyteam has ever seen
					local losBits = Spring.GetUnitLosState(uID, initScanAllyTeam, true)
					if losBits and (losBits % 2 >= 1 or losBits % 8 >= 4) then
						local x, _, z = Spring.GetUnitBasePosition(uID)
						if x then
							ghostBuildings[uID] = { defID = defID, x = x, z = z, teamID = uTeam }
						end
					end
				else
					-- As player, we can see all units returned (only own-LOS units are returned)
					local x, _, z = Spring.GetUnitBasePosition(uID)
					if x then
						ghostBuildings[uID] = { defID = defID, x = x, z = z, teamID = uTeam }
					end
				end
			end
		end
	end
end
end -- do block for initScan locals

-- For spectators, center on map and zoom out more (always on new game, even if has saved config)
do
	local isSpectator = Spring.GetSpectatingState()
	local currentGameID = Game.gameID and Game.gameID or Spring.GetGameRulesParam("GameID")
	local isNewGame = not miscState.savedGameID or miscState.savedGameID ~= currentGameID
	if isSpectator and isNewGame then
		-- Center on map
		cameraState.wcx = mapInfo.mapSizeX / 2
		cameraState.wcz = mapInfo.mapSizeZ / 2
		cameraState.targetWcx = cameraState.wcx
		cameraState.targetWcz = cameraState.wcz
		-- Zoom out to cover most of the map
		cameraState.zoom = 0.1
		cameraState.targetZoom = 0.1
	elseif (not cameraState.wcx or not cameraState.wcz) and miscState.startX and miscState.startX >= 0 then
		-- Only set camera position if not already loaded from config (for players)
		-- Set zoom to 0.5 for players
		cameraState.zoom = 0.5
		cameraState.targetZoom = 0.5
		-- Apply map margin limits to start position
		local pipWidth, pipHeight = GetEffectivePipDimensions()
		local visibleWorldWidth = pipWidth / cameraState.zoom
		local visibleWorldHeight = pipHeight / cameraState.zoom
		cameraState.wcx = ClampCameraAxis(miscState.startX, visibleWorldWidth, mapInfo.mapSizeX, config.mapEdgeMargin)
		cameraState.wcz = ClampCameraAxis(miscState.startZ, visibleWorldHeight, mapInfo.mapSizeZ, config.mapEdgeMargin)
		cameraState.targetWcx, cameraState.targetWcz = cameraState.wcx, cameraState.wcz  -- Initialize targets
	end
end

-- Minimap mode: hide the engine minimap since we're replacing it
if isMinimapMode then
	-- Store original minimap geometry and minimize state for restoration on shutdown
	miscState.oldMinimapGeometry = Spring.GetMiniMapGeometry()
	miscState.oldMinimapMinimized = Spring.GetConfigInt("MinimapMinimize", 0)
	-- Fully hide the engine minimap: slave it so it only renders when we call gl.DrawMiniMap() (which we don't)
	Spring.SendCommands("minimap minimize 1")
	gl.SlaveMiniMap(true)
	-- Disable the gui_minimap widget if it's running (we're replacing it)
	-- Use FindWidget which works reliably during luaui reload
	if widgetHandler:FindWidget("Minimap") then
		widgetHandler:DisableWidget("Minimap")
	end
	
	-- In minimap mode, don't start minimized and center on map
	uiState.inMinMode = false
	-- Honour MinimapMinimize: start hidden if user had the minimap minimized
	miscState.minimapMinimized = (miscState.oldMinimapMinimized == 1)
	-- Only reset camera if not restored from config (luaui reload)
	if not miscState.minimapCameraRestored then
		cameraState.wcx = mapInfo.mapSizeX / 2
		cameraState.wcz = mapInfo.mapSizeZ / 2
		cameraState.targetWcx = cameraState.wcx
		cameraState.targetWcz = cameraState.wcz
		-- Start zoomed out to see full map (will be adjusted based on aspect ratio in ViewResize)
		cameraState.zoom = 0.1
		cameraState.targetZoom = 0.1
	end
else
	-- Always minimize PIP when first starting (only on fresh start, not on reload)
	if not uiState.inMinMode and not miscState.hadSavedConfig then
		uiState.savedDimensions = {
			l = render.dim.l,
			r = render.dim.r,
			b = render.dim.b,
			t = render.dim.t
		}
	end
end

	widget:ViewResize()

	-- Create API for other widgets
	WG['pip'..pipNumber] = {}
	WG['pip'..pipNumber].IsAbove = function(mx, my)
		return widget:IsAbove(mx, my)
	end
	WG['pip'..pipNumber].ForceUpdate = function()
		pipR2T.contentNeedsUpdate = true
	end
	WG['pip'..pipNumber].SetUpdateRate = function(fps)
		pipUpdateRate = fps
		pipUpdateInterval = pipUpdateRate > 0 and (1 / pipUpdateRate) or 0
	end
	WG['pip'..pipNumber].GetUpdateRate = function()
		return pipUpdateRate
	end
	WG['pip'..pipNumber].SetMapRuler = function(enabled)
		config.showMapRuler = enabled
	end
	WG['pip'..pipNumber].GetMapRuler = function()
		return config.showMapRuler
	end
	WG['pip'..pipNumber].TrackPlayer = function(playerID)
		if playerID and type(playerID) == "number" then
			-- Prevent tracking yourself
			local myPlayerID = Spring.GetMyPlayerID()
			if playerID == myPlayerID then
				return false
			end
			
			local name, _, isSpec = spFunc.GetPlayerInfo(playerID, false)
			if name and not isSpec then
				interactionState.trackingPlayerID = playerID
				interactionState.areTracking = nil  -- Clear unit tracking
				pipR2T.frameNeedsUpdate = true
				pipR2T.contentNeedsUpdate = true
				pipR2T.losNeedsUpdate = true  -- Update LOS for new tracked player
				return true
			end
		end
		return false
	end
	WG['pip'..pipNumber].UntrackPlayer = function()
		if interactionState.trackingPlayerID then
			interactionState.trackingPlayerID = nil
			pipR2T.frameNeedsUpdate = true
			pipR2T.losNeedsUpdate = true  -- Update LOS when untracking
			return true
		end
		return false
	end
	WG['pip'..pipNumber].GetTrackedPlayer = function()
		return interactionState.trackingPlayerID
	end
	-- API for minimap mode: get visible world area
	WG['pip'..pipNumber].IsMinimapMode = function()
		return isMinimapMode
	end
	WG['pip'..pipNumber].GetVisibleWorldArea = function()
		-- Returns the visible world coordinates: left, right, bottom, top
		return render.world.l, render.world.r, render.world.b, render.world.t
	end
	WG['pip'..pipNumber].GetScreenBounds = function()
		-- Returns the screen coordinates of the PIP
		return render.dim.l, render.dim.r, render.dim.b, render.dim.t
	end
	WG['pip'..pipNumber].IsMinimized = function()
		return uiState.inMinMode or (isMinimapMode and miscState.minimapMinimized)
	end
	WG['pip'..pipNumber].GetZoom = function()
		return cameraState.zoom
	end
	WG['pip'..pipNumber].GetCameraCenter = function()
		return cameraState.wcx, cameraState.wcz
	end
	-- Expose ghost building cache so sibling PIPs can share data on reload
	WG['pip'..pipNumber].GetGhostBuildings = function()
		return ghostBuildings
	end

	-- In minimap mode, also register as WG.pip_minimap for compatibility
	if isMinimapMode then
		WG.pip_minimap = WG['pip'..pipNumber]
		-- Also expose getHeight like the original minimap widget for topbar compatibility
		WG.pip_minimap.getHeight = function()
			if miscState.minimapMinimized then return 0 end
			local padding = WG.FlowUI and WG.FlowUI.elementPadding or 5
			return (render.dim.t - render.dim.b) + padding
		end
		
		-- Register as WG['minimap'] for full compatibility with widgets expecting the original minimap API
		WG['minimap'] = {}
		WG['minimap'].getHeight = function()
			if miscState.minimapMinimized then return 0 end
			local padding = WG.FlowUI and WG.FlowUI.elementPadding or 5
			return (render.dim.t - render.dim.b) + padding
		end
		WG['minimap'].getMaxHeight = function()
			return math.floor(config.minimapModeMaxHeight * render.vsy), config.minimapModeMaxHeight
		end
		WG['minimap'].setMaxHeight = function(value)
			config.minimapModeMaxHeight = value
			widget:ViewResize()
		end
		WG['minimap'].getLeftClickMove = function()
			return config.leftButtonPansCamera
		end
		WG['minimap'].setLeftClickMove = function(value)
			config.leftButtonPansCamera = value
			Spring.SetConfigInt("MinimapLeftClickMove", value and 1 or 0)
		end
		-- API for widgetHandler to detect PIP minimap mode and get transformation info
		WG['minimap'].isPipMinimapActive = function()
			return true  -- Always true when this widget is active in minimap mode
		end
		-- Flag set during DrawInMiniMap calls from PIP (widgets can check this)
		WG['minimap'].isDrawingInPip = false
		-- Get the screen bounds of the PIP minimap for the widgetHandler to use
		WG['minimap'].getScreenBounds = function()
			return render.dim.l, render.dim.b, render.dim.r, render.dim.t
		end
		-- Get the world coordinates visible in the PIP
		WG['minimap'].getVisibleWorldArea = function()
			return render.world.l, render.world.r, render.world.b, render.world.t
		end
		-- Get the current minimap rotation
		WG['minimap'].getRotation = function()
			return render.minimapRotation or 0
		end
		-- Get normalized visible area for GL4 shader widgets (startbox, point_tracker, etc.)
		-- Returns left, right, bottom, top in [0,1] world-normalized coords (NOT Y-flipped)
		WG['minimap'].getNormalizedVisibleArea = function()
			local normVisLeft = render.world.l / mapInfo.mapSizeX
			local normVisRight = render.world.r / mapInfo.mapSizeX
			local normVisBottom = render.world.b / mapInfo.mapSizeZ
			local normVisTop = render.world.t / mapInfo.mapSizeZ
			return normVisLeft, normVisRight, normVisBottom, normVisTop
		end
		-- Get zoom level (1.0 = full map visible, >1 = zoomed in)
		WG['minimap'].getZoomLevel = function()
			return mapInfo.mapSizeX / (render.world.r - render.world.l)
		end
		-- Get/set whether to show spectator pings on the PIP minimap
		WG['minimap'].getShowSpectatorPings = function()
			return config.showSpectatorPings
		end
		WG['minimap'].setShowSpectatorPings = function(value)
			config.showSpectatorPings = value
		end
	end

	for i = 1, #buttons do
		local button = buttons[i]
		if button.command then
			widgetHandler.actionHandler:AddAction(self, button.command, button.OnPress, nil, 'p')

			-- Bind hotkeys for specific commands
			if button.command == 'pip_copy' then
				Spring.SendCommands("unbindkeyset alt+q")
				Spring.SendCommands("bind alt+q pip_copy")
			elseif button.command == 'pip_switch' then
				Spring.SendCommands("unbindkeyset shift+q")
				Spring.SendCommands("bind shift+q pip_switch")
			elseif button.command == 'pip_track' then
				Spring.SendCommands("unbindkeyset alt+a")
				Spring.SendCommands("bind alt+a pip_track")
			end
		end
	end

	-- Register guishader blur for PIP background
	UpdateGuishaderBlur()
end

function widget:ViewResize()

	font = WG['fonts'].getFont(2)

	local oldVsx, oldVsy = render.vsx, render.vsy
	render.vsx, render.vsy = Spring.GetViewGeometry()
	
	-- In minimap mode, calculate position and size like the minimap widget does
	if isMinimapMode then
		-- Use mapEdgeMargin = 0 in minimap mode
		config.mapEdgeMargin = 0

		-- Get current rotation to determine if dimensions should be swapped
		-- When rotation is 90° or 270°, the map appears rotated so width/height swap visually
		local minimapRotation = Spring.GetMiniMapRotation and Spring.GetMiniMapRotation() or 0
		render.minimapRotation = minimapRotation
		render.lastMinimapRotation = minimapRotation
		
		-- Check if rotation is near 90° or 270° (within a small tolerance)
		local rotDeg = math.abs(minimapRotation * 180 / math.pi) % 360
		local is90or270 = (rotDeg > 80 and rotDeg < 100) or (rotDeg > 260 and rotDeg < 280)
		
		-- Calculate map aspect ratio, swapping if rotated 90° or 270°
		local mapRatio
		if is90or270 then
			mapRatio = Game.mapY / Game.mapX  -- Inverted for rotated view
		else
			mapRatio = Game.mapX / Game.mapY
		end
		
		local maxHeight = config.minimapModeMaxHeight
		-- Dynamically determine max width from topbar position (like gui_minimap does)
		local effectiveMaxWidth = config.minimapModeMaxWidth
		if WG['topbar'] and WG['topbar'].GetPosition then
			local topbarArea = WG['topbar'].GetPosition()
			if topbarArea and topbarArea[1] then
				local margin = WG.FlowUI and (WG.FlowUI.elementMargin + WG.FlowUI.elementPadding) or 10
				effectiveMaxWidth = (topbarArea[1] - margin) / render.vsx
			end
		end
		local maxWidth = math.min(maxHeight * mapRatio, effectiveMaxWidth * (render.vsx / render.vsy))
		if maxWidth >= effectiveMaxWidth * (render.vsx / render.vsy) then
			maxHeight = maxWidth / mapRatio
		end
		
		local usedWidth = math.floor(maxWidth * render.vsy)
		local usedHeight = math.floor(maxHeight * render.vsy)
		
		-- Position at top-left corner touching the screen edges (no padding offset)
		render.dim.l = 0
		render.dim.r = usedWidth
		render.dim.b = render.vsy - usedHeight
		render.dim.t = render.vsy
		
		-- Calculate zoom so the map texture fully fits the PIP
		-- Use full dimensions since we're edge-to-edge
		local contentWidth = usedWidth
		local contentHeight = usedHeight
		
		-- Calculate zoom based on which dimension is the limiting factor
		-- For rotated maps, the visible dimensions are swapped
		local fitZoomX, fitZoomZ
		if is90or270 then
			-- When rotated 90/270, width constraint applies to Z, height to X
			fitZoomX = contentHeight / mapInfo.mapSizeX
			fitZoomZ = contentWidth / mapInfo.mapSizeZ
		else
			fitZoomX = contentWidth / mapInfo.mapSizeX
			fitZoomZ = contentHeight / mapInfo.mapSizeZ
		end
		local fitZoom = math.min(fitZoomX, fitZoomZ)  -- Use min to ensure full map is visible at max zoom-out

		-- Set min zoom for current orientation (recalculated on rotation change via ViewResize)
		minimapModeMinZoom = fitZoom
		
		-- Only set camera defaults if not restored from config (i.e., not a luaui reload)
		if miscState.minimapCameraRestored then
			-- Restored from config - just ensure zoom isn't below minimum
			if cameraState.zoom < fitZoom then
				cameraState.zoom = fitZoom
				cameraState.targetZoom = fitZoom
			end
		else
			-- Not restored - set to fit full map
			cameraState.zoom = fitZoom
			cameraState.targetZoom = fitZoom
			cameraState.wcx = mapInfo.mapSizeX / 2
			cameraState.wcz = mapInfo.mapSizeZ / 2
			cameraState.targetWcx = cameraState.wcx
			cameraState.targetWcz = cameraState.wcz
		end
		
		-- Force recalculation of world coordinates immediately for minimap mode
		-- This ensures the first frame renders with correct bounds
		RecalculateWorldCoordinates()
		RecalculateGroundTextureCoordinates()
	else
		-- Normal PIP mode: scale dimensions with screen size
		-- When in minMode, render.dim is the tiny button — use savedDimensions as the real dimensions
		local minSize = math.floor(config.minPanelSize * render.widgetScale)
		
		-- Rescale savedDimensions to match new resolution (they're in old pixel coords)
		if uiState.savedDimensions.l and uiState.savedDimensions.r and
		   uiState.savedDimensions.b and uiState.savedDimensions.t and
		   oldVsx > 0 and oldVsy > 0 then
			uiState.savedDimensions.l = math.floor(uiState.savedDimensions.l / oldVsx * render.vsx)
			uiState.savedDimensions.r = math.floor(uiState.savedDimensions.r / oldVsx * render.vsx)
			uiState.savedDimensions.b = math.floor(uiState.savedDimensions.b / oldVsy * render.vsy)
			uiState.savedDimensions.t = math.floor(uiState.savedDimensions.t / oldVsy * render.vsy)
		end
		
		if uiState.inMinMode then
			-- In min mode, render.dim is the tiny button — don't validate it as expanded dims.
			-- Just ensure we have valid savedDimensions (or build defaults).
			if not AreExpandedDimensionsValid(uiState.savedDimensions) then
				uiState.savedDimensions = BuildDefaultExpandedDimensions()
			end
			-- render.dim will be overwritten to the button position below
		else
			-- Validate that dimensions are reasonable (not at origin/bottom-left which indicates corruption)
			local dimsValid = render.dim.l and render.dim.r and render.dim.b and render.dim.t and
			                  oldVsx > 0 and oldVsy > 0 and
			                  (render.dim.r - render.dim.l) >= minSize and
			                  (render.dim.t - render.dim.b) >= minSize and
			                  render.dim.r > minSize and  -- Not stuck at bottom-left
			                  render.dim.t > minSize
			
			if dimsValid then
				render.dim.l, render.dim.r, render.dim.b, render.dim.t = render.dim.l/oldVsx, render.dim.r/oldVsx, render.dim.b/oldVsy, render.dim.t/oldVsy
			else
				-- Initialize with default values positioned in upper-right area of screen
				Spring.Echo("PIP: Detected invalid dimensions, resetting to default position")
				render.dim.l = 0.7
				render.dim.r = 0.7 + (config.minPanelSize * render.widgetScale * 1.4) / render.vsx
				render.dim.b = 0.7
				render.dim.t = 0.7 + (config.minPanelSize * render.widgetScale * 1.2) / render.vsy
				-- Also clear saved dimensions since they may be corrupted too
				uiState.savedDimensions = {}
			end
			render.dim.l, render.dim.r, render.dim.b, render.dim.t = math.floor(render.dim.l*render.vsx), math.floor(render.dim.r*render.vsx), math.floor(render.dim.b*render.vsy), math.floor(render.dim.t*render.vsy)
			
			-- Clamp oversized dimensions to max constraints (auto-correct errors from previous sessions)
			local maxSize = math.floor(render.vsy * config.maxPanelSizeVsy)
			if render.dim.r - render.dim.l > maxSize then
				render.dim.r = render.dim.l + maxSize
			end
			if render.dim.t - render.dim.b > maxSize then
				render.dim.b = render.dim.t - maxSize
			end
		end
	end

	render.widgetScale = (render.vsy / 2000) * render.uiScale
	render.usedButtonSize = math.floor(config.buttonSize * render.widgetScale * render.uiScale)

	render.elementPadding = WG.FlowUI.elementPadding
	render.elementCorner = WG.FlowUI.elementCorner
	render.RectRound = WG.FlowUI.Draw.RectRound
	render.UiElement = WG.FlowUI.Draw.Element
	render.RectRoundOutline = WG.FlowUI.Draw.RectRoundOutline
	elementMargin = WG.FlowUI.elementMargin

	-- Invalidate display lists on resize
	if render.minModeDlist then
		gl.DeleteList(render.minModeDlist)
		render.minModeDlist = nil
	end

	-- Invalidate frame textures on resize
	if pipR2T.frameBackgroundTex then
		gl.DeleteTexture(pipR2T.frameBackgroundTex)
		pipR2T.frameBackgroundTex = nil
	end
	if pipR2T.frameButtonsTex then
		gl.DeleteTexture(pipR2T.frameButtonsTex)
		pipR2T.frameButtonsTex = nil
	end
	pipR2T.frameNeedsUpdate = true

	-- Update minimize button position with screen margin
	-- Position the minimize button based on the saved window position (not screen edge)
	local screenMarginPx = math.floor(config.screenMargin * render.vsy)
	local buttonSizeScaled = math.floor(render.usedButtonSize * config.maximizeSizemult)

	-- If we have saved dimensions, position the minimize button at the window's position
	-- This ensures consistency between auto-minimize on load and manual minimize
	-- Validate that saved dimensions are reasonable (not corrupted to bottom-left)
	local minSize = math.floor(config.minPanelSize * render.widgetScale)
	local savedDimsValid = uiState.savedDimensions.l and uiState.savedDimensions.r and 
	                       uiState.savedDimensions.b and uiState.savedDimensions.t and
	                       (uiState.savedDimensions.r - uiState.savedDimensions.l) >= minSize and
	                       (uiState.savedDimensions.t - uiState.savedDimensions.b) >= minSize and
	                       uiState.savedDimensions.r > minSize and
	                       uiState.savedDimensions.t > minSize
	
	if savedDimsValid then
		-- Position based on where the window was (same logic as manual minimize)
		local sw, sh = Spring.GetWindowGeometry()
		if uiState.savedDimensions.l < sw * 0.5 then
			uiState.minModeL = uiState.savedDimensions.l
		else
			uiState.minModeL = uiState.savedDimensions.r - buttonSizeScaled
		end
		if uiState.savedDimensions.b < sh * 0.25 then
			uiState.minModeB = uiState.savedDimensions.b
		else
			uiState.minModeB = uiState.savedDimensions.t - buttonSizeScaled
		end
	else
		-- Fallback to top-right corner if no valid saved dimensions
		uiState.minModeL = render.vsx - buttonSizeScaled - screenMarginPx
		uiState.minModeB = render.vsy - buttonSizeScaled - screenMarginPx
	end
	
	-- Validate minMode position isn't at bottom-left (indicating corruption)
	if uiState.minModeL < buttonSizeScaled and uiState.minModeB < buttonSizeScaled then
		-- Corrupted position, reset to top-right corner
		uiState.minModeL = render.vsx - buttonSizeScaled - screenMarginPx
		uiState.minModeB = render.vsy - buttonSizeScaled - screenMarginPx
	end

	-- If we're in min mode, ensure window is positioned at the minimize button location
	if uiState.inMinMode then
		render.dim.l = uiState.minModeL
		render.dim.r = uiState.minModeL + buttonSizeScaled
		render.dim.b = uiState.minModeB
		render.dim.t = uiState.minModeB + buttonSizeScaled
	else
		-- Only correct screen position when not in min mode
		CorrectScreenPosition()
	end

	-- Clamp camera position to respect margin after view resize
	local pipWidth = render.dim.r - render.dim.l
	local pipHeight = render.dim.t - render.dim.b
	
	-- Swap dimensions when rotated 90°/270°
	if render.minimapRotation then
		local rotDeg = math.abs(render.minimapRotation * 180 / math.pi) % 180
		if rotDeg > 45 and rotDeg < 135 then
			pipWidth, pipHeight = pipHeight, pipWidth
		end
	end

	-- Calculate dynamic min zoom so full map is visible at max zoom-out
	-- Use raw (non-rotated) dimensions and take min(dim)/max(mapSize) so zoom limit is the same regardless of rotation
	if not isMinimapMode then
		-- When minimized, use saved expanded dimensions (not the tiny button size)
		local rawW, rawH
		if uiState.inMinMode and uiState.savedDimensions.l and uiState.savedDimensions.r then
			rawW = uiState.savedDimensions.r - uiState.savedDimensions.l
			rawH = uiState.savedDimensions.t - uiState.savedDimensions.b
		else
			rawW = render.dim.r - render.dim.l
			rawH = render.dim.t - render.dim.b
		end
		pipModeMinZoom = math.min(rawW, rawH) / math.max(mapInfo.mapSizeX, mapInfo.mapSizeZ)
		if cameraState.zoom < pipModeMinZoom then
			cameraState.zoom = pipModeMinZoom
			cameraState.targetZoom = pipModeMinZoom
		end
	end
	
	local visibleWorldWidth = pipWidth / cameraState.zoom
	local visibleWorldHeight = pipHeight / cameraState.zoom

	cameraState.wcx = ClampCameraAxis(cameraState.wcx, visibleWorldWidth, mapInfo.mapSizeX, config.mapEdgeMargin)
	cameraState.wcz = ClampCameraAxis(cameraState.wcz, visibleWorldHeight, mapInfo.mapSizeZ, config.mapEdgeMargin)
	cameraState.targetWcx = cameraState.wcx
	cameraState.targetWcz = cameraState.wcz

	RecalculateWorldCoordinates()
	RecalculateGroundTextureCoordinates()

	-- Delete and recreate textures on size change
	if pipR2T.contentTex then
		gl.DeleteTexture(pipR2T.contentTex)
		pipR2T.contentTex = nil
	end
	if pipR2T.unitsTex then
		gl.DeleteTexture(pipR2T.unitsTex)
		pipR2T.unitsTex = nil
	end
	-- Invalidate content mask cache to force regeneration with correct dimensions
	pipR2T.contentMaskLastWidth = 0
	pipR2T.contentMaskLastHeight = 0
	pipR2T.contentMaskLastL = -1
	pipR2T.contentMaskLastB = -1
	pipR2T.contentNeedsUpdate = true
	pipR2T.unitsNeedsUpdate = true

	-- Update guishader blur dimensions
	UpdateGuishaderBlur()
end

function widget:PlayerChanged(playerID)
	-- Update LOS texture when player state changes (e.g., entering/exiting spec mode)
	pipR2T.losNeedsUpdate = true

	-- Invalidate cached takeable teams (leadership may have changed)
	cachedTakeableTeams = nil

	-- Update spec state
	cameraState.mySpecState = Spring.GetSpectatingState()

	-- Don't clear ghost buildings here: PlayerChanged fires frequently (on any player's
	-- state change, team switches, etc.) and clearing ghosts causes them to vanish.
	-- The periodic ghost scan uses mark-and-sweep to keep ghosts fresh.

	-- Keep tracking even if fullview is disabled - tracking will resume when fullview is re-enabled
end

function widget:GameOver()
	-- Disable LOS view on game over (spectators get full view, LOS filtering is no longer useful)
	if state.losViewEnabled then
		state.losViewEnabled = false
		state.losViewAllyTeam = nil
		for k in pairs(ghostBuildings) do ghostBuildings[k] = nil end
		pipR2T.losNeedsUpdate = true
	end

	-- Cancel unit tracking
	interactionState.areTracking = nil
	interactionState.trackingPlayerID = nil

	-- Start smooth zoom-out to full map view and center
	-- Only set targetZoom (not zoom) so the Update loop animates the zoom-out smoothly
	local zoomMin = GetEffectiveZoomMin()
	cameraState.targetZoom = zoomMin
	cameraState.targetWcx = mapInfo.mapSizeX / 2
	cameraState.targetWcz = mapInfo.mapSizeZ / 2

	-- Deactivate TV camera so it stops overriding camera targets
	if pipTV.camera.active then
		pipTV.camera.active = false
	end

	-- Flag to protect the zoom-out animation from being overridden
	miscState.gameOverZoomingOut = true
	miscState.isGameOver = true

	-- Clear takeable teams cache so icons stop blinking (no one can take units after game over)
	cachedTakeableTeams = {}

	pipR2T.frameNeedsUpdate = true
	pipR2T.unitsNeedsUpdate = true
	pipR2T.contentNeedsUpdate = true
end

function widget:Shutdown()
	-- Check if another PIP instance is still running.
	-- Deleting GL resources (atlas, shaders, VBOs, display lists) while another PIP instance
	-- is active can corrupt the engine's internal resource tracking, causing "opaque squares"
	-- for unit icons in the surviving PIP. Defer GPU resource cleanup if another PIP is alive.
	local anotherPipActive = false
	for n = 0, 4 do
		if n ~= pipNumber and WG['pip' .. n] then
			anotherPipActive = true
			break
		end
	end

	if not anotherPipActive then
		-- Safe to clean up all GPU resources — we're the last PIP instance
		DestroyGL4Icons()
		DestroyGL4Primitives()
		DestroyGL4Decals()

		gl.DeleteList(unitOutlineList)
		gl.DeleteList(radarDotList)
		DeleteSeismicPingDlists()

		if shaders.los then
			gl.DeleteShader(shaders.los)
			shaders.los = nil
		end

		if shaders.minimapShading then
			gl.DeleteShader(shaders.minimapShading)
			shaders.minimapShading = nil
		end

		if shaders.water then
			gl.DeleteShader(shaders.water)
			shaders.water = nil
		end

		if shaders.decal then
			gl.DeleteShader(shaders.decal)
			shaders.decal = nil
		end
	else
		-- Another PIP is still active — only disable GL4 flag (don't delete GPU resources)
		-- The orphaned resources will be freed when the last PIP shuts down or the game ends
		gl4Icons.enabled = false
		gl4Prim.enabled = false
	end

	-- R2T textures are per-instance and safe to always delete
	if pipR2T.contentTex then
		gl.DeleteTexture(pipR2T.contentTex)
		pipR2T.contentTex = nil
	end
	if pipR2T.unitsTex then
		gl.DeleteTexture(pipR2T.unitsTex)
		pipR2T.unitsTex = nil
	end

	-- Clean up content mask dlist
	if pipR2T.contentMaskDlist then
		gl.DeleteList(pipR2T.contentMaskDlist)
		pipR2T.contentMaskDlist = nil
	end

	-- Clean up frame textures
	if pipR2T.frameBackgroundTex then
		gl.DeleteTexture(pipR2T.frameBackgroundTex)
		pipR2T.frameBackgroundTex = nil
	end
	if pipR2T.frameButtonsTex then
		gl.DeleteTexture(pipR2T.frameButtonsTex)
		pipR2T.frameButtonsTex = nil
	end

	-- Clean up LOS texture
	if pipR2T.losTex then
		gl.DeleteTexture(pipR2T.losTex)
		pipR2T.losTex = nil
	end

	-- Clean up decal overlay texture
	if pipR2T.decalTex then
		gl.DeleteTexture(pipR2T.decalTex)
		pipR2T.decalTex = nil
	end

	-- Clean up minimize mode display list
	if render.minModeDlist then
		gl.DeleteList(render.minModeDlist)
		render.minModeDlist = nil
	end

	-- Clean up tracked player overlay display lists
	if pipR2T.resbarTextDlist then
		gl.DeleteList(pipR2T.resbarTextDlist)
		pipR2T.resbarTextDlist = nil
	end
	if pipR2T.playerNameDlist then
		gl.DeleteList(pipR2T.playerNameDlist)
		pipR2T.playerNameDlist = nil
	end

	-- Remove guishader blur
	if WG['guishader'] then
		if WG['guishader'].RemoveDlist then
			WG['guishader'].RemoveDlist('pip'..pipNumber)
		elseif WG['guishader'].RemoveRect then
			WG['guishader'].RemoveRect('pip'..pipNumber)
		end
	end
	-- Clean up guishader dlist
	if render.guishaderDlist then
		gl.DeleteList(render.guishaderDlist)
		render.guishaderDlist = nil
	end

	-- Restore minimap if we were in minimap mode
	if isMinimapMode then
		-- Release the engine minimap from slave mode
		gl.SlaveMiniMap(false)
		-- Restore original minimize state
		if miscState.oldMinimapMinimized == 0 then
			Spring.SendCommands("minimap minimize 0")
		end
		if miscState.oldMinimapGeometry then
			Spring.SendCommands("minimap geometry " .. miscState.oldMinimapGeometry)
		end
		-- Re-enable the gui_minimap widget if it exists
		if widgetHandler.knownWidgets and widgetHandler.knownWidgets["Minimap"] then
			widgetHandler:EnableWidget("Minimap")
		end
	end

	-- Clean up TV focus coordination
	if WG.pipTVFocus then
		WG.pipTVFocus[pipNumber] = nil
		if not next(WG.pipTVFocus) then WG.pipTVFocus = nil end
	end

	-- Clean up API (must happen AFTER the anotherPipActive check above)
	WG['pip'..pipNumber] = nil
	if isMinimapMode then
		WG.pip_minimap = nil
		WG['minimap'] = nil
	end

	for i = 1, #buttons do
		local button = buttons[i]
		if button.command then
			widgetHandler.actionHandler:RemoveAction(self, button.command)

			-- Unbind hotkeys for specific commands
			if button.command == 'pip_copy' then
				Spring.SendCommands("unbind Alt+Q pip_copy")
			elseif button.command == 'pip_switch' then
				Spring.SendCommands("unbind Shift+Q pip_switch")
			elseif button.command == 'pip_track' then
				Spring.SendCommands("unbind Alt+A pip_track")
			end
		end
	end
end

function widget:GetConfigData()
	CorrectScreenPosition()

	-- Guard against uninitialized render dimensions
	if not render.dim.l or not render.dim.r or not render.dim.b or not render.dim.t then return {} end

	-- When in min mode, save the expanded dimensions from uiState.savedDimensions
	local saveL, saveR, saveB, saveT
	if uiState.inMinMode and uiState.savedDimensions.l then
		saveL = uiState.savedDimensions.l / render.vsx
		saveR = uiState.savedDimensions.r / render.vsx
		saveB = uiState.savedDimensions.b / render.vsy
		saveT = uiState.savedDimensions.t / render.vsy
	else
		saveL = render.dim.l / render.vsx
		saveR = render.dim.r / render.vsx
		saveB = render.dim.b / render.vsy
		saveT = render.dim.t / render.vsy
	end

	return {
		pl=saveL, pr=saveR, pb=saveB, pt=saveT,
		zoom=cameraState.zoom,
		wcx=cameraState.wcx,
		wcz=cameraState.wcz,
		inMinMode=uiState.inMinMode,
		minModeL=uiState.minModeL,
		minModeB=uiState.minModeB,
		areTracking=interactionState.areTracking,
		trackingPlayerID=interactionState.trackingPlayerID,
		losViewEnabled=state.losViewEnabled,
		losViewAllyTeam=state.losViewAllyTeam,
		showUnitpics=config.showUnitpics,
		unitpicZoomThreshold=config.unitpicZoomThreshold,
		explosionOverlay=config.explosionOverlay,
		explosionOverlayAlpha=config.explosionOverlayAlpha,
		healthDarkenMax=config.healthDarkenMax,
		activityFocusEnabled=miscState.activityFocusEnabled,
		activityFocusIgnoreSpectators=config.activityFocusIgnoreSpectators,
		tvEnabled=miscState.tvEnabled,
		hideAICommands=config.hideAICommands,
		gameID = Game.gameID or Spring.GetGameRulesParam("GameID"),
		-- Minimap mode settings
		minimapModeMaxHeight = config.minimapModeMaxHeight,
		-- leftButtonPansCamera now stored as Spring ConfigInt "MinimapLeftClickMove"
		-- Minimap mode camera state (for luaui reload restoration)
		minimapModeWcx = isMinimapMode and cameraState.wcx or nil,
		minimapModeWcz = isMinimapMode and cameraState.wcz or nil,
		minimapModeZoom = isMinimapMode and cameraState.zoom or nil,
		-- Ghost building positions persist across luaui reload (same game only)
		ghostBuildings = ghostBuildings,
	}
end

function widget:SetConfigData(data)
	if not data or not data.gameID then return end	-- prevent loading empty/corrupted data

	miscState.hadSavedConfig = (data and next(data) ~= nil) -- Mark that we have saved config data
	miscState.savedGameID = data and data.gameID -- Store saved gameID for new game detection in Initialize

	-- Validate and sanitize position data to prevent corruption
	local function isValidNumber(val, min, max)
		return val and type(val) == "number" and val == val and val >= min and val <= max
	end

	-- Don't restore uiState.minModeL/uiState.minModeB - always recalculate position in top-right corner
	-- uiState.minModeL and uiState.minModeB will be set by ViewResize

	-- First restore the expanded dimensions if available and valid
	if data.pl and data.pr and data.pb and data.pt then
		-- Validate that the position values are reasonable (between 0 and 1 as normalized coords)
		if isValidNumber(data.pl, 0, 1) and isValidNumber(data.pr, 0, 1) and 
		   isValidNumber(data.pb, 0, 1) and isValidNumber(data.pt, 0, 1) and
		   data.pl < data.pr and data.pb < data.pt then  -- Ensure left < right and bottom < top
			
			local tempL = math.floor(data.pl*render.vsx)
			local tempR = math.floor(data.pr*render.vsx)
			local tempB = math.floor(data.pb*render.vsy)
			local tempT = math.floor(data.pt*render.vsy)
			
			-- Additional sanity check: ensure dimensions are within screen bounds
			local minSize = math.floor(config.minPanelSize * render.widgetScale)
			local maxSize = math.floor(render.vsy * config.maxPanelSizeVsy)
			local windowWidth = tempR - tempL
			local windowHeight = tempT - tempB
			
			-- Clamp oversized dimensions to max constraints
			if windowWidth > maxSize then
				tempR = tempL + maxSize
				windowWidth = maxSize
			end
			if windowHeight > maxSize then
				tempB = tempT - maxSize
				windowHeight = maxSize
			end
			
			if windowWidth >= minSize and windowHeight >= minSize and
			   tempL >= 0 and tempR <= render.vsx and
			   tempB >= 0 and tempT <= render.vsy then
				
				uiState.savedDimensions = {
					l = tempL,
					r = tempR,
					b = tempB,
					t = tempT
				}
				-- Set dim to expanded size initially
				render.dim.l = uiState.savedDimensions.l
				render.dim.r = uiState.savedDimensions.r
				render.dim.b = uiState.savedDimensions.b
				render.dim.t = uiState.savedDimensions.t
				CorrectScreenPosition()
			else
				-- Invalid dimensions - use default center position
				Spring.Echo("PIP: Invalid saved dimensions detected, resetting to default position")
			end
		else
			-- Invalid position data - don't restore
			Spring.Echo("PIP: Corrupted position data detected, resetting to default position")
		end
	end

	-- Always force minimize if in pregame AND it's a new game (different gameID)
	local gameFrame = Spring.GetGameFrame()
	local currentGameID = Game.gameID and Game.gameID or Spring.GetGameRulesParam("GameID")
	local isSameGame = (data.gameID and currentGameID and data.gameID == currentGameID)

	if gameFrame == 0 and not isSameGame then
		-- Force minimize in pregame for a new game
		uiState.inMinMode = true
	elseif data.inMinMode ~= nil then
		-- Restore saved state if same game or if in active game
		uiState.inMinMode = data.inMinMode
		-- If restoring to maximized state, mark as opened this game
		if not data.inMinMode then
			miscState.hasOpenedPIPThisGame = true
		end
	else
		-- Default to minimized if no saved state
		uiState.inMinMode = true
	end

	-- If no valid saved data, keep existing dim values (initialized at top of file)

	-- Validate camera coordinates (must be within map bounds)
	local maxX = mapInfo.mapSizeX
	local maxZ = mapInfo.mapSizeZ
	
	if isMinimapMode then
		-- In minimap mode, only restore camera state on luaui reload (same game)
		-- At game launch, camera should start centered at minimum zoom
		if isSameGame then
			if data.minimapModeWcx and isValidNumber(data.minimapModeWcx, 0, maxX) then
				cameraState.wcx = data.minimapModeWcx
			end
			if data.minimapModeWcz and isValidNumber(data.minimapModeWcz, 0, maxZ) then
				cameraState.wcz = data.minimapModeWcz
			end
			cameraState.targetWcx, cameraState.targetWcz = cameraState.wcx, cameraState.wcz
			
			if data.minimapModeZoom and isValidNumber(data.minimapModeZoom, 0, 1) then
				cameraState.zoom = data.minimapModeZoom
				cameraState.targetZoom = cameraState.zoom
				miscState.minimapCameraRestored = true  -- Flag that we restored camera state
			end
		end
		-- If not same game, leave camera at defaults (centered, min zoom) set in Initialize
	else
		-- Regular PIP mode - restore camera position
		if data.wcx and isValidNumber(data.wcx, 0, maxX) then
			cameraState.wcx = data.wcx
		end
		if data.wcz and isValidNumber(data.wcz, 0, maxZ) then
			cameraState.wcz = data.wcz
		end
		cameraState.targetWcx, cameraState.targetWcz = cameraState.wcx, cameraState.wcz  -- Initialize targets from config
		
		-- Validate zoom level (must be between 0 and 1)
		if data.zoom and isValidNumber(data.zoom, 0, 1) then
			cameraState.zoom = data.zoom
		end
	end
	
	if data.showUnitpics ~= nil then config.showUnitpics = data.showUnitpics end
	if data.explosionOverlay ~= nil then config.explosionOverlay = data.explosionOverlay end
	if data.explosionOverlayAlpha then config.explosionOverlayAlpha = data.explosionOverlayAlpha end
	if data.hideAICommands ~= nil then config.hideAICommands = data.hideAICommands end
	if data.healthDarkenMax ~= nil then config.healthDarkenMax = data.healthDarkenMax end
	if data.activityFocusEnabled ~= nil then miscState.activityFocusEnabled = data.activityFocusEnabled end
	if data.activityFocusIgnoreSpectators ~= nil then config.activityFocusIgnoreSpectators = data.activityFocusIgnoreSpectators end
	if data.tvEnabled ~= nil then
		miscState.tvEnabled = data.tvEnabled
		if miscState.tvEnabled then
			pipTV.camera.active = true
			pipTV.director.idle = true
			pipTV.director.lastOverviewTime = os.clock()
		end
	end
	--if data.unitpicZoomThreshold then config.unitpicZoomThreshold = data.unitpicZoomThreshold end
	
	-- Restore minimap mode settings
	if data.minimapModeMaxHeight and type(data.minimapModeMaxHeight) == "number" and data.minimapModeMaxHeight > 0 and data.minimapModeMaxHeight <= 1 then
		config.minimapModeMaxHeight = data.minimapModeMaxHeight
	end
	-- leftButtonPansCamera now read from Spring ConfigInt "MinimapLeftClickMove"
	if data.leftButtonPansCamera ~= nil and Spring.GetConfigInt("MinimapLeftClickMove", -1) == -1 then
		-- Migrate old config data to new ConfigInt (one-time)
		config.leftButtonPansCamera = data.leftButtonPansCamera
		Spring.SetConfigInt("MinimapLeftClickMove", data.leftButtonPansCamera and 1 or 0)
	end

	local currentGameID = Game.gameID and Game.gameID or Spring.GetGameRulesParam("GameID")
	local isSameGame = (data.gameID and currentGameID and data.gameID == currentGameID)

	-- Restore ghost buildings from saved config (same game only — positions are game-specific)
	if isSameGame and data.ghostBuildings then
		ghostBuildings = data.ghostBuildings
	end

	if Spring.GetGameFrame() > 0 or isSameGame then
		interactionState.areTracking = data.areTracking

		-- Restore player tracking if same game and player still exists
		if data.trackingPlayerID and isSameGame then
			local playerName = spFunc.GetPlayerInfo(data.trackingPlayerID, false)
			if playerName then
				-- Restore the tracking - validation happens in UpdatePlayerTracking
				interactionState.trackingPlayerID = data.trackingPlayerID
				-- Force frame update to show button
				pipR2T.frameNeedsUpdate = true
			end
		end

		-- Restore LOS view state only if same game
		if isSameGame then
			if data.losViewEnabled ~= nil then
				state.losViewEnabled = data.losViewEnabled
			end
			if data.losViewAllyTeam ~= nil then
				state.losViewAllyTeam = data.losViewAllyTeam
			end
			if state.losViewEnabled then
				pipR2T.losNeedsUpdate = true
				pipR2T.frameNeedsUpdate = true
			end
		end
	end
	cameraState.targetZoom = cameraState.zoom
end

-- Helper function to draw formation dots overlay
local function DrawFormationDotsOverlay()
	if not (interactionState.areFormationDragging and WG.customformations) then
		return
	end

	local formationNodes = WG.customformations.GetFormationNodes and WG.customformations.GetFormationNodes()
	local lineLength = WG.customformations.GetFormationLineLength and WG.customformations.GetFormationLineLength()
	local selectedUnitsCount = WG.customformations.GetSelectedUnitsCount and WG.customformations.GetSelectedUnitsCount()
	local formationCmd = WG.customformations.GetFormationCommand and WG.customformations.GetFormationCommand()

	if not (formationNodes and #formationNodes > 1 and lineLength and selectedUnitsCount and selectedUnitsCount > 1 and lineLength > 0) then
		return
	end

	-- Set color based on command type
	local r, g, b = 0.5, 0.5, 1.0
	if formationCmd == CMD.MOVE then
		r, g, b = 0.5, 1.0, 0.5
	elseif formationCmd == CMD.ATTACK then
		r, g, b = 1.0, 0.2, 0.2
	elseif formationCmd == CMD.FIGHT then
		r, g, b = 0.5, 0.5, 1.0
	end

	local lengthPerUnit = lineLength / (selectedUnitsCount - 1)
	local dotSize = math.floor(render.vsy * 0.0085)

	local function DrawScreenDot(sx, sy)
		glFunc.Color(r, g, b, 1)
		glFunc.Texture("LuaUI/Images/formationDot.dds")
		glFunc.TexRect(sx - dotSize, sy - dotSize, sx + dotSize, sy + dotSize)
	end

	-- Draw first dot
	local sx, sy = WorldToPipCoords(formationNodes[1][1], formationNodes[1][3])
	if sx >= render.dim.l and sx <= render.dim.r and sy >= render.dim.b and sy <= render.dim.t then
		DrawScreenDot(sx, sy)
	end

	-- Draw dots along the line
	if #formationNodes > 2 then
		local currentLength = 0
		local lengthUnitNext = lengthPerUnit

		for i = 1, #formationNodes - 1 do
			local node1 = formationNodes[i]
			local node2 = formationNodes[i + 1]
			local dx = node1[1] - node2[1]
			local dz = node1[3] - node2[3]
			local length = math.sqrt(dx * dx + dz * dz)

			while currentLength + length >= lengthUnitNext do
				local factor = (lengthUnitNext - currentLength) / length
				local wx = node1[1] + (node2[1] - node1[1]) * factor
				local wz = node1[3] + (node2[3] - node1[3]) * factor

				sx, sy = WorldToPipCoords(wx, wz)
				if sx >= render.dim.l and sx <= render.dim.r and sy >= render.dim.b and sy <= render.dim.t then
					DrawScreenDot(sx, sy)
				end

				lengthUnitNext = lengthUnitNext + lengthPerUnit
			end
			currentLength = currentLength + length
		end
	end

	-- Draw last dot
	sx, sy = WorldToPipCoords(formationNodes[#formationNodes][1], formationNodes[#formationNodes][3])
	if sx >= render.dim.l and sx <= render.dim.r and sy >= render.dim.b and sy <= render.dim.t then
		DrawScreenDot(sx, sy)
	end

	glFunc.Texture(false)
end

-- Pre-created blit function for decal overlay (avoids per-frame closure allocation).
-- References render.ground tables via upvalue; values update in-place so function stays valid.
local function decalBlitQuad()
	glFunc.TexCoord(render.ground.coord.l, render.ground.coord.b); glFunc.Vertex(render.ground.view.l, render.ground.view.b)
	glFunc.TexCoord(render.ground.coord.r, render.ground.coord.b); glFunc.Vertex(render.ground.view.r, render.ground.view.b)
	glFunc.TexCoord(render.ground.coord.r, render.ground.coord.t); glFunc.Vertex(render.ground.view.r, render.ground.view.t)
	glFunc.TexCoord(render.ground.coord.l, render.ground.coord.t); glFunc.Vertex(render.ground.view.l, render.ground.view.t)
end

-- Draw ground decals (explosion scars) from the cached decal R2T texture.
-- The decal texture covers the full map and is updated periodically by UpdateDecalTexture().
-- Uses multiply blending to darken ground where decals exist; white = no change.
local function DrawDecalsOverlay()
	if not config.drawDecals then return end
	if not pipR2T.decalTex then return end
	if decalGL4.instanceCount == 0 then return end  -- no decals to draw

	-- Blit decal texture with multiply blending: result = ground_color * decal_tex_color
	-- Alpha: preserve destination alpha (prevents 3D world showing through PIP)
	gl.Scissor(render.dim.l, render.dim.b, render.dim.r - render.dim.l, render.dim.t - render.dim.b)
	gl.DepthTest(false)
	gl.BlendFuncSeparate(GL.DST_COLOR, GL.ZERO, GL.ZERO, GL.ONE)
	glFunc.Color(1, 1, 1, 1)
	glFunc.Texture(pipR2T.decalTex)

	-- Map visible world portion to screen using pre-created function (no closure allocation)
	glFunc.BeginEnd(GL.QUADS, decalBlitQuad)

	glFunc.Texture(false)
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	gl.Scissor(false)
end

-- Helper function to draw command queues overlay
-- Draw command FX: fading lines from unit to command target
local function DrawCommandFXOverlay()
	if not config.drawCommandFX then return end
	if commandFX.count == 0 then return end

	local useGL4 = gl4Prim.enabled
	local resScale = render.contentScale or 1
	local now = wallClockTime  -- Use wall-clock time so FX fades even when paused

	local baseDuration = config.commandFXDuration
	local fxDuration = baseDuration
	local fxAlpha = config.commandFXOpacity

	-- Compact: remove expired entries and draw active ones
	local writeIdx = 0

	if useGL4 then
		gl4Prim.normLines.count = 0

		for i = 1, commandFX.count do
			local fx = commandFX.list[i]
			local age = now - fx.time
			if age < fxDuration then
				writeIdx = writeIdx + 1
				if writeIdx ~= i then
					commandFX.list[writeIdx] = fx
				end
				local progress = age / fxDuration
				local alpha = fxAlpha * (1 - progress)
				local color = fx.color
				local r, g, b = color[1], color[2], color[3]

				GL4AddNormLine(fx.unitX, fx.unitZ, fx.targetX, fx.targetZ,
					r, g, b, alpha, r, g, b, alpha)
			end
		end

		-- Clean up trailing entries
		for i = writeIdx + 1, commandFX.count do
			commandFX.list[i] = nil
		end
		commandFX.count = writeIdx

		-- Flush via GL4 shaders
		if gl4Prim.normLines.count > 0 then
			gl.Scissor(render.dim.l, render.dim.b, render.dim.r - render.dim.l, render.dim.t - render.dim.b)
			gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
			gl.DepthTest(false)

			GL4SetPrimUniforms(gl4Prim.lineShader, gl4Prim.lineUniformLocs)
			local ln = gl4Prim.normLines
			ln.vbo:Upload(ln.data, nil, 0, 1, ln.count * gl4Prim.LINE_STEP)
			glFunc.LineWidth(1.0 * resScale)
			ln.vao:DrawArrays(GL.LINES, ln.count)
			glFunc.LineWidth(1.0)
			gl.UseShader(0)

			gl.Scissor(false)
		end
	end
end

local function DrawCommandQueuesOverlay(cachedSelectedUnits)
	-- Check if Shift+Space (meta) is held to show all visible units
	local alt, ctrl, meta, shift = Spring.GetModKeyState()
	local showAllUnits = shift and meta

	-- Reuse pool table instead of allocating new one
	local unitsToShow = pools.unitsToShow
	local unitCount = 0

	if showAllUnits then
		-- Show command queues for all visible units in PIP window
		if miscState.pipUnits then
			local pUnitCount = #miscState.pipUnits
			for i = 1, pUnitCount do
				local uID = miscState.pipUnits[i]
				-- Filter out AI units: always skip scavenger/raptor, optionally skip other AI
				local uTeam = spFunc.GetUnitTeam(uID)
				if not scavRaptorTeams[uTeam] and not (config.hideAICommands and aiTeams[uTeam]) then
					unitCount = unitCount + 1
					unitsToShow[unitCount] = uID
				end
			end
		end
	else
		-- Show only selected units (or tracked player's selected units)
		if interactionState.trackingPlayerID then
			-- Get tracked player's selected units — write directly into pool to avoid table alloc
			local playerSelections = WG['allyselectedunits'] and WG['allyselectedunits'].getPlayerSelectedUnits(interactionState.trackingPlayerID)
			if playerSelections then
				for unitID, _ in pairs(playerSelections) do
					unitCount = unitCount + 1
					unitsToShow[unitCount] = unitID
				end
			end
		else
			-- Use cached selected units to avoid redundant API call
			local selectedUnits = cachedSelectedUnits
			if not selectedUnits then
				return
			end
			local selectedCount = #selectedUnits
			if selectedCount == 0 then
				return
			end
			for i = 1, selectedCount do
				unitsToShow[i] = selectedUnits[i]
			end
			unitCount = selectedCount
		end
	end

	if unitCount == 0 then
		return
	end

	local resScale = render.contentScale or 1
	local useGL4Commands = gl4Prim.enabled
	local maxUnits = Game.maxUnits or 32000  -- Features encoded as featureID + maxUnits

	-- ========================================================================
	-- Waypoint cache: only call GetUnitCommands every CMD_CACHE_INTERVAL frames
	-- GetUnitCommands allocates ~60 tables per unit per call (outer + cmd + params),
	-- causing massive GC pressure. We cache the extracted positions/cmdIDs and
	-- only refresh periodically or when the unit list changes.
	-- ========================================================================
	cmdQueueCache.counter = cmdQueueCache.counter + 1

	-- Periodically prune wpCache entries for dead units (~every 5 seconds at 60fps)
	if cmdQueueCache.counter % 300 == 0 then
		local wpCache = cmdQueueCache.waypoints
		for uID in pairs(wpCache) do
			if not spFunc.GetUnitPosition(uID) then
				wpCache[uID] = nil
			end
		end
	end

	-- Quick hash to detect unit list changes: unitCount + first/last unitIDs
	local unitHash = unitCount
	if unitCount > 0 then unitHash = unitHash + unitsToShow[1] end
	if unitCount > 1 then unitHash = unitHash + unitsToShow[unitCount] end
	if unitCount > 2 then unitHash = unitHash + unitsToShow[math.floor(unitCount / 2)] end

	local needRefresh = (cmdQueueCache.counter % CMD_CACHE_INTERVAL == 0)
		or (unitHash ~= cmdQueueCache.lastUnitHash)
	cmdQueueCache.lastUnitHash = unitHash

	if needRefresh then
		local wpCache = cmdQueueCache.waypoints
		for i = 1, unitCount do
			local uID = unitsToShow[i]
			local unitTeam = spFunc.GetUnitTeam(uID)
			-- Skip gaia units, and skip AI units (always for scav/raptor, optionally for other AI)
			if unitTeam ~= gaiaTeamID and not scavRaptorTeams[unitTeam] and not (config.hideAICommands and aiTeams[unitTeam]) then
				local commands = spFunc.GetUnitCommands(uID, 30)
				local cached = wpCache[uID]
				if not cached then
					cached = { n = 0 }
					wpCache[uID] = cached
				end
				local wpCount = 0
				if commands then
					for j = 1, #commands do
						local cmd = commands[j]
						local cmdX, cmdZ
						local params = cmd.params
						if params then
							local paramCount = #params
							if paramCount == 3 or cmd.id == 10 then
								cmdX, cmdZ = params[1], params[3]
							elseif paramCount == 4 then
								cmdX, cmdZ = params[1], params[3]
							elseif paramCount == 5 then
								if params[1] > 0 and params[1] < 1000000 then
									local tx, _, tz = spFunc.GetUnitPosition(params[1])
									if tx then cmdX, cmdZ = tx, tz end
								else
									cmdX, cmdZ = params[2], params[4]
								end
							elseif paramCount == 1 then
								local targetID = params[1]
								local tx, _, tz
								if targetID >= maxUnits then
									tx, _, tz = spFunc.GetFeaturePosition(targetID - maxUnits)
								else
									tx, _, tz = spFunc.GetUnitPosition(targetID)
								end
								if tx then cmdX, cmdZ = tx, tz end
							end
						end
						if cmdX and cmdZ then
							wpCount = wpCount + 1
							local wp = cached[wpCount]
							if not wp then
								wp = { 0, 0, 0 }  -- {worldX, worldZ, cmdID}
								cached[wpCount] = wp
							end
							wp[1], wp[2], wp[3] = cmdX, cmdZ, cmd.id
						end
					end
				end
				cached.n = wpCount
			else
				-- Gaia unit — clear any stale cache
				local cached = wpCache[uID]
				if cached then cached.n = 0 end
			end
		end
	end

	-- ========================================================================
	-- GL4 rendering path
	-- ========================================================================
	if useGL4Commands then
		gl4Prim.normLines.count = 0
		gl4Prim.circles.count = 0

		local wpCache = cmdQueueCache.waypoints
		for i = 1, unitCount do
			local uID = unitsToShow[i]
			local cached = wpCache[uID]
			if cached and cached.n > 0 then
				local ux, _, uz = spFunc.GetUnitPosition(uID)
				if ux then
					local prevWX, prevWZ = ux, uz
					for j = 1, cached.n do
						local wp = cached[j]
						local cmdX, cmdZ, cmdID = wp[1], wp[2], wp[3]
						local color = cmdColors[cmdID] or cmdColors.unknown
						local r, g, b = color[1], color[2], color[3]

						GL4AddNormLine(prevWX, prevWZ, cmdX, cmdZ,
							r, g, b, 0.8, r, g, b, 0.8)

						prevWX, prevWZ = cmdX, cmdZ
					end
				end
			end
		end

		-- Clear leftover entries in pools
		for i = unitCount + 1, #unitsToShow do
			unitsToShow[i] = nil
		end

		-- Flush via GL4 shaders
		if gl4Prim.normLines.count > 0 or gl4Prim.circles.count > 0 then
			gl.Scissor(render.dim.l, render.dim.b, render.dim.r - render.dim.l, render.dim.t - render.dim.b)
			gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
			gl.DepthTest(false)

			if gl4Prim.circles.count > 0 then
				local c = gl4Prim.circles
				c.vbo:Upload(c.data, nil, 0, 1, c.count * gl4Prim.CIRCLE_STEP)
				GL4SetPrimUniforms(c.shader, c.uniformLocs)
				c.vao:DrawArrays(GL.POINTS, c.count)
				gl.UseShader(0)
			end

			if gl4Prim.normLines.count > 0 then
				GL4SetPrimUniforms(gl4Prim.lineShader, gl4Prim.lineUniformLocs)
				local ln = gl4Prim.normLines
				ln.vbo:Upload(ln.data, nil, 0, 1, ln.count * gl4Prim.LINE_STEP)
				glFunc.LineWidth(1.0 * resScale)
				ln.vao:DrawArrays(GL.LINES, ln.count)
				glFunc.LineWidth(1.0)
				gl.UseShader(0)
			end

			gl.Scissor(false)
		end

		-- Clear leftover entries in pools
		for i = unitCount + 1, #unitsToShow do
			unitsToShow[i] = nil
		end
	end
end

-- Helper function to draw build preview for cursor
local function DrawBuildPreview(mx, my, iconRadiusZoomDistMult)
	if mx < render.dim.l or mx > render.dim.r or my < render.dim.b or my > render.dim.t then
		return
	end

	local _, activeCmdID = Spring.GetActiveCommand()

	-- Exit early if no active command
	if not activeCmdID then
		return
	end

	-- Handle Area Mex command preview
	if activeCmdID == CMD_AREA_MEX then
		local wx, wz = PipToWorldCoords(mx, my)
		local metalSpots = WG["resource_spot_finder"] and WG["resource_spot_finder"].metalSpotsList
		local metalMap = WG["resource_spot_finder"] and WG["resource_spot_finder"].isMetalMap

		if metalSpots and not metalMap then
			-- Draw circle showing area
			local radius = 200
			local segments = 32
			glFunc.Color(1, 1, 0, 0.3)
			glFunc.LineWidth(2)
			glFunc.BeginEnd(glConst.LINE_LOOP, function()
				for i = 0, segments do
					local angle = (i / segments) * 2 * math.pi
					local x = wx + radius * math.cos(angle)
					local z = wz + radius * math.sin(angle)
					local cx, cy = WorldToPipCoords(x, z)
					glFunc.Vertex(cx, cy)
				end
			end)
			glFunc.LineWidth(1)
			glFunc.Color(1, 1, 1, 1)

			-- Draw preview icons for all spots in area
			local mexBuildings = WG["resource_spot_builder"] and WG["resource_spot_builder"].GetMexBuildings()
			if mexBuildings then
				local selectedUnits = Spring.GetSelectedUnits()
				local mexConstructors = WG["resource_spot_builder"] and WG["resource_spot_builder"].GetMexConstructors()
				local selectedMex = WG["resource_spot_builder"] and WG["resource_spot_builder"].GetBestExtractorFromBuilders(selectedUnits, mexConstructors, mexBuildings)

				if selectedMex then
					local buildIcon = cache.unitIcon[selectedMex]
					if buildIcon then
						local iconSize = iconRadiusZoomDistMult * buildIcon.size * 0.8

						for i = 1, #metalSpots do
							local spot = metalSpots[i]
							local dist = math.sqrt((spot.x - wx)^2 + (spot.z - wz)^2)
							if dist < radius then
								local cx, cy = WorldToPipCoords(spot.x, spot.z)
								glFunc.Color(1, 1, 1, 0.3)
								glFunc.Texture(buildIcon.bitmap)
								glFunc.TexRect(cx - iconSize, cy - iconSize, cx + iconSize, cy + iconSize)
							end
						end
						glFunc.Texture(false)
					end
				end
			end
		end
	-- Handle regular build command preview
	elseif activeCmdID and activeCmdID < 0 and not interactionState.areBuildDragging then
		local buildDefID = -activeCmdID
		local wx, wz = PipToWorldCoords(mx, my)
		local wy = spFunc.GetGroundHeight(wx, wz)

		-- Check if this is a mex/geo that needs spot snapping
		local mexBuildings = WG["resource_spot_builder"] and WG["resource_spot_builder"].GetMexBuildings()
		local geoBuildings = WG["resource_spot_builder"] and WG["resource_spot_builder"].GetGeoBuildings()
		local isMex = mexBuildings and mexBuildings[buildDefID]
		local isGeo = geoBuildings and geoBuildings[buildDefID]
		local metalMap = WG["resource_spot_finder"] and WG["resource_spot_finder"].isMetalMap

		if isMex and not metalMap and WG["resource_spot_finder"] and WG["resource_spot_builder"] then
			local metalSpots = WG["resource_spot_finder"].metalSpotsList
			local nearestSpot = WG["resource_spot_builder"].FindNearestValidSpotForExtractor(wx, wz, metalSpots, buildDefID)
			if nearestSpot then
				wx, wz = nearestSpot.x, nearestSpot.z
				wy = nearestSpot.y
			end
		elseif isGeo and WG["resource_spot_finder"] and WG["resource_spot_builder"] then
			local geoSpots = WG["resource_spot_finder"].geoSpotsList
			local nearestSpot = WG["resource_spot_builder"].FindNearestValidSpotForExtractor(wx, wz, geoSpots, buildDefID)
			if nearestSpot then
				wx, wz = nearestSpot.x, nearestSpot.z
				wy = nearestSpot.y
			end
		else
			-- Regular building - snap to building grid
			local buildDef = UnitDefs[buildDefID]
			if buildDef then
				local gridSize = 16
				wx = math.floor(wx / gridSize + 0.5) * gridSize
				wz = math.floor(wz / gridSize + 0.5) * gridSize
			end
		end

		local buildIcon = cache.unitIcon[buildDefID]
		if buildIcon then
			local iconSize = iconRadiusZoomDistMult * buildIcon.size
			local cx, cy = WorldToPipCoords(wx, wz)
			local buildFacing = Spring.GetBuildFacing()
			local rotation = buildFacing * 90
			local canBuild = Spring.TestBuildOrder(buildDefID, wx, wy, wz, buildFacing)

				if canBuild == 2 then
					glFunc.Color(1, 1, 1, 0.5)
				elseif canBuild == 1 then
					local blockedByMobile = false
					local nearbyUnits = Spring.GetUnitsInCylinder(wx, wz, 64)
				if nearbyUnits then
					for _, unitID in ipairs(nearbyUnits) do
						local unitDefID = spFunc.GetUnitDefID(unitID)
						if unitDefID and cache.canMove[unitDefID] and not cache.isBuilding[unitDefID] then
							blockedByMobile = true
							break
						end
					end
				end				
				if blockedByMobile then
					glFunc.Color(1, 1, 1, 0.5)
				else
					glFunc.Color(1, 1, 0, 0.5)
				end
			else
				glFunc.Color(1, 0, 0, 0.5)
			end

			glFunc.Texture(buildIcon.bitmap)

			if rotation ~= 0 then
				glFunc.PushMatrix()
				glFunc.Translate(cx, cy, 0)
				glFunc.Rotate(rotation, 0, 0, 1)
				glFunc.TexRect(-iconSize, -iconSize, iconSize, iconSize)
				glFunc.PopMatrix()
			else
				glFunc.TexRect(cx - iconSize, cy - iconSize, cx + iconSize, cy + iconSize)
			end

			glFunc.Texture(false)
		end
	end
end

-- Helper function to draw build drag preview ghosts
local function DrawBuildDragPreview(iconRadiusZoomDistMult)
	if not interactionState.areBuildDragging or #interactionState.buildDragPositions == 0 then
		return
	end

	local _, cmdID = Spring.GetActiveCommand()
	if not cmdID or cmdID >= 0 then
		return
	end

	local buildDefID = -cmdID
	local buildIcon = cache.unitIcon[buildDefID]
	if not buildIcon then
		return
	end

	local buildFacing = Spring.GetBuildFacing()
	local buildWidth, buildHeight = GetBuildingDimensions(buildDefID, buildFacing)
	local centerX, centerY = WorldToPipCoords(0, 0)
	local edgeX, edgeY = WorldToPipCoords(buildWidth, 0)
	local iconSize = math.abs(edgeX - centerX)
	local rotation = buildFacing * 90

	glFunc.Texture(buildIcon.bitmap)

	for i = 1, #interactionState.buildDragPositions do
		local pos = interactionState.buildDragPositions[i]
		local cx, cy = WorldToPipCoords(pos.wx, pos.wz)
		local canBuild = Spring.TestBuildOrder(buildDefID, pos.wx, spFunc.GetGroundHeight(pos.wx, pos.wz), pos.wz, buildFacing)
		local alpha = math.max(0.3, 0.6 - (i - 1) * 0.05)

		if canBuild == 2 then
			glFunc.Color(1, 1, 1, alpha)
		elseif canBuild == 1 then
			local blockedByMobile = false
			local nearbyUnits = Spring.GetUnitsInCylinder(pos.wx, pos.wz, 64)
			if nearbyUnits then
				for _, unitID in ipairs(nearbyUnits) do
					local unitDefID = spFunc.GetUnitDefID(unitID)
					if unitDefID and cache.canMove[unitDefID] and not cache.isBuilding[unitDefID] then
						blockedByMobile = true
						break
					end
				end
			end

			if blockedByMobile then
				glFunc.Color(1, 1, 1, alpha)
			else
				glFunc.Color(1, 1, 0, alpha)
			end
		else
			glFunc.Color(1, 0, 0, alpha)
		end

		if rotation ~= 0 then
			glFunc.PushMatrix()
			glFunc.Translate(cx, cy, 0)
			glFunc.Rotate(rotation, 0, 0, 1)
			glFunc.TexRect(-iconSize, -iconSize, iconSize, iconSize)
			glFunc.PopMatrix()
		else
			glFunc.TexRect(cx - iconSize, cy - iconSize, cx + iconSize, cy + iconSize)
		end
	end

	glFunc.Texture(false)
end

-- Helper function to draw queued building ghosts
local function DrawQueuedBuilds(iconRadiusZoomDistMult, cachedSelectedUnits)
	-- When tracking another player, use their selected units instead of the local player's
	local selectedUnits
	local selectedCount = 0
	if interactionState.trackingPlayerID then
		local playerSelections = WG['allyselectedunits'] and WG['allyselectedunits'].getPlayerSelectedUnits(interactionState.trackingPlayerID)
		if playerSelections then
			-- Convert set to array (reuse cachedSelectedUnits table to avoid alloc)
			selectedUnits = cachedSelectedUnits or {}
			for unitID, _ in pairs(playerSelections) do
				selectedCount = selectedCount + 1
				selectedUnits[selectedCount] = unitID
			end
		end
	else
		selectedUnits = cachedSelectedUnits
		selectedCount = selectedUnits and #selectedUnits or 0
	end
	if selectedCount == 0 then
		return
	end

	-- Clear and reuse texture grouping tables
	for k in pairs(pools.buildsByTexture) do
		pools.buildsByTexture[k] = nil
	end
	for k in pairs(pools.buildCountByTexture) do
		pools.buildCountByTexture[k] = nil
	end

	for i = 1, selectedCount do
		local unitID = selectedUnits[i]
		local queue = spFunc.GetUnitCommands(unitID, -1)

		if queue then
			local queueLength = #queue
			for j = 1, queueLength do
				local cmd = queue[j]
				if cmd.id < 0 then
					local buildDefID = -cmd.id
					local buildIcon = cache.unitIcon[buildDefID]
					if buildIcon and cmd.params then
						local paramCount = #cmd.params
						if paramCount >= 3 then
							local bwx, bwz = cmd.params[1], cmd.params[3]

							if bwx >= render.world.l and bwx <= render.world.r and bwz >= render.world.t and bwz <= render.world.b then
								local cx, cy = WorldToPipCoords(bwx, bwz)
								local iconSize = iconRadiusZoomDistMult * buildIcon.size
								local buildFacing = paramCount >= 4 and cmd.params[4] or 0
								local rotation = buildFacing * 90

								local bitmap = buildIcon.bitmap
								local texBuilds = pools.buildsByTexture[bitmap]
								local buildCount = pools.buildCountByTexture[bitmap] or 0
								if not texBuilds then
									texBuilds = {}
									pools.buildsByTexture[bitmap] = texBuilds
								end
								buildCount = buildCount + 1
								pools.buildCountByTexture[bitmap] = buildCount
								texBuilds[buildCount] = {
									cx = cx,
									cy = cy,
									iconSize = iconSize,
									rotation = rotation
								}
							end
						end
					end
				end
			end
		end
	end

	glFunc.Color(0.5, 1, 0.5, 0.4)
	for bitmap, builds in pairs(pools.buildsByTexture) do
		glFunc.Texture(bitmap)
		local buildCount = pools.buildCountByTexture[bitmap]
		for i = 1, buildCount do
			local build = builds[i]
			local cx, cy, iconSize, rotation = build.cx, build.cy, build.iconSize, build.rotation

			if rotation ~= 0 then
				glFunc.PushMatrix()
				glFunc.Translate(cx, cy, 0)
				glFunc.Rotate(rotation, 0, 0, 1)
				glFunc.TexRect(-iconSize, -iconSize, iconSize, iconSize)
				glFunc.PopMatrix()
			else
				glFunc.TexRect(cx - iconSize, cy - iconSize, cx + iconSize, cy + iconSize)
			end
		end
	end
	glFunc.Texture(false)
end

----------------------------------------------------------------------------------------------------
-- GL4 Instanced Icon Drawing
----------------------------------------------------------------------------------------------------
-- Replaces the DrawUnit loop + DrawIcons function with a single GPU instanced draw call.
-- Instead of per-unit Lua→C API calls and per-icon texture switches, all icons are packed
-- into a VBO and drawn with a single DrawArrays call through a texture atlas.
local function GL4DrawIcons(checkAllyTeamID, selectedSet, trackingSet)
	-- Engine-matching icon size (MiniMap.cpp lines 518-526):
	-- Engine dpr = unitBaseSize * (ppe^2 * mapX * mapZ / 40000)^0.25 where ppe = pixels/elmo = zoom.
	-- Simplifies to: unitBaseSize * (mapX*mapZ/40000)^0.25 * sqrt(zoom).
	-- Independent of PIP pixel dimensions (aspect ratio doesn't affect icon size).
	local resScale = render.contentScale or 1
	local unitBaseSize = Spring.GetConfigFloat("MinimapIconScale", 3.5)
	local iconRadiusZoomDistMult = unitBaseSize * (mapInfo.mapSizeX * mapInfo.mapSizeZ / 40000) ^ 0.25 * math.sqrt(cameraState.zoom) * resScale

	-- Check if unitpics should be shown at this zoom level
	local useUnitpics = config.showUnitpics and cameraState.zoom >= config.unitpicZoomThreshold
	local unitpicEntries = {}
	local unitpicCount = 0

	-- Write directly into pre-allocated flat array (zero per-frame allocations)
	local data = gl4Icons.instanceData
	local unitCount = #miscState.pipUnits
	local unitDefCacheTbl = gl4Icons.unitDefCache
	local unitTeamCacheTbl = gl4Icons.unitTeamCache
	local unitDefLayerTbl = gl4Icons.unitDefLayer
	local atlasUVs = gl4Icons.atlasUVs
	local defaultUV = gl4Icons.defaultUV
	local cacheUnitIcon = cache.unitIcon
	local cacheIsBuilding = cache.isBuilding
	local localCantBeTransported = cache.cantBeTransported
	local crashingUnits = miscState.crashingUnits
	local localTeamAllyTeamCache = teamAllyTeamCache
	local localTeamColors = teamColors
	local localBuildPosX = ownBuildingPosX
	local localBuildPosZ = ownBuildingPosZ
	local usedElements = 0
	local maxInst = gl4Icons.MAX_INSTANCES
	local instStep = gl4Icons.INSTANCE_STEP
	local pipUnits = miscState.pipUnits

	-- Position cache tables (populated during sort key pass, consumed by processUnit)
	local localCachePosX = gl4Icons.cachedPosX
	local localCachePosZ = gl4Icons.cachedPosZ

	-- Pre-build combined UV+size lookup (one array instead of two hash lookups per unit)
	local uvSizeLookup = gl4Icons._uvSizeLookup
	if not uvSizeLookup then
		uvSizeLookup = {}
		for uDefID, uvs in pairs(atlasUVs) do
			local icon = cacheUnitIcon[uDefID]
			local sz = icon and icon.size or 0.5
			uvSizeLookup[uDefID] = {uvs[1], uvs[2], uvs[3], uvs[4], sz}
		end
		gl4Icons._uvSizeLookup = uvSizeLookup
	end
	local defaultUVSize = gl4Icons._defaultUVSize
	if not defaultUVSize then
		defaultUVSize = {defaultUV[1], defaultUV[2], defaultUV[3], defaultUV[4], 0.5}
		gl4Icons._defaultUVSize = defaultUVSize
	end

	-- Pre-flatten team colors into separate R/G/B arrays (avoids nested table access per unit)
	local teamColorR = gl4Icons._teamColorR
	local teamColorG = gl4Icons._teamColorG
	local teamColorB = gl4Icons._teamColorB
	if not teamColorR then
		teamColorR = {}; teamColorG = {}; teamColorB = {}
		gl4Icons._teamColorR = teamColorR
		gl4Icons._teamColorG = teamColorG
		gl4Icons._teamColorB = teamColorB
	end
	for tID, c in pairs(localTeamColors) do
		teamColorR[tID] = c[1]; teamColorG[tID] = c[2]; teamColorB[tID] = c[3]
	end

	-- At high unit counts, skip cosmetic-only features (stun tint, damage flash)
	-- to reduce per-unit API calls. These are barely visible at the zoom levels
	-- where thousands of units are on screen.
	local skipCosmetics = unitCount > 2000
	local mathFloor = math.floor

	-- LOS bitmask constants (raw mode avoids table allocation per GetUnitLosState call)
	local LOS_INLOS = 1
	local LOS_INRADAR = 2
	local LOS_PREVLOS = 4
	local LOS_CONTRADAR = 8

	-- Compute takeable teams (leaderless, alive, non-AI)  cached, invalidated on PlayerChanged
	-- After GameOver, takeable is always empty (no point blinking — game is done)
	if not cachedTakeableTeams and not miscState.isGameOver then
		cachedTakeableTeams = {}
		for _, tID in ipairs(Spring.GetTeamList()) do
			local _, leader, isDead, hasAI = Spring.GetTeamInfo(tID, false)
			if leader == -1 and not isDead and not hasAI then
				cachedTakeableTeams[tID] = true
			end
		end
	end
	local takeableTeams = cachedTakeableTeams

	-- Build tracked set for O(1) lookup in processUnit (must be before processUnit definition)
	local trackedSet = trackingSet

	-- Process one unit: resolve LOS, look up icon, write to VBO array.
	-- Returns updated usedElements. Defined once to avoid closure per-layer.
	-- (inlined via local function for LuaJIT trace compilation)
	local function processUnit(uID, usedEl)
		if usedEl >= maxInst then return usedEl end

		-- unitDefID and unitTeam are guaranteed cached by the keysort pass
		local uDefID = unitDefCacheTbl[uID]
		local uTeam = unitTeamCacheTbl[uID]

		-- Get world position from sort-pass cache (avoids redundant GetUnitBasePosition call)
		local ux = localCachePosX[uID]
		local uz = localCachePosZ[uID]
		if not ux then
			-- Fallback: unit wasn't in sort pass (shouldn't happen, but be safe)
			local x, _, z = spFunc.GetUnitBasePosition(uID)
			if not x then return usedEl end
			ux, uz = x, z
		end

		-- LOS filtering for enemy units
		local isRadar = false
		local visibleDefID = uDefID
		if checkAllyTeamID and uTeam then
			local unitAllyTeam = localTeamAllyTeamCache[uTeam]
			if not unitAllyTeam then
				unitAllyTeam = spFunc.GetTeamAllyTeamID(uTeam)
				localTeamAllyTeamCache[uTeam] = unitAllyTeam
			end
			if unitAllyTeam ~= checkAllyTeamID then
				local losBits = spFunc.GetUnitLosState(uID, checkAllyTeamID, true)
				if not losBits or losBits == 0 then
					return usedEl
				elseif losBits % (LOS_INLOS * 2) >= LOS_INLOS then
					-- full LOS: draw normally, and record building ghost for when it leaves LOS
					if cacheIsBuilding[uDefID] then
						local g = ghostBuildings[uID]
						if g then
							g.defID = uDefID; g.x = ux; g.z = uz; g.teamID = uTeam
						else
							ghostBuildings[uID] = { defID = uDefID, x = ux, z = uz, teamID = uTeam }
						end
					end
				elseif losBits % (LOS_INRADAR * 2) >= LOS_INRADAR then
					-- Buildings in radar: don't wobble (they're stationary, position is known)
					if not cacheIsBuilding[uDefID] then
						isRadar = true
					end
					local typed = (losBits % (LOS_PREVLOS * 2) >= LOS_PREVLOS) or (losBits % (LOS_CONTRADAR * 2) >= LOS_CONTRADAR)
					if not (typed and uDefID) then
						visibleDefID = nil
					end
				else
					-- Not in LOS or radar, but has some bits (e.g. PREVLOS).
					-- Record ghost for previously-seen buildings so they appear as ghosts.
					if cacheIsBuilding[uDefID] and losBits % (LOS_PREVLOS * 2) >= LOS_PREVLOS then
						local g = ghostBuildings[uID]
						if g then
							g.defID = uDefID; g.x = ux; g.z = uz; g.teamID = uTeam
						else
							ghostBuildings[uID] = { defID = uDefID, x = ux, z = uz, teamID = uTeam }
						end
					end
					return usedEl
				end
			end
		end

		if not visibleDefID and not isRadar then return usedEl end

		-- Look up atlas UV and size scale (combined single-table lookup)
		local uvs = uvSizeLookup[visibleDefID] or defaultUVSize

		-- Team color (white if selected, flattened lookup)
		local r, g, b
		if selectedSet and selectedSet[uID] then
			r, g, b = 1, 1, 1
		else
			r = teamColorR[uTeam] or 1
			g = teamColorG[uTeam] or 1
			b = teamColorB[uTeam] or 1
		end

		-- Damage flash: briefly flash toward white when unit takes damage
		-- Cost: one table lookup per unit (no API calls — fed by widget:UnitDamaged)
		local flashFactor = 0
		local flash = damageFlash[uID]
		if flash then
			local elapsed = gameTime - flash.time
			if elapsed < DAMAGE_FLASH_DURATION then
				local f = flash.intensity * (1 - elapsed / DAMAGE_FLASH_DURATION)
				flashFactor = f
				r = r + (1 - r) * f
				g = g + (1 - g) * f
				b = b + (1 - b) * f
			else
				damageFlash[uID] = nil  -- expired, clean up
			end
		end

		-- Stun detection (EMP/paralyze, not build-in-progress)
		-- Skipped at high unit counts (cosmetic gray tint, saves API call per unit)
		local isStunned = false
		local healthPct = 100  -- default full health
		if not skipCosmetics and not isRadar then
			local stun, _, buildStun = spFunc.GetUnitIsStunned(uID)
			if stun and not buildStun then isStunned = true end
		end

		-- Self-destruct: use event-driven cache (no per-unit API call)
		local isSelfD = not isRadar and selfDUnits[uID] or false

		-- Collect unitpic data when zoomed in (only for fully visible, non-radar units)
		-- Also fetch health for damage indication (icon tint + unitpic health bar)
		if useUnitpics and not isRadar and visibleDefID then
			local hp, maxHP, _, _, bp = spFunc.GetUnitHealth(uID)
			if hp and maxHP and maxHP > 0 then
				healthPct = math.max(0, math.min(100, mathFloor(hp / maxHP * 100)))
			end
			unitpicCount = unitpicCount + 1
			local up = unitpicEntries[unitpicCount]
			if not up then
				up = {}
				unitpicEntries[unitpicCount] = up
			end
			up[1] = wtp.offsetX + ux * wtp.scaleX   -- pipX
			up[2] = wtp.offsetZ + uz * wtp.scaleZ   -- pipY
			up[3] = visibleDefID
			up[4] = uTeam
			up[5] = (selectedSet and selectedSet[uID]) and true or false
			up[6] = bp or 1  -- buildProgress
			up[7] = uID
			up[8] = healthPct / 100  -- health fraction for health bar
			return usedEl  -- Skip GL4 icon — unitpic will be drawn on top instead
		elseif not skipCosmetics and not isRadar then
			-- Non-unitpic zoom: still fetch health for icon damage tint
			local hp, maxHP = spFunc.GetUnitHealth(uID)
			if hp and maxHP and maxHP > 0 then
				healthPct = math.max(0, math.min(100, mathFloor(hp / maxHP * 100)))
			end
		end

		-- Write 12 floats directly into pre-allocated array
		local off = usedEl * instStep
		-- Takeable blink only for teams on the viewer's own allyteam (can't take enemy units)
		local isTakeable = takeableTeams[uTeam] and checkAllyTeamID and localTeamAllyTeamCache[uTeam] == checkAllyTeamID
		data[off+1] = ux; data[off+2] = uz; data[off+3] = uvs[5]; data[off+4] = healthPct * 32 + (isRadar and 1 or 0) + (isTakeable and 2 or 0) + (isStunned and 4 or 0) + (trackedSet and trackedSet[uID] and 8 or 0) + (isSelfD and 16 or 0)
		data[off+5] = uvs[1]; data[off+6] = uvs[2]; data[off+7] = uvs[3]; data[off+8] = uvs[4]
		data[off+9] = r; data[off+10] = g; data[off+11] = b; data[off+12] = (uID * 0.37) % 6.2832 + mathFloor(flashFactor * 100) * 7.0
		return usedEl + 1
	end

	local icT0 = os.clock()

	-- Ghost building pass: enemy buildings previously seen but no longer in LOS
	-- Rendered first (lowest VBO indices) so live icons overdraw them correctly.
	--
	-- Two visibility strategies depending on mode:
	-- 1) LOS view (fullview still ON): use GetUnitLosState to query the viewed allyteam's
	--    actual LOS. Reliable because fullview is ON and engine returns accurate per-allyteam data.
	-- 2) Fullview OFF: use pipUnits membership (from GetUnitsInRectangle). Engine LOS APIs
	--    are unreliable for spectators who toggled fullview OFF, but GetUnitsInRectangle
	--    correctly filters to visible units only.
	if checkAllyTeamID then
		-- Determine which visibility check to use
		local isLosViewMode = state.losViewEnabled and state.losViewAllyTeam

		-- For non-LOS-view mode: build O(1) lookup of units returned by GetUnitsInRectangle
		local liveSet
		if not isLosViewMode then
			liveSet = {}
			local localPipUnits = miscState.pipUnits
			for i = 1, #localPipUnits do
				liveSet[localPipUnits[i]] = true
			end
		end

		local viewL = render.world.l - 220
		local viewR = render.world.r + 220
		local viewT = render.world.t - 220
		local viewB = render.world.b + 220

		for gID, ghost in pairs(ghostBuildings) do
			if usedElements >= maxInst then break end
			-- Determine if this ghost is currently visible to the viewer
			local isVisible
			if isLosViewMode then
				-- LOS view: check if the building is in LOS or radar for the viewed allyteam
				local lb = spFunc.GetUnitLosState(gID, checkAllyTeamID, true)
				isVisible = lb and (lb % 2 >= 1 or lb % 4 >= 2)  -- INLOS or INRADAR
			else
				-- Fullview OFF: check if the building is in pipUnits (engine-enforced visibility)
				isVisible = liveSet[gID]
			end
			if not isVisible then
				-- Building is in fog-of-war for the viewer. Draw a dimmed ghost icon.
				if ghost.x >= viewL and ghost.x <= viewR and ghost.z >= viewT and ghost.z <= viewB then
					local uvs, sizeScale
					if cacheUnitIcon[ghost.defID] then
						uvs = atlasUVs[ghost.defID] or defaultUV
						sizeScale = cacheUnitIcon[ghost.defID].size
					else
						uvs = defaultUV
						sizeScale = 0.5
					end
					local color = localTeamColors[ghost.teamID]
					-- Dim ghost icons to simulate being under FoW overlay (engine draws them below LOS layer)
					local dim = 0.6
					local r, g, b = (color and color[1] or 1) * dim, (color and color[2] or 1) * dim, (color and color[3] or 1) * dim
					local off = usedElements * gl4Icons.INSTANCE_STEP
					-- Ghost buildings are always from a different allyteam (enemy) — never takeable
					-- Health=100 (full) so shader doesn't apply damage darkening on top of ghost dim
					data[off+1] = ghost.x; data[off+2] = ghost.z; data[off+3] = sizeScale; data[off+4] = 100 * 32
					data[off+5] = uvs[1]; data[off+6] = uvs[2]; data[off+7] = uvs[3]; data[off+8] = uvs[4]
					data[off+9] = r; data[off+10] = g; data[off+11] = b; data[off+12] = (gID * 0.37) % 6.2832
					usedElements = usedElements + 1
				end
			end
			-- If liveSet[gID] is true, processUnit will draw the live icon (which overdraws
			-- the ghost at its VBO index). Ghost data stays in the table for when the building
			-- leaves LOS/radar again. Dead-building cleanup is handled by UnitDestroyed callback
			-- (fires for units visible to the viewed allyteam) and by the periodic fullview scan
			-- (dead units are absent from GetAllUnits, so stale ghosts are cleared on next rescan).
		end
	end

	local icT1 = os.clock()

	-- Sort units by (layer, Z depth) with unitID tiebreaker for deterministic draw order.
	-- Layer is primary (structures→ground→air→commanders). Z depth gives correct
	-- front-to-back ordering (larger Z = further south = drawn on top).
	-- UnitID tiebreaker in comparator prevents z-fighting from equal-Z units.
	-- Position is cached here so processUnit can reuse it without a second API call.
	--
	-- Buildings are separated from mobile units so we can cache their sort order.
	-- Immobile buildings never change position, so their relative sort order is stable.
	-- We only re-sort buildings when the visible set changes (detected via count + hash).
	-- Mobile units are sorted every frame since their positions change.
	local buildingIDs = gl4Icons._buildingBuf
	local mobileIDs = gl4Icons._mobileBuf
	local bCount, mCount = 0, 0
	local bldgHash = 0
	local defaultLayer = gl4Icons.LAYER_GROUND
	local localGaiaTeamID = gaiaTeamID
	-- Predict whether building block cache will be valid this frame.
	-- If valid, we skip writing localCachePosX/Z for buildings (saves ~3600 table writes).
	-- Prediction uses previous frame's bCount/hash — if buildings didn't change last frame,
	-- they almost certainly won't this frame either. Worst case: one extra rebuild.
	local bldgBlockWillRebuild = useUnitpics
		or not gl4Icons._bldgBlock
		or (Spring.GetGameFrame() - (gl4Icons._bldgBlockFrame or 0)) >= 30
	for i = 1, unitCount do
		local uID = pipUnits[i]
		-- Skip crashing units early
		if crashingUnits[uID] then
			-- skip
		else
		-- Fast path for known immobile buildings: skip all classification lookups
		local cachedBldgX = localBuildPosX[uID]
		if cachedBldgX then
			-- On block-cache frames, skip position cache writes (processUnit won't run for buildings)
			if not bldgBlockWillRebuild then
				-- no-op: position not needed this frame
			else
				localCachePosX[uID] = cachedBldgX
				localCachePosZ[uID] = localBuildPosZ[uID]
			end
			-- Sort key is stable (position never changes), already in gl4IconSortKeys
			bCount = bCount + 1
			buildingIDs[bCount] = uID
			bldgHash = bldgHash + uID
		else
		local uDefID = unitDefCacheTbl[uID]
		if not uDefID then
			uDefID = spFunc.GetUnitDefID(uID)
			unitDefCacheTbl[uID] = uDefID
		end
		-- Pre-cache team so processUnit never calls GetUnitTeam
		local uTeam = unitTeamCacheTbl[uID]
		if not uTeam then
			uTeam = spFunc.GetUnitTeam(uID)
			unitTeamCacheTbl[uID] = uTeam
		end
		if uTeam ~= localGaiaTeamID then
		local layer = unitDefLayerTbl[uDefID] or defaultLayer
		local x, _, z = spFunc.GetUnitBasePosition(uID)
		local xPos = x or 0
		local zPos = z or 0
		localCachePosX[uID] = xPos
		localCachePosZ[uID] = zPos
		local sortKey = layer * 100000 + mathFloor(zPos)
		gl4IconSortKeys[uID] = sortKey
		-- Separate immobile buildings from mobile units for split sorting
		local isImmobile = cacheIsBuilding[uDefID] and localCantBeTransported[uDefID]
		if isImmobile then
			-- Cache building positions (they never move)
			localBuildPosX[uID] = xPos
			localBuildPosZ[uID] = zPos
			bCount = bCount + 1
			buildingIDs[bCount] = uID
			bldgHash = bldgHash + uID  -- order-independent hash for set change detection
		else
			mCount = mCount + 1
			mobileIDs[mCount] = uID
		end
		end -- uTeam ~= gaia
		end -- not cachedBldgX
		end -- not crashing
	end
	-- Clear stale entries from previous frame
	local prevBLen = gl4Icons._prevBuildingLen
	for i = bCount + 1, prevBLen do buildingIDs[i] = nil end
	gl4Icons._prevBuildingLen = bCount
	local prevMLen = gl4Icons._prevMobileLen
	for i = mCount + 1, prevMLen do mobileIDs[i] = nil end
	gl4Icons._prevMobileLen = mCount

	local icT2 = os.clock()

	-- Mobile units: sort every frame (positions change).
	-- Skip sort at high counts — z-ordering is cosmetic and invisible at this density.
	if mCount <= 2000 then
		table.sort(mobileIDs, gl4IconSortCmp)
	end

	-- Buildings: sort only when the visible set changes (positions are immutable).
	-- Detected via count + additive hash of unit IDs — virtually collision-free.
	local bldgSortedCache = gl4Icons._bldgSortedCache
	if bCount ~= gl4Icons._lastBldgCount or bldgHash ~= gl4Icons._lastBldgHash then
		table.sort(buildingIDs, gl4IconSortCmp)
		for i = 1, bCount do bldgSortedCache[i] = buildingIDs[i] end
		bldgSortedCache[bCount + 1] = nil
		gl4Icons._lastBldgCount = bCount
		gl4Icons._lastBldgHash = bldgHash
	end

	local icT3 = os.clock()

	-- Building block VBO cache: instead of processing each building individually,
	-- cache the entire building VBO output as a contiguous flat array.
	-- On subsequent frames (while building set unchanged), copy the block in one
	-- tight numeric loop (~0.05ms vs ~1.3ms per-building processing).
	-- Dynamic state (selection, damage flash, tracking) is applied as overlays.
	-- Block is rebuilt every 30 game frames to catch LOS/stun changes.
	local currentGameFrame = Spring.GetGameFrame()
	local bldgBlock = gl4Icons._bldgBlock
	local bldgBlockValid = bldgBlock
		and bCount == gl4Icons._bldgBlockBCount
		and bldgHash == gl4Icons._bldgBlockHash
		and checkAllyTeamID == gl4Icons._bldgBlockCheckAlly  -- LOS filtering context changed
		and (currentGameFrame - (gl4Icons._bldgBlockFrame or 0)) < 30
		and not useUnitpics  -- unitpic collection needs per-unit data

	local preProcessEl = usedElements

	if bldgBlockValid then
		-- Fast path: copy entire cached building block
		local blockFloats = gl4Icons._bldgBlockN  -- total float count
		local blockOffset = usedElements * instStep
		-- Unrolled copy: 12 floats per building instance
		local j = 1
		while j + 11 <= blockFloats do
			data[blockOffset+j]=bldgBlock[j]; data[blockOffset+j+1]=bldgBlock[j+1]
			data[blockOffset+j+2]=bldgBlock[j+2]; data[blockOffset+j+3]=bldgBlock[j+3]
			data[blockOffset+j+4]=bldgBlock[j+4]; data[blockOffset+j+5]=bldgBlock[j+5]
			data[blockOffset+j+6]=bldgBlock[j+6]; data[blockOffset+j+7]=bldgBlock[j+7]
			data[blockOffset+j+8]=bldgBlock[j+8]; data[blockOffset+j+9]=bldgBlock[j+9]
			data[blockOffset+j+10]=bldgBlock[j+10]; data[blockOffset+j+11]=bldgBlock[j+11]
			j = j + 12
		end
		while j <= blockFloats do
			data[blockOffset + j] = bldgBlock[j]
			j = j + 1
		end
		usedElements = usedElements + gl4Icons._bldgBlockCount

		-- Dynamic overlays on top of cached data
		local bldgIdx = gl4Icons._bldgBlockIdx

		-- Selection overlay: selected buildings rendered white
		if selectedSet then
			for uID, _ in pairs(selectedSet) do
				local idx = bldgIdx[uID]
				if idx then
					local off = (preProcessEl + idx - 1) * instStep
					data[off + 9] = 1; data[off + 10] = 1; data[off + 11] = 1
					data[off + 12] = (uID * 0.37) % 6.2832  -- reset flash encoding
				end
			end
		end

		-- Damage flash overlay
		for uID, flash in pairs(damageFlash) do
			local idx = bldgIdx[uID]
			if idx then
				local elapsed = gameTime - flash.time
				if elapsed < DAMAGE_FLASH_DURATION then
					local f = flash.intensity * (1 - elapsed / DAMAGE_FLASH_DURATION)
					local off = (preProcessEl + idx - 1) * instStep
					data[off + 9] = data[off + 9] + (1 - data[off + 9]) * f
					data[off + 10] = data[off + 10] + (1 - data[off + 10]) * f
					data[off + 11] = data[off + 11] + (1 - data[off + 11]) * f
					data[off + 12] = (uID * 0.37) % 6.2832 + mathFloor(f * 100) * 7.0
				else
					damageFlash[uID] = nil
				end
			end
		end

		-- Tracking overlay: re-apply tracking flag for tracked buildings
		-- Block stores flags with bits 3-4 stripped; re-apply from current trackedSet
		if trackedSet then
			for uID, _ in pairs(trackedSet) do
				local idx = bldgIdx[uID]
				if idx then
					local off = (preProcessEl + idx - 1) * instStep
					data[off + 4] = data[off + 4] + 8  -- set tracking bit (bit 3)
				end
			end
		end

		-- SelfD overlay: re-apply selfD flag for self-destructing buildings
		for uID in pairs(selfDUnits) do
			local idx = bldgIdx[uID]
			if idx then
				local off = (preProcessEl + idx - 1) * instStep
				data[off + 4] = data[off + 4] + 16 -- set selfD bit (bit 4)
			end
		end
	else
		-- Slow path: process each building individually, build block cache
		local bldgIdx = gl4Icons._bldgBlockIdx
		if not bldgIdx then
			bldgIdx = {}
			gl4Icons._bldgBlockIdx = bldgIdx
		end
		for k in pairs(bldgIdx) do bldgIdx[k] = nil end

		local writeCount = 0
		for i = 1, bCount do
			local uID = bldgSortedCache[i]
			if usedElements >= maxInst then break end
			local prevEl = usedElements
			usedElements = processUnit(uID, usedElements)
			if usedElements > prevEl then
				writeCount = writeCount + 1
				bldgIdx[uID] = writeCount  -- 1-based index within block
			end
		end

		-- Cache the building block for future frames
		if not bldgBlock then
			bldgBlock = {}
			gl4Icons._bldgBlock = bldgBlock
		end
		local blockStart = preProcessEl * instStep
		local blockFloats = (usedElements - preProcessEl) * instStep
		for j = 1, blockFloats do
			bldgBlock[j] = data[blockStart + j]
		end
		-- Strip tracked + selfD bits from cached flags, preserving health and bits 0-2
		-- Flags format: healthPct*32 + bitFlags. Clear bits 3-4 (tracked=8, selfD=16)
		for i = 0, writeCount - 1 do
			local j = i * instStep + 4  -- flags position within block (1-based: inst 0 → idx 4)
			local f = bldgBlock[j]
			bldgBlock[j] = f - f % 32 + f % 8  -- keep health*32 + bits 0-2, clear bits 3-4
		end
		-- Clear stale entries beyond current block
		local prevBlockN = gl4Icons._bldgBlockN or 0
		for j = blockFloats + 1, prevBlockN do bldgBlock[j] = nil end

		gl4Icons._bldgBlockN = blockFloats
		gl4Icons._bldgBlockCount = usedElements - preProcessEl
		gl4Icons._bldgBlockBCount = bCount
		gl4Icons._bldgBlockHash = bldgHash
		gl4Icons._bldgBlockCheckAlly = checkAllyTeamID
		gl4Icons._bldgBlockFrame = currentGameFrame
	end
	local icT3b = os.clock()
	local bldgProcessed = usedElements - preProcessEl
	local preMobileEl = usedElements
	for i = 1, mCount do
		usedElements = processUnit(mobileIDs[i], usedElements)
		if usedElements >= maxInst then break end
	end

	local icT4 = os.clock()
	local mobileProcessed = usedElements - preMobileEl

	-- Skip draw if no icons and no unitpics
	if usedElements == 0 and unitpicCount == 0 then
		perfTimers.icGhost = perfTimers.icGhost + PERF_SMOOTH * ((icT1 - icT0) - perfTimers.icGhost)
		perfTimers.icKeysort = perfTimers.icKeysort + PERF_SMOOTH * ((icT2 - icT1) - perfTimers.icKeysort)
		perfTimers.icSort = perfTimers.icSort + PERF_SMOOTH * ((icT3 - icT2) - perfTimers.icSort)
		perfTimers.icProcess = perfTimers.icProcess + PERF_SMOOTH * ((icT4 - icT3) - perfTimers.icProcess)
		perfTimers.icProcBldg = perfTimers.icProcBldg + PERF_SMOOTH * ((icT3b - icT3) - perfTimers.icProcBldg)
		perfTimers.icProcMobile = perfTimers.icProcMobile + PERF_SMOOTH * ((icT4 - icT3b) - perfTimers.icProcMobile)
		perfTimers.icProcBldgN = bldgProcessed
		perfTimers.icProcMobileN = mobileProcessed
		return iconRadiusZoomDistMult
	end

	-- Draw GL4 icons (skip VBO upload/draw when all units are rendered as unitpics)
	if usedElements > 0 then
		-- Single bulk upload to GPU (only the used portion)
		gl4Icons.vbo:Upload(data, nil, 0, 1, usedElements * gl4Icons.INSTANCE_STEP)

		-- Set up GL state for icon drawing
		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)

		-- Activate shader and set uniforms
		gl.UseShader(gl4Icons.shader)
		local ul = gl4Icons.uniformLocs
		gl.UniformFloat(ul.wtp_scale, wtp.scaleX, wtp.scaleZ)
		gl.UniformFloat(ul.wtp_offset, wtp.offsetX, wtp.offsetZ)

		-- FBO dimensions for NDC conversion
		local fboW = render.dim.r - render.dim.l
		local fboH = render.dim.t - render.dim.b
		gl.UniformFloat(ul.ndcScale, 2.0 / fboW, 2.0 / fboH)

		-- Map rotation
		local rot = render.minimapRotation or 0
		gl.UniformFloat(ul.rotSC, math.sin(rot), math.cos(rot))
		gl.UniformFloat(ul.rotCenter, fboW * 0.5, fboH * 0.5)

		-- Icon size and time
		gl.UniformFloat(ul.iconBaseSize, iconRadiusZoomDistMult)
		gl.UniformFloat(ul.gameTime, gameTime)
		gl.UniformFloat(ul.wallClockTime, wallClockTime)
		gl.UniformFloat(ul.healthDarkenMax, config.healthDarkenMax)

		-- Bind atlas texture
		glFunc.Texture(0, gl4Icons.atlas)

		-- Pass 1: Outlines for tracked units (white) and self-destructing units (red-orange pulse)
		-- Only runs when there are tracked or selfD units; the shader culls others via alpha=0
		local hasSelfD = next(selfDUnits) ~= nil
		if trackedSet or hasSelfD then
			gl.UniformFloat(ul.outlinePass, 1.0)
			gl4Icons.vao:DrawArrays(GL.POINTS, usedElements)
		end

		-- Pass 2: Normal icon draw
		gl.UniformFloat(ul.outlinePass, 0.0)
		gl4Icons.vao:DrawArrays(GL.POINTS, usedElements)

		glFunc.Texture(0, false)

		gl.UseShader(0)
	end

	local icT5 = os.clock()

	-- Draw unitpics overlay when zoomed in close (rendered on top of GL4 icons)
	if useUnitpics and unitpicCount > 0 then
		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
		local unitpicSizeMult = 0.85
		local picTexInset = 0.18 * (1 - (cameraState.zoom - config.unitpicZoomThreshold) / (1 - config.unitpicZoomThreshold))
		local distMult = math.min(math.max(1, 2.2-(cameraState.zoom*3.3)), 3)
		local teamBorderSize = 3 * cameraState.zoom * distMult * resScale
		local blackBorderSize = 4 * cameraState.zoom * distMult * resScale
		local cornerCutRatio = 0.2
		local isRotated = render.minimapRotation ~= 0
		local hoveredID = drawData.hoveredUnitID
		local cacheUnitPic = cache.unitPic

		-- Draw each unitpic (already in correct layer order from 4-pass processing)
		for j = 1, unitpicCount do
			local up = unitpicEntries[j]
			local px, py = up[1], up[2]
			local uDefID, uTeam = up[3], up[4]
			local isSelected, buildProgress, uID = up[5], up[6], up[7]

			local iconData = cacheUnitIcon[uDefID]
			local iconSize = iconRadiusZoomDistMult * (iconData and iconData.size or 0.5) * unitpicSizeMult
			local bdrSize = iconSize + teamBorderSize + blackBorderSize
			local teamBdrSize = iconSize + teamBorderSize
			local crnrCut = bdrSize * cornerCutRatio
			local crnrCutOuter = bdrSize * cornerCutRatio * 1.2
			local opacity = buildProgress >= 1 and 1.0 or (0.2 + (buildProgress * 0.5))
			local isHovered = hoveredID and uID == hoveredID
			local color = localTeamColors[uTeam]
			local unitpic = cacheUnitPic[uDefID]

			if isRotated then
				glFunc.PushMatrix()
				glFunc.Translate(px, py, 0)
				glFunc.Rotate(-render.minimapRotation * 180 / math.pi, 0, 0, 1)

				-- Black border
				glFunc.Texture(false)
				glFunc.Color(0, 0, 0, 0.9)
				glFunc.BeginEnd(glConst.TRIANGLE_FAN, drawOctagonVertices, 0, 0, bdrSize, crnrCutOuter)

				-- Team color border
				if isSelected then
					glFunc.Color(1, 1, 1, 1)
				elseif color then
					glFunc.Color(color[1], color[2], color[3], 1)
				else
					glFunc.Color(1, 1, 1, 1)
				end
				glFunc.BeginEnd(glConst.TRIANGLE_FAN, drawOctagonVertices, 0, 0, teamBdrSize, crnrCut)

				-- Unitpic texture
				if unitpic then
					glFunc.Texture(unitpic)
					if isSelected then
						glFunc.Color(1, 1, 1, isHovered and math.min(1.0, opacity * 1.3) or opacity)
					else
						local brightness = 0.7 + ((color and (color[1] + color[2] + color[3]) or 3) / 9)
						if isHovered then brightness = brightness * 1.2 end
						glFunc.Color(brightness, brightness, brightness, opacity)
					end
					glFunc.BeginEnd(glConst.TRIANGLE_FAN, drawTexturedOctagonVertices, 0, 0, iconSize, crnrCut, picTexInset)
				end

				-- Health bar (only for damaged units, inside the icon area)
				local healthFrac = up[8] or 1
				if healthFrac < 0.99 then
					local barW = iconSize * 0.82
					local barH = math.max(1, iconSize * 0.13)
					local barY = iconSize - barH * 1.5
					local outl = math.max(1, barH * 0.2)
					glFunc.Texture(false)
					-- Outline
					glFunc.Color(0, 0, 0, 0.9)
					glFunc.BeginEnd(glConst.QUADS, function()
						glFunc.Vertex(-barW - outl, barY - outl, 0)
						glFunc.Vertex(barW + outl, barY - outl, 0)
						glFunc.Vertex(barW + outl, barY + barH + outl, 0)
						glFunc.Vertex(-barW - outl, barY + barH + outl, 0)
					end)
					-- Background
					glFunc.Color(0.15, 0.15, 0.15, 0.8)
					glFunc.BeginEnd(glConst.QUADS, function()
						glFunc.Vertex(-barW, barY, 0)
						glFunc.Vertex(barW, barY, 0)
						glFunc.Vertex(barW, barY + barH, 0)
						glFunc.Vertex(-barW, barY + barH, 0)
					end)
					-- Fill with green→yellow→red gradient
					local hr = healthFrac < 0.5 and 1.0 or (1.0 - (healthFrac - 0.5) * 2)
					local hg = healthFrac > 0.5 and 1.0 or (healthFrac * 2)
					local fillW = barW * 2 * healthFrac - barW
					glFunc.Color(hr, hg, 0, 0.9)
					glFunc.BeginEnd(glConst.QUADS, function()
						glFunc.Vertex(-barW, barY, 0)
						glFunc.Vertex(fillW, barY, 0)
						glFunc.Vertex(fillW, barY + barH, 0)
						glFunc.Vertex(-barW, barY + barH, 0)
					end)
				end

				glFunc.PopMatrix()
			else
				-- Black border
				glFunc.Texture(false)
				glFunc.Color(0, 0, 0, 0.9)
				glFunc.BeginEnd(glConst.TRIANGLE_FAN, drawOctagonVertices, px, py, bdrSize, crnrCutOuter)

				-- Team color border
				if isSelected then
					glFunc.Color(1, 1, 1, 1)
				elseif color then
					glFunc.Color(color[1], color[2], color[3], 1)
				else
					glFunc.Color(1, 1, 1, 1)
				end
				glFunc.BeginEnd(glConst.TRIANGLE_FAN, drawOctagonVertices, px, py, teamBdrSize, crnrCut)

				-- Unitpic texture
				if unitpic then
					glFunc.Texture(unitpic)
					if isSelected then
						glFunc.Color(1, 1, 1, isHovered and math.min(1.0, opacity * 1.3) or opacity)
					else
						local brightness = 0.7 + ((color and (color[1] + color[2] + color[3]) or 3) / 9)
						if isHovered then brightness = brightness * 1.2 end
						glFunc.Color(brightness, brightness, brightness, opacity)
					end
					glFunc.BeginEnd(glConst.TRIANGLE_FAN, drawTexturedOctagonVertices, px, py, iconSize, crnrCut, picTexInset)
				end

				-- Health bar (only for damaged units, inside the icon area)
				local healthFrac = up[8] or 1
				if healthFrac < 0.99 then
					local barW = iconSize * 0.82
					local barH = math.max(1, iconSize * 0.13)
					local barY = py + iconSize - barH * 1.5
					local outl = math.max(1, barH * 0.2)
					glFunc.Texture(false)
					-- Outline
					glFunc.Color(0, 0, 0, 0.9)
					glFunc.BeginEnd(glConst.QUADS, function()
						glFunc.Vertex(px - barW - outl, barY - outl, 0)
						glFunc.Vertex(px + barW + outl, barY - outl, 0)
						glFunc.Vertex(px + barW + outl, barY + barH + outl, 0)
						glFunc.Vertex(px - barW - outl, barY + barH + outl, 0)
					end)
					-- Background
					glFunc.Color(0.15, 0.15, 0.15, 0.8)
					glFunc.BeginEnd(glConst.QUADS, function()
						glFunc.Vertex(px - barW, barY, 0)
						glFunc.Vertex(px + barW, barY, 0)
						glFunc.Vertex(px + barW, barY + barH, 0)
						glFunc.Vertex(px - barW, barY + barH, 0)
					end)
					-- Fill with green→yellow→red gradient
					local hr = healthFrac < 0.5 and 1.0 or (1.0 - (healthFrac - 0.5) * 2)
					local hg = healthFrac > 0.5 and 1.0 or (healthFrac * 2)
					local fillW = barW * 2 * healthFrac - barW
					glFunc.Color(hr, hg, 0, 0.9)
					glFunc.BeginEnd(glConst.QUADS, function()
						glFunc.Vertex(px - barW, barY, 0)
						glFunc.Vertex(px + fillW, barY, 0)
						glFunc.Vertex(px + fillW, barY + barH, 0)
						glFunc.Vertex(px - barW, barY + barH, 0)
					end)
				end
			end
		end

		glFunc.Texture(false)
	end

	-- Draw start unit icon before game starts (when commander is not yet placed)
	if not gameHasStarted and not isMinimapMode and miscState.startX and miscState.startX >= 0 then
		local myTeamID = Spring.GetMyTeamID()
		local startDefID = Spring.GetTeamRulesParam(myTeamID, "startUnit")
		if startDefID and cacheUnitIcon[startDefID] then
			local iconData = cacheUnitIcon[startDefID]
			local iconSize = iconRadiusZoomDistMult * iconData.size
			local cx, cy = WorldToPipCoords(miscState.startX, miscState.startZ)
			local teamColor = localTeamColors[myTeamID] or {1, 1, 1}
			local texInset = 0.07

			gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
			glFunc.Texture(iconData.bitmap)
			glFunc.BeginEnd(glConst.QUADS, function()
				glFunc.Color(teamColor[1], teamColor[2], teamColor[3], 1)
				glFunc.TexCoord(texInset, 1 - texInset)
				glFunc.Vertex(cx - iconSize, cy - iconSize)
				glFunc.TexCoord(1 - texInset, 1 - texInset)
				glFunc.Vertex(cx + iconSize, cy - iconSize)
				glFunc.TexCoord(1 - texInset, texInset)
				glFunc.Vertex(cx + iconSize, cy + iconSize)
				glFunc.TexCoord(texInset, texInset)
				glFunc.Vertex(cx - iconSize, cy + iconSize)
			end)
			glFunc.Texture(false)
		end
	end

	local icT6 = os.clock()
	perfTimers.icGhost = perfTimers.icGhost + PERF_SMOOTH * ((icT1 - icT0) - perfTimers.icGhost)
	perfTimers.icKeysort = perfTimers.icKeysort + PERF_SMOOTH * ((icT2 - icT1) - perfTimers.icKeysort)
	perfTimers.icSort = perfTimers.icSort + PERF_SMOOTH * ((icT3 - icT2) - perfTimers.icSort)
	perfTimers.icProcess = perfTimers.icProcess + PERF_SMOOTH * ((icT4 - icT3) - perfTimers.icProcess)
	perfTimers.icProcBldg = perfTimers.icProcBldg + PERF_SMOOTH * ((icT3b - icT3) - perfTimers.icProcBldg)
	perfTimers.icProcMobile = perfTimers.icProcMobile + PERF_SMOOTH * ((icT4 - icT3b) - perfTimers.icProcMobile)
	perfTimers.icProcBldgN = bldgProcessed
	perfTimers.icProcMobileN = mobileProcessed
	perfTimers.icUploadDraw = perfTimers.icUploadDraw + PERF_SMOOTH * ((icT5 - icT4) - perfTimers.icUploadDraw)
	perfTimers.icUnitpics = perfTimers.icUnitpics + PERF_SMOOTH * ((icT6 - icT5) - perfTimers.icUnitpics)

	return iconRadiusZoomDistMult
end
-- Helper function to draw units and features in PIP
local function DrawUnitsAndFeatures(cachedSelectedUnits)

	-- Use larger margin for units and features to account for their radius
	-- Features especially can be quite large (up to ~200 units radius for big wrecks)
	local margin = 220

	-- When spectating and tracking a player, get ALL units and we'll filter by visibility in DrawUnit
	-- Otherwise, GetUnitsInRectangle returns units visible to our team
	if interactionState.trackingPlayerID and cameraState.mySpecState then
		-- Spectating and tracking: get all units (pass -1 to get all units regardless of visibility)
		miscState.pipUnits = Spring.GetAllUnits()
		-- Filter to only units in the rectangle (do this manually since we got all units)
		local unitsInRect = {}
		for i = 1, #miscState.pipUnits do
			local uID = miscState.pipUnits[i]
			local ux, _, uz = spFunc.GetUnitBasePosition(uID)
			if ux and ux >= render.world.l - margin and ux <= render.world.r + margin and uz >= render.world.t - margin and uz <= render.world.b + margin then
				unitsInRect[#unitsInRect + 1] = uID
			end
		end
		miscState.pipUnits = unitsInRect
	else
		-- Normal play or spec without tracking: use standard API (returns LOS + radar units for our team)
		miscState.pipUnits = spFunc.GetUnitsInRectangle(render.world.l - margin, render.world.t - margin, render.world.r + margin, render.world.b + margin)
	end

	-- Cache counts to avoid repeated length calculations
	local unitCount = #miscState.pipUnits

	-- Pre-compute per-frame visibility context (avoids redundant API calls per unit)
	local checkAllyTeamID = nil
	local _, fullview = Spring.GetSpectatingState()
	local myAllyTeam = Spring.GetMyAllyTeamID()
	if interactionState.trackingPlayerID and cameraState.mySpecState then
		local _, _, _, playerTeamID = spFunc.GetPlayerInfo(interactionState.trackingPlayerID, false)
		if playerTeamID then
			local playerAllyTeamID = teamAllyTeamCache[playerTeamID] or Spring.GetTeamAllyTeamID(playerTeamID)
			if not fullview and playerAllyTeamID ~= myAllyTeam then
				checkAllyTeamID = myAllyTeam
			else
				checkAllyTeamID = playerAllyTeamID
			end
		end
	elseif state.losViewEnabled and state.losViewAllyTeam then
		checkAllyTeamID = state.losViewAllyTeam
	elseif not cameraState.mySpecState then
		local myTeamID = Spring.GetMyTeamID()
		checkAllyTeamID = teamAllyTeamCache[myTeamID] or Spring.GetTeamAllyTeamID(myTeamID)
	elseif cameraState.mySpecState then
		if not fullview then
			checkAllyTeamID = myAllyTeam
		end
	end

	-- Pre-fetch player selections once (avoids per-unit WG lookup)
	local playerSelections = nil
	if interactionState.trackingPlayerID then
		playerSelections = WG['allyselectedunits'] and WG['allyselectedunits'].getPlayerSelectedUnits(interactionState.trackingPlayerID)
		if not playerSelections then playerSelections = {} end  -- empty table signals "use tracking mode" to DrawUnit
	end

	-- Build tracking set for O(1) lookup (avoids O(N*M) linear scan per unit)
	local trackingSet = nil
	if interactionState.areTracking then
		trackingSet = pools.trackingSet
		if not trackingSet then
			trackingSet = {}
			pools.trackingSet = trackingSet
		end
		for k in pairs(trackingSet) do trackingSet[k] = nil end
		for _, trackedID in ipairs(interactionState.areTracking) do
			trackingSet[trackedID] = true
		end
	end

	-- Note: cameraRotY is now set in DrawScreen before this function is called

	gl.DepthTest(true)
	gl.DepthMask(true)
	gl.Blending(false)
	gl.AlphaTest(false)

	gl.Scissor(render.dim.l, render.dim.b, render.dim.r - render.dim.l, render.dim.t - render.dim.b)
	glFunc.LineWidth(2.0)

	-- Precompute center translation values (used by all drawing)
	local centerX = 0.5 * (render.dim.l + render.dim.r)
	local centerY = 0.5 * (render.dim.b + render.dim.t)

	-- Get resolution scale for R2T rendering (affects coordinate mapping, not icon sizes)
	local resScale = render.contentScale or 1

	-- Calculate content scale during minimize animation
	local contentScale = 1.0
	if uiState.isAnimating then
		-- During animation, scale content to fit within the shrinking window
		-- Only scale down during minimize (uiState.inMinMode = true), not during maximize
		if uiState.inMinMode then
			local currentWidth = render.dim.r - render.dim.l
			local currentHeight = render.dim.t - render.dim.b
			local startWidth = uiState.animStartDim.r - uiState.animStartDim.l
			local startHeight = uiState.animStartDim.t - uiState.animStartDim.b

			-- Use the smaller of width/height ratio to maintain aspect ratio
			local widthScale = currentWidth / startWidth
			local heightScale = currentHeight / startHeight
			contentScale = math.min(widthScale, heightScale)
		end
		-- When maximizing (uiState.inMinMode = false), keep contentScale = 1.0 to avoid oversized units
	end

	-- Apply contentScale for animation, and resScale for high-res R2T rendering
	-- resScale is multiplied to match the enlarged coordinate space
	local drawScale = cameraState.zoom * contentScale * resScale
	glFunc.PushMatrix()
	glFunc.Translate(centerX, centerY, 0)
	glFunc.Scale(drawScale, drawScale, drawScale)


	-- Draw features (3D models)
	local featureFade = 0
	if cameraState.zoom >= config.zoomFeatures then
		featureFade = math.min(1, (cameraState.zoom - config.zoomFeatures) / config.zoomFeaturesFadeRange)
	end
	-- Skip features entirely under extreme workload
	if perfTimers.itemCount > 1200 then featureFade = 0 end
	local t0 = os.clock()
	if featureFade > 0 then  -- Only draw features if zoom is above threshold
		miscState.pipFeatures = spFunc.GetFeaturesInRectangle(render.world.l - margin, render.world.t - margin, render.world.r + margin, render.world.b + margin)
		local featureCount = #miscState.pipFeatures
		if featureCount > 0 then
			-- Premultiplied alpha: RGB = color * fade, A = fade
			-- Pass 1: RGB only. Modulate by featureFade for premultiplied alpha.
			-- Mask alpha writes because feature tex0.alpha is used
			-- as a team-color/transparency mask and would cause semi-transparency
			-- when the FBO is composited with premultiplied alpha.
			gl.ColorMask(true, true, true, false)
			glFunc.Color(featureFade, featureFade, featureFade, 1)
			glFunc.Texture(0, '$units')
			for i = 1, featureCount do
				DrawFeature(miscState.pipFeatures[i])
			end
			-- Pass 2: alpha only. Write featureFade to alpha channel.
			-- Re-render feature geometry without texture so the
			-- fixed-function pipeline outputs glColor alpha.
			-- Key: DepthTest must be LEQUAL (not default LESS) so fragments at the
			-- same depth as pass 1 are accepted (D <= D = true).
			gl.ColorMask(false, false, false, true)
			gl.DepthTest(GL.LEQUAL)
			gl.DepthMask(false)
			glFunc.Texture(0, false)
			glFunc.Color(1, 1, 1, featureFade)
			for i = 1, featureCount do
				DrawFeature(miscState.pipFeatures[i], true)  -- noTextures: skip texture bind
			end
			-- Restore
			gl.ColorMask(true, true, true, true)
			gl.DepthTest(true)
			gl.DepthMask(true)
			glFunc.Color(1, 1, 1, 1)
		end
	end

	-- Reset GL4 primitive counters for this frame
	if gl4Prim.enabled then
		GL4ResetPrimCounts()
	end

	local t1 = os.clock()
	perfTimers.features = perfTimers.features + PERF_SMOOTH * ((t1 - t0) - perfTimers.features)

	-- Draw projectiles if enabled
	if config.drawProjectiles then
		glFunc.Texture(false)  -- Disable textures for colored projectiles
		gl.Blending(true)
		gl.DepthTest(false)

		do
			-- Get projectiles in the PIP window's world rectangle
			-- Use larger margin (1200) to catch beam/lightning projectiles whose impact point
			-- is far from the visible area but whose origin (shooting unit) is in view
			local projMargin = 1200
			local projectiles = spFunc.GetProjectilesInRectangle(render.world.l - projMargin, render.world.t - projMargin, render.world.r + projMargin, render.world.b + projMargin)
			
			-- Reuse pool table for active trails tracking (avoid per-frame allocations)
			local activeTrails = pools.activeTrails
			-- Clear previous frame's data
			for k in pairs(activeTrails) do activeTrails[k] = nil end
			
			if projectiles then
				local projectileCount = #projectiles
				local MAX_PROJECTILES = GetDetailCap(150)

				-- When too many projectiles, compute a minimum explosion radius threshold
				-- so only the ~150 biggest-damage ones are drawn
				local minRadius = 0
				if projectileCount > MAX_PROJECTILES then
					-- Collect explosion radii for all projectiles
					local radii = pools.projectileRadii
					if not radii then
						radii = {}
						pools.projectileRadii = radii
					end
					local rCount = 0
					for i = 1, projectileCount do
						local pDefID = spFunc.GetProjectileDefID(projectiles[i])
						local r = pDefID and cache.weaponExplosionRadius[pDefID] or 10
						rCount = rCount + 1
						radii[rCount] = r
					end
					-- Sort descending and pick the threshold at MAX_PROJECTILES
					table.sort(radii, sortDescending)
					minRadius = radii[MAX_PROJECTILES] or 0
					-- Clear excess entries
					for i = rCount + 1, #radii do radii[i] = nil end
				end

				for i = 1, projectileCount do
					local pID = projectiles[i]
					-- Filter small projectiles when over budget
					-- Always draw lasers/lightning/blasters (they're visually important beams)
					local shouldDraw = true
					if minRadius > 0 then
						local pDefID = spFunc.GetProjectileDefID(pID)
						if not (pDefID and (cache.weaponIsLaser[pDefID] or cache.weaponIsLightning[pDefID] or cache.weaponIsBlaster[pDefID])) then
							local r = pDefID and cache.weaponExplosionRadius[pDefID] or 10
							if r < minRadius then
								shouldDraw = false
							end
						end
					end
					if shouldDraw then
						DrawProjectile(pID)
					end
					-- Mark this trail as active if it exists (for stale cleanup)
					if cache.missileTrails[pID] or cache.plasmaTrails[pID] or cache.flameBirthTime[pID] then
						activeTrails[pID] = true
					end
				end
			end
			
			-- Clean up stale missile trails (projectiles that no longer exist)
			for pID in pairs(cache.missileTrails) do
				if not activeTrails[pID] then
					cache.missileTrails[pID] = nil
				end
			end
			for pID in pairs(cache.plasmaTrails) do
				if not activeTrails[pID] then
					cache.plasmaTrails[pID] = nil
				end
			end
			for pID in pairs(cache.flameBirthTime) do
				if not activeTrails[pID] then
					cache.flameBirthTime[pID] = nil
					cache.flameSeeds[pID] = nil
				end
			end

			-- Draw laser beams
			DrawLaserBeams()
		end

		-- Draw icon shatters
		DrawIconShatters()

		-- Draw seismic pings (always visible at any zoom level)
		DrawSeismicPings()
		
		gl.DepthTest(true)
		gl.Blending(false)
	end
	
	local t2 = os.clock()
	perfTimers.projectiles = perfTimers.projectiles + PERF_SMOOTH * ((t2 - t1) - perfTimers.projectiles)

	-- Draw explosions independently (graduated visibility based on radius)
	if config.drawExplosions then
		gl.Blending(true)
		gl.DepthTest(false)
		glFunc.Texture(false)
		DrawExplosions()
		gl.DepthTest(true)
		gl.Blending(false)
	end

	glFunc.PopMatrix()

	-- Flush GL4 primitives (circles, quads, lines from projectiles/explosions/beams)
	-- Must happen after PopMatrix since GL4 shaders bypass the matrix stack
	if gl4Prim.enabled then
		gl.Blending(true)
		gl.DepthTest(false)
		glFunc.Texture(false)
		GL4FlushEffects()
		gl.DepthTest(true)
		gl.Blending(false)
	end

	glFunc.Texture(0, false)
	gl.Blending(true)
	gl.DepthMask(false)
	gl.DepthTest(false)

	local t3 = os.clock()
	perfTimers.explosions = perfTimers.explosions + PERF_SMOOTH * ((t3 - t2) - perfTimers.explosions)

	-- Command queue drawing is handled by DrawCommandQueuesOverlay (called after this function)
	-- which uses cached waypoints and batched rendering (GL4 or single BeginEnd calls).

	-- Draw icons (GL4 instanced path)
	local iconRadiusZoomDistMult
	-- Build selection set for GL4 icon rendering
	local selectedSet
	if interactionState.trackingPlayerID then
		selectedSet = WG['allyselectedunits'] and WG['allyselectedunits'].getPlayerSelectedUnits(interactionState.trackingPlayerID)
	else
		local selUnits2 = cachedSelectedUnits or Spring.GetSelectedUnits()
		selectedSet = {}
		for si = 1, #selUnits2 do selectedSet[selUnits2[si]] = true end
	end
	iconRadiusZoomDistMult = GL4DrawIcons(checkAllyTeamID, selectedSet, trackingSet)

	local t4 = os.clock()
	perfTimers.icons = perfTimers.icons + PERF_SMOOTH * ((t4 - t3) - perfTimers.icons)

	-- Explosion overlay: re-render explosions on top of icons with additive blend
	-- This creates a "units engulfed in fire" effect using a single soft glow per explosion
	-- Skip under high workload to save GPU time
	if config.explosionOverlay and config.drawExplosions and #cache.explosions > 0 and gl4Prim.enabled and perfTimers.itemCount < 800 then
		GL4ResetPrimCounts()
		DrawExplosionOverlay()
		if gl4Prim.circles.count > 0 then
			gl.Blending(GL.SRC_ALPHA, GL.ONE)  -- Additive blend
			gl.DepthTest(false)
			GL4FlushCirclesOnly()
			gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)  -- Restore
		end
	end

	-- Draw ally cursors
	if WG['allycursors'] and WG['allycursors'].getCursor and interactionState.trackingPlayerID then
		local cursor, isNotIdle = WG['allycursors'].getCursor(interactionState.trackingPlayerID)
		if cursor and isNotIdle then
			local wx, wz = cursor[1], cursor[3]
			local cx, cy = WorldToPipCoords(wx, wz)
			local opacity = cursor[7] or 1

			-- Get player's team color
			local _, _, _, teamID = spFunc.GetPlayerInfo(interactionState.trackingPlayerID, false)
			if teamID then
				local r, g, b = Spring.GetTeamColor(teamID)
				-- Scale cursor size: larger at low zoom, stays reasonable at high zoom
				local resScale = config.contentResolutionScale or 1
				local cursorSize = render.vsy * 0.0073 * resScale
				-- Draw crosshair lines to PIP boundaries (stop at cursor edge)
				--glFunc.Color(r*1.5+0.5, g*1.5+0.5, b*1.5+0.5, 0.08)
				--glFunc.LineWidth(render.vsy / 600)
				-- glFunc.BeginEnd(glConst.LINES, function()
				-- 	-- Horizontal line (left to cursor)
				-- 	glFunc.Vertex(0, cy)
				-- 	glFunc.Vertex(cx - cursorSize, cy)
				-- 	-- Horizontal line (cursor to right)
				-- 	glFunc.Vertex(cx + cursorSize, cy)
				-- 	glFunc.Vertex(render.dim.r - render.dim.l, cy)
				-- 	-- Vertical line (bottom to cursor)
				-- 	glFunc.Vertex(cx, 0)
				-- 	glFunc.Vertex(cx, cy - cursorSize)
				-- 	-- Vertical line (cursor to top)
				-- 	glFunc.Vertex(cx, cy + cursorSize)
				-- 	glFunc.Vertex(cx, render.dim.t - render.dim.b)
				-- end)

				-- Draw cursor as broken circle (4 arcs with 4 gaps)
				-- Each arc is 1/8 of circle, each gap is 1/8 of circle
				-- Arcs centered at top (90°), right (0°), bottom (270°), left (180°)
				local segments = 24
				local pi = math.pi

				-- Define 4 arcs: each arc is 45° (pi/4), centered at cardinal directions
				local arcs = {
					{pi/2 - pi/8, pi/2 + pi/8},      -- Top arc (centered at 90°)
					{0 - pi/8, 0 + pi/8},             -- Right arc (centered at 0°)
					{3*pi/2 - pi/8, 3*pi/2 + pi/8},  -- Bottom arc (centered at 270°)
					{pi - pi/8, pi + pi/8}            -- Left arc (centered at 180°)
				}

				-- Draw black outline first (thicker)
				glFunc.Color(0, 0, 0, 0.66)
				glFunc.LineWidth((render.vsy / 500 + 2) * resScale)
				for _, arc in ipairs(arcs) do
					glFunc.BeginEnd(GL.LINE_STRIP, function()
						local startAngle, endAngle = arc[1], arc[2]
						local arcSegments = math.floor(segments / 8) -- 1/8 of circle for each arc
						for i = 0, arcSegments do
							local t = i / arcSegments
							local angle = startAngle + (endAngle - startAngle) * t
							local x = cx + math.cos(angle) * cursorSize
							local y = cy + math.sin(angle) * cursorSize
							glFunc.Vertex(x, y)
						end
					end)
				end

				-- Draw colored arcs on top
				glFunc.Color((r*1.3)+0.66, (g*1.3)+0.66, (b*1.3)+0.66, 1)
				glFunc.LineWidth((render.vsy / 500) * resScale)
				for _, arc in ipairs(arcs) do
					glFunc.BeginEnd(GL.LINE_STRIP, function()
						local startAngle, endAngle = arc[1], arc[2]
						local arcSegments = math.floor(segments / 8) -- 1/8 of circle for each arc
						for i = 0, arcSegments do
							local t = i / arcSegments
							local angle = startAngle + (endAngle - startAngle) * t
							local x = cx + math.cos(angle) * cursorSize
							local y = cy + math.sin(angle) * cursorSize
							glFunc.Vertex(x, y)
						end
					end)
				end
				glFunc.LineWidth(1.0)
			end
		end
	end

	-- Draw build previews
	local mx, my = spFunc.GetMouseState()
	DrawBuildPreview(mx, my, iconRadiusZoomDistMult)
	DrawBuildDragPreview(iconRadiusZoomDistMult)
	DrawQueuedBuilds(iconRadiusZoomDistMult, cachedSelectedUnits)

	glFunc.LineWidth(1.0)
	gl.Scissor(false)

	-- Update total timer and item count
	local tEnd = os.clock()
	perfTimers.total = perfTimers.total + PERF_SMOOTH * ((tEnd - t0) - perfTimers.total)
	perfTimers.itemCount = unitCount + #cache.explosions + (miscState.pipFeatures and #miscState.pipFeatures or 0)

	-- Debug echo every 2 seconds
	if config.showPipTimers and tEnd - perfTimers.lastEchoTime > 2.0 then
		perfTimers.lastEchoTime = tEnd
		Spring.Echo(string.format(
			"[PIP%d] total=%.1fms  feat=%.2fms  proj=%.2fms  expl=%.2fms  icons=%.2fms  items=%d",
			pipNumber,
			perfTimers.total * 1000,
			perfTimers.features * 1000,
			perfTimers.projectiles * 1000,
			perfTimers.explosions * 1000,
			perfTimers.icons * 1000,
			perfTimers.itemCount
		))
		Spring.Echo(string.format(
			"  icons: ghost=%.2fms  keysort=%.2fms  sort=%.2fms  process=%.2fms  upload+draw=%.2fms  unitpics=%.2fms",
			perfTimers.icGhost * 1000,
			perfTimers.icKeysort * 1000,
			perfTimers.icSort * 1000,
			perfTimers.icProcess * 1000,
			perfTimers.icUploadDraw * 1000,
			perfTimers.icUnitpics * 1000
		))
		Spring.Echo(string.format(
			"    process: bldg=%.2fms(%d)  mobile=%.2fms(%d)",
			perfTimers.icProcBldg * 1000,
			perfTimers.icProcBldgN,
			perfTimers.icProcMobile * 1000,
			perfTimers.icProcMobileN
		))
	end
end

-- Helper function to render PIP frame background (static)
local function RenderFrameBackground()
	-- Render panel at origin without accounting for padding (padding drawn separately)
	local pipWidth = render.dim.r - render.dim.l
	local pipHeight = render.dim.t - render.dim.b
	glFunc.Color(0.6,0.6,0.6,0.6)
	
	-- Determine which corners to round based on screen edge proximity
	-- Corners at screen edges should be sharp (0), others rounded (1)
	local edgeTolerance = 2  -- Pixels from edge to consider "at edge"
	local atLeft = render.dim.l <= edgeTolerance
	local atRight = render.dim.r >= render.vsx - edgeTolerance
	local atBottom = render.dim.b <= edgeTolerance
	local atTop = render.dim.t >= render.vsy - edgeTolerance
	
	-- RectRound params: tl, tr, br, bl (top-left, top-right, bottom-right, bottom-left)
	local tl = (atLeft or atTop) and 0 or 1
	local tr = (atRight or atTop) and 0 or 1
	local br = (atRight or atBottom) and 0 or 1
	local bl = (atLeft or atBottom) and 0 or 1
	
	render.RectRound(0, 0, pipWidth, pipHeight, render.elementCorner*0.4, tl, tr, br, bl)
end

-- Helper function to calculate maximize icon rotation angle based on expansion direction
local function GetMaximizeIconRotation()
	-- Determine expansion direction based on current or minimize button position
	local sw, sh = Spring.GetWindowGeometry()
	local posL, posB
	
	-- Use current position when maximized (for minimize button rotation during drag/resize)
	-- Use minMode position when minimized (for maximize button rotation)
	if uiState.inMinMode then
		posL = uiState.minModeL
		posB = uiState.minModeB
	else
		-- When maximized, determine where it would minimize to based on current position
		local buttonSize = math.floor(render.usedButtonSize * config.maximizeSizemult)
		if render.dim.l < sw * 0.5 then
			posL = render.dim.l
		else
			posL = render.dim.r - buttonSize
		end
		if render.dim.b < sh * 0.25 then
			posB = render.dim.b
		else
			posB = render.dim.t - buttonSize
		end
	end
	
	local onLeftSide = (posL and posL < sw * 0.5)
	local onBottomSide = (posB and posB < sh * 0.25)
	
	-- Default icon points to bottom-left, rotate to point toward expansion:
	if onLeftSide and onBottomSide then
		return 180  -- Bottom-left: expands toward top-right
	elseif not onLeftSide and onBottomSide then
		return 270  -- Bottom-right: expands toward top-left
	elseif not onLeftSide and not onBottomSide then
		return 0  -- Top-right: expands toward bottom-left
	else  -- onLeftSide and not onBottomSide
		return 90  -- Top-left: expands toward bottom-right
	end
end

-- Helper function to render PIP frame buttons without hover effects
local function RenderFrameButtons()
	-- In minimap mode, don't render buttons at all (no minimize, no resize handle)
	if isMinimapMode and config.minimapModeShowButtons == false then
		return
	end

	local usedButtonSizeLocal = render.usedButtonSize
	local pipWidth = render.dim.r - render.dim.l
	local pipHeight = render.dim.t - render.dim.b

	-- Skip all rendering if showButtonsOnHoverOnly is enabled and mouse is not over PIP
	if config.showButtonsOnHoverOnly and not interactionState.isMouseOverPip then
		return
	end

	-- Resize handle (bottom-right corner) - hide in minimap mode if configured
	if not (isMinimapMode and config.minimapModeHideMoveResize) then
		glFunc.Color(config.panelBorderColorDark)
		glFunc.LineWidth(1.0)
		glFunc.BeginEnd(glConst.TRIANGLES, function()
			-- Relative coordinates for resize handle
			glFunc.Vertex(pipWidth - usedButtonSizeLocal, 0)
			glFunc.Vertex(pipWidth, 0)
			glFunc.Vertex(pipWidth, usedButtonSizeLocal)
		end)
	end

	-- Minimize button (top-right) - hide in minimap mode
	if not isMinimapMode then
		glFunc.Color(config.panelBorderColorDark)
		glFunc.Texture(false)
		render.RectRound(pipWidth - usedButtonSizeLocal - render.elementPadding, pipHeight - usedButtonSizeLocal - render.elementPadding, pipWidth, pipHeight, render.elementCorner*0.65, 0, 0, 0, 1)
		glFunc.Color(config.panelBorderColorLight)
		glFunc.Texture('LuaUI/Images/pip/PipShrink.png')
		
		-- Rotate icon to point toward shrink position (opposite of expand direction)
		local rotation = GetMaximizeIconRotation()
		local centerX = pipWidth - usedButtonSizeLocal * 0.5
		local centerY = pipHeight - usedButtonSizeLocal * 0.5
		glFunc.PushMatrix()
		glFunc.Translate(centerX, centerY, 0)
		glFunc.Rotate(rotation, 0, 0, 1)
		glFunc.Translate(-centerX, -centerY, 0)
		
		glFunc.TexRect(pipWidth - usedButtonSizeLocal, pipHeight - usedButtonSizeLocal, pipWidth, pipHeight)
		glFunc.PopMatrix()
		glFunc.Texture(false)
	end

	-- Bottom-left buttons
	local selectedUnits = Spring.GetSelectedUnits()
	local hasSelection = #selectedUnits > 0
	local isTracking = interactionState.areTracking ~= nil
	local isTrackingPlayer = interactionState.trackingPlayerID ~= nil
	-- Show player tracking button when tracking, when spectating, or when having alive teammates
	local spec = Spring.GetSpectatingState()
	local aliveTeammates = GetAliveTeammates()
	local showPlayerTrackButton = isTrackingPlayer or spec or (#aliveTeammates > 0)
	local visibleButtons = {}
	for i = 1, #buttons do
		local btn = buttons[i]
		-- In minimap mode, hide move button if configured
		local skipButton = false
		if isMinimapMode and config.minimapModeHideMoveResize then
			-- Skip move button (no command, has PipMove texture)
			if btn.tooltipKey == 'ui.pip.move' then
				skipButton = true
			end
		end
		
		if not skipButton then
			-- In minimap mode, skip switch and copy buttons (keep pip_track and pip_trackplayer)
			-- Allow pip_view for spectators with fullview
			if isMinimapMode then
				if btn.command == 'pip_switch' or btn.command == 'pip_copy' then
					skipButton = true
				elseif btn.command == 'pip_view' then
					local _, fullview = Spring.GetSpectatingState()
					if not fullview then
						skipButton = true
					end
				end
			end
		end
		
		if not skipButton then
			-- Show pip_track button if has selection or is tracking units
			if btn.command == 'pip_track' then
				if hasSelection or isTracking then
					visibleButtons[#visibleButtons + 1] = btn
				end
			-- Show pip_trackplayer button if lockcamera is available or already tracking (hidden during TV)
			elseif btn.command == 'pip_trackplayer' then
				if showPlayerTrackButton and not miscState.tvEnabled then
					visibleButtons[#visibleButtons + 1] = btn
				end
			-- Show pip_view button only for spectators
			elseif btn.command == 'pip_view' then
				if showPlayerTrackButton then
					visibleButtons[#visibleButtons + 1] = btn
				end
			-- Hide pip_activity in singleplayer, when tracking, or optionally for spectators
			elseif btn.command == 'pip_activity' then
				if not isSinglePlayer and not interactionState.trackingPlayerID and not miscState.tvEnabled and not (config.activityFocusHideForSpectators and cameraState.mySpecState) then
					visibleButtons[#visibleButtons + 1] = btn
				end
			-- Show pip_tv button for spectators only (or always if not spectator-only)
			elseif btn.command == 'pip_tv' then
				if not config.tvModeSpectatorsOnly or cameraState.mySpecState then
					visibleButtons[#visibleButtons + 1] = btn
				end
			else
				visibleButtons[#visibleButtons + 1] = btn
			end
		end
	end

	local buttonCount = #visibleButtons
	glFunc.Color(config.panelBorderColorDark)
	glFunc.Texture(false)
	render.RectRound(0, 0, (buttonCount * usedButtonSizeLocal) + math.floor(render.elementPadding*0.75), usedButtonSizeLocal + math.floor(render.elementPadding*0.75), render.elementCorner*0.65, 0, 1, 0, 0)

	local bx = 0
	for i = 1, buttonCount do
		local isActive = (visibleButtons[i].command == 'pip_track' and interactionState.areTracking) or
		                 (visibleButtons[i].command == 'pip_trackplayer' and interactionState.trackingPlayerID) or
		                 (visibleButtons[i].command == 'pip_view' and state.losViewEnabled) or
		                 (visibleButtons[i].command == 'pip_activity' and miscState.activityFocusEnabled) or
		                 (visibleButtons[i].command == 'pip_tv' and miscState.tvEnabled)
		
		if isActive then
			glFunc.Color(config.panelBorderColorLight)
			glFunc.Texture(false)
			render.RectRound(bx, 0, bx + usedButtonSizeLocal, usedButtonSizeLocal, render.elementCorner*0.4, 1, 1, 1, 1)
			glFunc.Color(config.panelBorderColorDark)
		else
			glFunc.Color(config.panelBorderColorLight)
		end
		glFunc.Texture(visibleButtons[i].texture)
		glFunc.TexRect(bx, 0, bx + usedButtonSizeLocal, usedButtonSizeLocal)
		bx = bx + usedButtonSizeLocal
	end
	glFunc.Texture(false)
end

-- Helper function to render PIP contents (units, features, ground, command queues)
-- Helper function to determine if LOS overlay should be shown and which allyteam to use
local function ShouldShowLOS()
	local myAllyTeam = Spring.GetMyAllyTeamID()
	local mySpec, fullview = Spring.GetSpectatingState()

	-- If tracking a player's camera, use their allyteam (priority over LOS view)
	if interactionState.trackingPlayerID then
		local _, _, isSpec, teamID = spFunc.GetPlayerInfo(interactionState.trackingPlayerID, false)
		if teamID then
			local allyTeamID = Spring.GetTeamAllyTeamID(teamID)
			-- Always return the tracked player's allyteam for LOS generation
			-- Even without fullview, we can manually generate their LOS at this location
			return true, allyTeamID
		end
	end

	-- If LOS view is manually enabled via button, use the locked allyteam (after checking player tracking)
	if state.losViewEnabled and state.losViewAllyTeam then
		-- Verify we can actually view this ally team's LOS
		-- Spectators with fullview can see any ally team, otherwise only current ally team
		if fullview or state.losViewAllyTeam == myAllyTeam then
			return true, state.losViewAllyTeam
		else
			-- Can't view this ally team anymore, disable LOS view
			state.losViewEnabled = false
			state.losViewAllyTeam = nil
		end
	end

	-- If not a spectator, show LOS for our own allyteam
	if not mySpec then
		return true, myAllyTeam
	end

	-- Spectators without fullview should see LOS for their current view
	if mySpec and not fullview then
		return true, myAllyTeam
	end

	-- Spectators with fullview don't need LOS overlay
	return false, nil
end

-- Helper function to get the normalized water/lava threshold for the heightmap shader
-- Returns the water/lava surface level in elmos for the heightmap shader
-- On lava maps, does a lazy read from the game rule if not yet known
local function GetWaterLevel()
	if mapInfo.dynamicWaterLevel then
		return mapInfo.dynamicWaterLevel
	end
	-- Lazy fallback: try reading game rule on first use (covers the gap between
	-- widget init and the first Update() poll, avoiding wrong waterLevel=0 on lava maps)
	if mapInfo.isLava then
		local level = Spring.GetGameRulesParam("lavaLevel")
		if level and level ~= -99999 then
			mapInfo.dynamicWaterLevel = level
			return level
		end
	end
	return 0
end

-- Helper function to draw water and LOS overlays
local function DrawWaterAndLOSOverlays()
	
	-- Draw water overlay using shader
	if mapInfo.hasWater and shaders.water then
		gl.UseShader(shaders.water)
		
		-- Set water color based on lava/water/void
		local r, g, b, a
		if mapInfo.voidWater then
			r, g, b, a = 0, 0, 0, 1
		elseif mapInfo.isLava then
			r, g, b, a = 0.22, 0, 0, 1
		else
			r, g, b, a = 0.08, 0.11, 0.22, 0.5
		end
		gl.UniformFloat(gl.GetUniformLocation(shaders.water, "waterColor"), r, g, b, a)
		gl.UniformFloat(gl.GetUniformLocation(shaders.water, "waterLevel"), GetWaterLevel())
		
		-- Bind heightmap texture
		gl.UniformInt(gl.GetUniformLocation(shaders.water, "heightTex"), 0)
		glFunc.Texture(0, '$heightmap')
		
		-- Draw water overlay
		glFunc.Color(1, 1, 1, 1)
		glFunc.BeginEnd(glConst.QUADS, GroundTextureVertices)
		
		glFunc.Texture(0, false)
		gl.UseShader(0)
	end

	-- Restore separate blend for alpha (maintains correct alpha accumulation in R2T FBOs)
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	gl.BlendFuncSeparate(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA, GL.ONE, GL.ONE_MINUS_SRC_ALPHA)

	-- Draw LOS darkening overlay
	local shouldShowLOS, losAllyTeam = ShouldShowLOS()
	if config.showLosOverlay and shouldShowLOS and pipR2T.losTex and gameHasStarted then
		-- Only use scissor test if not rotated (scissor doesn't work with rotation)
		if render.minimapRotation == 0 then
			-- Calculate scissor coordinates to only show the visible map portion
			local scissorL = math.floor(math.max(render.ground.view.l, render.dim.l))
			local scissorR = math.ceil(math.min(render.ground.view.r, render.dim.r))
			local scissorB = math.floor(math.max(render.ground.view.b, render.dim.b))
			local scissorT = math.ceil(math.min(render.ground.view.t, render.dim.t))

			if scissorR > scissorL and scissorT > scissorB then
				-- Enable scissor test to clip to visible map area
				gl.Scissor(scissorL, scissorB, scissorR - scissorL, scissorT - scissorB)
			end
		end

		-- Draw LOS texture using engine-like reverse-subtract blending
		-- result_rgb = dst_rgb - src_rgb (subtractive darkening, like engine's additive-bias)
		-- result_alpha = dst_alpha (preserve FBO alpha)
		gl.BlendEquationSeparate(GL.FUNC_REVERSE_SUBTRACT, GL.FUNC_ADD)
		gl.BlendFuncSeparate(GL.ONE, GL.ONE, GL.ZERO, GL.ONE)
		glFunc.Color(1, 1, 1, 0)
		glFunc.Texture(pipR2T.losTex)

		-- Draw full-screen quad with map texture coordinates
		glFunc.BeginEnd(GL.QUADS, function()
			glFunc.TexCoord(render.ground.coord.l, render.ground.coord.b); glFunc.Vertex(render.ground.view.l, render.ground.view.b)
			glFunc.TexCoord(render.ground.coord.r, render.ground.coord.b); glFunc.Vertex(render.ground.view.r, render.ground.view.b)
			glFunc.TexCoord(render.ground.coord.r, render.ground.coord.t); glFunc.Vertex(render.ground.view.r, render.ground.view.t)
			glFunc.TexCoord(render.ground.coord.l, render.ground.coord.t); glFunc.Vertex(render.ground.view.l, render.ground.view.t)
		end)

		glFunc.Texture(false)
		-- Restore normal blend equation and separate alpha blend for R2T FBOs
		gl.BlendEquation(GL.FUNC_ADD)
		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
		gl.BlendFuncSeparate(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA, GL.ONE, GL.ONE_MINUS_SRC_ALPHA)
		
		if render.minimapRotation == 0 then
			gl.Scissor(false)  -- Disable scissor test
		end
	end
end

-- Helper function to draw map markers with rotating rectangles
local function DrawMapMarkers()
	if #miscState.mapMarkers == 0 then
		return
	end
	
	-- Check if LOS view is limited and get the visible allyteam
	local shouldShowLOS, losAllyTeam = ShouldShowLOS()
	local filterByAllyTeam = shouldShowLOS and losAllyTeam ~= nil
	
	local currentTime = os.clock()
	local resScale = render.contentScale or 1
	local lineSize = math.floor(4 * render.widgetScale * resScale)
	-- Scale baseSize based on zoom level (more zoomed out = slightly smaller markers)
	local zoomScale = 0.45 + (cameraState.zoom * 0.66)  -- Scale between 0.7 and 1.0
	local baseSize = 45 * render.widgetScale * zoomScale * resScale
				
	glFunc.Texture(false)
	
	-- Remove expired markers and draw active ones
	local i = 1
	local n = #miscState.mapMarkers
	while i <= n do
		local marker = miscState.mapMarkers[i]
		local age = currentTime - marker.time
		
		if age > 4 or (marker.fadeStart and (currentTime - marker.fadeStart) > 0.4) then
			miscState.mapMarkers[i] = miscState.mapMarkers[n]
			miscState.mapMarkers[n] = nil
			n = n - 1
		else
			-- Filter markers by allyteam if LOS view is limited
			local shouldDraw = true
			if filterByAllyTeam and marker.teamID then
				local markerAllyTeam = Spring.GetTeamAllyTeamID(marker.teamID)
				shouldDraw = (markerAllyTeam == losAllyTeam)
			end
			
			if shouldDraw then
				-- Draw marker if it's within the visible area (with margin for edge visibility)
				local sx, sy = WorldToPipCoords(marker.x, marker.z)
				
				-- Expand bounds check to include margin outside the PIP for edge markers
				local edgeMargin = (baseSize*1.25) * render.widgetScale
				if sx >= render.dim.l - edgeMargin and sx <= render.dim.r + edgeMargin and sy >= render.dim.b - edgeMargin and sy <= render.dim.t + edgeMargin then
				-- Calculate rotation based on time (rotate at 180 degrees per second)
				local rotation = (age * 180) % 360
				
				-- Size animation: elastic burst → bouncy settle → shrink to zero
				-- Uses damped oscillation with V-shaped valleys for instant bounce-back
				local sizeScale
				if age < 2.8 then
					-- Damped spring with |cos| waveform: smooth peaks, V-shaped valleys
					-- Valleys are angular (derivative discontinuity) so marker snaps back immediately
					local A = 12
					local decay = 2.5
					local freq = 1.5
					local wave = 1.5 * math.abs(math.cos(freq * age)) - 1
					sizeScale = 1 + A * math.exp(-decay * age) * wave
					if sizeScale < 0.15 then sizeScale = 0.15 end
				else
					-- Shrink to zero: 1.0x → 0 over remaining 1.2s
					local t = (age - 2.8) / 1.2
					sizeScale = math.max(0, 1.0 * (1 - t * t))  -- quadratic ease-in
				end
				local size = baseSize * sizeScale
				
				-- Fade out: start fading earlier, slightly faster
				local alpha
				if marker.fadeStart then
					local fadeDur = 0.4
					local fadeAge = currentTime - marker.fadeStart
					alpha = math.max(0, 1 - fadeAge / fadeDur)
				else
					alpha = age < 2.2 and 1 or math.max(0, 1 - (age - 2.2) / 1.8)
				end
				
				-- Use team color, white for spectators, or default yellow
				local r, g, b = 1, 1, 0  -- Default yellow
				if marker.isSpectator then
					r, g, b = 1, 1, 1  -- White for spectators
				elseif marker.teamID then
					r, g, b = Spring.GetTeamColor(marker.teamID)
				end
				
				-- Draw rotating rectangle
				glFunc.PushMatrix()
				glFunc.Translate(sx, sy, 0)
				glFunc.Rotate(rotation, 0, 0, 1)

				-- background
				glFunc.Color(0, 0, 0, alpha * 0.5)
				glFunc.LineWidth(lineSize+2.5)
				gl.BeginEnd(GL.LINE_LOOP, function()
					glFunc.Vertex(-size, -size)
					glFunc.Vertex(size, -size)
					glFunc.Vertex(size, size)
					glFunc.Vertex(-size, size)
				end)
				-- colored
				glFunc.Color(r*1.15, g*1.15, b*1.15, alpha)
				glFunc.LineWidth(lineSize)
				gl.BeginEnd(GL.LINE_LOOP, function()
					glFunc.Vertex(-size, -size)
					glFunc.Vertex(size, -size)
					glFunc.Vertex(size, size)
					glFunc.Vertex(-size, size)
				end)
				
				glFunc.PopMatrix()
			end
			end  -- end if shouldDraw
			
			i = i + 1
		end
	end
	
	glFunc.LineWidth(1.0)
	glFunc.Color(1, 1, 1, 1)
end

-- Draw build cursor inside rotation matrix
-- Draw build cursor with rotation applied as overlay
local function DrawBuildCursorWithRotation()
	local mx, my = spFunc.GetMouseState()

	-- Check if mouse is over PIP (using actual screen coordinates)
	if mx < render.dim.l or mx > render.dim.r or my < render.dim.b or my > render.dim.t then
		return
	end

	-- Get active command
	local _, cmdID = Spring.GetActiveCommand()
	if not cmdID or cmdID >= 0 then
		return
	end

	-- Check if it's a build command
	local buildDefID = -cmdID
	local uDef = UnitDefs[buildDefID]
	if not uDef then
		return
	end

	-- Apply rotation transform manually
	if render.minimapRotation ~= 0 then
		local centerX = render.dim.l + (render.dim.r - render.dim.l) / 2
		local centerY = render.dim.b + (render.dim.t - render.dim.b) / 2
		glFunc.PushMatrix()
		glFunc.Translate(centerX, centerY, 0)
		glFunc.Rotate(render.minimapRotation * 180 / math.pi, 0, 0, 1)
		glFunc.Translate(-centerX, -centerY, 0)
	end

	-- Get world position under cursor
	local wx, wz = PipToWorldCoords(mx, my)

	-- Snap to build grid
	local gridSize = 16
	wx = math.floor(wx / gridSize + 0.5) * gridSize
	wz = math.floor(wz / gridSize + 0.5) * gridSize

	local wy = spFunc.GetGroundHeight(wx, wz)
	local buildFacing = Spring.GetBuildFacing()
	local buildTest = Spring.TestBuildOrder(buildDefID, wx, wy, wz, buildFacing)
	local canBuild = (buildTest and buildTest > 0)

	-- Draw unit icon
	if cache.unitIcon[buildDefID] then
		local iconData = cache.unitIcon[buildDefID]
		local texture = iconData.bitmap
		-- Engine-matching icon size (same as GL4DrawIcons/DrawIcons)
		local resScale = render.contentScale or 1
		local unitBaseSize = Spring.GetConfigFloat("MinimapIconScale", 3.5)
		local iconSize = unitBaseSize * (mapInfo.mapSizeX * mapInfo.mapSizeZ / 40000) ^ 0.25 * math.sqrt(cameraState.zoom) * resScale * iconData.size
		local sx, sy = WorldToPipCoords(wx, wz)

		-- Counter-rotate icon to keep it upright
		glFunc.PushMatrix()
		glFunc.Translate(sx, sy, 0)
		if render.minimapRotation ~= 0 then
			glFunc.Rotate(-render.minimapRotation * 180 / math.pi, 0, 0, 1)
		end
		glFunc.Texture(texture)
		glFunc.Color(1, 1, 1, 0.7)
		glFunc.BeginEnd(glConst.QUADS, function()
			glFunc.TexCoord(0, 0)
			glFunc.Vertex(-iconSize, -iconSize)
			glFunc.TexCoord(1, 0)
			glFunc.Vertex(iconSize, -iconSize)
			glFunc.TexCoord(1, 1)
			glFunc.Vertex(iconSize, iconSize)
			glFunc.TexCoord(0, 1)
			glFunc.Vertex(-iconSize, iconSize)
		end)
		glFunc.Texture(false)
		glFunc.PopMatrix()
	end

	-- Draw placement grid
	local xsize = uDef.xsize * 4
	local zsize = uDef.zsize * 4
	if buildFacing == 1 or buildFacing == 3 then
		xsize, zsize = zsize, xsize
	end

	local halfX, halfZ = xsize, zsize
	local gridLeft, gridRight = wx - halfX, wx + halfX
	local gridTop, gridBottom = wz - halfZ, wz + halfZ
	local cellSize = 16

	glFunc.Texture(false)
	local gridColor = canBuild and {0.3, 1.0, 0.3, 0.3} or {1.0, 0.3, 0.3, 0.3}
	glFunc.Color(gridColor[1], gridColor[2], gridColor[3], gridColor[4])

	-- Draw filled grid cells
	for gx = gridLeft, gridRight - cellSize, cellSize do
		for gz = gridTop, gridBottom - cellSize, cellSize do
			local x1, y1 = WorldToPipCoords(gx, gz)
			local x2, y2 = WorldToPipCoords(gx + cellSize, gz + cellSize)
			if x2 >= render.dim.l and x1 <= render.dim.r and y2 >= render.dim.b and y1 <= render.dim.t then
				glFunc.BeginEnd(glConst.QUADS, function()
					glFunc.Vertex(x1, y1)
					glFunc.Vertex(x2, y1)
					glFunc.Vertex(x2, y2)
					glFunc.Vertex(x1, y2)
				end)
			end
		end
	end

	-- Draw grid lines
	local lineColor = canBuild and {0.5, 1.0, 0.5, 0.9} or {1.0, 0.5, 0.5, 0.9}
	glFunc.Color(lineColor[1], lineColor[2], lineColor[3], lineColor[4])
	glFunc.LineWidth(1.5)

	for gx = gridLeft, gridRight, cellSize do
		local x1, y1 = WorldToPipCoords(gx, gridTop)
		local x2, y2 = WorldToPipCoords(gx, gridBottom)
		if x1 >= render.dim.l and x1 <= render.dim.r then
			glFunc.BeginEnd(GL.LINES, function()
				glFunc.Vertex(x1, y1)
				glFunc.Vertex(x2, y2)
			end)
		end
	end

	for gz = gridTop, gridBottom, cellSize do
		local x1, y1 = WorldToPipCoords(gridLeft, gz)
		local x2, y2 = WorldToPipCoords(gridRight, gz)
		if y1 >= render.dim.b and y1 <= render.dim.t then
			glFunc.BeginEnd(GL.LINES, function()
				glFunc.Vertex(x1, y1)
				glFunc.Vertex(x2, y2)
			end)
		end
	end

	glFunc.LineWidth(1.0)
	glFunc.Color(1, 1, 1, 1)
	
	-- Pop rotation matrix
	if render.minimapRotation ~= 0 then
		glFunc.PopMatrix()
	end
end

-- Draw the main camera's view boundaries on the PIP (for minimap mode)
local function DrawCameraViewBounds()
	-- Only draw in minimap mode when not tracking a player camera and not in TV mode
	-- TV mode has its own auto-camera, so showing the main camera viewport is misleading
	if not isMinimapMode or interactionState.trackingPlayerID or miscState.tvEnabled then
		return
	end
	
	-- Get screen dimensions
	local vsx, vsy = Spring.GetViewGeometry()
	
	-- Get camera position for ray origin
	local camX, camY, camZ = Spring.GetCameraPosition()
	
	-- Get camera look-at ground height for a flat reference plane
	-- Use ground height at the camera's XZ position (clamped to map) for a reasonable estimate
	local lookX = math.max(0, math.min(camX, Game.mapSizeX))
	local lookZ = math.max(0, math.min(camZ, Game.mapSizeZ))
	local groundY = spFunc.GetGroundHeight(lookX, lookZ) or 0
	if groundY < 0 then groundY = 0 end
	
	-- Helper function to intersect a screen pixel ray with a flat plane at groundY
	-- Gives correct scale without terrain-induced skewing, works off-map
	local function screenToGround(sx, sy)
		local dirX, dirY, dirZ = Spring.GetPixelDir(sx, sy)
		
		if dirY >= 0 then
			local farDist = 50000
			return camX + dirX * farDist, camZ + dirZ * farDist
		end
		
		local t = -(camY - groundY) / dirY
		if t < 0 then
			local farDist = 50000
			return camX + dirX * farDist, camZ + dirZ * farDist
		end
		
		return camX + dirX * t, camZ + dirZ * t
	end
	
	-- Use inset from edges to avoid issues at exact corners
	local inset = 1
	
	-- Get world coordinates for all 4 screen corners by tracing against terrain
	local bottomLeftX, bottomLeftZ = screenToGround(inset, inset)
	local bottomRightX, bottomRightZ = screenToGround(vsx - inset, inset)
	local topRightX, topRightZ = screenToGround(vsx - inset, vsy - inset)
	local topLeftX, topLeftZ = screenToGround(inset, vsy - inset)
	
	-- Don't clamp to map bounds - let the view representation extend off the map
	-- This fixes the "sticking to edges" issue
	
	-- Convert to pip coordinates (no clamping, preserve true perspective shape)
	-- Note: World Z maps to pip Y inversely (high Z = low Y in pip view)
	-- Round to nearest pixel to eliminate sub-pixel jitter when the camera moves
	local bl_x, bl_y = WorldToPipCoords(bottomLeftX, bottomLeftZ)
	local br_x, br_y = WorldToPipCoords(bottomRightX, bottomRightZ)
	local tr_x, tr_y = WorldToPipCoords(topRightX, topRightZ)
	local tl_x, tl_y = WorldToPipCoords(topLeftX, topLeftZ)
	bl_x = math.floor(bl_x + 0.5);  bl_y = math.floor(bl_y + 0.5)
	br_x = math.floor(br_x + 0.5);  br_y = math.floor(br_y + 0.5)
	tr_x = math.floor(tr_x + 0.5);  tr_y = math.floor(tr_y + 0.5)
	tl_x = math.floor(tl_x + 0.5);  tl_y = math.floor(tl_y + 0.5)
	
	-- Calculate chamfer size (4 pixels at 1080p, scaled by resolution)
	local resScale = render.contentScale or 1
	local chamfer = 2 * (render.vsy / 1080) * resScale
	
	-- Clamp chamfer so it never exceeds 5% of any edge length
	local edgeBL_BR = math.sqrt((br_x-bl_x)^2 + (br_y-bl_y)^2)
	local edgeBR_TR = math.sqrt((tr_x-br_x)^2 + (tr_y-br_y)^2)
	local edgeTR_TL = math.sqrt((tl_x-tr_x)^2 + (tl_y-tr_y)^2)
	local edgeTL_BL = math.sqrt((bl_x-tl_x)^2 + (bl_y-tl_y)^2)
	local minEdge = math.min(edgeBL_BR, edgeBR_TR, edgeTR_TL, edgeTL_BL)
	chamfer = math.min(chamfer, minEdge * 0.05)
	
	-- Calculate chamfer offsets for each corner
	-- Always apply chamfers regardless of position
	local function getChamferVertices(x1, y1, x2, y2, cornerX, cornerY)
		-- Get direction vectors from corner to adjacent points
		local dx1, dy1 = x1 - cornerX, y1 - cornerY
		local dx2, dy2 = x2 - cornerX, y2 - cornerY
		
		-- Normalize and scale by chamfer size
		local len1 = math.sqrt(dx1*dx1 + dy1*dy1)
		local len2 = math.sqrt(dx2*dx2 + dy2*dy2)
		
		if len1 < 0.001 or len2 < 0.001 then
			return cornerX, cornerY, cornerX, cornerY
		end
		
		-- Chamfer points along each edge from the corner
		local c1x = cornerX + (dx1 / len1) * chamfer
		local c1y = cornerY + (dy1 / len1) * chamfer
		local c2x = cornerX + (dx2 / len2) * chamfer
		local c2y = cornerY + (dy2 / len2) * chamfer
		
		return c1x, c1y, c2x, c2y
	end
	
	-- Get chamfered vertices for each corner (going clockwise from bottom-left)
	local bl_c1x, bl_c1y, bl_c2x, bl_c2y = getChamferVertices(tl_x, tl_y, br_x, br_y, bl_x, bl_y)
	local br_c1x, br_c1y, br_c2x, br_c2y = getChamferVertices(bl_x, bl_y, tr_x, tr_y, br_x, br_y)
	local tr_c1x, tr_c1y, tr_c2x, tr_c2y = getChamferVertices(br_x, br_y, tl_x, tl_y, tr_x, tr_y)
	local tl_c1x, tl_c1y, tl_c2x, tl_c2y = getChamferVertices(tr_x, tr_y, bl_x, bl_y, tl_x, tl_y)
	
	-- Draw the view trapezoid with chamfered corners (anti-aliased)
	glFunc.Texture(false)
	
	gl.UnsafeState(GL_LINE_SMOOTH, function()
		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
		
		-- Draw dark shadow outline first (thicker, behind the white line)
		glFunc.LineWidth(3 * ((vsx+1000) / 3000) * resScale)
		glFunc.Color(0, 0, 0, 0.35)
		glFunc.BeginEnd(glConst.LINE_LOOP, function()
			-- Bottom-left corner (2 vertices)
			glFunc.Vertex(bl_c1x, bl_c1y)  -- toward top-left
			glFunc.Vertex(bl_c2x, bl_c2y)  -- toward bottom-right
			-- Bottom-right corner (2 vertices)
			glFunc.Vertex(br_c1x, br_c1y)  -- toward bottom-left
			glFunc.Vertex(br_c2x, br_c2y)  -- toward top-right
			-- Top-right corner (2 vertices)
			glFunc.Vertex(tr_c1x, tr_c1y)  -- toward bottom-right
			glFunc.Vertex(tr_c2x, tr_c2y)  -- toward top-left
			-- Top-left corner (2 vertices)
			glFunc.Vertex(tl_c1x, tl_c1y)  -- toward top-right
			glFunc.Vertex(tl_c2x, tl_c2y)  -- toward bottom-left
		end)
		
		-- Draw white line on top
		glFunc.LineWidth(1.3 * ((vsx+1000) / 3000) * resScale)
		glFunc.Color(1, 1, 1, 0.8)
		glFunc.BeginEnd(glConst.LINE_LOOP, function()
			-- Bottom-left corner (2 vertices)
			glFunc.Vertex(bl_c1x, bl_c1y)
			glFunc.Vertex(bl_c2x, bl_c2y)
			-- Bottom-right corner (2 vertices)
			glFunc.Vertex(br_c1x, br_c1y)
			glFunc.Vertex(br_c2x, br_c2y)
			-- Top-right corner (2 vertices)
			glFunc.Vertex(tr_c1x, tr_c1y)
			glFunc.Vertex(tr_c2x, tr_c2y)
			-- Top-left corner (2 vertices)
			glFunc.Vertex(tl_c1x, tl_c1y)
			glFunc.Vertex(tl_c2x, tl_c2y)
		end)
	end)
	
	glFunc.LineWidth(1.0)
end


-- Update map ruler texture (must be called OUTSIDE of R2T context)
local function UpdateMapRulerTexture()
	if not gl.R2tHelper then
		return
	end
	
	-- Calculate ruler mark size
	local markSize = math.ceil(3 * (render.vsy / 2000))
	
	-- Generate cache key with rounding to avoid tiny changes triggering regeneration
	-- Round world coordinates to nearest 10 units and screen dimensions to nearest 5 pixels
	local cacheKey = string.format("%d_%d_%d_%d_%d_%d_%d_%d_%d",
		math.floor(render.world.l / 3) * 3,
		math.floor(render.world.r / 3) * 3,
		math.floor(render.world.t / 3) * 3,
		math.floor(render.world.b / 3) * 3,
		math.floor(render.dim.l / 3) * 3,
		math.floor(render.dim.r / 3) * 3,
		math.floor(render.dim.b / 3) * 3,
		math.floor(render.dim.t / 3) * 3,
		markSize)
	
	-- Check if texture needs regeneration
	if pipR2T.rulerCacheKey ~= cacheKey then
		pipR2T.rulerNeedsUpdate = true
		pipR2T.rulerCacheKey = cacheKey
	end
	
	-- Create/update texture if needed
	if not pipR2T.rulerNeedsUpdate then
		return
	end
	
	local pipWidth = render.dim.r - render.dim.l
	local pipHeight = render.dim.t - render.dim.b
		
		if not pipR2T.rulerTex or math.floor(pipWidth) ~= pipR2T.rulerLastWidth or math.floor(pipHeight) ~= pipR2T.rulerLastHeight then
			if pipR2T.rulerTex then
				gl.DeleteTexture(pipR2T.rulerTex)
			end
			pipR2T.rulerTex = gl.CreateTexture(math.floor(pipWidth), math.floor(pipHeight), {
				target = GL.TEXTURE_2D, format = GL.RGBA, fbo = true,
			})
			pipR2T.rulerLastWidth = math.floor(pipWidth)
			pipR2T.rulerLastHeight = math.floor(pipHeight)
		end
		
		if pipR2T.rulerTex then
			gl.R2tHelper.RenderToTexture(pipR2T.rulerTex, function()
				glFunc.Translate(-1, -1, 0)
				glFunc.Scale(2 / pipWidth, 2 / pipHeight, 0)
				
				-- Create reusable mark pattern display lists if not exist or size changed
				if not render.mapRulerMarkDlists.horizontal or render.mapRulerLastMarkSize ~= markSize then
					-- Clean up old display lists
					if render.mapRulerMarkDlists.horizontal then
						for _, dlist in pairs(render.mapRulerMarkDlists.horizontal) do
							gl.DeleteList(dlist)
						end
						for _, dlist in pairs(render.mapRulerMarkDlists.vertical) do
							gl.DeleteList(dlist)
						end
					end
					
					render.mapRulerMarkDlists.horizontal = {}
					render.mapRulerMarkDlists.vertical = {}
					
					-- Create horizontal marks (top/bottom edges) - centered at origin
					for i, mult in ipairs({1, 2, 3}) do
						local length = markSize * mult
						-- Top mark (extends downward from 0)
						render.mapRulerMarkDlists.horizontal["top" .. i] = gl.CreateList(function()
							glFunc.BeginEnd(glConst.QUADS, function()
								glFunc.Vertex(-markSize/2, -length)
								glFunc.Vertex(markSize/2, -length)
								glFunc.Vertex(markSize/2, 0)
								glFunc.Vertex(-markSize/2, 0)
							end)
						end)
						-- Bottom mark (extends upward from 0)
						render.mapRulerMarkDlists.horizontal["bottom" .. i] = gl.CreateList(function()
							glFunc.BeginEnd(glConst.QUADS, function()
								glFunc.Vertex(-markSize/2, 0)
								glFunc.Vertex(markSize/2, 0)
								glFunc.Vertex(markSize/2, length)
								glFunc.Vertex(-markSize/2, length)
							end)
						end)
					end
					
					-- Create vertical marks (left/right edges) - centered at origin
					for i, mult in ipairs({1, 2, 3}) do
						local length = markSize * mult
						-- Left mark (extends rightward from 0)
						render.mapRulerMarkDlists.vertical["left" .. i] = gl.CreateList(function()
							glFunc.BeginEnd(glConst.QUADS, function()
								glFunc.Vertex(0, -markSize/2)
								glFunc.Vertex(length, -markSize/2)
								glFunc.Vertex(length, markSize/2)
								glFunc.Vertex(0, markSize/2)
							end)
						end)
						-- Right mark (extends leftward from 0)
						render.mapRulerMarkDlists.vertical["right" .. i] = gl.CreateList(function()
							glFunc.BeginEnd(glConst.QUADS, function()
								glFunc.Vertex(-length, -markSize/2)
								glFunc.Vertex(0, -markSize/2)
								glFunc.Vertex(0, markSize/2)
								glFunc.Vertex(-length, markSize/2)
							end)
						end)
					end
					
					render.mapRulerLastMarkSize = markSize
				end
				
				-- Use fixed ruler spacing
				local smallestSpacing = 64
				local mediumSpacing = smallestSpacing * 4  -- 256
				local largestSpacing = smallestSpacing * 16  -- 1024

				-- Get rotation in degrees (0-360)
				local rotDeg = 0
				if render.minimapRotation then
					rotDeg = (render.minimapRotation * 180 / math.pi) % 360
				end
				
				-- Determine which world axis maps to screen horizontal/vertical and in which direction
				-- Screen Y increases upward, world Z increases downward (south)
				-- Screen X increases rightward, world X increases rightward (east)
				local horizWorldL, horizWorldR  -- World coords at screen left and right
				local vertWorldB, vertWorldT    -- World coords at screen bottom and top
				
				if rotDeg >= 315 or rotDeg < 45 then
					-- ~0 degrees: X horizontal (normal), Z vertical (flipped)
					horizWorldL, horizWorldR = render.world.l, render.world.r
					vertWorldB, vertWorldT = render.world.b, render.world.t
				elseif rotDeg >= 45 and rotDeg < 135 then
					-- ~90 degrees: Z horizontal, X vertical (normal)
					horizWorldL, horizWorldR = render.world.t, render.world.b
					vertWorldB, vertWorldT = render.world.l, render.world.r
				elseif rotDeg >= 135 and rotDeg < 225 then
					-- ~180 degrees: X horizontal (flipped), Z vertical (normal)
					horizWorldL, horizWorldR = render.world.r, render.world.l
					vertWorldB, vertWorldT = render.world.t, render.world.b
				else
					-- ~270 degrees: Z horizontal, X vertical (flipped)
					horizWorldL, horizWorldR = render.world.b, render.world.t
					vertWorldB, vertWorldT = render.world.r, render.world.l
				end
				
				local horizWorldRange = horizWorldR - horizWorldL
				local vertWorldRange = vertWorldT - vertWorldB
				
				-- Calculate how many pixels each spacing level would take on screen (per axis)
				local hSmallestScreenSpacing = pipWidth * (smallestSpacing / math.abs(horizWorldRange))
				local hMediumScreenSpacing = pipWidth * (mediumSpacing / math.abs(horizWorldRange))
				local hLargestScreenSpacing = pipWidth * (largestSpacing / math.abs(horizWorldRange))
				local vSmallestScreenSpacing = pipHeight * (smallestSpacing / math.abs(vertWorldRange))
				local vMediumScreenSpacing = pipHeight * (mediumSpacing / math.abs(vertWorldRange))
				local vLargestScreenSpacing = pipHeight * (largestSpacing / math.abs(vertWorldRange))

				-- Show different levels based on screen spacing (per axis)
				local hShowSmallest = hSmallestScreenSpacing >= 8
				local hShowMedium = hMediumScreenSpacing >= 8
				local hShowLargest = hLargestScreenSpacing >= 8
				local vShowSmallest = vSmallestScreenSpacing >= 8
				local vShowMedium = vMediumScreenSpacing >= 8
				local vShowLargest = vLargestScreenSpacing >= 8
				
				glFunc.Texture(false)
				glFunc.Color(1, 1, 1, 0.12)
				
				-- Draw horizontal edge marks (top/bottom of screen)
				local startH = math.ceil(math.min(horizWorldL, horizWorldR) / smallestSpacing) * smallestSpacing
				local endH = math.max(horizWorldL, horizWorldR)
				local h = startH
				while h <= endH do
					local lsx = (h - horizWorldL) / horizWorldRange * pipWidth
					if lsx >= 0 and lsx <= pipWidth then
						local is16x = (h % largestSpacing == 0)
						local is4x = (h % mediumSpacing == 0)
						
						local markType
						if is16x and hShowLargest then
							markType = 3
						elseif is4x and hShowMedium then
							markType = 2
						elseif hShowSmallest then
							markType = 1
						end
						
						if markType then
							glFunc.PushMatrix()
							glFunc.Translate(lsx, pipHeight, 0)
							glFunc.CallList(render.mapRulerMarkDlists.horizontal["top" .. markType])
							glFunc.PopMatrix()
							
							glFunc.PushMatrix()
							glFunc.Translate(lsx, 0, 0)
							glFunc.CallList(render.mapRulerMarkDlists.horizontal["bottom" .. markType])
							glFunc.PopMatrix()
						end
					end
					h = h + smallestSpacing
				end
				
				-- Draw vertical edge marks (left/right of screen)
				local startV = math.ceil(math.min(vertWorldB, vertWorldT) / smallestSpacing) * smallestSpacing
				local endV = math.max(vertWorldB, vertWorldT)
				local v = startV
				while v <= endV do
					local lsy = (v - vertWorldB) / vertWorldRange * pipHeight
					if lsy >= 0 and lsy <= pipHeight then
						local is16x = (v % largestSpacing == 0)
						local is4x = (v % mediumSpacing == 0)
						
						local markType
						if is16x and vShowLargest then
							markType = 3
						elseif is4x and vShowMedium then
							markType = 2
						elseif vShowSmallest then
							markType = 1
						end
						
						if markType then
							glFunc.PushMatrix()
							glFunc.Translate(0, lsy, 0)
							glFunc.CallList(render.mapRulerMarkDlists.vertical["left" .. markType])
							glFunc.PopMatrix()
							
							glFunc.PushMatrix()
							glFunc.Translate(pipWidth, lsy, 0)
							glFunc.CallList(render.mapRulerMarkDlists.vertical["right" .. markType])
							glFunc.PopMatrix()
						end
					end
					v = v + smallestSpacing
				end
				
				glFunc.Color(1, 1, 1, 1)
			end, true)
			
			pipR2T.rulerNeedsUpdate = false
		end
end

-- Blit the cached map ruler texture (called inside RenderPipContents)
local function BlitMapRuler()
	if pipR2T.rulerTex and gl.R2tHelper then
		gl.R2tHelper.BlendTexRect(pipR2T.rulerTex, render.dim.l, render.dim.b, render.dim.r, render.dim.t, true)
	end
end

-- Helper for drawing a textured quad — passed as callback to gl.BeginEnd to avoid closure allocation
local function DrawTexturedQuad(qL, qB, qR, qT)
	glFunc.TexCoord(0, 0)
	glFunc.Vertex(qL, qB)
	glFunc.TexCoord(1, 0)
	glFunc.Vertex(qR, qB)
	glFunc.TexCoord(1, 1)
	glFunc.Vertex(qR, qT)
	glFunc.TexCoord(0, 1)
	glFunc.Vertex(qL, qT)
end

-- Blit an oversized R2T texture to screen with smooth camera UV-shift and zoom scaling.
-- The texture was rendered centered at (storedWcx, storedWcz) with storedZoom and storedRotation.
-- The blit positions the oversized quad so the current camera view aligns correctly through the stencil mask.
-- Stencil must already be set up to clip to PIP bounds.
local function BlitShiftedTexture(tex, texWidth, texHeight, storedWcx, storedWcz, storedZoom, storedRotation)
	if not tex then return end

	local resScale = config.contentResolutionScale

	-- Camera offset since texture was rendered
	local dx = cameraState.wcx - storedWcx
	local dz = cameraState.wcz - storedWcz

	-- Screen-space shift (pre-rotation):
	--   Camera right (dx>0) → content shifts left → negative X
	--   Camera south (dz>0) → content shifts up   → positive Y  (world Z+ = screen Y-)
	local preShiftX = -dx * cameraState.zoom
	local preShiftY = dz * cameraState.zoom

	-- Rotate shift to match the rotation baked into the texture
	local cosA = math.cos(storedRotation)
	local sinA = math.sin(storedRotation)
	local shiftX = preShiftX * cosA - preShiftY * sinA
	local shiftY = preShiftX * sinA + preShiftY * cosA

	-- Zoom scaling: texture was rendered at storedZoom, display at current zoom
	local zoomRatio = storedZoom ~= 0 and (cameraState.zoom / storedZoom) or 1

	-- PIP center in screen coordinates
	local cx = (render.dim.l + render.dim.r) * 0.5
	local cy = (render.dim.b + render.dim.t) * 0.5

	-- Quad size: oversized texture mapped to screen pixels, scaled by zoom ratio
	local halfW = texWidth * zoomRatio / (2 * resScale)
	local halfH = texHeight * zoomRatio / (2 * resScale)

	-- Quad position (centered on PIP + camera shift)
	local qL = cx - halfW + shiftX
	local qB = cy - halfH + shiftY
	local qR = cx + halfW + shiftX
	local qT = cy + halfH + shiftY

	-- Draw textured quad (stencil clips to PIP bounds)
	glFunc.Texture(tex)
	glFunc.BeginEnd(glConst.QUADS, DrawTexturedQuad, qL, qB, qR, qT)
	glFunc.Texture(false)
end

-- Render only the cheap/lightweight layers (ground texture, water, LOS overlay)
-- Called inside R2T context with rotation matrix already set up
local function RenderCheapLayers()
	-- Apply rotation to content if minimap is rotated
	if render.minimapRotation ~= 0 then
		local centerX = render.dim.l + (render.dim.r - render.dim.l) / 2
		local centerY = render.dim.b + (render.dim.t - render.dim.b) / 2
		glFunc.PushMatrix()
		glFunc.Translate(centerX, centerY, 0)
		glFunc.Rotate(render.minimapRotation * 180 / math.pi, 0, 0, 1)
		glFunc.Translate(-centerX, -centerY, 0)
	end

	if uiState.drawingGround then
		-- Draw ground minimap with shading in single pass (matches engine compositing)
		glFunc.Color(1, 1, 1, 1)
		if shaders.minimapShading then
			gl.UseShader(shaders.minimapShading)
			glFunc.Texture(0, '$minimap')
			glFunc.Texture(1, '$shading')
			glFunc.BeginEnd(glConst.QUADS, GroundTextureVertices)
			glFunc.Texture(0, false)
			glFunc.Texture(1, false)
			gl.UseShader(0)
		else
			glFunc.Texture('$minimap')
			glFunc.BeginEnd(glConst.QUADS, GroundTextureVertices)
			glFunc.Texture(false)
		end

		-- Draw water and LOS overlays
		DrawWaterAndLOSOverlays()
	end

	-- Draw ground decals on top of ground/water/LOS (multiply-blends against ground color)
	DrawDecalsOverlay()

	-- Pop rotation matrix if it was applied
	if render.minimapRotation ~= 0 then
		glFunc.PopMatrix()
	end
end

-- Render the expensive layers (units, features, projectiles, commands, markers, camera bounds)
-- Called inside R2T context for the oversized unitsTex
local function RenderExpensiveLayers()
	local cachedSelectedUnits = Spring.GetSelectedUnits()

	-- Apply rotation to all content if minimap is rotated
	if render.minimapRotation ~= 0 then
		local centerX = render.dim.l + (render.dim.r - render.dim.l) / 2
		local centerY = render.dim.b + (render.dim.t - render.dim.b) / 2
		glFunc.PushMatrix()
		glFunc.Translate(centerX, centerY, 0)
		glFunc.Rotate(render.minimapRotation * 180 / math.pi, 0, 0, 1)
		glFunc.Translate(-centerX, -centerY, 0)
	end

	-- Measure draw time for performance monitoring
	local drawStartTime = os.clock()
	DrawUnitsAndFeatures(cachedSelectedUnits)
	pipR2T.contentLastDrawTime = os.clock() - drawStartTime

	DrawCommandQueuesOverlay(cachedSelectedUnits)
	DrawCommandFXOverlay()

	-- Pop rotation matrix if it was applied
	if render.minimapRotation ~= 0 then
		glFunc.PopMatrix()
	end
end

-- Full render for fallback when unitsTex is not available
local function RenderPipContents()
	-- Cache selected units once per render cycle to avoid multiple API calls
	local cachedSelectedUnits = Spring.GetSelectedUnits()
	
	-- Apply rotation to all content if minimap is rotated
	if render.minimapRotation ~= 0 then
		local centerX = render.dim.l + (render.dim.r - render.dim.l) / 2
		local centerY = render.dim.b + (render.dim.t - render.dim.b) / 2
		glFunc.PushMatrix()
		glFunc.Translate(centerX, centerY, 0)
		glFunc.Rotate(render.minimapRotation * 180 / math.pi, 0, 0, 1)
		glFunc.Translate(-centerX, -centerY, 0)
	end
	
	if uiState.drawingGround then
		-- Draw ground minimap with shading in single pass (matches engine compositing)
		glFunc.Color(1, 1, 1, 1)
		if shaders.minimapShading then
			gl.UseShader(shaders.minimapShading)
			glFunc.Texture(0, '$minimap')
			glFunc.Texture(1, '$shading')
			glFunc.BeginEnd(glConst.QUADS, GroundTextureVertices)
			glFunc.Texture(0, false)
			glFunc.Texture(1, false)
			gl.UseShader(0)
		else
			glFunc.Texture('$minimap')
			glFunc.BeginEnd(glConst.QUADS, GroundTextureVertices)
			glFunc.Texture(false)
		end
		
		-- Draw water and LOS overlays
		DrawWaterAndLOSOverlays()
	end

	-- Draw ground decals (before units so they appear below)
	DrawDecalsOverlay()

	-- Measure draw time for performance monitoring
	local drawStartTime = os.clock()
	DrawUnitsAndFeatures(cachedSelectedUnits)
	pipR2T.contentLastDrawTime = os.clock() - drawStartTime

	DrawCommandQueuesOverlay(cachedSelectedUnits)
	DrawCommandFXOverlay()
	
	-- Pop rotation matrix if it was applied
	if render.minimapRotation ~= 0 then
		glFunc.PopMatrix()
	end
	
	-- Blit map ruler AFTER rotation pop so marks stay at screen edges
	-- The ruler texture already maps world coordinates for the current rotation angle
	if uiState.drawingGround and config.showMapRuler then
		local _, _, spec = spFunc.GetPlayerInfo(Spring.GetMyPlayerID(), false)
		if not spec then
			BlitMapRuler()
		end
	end
	
	-- NOTE: DrawInMiniMap overlays are now rendered in DrawScreen after the R2T is blitted,
	-- because matrix manipulation doesn't work correctly inside the R2T context.
end

-- Helper function to draw box selection rectangle
local function DrawBoxSelection()
	if not interactionState.areBoxSelecting then
		return
	end

	-- Don't draw box selection when tracking a player's camera
	if interactionState.trackingPlayerID then
		return
	end

	-- Don't draw box selection when tracking a player's camera
	if interactionState.trackingPlayerID then
		return
	end

	local minX = math.max(math.min(interactionState.boxSelectStartX, interactionState.boxSelectEndX), render.dim.l)
	local maxX = math.min(math.max(interactionState.boxSelectStartX, interactionState.boxSelectEndX), render.dim.r)
	local minY = math.max(math.min(interactionState.boxSelectStartY, interactionState.boxSelectEndY), render.dim.b)
	local maxY = math.min(math.max(interactionState.boxSelectStartY, interactionState.boxSelectEndY), render.dim.t)

	-- Check if selectionbox widget is enabled
	local selectionboxEnabled = widgetHandler:IsWidgetKnown("Selectionbox") and (widgetHandler.orderList["Selectionbox"] and widgetHandler.knownWidgets["Selectionbox"].active)

	-- Get modifier key states (ignoring alt as requested)
	local alt, ctrl, meta, shift = Spring.GetModKeyState()

	-- Determine background color based on modifier keys (only if selectionbox widget is enabled)
	local bgAlpha = 0.03
	if selectionboxEnabled and ctrl then
		-- Red background when ctrl is held
		glFunc.Color(1, 0.25, 0.25, bgAlpha)
	elseif selectionboxEnabled and shift then
		-- Green background when shift is held
		glFunc.Color(0.45, 1, 0.45, bgAlpha)
	else
		-- White background for normal selection
		glFunc.Color(1, 1, 1, bgAlpha * 0.8)
	end

	glFunc.Texture(false)
	glFunc.BeginEnd(glConst.QUADS, function()
		glFunc.Vertex(minX, minY)
		glFunc.Vertex(maxX, minY)
		glFunc.Vertex(maxX, maxY)
		glFunc.Vertex(minX, maxY)
	end)

	gl.PolygonMode(GL.FRONT_AND_BACK, GL.LINE)
	glFunc.LineWidth(2.0 + 2.5)
	glFunc.Color(0, 0, 0, 0.12)
	glFunc.BeginEnd(glConst.QUADS, function()
	glFunc.Vertex(minX, minY)
		glFunc.Vertex(maxX, minY)
		glFunc.Vertex(maxX, maxY)
		glFunc.Vertex(minX, maxY)
	end)

	-- Use stipple line only if selectionbox widget is enabled, otherwise use normal line
	if selectionboxEnabled then
		gl.LineStipple(true)
	end
	glFunc.LineWidth(2.0)

	-- Determine line color based on modifier keys (only if selectionbox widget is enabled)
	if selectionboxEnabled and ctrl then
		-- Bright red when ctrl is held
		glFunc.Color(1, 0.82, 0.82, 1)
	elseif selectionboxEnabled and shift then
		-- Bright green when shift is held
		glFunc.Color(0.92, 1, 0.92, 1)
	else
		-- White for normal selection
		glFunc.Color(1, 1, 1, 1)
	end

	glFunc.BeginEnd(glConst.QUADS, function()
		glFunc.Vertex(minX, minY)
		glFunc.Vertex(maxX, minY)
		glFunc.Vertex(maxX, maxY)
		glFunc.Vertex(minX, maxY)
	end)
	gl.PolygonMode(GL.FRONT_AND_BACK, GL.FILL)
	if selectionboxEnabled then
		gl.LineStipple(false)
	end
	glFunc.LineWidth(1.0)
end

local function DrawAreaCommand()
	if not interactionState.areAreaDragging then
		return
	end

	local mx, my = spFunc.GetMouseState()
	local _, cmdID = Spring.GetActiveCommand()
	if not cmdID or cmdID <= 0 then
		return
	end

	-- Calculate center and current mouse position in screen coordinates
	local centerX = interactionState.areaCommandStartX
	local centerY = interactionState.areaCommandStartY

	-- Calculate radius in screen space (pixels)
	local dx = mx - centerX
	local dy = my - centerY
	local radius = math.sqrt(dx * dx + dy * dy)

	-- Only draw if dragged more than 5 pixels
	if radius < 5 then
		return
	end

	-- Get command color
	local color = cmdColors[cmdID] or cmdColors.unknown

	-- Draw filled circle with command color using additive blending
	glFunc.Texture(false)
	gl.Blending(GL.SRC_ALPHA, GL.ONE)

	-- Enable scissor test to clamp drawing to PIP bounds
	gl.Scissor(render.dim.l, render.dim.b, render.dim.r - render.dim.l, render.dim.t - render.dim.b)

	-- Draw filled circle with vibrant colors
	glFunc.Color(color[1], color[2], color[3], 0.25)
	local segments = math.max(16, math.min(64, math.floor(radius / 3)))
	glFunc.BeginEnd(GL.TRIANGLE_FAN, function()
		glFunc.Vertex(centerX, centerY)
		for i = 0, segments do
			local angle = (i / segments) * 2 * math.pi
			local x = centerX + math.cos(angle) * radius
			local y = centerY + math.sin(angle) * radius
			glFunc.Vertex(x, y)
		end
	end)

	-- Disable scissor test

	-- Reset
	gl.Scissor(false)
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	glFunc.Color(1, 1, 1, 1)
end

-- Draw build cursor (icon and placement grid) when holding a build command
local function DrawBuildCursor()
	local mx, my = spFunc.GetMouseState()

	-- Check if mouse is over PIP
	if mx < render.dim.l or mx > render.dim.r or my < render.dim.b or my > render.dim.t then
		return
	end

	-- Get active command
	local _, cmdID = Spring.GetActiveCommand()
	if not cmdID or cmdID >= 0 then
		return
	end

	-- Check if it's a build command
	local buildDefID = -cmdID
	local uDef = UnitDefs[buildDefID]
	if not uDef then
		return
	end

	-- Get world position under cursor
	local wx, wz = PipToWorldCoords(mx, my)

	-- Snap to build grid (16 elmos per cell, buildings snap to this grid)
	local gridSize = 16
	wx = math.floor(wx / gridSize + 0.5) * gridSize
	wz = math.floor(wz / gridSize + 0.5) * gridSize

	local wy = spFunc.GetGroundHeight(wx, wz)

	-- Get build facing
	local buildFacing = Spring.GetBuildFacing()

	-- Test if building can be placed here (returns 0 if not buildable, or a positive value if buildable)
	local buildTest = Spring.TestBuildOrder(buildDefID, wx, wy, wz, buildFacing)
	local canBuild = (buildTest and buildTest > 0)

	-- Draw unit icon at cursor position with 0.7 opacity
	if cache.unitIcon[buildDefID] then
		local iconData = cache.unitIcon[buildDefID]
		local texture = iconData.bitmap

		-- Engine-matching icon size (same as GL4DrawIcons/DrawIcons)
		local resScale = render.contentScale or 1
		local unitBaseSize = Spring.GetConfigFloat("MinimapIconScale", 3.5)
		local iconSize = unitBaseSize * (mapInfo.mapSizeX * mapInfo.mapSizeZ / 40000) ^ 0.25 * math.sqrt(cameraState.zoom) * resScale * iconData.size

		local sx, sy = WorldToPipCoords(wx, wz)

		glFunc.Texture(texture)
		glFunc.Color(1, 1, 1, 0.7)
		glFunc.TexRect(sx - iconSize, sy - iconSize, sx + iconSize, sy + iconSize)
		glFunc.Texture(false)
	end

	-- Draw placement grid
	local xsize = uDef.xsize * 4  -- Convert to elmos (each cell is 8 elmos)
	local zsize = uDef.zsize * 4

	-- Adjust for build facing (swap dimensions if rotated 90/270 degrees)
	if buildFacing == 1 or buildFacing == 3 then
		xsize, zsize = zsize, xsize
	end

	-- Calculate grid corners in world space
	local halfX = xsize
	local halfZ = zsize
	local gridLeft = wx - halfX
	local gridRight = wx + halfX
	local gridTop = wz - halfZ
	local gridBottom = wz + halfZ

	-- Draw grid cells
	local cellSize = 16  -- Each grid cell is 16 elmos (snap grid size)

	glFunc.Texture(false)

	-- We can't test individual cells, so use the overall buildability for the entire grid
	-- The grid shows if the building footprint as a whole can be placed
	local gridColor = canBuild and {0.3, 1.0, 0.3, 0.3} or {1.0, 0.3, 0.3, 0.3}
	glFunc.Color(gridColor[1], gridColor[2], gridColor[3], gridColor[4])

	-- Draw filled grid cells
	for gx = gridLeft, gridRight - cellSize, cellSize do
		for gz = gridTop, gridBottom - cellSize, cellSize do
			local x1, y1 = WorldToPipCoords(gx, gz)
			local x2, y2 = WorldToPipCoords(gx + cellSize, gz + cellSize)

			-- Only draw if within PIP bounds
			if x2 >= render.dim.l and x1 <= render.dim.r and y2 >= render.dim.b and y1 <= render.dim.t then
				glFunc.BeginEnd(glConst.QUADS, function()
					glFunc.Vertex(x1, y1)
					glFunc.Vertex(x2, y1)
					glFunc.Vertex(x2, y2)
					glFunc.Vertex(x1, y2)
				end)
			end
		end
	end

	-- Draw grid lines with color based on overall buildability
	local lineColor = canBuild and {0.5, 1.0, 0.5, 0.9} or {1.0, 0.5, 0.5, 0.9}
	glFunc.Color(lineColor[1], lineColor[2], lineColor[3], lineColor[4])
	glFunc.LineWidth(1.5)

	-- Vertical lines
	for gx = gridLeft, gridRight, cellSize do
		local x1, y1 = WorldToPipCoords(gx, gridTop)
		local x2, y2 = WorldToPipCoords(gx, gridBottom)
		if x1 >= render.dim.l and x1 <= render.dim.r then
			glFunc.BeginEnd(glConst.LINES, function()
				glFunc.Vertex(x1, math.max(y1, render.dim.b))
				glFunc.Vertex(x2, math.min(y2, render.dim.t))
			end)
		end
	end

	-- Horizontal lines
	for gz = gridTop, gridBottom, cellSize do
		local x1, y1 = WorldToPipCoords(gridLeft, gz)
		local x2, y2 = WorldToPipCoords(gridRight, gz)
		if y1 >= render.dim.b and y1 <= render.dim.t then
			glFunc.BeginEnd(glConst.LINES, function()
				glFunc.Vertex(math.max(x1, render.dim.l), y1)
				glFunc.Vertex(math.min(x2, render.dim.r), y2)
			end)
		end
	end

	glFunc.LineWidth(1.0)
	glFunc.Color(1, 1, 1, 1)
end

-- Helper function to draw tracked player name (uses cached display list)
local function DrawTrackedPlayerName()
	if not (interactionState.trackingPlayerID and interactionState.isMouseOverPip) then
		return
	end

	local playerName, active, isSpec, teamID = spFunc.GetPlayerInfo(interactionState.trackingPlayerID, false)
	if not (playerName and teamID) then
		return
	end

	-- Get display name (may be modified by playernames widget)
	if WG.playernames and WG.playernames.getPlayername then
		playerName = WG.playernames.getPlayername(interactionState.trackingPlayerID)
	end

	-- Check if we need to regenerate the display list (player changed or name changed)
	local needsUpdate = pipR2T.playerNameDlist == nil or
		pipR2T.playerNameLastPlayerID ~= interactionState.trackingPlayerID or
		pipR2T.playerNameLastName ~= playerName

	if needsUpdate then
		-- Clean up old display list
		if pipR2T.playerNameDlist then
			gl.DeleteList(pipR2T.playerNameDlist)
		end

		-- Get team color
		local r, g, b = Spring.GetTeamColor(teamID)
		local fontSize = math.floor(20 * render.widgetScale)
		local padding = math.floor(17 * render.widgetScale)
		local centerX = (render.dim.l + render.dim.r) / 2

		-- Create new display list
		pipR2T.playerNameDlist = gl.CreateList(function()
			font:Begin()
			font:SetTextColor(r, g, b, 1)
			font:SetOutlineColor(0, 0, 0, 0.8)
			font:Print(playerName, centerX, render.dim.t - padding - (fontSize * 1.6), fontSize * 2, "con")
			font:End()
		end)

		pipR2T.playerNameLastPlayerID = interactionState.trackingPlayerID
		pipR2T.playerNameLastName = playerName
	end

	-- Draw the cached display list
	if pipR2T.playerNameDlist then
		gl.CallList(pipR2T.playerNameDlist)
	end
end

-- Helper function to format resource numbers compactly
local function shortRes(n)
	if n >= 10000000 then
		return string.format("%.1fm", n / 1000000)
	elseif n >= 10000 then
		return string.format("%.1fk", n / 1000)
	elseif n >= 1000 then
		return string.format("%.0f", n)
	else
		return string.format("%.0f", n)
	end
end

-- Helper function to draw resource bars when tracking a player camera (hidden when PIP is hovered)
-- Bars update every frame, text updates at ~2 FPS via cached display list
local function DrawTrackedPlayerResourceBars()
	-- Only show when tracking a player camera AND not hovering the PIP
	if not interactionState.trackingPlayerID then
		return
	end
	if interactionState.isMouseOverPip then
		return
	end

	local playerName, active, isSpec, teamID = spFunc.GetPlayerInfo(interactionState.trackingPlayerID, false)
	if not teamID then
		return
	end

	-- Get team resources - this works for spectators viewing any team
	-- Returns: current, storage, pull, income, expense, share
	local metalCur, metalMax, metalPull, metalIncome, metalExpense, metalShare = Spring.GetTeamResources(teamID, 'metal')
	local energyCur, energyMax, energyPull, energyIncome, energyExpense, energyShare = Spring.GetTeamResources(teamID, 'energy')

	if not (metalCur and energyCur) then
		return
	end

	-- Get energy conversion level (mmLevel)
	local mmLevel = Spring.GetTeamRulesParam(teamID, 'mmLevel')
	if mmLevel == nil then mmLevel = 1 end

	-- Check if player has teammates (for share slider)
	local _, _, _, _, _, allyTeamID = Spring.GetTeamInfo(teamID, false)
	local allyTeamList = Spring.GetTeamList(allyTeamID)
	local hasTeammates = allyTeamList and #allyTeamList > 1

	-- Calculate bar dimensions - compact version at top of PIP
	local pipWidth = render.dim.r - render.dim.l
	local pipHeight = render.dim.t - render.dim.b
	local padding = math.floor(20 * render.widgetScale) * math.max(1, (render.vsx / 2700))
	local barHeight = math.floor(math.max(5, 7 * render.widgetScale)) * math.max(1, (render.vsx / 2400))
	local totalBarWidth = math.min(math.floor(pipWidth * 0.32), config.minPanelSize*0.5)  -- Each bar is 32% of PIP width
	local gapBetweenBars = math.floor(totalBarWidth * 0.28)
	
	-- Position: top of PIP, with padding from edge and corner
	local topY = render.dim.t - padding - render.elementCorner * 0.5
	local barY = topY - barHeight
	local centerX = (render.dim.l + render.dim.r) / 2
	
	-- Metal bar on left of center
	local metalBarRight = centerX - gapBetweenBars / 2
	local metalBarLeft = metalBarRight - totalBarWidth
	
	-- Energy bar on right of center
	local energyBarLeft = centerX + gapBetweenBars / 2
	local energyBarRight = energyBarLeft + totalBarWidth

	-- Calculate fill amounts
	local metalFill = math.min(1, math.max(0, metalCur / metalMax))
	local energyFill = math.min(1, math.max(0, energyCur / energyMax))

	-- Draw background boxes
	local bgAlpha = 0.6
	local cornerRadius = barHeight * 0.25
	
	glFunc.Color(0, 0, 0, bgAlpha)
	render.RectRound(metalBarLeft - 2, barY - 2, metalBarRight + 2, topY + 2, cornerRadius, 1, 1, 1, 1)
	render.RectRound(energyBarLeft - 2, barY - 2, energyBarRight + 2, topY + 2, cornerRadius, 1, 1, 1, 1)

	-- Draw metal bar fill
	if metalFill > 0.01 then
		local fillRight = metalBarLeft + (totalBarWidth * metalFill)
		glFunc.Color(0.77, 0.77, 0.77, 0.9)
		render.RectRound(metalBarLeft, barY, fillRight, topY, cornerRadius, 1, metalFill >= 0.02 and 1 or 0, metalFill >= 0.02 and 1 or 0, 1)
	end

	-- Draw energy bar fill
	if energyFill > 0.01 then
		local fillRight = energyBarLeft + (totalBarWidth * energyFill)
		glFunc.Color(1, 1, 0, 0.9)
		render.RectRound(energyBarLeft, barY, fillRight, topY, cornerRadius, 1, energyFill >= 0.02 and 1 or 0, energyFill >= 0.02 and 1 or 0, 1)
	end

	-- Draw sliders
	local sliderRadius = math.floor(barHeight * 0.55)
	local sliderY = barY + barHeight / 2

	-- Energy conversion slider (yellow, on energy bar only)
	if mmLevel and mmLevel < 0.745 and mmLevel > 0.755 then
		local convX = energyBarLeft + (totalBarWidth * mmLevel)
		glFunc.Color(0.94, 0.94, 0.66, 1)
		-- Draw slider knob as a circle
		local steps = 10
		glFunc.BeginEnd(GL.TRIANGLE_FAN, function()
			glFunc.Vertex(convX, sliderY, 0)
			for i = 0, steps do
				local angle = (i / steps) * 2 * math.pi
				glFunc.Vertex(convX + math.cos(angle) * sliderRadius, sliderY + math.sin(angle) * sliderRadius, 0)
			end
		end)
		-- Draw outline
		glFunc.Color(0, 0, 0, 0.6)
		glFunc.LineWidth(1)
		glFunc.BeginEnd(GL.LINE_LOOP, function()
			for i = 0, steps - 1 do
				local angle = (i / steps) * 2 * math.pi
				glFunc.Vertex(convX + math.cos(angle) * sliderRadius, sliderY + math.sin(angle) * sliderRadius, 0)
			end
		end)
	end

	-- Share sliders (red, only if player has teammates)
	if hasTeammates then
		-- Metal share slider
		if metalShare and metalShare < 0.98 then	-- default metalShare = 0.99
			local shareX = metalBarLeft + (totalBarWidth * metalShare)
			glFunc.Color(0.9, 0.2, 0.2, 0.9)
			local steps = 10
			glFunc.BeginEnd(GL.TRIANGLE_FAN, function()
				glFunc.Vertex(shareX, sliderY, 0)
				for i = 0, steps do
					local angle = (i / steps) * 2 * math.pi
					glFunc.Vertex(shareX + math.cos(angle) * sliderRadius, sliderY + math.sin(angle) * sliderRadius, 0)
				end
			end)
			glFunc.Color(0, 0, 0, 0.6)
			glFunc.LineWidth(1)
			glFunc.BeginEnd(GL.LINE_LOOP, function()
				for i = 0, steps - 1 do
					local angle = (i / steps) * 2 * math.pi
					glFunc.Vertex(shareX + math.cos(angle) * sliderRadius, sliderY + math.sin(angle) * sliderRadius, 0)
				end
			end)
		end

		-- Energy share slider
		if energyShare and energyShare < 0.94 or energyShare > 0.96 then -- default energyShare = 0.949999
			local shareX = energyBarLeft + (totalBarWidth * energyShare)
			glFunc.Color(0.9, 0.2, 0.2, 0.9)
			local steps = 10
			glFunc.BeginEnd(GL.TRIANGLE_FAN, function()
				glFunc.Vertex(shareX, sliderY, 0)
				for i = 0, steps do
					local angle = (i / steps) * 2 * math.pi
					glFunc.Vertex(shareX + math.cos(angle) * sliderRadius, sliderY + math.sin(angle) * sliderRadius, 0)
				end
			end)
			glFunc.Color(0, 0, 0, 0.6)
			glFunc.LineWidth(1)
			glFunc.BeginEnd(GL.LINE_LOOP, function()
				for i = 0, steps - 1 do
					local angle = (i / steps) * 2 * math.pi
					glFunc.Vertex(shareX + math.cos(angle) * sliderRadius, sliderY + math.sin(angle) * sliderRadius, 0)
				end
			end)
		end
	end

	-- Text rendering - use cached display list, update at ~2 FPS
	local currentTime = os.clock()
	local needsTextUpdate = pipR2T.resbarTextDlist == nil or
		pipR2T.resbarTextLastPlayerID ~= interactionState.trackingPlayerID or
		(currentTime - pipR2T.resbarTextLastUpdate) >= pipR2T.resbarTextUpdateRate

	if needsTextUpdate then
		-- Clean up old display list
		if pipR2T.resbarTextDlist then
			gl.DeleteList(pipR2T.resbarTextDlist)
		end

		-- Create new display list with current resource text
		local fontSize = math.floor(math.max(12, 20 * render.widgetScale)) * math.max(1, (render.vsx / 2700))
		local smallFontSize = math.floor(fontSize * 0.8)
		local textY = barY + (barHeight / 2) + smallFontSize * 0.1
		local incomeY = barY - smallFontSize * 0.65
		local metalCenterX = (metalBarLeft + metalBarRight) / 2
		local energyCenterX = (energyBarLeft + energyBarRight) / 2

		pipR2T.resbarTextDlist = gl.CreateList(function()
			font:Begin()
			font:SetOutlineColor(0, 0, 0, 1)
			
			-- Metal: current amount centered on bar
			font:SetTextColor(1, 1, 1, 1)
			font:Print(shortRes(metalCur), metalCenterX, textY, fontSize, "ocn")
			
			-- Metal: income and pull below bar
			font:SetTextColor(0.5, 1, 0.5, 1)
			font:Print("+" .. shortRes(metalIncome), metalCenterX - 4, incomeY, smallFontSize, "orn")
			font:SetTextColor(1, 0.5, 0.5, 1)
			font:Print("-" .. shortRes(metalPull), metalCenterX + 4, incomeY, smallFontSize, "oln")
			
			-- Energy: current amount centered on bar
			font:SetTextColor(1, 1, 0.7, 1)
			font:Print(shortRes(energyCur), energyCenterX, textY, fontSize, "ocn")
			
			-- Energy: income and pull below bar
			font:SetTextColor(0.5, 1, 0.5, 1)
			font:Print("+" .. shortRes(energyIncome), energyCenterX - 4, incomeY, smallFontSize, "orn")
			font:SetTextColor(1, 0.5, 0.5, 1)
			font:Print("-" .. shortRes(energyPull), energyCenterX + 4, incomeY, smallFontSize, "oln")
			
			font:End()
		end)

		pipR2T.resbarTextLastUpdate = currentTime
		pipR2T.resbarTextLastPlayerID = interactionState.trackingPlayerID
	end

	-- Draw the cached text display list
	if pipR2T.resbarTextDlist then
		gl.CallList(pipR2T.resbarTextDlist)
	end
	
	glFunc.Color(1, 1, 1, 1)
end

-- Helper function to draw a minimap overlay in PIP corner when tracking a player camera
-- Shows map with LOS overlay and a rectangle indicating the current PIP view
-- Also shown for players (not just spectators tracking others) and when hovering
local function DrawTrackedPlayerMinimap()
	-- In minimap mode, don't show the pip-minimap overlay (we ARE the minimap)
	-- Exception: when tracking a player camera or TV mode, the minimap is zoomed in so we need the overview
	if isMinimapMode and not interactionState.trackingPlayerID and not miscState.tvEnabled then
		interactionState.pipMinimapBounds = nil
		return
	end
	
	-- Show for players OR when tracking a player camera OR when hovering OR during activity focus
	local showForPlayer = not cameraState.mySpecState  -- Show for players
	local showForTracking = interactionState.trackingPlayerID ~= nil  -- Show when tracking
	local showForHover = interactionState.isMouseOverPip  -- Show when hovering
	local showForActivityFocus = config.activityFocusShowMinimap and miscState.activityFocusActive  -- Show during map marker focus
	local showForTV = miscState.tvEnabled  -- Show during TV mode
	
	if not showForPlayer and not showForTracking and not showForHover and not showForActivityFocus and not showForTV then
		interactionState.pipMinimapBounds = nil
		return
	end

	-- Get team for LOS overlay
	local teamID
	if interactionState.trackingPlayerID then
		local playerName, active, isSpec
		playerName, active, isSpec, teamID = spFunc.GetPlayerInfo(interactionState.trackingPlayerID, false)
	else
		-- Use local player's team
		teamID = Spring.GetMyTeamID()
	end
	if not teamID then
		interactionState.pipMinimapBounds = nil
		return
	end

	-- Calculate minimap dimensions - use hover size if hovering or TV/activity active, otherwise normal size
	local pipWidth = render.dim.r - render.dim.l
	local pipHeight = render.dim.t - render.dim.b
	local useEnlargedSize = showForHover or showForTV or showForActivityFocus
	local heightPercent = useEnlargedSize and config.minimapHoverHeightPercent or config.minimapHeightPercent
	local minimapHeight = math.floor(pipHeight * heightPercent)
	
	-- Check if map is rotated 90°/270° — swap aspect ratio so minimap container matches rotated content
	local isRotated90 = false
	if render.minimapRotation then
		local rotDeg = math.abs(render.minimapRotation * 180 / math.pi) % 180
		if rotDeg > 45 and rotDeg < 135 then
			isRotated90 = true
		end
	end
	local naturalAspect = mapInfo.mapSizeX / mapInfo.mapSizeZ  -- true (unrotated) map aspect
	local mapAspect = isRotated90 and (mapInfo.mapSizeZ / mapInfo.mapSizeX) or naturalAspect
	local minimapWidth
	if isRotated90 and naturalAspect > 1 then
		-- Wide map rotated: keep the longest dimension the same as unrotated
		-- Unrotated width would be minimapHeight * naturalAspect (the longest dim)
		-- Use that as the new height, derive width from rotated aspect
		local unrotatedWidth = math.floor(minimapHeight * naturalAspect)
		minimapHeight = unrotatedWidth
		minimapWidth = math.floor(minimapHeight * mapAspect)
	elseif isRotated90 and naturalAspect <= 1 then
		-- Tall map rotated: it becomes wide, keep height as-is
		minimapWidth = math.floor(minimapHeight * mapAspect)
	else
		minimapWidth = math.floor(minimapHeight * naturalAspect)
	end

	-- Clamp to reasonable size
	minimapWidth = math.min(minimapWidth, math.floor(pipWidth * 0.35))
	minimapHeight = math.floor(minimapWidth / mapAspect)

	-- Position based on config corner setting
	-- 1=bottom-left, 2=bottom-right, 3=top-left, 4=top-right
	-- When tracking units, add cornerSize offset; otherwise stick to PIP edge
	local isTrackingUnits = interactionState.areTracking and #interactionState.areTracking > 0
	local cornerSize = isTrackingUnits and math.floor(render.elementCorner * 0.6) or 0
	local borderOffset = isTrackingUnits and 1 or 0  -- Touch the team color border, or snap to edge
	local mmLeft, mmBottom, mmRight, mmTop
	local corner = config.pipMinimapCorner or 1
	
	if corner == 1 then  -- bottom-left
		mmLeft = render.dim.l + cornerSize + borderOffset
		mmBottom = render.dim.b + cornerSize + borderOffset
		mmRight = mmLeft + minimapWidth
		mmTop = mmBottom + minimapHeight
	elseif corner == 2 then  -- bottom-right
		mmRight = render.dim.r - cornerSize - borderOffset
		mmBottom = render.dim.b + cornerSize + borderOffset
		mmLeft = mmRight - minimapWidth
		mmTop = mmBottom + minimapHeight
	elseif corner == 3 then  -- top-left
		mmLeft = render.dim.l + cornerSize + borderOffset
		mmTop = render.dim.t - cornerSize - borderOffset
		mmRight = mmLeft + minimapWidth
		mmBottom = mmTop - minimapHeight
	else  -- top-right (4)
		mmRight = render.dim.r - cornerSize - borderOffset
		mmTop = render.dim.t - cornerSize - borderOffset
		mmLeft = mmRight - minimapWidth
		mmBottom = mmTop - minimapHeight
	end

	-- Store minimap bounds for click handling (include the border)
	interactionState.pipMinimapBounds = {
		l = corner == 2 and (mmLeft - 3) or mmLeft,
		r = corner == 1 and (mmRight + 3) or mmRight,
		b = corner >= 3 and (mmBottom - 3) or mmBottom,
		t = corner <= 2 and (mmTop + 3) or mmTop,
		-- Store actual drawing bounds (without border) for coordinate conversion
		drawL = mmLeft,
		drawR = mmRight,
		drawB = mmBottom,
		drawT = mmTop,
	}

	-- Determine which corner faces PIP center for chamfer and border
	-- bottom-left: chamfer top-right, border top+right
	-- bottom-right: chamfer top-left, border top+left
	-- top-left: chamfer bottom-right, border bottom+right
	-- top-right: chamfer bottom-left, border bottom+left
	local chamferSize = math.floor(minimapHeight * 0.06)
	
	glFunc.Color(0, 0, 0, 0.85)
	if corner == 1 then  -- bottom-left: chamfer top-right
		glFunc.BeginEnd(GL.POLYGON, function()
			glFunc.Vertex(mmLeft, mmBottom)
			glFunc.Vertex(mmRight + 3, mmBottom)
			glFunc.Vertex(mmRight + 3, mmTop + 3 - chamferSize)
			glFunc.Vertex(mmRight + 3 - chamferSize, mmTop + 3)
			glFunc.Vertex(mmLeft, mmTop + 3)
		end)
	elseif corner == 2 then  -- bottom-right: chamfer top-left
		glFunc.BeginEnd(GL.POLYGON, function()
			glFunc.Vertex(mmRight, mmBottom)
			glFunc.Vertex(mmRight, mmTop + 3)
			glFunc.Vertex(mmLeft - 3 + chamferSize, mmTop + 3)
			glFunc.Vertex(mmLeft - 3, mmTop + 3 - chamferSize)
			glFunc.Vertex(mmLeft - 3, mmBottom)
		end)
	elseif corner == 3 then  -- top-left: chamfer bottom-right
		glFunc.BeginEnd(GL.POLYGON, function()
			glFunc.Vertex(mmLeft, mmTop)
			glFunc.Vertex(mmLeft, mmBottom - 3)
			glFunc.Vertex(mmRight + 3 - chamferSize, mmBottom - 3)
			glFunc.Vertex(mmRight + 3, mmBottom - 3 + chamferSize)
			glFunc.Vertex(mmRight + 3, mmTop)
		end)
	else  -- top-right: chamfer bottom-left
		glFunc.BeginEnd(GL.POLYGON, function()
			glFunc.Vertex(mmRight, mmTop)
			glFunc.Vertex(mmLeft - 3, mmTop)
			glFunc.Vertex(mmLeft - 3, mmBottom - 3 + chamferSize)
			glFunc.Vertex(mmLeft - 3 + chamferSize, mmBottom - 3)
			glFunc.Vertex(mmRight, mmBottom - 3)
		end)
	end

	-- Draw border on sides facing PIP center
	glFunc.Color(0.5, 0.5, 0.5, 0.6)
	glFunc.LineWidth(1)
	if corner == 1 then  -- bottom-left: border top+right
		glFunc.BeginEnd(GL.LINE_STRIP, function()
			glFunc.Vertex(mmLeft, mmTop + 3)
			glFunc.Vertex(mmRight + 3 - chamferSize, mmTop + 3)
			glFunc.Vertex(mmRight + 3, mmTop + 3 - chamferSize)
			glFunc.Vertex(mmRight + 3, mmBottom)
		end)
	elseif corner == 2 then  -- bottom-right: border top+left
		glFunc.BeginEnd(GL.LINE_STRIP, function()
			glFunc.Vertex(mmRight, mmTop + 3)
			glFunc.Vertex(mmLeft - 3 + chamferSize, mmTop + 3)
			glFunc.Vertex(mmLeft - 3, mmTop + 3 - chamferSize)
			glFunc.Vertex(mmLeft - 3, mmBottom)
		end)
	elseif corner == 3 then  -- top-left: border bottom+right
		glFunc.BeginEnd(GL.LINE_STRIP, function()
			glFunc.Vertex(mmLeft, mmBottom - 3)
			glFunc.Vertex(mmRight + 3 - chamferSize, mmBottom - 3)
			glFunc.Vertex(mmRight + 3, mmBottom - 3 + chamferSize)
			glFunc.Vertex(mmRight + 3, mmTop)
		end)
	else  -- top-right: border bottom+left
		glFunc.BeginEnd(GL.LINE_STRIP, function()
			glFunc.Vertex(mmRight, mmBottom - 3)
			glFunc.Vertex(mmLeft - 3 + chamferSize, mmBottom - 3)
			glFunc.Vertex(mmLeft - 3, mmBottom - 3 + chamferSize)
			glFunc.Vertex(mmLeft - 3, mmTop)
		end)
	end

	-- Apply rotation for minimap content
	local mmCenterX = (mmLeft + mmRight) / 2
	local mmCenterY = (mmBottom + mmTop) / 2

	-- When rotated 90°/270°, content inside the rotation matrix must use swapped width/height
	-- so that after rotation it visually fills the container (which has the rotated aspect ratio)
	local cLeft, cRight, cBottom, cTop, cWidth, cHeight
	if isRotated90 then
		cWidth = minimapHeight  -- container height becomes content width (will rotate to visual height)
		cHeight = minimapWidth  -- container width becomes content height (will rotate to visual width)
		cLeft = mmCenterX - cWidth / 2
		cRight = mmCenterX + cWidth / 2
		cBottom = mmCenterY - cHeight / 2
		cTop = mmCenterY + cHeight / 2
	else
		cLeft, cRight, cBottom, cTop = mmLeft, mmRight, mmBottom, mmTop
		cWidth = minimapWidth
		cHeight = minimapHeight
	end

	if render.minimapRotation ~= 0 then
		glFunc.PushMatrix()
		glFunc.Translate(mmCenterX, mmCenterY, 0)
		glFunc.Rotate(render.minimapRotation * 180 / math.pi, 0, 0, 1)
		glFunc.Translate(-mmCenterX, -mmCenterY, 0)
	end

	-- Draw minimap ground texture with shading in single pass (matches engine compositing)
	glFunc.Color(1, 1, 1, 1)
	if shaders.minimapShading then
		gl.UseShader(shaders.minimapShading)
		glFunc.Texture(0, '$minimap')
		glFunc.Texture(1, '$shading')
		glFunc.BeginEnd(GL.QUADS, function()
			glFunc.TexCoord(0, 0); glFunc.Vertex(cLeft, cTop)
			glFunc.TexCoord(1, 0); glFunc.Vertex(cRight, cTop)
			glFunc.TexCoord(1, 1); glFunc.Vertex(cRight, cBottom)
			glFunc.TexCoord(0, 1); glFunc.Vertex(cLeft, cBottom)
		end)
		glFunc.Texture(0, false)
		glFunc.Texture(1, false)
		gl.UseShader(0)
	else
		glFunc.Texture('$minimap')
		glFunc.BeginEnd(GL.QUADS, function()
			glFunc.TexCoord(0, 0); glFunc.Vertex(cLeft, cTop)
			glFunc.TexCoord(1, 0); glFunc.Vertex(cRight, cTop)
			glFunc.TexCoord(1, 1); glFunc.Vertex(cRight, cBottom)
			glFunc.TexCoord(0, 1); glFunc.Vertex(cLeft, cBottom)
		end)
		glFunc.Texture(false)
	end

	-- Draw water/lava/void overlay
	if mapInfo.hasWater and shaders.water then
		gl.UseShader(shaders.water)
		local r, g, b, a
		if mapInfo.voidWater then
			r, g, b, a = 0, 0, 0, 1
		elseif mapInfo.isLava then
			r, g, b, a = 0.22, 0, 0, 1
		else
			r, g, b, a = 0.08, 0.11, 0.22, 0.5
		end
		gl.UniformFloat(gl.GetUniformLocation(shaders.water, "waterColor"), r, g, b, a)
		gl.UniformFloat(gl.GetUniformLocation(shaders.water, "waterLevel"), GetWaterLevel())
		gl.UniformInt(gl.GetUniformLocation(shaders.water, "heightTex"), 0)
		glFunc.Texture(0, '$heightmap')
		glFunc.Color(1, 1, 1, 1)
		glFunc.BeginEnd(GL.QUADS, function()
			glFunc.TexCoord(0, 0); glFunc.Vertex(cLeft, cTop)
			glFunc.TexCoord(1, 0); glFunc.Vertex(cRight, cTop)
			glFunc.TexCoord(1, 1); glFunc.Vertex(cRight, cBottom)
			glFunc.TexCoord(0, 1); glFunc.Vertex(cLeft, cBottom)
		end)
		glFunc.Texture(0, false)
		gl.UseShader(0)
	end

	-- Draw LOS overlay on minimap (only after game has started and when LOS should be shown)
	local shouldShowLOS, _ = ShouldShowLOS()
	if config.showLosOverlay and shouldShowLOS and pipR2T.losTex and gameHasStarted then
		-- Engine-like reverse-subtract: result_rgb = dst - src (subtractive darkening)
		gl.BlendEquationSeparate(GL.FUNC_REVERSE_SUBTRACT, GL.FUNC_ADD)
		gl.BlendFuncSeparate(GL.ONE, GL.ONE, GL.ZERO, GL.ONE)
		glFunc.Color(1, 1, 1, 0)
		glFunc.Texture(pipR2T.losTex)
		glFunc.BeginEnd(GL.QUADS, function()
			glFunc.TexCoord(0, 0); glFunc.Vertex(cLeft, cTop)
			glFunc.TexCoord(1, 0); glFunc.Vertex(cRight, cTop)
			glFunc.TexCoord(1, 1); glFunc.Vertex(cRight, cBottom)
			glFunc.TexCoord(0, 1); glFunc.Vertex(cLeft, cBottom)
		end)
		glFunc.Texture(false)
		gl.BlendEquation(GL.FUNC_ADD)
		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	end

	-- Draw view rectangle (dynamic, updates every frame)
	local worldL = math.max(0, math.min(mapInfo.mapSizeX, render.world.l))
	local worldR = math.max(0, math.min(mapInfo.mapSizeX, render.world.r))
	local worldT = math.max(0, math.min(mapInfo.mapSizeZ, render.world.t))
	local worldB = math.max(0, math.min(mapInfo.mapSizeZ, render.world.b))

	local viewL = cLeft + (worldL / mapInfo.mapSizeX) * cWidth
	local viewR = cLeft + (worldR / mapInfo.mapSizeX) * cWidth
	local viewT = cTop - (worldT / mapInfo.mapSizeZ) * cHeight
	local viewB = cTop - (worldB / mapInfo.mapSizeZ) * cHeight

	-- Draw dark shadow outline behind view rectangle
	glFunc.Color(0, 0, 0, 0.33)
	glFunc.LineWidth(3)
	glFunc.BeginEnd(GL.LINE_LOOP, function()
		glFunc.Vertex(viewL, viewB)
		glFunc.Vertex(viewR, viewB)
		glFunc.Vertex(viewR, viewT)
		glFunc.Vertex(viewL, viewT)
	end)

	-- Draw white view rectangle on top
	glFunc.Color(1, 1, 1, 0.9)
	glFunc.LineWidth(1.5)
	glFunc.BeginEnd(GL.LINE_LOOP, function()
		glFunc.Vertex(viewL, viewB)
		glFunc.Vertex(viewR, viewB)
		glFunc.Vertex(viewR, viewT)
		glFunc.Vertex(viewL, viewT)
	end)

	glFunc.Color(1, 1, 1, 0.15)
	glFunc.BeginEnd(GL.QUADS, function()
		glFunc.Vertex(viewL, viewB)
		glFunc.Vertex(viewR, viewB)
		glFunc.Vertex(viewR, viewT)
		glFunc.Vertex(viewL, viewT)
	end)

	if render.minimapRotation ~= 0 then
		glFunc.PopMatrix()
	end

	glFunc.LineWidth(1)
	glFunc.Color(1, 1, 1, 1)
end

-- Helper function to update R2T frame textures
local function UpdateR2TFrame(pipWidth, pipHeight)
	if not gl.R2tHelper then
		return
	end

	-- Check if frame size changed
	if math.floor(pipWidth) ~= pipR2T.frameLastWidth or math.floor(pipHeight) ~= pipR2T.frameLastHeight then
		pipR2T.frameNeedsUpdate = true
		if pipR2T.frameBackgroundTex then
			gl.DeleteTexture(pipR2T.frameBackgroundTex)
			pipR2T.frameBackgroundTex = nil
		end
		if pipR2T.frameButtonsTex then
			gl.DeleteTexture(pipR2T.frameButtonsTex)
			pipR2T.frameButtonsTex = nil
		end
		-- Invalidate text display lists when size changes (positions change)
		if pipR2T.resbarTextDlist then
			gl.DeleteList(pipR2T.resbarTextDlist)
			pipR2T.resbarTextDlist = nil
		end
		if pipR2T.playerNameDlist then
			gl.DeleteList(pipR2T.playerNameDlist)
			pipR2T.playerNameDlist = nil
		end
		pipR2T.frameLastWidth = math.floor(pipWidth)
		pipR2T.frameLastHeight = math.floor(pipHeight)
	end

	-- Update frame textures if needed
	if pipR2T.frameNeedsUpdate and pipWidth >= 1 and pipHeight >= 1 then
		-- Create texture large enough to include elementPadding on all sides
		local bgTexWidth = math.floor(pipWidth + render.elementPadding * 2)
		local bgTexHeight = math.floor(pipHeight + render.elementPadding * 2)
		
		if not pipR2T.frameBackgroundTex then
			pipR2T.frameBackgroundTex = gl.CreateTexture(bgTexWidth, bgTexHeight, {
				target = GL.TEXTURE_2D, format = GL.RGBA, fbo = true,
			})
		end
		if pipR2T.frameBackgroundTex then
			gl.R2tHelper.RenderToTexture(pipR2T.frameBackgroundTex, function()
				glFunc.Translate(-1, -1, 0)
				glFunc.Scale(2 / bgTexWidth, 2 / bgTexHeight, 0)
				-- Render UiElement using actual screen coordinates for proper shading
				local padL = render.dim.l - render.elementPadding
				local padB = render.dim.b - render.elementPadding
				local padR = render.dim.r + render.elementPadding
				local padT = render.dim.t + render.elementPadding
				-- Translate to origin for texture rendering
				glFunc.Translate(-padL, -padB, 0)
				local tl, tr, br, bl = GetChamferedCorners(padL, padB, padR, padT)
				render.UiElement(padL, padB, padR, padT, tl, tr, br, bl, nil, nil, nil, nil, nil, nil, nil, nil)
			end, true)
		end

		if not pipR2T.frameButtonsTex then
			pipR2T.frameButtonsTex = gl.CreateTexture(math.floor(pipWidth), math.floor(pipHeight), {
				target = GL.TEXTURE_2D, format = GL.RGBA, fbo = true,
			})
		end
		if pipR2T.frameButtonsTex then
			gl.R2tHelper.RenderToTexture(pipR2T.frameButtonsTex, function()
				glFunc.Translate(-1, -1, 0)
				glFunc.Scale(2 / pipWidth, 2 / pipHeight, 0)
				RenderFrameButtons()
			end, true)
		end

		pipR2T.frameNeedsUpdate = false
	end

	if pipR2T.frameBackgroundTex then
		-- Blit the cached UiElement background (includes padding)
		gl.R2tHelper.BlendTexRect(pipR2T.frameBackgroundTex, render.dim.l-render.elementPadding, render.dim.b-render.elementPadding, render.dim.r+render.elementPadding, render.dim.t+render.elementPadding, true)
	else
		-- Fallback to direct rendering if texture not available
		local padL = render.dim.l - render.elementPadding
		local padB = render.dim.b - render.elementPadding
		local padR = render.dim.r + render.elementPadding
		local padT = render.dim.t + render.elementPadding
		local tl, tr, br, bl = GetChamferedCorners(padL, padB, padR, padT)
		render.UiElement(padL, padB, padR, padT, tl, tr, br, bl, nil, nil, nil, nil, nil, nil, nil, nil)
	end
end

-- Helper function to calculate dynamic update rate
local function CalculateDynamicUpdateRate()
	-- Base rate from zoom level
	local dynamicUpdateRate = config.pipMinUpdateRate
	if cameraState.zoom >= config.pipZoomThresholdMax then
		dynamicUpdateRate = config.pipMaxUpdateRate
	elseif cameraState.zoom > config.pipZoomThresholdMin then
		dynamicUpdateRate = config.pipMinUpdateRate + (config.pipMaxUpdateRate - config.pipMinUpdateRate) * ((cameraState.zoom - config.pipZoomThresholdMin) / (config.pipZoomThresholdMax - config.pipZoomThresholdMin))
	end

	-- Apply performance-based adjustment using averaged frame times
	local avgDrawTime = pipR2T.contentDrawTimeAverage
	if avgDrawTime > 0 then
		-- Calculate target rate based on how draw time compares to pipTargetDrawTime
		-- If draw time exceeds target, scale the rate down proportionally
		local targetDrawTime = config.pipTargetDrawTime
		if avgDrawTime > targetDrawTime and targetDrawTime > 0 then
			-- Scale rate so that (rate * avgDrawTime) approaches (rate * targetDrawTime)
			-- e.g. if draw time is 2x target, halve the rate
			local targetRate = dynamicUpdateRate * (targetDrawTime / avgDrawTime)
			-- Clamp to floor rate
			targetRate = math.max(config.pipFloorUpdateRate, targetRate)
			-- Smooth transition towards target
			local targetFactor = targetRate / dynamicUpdateRate
			pipR2T.contentPerformanceFactor = pipR2T.contentPerformanceFactor + (targetFactor - pipR2T.contentPerformanceFactor) * config.pipPerformanceAdjustSpeed
		else
			-- Below target, gradually recover towards 1.0
			pipR2T.contentPerformanceFactor = pipR2T.contentPerformanceFactor + (1.0 - pipR2T.contentPerformanceFactor) * config.pipPerformanceAdjustSpeed * 0.5
		end
		-- Apply performance factor, ensuring we don't go below floor rate
		dynamicUpdateRate = math.max(config.pipFloorUpdateRate, dynamicUpdateRate * pipR2T.contentPerformanceFactor)
	end

	pipR2T.contentCurrentUpdateRate = dynamicUpdateRate
	return dynamicUpdateRate
end

-- Helper function to update the oversized units texture at throttled rate
-- Renders expensive layers (units, features, projectiles, commands, markers, camera bounds)
local function UpdateR2TUnits(currentTime, pipUpdateInterval, pipWidth, pipHeight)
	if not gl.R2tHelper then
		return
	end

	-- In minimap mode, skip rendering until ViewResize has initialized the zoom level
	if isMinimapMode and not minimapModeMinZoom then
		return
	end

	-- Get current rotation early (before shouldUpdate check) so rotation changes are detected
	local currentRotation = Spring.GetMiniMapRotation and Spring.GetMiniMapRotation() or 0

	local resScale = config.contentResolutionScale
	local margin = config.smoothCameraMargin
	local uW = math.floor(pipWidth * (1 + 2 * margin) * resScale)
	local uH = math.floor(pipHeight * (1 + 2 * margin) * resScale)

	-- Check if size changed
	local sizeChanged = math.floor(pipWidth) ~= pipR2T.unitsLastWidth or math.floor(pipHeight) ~= pipR2T.unitsLastHeight

	-- Check if rotation changed (requires re-render as rotation is baked into unitsTex)
	local rotChanged = pipR2T.unitsRotation ~= currentRotation

	-- Check if camera has drifted far enough to consume most of the margin
	local driftForced = false
	if pipR2T.unitsZoom ~= 0 and margin > 0 then
		local dx = cameraState.wcx - pipR2T.unitsWcx
		local dz = cameraState.wcz - pipR2T.unitsWcz
		local marginWorldX = margin * pipWidth / cameraState.zoom
		local marginWorldZ = margin * pipHeight / cameraState.zoom
		if marginWorldX > 0 and marginWorldZ > 0 then
			local driftFracX = math.abs(dx) / marginWorldX
			local driftFracZ = math.abs(dz) / marginWorldZ
			local zoomRatio = cameraState.zoom / pipR2T.unitsZoom
			if driftFracX * zoomRatio > 0.7 or driftFracZ * zoomRatio > 0.7 then
				driftForced = true
			end
		end
		-- Zoom-out detection: force re-render when viewport outgrows the oversized texture
		if not driftForced then
			local zoomRatio = cameraState.zoom / pipR2T.unitsZoom
			local safeRatio = 1 / (1 + 2 * margin)
			if zoomRatio < safeRatio * 1.1 then
				driftForced = true
			end
		end
	end

	-- Check if should update based on time
	-- Zoom changes are handled by scaling the blit quad, so they don't force a re-render
	-- During resize, sizeChanged defers to throttle instead of forcing immediate update —
	-- this avoids texture alloc/dealloc/render on every frame of the drag
	local timeSinceLastUpdate = currentTime - pipR2T.unitsLastUpdateTime
	local shouldUpdate = pipR2T.unitsNeedsUpdate or rotChanged or driftForced or
		(sizeChanged and not uiState.areResizing) or
		pipUpdateInterval == 0 or
		(pipUpdateInterval > 0 and timeSinceLastUpdate >= pipUpdateInterval)

	-- If size changed but we're throttled, defer the update
	if sizeChanged and not shouldUpdate then
		pipR2T.unitsNeedsUpdate = true
	end

	if not shouldUpdate then
		return
	end

	-- Delete old texture if size changed
	if sizeChanged then
		if pipR2T.unitsTex then
			gl.DeleteTexture(pipR2T.unitsTex)
			pipR2T.unitsTex = nil
		end
		pipR2T.unitsLastWidth = math.floor(pipWidth)
		pipR2T.unitsLastHeight = math.floor(pipHeight)
	end

	-- Create texture if needed
	if not pipR2T.unitsTex and uW >= 1 and uH >= 1 then
		pipR2T.unitsTex = gl.CreateTexture(uW, uH, {
			target = GL.TEXTURE_2D, format = GL.RGBA, fbo = true,
		})
		pipR2T.unitsTexWidth = uW
		pipR2T.unitsTexHeight = uH
	end

	if pipR2T.unitsTex then
		-- Use the rotation we already fetched
		render.minimapRotation = currentRotation

		gl.R2tHelper.RenderToTexture(pipR2T.unitsTex, function()
			glFunc.Translate(-1, -1, 0)
			glFunc.Scale(2 / uW, 2 / uH, 0)

			-- Use separate blend for alpha: color blends normally, alpha accumulates
			-- correctly for later premultiplied compositing (avoids alpha² darkening)
			gl.BlendFuncSeparate(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA, GL.ONE, GL.ONE_MINUS_SRC_ALPHA)

			-- Save current dimensions
			pools.savedDim.l, pools.savedDim.r, pools.savedDim.b, pools.savedDim.t = render.dim.l, render.dim.r, render.dim.b, render.dim.t

			-- Set oversized dimensions — contentScale = resScale so RecalcWorldCoords
			-- divides by resScale, leaving the (1 + 2*margin) factor to expand world bounds
			render.dim.l, render.dim.b, render.dim.r, render.dim.t = 0, 0, uW, uH
			render.contentScale = resScale
			RecalculateWorldCoordinates()

			-- Store world bounds and camera state for the compositing blit
			pipR2T.unitsWorld.l = render.world.l
			pipR2T.unitsWorld.r = render.world.r
			pipR2T.unitsWorld.b = render.world.b
			pipR2T.unitsWorld.t = render.world.t
			pipR2T.unitsZoom = cameraState.zoom
			pipR2T.unitsRotation = render.minimapRotation
			pipR2T.unitsWcx = cameraState.wcx
			pipR2T.unitsWcz = cameraState.wcz

			-- Use pcall so restore always runs even if rendering errors
			local ok, err = pcall(RenderExpensiveLayers)
			if not ok then
				Spring.Echo("[PIP] Units render error: " .. tostring(err))
				-- Emergency GL state cleanup: RenderExpensiveLayers may have left dirty state
				gl.UseShader(0)
				glFunc.Texture(0, false)
				glFunc.Texture(1, false)
				glFunc.Texture(false)
				gl.Scissor(false)
				gl.BlendEquation(GL.FUNC_ADD)
				-- Try to pop rotation matrix if it was pushed
				if render.minimapRotation ~= 0 then
					pcall(glFunc.PopMatrix)
				end
			end

			-- Restore blending and original values
			gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
			render.contentScale = 1
			render.dim.l, render.dim.r, render.dim.b, render.dim.t = pools.savedDim.l, pools.savedDim.r, pools.savedDim.b, pools.savedDim.t
			RecalculateWorldCoordinates()
			RecalculateGroundTextureCoordinates()
		end, true)
		pipR2T.unitsLastUpdateTime = currentTime
		pipR2T.unitsNeedsUpdate = false
	end
end

-- Update oversized content texture (cheap layers: ground, water, LOS) at throttled rate
-- The oversized texture provides margin for smooth camera panning via UV-shift in DrawScreen
local function UpdateR2TCheapLayers(currentTime, pipUpdateInterval, pipWidth, pipHeight)
	if not gl.R2tHelper then
		return
	end

	-- In minimap mode, skip rendering until ViewResize has initialized the zoom level
	if isMinimapMode and not minimapModeMinZoom then
		return
	end

	local resScale = config.contentResolutionScale
	local margin = config.smoothCameraMarginCheap
	local cW = math.floor(pipWidth * (1 + 2 * margin) * resScale)
	local cH = math.floor(pipHeight * (1 + 2 * margin) * resScale)

	-- Check if size changed
	local sizeChanged = math.floor(pipWidth) ~= pipR2T.contentLastWidth or math.floor(pipHeight) ~= pipR2T.contentLastHeight

	-- Check if rotation changed (rotation is baked into the texture)
	local currentRotation = Spring.GetMiniMapRotation and Spring.GetMiniMapRotation() or 0
	local rotChanged = pipR2T.contentRotation ~= currentRotation

	-- Check if camera has drifted far enough to consume most of the margin
	-- If so, force an immediate re-render to avoid showing the edge of the oversized texture
	local driftForced = false
	if pipR2T.contentZoom ~= 0 and margin > 0 then
		local dx = cameraState.wcx - pipR2T.contentWcx
		local dz = cameraState.wcz - pipR2T.contentWcz
		-- Convert world drift to fraction of the margin's world-space coverage
		-- Margin covers (margin * pipWidth / zoom) in world units per side
		local marginWorldX = margin * pipWidth / cameraState.zoom
		local marginWorldZ = margin * pipHeight / cameraState.zoom
		if marginWorldX > 0 and marginWorldZ > 0 then
			local driftFracX = math.abs(dx) / marginWorldX
			local driftFracZ = math.abs(dz) / marginWorldZ
			-- Also account for zoom drift: if zoomed in relative to stored, margin shrinks
			local zoomRatio = cameraState.zoom / pipR2T.contentZoom
			local effectiveDriftX = driftFracX * zoomRatio
			local effectiveDriftZ = driftFracZ * zoomRatio
			if effectiveDriftX > 0.7 or effectiveDriftZ > 0.7 then
				driftForced = true
			end
		end
		-- Zoom-out detection: if current zoom shrank enough that the oversized texture
		-- no longer covers the viewport, force a re-render.
		-- The texture covers (1+2*margin) × the viewport at the stored zoom,
		-- so it can handle a zoom ratio down to ~1/(1+2*margin) before edges appear.
		if not driftForced then
			local zoomRatio = cameraState.zoom / pipR2T.contentZoom
			local safeRatio = 1 / (1 + 2 * margin)
			if zoomRatio < safeRatio * 1.1 then  -- 10% safety margin
				driftForced = true
			end
		end
	end

	-- Check if should update based on time
	-- During resize, sizeChanged defers to throttle instead of forcing immediate update
	local timeSinceLastUpdate = currentTime - pipR2T.contentLastUpdateTime
	local shouldUpdate = pipR2T.contentNeedsUpdate or rotChanged or driftForced or
		(sizeChanged and not uiState.areResizing) or
		pipUpdateInterval == 0 or
		(pipUpdateInterval > 0 and timeSinceLastUpdate >= pipUpdateInterval)

	if sizeChanged and not shouldUpdate then
		pipR2T.contentNeedsUpdate = true
	end

	if not shouldUpdate then
		return
	end

	-- Delete old texture if size changed
	if sizeChanged then
		if pipR2T.contentTex then
			gl.DeleteTexture(pipR2T.contentTex)
			pipR2T.contentTex = nil
		end
		pipR2T.contentLastWidth = math.floor(pipWidth)
		pipR2T.contentLastHeight = math.floor(pipHeight)
	end

	-- Create oversized texture if needed
	if not pipR2T.contentTex and cW >= 1 and cH >= 1 then
		pipR2T.contentTex = gl.CreateTexture(cW, cH, {
			target = GL.TEXTURE_2D, format = GL.RGBA, fbo = true,
		})
		pipR2T.contentTexWidth = cW
		pipR2T.contentTexHeight = cH
		pipR2T.contentLastWidth = math.floor(pipWidth)
		pipR2T.contentLastHeight = math.floor(pipHeight)
	end

	if pipR2T.contentTex then
		render.minimapRotation = currentRotation

		gl.R2tHelper.RenderToTexture(pipR2T.contentTex, function()
			glFunc.Translate(-1, -1, 0)
			glFunc.Scale(2 / cW, 2 / cH, 0)

			-- Fill entire texture with transparent background
			-- (rotation leaves corners uncovered by the ground texture)
			-- Use (0,0,0,0) for all cases: in premultiplied alpha compositing,
			-- non-zero RGB with alpha=0 would be added (tinting) to the background
			gl.Blending(false)
			glFunc.Color(0, 0, 0, 0)
			glFunc.Texture(false)
			glFunc.BeginEnd(glConst.QUADS, DrawTexturedQuad, 0, 0, cW, cH)
			glFunc.Color(1, 1, 1, 1)

			-- Use separate blend for alpha: color blends normally, alpha accumulates
			-- correctly for later premultiplied compositing (avoids water/overlay
			-- reducing alpha and causing semi-transparency)
			gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
			gl.BlendFuncSeparate(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA, GL.ONE, GL.ONE_MINUS_SRC_ALPHA)

			-- Save current dimensions
			pools.savedDim.l, pools.savedDim.r, pools.savedDim.b, pools.savedDim.t = render.dim.l, render.dim.r, render.dim.b, render.dim.t

			-- Set oversized dims — contentScale = resScale so world bounds expand by (1+2*margin)
			render.dim.l, render.dim.b, render.dim.r, render.dim.t = 0, 0, cW, cH
			render.contentScale = resScale
			RecalculateWorldCoordinates()
			RecalculateGroundTextureCoordinates()

			-- Render cheap layers (ground, water, LOS)
			local ok, err = pcall(RenderCheapLayers)
			if not ok then
				Spring.Echo("[PIP] Cheap layers render error: " .. tostring(err))
				-- Emergency GL state cleanup: RenderCheapLayers may have left dirty state
				-- (active shader, wrong blend equation, pushed matrix, bound textures, scissor)
				gl.UseShader(0)
				glFunc.Texture(0, false)
				glFunc.Texture(1, false)
				glFunc.Texture(false)
				gl.Scissor(false)
				gl.BlendEquation(GL.FUNC_ADD)
				gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
				gl.BlendFuncSeparate(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA, GL.ONE, GL.ONE_MINUS_SRC_ALPHA)
				-- Try to pop rotation matrix if it was pushed
				if render.minimapRotation ~= 0 then
					pcall(glFunc.PopMatrix)
				end
			end

			-- Restore
			render.contentScale = 1
			render.dim.l, render.dim.r, render.dim.b, render.dim.t = pools.savedDim.l, pools.savedDim.r, pools.savedDim.b, pools.savedDim.t
			RecalculateWorldCoordinates()
			RecalculateGroundTextureCoordinates()
		end, true)

		-- Store camera state for UV-shift in DrawScreen
		pipR2T.contentWcx = cameraState.wcx
		pipR2T.contentWcz = cameraState.wcz
		pipR2T.contentZoom = cameraState.zoom
		pipR2T.contentRotation = currentRotation
		pipR2T.contentLastUpdateTime = currentTime
		pipR2T.contentNeedsUpdate = false
	end
end

-- GL4 instanced decal rendering: GPU computes alpha fade, single draw call
-- VBO holds per-instance decal data, geometry shader expands points to rotated textured quads
-- Instance data only uploaded when decals are added/removed (not every frame)
decalGL4 = {
	atlasPath = "luaui/images/decals_gl4/decalsgl4_atlas_diffuse.dds",
	INSTANCE_STEP = 16,   -- floats per instance (4 x vec4)
	MAX_INSTANCES = 16384,
	vbo = nil,
	vao = nil,
	instanceData = nil,   -- pre-allocated flat float array
	instanceCount = 0,    -- current number of valid instances
	version = -1,         -- last usedElements sum (dirty check)
	logCount = 0,
	uniformLocs = nil,    -- cached uniform locations
	renderFrame = 0,      -- game frame for GPU alpha computation (set before R2T draw)
}

-- Initialize GL4 decal resources (called during R2T setup)
InitGL4Decals = function()
	if not gl.GetVAO or not gl.GetVBO then return end
	if not shaders.decal then return end

	local vbo = gl.GetVBO(GL.ARRAY_BUFFER, true)
	if not vbo then
		Spring.Echo("[PIP] GL4 decals: Failed to create VBO")
		return
	end
	vbo:Define(decalGL4.MAX_INSTANCES, {
		{id = 0, name = 'posRot',      size = 4},  -- worldX, worldZ, rotation, maxalpha
		{id = 1, name = 'sizeAlpha',   size = 4},  -- halfLengthX, halfWidthZ, alphastart, alphadecay
		{id = 2, name = 'uvCoords',    size = 4},  -- p, q, s, t
		{id = 3, name = 'spawnParams', size = 4},  -- spawnframe, 0, 0, 0
	})

	local vao = gl.GetVAO()
	if not vao then
		Spring.Echo("[PIP] GL4 decals: Failed to create VAO")
		vbo:Delete()
		return
	end
	vao:AttachVertexBuffer(vbo)

	-- Pre-allocate instance data array
	local instanceData = {}
	for i = 1, decalGL4.MAX_INSTANCES * decalGL4.INSTANCE_STEP do
		instanceData[i] = 0
	end

	decalGL4.vbo = vbo
	decalGL4.vao = vao
	decalGL4.instanceData = instanceData

	-- Cache uniform locations
	decalGL4.uniformLocs = {
		gameFrame  = gl.GetUniformLocation(shaders.decal, "gameFrame"),
		invMapSize = gl.GetUniformLocation(shaders.decal, "invMapSize"),
	}

	Spring.Echo("[PIP] GL4 instanced decal rendering enabled")
end

-- Destroy GL4 decal resources
DestroyGL4Decals = function()
	if decalGL4.vao then decalGL4.vao:Delete(); decalGL4.vao = nil end
	if decalGL4.vbo then decalGL4.vbo:Delete(); decalGL4.vbo = nil end
	decalGL4.instanceData = nil
	decalGL4.instanceCount = 0
	decalGL4.version = -1
	decalGL4.uniformLocs = nil
end

-- Rebuild VBO instance data from decal VBO tables (only when decals added/removed)
-- Uses sequential index iteration (1..usedElements) instead of pairs() for speed.
-- The VBO uses swap-with-last compaction so indices are always contiguous.
local function RebuildDecalVBO(vboTables)
	local data = decalGL4.instanceData
	local step = decalGL4.INSTANCE_STEP
	local count = 0
	local maxInst = decalGL4.MAX_INSTANCES

	for vi = 1, #vboTables do
		local vbo = vboTables[vi]
		if vbo and vbo.usedElements > 0 then
			local srcStep = vbo.instanceStep
			local srcData = vbo.instanceData
			local used = vbo.usedElements
			-- Sequential iteration: ~3x faster than pairs() over sparse hash table
			for idx = 1, used do
				if count >= maxInst then break end
				local ofs = (idx - 1) * srcStep
				local p = srcData[ofs + 5]
				local s = srcData[ofs + 7]
				-- Only include textured decals (skip untextured color-only)
				if p and s then
					local o = count * step
					-- posRot: worldX, worldZ, rotation, maxalpha
					data[o+1]  = srcData[ofs + 13]   -- posx
					data[o+2]  = srcData[ofs + 15]   -- posz
					data[o+3]  = srcData[ofs + 3]    -- rotation
					data[o+4]  = srcData[ofs + 4]    -- maxalpha
					-- sizeAlpha: halfLengthX, halfWidthZ, alphastart, alphadecay
					data[o+5]  = srcData[ofs + 1] * 0.5  -- half length
					data[o+6]  = srcData[ofs + 2] * 0.5  -- half width
					data[o+7]  = srcData[ofs + 9]    -- alphastart
					data[o+8]  = srcData[ofs + 10]   -- alphadecay
					-- uvCoords: p, q, s, t
					data[o+9]  = p
					data[o+10] = srcData[ofs + 6]    -- q
					data[o+11] = s
					data[o+12] = srcData[ofs + 8]    -- t
					-- spawnParams: spawnframe, 0, 0, 0
					data[o+13] = srcData[ofs + 16]   -- spawnframe
					data[o+14] = 0
					data[o+15] = 0
					data[o+16] = 0
					count = count + 1
				end
			end
		end
	end

	decalGL4.instanceCount = count

	-- Upload to GPU
	if count > 0 then
		decalGL4.vbo:Upload(data, nil, 0, 1, count * step)
	end
end

-- Pre-created closure for R2T clear quad (no per-call allocation)
local function decalClearQuad()
	glFunc.Vertex(-1, -1); glFunc.Vertex(1, -1)
	glFunc.Vertex(1, 1); glFunc.Vertex(-1, 1)
end

-- Pre-created R2T draw function for GL4 decals (no per-call closure allocation)
local function decalR2TDraw()
	-- Clear to white (multiply identity)
	glFunc.Texture(false)
	gl.Blending(false)
	glFunc.Color(1, 1, 1, 1)
	glFunc.BeginEnd(GL.QUADS, decalClearQuad)

	if decalGL4.instanceCount > 0 then
		-- GL_MIN blending: darkest wins, no overlap fringing, alpha stays 1.0
		gl.Blending(GL.ONE, GL.ONE)
		gl.BlendEquation(0x8007)  -- GL_MIN

		local atlasOK = glFunc.Texture(decalGL4.atlasPath)
		if atlasOK then
			gl.UseShader(shaders.decal)
			local ul = decalGL4.uniformLocs
			gl.UniformFloat(ul.gameFrame, decalGL4.renderFrame)
			gl.UniformFloat(ul.invMapSize, 2.0 / mapInfo.mapSizeX, 2.0 / mapInfo.mapSizeZ)
			decalGL4.vao:DrawArrays(GL.POINTS, decalGL4.instanceCount)
			gl.UseShader(0)
			glFunc.Texture(false)
		end

		gl.BlendEquation(GL.FUNC_ADD)
	end

	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
end

local function UpdateDecalTexture()
	if not config.drawDecals then return end
	if not pipR2T.decalTex then return end
	if not decalGL4.vao then return end

	-- Rate-limit: only run every N game frames (~1 sec)
	local frame = Spring.GetGameFrame()
	if (frame - pipR2T.decalLastCheckFrame) < pipR2T.decalCheckInterval then return end
	pipR2T.decalLastCheckFrame = frame

	local decalsAPI = WG['decalsgl4']
	if not decalsAPI then return end
	local getVBO = decalsAPI.GetVBOData
	if not getVBO then return end
	local vboTables = getVBO()
	if not vboTables then return end

	-- Always rebuild: usedElements sum can't detect add+remove in same interval
	-- RebuildDecalVBO is cheap (~0.1ms for 1000 decals: sequential array copy, no alloc)
	RebuildDecalVBO(vboTables)

	if decalGL4.instanceCount == 0 then return end

	-- Render into R2T texture: single instanced draw call, GPU computes alpha fade
	decalGL4.renderFrame = frame
	gl.R2tHelper.RenderToTexture(pipR2T.decalTex, decalR2TDraw)
end

-- Update LOS texture with current Line-of-Sight information
local function UpdateLOSTexture(currentTime)
	-- In minimap mode, skip until ViewResize has initialized
	if isMinimapMode and not minimapModeMinZoom then
		return
	end

	-- Check if we should update LOS texture
	local shouldShowLOS, losAllyTeam = ShouldShowLOS()
	if not shouldShowLOS or not pipR2T.losTex then
		return
	end

	local myAllyTeam = Spring.GetMyAllyTeamID()
	-- Can only use engine LOS if:
	-- 1. Same allyteam as us
	-- 2. If tracking a player, must have fullview enabled (engine LOS requires fullview for enemy teams)
	local useEngineLOS = (losAllyTeam == myAllyTeam)
	if interactionState.trackingPlayerID and losAllyTeam ~= myAllyTeam then
		-- Tracking an enemy player - must have fullview to use engine LOS
		local _, fullview = Spring.GetSpectatingState()
		if not fullview then
			-- Without fullview, must manually generate enemy LOS
			useEngineLOS = false
		end
	end
	
	-- Handle delay when switching to engine LOS
	local actualUseEngineLOS = useEngineLOS
	if useEngineLOS then
		-- Check if we're in the delay period after mode change
		local modeChanged = (pipR2T.losLastMode ~= nil and pipR2T.losLastMode ~= useEngineLOS)
		if modeChanged then
			pipR2T.losEngineDelayFrames = 2
		end
		
		if pipR2T.losEngineDelayFrames > 0 then
			pipR2T.losEngineDelayFrames = pipR2T.losEngineDelayFrames - 1
			-- Continue using manual LOS during delay to avoid visual gap
			actualUseEngineLOS = false
		end
	end
	pipR2T.losLastMode = useEngineLOS

	-- Check if update is needed based on update rate
	local shouldUpdate
	if actualUseEngineLOS then
		-- Always update when using engine LOS (it's cheap and real-time)
		shouldUpdate = true
	else
		-- Only apply rate limiting when manually generating LOS (expensive)
		shouldUpdate = pipR2T.losNeedsUpdate or (currentTime - pipR2T.losLastUpdateTime) >= pipR2T.losUpdateRate
	end

	if not shouldUpdate then
		return
	end

	-- Validate losAllyTeam before proceeding
	if not losAllyTeam or losAllyTeam < 0 then
		return
	end
	
	-- Check if we can actually query this allyTeam's LOS
	-- Without fullview, we can only query our own allyTeam
	if losAllyTeam ~= myAllyTeam then
		local _, fullview = Spring.GetSpectatingState()
		if not fullview then
			-- Can't query enemy LOS without fullview - skip update
			return
		end
	end

	-- Calculate LOS texture dimensions
	local losTexWidth = math.max(1, math.floor(mapInfo.mapSizeX / pipR2T.losTexScale))
	local losTexHeight = math.max(1, math.floor(mapInfo.mapSizeZ / pipR2T.losTexScale))

	-- Render the LOS texture
	gl.R2tHelper.RenderToTexture(pipR2T.losTex, function()
		if actualUseEngineLOS then
			-- Use engine's LOS texture (fast, real-time)
			-- Requires shader to convert red channel to greyscale
			if not shaders.los then
				return
			end
				glFunc.Texture(0, '$info:los')
				glFunc.Texture(1, '$info:radar')

				-- Activate shader to convert red channel to greyscale
				gl.UseShader(shaders.los)
				
				-- Update shader uniforms (in case config changed)
				gl.UniformFloat(gl.GetUniformLocation(shaders.los, "showRadar"), config.showLosRadar and 1.0 or 0.0)

				-- Draw full-screen quad in normalized coordinates (-1 to 1)
				glFunc.BeginEnd(glConst.QUADS, function()
					glFunc.TexCoord(0, 0); glFunc.Vertex(-1, -1)
					glFunc.TexCoord(1, 0); glFunc.Vertex(1, -1)
					glFunc.TexCoord(1, 1); glFunc.Vertex(1, 1)
					glFunc.TexCoord(0, 1); glFunc.Vertex(-1, 1)
				end)

				gl.UseShader(0)
				glFunc.Texture(1, false)
				glFunc.Texture(0, false)
			else
				-- Manually generate LOS texture using Spring.IsPosInLos (expensive)
				-- Output darkening amounts (matching engine-like additive-bias method)
				-- 0 = no darkening (in LOS), positive = darken by that amount
				local fogDarken = config.losOverlayOpacity * 0.28  -- Fog darkening amount
				local noRadarDarken = fogDarken + config.losOverlayOpacity * 0.1  -- Extra for no-radar areas
				local showRadar = config.showLosRadar
				
				if showRadar then
					-- Start with maximum darkening (no LOS, no radar)
					gl.Clear(GL.COLOR_BUFFER_BIT, noRadarDarken, noRadarDarken, noRadarDarken, 1)
				else
					-- No radar display, start with fog darkening
					gl.Clear(GL.COLOR_BUFFER_BIT, fogDarken, fogDarken, fogDarken, 1)
				end

				local cellSizeX = mapInfo.mapSizeX / losTexWidth
				local cellSizeZ = mapInfo.mapSizeZ / losTexHeight
				
				-- First pass: draw radar areas (moderate darkening) if showRadar enabled
				if showRadar then
					glFunc.Color(fogDarken, fogDarken, fogDarken, 1)
					glFunc.BeginEnd(glConst.QUADS, function()
						for y = 0, losTexHeight - 1 do
							for x = 0, losTexWidth - 1 do
								local worldX = (x + 0.5) * cellSizeX
								local worldZ = (y + 0.5) * cellSizeZ
								local worldY = spFunc.GetGroundHeight(worldX, worldZ)

								if spFunc.IsPosInRadar(worldX, worldY, worldZ, losAllyTeam) then
									local nx1 = (x / losTexWidth) * 2 - 1
									local nx2 = ((x + 1) / losTexWidth) * 2 - 1
									local ny1 = (y / losTexHeight) * 2 - 1
									local ny2 = ((y + 1) / losTexHeight) * 2 - 1

									glFunc.Vertex(nx1, ny1)
									glFunc.Vertex(nx2, ny1)
									glFunc.Vertex(nx2, ny2)
									glFunc.Vertex(nx1, ny2)
								end
							end
						end
					end)
				end
				
				-- Second pass: draw LOS areas (no darkening)
				glFunc.Color(0, 0, 0, 1)
				glFunc.BeginEnd(glConst.QUADS, function()
					for y = 0, losTexHeight - 1 do
						for x = 0, losTexWidth - 1 do
							local worldX = (x + 0.5) * cellSizeX
							local worldZ = (y + 0.5) * cellSizeZ
							local worldY = spFunc.GetGroundHeight(worldX, worldZ)

							if spFunc.IsPosInLos(worldX, worldY, worldZ, losAllyTeam) then
								local nx1 = (x / losTexWidth) * 2 - 1
								local nx2 = ((x + 1) / losTexWidth) * 2 - 1
								local ny1 = (y / losTexHeight) * 2 - 1
								local ny2 = ((y + 1) / losTexHeight) * 2 - 1

								glFunc.Vertex(nx1, ny1)
								glFunc.Vertex(nx2, ny1)
								glFunc.Vertex(nx2, ny2)
								glFunc.Vertex(nx1, ny2)
							end
						end
					end
				end)

				gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
			end
		end, true)

	pipR2T.losLastUpdateTime = currentTime
	pipR2T.losNeedsUpdate = false
end

-- Helper function to draw tracking indicators
local function DrawTrackingIndicators()
	if interactionState.areTracking and #interactionState.areTracking > 0 then
		local lineWidth = math.ceil(2 * (render.vsx / 1920))
		local pipWidth = render.dim.r - render.dim.l
		local pipHeight = render.dim.t - render.dim.b
		glFunc.Color(1, 1, 1, 0.22)
		render.RectRoundOutline(render.dim.l, render.dim.b, render.dim.r, render.dim.t, render.elementCorner*0.5, lineWidth, 1, 1, 1, 1, {1, 1, 1, 0.22}, {1, 1, 1, 0.22})
	end

	if interactionState.trackingPlayerID then
		local playerName, active, isSpec, teamID = spFunc.GetPlayerInfo(interactionState.trackingPlayerID, false)
		if teamID then
			local r, g, b = Spring.GetTeamColor(teamID)
			local lineWidth = math.ceil(3 * (render.vsx / 1920))
			glFunc.Color(r, g, b, 0.5)
			render.RectRoundOutline(render.dim.l, render.dim.b, render.dim.r, render.dim.t, render.elementCorner*0.5, lineWidth, 1, 1, 1, 1, {r, g, b, 0.5}, {r, g, b, 0.5})
		end
	end
end

-- Helper function to handle hover and cursor updates
local function HandleHoverAndCursor(mx, my)
	if interactionState.arePanning then
		return
	end

	if not (interactionState.areBoxSelecting or (mx >= render.dim.l and mx <= render.dim.r and my >= render.dim.b and my <= render.dim.t)) then
		if WG['info'] and WG['info'].clearCustomHover then
			WG['info'].clearCustomHover()
		end
		interactionState.lastHoveredUnitID = nil
		interactionState.lastHoveredFeatureID = nil
		return
	end

	-- Throttle expensive GetUnitAtPoint calls for performance (but not during active zoom)
	local currentTime = os.clock()
	local shouldCheckUnit = (currentTime - interactionState.lastHoverCursorCheckTime) >= 0.1
	local isZooming = interactionState.areIncreasingZoom or interactionState.areDecreasingZoom

	if shouldCheckUnit and not isZooming then
		interactionState.lastHoverCursorCheckTime = currentTime

		-- Update info widget with custom hover
		if WG['info'] and WG['info'].setCustomHover then
			local wx, wz = PipToWorldCoords(mx, my)
			local uID = GetUnitAtPoint(wx, wz)
			if uID then
				WG['info'].setCustomHover('unit', uID)
				interactionState.lastHoveredUnitID = uID
				interactionState.lastHoveredFeatureID = nil
			else
				-- Only check features if zoom level is high enough to render them
				if cameraState.zoom >= config.zoomFeatures then
					local fID = GetFeatureAtPoint(wx, wz)
					if fID then
						WG['info'].setCustomHover('feature', fID)
						interactionState.lastHoveredFeatureID = fID
						interactionState.lastHoveredUnitID = nil
					else
						WG['info'].clearCustomHover()
						interactionState.lastHoveredUnitID = nil
						interactionState.lastHoveredFeatureID = nil
					end
				else
					WG['info'].clearCustomHover()
					interactionState.lastHoveredUnitID = nil
					interactionState.lastHoveredFeatureID = nil
				end
			end
		end
	end

	-- Handle cursor - this runs every frame for smooth cursor updates
	-- Don't change cursor for spectators (unless config allows it)
	local isSpec = Spring.GetSpectatingState()
	local canGiveCommands = not isSpec or config.allowCommandsWhenSpectating
	local lastHoveredUnitID = interactionState.lastHoveredUnitID
	if canGiveCommands then
		local _, activeCmdID = Spring.GetActiveCommand()
		if not activeCmdID then
			local defaultCmd = Spring.GetDefaultCommand()

			if not defaultCmd or defaultCmd == 0 then
				local selectedUnits = Spring.GetSelectedUnits()
				if selectedUnits and #selectedUnits > 0 then
					-- Check if hovering over an enemy unit with units that can attack
					-- But don't show attack cursor for neutral units
					if lastHoveredUnitID and not Spring.IsUnitAllied(lastHoveredUnitID) then
						local allyTeam = Spring.GetUnitAllyTeam(lastHoveredUnitID)
						local isNeutral = (allyTeam == gaiaAllyTeamID)
						
						-- Check if unit is visible (LOS or radar)
						local checkAllyTeamID = cameraState.myAllyTeamID
						if interactionState.trackingPlayerID and cameraState.mySpecState then
							local _, _, _, teamID = spFunc.GetPlayerInfo(interactionState.trackingPlayerID, false)
							checkAllyTeamID = select(6, spFunc.GetTeamInfo(teamID, false))
						end
						local losState = spFunc.GetUnitLosState(lastHoveredUnitID, checkAllyTeamID)
						local isVisibleOrRadar = losState and (losState.los or losState.radar)
						
						if not isNeutral and isVisibleOrRadar then
							-- Check if any selected unit can attack
							for i = 1, #selectedUnits do
								local uDefID = spFunc.GetUnitDefID(selectedUnits[i])
								if uDefID and cache.canAttack[uDefID] then
									Spring.SetMouseCursor('Attack')
									return
								end
							end
						end
					end
					
					-- Check if we have a transport and are hovering over a transportable unit
					-- Use cached result from throttled check above
					if lastHoveredUnitID and Spring.IsUnitAllied(lastHoveredUnitID) then
						-- Check if any transport in selection can load this unit
						for i = 1, #selectedUnits do
							if CanTransportLoadUnit(selectedUnits[i], lastHoveredUnitID) then
								Spring.SetMouseCursor('Load')
								return
							end
						end
					end

					-- Default to Move cursor if units can move (using cache)
					for i = 1, #selectedUnits do
						local uDefID = spFunc.GetUnitDefID(selectedUnits[i])
						if uDefID and (cache.canMove[uDefID] or cache.canFly[uDefID]) then
							Spring.SetMouseCursor('Move')
							return
						end
					end
				end
			elseif defaultCmd == CMD.ATTACK and lastHoveredUnitID and not Spring.IsUnitAllied(lastHoveredUnitID) then
				-- Hovering over enemy unit with units that can attack
				Spring.SetMouseCursor('Attack')
				return
			end
		else
			local cursorName = cmdCursors[activeCmdID]
			if cursorName then
				Spring.SetMouseCursor(cursorName)
			end
		end
	end
end

-- Helper function to draw interactive overlays (buttons, pip number, etc.)
local function DrawInteractiveOverlays(mx, my, usedButtonSize)
	-- Draw pipNumber text only when hovering (and only for pip 2+)
	if pipNumber > 1 and interactionState.isMouseOverPip then
		glFunc.Color(config.panelBorderColorDark)
		render.RectRound(render.dim.l, render.dim.t - render.usedButtonSize, render.dim.l + render.usedButtonSize, render.dim.t, render.elementCorner*0.4, 0, 0, 1, 0)
		local fontSize = 14
		local padding = 12
		font:Begin()
		font:SetTextColor(0.85, 0.85, 0.85, 1)
		font:SetOutlineColor(0, 0, 0, 0.5)
		font:Print(pipNumber, render.dim.l + padding, render.dim.t - (fontSize*1.15) - padding, fontSize*2, "no")
		font:End()
	end

	-- Bottom-left buttons hover
	local selectedUnits = Spring.GetSelectedUnits()
	local visibleButtons = {}
	for i = 1, #buttons do
		local btn = buttons[i]
		-- In minimap mode, hide move button if configured
		local skipButton = false
		if isMinimapMode and config.minimapModeHideMoveResize then
			if btn.tooltipKey == 'ui.pip.move' then
				skipButton = true
			end
		end
		-- In minimap mode, skip switch and copy buttons (keep pip_track and pip_trackplayer)
		-- Allow pip_view for spectators with fullview
		if isMinimapMode then
			if btn.command == 'pip_switch' or btn.command == 'pip_copy' then
				skipButton = true
			elseif btn.command == 'pip_view' then
				local _, fullview = Spring.GetSpectatingState()
				if not fullview then
					skipButton = true
				end
			end
		end
		
		if not skipButton then
			if btn.command == 'pip_track' then
				if #selectedUnits > 0 or interactionState.areTracking then
					visibleButtons[#visibleButtons + 1] = btn
				end
			elseif btn.command == 'pip_trackplayer' then
				local _, _, spec = spFunc.GetPlayerInfo(Spring.GetMyPlayerID(), false)
				local aliveTeammates = GetAliveTeammates()
				if (interactionState.trackingPlayerID or spec or (#aliveTeammates > 0)) and not miscState.tvEnabled then
					visibleButtons[#visibleButtons + 1] = btn
				end
			elseif btn.command == 'pip_view' then
				local _, _, spec = spFunc.GetPlayerInfo(Spring.GetMyPlayerID(), false)
				if spec then
					visibleButtons[#visibleButtons + 1] = btn
				end
			elseif btn.command == 'pip_activity' then
				if not isSinglePlayer and not interactionState.trackingPlayerID and not miscState.tvEnabled and not (config.activityFocusHideForSpectators and cameraState.mySpecState) then
					visibleButtons[#visibleButtons + 1] = btn
				end
			elseif btn.command == 'pip_tv' then
				if not config.tvModeSpectatorsOnly or cameraState.mySpecState then
					visibleButtons[#visibleButtons + 1] = btn
				end
			else
				visibleButtons[#visibleButtons + 1] = btn
			end
		end
	end

	if #visibleButtons > 0 then
		-- Draw base buttons when showing on hover
		if config.showButtonsOnHoverOnly and interactionState.isMouseOverPip then
			glFunc.Color(config.panelBorderColorDark)
			glFunc.Texture(false)
			render.RectRound(render.dim.l, render.dim.b, render.dim.l + (#visibleButtons * render.usedButtonSize) + math.floor(render.elementPadding*0.75), render.dim.b + render.usedButtonSize + math.floor(render.elementPadding*0.75), render.elementCorner, 0, 1, 0, 0)
			local bx = render.dim.l
			for i = 1, #visibleButtons do
				if (visibleButtons[i].command == 'pip_track' and interactionState.areTracking) or
				   (visibleButtons[i].command == 'pip_trackplayer' and interactionState.trackingPlayerID) or
				   (visibleButtons[i].command == 'pip_view' and state.losViewEnabled) or
				   (visibleButtons[i].command == 'pip_activity' and miscState.activityFocusEnabled) or
				   (visibleButtons[i].command == 'pip_tv' and miscState.tvEnabled) then
					glFunc.Color(config.panelBorderColorLight)
					glFunc.Texture(false)
					render.RectRound(bx, render.dim.b, bx + render.usedButtonSize, render.dim.b + render.usedButtonSize, render.elementCorner*0.4, 1, 1, 1, 1)
					glFunc.Color(config.panelBorderColorDark)
				else
					glFunc.Color(config.panelBorderColorLight)
				end
				glFunc.Texture(visibleButtons[i].texture)
				glFunc.TexRect(bx, render.dim.b, bx + render.usedButtonSize, render.dim.b + render.usedButtonSize)
				bx = bx + render.usedButtonSize
			end
			glFunc.Texture(false)
		end

		-- Button hover interactions (always check for hover, not just when showing on hover)
		local bx = render.dim.l
		for i = 1, #visibleButtons do
			if mx >= bx and mx <= bx + render.usedButtonSize and my >= render.dim.b and my <= render.dim.b + render.usedButtonSize then
				if visibleButtons[i].tooltipKey and WG['tooltip'] then
					local tooltipKey = visibleButtons[i].tooltipKey
					if visibleButtons[i].tooltipActiveKey then
						if (visibleButtons[i].command == 'pip_track' and interactionState.areTracking) or
						   (visibleButtons[i].command == 'pip_trackplayer' and interactionState.trackingPlayerID) or
						   (visibleButtons[i].command == 'pip_view' and state.losViewEnabled) or
						   (visibleButtons[i].command == 'pip_activity' and miscState.activityFocusEnabled) or
						   (visibleButtons[i].command == 'pip_tv' and miscState.tvEnabled) then
							tooltipKey = visibleButtons[i].tooltipActiveKey
						end
					end
					-- Generate tooltip with shortcut key on new line if available
					local tooltipText = Spring.I18N(tooltipKey)
					-- Use button's shortcut field first, fall back to getActionHotkey
					-- In minimap mode, don't show shorcut for track units button
					local shortcut = visibleButtons[i].shortcut
					local suppressShortcut = isMinimapMode and visibleButtons[i].command == 'pip_track'
					if suppressShortcut then
						shortcut = nil
					end
					if not shortcut and not suppressShortcut and visibleButtons[i].command then
						shortcut = getActionHotkey(visibleButtons[i].command)
					end
					if shortcut and shortcut ~= "" then
						tooltipText = tooltipText .. "\n" .. shortcut
					end
					WG['tooltip'].ShowTooltip('pip'..pipNumber, tooltipText, nil, nil, nil)
				end
				glFunc.Color(1,1,1,0.12)
				glFunc.Texture(false)
				render.RectRound(bx, render.dim.b, bx + render.usedButtonSize, render.dim.b + render.usedButtonSize, render.elementCorner*0.4, 1, 1, 1, 1)
				if (visibleButtons[i].command == 'pip_track' and interactionState.areTracking) or
				   (visibleButtons[i].command == 'pip_trackplayer' and interactionState.trackingPlayerID) or
				   (visibleButtons[i].command == 'pip_view' and state.losViewEnabled) or
				   (visibleButtons[i].command == 'pip_activity' and miscState.activityFocusEnabled) or
				   (visibleButtons[i].command == 'pip_tv' and miscState.tvEnabled) then
					glFunc.Color(config.panelBorderColorDark)
				else
					glFunc.Color(1, 1, 1, 1)
				end
				glFunc.Texture(visibleButtons[i].texture)
				glFunc.TexRect(bx, render.dim.b, bx + render.usedButtonSize, render.dim.b + render.usedButtonSize)
				-- Draw hover highlight on top for better visibility
				glFunc.Color(1, 1, 1, 0.2)
				glFunc.Texture(false)
				render.RectRound(bx, render.dim.b, bx + render.usedButtonSize, render.dim.b + render.usedButtonSize, render.elementCorner*0.4, 1, 1, 1, 1)
				glFunc.Texture(false)
				break
			end
			bx = bx + render.usedButtonSize
		end
	end
end

function widget:DrawScreen()
	local mx, my, mbl = spFunc.GetMouseState()

	-- During animation, disable mouse interaction
	if uiState.isAnimating then
		mx, my = -1, -1  -- Force mouse out of bounds during animation
	end

	-- In minimap mode, skip all rendering until ViewResize has completed initialization
	if isMinimapMode and not minimapModeMinZoom then
		return
	end

	-- In minimap mode, honour MinimapMinimize to hide the PIP minimap
	if isMinimapMode and miscState.minimapMinimized then
		return
	end

	-- In minimap mode, never show minimized state (skip this whole section)
	if uiState.inMinMode and not uiState.isAnimating and not isMinimapMode then
		-- Use display list for minimized mode (static graphics with relative coordinates)
		local buttonSize = math.floor(render.usedButtonSize*config.maximizeSizemult)

		-- Draw render.UiElement background FIRST (with proper screen coordinates)
		--render.UiElement(uiState.minModeL-render.elementPadding, uiState.minModeB-render.elementPadding, uiState.minModeL+buttonSize+render.elementPadding, uiState.minModeB+buttonSize+render.elementPadding, 1, 1, 1, 1, nil, nil, nil, nil, nil, nil, nil, nil)

		-- Then draw icon on top using display list
		local offset = render.elementPadding + 2	-- to prevent touching screen edges and FlowUI Element will remove borders
		
		-- Check if we need to recreate display list due to position change (affects rotation)
		local sw, sh = Spring.GetWindowGeometry()
		local currentQuadrant = (uiState.minModeL < sw * 0.5 and 1 or 2) + (uiState.minModeB < sh * 0.25 and 0 or 2)
		-- Also track edge state for chamfered corners
		local actualL = uiState.minModeL - render.elementPadding
		local actualB = uiState.minModeB - render.elementPadding
		local actualR = uiState.minModeL + buttonSize + render.elementPadding
		local actualT = uiState.minModeB + buttonSize + render.elementPadding
		local currentEdgeState = (actualL <= 0 and 1 or 0) + (actualB <= 0 and 2 or 0) + (actualR >= render.vsx and 4 or 0) + (actualT >= render.vsy and 8 or 0)
		if (render.minModeQuadrant ~= currentQuadrant or render.minModeEdgeState ~= currentEdgeState) and render.minModeDlist then
			gl.DeleteList(render.minModeDlist)
			render.minModeDlist = nil
		end
		render.minModeQuadrant = currentQuadrant
		render.minModeEdgeState = currentEdgeState
		
		if not render.minModeDlist then
			render.minModeDlist = gl.CreateList(function()
				-- Draw render.UiElement background (only borders, no fill to avoid double opacity)
				-- Compute actual screen coordinates for chamfered corners
				local actualL = uiState.minModeL - render.elementPadding
				local actualB = uiState.minModeB - render.elementPadding
				local actualR = uiState.minModeL + buttonSize + render.elementPadding
				local actualT = uiState.minModeB + buttonSize + render.elementPadding
				local tl, tr, br, bl = GetChamferedCorners(actualL, actualB, actualR, actualT)
				render.UiElement(offset-render.elementPadding, offset-render.elementPadding, offset+buttonSize+render.elementPadding, offset+buttonSize+render.elementPadding, tl, tr, br, bl, nil, nil, nil, nil, nil, nil, nil, nil)

				-- Draw icon at origin (0,0) - will be transformed to actual position
				glFunc.Color(config.panelBorderColorLight)
				glFunc.Texture('LuaUI/Images/pip/PipExpand.png')
				
				-- Rotate icon based on expansion direction
				local rotation = GetMaximizeIconRotation()
				local centerX = offset + buttonSize * 0.5
				local centerY = offset + buttonSize * 0.5
				glFunc.PushMatrix()
				glFunc.Translate(centerX, centerY, 0)
				glFunc.Rotate(rotation, 0, 0, 1)
				glFunc.Translate(-centerX, -centerY, 0)
				
				glFunc.TexRect(offset, offset, offset+buttonSize, offset+buttonSize)
				glFunc.PopMatrix()
				glFunc.Texture(false)
			end)
		end

		-- Apply transform and draw the cached icon at actual position
		glFunc.PushMatrix()
		glFunc.Translate(uiState.minModeL-offset, uiState.minModeB-offset, 0)
		glFunc.CallList(render.minModeDlist)
		glFunc.PopMatrix()

		-- Draw hover overlay if needed (dynamic)
		glFunc.Color(config.panelBorderColorDark)
		glFunc.Texture(false)
		if mx >= uiState.minModeL - render.elementPadding and mx <= uiState.minModeL + buttonSize + render.elementPadding and
			my >= uiState.minModeB - render.elementPadding and my <= uiState.minModeB + buttonSize + render.elementPadding then
			if WG['tooltip'] then
				WG['tooltip'].ShowTooltip('pip'..pipNumber, Spring.I18N('ui.pip.tooltip'), nil, nil, nil)
			end
			glFunc.Color(1,1,1,0.12)
			glFunc.Texture(false)
			render.RectRound(uiState.minModeL, uiState.minModeB, uiState.minModeL + buttonSize, uiState.minModeB + buttonSize, render.elementCorner*0.4, 1, 1, 1, 1)
		end
		return
	end

	HandleHoverAndCursor(mx, my)

	----------------------------------------------------------------------------------------------------
	-- Updates
	----------------------------------------------------------------------------------------------------
	if interactionState.areCentering then
		UpdateCentering(spFunc.GetMouseState())
	end

	if interactionState.areTracking then
		UpdateTracking()
	end

	----------------------------------------------------------------------------------------------------
	-- Panel and buttons (using render-to-texture for static/semi-static parts)
	----------------------------------------------------------------------------------------------------
	local pipWidth = render.dim.r - render.dim.l
	local pipHeight = render.dim.t - render.dim.b

	UpdateR2TFrame(pipWidth, pipHeight)

	----------------------------------------------------------------------------------------------------
	-- Units, features, and queues (using render-to-texture for performance)
	----------------------------------------------------------------------------------------------------
	if gl.R2tHelper then
		local currentTime = os.clock()
		local dynamicUpdateRate = CalculateDynamicUpdateRate()
		local pipUpdateInterval = dynamicUpdateRate > 0 and (1 / dynamicUpdateRate) or 0

		-- Update LOS texture
		UpdateLOSTexture(currentTime)

		-- Update decal overlay texture (~once per second, game-frame based)
		UpdateDecalTexture()

		-- Force immediate units re-render when fullview state changes.
		-- The main transition detection code (below) runs AFTER UpdateR2TUnits,
		-- so detect the change here to ensure the ghost pass runs on the same frame.
		do
			local _, fv = Spring.GetSpectatingState()
			if miscState.lastFullview ~= nil and miscState.lastFullview ~= fv then
				pipR2T.unitsNeedsUpdate = true
			end
		end

		-- Update oversized units texture at throttled rate (expensive layers)
		local drawStartTime = os.clock()
		local prevUnitsTime = pipR2T.unitsLastUpdateTime
		UpdateR2TUnits(currentTime, pipUpdateInterval, pipWidth, pipHeight)

		-- Update oversized cheap layers texture at throttled rate
		local prevContentTime = pipR2T.contentLastUpdateTime
		UpdateR2TCheapLayers(currentTime, pipUpdateInterval, pipWidth, pipHeight)

		-- Only record draw time when actual rendering occurred (not throttled no-ops)
		local didRender = pipR2T.unitsLastUpdateTime ~= prevUnitsTime or pipR2T.contentLastUpdateTime ~= prevContentTime
		if didRender then
			local drawTime = os.clock() - drawStartTime
			pipR2T.contentLastDrawTime = drawTime
		
			-- Add to frame time history (ring buffer of last N frames)
			pipR2T.contentDrawTimeHistoryIndex = (pipR2T.contentDrawTimeHistoryIndex % config.pipFrameTimeHistorySize) + 1
			pipR2T.contentDrawTimeHistory[pipR2T.contentDrawTimeHistoryIndex] = drawTime
		
			-- Calculate average of frame times
			local sum = 0
			local count = 0
			for i = 1, config.pipFrameTimeHistorySize do
				if pipR2T.contentDrawTimeHistory[i] then
					sum = sum + pipR2T.contentDrawTimeHistory[i]
					count = count + 1
				end
			end
			pipR2T.contentDrawTimeAverage = count > 0 and (sum / count) or 0
		end

		-- Update content mask display list if dimensions or position changed
		local maskNeedsUpdate = (math.floor(pipWidth) ~= pipR2T.contentMaskLastWidth or 
								 math.floor(pipHeight) ~= pipR2T.contentMaskLastHeight or
								 math.floor(render.dim.l) ~= pipR2T.contentMaskLastL or
								 math.floor(render.dim.b) ~= pipR2T.contentMaskLastB)
		if maskNeedsUpdate then
			if pipR2T.contentMaskDlist then
				gl.DeleteList(pipR2T.contentMaskDlist)
			end
			pipR2T.contentMaskDlist = gl.CreateList(function()
				-- Draw rounded rectangle shape for stencil mask
				-- Use slightly larger corner radius so diagonal border looks same thickness as straight edges
				-- Disable corner rounding at screen edges
				local edgeTolerance = 2
				local atLeft = render.dim.l <= edgeTolerance
				local atRight = render.dim.r >= render.vsx - edgeTolerance
				local atBottom = render.dim.b <= edgeTolerance
				local atTop = render.dim.t >= render.vsy - edgeTolerance
				local tl = (atLeft or atTop) and 0 or 1
				local tr = (atRight or atTop) and 0 or 1
				local br = (atRight or atBottom) and 0 or 1
				local bl = (atLeft or atBottom) and 0 or 1
				render.RectRound(render.dim.l, render.dim.b, render.dim.r, render.dim.t, render.elementCorner * 0.5, tl, tr, br, bl)
			end)
			-- Also invalidate text display lists when position changes
			if pipR2T.resbarTextDlist then
				gl.DeleteList(pipR2T.resbarTextDlist)
				pipR2T.resbarTextDlist = nil
			end
			if pipR2T.playerNameDlist then
				gl.DeleteList(pipR2T.playerNameDlist)
				pipR2T.playerNameDlist = nil
			end
			pipR2T.contentMaskLastWidth = math.floor(pipWidth)
			pipR2T.contentMaskLastHeight = math.floor(pipHeight)
			pipR2T.contentMaskLastL = math.floor(render.dim.l)
			pipR2T.contentMaskLastB = math.floor(render.dim.b)
		end

		-- Blit the pre-rendered texture with rounded corner stencil mask
		if pipR2T.contentTex then
			-- Set up stencil buffer to clip to rounded corners
			gl.Clear(GL.STENCIL_BUFFER_BIT)
			gl.StencilTest(true)
			gl.StencilFunc(GL.ALWAYS, 1, 0xFF)  -- Always pass, write 1 to stencil buffer
			gl.StencilOp(GL.KEEP, GL.KEEP, GL.REPLACE)  -- Replace stencil value where we draw
			gl.ColorMask(false, false, false, false)  -- Don't draw to color buffer
			
			-- Draw the rounded mask shape into stencil buffer
			if pipR2T.contentMaskDlist then
				gl.CallList(pipR2T.contentMaskDlist)
			end
			
			-- Now draw content only where stencil == 1
			gl.ColorMask(true, true, true, true)  -- Enable color writes
			gl.StencilFunc(GL.EQUAL, 1, 0xFF)  -- Only draw where stencil == 1
			gl.StencilOp(GL.KEEP, GL.KEEP, GL.KEEP)  -- Don't modify stencil buffer
			
			-- Reset GL state — mask drawing dirties color/blending state
			glFunc.Color(1, 1, 1, 1)
			gl.Blending(GL.ONE, GL.ONE_MINUS_SRC_ALPHA)  -- Premultiplied alpha: opaque map shows fully, transparent off-map areas pass through

			-- Blit oversized content texture (cheap layers: ground, water, LOS) with camera shift
			BlitShiftedTexture(pipR2T.contentTex, pipR2T.contentTexWidth, pipR2T.contentTexHeight,
				pipR2T.contentWcx, pipR2T.contentWcz, pipR2T.contentZoom, pipR2T.contentRotation)

			-- Blit oversized units texture (expensive layers: units, features, projectiles)
			-- Uses premultiplied alpha: FBO was rendered with BlendFuncSeparate for correct alpha
			if pipR2T.unitsTex then
				gl.Blending(GL.ONE, GL.ONE_MINUS_SRC_ALPHA)
				BlitShiftedTexture(pipR2T.unitsTex, pipR2T.unitsTexWidth, pipR2T.unitsTexHeight,
					pipR2T.unitsWcx, pipR2T.unitsWcz, pipR2T.unitsZoom, pipR2T.unitsRotation)
			end
			gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)  -- Explicitly restore blend func

			-- Blit map ruler directly to screen (not in oversized texture — rulers are edge-fixed)
			if uiState.drawingGround and config.showMapRuler then
				local _, _, spec = spFunc.GetPlayerInfo(Spring.GetMyPlayerID(), false)
				if not spec then
					UpdateMapRulerTexture()
					if pipR2T.rulerTex then
						gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
						gl.R2tHelper.BlendTexRect(pipR2T.rulerTex, render.dim.l, render.dim.b, render.dim.r, render.dim.t, true)
						gl.Blending(true)
					end
				end
			end
			
			-- Disable stencil test
			gl.StencilTest(false)
			
			-- Draw minimap overlays from other widgets (only in minimap mode)
			-- This is done here in DrawScreen (not in R2T) because matrix manipulation works correctly here
			if isMinimapMode and WG['minimap'] and widgetHandler and widgetHandler.DrawInMiniMapList then
				local minimapWidth = render.dim.r - render.dim.l
				local minimapHeight = render.dim.t - render.dim.b
				
				-- Get the world coordinates visible in the PIP
				local worldL, worldR, worldB, worldT = render.world.l, render.world.r, render.world.b, render.world.t
				
				-- Use scissor to clip to PIP area
				gl.Scissor(render.dim.l, render.dim.b, minimapWidth, minimapHeight)
				
				-- Set a flag that widgets can check during their DrawInMiniMap
				WG['minimap'].isDrawingInPip = true
				
				-- Update module-level upvalues for the minimap API functions (avoids per-frame closures)
				-- For shaders: pass in world-normalized coords (NOT Y-flipped), shaders do their own flip
				minimapApiNormLeft = worldL / mapInfo.mapSizeX
				minimapApiNormRight = worldR / mapInfo.mapSizeX
				minimapApiNormBottom = worldB / mapInfo.mapSizeZ  -- world Z coords, shader will flip
				minimapApiNormTop = worldT / mapInfo.mapSizeZ
				minimapApiZoomLevel = mapInfo.mapSizeX / (worldR - worldL)
				
				-- Expose pre-created functions (no per-frame allocation)
				WG['minimap'].getNormalizedVisibleArea = minimapApiGetNormalizedVisibleArea
				WG['minimap'].getZoomLevel = minimapApiGetZoomLevel
				
				-- Compute rotation-aware ortho bounds for fixed-function GL widgets.
				-- Widgets handle rotation themselves via getCurrentMiniMapRotationOption(),
				-- so we do NOT apply GL rotation. Instead we compute ortho bounds that match
				-- each rotation's pixel coordinate mapping.
				--
				-- Widget pixel coordinate conventions per rotation:
				--   DEG_0:   pixelX = worldX/mapX * sx,            pixelY = sz - worldZ/mapZ * sz
				--   DEG_90:  pixelX = worldZ/mapZ * sx,            pixelY = worldX/mapX * sz
				--   DEG_180: pixelX = sx - worldX/mapX * sx,       pixelY = worldZ/mapZ * sz
				--   DEG_270: pixelX = sx - worldZ/mapZ * sx,       pixelY = sz - worldX/mapX * sz
				--
				-- We compute the ortho bounds [left, right, bottom, top] so that the pixel
				-- range corresponding to the visible world area maps to the full viewport.
				
				local rotCategory = 0
				if render.minimapRotation then
					rotCategory = math.floor((render.minimapRotation / math.pi * 2 + 0.5) % 4)
				end
				
				local visPixelLeft, visPixelRight, visPixelTop, visPixelBottom
				if rotCategory == 1 then -- 90°
					visPixelLeft   = worldT / mapInfo.mapSizeZ * minimapWidth
					visPixelRight  = worldB / mapInfo.mapSizeZ * minimapWidth
					visPixelBottom = worldL / mapInfo.mapSizeX * minimapHeight
					visPixelTop    = worldR / mapInfo.mapSizeX * minimapHeight
				elseif rotCategory == 2 then -- 180°
					visPixelLeft   = (1 - worldR / mapInfo.mapSizeX) * minimapWidth
					visPixelRight  = (1 - worldL / mapInfo.mapSizeX) * minimapWidth
					visPixelTop    = worldB / mapInfo.mapSizeZ * minimapHeight
					visPixelBottom = worldT / mapInfo.mapSizeZ * minimapHeight
				elseif rotCategory == 3 then -- 270°
					visPixelLeft   = (1 - worldB / mapInfo.mapSizeZ) * minimapWidth
					visPixelRight  = (1 - worldT / mapInfo.mapSizeZ) * minimapWidth
					visPixelBottom = (1 - worldR / mapInfo.mapSizeX) * minimapHeight
					visPixelTop    = (1 - worldL / mapInfo.mapSizeX) * minimapHeight
				else -- 0° (default)
					visPixelLeft   = worldL / mapInfo.mapSizeX * minimapWidth
					visPixelRight  = worldR / mapInfo.mapSizeX * minimapWidth
					visPixelTop    = (1 - worldT / mapInfo.mapSizeZ) * minimapHeight
					visPixelBottom = (1 - worldB / mapInfo.mapSizeZ) * minimapHeight
				end
				
				for _, w in ipairs(widgetHandler.DrawInMiniMapList) do
					if w ~= widget then  -- Don't recursively call ourselves
						-- Save current matrices
						gl.MatrixMode(GL.PROJECTION)
						glFunc.PushMatrix()
						gl.LoadIdentity()
						
						-- Ortho maps the visible pixel range to NDC [-1,1], which maps to viewport.
						-- bottom > top flips Y so widget Y-down coords map correctly to screen.
						gl.Ortho(visPixelLeft, visPixelRight, visPixelBottom, visPixelTop, -1, 1)
						
						gl.MatrixMode(GL.MODELVIEW)
						glFunc.PushMatrix()
						gl.LoadIdentity()
						
						-- Set viewport to PIP area so NDC [-1,1] maps to our PIP screen coords
						gl.Viewport(render.dim.l, render.dim.b, minimapWidth, minimapHeight)
						
						-- Direct call instead of pcall closure to avoid per-widget per-frame allocations
						-- Errors will propagate but that's acceptable for performance
						local drawFunc = w.DrawInMiniMap
						if drawFunc then
							drawFunc(w, minimapWidth, minimapHeight)
						end
						
						-- Restore viewport to full screen
						gl.Viewport(0, 0, render.vsx, render.vsy)
						
						-- Restore matrices
						glFunc.PopMatrix()
						gl.MatrixMode(GL.PROJECTION)
						glFunc.PopMatrix()
						gl.MatrixMode(GL.MODELVIEW)
					end
				end
				
				-- Clear the flag and disable scissor
				WG['minimap'].isDrawingInPip = false
				gl.Scissor(false)
				
				-- Reset GL state that widgets may have left dirty
				glFunc.Texture(false)
				glFunc.Color(1, 1, 1, 1)
				gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
				gl.DepthTest(false)
				gl.DepthMask(false)
				gl.Culling(false)
				gl.PolygonMode(GL.FRONT_AND_BACK, GL.FILL)
				gl.LineWidth(1.0)
				-- Reset stencil state (attack range widget uses stencil)
				gl.StencilTest(false)
				gl.StencilMask(255)
				gl.StencilOp(GL.KEEP, GL.KEEP, GL.KEEP)
				gl.ColorMask(true, true, true, true)
			end
		end
	end

	-- Draw map markers and camera view bounds at full frame rate (not throttled with unitsTex)
	-- Drawn after DrawInMiniMap overlays so they appear on top of everything
	if isMinimapMode then
		local minimapWidth = render.dim.r - render.dim.l
		local minimapHeight = render.dim.t - render.dim.b
		gl.Scissor(render.dim.l, render.dim.b, minimapWidth, minimapHeight)

		if render.minimapRotation ~= 0 then
			local centerX = render.dim.l + minimapWidth / 2
			local centerY = render.dim.b + minimapHeight / 2
			glFunc.PushMatrix()
			glFunc.Translate(centerX, centerY, 0)
			glFunc.Rotate(render.minimapRotation * 180 / math.pi, 0, 0, 1)
			glFunc.Translate(-centerX, -centerY, 0)
		end

		DrawMapMarkers()
		DrawCameraViewBounds()

		if render.minimapRotation ~= 0 then
			glFunc.PopMatrix()
		end

		gl.Scissor(false)
	end

	-- Draw tracking indicators
	DrawTrackingIndicators()

	----------------------------------------------------------------------------------------------------
	-- Buttons and hover effects
	----------------------------------------------------------------------------------------------------
	if gl.R2tHelper then
		-- Update mouse hover state
		interactionState.isMouseOverPip = (mx >= render.dim.l and mx <= render.dim.r and my >= render.dim.b and my <= render.dim.t)

		-- Blit frame buttons
		if pipR2T.frameButtonsTex then
			gl.R2tHelper.BlendTexRect(pipR2T.frameButtonsTex, render.dim.l, render.dim.b, render.dim.r, render.dim.t, true)
		end

		-- Draw resize handle when showing on hover (hide in minimap mode if configured)
		if config.showButtonsOnHoverOnly and interactionState.isMouseOverPip and not (isMinimapMode and config.minimapModeHideMoveResize) then
			glFunc.Color(config.panelBorderColorDark)
			glFunc.LineWidth(1.0)
			glFunc.BeginEnd(glConst.TRIANGLES, ResizeHandleVertices)
		end

		-- Draw dynamic hover overlays
		-- Resize handle hover (skip in minimap mode if configured)
		local hover = false
		if not (isMinimapMode and config.minimapModeHideMoveResize) then
			hover = uiState.areResizing or false
			if mx >= render.dim.l and mx <= render.dim.r and my >= render.dim.b and my <= render.dim.t then
				if (render.dim.r-mx + my-render.dim.b <= render.usedButtonSize) then
					hover = true
					if WG['tooltip'] then
						WG['tooltip'].ShowTooltip('pip'..pipNumber, Spring.I18N('ui.pip.resize'), nil, nil, nil)
					end
				end
			end
			if hover then
				local mult = mbl and 4.5 or 1.5
				glFunc.Color(config.panelBorderColorDark[1]*mult, config.panelBorderColorDark[2]*mult, config.panelBorderColorDark[3]*mult, 1)
				glFunc.LineWidth(1.0)
				glFunc.BeginEnd(glConst.TRIANGLES, ResizeHandleVertices)
			end
		end

		-- Minimize button hover (skip in minimap mode)
		hover = false
		if not isMinimapMode or config.minimapModeShowButtons then
			if config.showButtonsOnHoverOnly and interactionState.isMouseOverPip then
				-- Draw minimize button base when showing on hover
				glFunc.Color(config.panelBorderColorDark)
				glFunc.Texture(false)
				render.RectRound(render.dim.r - render.usedButtonSize - render.elementPadding, render.dim.t - render.usedButtonSize - render.elementPadding, render.dim.r, render.dim.t, render.elementCorner, 0, 0, 0, 1)
				glFunc.Color(config.panelBorderColorLight)
				glFunc.Texture('LuaUI/Images/pip/PipShrink.png')
				
				-- Rotate icon opposite to maximize direction (points toward shrink position)
				local rotation = GetMaximizeIconRotation()
				local centerX = render.dim.r - render.usedButtonSize * 0.5
				local centerY = render.dim.t - render.usedButtonSize * 0.5
				glFunc.PushMatrix()
				glFunc.Translate(centerX, centerY, 0)
				glFunc.Rotate(rotation, 0, 0, 1)
				glFunc.Translate(-centerX, -centerY, 0)
				
				glFunc.TexRect(render.dim.r - render.usedButtonSize, render.dim.t - render.usedButtonSize, render.dim.r, render.dim.t)
				glFunc.PopMatrix()
				glFunc.Texture(false)
			end
			if mx >= render.dim.r - render.usedButtonSize - render.elementPadding and mx <= render.dim.r - render.elementPadding and
				my >= render.dim.t - render.usedButtonSize - render.elementPadding and my <= render.dim.t - render.elementPadding then
				hover = true
				if WG['tooltip'] then
					WG['tooltip'].ShowTooltip('pip'..pipNumber, Spring.I18N('ui.pip.minimize'), nil, nil, nil)
				end
				glFunc.Color(1,1,1,0.12)
				glFunc.Texture(false)
				render.RectRound(render.dim.r - render.usedButtonSize, render.dim.t - render.usedButtonSize, render.dim.r, render.dim.t, render.elementCorner*0.4, 1, 1, 1, 1)
				glFunc.Color(1, 1, 1, 1)
				glFunc.Texture('LuaUI/Images/pip/PipShrink.png')
				
				-- Rotate icon opposite to maximize direction (points toward shrink position)
				local rotation = GetMaximizeIconRotation()
				local centerX = render.dim.r - render.usedButtonSize * 0.5
				local centerY = render.dim.t - render.usedButtonSize * 0.5
				glFunc.PushMatrix()
				glFunc.Translate(centerX, centerY, 0)
				glFunc.Rotate(rotation, 0, 0, 1)
				glFunc.Translate(-centerX, -centerY, 0)
				
				glFunc.TexRect(render.dim.r - render.usedButtonSize, render.dim.t - render.usedButtonSize, render.dim.r, render.dim.t)
				glFunc.PopMatrix()
				glFunc.Texture(false)
			end
		end

		-- Bottom-left buttons hover and pip number
		DrawInteractiveOverlays(mx, my, render.usedButtonSize)
	end

	if not uiState.isAnimating then
		-- Display tracked player name at top-center of PIP (only when hovering)
		DrawTrackedPlayerName()

		-- Display resource bars when tracking a player camera (hidden when PIP is hovered)
		DrawTrackedPlayerResourceBars()

		-- Display minimap overlay when tracking a player camera (hidden when PIP is hovered)
		DrawTrackedPlayerMinimap()

		-- Draw box selection rectangle
		DrawBoxSelection()

		-- Draw area command circle
		DrawAreaCommand()

		-- Draw build cursor with rotation applied
		DrawBuildCursorWithRotation()

		-- Draw formation dots overlay (command queues are now in R2T)
		DrawFormationDotsOverlay()

		-- Display current max update rate (top-left corner)
		if config.showPipFps then
			local fontSize = 12
			local padding = 12
			font:Begin()
			font:SetTextColor(0.85, 0.85, 0.85, 1)
			font:SetOutlineColor(0, 0, 0, 0.5)
			local fpsText = string.format("%.0f FPS", pipR2T.contentCurrentUpdateRate)..'\n'..pipR2T.contentDrawTimeAverage
			if config.showPipTimers then
				fpsText = fpsText .. string.format(
					"\ntotal %.1fms  items %d\nfeat %.2f  proj %.2f\nexpl %.2f  icons %.2f",
					perfTimers.total * 1000, perfTimers.itemCount,
					perfTimers.features * 1000, perfTimers.projectiles * 1000,
					perfTimers.explosions * 1000, perfTimers.icons * 1000
				)
			end
			font:Print(fpsText, render.dim.l + padding, render.dim.t - (fontSize*1.6) - padding, fontSize*2, "no")
			font:End()
		end
	end

	-- Note: In minimap mode, we don't call gl.DrawMiniMap() because it would render the engine
	-- minimap terrain on top of our PIP. The engine minimap is minimized instead.
	-- DrawInMiniMap overlays from other widgets are handled in RenderPipContents() during R2T.
	-- Widgets can check WG['minimap'].isPipMinimapActive() or WG['minimap'].isDrawingInPip to adapt.

	glFunc.Color(1, 1, 1, 1)
end

function widget:DrawWorld()
	-- Skip if fully minimized (no world view to show)
	if uiState.inMinMode and not uiState.isAnimating then return end
	
	-- In minimap mode, don't draw pip view rectangle in world
	if isMinimapMode then return end

	-- Draw rectangle outline in world view marking PIP boundaries
	if config.showViewRectangleInWorld and not interactionState.trackingPlayerID then
		local r, g, b = 1, 1, 1

		local innerLineDist = 8
		local cornerSize = 11
		local lineWidthMult = 0.66 + (render.vsy / 4000)
		gl.DepthTest(false)
		glFunc.LineWidth(7*lineWidthMult)
		glFunc.Color(0, 0, 0, 0.05)
		glFunc.BeginEnd(glConst.LINE_STRIP, DrawGroundBox, render.world.l, render.world.r, render.world.b, render.world.t, cornerSize)
		glFunc.Color(0, 0, 0, 0.015)
		glFunc.BeginEnd(glConst.LINE_STRIP, DrawGroundBox, render.world.l+innerLineDist, render.world.r-innerLineDist, render.world.b+innerLineDist, render.world.t-innerLineDist, cornerSize*0.65)
		glFunc.LineWidth(2.5*lineWidthMult)
		glFunc.Color(r, g, b, 0.25)
		glFunc.BeginEnd(glConst.LINE_STRIP, DrawGroundBox, render.world.l, render.world.r, render.world.b, render.world.t, cornerSize)
		glFunc.Color(r, g, b, 0.045)
		glFunc.BeginEnd(glConst.LINE_STRIP, DrawGroundBox, render.world.l+innerLineDist, render.world.r-innerLineDist, render.world.b-innerLineDist, render.world.t+innerLineDist, cornerSize*0.65)
	end

	-- Note: Formation lines are not drawn in world view (customformations widget handles this)

	-- Draw build drag line if actively dragging
	local dragCount = #interactionState.buildDragPositions
	if interactionState.areBuildDragging and dragCount > 1 then
		glFunc.Color(1, 1, 0, 0.6)
		glFunc.LineWidth(2.0)
		gl.LineStipple(true)
		gl.DepthTest(true)
		glFunc.BeginEnd(GL.LINE_STRIP, function()
			for i = 1, dragCount do
				local pos = interactionState.buildDragPositions[i]
				local wy = spFunc.GetGroundHeight(pos.wx, pos.wz)
				glFunc.Vertex(pos.wx, wy + 5, pos.wz)
			end
		end)
		gl.LineStipple(false)
		gl.DepthTest(false)
		glFunc.LineWidth(1.0)
	end

	-- Draw area command radius circle if actively dragging
	if interactionState.areAreaDragging then
		local mx, my = spFunc.GetMouseState()
		local wx, wz = PipToWorldCoords(mx, my)
		local startWX, startWZ = PipToWorldCoords(interactionState.areaCommandStartX, interactionState.areaCommandStartY)
		local dx = wx - startWX
		local dz = wz - startWZ
		local radius = math.sqrt(dx * dx + dz * dz)

		if radius > 5 then -- Only draw if dragged more than 5 elmos
			local _, cmdID = Spring.GetActiveCommand()
			if cmdID and cmdID > 0 then
				local color = cmdColors[cmdID] or cmdColors.unknown
				local wy = spFunc.GetGroundHeight(startWX, startWZ)

				gl.DepthTest(true)
				gl.Blending(GL.SRC_ALPHA, GL.ONE)

				-- Draw filled circle with additive blending
				glFunc.Color(color[1], color[2], color[3], 0.25)
				gl.DrawGroundCircle(startWX, wy, startWZ, radius, 32)

				gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
				gl.DepthTest(false)
			end
		end
	end

	glFunc.Color(1, 1, 1, 1)
end

function widget:DrawInMiniMap(minimapWidth, minimapHeight)
	-- In minimap mode, don't draw PIP viewport rectangle on the minimap (we ARE the minimap)
	if isMinimapMode then return end
	if uiState.inMinMode then return end
	if not config.showViewRectangleOnMinimap then return end

	-- Calculate the viewport in world space
	local wcx, wcz = cameraState.wcx, cameraState.wcz
	local pipWidth = render.dim.r - render.dim.l
	local pipHeight = render.dim.t - render.dim.b
	local hw = 0.5 * pipWidth / cameraState.zoom
	local hh = 0.5 * pipHeight / cameraState.zoom
	
	-- At 90/270 degrees, the world dimensions are swapped relative to screen
	-- We need to swap the rectangle dimensions to match what's actually visible
	local rotDeg = 0
	if render.minimapRotation then
		rotDeg = math.abs(render.minimapRotation * 180 / math.pi) % 360
	end
	local isRotated90 = (rotDeg > 45 and rotDeg < 135) or (rotDeg > 225 and rotDeg < 315)
	if isRotated90 then
		hw, hh = hh, hw
	end
	
	-- The minimap itself is rotated, so we need to transform the world position
	-- to account for the minimap's rotation
	local worldX, worldZ = wcx, wcz
	if render.minimapRotation and render.minimapRotation ~= 0 then
		-- Rotate the center point by the inverse of minimap rotation
		-- around the map center
		local mapCenterX = mapInfo.mapSizeX / 2
		local mapCenterZ = mapInfo.mapSizeZ / 2
		local dx = worldX - mapCenterX
		local dz = worldZ - mapCenterZ
		local cos_a = math.cos(-render.minimapRotation)
		local sin_a = math.sin(-render.minimapRotation)
		worldX = mapCenterX + (dx * cos_a - dz * sin_a)
		worldZ = mapCenterZ + (dx * sin_a + dz * cos_a)
	end
	
	-- Convert to minimap coordinates
	local centerX = (worldX / mapInfo.mapSizeX) * minimapWidth
	local centerY = (1 - (worldZ / mapInfo.mapSizeZ)) * minimapHeight
	
	-- Convert half-dimensions to minimap pixel size
	local halfWidth = (hw / mapInfo.mapSizeX) * minimapWidth
	local halfHeight = (hh / mapInfo.mapSizeZ) * minimapHeight
	
	-- Draw rectangle showing PIP view area (team-colored if tracking player)
	-- Use same resolution-scaled line widths as the PIP border shape
	local linewidth = 1.5 * ((render.vsx + 1000) / 3000)
	local outlinewidth = 3 * ((render.vsx + 1000) / 3000)
	glFunc.Texture(false)
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	glFunc.PushMatrix()
	
	-- Translate to center and rotate
	glFunc.Translate(centerX, centerY, 0)
	if render.minimapRotation and render.minimapRotation ~= 0 then
		glFunc.Rotate(render.minimapRotation * 180 / math.pi, 0, 0, 1)
	end
	
	-- Draw dark background rectangle (centered at origin after transform)
	-- Use same fixed screen-pixel chamfer as PIP border (2.5 pixels at 1080p)
	-- Stays constant regardless of zoom level
	local chamfer = 2.5 * (render.vsy / 1080)
	local cx = chamfer
	local cy = chamfer

	-- draw dark outline
	glFunc.Color(0, 0, 0, 0.4)
	glFunc.LineWidth(outlinewidth)
	glFunc.BeginEnd(GL.LINE_LOOP, function()
		-- Bottom edge
		glFunc.Vertex(-halfWidth + cx, -halfHeight)
		glFunc.Vertex(halfWidth - cx, -halfHeight)
		-- Bottom-right corner cut
		glFunc.Vertex(halfWidth, -halfHeight + cy)
		-- Right edge
		glFunc.Vertex(halfWidth, halfHeight - cy)
		-- Top-right corner cut
		glFunc.Vertex(halfWidth - cx, halfHeight)
		-- Top edge
		glFunc.Vertex(-halfWidth + cx, halfHeight)
		-- Top-left corner cut
		glFunc.Vertex(-halfWidth, halfHeight - cy)
		-- Left edge
		glFunc.Vertex(-halfWidth, -halfHeight + cy)
		-- Bottom-left corner cut closes the loop
	end)

	-- Use team color if tracking a player, otherwise white
	local r, g, b = 0.85, 0.85, 0.85
	if interactionState.trackingPlayerID then
		local _, _, _, teamID = spFunc.GetPlayerInfo(interactionState.trackingPlayerID, false)
		if teamID then
			r, g, b = Spring.GetTeamColor(teamID)
		end
	end

	-- draw bright line
	glFunc.Color(r, g, b, 0.8)
	glFunc.LineWidth(linewidth)
	glFunc.BeginEnd(GL.LINE_LOOP, function()
		-- Bottom edge
		glFunc.Vertex(-halfWidth + cx, -halfHeight)
		glFunc.Vertex(halfWidth - cx, -halfHeight)
		-- Bottom-right corner cut
		glFunc.Vertex(halfWidth, -halfHeight + cy)
		-- Right edge
		glFunc.Vertex(halfWidth, halfHeight - cy)
		-- Top-right corner cut
		glFunc.Vertex(halfWidth - cx, halfHeight)
		-- Top edge
		glFunc.Vertex(-halfWidth + cx, halfHeight)
		-- Top-left corner cut
		glFunc.Vertex(-halfWidth, halfHeight - cy)
		-- Left edge
		glFunc.Vertex(-halfWidth, -halfHeight + cy)
		-- Bottom-left corner cut closes the loop
	end)

	glFunc.LineWidth(1.0)
	glFunc.Color(1, 1, 1, 1)
	glFunc.PopMatrix()
end

-- Timer for periodic ghost building cleanup (checks ghosts outside PIP viewport)
-- ghostCleanupTimer stored in cache table to avoid a top-level local
cache.ghostCleanupTimer = 0

function widget:Update(dt)
	-- Skip ALL heavy processing when minimized and not animating.
	-- DrawScreen/DrawWorld already return early when minimized, so ghost cleanup,
	-- TV camera, zoom interpolation, hover detection, etc. are pure waste.
	if uiState.inMinMode and not uiState.isAnimating then
		return
	end

	-- Periodic ghost building cleanup: remove ghosts whose position is now in LOS
	-- The draw-path check only catches ghosts within the PIP viewport; this catches all of them
	local cleanupAllyTeam
	if not cameraState.mySpecState then
		cleanupAllyTeam = Spring.GetMyAllyTeamID()
	elseif state.losViewEnabled and state.losViewAllyTeam then
		cleanupAllyTeam = state.losViewAllyTeam
	end
	if cleanupAllyTeam then
		cache.ghostCleanupTimer = cache.ghostCleanupTimer + dt
		if cache.ghostCleanupTimer >= 1.0 then  -- check every 1 second
			cache.ghostCleanupTimer = 0
			for gID, ghost in pairs(ghostBuildings) do
				local gy = spFunc.GetGroundHeight(ghost.x, ghost.z)
				if spFunc.IsPosInLos(ghost.x, gy, ghost.z, cleanupAllyTeam) then
					-- Position is in LOS but unitID is not visible (not alive) — building was destroyed
					if not spFunc.GetUnitDefID(gID) then
						ghostBuildings[gID] = nil
					end
				end
			end
		end
	end

	-- Periodic self-destruct refresh: validate cached selfDUnits set every SELFD_REFRESH_INTERVAL frames
	-- Catches edge cases where UnitCommand callin might miss a cancellation (e.g. from synced code)
	selfDRefreshCounter = selfDRefreshCounter + 1
	if selfDRefreshCounter >= SELFD_REFRESH_INTERVAL then
		selfDRefreshCounter = 0
		for uID in pairs(selfDUnits) do
			local selfDTime = spFunc.GetUnitSelfDTime(uID)
			if not selfDTime or selfDTime <= 0 then
				selfDUnits[uID] = nil
			end
		end
	end

	-- Periodically re-read the leftClickMove config in case another widget changed it
	if isMinimapMode then
		cache.leftClickMoveTimer = (cache.leftClickMoveTimer or 0) + dt
		if cache.leftClickMoveTimer >= 2.0 then
			cache.leftClickMoveTimer = 0
			local cur = Spring.GetConfigInt("MinimapLeftClickMove", 1) == 1
			if cur ~= config.leftButtonPansCamera then
				config.leftButtonPansCamera = cur
			end
		end
	end

	-- In minimap mode, check if rotation changed and recalculate dimensions if needed
	if isMinimapMode then
		local currentRotation = Spring.GetMiniMapRotation and Spring.GetMiniMapRotation() or 0
		
		-- Only care about rotation category changes (0°/180° vs 90°/270°)
		local function getRotationCategory(rot)
			local rotDeg = math.abs(rot * 180 / math.pi) % 360
			if (rotDeg > 80 and rotDeg < 100) or (rotDeg > 260 and rotDeg < 280) then
				return 1  -- 90° or 270°
			else
				return 0  -- 0° or 180°
			end
		end
		
		local currentCategory = getRotationCategory(currentRotation)
		local lastCategory = getRotationCategory(render.lastMinimapRotation or 0)
		
		if currentCategory ~= lastCategory then
			-- Rotation category changed, recalculate dimensions preserving relative zoom
			render.lastMinimapRotation = currentRotation
			local oldMin = minimapModeMinZoom or cameraState.zoom
			-- Calculate zoom ratio relative to old fitZoom (1.0 = fully zoomed out)
			local zoomRatio = cameraState.zoom / oldMin
			local targetZoomRatio = cameraState.targetZoom / oldMin
			miscState.minimapCameraRestored = true
			widget:ViewResize()  -- Recalculates dimensions and minimapModeMinZoom
			-- Apply same ratio to new fitZoom so relative zoom is preserved
			local newMin = minimapModeMinZoom or oldMin
			cameraState.zoom = math.max(newMin * zoomRatio, newMin)
			cameraState.targetZoom = math.max(newMin * targetZoomRatio, newMin)
			cameraState.wcx = cameraState.targetWcx
			cameraState.wcz = cameraState.targetWcz
		else
			-- Just update the stored rotation for rendering
			render.minimapRotation = currentRotation
		end
	else
		-- Non-minimap mode: detect rotation category changes and re-clamp camera
		local currentRotation = Spring.GetMiniMapRotation and Spring.GetMiniMapRotation() or 0
		local function getRotCat(rot)
			local rotDeg = math.abs(rot * 180 / math.pi) % 180
			return (rotDeg > 45 and rotDeg < 135) and 1 or 0
		end
		local curCat = getRotCat(currentRotation)
		local lastCat = getRotCat(render.lastMinimapRotation or 0)
		render.minimapRotation = currentRotation
		if curCat ~= lastCat then
			render.lastMinimapRotation = currentRotation
			-- Recalculate dynamic min zoom (rotation-independent)
			local pipWidth, pipHeight = GetEffectivePipDimensions()
			local rawW = render.dim.r - render.dim.l
			local rawH = render.dim.t - render.dim.b
			local newMinZoom = math.min(rawW, rawH) / math.max(mapInfo.mapSizeX, mapInfo.mapSizeZ)
			pipModeMinZoom = newMinZoom
			-- Clamp zoom to new min if needed
			if cameraState.zoom < pipModeMinZoom then
				cameraState.zoom = pipModeMinZoom
				cameraState.targetZoom = pipModeMinZoom
			end
			if cameraState.targetZoom < pipModeMinZoom then
				cameraState.targetZoom = pipModeMinZoom
			end
			-- Re-clamp camera position with new effective dimensions
			local visibleWorldWidth = pipWidth / cameraState.zoom
			local visibleWorldHeight = pipHeight / cameraState.zoom
			cameraState.wcx = ClampCameraAxis(cameraState.wcx, visibleWorldWidth, mapInfo.mapSizeX, config.mapEdgeMargin)
			cameraState.wcz = ClampCameraAxis(cameraState.wcz, visibleWorldHeight, mapInfo.mapSizeZ, config.mapEdgeMargin)
			cameraState.targetWcx = cameraState.wcx
			cameraState.targetWcz = cameraState.wcz
			RecalculateWorldCoordinates()
			RecalculateGroundTextureCoordinates()
		end
	end
	
	-- Monitor dynamic water/lava level changes
	if mapInfo.isLava or mapInfo.hasWater then
		local lavaLevel = Spring.GetGameRulesParam("lavaLevel")
		if lavaLevel and lavaLevel ~= -99999 then
			-- Lava gadget is active and has set a real level
			if mapInfo.dynamicWaterLevel ~= lavaLevel then
				local oldLevel = mapInfo.dynamicWaterLevel
				mapInfo.dynamicWaterLevel = lavaLevel
				-- Check if the level actually changed enough to warrant a redraw
				if not oldLevel or math.abs(lavaLevel - oldLevel) > 0.5 then
					pipR2T.contentNeedsUpdate = true
				end
			end
		end
	end
	
	-- In minimap mode, ensure the old minimap widget stays disabled
	-- (it may load after us due to widget layer ordering)
	if isMinimapMode and not miscState.minimapWidgetDisabled then
		local minimapWidget = widgetHandler:FindWidget("Minimap")
		if minimapWidget then
			widgetHandler:DisableWidget("Minimap")
		end
		-- Also ensure the engine minimap stays minimized
		Spring.SendCommands("minimap minimize 1")
		miscState.minimapWidgetDisabled = true
	end

	-- In minimap mode, poll MinimapMinimize to honour the user's minimize setting
	if isMinimapMode then
		local wantMinimized = Spring.GetConfigInt("MinimapMinimize", 0) == 1
		if wantMinimized ~= miscState.minimapMinimized then
			miscState.minimapMinimized = wantMinimized
			-- Always keep the engine minimap minimized (we replace it)
			Spring.SendCommands("minimap minimize 1")
			-- Update guishader blur: remove when hidden, re-add when shown
			if wantMinimized then
				if WG['guishader'] then
					if WG['guishader'].RemoveDlist then
						WG['guishader'].RemoveDlist('pip'..pipNumber)
					elseif WG['guishader'].RemoveRect then
						WG['guishader'].RemoveRect('pip'..pipNumber)
					end
				end
			else
				UpdateGuishaderBlur()
			end
		end
	end
	
	-- Update spectating state and check if it changed
	local oldSpecState = cameraState.mySpecState
	local specState, fullviewState = Spring.GetSpectatingState()
	cameraState.mySpecState = specState

	-- If spec state changed, update LOS texture
	if oldSpecState ~= cameraState.mySpecState then
		pipR2T.losNeedsUpdate = true
	end

	-- Detect fullview transitions BEFORE the periodic scan, so timer resets
	-- take effect on the same frame (avoids 1-frame delay).
	if miscState.lastFullview ~= nil and miscState.lastFullview and not fullviewState and specState then
		pipR2T.losNeedsUpdate = true
		pipR2T.contentNeedsUpdate = true
		pipR2T.unitsNeedsUpdate = true
	elseif miscState.lastFullview ~= nil and not miscState.lastFullview and fullviewState and specState then
		-- Fullview OFF→ON: do NOT clear ghosts (fullview state can oscillate across frames).
		-- Force immediate rescan so ghosts are populated before a possible quick OFF toggle.
		miscState.specGhostScanTime = 0
		pipR2T.losNeedsUpdate = true
		pipR2T.contentNeedsUpdate = true
		pipR2T.unitsNeedsUpdate = true
	end
	miscState.lastFullview = fullviewState

	-- While fullview is ON, periodically scan enemy buildings and record ghosts
	-- for buildings the viewed allyteam has seen (INLOS or PREVLOS).
	-- Uses mark-and-sweep: marks existing ghosts, unmarks those found alive,
	-- then sweeps stale entries (destroyed buildings).
	-- Scan every 2 seconds for responsive ghost updates.
	if specState and fullviewState then
		local now = os.clock()
		if now - miscState.specGhostScanTime >= 2.0 then
			miscState.specGhostScanTime = now
			-- Use losViewAllyTeam when LOS view is active, otherwise GetMyAllyTeamID()
			local scanAllyTeam = (state.losViewEnabled and state.losViewAllyTeam) or Spring.GetMyAllyTeamID()
			-- Mark all existing ghosts for sweep
			local stale = {}
			for gID in pairs(ghostBuildings) do stale[gID] = true end
			local allUnits = Spring.GetAllUnits()
			for i = 1, #allUnits do
				local uID = allUnits[i]
				local defID = Spring.GetUnitDefID(uID)
				if defID and cache.isBuilding[defID] then
					local uTeam = Spring.GetUnitTeam(uID)
					if uTeam then
						local uAllyTeam = Spring.GetTeamAllyTeamID(uTeam)
						if uAllyTeam ~= scanAllyTeam then
							-- Only record/keep buildings the viewed allyteam has seen (INLOS or PREVLOS).
							-- With fullview, GetUnitLosState reliably returns any allyteam's LOS.
							-- stale[uID] is only cleared inside the PREVLOS check so ghosts for
							-- buildings the allyteam has NEVER seen get swept (not preserved).
							local losBits = Spring.GetUnitLosState(uID, scanAllyTeam, true)
							if losBits and (losBits % 2 >= 1 or losBits % 8 >= 4) then
								stale[uID] = nil  -- seen and still alive, don't sweep
								local x, _, z = Spring.GetUnitBasePosition(uID)
								if x then
									local g = ghostBuildings[uID]
									if g then
										g.defID = defID; g.x = x; g.z = z; g.teamID = uTeam
									else
										ghostBuildings[uID] = { defID = defID, x = x, z = z, teamID = uTeam }
									end
								end
							end
						end
					end
				end
			end
			-- Sweep stale ghosts (buildings destroyed while we had fullview)
			for gID in pairs(stale) do
				ghostBuildings[gID] = nil
			end
		end
	end

	-- Update mouse hover state
	local mx, my = spFunc.GetMouseState()
	local wasMouseOver = interactionState.isMouseOverPip
	-- Add nil safety for render.dim values
	if render.dim.l and render.dim.r and render.dim.b and render.dim.t then
		interactionState.isMouseOverPip = (mx >= render.dim.l and mx <= render.dim.r and my >= render.dim.b and my <= render.dim.t and not uiState.inMinMode)
	else
		interactionState.isMouseOverPip = false
	end

	-- Update hovered unit for icon highlighting (throttled for performance with many units)
	-- Only check every 0.1 seconds or when mouse moves significantly
	-- Skip entirely during active zoom for better performance
	local currentTime = os.clock()
	local mouseMoveThreshold = 10  -- pixels
	local hoverCheckInterval = 0.1  -- seconds
	local mouseMovedSignificantly = math.abs(mx - interactionState.lastHoverCheckX) > mouseMoveThreshold or
	                                 math.abs(my - interactionState.lastHoverCheckY) > mouseMoveThreshold
	local shouldCheckHover = (currentTime - interactionState.lastHoverCheckTime) > hoverCheckInterval or mouseMovedSignificantly
	local isZooming = interactionState.areIncreasingZoom or interactionState.areDecreasingZoom

	if interactionState.isMouseOverPip and shouldCheckHover and not isZooming then
		interactionState.lastHoverCheckTime = currentTime
		interactionState.lastHoverCheckX = mx
		interactionState.lastHoverCheckY = my

		local _, cmdID = Spring.GetActiveCommand()
		local wx, wz = PipToWorldCoords(mx, my)
		local unitID = GetUnitAtPoint(wx, wz)

		-- Only highlight units when there's an active command that can target units
		if cmdID and cmdID > 0 then  -- Positive cmdID means it's a command (not a build command)
			-- Don't highlight units for PATROL and FIGHT (they target ground)
			if cmdID == CMD.PATROL or cmdID == CMD.FIGHT then
				drawData.hoveredUnitID = nil
			-- Validate if this unit is a valid target for the command
			elseif unitID then
				local isValidTarget = true
				local isAlly = Spring.IsUnitAllied(unitID)
				local setTargetCmd = GameCMD and GameCMD.UNIT_SET_TARGET_NO_GROUND

				-- Commands that can only target enemy units
				if cmdID == CMD.ATTACK or (setTargetCmd and cmdID == setTargetCmd) or cmdID == CMD.CAPTURE then
					isValidTarget = not isAlly
				-- Commands that can only target allied units
				elseif cmdID == CMD.GUARD or cmdID == CMD.REPAIR or cmdID == CMD.LOAD_UNITS then
					isValidTarget = isAlly
				-- Commands that work on both allies and enemies are fine (RECLAIM, RESURRECT, RESTORE, etc.)
				end

				drawData.hoveredUnitID = isValidTarget and unitID or nil
			else
				drawData.hoveredUnitID = nil
			end
		-- No active command - check if we should highlight for transport loading or attack
		elseif unitID then
			local selectedUnits = Spring.GetSelectedUnits()
			local shouldHighlight = false
			local isAlly = Spring.IsUnitAllied(unitID)

			if isAlly then
				-- Check if any transport in selection can load this target unit
				for i = 1, #selectedUnits do
					if CanTransportLoadUnit(selectedUnits[i], unitID) then
						shouldHighlight = true
						break
					end
				end
			else
				-- Enemy unit - check if any selected unit can attack
				-- But don't highlight neutral units
				local allyTeam = Spring.GetUnitAllyTeam(unitID)
				local isNeutral = (allyTeam == gaiaAllyTeamID)
				
				-- Check if unit is visible (LOS or radar)
				local checkAllyTeamID = cameraState.myAllyTeamID
				if interactionState.trackingPlayerID and cameraState.mySpecState then
					local _, _, _, teamID = spFunc.GetPlayerInfo(interactionState.trackingPlayerID, false)
					checkAllyTeamID = select(6, spFunc.GetTeamInfo(teamID, false))
				end
				local losState = spFunc.GetUnitLosState(unitID, checkAllyTeamID)
				local isVisibleOrRadar = losState and (losState.los or losState.radar)
				
				if not isNeutral and isVisibleOrRadar then
					for i = 1, #selectedUnits do
						local uDefID = spFunc.GetUnitDefID(selectedUnits[i])
						if uDefID and cache.canAttack[uDefID] then
							shouldHighlight = true
							break
						end
					end
				end
			end

			drawData.hoveredUnitID = shouldHighlight and unitID or nil
		else
			drawData.hoveredUnitID = nil
		end
	elseif isZooming then
		-- Clear hover during zoom to avoid stale highlights
		drawData.hoveredUnitID = nil
	elseif not interactionState.isMouseOverPip then
		-- Only clear if mouse left the PIP
		drawData.hoveredUnitID = nil
	end
	-- Otherwise keep the last cached hover value to prevent flickering
	
	-- If hover state changed, update frame buttons
	if wasMouseOver ~= interactionState.isMouseOverPip and config.showButtonsOnHoverOnly then
		pipR2T.frameNeedsUpdate = true
	end

	-- Track selection and tracking state changes for frame updates
	local selectedUnits = Spring.GetSelectedUnits()
	local currentSelectionCount = #selectedUnits
	local currentTrackingState = interactionState.areTracking ~= nil
	local currentPlayerTrackingState = interactionState.trackingPlayerID ~= nil
	if not lastSelectionCount then lastSelectionCount = 0 end
	if not lastTrackingState then lastTrackingState = false end
	if not lastPlayerTrackingState then lastPlayerTrackingState = false end

	if currentSelectionCount ~= lastSelectionCount or currentTrackingState ~= lastTrackingState or currentPlayerTrackingState ~= lastPlayerTrackingState then
		pipR2T.frameNeedsUpdate = true
		lastSelectionCount = currentSelectionCount
		lastTrackingState = currentTrackingState
		lastPlayerTrackingState = currentPlayerTrackingState
	end

	-- Check if selectionbox widget state has changed and update command colors accordingly
	local selectionboxEnabled = widgetHandler:IsWidgetKnown("Selectionbox") and (widgetHandler.orderList["Selectionbox"] and widgetHandler.knownWidgets["Selectionbox"].active)
	if selectionboxEnabled ~= drawData.lastSelectionboxEnabled then
		drawData.lastSelectionboxEnabled = selectionboxEnabled
		if selectionboxEnabled then
			-- Selectionbox widget is now enabled, disable engine's default selection box
			Spring.LoadCmdColorsConfig('mouseBoxLineWidth 0')
		else
			-- Selectionbox widget is now disabled, restore engine's default selection box
			Spring.LoadCmdColorsConfig('mouseBoxLineWidth 1.5')
		end
	end

	-- Verify actual mouse button states to prevent stuck button tracking
	-- This handles cases where MouseRelease events don't fire (e.g., button released outside widget)
	local mouseX, mouseY, leftButton, middleButton, rightButton = spFunc.GetMouseState()
	if not leftButton and interactionState.leftMousePressed then
		interactionState.leftMousePressed = false
	end
	if not leftButton and interactionState.pipMinimapDragging then
		interactionState.pipMinimapDragging = false
	end
	if not rightButton and interactionState.rightMousePressed then
		interactionState.rightMousePressed = false
	end
	if not middleButton and interactionState.middleMousePressed then
		interactionState.middleMousePressed = false
	end

	-- If no buttons are actually pressed but we think we're panning with left+right, stop panning
	if interactionState.arePanning and not interactionState.panToggleMode and not leftButton and not rightButton and not middleButton then
		interactionState.arePanning = false
	end

	-- Update wall-clock time (always advances, even when paused — used for blink/pulse animations)
	wallClockTime = wallClockTime + dt

	-- Update game time (only when game is not paused)
	local _, _, isPaused = Spring.GetGameSpeed()
	if not isPaused then
		gameTime = gameTime + dt
	end

	-- Handle minimize/maximize animation
	if uiState.isAnimating then
		-- Guard: ensure animStartDim and animEndDim are properly initialized
		if not AreDimensionsValid(uiState.animStartDim) or not AreDimensionsValid(uiState.animEndDim) then
			RecoverInvalidAnimationState()
		else
			uiState.animationProgress = uiState.animationProgress + (dt / uiState.animationDuration)
			pipR2T.contentNeedsUpdate = true  -- Update during animation
			pipR2T.frameNeedsUpdate = true  -- Frame also needs update during animation

			if uiState.animationProgress >= 1 then
				-- Animation complete
				uiState.animationProgress = 1
				uiState.isAnimating = false
				render.dim.l = uiState.animEndDim.l
				render.dim.r = uiState.animEndDim.r
				render.dim.b = uiState.animEndDim.b
				render.dim.t = uiState.animEndDim.t
				-- Recalculate min zoom from final dimensions (fixes zoom limit after expanding from minimized)
				if not isMinimapMode then
					local rawW = render.dim.r - render.dim.l
					local rawH = render.dim.t - render.dim.b
					pipModeMinZoom = math.min(rawW, rawH) / math.max(mapInfo.mapSizeX, mapInfo.mapSizeZ)
					if cameraState.zoom < pipModeMinZoom then
						cameraState.zoom = pipModeMinZoom
						cameraState.targetZoom = pipModeMinZoom
					end
					if cameraState.targetZoom < pipModeMinZoom then
						cameraState.targetZoom = pipModeMinZoom
					end
				end
				-- Recalculate world coordinates for final dimensions
				RecalculateWorldCoordinates()
				RecalculateGroundTextureCoordinates()
				pipR2T.frameNeedsUpdate = true  -- Final update after animation
				-- Update guishader blur after animation completes
				UpdateGuishaderBlur()
			else
				-- Interpolate dimensions with easing (ease-in-out)
				local t = uiState.animationProgress
				local ease = t < 0.5 and 2 * t * t or 1 - math.pow(-2 * t + 2, 2) / 2

				render.dim.l = uiState.animStartDim.l + (uiState.animEndDim.l - uiState.animStartDim.l) * ease
				render.dim.r = uiState.animStartDim.r + (uiState.animEndDim.r - uiState.animStartDim.r) * ease
				render.dim.b = uiState.animStartDim.b + (uiState.animEndDim.b - uiState.animStartDim.b) * ease
				render.dim.t = uiState.animStartDim.t + (uiState.animEndDim.t - uiState.animStartDim.t) * ease

				RecalculateWorldCoordinates()
				RecalculateGroundTextureCoordinates()
				-- Update guishader blur continuously during animation
				UpdateGuishaderBlur()
			end
		end
	end

	-- Activity focus: restore camera after hold duration expires
	if miscState.activityFocusActive and miscState.activityFocusEnabled then
		local elapsed = os.clock() - miscState.activityFocusTime
		if elapsed >= config.activityFocusDuration then
			-- Restore saved camera position
			if miscState.activityFocusSavedWcx then
				cameraState.targetWcx = miscState.activityFocusSavedWcx
				cameraState.targetWcz = miscState.activityFocusSavedWcz
				cameraState.targetZoom = miscState.activityFocusSavedZoom
			end
			miscState.activityFocusActive = false
		end
	end

	-- TV mode: auto-camera controller (drives camera targets each frame)
	-- Pause TV camera when user is manually interacting or hovering, with a resume delay
	-- Stop entirely at game over so the zoom-out animation plays uninterrupted
	if miscState.tvEnabled and pipTV.camera.active and not miscState.isGameOver then
		local userInteracting = interactionState.arePanning
			or interactionState.areIncreasingZoom
			or interactionState.areDecreasingZoom
			or interactionState.isMouseOverPip
		if userInteracting then
			-- Record when user last interacted, don't update TV camera
			pipTV.camera.lastUserInteraction = os.clock()
		elseif pipTV.camera.lastUserInteraction and (os.clock() - pipTV.camera.lastUserInteraction) < 0.6 then
			-- Resume delay: wait 0.6s after user stops interacting
		else
			pipTV.camera.lastUserInteraction = nil
			pipTV.CameraUpdate(dt)
			-- NOTE: We intentionally do NOT set pipR2T.contentNeedsUpdate = true here.
			-- The oversized texture + UV-drift system handles camera movement smoothly,
			-- re-rendering only when camera drift exceeds the texture margin (~70% consumed).
			-- Forcing contentNeedsUpdate every frame would bypass this optimization and
			-- cause expensive full R2T re-renders at 60fps instead of ~3-5fps.
		end
	end

	-- Smooth zoom and camera center interpolation
	local zoomNeedsUpdate = math.abs(cameraState.zoom - cameraState.targetZoom) > 0.001
	local centerNeedsUpdate = math.abs(cameraState.wcx - cameraState.targetWcx) > 0.1 or math.abs(cameraState.wcz - cameraState.targetWcz) > 0.1

	-- GameOver zoom-out animation: keep updating content until complete
	if miscState.gameOverZoomingOut then
		if zoomNeedsUpdate or centerNeedsUpdate then
			pipR2T.contentNeedsUpdate = true
		else
			-- Zoom-out animation complete
			miscState.gameOverZoomingOut = false
		end
	end

	-- If zoom-to-cursor is active, continuously recalculate target center to keep world position under cursor
	-- Disable this when tracking units - we want to keep the camera centered on tracked units
	if cameraState.zoomToCursorActive and zoomNeedsUpdate and not interactionState.areTracking then
		local screenOffsetX = cameraState.zoomToCursorScreenX - (render.dim.l + render.dim.r) * 0.5
		local screenOffsetY = cameraState.zoomToCursorScreenY - (render.dim.b + render.dim.t) * 0.5

		-- Apply inverse rotation to screen offsets if minimap is rotated
		if render.minimapRotation ~= 0 then
			local cosR = math.cos(-render.minimapRotation)
			local sinR = math.sin(-render.minimapRotation)
			local rotatedX = screenOffsetX * cosR - screenOffsetY * sinR
			local rotatedY = screenOffsetX * sinR + screenOffsetY * cosR
			screenOffsetX = rotatedX
			screenOffsetY = rotatedY
		end

		-- Calculate what center should be to keep the stored world position under the cursor with current target zoom
		cameraState.targetWcx = cameraState.zoomToCursorWorldX - screenOffsetX / cameraState.targetZoom
		cameraState.targetWcz = cameraState.zoomToCursorWorldZ + screenOffsetY / cameraState.targetZoom

		-- Apply same margin-based clamping as panning
		local pipWidth, pipHeight = GetEffectivePipDimensions()
		local visibleWorldWidth = pipWidth / cameraState.targetZoom
		local visibleWorldHeight = pipHeight / cameraState.targetZoom

		-- Clamp with per-axis margins (centers on axis when view exceeds map)
		-- In minimap mode at minimum zoom, force center on map
		if IsAtMinimumZoom(cameraState.targetZoom) then
			cameraState.targetWcx = mapInfo.mapSizeX / 2
			cameraState.targetWcz = mapInfo.mapSizeZ / 2
		else
			cameraState.targetWcx = ClampCameraAxis(cameraState.targetWcx, visibleWorldWidth, mapInfo.mapSizeX, config.mapEdgeMargin)
			cameraState.targetWcz = ClampCameraAxis(cameraState.targetWcz, visibleWorldHeight, mapInfo.mapSizeZ, config.mapEdgeMargin)
		end

		centerNeedsUpdate = true  -- Force center update
	end

	if zoomNeedsUpdate or centerNeedsUpdate then
		if zoomNeedsUpdate then
			cameraState.zoom = cameraState.zoom + (cameraState.targetZoom - cameraState.zoom) * math.min(dt * config.zoomSmoothness, 1)
			-- Snap to target when close enough to avoid the asymptotic interpolation
			-- never reaching exact fitZoom (which would leave a sliver of void)
			if math.abs(cameraState.zoom - cameraState.targetZoom) < 0.002 then
				cameraState.zoom = cameraState.targetZoom
			end
			-- Enforce zoom floor (can go stale after PIP resize / rotation change)
			local zoomMin = GetEffectiveZoomMin()
			if cameraState.zoom < zoomMin then cameraState.zoom = zoomMin end
			if cameraState.targetZoom < zoomMin then cameraState.targetZoom = zoomMin end
		end

		-- Calculate bounds for CURRENT zoom level
		-- When rotated 90°/270°, swap pip dimensions for world coordinate calculations
		local pipWidth = render.dim.r - render.dim.l
		local pipHeight = render.dim.t - render.dim.b
		
		-- Check if we're rotated 90° or 270°
		local isRotated90 = false
		if render.minimapRotation then
			local rotDeg = math.abs(render.minimapRotation * 180 / math.pi) % 180
			if rotDeg > 45 and rotDeg < 135 then
				isRotated90 = true
				-- Swap dimensions for world calculations when rotated
				pipWidth, pipHeight = pipHeight, pipWidth
			end
		end
		
		local currentVisibleWorldWidth = pipWidth / cameraState.zoom
		local currentVisibleWorldHeight = pipHeight / cameraState.zoom
		local currentMarginX = currentVisibleWorldWidth * config.mapEdgeMargin
		local currentMarginZ = currentVisibleWorldHeight * config.mapEdgeMargin

		local currentMinWcx = currentVisibleWorldWidth / 2 - currentMarginX
		local currentMaxWcx = mapInfo.mapSizeX - (currentVisibleWorldWidth / 2 - currentMarginX)
		local currentMinWcz = currentVisibleWorldHeight / 2 - currentMarginZ
		local currentMaxWcz = mapInfo.mapSizeZ - (currentVisibleWorldHeight / 2 - currentMarginZ)

		-- When view exceeds map in an axis, force center (min >= max means view > map + 2*margin)
		local currentForceCenterX = currentMinWcx >= currentMaxWcx
		local currentForceCenterZ = currentMinWcz >= currentMaxWcz
		if currentForceCenterX then
			currentMinWcx = mapInfo.mapSizeX / 2
			currentMaxWcx = mapInfo.mapSizeX / 2
		end
		if currentForceCenterZ then
			currentMinWcz = mapInfo.mapSizeZ / 2
			currentMaxWcz = mapInfo.mapSizeZ / 2
		end

		-- Also calculate bounds for TARGET zoom level to detect if we WILL hit an edge
		local targetVisibleWorldWidth = pipWidth / cameraState.targetZoom
		local targetVisibleWorldHeight = pipHeight / cameraState.targetZoom
		local targetMarginX = targetVisibleWorldWidth * config.mapEdgeMargin
		local targetMarginZ = targetVisibleWorldHeight * config.mapEdgeMargin

		local targetMinWcx = targetVisibleWorldWidth / 2 - targetMarginX
		local targetMaxWcx = mapInfo.mapSizeX - (targetVisibleWorldWidth / 2 - targetMarginX)
		local targetMinWcz = targetVisibleWorldHeight / 2 - targetMarginZ
		local targetMaxWcz = mapInfo.mapSizeZ - (targetVisibleWorldHeight / 2 - targetMarginZ)

		if targetMinWcx >= targetMaxWcx then
			targetMinWcx = mapInfo.mapSizeX / 2
			targetMaxWcx = mapInfo.mapSizeX / 2
		end
		if targetMinWcz >= targetMaxWcz then
			targetMinWcz = mapInfo.mapSizeZ / 2
			targetMaxWcz = mapInfo.mapSizeZ / 2
		end

		-- Detect if at edge: either currently at edge, OR would be pushed by target zoom bounds
		-- This handles both zooming from outside map AND zooming near edges inside map
		local atLeftEdge = currentForceCenterX or cameraState.wcx <= currentMinWcx + 1 or cameraState.wcx <= targetMinWcx + 1
		local atRightEdge = currentForceCenterX or cameraState.wcx >= currentMaxWcx - 1 or cameraState.wcx >= targetMaxWcx - 1
		local atTopEdge = currentForceCenterZ or cameraState.wcz <= currentMinWcz + 1 or cameraState.wcz <= targetMinWcz + 1
		local atBottomEdge = currentForceCenterZ or cameraState.wcz >= currentMaxWcz - 1 or cameraState.wcz >= targetMaxWcz - 1

		if centerNeedsUpdate then
			-- Use different smoothness values depending on context
			local smoothnessToUse = config.centerSmoothness -- Default for zoom-to-cursor and panning
			if miscState.isSwitchingViews then
				smoothnessToUse = config.switchSmoothness -- Fast transition for view switching
			elseif interactionState.trackingPlayerID then
				smoothnessToUse = config.playerTrackingSmoothness -- Slower, smoother tracking for player camera
			elseif interactionState.areTracking then
				-- When tracking units and also zooming, use zoom smoothness for the center animation
				-- so that both animations stay in sync (otherwise panning lags behind zooming near edges)
				if zoomNeedsUpdate then
					smoothnessToUse = config.zoomSmoothness
				else
					smoothnessToUse = config.trackingSmoothness -- Smoother animation for unit tracking mode
				end
			end

			local centerFactor = math.min(dt * smoothnessToUse, 1)
			
			-- When zooming near edges, we need to handle two cases:
			-- 1. Already AT the edge (position at current boundary) -> directly track the edge (snap)
			-- 2. Approaching the edge (detected via target bounds) -> smoothly transition toward edge
			-- The edge position itself changes smoothly with zoom, so snapping when AT edge gives smooth motion
			if zoomNeedsUpdate then
				-- Check if we're actually AT the current edge (within 2 world units)
				local atCurrentLeftEdge = cameraState.wcx <= currentMinWcx + 2
				local atCurrentRightEdge = cameraState.wcx >= currentMaxWcx - 2
				local atCurrentTopEdge = cameraState.wcz <= currentMinWcz + 2
				local atCurrentBottomEdge = cameraState.wcz >= currentMaxWcz - 2
				
				if atLeftEdge then
					if atCurrentLeftEdge then
						-- Already at edge - directly track it (edge position changes with zoom)
						cameraState.wcx = currentMinWcx
					else
						-- Approaching edge - smoothly transition toward it
						local edgeFactor = math.min(dt * config.zoomSmoothness * 0.5, 1)
						cameraState.wcx = cameraState.wcx + (currentMinWcx - cameraState.wcx) * edgeFactor
					end
					cameraState.targetWcx = currentMinWcx
				elseif atRightEdge then
					if atCurrentRightEdge then
						cameraState.wcx = currentMaxWcx
					else
						local edgeFactor = math.min(dt * config.zoomSmoothness * 0.5, 1)
						cameraState.wcx = cameraState.wcx + (currentMaxWcx - cameraState.wcx) * edgeFactor
					end
					cameraState.targetWcx = currentMaxWcx
				else
					cameraState.wcx = cameraState.wcx + (cameraState.targetWcx - cameraState.wcx) * centerFactor
				end
				
				if atTopEdge then
					if atCurrentTopEdge then
						cameraState.wcz = currentMinWcz
					else
						local edgeFactor = math.min(dt * config.zoomSmoothness * 0.5, 1)
						cameraState.wcz = cameraState.wcz + (currentMinWcz - cameraState.wcz) * edgeFactor
					end
					cameraState.targetWcz = currentMinWcz
				elseif atBottomEdge then
					if atCurrentBottomEdge then
						cameraState.wcz = currentMaxWcz
					else
						local edgeFactor = math.min(dt * config.zoomSmoothness * 0.5, 1)
						cameraState.wcz = cameraState.wcz + (currentMaxWcz - cameraState.wcz) * edgeFactor
					end
					cameraState.targetWcz = currentMaxWcz
				else
					cameraState.wcz = cameraState.wcz + (cameraState.targetWcz - cameraState.wcz) * centerFactor
				end
			else
				-- Not zooming, normal interpolation
				cameraState.wcx = cameraState.wcx + (cameraState.targetWcx - cameraState.wcx) * centerFactor
				cameraState.wcz = cameraState.wcz + (cameraState.targetWcz - cameraState.wcz) * centerFactor
			end
		end

		-- Final clamp based on current zoom
		cameraState.wcx = math.min(math.max(cameraState.wcx, currentMinWcx), currentMaxWcx)
		cameraState.wcz = math.min(math.max(cameraState.wcz, currentMinWcz), currentMaxWcz)
		
		-- In minimap mode at minimum zoom, force exact center to prevent any drift
		if IsAtMinimumZoom(cameraState.zoom) then
			cameraState.wcx = mapInfo.mapSizeX / 2
			cameraState.wcz = mapInfo.mapSizeZ / 2
			cameraState.targetWcx = cameraState.wcx
			cameraState.targetWcz = cameraState.wcz
		end

		RecalculateWorldCoordinates()
		RecalculateGroundTextureCoordinates()
	else
		-- Zoom and center have reached their targets, disable zoom-to-cursor and switch transition
		cameraState.zoomToCursorActive = false
		miscState.isSwitchingViews = false
	end

	-- Activity focus: re-assert target position each frame while active
	-- Edge/center clamping at low zoom levels overwrites targetWcx/targetWcz;
	-- re-applying from stored marker coords ensures the camera reaches the marker
	-- Cancel if the user is actively panning or zooming the PIP
	if miscState.activityFocusActive and miscState.activityFocusTargetX then
		if interactionState.arePanning or interactionState.areIncreasingZoom or interactionState.areDecreasingZoom then
			-- User is interacting — cancel focus and don't restore saved camera
			miscState.activityFocusActive = false
		else
			cameraState.targetWcx = miscState.activityFocusTargetX
			cameraState.targetWcz = miscState.activityFocusTargetZ
			cameraState.targetZoom = math.max(config.activityFocusZoom, GetEffectiveZoomMin())
		end
	end

	if interactionState.areIncreasingZoom then
		cameraState.targetZoom = math.min(cameraState.targetZoom * config.zoomRate ^ dt, GetEffectiveZoomMax())

		-- Clamp BOTH current and target camera positions to respect margin
		-- Use current zoom for current position, target zoom for target position
		local pipWidth = render.dim.r - render.dim.l
		local pipHeight = render.dim.t - render.dim.b
		
		-- Swap dimensions when rotated 90°/270°
		if render.minimapRotation then
			local rotDeg = math.abs(render.minimapRotation * 180 / math.pi) % 180
			if rotDeg > 45 and rotDeg < 135 then
				pipWidth, pipHeight = pipHeight, pipWidth
			end
		end

		-- Clamp current animated position
		local currentVisibleWorldWidth = pipWidth / cameraState.zoom
		local currentVisibleWorldHeight = pipHeight / cameraState.zoom

		cameraState.wcx = ClampCameraAxis(cameraState.wcx, currentVisibleWorldWidth, mapInfo.mapSizeX, config.mapEdgeMargin)
		cameraState.wcz = ClampCameraAxis(cameraState.wcz, currentVisibleWorldHeight, mapInfo.mapSizeZ, config.mapEdgeMargin)

		-- Clamp target position
		local targetVisibleWorldWidth = pipWidth / cameraState.targetZoom
		local targetVisibleWorldHeight = pipHeight / cameraState.targetZoom

		cameraState.targetWcx = ClampCameraAxis(cameraState.targetWcx, targetVisibleWorldWidth, mapInfo.mapSizeX, config.mapEdgeMargin)
		cameraState.targetWcz = ClampCameraAxis(cameraState.targetWcz, targetVisibleWorldHeight, mapInfo.mapSizeZ, config.mapEdgeMargin)

		-- Don't recalculate here - will be done below in the main zoom/center update block
	elseif interactionState.areDecreasingZoom then
		cameraState.targetZoom = math.max(cameraState.targetZoom / config.zoomRate ^ dt, GetEffectiveZoomMin())

		-- Clamp BOTH current and target camera positions to respect margin
		-- Use current zoom for current position, target zoom for target position
		local pipWidth = render.dim.r - render.dim.l
		local pipHeight = render.dim.t - render.dim.b
		
		-- Swap dimensions when rotated 90°/270°
		if render.minimapRotation then
			local rotDeg = math.abs(render.minimapRotation * 180 / math.pi) % 180
			if rotDeg > 45 and rotDeg < 135 then
				pipWidth, pipHeight = pipHeight, pipWidth
			end
		end

		-- Clamp current animated position
		local currentVisibleWorldWidth = pipWidth / cameraState.zoom
		local currentVisibleWorldHeight = pipHeight / cameraState.zoom

		cameraState.wcx = ClampCameraAxis(cameraState.wcx, currentVisibleWorldWidth, mapInfo.mapSizeX, config.mapEdgeMargin)
		cameraState.wcz = ClampCameraAxis(cameraState.wcz, currentVisibleWorldHeight, mapInfo.mapSizeZ, config.mapEdgeMargin)

		-- Clamp target position
		local targetVisibleWorldWidth = pipWidth / cameraState.targetZoom
		local targetVisibleWorldHeight = pipHeight / cameraState.targetZoom

		cameraState.targetWcx = ClampCameraAxis(cameraState.targetWcx, targetVisibleWorldWidth, mapInfo.mapSizeX, config.mapEdgeMargin)
		cameraState.targetWcz = ClampCameraAxis(cameraState.targetWcz, targetVisibleWorldHeight, mapInfo.mapSizeZ, config.mapEdgeMargin)

		-- Don't recalculate here - will be done below in the main zoom/center update block
	end

	if not gameHasStarted and not isMinimapMode then
		-- Only auto-focus on start position if not spectating or not tracking another player
		-- Don't do this in minimap mode - the minimap should show the full map
		local isSpec = Spring.GetSpectatingState()
		if not isSpec and not interactionState.trackingPlayerID then
			local newX, _, newZ = Spring.GetTeamStartPosition(Spring.GetMyTeamID())
			if newX ~= miscState.startX then
				miscState.startX, miscState.startZ = newX, newZ
				-- Apply map margin limits to start position
				local pipWidth, pipHeight = GetEffectivePipDimensions()
				local visibleWorldWidth = pipWidth / cameraState.zoom
				local visibleWorldHeight = pipHeight / cameraState.zoom
				cameraState.wcx = ClampCameraAxis(newX, visibleWorldWidth, mapInfo.mapSizeX, config.mapEdgeMargin)
				cameraState.wcz = ClampCameraAxis(newZ, visibleWorldHeight, mapInfo.mapSizeZ, config.mapEdgeMargin)
				cameraState.targetWcx, cameraState.targetWcz = cameraState.wcx, cameraState.wcz  -- Set targets instantly for start position
				RecalculateWorldCoordinates()
				RecalculateGroundTextureCoordinates()
			end
		end
	end

	-- Update player camera tracking (but not during view switching)
	if interactionState.trackingPlayerID and not miscState.isSwitchingViews then
		UpdatePlayerTracking()
	end

	-- Check for modifier key changes during box selection
	if interactionState.areBoxSelecting then
		local alt, ctrl, meta, shift = Spring.GetModKeyState()
		local modifiersChanged = alt ~= interactionState.lastModifierState[1] or ctrl ~= interactionState.lastModifierState[2] or
		   meta ~= interactionState.lastModifierState[3] or shift ~= interactionState.lastModifierState[4]

		-- Also check for units moving in/out of selection box (throttled to ~15fps for continuous updates)
		local currentTime = os.clock()
		local shouldUpdate = modifiersChanged or (currentTime - interactionState.lastBoxSelectUpdate) > 0.067

		if shouldUpdate then
			if modifiersChanged then
				interactionState.lastModifierState = {alt, ctrl, meta, shift}
				-- Update deselection mode based on Ctrl state
				interactionState.areBoxDeselecting = ctrl
			end

			-- Update selection (bypass throttle if modifiers changed, otherwise use throttle)
			interactionState.lastBoxSelectUpdate = currentTime
			local unitsInBox = GetUnitsInBox(interactionState.boxSelectStartX, interactionState.boxSelectStartY, interactionState.boxSelectEndX, interactionState.boxSelectEndY)

			-- Always use SmartSelect_SelectUnits if available - it handles all modifier logic
			if WG.SmartSelect_SelectUnits then
				WG.SmartSelect_SelectUnits(unitsInBox)
			else
				-- Fallback to engine default if smart select is disabled
				Spring.SelectUnitArray(unitsInBox, shift) -- shift = append mode
			end
		end
	end
end

function widget:GameStart()
	gameHasStarted = true

	-- Automatically maximize for players (only for the first PIP instance)
	if pipNumber == 1 and not cameraState.mySpecState and uiState.inMinMode then
		StartMaximizeAnimation()
	end

	-- Automatically track the commander at game start (not for spectators or minimap mode)
	local spec = Spring.GetSpectatingState()
	if not spec and not isMinimapMode then
		local commanderID = FindMyCommander()
		if commanderID then
			interactionState.areTracking = {commanderID}  -- Store as table/array
		end
	end

	-- On lava/water maps, read the lava level now that the gadget has initialized
	-- (may not have been available during widget module-level init)
	if mapInfo.isLava or mapInfo.hasWater then
		local lavaLevel = Spring.GetGameRulesParam("lavaLevel")
		if lavaLevel and lavaLevel ~= -99999 then
			if mapInfo.dynamicWaterLevel ~= lavaLevel then
				mapInfo.dynamicWaterLevel = lavaLevel
				pipR2T.contentNeedsUpdate = true
			end
		end
	end
end

function widget:UnitSeismicPing(x, y, z, strength, allyTeam, unitID, unitDefID)
	if uiState.inMinMode then return end

	local myAllyTeam = Spring.GetMyAllyTeamID()
	local spec, fullview = Spring.GetSpectatingState()
	local unitAllyTeam = unitID and Spring.GetUnitAllyTeam(unitID) or allyTeam

	if (spec or allyTeam == myAllyTeam) and unitAllyTeam ~= allyTeam then
		-- Calculate ping radius based on strength (strength is typically 1-10)
		-- Use larger base radius for visibility
		local maxRadius = 100 + math.min(strength, 20) * 15

		-- Add to seismic pings cache
		table.insert(cache.seismicPings, {
			x = x,
			z = z,
			strength = strength,
			maxRadius = maxRadius,
			startTime = gameTime,
			allyTeam = allyTeam,
		})

		-- Limit max seismic pings to prevent memory issues (drop oldest)
		local pingCount = #cache.seismicPings
		if pingCount > 50 then
			cache.seismicPings[1] = cache.seismicPings[pingCount]
			cache.seismicPings[pingCount] = nil
		end
	end
end

-- Helper function to create icon shatter effect for a unit
-- unitVelX, unitVelZ are optional velocity components to add to fragments
local function CreateIconShatter(unitID, unitDefID, unitTeam, unitVelX, unitVelZ)
	if uiState.inMinMode then return end
	-- Performance: limit max simultaneous shatters
	if #cache.iconShatters >= cache.maxIconShatters then return end

	-- Throttle shatters based on number of visible unit icons
	local iconCount = #miscState.pipUnits
	if iconCount >= 4000 then return end  -- no shatters at all above 4000 icons
	if iconCount >= 3000 then
		-- Only shatter big-footprint units (xsize*4 >= 16 means footprint >= 4)
		local xs = cache.xsizes[unitDefID]
		local zs = cache.zsizes[unitDefID]
		if not xs or (xs < 16 and (not zs or zs < 16)) then return end
	end

	-- Only shatter if unit has an icon
	if not cache.unitIcon[unitDefID] then return end

	-- Skip unfinished/under-construction units
	local _, _, _, _, buildProg = spFunc.GetUnitHealth(unitID)
	if buildProg and buildProg < 1 then return end

	-- Get unit position
	local ux, uy, uz = spFunc.GetUnitPosition(unitID)
	if not ux then return end

	-- Get icon data
	local iconData = cache.unitIcon[unitDefID]
	if not iconData or not iconData.size then return end -- Ensure icon has size data
	-- Engine-matching icon size (same as GL4DrawIcons/DrawIcons)
	local resScale = render.contentScale or 1
	local unitBaseSize = Spring.GetConfigFloat("MinimapIconScale", 3.5)
	local iconSize = unitBaseSize * (mapInfo.mapSizeX * mapInfo.mapSizeZ / 40000) ^ 0.25 * math.sqrt(cameraState.zoom) * resScale * iconData.size

	-- Skip shattering for tiny icons (too small to see fragments when zoomed out)
	if iconSize < 6 then return end

	-- Use fixed 2x2 or 3x3 grid for fewer, bigger fragments
	-- Adjust threshold based on actual rendered size
	local grid = iconSize < 40 and 2 or 3
	-- Icon is rendered at 2*iconSize (from -iconSize to +iconSize), so fragments need to match
	local fragSize = (iconSize * 2) / grid

	-- Get team color
	local teamColor = teamColors[unitTeam]
	if not teamColor then return end
	local teamR, teamG, teamB = teamColor[1], teamColor[2], teamColor[3]

	-- Convert unit velocity from world units to screen units (if provided)
	-- Scale by zoom to match fragment velocity scale
	local velModX = 0
	local velModZ = 0
	if unitVelX and unitVelZ then
		-- Convert world velocity to screen velocity (scale by zoom factor)
		-- Multiply by a factor to make the effect clearly visible
		local velScale = 10.0 / cameraState.zoom
		velModX = unitVelX * velScale
		velModZ = unitVelZ * velScale
	end

	-- Create fragments in a grid pattern - each fragment represents a unique piece of the texture
	local fragments = {}
	for gx = 0, grid - 1 do
		for gz = 0, grid - 1 do
			-- Calculate offset from center for this grid cell
			local offsetX = (gx - (grid - 1) / 2) * fragSize
			local offsetZ = (gz - (grid - 1) / 2) * fragSize

			-- Calculate angle from icon center to this fragment
			local angle = math.atan2(offsetZ, offsetX)
			-- Add small random variation
			angle = angle + (math.random() - 0.5) * 0.2

			-- Divide by zoom to compensate for gl.Scale transformation
			-- Use square root of iconSize to reduce the impact of larger icons on distance
			local speedVariation = 0.4 + math.random() * 1.2  -- 0.4 to 1.6
			local speed = ((25 + math.random() * 15) * (math.sqrt(iconSize) / 6.3) * 3.4 * speedVariation) / cameraState.zoom

			table.insert(fragments, {
				-- Store world coordinates (not PiP-local)
				wx = ux,
				wz = uz,
				-- Add unit velocity to fragment velocity
				vx = math.cos(angle) * speed + velModX,
				vz = math.sin(angle) * speed + velModZ,
				-- UV coordinates map each fragment to its portion of the texture
				-- Flip Y to match OpenGL texture coordinates (Y=0 at bottom)
				uvx1 = gx / grid,
				uvy1 = (grid - gz - 1) / grid,
				uvx2 = (gx + 1) / grid,
				uvy2 = (grid - gz) / grid,
				size = fragSize,
				-- Minor rotation: start with small random angle (0-20 degrees)
				rot = (math.random() - 0.5) * 20,
				-- Very slow rotation speed (max ±1 degree per frame, results in ~20 degrees total)
				rotSpeed = (math.random() - 0.5) * 1,
			})
		end
	end

	-- Add shatter effect with variable lifetime
	-- Smaller icons have shorter lifetimes, with additional random variation
	local baseLifetime = 0.4 + iconSize / 216
	local lifetimeVariation = 0.6 + math.random() * 0.8  -- 0.6 to 1.4 (±40% variation)

	-- Capture damage flash intensity at death time (for white flash on fragments)
	local flashIntensity = 0
	local flash = damageFlash[unitID]
	if flash then
		local flashAge = gameTime - flash.time
		if flashAge < DAMAGE_FLASH_DURATION then
			flashIntensity = flash.intensity * (1 - flashAge / DAMAGE_FLASH_DURATION)
		end
	end

	table.insert(cache.iconShatters, {
		startTime = gameTime,
		fragments = fragments,
		icon = iconData,
		teamR = teamR,
		teamG = teamG,
		teamB = teamB,
		duration = baseLifetime * lifetimeVariation,
		zoom = cameraState.zoom,  -- Store zoom factor to compensate for gl.Scale during rendering
		flashIntensity = flashIntensity,  -- Inherited damage flash (0-1)
	})
end

-- Called by unit_crashing_aircraft gadget when an aircraft starts crashing
function widget:CrashingAircraft(unitID, unitDefID, teamID)
	miscState.crashingUnits[unitID] = true
	selfDUnits[unitID] = nil
	
	-- Create shatter effect with unit's current velocity (skip when minimized)
	if not uiState.inMinMode then
		local vx, vy, vz = Spring.GetUnitVelocity(unitID)
		CreateIconShatter(unitID, unitDefID, teamID, vx, vz)
	end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
	-- Note: We intentionally do NOT clear crashingUnits here because DrawScreen may run
	-- after this callback in the same frame, and we need the entry to still exist so
	-- the crashing unit icon doesn't flash for one frame when it dies.
	-- The entry will remain in crashingUnits but this is harmless - it's just a boolean.

	-- TV mode: unit death event — weight based on unit cost
	if miscState.tvEnabled and unitDefID then
		local cost = cache.unitCost[unitDefID] or 100
		local weight = math.min(5, cost / 200)
		if weight > 0.2 then
			local x, _, z = spFunc.GetUnitBasePosition(unitID)
			if x then pipTV.AddEvent(x, z, weight, 'death') end
		end
	end

	-- Create shatter effect for non-crashing units (crashing units already shattered in CrashingAircraft)
	-- Skip when minimized — nothing is being drawn, shatters would be wasted
	if not miscState.crashingUnits[unitID] and not uiState.inMinMode then
		-- Get unit velocity so shatter fragments carry the unit's momentum
		local vx, vy, vz = Spring.GetUnitVelocity(unitID)
		CreateIconShatter(unitID, unitDefID, unitTeam, vx, vz)
		-- Suppress icon immediately so it doesn't linger during death animation
		miscState.crashingUnits[unitID] = true
	end
	-- Don't clear crashingUnits[unitID] here - let it persist to prevent icon flash

	-- Clear GL4 caches for this unit
	gl4Icons.unitDefCache[unitID] = nil
	gl4Icons.unitTeamCache[unitID] = nil

	-- Clear damage flash and self-destruct tracking
	damageFlash[unitID] = nil
	selfDUnits[unitID] = nil

	-- Clear ghost building: only remove if we have LOS on the position (or no LOS filtering active)
	-- For spectators with LOS view, the ghost should persist if the position is in FoW
	-- (the viewed allyteam doesn't know the building was destroyed yet)
	if ghostBuildings[unitID] then
		local ghost = ghostBuildings[unitID]
		if state.losViewEnabled and state.losViewAllyTeam then
			local gy = Spring.GetGroundHeight(ghost.x, ghost.z)
			if Spring.IsPosInLos(ghost.x, gy, ghost.z, state.losViewAllyTeam) then
				ghostBuildings[unitID] = nil  -- destroyed in LOS, remove ghost
			end
			-- else: destroyed in FoW, ghost persists until LOS reaches the position
		else
			ghostBuildings[unitID] = nil
		end
	end
	ownBuildingPosX[unitID] = nil
	ownBuildingPosZ[unitID] = nil
end

-- Handle unit team changes (give/take)
function widget:UnitGiven(unitID, unitDefID, newTeamID, oldTeamID)
	-- Clear GL4 cache so it picks up the new team color
	gl4Icons.unitTeamCache[unitID] = nil
	-- Force re-classification in keysort (new team may change colors/LOS)
	ownBuildingPosX[unitID] = nil
	ownBuildingPosZ[unitID] = nil
end

-- Handle buildings being picked up by transports — invalidate cached position
function widget:UnitLoaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	ownBuildingPosX[unitID] = nil
	ownBuildingPosZ[unitID] = nil
end

-- Handle buildings being dropped by transports — update cached position and ghost
function widget:UnitUnloaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	local x, _, z = spFunc.GetUnitBasePosition(unitID)
	if x and cache.isBuilding[unitDefID] then
		if cache.cantBeTransported[unitDefID] then
			ownBuildingPosX[unitID] = x
			ownBuildingPosZ[unitID] = z
		end
		-- Update ghost position if this was a tracked enemy building
		if ghostBuildings[unitID] then
			ghostBuildings[unitID].x = x
			ghostBuildings[unitID].z = z
		end
	end
end

-- Track enemy building positions for ghost rendering on PIP
-- Self-destruct tracking + Command FX
function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	-- Self-destruct tracking (event-driven, avoids per-frame GetUnitSelfDTime calls)
	if cmdID == CMD.SELFD then
		-- SELFD toggles: if already counting down, this cancels it; otherwise starts it
		local selfDTime = spFunc.GetUnitSelfDTime(unitID)
		if selfDTime and selfDTime > 0 then
			selfDUnits[unitID] = nil  -- was counting down, this command cancels it
		else
			selfDUnits[unitID] = true  -- start countdown
		end
	elseif cmdID == CMD.STOP then
		-- Stop cancels self-destruct
		selfDUnits[unitID] = nil
	end

	if not config.drawCommandFX then return end
	if uiState.inMinMode then return end

	-- Only show commands for the ally team we're "viewing as"
	local _, _, _, _, _, unitAllyTeam = spFunc.GetTeamInfo(unitTeam, false)
	if cameraState.mySpecState then
		-- Spectator: determine which ally team is relevant
		local viewAllyTeam = nil  -- nil = show all (fullview spectator, no tracking)
		if interactionState.trackingPlayerID then
			local _, _, _, playerTeamID = spFunc.GetPlayerInfo(interactionState.trackingPlayerID, false)
			if playerTeamID then
				viewAllyTeam = teamAllyTeamCache[playerTeamID] or Spring.GetTeamAllyTeamID(playerTeamID)
			end
		elseif state.losViewEnabled and state.losViewAllyTeam then
			viewAllyTeam = state.losViewAllyTeam
		else
			local _, fullview = Spring.GetSpectatingState()
			if not fullview then
				viewAllyTeam = Spring.GetMyAllyTeamID()
			end
		end
		if viewAllyTeam and unitAllyTeam ~= viewAllyTeam then return end
	else
		local myAllyTeam = Spring.GetMyAllyTeamID()
		if unitAllyTeam ~= myAllyTeam then return end
	end

	-- Skip gaia / critter units
	if unitTeam == gaiaTeamID then return end

	-- Skip commands to newly finished units (rally point / initial orders)
	if config.commandFXIgnoreNewUnits then
		local finishTime = commandFX.newUnits[unitID]
		if finishTime then
			if (gameTime - finishTime) < 0.3 then
				return
			else
				commandFX.newUnits[unitID] = nil
			end
		end
	end

	-- Get command color (skip unknown commands)
	local color = cmdColors[cmdID]
	if not color and cmdID < 0 then
		color = cmdColors.unknown  -- build commands
	end
	if not color then return end

	-- Resolve target position from command params
	local targetX, targetZ
	local nParams = cmdParams and #cmdParams or 0
	if nParams >= 3 then
		-- Position-based command: params = {x, y, z, ...}
		targetX, targetZ = cmdParams[1], cmdParams[3]
	elseif nParams == 1 then
		-- Unit or feature target
		local targetID = cmdParams[1]
		if targetID >= (Game.maxUnits or 32000) then
			local fx, _, fz = spFunc.GetFeaturePosition(targetID - (Game.maxUnits or 32000))
			if fx then targetX, targetZ = fx, fz end
		else
			local ux, _, uz = spFunc.GetUnitPosition(targetID)
			if ux then targetX, targetZ = ux, uz end
		end
	end
	if not targetX then return end

	-- Get start position: chain from previous command target if recent, else use unit position
	local startX, startZ
	local lastTarget = commandFX.lastTarget[unitID]
	if lastTarget and (wallClockTime - lastTarget.time) < 0.15 then
		-- Recent command in queue — chain from its target
		startX, startZ = lastTarget.x, lastTarget.z
	else
		-- First command or stale — start from unit position
		local ux, _, uz = spFunc.GetUnitPosition(unitID)
		if not ux then return end
		startX, startZ = ux, uz
	end

	-- Don't add if start and target are at same spot
	if math.abs(startX - targetX) < 1 and math.abs(startZ - targetZ) < 1 then
		-- Still update last target for further chaining
		commandFX.lastTarget[unitID] = { x = targetX, z = targetZ, time = wallClockTime }
		return
	end

	-- Update last target for this unit (for chaining subsequent commands)
	commandFX.lastTarget[unitID] = { x = targetX, z = targetZ, time = wallClockTime }

	-- Add to FX list (cap at max entries)
	if commandFX.count < commandFX.MAX then
		commandFX.count = commandFX.count + 1
		commandFX.list[commandFX.count] = {
			unitX = startX, unitZ = startZ,
			targetX = targetX, targetZ = targetZ,
			cmdID = cmdID,
			time = wallClockTime,
			color = color,
		}
	end
end

-- Track newly finished units to suppress their initial rally point command FX
function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if config.drawCommandFX and config.commandFXIgnoreNewUnits then
		commandFX.newUnits[unitID] = wallClockTime
	end

	-- Record newly completed enemy buildings as ghosts for spectators
	-- Catches buildings built outside the PIP viewport while fullview is ON
	-- Only ghost buildings the viewed allyteam has actually seen (PREVLOS or INLOS)
	if cameraState.mySpecState and cache.isBuilding[unitDefID] then
		local myAllyTeam = Spring.GetMyAllyTeamID()
		local uAllyTeam = Spring.GetTeamAllyTeamID(unitTeam)
		if uAllyTeam ~= myAllyTeam then
			local losBits = Spring.GetUnitLosState(unitID, myAllyTeam, true)
			if losBits and (losBits % 2 >= 1 or losBits % 8 >= 4) then
				local x, _, z = Spring.GetUnitBasePosition(unitID)
				if x then
					ghostBuildings[unitID] = { defID = unitDefID, x = x, z = z, teamID = unitTeam }
				end
			end
		end
	end

	-- TV mode: big unit finished event
	if miscState.tvEnabled and unitDefID then
		local cost = cache.unitCost[unitDefID] or 0
		if cost >= config.tvUnitFinishedCostThreshold then
			local weight = math.min(4, cost / 500)
			local x, _, z = spFunc.GetUnitBasePosition(unitID)
			if x then pipTV.AddEvent(x, z, weight, 'finished') end
		end
	end
end

-- UnitEnteredLos is only called for non-allied units entering the local player's LOS
-- We record the building's position so we can draw its icon when it leaves LOS
function widget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer)
	if uiState.inMinMode then return end  -- Skip damage flash + TV events when not visible
	if damage <= 0 then return end
	if paralyzer then damage = damage * 0.1 end  -- paralyzer visually counts for 1/10th
	local maxHP = UnitDefs[unitDefID] and UnitDefs[unitDefID].health or 1
	local intensity = math.min(1.0, damage / maxHP * 3)  -- scale up so small hits are visible too
	local existing = damageFlash[unitID]
	if existing and (gameTime - existing.time) < DAMAGE_FLASH_DURATION then
		-- Accumulate: boost intensity if already flashing
		existing.intensity = math.min(1.0, existing.intensity + intensity * 0.5)
		existing.time = gameTime
	else
		damageFlash[unitID] = { time = gameTime, intensity = intensity }
	end

	-- TV mode: combat event — weight based on damage/cost ratio
	if miscState.tvEnabled then
		local cost = cache.unitCost[unitDefID] or 100
		local weight = math.min(3, (damage / math.max(cost, 50)) * 2)
		if weight > 0.1 then
			local x, _, z = spFunc.GetUnitBasePosition(unitID)
			if x then pipTV.AddEvent(x, z, weight, 'combat') end
		end
	end
end

function widget:UnitEnteredLos(unitID, unitTeam)
	-- Skip for fullview spectators (they see everything, ghosts are recorded in processUnit)
	if cameraState.mySpecState then
		local _, fullview = Spring.GetSpectatingState()
		if fullview then return end
	end
	local unitDefID = spFunc.GetUnitDefID(unitID)
	if not unitDefID then return end
	if not cache.isBuilding[unitDefID] then return end
	local x, _, z = spFunc.GetUnitBasePosition(unitID)
	if not x then return end
	ghostBuildings[unitID] = { defID = unitDefID, x = x, z = z, teamID = unitTeam }
end

-- Handle explosions from weapons (called when a visible explosion occurs)
function widget:VisibleExplosion(px, py, pz, weaponID, ownerID)
	if uiState.inMinMode then return end
	if not config.drawExplosions then return end
	
	-- Skip specific weapons using cached data (e.g., footstep effects)
	if weaponID and cache.weaponSkipExplosion[weaponID] then
		return
	end
	
	-- Get explosion radius for visibility check
	local radius = 10
	if weaponID and cache.weaponExplosionRadius[weaponID] then
		radius = cache.weaponExplosionRadius[weaponID]
	end
	
	-- No zoom-based rejection: count-based filtering happens in DrawExplosions

	-- Check if this is a lightning weapon
	local isLightning = weaponID and cache.weaponIsLightning[weaponID]
	
	-- Check if this is a paralyze weapon
	local isParalyze = weaponID and cache.weaponIsParalyze[weaponID]

	-- Check if this is a Juno weapon
	local isJuno = weaponID and cache.weaponIsJuno[weaponID]
	
	-- Check if this is an anti-air weapon (skip AA explosions for now)
	local isAA = weaponID and cache.weaponIsAA[weaponID]
	if isAA then return end

	-- Detect unit death explosions (ownerID is the dying unit, already in crashingUnits)
	local isUnitExplosion = ownerID and miscState.crashingUnits[ownerID] or false

	-- Add explosion to list with radius from cached weapon data
	local radius = 10 -- Default radius
	if weaponID and cache.weaponExplosionRadius[weaponID] then
		radius = cache.weaponExplosionRadius[weaponID]
	end

	-- Skip very small explosions (below threshold), except for lightning
	if radius < 8 and not isLightning then
		return
	end

	-- Create explosion entry
	local explosion = {
		x = px,
		y = py,
		z = pz,
		radius = radius,
		startFrame = Spring.GetGameFrame(),  -- game-frame based: freezes when paused
		randomSeed = math.random() * 1000,  -- For consistent per-explosion randomness
		rotationSpeed = (math.random() - 0.5) * 4,  -- Random rotation speed
		particles = {},  -- Will store particle debris
		isLightning = isLightning,
		isParalyze = isParalyze,
		isJuno = isJuno,
		isAA = isAA,
		isUnitExplosion = isUnitExplosion,
		isBigFlash = false,  -- set below
	}

	-- Detect big flash explosions: nukes, commanders, large unit death explosions
	-- These get an additional white flash layer that fades fast then lingers
	if not isLightning and not isParalyze and not isJuno then
		if radius >= 100 then
			explosion.isBigFlash = true
		elseif isUnitExplosion and ownerID then
			local ownerDefID = Spring.GetUnitDefID(ownerID)
			if ownerDefID and cache.isCommander[ownerDefID] then
				explosion.isBigFlash = true
			end
		end
	end

	-- Add lightning sparks
	if isLightning then
		local sparkCount = 6 + math.floor(math.random() * 4) -- 6-9 sparks
		for i = 1, sparkCount do
			local angle = (i / sparkCount) * 2 * math.pi + (math.random() - 0.5) * 0.8
			local speed = 15 + math.random() * 20
			local vx = math.cos(angle) * speed
			local vz = math.sin(angle) * speed

			table.insert(explosion.particles, {
				x = 0,
				z = 0,
				vx = vx,
				vz = vz,
				life = 0.3 + math.random() * 0.2, -- 0.3-0.5 seconds
				size = 2 + math.random() * 2
			})
		end
	end

	table.insert(cache.explosions, explosion)

	-- TV mode: explosion event — weight based on radius
	if miscState.tvEnabled and radius >= 20 then
		local weight = math.min(4, radius / 60)
		pipTV.AddEvent(px, pz, weight, 'explosion')
	end

	-- Add particle debris for larger explosions
	if radius > 30 then
		local explosion = cache.explosions[#cache.explosions]
		local particleCount = math.min(12, math.floor(radius / 10))

		-- Massive explosions get way more particles and additional effects
		if radius > 150 then
			particleCount = math.min(24, math.floor(radius / 8))  -- More particles for nukes
		elseif radius > 80 then
			particleCount = math.min(18, math.floor(radius / 9))  -- More for large explosions
		end

		for i = 1, particleCount do
			local angle = (i / particleCount) * 2 * math.pi + (math.random() - 0.5) * 0.5
			local speed = 20 + math.random() * 30
			-- Bigger explosions = faster flying particles
			local speedMultiplier = 1
			if radius > 150 then
				speedMultiplier = 4  -- Nukes fly MUCH further (was 2.5)
			elseif radius > 80 then
				speedMultiplier = 2.5  -- Large explosions fly further (was 1.8)
			end
			-- Bigger particles for bigger explosions
			local sizeMultiplier = 1
			if radius > 150 then
				sizeMultiplier = 1.5
			elseif radius > 80 then
				sizeMultiplier = 1.25
			end
			table.insert(explosion.particles, {
				angle = angle,
				speed = speed * speedMultiplier,
				size = (2 + math.random() * 3) * 2 * sizeMultiplier,  -- Scaled by explosion size
				lifetime = speedMultiplier * 1.5  -- Particles from bigger explosions live even longer (was 1x)
			})
		end
	end

end

function widget:DefaultCommand()
	if uiState.inMinMode then return end
	local mx, my = spFunc.GetMouseState()
	if mx >= render.dim.l and mx <= render.dim.r and my >= render.dim.b and my <= render.dim.t then
		local wx, wz = PipToWorldCoords(mx, my)
		local uID = GetUnitAtPoint(wx, wz)
		if uID then
			if Spring.IsUnitAllied(uID) then
				return CMD.GUARD
			else
				return CMD.ATTACK
			end
		end
		local fID = GetFeatureAtPoint(wx, wz)
		if fID then
			return CMD.RECLAIM
		end
		return CMD.MOVE
	end
end

function widget:MapDrawCmd(playerID, cmdType, mx, my, mz, a, b, c)
	if uiState.inMinMode then return end
	-- Prevent infinite recursion when we call Spring.Marker* functions
	if miscState.isProcessingMapDraw then
		return false
	end

	-- Store point markers for rendering (from any player, but not spectators)
	if cmdType == 'point' then
		-- Get player's team and spec status
		local _, _, isSpec, teamID = Spring.GetPlayerInfo(playerID, false)

		-- Add marker if player is not a spectator, or if spectator pings are enabled in minimap mode
		local showMarker = not isSpec or (isMinimapMode and config.showSpectatorPings)
		if showMarker then
			-- Shorten lifetime of older nearby markers from the same player
			local now = os.clock()
			local proximityDist = 500  -- World units — "same general area"
			for j = #miscState.mapMarkers, 1, -1 do
				local old = miscState.mapMarkers[j]
				if old.playerID == playerID then
					local dx = old.x - mx
					local dz = old.z - mz
					if dx*dx + dz*dz < proximityDist * proximityDist then
						-- Mark for early fade-out (0.5s from now)
						if not old.fadeStart then
							old.fadeStart = now
						end
					end
				end
			end

			-- Add marker to list
			table.insert(miscState.mapMarkers, {
				x = mx,
				z = mz,
				time = now,
				teamID = teamID,
				playerID = playerID,
				isSpectator = isSpec
			})
			
			-- Force PIP content update to show marker immediately
			pipR2T.contentNeedsUpdate = true

			-- TV mode: map marker event (moderate weight)
			if miscState.tvEnabled then
				pipTV.AddEvent(mx, mz, 2.5, 'marker')
			end

			-- Activity focus: briefly move camera to this marker
			local triggerFocus = miscState.activityFocusEnabled and not miscState.tvEnabled
			if triggerFocus and config.activityFocusHideForSpectators and cameraState.mySpecState then
				triggerFocus = false
			end
			if triggerFocus and playerID == Spring.GetMyPlayerID() then
				triggerFocus = false
			end
			if triggerFocus and isSpec and config.activityFocusIgnoreSpectators then
				triggerFocus = false
			end
			-- Block activity focus for ignored players (uses WG.ignoredAccounts from api_ignore widget)
			if triggerFocus and config.activityFocusBlockIgnoredPlayers and WG.ignoredAccounts then
				local pName, _, _, _, _, _, _, _, _, _, pInfo = Spring.GetPlayerInfo(playerID)
				local pAccountID = pInfo and pInfo.accountid and tonumber(pInfo.accountid)
				if (pName and WG.ignoredAccounts[pName]) or (pAccountID and WG.ignoredAccounts[pAccountID]) then
					triggerFocus = false
				end
			end
			if triggerFocus and interactionState.trackingPlayerID then
				triggerFocus = false
			end
			if triggerFocus and interactionState.isMouseOverPip then
				triggerFocus = false
			end
			if triggerFocus and not gameHasStarted then
				triggerFocus = false
			end
			-- Per-player spam protection: cooldown, throttle, and mute
			if triggerFocus then
				local now = os.clock()
				local hist = miscState.activityFocusPlayerHistory[playerID]
				if not hist then
					hist = { timestamps = {}, mutedUntil = 0, throttledUntil = 0 }
					miscState.activityFocusPlayerHistory[playerID] = hist
				end
				-- Check if player is muted
				if now < hist.mutedUntil then
					triggerFocus = false
				-- Check if player is throttled
				elseif now < hist.throttledUntil then
					triggerFocus = false
				else
					-- Prune old timestamps outside the window
					local window = config.activityFocusThrottleWindow
					local pruned = {}
					for i = 1, #hist.timestamps do
						if now - hist.timestamps[i] < window then
							pruned[#pruned + 1] = hist.timestamps[i]
						end
					end
					hist.timestamps = pruned
					local count = #pruned
					-- Check mute threshold (most severe)
					if count >= config.activityFocusMuteCount then
						hist.mutedUntil = now + config.activityFocusMuteDuration
						hist.timestamps = {}
						triggerFocus = false
					-- Check throttle threshold
					elseif count >= config.activityFocusThrottleCount then
						hist.throttledUntil = now + config.activityFocusThrottleDuration
						triggerFocus = false
					-- Check per-marker cooldown (time since last marker from this player)
					elseif count > 0 and (now - pruned[count]) < config.activityFocusCooldown then
						triggerFocus = false
					end
					-- Record this marker timestamp (even if suppressed by cooldown)
					hist.timestamps[#hist.timestamps + 1] = now
				end
			end
			if triggerFocus and not miscState.activityFocusActive then
				-- Save current camera position before focusing
				miscState.activityFocusSavedWcx = cameraState.targetWcx
				miscState.activityFocusSavedWcz = cameraState.targetWcz
				miscState.activityFocusSavedZoom = cameraState.targetZoom
				-- Store marker position (re-asserted each frame to survive edge clamping)
				miscState.activityFocusTargetX = mx
				miscState.activityFocusTargetZ = mz
				-- Move camera to marker
				cameraState.targetWcx = mx
				cameraState.targetWcz = mz
				cameraState.targetZoom = math.max(config.activityFocusZoom, cameraState.targetZoom)
				miscState.activityFocusTime = os.clock()
				miscState.activityFocusActive = true
			elseif triggerFocus and miscState.activityFocusActive then
				-- Already focusing: update target to new marker, reset timer
				miscState.activityFocusTargetX = mx
				miscState.activityFocusTargetZ = mz
				cameraState.targetWcx = mx
				cameraState.targetWcz = mz
				miscState.activityFocusTime = os.clock()
			end
		end
	end

	-- Only process our own mapmarks for placement logic (not from other players)
	local myPlayerID = Spring.GetMyPlayerID()
	if playerID ~= myPlayerID then
		return false
	end

	-- The mx,my,mz parameters are world coordinates from where the camera is looking
	-- We need to check if the mapmark was initiated while mouse was over the PiP

	-- For point markers, use the stored initiation position (from double-click)
	-- For line/erase, use current mouse position (for continuous drawing)
	local screenX, screenY
	if cmdType == 'point' and miscState.mapmarkInitScreenX and miscState.mapmarkInitScreenY then
		-- Use the position where mapmark was initiated (double-click position)
		-- Check if it was recent (within last 10 seconds - allows time for typing message)
		if (os.clock() - miscState.mapmarkInitTime) < 10 then
			screenX = miscState.mapmarkInitScreenX
			screenY = miscState.mapmarkInitScreenY
			-- Clear the stored position after using it
			miscState.mapmarkInitScreenX = nil
			miscState.mapmarkInitScreenY = nil
		else
			-- Too old, use current position and clear stored position
			screenX, screenY = spFunc.GetMouseState()
			miscState.mapmarkInitScreenX = nil
			miscState.mapmarkInitScreenY = nil
		end
	else
		-- For line drawing and erase, use current mouse position
		screenX, screenY = spFunc.GetMouseState()
	end

	-- Check if the mouse was/is over the PiP window
	if screenX >= render.dim.l and screenX <= render.dim.r and screenY >= render.dim.b and screenY <= render.dim.t and not uiState.inMinMode then
		-- The mapmark was initiated while mouse was over PiP
		-- Translate the PiP screen position to world coordinates
		local wx, wz = PipToWorldCoords(screenX, screenY)
		if not wx or not wz then
			-- If translation fails, let default handler process it
			return false
		end

		local wy = spFunc.GetGroundHeight(wx, wz)
		-- Add small height offset so markers are visible above ground (except for erase)
		local markerHeight = wy + 5

		-- Now place the marker at the PiP world coordinates instead of camera world coordinates
		miscState.isProcessingMapDraw = true

		if cmdType == 'point' then
			-- Place marker at PiP location
			Spring.MarkerAddPoint(wx, markerHeight, wz, c or "")

		elseif cmdType == 'line' then
			-- For line drawing in PiP - track for continuous drawing

			-- If we have a previous position, draw line from there to here
			if interactionState.lastMapDrawX and interactionState.lastMapDrawZ then
				local lastY = spFunc.GetGroundHeight(interactionState.lastMapDrawX, interactionState.lastMapDrawZ) + 5
				Spring.MarkerAddLine(interactionState.lastMapDrawX, lastY, interactionState.lastMapDrawZ, wx, markerHeight, wz)
			end

			-- Update last position for next segment
			interactionState.lastMapDrawX = wx
			interactionState.lastMapDrawZ = wz

		elseif cmdType == 'erase' then
			-- Erase at the PiP location - use ground height for better detection
			Spring.MarkerErasePosition(wx, wy, wz)
		end

		miscState.isProcessingMapDraw = false
		return true -- Consume the original event to prevent double placement

	else
		-- Not over PiP, reset map drawing state and allow default handling
		if cmdType == 'line' or cmdType == 'erase' then
			interactionState.lastMapDrawX = nil
			interactionState.lastMapDrawZ = nil
		end
	end

	return false -- Let default handler process it
end

function widget:IsAbove(mx, my)
	-- Guard against uninitialized render dimensions
	if not render.dim.l or not render.dim.r or not render.dim.b or not render.dim.t then return false end

	-- When minimap is hidden via MinimapMinimize, don't capture mouse
	if isMinimapMode and miscState.minimapMinimized then return false end
	
	-- Claim mouse interaction when cursor is over the PIP window
	if uiState.isAnimating then
		-- During animation, check both start and end positions to ensure we capture the animated area
		if uiState.inMinMode then
			-- Animating to minimized - check the shrinking area
			return mx >= math.min(render.dim.l, uiState.minModeL) and mx <= math.max(render.dim.r, uiState.minModeL + math.floor(render.usedButtonSize*config.maximizeSizemult)) and
			       my >= math.min(render.dim.b, uiState.minModeB) and my <= math.max(render.dim.t, uiState.minModeB + math.floor(render.usedButtonSize*config.maximizeSizemult))
		else
			-- Animating to maximized - check the expanding area
			return mx >= math.min(render.dim.l, uiState.minModeL) and mx <= math.max(render.dim.r, uiState.minModeL + math.floor(render.usedButtonSize*config.maximizeSizemult)) and
			       my >= math.min(render.dim.b, uiState.minModeB) and my <= math.max(render.dim.t, uiState.minModeB + math.floor(render.usedButtonSize*config.maximizeSizemult))
		end
	elseif uiState.inMinMode then
		-- In minimized mode, check if over the minimize button area only
		local buttonSize = math.floor(render.usedButtonSize * config.maximizeSizemult)
		return mx >= uiState.minModeL and mx <= uiState.minModeL + buttonSize and my >= uiState.minModeB and my <= uiState.minModeB + buttonSize
	else
		-- In normal mode, check if over the PIP panel
		if not AreExpandedDimensionsValid(render.dim) then
			return false
		end
		return mx >= render.dim.l and mx <= render.dim.r and my >= render.dim.b and my <= render.dim.t
	end
end

function widget:MouseWheel(up, value)
	if not uiState.inMinMode then
		local mx, my = spFunc.GetMouseState()
		if mx >= render.dim.l and mx <= render.dim.r and my >= render.dim.b and my <= render.dim.t then
			-- Don't allow zooming when tracking a player's camera
			if interactionState.trackingPlayerID then
				return true
			end

			local oldZoom = cameraState.targetZoom

			-- Use |value| to scale the zoom step — at low FPS the engine coalesces
			-- multiple scroll ticks into a single MouseWheel call with a larger value.
			-- Ignoring it makes zooming feel sluggish when frames are slow.
			local absValue = math.abs(value)
			if absValue < 1 then absValue = 1 end
			local zoomFactor = config.zoomWheel ^ absValue

			if Spring.GetConfigInt("ScrollWheelSpeed", 1) > 0 then
				if up then
					cameraState.targetZoom = math.max(cameraState.targetZoom / zoomFactor, GetEffectiveZoomMin())
				else
					cameraState.targetZoom = math.min(cameraState.targetZoom * zoomFactor, GetEffectiveZoomMax())
				end
			else
				if not up then
					cameraState.targetZoom = math.max(cameraState.targetZoom / zoomFactor, GetEffectiveZoomMin())
				else
					cameraState.targetZoom = math.min(cameraState.targetZoom * zoomFactor, GetEffectiveZoomMax())
				end
			end

			-- If zoom-to-cursor is enabled and we're INCREASING zoom (getting closer), store the cursor world position
			-- Disable zoom-to-cursor when tracking units (always zoom to center)
			if config.zoomToCursor and cameraState.targetZoom > oldZoom and not interactionState.areTracking then
				-- Store screen position
				cameraState.zoomToCursorScreenX = mx
				cameraState.zoomToCursorScreenY = my

				-- Calculate and store the world position under cursor using CURRENT animated values
				-- This is critical - we need to use where we ARE now, not where we're going
				local screenOffsetX = mx - (render.dim.l + render.dim.r) * 0.5
				local screenOffsetY = my - (render.dim.b + render.dim.t) * 0.5

				-- Apply inverse rotation to screen offsets if minimap is rotated
				if render.minimapRotation ~= 0 then
					local cosR = math.cos(-render.minimapRotation)
					local sinR = math.sin(-render.minimapRotation)
					local rotatedX = screenOffsetX * cosR - screenOffsetY * sinR
					local rotatedY = screenOffsetX * sinR + screenOffsetY * cosR
					screenOffsetX = rotatedX
					screenOffsetY = rotatedY
				end

				-- Use current animated zoom and center, not targets
				cameraState.zoomToCursorWorldX = cameraState.wcx + screenOffsetX / cameraState.zoom
				cameraState.zoomToCursorWorldZ = cameraState.wcz - screenOffsetY / cameraState.zoom

				-- Enable continuous recalculation in Update
				cameraState.zoomToCursorActive = true
			else
				-- Decreasing zoom (pulling back) or feature disabled - disable zoom-to-cursor
				cameraState.zoomToCursorActive = false

				-- Clamp BOTH current and target camera positions to respect margin
				local pipWidth, pipHeight = GetEffectivePipDimensions()

				-- Clamp current animated position
				local currentVisibleWorldWidth = pipWidth / cameraState.zoom
				local currentVisibleWorldHeight = pipHeight / cameraState.zoom

				cameraState.wcx = ClampCameraAxis(cameraState.wcx, currentVisibleWorldWidth, mapInfo.mapSizeX, config.mapEdgeMargin)
				cameraState.wcz = ClampCameraAxis(cameraState.wcz, currentVisibleWorldHeight, mapInfo.mapSizeZ, config.mapEdgeMargin)

				-- Clamp target position
				local targetVisibleWorldWidth = pipWidth / cameraState.targetZoom
				local targetVisibleWorldHeight = pipHeight / cameraState.targetZoom

				cameraState.targetWcx = ClampCameraAxis(cameraState.targetWcx, targetVisibleWorldWidth, mapInfo.mapSizeX, config.mapEdgeMargin)
				cameraState.targetWcz = ClampCameraAxis(cameraState.targetWcz, targetVisibleWorldHeight, mapInfo.mapSizeZ, config.mapEdgeMargin)

				RecalculateWorldCoordinates()
				RecalculateGroundTextureCoordinates()
			end

			return true
		end
	end
end

function widget:MousePress(mx, my, mButton)
	-- Guard against uninitialized render dimensions
	if not render.dim.l or not render.dim.r or not render.dim.b or not render.dim.t then return end

	-- Track mapmark initiation position if mouse is over PiP (for point markers with double-click)
	if mx >= render.dim.l and mx <= render.dim.r and my >= render.dim.b and my <= render.dim.t and not uiState.inMinMode then
		miscState.mapmarkInitScreenX = mx
		miscState.mapmarkInitScreenY = my
		miscState.mapmarkInitTime = os.clock()
	end

	-- Handle click/drag on pip-minimap (if visible and not tracking player camera)
	local mmBounds = interactionState.pipMinimapBounds
	if mButton == 1 and mmBounds and not interactionState.trackingPlayerID and not uiState.inMinMode then
		if mx >= mmBounds.l and mx <= mmBounds.r and my >= mmBounds.b and my <= mmBounds.t then
			-- Convert screen position to world position and move camera there
			local mmWidth = mmBounds.drawR - mmBounds.drawL
			local mmHeight = mmBounds.drawT - mmBounds.drawB
			local relX = (mx - mmBounds.drawL) / mmWidth
			local relY = 1 - ((my - mmBounds.drawB) / mmHeight)  -- Flip Y (screen Y is bottom-up, map Z is top-down)
			
			-- Apply rotation to account for minimap rotation
			local minimapRotation = Spring.GetMiniMapRotation()
			if minimapRotation ~= 0 then
				-- Convert to center-based coordinates (0.5, 0.5 is center)
				local centeredX = relX - 0.5
				local centeredY = relY - 0.5
				
				-- Apply rotation (positive direction - Spring's rotation is CCW)
				local cosR = math.cos(minimapRotation)
				local sinR = math.sin(minimapRotation)
				local rotatedX = centeredX * cosR - centeredY * sinR
				local rotatedY = centeredX * sinR + centeredY * cosR
				
				-- Convert back to 0-1 range
				relX = rotatedX + 0.5
				relY = rotatedY + 0.5
			end
			
			local worldX = relX * mapInfo.mapSizeX
			local worldZ = relY * mapInfo.mapSizeZ
			
			-- Set camera target
			cameraState.targetWcx = math.max(0, math.min(mapInfo.mapSizeX, worldX))
			cameraState.targetWcz = math.max(0, math.min(mapInfo.mapSizeZ, worldZ))
			RecalculateWorldCoordinates()
			RecalculateGroundTextureCoordinates()
			
			-- Clear unit tracking when clicking minimap
			interactionState.areTracking = nil
			
			-- Start minimap dragging for continued movement
			interactionState.pipMinimapDragging = true
			interactionState.leftMousePressed = true
			
			return true  -- Consume the click
		end
	end

	-- Track mouse button states for left+right panning
	local wasLeftPressed = interactionState.leftMousePressed
	local wasRightPressed = interactionState.rightMousePressed

	if mButton == 1 then
		interactionState.leftMousePressed = true
	elseif mButton == 3 then
		interactionState.rightMousePressed = true
	end

	-- Check for left+right mouse button combination for panning (laptop friendly)
	-- Only start panning if we just pressed the SECOND button (the other was already down)
	if interactionState.leftMousePressed and interactionState.rightMousePressed and mx >= render.dim.l and mx <= render.dim.r and my >= render.dim.b and my <= render.dim.t then
		-- Check if this button press completes the combo (other button was already pressed)
		local isSecondButton = (mButton == 1 and wasRightPressed) or (mButton == 3 and wasLeftPressed)

		if isSecondButton then
			-- Cancel any ongoing operations
			if interactionState.areBuildDragging then
				interactionState.areBuildDragging = false
				interactionState.buildDragPositions = {}
			end
			if interactionState.areAreaDragging then
				interactionState.areAreaDragging = false
			end
			if interactionState.areBoxSelecting then
				interactionState.areBoxSelecting = false
				interactionState.areBoxDeselecting = false
				if WG.SmartSelect_ClearReference then
					WG.SmartSelect_ClearReference()
				end
			end
			if interactionState.areFormationDragging then
				interactionState.areFormationDragging = false
			end

			-- Start panning (but not when tracking player camera or at minimum zoom)
			if not interactionState.trackingPlayerID and not IsAtMinimumZoom(cameraState.zoom) then
				interactionState.arePanning = true
				interactionState.panStartX = (render.dim.l + render.dim.r) / 2
				interactionState.panStartY = (render.dim.b + render.dim.t) / 2
				interactionState.areTracking = nil
				-- Cancel any ongoing smooth animation by setting target to current position
				cameraState.targetWcx = cameraState.wcx
				cameraState.targetWcz = cameraState.wcz
				cameraState.zoomToCursorActive = false
			end
			return true
		end
	end
	
	-- Check if we are centering the view, takes priority
	if mButton == 1 then
		if interactionState.areCentering then
			UpdateCentering(mx, my)
			interactionState.areCentering = false
			return true
		end
	end

	-- Check if we are in min mode
	if uiState.inMinMode then
		-- Handle middle mouse button even in min mode
		if mButton == 2 then
			if interactionState.panToggleMode then
				interactionState.panToggleMode = false
				interactionState.arePanning = false
				return true
			end
		end

		-- Was maximize clicked? (or ALT+drag/middle drag to move window)
		if (mButton == 1 or mButton == 2) and
		   mx >= uiState.minModeL and mx <= uiState.minModeL + math.floor(render.usedButtonSize*config.maximizeSizemult) and
		   my >= uiState.minModeB and my <= uiState.minModeB + math.floor(render.usedButtonSize*config.maximizeSizemult) then
			local altKey = Spring.GetModKeyState()
			
			-- If ALT is held or middle mouse, start tracking for drag (to move window)
			if altKey or mButton == 2 then
				interactionState.minimizeButtonClickStartX = mx
				interactionState.minimizeButtonClickStartY = my
				return true
			end
			
			-- Normal maximize (no ALT, left click only)
			if mButton == 1 then
				StartMaximizeAnimation()
				-- Update hover state after maximizing to check if mouse is over the restored PIP
				interactionState.isMouseOverPip = (mx >= render.dim.l and mx <= render.dim.r and my >= render.dim.b and my <= render.dim.t)
				return true
			end
		end
		-- Nothing else to click while in minMode
		return
	end

	-- Handle middle mouse button - start tracking for toggle vs hold-drag detection
	if mButton == 2 then
		-- If already in toggle mode, turn it off (regardless of where we click)
		if interactionState.panToggleMode then
			interactionState.panToggleMode = false
			interactionState.arePanning = false
			return true
		end

		-- Check if middle mouse is on the minimize button (to move window instead of pan)
		if mx >= render.dim.l and mx <= render.dim.r and my >= render.dim.b and my <= render.dim.t then
			if mx >= render.dim.r - render.usedButtonSize and my >= render.dim.t - render.usedButtonSize then
				interactionState.minimizeButtonClickStartX = mx
				interactionState.minimizeButtonClickStartY = my
				return true
			end
		end

		-- Start tracking middle mouse for toggle vs hold-drag
		if mx >= render.dim.l and mx <= render.dim.r and my >= render.dim.b and my <= render.dim.t then
			-- Cancel any ongoing build drag when middle mouse is pressed
			if interactionState.areBuildDragging then
				interactionState.areBuildDragging = false
				interactionState.buildDragPositions = {}
			end
			if interactionState.areAreaDragging then
				interactionState.areAreaDragging = false
			end

			interactionState.middleMousePressed = true
			interactionState.middleMouseMoved = false
			interactionState.middleMousePressX = mx
			interactionState.middleMousePressY = my
			interactionState.panStartX = (render.dim.l + render.dim.r) / 2
			interactionState.panStartY = (render.dim.b + render.dim.t) / 2
			return true
		end
	end

	-- Did we click within the pip window ?
	if mx >= render.dim.l and mx <= render.dim.r and my >= render.dim.b and my <= render.dim.t then

		-- Was it a left click? -> check buttons
		if mButton == 1 then

			-- Resize thing (check first - highest priority) - disabled in minimap mode
			if not (isMinimapMode and config.minimapModeHideMoveResize) then
				if render.dim.r-mx + my-render.dim.b <= render.usedButtonSize then
					uiState.areResizing = true
					return true
				end
			end

			-- Minimizing? (or ALT+drag/middle drag to move window) - disabled in minimap mode
			if not isMinimapMode and mx >= render.dim.r - render.usedButtonSize and my >= render.dim.t - render.usedButtonSize then
				local altKey = Spring.GetModKeyState()
				
				-- If ALT is held or middle mouse, start tracking for drag (to move window)
				if altKey or mButton == 2 then
					interactionState.minimizeButtonClickStartX = mx
					interactionState.minimizeButtonClickStartY = my
					return true
				end
				
				-- Normal minimize (no ALT, left click only)
				local sw, sh = Spring.GetWindowGeometry()

				-- Save current dimensions before minimizing
				uiState.savedDimensions = {
					l = render.dim.l,
					r = render.dim.r,
					b = render.dim.b,
					t = render.dim.t
				}

				-- Calculate where the minimize button will end up
				local targetL, targetB
				if render.dim.l < sw * 0.5 then
					targetL = render.dim.l
				else
					targetL = render.dim.r - math.floor(render.usedButtonSize*config.maximizeSizemult)
				end
				if render.dim.b < sh * 0.25 then
					targetB = render.dim.b
				else
					targetB = render.dim.t - math.floor(render.usedButtonSize*config.maximizeSizemult)
				end

				-- Store the target position
				uiState.minModeL = targetL
				uiState.minModeB = targetB

				-- Start minimize animation
				local buttonSize = math.floor(render.usedButtonSize*config.maximizeSizemult)
				uiState.animStartDim = {
					l = render.dim.l,
					r = render.dim.r,
					b = render.dim.b,
					t = render.dim.t
				}
				uiState.animEndDim = {
					l = targetL,
					r = targetL + buttonSize,
					b = targetB,
					t = targetB + buttonSize
				}
				uiState.animationProgress = 0
				uiState.isAnimating = true
				uiState.inMinMode = true

				-- Clean up R2T textures when minimizing to prevent them from being drawn
				if pipR2T.contentTex then
					gl.DeleteTexture(pipR2T.contentTex)
					pipR2T.contentTex = nil
				end
				if pipR2T.unitsTex then
					gl.DeleteTexture(pipR2T.unitsTex)
					pipR2T.unitsTex = nil
				end
				if pipR2T.frameBackgroundTex then
					gl.DeleteTexture(pipR2T.frameBackgroundTex)
					pipR2T.frameBackgroundTex = nil
				end
				if pipR2T.frameButtonsTex then
					gl.DeleteTexture(pipR2T.frameButtonsTex)
					pipR2T.frameButtonsTex = nil
				end

				return true
			end

			-- Button row
			if my <= render.dim.b + render.usedButtonSize then
				-- Calculate visible buttons
				local selectedUnits = Spring.GetSelectedUnits()
				local hasSelection = #selectedUnits > 0
				local isTracking = interactionState.areTracking ~= nil
				local isTrackingPlayer = interactionState.trackingPlayerID ~= nil
				-- Show player tracking button when tracking, when spectating, or when having alive teammates
				local showPlayerTrackButton = isTrackingPlayer
				if not showPlayerTrackButton then
					local _, _, spec = spFunc.GetPlayerInfo(Spring.GetMyPlayerID(), false)
					local aliveTeammates = GetAliveTeammates()
					showPlayerTrackButton = spec or (#aliveTeammates > 0)
				end
				local visibleButtons = {}
				for i = 1, #buttons do
					local btn = buttons[i]
					-- In minimap mode, skip move button if configured
					local skipButton = false
					if isMinimapMode and config.minimapModeHideMoveResize then
						if btn.tooltipKey == 'ui.pip.move' then
							skipButton = true
						end
					end
					-- In minimap mode, skip switch and copy buttons (keep pip_track and pip_trackplayer)
					-- Allow pip_view for spectators with fullview
					if isMinimapMode then
						if btn.command == 'pip_switch' or btn.command == 'pip_copy' then
							skipButton = true
						elseif btn.command == 'pip_view' then
							local _, fullview = Spring.GetSpectatingState()
							if not fullview then
								skipButton = true
							end
						end
					end
					
					if not skipButton then
						-- Show pip_track button if has selection or is tracking units
						if btn.command == 'pip_track' then
							if hasSelection or isTracking then
								visibleButtons[#visibleButtons + 1] = btn
							end
						-- Show pip_trackplayer button if lockcamera is available or already tracking (hidden during TV)
						elseif btn.command == 'pip_trackplayer' then
							if showPlayerTrackButton and not miscState.tvEnabled then
								visibleButtons[#visibleButtons + 1] = btn
							end
						-- Show pip_view button only for spectators
						elseif btn.command == 'pip_view' then
							local _, _, spec = spFunc.GetPlayerInfo(Spring.GetMyPlayerID(), false)
							if spec then
								visibleButtons[#visibleButtons + 1] = btn
							end
						elseif btn.command == 'pip_activity' then
							if not isSinglePlayer and not interactionState.trackingPlayerID and not miscState.tvEnabled and not (config.activityFocusHideForSpectators and cameraState.mySpecState) then
								visibleButtons[#visibleButtons + 1] = btn
							end
						elseif btn.command == 'pip_tv' then
							if not config.tvModeSpectatorsOnly or cameraState.mySpecState then
								visibleButtons[#visibleButtons + 1] = btn
							end
						else
							visibleButtons[#visibleButtons + 1] = btn
						end
					end
				end
				local buttonIndex = 1 + math.floor((mx - render.dim.l) / render.usedButtonSize)
				local pressedButton = visibleButtons[buttonIndex]
				if pressedButton then
					pressedButton.OnPress()
					return true
				end
			end

			-- Missed buttons with left click, so what did we click on?
			local wx, wz = PipToWorldCoords(mx, my)
			
			-- In minimap mode with leftButtonPansCamera enabled, left-click moves the world camera
			if isMinimapMode and IsLeftClickPanActive() then
				local _, cmdID = Spring.GetActiveCommand()
				-- Only move world camera if there's no active command
				if not cmdID or cmdID == 0 then
					local groundHeight = spFunc.GetGroundHeight(wx, wz) or 0
					Spring.SetCameraTarget(wx, groundHeight, wz, 0.2)
					interactionState.worldCameraDragging = true
					return true
				end
			end
			
			local _, cmdID = Spring.GetActiveCommand()
			if cmdID then
				-- Check if this is a build command with shift modifier for drag-to-build
				local alt, ctrl, meta, shift = Spring.GetModKeyState()

				-- Don't issue commands if alt is held without shift (user wants to pan instead)
				-- But if both alt+shift are held with a build command, allow build dragging
				local isBuildCommand = (cmdID < 0)
				local allowBuildDrag = (isBuildCommand and alt and shift)

				if alt and not allowBuildDrag then
					-- Alt held without build drag conditions, so user wants to pan
					-- Fall through to allow panning
				elseif allowBuildDrag then
					-- Alt+Shift+BuildCommand - start build dragging
					-- Snap to 16-elmo build grid
					local gridSize = 16
					wx = math.floor(wx / gridSize + 0.5) * gridSize
					wz = math.floor(wz / gridSize + 0.5) * gridSize

					interactionState.areBuildDragging = true
					interactionState.buildDragStartX = mx
					interactionState.buildDragStartY = my
					interactionState.buildDragPositions = {{wx = wx, wz = wz}}
					return true
				elseif not alt then
					if cmdID < 0 and shift then
						-- Start drag-to-build for buildings with shift modifier
						-- Snap to 16-elmo build grid
						local gridSize = 16
						wx = math.floor(wx / gridSize + 0.5) * gridSize
						wz = math.floor(wz / gridSize + 0.5) * gridSize

						interactionState.areBuildDragging = true
						interactionState.buildDragStartX = mx
						interactionState.buildDragStartY = my
						interactionState.buildDragPositions = {{wx = wx, wz = wz}}
						return true
					elseif cmdID > 0 then
						-- Check if command supports area mode
						local setTargetCmd = GameCMD and GameCMD.UNIT_SET_TARGET_NO_GROUND
						local supportsArea = (cmdID == CMD.ATTACK or cmdID == CMD.RECLAIM or cmdID == CMD.REPAIR or
						                      cmdID == CMD.RESURRECT or cmdID == CMD.CAPTURE or cmdID == CMD.RESTORE or
						                      cmdID == CMD.LOAD_UNITS or (setTargetCmd and cmdID == setTargetCmd))
						if supportsArea then
							-- Don't allow area commands as spectator (unless config allows it)
							local isSpec = Spring.GetSpectatingState()
							local canGiveCommands = not isSpec or config.allowCommandsWhenSpectating
							if canGiveCommands then
								-- Start area command drag
								interactionState.areAreaDragging = true
								interactionState.areaCommandStartX = mx
								interactionState.areaCommandStartY = my
								return true
							end
						else
							-- Single command (no area support)
							IssueCommandAtPoint(cmdID, wx, wz, false, false)

							if not shift then
								Spring.SetActiveCommand(0)
							end

							return true
						end
					else
						-- Build command without shift (single build)
						-- Snap to 16-elmo build grid
						local gridSize = 16
						wx = math.floor(wx / gridSize + 0.5) * gridSize
						wz = math.floor(wz / gridSize + 0.5) * gridSize

						IssueCommandAtPoint(cmdID, wx, wz, false, false)

						if not shift then
							Spring.SetActiveCommand(0)
						end

						return true
					end
				end
				-- If alt is held, fall through to allow panning to be initiated in MouseMove
			end

			-- No active command - start box selection or panning
			-- Don't start single left-click actions if we're already panning with left+right
			if not interactionState.arePanning then
				-- Check if alt is held - if so, don't start box selection (panning will be handled in MouseMove)
				-- Also don't allow box selection when tracking a player's camera
				local alt, ctrl, meta, shift = Spring.GetModKeyState()
				if not alt and not interactionState.trackingPlayerID then
					if IsLeftClickPanActive() and not interactionState.trackingPlayerID then
					interactionState.arePanning = true
					interactionState.panStartX = mx
					interactionState.panStartY = my
					interactionState.areTracking = nil
					-- Track initial click position for deselection on release (even if we're panning)
					interactionState.boxSelectStartX = mx
					interactionState.boxSelectStartY = my
					interactionState.boxSelectEndX = mx
					interactionState.boxSelectEndY = my
				else
					-- Start box selection instead
					-- Save current selection before starting box selection
					interactionState.selectionBeforeBox = Spring.GetSelectedUnits()

					interactionState.areBoxSelecting = true
					interactionState.boxSelectStartX = mx
					interactionState.boxSelectStartY = my
					interactionState.boxSelectEndX = mx
					interactionState.boxSelectEndY = my
					-- Initialize modifier state
					local alt, ctrl, meta, shift = Spring.GetModKeyState()
					interactionState.lastModifierState = {alt, ctrl, meta, shift}
					-- Check if we're starting a deselection (Ctrl held)
					interactionState.areBoxDeselecting = ctrl
					-- Set reference selection for smart select
					if WG.SmartSelect_SetReference then
						WG.SmartSelect_SetReference()
					end
				end
			end
			-- If alt is held, fall through without starting box selection (panning will be handled in MouseMove)
			end

			return true

		elseif mButton == 3 then
			-- Don't start right-click actions if we're already panning with left+right
			if interactionState.arePanning then
				return true
			end

			-- Check if there's an active command (FIGHT, ATTACK, PATROL can be formation commands)
			local _, activeCmd = Spring.GetActiveCommand()

			-- If it's a non-formation command, just clear it
			if activeCmd and activeCmd ~= CMD.FIGHT and activeCmd ~= CMD.ATTACK and activeCmd ~= CMD.PATROL then
				Spring.SetActiveCommand(0)
				return true
			end

			-- Start formation dragging (if customformations widget is available)
			if WG.customformations and WG.customformations.StartFormation then
				local wx, wz = PipToWorldCoords(mx, my)
				local wy = spFunc.GetGroundHeight(wx, wz)

				-- Determine the command to use
				local cmdID = activeCmd -- Start with active command (might be FIGHT, ATTACK, or PATROL)
				local overrideTarget = nil

				-- If no active command, determine default based on what's under cursor
				if not cmdID then
					local uID = GetUnitAtPoint(wx, wz)
					if uID then
						if Spring.IsUnitAllied(uID) then
							-- Check if we should use LOAD_UNITS command
							local selectedUnits = Spring.GetSelectedUnits()
							local canLoadTarget = false

							-- Check if any transport in selection can load this target unit
							for i = 1, #selectedUnits do
								if CanTransportLoadUnit(selectedUnits[i], uID) then
									canLoadTarget = true
									break
								end
							end

							if canLoadTarget then
								-- Don't allow area LOAD_UNITS as spectator (unless config allows it)
								local isSpec = Spring.GetSpectatingState()
								local canGiveCommands = not isSpec or config.allowCommandsWhenSpectating
								if canGiveCommands then
									-- Start area LOAD_UNITS drag instead of formation
									interactionState.areAreaDragging = true
									interactionState.areaCommandStartX = mx
									interactionState.areaCommandStartY = my
									-- Temporarily set LOAD_UNITS as active command for area drag
									Spring.SetActiveCommand(Spring.GetCmdDescIndex(CMD.LOAD_UNITS))
									return true
								end
							else
								cmdID = CMD.GUARD
								overrideTarget = uID
							end
						else
							cmdID = CMD.ATTACK
							overrideTarget = uID
						end
					else
						local fID = GetFeatureAtPoint(wx, wz)
						if fID then
							cmdID = CMD.RECLAIM
						else
							cmdID = CMD.MOVE
						end
					end
				end

				-- For formation drags starting on units, use MOVE but remember the original target
				-- The customformations widget will check if we release on the same target
				local actualCmd = cmdID
				if overrideTarget and (cmdID == CMD.GUARD or cmdID == CMD.ATTACK) then
					actualCmd = CMD.MOVE
				end

				if actualCmd then
					-- Don't allow formation dragging as spectator (unless config allows it)
					local isSpec = Spring.GetSpectatingState()
					local canGiveCommands = not isSpec or config.allowCommandsWhenSpectating
					if canGiveCommands then
						-- Start formation with world position
						-- Note: third parameter is fromMinimap, not shift behavior
						-- Check if we should queue commands (only for single unit)
						local selectedUnits = Spring.GetSelectedUnits()
						local shouldQueue = selectedUnits and #selectedUnits == 1

						-- Don't set pipForceShift yet - first command should replace, not queue
						-- We'll set it after the first node is added (in MouseMove)
						if WG.customformations.StartFormation({wx, wy, wz}, actualCmd, false) then
							interactionState.areFormationDragging = true
							interactionState.formationDragStartX = mx
							interactionState.formationDragStartY = my
							interactionState.formationDragShouldQueue = shouldQueue
							return true
						end
					end
				end
			end

			return true
		end

		-- Claim all mouse presses within PIP bounds
		return true
	end
end

function widget:MouseMove(mx, my, dx, dy, mButton)
	-- Get modifier key states
	local alt, ctrl, meta, shift = Spring.GetModKeyState()

	-- Handle world camera dragging (leftButtonPansCamera mode in minimap mode)
	if interactionState.worldCameraDragging then
		-- Convert PIP coordinates to world coordinates and move world camera
		local wx, wz = PipToWorldCoords(mx, my)
		local groundHeight = spFunc.GetGroundHeight(wx, wz) or 0
		Spring.SetCameraTarget(wx, groundHeight, wz, 0.04)
		return true
	end

	-- Handle pip-minimap dragging (moves PIP camera)
	if interactionState.pipMinimapDragging then
		local mmBounds = interactionState.pipMinimapBounds
		if mmBounds then
			-- Convert screen position to world position and move camera there
			local mmWidth = mmBounds.drawR - mmBounds.drawL
			local mmHeight = mmBounds.drawT - mmBounds.drawB
			local relX = (mx - mmBounds.drawL) / mmWidth
			local relY = 1 - ((my - mmBounds.drawB) / mmHeight)  -- Flip Y (screen Y is bottom-up, map Z is top-down)
			
			-- Apply inverse rotation to account for minimap rotation
			local minimapRotation = Spring.GetMiniMapRotation()
			if minimapRotation ~= 0 then
				-- Convert to center-based coordinates (0.5, 0.5 is center)
				local centeredX = relX - 0.5
				local centeredY = relY - 0.5
				
				-- Apply rotation (positive direction - Spring's rotation is CCW)
				local cosR = math.cos(minimapRotation)
				local sinR = math.sin(minimapRotation)
				local rotatedX = centeredX * cosR - centeredY * sinR
				local rotatedY = centeredX * sinR + centeredY * cosR
				-- Convert back to 0-1 range
				relX = rotatedX + 0.5
				relY = rotatedY + 0.5
			end
			
			local worldX = relX * mapInfo.mapSizeX
			local worldZ = relY * mapInfo.mapSizeZ
			
			-- Apply map edge margin constraints (same as UpdateTracking)
			local pipWidth, pipHeight = GetEffectivePipDimensions()
			local visibleWorldWidth = pipWidth / cameraState.zoom
			local visibleWorldHeight = pipHeight / cameraState.zoom
			
			-- Set camera target clamped to per-axis margins (centers on axis when view exceeds map)
			-- In minimap mode at minimum zoom, force center on map
			if IsAtMinimumZoom(cameraState.zoom) then
				cameraState.targetWcx = mapInfo.mapSizeX / 2
				cameraState.targetWcz = mapInfo.mapSizeZ / 2
			else
				cameraState.targetWcx = ClampCameraAxis(worldX, visibleWorldWidth, mapInfo.mapSizeX, config.mapEdgeMargin)
				cameraState.targetWcz = ClampCameraAxis(worldZ, visibleWorldHeight, mapInfo.mapSizeZ, config.mapEdgeMargin)
			end
			-- Also set current position for immediate response during drag
			cameraState.wcx = cameraState.targetWcx
			cameraState.wcz = cameraState.targetWcz
			RecalculateWorldCoordinates()
			RecalculateGroundTextureCoordinates()
		end
		return true
	end

	-- Handle minimize button drag (ALT+drag to move PIP window on screen)
	if interactionState.minimizeButtonClickStartX ~= 0 and not uiState.isAnimating then
		local dragThreshold = 8  -- Pixels before considering it a drag
		local dragDistX = math.abs(mx - interactionState.minimizeButtonClickStartX)
		local dragDistY = math.abs(my - interactionState.minimizeButtonClickStartY)
		
		if dragDistX > dragThreshold or dragDistY > dragThreshold or interactionState.minimizeButtonDragging then
			interactionState.minimizeButtonDragging = true
			
			if uiState.inMinMode then
				-- Move the minimized button position
				uiState.minModeL = uiState.minModeL + dx
				uiState.minModeB = uiState.minModeB + dy
				
				-- Clamp to screen bounds
				local buttonSize = math.floor(render.usedButtonSize * config.maximizeSizemult)
				local screenMarginPx = math.floor(config.screenMargin * render.vsy)
				uiState.minModeL = math.max(screenMarginPx, math.min(render.vsx - screenMarginPx - buttonSize, uiState.minModeL))
				uiState.minModeB = math.max(screenMarginPx, math.min(render.vsy - screenMarginPx - buttonSize, uiState.minModeB))
				
				-- Also update saved dimensions so they stay relative to the button position
				if AreExpandedDimensionsValid(uiState.savedDimensions) then
					uiState.savedDimensions.l = uiState.savedDimensions.l + dx
					uiState.savedDimensions.r = uiState.savedDimensions.r + dx
					uiState.savedDimensions.b = uiState.savedDimensions.b + dy
					uiState.savedDimensions.t = uiState.savedDimensions.t + dy
				end
				
				-- Update guishader blur dimensions
				UpdateGuishaderBlur()
			else
				-- Move PIP window on screen (like the move button does)
				render.dim.l = render.dim.l + dx
				render.dim.r = render.dim.r + dx
				render.dim.b = render.dim.b + dy
				render.dim.t = render.dim.t + dy
				CorrectScreenPosition()
				RecalculateWorldCoordinates()
				RecalculateGroundTextureCoordinates()
				
				-- Update guishader blur dimensions
				UpdateGuishaderBlur()
			end
			
			return true
		end
	end

	-- Check for left+right mouse button combination for panning (if not already panning)
	if interactionState.leftMousePressed and interactionState.rightMousePressed and not interactionState.arePanning and mx >= render.dim.l and mx <= render.dim.r and my >= render.dim.b and my <= render.dim.t then
		-- Check if there's actual movement (not just mouse jitter)
		if math.abs(dx) > 2 or math.abs(dy) > 2 then
			-- Cancel any ongoing operations
			if interactionState.areBuildDragging then
				interactionState.areBuildDragging = false
				interactionState.buildDragPositions = {}
			end
			if interactionState.areBoxSelecting then
				interactionState.areBoxSelecting = false
				interactionState.areBoxDeselecting = false
				if WG.SmartSelect_ClearReference then
					WG.SmartSelect_ClearReference()
				end
			end
			if interactionState.areFormationDragging then
				interactionState.areFormationDragging = false
			end

			-- Start panning (cancel player tracking if config allows, otherwise block)
			if interactionState.trackingPlayerID then
				if config.cancelPlayerTrackingOnPan then
					interactionState.trackingPlayerID = nil
				else
					return  -- Don't pan when tracking player camera
				end
			end
			-- Don't pan when at minimum zoom in minimap mode
			if not IsAtMinimumZoom(cameraState.zoom) then
				interactionState.arePanning = true
				interactionState.areTracking = nil
				-- Cancel any ongoing smooth animation by setting target to current position
				cameraState.targetWcx = cameraState.wcx
				cameraState.targetWcz = cameraState.wcz
				cameraState.zoomToCursorActive = false
			end
		end
	end

	-- If middle mouse is pressed but not yet committed to a mode, check if moved
	if interactionState.middleMousePressed and not interactionState.arePanning then
		-- Check if there's actual movement (not just mouse jitter)
		-- Use a small threshold to distinguish click from drag
		if math.abs(dx) > 2 or math.abs(dy) > 2 then
			interactionState.middleMouseMoved = true
			-- Start hold-drag panning (cancel player tracking if config allows, otherwise block)
			if interactionState.trackingPlayerID then
				if config.cancelPlayerTrackingOnPan then
					interactionState.trackingPlayerID = nil
				else
					return  -- Don't pan when tracking player camera
				end
			end
			-- Don't pan when at minimum zoom in minimap mode
			if not IsAtMinimumZoom(cameraState.zoom) then
				interactionState.arePanning = true
				interactionState.areTracking = nil
				-- Cancel any ongoing smooth animation by setting target to current position
				cameraState.targetWcx = cameraState.wcx
				cameraState.targetWcz = cameraState.wcz
				cameraState.zoomToCursorActive = false
			end
		end
	end

	-- Alt+Left drag for panning (but not when queuing buildings with shift)
	-- Skip if we're already doing minimize button drag
	if interactionState.leftMousePressed and alt and not interactionState.arePanning and not interactionState.minimizeButtonDragging and interactionState.minimizeButtonClickStartX == 0 and mx >= render.dim.l and mx <= render.dim.r and my >= render.dim.b and my <= render.dim.t then
		-- Check if we're holding a build command with shift (queuing buildings)
		local _, cmdID = Spring.GetActiveCommand()
		local isBuildCommand = (cmdID and cmdID < 0)
		local isQueueingBuilds = (isBuildCommand and shift)

		-- Don't start panning if queuing buildings
		if not isQueueingBuilds then
			-- Check if there's actual movement (not just mouse jitter)
			if math.abs(dx) > 2 or math.abs(dy) > 2 then
				-- Cancel any ongoing operations
				if interactionState.areBuildDragging then
					interactionState.areBuildDragging = false
					interactionState.buildDragPositions = {}
				end
				if interactionState.areBoxSelecting then
					interactionState.areBoxSelecting = false
					interactionState.areBoxDeselecting = false
					-- Restore selection to what it was before box selection started
					if interactionState.selectionBeforeBox then
						Spring.SelectUnitArray(interactionState.selectionBeforeBox)
						interactionState.selectionBeforeBox = nil
					end
					if WG.SmartSelect_ClearReference then
						WG.SmartSelect_ClearReference()
					end
				end
				if interactionState.areFormationDragging then
					interactionState.areFormationDragging = false
				end
			end

			-- Start panning (cancel player tracking if config allows, otherwise block)
			if interactionState.trackingPlayerID then
				if config.cancelPlayerTrackingOnPan then
					interactionState.trackingPlayerID = nil
				else
					return  -- Don't pan when tracking player camera
				end
			end
			-- Don't pan when at minimum zoom in minimap mode
			if not IsAtMinimumZoom(cameraState.zoom) then
				interactionState.arePanning = true
				interactionState.areTracking = nil
				-- Cancel any ongoing smooth animation by setting target to current position
				cameraState.targetWcx = cameraState.wcx
				cameraState.targetWcz = cameraState.wcz
				cameraState.zoomToCursorActive = false
			end
		end
	end

	if uiState.areResizing then
		local minSize = math.floor(config.minPanelSize*render.widgetScale)
		local maxSize = math.floor(render.vsy * config.maxPanelSizeVsy)
		
		-- Apply width constraint
		local currentWidth = render.dim.r - render.dim.l
		local newWidth = render.dim.r + dx - render.dim.l
		if newWidth >= minSize then
			-- Allow resize if within max, OR if shrinking toward max (window was oversized)
			if newWidth <= maxSize or newWidth < currentWidth then
				render.dim.r = render.dim.r + dx
				-- Clamp to maxSize if still above it after shrink
				if render.dim.r - render.dim.l > maxSize then
					render.dim.r = render.dim.l + maxSize
				end
			end
		end
		
		-- Apply height constraint  
		local currentHeight = render.dim.t - render.dim.b
		local newHeight = render.dim.t - dy - render.dim.b
		if newHeight >= minSize then
			-- Allow resize if within max, OR if shrinking toward max (window was oversized)
			if newHeight <= maxSize or newHeight < currentHeight then
				render.dim.b = render.dim.b + dy
				-- Clamp to maxSize if still above it after shrink
				if render.dim.t - render.dim.b > maxSize then
					render.dim.b = render.dim.t - maxSize
				end
			end
		end
		
		CorrectScreenPosition()

		-- Update guishader blur dimensions
		UpdateGuishaderBlur()

		-- Clamp camera position to respect margin after resize
		local pipWidth, pipHeight = GetEffectivePipDimensions()

		-- Update dynamic min zoom so full map is visible at max zoom-out
		if isMinimapMode then
			-- Recalculate minimapModeMinZoom for the new PIP dimensions
			local rawW = render.dim.r - render.dim.l
			local rawH = render.dim.t - render.dim.b
			local is90 = false
			if render.minimapRotation then
				local rotDeg = math.abs(render.minimapRotation * 180 / math.pi) % 180
				if rotDeg > 45 and rotDeg < 135 then is90 = true end
			end
			local fzx = is90 and (rawH / mapInfo.mapSizeX) or (rawW / mapInfo.mapSizeX)
			local fzz = is90 and (rawW / mapInfo.mapSizeZ) or (rawH / mapInfo.mapSizeZ)
			minimapModeMinZoom = math.min(fzx, fzz)
			if cameraState.zoom < minimapModeMinZoom then
				cameraState.zoom = minimapModeMinZoom
				cameraState.targetZoom = minimapModeMinZoom
			end
		else
			-- Use raw (non-rotated) dimensions so zoom limit is the same regardless of rotation
			local rawW = render.dim.r - render.dim.l
			local rawH = render.dim.t - render.dim.b
			pipModeMinZoom = math.min(rawW, rawH) / math.max(mapInfo.mapSizeX, mapInfo.mapSizeZ)
			if cameraState.zoom < pipModeMinZoom then
				cameraState.zoom = pipModeMinZoom
				cameraState.targetZoom = pipModeMinZoom
			end
		end

		local visibleWorldWidth = pipWidth / cameraState.zoom
		local visibleWorldHeight = pipHeight / cameraState.zoom

		cameraState.wcx = ClampCameraAxis(cameraState.wcx, visibleWorldWidth, mapInfo.mapSizeX, config.mapEdgeMargin)
		cameraState.wcz = ClampCameraAxis(cameraState.wcz, visibleWorldHeight, mapInfo.mapSizeZ, config.mapEdgeMargin)
		cameraState.targetWcx = cameraState.wcx
		cameraState.targetWcz = cameraState.wcz
		RecalculateWorldCoordinates()
		RecalculateGroundTextureCoordinates()

	elseif interactionState.areDragging then
		render.dim.l = render.dim.l + dx
		render.dim.r = render.dim.r + dx
		render.dim.b = render.dim.b + dy
		render.dim.t = render.dim.t + dy
		CorrectScreenPosition()
		RecalculateWorldCoordinates()
		RecalculateGroundTextureCoordinates()

		-- Update guishader blur dimensions
		UpdateGuishaderBlur()

	elseif interactionState.arePanning then
		-- In minimap mode at minimum zoom, don't allow panning - keep centered on map
		if IsAtMinimumZoom(cameraState.zoom) then
			cameraState.wcx = mapInfo.mapSizeX / 2
			cameraState.wcz = mapInfo.mapSizeZ / 2
			cameraState.targetWcx = cameraState.wcx
			cameraState.targetWcz = cameraState.wcz
			return
		end
		
		-- Pan the camera based on mouse movement (only if there's movement)
		if dx ~= 0 or dy ~= 0 then
			-- Get current minimap rotation (must fetch fresh)
			local minimapRotation = Spring.GetMiniMapRotation and Spring.GetMiniMapRotation() or 0
			
			-- Apply inverse rotation to mouse deltas if minimap is rotated
			local panDx, panDy = dx, dy
			if minimapRotation ~= 0 then
				local cosR = math.cos(-minimapRotation)
				local sinR = math.sin(-minimapRotation)
				panDx = dx * cosR - dy * sinR
				panDy = dx * sinR + dy * cosR
			end
			
			-- Calculate the visible world area at current zoom
			-- At 90/270 degrees, swap dimensions for correct panning limits
			local pipWidth = render.dim.r - render.dim.l
			local pipHeight = render.dim.t - render.dim.b
			local visibleWorldWidth = pipWidth / cameraState.zoom
			local visibleWorldHeight = pipHeight / cameraState.zoom
			
			if minimapRotation ~= 0 then
				local rotDeg = math.abs(minimapRotation * 180 / math.pi) % 180
				if rotDeg > 45 and rotDeg < 135 then
					visibleWorldWidth, visibleWorldHeight = visibleWorldHeight, visibleWorldWidth
				end
			end

			-- Apply panning with per-axis margin limits (using rotated deltas, centers on axis when view exceeds map)
			cameraState.wcx = ClampCameraAxis(cameraState.wcx - panDx / cameraState.zoom, visibleWorldWidth, mapInfo.mapSizeX, config.mapEdgeMargin)
			cameraState.wcz = ClampCameraAxis(cameraState.wcz + panDy / cameraState.zoom, visibleWorldHeight, mapInfo.mapSizeZ, config.mapEdgeMargin)
			cameraState.targetWcx, cameraState.targetWcz = cameraState.wcx, cameraState.wcz  -- Panning updates instantly, not smoothly
			
			RecalculateWorldCoordinates()
			RecalculateGroundTextureCoordinates()

			-- Warp mouse back to center after processing movement
			local centerX = math.floor((render.dim.l + render.dim.r) / 2)
			local centerY = math.floor((render.dim.b + render.dim.t) / 2)
			Spring.WarpMouse(centerX, centerY)
		end

	elseif interactionState.areBoxSelecting then
		-- Update the end position of the box selection
		interactionState.boxSelectEndX = mx
		interactionState.boxSelectEndY = my

		-- Send live selection/deselection updates (throttled to ~30fps)
		local currentTime = os.clock()
		if (currentTime - interactionState.lastBoxSelectUpdate) > 0.033 then
			interactionState.lastBoxSelectUpdate = currentTime
			local unitsInBox = GetUnitsInBox(interactionState.boxSelectStartX, interactionState.boxSelectStartY, interactionState.boxSelectEndX, interactionState.boxSelectEndY)

			-- Always use SmartSelect_SelectUnits if available - it handles all modifier logic
			if WG.SmartSelect_SelectUnits then
				WG.SmartSelect_SelectUnits(unitsInBox)
			else
				-- Fallback to engine default if smart select is disabled
				local _, ctrl, _, shift = Spring.GetModKeyState()
				if ctrl then
					-- Deselect mode
					local currentSelection = Spring.GetSelectedUnits()
					local newSelection = {}
					local unitsToDeselect = {}
					local boxCount = #unitsInBox
					for i = 1, boxCount do
						unitsToDeselect[unitsInBox[i]] = true
					end
					local selectionCount = #currentSelection
					for i = 1, selectionCount do
						local unitID = currentSelection[i]
						if not unitsToDeselect[unitID] then
							newSelection[#newSelection + 1] = unitID
						end
					end
					Spring.SelectUnitArray(newSelection)
				else
					Spring.SelectUnitArray(unitsInBox, shift) -- shift = append mode
				end
			end
		end

	elseif interactionState.areFormationDragging then
		-- Add formation nodes as we drag
		if WG.customformations and WG.customformations.AddFormationNode then
			if mx >= render.dim.l and mx <= render.dim.r and my >= render.dim.b and my <= render.dim.t then
				local wx, wz = PipToWorldCoords(mx, my)
				local wy = spFunc.GetGroundHeight(wx, wz)
				WG.customformations.AddFormationNode({wx, wy, wz})

				-- After the first node is added, enable queuing for subsequent nodes
				-- (if shouldQueue is true - only for single unit selection)
				if interactionState.formationDragShouldQueue and not WG.pipForceShift then
					WG.pipForceShift = true
				end
			end
		end

	elseif interactionState.areBuildDragging and not interactionState.arePanning then
		-- Update build drag positions (but not if we're panning)
		if mx >= render.dim.l and mx <= render.dim.r and my >= render.dim.b and my <= render.dim.t then
			local startWX, startWZ = PipToWorldCoords(interactionState.buildDragStartX, interactionState.buildDragStartY)
			local endWX, endWZ = PipToWorldCoords(mx, my)

			local _, cmdID = Spring.GetActiveCommand()
			if cmdID and cmdID < 0 then
				local buildDefID = -cmdID
				local alt, ctrl, meta, shift = Spring.GetModKeyState()

				interactionState.buildDragPositions = CalculateBuildDragPositions(startWX, startWZ, endWX, endWZ, buildDefID, alt, ctrl, shift)
			end
		end
	end
end

function widget:KeyRelease(key)
	-- When modifier keys change during build dragging, recalculate positions
	if interactionState.areBuildDragging then
		local mx, my = spFunc.GetMouseState()
		if mx >= render.dim.l and mx <= render.dim.r and my >= render.dim.b and my <= render.dim.t then
			local startWX, startWZ = PipToWorldCoords(interactionState.buildDragStartX, interactionState.buildDragStartY)
			local endWX, endWZ = PipToWorldCoords(mx, my)

			local _, cmdID = Spring.GetActiveCommand()
			if cmdID and cmdID < 0 then
				local buildDefID = -cmdID
				local alt, ctrl, meta, shift = Spring.GetModKeyState()

				interactionState.buildDragPositions = CalculateBuildDragPositions(startWX, startWZ, endWX, endWZ, buildDefID, alt, ctrl, shift)
			end
		end
	end
end

function widget:MouseRelease(mx, my, mButton)
	-- Handle world camera drag release (leftButtonPansCamera mode)
	if mButton == 1 and interactionState.worldCameraDragging then
		interactionState.worldCameraDragging = false
		return true
	end

	-- Handle pip-minimap drag release
	if mButton == 1 and interactionState.pipMinimapDragging then
		interactionState.pipMinimapDragging = false
		return true
	end

	-- Handle minimize button click/drag release (ALT+click to minimize, ALT/middle drag to move)
	if (mButton == 1 or mButton == 2) and interactionState.minimizeButtonClickStartX ~= 0 then
		local wasDragging = interactionState.minimizeButtonDragging
		local dragThreshold = 8  -- Pixels before considering it a drag
		local dragDistX = math.abs(mx - interactionState.minimizeButtonClickStartX)
		local dragDistY = math.abs(my - interactionState.minimizeButtonClickStartY)
		local wasClick = dragDistX <= dragThreshold and dragDistY <= dragThreshold
		
		-- Reset drag state
		interactionState.minimizeButtonClickStartX = 0
		interactionState.minimizeButtonClickStartY = 0
		interactionState.minimizeButtonDragging = false
		
		-- If it was a click (not a drag) with left mouse, trigger minimize or maximize
		-- Middle mouse click does nothing (just drag to move)
		if wasClick and mButton == 1 and not uiState.isAnimating then
			if uiState.inMinMode then
				-- Maximize (we were in minimized mode)
				StartMaximizeAnimation()
				interactionState.isMouseOverPip = false
			else
				-- Minimize (we were in maximized mode)
				local sw, sh = Spring.GetWindowGeometry()
				
				-- Save current dimensions before minimizing
				uiState.savedDimensions = {
					l = render.dim.l,
					r = render.dim.r,
					b = render.dim.b,
					t = render.dim.t
				}

				-- Calculate where the minimize button will end up
				local targetL, targetB
				if render.dim.l < sw * 0.5 then
					targetL = render.dim.l
				else
					targetL = render.dim.r - math.floor(render.usedButtonSize*config.maximizeSizemult)
				end
				if render.dim.b < sh * 0.25 then
					targetB = render.dim.b
				else
					targetB = render.dim.t - math.floor(render.usedButtonSize*config.maximizeSizemult)
				end

				-- Store the target position
				uiState.minModeL = targetL
				uiState.minModeB = targetB

				-- Start minimize animation
				local buttonSize = math.floor(render.usedButtonSize*config.maximizeSizemult)
				uiState.animStartDim = {
					l = render.dim.l,
					r = render.dim.r,
					b = render.dim.b,
					t = render.dim.t
				}
				uiState.animEndDim = {
					l = targetL,
					r = targetL + buttonSize,
					b = targetB,
					t = targetB + buttonSize
				}
				uiState.animationProgress = 0
				uiState.isAnimating = true
				uiState.inMinMode = true

				-- Clean up R2T textures when minimizing
				if pipR2T.contentTex then
					gl.DeleteTexture(pipR2T.contentTex)
					pipR2T.contentTex = nil
				end
				if pipR2T.unitsTex then
					gl.DeleteTexture(pipR2T.unitsTex)
					pipR2T.unitsTex = nil
				end
				if pipR2T.frameBackgroundTex then
					gl.DeleteTexture(pipR2T.frameBackgroundTex)
					pipR2T.frameBackgroundTex = nil
				end
				if pipR2T.frameButtonsTex then
					gl.DeleteTexture(pipR2T.frameButtonsTex)
					pipR2T.frameButtonsTex = nil
				end
			end
		end
		return  -- Don't process further
	end

	-- Store panning state BEFORE we modify it
	local wasPanning = interactionState.arePanning

	-- Stop panning if either left or right button is released (check BEFORE updating states)
	if interactionState.arePanning and not interactionState.panToggleMode and not interactionState.middleMousePressed and (mButton == 1 or mButton == 3) then
		-- Only stop if we were panning with left+right buttons (not middle mouse)
		-- After releasing one button, the other should still be pressed for continued panning
		local otherButtonStillPressed = false
		if mButton == 1 and interactionState.rightMousePressed then
			otherButtonStillPressed = true
		elseif mButton == 3 and interactionState.leftMousePressed then
			otherButtonStillPressed = true
		end

		if not otherButtonStillPressed then
			interactionState.arePanning = false
		end
	end

	-- Handle single left-click on empty space when using left-button panning mode
	-- Must do this AFTER panning stops but BEFORE we clear button states
	-- In panning mode, no box selection is started, so we need to handle deselection here
	if mButton == 1 and mx >= render.dim.l and mx <= render.dim.r and my >= render.dim.b and my <= render.dim.t and not uiState.inMinMode and IsLeftClickPanActive() then
		-- Check if this was a very short click (indicating panning was not actually used to pan)
		local minDragDistance = 5
		local dragDistX = math.abs(mx - interactionState.panStartX)
		local dragDistY = math.abs(my - interactionState.panStartY)
		local wasShortClick = dragDistX <= minDragDistance and dragDistY <= minDragDistance

		-- Check if we WERE in panning mode (we stored this before it was cleared)
		-- This handles clicks that started panning but didn't actually pan
		if wasShortClick and wasPanning then
			-- This was just a single click that started panning but didn't actually pan
			-- Check if we clicked on a unit
			local wx, wz = PipToWorldCoords(mx, my)
			local uID = GetUnitAtPoint(wx, wz)

			if uID then
				-- Clicked on a unit - select it
				local alt, ctrl, meta, shift = Spring.GetModKeyState()
				if ctrl then
					-- Ctrl+click: toggle selection
					if spFunc.IsUnitSelected(uID) then
						local currentSelection = Spring.GetSelectedUnits()
						local newSelection = {}
						for i = 1, #currentSelection do
							if currentSelection[i] ~= uID then
								newSelection[#newSelection + 1] = currentSelection[i]
							end
						end
						Spring.SelectUnitArray(newSelection)
					else
						Spring.SelectUnitArray({uID}, true)
					end
				elseif shift then
					-- Shift+click: add to selection
					Spring.SelectUnitArray({uID}, true)
				else
					-- Normal click: select only this unit
					Spring.SelectUnitArray({uID}, false)
				end
			else
				-- Clicked empty space - deselect unless shift is held
				local _, _, _, shift = Spring.GetModKeyState()
				if not shift then
					Spring.SelectUnitArray({})
				end
			end

			-- Mark that we handled the click so box selection doesn't process it again
			interactionState.clickHandledInPanMode = true
		end
	end

	-- Track mouse button states for left+right panning (update AFTER checking panning state)
	if mButton == 1 then
		interactionState.leftMousePressed = false
	elseif mButton == 3 then
		interactionState.rightMousePressed = false
	end

	-- Skip box selection if we already handled this click in panning mode
	if interactionState.clickHandledInPanMode then
		interactionState.clickHandledInPanMode = false
		return
	end

	if interactionState.areBoxSelecting then
		-- Complete the box selection
		local minDragDistance = 5 -- Minimum pixels to consider it a drag vs a click
		local dragDistX = math.abs(interactionState.boxSelectEndX - interactionState.boxSelectStartX)
		local dragDistY = math.abs(interactionState.boxSelectEndY - interactionState.boxSelectStartY)

		if dragDistX > minDragDistance or dragDistY > minDragDistance then
			-- It's a drag - get units in the box
			local unitsInBox = GetUnitsInBox(interactionState.boxSelectStartX, interactionState.boxSelectStartY, interactionState.boxSelectEndX, interactionState.boxSelectEndY)

			if interactionState.areBoxDeselecting then
				-- Final deselection - remove units in box from current selection
				local currentSelection = Spring.GetSelectedUnits()
				local newSelection = {}
				-- Create a set for fast lookup of units to deselect
				local unitsToDeselect = {}
				for i = 1, #unitsInBox do
					unitsToDeselect[unitsInBox[i]] = true
				end
				-- Keep only units not in the deselection box
				for i = 1, #currentSelection do
					local unitID = currentSelection[i]
					if not unitsToDeselect[unitID] then
						newSelection[#newSelection + 1] = unitID
					end
				end
				Spring.SelectUnitArray(newSelection)
			else
				-- Regular selection
				if WG.SmartSelect_SelectUnits then
					WG.SmartSelect_SelectUnits(unitsInBox)
				else
					-- Fallback if smart select is not available
					local _, _, _, shift = Spring.GetModKeyState()
					if #unitsInBox > 0 then
						Spring.SelectUnitArray(unitsInBox, shift)
					else
						-- No units in box - clear selection unless shift is held
						if not shift then
							Spring.SelectUnitArray({})
						end
					end
				end
			end
		else
			-- It's a click - check if we clicked on a unit
			local wx, wz = PipToWorldCoords(mx, my)
			local uID = GetUnitAtPoint(wx, wz)
			if uID then
				local alt, ctrl, meta, shift = Spring.GetModKeyState()
				if ctrl then
					-- Ctrl+click: toggle selection (add if not selected, remove if selected)
					if spFunc.IsUnitSelected(uID) then
						-- Deselect it
						local currentSelection = Spring.GetSelectedUnits()
						local newSelection = {}
						for i = 1, #currentSelection do
							if currentSelection[i] ~= uID then
								newSelection[#newSelection + 1] = currentSelection[i]
							end
						end
						Spring.SelectUnitArray(newSelection)
					else
						-- Add to selection
						Spring.SelectUnitArray({uID}, true)
					end
				elseif shift then
					-- Shift+click: add to selection
					Spring.SelectUnitArray({uID}, true)
				else
					-- Normal click without modifier: select only this unit (replace selection)
					Spring.SelectUnitArray({uID}, false)
				end
			else
				-- Clicked empty space - deselect unless shift is held
				local _, _, _, shift = Spring.GetModKeyState()
				if not shift then
					Spring.SelectUnitArray({})
				end
			end
		end

		interactionState.areBoxSelecting = false
		interactionState.areBoxDeselecting = false
		-- Clear saved selection since box selection completed normally
		interactionState.selectionBeforeBox = nil
		-- Clear reference selection for smart select
		if WG.SmartSelect_ClearReference then
			WG.SmartSelect_ClearReference()
		end

	elseif interactionState.areAreaDragging then
		-- Complete area command drag
		local minDragDistance = 5 -- Minimum pixels to consider it a drag
		local dragDistX = math.abs(mx - interactionState.areaCommandStartX)
		local dragDistY = math.abs(my - interactionState.areaCommandStartY)

		if mx >= render.dim.l and mx <= render.dim.r and my >= render.dim.b and my <= render.dim.t then
			local wx, wz = PipToWorldCoords(mx, my)
			local startWX, startWZ = PipToWorldCoords(interactionState.areaCommandStartX, interactionState.areaCommandStartY)
			local _, cmdID = Spring.GetActiveCommand()

			if cmdID and cmdID > 0 then
				-- Check if this is a set target command
				local setTargetCmd = GameCMD and GameCMD.UNIT_SET_TARGET_NO_GROUND
				local isSetTarget = setTargetCmd and cmdID == setTargetCmd

				if isSetTarget then
					-- Set target requires a unit at the center point
					local targetID = GetUnitAtPoint(startWX, startWZ)
					if targetID then
						-- Calculate radius in world coordinates
						local dx = wx - startWX
						local dz = wz - startWZ
						local radius = math.sqrt(dx * dx + dz * dz)

						if dragDistX > minDragDistance or dragDistY > minDragDistance then
							-- It's a drag - issue area set target command
							local alt, ctrl, meta, shift = Spring.GetModKeyState()
							local cmdOpts = GetCmdOpts(alt, ctrl, meta, shift, false)
							GiveNotifyingOrder(cmdID, {targetID, startWX, spFunc.GetGroundHeight(startWX, startWZ), startWZ, radius}, cmdOpts)
						else
							-- It's a click - issue single set target command
							local alt, ctrl, meta, shift = Spring.GetModKeyState()
							local cmdOpts = GetCmdOpts(alt, ctrl, meta, shift, false)
							GiveNotifyingOrder(cmdID, {targetID}, cmdOpts)
						end
					end
				else
					-- Regular area command
					-- Calculate radius in world coordinates
					local dx = wx - startWX
					local dz = wz - startWZ
					local radius = math.sqrt(dx * dx + dz * dz)

					if dragDistX > minDragDistance or dragDistY > minDragDistance then
						-- It's a drag - issue area command with radius
						IssueCommandAtPoint(cmdID, startWX, startWZ, false, false, radius)
					else
						-- It's a click - issue single command without radius
						IssueCommandAtPoint(cmdID, startWX, startWZ, false, false)
					end
				end

				local _, _, _, shift = Spring.GetModKeyState()
				if not shift then
					Spring.SetActiveCommand(0)
				end
			end
		end

		interactionState.areAreaDragging = false

	elseif interactionState.areFormationDragging then
		-- End formation drag
		-- Check if it was a short click vs an actual drag
		local minDragDistance = 5 -- Minimum pixels to consider it a drag
		local dragDistX = math.abs(mx - interactionState.formationDragStartX)
		local dragDistY = math.abs(my - interactionState.formationDragStartY)
		local isDrag = dragDistX > minDragDistance or dragDistY > minDragDistance

		if WG.customformations and WG.customformations.EndFormation then
			-- Add final position if still within PIP bounds
			local finalPos = nil
			if mx >= render.dim.l and mx <= render.dim.r and my >= render.dim.b and my <= render.dim.t then
				local wx, wz = PipToWorldCoords(mx, my)
				local wy = spFunc.GetGroundHeight(wx, wz)
				finalPos = {wx, wy, wz}
			end
			WG.customformations.EndFormation(finalPos)
		end

		-- Clear the force shift flag
		WG.pipForceShift = nil
		interactionState.formationDragShouldQueue = false

		-- If it was just a click (not a drag), issue the original command
		if not isDrag and mx >= render.dim.l and mx <= render.dim.r and my >= render.dim.b and my <= render.dim.t then
			local wx, wz = PipToWorldCoords(mx, my)

			-- Determine the original command
			local cmdID = nil
			local uID = GetUnitAtPoint(wx, wz)
			if uID then
				if Spring.IsUnitAllied(uID) then
					-- Check if we should use LOAD_UNITS command
					local selectedUnits = Spring.GetSelectedUnits()
					local canLoadTarget = false

					-- Check if any transport in selection can load this target unit
					for i = 1, #selectedUnits do
						if CanTransportLoadUnit(selectedUnits[i], uID) then
							canLoadTarget = true
							break
						end
					end

					if canLoadTarget then
						cmdID = CMD.LOAD_UNITS
					else
						cmdID = CMD.GUARD
					end
				else
					cmdID = CMD.ATTACK
				end
			else
				local fID = GetFeatureAtPoint(wx, wz)
				if fID then
					cmdID = CMD.RECLAIM
				else
					cmdID = CMD.MOVE
				end
			end

			if cmdID then
				-- Simple right-click (not a drag) should work normally, not queue
				IssueCommandAtPoint(cmdID, wx, wz, true, false)
			end
		end

		interactionState.areFormationDragging = false

	elseif interactionState.areBuildDragging then
		-- End build drag - issue all build commands
		local minDragDistance = 5
		local dragDistX = math.abs(mx - interactionState.buildDragStartX)
		local dragDistY = math.abs(my - interactionState.buildDragStartY)
		local isDrag = dragDistX > minDragDistance or dragDistY > minDragDistance

		local _, cmdID = Spring.GetActiveCommand()
		if cmdID and cmdID < 0 then
			local buildDefID = -cmdID
			local alt, ctrl, meta, shift = Spring.GetModKeyState()

			if isDrag and #interactionState.buildDragPositions > 0 then
				-- Issue build commands for all positions (force queue for multiple commands)
				for i = 1, #interactionState.buildDragPositions do
					local pos = interactionState.buildDragPositions[i]
					IssueCommandAtPoint(cmdID, pos.wx, pos.wz, false, true)
				end
			else
				-- Just a click, issue single command (no forced queue)
				local wx, wz = PipToWorldCoords(mx, my)
				IssueCommandAtPoint(cmdID, wx, wz, false, false)
			end

			if not shift then
				Spring.SetActiveCommand(0)
			end
		end

		interactionState.areBuildDragging = false
		interactionState.buildDragPositions = {}
	end

	uiState.areResizing = false
	interactionState.areDragging = false

	-- Handle middle mouse release
	if mButton == 2 then
		if interactionState.middleMousePressed then
			-- Middle mouse was pressed in our window
			-- Check if it was a click (not a drag) - if so, teleport world camera
			local wasClick = not interactionState.middleMouseMoved
			
			if wasClick and config.middleClickTeleport then
				-- Convert click position to world coordinates
				local wx, wz = PipToWorldCoords(interactionState.middleMousePressX, interactionState.middleMousePressY)
				local groundHeight = spFunc.GetGroundHeight(wx, wz) or 0
				
				-- Get current camera state
				local curCamState = Spring.GetCameraState()
				if curCamState then
					-- Set position
					curCamState.px = wx
					curCamState.pz = wz
					
					-- Calculate zoom level for teleport
					local targetZoom
					local adjustZoom = true
					
					if isMinimapMode then
						-- In minimap mode, preserve current camera zoom but apply offset and limits
						-- Get current world camera zoom equivalent from height/dist
						local referenceHeight = 1200  -- At zoom 1.0
						local currentHeight = curCamState.height or curCamState.dist or 2000
						local currentZoom = referenceHeight / currentHeight
						
						-- Clamp to min/max bounds
						targetZoom = math.max(config.minimapMiddleClickZoomMin, math.min(config.minimapMiddleClickZoomMax, currentZoom))
						
						-- Only adjust if actually changed
						if math.abs(targetZoom - currentZoom) < 0.01 then
							adjustZoom = false
						end
					else
						-- Calculate world camera zoom based on PIP zoom
						-- PIP zoom is in range [zoomMin, zoomMax], higher = more zoomed in
						-- World camera height: higher height = more zoomed out
						local pipZoom = cameraState.zoom
						-- Apply zoom offset (slightly more zoomed out than PIP)
						targetZoom = pipZoom - config.middleClickZoomOffset

						-- Clamp to configured bounds
						targetZoom = math.max(config.middleClickZoomMin, math.min(config.middleClickZoomMax, targetZoom))
					end
					
					-- Only adjust height/dist if needed
					if adjustZoom then
						-- Convert zoom to camera height/dist: height = referenceHeight / zoom
						-- Reference: at zoom 0.5, height is ~2400 elmos (typical gameplay view)
						local referenceHeight = 1200  -- At zoom 1.0
						local targetHeight = referenceHeight / targetZoom
						
						-- Set height/dist based on camera type
						-- TA camera uses "height", Spring camera uses "dist"
						if curCamState.name == "ta" or curCamState.name == "ov" then
							curCamState.height = targetHeight
						elseif curCamState.name == "spring" then
							curCamState.dist = targetHeight
						else
							-- For other cameras (free, etc), try both
							curCamState.height = targetHeight
							curCamState.dist = targetHeight
						end
					end
					
					Spring.SetCameraState(curCamState, 0.2)
				else
					-- Fallback: just move camera target without zoom change
					Spring.SetCameraTarget(wx, groundHeight, wz, 0.2)
				end
			end
			
			-- Stop panning
			interactionState.arePanning = false
			interactionState.middleMousePressed = false
			interactionState.middleMouseMoved = false
			interactionState.middleMousePressX = 0
			interactionState.middleMousePressY = 0
		elseif interactionState.panToggleMode then
			-- Middle mouse released while in toggle mode (click was outside our window) - ignore
		end
	end

	-- Only stop panning from left button if not in toggle mode AND using leftButtonPansCamera mode
	-- (Don't interfere with left+right button panning which handles its own cleanup above)
	if interactionState.arePanning and not interactionState.panToggleMode and not interactionState.middleMousePressed and IsLeftClickPanActive() and mButton == 1 then
		interactionState.arePanning = false
	end

	interactionState.areIncreasingZoom = false
	interactionState.areDecreasingZoom = false
end
