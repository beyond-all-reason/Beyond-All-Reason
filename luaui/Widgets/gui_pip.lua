if not Spring.GetModOptions().pip then --and not Spring.GetModOptions().allowuserwidgets then
	return
end

function widget:GetInfo()
	return {
		name      = "Picture-in-Picture",
		desc      = "",
		author    = "Floris, (original by Niobium in 2010)",
		version   = "2.0",
		date      = "October 2025",
		license   = "GNU GPL, v2 or later",
		layer     = -990010,
		enabled   = true,
		handler   = true,
	}
end

pipNumber = pipNumber or 1

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
	zoomMax = 0.95,
	zoomFeatures = 0.2,
	zoomProjectileDetail = 0.2,
	zoomExplosionDetail = 0.1,

	-- Feature and overlay settings
	hideEnergyOnlyFeatures = false,
	showLosOverlay = true,
	showLosRadar = true,
	losOverlayOpacity = 0.6,
	showPipFps = false,
	allowCommandsWhenSpectating = false,  -- Allow giving commands as spectator when god mode is enabled

	-- Rendering settings
	iconRadius = 40,
	showUnitpics = true,      -- Show unitpics instead of icons when zoomed in
	unitpicZoomThreshold = 0.7, -- Zoom level at which to switch to unitpics (higher = more zoomed in)
	leftButtonPansCamera = false,
	maximizeSizemult = 1.25,
	screenMargin = 0.05,
	drawProjectiles = true,
	zoomToCursor = true,
	mapEdgeMargin = 0.15,
	showButtonsOnHoverOnly = true,
	switchInheritsTracking = false,
	switchTransitionTime = 0.15,
	showMapRuler = true,
	showWorldIcon = true,  -- Show minimize/maximize icon in world view at PIP camera location
	showWorldIconForSpectators = false,  -- Also show world icon when spectating (default off)
	cancelPlayerTrackingOnPan = true,  -- Cancel player camera tracking when trying to pan or ALT+drag

	-- Performance settings
	pipMinUpdateRate = 30,
	pipMaxUpdateRate = 120,
	pipZoomThresholdMin = 0.15,
	pipZoomThresholdMax = 0.4,
	pipTargetDrawTime = 0.003,
	pipPerformanceAdjustSpeed = 0.1,

	radarWobbleSpeed = 1,
	CMD_AREA_MEX = GameCMD and GameCMD.AREA_MEX or 10000,
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
	world = {},  -- World coordinate boundaries
	ground = { view = {}, coord = {} },  -- Ground texture view and texture coordinates
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
	contentLastDrawTime = 0,  -- Last measured draw time for performance monitoring
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
	worldMinimizeIconHovered = false,  -- Hover state for world minimize icon
	worldMaximizeIconHovered = false,  -- Hover state for world maximize icon
	worldIconHoverStartTime = 0,  -- Time when hover started (for 1s delay)
	worldIconTooltipDisplayStartTime = 0,  -- Time when tooltip started displaying (for 1s count)
	worldIconTooltipShownThisHover = false,  -- Flag to only count tooltip once per hover
	worldIconDragging = false,  -- Whether we're dragging via world icon to move PIP window
	worldIconClickStartX = 0,  -- Screen X when we started clicking world icon
	worldIconClickStartY = 0,  -- Screen Y when we started clicking world icon
	minimizeButtonDragging = false,  -- Whether we're dragging via minimize button to move PIP window
	minimizeButtonClickStartX = 0,  -- Screen X when we started clicking minimize button
	minimizeButtonClickStartY = 0,  -- Screen Y when we started clicking minimize button
}

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
	worldIconTooltipShownThisGame = 0,  -- How many times tooltip shown this game
	worldIconTooltipShownTotal = 0,  -- How many times tooltip shown ever (persistent)
	hadSavedConfig = false,
	hasOpenedPIPThisGame = false,  -- Whether PIP has been opened/maximized at least once this game
	worldIconLockedX = nil,  -- Locked world icon X position while hovering
	worldIconLockedZ = nil,  -- Locked world icon Z position while hovering
	pipUnits = {},
	pipFeatures = {},
	mapMarkers = {},  -- Table to store active map markers
}
-- Consolidated drawing data
local drawData = {
	iconTeam = {},
	iconX = {},
	iconY = {},
	iconUdef = {},
	iconSelected = {},
	iconBuildProgress = {},
	iconUnitID = {},
	radarBlobX = {},
	radarBlobY = {},
	radarBlobTeam = {},
	radarBlobUdef = {},  -- Store unit def ID if known
	radarBlobUnitID = {},  -- Store unit ID for wobble calculation
	trackedIconIndices = {},
	hoveredUnitID = nil,
	lastSelectionboxEnabled = nil,
}

-- Reusable table pools to reduce GC pressure
-- These tables are reused across frames instead of being allocated/deallocated repeatedly
-- This significantly reduces garbage collection overhead in performance-critical draw paths
local pools = {
	iconsByTexture = {}, -- Reused for grouping icons by texture (DrawUnitsAndFeatures)
	unitpicsByTexture = {}, -- Reused for grouping unitpics by texture
	defaultIconIndices = {}, -- Reused for default icon indices (DrawUnitsAndFeatures)
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
	savedDim = {l=0, r=0, b=0, t=0}, -- Reused for UpdateR2TContent dimension backup
	savedGround = {view={l=0,r=0,b=0,t=0}, coord={l=0,r=0,b=0,t=0}}, -- Reused for UpdateR2TContent ground backup
	projectileColor = {1, 0.5, 0, 1}, -- Reused for DrawProjectile default color
	trackingMerge = {}, -- Reused for tracking unit merge operations
	trackingTempSet = {}, -- Reused for tracking unit deduplication
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
	-- Combat properties
	canAttack = {},
	maxIconShatters = 20,
	weaponIsLaser = {},
	weaponIsBlaster = {},
	weaponIsPlasma = {},
	weaponIsMissile = {},
	weaponIsLightning = {},
	weaponIsFlame = {},
	weaponIsParalyze = {},
	weaponSize = {},
	weaponRange = {},
	weaponThickness = {},
	weaponColor = {},
	weaponExplosionRadius = {},
	weaponSkipExplosion = {},
}

local gameTime = 0 -- Accumulated game time (pauses when game is paused)

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
local gaiaAllyTeamID = select(6, Spring.GetTeamInfo(Spring.GetGaiaTeamID()))

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
	GetCommandQueue = Spring.GetCommandQueue,
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
mapInfo.hasWater = mapInfo.minGroundHeight < 0
mapInfo.isLava = mapInfo.hasWater and Spring.Lava.isLavaMap


----------------------------------------------------------------------------------------------------

-- Buttons (Must be declared after variables)
local buttons = {
	{
		texture = 'LuaUI/Images/pip/PipCopy.png',
		tooltip = Spring.I18N('ui.pip.copy'),
		command = 'pip_copy',
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
		tooltip = Spring.I18N('ui.pip.switch'),
		command = 'pip_switch',
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
		tooltip = Spring.I18N('ui.pip.track'),
		tooltipActive = Spring.I18N('ui.pip.untrack'),
		command = 'pip_track',
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
		tooltip = Spring.I18N('ui.pip.view'),
		tooltipActive = Spring.I18N('ui.pip.unview'),
		command = 'pip_view',
		OnPress = function()
			state.losViewEnabled = not state.losViewEnabled
			if state.losViewEnabled then
				-- Store the current allyteam when enabling LOS view
				state.losViewAllyTeam = Spring.GetMyAllyTeamID()
			else
				state.losViewAllyTeam = nil
			end
			pipR2T.losNeedsUpdate = true
			pipR2T.frameNeedsUpdate = true
		end
	},
	{
		texture = 'LuaUI/Images/pip/PipCam.png',
		tooltip = Spring.I18N('ui.pip.camera'),
		tooltipActive = Spring.I18N('ui.pip.uncamera'),
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
		texture = 'LuaUI/Images/pip/PipMove.png',
		tooltip = Spring.I18N('ui.pip.move'),
		command = nil,
		OnPress = function()
			interactionState.areDragging = true
		end
	},
}

-- Shader for converting red-channel LOS texture to greyscale
local losShader = nil
local losShaderCode = {
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
		uniform float baseValue;
		uniform float losScale;
		uniform float showRadar;
		varying vec2 texCoord;
		void main() {
			// Red channel of LOS texture: LOS (0.2-1.0 = in LOS, <0.2 = not in LOS)
			float losValue = texture2D(losTex, texCoord).r;
			// Red channel of radar texture: Radar coverage
			float radarValue = texture2D(radarTex, texCoord).r;

			// Calculate grey based on LOS
			float grey = baseValue + losValue * losScale;

			// If showRadar enabled, darken areas that have neither LOS nor radar
			if (showRadar > 0.5) {
				if (losValue < 0.2 && radarValue < 0.2) {
					// Neither LOS nor radar - darken further
					grey = grey * 0.5;
				}
			}

			gl_FragColor = vec4(grey, grey, grey, 1.0);
		}
	]],
	uniformFloat = {
		baseValue = 1.0 - config.losOverlayOpacity,  -- Brightness in no-LOS areas
		losScale = config.losOverlayOpacity,         -- Brightness added for LOS areas
		showRadar = config.showLosRadar and 1.0 or 0.0,
	},
	uniformInt = {
		losTex = 0,
		radarTex = 1,
	},
}

-- Shader for rendering water overlay based on heightmap
local waterShader = nil
local waterShaderCode = {
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
		varying vec2 texCoord;
		void main() {
			float height = texture2D(heightTex, texCoord).r;

			// Heightmap: black (0.0) = water, white (1.0) = land
			// Apply water color where heightmap is black (water areas)
			float waterAmount = 1.0 - height;

			gl_FragColor = vec4(waterColor.rgb, waterColor.a * waterAmount * 0.05);
		}
	]],
	uniformInt = {
		heightTex = 0,
	},
	uniformFloat = {
		waterColor = {0, 0.04, 0.25, 0.5},
	},
}

local teamColors = {}
local teamList = Spring.GetTeamList()
for i = 1, #teamList do
	local tID = teamList[i]
	teamColors[tID] = {Spring.GetTeamColor(tID)}
end

----------------------------------------------------------------------------------------------------
-- Local functions
----------------------------------------------------------------------------------------------------
-- Utility

-- Cached factors for WorldToPipCoords (performance optimization)
local worldToPipScaleX = 1
local worldToPipScaleZ = 1
local worldToPipOffsetX = 0
local worldToPipOffsetZ = 0

function RecalculateWorldCoordinates()
	local hw, hh = 0.5 * (render.dim.r - render.dim.l) / cameraState.zoom, 0.5 * (render.dim.t - render.dim.b) / cameraState.zoom

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
			worldToPipScaleX = (dimR - dimL) / worldWidth
			worldToPipScaleZ = (dimT - dimB) / worldHeight
			worldToPipOffsetX = dimL - render.world.l * worldToPipScaleX
			worldToPipOffsetZ = dimB - render.world.b * worldToPipScaleZ
		else
			worldToPipScaleX = (render.dim.r - render.dim.l) / worldWidth
			worldToPipScaleZ = (render.dim.t - render.dim.b) / worldHeight
			worldToPipOffsetX = render.dim.l - render.world.l * worldToPipScaleX
			worldToPipOffsetZ = render.dim.b - render.world.b * worldToPipScaleZ
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
	local screenMarginPx = math.floor(config.screenMargin * render.vsy)
	local minSize = math.floor(config.minPanelSize * render.widgetScale)

	-- Calculate current window dimensions
	local windowWidth = render.dim.r - render.dim.l
	local windowHeight = render.dim.t - render.dim.b

	-- Enforce minimum panel size
	if windowWidth < minSize then
		windowWidth = minSize
		render.dim.r = render.dim.l + windowWidth
	end
	if windowHeight < minSize then
		windowHeight = minSize
		render.dim.t = render.dim.b + windowHeight
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

local function UpdateGuishaderBlur()
	if WG['guishader'] then
		-- Always update blur with current dimensions (including when minimized)
		-- The dim values will reflect the minimized button size when uiState.inMinMode is true
		-- Use InsertDlist for rounded corner blur support
		if WG['guishader'].InsertDlist then
			-- Clean up old dlist ourselves before creating new one
			if render.guishaderDlist then
				gl.DeleteList(render.guishaderDlist)
				render.guishaderDlist = nil
			end
			-- Create new dlist with rounded rectangle
			render.guishaderDlist = gl.CreateList(function()
				render.RectRound(render.dim.l-render.elementPadding, render.dim.b-render.elementPadding, render.dim.r+render.elementPadding, render.dim.t+render.elementPadding, render.elementCorner)
			end)
			-- Use force=true to ensure immediate stencil texture update
			WG['guishader'].InsertDlist(render.guishaderDlist, 'pip'..pipNumber, true)
		elseif WG['guishader'].InsertRect then
			-- Fallback to InsertRect if InsertDlist not available
			WG['guishader'].InsertRect(render.dim.l-render.elementPadding, render.dim.b-render.elementPadding, render.dim.r+render.elementPadding, render.dim.t+render.elementPadding, 'pip'..pipNumber)
		end
	end
end

local function UpdateCentering(mx, my)
	local _, pos = Spring.TraceScreenRay(mx, my, true)
	if pos and pos[2] > -10000 then
		cameraState.wcx, cameraState.wcz = pos[1], pos[3]
		cameraState.targetWcx, cameraState.targetWcz = cameraState.wcx, cameraState.wcz  -- Set targets instantly for centering
		RecalculateWorldCoordinates()
		RecalculateGroundTextureCoordinates()
	end
end

local function UpdateTracking()
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
		local pipWidth = render.dim.r - render.dim.l
		local pipHeight = render.dim.t - render.dim.b
		local visibleWorldWidth = pipWidth / cameraState.targetZoom
		local visibleWorldHeight = pipHeight / cameraState.targetZoom
		local smallerVisibleDimension = math.min(visibleWorldWidth, visibleWorldHeight)
		local margin = smallerVisibleDimension * config.mapEdgeMargin

		-- Calculate min/max camera positions to keep margin from map edges
		local minWcx = visibleWorldWidth / 2 - margin
		local maxWcx = mapInfo.mapSizeX - (visibleWorldWidth / 2 - margin)
		local minWcz = visibleWorldHeight / 2 - margin
		local maxWcz = mapInfo.mapSizeZ - (visibleWorldHeight / 2 - margin)

		-- Set only the target positions for smooth camera transition, clamped to margins
		cameraState.targetWcx = math.min(math.max(newTargetWcx, minWcx), maxWcx)
		cameraState.targetWcz = math.min(math.max(newTargetWcz, minWcz), maxWcz)

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
					zoomValue = math.max(config.zoomMin, math.min(config.zoomMax, zoomValue))
				end

				-- Second priority: use height if dist not available
				-- Validate height is reasonable (100-15000 range for overview support)
				if not zoomValue and height and height > 100 and height < 15000 then
					-- Camera height scales inversely with zoom
					local baseZoom = 2400 / height
					-- Adjust zoom based on PIP size
					zoomValue = baseZoom * pipSizeRatio
					-- Clamp to valid zoom range instead of discarding
					zoomValue = math.max(config.zoomMin, math.min(config.zoomMax, zoomValue))
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
		local pipWidth = render.dim.r - render.dim.l
		local pipHeight = render.dim.t - render.dim.b
		local visibleWorldWidth = pipWidth / cameraState.targetZoom
		local visibleWorldHeight = pipHeight / cameraState.targetZoom
		local smallerVisibleDimension = math.min(visibleWorldWidth, visibleWorldHeight)
		local margin = smallerVisibleDimension * config.mapEdgeMargin

		local minWcx = visibleWorldWidth / 2 - margin
		local maxWcx = mapInfo.mapSizeX - (visibleWorldWidth / 2 - margin)
		local minWcz = visibleWorldHeight / 2 - margin
		local maxWcz = mapInfo.mapSizeZ - (visibleWorldHeight / 2 - margin)

		cameraState.targetWcx = math.min(math.max(cameraState.targetWcx, minWcx), maxWcx)
		cameraState.targetWcz = math.min(math.max(cameraState.targetWcz, minWcz), maxWcz)
	end
end

local function PipToWorldCoords(mx, my)
	-- Apply inverse rotation if minimap is rotated
	if render.minimapRotation ~= 0 then
		local centerX = render.dim.l + (render.dim.r - render.dim.l) / 2
		local centerY = render.dim.b + (render.dim.t - render.dim.b) / 2

		-- Translate to origin
		local dx = mx - centerX
		local dy = my - centerY

		-- Rotate back (inverse rotation = negative angle)
		local cosR = math.cos(-render.minimapRotation)
		local sinR = math.sin(-render.minimapRotation)
		local rotatedX = dx * cosR - dy * sinR
		local rotatedY = dx * sinR + dy * cosR

		-- Translate back
		mx = rotatedX + centerX
		my = rotatedY + centerY
	end

	return render.world.l + (render.world.r - render.world.l) * ((mx - render.dim.l) / (render.dim.r - render.dim.l)),
		   render.world.b + (render.world.t - render.world.b) * ((my - render.dim.b) / (render.dim.t - render.dim.b))
end
local function WorldToPipCoords(wx, wz)
	-- Use precalculated factors for performance (avoids repeated division)
	-- Rotation is now handled by matrix transformation in RenderPipContents
	return worldToPipOffsetX + wx * worldToPipScaleX,
		   worldToPipOffsetZ + wz * worldToPipScaleZ
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

local function DrawPanel(l, r, b, t)
	glFunc.Color(0.6,0.6,0.6,0.6)
	render.UiElement(l-render.elementPadding, b-render.elementPadding, r+render.elementPadding, t+render.elementPadding, 1, 1, 1, 1, nil, nil, nil, nil, nil, nil, nil, nil)
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


