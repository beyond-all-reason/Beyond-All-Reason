if not RmlUi then
	return
end

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Terraform Brush UI",
		desc = "RmlUI panel for terraform brush shape, mode, and rotation controls",
		author = "BARb",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true,
	}
end

local MODEL_NAME = "terraform_brush_model"
local RML_PATH = "luaui/RmlWidgets/gui_terraform_brush/gui_terraform_brush.rml"

local ROTATION_STEP = 3
local CURVE_STEP = 0.1
local LENGTH_SCALE_STEP = 0.1
local RADIUS_STEP = 8
local HEIGHT_CAP_STEP = 8
local HEIGHT_STEP = 8
local DEFAULT_MAX_INTENSITY = 10.0

local INTENSITY_LOG_MIN = 0.1
local INTENSITY_LOG_MAX = 100.0
local INTENSITY_SLIDER_MAX = 1000
local INTENSITY_LOG_RANGE = math.log(INTENSITY_LOG_MAX / INTENSITY_LOG_MIN)

local function sliderToIntensity(v)
	return INTENSITY_LOG_MIN * math.exp(v / INTENSITY_SLIDER_MAX * INTENSITY_LOG_RANGE)
end

local function intensityToSlider(intensity)
	if intensity <= INTENSITY_LOG_MIN then return 0 end
	return math.floor(INTENSITY_SLIDER_MAX * math.log(intensity / INTENSITY_LOG_MIN) / INTENSITY_LOG_RANGE + 0.5)
end

local CADENCE_LOG_MIN = 1
local CADENCE_LOG_MAX = 1000
local CADENCE_SLIDER_MAX = 1000
local CADENCE_LOG_RANGE = math.log(CADENCE_LOG_MAX / CADENCE_LOG_MIN)

local function sliderToCadence(v)
	return math.max(1, math.floor(CADENCE_LOG_MIN * math.exp(v / CADENCE_SLIDER_MAX * CADENCE_LOG_RANGE) + 0.5))
end

local function cadenceToSlider(c)
	if c <= CADENCE_LOG_MIN then return 0 end
	return math.floor(CADENCE_SLIDER_MAX * math.log(c / CADENCE_LOG_MIN) / CADENCE_LOG_RANGE + 0.5)
end

-- Frequency slider: logarithmic mapping for 0.1 .. 60.0 seconds
local FREQ_LOG_MIN = 0.1
local FREQ_LOG_MAX = 60.0
local FREQ_SLIDER_MAX = 1000
local FREQ_LOG_RANGE = math.log(FREQ_LOG_MAX / FREQ_LOG_MIN)

local function sliderToFrequency(v)
	return FREQ_LOG_MIN * math.exp(v / FREQ_SLIDER_MAX * FREQ_LOG_RANGE)
end

local function frequencyToSlider(f)
	if f <= FREQ_LOG_MIN then return 0 end
	return math.floor(FREQ_SLIDER_MAX * math.log(f / FREQ_LOG_MIN) / FREQ_LOG_RANGE + 0.5)
end

-- Persistence slider: piecewise log mapping
-- First 1/5 (0-200): 0-60s, next 1/4 (200-450): 60-600s, rest (450-999): 600-3600s, 1000 = permanent
local PERSIST_SLIDER_MAX = 1000
local PERSIST_PERMANENT_VAL = 3601

local function sliderToPersist(v)
	v = math.max(0, math.min(PERSIST_SLIDER_MAX, math.floor(v + 0.5)))
	if v >= PERSIST_SLIDER_MAX then return PERSIST_PERMANENT_VAL end
	if v <= 0 then return 0 end
	if v <= 200 then
		return math.floor(v / 200 * 60 + 0.5)
	elseif v <= 450 then
		return math.floor(60 + (v - 200) / 250 * 540 + 0.5)
	else
		return math.floor(600 + (v - 450) / 549 * 3000 + 0.5)
	end
end

local function persistToSlider(s)
	if s >= PERSIST_PERMANENT_VAL then return PERSIST_SLIDER_MAX end
	if s <= 0 then return 0 end
	if s <= 60 then
		return math.floor(s / 60 * 200 + 0.5)
	elseif s <= 600 then
		return math.floor(200 + (s - 60) / 540 * 250 + 0.5)
	else
		return math.floor(450 + (s - 600) / 3000 * 549 + 0.5)
	end
end

local function formatFrequency(f)
	if f >= 10 then
		return string.format("%.0fs", f)
	elseif f >= 1 then
		return string.format("%.1fs", f)
	else
		return string.format("%.2fs", f)
	end
end

local WG = WG
local GetViewGeometry = Spring.GetViewGeometry
local GetMouseState   = Spring.GetMouseState
local TraceScreenRay  = Spring.TraceScreenRay

-- ============ UI Sound Effects ============
local uiSounds = {
	modeSwitch  = "LuaUI/Sounds/buildbar_click.wav",
	shapeSwitch = "LuaUI/Sounds/buildbar_hover.wav",
	toolSwitch  = "LuaUI/Sounds/buildbar_add.wav",
	toggleOn    = "LuaUI/Sounds/switchon.wav",
	toggleOff   = "LuaUI/Sounds/switchoff.wav",
	click       = "LuaUI/Sounds/tock.wav",
	tick        = "LuaUI/Sounds/hover.wav",
	undo        = "LuaUI/Sounds/buildbar_rem.wav",
	save        = "LuaUI/Sounds/buildbar_waypoint.wav",
	dropdown    = "LuaUI/Sounds/buildbar_click.wav",
	panelOpen   = "LuaUI/Sounds/buildbar_click.wav",
	reset       = "LuaUI/Sounds/buildbar_rem.wav",
	exit        = "LuaUI/Sounds/switchoff.wav",
	sliderLock  = "sounds/ui/beep6.wav",
}
local uiSoundVolumes = {
	modeSwitch  = 0.45,
	shapeSwitch = 0.35,
	toolSwitch  = 0.5,
	toggleOn    = 0.4,
	toggleOff   = 0.4,
	click       = 0.35,
	tick        = 0.15,
	undo        = 0.4,
	save        = 0.5,
	dropdown    = 0.3,
	panelOpen   = 0.3,
	reset       = 0.4,
	exit        = 0.35,
	sliderLock  = 0.5,
}
local soundCooldowns = {}
local SOUND_COOLDOWN = 0.04  -- seconds between repeated sounds of the same type
-- soundMuted lives on widgetState (shared with tf_guide module)

local function playSound(name)
	if widgetState and widgetState.soundMuted then return end
	local path = uiSounds[name]
	if not path then return end
	local now = Spring.GetTimer()
	local last = soundCooldowns[name]
	if last and Spring.DiffTimers(now, last) < SOUND_COOLDOWN then return end
	soundCooldowns[name] = now
	Spring.PlaySoundFile(path, uiSoundVolumes[name] or 0.4, "ui")
end

local INITIAL_LEFT_VW = 78
local INITIAL_TOP_VH = 25
local BASE_WIDTH_DP = 162
local BASE_RESOLUTION = 1920

local lastVsx, lastVsy = 0, 0
local currentLeftVw = INITIAL_LEFT_VW
local currentTopVh = INITIAL_TOP_VH

local uiState = { updatingFromCode = false, draggingSlider = nil }
-- guideMode lives on widgetState (shared with tf_guide module)

-- Window drag state (module-level so widget:MouseMove/MouseRelease can access)
local WINDOW_SNAP_THRESHOLD = 30
local windowDragState = {
	active = false,
	rootEl = nil,
	offsetX = 0,
	offsetY = 0,
	ew = 0,
	eh = 0,
	vsx = 0,
	vsy = 0,
	lastX = -1,
	lastY = -1,
	snapRects = nil,
}
local windowDragAllWindows = {}
-- floatingTipEl, currentHint, lastRenderedHint live on widgetState (shared with tf_guide)

local widgetState = {
	rmlContext = nil,
	document = nil,
	dmHandle = nil,
	rootElement = nil,
	modeButtons = {},
	shapeButtons = {},
	rampTypeButtons = {},
	panelWidthDp = BASE_WIDTH_DP,
	-- Feature placer section elements
	fpSubmodesEl = nil,
	fpControlsEl = nil,
	tfControlsEl = nil,
	fpSubModeButtons = {},
	fpDistButtons = {},
	-- Weather brush section elements
	wbSubmodesEl = nil,
	wbControlsEl = nil,
	wbSubModeButtons = {},
	wbDistButtons = {},
	-- Splat painter section elements
	spControlsEl = nil,
	spPreviewEls = nil,
	spPreviewTextures = nil,
	spPreviewVerified = false,
	-- Decal section elements
	dcControlsEl = nil,
	dcSubmodesEl = nil,
	dcDistButtons = {},
	decalsActive = false,
	-- Metal brush section elements
	mbSubmodesEl = nil,
	mbControlsEl = nil,
	mbSubModeButtons = {},
	mbShapeButtons = {},
	-- Grass brush section elements
	gbSubmodesEl = nil,
	gbControlsEl = nil,
	gbSubModeButtons = {},
	gbShapeButtons = {},
	-- Noise brush section elements
	noiseRootEl = nil,
	noiseTypeButtons = {},
	-- Environment section elements
	envControlsEl = nil,
	envActive = false,
	envSkyboxThumbs = {},
	envCurrentSkybox = nil,
	envDefaultSkybox = nil,
	envLoadedTextures = {},  -- DDS paths pre-loaded into GL, freed on shutdown
	-- Light placer section elements
	lightControlsEl = nil,
	lightActive = false,
	lightTypeButtons = {},
	lightModeButtons = {},
	lightDistButtons = {},
	lightLibraryOpen = false,
	lightLibraryRootEl = nil,
	lightLibraryTab = "builtin",  -- "builtin" or "user"
	lightLibrarySelectedPreset = nil,
	-- Start Positions tool section elements
	startposActive = false,
	stpSubmodesEl = nil,
	stpControlsEl = nil,
	stpSubModeButtons = {},
	stpShapeButtons = {},
	stpShapeOptionsEl = nil,
	stpShapeRowEl = nil,
	stpExpressHintEl = nil,
	stpStartboxHintEl = nil,
	envFadeEnabled = true,   -- whether skybox transitions use fade effect
	skyboxLibraryRootEl = nil, -- floating skybox library window element
	-- Environment sub-window elements and open state
	envSunRootEl = nil,
	envFogRootEl = nil,
	envGroundLightingRootEl = nil,
	envUnitLightingRootEl = nil,
	envMapRootEl = nil,
	envWaterRootEl = nil,
	envDimensionsRootEl = nil,
	splatTexRootEl = nil,
	envSunOpen = false,
	envFogOpen = false,
	envGroundLightingOpen = false,
	envUnitLightingOpen = false,
	envMapOpen = false,
	envWaterOpen = false,
	envDimensionsOpen = false,
	splatTexOpen = false,
	-- Map defaults captured at init for resets
	envDefaults = nil,
	-- Slider wheel-lock state
	lockedSliders = {},         -- {[sliderId] = element}
	sliderLastClickTime = {},   -- {[sliderId] = timerObj}
	sliderPulsePhase = false,
	sliderPulseTimer = 0,
	-- Slider keybind-scroll flash state
	sliderFlashes = {},         -- {[sliderId] = {el, timer}}
	prevSyncValues = {},        -- {[sliderId] = valueString}
	-- Passthrough mode: deactivate all tools but keep panel visible
	passthroughMode = false,
	passthroughSaved = nil,     -- {tool=string, mode=string|nil}
	-- Settings window
	settingsRootEl = nil,
	settingsOpen = false,
	settingsCapturing = nil,    -- action name being rebound, or nil
	settingsCaptureField = nil, -- "key" or "key2" for scroll controls
	settingsCaptureEl = nil,    -- the DOM element currently being captured
	settingsPendingBinds = nil, -- deep copy of keybinds being edited
	settingsKeybindEls = {},    -- {[action] = keyElement}
	-- G3: shortcut discovery tip state (guide mode only)
	g3GroupCounts = {},  -- {[groupKey] = interactionCount}
	g3GroupShown  = {},  -- {[groupKey] = true} once shown this session
	g3Toast       = { text = nil, expiry = 0 },  -- active proactive hint
	-- Full restore confirm state
	fullRestoreConfirmExpiry = 0,
	-- Metal clean confirm state
	metalCleanConfirmExpiry = 0,
	-- Auto-scroll transport state (per-slider, keyed by slider element id)
	transports = {},
	-- Currently focused RmlUI input element (text/number boxes); cleared on blur.
	-- Used to auto-blur when game chat is opened, so Tab autocomplete isn't stolen by RmlUI.
	focusedRmlInput = nil,
	-- Module-shared mutable state
	noiseManuallyHidden = false,
	lastNoiseActive = false,
	skyboxLibraryOpen = false,
	-- Guide mode shared state (used by tf_guide + updateFloatingTip in main)
	soundMuted = false,
	guideMode = false,
	floatingTipEl = nil,
	currentHint = nil,
	lastRenderedHint = nil,
}

-- Skybox fade transition state (outside widgetState to avoid serialisation concerns)
local skyFade = {
	active = false,       -- is a transition in progress?
	phase = "idle",       -- "fadeout" | "fadein" | "idle"
	progress = 0,         -- 0..1
	speed = 3.0,          -- full fade in/out takes ~0.33 s
	pendingTexture = nil, -- DDS path to apply at the midpoint
	-- Saved sun lighting values (restored after fade)
	origUnitAmbient    = nil,
	origUnitDiffuse    = nil,
	origUnitSpecular   = nil,
	origGroundAmbient  = nil,
	origGroundDiffuse  = nil,
	origGroundSpecular = nil,
}

-- Dynamic skybox rotation state
local skyDynamic = {
	playing = false,
	speedX = 0,  -- rad/s around X axis
	speedY = 0,  -- rad/s around Y axis
	speedZ = 0,  -- rad/s around Z axis
	angleX = 0,  -- accumulated delta rotation since play
	angleY = 0,
	angleZ = 0,
	startQuat = nil,  -- {x,y,z,w} skybox quaternion at play-start
	sunSync = false,  -- rotate sun direction in lockstep
	origSunDir = nil, -- {x,y,z} captured when play is pressed
	origQuat = nil,   -- alias for startQuat (used by sun delta calc)
	-- Cached DOM elements for sun slider feedback (populated during init)
	sunSliderX = nil, sunLabelX = nil,
	sunSliderY = nil, sunLabelY = nil,
	sunSliderZ = nil, sunLabelZ = nil,
}

-- Quaternion helpers for composing per-axis rotations
local function quatFromAxisAngle(ax, ay, az, angle)
	local h = angle * 0.5
	local s = math.sin(h)
	return ax * s, ay * s, az * s, math.cos(h)
end

local function quatMul(ax, ay, az, aw, bx, by, bz, bw)
	return aw*bx + ax*bw + ay*bz - az*by,
	       aw*by - ax*bz + ay*bw + az*bx,
	       aw*bz + ax*by - ay*bx + az*bw,
	       aw*bw - ax*bx - ay*by - az*bz
end

local function quatToAxisAngle(qx, qy, qz, qw)
	local len = math.sqrt(qx*qx + qy*qy + qz*qz + qw*qw)
	if len > 0 then qx, qy, qz, qw = qx/len, qy/len, qz/len, qw/len end
	if qw < 0 then qx, qy, qz, qw = -qx, -qy, -qz, -qw end
	local sinHalf = math.sqrt(qx*qx + qy*qy + qz*qz)
	if sinHalf < 1e-8 then
		return 0, 1, 0, 0
	end
	local angle = 2 * math.atan2(sinHalf, qw)
	return qx / sinHalf, qy / sinHalf, qz / sinHalf, angle
end

local PI2 = math.pi * 2
local function wrapAngle(a)
	return a - PI2 * math.floor(a / PI2)
end

-- Rotate a vector by a quaternion: v' = q * v * q^-1
local function quatRotateVec(qx, qy, qz, qw, vx, vy, vz)
	local tx = 2 * (qy*vz - qz*vy)
	local ty = 2 * (qz*vx - qx*vz)
	local tz = 2 * (qx*vy - qy*vx)
	return vx + qw*tx + (qy*tz - qz*ty),
	       vy + qw*ty + (qz*tx - qx*tz),
	       vz + qw*tz + (qx*ty - qy*tx)
end

-- Quaternion inverse (conjugate for unit quaternions)
local function quatInv(qx, qy, qz, qw)
	return -qx, -qy, -qz, qw
end

local function tickSkyDynamic(dt)
	if not skyDynamic.playing then return end
	if skyDynamic.speedX == 0 and skyDynamic.speedY == 0 and skyDynamic.speedZ == 0 then return end

	skyDynamic.angleX = wrapAngle(skyDynamic.angleX + skyDynamic.speedX * dt)
	skyDynamic.angleY = wrapAngle(skyDynamic.angleY + skyDynamic.speedY * dt)
	skyDynamic.angleZ = wrapAngle(skyDynamic.angleZ + skyDynamic.speedZ * dt)

	-- Build delta quaternion from accumulated angles since play
	local dqx, dqy, dqz, dqw = quatFromAxisAngle(1, 0, 0, skyDynamic.angleX)
	local rx, ry, rz, rw = quatFromAxisAngle(0, 1, 0, skyDynamic.angleY)
	dqx, dqy, dqz, dqw = quatMul(dqx, dqy, dqz, dqw, rx, ry, rz, rw)
	rx, ry, rz, rw = quatFromAxisAngle(0, 0, 1, skyDynamic.angleZ)
	dqx, dqy, dqz, dqw = quatMul(dqx, dqy, dqz, dqw, rx, ry, rz, rw)

	-- Final skybox rotation = delta * startQuat
	local sq = skyDynamic.startQuat
	local qx, qy, qz, qw = dqx, dqy, dqz, dqw
	if sq then
		qx, qy, qz, qw = quatMul(dqx, dqy, dqz, dqw, sq[1], sq[2], sq[3], sq[4])
	end

	local ax, ay, az, angle = quatToAxisAngle(qx, qy, qz, qw)
	Spring.SetAtmosphere({ skyAxisAngle = { ax, ay, az, angle } })

	-- Rotate sun direction by delta from play-start orientation
	if skyDynamic.sunSync and skyDynamic.origSunDir then
		local sd = skyDynamic.origSunDir
		local sx, sy, sz = quatRotateVec(dqx, dqy, dqz, dqw, sd[1], sd[2], sd[3])
		Spring.SetSunDirection(sx, sy, sz)
		-- Update sun direction sliders to reflect current values
		if skyDynamic.sunSliderX then
			uiState.updatingFromCode = true
			local function setSlLb(sl, lb, v)
				if sl then sl:SetAttribute("value", tostring(math.floor(v * 10000 + 0.5))) end
				if lb then lb.inner_rml = string.format("%.2f", v) end
			end
			setSlLb(skyDynamic.sunSliderX, skyDynamic.sunLabelX, sx)
			setSlLb(skyDynamic.sunSliderY, skyDynamic.sunLabelY, sy)
			setSlLb(skyDynamic.sunSliderZ, skyDynamic.sunLabelZ, sz)
			uiState.updatingFromCode = false
		end
	end
end

-- Helper: read a sun lighting colour as {r,g,b}
local function getSunColor(kind, scope)
	local r, g, b = gl.GetSun(kind, scope)
	if r then return {r, g, b} end
	return {1, 1, 1}
end

-- Helper: scale a saved {r,g,b} colour and apply via SetSunLighting
local function setSunColorScaled(key, base, scale)
	Spring.SetSunLighting({ [key] = { base[1]*scale, base[2]*scale, base[3]*scale } })
end

-- Start a skybox fade transition (screen overlay fade-to-black)
local function startSkyboxFade(newTexturePath)
	if skyFade.active and skyFade.phase == "fadeout" then
		skyFade.pendingTexture = newTexturePath
		return
	end
	-- Capture current lighting so we can dim and restore it
	skyFade.origUnitAmbient    = getSunColor("ambient", "unit")
	skyFade.origUnitDiffuse    = getSunColor("diffuse", "unit")
	skyFade.origUnitSpecular   = getSunColor("specular", "unit")
	skyFade.origGroundAmbient  = getSunColor("ambient")
	skyFade.origGroundDiffuse  = getSunColor("diffuse")
	skyFade.origGroundSpecular = getSunColor("specular")
	skyFade.pendingTexture = newTexturePath
	skyFade.phase = "fadeout"
	skyFade.progress = 0
	skyFade.active = true
end
widgetState.startSkyboxFade = startSkyboxFade

-- Apply a skybox change: uses fade if enabled, instant swap otherwise
local function applySkybox(texturePath)
	if not texturePath then return end
	if texturePath ~= "" and not VFS.FileExists(texturePath) then
		Spring.Echo("[Terraform Brush] Skybox texture not found: " .. texturePath)
		return
	end
	if widgetState.envFadeEnabled then
		startSkyboxFade(texturePath)
	else
		Spring.SetSkyBoxTexture(texturePath)
	end
end
widgetState.applySkybox = applySkybox

local function tickSkyboxFade(dt)
	if not skyFade.active then return end
	local step = skyFade.speed * dt

	if skyFade.phase == "fadeout" then
		skyFade.progress = math.min(1, skyFade.progress + step)
		-- Dim lighting in sync with the sky overlay
		local s = 1 - skyFade.progress
		setSunColorScaled("unitAmbientColor",    skyFade.origUnitAmbient,    s)
		setSunColorScaled("unitDiffuseColor",    skyFade.origUnitDiffuse,    s)
		setSunColorScaled("unitSpecularColor",   skyFade.origUnitSpecular,   s)
		setSunColorScaled("groundAmbientColor",  skyFade.origGroundAmbient,  s)
		setSunColorScaled("groundDiffuseColor",  skyFade.origGroundDiffuse,  s)
		setSunColorScaled("groundSpecularColor", skyFade.origGroundSpecular, s)
		if skyFade.progress >= 1 then
			if skyFade.pendingTexture then
				Spring.SetSkyBoxTexture(skyFade.pendingTexture)
			end
			skyFade.phase = "fadein"
			skyFade.progress = 0
		end
	elseif skyFade.phase == "fadein" then
		skyFade.progress = math.min(1, skyFade.progress + step)
		-- Restore lighting in sync
		local s = skyFade.progress
		setSunColorScaled("unitAmbientColor",    skyFade.origUnitAmbient,    s)
		setSunColorScaled("unitDiffuseColor",    skyFade.origUnitDiffuse,    s)
		setSunColorScaled("unitSpecularColor",   skyFade.origUnitSpecular,   s)
		setSunColorScaled("groundAmbientColor",  skyFade.origGroundAmbient,  s)
		setSunColorScaled("groundDiffuseColor",  skyFade.origGroundDiffuse,  s)
		setSunColorScaled("groundSpecularColor", skyFade.origGroundSpecular, s)
		if skyFade.progress >= 1 then
			-- Ensure exact original values are restored
			Spring.SetSunLighting({
				unitAmbientColor    = skyFade.origUnitAmbient,
				unitDiffuseColor    = skyFade.origUnitDiffuse,
				unitSpecularColor   = skyFade.origUnitSpecular,
				groundAmbientColor  = skyFade.origGroundAmbient,
				groundDiffuseColor  = skyFade.origGroundDiffuse,
				groundSpecularColor = skyFade.origGroundSpecular,
			})
			skyFade.active = false
			skyFade.phase = "idle"
		end
	end
end

local function clampPanelPosition()
	local vsx, vsy = GetViewGeometry()
	if vsx <= 0 or vsy <= 0 then return end
	local panelWidthPx = widgetState.panelWidthDp -- dp ~= px but close enough for clamping
	local panelWidthVw = (panelWidthPx / vsx) * 100
	local maxLeftVw = math.max(0, 100 - panelWidthVw - 1)
	local maxTopVh = 90 -- leave some room at bottom
	currentLeftVw = math.max(0, math.min(currentLeftVw, maxLeftVw))
	currentTopVh = math.max(0, math.min(currentTopVh, maxTopVh))
end

local function buildRootStyle()
	clampPanelPosition()
	return string.format("left: %.2fvw; top: %.2fvh; width: %ddp;",
		currentLeftVw, currentTopVh, widgetState.panelWidthDp)
end

-- All env sub-windows match the main panel width exactly.
local function applyEnvWindowWidths()
	local wDp = widgetState.panelWidthDp .. "dp"
	local envWins = {
		widgetState.envSunRootEl,
		widgetState.envFogRootEl,
		widgetState.envGroundLightingRootEl,
		widgetState.envUnitLightingRootEl,
		widgetState.envMapRootEl,
		widgetState.envWaterRootEl,
		widgetState.envDimensionsRootEl,
		widgetState.splatTexRootEl,
		widgetState.skyboxLibraryRootEl,
		widgetState.noiseRootEl,
		widgetState.lightLibraryRootEl,
	}
	for _, el in ipairs(envWins) do
		if el then el.style.width = wDp end
	end
end

local initialModel = {
	radius = 100,
	shapeName = "Circle",
	rotationDeg = 0,
	curve = "1.0",
	intensity = "1.0",

	lengthScale = "1.0",
	heightCapMinStr = "--",
	heightCapMaxStr = "--",
}

local shapeNames = {
	circle = "Circle",
	square = "Square",
	hexagon = "Hexagon",
	octagon = "Octagon",
	ring = "Ring",
	fill = "Fill",
}

local function setActiveClass(buttons, activeKey)
	for key, element in pairs(buttons) do
		if element then
			element:SetClass("active", key == activeKey)
		end
	end
end

local CLAY_UNAVAILABLE_MODES = { noise = true, restore = true }

local function clearPassthrough()
	if widgetState.passthroughMode then
		widgetState.passthroughMode = false
		widgetState.passthroughSaved = nil
		local doc = widgetState.document
		if doc then
			local ptBtn = doc:GetElementById("btn-passthrough")
			if ptBtn then ptBtn:SetClass("active", false) end
			local pauseIcon = doc:GetElementById("passthrough-icon-pause")
			if pauseIcon then pauseIcon:SetClass("hidden", false) end
			local playIcon = doc:GetElementById("passthrough-icon-play")
			if playIcon then playIcon:SetClass("hidden", true) end
		end
		if widgetState.rootElement then
			widgetState.rootElement:SetClass("passthrough-dimmed", false)
		end
	end
end

local function onModeClick(mode)
	return function(event)
		if widgetState.noTerraform then event:StopPropagation(); return end
		playSound("modeSwitch")
		clearPassthrough()
		-- Deactivate feature placer / weather brush / splat painter / metal brush when switching to a terraform mode
		if WG.MetalBrush then
			WG.MetalBrush.deactivate()
		end
		if WG.FeaturePlacer then
			WG.FeaturePlacer.deactivate()
		end
		if WG.WeatherBrush then
			WG.WeatherBrush.deactivate()
		end
		if WG.SplatPainter then
			WG.SplatPainter.deactivate()
		end
		if WG.GrassBrush then
			WG.GrassBrush.deactivate()
		end
		widgetState.envActive = false
		widgetState.lightActive = false
		if WG.LightPlacer then WG.LightPlacer.deactivate() end
		widgetState.startposActive = false
		if WG.StartPosTool then WG.StartPosTool.deactivate() end
		widgetState.cloneActive = false
		if WG.CloneTool then WG.CloneTool.deactivate() end

		if WG.TerraformBrush then
			WG.TerraformBrush.setMode(mode)
		end

		setActiveClass(widgetState.modeButtons, mode)
		local inRestore = mode == "restore"
		local clayBtn = widgetState.document and widgetState.document:GetElementById("btn-clay-mode")
		if clayBtn then
			clayBtn:SetClass("hidden", inRestore)
			clayBtn:SetClass("unavailable", CLAY_UNAVAILABLE_MODES[mode] == true)
		end
		local frEl = widgetState.fullRestoreEl or (widgetState.document and widgetState.document:GetElementById("btn-full-restore"))
		if frEl then
			frEl:SetClass("hidden", not inRestore)
		end
		event:StopPropagation()
	end
end

local function onShapeClick(shape)
	return function(event)
		playSound("shapeSwitch")
		-- Route to feature placer, splat painter, or terraform brush based on active mode
		local fpState = WG.FeaturePlacer and WG.FeaturePlacer.getState()
		local spState = WG.SplatPainter and WG.SplatPainter.getState()
		local lpState = WG.LightPlacer and WG.LightPlacer.getState()
		local lpActive = widgetState.lightActive and lpState and lpState.active
		if lpActive then
			if shape ~= "circle" and shape ~= "square" then
				event:StopPropagation()
				return
			end
			WG.LightPlacer.setShape(shape)
		elseif fpState and fpState.active then
			if shape == "ring" or shape == "fill" then
				event:StopPropagation()
				return
			end
			WG.FeaturePlacer.setShape(shape)
		elseif spState and spState.active then
			if shape == "ring" or shape == "fill" then
				event:StopPropagation()
				return
			end
			WG.SplatPainter.setShape(shape)
		elseif WG.TerraformBrush then
			local state = WG.TerraformBrush.getState()
			if state and state.mode == "ramp" and shape ~= "circle" and shape ~= "square" then
				event:StopPropagation()
				return
			end
			if state and (state.mode == "level" or state.mode == "smooth") and shape == "ring" then
				event:StopPropagation()
				return
			end
			WG.TerraformBrush.setShape(shape)
		end

		setActiveClass(widgetState.shapeButtons, shape)

		local ringWidthRowEl = widgetState.document and widgetState.document:GetElementById("ring-width-row")
		if ringWidthRowEl then
			ringWidthRowEl:SetClass("hidden", shape ~= "ring")
		end

		if widgetState.dmHandle then
			widgetState.dmHandle.shapeName = shapeNames[shape]
		end

		event:StopPropagation()
	end
end

local function onRotateCW(event)
	playSound("tick")
	if WG.TerraformBrush then
		WG.TerraformBrush.rotate(ROTATION_STEP)
	end

	event:StopPropagation()
end

