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
		layer     = -90005,
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
local panelBorderColorLight = {0.75, 0.75, 0.75, 1}
local panelBorderColorDark = {0.2, 0.2, 0.2, 1}
local minPanelSize = 330
local buttonSize = 50

local zoomWheel = 1.22 -- Factor for mousewheel zoom
local zoomRate = 15 -- magnification multiplication per second
local zoomSmoothness = 10 -- How fast zoom transitions happen (higher = faster)
local centerSmoothness = 15 -- How fast camera center pans during zoom-to-cursor (higher = faster)
local trackingSmoothness = 8 -- How fast camera transitions when tracking units die/move (higher = faster, lower = smoother)
local zoomMin = 0.06
local zoomMax = 0.8
local zoom = 0.55 -- Initial zoom level
local zoomFeatures = 0.2 -- Zoom level at which features stop being drawn (below this zoom, features are hidden)
local zoomProjectileDetail = 0.2 -- Zoom level threshold for drawing expensive projectile effects (projectiles, beams, shatters). Explosions always shown.
local zoomExplosionDetail = 0.1 -- Zoom level threshold for drawing expensive projectile effects (projectiles, beams, shatters). Explosions always shown.

local iconRadius = 40

local leftButtonPansCamera = false
local hideCursorWhilePanning = true
local maximizeSizemult = 1.25	-- enlarge the maximize icon so it stands out more
local screenMargin = 0.05	-- limit how close to the screen edge the PiP window can be moved
local drawProjectiles = true  -- Show projectiles and explosions in PIP window
local zoomToCursor = true  -- When increasing zoom (getting closer), zoom towards cursor position (decreasing zoom pulls back to center)
local mapEdgeMargin = 0.15  -- Maximum allowed distance from PiP edge to map edge (as fraction of PiP size)

local pipMinUpdateRate = 40  -- Minimum FPS for PIP rendering when zoomed out (performance-adjusted dynamically)
local pipMaxUpdateRate = 120  -- Maximum FPS for PIP rendering when zoomed in
local pipZoomThresholdMin = 0.15  -- Zoom level where we use minimum update rate
local pipZoomThresholdMax = 0.4  -- Zoom level where we use maximum update rate
local pipTargetDrawTime = 0.003  -- Target draw time in seconds (3ms) - if exceeded, reduce update rate
local pipPerformanceAdjustSpeed = 0.1  -- How quickly to adjust FPS based on performance (0-1, higher = faster adjustment)

local CMD_AREA_MEX = GameCMD and GameCMD.AREA_MEX or 10000  -- Area mex command

----------------------------------------------------------------------------------------------------
-- Globals
----------------------------------------------------------------------------------------------------

local uiScale = tonumber(Spring.GetConfigFloat("ui_scale", 1) or 1)
local vsx, vsy = Spring.GetViewGeometry()
local widgetScale = (vsy / 2000) * uiScale

-- Interface dimension tables
local dim = {} -- Panel dimensions: left, right, bottom, top
	dim.l = math.floor(vsx*0.7)
	dim.r = math.floor((vsx*0.7)+(minPanelSize*widgetScale*1.4))
	dim.b = math.floor(vsy*0.7)
	dim.t = math.floor((vsy*0.7)+(minPanelSize*widgetScale*1.2))

local world = {} -- World coordinate boundaries
local ground = { view = {}, coord = {} } -- Ground texture view and texture coordinates

-- Base variables
local targetZoom = zoom
local wcx, wcz = 1000, 1000
local targetWcx, targetWcz = wcx, wcz  -- Target camera center for smooth transitions

-- Zoom-to-cursor state (stores the locked cursor world position)
local zoomToCursorActive = false
local zoomToCursorWorldX, zoomToCursorWorldZ = 0, 0  -- World position to keep under cursor
local zoomToCursorScreenX, zoomToCursorScreenY = 0, 0  -- Screen position of cursor

-- State variables
local inMinMode = false
local minModeL
local minModeB
local savedDimensions = {} -- Store dimensions before minimizing
local isAnimating = false
local animationProgress = 0
local animationDuration = 0.22 -- seconds for the minimize/maximize transition animation
local animStartDim = {} -- Starting dimensions for animation
local animEndDim = {} -- Ending dimensions for animation
local drawingGround = true
local areResizing = false

-- Render-to-texture state (consolidated to reduce local variable count)
local pipR2T = {
	contentTex = nil,
	contentNeedsUpdate = true,
	contentLastUpdateTime = 0,
	contentCurrentUpdateRate = pipMinUpdateRate,
	contentLastWidth = 0,
	contentLastHeight = 0,
	contentLastDrawTime = 0,  -- Last measured draw time for performance monitoring
	contentPerformanceFactor = 1.0,  -- Multiplier applied to update rate based on performance (1.0 = no adjustment)
	frameBackgroundTex = nil,
	frameButtonsTex = nil,
	frameNeedsUpdate = true,
	frameLastWidth = 0,
	frameLastHeight = 0,
}
local minModeDlist = nil  -- Display list for minimized mode button

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
	lastMapDrawX = nil,
	lastMapDrawZ = nil,
	clickHandledInPanMode = false,
}

-- Misc variables
local startX, startZ
local isProcessingMapDraw = false -- Prevent MapDrawCmd recursion
local mapmarkInitScreenX, mapmarkInitScreenY = nil, nil -- Track where mapmark was initiated
local mapmarkInitTime = 0 -- Track when mapmark was initiated
local backupTracking = nil -- Store tracking state when switching views
local hadSavedConfig = false -- Track if we loaded from saved config (to avoid auto-minimize on reload)
local unitShader
local pipUnits = {}
local pipFeatures = {}
-- Arrays for unit icons (batched drawing)
local pipIconTeam, pipIconX, pipIconY, pipIconUdef, pipIconSelected = {}, {}, {}, {}, {}
local lastSelectionboxEnabled = nil -- Track selectionbox widget state for command color config

-- Reusable table pools to reduce GC pressure
-- These tables are reused across frames instead of being allocated/deallocated repeatedly
-- This significantly reduces garbage collection overhead in performance-critical draw paths
local iconsByTexturePool = {} -- Reused for grouping icons by texture (DrawUnitsAndFeatures)
local defaultIconIndicesPool = {} -- Reused for default icon indices (DrawUnitsAndFeatures)
local selectableUnitsPool = {} -- Reused for GetUnitsInBox results
local fragmentsByTexturePool = {} -- Reused for icon shatter fragments grouping (DrawIconShatters)
local unitsToShowPool = {} -- Reused for DrawCommandQueuesOverlay unit list
local commandLinePool = {} -- Reused for batched command line vertices
local commandMarkerPool = {} -- Reused for batched command marker vertices

-- Consolidated cache tables
local cache = {
	noModelFeatures = {},
	xsizes = {},
	zsizes = {},
	unitIcon = {},
	isFactory = {},
	radiusSqs = {},
	featureRadiusSqs = {},
	projectileSizes = {},
	explosions = {},
	laserBeams = {},
	iconShatters = {},
	maxIconShatters = 20,
	weaponIsLaser = {},
	weaponIsBlaster = {},
	weaponIsPlasma = {},
	weaponIsMissile = {},
	weaponIsLightning = {},
	weaponIsFlame = {},
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
local gameHasStarted

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
		-- deathWatch is not a standard CMD constant
	}

-- Buttons (Must be declared after variables)
local buttons = {
	-- 	texture = 'LuaUI/Images/pip/PipMinus.png',
	-- 	tooltip = 'Decrease zoom (pull back) [Hold]',
	-- 	command = nil,
	-- 	OnPress = function() interactionState.areDecreasingZoom = true end
	-- },
	-- {
	-- 	texture = 'LuaUI/Images/pip/PipPlus.png',
	-- 	tooltip = 'Increase zoom (get closer) [Hold]',
	-- 	command = nil,
	-- 	OnPress = function() interactionState.areIncreasingZoom = true end
	-- },
	-- {
	-- 	texture = 'LuaUI/Images/pip/PipCenter.png',
	-- 	tooltip = 'Enter centering mode',
	-- 	command = nil,
	-- 	OnPress = function() interactionState.areCentering = true interactionState.areTracking = nil end
	-- },
	{
		texture = 'LuaUI/Images/pip/PipSwitch.png',
		tooltip = Spring.I18N('ui.pip.switch'),
		command = 'pip_switch',
		OnPress = function()
				local sizex, sizez = Spring.GetWindowGeometry()
				local _, pos = Spring.TraceScreenRay(sizex/2, sizez/2, true)
				if pos and pos[2] > -10000 then
					-- Calculate the actual center of tracked units (if tracking) for main view camera
					local pipCameraTargetX, pipCameraTargetZ = wcx, wcz
					if interactionState.areTracking and #interactionState.areTracking > 0 then
						-- Calculate average position of tracked units (not margin-corrected camera)
						local uCount = 0
						local ax, az = 0, 0
						for i = 1, #interactionState.areTracking do
							local uID = interactionState.areTracking[i]
							local ux, uy, uz = Spring.GetUnitBasePosition(uID)
							if ux then
								ax = ax + ux
								az = az + uz
								uCount = uCount + 1
							end
						end
						if uCount > 0 then
							pipCameraTargetX, pipCameraTargetZ = ax / uCount, az / uCount
						end

						-- First untrack anything in main view
						Spring.SendCommands("track")
						-- Then track the PIP units in main view
						for i = 1, #interactionState.areTracking do
							Spring.SendCommands("track " .. interactionState.areTracking[i])
						end
					else
						-- If not tracking in PIP, untrack in main view
						Spring.SendCommands("track")
					end

					-- Backup current tracking state before switching
					local tempTracking = backupTracking
					backupTracking = interactionState.areTracking

					-- Switch camera positions - use actual unit center, not margin-corrected camera
					Spring.SetCameraTarget(pipCameraTargetX, 0, pipCameraTargetZ, 0.2)
					wcx, wcz = pos[1], pos[3]
					targetWcx, targetWcz = wcx, wcz  -- Set targets instantly for button clicks
					RecalculateWorldCoordinates()
					RecalculateGroundTextureCoordinates()

					-- Restore tracking state from previous backup
					interactionState.areTracking = tempTracking
				end
			end
	},
	{
		texture = 'LuaUI/Images/pip/PipT.png',
		tooltip = Spring.I18N('ui.pip.track'),
		command = 'pip_track',
		OnPress = function()
					if interactionState.areTracking then
						interactionState.areTracking = nil
					else
						interactionState.areTracking = Spring.GetSelectedUnits()
						-- Disable zoom-to-cursor when tracking is enabled
						zoomToCursorActive = false
					end
				end
	},
	{
		texture = 'LuaUI/Images/pip/PipMove.png',
		tooltip = Spring.I18N('ui.pip.move'),
		command = nil,
		OnPress = function() interactionState.areDragging = true end
	},
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

local GL_LINE_STRIP = GL.LINE_STRIP
local GL_LINES = GL.LINES
local GL_TRIANGLES = GL.TRIANGLES
local GL_TRIANGLE_FAN = GL.TRIANGLE_FAN
local GL_QUADS = GL.QUADS
local GL_LINE_LOOP = GL.LINE_LOOP

local glColor = gl.Color
local glTexCoord = gl.TexCoord
local glTexture = gl.Texture
local glTexRect = gl.TexRect
local glVertex = gl.Vertex
local glBeginEnd = gl.BeginEnd
local glText = gl.Text
local glPushMatrix = gl.PushMatrix
local glPopMatrix = gl.PopMatrix
local glTranslate = gl.Translate
local glRotate = gl.Rotate
local glScale = gl.Scale
local glUnitRaw = gl.UnitRaw
local glCallList = gl.CallList

local spGetGroundHeight = Spring.GetGroundHeight
local spGetUnitsInRectangle = Spring.GetUnitsInRectangle
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitBasePosition = Spring.GetUnitBasePosition
local spGetUnitDirection = Spring.GetUnitDirection
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitDefID = Spring.GetUnitDefID
local spGetFeatureDefID = Spring.GetFeatureDefID
local spGetFeatureDirection = Spring.GetFeatureDirection
local spGetFeaturePosition = Spring.GetFeaturePosition
local spGetFeatureTeam = Spring.GetFeatureTeam
local spGetFeaturesInRectangle = Spring.GetFeaturesInRectangle
local spIsUnitSelected = Spring.IsUnitSelected
local spGetUnitHealth = Spring.GetUnitHealth
local spGetMouseState = Spring.GetMouseState
local spGetUnitLosState = Spring.GetUnitLosState
local spGetProjectilesInRectangle = Spring.GetProjectilesInRectangle
local spGetProjectilePosition = Spring.GetProjectilePosition
local spGetProjectileDefID = Spring.GetProjectileDefID
local spGetProjectileTarget = Spring.GetProjectileTarget
local spGetProjectileOwnerID = Spring.GetProjectileOwnerID
local spGetProjectileVelocity = Spring.GetProjectileVelocity

local rad2deg = 180 / math.pi
local atan2 = math.atan2
local mapSizeX = Game.mapSizeX
local mapSizeZ = Game.mapSizeZ


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
	local hw, hh = 0.5 * (dim.r - dim.l) / zoom, 0.5 * (dim.t - dim.b) / zoom
	world.l, world.r, world.b, world.t = wcx - hw, wcx + hw, wcz + hh, wcz - hh

	-- Precalculate factors for WorldToPipCoords (performance)
	local worldWidth = world.r - world.l
	local worldHeight = world.t - world.b
	if worldWidth ~= 0 and worldHeight ~= 0 then
		worldToPipScaleX = (dim.r - dim.l) / worldWidth
		worldToPipScaleZ = (dim.t - dim.b) / worldHeight
		worldToPipOffsetX = dim.l - world.l * worldToPipScaleX
		worldToPipOffsetZ = dim.b - world.b * worldToPipScaleZ
	end
end

function RecalculateGroundTextureCoordinates()
	if world.l < 0 then
		ground.view.l = dim.l + (dim.r - dim.l) * (-world.l / (world.r - world.l))
		ground.coord.l = 0
	else
		ground.view.l = dim.l
		ground.coord.l = world.l / mapSizeX
	end
	if world.r > mapSizeX then
		ground.view.r = dim.r - (dim.r - dim.l) * ((world.r - mapSizeX) / (world.r - world.l))
		ground.coord.r = 1
	else
		ground.view.r = dim.r
		ground.coord.r = world.r / mapSizeX
	end
	if world.t < 0 then
		ground.view.t = dim.t - (dim.t - dim.b) * (-world.t / (world.b - world.t))
		ground.coord.t = 0
	else
		ground.view.t = dim.t
		ground.coord.t = world.t / mapSizeZ
	end
	if world.b > mapSizeZ then
		ground.view.b = dim.b + (dim.t - dim.b) * ((world.b - mapSizeZ) / (world.b - world.t))
		ground.coord.b = 1
	else
		ground.view.b = dim.b
		ground.coord.b = world.b / mapSizeZ
	end
end

local function CorrectScreenPosition()
	local screenMarginPx = math.floor(screenMargin * vsy)
	local minSize = math.floor(minPanelSize * widgetScale)

	-- Calculate current window dimensions
	local windowWidth = dim.r - dim.l
	local windowHeight = dim.t - dim.b

	-- Enforce minimum panel size
	if windowWidth < minSize then
		windowWidth = minSize
		dim.r = dim.l + windowWidth
	end
	if windowHeight < minSize then
		windowHeight = minSize
		dim.t = dim.b + windowHeight
	end

	-- Check and correct left boundary
	if dim.l < screenMarginPx then
		dim.l = screenMarginPx
		dim.r = dim.l + windowWidth
	end

	-- Check and correct right boundary
	if dim.r > vsx - screenMarginPx then
		dim.r = vsx - screenMarginPx
		dim.l = dim.r - windowWidth
	end

	-- Check and correct bottom boundary
	if dim.b < screenMarginPx then
		dim.b = screenMarginPx
		dim.t = dim.b + windowHeight
	end

	-- Check and correct top boundary
	if dim.t > vsy - screenMarginPx then
		dim.t = vsy - screenMarginPx
		dim.b = dim.t - windowHeight
	end
end

local function UpdateGuishaderBlur()
	if WG['guishader'] then
		-- Always update blur with current dimensions (including when minimized)
		-- The dim values will reflect the minimized button size when inMinMode is true
		if WG['guishader'].InsertRect then
			WG['guishader'].InsertRect(dim.l-elementPadding, dim.b-elementPadding, dim.r+elementPadding, dim.t+elementPadding, 'pip'..pipNumber)
		end
	end
end

local function UpdateCentering(mx, my)
	local _, pos = Spring.TraceScreenRay(mx, my, true)
	if pos and pos[2] > -10000 then
		wcx, wcz = pos[1], pos[3]
		targetWcx, targetWcz = wcx, wcz  -- Set targets instantly for centering
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
		local ux, uy, uz = spGetUnitBasePosition(uID)
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
		local pipWidth = dim.r - dim.l
		local pipHeight = dim.t - dim.b
		local visibleWorldWidth = pipWidth / zoom
		local visibleWorldHeight = pipHeight / zoom
		local smallerVisibleDimension = math.min(visibleWorldWidth, visibleWorldHeight)
		local margin = smallerVisibleDimension * mapEdgeMargin

		-- Calculate min/max camera positions to keep margin from map edges
		local minWcx = visibleWorldWidth / 2 - margin
		local maxWcx = mapSizeX - (visibleWorldWidth / 2 - margin)
		local minWcz = visibleWorldHeight / 2 - margin
		local maxWcz = mapSizeZ - (visibleWorldHeight / 2 - margin)

		-- Set only the target positions for smooth camera transition, clamped to margins
		targetWcx = math.min(math.max(newTargetWcx, minWcx), maxWcx)
		targetWcz = math.min(math.max(newTargetWcz, minWcz), maxWcz)

		-- Don't update wcx/wcz immediately - let the smooth interpolation system handle it
		-- RecalculateWorldCoordinates() and RecalculateGroundTextureCoordinates() will be called in Update()

		interactionState.areTracking = stillAlive
	else
		interactionState.areTracking = nil
	end
end
local function PipToWorldCoords(mx, my)
	return world.l + (world.r - world.l) * ((mx - dim.l) / (dim.r - dim.l)),
		   world.b + (world.t - world.b) * ((my - dim.b) / (dim.t - dim.b))
end
local function WorldToPipCoords(wx, wz)
	-- Use precalculated factors for performance (avoids repeated division)
	return worldToPipOffsetX + wx * worldToPipScaleX,
		   worldToPipOffsetZ + wz * worldToPipScaleZ
end

-- Drawing
local function ResizeHandleVertices()
	glVertex(dim.r, dim.b)
	glVertex(dim.r - usedButtonSize, dim.b)
	glVertex(dim.r, dim.b + usedButtonSize)
end
local function GroundTextureVertices()
	glTexCoord(ground.coord.l, ground.coord.b); glVertex(ground.view.l, ground.view.b)
	glTexCoord(ground.coord.r, ground.coord.b); glVertex(ground.view.r, ground.view.b)
	glTexCoord(ground.coord.r, ground.coord.t); glVertex(ground.view.r, ground.view.t)
	glTexCoord(ground.coord.l, ground.coord.t); glVertex(ground.view.l, ground.view.t)
end