local function DrawUnit(uID)
	local uDefID = spFunc.GetUnitDefID(uID)
	-- Don't return early if uDefID is nil - unit might be radar-only

	local uTeam = spFunc.GetUnitTeam(uID)
	local ux, uy, uz = spFunc.GetUnitBasePosition(uID)
	if not ux then return end  -- Early exit if position is invalid

	-- Debug counter for radar blobs
	local debugRadarBlobCount = 0

	-- Check visibility: either when tracking a player OR for our own team's visibility OR when LOS view is enabled
	-- Get the ally team we should check visibility for
	-- Note: trackingPlayerID takes priority over state.losViewEnabled (player tracking overrides LOS view)
	local checkAllyTeamID = nil
	local isEnemyUnit = false

	if interactionState.trackingPlayerID and cameraState.mySpecState then
		-- When tracking a player (as spectator), check their ally team's visibility
		local _, _, _, playerTeamID = spFunc.GetPlayerInfo(interactionState.trackingPlayerID, false)
		if playerTeamID then
			local _, _, _, _, _, playerAllyTeamID = spFunc.GetTeamInfo(playerTeamID, false)

			-- Check if we have fullview - without it we can only see our own allyteam's LOS
			local _, fullview = Spring.GetSpectatingState()
			local myAllyTeam = Spring.GetMyAllyTeamID()

			if not fullview and playerAllyTeamID ~= myAllyTeam then
				-- Tracking enemy player without fullview - use our own allyteam for visibility checks
				checkAllyTeamID = myAllyTeam
			else
				-- Either have fullview or tracking same allyteam - use tracked player's allyteam
				checkAllyTeamID = playerAllyTeamID
			end

			local _, _, _, _, _, unitAllyTeamID = spFunc.GetTeamInfo(uTeam, false)
			isEnemyUnit = (unitAllyTeamID ~= checkAllyTeamID)
		end
	elseif state.losViewEnabled and state.losViewAllyTeam then
		-- When LOS view is enabled (and not tracking a player), check visibility for the locked allyteam
		checkAllyTeamID = state.losViewAllyTeam
		local _, _, _, _, _, unitAllyTeamID = spFunc.GetTeamInfo(uTeam, false)
		isEnemyUnit = (unitAllyTeamID ~= state.losViewAllyTeam)
	elseif not cameraState.mySpecState then
		-- When playing (not spectating), check our own ally team's visibility
		local myTeamID = Spring.GetMyTeamID()
		local _, _, _, _, _, myAllyTeamID = spFunc.GetTeamInfo(myTeamID, false)
		checkAllyTeamID = myAllyTeamID
		local _, _, _, _, _, unitAllyTeamID = spFunc.GetTeamInfo(uTeam, false)
		isEnemyUnit = (unitAllyTeamID ~= myAllyTeamID)
	elseif cameraState.mySpecState then
		-- Spectating without tracking a player - check if we have limited view
		local _, fullview = Spring.GetSpectatingState()
		if not fullview then
			-- Spectating without fullview - check visibility for current allyteam
			local myAllyTeam = Spring.GetMyAllyTeamID()
			checkAllyTeamID = myAllyTeam
			local _, _, _, _, _, unitAllyTeamID = spFunc.GetTeamInfo(uTeam, false)
			isEnemyUnit = (unitAllyTeamID ~= myAllyTeam)
		end
	end
	-- else: spectator with full view not tracking anyone - skip all visibility checks

	-- Only check visibility for enemy units when we have a specific ally team to check against
	if checkAllyTeamID and isEnemyUnit then
		-- Get detailed LOS state
		local losState = spFunc.GetUnitLosState(uID, checkAllyTeamID)
		-- losState is a table with: los, prevLos, contRadar, radar, typed

		if not losState then
			-- No visibility at all, don't draw it
			return
		end

		-- Check if unit identity is known (in LOS) or just in radar
		if losState.los then
			-- Unit is in LOS - draw normally (continue to icon drawing below)
		elseif losState.radar then
			-- Unit is in radar but not in LOS
			local sx, sy = WorldToPipCoords(ux, uz)
			local idx = #drawData.radarBlobX + 1
			drawData.radarBlobX[idx] = sx
			drawData.radarBlobY[idx] = sy
			drawData.radarBlobTeam[idx] = uTeam
			drawData.radarBlobUnitID[idx] = uID  -- Store for wobble calculation
			-- Only store unit def if the type is actually known to the tracked player
			-- losState.typed tells us if unit type has been revealed (prevLos or other means)
			if losState.typed then
				drawData.radarBlobUdef[idx] = uDefID
			else
				drawData.radarBlobUdef[idx] = nil  -- Unknown type - will be drawn as blob
			end
			return
		else
			-- Not in LOS and not in radar - don't draw
			return
		end
	end

	-- If uDefID is nil at this point, unit shouldn't be drawn as icon (already handled as radar blob or not visible)
	if not uDefID then
		return
	end

	glFunc.PushMatrix()
	glFunc.Translate(ux - cameraState.wcx, cameraState.wcz - uz, 0)
	-- Store for batched icon drawing later
	local idx = #drawData.iconTeam + 1
	drawData.iconTeam[idx] = uTeam
	drawData.iconX[idx], drawData.iconY[idx] = WorldToPipCoords(ux, uz)
	drawData.iconUdef[idx] = uDefID
	drawData.iconUnitID[idx] = uID
	-- When tracking a player, show their selections instead of our own
	if interactionState.trackingPlayerID then
		local playerSelections = WG['allyselectedunits'] and WG['allyselectedunits'].getPlayerSelectedUnits(interactionState.trackingPlayerID)
		drawData.iconSelected[idx] = playerSelections and playerSelections[uID] or false
	else
		drawData.iconSelected[idx] = spFunc.IsUnitSelected(uID)
	end
	-- Get build progress (1 for finished units, < 1 for units under construction)
	local _, _, _, _, buildProgress = spFunc.GetUnitHealth(uID)
	drawData.iconBuildProgress[idx] = buildProgress or 1
	-- Check if this unit is being tracked
	local isTracked = false
	if interactionState.areTracking then
		for _, trackedID in ipairs(interactionState.areTracking) do
			if trackedID == uID then
				isTracked = true
				drawData.trackedIconIndices[#drawData.trackedIconIndices + 1] = idx
				break
			end
		end
	end
	glFunc.PopMatrix()
end

local function DrawFeature(fID)
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
		glFunc.Texture(0, '%-' .. fDefID .. ':0')
		gl.FeatureShape(fDefID, spFunc.GetFeatureTeam(fID))
	glFunc.PopMatrix()
end

local function DrawProjectile(pID)
	local px, py, pz = spFunc.GetProjectilePosition(pID)
	if not px then return end

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
					local baseOuterWidth = thickness * 9 * zoomScale
					local baseInnerWidth = thickness * 2.2 * zoomScale

					-- Draw segments
					local prevX = ox
					local prevZ = oz
					local prevBrightness = 0.7 + math.sin(segmentSeed) * 0.3

					for i = 1, numSegments do
						local segX, segZ, brightness

						if i == numSegments then
							-- End at target
							segX, segZ = tx, tz
							brightness = 1.2
						else
							-- Create jagged middle segment
							local baseX = ox + dx * i
							local baseZ = oz + dz * i
							local perpX = -dz / dist2D
							local perpZ = dx / dist2D
							local jitter = math.sin((segmentSeed + i) * 43758.5453) * boltJitter
							brightness = 0.5 + math.abs(math.sin((segmentSeed + i * 7.1234) * 12.9898)) * 1.0

							segX = baseX + perpX * jitter
							segZ = baseZ + perpZ * jitter
						end

						-- Average brightness of the two segment endpoints
						local avgBrightness = (prevBrightness + brightness) * 0.5

						-- Thickness scales with brightness
						local segOuterWidth = math.max(6, baseOuterWidth * avgBrightness)
						local segInnerWidth = math.max(1, baseInnerWidth * avgBrightness)

						-- Transform to screen space
						local x1 = prevX - cameraState.wcx
						local z1 = cameraState.wcz - prevZ
						local x2 = segX - cameraState.wcx
						local z2 = cameraState.wcz - segZ

						-- Draw outer glow
						glFunc.LineWidth(segOuterWidth)
						glFunc.Color(colorData[1], colorData[2], colorData[3], 0.4 * avgBrightness)
						glFunc.BeginEnd(glConst.LINES, function()
							glFunc.Vertex(x1, z1, 0)
							glFunc.Vertex(x2, z2, 0)
						end)

						-- Draw inner core (very white with slight blue tint)
						glFunc.LineWidth(segInnerWidth)
						local coreR = 0.9 + colorData[1] * 0.1
						local coreG = 0.9 + colorData[2] * 0.1
						local coreB = 0.95 + colorData[3] * 0.05
						glFunc.Color(coreR, coreG, coreB, 0.98 * avgBrightness)
						glFunc.BeginEnd(glConst.LINES, function()
							glFunc.Vertex(x1, z1, 0)
							glFunc.Vertex(x2, z2, 0)
						end)

						-- Move to next segment
						prevX, prevZ = segX, segZ
						prevBrightness = brightness
					end

					glFunc.LineWidth(1)

					-- Draw small explosion effect at target point immediately (instead of caching)
					-- This is a simple white-blue flash that fades quickly
					local explosionRadius = 8
					local baseRadius = explosionRadius * 1.0 -- Start at full size
					local alpha = 1.0 -- Full brightness at impact

					-- White-blue electric color
					local r, g, b = 0.9, 0.95, 1

					-- Circle drawing constants
					local segments = 24
					local angleStep = (2 * math.pi) / segments

					glFunc.PushMatrix()
					glFunc.Translate(tx - cameraState.wcx, cameraState.wcz - tz, 0)

					-- Draw bright outer glow first (bigger)
					local glowAlpha = alpha * 0.5
					local glowRadius = baseRadius * 5.8

					for j = 0, segments - 1 do
						local angle1 = j * angleStep
						local angle2 = (j + 1) * angleStep

						glFunc.BeginEnd(glConst.TRIANGLES, function()
							-- Center vertex
							glFunc.Color(r * 0.7, g * 0.7, b * 0.8, glowAlpha)
							glFunc.Vertex(0, 0, 0)

							-- Edge vertices (fade out)
							glFunc.Color(r * 0.4, g * 0.4, b * 0.5, 0)
							glFunc.Vertex(math.cos(angle1) * glowRadius, math.sin(angle1) * glowRadius, 0)
							glFunc.Vertex(math.cos(angle2) * glowRadius, math.sin(angle2) * glowRadius, 0)
						end)
					end

					-- Draw main flash with brighter core
					local coreAlpha = alpha * 0.95
					local edgeAlpha = alpha * 0.5
					local coreRadius = baseRadius * 0.4

					for j = 0, segments - 1 do
						local angle1 = j * angleStep
						local angle2 = (j + 1) * angleStep

						glFunc.BeginEnd(glConst.TRIANGLES, function()
							-- Center vertex (very bright white-blue)
							glFunc.Color(1, 1, 1, coreAlpha)
							glFunc.Vertex(0, 0, 0)

							-- Edge vertices (fade to electric blue)
							glFunc.Color(r * 0.8, g * 0.8, b, edgeAlpha)
							glFunc.Vertex(math.cos(angle1) * coreRadius, math.sin(angle1) * coreRadius, 0)

							glFunc.Color(r * 0.8, g * 0.8, b, edgeAlpha)
							glFunc.Vertex(math.cos(angle2) * coreRadius, math.sin(angle2) * coreRadius, 0)
						end)
					end

					glFunc.PopMatrix()

					return -- Don't draw as a projectile
				end
			end
		end

		-- Check if this is a flame weapon (Flame - particle stream effect)
		if cache.weaponIsFlame[pDefID] then
			-- Get weapon color from cached data (typically orange/yellow)
			local colorData = cache.weaponColor[pDefID]

			-- Draw flame as multiple small particles with random variation
			-- Use projectile ID and position for seeded randomness
			local seed = pID * 123.456 + px * 10 + pz * 10

			glFunc.PushMatrix()
			glFunc.Translate(px - cameraState.wcx, cameraState.wcz - pz, 0)

			local particleSeed = seed * 789.012
			-- Random offset from projectile position
			local offsetX = (math.sin(particleSeed * 12.9898) * 2 - 1) * 4
			local offsetZ = (math.sin(particleSeed * 78.233) * 2 - 1) * 4

			-- Variable particle size (2-6 units)
			local particleSize = 10 + math.abs(math.sin(particleSeed * 43.758)) * 4

			-- Color variation between particles (0 to 1)
			local colorVariation = math.abs(math.sin(particleSeed * 91.321))

			-- Draw outer glow (yellow to orange gradient with fade at edges)
			local glowR = 1.0
			local glowG = 0.8 + colorVariation * 0.15  -- 0.8 to 0.95 (stays more yellow/orange)
			local glowB = 0.1 + colorVariation * 0.15   -- 0.1 to 0.25 (slight variation)

			-- Draw middle layer (orange, less red)
			local r = 1.0
			local g = 0.45 + colorVariation * 0.3  -- 0.5 to 0.8 (more orange, less red)
			local b = 0.05
			local sides = 5
			glFunc.Color(r*1.25, g*1.25, b*1.25, 1)
			glFunc.BeginEnd(glConst.TRIANGLE_FAN, function()
				glFunc.Vertex(offsetX, offsetZ, 0) -- Center
				-- Create irregular flame-like shape with 6 points
				glFunc.Color(r, g, b, 0.6)
				for j = 0, sides do
					local angle = (j / sides) * math.pi * 2
					local radiusVariation = 0.6 + math.abs(math.sin(particleSeed * 17.89 + j)) * 0.8
					local radius = particleSize * 1.0 * radiusVariation
					glFunc.Vertex(
						offsetX + math.cos(angle) * radius,
						offsetZ + math.sin(angle) * radius,
						0
					)
				end
			end)

			glFunc.PopMatrix()
			return -- Don't draw as regular projectile
		end

		-- Check if this is a blaster weapon (LaserCannon - traveling projectile)
		if cache.weaponIsBlaster[pDefID] then
			-- Get weapon color from cached data
			local colorData = cache.weaponColor[pDefID]
			color = {colorData[1], colorData[2], colorData[3], 1}

			-- Make blaster bolts elongated based on velocity
			local vx, vy, vz = spFunc.GetProjectileVelocity(pID)
			if vx and (vx ~= 0 or vy ~= 0 or vz ~= 0) then
				-- Calculate bolt dimensions based on speed
				local speed = math.sqrt(vx*vx + vy*vy + vz*vz)

				-- Scale up width at low zoom (far back) for better visibility (but not length)
				local zoomScale = math.max(1, math.min(3, 1 / cameraState.zoom))

				-- Elongated blaster bolt (longer in direction of travel)
				width = (cache.weaponSize[pDefID] or 2) * 0.8 * zoomScale
				height = speed * 0.15 -- Length based on speed

				-- Calculate angle based on velocity direction (like missiles)
				angle = math.atan2(vx, vz) * mapInfo.rad2deg
			else
				-- Fallback: draw as regular sized projectile
				size = math.max(3, cache.weaponSize[pDefID] * 2)
			end
		-- Non-laser, non-blaster weapon projectiles - use cached size data
		elseif not cache.projectileSizes[pDefID] then
			-- Get size from cached weapon data
			local wSize = cache.weaponSize[pDefID]
			if wSize then
				-- Scale smaller projectiles down more than larger ones
				if wSize < 2 then
					cache.projectileSizes[pDefID] = wSize * 1.2 -- Small projectiles: scale by 1.2
				elseif wSize < 4 then
					cache.projectileSizes[pDefID] = wSize * 1.5 -- Medium-small: scale by 1.5
				else
					cache.projectileSizes[pDefID] = wSize * 2 -- Large projectiles: scale by 2
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
			color = {1, 1, 0, 1}
		end
	else
		-- This is debris or other non-weapon projectile
		size = 2
		color = {0.7, 0.7, 0.7, 1} -- Light gray for debris
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

	-- Scale projectiles to be visible at all zoom levels
	-- Increase base size at high zoom (zoomed in close)
	local zoomScale = 1 + (cameraState.zoom * 2) -- At zoom 0.05: 1.1x, at zoom 0.8: 2.6x
	width = width * zoomScale
	height = height * zoomScale

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
			angle = math.atan2(vx, vz) * mapInfo.rad2deg
		end
	end

	glFunc.PushMatrix()
		glFunc.Translate(px - cameraState.wcx, cameraState.wcz - pz, 0)

		-- Rotate missile/blaster to point towards target/velocity
		if isMissile then
			glFunc.Rotate(angle, 0, 0, 1)
		end

		-- Draw blaster bolts with outer glow and inner core
		if pDefID and cache.weaponIsBlaster[pDefID] then
			-- Draw outer glow (wider, more transparent)
			glFunc.Color(color[1], color[2], color[3], color[4] * 0.4)
			glFunc.BeginEnd(glConst.QUADS, function()
				glFunc.Vertex(-width * 1.3, -height, 0)
				glFunc.Vertex(width * 1.3, -height, 0)
				glFunc.Vertex(width * 1.3, height, 0)
				glFunc.Vertex(-width * 1.3, height, 0)
			end)

			-- Draw inner core (brighter, whiter)
			local whiteness = 0.6 -- Blend with white for brighter core
			local coreR = color[1] * (1 - whiteness) + whiteness
			local coreG = color[2] * (1 - whiteness) + whiteness
			local coreB = color[3] * (1 - whiteness) + whiteness
			glFunc.Color(coreR, coreG, coreB, color[4] * 0.95)
			glFunc.BeginEnd(glConst.QUADS, function()
				glFunc.Vertex(-width * 0.6, -height, 0)
				glFunc.Vertex(width * 0.6, -height, 0)
				glFunc.Vertex(width * 0.6, height, 0)
				glFunc.Vertex(-width * 0.6, height, 0)
			end)
		-- Draw missiles with pointed nose and tail fins
		elseif pDefID and cache.weaponIsMissile[pDefID] then
			-- Off-white color for missiles
			glFunc.Color(0.9, 0.9, 0.85, color[4])

			-- Main body (rectangle)
			glFunc.BeginEnd(glConst.QUADS, function()
				glFunc.Vertex(-width, -height * 0.7, 0)
				glFunc.Vertex(width, -height * 0.7, 0)
				glFunc.Vertex(width, height * 0.3, 0)
				glFunc.Vertex(-width, height * 0.3, 0)
			end)

			-- Pointed nose (triangle at front/top pointing in direction of travel)
			glFunc.BeginEnd(glConst.TRIANGLES, function()
				glFunc.Vertex(-width, -height * 0.7, 0)
				glFunc.Vertex(width, -height * 0.7, 0)
				glFunc.Vertex(0, -height, 0) -- Tip pointing forward in direction of travel
			end)

			-- Tail fins (trapezoidal stabilizer wings starting earlier at back)
			glFunc.BeginEnd(glConst.QUADS, function()
				-- Left fin (1.8x width, 1.6x length, swept back at ~25 degrees, 2x elongated toward front)
				local finWidth = width * 1.8  -- Scale by 1.8x
				local baseFinLength = height * 0.25  -- Base length scaled by 1.6 (0.15 * 1.6 = 0.24)
				local finStart = baseFinLength * 2  -- Elongated 2x toward front
				local finEnd = height * 0.0
				local finHeight = (finStart - finEnd) * 0.8  -- Height scaled by 0.8
				finStart = finEnd + finHeight
				-- No offset - fins at original position
				local sweepBack = finWidth * 0.47  -- ~25 degree sweep back (tan(25°) ≈ 0.47)

				glFunc.Vertex(-width, finStart, 0)  -- Front inner edge (no sweep)
				glFunc.Vertex(-finWidth, finStart, 0)  -- Front outer edge (unskewed)
				glFunc.Vertex(-finWidth, finEnd + sweepBack, 0)    -- Back outer edge swept toward back
				glFunc.Vertex(-width, finEnd, 0)
			end)
			glFunc.BeginEnd(glConst.QUADS, function()
				-- Right fin (1.8x width, 1.6x length, swept back at ~25 degrees, 2x elongated toward front)
				local finWidth = width * 1.5 * 1.5 * 0.8  -- Scale by 1.5, then 1.5, then 0.8 = 1.8x
				local baseFinLength = height * 0.15 * 1.6  -- Base length scaled by 1.6
				local finStart = baseFinLength * 2  -- Elongated 2x toward front
				local finEnd = height * 0.0
				local finHeight = (finStart - finEnd) * 0.8  -- Height scaled by 0.8
				finStart = finEnd + finHeight
				-- No offset - fins at original position
				local sweepBack = finWidth * 0.47  -- ~25 degree sweep back (tan(25°) ≈ 0.47)

				glFunc.Vertex(width, finStart, 0)  -- Front inner edge (no sweep)
				glFunc.Vertex(finWidth, finStart, 0)  -- Front outer edge (unskewed)
				glFunc.Vertex(finWidth, finEnd + sweepBack, 0)     -- Back outer edge swept toward back
				glFunc.Vertex(width, finEnd, 0)
			end)
		else

			-- Draw plasma projectiles as circles with gradient
			if pDefID and cache.weaponIsPlasma[pDefID] then
				local radius = math.max(width, height)
				local segments = 7

				local coreWhiteness = 0.9
				local coreR = color[1] * (1 - coreWhiteness) + coreWhiteness
				local coreG = color[2] * (1 - coreWhiteness) + coreWhiteness
				local coreB = color[3] * (1 - coreWhiteness) + coreWhiteness

				local orangeTint = 0.4
				local outerR = math.min(1, color[1] + orangeTint)
				local outerG = math.max(0, color[2] - orangeTint * 0.3)
				local outerB = math.max(0, color[3] - orangeTint * 0.5)

				-- Draw gradient from center (bright white) to edge (orange-tinted)
				glFunc.BeginEnd(glConst.TRIANGLES, function()
					for i = 0, segments - 1 do
						local angle1 = (i / segments) * 2 * math.pi
						local angle2 = ((i + 1) / segments) * 2 * math.pi

						-- Center vertex (bright white core)
						glFunc.Color(coreR, coreG, coreB, color[4])
						glFunc.Vertex(0, 0, 0)

						-- Edge vertexes (orange-tinted outer)
						glFunc.Color(outerR, outerG, outerB, color[4])
						glFunc.Vertex(math.cos(angle1) * radius, math.sin(angle1) * radius, 0)
						glFunc.Vertex(math.cos(angle2) * radius, math.sin(angle2) * radius, 0)
					end
				end)
			else
				-- Other projectiles as squares
				-- glFunc.Color(color[1], color[2], color[3], color[4])
				-- glFunc.BeginEnd(glConst.QUADS, function()
				-- 	glFunc.Vertex(-width, -height, 0)
				-- 	glFunc.Vertex(width, -height, 0)
				-- 	glFunc.Vertex(width, height, 0)
				-- 	glFunc.Vertex(-width, height, 0)
				-- end)
			end
		end

	glFunc.PopMatrix()
end

local function DrawLaserBeams()
	if #cache.laserBeams == 0 then return end

	local i = 1

	-- Precompute zoom-dependent scaling once
	local zoomScale = math.max(0.5, cameraState.zoom / 70)
	local wcx_cached = cameraState.wcx  -- Cache these for loop
	local wcz_cached = cameraState.wcz

	-- Cache world boundaries for culling
	local worldLeft = render.world.l
	local worldRight = render.world.r
	local worldTop = render.world.t
	local worldBottom = render.world.b

	while i <= #cache.laserBeams do
		local beam = cache.laserBeams[i]
		local age = gameTime - beam.startTime

		-- Remove beams older than 0.15 seconds
		if age > 0.15 then
			table.remove(cache.laserBeams, i)
			-- Don't increment i when removing, as the next item shifts down
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
					beamMinX = math.min(beamMinX, seg.x)
					beamMaxX = math.max(beamMaxX, seg.x)
					beamMinZ = math.min(beamMinZ, seg.z)
					beamMaxZ = math.max(beamMaxZ, seg.z)
				end
			else
				-- For regular beams, check origin and target
				beamMinX = math.min(beam.ox, beam.tx)
				beamMaxX = math.max(beam.ox, beam.tx)
				beamMinZ = math.min(beam.oz, beam.tz)
				beamMaxZ = math.max(beam.oz, beam.tz)
			end

		-- Skip if beam is completely outside visible area
		if beamMaxX < worldLeft - margin or beamMinX > worldRight + margin or
		   beamMaxZ < worldTop - margin or beamMinZ > worldBottom + margin then
			i = i + 1
		else
			-- Check if this is a lightning bolt (segmented) or regular laser beam
			if beam.isLightning then
				-- Draw lightning bolt with jagged segments
				local alpha = 1 - (age / 0.15) -- Fade out over lifetime				-- Base beam widths
				local baseOuterWidth = beam.thickness * 9 * zoomScale
				local baseInnerWidth = beam.thickness * 2.2 * zoomScale

				-- Draw segments individually with variable brightness and thickness
				for j = 1, #beam.segments - 1 do
					local seg1 = beam.segments[j]
					local seg2 = beam.segments[j + 1]

					-- Average brightness of the two segment endpoints
					local avgBrightness = (seg1.brightness + seg2.brightness) * 0.5

					-- Thickness scales with brightness (brighter = thicker)
					local segOuterWidth = math.max(2, baseOuterWidth * avgBrightness)
					local segInnerWidth = math.max(1, baseInnerWidth * avgBrightness)

					-- Draw outer glow (thicker, more transparent)
					glFunc.LineWidth(segOuterWidth)
					glFunc.Color(beam.r, beam.g, beam.b, alpha * 0.4 * avgBrightness)
					glFunc.BeginEnd(glConst.LINES, function()
						glFunc.Vertex(seg1.x - wcx_cached, wcz_cached - seg1.z, 0)
						glFunc.Vertex(seg2.x - wcx_cached, wcz_cached - seg2.z, 0)
					end)

					-- Draw inner core (thinner, brighter, whiter)
					glFunc.LineWidth(segInnerWidth)
					-- Make lightning core very white with slight blue tint, scaled by brightness
					local coreR = 0.9 + beam.r * 0.1
					local coreG = 0.9 + beam.g * 0.1
					local coreB = 0.95 + beam.b * 0.05
					glFunc.Color(coreR, coreG, coreB, alpha * 0.98 * avgBrightness)
					glFunc.BeginEnd(glConst.LINES, function()
						glFunc.Vertex(seg1.x - wcx_cached, wcz_cached - seg1.z, 0)
						glFunc.Vertex(seg2.x - wcx_cached, wcz_cached - seg2.z, 0)
					end)
				end
			else
				-- Draw regular laser beam as a line with glow effect
				local alpha = 1 - (age / 0.15) -- Fade out over lifetime

				-- Precompute beam widths once
				local outerWidth = math.max(2, beam.thickness * 3 * zoomScale)
				local innerWidth = math.max(1, beam.thickness * 1.5 * zoomScale)

				-- Precompute vertex positions
				local ox = beam.ox - wcx_cached
				local oz = wcz_cached - beam.oz
				local tx = beam.tx - wcx_cached
				local tz = wcz_cached - beam.tz

				-- Draw outer glow (thicker, more transparent)
				glFunc.LineWidth(outerWidth)
				glFunc.Color(beam.r, beam.g, beam.b, alpha * 0.3)
				glFunc.BeginEnd(glConst.LINES, function()
					glFunc.Vertex(ox, oz, 0)
					glFunc.Vertex(tx, tz, 0)
				end)

				-- Draw inner core (thinner, brighter, whiter)
				glFunc.LineWidth(innerWidth)
				-- Blend weapon color with white for brighter core
				local whiteness = 0.5 + (beam.thickness / 16) * 0.3  -- 0.5 to 0.8 based on thickness
				local coreR = beam.r * (1 - whiteness) + whiteness
				local coreG = beam.g * (1 - whiteness) + whiteness
				local coreB = beam.b * (1 - whiteness) + whiteness
				glFunc.Color(coreR, coreG, coreB, alpha * 0.95)
				glFunc.BeginEnd(glConst.LINES, function()
					glFunc.Vertex(ox, oz, 0)
					glFunc.Vertex(tx, tz, 0)
				end)
			end

				i = i + 1
			end
		end
	end

	-- Reset line width once at the end
	glFunc.LineWidth(1)
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

	local i = 1
	while i <= #cache.iconShatters do
		local shatter = cache.iconShatters[i]
		local age = gameTime - shatter.startTime
		local progress = age / shatter.duration

		-- Remove old shatters
		if progress >= 1 then
			table.remove(cache.iconShatters, i)
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
					r = shatter.teamR,
					g = shatter.teamG,
				b = shatter.teamB
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
				local hs = frag.halfSize
				-- Draw quad with proper texture coordinate mapping
				glFunc.BeginEnd(glConst.QUADS, function()
					glFunc.TexCoord(frag.uvx1, frag.uvy2)
					glFunc.Vertex(-hs, -hs, 0)
					glFunc.TexCoord(frag.uvx2, frag.uvy2)
					glFunc.Vertex(hs, -hs, 0)
					glFunc.TexCoord(frag.uvx2, frag.uvy1)
					glFunc.Vertex(hs, hs, 0)
					glFunc.TexCoord(frag.uvx1, frag.uvy1)
					glFunc.Vertex(-hs, hs, 0)
				end)
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

	while i <= #cache.seismicPings do
		local ping = cache.seismicPings[i]
		local age = gameTime - ping.startTime

		if age > pingLifetime then
			table.remove(cache.seismicPings, i)
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

	local i = 1
	local wcx_cached = cameraState.wcx
	local wcz_cached = cameraState.wcz

	mapInfo.rad2deg = 57.29577951308232 -- Precompute radians to degrees conversion

	-- Cache world boundaries for culling
	local worldLeft = render.world.l
	local worldRight = render.world.r
	local worldTop = render.world.t
	local worldBottom = render.world.b

	while i <= #cache.explosions do
		local explosion = cache.explosions[i]
		local age = gameTime - explosion.startTime

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

		if age > lifetime then
			table.remove(cache.explosions, i)
			-- Don't increment i when removing
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
					local alpha = (1 - progress) * (1 - progress) -- Faster fade				-- White-blue electric color
					local r, g, b = 0.9, 0.95, 1

					glFunc.PushMatrix()
					glFunc.Translate(explosion.x - wcx_cached, wcz_cached - explosion.z, 0)

					-- Draw bright outer glow first (bigger)
					local glowAlpha = alpha * 0.5
					local glowRadius = baseRadius * 1.8 -- Much bigger glow


					for j = 0, segments - 1 do
						local angle1 = j * angleStep
						local angle2 = (j + 1) * angleStep

						glFunc.BeginEnd(glConst.TRIANGLES, function()
							-- Center vertex
							glFunc.Color(r * 0.7, g * 0.7, b * 0.8, glowAlpha)
							glFunc.Vertex(0, 0, 0)

							-- Edge vertices (fade out)
							glFunc.Color(r * 0.4, g * 0.4, b * 0.5, 0)
							glFunc.Vertex(math.cos(angle1) * glowRadius, math.sin(angle1) * glowRadius, 0)
							glFunc.Vertex(math.cos(angle2) * glowRadius, math.sin(angle2) * glowRadius, 0)
						end)
					end

					-- Draw main flash with brighter core
					local coreAlpha = alpha * 0.95 -- Much brighter
					local edgeAlpha = alpha * 0.5
					local coreRadius = baseRadius * 0.4 -- Smaller tight core

					for j = 0, segments - 1 do
						local angle1 = j * angleStep
						local angle2 = (j + 1) * angleStep

						glFunc.BeginEnd(glConst.TRIANGLES, function()
							-- Center vertex (very bright white-blue)
							glFunc.Color(1, 1, 1, coreAlpha) -- Pure white core
							glFunc.Vertex(0, 0, 0)

							-- Edge vertices (fade to electric blue)
							glFunc.Color(r * 0.8, g * 0.8, b, edgeAlpha)
							glFunc.Vertex(math.cos(angle1) * coreRadius, math.sin(angle1) * coreRadius, 0)

							glFunc.Color(r * 0.8, g * 0.8, b, edgeAlpha)
							glFunc.Vertex(math.cos(angle2) * coreRadius, math.sin(angle2) * coreRadius, 0)
						end)
					end

					-- Draw electric sparks
					for k = 1, #explosion.particles do
						local particle = explosion.particles[k]
						local particleAge = age
						local particleProgress = particleAge / particle.life

						if particleProgress < 1 then
							-- Update particle position
							particle.x = particle.x + particle.vx * (1 / 30) -- Approximate frame time
							particle.z = particle.z + particle.vz * (1 / 30)

							-- Draw spark as small line
							local sparkAlpha = (1 - particleProgress) * 0.9
							local sparkLength = particle.size * (1 - particleProgress * 0.5)

							-- Spark direction based on velocity
							local sparkDirX = particle.vx * 0.3
							local sparkDirZ = particle.vz * 0.3

							glFunc.LineWidth(math.max(1, particle.size * 0.8))
							glFunc.Color(r, g, b, sparkAlpha)
							glFunc.BeginEnd(glConst.LINES, function()
								glFunc.Vertex(particle.x - sparkDirX, particle.z - sparkDirZ, 0)
								glFunc.Vertex(particle.x + sparkDirX, particle.z + sparkDirZ, 0)
							end)
						end
					end

					glFunc.PopMatrix()
				else
					-- Normal explosion rendering
					-- Scale down big explosions by 25% (multiply radius by 0.75)
					local effectiveRadius = explosion.radius
					if explosion.radius > 80 then
						effectiveRadius = explosion.radius * 0.75
					end

					local baseRadius = effectiveRadius * (0.3 + progress * 1.7) -- Expands to 2x size
					local alpha = 1 - progress                  -- Fades out

					-- Add pulsing effect
					local pulseScale = 1 + math.sin(progress * math.pi * 4) * 0.1

					-- Color based on size: small = yellow, large = red-orange to white (nuke-like)
					local r, g, b
					if explosion.isParalyze then
						-- Paralyze explosions: blue-white-ish
						r, g, b = 0.75, 0.85, 1
					elseif explosion.radius > 150 then
						-- Nuke explosions: white to yellow-orange
						r, g, b = 1, 0.9, 0.6
					elseif explosion.radius > 80 then
						-- Large explosions: orange-yellow
						r, g, b = 1, 0.7, 0.2
					else
						-- Normal explosions: yellow to orange
						r, g, b = 1, 0.8 - (explosion.radius / 200), 0
					end

					glFunc.PushMatrix()
					glFunc.Translate(explosion.x - wcx_cached, wcz_cached - explosion.z, 0)

					-- Apply rotation (use precalculated mapInfo.rad2deg)
					--local rotation = explosion.rotationSpeed * age * mapInfo.rad2deg
					--glFunc.Rotate(rotation, 0, 0, 1)

					-- Bigger explosions are more opaque
					local coreAlpha = alpha
					local edgeAlpha = alpha * 0.85
					if explosion.radius > 150 then
						coreAlpha = math.min(1, alpha * 1.2) -- Nukes more opaque
						edgeAlpha = math.min(1, alpha * 1.1)
					elseif explosion.radius > 80 then
						coreAlpha = math.min(1, alpha * 1.1) -- Large explosions more opaque
						edgeAlpha = math.min(1, alpha * 0.95)
					end

					local ringProgress = math.max(0, progress * 0.12) -- Stagger more tightly
					if ringProgress > 0 then
						-- Normalize ringProgress to 0-1 range for proper fading (max is 0.12)
						local ringAlpha = (1 - math.min(1, ringProgress / 0.12)) * alpha * 0.8
						local ringRadius = baseRadius * (0.8 + ringProgress * 0.4)
						-- Thicker lines for bigger explosions
						local lineWidth = 4
						if explosion.radius > 150 then
							lineWidth = 6
						elseif explosion.radius > 80 then
							lineWidth = 5
						end
						glFunc.LineWidth(lineWidth)
						glFunc.Color(r, g, b, ringAlpha)
						glFunc.BeginEnd(glConst.LINE_LOOP, function()
							for j = 0, segments do
								local angle = j * angleStep
								glFunc.Vertex(math.cos(angle) * ringRadius, math.sin(angle) * ringRadius, 0)
							end
						end)
					end

					-- Add extra bright flash for massive explosions at the start
					if (explosion.isParalyze or explosion.radius > 150) and actualProgress < 0.45 then
						-- Flash only in first part of explosion
						local flashProgress = actualProgress / 0.45
						local flashAlpha = (1 - flashProgress) * alpha
						local flashRadius = baseRadius * 0.9
						if explosion.isParalyze then
							glFunc.Color(0.65, 0.7, 1, flashAlpha)
						else
							glFunc.Color(1, 1, 1, flashAlpha)
						end
						glFunc.BeginEnd(glConst.TRIANGLE_FAN, function()
							glFunc.Vertex(0, 0, 0)
							for j = 0, segments do
								local angle = j * angleStep
								glFunc.Vertex(math.cos(angle) * flashRadius, math.sin(angle) * flashRadius, 0)
							end
						end)
					end

					glFunc.PopMatrix()
				end
				i = i + 1
			end
		end
	end
	glFunc.LineWidth(1)
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
		-- Cache unitpic path (buildpic texture)
		local unitpicPath = 'unitpics/' .. uDef.name .. '.dds'
		if VFS.FileExists(unitpicPath) then
			cache.unitPic[uDefID] = unitpicPath
		end

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

	-- Initialize LOS shader for red-to-greyscale conversion
	losShader = gl.CreateShader(losShaderCode)
	if not losShader then
		Spring.Echo("PIP: Failed to compile LOS shader, LOS overlay will be disabled")
		Spring.Echo("PIP: Shader log: " .. (gl.GetShaderLog() or "no log"))
		if pipR2T.losTex then
			gl.DeleteTexture(pipR2T.losTex)
			pipR2T.losTex = nil
		end
	end

	-- Initialize water shader if map has water
	if mapInfo.hasWater then
		waterShader = gl.CreateShader(waterShaderCode)
		if not waterShader then
			Spring.Echo("PIP: Failed to compile water shader")
			Spring.Echo("PIP: Shader log: " .. (gl.GetShaderLog() or "no log"))
		end
	end

	-- Localize weapon data for performance
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
		elseif wDef.type == "LightningCannon" then
			cache.weaponIsLightning[wDefID] = true
		elseif wDef.type == "Flame" then
			cache.weaponIsFlame[wDefID] = true
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
end

gameHasStarted = (Spring.GetGameFrame() > 0)
miscState.startX, _, miscState.startZ = Spring.GetTeamStartPosition(Spring.GetMyTeamID())

-- For spectators on first maximize, center on map and zoom out more
local isSpectator = Spring.GetSpectatingState()
if isSpectator and not miscState.hadSavedConfig then
	-- Center on map
	cameraState.wcx = mapInfo.mapSizeX / 2
	cameraState.wcz = mapInfo.mapSizeZ / 2
	cameraState.targetWcx = cameraState.wcx
	cameraState.targetWcz = cameraState.wcz
	-- Zoom out more to see more of the map
	cameraState.zoom = 0.3
	cameraState.targetZoom = 0.3
elseif (not cameraState.wcx or not cameraState.wcz) and miscState.startX and miscState.startX >= 0 then
	-- Only set camera position if not already loaded from config (for players)
	cameraState.wcx, cameraState.wcz = miscState.startX, miscState.startZ
	cameraState.targetWcx, cameraState.targetWcz = cameraState.wcx, cameraState.wcz  -- Initialize targets
end

-- Always minimize PIP when first starting (only on fresh start, not on reload)
if not uiState.inMinMode and not miscState.hadSavedConfig then
		uiState.savedDimensions = {
			l = render.dim.l,
			r = render.dim.r,
			b = render.dim.b,
			t = render.dim.t
		}
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
			end
		end
	end

	-- Register guishader blur for PIP background
	UpdateGuishaderBlur()
end

function widget:ViewResize()

	font = WG['fonts'].getFont(2)

	local oldVsx, oldVsy = render.vsx, render.vsy
	-- Ensure dim fields are initialized before arithmetic operations
	if render.dim.l and render.dim.r and render.dim.b and render.dim.t then
		render.dim.l, render.dim.r, render.dim.b, render.dim.t = render.dim.l/oldVsx, render.dim.r/oldVsx, render.dim.b/oldVsy, render.dim.t/oldVsy
	else
		-- Initialize with default values if not set
		render.dim.l = 0.7
		render.dim.r = 0.7 + (config.minPanelSize * render.widgetScale * 1.4) / oldVsx
		render.dim.b = 0.7
		render.dim.t = 0.7 + (config.minPanelSize * render.widgetScale * 1.2) / oldVsy
	end
	render.vsx, render.vsy = Spring.GetViewGeometry()
	render.dim.l, render.dim.r, render.dim.b, render.dim.t = math.floor(render.dim.l*render.vsx), math.floor(render.dim.r*render.vsx), math.floor(render.dim.b*render.vsy), math.floor(render.dim.t*render.vsy)

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
	if uiState.savedDimensions.l and uiState.savedDimensions.r and uiState.savedDimensions.b and uiState.savedDimensions.t then
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
		-- Fallback to screen edge if no saved dimensions
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
	local visibleWorldWidth = pipWidth / cameraState.zoom
	local visibleWorldHeight = pipHeight / cameraState.zoom
	local smallerVisibleDimension = math.min(visibleWorldWidth, visibleWorldHeight)
	local margin = smallerVisibleDimension * config.mapEdgeMargin

	local minWcx = visibleWorldWidth / 2 - margin
	local maxWcx = mapInfo.mapSizeX - (visibleWorldWidth / 2 - margin)
	local minWcz = visibleWorldHeight / 2 - margin
	local maxWcz = mapInfo.mapSizeZ - (visibleWorldHeight / 2 - margin)

	cameraState.wcx = math.min(math.max(cameraState.wcx, minWcx), maxWcx)
	cameraState.wcz = math.min(math.max(cameraState.wcz, minWcz), maxWcz)
	cameraState.targetWcx = cameraState.wcx
	cameraState.targetWcz = cameraState.wcz

	RecalculateWorldCoordinates()
	RecalculateGroundTextureCoordinates()

	-- Delete and recreate texture on size change
	if pipR2T.contentTex then
		gl.DeleteTexture(pipR2T.contentTex)
		pipR2T.contentTex = nil
	end
	pipR2T.contentNeedsUpdate = true

	-- Update guishader blur dimensions
	UpdateGuishaderBlur()
end

function widget:PlayerChanged(playerID)
	-- Update LOS texture when player state changes (e.g., entering/exiting spec mode)
	pipR2T.losNeedsUpdate = true

	-- Update spec state
	cameraState.mySpecState = Spring.GetSpectatingState()

	-- Keep tracking even if fullview is disabled - tracking will resume when fullview is re-enabled
end

function widget:Shutdown()
	gl.DeleteList(unitOutlineList)
	gl.DeleteList(radarDotList)
	DeleteSeismicPingDlists()

	-- Clean up render-to-texture
	if pipR2T.contentTex then
		gl.DeleteTexture(pipR2T.contentTex)
		pipR2T.contentTex = nil
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

	-- Clean up LOS shader
	if losShader then
		gl.DeleteShader(losShader)
		losShader = nil
	end

	if waterShader then
		gl.DeleteShader(waterShader)
		waterShader = nil
	end

	-- Clean up minimize mode display list
	if render.minModeDlist then
		gl.DeleteList(render.minModeDlist)
		render.minModeDlist = nil
	end

	-- Remove guishader blur
	if WG['guishader'] then
		if WG['guishader'].RemoveDlist then
			WG['guishader'].RemoveDlist('pip'..pipNumber)
		elseif WG['guishader'].RemoveRect then
			WG['guishader'].RemoveRect('pip'..pipNumber)
		end
	end
	-- Clean up our guishader dlist
	if render.guishaderDlist then
		gl.DeleteList(render.guishaderDlist)
		render.guishaderDlist = nil
	end

	-- Clean up API
	WG['pip'..pipNumber] = nil

	for i = 1, #buttons do
		local button = buttons[i]
		if button.command then
			widgetHandler.actionHandler:RemoveAction(self, button.command)

			-- Unbind hotkeys for specific commands
			if button.command == 'pip_copy' then
				Spring.SendCommands("unbind Alt+Q pip_copy")
			elseif button.command == 'pip_switch' then
				Spring.SendCommands("unbind Shift+Q pip_switch")
			end
		end
	end
end

function widget:GetConfigData()
	CorrectScreenPosition()

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
		drawingGround=uiState.drawingGround,
		drawProjectiles=config.drawProjectiles,
		areTracking=interactionState.areTracking,
		trackingPlayerID=interactionState.trackingPlayerID,
		trackingSmoothness=config.trackingSmoothness,
		radarWobbleSpeed=config.radarWobbleSpeed,
		losViewEnabled=state.losViewEnabled,
		losViewAllyTeam=state.losViewAllyTeam,
		showUnitpics=config.showUnitpics,
		unitpicZoomThreshold=config.unitpicZoomThreshold,
		gameID = Game.gameID or Spring.GetGameRulesParam("GameID"),
		worldIconTooltipShownTotal = miscState.worldIconTooltipShownTotal,
	}