local function onRotateCCW(event)
	playSound("tick")
	if WG.TerraformBrush then
		WG.TerraformBrush.rotate(-ROTATION_STEP)
	end

	event:StopPropagation()
end

local function onCurveUp(event)
	playSound("tick")
	if WG.TerraformBrush then
		local state = WG.TerraformBrush.getState()
		WG.TerraformBrush.setCurve(state.curve + CURVE_STEP)
	end

	event:StopPropagation()
end

local function onCurveDown(event)
	playSound("tick")
	if WG.TerraformBrush then
		local state = WG.TerraformBrush.getState()
		WG.TerraformBrush.setCurve(state.curve - CURVE_STEP)
	end

	event:StopPropagation()
end

local function onIntensityUp(event)
	playSound("tick")
	if WG.TerraformBrush then
		local state = WG.TerraformBrush.getState()
		local newI = state.intensity * 1.15
		if newI < state.intensity + 0.1 then newI = state.intensity + 0.1 end
		WG.TerraformBrush.setIntensity(newI)
	end

	event:StopPropagation()
end

local function onIntensityDown(event)
	playSound("tick")
	if WG.TerraformBrush then
		local state = WG.TerraformBrush.getState()
		local newI = state.intensity / 1.15
		if newI > state.intensity - 0.1 then newI = state.intensity - 0.1 end
		WG.TerraformBrush.setIntensity(newI)
	end

	event:StopPropagation()
end

local capMinValue = 0
local capMaxValue = 0
local capAbsolute = true
local ringWidthPct = 40  -- percent of radius; inner ratio = 1 - ringWidthPct/100

local function applyCap(which, value)
	if not WG.TerraformBrush then return end
	if which == "max" then
		WG.TerraformBrush.setHeightCapMax(value ~= 0 and value or nil)
	else
		WG.TerraformBrush.setHeightCapMin(value ~= 0 and value or nil)
	end
end

local function getEffectiveMaxIntensity()
	if capMaxValue ~= 0 or capMinValue ~= 0 then
		local maxCap = math.max(math.abs(capMaxValue), math.abs(capMinValue))
		return math.max(1.0, maxCap / HEIGHT_STEP)
	end
	return DEFAULT_MAX_INTENSITY
end

local function trackSliderDrag(element, id)
	element:AddEventListener("mousedown", function(event)
		local ls = widgetState.lockedSliders
		local lt = widgetState.sliderLastClickTime
		local now = Spring.GetTimer()

		-- If already locked, single click unlocks
		if ls[id] then
			ls[id] = nil
			element:SetClass("slider-locked", false)
			element:SetClass("slider-pulse", false)
			lt[id] = nil
			uiState.draggingSlider = id
			return
		end

		-- Double-click detection: lock the slider
		if lt[id] then
			local dt = Spring.DiffTimers(now, lt[id])
			if dt < 0.35 then
				ls[id] = element
				element:SetClass("slider-locked", true)
				lt[id] = nil
				playSound("sliderLock")
				return
			end
		end
		lt[id] = now

		-- Normal drag behavior
		uiState.draggingSlider = id
	end, false)
	element:AddEventListener("mouseup", function() uiState.draggingSlider = nil end, false)
end

-- Helper: sync slider value from state and flash green if it changed externally
local function syncAndFlash(el, id, newValStr)
	if not el or not newValStr then return end
	if uiState.draggingSlider == id then return end
	local prev = widgetState.prevSyncValues[id]
	el:SetAttribute("value", newValStr)
	widgetState.prevSyncValues[id] = newValStr
	if prev and prev ~= newValStr and not widgetState.lockedSliders[id] then
		widgetState.sliderFlashes[id] = { el = el, timer = 1.0 }
		el:SetClass("slider-flash", true)
	end
end

-- ============ Guide Mode ============

local guideHints = {
	-- MODE buttons
	["btn-raise"]       = "Raise terrain upward under your cursor. Hold LMB and drag to continuously sculpt hills and ridges.",
	["btn-lower"]       = "Lower terrain downward under your cursor. Hold RMB and drag to carve valleys and trenches.",
	["btn-level"]       = "MODIFY: average heights within the brush and blend toward that mean with a smooth falloff. Use the LEVEL submode to pin the target to your first-click height instead.",
	["btn-ramp"]        = "Click and drag to build a smooth slope between two elevation points. Use Length to control taper width.",
	["btn-restore"]     = "Erase your edits and restore the original map height — useful to undo a specific area without affecting the rest.",
	["btn-noise"]       = "Apply procedural noise to the terrain. Opens the Noise Parameters window to choose the noise type and detail.",
	["btn-passthrough"]  = "Pause all terraform tools and release keyboard/mouse controls back to the game. Click again or any mode button to resume.",
	["btn-features"]    = "Place decorative props like trees, rocks and crystals using the Feature Placer sub-tool.",
	["btn-weather"]     = "Spawn persistent weather particle effects such as rain, snow or dust with configurable rate and lifetime.",
	["btn-environment"] = "Change the skybox texture at runtime. Select from the skybox library or reset to the map default.",
	["btn-env-skybox-library"] = "Open the skybox library to browse and apply skybox textures with optional fade transitions.",
	["btn-env-sun-shadows"] = "Open the Sun & Shadows panel to adjust sun direction, height, and shadow density.",
	["btn-env-fog-atmo"] = "Open the Fog & Atmosphere panel to adjust fog distance, fog color, sun color, and sky color.",
	["btn-env-ground-lighting"] = "Open the Ground Lighting panel to adjust ground ambient, diffuse, and specular colors.",
	["btn-env-unit-lighting"] = "Open the Unit Lighting panel to adjust unit ambient, diffuse, and specular colors.",
	["btn-env-map-render"] = "Open the Map Rendering panel to adjust splat textures, void settings, and detail normals.",
	["btn-env-water"] = "Open the Water panel to adjust surface, fresnel, perlin noise, blur, wave, and caustics properties.",
	["btn-env-save"] = "Export all current environment settings to a Lua file in the Terraform Brush/Lightmaps/ folder for use by mappers.",
	["btn-lights"]      = "Place deferred GL4 lights on the map. Supports point, cone, and beam lights with scatter, single, and remove modes.",
	-- SHAPE buttons
	["btn-circle"]      = "Round brush with smooth radial falloff. The most natural-looking shape for hills and depressions.",
	["btn-square"]      = "Square brush with hard corners. Great for angular structures, walls and grid-aligned terrain edits.",
	-- RAMP TYPE buttons
	["btn-ramp-straight"] = "Straight ramp: drag from start to end point to create a linear slope. Simple and precise.",
	["btn-ramp-spline"]   = "Spline ramp: drag freely along a curved path to create a winding slope that follows your mouse movement.",
	["btn-hexagon"]     = "Hex-shaped brush, ideal for large flat tiles, honeycomb terrain layouts and hex-grid maps.",
	["btn-octagon"]     = "Eight-sided brush — a compact middle ground between circle and square for mid-sized edits.",
	["btn-triangle"]    = "Three-sided brush for sharp wedge-shaped terrain edits, cliff faces and triangular plateaus.",
	["btn-ring"]        = "Hollow ring brush that only affects the outer edge of the area. Perfect for craters and moats.",
	["btn-fill"]        = "Fill brush: click inside any enclosed terrain shape to flood-fill it. Flat fill when walls are uniform height; smooth biharmonic surface when walls vary.",
	["btn-clay-mode"]   = "Clay Brush restricts edits to only push terrain in one direction, preventing accidental raise while lowering and vice versa.",
	-- Overlay / visual toggles
	["btn-grid-overlay"]      = "Draws a measurement grid across the terrain to help align structures and judge distances. Always visible, not just inside the brush.",
	["btn-dust-effects"]      = "Toggle dust particle effects when terraforming. Purely cosmetic — only applies when DJ Mode is active.",
	["btn-seismic-effects"]   = "Toggle ground impact sounds while sculpting terrain. Only applies when DJ Mode is active.",
	["btn-dj-activate"]       = "Master switch for DJ Mode — when ON, all enabled DJ Mode effects (dust, seismic) are applied during sculpting.",
	["btn-height-colormap"]   = "Overlay a topographic height colormap on the brush footprint — colour-coded from blue (low) through green/yellow to red/white (high) with contour lines at 10% intervals.",
	["btn-curve-overlay"]     = "Draws the edge fall-off curve as an arc inside the brush circle so you can preview the blend gradient while painting.",
	["btn-velocity-intensity"] = "Scales brush intensity by mouse drag speed \xe2\x80\x94 move faster for stronger effect, slower for finer control.",
	["btn-pen-pressure"]       = "Modulates brush intensity (and optionally size) using tablet pen pressure. Requires pen_pressure_server.py running.",
	["btn-pen-intensity"]      = "Pen pressure is modulating intensity — click to toggle. Configure in Settings → Stroke.",
	["btn-pen-size"]           = "Pen pressure is modulating size — click to toggle. Configure in Settings → Stroke.",
	-- Undo / History
	["btn-undo"]        = "Undo the last brush stroke. Keyboard shortcut: Ctrl+Z.",
	["btn-redo"]        = "Redo a stroke that was undone. Keyboard shortcut: Ctrl+Shift+Z.",
	["slider-history"]  = "Scrub through your edit history. Drag left to undo multiple steps, right to redo — like a time-slider for your terrain.",
	-- Rotation
	["btn-rot-ccw"]     = "Rotate the brush counter-clockwise by a small step. Affects non-circular shapes and ramp direction.",
	["btn-rot-cw"]      = "Rotate the brush clockwise by a small step. Affects non-circular shapes and ramp direction.",
	["slider-rotation"] = "Set the brush rotation angle from 0–359°. Affects all non-circular shapes. Shortcut: Alt+Scroll.",
	-- Intensity
	["btn-intensity-down"] = "Decrease the sculpt speed — gentler edits that change height more slowly per second.",
	["btn-intensity-up"]   = "Increase the sculpt speed — more aggressive edits that cut or raise terrain faster.",
	["slider-intensity"]   = "Controls how fast terrain is sculpted. Low values are subtle and precise; high values are very aggressive. Space+Scroll.",

	-- Restore strength
	["btn-restore-strength-down"] = "Decrease restore target \xe2\x80\x94 lower values blend only partway back toward original height.",
	["btn-restore-strength-up"]   = "Increase restore target \xe2\x80\x94 100% restores fully to original map height.",
	["slider-restore-strength"]   = "Controls how far toward original height the restore brush blends. 100% = full restore, 50% = halfway, 0% = no change.",

	-- Size
	["btn-size-down"]      = "Shrink the brush radius by one step. Keyboard shortcut: Ctrl+Scroll (scroll down).",
	["btn-size-up"]        = "Grow the brush radius by one step. Keyboard shortcut: Ctrl+Scroll (scroll up).",
	["slider-size"]        = "Sets the brush radius in world units. Small values give fine detail; large values reshape broad areas. Ctrl+Scroll.",
	["slider-ring-width"]  = "Controls how thick the ring band is as a percentage of the brush radius. 5% = very thin edge; 95% = nearly full solid brush. Ctrl+R+Scroll.",
	["btn-ring-width-down"] = "Narrow the ring band, making it thinner and more precise.",
	["btn-ring-width-up"]   = "Widen the ring band, filling more of the brush area with the effect.",
	-- Length
	["btn-length-down"] = "Shorten the brush along its axis, making it more circular.",
	["btn-length-up"]   = "Lengthen the brush along its rotation axis, stretching it into an oval or ramp shape.",
	["slider-length"]   = "Stretches the brush into an oval or elongated ramp along its rotation direction. Ctrl+Alt+Scroll.",
	-- Fall-off Curve
	["btn-curve-down"]  = "Flatten the edge fall-off — gives a wider plateau and a gradual slope to the edge.",
	["btn-curve-up"]    = "Sharpen the edge fall-off — terrain drops off more steeply right at the brush boundary.",
	["slider-curve"]    = "Controls edge fall-off sharpness. Low = gentle gradient, high = cliff-like drop at the brush edge. Shift+Scroll.",
	-- Height Cap
	["btn-cap-absolute"] = "When on, cap values are world-space elevations. When off, they are offsets relative to where you start the stroke.",
	["slider-cap-max"]   = "Clamps the maximum elevation the brush can raise terrain to. Useful to keep edits within a specific height band.",
	["btn-cap-max-down"] = "Decrease the height cap maximum by one step.",
	["btn-cap-max-up"]   = "Increase the height cap maximum by one step.",
	["btn-sample-max"]   = "Enter height-sampling mode: hover over a topo contour line and click to set that elevation as the Max cap. Click the peak number to use the highest point in the brush area.",
	["slider-cap-min"]   = "Clamps the minimum elevation the brush can lower terrain to. Combine with Max to lock edits inside a height range.",
	["btn-cap-min-down"] = "Decrease the height cap minimum by one step.",
	["btn-cap-min-up"]   = "Increase the height cap minimum by one step.",
	["btn-sample-min"]   = "Enter height-sampling mode: hover over a topo contour line and click to set that elevation as the Min cap. Click the peak number to use the highest point in the brush area.",
	-- Restore defaults
	["btn-defaults"]    = "Reset all brush settings — size, intensity, fall-off curve, rotation, height caps and toggle states — back to their factory defaults.",
	-- Presets
	["preset-name-input"] = "Type a name here to save the current brush settings as a reusable preset, or to filter the preset list.",
	["btn-preset-save"]   = "Save the current brush settings under the typed name. Built-in presets show in italic and cannot be overwritten.",
	["btn-preset-toggle"] = "Open or close the preset dropdown list to load or delete a saved brush configuration.",
	-- Export / Import
	["btn-export"]      = "Export the current heightmap as a 16-bit PNG image to disk for backup or external editing in other tools.",
	-- Feature Placer sub-modes
	["btn-fp-scatter"]  = "Scatter features randomly across the brush area with each drag — ideal for natural-looking forests and rock fields.",
	["btn-fp-point"]    = "Place features exactly at the cursor position. Click once to plant a single feature precisely.",
	["btn-fp-remove"]   = "Erase existing features under the brush cursor — removes props placed earlier without affecting terrain.",
	-- Feature distribution
	["btn-fp-dist-random"]    = "Spread features at randomly chosen positions within the brush area for an organic, varied look.",
	["btn-fp-dist-regular"]   = "Space features in a uniform grid pattern inside the brush for orderly, evenly distributed arrangements.",
	["btn-fp-dist-clustered"] = "Group features in tight natural clusters, mimicking how plants or rocks tend to gather together.",
	-- Feature smart filter
	["btn-fp-smart-toggle"] = "Enable Smart Filter — makes placement terrain-aware by skipping water, cliffs or altitude zones you configure below.",
	["btn-fp-grid-overlay"] = "Draws a measurement grid across the terrain to help align features and judge distances. Always visible, not just inside the brush.",
	["btn-fp-grid-snap"]    = "Snap feature placement positions to the build grid (48 elmo intervals) for precise, aligned placement.",
	["btn-fp-avoid-water"]  = "Skip placement on underwater terrain so features only land on dry ground above sea level.",
	["btn-fp-avoid-cliffs"] = "Prevent features from spawning on slopes steeper than the Max Slope angle you set.",
	["btn-fp-prefer-slopes"] = "Only place features on slopes steeper than the Min Slope angle — useful for cliff-face vegetation.",
	["btn-fp-alt-min-enable"] = "Enable a minimum altitude filter — no features will be placed below this elevation threshold.",
	["btn-fp-alt-max-enable"] = "Enable a maximum altitude filter — no features will be placed above this elevation threshold.",
	-- Feature sliders
	["fp-slider-size"]       = "Radius of the feature placement area. Ctrl+Scroll to resize while painting.",
	["fp-slider-rotation"]   = "Base rotation angle for all placed features. Individual randomization is added on top of this value.",
	["fp-slider-rot-random"] = "Randomizes each feature's orientation by ±this percentage. 100% = fully random; 0% = all face the same direction.",
	["fp-slider-count"]      = "Number of features placed per brush stroke — higher counts fill the area more densely.",
	["fp-slider-cadence"]    = "How fast features are placed while dragging — lower values produce more features per distance traveled.",
	-- Feature undo/save/load
	["btn-fp-undo"]    = "Undo the last batch of placed or removed features, restoring the previous state.",
	["btn-fp-redo"]    = "Redo features that were just undone.",
	["slider-fp-history"] = "Scrub through feature placement history. Drag left to undo multiple steps, right to redo.",
	["btn-fp-save"]    = "Save the current feature layout to a file on disk so you can restore it later.",
	["btn-fp-load"]    = "Load a previously saved feature layout from disk, restoring all features from that session.",
	["btn-fp-clearall"] = "Remove all features placed in this session from the map — cannot be undone.",
	-- Weather sub-modes
	["btn-wb-scatter"]  = "Scatter weather effects randomly across the brush area each time you paint.",
	["btn-wb-point"]    = "Place a weather effect exactly at the clicked cursor position.",
	["btn-wb-remove"]   = "Erase persistent weather effects under the brush — removes effects that were painted earlier.",
	-- Weather distribution
	["btn-wb-dist-random"]  = "Spawn weather particles at randomly chosen positions within the brush area.",
	["btn-wb-dist-regular"] = "Spawn weather particles in a uniform grid pattern for organized, evenly spaced effects.",
	["btn-wb-dist-clustered"] = "Group weather particles in tight clusters for concentrated effect zones.",
	-- Decal distribution
	["btn-dc-dist-random"]    = "Place decals at random positions within the brush area.",
	["btn-dc-dist-regular"]   = "Space decals in a uniform grid pattern inside the brush.",
	["btn-dc-dist-clustered"] = "Group decals in tight clusters for natural-looking placement.",
	-- Light distribution
	["btn-lp-dist-random"]    = "Place lights at random positions within the brush area.",
	["btn-lp-dist-regular"]   = "Space lights in a uniform grid pattern inside the brush.",
	["btn-lp-dist-clustered"] = "Group lights in tight clusters for concentrated illumination.",
	-- Weather sliders
	["wb-slider-size"]      = "Area radius of the weather effect zone. Ctrl+Scroll to resize while painting.",
	["wb-slider-length"]    = "Elongates the weather pattern along its axis — makes rain streaks or gusts cover a longer area.",
	["wb-slider-rotation"]  = "Direction the weather moves — adjust this to set wind angle for rain, snow or dust.",
	["wb-slider-count"]     = "Number of particles spawned per emission tick — higher values create denser effects.",
	["wb-slider-cadence"]   = "How quickly particles are emitted while dragging to paint — controls density per stroke.",
	["wb-slider-frequency"] = "How often persistent effects repeat their spawn cycle. Lower interval = more frequent bursts.",
	["wb-slider-persist"]   = "How long particles from a painted effect linger before fading. Increase for long-lasting rain or snow.",
	["btn-wb-persistent"]   = "Enable permanent mode — painted weather effects never fade away until you manually clear them.",
	["btn-wb-clearall"]     = "Remove all persistent weather effects currently active on the map.",
	-- Noise Parameters (in noise window)
	["btn-noise-perlin"]  = "Classic gradient noise — smooth, flowing and organic. The most natural-looking all-purpose noise type.",
	["btn-noise-voronoi"] = "Cell-based noise producing cracked earth, tile-like or rocky terrain patterns with distinct cell edges.",
	["btn-noise-fbm"]     = "Fractal Brownian Motion stacks multiple noise layers for highly detailed, multi-scale natural terrain.",
	["btn-noise-billow"]  = "Absolute-value noise creating billowy cloud-like domes and rolling hills with soft rounded peaks.",
	["slider-noise-scale"]       = "Size of each noise cell in world units — larger values give broader, smoother terrain shapes.",
	["slider-noise-octaves"]     = "Number of detail layers stacked on top of each other. More octaves add progressively finer micro-detail.",
	["slider-noise-persistence"] = "How much each successive octave's amplitude shrinks. Higher values keep fine details bold and prominent.",
	["slider-noise-lacunarity"]  = "How much each octave's frequency multiplies per layer. Higher values pack in much more detail per octave.",
	["slider-noise-seed"]        = "Random seed for the noise pattern. Change it to get a completely different terrain layout with the same settings.",
	["btn-noise-reseed"]         = "Pick a new random seed instantly, generating a fresh noise pattern without adjusting any other parameters.",
	["btn-noise-seed-down"]      = "Decrease noise seed by 1.",
	["btn-noise-seed-up"]        = "Increase noise seed by 1.",
	-- Splat Painter
	["btn-splat"]               = "Paint the splatmap distribution texture that controls which ground detail texture is visible in each area of the map.",
	-- Metal brush
	["btn-metal"]               = "Paint and stamp metal deposits on the map. LMB raises metal, RMB lowers. Stamp mode places standard metal spots. Requires /cheat.",
	["btn-mb-paint"]            = "Continuous paint mode: hold LMB to add metal, RMB to remove. Intensity and falloff control the rate.",
	["btn-mb-stamp"]            = "Stamp a complete metal spot in one click. LMB places, RMB erases. Metal value and brush size control the spot.",
	["btn-mb-remove"]           = "Remove metal from the map. Click or drag to erase metal spots.",
	["slider-metal-value"]      = "Target metal extraction rate for stamp mode. Standard mex spots use 2.0. Space+Scroll to adjust in-game.",
	["btn-metal-value-down"]    = "Decrease metal extraction value by ~10%.",
	["btn-metal-value-up"]      = "Increase metal extraction value by ~10%.",
	["btn-metal-save"]          = "Save the current metal map to a Lua data file in LuaUI/Config/MetalMaps/.",
	["btn-metal-load"]          = "Load a previously saved metal map from disk and apply it to the map.",
	["btn-metal-clean"]         = "Remove ALL metal from the map. Click once to arm, click again to confirm.",
	-- Grass brush
	["btn-grass"]               = "Paint and erase grass density on the map. LMB grows grass, RMB removes. Fill mode sets entire area at once. Requires /cheat.",
	["btn-gb-paint"]            = "Continuous paint mode: hold LMB to grow grass, RMB to remove. Density and falloff control the brush.",
	["btn-gb-fill"]             = "Fill mode: click LMB to set brush area to target density, RMB to clear all grass in area.",
	["slider-grass-density"]    = "Target grass density (0-100%). Paint mode paints toward this density; Fill mode stamps it instantly. Space+Scroll.",
	["btn-grass-density-down"]  = "Decrease grass density by 5%.",
	["btn-grass-density-up"]    = "Increase grass density by 5%.",
	["btn-grass-save"]          = "Export the current grass map to a TGA image file for use in map distribution.",
	["slider-gb-size"]          = "Brush radius for grass painting. Ctrl+Scroll.",
	["slider-gb-rotation"]      = "Rotation angle for non-circular grass brush shapes (0-359°). Alt+Scroll.",
	["slider-gb-curve"]         = "Edge fall-off sharpness for grass painting. Low = gentle gradient, high = hard edge. Shift+Scroll.",
	["slider-mb-size"]          = "Brush radius for metal painting and stamping. Ctrl+Scroll.",
	["slider-mb-rotation"]      = "Rotation angle for non-circular metal brush shapes (0–359°). Alt+Scroll.",
	["slider-mb-length"]        = "Stretches the metal brush into an elongated shape along its rotation axis. Ctrl+Alt+Scroll.",
	["slider-mb-curve"]         = "Edge fall-off sharpness for metal painting. Low = gentle gradient, high = hard edge. Shift+Scroll.",
	-- Start Positions
	["btn-sp-rot-ccw"]          = "Rotate the start position layout counter-clockwise.",
	["btn-sp-rot-cw"]           = "Rotate the start position layout clockwise.",
	["btn-sp-ch1"]              = "Paint into channel 1 (Red) of the splatmap. Corresponds to the first detail ground texture.",
	["btn-sp-ch2"]              = "Paint into channel 2 (Green) of the splatmap. Corresponds to the second detail ground texture.",
	["btn-sp-ch3"]              = "Paint into channel 3 (Blue) of the splatmap. Corresponds to the third detail ground texture.",
	["btn-sp-ch4"]              = "Paint into channel 4 (Alpha) of the splatmap. Corresponds to the fourth detail ground texture.",
	["sp-slider-strength"]      = "Controls paint opacity per stroke. Low values let you blend textures subtly; high values replace quickly.",
	["sp-slider-intensity"]     = "Multiplier on effective paint strength. Combines with Strength for aggressive or subtle painting. Space+Scroll.",
	["sp-slider-size"]          = "Sets the brush radius in world units. Ctrl+Scroll to resize while painting.",
	["sp-slider-rotation"]      = "Set the brush rotation angle from 0–359°. Affects non-circular shapes. Alt+Scroll.",
	["sp-slider-curve"]         = "Controls edge fall-off sharpness. Low = gentle gradient, high = hard-edged painting at the brush boundary.",
	["btn-sp-smart-toggle"]     = "Enable Smart Filter — makes painting terrain-aware by skipping water, cliffs or altitude zones you configure.",
	["btn-sp-avoid-water"]      = "Skip painting on underwater terrain so splats only affect dry ground above sea level.",
	["btn-sp-avoid-cliffs"]     = "Prevent painting on slopes steeper than the Max Slope angle.",
	["btn-sp-prefer-slopes"]    = "Only paint on slopes steeper than the Min Slope angle — useful for cliff-face texturing.",
	["btn-sp-alt-min-enable"]   = "Enable a minimum altitude filter — no painting below this elevation threshold.",
	["btn-sp-alt-max-enable"]   = "Enable a maximum altitude filter — no painting above this elevation threshold.",
	["btn-sp-export-format"]    = "Click to cycle the export image format between PNG, DDS and TGA.",
	["btn-sp-save"]             = "Save the current splatmap distribution texture to disk for backup or external editing.",
	["btn-decals"]              = "Open the Decals panel: decal library (scars, explosions, tracks, builds) and combat heatmap tools.",
	["btn-dc-heatmap-export"]   = "Save the combat heatmap (accumulated explosion density) as CSV grid + PGM grayscale image.",
	["btn-dc-heatmap-reset"]    = "Reset the heatmap — clears all accumulated explosion tracking data.",
	-- Light Placer controls
	["btn-lt-point"]            = "Omnidirectional point light — radiates equally in all directions. Good for general ambient fill and glowing effects.",
	["btn-lt-cone"]             = "Directional cone/spotlight — casts a focused beam in one direction. Use pitch/yaw to aim and theta to control spread.",
	["btn-lt-beam"]             = "Linear beam light with a start and end point. Useful for laser-like effects and long glowing lines.",
	["btn-lp-point"]            = "Place a single light at the exact cursor position. Click to place one at a time for precise control.",
	["btn-lp-scatter"]          = "Scatter multiple lights in the brush area with each click. Adjust count and brush radius below.",
	["btn-lp-remove"]           = "Erase placed lights under the brush cursor — removes lights within the brush radius.",
	["btn-lp-dist-random"]      = "Distribute scattered lights at random positions within the brush for an organic look.",
	["btn-lp-dist-regular"]     = "Space scattered lights in a uniform grid pattern for orderly, evenly distributed placement.",
	["btn-lp-dist-clustered"]   = "Group scattered lights in tight clusters, mimicking how light sources tend to gather naturally.",
	["slider-lp-color-r"]       = "Red channel intensity for the light color (0–1). Combine R, G, B to mix any color.",
	["slider-lp-color-g"]       = "Green channel intensity for the light color (0–1). Combine R, G, B to mix any color.",
	["slider-lp-color-b"]       = "Blue channel intensity for the light color (0–1). Combine R, G, B to mix any color.",
	["slider-lp-brightness"]    = "Overall brightness multiplier. Higher values produce more intense light. Use with care — values above 5 can bloom significantly.",
	["slider-lp-light-radius"]  = "How far the light reaches from its center in world units (elmos). Larger radius = softer, wider light.",
	["slider-lp-elevation"]     = "Height offset above the ground where lights are placed (in elmos). 0 = on the ground, higher = floating above terrain. Shift+Scroll.",
	["slider-lp-pitch"]         = "Vertical aiming angle for cone/beam lights. -90 = straight down, 0 = horizontal, 90 = straight up.",
	["slider-lp-yaw"]           = "Horizontal rotation angle for cone/beam lights (0–360°). Controls which compass direction the light faces.",
	["slider-lp-roll"]          = "Roll rotation of cone/beam lights (0–360°). Mostly useful for asymmetric beam patterns.",
	["slider-lp-theta"]         = "Cone half-angle spread in radians. Smaller = tighter spotlight, larger = wider floodlight.",
	["slider-lp-beam-length"]   = "Length of the beam from start to end point in world units.",
	["slider-lp-count"]         = "Number of lights placed per scatter operation.",
	["slider-lp-brush-radius"]  = "Radius of the scatter brush area in world units. Lights are distributed within this zone.",
	["btn-lp-smart-toggle"]     = "Enable Smart Filter for light placement — skips water, cliffs or altitude zones.",
	["btn-lp-sf-water"]         = "Skip light placement on underwater terrain.",
	["btn-lp-sf-cliffs"]        = "Prevent lights from being placed on steep cliff faces.",
	["btn-lp-library"]          = "Open the Light Library to browse built-in presets and your saved light arrangements.",
	["btn-lp-undo"]             = "Undo the last light placement or removal action.",
	["btn-lp-redo"]             = "Redo a light action that was just undone.",
	["slider-lp-history"]       = "Scrub through light placement history. Drag left to undo multiple steps, right to redo.",
	["btn-lp-save"]             = "Save all currently placed lights to a timestamped file on disk.",
	["btn-lp-load"]             = "Load a previously saved light layout from disk.",
	["btn-lp-clear-all"]        = "Remove all placed lights from the map — cannot be undone.",
	["btn-lp-material-toggle"]  = "Show or hide the material properties section (model factor, specular, scattering, lens flare).",
}