local function UnitBuildingVerts(prog)
	local f = 2 * prog
	glVertex(-1, 0.1, -1); glVertex(-1 + f, 0.1, -1    )
	glVertex( 1, 0.1, -1); glVertex( 1    , 0.1, -1 + f)
	glVertex( 1, 0.1,  1); glVertex( 1 - f, 0.1,  1    )
	glVertex(-1, 0.1,  1); glVertex(-1    , 0.1,  1 - f)
end

local function DrawPanel(l, r, b, t)
	glColor(0.6,0.6,0.6,0.6)
	--RectRound(l, b, r, t, elementCorner*0.4, 1, 1, 1, 1)
	UiElement(l-elementPadding, b-elementPadding, r+elementPadding, t+elementPadding, 1, 1, 1, 1, nil, nil, nil, nil, nil, nil, nil, nil)
end

-- Draw panel background without borders (for display lists that will have borders drawn separately)
local function DrawPanelBackground(l, r, b, t)
	glColor(0.6,0.6,0.6,0.6)
	RectRound(l, b, r, t, elementCorner*0.4, 1, 1, 1, 1)
end

local function DrawGroundLine(x1, z1, x2, z2)
	local dx, dz = x2 - x1, z2 - z1
	for s = 0, 1, 0.0625 do
		local tx, tz = x1 + dx * s, z1 + dz * s
		glVertex(tx, spGetGroundHeight(tx, tz) + 5.0, tz)
	end
end

local function DrawGroundBox(l, r, b, t)
	DrawGroundLine(l, t, r, t)
	DrawGroundLine(r, t, r, b)
	DrawGroundLine(r, b, l, b)
	DrawGroundLine(l, b, l, t)
end

