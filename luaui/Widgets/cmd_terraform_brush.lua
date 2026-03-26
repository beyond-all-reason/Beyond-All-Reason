local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Terraform Brush",
		desc = "Hover mouse and raise/lower terrain with /terraformup and /terraformdown commands",
		author = "BARb",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

local PACKET_HEADER = "$terraform_brush$"
local RAMP_HEADER = "$terraform_ramp$"
local SPLINE_RAMP_HEADER = "$terraform_ramp_spline$"
local RESTORE_HEADER = "$terraform_restore$"
local IMPORT_HEADER = "$terraform_import$"
local UNDO_HEADER = "$terraform_undo$"
local REDO_HEADER = "$terraform_redo$"
local DEFAULT_RADIUS = 100
local UPDATE_INTERVAL = 0.016

local SendLuaRulesMsg = Spring.SendLuaRulesMsg
local GetMouseState = Spring.GetMouseState
local TraceScreenRay = Spring.TraceScreenRay
local GetGroundHeight = Spring.GetGroundHeight
local Echo = Spring.Echo
local ForceTesselationUpdate = Spring.ForceTesselationUpdate

local glColor = gl.Color
local glLineWidth = gl.LineWidth
local glVertex = gl.Vertex
local glBeginEnd = gl.BeginEnd
local glDrawGroundCircle = gl.DrawGroundCircle
local glCreateList = gl.CreateList
local glCallList = gl.CallList
local glDeleteList = gl.DeleteList
local GL_LINE_LOOP = GL.LINE_LOOP
local GL_LINE_STRIP = GL.LINE_STRIP
local GL_LINES = GL.LINES

local floor = math.floor
local max = math.max
local min = math.min
local cos = math.cos
local sin = math.sin
local abs = math.abs
local pi = math.pi
local ceil = math.ceil
local atan2 = math.atan2
local GetModKeyState = Spring.GetModKeyState
local GetKeyState = Spring.GetKeyState
local KEYSYMS_SPACE = 0x20

local RADIUS_STEP = 8
local ROTATION_STEP = 3
local CURVE_STEP = 0.1
local MAX_RADIUS = 2000
local MIN_RADIUS = 8
local MIN_CURVE = 0.1
local MAX_CURVE = 5.0
local DEFAULT_CURVE = 1.0
local INTENSITY_STEP = 0.1
local MIN_INTENSITY = 0.1
local MAX_INTENSITY = 100.0
local DEFAULT_INTENSITY = 1.0
local CIRCLE_SEGMENTS = 64
local FALLOFF_DISPLAY_HEIGHT = 60
local RING_INNER_RATIO = 0.6
local DEFAULT_LENGTH_SCALE = 1.0
local MIN_LENGTH_SCALE = 0.2
local MAX_LENGTH_SCALE = 5.0
local LENGTH_SCALE_STEP = 0.1
local GRID_SNAP_SIZE = 48  -- matches build grid widget spacing (3 * 16 elmos)

local activeDirection = nil
local activeRadius = DEFAULT_RADIUS
local activeShape = "circle"
local activeRotation = 0
local activeCurve = DEFAULT_CURVE
local activeIntensity = DEFAULT_INTENSITY
local activeLengthScale = DEFAULT_LENGTH_SCALE
local activeMode = nil
local updateTimer = 0
local heightCapMin = nil
local heightCapMax = nil
local heightCapAbsolute = false
local lockedWorldX = nil
local lockedWorldZ = nil
local lockedGroundY = nil
local lastScreenX = nil
local lastScreenY = nil
local rampEndX = nil
local rampEndZ = nil
local rampSplinePoints = {}
local SPLINE_SAMPLE_DIST = 24
local SPLINE_MAX_POINTS = 40
local dragOriginX = nil
local dragOriginZ = nil
local shiftAxis = nil -- "x" or "z" once determined
local shiftOriginX = nil
local shiftOriginZ = nil
local wasShiftHeld = false
local gridShowing = false
local gridOverlayOn = false
local dustEffects = true
local rightMouseHeld = false
local savedModeBeforeRMB = nil
local savedDirectionBeforeRMB = nil
local clayMode = false

-- History slider state
local historyUndoCount = 0
local historyRedoCount = 0

-- Tessellation refresh: force mesh re-tessellation for N frames after heightmap edits
local TESS_DIRTY_FRAMES = 10
local tessellationDirtyFrames = 0

local function markTessellationDirty()
	tessellationDirtyFrames = TESS_DIRTY_FRAMES
end

local function getWorldMousePosition()
	local mx, my = GetMouseState()
	local _, pos = TraceScreenRay(mx, my, true)

	if pos then
		return pos[1], pos[3]
	end

	return nil, nil
end

local AXIS_LOCK_THRESHOLD = 16

-- Find any land unit def for force-showing the build grid
local gridForceShowDefID
for id, def in pairs(UnitDefs) do
	if not def.modCategories or not def.modCategories.underwater then
		gridForceShowDefID = id
		break
	end
end

local function showBuildGrid()
	if gridShowing then return end
	local bg = WG['buildinggrid']
	if bg and bg.setForceShow and gridForceShowDefID then
		bg.setForceShow("terraform", true, gridForceShowDefID)
		gridShowing = true
	end
end

local function hideBuildGrid()
	if not gridShowing then return end
	local bg = WG['buildinggrid']
	if bg and bg.setForceShow then
		bg.setForceShow("terraform", false)
		gridShowing = false
	end
end

local function snapToGrid(x, z)
	return floor(x / GRID_SNAP_SIZE + 0.5) * GRID_SNAP_SIZE,
	       floor(z / GRID_SNAP_SIZE + 0.5) * GRID_SNAP_SIZE
end

local function constrainToAxis(originX, originZ, rawX, rawZ)
	local dx = rawX - originX
	local dz = rawZ - originZ

	if not shiftAxis then
		if abs(dx) > AXIS_LOCK_THRESHOLD or abs(dz) > AXIS_LOCK_THRESHOLD then
			if abs(dx) >= abs(dz) then
				shiftAxis = "x"
			else
				shiftAxis = "z"
			end
		else
			return originX, originZ
		end
	end

	if shiftAxis == "x" then
		return rawX, originZ
	else
		return originX, rawZ
	end
end

local function sendTerraformMessage(direction, worldX, worldZ, radius, shape, rotation, curve)
	local absCapMin, absCapMax
	if heightCapAbsolute then
		absCapMin = heightCapMin and string.format("%.0f", heightCapMin) or "nil"
		absCapMax = heightCapMax and string.format("%.0f", heightCapMax) or "nil"
	else
		absCapMin = (heightCapMin and lockedGroundY) and string.format("%.0f", lockedGroundY + heightCapMin) or "nil"
		absCapMax = (heightCapMax and lockedGroundY) and string.format("%.0f", lockedGroundY + heightCapMax) or "nil"
	end
	local msg = PACKET_HEADER
		.. direction .. " "
		.. floor(worldX) .. " "
		.. floor(worldZ) .. " "
		.. radius .. " "
		.. shape .. " "
		.. rotation .. " "
		.. string.format("%.1f", curve) .. " "
		.. absCapMin .. " "
		.. absCapMax .. " "
		.. string.format("%.1f", activeIntensity) .. " "
		.. string.format("%.1f", activeLengthScale) .. " "
		.. (clayMode and "1" or "0") .. " "
		.. (dustEffects and "1" or "0")
	SendLuaRulesMsg(msg)
	markTessellationDirty()