-- G3: Shortcut discovery tip groups — shown near cursor after 3 interactions (guide mode only)
local g3TipGroups = {
	intensity = "Tip: Hold Space\xe2\x80\x94then scroll the mouse wheel to adjust intensity while sculpting. Faster than reaching for the slider!",
	size      = "Tip: Hold Ctrl and scroll to resize the brush in real time \xe2\x80\x94 no need to touch the slider.",
	rotation  = "Tip: Hold Alt and scroll to rotate the brush on the fly. Add Ctrl to also stretch its length (Ctrl+Alt+Scroll).",
	curve     = "Tip: Hold Shift and scroll to sharpen or soften the edge fall-off while you paint.",
	length    = "Tip: Hold Ctrl+Alt and scroll to stretch the brush length without using the slider.",
	ring      = "Tip: Hold Ctrl+R and scroll to fine-tune the ring band width while painting.",
	undo      = "Tip: Ctrl+Z undoes the last stroke \xe2\x80\x94 hold it down for rapid multi-step undo.",
	redo      = "Tip: Ctrl+Shift+Z redoes \xe2\x80\x94 hold it down for rapid multi-step redo.",
}
-- Maps UI element IDs to their tip group key for G3 interaction counting
local g3ElemGroup = {
	["slider-intensity"]    = "intensity",
	["btn-intensity-down"]  = "intensity",
	["btn-intensity-up"]    = "intensity",
	["slider-size"]         = "size",
	["btn-size-down"]       = "size",
	["btn-size-up"]         = "size",
	["slider-rotation"]     = "rotation",
	["btn-rot-ccw"]         = "rotation",
	["btn-rot-cw"]          = "rotation",
	["slider-curve"]        = "curve",
	["btn-curve-down"]      = "curve",
	["btn-curve-up"]        = "curve",
	["slider-length"]       = "length",
	["slider-ring-width"]   = "ring",
	["btn-ring-width-down"] = "ring",
	["btn-ring-width-up"]   = "ring",
	["btn-undo"]            = "undo",
	["btn-redo"]            = "redo",
}

local function updateFloatingTip()
	if not widgetState.floatingTipEl then return end
	-- G3 toast takes priority over the hover hint while it is still active
	local activeHint = widgetState.currentHint
	local g3t = widgetState.g3Toast
	if widgetState.guideMode and g3t.text then
		local now = Spring.GetGameSeconds()
		if now and now < g3t.expiry then
			activeHint = g3t.text
		else
			g3t.text = nil
			g3t.expiry = 0
		end
	end
	if not (widgetState.guideMode and activeHint) then
		widgetState.floatingTipEl:SetClass("hidden", true)
		widgetState.lastRenderedHint = nil
		return
	end
	local mx, my = GetMouseState()
	local vsx, vsy = GetViewGeometry()
	if not mx or vsx <= 0 or vsy <= 0 then return end
	-- Spring y is bottom-up (0=bottom of viewport); convert to RmlUi top-down (0=top)
	local TIP_W, TIP_H = 168, 100  -- approximate tooltip pixel size for edge clamping
	-- Show tooltip to the left of the cursor when in the right portion of the screen
	-- (where the terraform brush panel lives, ~78vw+), so it never overlaps the panel.
	local inRightRegion = mx > vsx * 0.62
	local leftPx
	if inRightRegion then
		leftPx = mx - TIP_W - 12
	else
		leftPx = mx + 16
		if leftPx + TIP_W > vsx then leftPx = mx - TIP_W - 12 end
	end
	local topPx = (vsy - my) + 32
	if topPx + TIP_H > vsy then topPx = (vsy - my) - TIP_H - 6 end
	leftPx = math.max(0, leftPx)
	topPx  = math.max(0, topPx)
	widgetState.floatingTipEl:SetAttribute("style", string.format("left: %.2fvw; top: %.2fvh;",
		(leftPx / vsx) * 100, (topPx / vsy) * 100))
	if activeHint ~= widgetState.lastRenderedHint then
		widgetState.floatingTipEl.inner_rml = activeHint
		widgetState.lastRenderedHint = activeHint
	end
	widgetState.floatingTipEl:SetClass("hidden", false)
end

-- ═══════════════════════════════════════════════════════════════════════
-- KEYBIND BADGE SYSTEM (G5) + SETTINGS WINDOW SUPPORT
-- Maps button element IDs to keybind action names for dynamic badge text
-- ═══════════════════════════════════════════════════════════════════════
local BADGE_ACTION_MAP = {
	-- Terrain mode buttons
	["btn-level"]    = "mode_level",
	["btn-ramp"]     = "mode_ramp",
	["btn-restore"]  = "mode_restore",
	["btn-noise"]    = "mode_noise",
	-- Shape buttons
	["btn-circle"]   = "shape_circle",
	["btn-square"]   = "shape_square",
	["btn-hexagon"]  = "shape_hexagon",
	["btn-octagon"]  = "shape_octagon",
	["btn-triangle"] = "shape_triangle",
	-- Toggle buttons
	["btn-clay-mode"] = "toggle_clay",
	-- Tool buttons
	["btn-grass"]       = "tool_grass",
	["btn-metal"]       = "tool_metal",
	["btn-features"]    = "tool_features",
	["btn-splat"]       = "tool_splat",
	["btn-decals"]      = "tool_decals",
	["btn-weather"]     = "tool_weather",
	["btn-environment"] = "tool_environment",
	["btn-lights"]      = "tool_lights",
	["btn-startpos"]    = "tool_startpos",
	["btn-clone"]       = "tool_clone",
}

-- Maps tool keybind action → button element ID for Click() dispatch
local TOOL_BTN_MAP = {
	tool_grass       = "btn-grass",
	tool_metal       = "btn-metal",
	tool_features    = "btn-features",
	tool_splat       = "btn-splat",
	tool_decals      = "btn-decals",
	tool_weather     = "btn-weather",
	tool_environment = "btn-environment",
	tool_lights      = "btn-lights",
	tool_startpos    = "btn-startpos",
	tool_clone       = "btn-clone",
}

-- Keybind display order for the settings list (sorted)
-- Scroll controls first (most used), then regular keybinds
local SCROLL_DISPLAY_ORDER = {
	"scroll_size", "scroll_rotation", "scroll_protractor", "scroll_curve",
	"scroll_intensity", "scroll_length", "scroll_ring",
}
local KEYBIND_DISPLAY_ORDER = {
	"mode_level", "mode_noise", "mode_ramp", "mode_restore",
	"shape_circle", "shape_square", "shape_triangle", "shape_hexagon", "shape_octagon",
	"toggle_clay",
	"tool_grass", "tool_metal", "tool_features", "tool_splat", "tool_decals",
	"tool_weather", "tool_environment", "tool_lights", "tool_startpos", "tool_clone",
}

local badgeElements = {}  -- {[buttonId] = badgeDivElement}

local function keyCodeToLabel(keyCode)
	if not keyCode or keyCode == 0 then return "?" end
	local sym = Spring.GetKeySymbol(keyCode)
	if sym and sym ~= "" then
		return sym:upper()
	end
	-- Fallback: printable ASCII
	if keyCode >= 32 and keyCode <= 126 then
		return string.char(keyCode):upper()
	end
	return "?" .. keyCode
end