local function DrawFormationDots(formationNodes, lineLength, selectedUnitsCount, formationCmd)
	if not formationNodes or #formationNodes < 2 or selectedUnitsCount < 2 then
		return
	end

	-- Set color based on command type
	local r, g, b = 0.5, 0.5, 1.0 -- Default blue
	if formationCmd == CMD.MOVE then
		r, g, b = 0.5, 1.0, 0.5 -- Green
	elseif formationCmd == CMD.ATTACK then
		r, g, b = 1.0, 0.2, 0.2 -- Red
	elseif formationCmd == CMD.FIGHT then
		r, g, b = 0.5, 0.5, 1.0 -- Blue
	end

	local lengthPerUnit = lineLength / (selectedUnitsCount - 1)
	local dotSize = 15 -- Fixed size for PIP window

	-- Helper to draw a dot at a position using texture
	local function DrawDot(pos)
		gl.PushMatrix()
		gl.Translate(pos[1], pos[2] + 1, pos[3]) -- Slightly above ground
		gl.Color(r, g, b, 1.0)
		gl.Texture("LuaUI/Images/pip/formationDot.dds")
		gl.BeginEnd(GL.QUADS, function()
			gl.TexCoord(0, 0); gl.Vertex(-dotSize, 0, -dotSize)
			gl.TexCoord(1, 0); gl.Vertex(dotSize, 0, -dotSize)
			gl.TexCoord(1, 1); gl.Vertex(dotSize, 0, dotSize)
			gl.TexCoord(0, 1); gl.Vertex(-dotSize, 0, dotSize)
		end)
		gl.Texture(false)
		gl.PopMatrix()
	end

	gl.DepthTest(true)

	-- Draw first dot
	DrawDot(formationNodes[1])

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
				local interpPos = {
					node1[1] + (node2[1] - node1[1]) * factor,
					node1[2] + (node2[2] - node1[2]) * factor,
					node1[3] + (node2[3] - node1[3]) * factor
				}
				DrawDot(interpPos)
				lengthUnitNext = lengthUnitNext + lengthPerUnit
			end
			currentLength = currentLength + length
		end
	end

	-- Draw last dot
	DrawDot(formationNodes[#formationNodes])

	gl.DepthTest(false)
	gl.Color(1, 1, 1, 1)
end


local function DrawUnit(uID)
	local uDefID = spGetUnitDefID(uID)
	if not uDefID then return end

	local uTeam = spGetUnitTeam(uID)
	local ux, uy, uz = spGetUnitBasePosition(uID)
	if not ux then return end  -- Early exit if position is invalid

	glPushMatrix()
	glTranslate(ux - wcx, wcz - uz, 0)
	-- Store for batched icon drawing later
	local idx = #pipIconTeam + 1
	pipIconTeam[idx] = uTeam
	pipIconX[idx], pipIconY[idx] = WorldToPipCoords(ux, uz)
	pipIconUdef[idx] = uDefID
	pipIconSelected[idx] = spIsUnitSelected(uID)
	glPopMatrix()
end

local function DrawFeature(fID)
	local fDefID = spGetFeatureDefID(fID)
	if not fDefID or cache.noModelFeatures[fDefID] then return end

	local fx, fy, fz = spGetFeaturePosition(fID)
	if not fx then return end  -- Early exit if position is invalid

	local dirx, _, dirz = spGetFeatureDirection(fID)
	local uHeading = dirx and atan2(dirx, dirz) * rad2deg or 0

	glPushMatrix()
		glTranslate(fx - wcx, wcz - fz, 0)
		glRotate(68, 1, 0, 0)  -- Rotate 75 degrees around X-axis to make models face upright
		glRotate(27, 0, 0, 1)	-- tilt slightly for better visibility
		glRotate(-8, 0, 1, 0)	-- tilt slightly for better visibility
		glRotate(uHeading, 0, 1, 0)
		glTexture(0, '%-' .. fDefID .. ':0')
		gl.FeatureShape(fDefID, spGetFeatureTeam(fID))
	glPopMatrix()
end

local function DrawProjectile(pID)
	local px, py, pz = spGetProjectilePosition(pID)
	if not px then return end

	-- Get projectile DefID - all projectiles from weapons will have this
	local pDefID = spGetProjectileDefID(pID)

	-- Get projectile size from cache or calculate it
	local size = 4 -- Default size
	local color = {1, 0.5, 0, 1} -- Default orange
	local width, height, isMissile, angle -- Initialize these early for blaster and missile handling

	if pDefID then
		-- This is a weapon projectile

		-- Check if this is a laser weapon (instant beam like BeamLaser - using cached data)
		if cache.weaponIsLaser[pDefID] then
			-- Get origin (owner unit position) and target
			local ownerID = spGetProjectileOwnerID(pID)
			local targetType, targetID = spGetProjectileTarget(pID)

			if ownerID then
				-- Use unit center as origin for lasers
				local ox, oy, oz = spGetUnitPosition(ownerID)

				if ox then
					local tx, ty, tz
					local hasValidTarget = false

					-- Try to get actual target position
					if targetType and targetID then
						if targetType == string.byte('u') then -- unit target
							local targetX, targetY, targetZ = spGetUnitPosition(targetID)
							if targetX then
								tx, ty, tz = targetX, targetY, targetZ
								hasValidTarget = true
							end
						elseif targetType == string.byte('f') then -- feature target
							local targetX, targetY, targetZ = Spring.GetFeaturePosition(targetID)
							if targetX then
								tx, ty, tz = targetX, targetY, targetZ
								hasValidTarget = true
							end
						elseif targetType == string.byte('p') then -- projectile target
							local targetX, targetY, targetZ = spGetProjectilePosition(targetID)
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
			local ownerID = spGetProjectileOwnerID(pID)
			local targetType, targetID = spGetProjectileTarget(pID)

			if ownerID then
				-- Use unit center as origin for lightning
				local ox, oy, oz = spGetUnitPosition(ownerID)

				if ox then
					local tx, ty, tz
					local hasValidTarget = false

					-- Try to get actual target position
					if targetType and targetID then
						if targetType == string.byte('u') then -- unit target
							local targetX, targetY, targetZ = spGetUnitPosition(targetID)
							if targetX then
								tx, ty, tz = targetX, targetY, targetZ
								hasValidTarget = true
							end
						elseif targetType == string.byte('f') then -- feature target
							local targetX, targetY, targetZ = Spring.GetFeaturePosition(targetID)
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
					local zoomScale = math.max(0.5, zoom / 70)
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
						local x1 = prevX - wcx
						local z1 = wcz - prevZ
						local x2 = segX - wcx
						local z2 = wcz - segZ

						-- Draw outer glow
						gl.LineWidth(segOuterWidth)
						glColor(colorData[1], colorData[2], colorData[3], 0.4 * avgBrightness)
						glBeginEnd(GL_LINES, function()
							glVertex(x1, z1, 0)
							glVertex(x2, z2, 0)
						end)

						-- Draw inner core (very white with slight blue tint)
						gl.LineWidth(segInnerWidth)
						local coreR = 0.9 + colorData[1] * 0.1
						local coreG = 0.9 + colorData[2] * 0.1
						local coreB = 0.95 + colorData[3] * 0.05
						glColor(coreR, coreG, coreB, 0.98 * avgBrightness)
						glBeginEnd(GL_LINES, function()
							glVertex(x1, z1, 0)
							glVertex(x2, z2, 0)
						end)

						-- Move to next segment
						prevX, prevZ = segX, segZ
						prevBrightness = brightness
					end

					gl.LineWidth(1)

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

					glPushMatrix()
					glTranslate(tx - wcx, wcz - tz, 0)

					-- Draw bright outer glow first (bigger)
					local glowAlpha = alpha * 0.5
					local glowRadius = baseRadius * 5.8

					for j = 0, segments - 1 do
						local angle1 = j * angleStep
						local angle2 = (j + 1) * angleStep

						glBeginEnd(GL_TRIANGLES, function()
							-- Center vertex
							glColor(r * 0.7, g * 0.7, b * 0.8, glowAlpha)
							glVertex(0, 0, 0)

							-- Edge vertices (fade out)
							glColor(r * 0.4, g * 0.4, b * 0.5, 0)
							glVertex(math.cos(angle1) * glowRadius, math.sin(angle1) * glowRadius, 0)
							glVertex(math.cos(angle2) * glowRadius, math.sin(angle2) * glowRadius, 0)
						end)
					end

					-- Draw main flash with brighter core
					local coreAlpha = alpha * 0.95
					local edgeAlpha = alpha * 0.5
					local coreRadius = baseRadius * 0.4

					for j = 0, segments - 1 do
						local angle1 = j * angleStep
						local angle2 = (j + 1) * angleStep

						glBeginEnd(GL_TRIANGLES, function()
							-- Center vertex (very bright white-blue)
							glColor(1, 1, 1, coreAlpha)
							glVertex(0, 0, 0)

							-- Edge vertices (fade to electric blue)
							glColor(r * 0.8, g * 0.8, b, edgeAlpha)
							glVertex(math.cos(angle1) * coreRadius, math.sin(angle1) * coreRadius, 0)

							glColor(r * 0.8, g * 0.8, b, edgeAlpha)
							glVertex(math.cos(angle2) * coreRadius, math.sin(angle2) * coreRadius, 0)
						end)
					end

					glPopMatrix()

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

			glPushMatrix()
			glTranslate(px - wcx, wcz - pz, 0)

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
			glColor(r*1.25, g*1.25, b*1.25, 1)
			glBeginEnd(GL_TRIANGLE_FAN, function()
				glVertex(offsetX, offsetZ, 0) -- Center
				-- Create irregular flame-like shape with 6 points
				glColor(r, g, b, 0.6)
				for j = 0, sides do
					local angle = (j / sides) * math.pi * 2
					local radiusVariation = 0.6 + math.abs(math.sin(particleSeed * 17.89 + j)) * 0.8
					local radius = particleSize * 1.0 * radiusVariation
					glVertex(
						offsetX + math.cos(angle) * radius,
						offsetZ + math.sin(angle) * radius,
						0
					)
				end
			end)

			glPopMatrix()
			return -- Don't draw as regular projectile
		end

		-- Check if this is a blaster weapon (LaserCannon - traveling projectile)
		if cache.weaponIsBlaster[pDefID] then
			-- Get weapon color from cached data
			local colorData = cache.weaponColor[pDefID]
			color = {colorData[1], colorData[2], colorData[3], 1}

			-- Make blaster bolts elongated based on velocity
			local vx, vy, vz = spGetProjectileVelocity(pID)
			if vx and (vx ~= 0 or vy ~= 0 or vz ~= 0) then
				-- Calculate bolt dimensions based on speed
				local speed = math.sqrt(vx*vx + vy*vy + vz*vz)

				-- Scale up width at low zoom (far back) for better visibility (but not length)
				local zoomScale = math.max(1, math.min(3, 1 / zoom))

				local boltLength = math.max(18, math.min(54, speed * 0.36)) -- 3x longer, constant length
				local boltWidth = math.max(1.5, cache.weaponSize[pDefID] * 1.5) * zoomScale -- width scales with zoom

				width = boltWidth
				height = boltLength
				isMissile = true -- Use missile rendering for elongation

				-- Calculate angle based on velocity direction (like missiles)
				angle = math.atan2(vx, vz) * rad2deg
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

	-- Scale plasma cannon projectiles at low zoom (far back) for better visibility
	if pDefID and cache.weaponIsPlasma[pDefID] then
		-- Scale from 1x (high zoom/close) to 2x (low zoom/far) for better visibility at distance
		local zoomScale = math.max(1, math.min(2, 1.2 / zoom))
		width = width * zoomScale * 0.9
		height = height * zoomScale * 0.9
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
		local vx, vy, vz = spGetProjectileVelocity(pID)
		if vx and (vx ~= 0 or vz ~= 0) then
			-- Calculate angle based on velocity direction
			angle = math.atan2(vx, vz) * rad2deg
		end
	end

	glPushMatrix()
		glTranslate(px - wcx, wcz - pz, 0)

		-- Rotate missile/blaster to point towards target/velocity
		if isMissile then
			glRotate(angle, 0, 0, 1)
		end

		-- Draw blaster bolts with outer glow and inner core
		if pDefID and cache.weaponIsBlaster[pDefID] then
			-- Draw outer glow (wider, more transparent)
			glColor(color[1], color[2], color[3], color[4] * 0.4)
			glBeginEnd(GL_QUADS, function()
				glVertex(-width * 1.3, -height, 0)
				glVertex(width * 1.3, -height, 0)
				glVertex(width * 1.3, height, 0)
				glVertex(-width * 1.3, height, 0)
			end)

			-- Draw inner core (brighter, whiter)
			local whiteness = 0.6 -- Blend with white for brighter core
			local coreR = color[1] * (1 - whiteness) + whiteness
			local coreG = color[2] * (1 - whiteness) + whiteness
			local coreB = color[3] * (1 - whiteness) + whiteness
			glColor(coreR, coreG, coreB, color[4] * 0.95)
			glBeginEnd(GL_QUADS, function()
				glVertex(-width * 0.6, -height, 0)
				glVertex(width * 0.6, -height, 0)
				glVertex(width * 0.6, height, 0)
				glVertex(-width * 0.6, height, 0)
			end)
		-- Draw missiles with pointed nose and tail fins
		elseif pDefID and cache.weaponIsMissile[pDefID] then
			-- Off-white color for missiles
			glColor(0.9, 0.9, 0.85, color[4])

			-- Main body (rectangle)
			glBeginEnd(GL_QUADS, function()
				glVertex(-width, -height * 0.7, 0)
				glVertex(width, -height * 0.7, 0)
				glVertex(width, height * 0.3, 0)
				glVertex(-width, height * 0.3, 0)
			end)

			-- Pointed nose (triangle at front/top pointing in direction of travel)
			glBeginEnd(GL_TRIANGLES, function()
				glVertex(-width, -height * 0.7, 0)
				glVertex(width, -height * 0.7, 0)
				glVertex(0, -height, 0) -- Tip pointing forward in direction of travel
			end)

			-- Tail fins (trapezoidal stabilizer wings starting earlier at back)
			glBeginEnd(GL_QUADS, function()
				-- Left fin (1.8x width, 1.6x length, swept back at ~25 degrees, 2x elongated toward front)
				local finWidth = width * 1.8  -- Scale by 1.8x
				local baseFinLength = height * 0.25  -- Base length scaled by 1.6 (0.15 * 1.6 = 0.24)
				local finStart = baseFinLength * 2  -- Elongated 2x toward front
				local finEnd = height * 0.0
				local finHeight = (finStart - finEnd) * 0.8  -- Height scaled by 0.8
				finStart = finEnd + finHeight
				-- No offset - fins at original position
				local sweepBack = finWidth * 0.47  -- ~25 degree sweep back (tan(25°) ≈ 0.47)

				glVertex(-width, finStart, 0)  -- Front inner edge (no sweep)
				glVertex(-finWidth, finStart, 0)  -- Front outer edge (unskewed)
				glVertex(-finWidth, finEnd + sweepBack, 0)    -- Back outer edge swept toward back
				glVertex(-width, finEnd, 0)
			end)
			glBeginEnd(GL_QUADS, function()
				-- Right fin (1.8x width, 1.6x length, swept back at ~25 degrees, 2x elongated toward front)
				local finWidth = width * 1.5 * 1.5 * 0.8  -- Scale by 1.5, then 1.5, then 0.8 = 1.8x
				local baseFinLength = height * 0.15 * 1.6  -- Base length scaled by 1.6
				local finStart = baseFinLength * 2  -- Elongated 2x toward front
				local finEnd = height * 0.0
				local finHeight = (finStart - finEnd) * 0.8  -- Height scaled by 0.8
				finStart = finEnd + finHeight
				-- No offset - fins at original position
				local sweepBack = finWidth * 0.47  -- ~25 degree sweep back (tan(25°) ≈ 0.47)

				glVertex(width, finStart, 0)  -- Front inner edge (no sweep)
				glVertex(finWidth, finStart, 0)  -- Front outer edge (unskewed)
				glVertex(finWidth, finEnd + sweepBack, 0)     -- Back outer edge swept toward back
				glVertex(width, finEnd, 0)
			end)
		else

			-- Draw plasma projectiles as circles with gradient
			if pDefID and cache.weaponIsPlasma[pDefID] then
				local radius = math.max(width, height)
				local segments = 7

				local coreWhiteness = 0.8
				local coreR = color[1] * (1 - coreWhiteness) + coreWhiteness
				local coreG = color[2] * (1 - coreWhiteness) + coreWhiteness
				local coreB = color[3] * (1 - coreWhiteness) + coreWhiteness

				local orangeTint = 0.8
				local outerR = math.min(1, color[1] + orangeTint)
				local outerG = math.max(0, color[2] - orangeTint * 0.3)
				local outerB = math.max(0, color[3] - orangeTint * 0.5)

				-- Draw gradient from center (bright white) to edge (orange-tinted)
				glBeginEnd(GL_TRIANGLES, function()
					for i = 0, segments - 1 do
						local angle1 = (i / segments) * 2 * math.pi
						local angle2 = ((i + 1) / segments) * 2 * math.pi

						-- Center vertex (bright white core)
						glColor(coreR, coreG, coreB, color[4])
						glVertex(0, 0, 0)

						-- Edge vertexes (orange-tinted outer)
						glColor(outerR, outerG, outerB, color[4])
						glVertex(math.cos(angle1) * radius, math.sin(angle1) * radius, 0)
						glVertex(math.cos(angle2) * radius, math.sin(angle2) * radius, 0)
					end
				end)
			else
				-- -- Other projectiles as squares
				-- glColor(color[1], color[2], color[3], color[4])
				-- glBeginEnd(GL_QUADS, function()
				-- 	glVertex(-width, -height, 0)
				-- 	glVertex(width, -height, 0)
				-- 	glVertex(width, height, 0)
				-- 	glVertex(-width, height, 0)
				-- end)
			end
		end

	glPopMatrix()
end

local function DrawLaserBeams()
	if #cache.laserBeams == 0 then return end

	local i = 1

	-- Precompute zoom-dependent scaling once
	local zoomScale = math.max(0.5, zoom / 70)
	local wcx_cached = wcx  -- Cache these for loop
	local wcz_cached = wcz

	-- Cache world boundaries for culling
	local worldLeft = world.l
	local worldRight = world.r
	local worldTop = world.t
	local worldBottom = world.b

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
					gl.LineWidth(segOuterWidth)
					glColor(beam.r, beam.g, beam.b, alpha * 0.4 * avgBrightness)
					glBeginEnd(GL_LINES, function()
						glVertex(seg1.x - wcx_cached, wcz_cached - seg1.z, 0)
						glVertex(seg2.x - wcx_cached, wcz_cached - seg2.z, 0)
					end)

					-- Draw inner core (thinner, brighter, whiter)
					gl.LineWidth(segInnerWidth)
					-- Make lightning core very white with slight blue tint, scaled by brightness
					local coreR = 0.9 + beam.r * 0.1
					local coreG = 0.9 + beam.g * 0.1
					local coreB = 0.95 + beam.b * 0.05
					glColor(coreR, coreG, coreB, alpha * 0.98 * avgBrightness)
					glBeginEnd(GL_LINES, function()
						glVertex(seg1.x - wcx_cached, wcz_cached - seg1.z, 0)
						glVertex(seg2.x - wcx_cached, wcz_cached - seg2.z, 0)
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
				gl.LineWidth(outerWidth)
				glColor(beam.r, beam.g, beam.b, alpha * 0.3)
				glBeginEnd(GL_LINES, function()
					glVertex(ox, oz, 0)
					glVertex(tx, tz, 0)
				end)

				-- Draw inner core (thinner, brighter, whiter)
				gl.LineWidth(innerWidth)
				-- Blend weapon color with white for brighter core
				local whiteness = 0.5 + (beam.thickness / 16) * 0.3  -- 0.5 to 0.8 based on thickness
				local coreR = beam.r * (1 - whiteness) + whiteness
				local coreG = beam.g * (1 - whiteness) + whiteness
				local coreB = beam.b * (1 - whiteness) + whiteness
				glColor(coreR, coreG, coreB, alpha * 0.95)
				glBeginEnd(GL_LINES, function()
					glVertex(ox, oz, 0)
					glVertex(tx, tz, 0)
				end)
			end

				i = i + 1
			end
		end
	end

	-- Reset line width once at the end
	gl.LineWidth(1)
end

local function DrawIconShatters()
	if #cache.iconShatters == 0 then return end

	local wcx_cached = wcx
	local wcz_cached = wcz

	gl.Blending(true)
	gl.DepthTest(false)

	-- Cache math functions for better performance
	local floor = math.floor

	-- Cache world boundaries for culling
	local worldLeft = world.l
	local worldRight = world.r
	local worldTop = world.t
	local worldBottom = world.b

	-- Reuse pooled table to minimize allocations
	local fragmentsByTexture = fragmentsByTexturePool

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
				-- Update fragment position with deceleration that increases towards end
				frag.x = frag.x + frag.vx * decel * 0.016
				frag.z = frag.z + frag.vz * decel * 0.016
				frag.vx = frag.vx * velocityDamping
				frag.vz = frag.vz * velocityDamping
				frag.rot = frag.rot + frag.rotSpeed * decel

				-- Calculate current size with scale, compensating for the glScale(zoom) in the matrix
				local currentSize = frag.size * scale * zoomInv
				local halfSize = currentSize * 0.5

				-- Add to batch for this texture (use counter instead of #texGroup)
				texGroupSize = texGroupSize + 1
				texGroup[texGroupSize] = {
					x = frag.x,
					z = frag.z,
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
		glTexture(bitmap)
		local fragCount = #frags
		for i = 1, fragCount do
			local frag = frags[i]
			glPushMatrix()
				glTranslate(frag.x, frag.z, 0)
				glRotate(frag.rot, 0, 0, 1)
				glColor(frag.r, frag.g, frag.b, 1.0)
				local hs = frag.halfSize
				-- Draw quad with proper texture coordinate mapping
				glBeginEnd(GL_QUADS, function()
					glTexCoord(frag.uvx1, frag.uvy2)
					glVertex(-hs, -hs, 0)
					glTexCoord(frag.uvx2, frag.uvy2)
					glVertex(hs, -hs, 0)
					glTexCoord(frag.uvx2, frag.uvy1)
					glVertex(hs, hs, 0)
					glTexCoord(frag.uvx1, frag.uvy1)
					glVertex(-hs, hs, 0)
				end)
			glPopMatrix()
		end
	end
	glTexture(false)

	gl.Blending(false)
	gl.DepthTest(true)
end

local function DrawExplosions()
	if #cache.explosions == 0 then return end

	local i = 1
	local wcx_cached = wcx
	local wcz_cached = wcz

	local rad2deg = 57.29577951308232 -- Precompute radians to degrees conversion

	-- Cache world boundaries for culling
	local worldLeft = world.l
	local worldRight = world.r
	local worldTop = world.t
	local worldBottom = world.b

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
				local progress = age / lifetime -- 0 to 1

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

					glPushMatrix()
					glTranslate(explosion.x - wcx_cached, wcz_cached - explosion.z, 0)

					-- Draw bright outer glow first (bigger)
					local glowAlpha = alpha * 0.5
					local glowRadius = baseRadius * 1.8 -- Much bigger glow


					for j = 0, segments - 1 do
						local angle1 = j * angleStep
						local angle2 = (j + 1) * angleStep

						glBeginEnd(GL_TRIANGLES, function()
							-- Center vertex
							glColor(r * 0.7, g * 0.7, b * 0.8, glowAlpha)
							glVertex(0, 0, 0)

							-- Edge vertices (fade out)
							glColor(r * 0.4, g * 0.4, b * 0.5, 0)
							glVertex(math.cos(angle1) * glowRadius, math.sin(angle1) * glowRadius, 0)
							glVertex(math.cos(angle2) * glowRadius, math.sin(angle2) * glowRadius, 0)
						end)
					end

					-- Draw main flash with brighter core
					local coreAlpha = alpha * 0.95 -- Much brighter
					local edgeAlpha = alpha * 0.5
					local coreRadius = baseRadius * 0.4 -- Smaller tight core

					for j = 0, segments - 1 do
						local angle1 = j * angleStep
						local angle2 = (j + 1) * angleStep

						glBeginEnd(GL_TRIANGLES, function()
							-- Center vertex (very bright white-blue)
							glColor(1, 1, 1, coreAlpha) -- Pure white core
							glVertex(0, 0, 0)

							-- Edge vertices (fade to electric blue)
							glColor(r * 0.8, g * 0.8, b, edgeAlpha)
							glVertex(math.cos(angle1) * coreRadius, math.sin(angle1) * coreRadius, 0)

							glColor(r * 0.8, g * 0.8, b, edgeAlpha)
							glVertex(math.cos(angle2) * coreRadius, math.sin(angle2) * coreRadius, 0)
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

							gl.LineWidth(math.max(1, particle.size * 0.8))
							glColor(r, g, b, sparkAlpha)
							glBeginEnd(GL_LINES, function()
								glVertex(particle.x - sparkDirX, particle.z - sparkDirZ, 0)
								glVertex(particle.x + sparkDirX, particle.z + sparkDirZ, 0)
							end)
						end
					end

					glPopMatrix()
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
					if explosion.radius > 150 then
						-- Massive explosions (nukes): bright white-yellow
						r, g, b = 1, 1, 0.8
					elseif explosion.radius > 80 then
						-- Large explosions: orange-yellow
						r, g, b = 1, 0.7, 0.2
					else
						-- Normal explosions: yellow to orange
						r, g, b = 1, 0.8 - (explosion.radius / 200), 0
					end

					glPushMatrix()
					glTranslate(explosion.x - wcx_cached, wcz_cached - explosion.z, 0)

					-- Apply rotation (use precalculated rad2deg)
					--local rotation = explosion.rotationSpeed * age * rad2deg
					--glRotate(rotation, 0, 0, 1)

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
						local ringAlpha = (1 - ringProgress) * alpha * 0.8
						local ringRadius = baseRadius * (0.8 + ringProgress * 0.4)
						glColor(r, g, b, ringAlpha)
						-- Thicker lines for bigger explosions
						local lineWidth = 4
						if explosion.radius > 150 then
							lineWidth = 6
						elseif explosion.radius > 80 then
							lineWidth = 5
						end
						gl.LineWidth(lineWidth)
						glBeginEnd(GL_LINE_LOOP, function()
							for j = 0, segments do
								local angle = j * angleStep
								glVertex(math.cos(angle) * ringRadius, math.sin(angle) * ringRadius, 0)
							end
						end)
					end

					-- Add extra bright flash for massive explosions at the start
					if explosion.radius > 150 and progress < 0.25 then -- Longer duration (was 0.15)
						local flashAlpha = (1 - progress / 0.25) * alpha -- Full opacity flash
						glColor(1, 1, 1, flashAlpha)
						local flashRadius = baseRadius * 0.7 -- Even larger (was 0.5)
						glBeginEnd(GL_TRIANGLE_FAN, function()
							glVertex(0, 0, 0)
							for j = 0, segments do
								local angle = j * angleStep
								glVertex(math.cos(angle) * flashRadius, math.sin(angle) * flashRadius, 0)
							end
						end)
					end

					glPopMatrix()
				end
				i = i + 1
			end
		end
	end
	gl.LineWidth(1)
end

local function GetUnitAtPoint(wx, wz)
	-- Calculate click radius based on current zoom
	-- At high zoom (3D models), use a fixed tight radius; at low zoom, use distMult for easier clicking
	local clickRadius
	if zoom > 0.9 then
		-- High zoom: use a fixed small radius that doesn't scale with zoom
		clickRadius = iconRadius * 0.4
	else
		-- Low zoom: use distMult for easier clicking on small icons
		local distMult = math.min(math.max(1, 2.2-(zoom*3.3)), 3)
		clickRadius = iconRadius * zoom * distMult * 0.8
	end

	local factoryID
	-- Iterate backwards to respect draw order (units drawn last are on top)
	for i = #pipUnits, 1, -1 do
		local uID = pipUnits[i]
		local ux, uy, uz = spGetUnitPosition(uID)
		if ux then
			local uDefID = spGetUnitDefID(uID)
			local dx, dz = ux - wx, uz - wz

			-- Use the calculated click radius or unit radius, whichever is larger
			local unitClickRadius = clickRadius
			if cache.unitIcon[uDefID] then
				-- If unit has a custom icon, scale the click radius by its size
				unitClickRadius = clickRadius * cache.unitIcon[uDefID].size
			end

			-- Also consider the actual unit radius, use whichever is larger for easier clicking
			local unitRadiusSq = cache.radiusSqs[uDefID] or (iconRadius*iconRadius)
			local clickRadiusSq = math.max(unitClickRadius * unitClickRadius, unitRadiusSq)

			if dx*dx + dz*dz < clickRadiusSq then
				if cache.isFactory[uDefID] then
					-- Factories have lower priority, remember but keep searching
					if not factoryID then
						factoryID = uID
					end
				else
					-- Non-factory unit found, return immediately (it's on top)
					return uID
				end
			end
		end
	end
	return factoryID
end

local function GetFeatureAtPoint(wx, wz)
	for i = 1, #pipFeatures do
		local fID = pipFeatures[i]
		local fx, fy, fz = spGetFeaturePosition(fID)
		if fx then
			local dx, dz = fx - wx, fz - wz
			if dx*dx + dz*dz < cache.featureRadiusSqs[spGetFeatureDefID(fID)] then
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
	local unitsInRect = spGetUnitsInRectangle(minWx, minWz, maxWx, maxWz)

	-- Reuse pool table to avoid allocations
	local selectableUnits = selectableUnitsPool
	local count = 0

	for i = 1, #unitsInRect do
		local uID = unitsInRect[i]
		local ux, uy, uz = spGetUnitPosition(uID)
		if ux then
			-- Check if unit is within the actual world bounds visible in PIP
			if ux >= world.l and ux <= world.r and uz >= world.t and uz <= world.b then
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
	local uCmds = Spring.GetUnitCommands(uID, 50)
	if not uCmds or #uCmds == 0 then return end
	local ux, uy, uz = spGetUnitPosition(uID)
	local px, pz = WorldToPipCoords(ux, uz)
	for i = 1, #uCmds do
		local cmd = uCmds[i]
		if (cmd.id < 0) or positionCmds[cmd.id] then
			local cx, cy, cz
			if #cmd.params >= 3 then
				cx, cy, cz = cmd.params[1], cmd.params[2], cmd.params[3]
			elseif #cmd.params == 1 then
				if cmd.params[1] > Game.maxUnits then
					cx, cy, cz = spGetFeaturePosition(cmd.params[1] - Game.maxUnits)
				else
					cx, cy, cz = spGetUnitPosition(cmd.params[1])
				end
			end
			if cx then
				local nx, nz = WorldToPipCoords(cx, cz)
				glColor(cmdColors[cmd.id] or cmdColors.unknown)
				glVertex(px, pz)
				glVertex(nx, nz)
				px, pz = nx, nz
			end
		end
	end
end

local function GetCmdOpts(alt, ctrl, meta, shift, right)

	local opts = { alt=alt, ctrl=ctrl, meta=meta, shift=shift, right=right }
	local coded = 0

	if alt   then coded = coded + CMD.OPT_ALT   end
	if ctrl  then coded = coded + CMD.OPT_CTRL  end
	if meta  then coded = coded + CMD.OPT_META  end
	if shift then coded = coded + CMD.OPT_SHIFT end
	if right then coded = coded + CMD.OPT_RIGHT end

	opts.coded = coded
	return opts
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
		local unitDefID = Spring.GetUnitDefID(unitID)
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
	local positions = {}
	local buildFacing = Spring.GetBuildFacing()
	local buildWidth, buildHeight = GetBuildingDimensions(buildDefID, buildFacing)

	-- Snap ONLY the start position - this becomes our anchor
	local sx, sy, sz = Spring.Pos2BuildPos(buildDefID, startWX, Spring.GetGroundHeight(startWX, startWZ), startWZ)

	-- For end position, snap it too to know the intended area
	local ex, ey, ez = Spring.Pos2BuildPos(buildDefID, endWX, Spring.GetGroundHeight(endWX, endWZ), endWZ)

	-- Calculate direction and distance
	local dx = ex - sx
	local dz = ez - sz
	local distance = math.sqrt(dx * dx + dz * dz)

	if distance < 1 then
		-- Too short, just return start position
		return {{wx = sx, wz = sz}}
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
			local snappedX, _, snappedZ = Spring.Pos2BuildPos(buildDefID, testX, Spring.GetGroundHeight(testX, testZ), testZ)

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
				local snappedX, _, snappedZ = Spring.Pos2BuildPos(buildDefID, wx, Spring.GetGroundHeight(wx, wz), wz)

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
					local snappedX, _, snappedZ = Spring.Pos2BuildPos(buildDefID, wx, Spring.GetGroundHeight(wx, wz), wz)

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

local function IssueCommandAtPoint(cmdID, wx, wz, usingRMB, forceQueue)

	local alt, ctrl, meta, shift = Spring.GetModKeyState()
	-- Force queue commands when explicitly requested (e.g., during formation drags)
	if forceQueue then
		shift = true
	end
	local cmdOpts = GetCmdOpts(alt, ctrl, meta, shift, usingRMB)

	-- For build commands (negative cmdID), don't check for units at the position
	-- We want to build AT the position, not command any unit that might be there
	local id = nil
	if cmdID > 0 then
		id = GetIDAtPoint(wx, wz)
	end

	if id then
		GiveNotifyingOrder(cmdID, {id}, cmdOpts)
	else
		if cmdID > 0 then
			GiveNotifyingOrder(cmdID, {wx, spGetGroundHeight(wx, wz), wz}, cmdOpts)
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
						local pos = {wx, spGetGroundHeight(wx, wz), wz}
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
			GiveNotifyingOrder(cmdID, {wx, spGetGroundHeight(wx, wz), wz, Spring.GetBuildFacing()}, cmdOpts)
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Callins
----------------------------------------------------------------------------------------------------

function widget:Initialize()

	unitOutlineList = gl.CreateList(function()
			gl.BeginEnd(GL.LINE_LOOP, function()
				gl.Vertex( 1, 0, 1)
				gl.Vertex( 1, 0,-1)
				gl.Vertex(-1, 0,-1)
				gl.Vertex(-1, 0, 1)
			end)
		end)

	radarDotList = gl.CreateList(function()
			glTexture('LuaUI/Images/pip/PipBlip.png')
			glBeginEnd(GL_QUADS, function()
				glVertex( iconRadius, iconRadius)
				glVertex( iconRadius,-iconRadius)
				glVertex(-iconRadius,-iconRadius)
				glVertex(-iconRadius, iconRadius)
			end)
			glTexture(false)
		end)

	unitShader = gl.CreateShader({
			fragment = [[
				uniform sampler2D unitTex;
				void main(void) {
					gl_FragData[0]     = texture2D(unitTex, gl_TexCoord[0].st);
					gl_FragData[0].rgb = mix(gl_FragData[0].rgb, gl_Color.rgb, gl_FragData[0].a);
					gl_FragData[0].a   = gl_FragCoord.z;
				}
			]],
		})

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
	end

	for fDefID, fDef in pairs(FeatureDefs) do
		if fDef.modelname == '' then
			cache.noModelFeatures[fDefID] = true
		end
		local fx, fz = 8 * fDef.xsize, 8 * fDef.zsize
		cache.featureRadiusSqs[fDefID] = fx*fx + fz*fz
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
	end

	gameHasStarted = (Spring.GetGameFrame() > 0)
	startX, _, startZ = Spring.GetTeamStartPosition(Spring.GetMyTeamID())
	-- Only set camera position if not already loaded from config
	if (not wcx or not wcz) and startX and startX >= 0 then
		wcx, wcz = startX, startZ
		targetWcx, targetWcz = wcx, wcz  -- Initialize targets
	end

	-- Minimize PIP before game starts (only on fresh start, not on reload)
	if not gameHasStarted and not inMinMode and not hadSavedConfig then
		inMinMode = true
		-- Store current dimensions before minimizing
		savedDimensions = {
			l = dim.l,
			r = dim.r,
			b = dim.b,
			t = dim.t
		}
	end

	widget:ViewResize()

	-- Create API for other widgets
	WG['guiPip'] = {}
	WG['guiPip'].IsAbove = function(mx, my)
		return widget:IsAbove(mx, my)
	end
	WG['guiPip'].ForceUpdate = function()
		pipR2T.contentNeedsUpdate = true
	end
	WG['guiPip'].SetUpdateRate = function(fps)
		pipUpdateRate = fps
		pipUpdateInterval = pipUpdateRate > 0 and (1 / pipUpdateRate) or 0
	end
	WG['guiPip'].GetUpdateRate = function()
		return pipUpdateRate
	end

	for i = 1, #buttons do
		local button = buttons[i]
		if button.command then
			widgetHandler.actionHandler:AddAction(self, button.command, button.OnPress, nil, 't')
		end
	end

	-- Register guishader blur for PIP background
	UpdateGuishaderBlur()
end

function widget:ViewResize()

	font = WG['fonts'].getFont(2)

	local oldVsx, oldVsy = vsx, vsy
	-- Ensure dim fields are initialized before arithmetic operations
	if dim.l and dim.r and dim.b and dim.t then
		dim.l, dim.r, dim.b, dim.t = dim.l/oldVsx, dim.r/oldVsx, dim.b/oldVsy, dim.t/oldVsy
	else
		-- Initialize with default values if not set
		dim.l = 0.7
		dim.r = 0.7 + (minPanelSize * widgetScale * 1.4) / oldVsx
		dim.b = 0.7
		dim.t = 0.7 + (minPanelSize * widgetScale * 1.2) / oldVsy
	end
	vsx, vsy = Spring.GetViewGeometry()
	dim.l, dim.r, dim.b, dim.t = math.floor(dim.l*vsx), math.floor(dim.r*vsx), math.floor(dim.b*vsy), math.floor(dim.t*vsy)

	widgetScale = (vsy / 2000) * uiScale
	usedButtonSize = math.floor(buttonSize * widgetScale * uiScale)

	elementPadding = WG.FlowUI.elementPadding
	elementCorner = WG.FlowUI.elementCorner
	RectRound = WG.FlowUI.Draw.RectRound
	UiElement = WG.FlowUI.Draw.Element
	elementMargin = WG.FlowUI.elementMargin

	-- Invalidate display lists on resize
	if minModeDlist then
		gl.DeleteList(minModeDlist)
		minModeDlist = nil
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
	-- Only recalculate if not in min mode (preserve saved position when restoring from config)
	-- But always initialize if nil to prevent errors
	if not inMinMode or minModeL == nil or minModeB == nil then
		local screenMarginPx = math.floor(screenMargin * vsy)
		local buttonSizeWithMargin = math.floor(usedButtonSize * maximizeSizemult)
		minModeL = vsx - buttonSizeWithMargin - screenMarginPx
		minModeB = vsy - buttonSizeWithMargin - screenMarginPx
	end

	-- If we're in min mode, ensure window is positioned at the minimize button location
	if inMinMode then
		dim.l = minModeL
		dim.r = minModeL + math.floor(usedButtonSize * maximizeSizemult)
		dim.b = minModeB
		dim.t = minModeB + math.floor(usedButtonSize * maximizeSizemult)
	else
		-- Only correct screen position when not in min mode
		CorrectScreenPosition()
	end

	-- Clamp camera position to respect margin after view resize
	local pipWidth = dim.r - dim.l
	local pipHeight = dim.t - dim.b
	local visibleWorldWidth = pipWidth / zoom
	local visibleWorldHeight = pipHeight / zoom
	local smallerVisibleDimension = math.min(visibleWorldWidth, visibleWorldHeight)
	local margin = smallerVisibleDimension * mapEdgeMargin

	local minWcx = visibleWorldWidth / 2 - margin
	local maxWcx = mapSizeX - (visibleWorldWidth / 2 - margin)
	local minWcz = visibleWorldHeight / 2 - margin
	local maxWcz = mapSizeZ - (visibleWorldHeight / 2 - margin)

	wcx = math.min(math.max(wcx, minWcx), maxWcx)
	wcz = math.min(math.max(wcz, minWcz), maxWcz)
	targetWcx = wcx
	targetWcz = wcz

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

function widget:Shutdown()
	gl.DeleteShader(unitShader)
	gl.DeleteList(unitOutlineList)
	gl.DeleteList(radarDotList)

	-- Clean up render-to-texture
	if pipR2T.contentTex then
		gl.DeleteTexture(pipR2T.contentTex)
		pipR2T.contentTex = nil
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

	-- Clean up minimize mode display list
	if minModeDlist then
		gl.DeleteList(minModeDlist)
		minModeDlist = nil
	end

	-- Remove guishader blur
	if WG['guishader'] and WG['guishader'].RemoveRect then
		WG['guishader'].RemoveRect('pip'..pipNumber)
	end

	-- Clean up API
	WG['guiPip'] = nil

	for i = 1, #buttons do
		local button = buttons[i]
		if button.command then
			widgetHandler.actionHandler:RemoveAction(self, button.command)
		end
	end
end

function widget:GetConfigData()
	CorrectScreenPosition()

	-- When in min mode, save the expanded dimensions from savedDimensions
	local saveL, saveR, saveB, saveT
	if inMinMode and savedDimensions.l then
		saveL = savedDimensions.l / vsx
		saveR = savedDimensions.r / vsx
		saveB = savedDimensions.b / vsy
		saveT = savedDimensions.t / vsy
	else
		saveL = dim.l / vsx
		saveR = dim.r / vsx
		saveB = dim.b / vsy
		saveT = dim.t / vsy
	end

	return {
			pl=saveL, pr=saveR, pb=saveB, pt=saveT,
			zoom=zoom,
			wcx=wcx,
			wcz=wcz,
			inMinMode=inMinMode,
			minModeL=minModeL,
			minModeB=minModeB,
			drawingGround=drawingGround,
			drawProjectiles=drawProjectiles,
			areTracking=interactionState.areTracking,
			trackingSmoothness=trackingSmoothness,
			gameID = Game.gameID and Game.gameID or Spring.GetGameRulesParam("GameID"),
		}
end

function widget:SetConfigData(data)
	--Spring.Echo(data)
	hadSavedConfig = (data and next(data) ~= nil) -- Mark that we have saved config data
	inMinMode = data.inMinMode or inMinMode
	minModeL = data.minModeL or minModeL
	minModeB = data.minModeB or minModeB

	-- If restoring in min mode, set dimensions to the saved minimize button position immediately
	if inMinMode and minModeL and minModeB then
		-- Calculate the button size using saved values (this is approximate until ViewResize recalculates)
		local buttonSizeEstimate = vsx - minModeL
		dim.l = minModeL
		dim.r = minModeL + buttonSizeEstimate
		dim.b = minModeB
		dim.t = minModeB + buttonSizeEstimate

		-- Also populate savedDimensions from the saved percentages so maximize works
		if data.pl and data.pr and data.pb and data.pt then
			savedDimensions = {
				l = math.floor(data.pl*vsx),
				r = math.floor(data.pr*vsx),
				b = math.floor(data.pb*vsy),
				t = math.floor(data.pt*vsy)
			}
		end
	elseif data.pl and data.pr and data.pb and data.pt then
		-- Restore normal dimensions from saved percentages
		dim.l = math.floor(data.pl*vsx)
		dim.r = math.floor(data.pr*vsx)
		dim.b = math.floor(data.pb*vsy)
		dim.t = math.floor(data.pt*vsy)
		CorrectScreenPosition()
	end
	-- If no valid saved data, keep existing dim values (initialized at top of file)

	wcx = data.wcx or wcx
	wcz = data.wcz or wcz
	targetWcx, targetWcz = wcx, wcz  -- Initialize targets from config
	drawingGround = data.drawingGround~= nil and data.drawingGround or drawingGround
	drawProjectiles = data.drawProjectiles~= nil and data.drawProjectiles or drawProjectiles
	trackingSmoothness = data.trackingSmoothness or trackingSmoothness
	if Spring.GetGameFrame() > 0 or (data.gameID and data.gameID == (Game.gameID and Game.gameID or Spring.GetGameRulesParam("GameID"))) then
		interactionState.areTracking = data.areTracking
		zoom = data.zoom or zoom
	end
	targetZoom = zoom
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
	local dotSize = math.floor(vsy * 0.0085)

	local function DrawScreenDot(sx, sy)
		glColor(r, g, b, 1)
		glTexture("LuaUI/Images/formationDot.dds")
		glTexRect(sx - dotSize, sy - dotSize, sx + dotSize, sy + dotSize)
	end

	-- Draw first dot
	local sx, sy = WorldToPipCoords(formationNodes[1][1], formationNodes[1][3])
	if sx >= dim.l and sx <= dim.r and sy >= dim.b and sy <= dim.t then
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
				if sx >= dim.l and sx <= dim.r and sy >= dim.b and sy <= dim.t then
					DrawScreenDot(sx, sy)
				end

				lengthUnitNext = lengthUnitNext + lengthPerUnit
			end
			currentLength = currentLength + length
		end
	end

	-- Draw last dot
	sx, sy = WorldToPipCoords(formationNodes[#formationNodes][1], formationNodes[#formationNodes][3])
	if sx >= dim.l and sx <= dim.r and sy >= dim.b and sy <= dim.t then
		DrawScreenDot(sx, sy)
	end

	glTexture(false)
end

-- Helper function to draw command queues overlay
local function DrawCommandQueuesOverlay()
	-- Check if Shift+Space (meta) is held to show all visible units
	local alt, ctrl, meta, shift = Spring.GetModKeyState()
	local showAllUnits = shift and meta

	-- Reuse pool table instead of allocating new one
	local unitsToShow = unitsToShowPool
	local unitCount = 0

	if showAllUnits then
		-- Show command queues for all visible units in PIP window
		if pipUnits then
			local pUnitCount = #pipUnits
			for i = 1, pUnitCount do
				unitCount = unitCount + 1
				unitsToShow[unitCount] = pipUnits[i]
			end
		end
	else
		-- Show only selected units
		local selectedUnits = Spring.GetSelectedUnits()
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

	gl.Scissor(dim.l, dim.b, dim.r - dim.l, dim.t - dim.b)
	gl.LineWidth(1.0)
	gl.LineStipple("springdefault")

	-- Cache Spring API functions for the loop
	local GetUnitPosition = Spring.GetUnitPosition
	local GetUnitCommands = Spring.GetUnitCommands

	-- Collect all line segments and markers into batches (massively reduces closure allocations)
	local linePool = commandLinePool
	local markerPool = commandMarkerPool
	local lineCount = 0
	local markerCount = 0

	for i = 1, unitCount do
		local uID = unitsToShow[i]
		local ux, uy, uz = GetUnitPosition(uID)
		if ux then
			local startSX, startSY = WorldToPipCoords(ux, uz)
			local commands = GetUnitCommands(uID, 30)

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
							if paramCount >= 3 then
								cmdX, cmdZ = params[1], params[3]
							elseif paramCount == 1 then
								local targetID = params[1]
								local tx, ty, tz = GetUnitPosition(targetID)
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

	-- Draw all lines in ONE glBeginEnd call (massive performance improvement)
	if lineCount > 0 then
		gl.BeginEnd(GL.LINES, function()
			for i = 1, lineCount do
				local line = linePool[i]
				gl.Color(line.r, line.g, line.b, 0.8)
				gl.Vertex(line.x1, line.y1)
				gl.Vertex(line.x2, line.y2)
			end
		end)
	end

	-- Draw all markers in ONE glBeginEnd call
	if markerCount > 0 then
		gl.BeginEnd(GL.QUADS, function()
			for i = 1, markerCount do
				local marker = markerPool[i]
				gl.Color(marker.r, marker.g, marker.b, 0.8)
				local x, y = marker.x, marker.y
				gl.Vertex(x - 3, y - 3)
				gl.Vertex(x + 3, y - 3)
				gl.Vertex(x + 3, y + 3)
				gl.Vertex(x - 3, y + 3)
			end
		end)
	end

	-- Clear leftover entries in pools
	for i = unitCount + 1, #unitsToShow do
		unitsToShow[i] = nil
	end

	gl.LineStipple(false)
	gl.LineWidth(1.0)
	gl.Scissor(false)
end

-- Helper function to draw build preview for cursor
local function DrawBuildPreview(mx, my, iconRadiusZoomDistMult)
	if mx < dim.l or mx > dim.r or my < dim.b or my > dim.t then
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
			glColor(1, 1, 0, 0.3)
			gl.LineWidth(2)
			glBeginEnd(GL_LINE_LOOP, function()
				for i = 0, segments do
					local angle = (i / segments) * 2 * math.pi
					local x = wx + radius * math.cos(angle)
					local z = wz + radius * math.sin(angle)
					local cx, cy = WorldToPipCoords(x, z)
					glVertex(cx, cy)
				end
			end)
			gl.LineWidth(1)

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
								glColor(1, 1, 1, 0.3)
								glTexture(buildIcon.bitmap)
								glTexRect(cx - iconSize, cy - iconSize, cx + iconSize, cy + iconSize)
							end
						end
						glTexture(false)
					end
				end
			end
		end
	-- Handle regular build command preview
	elseif activeCmdID and activeCmdID < 0 and not interactionState.areBuildDragging then
		local buildDefID = -activeCmdID
		local wx, wz = PipToWorldCoords(mx, my)
		local wy = spGetGroundHeight(wx, wz)

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
				glColor(1, 1, 1, 0.5)
			elseif canBuild == 1 then
				local blockedByMobile = false
				local nearbyUnits = Spring.GetUnitsInCylinder(wx, wz, 64)
				if nearbyUnits then
					for _, unitID in ipairs(nearbyUnits) do
						local unitDefID = Spring.GetUnitDefID(unitID)
						if unitDefID then
							local unitDef = UnitDefs[unitDefID]
							if unitDef and unitDef.canMove and not unitDef.isBuilding then
								blockedByMobile = true
								break
							end
						end
					end
				end

				if blockedByMobile then
					glColor(1, 1, 1, 0.5)
				else
					glColor(1, 1, 0, 0.5)
				end
			else
				glColor(1, 0, 0, 0.5)
			end

			glTexture(buildIcon.bitmap)

			if rotation ~= 0 then
				glPushMatrix()
				glTranslate(cx, cy, 0)
				glRotate(rotation, 0, 0, 1)
				glTexRect(-iconSize, -iconSize, iconSize, iconSize)
				glPopMatrix()
			else
				glTexRect(cx - iconSize, cy - iconSize, cx + iconSize, cy + iconSize)
			end

			glTexture(false)
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

	glTexture(buildIcon.bitmap)

	for i = 1, #interactionState.buildDragPositions do
		local pos = interactionState.buildDragPositions[i]
		local cx, cy = WorldToPipCoords(pos.wx, pos.wz)
		local canBuild = Spring.TestBuildOrder(buildDefID, pos.wx, Spring.GetGroundHeight(pos.wx, pos.wz), pos.wz, buildFacing)
		local alpha = math.max(0.3, 0.6 - (i - 1) * 0.05)

		if canBuild == 2 then
			glColor(1, 1, 1, alpha)
		elseif canBuild == 1 then
			local blockedByMobile = false
			local nearbyUnits = Spring.GetUnitsInCylinder(pos.wx, pos.wz, 64)
			if nearbyUnits then
				for _, unitID in ipairs(nearbyUnits) do
					local unitDefID = Spring.GetUnitDefID(unitID)
					if unitDefID then
						local unitDef = UnitDefs[unitDefID]
						if unitDef and unitDef.canMove and not unitDef.isBuilding then
							blockedByMobile = true
							break
						end
					end
				end
			end

			if blockedByMobile then
				glColor(1, 1, 1, alpha)
			else
				glColor(1, 1, 0, alpha)
			end
		else
			glColor(1, 0, 0, alpha)
		end

		if rotation ~= 0 then
			glPushMatrix()
			glTranslate(cx, cy, 0)
			glRotate(rotation, 0, 0, 1)
			glTexRect(-iconSize, -iconSize, iconSize, iconSize)
			glPopMatrix()
		else
			glTexRect(cx - iconSize, cy - iconSize, cx + iconSize, cy + iconSize)
		end
	end

	glTexture(false)
end

-- Helper function to draw queued building ghosts
local function DrawQueuedBuilds(iconRadiusZoomDistMult)
	local selectedUnits = Spring.GetSelectedUnits()
	local selectedCount = selectedUnits and #selectedUnits or 0
	if selectedCount == 0 then
		return
	end

	local buildsByTexture = {}
	local buildCountByTexture = {}

	for i = 1, selectedCount do
		local unitID = selectedUnits[i]
		local queue = Spring.GetCommandQueue(unitID, -1)

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

							if bwx >= world.l and bwx <= world.r and bwz >= world.t and bwz <= world.b then
								local cx, cy = WorldToPipCoords(bwx, bwz)
								local iconSize = iconRadiusZoomDistMult * buildIcon.size
								local buildFacing = paramCount >= 4 and cmd.params[4] or 0
								local rotation = buildFacing * 90

								local bitmap = buildIcon.bitmap
								local texBuilds = buildsByTexture[bitmap]
								local buildCount = buildCountByTexture[bitmap] or 0
								if not texBuilds then
									texBuilds = {}
									buildsByTexture[bitmap] = texBuilds
								end
								buildCount = buildCount + 1
								buildCountByTexture[bitmap] = buildCount
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

	glColor(0.5, 1, 0.5, 0.4)
	for bitmap, builds in pairs(buildsByTexture) do
		glTexture(bitmap)
		local buildCount = buildCountByTexture[bitmap]
		for i = 1, buildCount do
			local build = builds[i]
			local cx, cy, iconSize, rotation = build.cx, build.cy, build.iconSize, build.rotation

			if rotation ~= 0 then
				glPushMatrix()
				glTranslate(cx, cy, 0)
				glRotate(rotation, 0, 0, 1)
				glTexRect(-iconSize, -iconSize, iconSize, iconSize)
				glPopMatrix()
			else
				glTexRect(cx - iconSize, cy - iconSize, cx + iconSize, cy + iconSize)
			end
		end
	end
	glTexture(false)
end

-- Helper function to draw icons (when zoomed out)
local function DrawIcons()
	-- Batch icon drawing by texture to minimize state changes
	local distMult = math.min(math.max(1, 2.2-(zoom*3.3)), 3)
	local iconRadiusZoom = iconRadius * zoom
	local iconRadiusZoomDistMult = iconRadiusZoom * distMult

	-- Reuse pooled tables to avoid allocations every frame
	local iconsByTexture = iconsByTexturePool
	local defaultIconIndices = defaultIconIndicesPool

	-- Clear pool tables from previous frame and track sizes
	local textureSizes = {}
	for k in pairs(iconsByTexture) do
		local t = iconsByTexture[k]
		for i = #t, 1, -1 do
			t[i] = nil
		end
		textureSizes[k] = 0
	end
	local defaultCount = 0

	local iconCount = #pipIconTeam
	for i = 1, iconCount do
		local udef = pipIconUdef[i]
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
		else
			defaultCount = defaultCount + 1
			defaultIconIndices[defaultCount] = i
		end
	end

	-- Clear leftover default indices
	for i = defaultCount + 1, #defaultIconIndices do
		defaultIconIndices[i] = nil
	end

	-- Draw icons grouped by texture (minimizes texture binding)
	for texture, indices in pairs(iconsByTexture) do
		glTexture(texture)
		local indexCount = #indices
		for j = 1, indexCount do
			local i = indices[j]
			local cx = pipIconX[i]
			local cy = pipIconY[i]
			local udef = pipIconUdef[i]
			local iconSize = iconRadiusZoomDistMult * cache.unitIcon[udef].size

			if pipIconSelected[i] then
				glColor(1,1,1,1)
			else
				glColor(teamColors[pipIconTeam[i]])
			end
			glTexRect(cx - iconSize, cy - iconSize, cx + iconSize, cy + iconSize)
		end
	end

	-- Draw default icons (fallback radar blip texture for unknown unit types)
	if defaultCount > 0 then
		glTexture('LuaUI/Images/pip/PipBlip.png')
		local defaultIconSize = iconRadius * 0.5 * zoom * distMult
		for j = 1, defaultCount do
			local i = defaultIconIndices[j]
			local cx = pipIconX[i]
			local cy = pipIconY[i]

			if pipIconSelected[i] then
				glColor(1,1,1,1)
			else
				glColor(teamColors[pipIconTeam[i]])
			end
			glTexRect(cx - defaultIconSize, cy - defaultIconSize, cx + defaultIconSize, cy + defaultIconSize)
		end
	end

	glTexture(false)

	-- Return iconRadiusZoomDistMult for build preview functions
	return iconRadiusZoomDistMult
end

-- Helper function to draw units and features in PIP
local function DrawUnitsAndFeatures()

	-- Use larger margin for units and features to account for their radius
	-- Features especially can be quite large (up to ~200 units radius for big wrecks)
	local margin = 250
	pipUnits = spGetUnitsInRectangle(world.l - margin, world.t - margin, world.r + margin, world.b + margin)
	pipFeatures = spGetFeaturesInRectangle(world.l - margin, world.t - margin, world.r + margin, world.b + margin)

	-- Cache counts to avoid repeated length calculations
	local unitCount = #pipUnits
	local featureCount = #pipFeatures

	-- Clear icon arrays (faster than iterating and setting to nil)
	local iconCount = #pipIconTeam
	if iconCount > 0 then
		-- Truncate arrays to zero length (faster than nilifying each element)
		for i = iconCount, 1, -1 do
			pipIconTeam[i] = nil
			pipIconX[i] = nil
			pipIconY[i] = nil
			pipIconUdef[i] = nil
			pipIconSelected[i] = nil
		end
	end

	-- Note: cameraRotY is now set in DrawScreen before this function is called

	gl.DepthTest(true)
	gl.DepthMask(true)
	gl.Blending(false)
	gl.AlphaTest(false)

	gl.Scissor(dim.l, dim.b, dim.r - dim.l, dim.t - dim.b)
	gl.UseShader(unitShader)
	gl.LineWidth(2.0)

	-- Precompute center translation values (used by all drawing)
	local centerX = 0.5 * (dim.l + dim.r)
	local centerY = 0.5 * (dim.b + dim.t)

	-- Calculate content scale during minimize animation
	local contentScale = 1.0
	if isAnimating then
		-- During animation, scale content to fit within the shrinking window
		-- Only scale down during minimize (inMinMode = true), not during maximize
		if inMinMode then
			local currentWidth = dim.r - dim.l
			local currentHeight = dim.t - dim.b
			local startWidth = animStartDim.r - animStartDim.l
			local startHeight = animStartDim.t - animStartDim.b

			-- Use the smaller of width/height ratio to maintain aspect ratio
			local widthScale = currentWidth / startWidth
			local heightScale = currentHeight / startHeight
			contentScale = math.min(widthScale, heightScale)
		end
		-- When maximizing (inMinMode = false), keep contentScale = 1.0 to avoid oversized units
	end

	glPushMatrix()
		glTranslate(centerX, centerY, 0)
		glScale(zoom * contentScale, zoom * contentScale, zoom * contentScale)

		-- Draw units
		for i = 1, unitCount do
			DrawUnit(pipUnits[i])
		end

		glTexture(0, '$units')

		-- Draw features
		if zoom >= zoomFeatures then  -- Only draw features if zoom is above threshold
			for i = 1, featureCount do
				DrawFeature(pipFeatures[i])
			end
		end

		-- Draw projectiles if enabled
		if drawProjectiles then
			glTexture(0, false)
			gl.UseShader(0)
			gl.Blending(true)
			gl.DepthTest(false)

			-- Only draw expensive projectile details when zoomed in enough
			local drawProjectileDetail = zoom >= zoomProjectileDetail

			if zoom >= zoomProjectileDetail then
				-- Get projectiles in the PIP window's world rectangle
				local projectiles = spGetProjectilesInRectangle(world.l - margin, world.t - margin, world.r + margin, world.b + margin)
				if projectiles then
					local projectileCount = #projectiles
					for i = 1, projectileCount do
						DrawProjectile(projectiles[i])
					end
				end
			end

			if zoom >= zoomExplosionDetail then
				DrawExplosions()
			end

			if zoom >= zoomProjectileDetail then
				-- Draw icon shatters
				DrawIconShatters()

				-- Draw laser beams
				DrawLaserBeams()
			end

			gl.DepthTest(true)
			gl.Blending(false)
			gl.UseShader(unitShader)
		end

	glPopMatrix()


	glTexture(0, false)
	gl.UseShader(0)
	gl.Blending(true)
	gl.DepthMask(false)
	gl.DepthTest(false)

	local _, _, _, shift = Spring.GetModKeyState()
	if shift then
		gl.LineStipple("springdefault")
		local selUnits = Spring.GetSelectedUnits()
		local selCount = #selUnits
		for i = 1, selCount do
			glBeginEnd(GL_LINES, UnitQueueVertices, selUnits[i])
		end
		gl.LineStipple(false)
	end

	-- Draw icons (when zoomed out)
	local iconRadiusZoomDistMult = DrawIcons()

	-- Draw build previews
	local mx, my = spGetMouseState()
	DrawBuildPreview(mx, my, iconRadiusZoomDistMult)
	DrawBuildDragPreview(iconRadiusZoomDistMult)
	DrawQueuedBuilds(iconRadiusZoomDistMult)

	gl.LineWidth(1.0)
	gl.Scissor(false)
end

-- Helper function to render PIP frame background (static)
local function RenderFrameBackground()
	-- Render panel at origin without accounting for padding (padding drawn separately)
	local pipWidth = dim.r - dim.l
	local pipHeight = dim.t - dim.b
	glColor(0.6,0.6,0.6,0.6)
	RectRound(0, 0, pipWidth, pipHeight, elementCorner*0.4, 1, 1, 1, 1)
end

-- Helper function to render PIP frame buttons without hover effects
local function RenderFrameButtons()
	local usedButtonSizeLocal = usedButtonSize
	local pipWidth = dim.r - dim.l
	local pipHeight = dim.t - dim.b

	-- Resize handle (bottom-right corner)
	glColor(panelBorderColorDark)
	gl.LineWidth(1.0)
	glBeginEnd(GL_TRIANGLES, function()
		-- Relative coordinates for resize handle
		glVertex(pipWidth - usedButtonSizeLocal, 0)
		glVertex(pipWidth, 0)
		glVertex(pipWidth, usedButtonSizeLocal)
	end)

	-- Minimize button (top-right)
	glColor(panelBorderColorDark)
	glTexture(false)
	RectRound(pipWidth - usedButtonSizeLocal - elementPadding, pipHeight - usedButtonSizeLocal - elementPadding, pipWidth, pipHeight, elementCorner, 0, 0, 0, 1)
	glColor(panelBorderColorLight)
	glTexture('LuaUI/Images/pip/PipMinimize.png')
	glTexRect(pipWidth - usedButtonSizeLocal, pipHeight - usedButtonSizeLocal, pipWidth, pipHeight)
	glTexture(false)

	-- Bottom-left buttons
	local selectedUnits = Spring.GetSelectedUnits()
	local hasSelection = #selectedUnits > 0
	local isTracking = interactionState.areTracking ~= nil
	local visibleButtons = {}
	for i = 1, #buttons do
		if buttons[i].command ~= 'pip_track' or hasSelection or isTracking then
			visibleButtons[#visibleButtons + 1] = buttons[i]
		end
	end

	local buttonCount = #visibleButtons
	glColor(panelBorderColorDark)
	glTexture(false)
	RectRound(0, 0, (buttonCount * usedButtonSizeLocal) + math.floor(elementPadding*0.75), usedButtonSizeLocal + math.floor(elementPadding*0.75), elementCorner, 0, 1, 0, 0)

	local bx = 0
	for i = 1, buttonCount do
		if visibleButtons[i].command == 'pip_track' and interactionState.areTracking then
			glColor(panelBorderColorLight)
			glTexture(false)
			RectRound(bx, 0, bx + usedButtonSizeLocal, usedButtonSizeLocal, elementCorner*0.4, 1, 1, 1, 1)
			glColor(panelBorderColorDark)
		else
			glColor(panelBorderColorLight)
		end
		glTexture(visibleButtons[i].texture)
		glTexRect(bx, 0, bx + usedButtonSizeLocal, usedButtonSizeLocal)
		bx = bx + usedButtonSizeLocal
	end
	glTexture(false)
end

-- Helper function to render PIP contents (units, features, ground, command queues)
local function RenderPipContents()
	if drawingGround then
		glColor(0.9, 0.9, 0.9, 1)
		glTexture('$grass')
		glBeginEnd(GL_QUADS, GroundTextureVertices)
		glTexture(false)
	end

	-- Measure draw time for performance monitoring
	local drawStartTime = os.clock()
	DrawUnitsAndFeatures()
	pipR2T.contentLastDrawTime = os.clock() - drawStartTime

	DrawCommandQueuesOverlay()
end

-- Helper function to draw UI buttons and controls
local function DrawUIButtons(mx, my, mbl)
	local hover = areResizing or false
	if mx >= dim.l and mx <= dim.r and my >= dim.b and my <= dim.t then
		if (dim.r-mx + my-dim.b <= usedButtonSize) then
			hover = true
			Spring.SetMouseCursor('cursornormal')
			if WG['tooltip'] then
				WG['tooltip'].ShowTooltip('pip'..pipNumber, Spring.I18N('ui.pip.resize'), nil, nil, nil)
			end
		end
	end
	local mult = mbl and 4.5 or 1.5
	-- Avoid table allocation in hot path
	if hover then
		glColor(panelBorderColorDark[1]*mult, panelBorderColorDark[2]*mult, panelBorderColorDark[3]*mult, 1)
	else
		glColor(panelBorderColorDark)
	end
	gl.LineWidth(1.0)
	glBeginEnd(GL_TRIANGLES, ResizeHandleVertices)

	-- Minimize button
	hover = false
	glColor(panelBorderColorDark)
	glTexture(false)
	RectRound(dim.r - usedButtonSize - elementPadding, dim.t - usedButtonSize - elementPadding, dim.r, dim.t, elementCorner, 0, 0, 0, 1)
	if mx >= dim.r - usedButtonSize - elementPadding and mx <= dim.r - elementPadding and
		my >= dim.t - usedButtonSize - elementPadding and my <= dim.t - elementPadding then
		hover = true
		Spring.SetMouseCursor('cursornormal')
		if WG['tooltip'] then
			WG['tooltip'].ShowTooltip('pip'..pipNumber, Spring.I18N('ui.pip.minimize'), nil, nil, nil)
		end
		glColor(1,1,1,0.12)
		glTexture(false)
		RectRound(dim.r - usedButtonSize, dim.t - usedButtonSize, dim.r, dim.t, elementCorner*0.4, 1, 1, 1, 1)
	end
	-- Avoid table allocation in hot path
	if hover then
		glColor(1, 1, 1, 1)
	else
		glColor(panelBorderColorLight)
	end
	glTexture('LuaUI/Images/pip/PipMinimize.png')
	glTexRect(dim.r - usedButtonSize, dim.t - usedButtonSize, dim.r, dim.t)

	-- Other buttons
	hover = false
	local bx = dim.l

	-- Calculate visible buttons (hide tracking button when no units selected and not tracking)
	local selectedUnits = Spring.GetSelectedUnits()
	local hasSelection = #selectedUnits > 0
	local isTracking = interactionState.areTracking ~= nil
	local visibleButtons = {}
	for i = 1, #buttons do
		if buttons[i].command ~= 'pip_track' or hasSelection or isTracking then
			visibleButtons[#visibleButtons + 1] = buttons[i]
		end
	end

	local buttonCount = #visibleButtons
	glColor(panelBorderColorDark)
	glTexture(false)
	RectRound(dim.l, dim.b, dim.l + (buttonCount * usedButtonSize) + math.floor(elementPadding*0.75), dim.b + usedButtonSize + math.floor(elementPadding*0.75), elementCorner, 0, 1, 0, 0)
	glColor(panelBorderColorLight)
	for i = 1, buttonCount do
		if mx >= bx and mx <= bx + usedButtonSize and
		   my >= dim.b and my <= dim.b + usedButtonSize then
			hover = true
			Spring.SetMouseCursor('cursornormal')
			if visibleButtons[i].tooltip and WG['tooltip'] then
				WG['tooltip'].ShowTooltip('pip'..pipNumber, visibleButtons[i].tooltip, nil, nil, nil)
			end
			glColor(1,1,1,0.12)
			glTexture(false)
			RectRound(bx, dim.b, bx + usedButtonSize, dim.b + usedButtonSize, elementCorner*0.4, 1, 1, 1, 1)
		end
		if visibleButtons[i].command == 'pip_track' and interactionState.areTracking then
			glColor(panelBorderColorLight)
			glTexture(false)
			RectRound(bx, dim.b, bx + usedButtonSize, dim.b + usedButtonSize, elementCorner*0.4, 1, 1, 1, 1)
			if hover then
				glColor(1, 1, 1, 1)
			else
				glColor(panelBorderColorDark)
			end
		else
			if hover then
				glColor(1, 1, 1, 1)
			else
				glColor(panelBorderColorLight)
			end
		end
		glTexture(visibleButtons[i].texture)
		glTexRect(bx, dim.b, bx + usedButtonSize, dim.b + usedButtonSize)
		bx = bx + usedButtonSize
		hover = false
	end
	glTexture(false)
end

-- Helper function to draw box selection rectangle
local function DrawBoxSelection()
	if not interactionState.areBoxSelecting then
		return
	end

	local minX = math.max(math.min(interactionState.boxSelectStartX, interactionState.boxSelectEndX), dim.l)
	local maxX = math.min(math.max(interactionState.boxSelectStartX, interactionState.boxSelectEndX), dim.r)
	local minY = math.max(math.min(interactionState.boxSelectStartY, interactionState.boxSelectEndY), dim.b)
	local maxY = math.min(math.max(interactionState.boxSelectStartY, interactionState.boxSelectEndY), dim.t)

	-- Check if selectionbox widget is enabled
	local selectionboxEnabled = widgetHandler:IsWidgetKnown("Selectionbox") and (widgetHandler.orderList["Selectionbox"] and widgetHandler.knownWidgets["Selectionbox"].active)

	-- Get modifier key states (ignoring alt as requested)
	local alt, ctrl, meta, shift = Spring.GetModKeyState()

	-- Determine background color based on modifier keys (only if selectionbox widget is enabled)
	local bgAlpha = 0.03
	if selectionboxEnabled and ctrl then
		-- Red background when ctrl is held
		glColor(1, 0.25, 0.25, bgAlpha)
	elseif selectionboxEnabled and shift then
		-- Green background when shift is held
		glColor(0.45, 1, 0.45, bgAlpha)
	else
		-- White background for normal selection
		glColor(1, 1, 1, bgAlpha * 0.8)
	end

	glTexture(false)
	glBeginEnd(GL_QUADS, function()
		glVertex(minX, minY)
		glVertex(maxX, minY)
		glVertex(maxX, maxY)
		glVertex(minX, maxY)
	end)

	gl.PolygonMode(GL.FRONT_AND_BACK, GL.LINE)
	gl.LineWidth(2.0 + 2.5)
	glColor(0, 0, 0, 0.12)
	glBeginEnd(GL_QUADS, function()
	glVertex(minX, minY)
		glVertex(maxX, minY)
		glVertex(maxX, maxY)
		glVertex(minX, maxY)
	end)

	-- Use stipple line only if selectionbox widget is enabled, otherwise use normal line
	if selectionboxEnabled then
		gl.LineStipple(true)
	end
	gl.LineWidth(2.0)

	-- Determine line color based on modifier keys (only if selectionbox widget is enabled)
	if selectionboxEnabled and ctrl then
		-- Bright red when ctrl is held
		glColor(1, 0.82, 0.82, 1)
	elseif selectionboxEnabled and shift then
		-- Bright green when shift is held
		glColor(0.92, 1, 0.92, 1)
	else
		-- White for normal selection
		glColor(1, 1, 1, 1)
	end

	glBeginEnd(GL_QUADS, function()
		glVertex(minX, minY)
		glVertex(maxX, minY)
		glVertex(maxX, maxY)
		glVertex(minX, maxY)
	end)
	gl.PolygonMode(GL.FRONT_AND_BACK, GL.FILL)
	if selectionboxEnabled then
		gl.LineStipple(false)
	end
	gl.LineWidth(1.0)
end

function widget:DrawScreen()

	local mx, my, mbl = spGetMouseState()

	-- During animation, draw transitioning panel
	if isAnimating then
		DrawPanel(dim.l, dim.r, dim.b, dim.t)

		-- Continue to draw PiP contents during animation (scaled down in DrawUnitsAndFeatures)
		if drawingGround then
			glColor(0.9, 0.9, 0.9, 1)
			glTexture('$grass')
			glBeginEnd(GL_QUADS, GroundTextureVertices)
			glTexture(false)
		end

		-- Draw units and features with scaled content
		DrawUnitsAndFeatures()

		-- Draw minimize/maximize button at fixed size based on direction
		if inMinMode then
			-- Animating to minimized - show maximize icon at its final position (fixed)
			local buttonSize = math.floor(usedButtonSize*maximizeSizemult)

			-- Draw button background panel first
			DrawPanel(minModeL, minModeL + buttonSize, minModeB, minModeB + buttonSize)
			glColor(panelBorderColorDark)
			glTexture(false)

			local hover = false
			if mx >= minModeL - elementPadding and mx <= minModeL + buttonSize + elementPadding and
			   my >= minModeB - elementPadding and my <= minModeB + buttonSize + elementPadding then
				hover = true
				-- Don't show tooltip during animation
				-- Draw hover background
				glColor(1,1,1,0.12)
				glTexture(false)
				RectRound(minModeL, minModeB, minModeL + buttonSize, minModeB + buttonSize, elementCorner*0.4, 1, 1, 1, 1)
			end
			if hover then
				glColor(1, 1, 1, 1)
			else
				glColor(panelBorderColorLight)
			end
			glTexture('LuaUI/Images/pip/PipMaximize.png')
			-- Draw button at final position (minModeL, minModeB), not at animated position
			glTexRect(minModeL, minModeB, minModeL + buttonSize, minModeB + buttonSize)
			glTexture(false)
		else
			-- Animating to maximized - show minimize icon at fixed button size in top-right corner
			local currentWidth = dim.r - dim.l
			local currentHeight = dim.t - dim.b
			if currentWidth > usedButtonSize and currentHeight > usedButtonSize then
				-- Draw button background panel first
				DrawPanel(dim.r - usedButtonSize, dim.r, dim.t - usedButtonSize, dim.t)
				glColor(panelBorderColorDark)
				glTexture(false)

				local hover = false
				if mx >= dim.r - usedButtonSize and mx <= dim.r and
				   my >= dim.t - usedButtonSize and my <= dim.t then
					hover = true
					-- Don't show tooltip during animation
					-- Draw hover background
					glColor(1,1,1,0.12)
					glTexture(false)
					RectRound(dim.r - usedButtonSize, dim.t - usedButtonSize, dim.r, dim.t, elementCorner*0.4, 1, 1, 1, 1)
				end
				if hover then
					glColor(1, 1, 1, 1)
				else
					glColor(panelBorderColorLight)
				end
				glTexture('LuaUI/Images/pip/PipMinimize.png')
				glTexRect(dim.r - usedButtonSize, dim.t - usedButtonSize, dim.r, dim.t)
				glTexture(false)
			end
		end
		return
	end

	if inMinMode then
		-- Use display list for minimized mode (static graphics with relative coordinates)
		local buttonSize = math.floor(usedButtonSize*maximizeSizemult)

		-- Draw UiElement background FIRST (with proper screen coordinates)
		--UiElement(minModeL-elementPadding, minModeB-elementPadding, minModeL+buttonSize+elementPadding, minModeB+buttonSize+elementPadding, 1, 1, 1, 1, nil, nil, nil, nil, nil, nil, nil, nil)

		-- Then draw icon on top using display list
		local offset = elementPadding + 2	-- to prevent touching screen edges and FlowUI Element will remove borders
		if not minModeDlist then
			minModeDlist = gl.CreateList(function()
				-- Draw UiElement background (only borders, no fill to avoid double opacity)
				UiElement(offset-elementPadding, offset-elementPadding, offset+buttonSize+elementPadding, offset+buttonSize+elementPadding, 1, 1, 1, 1, nil, nil, nil, nil, nil, nil, nil, nil)

				-- Draw icon at origin (0,0) - will be transformed to actual position
				glColor(panelBorderColorLight)
				glTexture('LuaUI/Images/pip/PipMaximize.png')
				glTexRect(offset, offset, offset+buttonSize, offset+buttonSize)
				glTexture(false)
			end)
		end

		-- Apply transform and draw the cached icon at actual position
		glPushMatrix()
		glTranslate(minModeL-offset, minModeB-offset, 0)
		gl.CallList(minModeDlist)
		glPopMatrix()

		-- Draw hover overlay if needed (dynamic)
		glColor(panelBorderColorDark)
		glTexture(false)
		local hover = false
		if mx >= minModeL - elementPadding and mx <= minModeL + buttonSize + elementPadding and
			my >= minModeB - elementPadding and my <= minModeB + buttonSize + elementPadding then
			hover = true
			if WG['tooltip'] then
				WG['tooltip'].ShowTooltip('pip'..pipNumber, Spring.I18N('ui.pip.tooltip'), nil, nil, nil)
			end
			glColor(1,1,1,0.12)
			glTexture(false)
			RectRound(minModeL, minModeB, minModeL + buttonSize, minModeB + buttonSize, elementCorner*0.4, 1, 1, 1, 1)
		end
		return
	end

	if not interactionState.arePanning then
		if interactionState.areBoxSelecting or (mx >= dim.l and mx <= dim.r and my >= dim.b and my <= dim.t) then
			-- Update info widget with custom hover for PIP window
			if WG['info'] and WG['info'].setCustomHover then
				local wx, wz = PipToWorldCoords(mx, my)
				local uID = GetUnitAtPoint(wx, wz)
				if uID then
					WG['info'].setCustomHover('unit', uID)
				else
					local fID = GetFeatureAtPoint(wx, wz)
					if fID then
						WG['info'].setCustomHover('feature', fID)
					else
						WG['info'].clearCustomHover()
					end
				end
			end

			-- Check if there's an active command
			local _, activeCmdID = Spring.GetActiveCommand()
			if not activeCmdID then
				-- No active command - use default command cursor behavior
				-- Get what command would be issued at the mouse position
				local wx, wz = PipToWorldCoords(mx, my)
				local targetID = GetIDAtPoint(wx, wz)
				local defaultCmd = Spring.GetDefaultCommand()

				-- If there's a default command, let it handle the cursor
				-- Otherwise check if selected units can move
				if not defaultCmd then
					local selectedUnits = Spring.GetSelectedUnits()
					local canMove = false

					if selectedUnits and #selectedUnits > 0 then
						for i = 1, #selectedUnits do
							local uDefID = Spring.GetUnitDefID(selectedUnits[i])
							if uDefID then
								local uDef = UnitDefs[uDefID]
								if uDef and (uDef.canMove or uDef.canFly) then
									canMove = true
									break
								end
							end
						end
					end

					-- Show move cursor if units can move, otherwise normal cursor
					if canMove then
						Spring.SetMouseCursor('cursormove')
					else
						Spring.SetMouseCursor('cursornormal')
					end
				end
			end
		else
			-- Mouse not in PIP window, clear custom hover
			if WG['info'] and WG['info'].clearCustomHover then
				WG['info'].clearCustomHover()
			end
		end
	end

	----------------------------------------------------------------------------------------------------
	-- Updates
	----------------------------------------------------------------------------------------------------
	if interactionState.areCentering then
		UpdateCentering(spGetMouseState())
	end

	if interactionState.areTracking then
		UpdateTracking()
	end

	----------------------------------------------------------------------------------------------------
	-- Panel and buttons (using render-to-texture for static/semi-static parts)
	----------------------------------------------------------------------------------------------------
	local pipWidth = dim.r - dim.l
	local pipHeight = dim.t - dim.b

	if gl.R2tHelper then
		-- Check if frame size changed
		local frameSizeChanged = (math.floor(pipWidth) ~= pipR2T.frameLastWidth or math.floor(pipHeight) ~= pipR2T.frameLastHeight)
		if frameSizeChanged then
			pipR2T.frameNeedsUpdate = true
			-- Delete old textures when size changes
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
			-- Create background texture if needed (no padding in texture)
			if not pipR2T.frameBackgroundTex then
				pipR2T.frameBackgroundTex = gl.CreateTexture(math.floor(pipWidth), math.floor(pipHeight), {
					target = GL.TEXTURE_2D,
					format = GL.RGBA,
					fbo = true,
				})
			end

			-- Create buttons texture if needed
			if not pipR2T.frameButtonsTex then
				pipR2T.frameButtonsTex = gl.CreateTexture(math.floor(pipWidth), math.floor(pipHeight), {
					target = GL.TEXTURE_2D,
					format = GL.RGBA,
					fbo = true,
				})
			end

			-- Render background
			if pipR2T.frameBackgroundTex then
				gl.R2tHelper.RenderToTexture(pipR2T.frameBackgroundTex,
					function()
						gl.Translate(-1, -1, 0)
						gl.Scale(2 / pipWidth, 2 / pipHeight, 0)
						RenderFrameBackground()
					end,
					true
				)
			end

			-- Render buttons (no hover)
			if pipR2T.frameButtonsTex then
				gl.R2tHelper.RenderToTexture(pipR2T.frameButtonsTex,
					function()
						gl.Translate(-1, -1, 0)
						gl.Scale(2 / pipWidth, 2 / pipHeight, 0)
						RenderFrameButtons()
					end,
					true
				)
			end

			pipR2T.frameNeedsUpdate = false
		end

		-- Blit frame background
		if pipR2T.frameBackgroundTex then
			gl.R2tHelper.BlendTexRect(pipR2T.frameBackgroundTex, dim.l, dim.b, dim.r, dim.t, true)
		end

		-- Draw UiElement borders around the frame (not in texture)
		UiElement(dim.l-elementPadding, dim.b-elementPadding, dim.r+elementPadding, dim.t+elementPadding, 1, 1, 1, 1, nil, nil, nil, nil, nil, nil, nil, nil)
	end

	----------------------------------------------------------------------------------------------------
	-- Units, features, and queues (using render-to-texture for performance)
	----------------------------------------------------------------------------------------------------
	if gl.R2tHelper then
		local currentTime = os.clock()

		-- Calculate dynamic update rate based on zoom level
		-- Higher zoom (more zoomed in) = higher update rate for smoother updates
		local dynamicUpdateRate = pipMinUpdateRate
		if zoom >= pipZoomThresholdMax then
			dynamicUpdateRate = pipMaxUpdateRate
		elseif zoom > pipZoomThresholdMin then
			-- Interpolate between min and max based on zoom
			local zoomFactor = (zoom - pipZoomThresholdMin) / (pipZoomThresholdMax - pipZoomThresholdMin)
			dynamicUpdateRate = pipMinUpdateRate + (pipMaxUpdateRate - pipMinUpdateRate) * zoomFactor
		end

	-- Adjust update rate based on actual draw time performance
	if pipR2T.contentLastDrawTime > 0 then
		local targetPerformanceFactor = 1.0
		if pipR2T.contentLastDrawTime > pipTargetDrawTime then
			-- Draw time is too high, reduce update rate
			-- Scale down proportionally to how much we're over budget
			targetPerformanceFactor = pipTargetDrawTime / pipR2T.contentLastDrawTime
			-- Clamp to reasonable range (don't go below 0.5x)
			targetPerformanceFactor = math.max(0.5, targetPerformanceFactor)
		elseif pipR2T.contentLastDrawTime < pipTargetDrawTime * 0.7 then
			-- Draw time is comfortably under budget, allow slight increase
			-- Only recover slowly to avoid oscillation
			targetPerformanceFactor = math.min(1.0, pipR2T.contentPerformanceFactor * 1.02)
		end
		-- Smoothly interpolate performance factor to avoid sudden changes
		pipR2T.contentPerformanceFactor = pipR2T.contentPerformanceFactor + (targetPerformanceFactor - pipR2T.contentPerformanceFactor) * pipPerformanceAdjustSpeed
		-- Apply performance factor to update rate
		dynamicUpdateRate = dynamicUpdateRate * pipR2T.contentPerformanceFactor
		-- Ensure we don't go below absolute minimum
		dynamicUpdateRate = math.max(10, dynamicUpdateRate)
	end		pipR2T.contentCurrentUpdateRate = dynamicUpdateRate  -- Store for display
		local pipUpdateInterval = dynamicUpdateRate > 0 and (1 / dynamicUpdateRate) or 0

		local pipWidth = dim.r - dim.l
		local pipHeight = dim.t - dim.b

		-- Check if content texture size changed (do this BEFORE shouldUpdate check)
		local contentSizeChanged = (math.floor(pipWidth) ~= pipR2T.contentLastWidth or math.floor(pipHeight) ~= pipR2T.contentLastHeight)
		if contentSizeChanged and pipR2T.contentTex then
			-- Delete old texture when size changes
			gl.DeleteTexture(pipR2T.contentTex)
			pipR2T.contentTex = nil
			pipR2T.contentLastWidth = math.floor(pipWidth)
			pipR2T.contentLastHeight = math.floor(pipHeight)
		end

		-- Force update if size changed or if it's time for periodic update
		local shouldUpdate = pipR2T.contentNeedsUpdate or contentSizeChanged or (pipUpdateInterval > 0 and (currentTime - pipR2T.contentLastUpdateTime) >= pipUpdateInterval) or pipUpdateInterval == 0

		if shouldUpdate then

			-- Create texture if needed
			if not pipR2T.contentTex and pipWidth >= 1 and pipHeight >= 1 then
				pipR2T.contentTex = gl.CreateTexture(math.floor(pipWidth), math.floor(pipHeight), {
					target = GL.TEXTURE_2D,
					format = GL.RGBA,
					fbo = true,
				})
				pipR2T.contentLastWidth = math.floor(pipWidth)
				pipR2T.contentLastHeight = math.floor(pipHeight)
			end

			if pipR2T.contentTex then
				-- Render PIP contents to texture (can only be done in Draw call-ins)
				gl.R2tHelper.RenderToTexture(pipR2T.contentTex,
					function()
						-- Transform to map texture space (0,0 to pipWidth,pipHeight) to normalized coords (-1,-1 to 1,1)
						gl.Translate(-1, -1, 0)
						gl.Scale(2 / pipWidth, 2 / pipHeight, 0)
						-- Don't translate by screen position - instead adjust dim temporarily

						-- Save current dim and ground coordinates
						local savedDim = {l = dim.l, r = dim.r, b = dim.b, t = dim.t}
						local savedGround = {
							view = {l = ground.view.l, r = ground.view.r, b = ground.view.b, t = ground.view.t},
							coord = {l = ground.coord.l, r = ground.coord.r, b = ground.coord.b, t = ground.coord.t}
						}

						-- Adjust dim to texture coordinates
						dim.l = 0
						dim.b = 0
						dim.r = pipWidth
						dim.t = pipHeight

						-- Recalculate world-to-pip conversion factors and ground coordinates based on new dim
						RecalculateWorldCoordinates()
						RecalculateGroundTextureCoordinates()

						-- Render content in texture space
						RenderPipContents()

						-- Restore original screen coordinates
						dim.l = savedDim.l
						dim.r = savedDim.r
						dim.b = savedDim.b
						dim.t = savedDim.t

						-- Recalculate world-to-pip conversion factors with restored dim
						RecalculateWorldCoordinates()

						-- Restore ground coordinates
						ground.view.l = savedGround.view.l
						ground.view.r = savedGround.view.r
						ground.view.b = savedGround.view.b
						ground.view.t = savedGround.view.t
						ground.coord.l = savedGround.coord.l
						ground.coord.r = savedGround.coord.r
						ground.coord.b = savedGround.coord.b
						ground.coord.t = savedGround.coord.t
					end,
					true
				)
				pipR2T.contentLastUpdateTime = currentTime
				pipR2T.contentNeedsUpdate = false
			end
		end

		-- Blit the pre-rendered texture
		if pipR2T.contentTex then
			gl.R2tHelper.BlendTexRect(pipR2T.contentTex, dim.l, dim.b, dim.r, dim.t, true)
		end
	end

	----------------------------------------------------------------------------------------------------
	-- Buttons and hover effects
	----------------------------------------------------------------------------------------------------
	if gl.R2tHelper then
		-- Blit frame buttons
		if pipR2T.frameButtonsTex then
			gl.R2tHelper.BlendTexRect(pipR2T.frameButtonsTex, dim.l, dim.b, dim.r, dim.t, true)
		end

		-- Draw dynamic hover overlays
		-- Resize handle hover
		local hover = areResizing or false
		if mx >= dim.l and mx <= dim.r and my >= dim.b and my <= dim.t then
			if (dim.r-mx + my-dim.b <= usedButtonSize) then
				hover = true
				Spring.SetMouseCursor('cursornormal')
				if WG['tooltip'] then
					WG['tooltip'].ShowTooltip('pip'..pipNumber, 'Resize', nil, nil, nil)
				end
			end
		end
		if hover then
			local mult = mbl and 4.5 or 1.5
			glColor(panelBorderColorDark[1]*mult, panelBorderColorDark[2]*mult, panelBorderColorDark[3]*mult, 1)
			gl.LineWidth(1.0)
			glBeginEnd(GL_TRIANGLES, ResizeHandleVertices)
		end

		-- Minimize button hover
		hover = false
		if mx >= dim.r - usedButtonSize - elementPadding and mx <= dim.r - elementPadding and
			my >= dim.t - usedButtonSize - elementPadding and my <= dim.t - elementPadding then
			hover = true
			Spring.SetMouseCursor('cursornormal')
			if WG['tooltip'] then
				WG['tooltip'].ShowTooltip('pip'..pipNumber, 'Minimize', nil, nil, nil)
			end
			glColor(1,1,1,0.12)
			glTexture(false)
			RectRound(dim.r - usedButtonSize, dim.t - usedButtonSize, dim.r, dim.t, elementCorner*0.4, 1, 1, 1, 1)
			glColor(1, 1, 1, 1)
			glTexture('LuaUI/Images/pip/PipMinimize.png')
			glTexRect(dim.r - usedButtonSize, dim.t - usedButtonSize, dim.r, dim.t)
			glTexture(false)
		end

		-- Bottom-left buttons hover
		local selectedUnits = Spring.GetSelectedUnits()
		local hasSelection = #selectedUnits > 0
		local isTracking = interactionState.areTracking ~= nil
		local visibleButtons = {}
		for i = 1, #buttons do
			if buttons[i].command ~= 'pip_track' or hasSelection or isTracking then
				visibleButtons[#visibleButtons + 1] = buttons[i]
			end
		end

		hover = false
		local bx = dim.l
		for i = 1, #visibleButtons do
			if mx >= bx and mx <= bx + usedButtonSize and
			   my >= dim.b and my <= dim.b + usedButtonSize then
				hover = true
				Spring.SetMouseCursor('cursornormal')
				if visibleButtons[i].tooltip and WG['tooltip'] then
					WG['tooltip'].ShowTooltip('pip'..pipNumber, visibleButtons[i].tooltip, nil, nil, nil)
				end
				glColor(1,1,1,0.12)
				glTexture(false)
				RectRound(bx, dim.b, bx + usedButtonSize, dim.b + usedButtonSize, elementCorner*0.4, 1, 1, 1, 1)
				-- Redraw button icon on hover for brightness
				if visibleButtons[i].command == 'pip_track' and interactionState.areTracking then
					glColor(panelBorderColorDark)
				else
					glColor(1, 1, 1, 1)
				end
				glTexture(visibleButtons[i].texture)
				glTexRect(bx, dim.b, bx + usedButtonSize, dim.b + usedButtonSize)
				glTexture(false)
				break
			end
			bx = bx + usedButtonSize
		end
	end

	if pipNumber ~= 1 then
		glColor(panelBorderColorDark)
		RectRound(dim.l, dim.t - usedButtonSize, dim.l + usedButtonSize, dim.t, elementCorner*0.4, 0, 0, 1, 0)
		local fontSize = 14
		local padding = 12
		font:Begin()
		font:SetTextColor(0.85, 0.85, 0.85, 1)
		font:SetOutlineColor(0, 0, 0, 0.5)
		font:Print(pipNumber, dim.l + padding, dim.t - (fontSize*1.15) - padding, fontSize*2, "no")
		font:End()	-- Draw box selection rectangle
	end

	-- Display current max update rate (top-left corner)
	-- local fontSize = 11
	-- local padding = 5
	-- font:Begin()
	-- font:SetTextColor(0.85, 0.85, 0.85, 1)
	-- font:SetOutlineColor(0, 0, 0, 0.5)
	-- font:Print(string.format("%.0f FPS", pipR2T.contentCurrentUpdateRate), dim.l + padding, dim.t - (fontSize*1.6) - padding, fontSize*2, "no")
	-- font:End()	-- Draw box selection rectangle

	DrawBoxSelection()

	-- Draw formation dots overlay (command queues are now in R2T)
	DrawFormationDotsOverlay()

	glColor(1, 1, 1, 1)
end

function widget:DrawWorld()
	if inMinMode then return end
	gl.Color(1, 1, 0, 0.25)
	gl.LineWidth(1.49)
	gl.DepthTest(true)
	glBeginEnd(GL_LINE_STRIP, DrawGroundBox, world.l, world.r, world.b, world.t)
	gl.DepthTest(false)

	-- Note: Formation lines are not drawn in world view (customformations widget handles this)

	-- Draw build drag line if actively dragging
	local dragCount = #interactionState.buildDragPositions
	if interactionState.areBuildDragging and dragCount > 1 then
		gl.Color(1, 1, 0, 0.6)
		gl.LineWidth(2.0)
		gl.LineStipple(true)
		gl.DepthTest(true)
		gl.BeginEnd(GL.LINE_STRIP, function()
			for i = 1, dragCount do
				local pos = interactionState.buildDragPositions[i]
				local wy = Spring.GetGroundHeight(pos.wx, pos.wz)
				gl.Vertex(pos.wx, wy + 5, pos.wz)
			end
		end)
		gl.LineStipple(false)
		gl.DepthTest(false)
		gl.LineWidth(1.0)
	end

	gl.Color(1, 1, 1, 1)
end

function widget:DrawInMiniMap(minimapWidth, minimapHeight)
	if inMinMode then return end

	-- Convert world coordinates to minimap coordinates (0-1 range)
	-- Note: Z-axis is inverted for minimap (top of map = 0, bottom = mapSizeZ)
	local x1 = world.l / mapSizeX
	local z1 = 1 - (world.t / mapSizeZ)  -- Invert Z
	local x2 = world.r / mapSizeX
	local z2 = 1 - (world.b / mapSizeZ)  -- Invert Z

	-- Clamp to minimap bounds
	x1 = math.max(0, math.min(1, x1))
	z1 = math.max(0, math.min(1, z1))
	x2 = math.max(0, math.min(1, x2))
	z2 = math.max(0, math.min(1, z2))

	-- Convert to pixel coordinates
	x1 = x1 * minimapWidth
	z1 = z1 * minimapHeight
	x2 = x2 * minimapWidth
	z2 = z2 * minimapHeight

	-- Draw yellow rectangle showing PIP view area
	gl.Texture(false)
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	gl.PushMatrix()
	gl.Translate(0, 0, 0)
	gl.Scale(1, 1, 1)

	-- Draw dark background rectangle
	gl.Color(0, 0, 0, 0.16)
	gl.LineWidth(3.5)
	gl.BeginEnd(GL.LINE_LOOP, function()
		gl.Vertex(x1, z1)
		gl.Vertex(x2, z1)
		gl.Vertex(x2, z2)
		gl.Vertex(x1, z2)
	end)

	-- Draw yellow rectangle
	gl.Color(1, 1, 0, 0.6)
	gl.LineWidth(2.0)
	--gl.LineStipple(2, 0xAAAA)
	gl.BeginEnd(GL.LINE_LOOP, function()
		gl.Vertex(x1, z1)
		gl.Vertex(x2, z1)
		gl.Vertex(x2, z2)
		gl.Vertex(x1, z2)
	end)
	--gl.LineStipple(false)

	gl.LineWidth(1.0)
	gl.Color(1, 1, 1, 1)
	gl.PopMatrix()
end

function widget:Update(dt)
	-- Track selection and tracking state changes for frame updates
	local selectedUnits = Spring.GetSelectedUnits()
	local currentSelectionCount = #selectedUnits
	local currentTrackingState = interactionState.areTracking ~= nil
	if not lastSelectionCount then lastSelectionCount = 0 end
	if not lastTrackingState then lastTrackingState = false end

	if currentSelectionCount ~= lastSelectionCount or currentTrackingState ~= lastTrackingState then
		pipR2T.frameNeedsUpdate = true
		lastSelectionCount = currentSelectionCount
		lastTrackingState = currentTrackingState
	end

	-- Check if selectionbox widget state has changed and update command colors accordingly
	local selectionboxEnabled = widgetHandler:IsWidgetKnown("Selectionbox") and (widgetHandler.orderList["Selectionbox"] and widgetHandler.knownWidgets["Selectionbox"].active)
	if selectionboxEnabled ~= lastSelectionboxEnabled then
		lastSelectionboxEnabled = selectionboxEnabled
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
	local mouseX, mouseY, leftButton, middleButton, rightButton = Spring.GetMouseState()
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
		Spring.SetMouseCursor('cursornormal')
	end

	-- Update game time (only when game is not paused)
	local _, _, isPaused = Spring.GetGameSpeed()
	if not isPaused then
		gameTime = gameTime + dt
	end

	-- Handle minimize/maximize animation
	if isAnimating then
		animationProgress = animationProgress + (dt / animationDuration)
		pipR2T.contentNeedsUpdate = true  -- Update during animation
		pipR2T.frameNeedsUpdate = true  -- Frame also needs update during animation

		if animationProgress >= 1 then
			-- Animation complete
			animationProgress = 1
			isAnimating = false
			dim.l = animEndDim.l
			dim.r = animEndDim.r
			dim.b = animEndDim.b
			dim.t = animEndDim.t
			-- Recalculate world coordinates for final dimensions
			RecalculateWorldCoordinates()
			RecalculateGroundTextureCoordinates()
			pipR2T.frameNeedsUpdate = true  -- Final update after animation
			-- Update guishader blur after animation completes
			UpdateGuishaderBlur()
		else
			-- Interpolate dimensions with easing (ease-in-out)
			local t = animationProgress
			local ease = t < 0.5 and 2 * t * t or 1 - math.pow(-2 * t + 2, 2) / 2

			dim.l = animStartDim.l + (animEndDim.l - animStartDim.l) * ease
			dim.r = animStartDim.r + (animEndDim.r - animStartDim.r) * ease
			dim.b = animStartDim.b + (animEndDim.b - animStartDim.b) * ease
			dim.t = animStartDim.t + (animEndDim.t - animStartDim.t) * ease

			RecalculateWorldCoordinates()
			RecalculateGroundTextureCoordinates()
			-- Update guishader blur continuously during animation
			UpdateGuishaderBlur()
		end
	end

	-- Smooth zoom and camera center interpolation
	local zoomNeedsUpdate = math.abs(zoom - targetZoom) > 0.001
	local centerNeedsUpdate = math.abs(wcx - targetWcx) > 0.1 or math.abs(wcz - targetWcz) > 0.1

	-- Mark PIP as needing update if zoom or position changed
	if zoomNeedsUpdate or centerNeedsUpdate then
		pipR2T.contentNeedsUpdate = true
	end

	-- If zoom-to-cursor is active, continuously recalculate target center to keep world position under cursor
	-- Disable this when tracking units - we want to keep the camera centered on tracked units
	if zoomToCursorActive and zoomNeedsUpdate and not interactionState.areTracking then
		local screenOffsetX = zoomToCursorScreenX - (dim.l + dim.r) * 0.5
		local screenOffsetY = zoomToCursorScreenY - (dim.b + dim.t) * 0.5

		-- Calculate what center should be to keep the stored world position under the cursor with current target zoom
		targetWcx = zoomToCursorWorldX - screenOffsetX / targetZoom
		targetWcz = zoomToCursorWorldZ + screenOffsetY / targetZoom

		-- Apply same margin-based clamping as panning
		local pipWidth = dim.r - dim.l
		local pipHeight = dim.t - dim.b
		local visibleWorldWidth = pipWidth / targetZoom
		local visibleWorldHeight = pipHeight / targetZoom

		-- Use the smaller dimension for consistent visual margin
		local smallerVisibleDimension = math.min(visibleWorldWidth, visibleWorldHeight)
		local margin = smallerVisibleDimension * mapEdgeMargin

		-- Calculate min/max camera positions to keep margin from map edges
		local minWcx = visibleWorldWidth / 2 - margin
		local maxWcx = mapSizeX - (visibleWorldWidth / 2 - margin)
		local minWcz = visibleWorldHeight / 2 - margin
		local maxWcz = mapSizeZ - (visibleWorldHeight / 2 - margin)

		-- Clamp with margin-based boundaries
		targetWcx = math.min(math.max(targetWcx, minWcx), maxWcx)
		targetWcz = math.min(math.max(targetWcz, minWcz), maxWcz)

		centerNeedsUpdate = true  -- Force center update
	end

	if zoomNeedsUpdate or centerNeedsUpdate then
		if zoomNeedsUpdate then
			zoom = zoom + (targetZoom - zoom) * math.min(dt * zoomSmoothness, 1)
		end

		if centerNeedsUpdate then
			-- Use different smoothness values depending on context
			local smoothnessToUse = centerSmoothness -- Default for zoom-to-cursor and panning
			if interactionState.areTracking then
				smoothnessToUse = trackingSmoothness -- Smoother animation for tracking mode
			end

			local centerFactor = math.min(dt * smoothnessToUse, 1)
			wcx = wcx + (targetWcx - wcx) * centerFactor
			wcz = wcz + (targetWcz - wcz) * centerFactor
		end

		RecalculateWorldCoordinates()
		RecalculateGroundTextureCoordinates()
	else
		-- Zoom and center have reached their targets, disable zoom-to-cursor
		zoomToCursorActive = false
	end

	if interactionState.areIncreasingZoom then
		targetZoom = math.min(targetZoom * zoomRate ^ dt, zoomMax)

		-- Clamp BOTH current and target camera positions to respect margin
		-- Use current zoom for current position, target zoom for target position
		local pipWidth = dim.r - dim.l
		local pipHeight = dim.t - dim.b

		-- Clamp current animated position
		local currentVisibleWorldWidth = pipWidth / zoom
		local currentVisibleWorldHeight = pipHeight / zoom
		local currentSmallerDimension = math.min(currentVisibleWorldWidth, currentVisibleWorldHeight)
		local currentMargin = currentSmallerDimension * mapEdgeMargin

		local currentMinWcx = currentVisibleWorldWidth / 2 - currentMargin
		local currentMaxWcx = mapSizeX - (currentVisibleWorldWidth / 2 - currentMargin)
		local currentMinWcz = currentVisibleWorldHeight / 2 - currentMargin
		local currentMaxWcz = mapSizeZ - (currentVisibleWorldHeight / 2 - currentMargin)

		wcx = math.min(math.max(wcx, currentMinWcx), currentMaxWcx)
		wcz = math.min(math.max(wcz, currentMinWcz), currentMaxWcz)

		-- Clamp target position
		local targetVisibleWorldWidth = pipWidth / targetZoom
		local targetVisibleWorldHeight = pipHeight / targetZoom
		local targetSmallerDimension = math.min(targetVisibleWorldWidth, targetVisibleWorldHeight)
		local targetMargin = targetSmallerDimension * mapEdgeMargin

		local targetMinWcx = targetVisibleWorldWidth / 2 - targetMargin
		local targetMaxWcx = mapSizeX - (targetVisibleWorldWidth / 2 - targetMargin)
		local targetMinWcz = targetVisibleWorldHeight / 2 - targetMargin
		local targetMaxWcz = mapSizeZ - (targetVisibleWorldHeight / 2 - targetMargin)

		targetWcx = math.min(math.max(targetWcx, targetMinWcx), targetMaxWcx)
		targetWcz = math.min(math.max(targetWcz, targetMinWcz), targetMaxWcz)

		RecalculateWorldCoordinates()
		RecalculateGroundTextureCoordinates()
	elseif interactionState.areDecreasingZoom then
		targetZoom = math.max(targetZoom / zoomRate ^ dt, zoomMin)

		-- Clamp BOTH current and target camera positions to respect margin
		-- Use current zoom for current position, target zoom for target position
		local pipWidth = dim.r - dim.l
		local pipHeight = dim.t - dim.b

		-- Clamp current animated position
		local currentVisibleWorldWidth = pipWidth / zoom
		local currentVisibleWorldHeight = pipHeight / zoom
		local currentSmallerDimension = math.min(currentVisibleWorldWidth, currentVisibleWorldHeight)
		local currentMargin = currentSmallerDimension * mapEdgeMargin

		local currentMinWcx = currentVisibleWorldWidth / 2 - currentMargin
		local currentMaxWcx = mapSizeX - (currentVisibleWorldWidth / 2 - currentMargin)
		local currentMinWcz = currentVisibleWorldHeight / 2 - currentMargin
		local currentMaxWcz = mapSizeZ - (currentVisibleWorldHeight / 2 - currentMargin)

		wcx = math.min(math.max(wcx, currentMinWcx), currentMaxWcx)
		wcz = math.min(math.max(wcz, currentMinWcz), currentMaxWcz)

		-- Clamp target position
		local targetVisibleWorldWidth = pipWidth / targetZoom
		local targetVisibleWorldHeight = pipHeight / targetZoom
		local targetSmallerDimension = math.min(targetVisibleWorldWidth, targetVisibleWorldHeight)
		local targetMargin = targetSmallerDimension * mapEdgeMargin

		local targetMinWcx = targetVisibleWorldWidth / 2 - targetMargin
		local targetMaxWcx = mapSizeX - (targetVisibleWorldWidth / 2 - targetMargin)
		local targetMinWcz = targetVisibleWorldHeight / 2 - targetMargin
		local targetMaxWcz = mapSizeZ - (targetVisibleWorldHeight / 2 - targetMargin)

		targetWcx = math.min(math.max(targetWcx, targetMinWcx), targetMaxWcx)
		targetWcz = math.min(math.max(targetWcz, targetMinWcz), targetMaxWcz)

		RecalculateWorldCoordinates()
		RecalculateGroundTextureCoordinates()
	end

	if not gameHasStarted then
		local newX, _, newZ = Spring.GetTeamStartPosition(Spring.GetMyTeamID())
		if newX ~= startX then
			startX, startZ = newX, newZ
			wcx, wcz = startX, startZ
			targetWcx, targetWcz = wcx, wcz  -- Set targets instantly for start position
			RecalculateWorldCoordinates()
			RecalculateGroundTextureCoordinates()
		end
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

	-- Automatically track the commander at game start
	local commanderID = FindMyCommander()
	if commanderID then
		interactionState.areTracking = {commanderID}  -- Store as table/array
	end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
	if inMinMode then return end
	-- Performance: limit max simultaneous shatters
	if #cache.iconShatters >= cache.maxIconShatters then return end

	-- Only shatter if unit has an icon
	if not cache.unitIcon[unitDefID] then return end

	-- Skip unfinished/under-construction units
	local _, _, _, _, buildProg = spGetUnitHealth(unitID)
	if buildProg and buildProg < 1 then return end

	-- Get unit position
	local ux, uy, uz = spGetUnitPosition(unitID)
	if not ux then return end

	-- Get icon data
	local iconData = cache.unitIcon[unitDefID]
	if not iconData or not iconData.size then return end -- Ensure icon has size data
	-- Calculate distMult the same way as icon rendering to match size at all zoom levels
	local distMult = math.min(math.max(1, 2.2-(zoom*3.3)), 3)
	-- Use exact same formula as icon rendering: iconRadius * zoom * iconData.size * distMult
	local iconSize = iconRadius * zoom * iconData.size * distMult

	-- Use fixed 2x2 or 3x3 grid for fewer, bigger fragments
	-- Adjust threshold based on actual rendered size
	local grid = iconSize < 40 and 2 or 3
	-- Icon is rendered at 2*iconSize (from -iconSize to +iconSize), so fragments need to match
	local fragSize = (iconSize * 2) / grid

	-- Convert world coords to PiP-local coords (center of icon)
	local pipX = ux - wcx
	local pipZ = wcz - uz

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

			-- Divide by zoom to compensate for glScale transformation
			-- Use square root of iconSize to reduce the impact of larger icons on distance
			local speedVariation = 0.4 + math.random() * 1.2  -- 0.4 to 1.6
			local speed = ((25 + math.random() * 15) * (math.sqrt(iconSize) / 6.3) * 3.4 * speedVariation) / zoom

			table.insert(fragments, {
				-- Start all fragments at icon center
				x = pipX,
				z = pipZ,
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
		zoom = zoom  -- Store zoom factor to compensate for glScale during rendering
	})
end

function widget:VisibleExplosion(px, py, pz, weaponID, ownerID)
	if inMinMode then return end
	-- Skip processing explosions when we're not rendering them due to zoom level
	if zoom < zoomExplosionDetail then return end
	if drawProjectiles then
		-- Skip specific weapons using cached data (e.g., footstep effects)
		if weaponID and cache.weaponSkipExplosion[weaponID] then
			return
		end

		-- Check if this is a lightning weapon
		local isLightning = weaponID and cache.weaponIsLightning[weaponID]

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
			isLightning = isLightning
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
	if inMinMode then return end
	local mx, my = spGetMouseState()
	if mx >= dim.l and mx <= dim.r and my >= dim.b and my <= dim.t then
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
	if inMinMode then return end
	-- Prevent infinite recursion when we call Spring.Marker* functions
	if isProcessingMapDraw then
		return false
	end

	-- Only process our own mapmarks (not from other players)
	local myPlayerID = Spring.GetMyPlayerID()
	if playerID ~= myPlayerID then
		return false
	end

	-- The mx,my,mz parameters are world coordinates from where the camera is looking
	-- We need to check if the mapmark was initiated while mouse was over the PiP

	-- For point markers, use the stored initiation position (from double-click)
	-- For line/erase, use current mouse position (for continuous drawing)
	local screenX, screenY
	if cmdType == 'point' and mapmarkInitScreenX and mapmarkInitScreenY then
		-- Use the position where mapmark was initiated (double-click position)
		-- Check if it was recent (within last 10 seconds - allows time for typing message)
		if (os.clock() - mapmarkInitTime) < 10 then
			screenX = mapmarkInitScreenX
			screenY = mapmarkInitScreenY
			-- Clear the stored position after using it
			mapmarkInitScreenX = nil
			mapmarkInitScreenY = nil
		else
			-- Too old, use current position and clear stored position
			screenX, screenY = Spring.GetMouseState()
			mapmarkInitScreenX = nil
			mapmarkInitScreenY = nil
		end
	else
		-- For line drawing and erase, use current mouse position
		screenX, screenY = Spring.GetMouseState()
	end

	-- Check if the mouse was/is over the PiP window
	if screenX >= dim.l and screenX <= dim.r and screenY >= dim.b and screenY <= dim.t and not inMinMode then
		-- The mapmark was initiated while mouse was over PiP
		-- Translate the PiP screen position to world coordinates
		local wx, wz = PipToWorldCoords(screenX, screenY)
		if not wx or not wz then
			-- If translation fails, let default handler process it
			return false
		end

		local wy = Spring.GetGroundHeight(wx, wz)
		-- Add small height offset so markers are visible above ground (except for erase)
		local markerHeight = wy + 5

		-- Now place the marker at the PiP world coordinates instead of camera world coordinates
		isProcessingMapDraw = true

		if cmdType == 'point' then
			-- Place marker at PiP location
			Spring.MarkerAddPoint(wx, markerHeight, wz, c or "")

		elseif cmdType == 'line' then
			-- For line drawing in PiP - track for continuous drawing

			-- If we have a previous position, draw line from there to here
			if interactionState.lastMapDrawX and interactionState.lastMapDrawZ then
				local lastY = Spring.GetGroundHeight(interactionState.lastMapDrawX, interactionState.lastMapDrawZ) + 5
				Spring.MarkerAddLine(interactionState.lastMapDrawX, lastY, interactionState.lastMapDrawZ, wx, markerHeight, wz)
			end

			-- Update last position for next segment
			interactionState.lastMapDrawX = wx
			interactionState.lastMapDrawZ = wz

		elseif cmdType == 'erase' then
			-- Erase at the PiP location - use ground height for better detection
			Spring.MarkerErasePosition(wx, wy, wz)
		end

		isProcessingMapDraw = false
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
	if isAnimating then
		-- During animation, check both start and end positions to ensure we capture the animated area
		if inMinMode then
			-- Animating to minimized - check the shrinking area
			return mx >= math.min(dim.l, minModeL) and mx <= math.max(dim.r, minModeL + math.floor(usedButtonSize*maximizeSizemult)) and
			       my >= math.min(dim.b, minModeB) and my <= math.max(dim.t, minModeB + math.floor(usedButtonSize*maximizeSizemult))
		else
			-- Animating to maximized - check the expanding area
			return mx >= math.min(dim.l, minModeL) and mx <= math.max(dim.r, minModeL + math.floor(usedButtonSize*maximizeSizemult)) and
			       my >= math.min(dim.b, minModeB) and my <= math.max(dim.t, minModeB + math.floor(usedButtonSize*maximizeSizemult))
		end
	elseif inMinMode then
		-- In minimized mode, check if over the minimize button area only
		local buttonSize = math.floor(usedButtonSize * maximizeSizemult)
		return mx >= minModeL and mx <= minModeL + buttonSize and my >= minModeB and my <= minModeB + buttonSize
	else
		-- In normal mode, check if over the PIP panel
		return mx >= dim.l and mx <= dim.r and my >= dim.b and my <= dim.t
	end
end

function widget:MouseWheel(up, value)
	if not inMinMode then
		local mx, my = spGetMouseState()
		if mx >= dim.l and mx <= dim.r and my >= dim.b and my <= dim.t then
			local oldZoom = targetZoom

			if Spring.GetConfigInt("ScrollWheelSpeed", 1) > 0 then
				if up then
					targetZoom = math.max(targetZoom / zoomWheel, zoomMin)
				else
					targetZoom = math.min(targetZoom * zoomWheel, zoomMax)
				end
			else
				if not up then
					targetZoom = math.max(targetZoom / zoomWheel, zoomMin)
				else
					targetZoom = math.min(targetZoom * zoomWheel, zoomMax)
				end
			end

			-- If zoom-to-cursor is enabled and we're INCREASING zoom (getting closer), store the cursor world position
			-- Disable zoom-to-cursor when tracking units (always zoom to center)
			if zoomToCursor and targetZoom > oldZoom and not interactionState.areTracking then
				-- Store screen position
				zoomToCursorScreenX = mx
				zoomToCursorScreenY = my

				-- Calculate and store the world position under cursor using CURRENT animated values
				-- This is critical - we need to use where we ARE now, not where we're going
				local screenOffsetX = mx - (dim.l + dim.r) * 0.5
				local screenOffsetY = my - (dim.b + dim.t) * 0.5

				-- Use current animated zoom and center, not targets
				zoomToCursorWorldX = wcx + screenOffsetX / zoom
				zoomToCursorWorldZ = wcz - screenOffsetY / zoom

				-- Enable continuous recalculation in Update
				zoomToCursorActive = true
			else
				-- Decreasing zoom (pulling back) or feature disabled - disable zoom-to-cursor
				zoomToCursorActive = false

				-- Clamp BOTH current and target camera positions to respect margin
				local pipWidth = dim.r - dim.l
				local pipHeight = dim.t - dim.b

				-- Clamp current animated position
				local currentVisibleWorldWidth = pipWidth / zoom
				local currentVisibleWorldHeight = pipHeight / zoom
				local currentSmallerDimension = math.min(currentVisibleWorldWidth, currentVisibleWorldHeight)
				local currentMargin = currentSmallerDimension * mapEdgeMargin

				local currentMinWcx = currentVisibleWorldWidth / 2 - currentMargin
				local currentMaxWcx = mapSizeX - (currentVisibleWorldWidth / 2 - currentMargin)
				local currentMinWcz = currentVisibleWorldHeight / 2 - currentMargin
				local currentMaxWcz = mapSizeZ - (currentVisibleWorldHeight / 2 - currentMargin)

				wcx = math.min(math.max(wcx, currentMinWcx), currentMaxWcx)
				wcz = math.min(math.max(wcz, currentMinWcz), currentMaxWcz)

				-- Clamp target position
				local targetVisibleWorldWidth = pipWidth / targetZoom
				local targetVisibleWorldHeight = pipHeight / targetZoom
				local targetSmallerDimension = math.min(targetVisibleWorldWidth, targetVisibleWorldHeight)
				local targetMargin = targetSmallerDimension * mapEdgeMargin

				local targetMinWcx = targetVisibleWorldWidth / 2 - targetMargin
				local targetMaxWcx = mapSizeX - (targetVisibleWorldWidth / 2 - targetMargin)
				local targetMinWcz = targetVisibleWorldHeight / 2 - targetMargin
				local targetMaxWcz = mapSizeZ - (targetVisibleWorldHeight / 2 - targetMargin)

				targetWcx = math.min(math.max(targetWcx, targetMinWcx), targetMaxWcx)
				targetWcz = math.min(math.max(targetWcz, targetMinWcz), targetMaxWcz)

				RecalculateWorldCoordinates()
				RecalculateGroundTextureCoordinates()
			end

			return true
		end
	end
end

function widget:MousePress(mx, my, mButton)

	-- Track mapmark initiation position if mouse is over PiP (for point markers with double-click)
	if mx >= dim.l and mx <= dim.r and my >= dim.b and my <= dim.t and not inMinMode then
		mapmarkInitScreenX = mx
		mapmarkInitScreenY = my
		mapmarkInitTime = os.clock()
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
	if interactionState.leftMousePressed and interactionState.rightMousePressed and mx >= dim.l and mx <= dim.r and my >= dim.b and my <= dim.t then
		-- Check if this button press completes the combo (other button was already pressed)
		local isSecondButton = (mButton == 1 and wasRightPressed) or (mButton == 3 and wasLeftPressed)

		if isSecondButton then
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

			-- Start panning
			interactionState.arePanning = true
			interactionState.panStartX = (dim.l + dim.r) / 2
			interactionState.panStartY = (dim.b + dim.t) / 2
			interactionState.areTracking = nil
			Spring.SetMouseCursor('cursornormal', hideCursorWhilePanning and 2 or 1)
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
	if inMinMode then
		-- Handle middle mouse button even in min mode
		if mButton == 2 then
			if interactionState.panToggleMode then
				interactionState.panToggleMode = false
				interactionState.arePanning = false
				Spring.SetMouseCursor('cursornormal')
				return true
			end
		end

		-- Was maximize clicked?
		if mButton == 1 and
		   mx >= minModeL and mx <= minModeL + math.floor(usedButtonSize*maximizeSizemult) and
		   my >= minModeB and my <= minModeB + math.floor(usedButtonSize*maximizeSizemult) then
			-- Start maximize animation - restore saved dimensions
			local buttonSize = math.floor(usedButtonSize*maximizeSizemult)

			-- Temporarily set dimensions to saved values to check if they're valid
			dim.l = savedDimensions.l
			dim.r = savedDimensions.r
			dim.b = savedDimensions.b
			dim.t = savedDimensions.t
			CorrectScreenPosition()

			-- Update camera to tracked units immediately before maximizing
			if interactionState.areTracking then
				UpdateTracking()
			end
			RecalculateWorldCoordinates()
			RecalculateGroundTextureCoordinates()

			animStartDim = {
				l = minModeL,
				r = minModeL + buttonSize,
				b = minModeB,
				t = minModeB + buttonSize
			}
			animEndDim = {
				l = dim.l,
				r = dim.r,
				b = dim.b,
				t = dim.t
			}
			animationProgress = 0
			isAnimating = true
			inMinMode = false
			return true
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
			Spring.SetMouseCursor('cursornormal')
			return true
		end

		-- Start tracking middle mouse for toggle vs hold-drag
		if mx >= dim.l and mx <= dim.r and my >= dim.b and my <= dim.t then
			-- Cancel any ongoing build drag when middle mouse is pressed
			if interactionState.areBuildDragging then
				interactionState.areBuildDragging = false
				interactionState.buildDragPositions = {}
			end

			interactionState.middleMousePressed = true
			interactionState.middleMouseMoved = false
			interactionState.panStartX = (dim.l + dim.r) / 2
			interactionState.panStartY = (dim.b + dim.t) / 2
			return true
		end
	end

	-- Did we click within the pip window ?
	if mx >= dim.l and mx <= dim.r and my >= dim.b and my <= dim.t then

		-- Was it a left click? -> check buttons
		if mButton == 1 then

			-- Resize thing (check first - highest priority)
			if dim.r-mx + my-dim.b <= usedButtonSize then
				areResizing = true
				return true
			end

			-- Minimizing?
			if mx >= dim.r - usedButtonSize and my >= dim.t - usedButtonSize then
				local sw, sh = Spring.GetWindowGeometry()

				-- Save current dimensions before minimizing
				savedDimensions = {
					l = dim.l,
					r = dim.r,
					b = dim.b,
					t = dim.t
				}

				-- Calculate where the minimize button will end up
				local targetL, targetB
				if dim.l < sw * 0.5 then
					targetL = dim.l
				else
					targetL = dim.r - math.floor(usedButtonSize*maximizeSizemult)
				end
				if dim.b < sh * 0.5 then
					targetB = dim.b
				else
					targetB = dim.t - math.floor(usedButtonSize*maximizeSizemult)
				end

				-- Store the target position
				minModeL = targetL
				minModeB = targetB

				-- Start minimize animation
				local buttonSize = math.floor(usedButtonSize*maximizeSizemult)
				animStartDim = {
					l = dim.l,
					r = dim.r,
					b = dim.b,
					t = dim.t
				}
				animEndDim = {
					l = targetL,
					r = targetL + buttonSize,
					b = targetB,
					t = targetB + buttonSize
				}
				animationProgress = 0
				isAnimating = true
				inMinMode = true

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
			if my <= dim.b + usedButtonSize then
				-- Calculate visible buttons (hide tracking button when no units selected and not tracking)
				local selectedUnits = Spring.GetSelectedUnits()
				local hasSelection = #selectedUnits > 0
				local isTracking = interactionState.areTracking ~= nil
				local visibleButtons = {}
				for i = 1, #buttons do
					if buttons[i].command ~= 'pip_track' or hasSelection or isTracking then
						visibleButtons[#visibleButtons + 1] = buttons[i]
					end
				end

				local pressedButton = visibleButtons[1 + math.floor((mx - dim.l) / usedButtonSize)]
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

				if cmdID < 0 and shift then
					-- Start drag-to-build for buildings with shift modifier
					interactionState.areBuildDragging = true
					interactionState.buildDragStartX = mx
					interactionState.buildDragStartY = my
					interactionState.buildDragPositions = {{wx = wx, wz = wz}}
					return true
				else
					-- Single build or non-build command (no forced queue)
					IssueCommandAtPoint(cmdID, wx, wz, false, false)

					if not shift then
						Spring.SetActiveCommand(0)
					end

					return true
				end
			end

			-- No active command - start box selection or panning
			-- Don't start single left-click actions if we're already panning with left+right
			if not interactionState.arePanning then
				if leftButtonPansCamera then
					interactionState.arePanning = true
					interactionState.panStartX = mx
					interactionState.panStartY = my
					interactionState.areTracking = nil
					-- Track initial click position for deselection on release (even if we're panning)
					interactionState.boxSelectStartX = mx
					interactionState.boxSelectStartY = my
					interactionState.boxSelectEndX = mx
					interactionState.boxSelectEndY = my
					Spring.SetMouseCursor('cursornormal', hideCursorWhilePanning and 2 or 1)
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
				local wy = Spring.GetGroundHeight(wx, wz)

				-- Determine the command to use
				local cmdID = activeCmd -- Start with active command (might be FIGHT, ATTACK, or PATROL)
				local overrideTarget = nil

				-- If no active command, determine default based on what's under cursor
				if not cmdID then
					local uID = GetUnitAtPoint(wx, wz)
					if uID then
						if Spring.IsUnitAllied(uID) then
							cmdID = CMD.GUARD
							overrideTarget = uID
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

			return false
		end
	end
end

function widget:MouseMove(mx, my, dx, dy, mButton)
	-- Get modifier key states
	local alt, ctrl, meta, shift = Spring.GetModKeyState()

	-- Check for left+right mouse button combination for panning (if not already panning)
	if interactionState.leftMousePressed and interactionState.rightMousePressed and not interactionState.arePanning and mx >= dim.l and mx <= dim.r and my >= dim.b and my <= dim.t then
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

			-- Start panning
			interactionState.arePanning = true
			interactionState.areTracking = nil
			Spring.SetMouseCursor('cursornormal', hideCursorWhilePanning and 2 or 1)
		end
	end

	-- If middle mouse is pressed but not yet committed to a mode, check if moved
	if interactionState.middleMousePressed and not interactionState.arePanning then
		-- Check if there's actual movement (not just mouse jitter)
		-- Use a small threshold to distinguish click from drag
		if math.abs(dx) > 2 or math.abs(dy) > 2 then
			interactionState.middleMouseMoved = true
			-- Start hold-drag panning
			interactionState.arePanning = true
			interactionState.areTracking = nil
			Spring.SetMouseCursor('cursornormal', hideCursorWhilePanning and 2 or 1)
		end
	end

	-- Alt+Left drag for panning
	if interactionState.leftMousePressed and alt and not interactionState.arePanning and mx >= dim.l and mx <= dim.r and my >= dim.b and my <= dim.t then
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

			-- Start panning
			interactionState.arePanning = true
			interactionState.areTracking = nil
			Spring.SetMouseCursor('cursornormal', hideCursorWhilePanning and 2 or 1)
		end
	end

	if areResizing then
		if dim.r+dx - dim.l >= math.floor(minPanelSize*widgetScale) then dim.r = dim.r + dx end
		if dim.t-dy - dim.b >= math.floor(minPanelSize*widgetScale) then dim.b = dim.b + dy end
		CorrectScreenPosition()
		RecalculateWorldCoordinates()
		RecalculateGroundTextureCoordinates()

		-- Update guishader blur dimensions
		UpdateGuishaderBlur()

		-- Clamp camera position to respect margin after resize
		local pipWidth = dim.r - dim.l
		local pipHeight = dim.t - dim.b
		local visibleWorldWidth = pipWidth / zoom
		local visibleWorldHeight = pipHeight / zoom
		local smallerVisibleDimension = math.min(visibleWorldWidth, visibleWorldHeight)
		local margin = smallerVisibleDimension * mapEdgeMargin

		local minWcx = visibleWorldWidth / 2 - margin
		local maxWcx = mapSizeX - (visibleWorldWidth / 2 - margin)
		local minWcz = visibleWorldHeight / 2 - margin
		local maxWcz = mapSizeZ - (visibleWorldHeight / 2 - margin)

		wcx = math.min(math.max(wcx, minWcx), maxWcx)
		wcz = math.min(math.max(wcz, minWcz), maxWcz)
		targetWcx = wcx
		targetWcz = wcz
		RecalculateWorldCoordinates()
		RecalculateGroundTextureCoordinates()

	elseif interactionState.areDragging then
		dim.l = dim.l + dx
		dim.r = dim.r + dx
		dim.b = dim.b + dy
		dim.t = dim.t + dy
		CorrectScreenPosition()
		RecalculateWorldCoordinates()
		RecalculateGroundTextureCoordinates()

		-- Update guishader blur dimensions
		UpdateGuishaderBlur()

	elseif interactionState.arePanning then
		-- Pan the camera based on mouse movement (only if there's movement)
		if dx ~= 0 or dy ~= 0 then
			-- Calculate the visible world area at current zoom
			local pipWidth = dim.r - dim.l
			local pipHeight = dim.t - dim.b
			local visibleWorldWidth = pipWidth / zoom
			local visibleWorldHeight = pipHeight / zoom

			-- Use the smaller dimension for consistent visual margin
			local smallerVisibleDimension = math.min(visibleWorldWidth, visibleWorldHeight)
			local margin = smallerVisibleDimension * mapEdgeMargin

			-- Calculate min/max camera positions to keep margin from map edges
			local minWcx = visibleWorldWidth / 2 - margin
			local maxWcx = mapSizeX - (visibleWorldWidth / 2 - margin)
			local minWcz = visibleWorldHeight / 2 - margin
			local maxWcz = mapSizeZ - (visibleWorldHeight / 2 - margin)

			-- Apply panning with margin-based limits
			wcx = math.min(math.max(wcx - dx / zoom, minWcx), maxWcx)
			wcz = math.min(math.max(wcz + dy / zoom, minWcz), maxWcz)
			targetWcx, targetWcz = wcx, wcz  -- Panning updates instantly, not smoothly
			RecalculateWorldCoordinates()
			RecalculateGroundTextureCoordinates()

			-- Warp mouse back to center after processing movement
			local centerX = math.floor((dim.l + dim.r) / 2)
			local centerY = math.floor((dim.b + dim.t) / 2)
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
			if mx >= dim.l and mx <= dim.r and my >= dim.b and my <= dim.t then
				local wx, wz = PipToWorldCoords(mx, my)
				local wy = Spring.GetGroundHeight(wx, wz)
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
		if mx >= dim.l and mx <= dim.r and my >= dim.b and my <= dim.t then
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
		local mx, my = Spring.GetMouseState()
		if mx >= dim.l and mx <= dim.r and my >= dim.b and my <= dim.t then
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
			Spring.SetMouseCursor('cursornormal')
		end
	end

	-- Handle single left-click on empty space when using left-button panning mode
	-- Must do this AFTER panning stops but BEFORE we clear button states
	-- In panning mode, no box selection is started, so we need to handle deselection here
	if mButton == 1 and mx >= dim.l and mx <= dim.r and my >= dim.b and my <= dim.t and not inMinMode and leftButtonPansCamera then
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
					if spIsUnitSelected(uID) then
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
					if spIsUnitSelected(uID) then
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
			if mx >= dim.l and mx <= dim.r and my >= dim.b and my <= dim.t then
				local wx, wz = PipToWorldCoords(mx, my)
				local wy = Spring.GetGroundHeight(wx, wz)
				finalPos = {wx, wy, wz}
			end
			WG.customformations.EndFormation(finalPos)
		end

		-- Clear the force shift flag
		WG.pipForceShift = nil
		interactionState.formationDragShouldQueue = false

		-- If it was just a click (not a drag), issue the original command
		if not isDrag and mx >= dim.l and mx <= dim.r and my >= dim.b and my <= dim.t then
			local wx, wz = PipToWorldCoords(mx, my)

			-- Determine the original command
			local cmdID = nil
			local uID = GetUnitAtPoint(wx, wz)
			if uID then
				if Spring.IsUnitAllied(uID) then
					cmdID = CMD.GUARD
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

	areResizing = false
	interactionState.areDragging = false

	-- Handle middle mouse release
	if mButton == 2 then
		if interactionState.middleMousePressed then
			-- Middle mouse was pressed in our window
			if not interactionState.middleMouseMoved then
				-- It was a click without movement - toggle mode
				interactionState.panToggleMode = true
				interactionState.arePanning = true
				interactionState.areTracking = nil
				Spring.SetMouseCursor('cursornormal', hideCursorWhilePanning and 2 or 1)
			else
				-- It was a hold-drag - stop panning
				interactionState.arePanning = false
				Spring.SetMouseCursor('cursornormal')
			end
			interactionState.middleMousePressed = false
			interactionState.middleMouseMoved = false
		elseif interactionState.panToggleMode then
			-- Middle mouse released while in toggle mode (click was outside our window) - ignore
		end
	end

	-- Only stop panning from left button if not in toggle mode AND using leftButtonPansCamera mode
	-- (Don't interfere with left+right button panning which handles its own cleanup above)
	if interactionState.arePanning and not interactionState.panToggleMode and not interactionState.middleMousePressed and leftButtonPansCamera and mButton == 1 then
		Spring.SetMouseCursor('cursornormal')
		interactionState.arePanning = false
	end

	interactionState.areIncreasingZoom = false
	interactionState.areDecreasingZoom = false
end









