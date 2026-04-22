function widget:GetInfo()
	return {
		name    = "Light Placer",
		desc    = "Brush tool for placing, arranging, and removing deferred GL4 lights on the map",
		author  = "BARb",
		date    = "2026",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true,
	}
end

----------------------------------------------------------------
-- Localize engine calls
----------------------------------------------------------------
local Echo             = Spring.Echo
local GetMouseState    = Spring.GetMouseState
local GetModKeyState   = Spring.GetModKeyState
local GetKeyState      = Spring.GetKeyState
local TraceScreenRay   = Spring.TraceScreenRay
local GetGroundHeight  = Spring.GetGroundHeight
local GetGroundNormal  = Spring.GetGroundNormal
local GetGameFrame     = Spring.GetGameFrame
local GetMapSize       = Spring.GetMapInfo  -- fallback: Game.mapSizeX / Game.mapSizeZ

local glColor     = gl.Color
local glLineWidth = gl.LineWidth
local glBeginEnd  = gl.BeginEnd
local glVertex    = gl.Vertex
local glPushMatrix  = gl.PushMatrix
local glPopMatrix   = gl.PopMatrix
local glTranslate   = gl.Translate
local glDepthTest   = gl.DepthTest
local GL_LINES      = GL.LINES
local GL_LINE_LOOP  = GL.LINE_LOOP

----------------------------------------------------------------
-- Constants
----------------------------------------------------------------
local SAVE_DIR = "lightmaps/"

local CIRCLE_SEGMENTS  = 48
local DEFAULT_RADIUS   = 200
local MIN_RADIUS       = 8
local MAX_RADIUS       = 2000
local RADIUS_STEP      = 8
local ROTATION_STEP    = 3
local COLOR_STEP       = 0.05
local BRIGHTNESS_STEP  = 0.1
local LIGHT_RADIUS_STEP = 10
local ELEVATION_STEP   = 5
local KEYSYMS_SPACE    = 0x20
local UPDATE_INTERVAL  = 1 / 30

local floor = math.floor
local max   = math.max
local min   = math.min
local cos   = math.cos
local sin   = math.sin
local pi    = math.pi
local sqrt  = math.sqrt
local rad   = math.rad
local atan2 = math.atan2

----------------------------------------------------------------
-- Light type defaults
----------------------------------------------------------------
local LIGHT_DEFAULTS = {
	point = {
		radius     = 300,
		color      = { 1.0, 0.9, 0.7 },
		brightness = 0.5,
		modelfactor = 1.0,
		specular   = 1.0,
		scattering = 1.0,
		lensflare  = 0.0,
	},
	cone = {
		radius     = 500,
		color      = { 1.0, 0.95, 0.8 },
		brightness = 0.5,
		modelfactor = 1.0,
		specular   = 1.0,
		scattering = 1.0,
		lensflare  = 0.0,
		theta      = 0.5,   -- half-angle radians (~28 degrees)
		pitch      = -90,   -- degrees, pointing straight down by default
		yaw        = 0,
		roll       = 0,
	},
	beam = {
		radius     = 200,
		color      = { 0.8, 0.9, 1.0 },
		brightness = 0.5,
		modelfactor = 1.0,
		specular   = 1.0,
		scattering = 1.0,
		lensflare  = 0.0,
		beamLength = 300,
		pitch      = 0,
		yaw        = 0,
		roll       = 0,
	},
}

----------------------------------------------------------------
-- State
----------------------------------------------------------------
local lp = {
	active        = false,
	mode          = nil,        -- "point", "scatter", "remove"
	lightType     = "point",    -- "point", "cone", "beam"
	shape         = "circle",
	radius        = DEFAULT_RADIUS,
	rotation      = 0,
	lightCount    = 5,
	cadence       = 50,
	distribution  = "random",   -- "random", "regular", "clustered"

	-- Light parameters (current)
	lightRadius     = 300,
	color           = { 1.0, 0.9, 0.7 },
	brightness      = 0.5,
	modelfactor     = 1.0,
	specular        = 1.0,
	scattering      = 1.0,
	lensflare       = 0.0,

	-- Cone/beam direction (Euler angles in degrees)
	pitch           = -45,
	yaw             = 0,
	roll            = 0,

	-- Cone specific
	theta           = 0.5,

	-- Beam specific
	beamLength      = 300,

	-- Elevation offset above ground
	elevation       = 20,

	-- Smart filter
	smartEnabled  = false,
	smartFilters  = {
		avoidWater   = true,
		avoidCliffs  = true,
		slopeMax     = 45,
		preferSlopes = false,
		slopeMin     = 10,
		altMinEnable = false,
		altMin       = 0,
		altMaxEnable = false,
		altMax       = 200,
	},

	dragging      = false,
	dragAction    = nil,
	placeTimer    = 0,

	-- For gizmo support (Phase 4)
	selectedLight = nil,
}

local updateTimer = 0

-- Cursor preview light (removed when deactivated or position changes enough)
local previewLight   = { id = nil, shape = nil }
local previewLastHash = nil

-- Pending preset: when set, MousePress places this entire preset at cursor
-- and the preview shows the composite of preset lights following the cursor.
local pendingPreset      = nil   -- presetData (with .lights array) or nil
local presetPreviewLights = {}   -- array of { shape, id }
local presetPreviewHash   = nil

----------------------------------------------------------------
-- Builtin presets
----------------------------------------------------------------
local BUILTIN_PRESETS = {
	{
		name = "Fireflies",
		desc = "20 small warm yellow-green point lights scattered loosely",
		lights = (function()
			local t = {}
			for i = 1, 20 do
				local angle = (i / 20) * 2 * pi + (i % 3) * 0.4
				local dist = 60 + (i * 23) % 160
				t[i] = {
					type = "point", offsetX = cos(angle) * dist, offsetZ = sin(angle) * dist,
					radius = 25 + (i % 5) * 8, color = { 0.6 + (i % 3) * 0.1, 0.8, 0.25 + (i % 4) * 0.05 },
					brightness = 0.15 + (i % 4) * 0.05, modelfactor = 1, specular = 0.1, scattering = 0.8, lensflare = 0.15,
				}
			end
			return t
		end)(),
	},
	{
		name = "Campfire",
		desc = "1 large warm orange core + 5 small red-orange embers",
		lights = {
			{ type = "point", offsetX = 0, offsetZ = 0, radius = 120, color = { 1.0, 0.55, 0.15 }, brightness = 1.5, modelfactor = 1, specular = 0.5, scattering = 1.2, lensflare = 0.3 },
			{ type = "point", offsetX = 20, offsetZ = 15, radius = 35, color = { 1.0, 0.3, 0.1 }, brightness = 0.6, modelfactor = 1, specular = 0.2, scattering = 0.5, lensflare = 0 },
			{ type = "point", offsetX = -25, offsetZ = 10, radius = 30, color = { 1.0, 0.35, 0.08 }, brightness = 0.5, modelfactor = 1, specular = 0.2, scattering = 0.5, lensflare = 0 },
			{ type = "point", offsetX = 5, offsetZ = -20, radius = 32, color = { 1.0, 0.4, 0.12 }, brightness = 0.55, modelfactor = 1, specular = 0.2, scattering = 0.5, lensflare = 0 },
			{ type = "point", offsetX = -15, offsetZ = -18, radius = 28, color = { 1.0, 0.32, 0.1 }, brightness = 0.4, modelfactor = 1, specular = 0.15, scattering = 0.4, lensflare = 0 },
			{ type = "point", offsetX = 30, offsetZ = -5, radius = 30, color = { 1.0, 0.38, 0.1 }, brightness = 0.5, modelfactor = 1, specular = 0.2, scattering = 0.5, lensflare = 0 },
		},
	},
	{
		name = "Spotlight Stage",
		desc = "3 colored cone lights at 120-degree spacing pointing down",
		lights = {
			{ type = "cone", offsetX = 0, offsetZ = -80, radius = 300, color = { 1.0, 0.2, 0.2 }, brightness = 2.0, modelfactor = 1, specular = 1.0, scattering = 0.3, lensflare = 0.5, theta = 0.3, pitch = -80, yaw = 0, roll = 0 },
			{ type = "cone", offsetX = 69, offsetZ = 40, radius = 300, color = { 0.2, 1.0, 0.2 }, brightness = 2.0, modelfactor = 1, specular = 1.0, scattering = 0.3, lensflare = 0.5, theta = 0.3, pitch = -80, yaw = 120, roll = 0 },
			{ type = "cone", offsetX = -69, offsetZ = 40, radius = 300, color = { 0.2, 0.3, 1.0 }, brightness = 2.0, modelfactor = 1, specular = 1.0, scattering = 0.3, lensflare = 0.5, theta = 0.3, pitch = -80, yaw = 240, roll = 0 },
		},
	},
	{
		name = "Bioluminescent Pool",
		desc = "8 teal point lights in a ring pattern",
		lights = (function()
			local t = {}
			for i = 1, 8 do
				local angle = (i / 8) * 2 * pi
				t[i] = {
					type = "point", offsetX = cos(angle) * 100, offsetZ = sin(angle) * 100,
					radius = 60, color = { 0.1, 0.7, 0.65 },
					brightness = 0.6, modelfactor = 1, specular = 0.3, scattering = 1.2, lensflare = 0.1,
				}
			end
			return t
		end)(),
	},
}