end

function widget:SetConfigData(data)
	--Spring.Echo(data)
	miscState.hadSavedConfig = (data and next(data) ~= nil) -- Mark that we have saved config data

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
			local windowWidth = tempR - tempL
			local windowHeight = tempT - tempB

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

	uiState.drawingGround = data.drawingGround~= nil and data.drawingGround or uiState.drawingGround
	config.drawProjectiles = data.drawProjectiles~= nil and data.drawProjectiles or config.drawProjectiles
	config.trackingSmoothness = data.trackingSmoothness or config.trackingSmoothness
	config.radarWobbleSpeed = data.radarWobbleSpeed or config.radarWobbleSpeed
	if data.showUnitpics ~= nil then config.showUnitpics = data.showUnitpics end
	--if data.unitpicZoomThreshold then config.unitpicZoomThreshold = data.unitpicZoomThreshold end

	-- Restore persistent tooltip counter
	if data.worldIconTooltipShownTotal and type(data.worldIconTooltipShownTotal) == "number" then
		miscState.worldIconTooltipShownTotal = data.worldIconTooltipShownTotal
	end

	local currentGameID = Game.gameID and Game.gameID or Spring.GetGameRulesParam("GameID")
	local isSameGame = (data.gameID and currentGameID and data.gameID == currentGameID)

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