end

local function parseRadius(args)
	if args and args[1] then
		local radius = tonumber(args[1])
		if radius and radius > 0 then
			return floor(radius)
		end
	end

	return DEFAULT_RADIUS
end

local function activate(direction, mode, args)
	activeDirection = direction
	activeMode = mode
	activeRadius = parseRadius(args)
	if mode == "level" then
		activeCurve = MAX_CURVE
	end
	local modeLabels = { raise = "RAISE", lower = "LOWER", level = "LEVEL", ramp = "RAMP", restore = "RESTORE" }
	local modeLabel = modeLabels[mode] or mode
	Echo("[Terraform Brush] Mode: " .. modeLabel .. " | Radius: " .. activeRadius .. " | Hold left-click to terraform, /terraformoff to stop")
	return true
end

local function activateTerraformUp(_, _, args)
	return activate(1, "raise", args)
end

local function activateTerraformDown(_, _, args)
	return activate(-1, "lower", args)
end

local function activateTerraformLevel(_, _, args)
	return activate(0, "level", args)
end

local function activateTerraformRamp(_, _, args)
	return activate(0, "ramp", args)
end

local function activateTerraformRestore(_, _, args)
	return activate(0, "restore", args)
end

-- Forward declaration
local invalidateDrawCache

local function deactivateTerraform()
	if activeMode then
		Echo("[Terraform Brush] Deactivated")
	end

	invalidateDrawCache()
	activeDirection = nil
	activeMode = nil
	return true
end

local function setMode(mode)
	if mode == "raise" then
		activeDirection = 1
		activeMode = "raise"
	elseif mode == "lower" then
		activeDirection = -1
		activeMode = "lower"
	elseif mode == "level" then
		activeDirection = 0
		activeMode = "level"
		activeCurve = MAX_CURVE
		if activeShape == "ring" then
			activeShape = "circle"
		end
	elseif mode == "ramp" then
		activeDirection = 0
		activeMode = "ramp"
		if activeShape ~= "circle" and activeShape ~= "square" then
			activeShape = "circle"
		end
	elseif mode == "restore" then
		activeDirection = 0
		activeMode = "restore"
	end
end

local function setShape(shape)
	if shape == "circle" or shape == "square" or shape == "ring" or shape == "hexagon" or shape == "octagon" then
		if activeMode == "ramp" and shape ~= "circle" and shape ~= "square" then
			return
		end
		if activeMode == "level" and shape == "ring" then
			return
		end
		activeShape = shape
	end
end

local function rotateBy(degrees)
	activeRotation = (activeRotation + degrees) % 360
end

local function setRotation(degrees)
	activeRotation = degrees % 360
end

local function setCurve(value)
	activeCurve = max(MIN_CURVE, min(MAX_CURVE, value))
end

local function setIntensity(value)
	activeIntensity = max(MIN_INTENSITY, min(MAX_INTENSITY, value))
end

local function setLengthScale(value)
	activeLengthScale = max(MIN_LENGTH_SCALE, min(MAX_LENGTH_SCALE, value))
end

local function setRadius(value)
	activeRadius = max(MIN_RADIUS, min(MAX_RADIUS, floor(value)))
end

local function setHeightCapMin(value)
	heightCapMin = value
end

local function setHeightCapMax(value)
	heightCapMax = value
end

local function setHeightCapAbsolute(value)
	heightCapAbsolute = value
end

local function setClayMode(value)
	clayMode = value and true or false
end

local function setGridOverlay(value)
	gridOverlayOn = value and true or false
	if gridOverlayOn then
		showBuildGrid()
	else
		hideBuildGrid()
	end
end

local function setDustEffects(value)
	dustEffects = value and true or false
end

local function getState()
	return {
		active = activeMode ~= nil,
		mode = activeMode,
		direction = activeDirection,
		radius = activeRadius,
		shape = activeShape,
		rotationDeg = activeRotation,
		curve = activeCurve,
		intensity = activeIntensity,
		lengthScale = activeLengthScale,
		heightCapMin = heightCapMin,
		heightCapMax = heightCapMax,
		heightCapAbsolute = heightCapAbsolute,
		clayMode = clayMode,
		gridOverlay = gridOverlayOn,
		dustEffects = dustEffects,
		undoCount = historyUndoCount,
		redoCount = historyRedoCount,
	}
end

local importHeightRows = nil
local importRowIndex = 0
local IMPORT_ROWS_PER_FRAME = 32
local pendingExport = false

-- Display list cache to avoid rebuilding geometry every frame
local drawCacheList = nil
local drawCacheParams = {}

invalidateDrawCache = function()
	if drawCacheList then
		glDeleteList(drawCacheList)
		drawCacheList = nil
	end
end

local function isDrawCacheValid(worldX, worldZ, groundY)
	local p = drawCacheParams
	return drawCacheList
		and p.worldX == worldX and p.worldZ == worldZ
		and p.groundY == groundY
		and p.shape == activeShape and p.radius == activeRadius
		and p.rotation == activeRotation and p.curve == activeCurve
		and p.lengthScale == activeLengthScale
		and p.mode == activeMode and p.direction == activeDirection
		and p.capMin == heightCapMin and p.capMax == heightCapMax
		and p.capAbsolute == heightCapAbsolute
		and p.lockedX == lockedWorldX and p.lockedZ == lockedWorldZ
		and p.lockedY == lockedGroundY
		and p.rampEndX == rampEndX and p.rampEndZ == rampEndZ
		and p.splineCount == #rampSplinePoints
end

local function updateDrawCacheParams(worldX, worldZ, groundY)
	local p = drawCacheParams
	p.worldX = worldX
	p.worldZ = worldZ
	p.groundY = groundY
	p.shape = activeShape
	p.radius = activeRadius
	p.rotation = activeRotation
	p.curve = activeCurve
	p.lengthScale = activeLengthScale
	p.mode = activeMode
	p.direction = activeDirection
	p.capMin = heightCapMin
	p.capMax = heightCapMax
	p.capAbsolute = heightCapAbsolute
	p.lockedX = lockedWorldX
	p.lockedZ = lockedWorldZ
	p.lockedY = lockedGroundY
	p.rampEndX = rampEndX
	p.rampEndZ = rampEndZ
	p.splineCount = #rampSplinePoints
end

local function exportHeightmap()
	pendingExport = true
	Echo("[Terraform Brush] Export queued, will save on next draw frame...")
end