----------------------------------------------------------------
-- Placed lights tracking
----------------------------------------------------------------
local placedLights = {}    -- { [instanceID] = lightDef }
local nextLightID  = 1
local undoStack    = {}    -- { { action="add"|"remove", lights={...} }, ... }
local redoStack    = {}
local MAX_UNDO     = 100

----------------------------------------------------------------
-- Utility: Euler angles to direction vector
----------------------------------------------------------------
local function eulerToDirection(pitchDeg, yawDeg)
	local p = rad(pitchDeg)
	local y = rad(yawDeg)
	local dx = cos(p) * sin(y)
	local dy = sin(p)
	local dz = cos(p) * cos(y)
	return dx, dy, dz
end

----------------------------------------------------------------
-- Utility: Beam endpoint from position, angles, and length
----------------------------------------------------------------
local function beamEndpoint(px, py, pz, pitchDeg, yawDeg, length)
	local dx, dy, dz = eulerToDirection(pitchDeg, yawDeg)
	return px + dx * length, py + dy * length, pz + dz * length
end

----------------------------------------------------------------
-- Utility: shape containment test
----------------------------------------------------------------
local function isInsideShape(dx, dz, radius, shape, rotDeg)
	if shape == "circle" then
		return dx * dx + dz * dz <= radius * radius
	end
	-- Rotate point by -rotation to test in axis-aligned space
	local rotRad = rad(-rotDeg)
	local c, s = cos(rotRad), sin(rotRad)
	local rx = dx * c - dz * s
	local rz = dx * s + dz * c
	if shape == "square" then
		return math.abs(rx) <= radius and math.abs(rz) <= radius
	end
	-- Default to circle
	return dx * dx + dz * dz <= radius * radius
end

----------------------------------------------------------------
-- Utility: smart filter check
----------------------------------------------------------------
local function isPointValid(px, pz, sf)
	local h = GetGroundHeight(px, pz)
	if sf.avoidWater and h < 0 then return false end
	local _, ny = GetGroundNormal(px, pz)
	if ny then
		local slopeAngle = math.acos(min(ny, 1.0)) * 180 / pi
		if sf.avoidCliffs and slopeAngle > sf.slopeMax then return false end
		if sf.preferSlopes and slopeAngle < sf.slopeMin then return false end
	end
	if sf.altMinEnable and h < sf.altMin then return false end
	if sf.altMaxEnable and h > sf.altMax then return false end
	return true
end