-- Update all keybind badge text from current widget keybinds
local function updateAllKeybindBadges()
	if not WG.TerraformBrush or not WG.TerraformBrush.getKeybinds then return end
	local binds = WG.TerraformBrush.getKeybinds()
	for btnId, action in pairs(BADGE_ACTION_MAP) do
		local el = badgeElements[btnId]
		if el and binds[action] then
			el.inner_rml = binds[action].label or "?"
		end
	end
	-- Update scroll keybind hint texts displayed next to every scroll-controlled parameter
	local doc = widgetState.document
	if doc then
		local function normKey(s)
			if not s or s == "" then return nil end
			local u = s:upper()
			if u == "LCTRL" or u == "RCTRL" then return "Ctrl"
			elseif u == "LSHIFT" or u == "RSHIFT" then return "Shift"
			elseif u == "LALT" or u == "RALT" then return "Alt"
			elseif u == "SPACE" then return "Space"
			else return u end
		end
		local hintMap = {
			["kbhint-cl-rotation"]  = "scroll_rotation",
			["kbhint-cl-height"]    = "scroll_curve",
			["kbhint-mb-size"]      = "scroll_size",
			["kbhint-mb-rotation"]  = "scroll_rotation",
			["kbhint-mb-length"]    = "scroll_length",
			["kbhint-mb-curve"]     = "scroll_curve",
			["kbhint-gb-size"]      = "scroll_size",
			["kbhint-gb-length"]    = "scroll_length",
			["kbhint-gb-rotation"]  = "scroll_rotation",
			["kbhint-gb-curve"]     = "scroll_curve",
			["kbhint-protractor"]   = "scroll_rotation",
			["kbhint-rotation"]     = "scroll_rotation",
			["kbhint-intensity"]    = "scroll_intensity",
			["kbhint-size"]         = "scroll_size",
			["kbhint-length"]       = "scroll_length",
			["kbhint-curve"]        = "scroll_curve",
			["kbhint-fp-size"]      = "scroll_size",
			["kbhint-wb-size"]      = "scroll_size",
			["kbhint-wb-length"]    = "scroll_length",
			["kbhint-sp-strength"]  = "scroll_intensity",
			["kbhint-sp-intensity"] = "scroll_intensity",
			["kbhint-sp-size"]      = "scroll_size",
			["kbhint-sp-rotation"]  = "scroll_rotation",
			["kbhint-sp-curve"]     = "scroll_curve",
		}
		for hintId, hintAction in pairs(hintMap) do
			local hintEl = doc:GetElementById(hintId)
			local kb = binds[hintAction]
			if hintEl and kb then
				local p1 = normKey(kb.label)
				local p2 = normKey(kb.label2)
				local keyParts = {}
				if p1 then keyParts[#keyParts+1] = p1 end
				if p2 then keyParts[#keyParts+1] = p2 end
				keyParts[#keyParts+1] = "Scroll"
				hintEl.inner_rml = table.concat(keyParts, "+")
			end
		end
	end
end

-- Initialize badge element references (call once from attachEventListeners)
local function initBadgeElements(doc)
	for btnId, _ in pairs(BADGE_ACTION_MAP) do
		local btn = doc:GetElementById(btnId)
		if btn then
			-- The keybind badge is always the first child div
			local child = btn:GetChild(0)
			if child and child:IsClassSet("tf-keybind-badge") then
				badgeElements[btnId] = child
			end
		end
	end
end

-- Populate keybind list in settings window
local function populateKeybindList(doc)
	local listEl = doc:GetElementById("keybind-list")
	if not listEl then return end
	local binds = widgetState.settingsPendingBinds
	if not binds then return end

	-- Build inner RML
	local parts = {}
	widgetState.settingsKeybindEls = {}

	-- Scroll controls section (editable modifier(s) + fixed "Scroll" badge)
	parts[#parts + 1] = '<div class="tf-keybind-separator"><div class="tf-keybind-sep-line"></div>'
		.. '<div class="tf-keybind-sep-label">Scroll Controls</div>'
		.. '<div class="tf-keybind-sep-line"></div></div>'
	for _, action in ipairs(SCROLL_DISPLAY_ORDER) do
		local kb = binds[action]
		if kb then
			local desc = kb.desc or action
			local lbl1 = kb.label or "?"
			local lbl2 = kb.label2 or ""
			if lbl2 == "" then lbl2 = "-" end
			parts[#parts + 1] = string.format(
				'<div class="tf-keybind-row"><div class="tf-keybind-action">%s</div>'
				.. '<div class="tf-scroll-keys">'
				.. '<div class="tf-keybind-key tf-scroll-mod">%s</div>'
				.. '<div class="tf-scroll-plus">+</div>'
				.. '<div class="tf-keybind-key tf-scroll-mod">%s</div>'
				.. '<div class="tf-scroll-plus">+</div>'
				.. '<div class="tf-scroll-fixed">Scroll</div>'
				.. '</div></div>',
				desc, lbl1, lbl2
			)
		end
	end

	-- Separator before regular keybinds
	parts[#parts + 1] = '<div class="tf-keybind-separator"><div class="tf-keybind-sep-line"></div>'
		.. '<div class="tf-keybind-sep-label">Key Bindings</div>'
		.. '<div class="tf-keybind-sep-line"></div></div>'

	-- Regular keybinds
	for _, action in ipairs(KEYBIND_DISPLAY_ORDER) do
		local kb = binds[action]
		if kb then
			local desc = kb.desc or action
			local label = kb.label or "?"
			parts[#parts + 1] = string.format(
				'<div class="tf-keybind-row"><div class="tf-keybind-action">%s</div>'
				.. '<div class="tf-keybind-key" id="kb-key-%s">%s</div></div>',
				desc, action, label
			)
		end
	end

	-- System Keys separator + fixed ESC entry (non-rebindable)
	parts[#parts + 1] = '<div class="tf-keybind-separator"><div class="tf-keybind-sep-line"></div>'
		.. '<div class="tf-keybind-sep-label">System Keys</div>'
		.. '<div class="tf-keybind-sep-line"></div></div>'
	parts[#parts + 1] = '<div class="tf-keybind-row"><div class="tf-keybind-action">Clear locked sliders</div>'
		.. '<div class="tf-keybind-key-fixed">ESC</div></div>'

	listEl.inner_rml = table.concat(parts) or ""

	-- Attach click listeners by traversing DOM children (GetElementById
	-- does not find elements created via inner_rml in RmlUI).
	local childIdx = 0

	-- Skip first separator (childIdx 0)
	childIdx = 1

	-- Scroll control rows: each row has tf-keybind-action + tf-scroll-keys container
	for _, action in ipairs(SCROLL_DISPLAY_ORDER) do
		local kb = binds[action]
		if kb then
			local row = listEl:GetChild(childIdx)
			if row then
				-- The scroll keys container is child(1) of the row
				local keysContainer = row:GetChild(1)
				if keysContainer then
					-- child(0) = key1 div, child(2) = key2 div (child(1) and (3) are "+" divs)
					local key1El = keysContainer:GetChild(0)
					local key2El = keysContainer:GetChild(2)
					if key1El then
						widgetState.settingsKeybindEls[action] = key1El
						key1El:AddEventListener("click", function(event)
							if widgetState.settingsCapturing and widgetState.settingsCaptureEl then
								widgetState.settingsCaptureEl:SetClass("capturing", false)
							end
							widgetState.settingsCapturing = action
							widgetState.settingsCaptureField = "key"
							widgetState.settingsCaptureEl = key1El
							key1El:SetClass("capturing", true)
							key1El.inner_rml = "..."
							event:StopPropagation()
						end, false)
					end
					if key2El then
						widgetState.settingsKeybindEls[action .. ":key2"] = key2El
						key2El:AddEventListener("click", function(event)
							if widgetState.settingsCapturing and widgetState.settingsCaptureEl then
								widgetState.settingsCaptureEl:SetClass("capturing", false)
							end
							widgetState.settingsCapturing = action
							widgetState.settingsCaptureField = "key2"
							widgetState.settingsCaptureEl = key2El
							key2El:SetClass("capturing", true)
							key2El.inner_rml = "..."
							event:StopPropagation()
						end, false)
					end
				end
			end
			childIdx = childIdx + 1
		end
	end

	-- Skip second separator
	childIdx = childIdx + 1

	-- Regular keybind rows
	for _, action in ipairs(KEYBIND_DISPLAY_ORDER) do
		local kb = binds[action]
		if kb then
			local row = listEl:GetChild(childIdx)
			if row then
				local keyEl = row:GetChild(1)  -- second child is the key div
				if keyEl then
					widgetState.settingsKeybindEls[action] = keyEl
					keyEl:AddEventListener("click", function(event)
						if widgetState.settingsCapturing and widgetState.settingsCaptureEl then
							widgetState.settingsCaptureEl:SetClass("capturing", false)
						end
						widgetState.settingsCapturing = action
						widgetState.settingsCaptureField = "key"
						widgetState.settingsCaptureEl = keyEl
						keyEl:SetClass("capturing", true)
						keyEl.inner_rml = "Press key..."
						event:StopPropagation()
					end, false)
				end
			end
			childIdx = childIdx + 1
		end
	end
end

-- Handle captured key in settings window. Called from widget:KeyPress forwarding.
local function handleSettingsKeyCapture(keyCode)
	local action = widgetState.settingsCapturing
	if not action then return false end
	local keyEl = widgetState.settingsCaptureEl
	local field = widgetState.settingsCaptureField or "key"
	if not keyEl then
		widgetState.settingsCapturing = nil
		widgetState.settingsCaptureField = nil
		widgetState.settingsCaptureEl = nil
		return false
	end

	-- Escape cancels capture
	if keyCode == 0x1B then -- ESCAPE
		local kb = widgetState.settingsPendingBinds and widgetState.settingsPendingBinds[action]
		if kb then
			if field == "key2" then
				local lbl = kb.label2 or ""
				keyEl.inner_rml = (lbl ~= "" and lbl) or "-"
			else
				keyEl.inner_rml = kb.label or "?"
			end
		else
			keyEl.inner_rml = "?"
		end
		keyEl:SetClass("capturing", false)
		widgetState.settingsCapturing = nil
		widgetState.settingsCaptureField = nil
		widgetState.settingsCaptureEl = nil
		return true
	end

	-- Delete/Backspace clears key2 slot for scroll controls
	if field == "key2" and (keyCode == 0x7F or keyCode == 0x08) then
		if widgetState.settingsPendingBinds and widgetState.settingsPendingBinds[action] then
			widgetState.settingsPendingBinds[action].key2 = 0
			widgetState.settingsPendingBinds[action].label2 = ""
		end
		keyEl.inner_rml = "-"
		keyEl:SetClass("capturing", false)
		keyEl:SetClass("modified", true)
		widgetState.settingsCapturing = nil
		widgetState.settingsCaptureField = nil
		widgetState.settingsCaptureEl = nil
		return true
	end

	-- Assign the new key
	local label = keyCodeToLabel(keyCode)
	if widgetState.settingsPendingBinds and widgetState.settingsPendingBinds[action] then
		if field == "key2" then
			widgetState.settingsPendingBinds[action].key2 = keyCode
			widgetState.settingsPendingBinds[action].label2 = label
		else
			widgetState.settingsPendingBinds[action].key = keyCode
			widgetState.settingsPendingBinds[action].label = label
		end
	end
	keyEl.inner_rml = label
	keyEl:SetClass("capturing", false)
	keyEl:SetClass("modified", true)
	widgetState.settingsCapturing = nil
	widgetState.settingsCaptureField = nil
	widgetState.settingsCaptureEl = nil
	return true
end

-- Handle tool-switching key press. Matches key against tool keybinds and clicks
-- the corresponding button. Called from cmd_terraform_brush KeyPress forwarding.
local function handleToolKey(keyCode)
	if not keyCode or keyCode == 0 then return false end
	if not WG.TerraformBrush or not WG.TerraformBrush.getKeybinds then return false end
	local binds = WG.TerraformBrush.getKeybinds()
	for action, btnId in pairs(TOOL_BTN_MAP) do
		local kb = binds[action]
		if kb and kb.key == keyCode then
			local doc = widgetState.document
			if doc then
				local btn = doc:GetElementById(btnId)
				if btn then
					btn:Click()
					return true
				end
			end
		end
	end
	return false
end

-- attachGuideMode moved to tf_guide.lua


-- attachEnvironmentListeners moved to tf_environment.lua


-- Wire up the static numbox text inputs next to every range slider.
-- Each slider with id="foo" has a sibling <input type="text" id="foo-numbox">.
-- The numbox shows the raw slider value; typing a number and pressing Enter or
-- clicking away updates the slider (and triggers its existing change handlers).

-- Resolve the RETURN key identifier lazily (RmlUi.key_identifier is a
-- readonly_property that creates a fresh table each access).
local KEY_RETURN  -- resolved on first keydown event

-- Wire a single slider+numbox pair by slider element and its numbox element.
local function wireSliderNumbox(slider, numbox)
	-- Set initial value from slider
	local initVal = tostring(slider:GetAttribute("value") or 0)
	numbox:SetAttribute("value", initVal)

	-- Slider -> numbox sync: update text whenever the slider moves
	slider:AddEventListener("change", function()
		local v = tostring(slider:GetAttribute("value") or 0)
		numbox:SetAttribute("value", v)
	end, false)

	-- Numbox -> slider sync helper
	local function applyNumboxValue()
		local raw = numbox:GetAttribute("value")
		local val = tonumber(raw)
		if not val then return end
		local smin = tonumber(slider:GetAttribute("min")) or 0
		local smax = tonumber(slider:GetAttribute("max")) or 1000
		local step = tonumber(slider:GetAttribute("step")) or 1
		val = math.max(smin, math.min(smax, val))
		if step > 0 then
			val = math.floor((val - smin) / step + 0.5) * step + smin
			val = math.max(smin, math.min(smax, val))
		end
		local valStr = tostring(val)
		slider:SetAttribute("value", valStr)
		numbox:SetAttribute("value", valStr)
	end

	-- Apply on focus lost
	numbox:AddEventListener("blur", function(event)
		applyNumboxValue()
		Spring.SDLStopTextInput()
		widgetState.focusedRmlInput = nil
		event:StopPropagation()
	end, false)

	-- Enable text input while focused
	numbox:AddEventListener("focus", function(event)
		Spring.SDLStartTextInput()
		widgetState.focusedRmlInput = numbox
	end, false)

	-- Apply on Enter key
	numbox:AddEventListener("keydown", function(event)
		if not KEY_RETURN then
			pcall(function() KEY_RETURN = RmlUi.key_identifier.RETURN end)
		end
		local p = event.parameters
		if p and KEY_RETURN and p.key_identifier == KEY_RETURN then
			applyNumboxValue()
			numbox:Blur()
		end
	end, false)
end

-- Find and wire all slider+numbox pairs by looking up numbox elements by class,
-- then deriving the slider ID by stripping the "-numbox" suffix.
local function attachSliderInputBoxes(doc)
	local numboxes = doc:GetElementsByClassName("tf-slider-numbox")
	if not numboxes then return end

	-- Iterate safely: try pairs (works for both tables and userdata with __pairs)
	local ok, err = pcall(function()
		for _, numbox in pairs(numboxes) do
			local numboxId = numbox.id or ""
			local sliderId = numboxId:match("^(.+)-numbox$")
			if sliderId then
				local slider = doc:GetElementById(sliderId)
				if slider then
					wireSliderNumbox(slider, numbox)
				end
			end
		end
	end)
	if not ok then
		Spring.Echo("[TF Brush] attachSliderInputBoxes error: " .. tostring(err))
	end
end

-- attachStartPosListeners moved to tf_startpos.lua


-- attachCloneToolListeners moved to tf_clone.lua


-- Transport listener registration extracted to avoid upvalue limit in attachEventListeners
widgetState.regTransports = function(doc)
	local TIDS = {
		"slider-rotation","slider-intensity","slider-restore-strength","slider-size",
		"slider-ring-width","slider-length","slider-curve","slider-cap-max","slider-cap-min",
		"slider-sp-allyteams","slider-sp-count",
		"slider-mb-size","slider-mb-rotation","slider-mb-length","slider-mb-curve",
		"slider-gb-size","slider-gb-length","slider-gb-rotation","slider-gb-curve",
		"slider-gb-slope-max","slider-gb-slope-min","slider-gb-alt-min","slider-gb-alt-max",
		"fp-slider-size","fp-slider-rotation","fp-slider-rot-random",
		"fp-slider-count","fp-slider-cadence",
		"fp-slider-slope-max","fp-slider-slope-min","fp-slider-alt-min","fp-slider-alt-max",
		"wb-slider-size","wb-slider-rotation","wb-slider-length","wb-slider-count",
		"wb-slider-cadence","wb-slider-frequency","wb-slider-persist",
		"sp-slider-strength","sp-slider-intensity","sp-slider-size","sp-slider-rotation",
		"sp-slider-curve","sp-slider-slope-max","sp-slider-slope-min",
		"sp-slider-alt-min","sp-slider-alt-max",
	}
	local function updateTransportBtns(t)
		local active = t.dir ~= 0 and not t.paused
		t.backEl:SetClass("active", active and t.dir < 0)
		t.fwdEl:SetClass("active",  active and t.dir > 0)
		if active then
			t.playEl.inner_rml = '<img class="tf-icon-xs" src="/luaui/images/terraform_brush/passthrough_pause.png" />'
			t.playEl:SetClass("active", true)
		else
			t.playEl.inner_rml = '<img class="tf-icon-xs" src="/luaui/images/terraform_brush/passthrough_play.png" />'
			t.playEl:SetClass("active", false)
		end
		if t.groupEl then
			local show = t.toggleVisible or (t.dir ~= 0)
			t.groupEl:SetClass("hidden", not show)
			if t.toggleEl then t.toggleEl:SetClass("active", show) end
		end
	end
	widgetState.updateTransportBtns = updateTransportBtns
	for _, sid in ipairs(TIDS) do
		local slEl = doc:GetElementById(sid)
		if slEl then
			local bEl   = doc:GetElementById(sid .. "-back")
			local pEl   = doc:GetElementById(sid .. "-play")
			local fEl   = doc:GetElementById(sid .. "-fwd")
			if bEl and pEl and fEl then
				local ts = { el=slEl, dir=0, speed=0, paused=false, accum=0,
				             backEl=bEl, playEl=pEl, fwdEl=fEl,
				             wrap = (sid:find("rotation") ~= nil),
				             toggleEl=doc:GetElementById(sid .. "-transport-toggle"),
				             groupEl=doc:GetElementById(sid .. "-transport"),
				             toggleVisible=false }
				widgetState.transports[sid] = ts
				if ts.toggleEl then
					ts.toggleEl:AddEventListener("click", function(ev)
						local t = widgetState.transports[sid]
						if t then
							t.toggleVisible = not t.toggleVisible
							if not t.toggleVisible then
								t.dir = 0; t.speed = 0; t.paused = false
							end
							updateTransportBtns(t)
						end
						ev:StopPropagation()
					end, false)
				end
				bEl:AddEventListener("click", function(ev)
					local t = widgetState.transports[sid]
					if t then
						if t.dir == -1 then t.speed = math.min(4, t.speed + 1)
						else t.dir = -1; t.speed = 1 end
						t.paused = false; updateTransportBtns(t)
					end
					ev:StopPropagation()
				end, false)
				bEl:AddEventListener("contextmenu", function(ev)
					local t = widgetState.transports[sid]
					if t then
						t.speed = math.max(0, t.speed - 1)
						if t.speed == 0 then t.dir = 0; t.paused = false end
						updateTransportBtns(t)
					end
					ev:StopPropagation()
				end, false)
				pEl:AddEventListener("click", function(ev)
					local t = widgetState.transports[sid]
					if t then
						if t.dir == 0 then t.dir = 1; t.speed = 1; t.paused = false
						else t.paused = not t.paused end
						updateTransportBtns(t)
					end
					ev:StopPropagation()
				end, false)
				fEl:AddEventListener("click", function(ev)
					local t = widgetState.transports[sid]
					if t then
						if t.dir == 1 then t.speed = math.min(4, t.speed + 1)
						else t.dir = 1; t.speed = 1 end
						t.paused = false; updateTransportBtns(t)
					end
					ev:StopPropagation()
				end, false)
				fEl:AddEventListener("contextmenu", function(ev)
					local t = widgetState.transports[sid]
					if t then
						t.speed = math.max(0, t.speed - 1)
						if t.speed == 0 then t.dir = 0; t.paused = false end
						updateTransportBtns(t)
					end
					ev:StopPropagation()
				end, false)
end
		end
	end
end

-- ============ Load extracted tool modules ============
local tfMetal = VFS.Include("luaui/RmlWidgets/gui_terraform_brush/tf_metal.lua")
local tfGrass = VFS.Include("luaui/RmlWidgets/gui_terraform_brush/tf_grass.lua")
local tfFeatures = VFS.Include("luaui/RmlWidgets/gui_terraform_brush/tf_features.lua")
local tfWeather = VFS.Include("luaui/RmlWidgets/gui_terraform_brush/tf_weather.lua")
local tfDecals = VFS.Include("luaui/RmlWidgets/gui_terraform_brush/tf_decals.lua")
local tfLights = VFS.Include("luaui/RmlWidgets/gui_terraform_brush/tf_lights.lua")
local tfNoise = VFS.Include("luaui/RmlWidgets/gui_terraform_brush/tf_noise.lua")
local tfStartPos = VFS.Include("luaui/RmlWidgets/gui_terraform_brush/tf_startpos.lua")
local tfClone = VFS.Include("luaui/RmlWidgets/gui_terraform_brush/tf_clone.lua")
local tfSplat = VFS.Include("luaui/RmlWidgets/gui_terraform_brush/tf_splat.lua")
local tfEnvironment = VFS.Include("luaui/RmlWidgets/gui_terraform_brush/tf_environment.lua")
local tfGuide = VFS.Include("luaui/RmlWidgets/gui_terraform_brush/tf_guide.lua")

-- Shared context passed to all extracted tool modules
local ctx = {
	uiState = uiState,
	widgetState = widgetState,
	playSound = playSound,
	setActiveClass = setActiveClass,
	trackSliderDrag = trackSliderDrag,
	syncAndFlash = syncAndFlash,
	clearPassthrough = clearPassthrough,
	WG = WG,
	-- Constants
	ROTATION_STEP = ROTATION_STEP,
	CURVE_STEP = CURVE_STEP,
	LENGTH_SCALE_STEP = LENGTH_SCALE_STEP,
	RADIUS_STEP = RADIUS_STEP,
	HEIGHT_CAP_STEP = HEIGHT_CAP_STEP,
	HEIGHT_STEP = HEIGHT_STEP,
	DEFAULT_MAX_INTENSITY = DEFAULT_MAX_INTENSITY,
	-- Slider converters
	sliderToIntensity = sliderToIntensity,
	intensityToSlider = intensityToSlider,
	sliderToCadence = sliderToCadence,
	cadenceToSlider = cadenceToSlider,
	sliderToFrequency = sliderToFrequency,
	frequencyToSlider = frequencyToSlider,
	sliderToPersist = sliderToPersist,
	persistToSlider = persistToSlider,
	formatFrequency = formatFrequency,
	shapeNames = shapeNames,
	guideHints = guideHints,
	PERSIST_PERMANENT_VAL = PERSIST_PERMANENT_VAL,
	-- Environment module extras
	skyDynamic = skyDynamic,
	quatFromAxisAngle = quatFromAxisAngle,
	-- Guide module extras
	populateKeybindList = populateKeybindList,
	updateAllKeybindBadges = updateAllKeybindBadges,
	g3ElemGroup = g3ElemGroup,
	g3TipGroups = g3TipGroups,
}

local function attachEventListeners()
	local doc = widgetState.document
	if not doc then
		return
	end

	-- Safety net: clear drag state if mouseup happens anywhere on document
	doc:AddEventListener("mouseup", function() uiState.draggingSlider = nil end, false)

	widgetState.modeButtons.raise = doc:GetElementById("btn-raise")
	widgetState.modeButtons.lower = doc:GetElementById("btn-lower")
	widgetState.modeButtons.smooth = doc:GetElementById("btn-level")
	widgetState.modeButtons.ramp = doc:GetElementById("btn-ramp")
	widgetState.modeButtons.restore = doc:GetElementById("btn-restore")
	widgetState.modeButtons.noise = doc:GetElementById("btn-noise")

	-- Smooth/Level submode buttons (child of primary SMOOTH button)
	widgetState.smoothSubModeButtons = {
		smooth = doc:GetElementById("btn-smooth-sub-smooth"),
		level  = doc:GetElementById("btn-smooth-sub-level"),
	}
	for subMode, subEl in pairs(widgetState.smoothSubModeButtons) do
		if subEl then
			local target = subMode
			subEl:AddEventListener("click", function(ev)
				playSound("modeSwitch")
				if WG.TerraformBrush then WG.TerraformBrush.setMode(target) end
				ev:StopPropagation()
			end, false)
		end
	end

	widgetState.shapeButtons.circle = doc:GetElementById("btn-circle")
	widgetState.shapeButtons.square = doc:GetElementById("btn-square")
	widgetState.shapeButtons.hexagon = doc:GetElementById("btn-hexagon")
	widgetState.shapeButtons.octagon = doc:GetElementById("btn-octagon")
	widgetState.shapeButtons.triangle = doc:GetElementById("btn-triangle")
	widgetState.shapeButtons.ring = doc:GetElementById("btn-ring")
	widgetState.shapeButtons.fill = doc:GetElementById("btn-fill")

	widgetState.rampTypeButtons.straight = doc:GetElementById("btn-ramp-straight")
	widgetState.rampTypeButtons.spline   = doc:GetElementById("btn-ramp-spline")

	for mode, element in pairs(widgetState.modeButtons) do
		if element then
			element:AddEventListener("click", onModeClick(mode), false)
		end
	end

	-- Feature Placer launch button
	local featuresBtn = doc:GetElementById("btn-features")
	if featuresBtn then
		featuresBtn:AddEventListener("click", function(event)
			playSound("toolSwitch")
			clearPassthrough()
			if WG.FeaturePlacer then
				-- Deactivate terraform brush and activate feature placer
				if WG.TerraformBrush then
					WG.TerraformBrush.deactivate()
				end
				if WG.WeatherBrush then
					WG.WeatherBrush.deactivate()
				end
				if WG.SplatPainter then
					WG.SplatPainter.deactivate()
				end
				if WG.MetalBrush then
					WG.MetalBrush.deactivate()
				end
				if WG.GrassBrush then
					WG.GrassBrush.deactivate()
				end
				widgetState.envActive = false
				widgetState.lightActive = false
				if WG.LightPlacer then WG.LightPlacer.deactivate() end
				widgetState.startposActive = false
				if WG.StartPosTool then WG.StartPosTool.deactivate() end
				widgetState.cloneActive = false
				if WG.CloneTool then WG.CloneTool.deactivate() end
				WG.FeaturePlacer.setMode("scatter")
			end
			event:StopPropagation()
		end, false)
	end

	-- Weather Brush launch button
	local weatherBtn = doc:GetElementById("btn-weather")
	if weatherBtn then
		weatherBtn:AddEventListener("click", function(event)
			playSound("toolSwitch")
			clearPassthrough()
			if WG.WeatherBrush then
				if WG.TerraformBrush then
					WG.TerraformBrush.deactivate()
				end
				if WG.FeaturePlacer then
					WG.FeaturePlacer.deactivate()
				end
				if WG.SplatPainter then
					WG.SplatPainter.deactivate()
				end
				if WG.MetalBrush then
					WG.MetalBrush.deactivate()
				end
				if WG.GrassBrush then
					WG.GrassBrush.deactivate()
				end
				widgetState.envActive = false
				widgetState.lightActive = false
				if WG.LightPlacer then WG.LightPlacer.deactivate() end
				widgetState.startposActive = false
				if WG.StartPosTool then WG.StartPosTool.deactivate() end
				widgetState.cloneActive = false
				if WG.CloneTool then WG.CloneTool.deactivate() end
				WG.WeatherBrush.activate("scatter")
			end
			event:StopPropagation()
		end, false)
	end

	-- Environment tool button
	local envBtn = doc:GetElementById("btn-environment")
	if envBtn then
		envBtn:AddEventListener("click", function(event)
			playSound("toolSwitch")
			clearPassthrough()
			local ok2, err2 = pcall(function()
				if widgetState.envActive then
					-- Toggling OFF: return to terraform brush
					widgetState.envActive = false
					if WG.TerraformBrush then
						local st = WG.TerraformBrush.getState()
						WG.TerraformBrush.setMode(st and st.mode or "raise")
					end
				else
					-- Toggling ON: deactivate all other tools
					if WG.TerraformBrush then WG.TerraformBrush.deactivate() end
					if WG.FeaturePlacer then WG.FeaturePlacer.deactivate() end
					if WG.WeatherBrush then WG.WeatherBrush.deactivate() end
					if WG.SplatPainter then WG.SplatPainter.deactivate() end
					if WG.MetalBrush then WG.MetalBrush.deactivate() end
					if WG.GrassBrush then WG.GrassBrush.deactivate() end
					widgetState.lightActive = false
					if WG.LightPlacer then WG.LightPlacer.deactivate() end
					widgetState.startposActive = false
					if WG.StartPosTool then WG.StartPosTool.deactivate() end
					widgetState.cloneActive = false
					if WG.CloneTool then WG.CloneTool.deactivate() end
					widgetState.decalsActive = false
					if WG.DecalPlacer then WG.DecalPlacer.deactivate() end
					widgetState.envActive = true
				end
			end)
			if not ok2 then
				Spring.Echo("[Terraform Brush UI] ERROR in envBtn click: " .. tostring(err2))
			end
			event:StopPropagation()
		end, false)
	end

	-- Light Placer launch button
	local lightsBtn = doc:GetElementById("btn-lights")
	if lightsBtn then
		lightsBtn:AddEventListener("click", function(event)
			playSound("toolSwitch")
			clearPassthrough()
			local ok2, err2 = pcall(function()
				if widgetState.lightActive then
					-- Toggling OFF: return to terraform brush
					widgetState.lightActive = false
					if WG.LightPlacer then WG.LightPlacer.deactivate() end
					if WG.TerraformBrush then
						local st = WG.TerraformBrush.getState()
						WG.TerraformBrush.setMode(st and st.mode or "raise")
					end
				else
					-- Toggling ON: deactivate all other tools
					if WG.TerraformBrush then WG.TerraformBrush.deactivate() end
					if WG.FeaturePlacer then WG.FeaturePlacer.deactivate() end
					if WG.WeatherBrush then WG.WeatherBrush.deactivate() end
					if WG.SplatPainter then WG.SplatPainter.deactivate() end
					if WG.MetalBrush then WG.MetalBrush.deactivate() end
					if WG.GrassBrush then WG.GrassBrush.deactivate() end
					widgetState.envActive = false
					widgetState.startposActive = false
					if WG.StartPosTool then WG.StartPosTool.deactivate() end
					widgetState.cloneActive = false
					if WG.CloneTool then WG.CloneTool.deactivate() end
					widgetState.decalsActive = false
					if WG.DecalPlacer then WG.DecalPlacer.deactivate() end
					widgetState.lightActive = true
					if WG.LightPlacer then WG.LightPlacer.setMode("point") end
				end
			end)
			if not ok2 then
				Spring.Echo("[Terraform Brush UI] ERROR in lightsBtn click: " .. tostring(err2))
			end
			event:StopPropagation()
		end, false)
	end

	-- Start Positions Tool launch button
	local startposBtn = doc:GetElementById("btn-startpos")
	if startposBtn then
		startposBtn:AddEventListener("click", function(event)
			playSound("toolSwitch")
			clearPassthrough()
			local ok2, err2 = pcall(function()
				if widgetState.startposActive then
					-- Toggling OFF: return to terraform brush
					widgetState.startposActive = false
					if WG.StartPosTool then WG.StartPosTool.deactivate() end
					widgetState.cloneActive = false
					if WG.CloneTool then WG.CloneTool.deactivate() end
					if WG.TerraformBrush then
						local st = WG.TerraformBrush.getState()
						WG.TerraformBrush.setMode(st and st.mode or "raise")
					end
				else
					-- Toggling ON: deactivate all other tools
					if WG.TerraformBrush then WG.TerraformBrush.deactivate() end
					if WG.FeaturePlacer then WG.FeaturePlacer.deactivate() end
					if WG.WeatherBrush then WG.WeatherBrush.deactivate() end
					if WG.SplatPainter then WG.SplatPainter.deactivate() end
					if WG.MetalBrush then WG.MetalBrush.deactivate() end
					if WG.GrassBrush then WG.GrassBrush.deactivate() end
					widgetState.envActive = false
					widgetState.lightActive = false
					if WG.LightPlacer then WG.LightPlacer.deactivate() end
					widgetState.cloneActive = false
					if WG.CloneTool then WG.CloneTool.deactivate() end
					widgetState.decalsActive = false
					if WG.DecalPlacer then WG.DecalPlacer.deactivate() end
					widgetState.startposActive = true
					if WG.StartPosTool then WG.StartPosTool.activate("express") end
				end
			end)
			if not ok2 then
				Spring.Echo("[Terraform Brush UI] ERROR in startposBtn click: " .. tostring(err2))
			end
			event:StopPropagation()
		end, false)
	end

	-- Splat Painter launch button
	local splatBtn = doc:GetElementById("btn-splat")
	if splatBtn then
		splatBtn:AddEventListener("click", function(event)
			playSound("toolSwitch")
			clearPassthrough()
			if WG.SplatPainter then
				if WG.TerraformBrush then
					WG.TerraformBrush.deactivate()
				end
				if WG.FeaturePlacer then
					WG.FeaturePlacer.deactivate()
				end
				if WG.WeatherBrush then
					WG.WeatherBrush.deactivate()
				end
				if WG.MetalBrush then
					WG.MetalBrush.deactivate()
				end
				if WG.GrassBrush then
					WG.GrassBrush.deactivate()
				end
				widgetState.envActive = false
				widgetState.lightActive = false
				if WG.LightPlacer then WG.LightPlacer.deactivate() end
				widgetState.startposActive = false
				if WG.StartPosTool then WG.StartPosTool.deactivate() end
				widgetState.cloneActive = false
				if WG.CloneTool then WG.CloneTool.deactivate() end
				widgetState.decalsActive = false
				if WG.DecalPlacer then WG.DecalPlacer.deactivate() end
				WG.SplatPainter.activate()
				local clayBtn = doc:GetElementById("btn-clay-mode")
				if clayBtn then
					clayBtn:SetClass("unavailable", true)
				end
			end
			event:StopPropagation()
		end, false)
	end

	for shape, element in pairs(widgetState.shapeButtons) do
		if element then
			element:AddEventListener("click", onShapeClick(shape), false)
		end
	end

	if widgetState.rampTypeButtons.straight then
		widgetState.rampTypeButtons.straight:AddEventListener("click", function(event)
			playSound("tick")
			if WG.TerraformBrush then WG.TerraformBrush.setShape("square") end
			event:StopPropagation()
		end, false)
	end
	if widgetState.rampTypeButtons.spline then
		widgetState.rampTypeButtons.spline:AddEventListener("click", function(event)
			playSound("tick")
			if WG.TerraformBrush then WG.TerraformBrush.setShape("circle") end
			event:StopPropagation()
		end, false)
	end

	local undoBtn = doc:GetElementById("btn-undo")
	if undoBtn then
		undoBtn:AddEventListener("click", function(event)
			playSound("undo")
			if WG.TerraformBrush then
				WG.TerraformBrush.undo()
			end
			event:StopPropagation()
		end, false)
	end

	local redoBtn = doc:GetElementById("btn-redo")
	if redoBtn then
		redoBtn:AddEventListener("click", function(event)
			playSound("undo")
			if WG.TerraformBrush then
				WG.TerraformBrush.redo()
			end
			event:StopPropagation()
		end, false)
	end

	local sliderHistory = doc:GetElementById("slider-history")
	if sliderHistory then
		trackSliderDrag(sliderHistory, "history")
		sliderHistory:AddEventListener("change", function(event)
			if uiState.updatingFromCode then event:StopPropagation(); return end
			if not WG.TerraformBrush then event:StopPropagation(); return end
			local val = tonumber(sliderHistory:GetAttribute("value")) or 0
			local state = WG.TerraformBrush.getState()
			if not state then event:StopPropagation(); return end
			local currentUndoCount = state.undoCount or 0
			local diff = val - currentUndoCount
			if diff > 0 then
				for i = 1, diff do
					WG.TerraformBrush.redo()
				end
			elseif diff < 0 then
				for i = 1, -diff do
					WG.TerraformBrush.undo()
				end
			end
			event:StopPropagation()
		end, false)
	end

	-- Metal undo/redo (per-tool undo via metal gadget)
	local mbUndoBtn = doc:GetElementById("btn-mb-undo")
	if mbUndoBtn then
		mbUndoBtn:AddEventListener("click", function(event)
			playSound("undo")
			if WG.MetalBrush and WG.MetalBrush.undo then WG.MetalBrush.undo() end
			event:StopPropagation()
		end, false)
	end

	local mbRedoBtn = doc:GetElementById("btn-mb-redo")
	if mbRedoBtn then
		mbRedoBtn:AddEventListener("click", function(event)
			playSound("undo")
			if WG.MetalBrush and WG.MetalBrush.redo then WG.MetalBrush.redo() end
			event:StopPropagation()
		end, false)
	end

	local mbSliderHistory = doc:GetElementById("slider-mb-history")
	if mbSliderHistory then
		trackSliderDrag(mbSliderHistory, "mb-history")
		mbSliderHistory:AddEventListener("change", function(event)
			if uiState.updatingFromCode then event:StopPropagation(); return end
			if not WG.TerraformBrush then event:StopPropagation(); return end
			local val = tonumber(mbSliderHistory:GetAttribute("value")) or 0
			local state = WG.TerraformBrush.getState()
			if not state then event:StopPropagation(); return end
			local currentUndoCount = state.undoCount or 0
			local diff = val - currentUndoCount
			if diff > 0 then
				for i = 1, diff do WG.TerraformBrush.redo() end
			elseif diff < 0 then
				for i = 1, -diff do WG.TerraformBrush.undo() end
			end
			event:StopPropagation()
		end, false)
	end

	local rotCW = doc:GetElementById("btn-rot-cw")
	local rotCCW = doc:GetElementById("btn-rot-ccw")

	if rotCW then
		rotCW:AddEventListener("click", onRotateCW, false)
	end

	if rotCCW then
		rotCCW:AddEventListener("click", onRotateCCW, false)
	end

	local sliderRotation = doc:GetElementById("slider-rotation")
	if sliderRotation then
		trackSliderDrag(sliderRotation, "rotation")
		sliderRotation:AddEventListener("change", function(event)
			if not uiState.updatingFromCode and WG.TerraformBrush then
				local val = tonumber(sliderRotation:GetAttribute("value")) or 0
				WG.TerraformBrush.setRotation(val)
			end
			event:StopPropagation()
		end, false)
	end

	local curveUpBtn = doc:GetElementById("btn-curve-up")
	local curveDownBtn = doc:GetElementById("btn-curve-down")

	if curveUpBtn then
		curveUpBtn:AddEventListener("click", onCurveUp, false)
	end

	if curveDownBtn then
		curveDownBtn:AddEventListener("click", onCurveDown, false)
	end

	local intensityUpBtn = doc:GetElementById("btn-intensity-up")
	local intensityDownBtn = doc:GetElementById("btn-intensity-down")

	if intensityUpBtn then
		intensityUpBtn:AddEventListener("click", onIntensityUp, false)
	end

	if intensityDownBtn then
		intensityDownBtn:AddEventListener("click", onIntensityDown, false)
	end

	local sliderCurve = doc:GetElementById("slider-curve")
	if sliderCurve then
		trackSliderDrag(sliderCurve, "curve")
		sliderCurve:AddEventListener("change", function(event)
			if not uiState.updatingFromCode and WG.TerraformBrush then
				local val = tonumber(sliderCurve:GetAttribute("value")) or 10
				WG.TerraformBrush.setCurve(val / 10)
			end
			event:StopPropagation()
		end, false)
	end

	local sliderIntensity = doc:GetElementById("slider-intensity")
	if sliderIntensity then
		trackSliderDrag(sliderIntensity, "intensity")
		sliderIntensity:AddEventListener("change", function(event)
			if not uiState.updatingFromCode and WG.TerraformBrush then
				local val = tonumber(sliderIntensity:GetAttribute("value")) or 0
				WG.TerraformBrush.setIntensity(sliderToIntensity(val))
			end
			event:StopPropagation()
		end, false)
	end

	local sliderRestoreStrength = doc:GetElementById("slider-restore-strength")
	local restoreStrengthLabel = doc:GetElementById("restore-strength-label")
	if sliderRestoreStrength then
		trackSliderDrag(sliderRestoreStrength, "restoreStrength")
		sliderRestoreStrength:AddEventListener("change", function(event)
			if not uiState.updatingFromCode and WG.TerraformBrush then
				local val = tonumber(sliderRestoreStrength:GetAttribute("value")) or 100
				WG.TerraformBrush.setRestoreStrength(val / 100)
				if restoreStrengthLabel then
					restoreStrengthLabel.inner_rml = tostring(val) .. "%"
				end
			end
			event:StopPropagation()
		end, false)
	end

	local restoreStrengthUpBtn = doc:GetElementById("btn-restore-strength-up")
	if restoreStrengthUpBtn then
		restoreStrengthUpBtn:AddEventListener("click", function(event)
			if WG.TerraformBrush then
				local state = WG.TerraformBrush.getState()
				local newVal = math.min(1.0, (state.restoreStrength or 1.0) + 0.05)
				WG.TerraformBrush.setRestoreStrength(newVal)
			end
			event:StopPropagation()
		end, false)
	end

	local restoreStrengthDownBtn = doc:GetElementById("btn-restore-strength-down")
	if restoreStrengthDownBtn then
		restoreStrengthDownBtn:AddEventListener("click", function(event)
			if WG.TerraformBrush then
				local state = WG.TerraformBrush.getState()
				local newVal = math.max(0.0, (state.restoreStrength or 1.0) - 0.05)
				WG.TerraformBrush.setRestoreStrength(newVal)
			end
			event:StopPropagation()
		end, false)
	end

	local sliderLength = doc:GetElementById("slider-length")
	if sliderLength then
		trackSliderDrag(sliderLength, "length")
		sliderLength:AddEventListener("change", function(event)
			if not uiState.updatingFromCode and WG.TerraformBrush then
				local val = tonumber(sliderLength:GetAttribute("value")) or 20
				WG.TerraformBrush.setLengthScale(val / 10)
			end
			event:StopPropagation()
		end, false)
	end

	local lengthUpBtn = doc:GetElementById("btn-length-up")
	if lengthUpBtn then
		lengthUpBtn:AddEventListener("click", function(event)
			if WG.TerraformBrush then
				local state = WG.TerraformBrush.getState()
				WG.TerraformBrush.setLengthScale(state.lengthScale + LENGTH_SCALE_STEP)
			end
			event:StopPropagation()
		end, false)
	end

	local lengthDownBtn = doc:GetElementById("btn-length-down")
	if lengthDownBtn then
		lengthDownBtn:AddEventListener("click", function(event)
			if WG.TerraformBrush then
				local state = WG.TerraformBrush.getState()
				WG.TerraformBrush.setLengthScale(state.lengthScale - LENGTH_SCALE_STEP)
			end
			event:StopPropagation()
		end, false)
	end

	local sliderSize = doc:GetElementById("slider-size")
	if sliderSize then
		trackSliderDrag(sliderSize, "size")
		sliderSize:AddEventListener("change", function(event)
			if not uiState.updatingFromCode and WG.TerraformBrush then
				local val = tonumber(sliderSize:GetAttribute("value")) or 100
				WG.TerraformBrush.setRadius(val)
			end
			event:StopPropagation()
		end, false)
	end

	local sizeUpBtn = doc:GetElementById("btn-size-up")
	if sizeUpBtn then
		sizeUpBtn:AddEventListener("click", function(event)
			if WG.TerraformBrush then
				local state = WG.TerraformBrush.getState()
				WG.TerraformBrush.setRadius(state.radius + RADIUS_STEP)
			end
			event:StopPropagation()
		end, false)
	end

	local sizeDownBtn = doc:GetElementById("btn-size-down")
	if sizeDownBtn then
		sizeDownBtn:AddEventListener("click", function(event)
			if WG.TerraformBrush then
				local state = WG.TerraformBrush.getState()
				WG.TerraformBrush.setRadius(state.radius - RADIUS_STEP)
			end
			event:StopPropagation()
		end, false)
	end

	local sliderRingWidth = doc:GetElementById("slider-ring-width")
	if sliderRingWidth then
		trackSliderDrag(sliderRingWidth, "ring-width")
		sliderRingWidth:AddEventListener("change", function(event)
			if not uiState.updatingFromCode and WG.TerraformBrush then
				local val = tonumber(sliderRingWidth:GetAttribute("value")) or 40
				ringWidthPct = val
				local lbl = doc:GetElementById("ring-width-label")
				if lbl then lbl.inner_rml = tostring(val) .. "%" end
				WG.TerraformBrush.setRingInnerRatio(1 - val / 100)
			end
			event:StopPropagation()
		end, false)
	end

	local ringWidthUpBtn = doc:GetElementById("btn-ring-width-up")
	if ringWidthUpBtn then
		ringWidthUpBtn:AddEventListener("click", function(event)
			if WG.TerraformBrush then
				ringWidthPct = math.min(95, ringWidthPct + 5)
				local sl = doc:GetElementById("slider-ring-width")
				if sl then sl:SetAttribute("value", tostring(ringWidthPct)) end
				local lbl = doc:GetElementById("ring-width-label")
				if lbl then lbl.inner_rml = tostring(ringWidthPct) .. "%" end
				WG.TerraformBrush.setRingInnerRatio(1 - ringWidthPct / 100)
			end
			event:StopPropagation()
		end, false)
	end

	local ringWidthDownBtn = doc:GetElementById("btn-ring-width-down")
	if ringWidthDownBtn then
		ringWidthDownBtn:AddEventListener("click", function(event)
			if WG.TerraformBrush then
				ringWidthPct = math.max(5, ringWidthPct - 5)
				local sl = doc:GetElementById("slider-ring-width")
				if sl then sl:SetAttribute("value", tostring(ringWidthPct)) end
				local lbl = doc:GetElementById("ring-width-label")
				if lbl then lbl.inner_rml = tostring(ringWidthPct) .. "%" end
				WG.TerraformBrush.setRingInnerRatio(1 - ringWidthPct / 100)
			end
			event:StopPropagation()
		end, false)
	end

	local sliderCapMax = doc:GetElementById("slider-cap-max")
	if sliderCapMax then
		trackSliderDrag(sliderCapMax, "capmax")
		sliderCapMax:AddEventListener("change", function(event)
			if uiState.updatingFromCode then event:StopPropagation(); return end
			local val = tonumber(sliderCapMax:GetAttribute("value")) or 0
			capMaxValue = val
			if capMinValue > capMaxValue then
				capMinValue = capMaxValue
				applyCap("min", capMinValue)
			end
			applyCap("max", capMaxValue)
			event:StopPropagation()
		end, false)
	end

	local sliderCapMin = doc:GetElementById("slider-cap-min")
	if sliderCapMin then
		trackSliderDrag(sliderCapMin, "capmin")
		sliderCapMin:AddEventListener("change", function(event)
			if uiState.updatingFromCode then event:StopPropagation(); return end
			local val = tonumber(sliderCapMin:GetAttribute("value")) or 0
			capMinValue = val
			if capMaxValue < capMinValue then
				capMaxValue = capMinValue
				applyCap("max", capMaxValue)
			end
			applyCap("min", capMinValue)
			event:StopPropagation()
		end, false)
	end

	-- Height cap +/- buttons (reuse a single local to stay under 200-local limit)
	local capBtn
	capBtn = doc:GetElementById("btn-cap-max-up")
	if capBtn then
		capBtn:AddEventListener("click", function(event)
			capMaxValue = math.min(500, capMaxValue + HEIGHT_CAP_STEP)
			if capMinValue > capMaxValue then
				capMinValue = capMaxValue
				applyCap("min", capMinValue)
			end
			applyCap("max", capMaxValue)
			event:StopPropagation()
		end, false)
	end

	capBtn = doc:GetElementById("btn-cap-max-down")
	if capBtn then
		capBtn:AddEventListener("click", function(event)
			capMaxValue = math.max(-500, capMaxValue - HEIGHT_CAP_STEP)
			if capMinValue > capMaxValue then
				capMinValue = capMaxValue
				applyCap("min", capMinValue)
			end
			applyCap("max", capMaxValue)
			event:StopPropagation()
		end, false)
	end

	capBtn = doc:GetElementById("btn-cap-min-up")
	if capBtn then
		capBtn:AddEventListener("click", function(event)
			capMinValue = math.min(500, capMinValue + HEIGHT_CAP_STEP)
			if capMaxValue < capMinValue then
				capMaxValue = capMinValue
				applyCap("max", capMaxValue)
			end
			applyCap("min", capMinValue)
			event:StopPropagation()
		end, false)
	end

	capBtn = doc:GetElementById("btn-cap-min-down")
	if capBtn then
		capBtn:AddEventListener("click", function(event)
			capMinValue = math.max(-500, capMinValue - HEIGHT_CAP_STEP)
			if capMaxValue < capMinValue then
				capMaxValue = capMinValue
				applyCap("max", capMaxValue)
			end
			applyCap("min", capMinValue)
			event:StopPropagation()
		end, false)
	end

	-- SAMPLE buttons: toggle height-sampling mode for each cap endpoint
	capBtn = doc:GetElementById("btn-sample-max")
	if capBtn then
		capBtn:AddEventListener("click", function(event)
			if WG.TerraformBrush then
				local cur = (WG.TerraformBrush.getState() or {}).heightSamplingMode
				WG.TerraformBrush.setHeightSamplingMode(cur == "max" and nil or "max")
			end
			event:StopPropagation()
		end, false)
	end

	capBtn = doc:GetElementById("btn-sample-min")
	if capBtn then
		capBtn:AddEventListener("click", function(event)
			if WG.TerraformBrush then
				local cur = (WG.TerraformBrush.getState() or {}).heightSamplingMode
				WG.TerraformBrush.setHeightSamplingMode(cur == "min" and nil or "min")
			end
			event:StopPropagation()
		end, false)
	end

	local capAbsoluteBtn = doc:GetElementById("btn-cap-absolute")
	if capAbsoluteBtn then
		capAbsoluteBtn:AddEventListener("click", function(event)
			playSound(capAbsolute and "toggleOff" or "toggleOn")
			capAbsolute = not capAbsolute
			if capAbsolute then
				capAbsoluteBtn:SetAttribute("src", "/luaui/images/terraform_brush/check_on.png")
			else
				capAbsoluteBtn:SetAttribute("src", "/luaui/images/terraform_brush/check_off.png")
			end
			if WG.TerraformBrush then
				WG.TerraformBrush.setHeightCapAbsolute(capAbsolute)
			end
			event:StopPropagation()
		end, false)
	end

	local clayBtn = doc:GetElementById("btn-clay-mode")
	if clayBtn then
		clayBtn:AddEventListener("click", function(event)
			local spActive = WG.SplatPainter and WG.SplatPainter.getState() and WG.SplatPainter.getState().active
			if not spActive and WG.TerraformBrush then
				local state = WG.TerraformBrush.getState()
				if not CLAY_UNAVAILABLE_MODES[state and state.mode] then
					local newVal = not (state and state.clayMode)
					playSound(newVal and "toggleOn" or "toggleOff")
					WG.TerraformBrush.setClayMode(newVal)
					clayBtn:SetClass("active", newVal)
				end
			end
			event:StopPropagation()
		end, false)
	end

	do
		local frBtn = doc:GetElementById("btn-full-restore")
		if frBtn then
			frBtn:AddEventListener("click", function(event)
				if widgetState.fullRestoreConfirmExpiry > 0 then
					-- Second click: confirmed
					widgetState.fullRestoreConfirmExpiry = 0
					frBtn:SetClass("confirming", false)
					if widgetState.fullRestoreLabel1 then widgetState.fullRestoreLabel1.inner_rml = "FULL" end
					if widgetState.fullRestoreLabel2 then widgetState.fullRestoreLabel2.inner_rml = "RESTORE" end
					playSound("reset")
					if WG.TerraformBrush then
						WG.TerraformBrush.fullRestore()
					end
				else
					-- First click: ask for confirmation
					widgetState.fullRestoreConfirmExpiry = (Spring.GetGameSeconds() or 0) + 3
					frBtn:SetClass("confirming", true)
					if widgetState.fullRestoreLabel1 then widgetState.fullRestoreLabel1.inner_rml = "ARE YOU" end
					if widgetState.fullRestoreLabel2 then widgetState.fullRestoreLabel2.inner_rml = "SURE?" end
					playSound("toggleOn")
				end
				event:StopPropagation()
			end, false)
		end
	end

	local gridBtn = doc:GetElementById("btn-grid-overlay")
	if gridBtn then
		gridBtn:AddEventListener("click", function(event)
			if WG.TerraformBrush then
				local state = WG.TerraformBrush.getState()
				local newVal = not (state and state.gridOverlay)
				playSound(newVal and "toggleOn" or "toggleOff")
				WG.TerraformBrush.setGridOverlay(newVal)
				gridBtn:SetClass("active", newVal)
			end
			event:StopPropagation()
		end, false)
	end

	do
		local snapBtn = doc:GetElementById("btn-grid-snap")
		if snapBtn then
			snapBtn:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					local newVal = not (state and state.gridSnap)
					playSound(newVal and "toggleOn" or "toggleOff")
					WG.TerraformBrush.setGridSnap(newVal)
					snapBtn:SetClass("active", newVal)
				end
				event:StopPropagation()
			end, false)
		end
		local sliderSnapSize = doc:GetElementById("slider-grid-snap-size")
		if sliderSnapSize then
			sliderSnapSize:AddEventListener("change", function(event)
				if not uiState.updatingFromCode and WG.TerraformBrush then
					local val = tonumber(sliderSnapSize:GetAttribute("value")) or 48
					WG.TerraformBrush.setGridSnapSize(val)
					local lbl = doc:GetElementById("grid-snap-size-label")
					if lbl then lbl.inner_rml = tostring(val) end
					local nb = doc:GetElementById("slider-grid-snap-size-numbox")
					if nb then nb:SetAttribute("value", tostring(val)) end
				end
				event:StopPropagation()
			end, false)
		end
		local snapSizeDownBtn = doc:GetElementById("btn-snap-size-down")
		if snapSizeDownBtn then
			snapSizeDownBtn:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					local cur = state and state.gridSnapSize or 48
					local newVal = math.max(16, cur - 16)
					WG.TerraformBrush.setGridSnapSize(newVal)
					if sliderSnapSize then sliderSnapSize:SetAttribute("value", tostring(newVal)) end
					local lbl = doc:GetElementById("grid-snap-size-label")
					if lbl then lbl.inner_rml = tostring(newVal) end
					local nb = doc:GetElementById("slider-grid-snap-size-numbox")
					if nb then nb:SetAttribute("value", tostring(newVal)) end
				end
				event:StopPropagation()
			end, false)
		end
		local snapSizeUpBtn = doc:GetElementById("btn-snap-size-up")
		if snapSizeUpBtn then
			snapSizeUpBtn:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					local cur = state and state.gridSnapSize or 48
					local newVal = math.min(128, cur + 16)
					WG.TerraformBrush.setGridSnapSize(newVal)
					if sliderSnapSize then sliderSnapSize:SetAttribute("value", tostring(newVal)) end
					local lbl = doc:GetElementById("grid-snap-size-label")
					if lbl then lbl.inner_rml = tostring(newVal) end
					local nb = doc:GetElementById("slider-grid-snap-size-numbox")
					if nb then nb:SetAttribute("value", tostring(newVal)) end
				end
				event:StopPropagation()
			end, false)
		end
	end

	-- ── Protractor: angle-snap toggle + step slider ─────────────────────────────
	do
		local angleSnapBtn = doc:GetElementById("btn-angle-snap")
		if angleSnapBtn then
			angleSnapBtn:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					local newVal = not (state and state.angleSnap)
					playSound(newVal and "toggleOn" or "toggleOff")
					WG.TerraformBrush.setAngleSnap(newVal)
					angleSnapBtn:SetClass("active", newVal)
				end
				event:StopPropagation()
			end, false)
		end
		-- Presets: index 0=7.5°, 1=15°, 2=30°, 3=60°, 4=90°
		local ANGLE_PRESETS = {7.5, 15, 30, 45, 60, 90}
		local function findAnglePresetIdx(val)
			local best, bestD = 1, math.huge
			for i, p in ipairs(ANGLE_PRESETS) do
				local d = math.abs(p - (val or 15))
				if d < bestD then bestD = d; best = i end
			end
			return best
		end
		local function applyAnglePreset(idx)
			idx = math.max(1, math.min(#ANGLE_PRESETS, idx))
			local pval = ANGLE_PRESETS[idx]
			local pstr = (pval == math.floor(pval)) and tostring(math.floor(pval)) or tostring(pval)
			if WG.TerraformBrush then WG.TerraformBrush.setAngleSnapStep(pval) end
			local sl = doc:GetElementById("slider-angle-snap-step")
			if sl then sl:SetAttribute("value", tostring(idx - 1)) end
			local lbl = doc:GetElementById("angle-snap-step-label")
			if lbl then lbl.inner_rml = pstr end
			local nb = doc:GetElementById("slider-angle-snap-step-numbox")
			if nb then nb:SetAttribute("value", pstr) end
		end
		local sliderAngleStep = doc:GetElementById("slider-angle-snap-step")
		if sliderAngleStep then
			sliderAngleStep:AddEventListener("change", function(event)
				if not uiState.updatingFromCode and WG.TerraformBrush then
					local idx = (tonumber(sliderAngleStep:GetAttribute("value")) or 1) + 1
					applyAnglePreset(idx)
				end
				event:StopPropagation()
			end, false)
		end
		local angleStepDownBtn = doc:GetElementById("btn-angle-step-down")
		if angleStepDownBtn then
			angleStepDownBtn:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					local idx = findAnglePresetIdx(state and state.angleSnapStep)
					applyAnglePreset(idx - 1)
				end
				event:StopPropagation()
			end, false)
		end
		local angleStepUpBtn = doc:GetElementById("btn-angle-step-up")
		if angleStepUpBtn then
			angleStepUpBtn:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					local idx = findAnglePresetIdx(state and state.angleSnapStep)
					applyAnglePreset(idx + 1)
				end
				event:StopPropagation()
			end, false)
		end
		-- Autosnap toggle
		local autoSnapBtn = doc:GetElementById("btn-angle-autosnap")
		if autoSnapBtn then
			autoSnapBtn:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					local newVal = not (state and state.angleSnapAuto)
					playSound(newVal and "toggleOn" or "toggleOff")
					WG.TerraformBrush.setAngleSnapAuto(newVal)
					autoSnapBtn:SetClass("active", newVal)
					local manualRow = doc:GetElementById("angle-manual-spoke-row")
					if manualRow then manualRow:SetClass("hidden", newVal) end
				end
				event:StopPropagation()
			end, false)
		end
		-- Manual spoke slider
		local manualSpokeSlider = doc:GetElementById("slider-manual-spoke")
		local function applyManualSpoke(idx)
			if WG.TerraformBrush then
				WG.TerraformBrush.setAngleSnapManualSpoke(idx)
				local state = WG.TerraformBrush.getState()
				local step  = state and state.angleSnapStep or 15
				local deg   = idx * step
				local lbl   = doc:GetElementById("angle-manual-spoke-label")
				if lbl then lbl.inner_rml = tostring(deg % 360) end
				if manualSpokeSlider then manualSpokeSlider:SetAttribute("value", tostring(idx)) end
			end
		end
		if manualSpokeSlider then
			manualSpokeSlider:AddEventListener("change", function(event)
				if not uiState.updatingFromCode then
					local idx = tonumber(manualSpokeSlider:GetAttribute("value")) or 0
					applyManualSpoke(idx)
				end
				event:StopPropagation()
			end, false)
		end
		local manualSpokeDown = doc:GetElementById("btn-manual-spoke-down")
		if manualSpokeDown then
			manualSpokeDown:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					local step  = state and state.angleSnapStep or 15
					local numSpokes = math.max(1, math.floor(360 / step))
					local cur = state and state.angleSnapManualSpoke or 0
					applyManualSpoke((cur - 1 + numSpokes) % numSpokes)
				end
				event:StopPropagation()
			end, false)
		end
		local manualSpokeUp = doc:GetElementById("btn-manual-spoke-up")
		if manualSpokeUp then
			manualSpokeUp:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					local step  = state and state.angleSnapStep or 15
					local numSpokes = math.max(1, math.floor(360 / step))
					local cur = state and state.angleSnapManualSpoke or 0
					applyManualSpoke((cur + 1) % numSpokes)
				end
				event:StopPropagation()
			end, false)
		end
	end

	-- ── Measure tool: toggle + clear ────────────────────────────────────────────
	do
		local measureBtn = doc:GetElementById("btn-measure")
		if measureBtn then
			measureBtn:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					local newVal = not (state and state.measureActive)
					playSound(newVal and "toggleOn" or "toggleOff")
					WG.TerraformBrush.setMeasureActive(newVal)
					measureBtn:SetClass("active", newVal)
				end
				event:StopPropagation()
			end, false)
		end
		local measureClearBtn = doc:GetElementById("btn-measure-clear")
		if measureClearBtn then
			measureClearBtn:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					WG.TerraformBrush.clearMeasureLines()
					playSound("toggleOff")
				end
				event:StopPropagation()
			end, false)
		end
		local rulerModeBtn = doc:GetElementById("btn-measure-ruler")
		if rulerModeBtn then
			rulerModeBtn:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					local newVal = not (state and state.measureRulerMode)
					playSound(newVal and "toggleOn" or "toggleOff")
					WG.TerraformBrush.setMeasureRulerMode(newVal)
					rulerModeBtn:SetClass("active", newVal)
				end
				event:StopPropagation()
			end, false)
		end
		local stickyModeBtn = doc:GetElementById("btn-measure-sticky")
		if stickyModeBtn then
			stickyModeBtn:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					local newVal = not (state and state.measureStickyMode)
					playSound(newVal and "toggleOn" or "toggleOff")
					WG.TerraformBrush.setMeasureStickyMode(newVal)
					stickyModeBtn:SetClass("active", newVal)
				end
				event:StopPropagation()
			end, false)
		end
		local showLengthBtn = doc:GetElementById("btn-measure-show-length")
		if showLengthBtn then
			showLengthBtn:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					local newVal = not (state and state.measureShowLength)
					playSound(newVal and "toggleOn" or "toggleOff")
					WG.TerraformBrush.setMeasureShowLength(newVal)
					showLengthBtn:SetClass("active", newVal)
				end
				event:StopPropagation()
			end, false)
		end
		-- G4: Auto-Ramp toggle — enable/disable automatic ramp chain attachment
		local rampAttachBtn = doc:GetElementById("btn-measure-ramp-attach")
		if rampAttachBtn then
			rampAttachBtn:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					local newVal = not (state and state.rampAutoAttach)
					playSound(newVal and "toggleOn" or "toggleOff")
					WG.TerraformBrush.setRampAutoAttach(newVal)
					rampAttachBtn:SetClass("active", newVal)
				end
				event:StopPropagation()
			end, false)
		end
		-- G4: Clear Ramps — removes only ramp-linked chains, keeps hand-drawn ones
		local clearRampsBtn = doc:GetElementById("btn-measure-clear-ramps")
		if clearRampsBtn then
			clearRampsBtn:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					WG.TerraformBrush.clearRampChains()
					playSound("toggleOff")
				end
				event:StopPropagation()
			end, false)
		end
	end

	-- ── Symmetry tool ───────────────────────────────────────────────────────────
	do
		local symmetryBtn = doc:GetElementById("btn-symmetry")
		if symmetryBtn then
			symmetryBtn:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					local newVal = not (state and state.symmetryActive)
					playSound(newVal and "toggleOn" or "toggleOff")
					WG.TerraformBrush.setSymmetryActive(newVal)
					symmetryBtn:SetClass("active", newVal)
				end
				event:StopPropagation()
			end, false)
		end
		local mirrorXBtn = doc:GetElementById("btn-symmetry-mirror-x")
		if mirrorXBtn then
			mirrorXBtn:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					local newVal = not (state and state.symmetryMirrorX)
					playSound(newVal and "toggleOn" or "toggleOff")
					WG.TerraformBrush.setSymmetryMirrorX(newVal)
					mirrorXBtn:SetClass("active", newVal)
					-- Radial is mutually exclusive
					local radialBtn = doc:GetElementById("btn-symmetry-radial")
					if radialBtn then radialBtn:SetClass("active", false) end
				end
				event:StopPropagation()
			end, false)
		end
		local mirrorYBtn = doc:GetElementById("btn-symmetry-mirror-y")
		if mirrorYBtn then
			mirrorYBtn:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					local newVal = not (state and state.symmetryMirrorY)
					playSound(newVal and "toggleOn" or "toggleOff")
					WG.TerraformBrush.setSymmetryMirrorY(newVal)
					mirrorYBtn:SetClass("active", newVal)
					local radialBtn = doc:GetElementById("btn-symmetry-radial")
					if radialBtn then radialBtn:SetClass("active", false) end
				end
				event:StopPropagation()
			end, false)
		end
		local radialBtn = doc:GetElementById("btn-symmetry-radial")
		if radialBtn then
			radialBtn:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					local newVal = not (state and state.symmetryRadial)
					playSound(newVal and "toggleOn" or "toggleOff")
					WG.TerraformBrush.setSymmetryRadial(newVal)
					radialBtn:SetClass("active", newVal)
					-- Clear mirror buttons when radial on
					if newVal then
						local mxBtn = doc:GetElementById("btn-symmetry-mirror-x")
						if mxBtn then mxBtn:SetClass("active", false) end
						local myBtn = doc:GetElementById("btn-symmetry-mirror-y")
						if myBtn then myBtn:SetClass("active", false) end
					end
				end
				event:StopPropagation()
			end, false)
		end
		-- Radial count slider
		local radialCountSlider = doc:GetElementById("slider-symmetry-radial-count")
		if radialCountSlider then
			radialCountSlider:AddEventListener("change", function(event)
				if not uiState.updatingFromCode and WG.TerraformBrush then
					local val = tonumber(radialCountSlider:GetAttribute("value")) or 2
					WG.TerraformBrush.setSymmetryRadialCount(val)
					local lbl = doc:GetElementById("symmetry-radial-count-label")
					if lbl then lbl.inner_rml = tostring(val) end
				end
				event:StopPropagation()
			end, false)
			trackSliderDrag(radialCountSlider, "symmetry-radial-count")
		end
		local countDownBtn = doc:GetElementById("btn-symmetry-count-down")
		if countDownBtn then
			countDownBtn:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					local cur = (state and state.symmetryRadialCount) or 2
					local newVal = math.max(2, cur - 1)
					WG.TerraformBrush.setSymmetryRadialCount(newVal)
					local lbl = doc:GetElementById("symmetry-radial-count-label")
					if lbl then lbl.inner_rml = tostring(newVal) end
					local sl = doc:GetElementById("slider-symmetry-radial-count")
					if sl then sl:SetAttribute("value", tostring(newVal)) end
				end
				event:StopPropagation()
			end, false)
		end
		local countUpBtn = doc:GetElementById("btn-symmetry-count-up")
		if countUpBtn then
			countUpBtn:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					local cur = (state and state.symmetryRadialCount) or 2
					local newVal = math.min(16, cur + 1)
					WG.TerraformBrush.setSymmetryRadialCount(newVal)
					local lbl = doc:GetElementById("symmetry-radial-count-label")
					if lbl then lbl.inner_rml = tostring(newVal) end
					local sl = doc:GetElementById("slider-symmetry-radial-count")
					if sl then sl:SetAttribute("value", tostring(newVal)) end
				end
				event:StopPropagation()
			end, false)
		end
		-- Place origin button
		local placeOriginBtn = doc:GetElementById("btn-symmetry-place-origin")
		if placeOriginBtn then
			placeOriginBtn:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					WG.TerraformBrush.setSymmetryPlacingOrigin(true)
					playSound("toggleOn")
				end
				event:StopPropagation()
			end, false)
		end
		-- Center origin button
		local centerOriginBtn = doc:GetElementById("btn-symmetry-center-origin")
		if centerOriginBtn then
			centerOriginBtn:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					WG.TerraformBrush.setSymmetryOrigin(nil, nil)
					playSound("toggleOff")
				end
				event:StopPropagation()
			end, false)
		end
		-- Mirror axis angle slider
		local mirrorAngleSlider = doc:GetElementById("slider-symmetry-mirror-angle")
		if mirrorAngleSlider then
			mirrorAngleSlider:AddEventListener("change", function(event)
				if not uiState.updatingFromCode and WG.TerraformBrush then
					local val = tonumber(mirrorAngleSlider:GetAttribute("value")) or 0
					WG.TerraformBrush.setSymmetryMirrorAngle(val)
					local lbl = doc:GetElementById("symmetry-mirror-angle-label")
					if lbl then lbl.inner_rml = tostring(math.floor(val)) end
				end
				event:StopPropagation()
			end, false)
			trackSliderDrag(mirrorAngleSlider, "symmetry-mirror-angle")
		end
		local angleDownBtn = doc:GetElementById("btn-symmetry-angle-down")
		if angleDownBtn then
			angleDownBtn:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					local cur = (state and state.symmetryMirrorAngle) or 0
					local newVal = (cur - 5) % 360
					WG.TerraformBrush.setSymmetryMirrorAngle(newVal)
					local lbl = doc:GetElementById("symmetry-mirror-angle-label")
					if lbl then lbl.inner_rml = tostring(math.floor(newVal)) end
					local sl = doc:GetElementById("slider-symmetry-mirror-angle")
					if sl then sl:SetAttribute("value", tostring(newVal)) end
				end
				event:StopPropagation()
			end, false)
		end
		local angleUpBtn = doc:GetElementById("btn-symmetry-angle-up")
		if angleUpBtn then
			angleUpBtn:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					local cur = (state and state.symmetryMirrorAngle) or 0
					local newVal = (cur + 5) % 360
					WG.TerraformBrush.setSymmetryMirrorAngle(newVal)
					local lbl = doc:GetElementById("symmetry-mirror-angle-label")
					if lbl then lbl.inner_rml = tostring(math.floor(newVal)) end
					local sl = doc:GetElementById("slider-symmetry-mirror-angle")
					if sl then sl:SetAttribute("value", tostring(newVal)) end
				end
				event:StopPropagation()
			end, false)
		end
		-- Flipped mode toggle
		local flippedBtn = doc:GetElementById("btn-symmetry-flipped")
		if flippedBtn then
			flippedBtn:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					local newVal = not (state and state.symmetryFlipped)
					playSound(newVal and "toggleOn" or "toggleOff")
					WG.TerraformBrush.setSymmetryFlipped(newVal)
					flippedBtn:SetClass("active", newVal)
				end
				event:StopPropagation()
			end, false)
		end
		-- Distort mode toggle (visible when measure tool active)
		local distortModeBtn = doc:GetElementById("btn-measure-distort")
		if distortModeBtn then
			distortModeBtn:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					local newVal = not (state and state.measureDistortMode)
					playSound(newVal and "toggleOn" or "toggleOff")
					WG.TerraformBrush.setMeasureDistortMode(newVal)
					distortModeBtn:SetClass("active", newVal)
				end
				event:StopPropagation()
			end, false)
		end
		-- Clear all symmetry settings
		local clearBtn = doc:GetElementById("btn-symmetry-clear")
		if clearBtn then
			clearBtn:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					WG.TerraformBrush.clearSymmetry()
					playSound("toggleOff")
				end
				event:StopPropagation()
			end, false)
		end
	end

	local colormapBtn = doc:GetElementById("btn-height-colormap")
	if colormapBtn then
		colormapBtn:AddEventListener("click", function(event)
			if WG.TerraformBrush then
				local state = WG.TerraformBrush.getState()
				local newVal = not (state and state.heightColormap)
				playSound(newVal and "toggleOn" or "toggleOff")
				WG.TerraformBrush.setHeightColormap(newVal)
				colormapBtn:SetClass("active", newVal)
			end
			event:StopPropagation()
		end, false)
	end

	local curveOverlayBtn = doc:GetElementById("btn-curve-overlay")
	if curveOverlayBtn then
		curveOverlayBtn:AddEventListener("click", function(event)
			if WG.TerraformBrush then
				local state = WG.TerraformBrush.getState()
				local newVal = not (state and state.curveOverlay)
				playSound(newVal and "toggleOn" or "toggleOff")
				WG.TerraformBrush.setCurveOverlay(newVal)
				curveOverlayBtn:SetClass("active", newVal)
			end
			event:StopPropagation()
		end, false)
	end

	local velocityIntensityBtn = doc:GetElementById("btn-velocity-intensity")
	if velocityIntensityBtn then
		velocityIntensityBtn:AddEventListener("click", function(event)
			if WG.TerraformBrush then
				local state = WG.TerraformBrush.getState()
				local newVal = not (state and state.velocityIntensity)
				playSound(newVal and "toggleOn" or "toggleOff")
				WG.TerraformBrush.setVelocityIntensity(newVal)
				velocityIntensityBtn:SetClass("active", newVal)
			end
			event:StopPropagation()
		end, false)
	end

	-- Pen Pressure inline chip toggles (intensity + size rows)
	do
		local penIntChip = doc:GetElementById("btn-pen-intensity")
		if penIntChip then
			penIntChip:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					local newVal = not (state and state.penPressureModulateIntensity)
					playSound(newVal and "toggleOn" or "toggleOff")
					WG.TerraformBrush.setPenPressureModulateIntensity(newVal)
					penIntChip:SetClass("active", newVal)
				end
				event:StopPropagation()
			end, false)
		end
		local penSizeChip = doc:GetElementById("btn-pen-size")
		if penSizeChip then
			penSizeChip:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					local newVal = not (state and state.penPressureModulateSize)
					playSound(newVal and "toggleOn" or "toggleOff")
					WG.TerraformBrush.setPenPressureModulateSize(newVal)
					penSizeChip:SetClass("active", newVal)
				end
				event:StopPropagation()
			end, false)
		end
	end



	local exportBtn = doc:GetElementById("btn-export")
	if exportBtn then
		exportBtn:AddEventListener("click", function(event)
			Spring.SendCommands("terraformexport")
			event:StopPropagation()
		end, false)
	end

	local importBtn = doc:GetElementById("btn-import")
	local tooltipLoad = doc:GetElementById("tooltip-load")
	if importBtn and tooltipLoad then
		importBtn:AddEventListener("mouseover", function(event)
			tooltipLoad:SetClass("hidden", false)
		end, false)
		importBtn:AddEventListener("mouseout", function(event)
			tooltipLoad:SetClass("hidden", true)
		end, false)
	end

	local metalBtn = doc:GetElementById("btn-metal")
	if metalBtn then
		metalBtn:AddEventListener("click", function(event)
			playSound("toolSwitch")
			clearPassthrough()
			if WG.MetalBrush then
				if WG.TerraformBrush then
					WG.TerraformBrush.deactivate()
				end
				if WG.FeaturePlacer then
					WG.FeaturePlacer.deactivate()
				end
				if WG.WeatherBrush then
					WG.WeatherBrush.deactivate()
				end
				if WG.SplatPainter then
					WG.SplatPainter.deactivate()
				end
				if WG.GrassBrush then
					WG.GrassBrush.deactivate()
				end
				widgetState.envActive = false
				widgetState.lightActive = false
				if WG.LightPlacer then WG.LightPlacer.deactivate() end
				widgetState.startposActive = false
				if WG.StartPosTool then WG.StartPosTool.deactivate() end
				widgetState.cloneActive = false
				if WG.CloneTool then WG.CloneTool.deactivate() end
				WG.MetalBrush.activate("paint")
				local clayBtn = doc:GetElementById("btn-clay-mode")
				if clayBtn then
					clayBtn:SetClass("unavailable", true)
				end
			end
			event:StopPropagation()
		end, false)
	end

	-- Grass launch button
	local grassBtn = doc:GetElementById("btn-grass")
	if grassBtn then
		grassBtn:AddEventListener("mouseover", function(event)
			local gApi = WG['grassgl4']
			local hasGrass = gApi and gApi.hasGrass and gApi.hasGrass()
			widgetState.grassHoverNoData = not hasGrass
		end, false)
		grassBtn:AddEventListener("mouseout", function(event)
			widgetState.grassHoverNoData = false
		end, false)
		grassBtn:AddEventListener("click", function(event)
			-- Block activation when the map has no grass data
			local gApi = WG['grassgl4']
			local hasGrass = gApi and gApi.hasGrass and gApi.hasGrass()
			if not hasGrass then
				event:StopPropagation()
				return
			end
			playSound("toolSwitch")
			clearPassthrough()
			if WG.GrassBrush then
				if WG.TerraformBrush then
					WG.TerraformBrush.deactivate()
				end
				if WG.FeaturePlacer then
					WG.FeaturePlacer.deactivate()
				end
				if WG.WeatherBrush then
					WG.WeatherBrush.deactivate()
				end
				if WG.SplatPainter then
					WG.SplatPainter.deactivate()
				end
				if WG.MetalBrush then
					WG.MetalBrush.deactivate()
				end
				widgetState.envActive = false
				widgetState.lightActive = false
				if WG.LightPlacer then WG.LightPlacer.deactivate() end
				widgetState.startposActive = false
				if WG.StartPosTool then WG.StartPosTool.deactivate() end
				widgetState.cloneActive = false
				if WG.CloneTool then WG.CloneTool.deactivate() end
				WG.GrassBrush.activate("paint")
				local clayBtn = doc:GetElementById("btn-clay-mode")
				if clayBtn then
					clayBtn:SetClass("unavailable", true)
				end
			end
			event:StopPropagation()
		end, false)
	end

	-- Decals launch button
	local decalsBtn = doc:GetElementById("btn-decals")
	if decalsBtn then
		decalsBtn:AddEventListener("click", function(event)
			playSound("toolSwitch")
			clearPassthrough()
			if WG.TerraformBrush then WG.TerraformBrush.deactivate() end
			if WG.FeaturePlacer then WG.FeaturePlacer.deactivate() end
			if WG.WeatherBrush then WG.WeatherBrush.deactivate() end
			if WG.SplatPainter then WG.SplatPainter.deactivate() end
			if WG.MetalBrush then WG.MetalBrush.deactivate() end
			if WG.GrassBrush then WG.GrassBrush.deactivate() end
			widgetState.envActive = false
			widgetState.lightActive = false
			if WG.LightPlacer then WG.LightPlacer.deactivate() end
			widgetState.startposActive = false
			if WG.StartPosTool then WG.StartPosTool.deactivate() end
			widgetState.cloneActive = false
			if WG.CloneTool then WG.CloneTool.deactivate() end
			widgetState.decalsActive = true
			if WG.DecalPlacer then
				local s = WG.DecalPlacer.getState()
				if not s or not s.active then
					WG.DecalPlacer.setMode("point")
				end
			end
			local clayBtn = doc:GetElementById("btn-clay-mode")
			if clayBtn then
				clayBtn:SetClass("unavailable", true)
			end
			event:StopPropagation()
		end, false)
	end

	local quitBtn = doc:GetElementById("btn-quit")
	if quitBtn then
		quitBtn:AddEventListener("click", function(event)
			playSound("exit")
			clearPassthrough()
			if WG.TerraformBrush then WG.TerraformBrush.deactivate() end
			if WG.FeaturePlacer then WG.FeaturePlacer.deactivate() end
			if WG.WeatherBrush then WG.WeatherBrush.deactivate() end
			if WG.SplatPainter then WG.SplatPainter.deactivate() end
			if WG.MetalBrush then WG.MetalBrush.deactivate() end
			if WG.GrassBrush then WG.GrassBrush.deactivate() end
			if WG.LightPlacer then WG.LightPlacer.deactivate() end
			if WG.StartPosTool then WG.StartPosTool.deactivate() end
			if WG.CloneTool then WG.CloneTool.deactivate() end
			if WG.DecalPlacer then WG.DecalPlacer.deactivate() end
			widgetState.envActive = false
			widgetState.lightActive = false
			widgetState.startposActive = false
			widgetState.cloneActive = false
			widgetState.decalsActive = false
			event:StopPropagation()
		end, false)
	end

	local defaultsBtn = doc:GetElementById("btn-defaults")
	if defaultsBtn then
		defaultsBtn:AddEventListener("click", function(event)
			playSound("reset")
			if WG.TerraformBrush then
				WG.TerraformBrush.setRadius(100)
				WG.TerraformBrush.setRotation(0)
				WG.TerraformBrush.setCurve(1.0)
				WG.TerraformBrush.setIntensity(1.0)
				WG.TerraformBrush.setLengthScale(1.0)
				WG.TerraformBrush.setShape("circle")
				WG.TerraformBrush.setHeightCapMin(nil)
				WG.TerraformBrush.setHeightCapMax(nil)
				WG.TerraformBrush.setHeightCapAbsolute(true)
				WG.TerraformBrush.setClayMode(false)
				WG.TerraformBrush.setGridOverlay(false)
				WG.TerraformBrush.setDustEffects(false)
				WG.TerraformBrush.setHeightColormap(false)
				WG.TerraformBrush.setCurveOverlay(false)
				WG.TerraformBrush.setVelocityIntensity(false)
				WG.TerraformBrush.setRestoreStrength(1.0)
				WG.TerraformBrush.setBrushOpacity(0.3)
			end
			capMinValue = 0
			capMaxValue = 0
			capAbsolute = true
			local absImg = doc:GetElementById("btn-cap-absolute")
			if absImg then
				absImg:SetAttribute("src", "/luaui/images/terraform_brush/check_on.png")
			end
			local clayImg = doc:GetElementById("btn-clay-mode")
			if clayImg then
				clayImg:SetClass("active", false)
			end
			local gridImg = doc:GetElementById("btn-grid-overlay")
			if gridImg then
				gridImg:SetClass("active", false)
			end
			local dustEl = doc:GetElementById("btn-dust-effects")
			if dustEl then
				dustEl:SetClass("active", false)
				local pill = doc:GetElementById("pill-dust-effects")
				if pill then pill.inner_rml = "OFF" end
			end
			local seismicEl = doc:GetElementById("btn-seismic-effects")
			if seismicEl then
				seismicEl:SetClass("active", false)
				local pill2 = doc:GetElementById("pill-seismic-effects")
				if pill2 then pill2.inner_rml = "OFF" end
			end
			local cmapImg = doc:GetElementById("btn-height-colormap")
			if cmapImg then
				cmapImg:SetClass("active", false)
			end
			local curveOvImg = doc:GetElementById("btn-curve-overlay")
			if curveOvImg then
				curveOvImg:SetClass("active", false)
			end
			local velIntImg = doc:GetElementById("btn-velocity-intensity")
			if velIntImg then
				velIntImg:SetClass("active", false)
			end
			event:StopPropagation()
		end, false)
	end

	-- Preset combobox system
	local presetNameInput = doc:GetElementById("preset-name-input")
	local presetDropdown = doc:GetElementById("preset-dropdown")
	local presetSaveBtn = doc:GetElementById("btn-preset-save")
	local presetToggleBtn = doc:GetElementById("btn-preset-toggle")
	local dropdownOpen = false
	local lastFilter = ""

	if presetNameInput then
		presetNameInput:AddEventListener("focus", function(event)
			WG.TerraformBrushInputFocused = true
			Spring.SDLStartTextInput()
			widgetState.focusedRmlInput = presetNameInput
		end, false)
		presetNameInput:AddEventListener("blur", function(event)
			WG.TerraformBrushInputFocused = false
			Spring.SDLStopTextInput()
			widgetState.focusedRmlInput = nil
		end, false)
	end

	local function setDropdownOpen(open)
		dropdownOpen = open
		if presetDropdown then
			presetDropdown:SetClass("hidden", not open)
		end
		if presetToggleBtn then
			presetToggleBtn:SetClass("open", open)
		end
	end

	-- G7: build a compact one-line parameter summary string for a preset row
	local function buildPresetSummary(pdata, isBuiltin)
		if not pdata then return "" end
		local m = type(pdata.mode) == "string" and pdata.mode or "?"
		local s = type(pdata.shape) == "string" and pdata.shape or "?"
		if #m > 0 then m = m:sub(1,1):upper() .. m:sub(2) end
		if #s > 0 then s = s:sub(1,1):upper() .. s:sub(2) end
		local r = math.floor(tonumber(pdata.radius) or 0)
		local itxt = string.format("%.1f", tonumber(pdata.intensity) or 0)
		local summary = m .. " · " .. s .. " · R:" .. r .. " · I:" .. itxt
		-- Append save date for user presets that have the savedAt field
		if not isBuiltin and pdata.savedAt and pdata.savedAt > 0 then
			local ok, dateStr = pcall(os.date, "%b %d", pdata.savedAt)
			if ok and dateStr and dateStr ~= "" then
				summary = summary .. " · " .. dateStr
			end
		end
		return summary
	end

	local function rebuildPresetList(filter)
		if not presetDropdown or not WG.TerraformBrush then return end
		presetDropdown.inner_rml = ""
		local names = WG.TerraformBrush.getPresetNames()
		local filterLower = filter and filter:lower() or ""
		local count = 0
		for _, name in ipairs(names) do
			if filterLower == "" or name:lower():find(filterLower, 1, true) then
				local isBuiltin = WG.TerraformBrush.isBuiltinPreset(name)
				local row = doc:CreateElement("div")
				row:SetClass("tf-preset-row", true)
				row:SetClass("tf-preset-builtin", isBuiltin)

				-- Top row: name + delete button
				local topRow = doc:CreateElement("div")
				topRow:SetClass("tf-preset-row-top", true)

				local nameEl = doc:CreateElement("div")
				nameEl:SetClass("tf-preset-name", true)
				nameEl.inner_rml = name
				topRow:AppendChild(nameEl)

				local delEl = doc:CreateElement("div")
				delEl:SetClass("tf-preset-delete", true)
				if isBuiltin then
					delEl:SetClass("tf-preset-delete-disabled", true)
					delEl.inner_rml = ""
				else
					delEl.inner_rml = "X"
				end
				topRow:AppendChild(delEl)
				row:AppendChild(topRow)

				-- Summary row: condensed params + optional save date
				local summaryEl = doc:CreateElement("div")
				summaryEl:SetClass("tf-preset-summary", true)
				local pdata = WG.TerraformBrush.getPreset and WG.TerraformBrush.getPreset(name)
				summaryEl.inner_rml = buildPresetSummary(pdata, isBuiltin)
				row:AppendChild(summaryEl)

				-- Click whole row (except delete) to load preset
				row:AddEventListener("click", function(event)
					playSound("click")
					if WG.TerraformBrush then
						WG.TerraformBrush.loadPreset(name)
						if presetNameInput then
							presetNameInput:SetAttribute("value", name)
						end
						setDropdownOpen(false)
					end
					event:StopPropagation()
				end, false)

				if not isBuiltin then
					delEl:AddEventListener("click", function(event)
						playSound("reset")
						if WG.TerraformBrush then
							WG.TerraformBrush.deletePreset(name)
							rebuildPresetList(filter)
						end
						event:StopPropagation()
					end, false)
				end

				presetDropdown:AppendChild(row)
				count = count + 1
			end
		end
		if count == 0 and dropdownOpen then
			setDropdownOpen(false)
		end
	end

	-- Toggle dropdown on arrow click
	if presetToggleBtn then
		presetToggleBtn:AddEventListener("click", function(event)
			playSound("dropdown")
			if dropdownOpen then
				setDropdownOpen(false)
			else
				rebuildPresetList(nil)
				setDropdownOpen(true)
			end
			event:StopPropagation()
		end, false)
	end

	-- Filter dropdown as user types
	if presetNameInput then
		presetNameInput:AddEventListener("change", function(event)
			local val = presetNameInput:GetAttribute("value") or ""
			if val ~= lastFilter then
				lastFilter = val
				rebuildPresetList(val)
				if val ~= "" and not dropdownOpen then
					setDropdownOpen(true)
				end
			end
		end, false)
	end

	if presetSaveBtn then
		presetSaveBtn:AddEventListener("click", function(event)
			playSound("save")
			if WG.TerraformBrush and presetNameInput then
				local name = presetNameInput:GetAttribute("value") or ""
				name = name:match("^%s*(.-)%s*$")
				if name ~= "" then
					WG.TerraformBrush.savePreset(name)
					presetNameInput:SetAttribute("value", "")
					lastFilter = ""
					if dropdownOpen then
						rebuildPresetList(nil)
					end
				end
			end
			event:StopPropagation()
		end, false)
	end

	-- Metal Brush controls (extracted to tf_metal.lua)
	tfMetal.attach(doc, ctx)

	-- Grass Brush controls (extracted to tf_grass.lua)
	tfGrass.attach(doc, ctx)

	-- Tool attach sections extracted to per-tool modules
	tfFeatures.attach(doc, ctx)
	tfWeather.attach(doc, ctx)
	tfSplat.attach(doc, ctx)
	tfDecals.attach(doc, ctx)
	tfEnvironment.attach(doc, ctx)
	tfLights.attach(doc, ctx)
	tfNoise.attach(doc, ctx)


	-- ============ Start Positions tool controls ============
	tfStartPos.attach(doc, ctx)


	-- ============ Clone Tool controls ============
	tfClone.attach(doc, ctx)


	tfGuide.attach(doc, ctx)


	-- ============ Keybind badges (G5) ============
	initBadgeElements(doc)
	updateAllKeybindBadges()

	attachSliderInputBoxes(doc)

	-- ============ Window dragging with edge snapping ============
	do
		local ds = windowDragState
		local allW = windowDragAllWindows

		local function makeWindowDraggable(handleId, rootEl)
			if not rootEl then return end
			local handleEl = doc:GetElementById(handleId)
			if not handleEl then return end
			allW[#allW + 1] = { rootEl = rootEl, handleId = handleId }

			handleEl:AddEventListener("mousedown", function(event)
				local p = event.parameters
				if not p or (p.button and p.button ~= 0) then return end
				local mx, my = GetMouseState()
				local vsx, vsy = GetViewGeometry()
				ds.active = true
				ds.rootEl = rootEl
				ds.offsetX = mx - rootEl.offset_left
				ds.offsetY = (vsx > 0 and vsy > 0) and ((vsy - my) - rootEl.offset_top) or 0
				ds.ew = rootEl.offset_width
				ds.eh = rootEl.offset_height
				ds.vsx = vsx
				ds.vsy = vsy
				ds.lastX = -1
				ds.lastY = -1
				local rects = {}
				for i = 1, #allW do
					local otherEl = allW[i].rootEl
					if otherEl ~= rootEl and not otherEl:IsClassSet("hidden") then
						rects[#rects + 1] = {
							otherEl.offset_left,
							otherEl.offset_top,
							otherEl.offset_width,
							otherEl.offset_height,
						}
					end
				end
				ds.snapRects = rects
				event:StopPropagation()
			end, false)
		end

		-- End drag on any mouseup in the document
		doc:AddEventListener("mouseup", function(event)
			if ds.active then
				if ds.rootEl == widgetState.rootElement then
					local vsx, vsy = ds.vsx, ds.vsy
					if vsx > 0 and vsy > 0 and ds.rootEl then
						currentLeftVw = (ds.rootEl.offset_left / vsx) * 100
						currentTopVh = (ds.rootEl.offset_top / vsy) * 100
					end
				end
				ds.active = false
				ds.rootEl = nil
				ds.snapRects = nil
			end
		end, false)

		makeWindowDraggable("tf-handle", widgetState.rootElement)
		makeWindowDraggable("tf-skybox-library-handle", widgetState.skyboxLibraryRootEl)
		makeWindowDraggable("tf-noise-handle", widgetState.noiseRootEl)
		makeWindowDraggable("tf-env-sun-handle", widgetState.envSunRootEl)
		makeWindowDraggable("tf-env-fog-handle", widgetState.envFogRootEl)
		makeWindowDraggable("tf-env-ground-lighting-handle", widgetState.envGroundLightingRootEl)
		makeWindowDraggable("tf-env-unit-lighting-handle", widgetState.envUnitLightingRootEl)
		makeWindowDraggable("tf-env-map-handle", widgetState.envMapRootEl)
		makeWindowDraggable("tf-env-water-handle", widgetState.envWaterRootEl)
		makeWindowDraggable("tf-env-dimensions-handle", widgetState.envDimensionsRootEl)
		makeWindowDraggable("tf-splattex-handle", widgetState.splatTexRootEl)
		makeWindowDraggable("tf-light-library-handle", widgetState.lightLibraryRootEl)
		makeWindowDraggable("tf-settings-handle", widgetState.settingsRootEl)
	end

	-- ===== Transport (auto-scroll) button listeners =====
	widgetState.regTransports(doc)

	-- Map damage disabled: show notice banner and dim terrain deformation tools
	if Game.mapDamage == false then
		widgetState.noTerraform = true
		do
			local noticeEl = doc:GetElementById("tf-mapdamage-notice")
			if noticeEl then noticeEl:SetClass("hidden", false) end
			local terrainSectionEl = doc:GetElementById("section-terrain")
			if terrainSectionEl then terrainSectionEl:SetClass("tf-terrain-locked", true) end
		end
	end
end


function widget:Initialize()
	widgetState.rmlContext = RmlUi.GetContext("shared")
	if not widgetState.rmlContext then
		return false
	end

	local dm = widgetState.rmlContext:OpenDataModel(MODEL_NAME, initialModel, self)
	if not dm then
		return false
	end
	widgetState.dmHandle = dm

	local document = widgetState.rmlContext:LoadDocument(RML_PATH)
	if not document then
		widget:Shutdown()
		return false
	end
	widgetState.document = document
	document:Show()

	widgetState.rootElement = document:GetElementById("tf-root")
	widgetState.rootElement:SetClass("hidden", true)

	local vsx = GetViewGeometry()
	local scaleFactor = math.max(1.0, vsx / BASE_RESOLUTION)
	widgetState.panelWidthDp = math.floor(BASE_WIDTH_DP * scaleFactor)
	lastVsx, lastVsy = GetViewGeometry()
	currentLeftVw = INITIAL_LEFT_VW
	currentTopVh = INITIAL_TOP_VH
	widgetState.rootElement:SetAttribute("style", buildRootStyle())

	widgetState.panelHidden = false
	widgetHandler:AddAction("terraformpanel", function()
		widgetState.panelHidden = not widgetState.panelHidden
		if widgetState.rootElement then
			widgetState.rootElement:SetClass("hidden", widgetState.panelHidden)
		end
		return true
	end, nil, "t")

	attachEventListeners()
	applyEnvWindowWidths()

	-- Pen pressure: suppress brush modulation when cursor is over the UI panel
	if widgetState.rootElement then
		widgetState.rootElement:AddEventListener("mouseover", function()
			if WG.TerraformBrush then WG.TerraformBrush.setPenOverUI(true) end
		end, false)
		widgetState.rootElement:AddEventListener("mouseout", function()
			if WG.TerraformBrush then WG.TerraformBrush.setPenOverUI(false) end
		end, false)
	end

	-- Expose UI-side API for key capture and badge refresh
	WG.TerraformBrushUI = {
		isCapturingKey = function()
			return widgetState.settingsCapturing ~= nil
		end,
		captureKey = function(keyCode)
			return handleSettingsKeyCapture(keyCode)
		end,
		refreshBadges = function()
			updateAllKeybindBadges()
		end,
		handleToolKey = function(keyCode)
			return handleToolKey(keyCode)
		end,
		-- Called by cmd_terraform_brush when the user clicks a height in sampling mode
		onHeightSampled = function(target, value)
			-- Update the local cap variables so the state sync loop reflects them
			if target == "max" then
				capMaxValue = value or 0
			elseif target == "min" then
				capMinValue = value or 0
			end
		end,
		-- Programmatically expand the HEIGHT CAP section (e.g. triggered by Alt+Shift scroll)
		expandHeightCap = function()
			local ctrl = widgetState.heightCapSectionCtrl
			if ctrl and ctrl.expand then ctrl.expand() end
		end,
		-- Returns the panel pixel bounds in Spring screen coords (Y=0 at bottom).
		-- Returns nil when the panel is hidden or not yet available.
		getPanelBounds = function()
			local vsx, vsy = Spring.GetViewGeometry()
			if vsx <= 0 then return nil end
			local root = widgetState.rootElement
			if not root then return nil end
			if widgetState.panelHidden then return nil end
			local leftPx   = root.offset_left
			local topPx    = root.offset_top
			local widthPx  = root.offset_width
			local heightPx = root.offset_height
			if not leftPx or widthPx == 0 or heightPx == 0 then return nil end
			-- Spring screen Y: 0=bottom, vsy=top
			return {
				left    = leftPx,
				right   = leftPx + widthPx,
				topY    = vsy - topPx,
				bottomY = vsy - topPx - heightPx,
			}
		end,
	}
end

local lastUpdateClock = Spring.GetTimer()

function widget:DrawScreen()
	-- One-shot: pre-load skybox DDS textures into GL named texture cache
	-- so Spring.SetSkyBoxTexture() can find them. Must happen in a Draw call-in.
	if widgetState.envLoadedTextures and not widgetState.envTexturesPreloaded then
		for _, path in ipairs(widgetState.envLoadedTextures) do
			gl.Texture(path)
			gl.Texture(false)
		end
		widgetState.envTexturesPreloaded = true
	end

	-- Draw sun position indicator on screen when environment mode is active
	if widgetState.envActive then
		local sx, sy, sz = gl.GetSun("pos")
		if sx then
			local cx, cy, cz = Spring.GetCameraPosition()
			local far = 50000
			local wx, wy, wz = cx + sx * far, cy + sy * far, cz + sz * far
			local scrX, scrY, scrZ = Spring.WorldToScreenCoords(wx, wy, wz)
			-- Only draw if the point is in front of the camera (scrZ < 1)
			if scrX and scrZ and scrZ < 1 then
				local vsx, vsy = Spring.GetViewGeometry()
				scrX = math.max(0, math.min(vsx, scrX))
				scrY = math.max(0, math.min(vsy, scrY))

				local r = 28
				local segs = 32
				gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
				gl.LineWidth(2.5)

				-- Outer ring (dark outline)
				gl.Color(0, 0, 0, 0.7)
				gl.BeginEnd(GL.LINE_LOOP, function()
					for i = 0, segs - 1 do
						local a = (i / segs) * math.pi * 2
						gl.Vertex(scrX + math.cos(a) * (r + 2), scrY + math.sin(a) * (r + 2))
					end
				end)

				-- Sun circle (yellow)
				gl.Color(1, 0.85, 0.1, 1)
				gl.BeginEnd(GL.LINE_LOOP, function()
					for i = 0, segs - 1 do
						local a = (i / segs) * math.pi * 2
						gl.Vertex(scrX + math.cos(a) * r, scrY + math.sin(a) * r)
					end
				end)

				-- Crosshair lines
				local cr = r + 16
				gl.LineWidth(2)
				gl.Color(1, 0.85, 0.1, 1)
				gl.BeginEnd(GL.LINES, function()
					gl.Vertex(scrX - cr, scrY)
					gl.Vertex(scrX - r - 3, scrY)
					gl.Vertex(scrX + r + 3, scrY)
					gl.Vertex(scrX + cr, scrY)
					gl.Vertex(scrX, scrY - cr)
					gl.Vertex(scrX, scrY - r - 3)
					gl.Vertex(scrX, scrY + r + 3)
					gl.Vertex(scrX, scrY + cr)
				end)

				-- Center dot
				gl.Color(1, 1, 0.3, 1)
				gl.BeginEnd(GL.QUADS, function()
					gl.Vertex(scrX - 2.5, scrY - 2.5)
					gl.Vertex(scrX + 2.5, scrY - 2.5)
					gl.Vertex(scrX + 2.5, scrY + 2.5)
					gl.Vertex(scrX - 2.5, scrY + 2.5)
				end)

				gl.LineWidth(1)
				gl.Color(1, 1, 1, 1)
				gl.Blending(false)
			end
		end
	end

	-- Sample terrain diffuse color under cursor via $map_gbuffer_difftex (screen-space, matches viewport)
	do
		local mx, my = GetMouseState()
		if mx and my then
			-- Verify cursor is over terrain (TraceScreenRay returns nil for sky/water/off-map)
			local _, coords = TraceScreenRay(mx, my, true)
			if coords then
				local vsx, vsy = Spring.GetViewGeometry()
				-- Screen UV: mouse position directly maps to gbuffer UV (no world-space transform needed)
				local u = mx / vsx
				local v = my / vsy
				if u >= 0 and u <= 1 and v >= 0 and v <= 1 then
					-- Lazy-init 1x1 FBO
					if not widgetState.spMinimapSampleTex then
						widgetState.spMinimapSampleTex = gl.CreateTexture(1, 1, {
							min_filter = GL.NEAREST, mag_filter = GL.NEAREST,
							fbo = true,
						})
					end
					local fboTex = widgetState.spMinimapSampleTex
					if fboTex then
						-- Pass 1: render gbuffer pixel into FBO
						gl.RenderToTexture(fboTex, function()
							gl.Texture("$map_gbuffer_difftex")
							gl.TexRect(-1, -1, 1, 1, u, v, u, v)
							gl.Texture(false)
						end)
						-- Pass 2: read back (separate call — render+read in same callback is unreliable)
						local sr, sg, sb
						gl.RenderToTexture(fboTex, function()
							sr, sg, sb = gl.ReadPixels(0, 0, 1, 1)
						end)
						if sr then
							local prev = widgetState.spTerrainColor
							if prev then
								-- Frame-rate independent smooth blend (exp decay, ~0.4s half-life)
								local now = Spring.GetTimer()
								local last = widgetState.spTerrainColorTime or now
								local dt = Spring.DiffTimers(now, last)
								widgetState.spTerrainColorTime = now
								local k = 1 - math.exp(-3.5 * dt) -- ~0.4s to reach halfway
								prev[1] = prev[1] + (sr - prev[1]) * k
								prev[2] = prev[2] + (sg - prev[2]) * k
								prev[3] = prev[3] + (sb - prev[3]) * k
							else
								widgetState.spTerrainColor = { sr, sg, sb }
								widgetState.spTerrainColorTime = Spring.GetTimer()
							end
						end
					end
				end
			end
		end
	end
end

function widget:DrawScreenPost()
	-- Render splat detail texture previews over the RML placeholder divs
	local els = widgetState.spPreviewEls
	if not els then return end

	-- Skip if root panel is hidden (tool deactivated or manually toggled off)
	local rootEl = widgetState.rootElement
	if rootEl and rootEl:IsClassSet("hidden") then return end

	-- Skip if splat controls panel is hidden
	local spEl = widgetState.spControlsEl
	local spOrigVisible = spEl and not spEl:IsClassSet("hidden")
	if not spOrigVisible then return end

	-- One-shot: find working per-layer textures (must run in a Draw call-in)
	if not widgetState.spPreviewVerified then
		widgetState.spPreviewRetries = (widgetState.spPreviewRetries or 0) + 1
		local found = {}
		local isDNTS = true
		local logRetry = (widgetState.spPreviewRetries == 1 or widgetState.spPreviewRetries == 30 or widgetState.spPreviewRetries == 120)
		-- Helper: try multiple path variants for a texture name
		local function tryTex(path)
			if not path or type(path) ~= "string" or path == "" then return nil end
			for _, candidate in ipairs({path, "maps/" .. path, ":l:" .. path, ":l:maps/" .. path}) do
				local info = gl.TextureInfo(candidate)
				if info then
					if logRetry then Spring.Echo("[TFBrush] tryTex OK: " .. candidate .. " id=" .. tostring(info.id or "nil") .. " xsize=" .. tostring(info.xsize or "nil")) end
					return candidate
				end
			end
			return nil
		end
		-- Strategy 1: $ssmf_splat_normals:N engine bindings (DNTS packed, most reliable)
		for i = 0, 3 do
			local name = "$ssmf_splat_normals:" .. i
			local info = gl.TextureInfo(name)
			if logRetry then
				if info then
					Spring.Echo("[TFBrush] Strategy1 " .. name .. " id=" .. tostring(info.id or "nil") .. " xsize=" .. tostring(info.xsize or "nil"))
				else
					Spring.Echo("[TFBrush] Strategy1 " .. name .. " -> nil")
				end
			end
			if info and info.xsize and info.xsize > 0 then
				found[i + 1] = name
			end
		end
		-- Strategy 2: mapinfo.lua resources (prefer DNTS normals over diffuse)
		if not next(found) then
			if logRetry then Spring.Echo("[TFBrush] Strategy1 found nothing, trying mapinfo.lua") end
			local mOk, mapinfo = pcall(VFS.Include, "mapinfo.lua")
			if logRetry then Spring.Echo("[TFBrush] mapinfo.lua load: ok=" .. tostring(mOk) .. " type=" .. type(mapinfo)) end
			if mOk and mapinfo then
				local res = mapinfo.resources or {}
				if logRetry then
					for k, v in pairs(res) do
						if type(k) == "string" and k:lower():find("splat") then
							Spring.Echo("[TFBrush] mapinfo.resources." .. k .. " = " .. tostring(v))
						end
					end
				end
				-- 2a: Try DNTS normal maps first (splatDetailNormalTex — shader expects this format)
				for i = 1, 4 do
					for _, key in ipairs({"splatDetailNormalTex" .. i, "splatDetailNormalTex" .. (i - 1), "splatdetailnormaltex" .. i, "splatdetailnormaltex" .. (i - 1)}) do
						local result = tryTex(res[key])
						if result then found[i] = result; break end
					end
				end
				-- 2b: Fall back to diffuse detail textures (different shader path needed)
				if not next(found) then
					isDNTS = false
					-- Try splatDetailTex table
					local sdt = res.splatDetailTex or res.splatdetailtex
					if type(sdt) == "table" then
						if logRetry then Spring.Echo("[TFBrush] splatDetailTex is table, #=" .. #sdt) end
						for i = 1, 4 do
							found[i] = tryTex(sdt[i]) or tryTex(sdt[i - 1])
						end
					end
					-- Try numbered splatDetailTex keys (0-based and 1-based)
					if not next(found) then
						for i = 1, 4 do
							for _, key in ipairs({"splatDetailTex" .. (i - 1), "splatDetailTex" .. i, "splatdetailtex" .. (i - 1), "splatdetailtex" .. i}) do
								local result = tryTex(res[key])
								if result then found[i] = result; break end
							end
						end
					end
				end
			end
		end
		if logRetry then
			Spring.Echo("[TFBrush] Discovery result (retry " .. widgetState.spPreviewRetries .. "): isDNTS=" .. tostring(isDNTS))
			for i = 1, 4 do
				Spring.Echo("[TFBrush]   channel " .. i .. " = " .. tostring(found[i] or "NONE"))
			end
		end
		widgetState.spPreviewTextures = found
		widgetState.spPreviewIsDNTS = isDNTS
		-- Only mark verified once textures found, or after enough retries
		if next(found) or widgetState.spPreviewRetries >= 120 then
			widgetState.spPreviewVerified = true
			Spring.Echo("[TFBrush] Texture discovery DONE at retry " .. widgetState.spPreviewRetries .. " found=" .. tostring(next(found) ~= nil))
		end
	end

	local textures = widgetState.spPreviewTextures
	if not textures or not next(textures) then return end

	-- Lazy-init terrain preview shader (handles DNTS normal maps and diffuse fallback)
	if not widgetState.spPreviewShader and gl.CreateShader then
		widgetState.spPreviewShader = gl.CreateShader({
			vertex = [[
				#version 130
				void main() {
					gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
					gl_TexCoord[0] = gl_MultiTexCoord0;
				}
			]],
			fragment = [[
				#version 130
				uniform sampler2D tex0;
				uniform int channel;
				uniform int isDNTS;
				uniform vec3 terrainColor;
				void main() {
					vec2 uv = gl_TexCoord[0].st;
					vec4 c = texture2D(tex0, uv);

					vec3 lit;
					if (isDNTS != 0) {
						// DNTS packed format: R=detail, G=normalX, B=normalY, A=specular
						vec3 n;
						n.x = c.g * 2.0 - 1.0;
						n.y = c.b * 2.0 - 1.0;
						n.z = sqrt(max(1.0 - n.x*n.x - n.y*n.y, 0.0));
						n = normalize(n);

						vec3 keyDir  = normalize(vec3(0.35, 0.8, 0.5));
						vec3 fillDir = normalize(vec3(-0.6, 0.3, 0.4));
						vec3 viewDir = vec3(0.0, 0.0, 1.0);
						float key  = max(dot(n, keyDir), 0.0);
						float fill = max(dot(n, fillDir), 0.0) * 0.3;
						vec3 halfVec = normalize(keyDir + viewDir);
						float spec = pow(max(dot(n, halfVec), 0.0), 24.0) * c.a;
						float lighting = 0.28 + 0.52 * key + fill;

						vec3 tc = terrainColor;
						float detail = c.r;
						vec3 tintA = tc * 0.55;
						vec3 tintB = tc * 1.05 + vec3(0.03);
						vec3 baseColor = mix(tintA, tintB, detail);
						lit = baseColor * lighting + vec3(0.9, 0.85, 0.75) * spec * 0.35;
					} else {
						// Diffuse detail texture: show actual RGB with gentle lighting
						vec3 keyDir  = normalize(vec3(0.35, 0.8, 0.5));
						vec3 faceN   = vec3(0.0, 0.0, 1.0);
						float lighting = 0.45 + 0.55 * max(dot(faceN, keyDir), 0.0);
						lit = c.rgb * lighting;
					}

					// Edge fade — smooth rounded falloff
					vec2 vc = (uv - 0.5) * 2.0;
					float edgeDist = max(abs(vc.x), abs(vc.y));
					float fade = smoothstep(1.0, 0.65, edgeDist);
					lit *= mix(0.55, 1.0, fade);

					// Slight contrast boost
					lit = pow(lit, vec3(0.92));

					gl_FragColor = vec4(lit, 1.0);
				}
			]],
			uniformInt = { tex0 = 0, channel = 0, isDNTS = 1 },
			uniformFloat = { terrainColor = { 0.4, 0.4, 0.4 } },
		})
		if not widgetState.spPreviewShader or widgetState.spPreviewShader == 0 then
			local shLog = gl.GetShaderLog and gl.GetShaderLog() or "no log"
			Spring.Echo("[TFBrush] Shader creation FAILED: " .. shLog)
			widgetState.spPreviewShader = nil
		else
			Spring.Echo("[TFBrush] Shader created OK: " .. tostring(widgetState.spPreviewShader))
			widgetState.spPreviewShaderChannelLoc = gl.GetUniformLocation(widgetState.spPreviewShader, "channel")
			widgetState.spPreviewShaderTerrainLoc = gl.GetUniformLocation(widgetState.spPreviewShader, "terrainColor")
			widgetState.spPreviewShaderIsDNTSLoc = gl.GetUniformLocation(widgetState.spPreviewShader, "isDNTS")
		end
	end

	local vsx, vsy = Spring.GetViewGeometry()
	local shader = widgetState.spPreviewShader

	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	gl.Color(1, 1, 1, 1)
	if shader then
		gl.UseShader(shader)
		-- Pass sampled terrain color to shader
		local tc = widgetState.spTerrainColor
		if tc and widgetState.spPreviewShaderTerrainLoc then
			gl.Uniform(widgetState.spPreviewShaderTerrainLoc, tc[1], tc[2], tc[3])
		end
		-- Tell shader whether textures are DNTS or plain diffuse
		if widgetState.spPreviewShaderIsDNTSLoc then
			gl.UniformInt(widgetState.spPreviewShaderIsDNTSLoc, widgetState.spPreviewIsDNTS and 1 or 0)
		end
	end

	local logDraw = not widgetState.spPreviewDrawLogged
	for i = 1, 4 do
		local div = els[i]
		local tex = textures[i]
		if div and tex then
			local x = div.absolute_left
			local y = div.absolute_top
			local w = div.offset_width
			local h = div.offset_height

			if logDraw then
				Spring.Echo("[TFBrush] Draw ch" .. i .. " pos=(" .. x .. "," .. y .. ") size=(" .. w .. "," .. h .. ") tex=" .. tex)
			end

			if w > 0 and h > 0 then
				local glY1 = vsy - y - h
				local glY2 = vsy - y

				if shader and widgetState.spPreviewShaderChannelLoc then
					gl.UniformInt(widgetState.spPreviewShaderChannelLoc, i - 1)
				end
				local bound = gl.Texture(0, tex)
				if logDraw then
					Spring.Echo("[TFBrush] gl.Texture(0, " .. tex .. ") = " .. tostring(bound))
				end
				if bound then
					-- Center crop to 1:1 aspect (cover-fit)
					local aspect = w / h
					local u0, u1, v0, v1
					if aspect > 1 then
						local inset = (1 - 1 / aspect) * 0.5
						u0, u1, v0, v1 = 0, 1, inset, 1 - inset
					else
						local inset = (1 - aspect) * 0.5
						u0, u1, v0, v1 = inset, 1 - inset, 0, 1
					end
					gl.TexRect(x, glY1, x + w, glY2, u0, v0, u1, v1)
					gl.Texture(0, false)
				end
			end
		end
	end
	widgetState.spPreviewDrawLogged = true

	if shader then gl.UseShader(0) end
	gl.Blending(true)
	gl.Color(1, 1, 1, 1)
end

-- Shared: draw black overlay on sky pixels (depth == 1.0) for skybox fade
local function drawSkyFadeOverlay()
	if not skyFade.active then return end

	local alpha = 0
	if skyFade.phase == "fadeout" then
		alpha = skyFade.progress
	elseif skyFade.phase == "fadein" then
		alpha = 1 - skyFade.progress
	end
	if alpha <= 0 then return end

	gl.DepthMask(false)
	gl.DepthTest(GL.EQUAL)

	gl.MatrixMode(GL.PROJECTION)
	gl.PushMatrix()
	gl.LoadIdentity()
	gl.MatrixMode(GL.MODELVIEW)
	gl.PushMatrix()
	gl.LoadIdentity()

	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	gl.Color(0, 0, 0, alpha)

	gl.BeginEnd(GL.QUADS, function()
		gl.Vertex(-1, -1, 1)
		gl.Vertex( 1, -1, 1)
		gl.Vertex( 1,  1, 1)
		gl.Vertex(-1,  1, 1)
	end)

	gl.Color(1, 1, 1, 1)

	gl.MatrixMode(GL.PROJECTION)
	gl.PopMatrix()
	gl.MatrixMode(GL.MODELVIEW)
	gl.PopMatrix()

	gl.DepthTest(false)
	gl.DepthMask(true)
	gl.Blending(false)
end

function widget:DrawWorld()
	drawSkyFadeOverlay()
end

function widget:DrawWorldReflection()
	drawSkyFadeOverlay()
end

function widget:Update()
	local ok, err = pcall(function()

	-- One-shot: when map damage is disabled, auto-switch to Features tool on first update
	if widgetState.noTerraform and not widgetState.noTerraformInitDone and WG.FeaturePlacer then
		widgetState.noTerraformInitDone = true
		if WG.TerraformBrush then WG.TerraformBrush.deactivate() end
		WG.FeaturePlacer.setMode("scatter")
	end

	-- Poll-based window drag (position only — mouseup ends drag via doc listener)
	local ds = windowDragState
	if ds.active and ds.rootEl then
		local mx, my = GetMouseState()
		local vsx, vsy = ds.vsx, ds.vsy
		local ew, eh = ds.ew, ds.eh
		local T = WINDOW_SNAP_THRESHOLD
		-- Spring Y is from bottom, RmlUI Y is from top
		local rmlY = vsy - my
		local newX = mx - ds.offsetX
		local newY = rmlY - ds.offsetY

		if newX < 0 then newX = 0
		elseif newX + ew > vsx then newX = vsx - ew end
		if newY < 0 then newY = 0
		elseif newY + eh > vsy then newY = vsy - eh end

		if newX < T then newX = 0
		elseif vsx - newX - ew < T then newX = vsx - ew end
		if newY < T then newY = 0
		elseif vsy - newY - eh < T then newY = vsy - eh end

		local rects = ds.snapRects
		if rects then
			local newR, newB = newX + ew, newY + eh
			for i = 1, #rects do
				local r = rects[i]
				local ox, oy = r[1], r[2]
				local oR, oB = ox + r[3], oy + r[4]
				if newY < oB and newB > oy then
					local d = newX - oR
					if d > -T and d < T then newX = oR; newR = newX + ew
					else d = newR - ox
						if d > -T and d < T then newX = ox - ew; newR = ox
						else d = newX - ox
							if d > -T and d < T then newX = ox; newR = newX + ew
							else d = newR - oR
								if d > -T and d < T then newX = oR - ew; newR = oR end
							end
						end
					end
				end
				if newX < oR and newR > ox then
					local d = newY - oB
					if d > -T and d < T then newY = oB; newB = newY + eh
					else d = newB - oy
						if d > -T and d < T then newY = oy - eh; newB = oy
						else d = newY - oy
							if d > -T and d < T then newY = oy; newB = newY + eh
							else d = newB - oB
								if d > -T and d < T then newY = oB - eh; newB = oB end
							end
						end
					end
				end
			end
		end

		local ix = math.floor(newX)
		local iy = math.floor(newY)
		if ix ~= ds.lastX or iy ~= ds.lastY then
			ds.lastX = ix
			ds.lastY = iy
			ds.rootEl.style.left = ix .. "px"
			ds.rootEl.style.top  = iy .. "px"
		end
	end

	-- When game chat input is open, auto-blur any focused RmlUI text input so
	-- Tab reaches the chat widget for autocomplete instead of navigating RmlUI fields.
	if widgetState.focusedRmlInput and WG['chat'] and WG['chat'].isInputActive() then
		widgetState.focusedRmlInput:Blur()
		widgetState.focusedRmlInput = nil
	end

	-- Drive skybox fade transition
	local now = Spring.GetTimer()
	local dt = Spring.DiffTimers(now, lastUpdateClock)
	lastUpdateClock = now
	tickSkyboxFade(dt)
	tickSkyDynamic(dt)

	-- Transport auto-scroll tick
	do
		local TSPEEDS = {0.005, 0.02, 0.08, 0.25}  -- fraction of range per second at each speed level
		for _, t in pairs(widgetState.transports) do
			if not t.paused then
				local rmin  = tonumber(t.el:GetAttribute("min"))  or 0
				local rmax  = tonumber(t.el:GetAttribute("max"))  or 100
				local rstep = tonumber(t.el:GetAttribute("step")) or 1
				-- directional scroll
				if t.dir ~= 0 then
					local rate  = (TSPEEDS[t.speed] or 0.005) * (rmax - rmin) * t.dir
					t.accum = t.accum + rate * dt
					if math.abs(t.accum) >= rstep then
						local stps  = math.floor(math.abs(t.accum) / rstep)
						local delta = stps * rstep * (t.accum >= 0 and 1 or -1)
						t.accum    = t.accum - delta
						local cur  = tonumber(t.el:GetAttribute("value")) or rmin
						local nv
						if t.wrap then
							nv = rmin + ((cur + delta - rmin) % (rmax - rmin + rstep))
						else
							nv = math.max(rmin, math.min(rmax, cur + delta))
						end
						if cur ~= nv then
							t.el:SetAttribute("value", tostring(nv))
						end
					end
				end
			end
		end
	end

	updateFloatingTip()
	-- Detect viewport resize and recalculate panel layout
	local vsx, vsy = GetViewGeometry()
	if vsx ~= lastVsx or vsy ~= lastVsy then
		lastVsx, lastVsy = vsx, vsy
		local scaleFactor = math.max(1.0, vsx / BASE_RESOLUTION)
		widgetState.panelWidthDp = math.floor(BASE_WIDTH_DP * scaleFactor)
		if widgetState.rootElement then
			widgetState.rootElement:SetAttribute("style", buildRootStyle())
		end
		applyEnvWindowWidths()
	end

	local tfState = WG.TerraformBrush and WG.TerraformBrush.getState()
	local fpState = WG.FeaturePlacer and WG.FeaturePlacer.getState()
	local wbState = WG.WeatherBrush and WG.WeatherBrush.getState()
	local spState = WG.SplatPainter and WG.SplatPainter.getState()
	local mbState = WG.MetalBrush and WG.MetalBrush.getState()
	local gbState = WG.GrassBrush and WG.GrassBrush.getState()
	local tfActive = tfState and tfState.active
	local fpActive = fpState and fpState.active
	local wbActive = wbState and wbState.active
	local spActive = spState and spState.active
	local mbActive = mbState and mbState.active
	local gbActive = gbState and gbState.active
	local envActive = widgetState.envActive
	local lpState = WG.LightPlacer and WG.LightPlacer.getState()
	local lpActive = widgetState.lightActive and lpState and lpState.active
	local stpState = WG.StartPosTool and WG.StartPosTool.getState()
	local stpActive = widgetState.startposActive and stpState and stpState.active
	local clState = WG.CloneTool and WG.CloneTool.getState()
	local clActive = widgetState.cloneActive and clState and clState.active
	local decalsActive = widgetState.decalsActive and true or false

	-- Deactivate environment mode when any other tool becomes active
	if envActive and (tfActive or fpActive or wbActive or spActive or mbActive or gbActive or lpActive or stpActive or clActive or decalsActive) then
		widgetState.envActive = false
		envActive = false
	end
	-- Deactivate light mode when any other tool becomes active
	if lpActive and (tfActive or fpActive or wbActive or spActive or mbActive or gbActive or envActive or stpActive or clActive or decalsActive) then
		widgetState.lightActive = false
		if WG.LightPlacer then WG.LightPlacer.deactivate() end
		lpActive = false
	end
	-- Deactivate startpos mode when any other tool becomes active
	if stpActive and (tfActive or fpActive or wbActive or spActive or mbActive or gbActive or envActive or lpActive or clActive or decalsActive) then
		widgetState.startposActive = false
		if WG.StartPosTool then WG.StartPosTool.deactivate() end
		stpActive = false
	end
	-- Deactivate clone mode when any other tool becomes active
	if clActive and (tfActive or fpActive or wbActive or spActive or mbActive or gbActive or envActive or lpActive or stpActive or decalsActive) then
		widgetState.cloneActive = false
		if WG.CloneTool then WG.CloneTool.deactivate() end
		clActive = false
	end
	-- Deactivate decals mode when any other (real) tool becomes active
	if decalsActive and (tfActive or fpActive or wbActive or spActive or mbActive or gbActive or envActive or lpActive or stpActive or clActive) then
		widgetState.decalsActive = false
		if WG.DecalPlacer then WG.DecalPlacer.deactivate() end
		decalsActive = false
	end

	-- Show panel if any tool is active (and panel not manually hidden), or if in passthrough mode
	local panelVisible = (tfActive or fpActive or wbActive or spActive or mbActive or gbActive or envActive or lpActive or stpActive or clActive or decalsActive or widgetState.passthroughMode) and not widgetState.panelHidden
	if widgetState.rootElement then
		widgetState.rootElement:SetClass("hidden", not panelVisible)
	end
	if not panelVisible then
		-- Clear any locked sliders when panel hides
		if next(widgetState.lockedSliders) then
			for id, element in pairs(widgetState.lockedSliders) do
				element:SetClass("slider-locked", false)
				element:SetClass("slider-pulse", false)
			end
			widgetState.lockedSliders = {}
			widgetState.sliderLastClickTime = {}
		end
		-- Clear flash state and prev-sync tracking
		for id, flash in pairs(widgetState.sliderFlashes) do
			flash.el:SetClass("slider-flash", false)
		end
		widgetState.sliderFlashes = {}
		widgetState.prevSyncValues = {}
		return
	end

	-- Toggle section visibility
	if panelVisible then
	if widgetState.tfControlsEl then
		widgetState.tfControlsEl:SetClass("hidden", fpActive or wbActive or spActive or mbActive or gbActive or envActive or lpActive or stpActive or clActive or decalsActive or false)
	end
	if widgetState.fpControlsEl then
		widgetState.fpControlsEl:SetClass("hidden", not fpActive)
	end
	if widgetState.fpSubmodesEl then
		widgetState.fpSubmodesEl:SetClass("hidden", not fpActive)
	end
	if widgetState.wbControlsEl then
		widgetState.wbControlsEl:SetClass("hidden", not wbActive)
	end
	if widgetState.wbSubmodesEl then
		widgetState.wbSubmodesEl:SetClass("hidden", not wbActive)
	end
	if widgetState.mbControlsEl then
		widgetState.mbControlsEl:SetClass("hidden", not mbActive)
	end
	if widgetState.mbSubmodesEl then
		widgetState.mbSubmodesEl:SetClass("hidden", not mbActive)
	end
	if widgetState.gbControlsEl then
		widgetState.gbControlsEl:SetClass("hidden", not gbActive)
	end
	if widgetState.gbSubmodesEl then
		widgetState.gbSubmodesEl:SetClass("hidden", not gbActive)
	end
	if widgetState.spControlsEl then
		widgetState.spControlsEl:SetClass("hidden", not spActive)
	end
	if widgetState.splatTexRootEl then
		if not spActive then
			widgetState.splatTexOpen = false
			widgetState.splatTexRootEl:SetClass("hidden", true)
		else
			widgetState.splatTexRootEl:SetClass("hidden", not widgetState.splatTexOpen)
		end
	end
	if widgetState.dcControlsEl then
		widgetState.dcControlsEl:SetClass("hidden", not widgetState.decalsActive)
	end
	if widgetState.dcSubmodesEl then
		widgetState.dcSubmodesEl:SetClass("hidden", not widgetState.decalsActive)
	end
	if widgetState.envControlsEl then
		widgetState.envControlsEl:SetClass("hidden", not envActive)
	end
	if widgetState.lightControlsEl then
		widgetState.lightControlsEl:SetClass("hidden", not lpActive)
	end
	if widgetState.stpSubmodesEl then
		widgetState.stpSubmodesEl:SetClass("hidden", not stpActive)
	end
	if widgetState.stpControlsEl then
		widgetState.stpControlsEl:SetClass("hidden", not stpActive)
	end
	if widgetState.cloneControlsEl then
		widgetState.cloneControlsEl:SetClass("hidden", not clActive)
	end
	if widgetState.clonePasteTransformsEl then
		local showTransforms = clActive and clState and (clState.state == "paste_preview" or clState.state == "copied")
		widgetState.clonePasteTransformsEl:SetClass("hidden", not showTransforms)
	end
	-- Hide skybox library when environment mode is deactivated
	if widgetState.skyboxLibraryRootEl then
		if not envActive then
			widgetState.skyboxLibraryOpen = false
			widgetState.skyboxLibraryRootEl:SetClass("hidden", true)
		else
			widgetState.skyboxLibraryRootEl:SetClass("hidden", not widgetState.skyboxLibraryOpen)
		end
	end
	-- Hide environment sub-windows when environment mode is deactivated
	local envWindows = {
		{ el = widgetState.envSunRootEl, key = "envSunOpen" },
		{ el = widgetState.envFogRootEl, key = "envFogOpen" },
		{ el = widgetState.envGroundLightingRootEl, key = "envGroundLightingOpen" },
		{ el = widgetState.envUnitLightingRootEl, key = "envUnitLightingOpen" },
		{ el = widgetState.envMapRootEl, key = "envMapOpen" },
		{ el = widgetState.envWaterRootEl, key = "envWaterOpen" },
		{ el = widgetState.envDimensionsRootEl, key = "envDimensionsOpen" },
	}
	for _, w in ipairs(envWindows) do
		if w.el then
			if not envActive then
				widgetState[w.key] = false
				w.el:SetClass("hidden", true)
			else
				w.el:SetClass("hidden", not widgetState[w.key])
			end
		end
	end
	-- Hide light library when light mode is deactivated
	if widgetState.lightLibraryRootEl then
		if not lpActive then
			widgetState.lightLibraryOpen = false
			widgetState.lightLibraryRootEl:SetClass("hidden", true)
		else
			widgetState.lightLibraryRootEl:SetClass("hidden", not widgetState.lightLibraryOpen)
		end
	end
	if widgetState.shapeRowEl then
		-- Scene (environment), clone, and startpos do not use shapes at all
		local hideShape = envActive or clActive or stpActive
			or widgetState.cloneActive or widgetState.startposActive or widgetState.envActive
		widgetState.shapeRowEl:SetClass("hidden", hideShape and true or false)
	end
	if widgetState.smoothSubmodesEl then
		local otherToolActive = fpActive or wbActive or spActive or mbActive or gbActive or envActive or lpActive or stpActive or clActive or decalsActive
		local inSmoothGroup = tfActive and tfState and (tfState.mode == "smooth" or tfState.mode == "level")
		widgetState.smoothSubmodesEl:SetClass("hidden", otherToolActive or not inSmoothGroup)
	end
	-- Ensure full-restore button only shows in terraform restore mode
	do
		local inTfRestore = tfActive and tfState and tfState.mode == "restore"
		local clayEl = doc and doc:GetElementById("btn-clay-mode")
		if clayEl then clayEl:SetClass("hidden", inTfRestore == true) end
		local frEl = widgetState.fullRestoreEl
		if frEl then frEl:SetClass("hidden", not inTfRestore) end
	end
	end -- if panelVisible

	local dcActive = widgetState.decalsActive

	-- Toggle noise floating window
	local noiseActive = tfActive and tfState.mode == "noise"
	if noiseActive and not widgetState.lastNoiseActive then
		widgetState.noiseManuallyHidden = false
	end
	widgetState.lastNoiseActive = noiseActive
	if widgetState.noiseRootEl then
		widgetState.noiseRootEl:SetClass("hidden", not noiseActive or widgetState.noiseManuallyHidden)
	end

	-- Disable ring shape when in feature, weather, splat, metal, or light mode
	local ringBtn = widgetState.shapeButtons.ring
	if ringBtn then
		ringBtn:SetClass("disabled", fpActive or wbActive or spActive or mbActive or gbActive or lpActive or false)
	end

	-- Disable hexagon/octagon/triangle in light mode (LightPlacer only supports circle/square)
	local hexBtn = widgetState.shapeButtons.hexagon
	if hexBtn then hexBtn:SetClass("disabled", lpActive or false) end
	local octBtn = widgetState.shapeButtons.octagon
	if octBtn then octBtn:SetClass("disabled", lpActive or false) end
	local triBtn = widgetState.shapeButtons.triangle
	if triBtn then triBtn:SetClass("disabled", lpActive or false) end

	-- Disable fill+clay in metal mode; disable fill in feature/grass/weather/light/noise modes
	local fillBtn = widgetState.shapeButtons.fill
	if fillBtn then
		fillBtn:SetClass("disabled", mbActive or fpActive or gbActive or wbActive or lpActive or noiseActive or false)
	end
	local clayBtn = doc and doc:GetElementById("btn-clay-mode")
	if clayBtn then
		clayBtn:SetClass("disabled", mbActive or lpActive or false)
	end

	local doc = widgetState.document

	-- Status summary helper (shared by all tool branches)
	local sumEl = doc and doc:GetElementById("status-summary")
	local function setSummary(title, color, ...)
		if not sumEl then return end
		local sep = '<span class="tf-ss-sep">|</span>'
		local buf = { '<span class="tf-ss-mode" style="color: ' .. color .. ';">' .. title .. '</span>' }
		local args = { ... }
		for i = 1, #args, 2 do
			buf[#buf + 1] = sep
			local label = args[i] or ""
			local value = args[i + 1] or ""
			if label == "" then
				buf[#buf + 1] = '<span class="tf-ss-val">' .. value .. '</span>'
			else
				buf[#buf + 1] = '<span class="tf-ss-label">' .. label .. '</span><span class="tf-ss-val">' .. value .. '</span>'
			end
		end
		sumEl.inner_rml = table.concat(buf)
	end

	-- Deactivate all tool buttons; each mode section re-activates its own
	if doc then
		do
			local toolBtnIds = {"btn-metal", "btn-features", "btn-splat", "btn-decals", "btn-weather", "btn-environment", "btn-lights", "btn-grass", "btn-startpos", "btn-clone"}
			for _, btnId in ipairs(toolBtnIds) do
				local el = doc:GetElementById(btnId)
				if el then el:SetClass("active", false) end
			end
		end

		-- Hide ramp-type row by default; the terrain-mode branch re-shows it when in ramp mode
		do
			local rampTypeRowEl = doc:GetElementById("tf-ramp-type-row")
			if rampTypeRowEl then rampTypeRowEl:SetClass("hidden", true) end
			local shapeRowEl = doc:GetElementById("tf-shape-row")
			-- Scene (env), clone, and startpos do not use shapes — keep hidden for those
			local hideShape2 = envActive or clActive or stpActive
				or widgetState.cloneActive or widgetState.startposActive or widgetState.envActive
			if shapeRowEl then shapeRowEl:SetClass("hidden", hideShape2 and true or false) end
		end

		-- Preemptively gray out the grass button on maps with no grass data.
		-- The actual status-summary override runs at the end of this function
		-- so all other per-tool updates still get to run.
		do
			local gApi = WG['grassgl4']
			local hasGrass = gApi and gApi.hasGrass and gApi.hasGrass()
			local grassBtnEl = doc:GetElementById("btn-grass")
			if grassBtnEl then
				grassBtnEl:SetClass("disabled", not hasGrass)
			end
			widgetState.grassNoDataThisMap = not hasGrass
		end
	end

	if mbActive then
		-- Metal Brush sync (extracted to tf_metal.lua)
		tfMetal.sync(doc, ctx, mbState, setSummary)

	elseif gbActive then
		-- Grass Brush sync (extracted to tf_grass.lua)
		tfGrass.sync(doc, ctx, gbState, setSummary, sumEl)

	elseif spActive then
		tfSplat.sync(doc, ctx, spState, setSummary)


	elseif fpActive then
		tfFeatures.sync(doc, ctx, fpState, setSummary)


	elseif envActive then
		tfEnvironment.sync(doc, ctx, setSummary)


	elseif lpActive then
		tfLights.sync(doc, ctx, lpState, setSummary)


	elseif stpActive then
		tfStartPos.sync(doc, ctx, stpState, setSummary)


	elseif clActive then
		tfClone.sync(doc, ctx, clState, setSummary)


	elseif decalsActive then
		tfDecals.sync(doc, ctx, setSummary)


	elseif tfActive then
		-- ===== Terraform mode: update terraform controls =====
		local state = tfState

		local effectiveMaxIntensity = getEffectiveMaxIntensity()
		if state.intensity > effectiveMaxIntensity then
			WG.TerraformBrush.setIntensity(effectiveMaxIntensity)
			state = WG.TerraformBrush.getState()
		end

		if widgetState.dmHandle then
			widgetState.dmHandle.radius = state.radius
			widgetState.dmHandle.shapeName = shapeNames[state.shape] or "Circle"
			widgetState.dmHandle.rotationDeg = state.rotationDeg
			widgetState.dmHandle.curve = string.format("%.1f", state.curve)
			widgetState.dmHandle.intensity = string.format("%.1f", state.intensity)

			-- Stamp mode badge visibility
			local stampBadge = doc and doc:GetElementById("stamp-badge")
			if stampBadge then
				local isStamp = WG.TerraformBrush.isStampMode and WG.TerraformBrush.isStampMode() or false
				stampBadge:SetClass("hidden", not isStamp)
			end

			widgetState.dmHandle.lengthScale = string.format("%.1f", state.lengthScale)
			widgetState.dmHandle.heightCapMaxStr = capMaxValue ~= 0 and tostring(capMaxValue) or "--"
			widgetState.dmHandle.heightCapMinStr = capMinValue ~= 0 and tostring(capMinValue) or "--"
		end

		if doc then
			uiState.updatingFromCode = true
			local ds = uiState.draggingSlider

			syncAndFlash(doc:GetElementById("slider-rotation"), "rotation", tostring(state.rotationDeg))

			syncAndFlash(doc:GetElementById("slider-curve"), "curve", tostring(math.floor(state.curve * 10 + 0.5)))

			do
				local elIntensity = doc:GetElementById("slider-intensity")
				if elIntensity then
					elIntensity:SetAttribute("max", tostring(intensityToSlider(effectiveMaxIntensity)))
				end
				local penEnabled = state.penPressureEnabled == true
				local penActive = penEnabled and state.penInContact and state.penPressureModulateIntensity
				if penActive then
					local pm = state.penPressureMapped or state.penPressure or 0
					local sens = state.penPressureSensitivity or 1.0
					local effInt = (state.intensity or 1) * (1.0 + pm * sens)
					syncAndFlash(elIntensity, "intensity", tostring(intensityToSlider(effInt)))
				else
					syncAndFlash(elIntensity, "intensity", tostring(intensityToSlider(state.intensity)))
				end
			end

			syncAndFlash(doc:GetElementById("slider-length"), "length", tostring(math.floor(state.lengthScale * 10 + 0.5)))

			do
				local penEnabled = state.penPressureEnabled == true
				local penActive = penEnabled and state.penInContact and state.penPressureModulateSize
				if penActive then
					local pm = state.penPressureMapped or state.penPressure or 0
					local sens = state.penPressureSensitivity or 1.0
					local effSize = math.floor((state.radius or 100) * (1.0 + pm * sens) + 0.5)
					syncAndFlash(doc:GetElementById("slider-size"), "size", tostring(effSize))
				else
					syncAndFlash(doc:GetElementById("slider-size"), "size", tostring(state.radius))
				end
			end

			local ringWidthRowEl = doc:GetElementById("ring-width-row")
			if ringWidthRowEl then
				ringWidthRowEl:SetClass("hidden", state.shape ~= "ring")
			end
			-- Sync ringWidthPct from widget state (e.g. changed by Ctrl+R scroll)
			if state.ringInnerRatio then
				ringWidthPct = math.floor((1 - state.ringInnerRatio) * 100 + 0.5)
			end
			syncAndFlash(doc:GetElementById("slider-ring-width"), "ring-width", tostring(ringWidthPct))
			local ringWidthLabelEl = doc:GetElementById("ring-width-label")
			if ringWidthLabelEl then
				ringWidthLabelEl.inner_rml = tostring(ringWidthPct) .. "%"
			end

			local restoreStrengthRow = doc:GetElementById("restore-strength-row")
			if restoreStrengthRow then
				restoreStrengthRow:SetClass("hidden", state.mode ~= "restore")
			end
			local sliderRestoreStrength = doc:GetElementById("slider-restore-strength")
			if sliderRestoreStrength and ds ~= "restoreStrength" then
				sliderRestoreStrength:SetAttribute("value", tostring(math.floor((state.restoreStrength or 1.0) * 100 + 0.5)))
			end
			local restoreStrengthLabel = doc:GetElementById("restore-strength-label")
			if restoreStrengthLabel then
				restoreStrengthLabel.inner_rml = tostring(math.floor((state.restoreStrength or 1.0) * 100 + 0.5)) .. "%"
			end

			local sliderCapMax = doc:GetElementById("slider-cap-max")
			if sliderCapMax and ds ~= "capmax" then
				sliderCapMax:SetAttribute("value", tostring(capMaxValue))
			end

			local sliderCapMin = doc:GetElementById("slider-cap-min")
			if sliderCapMin and ds ~= "capmin" then
				sliderCapMin:SetAttribute("value", tostring(capMinValue))
			end

			local sliderHistory = doc:GetElementById("slider-history")
			if sliderHistory and ds ~= "history" then
				local totalSteps = (state.undoCount or 0) + (state.redoCount or 0)
				local maxVal = math.min(totalSteps, 400)
				if maxVal < 1 then maxVal = 1 end
				sliderHistory:SetAttribute("max", tostring(maxVal))
				sliderHistory:SetAttribute("value", tostring(state.undoCount or 0))
			end

			local clayImg = doc:GetElementById("btn-clay-mode")
			if clayImg then
				clayImg:SetClass("active", state.clayMode == true)
				clayImg:SetClass("unavailable", CLAY_UNAVAILABLE_MODES[state.mode] == true)
			end

			local gridImg = doc:GetElementById("btn-grid-overlay")
			if gridImg then
				gridImg:SetClass("active", state.gridOverlay == true)
			end

			local snapImg = doc:GetElementById("btn-grid-snap")
			if snapImg then
				snapImg:SetClass("active", state.gridSnap == true)
			end

			local snapSizeRow = doc:GetElementById("grid-snap-size-row")
			if snapSizeRow then
				snapSizeRow:SetClass("hidden", not state.gridSnap)
			end
			local sliderSnapSizeSync = doc:GetElementById("slider-grid-snap-size")
			if sliderSnapSizeSync then
				sliderSnapSizeSync:SetAttribute("value", tostring(state.gridSnapSize or 48))
			end
			local snapSizeLabel = doc:GetElementById("grid-snap-size-label")
			if snapSizeLabel then
				snapSizeLabel.inner_rml = tostring(state.gridSnapSize or 48)
			end
			local snapSizeNb = doc:GetElementById("slider-grid-snap-size-numbox")
			if snapSizeNb then
				snapSizeNb:SetAttribute("value", tostring(state.gridSnapSize or 48))
			end

			-- Protractor state sync
			local angleSnapImg = doc:GetElementById("btn-angle-snap")
			if angleSnapImg then
				angleSnapImg:SetClass("active", state.angleSnap == true)
			end
			local angleStepRow = doc:GetElementById("angle-snap-step-row")
			if angleStepRow then
				angleStepRow:SetClass("hidden", not state.angleSnap)
			end
			local ANGLE_PRESETS_SYNC = {7.5, 15, 30, 45, 60, 90}
			local function findAnglePresetIdxSync(val)
				local best, bestD = 1, math.huge
				for i, p in ipairs(ANGLE_PRESETS_SYNC) do
					local d = math.abs(p - (val or 15))
					if d < bestD then bestD = d; best = i end
				end
				return best
			end
			local curStep = state.angleSnapStep or 15
			local curIdx  = findAnglePresetIdxSync(curStep)
			local curStr  = (curStep == math.floor(curStep)) and tostring(math.floor(curStep)) or tostring(curStep)
			local sliderAngleStepSync = doc:GetElementById("slider-angle-snap-step")
			if sliderAngleStepSync then
				sliderAngleStepSync:SetAttribute("value", tostring(curIdx - 1))
			end
			local angleStepLbl = doc:GetElementById("angle-snap-step-label")
			if angleStepLbl then
				angleStepLbl.inner_rml = curStr
			end
			local angleStepNb = doc:GetElementById("slider-angle-snap-step-numbox")
			if angleStepNb then
				angleStepNb:SetAttribute("value", curStr)
			end

			-- Autosnap toggle + manual spoke sync
			do
				local isAuto = state.angleSnapAuto ~= false
				local asBtn = doc:GetElementById("btn-angle-autosnap")
				if asBtn then asBtn:SetClass("active", isAuto) end
				local msRow = doc:GetElementById("angle-manual-spoke-row")
				if msRow then msRow:SetClass("hidden", isAuto) end
				if not isAuto then
					local step2 = state.angleSnapStep or 15
					local numSpokes2 = math.max(1, math.floor(360 / step2))
					local spokeIdx = state.angleSnapManualSpoke or 0
					local spokeAngle = (spokeIdx * step2) % 360
					local msLbl = doc:GetElementById("angle-manual-spoke-label")
					if msLbl then msLbl.inner_rml = tostring(spokeAngle) end
					local msSlider = doc:GetElementById("slider-manual-spoke")
					if msSlider then
						uiState.updatingFromCode = true
						msSlider:SetAttribute("max", tostring(numSpokes2 - 1))
						msSlider:SetAttribute("value", tostring(spokeIdx))
						uiState.updatingFromCode = false
					end
				end
			end

			-- Measure tool state sync
			local measureImg = doc:GetElementById("btn-measure")
			if measureImg then
				measureImg:SetClass("active", state.measureActive == true)
			end
			-- Ramp-manipulator discoverability: dot + chip pulse once a ramp is drawn
			do
				local curCount = state.measureChainCount or 0
				local lastCount = widgetState.lastMeasureChainCount or 0
				if curCount > lastCount then
					widgetState.instrumentsHintActive = true
				end
				widgetState.lastMeasureChainCount = curCount
				local instSec = doc:GetElementById("section-instruments")
				local instDot = doc:GetElementById("instruments-notify-dot")
				if instDot then
					local secHidden = instSec and instSec:IsClassSet("hidden") or false
					instDot:SetClass("hidden", not (widgetState.instrumentsHintActive and secHidden))
				end
				if widgetState.instrumentsPulseFrame and Spring.GetGameFrame() >= widgetState.instrumentsPulseFrame then
					widgetState.instrumentsPulseFrame = nil
					if widgetState.instrumentsHintActive then
						widgetState.instrumentsHintActive = false
						if measureImg then
							measureImg:SetClass("tf-chip-2pulse", false)
							measureImg:SetClass("tf-chip-2pulse", true)
							widgetState.instrumentsPulseExpiry = (Spring.GetGameSeconds() or 0) + 1.25
						end
					end
				end
				if widgetState.instrumentsPulseExpiry and (Spring.GetGameSeconds() or 0) >= widgetState.instrumentsPulseExpiry then
					widgetState.instrumentsPulseExpiry = nil
					if measureImg then measureImg:SetClass("tf-chip-2pulse", false) end
				end
			end
			local measureToolRow = doc:GetElementById("measure-toolbar-row")
			if measureToolRow then
				measureToolRow:SetClass("hidden", not state.measureActive)
			end
			do
				local rulerBtn = doc:GetElementById("btn-measure-ruler")
				if rulerBtn then
					rulerBtn:SetClass("active", state.measureRulerMode == true)
				end
				local stickyBtn = doc:GetElementById("btn-measure-sticky")
				if stickyBtn then
					stickyBtn:SetClass("active", state.measureStickyMode == true)
				end
				local showLenBtn = doc:GetElementById("btn-measure-show-length")
				if showLenBtn then
					showLenBtn:SetClass("active", state.measureShowLength == true)
				end
			end

			-- Symmetry tool state sync
			do
				local symBtn = doc:GetElementById("btn-symmetry")
				if symBtn then symBtn:SetClass("active", state.symmetryActive == true) end
				local symRow = doc:GetElementById("symmetry-toolbar-row")
				if symRow then symRow:SetClass("hidden", not state.symmetryActive) end
				local symRadialBtn = doc:GetElementById("btn-symmetry-radial")
				if symRadialBtn then symRadialBtn:SetClass("active", state.symmetryRadial == true) end
				local symMirrorXBtn = doc:GetElementById("btn-symmetry-mirror-x")
				if symMirrorXBtn then symMirrorXBtn:SetClass("active", state.symmetryMirrorX == true) end
				local symMirrorYBtn = doc:GetElementById("btn-symmetry-mirror-y")
				if symMirrorYBtn then symMirrorYBtn:SetClass("active", state.symmetryMirrorY == true) end
				local symFlippedBtn = doc:GetElementById("btn-symmetry-flipped")
				if symFlippedBtn then symFlippedBtn:SetClass("active", state.symmetryFlipped == true) end
				local distortBtn = doc:GetElementById("btn-measure-distort")
				if distortBtn then
					distortBtn:SetClass("active", state.measureDistortMode == true)
					distortBtn:SetClass("hidden", not state.measureActive)
				end
				local symRadialRow = doc:GetElementById("symmetry-radial-count-row")
				if symRadialRow then symRadialRow:SetClass("hidden", not state.symmetryRadial) end
				local symCountLabel = doc:GetElementById("symmetry-radial-count-label")
				if symCountLabel then symCountLabel.inner_rml = tostring(state.symmetryRadialCount or 2) end
				local symCountSlider = doc:GetElementById("slider-symmetry-radial-count")
				if symCountSlider then symCountSlider:SetAttribute("value", tostring(state.symmetryRadialCount or 2)) end
				local hasAxial = state.symmetryMirrorX or state.symmetryMirrorY
				local mirrorAngleRow = doc:GetElementById("symmetry-mirror-angle-row")
				if mirrorAngleRow then mirrorAngleRow:SetClass("hidden", not hasAxial) end
				local mirrorAngleLabel = doc:GetElementById("symmetry-mirror-angle-label")
				if mirrorAngleLabel then mirrorAngleLabel.inner_rml = tostring(math.floor(state.symmetryMirrorAngle or 0)) end
				local mirrorAngleSlider = doc:GetElementById("slider-symmetry-mirror-angle")
				if mirrorAngleSlider then mirrorAngleSlider:SetAttribute("value", tostring(state.symmetryMirrorAngle or 0)) end
			end

			local dustEl = doc:GetElementById("btn-dust-effects")
			if dustEl then
				dustEl:SetClass("active", state.dustEffects == true)
				local pill = doc:GetElementById("pill-dust-effects")
				if pill then pill.inner_rml = state.dustEffects and "ON" or "OFF" end
			end
			local seismicEl = doc:GetElementById("btn-seismic-effects")
			if seismicEl then
				seismicEl:SetClass("active", state.seismicEffects == true)
				local pill2 = doc:GetElementById("pill-seismic-effects")
				if pill2 then pill2.inner_rml = state.seismicEffects and "ON" or "OFF" end
			end
			local djActivateEl = doc:GetElementById("btn-dj-activate")
			if djActivateEl then
				djActivateEl:SetClass("active", state.djMode == true)
				local pillDj = doc:GetElementById("pill-dj-activate")
				if pillDj then pillDj.inner_rml = state.djMode and "ON" or "OFF" end
			end
			local subSettings = doc:GetElementById("dj-sub-settings")
			if subSettings then subSettings:SetClass("dj-disabled", not state.djMode) end
			local cmapImg = doc:GetElementById("btn-height-colormap")
			if cmapImg then
				cmapImg:SetClass("active", state.heightColormap == true)
			end

			do
				local sampleMax = doc:GetElementById("btn-sample-max")
				if sampleMax then sampleMax:SetClass("active", state.heightSamplingMode == "max") end
				local sampleMin = doc:GetElementById("btn-sample-min")
				if sampleMin then sampleMin:SetClass("active", state.heightSamplingMode == "min") end
			end

			local curveOvImg = doc:GetElementById("btn-curve-overlay")
			if curveOvImg then
				curveOvImg:SetClass("active", state.curveOverlay == true)
			end

			local velIntImg = doc:GetElementById("btn-velocity-intensity")
			if velIntImg then
				velIntImg:SetClass("active", state.velocityIntensity == true)
			end



			do
				local penEnabled = state.penPressureEnabled == true
				local pm = state.penPressureMapped or state.penPressure or 0
				local pctStr = string.format("%d%%", math.floor(pm * 100 + 0.5))

				-- Intensity pen pill: show only when pen enabled AND modulate intensity is on
				local penIntChip = doc:GetElementById("btn-pen-intensity")
				if penIntChip then
					local showInt = penEnabled and (state.penPressureModulateIntensity == true)
					penIntChip:SetClass("hidden", not showInt)
					penIntChip:SetClass("active", showInt)
				end
				local penIntLabel = doc:GetElementById("pen-intensity-label")
				if penIntLabel then
					local showInt = penEnabled and (state.penPressureModulateIntensity == true)
					penIntLabel:SetClass("hidden", not showInt)
					if showInt then penIntLabel.inner_rml = pctStr end
				end

				-- Size pen pill: show only when pen enabled AND modulate size is on
				local penSizeChip = doc:GetElementById("btn-pen-size")
				if penSizeChip then
					local showSize = penEnabled and (state.penPressureModulateSize == true)
					penSizeChip:SetClass("hidden", not showSize)
					penSizeChip:SetClass("active", showSize)
				end
				local penSizeLabel = doc:GetElementById("pen-size-label")
				if penSizeLabel then
					local showSize = penEnabled and (state.penPressureModulateSize == true)
					penSizeLabel:SetClass("hidden", not showSize)
					if showSize then penSizeLabel.inner_rml = pctStr end
				end

				-- Pen pressure labels only (no slider movement to avoid feedback loops)
				uiState.updatingFromCode = false

				-- Settings panel sync
				local penToggle = doc:GetElementById("btn-pen-pressure-toggle")
				if penToggle then penToggle:SetClass("active", penEnabled) end
				local pillPen = doc:GetElementById("pill-pen-pressure")
				if pillPen then pillPen.inner_rml = penEnabled and "ON" or "OFF" end
				local penSub = doc:GetElementById("pen-pressure-sub")
				if penSub then penSub:SetClass("dj-disabled", not penEnabled) end
				local modIntImg = doc:GetElementById("btn-pen-mod-intensity")
				if modIntImg then
					modIntImg:SetAttribute("src", (state.penPressureModulateIntensity) and "/luaui/images/terraform_brush/check_on.png" or "/luaui/images/terraform_brush/check_off.png")
				end
				local modSizeImg = doc:GetElementById("btn-pen-mod-size")
				if modSizeImg then
					modSizeImg:SetAttribute("src", (state.penPressureModulateSize) and "/luaui/images/terraform_brush/check_on.png" or "/luaui/images/terraform_brush/check_off.png")
				end
				-- Curve buttons
				local curveMap = { [1]="btn-curve-linear", [2]="btn-curve-quad", [3]="btn-curve-cubic", [4]="btn-curve-scurve", [5]="btn-curve-log" }
				local curveVal = state.penPressureCurve or 2
				for cv, cid in pairs(curveMap) do
					local el = doc:GetElementById(cid)
					if el then el:SetClass("active", cv == curveVal) end
				end
			end

			uiState.updatingFromCode = false
		end

		do
			local primaryKey = (state.mode == "level") and "smooth" or state.mode
			setActiveClass(widgetState.modeButtons, primaryKey)
		end
		setActiveClass(widgetState.shapeButtons, state.shape)

		-- Smooth/Level submode active chip sync (visibility handled below, after tool-active checks)
		if widgetState.smoothSubModeButtons then
			local inSmoothGroup = state.mode == "smooth" or state.mode == "level"
			setActiveClass(widgetState.smoothSubModeButtons, inSmoothGroup and state.mode or nil)
		end

		-- Show ramp-type-row when in ramp mode; hide normal shape row
		local rampTypeRowEl = doc and doc:GetElementById("tf-ramp-type-row")
		local shapeRowEl    = doc and doc:GetElementById("tf-shape-row")
		if rampTypeRowEl then
			local isRamp = state.mode == "ramp"
			rampTypeRowEl:SetClass("hidden", not isRamp)
			if shapeRowEl then shapeRowEl:SetClass("hidden", isRamp) end
		end
		-- Sync ramp type buttons
		local rts = widgetState.rampTypeButtons
		if rts.straight then rts.straight:SetClass("active", state.shape == "square") end
		if rts.spline   then rts.spline:SetClass("active", state.shape == "circle") end

		-- D4: Update contextual status summary line
		do
			local sumEl = doc and doc:GetElementById("status-summary")
			if sumEl then
				local modeColors = {
					raise = "#22c55e", lower = "#ef4444", level = "#06b6d4", smooth = "#06b6d4",
					ramp = "#fad400", restore = "#a855f7", noise = "#fbbf24",
				}
				local m = state.mode or "---"
				local mc = modeColors[m] or "#9ca3af"
				local sep = '<span class="tf-ss-sep">|</span>'
				local function lv(label, value)
					return '<span class="tf-ss-label">' .. label .. '</span><span class="tf-ss-val">' .. value .. '</span>'
				end
				local parts = {
					'<span class="tf-ss-mode" style="color: ' .. mc .. ';">' .. m:upper() .. '</span>',
					sep,
					lv("", shapeNames[state.shape] or "Circle"),
					sep,
					lv("R ", tostring(state.radius)),
					sep,
					lv("Int ", string.format("%.1f", state.intensity)),
					sep,
					lv("Crv ", string.format("%.1f", state.curve)),
				}
				if state.velocityIntensity and state.dragVelocityFactor then
					parts[#parts + 1] = sep
					parts[#parts + 1] = '<span class="tf-ss-label">Vel </span><span class="tf-ss-val" style="color: #fbbf24;">' .. string.format("x%.1f", state.dragVelocityFactor) .. '</span>'
				end
				if state.mode == "restore" then
					parts[#parts + 1] = sep
					parts[#parts + 1] = lv("Str ", tostring(math.floor((state.restoreStrength or 1) * 100 + 0.5)) .. "%")
				end
				sumEl.inner_rml = table.concat(parts)
			end
		end

		-- Sync noise type buttons when in noise mode
		if state.mode == "noise" and state.noiseType then
			setActiveClass(widgetState.noiseTypeButtons, state.noiseType)

			-- Sync noise sliders from state (handles preset loads, keyboard changes, etc.)
			uiState.updatingFromCode = true
			local ds = uiState.draggingSlider

			local noiseSliderScale = doc:GetElementById("slider-noise-scale")
			if noiseSliderScale and ds ~= "noise-scale" then
				noiseSliderScale:SetAttribute("value", tostring(state.noiseScale))
			end
			local nsLabel = doc:GetElementById("noise-scale-label")
			if nsLabel then nsLabel.inner_rml = tostring(state.noiseScale) end

			local noiseSliderOctaves = doc:GetElementById("slider-noise-octaves")
			if noiseSliderOctaves and ds ~= "noise-octaves" then
				noiseSliderOctaves:SetAttribute("value", tostring(state.noiseOctaves))
			end
			local noLabel = doc:GetElementById("noise-octaves-label")
			if noLabel then noLabel.inner_rml = tostring(state.noiseOctaves) end

			local noiseSliderPersist = doc:GetElementById("slider-noise-persistence")
			if noiseSliderPersist and ds ~= "noise-persistence" then
				noiseSliderPersist:SetAttribute("value", tostring(math.floor(state.noisePersistence * 100 + 0.5)))
			end
			local npLabel = doc:GetElementById("noise-persistence-label")
			if npLabel then npLabel.inner_rml = string.format("%.2f", state.noisePersistence) end

			local noiseSliderLacun = doc:GetElementById("slider-noise-lacunarity")
			if noiseSliderLacun and ds ~= "noise-lacunarity" then
				noiseSliderLacun:SetAttribute("value", tostring(math.floor(state.noiseLacunarity * 10 + 0.5)))
			end
			local nlLabel = doc:GetElementById("noise-lacunarity-label")
			if nlLabel then nlLabel.inner_rml = string.format("%.1f", state.noiseLacunarity) end

			local noiseSliderSeed = doc:GetElementById("slider-noise-seed")
			if noiseSliderSeed and ds ~= "noise-seed" then
				noiseSliderSeed:SetAttribute("value", tostring(state.noiseSeed))
			end
			local seedLabel = doc:GetElementById("noise-seed-label")
			if seedLabel then seedLabel.inner_rml = tostring(state.noiseSeed) end

			uiState.updatingFromCode = false
		end

		-- Clear feature mode highlights
		local featuresBtn = doc and doc:GetElementById("btn-features")
		if featuresBtn then
			featuresBtn:SetClass("active", false)
		end
		-- Clear weather mode highlight
		local weatherBtn = doc and doc:GetElementById("btn-weather")
		if weatherBtn then
			weatherBtn:SetClass("active", false)
		end
		-- Clear splat mode highlight
		local splatBtn3 = doc and doc:GetElementById("btn-splat")
		if splatBtn3 then splatBtn3:SetClass("active", false) end
		-- Clear decals mode highlight
		local decalsBtn5 = doc and doc:GetElementById("btn-decals")
		if decalsBtn5 then decalsBtn5:SetClass("active", false) end
		-- Clear metal mode highlight
		local metalBtn5 = doc and doc:GetElementById("btn-metal")
		if metalBtn5 then metalBtn5:SetClass("active", false) end
		local grassBtn7 = doc and doc:GetElementById("btn-grass")
		if grassBtn7 then grassBtn7:SetClass("active", false) end

		-- Gray out unsupported shapes per mode
		local isRamp = state.mode == "ramp"
		local isLevel = state.mode == "level" or state.mode == "smooth"
		local rampDisabled = { triangle = true, hexagon = true, octagon = true, ring = true }
		for shape, element in pairs(widgetState.shapeButtons) do
			if element then
				local disabled = (isRamp and rampDisabled[shape]) or (isLevel and shape == "ring")
				element:SetClass("disabled", disabled or false)
			end
		end

		-- Import progress bar
		local importRow = doc and doc:GetElementById("import-progress-row")
		if importRow then
			if state.importProgress and state.importTotal and state.importTotal > 0 then
				importRow:SetClass("hidden", false)
				local pct = math.floor(state.importProgress / state.importTotal * 100)
				local fill = doc:GetElementById("import-progress-fill")
				if fill then fill:SetAttribute("style", "height: 6dp; width: " .. pct .. "%; background-color: #4a9eff; border-radius: 3dp;") end
				local label = doc:GetElementById("import-progress-label")
				if label then label.inner_rml = pct .. "%" end
			else
				importRow:SetClass("hidden", true)
			end
		end
	end
	-- Slider wheel-lock pulse animation
	do
		local ls = widgetState.lockedSliders
		if next(ls) then
			widgetState.sliderPulseTimer = widgetState.sliderPulseTimer + dt
			if widgetState.sliderPulseTimer >= 0.8 then
				widgetState.sliderPulseTimer = 0
				widgetState.sliderPulsePhase = not widgetState.sliderPulsePhase
				for _, element in pairs(ls) do
					element:SetClass("slider-pulse", widgetState.sliderPulsePhase)
				end
			end
		end
	end
	-- Full restore confirm timeout: auto-reset after 3 s if not confirmed
	if widgetState.fullRestoreConfirmExpiry > 0 then
		local now = Spring.GetGameSeconds() or 0
		if now >= widgetState.fullRestoreConfirmExpiry then
			widgetState.fullRestoreConfirmExpiry = 0
			local frBtn = widgetState.fullRestoreEl
			if frBtn then frBtn:SetClass("confirming", false) end
			if widgetState.fullRestoreLabel1 then widgetState.fullRestoreLabel1.inner_rml = "FULL" end
			if widgetState.fullRestoreLabel2 then widgetState.fullRestoreLabel2.inner_rml = "RESTORE" end
		end
	end
	-- Metal clean confirm timeout: auto-reset after 3 s if not confirmed
	if widgetState.metalCleanConfirmExpiry > 0 then
		local now = Spring.GetGameSeconds() or 0
		if now >= widgetState.metalCleanConfirmExpiry then
			widgetState.metalCleanConfirmExpiry = 0
			local cleanBtn = widgetState.metalCleanEl
			if cleanBtn then cleanBtn:SetClass("confirming", false) end
			local cleanLabel = widgetState.metalCleanLabel
			if cleanLabel then cleanLabel.inner_rml = "CLEAN" end
		end
	end
	-- Slider keybind-scroll flash countdown
	do
		local sf = widgetState.sliderFlashes
		if next(sf) then
			for id, flash in pairs(sf) do
				flash.timer = flash.timer - dt
				if flash.timer <= 0 then
					flash.el:SetClass("slider-flash", false)
					sf[id] = nil
				end
			end
		end
	end
	-- Override status summary when hovering the grass button on maps with no grass data.
	-- Done last so it beats any per-tool summary written above.
	if widgetState.grassHoverNoData and widgetState.grassNoDataThisMap then
		local sumEl2 = widgetState.document and widgetState.document:GetElementById("status-summary")
		if sumEl2 then
			local sep = '<span class="tf-ss-sep">|</span>'
			sumEl2.inner_rml = '<span class="tf-ss-mode tf-ss-pulse" style="color: #10b981;">GRASS</span>' .. sep .. '<span class="tf-ss-val tf-ss-pulse" style="color: #fbbf24;">No grass data for this map</span>'
		end
	end
	-- Reactive refresh of section warn chips after state sync
	if widgetState.warnRefreshFuncs then for i = 1, #widgetState.warnRefreshFuncs do widgetState.warnRefreshFuncs[i]() end end
	end) -- end pcall wrapper
	if not ok then
		Spring.Echo("[Terraform Brush UI] ERROR in Update: " .. tostring(err))
	end
end

function widget:RecvLuaMsg(message, playerID)
	local document = widgetState.document
	if not document then return end
	if message:sub(1, 19) == 'LobbyOverlayActive0' then
		document:Show()
	elseif message:sub(1, 19) == 'LobbyOverlayActive1' then
		document:Hide()
	end
end

function widget:MousePress(mx, my, button)
	-- Mouse button 4 = back, button 5 = forward (browser-style side buttons)
	if button == 4 or button == 5 then
		local anyActive = false
		for _, t in pairs(widgetState.transports) do
			if t.dir ~= 0 then anyActive = true; break end
		end
		if anyActive then
			local isBack = (button == 4)
			local utb = widgetState.updateTransportBtns
			for _, t in pairs(widgetState.transports) do
				if t.dir ~= 0 then
					if isBack then
						if t.dir == -1 then t.speed = math.min(4, t.speed + 1)
						else t.dir = -1; t.speed = 1 end
					else
						if t.dir == 1 then t.speed = math.min(4, t.speed + 1)
						else t.dir = 1; t.speed = 1 end
					end
					t.paused = false
					if utb then utb(t) end
				end
			end
			return true
		end
	end
	return false
end

function widget:MouseWheel(up, value)
	local ls = widgetState.lockedSliders
	if not next(ls) then return false end

	for id, element in pairs(ls) do
		local min = tonumber(element:GetAttribute("min")) or 0
		local max = tonumber(element:GetAttribute("max")) or 100
		local step = tonumber(element:GetAttribute("step")) or 1
		local cur = tonumber(element:GetAttribute("value")) or min
		-- Use 2% of range per tick, rounded to step, minimum 1 step
		local range = max - min
		local wheelStep = math.max(step, math.floor(range * 0.02 / step + 0.5) * step)
		local delta = up and wheelStep or -wheelStep
		local newVal = math.max(min, math.min(max, cur + delta))
		element:SetAttribute("value", tostring(newVal))
	end
	return true
end

function widget:KeyPress(key, mods, isRepeat)
	-- Suppress all keys while the keybind editor is capturing a key press
	if widgetState.settingsCapturing then
		handleSettingsKeyCapture(key)
		return true
	end
	-- Space (key 32): pause/resume all active transports
	if key == 32 then
		local anyActive = false
		for _, t in pairs(widgetState.transports) do
			if t.dir ~= 0 and not t.paused then anyActive = true; break end
		end
		if anyActive then
			for _, t in pairs(widgetState.transports) do
				if t.dir ~= 0 then
					t.paused = true
					if widgetState.updateTransportBtns then
						widgetState.updateTransportBtns(t)
					end
				end
			end
			return true
		else
			-- if everything is paused, unpause
			local anyPaused = false
			for _, t in pairs(widgetState.transports) do
				if t.dir ~= 0 and t.paused then anyPaused = true; break end
			end
			if anyPaused then
				for _, t in pairs(widgetState.transports) do
					if t.dir ~= 0 then
						t.paused = false
						if widgetState.updateTransportBtns then
							widgetState.updateTransportBtns(t)
						end
					end
				end
				return true
			end
		end
	end
	-- ESC (key code 27) clears all locked sliders
	if key == 27 then
		local ls = widgetState.lockedSliders
		if next(ls) then
			for id, element in pairs(ls) do
				element:SetClass("slider-locked", false)
				element:SetClass("slider-pulse", false)
			end
			widgetState.lockedSliders = {}
			widgetState.sliderLastClickTime = {}
			return true
		end
	end
	return false
end

function widget:Shutdown()
	WG.TerraformBrushUI = nil

	-- If a text input had focus when we shut down, SDL text-input mode is still
	-- active and will leak into the next session (causing key-event side-effects).
	if WG.TerraformBrushInputFocused then
		WG.TerraformBrushInputFocused = false
		Spring.SDLStopTextInput()
	end

	if widgetState.document then
		widgetState.document:Close()
		widgetState.document = nil
	end

	if widgetState.rmlContext then
		widgetState.rmlContext:RemoveDataModel(MODEL_NAME)
	end

	widgetState.dmHandle = nil
	widgetState.rootElement = nil
	widgetState.modeButtons = {}
	widgetState.shapeButtons = {}
	widgetState.fpSubmodesEl = nil
	widgetState.fpControlsEl = nil
	widgetState.tfControlsEl = nil
	widgetState.fpSubModeButtons = {}
	widgetState.fpDistButtons = {}
	widgetState.wbSubmodesEl = nil
	widgetState.wbControlsEl = nil
	widgetState.wbSubModeButtons = {}
	widgetState.wbDistButtons = {}
	widgetState.spControlsEl = nil
	widgetState.spPreviewEls = nil
	widgetState.spPreviewTextures = nil
	widgetState.spPreviewVerified = false
	if widgetState.spPreviewShader then
		gl.DeleteShader(widgetState.spPreviewShader)
		widgetState.spPreviewShader = nil
	end
	if widgetState.spMinimapSampleTex then
		gl.DeleteTexture(widgetState.spMinimapSampleTex)
		widgetState.spMinimapSampleTex = nil
	end
	widgetState.dcControlsEl = nil
	widgetState.dcSubmodesEl = nil
	widgetState.dcDistButtons = {}
	widgetState.mbSubmodesEl = nil
	widgetState.mbControlsEl = nil
	widgetState.mbSubModeButtons = {}
	widgetState.mbShapeButtons = {}
	widgetState.gbSubmodesEl = nil
	widgetState.gbControlsEl = nil
	widgetState.gbSubModeButtons = {}
	widgetState.gbShapeButtons = {}
	if WG.GrassBrush then WG.GrassBrush.deactivate() end
	widgetState.noiseRootEl = nil
	widgetState.noiseTypeButtons = {}
	widgetState.envControlsEl = nil
	widgetState.envActive = false
	widgetState.envSkyboxThumbs = {}
	widgetState.envCurrentSkybox = nil
	widgetState.envDefaultSkybox = nil
	widgetState.skyboxLibraryRootEl = nil
	widgetState.skyboxLibraryOpen = false
	widgetState.lightControlsEl = nil
	widgetState.lightActive = false
	widgetState.startposActive = false
	widgetState.stpSubmodesEl = nil
	widgetState.stpControlsEl = nil
	widgetState.stpSubModeButtons = {}
	widgetState.stpShapeButtons = {}
	widgetState.stpShapeOptionsEl = nil
	widgetState.stpShapeRowEl = nil
	widgetState.stpExpressHintEl = nil
	widgetState.stpStartboxHintEl = nil
	if WG.StartPosTool then WG.StartPosTool.deactivate() end
	widgetState.cloneActive = false
	widgetState.cloneControlsEl = nil
	widgetState.clonePasteTransformsEl = nil
	if WG.CloneTool then WG.CloneTool.deactivate() end
	widgetState.lightTypeButtons = {}
	widgetState.lightModeButtons = {}
	widgetState.lightDistButtons = {}
	widgetState.lightLibraryRootEl = nil
	widgetState.lightLibraryOpen = false
	widgetState.lightLibrarySelectedPreset = nil
	if WG.LightPlacer then WG.LightPlacer.deactivate() end

	-- Free pre-loaded skybox textures
	for _, texPath in ipairs(widgetState.envLoadedTextures or {}) do
		gl.DeleteTexture(texPath)
	end
	widgetState.envLoadedTextures = {}

	-- Restore sun lighting if shut down mid-fade
	if skyFade.active and skyFade.origUnitAmbient then
		Spring.SetSunLighting({
			unitAmbientColor    = skyFade.origUnitAmbient,
			unitDiffuseColor    = skyFade.origUnitDiffuse,
			unitSpecularColor   = skyFade.origUnitSpecular,
			groundAmbientColor  = skyFade.origGroundAmbient,
			groundDiffuseColor  = skyFade.origGroundDiffuse,
			groundSpecularColor = skyFade.origGroundSpecular,
		})
	end
	skyFade.active = false
	skyFade.phase = "idle"

	widgetHandler:RemoveAction("terraformpanel")
end