local function doExportHeightmap()
	local squareSize = Game.squareSize
	local w = Game.mapSizeX / squareSize + 1
	local h = Game.mapSizeZ / squareSize + 1

	local minH, maxH = math.huge, -math.huge
	local heightGrid = {}
	for zi = 0, Game.mapSizeZ, squareSize do
		local row = {}
		for xi = 0, Game.mapSizeX, squareSize do
			local gh = GetGroundHeight(xi, zi)
			if gh < minH then minH = gh end
			if gh > maxH then maxH = gh end
			row[#row + 1] = gh
		end
		heightGrid[#heightGrid + 1] = row
	end

	local heightRange = maxH - minH
	if heightRange < 1 then heightRange = 1 end

	local baseName = "heightmap_export_" .. Game.mapName
	local filename = baseName .. ".png"

	local fboTex = gl.CreateTexture(w, h, {
		border = false,
		min_filter = GL.NEAREST,
		mag_filter = GL.NEAREST,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
		fbo = true,
	})

	if not fboTex then
		Echo("[Terraform Brush] Failed to create FBO texture for export")
		return
	end

	-- Render heights AND save inside same FBO binding (proven pattern from GenEnvLut/GenBrdfLut)
	gl.RenderToTexture(fboTex, function()
		gl.Blending(false)
		gl.DepthTest(false)

		gl.MatrixMode(GL.PROJECTION)
		gl.PushMatrix()
		gl.LoadIdentity()
		gl.MatrixMode(GL.MODELVIEW)
		gl.PushMatrix()
		gl.LoadIdentity()

		gl.BeginEnd(GL.QUADS, function()
			for zi = 1, #heightGrid do
				local row = heightGrid[zi]
				local y0 = (zi - 1) / #heightGrid * 2 - 1
				local y1 = zi / #heightGrid * 2 - 1
				for xi = 1, #row do
					local norm = (row[xi] - minH) / heightRange
					gl.Color(norm, norm, norm, 1)
					local x0 = (xi - 1) / #row * 2 - 1
					local x1 = xi / #row * 2 - 1
					gl.Vertex(x0, y0, 0)
					gl.Vertex(x1, y0, 0)
					gl.Vertex(x1, y1, 0)
					gl.Vertex(x0, y1, 0)
				end
			end
		end)

		gl.MatrixMode(GL.PROJECTION)
		gl.PopMatrix()
		gl.MatrixMode(GL.MODELVIEW)
		gl.PopMatrix()

		-- Save INSIDE the FBO callback (critical!)
		gl.SaveImage(0, 0, w, h, filename, { yflip = false })

		gl.Blending(true)
	end)

	gl.DeleteTexture(fboTex)

	-- Write metadata
	local metaFile = io.open(baseName .. ".txt", "w")
	if metaFile then
		metaFile:write(string.format("%.2f %.2f\n", minH, maxH))
		metaFile:close()
	end

	Echo("[Terraform Brush] Exported to: " .. filename .. " (" .. w .. "x" .. h .. ", range: " .. floor(minH) .. " to " .. floor(maxH) .. ")")
end

local pendingImportFile = nil

local function importHeightmap(_, _, args)
	if not args or not args[1] then
		Echo("[Terraform Brush] Usage: /terraformimport <filename.png>")
		return
	end
	pendingImportFile = args[1]
	Echo("[Terraform Brush] Import queued: " .. pendingImportFile)
end

local function doImportHeightmapRead()
	local filename = pendingImportFile
	pendingImportFile = nil

	local squareSize = Game.squareSize
	local w = Game.mapSizeX / squareSize + 1
	local h = Game.mapSizeZ / squareSize + 1

	-- Load the PNG as a GL texture
	local loaded = gl.Texture(0, filename)
	if not loaded then
		Echo("[Terraform Brush] Failed to load texture: " .. filename)
		return
	end

	local fboTex = gl.CreateTexture(w, h, {
		border = false,
		min_filter = GL.LINEAR,
		mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
		fbo = true,
	})

	if not fboTex then
		Echo("[Terraform Brush] Failed to create FBO for import")
		gl.Texture(0, false)
		return
	end

	-- Render loaded texture to FBO and read pixels in same binding
	local res
	gl.RenderToTexture(fboTex, function()
		gl.Blending(false)
		gl.DepthTest(false)

		gl.MatrixMode(GL.PROJECTION)
		gl.PushMatrix()
		gl.LoadIdentity()
		gl.MatrixMode(GL.MODELVIEW)
		gl.PushMatrix()
		gl.LoadIdentity()

		gl.TexRect(-1, -1, 1, 1, 0, 0, 1, 1)

		gl.MatrixMode(GL.PROJECTION)
		gl.PopMatrix()
		gl.MatrixMode(GL.MODELVIEW)
		gl.PopMatrix()

		res = gl.ReadPixels(0, 0, w, h)

		gl.Blending(true)
	end)

	gl.Texture(0, false)
	gl.DeleteTexture(fboTex)

	if not res then
		Echo("[Terraform Brush] Failed to read pixels from " .. filename)
		return
	end

	-- Read metadata
	local metaBase = filename:gsub("%.png$", ".txt")
	local minH, maxH
	local metaFile = io.open(metaBase, "r")
	if metaFile then
		local content = metaFile:read("*a")
		metaFile:close()
		if content then
			local a, b = content:match("([%-%.%d]+)%s+([%-%.%d]+)")
			minH = tonumber(a)
			maxH = tonumber(b)
		end
	end

	if not minH or not maxH then
		minH = -200
		maxH = 800
		Echo("[Terraform Brush] No metadata file, using default range: " .. minH .. " to " .. maxH)
	end

	local heightRange = maxH - minH
	local columns = {}
	for col = 1, #res do
		local row = res[col]
		local numRows = #row
		local heights = {}
		for rowIdx = 1, numRows do
			local flippedIdx = numRows - rowIdx + 1
			local pixel = row[flippedIdx]
			local grey = (pixel[1] + pixel[2] + pixel[3]) / 3
			heights[rowIdx] = minH + grey * heightRange
		end
		columns[col] = heights
	end

	importHeightRows = columns
	importRowIndex = 0
	Echo("[Terraform Brush] Loaded " .. filename .. " (" .. #res .. "x" .. #res[1] .. "), applying " .. IMPORT_ROWS_PER_FRAME .. " cols/frame...")
end

local function doImportHeightmapSend()
	if not importHeightRows then
		return
	end

	local squareSize = Game.squareSize
	local totalCols = #importHeightRows
	local rowsThisFrame = 0

	while importRowIndex < totalCols and rowsThisFrame < IMPORT_ROWS_PER_FRAME do
		importRowIndex = importRowIndex + 1
		rowsThisFrame = rowsThisFrame + 1

		local heights = importHeightRows[importRowIndex]
		local x = (importRowIndex - 1) * squareSize

		local parts = {}
		for j = 1, #heights do
			parts[j] = string.format("%.0f", heights[j])
		end

		local msg = IMPORT_HEADER .. x .. " " .. table.concat(parts, " ")
		SendLuaRulesMsg(msg)
	end

	markTessellationDirty()

	if importRowIndex >= totalCols then
		Echo("[Terraform Brush] Heightmap import complete!")
		importHeightRows = nil
		importRowIndex = 0
	end
end

function widget:Initialize()
	widgetHandler:AddAction("terraformbrush", function(_, _, args)
		if activeMode then
			return deactivateTerraform()
		else
			return activate(1, "raise", args)
		end
	end, nil, "t")
	widgetHandler:AddAction("terraformup", activateTerraformUp, nil, "t")
	widgetHandler:AddAction("terraformdown", activateTerraformDown, nil, "t")
	widgetHandler:AddAction("terraformlevel", activateTerraformLevel, nil, "t")
	widgetHandler:AddAction("terraformramp", activateTerraformRamp, nil, "t")
	widgetHandler:AddAction("terraformrestore", activateTerraformRestore, nil, "t")
	widgetHandler:AddAction("terraformoff", deactivateTerraform, nil, "t")
	widgetHandler:AddAction("terraformexport", exportHeightmap, nil, "t")
	widgetHandler:AddAction("terraformimport", importHeightmap, nil, "t")

	WG.TerraformBrush = {
		setMode = setMode,
		setShape = setShape,
		rotate = rotateBy,
		setRotation = setRotation,
		setCurve = setCurve,
		setIntensity = setIntensity,
		setLengthScale = setLengthScale,
		setRadius = setRadius,
		setHeightCapMin = setHeightCapMin,
		setHeightCapMax = setHeightCapMax,
		setHeightCapAbsolute = setHeightCapAbsolute,
		setClayMode = setClayMode,
		setGridOverlay = setGridOverlay,
		setDustEffects = setDustEffects,
		getState = getState,
		deactivate = deactivateTerraform,
		undo = function()
			if historyUndoCount > 0 then
				SendLuaRulesMsg(UNDO_HEADER)
			end
		end,
		redo = function()
			if historyRedoCount > 0 then
				SendLuaRulesMsg(REDO_HEADER)
			end
		end,
	}

	widgetHandler:RegisterGlobal("TerraformBrushStackUpdate", function(undoCount, redoCount)
		historyUndoCount = undoCount or 0
		historyRedoCount = redoCount or 0
		markTessellationDirty()
	end)
end

function widget:Shutdown()
	invalidateDrawCache()
	widgetHandler:RemoveAction("terraformbrush")
	widgetHandler:RemoveAction("terraformup")
	widgetHandler:RemoveAction("terraformdown")
	widgetHandler:RemoveAction("terraformlevel")
	widgetHandler:RemoveAction("terraformramp")
	widgetHandler:RemoveAction("terraformrestore")
	widgetHandler:RemoveAction("terraformoff")
	widgetHandler:RemoveAction("terraformexport")
	widgetHandler:RemoveAction("terraformimport")
	widgetHandler:DeregisterGlobal("TerraformBrushStackUpdate")
	hideBuildGrid()
	WG.TerraformBrush = nil
end

local function smoothSplinePoints(points, passes)
	if #points < 3 then return points end
	local result = points
	for _ = 1, (passes or 2) do
		local smoothed = { result[1] }
		for i = 2, #result - 1 do
			smoothed[i] = {
				(result[i - 1][1] + result[i][1] + result[i + 1][1]) / 3,
				(result[i - 1][2] + result[i][2] + result[i + 1][2]) / 3,
			}
		end
		smoothed[#result] = result[#result]
		result = smoothed
	end
	return result
end

local function downsamplePoints(points, maxCount)
	if #points <= maxCount then return points end
	local result = { points[1] }
	local step = (#points - 1) / (maxCount - 1)
	for i = 2, maxCount - 1 do
		local idx = floor(1 + (i - 1) * step + 0.5)
		result[i] = points[idx]
	end
	result[maxCount] = points[#points]
	return result
end

local function getSmoothedSpline()
	local pts = rampSplinePoints
	if #pts < 2 then return pts end
	pts = downsamplePoints(pts, SPLINE_MAX_POINTS)
	return smoothSplinePoints(pts, 2)
end

function widget:Update(dt)
	if not activeMode then
		return
	end

	updateTimer = updateTimer + dt
	if updateTimer < UPDATE_INTERVAL then
		return
	end
	updateTimer = 0

	local mx, my, leftPressed, _, rightPressed = GetMouseState()
	local anyPressed = leftPressed or (rightPressed and rightMouseHeld)
	if not anyPressed then
		lockedWorldX = nil
		lockedWorldZ = nil
		lockedGroundY = nil
		lastScreenX = nil
		lastScreenY = nil
		rampEndX = nil
		rampEndZ = nil
		rampSplinePoints = {}
		dragOriginX = nil
		dragOriginZ = nil
		shiftAxis = nil
		return
	end

	if not lockedWorldX then
		return
	end

	local _, _, _, shift = GetModKeyState()
	if not shift then
		shiftAxis = nil
		shiftOriginX = nil
		shiftOriginZ = nil
	end

	if activeMode == "ramp" then
		if activeShape == "circle" then
			-- Spline ramp: collect path points as user drags
			if mx ~= lastScreenX or my ~= lastScreenY then
				lastScreenX = mx
				lastScreenY = my
				local worldX, worldZ = getWorldMousePosition()
				if worldX then
					local addPoint = true
					if #rampSplinePoints > 0 then
						local last = rampSplinePoints[#rampSplinePoints]
						local dx = worldX - last[1]
						local dz = worldZ - last[2]
						if (dx * dx + dz * dz) < SPLINE_SAMPLE_DIST * SPLINE_SAMPLE_DIST then
							addPoint = false
						end
					end
					if addPoint then
						rampSplinePoints[#rampSplinePoints + 1] = { worldX, worldZ }
					end
					rampEndX = worldX
					rampEndZ = worldZ
				end
			end

			if #rampSplinePoints >= 2 then
				local smoothed = getSmoothedSpline()
				local parts = { SPLINE_RAMP_HEADER, tostring(activeRadius), " ", tostring(#smoothed) }
				for i = 1, #smoothed do
					parts[#parts + 1] = " "
					parts[#parts + 1] = tostring(floor(smoothed[i][1]))
					parts[#parts + 1] = " "
					parts[#parts + 1] = tostring(floor(smoothed[i][2]))
				end
				parts[#parts + 1] = " "
				parts[#parts + 1] = clayMode and "1" or "0"
				parts[#parts + 1] = " "
				parts[#parts + 1] = dustEffects and "1" or "0"
				SendLuaRulesMsg(table.concat(parts))
				markTessellationDirty()
			end
		else
			-- Square ramp: straight line from A to B
			if mx ~= lastScreenX or my ~= lastScreenY then
				lastScreenX = mx
				lastScreenY = my
				local worldX, worldZ = getWorldMousePosition()
				if worldX then
					if shift and (shiftOriginX or dragOriginX) then
						local ox = shiftOriginX or dragOriginX
						local oz = shiftOriginZ or dragOriginZ
						worldX, worldZ = constrainToAxis(ox, oz, worldX, worldZ)
					end
					if shift then
						worldX, worldZ = snapToGrid(worldX, worldZ)
					end
					rampEndX = worldX
					rampEndZ = worldZ
				 end
			end

			if rampEndX then
				local endY = GetGroundHeight(rampEndX, rampEndZ)
				local msg = RAMP_HEADER
					.. floor(lockedWorldX) .. " "
					.. floor(lockedWorldZ) .. " "
					.. string.format("%.0f", lockedGroundY) .. " "
					.. floor(rampEndX) .. " "
					.. floor(rampEndZ) .. " "
					.. string.format("%.0f", endY) .. " "
					.. activeRadius .. " "
					.. (clayMode and "1" or "0") .. " "
					.. (dustEffects and "1" or "0")
				SendLuaRulesMsg(msg)
				markTessellationDirty()
			end
		end
	elseif activeMode == "restore" then
		if mx ~= lastScreenX or my ~= lastScreenY then
			lastScreenX = mx
			lastScreenY = my
			local worldX, worldZ = getWorldMousePosition()
			if worldX then
				if shift and (shiftOriginX or dragOriginX) then
					local ox = shiftOriginX or dragOriginX
					local oz = shiftOriginZ or dragOriginZ
					worldX, worldZ = constrainToAxis(ox, oz, worldX, worldZ)
				end
				if shift then
					worldX, worldZ = snapToGrid(worldX, worldZ)
				end
				lockedWorldX = worldX
				lockedWorldZ = worldZ
			end
		end

		local msg = RESTORE_HEADER
			.. floor(lockedWorldX) .. " "
			.. floor(lockedWorldZ) .. " "
			.. activeRadius .. " "
			.. activeShape .. " "
			.. activeRotation .. " "
			.. string.format("%.1f", activeCurve) .. " "
			.. string.format("%.1f", activeIntensity) .. " "
			.. string.format("%.1f", activeLengthScale)
		SendLuaRulesMsg(msg)
		markTessellationDirty()
	else
		if mx ~= lastScreenX or my ~= lastScreenY then
			lastScreenX = mx
			lastScreenY = my
			local worldX, worldZ = getWorldMousePosition()
			if worldX then
				if shift and (shiftOriginX or dragOriginX) then
					local ox = shiftOriginX or dragOriginX
					local oz = shiftOriginZ or dragOriginZ
					worldX, worldZ = constrainToAxis(ox, oz, worldX, worldZ)
				end
				if shift then
					worldX, worldZ = snapToGrid(worldX, worldZ)
				end
				lockedWorldX = worldX
				lockedWorldZ = worldZ
			end
		end

		sendTerraformMessage(activeDirection, lockedWorldX, lockedWorldZ, activeRadius, activeShape, activeRotation, activeCurve)
	end
end

local function rotatePoint(px, pz, angleDeg)
	local rad = angleDeg * pi / 180
	local cosA = cos(rad)
	local sinA = sin(rad)
	return px * cosA - pz * sinA, px * sinA + pz * cosA
end

local function drawRotatedSquare(cx, cz, radius, angleDeg, lengthScale)
	lengthScale = lengthScale or 1.0
	local corners = {
		{ -radius, -radius * lengthScale },
		{  radius, -radius * lengthScale },
		{  radius,  radius * lengthScale },
		{ -radius,  radius * lengthScale },
	}

	glBeginEnd(GL_LINE_LOOP, function()
		for i = 1, 4 do
			local rx, rz = rotatePoint(corners[i][1], corners[i][2], angleDeg)
			local wx, wz = cx + rx, cz + rz
			local wy = GetGroundHeight(wx, wz)
			glVertex(wx, wy + 4, wz)
		end
	end)
end

local function drawRegularPolygon(cx, cz, radius, angleDeg, numSides, lengthScale)
	lengthScale = lengthScale or 1.0
	local angleStep = 2 * pi / numSides
	local offsetRad = angleDeg * pi / 180
	glBeginEnd(GL_LINE_LOOP, function()
		for i = 0, numSides - 1 do
			local a = i * angleStep
			local lx = cos(a) * radius
			local lz = sin(a) * radius * lengthScale
			local rx, rz = rotatePoint(lx, lz, angleDeg)
			local wx = cx + rx
			local wz = cz + rz
			local wy = GetGroundHeight(wx, wz)
			glVertex(wx, wy + 4, wz)
		end
	end)
end

local function drawRing(cx, cz, radius, angleDeg, lengthScale)
	lengthScale = lengthScale or 1.0
	local groundY = GetGroundHeight(cx, cz)
	if lengthScale == 1.0 then
		glDrawGroundCircle(cx, groundY, cz, radius, CIRCLE_SEGMENTS)
		glDrawGroundCircle(cx, groundY, cz, radius * RING_INNER_RATIO, CIRCLE_SEGMENTS)
	else
		angleDeg = angleDeg or 0
		local innerR = radius * RING_INNER_RATIO
		for _, r in ipairs({radius, innerR}) do
			glBeginEnd(GL_LINE_LOOP, function()
				for i = 0, CIRCLE_SEGMENTS - 1 do
					local a = (i / CIRCLE_SEGMENTS) * 2 * pi
					local lx = cos(a) * r
					local lz = sin(a) * r * lengthScale
					local rx, rz = rotatePoint(lx, lz, angleDeg)
					local wx, wz = cx + rx, cz + rz
					local wy = GetGroundHeight(wx, wz)
					glVertex(wx, wy + 4, wz)
				end
			end)
		end
	end
end

local function getShapeCorners(shape, radius, angleDeg, lengthScale)
	lengthScale = lengthScale or 1.0
	if shape == "circle" or shape == "ring" then
		local corners = {}
		local segments = 32
		for i = 0, segments - 1 do
			local angle = (i / segments) * 2 * pi
			local lx = cos(angle) * radius
			local lz = sin(angle) * radius * lengthScale
			local rx, rz = rotatePoint(lx, lz, angleDeg)
			corners[#corners + 1] = { rx, rz }
		end

		return corners
	elseif shape == "square" then
		local raw = {
			{ -radius, -radius * lengthScale },
			{  radius, -radius * lengthScale },
			{  radius,  radius * lengthScale },
			{ -radius,  radius * lengthScale },
		}
		local corners = {}
		for i = 1, 4 do
			local rx, rz = rotatePoint(raw[i][1], raw[i][2], angleDeg)
			corners[#corners + 1] = { rx, rz }
		end

		return corners
	elseif shape == "hexagon" or shape == "octagon" then
		local numSides = shape == "hexagon" and 6 or 8
		local angleStep = 2 * pi / numSides
		local corners = {}
		for i = 0, numSides - 1 do
			local a = i * angleStep
			local lx = cos(a) * radius
			local lz = sin(a) * radius * lengthScale
			local rx, rz = rotatePoint(lx, lz, angleDeg)
			corners[#corners + 1] = { rx, rz }
		end

		return corners
	end

	return {}
end

local function drawShapeAtHeight(cx, cz, corners, height)
	glBeginEnd(GL_LINE_LOOP, function()
		for i = 1, #corners do
			glVertex(cx + corners[i][1], height, cz + corners[i][2])
		end
	end)
end

local function drawVerticalEdges(cx, cz, corners, bottomY, topY, stride)
	stride = stride or 1
	glBeginEnd(GL_LINES, function()
		for i = 1, #corners, stride do
			local wx = cx + corners[i][1]
			local wz = cz + corners[i][2]
			glVertex(wx, bottomY, wz)
			glVertex(wx, topY, wz)
		end
	end)
end

local function drawPrism(cx, cz, radius, shape, angleDeg, groundY, capMin, capMax, lengthScale)
	local corners = getShapeCorners(shape, radius, angleDeg, lengthScale)
	if #corners == 0 then
		return
	end

	local topY = capMax or groundY
	local botY = capMin or groundY
	local hasCaps = capMin or capMax

	local vertStride = 1
	if #corners > 8 then
		vertStride = math.ceil(#corners / 8)
	end

	if hasCaps then
		if capMax then
			glColor(1.0, 0.6, 0.1, 0.6)
			drawShapeAtHeight(cx, cz, corners, topY)
		end

		if capMin then
			glColor(0.1, 0.6, 1.0, 0.6)
			drawShapeAtHeight(cx, cz, corners, botY)
		end

		glColor(1, 1, 1, 0.2)
		drawVerticalEdges(cx, cz, corners, botY, topY, vertStride)
	end
end

local function drawRingPrism(cx, cz, radius, angleDeg, groundY, capMin, capMax, lengthScale)
	local outerCorners = getShapeCorners("circle", radius, angleDeg, lengthScale)
	local innerCorners = getShapeCorners("circle", radius * RING_INNER_RATIO, angleDeg, lengthScale)

	local topY = capMax or groundY
	local botY = capMin or groundY
	local hasCaps = capMin or capMax

	local vertStride = ceil(#outerCorners / 8)

	if hasCaps then
		if capMax then
			glColor(1.0, 0.6, 0.1, 0.6)
			drawShapeAtHeight(cx, cz, outerCorners, topY)
			drawShapeAtHeight(cx, cz, innerCorners, topY)
		end

		if capMin then
			glColor(0.1, 0.6, 1.0, 0.6)
			drawShapeAtHeight(cx, cz, outerCorners, botY)
			drawShapeAtHeight(cx, cz, innerCorners, botY)
		end

		glColor(1, 1, 1, 0.2)
		drawVerticalEdges(cx, cz, outerCorners, botY, topY, vertStride)
		drawVerticalEdges(cx, cz, innerCorners, botY, topY, vertStride)
	end
end

local function drawFalloffCurveCircle(cx, cz, radius, curvePower, baseY, effectHeight, angleDeg, lengthScale)
	lengthScale = lengthScale or 1.0
	angleDeg = angleDeg or 0
	local segments = 64
	glBeginEnd(GL_LINE_LOOP, function()
		for i = 0, segments - 1 do
			local theta = (i / segments) * 2 * pi
			local nd = cos(theta)
			local rawFalloff = 1 - nd * nd
			if rawFalloff < 0 then rawFalloff = 0 end
			local falloff = rawFalloff ^ curvePower
			local lx = cos(theta) * radius
			local lz = sin(theta) * radius * lengthScale
			local rx, rz = rotatePoint(lx, lz, angleDeg)
			glVertex(cx + rx, baseY + falloff * effectHeight, cz + rz)
		end
	end)
end

local function drawFalloffCurveRing(cx, cz, radius, curvePower, baseY, effectHeight, angleDeg, lengthScale)
	lengthScale = lengthScale or 1.0
	angleDeg = angleDeg or 0
	local midR = radius * (1 + RING_INNER_RATIO) * 0.5
	local segments = 64
	glBeginEnd(GL_LINE_LOOP, function()
		for i = 0, segments - 1 do
			local theta = (i / segments) * 2 * pi
			local nd = cos(theta)
			local rawFalloff = 1 - nd * nd
			if rawFalloff < 0 then rawFalloff = 0 end
			local falloff = rawFalloff ^ curvePower
			local lx = cos(theta) * midR
			local lz = sin(theta) * midR * lengthScale
			local rx, rz = rotatePoint(lx, lz, angleDeg)
			glVertex(cx + rx, baseY + falloff * effectHeight, cz + rz)
		end
	end)
end

local function drawFalloffCurveRegularPoly(cx, cz, radius, angleDeg, numSides, curvePower, baseY, effectHeight, lengthScale)
	lengthScale = lengthScale or 1.0
	local segmentsPerFace = 8
	local angleStep = 2 * pi / numSides
	glBeginEnd(GL_LINE_LOOP, function()
		for side = 0, numSides - 1 do
			local a0 = side * angleStep
			local a1 = (side + 1) * angleStep
			local x0, z0 = cos(a0) * radius, sin(a0) * radius
			local x1, z1 = cos(a1) * radius, sin(a1) * radius
			for i = 0, segmentsPerFace - 1 do
				local t = i / segmentsPerFace
				local lx = x0 + (x1 - x0) * t
				local lz = z0 + (z1 - z0) * t
				local dist = (lx * lx + lz * lz) ^ 0.5
				local angle = atan2(lz, lx)
				if angle < 0 then angle = angle + 2 * pi end
				local aInSector = (angle % angleStep) - angleStep / 2
				local apothem = radius * cos(pi / numSides)
				local edgeDist = apothem / cos(aInSector)
				local nd = dist / edgeDist
				local rawFalloff = 1 - nd
				if rawFalloff < 0 then rawFalloff = 0 end
				local falloff = rawFalloff ^ curvePower
				local slz = lz * lengthScale
				local rx, rz = rotatePoint(lx, slz, angleDeg)
				glVertex(cx + rx, baseY + falloff * effectHeight, cz + rz)
			end
		end
	end)
end

local squareFaces = {
	{ -1, -1,  1, -1 },
	{  1, -1,  1,  1 },
	{  1,  1, -1,  1 },
	{ -1,  1, -1, -1 },
}

local function drawFalloffCurvePoly(cx, cz, faces, radiusX, radiusZ, angleDeg, curvePower, baseY, effectHeight)
	local segmentsPerFace = 12
	glBeginEnd(GL_LINE_LOOP, function()
		for _, face in ipairs(faces) do
			for i = 0, segmentsPerFace - 1 do
				local t = i / segmentsPerFace
				local lx = (face[1] + (face[3] - face[1]) * t) * radiusX
				local lz = (face[2] + (face[4] - face[2]) * t) * radiusZ
				local nd = max(abs(lx) / radiusX, abs(lz) / radiusZ)
				local rawFalloff = 1 - nd
				if rawFalloff < 0 then rawFalloff = 0 end
				local falloff = rawFalloff ^ curvePower
				local rx, rz = rotatePoint(lx, lz, angleDeg)
				glVertex(cx + rx, baseY + falloff * effectHeight, cz + rz)
			end
		end
	end)
end

local function drawRampPreview(startX, startZ, startY, endX, endZ, endY, width)
	local dx = endX - startX
	local dz = endZ - startZ
	local length = (dx * dx + dz * dz) ^ 0.5
	if length < 1 then
		return
	end

	local nx = -dz / length * width
	local nz = dx / length * width

	local c1x, c1z = startX + nx, startZ + nz
	local c2x, c2z = startX - nx, startZ - nz
	local c3x, c3z = endX - nx, endZ - nz
	local c4x, c4z = endX + nx, endZ + nz

	glColor(0.9, 0.7, 0.2, 0.7)
	glLineWidth(2)
	glBeginEnd(GL_LINE_LOOP, function()
		glVertex(c1x, startY + 4, c1z)
		glVertex(c4x, endY + 4, c4z)
		glVertex(c3x, endY + 4, c3z)
		glVertex(c2x, startY + 4, c2z)
	end)

	glColor(0.9, 0.7, 0.2, 0.4)
	glBeginEnd(GL_LINES, function()
		glVertex(startX, startY + 4, startZ)
		glVertex(endX, endY + 4, endZ)
	end)
end

local function drawSplineRampPreview(points, width)
	if #points < 2 then return end

	-- Center line
	glColor(0.9, 0.7, 0.2, 0.7)
	glLineWidth(2)
	glBeginEnd(GL_LINE_STRIP, function()
		for i = 1, #points do
			local y = GetGroundHeight(points[i][1], points[i][2])
			glVertex(points[i][1], y + 4, points[i][2])
		end
	end)

	-- Compute normals per point
	local normals = {}
	for i = 1, #points do
		local nx, nz = 0, 0
		if i < #points then
			local dx = points[i + 1][1] - points[i][1]
			local dz = points[i + 1][2] - points[i][2]
			local len = (dx * dx + dz * dz) ^ 0.5
			if len > 0 then nx, nz = -dz / len, dx / len end
		end
		if i > 1 then
			local dx = points[i][1] - points[i - 1][1]
			local dz = points[i][2] - points[i - 1][2]
			local len = (dx * dx + dz * dz) ^ 0.5
			if len > 0 then
				local n2x, n2z = -dz / len, dx / len
				if i < #points then
					nx = (nx + n2x) * 0.5
					nz = (nz + n2z) * 0.5
					local nlen = (nx * nx + nz * nz) ^ 0.5
					if nlen > 0 then nx, nz = nx / nlen, nz / nlen end
				else
					nx, nz = n2x, n2z
				end
			end
		end
		normals[i] = { nx * width, nz * width }
	end

	-- Left edge
	glColor(0.9, 0.7, 0.2, 0.4)
	glLineWidth(1.5)
	glBeginEnd(GL_LINE_STRIP, function()
		for i = 1, #points do
			local lx = points[i][1] + normals[i][1]
			local lz = points[i][2] + normals[i][2]
			local y = GetGroundHeight(lx, lz)
			glVertex(lx, y + 4, lz)
		end
	end)

	-- Right edge
	glBeginEnd(GL_LINE_STRIP, function()
		for i = 1, #points do
			local rx = points[i][1] - normals[i][1]
			local rz = points[i][2] - normals[i][2]
			local y = GetGroundHeight(rx, rz)
			glVertex(rx, y + 4, rz)
		end
	end)

	-- End caps
	local startY = GetGroundHeight(points[1][1], points[1][2])
	local endY = GetGroundHeight(points[#points][1], points[#points][2])
	glBeginEnd(GL_LINES, function()
		glVertex(points[1][1] + normals[1][1], startY + 4, points[1][2] + normals[1][2])
		glVertex(points[1][1] - normals[1][1], startY + 4, points[1][2] - normals[1][2])
		local n = #points
		glVertex(points[n][1] + normals[n][1], endY + 4, points[n][2] + normals[n][2])
		glVertex(points[n][1] - normals[n][1], endY + 4, points[n][2] - normals[n][2])
	end)
end

function widget:DrawScreen()
	if pendingExport then
		pendingExport = false
		doExportHeightmap()
	end
	if pendingImportFile then
		doImportHeightmapRead()
	end
	if importHeightRows then
		doImportHeightmapSend()
	end
end

function widget:DrawWorld()
	if tessellationDirtyFrames > 0 then
		ForceTesselationUpdate(true)
		tessellationDirtyFrames = tessellationDirtyFrames - 1
	end

	if not activeMode then
		invalidateDrawCache()
		if not gridOverlayOn then
			hideBuildGrid()
		end
		return
	end

	local worldX, worldZ = getWorldMousePosition()
	if not worldX then
		return
	end

	-- Track shift key state for axis-lock origin capture
	local _, _, _, shiftHeld = GetModKeyState()
	if shiftHeld and not wasShiftHeld then
		shiftOriginX = worldX
		shiftOriginZ = worldZ
		shiftAxis = nil
	elseif not shiftHeld and wasShiftHeld then
		shiftOriginX = nil
		shiftOriginZ = nil
		shiftAxis = nil
	end
	wasShiftHeld = shiftHeld

	if shiftOriginX and shiftHeld then
		worldX, worldZ = constrainToAxis(shiftOriginX, shiftOriginZ, worldX, worldZ)
	end

	-- Grid snap + visual when shift is held or overlay is toggled on
	if shiftHeld then
		worldX, worldZ = snapToGrid(worldX, worldZ)
		showBuildGrid()
	elseif gridOverlayOn then
		showBuildGrid()
	else
		hideBuildGrid()
	end

	local groundY = GetGroundHeight(worldX, worldZ)

	-- Reuse cached display list when nothing changed
	if isDrawCacheValid(worldX, worldZ, groundY) then
		glCallList(drawCacheList)
	else
		invalidateDrawCache()
		drawCacheList = glCreateList(function()
		if activeMode == "ramp" then
			glColor(0.9, 0.7, 0.2, 0.7)
			glLineWidth(2)

			if activeShape == "circle" then
				-- Spline ramp preview
				glDrawGroundCircle(worldX, groundY, worldZ, activeRadius, CIRCLE_SEGMENTS)
				if #rampSplinePoints >= 2 then
					local smoothed = getSmoothedSpline()
					drawSplineRampPreview(smoothed, activeRadius)
				elseif lockedWorldX then
					-- Only start point locked, show line to cursor
					drawRampPreview(lockedWorldX, lockedWorldZ, lockedGroundY, worldX, worldZ, groundY, activeRadius)
				end
			else
				-- Square straight ramp preview
				glDrawGroundCircle(worldX, groundY, worldZ, activeRadius, CIRCLE_SEGMENTS)
				if lockedWorldX and rampEndX then
					local endY = GetGroundHeight(rampEndX, rampEndZ)
					drawRampPreview(lockedWorldX, lockedWorldZ, lockedGroundY, rampEndX, rampEndZ, endY, activeRadius)
				elseif lockedWorldX then
					drawRampPreview(lockedWorldX, lockedWorldZ, lockedGroundY, worldX, worldZ, groundY, activeRadius)
				end
			end

			glColor(1, 1, 1, 1)
			glLineWidth(1)
			return
		end

		if activeMode == "raise" then
			glColor(0.2, 0.8, 0.2, 0.7)
		elseif activeMode == "lower" then
			glColor(0.8, 0.2, 0.2, 0.7)
		elseif activeMode == "restore" then
			glColor(0.7, 0.3, 0.9, 0.7)
		else
			glColor(0.3, 0.5, 0.9, 0.7)
		end

		glLineWidth(2)

		if activeShape == "circle" then
			if activeLengthScale ~= 1.0 then
				drawRegularPolygon(worldX, worldZ, activeRadius, activeRotation, CIRCLE_SEGMENTS, activeLengthScale)
			else
				glDrawGroundCircle(worldX, groundY, worldZ, activeRadius, CIRCLE_SEGMENTS)
			end
		elseif activeShape == "square" then
			drawRotatedSquare(worldX, worldZ, activeRadius, activeRotation, activeLengthScale)
		elseif activeShape == "hexagon" then
			drawRegularPolygon(worldX, worldZ, activeRadius, activeRotation, 6, activeLengthScale)
		elseif activeShape == "octagon" then
			drawRegularPolygon(worldX, worldZ, activeRadius, activeRotation, 8, activeLengthScale)
		elseif activeShape == "ring" then
			drawRing(worldX, worldZ, activeRadius, activeRotation, activeLengthScale)
		end

		if heightCapMin or heightCapMax then
			glLineWidth(1.5)
			local refY = lockedGroundY or groundY
			local absCapMin, absCapMax
			if heightCapAbsolute then
				absCapMin = heightCapMin and heightCapMin or nil
				absCapMax = heightCapMax and heightCapMax or nil
			else
				absCapMin = heightCapMin and (refY + heightCapMin) or nil
				absCapMax = heightCapMax and (refY + heightCapMax) or nil
			end
			local drawX = lockedWorldX or worldX
			local drawZ = lockedWorldZ or worldZ

			if activeShape == "ring" then
				drawRingPrism(drawX, drawZ, activeRadius, activeRotation, refY, absCapMin, absCapMax, activeLengthScale)
			else
				drawPrism(drawX, drawZ, activeRadius, activeShape, activeRotation, refY, absCapMin, absCapMax, activeLengthScale)
			end
		end

		local dir = activeDirection ~= 0 and activeDirection or 1
		local effectHeight = FALLOFF_DISPLAY_HEIGHT
		if heightCapMax and dir > 0 then
			effectHeight = heightCapMax
		elseif heightCapMin and dir < 0 then
			effectHeight = -heightCapMin
		end
		effectHeight = effectHeight * dir

		glColor(1.0, 0.15, 0.15, 0.9)
		glLineWidth(2)

		if activeShape == "circle" then
			drawFalloffCurveCircle(worldX, worldZ, activeRadius, activeCurve, groundY, effectHeight, activeRotation, activeLengthScale)
		elseif activeShape == "square" then
			drawFalloffCurvePoly(worldX, worldZ, squareFaces, activeRadius, activeRadius * activeLengthScale, activeRotation, activeCurve, groundY, effectHeight)
		elseif activeShape == "hexagon" then
			drawFalloffCurveRegularPoly(worldX, worldZ, activeRadius, activeRotation, 6, activeCurve, groundY, effectHeight, activeLengthScale)
		elseif activeShape == "octagon" then
			drawFalloffCurveRegularPoly(worldX, worldZ, activeRadius, activeRotation, 8, activeCurve, groundY, effectHeight, activeLengthScale)
		elseif activeShape == "ring" then
			drawFalloffCurveRing(worldX, worldZ, activeRadius, activeCurve, groundY, effectHeight, activeRotation, activeLengthScale)
		end

		glColor(1, 1, 1, 1)
		glLineWidth(1)
		end)
		updateDrawCacheParams(worldX, worldZ, groundY)
		glCallList(drawCacheList)
	end

	-- Draw axis-lock indicator line following terrain
	if shiftAxis and shiftHeld then
		local AXIS_STEP = 16
		local AXIS_OFFSET = 4
		local mapX = Game.mapSizeX
		local mapZ = Game.mapSizeZ
		glColor(1.0, 1.0, 0.4, 0.85)
		glLineWidth(3)
		gl.DepthTest(GL.ALWAYS)
		gl.DepthMask(false)
		glBeginEnd(GL_LINE_STRIP, function()
			if shiftAxis == "x" then
				for x = 0, mapX, AXIS_STEP do
					glVertex(x, GetGroundHeight(x, worldZ) + AXIS_OFFSET, worldZ)
				end
			else
				for z = 0, mapZ, AXIS_STEP do
					glVertex(worldX, GetGroundHeight(worldX, z) + AXIS_OFFSET, z)
				end
			end
		end)
		gl.DepthTest(false)
		gl.DepthMask(true)
		glColor(1, 1, 1, 1)
		glLineWidth(1)
	end
end

function widget:KeyPress(key, mods, isRepeat)
	if not activeMode then return false end
	if mods.ctrl and key == 122 then -- Ctrl+Z
		if mods.shift then
			SendLuaRulesMsg(REDO_HEADER)
			Echo("[Terraform Brush] Redo")
		else
			SendLuaRulesMsg(UNDO_HEADER)
			Echo("[Terraform Brush] Undo")
		end
		return true
	end

	if not mods.ctrl and not mods.alt then
		if key == 99 then -- C: circle
			setShape("circle")
			return true
		elseif key == 115 then -- S: square
			setShape("square")
			return true
		elseif key == 104 then -- H: hexagon
			setShape("hexagon")
			return true
		elseif key == 111 then -- O: octagon
			setShape("octagon")
			return true
		elseif key == 114 then -- R: ramp
			setMode("ramp")
			return true
		elseif key == 101 then -- E: restore
			setMode("restore")
			return true
		elseif key == 108 then -- L: level
			setMode("level")
			return true
		end
	end

	return false
end

function widget:MousePress(mx, my, button)
	if not activeMode then
		return false
	end

	if button == 1 then
		local worldX, worldZ = getWorldMousePosition()
		if worldX then
			lockedWorldX = worldX
			lockedWorldZ = worldZ
			lockedGroundY = GetGroundHeight(worldX, worldZ)
			lastScreenX = mx
			lastScreenY = my
			dragOriginX = worldX
			dragOriginZ = worldZ
			-- If shift already held, use existing shift origin for drag
			if shiftOriginX then
				dragOriginX = shiftOriginX
				dragOriginZ = shiftOriginZ
			end
			-- Initialize spline points for circle+ramp
			if activeMode == "ramp" and activeShape == "circle" then
				rampSplinePoints = { { worldX, worldZ } }
			end
		end

		return true
	end

	if button == 3 then
		if not rightMouseHeld then
			savedModeBeforeRMB = activeMode
			savedDirectionBeforeRMB = activeDirection
			rightMouseHeld = true
			setMode("lower")
		end
		local worldX, worldZ = getWorldMousePosition()
		if worldX then
			lockedWorldX = worldX
			lockedWorldZ = worldZ
			lockedGroundY = GetGroundHeight(worldX, worldZ)
			lastScreenX = mx
			lastScreenY = my
			dragOriginX = worldX
			dragOriginZ = worldZ
		end
		return true
	end

	return false
end

function widget:MouseRelease(mx, my, button)
	if button == 3 and rightMouseHeld then
		rightMouseHeld = false
		if savedModeBeforeRMB then
			setMode(savedModeBeforeRMB)
		else
			activeMode = nil
			activeDirection = nil
		end
		savedModeBeforeRMB = nil
		savedDirectionBeforeRMB = nil
		lockedWorldX = nil
		lockedWorldZ = nil
		lockedGroundY = nil
		return true
	end
	return false
end

function widget:MouseWheel(up, value)
	if not activeMode then
		return false
	end

	local alt, ctrl, _, shift = GetModKeyState()
	if alt and ctrl then
		if up then
			setLengthScale(activeLengthScale + LENGTH_SCALE_STEP)
		else
			setLengthScale(activeLengthScale - LENGTH_SCALE_STEP)
		end

		Echo("[Terraform Brush] Length: " .. string.format("%.1f", activeLengthScale))
		return true
	end

	if alt then
		if up then
			activeRotation = (activeRotation + ROTATION_STEP) % 360
		else
			activeRotation = (activeRotation - ROTATION_STEP) % 360
		end

		Echo("[Terraform Brush] Rotation: " .. activeRotation .. "°")
		return true
	end

	if shift then
		if up then
			activeCurve = min(MAX_CURVE, activeCurve + CURVE_STEP)
		else
			activeCurve = max(MIN_CURVE, activeCurve - CURVE_STEP)
		end

		activeCurve = floor(activeCurve * 10 + 0.5) / 10
		Echo("[Terraform Brush] Curve: " .. string.format("%.1f", activeCurve) .. " (flat ← 1.0 → sharp)")
		return true
	end

	local spaceHeld = GetKeyState(KEYSYMS_SPACE)
	if spaceHeld then
		if up then
			local newI = activeIntensity * 1.15
			if newI < activeIntensity + 0.1 then newI = activeIntensity + 0.1 end
			setIntensity(newI)
		else
			local newI = activeIntensity / 1.15
			if newI > activeIntensity - 0.1 then newI = activeIntensity - 0.1 end
			setIntensity(newI)
		end

		Echo("[Terraform Brush] Intensity: " .. string.format("%.1f", activeIntensity))
		return true
	end

	if not ctrl then
		return false
	end

	if up then
		activeRadius = min(MAX_RADIUS, activeRadius + RADIUS_STEP)
	else
		activeRadius = max(MIN_RADIUS, activeRadius - RADIUS_STEP)
	end

	Echo("[Terraform Brush] Radius: " .. activeRadius)
	return true
end