----------------------------------------------------------------
-- Utility: generate scatter positions
----------------------------------------------------------------
local function generateScatterPositions(cx, cz, radius, count, shape, rotDeg, distribution)
	local positions = {}
	if distribution == "random" then
		local attempts = 0
		while #positions < count and attempts < count * 10 do
			local dx = (math.random() * 2 - 1) * radius
			local dz = (math.random() * 2 - 1) * radius
			if isInsideShape(dx, dz, radius, shape, rotDeg) then
				positions[#positions + 1] = { cx + dx, cz + dz }
			end
			attempts = attempts + 1
		end
	elseif distribution == "regular" then
		local spacing = radius * 2 / max(math.ceil(sqrt(count)), 1)
		local halfR = radius
		local placed = 0
		local gz = -halfR
		while gz <= halfR and placed < count do
			local gx = -halfR
			while gx <= halfR and placed < count do
				if isInsideShape(gx, gz, radius, shape, rotDeg) then
					positions[#positions + 1] = { cx + gx, cz + gz }
					placed = placed + 1
				end
				gx = gx + spacing
			end
			gz = gz + spacing
		end
	elseif distribution == "clustered" then
		local clusterCount = max(floor(count / 4), 1)
		local perCluster = max(floor(count / clusterCount), 1)
		for _ = 1, clusterCount do
			local cdx = (math.random() * 2 - 1) * radius * 0.6
			local cdz = (math.random() * 2 - 1) * radius * 0.6
			if isInsideShape(cdx, cdz, radius, shape, rotDeg) then
				for _ = 1, perCluster do
					local ox = cdx + (math.random() * 2 - 1) * radius * 0.25
					local oz = cdz + (math.random() * 2 - 1) * radius * 0.25
					if isInsideShape(ox, oz, radius, shape, rotDeg) then
						positions[#positions + 1] = { cx + ox, cz + oz }
					end
				end
			end
		end
	end
	return positions
end

----------------------------------------------------------------
-- Add a single GL4 deferred light and track it
----------------------------------------------------------------
local function addOneLight(px, pz, lightDef)
	local lightsAPI = WG['lightsgl4']
	if not lightsAPI then return nil end

	local py = GetGroundHeight(px, pz)
	if not py then py = 0 end
	-- Elevate above ground by user-configurable offset
	py = py + lp.elevation

	local r = lightDef.color[1] * lightDef.brightness
	local g = lightDef.color[2] * lightDef.brightness
	local b = lightDef.color[3] * lightDef.brightness

	local instanceID
	if lightDef.type == "point" then
		instanceID = lightsAPI.AddPointLight(
			nil, nil, nil, nil,
			px, py, pz, lightDef.radius,
			r, g, b, 1.0,
			0, 0, 0, 0,
			lightDef.modelfactor, lightDef.specular, lightDef.scattering, lightDef.lensflare,
			nil, 0, 1, 0
		)
	elseif lightDef.type == "cone" then
		local dx, dy, dz = eulerToDirection(lightDef.pitch or -90, lightDef.yaw or 0)
		instanceID = lightsAPI.AddConeLight(
			nil, nil, nil, nil,
			px, py, pz, lightDef.radius,
			r, g, b, 1.0,
			dx, dy, dz, lightDef.theta or 0.5, 0,
			lightDef.modelfactor, lightDef.specular, lightDef.scattering, lightDef.lensflare,
			nil, 0, 1, 0
		)
	elseif lightDef.type == "beam" then
		local ex, ey, ez = beamEndpoint(px, py, pz, lightDef.pitch or 0, lightDef.yaw or 0, lightDef.beamLength or 300)
		instanceID = lightsAPI.AddBeamLight(
			nil, nil, nil, nil,
			px, py, pz, lightDef.radius,
			r, g, b, 1.0,
			ex, ey, ez, lightDef.radius, 0,
			lightDef.modelfactor, lightDef.specular, lightDef.scattering, lightDef.lensflare,
			nil, 0, 1, 0
		)
	end

	if instanceID then
		local record = {
			instanceID  = instanceID,
			type        = lightDef.type,
			pos         = { px, py, pz },
			radius      = lightDef.radius,
			color       = { lightDef.color[1], lightDef.color[2], lightDef.color[3] },
			brightness  = lightDef.brightness,
			modelfactor = lightDef.modelfactor,
			specular    = lightDef.specular,
			scattering  = lightDef.scattering,
			lensflare   = lightDef.lensflare,
			pitch       = lightDef.pitch,
			yaw         = lightDef.yaw,
			roll        = lightDef.roll,
			theta       = lightDef.theta,
			beamLength  = lightDef.beamLength,
			elevation   = lp.elevation,
			animation   = nil, -- reserved for Phase 3
		}
		placedLights[instanceID] = record
		return record
	end
	return nil
end

----------------------------------------------------------------
-- Remove a placed light from the deferred renderer
----------------------------------------------------------------
local function removeOneLight(instanceID)
	local lightsAPI = WG['lightsgl4']
	if not lightsAPI then return end
	local record = placedLights[instanceID]
	if not record then return end

	local lightShape
	if record.type == "point" then
		lightShape = "point"
	elseif record.type == "cone" then
		lightShape = "cone"
	elseif record.type == "beam" then
		lightShape = "beam"
	end
	lightsAPI.RemoveLight(lightShape, instanceID, nil)
	placedLights[instanceID] = nil
end

----------------------------------------------------------------
-- Build current light definition from state
----------------------------------------------------------------
local function buildLightDef()
	return {
		type        = lp.lightType,
		radius      = lp.lightRadius,
		color       = { lp.color[1], lp.color[2], lp.color[3] },
		brightness  = lp.brightness,
		modelfactor = lp.modelfactor,
		specular    = lp.specular,
		scattering  = lp.scattering,
		lensflare   = lp.lensflare,
		pitch       = lp.pitch,
		yaw         = lp.yaw,
		roll        = lp.roll,
		theta       = lp.theta,
		beamLength  = lp.beamLength,
	}
end

----------------------------------------------------------------
-- Undo / Redo
----------------------------------------------------------------
local function pushUndo(action, lights)
	if #undoStack >= MAX_UNDO then
		table.remove(undoStack, 1)
	end
	undoStack[#undoStack + 1] = { action = action, lights = lights }
	redoStack = {}
end

local function doUndo()
	if #undoStack == 0 then return end
	local entry = undoStack[#undoStack]
	undoStack[#undoStack] = nil

	if entry.action == "add" then
		local removed = {}
		for _, rec in ipairs(entry.lights) do
			if placedLights[rec.instanceID] then
				removed[#removed + 1] = placedLights[rec.instanceID]
				removeOneLight(rec.instanceID)
			end
		end
		redoStack[#redoStack + 1] = { action = "add", lights = removed }
	elseif entry.action == "remove" then
		local restored = {}
		for _, rec in ipairs(entry.lights) do
			local newRec = addOneLight(rec.pos[1], rec.pos[3], rec)
			if newRec then
				restored[#restored + 1] = newRec
			end
		end
		redoStack[#redoStack + 1] = { action = "remove", lights = restored }
	end
end

local function doRedo()
	if #redoStack == 0 then return end
	local entry = redoStack[#redoStack]
	redoStack[#redoStack] = nil

	if entry.action == "add" then
		-- Redo an add = re-place the lights that were removed by undo
		local restored = {}
		for _, rec in ipairs(entry.lights) do
			local newRec = addOneLight(rec.pos[1], rec.pos[3], rec)
			if newRec then
				restored[#restored + 1] = newRec
			end
		end
		undoStack[#undoStack + 1] = { action = "add", lights = restored }
	elseif entry.action == "remove" then
		-- Redo a remove = re-remove the lights that were restored by undo
		local removed = {}
		for _, rec in ipairs(entry.lights) do
			if placedLights[rec.instanceID] then
				removed[#removed + 1] = placedLights[rec.instanceID]
				removeOneLight(rec.instanceID)
			end
		end
		undoStack[#undoStack + 1] = { action = "remove", lights = removed }
	end
end

----------------------------------------------------------------
-- Place lights (scatter or point mode)
----------------------------------------------------------------
local function placeAtPosition(worldX, worldZ)
	local lightDef = buildLightDef()
	local added = {}

	if lp.mode == "point" then
		if lp.smartEnabled and not isPointValid(worldX, worldZ, lp.smartFilters) then
			return
		end
		local rec = addOneLight(worldX, worldZ, lightDef)
		if rec then added[#added + 1] = rec end

	elseif lp.mode == "scatter" then
		local positions = generateScatterPositions(
			worldX, worldZ,
			lp.radius, lp.lightCount,
			lp.shape, lp.rotation, lp.distribution
		)
		for _, pos in ipairs(positions) do
			local px, pz = pos[1], pos[2]
			if not lp.smartEnabled or isPointValid(px, pz, lp.smartFilters) then
				local rec = addOneLight(px, pz, lightDef)
				if rec then added[#added + 1] = rec end
			end
		end
	end

	if #added > 0 then
		pushUndo("add", added)
	end
end

----------------------------------------------------------------
-- Remove lights within brush area
----------------------------------------------------------------
local function removeAtPosition(worldX, worldZ)
	local removed = {}
	for instanceID, rec in pairs(placedLights) do
		local dx = rec.pos[1] - worldX
		local dz = rec.pos[3] - worldZ
		if isInsideShape(dx, dz, lp.radius, lp.shape, lp.rotation) then
			removed[#removed + 1] = rec
		end
	end
	if #removed > 0 then
		for _, rec in ipairs(removed) do
			removeOneLight(rec.instanceID)
		end
		pushUndo("remove", removed)
	end
end

-- Apply TerraformBrush grid-snap + symmetric fan-out to a placement call.
local function placeSymmetric(fn, cx, cz)
	local tb = WG.TerraformBrush
	local rot = lp.rotation or 0
	if tb and tb.getState then
		local st = tb.getState()
		if st.angleSnap then rot = st.rotationDeg or rot end
		if st.gridSnap and tb.snapWorld then
			cx, cz = tb.snapWorld(cx, cz, rot)
		end
		if st.symmetryActive and tb.getSymmetricPositions then
			local positions = tb.getSymmetricPositions(cx, cz, rot)
			if positions and #positions > 0 then
				for _, p in ipairs(positions) do fn(p.x, p.z) end
				return
			end
		end
	end
	fn(cx, cz)
end

----------------------------------------------------------------
-- Save / Load
----------------------------------------------------------------
local function getMapName()
	local mapName = Game.mapName or "unknown"
	return mapName:gsub("[^%w_%-]", "_")
end

local function save()
	local lightList = {}
	for _, rec in pairs(placedLights) do
		lightList[#lightList + 1] = {
			type        = rec.type,
			pos         = { rec.pos[1], rec.pos[2], rec.pos[3] },
			radius      = rec.radius,
			color       = { rec.color[1], rec.color[2], rec.color[3] },
			brightness  = rec.brightness,
			modelfactor = rec.modelfactor,
			specular    = rec.specular,
			scattering  = rec.scattering,
			lensflare   = rec.lensflare,
			pitch       = rec.pitch,
			yaw         = rec.yaw,
			roll        = rec.roll,
			theta       = rec.theta,
			beamLength  = rec.beamLength,
			elevation   = rec.elevation,
			animation   = rec.animation,
		}
	end

	local data = {
		version = 1,
		mapName = Game.mapName,
		lights  = lightList,
	}

	local timestamp = os.date("%Y%m%d_%H%M%S")
	local filename = SAVE_DIR .. getMapName() .. "_lights_" .. timestamp .. ".lua"

	local lines = { "return {\n", "\tversion = 1,\n", '\tmapName = "' .. (Game.mapName or "unknown") .. '",\n', "\tlights = {\n" }
	for _, l in ipairs(lightList) do
		lines[#lines + 1] = "\t\t{\n"
		lines[#lines + 1] = string.format('\t\t\ttype = "%s",\n', l.type)
		lines[#lines + 1] = string.format("\t\t\tpos = { %.1f, %.1f, %.1f },\n", l.pos[1], l.pos[2], l.pos[3])
		lines[#lines + 1] = string.format("\t\t\tradius = %.1f,\n", l.radius)
		lines[#lines + 1] = string.format("\t\t\tcolor = { %.3f, %.3f, %.3f },\n", l.color[1], l.color[2], l.color[3])
		lines[#lines + 1] = string.format("\t\t\tbrightness = %.2f,\n", l.brightness)
		lines[#lines + 1] = string.format("\t\t\tmodelfactor = %.2f,\n", l.modelfactor)
		lines[#lines + 1] = string.format("\t\t\tspecular = %.2f,\n", l.specular)
		lines[#lines + 1] = string.format("\t\t\tscattering = %.2f,\n", l.scattering)
		lines[#lines + 1] = string.format("\t\t\tlensflare = %.2f,\n", l.lensflare)
		if l.pitch then lines[#lines + 1] = string.format("\t\t\tpitch = %.1f,\n", l.pitch) end
		if l.yaw   then lines[#lines + 1] = string.format("\t\t\tyaw = %.1f,\n", l.yaw) end
		if l.roll  then lines[#lines + 1] = string.format("\t\t\troll = %.1f,\n", l.roll) end
		if l.theta then lines[#lines + 1] = string.format("\t\t\ttheta = %.3f,\n", l.theta) end
		if l.beamLength then lines[#lines + 1] = string.format("\t\t\tbeamLength = %.1f,\n", l.beamLength) end
		if l.elevation then lines[#lines + 1] = string.format("\t\t\televation = %.1f,\n", l.elevation) end
		lines[#lines + 1] = "\t\t},\n"
	end
	lines[#lines + 1] = "\t},\n"
	lines[#lines + 1] = "}\n"

	local content = table.concat(lines)
	local file = io.open(filename, "w")
	if file then
		file:write(content)
		file:close()
		Echo("[LightPlacer] Saved " .. #lightList .. " lights to " .. filename)
	else
		Echo("[LightPlacer] Error: could not write to " .. filename)
	end
	return filename
end

local function clearAllLights()
	local removed = {}
	for instanceID, rec in pairs(placedLights) do
		removed[#removed + 1] = rec
	end
	for _, rec in ipairs(removed) do
		removeOneLight(rec.instanceID)
	end
	if #removed > 0 then
		pushUndo("remove", removed)
	end
end

local function listSaves()
	local files = {}
	local found = VFS.DirList(SAVE_DIR, "*.lua", VFS.RAW) or {}
	for _, path in ipairs(found) do
		files[#files + 1] = path
	end
	return files
end

local function load(filename)
	-- If no filename given, load most recent save
	if not filename then
		local saves = listSaves()
		if #saves == 0 then
			Echo("[LightPlacer] No saved light files found")
			return false
		end
		filename = saves[#saves]  -- most recent (alphabetically last = most recent timestamp)
	end

	local chunk, err = loadfile(filename)
	if not chunk then
		Echo("[LightPlacer] Error loading " .. filename .. ": " .. tostring(err))
		return false
	end
	local data = chunk()
	if not data or not data.lights then
		Echo("[LightPlacer] Invalid light file format: " .. filename)
		return false
	end

	-- Clear existing lights first
	clearAllLights()
	undoStack = {}
	redoStack = {}

	local added = {}
	for _, l in ipairs(data.lights) do
		local rec = addOneLight(l.pos[1], l.pos[3], l)
		if rec then added[#added + 1] = rec end
	end

	if #added > 0 then
		pushUndo("add", added)
	end

	Echo("[LightPlacer] Loaded " .. #added .. " lights from " .. filename)
	return true
end

----------------------------------------------------------------
-- Save / Load user presets
----------------------------------------------------------------
local PRESET_DIR = "lightmaps/presets/"

local function saveUserPreset(presetName)
	if not presetName or presetName == "" then return nil end

	-- Sanitize name
	local safeName = presetName:gsub("[^%w_%-]", "_")
	local filename = PRESET_DIR .. safeName .. ".lua"

	-- Collect all currently placed lights
	local lightList = {}
	-- Find center of mass to store relative positions
	local sumX, sumZ, count = 0, 0, 0
	for _, rec in pairs(placedLights) do
		sumX = sumX + rec.pos[1]
		sumZ = sumZ + rec.pos[3]
		count = count + 1
	end
	if count == 0 then
		Echo("[LightPlacer] No lights to save as preset")
		return nil
	end
	local centerX = sumX / count
	local centerZ = sumZ / count

	for _, rec in pairs(placedLights) do
		lightList[#lightList + 1] = {
			type        = rec.type,
			offsetX     = rec.pos[1] - centerX,
			offsetZ     = rec.pos[3] - centerZ,
			radius      = rec.radius,
			color       = { rec.color[1], rec.color[2], rec.color[3] },
			brightness  = rec.brightness,
			modelfactor = rec.modelfactor,
			specular    = rec.specular,
			scattering  = rec.scattering,
			lensflare   = rec.lensflare,
			pitch       = rec.pitch,
			yaw         = rec.yaw,
			roll        = rec.roll,
			theta       = rec.theta,
			beamLength  = rec.beamLength,
			elevation   = rec.elevation,
		}
	end

	local data = {
		version = 1,
		name    = presetName,
		lights  = lightList,
	}

	local lines = { "return {\n", "\tversion = 1,\n", '\tname = "' .. presetName .. '",\n', "\tlights = {\n" }
	for _, l in ipairs(lightList) do
		lines[#lines + 1] = "\t\t{\n"
		lines[#lines + 1] = string.format('\t\t\ttype = "%s",\n', l.type)
		lines[#lines + 1] = string.format("\t\t\toffsetX = %.1f,\n", l.offsetX)
		lines[#lines + 1] = string.format("\t\t\toffsetZ = %.1f,\n", l.offsetZ)
		lines[#lines + 1] = string.format("\t\t\tradius = %.1f,\n", l.radius)
		lines[#lines + 1] = string.format("\t\t\tcolor = { %.3f, %.3f, %.3f },\n", l.color[1], l.color[2], l.color[3])
		lines[#lines + 1] = string.format("\t\t\tbrightness = %.2f,\n", l.brightness)
		lines[#lines + 1] = string.format("\t\t\tmodelfactor = %.2f,\n", l.modelfactor)
		lines[#lines + 1] = string.format("\t\t\tspecular = %.2f,\n", l.specular)
		lines[#lines + 1] = string.format("\t\t\tscattering = %.2f,\n", l.scattering)
		lines[#lines + 1] = string.format("\t\t\tlensflare = %.2f,\n", l.lensflare)
		if l.pitch then lines[#lines + 1] = string.format("\t\t\tpitch = %.1f,\n", l.pitch) end
		if l.yaw   then lines[#lines + 1] = string.format("\t\t\tyaw = %.1f,\n", l.yaw) end
		if l.roll  then lines[#lines + 1] = string.format("\t\t\troll = %.1f,\n", l.roll) end
		if l.theta then lines[#lines + 1] = string.format("\t\t\ttheta = %.3f,\n", l.theta) end
		if l.beamLength then lines[#lines + 1] = string.format("\t\t\tbeamLength = %.1f,\n", l.beamLength) end
		if l.elevation then lines[#lines + 1] = string.format("\t\t\televation = %.1f,\n", l.elevation) end
		lines[#lines + 1] = "\t\t},\n"
	end
	lines[#lines + 1] = "\t},\n"
	lines[#lines + 1] = "}\n"

	local content = table.concat(lines)
	local file = io.open(filename, "w")
	if file then
		file:write(content)
		file:close()
		Echo("[LightPlacer] Saved user preset '" .. presetName .. "' (" .. #lightList .. " lights)")
		return filename
	else
		Echo("[LightPlacer] Error: could not write preset to " .. filename)
		return nil
	end
end

local function listUserPresets()
	local presets = {}
	local found = VFS.DirList(PRESET_DIR, "*.lua", VFS.RAW) or {}
	for _, path in ipairs(found) do
		local name = path:match("([^/\\]+)%.lua$")
		if name then
			presets[#presets + 1] = { name = name, path = path }
		end
	end
	return presets
end

local function placePreset(presetData, worldX, worldZ)
	if not presetData or not presetData.lights then return end
	local added = {}
	for _, l in ipairs(presetData.lights) do
		local px = worldX + (l.offsetX or 0)
		local pz = worldZ + (l.offsetZ or 0)
		if not lp.smartEnabled or isPointValid(px, pz, lp.smartFilters) then
			local rec = addOneLight(px, pz, l)
			if rec then added[#added + 1] = rec end
		end
	end
	if #added > 0 then
		pushUndo("add", added)
	end
end

local function loadPresetFile(filename)
	local chunk, err = loadfile(filename)
	if not chunk then
		Echo("[LightPlacer] Error loading preset: " .. tostring(err))
		return nil
	end
	return chunk()
end

----------------------------------------------------------------
-- Apply defaults when switching light type
----------------------------------------------------------------
local function applyLightTypeDefaults(lightType)
	local defaults = LIGHT_DEFAULTS[lightType]
	if not defaults then return end
	lp.lightType    = lightType
	lp.lightRadius  = defaults.radius
	lp.color        = { defaults.color[1], defaults.color[2], defaults.color[3] }
	lp.brightness   = defaults.brightness
	lp.modelfactor  = defaults.modelfactor
	lp.specular     = defaults.specular
	lp.scattering   = defaults.scattering
	lp.lensflare    = defaults.lensflare
	if defaults.theta      then lp.theta      = defaults.theta end
	if defaults.pitch      then lp.pitch      = defaults.pitch end
	if defaults.yaw        then lp.yaw        = defaults.yaw end
	if defaults.roll       then lp.roll       = defaults.roll end
	if defaults.beamLength then lp.beamLength = defaults.beamLength end
end

----------------------------------------------------------------
-- Preview light: live GL4 light that follows the cursor
----------------------------------------------------------------
local function removePreviewLight()
	if not previewLight.id then return end
	local api = WG['lightsgl4']
	if api and api.RemoveLight then
		api.RemoveLight(previewLight.shape, previewLight.id, nil)
	end
	previewLight.id    = nil
	previewLight.shape = nil
	previewLastHash    = nil
end

local function updatePreviewLight(worldX, worldZ)
	local api = WG['lightsgl4']
	if not api then removePreviewLight(); return end
	local hash = string.format("%.0f_%.0f_%s_%.3f_%.3f_%.3f_%.2f_%d_%d_%d_%.1f_%.2f_%d",
		worldX, worldZ, lp.lightType,
		lp.color[1], lp.color[2], lp.color[3],
		lp.brightness, lp.lightRadius, lp.pitch, lp.yaw, lp.theta, lp.elevation, lp.beamLength)
	if hash == previewLastHash then return end
	removePreviewLight()
	local py = (GetGroundHeight(worldX, worldZ) or 0) + lp.elevation
	local r  = lp.color[1] * lp.brightness
	local g  = lp.color[2] * lp.brightness
	local b  = lp.color[3] * lp.brightness
	local id
	if lp.lightType == "point" then
		id = api.AddPointLight(nil, nil, nil, nil,
			worldX, py, worldZ, lp.lightRadius,
			r, g, b, 1.0, 0, 0, 0, 0,
			lp.modelfactor, lp.specular, lp.scattering, lp.lensflare,
			nil, 0, 1, 0)
		previewLight.shape = "point"
	elseif lp.lightType == "cone" then
		local dx, dy, dz = eulerToDirection(lp.pitch, lp.yaw)
		id = api.AddConeLight(nil, nil, nil, nil,
			worldX, py, worldZ, lp.lightRadius,
			r, g, b, 1.0, dx, dy, dz, lp.theta, 0,
			lp.modelfactor, lp.specular, lp.scattering, lp.lensflare,
			nil, 0, 1, 0)
		previewLight.shape = "cone"
	elseif lp.lightType == "beam" then
		local ex, ey, ez = beamEndpoint(worldX, py, worldZ, lp.pitch, lp.yaw, lp.beamLength)
		id = api.AddBeamLight(nil, nil, nil, nil,
			worldX, py, worldZ, lp.lightRadius,
			r, g, b, 1.0, ex, ey, ez, lp.lightRadius, 0,
			lp.modelfactor, lp.specular, lp.scattering, lp.lensflare,
			nil, 0, 1, 0)
		previewLight.shape = "beam"
	end
	if id then
		previewLight.id = id
		previewLastHash = hash
	end
end

----------------------------------------------------------------
-- Preset preview: preview lights for all lights in a pending preset
----------------------------------------------------------------
local function removePresetPreviewLights()
	local api = WG['lightsgl4']
	if api and api.RemoveLight then
		for _, p in ipairs(presetPreviewLights) do
			api.RemoveLight(p.shape, p.id, nil)
		end
	end
	presetPreviewLights = {}
	presetPreviewHash = nil
end

local function updatePresetPreviewLights(worldX, worldZ)
	if not pendingPreset or not pendingPreset.lights then
		removePresetPreviewLights()
		return
	end
	local api = WG['lightsgl4']
	if not api then removePresetPreviewLights(); return end
	local hash = string.format("%.0f_%.0f_%d", worldX, worldZ, #pendingPreset.lights)
	if hash == presetPreviewHash and #presetPreviewLights > 0 then return end
	removePresetPreviewLights()
	for _, l in ipairs(pendingPreset.lights) do
		local px = worldX + (l.offsetX or 0)
		local pz = worldZ + (l.offsetZ or 0)
		local py = (GetGroundHeight(px, pz) or 0) + (l.elevation or 0)
		local color = l.color or { 1, 1, 1 }
		local br = l.brightness or 1
		local r, g, b = color[1] * br, color[2] * br, color[3] * br
		local radius = l.radius or 200
		local id
		local ltype = l.type or "point"
		if ltype == "point" then
			id = api.AddPointLight(nil, nil, nil, nil,
				px, py, pz, radius,
				r, g, b, 1.0, 0, 0, 0, 0,
				l.modelfactor or 1, l.specular or 1, l.scattering or 1, l.lensflare or 0,
				nil, 0, 1, 0)
		elseif ltype == "cone" then
			local dx, dy, dz = eulerToDirection(l.pitch or -90, l.yaw or 0)
			id = api.AddConeLight(nil, nil, nil, nil,
				px, py, pz, radius,
				r, g, b, 1.0, dx, dy, dz, l.theta or 0.5, 0,
				l.modelfactor or 1, l.specular or 1, l.scattering or 1, l.lensflare or 0,
				nil, 0, 1, 0)
		elseif ltype == "beam" then
			local ex, ey, ez = beamEndpoint(px, py, pz, l.pitch or 0, l.yaw or 0, l.beamLength or 300)
			id = api.AddBeamLight(nil, nil, nil, nil,
				px, py, pz, radius,
				r, g, b, 1.0, ex, ey, ez, radius, 0,
				l.modelfactor or 1, l.specular or 1, l.scattering or 1, l.lensflare or 0,
				nil, 0, 1, 0)
		end
		if id then
			presetPreviewLights[#presetPreviewLights + 1] = { shape = ltype, id = id }
		end
	end
	presetPreviewHash = hash
end

local function setPendingPreset(preset)
	pendingPreset = preset
	removePresetPreviewLights()
	removePreviewLight()
end

local function clearPendingPreset()
	pendingPreset = nil
	removePresetPreviewLights()
end

----------------------------------------------------------------
-- Draw: cursor preview circle + ghost light indicator
----------------------------------------------------------------
local function drawBrushCircle(worldX, worldZ)
	if not worldX then return end
	local gy = GetGroundHeight(worldX, worldZ) or 0

	glDepthTest(true)
	glLineWidth(2)

	if lp.mode == "remove" then
		glColor(1, 0.3, 0.3, 0.8)
	else
		glColor(lp.color[1], lp.color[2], lp.color[3], 0.8)
	end

	-- Brush outline
	if lp.mode == "scatter" or lp.mode == "remove" then
		local r = lp.radius
		glBeginEnd(GL_LINE_LOOP, function()
			for i = 0, CIRCLE_SEGMENTS - 1 do
				local angle = (i / CIRCLE_SEGMENTS) * 2 * pi
				local px = worldX + cos(angle) * r
				local pz = worldZ + sin(angle) * r
				local py = GetGroundHeight(px, pz) or gy
				glVertex(px, py + 2, pz)
			end
		end)
	end

	-- Light radius indicator for point mode
	if lp.mode == "point" then
		local lr = lp.lightRadius
		glColor(lp.color[1], lp.color[2], lp.color[3], 0.4)
		glBeginEnd(GL_LINE_LOOP, function()
			for i = 0, CIRCLE_SEGMENTS - 1 do
				local angle = (i / CIRCLE_SEGMENTS) * 2 * pi
				local px = worldX + cos(angle) * lr
				local pz = worldZ + sin(angle) * lr
				local py = GetGroundHeight(px, pz) or gy
				glVertex(px, py + 2, pz)
			end
		end)
	end

	-- Direction indicator for cone/beam
	if lp.lightType == "cone" then
		local dx, dy, dz = eulerToDirection(lp.pitch, lp.yaw)
		local reach = lp.lightRadius * 0.6
		local rimR  = reach * math.tan(lp.theta)
		local tipX, tipY, tipZ = worldX, gy + lp.elevation, worldZ
		local rimCX = tipX + dx * reach
		local rimCY = tipY + dy * reach
		local rimCZ = tipZ + dz * reach
		-- Build two perpendicular vectors to direction
		local px, py2, pz
		if math.abs(dx) < 0.9 then
			-- cross (1,0,0) × (dx,dy,dz) = (0,-dz,dy)
			px, py2, pz = 0, -dz, dy
		else
			-- cross (0,1,0) × (dx,dy,dz) = (dz,0,-dx)
			px, py2, pz = dz, 0, -dx
		end
		local pl = sqrt(px*px + py2*py2 + pz*pz)
		if pl > 0.001 then px = px/pl; py2 = py2/pl; pz = pz/pl end
		local qx = dy*pz - dz*py2
		local qy = dz*px - dx*pz
		local qz = dx*py2 - dy*px
		-- Cone rim circle
		glColor(lp.color[1], lp.color[2], lp.color[3], 0.45)
		glLineWidth(2)
		glBeginEnd(GL_LINE_LOOP, function()
			for i = 0, CIRCLE_SEGMENTS - 1 do
				local a = (i / CIRCLE_SEGMENTS) * 2 * pi
				local c, s = cos(a), sin(a)
				glVertex(rimCX + (px*c + qx*s) * rimR,
				         rimCY + (py2*c + qy*s) * rimR,
				         rimCZ + (pz*c + qz*s) * rimR)
			end
		end)
		-- 4 edge lines from tip to rim
		glColor(1, 1, 0, 0.7)
		glLineWidth(3)
		glBeginEnd(GL_LINES, function()
			for k = 0, 3 do
				local a = (k / 4) * 2 * pi
				local c, s = cos(a), sin(a)
				glVertex(tipX, tipY, tipZ)
				glVertex(rimCX + (px*c + qx*s) * rimR,
				         rimCY + (py2*c + qy*s) * rimR,
				         rimCZ + (pz*c + qz*s) * rimR)
			end
		end)
	elseif lp.lightType == "beam" then
		local dx, dy, dz = eulerToDirection(lp.pitch, lp.yaw)
		local len = lp.beamLength
		local tipX, tipY, tipZ = worldX, gy + lp.elevation, worldZ
		local endX = tipX + dx * len
		local endY = tipY + dy * len
		local endZ = tipZ + dz * len
		-- Main beam axis
		glColor(1, 1, 0, 0.7)
		glLineWidth(3)
		glBeginEnd(GL_LINES, function()
			glVertex(tipX, tipY, tipZ)
			glVertex(endX, endY, endZ)
		end)
		-- Small cross at start
		local cr = min(20, lp.lightRadius * 0.1)
		glColor(lp.color[1], lp.color[2], lp.color[3], 0.5)
		glLineWidth(2)
		glBeginEnd(GL_LINES, function()
			glVertex(tipX - cr, tipY, tipZ); glVertex(tipX + cr, tipY, tipZ)
			glVertex(tipX, tipY, tipZ - cr); glVertex(tipX, tipY, tipZ + cr)
		end)
		-- End marker
		glBeginEnd(GL_LINES, function()
			glVertex(endX - cr, endY, endZ); glVertex(endX + cr, endY, endZ)
			glVertex(endX, endY, endZ - cr); glVertex(endX, endY, endZ + cr)
		end)
	end

	-- Elevation indicator: vertical line from ground to light height + small cross
	if lp.elevation > 2 then
		local elY = gy + lp.elevation
		glColor(1, 1, 1, 0.5)
		glLineWidth(1)
		-- Vertical stalk
		glBeginEnd(GL_LINES, function()
			glVertex(worldX, gy + 2, worldZ)
			glVertex(worldX, elY, worldZ)
		end)
		-- Small horizontal cross at elevated height
		local crossSize = min(30, lp.elevation * 0.3)
		glColor(lp.color[1], lp.color[2], lp.color[3], 0.7)
		glLineWidth(2)
		glBeginEnd(GL_LINES, function()
			glVertex(worldX - crossSize, elY, worldZ)
			glVertex(worldX + crossSize, elY, worldZ)
			glVertex(worldX, elY, worldZ - crossSize)
			glVertex(worldX, elY, worldZ + crossSize)
		end)
	end

	glColor(1, 1, 1, 1)
	glLineWidth(1)
	glDepthTest(false)
end

----------------------------------------------------------------
-- Widget callins
----------------------------------------------------------------
function widget:Initialize()
	-- Ensure save directories exist
	Spring.CreateDir(SAVE_DIR)
	Spring.CreateDir(PRESET_DIR)

	WG.LightPlacer = {
		getState = function()
			return {
				active       = lp.active,
				mode         = lp.mode,
				lightType    = lp.lightType,
				shape        = lp.shape,
				radius       = lp.radius,
				rotation     = lp.rotation,
				lightCount   = lp.lightCount,
				cadence      = lp.cadence,
				distribution = lp.distribution,
				lightRadius  = lp.lightRadius,
				color        = lp.color,
				brightness   = lp.brightness,
				modelfactor  = lp.modelfactor,
				specular     = lp.specular,
				scattering   = lp.scattering,
				lensflare    = lp.lensflare,
				pitch        = lp.pitch,
				yaw          = lp.yaw,
				roll         = lp.roll,
				theta        = lp.theta,
				beamLength   = lp.beamLength,
				elevation    = lp.elevation,
				smartEnabled = lp.smartEnabled,
				smartFilters = lp.smartFilters,
				undoCount    = #undoStack,
				redoCount    = #redoStack,
				lightCount_placed = 0,
				selectedLight = lp.selectedLight,
			}
		end,

		activate     = function() lp.active = true end,
		deactivate   = function()
			lp.active = false
			lp.mode = nil
			lp.dragging = false
			removePreviewLight()
			clearPendingPreset()
		end,

		setMode         = function(m) lp.mode = m; lp.active = (m ~= nil) end,
		setLightType    = function(t) applyLightTypeDefaults(t) end,
		setShape        = function(s) lp.shape = s end,
		setRadius       = function(r) lp.radius = max(MIN_RADIUS, min(MAX_RADIUS, r)) end,
		setRotation     = function(d) lp.rotation = d % 360 end,
		rotate          = function(step) lp.rotation = (lp.rotation + step) % 360 end,
		setLightCount   = function(n) lp.lightCount = max(1, min(500, n)) end,
		setCadence      = function(v) lp.cadence = max(1, min(1000, v)) end,
		setDistribution = function(d) lp.distribution = d end,

		setLightRadius  = function(r) lp.lightRadius = max(10, min(5000, r)) end,
		setColor        = function(r, g, b) lp.color = { r, g, b } end,
		setBrightness   = function(v) lp.brightness = max(0.01, min(50, v)) end,
		setModelfactor  = function(v) lp.modelfactor = max(0, min(5, v)) end,
		setSpecular     = function(v) lp.specular = max(0, min(5, v)) end,
		setScattering   = function(v) lp.scattering = max(0, min(5, v)) end,
		setLensflare    = function(v) lp.lensflare = max(0, min(5, v)) end,

		setPitch        = function(v) lp.pitch = max(-90, min(90, v)) end,
		setYaw          = function(v) lp.yaw = v % 360 end,
		setRoll         = function(v) lp.roll = v % 360 end,
		setTheta        = function(v) lp.theta = max(0.05, min(1.5, v)) end,
		setBeamLength   = function(v) lp.beamLength = max(10, min(5000, v)) end,
		setElevation    = function(v) lp.elevation = max(0, min(2000, v)) end,

		setSmartEnabled = function(b) lp.smartEnabled = b end,
		setSmartFilter  = function(k, v) lp.smartFilters[k] = v end,

		undo     = doUndo,
		redo     = doRedo,
		save     = save,
		load     = load,
		listSaves = listSaves,
		clearAll  = clearAllLights,

		saveUserPreset  = saveUserPreset,
		listUserPresets = listUserPresets,
		loadPresetFile  = loadPresetFile,
		placePreset     = placePreset,
		getBuiltinPresets = function() return BUILTIN_PRESETS end,

		setPendingPreset   = setPendingPreset,
		clearPendingPreset = clearPendingPreset,
		getPendingPreset   = function() return pendingPreset end,

		getPlacedCount  = function() local n = 0; for _ in pairs(placedLights) do n = n + 1 end; return n end,
	}
end

function widget:Shutdown()
	removePreviewLight()
	removePresetPreviewLights()
	-- Remove all placed lights from the renderer
	for instanceID in pairs(placedLights) do
		removeOneLight(instanceID)
	end
	placedLights = {}
	WG.LightPlacer = nil
end

function widget:IsAbove(x, y)
	return false
end

local function isOverLightsUI(mx, my)
	local tfUI = WG.TerraformBrushUI
	if not tfUI then return false end
	local function overBounds(b)
		if not b then return false end
		return mx >= b.left and mx <= b.right and my >= b.bottomY and my <= b.topY
	end
	if overBounds(tfUI.getPanelBounds and tfUI.getPanelBounds()) then return true end
	if overBounds(tfUI.getLightLibraryBounds and tfUI.getLightLibraryBounds()) then return true end
	return false
end

function widget:MousePress(mx, my, button)
	if not lp.active or not lp.mode then return false end
	if button ~= 1 and button ~= 3 then return false end
	if isOverLightsUI(mx, my) then return true end

	-- Defer to measure tool when active
	do
		local tb = WG.TerraformBrush
		local st = tb and tb.getState and tb.getState() or nil
		if st and st.measureActive then return false end
	end

	local _, coords = TraceScreenRay(mx, my, true)
	if not coords then return false end

	local worldX, _, worldZ = coords[1], coords[2], coords[3]

	if button == 1 then
		-- If a preset is armed, place the entire preset at cursor; keep armed
		-- so the user can drop it multiple times. Right click or Esc clears.
		if pendingPreset then
			placePreset(pendingPreset, worldX, worldZ)
			lp.dragging = false
			return true
		end
		if lp.mode == "remove" then
			placeSymmetric(removeAtPosition, worldX, worldZ)
		else
			placeSymmetric(placeAtPosition, worldX, worldZ)
		end
		lp.dragging = true
		lp.dragAction = lp.mode == "remove" and "remove" or "place"
		lp.placeTimer = 0
		return true
	elseif button == 3 then
		-- Right click clears armed preset if any, otherwise removes at position
		if pendingPreset then
			clearPendingPreset()
			return true
		end
		placeSymmetric(removeAtPosition, worldX, worldZ)
		lp.dragging = true
		lp.dragAction = "remove"
		lp.placeTimer = 0
		return true
	end

	return false
end

function widget:MouseRelease(mx, my, button)
	if lp.dragging then
		lp.dragging = false
		lp.dragAction = nil
		return true
	end
	return false
end

function widget:Update(dt)
	if not lp.active or not lp.dragging then return end
	if lp.mode ~= "scatter" and lp.dragAction ~= "remove" then return end

	lp.placeTimer = lp.placeTimer + dt
	-- Cadence: higher = faster. 1000 = every frame, 1 = very slow
	local interval = 1.0 / max(lp.cadence / 100, 0.01)
	if lp.placeTimer < interval then return end
	lp.placeTimer = lp.placeTimer - interval

	local mx, my = GetMouseState()
	local _, coords = TraceScreenRay(mx, my, true)
	if not coords then return end

	if lp.dragAction == "remove" then
		placeSymmetric(removeAtPosition, coords[1], coords[3])
	else
		placeSymmetric(placeAtPosition, coords[1], coords[3])
	end
end

function widget:DrawWorld()
	if not lp.active or not lp.mode then
		removePreviewLight()
		removePresetPreviewLights()
		return
	end

	local mx, my = GetMouseState()
	local worldX, worldZ

	-- Real ground position under cursor (if any)
	local _, coords = TraceScreenRay(mx, my, true)
	if coords then worldX, worldZ = coords[1], coords[3] end

	-- Animated unmouse: slide brush toward the parked spot when cursor is over
	-- the terraform panel or the light library, and back when it leaves.
	do
		local tb = WG.TerraformBrush
		local tfUI = WG.TerraformBrushUI
		local function overBounds(b)
			if not b then return false end
			return mx >= b.left and mx <= b.right and my >= b.bottomY and my <= b.topY
		end
		local libBounds = tfUI and tfUI.getLightLibraryBounds and tfUI.getLightLibraryBounds()
		local overLib   = overBounds(libBounds)
		if tb and tb.animateUnmouse then
			-- When cursor is over the light library but not the main panel, the
			-- shared animateUnmouse won't detect it. Treat "over library" as if
			-- over panel by supplying a library-derived parked position.
			if overLib and not overBounds(tfUI and tfUI.getPanelBounds and tfUI.getPanelBounds()) then
				local vsx, vsy = Spring.GetViewGeometry()
				local cx = floor(vsx * 0.5)
				if cx >= libBounds.left - 30 and cx <= libBounds.right + 30 then
					cx = floor(libBounds.left * 0.5)
				end
				local cy = floor(vsy * 0.5)
				local _, ccoords = TraceScreenRay(cx, cy, true)
				if ccoords then worldX, worldZ = ccoords[1], ccoords[3] end
			else
				worldX, worldZ = tb.animateUnmouse("lightPlacer", worldX, worldZ, lp.radius, 1.0)
			end
		end
	end

	if not worldX then
		removePreviewLight()
		removePresetPreviewLights()
		return
	end

	-- Armed preset preview: show all preset lights at cursor; suppress regular preview
	if pendingPreset and lp.mode ~= "remove" then
		removePreviewLight()
		updatePresetPreviewLights(worldX, worldZ)
		drawBrushCircle(worldX, worldZ)
		return
	end

	removePresetPreviewLights()

	-- Live preview light at cursor (skip in remove mode)
	if lp.mode ~= "remove" then
		updatePreviewLight(worldX, worldZ)
	else
		removePreviewLight()
	end

	drawBrushCircle(worldX, worldZ)
end

function widget:KeyPress(key, mods, isRepeat)
	if not lp.active then return false end

	-- Escape = deactivate
	if key == 0x1B then
		if pendingPreset then
			clearPendingPreset()
			return true
		end
		lp.active = false
		lp.mode = nil
		lp.dragging = false
		return true
	end

	-- Ctrl+Z / Ctrl+Shift+Z for undo/redo,  Ctrl+Y also redo
	if mods.ctrl and (key == 0x7A or key == 0x5A) then -- z/Z
		if mods.shift then
			doRedo()
			Echo("[Light Placer] Redo")
		else
			doUndo()
			Echo("[Light Placer] Undo")
		end
		return true
	end
	if mods.ctrl and (key == 0x79 or key == 0x59) then -- y/Y
		doRedo()
		Echo("[Light Placer] Redo")
		return true
	end

	-- Space key = suppress (used for brightness via scroll)
	if key == KEYSYMS_SPACE then
		return true
	end

	-- Bracket keys [ / ] with modifiers matching scroll conventions:
	--   Ctrl+[/]     = Brush radius   (matches Ctrl+Scroll)
	--   Alt+[/]      = Rotation       (matches Alt+Scroll)
	--   Shift+[/]    = Elevation      (matches Shift+Scroll)
	--   Space+[/]    = Brightness     (matches Space+Scroll)
	if key == 91 or key == 93 then -- [ or ]
		local increase = (key == 93)
		local spaceHeld = GetKeyState(KEYSYMS_SPACE)

		if mods.ctrl then
			local step = increase and RADIUS_STEP or -RADIUS_STEP
			lp.radius = max(MIN_RADIUS, min(MAX_RADIUS, lp.radius + step))
			Echo("[Light Placer] Brush radius: " .. lp.radius)
			return true
		elseif mods.alt then
			if increase then
				lp.rotation = (lp.rotation + ROTATION_STEP) % 360
			else
				lp.rotation = (lp.rotation - ROTATION_STEP) % 360
			end
			Echo("[Light Placer] Rotation: " .. lp.rotation .. "°")
			return true
		elseif mods.shift then
			local step = increase and ELEVATION_STEP or -ELEVATION_STEP
			lp.elevation = max(0, min(2000, lp.elevation + step))
			Echo("[Light Placer] Elevation: " .. lp.elevation)
			return true
		elseif spaceHeld then
			if increase then
				lp.brightness = min(50, lp.brightness + BRIGHTNESS_STEP)
			else
				lp.brightness = max(0.01, lp.brightness - BRIGHTNESS_STEP)
			end
			Echo("[Light Placer] Brightness: " .. string.format("%.2f", lp.brightness))
			return true
		end
	end

	return false
end

function widget:MouseWheel(up, value)
	if not lp.active then return false end
	do
		local mx, my = GetMouseState()
		if isOverLightsUI(mx, my) then return false end
	end

	local alt, ctrl, _, shift = GetModKeyState()

	-- R/G/B held + scroll = adjust individual color channels
	local rHeld = GetKeyState(0x72) -- r
	local gHeld = GetKeyState(0x67) -- g
	local bHeld = GetKeyState(0x62) -- b
	local delta = up and COLOR_STEP or -COLOR_STEP

	if rHeld then
		lp.color[1] = max(0, min(1, lp.color[1] + delta))
		Echo("[Light Placer] Red: " .. string.format("%.2f", lp.color[1]))
		return true
	elseif gHeld then
		lp.color[2] = max(0, min(1, lp.color[2] + delta))
		Echo("[Light Placer] Green: " .. string.format("%.2f", lp.color[2]))
		return true
	elseif bHeld then
		lp.color[3] = max(0, min(1, lp.color[3] + delta))
		Echo("[Light Placer] Blue: " .. string.format("%.2f", lp.color[3]))
		return true
	end

	-- Ctrl+Alt+Scroll = pitch (up=toward horiz/0°, down=toward down/-90°)
	if ctrl and alt then
		local dir = up and 5 or -5
		lp.pitch = max(-90, min(90, lp.pitch + dir))
		Echo("[Light Placer] Pitch: " .. lp.pitch .. "°")
		return true
	end

	-- Alt+Scroll = yaw (rotate direction horizontally)
	if alt and not ctrl then
		local dir = up and 10 or -10
		lp.yaw = ((lp.yaw + dir) % 360 + 360) % 360
		Echo("[Light Placer] Yaw: " .. lp.yaw .. "°")
		return true
	end

	-- Shift+Scroll = elevation offset above ground
	if shift and not ctrl then
		local step = up and ELEVATION_STEP or -ELEVATION_STEP
		lp.elevation = max(0, min(2000, lp.elevation + step))
		Echo("[Light Placer] Elevation: " .. lp.elevation)
		return true
	end

	-- Space+Scroll = brightness
	local spaceHeld = GetKeyState(KEYSYMS_SPACE)
	if spaceHeld then
		if up then
			lp.brightness = min(50, lp.brightness + BRIGHTNESS_STEP)
		else
			lp.brightness = max(0.01, lp.brightness - BRIGHTNESS_STEP)
		end
		Echo("[Light Placer] Brightness: " .. string.format("%.2f", lp.brightness))
		return true
	end

	-- Ctrl+Scroll = brush radius (placement area size)
	if ctrl then
		local step = up and RADIUS_STEP or -RADIUS_STEP
		lp.radius = max(MIN_RADIUS, min(MAX_RADIUS, lp.radius + step))
		Echo("[Light Placer] Brush radius: " .. lp.radius)
		return true
	end

	return false
end
