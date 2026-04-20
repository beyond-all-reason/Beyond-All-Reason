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
local soundMuted = false

local function playSound(name)
	if soundMuted then return end
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

local updatingFromCode = false
local draggingSlider = nil  -- id of slider currently being dragged by user
local guideMode = false

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
local floatingTipEl = nil
local currentHint = nil
local noiseManuallyHidden = false
local lastNoiseActive = false
local skyboxLibraryOpen = false
local lastRenderedHint = nil

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
			updatingFromCode = true
			local function setSlLb(sl, lb, v)
				if sl then sl:SetAttribute("value", tostring(math.floor(v * 10000 + 0.5))) end
				if lb then lb.inner_rml = string.format("%.2f", v) end
			end
			setSlLb(skyDynamic.sunSliderX, skyDynamic.sunLabelX, sx)
			setSlLb(skyDynamic.sunSliderY, skyDynamic.sunLabelY, sy)
			setSlLb(skyDynamic.sunSliderZ, skyDynamic.sunLabelZ, sz)
			updatingFromCode = false
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
		if fpState and fpState.active then
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
			draggingSlider = id
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
		draggingSlider = id
	end, false)
	element:AddEventListener("mouseup", function() draggingSlider = nil end, false)
end

-- Helper: sync slider value from state and flash green if it changed externally
local function syncAndFlash(el, id, newValStr)
	if not el or not newValStr then return end
	if draggingSlider == id then return end
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
	["btn-decals"]              = "Open the Decals panel: decal library (scars, explosions, tracks, builds), export & analytics, and combat heatmap tools.",
	["btn-dc-export-all"]       = "Export ALL decals (GL4 + engine) as Lua table, CSV, stamp file, and features.lua.",
	["btn-dc-export-stamp"]     = "Export engine decals as a re-importable stamp file that recreates them on any map via Spring.CreateGroundDecal.",
	["btn-dc-export-features"]  = "Convert decal positions into a features.lua file — permanent map debris/craters for mappers.",
	["btn-dc-export-csv"]       = "Export decal snapshot as CSV for use in Python, GIS tools, or spreadsheets.",
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
	["slider-lp-modelfactor"]   = "How strongly the light affects 3D models. 0 = light ignores models, 1 = normal, higher = exaggerated.",
	["slider-lp-specular"]      = "Specular highlight intensity. Higher values create shinier, more reflective surfaces under the light.",
	["slider-lp-scattering"]    = "Atmospheric scattering amount. Higher values make the light more visible in fog and atmosphere.",
	["slider-lp-lensflare"]     = "Lens flare intensity when looking toward the light source. 0 = none, higher = more prominent flare.",
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
	if not floatingTipEl then return end
	-- G3 toast takes priority over the hover hint while it is still active
	local activeHint = currentHint
	local g3t = widgetState.g3Toast
	if guideMode and g3t.text then
		local now = Spring.GetGameSeconds()
		if now and now < g3t.expiry then
			activeHint = g3t.text
		else
			g3t.text = nil
			g3t.expiry = 0
		end
	end
	if not (guideMode and activeHint) then
		floatingTipEl:SetClass("hidden", true)
		lastRenderedHint = nil
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
	floatingTipEl:SetAttribute("style", string.format("left: %.2fvw; top: %.2fvh;",
		(leftPx / vsx) * 100, (topPx / vsy) * 100))
	if activeHint ~= lastRenderedHint then
		floatingTipEl.inner_rml = activeHint
		lastRenderedHint = activeHint
	end
	floatingTipEl:SetClass("hidden", false)
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

local function attachGuideMode(doc)
	floatingTipEl = doc:GetElementById("tf-guide-floating-tip")

	local guideBtnEl = doc:GetElementById("btn-guide")
	if guideBtnEl then
		guideBtnEl:AddEventListener("click", function(event)
			guideMode = not guideMode
			guideBtnEl:SetClass("active", guideMode)
			if not guideMode then
				currentHint = nil
				lastRenderedHint = nil
				if floatingTipEl then floatingTipEl.inner_rml = "" end
				widgetState.g3Toast.text   = nil
				widgetState.g3Toast.expiry = 0
			end
			event:StopPropagation()
		end, false)
	end

	local soundBtnEl = doc:GetElementById("btn-sound")
	if soundBtnEl then
		soundBtnEl:AddEventListener("click", function(event)
			soundMuted = not soundMuted
			soundBtnEl:SetClass("muted", soundMuted)
			event:StopPropagation()
		end, false)
	end

	do
		local ptBtn = doc:GetElementById("btn-passthrough")
		local ptIconPause = doc:GetElementById("passthrough-icon-pause")
		local ptIconPlay = doc:GetElementById("passthrough-icon-play")
		if ptBtn then
			ptBtn:AddEventListener("click", function(event)
				if not widgetState.passthroughMode then
					-- Enter passthrough: save current tool, deactivate everything
					local saved = nil
					local tfSt = WG.TerraformBrush and WG.TerraformBrush.getState()
					local fpSt = WG.FeaturePlacer and WG.FeaturePlacer.getState()
					local wbSt = WG.WeatherBrush and WG.WeatherBrush.getState()
					local spSt = WG.SplatPainter and WG.SplatPainter.getState()
					local mbSt = WG.MetalBrush and WG.MetalBrush.getState()
					local gbSt = WG.GrassBrush and WG.GrassBrush.getState()
					local lpSt = WG.LightPlacer and WG.LightPlacer.getState()
					local stSt = WG.StartPosTool and WG.StartPosTool.getState()
					local clSt = WG.CloneTool and WG.CloneTool.getState()
					if tfSt and tfSt.active then
						saved = { tool = "terraform", mode = tfSt.mode }
					elseif fpSt and fpSt.active then
						saved = { tool = "features", mode = fpSt.mode }
					elseif wbSt and wbSt.active then
						saved = { tool = "weather", mode = wbSt.mode }
					elseif spSt and spSt.active then
						saved = { tool = "splat" }
					elseif mbSt and mbSt.active then
						saved = { tool = "metal", mode = mbSt.subMode }
					elseif gbSt and gbSt.active then
						saved = { tool = "grass", mode = gbSt.subMode }
					elseif widgetState.envActive then
						saved = { tool = "environment" }
					elseif widgetState.lightActive and lpSt and lpSt.active then
						saved = { tool = "lights" }
					elseif widgetState.startposActive and stSt and stSt.active then
						saved = { tool = "startpos", mode = stSt.mode }
					elseif widgetState.cloneActive and clSt and clSt.active then
						saved = { tool = "clone" }
					end
					-- Deactivate all tools
					if WG.TerraformBrush then WG.TerraformBrush.deactivate() end
					if WG.FeaturePlacer then WG.FeaturePlacer.deactivate() end
					if WG.WeatherBrush then WG.WeatherBrush.deactivate() end
					if WG.SplatPainter then WG.SplatPainter.deactivate() end
					if WG.MetalBrush then WG.MetalBrush.deactivate() end
					if WG.GrassBrush then WG.GrassBrush.deactivate() end
					if WG.LightPlacer then WG.LightPlacer.deactivate() end
					if WG.StartPosTool then WG.StartPosTool.deactivate() end
					if WG.CloneTool then WG.CloneTool.deactivate() end
					widgetState.envActive = false
					widgetState.lightActive = false
					widgetState.startposActive = false
					widgetState.cloneActive = false
					widgetState.passthroughSaved = saved
					widgetState.passthroughMode = true
					ptBtn:SetClass("active", true)
					if ptIconPause then ptIconPause:SetClass("hidden", true) end
					if ptIconPlay then ptIconPlay:SetClass("hidden", false) end
					if widgetState.rootElement then
						widgetState.rootElement:SetClass("passthrough-dimmed", true)
					end
					playSound("modeSwitch")
				else
					-- Exit passthrough: restore saved tool
					widgetState.passthroughMode = false
					ptBtn:SetClass("active", false)
					if ptIconPause then ptIconPause:SetClass("hidden", false) end
					if ptIconPlay then ptIconPlay:SetClass("hidden", true) end
					if widgetState.rootElement then
						widgetState.rootElement:SetClass("passthrough-dimmed", false)
					end
					local s = widgetState.passthroughSaved
					widgetState.passthroughSaved = nil
					if s then
						if s.tool == "terraform" and WG.TerraformBrush then
							WG.TerraformBrush.setMode(s.mode or "raise")
						elseif s.tool == "features" and WG.FeaturePlacer then
							WG.FeaturePlacer.setMode(s.mode or "scatter")
						elseif s.tool == "weather" and WG.WeatherBrush then
							WG.WeatherBrush.setMode(s.mode or "place")
						elseif s.tool == "splat" and WG.SplatPainter then
							WG.SplatPainter.setMode("paint")
						elseif s.tool == "metal" and WG.MetalBrush then
							WG.MetalBrush.setMode(s.mode or "add")
						elseif s.tool == "grass" and WG.GrassBrush then
							WG.GrassBrush.setMode(s.mode or "add")
						elseif s.tool == "environment" then
							widgetState.envActive = true
						elseif s.tool == "lights" and WG.LightPlacer then
							widgetState.lightActive = true
							WG.LightPlacer.setMode("scatter")
						elseif s.tool == "startpos" and WG.StartPosTool then
							widgetState.startposActive = true
							WG.StartPosTool.setMode(s.mode or "express")
						elseif s.tool == "clone" and WG.CloneTool then
							widgetState.cloneActive = true
							WG.CloneTool.activate()
						end
					end
					playSound("modeSwitch")
				end
				event:StopPropagation()
			end, false)
		end
	end

	-- ============ Settings window (gear button) ============
	do
		widgetState.settingsRootEl = doc:GetElementById("tf-settings-root")
		local settingsBtn = doc:GetElementById("btn-settings")
		local settingsCloseBtn = doc:GetElementById("btn-settings-close")

		local function toggleSettings()
			widgetState.settingsOpen = not widgetState.settingsOpen
			if widgetState.settingsRootEl then
				widgetState.settingsRootEl:SetClass("hidden", not widgetState.settingsOpen)
			end
			if settingsBtn then
				settingsBtn:SetClass("active", widgetState.settingsOpen)
			end
			if widgetState.settingsOpen then
				-- Snapshot current keybinds for editing
				if WG.TerraformBrush and WG.TerraformBrush.getKeybinds then
					widgetState.settingsPendingBinds = WG.TerraformBrush.getKeybinds()
				end
				widgetState.settingsCapturing = nil
				widgetState.settingsCaptureField = nil
				widgetState.settingsCaptureEl = nil
				populateKeybindList(doc)
			end
		end

		if settingsBtn then
			settingsBtn:AddEventListener("click", function(event)
				toggleSettings()
				event:StopPropagation()
			end, false)
		end

		if settingsCloseBtn then
			settingsCloseBtn:AddEventListener("click", function(event)
				widgetState.settingsOpen = false
				widgetState.settingsCapturing = nil
				widgetState.settingsCaptureField = nil
				widgetState.settingsCaptureEl = nil
				if widgetState.settingsRootEl then
					widgetState.settingsRootEl:SetClass("hidden", true)
				end
				if settingsBtn then settingsBtn:SetClass("active", false) end
				event:StopPropagation()
			end, false)
		end

		-- Save button
		local kbSaveBtn = doc:GetElementById("btn-kb-save")
		if kbSaveBtn then
			kbSaveBtn:AddEventListener("click", function(event)
				if WG.TerraformBrush and widgetState.settingsPendingBinds then
					WG.TerraformBrush.applyKeybinds(widgetState.settingsPendingBinds)
					WG.TerraformBrush.saveKeybinds()
					updateAllKeybindBadges()
					Spring.Echo("[Terraform Brush] Keybinds saved.")
				end
				event:StopPropagation()
			end, false)
		end

		-- Apply button (apply without saving to disk)
		local kbApplyBtn = doc:GetElementById("btn-kb-apply")
		if kbApplyBtn then
			kbApplyBtn:AddEventListener("click", function(event)
				if WG.TerraformBrush and widgetState.settingsPendingBinds then
					WG.TerraformBrush.applyKeybinds(widgetState.settingsPendingBinds)
					updateAllKeybindBadges()
					Spring.Echo("[Terraform Brush] Keybinds applied.")
				end
				event:StopPropagation()
			end, false)
		end

		-- Restore Defaults button
		local kbDefaultsBtn = doc:GetElementById("btn-kb-defaults")
		if kbDefaultsBtn then
			kbDefaultsBtn:AddEventListener("click", function(event)
				if WG.TerraformBrush and WG.TerraformBrush.getDefaultKeybinds then
					widgetState.settingsPendingBinds = WG.TerraformBrush.getDefaultKeybinds()
					widgetState.settingsCapturing = nil
					widgetState.settingsCaptureField = nil
					widgetState.settingsCaptureEl = nil
					populateKeybindList(doc)
				end
				event:StopPropagation()
			end, false)
		end

		-- Cancel button
		local kbCancelBtn = doc:GetElementById("btn-kb-cancel")
		if kbCancelBtn then
			kbCancelBtn:AddEventListener("click", function(event)
				widgetState.settingsOpen = false
				widgetState.settingsCapturing = nil
				widgetState.settingsCaptureField = nil
				widgetState.settingsCaptureEl = nil
				widgetState.settingsPendingBinds = nil
				if widgetState.settingsRootEl then
					widgetState.settingsRootEl:SetClass("hidden", true)
				end
				if settingsBtn then settingsBtn:SetClass("active", false) end
				event:StopPropagation()
			end, false)
		end
	end

	-- ============ Settings: tab switching (Keybinds / DJ Mode / Stroke) ============
	do
		local tabKeybindsBtn = doc:GetElementById("btn-settings-tab-keybinds")
		local tabDJBtn       = doc:GetElementById("btn-settings-tab-dj")
		local tabStrokeBtn   = doc:GetElementById("btn-settings-tab-stroke")
		local tabKeybinds    = doc:GetElementById("settings-tab-keybinds")
		local tabDJ          = doc:GetElementById("settings-tab-dj")
		local tabStroke      = doc:GetElementById("settings-tab-stroke")

		local function switchSettingsTab(tab)
			if tabKeybindsBtn then tabKeybindsBtn:SetClass("active", tab == "keybinds") end
			if tabDJBtn       then tabDJBtn:SetClass("active", tab == "dj") end
			if tabStrokeBtn   then tabStrokeBtn:SetClass("active", tab == "stroke") end
			if tabKeybinds    then tabKeybinds:SetClass("hidden", tab ~= "keybinds") end
			if tabDJ          then tabDJ:SetClass("hidden", tab ~= "dj") end
			if tabStroke      then tabStroke:SetClass("hidden", tab ~= "stroke") end
		end

		if tabKeybindsBtn then
			tabKeybindsBtn:AddEventListener("click", function(event)
				switchSettingsTab("keybinds")
				event:StopPropagation()
			end, false)
		end
		if tabDJBtn then
			tabDJBtn:AddEventListener("click", function(event)
				switchSettingsTab("dj")
				event:StopPropagation()
			end, false)
		end
		if tabStrokeBtn then
			tabStrokeBtn:AddEventListener("click", function(event)
				switchSettingsTab("stroke")
				event:StopPropagation()
			end, false)
		end
	end

	-- ============ DJ Mode: Master Activate Toggle ============
	do
		local activateBtn = doc:GetElementById("btn-dj-activate")
		if activateBtn then
			activateBtn:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					local newVal = not (state and state.djMode)
					playSound(newVal and "toggleOn" or "toggleOff")
					WG.TerraformBrush.setDjMode(newVal)
					activateBtn:SetClass("active", newVal)
					local pill = doc:GetElementById("pill-dj-activate")
					if pill then pill.inner_rml = newVal and "ON" or "OFF" end
					local subSettings = doc:GetElementById("dj-sub-settings")
					if subSettings then subSettings:SetClass("dj-disabled", not newVal) end
				end
				event:StopPropagation()
			end, false)
		end
	end

	-- ============ DJ Mode: Dust Visual Effects ============
	do
		local dustBtn = doc:GetElementById("btn-dust-effects")
		if dustBtn then
			dustBtn:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					local newVal = not (state and state.dustEffects)
					playSound(newVal and "toggleOn" or "toggleOff")
					WG.TerraformBrush.setDustEffects(newVal)
					dustBtn:SetClass("active", newVal)
					local pill = doc:GetElementById("pill-dust-effects")
					if pill then pill.inner_rml = newVal and "ON" or "OFF" end
				end
				event:StopPropagation()
			end, false)
		end
	end

	-- ============ DJ Mode: Seismic Sound Effects ============
	do
		local seismicBtn = doc:GetElementById("btn-seismic-effects")
		if seismicBtn then
			seismicBtn:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					local newVal = not (state and state.seismicEffects)
					playSound(newVal and "toggleOn" or "toggleOff")
					WG.TerraformBrush.setSeismicEffects(newVal)
					seismicBtn:SetClass("active", newVal)
					local pill = doc:GetElementById("pill-seismic-effects")
					if pill then pill.inner_rml = newVal and "ON" or "OFF" end
				end
				event:StopPropagation()
			end, false)
		end
	end

	-- ============ Stroke: Pen Pressure ============
	do
		local penToggleBtn = doc:GetElementById("btn-pen-pressure-toggle")
		local penSub = doc:GetElementById("pen-pressure-sub")
		if penToggleBtn then
			penToggleBtn:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					local newVal = not (state and state.penPressureEnabled)
					playSound(newVal and "toggleOn" or "toggleOff")
					WG.TerraformBrush.setPenPressure(newVal)
					penToggleBtn:SetClass("active", newVal)
					local pill = doc:GetElementById("pill-pen-pressure")
					if pill then pill.inner_rml = newVal and "ON" or "OFF" end
					if penSub then penSub:SetClass("dj-disabled", not newVal) end
				end
				event:StopPropagation()
			end, false)
		end
		local modIntBtn = doc:GetElementById("btn-pen-mod-intensity")
		if modIntBtn then
			modIntBtn:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					local newVal = not (state and state.penPressureModulateIntensity)
					WG.TerraformBrush.setPenPressureModulateIntensity(newVal)
					modIntBtn:SetAttribute("src", newVal and "/luaui/images/terraform_brush/check_on.png" or "/luaui/images/terraform_brush/check_off.png")
				end
				event:StopPropagation()
			end, false)
		end
		local modSizeBtn = doc:GetElementById("btn-pen-mod-size")
		if modSizeBtn then
			modSizeBtn:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					local newVal = not (state and state.penPressureModulateSize)
					WG.TerraformBrush.setPenPressureModulateSize(newVal)
					modSizeBtn:SetAttribute("src", newVal and "/luaui/images/terraform_brush/check_on.png" or "/luaui/images/terraform_brush/check_off.png")
				end
				event:StopPropagation()
			end, false)
		end
		local sensSlider = doc:GetElementById("slider-pen-sensitivity")
		if sensSlider then
			sensSlider:AddEventListener("change", function(event)
				if updatingFromCode then return end
				if WG.TerraformBrush then
					local val = tonumber(sensSlider:GetAttribute("value")) or 100
					WG.TerraformBrush.setPenPressureSensitivity(val / 100)
					local lbl = doc:GetElementById("pen-sensitivity-label")
					if lbl then lbl.inner_rml = tostring(math.floor(val)) end
				end
			end, false)
		end
		local curveIds = {
			["btn-curve-linear"] = 1, ["btn-curve-quad"] = 2, ["btn-curve-cubic"] = 3,
			["btn-curve-scurve"] = 4, ["btn-curve-log"] = 5,
		}
		for id, curveVal in pairs(curveIds) do
			local btn = doc:GetElementById(id)
			if btn then
				btn:AddEventListener("click", function(event)
					if WG.TerraformBrush then
						WG.TerraformBrush.setPenPressureCurve(curveVal)
						for cid, _ in pairs(curveIds) do
							local el = doc:GetElementById(cid)
							if el then el:SetClass("active", cid == id) end
						end
					end
					event:StopPropagation()
				end, false)
			end
		end
	end

	-- ============ Stroke: Brush Wiggle ============
	do
		local wiggleBtn = doc:GetElementById("btn-wiggle-toggle")
		local wiggleSub = doc:GetElementById("wiggle-sub")
		local function refreshWiggleChips(ampIdx, spdIdx)
			for i = 1, 4 do
				local a = doc:GetElementById("btn-wiggle-amp-" .. i)
				local s = doc:GetElementById("btn-wiggle-spd-" .. i)
				if a then a:SetClass("active", i == ampIdx) end
				if s then s:SetClass("active", i == spdIdx) end
			end
		end
		if wiggleBtn then
			wiggleBtn:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					local newVal = not (state and state.wiggleEnabled)
					playSound(newVal and "toggleOn" or "toggleOff")
					WG.TerraformBrush.setWiggle(newVal, state and state.wiggleAmpIdx or 1, state and state.wiggleSpdIdx or 1)
					wiggleBtn:SetClass("active", newVal)
					local pill = doc:GetElementById("pill-wiggle-toggle")
					if pill then pill.inner_rml = newVal and "ON" or "OFF" end
					if wiggleSub then wiggleSub:SetClass("dj-disabled", not newVal) end
				end
				event:StopPropagation()
			end, false)
		end
		for i = 1, 4 do
			local aBtn = doc:GetElementById("btn-wiggle-amp-" .. i)
			if aBtn then
				aBtn:AddEventListener("click", function(event)
					if WG.TerraformBrush then
						local state = WG.TerraformBrush.getState()
						WG.TerraformBrush.setWiggle(state and state.wiggleEnabled, i, state and state.wiggleSpdIdx or 1)
						refreshWiggleChips(i, state and state.wiggleSpdIdx or 1)
					end
					event:StopPropagation()
				end, false)
			end
			local sBtn = doc:GetElementById("btn-wiggle-spd-" .. i)
			if sBtn then
				sBtn:AddEventListener("click", function(event)
					if WG.TerraformBrush then
						local state = WG.TerraformBrush.getState()
						WG.TerraformBrush.setWiggle(state and state.wiggleEnabled, state and state.wiggleAmpIdx or 1, i)
						refreshWiggleChips(state and state.wiggleAmpIdx or 1, i)
					end
					event:StopPropagation()
				end, false)
			end
		end
	end

	for elemId, hint in pairs(guideHints) do
		local el = doc:GetElementById(elemId)
		if el then
			el:AddEventListener("mouseover", function(event)
				if guideMode then currentHint = hint end
			end, false)
			el:AddEventListener("mouseout", function(event)
				if guideMode then currentHint = nil end
			end, false)
		end
	end

	-- G3: Shortcut discovery tips — fire near cursor after 3 interactions (guide mode only)
	for elemId, group in pairs(g3ElemGroup) do
		local el = doc:GetElementById(elemId)
		if el then
			el:AddEventListener("mousedown", function(event)
				if not guideMode then return end
				local cnt = (widgetState.g3GroupCounts[group] or 0) + 1
				widgetState.g3GroupCounts[group] = cnt
				if cnt >= 3 and not widgetState.g3GroupShown[group] then
					widgetState.g3GroupShown[group] = true
					widgetState.g3Toast.text   = g3TipGroups[group]
					widgetState.g3Toast.expiry = (Spring.GetGameSeconds() or 0) + 5
				end
			end, false)
		end
	end
end

local function attachEnvironmentListeners(doc)
	-- Capture map defaults at startup
	local sunX, sunY, sunZ = gl.GetSun("pos")
	sunX, sunY, sunZ = sunX or 0, sunY or 1, sunZ or 0
	local gaR, gaG, gaB = gl.GetSun("ambient")
	gaR, gaG, gaB = gaR or 0, gaG or 0, gaB or 0
	local gdR, gdG, gdB = gl.GetSun("diffuse")
	gdR, gdG, gdB = gdR or 0, gdG or 0, gdB or 0
	local gsR, gsG, gsB = gl.GetSun("specular")
	gsR, gsG, gsB = gsR or 0, gsG or 0, gsB or 0
	local uaR, uaG, uaB = gl.GetSun("ambient", "unit")
	uaR, uaG, uaB = uaR or 0, uaG or 0, uaB or 0
	local udR, udG, udB = gl.GetSun("diffuse", "unit")
	udR, udG, udB = udR or 0, udG or 0, udB or 0
	local usR, usG, usB = gl.GetSun("specular", "unit")
	usR, usG, usB = usR or 0, usG or 0, usB or 0
	local fogS = gl.GetAtmosphere("fogStart")
	local fogE = gl.GetAtmosphere("fogEnd")
	local fR, fG, fB, fA = gl.GetAtmosphere("fogColor")
	local scR, scG, scB = gl.GetAtmosphere("sunColor")
	local skR, skG, skB = gl.GetAtmosphere("skyColor")
	local saX, saY, saZ, saAngle = gl.GetAtmosphere("skyAxisAngle")
	local gsd = gl.GetSun("shadowDensity", "ground") or 0
	local usd = gl.GetSun("shadowDensity", "unit") or 0

	widgetState.envDefaults = {
		sunPos = { sunX, sunY, sunZ },
		groundAmbient = { gaR, gaG, gaB },
		groundDiffuse = { gdR, gdG, gdB },
		groundSpecular = { gsR, gsG, gsB },
		unitAmbient = { uaR, uaG, uaB },
		unitDiffuse = { udR, udG, udB },
		unitSpecular = { usR, usG, usB },
		fogStart = fogS,
		fogEnd = fogE,
		fogColor = { fR, fG, fB, fA },
		sunColor = { scR, scG, scB },
		skyColor = { skR, skG, skB },
		skyAxisAngle = { saX, saY, saZ, saAngle },
		groundShadowDensity = gsd,
		unitShadowDensity = usd,
		cloudColor = { gl.GetAtmosphere("cloudColor") },
		sunIntensity = 1.0,
		waterAbsorb = { gl.GetWaterRendering("absorb") },
		waterBaseColor = { gl.GetWaterRendering("baseColor") },
		waterMinColor = { gl.GetWaterRendering("minColor") },
		waterSurfaceColor = { gl.GetWaterRendering("surfaceColor") },
		waterPlaneColor = { gl.GetWaterRendering("planeColor") },
		waterDiffuseColor = { gl.GetWaterRendering("diffuseColor") },
		waterSpecularColor = { gl.GetWaterRendering("specularColor") },
	}

	-- Grab floating window root elements
	widgetState.envSunRootEl = doc:GetElementById("tf-env-sun-root")
	widgetState.envFogRootEl = doc:GetElementById("tf-env-fog-root")
	widgetState.envGroundLightingRootEl = doc:GetElementById("tf-env-ground-lighting-root")
	widgetState.envUnitLightingRootEl = doc:GetElementById("tf-env-unit-lighting-root")
	widgetState.envMapRootEl = doc:GetElementById("tf-env-map-root")
	widgetState.envWaterRootEl = doc:GetElementById("tf-env-water-root")
	widgetState.envDimensionsRootEl = doc:GetElementById("tf-env-dimensions-root")
	widgetState.splatTexRootEl = doc:GetElementById("tf-splattex-root")

	-- Helper: wire a slider that maps integer range to float values
	local function envSlider(sliderId, labelId, toFloat, fromFloat, onChange)
		local sl = doc:GetElementById(sliderId)
		local lb = doc:GetElementById(labelId)
		if not sl then return end
		trackSliderDrag(sl, sliderId)
		sl:AddEventListener("change", function(event)
			if updatingFromCode then return end
			local raw = tonumber(sl:GetAttribute("value")) or 0
			local val = toFloat(raw)
			if lb then lb.inner_rml = string.format("%.2f", val) end
			onChange(val)
			event:StopPropagation()
		end, false)
		-- Set initial value
		local initVal = fromFloat()
		sl:SetAttribute("value", tostring(math.floor(initVal + 0.5)))
		if lb then lb.inner_rml = string.format("%.2f", toFloat(math.floor(initVal + 0.5))) end
	end

	-- Helper: set slider + label from code
	local function envSetSlider(sliderId, labelId, intVal, displayVal)
		local sl = doc:GetElementById(sliderId)
		local lb = doc:GetElementById(labelId)
		if sl then sl:SetAttribute("value", tostring(intVal)) end
		if lb then lb.inner_rml = displayVal end
	end

	-- Helper: update a preview box's background-color from RGB (0-1 range)
	local function updatePreview(previewEl, r, g, b)
		if not previewEl then return end
		local ri = math.floor(math.min(math.max(r or 0, 0), 1) * 255 + 0.5)
		local gi = math.floor(math.min(math.max(g or 0, 0), 1) * 255 + 0.5)
		local bi = math.floor(math.min(math.max(b or 0, 0), 1) * 255 + 0.5)
		previewEl:SetAttribute("style", string.format("background-color: rgb(%d, %d, %d);", ri, gi, bi))
	end

	-- Helper: wire palette swatches + color preview for a color group
	-- cfg = { paletteId, previewId, sliderPrefix, channels, getColor, setColor }
	local function wireColorGroup(cfg)
		local previewEl = doc:GetElementById(cfg.previewId)
		local paletteEl = cfg.paletteId and doc:GetElementById(cfg.paletteId)
		local channels = cfg.channels or {"r", "g", "b"}
		local function refreshPreview()
			local c = cfg.getColor()
			updatePreview(previewEl, c[1], c[2], c[3])
		end
		for _, s in ipairs(channels) do
			local sl = doc:GetElementById("slider-env-" .. cfg.sliderPrefix .. "-" .. s)
			if sl then sl:AddEventListener("change", function() refreshPreview() end, false) end
		end
		if paletteEl then
			local idx = 0
			while true do
				local swatch = paletteEl:GetChild(idx)
				if not swatch then break end
				local style = swatch:GetAttribute("style") or ""
				local hex = style:match("#(%x%x%x%x%x%x)")
				if hex then
					local hr = tonumber(hex:sub(1, 2), 16) / 255
					local hg = tonumber(hex:sub(3, 4), 16) / 255
					local hb = tonumber(hex:sub(5, 6), 16) / 255
					swatch:AddEventListener("click", function(event)
						cfg.setColor({ hr, hg, hb })
						envSetSlider("slider-env-" .. cfg.sliderPrefix .. "-r", "lbl-env-" .. cfg.sliderPrefix .. "-r",
							math.floor(hr * 1000 + 0.5), string.format("%.2f", hr))
						envSetSlider("slider-env-" .. cfg.sliderPrefix .. "-g", "lbl-env-" .. cfg.sliderPrefix .. "-g",
							math.floor(hg * 1000 + 0.5), string.format("%.2f", hg))
						envSetSlider("slider-env-" .. cfg.sliderPrefix .. "-b", "lbl-env-" .. cfg.sliderPrefix .. "-b",
							math.floor(hb * 1000 + 0.5), string.format("%.2f", hb))
						refreshPreview()
						event:StopPropagation()
					end, false)
				end
				idx = idx + 1
			end
		end
		refreshPreview()
	end

	-- Helper: wire a checkbox toggle
	local function envCheckbox(btnId, initVal, onChange)
		local btn = doc:GetElementById(btnId)
		if not btn then return end
		local state = initVal
		btn:SetAttribute("src", state
			and "/luaui/images/terraform_brush/check_on.png"
			or  "/luaui/images/terraform_brush/check_off.png")
		btn:AddEventListener("click", function(event)
			state = not state
			btn:SetAttribute("src", state
				and "/luaui/images/terraform_brush/check_on.png"
				or  "/luaui/images/terraform_brush/check_off.png")
			onChange(state)
			event:StopPropagation()
		end, false)
	end

	-- Helper: wire a window toggle button + close button
	local function envWindowToggle(openBtnId, closeBtnId, rootEl, stateKey)
		local openBtn = doc:GetElementById(openBtnId)
		if openBtn then
			openBtn:AddEventListener("click", function(event)
				widgetState[stateKey] = not widgetState[stateKey]
				playSound(widgetState[stateKey] and "panelOpen" or "click")
				if rootEl then rootEl:SetClass("hidden", not widgetState[stateKey]) end
				openBtn:SetClass("env-open", widgetState[stateKey] == true)
				event:StopPropagation()
			end, false)
		end
		local closeBtn = doc:GetElementById(closeBtnId)
		if closeBtn then
			closeBtn:AddEventListener("click", function(event)
				playSound("click")
				widgetState[stateKey] = false
				if rootEl then rootEl:SetClass("hidden", true) end
				if openBtn then openBtn:SetClass("env-open", false) end
				event:StopPropagation()
			end, false)
		end
	end

	-- Wire toggle/close for each sub-window
	envWindowToggle("btn-env-sun-shadows", "btn-env-sun-close", widgetState.envSunRootEl, "envSunOpen")
	envWindowToggle("btn-env-fog-atmo", "btn-env-fog-close", widgetState.envFogRootEl, "envFogOpen")
	envWindowToggle("btn-env-ground-lighting", "btn-env-ground-lighting-close", widgetState.envGroundLightingRootEl, "envGroundLightingOpen")
	envWindowToggle("btn-env-unit-lighting", "btn-env-unit-lighting-close", widgetState.envUnitLightingRootEl, "envUnitLightingOpen")
	envWindowToggle("btn-env-map-render", "btn-env-map-close", widgetState.envMapRootEl, "envMapOpen")
	envWindowToggle("btn-env-water", "btn-env-water-close", widgetState.envWaterRootEl, "envWaterOpen")
	envWindowToggle("btn-env-dimensions", "btn-env-dimensions-close", widgetState.envDimensionsRootEl, "envDimensionsOpen")
	envWindowToggle("btn-sp-splattex", "btn-splattex-close", widgetState.splatTexRootEl, "splatTexOpen")

	-- Helper: wire a collapsible section toggle (click header row to expand/collapse)
	-- Returns a ctrl table with an expand() method for programmatic expansion.
	local function envSectionToggle(toggleBtnId, toggleImgId, sectionId, defaultExpanded)
		local toggleBtn = doc:GetElementById(toggleBtnId)
		local toggleImg = doc:GetElementById(toggleImgId)
		local section = doc:GetElementById(sectionId)
		if not toggleBtn or not toggleImg or not section then return {} end
		local expanded = defaultExpanded
		section:SetClass("hidden", not expanded)
		toggleImg:SetAttribute("src", expanded
			and "/luaui/images/terraform_brush/minus.png"
			or  "/luaui/images/terraform_brush/plus.png")
		toggleBtn:AddEventListener("click", function(event)
			expanded = not expanded
			playSound(expanded and "panelOpen" or "click")
			section:SetClass("hidden", not expanded)
			toggleImg:SetAttribute("src", expanded
				and "/luaui/images/terraform_brush/minus.png"
				or  "/luaui/images/terraform_brush/plus.png")
			event:StopPropagation()
		end, false)
		return {
			expand = function()
				if not expanded then
					expanded = true
					playSound("panelOpen")
					section:SetClass("hidden", false)
					toggleImg:SetAttribute("src", "/luaui/images/terraform_brush/minus.png")
				end
			end,
		}
	end

	-- Terrain panel collapsible sections (default collapsed)
	envSectionToggle("btn-toggle-terrain",  "img-toggle-terrain",  "section-terrain",  true)
	envSectionToggle("btn-toggle-tools",    "img-toggle-tools",    "section-tools",    true)
	envSectionToggle("btn-toggle-shape",    "img-toggle-shape",    "section-shape",    true)
	envSectionToggle("btn-toggle-sliders",  "img-toggle-sliders",  "section-sliders",  true)
	widgetState.heightCapSectionCtrl = envSectionToggle("btn-toggle-heightcap", "img-toggle-heightcap", "section-heightcap", false)
	envSectionToggle("btn-toggle-presets",   "img-toggle-presets",   "section-presets",   false)

	-- Tool sub-panel collapsible sections
	envSectionToggle("btn-toggle-sp-mode",      "img-toggle-sp-mode",      "section-sp-mode",      true)
	envSectionToggle("btn-toggle-mb-mode",      "img-toggle-mb-mode",      "section-mb-mode",      true)
	envSectionToggle("btn-toggle-mb-undo",      "img-toggle-mb-undo",      "section-mb-undo",      false)
	envSectionToggle("btn-toggle-gb-mode",      "img-toggle-gb-mode",      "section-gb-mode",      true)
	envSectionToggle("btn-toggle-gb-shape",     "img-toggle-gb-shape",     "section-gb-shape",     true)
	envSectionToggle("btn-toggle-gb-undo",      "img-toggle-gb-undo",      "section-gb-undo",      false)
	envSectionToggle("btn-toggle-fp-mode",      "img-toggle-fp-mode",      "section-fp-mode",      true)
	envSectionToggle("btn-toggle-smooth-mode",  "img-toggle-smooth-mode",  "section-smooth-mode",  true)
	envSectionToggle("btn-toggle-fp-undo",      "img-toggle-fp-undo",      "section-fp-undo",      false)
	envSectionToggle("btn-toggle-fp-dist",      "img-toggle-fp-dist",      "section-fp-dist",      true)
	envSectionToggle("btn-toggle-fp-save",      "img-toggle-fp-save",      "section-fp-save",      false)
	envSectionToggle("btn-toggle-ramp-type",    "img-toggle-ramp-type",    "section-ramp-type",    true)
	envSectionToggle("btn-toggle-wb-mode",      "img-toggle-wb-mode",      "section-wb-mode",      true)
	envSectionToggle("btn-toggle-wb-dist",      "img-toggle-wb-dist",      "section-wb-dist",      true)
	envSectionToggle("btn-toggle-cl-undo",      "img-toggle-cl-undo",      "section-cl-undo",      false)
	envSectionToggle("btn-toggle-tf-undo",      "img-toggle-tf-undo",      "section-tf-undo",      false)
	envSectionToggle("btn-toggle-spl-channel",  "img-toggle-spl-channel",  "section-spl-channel",  true)
	envSectionToggle("btn-toggle-dc-export",    "img-toggle-dc-export",    "section-dc-export",    false)
	envSectionToggle("btn-toggle-dc-heatmap",   "img-toggle-dc-heatmap",   "section-dc-heatmap",   false)
	envSectionToggle("btn-toggle-dc-library",   "img-toggle-dc-library",   "section-dc-library",   true)
	envSectionToggle("btn-toggle-dc-dist",      "img-toggle-dc-dist",      "section-dc-dist",      true)
	envSectionToggle("btn-toggle-dc-mode",      "img-toggle-dc-mode",      "section-dc-mode",      true)
	envSectionToggle("btn-toggle-dc-undo",      "img-toggle-dc-undo",      "section-dc-undo",      false)

	-- New: DISPLAY / INSTRUMENTS / CONTROLS collapsible wrappers per panel
	envSectionToggle("btn-toggle-mb-overlays",     "img-toggle-mb-overlays",     "section-mb-overlays",     false)
	envSectionToggle("btn-toggle-mb-instruments",  "img-toggle-mb-instruments",  "section-mb-instruments",  false)
	envSectionToggle("btn-toggle-mb-controls",     "img-toggle-mb-controls",     "section-mb-controls",     true)
	envSectionToggle("btn-toggle-gb-overlays",     "img-toggle-gb-overlays",     "section-gb-overlays",     false)
	envSectionToggle("btn-toggle-gb-instruments",  "img-toggle-gb-instruments",  "section-gb-instruments",  false)
	envSectionToggle("btn-toggle-gb-controls",     "img-toggle-gb-controls",     "section-gb-controls",     true)
	envSectionToggle("btn-toggle-fp-overlays",     "img-toggle-fp-overlays",     "section-fp-overlays",     false)
	envSectionToggle("btn-toggle-fp-instruments",  "img-toggle-fp-instruments",  "section-fp-instruments",  false)
	envSectionToggle("btn-toggle-fp-controls",     "img-toggle-fp-controls",     "section-fp-controls",     true)
	envSectionToggle("btn-toggle-fp-smart",        "img-toggle-fp-smart",        "section-fp-smart",        false)
	envSectionToggle("btn-toggle-gb-smart",        "img-toggle-gb-smart",        "section-gb-smart",        false)

	-- Pill-button tab switching for smart filter sub-panels
	do
		-- Independent toggle pills for feature placer (both can be active)
		local function wireIndependentPills(pills, onActivate)
			for _, p in ipairs(pills) do
				local btn = doc:GetElementById(p.btnId)
				local content = doc:GetElementById(p.contentId)
				if btn and content then
					btn:AddEventListener("click", function()
						local isActive = btn:IsClassSet("active")
						btn:SetClass("active", not isActive)
						content:SetClass("hidden", isActive)
						if not isActive and onActivate then onActivate() end
					end)
				end
			end
		end
		wireIndependentPills({
			{ btnId = "fp-filter-chip-slope",    contentId = "fp-smart-slope-content" },
			{ btnId = "fp-filter-chip-altitude",  contentId = "fp-smart-altitude-content" },
		}, function()
			if WG.FeaturePlacer then WG.FeaturePlacer.setSmartEnabled(true) end
		end)

		-- Exclusive tab pills for grass brush (original behavior)
		local function wirePillTabs(pills, onActivate)
			for _, p in ipairs(pills) do
				local btn = doc:GetElementById(p.btnId)
				local content = doc:GetElementById(p.contentId)
				if btn and content then
					btn:AddEventListener("click", function()
						for _, q in ipairs(pills) do
							local b2 = doc:GetElementById(q.btnId)
							local c2 = doc:GetElementById(q.contentId)
							if b2 then b2:SetClass("active", b2 == btn) end
							if c2 then c2:SetClass("hidden", c2 ~= content) end
						end
						content:SetClass("hidden", false)
						btn:SetClass("active", true)
						if onActivate then onActivate() end
					end)
				end
			end
		end
		wirePillTabs({
			{ btnId = "btn-gb-pill-slope",    contentId = "gb-smart-slope-content" },
			{ btnId = "btn-gb-pill-altitude",  contentId = "gb-smart-altitude-content" },
			{ btnId = "btn-gb-pill-color",     contentId = "gb-smart-color-content" },
		})
	end
	envSectionToggle("btn-toggle-wb-undo",         "img-toggle-wb-undo",         "section-wb-undo",         false)
	envSectionToggle("btn-toggle-wb-overlays",     "img-toggle-wb-overlays",     "section-wb-overlays",     false)
	envSectionToggle("btn-toggle-wb-instruments",  "img-toggle-wb-instruments",  "section-wb-instruments",  false)
	envSectionToggle("btn-toggle-wb-controls",     "img-toggle-wb-controls",     "section-wb-controls",     true)
	envSectionToggle("btn-toggle-sp-undo",         "img-toggle-sp-undo",         "section-sp-undo",         false)
	envSectionToggle("btn-toggle-sp-overlays",     "img-toggle-sp-overlays",     "section-sp-overlays",     false)
	envSectionToggle("btn-toggle-sp-instruments",  "img-toggle-sp-instruments",  "section-sp-instruments",  false)
	envSectionToggle("btn-toggle-sp-controls",     "img-toggle-sp-controls",     "section-sp-controls",     true)
	envSectionToggle("btn-toggle-dc-overlays",     "img-toggle-dc-overlays",     "section-dc-overlays",     false)
	envSectionToggle("btn-toggle-dc-instruments",  "img-toggle-dc-instruments",  "section-dc-instruments",  false)
	envSectionToggle("btn-toggle-dc-controls",     "img-toggle-dc-controls",     "section-dc-controls",     true)
	envSectionToggle("btn-toggle-lp-overlays",     "img-toggle-lp-overlays",     "section-lp-overlays",     false)
	envSectionToggle("btn-toggle-lp-instruments",  "img-toggle-lp-instruments",  "section-lp-instruments",  false)
	envSectionToggle("btn-toggle-lp-controls",     "img-toggle-lp-controls",     "section-lp-controls",     true)
	envSectionToggle("btn-toggle-env-buttons",  "img-toggle-env-buttons",  "section-env-buttons",  true)
	envSectionToggle("btn-toggle-lt-type",      "img-toggle-lt-type",      "section-lt-type",      true)
	envSectionToggle("btn-toggle-lt-placement", "img-toggle-lt-placement", "section-lt-placement", true)
	envSectionToggle("btn-toggle-lt-dist",      "img-toggle-lt-dist",      "section-lt-dist",      true)
	envSectionToggle("btn-toggle-lp-color",     "img-toggle-lp-color",     "section-lp-color",     true)
	envSectionToggle("btn-toggle-lp-undo",      "img-toggle-lp-undo",      "section-lp-undo",      false)
	envSectionToggle("btn-toggle-noise-type",   "img-toggle-noise-type",   "section-noise-type",   true)

	-- Parameter chip toggles — toggle individual slider row visibility
	-- Uses table field instead of local function to avoid the 200-local limit
	widgetState.chipToggle = function(chipId, rowId, defaultVis)
		local chip = doc:GetElementById(chipId)
		local row  = doc:GetElementById(rowId)
		if not chip or not row then return end
		local visible = defaultVis ~= false
		chip:SetClass("active", visible)
		row:SetClass("hidden", not visible)
		chip:AddEventListener("click", function(event)
			visible = not visible
			chip:SetClass("active", visible)
			row:SetClass("hidden", not visible)
			playSound(visible and "panelOpen" or "click")
			event:StopPropagation()
		end, false)
	end
	widgetState.chipToggle("param-chip-rotation",  "param-rotation-row",  true)
	widgetState.chipToggle("param-chip-intensity", "param-intensity-row", true)
	widgetState.chipToggle("param-chip-size",      "param-size-row",      true)
	widgetState.chipToggle("param-chip-length",    "param-length-row",    true)
	widgetState.chipToggle("param-chip-falloff",   "param-falloff-row",   true)

	-- Feature placer control pill toggles
	widgetState.chipToggle("fp-param-chip-size",      "fp-param-size-row",      true)
	widgetState.chipToggle("fp-param-chip-rotation",  "fp-param-rotation-row",  true)
	widgetState.chipToggle("fp-param-chip-alignment", "fp-param-alignment-row", true)
	widgetState.chipToggle("fp-param-chip-count",     "fp-param-count-row",     true)
	widgetState.chipToggle("fp-param-chip-rate",      "fp-param-rate-row",      true)

	-- Collapsible toggle with warning chip: shown when collapsed but any listed chip is active.
	-- Uses table field to avoid the 200-local chunk limit.
	widgetState.warningToggle = function(toggleId, imgId, sectionId, warnId, activeIds, defaultExpanded)
		local toggleBtn = doc:GetElementById(toggleId)
		local toggleImg = doc:GetElementById(imgId)
		local section   = doc:GetElementById(sectionId)
		local warnChip  = doc:GetElementById(warnId)
		if not toggleBtn or not toggleImg or not section or not warnChip then return end
		local expanded = defaultExpanded ~= false
		local function refreshWarn()
			if expanded then warnChip:SetClass("hidden", true); return end
			local anyActive = false
			for i = 1, #activeIds do
				local chip = doc:GetElementById(activeIds[i])
				if chip and chip.class_name and chip.class_name:find("active") then anyActive = true; break end
			end
			warnChip:SetClass("hidden", not anyActive)
		end
		if not widgetState.warnRefreshFuncs then widgetState.warnRefreshFuncs = {} end
		widgetState.warnRefreshFuncs[#widgetState.warnRefreshFuncs + 1] = refreshWarn
		local function setExpanded(v)
			expanded = v
			section:SetClass("hidden", not expanded)
			toggleImg:SetAttribute("src", expanded
				and "/luaui/images/terraform_brush/minus.png"
				or  "/luaui/images/terraform_brush/plus.png")
			refreshWarn()
		end
		setExpanded(expanded)
		toggleBtn:AddEventListener("click", function(event)
			setExpanded(not expanded)
			playSound(expanded and "panelOpen" or "click")
			event:StopPropagation()
		end, false)
		warnChip:AddEventListener("click", function(event)
			event:StopPropagation()
		end, false)
	end
	widgetState.warningToggle("btn-toggle-overlays",    "img-toggle-overlays",    "section-overlays",    "warn-chip-overlays",    {"btn-grid-overlay","btn-height-colormap"}, false)
	widgetState.warningToggle("btn-toggle-instruments", "img-toggle-instruments", "section-instruments", "warn-chip-instruments", {"btn-grid-snap","btn-angle-snap","btn-measure","btn-symmetry"}, false)

	-- Skybox Library collapsible sections (default collapsed)
	envSectionToggle("btn-env-toggle-skyrot",   "img-env-toggle-skyrot",   "env-section-skyrot",   false)
	envSectionToggle("btn-env-toggle-skydyn",   "img-env-toggle-skydyn",   "env-section-skydyn",   false)

	-- Sun & Shadows collapsible sections (default expanded)
	envSectionToggle("btn-env-toggle-sundir",   "img-env-toggle-sundir",   "env-section-sundir",   true)
	envSectionToggle("btn-env-toggle-sunint",   "img-env-toggle-sunint",   "env-section-sunint",   true)
	envSectionToggle("btn-env-toggle-shadow",   "img-env-toggle-shadow",   "env-section-shadow",   true)

	-- Fog & Atmosphere collapsible sections (default collapsed)
	envSectionToggle("btn-env-toggle-fogdist",  "img-env-toggle-fogdist",  "env-section-fogdist",  true)
	envSectionToggle("btn-env-toggle-fogcol",   "img-env-toggle-fogcol",   "env-section-fogcol",   true)
	envSectionToggle("btn-env-toggle-suncol",   "img-env-toggle-suncol",   "env-section-suncol",   false)
	envSectionToggle("btn-env-toggle-skycol",   "img-env-toggle-skycol",   "env-section-skycol",   false)
	envSectionToggle("btn-env-toggle-cloudcol", "img-env-toggle-cloudcol", "env-section-cloudcol", false)

	-- Ground Lighting collapsible sections (default expanded)
	envSectionToggle("btn-env-toggle-gambient",  "img-env-toggle-gambient",  "env-section-gambient",  true)
	envSectionToggle("btn-env-toggle-gdiffuse",  "img-env-toggle-gdiffuse",  "env-section-gdiffuse",  true)
	envSectionToggle("btn-env-toggle-gspecular", "img-env-toggle-gspecular", "env-section-gspecular", true)

	-- Unit Lighting collapsible sections (default expanded)
	envSectionToggle("btn-env-toggle-uambient",  "img-env-toggle-uambient",  "env-section-uambient",  true)
	envSectionToggle("btn-env-toggle-udiffuse",  "img-env-toggle-udiffuse",  "env-section-udiffuse",  true)
	envSectionToggle("btn-env-toggle-uspecular", "img-env-toggle-uspecular", "env-section-uspecular", true)

	-- Map Rendering collapsible sections (default expanded)
	envSectionToggle("btn-env-toggle-rendertoggle", "img-env-toggle-rendertoggle", "env-section-rendertoggle", true)
	envSectionToggle("btn-env-toggle-deferred",     "img-env-toggle-deferred",     "env-section-deferred",     true)
	envSectionToggle("btn-env-toggle-mapparams",    "img-env-toggle-mapparams",    "env-section-mapparams",    true)

	-- Water collapsible sections (default collapsed)
	envSectionToggle("btn-env-toggle-wtoggle",  "img-env-toggle-wtoggle",  "env-section-wtoggle",  true)
	envSectionToggle("btn-env-toggle-wcolors",  "img-env-toggle-wcolors",  "env-section-wcolors",  false)
	-- Water color sub-sections (lower level, default collapsed)
	envSectionToggle("btn-env-toggle-wc-absorb",       "img-env-toggle-wc-absorb",       "env-section-wc-absorb",       false)
	envSectionToggle("btn-env-toggle-wc-basecolor",    "img-env-toggle-wc-basecolor",    "env-section-wc-basecolor",    false)
	envSectionToggle("btn-env-toggle-wc-mincolor",     "img-env-toggle-wc-mincolor",     "env-section-wc-mincolor",     false)
	envSectionToggle("btn-env-toggle-wc-surfacecolor", "img-env-toggle-wc-surfacecolor", "env-section-wc-surfacecolor", false)
	envSectionToggle("btn-env-toggle-wc-planecolor",   "img-env-toggle-wc-planecolor",   "env-section-wc-planecolor",   false)
	envSectionToggle("btn-env-toggle-wc-diffusecolor", "img-env-toggle-wc-diffusecolor", "env-section-wc-diffusecolor", false)
	envSectionToggle("btn-env-toggle-wc-specularcolor","img-env-toggle-wc-specularcolor","env-section-wc-specularcolor",false)
	envSectionToggle("btn-env-toggle-surface",  "img-env-toggle-surface",  "env-section-surface",  false)
	envSectionToggle("btn-env-toggle-material", "img-env-toggle-material", "env-section-material", false)
	envSectionToggle("btn-env-toggle-fresnel",  "img-env-toggle-fresnel",  "env-section-fresnel",  false)
	envSectionToggle("btn-env-toggle-perlin",   "img-env-toggle-perlin",   "env-section-perlin",   false)
	envSectionToggle("btn-env-toggle-blur",     "img-env-toggle-blur",     "env-section-blur",     false)

	-- Wire ± buttons for env color RGB sliders
	do
		local colorSliders = {
			"suncol-r", "suncol-g", "suncol-b",
			"fog-r", "fog-g", "fog-b",
			"skycol-r", "skycol-g", "skycol-b",
			"cloudcol-r", "cloudcol-g", "cloudcol-b",
			"snowcol-r", "snowcol-g", "snowcol-b",
			"gambient-r", "gambient-g", "gambient-b",
			"gdiffuse-r", "gdiffuse-g", "gdiffuse-b",
			"gspecular-r", "gspecular-g", "gspecular-b",
			"uambient-r", "uambient-g", "uambient-b",
			"udiffuse-r", "udiffuse-g", "udiffuse-b",
			"uspecular-r", "uspecular-g", "uspecular-b",
			"wc-absorb-r", "wc-absorb-g", "wc-absorb-b",
			"wc-basecolor-r", "wc-basecolor-g", "wc-basecolor-b",
			"wc-mincolor-r", "wc-mincolor-g", "wc-mincolor-b",
			"wc-surfacecolor-r", "wc-surfacecolor-g", "wc-surfacecolor-b",
			"wc-planecolor-r", "wc-planecolor-g", "wc-planecolor-b",
			"wc-diffusecolor-r", "wc-diffusecolor-g", "wc-diffusecolor-b",
			"wc-specularcolor-r", "wc-specularcolor-g", "wc-specularcolor-b",
			-- non-color sliders with ± buttons
			"sun-y", "sun-x", "sun-z", "sun-intensity",
			"gshadow", "ushadow",
			"fog-start", "fog-end", "fog-a",
			"snow-density", "snow-speed", "snow-size", "snow-wind", "snow-opacity",
			"skyangle", "skyaxis-x", "skyaxis-y", "skyaxis-z",
			"skydyn-x", "skydyn-y", "skydyn-z",
			"wl",
			"w-repeatx", "w-repeaty", "w-alpha",
			"w-ambient", "w-diffuse", "w-specular", "w-specpow",
			"w-fresnelmin", "w-fresnelmax", "w-fresnelpow",
			"w-pfreq", "w-placun", "w-pamp", "w-numtiles",
			"w-blurbase", "w-blurexp", "w-refldist", "w-waveoff", "w-wavelen",
			"w-foamdist", "w-foamint", "w-caustres", "w-cauststr",
			"splatmult-0", "splatmult-1", "splatmult-2", "splatmult-3",
			"splatscale-0", "splatscale-1", "splatscale-2", "splatscale-3",
			"lava-amp", "lava-period", "lava-fogheight",
		}
		for _, suffix in ipairs(colorSliders) do
			local sl = doc:GetElementById("slider-env-" .. suffix)
			if sl then
				local mn = tonumber(sl:GetAttribute("min")) or 0
				local mx = tonumber(sl:GetAttribute("max")) or 1000
				local st = tonumber(sl:GetAttribute("step")) or 1
				local downBtn = doc:GetElementById("btn-env-" .. suffix .. "-down")
				local upBtn = doc:GetElementById("btn-env-" .. suffix .. "-up")
				if downBtn then
					downBtn:AddEventListener("click", function(event)
						local val = tonumber(sl:GetAttribute("value")) or 0
						sl:SetAttribute("value", tostring(math.max(mn, val - st)))
						event:StopPropagation()
					end, false)
				end
				if upBtn then
					upBtn:AddEventListener("click", function(event)
						local val = tonumber(sl:GetAttribute("value")) or 0
						sl:SetAttribute("value", tostring(math.min(mx, val + st)))
						event:StopPropagation()
					end, false)
				end
			end
		end
	end

	-- ---- Sun & Shadows sliders ----
	-- Cache DOM elements for live feedback from dynamic rotation
	skyDynamic.sunSliderX = doc:GetElementById("slider-env-sun-x")
	skyDynamic.sunLabelX  = doc:GetElementById("lbl-env-sun-x")
	skyDynamic.sunSliderY = doc:GetElementById("slider-env-sun-y")
	skyDynamic.sunLabelY  = doc:GetElementById("lbl-env-sun-y")
	skyDynamic.sunSliderZ = doc:GetElementById("slider-env-sun-z")
	skyDynamic.sunLabelZ  = doc:GetElementById("lbl-env-sun-z")

	envSlider("slider-env-sun-y", "lbl-env-sun-y",
		function(v) return v / 10000 end,
		function() return (select(2, gl.GetSun("pos"))) * 10000 end,
		function(val)
			local sx, sy, sz = gl.GetSun("pos")
			Spring.SetSunDirection(sx, val, sz)
			Spring.SetSunLighting({ groundShadowDensity = gl.GetSun("shadowDensity"), modelShadowDensity = gl.GetSun("shadowDensity") })
		end)
	envSlider("slider-env-sun-x", "lbl-env-sun-x",
		function(v) return v / 10000 end,
		function() return (select(1, gl.GetSun("pos"))) * 10000 end,
		function(val)
			local sx, sy, sz = gl.GetSun("pos")
			Spring.SetSunDirection(val, sy, sz)
			Spring.SetSunLighting({ groundShadowDensity = gl.GetSun("shadowDensity"), modelShadowDensity = gl.GetSun("shadowDensity") })
		end)
	envSlider("slider-env-sun-z", "lbl-env-sun-z",
		function(v) return v / 10000 end,
		function() return (select(3, gl.GetSun("pos"))) * 10000 end,
		function(val)
			local sx, sy, sz = gl.GetSun("pos")
			Spring.SetSunDirection(sx, sy, val)
			Spring.SetSunLighting({ groundShadowDensity = gl.GetSun("shadowDensity"), modelShadowDensity = gl.GetSun("shadowDensity") })
		end)
	envSlider("slider-env-gshadow", "lbl-env-gshadow",
		function(v) return v / 1000 end,
		function() return gl.GetSun("shadowDensity", "ground") * 1000 end,
		function(val) Spring.SetSunLighting({ groundShadowDensity = val }) end)
	envSlider("slider-env-ushadow", "lbl-env-ushadow",
		function(v) return v / 1000 end,
		function() return gl.GetSun("shadowDensity", "unit") * 1000 end,
		function(val) Spring.SetSunLighting({ modelShadowDensity = val }) end)

	-- Sun reset
	local resetSunBtn = doc:GetElementById("btn-env-reset-sun")
	if resetSunBtn then
		resetSunBtn:AddEventListener("click", function(event)
			local d = widgetState.envDefaults
			Spring.SetSunDirection(d.sunPos[1], d.sunPos[2], d.sunPos[3])
			Spring.SetSunLighting({ groundShadowDensity = d.groundShadowDensity, modelShadowDensity = d.unitShadowDensity })
			envSetSlider("slider-env-sun-y", "lbl-env-sun-y", math.floor(d.sunPos[2] * 10000 + 0.5), string.format("%.2f", d.sunPos[2]))
			envSetSlider("slider-env-sun-x", "lbl-env-sun-x", math.floor(d.sunPos[1] * 10000 + 0.5), string.format("%.2f", d.sunPos[1]))
			envSetSlider("slider-env-sun-z", "lbl-env-sun-z", math.floor(d.sunPos[3] * 10000 + 0.5), string.format("%.2f", d.sunPos[3]))
			envSetSlider("slider-env-gshadow", "lbl-env-gshadow", math.floor(d.groundShadowDensity * 1000 + 0.5), string.format("%.2f", d.groundShadowDensity))
			envSetSlider("slider-env-ushadow", "lbl-env-ushadow", math.floor(d.unitShadowDensity * 1000 + 0.5), string.format("%.2f", d.unitShadowDensity))
			event:StopPropagation()
		end, false)
	end

	-- Sun intensity slider
	envSlider("slider-env-sun-intensity", "lbl-env-sun-intensity",
		function(v) return v / 1000 end,
		function() return (widgetState.envSunIntensity or 1.0) * 1000 end,
		function(val)
			widgetState.envSunIntensity = val
			local sx, sy, sz = gl.GetSun("pos")
			if sx then Spring.SetSunDirection(sx, sy, sz, val) end
		end)
	widgetState.envSunIntensity = 1.0

	-- ---- Fog & Atmosphere sliders ----
	envSlider("slider-env-fog-start", "lbl-env-fog-start",
		function(v) return v / 100 end,
		function() return gl.GetAtmosphere("fogStart") * 100 end,
		function(val) Spring.SetAtmosphere({ fogStart = val }) end)
	envSlider("slider-env-fog-end", "lbl-env-fog-end",
		function(v) return v / 100 end,
		function() return gl.GetAtmosphere("fogEnd") * 100 end,
		function(val) Spring.SetAtmosphere({ fogEnd = val }) end)

	-- Fog reset
	local resetFogBtn = doc:GetElementById("btn-env-reset-fog")
	if resetFogBtn then
		resetFogBtn:AddEventListener("click", function(event)
			local d = widgetState.envDefaults
			Spring.SetAtmosphere({ fogStart = d.fogStart, fogEnd = d.fogEnd })
			envSetSlider("slider-env-fog-start", "lbl-env-fog-start", math.floor(d.fogStart * 100 + 0.5), string.format("%.2f", d.fogStart))
			envSetSlider("slider-env-fog-end", "lbl-env-fog-end", math.floor(d.fogEnd * 100 + 0.5), string.format("%.2f", d.fogEnd))
			event:StopPropagation()
		end, false)
	end

	-- Fog color
	local function fogColorSlider(suffix, idx)
		envSlider("slider-env-fog-" .. suffix, "lbl-env-fog-" .. suffix,
			function(v) return v / 1000 end,
			function()
				local c = { gl.GetAtmosphere("fogColor") }
				return (c[idx] or 0) * 1000
			end,
			function(val)
				local c = { gl.GetAtmosphere("fogColor") }
				c[idx] = val
				Spring.SetAtmosphere({ fogColor = c })
			end)
	end
	fogColorSlider("r", 1)
	fogColorSlider("g", 2)
	fogColorSlider("b", 3)
	fogColorSlider("a", 4)

	-- Fog color reset
	local resetFogColorBtn = doc:GetElementById("btn-env-reset-fogcolor")
	if resetFogColorBtn then
		resetFogColorBtn:AddEventListener("click", function(event)
			local d = widgetState.envDefaults
			Spring.SetAtmosphere({ fogColor = d.fogColor })
			for i, s in ipairs({"r", "g", "b", "a"}) do
				envSetSlider("slider-env-fog-" .. s, "lbl-env-fog-" .. s,
					math.floor((d.fogColor[i] or 0) * 1000 + 0.5),
					string.format("%.2f", d.fogColor[i] or 0))
			end
			event:StopPropagation()
		end, false)
	end

	-- Sun color sliders
	local function sunColorSlider(suffix, idx)
		envSlider("slider-env-suncol-" .. suffix, "lbl-env-suncol-" .. suffix,
			function(v) return v / 1000 end,
			function()
				local c = { gl.GetAtmosphere("sunColor") }
				return (c[idx] or 0) * 1000
			end,
			function(val)
				local c = { gl.GetAtmosphere("sunColor") }
				c[idx] = val
				Spring.SetAtmosphere({ sunColor = c })
			end)
	end
	sunColorSlider("r", 1)
	sunColorSlider("g", 2)
	sunColorSlider("b", 3)

	-- Sky color sliders
	local function skyColorSlider(suffix, idx)
		envSlider("slider-env-skycol-" .. suffix, "lbl-env-skycol-" .. suffix,
			function(v) return v / 1000 end,
			function()
				local c = { gl.GetAtmosphere("skyColor") }
				return (c[idx] or 0) * 1000
			end,
			function(val)
				local c = { gl.GetAtmosphere("skyColor") }
				c[idx] = val
				Spring.SetAtmosphere({ skyColor = c })
			end)
	end
	skyColorSlider("r", 1)
	skyColorSlider("g", 2)
	skyColorSlider("b", 3)

	-- Cloud color sliders
	local function cloudColorSlider(suffix, idx)
		envSlider("slider-env-cloudcol-" .. suffix, "lbl-env-cloudcol-" .. suffix,
			function(v) return v / 1000 end,
			function()
				local c = { gl.GetAtmosphere("cloudColor") }
				return (c[idx] or 0) * 1000
			end,
			function(val)
				local c = { gl.GetAtmosphere("cloudColor") }
				c[idx] = val
				Spring.SetAtmosphere({ cloudColor = c })
			end)
	end
	cloudColorSlider("r", 1)
	cloudColorSlider("g", 2)
	cloudColorSlider("b", 3)

	-- Wire palette + preview for fog, sun, sky, cloud colors
	wireColorGroup({
		paletteId = "env-fog-palette", previewId = "env-fog-preview", sliderPrefix = "fog",
		channels = {"r", "g", "b", "a"},
		getColor = function() return { gl.GetAtmosphere("fogColor") } end,
		setColor = function(c)
			local existing = { gl.GetAtmosphere("fogColor") }
			Spring.SetAtmosphere({ fogColor = { c[1], c[2], c[3], existing[4] or 0 } })
		end,
	})
	wireColorGroup({
		paletteId = "env-suncol-palette", previewId = "env-suncol-preview", sliderPrefix = "suncol",
		getColor = function() return { gl.GetAtmosphere("sunColor") } end,
		setColor = function(c) Spring.SetAtmosphere({ sunColor = c }) end,
	})
	wireColorGroup({
		paletteId = "env-skycol-palette", previewId = "env-skycol-preview", sliderPrefix = "skycol",
		getColor = function() return { gl.GetAtmosphere("skyColor") } end,
		setColor = function(c) Spring.SetAtmosphere({ skyColor = c }) end,
	})
	wireColorGroup({
		paletteId = "env-cloudcol-palette", previewId = "env-cloudcol-preview", sliderPrefix = "cloudcol",
		getColor = function() return { gl.GetAtmosphere("cloudColor") } end,
		setColor = function(c) Spring.SetAtmosphere({ cloudColor = c }) end,
	})

	-- Sun color reset
	do local resetBtn = doc:GetElementById("btn-env-reset-suncol")
	if resetBtn then
		resetBtn:AddEventListener("click", function(event)
			local d = widgetState.envDefaults
			Spring.SetAtmosphere({ sunColor = d.sunColor })
			for i, s in ipairs({"r", "g", "b"}) do
				envSetSlider("slider-env-suncol-" .. s, "lbl-env-suncol-" .. s,
					math.floor((d.sunColor[i] or 0) * 1000 + 0.5),
					string.format("%.2f", d.sunColor[i] or 0))
			end
			local c = d.sunColor
			updatePreview(doc:GetElementById("env-suncol-preview"), c[1], c[2], c[3])
			event:StopPropagation()
		end, false)
	end end

	-- Sky color reset
	do local resetBtn = doc:GetElementById("btn-env-reset-skycol")
	if resetBtn then
		resetBtn:AddEventListener("click", function(event)
			local d = widgetState.envDefaults
			Spring.SetAtmosphere({ skyColor = d.skyColor })
			for i, s in ipairs({"r", "g", "b"}) do
				envSetSlider("slider-env-skycol-" .. s, "lbl-env-skycol-" .. s,
					math.floor((d.skyColor[i] or 0) * 1000 + 0.5),
					string.format("%.2f", d.skyColor[i] or 0))
			end
			local c = d.skyColor
			updatePreview(doc:GetElementById("env-skycol-preview"), c[1], c[2], c[3])
			event:StopPropagation()
		end, false)
	end end

	-- Cloud color reset
	do local resetBtn = doc:GetElementById("btn-env-reset-cloudcol")
	if resetBtn then
		resetBtn:AddEventListener("click", function(event)
			local d = widgetState.envDefaults
			Spring.SetAtmosphere({ cloudColor = d.cloudColor })
			for i, s in ipairs({"r", "g", "b"}) do
				envSetSlider("slider-env-cloudcol-" .. s, "lbl-env-cloudcol-" .. s,
					math.floor((d.cloudColor[i] or 0) * 1000 + 0.5),
					string.format("%.2f", d.cloudColor[i] or 0))
			end
			local c = d.cloudColor
			updatePreview(doc:GetElementById("env-cloudcol-preview"), c[1], c[2], c[3])
			event:StopPropagation()
		end, false)
	end end

	-- ---- Snow controls ----
	envSectionToggle("btn-env-toggle-snow", "img-env-toggle-snow", "env-section-snow", false)

	-- Snow enable checkbox
	do
		local snowApi = WG['snow']
		local snowEnabled = snowApi and snowApi.getSnowMap() or false
		envCheckbox("btn-env-snow-enabled", snowEnabled,
			function(val)
				if WG['snow'] then WG['snow'].setSnowMap(val) end
			end)
	end

	-- Snow auto-reduce checkbox
	do
		local snowApi = WG['snow']
		local autoReduce = snowApi and snowApi.getAutoReduce and snowApi.getAutoReduce() or true
		envCheckbox("btn-env-snow-autoreduce", autoReduce,
			function(val)
				if WG['snow'] then WG['snow'].setAutoReduce(val) end
			end)
	end

	-- Snow density slider (multiplier 0.1 - 5.0)
	envSlider("slider-env-snow-density", "lbl-env-snow-density",
		function(v) return v / 100 end,
		function()
			local snowApi = WG['snow']
			return snowApi and snowApi.getMultiplier and snowApi.getMultiplier() * 100 or 100
		end,
		function(val)
			if WG['snow'] then WG['snow'].setMultiplier(val) end
		end)

	-- Snow speed slider (multiplier 0.1 - 3.0)
	envSlider("slider-env-snow-speed", "lbl-env-snow-speed",
		function(v) return v / 100 end,
		function()
			local snowApi = WG['snow']
			return snowApi and snowApi.getSpeedMultiplier and snowApi.getSpeedMultiplier() * 100 or 100
		end,
		function(val)
			if WG['snow'] then WG['snow'].setSpeedMultiplier(val) end
		end)

	-- Snow size slider (multiplier 0.1 - 3.0)
	envSlider("slider-env-snow-size", "lbl-env-snow-size",
		function(v) return v / 100 end,
		function()
			local snowApi = WG['snow']
			return snowApi and snowApi.getSizeMultiplier and snowApi.getSizeMultiplier() * 100 or 100
		end,
		function(val)
			if WG['snow'] then WG['snow'].setSizeMultiplier(val) end
		end)

	-- Snow wind slider (0.0 - 20.0)
	envSlider("slider-env-snow-wind", "lbl-env-snow-wind",
		function(v) return v / 10 end,
		function()
			local snowApi = WG['snow']
			return snowApi and snowApi.getWindMultiplier and snowApi.getWindMultiplier() * 10 or 45
		end,
		function(val)
			if WG['snow'] then WG['snow'].setWindMultiplier(val) end
		end)

	-- Snow opacity slider (0.0 - 1.0)
	envSlider("slider-env-snow-opacity", "lbl-env-snow-opacity",
		function(v) return v / 100 end,
		function()
			local snowApi = WG['snow']
			return snowApi and snowApi.getOpacity and snowApi.getOpacity() * 100 or 66
		end,
		function(val)
			if WG['snow'] then WG['snow'].setOpacity(val) end
		end)

	-- Snow color sliders
	local function snowColorSlider(suffix, idx)
		envSlider("slider-env-snowcol-" .. suffix, "lbl-env-snowcol-" .. suffix,
			function(v) return v / 1000 end,
			function()
				local snowApi = WG['snow']
				if snowApi and snowApi.getColor then
					local r, g, b = snowApi.getColor()
					local c = {r, g, b}
					return (c[idx] or 0) * 1000
				end
				return ({800, 800, 900})[idx]
			end,
			function(val)
				if WG['snow'] and WG['snow'].getColor and WG['snow'].setColor then
					local r, g, b = WG['snow'].getColor()
					local c = {r, g, b}
					c[idx] = val
					WG['snow'].setColor(c[1], c[2], c[3])
					updatePreview(doc:GetElementById("env-snowcol-preview"), c[1], c[2], c[3])
				end
			end)
	end
	snowColorSlider("r", 1)
	snowColorSlider("g", 2)
	snowColorSlider("b", 3)

	-- Wire snow color palette + preview
	wireColorGroup({
		paletteId = "env-snowcol-palette", previewId = "env-snowcol-preview", sliderPrefix = "snowcol",
		getColor = function()
			local snowApi = WG['snow']
			if snowApi and snowApi.getColor then
				local r, g, b = snowApi.getColor()
				return {r, g, b}
			end
			return {0.8, 0.8, 0.9}
		end,
		setColor = function(c)
			if WG['snow'] and WG['snow'].setColor then
				WG['snow'].setColor(c[1], c[2], c[3])
			end
		end,
	})

	-- Snow reset button
	do local resetBtn = doc:GetElementById("btn-env-reset-snow")
	if resetBtn then
		resetBtn:AddEventListener("click", function(event)
			if WG['snow'] then
				if WG['snow'].setMultiplier then WG['snow'].setMultiplier(1.0) end
				if WG['snow'].setSpeedMultiplier then WG['snow'].setSpeedMultiplier(1.0) end
				if WG['snow'].setSizeMultiplier then WG['snow'].setSizeMultiplier(1.0) end
				if WG['snow'].setWindMultiplier then WG['snow'].setWindMultiplier(4.5) end
				if WG['snow'].setOpacity then WG['snow'].setOpacity(0.66) end
				if WG['snow'].setColor then WG['snow'].setColor(0.8, 0.8, 0.9) end
			end
			envSetSlider("slider-env-snow-density", "lbl-env-snow-density", 100, "1.00")
			envSetSlider("slider-env-snow-speed", "lbl-env-snow-speed", 100, "1.00")
			envSetSlider("slider-env-snow-size", "lbl-env-snow-size", 100, "1.00")
			envSetSlider("slider-env-snow-wind", "lbl-env-snow-wind", 45, "4.50")
			envSetSlider("slider-env-snow-opacity", "lbl-env-snow-opacity", 66, "0.66")
			envSetSlider("slider-env-snowcol-r", "lbl-env-snowcol-r", 800, "0.80")
			envSetSlider("slider-env-snowcol-g", "lbl-env-snowcol-g", 800, "0.80")
			envSetSlider("slider-env-snowcol-b", "lbl-env-snowcol-b", 900, "0.90")
			updatePreview(doc:GetElementById("env-snowcol-preview"), 0.8, 0.8, 0.9)
			event:StopPropagation()
		end, false)
	end end

	-- ---- Lighting sliders ----
	local function lightingSlider(prefix, sunKind, sunScope, lightingKey)
		for i, suffix in ipairs({"r", "g", "b"}) do
			envSlider("slider-env-" .. prefix .. "-" .. suffix, "lbl-env-" .. prefix .. "-" .. suffix,
				function(v) return v / 1000 end,
				function()
					local r, g, b = gl.GetSun(sunKind, sunScope)
					local c = {r, g, b}
					return (c[i] or 0) * 1000
				end,
				function(val)
					local r, g, b = gl.GetSun(sunKind, sunScope)
					local c = {r or 0, g or 0, b or 0}
					c[i] = val
					Spring.SetSunLighting({ [lightingKey] = c })
					Spring.SendCommands("luarules updatesun")
				end)
		end
	end
	lightingSlider("gambient", "ambient", nil, "groundAmbientColor")
	lightingSlider("gdiffuse", "diffuse", nil, "groundDiffuseColor")
	lightingSlider("gspecular", "specular", nil, "groundSpecularColor")
	lightingSlider("uambient", "ambient", "unit", "unitAmbientColor")
	lightingSlider("udiffuse", "diffuse", "unit", "unitDiffuseColor")
	lightingSlider("uspecular", "specular", "unit", "unitSpecularColor")

	-- Ground lighting reset
	do local resetBtn = doc:GetElementById("btn-env-reset-ground-lighting")
	if resetBtn then
		resetBtn:AddEventListener("click", function(event)
			local d = widgetState.envDefaults
			Spring.SetSunLighting({
				groundAmbientColor = d.groundAmbient,
				groundDiffuseColor = d.groundDiffuse,
				groundSpecularColor = d.groundSpecular,
			})
			Spring.SendCommands("luarules updatesun")
			local map = {
				{"gambient", d.groundAmbient}, {"gdiffuse", d.groundDiffuse}, {"gspecular", d.groundSpecular},
			}
			for _, entry in ipairs(map) do
				for i, s in ipairs({"r", "g", "b"}) do
					envSetSlider("slider-env-" .. entry[1] .. "-" .. s, "lbl-env-" .. entry[1] .. "-" .. s,
						math.floor((entry[2][i] or 0) * 1000 + 0.5),
						string.format("%.2f", entry[2][i] or 0))
				end
			end
			event:StopPropagation()
		end, false)
	end end

	-- Unit lighting reset
	do local resetBtn = doc:GetElementById("btn-env-reset-unit-lighting")
	if resetBtn then
		resetBtn:AddEventListener("click", function(event)
			local d = widgetState.envDefaults
			Spring.SetSunLighting({
				unitAmbientColor = d.unitAmbient,
				unitDiffuseColor = d.unitDiffuse,
				unitSpecularColor = d.unitSpecular,
			})
			Spring.SendCommands("luarules updatesun")
			local map = {
				{"uambient", d.unitAmbient}, {"udiffuse", d.unitDiffuse}, {"uspecular", d.unitSpecular},
			}
			for _, entry in ipairs(map) do
				for i, s in ipairs({"r", "g", "b"}) do
					envSetSlider("slider-env-" .. entry[1] .. "-" .. s, "lbl-env-" .. entry[1] .. "-" .. s,
						math.floor((entry[2][i] or 0) * 1000 + 0.5),
						string.format("%.2f", entry[2][i] or 0))
				end
			end
			event:StopPropagation()
		end, false)
	end end

	-- ---- Map Rendering controls ----
	-- Render toggles (default to true; no engine getter available)
	envCheckbox("btn-env-drawsky", true,
		function(val) Spring.SetDrawSky(val) end)
	envCheckbox("btn-env-drawwater", true,
		function(val) Spring.SetDrawWater(val) end)
	envCheckbox("btn-env-drawground", true,
		function(val) Spring.SetDrawGround(val) end)

	-- Deferred rendering toggles (default to true)
	envCheckbox("btn-env-deferground", true,
		function(val) Spring.SetDrawGroundDeferred(val) end)
	envCheckbox("btn-env-defermodels", true,
		function(val) Spring.SetDrawModelsDeferred(val, val) end)

	envCheckbox("btn-env-splatdnda", gl.GetMapRendering("splatDetailNormalDiffuseAlpha"),
		function(val) Spring.SetMapRenderingParams({ splatDetailNormalDiffuseAlpha = val }) end)
	envCheckbox("btn-env-voidwater", gl.GetMapRendering("voidWater"),
		function(val) Spring.SetMapRenderingParams({ voidWater = val }) end)
	envCheckbox("btn-env-voidground", gl.GetMapRendering("voidGround"),
		function(val) Spring.SetMapRenderingParams({ voidGround = val }) end)

	-- Splat tex multipliers
	for ch = 0, 3 do
		local chIdx = ch + 1
		envSlider("slider-env-splatmult-" .. ch, "lbl-env-splatmult-" .. ch,
			function(v) return v / 1000 end,
			function()
				local r, g, b, a = gl.GetMapRendering("splatTexMults")
				local c = {r, g, b, a}
				return (c[chIdx] or 0) * 1000
			end,
			function(val)
				local r, g, b, a = gl.GetMapRendering("splatTexMults")
				local c = {r, g, b, a}
				c[chIdx] = val
				Spring.SetMapRenderingParams({ splatTexMults = c })
			end)
	end

	-- Splat tex scales
	for ch = 0, 3 do
		local chIdx = ch + 1
		envSlider("slider-env-splatscale-" .. ch, "lbl-env-splatscale-" .. ch,
			function(v) return v / 10000 end,
			function()
				local r, g, b, a = gl.GetMapRendering("splatTexScales")
				local c = {r, g, b, a}
				return (c[chIdx] or 0) * 10000
			end,
			function(val)
				local r, g, b, a = gl.GetMapRendering("splatTexScales")
				local c = {r, g, b, a}
				c[chIdx] = val
				Spring.SetMapRenderingParams({ splatTexScales = c })
			end)
		-- Override label format to 3 decimal places
		local lb = doc:GetElementById("lbl-env-splatscale-" .. ch)
		local sl = doc:GetElementById("slider-env-splatscale-" .. ch)
		if sl and lb then
			sl:AddEventListener("change", function(event)
				if updatingFromCode then return end
				local raw = tonumber(sl:GetAttribute("value")) or 0
				lb.inner_rml = string.format("%.4f", raw / 10000)
			end, false)
		end
	end

	-- ---- Skybox rotation sliders ----
	envSlider("slider-env-skyangle", "lbl-env-skyangle",
		function(v) return v / 100 end,
		function()
			local x, y, z, angle = gl.GetAtmosphere("skyAxisAngle")
			return (angle or 0) * 100
		end,
		function(val)
			local x, y, z, angle = gl.GetAtmosphere("skyAxisAngle")
			Spring.SetAtmosphere({ skyAxisAngle = { x, y, z, val } })
		end)
	local function skyAxisSlider(axis, idx)
		envSlider("slider-env-skyaxis-" .. axis, "lbl-env-skyaxis-" .. axis,
			function(v) return v / 100 end,
			function()
				local x, y, z, angle = gl.GetAtmosphere("skyAxisAngle")
				local c = {x, y, z, angle}
				return (c[idx] or 0) * 100
			end,
			function(val)
				local x, y, z, angle = gl.GetAtmosphere("skyAxisAngle")
				local c = {x, y, z, angle}
				c[idx] = val
				Spring.SetAtmosphere({ skyAxisAngle = c })
			end)
	end
	skyAxisSlider("x", 1)
	skyAxisSlider("y", 2)
	skyAxisSlider("z", 3)

	-- Sky axis reset
	local resetSkyAxisBtn = doc:GetElementById("btn-env-reset-skyaxis")
	if resetSkyAxisBtn then
		resetSkyAxisBtn:AddEventListener("click", function(event)
			local d = widgetState.envDefaults
			Spring.SetAtmosphere({ skyAxisAngle = d.skyAxisAngle })
			event:StopPropagation()
		end, false)
	end

	-- ---- Dynamic skybox rotation controls ----
	local function skyDynSlider(axis, field)
		envSlider("slider-env-skydyn-" .. axis, "lbl-env-skydyn-" .. axis,
			function(v) return v / 100 end,
			function() return skyDynamic[field] * 100 end,
			function(val) skyDynamic[field] = val end)
	end
	skyDynSlider("x", "speedX")
	skyDynSlider("y", "speedY")
	skyDynSlider("z", "speedZ")

	envCheckbox("btn-env-skydyn-sunsync", skyDynamic.sunSync,
		function(val) skyDynamic.sunSync = val end)

	local playBtn = doc:GetElementById("btn-env-skydyn-play")
	local pauseBtn = doc:GetElementById("btn-env-skydyn-pause")
	if playBtn then
		playBtn:AddEventListener("click", function(event)
			skyDynamic.playing = true
			-- Reset delta angles to zero; capture current skybox rotation as start quaternion
			skyDynamic.angleX = 0
			skyDynamic.angleY = 0
			skyDynamic.angleZ = 0
			local x, y, z, angle = gl.GetAtmosphere("skyAxisAngle")
			local sqx, sqy, sqz, sqw = quatFromAxisAngle(x or 0, y or 1, z or 0, angle or 0)
			skyDynamic.startQuat = { sqx, sqy, sqz, sqw }
			-- Capture sun direction for sun-sync
			local sx, sy, sz = gl.GetSun("pos")
			skyDynamic.origSunDir = { sx, sy, sz }
			event:StopPropagation()
		end, false)
	end
	if pauseBtn then
		pauseBtn:AddEventListener("click", function(event)
			skyDynamic.playing = false
			event:StopPropagation()
		end, false)
	end

	-- ---- Water controls ----
	envCheckbox("btn-env-w-shorewaves", gl.GetWaterRendering("shoreWaves"),
		function(val)
			Spring.SetWaterParams({ shoreWaves = val })
			Spring.SendCommands("water 4")
		end)
	envCheckbox("btn-env-w-waterplane", gl.GetWaterRendering("hasWaterPlane"),
		function(val)
			Spring.SetWaterParams({ hasWaterPlane = val })
			Spring.SendCommands("water 4")
		end)
	envCheckbox("btn-env-w-forcerender", gl.GetWaterRendering("forceRendering"),
		function(val)
			Spring.SetWaterParams({ forceRendering = val })
			Spring.SendCommands("water 4")
		end)

	-- Water sliders
	local waterSliders = {
		{ "repeatx", "repeatx", 1, "repeatX", "repeatX", 1 },
		{ "repeaty", "repeaty", 1, "repeatY", "repeatY", 1 },
		{ "alpha", "alpha", 1000, "surfaceAlpha", "surfaceAlpha", 1000 },
		{ "ambient", "ambient", 1000, "ambientFactor", "ambientFactor", 1000 },
		{ "diffuse", "diffuse", 1000, "diffuseFactor", "diffuseFactor", 1000 },
		{ "specular", "specular", 1000, "specularFactor", "specularFactor", 1000 },
		{ "specpow", "specpow", 10, "specularPower", "specularPower", 10 },
		{ "fresnelmin", "fresnelmin", 100, "fresnelMin", "fresnelMin", 100 },
		{ "fresnelmax", "fresnelmax", 100, "fresnelMax", "fresnelMax", 100 },
		{ "fresnelpow", "fresnelpow", 10, "fresnelPower", "fresnelPower", 10 },
		{ "pfreq", "pfreq", 1, "perlinStartFreq", "perlinStartFreq", 1 },
		{ "placun", "placun", 100, "perlinLacunarity", "perlinLacunarity", 100 },
		{ "pamp", "pamp", 100, "perlinAmplitude", "perlinAmplitude", 100 },
		{ "numtiles", "numtiles", 1, "numTiles", "numTiles", 1 },
		{ "blurbase", "blurbase", 100, "blurBase", "blurBase", 100 },
		{ "blurexp", "blurexp", 100, "blurExponent", "blurExponent", 100 },
		{ "refldist", "refldist", 100, "reflectionDistortion", "reflectionDistortion", 100 },
		{ "waveoff", "waveoff", 100, "waveOffsetFactor", "waveOffsetFactor", 100 },
		{ "wavelen", "wavelen", 100, "waveLength", "waveLength", 100 },
		{ "foamdist", "foamdist", 100, "waveFoamDistortion", "waveFoamDistortion", 100 },
		{ "foamint", "foamint", 100, "waveFoamIntensity", "waveFoamIntensity", 100 },
		{ "caustres", "caustres", 1, "causticsResolution", "causticsResolution", 1 },
		{ "cauststr", "cauststr", 100, "causticsStrength", "causticsStrength", 100 },
	}
	for _, ws in ipairs(waterSliders) do
		local slSuffix, lblSuffix, divisor, getParam, setParam, getScale = ws[1], ws[2], ws[3], ws[4], ws[5], ws[6]
		envSlider("slider-env-w-" .. slSuffix, "lbl-env-w-" .. lblSuffix,
			function(v) return v / divisor end,
			function() return (gl.GetWaterRendering(getParam) or 0) * getScale end,
			function(val)
				Spring.SetWaterParams({ [setParam] = val })
				Spring.SendCommands("water 4")
			end)
	end

	-- ---- Water color sliders ----
	do
		local waterColorParams = {
			{ prefix = "absorb",       param = "absorb",       paletteId = "env-wc-palette-absorb" },
			{ prefix = "basecolor",    param = "baseColor",    paletteId = "env-wc-palette-basecolor" },
			{ prefix = "mincolor",     param = "minColor" },
			{ prefix = "surfacecolor", param = "surfaceColor" },
			{ prefix = "planecolor",   param = "planeColor" },
			{ prefix = "diffusecolor", param = "diffuseColor" },
			{ prefix = "specularcolor",param = "specularColor" },
		}
		for _, wc in ipairs(waterColorParams) do
			for i, suffix in ipairs({"r", "g", "b"}) do
				envSlider("slider-env-wc-" .. wc.prefix .. "-" .. suffix, "lbl-env-wc-" .. wc.prefix .. "-" .. suffix,
					function(v) return v / 1000 end,
					function()
						local c = { gl.GetWaterRendering(wc.param) }
						return (c[i] or 0) * 1000
					end,
					function(val)
						local c = { gl.GetWaterRendering(wc.param) }
						c[i] = val
						Spring.SetWaterParams({ [wc.param] = c })
						Spring.SendCommands("water 4")
					end)
			end
			wireColorGroup({
				paletteId = wc.paletteId,
				previewId = "env-wc-preview-" .. wc.prefix,
				sliderPrefix = "wc-" .. wc.prefix,
				getColor = function() return { gl.GetWaterRendering(wc.param) } end,
				setColor = function(c)
					Spring.SetWaterParams({ [wc.param] = c })
					Spring.SendCommands("water 4")
				end,
			})
		end

		-- Water colors reset
		local resetWCBtn = doc:GetElementById("btn-env-reset-watercolors")
		if resetWCBtn then
			resetWCBtn:AddEventListener("click", function(event)
				local d = widgetState.envDefaults
				local resetMap = {
					{ "absorb", d.waterAbsorb }, { "basecolor", d.waterBaseColor },
					{ "mincolor", d.waterMinColor }, { "surfacecolor", d.waterSurfaceColor },
					{ "planecolor", d.waterPlaneColor }, { "diffusecolor", d.waterDiffuseColor },
					{ "specularcolor", d.waterSpecularColor },
				}
				local paramMap = {
					absorb = "absorb", basecolor = "baseColor", mincolor = "minColor",
					surfacecolor = "surfaceColor", planecolor = "planeColor",
					diffusecolor = "diffuseColor", specularcolor = "specularColor",
				}
				for _, entry in ipairs(resetMap) do
					local prefix, defVal = entry[1], entry[2]
					Spring.SetWaterParams({ [paramMap[prefix]] = defVal })
					for i, s in ipairs({"r", "g", "b"}) do
						envSetSlider("slider-env-wc-" .. prefix .. "-" .. s, "lbl-env-wc-" .. prefix .. "-" .. s,
							math.floor((defVal[i] or 0) * 1000 + 0.5),
							string.format("%.2f", defVal[i] or 0))
					end
					updatePreview(doc:GetElementById("env-wc-preview-" .. prefix), defVal[1], defVal[2], defVal[3])
				end
				Spring.SendCommands("water 4")
				-- Also deactivate shader overlay on color reset
				local overlay = WG.WaterTypeOverlay
				if overlay then overlay.deactivate() end
				event:StopPropagation()
			end, false)
		end
	end

	-- ---- Water Type Preset Switcher ----
	do
		local waterTypePresets = {
			ocean = {
				absorb       = {0.30, 0.04, 0.03},
				baseColor    = {0.00, 0.10, 0.30},
				minColor     = {0.00, 0.02, 0.08},
				surfaceColor = {0.60, 0.70, 0.85},
				planeColor   = {0.00, 0.15, 0.35},
				diffuseColor = {1.00, 1.00, 1.00},
				specularColor= {0.80, 0.80, 0.90},
			},
			lava = {
				absorb       = {0.00, 0.25, 0.45},
				baseColor    = {0.80, 0.20, 0.00},
				minColor     = {0.50, 0.05, 0.00},
				surfaceColor = {1.00, 0.50, 0.10},
				planeColor   = {0.60, 0.10, 0.00},
				diffuseColor = {1.00, 0.40, 0.00},
				specularColor= {1.00, 0.60, 0.20},
			},
			acid = {
				absorb       = {0.30, 0.02, 0.35},
				baseColor    = {0.10, 0.40, 0.05},
				minColor     = {0.00, 0.15, 0.00},
				surfaceColor = {0.30, 0.80, 0.20},
				planeColor   = {0.05, 0.30, 0.02},
				diffuseColor = {0.50, 1.00, 0.30},
				specularColor= {0.40, 0.90, 0.30},
			},
			swamp = {
				absorb       = {0.15, 0.08, 0.02},
				baseColor    = {0.15, 0.18, 0.05},
				minColor     = {0.03, 0.05, 0.02},
				surfaceColor = {0.25, 0.30, 0.15},
				planeColor   = {0.10, 0.12, 0.04},
				diffuseColor = {0.60, 0.70, 0.40},
				specularColor= {0.30, 0.35, 0.20},
			},
			ice = {
				absorb       = {0.15, 0.05, 0.03},
				baseColor    = {0.50, 0.65, 0.80},
				minColor     = {0.20, 0.30, 0.40},
				surfaceColor = {0.85, 0.90, 0.95},
				planeColor   = {0.40, 0.55, 0.70},
				diffuseColor = {0.90, 0.95, 1.00},
				specularColor= {1.00, 1.00, 1.00},
			},
		}

		local wtypeButtons = { "default", "ocean", "lava", "acid", "swamp", "ice" }
		local wtypeBtnEls = {}
		for _, name in ipairs(wtypeButtons) do
			wtypeBtnEls[name] = doc:GetElementById("btn-wtype-" .. name)
		end

		local function applyWaterTypePreset(colors)
			for param, c in pairs(colors) do
				Spring.SetWaterParams({ [param] = c })
			end
			Spring.SendCommands("water 4")
			-- Update all water color sliders to reflect new values
			local sliderMap = {
				{ "absorb",       "absorb" },
				{ "basecolor",    "baseColor" },
				{ "mincolor",     "minColor" },
				{ "surfacecolor", "surfaceColor" },
				{ "planecolor",   "planeColor" },
				{ "diffusecolor", "diffuseColor" },
				{ "specularcolor","specularColor" },
			}
			for _, entry in ipairs(sliderMap) do
				local prefix, param = entry[1], entry[2]
				local c = { gl.GetWaterRendering(param) }
				for i, s in ipairs({"r", "g", "b"}) do
					envSetSlider("slider-env-wc-" .. prefix .. "-" .. s, "lbl-env-wc-" .. prefix .. "-" .. s,
						math.floor((c[i] or 0) * 1000 + 0.5),
						string.format("%.2f", c[i] or 0))
				end
				updatePreview(doc:GetElementById("env-wc-preview-" .. prefix), c[1], c[2], c[3])
			end
		end

		local function setWtypeActive(activeName)
			for _, name in ipairs(wtypeButtons) do
				local el = wtypeBtnEls[name]
				if el then
					if name == activeName then
						el:SetClass("tf-wtype-active", true)
					else
						el:SetClass("tf-wtype-active", false)
					end
				end
			end
		end

		for _, name in ipairs(wtypeButtons) do
			local btn = wtypeBtnEls[name]
			if btn then
				btn:AddEventListener("click", function(event)
					if name == "default" then
						-- Reset to map defaults
						local d = widgetState.envDefaults
						local defColors = {
							absorb = d.waterAbsorb, baseColor = d.waterBaseColor,
							minColor = d.waterMinColor, surfaceColor = d.waterSurfaceColor,
							planeColor = d.waterPlaneColor, diffuseColor = d.waterDiffuseColor,
							specularColor = d.waterSpecularColor,
						}
						applyWaterTypePreset(defColors)
					else
						applyWaterTypePreset(waterTypePresets[name])
					end
					-- Activate/deactivate the shader overlay for lava/acid
					local overlay = WG.WaterTypeOverlay
					if overlay then
						if name == "lava" or name == "acid" then
							overlay.activate(name)
						else
							overlay.deactivate()
						end
					end
					setWtypeActive(name)
					-- Show/hide water sections for lava/acid types
					local stdSections = doc:GetElementById("env-water-std-sections")
					local lavaSections = doc:GetElementById("env-lava-sections")
					if stdSections and lavaSections then
						local isLavaType = name == "lava" or name == "acid"
						stdSections:SetClass("hidden", isLavaType)
						lavaSections:SetClass("hidden", not isLavaType)
					end
					event:StopPropagation()
				end, false)
			end
		end

		-- Lava / acid shader overlay sliders
		envSlider("slider-env-lava-amp", "lbl-env-lava-amp",
			function(v) return v end,
			function() return 2 end,
			function(val)
				local ov = WG.WaterTypeOverlay
				if ov and ov.setTideAmplitude then ov.setTideAmplitude(val) end
			end)
		envSlider("slider-env-lava-period", "lbl-env-lava-period",
			function(v) return v end,
			function() return 200 end,
			function(val)
				local ov = WG.WaterTypeOverlay
				if ov and ov.setTidePeriod then ov.setTidePeriod(val) end
			end)
		envSlider("slider-env-lava-fogheight", "lbl-env-lava-fogheight",
			function(v) return v end,
			function() return 20 end,
			function(val)
				local ov = WG.WaterTypeOverlay
				if ov and ov.setFogHeight then ov.setFogHeight(val) end
			end)
	end

	-- ---- Dimensions panel controls ----
	do
		-- Populate map size labels
		local lblMapX = doc:GetElementById("lbl-dim-map-x")
		local lblMapZ = doc:GetElementById("lbl-dim-map-z")
		if lblMapX then lblMapX.inner_rml = tostring(Game.mapSizeX) end
		if lblMapZ then lblMapZ.inner_rml = tostring(Game.mapSizeZ) end

		-- Height extreme labels
		local lblInitMin = doc:GetElementById("lbl-dim-init-min")
		local lblInitMax = doc:GetElementById("lbl-dim-init-max")
		local lblCurrMin = doc:GetElementById("lbl-dim-curr-min")
		local lblCurrMax = doc:GetElementById("lbl-dim-curr-max")
		local lblWaterPlane = doc:GetElementById("lbl-dim-water-plane")

		local function refreshDimExtremes()
			local initMin, initMax, currMin, currMax = Spring.GetGroundExtremes()
			if lblInitMin then lblInitMin.inner_rml = string.format("%.1f", initMin or 0) end
			if lblInitMax then lblInitMax.inner_rml = string.format("%.1f", initMax or 0) end
			if lblCurrMin then lblCurrMin.inner_rml = string.format("%.1f", currMin or 0) end
			if lblCurrMax then lblCurrMax.inner_rml = string.format("%.1f", currMax or 0) end
			local wl = Spring.GetWaterPlaneLevel and Spring.GetWaterPlaneLevel() or 0
			if lblWaterPlane then lblWaterPlane.inner_rml = string.format("%.1f", wl) end
		end

		refreshDimExtremes()

		local refreshBtn = doc:GetElementById("btn-dim-refresh-extremes")
		if refreshBtn then
			refreshBtn:AddEventListener("click", function(event)
				refreshDimExtremes()
				event:StopPropagation()
			end, false)
		end

		-- Water level input
		local wlInput = doc:GetElementById("input-dim-waterlevel")
		if wlInput then
			wlInput:AddEventListener("focus", function() Spring.SDLStartTextInput(); widgetState.focusedRmlInput = wlInput end, false)
			wlInput:AddEventListener("blur", function() Spring.SDLStopTextInput(); widgetState.focusedRmlInput = nil end, false)
		end

		local wlApplyBtn = doc:GetElementById("btn-dim-waterlevel-apply")
		if wlApplyBtn then
			wlApplyBtn:AddEventListener("click", function(event)
				local val = wlInput and tonumber(wlInput:GetAttribute("value"))
				if val and val ~= 0 then
					Spring.SendLuaRulesMsg("$wl$:" .. tostring(val))
					if wlInput then wlInput:SetAttribute("value", "0") end
					-- Refresh extremes after a short delay via next open
					refreshDimExtremes()
				end
				event:StopPropagation()
			end, false)
		end

		-- Min height input
		local minHInput = doc:GetElementById("input-dim-minheight")
		if minHInput then
			minHInput:AddEventListener("focus", function() Spring.SDLStartTextInput(); widgetState.focusedRmlInput = minHInput end, false)
			minHInput:AddEventListener("blur", function() Spring.SDLStopTextInput(); widgetState.focusedRmlInput = nil end, false)
		end

		local minHApplyBtn = doc:GetElementById("btn-dim-minheight-apply")
		if minHApplyBtn then
			minHApplyBtn:AddEventListener("click", function(event)
				local val = minHInput and tonumber(minHInput:GetAttribute("value"))
				if val then
					Spring.SendLuaRulesMsg("$hclampmin$:" .. tostring(val))
					refreshDimExtremes()
				end
				event:StopPropagation()
			end, false)
		end

		-- Max height input
		local maxHInput = doc:GetElementById("input-dim-maxheight")
		if maxHInput then
			maxHInput:AddEventListener("focus", function() Spring.SDLStartTextInput(); widgetState.focusedRmlInput = maxHInput end, false)
			maxHInput:AddEventListener("blur", function() Spring.SDLStopTextInput(); widgetState.focusedRmlInput = nil end, false)
		end

		local maxHApplyBtn = doc:GetElementById("btn-dim-maxheight-apply")
		if maxHApplyBtn then
			maxHApplyBtn:AddEventListener("click", function(event)
				local val = maxHInput and tonumber(maxHInput:GetAttribute("value"))
				if val then
					Spring.SendLuaRulesMsg("$hclampmax$:" .. tostring(val))
					refreshDimExtremes()
				end
				event:StopPropagation()
			end, false)
		end

		local wlResetBtn = doc:GetElementById("btn-dim-reset-waterlevel")
		if wlResetBtn then
			wlResetBtn:AddEventListener("click", function(event)
				if wlInput then wlInput:SetAttribute("value", "0") end
				event:StopPropagation()
			end, false)
		end

		local boundsResetBtn = doc:GetElementById("btn-dim-reset-bounds")
		if boundsResetBtn then
			boundsResetBtn:AddEventListener("click", function(event)
				if minHInput then minHInput:SetAttribute("value", "") end
				if maxHInput then maxHInput:SetAttribute("value", "") end
				event:StopPropagation()
			end, false)
		end
	end

	-- ---- Environment Save button ----
	local envSaveBtn = doc:GetElementById("btn-env-save")
	if envSaveBtn then
		envSaveBtn:AddEventListener("click", function(event)
			playSound("save")
			-- Collect all current environment settings
			local sX, sY, sZ = gl.GetSun("pos")
			local grA = { gl.GetSun("ambient") }
			local grD = { gl.GetSun("diffuse") }
			local grS = { gl.GetSun("specular") }
			local unA = { gl.GetSun("ambient", "unit") }
			local unD = { gl.GetSun("diffuse", "unit") }
			local unS = { gl.GetSun("specular", "unit") }
			local gShadow = gl.GetSun("shadowDensity", "ground")
			local uShadow = gl.GetSun("shadowDensity", "unit")
			local fgS = gl.GetAtmosphere("fogStart")
			local fgE = gl.GetAtmosphere("fogEnd")
			local fgC = { gl.GetAtmosphere("fogColor") }
			local snC = { gl.GetAtmosphere("sunColor") }
			local skC = { gl.GetAtmosphere("skyColor") }
			local skAA = { gl.GetAtmosphere("skyAxisAngle") }
			local clC = { gl.GetAtmosphere("cloudColor") }
			local sunIntensity = widgetState.envSunIntensity or 1.0

			local smR, smG, smB, smA = gl.GetMapRendering("splatTexMults")
			local ssR, ssG, ssB, ssA = gl.GetMapRendering("splatTexScales")
			local sdnda = gl.GetMapRendering("splatDetailNormalDiffuseAlpha")
			local vW = gl.GetMapRendering("voidWater")
			local vG = gl.GetMapRendering("voidGround")

			local fmt3 = function(t) return string.format("{ %.4f, %.4f, %.4f }", t[1] or 0, t[2] or 0, t[3] or 0) end
			local fmt4 = function(t) return string.format("{ %.4f, %.4f, %.4f, %.4f }", t[1] or 0, t[2] or 0, t[3] or 0, t[4] or 0) end
			local bstr = function(v) return v and "true" or "false" end

			local outLines = {
				"-- Environment config exported from BAR Terraform Brush",
				"-- Map: " .. (Game.mapName or "unknown"),
				"-- Date: " .. os.date("%Y-%m-%d %H:%M:%S"),
				"return {",
				"\tversion = 1,",
				"\tmapName = \"" .. (Game.mapName or "unknown") .. "\",",
				"",
				"\t-- Sun direction",
				"\tsunDir = " .. fmt3({sX, sY, sZ}) .. ",",
				"",
				"\t-- Shadow density",
				"\tgroundShadowDensity = " .. string.format("%.4f", gShadow) .. ",",
				"\tmodelShadowDensity = " .. string.format("%.4f", uShadow) .. ",",
				"",
				"\t-- Ground lighting",
				"\tgroundAmbientColor = " .. fmt3(grA) .. ",",
				"\tgroundDiffuseColor = " .. fmt3(grD) .. ",",
				"\tgroundSpecularColor = " .. fmt3(grS) .. ",",
				"",
				"\t-- Unit lighting",
				"\tunitAmbientColor = " .. fmt3(unA) .. ",",
				"\tunitDiffuseColor = " .. fmt3(unD) .. ",",
				"\tunitSpecularColor = " .. fmt3(unS) .. ",",
				"",
				"\t-- Fog",
				"\tfogStart = " .. string.format("%.4f", fgS) .. ",",
				"\tfogEnd = " .. string.format("%.4f", fgE) .. ",",
				"\tfogColor = " .. fmt4(fgC) .. ",",
				"",
				"\t-- Atmosphere colors",
				"\tsunColor = " .. fmt3(snC) .. ",",
				"\tskyColor = " .. fmt3(skC) .. ",",
				"\tcloudColor = " .. fmt3(clC) .. ",",
				"",
				"\t-- Sun intensity",
				"\tsunIntensity = " .. string.format("%.4f", sunIntensity) .. ",",
				"",
				"\t-- Skybox rotation",
				"\tskyAxisAngle = " .. fmt4(skAA) .. ",",
				"",
				"\t-- Map rendering",
				"\tsplatDetailNormalDiffuseAlpha = " .. bstr(sdnda) .. ",",
				"\tsplatTexMults = " .. fmt4({smR, smG, smB, smA}) .. ",",
				"\tsplatTexScales = " .. fmt4({ssR, ssG, ssB, ssA}) .. ",",
				"\tvoidWater = " .. bstr(vW) .. ",",
				"\tvoidGround = " .. bstr(vG) .. ",",
				"",
				"\t-- Water",
				"\twater = {",
			}

			-- Add all water params
			local wParams = {
				"shoreWaves", "hasWaterPlane", "forceRendering",
				"repeatX", "repeatY", "surfaceAlpha",
				"ambientFactor", "diffuseFactor", "specularFactor", "specularPower",
				"fresnelMin", "fresnelMax", "fresnelPower",
				"perlinStartFreq", "perlinLacunarity", "perlinAmplitude", "numTiles",
				"blurBase", "blurExponent", "reflectionDistortion",
				"waveOffsetFactor", "waveLength", "waveFoamDistortion", "waveFoamIntensity",
				"causticsResolution", "causticsStrength",
			}
			local boolParams = { shoreWaves = true, hasWaterPlane = true, forceRendering = true }
			for _, p in ipairs(wParams) do
				local val = gl.GetWaterRendering(p)
				if boolParams[p] then
					outLines[#outLines + 1] = "\t\t" .. p .. " = " .. bstr(val) .. ","
				else
					outLines[#outLines + 1] = "\t\t" .. p .. " = " .. string.format("%.4f", val or 0) .. ","
				end
			end
			outLines[#outLines + 1] = "\t},"
			outLines[#outLines + 1] = ""

			-- Water colors
			outLines[#outLines + 1] = "\t-- Water colors"
			local waterColorExport = {
				{"absorb", "absorb"}, {"baseColor", "baseColor"}, {"minColor", "minColor"},
				{"surfaceColor", "surfaceColor"}, {"planeColor", "planeColor"},
				{"diffuseColor", "diffuseColor"}, {"specularColor", "specularColor"},
			}
			for _, wce in ipairs(waterColorExport) do
				local c = { gl.GetWaterRendering(wce[2]) }
				outLines[#outLines + 1] = "\twaterColors_" .. wce[1] .. " = " .. fmt3(c) .. ","
			end
			outLines[#outLines + 1] = "}"
			outLines[#outLines + 1] = ""

			local content = table.concat(outLines, "\n")
			local mapSafe = (Game.mapName or "unknown"):gsub("[^%w_%-]", "_")
			local timestamp = os.date("%Y%m%d_%H%M%S")
			local LIGHTMAPS_DIR = "Terraform Brush/Lightmaps/"
			Spring.CreateDir(LIGHTMAPS_DIR)
			local filename = LIGHTMAPS_DIR .. mapSafe .. "_environ_" .. timestamp .. ".lua"

			-- Write file
			local file = io.open(filename, "w")
			if file then
				file:write(content)
				file:close()
				Spring.Echo("[Environ] Saved environment config to: " .. filename)
			else
				Spring.Echo("[Environ] ERROR: Could not write to " .. filename)
			end
			event:StopPropagation()
		end, false)
	end
end

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

local function attachStartPosListeners(doc)
	widgetState.stpSubmodesEl = doc:GetElementById("tf-startpos-submodes")
	widgetState.stpControlsEl = doc:GetElementById("tf-startpos-controls")
	widgetState.stpShapeOptionsEl = doc:GetElementById("sp-shape-options")
	widgetState.stpShapeRowEl = doc:GetElementById("sp-shape-row")
	widgetState.stpExpressHintEl = doc:GetElementById("sp-express-hint")
	widgetState.stpStartboxHintEl = doc:GetElementById("sp-startbox-hint")

	-- Sub-mode buttons
	local stpSubModes = { "express", "shape", "startbox" }
	for _, sm in ipairs(stpSubModes) do
		local btn = doc:GetElementById("btn-sp-" .. sm)
		if btn then
			widgetState.stpSubModeButtons[sm] = btn
			btn:AddEventListener("click", function(event)
				playSound("modeSwitch")
				if WG.StartPosTool then WG.StartPosTool.setSubMode(sm) end
				event:StopPropagation()
			end, false)
		end
	end

	-- Shape buttons
	local stpShapes = { "circle", "square", "hexagon", "triangle" }
	for _, sh in ipairs(stpShapes) do
		local btn = doc:GetElementById("btn-sp-shape-" .. sh)
		if btn then
			widgetState.stpShapeButtons[sh] = btn
			btn:AddEventListener("click", function(event)
				playSound("modeSwitch")
				if WG.StartPosTool then WG.StartPosTool.setShape(sh) end
				event:StopPropagation()
			end, false)
		end
	end

	-- Ally teams slider
	local allySlider = doc:GetElementById("slider-sp-allyteams")
	if allySlider then
		trackSliderDrag(allySlider, "sp-allyteams")
		allySlider:AddEventListener("change", function(event)
			if updatingFromCode then return end
			local val = tonumber(allySlider:GetAttribute("value")) or 2
			if WG.StartPosTool then WG.StartPosTool.setNumAllyTeams(val) end
			event:StopPropagation()
		end, false)
	end
	local teamsDown = doc:GetElementById("btn-sp-teams-down")
	if teamsDown then
		teamsDown:AddEventListener("click", function(event)
			if WG.StartPosTool then
				local s = WG.StartPosTool.getState()
				WG.StartPosTool.setNumAllyTeams(s.numAllyTeams - 1)
			end
			event:StopPropagation()
		end, false)
	end
	local teamsUp = doc:GetElementById("btn-sp-teams-up")
	if teamsUp then
		teamsUp:AddEventListener("click", function(event)
			if WG.StartPosTool then
				local s = WG.StartPosTool.getState()
				WG.StartPosTool.setNumAllyTeams(s.numAllyTeams + 1)
			end
			event:StopPropagation()
		end, false)
	end

	-- Shape count slider
	local countSlider = doc:GetElementById("slider-sp-count")
	if countSlider then
		trackSliderDrag(countSlider, "sp-count")
		countSlider:AddEventListener("change", function(event)
			if updatingFromCode then return end
			local val = tonumber(countSlider:GetAttribute("value")) or 4
			if WG.StartPosTool then WG.StartPosTool.setShapeCount(val) end
			event:StopPropagation()
		end, false)
	end
	local countDown = doc:GetElementById("btn-sp-count-down")
	if countDown then
		countDown:AddEventListener("click", function(event)
			if WG.StartPosTool then
				local s = WG.StartPosTool.getState()
				WG.StartPosTool.setShapeCount(s.shapeCount - 1)
			end
			event:StopPropagation()
		end, false)
	end
	local countUp = doc:GetElementById("btn-sp-count-up")
	if countUp then
		countUp:AddEventListener("click", function(event)
			if WG.StartPosTool then
				local s = WG.StartPosTool.getState()
				WG.StartPosTool.setShapeCount(s.shapeCount + 1)
			end
			event:StopPropagation()
		end, false)
	end

	-- Shape size slider
	local sizeSlider = doc:GetElementById("slider-sp-size")
	if sizeSlider then
		trackSliderDrag(sizeSlider, "sp-size")
		sizeSlider:AddEventListener("change", function(event)
			if updatingFromCode then return end
			local val = tonumber(sizeSlider:GetAttribute("value")) or 2000
			if WG.StartPosTool then WG.StartPosTool.setRadius(val) end
			event:StopPropagation()
		end, false)
	end
	local sizeDown = doc:GetElementById("btn-sp-size-down")
	if sizeDown then
		sizeDown:AddEventListener("click", function(event)
			if WG.StartPosTool then
				local s = WG.StartPosTool.getState()
				WG.StartPosTool.setRadius(s.shapeRadius - 32)
			end
			event:StopPropagation()
		end, false)
	end
	local sizeUp = doc:GetElementById("btn-sp-size-up")
	if sizeUp then
		sizeUp:AddEventListener("click", function(event)
			if WG.StartPosTool then
				local s = WG.StartPosTool.getState()
				WG.StartPosTool.setRadius(s.shapeRadius + 32)
			end
			event:StopPropagation()
		end, false)
	end

	-- Rotation slider
	local rotSlider = doc:GetElementById("slider-sp-rotation")
	if rotSlider then
		trackSliderDrag(rotSlider, "sp-rotation")
		rotSlider:AddEventListener("change", function(event)
			if updatingFromCode then return end
			local val = tonumber(rotSlider:GetAttribute("value")) or 0
			if WG.StartPosTool then WG.StartPosTool.setRotation(val) end
			event:StopPropagation()
		end, false)
	end
	do
		local spRotCW = doc:GetElementById("btn-sp-rot-cw")
		if spRotCW then
			spRotCW:AddEventListener("click", function(event)
				if WG.StartPosTool then
					local s = WG.StartPosTool.getState()
					WG.StartPosTool.setRotation(((s and s.shapeRotation or 0) + ROTATION_STEP) % 360)
				end
				event:StopPropagation()
			end, false)
		end
		local spRotCCW = doc:GetElementById("btn-sp-rot-ccw")
		if spRotCCW then
			spRotCCW:AddEventListener("click", function(event)
				if WG.StartPosTool then
					local s = WG.StartPosTool.getState()
					WG.StartPosTool.setRotation(((s and s.shapeRotation or 0) - ROTATION_STEP) % 360)
				end
				event:StopPropagation()
			end, false)
		end
	end

	-- Random positions button
	local randomBtn = doc:GetElementById("btn-sp-random")
	if randomBtn then
		randomBtn:AddEventListener("click", function(event)
			playSound("apply")
			if WG.StartPosTool then
				local mx, my = Spring.GetMouseState()
				local _, pos = Spring.TraceScreenRay(mx, my, true)
				if pos then
					WG.StartPosTool.placeRandomPositions(pos[1], pos[3])
				else
					-- Fallback: center of map
					local mapX = Game.mapSizeX / 2
					local mapZ = Game.mapSizeZ / 2
					WG.StartPosTool.placeRandomPositions(mapX, mapZ)
				end
			end
			event:StopPropagation()
		end, false)
	end

	-- Clear all button
	local clearBtn = doc:GetElementById("btn-sp-clear")
	if clearBtn then
		clearBtn:AddEventListener("click", function(event)
			playSound("apply")
			if WG.StartPosTool then
				WG.StartPosTool.clearAllPositions()
				WG.StartPosTool.clearAllStartboxes()
			end
			event:StopPropagation()
		end, false)
	end

	-- Save button
	local saveBtn = doc:GetElementById("btn-sp-save")
	if saveBtn then
		saveBtn:AddEventListener("click", function(event)
			playSound("apply")
			if WG.StartPosTool then
				WG.StartPosTool.saveStartPositions()
				WG.StartPosTool.saveStartboxes()
			end
			event:StopPropagation()
		end, false)
	end

	-- Load button
	local loadBtn = doc:GetElementById("btn-sp-load")
	if loadBtn then
		loadBtn:AddEventListener("click", function(event)
			playSound("apply")
			if WG.StartPosTool then
				WG.StartPosTool.loadStartPositions()
				WG.StartPosTool.loadStartboxes()
			end
			event:StopPropagation()
		end, false)
	end
end

local function attachCloneToolListeners(doc)
	widgetState.cloneActive = false
	widgetState.cloneControlsEl = doc:GetElementById("tf-clone-controls")
	widgetState.clonePasteTransformsEl = doc:GetElementById("cl-paste-transforms")

	-- Clone tool launch button
	local cloneBtn = doc:GetElementById("btn-clone")
	if cloneBtn then
		cloneBtn:AddEventListener("click", function(event)
			playSound("toolSwitch")
			clearPassthrough()
			if widgetState.cloneActive then
				-- Toggle OFF
				widgetState.cloneActive = false
				if WG.CloneTool then WG.CloneTool.deactivate() end
				if WG.TerraformBrush then
					local st = WG.TerraformBrush.getState()
					WG.TerraformBrush.setMode(st and st.mode or "raise")
				end
			else
				-- Toggle ON: deactivate all other tools
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
				widgetState.decalsActive = false
				if WG.DecalPlacer then WG.DecalPlacer.deactivate() end
				widgetState.cloneActive = true
				if WG.CloneTool then WG.CloneTool.activate() end
			end
			event:StopPropagation()
		end, false)
	end

	-- Layer toggles
	local layerNames = {"terrain", "metal", "features", "splats", "grass", "decals", "weather", "lights"}
	for _, name in ipairs(layerNames) do
		local el = doc:GetElementById("btn-cl-" .. name)
		if el then
			el:AddEventListener("click", function(event)
				local isActive = el:IsClassSet("active")
				el:SetClass("active", not isActive)
				if WG.CloneTool then WG.CloneTool.setLayer(name, not isActive) end
				event:StopPropagation()
			end, false)
		end
	end

	-- Copy button
	local copyBtn = doc:GetElementById("btn-cl-copy")
	if copyBtn then
		copyBtn:AddEventListener("click", function(event)
			if WG.CloneTool then WG.CloneTool.doCopy() end
			event:StopPropagation()
		end, false)
	end

	-- Paste button
	local pasteBtn = doc:GetElementById("btn-cl-paste")
	if pasteBtn then
		pasteBtn:AddEventListener("click", function(event)
			if WG.CloneTool then WG.CloneTool.startPaste() end
			event:StopPropagation()
		end, false)
	end

	-- Clear button
	local clearBtn = doc:GetElementById("btn-cl-clear")
	if clearBtn then
		clearBtn:AddEventListener("click", function(event)
			if WG.CloneTool then WG.CloneTool.cancelOperation() end
			event:StopPropagation()
		end, false)
	end

	-- Rotation slider
	local rotSlider = doc:GetElementById("slider-cl-rotation")
	if rotSlider then
		trackSliderDrag(rotSlider, "cl-rotation")
		rotSlider:AddEventListener("change", function(event)
			if updatingFromCode then return end
			local val = tonumber(rotSlider:GetAttribute("value")) or 0
			if WG.CloneTool then WG.CloneTool.setRotation(val) end
			event:StopPropagation()
		end, false)
	end
	local clRotCW = doc:GetElementById("btn-cl-rot-cw")
	if clRotCW then
		clRotCW:AddEventListener("click", function(event)
			if WG.CloneTool then
				local st = WG.CloneTool.getState()
				WG.CloneTool.setRotation(((st and st.pasteRotation or 0) + ROTATION_STEP) % 360)
			end
			event:StopPropagation()
		end, false)
	end
	local clRotCCW = doc:GetElementById("btn-cl-rot-ccw")
	if clRotCCW then
		clRotCCW:AddEventListener("click", function(event)
			if WG.CloneTool then
				local st = WG.CloneTool.getState()
				WG.CloneTool.setRotation(((st and st.pasteRotation or 0) - ROTATION_STEP) % 360)
			end
			event:StopPropagation()
		end, false)
	end

	-- Height offset slider
	local heightSlider = doc:GetElementById("slider-cl-height")
	if heightSlider then
		trackSliderDrag(heightSlider, "cl-height")
		heightSlider:AddEventListener("change", function(event)
			if updatingFromCode then return end
			local val = tonumber(heightSlider:GetAttribute("value")) or 0
			if WG.CloneTool then WG.CloneTool.setHeightOffset(val) end
			event:StopPropagation()
		end, false)
	end
	local clHeightUp = doc:GetElementById("btn-cl-height-up")
	if clHeightUp then
		clHeightUp:AddEventListener("click", function(event)
			if WG.CloneTool then
				local st = WG.CloneTool.getState()
				local cur = (st and st.pasteHeightOffset or 0)
				WG.CloneTool.setHeightOffset(math.min(500, cur + 10))
			end
			event:StopPropagation()
		end, false)
	end
	local clHeightDown = doc:GetElementById("btn-cl-height-down")
	if clHeightDown then
		clHeightDown:AddEventListener("click", function(event)
			if WG.CloneTool then
				local st = WG.CloneTool.getState()
				local cur = (st and st.pasteHeightOffset or 0)
				WG.CloneTool.setHeightOffset(math.max(-500, cur - 10))
			end
			event:StopPropagation()
		end, false)
	end

	-- Mirror X button
	local mirXBtn = doc:GetElementById("btn-cl-mirror-x")
	if mirXBtn then
		mirXBtn:AddEventListener("click", function(event)
			local isActive = mirXBtn:IsClassSet("active")
			mirXBtn:SetClass("active", not isActive)
			if WG.CloneTool then WG.CloneTool.setMirrorX(not isActive) end
			event:StopPropagation()
		end, false)
	end

	-- Mirror Z button
	local mirZBtn = doc:GetElementById("btn-cl-mirror-z")
	if mirZBtn then
		mirZBtn:AddEventListener("click", function(event)
			local isActive = mirZBtn:IsClassSet("active")
			mirZBtn:SetClass("active", not isActive)
			if WG.CloneTool then WG.CloneTool.setMirrorZ(not isActive) end
			event:StopPropagation()
		end, false)
	end

	-- Terrain quality buttons
	local qualityBtns = {
		doc:GetElementById("btn-cl-quality-full"),
		doc:GetElementById("btn-cl-quality-balanced"),
		doc:GetElementById("btn-cl-quality-fast"),
	}
	local qualityNames = { "full", "balanced", "fast" }
	for qi = 1, 3 do
		local btn = qualityBtns[qi]
		local qName = qualityNames[qi]
		if btn then
			btn:AddEventListener("click", function(event)
				if WG.CloneTool then WG.CloneTool.setTerrainQuality(qName) end
				for j = 1, 3 do
					if qualityBtns[j] then qualityBtns[j]:SetClass("active", j == qi) end
				end
				event:StopPropagation()
			end, false)
		end
	end

	-- Undo button
	local undoBtn = doc:GetElementById("btn-cl-undo")
	if undoBtn then
		undoBtn:AddEventListener("click", function(event)
			if WG.CloneTool and WG.CloneTool.undo then
				WG.CloneTool.undo()
			end
			event:StopPropagation()
		end, false)
	end

	-- Redo button
	local redoBtn = doc:GetElementById("btn-cl-redo")
	if redoBtn then
		redoBtn:AddEventListener("click", function(event)
			if WG.CloneTool and WG.CloneTool.redo then
				WG.CloneTool.redo()
			end
			event:StopPropagation()
		end, false)
	end

	-- History slider
	local sliderClHistory = doc:GetElementById("slider-cl-history")
	if sliderClHistory then
		trackSliderDrag(sliderClHistory, "cl-history")
		sliderClHistory:AddEventListener("change", function(event)
			if updatingFromCode then event:StopPropagation(); return end
			if not WG.CloneTool then event:StopPropagation(); return end
			local val = tonumber(sliderClHistory:GetAttribute("value")) or 0
			local clSt = WG.CloneTool.getState()
			if not clSt then event:StopPropagation(); return end
			local currentUndoCount = clSt.undoCount or 0
			local diff = val - currentUndoCount
			if diff > 0 then
				for i = 1, diff do
					WG.CloneTool.redo()
				end
			elseif diff < 0 then
				for i = 1, -diff do
					WG.CloneTool.undo()
				end
			end
			event:StopPropagation()
		end, false)
	end
end

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

local function attachEventListeners()
	local doc = widgetState.document
	if not doc then
		return
	end

	-- Safety net: clear drag state if mouseup happens anywhere on document
	doc:AddEventListener("mouseup", function() draggingSlider = nil end, false)

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
			if updatingFromCode then event:StopPropagation(); return end
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

	-- Metal undo/redo (shares terraform undo system)
	local mbUndoBtn = doc:GetElementById("btn-mb-undo")
	if mbUndoBtn then
		mbUndoBtn:AddEventListener("click", function(event)
			playSound("undo")
			if WG.TerraformBrush then WG.TerraformBrush.undo() end
			event:StopPropagation()
		end, false)
	end

	local mbRedoBtn = doc:GetElementById("btn-mb-redo")
	if mbRedoBtn then
		mbRedoBtn:AddEventListener("click", function(event)
			playSound("undo")
			if WG.TerraformBrush then WG.TerraformBrush.redo() end
			event:StopPropagation()
		end, false)
	end

	local mbSliderHistory = doc:GetElementById("slider-mb-history")
	if mbSliderHistory then
		trackSliderDrag(mbSliderHistory, "mb-history")
		mbSliderHistory:AddEventListener("change", function(event)
			if updatingFromCode then event:StopPropagation(); return end
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
			if not updatingFromCode and WG.TerraformBrush then
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
			if not updatingFromCode and WG.TerraformBrush then
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
			if not updatingFromCode and WG.TerraformBrush then
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
			if not updatingFromCode and WG.TerraformBrush then
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
			if not updatingFromCode and WG.TerraformBrush then
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
			if not updatingFromCode and WG.TerraformBrush then
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
			if not updatingFromCode and WG.TerraformBrush then
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
			if updatingFromCode then event:StopPropagation(); return end
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
			if updatingFromCode then event:StopPropagation(); return end
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
				if not updatingFromCode and WG.TerraformBrush then
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
				if not updatingFromCode and WG.TerraformBrush then
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
				if not updatingFromCode then
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
				if not updatingFromCode and WG.TerraformBrush then
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
				if not updatingFromCode and WG.TerraformBrush then
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
					WG.DecalPlacer.setMode("scatter")
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

	-- ============ Metal Brush controls ============

	widgetState.mbSubmodesEl = doc:GetElementById("tf-metal-submodes")
	widgetState.mbControlsEl = doc:GetElementById("tf-metal-controls")

	widgetState.mbSubModeButtons = {}
	widgetState.mbSubModeButtons.paint = doc:GetElementById("btn-mb-paint")
	widgetState.mbSubModeButtons.stamp = doc:GetElementById("btn-mb-stamp")
	widgetState.mbSubModeButtons.remove = doc:GetElementById("btn-mb-remove")

	for mbMode, element in pairs(widgetState.mbSubModeButtons) do
		if element then
			element:AddEventListener("click", function(event)
				playSound("modeSwitch")
				if WG.MetalBrush then WG.MetalBrush.setSubMode(mbMode) end
				setActiveClass(widgetState.mbSubModeButtons, mbMode)
				event:StopPropagation()
			end, false)
		end
	end

	local mbSliderValue = doc:GetElementById("slider-metal-value")
	if mbSliderValue then
		trackSliderDrag(mbSliderValue, "mb-value")
		mbSliderValue:AddEventListener("change", function(event)
			if updatingFromCode then event:StopPropagation(); return end
			local v = tonumber(mbSliderValue:GetAttribute("value")) or 0
			-- Logarithmic mapping: 0.01 .. 50.0
			local mv = 0.01 * math.exp(v / 1000 * math.log(50.0 / 0.01))
			if WG.MetalBrush then WG.MetalBrush.setMetalValue(mv) end
			local mbLabel = doc:GetElementById("mb-value-label")
			if mbLabel then mbLabel.inner_rml = string.format("%.1f", mv) end
			event:StopPropagation()
		end, false)
	end

	do
		local valUp = doc:GetElementById("btn-metal-value-up")
		if valUp then
			valUp:AddEventListener("click", function(event)
				if WG.MetalBrush then
					local s = WG.MetalBrush.getState()
					local cur = s and s.metalValue or 2.0
					WG.MetalBrush.setMetalValue(cur * 1.1)
				end
				event:StopPropagation()
			end, false)
		end
		local valDn = doc:GetElementById("btn-metal-value-down")
		if valDn then
			valDn:AddEventListener("click", function(event)
				if WG.MetalBrush then
					local s = WG.MetalBrush.getState()
					local cur = s and s.metalValue or 2.0
					WG.MetalBrush.setMetalValue(cur / 1.1)
				end
				event:StopPropagation()
			end, false)
		end
	end

	local mbSaveBtn = doc:GetElementById("btn-metal-save")
	if mbSaveBtn then
		mbSaveBtn:AddEventListener("click", function(event)
			playSound("save")
			if WG.MetalBrush then WG.MetalBrush.saveMetalMap() end
			event:StopPropagation()
		end, false)
	end

	local mbLoadBtn = doc:GetElementById("btn-metal-load")
	if mbLoadBtn then
		mbLoadBtn:AddEventListener("click", function(event)
			playSound("apply")
			if WG.MetalBrush then WG.MetalBrush.loadMetalMap() end
			event:StopPropagation()
		end, false)
	end

	local mbCleanBtn = doc:GetElementById("btn-metal-clean")
	local mbCleanLabel = doc:GetElementById("metal-clean-label")
	if mbCleanBtn then
		mbCleanBtn:AddEventListener("click", function(event)
			if widgetState.metalCleanConfirmExpiry > 0 then
				-- Second click: confirmed
				widgetState.metalCleanConfirmExpiry = 0
				mbCleanBtn:SetClass("confirming", false)
				if mbCleanLabel then mbCleanLabel.inner_rml = "CLEAN" end
				playSound("reset")
				if WG.MetalBrush then WG.MetalBrush.clearMetalMap() end
			else
				-- First click: ask for confirmation
				widgetState.metalCleanConfirmExpiry = (Spring.GetGameSeconds() or 0) + 3
				mbCleanBtn:SetClass("confirming", true)
				if mbCleanLabel then mbCleanLabel.inner_rml = "ARE YOU SURE?" end
				playSound("toggleOn")
			end
			event:StopPropagation()
		end, false)
	end

	-- Metal shape buttons (removed; metal now uses the shared tf-shape-row)
	widgetState.mbShapeButtons = {}

	-- Metal size slider (scoped to avoid function-level local overflow)
	do
		local sl = doc:GetElementById("slider-mb-size")
		if sl then
			trackSliderDrag(sl, "mb-size")
			sl:AddEventListener("change", function(event)
				if not updatingFromCode and WG.TerraformBrush then
					local val = tonumber(sl:GetAttribute("value")) or 100
					WG.TerraformBrush.setRadius(val)
				end
				event:StopPropagation()
			end, false)
		end
		local up = doc:GetElementById("btn-mb-size-up")
		if up then
			up:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					WG.TerraformBrush.setRadius(state.radius + RADIUS_STEP)
				end
				event:StopPropagation()
			end, false)
		end
		local dn = doc:GetElementById("btn-mb-size-down")
		if dn then
			dn:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					WG.TerraformBrush.setRadius(state.radius - RADIUS_STEP)
				end
				event:StopPropagation()
			end, false)
		end
	end

	-- Metal rotation slider
	do
		local sl = doc:GetElementById("slider-mb-rotation")
		if sl then
			trackSliderDrag(sl, "mb-rotation")
			sl:AddEventListener("change", function(event)
				if not updatingFromCode and WG.TerraformBrush then
					local val = tonumber(sl:GetAttribute("value")) or 0
					WG.TerraformBrush.setRotation(val)
				end
				event:StopPropagation()
			end, false)
		end
		local cw = doc:GetElementById("btn-mb-rot-cw")
		if cw then
			cw:AddEventListener("click", function(event)
				if WG.TerraformBrush then WG.TerraformBrush.rotate(ROTATION_STEP) end
				event:StopPropagation()
			end, false)
		end
		local ccw = doc:GetElementById("btn-mb-rot-ccw")
		if ccw then
			ccw:AddEventListener("click", function(event)
				if WG.TerraformBrush then WG.TerraformBrush.rotate(-ROTATION_STEP) end
				event:StopPropagation()
			end, false)
		end
	end

	-- Metal length slider
	do
		local sl = doc:GetElementById("slider-mb-length")
		if sl then
			trackSliderDrag(sl, "mb-length")
			sl:AddEventListener("change", function(event)
				if not updatingFromCode and WG.TerraformBrush then
					local val = tonumber(sl:GetAttribute("value")) or 10
					WG.TerraformBrush.setLengthScale(val / 10)
				end
				event:StopPropagation()
			end, false)
		end
		local up = doc:GetElementById("btn-mb-length-up")
		if up then
			up:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					WG.TerraformBrush.setLengthScale(state.lengthScale + LENGTH_SCALE_STEP)
				end
				event:StopPropagation()
			end, false)
		end
		local dn = doc:GetElementById("btn-mb-length-down")
		if dn then
			dn:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					WG.TerraformBrush.setLengthScale(state.lengthScale - LENGTH_SCALE_STEP)
				end
				event:StopPropagation()
			end, false)
		end
	end

	-- Metal curve/falloff slider
	do
		local sl = doc:GetElementById("slider-mb-curve")
		if sl then
			trackSliderDrag(sl, "mb-curve")
			sl:AddEventListener("change", function(event)
				if not updatingFromCode and WG.TerraformBrush then
					local val = tonumber(sl:GetAttribute("value")) or 10
					WG.TerraformBrush.setCurve(val / 10)
				end
				event:StopPropagation()
			end, false)
		end
		local up = doc:GetElementById("btn-mb-curve-up")
		if up then
			up:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					WG.TerraformBrush.setCurve(state.curve + CURVE_STEP)
				end
				event:StopPropagation()
			end, false)
		end
		local dn = doc:GetElementById("btn-mb-curve-down")
		if dn then
			dn:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					WG.TerraformBrush.setCurve(state.curve - CURVE_STEP)
				end
				event:StopPropagation()
			end, false)
		end
	end

	-- ============ Grass Brush controls ============

	widgetState.gbSubmodesEl = doc:GetElementById("tf-grass-submodes")
	widgetState.gbControlsEl = doc:GetElementById("tf-grass-controls")
	widgetState.gbSubModeButtons = {}
	widgetState.gbSubModeButtons.paint = doc:GetElementById("btn-gb-paint")
	widgetState.gbSubModeButtons.fill = doc:GetElementById("btn-gb-fill")
	widgetState.gbSubModeButtons.erase = doc:GetElementById("btn-gb-erase")

	for gbMode, element in pairs(widgetState.gbSubModeButtons) do
		if element then
			element:AddEventListener("click", function(event)
				playSound("modeSwitch")
				if WG.GrassBrush then WG.GrassBrush.setSubMode(gbMode) end
				setActiveClass(widgetState.gbSubModeButtons, gbMode)
				event:StopPropagation()
			end, false)
		end
	end

	do
		local sl = doc:GetElementById("slider-grass-density")
		if sl then
			trackSliderDrag(sl, "gb-density")
			sl:AddEventListener("change", function(event)
				if updatingFromCode then event:StopPropagation(); return end
				local v = tonumber(sl:GetAttribute("value")) or 80
				local density = v / 100
				if WG.GrassBrush then WG.GrassBrush.setDensity(density) end
				local label = doc:GetElementById("gb-density-label")
				if label then label.inner_rml = tostring(math.floor(density * 100 + 0.5)) .. "%" end
				event:StopPropagation()
			end, false)
		end
		local densUp = doc:GetElementById("btn-grass-density-up")
		if densUp then
			densUp:AddEventListener("click", function(event)
				if WG.GrassBrush then
					local s = WG.GrassBrush.getState()
					local cur = s and s.density or 0.8
					WG.GrassBrush.setDensity(math.min(1.0, cur + 0.05))
				end
				event:StopPropagation()
			end, false)
		end
		local densDn = doc:GetElementById("btn-grass-density-down")
		if densDn then
			densDn:AddEventListener("click", function(event)
				if WG.GrassBrush then
					local s = WG.GrassBrush.getState()
					local cur = s and s.density or 0.8
					WG.GrassBrush.setDensity(math.max(0.0, cur - 0.05))
				end
				event:StopPropagation()
			end, false)
		end
	end

	do
		local btn = doc:GetElementById("btn-grass-save")
		if btn then
			btn:AddEventListener("click", function(event)
				playSound("save")
				if WG.GrassBrush then WG.GrassBrush.saveGrassMap() end
				event:StopPropagation()
			end, false)
		end
	end

	-- Grass undo/redo history controls
	do
		local btnUndo = doc:GetElementById("btn-gb-undo")
		if btnUndo then
			btnUndo:AddEventListener("click", function(event)
				if WG.GrassBrush then playSound("undo"); WG.GrassBrush.undo() end
				event:StopPropagation()
			end, false)
		end

		local btnRedo = doc:GetElementById("btn-gb-redo")
		if btnRedo then
			btnRedo:AddEventListener("click", function(event)
				if WG.GrassBrush then playSound("redo"); WG.GrassBrush.redo() end
				event:StopPropagation()
			end, false)
		end

		local slHist = doc:GetElementById("slider-gb-history")
		if slHist then
			trackSliderDrag(slHist, "gb-history")
			slHist:AddEventListener("change", function(event)
				if updatingFromCode then event:StopPropagation(); return end
				local v = tonumber(slHist:GetAttribute("value")) or 0
				if WG.GrassBrush then WG.GrassBrush.undoToIndex(v) end
				event:StopPropagation()
			end, false)
		end
	end

	-- Grass shape buttons
	widgetState.gbShapeButtons = {}
	widgetState.gbShapeButtons.circle = doc:GetElementById("btn-gb-circle")
	widgetState.gbShapeButtons.square = doc:GetElementById("btn-gb-square")
	widgetState.gbShapeButtons.hexagon = doc:GetElementById("btn-gb-hexagon")
	widgetState.gbShapeButtons.octagon = doc:GetElementById("btn-gb-octagon")
	widgetState.gbShapeButtons.triangle = doc:GetElementById("btn-gb-triangle")

	for shape, element in pairs(widgetState.gbShapeButtons) do
		if element then
			element:AddEventListener("click", function(event)
				playSound("shapeSwitch")
				if WG.GrassBrush then
					WG.GrassBrush.setShape(shape)
				end
				setActiveClass(widgetState.gbShapeButtons, shape)
				event:StopPropagation()
			end, false)
		end
	end

	-- Grass size slider
	do
		local sl = doc:GetElementById("slider-gb-size")
		if sl then
			trackSliderDrag(sl, "gb-size")
			sl:AddEventListener("change", function(event)
				if not updatingFromCode and WG.GrassBrush then
					local val = tonumber(sl:GetAttribute("value")) or 100
					WG.GrassBrush.setRadius(val)
				end
				event:StopPropagation()
			end, false)
		end
		local up = doc:GetElementById("btn-gb-size-up")
		if up then
			up:AddEventListener("click", function(event)
				if WG.GrassBrush then
					local state = WG.GrassBrush.getState()
					WG.GrassBrush.setRadius(state.radius + RADIUS_STEP)
				end
				event:StopPropagation()
			end, false)
		end
		local dn = doc:GetElementById("btn-gb-size-down")
		if dn then
			dn:AddEventListener("click", function(event)
				if WG.GrassBrush then
					local state = WG.GrassBrush.getState()
					WG.GrassBrush.setRadius(state.radius - RADIUS_STEP)
				end
				event:StopPropagation()
			end, false)
		end
	end

	-- Grass rotation slider
	do
		local sl = doc:GetElementById("slider-gb-rotation")
		if sl then
			trackSliderDrag(sl, "gb-rotation")
			sl:AddEventListener("change", function(event)
				if not updatingFromCode and WG.GrassBrush then
					local val = tonumber(sl:GetAttribute("value")) or 0
					WG.GrassBrush.setRotation(val)
				end
				event:StopPropagation()
			end, false)
		end
		local cw = doc:GetElementById("btn-gb-rot-cw")
		if cw then
			cw:AddEventListener("click", function(event)
				if WG.GrassBrush then
					local state = WG.GrassBrush.getState()
					WG.GrassBrush.setRotation((state.rotationDeg or 0) + ROTATION_STEP)
				end
				event:StopPropagation()
			end, false)
		end
		local ccw = doc:GetElementById("btn-gb-rot-ccw")
		if ccw then
			ccw:AddEventListener("click", function(event)
				if WG.GrassBrush then
					local state = WG.GrassBrush.getState()
					WG.GrassBrush.setRotation((state.rotationDeg or 0) - ROTATION_STEP)
				end
				event:StopPropagation()
			end, false)
		end
	end

	-- Grass curve/falloff slider
	do
		local sl = doc:GetElementById("slider-gb-curve")
		if sl then
			trackSliderDrag(sl, "gb-curve")
			sl:AddEventListener("change", function(event)
				if not updatingFromCode and WG.GrassBrush then
					local val = tonumber(sl:GetAttribute("value")) or 10
					WG.GrassBrush.setCurve(val / 10)
				end
				event:StopPropagation()
			end, false)
		end
		local up = doc:GetElementById("btn-gb-curve-up")
		if up then
			up:AddEventListener("click", function(event)
				if WG.GrassBrush then
					local state = WG.GrassBrush.getState()
					WG.GrassBrush.setCurve(state.curve + CURVE_STEP)
				end
				event:StopPropagation()
			end, false)
		end
		local dn = doc:GetElementById("btn-gb-curve-down")
		if dn then
			dn:AddEventListener("click", function(event)
				if WG.GrassBrush then
					local state = WG.GrassBrush.getState()
					WG.GrassBrush.setCurve(state.curve - CURVE_STEP)
				end
				event:StopPropagation()
			end, false)
		end
	end

	-- Grass length scale slider
	do
		local sl = doc:GetElementById("slider-gb-length")
		if sl then
			trackSliderDrag(sl, "gb-length")
			sl:AddEventListener("change", function(event)
				if updatingFromCode then event:StopPropagation(); return end
				local v = tonumber(sl:GetAttribute("value")) or 10
				if WG.GrassBrush then WG.GrassBrush.setLengthScale(v / 10) end
				event:StopPropagation()
			end, false)
		end
		local up = doc:GetElementById("btn-gb-length-up")
		if up then
			up:AddEventListener("click", function(event)
				if WG.GrassBrush then
					local state = WG.GrassBrush.getState()
					WG.GrassBrush.setLengthScale(state.lengthScale + 0.1)
				end
				event:StopPropagation()
			end, false)
		end
		local dn = doc:GetElementById("btn-gb-length-down")
		if dn then
			dn:AddEventListener("click", function(event)
				if WG.GrassBrush then
					local state = WG.GrassBrush.getState()
					WG.GrassBrush.setLengthScale(state.lengthScale - 0.1)
				end
				event:StopPropagation()
			end, false)
		end
	end

	-- Grass smart filter toggles
	do
		local function wireGbSmartToggle(btnId, filterKey)
			local btn = doc:GetElementById(btnId)
			if btn then
				btn:AddEventListener("click", function(event)
					if WG.GrassBrush then
						local sf = WG.GrassBrush.getState().smartFilters
						playSound(sf[filterKey] and "toggleOff" or "toggleOn")
						WG.GrassBrush.setSmartFilter(filterKey, not sf[filterKey])
					end
					event:StopPropagation()
				end, false)
			end
		end

		local toggle = doc:GetElementById("btn-gb-smart-toggle")
		if toggle then
			toggle:AddEventListener("click", function(event)
				if WG.GrassBrush then
					local st = WG.GrassBrush.getState()
					playSound(st.smartEnabled and "toggleOff" or "toggleOn")
					WG.GrassBrush.setSmartEnabled(not st.smartEnabled)
				end
				event:StopPropagation()
			end, false)
		end

		wireGbSmartToggle("btn-gb-avoid-water",    "avoidWater")
		wireGbSmartToggle("btn-gb-avoid-cliffs",   "avoidCliffs")
		wireGbSmartToggle("btn-gb-prefer-slopes",  "preferSlopes")
		wireGbSmartToggle("btn-gb-alt-min-enable", "altMinEnable")
		wireGbSmartToggle("btn-gb-alt-max-enable", "altMaxEnable")

		local slSlopeMax = doc:GetElementById("slider-gb-slope-max")
		if slSlopeMax then
			trackSliderDrag(slSlopeMax, "gb-slope-max")
			slSlopeMax:AddEventListener("change", function(event)
				if updatingFromCode then event:StopPropagation(); return end
				local v = tonumber(slSlopeMax:GetAttribute("value")) or 45
				if WG.GrassBrush then WG.GrassBrush.setSmartFilter("slopeMax", v) end
				event:StopPropagation()
			end, false)
		end

		local slSlopeMin = doc:GetElementById("slider-gb-slope-min")
		if slSlopeMin then
			trackSliderDrag(slSlopeMin, "gb-slope-min")
			slSlopeMin:AddEventListener("change", function(event)
				if updatingFromCode then event:StopPropagation(); return end
				local v = tonumber(slSlopeMin:GetAttribute("value")) or 10
				if WG.GrassBrush then WG.GrassBrush.setSmartFilter("slopeMin", v) end
				event:StopPropagation()
			end, false)
		end

		local slAltMin = doc:GetElementById("slider-gb-alt-min")
		if slAltMin then
			trackSliderDrag(slAltMin, "gb-alt-min")
			slAltMin:AddEventListener("change", function(event)
				if updatingFromCode then event:StopPropagation(); return end
				local v = tonumber(slAltMin:GetAttribute("value")) or 0
				if WG.GrassBrush then WG.GrassBrush.setSmartFilter("altMin", v) end
				event:StopPropagation()
			end, false)
		end

		local slAltMax = doc:GetElementById("slider-gb-alt-max")
		if slAltMax then
			trackSliderDrag(slAltMax, "gb-alt-max")
			slAltMax:AddEventListener("change", function(event)
				if updatingFromCode then event:StopPropagation(); return end
				local v = tonumber(slAltMax:GetAttribute("value")) or 200
				if WG.GrassBrush then WG.GrassBrush.setSmartFilter("altMax", v) end
				event:StopPropagation()
			end, false)
		end

		-- Grass smart filter +/- buttons
		local function wireGbSmartBtn(btnId, filterKey, step)
			local btn = doc:GetElementById(btnId)
			if btn then
				btn:AddEventListener("click", function(event)
					if WG.GrassBrush then
						local sf = WG.GrassBrush.getState().smartFilters
						WG.GrassBrush.setSmartFilter(filterKey, (sf[filterKey] or 0) + step)
					end
					event:StopPropagation()
				end, false)
			end
		end
		wireGbSmartBtn("btn-gb-slope-max-up",   "slopeMax",  5)
		wireGbSmartBtn("btn-gb-slope-max-down", "slopeMax", -5)
		wireGbSmartBtn("btn-gb-slope-min-up",   "slopeMin",  5)
		wireGbSmartBtn("btn-gb-slope-min-down", "slopeMin", -5)
		wireGbSmartBtn("btn-gb-alt-min-up",     "altMin",   10)
		wireGbSmartBtn("btn-gb-alt-min-down",   "altMin",  -10)
		wireGbSmartBtn("btn-gb-alt-max-up",     "altMax",   10)
		wireGbSmartBtn("btn-gb-alt-max-down",   "altMax",  -10)
	end

	-- Grass color filter controls
	do
		local colorToggle = doc:GetElementById("btn-gb-color-toggle")
		if colorToggle then
			colorToggle:AddEventListener("click", function(event)
				if WG.GrassBrush then
					local st = WG.GrassBrush.getState()
					playSound(st.texFilterEnabled and "toggleOff" or "toggleOn")
					WG.GrassBrush.setTexFilterEnabled(not st.texFilterEnabled)
				end
				event:StopPropagation()
			end, false)
		end

		local pipetteBtn = doc:GetElementById("btn-gb-pipette")
		if pipetteBtn then
			pipetteBtn:AddEventListener("click", function(event)
				if WG.GrassBrush then
					local st = WG.GrassBrush.getState()
					if st.pipetteMode then
						WG.GrassBrush.setPipetteMode(false)
					else
						playSound("click")
						WG.GrassBrush.setPipetteMode(true)
					end
				end
				event:StopPropagation()
			end, false)
		end

		local slThresh = doc:GetElementById("slider-gb-color-thresh")
		if slThresh then
			trackSliderDrag(slThresh, "gb-color-thresh")
			slThresh:AddEventListener("change", function(event)
				if updatingFromCode then event:StopPropagation(); return end
				local v = tonumber(slThresh:GetAttribute("value")) or 35
				if WG.GrassBrush then WG.GrassBrush.setTexFilterThreshold(v / 100) end
				event:StopPropagation()
			end, false)
		end

		local slPad = doc:GetElementById("slider-gb-color-pad")
		if slPad then
			trackSliderDrag(slPad, "gb-color-pad")
			slPad:AddEventListener("change", function(event)
				if updatingFromCode then event:StopPropagation(); return end
				local v = tonumber(slPad:GetAttribute("value")) or 0
				if WG.GrassBrush then WG.GrassBrush.setTexFilterPadding(v) end
				event:StopPropagation()
			end, false)
		end

		local excludeToggle = doc:GetElementById("btn-gb-exclude-toggle")
		if excludeToggle then
			excludeToggle:AddEventListener("click", function(event)
				if WG.GrassBrush then
					local st = WG.GrassBrush.getState()
					playSound(st.texExcludeEnabled and "toggleOff" or "toggleOn")
					WG.GrassBrush.setTexExcludeEnabled(not st.texExcludeEnabled)
				end
				event:StopPropagation()
			end, false)
		end

		local excludePipetteBtn = doc:GetElementById("btn-gb-exclude-pipette")
		if excludePipetteBtn then
			excludePipetteBtn:AddEventListener("click", function(event)
				if WG.GrassBrush then
					local st = WG.GrassBrush.getState()
					if st.pipetteExcludeMode then
						WG.GrassBrush.setPipetteExcludeMode(false)
					else
						playSound("click")
						WG.GrassBrush.setPipetteExcludeMode(true)
					end
				end
				event:StopPropagation()
			end, false)
		end
	end

	-- ============ Feature Placer controls ============
	;(function()

	-- Cache section elements for visibility toggling
	widgetState.tfControlsEl = doc:GetElementById("tf-terraform-controls")
	widgetState.fpControlsEl = doc:GetElementById("tf-feature-controls")
	widgetState.fpSubmodesEl = doc:GetElementById("tf-feature-submodes")
	widgetState.shapeRowEl = doc:GetElementById("tf-shape-row")
	widgetState.smoothSubmodesEl = doc:GetElementById("tf-smooth-submodes")
	widgetState.fullRestoreEl = doc:GetElementById("btn-full-restore")
	widgetState.fullRestoreLabel1 = doc:GetElementById("full-restore-label-1")
	widgetState.fullRestoreLabel2 = doc:GetElementById("full-restore-label-2")
	widgetState.metalCleanEl = doc:GetElementById("btn-metal-clean")
	widgetState.metalCleanLabel = doc:GetElementById("metal-clean-label")

	-- Feature sub-mode buttons
	widgetState.fpSubModeButtons.scatter = doc:GetElementById("btn-fp-scatter")
	widgetState.fpSubModeButtons.point = doc:GetElementById("btn-fp-point")
	widgetState.fpSubModeButtons.remove = doc:GetElementById("btn-fp-remove")

	for fmode, element in pairs(widgetState.fpSubModeButtons) do
		if element then
			element:AddEventListener("click", function(event)
				playSound("modeSwitch")
				if WG.FeaturePlacer then
					WG.FeaturePlacer.setMode(fmode)
				end
				setActiveClass(widgetState.fpSubModeButtons, fmode)
				event:StopPropagation()
			end, false)
		end
	end

	-- Distribution buttons
	widgetState.fpDistButtons.random    = doc:GetElementById("btn-fp-dist-random")
	widgetState.fpDistButtons.regular   = doc:GetElementById("btn-fp-dist-regular")
	widgetState.fpDistButtons.clustered = doc:GetElementById("btn-fp-dist-clustered")

	for dist, element in pairs(widgetState.fpDistButtons) do
		if element then
			element:AddEventListener("click", function(event)
				playSound("shapeSwitch")
				if WG.FeaturePlacer then
					WG.FeaturePlacer.setDistribution(dist)
				end
				setActiveClass(widgetState.fpDistButtons, dist)
				event:StopPropagation()
			end, false)
		end
	end

	-- Feature size slider + buttons
	local fpSliderSize = doc:GetElementById("fp-slider-size")
	if fpSliderSize then
		trackSliderDrag(fpSliderSize, "fp-size")
		fpSliderSize:AddEventListener("change", function(event)
			if not updatingFromCode and WG.FeaturePlacer then
				local val = tonumber(fpSliderSize:GetAttribute("value")) or 200
				WG.FeaturePlacer.setRadius(val)
			end
			event:StopPropagation()
		end, false)
	end

	local fpSizeUp = doc:GetElementById("btn-fp-size-up")
	if fpSizeUp then
		fpSizeUp:AddEventListener("click", function(event)
			if WG.FeaturePlacer then
				local st = WG.FeaturePlacer.getState()
				WG.FeaturePlacer.setRadius(st.radius + RADIUS_STEP * 4)
			end
			event:StopPropagation()
		end, false)
	end

	local fpSizeDown = doc:GetElementById("btn-fp-size-down")
	if fpSizeDown then
		fpSizeDown:AddEventListener("click", function(event)
			if WG.FeaturePlacer then
				local st = WG.FeaturePlacer.getState()
				WG.FeaturePlacer.setRadius(st.radius - RADIUS_STEP * 4)
			end
			event:StopPropagation()
		end, false)
	end

	-- Feature rotation slider + buttons
	local fpSliderRotation = doc:GetElementById("fp-slider-rotation")
	if fpSliderRotation then
		trackSliderDrag(fpSliderRotation, "fp-rotation")
		fpSliderRotation:AddEventListener("change", function(event)
			if not updatingFromCode and WG.FeaturePlacer then
				local val = tonumber(fpSliderRotation:GetAttribute("value")) or 0
				WG.FeaturePlacer.setRotation(val)
			end
			event:StopPropagation()
		end, false)
	end

	local fpRotCW = doc:GetElementById("btn-fp-rot-cw")
	if fpRotCW then
		fpRotCW:AddEventListener("click", function(event)
			if WG.FeaturePlacer then WG.FeaturePlacer.rotate(ROTATION_STEP) end
			event:StopPropagation()
		end, false)
	end

	local fpRotCCW = doc:GetElementById("btn-fp-rot-ccw")
	if fpRotCCW then
		fpRotCCW:AddEventListener("click", function(event)
			if WG.FeaturePlacer then WG.FeaturePlacer.rotate(-ROTATION_STEP) end
			event:StopPropagation()
		end, false)
	end

	-- Feature rotation randomness slider
	local fpSliderRotRandom = doc:GetElementById("fp-slider-rot-random")
	if fpSliderRotRandom then
		trackSliderDrag(fpSliderRotRandom, "fp-rot-random")
		fpSliderRotRandom:AddEventListener("change", function(event)
			if not updatingFromCode and WG.FeaturePlacer then
				local val = tonumber(fpSliderRotRandom:GetAttribute("value")) or 100
				WG.FeaturePlacer.setRotRandom(val)
			end
			event:StopPropagation()
		end, false)
	end

	local fpRotRndDown = doc:GetElementById("btn-fp-rot-random-down")
	if fpRotRndDown then
		fpRotRndDown:AddEventListener("click", function(event)
			if WG.FeaturePlacer then
				local st = WG.FeaturePlacer.getState()
				WG.FeaturePlacer.setRotRandom(math.max(0, (st.rotRandom or 100) - 5))
			end
			event:StopPropagation()
		end, false)
	end

	local fpRotRndUp = doc:GetElementById("btn-fp-rot-random-up")
	if fpRotRndUp then
		fpRotRndUp:AddEventListener("click", function(event)
			if WG.FeaturePlacer then
				local st = WG.FeaturePlacer.getState()
				WG.FeaturePlacer.setRotRandom(math.min(100, (st.rotRandom or 0) + 5))
			end
			event:StopPropagation()
		end, false)
	end

	-- Feature count slider + buttons
	local fpSliderCount = doc:GetElementById("fp-slider-count")
	if fpSliderCount then
		trackSliderDrag(fpSliderCount, "fp-count")
		fpSliderCount:AddEventListener("change", function(event)
			if not updatingFromCode and WG.FeaturePlacer then
				local val = tonumber(fpSliderCount:GetAttribute("value")) or 10
				WG.FeaturePlacer.setFeatureCount(val)
			end
			event:StopPropagation()
		end, false)
	end

	local fpCountUp = doc:GetElementById("btn-fp-count-up")
	if fpCountUp then
		fpCountUp:AddEventListener("click", function(event)
			if WG.FeaturePlacer then
				local st = WG.FeaturePlacer.getState()
				WG.FeaturePlacer.setFeatureCount(st.featureCount + 1)
			end
			event:StopPropagation()
		end, false)
	end

	local fpCountDown = doc:GetElementById("btn-fp-count-down")
	if fpCountDown then
		fpCountDown:AddEventListener("click", function(event)
			if WG.FeaturePlacer then
				local st = WG.FeaturePlacer.getState()
				WG.FeaturePlacer.setFeatureCount(st.featureCount - 1)
			end
			event:StopPropagation()
		end, false)
	end

	-- Feature cadence slider + buttons
	local fpSliderCadence = doc:GetElementById("fp-slider-cadence")
	if fpSliderCadence then
		trackSliderDrag(fpSliderCadence, "fp-cadence")
		fpSliderCadence:AddEventListener("change", function(event)
			if not updatingFromCode and WG.FeaturePlacer then
				local sliderVal = tonumber(fpSliderCadence:GetAttribute("value")) or 0
				WG.FeaturePlacer.setCadence(sliderToCadence(sliderVal))
			end
			event:StopPropagation()
		end, false)
	end

	local fpCadenceUp = doc:GetElementById("btn-fp-cadence-up")
	if fpCadenceUp then
		fpCadenceUp:AddEventListener("click", function(event)
			if WG.FeaturePlacer then
				local st = WG.FeaturePlacer.getState()
				local step = math.max(1, math.floor(st.cadence * 0.2))
				WG.FeaturePlacer.setCadence(st.cadence + step)
			end
			event:StopPropagation()
		end, false)
	end

	local fpCadenceDown = doc:GetElementById("btn-fp-cadence-down")
	if fpCadenceDown then
		fpCadenceDown:AddEventListener("click", function(event)
			if WG.FeaturePlacer then
				local st = WG.FeaturePlacer.getState()
				local step = math.max(1, math.floor(st.cadence * 0.2))
				WG.FeaturePlacer.setCadence(st.cadence - step)
			end
			event:StopPropagation()
		end, false)
	end

	-- Feature undo/redo buttons
	local fpUndoBtn = doc:GetElementById("btn-fp-undo")
	if fpUndoBtn then
		fpUndoBtn:AddEventListener("click", function(event)
			playSound("undo")
			if WG.FeaturePlacer then WG.FeaturePlacer.undo() end
			event:StopPropagation()
		end, false)
	end

	local fpRedoBtn = doc:GetElementById("btn-fp-redo")
	if fpRedoBtn then
		fpRedoBtn:AddEventListener("click", function(event)
			playSound("undo")
			if WG.FeaturePlacer then WG.FeaturePlacer.redo() end
			event:StopPropagation()
		end, false)
	end

	-- Feature history slider
	local sliderFpHistory = doc:GetElementById("slider-fp-history")
	if sliderFpHistory then
		trackSliderDrag(sliderFpHistory, "fp-history")
		sliderFpHistory:AddEventListener("change", function(event)
			if updatingFromCode then event:StopPropagation(); return end
			if not WG.FeaturePlacer then event:StopPropagation(); return end
			local val = tonumber(sliderFpHistory:GetAttribute("value")) or 0
			local fpSt = WG.FeaturePlacer.getState()
			if not fpSt then event:StopPropagation(); return end
			local currentUndoCount = fpSt.undoCount or 0
			local diff = val - currentUndoCount
			if diff > 0 then
				for i = 1, diff do
					WG.FeaturePlacer.redo()
				end
			elseif diff < 0 then
				for i = 1, -diff do
					WG.FeaturePlacer.undo()
				end
			end
			event:StopPropagation()
		end, false)
	end

	-- Feature save/load/clear buttons
	local fpSaveBtn = doc:GetElementById("btn-fp-save")
	if fpSaveBtn then
		fpSaveBtn:AddEventListener("click", function(event)
			playSound("save")
			if WG.FeaturePlacer then WG.FeaturePlacer.save() end
			event:StopPropagation()
		end, false)
	end

	local fpLoadBtn = doc:GetElementById("btn-fp-load")
	if fpLoadBtn then
		fpLoadBtn:AddEventListener("click", function(event)
			playSound("dropdown")
			-- Toggle the save list visibility and populate it
			local listEl = doc:GetElementById("fp-save-load-list")
			if listEl then
				local isHidden = listEl.class_name and listEl.class_name:find("hidden") ~= nil
				listEl:SetClass("hidden", not isHidden)
				if isHidden and WG.FeaturePlacer then
					-- Rebuild the file list
					listEl.inner_rml = ""
					local files = WG.FeaturePlacer.listSaves()
					if #files == 0 then
						listEl.inner_rml = '<div style="padding: 4dp 6dp; font-size: 0.9rem; color: #6b7280;">No saved feature maps</div>'
					else
						for _, filepath in ipairs(files) do
							local fname = filepath:match("[^/\\]+$") or filepath
							local item = doc:CreateElement("div")
							item:SetAttribute("style", "padding: 3dp 6dp; font-size: 0.9rem; color: #9ca3af; cursor: pointer; border-radius: 3dp;")
							item.inner_rml = fname
							item:AddEventListener("click", function(ev)
								if WG.FeaturePlacer then
									WG.FeaturePlacer.load(filepath)
								end
								listEl:SetClass("hidden", true)
								ev:StopPropagation()
							end, false)
							item:AddEventListener("mouseover", function()
								item:SetAttribute("style", "padding: 3dp 6dp; font-size: 0.9rem; color: #d1d5db; cursor: pointer; border-radius: 3dp; background-color: #2a2a3a;")
							end, false)
							item:AddEventListener("mouseout", function()
								item:SetAttribute("style", "padding: 3dp 6dp; font-size: 0.9rem; color: #9ca3af; cursor: pointer; border-radius: 3dp;")
							end, false)
							listEl:AppendChild(item)
						end
					end
				end
			end
			event:StopPropagation()
		end, false)
	end

	local fpClearAllBtn = doc:GetElementById("btn-fp-clearall")
	if fpClearAllBtn then
		fpClearAllBtn:AddEventListener("click", function(event)
			playSound("reset")
			if WG.FeaturePlacer then WG.FeaturePlacer.clearAll() end
			event:StopPropagation()
		end, false)
	end

	end)() -- end Feature Placer IIFE

	-- ============ Smart distribution filter controls ============
	local fpSmartToggle = doc:GetElementById("btn-fp-smart-toggle")
	if fpSmartToggle then
		fpSmartToggle:AddEventListener("click", function(event)
			if WG.FeaturePlacer then
				local st = WG.FeaturePlacer.getState()
				playSound(st.smartEnabled and "toggleOff" or "toggleOn")
				WG.FeaturePlacer.setSmartEnabled(not st.smartEnabled)
			end
			event:StopPropagation()
		end, false)
	end

	local function wireSmartToggle(btnId, filterKey)
		local btn = doc:GetElementById(btnId)
		if btn then
			btn:AddEventListener("click", function(event)
				if WG.FeaturePlacer then
					local sf = WG.FeaturePlacer.getState().smartFilters
					playSound(sf[filterKey] and "toggleOff" or "toggleOn")
					WG.FeaturePlacer.setSmartFilter(filterKey, not sf[filterKey])
				end
				event:StopPropagation()
			end, false)
		end
	end
	wireSmartToggle("btn-fp-avoid-water",    "avoidWater")
	wireSmartToggle("btn-fp-avoid-cliffs",   "avoidCliffs")
	wireSmartToggle("btn-fp-prefer-slopes",  "preferSlopes")
	wireSmartToggle("btn-fp-alt-min-enable", "altMinEnable")
	wireSmartToggle("btn-fp-alt-max-enable", "altMaxEnable")

	-- Display overlay: Grid (feature panel)
	local btnFpGridDisplay = doc:GetElementById("btn-fp-grid-overlay-display")
	if btnFpGridDisplay then
		btnFpGridDisplay:AddEventListener("click", function(event)
			if WG.TerraformBrush then
				local state = WG.TerraformBrush.getState()
				local newVal = not (state and state.gridOverlay)
				playSound(newVal and "toggleOn" or "toggleOff")
				WG.TerraformBrush.setGridOverlay(newVal)
				btnFpGridDisplay:SetClass("active", newVal)
			end
			event:StopPropagation()
		end, false)
	end

	-- Display overlay: Height Map (feature panel)
	local btnFpHeightMap = doc:GetElementById("btn-fp-height-colormap")
	if btnFpHeightMap then
		btnFpHeightMap:AddEventListener("click", function(event)
			if WG.TerraformBrush then
				local state = WG.TerraformBrush.getState()
				local newVal = not (state and state.heightColormap)
				playSound(newVal and "toggleOn" or "toggleOff")
				WG.TerraformBrush.setHeightColormap(newVal)
				btnFpHeightMap:SetClass("active", newVal)
			end
			event:StopPropagation()
		end, false)
	end

	-- Instruments: Measure (feature panel)
	local btnFpMeasure = doc:GetElementById("btn-fp-measure")
	if btnFpMeasure then
		btnFpMeasure:AddEventListener("click", function(event)
			if WG.TerraformBrush then
				local state = WG.TerraformBrush.getState()
				local newVal = not (state and state.measureActive)
				playSound(newVal and "toggleOn" or "toggleOff")
				WG.TerraformBrush.setMeasureActive(newVal)
				btnFpMeasure:SetClass("active", newVal)
			end
			event:StopPropagation()
		end, false)
	end

	-- Instruments: Symmetry (feature panel)
	local btnFpSymmetry = doc:GetElementById("btn-fp-symmetry")
	local fpSymRow = doc:GetElementById("fp-symmetry-toolbar-row")
	if btnFpSymmetry then
		btnFpSymmetry:AddEventListener("click", function(event)
			if WG.TerraformBrush then
				local state = WG.TerraformBrush.getState()
				local newVal = not (state and state.symmetryActive)
				playSound(newVal and "toggleOn" or "toggleOff")
				WG.TerraformBrush.setSymmetryActive(newVal)
				btnFpSymmetry:SetClass("active", newVal)
				if fpSymRow then fpSymRow:SetClass("hidden", not newVal) end
			end
			event:StopPropagation()
		end, false)
	end

	-- Feature panel symmetry sub-toolbar handlers
	do
		local function fpSymBtn(id, fn)
			local el = doc:GetElementById(id)
			if el then el:AddEventListener("click", function(ev) fn(ev); ev:StopPropagation() end, false) end
			return el
		end
		fpSymBtn("fp-btn-symmetry-radial", function()
			if WG.TerraformBrush then
				local s = WG.TerraformBrush.getState()
				WG.TerraformBrush.setSymmetryRadial(not (s and s.symmetryRadial))
			end
		end)
		fpSymBtn("fp-btn-symmetry-mirror-x", function()
			if WG.TerraformBrush then
				local s = WG.TerraformBrush.getState()
				WG.TerraformBrush.setSymmetryMirrorX(not (s and s.symmetryMirrorX))
			end
		end)
		fpSymBtn("fp-btn-symmetry-mirror-y", function()
			if WG.TerraformBrush then
				local s = WG.TerraformBrush.getState()
				WG.TerraformBrush.setSymmetryMirrorY(not (s and s.symmetryMirrorY))
			end
		end)
		fpSymBtn("fp-btn-symmetry-flipped", function()
			if WG.TerraformBrush then
				local s = WG.TerraformBrush.getState()
				WG.TerraformBrush.setSymmetryFlipped(not (s and s.symmetryFlipped))
			end
		end)
		fpSymBtn("fp-btn-symmetry-place-origin", function()
			if WG.TerraformBrush then
				WG.TerraformBrush.setSymmetryPlacingOrigin(true)
			end
		end)
		fpSymBtn("fp-btn-symmetry-center-origin", function()
			if WG.TerraformBrush then
				WG.TerraformBrush.setSymmetryOrigin(nil, nil)
				playSound("toggleOff")
			end
		end)
		fpSymBtn("fp-btn-symmetry-count-down", function()
			if WG.TerraformBrush then
				local s = WG.TerraformBrush.getState()
				local c = math.max(2, (s and s.symmetryRadialCount or 2) - 1)
				WG.TerraformBrush.setSymmetryRadialCount(c)
			end
		end)
		fpSymBtn("fp-btn-symmetry-count-up", function()
			if WG.TerraformBrush then
				local s = WG.TerraformBrush.getState()
				local c = math.min(16, (s and s.symmetryRadialCount or 2) + 1)
				WG.TerraformBrush.setSymmetryRadialCount(c)
			end
		end)
		fpSymBtn("fp-btn-symmetry-angle-down", function()
			if WG.TerraformBrush then
				local s = WG.TerraformBrush.getState()
				local a = ((s and s.symmetryMirrorAngle or 0) - 5) % 360
				WG.TerraformBrush.setSymmetryMirrorAngle(a)
			end
		end)
		fpSymBtn("fp-btn-symmetry-angle-up", function()
			if WG.TerraformBrush then
				local s = WG.TerraformBrush.getState()
				local a = ((s and s.symmetryMirrorAngle or 0) + 5) % 360
				WG.TerraformBrush.setSymmetryMirrorAngle(a)
			end
		end)
		local fpSymCountSlider = doc:GetElementById("fp-slider-symmetry-radial-count")
		if fpSymCountSlider then
			fpSymCountSlider:AddEventListener("change", function(ev)
				if updatingFromCode then ev:StopPropagation(); return end
				if WG.TerraformBrush then
					local v = tonumber(fpSymCountSlider:GetAttribute("value")) or 2
					WG.TerraformBrush.setSymmetryRadialCount(v)
				end
				ev:StopPropagation()
			end, false)
		end
		local fpSymAngleSlider = doc:GetElementById("fp-slider-symmetry-mirror-angle")
		if fpSymAngleSlider then
			fpSymAngleSlider:AddEventListener("change", function(ev)
				if updatingFromCode then ev:StopPropagation(); return end
				if WG.TerraformBrush then
					local v = tonumber(fpSymAngleSlider:GetAttribute("value")) or 0
					WG.TerraformBrush.setSymmetryMirrorAngle(v)
				end
				ev:StopPropagation()
			end, false)
		end
	end

	local btnFpGridOverlay = doc:GetElementById("btn-fp-grid-overlay")
	if btnFpGridOverlay then
		btnFpGridOverlay:AddEventListener("click", function(event)
			if WG.FeaturePlacer then
				local st = WG.FeaturePlacer.getState()
				local newVal = not (st and st.gridOverlay)
				WG.FeaturePlacer.setGridOverlay(newVal)
				btnFpGridOverlay:SetClass("active", newVal)
			end
			event:StopPropagation()
		end, false)
	end

	local btnFpGridSnap = doc:GetElementById("btn-fp-grid-snap")
	if btnFpGridSnap then
		btnFpGridSnap:AddEventListener("click", function(event)
			if WG.FeaturePlacer then
				local st = WG.FeaturePlacer.getState()
				local newVal = not (st and st.gridSnap)
				WG.FeaturePlacer.setGridSnap(newVal)
				btnFpGridSnap:SetClass("active", newVal)
			end
			event:StopPropagation()
		end, false)
	end

	local fpSliderSlopeMax = doc:GetElementById("fp-slider-slope-max")
	if fpSliderSlopeMax then
		trackSliderDrag(fpSliderSlopeMax, "fp-slope-max")
		fpSliderSlopeMax:AddEventListener("change", function(event)
			if not updatingFromCode and WG.FeaturePlacer then
				local val = tonumber(fpSliderSlopeMax:GetAttribute("value")) or 45
				WG.FeaturePlacer.setSmartFilter("slopeMax", val)
			end
			event:StopPropagation()
		end, false)
	end

	local fpSliderSlopeMin = doc:GetElementById("fp-slider-slope-min")
	if fpSliderSlopeMin then
		trackSliderDrag(fpSliderSlopeMin, "fp-slope-min")
		fpSliderSlopeMin:AddEventListener("change", function(event)
			if not updatingFromCode and WG.FeaturePlacer then
				local val = tonumber(fpSliderSlopeMin:GetAttribute("value")) or 10
				WG.FeaturePlacer.setSmartFilter("slopeMin", val)
			end
			event:StopPropagation()
		end, false)
	end

	local fpSliderAltMin = doc:GetElementById("fp-slider-alt-min")
	if fpSliderAltMin then
		trackSliderDrag(fpSliderAltMin, "fp-alt-min")
		fpSliderAltMin:AddEventListener("change", function(event)
			if not updatingFromCode and WG.FeaturePlacer then
				local val = tonumber(fpSliderAltMin:GetAttribute("value")) or 0
				-- Couple: clamp max up if it's below new min
				local sf = WG.FeaturePlacer.getState().smartFilters
				if sf.altMaxEnable and val > sf.altMax then
					WG.FeaturePlacer.setSmartFilter("altMax", val)
				end
				WG.FeaturePlacer.setSmartFilter("altMin", val)
			end
			event:StopPropagation()
		end, false)
	end

	local fpSliderAltMax = doc:GetElementById("fp-slider-alt-max")
	if fpSliderAltMax then
		trackSliderDrag(fpSliderAltMax, "fp-alt-max")
		fpSliderAltMax:AddEventListener("change", function(event)
			if not updatingFromCode and WG.FeaturePlacer then
				local val = tonumber(fpSliderAltMax:GetAttribute("value")) or 200
				-- Couple: clamp min down if it's above new max
				local sf = WG.FeaturePlacer.getState().smartFilters
				if sf.altMinEnable and val < sf.altMin then
					WG.FeaturePlacer.setSmartFilter("altMin", val)
				end
				WG.FeaturePlacer.setSmartFilter("altMax", val)
			end
			event:StopPropagation()
		end, false)
	end

	-- Feature placer smart filter +/- buttons
	do
		local function wireFpSmartBtn(btnId, filterKey, step)
			local btn = doc:GetElementById(btnId)
			if btn then
				btn:AddEventListener("click", function(event)
					if WG.FeaturePlacer then
						local sf = WG.FeaturePlacer.getState().smartFilters
						WG.FeaturePlacer.setSmartFilter(filterKey, (sf[filterKey] or 0) + step)
					end
					event:StopPropagation()
				end, false)
			end
		end
		wireFpSmartBtn("btn-fp-slope-max-up",   "slopeMax",  5)
		wireFpSmartBtn("btn-fp-slope-max-down", "slopeMax", -5)
		wireFpSmartBtn("btn-fp-slope-min-up",   "slopeMin",  5)
		wireFpSmartBtn("btn-fp-slope-min-down", "slopeMin", -5)
		wireFpSmartBtn("btn-fp-alt-min-up",     "altMin",   10)
		wireFpSmartBtn("btn-fp-alt-min-down",   "altMin",  -10)
		wireFpSmartBtn("btn-fp-alt-max-up",     "altMax",   10)
		wireFpSmartBtn("btn-fp-alt-max-down",   "altMax",  -10)
	end

	-- ============ Weather Brush controls ============

	widgetState.wbSubmodesEl = doc:GetElementById("tf-weather-submodes")
	widgetState.wbControlsEl = doc:GetElementById("tf-weather-controls")

	-- Weather sub-mode buttons
	widgetState.wbSubModeButtons.scatter = doc:GetElementById("btn-wb-scatter")
	widgetState.wbSubModeButtons.point = doc:GetElementById("btn-wb-point")
	widgetState.wbSubModeButtons.remove = doc:GetElementById("btn-wb-remove")

	for wmode, element in pairs(widgetState.wbSubModeButtons) do
		if element then
			element:AddEventListener("click", function(event)
				playSound("modeSwitch")
				if WG.WeatherBrush then WG.WeatherBrush.setMode(wmode) end
				setActiveClass(widgetState.wbSubModeButtons, wmode)
				event:StopPropagation()
			end, false)
		end
	end

	-- Weather distribution buttons
	widgetState.wbDistButtons.random = doc:GetElementById("btn-wb-dist-random")
	widgetState.wbDistButtons.regular = doc:GetElementById("btn-wb-dist-regular")
	widgetState.wbDistButtons.clustered = doc:GetElementById("btn-wb-dist-clustered")

	for dist, element in pairs(widgetState.wbDistButtons) do
		if element then
			element:AddEventListener("click", function(event)
				playSound("shapeSwitch")
				if WG.WeatherBrush then WG.WeatherBrush.setDistribution(dist) end
				setActiveClass(widgetState.wbDistButtons, dist)
				event:StopPropagation()
			end, false)
		end
	end

	-- Weather size slider + buttons
	local wbSliderSize = doc:GetElementById("wb-slider-size")
	if wbSliderSize then
		trackSliderDrag(wbSliderSize, "wb-size")
		wbSliderSize:AddEventListener("change", function(event)
			if not updatingFromCode and WG.WeatherBrush then
				local val = tonumber(wbSliderSize:GetAttribute("value")) or 200
				WG.WeatherBrush.setRadius(val)
			end
			event:StopPropagation()
		end, false)
	end

	local wbSizeUp = doc:GetElementById("btn-wb-size-up")
	if wbSizeUp then
		wbSizeUp:AddEventListener("click", function(event)
			if WG.WeatherBrush then
				local st = WG.WeatherBrush.getState()
				WG.WeatherBrush.setRadius(st.radius + RADIUS_STEP * 4)
			end
			event:StopPropagation()
		end, false)
	end

	local wbSizeDown = doc:GetElementById("btn-wb-size-down")
	if wbSizeDown then
		wbSizeDown:AddEventListener("click", function(event)
			if WG.WeatherBrush then
				local st = WG.WeatherBrush.getState()
				WG.WeatherBrush.setRadius(st.radius - RADIUS_STEP * 4)
			end
			event:StopPropagation()
		end, false)
	end

	-- Weather length slider + buttons
	local wbSliderLength = doc:GetElementById("wb-slider-length")
	if wbSliderLength then
		trackSliderDrag(wbSliderLength, "wb-length")
		wbSliderLength:AddEventListener("change", function(event)
			if not updatingFromCode and WG.WeatherBrush then
				local val = tonumber(wbSliderLength:GetAttribute("value")) or 10
				WG.WeatherBrush.setLengthScale(val / 10)
			end
			event:StopPropagation()
		end, false)
	end

	local wbLengthUp = doc:GetElementById("btn-wb-length-up")
	if wbLengthUp then
		wbLengthUp:AddEventListener("click", function(event)
			if WG.WeatherBrush then
				local st = WG.WeatherBrush.getState()
				WG.WeatherBrush.setLengthScale(st.lengthScale + LENGTH_SCALE_STEP)
			end
			event:StopPropagation()
		end, false)
	end

	local wbLengthDown = doc:GetElementById("btn-wb-length-down")
	if wbLengthDown then
		wbLengthDown:AddEventListener("click", function(event)
			if WG.WeatherBrush then
				local st = WG.WeatherBrush.getState()
				WG.WeatherBrush.setLengthScale(st.lengthScale - LENGTH_SCALE_STEP)
			end
			event:StopPropagation()
		end, false)
	end

	-- Weather rotation slider + buttons
	local wbSliderRotation = doc:GetElementById("wb-slider-rotation")
	if wbSliderRotation then
		trackSliderDrag(wbSliderRotation, "wb-rotation")
		wbSliderRotation:AddEventListener("change", function(event)
			if not updatingFromCode and WG.WeatherBrush then
				local val = tonumber(wbSliderRotation:GetAttribute("value")) or 0
				WG.WeatherBrush.setRotation(val)
			end
			event:StopPropagation()
		end, false)
	end

	local wbRotCW = doc:GetElementById("btn-wb-rot-cw")
	if wbRotCW then
		wbRotCW:AddEventListener("click", function(event)
			if WG.WeatherBrush then WG.WeatherBrush.rotate(ROTATION_STEP) end
			event:StopPropagation()
		end, false)
	end

	local wbRotCCW = doc:GetElementById("btn-wb-rot-ccw")
	if wbRotCCW then
		wbRotCCW:AddEventListener("click", function(event)
			if WG.WeatherBrush then WG.WeatherBrush.rotate(-ROTATION_STEP) end
			event:StopPropagation()
		end, false)
	end

	-- Weather count slider + buttons
	local wbSliderCount = doc:GetElementById("wb-slider-count")
	if wbSliderCount then
		trackSliderDrag(wbSliderCount, "wb-count")
		wbSliderCount:AddEventListener("change", function(event)
			if not updatingFromCode and WG.WeatherBrush then
				local val = tonumber(wbSliderCount:GetAttribute("value")) or 3
				WG.WeatherBrush.setSpawnCount(val)
			end
			event:StopPropagation()
		end, false)
	end

	local wbCountUp = doc:GetElementById("btn-wb-count-up")
	if wbCountUp then
		wbCountUp:AddEventListener("click", function(event)
			if WG.WeatherBrush then
				local st = WG.WeatherBrush.getState()
				WG.WeatherBrush.setSpawnCount(st.spawnCount + 1)
			end
			event:StopPropagation()
		end, false)
	end

	local wbCountDown = doc:GetElementById("btn-wb-count-down")
	if wbCountDown then
		wbCountDown:AddEventListener("click", function(event)
			if WG.WeatherBrush then
				local st = WG.WeatherBrush.getState()
				WG.WeatherBrush.setSpawnCount(st.spawnCount - 1)
			end
			event:StopPropagation()
		end, false)
	end

	-- Weather cadence slider + buttons
	local wbSliderCadence = doc:GetElementById("wb-slider-cadence")
	if wbSliderCadence then
		trackSliderDrag(wbSliderCadence, "wb-cadence")
		wbSliderCadence:AddEventListener("change", function(event)
			if not updatingFromCode and WG.WeatherBrush then
				local sliderVal = tonumber(wbSliderCadence:GetAttribute("value")) or 0
				WG.WeatherBrush.setCadence(sliderToCadence(sliderVal))
			end
			event:StopPropagation()
		end, false)
	end

	local wbCadenceUp = doc:GetElementById("btn-wb-cadence-up")
	if wbCadenceUp then
		wbCadenceUp:AddEventListener("click", function(event)
			if WG.WeatherBrush then
				local st = WG.WeatherBrush.getState()
				local step = math.max(1, math.floor(st.cadence * 0.2))
				WG.WeatherBrush.setCadence(st.cadence + step)
			end
			event:StopPropagation()
		end, false)
	end

	local wbCadenceDown = doc:GetElementById("btn-wb-cadence-down")
	if wbCadenceDown then
		wbCadenceDown:AddEventListener("click", function(event)
			if WG.WeatherBrush then
				local st = WG.WeatherBrush.getState()
				local step = math.max(1, math.floor(st.cadence * 0.2))
				WG.WeatherBrush.setCadence(st.cadence - step)
			end
			event:StopPropagation()
		end, false)
	end

	-- Weather frequency slider + buttons
	local wbSliderFrequency = doc:GetElementById("wb-slider-frequency")
	if wbSliderFrequency then
		trackSliderDrag(wbSliderFrequency, "wb-frequency")
		wbSliderFrequency:AddEventListener("change", function(event)
			if not updatingFromCode and WG.WeatherBrush then
				local sliderVal = tonumber(wbSliderFrequency:GetAttribute("value")) or 0
				WG.WeatherBrush.setFrequency(sliderToFrequency(sliderVal))
			end
			event:StopPropagation()
		end, false)
	end

	local wbFrequencyUp = doc:GetElementById("btn-wb-frequency-up")
	if wbFrequencyUp then
		wbFrequencyUp:AddEventListener("click", function(event)
			if WG.WeatherBrush then
				local st = WG.WeatherBrush.getState()
				local step = math.max(0.1, st.frequency * 0.2)
				WG.WeatherBrush.setFrequency(st.frequency + step)
			end
			event:StopPropagation()
		end, false)
	end

	local wbFrequencyDown = doc:GetElementById("btn-wb-frequency-down")
	if wbFrequencyDown then
		wbFrequencyDown:AddEventListener("click", function(event)
			if WG.WeatherBrush then
				local st = WG.WeatherBrush.getState()
				local step = math.max(0.1, st.frequency * 0.2)
				WG.WeatherBrush.setFrequency(st.frequency - step)
			end
			event:StopPropagation()
		end, false)
	end

	-- Weather persistence slider (piecewise log mapping)
	local wbSliderPersist = doc:GetElementById("wb-slider-persist")
	if wbSliderPersist then
		trackSliderDrag(wbSliderPersist, "wb-persist")
		wbSliderPersist:AddEventListener("change", function(event)
			if not updatingFromCode and WG.WeatherBrush then
				local sliderVal = tonumber(wbSliderPersist:GetAttribute("value")) or 0
				local seconds = sliderToPersist(sliderVal)
				WG.WeatherBrush.setPersistenceSeconds(seconds)
			end
			event:StopPropagation()
		end, false)
	end

	-- Weather persistent mode toggle
	local wbPersistToggle = doc:GetElementById("btn-wb-persistent")
	if wbPersistToggle then
		wbPersistToggle:AddEventListener("click", function(event)
			if WG.WeatherBrush then
				local wbs = WG.WeatherBrush.getState()
				local isPerm = wbs and wbs.persistenceSeconds >= PERSIST_PERMANENT_VAL
				if isPerm then
					WG.WeatherBrush.setPersistenceSeconds(0)
				else
					WG.WeatherBrush.setPersistenceSeconds(PERSIST_PERMANENT_VAL)
				end
			end
			event:StopPropagation()
		end, false)
	end

	-- Weather Clear All button
	local wbClearAllBtn = doc:GetElementById("btn-wb-clearall")
	if wbClearAllBtn then
		wbClearAllBtn:AddEventListener("click", function(event)
			playSound("reset")
			if WG.WeatherBrush then WG.WeatherBrush.clearAllPersistent() end
			event:StopPropagation()
		end, false)
	end

	-- ============ Splat Painter controls ============

	widgetState.spControlsEl = doc:GetElementById("tf-splat-controls")

	-- ============ Decal controls ============
	;(function()

	widgetState.dcControlsEl  = doc:GetElementById("tf-decal-controls")
	widgetState.dcSubmodesEl  = doc:GetElementById("tf-dc-submodes")

	-- Decal distribution buttons
	widgetState.dcDistButtons.random    = doc:GetElementById("btn-dc-dist-random")
	widgetState.dcDistButtons.regular   = doc:GetElementById("btn-dc-dist-regular")
	widgetState.dcDistButtons.clustered = doc:GetElementById("btn-dc-dist-clustered")

	for dist, element in pairs(widgetState.dcDistButtons) do
		if element then
			element:AddEventListener("click", function(event)
				playSound("shapeSwitch")
				if WG.DecalPainter then WG.DecalPainter.setDistribution(dist) end
				setActiveClass(widgetState.dcDistButtons, dist)
				event:StopPropagation()
			end, false)
		end
	end

	-- Splat channel buttons
	local spChannelButtons = {
		doc:GetElementById("btn-sp-ch1"),
		doc:GetElementById("btn-sp-ch2"),
		doc:GetElementById("btn-sp-ch3"),
		doc:GetElementById("btn-sp-ch4"),
	}
	for i, btn in ipairs(spChannelButtons) do
		if btn then
			btn:AddEventListener("click", function(event)
				playSound("modeSwitch")
				if WG.SplatPainter then WG.SplatPainter.setChannel(i) end
				for j, b in ipairs(spChannelButtons) do
					if b then b:SetClass("active", j == i) end
				end
				event:StopPropagation()
			end, false)
		end
	end

	-- Splat detail texture previews: discover per-layer texture names
	do
		widgetState.spPreviewEls = {
			doc:GetElementById("sp-ch1-preview"),
			doc:GetElementById("sp-ch2-preview"),
			doc:GetElementById("sp-ch3-preview"),
			doc:GetElementById("sp-ch4-preview"),
		}
		widgetState.spPreviewTextures = {}
		widgetState.spPreviewVerified = false
	end

	-- Splat strength slider + buttons
	local spSliderStrength = doc:GetElementById("sp-slider-strength")
	if spSliderStrength then
		trackSliderDrag(spSliderStrength, "sp-strength")
		spSliderStrength:AddEventListener("change", function(event)
			if not updatingFromCode and WG.SplatPainter then
				local val = tonumber(spSliderStrength:GetAttribute("value")) or 15
				WG.SplatPainter.setStrength(val / 100)
			end
			event:StopPropagation()
		end, false)
	end

	local spStrengthUp = doc:GetElementById("btn-sp-strength-up")
	if spStrengthUp then
		spStrengthUp:AddEventListener("click", function(event)
			if WG.SplatPainter then
				local st = WG.SplatPainter.getState()
				WG.SplatPainter.setStrength(st.strength + 0.05)
			end
			event:StopPropagation()
		end, false)
	end

	local spStrengthDown = doc:GetElementById("btn-sp-strength-down")
	if spStrengthDown then
		spStrengthDown:AddEventListener("click", function(event)
			if WG.SplatPainter then
				local st = WG.SplatPainter.getState()
				WG.SplatPainter.setStrength(st.strength - 0.05)
			end
			event:StopPropagation()
		end, false)
	end

	-- Splat intensity slider + buttons
	local spSliderIntensity = doc:GetElementById("sp-slider-intensity")
	if spSliderIntensity then
		trackSliderDrag(spSliderIntensity, "sp-intensity")
		spSliderIntensity:AddEventListener("change", function(event)
			if not updatingFromCode and WG.SplatPainter then
				local val = tonumber(spSliderIntensity:GetAttribute("value")) or 10
				WG.SplatPainter.setIntensity(val / 10)
			end
			event:StopPropagation()
		end, false)
	end

	local spIntensityUp = doc:GetElementById("btn-sp-intensity-up")
	if spIntensityUp then
		spIntensityUp:AddEventListener("click", function(event)
			if WG.SplatPainter then
				local st = WG.SplatPainter.getState()
				WG.SplatPainter.setIntensity(st.intensity + 0.1)
			end
			event:StopPropagation()
		end, false)
	end

	local spIntensityDown = doc:GetElementById("btn-sp-intensity-down")
	if spIntensityDown then
		spIntensityDown:AddEventListener("click", function(event)
			if WG.SplatPainter then
				local st = WG.SplatPainter.getState()
				WG.SplatPainter.setIntensity(st.intensity - 0.1)
			end
			event:StopPropagation()
		end, false)
	end

	-- Splat size slider + buttons
	local spSliderSize = doc:GetElementById("sp-slider-size")
	if spSliderSize then
		trackSliderDrag(spSliderSize, "sp-size")
		spSliderSize:AddEventListener("change", function(event)
			if not updatingFromCode and WG.SplatPainter then
				local val = tonumber(spSliderSize:GetAttribute("value")) or 100
				WG.SplatPainter.setRadius(val)
			end
			event:StopPropagation()
		end, false)
	end

	local spSizeUp = doc:GetElementById("btn-sp-size-up")
	if spSizeUp then
		spSizeUp:AddEventListener("click", function(event)
			if WG.SplatPainter then
				local st = WG.SplatPainter.getState()
				WG.SplatPainter.setRadius(st.radius + RADIUS_STEP)
			end
			event:StopPropagation()
		end, false)
	end

	local spSizeDown = doc:GetElementById("btn-sp-size-down")
	if spSizeDown then
		spSizeDown:AddEventListener("click", function(event)
			if WG.SplatPainter then
				local st = WG.SplatPainter.getState()
				WG.SplatPainter.setRadius(st.radius - RADIUS_STEP)
			end
			event:StopPropagation()
		end, false)
	end

	-- Splat rotation slider + buttons
	local spSliderRotation = doc:GetElementById("sp-slider-rotation")
	if spSliderRotation then
		trackSliderDrag(spSliderRotation, "sp-rotation")
		spSliderRotation:AddEventListener("change", function(event)
			if not updatingFromCode and WG.SplatPainter then
				local val = tonumber(spSliderRotation:GetAttribute("value")) or 0
				WG.SplatPainter.setRotation(val)
			end
			event:StopPropagation()
		end, false)
	end

	local spRotCW = doc:GetElementById("btn-sp-rot-cw")
	if spRotCW then
		spRotCW:AddEventListener("click", function(event)
			if WG.SplatPainter then WG.SplatPainter.rotate(ROTATION_STEP) end
			event:StopPropagation()
		end, false)
	end

	local spRotCCW = doc:GetElementById("btn-sp-rot-ccw")
	if spRotCCW then
		spRotCCW:AddEventListener("click", function(event)
			if WG.SplatPainter then WG.SplatPainter.rotate(-ROTATION_STEP) end
			event:StopPropagation()
		end, false)
	end

	-- Splat curve slider + buttons
	local spSliderCurve = doc:GetElementById("sp-slider-curve")
	if spSliderCurve then
		trackSliderDrag(spSliderCurve, "sp-curve")
		spSliderCurve:AddEventListener("change", function(event)
			if not updatingFromCode and WG.SplatPainter then
				local val = tonumber(spSliderCurve:GetAttribute("value")) or 10
				WG.SplatPainter.setCurve(val / 10)
			end
			event:StopPropagation()
		end, false)
	end

	local spCurveUp = doc:GetElementById("btn-sp-curve-up")
	if spCurveUp then
		spCurveUp:AddEventListener("click", function(event)
			if WG.SplatPainter then
				local st = WG.SplatPainter.getState()
				WG.SplatPainter.setCurve(st.curve + CURVE_STEP)
			end
			event:StopPropagation()
		end, false)
	end

	local spCurveDown = doc:GetElementById("btn-sp-curve-down")
	if spCurveDown then
		spCurveDown:AddEventListener("click", function(event)
			if WG.SplatPainter then
				local st = WG.SplatPainter.getState()
				WG.SplatPainter.setCurve(st.curve - CURVE_STEP)
			end
			event:StopPropagation()
		end, false)
	end

	-- Splat smart filter controls
	local function wireSpSmartToggle(btnId, filterKey)
		local btn = doc:GetElementById(btnId)
		if btn then
			btn:AddEventListener("click", function(event)
				if WG.SplatPainter then
					local sf = WG.SplatPainter.getState().smartFilters
					WG.SplatPainter.setSmartFilter(filterKey, not sf[filterKey])
				end
				event:StopPropagation()
			end, false)
		end
	end
	wireSpSmartToggle("btn-sp-avoid-water",    "avoidWater")
	wireSpSmartToggle("btn-sp-avoid-cliffs",   "avoidCliffs")
	wireSpSmartToggle("btn-sp-prefer-slopes",  "preferSlopes")
	wireSpSmartToggle("btn-sp-alt-min-enable", "altMinEnable")
	wireSpSmartToggle("btn-sp-alt-max-enable", "altMaxEnable")

	local btnSpSmartToggle = doc:GetElementById("btn-sp-smart-toggle")
	if btnSpSmartToggle then
		btnSpSmartToggle:AddEventListener("click", function(event)
			if WG.SplatPainter then
				local st = WG.SplatPainter.getState()
				WG.SplatPainter.setSmartEnabled(not st.smartEnabled)
			end
			event:StopPropagation()
		end, false)
	end

	local spSliderSlopeMax = doc:GetElementById("sp-slider-slope-max")
	if spSliderSlopeMax then
		trackSliderDrag(spSliderSlopeMax, "sp-slope-max")
		spSliderSlopeMax:AddEventListener("change", function(event)
			if not updatingFromCode and WG.SplatPainter then
				local val = tonumber(spSliderSlopeMax:GetAttribute("value")) or 45
				WG.SplatPainter.setSmartFilter("slopeMax", val)
			end
			event:StopPropagation()
		end, false)
	end

	local spSliderSlopeMin = doc:GetElementById("sp-slider-slope-min")
	if spSliderSlopeMin then
		trackSliderDrag(spSliderSlopeMin, "sp-slope-min")
		spSliderSlopeMin:AddEventListener("change", function(event)
			if not updatingFromCode and WG.SplatPainter then
				local val = tonumber(spSliderSlopeMin:GetAttribute("value")) or 10
				WG.SplatPainter.setSmartFilter("slopeMin", val)
			end
			event:StopPropagation()
		end, false)
	end

	local spSliderAltMin = doc:GetElementById("sp-slider-alt-min")
	if spSliderAltMin then
		trackSliderDrag(spSliderAltMin, "sp-alt-min")
		spSliderAltMin:AddEventListener("change", function(event)
			if not updatingFromCode and WG.SplatPainter then
				local val = tonumber(spSliderAltMin:GetAttribute("value")) or 0
				local sf = WG.SplatPainter.getState().smartFilters
				if sf.altMaxEnable and val > sf.altMax then
					WG.SplatPainter.setSmartFilter("altMax", val)
				end
				WG.SplatPainter.setSmartFilter("altMin", val)
			end
			event:StopPropagation()
		end, false)
	end

	local spSliderAltMax = doc:GetElementById("sp-slider-alt-max")
	if spSliderAltMax then
		trackSliderDrag(spSliderAltMax, "sp-alt-max")
		spSliderAltMax:AddEventListener("change", function(event)
			if not updatingFromCode and WG.SplatPainter then
				local val = tonumber(spSliderAltMax:GetAttribute("value")) or 200
				local sf = WG.SplatPainter.getState().smartFilters
				if sf.altMinEnable and val < sf.altMin then
					WG.SplatPainter.setSmartFilter("altMin", val)
				end
				WG.SplatPainter.setSmartFilter("altMax", val)
			end
			event:StopPropagation()
		end, false)
	end

	-- Splat painter smart filter +/- buttons
	do
		local function wireSpSmartBtn(btnId, filterKey, step)
			local btn = doc:GetElementById(btnId)
			if btn then
				btn:AddEventListener("click", function(event)
					if WG.SplatPainter then
						local sf = WG.SplatPainter.getState().smartFilters
						WG.SplatPainter.setSmartFilter(filterKey, (sf[filterKey] or 0) + step)
					end
					event:StopPropagation()
				end, false)
			end
		end
		wireSpSmartBtn("btn-sp-slope-max-up",   "slopeMax",  5)
		wireSpSmartBtn("btn-sp-slope-max-down", "slopeMax", -5)
		wireSpSmartBtn("btn-sp-slope-min-up",   "slopeMin",  5)
		wireSpSmartBtn("btn-sp-slope-min-down", "slopeMin", -5)
		wireSpSmartBtn("btn-sp-alt-min-up",     "altMin",   10)
		wireSpSmartBtn("btn-sp-alt-min-down",   "altMin",  -10)
		wireSpSmartBtn("btn-sp-alt-max-up",     "altMax",   10)
		wireSpSmartBtn("btn-sp-alt-max-down",   "altMax",  -10)
	end

	-- Splat export format toggle
	local spExportFmtBtn = doc:GetElementById("btn-sp-export-format")
	if spExportFmtBtn then
		spExportFmtBtn:AddEventListener("click", function(event)
			playSound("click")
			if WG.SplatPainter then WG.SplatPainter.cycleExportFormat() end
			event:StopPropagation()
		end, false)
	end

	-- Splat save button
	local spSaveBtn = doc:GetElementById("btn-sp-save")
	if spSaveBtn then
		spSaveBtn:AddEventListener("click", function(event)
			playSound("save")
			if WG.SplatPainter then WG.SplatPainter.saveSplats() end
			event:StopPropagation()
		end, false)
	end

	-- Splat undo/redo buttons and history slider
	do
		local spUndoBtn = doc:GetElementById("btn-sp-undo")
		if spUndoBtn then
			spUndoBtn:AddEventListener("click", function(event)
				playSound("click")
				if WG.SplatPainter then WG.SplatPainter.undo() end
				event:StopPropagation()
			end, false)
		end

		local spRedoBtn = doc:GetElementById("btn-sp-redo")
		if spRedoBtn then
			spRedoBtn:AddEventListener("click", function(event)
				playSound("click")
				if WG.SplatPainter then WG.SplatPainter.redo() end
				event:StopPropagation()
			end, false)
		end

		local spHistSlider = doc:GetElementById("slider-sp-history")
		if spHistSlider then
			spHistSlider:AddEventListener("change", function(event)
				if updatingFromCode then return end
				local spSt = WG.SplatPainter and WG.SplatPainter.getState()
				if not spSt then return end
				local newVal = tonumber(event.target:GetAttribute("value")) or 0
				local curPos = spSt.undoCount or 0
				local diff = newVal - curPos
				if diff < 0 then
					for _ = 1, -diff do
						WG.SplatPainter.undo()
					end
				elseif diff > 0 then
					for _ = 1, diff do
						WG.SplatPainter.redo()
					end
				end
				event:StopPropagation()
			end, false)
		end
	end

	end)() -- end Decal controls IIFE

	-- ============ Decal Export & Analytics buttons ============
	do
		local function dcExportClick(btnId, actionFn)
			local btn = doc:GetElementById(btnId)
			if btn then
				btn:AddEventListener("click", function(event)
					playSound("tick")
					actionFn()
					event:StopPropagation()
				end, false)
			end
		end

		dcExportClick("btn-dc-export-all", function()
			if WG.DecalExporter then
				local gl4 = WG.DecalExporter.snapshotGL4() or {}
				local eng = WG.DecalExporter.snapshotEngine() or {}
				local combined = {}
				for _, d in ipairs(gl4) do combined[#combined + 1] = d end
				for _, d in ipairs(eng) do combined[#combined + 1] = d end
				if #combined > 0 then
					WG.DecalExporter.exportLua(combined)
					WG.DecalExporter.exportCSV(combined)
					WG.DecalExporter.exportStamp(combined)
					WG.DecalExporter.exportFeatures(combined)
				else
					Spring.Echo("[Decal Export] No decals to export")
				end
			else
				Spring.Echo("[Decal Export] Enable the 'Decal Exporter & Analytics' widget first")
			end
		end)

		dcExportClick("btn-dc-export-stamp", function()
			if WG.DecalExporter then
				local snap = WG.DecalExporter.snapshotEngine()
				if snap then WG.DecalExporter.exportStamp(snap) end
			else
				Spring.Echo("[Decal Export] Enable the 'Decal Exporter & Analytics' widget first")
			end
		end)

		dcExportClick("btn-dc-export-features", function()
			if WG.DecalExporter then
				local gl4 = WG.DecalExporter.snapshotGL4() or {}
				local eng = WG.DecalExporter.snapshotEngine() or {}
				local combined = {}
				for _, d in ipairs(gl4) do combined[#combined + 1] = d end
				for _, d in ipairs(eng) do combined[#combined + 1] = d end
				if #combined > 0 then
					WG.DecalExporter.exportFeatures(combined)
				end
			else
				Spring.Echo("[Decal Export] Enable the 'Decal Exporter & Analytics' widget first")
			end
		end)

		dcExportClick("btn-dc-export-csv", function()
			if WG.DecalExporter then
				local gl4 = WG.DecalExporter.snapshotGL4() or {}
				local eng = WG.DecalExporter.snapshotEngine() or {}
				local combined = {}
				for _, d in ipairs(gl4) do combined[#combined + 1] = d end
				for _, d in ipairs(eng) do combined[#combined + 1] = d end
				if #combined > 0 then
					WG.DecalExporter.exportCSV(combined)
				end
			else
				Spring.Echo("[Decal Export] Enable the 'Decal Exporter & Analytics' widget first")
			end
		end)

		dcExportClick("btn-dc-heatmap-export", function()
			if WG.DecalExporter then
				WG.DecalExporter.exportHeatmapCSV()
				WG.DecalExporter.exportHeatmapPGM()
			else
				Spring.Echo("[Decal Export] Enable the 'Decal Exporter & Analytics' widget first")
			end
		end)

		dcExportClick("btn-dc-heatmap-reset", function()
			if WG.DecalExporter then
				WG.DecalExporter.resetHeatmap()
				Spring.Echo("[Decal Export] Heatmap reset")
			end
		end)
	end

	-- ============ Decal Library buttons ============
	do
		local function dcLibClick(btnId, fn)
			local btn = doc:GetElementById(btnId)
			if btn then
				btn:AddEventListener("click", function(event)
					playSound("tick")
					fn()
					event:StopPropagation()
				end, false)
			end
		end
		local function ensureDecalPlacer()
			if not WG.DecalPlacer then
				Spring.Echo("[Decal Library] Enable the 'Decal Placer' widget first")
				return false
			end
			return true
		end
		dcLibClick("btn-dc-library-scatter", function()
			if ensureDecalPlacer() then WG.DecalPlacer.setMode("scatter") end
		end)
		dcLibClick("btn-dc-library-point", function()
			if ensureDecalPlacer() then WG.DecalPlacer.setMode("point") end
		end)
		dcLibClick("btn-dc-library-remove", function()
			if ensureDecalPlacer() then WG.DecalPlacer.setMode("remove") end
		end)
		dcLibClick("btn-dc-library-stop", function()
			if WG.DecalPlacer then WG.DecalPlacer.deactivate() end
		end)
		dcLibClick("btn-dc-library-open", function()
			if ensureDecalPlacer() then
				local s = WG.DecalPlacer.getState()
				if not s or not s.active then
					WG.DecalPlacer.setMode("scatter")
				end
			end
		end)

		-- Brush / decal option sliders + action buttons (dc-*)
		local function bindDCSlider(sliderId, numboxId, setter, transform)
			local slider = doc:GetElementById(sliderId)
			local numbox = doc:GetElementById(numboxId)
			if not slider then return end
			local function applyFromValue(s)
				local v = tonumber(s); if not v then return end
				if transform then v = transform(v) end
				setter(v)
			end
			slider:AddEventListener("change", function()
				applyFromValue(slider:GetAttribute("value"))
			end, false)
			if numbox then
				numbox:AddEventListener("focus", function() Spring.SDLStartTextInput(); widgetState.focusedRmlInput = numbox end, false)
				numbox:AddEventListener("blur",  function() Spring.SDLStopTextInput(); widgetState.focusedRmlInput = nil end, false)
				numbox:AddEventListener("change", function()
					applyFromValue(numbox:GetAttribute("value"))
				end, false)
			end
		end
		local function bindDCStep(btnId, getCur, setter, step)
			local btn = doc:GetElementById(btnId)
			if btn then
				btn:AddEventListener("click", function(event)
					playSound("tick")
					setter(getCur() + step)
					event:StopPropagation()
				end, false)
			end
		end
		local DP = WG.DecalPlacer
		if DP then
			bindDCSlider("dc-slider-radius",   "dc-slider-radius-numbox",   DP.setRadius)
			bindDCSlider("dc-slider-rotation", "dc-slider-rotation-numbox", DP.setRotation)
			bindDCSlider("dc-slider-rotrand",  "dc-slider-rotrand-numbox",  DP.setRotRandom)
			bindDCSlider("dc-slider-count",    "dc-slider-count-numbox",    DP.setDecalCount)
			bindDCSlider("dc-slider-cadence",  "dc-slider-cadence-numbox",  DP.setCadence)
			bindDCSlider("dc-slider-sizemin",  "dc-slider-sizemin-numbox",  DP.setSizeMin)
			bindDCSlider("dc-slider-sizemax",  "dc-slider-sizemax-numbox",  DP.setSizeMax)
			bindDCSlider("dc-slider-alpha",    "dc-slider-alpha-numbox",    DP.setAlpha, function(v) return v/100 end)

			bindDCStep("btn-dc-radius-down",  function() return DP.getState().radius end,     DP.setRadius,    -8)
			bindDCStep("btn-dc-radius-up",    function() return DP.getState().radius end,     DP.setRadius,     8)
			bindDCStep("btn-dc-rot-ccw",      function() return DP.getState().rotation end,   DP.setRotation,  -5)
			bindDCStep("btn-dc-rot-cw",       function() return DP.getState().rotation end,   DP.setRotation,   5)
			bindDCStep("btn-dc-count-down",   function() return DP.getState().decalCount end, DP.setDecalCount,-1)
			bindDCStep("btn-dc-count-up",     function() return DP.getState().decalCount end, DP.setDecalCount, 1)
			bindDCStep("btn-dc-cadence-down",  function() return DP.getState().cadence end,    DP.setCadence,    -5)
			bindDCStep("btn-dc-cadence-up",    function() return DP.getState().cadence end,    DP.setCadence,     5)
			bindDCStep("btn-dc-rotrand-down",  function() return DP.getState().rotRandom end,  DP.setRotRandom,  -1)
			bindDCStep("btn-dc-rotrand-up",    function() return DP.getState().rotRandom end,  DP.setRotRandom,   1)
			bindDCStep("btn-dc-sizemin-down",  function() return DP.getState().sizeMin end,    DP.setSizeMin,    -4)
			bindDCStep("btn-dc-sizemin-up",    function() return DP.getState().sizeMin end,    DP.setSizeMin,     4)
			bindDCStep("btn-dc-sizemax-down",  function() return DP.getState().sizeMax end,    DP.setSizeMax,    -4)
			bindDCStep("btn-dc-sizemax-up",    function() return DP.getState().sizeMax end,    DP.setSizeMax,     4)
			bindDCStep("btn-dc-alpha-down",    function() return DP.getState().alpha*100 end,  function(v) DP.setAlpha(v/100) end, -1)
			bindDCStep("btn-dc-alpha-up",      function() return DP.getState().alpha*100 end,  function(v) DP.setAlpha(v/100) end,  1)
		end
		dcLibClick("btn-dc-align-toggle", function()
			if DP then
				local s = DP.getState()
				if s then DP.setAlignToNormal(not s.alignToNormal) end
			end
		end)
		-- Decal undo/redo section (undo only — DC has no redo backend)
		local dcUndoBtn = doc:GetElementById("btn-dc-undo")
		if dcUndoBtn then
			dcUndoBtn:AddEventListener("click", function(event)
				if DP then playSound("undo"); DP.undo() end
				event:StopPropagation()
			end, false)
		end
		-- Redo button: no-op (DC redo not implemented)
		local dcRedoBtn = doc:GetElementById("btn-dc-redo")
		if dcRedoBtn then
			dcRedoBtn:AddEventListener("click", function(event)
				event:StopPropagation()
			end, false)
		end
		local sliderDcHistory = doc:GetElementById("slider-dc-history")
		if sliderDcHistory then
			trackSliderDrag(sliderDcHistory, "dc-history")
			sliderDcHistory:AddEventListener("change", function(event)
				if updatingFromCode then event:StopPropagation(); return end
				if not DP then event:StopPropagation(); return end
				local val = tonumber(sliderDcHistory:GetAttribute("value")) or 0
				local dcSt = DP.getState()
				if not dcSt then event:StopPropagation(); return end
				local cur = dcSt.undoCount or 0
				local diff = val - cur
				if diff < 0 then
					for i = 1, -diff do DP.undo() end
				end
				event:StopPropagation()
			end, false)
		end
		dcLibClick("btn-dc-clearall", function() if DP then DP.clearAll() end end)
		dcLibClick("btn-dc-save",     function() if DP then DP.save()     end end)
		dcLibClick("btn-dc-load",     function()
			if not DP then return end
			local saves = DP.listSaves()
			if not saves or #saves == 0 then Spring.Echo("[Decal Placer] No saved files"); return end
			DP.load(saves[#saves])
			Spring.Echo("[Decal Placer] Loaded " .. saves[#saves])
		end)
	end

	-- ============ Environment controls ============
	;(function()

	widgetState.envControlsEl = doc:GetElementById("tf-environment-controls")

	-- Scan for skybox textures and build the thumbnail grid
	local SKYBOX_DIR = "luaui/RmlWidgets/gui_terraform_brush/skyboxes/"
	local skyboxFiles = VFS.DirList(SKYBOX_DIR, "*", VFS.RAW_FIRST) or {}

	-- Separate DDS skybox textures from preview images (jpg/png)
	local ddsFiles = {}      -- { {path, baseLower}, ... }
	local previewFiles = {}  -- baseLower -> path  (jpg/png only)
	for _, fp in ipairs(skyboxFiles) do
		local ext = (fp:match("%.([^%.]+)$") or ""):lower()
		local basename = fp:match("([^/\\]+)%.[^%.]+$") or ""
		local baseLower = basename:lower()
		if ext == "dds" then
			ddsFiles[#ddsFiles + 1] = { path = fp, baseLower = baseLower }
		elseif ext == "jpg" or ext == "jpeg" or ext == "png" then
			previewFiles[baseLower] = fp
		end
	end

	-- Match each DDS to its preview image using fuzzy name matching
	local function findPreview(ddsBase)
		-- Try direct match first (unlikely but cheap)
		if previewFiles[ddsBase] then return previewFiles[ddsBase] end
		-- Try common naming: "Name - Preview", "Name Reflections"
		for key, path in pairs(previewFiles) do
			local stripped = key:gsub("%s*%-%s*preview$", ""):gsub("%s*reflections$", "")
			local ddsStripped = ddsBase:gsub("_skybox", ""):gsub("skybox", "")
			-- Check if either name starts with the other's prefix (at least 6 chars)
			if #stripped >= 6 and (ddsBase:find(stripped:sub(1, math.min(#stripped, 12)), 1, true)
				or stripped:find(ddsBase:sub(1, math.min(#ddsBase, 12)), 1, true)) then
				return path
			end
			if #ddsStripped >= 4 and (key:find(ddsStripped:sub(1, math.min(#ddsStripped, 10)), 1, true)
				or ddsStripped:find(stripped:sub(1, math.min(#stripped, 10)), 1, true)) then
				return path
			end
		end
		return nil
	end

	local gridEl = doc:GetElementById("env-skybox-grid")
	if gridEl then
		-- Store DDS paths for deferred pre-loading in DrawScreen
		-- (gl.Texture cannot be called in Initialize, only in Draw call-ins)
		for _, dds in ipairs(ddsFiles) do
			widgetState.envLoadedTextures[#widgetState.envLoadedTextures + 1] = dds.path
		end
		widgetState.envTexturesPreloaded = false

		for _, dds in ipairs(ddsFiles) do
			local previewPath = findPreview(dds.baseLower)
			local ddsPath = dds.path
			local displayName = dds.path:match("([^/\\]+)%.%w+$") or dds.path

			local thumbDiv = doc:CreateElement("div")
			thumbDiv:SetClass("env-skybox-thumb", true)
			thumbDiv:SetAttribute("title", displayName)

			if previewPath then
				local img = doc:CreateElement("img")
				img:SetAttribute("src", "/" .. previewPath)
				thumbDiv:AppendChild(img)
			end

			local label = doc:CreateElement("div")
			label:SetClass("env-skybox-name", true)
			label.inner_rml = displayName
			thumbDiv:AppendChild(label)

			thumbDiv:AddEventListener("click", function(event)
				local normalized = ddsPath:gsub("\\", "/")
				widgetState.applySkybox(normalized)
				widgetState.envCurrentSkybox = normalized
				for _, t in ipairs(widgetState.envSkyboxThumbs) do
					t.element:SetClass("active", t.path == ddsPath)
				end
				event:StopPropagation()
			end, false)

			gridEl:AppendChild(thumbDiv)
			widgetState.envSkyboxThumbs[#widgetState.envSkyboxThumbs + 1] = { element = thumbDiv, path = ddsPath }
		end

		if #ddsFiles == 0 then
			gridEl.inner_rml = '<div class="text-xs text-keybind" style="padding: 8dp; text-align: center;">'
				.. 'No skybox textures found.<br/>'
				.. 'Get skyboxes from the Discord <span style="color: #fbbf24;">#mapping</span> channel pins and place them in:<br/>'
				.. '<span style="color: #9ca3af;">luaui/RmlWidgets/gui_terraform_brush/skyboxes/</span>'
				.. '</div>'
		end
	end

	-- Reset skybox button
	local resetSkyboxBtn = doc:GetElementById("btn-env-reset-skybox")
	if resetSkyboxBtn then
		resetSkyboxBtn:AddEventListener("click", function(event)
			local resetPath = widgetState.envDefaultSkybox or ""
			widgetState.applySkybox(resetPath)
			widgetState.envCurrentSkybox = nil
			for _, t in ipairs(widgetState.envSkyboxThumbs) do
				t.element:SetClass("active", false)
			end
			event:StopPropagation()
		end, false)
	end

	-- Fade transition toggle
	local fadeToggleBtn = doc:GetElementById("btn-env-fade-toggle")
	if fadeToggleBtn then
		fadeToggleBtn:AddEventListener("click", function(event)
			widgetState.envFadeEnabled = not widgetState.envFadeEnabled
			playSound(widgetState.envFadeEnabled and "toggleOn" or "toggleOff")
			fadeToggleBtn:SetAttribute("src",
				widgetState.envFadeEnabled
				and "/luaui/images/terraform_brush/check_on.png"
				or  "/luaui/images/terraform_brush/check_off.png")
			event:StopPropagation()
		end, false)
	end

	-- ============ Environment sub-windows setup ============
	attachEnvironmentListeners(doc)

	-- ============ Light Placer controls ============

	widgetState.lightControlsEl = doc:GetElementById("tf-light-controls")

	-- Light type buttons
	local ltTypes = { "point", "cone", "beam" }
	for _, lt in ipairs(ltTypes) do
		local btn = doc:GetElementById("btn-lt-" .. lt)
		if btn then
			widgetState.lightTypeButtons[lt] = btn
			btn:AddEventListener("click", function(event)
				playSound("modeSwitch")
				if WG.LightPlacer then WG.LightPlacer.setLightType(lt) end
				event:StopPropagation()
			end, false)
		end
	end

	-- Placement mode buttons
	local lpModes = { "point", "scatter", "remove" }
	for _, mode in ipairs(lpModes) do
		local btn = doc:GetElementById("btn-lp-" .. mode)
		if btn then
			widgetState.lightModeButtons[mode] = btn
			btn:AddEventListener("click", function(event)
				playSound("modeSwitch")
				if WG.LightPlacer then WG.LightPlacer.setMode(mode) end
				event:StopPropagation()
			end, false)
		end
	end

	-- Distribution buttons
	local lpDists = { "random", "regular", "clustered" }
	for _, dist in ipairs(lpDists) do
		local btn = doc:GetElementById("btn-lp-dist-" .. dist)
		if btn then
			widgetState.lightDistButtons[dist] = btn
			btn:AddEventListener("click", function(event)
				playSound("shapeSwitch")
				if WG.LightPlacer then WG.LightPlacer.setDistribution(dist) end
				event:StopPropagation()
			end, false)
		end
	end

	-- Color sliders
	local function setupColorSlider(channel, idx)
		local slider = doc:GetElementById("slider-lp-color-" .. channel)
		if slider then
			trackSliderDrag(slider, "lp-color-" .. channel)
			slider:AddEventListener("change", function(event)
				if updatingFromCode then return end
				local val = tonumber(slider:GetAttribute("value")) or 0
				if WG.LightPlacer then
					local state = WG.LightPlacer.getState()
					local r, g, b = state.color[1], state.color[2], state.color[3]
					if idx == 1 then r = val / 1000
					elseif idx == 2 then g = val / 1000
					else b = val / 1000 end
					WG.LightPlacer.setColor(r, g, b)
				end
				event:StopPropagation()
			end, false)
		end
	end
	setupColorSlider("r", 1)
	setupColorSlider("g", 2)
	setupColorSlider("b", 3)

	-- Color palette swatch clicks
	do
	local PALETTE = {
		-- Row 1: neutrals + warm-to-cool spectrum (18)
		{1.0, 1.0, 1.0, "#FFFFFF", "White"},
		{0.88, 0.88, 0.88, "#E0E0E0", "Light Gray"},
		{0.53, 0.53, 0.53, "#888888", "Gray"},
		{0.33, 0.33, 0.33, "#555555", "Dark Gray"},
		{0.2, 0.2, 0.2, "#333333", "Charcoal"},
		{0.11, 0.11, 0.11, "#1D1D1D", "Near Black"},
		{0.03, 0.02, 0.02, "#080606", "Black"},
		{1.0, 0.0, 0.0, "#FF0000", "Red"},
		{1.0, 0.27, 0.0, "#FF4400", "Red-Orange"},
		{1.0, 0.53, 0.0, "#FF8800", "Orange"},
		{1.0, 0.8, 0.0, "#FFCC00", "Gold"},
		{1.0, 0.93, 0.33, "#FFEE54", "Yellow"},
		{0.53, 1.0, 0.0, "#88FF00", "Lime"},
		{0.0, 1.0, 0.0, "#00FF00", "Green"},
		{0.0, 1.0, 0.8, "#00FFCC", "Aquamarine"},
		{0.0, 0.8, 1.0, "#00CCFF", "Sky Blue"},
		{0.0, 0.53, 1.0, "#0088FF", "Dodger Blue"},
		{0.0, 0.0, 1.0, "#0000FF", "Blue"},
		-- Row 2: warm tones, pinks/purples, pastels (18)
		{1.0, 1.0, 0.8, "#FFFFCC", "Cream"},
		{1.0, 0.88, 0.69, "#FFE0B0", "Peach"},
		{1.0, 0.78, 0.49, "#FFC87C", "Light Apricot"},
		{1.0, 0.67, 0.27, "#FFAA44", "Sandy Orange"},
		{0.8, 0.4, 0.0, "#CC6600", "Brown Orange"},
		{0.53, 0.27, 0.0, "#884400", "Saddle Brown"},
		{0.27, 0.13, 0.0, "#442200", "Dark Brown"},
		{1.0, 0.0, 0.53, "#FF0088", "Hot Pink"},
		{1.0, 0.0, 1.0, "#FF00FF", "Magenta"},
		{0.53, 0.0, 1.0, "#8800FF", "Purple"},
		{0.64, 0.11, 0.89, "#A41DE2", "Violet"},
		{0.4, 0.27, 0.8, "#6644CC", "Indigo"},
		{0.0, 1.0, 1.0, "#00FFFF", "Cyan"},
		{0.67, 1.0, 0.8, "#AAFFCC", "Mint"},
		{0.8, 0.87, 1.0, "#CCDDFF", "Lavender"},
		{1.0, 0.8, 0.87, "#FFCCDD", "Pink"},
		{0.87, 0.8, 1.0, "#DDCCFF", "Lilac"},
		{0.8, 1.0, 0.87, "#CCFFDD", "Honeydew"},
		-- Row 3: BAR theme + warm/cool light presets (18)
		{0.17, 0.65, 0.92, "#2BA5EA", "Armada Blue"},
		{0.99, 0.75, 0.30, "#FDC04C", "BAR Yellow"},
		{0.27, 0.92, 0.17, "#46EA2B", "BAR HP Green"},
		{0.42, 0.35, 0.0, "#6B5A00", "Buildtime Dark"},
		{0.16, 0.16, 0.16, "#282828", "BAR Border"},
		{1.0, 0.93, 0.87, "#FFEEDD", "Warm White"},
		{1.0, 0.83, 0.63, "#FFD4A0", "Candle"},
		{1.0, 0.73, 0.47, "#FFBB77", "Tungsten"},
		{1.0, 0.6, 0.27, "#FF9944", "Sunset"},
		{1.0, 0.47, 0.13, "#FF7722", "Amber"},
		{0.87, 0.33, 0.0, "#DD5500", "Deep Orange"},
		{0.93, 0.93, 1.0, "#EEEEFF", "Cool White"},
		{0.8, 0.8, 1.0, "#CCCCFF", "Pale Blue"},
		{0.67, 0.73, 1.0, "#AABBFF", "Soft Blue"},
		{0.53, 0.6, 0.87, "#8899DD", "Steel Blue"},
		{0.4, 0.47, 0.73, "#6677BB", "Slate"},
		{0.27, 0.33, 0.6, "#445599", "Night Blue"},
		{0.13, 0.2, 0.47, "#223377", "Midnight"},
	}
	for idx, c in ipairs(PALETTE) do
		local swatch = doc:GetElementById("lp-swatch-" .. idx)
		if swatch then
			swatch:AddEventListener("click", function(event)
				if WG.LightPlacer then
					WG.LightPlacer.setColor(c[1], c[2], c[3])
				end
				event:StopPropagation()
			end, false)
			guideHints["lp-swatch-" .. idx] = c[5] .. " " .. c[4]
		end
	end
	end

	-- Material section collapse toggle
	do local matToggleBtn = doc:GetElementById("btn-lp-material-toggle")
	local matSection   = doc:GetElementById("lp-material-section")
	widgetState.lightMaterialVisible = true
	if matToggleBtn and matSection then
		matToggleBtn:AddEventListener("click", function(event)
			widgetState.lightMaterialVisible = not widgetState.lightMaterialVisible
			matSection:SetClass("hidden", not widgetState.lightMaterialVisible)
			matToggleBtn:SetAttribute("src",
				widgetState.lightMaterialVisible
				and "/luaui/images/terraform_brush/check_on.png"
				or  "/luaui/images/terraform_brush/check_off.png")
			event:StopPropagation()
		end, false)
	end end

	-- Brightness slider
	local brightnessSlider = doc:GetElementById("slider-lp-brightness")
	if brightnessSlider then
		trackSliderDrag(brightnessSlider, "lp-brightness")
		brightnessSlider:AddEventListener("change", function(event)
			if updatingFromCode then return end
			local val = tonumber(brightnessSlider:GetAttribute("value")) or 200
			if WG.LightPlacer then WG.LightPlacer.setBrightness(val / 100) end
			event:StopPropagation()
		end, false)
	end
	local brightDownBtn = doc:GetElementById("btn-lp-brightness-down")
	if brightDownBtn then
		brightDownBtn:AddEventListener("click", function(event)
			if WG.LightPlacer then
				local s = WG.LightPlacer.getState()
				WG.LightPlacer.setBrightness(s.brightness - 0.1)
			end
			event:StopPropagation()
		end, false)
	end
	local brightUpBtn = doc:GetElementById("btn-lp-brightness-up")
	if brightUpBtn then
		brightUpBtn:AddEventListener("click", function(event)
			if WG.LightPlacer then
				local s = WG.LightPlacer.getState()
				WG.LightPlacer.setBrightness(s.brightness + 0.1)
			end
			event:StopPropagation()
		end, false)
	end

	-- Light radius slider
	local lightRadSlider = doc:GetElementById("slider-lp-light-radius")
	if lightRadSlider then
		trackSliderDrag(lightRadSlider, "lp-light-radius")
		lightRadSlider:AddEventListener("change", function(event)
			if updatingFromCode then return end
			local val = tonumber(lightRadSlider:GetAttribute("value")) or 300
			if WG.LightPlacer then WG.LightPlacer.setLightRadius(val) end
			event:StopPropagation()
		end, false)
	end
	local lightRadDown = doc:GetElementById("btn-lp-light-radius-down")
	if lightRadDown then
		lightRadDown:AddEventListener("click", function(event)
			if WG.LightPlacer then
				local s = WG.LightPlacer.getState()
				WG.LightPlacer.setLightRadius(s.lightRadius - 50)
			end
			event:StopPropagation()
		end, false)
	end
	local lightRadUp = doc:GetElementById("btn-lp-light-radius-up")
	if lightRadUp then
		lightRadUp:AddEventListener("click", function(event)
			if WG.LightPlacer then
				local s = WG.LightPlacer.getState()
				WG.LightPlacer.setLightRadius(s.lightRadius + 50)
			end
			event:StopPropagation()
		end, false)
	end

	-- Elevation slider
	local elevSlider = doc:GetElementById("slider-lp-elevation")
	if elevSlider then
		trackSliderDrag(elevSlider, "lp-elevation")
		elevSlider:AddEventListener("change", function(event)
			if updatingFromCode then return end
			local val = tonumber(elevSlider:GetAttribute("value")) or 20
			if WG.LightPlacer then WG.LightPlacer.setElevation(val) end
			event:StopPropagation()
		end, false)
	end
	local elevDown = doc:GetElementById("btn-lp-elevation-down")
	if elevDown then
		elevDown:AddEventListener("click", function(event)
			if WG.LightPlacer then
				local s = WG.LightPlacer.getState()
				WG.LightPlacer.setElevation(s.elevation - 5)
			end
			event:StopPropagation()
		end, false)
	end
	local elevUp = doc:GetElementById("btn-lp-elevation-up")
	if elevUp then
		elevUp:AddEventListener("click", function(event)
			if WG.LightPlacer then
				local s = WG.LightPlacer.getState()
				WG.LightPlacer.setElevation(s.elevation + 5)
			end
			event:StopPropagation()
		end, false)
	end

	-- Material sliders
	local materials = {
		{ id = "modelfactor", setter = "setModelfactor", scale = 100 },
		{ id = "specular",    setter = "setSpecular",    scale = 100 },
		{ id = "scattering",  setter = "setScattering",  scale = 100 },
		{ id = "lensflare",   setter = "setLensflare",   scale = 100 },
	}
	for _, mat in ipairs(materials) do
		local slider = doc:GetElementById("slider-lp-" .. mat.id)
		if slider then
			trackSliderDrag(slider, "lp-" .. mat.id)
			slider:AddEventListener("change", function(event)
				if updatingFromCode then return end
				local val = tonumber(slider:GetAttribute("value")) or 100
				if WG.LightPlacer then WG.LightPlacer[mat.setter](val / mat.scale) end
				event:StopPropagation()
			end, false)
		end
	end

	-- Direction sliders (pitch, yaw, roll)
	local dirSliders = {
		{ id = "pitch", setter = "setPitch", scale = 10 },
		{ id = "yaw",   setter = "setYaw",   scale = 10 },
		{ id = "roll",  setter = "setRoll",  scale = 10 },
	}
	for _, ds in ipairs(dirSliders) do
		local slider = doc:GetElementById("slider-lp-" .. ds.id)
		if slider then
			trackSliderDrag(slider, "lp-" .. ds.id)
			slider:AddEventListener("change", function(event)
				if updatingFromCode then return end
				local val = tonumber(slider:GetAttribute("value")) or 0
				if WG.LightPlacer then WG.LightPlacer[ds.setter](val / ds.scale) end
				event:StopPropagation()
			end, false)
		end
	end

	-- Theta slider (cone spread)
	local thetaSlider = doc:GetElementById("slider-lp-theta")
	if thetaSlider then
		trackSliderDrag(thetaSlider, "lp-theta")
		thetaSlider:AddEventListener("change", function(event)
			if updatingFromCode then return end
			local val = tonumber(thetaSlider:GetAttribute("value")) or 500
			if WG.LightPlacer then WG.LightPlacer.setTheta(val / 1000) end
			event:StopPropagation()
		end, false)
	end

	-- Beam length slider
	local beamLenSlider = doc:GetElementById("slider-lp-beam-length")
	if beamLenSlider then
		trackSliderDrag(beamLenSlider, "lp-beam-length")
		beamLenSlider:AddEventListener("change", function(event)
			if updatingFromCode then return end
			local val = tonumber(beamLenSlider:GetAttribute("value")) or 300
			if WG.LightPlacer then WG.LightPlacer.setBeamLength(val) end
			event:StopPropagation()
		end, false)
	end

	-- Scatter count slider
	local countSlider = doc:GetElementById("slider-lp-count")
	if countSlider then
		trackSliderDrag(countSlider, "lp-count")
		countSlider:AddEventListener("change", function(event)
			if updatingFromCode then return end
			local val = tonumber(countSlider:GetAttribute("value")) or 5
			if WG.LightPlacer then WG.LightPlacer.setLightCount(val) end
			event:StopPropagation()
		end, false)
	end
	local countDown = doc:GetElementById("btn-lp-count-down")
	if countDown then
		countDown:AddEventListener("click", function(event)
			if WG.LightPlacer then
				local s = WG.LightPlacer.getState()
				WG.LightPlacer.setLightCount(s.lightCount - 1)
			end
			event:StopPropagation()
		end, false)
	end
	local countUp = doc:GetElementById("btn-lp-count-up")
	if countUp then
		countUp:AddEventListener("click", function(event)
			if WG.LightPlacer then
				local s = WG.LightPlacer.getState()
				WG.LightPlacer.setLightCount(s.lightCount + 1)
			end
			event:StopPropagation()
		end, false)
	end

	-- Brush radius slider (scatter area)
	local brushRadSlider = doc:GetElementById("slider-lp-brush-radius")
	if brushRadSlider then
		trackSliderDrag(brushRadSlider, "lp-brush-radius")
		brushRadSlider:AddEventListener("change", function(event)
			if updatingFromCode then return end
			local val = tonumber(brushRadSlider:GetAttribute("value")) or 200
			if WG.LightPlacer then WG.LightPlacer.setRadius(val) end
			event:StopPropagation()
		end, false)
	end
	local brushRadDown = doc:GetElementById("btn-lp-brush-radius-down")
	if brushRadDown then
		brushRadDown:AddEventListener("click", function(event)
			if WG.LightPlacer then
				local s = WG.LightPlacer.getState()
				WG.LightPlacer.setRadius(s.radius - 8)
			end
			event:StopPropagation()
		end, false)
	end
	local brushRadUp = doc:GetElementById("btn-lp-brush-radius-up")
	if brushRadUp then
		brushRadUp:AddEventListener("click", function(event)
			if WG.LightPlacer then
				local s = WG.LightPlacer.getState()
				WG.LightPlacer.setRadius(s.radius + 8)
			end
			event:StopPropagation()
		end, false)
	end

	-- Smart filter toggle
	local smartToggleBtn = doc:GetElementById("btn-lp-smart-toggle")
	if smartToggleBtn then
		smartToggleBtn:AddEventListener("click", function(event)
			if WG.LightPlacer then
				local s = WG.LightPlacer.getState()
				WG.LightPlacer.setSmartEnabled(not s.smartEnabled)
			end
			event:StopPropagation()
		end, false)
	end
	local sfWaterBtn = doc:GetElementById("btn-lp-sf-water")
	if sfWaterBtn then
		sfWaterBtn:AddEventListener("click", function(event)
			if WG.LightPlacer then
				local s = WG.LightPlacer.getState()
				WG.LightPlacer.setSmartFilter("avoidWater", not s.smartFilters.avoidWater)
				sfWaterBtn:SetAttribute("src", (not s.smartFilters.avoidWater)
					and "/luaui/images/terraform_brush/check_on.png"
					or "/luaui/images/terraform_brush/check_off.png")
			end
			event:StopPropagation()
		end, false)
	end
	local sfCliffsBtn = doc:GetElementById("btn-lp-sf-cliffs")
	if sfCliffsBtn then
		sfCliffsBtn:AddEventListener("click", function(event)
			if WG.LightPlacer then
				local s = WG.LightPlacer.getState()
				WG.LightPlacer.setSmartFilter("avoidCliffs", not s.smartFilters.avoidCliffs)
				sfCliffsBtn:SetAttribute("src", (not s.smartFilters.avoidCliffs)
					and "/luaui/images/terraform_brush/check_on.png"
					or "/luaui/images/terraform_brush/check_off.png")
			end
			event:StopPropagation()
		end, false)
	end

	-- Action buttons: library, undo, redo, save, load, clear all
	local libraryBtn = doc:GetElementById("btn-lp-library")
	if libraryBtn then
		libraryBtn:AddEventListener("click", function(event)
			playSound("panelOpen")
			widgetState.lightLibraryOpen = not widgetState.lightLibraryOpen
			event:StopPropagation()
		end, false)
	end
	local undoBtn = doc:GetElementById("btn-lp-undo")
	if undoBtn then
		undoBtn:AddEventListener("click", function(event)
			playSound("undo")
			if WG.LightPlacer then WG.LightPlacer.undo() end
			event:StopPropagation()
		end, false)
	end
	local redoBtn = doc:GetElementById("btn-lp-redo")
	if redoBtn then
		redoBtn:AddEventListener("click", function(event)
			playSound("undo")
			if WG.LightPlacer then WG.LightPlacer.redo() end
			event:StopPropagation()
		end, false)
	end
	-- Light history slider
	local sliderLpHistory = doc:GetElementById("slider-lp-history")
	if sliderLpHistory then
		trackSliderDrag(sliderLpHistory, "lp-history")
		sliderLpHistory:AddEventListener("change", function(event)
			if updatingFromCode then event:StopPropagation(); return end
			if not WG.LightPlacer then event:StopPropagation(); return end
			local val = tonumber(sliderLpHistory:GetAttribute("value")) or 0
			local lpSt = WG.LightPlacer.getState()
			if not lpSt then event:StopPropagation(); return end
			local currentUndoCount = lpSt.undoCount or 0
			local diff = val - currentUndoCount
			if diff > 0 then
				for i = 1, diff do
					WG.LightPlacer.redo()
				end
			elseif diff < 0 then
				for i = 1, -diff do
					WG.LightPlacer.undo()
				end
			end
			event:StopPropagation()
		end, false)
	end
	local saveBtn = doc:GetElementById("btn-lp-save")
	if saveBtn then
		saveBtn:AddEventListener("click", function(event)
			playSound("save")
			if WG.LightPlacer then WG.LightPlacer.save() end
			event:StopPropagation()
		end, false)
	end
	local loadBtn = doc:GetElementById("btn-lp-load")
	if loadBtn then
		loadBtn:AddEventListener("click", function(event)
			playSound("dropdown")
			if WG.LightPlacer then WG.LightPlacer.load() end
			event:StopPropagation()
		end, false)
	end
	local clearAllBtn = doc:GetElementById("btn-lp-clear-all")
	if clearAllBtn then
		clearAllBtn:AddEventListener("click", function(event)
			playSound("reset")
			if WG.LightPlacer then WG.LightPlacer.clearAll() end
			event:StopPropagation()
		end, false)
	end

	end)() -- end Environment+LightPlacer IIFE

	-- ============ Skybox Library floating window ============

	widgetState.skyboxLibraryRootEl = doc:GetElementById("tf-skybox-library-root")

	-- Toggle button in environment panel
	local skyboxLibBtn = doc:GetElementById("btn-env-skybox-library")
	if skyboxLibBtn then
		skyboxLibBtn:AddEventListener("click", function(event)
			playSound(skyboxLibraryOpen and "click" or "panelOpen")
			skyboxLibraryOpen = not skyboxLibraryOpen
			if widgetState.skyboxLibraryRootEl then
				widgetState.skyboxLibraryRootEl:SetClass("hidden", not skyboxLibraryOpen)
			end
			skyboxLibBtn:SetClass("env-open", skyboxLibraryOpen == true)
			event:StopPropagation()
		end, false)
	end

	-- Close button on library window
	local skyboxLibCloseBtn = doc:GetElementById("btn-skybox-library-close")
	if skyboxLibCloseBtn then
		skyboxLibCloseBtn:AddEventListener("click", function(event)
			playSound("click")
			skyboxLibraryOpen = false
			if widgetState.skyboxLibraryRootEl then
				widgetState.skyboxLibraryRootEl:SetClass("hidden", true)
			end
			if skyboxLibBtn then skyboxLibBtn:SetClass("env-open", false) end
			event:StopPropagation()
		end, false)
	end

	-- ============ Light Library floating window ============
	;(function()
	widgetState.lightLibraryRootEl = doc:GetElementById("tf-light-library-root")
	local llBuiltinList = doc:GetElementById("ll-builtin-list")
	local llUserList    = doc:GetElementById("ll-user-list")
	local llSearchInput = doc:GetElementById("ll-search-input")

	local function getLLSearchFilter()
		if llSearchInput then
			local val = llSearchInput:GetAttribute("value") or ""
			return val:lower()
		end
		return ""
	end

	-- Helper: populate builtin presets list
	local function populateBuiltinPresets(filter)
		if not llBuiltinList or not WG.LightPlacer then return end
		filter = filter or getLLSearchFilter()
		llBuiltinList.inner_rml = ""
		local presets = WG.LightPlacer.getBuiltinPresets()
		if not presets then return end
		local shown = {}
		for i, preset in ipairs(presets) do
			local name = preset.name or "Unnamed"
			if filter == "" or name:lower():find(filter, 1, true) or (preset.desc or ""):lower():find(filter, 1, true) then
				shown[#shown + 1] = { idx = i, preset = preset }
			end
		end
		for _, entry in ipairs(shown) do
			local i = entry.idx
			local preset = entry.preset
			local itemId = "ll-builtin-" .. i
			local html = '<div id="' .. itemId .. '" class="ll-preset-item">'
				.. '<div class="ll-preset-name">' .. (preset.name or "Unnamed") .. '</div>'
				.. '<div class="ll-preset-desc">' .. (preset.desc or "") .. ' (' .. #preset.lights .. ' lights)</div>'
				.. '</div>'
			llBuiltinList.inner_rml = llBuiltinList.inner_rml .. html
		end
		-- Bind click events after populating
		for _, entry in ipairs(shown) do
			local i = entry.idx
			local preset = entry.preset
			local item = doc:GetElementById("ll-builtin-" .. i)
			if item then
				item:AddEventListener("click", function(event)
					widgetState.lightLibrarySelectedPreset = preset
					for _, e2 in ipairs(shown) do
						local el = doc:GetElementById("ll-builtin-" .. e2.idx)
						if el then el:SetClass("selected", e2.idx == i) end
					end
					event:StopPropagation()
				end, false)
				item:AddEventListener("dblclick", function(event)
					if WG.LightPlacer then
						local mx, my = GetMouseState()
						local _, coords = TraceScreenRay(mx, my, true)
						if coords then
							WG.LightPlacer.placePreset(preset, coords[1], coords[3])
						end
					end
					event:StopPropagation()
				end, false)
			end
		end
	end

	-- Helper: populate user presets list
	local function populateUserPresets(filter)
		if not llUserList or not WG.LightPlacer then return end
		filter = filter or getLLSearchFilter()
		llUserList.inner_rml = ""
		local presets = WG.LightPlacer.listUserPresets()
		if not presets or #presets == 0 then
			llUserList.inner_rml = '<div class="text-xs text-keybind" style="padding: 4dp;">No saved user presets yet.</div>'
			return
		end
		local shown = {}
		for i, p in ipairs(presets) do
			local name = p.name or "?"
			if filter == "" or name:lower():find(filter, 1, true) then
				shown[#shown + 1] = { idx = i, p = p }
			end
		end
		for _, entry in ipairs(shown) do
			local i = entry.idx
			local p = entry.p
			local itemId = "ll-user-" .. i
			local html = '<div id="' .. itemId .. '" class="ll-preset-item">'
				.. '<div class="ll-preset-name">' .. (p.name or "?") .. '</div>'
				.. '</div>'
			llUserList.inner_rml = llUserList.inner_rml .. html
		end
		for _, entry in ipairs(shown) do
			local i = entry.idx
			local p = entry.p
			local item = doc:GetElementById("ll-user-" .. i)
			if item then
				item:AddEventListener("click", function(event)
					local data = WG.LightPlacer.loadPresetFile(p.path)
					if data then
						widgetState.lightLibrarySelectedPreset = data
					end
					for _, e2 in ipairs(shown) do
						local el = doc:GetElementById("ll-user-" .. e2.idx)
						if el then el:SetClass("selected", e2.idx == i) end
					end
					event:StopPropagation()
				end, false)
				item:AddEventListener("dblclick", function(event)
					local data = WG.LightPlacer.loadPresetFile(p.path)
					if data and WG.LightPlacer then
						local mx, my = GetMouseState()
						local _, coords = TraceScreenRay(mx, my, true)
						if coords then
							WG.LightPlacer.placePreset(data, coords[1], coords[3])
						end
					end
					event:StopPropagation()
				end, false)
			end
		end
	end

	-- Library button (in light controls) toggles library window
	-- Already bound above to widgetState.lightLibraryOpen toggle;
	-- Now also toggle the root element visibility
	local origLibraryBtn = doc:GetElementById("btn-lp-library")
	if origLibraryBtn then
		origLibraryBtn:AddEventListener("click", function(event)
			if widgetState.lightLibraryRootEl then
				widgetState.lightLibraryRootEl:SetClass("hidden", not widgetState.lightLibraryOpen)
				if widgetState.lightLibraryOpen then
					populateBuiltinPresets()
					if widgetState.lightLibraryTab == "user" then
						populateUserPresets()
					end
				end
			end
		end, false)
	end

	-- Tab buttons
	local tabBuiltin = doc:GetElementById("btn-ll-tab-builtin")
	local tabUser    = doc:GetElementById("btn-ll-tab-user")
	if tabBuiltin then
		tabBuiltin:AddEventListener("click", function(event)
			playSound("click")
			widgetState.lightLibraryTab = "builtin"
			if tabBuiltin then tabBuiltin:SetClass("active", true) end
			if tabUser then tabUser:SetClass("active", false) end
			if llBuiltinList then llBuiltinList:SetClass("hidden", false) end
			if llUserList then llUserList:SetClass("hidden", true) end
			event:StopPropagation()
		end, false)
	end
	if tabUser then
		tabUser:AddEventListener("click", function(event)
			playSound("click")
			widgetState.lightLibraryTab = "user"
			if tabBuiltin then tabBuiltin:SetClass("active", false) end
			if tabUser then tabUser:SetClass("active", true) end
			if llBuiltinList then llBuiltinList:SetClass("hidden", true) end
			if llUserList then llUserList:SetClass("hidden", false) end
			populateUserPresets()
			event:StopPropagation()
		end, false)
	end

	-- Close button
	local llCloseBtn = doc:GetElementById("btn-light-library-close")
	if llCloseBtn then
		llCloseBtn:AddEventListener("click", function(event)
			playSound("click")
			widgetState.lightLibraryOpen = false
			if widgetState.lightLibraryRootEl then
				widgetState.lightLibraryRootEl:SetClass("hidden", true)
			end
			event:StopPropagation()
		end, false)
	end

	-- Search bar filtering
	if llSearchInput then
		llSearchInput:AddEventListener("change", function(event)
			local filter = getLLSearchFilter()
			if widgetState.lightLibraryTab == "builtin" then
				populateBuiltinPresets(filter)
			else
				populateUserPresets(filter)
			end
		end, false)
	end
	local llSearchClear = doc:GetElementById("btn-ll-search-clear")
	if llSearchClear then
		llSearchClear:AddEventListener("click", function(event)
			if llSearchInput then
				llSearchInput:SetAttribute("value", "")
			end
			if widgetState.lightLibraryTab == "builtin" then
				populateBuiltinPresets("")
			else
				populateUserPresets("")
			end
			event:StopPropagation()
		end, false)
	end

	-- Save preset button
	local llSaveBtn = doc:GetElementById("btn-ll-save-preset")
	local llNameInput = doc:GetElementById("input-ll-preset-name")
	if llSaveBtn then
		llSaveBtn:AddEventListener("click", function(event)
			playSound("save")
			if WG.LightPlacer and llNameInput then
				local name = llNameInput:GetAttribute("value") or ""
				if name ~= "" then
					WG.LightPlacer.saveUserPreset(name)
					populateUserPresets()
				end
			end
			event:StopPropagation()
		end, false)
	end

	-- Delete selected preset
	local llDeleteBtn = doc:GetElementById("btn-ll-delete-preset")
	if llDeleteBtn then
		llDeleteBtn:AddEventListener("click", function(event)
			playSound("reset")
			local sel = widgetState.lightLibrarySelectedPreset
			if sel and sel.name and WG.LightPlacer then
				-- Only delete user presets (ones loaded from files)
				local presets = WG.LightPlacer.listUserPresets()
				for _, p in ipairs(presets) do
					if p.name == sel.name then
						os.remove(p.path)
						widgetState.lightLibrarySelectedPreset = nil
						populateUserPresets()
						break
					end
				end
			end
			event:StopPropagation()
		end, false)
	end

	-- Refresh button
	local llRefreshBtn = doc:GetElementById("btn-ll-refresh")
	if llRefreshBtn then
		llRefreshBtn:AddEventListener("click", function(event)
			playSound("click")
			populateBuiltinPresets()
			populateUserPresets()
			event:StopPropagation()
		end, false)
	end
	end)() -- end Light Library IIFE

	-- ============ Noise Brush controls ============

	widgetState.noiseRootEl = doc:GetElementById("tf-noise-root")

	-- Noise close button
	local noiseCloseBtn = doc:GetElementById("btn-noise-close")
	if noiseCloseBtn then
		noiseCloseBtn:AddEventListener("click", function(event)
			playSound("click")
			noiseManuallyHidden = true
			if widgetState.noiseRootEl then
				widgetState.noiseRootEl:SetClass("hidden", true)
			end
			event:StopPropagation()
		end, false)
	end

	-- Noise type buttons
	widgetState.noiseTypeButtons.perlin = doc:GetElementById("btn-noise-perlin")
	widgetState.noiseTypeButtons.voronoi = doc:GetElementById("btn-noise-voronoi")
	widgetState.noiseTypeButtons.fbm = doc:GetElementById("btn-noise-fbm")
	widgetState.noiseTypeButtons.billow = doc:GetElementById("btn-noise-billow")

	for ntype, element in pairs(widgetState.noiseTypeButtons) do
		if element then
			element:AddEventListener("click", function(event)
				playSound("modeSwitch")
				if WG.TerraformBrush then WG.TerraformBrush.setNoiseType(ntype) end
				setActiveClass(widgetState.noiseTypeButtons, ntype)
				event:StopPropagation()
			end, false)
		end
	end

	-- Noise scale slider + buttons
	local noiseSliderScale = doc:GetElementById("slider-noise-scale")
	if noiseSliderScale then
		trackSliderDrag(noiseSliderScale, "noise-scale")
		noiseSliderScale:AddEventListener("change", function(event)
			if not updatingFromCode and WG.TerraformBrush then
				local val = tonumber(noiseSliderScale:GetAttribute("value")) or 64
				WG.TerraformBrush.setNoiseScale(val)
				local label = doc:GetElementById("noise-scale-label")
				if label then label.inner_rml = tostring(val) end
			end
			event:StopPropagation()
		end, false)
	end

	local noiseBtn = doc:GetElementById("btn-noise-scale-up")
	if noiseBtn then
		noiseBtn:AddEventListener("click", function(event)
			if WG.TerraformBrush and noiseSliderScale then
				local val = math.min(512, (tonumber(noiseSliderScale:GetAttribute("value")) or 64) + 8)
				WG.TerraformBrush.setNoiseScale(val)
				noiseSliderScale:SetAttribute("value", tostring(val))
				local label = doc:GetElementById("noise-scale-label")
				if label then label.inner_rml = tostring(val) end
			end
			event:StopPropagation()
		end, false)
	end

	noiseBtn = doc:GetElementById("btn-noise-scale-down")
	if noiseBtn then
		noiseBtn:AddEventListener("click", function(event)
			if WG.TerraformBrush and noiseSliderScale then
				local val = math.max(8, (tonumber(noiseSliderScale:GetAttribute("value")) or 64) - 8)
				WG.TerraformBrush.setNoiseScale(val)
				noiseSliderScale:SetAttribute("value", tostring(val))
				local label = doc:GetElementById("noise-scale-label")
				if label then label.inner_rml = tostring(val) end
			end
			event:StopPropagation()
		end, false)
	end

	-- Noise octaves slider + buttons
	local noiseSliderOctaves = doc:GetElementById("slider-noise-octaves")
	if noiseSliderOctaves then
		trackSliderDrag(noiseSliderOctaves, "noise-octaves")
		noiseSliderOctaves:AddEventListener("change", function(event)
			if not updatingFromCode and WG.TerraformBrush then
				local val = tonumber(noiseSliderOctaves:GetAttribute("value")) or 4
				WG.TerraformBrush.setNoiseOctaves(val)
				local label = doc:GetElementById("noise-octaves-label")
				if label then label.inner_rml = tostring(val) end
			end
			event:StopPropagation()
		end, false)
	end

	noiseBtn = doc:GetElementById("btn-noise-octaves-up")
	if noiseBtn then
		noiseBtn:AddEventListener("click", function(event)
			if WG.TerraformBrush and noiseSliderOctaves then
				local val = math.min(8, (tonumber(noiseSliderOctaves:GetAttribute("value")) or 4) + 1)
				WG.TerraformBrush.setNoiseOctaves(val)
				noiseSliderOctaves:SetAttribute("value", tostring(val))
				local label = doc:GetElementById("noise-octaves-label")
				if label then label.inner_rml = tostring(val) end
			end
			event:StopPropagation()
		end, false)
	end

	noiseBtn = doc:GetElementById("btn-noise-octaves-down")
	if noiseBtn then
		noiseBtn:AddEventListener("click", function(event)
			if WG.TerraformBrush and noiseSliderOctaves then
				local val = math.max(1, (tonumber(noiseSliderOctaves:GetAttribute("value")) or 4) - 1)
				WG.TerraformBrush.setNoiseOctaves(val)
				noiseSliderOctaves:SetAttribute("value", tostring(val))
				local label = doc:GetElementById("noise-octaves-label")
				if label then label.inner_rml = tostring(val) end
			end
			event:StopPropagation()
		end, false)
	end

	-- Noise persistence slider + buttons
	local noiseSliderPersist = doc:GetElementById("slider-noise-persistence")
	if noiseSliderPersist then
		trackSliderDrag(noiseSliderPersist, "noise-persistence")
		noiseSliderPersist:AddEventListener("change", function(event)
			if not updatingFromCode and WG.TerraformBrush then
				local val = tonumber(noiseSliderPersist:GetAttribute("value")) or 50
				WG.TerraformBrush.setNoisePersistence(val / 100)
				local label = doc:GetElementById("noise-persistence-label")
				if label then label.inner_rml = string.format("%.2f", val / 100) end
			end
			event:StopPropagation()
		end, false)
	end

	noiseBtn = doc:GetElementById("btn-noise-persist-up")
	if noiseBtn then
		noiseBtn:AddEventListener("click", function(event)
			if WG.TerraformBrush and noiseSliderPersist then
				local val = math.min(90, (tonumber(noiseSliderPersist:GetAttribute("value")) or 50) + 5)
				WG.TerraformBrush.setNoisePersistence(val / 100)
				noiseSliderPersist:SetAttribute("value", tostring(val))
				local label = doc:GetElementById("noise-persistence-label")
				if label then label.inner_rml = string.format("%.2f", val / 100) end
			end
			event:StopPropagation()
		end, false)
	end

	noiseBtn = doc:GetElementById("btn-noise-persist-down")
	if noiseBtn then
		noiseBtn:AddEventListener("click", function(event)
			if WG.TerraformBrush and noiseSliderPersist then
				local val = math.max(10, (tonumber(noiseSliderPersist:GetAttribute("value")) or 50) - 5)
				WG.TerraformBrush.setNoisePersistence(val / 100)
				noiseSliderPersist:SetAttribute("value", tostring(val))
				local label = doc:GetElementById("noise-persistence-label")
				if label then label.inner_rml = string.format("%.2f", val / 100) end
			end
			event:StopPropagation()
		end, false)
	end

	-- Noise lacunarity slider + buttons
	local noiseSliderLacun = doc:GetElementById("slider-noise-lacunarity")
	if noiseSliderLacun then
		trackSliderDrag(noiseSliderLacun, "noise-lacunarity")
		noiseSliderLacun:AddEventListener("change", function(event)
			if not updatingFromCode and WG.TerraformBrush then
				local val = tonumber(noiseSliderLacun:GetAttribute("value")) or 20
				WG.TerraformBrush.setNoiseLacunarity(val / 10)
				local label = doc:GetElementById("noise-lacunarity-label")
				if label then label.inner_rml = string.format("%.1f", val / 10) end
			end
			event:StopPropagation()
		end, false)
	end

	noiseBtn = doc:GetElementById("btn-noise-lacun-up")
	if noiseBtn then
		noiseBtn:AddEventListener("click", function(event)
			if WG.TerraformBrush and noiseSliderLacun then
				local val = math.min(40, (tonumber(noiseSliderLacun:GetAttribute("value")) or 20) + 1)
				WG.TerraformBrush.setNoiseLacunarity(val / 10)
				noiseSliderLacun:SetAttribute("value", tostring(val))
				local label = doc:GetElementById("noise-lacunarity-label")
				if label then label.inner_rml = string.format("%.1f", val / 10) end
			end
			event:StopPropagation()
		end, false)
	end

	noiseBtn = doc:GetElementById("btn-noise-lacun-down")
	if noiseBtn then
		noiseBtn:AddEventListener("click", function(event)
			if WG.TerraformBrush and noiseSliderLacun then
				local val = math.max(10, (tonumber(noiseSliderLacun:GetAttribute("value")) or 20) - 1)
				WG.TerraformBrush.setNoiseLacunarity(val / 10)
				noiseSliderLacun:SetAttribute("value", tostring(val))
				local label = doc:GetElementById("noise-lacunarity-label")
				if label then label.inner_rml = string.format("%.1f", val / 10) end
			end
			event:StopPropagation()
		end, false)
	end

	-- Noise seed slider + reseed button
	local noiseSliderSeed = doc:GetElementById("slider-noise-seed")
	if noiseSliderSeed then
		trackSliderDrag(noiseSliderSeed, "noise-seed")
		noiseSliderSeed:AddEventListener("change", function(event)
			if not updatingFromCode and WG.TerraformBrush then
				local val = tonumber(noiseSliderSeed:GetAttribute("value")) or 0
				WG.TerraformBrush.setNoiseSeed(val)
				local label = doc:GetElementById("noise-seed-label")
				if label then label.inner_rml = tostring(val) end
			end
			event:StopPropagation()
		end, false)
	end

	local noiseReseed = doc:GetElementById("btn-noise-reseed")
	if noiseReseed then
		noiseReseed:AddEventListener("click", function(event)
			local newSeed = math.floor(math.random() * 9999)
			if WG.TerraformBrush then WG.TerraformBrush.setNoiseSeed(newSeed) end
			if noiseSliderSeed then noiseSliderSeed:SetAttribute("value", tostring(newSeed)) end
			local label = doc:GetElementById("noise-seed-label")
			if label then label.inner_rml = tostring(newSeed) end
			event:StopPropagation()
		end, false)
	end

	local noiseSeedDown = doc:GetElementById("btn-noise-seed-down")
	if noiseSeedDown then
		noiseSeedDown:AddEventListener("click", function(event)
			if WG.TerraformBrush then
				local st = WG.TerraformBrush.getState()
				local cur = (st and st.noiseSeed) or 0
				local newVal = math.max(0, cur - 1)
				WG.TerraformBrush.setNoiseSeed(newVal)
				if noiseSliderSeed then noiseSliderSeed:SetAttribute("value", tostring(newVal)) end
				local label = doc:GetElementById("noise-seed-label")
				if label then label.inner_rml = tostring(newVal) end
			end
			event:StopPropagation()
		end, false)
	end

	local noiseSeedUp = doc:GetElementById("btn-noise-seed-up")
	if noiseSeedUp then
		noiseSeedUp:AddEventListener("click", function(event)
			if WG.TerraformBrush then
				local st = WG.TerraformBrush.getState()
				local cur = (st and st.noiseSeed) or 0
				local newVal = math.min(9999, cur + 1)
				WG.TerraformBrush.setNoiseSeed(newVal)
				if noiseSliderSeed then noiseSliderSeed:SetAttribute("value", tostring(newVal)) end
				local label = doc:GetElementById("noise-seed-label")
				if label then label.inner_rml = tostring(newVal) end
			end
			event:StopPropagation()
		end, false)
	end

	-- ============ Start Positions tool controls ============
	attachStartPosListeners(doc)

	-- ============ Clone Tool controls ============
	attachCloneToolListeners(doc)

	attachGuideMode(doc)

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
			skyboxLibraryOpen = false
			widgetState.skyboxLibraryRootEl:SetClass("hidden", true)
		else
			widgetState.skyboxLibraryRootEl:SetClass("hidden", not skyboxLibraryOpen)
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
		widgetState.shapeRowEl:SetClass("hidden", envActive or lpActive or gbActive or clActive)
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
	if noiseActive and not lastNoiseActive then
		noiseManuallyHidden = false
	end
	lastNoiseActive = noiseActive
	if widgetState.noiseRootEl then
		widgetState.noiseRootEl:SetClass("hidden", not noiseActive or noiseManuallyHidden)
	end

	-- Disable ring shape when in feature, weather, splat, or metal mode
	local ringBtn = widgetState.shapeButtons.ring
	if ringBtn then
		ringBtn:SetClass("disabled", fpActive or wbActive or spActive or mbActive or gbActive or false)
	end

	-- Disable fill+clay in metal mode; disable fill in feature mode
	local fillBtn = widgetState.shapeButtons.fill
	if fillBtn then
		fillBtn:SetClass("disabled", mbActive or fpActive or false)
	end
	local clayBtn = doc and doc:GetElementById("btn-clay-mode")
	if clayBtn then
		clayBtn:SetClass("disabled", mbActive or false)
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
			if shapeRowEl then shapeRowEl:SetClass("hidden", false) end
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
		-- ===== Metal Brush mode: update metal controls =====
		local metalBtn = doc and doc:GetElementById("btn-metal")
		if metalBtn then metalBtn:SetClass("active", true) end
		setActiveClass(widgetState.modeButtons, nil)

		-- Metal sub-mode buttons
		setActiveClass(widgetState.mbSubModeButtons, mbState.subMode)

		-- Metal value slider & label sync
		if doc then
			updatingFromCode = true
			local ds = draggingSlider

			local mbValueLabel = doc:GetElementById("mb-value-label")
			if mbValueLabel then mbValueLabel.inner_rml = string.format("%.1f", mbState.metalValue) end

			do
				local mv = math.max(0.01, mbState.metalValue)
				local sv = math.floor(1000 * math.log(mv / 0.01) / math.log(50.0 / 0.01) + 0.5)
				syncAndFlash(doc:GetElementById("slider-metal-value"), "mb-value", tostring(sv))
			end

			-- Sync size, rotation, length, curve from shared terraform state
			local tfSt2 = WG.TerraformBrush and WG.TerraformBrush.getState()
			if tfSt2 then
				local mbSizeLabel = doc:GetElementById("mb-size-label")
				if mbSizeLabel then mbSizeLabel.inner_rml = tostring(tfSt2.radius) end
				syncAndFlash(doc:GetElementById("slider-mb-size"), "mb-size", tostring(tfSt2.radius))

				local mbRotLabel = doc:GetElementById("mb-rotation-label")
				if mbRotLabel then mbRotLabel.inner_rml = tostring(tfSt2.rotationDeg) .. "&#176;" end
				syncAndFlash(doc:GetElementById("slider-mb-rotation"), "mb-rotation", tostring(tfSt2.rotationDeg))

				local mbLenLabel = doc:GetElementById("mb-length-label")
				if mbLenLabel then mbLenLabel.inner_rml = string.format("%.1f", tfSt2.lengthScale) end
				syncAndFlash(doc:GetElementById("slider-mb-length"), "mb-length", tostring(math.floor(tfSt2.lengthScale * 10 + 0.5)))

				local mbCurveLabel = doc:GetElementById("mb-curve-label")
				if mbCurveLabel then mbCurveLabel.inner_rml = string.format("%.1f", tfSt2.curve) end
				syncAndFlash(doc:GetElementById("slider-mb-curve"), "mb-curve", tostring(math.floor(tfSt2.curve * 10 + 0.5)))
			end

			updatingFromCode = false
		end

		-- Shape: use terraform brush shape (shared)
		local tfSt = WG.TerraformBrush and WG.TerraformBrush.getState()
		if tfSt then
			setActiveClass(widgetState.shapeButtons, tfSt.shape)
		end

		do
			local tfSt2 = WG.TerraformBrush and WG.TerraformBrush.getState()
			local sm = mbState.subMode or "paint"
			setSummary("METAL", "#14b8a6",
				"", sm:upper(),
				"R ", tostring(tfSt2 and tfSt2.radius or "?"),
				"Val ", string.format("%.1f", mbState.metalValue or 0),
				"Crv ", string.format("%.1f", tfSt2 and tfSt2.curve or 0))
		end

	elseif gbActive then
		-- ===== Grass Brush mode: update grass controls =====
		local grassBtn = doc and doc:GetElementById("btn-grass")
		if grassBtn then grassBtn:SetClass("active", true) end
		setActiveClass(widgetState.modeButtons, nil)

		-- Grass sub-mode buttons
		setActiveClass(widgetState.gbSubModeButtons, gbState.subMode)

		-- Update clay button: unavailable in grass mode
		local clayBtnG = doc and doc:GetElementById("btn-clay-mode")
		if clayBtnG then
			clayBtnG:SetClass("unavailable", true)
		end

		-- Grass density slider & label sync
		if doc then
			updatingFromCode = true

			local gbDensityLabel = doc:GetElementById("gb-density-label")
			if gbDensityLabel then gbDensityLabel.inner_rml = tostring(math.floor(gbState.density * 100 + 0.5)) .. "%" end

			do
				local sv = math.floor(gbState.density * 100 + 0.5)
				syncAndFlash(doc:GetElementById("slider-grass-density"), "gb-density", tostring(sv))
			end

			-- Sync size, rotation, curve, length from grass brush own state
			do
				local gbSizeLabel = doc:GetElementById("gb-size-label")
				if gbSizeLabel then gbSizeLabel.inner_rml = tostring(gbState.radius or 100) end
				syncAndFlash(doc:GetElementById("slider-gb-size"), "gb-size", tostring(gbState.radius or 100))

				local gbRotLabel = doc:GetElementById("gb-rotation-label")
				if gbRotLabel then gbRotLabel.inner_rml = tostring(gbState.rotationDeg or 0) .. "&#176;" end
				syncAndFlash(doc:GetElementById("slider-gb-rotation"), "gb-rotation", tostring(gbState.rotationDeg or 0))

				local gbCurveLabel = doc:GetElementById("gb-curve-label")
				if gbCurveLabel then gbCurveLabel.inner_rml = string.format("%.1f", gbState.curve or 1.0) end
				syncAndFlash(doc:GetElementById("slider-gb-curve"), "gb-curve", tostring(math.floor((gbState.curve or 1.0) * 10 + 0.5)))

				local gbLenLabel = doc:GetElementById("gb-length-label")
				if gbLenLabel then gbLenLabel.inner_rml = string.format("%.1f", gbState.lengthScale or 1.0) end
				syncAndFlash(doc:GetElementById("slider-gb-length"), "gb-length", tostring(math.floor((gbState.lengthScale or 1.0) * 10 + 0.5)))
			end

			-- Smart filter UI sync
			do
				local smartOn = gbState.smartEnabled
				local smartToggle = doc:GetElementById("btn-gb-smart-toggle")
				if smartToggle then smartToggle:SetAttribute("src", smartOn and "/luaui/images/terraform_brush/check_on.png" or "/luaui/images/terraform_brush/check_off.png") end
				local smartOpts = doc:GetElementById("gb-smart-options")
				if smartOpts then smartOpts:SetClass("hidden", not smartOn) end

				local sf = gbState.smartFilters or {}
				local function syncSmartCheck(id, key)
					local el = doc:GetElementById(id)
					if el then el:SetAttribute("src", sf[key] and "/luaui/images/terraform_brush/check_on.png" or "/luaui/images/terraform_brush/check_off.png") end
				end
				syncSmartCheck("btn-gb-avoid-water",    "avoidWater")
				syncSmartCheck("btn-gb-avoid-cliffs",   "avoidCliffs")
				syncSmartCheck("btn-gb-prefer-slopes",  "preferSlopes")
				syncSmartCheck("btn-gb-alt-min-enable", "altMinEnable")
				syncSmartCheck("btn-gb-alt-max-enable", "altMaxEnable")

				-- Slope max slider visibility
				local slopeMaxRow = doc:GetElementById("gb-smart-slope-max-row")
				local slopeMaxSl = doc:GetElementById("gb-smart-slope-max-slider-row")
				if slopeMaxRow then slopeMaxRow:SetClass("hidden", not sf.avoidCliffs) end
				if slopeMaxSl then slopeMaxSl:SetClass("hidden", not sf.avoidCliffs) end
				local slopeMaxLabel = doc:GetElementById("gb-smart-slope-max-label")
				if slopeMaxLabel then slopeMaxLabel.inner_rml = tostring(sf.slopeMax or 45) end
				syncAndFlash(doc:GetElementById("slider-gb-slope-max"), "gb-slope-max", tostring(sf.slopeMax or 45))

				-- Slope min slider visibility
				local slopeMinRow = doc:GetElementById("gb-smart-slope-min-row")
				local slopeMinSl = doc:GetElementById("gb-smart-slope-min-slider-row")
				if slopeMinRow then slopeMinRow:SetClass("hidden", not sf.preferSlopes) end
				if slopeMinSl then slopeMinSl:SetClass("hidden", not sf.preferSlopes) end
				local slopeMinLabel = doc:GetElementById("gb-smart-slope-min-label")
				if slopeMinLabel then slopeMinLabel.inner_rml = tostring(sf.slopeMin or 10) end
				syncAndFlash(doc:GetElementById("slider-gb-slope-min"), "gb-slope-min", tostring(sf.slopeMin or 10))

				-- Altitude min slider visibility
				local altMinSl = doc:GetElementById("gb-smart-alt-min-slider-row")
				if altMinSl then altMinSl:SetClass("hidden", not sf.altMinEnable) end
				local altMinLabel = doc:GetElementById("gb-smart-alt-min-label")
				if altMinLabel then altMinLabel.inner_rml = tostring(sf.altMin or 0) end
				syncAndFlash(doc:GetElementById("slider-gb-alt-min"), "gb-alt-min", tostring(sf.altMin or 0))

				-- Altitude max slider visibility
				local altMaxSl = doc:GetElementById("gb-smart-alt-max-slider-row")
				if altMaxSl then altMaxSl:SetClass("hidden", not sf.altMaxEnable) end
				local altMaxLabel = doc:GetElementById("gb-smart-alt-max-label")
				if altMaxLabel then altMaxLabel.inner_rml = tostring(sf.altMax or 200) end
				syncAndFlash(doc:GetElementById("slider-gb-alt-max"), "gb-alt-max", tostring(sf.altMax or 200))
			end

			-- Color filter UI sync
			do
				local colorOn = gbState.texFilterEnabled
				local colorToggle = doc:GetElementById("btn-gb-color-toggle")
				if colorToggle then colorToggle:SetAttribute("src", colorOn and "/luaui/images/terraform_brush/check_on.png" or "/luaui/images/terraform_brush/check_off.png") end
				local colorOpts = doc:GetElementById("gb-color-options")
				if colorOpts then colorOpts:SetClass("hidden", not colorOn) end

				-- Color swatch: update background from filter color
				local tc = gbState.texFilterColor or {}
				local swatchEl = doc:GetElementById("gb-tex-color-swatch")
				if swatchEl then
					local ri = math.floor(math.min(math.max(tc[1] or 0, 0), 1) * 255 + 0.5)
					local gi = math.floor(math.min(math.max(tc[2] or 0, 0), 1) * 255 + 0.5)
					local bi = math.floor(math.min(math.max(tc[3] or 0, 0), 1) * 255 + 0.5)
					swatchEl:SetAttribute("style", string.format("background-color: rgb(%d, %d, %d);", ri, gi, bi))
				end

				-- Pipette button active state
				local pipBtn = doc:GetElementById("btn-gb-pipette")
				if pipBtn then pipBtn:SetClass("active", gbState.pipetteMode or false) end

				-- Threshold slider
				local threshVal = math.floor((gbState.texFilterThreshold or 0.35) * 100 + 0.5)
				syncAndFlash(doc:GetElementById("slider-gb-color-thresh"), "gb-color-thresh", tostring(threshVal))
				local threshLabel = doc:GetElementById("gb-color-thresh-label")
				if threshLabel then threshLabel.inner_rml = tostring(threshVal) end

				-- Padding slider
				local padVal = gbState.texFilterPadding or 0
				syncAndFlash(doc:GetElementById("slider-gb-color-pad"), "gb-color-pad", tostring(math.floor(padVal + 0.5)))
				local padLabel = doc:GetElementById("gb-color-pad-label")
				if padLabel then padLabel.inner_rml = tostring(math.floor(padVal + 0.5)) end

				-- Exclude toggle
				local exOn = gbState.texExcludeEnabled
				local exToggle = doc:GetElementById("btn-gb-exclude-toggle")
				if exToggle then exToggle:SetAttribute("src", exOn and "/luaui/images/terraform_brush/check_on.png" or "/luaui/images/terraform_brush/check_off.png") end

				-- Exclude swatch
				local ec = gbState.texFilterColor or {}
				local exSwatchEl = doc:GetElementById("gb-tex-exclude-swatch")
				if exSwatchEl then
					local ri = math.floor(math.min(math.max(ec[5] or 0.65, 0), 1) * 255 + 0.5)
					local gi = math.floor(math.min(math.max(ec[6] or 0.35, 0), 1) * 255 + 0.5)
					local bi = math.floor(math.min(math.max(ec[7] or 0.10, 0), 1) * 255 + 0.5)
					exSwatchEl:SetAttribute("style", string.format("background-color: rgb(%d, %d, %d);", ri, gi, bi))
				end

				-- Exclude pipette active state
				local exPipBtn = doc:GetElementById("btn-gb-exclude-pipette")
				if exPipBtn then exPipBtn:SetClass("active", gbState.pipetteExcludeMode or false) end
			end

			-- History slider sync
			do
				local histIdx = gbState.historyIndex or 0
				local histMax = gbState.historyMax or 0
				local slH = doc:GetElementById("slider-gb-history")
				if slH then
					slH:SetAttribute("max", tostring(histMax))
					syncAndFlash(slH, "gb-history", tostring(histIdx))
				end
				local numH = doc:GetElementById("slider-gb-history-numbox")
				if numH then numH:SetAttribute("value", tostring(histIdx)) end
			end

			updatingFromCode = false
		end

		-- Shape: use grass brush shape (own state)
		if gbState.shape then
			setActiveClass(widgetState.gbShapeButtons, gbState.shape)
		end

		-- Gray out ring and unsupported shapes
		for shape, element in pairs(widgetState.shapeButtons) do
			if element and shape ~= "ring" then
				element:SetClass("disabled", false)
			end
		end

		do
			local gApi = WG['grassgl4']
			local hasGrass = gApi and gApi.hasGrass and gApi.hasGrass()
			if not hasGrass then
				if sumEl then
					local sep = '<span class="tf-ss-sep">|</span>'
					sumEl.inner_rml = '<span class="tf-ss-mode" style="color: #10b981;">GRASS</span>' .. sep .. '<span class="tf-ss-val" style="color: #fbbf24;">No grass data for this map</span>'
				end
			else
				setSummary("GRASS", "#10b981",
					"", (gbState.subMode or "paint"):upper(),
					"", shapeNames[gbState.shape] or "Circle",
					"R ", tostring(gbState.radius or 0),
					"Density ", string.format("%.0f", (gbState.density or 0) * 100) .. "%")
			end
		end

	elseif wbActive then
		-- Weather mode: highlight weather button, update shape, sync controls
		local weatherBtn = doc and doc:GetElementById("btn-weather")
		if weatherBtn then weatherBtn:SetClass("active", true) end
		setActiveClass(widgetState.modeButtons, nil)
		setActiveClass(widgetState.shapeButtons, wbState.shape)

		-- Weather sub-mode buttons
		setActiveClass(widgetState.wbSubModeButtons, wbState.mode)

		-- Weather distribution buttons
		setActiveClass(widgetState.wbDistButtons, wbState.distribution)

		if doc then
			updatingFromCode = true
			local ds = draggingSlider

			-- Weather labels
			local wbRadiusLabel = doc:GetElementById("wb-radius-label")
			if wbRadiusLabel then wbRadiusLabel.inner_rml = tostring(wbState.radius) end

			local wbLengthLabel = doc:GetElementById("wb-length-label")
			if wbLengthLabel then wbLengthLabel.inner_rml = string.format("%.1f", wbState.lengthScale) end

			local wbRotationLabel = doc:GetElementById("wb-rotation-label")
			if wbRotationLabel then wbRotationLabel.inner_rml = tostring(wbState.rotation) end

			local wbCountLabel = doc:GetElementById("wb-count-label")
			if wbCountLabel then wbCountLabel.inner_rml = tostring(wbState.spawnCount) end

			local wbCadenceLabel = doc:GetElementById("wb-cadence-label")
			if wbCadenceLabel then wbCadenceLabel.inner_rml = tostring(wbState.cadence) end

			local wbFrequencyLabel = doc:GetElementById("wb-frequency-label")
			if wbFrequencyLabel then wbFrequencyLabel.inner_rml = formatFrequency(wbState.frequency) end

			local wbPersistentCount = doc:GetElementById("wb-persistent-count")
			if wbPersistentCount then wbPersistentCount.inner_rml = tostring(wbState.persistentCount) end

			-- Persistence label
			local persistLabel = doc:GetElementById("wb-persist-label")
			if persistLabel then
				local ps = wbState.persistenceSeconds
				if ps == 0 then
					persistLabel.inner_rml = "Off"
				elseif ps >= 3601 then
					persistLabel.inner_rml = "&#8734;"
				elseif ps >= 60 then
					persistLabel.inner_rml = string.format("%dm", math.floor(ps / 60))
				else
					persistLabel.inner_rml = string.format("%ds", ps)
				end
			end

			-- Persistence slider (log-mapped)
			local wbSliderPersist = doc:GetElementById("wb-slider-persist")
			if wbSliderPersist then
				if ds ~= "wb-persist" then
					wbSliderPersist:SetAttribute("value", tostring(persistToSlider(wbState.persistenceSeconds)))
				end
			end

			-- Persistent mode toggle
			local wbPersistToggle = doc:GetElementById("btn-wb-persistent")
			if wbPersistToggle then
				local isPerm = wbState.persistenceSeconds >= PERSIST_PERMANENT_VAL
				wbPersistToggle:SetAttribute("src", isPerm
					and "/luaui/images/terraform_brush/check_on.png"
					or "/luaui/images/terraform_brush/check_off.png")
			end

			-- Weather sliders
			syncAndFlash(doc:GetElementById("wb-slider-size"), "wb-size", tostring(wbState.radius))
			syncAndFlash(doc:GetElementById("wb-slider-length"), "wb-length", tostring(math.floor(wbState.lengthScale * 10 + 0.5)))
			syncAndFlash(doc:GetElementById("wb-slider-rotation"), "wb-rotation", tostring(wbState.rotation))
			syncAndFlash(doc:GetElementById("wb-slider-count"), "wb-count", tostring(wbState.spawnCount))
			syncAndFlash(doc:GetElementById("wb-slider-cadence"), "wb-cadence", tostring(cadenceToSlider(wbState.cadence)))
			syncAndFlash(doc:GetElementById("wb-slider-frequency"), "wb-frequency", tostring(frequencyToSlider(wbState.frequency)))

			updatingFromCode = false
		end

		setSummary("WEATHER", "#38bdf8",
			"", (wbState.mode or "place"):upper(),
			"R ", tostring(wbState.radius or 0),
			"Count ", tostring(wbState.spawnCount or 1),
			"Freq ", string.format("%.1f", wbState.frequency or 1))

	elseif spActive then
		-- ===== Splat Painter mode: update splat controls =====
		local splatBtn = doc and doc:GetElementById("btn-splat")
		if splatBtn then splatBtn:SetClass("active", true) end
		setActiveClass(widgetState.modeButtons, nil)

		setActiveClass(widgetState.shapeButtons, spState.shape)

		if doc then
			updatingFromCode = true
			local ds = draggingSlider

			-- Splat labels
			local spStrengthLabel = doc:GetElementById("sp-strength-label")
			if spStrengthLabel then spStrengthLabel.inner_rml = string.format("%.2f", spState.strength) end

			local spIntensityLabel = doc:GetElementById("sp-intensity-label")
			if spIntensityLabel then spIntensityLabel.inner_rml = string.format("%.1f", spState.intensity) end

			local spRadiusLabel = doc:GetElementById("sp-radius-label")
			if spRadiusLabel then spRadiusLabel.inner_rml = tostring(spState.radius) end

			local spRotationLabel = doc:GetElementById("sp-rotation-label")
			if spRotationLabel then spRotationLabel.inner_rml = tostring(spState.rotationDeg) end

			local spCurveLabel = doc:GetElementById("sp-curve-label")
			if spCurveLabel then spCurveLabel.inner_rml = string.format("%.1f", spState.curve) end

			-- Splat channel button highlights
			for i = 1, 4 do
				local chBtn = doc:GetElementById("btn-sp-ch" .. i)
				if chBtn then chBtn:SetClass("active", i == spState.channel) end
			end

			-- Splat sliders
			syncAndFlash(doc:GetElementById("sp-slider-strength"), "sp-strength", tostring(math.floor(spState.strength * 100 + 0.5)))
			syncAndFlash(doc:GetElementById("sp-slider-intensity"), "sp-intensity", tostring(math.floor(spState.intensity * 10 + 0.5)))
			syncAndFlash(doc:GetElementById("sp-slider-size"), "sp-size", tostring(spState.radius))
			syncAndFlash(doc:GetElementById("sp-slider-rotation"), "sp-rotation", tostring(spState.rotationDeg))
			syncAndFlash(doc:GetElementById("sp-slider-curve"), "sp-curve", tostring(math.floor(spState.curve * 10 + 0.5)))

			-- Smart filter UI sync
			local spSmartOptions = doc:GetElementById("sp-smart-options")
			if spSmartOptions then
				local isSmart = spState.smartEnabled == true
				spSmartOptions:SetClass("hidden", not isSmart)
				local spSmartToggleBtn = doc:GetElementById("btn-sp-smart-toggle")
				if spSmartToggleBtn then
					spSmartToggleBtn:SetAttribute("src", isSmart
						and "/luaui/images/terraform_brush/check_on.png"
						or  "/luaui/images/terraform_brush/check_off.png")
				end
				if spState.smartFilters then
					local sf = spState.smartFilters

					local avoidWaterBtn = doc:GetElementById("btn-sp-avoid-water")
					if avoidWaterBtn then
						avoidWaterBtn:SetAttribute("src", sf.avoidWater
							and "/luaui/images/terraform_brush/check_on.png"
							or "/luaui/images/terraform_brush/check_off.png")
					end

					local avoidCliffsBtn = doc:GetElementById("btn-sp-avoid-cliffs")
					if avoidCliffsBtn then
						avoidCliffsBtn:SetAttribute("src", sf.avoidCliffs
							and "/luaui/images/terraform_brush/check_on.png"
							or "/luaui/images/terraform_brush/check_off.png")
					end

					local slopeMaxRow = doc:GetElementById("sp-smart-slope-max-row")
					if slopeMaxRow then slopeMaxRow:SetClass("hidden", not sf.avoidCliffs) end
					local slopeMaxSliderRow = doc:GetElementById("sp-smart-slope-max-slider-row")
					if slopeMaxSliderRow then slopeMaxSliderRow:SetClass("hidden", not sf.avoidCliffs) end
					local slopeMaxLabel = doc:GetElementById("sp-smart-slope-max-label")
					if slopeMaxLabel then slopeMaxLabel.inner_rml = tostring(sf.slopeMax) end
					local spSSlopeMax = doc:GetElementById("sp-slider-slope-max")
					if spSSlopeMax and ds ~= "sp-slope-max" then
						spSSlopeMax:SetAttribute("value", tostring(sf.slopeMax))
					end

					local preferSlopesBtn = doc:GetElementById("btn-sp-prefer-slopes")
					if preferSlopesBtn then
						preferSlopesBtn:SetAttribute("src", sf.preferSlopes
							and "/luaui/images/terraform_brush/check_on.png"
							or "/luaui/images/terraform_brush/check_off.png")
					end

					local slopeMinRow = doc:GetElementById("sp-smart-slope-min-row")
					if slopeMinRow then slopeMinRow:SetClass("hidden", not sf.preferSlopes) end
					local slopeMinSliderRow = doc:GetElementById("sp-smart-slope-min-slider-row")
					if slopeMinSliderRow then slopeMinSliderRow:SetClass("hidden", not sf.preferSlopes) end
					local slopeMinLabel = doc:GetElementById("sp-smart-slope-min-label")
					if slopeMinLabel then slopeMinLabel.inner_rml = tostring(sf.slopeMin) end
					local spSSlopeMin = doc:GetElementById("sp-slider-slope-min")
					if spSSlopeMin and ds ~= "sp-slope-min" then
						spSSlopeMin:SetAttribute("value", tostring(sf.slopeMin))
					end

					local altMinEnableBtn = doc:GetElementById("btn-sp-alt-min-enable")
					if altMinEnableBtn then
						altMinEnableBtn:SetAttribute("src", sf.altMinEnable
							and "/luaui/images/terraform_brush/check_on.png"
							or "/luaui/images/terraform_brush/check_off.png")
					end
					local altMinSliderRow = doc:GetElementById("sp-smart-alt-min-slider-row")
					if altMinSliderRow then altMinSliderRow:SetClass("hidden", not sf.altMinEnable) end
					local altMinLabel = doc:GetElementById("sp-smart-alt-min-label")
					if altMinLabel then altMinLabel.inner_rml = tostring(sf.altMin) end
					local spSAltMin = doc:GetElementById("sp-slider-alt-min")
					if spSAltMin and ds ~= "sp-alt-min" then
						spSAltMin:SetAttribute("value", tostring(sf.altMin))
					end

					local altMaxEnableBtn = doc:GetElementById("btn-sp-alt-max-enable")
					if altMaxEnableBtn then
						altMaxEnableBtn:SetAttribute("src", sf.altMaxEnable
							and "/luaui/images/terraform_brush/check_on.png"
							or "/luaui/images/terraform_brush/check_off.png")
					end
					local altMaxSliderRow = doc:GetElementById("sp-smart-alt-max-slider-row")
					if altMaxSliderRow then altMaxSliderRow:SetClass("hidden", not sf.altMaxEnable) end
					local altMaxLabel = doc:GetElementById("sp-smart-alt-max-label")
					if altMaxLabel then altMaxLabel.inner_rml = tostring(sf.altMax) end
					local spSAltMax = doc:GetElementById("sp-slider-alt-max")
					if spSAltMax and ds ~= "sp-alt-max" then
						spSAltMax:SetAttribute("value", tostring(sf.altMax))
					end
				end
			end

			-- Export format label
			local spExportFmtLabel = doc:GetElementById("sp-export-format-label")
			if spExportFmtLabel and spState.exportFormat then
				spExportFmtLabel.inner_rml = string.upper(spState.exportFormat)
			end

			-- Undo/redo history slider sync
			do
				local undoCount = spState.undoCount or 0
				local redoCount = spState.redoCount or 0
				local total = undoCount + redoCount
				local spHistSlider = doc:GetElementById("slider-sp-history")
				if spHistSlider and ds ~= "sp-history" then
					spHistSlider:SetAttribute("max", tostring(total))
					spHistSlider:SetAttribute("value", tostring(undoCount))
				end
				local spHistNumbox = doc:GetElementById("slider-sp-history-numbox")
				if spHistNumbox then
					spHistNumbox.inner_rml = tostring(undoCount)
				end
			end

			-- Decal Exporter stats sync (throttled — every ~1 second)
			do if WG.DecalExporter and (Spring.GetGameFrame() % 30 == 0) then
				local dcGl4 = doc:GetElementById("dc-gl4-count")
				local dcEng = doc:GetElementById("dc-engine-count")
				local dcHeat = doc:GetElementById("dc-heat-count")
				local dcHeatExp = doc:GetElementById("dc-heat-explosions")
				local gl4n = 0
				local decalsApi = WG['decalsgl4']
				if decalsApi and decalsApi.GetActiveDecals then
					local ad = decalsApi.GetActiveDecals()
					if ad then for _ in pairs(ad) do gl4n = gl4n + 1 end end
				end
				local engn = 0
				if Spring.GetAllGroundDecals then
					local ids = Spring.GetAllGroundDecals()
					if ids then engn = #ids end
				end
				if dcGl4 then dcGl4.inner_rml = tostring(gl4n) end
				if dcEng then dcEng.inner_rml = tostring(engn) end
				local _, _, _, hm = WG.DecalExporter.getHeatGrid()
				if dcHeat then dcHeat.inner_rml = string.format("%.0f", hm or 0) end
				if dcHeatExp then dcHeatExp.inner_rml = tostring(WG.DecalExporter.getTotalExplosions()) end
			end end

			updatingFromCode = false
		end

		-- Gray out unsupported shapes in splat mode (no ring)
		for shape, element in pairs(widgetState.shapeButtons) do
			if element and shape ~= "ring" then
				element:SetClass("disabled", false)
			end
		end

		do
			local toolLabel = "SPLAT"
			setSummary(toolLabel, "#22c55e",
				"CH ", tostring(spState.channel or "?"),
				"", shapeNames[spState.shape] or "Circle",
				"R ", tostring(spState.radius or 0),
				"Str ", string.format("%.2f", spState.strength or 0),
				"Int ", string.format("%.1f", spState.intensity or 0))
		end

	elseif fpActive then
		-- ===== Feature Placer mode: update feature controls =====
		local featuresBtn = doc and doc:GetElementById("btn-features")
		if featuresBtn then
			featuresBtn:SetClass("active", true)
		end
		-- Clear terraform mode highlights
		setActiveClass(widgetState.modeButtons, nil)

		-- Feature sub-mode buttons
		setActiveClass(widgetState.fpSubModeButtons, fpState.mode)

		-- Feature distribution buttons
		setActiveClass(widgetState.fpDistButtons, fpState.distribution)

		-- Feature shape buttons
		setActiveClass(widgetState.shapeButtons, fpState.shape)

		if doc then
			updatingFromCode = true
			local ds = draggingSlider

			-- Feature labels
			local fpRadiusLabel = doc:GetElementById("fp-radius-label")
			if fpRadiusLabel then fpRadiusLabel.inner_rml = tostring(fpState.radius) end

			local fpRotationLabel = doc:GetElementById("fp-rotation-label")
			if fpRotationLabel then fpRotationLabel.inner_rml = tostring(fpState.rotation) end

			local fpRotRandomLabel = doc:GetElementById("fp-rot-random-label")
			if fpRotRandomLabel then fpRotRandomLabel.inner_rml = tostring(fpState.rotRandom) end

			local fpCountLabel = doc:GetElementById("fp-count-label")
			if fpCountLabel then fpCountLabel.inner_rml = tostring(fpState.featureCount) end

			local fpCadenceLabel = doc:GetElementById("fp-cadence-label")
			if fpCadenceLabel then fpCadenceLabel.inner_rml = tostring(fpState.cadence) end

			-- Feature sliders
			syncAndFlash(doc:GetElementById("fp-slider-size"), "fp-size", tostring(fpState.radius))
			syncAndFlash(doc:GetElementById("fp-slider-rotation"), "fp-rotation", tostring(fpState.rotation))
			syncAndFlash(doc:GetElementById("fp-slider-rot-random"), "fp-rot-random", tostring(fpState.rotRandom))
			syncAndFlash(doc:GetElementById("fp-slider-count"), "fp-count", tostring(fpState.featureCount))
			syncAndFlash(doc:GetElementById("fp-slider-cadence"), "fp-cadence", tostring(cadenceToSlider(fpState.cadence)))

			-- Smart filter UI sync
			local fpSmartToggle = doc:GetElementById("btn-fp-smart-toggle")
			if fpSmartToggle then
				fpSmartToggle:SetAttribute("src", fpState.smartEnabled
					and "/luaui/images/terraform_brush/check_on.png"
					or "/luaui/images/terraform_brush/check_off.png")
			end
			if fpState.smartFilters then
				local sf = fpState.smartFilters

				local avoidWaterBtn = doc:GetElementById("btn-fp-avoid-water")
				if avoidWaterBtn then
					avoidWaterBtn:SetAttribute("src", sf.avoidWater
						and "/luaui/images/terraform_brush/check_on.png"
						or "/luaui/images/terraform_brush/check_off.png")
				end

				local avoidCliffsBtn = doc:GetElementById("btn-fp-avoid-cliffs")
				if avoidCliffsBtn then
					avoidCliffsBtn:SetAttribute("src", sf.avoidCliffs
						and "/luaui/images/terraform_brush/check_on.png"
						or "/luaui/images/terraform_brush/check_off.png")
				end

				local slopeMaxRow = doc:GetElementById("fp-smart-slope-max-row")
				if slopeMaxRow then slopeMaxRow:SetClass("hidden", not sf.avoidCliffs) end
				local slopeMaxSliderRow = doc:GetElementById("fp-smart-slope-max-slider-row")
				if slopeMaxSliderRow then slopeMaxSliderRow:SetClass("hidden", not sf.avoidCliffs) end
				local slopeMaxLabel = doc:GetElementById("fp-smart-slope-max-label")
				if slopeMaxLabel then slopeMaxLabel.inner_rml = tostring(sf.slopeMax) end
				local fpSSlopeMax = doc:GetElementById("fp-slider-slope-max")
				if fpSSlopeMax and ds ~= "fp-slope-max" then
					fpSSlopeMax:SetAttribute("value", tostring(sf.slopeMax))
				end

				local preferSlopesBtn = doc:GetElementById("btn-fp-prefer-slopes")
				if preferSlopesBtn then
					preferSlopesBtn:SetAttribute("src", sf.preferSlopes
						and "/luaui/images/terraform_brush/check_on.png"
						or "/luaui/images/terraform_brush/check_off.png")
				end

				local slopeMinRow = doc:GetElementById("fp-smart-slope-min-row")
				if slopeMinRow then slopeMinRow:SetClass("hidden", not sf.preferSlopes) end
				local slopeMinSliderRow = doc:GetElementById("fp-smart-slope-min-slider-row")
				if slopeMinSliderRow then slopeMinSliderRow:SetClass("hidden", not sf.preferSlopes) end
				local slopeMinLabel = doc:GetElementById("fp-smart-slope-min-label")
				if slopeMinLabel then slopeMinLabel.inner_rml = tostring(sf.slopeMin) end
				local fpSSlopeMin = doc:GetElementById("fp-slider-slope-min")
				if fpSSlopeMin and ds ~= "fp-slope-min" then
					fpSSlopeMin:SetAttribute("value", tostring(sf.slopeMin))
				end

				local altMinEnableBtn = doc:GetElementById("btn-fp-alt-min-enable")
				if altMinEnableBtn then
					altMinEnableBtn:SetAttribute("src", sf.altMinEnable
						and "/luaui/images/terraform_brush/check_on.png"
						or "/luaui/images/terraform_brush/check_off.png")
				end
				local altMinSliderRow = doc:GetElementById("fp-smart-alt-min-slider-row")
				if altMinSliderRow then altMinSliderRow:SetClass("hidden", not sf.altMinEnable) end
				local altMinLabel = doc:GetElementById("fp-smart-alt-min-label")
				if altMinLabel then altMinLabel.inner_rml = tostring(sf.altMin) end
				local fpSAltMin = doc:GetElementById("fp-slider-alt-min")
				if fpSAltMin and ds ~= "fp-alt-min" then
					fpSAltMin:SetAttribute("value", tostring(sf.altMin))
				end

				local altMaxEnableBtn = doc:GetElementById("btn-fp-alt-max-enable")
				if altMaxEnableBtn then
					altMaxEnableBtn:SetAttribute("src", sf.altMaxEnable
						and "/luaui/images/terraform_brush/check_on.png"
						or "/luaui/images/terraform_brush/check_off.png")
				end
				local altMaxSliderRow = doc:GetElementById("fp-smart-alt-max-slider-row")
				if altMaxSliderRow then altMaxSliderRow:SetClass("hidden", not sf.altMaxEnable) end
				local altMaxLabel = doc:GetElementById("fp-smart-alt-max-label")
				if altMaxLabel then altMaxLabel.inner_rml = tostring(sf.altMax) end
				local fpSAltMax = doc:GetElementById("fp-slider-alt-max")
				if fpSAltMax and ds ~= "fp-alt-max" then
					fpSAltMax:SetAttribute("value", tostring(sf.altMax))
				end
			end

			-- Grid overlay / snap chip sync
			local fpGridOverlayBtn = doc:GetElementById("btn-fp-grid-overlay")
			if fpGridOverlayBtn then
				fpGridOverlayBtn:SetClass("active", fpState.gridOverlay == true)
			end
			local fpGridSnapBtn = doc:GetElementById("btn-fp-grid-snap")
			if fpGridSnapBtn then
				fpGridSnapBtn:SetClass("active", fpState.gridSnap == true)
			end

			-- Display overlay sync (shared TerraformBrush state)
			if WG.TerraformBrush then
				local tbState = WG.TerraformBrush.getState()
				if tbState then
					local fpGridDisp = doc:GetElementById("btn-fp-grid-overlay-display")
					if fpGridDisp then fpGridDisp:SetClass("active", tbState.gridOverlay == true) end
					local fpHMap = doc:GetElementById("btn-fp-height-colormap")
					if fpHMap then fpHMap:SetClass("active", tbState.heightColormap == true) end
					local fpMeas = doc:GetElementById("btn-fp-measure")
					if fpMeas then fpMeas:SetClass("active", tbState.measureActive == true) end
					local fpSym = doc:GetElementById("btn-fp-symmetry")
					if fpSym then fpSym:SetClass("active", tbState.symmetryActive == true) end
					-- fp-symmetry sub-toolbar sync
					local fpSymRow2 = doc:GetElementById("fp-symmetry-toolbar-row")
					if fpSymRow2 then fpSymRow2:SetClass("hidden", not tbState.symmetryActive) end
					local fpSymRadial = doc:GetElementById("fp-btn-symmetry-radial")
					if fpSymRadial then fpSymRadial:SetClass("active", tbState.symmetryRadial == true) end
					local fpSymMX = doc:GetElementById("fp-btn-symmetry-mirror-x")
					if fpSymMX then fpSymMX:SetClass("active", tbState.symmetryMirrorX == true) end
					local fpSymMY = doc:GetElementById("fp-btn-symmetry-mirror-y")
					if fpSymMY then fpSymMY:SetClass("active", tbState.symmetryMirrorY == true) end
					local fpSymFlip = doc:GetElementById("fp-btn-symmetry-flipped")
					if fpSymFlip then fpSymFlip:SetClass("active", tbState.symmetryFlipped == true) end
					local fpSymRadRow = doc:GetElementById("fp-symmetry-radial-count-row")
					if fpSymRadRow then fpSymRadRow:SetClass("hidden", not tbState.symmetryRadial) end
					local fpSymRadLabel = doc:GetElementById("fp-symmetry-radial-count-label")
					if fpSymRadLabel then fpSymRadLabel.inner_rml = tostring(tbState.symmetryRadialCount or 2) end
					local fpSymRadSlider = doc:GetElementById("fp-slider-symmetry-radial-count")
					if fpSymRadSlider then fpSymRadSlider:SetAttribute("value", tostring(tbState.symmetryRadialCount or 2)) end
					local fpHasAxial = tbState.symmetryMirrorX or tbState.symmetryMirrorY
					local fpSymAngRow = doc:GetElementById("fp-symmetry-mirror-angle-row")
					if fpSymAngRow then fpSymAngRow:SetClass("hidden", not fpHasAxial) end
					local fpSymAngLabel = doc:GetElementById("fp-symmetry-mirror-angle-label")
					if fpSymAngLabel then fpSymAngLabel.inner_rml = tostring(math.floor(tbState.symmetryMirrorAngle or 0)) end
					local fpSymAngSlider = doc:GetElementById("fp-slider-symmetry-mirror-angle")
					if fpSymAngSlider then fpSymAngSlider:SetAttribute("value", tostring(tbState.symmetryMirrorAngle or 0)) end
				end
			end

			-- Feature history slider sync
			local sliderFpHist = doc:GetElementById("slider-fp-history")
			if sliderFpHist and ds ~= "fp-history" then
				local totalSteps = (fpState.undoCount or 0) + (fpState.redoCount or 0)
				local maxVal = math.min(totalSteps, 400)
				if maxVal < 1 then maxVal = 1 end
				sliderFpHist:SetAttribute("max", tostring(maxVal))
				sliderFpHist:SetAttribute("value", tostring(fpState.undoCount or 0))
			end
			local fpHistNumbox = doc:GetElementById("slider-fp-history-numbox")
			if fpHistNumbox then
				fpHistNumbox:SetAttribute("value", tostring(fpState.undoCount or 0))
			end

			updatingFromCode = false
		end

		-- Gray out unsupported shapes in feature mode (no ring, no fill)
		for shape, element in pairs(widgetState.shapeButtons) do
			if element and shape ~= "ring" and shape ~= "fill" then
				element:SetClass("disabled", false)
			end
		end

		setSummary("FEATURES", "#34d399",
			"", (fpState.mode or "place"):upper(),
			"", shapeNames[fpState.shape] or "Circle",
			"R ", tostring(fpState.radius or 0),
			"Count ", tostring(fpState.featureCount or 1))

	elseif envActive then
		-- ===== Environment mode: highlight button, clear other highlights =====
		local envBtnU = doc and doc:GetElementById("btn-environment")
		if envBtnU then envBtnU:SetClass("active", true) end
		setActiveClass(widgetState.modeButtons, nil)

		setSummary("ENVIRONMENT", "#9ca3af")

	elseif lpActive then
		-- ===== Light Placer mode: highlight button, clear others, sync controls =====
		local lightsBtnU = doc and doc:GetElementById("btn-lights")
		if lightsBtnU then lightsBtnU:SetClass("active", true) end
		setActiveClass(widgetState.modeButtons, nil)

		-- Update light type buttons
		for lt, el in pairs(widgetState.lightTypeButtons) do
			el:SetClass("active", lt == lpState.lightType)
		end
		-- Update placement mode buttons
		for mode, el in pairs(widgetState.lightModeButtons) do
			el:SetClass("active", mode == lpState.mode)
		end
		-- Show/hide direction section for cone/beam
		local dirSection = doc and doc:GetElementById("lp-direction-section")
		if dirSection then dirSection:SetClass("hidden", lpState.lightType == "point") end
		local thetaSection = doc and doc:GetElementById("lp-theta-section")
		if thetaSection then thetaSection:SetClass("hidden", lpState.lightType ~= "cone") end
		local beamSection = doc and doc:GetElementById("lp-beam-section")
		if beamSection then beamSection:SetClass("hidden", lpState.lightType ~= "beam") end
		-- Show/hide scatter section
		local scatterSection = doc and doc:GetElementById("lp-scatter-section")
		if scatterSection then scatterSection:SetClass("hidden", lpState.mode ~= "scatter") end
		-- Show/hide distribution section (only visible for scatter)
		local distSection = doc and doc:GetElementById("lp-distribution-section")
		if distSection then distSection:SetClass("hidden", lpState.mode ~= "scatter") end
		-- Update distribution buttons
		for dist, el in pairs(widgetState.lightDistButtons) do
			el:SetClass("active", dist == lpState.distribution)
		end
		-- Update labels
		local brightnessLabel = doc and doc:GetElementById("lp-brightness-label")
		if brightnessLabel then brightnessLabel.inner_rml = string.format("%.1f", lpState.brightness) end
		local lightRadLabel = doc and doc:GetElementById("lp-light-radius-label")
		if lightRadLabel then lightRadLabel.inner_rml = tostring(math.floor(lpState.lightRadius)) end
		local elevLabel = doc and doc:GetElementById("lp-elevation-label")
		if elevLabel then elevLabel.inner_rml = tostring(math.floor(lpState.elevation)) end
		local countLabel = doc and doc:GetElementById("lp-count-label")
		if countLabel then countLabel.inner_rml = tostring(lpState.lightCount) end
		local brushRadLabel = doc and doc:GetElementById("lp-brush-radius-label")
		if brushRadLabel then brushRadLabel.inner_rml = tostring(math.floor(lpState.radius)) end
		-- Update color labels and preview
		local rLabel = doc and doc:GetElementById("lp-color-r-label")
		if rLabel then rLabel.inner_rml = string.format("%.2f", lpState.color[1]) end
		local gLabel = doc and doc:GetElementById("lp-color-g-label")
		if gLabel then gLabel.inner_rml = string.format("%.2f", lpState.color[2]) end
		local bLabel = doc and doc:GetElementById("lp-color-b-label")
		if bLabel then bLabel.inner_rml = string.format("%.2f", lpState.color[3]) end
		local colorPreview = doc and doc:GetElementById("lp-color-preview")
		if colorPreview then
			local cr = math.floor(lpState.color[1] * 255)
			local cg = math.floor(lpState.color[2] * 255)
			local cb = math.floor(lpState.color[3] * 255)
			colorPreview:SetAttribute("style", string.format("background-color: #%02x%02x%02x;", cr, cg, cb))
		end
		-- Material labels
		local mfLabel = doc and doc:GetElementById("lp-modelfactor-label")
		if mfLabel then mfLabel.inner_rml = string.format("%.2f", lpState.modelfactor) end
		local spLabel = doc and doc:GetElementById("lp-specular-label")
		if spLabel then spLabel.inner_rml = string.format("%.2f", lpState.specular) end
		local scLabel = doc and doc:GetElementById("lp-scattering-label")
		if scLabel then scLabel.inner_rml = string.format("%.2f", lpState.scattering) end
		local lfLabel = doc and doc:GetElementById("lp-lensflare-label")
		if lfLabel then lfLabel.inner_rml = string.format("%.2f", lpState.lensflare) end
		-- Direction labels
		local pitchLabel = doc and doc:GetElementById("lp-pitch-label")
		if pitchLabel then pitchLabel.inner_rml = tostring(math.floor(lpState.pitch)) end
		local yawLabel = doc and doc:GetElementById("lp-yaw-label")
		if yawLabel then yawLabel.inner_rml = tostring(math.floor(lpState.yaw)) end
		local rollLabel = doc and doc:GetElementById("lp-roll-label")
		if rollLabel then rollLabel.inner_rml = tostring(math.floor(lpState.roll)) end
		local thetaLabel = doc and doc:GetElementById("lp-theta-label")
		if thetaLabel then thetaLabel.inner_rml = string.format("%.2f", lpState.theta) end
		local beamLenLabel = doc and doc:GetElementById("lp-beam-length-label")
		if beamLenLabel then beamLenLabel.inner_rml = tostring(math.floor(lpState.beamLength)) end
		-- Placed count
		local placedEl = doc and doc:GetElementById("lp-placed-count")
		if placedEl and WG.LightPlacer then
			placedEl.inner_rml = tostring(WG.LightPlacer.getPlacedCount())
		end
		-- Smart filter toggle icon
		local smartToggle = doc and doc:GetElementById("btn-lp-smart-toggle")
		if smartToggle then
			smartToggle:SetAttribute("src", lpState.smartEnabled
				and "/luaui/images/terraform_brush/check_on.png"
				or "/luaui/images/terraform_brush/check_off.png")
		end
		local smartDetails = doc and doc:GetElementById("lp-smart-details")
		if smartDetails then smartDetails:SetClass("hidden", not lpState.smartEnabled) end

		-- Light history slider sync
		local sliderLpHist = doc and doc:GetElementById("slider-lp-history")
		if sliderLpHist and draggingSlider ~= "lp-history" then
			updatingFromCode = true
			local totalSteps = (lpState.undoCount or 0) + (lpState.redoCount or 0)
			local maxVal = math.min(totalSteps, 400)
			if maxVal < 1 then maxVal = 1 end
			sliderLpHist:SetAttribute("max", tostring(maxVal))
			sliderLpHist:SetAttribute("value", tostring(lpState.undoCount or 0))
			updatingFromCode = false
		end

		setSummary("LIGHTS", "#fbbf24",
			"", (lpState.lightType or "point"):upper(),
			"Bright ", string.format("%.1f", lpState.brightness or 1),
			"Rad ", tostring(lpState.lightRadius or 200),
			"Elev ", tostring(lpState.elevation or 100))

	elseif stpActive then
		-- ===== Start Positions mode: highlight button, sync controls =====
		local stpBtnU = doc and doc:GetElementById("btn-startpos")
		if stpBtnU then stpBtnU:SetClass("active", true) end
		setActiveClass(widgetState.modeButtons, nil)

		-- Sub-mode buttons
		setActiveClass(widgetState.stpSubModeButtons, stpState.subMode)

		-- Shape buttons
		setActiveClass(widgetState.stpShapeButtons, stpState.shapeType)

		-- Show/hide shape options and shape row (only in shape mode)
		local isShapeMode = stpState.subMode == "shape"
		if widgetState.stpShapeOptionsEl then
			widgetState.stpShapeOptionsEl:SetClass("hidden", not isShapeMode)
		end
		if widgetState.stpShapeRowEl then
			widgetState.stpShapeRowEl:SetClass("hidden", not isShapeMode)
		end

		-- Show/hide hint text based on sub-mode
		if widgetState.stpExpressHintEl then
			widgetState.stpExpressHintEl:SetClass("hidden", stpState.subMode ~= "express")
		end
		if widgetState.stpStartboxHintEl then
			widgetState.stpStartboxHintEl:SetClass("hidden", stpState.subMode ~= "startbox")
		end

		-- Update labels
		local allyLabel = doc and doc:GetElementById("sp-allyteams-label")
		if allyLabel then allyLabel.inner_rml = tostring(stpState.numAllyTeams) end
		local countLabel = doc and doc:GetElementById("sp-count-label")
		if countLabel then countLabel.inner_rml = tostring(stpState.shapeCount) end
		local sizeLabel = doc and doc:GetElementById("sp-size-label")
		if sizeLabel then sizeLabel.inner_rml = tostring(math.floor(stpState.shapeRadius)) end
		local rotLabel = doc and doc:GetElementById("sp-rotation-label")
		if rotLabel then rotLabel.inner_rml = tostring(math.floor(stpState.shapeRotation)) .. "\194\176" end

		-- Sync sliders
		local allySlider = doc and doc:GetElementById("slider-sp-allyteams")
		if allySlider then allySlider:SetAttribute("value", tostring(stpState.numAllyTeams)) end
		local countSlider = doc and doc:GetElementById("slider-sp-count")
		if countSlider then countSlider:SetAttribute("value", tostring(stpState.shapeCount)) end
		local sizeSlider = doc and doc:GetElementById("slider-sp-size")
		if sizeSlider then sizeSlider:SetAttribute("value", tostring(math.floor(stpState.shapeRadius))) end
		local rotSlider = doc and doc:GetElementById("slider-sp-rotation")
		if rotSlider then rotSlider:SetAttribute("value", tostring(math.floor(stpState.shapeRotation))) end

		setSummary("START POS", "#9ca3af",
			"", (stpState.subMode or "express"):upper(),
			"Teams ", tostring(stpState.numAllyTeams or 2))

	elseif clActive then
		-- ===== Clone Tool mode: highlight button, sync controls =====
		do
			local clBtnU = doc and doc:GetElementById("btn-clone")
			if clBtnU then clBtnU:SetClass("active", true) end
			setActiveClass(widgetState.modeButtons, nil)

			-- Update status label
			local statusLabel = doc and doc:GetElementById("cl-status-label")
			if statusLabel and clState then
				local statusText = "Select an area to clone"
				if clState.state == "selecting" then
					statusText = "Drawing selection..."
				elseif clState.state == "box_drawn" then
					statusText = "Box drawn \194\183 Ctrl+C to copy"
				elseif clState.state == "copied" then
					statusText = "Copied \194\183 Ctrl+V to paste"
				elseif clState.state == "paste_preview" then
					statusText = "Click to paste \194\183 RMB to cancel"
				end
				statusLabel.inner_rml = statusText
			end

			-- Sync rotation/height sliders
			if doc then
				updatingFromCode = true
				local ds = draggingSlider
				local rotLabel = doc:GetElementById("cl-rotation-label")
				if rotLabel and clState then rotLabel.inner_rml = tostring(math.floor(clState.pasteRotation)) .. "\194\176" end
				local rotSl = doc:GetElementById("slider-cl-rotation")
				if rotSl and ds ~= "cl-rotation" and clState then
					rotSl:SetAttribute("value", tostring(math.floor(clState.pasteRotation)))
				end
				local rotNumbox = doc:GetElementById("slider-cl-rotation-numbox")
				if rotNumbox and ds ~= "cl-rotation" and clState then
					rotNumbox:SetAttribute("value", tostring(math.floor(clState.pasteRotation)))
				end
				local heightLabel = doc:GetElementById("cl-height-label")
				if heightLabel and clState then heightLabel.inner_rml = tostring(math.floor(clState.pasteHeightOffset)) end
				local heightSl = doc:GetElementById("slider-cl-height")
				if heightSl and ds ~= "cl-height" and clState then
					heightSl:SetAttribute("value", tostring(math.floor(clState.pasteHeightOffset)))
				end
				local heightNumbox = doc:GetElementById("slider-cl-height-numbox")
				if heightNumbox and ds ~= "cl-height" and clState then
					heightNumbox:SetAttribute("value", tostring(math.floor(clState.pasteHeightOffset)))
				end

				-- Sync mirror buttons
				local mirXBtn = doc:GetElementById("btn-cl-mirror-x")
				if mirXBtn and clState then mirXBtn:SetClass("active", clState.pasteMirrorX) end
				local mirZBtn = doc:GetElementById("btn-cl-mirror-z")
				if mirZBtn and clState then mirZBtn:SetClass("active", clState.pasteMirrorZ) end

				-- Sync quality buttons
				if clState then
					local tq = clState.terrainQuality or "balanced"
					local qFull = doc:GetElementById("btn-cl-quality-full")
					local qBal  = doc:GetElementById("btn-cl-quality-balanced")
					local qFast = doc:GetElementById("btn-cl-quality-fast")
					if qFull then qFull:SetClass("active", tq == "full") end
					if qBal  then qBal:SetClass("active", tq == "balanced") end
					if qFast then qFast:SetClass("active", tq == "fast") end
				end

				-- Sync history slider
				local sliderClHist = doc:GetElementById("slider-cl-history")
				if sliderClHist and ds ~= "cl-history" and clState then
					local totalSteps = (clState.undoCount or 0) + (clState.redoCount or 0)
					local maxVal = math.min(totalSteps, 400)
					if maxVal < 1 then maxVal = 1 end
					sliderClHist:SetAttribute("max", tostring(maxVal))
					sliderClHist:SetAttribute("value", tostring(clState.undoCount or 0))
				end

				updatingFromCode = false
			end
		end

		do
			local cs = clState and clState.state or "idle"
			local stateLabels = { idle = "IDLE", selecting = "SELECTING", box_drawn = "BOX DRAWN", copied = "COPIED", paste_preview = "PASTE" }
			setSummary("CLONE", "#22d3ee",
				"", stateLabels[cs] or cs:upper(),
				"Rot ", tostring(math.floor(clState and clState.pasteRotation or 0)) .. "\194\176",
				"Quality ", (clState and clState.terrainQuality or "balanced"):upper())
		end

	elseif decalsActive then
		-- ===== Decals mode: highlight decals button =====
		local decalsBtnA = doc and doc:GetElementById("btn-decals")
		if decalsBtnA then decalsBtnA:SetClass("active", true) end
		setActiveClass(widgetState.modeButtons, nil)
		local dpState = WG.DecalPlacer and WG.DecalPlacer.getState()
		if dpState then
			setSummary("DECALS", "#e060e0",
				"", (dpState.mode or "idle"):upper(),
				"R ", tostring(dpState.radius or 0),
				"Sel ", tostring(#(dpState.selectedDecals or {})))

			-- Sync brush/option labels & sliders
			local function setLbl(id, txt)
				local e = doc and doc:GetElementById(id)
				if e then e.inner_rml = tostring(txt) end
			end
			local function setSlider(id, val)
				local e = doc and doc:GetElementById(id)
				if e then e:SetAttribute("value", tostring(val)) end
			end
			setLbl("dc-radius-label",   dpState.radius or 0)
			setLbl("dc-rotation-label", math.floor(dpState.rotation or 0))
			setLbl("dc-rotrand-label",  dpState.rotRandom or 0)
			setLbl("dc-count-label",    dpState.decalCount or 0)
			setLbl("dc-cadence-label",  dpState.cadence or 0)
			setLbl("dc-sizemin-label",  dpState.sizeMin or 0)
			setLbl("dc-sizemax-label",  dpState.sizeMax or 0)
			setLbl("dc-alpha-label",    math.floor((dpState.alpha or 0) * 100))
			setSlider("dc-slider-radius",   dpState.radius or 0)
			setSlider("dc-slider-rotation", math.floor(dpState.rotation or 0))
			setSlider("dc-slider-rotrand",  dpState.rotRandom or 0)
			setSlider("dc-slider-count",    dpState.decalCount or 0)
			setSlider("dc-slider-cadence",  dpState.cadence or 0)
			setSlider("dc-slider-sizemin",  dpState.sizeMin or 0)
			setSlider("dc-slider-sizemax",  dpState.sizeMax or 0)
			setSlider("dc-slider-alpha",    math.floor((dpState.alpha or 0) * 100))
			-- Mode row active highlight
			local modes = { scatter = "btn-dc-library-scatter", point = "btn-dc-library-point", remove = "btn-dc-library-remove" }
			for m, id in pairs(modes) do
				local b = doc and doc:GetElementById(id)
				if b then b:SetClass("active", dpState.mode == m) end
			end
			-- Align toggle icon
			local alignBtn = doc and doc:GetElementById("btn-dc-align-toggle")
			if alignBtn then
				alignBtn:SetAttribute("src", dpState.alignToNormal
					and "/luaui/images/terraform_brush/check_on.png"
					or  "/luaui/images/terraform_brush/check_off.png")
			end
			-- DC undo history slider
			local dcUndoCnt = dpState.undoCount or 0
			local slDcHist = doc and doc:GetElementById("slider-dc-history")
			local nbDcHist = doc and doc:GetElementById("slider-dc-history-numbox")
			if slDcHist and draggingSlider ~= "dc-history" then
				local dcMax = math.max(dcUndoCnt, 1)
				slDcHist:SetAttribute("max",   tostring(dcMax))
				slDcHist:SetAttribute("value", tostring(dcUndoCnt))
			end
			if nbDcHist then nbDcHist:SetAttribute("value", tostring(dcUndoCnt)) end
		else
			setSummary("DECALS", "#e060e0", "", "LIBRARY", "", "", "", "")
		end

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
			updatingFromCode = true
			local ds = draggingSlider

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
						updatingFromCode = true
						msSlider:SetAttribute("max", tostring(numSpokes2 - 1))
						msSlider:SetAttribute("value", tostring(spokeIdx))
						updatingFromCode = false
					end
				end
			end

			-- Measure tool state sync
			local measureImg = doc:GetElementById("btn-measure")
			if measureImg then
				measureImg:SetClass("active", state.measureActive == true)
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
				updatingFromCode = false

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

			updatingFromCode = false
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
			updatingFromCode = true
			local ds = draggingSlider

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

			updatingFromCode = false
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
	skyboxLibraryOpen = false
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