-- Helper function to draw command queues overlay
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
				unitCount = unitCount + 1
				unitsToShow[unitCount] = miscState.pipUnits[i]
			end
		end
	else
		-- Show only selected units (or tracked player's selected units)
		local selectedUnits
		if interactionState.trackingPlayerID then
			-- Get tracked player's selected units
			local playerSelections = WG['allyselectedunits'] and WG['allyselectedunits'].getPlayerSelectedUnits(interactionState.trackingPlayerID)
			if playerSelections then
				-- Convert table to array
				selectedUnits = {}
				for unitID, _ in pairs(playerSelections) do
					selectedUnits[#selectedUnits + 1] = unitID
				end
			end
		else
			-- Use cached selected units to avoid redundant API call
			selectedUnits = cachedSelectedUnits
		end

		if not selectedUnits then
			return
		end
		local selectedCount = #selectedUnits
		if selectedCount == 0 then
			return
		end
		-- Copy selected units to pool (avoid using external array directly)
		for i = 1, selectedCount do
			unitsToShow[i] = selectedUnits[i]
		end
		unitCount = selectedCount
	end

	if unitCount == 0 then
		return
	end

	gl.Scissor(render.dim.l, render.dim.b, render.dim.r - render.dim.l, render.dim.t - render.dim.b)
	glFunc.LineWidth(1.0)
	gl.LineStipple("springdefault")

	-- Collect all line segments and markers into batches (massively reduces closure allocations)
	local linePool = pools.commandLine
	local markerPool = pools.commandMarker
	local lineCount = 0
	local markerCount = 0
	local maxUnits = Game.maxUnits or 32000	-- Features are encoded as featureID + Game.maxUnits in commands

	for i = 1, unitCount do
		local uID = unitsToShow[i]
		local ux, uy, uz = spFunc.GetUnitPosition(uID)
		if ux then
			local startSX, startSY = WorldToPipCoords(ux, uz)
			local commands = spFunc.GetUnitCommands(uID, 30)

			if commands then
				local cmdCount = #commands
				if cmdCount > 0 then
					local prevSX, prevSY = startSX, startSY

					for j = 1, cmdCount do
						local cmd = commands[j]
						local cmdX, cmdZ
						local params = cmd.params
						if params then
							local paramCount = #params
							if paramCount == 3 or cmd.id == 10 then
								-- Regular positional command (move, attack-ground, etc.)
								cmdX, cmdZ = params[1], params[3]
							elseif paramCount == 4 then
								-- Area commands (reclaim, repair, etc.) have 4 params: {x, y, z, radius}
								cmdX, cmdZ = params[1], params[3]
							elseif paramCount == 5 then
								-- 5 params could be: {targetID, x, y, z, radius} for set-target area commands
								if params[1] > 0 and params[1] < 1000000 then
									-- It's a target ID command
									local targetID = params[1]
									local tx, ty, tz = spFunc.GetUnitPosition(targetID)
									if tx then
										cmdX, cmdZ = tx, tz
									end
								else
									-- Treat as positional
									cmdX, cmdZ = params[2], params[4]
								end
							elseif paramCount == 1 then
								local targetID = params[1]
								local tx, ty, tz
								if targetID >= maxUnits then	-- Features are encoded as featureID + Game.maxUnits in commands
									tx, ty, tz = spFunc.GetFeaturePosition(targetID - maxUnits)
								else
									tx, ty, tz = spFunc.GetUnitPosition(targetID)
								end
								if tx then
									cmdX, cmdZ = tx, tz
								end
							end
						end
						if cmdX and cmdZ then
							local cmdSX, cmdSY = WorldToPipCoords(cmdX, cmdZ)

							-- Use cmdColors table
							local color = cmdColors[cmd.id] or cmdColors.unknown
							local r, g, b = color[1], color[2], color[3]

							-- Add line segment to batch
							lineCount = lineCount + 1
							local lineData = linePool[lineCount]
							if not lineData then
								lineData = {}
								linePool[lineCount] = lineData
							end
							lineData.x1, lineData.y1 = prevSX, prevSY
							lineData.x2, lineData.y2 = cmdSX, cmdSY
							lineData.r, lineData.g, lineData.b = r, g, b

							-- Add marker to batch
							markerCount = markerCount + 1
							local markerData = markerPool[markerCount]
							if not markerData then
								markerData = {}
								markerPool[markerCount] = markerData
							end
							markerData.x, markerData.y = cmdSX, cmdSY
							markerData.r, markerData.g, markerData.b = r, g, b

							prevSX, prevSY = cmdSX, cmdSY
						end
					end
				end
			end
		end
	end

	-- Draw all lines in ONE gl.BeginEnd call (massive performance improvement)
	if lineCount > 0 then
		glFunc.BeginEnd(GL.LINES, function()
			for i = 1, lineCount do
				local line = linePool[i]
				glFunc.Color(line.r, line.g, line.b, 0.8)
				glFunc.Vertex(line.x1, line.y1)
				glFunc.Vertex(line.x2, line.y2)
			end
		end)
	end

	-- Draw all markers in ONE gl.BeginEnd call
	if markerCount > 0 then
		glFunc.BeginEnd(GL.QUADS, function()
			for i = 1, markerCount do
				local marker = markerPool[i]
				glFunc.Color(marker.r, marker.g, marker.b, 0.8)
				local x, y = marker.x, marker.y
				glFunc.Vertex(x - 3, y - 3)
				glFunc.Vertex(x + 3, y - 3)
				glFunc.Vertex(x + 3, y + 3)
				glFunc.Vertex(x - 3, y + 3)
			end
		end)
	end

	-- Clear leftover entries in pools
	for i = unitCount + 1, #unitsToShow do
		unitsToShow[i] = nil
	end

	gl.LineStipple(false)
	glFunc.LineWidth(1.0)
	gl.Scissor(false)
end

-- Helper function to draw build preview for cursor
local function DrawBuildPreview(mx, my, iconRadiusZoomDistMult)
	if mx < render.dim.l or mx > render.dim.r or my < render.dim.b or my > render.dim.t then
		return
	end

	local _, activeCmdID = Spring.GetActiveCommand()

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
	local selectedUnits = cachedSelectedUnits
	local selectedCount = selectedUnits and #selectedUnits or 0
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
		local queue = spFunc.GetCommandQueue(unitID, -1)

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

-- Helper function to draw icons (when zoomed out)
local function DrawIcons()
	-- Batch icon drawing by texture to minimize state changes
	local distMult = math.min(math.max(1, 2.2-(cameraState.zoom*3.3)), 3)
	local iconRadiusZoom = config.iconRadius * cameraState.zoom
	local iconRadiusZoomDistMult = iconRadiusZoom * distMult

	-- Check if we should use unitpics instead of icons
	local useUnitpics = config.showUnitpics and cameraState.zoom >= config.unitpicZoomThreshold

	-- Texture coordinate inset to prevent edge bleeding
	local texInset = 0.004

	-- Reuse pooled tables to avoid allocations every frame
	local iconsByTexture = pools.iconsByTexture
	local unitpicsByTexture = pools.unitpicsByTexture
	local defaultIconIndices = pools.defaultIconIndices

	-- Clear pool tables from previous frame and track sizes
	local textureSizes = {}
	for k in pairs(iconsByTexture) do
		local t = iconsByTexture[k]
		for i = #t, 1, -1 do
			t[i] = nil
		end
		textureSizes[k] = 0
	end
	-- Clear unitpic pool tables
	local unitpicSizes = {}
	for k in pairs(unitpicsByTexture) do
		local t = unitpicsByTexture[k]
		for i = #t, 1, -1 do
			t[i] = nil
		end
		unitpicSizes[k] = 0
	end
	local defaultCount = 0

	local iconCount = #drawData.iconTeam
	for i = 1, iconCount do
		local udef = drawData.iconUdef[i]
		if udef and cache.unitIcon[udef] then
			local bitmap = cache.unitIcon[udef].bitmap
			local texGroup = iconsByTexture[bitmap]
			local groupSize = textureSizes[bitmap]
			if not texGroup then
				texGroup = {}
				groupSize = 0
				iconsByTexture[bitmap] = texGroup
			end
			groupSize = groupSize + 1
			textureSizes[bitmap] = groupSize
			texGroup[groupSize] = i

			-- Also group by unitpic if we're using unitpics
			if useUnitpics and cache.unitPic[udef] then
				local unitpic = cache.unitPic[udef]
				local picGroup = unitpicsByTexture[unitpic]
				local picGroupSize = unitpicSizes[unitpic]
				if not picGroup then
					picGroup = {}
					picGroupSize = 0
					unitpicsByTexture[unitpic] = picGroup
				end
				picGroupSize = picGroupSize + 1
				unitpicSizes[unitpic] = picGroupSize
				picGroup[picGroupSize] = i
			end
		else
			defaultCount = defaultCount + 1
			defaultIconIndices[defaultCount] = i
		end
	end

	-- Clear leftover default indices
	for i = defaultCount + 1, #defaultIconIndices do
		defaultIconIndices[i] = nil
	end

	-- Draw unitpics when zoomed in enough (before icons so icons layer on top if needed)
	if useUnitpics then
		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
		-- Unitpic size multiplier (smaller than icons since they have no transparency)
		local unitpicSizeMult = 0.85
		-- Texcoord inset for 30% zoom (0.15 on each side)
		local picTexInset = 0.18 * (1 - (cameraState.zoom - config.unitpicZoomThreshold) / (1 - config.unitpicZoomThreshold))
		-- Fixed border sizes in world units
		local teamBorderSize = 3 * cameraState.zoom * distMult
		local blackBorderSize = 4 * cameraState.zoom * distMult
		-- Corner cut ratio (0.25 = cut 25% of each corner of the unitpic)
		local cornerCutRatio = 0.25

		-- Helper function to draw octagon vertices (for use in BeginEnd with TRIANGLE_FAN)
		-- Uses absolute corner cut 'c' so all layers align
		local function drawOctagonVertices(cx, cy, s, c)
			glFunc.Vertex(cx, cy, 0)  -- Center
			glFunc.Vertex(cx - s + c, cy - s, 0)  -- Bottom left side
			glFunc.Vertex(cx + s - c, cy - s, 0)  -- Bottom right side
			glFunc.Vertex(cx + s, cy - s + c, 0)  -- Right bottom side
			glFunc.Vertex(cx + s, cy + s - c, 0)  -- Right top side
			glFunc.Vertex(cx + s - c, cy + s, 0)  -- Top right side
			glFunc.Vertex(cx - s + c, cy + s, 0)  -- Top left side
			glFunc.Vertex(cx - s, cy + s - c, 0)  -- Left top side
			glFunc.Vertex(cx - s, cy - s + c, 0)  -- Left bottom side
			glFunc.Vertex(cx - s + c, cy - s, 0)  -- Close back to start
		end

		-- Helper for textured octagon (unitpic) - Y flipped
		-- Uses absolute corner cut 'c' so all layers align
		-- Maps texture coordinates directly based on vertex position within the square
		local function drawTexturedOctagonVertices(cx, cy, s, c, texIn)
			local t0, t1 = texIn, 1 - texIn
			local tRange = t1 - t0
			local tMid = (t0 + t1) * 0.5
			-- Convert position offset to texcoord offset
			local function posToTex(px, py)
				-- px, py are offsets from center in range [-s, s]
				-- Map to texcoord range [t0, t1], with Y flipped
				local tx = t0 + tRange * (px + s) / (2 * s)
				local ty = t1 - tRange * (py + s) / (2 * s)  -- Y flipped
				return tx, ty
			end
			-- Center
			glFunc.TexCoord(tMid, tMid)
			glFunc.Vertex(cx, cy, 0)
			-- Bottom left side
			local tx, ty = posToTex(-s + c, -s)
			glFunc.TexCoord(tx, ty)
			glFunc.Vertex(cx - s + c, cy - s, 0)
			-- Bottom right side
			tx, ty = posToTex(s - c, -s)
			glFunc.TexCoord(tx, ty)
			glFunc.Vertex(cx + s - c, cy - s, 0)
			-- Right bottom side
			tx, ty = posToTex(s, -s + c)
			glFunc.TexCoord(tx, ty)
			glFunc.Vertex(cx + s, cy - s + c, 0)
			-- Right top side
			tx, ty = posToTex(s, s - c)
			glFunc.TexCoord(tx, ty)
			glFunc.Vertex(cx + s, cy + s - c, 0)
			-- Top right side
			tx, ty = posToTex(s - c, s)
			glFunc.TexCoord(tx, ty)
			glFunc.Vertex(cx + s - c, cy + s, 0)
			-- Top left side
			tx, ty = posToTex(-s + c, s)
			glFunc.TexCoord(tx, ty)
			glFunc.Vertex(cx - s + c, cy + s, 0)
			-- Left top side
			tx, ty = posToTex(-s, s - c)
			glFunc.TexCoord(tx, ty)
			glFunc.Vertex(cx - s, cy + s - c, 0)
			-- Left bottom side
			tx, ty = posToTex(-s, -s + c)
			glFunc.TexCoord(tx, ty)
			glFunc.Vertex(cx - s, cy - s + c, 0)
			-- Close back to start
			tx, ty = posToTex(-s + c, -s)
			glFunc.TexCoord(tx, ty)
			glFunc.Vertex(cx - s + c, cy - s, 0)
		end

		-- PASS 1: Draw black outer borders (no texture)
		glFunc.Texture(false)
		glFunc.Color(0, 0, 0, 0.9)
		if render.minimapRotation ~= 0 then
			for texture, indices in pairs(unitpicsByTexture) do
				local indexCount = #indices
				for j = 1, indexCount do
					local i = indices[j]
					local cx = drawData.iconX[i]
					local cy = drawData.iconY[i]
					local udef = drawData.iconUdef[i]
					local iconSize = iconRadiusZoomDistMult * cache.unitIcon[udef].size * unitpicSizeMult
					local borderSize = iconSize + teamBorderSize + blackBorderSize
					local cornerCut = (iconSize + teamBorderSize + blackBorderSize) * cornerCutRatio * 1.2  -- Absolute corner cut based on unitpic size

					glFunc.PushMatrix()
					glFunc.Translate(cx, cy, 0)
					glFunc.Rotate(-render.minimapRotation * 180 / math.pi, 0, 0, 1)
					glFunc.BeginEnd(glConst.TRIANGLE_FAN, drawOctagonVertices, 0, 0, borderSize, cornerCut)
					glFunc.PopMatrix()
				end
			end
		else
			for texture, indices in pairs(unitpicsByTexture) do
				local indexCount = #indices
				for j = 1, indexCount do
					local i = indices[j]
					local cx = drawData.iconX[i]
					local cy = drawData.iconY[i]
					local udef = drawData.iconUdef[i]
					local iconSize = iconRadiusZoomDistMult * cache.unitIcon[udef].size * unitpicSizeMult
					local borderSize = iconSize + teamBorderSize + blackBorderSize
					local cornerCut = (iconSize + teamBorderSize + blackBorderSize) * cornerCutRatio * 1.2	-- Absolute corner cut based on unitpic size

					glFunc.BeginEnd(glConst.TRIANGLE_FAN, drawOctagonVertices, cx, cy, borderSize, cornerCut)
				end
			end
		end

		-- PASS 2: Draw team-colored inner borders (no texture)
		if render.minimapRotation ~= 0 then
			for texture, indices in pairs(unitpicsByTexture) do
				local indexCount = #indices
				for j = 1, indexCount do
					local i = indices[j]
					local cx = drawData.iconX[i]
					local cy = drawData.iconY[i]
					local udef = drawData.iconUdef[i]
					local iconSize = iconRadiusZoomDistMult * cache.unitIcon[udef].size * unitpicSizeMult
					local borderSize = iconSize + teamBorderSize
					local cornerCut = (iconSize + teamBorderSize + blackBorderSize) * cornerCutRatio  -- Absolute corner cut based on unitpic size

					local color = teamColors[drawData.iconTeam[i]]
					if drawData.iconSelected[i] then
						glFunc.Color(1, 1, 1, 1)
					else
						glFunc.Color(color[1], color[2], color[3], 1)
					end

					glFunc.PushMatrix()
					glFunc.Translate(cx, cy, 0)
					glFunc.Rotate(-render.minimapRotation * 180 / math.pi, 0, 0, 1)
					glFunc.BeginEnd(glConst.TRIANGLE_FAN, drawOctagonVertices, 0, 0, borderSize, cornerCut)
					glFunc.PopMatrix()
				end
			end
		else
			for texture, indices in pairs(unitpicsByTexture) do
				local indexCount = #indices
				for j = 1, indexCount do
					local i = indices[j]
					local cx = drawData.iconX[i]
					local cy = drawData.iconY[i]
					local udef = drawData.iconUdef[i]
					local iconSize = iconRadiusZoomDistMult * cache.unitIcon[udef].size * unitpicSizeMult
					local borderSize = iconSize + teamBorderSize
					local cornerCut = (iconSize + teamBorderSize + blackBorderSize) * cornerCutRatio  -- Absolute corner cut based on unitpic size

					local color = teamColors[drawData.iconTeam[i]]
					if drawData.iconSelected[i] then
						glFunc.Color(1, 1, 1, 1)
					else
						glFunc.Color(color[1], color[2], color[3], 1)
					end

					glFunc.BeginEnd(glConst.TRIANGLE_FAN, drawOctagonVertices, cx, cy, borderSize, cornerCut)
				end
			end
		end

		-- PASS 3: Draw unitpics on top (textured octagons)
		for texture, indices in pairs(unitpicsByTexture) do
			glFunc.Texture(texture)
			local indexCount = #indices

			if render.minimapRotation ~= 0 then
				for j = 1, indexCount do
					local i = indices[j]
					local cx = drawData.iconX[i]
					local cy = drawData.iconY[i]
					local udef = drawData.iconUdef[i]
					local iconSize = iconRadiusZoomDistMult * cache.unitIcon[udef].size * unitpicSizeMult
					local cornerCut = (iconSize + teamBorderSize + blackBorderSize) * cornerCutRatio  -- Absolute corner cut based on unitpic size

					local buildProgress = drawData.iconBuildProgress[i]
					local opacity = buildProgress >= 1 and 1.0 or (0.2 + (buildProgress * 0.5))

					local isHovered = (drawData.hoveredUnitID and drawData.iconUnitID[i] == drawData.hoveredUnitID)

					if drawData.iconSelected[i] then
						if isHovered then
							glFunc.Color(1, 1, 1, math.min(1.0, opacity * 1.3))
						else
							glFunc.Color(1, 1, 1, opacity)
						end
					else
						local color = teamColors[drawData.iconTeam[i]]
						local brightness = 0.7 + (color[1] + color[2] + color[3]) / 9
						if isHovered then
							glFunc.Color(brightness * 1.2, brightness * 1.2, brightness * 1.2, opacity)
						else
							glFunc.Color(brightness, brightness, brightness, opacity)
						end
					end

					glFunc.PushMatrix()
					glFunc.Translate(cx, cy, 0)
					glFunc.Rotate(-render.minimapRotation * 180 / math.pi, 0, 0, 1)
					glFunc.BeginEnd(glConst.TRIANGLE_FAN, drawTexturedOctagonVertices, 0, 0, iconSize, cornerCut, picTexInset)
					glFunc.PopMatrix()
				end
			else
				for j = 1, indexCount do
					local i = indices[j]
					local cx = drawData.iconX[i]
					local cy = drawData.iconY[i]
					local udef = drawData.iconUdef[i]
					local iconSize = iconRadiusZoomDistMult * cache.unitIcon[udef].size * unitpicSizeMult
					local cornerCut = (iconSize + teamBorderSize + blackBorderSize) * cornerCutRatio  -- Absolute corner cut based on unitpic size

					local buildProgress = drawData.iconBuildProgress[i]
					local opacity = buildProgress >= 1 and 1.0 or (0.2 + (buildProgress * 0.5))

					local isHovered = (drawData.hoveredUnitID and drawData.iconUnitID[i] == drawData.hoveredUnitID)

					if drawData.iconSelected[i] then
						if isHovered then
							glFunc.Color(1, 1, 1, math.min(1.0, opacity * 1.3))
						else
							glFunc.Color(1, 1, 1, opacity)
						end
					else
						opacity = opacity
						local color = teamColors[drawData.iconTeam[i]]
						local brightness = 0.7 + (color[1] + color[2] + color[3]) / 9
						if isHovered then
							glFunc.Color(brightness * 1.2, brightness * 1.2, brightness * 1.2, opacity)
						else
							glFunc.Color(brightness, brightness, brightness, opacity)
						end
					end

					glFunc.BeginEnd(glConst.TRIANGLE_FAN, drawTexturedOctagonVertices, cx, cy, iconSize, cornerCut, picTexInset)
				end
			end
		end
		glFunc.Texture(false)
	end

	-- Skip normal icon drawing when using unitpics
	if not useUnitpics then

	-- Draw white backgrounds for tracked units FIRST (before normal icons)
	local trackedCount = #drawData.trackedIconIndices
	if trackedCount > 0 then
		--gl.Blending(GL.ONE, GL.ONE)  -- Full additive blending for bright white glow (when not inverted icon)
		glFunc.Color(1, 1, 1, 0.5)

		-- Group tracked units by texture for batching
		local trackedByTexture = {}
		for i = 1, trackedCount do
			local idx = drawData.trackedIconIndices[i]
			local udef = drawData.iconUdef[idx]
			if udef and cache.unitIcon[udef] then
				local texture = cache.unitIcon[udef].bitmap
				if texture then
					if not trackedByTexture[texture] then
						trackedByTexture[texture] = {}
					end
					trackedByTexture[texture][#trackedByTexture[texture] + 1] = idx
				end
			end
		end

		-- Draw tracked unit backgrounds grouped by texture
		for texture, indices in pairs(trackedByTexture) do
			local invertedTexture = string.gsub(texture, "icons/", "icons/inverted/")
			glFunc.Texture(invertedTexture)

			-- Draw with counter-rotation if map is rotated
			if render.minimapRotation ~= 0 then
				for j = 1, #indices do
					local idx = indices[j]
					if drawData.iconBuildProgress[idx] >= 1 then
						local cx = drawData.iconX[idx]
						local cy = drawData.iconY[idx]
						local udef = drawData.iconUdef[idx]
						local iconSize = iconRadiusZoomDistMult * cache.unitIcon[udef].size
						local baseSize = cache.unitIcon[udef].size
						local borderPixels = 0.09 / baseSize  -- Inverse relationship: smaller units get proportionally more border
						local enlargedSize = iconSize * (1 + borderPixels)

						glFunc.PushMatrix()
						glFunc.Translate(cx, cy, 0)
						glFunc.Rotate(-render.minimapRotation * 180 / math.pi, 0, 0, 1)
						glFunc.BeginEnd(glConst.QUADS, function()
							glFunc.TexCoord(texInset, 1 - texInset)
							glFunc.Vertex(-enlargedSize, -enlargedSize)
							glFunc.TexCoord(1 - texInset, 1 - texInset)
							glFunc.Vertex(enlargedSize, -enlargedSize)
							glFunc.TexCoord(1 - texInset, texInset)
							glFunc.Vertex(enlargedSize, enlargedSize)
							glFunc.TexCoord(texInset, texInset)
							glFunc.Vertex(-enlargedSize, enlargedSize)
						end)
						glFunc.PopMatrix()
					end
				end
			else
				glFunc.BeginEnd(glConst.QUADS, function()
					for j = 1, #indices do
						local idx = indices[j]
						if drawData.iconBuildProgress[idx] >= 1 then
							local cx = drawData.iconX[idx]
							local cy = drawData.iconY[idx]
							local udef = drawData.iconUdef[idx]
							local iconSize = iconRadiusZoomDistMult * cache.unitIcon[udef].size
							local baseSize = cache.unitIcon[udef].size
							local borderPixels = 0.09 / baseSize  -- Inverse relationship: smaller units get proportionally more border
							local enlargedSize = iconSize * (1 + borderPixels)

							glFunc.TexCoord(texInset, 1 - texInset)
							glFunc.Vertex(cx - enlargedSize, cy - enlargedSize)
							glFunc.TexCoord(1 - texInset, 1 - texInset)
							glFunc.Vertex(cx + enlargedSize, cy - enlargedSize)
							glFunc.TexCoord(1 - texInset, texInset)
							glFunc.Vertex(cx + enlargedSize, cy + enlargedSize)
							glFunc.TexCoord(texInset, texInset)
							glFunc.Vertex(cx - enlargedSize, cy + enlargedSize)
						end
					end
				end)
			end
		end
		glFunc.Texture(false)
	end

	-- Draw bright glow for hovered unit (when command is active)
	if drawData.hoveredUnitID then
		glFunc.Color(1, 0.95, 0, 0.66)  -- Bright yellow glow
		gl.Blending(GL.SRC_ALPHA, GL.ONE)  -- Additive blending for bright glow

		-- Find the hovered unit in the draw data
		for i = 1, iconCount do
			if drawData.iconUnitID[i] == drawData.hoveredUnitID and drawData.iconBuildProgress[i] >= 1 then
				local cx = drawData.iconX[i]
				local cy = drawData.iconY[i]
				local udef = drawData.iconUdef[i]

				if udef and cache.unitIcon[udef] then
					local texture = cache.unitIcon[udef].bitmap
					local invertedTexture = string.gsub(texture, "icons/", "icons/inverted/")
					glFunc.Texture(invertedTexture)

					local iconSize = iconRadiusZoomDistMult * cache.unitIcon[udef].size
					local baseSize = cache.unitIcon[udef].size
					local borderPixels = 0.15 / baseSize  -- Larger border for hover glow
					local enlargedSize = iconSize * (1 + borderPixels)

					if render.minimapRotation ~= 0 then
						glFunc.PushMatrix()
						glFunc.Translate(cx, cy, 0)
						glFunc.Rotate(-render.minimapRotation * 180 / math.pi, 0, 0, 1)
						glFunc.BeginEnd(glConst.QUADS, function()
							glFunc.TexCoord(texInset, 1 - texInset)
							glFunc.Vertex(-enlargedSize, -enlargedSize)
							glFunc.TexCoord(1 - texInset, 1 - texInset)
							glFunc.Vertex(enlargedSize, -enlargedSize)
							glFunc.TexCoord(1 - texInset, texInset)
							glFunc.Vertex(enlargedSize, enlargedSize)
							glFunc.TexCoord(texInset, texInset)
							glFunc.Vertex(-enlargedSize, enlargedSize)
						end)
						glFunc.PopMatrix()
					else
						glFunc.BeginEnd(glConst.QUADS, function()
							glFunc.TexCoord(texInset, 1 - texInset)
							glFunc.Vertex(cx - enlargedSize, cy - enlargedSize)
							glFunc.TexCoord(1 - texInset, 1 - texInset)
							glFunc.Vertex(cx + enlargedSize, cy - enlargedSize)
							glFunc.TexCoord(1 - texInset, texInset)
							glFunc.Vertex(cx + enlargedSize, cy + enlargedSize)
							glFunc.TexCoord(texInset, texInset)
							glFunc.Vertex(cx - enlargedSize, cy + enlargedSize)
						end)
					end
					glFunc.Texture(false)
				else
					-- Default icon - draw circle glow
					local defaultIconSize = config.iconRadius * 0.5 * cameraState.zoom * distMult
					local glowSize = defaultIconSize * 1.4
					glFunc.Texture('LuaUI/Images/pip/PipBlip.png')

					if render.minimapRotation ~= 0 then
						glFunc.PushMatrix()
						glFunc.Translate(cx, cy, 0)
						glFunc.Rotate(-render.minimapRotation * 180 / math.pi, 0, 0, 1)
						glFunc.BeginEnd(glConst.QUADS, function()
							glFunc.TexCoord(texInset, 1 - texInset)
							glFunc.Vertex(-glowSize, -glowSize)
							glFunc.TexCoord(1 - texInset, 1 - texInset)
							glFunc.Vertex(glowSize, -glowSize)
							glFunc.TexCoord(1 - texInset, texInset)
							glFunc.Vertex(glowSize, glowSize)
							glFunc.TexCoord(texInset, texInset)
							glFunc.Vertex(-glowSize, glowSize)
						end)
						glFunc.PopMatrix()
					else
						glFunc.BeginEnd(glConst.QUADS, function()
							glFunc.TexCoord(texInset, 1 - texInset)
							glFunc.Vertex(cx - glowSize, cy - glowSize)
							glFunc.TexCoord(1 - texInset, 1 - texInset)
							glFunc.Vertex(cx + glowSize, cy - glowSize)
							glFunc.TexCoord(1 - texInset, texInset)
							glFunc.Vertex(cx + glowSize, cy + glowSize)
							glFunc.TexCoord(texInset, texInset)
							glFunc.Vertex(cx - glowSize, cy + glowSize)
						end)
					end
					glFunc.Texture(false)
				end
				break  -- Found the hovered unit, no need to continue
			end
		end

		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)  -- Restore normal blending
	end	-- Draw icons grouped by texture (minimizes texture binding)
	for texture, indices in pairs(iconsByTexture) do
		glFunc.Texture(texture)
		local indexCount = #indices

		-- Draw normal icons
		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)

		-- Draw with counter-rotation if map is rotated
		if render.minimapRotation ~= 0 then
			for j = 1, indexCount do
				local i = indices[j]
				local cx = drawData.iconX[i]
				local cy = drawData.iconY[i]
				local udef = drawData.iconUdef[i]
				local iconSize = iconRadiusZoomDistMult * cache.unitIcon[udef].size

				local buildProgress = drawData.iconBuildProgress[i]
				local opacity = buildProgress >= 1 and 1.0 or (0.2 + (buildProgress * 0.5))

				local isHovered = (drawData.hoveredUnitID and drawData.iconUnitID[i] == drawData.hoveredUnitID)

				if drawData.iconSelected[i] then
					if isHovered then
						glFunc.Color(1, 1, 1, math.min(1.0, opacity * 1.3))
					else
						glFunc.Color(1, 1, 1, opacity)
					end
				else
					local color = teamColors[drawData.iconTeam[i]]
					if isHovered then
						glFunc.Color(math.min(1.0, color[1] * 1.3), math.min(1.0, color[2] * 1.3), math.min(1.0, color[3] * 1.3), opacity)
					else
						glFunc.Color(color[1], color[2], color[3], opacity)
					end
				end

				-- Counter-rotate to keep icon upright
				glFunc.PushMatrix()
				glFunc.Translate(cx, cy, 0)
				glFunc.Rotate(-render.minimapRotation * 180 / math.pi, 0, 0, 1)
				glFunc.BeginEnd(glConst.QUADS, function()
					glFunc.TexCoord(texInset, 1 - texInset)
					glFunc.Vertex(-iconSize, -iconSize)
					glFunc.TexCoord(1 - texInset, 1 - texInset)
					glFunc.Vertex(iconSize, -iconSize)
					glFunc.TexCoord(1 - texInset, texInset)
					glFunc.Vertex(iconSize, iconSize)
					glFunc.TexCoord(texInset, texInset)
					glFunc.Vertex(-iconSize, iconSize)
				end)
				glFunc.PopMatrix()
			end
		else
			-- Fast batch path when no rotation
			glFunc.BeginEnd(glConst.QUADS, function()
				for j = 1, indexCount do
					local i = indices[j]
					local cx = drawData.iconX[i]
					local cy = drawData.iconY[i]
					local udef = drawData.iconUdef[i]
					local iconSize = iconRadiusZoomDistMult * cache.unitIcon[udef].size

					local buildProgress = drawData.iconBuildProgress[i]
					local opacity = buildProgress >= 1 and 1.0 or (0.2 + (buildProgress * 0.5))

					local isHovered = (drawData.hoveredUnitID and drawData.iconUnitID[i] == drawData.hoveredUnitID)

					if drawData.iconSelected[i] then
						if isHovered then
							glFunc.Color(1, 1, 1, math.min(1.0, opacity * 1.3))
						else
							glFunc.Color(1, 1, 1, opacity)
						end
					else
						local color = teamColors[drawData.iconTeam[i]]
						if isHovered then
							glFunc.Color(math.min(1.0, color[1] * 1.3), math.min(1.0, color[2] * 1.3), math.min(1.0, color[3] * 1.3), opacity)
						else
							glFunc.Color(color[1], color[2], color[3], opacity)
						end
					end
					glFunc.TexCoord(texInset, 1 - texInset)
					glFunc.Vertex(cx - iconSize, cy - iconSize)
					glFunc.TexCoord(1 - texInset, 1 - texInset)
					glFunc.Vertex(cx + iconSize, cy - iconSize)
					glFunc.TexCoord(1 - texInset, texInset)
					glFunc.Vertex(cx + iconSize, cy + iconSize)
					glFunc.TexCoord(texInset, texInset)
					glFunc.Vertex(cx - iconSize, cy + iconSize)
				end
			end)
		end
	end

	-- Draw default icons (fallback radar blip texture for unknown unit types)
	if defaultCount > 0 then
		glFunc.Texture('LuaUI/Images/pip/PipBlip.png')
		local defaultIconSize = config.iconRadius * 0.5 * cameraState.zoom * distMult

		if render.minimapRotation ~= 0 then
			for j = 1, defaultCount do
				local i = defaultIconIndices[j]
				local cx = drawData.iconX[i]
				local cy = drawData.iconY[i]

				local buildProgress = drawData.iconBuildProgress[i]
				local opacity = buildProgress >= 1 and 1.0 or (0.2 + (buildProgress * 0.5))

				local isHovered = (drawData.hoveredUnitID and drawData.iconUnitID[i] == drawData.hoveredUnitID)

				if drawData.iconSelected[i] then
					if isHovered then
						glFunc.Color(1, 1, 1, math.min(1.0, opacity * 1.3))
					else
						glFunc.Color(1, 1, 1, opacity)
					end
				else
					local color = teamColors[drawData.iconTeam[i]]
					if isHovered then
						glFunc.Color(math.min(1.0, color[1] * 1.55), math.min(1.0, color[2] * 1.55), math.min(1.0, color[3] * 1.55), opacity)
					else
						glFunc.Color(color[1], color[2], color[3], opacity)
					end
				end

				-- Counter-rotate to keep icon upright
				glFunc.PushMatrix()
				glFunc.Translate(cx, cy, 0)
				glFunc.Rotate(-render.minimapRotation * 180 / math.pi, 0, 0, 1)
				glFunc.BeginEnd(glConst.QUADS, function()
					glFunc.TexCoord(texInset, 1 - texInset)
					glFunc.Vertex(-defaultIconSize, -defaultIconSize)
					glFunc.TexCoord(1 - texInset, 1 - texInset)
					glFunc.Vertex(defaultIconSize, -defaultIconSize)
					glFunc.TexCoord(1 - texInset, texInset)
					glFunc.Vertex(defaultIconSize, defaultIconSize)
					glFunc.TexCoord(texInset, texInset)
					glFunc.Vertex(-defaultIconSize, defaultIconSize)
				end)
				glFunc.PopMatrix()
			end
		else
			glFunc.BeginEnd(glConst.QUADS, function()
				for j = 1, defaultCount do
					local i = defaultIconIndices[j]
					local cx = drawData.iconX[i]
					local cy = drawData.iconY[i]

					-- 0.2 to 0.7 while building, then jump to 1.0 when complete
					local buildProgress = drawData.iconBuildProgress[i]
					local opacity
					if buildProgress >= 1 then
						opacity = 1.0
					else
						opacity = 0.2 + (buildProgress * 0.5)
					end

				-- Check if this unit is hovered
				local isHovered = (drawData.hoveredUnitID and drawData.iconUnitID[i] == drawData.hoveredUnitID)

				if drawData.iconSelected[i] then
					if isHovered then
						glFunc.Color(1, 1, 1, math.min(1.0, opacity * 1.3))
					else
						glFunc.Color(1, 1, 1, opacity)
					end
				else
					local color = teamColors[drawData.iconTeam[i]]
					if isHovered then
						glFunc.Color(math.min(1.0, color[1] * 1.55), math.min(1.0, color[2] * 1.55), math.min(1.0, color[3] * 1.55), opacity)
					else
						glFunc.Color(color[1], color[2], color[3], opacity)
					end
				end
				-- Use manual texture coordinates with inset to prevent edge bleeding
				glFunc.TexCoord(texInset, 1 - texInset)
				glFunc.Vertex(cx - defaultIconSize, cy - defaultIconSize)
				glFunc.TexCoord(1 - texInset, 1 - texInset)
				glFunc.Vertex(cx + defaultIconSize, cy - defaultIconSize)
				glFunc.TexCoord(1 - texInset, texInset)
				glFunc.Vertex(cx + defaultIconSize, cy + defaultIconSize)
				glFunc.TexCoord(texInset, texInset)
				glFunc.Vertex(cx - defaultIconSize, cy + defaultIconSize)
			end
		end)
		end
	end

	end  -- End of "if not useUnitpics" block

	-- Draw radar blobs for units in radar but not in LOS
	local radarBlobCount = #drawData.radarBlobX
	if radarBlobCount > 0 then
		-- Separate radar blobs into known types (draw as icons) and unknown types (draw as blobs)
		local knownRadarUnits = {}  -- Has unit icon
		local unknownRadarUnits = {}  -- No icon, draw as blob

		for i = 1, radarBlobCount do
			local udef = drawData.radarBlobUdef[i]
			if udef and cache.unitIcon[udef] then
				knownRadarUnits[#knownRadarUnits + 1] = i
			else
				unknownRadarUnits[#unknownRadarUnits + 1] = i
			end
		end

		-- Draw known radar units as semi-transparent icons
		if #knownRadarUnits > 0 then
			local radarIconsByTexture = {}
			for j = 1, #knownRadarUnits do
				local i = knownRadarUnits[j]
				local udef = drawData.radarBlobUdef[i]
				local bitmap = cache.unitIcon[udef].bitmap
				if not radarIconsByTexture[bitmap] then
					radarIconsByTexture[bitmap] = {}
				end
				radarIconsByTexture[bitmap][#radarIconsByTexture[bitmap] + 1] = i
			end

			-- Draw radar icons grouped by texture with reduced opacity
			for texture, indices in pairs(radarIconsByTexture) do
				glFunc.Texture(texture)
				glFunc.BeginEnd(glConst.QUADS, function()
					for j = 1, #indices do
						local i = indices[j]
						local udef = drawData.radarBlobUdef[i]
						local teamID = drawData.radarBlobTeam[i]
						local uID = drawData.radarBlobUnitID[i]
						local baseCx = drawData.radarBlobX[i]
						local baseCy = drawData.radarBlobY[i]

						-- Simulate radar wobble with time-based oscillation
						local time = os.clock()
						local wobbleAmount = iconRadiusZoomDistMult * 0.3
						local wobbleX = math.sin(time * config.radarWobbleSpeed + uID * 0.5) * wobbleAmount
						local wobbleY = math.cos(time * config.radarWobbleSpeed * 1.15 + uID * 0.7) * wobbleAmount
						local cx = baseCx + wobbleX
						local cy = baseCy + wobbleY

						local iconSize = iconRadiusZoomDistMult * cache.unitIcon[udef].size

						if teamColors[teamID] then
							-- Tint with team color and reduced opacity for radar units
							glFunc.Color(teamColors[teamID][1], teamColors[teamID][2], teamColors[teamID][3], 0.75)
							glFunc.TexCoord(texInset, 1 - texInset)
							glFunc.Vertex(cx - iconSize, cy - iconSize)
							glFunc.TexCoord(1 - texInset, 1 - texInset)
							glFunc.Vertex(cx + iconSize, cy - iconSize)
							glFunc.TexCoord(1 - texInset, texInset)
							glFunc.Vertex(cx + iconSize, cy + iconSize)
							glFunc.TexCoord(texInset, texInset)
							glFunc.Vertex(cx - iconSize, cy + iconSize)
						end
					end
				end)
			end
			glFunc.Texture(false)
		end

		-- Draw unknown radar units as circular blobs
		if #unknownRadarUnits > 0 then
			glFunc.Texture('LuaUI/Images/pip/PipBlip.png')
			local blobSize = iconRadiusZoomDistMult * 0.5

			-- Pre-calculate wobble values outside drawing loop for performance
			local time = os.clock()
			local wobbleAmount = iconRadiusZoomDistMult * 0.3
			local wobbleSpeedX = time * config.radarWobbleSpeed
			local wobbleSpeedY = time * config.radarWobbleSpeed * 1.15

			glFunc.BeginEnd(glConst.QUADS, function()
				for j = 1, #unknownRadarUnits do
					local i = unknownRadarUnits[j]
					local uID = drawData.radarBlobUnitID[i]
					local teamID = drawData.radarBlobTeam[i]
					local baseCx = drawData.radarBlobX[i]
					local baseCy = drawData.radarBlobY[i]

					-- Apply wobble
					local cx = baseCx + math.sin(wobbleSpeedX + uID * 0.5) * wobbleAmount
					local cy = baseCy + math.cos(wobbleSpeedY + uID * 0.7) * wobbleAmount
					local teamColor = teamColors[teamID]

					glFunc.Color(teamColor[1], teamColor[2], teamColor[3], 0.6)
					glFunc.TexCoord(0, 0)
					glFunc.Vertex(cx - blobSize, cy - blobSize)
					glFunc.TexCoord(1, 0)
					glFunc.Vertex(cx + blobSize, cy - blobSize)
					glFunc.TexCoord(1, 1)
					glFunc.Vertex(cx + blobSize, cy + blobSize)
					glFunc.TexCoord(0, 1)
					glFunc.Vertex(cx - blobSize, cy + blobSize)
				end
			end)
			glFunc.Texture(false)
		end
	end

	glFunc.Texture(false)

	-- Return iconRadiusZoomDistMult for build preview functions
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

	miscState.pipFeatures = spFunc.GetFeaturesInRectangle(render.world.l - margin, render.world.t - margin, render.world.r + margin, render.world.b + margin)

	-- Cache counts to avoid repeated length calculations
	local unitCount = #miscState.pipUnits
	local featureCount = #miscState.pipFeatures

	-- Clear icon arrays (faster than iterating and setting to nil)
	for i = #drawData.iconTeam, 1, -1 do
		drawData.iconTeam[i] = nil
		drawData.iconX[i] = nil
		drawData.iconY[i] = nil
		drawData.iconUdef[i] = nil
		drawData.iconSelected[i] = nil
		drawData.iconBuildProgress[i] = nil
		drawData.iconUnitID[i] = nil
	end
	-- Clear radar blob arrays
	for i = #drawData.radarBlobX, 1, -1 do
		drawData.radarBlobX[i] = nil
		drawData.radarBlobY[i] = nil
		drawData.radarBlobTeam[i] = nil
		drawData.radarBlobUdef[i] = nil
		drawData.radarBlobUnitID[i] = nil
	end
	-- Clear tracked indices
	for i = #drawData.trackedIconIndices, 1, -1 do
		drawData.trackedIconIndices[i] = nil
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

	glFunc.PushMatrix()
	glFunc.Translate(centerX, centerY, 0)
	glFunc.Scale(cameraState.zoom * contentScale, cameraState.zoom * contentScale, cameraState.zoom * contentScale)

	-- Draw units (only icon data collection now, no 3D rendering)
	for i = 1, unitCount do
		DrawUnit(miscState.pipUnits[i])
	end

	-- Draw features (3D models)
	if cameraState.zoom >= config.zoomFeatures then  -- Only draw features if zoom is above threshold
		glFunc.Texture(0, '$units')
		for i = 1, featureCount do
			DrawFeature(miscState.pipFeatures[i])
		end
	end

		-- Draw projectiles if enabled
	if config.drawProjectiles then
		glFunc.Texture(false)  -- Disable textures for colored projectiles
		gl.Blending(true)
		gl.DepthTest(false)

		if cameraState.zoom >= config.zoomProjectileDetail then
			-- Get projectiles in the PIP window's world rectangle
			local projectiles = spFunc.GetProjectilesInRectangle(render.world.l - margin, render.world.t - margin, render.world.r + margin, render.world.b + margin)
			if projectiles then
				local projectileCount = #projectiles
				for i = 1, projectileCount do
					DrawProjectile(projectiles[i])
				end
			end
		end

		if cameraState.zoom >= config.zoomExplosionDetail then
			if cameraState.zoom >= config.zoomProjectileDetail then
				-- Draw icon shatters
				DrawIconShatters()

				-- Draw laser beams
				DrawLaserBeams()
			end

			-- Draw explosions
			DrawExplosions()
		end

		-- Draw seismic pings (always visible at any zoom level)
		DrawSeismicPings()

		gl.DepthTest(true)
		gl.Blending(false)
	end

	glFunc.PopMatrix()


	glFunc.Texture(0, false)
	gl.Blending(true)
		gl.DepthMask(false)
		gl.DepthTest(false)

		local _, _, _, shift = Spring.GetModKeyState()
		if shift then
			gl.LineStipple("springdefault")
			local selUnits = Spring.GetSelectedUnits()
			local selCount = #selUnits
			for i = 1, selCount do
				glFunc.BeginEnd(glConst.LINES, UnitQueueVertices, selUnits[i])
			end
			gl.LineStipple(false)
		end

		-- Draw icons (when zoomed out)
		local iconRadiusZoomDistMult = DrawIcons()

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
					local cursorSize = render.vsy * 0.0073
					Spring.Echo()
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
					glFunc.LineWidth(render.vsy / 500 + 2)
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
					glFunc.LineWidth(render.vsy / 500)
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
end

-- Helper function to render PIP frame background (static)
local function RenderFrameBackground()
	-- Render panel at origin without accounting for padding (padding drawn separately)
	local pipWidth = render.dim.r - render.dim.l
	local pipHeight = render.dim.t - render.dim.b
	glFunc.Color(0.6,0.6,0.6,0.6)
	render.RectRound(0, 0, pipWidth, pipHeight, render.elementCorner*0.4, 1, 1, 1, 1)
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
	local usedButtonSizeLocal = render.usedButtonSize
	local pipWidth = render.dim.r - render.dim.l
	local pipHeight = render.dim.t - render.dim.b

	-- Skip all rendering if showButtonsOnHoverOnly is enabled and mouse is not over PIP
	if config.showButtonsOnHoverOnly and not interactionState.isMouseOverPip then
		return
	end

	-- Resize handle (bottom-right corner)
	glFunc.Color(config.panelBorderColorDark)
	glFunc.LineWidth(1.0)
	glFunc.BeginEnd(glConst.TRIANGLES, function()
		-- Relative coordinates for resize handle
		glFunc.Vertex(pipWidth - usedButtonSizeLocal, 0)
		glFunc.Vertex(pipWidth, 0)
		glFunc.Vertex(pipWidth, usedButtonSizeLocal)
	end)

	-- Minimize button (top-right)
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
		-- Show pip_track button if has selection or is tracking units
		if buttons[i].command == 'pip_track' then
			if hasSelection or isTracking then
				visibleButtons[#visibleButtons + 1] = buttons[i]
			end
		-- Show pip_trackplayer button if lockcamera is available or already tracking
		elseif buttons[i].command == 'pip_trackplayer' then
			if showPlayerTrackButton then
				visibleButtons[#visibleButtons + 1] = buttons[i]
			end
		-- Show pip_view button only for spectators
		elseif buttons[i].command == 'pip_view' then
			if showPlayerTrackButton then
				visibleButtons[#visibleButtons + 1] = buttons[i]
			end
		else
			visibleButtons[#visibleButtons + 1] = buttons[i]
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
		                 (visibleButtons[i].command == 'pip_view' and state.losViewEnabled)

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

-- Helper function to draw water and LOS overlays
local function DrawWaterAndLOSOverlays()
	-- Draw water overlay using shader
	if mapInfo.hasWater and waterShader and not mapInfo.voidWater then
		gl.UseShader(waterShader)

		-- Set water color based on lava/water
		local r, g, b, a
		if mapInfo.isLava then
			r, g, b, a = 0.22, 0, 0, 1
		else
			r, g, b, a = 0.08, 0.11, 0.22, 0.5
		end
		gl.UniformFloat(gl.GetUniformLocation(waterShader, "waterColor"), r, g, b, a)

		-- Bind heightmap texture
		gl.UniformInt(gl.GetUniformLocation(waterShader, "heightTex"), 0)
		glFunc.Texture(0, '$heightmap')

		-- Draw water overlay
		glFunc.Color(1, 1, 1, 1)
		glFunc.BeginEnd(glConst.QUADS, GroundTextureVertices)

		glFunc.Texture(0, false)
		gl.UseShader(0)
	end

	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)  -- Restore default blending

	-- Draw LOS darkening overlay
	local shouldShowLOS, losAllyTeam = ShouldShowLOS()
	if config.showLosOverlay and shouldShowLOS and pipR2T.losTex then
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

		-- Draw LOS texture
		gl.Blending(GL.DST_COLOR, GL.ZERO)  -- result = dst * src
		glFunc.Color(1, 1, 1, 1)
		glFunc.Texture(pipR2T.losTex)

		-- Draw full-screen quad with map texture coordinates
		glFunc.BeginEnd(GL.QUADS, function()
			glFunc.TexCoord(render.ground.coord.l, render.ground.coord.b); glFunc.Vertex(render.ground.view.l, render.ground.view.b)
			glFunc.TexCoord(render.ground.coord.r, render.ground.coord.b); glFunc.Vertex(render.ground.view.r, render.ground.view.b)
			glFunc.TexCoord(render.ground.coord.r, render.ground.coord.t); glFunc.Vertex(render.ground.view.r, render.ground.view.t)
			glFunc.TexCoord(render.ground.coord.l, render.ground.coord.t); glFunc.Vertex(render.ground.view.l, render.ground.view.t)
		end)

		glFunc.Texture(false)
		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)  -- Restore default blending

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
	local lineSize = math.floor(4 * render.widgetScale)
	-- Scale baseSize based on zoom level (more zoomed out = slightly smaller markers)
	local zoomScale = 0.45 + (cameraState.zoom * 0.66)  -- Scale between 0.7 and 1.0
	local baseSize = 45 * render.widgetScale * zoomScale

	glFunc.Texture(false)

	-- Remove expired markers and draw active ones
	local i = 1
	while i <= #miscState.mapMarkers do
		local marker = miscState.mapMarkers[i]
		local age = currentTime - marker.time

		if age > 4.5 then
			table.remove(miscState.mapMarkers, i)
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

				-- Size of the rectangle (in screen pixels) with pulsating scale
				local pulseScale = 1 + math.sin(age * 4.5) * 0.2  -- Pulsate between 0.8 and 1.2
				local size = baseSize * pulseScale

				-- Fade out over the last second
				local alpha = age < 2.5 and 1 or (1 - (age - 2.5))

				-- Use team color or default
				local r, g, b = 1, 1, 0  -- Default yellow
				if marker.teamID then
					r, g, b = Spring.GetTeamColor(marker.teamID)
				end

				-- Draw rotating rectangle
				glFunc.PushMatrix()
				glFunc.Translate(sx, sy, 0)
				glFunc.Rotate(rotation, 0, 0, 1)

				-- background
				glFunc.Color(0, 0, 0, alpha * 0.5)
				glFunc.LineWidth(lineSize+2)
				gl.BeginEnd(GL.LINE_LOOP, function()
					glFunc.Vertex(-size, -size)
					glFunc.Vertex(size, -size)
					glFunc.Vertex(size, size)
					glFunc.Vertex(-size, size)
				end)
				-- colored
				local addition = 2 * (pulseScale-0.9)
				glFunc.Color(r*1.2 + addition, g*1.2 + addition, b*1.2 + addition, alpha)
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
		local distMult = math.min(math.max(1, 2.2-(cameraState.zoom*3.3)), 3)
		local iconRadiusZoom = config.iconRadius * cameraState.zoom
		local iconSize = iconRadiusZoom * distMult * iconData.size
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
		-- Draw ground minimap
		glFunc.Color(1, 1, 1, 1)
		glFunc.Texture('$minimap')
		glFunc.BeginEnd(glConst.QUADS, GroundTextureVertices)
		glFunc.Texture(false)

		-- Draw water and LOS overlays
		DrawWaterAndLOSOverlays()
	end

	-- Measure draw time for performance monitoring
	local drawStartTime = os.clock()
	DrawUnitsAndFeatures(cachedSelectedUnits)
	pipR2T.contentLastDrawTime = os.clock() - drawStartTime

	DrawCommandQueuesOverlay(cachedSelectedUnits)

	-- Draw map markers
	DrawMapMarkers()

	-- Pop rotation matrix if it was applied
	if render.minimapRotation ~= 0 then
		glFunc.PopMatrix()
	end
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

-- Draw map ruler at PIP edges to show scale
local function DrawMapRuler()
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
	if pipR2T.rulerNeedsUpdate then
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

				-- Calculate how many pixels each spacing level would take on screen
				local smallestScreenSpacing = pipWidth * (smallestSpacing / math.abs(horizWorldRange))
				local mediumScreenSpacing = pipWidth * (mediumSpacing / math.abs(horizWorldRange))
				local largestScreenSpacing = pipWidth * (largestSpacing / math.abs(horizWorldRange))

				-- Show different levels based on screen spacing
				local showSmallest = smallestScreenSpacing >= 8
				local showMedium = mediumScreenSpacing >= 8
				local showLargest = largestScreenSpacing >= 8

				glFunc.Texture(false)
				glFunc.Color(1, 1, 1, 0.18)

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
						if is16x and showLargest then
							markType = 3
						elseif is4x and showMedium then
							markType = 2
						elseif showSmallest then
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
						if is16x and showLargest then
							markType = 3
						elseif is4x and showMedium then
							markType = 2
						elseif showSmallest then
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

	-- Blit the cached ruler texture
	if pipR2T.rulerTex then
		gl.R2tHelper.BlendTexRect(pipR2T.rulerTex, render.dim.l, render.dim.b, render.dim.r, render.dim.t, true)
	end
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

		-- Calculate icon size (same as DrawIcons function)
		local distMult = math.min(math.max(1, 2.2-(cameraState.zoom*3.3)), 3)
		local iconRadiusZoom = config.iconRadius * cameraState.zoom
		local iconSize = iconRadiusZoom * distMult * iconData.size

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

-- Helper function to draw tracked player name
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

	-- Get team color
	local r, g, b = Spring.GetTeamColor(teamID)
	local fontSize = math.floor(20 * render.widgetScale)
	local padding = math.floor(17 * render.widgetScale)
	local centerX = (render.dim.l + render.dim.r) / 2

	font:Begin()
	font:SetTextColor(r, g, b, 1)
	font:SetOutlineColor(0, 0, 0, 0.8)
	font:Print(playerName, centerX, render.dim.t - padding - (fontSize * 1.6), fontSize * 2, "con")
	font:End()
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
				render.UiElement(padL, padB, padR, padT, 1, 1, 1, 1, nil, nil, nil, nil, nil, nil, nil, nil)
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
		render.UiElement(render.dim.l-render.elementPadding, render.dim.b-render.elementPadding, render.dim.r+render.elementPadding, render.dim.t+render.elementPadding, 1, 1, 1, 1, nil, nil, nil, nil, nil, nil, nil, nil)
	end
end

-- Helper function to calculate dynamic update rate
local function CalculateDynamicUpdateRate()
	local dynamicUpdateRate = config.pipMinUpdateRate
	if cameraState.zoom >= config.pipZoomThresholdMax then
		dynamicUpdateRate = config.pipMaxUpdateRate
	elseif cameraState.zoom > config.pipZoomThresholdMin then
		dynamicUpdateRate = config.pipMinUpdateRate + (config.pipMaxUpdateRate - config.pipMinUpdateRate) * ((cameraState.zoom - config.pipZoomThresholdMin) / (config.pipZoomThresholdMax - config.pipZoomThresholdMin))
	end

	if pipR2T.contentLastDrawTime > 0 then
		local targetPerformanceFactor = 1.0
		if pipR2T.contentLastDrawTime > config.pipTargetDrawTime then
			targetPerformanceFactor = math.max(0.5, config.pipTargetDrawTime / pipR2T.contentLastDrawTime)
		elseif pipR2T.contentLastDrawTime < config.pipTargetDrawTime * 0.7 then
			targetPerformanceFactor = math.min(1.0, pipR2T.contentPerformanceFactor * 1.02)
		end
		pipR2T.contentPerformanceFactor = pipR2T.contentPerformanceFactor + (targetPerformanceFactor - pipR2T.contentPerformanceFactor) * config.pipPerformanceAdjustSpeed
		dynamicUpdateRate = math.max(10, dynamicUpdateRate * pipR2T.contentPerformanceFactor)
	end

	pipR2T.contentCurrentUpdateRate = dynamicUpdateRate
	return dynamicUpdateRate
end

-- Helper function to update R2T content texture
local function UpdateR2TContent(currentTime, pipUpdateInterval, pipWidth, pipHeight)
	if not gl.R2tHelper then
		return
	end

	-- Check if size changed
	local contentSizeChanged = math.floor(pipWidth) ~= pipR2T.contentLastWidth or math.floor(pipHeight) ~= pipR2T.contentLastHeight

	-- Check if should update
	-- During resize, respect FPS throttling unless it's a forced update or unlimited FPS
	local timeSinceLastUpdate = currentTime - pipR2T.contentLastUpdateTime
	local shouldUpdate = pipR2T.contentNeedsUpdate or
		pipUpdateInterval == 0 or
		(pipUpdateInterval > 0 and timeSinceLastUpdate >= pipUpdateInterval)

	-- If size changed but we're throttled, defer the update
	if contentSizeChanged and not shouldUpdate then
		pipR2T.contentNeedsUpdate = true
	end

	if not shouldUpdate then
		return
	end

	-- Only delete old texture when we're about to create a new one
	if contentSizeChanged then
		if pipR2T.contentTex then
			gl.DeleteTexture(pipR2T.contentTex)
			pipR2T.contentTex = nil
		end
		pipR2T.contentLastWidth = math.floor(pipWidth)
		pipR2T.contentLastHeight = math.floor(pipHeight)
	end

	-- Create texture if needed
	if not pipR2T.contentTex and pipWidth >= 1 and pipHeight >= 1 then
		pipR2T.contentTex = gl.CreateTexture(math.floor(pipWidth), math.floor(pipHeight), {
			target = GL.TEXTURE_2D, format = GL.RGBA, fbo = true,
		})
		pipR2T.contentLastWidth = math.floor(pipWidth)
		pipR2T.contentLastHeight = math.floor(pipHeight)
	end

	if pipR2T.contentTex then
		-- Get and store minimap rotation for coordinate transformations
		render.minimapRotation = Spring.GetMiniMapRotation and Spring.GetMiniMapRotation() or 0

		gl.R2tHelper.RenderToTexture(pipR2T.contentTex, function()
			glFunc.Translate(-1, -1, 0)
			glFunc.Scale(2 / pipWidth, 2 / pipHeight, 0)

			-- Reuse saved dimension tables
			pools.savedDim.l, pools.savedDim.r, pools.savedDim.b, pools.savedDim.t = render.dim.l, render.dim.r, render.dim.b, render.dim.t
			pools.savedGround.view.l, pools.savedGround.view.r, pools.savedGround.view.b, pools.savedGround.view.t = render.ground.view.l, render.ground.view.r, render.ground.view.b, render.ground.view.t
			pools.savedGround.coord.l, pools.savedGround.coord.r, pools.savedGround.coord.b, pools.savedGround.coord.t = render.ground.coord.l, render.ground.coord.r, render.ground.coord.b, render.ground.coord.t

			render.dim.l, render.dim.b, render.dim.r, render.dim.t = 0, 0, pipWidth, pipHeight
			RecalculateWorldCoordinates()
			RecalculateGroundTextureCoordinates()
			RenderPipContents()

			render.dim.l, render.dim.r, render.dim.b, render.dim.t = pools.savedDim.l, pools.savedDim.r, pools.savedDim.b, pools.savedDim.t
			RecalculateWorldCoordinates()
			render.ground.view.l, render.ground.view.r, render.ground.view.b, render.ground.view.t = pools.savedGround.view.l, pools.savedGround.view.r, pools.savedGround.view.b, pools.savedGround.view.t
			render.ground.coord.l, render.ground.coord.r, render.ground.coord.b, render.ground.coord.t = pools.savedGround.coord.l, pools.savedGround.coord.r, pools.savedGround.coord.b, pools.savedGround.coord.t
		end, true)
		pipR2T.contentLastUpdateTime = currentTime
		pipR2T.contentNeedsUpdate = false
	end
end

-- Update LOS texture with current Line-of-Sight information
local function UpdateLOSTexture(currentTime)
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
			if not losShader then
				return
			end
				glFunc.Texture(0, '$info:los')
				glFunc.Texture(1, '$info:radar')

				-- Activate shader to convert red channel to greyscale
				gl.UseShader(losShader)

				-- Update shader uniforms (in case config changed)
				gl.UniformFloat(gl.GetUniformLocation(losShader, "showRadar"), config.showLosRadar and 1.0 or 0.0)

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
				-- Clear to darkest level (neither LOS nor radar)
				local baseBrightness = 1.0 - config.losOverlayOpacity
				local darkestBrightness = baseBrightness * 0.5  -- Same as shader: grey * 0.5
				local showRadar = config.showLosRadar

				if showRadar then
					-- Start with darkest (no LOS, no radar)
					gl.Clear(GL.COLOR_BUFFER_BIT, darkestBrightness, darkestBrightness, darkestBrightness, 1)
				else
					-- No radar display, start with base darkness
					gl.Clear(GL.COLOR_BUFFER_BIT, baseBrightness, baseBrightness, baseBrightness, 1)
				end

				local cellSizeX = mapInfo.mapSizeX / losTexWidth
				local cellSizeZ = mapInfo.mapSizeZ / losTexHeight

				-- First pass: draw radar areas (medium brightness) if showRadar enabled
				if showRadar then
					glFunc.Color(baseBrightness, baseBrightness, baseBrightness, 1)
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

				-- Second pass: draw LOS areas (brightest)
				glFunc.Color(1, 1, 1, 1)
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
local lastHoverCursorCheckTime = 0
local lastHoveredUnitID = nil
local lastHoveredFeatureID = nil
local function HandleHoverAndCursor(mx, my)
	if interactionState.arePanning then
		return
	end

	if not (interactionState.areBoxSelecting or (mx >= render.dim.l and mx <= render.dim.r and my >= render.dim.b and my <= render.dim.t)) then
		if WG['info'] and WG['info'].clearCustomHover then
			WG['info'].clearCustomHover()
		end
		lastHoveredUnitID = nil
		lastHoveredFeatureID = nil
		return
	end

	-- Throttle expensive GetUnitAtPoint calls for performance (but not during active zoom)
	local currentTime = os.clock()
	local shouldCheckUnit = (currentTime - lastHoverCursorCheckTime) >= 0.1
	local isZooming = interactionState.areIncreasingZoom or interactionState.areDecreasingZoom

	if shouldCheckUnit and not isZooming then
		lastHoverCursorCheckTime = currentTime

		-- Update info widget with custom hover
		if WG['info'] and WG['info'].setCustomHover then
			local wx, wz = PipToWorldCoords(mx, my)
			local uID = GetUnitAtPoint(wx, wz)
			if uID then
				WG['info'].setCustomHover('unit', uID)
				lastHoveredUnitID = uID
				lastHoveredFeatureID = nil
			else
				-- Only check features if zoom level is high enough to render them
				if cameraState.zoom >= config.zoomFeatures then
					local fID = GetFeatureAtPoint(wx, wz)
					if fID then
						WG['info'].setCustomHover('feature', fID)
						lastHoveredFeatureID = fID
						lastHoveredUnitID = nil
					else
						WG['info'].clearCustomHover()
						lastHoveredUnitID = nil
						lastHoveredFeatureID = nil
					end
				else
					WG['info'].clearCustomHover()
					lastHoveredUnitID = nil
					lastHoveredFeatureID = nil
				end
			end
		end
	end

	-- Handle cursor - this runs every frame for smooth cursor updates
	-- Don't change cursor for spectators (unless config allows it)
	local isSpec = Spring.GetSpectatingState()
	local canGiveCommands = not isSpec or config.allowCommandsWhenSpectating
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
	if pipNumber ~= 1 and interactionState.isMouseOverPip then
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
		if buttons[i].command == 'pip_track' then
			if #selectedUnits > 0 or interactionState.areTracking then
				visibleButtons[#visibleButtons + 1] = buttons[i]
			end
		elseif buttons[i].command == 'pip_trackplayer' then
			local _, _, spec = spFunc.GetPlayerInfo(Spring.GetMyPlayerID(), false)
			local aliveTeammates = GetAliveTeammates()
			if interactionState.trackingPlayerID or spec or (#aliveTeammates > 0) then
				visibleButtons[#visibleButtons + 1] = buttons[i]
			end
		elseif buttons[i].command == 'pip_view' then
			local _, _, spec = spFunc.GetPlayerInfo(Spring.GetMyPlayerID(), false)
			if spec then
				visibleButtons[#visibleButtons + 1] = buttons[i]
			end
		else
			visibleButtons[#visibleButtons + 1] = buttons[i]
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
				   (visibleButtons[i].command == 'pip_view' and state.losViewEnabled) then
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
				if visibleButtons[i].tooltip and WG['tooltip'] then
					local tooltipText = visibleButtons[i].tooltip
					if visibleButtons[i].tooltipActive then
						if (visibleButtons[i].command == 'pip_track' and interactionState.areTracking) or
						   (visibleButtons[i].command == 'pip_trackplayer' and interactionState.trackingPlayerID) or
						   (visibleButtons[i].command == 'pip_view' and state.losViewEnabled) then
							tooltipText = visibleButtons[i].tooltipActive
						end
					end
					WG['tooltip'].ShowTooltip('pip'..pipNumber, tooltipText, nil, nil, nil)
				end
				glFunc.Color(1,1,1,0.12)
				glFunc.Texture(false)
				render.RectRound(bx, render.dim.b, bx + render.usedButtonSize, render.dim.b + render.usedButtonSize, render.elementCorner*0.4, 1, 1, 1, 1)
				if (visibleButtons[i].command == 'pip_track' and interactionState.areTracking) or
				   (visibleButtons[i].command == 'pip_trackplayer' and interactionState.trackingPlayerID) or
				   (visibleButtons[i].command == 'pip_view' and state.losViewEnabled) then
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

	if uiState.inMinMode and not uiState.isAnimating then
		-- Use display list for minimized mode (static graphics with relative coordinates)
		local buttonSize = math.floor(render.usedButtonSize*config.maximizeSizemult)

		-- Draw render.UiElement background FIRST (with proper screen coordinates)
		--render.UiElement(uiState.minModeL-render.elementPadding, uiState.minModeB-render.elementPadding, uiState.minModeL+buttonSize+render.elementPadding, uiState.minModeB+buttonSize+render.elementPadding, 1, 1, 1, 1, nil, nil, nil, nil, nil, nil, nil, nil)

		-- Then draw icon on top using display list
		local offset = render.elementPadding + 2	-- to prevent touching screen edges and FlowUI Element will remove borders

		-- Check if we need to recreate display list due to position change (affects rotation)
		local sw, sh = Spring.GetWindowGeometry()
		local currentQuadrant = (uiState.minModeL < sw * 0.5 and 1 or 2) + (uiState.minModeB < sh * 0.25 and 0 or 2)
		if render.minModeQuadrant ~= currentQuadrant and render.minModeDlist then
			gl.DeleteList(render.minModeDlist)
			render.minModeDlist = nil
		end
		render.minModeQuadrant = currentQuadrant

		if not render.minModeDlist then
			render.minModeDlist = gl.CreateList(function()
				-- Draw render.UiElement background (only borders, no fill to avoid double opacity)
				render.UiElement(offset-render.elementPadding, offset-render.elementPadding, offset+buttonSize+render.elementPadding, offset+buttonSize+render.elementPadding, 1, 1, 1, 1, nil, nil, nil, nil, nil, nil, nil, nil)

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

		-- Measure time to render
		local drawStartTime = os.clock()
		UpdateR2TContent(currentTime, pipUpdateInterval, pipWidth, pipHeight)
		pipR2T.contentLastDrawTime = os.clock() - drawStartTime

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
				render.RectRound(render.dim.l, render.dim.b, render.dim.r, render.dim.t, render.elementCorner * 0.5, 1, 1, 1, 1)
			end)
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

			gl.R2tHelper.BlendTexRect(pipR2T.contentTex, render.dim.l, render.dim.b, render.dim.r, render.dim.t, true)

			-- Disable stencil test
			gl.StencilTest(false)
		end

		-- Draw map ruler at edges (only when not spectating)
		if config.showMapRuler then
			local _, _, spec = spFunc.GetPlayerInfo(Spring.GetMyPlayerID(), false)
			if not spec then
				DrawMapRuler()
			end
		end
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

		-- Draw resize handle when showing on hover
		if config.showButtonsOnHoverOnly and interactionState.isMouseOverPip then
			glFunc.Color(config.panelBorderColorDark)
			glFunc.LineWidth(1.0)
			glFunc.BeginEnd(glConst.TRIANGLES, ResizeHandleVertices)
		end

		-- Draw dynamic hover overlays
		-- Resize handle hover
		local hover = uiState.areResizing or false
		if mx >= render.dim.l and mx <= render.dim.r and my >= render.dim.b and my <= render.dim.t then
			if (render.dim.r-mx + my-render.dim.b <= render.usedButtonSize) then
				hover = true
				if WG['tooltip'] then
					WG['tooltip'].ShowTooltip('pip'..pipNumber, 'Resize', nil, nil, nil)
				end
			end
		end
		if hover then
			local mult = mbl and 4.5 or 1.5
			glFunc.Color(config.panelBorderColorDark[1]*mult, config.panelBorderColorDark[2]*mult, config.panelBorderColorDark[3]*mult, 1)
			glFunc.LineWidth(1.0)
			glFunc.BeginEnd(glConst.TRIANGLES, ResizeHandleVertices)
		end

		-- Minimize button hover
		hover = false
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
				WG['tooltip'].ShowTooltip('pip'..pipNumber, 'Minimize', nil, nil, nil)
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

		-- Bottom-left buttons hover and pip number
		DrawInteractiveOverlays(mx, my, render.usedButtonSize)
	end

	-- Display tracked player name at top-center of PIP (only when hovering)
	DrawTrackedPlayerName()

	-- Display current max update rate (top-left corner)
	if showPipFps then
		local fontSize = 11
		local padding = 8
		font:Begin()
		font:SetTextColor(0.85, 0.85, 0.85, 1)
		font:SetOutlineColor(0, 0, 0, 0.5)
		font:Print(string.format("%.0f FPS", pipR2T.contentCurrentUpdateRate), render.dim.l + padding, render.dim.t - (fontSize*1.6) - padding, fontSize*2, "no")
		font:End()
	end

	-- Draw box selection rectangle
	DrawBoxSelection()

	-- Draw area command circle
	DrawAreaCommand()

	-- Draw build cursor with rotation applied
	DrawBuildCursorWithRotation()

	-- Draw formation dots overlay (command queues are now in R2T)
	DrawFormationDotsOverlay()

	glFunc.Color(1, 1, 1, 1)
end

function widget:DrawWorld()
	-- When fully minimized (not animating), draw maximize icon at PIP camera location
	-- Don't show if tracking player camera, or if spectator (unless showWorldIconForSpectators is enabled)
	local shouldShowWorldIcon = config.showWorldIcon and not interactionState.trackingPlayerID and
		(not cameraState.mySpecState or config.showWorldIconForSpectators)
	if uiState.inMinMode and not uiState.isAnimating and shouldShowWorldIcon then
		local alt = Spring.GetModKeyState()
		local iconSize = 16  -- World units
		-- Use locked position if hovering, otherwise current camera center
		local iconX = miscState.worldIconLockedX or cameraState.wcx
		local iconZ = miscState.worldIconLockedZ or cameraState.wcz
		local iconY = math.max(spFunc.GetGroundHeight(iconX, iconZ), 0) + 2  -- Above water level

		-- Calculate distance-based opacity (fade in when cursor approaches)
		-- Use 18% of vertical screen height as the fade distance
		local fadeDistance = render.vsy * 0.18
		local distanceOpacityMult = 1.0
		local mx, my = spFunc.GetMouseState()
		local iconScreenX, iconScreenY = Spring.WorldToScreenCoords(iconX, iconY, iconZ)
		if iconScreenX and iconScreenY then
			local screenDist = math.sqrt((mx - iconScreenX)^2 + (my - iconScreenY)^2)
			if screenDist >= fadeDistance then
				distanceOpacityMult = 0
			else
				distanceOpacityMult = 1 - (screenDist / fadeDistance)
			end
		end

		-- Skip drawing entirely if too far away
		if distanceOpacityMult <= 0 then
			return
		end

		-- Draw octagon border around icon (same style as PIP boundary but more distant)
		local innerLineDist = 8
		local cornerSize = 11 * 0.6  -- 60% of normal corner size
		local lineWidthMult = 0.66 + (render.vsy / 4000)
		local borderDist = iconSize + 16  -- More distance from icon

		-- Use team color if we were tracking a player, otherwise white
		local r, g, b = 1, 1, 1
		if interactionState.trackingPlayerID then
			local _, _, _, teamID = spFunc.GetPlayerInfo(interactionState.trackingPlayerID, false)
			if teamID then
				r, g, b = Spring.GetTeamColor(teamID)
			end
		end

		gl.DepthTest(false)

		-- Draw border octagons (same opacity as non-minimized PIP boundary, scaled by distance)
		glFunc.LineWidth(7*lineWidthMult)
		glFunc.Color(0, 0, 0, 0.05 * distanceOpacityMult)
		glFunc.BeginEnd(glConst.LINE_STRIP, DrawGroundBox, iconX - borderDist, iconX + borderDist, iconZ - borderDist, iconZ + borderDist, cornerSize)
		glFunc.Color(0, 0, 0, 0.015 * distanceOpacityMult)
		glFunc.BeginEnd(glConst.LINE_STRIP, DrawGroundBox, iconX - borderDist + innerLineDist, iconX + borderDist - innerLineDist, iconZ - borderDist + innerLineDist, iconZ + borderDist - innerLineDist, cornerSize*0.65)
		glFunc.LineWidth(2.5*lineWidthMult)
		glFunc.Color(r, g, b, 0.25 * distanceOpacityMult)
		glFunc.BeginEnd(glConst.LINE_STRIP, DrawGroundBox, iconX - borderDist, iconX + borderDist, iconZ - borderDist, iconZ + borderDist, cornerSize)
		glFunc.Color(r, g, b, 0.045 * distanceOpacityMult)
		glFunc.BeginEnd(glConst.LINE_STRIP, DrawGroundBox, iconX - borderDist + innerLineDist, iconX + borderDist - innerLineDist, iconZ - borderDist + innerLineDist, iconZ + borderDist - innerLineDist, cornerSize*0.65)

		-- Draw maximize icon (flat on ground, facing up)
		local iconOpacity = 0.2
		if interactionState.worldMaximizeIconHovered then
			iconOpacity = alt and 0.95 or 0.35
		end
		iconOpacity = iconOpacity * distanceOpacityMult

		glFunc.Color(1, 1, 1, iconOpacity)
		glFunc.Texture('LuaUI/Images/pip/PipMaximize.png')
		glFunc.BeginEnd(GL.QUADS, function()
			glFunc.TexCoord(0, 0)
			glFunc.Vertex(iconX - iconSize, iconY, iconZ + iconSize)
			glFunc.TexCoord(1, 0)
			glFunc.Vertex(iconX + iconSize, iconY, iconZ + iconSize)
			glFunc.TexCoord(1, 1)
			glFunc.Vertex(iconX + iconSize, iconY, iconZ - iconSize)
			glFunc.TexCoord(0, 1)
			glFunc.Vertex(iconX - iconSize, iconY, iconZ - iconSize)
		end)
		glFunc.Texture(false)
		glFunc.Color(1, 1, 1, 1)

		-- Show tooltip when hovered for at least 1 second (max 5 times per game, 20 times total ever)
		local currentTime = os.clock()
		if interactionState.worldMaximizeIconHovered and WG['tooltip'] and
		   miscState.worldIconTooltipShownThisGame < 5 and miscState.worldIconTooltipShownTotal < 20 then
			-- Only show tooltip after hovering for 1 second
			if currentTime - interactionState.worldIconHoverStartTime >= 1.0 then
				WG['tooltip'].ShowTooltip('pip_world_icon', Spring.I18N('ui.pip.worldmaximize'), nil, nil, nil)
				-- Start tracking display time if not already
				if interactionState.worldIconTooltipDisplayStartTime == 0 then
					interactionState.worldIconTooltipDisplayStartTime = currentTime
				end
				-- Only count as shown after displaying for 1 second
				if not interactionState.worldIconTooltipShownThisHover and
				   currentTime - interactionState.worldIconTooltipDisplayStartTime >= 1.0 then
					interactionState.worldIconTooltipShownThisHover = true
					miscState.worldIconTooltipShownThisGame = miscState.worldIconTooltipShownThisGame + 1
					miscState.worldIconTooltipShownTotal = miscState.worldIconTooltipShownTotal + 1
				end
			end
		end
		return
	end

	-- During animation or when not minimized, draw the PIP boundary
	if uiState.inMinMode and not uiState.isAnimating then return end  -- Skip if fully minimized (handled above), but continue during animation

	-- Draw rectangle outline in world view marking PIP boundaries
	-- Don't show if tracking player camera, or if spectator (unless showWorldIconForSpectators is enabled)
	if not interactionState.trackingPlayerID and (not cameraState.mySpecState or config.showWorldIconForSpectators) then
		-- Use team color if tracking a player, otherwise white
		local r, g, b = 1, 1, 1
		if interactionState.trackingPlayerID then
			local _, _, _, teamID = spFunc.GetPlayerInfo(interactionState.trackingPlayerID, false)
			if teamID then
				r, g, b = Spring.GetTeamColor(teamID)
			end
		end

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

		-- Draw minimize icon at center of PIP boundary (if enabled and not tracking player)
		if config.showWorldIcon and not interactionState.trackingPlayerID then
			local alt = Spring.GetModKeyState()
			local iconSize = 16  -- World units
			-- Use locked position if hovering, otherwise current camera center
			local iconX = miscState.worldIconLockedX or cameraState.wcx
			local iconZ = miscState.worldIconLockedZ or cameraState.wcz
			local iconY = math.max(spFunc.GetGroundHeight(iconX, iconZ), 0) + 2  -- Above water level

			-- Calculate distance-based opacity (fade in when cursor approaches)
			-- Use 18% of vertical screen height as the fade distance
			local fadeDistance = render.vsy * 0.22
			local distanceOpacityMult = 1.0
			local mx, my = spFunc.GetMouseState()
			local iconScreenX, iconScreenY = Spring.WorldToScreenCoords(iconX, iconY, iconZ)
			if iconScreenX and iconScreenY then
				local screenDist = math.sqrt((mx - iconScreenX)^2 + (my - iconScreenY)^2)
				if screenDist >= fadeDistance then
					distanceOpacityMult = 0
				else
					distanceOpacityMult = 1 - (screenDist / fadeDistance)
				end
			end

			-- Only draw if close enough
			if distanceOpacityMult > 0 then
				local iconOpacity = 0.1
				if interactionState.worldMinimizeIconHovered then
					iconOpacity = alt and 0.95 or 0.25
				end
				iconOpacity = iconOpacity * distanceOpacityMult

				glFunc.Color(1, 1, 1, iconOpacity)
				glFunc.Texture('LuaUI/Images/pip/PipMinimize.png')
				glFunc.BeginEnd(GL.QUADS, function()
					glFunc.TexCoord(0, 0)
					glFunc.Vertex(iconX - iconSize, iconY, iconZ + iconSize)
					glFunc.TexCoord(1, 0)
					glFunc.Vertex(iconX + iconSize, iconY, iconZ + iconSize)
					glFunc.TexCoord(1, 1)
					glFunc.Vertex(iconX + iconSize, iconY, iconZ - iconSize)
					glFunc.TexCoord(0, 1)
					glFunc.Vertex(iconX - iconSize, iconY, iconZ - iconSize)
				end)
				glFunc.Texture(false)

				-- Show tooltip when hovered for at least 1 second (max 5 times per game, 20 times total ever)
				local currentTime = os.clock()
				if interactionState.worldMinimizeIconHovered and WG['tooltip'] and
				   miscState.worldIconTooltipShownThisGame < 5 and miscState.worldIconTooltipShownTotal < 20 then
					-- Only show tooltip after hovering for 1 second
					if currentTime - interactionState.worldIconHoverStartTime >= 1.0 then
						WG['tooltip'].ShowTooltip('pip_world_icon', Spring.I18N('ui.pip.worldminimize'), nil, nil, nil)
						-- Start tracking display time if not already
						if interactionState.worldIconTooltipDisplayStartTime == 0 then
							interactionState.worldIconTooltipDisplayStartTime = currentTime
						end
						-- Only count as shown after displaying for 1 second
						if not interactionState.worldIconTooltipShownThisHover and
						   currentTime - interactionState.worldIconTooltipDisplayStartTime >= 1.0 then
							interactionState.worldIconTooltipShownThisHover = true
							miscState.worldIconTooltipShownThisGame = miscState.worldIconTooltipShownThisGame + 1
							miscState.worldIconTooltipShownTotal = miscState.worldIconTooltipShownTotal + 1
						end
					end
				end
			end  -- end distanceOpacityMult > 0
		end  -- end config.showWorldIcon
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
	if uiState.inMinMode then return end

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
	local linewidth = math.ceil(render.vsy / 2000)
	glFunc.Texture(false)
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	glFunc.PushMatrix()

	-- Translate to center and rotate
	glFunc.Translate(centerX, centerY, 0)
	if render.minimapRotation and render.minimapRotation ~= 0 then
		glFunc.Rotate(render.minimapRotation * 180 / math.pi, 0, 0, 1)
	end

	-- Draw dark background rectangle (centered at origin after transform)
	-- Use octagon with corners cut off by 16 world units (converted to minimap units)
	local cornerWorldSize = 64
	local cornerX = (cornerWorldSize / mapInfo.mapSizeX) * minimapWidth
	local cornerY = (cornerWorldSize / mapInfo.mapSizeZ) * minimapHeight
	-- Clamp corner size if rectangle is too small
	local maxCorner = math.min(halfWidth, halfHeight) / 2
	local cx = math.min(cornerX, maxCorner)
	local cy = math.min(cornerY, maxCorner)

	-- draw dark outline
	glFunc.Color(0, 0, 0, 0.6)
	glFunc.LineWidth((linewidth*1.5)+1)
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
	glFunc.Color(r, g, b, 1)
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

function widget:Update(dt)
	-- Update spectating state and check if it changed
	local oldSpecState = cameraState.mySpecState
	cameraState.mySpecState = Spring.GetSpectatingState()

	-- If spec state changed, update LOS texture
	if oldSpecState ~= cameraState.mySpecState then
		pipR2T.losNeedsUpdate = true
	end

	-- Update mouse hover state
	local mx, my = spFunc.GetMouseState()
	local wasMouseOver = interactionState.isMouseOverPip
	interactionState.isMouseOverPip = (mx >= render.dim.l and mx <= render.dim.r and my >= render.dim.b and my <= render.dim.t and not uiState.inMinMode)

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

	-- Update world icon hover states (for minimize/maximize icons in world view)
	-- Check if mouse is over the world icons using TraceScreenRay
	-- Don't show/check world icon when tracking player camera
	local wasMinimizeHovered = interactionState.worldMinimizeIconHovered
	local wasMaximizeHovered = interactionState.worldMaximizeIconHovered
	interactionState.worldMinimizeIconHovered = false
	interactionState.worldMaximizeIconHovered = false

	local alt = Spring.GetModKeyState()
	-- Also check for spectator (unless showWorldIconForSpectators is enabled)
	local shouldCheckWorldIcon = config.showWorldIcon and not uiState.isAnimating and
		not interactionState.isMouseOverPip and not interactionState.trackingPlayerID and
		(not cameraState.mySpecState or config.showWorldIconForSpectators)
	if shouldCheckWorldIcon then
		local _, pos = Spring.TraceScreenRay(mx, my, true)
		if pos then
			local worldX, worldZ = pos[1], pos[3]
			local iconSize = 16  -- Must match DrawWorld icon size
			local iconClickRadius = iconSize + 8  -- Slightly larger for easier clicking

			if uiState.inMinMode then
				-- Check maximize icon - use locked position if already hovering
				local iconX = miscState.worldIconLockedX or cameraState.wcx
				local iconZ = miscState.worldIconLockedZ or cameraState.wcz
				local dx = math.abs(worldX - iconX)
				local dz = math.abs(worldZ - iconZ)
				if dx < iconClickRadius and dz < iconClickRadius then
					interactionState.worldMaximizeIconHovered = true
				end
			else
				-- Check minimize icon - use locked position if already hovering
				local iconX = miscState.worldIconLockedX or cameraState.wcx
				local iconZ = miscState.worldIconLockedZ or cameraState.wcz
				local dx = math.abs(worldX - iconX)
				local dz = math.abs(worldZ - iconZ)
				if dx < iconClickRadius and dz < iconClickRadius then
					interactionState.worldMinimizeIconHovered = true
				end
			end
		end
	end

	-- Track hover start time for tooltip delay and lock icon position
	local isNowHovered = interactionState.worldMinimizeIconHovered or interactionState.worldMaximizeIconHovered
	local wasHovered = wasMinimizeHovered or wasMaximizeHovered

	-- Start tracking hover time when we start hovering, and lock icon position
	if isNowHovered and not wasHovered then
		interactionState.worldIconHoverStartTime = os.clock()
		-- Lock the icon position so it doesn't move while hovering
		miscState.worldIconLockedX = cameraState.wcx
		miscState.worldIconLockedZ = cameraState.wcz
	end

	-- Reset all tooltip state and unlock position when we stop hovering either icon
	-- But don't clear if we're in the middle of a drag operation
	local isWorldIconDragging = interactionState.worldIconClickStartX ~= 0 or interactionState.worldIconDragging
	if not isWorldIconDragging and
	   ((wasMinimizeHovered and not interactionState.worldMinimizeIconHovered) or
	    (wasMaximizeHovered and not interactionState.worldMaximizeIconHovered)) then
		interactionState.worldIconTooltipShownThisHover = false
		interactionState.worldIconHoverStartTime = 0
		interactionState.worldIconTooltipDisplayStartTime = 0
		-- Unlock icon position when no longer hovering
		miscState.worldIconLockedX = nil
		miscState.worldIconLockedZ = nil
	end

	-- Update game time (only when game is not paused)
	local _, _, isPaused = Spring.GetGameSpeed()
	if not isPaused then
		gameTime = gameTime + dt
	end

	-- Handle minimize/maximize animation
	if uiState.isAnimating then
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

	-- Smooth zoom and camera center interpolation
	local zoomNeedsUpdate = math.abs(cameraState.zoom - cameraState.targetZoom) > 0.001
	local centerNeedsUpdate = math.abs(cameraState.wcx - cameraState.targetWcx) > 0.1 or math.abs(cameraState.wcz - cameraState.targetWcz) > 0.1

	-- Don't force immediate updates during zoom/pan - let dynamic update rate handle it for better performance
	-- Only mark for update on significant changes (tracked player switching, etc.)
	-- if zoomNeedsUpdate or centerNeedsUpdate then
	-- 	pipR2T.contentNeedsUpdate = true
	-- end

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
		local pipWidth = render.dim.r - render.dim.l
		local pipHeight = render.dim.t - render.dim.b
		local visibleWorldWidth = pipWidth / cameraState.targetZoom
		local visibleWorldHeight = pipHeight / cameraState.targetZoom

		-- Use the smaller dimension for consistent visual margin
		local smallerVisibleDimension = math.min(visibleWorldWidth, visibleWorldHeight)
		local margin = smallerVisibleDimension * config.mapEdgeMargin

		-- Calculate min/max camera positions to keep margin from map edges
		local minWcx = visibleWorldWidth / 2 - margin
		local maxWcx = mapInfo.mapSizeX - (visibleWorldWidth / 2 - margin)
		local minWcz = visibleWorldHeight / 2 - margin
		local maxWcz = mapInfo.mapSizeZ - (visibleWorldHeight / 2 - margin)

		-- Clamp with margin-based boundaries
		cameraState.targetWcx = math.min(math.max(cameraState.targetWcx, minWcx), maxWcx)
		cameraState.targetWcz = math.min(math.max(cameraState.targetWcz, minWcz), maxWcz)

		centerNeedsUpdate = true  -- Force center update
	end

	if zoomNeedsUpdate or centerNeedsUpdate then
		if zoomNeedsUpdate then
			cameraState.zoom = cameraState.zoom + (cameraState.targetZoom - cameraState.zoom) * math.min(dt * config.zoomSmoothness, 1)
		end

		-- Calculate bounds for CURRENT zoom level
		local pipWidth = render.dim.r - render.dim.l
		local pipHeight = render.dim.t - render.dim.b
		local currentVisibleWorldWidth = pipWidth / cameraState.zoom
		local currentVisibleWorldHeight = pipHeight / cameraState.zoom
		local currentSmallerDimension = math.min(currentVisibleWorldWidth, currentVisibleWorldHeight)
		local currentMargin = currentSmallerDimension * config.mapEdgeMargin

		local currentMinWcx = currentVisibleWorldWidth / 2 - currentMargin
		local currentMaxWcx = mapInfo.mapSizeX - (currentVisibleWorldWidth / 2 - currentMargin)
		local currentMinWcz = currentVisibleWorldHeight / 2 - currentMargin
		local currentMaxWcz = mapInfo.mapSizeZ - (currentVisibleWorldHeight / 2 - currentMargin)

		-- Also calculate bounds for TARGET zoom level to detect if we WILL hit an edge
		local targetVisibleWorldWidth = pipWidth / cameraState.targetZoom
		local targetVisibleWorldHeight = pipHeight / cameraState.targetZoom
		local targetSmallerDimension = math.min(targetVisibleWorldWidth, targetVisibleWorldHeight)
		local targetMargin = targetSmallerDimension * config.mapEdgeMargin

		local targetMinWcx = targetVisibleWorldWidth / 2 - targetMargin
		local targetMaxWcx = mapInfo.mapSizeX - (targetVisibleWorldWidth / 2 - targetMargin)
		local targetMinWcz = targetVisibleWorldHeight / 2 - targetMargin
		local targetMaxWcz = mapInfo.mapSizeZ - (targetVisibleWorldHeight / 2 - targetMargin)

		-- Detect if at edge: either currently at edge, OR would be pushed by target zoom bounds
		-- This handles both zooming from outside map AND zooming near edges inside map
		local atLeftEdge = cameraState.wcx <= currentMinWcx + 1 or cameraState.wcx <= targetMinWcx + 1
		local atRightEdge = cameraState.wcx >= currentMaxWcx - 1 or cameraState.wcx >= targetMaxWcx - 1
		local atTopEdge = cameraState.wcz <= currentMinWcz + 1 or cameraState.wcz <= targetMinWcz + 1
		local atBottomEdge = cameraState.wcz >= currentMaxWcz - 1 or cameraState.wcz >= targetMaxWcz - 1

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

		RecalculateWorldCoordinates()
		RecalculateGroundTextureCoordinates()
	else
		-- Zoom and center have reached their targets, disable zoom-to-cursor and switch transition
		cameraState.zoomToCursorActive = false
		miscState.isSwitchingViews = false
	end

	if interactionState.areIncreasingZoom then
		cameraState.targetZoom = math.min(cameraState.targetZoom * config.zoomRate ^ dt, config.zoomMax)

		-- Clamp BOTH current and target camera positions to respect margin
		-- Use current zoom for current position, target zoom for target position
		local pipWidth = render.dim.r - render.dim.l
		local pipHeight = render.dim.t - render.dim.b

		-- Clamp current animated position
		local currentVisibleWorldWidth = pipWidth / cameraState.zoom
		local currentVisibleWorldHeight = pipHeight / cameraState.zoom
		local currentSmallerDimension = math.min(currentVisibleWorldWidth, currentVisibleWorldHeight)
		local currentMargin = currentSmallerDimension * config.mapEdgeMargin

		local currentMinWcx = currentVisibleWorldWidth / 2 - currentMargin
		local currentMaxWcx = mapInfo.mapSizeX - (currentVisibleWorldWidth / 2 - currentMargin)
		local currentMinWcz = currentVisibleWorldHeight / 2 - currentMargin
		local currentMaxWcz = mapInfo.mapSizeZ - (currentVisibleWorldHeight / 2 - currentMargin)

		cameraState.wcx = math.min(math.max(cameraState.wcx, currentMinWcx), currentMaxWcx)
		cameraState.wcz = math.min(math.max(cameraState.wcz, currentMinWcz), currentMaxWcz)

		-- Clamp target position
		local targetVisibleWorldWidth = pipWidth / cameraState.targetZoom
		local targetVisibleWorldHeight = pipHeight / cameraState.targetZoom
		local targetSmallerDimension = math.min(targetVisibleWorldWidth, targetVisibleWorldHeight)
		local targetMargin = targetSmallerDimension * config.mapEdgeMargin

		local targetMinWcx = targetVisibleWorldWidth / 2 - targetMargin
		local targetMaxWcx = mapInfo.mapSizeX - (targetVisibleWorldWidth / 2 - targetMargin)
		local targetMinWcz = targetVisibleWorldHeight / 2 - targetMargin
		local targetMaxWcz = mapInfo.mapSizeZ - (targetVisibleWorldHeight / 2 - targetMargin)

		cameraState.targetWcx = math.min(math.max(cameraState.targetWcx, targetMinWcx), targetMaxWcx)
		cameraState.targetWcz = math.min(math.max(cameraState.targetWcz, targetMinWcz), targetMaxWcz)

		-- Don't recalculate here - will be done below in the main zoom/center update block
	elseif interactionState.areDecreasingZoom then
		cameraState.targetZoom = math.max(cameraState.targetZoom / config.zoomRate ^ dt, config.zoomMin)

		-- Clamp BOTH current and target camera positions to respect margin
		-- Use current zoom for current position, target zoom for target position
		local pipWidth = render.dim.r - render.dim.l
		local pipHeight = render.dim.t - render.dim.b

		-- Clamp current animated position
		local currentVisibleWorldWidth = pipWidth / cameraState.zoom
		local currentVisibleWorldHeight = pipHeight / cameraState.zoom
		local currentSmallerDimension = math.min(currentVisibleWorldWidth, currentVisibleWorldHeight)
		local currentMargin = currentSmallerDimension * config.mapEdgeMargin

		local currentMinWcx = currentVisibleWorldWidth / 2 - currentMargin
		local currentMaxWcx = mapInfo.mapSizeX - (currentVisibleWorldWidth / 2 - currentMargin)
		local currentMinWcz = currentVisibleWorldHeight / 2 - currentMargin
		local currentMaxWcz = mapInfo.mapSizeZ - (currentVisibleWorldHeight / 2 - currentMargin)

		cameraState.wcx = math.min(math.max(cameraState.wcx, currentMinWcx), currentMaxWcx)
		cameraState.wcz = math.min(math.max(cameraState.wcz, currentMinWcz), currentMaxWcz)

		-- Clamp target position
		local targetVisibleWorldWidth = pipWidth / cameraState.targetZoom
		local targetVisibleWorldHeight = pipHeight / cameraState.targetZoom
		local targetSmallerDimension = math.min(targetVisibleWorldWidth, targetVisibleWorldHeight)
	local targetMargin = targetSmallerDimension * config.mapEdgeMargin
		cameraState.targetWcz = math.min(math.max(cameraState.targetWcz, targetMinWcz), targetMaxWcz)

		-- Don't recalculate here - will be done below in the main zoom/center update block
	end

	if not gameHasStarted then
		-- Only auto-focus on start position if not spectating or not tracking another player
		local isSpec = Spring.GetSpectatingState()
		if not isSpec and not interactionState.trackingPlayerID then
			local newX, _, newZ = Spring.GetTeamStartPosition(Spring.GetMyTeamID())
			if newX ~= miscState.startX then
				miscState.startX, miscState.startZ = newX, newZ
				cameraState.wcx, cameraState.wcz = miscState.startX, miscState.startZ
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
		-- Trigger maximize animation
		render.usedButtonSize = math.floor(config.buttonSize * render.widgetScale * render.uiScale)
		local buttonSizeWithScale = math.floor(render.usedButtonSize * config.maximizeSizemult)

		-- Update camera to tracked units immediately before maximizing
		if interactionState.areTracking then
			UpdateTracking()
		end
		RecalculateWorldCoordinates()
		RecalculateGroundTextureCoordinates()

		uiState.animStartDim = {
			l = uiState.minModeL,
			r = uiState.minModeL + buttonSizeWithScale,
			b = uiState.minModeB,
			t = uiState.minModeB + buttonSizeWithScale
		}
		uiState.animEndDim = {
			l = uiState.savedDimensions.l,
			r = uiState.savedDimensions.r,
			b = uiState.savedDimensions.b,
			t = uiState.savedDimensions.t
		}
		uiState.animationProgress = 0
		uiState.isAnimating = true
		uiState.inMinMode = false
		miscState.hasOpenedPIPThisGame = true
	end

	-- Automatically track the commander at game start (not for spectators)
	local spec = Spring.GetSpectatingState()
	if not spec then
		local commanderID = FindMyCommander()
		if commanderID then
			interactionState.areTracking = {commanderID}  -- Store as table/array
		end
	end
end

function widget:UnitSeismicPing(x, y, z, strength, allyTeam)
	if uiState.inMinMode then return end


	local myAllyTeam = Spring.GetMyAllyTeamID()
	--local unitAllyTeam = Spring.GetUnitAllyTeam(unitID)

	if (spec or allyTeam == myAllyTeam) then
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

		-- Limit max seismic pings to prevent memory issues
		if #cache.seismicPings > 50 then
			table.remove(cache.seismicPings, 1)
		end
	end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
	if uiState.inMinMode then return end
	-- Performance: limit max simultaneous shatters
	if #cache.iconShatters >= cache.maxIconShatters then return end

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
	-- Calculate distMult the same way as icon rendering to match size at all zoom levels
	local distMult = math.min(math.max(1, 2.2-(cameraState.zoom*3.3)), 3)
	-- Use exact same formula as icon rendering: iconRadius * cameraState.zoom * iconData.size * distMult
	local iconSize = config.iconRadius * cameraState.zoom * iconData.size * distMult

	-- Use fixed 2x2 or 3x3 grid for fewer, bigger fragments
	-- Adjust threshold based on actual rendered size
	local grid = iconSize < 40 and 2 or 3
	-- Icon is rendered at 2*iconSize (from -iconSize to +iconSize), so fragments need to match
	local fragSize = (iconSize * 2) / grid

	-- Get team color
	local teamColor = teamColors[unitTeam]
	if not teamColor then return end
	local teamR, teamG, teamB = teamColor[1], teamColor[2], teamColor[3]

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
				vx = math.cos(angle) * speed,
				vz = math.sin(angle) * speed,
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

	table.insert(cache.iconShatters, {
		startTime = gameTime,
		fragments = fragments,
		icon = iconData,
		teamR = teamR,
		teamG = teamG,
		teamB = teamB,
		duration = baseLifetime * lifetimeVariation,
		zoom = cameraState.zoom  -- Store zoom factor to compensate for gl.Scale during rendering
	})
end

function widget:VisibleExplosion(px, py, pz, weaponID, ownerID)
	if uiState.inMinMode then return end
	-- Skip processing explosions when we're not rendering them due to zoom level
	if cameraState.zoom < config.zoomExplosionDetail then return end
	if config.drawProjectiles then
		-- Skip specific weapons using cached data (e.g., footstep effects)
		if weaponID and cache.weaponSkipExplosion[weaponID] then
			return
		end

		-- Check if this is a lightning weapon
		local isLightning = weaponID and cache.weaponIsLightning[weaponID]

		-- Check if this is a paralyze weapon
		local isParalyze = weaponID and cache.weaponIsParalyze[weaponID]

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
			startTime = gameTime,
			randomSeed = math.random() * 1000,  -- For consistent per-explosion randomness
			rotationSpeed = (math.random() - 0.5) * 4,  -- Random rotation speed
			particles = {},  -- Will store particle debris
			isLightning = isLightning,
			isParalyze = isParalyze
		}

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

	-- Store point markers for rendering (from any player)
	if cmdType == 'point' then
		-- Get player's team
		local _, _, _, teamID = Spring.GetPlayerInfo(playerID, false)

		-- Add marker to list
		table.insert(miscState.mapMarkers, {
			x = mx,
			z = mz,
			time = os.clock(),
			teamID = teamID,
			playerID = playerID
		})

		-- Force PIP content update to show marker immediately
		pipR2T.contentNeedsUpdate = true
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
		return mx >= render.dim.l and mx <= render.dim.r and my >= render.dim.b and my <= render.dim.t
	end
end

function widget:MouseWheel(up, value)
	-- Handle ALT+scroll when hovering world icon to zoom PIP
	local alt = Spring.GetModKeyState()
	if alt and config.showWorldIcon and (interactionState.worldMinimizeIconHovered or interactionState.worldMaximizeIconHovered) then
		-- Don't allow zooming when tracking a player's camera
		if interactionState.trackingPlayerID then
			return true
		end

		if Spring.GetConfigInt("ScrollWheelSpeed", 1) > 0 then
			if up then
				cameraState.targetZoom = math.max(cameraState.targetZoom / config.zoomWheel, config.zoomMin)
			else
				cameraState.targetZoom = math.min(cameraState.targetZoom * config.zoomWheel, config.zoomMax)
			end
		else
			if not up then
				cameraState.targetZoom = math.max(cameraState.targetZoom / config.zoomWheel, config.zoomMin)
			else
				cameraState.targetZoom = math.min(cameraState.targetZoom * config.zoomWheel, config.zoomMax)
			end
		end

		-- Update locked icon position to follow mouse cursor's world position after zoom
		-- This keeps the icon under the cursor as zoom changes
		local mx, my = spFunc.GetMouseState()
		local _, pos = Spring.TraceScreenRay(mx, my, true)
		if pos then
			miscState.worldIconLockedX = pos[1]
			miscState.worldIconLockedZ = pos[3]
		end

		return true
	end

	if not uiState.inMinMode then
		local mx, my = spFunc.GetMouseState()
		if mx >= render.dim.l and mx <= render.dim.r and my >= render.dim.b and my <= render.dim.t then
			-- Don't allow zooming when tracking a player's camera
			if interactionState.trackingPlayerID then
				return true
			end

			local oldZoom = cameraState.targetZoom

			if Spring.GetConfigInt("ScrollWheelSpeed", 1) > 0 then
				if up then
					cameraState.targetZoom = math.max(cameraState.targetZoom / config.zoomWheel, config.zoomMin)
				else
					cameraState.targetZoom = math.min(cameraState.targetZoom * config.zoomWheel, config.zoomMax)
				end
			else
				if not up then
					cameraState.targetZoom = math.max(cameraState.targetZoom / config.zoomWheel, config.zoomMin)
				else
					cameraState.targetZoom = math.min(cameraState.targetZoom * config.zoomWheel, config.zoomMax)
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
				local pipWidth = render.dim.r - render.dim.l
				local pipHeight = render.dim.t - render.dim.b

				-- Clamp current animated position
				local currentVisibleWorldWidth = pipWidth / cameraState.zoom
				local currentVisibleWorldHeight = pipHeight / cameraState.zoom
				local currentSmallerDimension = math.min(currentVisibleWorldWidth, currentVisibleWorldHeight)
				local currentMargin = currentSmallerDimension * config.mapEdgeMargin

				local currentMinWcx = currentVisibleWorldWidth / 2 - currentMargin
				local currentMaxWcx = mapInfo.mapSizeX - (currentVisibleWorldWidth / 2 - currentMargin)
				local currentMinWcz = currentVisibleWorldHeight / 2 - currentMargin
				local currentMaxWcz = mapInfo.mapSizeZ - (currentVisibleWorldHeight / 2 - currentMargin)

				cameraState.wcx = math.min(math.max(cameraState.wcx, currentMinWcx), currentMaxWcx)
				cameraState.wcz = math.min(math.max(cameraState.wcz, currentMinWcz), currentMaxWcz)

				-- Clamp target position
				local targetVisibleWorldWidth = pipWidth / cameraState.targetZoom
				local targetVisibleWorldHeight = pipHeight / cameraState.targetZoom
				local targetSmallerDimension = math.min(targetVisibleWorldWidth, targetVisibleWorldHeight)
				local targetMargin = targetSmallerDimension * config.mapEdgeMargin

				local targetMinWcx = targetVisibleWorldWidth / 2 - targetMargin
				local targetMaxWcx = mapInfo.mapSizeX - (targetVisibleWorldWidth / 2 - targetMargin)
				local targetMinWcz = targetVisibleWorldHeight / 2 - targetMargin
				local targetMaxWcz = mapInfo.mapSizeZ - (targetVisibleWorldHeight / 2 - targetMargin)

				cameraState.targetWcx = math.min(math.max(cameraState.targetWcx, targetMinWcx), targetMaxWcx)
				cameraState.targetWcz = math.min(math.max(cameraState.targetWcz, targetMinWcz), targetMaxWcz)

				RecalculateWorldCoordinates()
				RecalculateGroundTextureCoordinates()
			end

			return true
		end
	end
end

function widget:MousePress(mx, my, mButton)

	-- Track mapmark initiation position if mouse is over PiP (for point markers with double-click)
	if mx >= render.dim.l and mx <= render.dim.r and my >= render.dim.b and my <= render.dim.t and not uiState.inMinMode then
		miscState.mapmarkInitScreenX = mx
		miscState.mapmarkInitScreenY = my
		miscState.mapmarkInitTime = os.clock()
	end

	-- Handle ALT+click on world minimize/maximize icons - start tracking for drag vs click
	local alt = Spring.GetModKeyState()
	if config.showWorldIcon and mButton == 1 and alt and not uiState.isAnimating then
		if (uiState.inMinMode and interactionState.worldMaximizeIconHovered) or
		   (not uiState.inMinMode and interactionState.worldMinimizeIconHovered) then
			-- Start tracking for potential drag or click (screen coordinates only for window movement)
			interactionState.worldIconClickStartX = mx
			interactionState.worldIconClickStartY = my
			return true  -- Capture the click
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

			-- Start panning (but not when tracking player camera)
			if not interactionState.trackingPlayerID then
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
				-- Start maximize animation - restore saved dimensions
				local buttonSize = math.floor(render.usedButtonSize*config.maximizeSizemult)

				-- Temporarily set dimensions to saved values to check if they're valid
				render.dim.l = uiState.savedDimensions.l
				render.dim.r = uiState.savedDimensions.r
				render.dim.b = uiState.savedDimensions.b
				render.dim.t = uiState.savedDimensions.t
				CorrectScreenPosition()

				-- Update camera to tracked units immediately before maximizing
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
			interactionState.panStartX = (render.dim.l + render.dim.r) / 2
			interactionState.panStartY = (render.dim.b + render.dim.t) / 2
			return true
		end
	end

	-- Did we click within the pip window ?
	if mx >= render.dim.l and mx <= render.dim.r and my >= render.dim.b and my <= render.dim.t then

		-- Was it a left click? -> check buttons
		if mButton == 1 then

			-- Resize thing (check first - highest priority)
			if render.dim.r-mx + my-render.dim.b <= render.usedButtonSize then
				uiState.areResizing = true
				return true
			end

			-- Minimizing? (or ALT+drag/middle drag to move window)
			if mx >= render.dim.r - render.usedButtonSize and my >= render.dim.t - render.usedButtonSize then
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
					-- Show pip_track button if has selection or is tracking units
					if buttons[i].command == 'pip_track' then
						if hasSelection or isTracking then
							visibleButtons[#visibleButtons + 1] = buttons[i]
						end
					-- Show pip_trackplayer button if lockcamera is available or already tracking
					elseif buttons[i].command == 'pip_trackplayer' then
						if showPlayerTrackButton then
							visibleButtons[#visibleButtons + 1] = buttons[i]
						end
					-- Show pip_view button only for spectators
					elseif buttons[i].command == 'pip_view' then
						local _, _, spec = spFunc.GetPlayerInfo(Spring.GetMyPlayerID(), false)
						if spec then
							visibleButtons[#visibleButtons + 1] = buttons[i]
						end
					else
						visibleButtons[#visibleButtons + 1] = buttons[i]
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
					if config.leftButtonPansCamera and not interactionState.trackingPlayerID then
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

	-- Handle world icon drag (ALT+drag to move PIP window on screen)
	if alt and interactionState.worldIconClickStartX ~= 0 and not uiState.isAnimating then
		local dragThreshold = 8  -- Pixels before considering it a drag
		local dragDistX = math.abs(mx - interactionState.worldIconClickStartX)
		local dragDistY = math.abs(my - interactionState.worldIconClickStartY)

		if dragDistX > dragThreshold or dragDistY > dragThreshold or interactionState.worldIconDragging then
			interactionState.worldIconDragging = true

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

			return true
		end
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
				if uiState.savedDimensions then
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
			interactionState.arePanning = true
			interactionState.areTracking = nil
			-- Cancel any ongoing smooth animation by setting target to current position
			cameraState.targetWcx = cameraState.wcx
			cameraState.targetWcz = cameraState.wcz
			cameraState.zoomToCursorActive = false
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
			interactionState.arePanning = true
			interactionState.areTracking = nil
			-- Cancel any ongoing smooth animation by setting target to current position
			cameraState.targetWcx = cameraState.wcx
			cameraState.targetWcz = cameraState.wcz
			cameraState.zoomToCursorActive = false
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
			interactionState.arePanning = true
			interactionState.areTracking = nil
			-- Cancel any ongoing smooth animation by setting target to current position
			cameraState.targetWcx = cameraState.wcx
			cameraState.targetWcz = cameraState.wcz
			cameraState.zoomToCursorActive = false
		end
	end

	if uiState.areResizing then
		local minSize = math.floor(config.minPanelSize*render.widgetScale)
		local maxSize = math.floor(render.vsy * config.maxPanelSizeVsy)

		-- Apply width constraint
		if render.dim.r+dx - render.dim.l >= minSize then
			local newWidth = render.dim.r + dx - render.dim.l
			if newWidth <= maxSize then
				render.dim.r = render.dim.r + dx
			end
		end

		-- Apply height constraint
		if render.dim.t-dy - render.dim.b >= minSize then
			local newHeight = render.dim.t - dy - render.dim.b
			if newHeight <= maxSize then
				render.dim.b = render.dim.b + dy
			end
		end

		CorrectScreenPosition()
		RecalculateWorldCoordinates()
		RecalculateGroundTextureCoordinates()

		-- Update guishader blur dimensions
		UpdateGuishaderBlur()

		-- Clamp camera position to respect margin after resize
		local pipWidth = render.dim.r - render.dim.l
		local pipHeight = render.dim.t - render.dim.b
		local visibleWorldWidth = pipWidth / cameraState.zoom
		local visibleWorldHeight = pipHeight / cameraState.zoom
		local smallerVisibleDimension = math.min(visibleWorldWidth, visibleWorldHeight)
		local margin = smallerVisibleDimension * config.mapEdgeMargin

		local minWcx = visibleWorldWidth / 2 - margin
		local maxWcx = mapInfo.mapSizeX - (visibleWorldWidth / 2 - margin)
		local minWcz = visibleWorldHeight / 2 - margin
		local maxWcz = mapInfo.mapSizeZ - (visibleWorldHeight / 2 - margin)

		cameraState.wcx = math.min(math.max(cameraState.wcx, minWcx), maxWcx)
		cameraState.wcz = math.min(math.max(cameraState.wcz, minWcz), maxWcz)
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
		-- Pan the camera based on mouse movement (only if there's movement)
		if dx ~= 0 or dy ~= 0 then
			-- Apply inverse rotation to mouse deltas if minimap is rotated
			local panDx, panDy = dx, dy
			if render.minimapRotation ~= 0 then
				local cosR = math.cos(-render.minimapRotation)
				local sinR = math.sin(-render.minimapRotation)
				panDx = dx * cosR - dy * sinR
				panDy = dx * sinR + dy * cosR
			end

			-- Calculate the visible world area at current zoom
			-- At 90/270 degrees, swap dimensions for correct panning limits
			local pipWidth = render.dim.r - render.dim.l
			local pipHeight = render.dim.t - render.dim.b
			local visibleWorldWidth = pipWidth / cameraState.zoom
			local visibleWorldHeight = pipHeight / cameraState.zoom

			if render.minimapRotation then
				local rotDeg = math.abs(render.minimapRotation * 180 / math.pi) % 180
				if rotDeg > 45 and rotDeg < 135 then
					visibleWorldWidth, visibleWorldHeight = visibleWorldHeight, visibleWorldWidth
				end
			end

			-- Use the smaller dimension for consistent visual margin
			local smallerVisibleDimension = math.min(visibleWorldWidth, visibleWorldHeight)
			local margin = smallerVisibleDimension * config.mapEdgeMargin

			-- Calculate min/max camera positions to keep margin from map edges
			local minWcx = visibleWorldWidth / 2 - margin
			local maxWcx = mapInfo.mapSizeX - (visibleWorldWidth / 2 - margin)
			local minWcz = visibleWorldHeight / 2 - margin
			local maxWcz = mapInfo.mapSizeZ - (visibleWorldHeight / 2 - margin)

			-- Apply panning with margin-based limits (using rotated deltas)
			cameraState.wcx = math.min(math.max(cameraState.wcx - panDx / cameraState.zoom, minWcx), maxWcx)
			cameraState.wcz = math.min(math.max(cameraState.wcz + panDy / cameraState.zoom, minWcz), maxWcz)
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
	-- Handle world icon click/drag release
	if mButton == 1 and interactionState.worldIconClickStartX ~= 0 then
		local wasDragging = interactionState.worldIconDragging
		local dragThreshold = 8  -- Pixels before considering it a drag
		local dragDistX = math.abs(mx - interactionState.worldIconClickStartX)
		local dragDistY = math.abs(my - interactionState.worldIconClickStartY)
		local wasClick = dragDistX <= dragThreshold and dragDistY <= dragThreshold

		-- Reset drag state
		interactionState.worldIconClickStartX = 0
		interactionState.worldIconClickStartY = 0
		interactionState.worldIconDragging = false

		-- If it was a click (not a drag), trigger minimize/maximize
		if wasClick and not uiState.isAnimating then
			local buttonSize = math.floor(render.usedButtonSize*config.maximizeSizemult)

			if uiState.inMinMode then
				-- Maximize from world icon
				render.dim.l = uiState.savedDimensions.l
				render.dim.r = uiState.savedDimensions.r
				render.dim.b = uiState.savedDimensions.b
				render.dim.t = uiState.savedDimensions.t
				CorrectScreenPosition()

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
				interactionState.isMouseOverPip = false
			else
				-- Minimize from world icon
				uiState.savedDimensions = {
					l = render.dim.l,
					r = render.dim.r,
					b = render.dim.b,
					t = render.dim.t
				}

				uiState.animStartDim = {
					l = render.dim.l,
					r = render.dim.r,
					b = render.dim.b,
					t = render.dim.t
				}
				uiState.animEndDim = {
					l = uiState.minModeL,
					r = uiState.minModeL + buttonSize,
					b = uiState.minModeB,
					t = uiState.minModeB + buttonSize
				}
				uiState.animationProgress = 0
				uiState.isAnimating = true
				uiState.inMinMode = true
				interactionState.isMouseOverPip = false
			end
		end
		return  -- Don't process further
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
				local buttonSize = math.floor(render.usedButtonSize*config.maximizeSizemult)

				render.dim.l = uiState.savedDimensions.l
				render.dim.r = uiState.savedDimensions.r
				render.dim.b = uiState.savedDimensions.b
				render.dim.t = uiState.savedDimensions.t
				CorrectScreenPosition()

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
	if mButton == 1 and mx >= render.dim.l and mx <= render.dim.r and my >= render.dim.b and my <= render.dim.t and not uiState.inMinMode and config.leftButtonPansCamera then
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
			-- Whether it was a drag or just a click, stop panning
			interactionState.arePanning = false
			interactionState.middleMousePressed = false
			interactionState.middleMouseMoved = false
		elseif interactionState.panToggleMode then
			-- Middle mouse released while in toggle mode (click was outside our window) - ignore
		end
	end

	-- Only stop panning from left button if not in toggle mode AND using leftButtonPansCamera mode
	-- (Don't interfere with left+right button panning which handles its own cleanup above)
	if interactionState.arePanning and not interactionState.panToggleMode and not interactionState.middleMousePressed and config.leftButtonPansCamera and mButton == 1 then
		interactionState.arePanning = false
	end

	interactionState.areIncreasingZoom = false
	interactionState.areDecreasingZoom = false
end
