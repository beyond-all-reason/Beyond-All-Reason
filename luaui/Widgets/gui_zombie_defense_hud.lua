function widget:GetInfo()
	return {
		name = "BAR Zombie Defense HUD & Auto-Support Control",
		desc = "Unified Minimap-Congruent FlowUI Vertical C2 Rail + 3D Unit Scanner + Output Resolution Lock + Graphics Debug Workbench",
		author = "BAR Zombie Defense",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 1000,
		enabled = true,
		handler = true,
	}
end

--------------------------------------------------------------------------------
-- Localized Spring & OpenGL APIs (Compact top-level locals: well below Lua 5.1 200 cap)
--------------------------------------------------------------------------------
local spGetGameRulesParam = Spring.GetGameRulesParam
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local spSendLuaRulesMsg = Spring.SendLuaRulesMsg
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitHealth = Spring.GetUnitHealth
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitHeading = Spring.GetUnitHeading
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitViewPosition = Spring.GetUnitViewPosition
local spGetAllUnits = Spring.GetAllUnits
local spGetGroundHeight = Spring.GetGroundHeight
local spTraceScreenRay = Spring.TraceScreenRay
local spGetMouseState = Spring.GetMouseState
local spGetViewGeometry = Spring.GetViewGeometry
local spGetMiniMapGeometry = Spring.GetMiniMapGeometry
local spGetTeamColor = Spring.GetTeamColor
local spValidUnitID = Spring.ValidUnitID
local spGetKeyState = Spring.GetKeyState
local spGetFPS = Spring.GetFPS
local spLoadCmdColorsConfig = Spring.LoadCmdColorsConfig

local glColor = gl.Color
local glRect = gl.Rect
local glText = gl.Text
local glBeginEnd = gl.BeginEnd
local glVertex = gl.Vertex
local glTexCoord = gl.TexCoord
local glTexture = gl.Texture
local glCreateList = gl.CreateList
local glCallList = gl.CallList
local glDeleteList = gl.DeleteList
local glLineWidth = gl.LineWidth
local glPushMatrix = gl.PushMatrix
local glPopMatrix = gl.PopMatrix
local glTranslate = gl.Translate
local glRotate = gl.Rotate
local glScale = gl.Scale
local glMatrixMode = gl.MatrixMode
local glLoadIdentity = gl.LoadIdentity
local glOrtho = gl.Ortho
local glScissor = gl.Scissor
local glDepthTest = gl.DepthTest
local glDepthMask = gl.DepthMask
local glCulling = gl.Culling
local glBlending = gl.Blending
local glClear = gl.Clear
local glBillboard = gl.Billboard

local GL_LINES = GL.LINES
local GL_LINE_LOOP = GL.LINE_LOOP
local GL_TRIANGLES = GL.TRIANGLES
local GL_TRIANGLE_FAN = GL.TRIANGLE_FAN
local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA

-- Provide valid non-zero WG.topbar stub at load time so Minimap & Chat never crash regardless of load order
WG = WG or {}
WG.topbar = WG.topbar or {}
WG.topbar.GetPosition = function()
	local vx, vy = spGetViewGeometry()
	vx, vy = vx or 1920, vy or 1080
	local x1 = math.floor(vx * 0.68)
	local y1 = vy - math.max(28, math.floor(38 * (vy / 1080)))
	return { x1, y1, vx, vy, 1.0, y1 }
end
if not WG.topbar.showingQuit then
	WG.topbar.showingQuit = function() return false end
end

local PREVIEW_MESHES = VFS.Include("luaui/Include/zdef_preview_meshes.lua") or {}
local previewDisplayLists = {}
local okMinimapUtils, MinimapUtils = pcall(VFS.Include, "luaui/Include/minimap_utils.lua")
local getCurrentMiniMapRotationOption = okMinimapUtils and MinimapUtils and MinimapUtils.getCurrentMiniMapRotationOption or nil
local MM_ROTATION = okMinimapUtils and MinimapUtils and MinimapUtils.ROTATION or { DEG_0 = 0, DEG_90 = 1, DEG_180 = 2, DEG_270 = 3 }

-- Precomputed unit circle table (24 segments) for crisp minimap tactical rings
local MM_CIRCLE_SEGS = 24
local MM_COS, MM_SIN = {}, {}
for i = 0, MM_CIRCLE_SEGS do
	local a = (i / MM_CIRCLE_SEGS) * math.pi * 2.0
	MM_COS[i] = math.cos(a)
	MM_SIN[i] = math.sin(a)
end

local LARGE_UNIT_MM_STYLE = {
	zdef_zombie_brute = { radius = 5.2,  fillAlpha = 0.28, borderAlpha = 0.94, borderW = 1.4, innerRing = false },
	zdef_mrap         = { radius = 5.6,  fillAlpha = 0.28, borderAlpha = 0.95, borderW = 1.5, innerRing = false },
	zdef_tank         = { radius = 7.2,  fillAlpha = 0.32, borderAlpha = 0.98, borderW = 1.7, innerRing = false },
	zdef_a10          = { radius = 7.8,  fillAlpha = 0.25, borderAlpha = 0.95, borderW = 1.5, innerRing = true  },
	zdef_fighter      = { radius = 7.8,  fillAlpha = 0.25, borderAlpha = 0.95, borderW = 1.5, innerRing = true  },
	zdef_c130         = { radius = 9.4,  fillAlpha = 0.28, borderAlpha = 0.96, borderW = 1.6, innerRing = true  },
	zdef_hq           = { radius = 11.0, fillAlpha = 0.34, borderAlpha = 1.00, borderW = 1.9, innerRing = true  },
}
local largeUnitDefStyle = {}

-- 3D Portrait Shader
local MODEL_VERT = [[
	#version 150 compatibility
	varying vec3 vNormal;
	varying vec3 vViewPos;
	void main() {
		gl_TexCoord[0] = gl_MultiTexCoord0;
		vNormal = normalize(gl_NormalMatrix * gl_Normal);
		vViewPos = (gl_ModelViewMatrix * gl_Vertex).xyz;
		gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
	}
]]

local MODEL_FRAG = [[
	#version 150 compatibility
	uniform sampler2D tex0;
	uniform vec3 teamCol;
	varying vec3 vNormal;
	varying vec3 vViewPos;

	void main() {
		vec4 t = texture2D(tex0, gl_TexCoord[0].st);
		vec3 albedo = mix(t.rgb, teamCol, t.a * 0.65);
		vec3 n = normalize(vNormal);
		vec3 keyDir = normalize(vec3(0.45, 0.85, 0.55));
		vec3 fillDir = normalize(vec3(-0.60, 0.25, -0.35));
		float ndl = clamp(dot(n, keyDir), 0.0, 1.0);
		float fill = clamp(dot(n, fillDir), 0.0, 1.0);
		float rim = pow(1.0 - clamp(abs(n.z), 0.0, 1.0), 2.2) * 0.28;
		vec3 lit = albedo * (0.46 + 0.54 * ndl + 0.18 * fill) + vec3(0.45, 0.72, 0.95) * rim;
		gl_FragColor = vec4(lit, 1.0);
	}
]]

local PREVIEW_SHOWCASE_ORDER = {
	"zdef_infantry",
	"zdef_mrap",
	"zdef_tank",
	"zdef_a10",
	"zdef_fighter",
	"zdef_c130",
	"zdef_hq",
	"zdef_zombie_walker",
	"zdef_zombie_soldier",
	"zdef_zombie_bloater",
	"zdef_zombie_brute",
}

local UNIT_META = {
	zdef_infantry = {
		title = "AKS-74U RIFLE INFANTRY",
		role = "Bộ binh Trấn giữ & Tuần tra",
		weapon = "AKS-74U 5.45mm (Loạt 3 viên)",
		special = "Laser Xanh lá • Có thể lây nhiễm",
		radius = 10.5, midY = 7.2, pitch = 14,
	},
	zdef_paratrooper = {
		title = "AIRBORNE PARATROOPER",
		role = "Lính dù Phản ứng nhanh",
		weapon = "AKS-74U Dù 5.45mm (Loạt 4 viên)",
		special = "Laser Xanh lá • Sĩ khí cao",
		radius = 10.8, midY = 7.4, pitch = 14,
	},
	zdef_mrap = {
		title = "MRAP 4x4 ARMORED PATROL",
		role = "Xe bọc thép Trinh sát & Hỏa lực",
		weapon = "Đại liên 12.7mm (.50 Cal)",
		special = "Laser Xanh dương • Miễn lây nhiễm",
		radius = 22.0, midY = 8.0, pitch = 16,
	},
	zdef_tank = {
		title = "M1 ABRAMS BATTLE TANK",
		role = "Xe tăng Chủ lực Xung kích",
		weapon = "Pháo 120mm HE nổ lan hất tung",
		special = "Laser Xanh dương • Giáp siêu dày",
		radius = 32.0, midY = 9.0, pitch = 18,
	},
	zdef_hq = {
		title = "MILITARY COMMAND BUNKER",
		role = "Bộ Chỉ huy Hậu cần (15,000 HP)",
		weapon = "Triển khai Bộ binh & Điều phối Không quân",
		special = "Bảo vệ bằng mọi giá — Mất là thua!",
		radius = 58.0, midY = 16.0, pitch = 20,
	},
	zdef_c130 = {
		title = "AC-130 / C-130 GUNSHIP",
		role = "Pháo hạm Tuần tra Trên không",
		weapon = "Lựu pháo 105mm & Chi viện Thiết giáp",
		special = "Laser Đỏ • Quỹ đạo nghiêng cánh 33°",
		radius = 105.0, midY = 18.0, pitch = 22,
	},
	zdef_a10 = {
		title = "A-10 THUNDERBOLT II",
		role = "Cường kích Cày xới Tầm thấp",
		weapon = "Pháo xoay 30mm GAU-8 (14 loạt)",
		special = "Laser Đỏ quét dọc chiến hào",
		radius = 52.0, midY = 10.0, pitch = 22,
	},
	zdef_fighter = {
		title = "F-16V STRIKE FIGHTER",
		role = "Tiêm kích Bổ nhào Phóng tên lửa",
		weapon = "4x AGM + 2x Bom Chùm Napalm",
		special = "Laser Đỏ • Bổ nhào -34° / +38°",
		radius = 46.0, midY = 9.0, pitch = 22,
	},
	zdef_zombie_walker = {
		title = "INFECTED ZOMBIE WALKER",
		role = "Xác sống Bầy đàn (Đi / Chạy)",
		weapon = "Cắn nhiễm độc (52 DMG)",
		special = "Biến bộ binh tử trận thành Zombie",
		radius = 9.8, midY = 6.8, pitch = 14,
	},
	zdef_zombie_soldier = {
		title = "REANIMATED ZOMBIE SOLDIER",
		role = "Chiến binh Lây nhiễm Giáp nhẹ",
		weapon = "Cận chiến Áp sát (68 DMG)",
		special = "Tái sinh từ Bộ binh bị hạ gục",
		radius = 10.2, midY = 7.2, pitch = 14,
	},
	zdef_zombie_bloater = {
		title = "VOLATILE BLOATER ZOMBIE",
		role = "Bom Sinh học Di động",
		weapon = "Đập Axit & Phát nổ khi chết",
		special = "Nổ hất văng các đơn vị xung quanh",
		radius = 10.6, midY = 7.3, pitch = 14,
	},
	zdef_zombie_brute = {
		title = "HEAVY MUTANT BRUTE",
		role = "Khổng lồ Đột biến (3200 HP)",
		weapon = "Cú giáng Siêu nặng (240 DMG)",
		special = "Trọng lượng lớn kháng hất tung",
		radius = 14.5, midY = 10.3, pitch = 14,
	},
}

local PKG_TARGET_META = {
	armor = { name = "VÙNG THẢ THIẾT GIÁP C-130",     radius = 120, r = 0.22, g = 0.65, b = 1.00 },
	a10   = { name = "TUYẾN CÀY XỚI A-10 30MM",       radius = 175, r = 1.00, g = 0.60, b = 0.16 },
	ac130 = { name = "TÂM BỔ NHÀO F-16 AGM & NAPALM", radius = 210, r = 1.00, g = 0.26, b = 0.26 },
}

local SUPPORT_CARDS = {
	{
		id = "zdef_call_armor", key = "1", pkg = "armor",
		title = "THIẾT GIÁP C-130",
		sub = "M1 Tank / MRAP (Tối đa 2 Tank • 3 MRAP)",
		cost = 190, cdMax = 26,
		r = 0.24, g = 0.66, b = 1.00,
	},
	{
		id = "zdef_call_a10", key = "2", pkg = "a10",
		title = "A-10 CÀY XỚI 30MM",
		sub = "Pháo xoay GAU-8 • 14 loạt cày chiến hào",
		cost = 150, cdMax = 12,
		r = 1.00, g = 0.62, b = 0.18,
	},
	{
		id = "zdef_call_ac130", key = "3", pkg = "ac130",
		title = "F-16V BỔ NHÀO",
		sub = "4x Tên lửa AGM + 2x Bom Chùm Napalm",
		cost = 180, cdMax = 16,
		r = 1.00, g = 0.28, b = 0.28,
	},
}

local SCALE_STEPS = {
	{ mult = 0.50, label = "0.5x" },
	{ mult = 0.75, label = "0.75x" },
	{ mult = 1.00, label = "1x" },
	{ mult = 1.25, label = "1.25x" },
	{ mult = 1.50, label = "1.5x" },
	{ mult = 2.00, label = "2x" },
}

local SCREEN_MODES = {
	{ id = "fullscreen", short = "FULL • SCALE", name = "Fullscreen (Scale)" },
	{ id = "borderless", short = "BORDERLESS",   name = "Borderless" },
	{ id = "windowed",   short = "WINDOWED",     name = "Windowed" },
}

local RESOLUTIONS = {
	{ label = "720P",  w = 1280, h = 720 },
	{ label = "900P",  w = 1600, h = 900 },
	{ label = "1080P", w = 1920, h = 1080 },
	{ label = "1440P", w = 2560, h = 1440 },
	{ label = "4K",    w = 3840, h = 2160 },
}

local CAMERA_MODES = {
	{ id = "ta",     mode = 1, cmd = "viewta",     short = "TA",     name = "TA OVERHEAD" },
	{ id = "follow", mode = 1, cmd = "viewta",     short = "THEO",   name = "FOLLOW CAMERA" },
	{ id = "spring", mode = 2, cmd = "viewspring", short = "SPRING", name = "SPRING CAMERA" },
	{ id = "tps",    mode = 0, cmd = "viewfps",    short = "TPS",    name = "3RD-PERSON ORBIT" },
	{ id = "free",   mode = 4, cmd = "viewfree",   short = "FREE",   name = "FREE CAMERA" },
}

--------------------------------------------------------------------------------
-- Live Graphics Debug Registry (16 Instant Visual Layers + Terrain Mode)
--------------------------------------------------------------------------------
local GFX_ITEMS = {
	-- Group 1 (1..8): Mod & Tactical World Graphics
	{ key = "lasers",       label = "Tia Laser GL4",    group = 1, kind = "flag" },
	{ key = "laserRings",   label = "Vòng Khóa Laser",  group = 1, kind = "flag" },
	{ key = "spotOverlays", label = "Vòng Cứ Điểm 3D",  group = 1, kind = "rules", msgPrefix = "zdef_gfx_spots" },
	{ key = "cegFx",        label = "Lửa & Nổ CEG",     group = 1, kind = "rules", msgPrefix = "zdef_gfx_ceg" },
	{ key = "worldBars",    label = "Thanh Máu 3D",     group = 1, kind = "flag" },
	{ key = "selRing",      label = "Vòng Chọn Chân",   group = 1, kind = "widgets", widgets = { "Selected Units GL4" } },
	{ key = "mmOverlay",    label = "Lớp Vẽ Minimap",   group = 1, kind = "flag" },
	{ key = "scanner3D",    label = "Khung Quét 3D",    group = 1, kind = "flag" },
	-- Group 2 (9..16): Engine & BAR Shaders
	{ key = "grass",        label = "Cỏ 3D GL4",        group = 2, kind = "widgets", widgets = { "Map Grass GL4" } },
	{ key = "shadows",      label = "Bóng Đổ Shadow",   group = 2, kind = "shadows" },
	{ key = "bloom",        label = "Phát Sáng Bloom",  group = 2, kind = "widgets", widgets = { "Bloom Shader Deferred" } },
	{ key = "ssao",         label = "Đổ Bóng SSAO",     group = 2, kind = "widgets", widgets = { "SSAO" } },
	{ key = "decals",       label = "Vết Nổ Decals",    group = 2, kind = "widgets", widgets = { "Decals GL4" } },
	{ key = "groundAO",     label = "Bóng Chân AO",     group = 2, kind = "widgets", widgets = { "Ground AO Plates GL4", "Ground AO Plates Features GL4" } },
	{ key = "postFx",       label = "Viền & Méo Nhiệt", group = 2, kind = "widgets", widgets = { "Outline Shader GL4", "Distortion GL4", "Airjets GL4", "Contrast Adaptive Sharpen" } },
	{ key = "guiBlur",      label = "Mờ Kính HUD",      group = 2, kind = "guiblur", widgets = { "GUI Shader" } },
}

local GFX = {
	lasers = true,
	laserRings = true,
	spotOverlays = true,
	cegFx = true,
	worldBars = true,
	selRing = true,
	mmOverlay = true,
	scanner3D = true,
	grass = true,
	shadows = true,
	bloom = true,
	ssao = true,
	decals = true,
	groundAO = true,
	postFx = true,
	guiBlur = true,
	terrainMode = "normal", -- "normal" | "height" | "path"
}
WG.ZDEF_GFX = GFX

--------------------------------------------------------------------------------
-- Consolidated State Tables
--------------------------------------------------------------------------------
local UI = {
	vsx = 1920, vsy = 1080,
	baseW = 1920, baseH = 1080,
	scaleModeIdx = 3, uiScale = 1.0, activeScaleLabel = "1x",
	resFactor = 1.0, effScale = 1.0,
	curScreenModeIdx = 3, curResIdx = 3,
	outputResW = 1920, outputResH = 1080,
	pendingWinRefineFrame = nil,
	pendingBootClampFrame = nil,
	spinAngle = 0.0,
	syncedMinimapIconScale = false,
	targetMinimapIconScale = 2.25,
	forcedStart = false,
	hudCleanTicks = 0,
	currentHoveredUnitID = nil,
	lastHoveredUnitID = nil,
	manualPreviewUnitName = nil,
	showcaseIdx = 1,
	previewYawOffset = 0.0,
	previewPitchOffset = 0.0,
	isDragging3D = false,
	dragLastX = 0, dragLastY = 0,
	pendingTargetPkg = nil,
	dismissedDefeat = false,
	lastGameOverState = 0,
	centeredOnHQ = false,
	-- Unified Vertical Rail State: activeTab = 1 ("CHIẾN DỊCH") | 2 ("HIỂN THỊ & DEBUG")
	activeTab = 1,
	mmL = 0, mmB = 720, mmR = 400, mmT = 1080,
	mmPad = 6, mmCorner = 5, mmMargin = 5,
	mmMin = false, mmMax = false,
	railSig = "",
	blurDlists = {},
	loggedErr = {},
}

local VM = {
	portraitShader = nil,
	uTeamCol = nil,
}

local TPS = {
	curCamIdx = 1,
	followModeActive = false,
	followHeight = 760.0,
	active = false,
	uid = nil,
	yaw = 0.0,
	pitchRx = 1.84,
	zoomMult = 1.0,
	targetZoomMult = 1.0,
	isDragging = false,
	dragLastX = 0,
	dragLastY = 0,
	savedClampPos = 1,
	fov = 52.0,
}

local RECTS = {
	rail        = { x1 = 0, x2 = 400, topY = 720, botY = 6 },
	pCommand    = { x = 0, y = 560, w = 400, h = 152 }, -- Always-visible Top Rail Card (Tabs + Telemetry + 3 Tactical Toggles)
	pSupport    = { x = 0, y = 400, w = 400, h = 148 }, -- Tab 1 Module A: Air Support (3 unified rows)
	pScanner    = { x = 0, y = 228, w = 400, h = 166 }, -- Tab 1 Module B: 3D Unit Inspector
	pWorkbench  = { x = 0, y = 180, w = 400, h = 368 }, -- Tab 2: Unified Display + Output Res + UI Scale + 16 GFX Switches
	tabBtns     = {}, -- [1..2]
	autoBtn     = { x1 = 0, y1 = 0, x2 = 0, y2 = 0 },
	sightBtn    = { x1 = 0, y1 = 0, x2 = 0, y2 = 0 },
	camBtn      = { x1 = 0, y1 = 0, x2 = 0, y2 = 0 },
	cards       = {}, -- [1..3]
	box3D       = { x = 10, y = 240, w = 126, h = 126 },
	scanNavBtns = {}, -- [1]=<, [2]=LIVE, [3]=>
	outResBtns  = {}, -- [1..5]
	outModeBtns = {}, -- [1..3]
	uiScaleBtns = {}, -- [1..6]
	gfxBtns     = {}, -- [1..16]
	presetBtns  = {}, -- [1]=All On, [2]=FPS Min, [3]=Terrain Mode
	restartBtn  = { x1 = 0, y1 = 0, x2 = 0, y2 = 0 },
	spectateBtn = { x1 = 0, y1 = 0, x2 = 0, y2 = 0 },
}

local function S(val)
	return math.floor(val * UI.effScale + 0.5)
end

local function SF(val)
	return val * UI.effScale
end

local function inRect(mx, my, r)
	return r and mx >= r.x1 and mx <= r.x2 and my >= r.y1 and my <= r.y2
end

local function inBox(mx, my, b)
	return b and mx >= b.x and mx <= (b.x + b.w) and my >= b.y and my <= (b.y + b.h)
end

--------------------------------------------------------------------------------
-- Disable ALL Unused BAR RTS Base-Building & Individual Unit Control Widgets
--------------------------------------------------------------------------------
local UNNEEDED_BAR_HUD_WIDGETS = {
	"Top Bar", "Info", "Build menu", "Build Bar", "Grid menu", "Order menu",
	"Ecostats", "Converter Usage", "ReclaimInfo", "Reclaim Field Highlight",
	"Idle Builders", "Unit Idle Builder Icons", "Unit Energy Icons",
	"BuildETA", "Show Builder Queue", "Prospector",
	"AdvPlayersList", "AdvPlayersList Game Info", "AdvPlayersList Mascot", "AdvPlayersList Unit Totals",
	"TeamStats", "Pregame UI", "Pregame UI - Draft Spawn Order", "Pregame Queue",
	"Start Position Suggestions", "Unit Groups", "Commander Name Tags", "Commander Hurt Vignette",
	"Health Bars GL4", "HealthBars", "Geothermalspots", "Metalspots", "Given Units",
	"Tax Buildspeed Debuff", "Picture-in-Picture Minimap", "Picture-in-Picture", "Picture-in-Picture 2",
	"Commands FX", "Show Orders", "CustomFormations2", "Waypoint Dragger",
	"Command Queue Manager", "Command Dance", "Auto Group", "Unit Group Number",
	"Unit Groups - Clear selection on empty", "Set unit type target",
	"Area Command Filter", "Attack no Ally", "DGun no ally", "DGun Stall Assist",
	"Stop means Stop", "State Reverse Toggle", "State Prefs V2", "Share Unit Command",
	"Self-Destruct Icons", "Self-Destruct Unit Pulse", "Unit Fire State Icons",
	"Unit Wait Icons", "Unit Repeat Icons", "NoDuplicateOrders", "Guard Remove",
	"Holdfire Fix", "Context Build", "Area Mex", "Blueprint", "Mouse Buildspacing",
	"Easy Facing", "Quick Build (mex/geo)", "Extractor Snap (mex/geo)",
	"SmartSelect", "Cycle Selected Units", "Commander Selector",
	"Exclude walls from area attacks", "Command Sounds", "Mouse FX",
	"Attack Range GL4", "Defense Range GL4", "Attack AoE", "Blast Radius",
	"Projectile Target AoE", "Cloak Fire State", "Auto Cloak Units",
	"Auto Repair Idle Builders", "Factory Assist Fix", "Factory Quotas",
	"Factory hold position", "Factory Guard Default On", "Transport Factory Guard",
	"Transport Load Indicators", "Preserve Commands", "Load Own Moving",
	"Area unload", "Area Reclaim Enemy", "Smart Area Reclaim", "Clean Builder Queue",
	"ImmobileBuilder", "Idle Constructor Guard After Build", "Builder Priority",
	"Build Split", "Chain Actions", "Bomber Attack Building Ground",
	"BombersDefaultHoldFire", "Set fighters on Fly mode", "Onoff for Hound and trajectory",
	"Limit Build Spacing", "Line-Build Hotkey Ignore", "Persistent Build Spacing",
	"Construction Turrets Range Assist", "Priority Construction Turrets",
	"Nano range on transport", "Unit Finished Sounds", "Attack and Move Notification",
	"Player Status Notifications", "Notifications", "Ally Request Listener",
}

local function hideEngineCommandQueueLines()
	if not spLoadCmdColorsConfig then return end
	spLoadCmdColorsConfig("useQueueIcons 0")
	spLoadCmdColorsConfig("queueIconAlpha 0")
	local cmds = {
		"move", "attack", "fight", "wait", "build", "guard", "stop", "patrol",
		"capture", "repair", "reclaim", "restore", "resurrect", "load", "unload", "deathWatch",
	}
	for i = 1, #cmds do
		spLoadCmdColorsConfig(cmds[i] .. " 0 0 0 0")
	end
end

local function disableUnneededBarHud()
	if widgetHandler and widgetHandler.DisableWidget then
		for i = 1, #UNNEEDED_BAR_HUD_WIDGETS do
			local wname = UNNEEDED_BAR_HUD_WIDGETS[i]
			if not widgetHandler.FindWidget or widgetHandler:FindWidget(wname) then
				pcall(function() widgetHandler:DisableWidget(wname) end)
			end
		end
	end
	Spring.SendCommands("resbar 0", "console 0")
	hideEngineCommandQueueLines()

	if WG and WG.darkenmap and WG.darkenmap.setMapDarkness then
		pcall(WG.darkenmap.setMapDarkness, 0)
	end
	if WG and WG.selectedunits then
		if WG.selectedunits.setSelectionHighlight then pcall(WG.selectedunits.setSelectionHighlight, false) end
		if WG.selectedunits.setMouseoverHighlight then pcall(WG.selectedunits.setMouseoverHighlight, false) end
	end

	Spring.SendCommands(
		"unbind Ctrl+f1",
		"unbind a", "unbind m", "unbind f", "unbind p", "unbind g",
		"unbind s", "unbind w", "unbind d", "unbind e", "unbind r",
		"unbind k", "unbind Ctrl+d",
		"bind Ctrl+f2 viewta",
		"bind Ctrl+f3 viewspring",
		"bind Ctrl+f4 viewrot",
		"bind Ctrl+f5 viewfree",
		"bind tab toggleoverview"
	)
end

--------------------------------------------------------------------------------
-- Graphics Debug Helpers (Widget / Engine / RulesParam Live Switching)
--------------------------------------------------------------------------------
local function isBarWidgetLoaded(wname)
	if not widgetHandler then return true end
	if widgetHandler.FindWidget then
		local ok, found = pcall(function() return widgetHandler:FindWidget(wname) ~= nil end)
		if ok then return found end
	end
	if widgetHandler.orderList and widgetHandler.orderList[wname] ~= nil then
		return (widgetHandler.orderList[wname] or 0) > 0
	end
	return true
end

local function setBarWidgetsEnabled(list, enabled)
	if not widgetHandler or not list then return end
	for i = 1, #list do
		local wname = list[i]
		if enabled then
			if widgetHandler.EnableWidget then pcall(function() widgetHandler:EnableWidget(wname) end) end
		else
			if widgetHandler.DisableWidget then pcall(function() widgetHandler:DisableWidget(wname) end) end
		end
	end
end

local function clearGuiBlurDlists()
	for key, dl in pairs(UI.blurDlists) do
		if WG.FlowUI and WG.FlowUI.guishaderRemoveDlist then
			pcall(WG.FlowUI.guishaderRemoveDlist, dl, key)
		else
			if WG.guishader and WG.guishader.RemoveDlist then pcall(WG.guishader.RemoveDlist, key) end
			if dl and glDeleteList then pcall(glDeleteList, dl) end
		end
		UI.blurDlists[key] = nil
	end
end

local function syncGfxStateFromEngine()
	if Spring.GetConfigInt then
		GFX.shadows = (Spring.GetConfigInt("Shadows", 1) or 1) > 0
	end
	for i = 1, #GFX_ITEMS do
		local item = GFX_ITEMS[i]
		if (item.kind == "widgets" or item.kind == "guiblur") and item.widgets and item.widgets[1] then
			GFX[item.key] = isBarWidgetLoaded(item.widgets[1])
		end
	end
end

local function applyGfxItemState(item, enabled)
	GFX[item.key] = enabled
	if item.kind == "rules" and item.msgPrefix then
		spSendLuaRulesMsg(item.msgPrefix .. (enabled and ":1" or ":0"))
	elseif item.kind == "shadows" then
		Spring.SendCommands(enabled and "shadows 1" or "shadows 0")
	elseif item.kind == "widgets" then
		setBarWidgetsEnabled(item.widgets, enabled)
	elseif item.kind == "guiblur" then
		setBarWidgetsEnabled(item.widgets, enabled)
		clearGuiBlurDlists()
	end
end

local function applyTerrainDebugMode(targetMode)
	GFX.terrainMode = targetMode
	if not Spring.GetMapDrawMode then return end
	local cur = Spring.GetMapDrawMode() or "normal"
	if targetMode == "height" then
		if cur ~= "height" then Spring.SendCommands("showelevation") end
	elseif targetMode == "path" then
		if cur ~= "pathTraversability" then Spring.SendCommands("showpathmap") end
	else
		if cur == "height" then Spring.SendCommands("showelevation")
		elseif cur == "pathTraversability" then Spring.SendCommands("showpathmap")
		elseif cur == "metal" then Spring.SendCommands("showmetalmap") end
	end
end

local function cycleTerrainDebugMode()
	if GFX.terrainMode == "normal" then applyTerrainDebugMode("height")
	elseif GFX.terrainMode == "height" then applyTerrainDebugMode("path")
	else applyTerrainDebugMode("normal") end
end

local function applyGfxPreset(preset)
	if preset == "all_on" then
		for i = 1, #GFX_ITEMS do applyGfxItemState(GFX_ITEMS[i], true) end
		applyTerrainDebugMode("normal")
	elseif preset == "perf" then
		local keepOn = { lasers = true, spotOverlays = true, worldBars = true, selRing = true, mmOverlay = true }
		for i = 1, #GFX_ITEMS do applyGfxItemState(GFX_ITEMS[i], keepOn[GFX_ITEMS[i].key] == true) end
		applyTerrainDebugMode("normal")
	end
end

local function countActiveGfxLayers()
	local n = 0
	for i = 1, #GFX_ITEMS do
		if GFX[GFX_ITEMS[i].key] then n = n + 1 end
	end
	return n, #GFX_ITEMS
end

--------------------------------------------------------------------------------
-- Unified BAR FlowUI Drawing System (Cohesive Monochromatic Slate + Single Accent)
--------------------------------------------------------------------------------
local function drawRoundedRect(x1, y1, x2, y2, r, colBot, colTop, tl, tr, br, bl)
	local rr = WG.FlowUI and WG.FlowUI.Draw and WG.FlowUI.Draw.RectRound
	if rr then
		rr(x1, y1, x2, y2, r, tl or 1, tr or 1, br or 1, bl or 1, colBot, colTop or colBot)
	else
		local c = colTop or colBot
		if c then glColor(c[1], c[2], c[3], c[4]) end
		glRect(x1, y1, x2, y2)
	end
end

local function drawRoundedOutline(x1, y1, x2, y2, r, lineW, col, tl, tr, br, bl)
	local rro = WG.FlowUI and WG.FlowUI.Draw and WG.FlowUI.Draw.RectRoundOutline
	if rro then
		rro(x1, y1, x2, y2, r, lineW, tl or 1, tr or 1, br or 1, bl or 1, col, col)
	else
		glColor(col[1], col[2], col[3], col[4])
		glLineWidth(lineW or 1.0)
		glBeginEnd(GL_LINE_LOOP, function()
			glVertex(x1, y1); glVertex(x2, y1); glVertex(x2, y2); glVertex(x1, y2)
		end)
		glLineWidth(1.0)
	end
end

local function syncPanelBlur(blurKey, x1, y1, x2, y2, r, tl, tr, br, bl)
	if not blurKey or not GFX.guiBlur then return end
	local flow = WG.FlowUI
	if flow and flow.guishaderCheckDlist then
		UI.blurDlists[blurKey] = flow.guishaderCheckDlist(UI.blurDlists[blurKey], blurKey, function()
			drawRoundedRect(x1, y1, x2, y2, r, { 1, 1, 1, 1 }, nil, tl, tr, br, bl)
		end, false)
	elseif WG.guishader and WG.guishader.InsertDlist and glCreateList and not UI.blurDlists[blurKey] then
		local dl = glCreateList(function()
			drawRoundedRect(x1, y1, x2, y2, r, { 1, 1, 1, 1 }, nil, tl, tr, br, bl)
		end)
		UI.blurDlists[blurKey] = dl
		pcall(WG.guishader.InsertDlist, dl, blurKey)
	end
end

-- Exact native BAR FlowUI Element panel matching the Minimap frame pixel-for-pixel
local function drawFlowPanel(x, y, w, h, isAlert, blurKey)
	local x1, y1, x2, y2 = x, y, x + w, y + h
	local flushLeft = (x1 <= 2)
	local tl, bl = flushLeft and 0 or 1, flushLeft and 0 or 1
	local tr, br = 1, 1
	local corner = UI.mmCorner or 5
	local pad = UI.mmPad or 6

	syncPanelBlur(blurKey, x1, y1, x2, y2, corner, tl, tr, br, bl)

	local uiEl = WG.FlowUI and WG.FlowUI.Draw and WG.FlowUI.Draw.Element
	if uiEl then
		local c1 = isAlert and { 0.16, 0.03, 0.04, math.min(0.92, (WG.FlowUI.opacity or 0.72) + 0.12) } or nil
		local c2 = isAlert and { 1.0, 0.25, 0.22, 0.16 } or nil
		uiEl(x1, y1, x2, y2, tl, tr, br, bl, 1, 1, 1, flushLeft and 0 or 1, nil, c1, c2, pad, false, nil)
	else
		local bgB = isAlert and { 0.12, 0.03, 0.04, 0.86 } or { 0.04, 0.05, 0.07, 0.82 }
		local bgT = isAlert and { 0.18, 0.05, 0.06, 0.90 } or { 0.07, 0.09, 0.12, 0.86 }
		drawRoundedRect(x1, y1, x2, y2, corner, bgB, bgT, tl, tr, br, bl)
		drawRoundedOutline(x1, y1, x2, y2, corner, 1.0,
			isAlert and { 0.95, 0.28, 0.24, 0.76 } or { 0.45, 0.56, 0.68, 0.36 }, tl, tr, br, bl)
	end
end

local function drawDivider(x1, x2, y)
	glColor(0.56, 0.70, 0.84, 0.16)
	glLineWidth(1.0)
	glBeginEnd(GL_LINES, function()
		glVertex(x1, y); glVertex(x2, y)
	end)
end

local function drawSleekBar(x, y, w, h, frac, r, g, b, showTicks)
	frac = math.max(0.0, math.min(1.0, frac or 0.0))
	local rad = math.max(2, math.floor(h * 0.38))
	drawRoundedRect(x, y, x + w, y + h, rad, { 0.02, 0.03, 0.05, 0.90 }, { 0.04, 0.06, 0.09, 0.90 })
	if frac > 0.008 then
		local fw = math.max(rad * 2, (w - 2) * frac)
		if fw > w - 2 then fw = w - 2 end
		drawRoundedRect(x + 1, y + 1, x + 1 + fw, y + h - 1, math.max(1, rad - 1),
			{ r * 0.74, g * 0.74, b * 0.74, 0.94 }, { math.min(1, r * 1.12), math.min(1, g * 1.12), math.min(1, b * 1.12), 0.98 })
	end
	if showTicks and w >= 50 then
		glColor(0.02, 0.04, 0.06, 0.50)
		glLineWidth(1.0)
		glBeginEnd(GL_LINES, function()
			for t = 1, 3 do
				local tx = x + w * (t * 0.25)
				glVertex(tx, y + 1); glVertex(tx, y + h - 1)
			end
		end)
	end
	drawRoundedOutline(x, y, x + w, y + h, rad, 1.0, { 0.42, 0.54, 0.66, 0.28 })
end

-- Unified Segmented Control Bar (recessed slate trough + cohesive active segment pill + subtle hairline dividers)
local function drawSegmentedBar(rects, labels, activeIdx, mx, my, accentR, accentG, accentB, fontSz)
	local n = #rects
	if n == 0 then return end
	local r0, rN = rects[1], rects[n]
	local rad = math.max(3, S(3.5))
	local ar, ag, ab = accentR or 0.22, accentG or 0.76, accentB or 0.98

	-- Recessed outer trough
	drawRoundedRect(r0.x1, r0.y1, rN.x2, rN.y2, rad, { 0.025, 0.035, 0.05, 0.88 }, { 0.04, 0.055, 0.08, 0.88 })
	drawRoundedOutline(r0.x1, r0.y1, rN.x2, rN.y2, rad, 1.0, { 0.42, 0.54, 0.68, 0.30 })

	-- Hairline dividers between inactive segments
	glColor(0.48, 0.60, 0.74, 0.20)
	glLineWidth(1.0)
	glBeginEnd(GL_LINES, function()
		for i = 1, n - 1 do
			if i ~= activeIdx and (i + 1) ~= activeIdx then
				local dx = rects[i].x2
				glVertex(dx, r0.y1 + S(3)); glVertex(dx, r0.y2 - S(3))
			end
		end
	end)

	-- Segments
	for i = 1, n do
		local r = rects[i]
		local isAct = (i == activeIdx)
		local hov = mx and my and inRect(mx, my, r)
		if isAct then
			drawRoundedRect(r.x1 + 1, r.y1 + 1, r.x2 - 1, r.y2 - 1, math.max(2, rad - 1),
				{ ar * 0.26, ag * 0.26, ab * 0.26, 0.94 }, { ar * 0.40, ag * 0.40, ab * 0.40, 0.96 })
			-- Crisp 2px luminous bottom indicator
			glColor(ar, ag, ab, 0.96)
			glRect(r.x1 + S(4), r.y1 + 1, r.x2 - S(4), r.y1 + S(2.5))
		elseif hov then
			drawRoundedRect(r.x1 + 1, r.y1 + 1, r.x2 - 1, r.y2 - 1, math.max(2, rad - 1),
				{ 0.14, 0.20, 0.28, 0.70 }, { 0.18, 0.25, 0.34, 0.76 })
		end
		local cx = (r.x1 + r.x2) * 0.5
		local cy = r.y1 + (r.y2 - r.y1) * 0.5 - SF(fontSz) * 0.34
		local col = isAct and "\255\246\252\255" or (hov and "\255\224\236\248" or "\255\165\184\204")
		glText(col .. tostring(labels[i] or ""), cx, cy, SF(fontSz), "co")
	end
end

-- Unified Quick Action Button (clean slate base, subtle keycap badge, crisp status dot + bottom accent bar)
local function drawTacticalQuickBtn(rect, keyTag, title, statusText, active, hovered, accentR, accentG, accentB)
	local x1, y1, x2, y2 = rect.x1, rect.y1, rect.x2, rect.y2
	local rad = math.max(3, S(3.5))
	local ar, ag, ab = accentR or 0.22, accentG or 0.78, accentB or 0.98
	local boost = hovered and 0.07 or 0.0

	local bgB = active and { 0.06 + ar * 0.10 + boost, 0.09 + ag * 0.10 + boost, 0.13 + ab * 0.10 + boost, 0.90 }
		or { 0.045 + boost, 0.06 + boost, 0.085 + boost, 0.84 }
	local bgT = active and { 0.09 + ar * 0.14 + boost, 0.13 + ag * 0.14 + boost, 0.18 + ab * 0.14 + boost, 0.94 }
		or { 0.07 + boost, 0.09 + boost, 0.125 + boost, 0.88 }
	local brd = active and { ar, ag, ab, hovered and 0.90 or 0.55 }
		or { 0.44, 0.56, 0.68, hovered and 0.62 or 0.28 }

	drawRoundedRect(x1, y1, x2, y2, rad, bgB, bgT)
	drawRoundedOutline(x1, y1, x2, y2, rad, 1.0, brd)

	if active then
		glColor(ar, ag, ab, 0.94)
		glRect(x1 + S(4), y1 + 1, x2 - S(4), y1 + S(2.5))
	end

	-- Top micro row: keycap badge on left + status text on right
	local topY = y2 - S(11.5)
	if keyTag then
		glText("\255\140\162\186" .. keyTag, x1 + S(6), topY, SF(6.8), "o")
	end
	local stCol = active and "\255\150\245\210" or "\255\145\160\178"
	glText(stCol .. statusText, x2 - S(6), topY, SF(7.0), "ro")

	-- Main button title centered cleanly below
	local titleCol = active and "\255\244\250\255" or (hovered and "\255\224\236\248" or "\255\186\202\218")
	glText(titleCol .. title, (x1 + x2) * 0.5, y1 + S(5.5), SF(8.0), "co")
end

-- Uniform Debug Switch Tile (clean slate tile + miniature hardware-style slide toggle on the right!)
local function drawGfxSwitchTile(rect, label, isOn, hovered)
	local x1, y1, x2, y2 = rect.x1, rect.y1, rect.x2, rect.y2
	local rad = math.max(2, S(3))
	local hB = hovered and 0.06 or 0.0

	local bgB = { 0.04 + hB, 0.055 + hB, 0.08 + hB, 0.84 }
	local bgT = { 0.065 + hB, 0.085 + hB, 0.12 + hB, 0.88 }
	local brd = isOn and { 0.26, 0.78, 0.96, hovered and 0.72 or 0.34 } or { 0.38, 0.46, 0.56, hovered and 0.58 or 0.22 }

	drawRoundedRect(x1, y1, x2, y2, rad, bgB, bgT)
	drawRoundedOutline(x1, y1, x2, y2, rad, 1.0, brd)

	-- Label on left
	local cy = y1 + (y2 - y1) * 0.5 - SF(7.5) * 0.34
	local txtCol = isOn and "\255\234\244\252" or "\255\138\152\168"
	glText(txtCol .. label, x1 + S(7), cy, SF(7.5), "o")

	-- Miniature cohesive toggle switch capsule on right
	local swW, swH = S(22), S(10)
	local swX2 = x2 - S(5)
	local swX1 = swX2 - swW
	local swY1 = y1 + math.floor(((y2 - y1) - swH) * 0.5)
	local swY2 = swY1 + swH
	local swR = math.max(2, math.floor(swH * 0.45))

	if isOn then
		drawRoundedRect(swX1, swY1, swX2, swY2, swR, { 0.12, 0.58, 0.78, 0.92 }, { 0.18, 0.74, 0.96, 0.96 })
		-- Knob right
		local kSz = swH - 2
		drawRoundedRect(swX2 - kSz - 1, swY1 + 1, swX2 - 1, swY2 - 1, math.max(1, swR - 1), { 0.92, 0.97, 1.0, 1.0 })
	else
		drawRoundedRect(swX1, swY1, swX2, swY2, swR, { 0.10, 0.13, 0.18, 0.94 }, { 0.14, 0.18, 0.24, 0.94 })
		-- Knob left
		local kSz = swH - 2
		drawRoundedRect(swX1 + 1, swY1 + 1, swX1 + 1 + kSz, swY2 - 1, math.max(1, swR - 1), { 0.52, 0.60, 0.70, 0.95 })
	end
end

-- Simple unified action pill (used for Defeat modal & preset strip)
local function drawUniformActionBtn(rect, label, active, hovered, r, g, b, fontSz)
	local x1, y1, x2, y2 = rect.x1, rect.y1, rect.x2, rect.y2
	local rad = math.max(3, S(3.5))
	local hB = hovered and 0.08 or 0.0
	local bgB = active and { r * 0.24 + hB, g * 0.24 + hB, b * 0.24 + hB, 0.90 } or { 0.05 + hB, 0.07 + hB, 0.10 + hB, 0.86 }
	local bgT = active and { r * 0.38 + hB, g * 0.38 + hB, b * 0.38 + hB, 0.95 } or { 0.08 + hB, 0.11 + hB, 0.15 + hB, 0.90 }
	local brd = active and { r, g, b, hovered and 0.96 or 0.70 } or { 0.42, 0.54, 0.68, hovered and 0.76 or 0.34 }
	drawRoundedRect(x1, y1, x2, y2, rad, bgB, bgT)
	drawRoundedOutline(x1, y1, x2, y2, rad, 1.0, brd)
	local cx = (x1 + x2) * 0.5
	local cy = y1 + (y2 - y1) * 0.5 - SF(fontSz) * 0.34
	glText(label, cx, cy, SF(fontSz), "co")
end

--------------------------------------------------------------------------------
-- Camera, Output Resolution Lock & Display Mode Management
--------------------------------------------------------------------------------
local function snapToCleanScale(rawMult)
	local bestIdx, bestDiff = 3, 999
	for i = 1, #SCALE_STEPS do
		local d = math.abs(rawMult - SCALE_STEPS[i].mult)
		if d < bestDiff then bestDiff, bestIdx = d, i end
	end
	return bestIdx, SCALE_STEPS[bestIdx].mult, SCALE_STEPS[bestIdx].label
end

do
	local saved = Spring.GetConfigFloat and Spring.GetConfigFloat("ui_scale", 1.0) or 1.0
	UI.scaleModeIdx, UI.uiScale, UI.activeScaleLabel = snapToCleanScale(saved)
end

local function syncMinimapIconScale()
	if Spring.SetConfigFloat then Spring.SetConfigFloat("MinimapIconScale", UI.targetMinimapIconScale) end
	if WG and WG.minimap and WG.minimap.setBaseIconScale then
		pcall(WG.minimap.setBaseIconScale, UI.targetMinimapIconScale)
		UI.syncedMinimapIconScale = true
	else
		Spring.SendCommands("minimap unitsize " .. tostring(UI.targetMinimapIconScale))
	end
end

local function syncCameraModeIds()
	if Spring.GetCameraNames then
		local names = Spring.GetCameraNames()
		if type(names) == "table" then
			for i = 1, #CAMERA_MODES do
				local cm = CAMERA_MODES[i]
				if names[cm.id] ~= nil then cm.mode = names[cm.id] end
			end
		end
	end
end

local function detectActiveCamIdx()
	if TPS.followModeActive then TPS.curCamIdx = 2; return 2, "THEO" end
	if TPS.active then TPS.curCamIdx = 4; return 4, "TPS" end
	if Spring.GetCameraState then
		local cs = Spring.GetCameraState()
		if cs then
			local cname = cs.name and string.lower(tostring(cs.name)) or ""
			local cmode = cs.mode
			for i = 1, #CAMERA_MODES do
				local cm = CAMERA_MODES[i]
				if cm.id ~= "tps" and cm.id ~= "follow" and (cname == cm.id or (cmode ~= nil and cmode == cm.mode)) then
					TPS.curCamIdx = i
					return i, cm.short
				end
			end
			if cname:find("ov") or cmode == 5 then return TPS.curCamIdx, "OV" end
		end
	end
	return TPS.curCamIdx, CAMERA_MODES[TPS.curCamIdx].short
end

local function resolveTPSFollowTarget()
	local sel = spGetSelectedUnits()
	if sel and #sel > 0 and spValidUnitID(sel[1]) then return sel[1] end
	if TPS.uid and spValidUnitID(TPS.uid) then return TPS.uid end
	if UI.currentHoveredUnitID and spValidUnitID(UI.currentHoveredUnitID) then return UI.currentHoveredUnitID end
	if UI.lastHoveredUnitID and spValidUnitID(UI.lastHoveredUnitID) then return UI.lastHoveredUnitID end
	local allU = spGetAllUnits and spGetAllUnits() or {}
	for i = 1, #allU do
		local uDef = spGetUnitDefID(allU[i])
		local dn = uDef and UnitDefs[uDef] and UnitDefs[uDef].name
		if dn and dn ~= "zdef_hq" then return allU[i] end
	end
	return allU[1]
end

local function applyCameraModeByIndex(idx)
	syncCameraModeIds()
	local nextIdx = ((idx - 1) % #CAMERA_MODES) + 1
	local cm = CAMERA_MODES[nextIdx]

	local exitUX, exitUY, exitUZ = nil, nil, nil
	if TPS.active and cm.id ~= "tps" then
		local prevUID = resolveTPSFollowTarget()
		if prevUID and spValidUnitID(prevUID) and spGetUnitPosition then
			exitUX, exitUY, exitUZ = spGetUnitPosition(prevUID)
		end
		TPS.isDragging = false
		if Spring.SetConfigInt then Spring.SetConfigInt("FPSClampPos", TPS.savedClampPos or 1) end
	end

	TPS.curCamIdx = nextIdx
	TPS.followModeActive = (cm.id == "follow")
	TPS.active = (cm.id == "tps")

	if Spring.SetConfigInt then
		Spring.SetConfigInt("CamMode", cm.mode)
		Spring.SetConfigInt("CamSpringMinZoomDistance", 300)
	end

	if TPS.active then
		if Spring.GetConfigInt then TPS.savedClampPos = Spring.GetConfigInt("FPSClampPos", 1) end
		if Spring.SetConfigInt then Spring.SetConfigInt("FPSClampPos", 0) end
		Spring.SendCommands("viewfps")
		local targetUID = resolveTPSFollowTarget()
		TPS.uid = targetUID
		TPS.pitchRx = 1.84
		TPS.zoomMult = 1.0
		TPS.targetZoomMult = 1.0
		TPS.isDragging = false
		if targetUID and spValidUnitID(targetUID) then
			local dx, dz = 0, 1
			if Spring.GetUnitDirection then
				local udx, _, udz = Spring.GetUnitDirection(targetUID)
				if udx and udz and (udx * udx + udz * udz > 1e-5) then dx, dz = udx, udz end
			elseif spGetUnitHeading then
				local hRad = (spGetUnitHeading(targetUID) / 32768.0) * math.pi
				dx, dz = math.sin(hRad), math.cos(hRad)
			end
			TPS.yaw = math.atan2(dx, -dz)
		end
		return
	end

	Spring.SendCommands(cm.cmd)
	if TPS.followModeActive then return end

	if Spring.GetCameraState and Spring.SetCameraState then
		local cs = Spring.GetCameraState() or {}
		local mx = (Game.mapSizeX or 4096) * 0.5
		local mz = (Game.mapSizeZ or 4096) * 0.5
		local px = exitUX or cs.px or mx
		local pz = exitUZ or cs.pz or mz
		local py = exitUY or (spGetGroundHeight and spGetGroundHeight(px, pz)) or cs.py or 120
		local dist = exitUX and 960 or (cs.dist or cs.height or 1450)
		if cm.id == "spring" then
			Spring.SetCameraState({ name = "spring", mode = cm.mode, px = px, py = py, pz = pz, dist = math.max(350, math.min(5500, dist)), rx = 2.45, ry = cs.ry or 0.0, rz = 0.0 }, 0.25)
		elseif cm.id == "ta" then
			Spring.SetCameraState({ name = "ta", mode = cm.mode, px = px, py = py, pz = pz, height = math.max(350, math.min(5500, dist)), angle = 0.46, flipped = -1 }, 0.25)
		else
			Spring.SetCameraState({ name = cm.id, mode = cm.mode }, 0.25)
		end
	end
end

local function cycleCameraMode(dir)
	detectActiveCamIdx()
	local nextIdx = TPS.curCamIdx + (dir or 1)
	if nextIdx < 1 then nextIdx = #CAMERA_MODES end
	if nextIdx > #CAMERA_MODES then nextIdx = 1 end
	applyCameraModeByIndex(nextIdx)
end

local function detectActiveDisplayIdx()
	local numDisp = (Spring.GetNumDisplays and Spring.GetNumDisplays()) or 1
	local savedDisp = (Spring.GetConfigInt and Spring.GetConfigInt("SelectedDisplay", 1)) or 1
	if Spring.GetWindowGeometry and Spring.GetScreenGeometry then
		local ww, wh, wpx, wpy = Spring.GetWindowGeometry()
		if wpx and wpy then
			local cx, cy = wpx + (ww or 0) * 0.5, wpy + (wh or 0) * 0.5
			for d = 1, numDisp do
				local sx, sy, px, py = Spring.GetScreenGeometry(d - 1)
				if sx and sx > 0 and cx >= px and cx < px + sx and cy >= py and cy < py + sy then
					return d, sx, sy, px or 0, py or 0
				end
			end
		end
	end
	local disp = math.max(1, math.min(numDisp, savedDisp))
	local sx, sy, px, py = 1920, 1080, 0, 0
	if Spring.GetScreenGeometry then
		local gsx, gsy, gpx, gpy = Spring.GetScreenGeometry(disp - 1)
		if gsx and gsx > 0 then sx, sy, px, py = gsx, gsy, gpx or 0, gpy or 0 end
	end
	return disp, sx, sy, px, py
end

local function findNearestResIdx(w, h)
	local bestIdx, bestDiff = 3, 999999
	for i = 1, #RESOLUTIONS do
		local d = math.abs((h or 1080) - RESOLUTIONS[i].h) * 2 + math.abs((w or 1920) - RESOLUTIONS[i].w)
		if d < bestDiff then bestDiff, bestIdx = d, i end
	end
	return bestIdx
end

local function findHardwareVideoMode(dispIdx, targetW, targetH, monW, monH)
	local tw = math.min(targetW, monW)
	local th = math.min(targetH, monH)
	if Platform and Platform.availableVideoModes then
		local bestW, bestH, bestScore = nil, nil, 9999999
		for _, vm in ipairs(Platform.availableVideoModes) do
			if vm.display == dispIdx and vm.w and vm.h and vm.w <= monW and vm.h <= monH then
				if vm.w == tw and vm.h == th then return vm.w, vm.h end
				local overPen = (vm.w > tw or vm.h > th) and 50000 or 0
				local score = overPen + math.abs(vm.w - tw) + math.abs(vm.h - th) * 2
				if score < bestScore then bestScore, bestW, bestH = score, vm.w, vm.h end
			end
		end
		if bestW and bestH then return bestW, bestH end
	end
	return tw, th
end

local function syncScreenAndResFromEngine()
	local fs = Spring.GetConfigInt and Spring.GetConfigInt("Fullscreen", 0) == 1
	local bl = Spring.GetConfigInt and Spring.GetConfigInt("WindowBorderless", 0) == 1
	if fs and not bl then UI.curScreenModeIdx = 1
	elseif bl then UI.curScreenModeIdx = 2
	else UI.curScreenModeIdx = 3 end

	local savedW = Spring.GetConfigInt and Spring.GetConfigInt("ZDefOutputResW", 0) or 0
	local savedH = Spring.GetConfigInt and Spring.GetConfigInt("ZDefOutputResH", 0) or 0
	if savedW >= 1280 and savedH >= 720 then
		UI.curResIdx = findNearestResIdx(savedW, savedH)
	else
		UI.curResIdx = 3 -- Default 1080P (avoids heavy 4K default on 4K displays)
	end
	UI.outputResW = RESOLUTIONS[UI.curResIdx].w
	UI.outputResH = RESOLUTIONS[UI.curResIdx].h
	if Spring.SetConfigInt then
		Spring.SetConfigInt("ZDefOutputResW", UI.outputResW)
		Spring.SetConfigInt("ZDefOutputResH", UI.outputResH)
	end
end

local function applyScreenModeAndResolution(isRefinePass)
	local sm = SCREEN_MODES[UI.curScreenModeIdx] or SCREEN_MODES[3]
	local res = RESOLUTIONS[UI.curResIdx] or RESOLUTIONS[3]
	UI.outputResW, UI.outputResH = res.w, res.h

	local dispIdx, sx, sy, px, py = detectActiveDisplayIdx()
	local tw = math.min(res.w, sx)
	local th = math.min(res.h, sy)

	if Spring.SetConfigInt then
		Spring.SetConfigInt("SelectedDisplay", dispIdx)
		Spring.SetConfigInt("ZDefOutputResW", res.w)
		Spring.SetConfigInt("ZDefOutputResH", res.h)
	end

	if sm.id == "fullscreen" then
		local modeW, modeH = findHardwareVideoMode(dispIdx, tw, th, sx, sy)
		if Spring.SetConfigInt then
			Spring.SetConfigInt("Fullscreen", 1)
			Spring.SetConfigInt("WindowBorderless", 0)
			Spring.SetConfigInt("XResolution", modeW)
			Spring.SetConfigInt("YResolution", modeH)
			Spring.SetConfigInt("XResolutionWindowed", tw)
			Spring.SetConfigInt("YResolutionWindowed", th)
		end
		UI.pendingWinRefineFrame = nil
		if Spring.SetWindowGeometry then
			Spring.SetWindowGeometry(dispIdx, 0, 0, modeW, modeH, true, false)
		else
			Spring.SendCommands("fullscreen 1")
		end
	elseif sm.id == "borderless" then
		local wx = px + math.max(0, math.floor((sx - tw) * 0.5))
		local wy = py + math.max(0, math.floor((sy - th) * 0.5))
		if Spring.SetConfigInt then
			Spring.SetConfigInt("Fullscreen", 0)
			Spring.SetConfigInt("WindowBorderless", 1)
			Spring.SetConfigInt("XResolution", tw)
			Spring.SetConfigInt("YResolution", th)
			Spring.SetConfigInt("XResolutionWindowed", tw)
			Spring.SetConfigInt("YResolutionWindowed", th)
			Spring.SetConfigInt("WindowPosX", wx)
			Spring.SetConfigInt("WindowPosY", wy)
		end
		UI.pendingWinRefineFrame = nil
		if Spring.SetWindowGeometry then
			Spring.SetWindowGeometry(dispIdx, wx, wy, tw, th, false, true)
		else
			Spring.SendCommands("fullscreen 0")
		end
	else
		local bTop, bLeft, bBot, bRight = 32, 8, 8, 8
		if Spring.GetWindowGeometry then
			local _, _, _, _, bt, bl, bb, br = Spring.GetWindowGeometry()
			if bt and bt >= 0 and bl and bl >= 0 then
				bTop, bLeft, bBot, bRight = bt, bl, bb or 0, br or 0
			end
		end
		local maxW = math.max(800, sx - bLeft - bRight)
		local maxH = math.max(600, sy - bTop - bBot - 40)
		local winW = math.min(tw, maxW)
		local winH = math.min(th, maxH)
		local wx = px + math.max(bLeft, math.floor((sx - winW) * 0.5))
		local wy = py + math.max(bTop + 4, math.floor((sy - winH) * 0.5))
		if Spring.SetConfigInt then
			Spring.SetConfigInt("Fullscreen", 0)
			Spring.SetConfigInt("WindowBorderless", 0)
			Spring.SetConfigInt("XResolution", tw)
			Spring.SetConfigInt("YResolution", th)
			Spring.SetConfigInt("XResolutionWindowed", winW)
			Spring.SetConfigInt("YResolutionWindowed", winH)
			Spring.SetConfigInt("WindowPosX", wx)
			Spring.SetConfigInt("WindowPosY", wy)
		end
		if Spring.SetWindowGeometry then
			Spring.SetWindowGeometry(dispIdx, wx, wy, winW, winH, false, false)
			if not isRefinePass and Spring.GetDrawFrame then
				UI.pendingWinRefineFrame = Spring.GetDrawFrame() + 3
			else
				UI.pendingWinRefineFrame = nil
			end
		else
			Spring.SendCommands("fullscreen 0")
		end
	end
end

local function setScreenModeIdx(idx)
	UI.curScreenModeIdx = ((idx - 1) % #SCREEN_MODES) + 1
	applyScreenModeAndResolution(false)
end

local function setOutputResolutionIdx(idx)
	UI.curResIdx = ((idx - 1) % #RESOLUTIONS) + 1
	applyScreenModeAndResolution(false)
end

local function cycleScreenMode(dir)
	setScreenModeIdx(UI.curScreenModeIdx + (dir or 1))
end

local function syncBarFlowUIScale()
	if Spring.SetConfigFloat then Spring.SetConfigFloat("ui_scale", UI.uiScale) end
	if WG and WG.FlowUI then
		WG.FlowUI.scale = UI.uiScale
		if WG.FlowUI.Callin and WG.FlowUI.Callin.ViewResize1 then
			pcall(WG.FlowUI.Callin.ViewResize1, UI.vsx, UI.vsy)
		end
	end
	if widgetHandler and widgetHandler.ViewResize and not widget._inSyncResize then
		widget._inSyncResize = true
		pcall(function()
			for _, w in ipairs(widgetHandler.ViewResizeList or {}) do
				if w ~= widget and w.ViewResize then w:ViewResize(UI.vsx, UI.vsy) end
			end
		end)
		widget._inSyncResize = false
	end
end

--------------------------------------------------------------------------------
-- Live Minimap-Aligned Vertical Rail Layout Engine
--------------------------------------------------------------------------------
local function readLiveMinimapRect()
	local vx, vy = spGetViewGeometry()
	vx, vy = vx or 1920, vy or 1080
	local flow = WG.FlowUI
	local pad = (flow and flow.elementPadding) or 6
	local corner = (flow and flow.elementCorner) or 5
	local margin = (flow and flow.elementMargin) or 5

	if WG.minimap and WG.minimap.getRect then
		local l, b, r, t, p, c, m, mn, mx = WG.minimap.getRect()
		if r and r > l and t and t > b then
			return l, b, r, t, p or pad, c or corner, m or margin, mn == true, mx == true, vx, vy
		end
	end
	if spGetMiniMapGeometry then
		local px, py, sx, sy, mn, mx = spGetMiniMapGeometry()
		if sx and sx > 20 and sy and sy > 20 then
			return px, py - pad, px + sx + pad, py + sy, pad, corner, margin, mn == true, mx == true, vx, vy
		end
	end
	local defW = math.floor(vx * 0.24)
	local defH = math.floor(vy * 0.26)
	return 0, vy - defH - pad, defW + pad, vy, pad, corner, margin, false, false, vx, vy
end

local function buildSegmentedRects(x1, y1, x2, y2, count)
	local out = {}
	local segW = (x2 - x1) / count
	for i = 1, count do
		local sx1 = math.floor(x1 + (i - 1) * segW)
		local sx2 = (i == count) and x2 or math.floor(x1 + i * segW)
		out[i] = { x1 = sx1, y1 = y1, x2 = sx2, y2 = y2 }
	end
	return out
end

local function recomputeLayout()
	local mmL, mmB, mmR, mmT, mmPad, mmCorner, mmMargin, mmMin, mmMax, vx, vy = readLiveMinimapRect()
	UI.vsx, UI.vsy = vx, vy
	UI.mmL, UI.mmB, UI.mmR, UI.mmT = mmL, mmB, mmR, mmT
	UI.mmPad, UI.mmCorner, UI.mmMargin = mmPad, mmCorner, mmMargin
	UI.mmMin, UI.mmMax = mmMin, mmMax
	UI.resFactor = math.max(0.45, math.min(vx / UI.baseW, vy / UI.baseH))
	UI.uiScale = SCALE_STEPS[UI.scaleModeIdx].mult
	UI.activeScaleLabel = SCALE_STEPS[UI.scaleModeIdx].label

	local gap = math.max(4, math.floor(mmMargin))
	local railX1, railX2, railTopY
	if mmMin then
		railX1 = 0
		railX2 = math.floor(math.max(320, math.min(480, vx * 0.24)))
		railTopY = vy - gap
	else
		railX1 = math.floor(mmL)
		local mmW = math.floor(mmR - mmL)
		local minReadableW = math.floor(260 * UI.resFactor)
		railX2 = railX1 + math.max(mmW, minReadableW)
		railTopY = math.floor(mmB) - gap
	end

	local railW = math.max(230, railX2 - railX1)
	local railBotY = gap
	local availH = math.max(200, railTopY - railBotY)

	RECTS.rail.x1 = railX1
	RECTS.rail.x2 = railX2
	RECTS.rail.topY = railTopY
	RECTS.rail.botY = railBotY

	-- Clean 2-Tab vertical height budget (ALWAYS fits comfortably with zero overlap or clipping!)
	local hCmdBase = 148
	local hSupBase = 148
	local hScnBase = 166
	local hWbBase  = 372
	local totalBase = (UI.activeTab == 1) and (hCmdBase + hSupBase + hScnBase) or (hCmdBase + hWbBase)
	local gapCount  = (UI.activeTab == 1) and 2 or 1

	local wScale = math.max(0.58, math.min(1.40, railW / 408.0))
	local hBudget = math.max(140, availH - gap * gapCount)
	UI.effScale = math.max(0.48, math.min(wScale, hBudget / totalBase))

	local inL = railX1 + ((railX1 <= 2) and S(8) or math.max(mmPad, S(8)))
	local inR = railX2 - math.max(mmPad, S(8))
	local inW = math.max(170, inR - inL)

	-- TOP CARD (Always Visible): 2-Tab Switcher + Telemetry + 3 Uniform Tactical Quick Toggles
	local pC = RECTS.pCommand
	pC.x, pC.w, pC.h = railX1, railW, S(hCmdBase)
	pC.y = railTopY - pC.h

	-- Segmented 2-Tab Navigation Bar right at top of Command Card
	RECTS.tabBtns = buildSegmentedRects(inL, pC.y + pC.h - S(28), inR, pC.y + pC.h - S(7), 2)

	-- 3 Uniform Quick Tactical Toggle Buttons along bottom of Command Card
	local qGap = S(5)
	local qY1, qY2 = pC.y + S(8), pC.y + S(38)
	local qW = math.floor((inW - qGap * 2) / 3)
	RECTS.autoBtn  = { x1 = inL,                  y1 = qY1, x2 = inL + qW,            y2 = qY2 }
	RECTS.sightBtn = { x1 = RECTS.autoBtn.x2 + qGap, y1 = qY1, x2 = RECTS.autoBtn.x2 + qGap + qW, y2 = qY2 }
	RECTS.camBtn   = { x1 = RECTS.sightBtn.x2 + qGap, y1 = qY1, x2 = inR,              y2 = qY2 }

	-- TAB 1: COMBAT OPERATIONS (Air Support + 3D Unit Scanner)
	local pS = RECTS.pSupport
	pS.x, pS.w, pS.h = railX1, railW, S(hSupBase)
	pS.y = pC.y - gap - pS.h

	RECTS.cards = {}
	local cGapY = S(5)
	local nCards = #SUPPORT_CARDS
	local supTop = pS.y + pS.h - S(26)
	local supBot = pS.y + S(8)
	local cardH = math.floor((supTop - supBot - cGapY * (nCards - 1)) / nCards)
	for i = 1, nCards do
		local cy2 = supTop - (i - 1) * (cardH + cGapY)
		RECTS.cards[i] = { x1 = inL, y1 = cy2 - cardH, x2 = inR, y2 = cy2 }
	end

	local p3 = RECTS.pScanner
	p3.x, p3.w, p3.h = railX1, railW, S(hScnBase)
	p3.y = pS.y - gap - p3.h

	-- Unified 3-segment mini navigation pill [< | LIVE | >] in Scanner header
	RECTS.scanNavBtns = buildSegmentedRects(inR - S(86), p3.y + p3.h - S(22), inR, p3.y + p3.h - S(6), 3)

	local bodyH = math.max(44, p3.h - S(34))
	local boxSz = math.min(bodyH, math.floor(inW * 0.36))
	RECTS.box3D.x = inL
	RECTS.box3D.y = p3.y + S(8) + math.floor((bodyH - boxSz) * 0.5)
	RECTS.box3D.w = boxSz
	RECTS.box3D.h = boxSz

	-- TAB 2: DISPLAY, OUTPUT RESOLUTION & GRAPHICS DEBUG WORKBENCH
	local pW = RECTS.pWorkbench
	pW.x, pW.w, pW.h = railX1, railW, S(hWbBase)
	pW.y = pC.y - gap - pW.h

	-- Section 1: Output Resolution (5-segment), Display Mode (3-segment), UI Scale (6-segment)
	local rY2 = pW.y + pW.h - S(24)
	local rY1 = rY2 - S(20)
	RECTS.outResBtns = buildSegmentedRects(inL, rY1, inR, rY2, #RESOLUTIONS)

	local mY2 = rY1 - S(4)
	local mY1 = mY2 - S(20)
	RECTS.outModeBtns = buildSegmentedRects(inL, mY1, inR, mY2, #SCREEN_MODES)

	local sY2 = mY1 - S(4)
	local sY1 = sY2 - S(19)
	RECTS.uiScaleBtns = buildSegmentedRects(inL + S(62), sY1, inR, sY2, #SCALE_STEPS)

	-- Section 2 & 3: 16 Uniform Graphics Switch Tiles (2 cols x 8 rows)
	RECTS.gfxBtns = {}
	local gColGap = S(5)
	local gRowGap = S(3)
	local colW = math.floor((inW - gColGap) * 0.5)
	local rowH = S(21)

	local sec1Top = sY1 - S(21)
	for i = 1, 8 do
		local col = (i - 1) % 2
		local row = math.floor((i - 1) / 2)
		local bx1 = inL + col * (colW + gColGap)
		local bx2 = (col == 1) and inR or (bx1 + colW)
		local by2 = sec1Top - row * (rowH + gRowGap)
		RECTS.gfxBtns[i] = { x1 = bx1, y1 = by2 - rowH, x2 = bx2, y2 = by2 }
	end

	local sec2Top = sec1Top - 4 * (rowH + gRowGap) - S(19)
	for i = 9, 16 do
		local idx = i - 8
		local col = (idx - 1) % 2
		local row = math.floor((idx - 1) / 2)
		local bx1 = inL + col * (colW + gColGap)
		local bx2 = (col == 1) and inR or (bx1 + colW)
		local by2 = sec2Top - row * (rowH + gRowGap)
		RECTS.gfxBtns[i] = { x1 = bx1, y1 = by2 - rowH, x2 = bx2, y2 = by2 }
	end

	-- Bottom 3-Segment Preset & Terrain Debug Strip
	RECTS.presetBtns = buildSegmentedRects(inL, pW.y + S(8), inR, pW.y + S(30), 3)

	-- Defeat Overlay Action Buttons
	local ovCx, ovCy = math.floor(vx * 0.5), math.floor(vy * 0.5)
	RECTS.restartBtn  = { x1 = ovCx - S(190), y1 = ovCy - S(108), x2 = ovCx - S(8),   y2 = ovCy - S(72) }
	RECTS.spectateBtn = { x1 = ovCx + S(8),   y1 = ovCy - S(108), x2 = ovCx + S(190), y2 = ovCy - S(72) }

	UI.railSig = string.format("%d:%d:%d:%d:%d:%d:%s:%s:%d",
		math.floor(mmL), math.floor(mmB), math.floor(mmR), math.floor(mmT), vx, vy,
		tostring(mmMin), tostring(mmMax), UI.activeTab)

	clearGuiBlurDlists()
end

local function setScaleModeIdx(idx)
	UI.scaleModeIdx = ((idx - 1) % #SCALE_STEPS) + 1
	recomputeLayout()
	syncBarFlowUIScale()
end

local function cycleScaleMode(dir)
	setScaleModeIdx(UI.scaleModeIdx + (dir or 1))
end

local function switchRailTab(tabIdx)
	if UI.activeTab ~= tabIdx then
		UI.activeTab = tabIdx
		if tabIdx == 2 then syncGfxStateFromEngine() end
		recomputeLayout()
	end
end

local function toggleDebugTab()
	switchRailTab((UI.activeTab == 2) and 1 or 2)
end

--------------------------------------------------------------------------------
-- 3D Preview Display List Cache
--------------------------------------------------------------------------------
local function getOrBuildPreviewDList(uName)
	if previewDisplayLists[uName] then return previewDisplayLists[uName] end
	local mdata = PREVIEW_MESHES[uName] or PREVIEW_MESHES.zdef_infantry
	if not mdata or not mdata.tris then return nil end
	local tris = mdata.tris
	local lx, ly, lz = 0.42, 0.78, 0.46
	local dlist = glCreateList(function()
		glBeginEnd(GL_TRIANGLES, function()
			for i = 1, #tris do
				local t = tris[i]
				local ndl = t[16] * lx + t[17] * ly + t[18] * lz
				if ndl < 0 then ndl = -ndl * 0.35 end
				local shade = math.min(1.18, 0.54 + 0.64 * ndl)
				glColor(shade, shade, shade, 1.0)
				glTexCoord(t[4], t[5]); glVertex(t[1], t[2], t[3])
				glTexCoord(t[9], t[10]); glVertex(t[6], t[7], t[8])
				glTexCoord(t[14], t[15]); glVertex(t[11], t[12], t[13])
			end
		end)
	end)
	previewDisplayLists[uName] = dlist
	return dlist
end

--------------------------------------------------------------------------------
-- Lifecycle Callins
--------------------------------------------------------------------------------
function widget:Initialize()
	WG.topbar = WG.topbar or {}
	WG.topbar.GetPosition = function()
		local vx, vy = spGetViewGeometry()
		vx, vy = vx or UI.vsx or 1920, vy or UI.vsy or 1080
		local x1 = math.floor(vx * 0.68)
		local y1 = vy - math.max(28, math.floor(38 * (vy / 1080)))
		return { x1, y1, vx, vy, 1.0, y1 }
	end
	if not WG.topbar.showingQuit then
		WG.topbar.showingQuit = function() return false end
	end
	WG.ZDEF_GFX = GFX

	syncCameraModeIds()
	applyCameraModeByIndex(1)
	syncScreenAndResFromEngine()
	disableUnneededBarHud()

	-- Anti-4K Boot Guard: never stay stuck at native 4K when Output Resolution is lower (default 1080P)
	local curVx, curVy = spGetViewGeometry()
	if curVx and curVy and (curVx > UI.outputResW + 64 or curVy > UI.outputResH + 64) then
		UI.pendingBootClampFrame = (Spring.GetDrawFrame and Spring.GetDrawFrame() or 0) + 2
	end

	if widgetHandler and widgetHandler.EnableWidget then
		if not widgetHandler.FindWidget or not widgetHandler:FindWidget("Minimap") then
			pcall(function() widgetHandler:EnableWidget("Minimap") end)
		end
		if not widgetHandler.FindWidget or not widgetHandler:FindWidget("BAR Zombie Defense GL4 Tactical Laser Sights") then
			pcall(function() widgetHandler:EnableWidget("BAR Zombie Defense GL4 Tactical Laser Sights") end)
		end
	end
	if gl.SlaveMiniMap then pcall(gl.SlaveMiniMap, true) end
	Spring.SendCommands("minimap minimize 0")

	if gl.CreateShader then
		local okS, sh = pcall(gl.CreateShader, { vertex = MODEL_VERT, fragment = MODEL_FRAG, uniformInt = { tex0 = 0 } })
		if okS and sh then
			VM.portraitShader = sh
			VM.uTeamCol = gl.GetUniformLocation(sh, "teamCol")
		end
	end

	largeUnitDefStyle = {}
	for uDefID, uDef in pairs(UnitDefs or {}) do
		if uDef and uDef.name and LARGE_UNIT_MM_STYLE[uDef.name] then
			largeUnitDefStyle[uDefID] = LARGE_UNIT_MM_STYLE[uDef.name]
		end
	end
	syncGfxStateFromEngine()
	recomputeLayout()
	syncMinimapIconScale()
end

function widget:Shutdown()
	if TPS.active and Spring.SetConfigInt then
		Spring.SetConfigInt("FPSClampPos", TPS.savedClampPos or 1)
	end
	clearGuiBlurDlists()
	if glDeleteList then
		for k, dl in pairs(previewDisplayLists) do
			glDeleteList(dl)
			previewDisplayLists[k] = nil
		end
	end
	if gl.DeleteShader and VM.portraitShader then
		pcall(gl.DeleteShader, VM.portraitShader)
		VM.portraitShader = nil
	end
end

function widget:ViewResize()
	recomputeLayout()
end

-- Client-side authoritative lock: swallow ALL individual unit orders
function widget:CommandNotify(cmdID, cmdParams, cmdOptions)
	return true
end

--------------------------------------------------------------------------------
-- Minimap Tactical Overlay (Strategic Spots S1..SN + HQ + Proportional Unit Circles)
--------------------------------------------------------------------------------
local function drawMinimapCircle(cx, cy, r, cr, cg, cb, fillAlpha, borderAlpha, borderW, innerRing)
	if fillAlpha and fillAlpha > 0.01 then
		glColor(cr, cg, cb, fillAlpha)
		glBeginEnd(GL_TRIANGLE_FAN, function()
			glVertex(cx, cy, 0)
			for i = 0, MM_CIRCLE_SEGS do
				glVertex(cx + MM_COS[i] * r, cy + MM_SIN[i] * r, 0)
			end
		end)
	end
	glLineWidth((borderW or 1.5) + 1.1)
	glColor(0.04, 0.06, 0.09, (borderAlpha or 0.9) * 0.72)
	glBeginEnd(GL_LINE_LOOP, function()
		local rOut = r + 0.55
		for i = 0, MM_CIRCLE_SEGS - 1 do
			glVertex(cx + MM_COS[i] * rOut, cy + MM_SIN[i] * rOut, 0)
		end
	end)
	glLineWidth(borderW or 1.5)
	glColor(cr, cg, cb, borderAlpha or 0.95)
	glBeginEnd(GL_LINE_LOOP, function()
		for i = 0, MM_CIRCLE_SEGS - 1 do
			glVertex(cx + MM_COS[i] * r, cy + MM_SIN[i] * r, 0)
		end
	end)
	if innerRing then
		local rIn = r * 0.52
		glLineWidth(1.0)
		glColor(cr, cg, cb, (borderAlpha or 0.95) * 0.58)
		glBeginEnd(GL_LINE_LOOP, function()
			for i = 0, MM_CIRCLE_SEGS - 1 do
				glVertex(cx + MM_COS[i] * rIn, cy + MM_SIN[i] * rIn, 0)
			end
		end)
	end
end

function widget:DrawInMiniMap(sx, sy)
	if not GFX.mmOverlay then return end
	if not sx or not sy or sx <= 0 or sy <= 0 then return end
	if not UI.syncedMinimapIconScale and WG and WG.minimap and WG.minimap.setBaseIconScale then
		syncMinimapIconScale()
	end

	local mapSizeX = Game.mapSizeX or 4096
	local mapSizeZ = Game.mapSizeZ or 4096
	local rot = getCurrentMiniMapRotationOption and getCurrentMiniMapRotationOption() or MM_ROTATION.DEG_0
	local mmAX, mmBX, mmCX, mmAY, mmBY, mmCY
	if rot == MM_ROTATION.DEG_90 then
		mmAX, mmBX, mmCX, mmAY, mmBY, mmCY = 0, sx / mapSizeZ, 0, sy / mapSizeX, 0, 0
	elseif rot == MM_ROTATION.DEG_180 then
		mmAX, mmBX, mmCX, mmAY, mmBY, mmCY = -sx / mapSizeX, 0, sx, 0, sy / mapSizeZ, 0
	elseif rot == MM_ROTATION.DEG_270 then
		mmAX, mmBX, mmCX, mmAY, mmBY, mmCY = 0, -sx / mapSizeZ, sx, -sy / mapSizeX, 0, sy
	else
		mmAX, mmBX, mmCX, mmAY, mmBY, mmCY = sx / mapSizeX, 0, 0, 0, -sy / mapSizeZ, sy
	end

	local mmScale = math.max(0.65, math.min(1.65, math.min(sx, sy) / 260.0))
	local labelSize = math.max(8.5, math.min(13.0, 9.8 * mmScale))
	local pulse = 0.72 + 0.28 * math.sin(UI.spinAngle * 0.14)

	glPushMatrix()
	glDepthTest(false)
	glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

	local spotCount = spGetGameRulesParam("zdef_spot_count") or 0
	local spotMinimapR = math.max(8.5 * mmScale, 180.0 * math.min(sx / mapSizeX, sy / mapSizeZ))
	for i = 1, spotCount do
		local wsx = spGetGameRulesParam("zdef_spot_x_" .. i)
		local wsz = spGetGameRulesParam("zdef_spot_z_" .. i)
		if wsx and wsz then
			local mx = mmAX * wsx + mmBX * wsz + mmCX
			local my = mmAY * wsx + mmBY * wsz + mmCY
			local owner = spGetGameRulesParam("zdef_spot_owner_" .. i) or 0
			local contested = (spGetGameRulesParam("zdef_spot_contested_" .. i) or 0) == 1
			local cr, cg, cb, fillA, brdA, colTag
			if contested then
				cr, cg, cb, fillA, brdA, colTag = 1.0, 0.56, 0.12, 0.24 * pulse, 0.96, "\255\255\185\75"
			elseif owner == 1 then
				cr, cg, cb, fillA, brdA, colTag = 0.18, 0.82, 1.0, 0.18, 0.90, "\255\145\235\255"
			else
				cr, cg, cb, fillA, brdA, colTag = 0.78, 0.84, 0.90, 0.10, 0.72, "\255\220\228\238"
			end
			drawMinimapCircle(mx, my, spotMinimapR, cr, cg, cb, fillA, brdA, contested and 2.0 or 1.5, false)
			glText(string.format("%sS%d", colTag, i), mx, my - labelSize * 0.34, labelSize, "co")
		end
	end

	local hqID = spGetGameRulesParam("zdef_hq_id")
	local allUnits = spGetAllUnits and spGetAllUnits() or {}
	for i = 1, #allUnits do
		local uid = allUnits[i]
		local uDefID = spGetUnitDefID(uid)
		local style = uDefID and largeUnitDefStyle[uDefID]
		if style then
			local ux, _, uz = spGetUnitPosition(uid)
			if ux and uz then
				local mx = mmAX * ux + mmBX * uz + mmCX
				local my = mmAY * ux + mmBY * uz + mmCY
				local ut = spGetUnitTeam(uid)
				local tr, tg, tb = 0.25, 0.85, 1.0
				if ut and spGetTeamColor then
					local r, g, b = spGetTeamColor(ut)
					if r then
						tr = math.min(1.0, r * 1.15 + 0.08)
						tg = math.min(1.0, g * 1.15 + 0.08)
						tb = math.min(1.0, b * 1.15 + 0.08)
					end
				end
				drawMinimapCircle(mx, my, style.radius * mmScale, tr, tg, tb, style.fillAlpha, style.borderAlpha, style.borderW, style.innerRing)
				if hqID and uid == hqID then
					glText("\255\165\245\255HQ", mx, my + style.radius * mmScale + 2.0, labelSize, "co")
				end
			end
		end
	end

	glLineWidth(1.0)
	glColor(1, 1, 1, 1)
	glPopMatrix()
end

--------------------------------------------------------------------------------
-- 3D World Overlays (Interactive Targeting Reticle + Hovered/Selected Unit Bar)
--------------------------------------------------------------------------------
function widget:DrawWorldPreUnit()
	if not UI.pendingTargetPkg then return end
	local tmeta = PKG_TARGET_META[UI.pendingTargetPkg]
	if not tmeta then return end
	local mx, my = spGetMouseState()
	if not mx or not my then return end
	local _, pos = spTraceScreenRay(mx, my, true)
	if type(pos) == "table" and pos[1] and pos[3] then
		local gx, gy, gz = pos[1], pos[2] or 50, pos[3]
		local pulse = 0.72 + 0.28 * math.sin(UI.spinAngle * 0.16)
		glColor(tmeta.r, tmeta.g, tmeta.b, 0.90 * pulse)
		glLineWidth(2.4)
		if gl.DrawGroundCircle then
			gl.DrawGroundCircle(gx, gy, gz, tmeta.radius, 40)
			gl.DrawGroundCircle(gx, gy, gz, tmeta.radius * 0.45, 24)
		end
		local rCross = tmeta.radius * 0.75
		glBeginEnd(GL_LINES, function()
			glVertex(gx - rCross, gy + 4, gz); glVertex(gx + rCross, gy + 4, gz)
			glVertex(gx, gy + 4, gz - rCross); glVertex(gx, gy + 4, gz + rCross)
		end)
		glLineWidth(1.0)
		glColor(1, 1, 1, 1)
	end
end

local function drawUnit3DHealthBar(uid)
	if not uid or not spValidUnitID(uid) then return end
	local hp, maxHp = spGetUnitHealth(uid)
	if not hp or not maxHp or maxHp <= 0 then return end
	local ux, uy, uz = spGetUnitViewPosition and spGetUnitViewPosition(uid) or spGetUnitPosition(uid)
	if not ux or not uy or not uz then return end

	local uDefID = spGetUnitDefID(uid)
	local uDef = uDefID and UnitDefs[uDefID]
	local hOff = (uDef and uDef.height and math.max(24, uDef.height + 12)) or 28
	local frac = math.max(0.0, math.min(1.0, hp / maxHp))
	local hr = (frac < 0.35) and 0.96 or ((frac < 0.65) and 0.96 or 0.22)
	local hg = (frac < 0.35) and 0.22 or ((frac < 0.65) and 0.78 or 0.92)
	local hb = 0.26

	glPushMatrix()
	glTranslate(ux, uy + hOff, uz)
	if glBillboard then glBillboard() end

	local bw, bh = 18, 3.2
	glColor(0.03, 0.05, 0.08, 0.90)
	glRect(-bw, -bh, bw, bh)
	glColor(hr, hg, hb, 0.96)
	glRect(-bw + 0.8, -bh + 0.8, -bw + 0.8 + (bw * 2 - 1.6) * frac, bh - 0.8)

	local state = spGetUnitRulesParam(uid, "zdef_state")
	local morale = spGetUnitRulesParam(uid, "zdef_morale")
	if state and morale then
		glText(string.format("\255\205\238\255%s • M:%d", state, morale), 0, bh + 3.5, 8.4, "co")
	end
	glPopMatrix()
end

function widget:DrawWorld()
	if not GFX.worldBars then return end
	pcall(function()
		local drawn = {}
		local sel = spGetSelectedUnits()
		if sel and #sel > 0 then
			for i = 1, #sel do
				local uid = sel[i]
				drawn[uid] = true
				drawUnit3DHealthBar(uid)
			end
		end
		if UI.currentHoveredUnitID and not drawn[UI.currentHoveredUnitID] then
			drawUnit3DHealthBar(UI.currentHoveredUnitID)
		end
	end)
	glColor(1, 1, 1, 1)
end

--------------------------------------------------------------------------------
-- Frame Update (Minimap Sync + Anti-4K Guard + LOS Sync + TPS 360° Orbit)
--------------------------------------------------------------------------------
function widget:Update(dt)
	local dtStep = math.min(0.1, dt or 0.016)
	UI.spinAngle = (UI.spinAngle + dtStep * 38.0) % 360.0

	if not UI.forcedStart and Spring.GetGameFrame() < 0 then
		UI.forcedStart = true
		Spring.SendCommands("forcestart")
	end

	if Spring.GetDrawFrame then
		local df = Spring.GetDrawFrame()
		if UI.pendingBootClampFrame and df >= UI.pendingBootClampFrame then
			UI.pendingBootClampFrame = nil
			applyScreenModeAndResolution(false)
		elseif UI.pendingWinRefineFrame and df >= UI.pendingWinRefineFrame then
			UI.pendingWinRefineFrame = nil
			applyScreenModeAndResolution(true)
		end
	end

	if UI.hudCleanTicks < 5 then
		UI.hudCleanTicks = UI.hudCleanTicks + 1
		disableUnneededBarHud()
		if UI.hudCleanTicks == 5 then
			syncGfxStateFromEngine()
			recomputeLayout()
		end
	end

	-- Keep vertical rail synced pixel-for-pixel with Minimap geometry
	local mmL, mmB, mmR, mmT, _, _, _, mmMin, mmMax, vx, vy = readLiveMinimapRect()
	local sig = string.format("%d:%d:%d:%d:%d:%d:%s:%s:%d",
		math.floor(mmL), math.floor(mmB), math.floor(mmR), math.floor(mmT), vx, vy,
		tostring(mmMin), tostring(mmMax), UI.activeTab)
	if sig ~= UI.railSig then
		recomputeLayout()
	end

	-- Sync BAR's LOS terrain overlay ONLY while Terrain Debug mode is "normal"
	if GFX.terrainMode == "normal" and Spring.GetMapDrawMode then
		local sightParam = spGetGameRulesParam("zdef_full_sight")
		if sightParam ~= nil then
			local wantLos = (sightParam == 0)
			local isLos = (Spring.GetMapDrawMode() == "los")
			if isLos ~= wantLos then Spring.SendCommands("togglelos") end
		end
	end

	-- Center TA camera onto HQ at Map's official Start Position once deployed
	if not UI.centeredOnHQ and Spring.GetGameFrame() >= 1 and Spring.SetCameraTarget then
		local hqx = spGetGameRulesParam("zdef_hq_x")
		local hqz = spGetGameRulesParam("zdef_hq_z")
		if hqx and hqz and (hqx > 1 or hqz > 1) then
			UI.centeredOnHQ = true
			local hqy = (spGetGroundHeight and spGetGroundHeight(hqx, hqz)) or 100
			Spring.SetCameraTarget(hqx, hqy, hqz, 0.35)
		end
	end

	local gOver = spGetGameRulesParam("zdef_game_over") or 0
	if gOver ~= UI.lastGameOverState then
		UI.lastGameOverState = gOver
		if gOver == 1 then UI.dismissedDefeat = false end
	end

	UI.currentHoveredUnitID = nil
	local mx, my = spGetMouseState()
	if mx and my then
		local rType, rData = spTraceScreenRay(mx, my)
		if rType == "unit" and rData and spValidUnitID(rData) then
			UI.currentHoveredUnitID = rData
			UI.lastHoveredUnitID = rData
		end
	end

	if (TPS.followModeActive or TPS.active) and Spring.SetCameraState then
		local followUID = resolveTPSFollowTarget()
		if followUID and spValidUnitID(followUID) then
			TPS.uid = followUID
			local ux, uy, uz = spGetUnitViewPosition and spGetUnitViewPosition(followUID, false) or spGetUnitPosition(followUID)
			if ux and uy and uz then
				if TPS.followModeActive then
					Spring.SetCameraState({
						name = "ta", mode = CAMERA_MODES[2].mode or 1,
						px = ux, py = uy, pz = uz,
						height = TPS.followHeight, angle = 0.46, flipped = -1,
					}, 0.08)
				else
					if spGetKeyState then
						if spGetKeyState(97) or spGetKeyState(276) then TPS.yaw = (TPS.yaw - dtStep * 2.1) % (math.pi * 2.0) end
						if spGetKeyState(100) or spGetKeyState(275) then TPS.yaw = (TPS.yaw + dtStep * 2.1) % (math.pi * 2.0) end
						if spGetKeyState(119) or spGetKeyState(273) then TPS.pitchRx = math.min(2.75, TPS.pitchRx + dtStep * 1.4) end
						if spGetKeyState(115) or spGetKeyState(274) then TPS.pitchRx = math.max(1.25, TPS.pitchRx - dtStep * 1.4) end
					end
					TPS.zoomMult = TPS.zoomMult + (TPS.targetZoomMult - TPS.zoomMult) * math.min(1.0, dtStep * 14.0)

					local uDefID = spGetUnitDefID(followUID)
					local uDef = uDefID and UnitDefs[uDefID]
					local dn = uDef and uDef.name or ""
					local isAir = (uDef and uDef.canFly)
					local lookH, baseDist
					if dn == "zdef_c130" then lookH, baseDist = 4.0, 105.0
					elseif isAir then lookH, baseDist = 4.5, 72.0
					elseif dn == "zdef_hq" then lookH, baseDist = 24.0, 135.0
					elseif dn == "zdef_tank" then lookH, baseDist = 14.5, 56.0
					elseif dn == "zdef_mrap" then lookH, baseDist = 12.0, 42.0
					elseif dn == "zdef_zombie_brute" then lookH, baseDist = 14.0, 38.0
					else lookH, baseDist = 9.5, 28.0 end

					local dist = baseDist * TPS.zoomMult
					local pivX, pivY, pivZ = ux, uy + lookH, uz
					local sinP = math.sin(TPS.pitchRx)
					local fx = sinP * math.sin(TPS.yaw)
					local fy = math.cos(TPS.pitchRx)
					local fz = -sinP * math.cos(TPS.yaw)

					local eyeX, eyeY, eyeZ = pivX - fx * dist, pivY - fy * dist, pivZ - fz * dist
					local rxUse, ryUse = TPS.pitchRx, TPS.yaw
					local dxUse, dyUse, dzUse = fx, fy, fz
					if spGetGroundHeight then
						local gH = spGetGroundHeight(eyeX, eyeZ) or 0
						if eyeY < gH + 4.5 then
							eyeY = gH + 4.5
							local ldx, ldy, ldz = pivX - eyeX, pivY - eyeY, pivZ - eyeZ
							local lLen = math.max(1e-4, math.sqrt(ldx * ldx + ldy * ldy + ldz * ldz))
							dxUse, dyUse, dzUse = ldx / lLen, ldy / lLen, ldz / lLen
							rxUse = math.acos(math.max(-0.995, math.min(0.995, dyUse)))
							ryUse = math.atan2(dxUse, -dzUse)
						end
					end
					Spring.SetCameraState({
						name = "fps", mode = CAMERA_MODES[4].mode or 0,
						px = eyeX, py = eyeY, pz = eyeZ,
						dx = dxUse, dy = dyUse, dz = dzUse,
						rx = rxUse, ry = ryUse, rz = 0.0, fov = TPS.fov,
					}, 0.0)
				end
			end
		end
	end
end

--------------------------------------------------------------------------------
-- TOP CARD: Unified 2-Tab Navigation + Telemetry + 3 Clean Tactical Toggles
--------------------------------------------------------------------------------
local function drawTopCommandCard()
	local p = RECTS.pCommand
	local px, py, pw, ph = p.x, p.y, p.w, p.h
	local inL = px + ((px <= 2) and S(8) or math.max(UI.mmPad, S(8)))
	local inR = px + pw - math.max(UI.mmPad, S(8))
	local inW = inR - inL
	local mx, my = spGetMouseState()

	local surge = (spGetGameRulesParam("zdef_surge_active") or 0) == 1
	local surgeProg = spGetGameRulesParam("zdef_surge_progress") or 0
	local waveNum = spGetGameRulesParam("zdef_wave_num") or 1
	local hqHp = spGetGameRulesParam("zdef_hq_hp") or 15000
	local hqMaxHp = math.max(1, spGetGameRulesParam("zdef_hq_maxhp") or 15000)
	local hqFrac = math.max(0, math.min(1, hqHp / hqMaxHp))
	local hqAlert = (spGetGameRulesParam("zdef_hq_under_attack") or 0) == 1
	local cp = spGetGameRulesParam("zdef_command_points") or 220
	local income = spGetGameRulesParam("zdef_cp_income") or 4
	local spotsCap = spGetGameRulesParam("zdef_captured_spots") or 1
	local spotsTot = spGetGameRulesParam("zdef_spot_count") or 6
	local zCount = spGetGameRulesParam("zdef_zombie_count") or 0
	local zKilled = spGetGameRulesParam("zdef_zombies_killed") or 0
	local activeInf = spGetGameRulesParam("zdef_active_inf") or 0
	local activeMraps = spGetGameRulesParam("zdef_active_mraps") or 0
	local activeTanks = spGetGameRulesParam("zdef_active_tanks") or 0
	local autoOn = (spGetGameRulesParam("zdef_auto_support") or 1) == 1
	local sightOn = (spGetGameRulesParam("zdef_full_sight") or 1) == 1
	local fps = spGetFPS and spGetFPS() or 60

	local frame = Spring.GetGameFrame() or 0
	local totalSec = math.max(0, math.floor(frame / 30))
	local mm, ss = math.floor(totalSec / 60), totalSec % 60
	local dangerMode = surge or hqAlert

	drawFlowPanel(px, py, pw, ph, dangerMode, "zdef_rail_cmd")

	-- 1. Clean 2-Tab Segmented Switcher right beneath Minimap
	local tab2Label = string.format("HIỂN THỊ & DEBUG  [%s]", RESOLUTIONS[UI.curResIdx].label)
	drawSegmentedBar(RECTS.tabBtns, { "CHIẾN DỊCH", tab2Label }, UI.activeTab, mx, my, 0.22, 0.78, 0.98, 8.0)

	-- 2. Clock / Wave / Surge (left)  |  CP / Income / Live FPS (right)
	local row1Y = py + ph - S(44)
	local waveCol = surge and "\255\255\092\092" or "\255\145\220\255"
	local tideTag = surge and "\255\255\090\090● SURGE" or string.format("\255\160\186\212%d%%", surgeProg)
	glText(string.format("\255\240\246\252%02d:%02d   %sWAVE %d   %s", mm, ss, waveCol, waveNum, tideTag),
		inL + S(2), row1Y, SF(9.0), "o")

	local fpsCol = (fps < 30) and "\255\255\095\095" or ((fps < 50) and "\255\255\210\095" or "\255\152\236\180")
	glText(string.format("\255\115\248\172%d CP \255\165\212\192(+%d/s)   %s%d FPS", cp, income, fpsCol, fps),
		inR - S(2), row1Y, SF(8.9), "ro")

	-- 3. HQ Integrity Bar
	local hqLblY = py + ph - S(60)
	local hqTitle = hqAlert and "\255\255\090\090▲ HQ BỊ TẤN CÔNG" or "\255\195\218\240CĂN CỨ HQ"
	glText(hqTitle, inL + S(2), hqLblY, SF(8.1), "o")
	local pctCol = (hqFrac < 0.35) and "\255\255\095\095" or "\255\185\235\210"
	glText(string.format("%s%d%% \255\150\172\194(%d/%d)", pctCol, math.floor(hqFrac * 100), math.floor(hqHp), math.floor(hqMaxHp)),
		inR - S(2), hqLblY, SF(7.9), "ro")
	drawSleekBar(inL, py + ph - S(71), inW, S(8), hqFrac,
		hqFrac < 0.35 and 0.96 or 0.20, hqFrac < 0.35 and 0.24 or 0.84, hqFrac < 0.35 and 0.24 or 0.56, true)

	-- 4. Clean 4-Column Aligned KPI Strip (Spots / Military / Zombies / Kills)
	local kpiY = py + ph - S(89)
	local podW = inW * 0.25
	local totalMil = activeInf + activeMraps + activeTanks
	glText(string.format("\255\150\178\202CỨ ĐIỂM \255\238\246\254%d/%d", spotsCap, spotsTot), inL + podW * 0.0, kpiY, SF(7.8), "o")
	glText(string.format("\255\150\178\202QUÂN \255\238\246\254%d (%dM/%dT)", totalMil, activeMraps, activeTanks), inL + podW * 1.0, kpiY, SF(7.8), "o")
	glText(string.format("\255\215\145\145ZOMBIE \255\248\230\230%d", zCount), inL + podW * 2.15, kpiY, SF(7.8), "o")
	glText(string.format("\255\145\218\175DIỆT \255\238\246\254%d", zKilled), inR - S(2), kpiY, SF(7.8), "ro")

	drawDivider(inL, inR, py + S(44))

	-- 5. ONLY 3 Clean, Uniform Tactical Quick Action Buttons!
	local _, camShort = detectActiveCamIdx()
	drawTacticalQuickBtn(RECTS.autoBtn,  "0", "TỰ ĐỘNG",  autoOn and "BẬT" or "TẮT",    autoOn,     mx and inRect(mx, my, RECTS.autoBtn),  0.18, 0.86, 0.56)
	drawTacticalQuickBtn(RECTS.sightBtn, "5", "TẦM NHÌN", sightOn and "TOÀN MAP" or "SƯƠNG", sightOn, mx and inRect(mx, my, RECTS.sightBtn), 0.22, 0.78, 0.98)
	drawTacticalQuickBtn(RECTS.camBtn,   "T", "CAMERA",   camShort,                     TPS.active, mx and inRect(mx, my, RECTS.camBtn),   0.22, 0.78, 0.98)
end

--------------------------------------------------------------------------------
-- TAB 1 — MODULE A: Air Support (3 Uniform Full-Width Tactical Rows)
--------------------------------------------------------------------------------
local function drawTab1Support()
	local p = RECTS.pSupport
	local px, py, pw, ph = p.x, p.y, p.w, p.h
	local inL = px + ((px <= 2) and S(8) or math.max(UI.mmPad, S(8)))
	local inR = px + pw - math.max(UI.mmPad, S(8))
	local mx, my = spGetMouseState()
	local cp = spGetGameRulesParam("zdef_command_points") or 220
	local isAiming = (UI.pendingTargetPkg ~= nil)

	drawFlowPanel(px, py, pw, ph, false, "zdef_rail_sup")

	-- Clean section header
	glText("\255\215\232\248CHI VIỆN KHÔNG QUÂN", inL + S(2), py + ph - S(16.5), SF(8.4), "o")
	if isAiming and PKG_TARGET_META[UI.pendingTargetPkg] then
		glText("\255\255\224\105► CLICK BẢN ĐỒ • ESC HỦY", inR - S(2), py + ph - S(16.5), SF(7.8), "ro")
	else
		glText("\255\090\240\135● BB  \255\085\180\255● GIÁP  \255\255\095\095● BAY", inR - S(2), py + ph - S(16.5), SF(7.5), "ro")
	end
	drawDivider(inL, inR, py + ph - S(22))

	-- 3 Uniform Full-Width Support Rows
	for i = 1, #SUPPORT_CARDS do
		local c = SUPPORT_CARDS[i]
		local r = RECTS.cards[i]
		if r then
			local x1, y1, x2, y2 = r.x1, r.y1, r.x2, r.y2
			local cw, ch = x2 - x1, y2 - y1
			local cdRem = spGetGameRulesParam("zdef_cd_" .. c.pkg) or 0
			local canAfford = (cp >= c.cost) and (cdRem <= 0)
			local isTarget = (UI.pendingTargetPkg == c.pkg)
			local hovered = mx and my and inRect(mx, my, r)
			local hB = hovered and 0.06 or 0.0

			local bgB, bgT, brd
			if isTarget then
				bgB = { c.r * 0.28, c.g * 0.24, c.b * 0.14, 0.92 }
				bgT = { c.r * 0.42, c.g * 0.36, c.b * 0.20, 0.96 }
				brd = { 1.0, 0.82, 0.26, 0.96 }
			elseif canAfford then
				bgB = { 0.045 + hB, 0.065 + hB, 0.095 + hB, 0.86 }
				bgT = { 0.07 + hB, 0.095 + hB, 0.135 + hB, 0.90 }
				brd = { 0.46, 0.60, 0.74, hovered and 0.74 or 0.32 }
			else
				bgB = { 0.035, 0.045, 0.06, 0.76 }
				bgT = { 0.055, 0.065, 0.085, 0.82 }
				brd = { 0.30, 0.36, 0.44, 0.24 }
			end

			drawRoundedRect(x1, y1, x2, y2, S(4), bgB, bgT)
			-- Crisp class indicator bar on left
			glColor(c.r, c.g, c.b, canAfford and 0.92 or 0.34)
			glRect(x1 + 1, y1 + S(3), x1 + S(3.5), y2 - S(3))

			if cdRem > 0 and c.cdMax > 0 then
				local cdFrac = math.min(1.0, cdRem / c.cdMax)
				drawRoundedRect(x1 + 1, y1 + 1, x1 + 1 + (cw - 2) * cdFrac, y2 - 1, S(3.5), { 0.32, 0.08, 0.08, 0.42 })
			end
			drawRoundedOutline(x1, y1, x2, y2, S(4), isTarget and 1.4 or 1.0, brd)

			-- Keycap [1..3]
			local kbX1, kbX2 = x1 + S(8), x1 + S(25)
			local kbY1, kbY2 = y1 + S(7), y2 - S(7)
			drawRoundedRect(kbX1, kbY1, kbX2, kbY2, S(2.5), { 0.09, 0.13, 0.19, 0.95 })
			drawRoundedOutline(kbX1, kbY1, kbX2, kbY2, S(2.5), 1.0, { c.r, c.g, c.b, canAfford and 0.65 or 0.26 })
			glText("\255\236\244\252" .. c.key, (kbX1 + kbX2) * 0.5, y1 + ch * 0.5 - SF(8.8) * 0.34, SF(8.8), "co")

			-- Title + sub
			local titleCol = isTarget and "\255\255\235\125" or (canAfford and "\255\240\246\254" or "\255\145\156\168")
			glText(titleCol .. c.title, kbX2 + S(8), y2 - S(14.5), SF(8.8), "o")
			glText("\255\152\178\204" .. c.sub, kbX2 + S(8), y1 + S(6), SF(7.4), "o")

			-- Cost / Cooldown on right
			if cdRem > 0 then
				glText(string.format("\255\255\140\110CD %ds", cdRem), x2 - S(7), y2 - S(14.5), SF(8.6), "ro")
			else
				local costCol = (cp >= c.cost) and "\255\120\248\172" or "\255\225\115\115"
				glText(string.format("%s%d CP", costCol, c.cost), x2 - S(7), y2 - S(14.5), SF(8.7), "ro")
			end
			local foot = isTarget and "\255\255\232\115CLICK BẢN ĐỒ"
				or (cdRem > 0 and "\255\185\145\135ĐANG HỒI"
				or (canAfford and "\255\140\178\205L: NGẮM • R: GỌI" or "\255\175\125\125THIẾU CP"))
			glText(foot, x2 - S(7), y1 + S(6), SF(7.0), "ro")
		end
	end
end

--------------------------------------------------------------------------------
-- TAB 1 — MODULE B: 3D Tactical Unit Inspector
--------------------------------------------------------------------------------
local function draw3DUnitPortrait(unitID, unitDefID, teamID, isZombie, overrideUnitName)
	local b3 = RECTS.box3D
	local bx, by, bw, bh = b3.x, b3.y, b3.w, b3.h
	if bw <= 10 or bh <= 10 then return end

	drawRoundedRect(bx, by, bx + bw, by + bh, S(4), { 0.015, 0.025, 0.042, 0.94 }, { 0.03, 0.05, 0.08, 0.94 })

	if not GFX.scanner3D then
		drawRoundedOutline(bx, by, bx + bw, by + bh, S(4), 1.0, { 0.42, 0.54, 0.66, 0.36 })
		glText("\255\255\195\0953D SCANNER", bx + bw * 0.5, by + bh * 0.54, SF(8.2), "co")
		glText("\255\165\182\200(ĐÃ TẮT DEBUG)", bx + bw * 0.5, by + bh * 0.36, SF(7.2), "co")
		return
	end

	local def = unitDefID and UnitDefs[unitDefID]
	local uName = overrideUnitName or (def and def.name) or "zdef_infantry"
	local meta = UNIT_META[uName] or UNIT_META.zdef_infantry

	glColor(isZombie and 0.40 or 0.14, isZombie and 0.12 or 0.36, isZombie and 0.12 or 0.50, 0.18)
	glBeginEnd(GL_LINES, function()
		for i = 1, 4 do
			local gx = bx + (bw / 5) * i
			local gy = by + (bh / 5) * i
			glVertex(gx, by + 2); glVertex(gx, by + bh - 2)
			glVertex(bx + 2, gy); glVertex(bx + bw - 2, gy)
		end
	end)

	local cx, cy = bx + bw * 0.5, by + bh * 0.22
	glColor(isZombie and 0.88 or 0.22, isZombie and 0.24 or 0.78, isZombie and 0.22 or 0.98, 0.36)
	glBeginEnd(GL_LINE_LOOP, function()
		for a = 0, 23 do
			local ang = (a / 24) * math.pi * 2
			glVertex(cx + math.cos(ang) * (bw * 0.36), cy + math.sin(ang) * (bh * 0.11))
		end
	end)

	local mdata = PREVIEW_MESHES[uName] or PREVIEW_MESHES.zdef_infantry
	local r = (mdata and mdata.radius) or meta.radius or 12.0
	local midX = (mdata and mdata.mid and mdata.mid[1]) or 0.0
	local midY = (mdata and mdata.mid and mdata.mid[2]) or meta.midY or 7.0
	local midZ = (mdata and mdata.mid and mdata.mid[3]) or 0.0
	local pitch = math.max(-45.0, math.min(65.0, (meta.pitch or 16.0) + UI.previewPitchOffset))

	local yawDeg = UI.previewYawOffset % 360.0
	local hasLiveUnit = (unitID ~= nil and spValidUnitID(unitID))
	if hasLiveUnit and spGetUnitHeading then
		local h = spGetUnitHeading(unitID)
		if h then yawDeg = ((h / 32768.0) * 180.0 + UI.previewYawOffset) % 360.0 end
	end

	glMatrixMode(GL.PROJECTION)
	glPushMatrix()
	glLoadIdentity()
	glOrtho(0, UI.vsx or 1920, 0, UI.vsy or 1080, -2000, 2000)
	glMatrixMode(GL.MODELVIEW)
	glPushMatrix()
	glLoadIdentity()

	glScissor(bx + 2, by + 2, bw - 4, bh - 4)
	glClear(GL.DEPTH_BUFFER_BIT)
	glDepthTest(true)
	glDepthMask(true)
	glCulling(false)

	glTranslate(bx + bw * 0.5, by + bh * 0.47, 0)
	local scalePx = (math.min(bw, bh) * 0.45) / math.max(3.5, r)
	glScale(scalePx, scalePx, scalePx)
	glRotate(pitch, 1, 0, 0)
	glRotate(yawDeg, 0, 1, 0)
	if hasLiveUnit then
		local fPitch = spGetUnitRulesParam(unitID, "zdef_flight_pitch")
		local fRoll = spGetUnitRulesParam(unitID, "zdef_flight_roll")
		if fPitch and fPitch ~= 0 then glRotate(-math.deg(fPitch), 1, 0, 0) end
		if fRoll and fRoll ~= 0 then glRotate(math.deg(fRoll), 0, 0, 1) end
	end
	glTranslate(-midX, -midY, -midZ)

	local texPath = (mdata and mdata.tex) or ("unittextures/" .. uName .. "_tex1.png")
	glBlending(false)
	glColor(1, 1, 1, 1)
	glTexture(0, texPath)

	if VM.portraitShader and gl.UseShader then
		gl.UseShader(VM.portraitShader)
		if VM.uTeamCol and gl.Uniform then
			local tr, tg, tb = 0.25, 0.65, 1.0
			if isZombie then
				tr, tg, tb = 0.55, 0.22, 0.20
			elseif teamID and spGetTeamColor then
				local rCol, gCol, bCol = spGetTeamColor(teamID)
				if rCol then tr, tg, tb = rCol, gCol, bCol end
			end
			gl.Uniform(VM.uTeamCol, tr, tg, tb)
		end
	end

	if hasLiveUnit and gl.UnitRaw then
		pcall(gl.UnitRaw, unitID, true, -1)
	else
		local dlist = getOrBuildPreviewDList(uName)
		if dlist then glCallList(dlist) end
	end

	if VM.portraitShader and gl.UseShader then gl.UseShader(0) end
	glTexture(0, false)
	glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	glDepthMask(false)
	glDepthTest(false)
	glScissor(false)

	glMatrixMode(GL.PROJECTION)
	glPopMatrix()
	glMatrixMode(GL.MODELVIEW)
	glPopMatrix()
	glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

	drawRoundedOutline(bx, by, bx + bw, by + bh, S(4), 1.0,
		{ isZombie and 0.88 or 0.36, isZombie and 0.28 or 0.62, isZombie and 0.26 or 0.82, 0.48 })

	local badgeCol = isZombie and "\255\255\105\105" or "\255\105\225\255"
	glText(badgeCol .. (UI.manualPreviewUnitName and "● MẪU" or "● LIVE"), bx + S(5), by + bh - S(12), SF(7.2), "o")
	glText("\255\145\175\205KÉO XOAY", bx + S(5), by + S(4), SF(6.7), "o")
end

local function resolveInspectedUnit()
	local sel = spGetSelectedUnits()
	if sel and #sel > 0 then
		for i = 1, #sel do
			local uid = sel[i]
			if spValidUnitID(uid) then
				local defID = spGetUnitDefID(uid)
				if defID then return uid, defID, #sel, sel, "selected" end
			end
		end
	end
	if UI.currentHoveredUnitID and spValidUnitID(UI.currentHoveredUnitID) then
		local defID = spGetUnitDefID(UI.currentHoveredUnitID)
		if defID then return UI.currentHoveredUnitID, defID, 1, { UI.currentHoveredUnitID }, "hovered" end
	end
	return nil, nil, 0, {}, "overview"
end

local function cycleShowcaseUnit(dir)
	if not UI.manualPreviewUnitName then
		local _, defID = resolveInspectedUnit()
		local curName = (defID and UnitDefs[defID] and UnitDefs[defID].name) or "zdef_infantry"
		for i = 1, #PREVIEW_SHOWCASE_ORDER do
			if PREVIEW_SHOWCASE_ORDER[i] == curName then UI.showcaseIdx = i; break end
		end
	end
	UI.showcaseIdx = UI.showcaseIdx + (dir or 1)
	if UI.showcaseIdx < 1 then UI.showcaseIdx = #PREVIEW_SHOWCASE_ORDER end
	if UI.showcaseIdx > #PREVIEW_SHOWCASE_ORDER then UI.showcaseIdx = 1 end
	UI.manualPreviewUnitName = PREVIEW_SHOWCASE_ORDER[UI.showcaseIdx]
end

local function drawTab1Scanner()
	local p = RECTS.pScanner
	local ix, iy, iw, ih = p.x, p.y, p.w, p.h
	local inL = ix + ((ix <= 2) and S(8) or math.max(UI.mmPad, S(8)))
	local inR = ix + iw - math.max(UI.mmPad, S(8))
	local mx, my = spGetMouseState()
	local unitID, unitDefID, selCount, _, inspectMode = resolveInspectedUnit()
	local isOverviewMode = (inspectMode == "overview") and (UI.manualPreviewUnitName == nil)

	local isZombie = false
	local uName = "zdef_hq"
	local def = nil

	if not isOverviewMode then
		def = unitDefID and UnitDefs[unitDefID]
		uName = UI.manualPreviewUnitName or (def and def.name) or "zdef_infantry"
		if not def and UnitDefNames and UnitDefNames[uName] then
			def = UnitDefNames[uName]
			unitDefID = def and def.id or nil
		end
		if UI.manualPreviewUnitName and UnitDefNames and UnitDefNames[UI.manualPreviewUnitName] then
			def = UnitDefNames[UI.manualPreviewUnitName]
			unitDefID = def.id
			unitID = nil
			local allU = spGetAllUnits and spGetAllUnits() or {}
			for i = 1, #allU do
				if spGetUnitDefID(allU[i]) == unitDefID then unitID = allU[i]; break end
			end
		end
		isZombie = (uName:find("zombie") ~= nil)
	end

	drawFlowPanel(ix, iy, iw, ih, isZombie, "zdef_rail_scan")

	-- Clean Header + Unified Segmented [< | LIVE | >] control
	local hdrText
	if isOverviewMode then
		hdrText = "QUÉT ĐƠN VỊ 3D • TỔNG QUAN"
	elseif UI.manualPreviewUnitName then
		hdrText = string.format("THƯ VIỆN 3D (%d/%d)", UI.showcaseIdx, #PREVIEW_SHOWCASE_ORDER)
	elseif inspectMode == "selected" then
		hdrText = (selCount > 1) and string.format("TIỂU ĐỘI (%d ĐƠN VỊ)", selCount) or "QUÉT 3D • ĐÃ CHỌN"
	else
		hdrText = "QUÉT 3D • TRỰC TIẾP"
	end
	glText("\255\215\232\248" .. hdrText, inL + S(2), iy + ih - S(16.5), SF(8.4), "o")

	local isLive = (UI.manualPreviewUnitName == nil)
	drawSegmentedBar(RECTS.scanNavBtns, { "<", isLive and "LIVE" or "MẪU", ">" }, isLive and 2 or 0, mx, my, 0.22, 0.78, 0.98, 7.2)
	drawDivider(inL, inR, iy + ih - S(25))

	local tx = RECTS.box3D.x + RECTS.box3D.w + S(10)
	local tw = math.max(80, inR - tx)

	if isOverviewMode then
		local hqID = spGetGameRulesParam("zdef_hq_id")
		local validHqID = (hqID and hqID > 0 and spValidUnitID(hqID)) and hqID or nil
		local hqDefID = (UnitDefNames and UnitDefNames.zdef_hq and UnitDefNames.zdef_hq.id) or nil
		draw3DUnitPortrait(validHqID, hqDefID, 0, false, "zdef_hq")

		local spotsCap = spGetGameRulesParam("zdef_captured_spots") or 0
		local spotsTot = math.max(1, spGetGameRulesParam("zdef_spot_count") or 6)
		local airSorties = spGetGameRulesParam("zdef_air_sorties") or 0
		local c130Mode = spGetGameRulesParam("zdef_c130_mode") or "ORBIT"

		glText("\255\242\248\255BỘ CHỈ HUY PHÒNG THỦ", tx, iy + ih - S(40), SF(9.1), "o")
		glText("\255\156\184\212Rê chuột / Click đơn vị để quét 3D", tx, iy + ih - S(54), SF(7.7), "o")

		glText(string.format("\255\150\208\240KIỂM SOÁT CỨ ĐIỂM: %d / %d", spotsCap, spotsTot), tx, iy + ih - S(74), SF(8.0), "o")
		drawSleekBar(tx, iy + ih - S(86), tw, S(7), spotsCap / spotsTot, 0.22, 0.78, 0.98, false)

		glText(string.format("\255\165\192\218PHÁO HẠM C-130: \255\238\246\254%s", tostring(c130Mode)), tx, iy + ih - S(106), SF(7.9), "o")
		glText(string.format("\255\165\192\218XUẤT KÍCH KHÔNG QUÂN: \255\238\246\254%d", airSorties), tx, iy + ih - S(120), SF(7.9), "o")
		glText("\255\130\235\175AI: \255\218\232\244Quân đội Tự động 100%", tx, iy + ih - S(134), SF(7.8), "o")
		glText("\255\135\165\195Click khung: Nhảy HQ • [T]: TPS 360°", tx, iy + ih - S(148), SF(7.2), "o")
		return
	end

	local teamID = (unitID and spValidUnitID(unitID) and spGetUnitTeam(unitID)) or 0
	draw3DUnitPortrait(unitID, unitDefID, teamID, isZombie, uName)

	local meta = UNIT_META[uName] or UNIT_META.zdef_infantry
	glText((isZombie and "\255\255\125\125" or "\255\244\250\255") .. meta.title, tx, iy + ih - S(40), SF(9.0), "o")
	glText("\255\156\186\214" .. meta.role, tx, iy + ih - S(53), SF(7.8), "o")

	local hp, maxHp
	if unitID and spValidUnitID(unitID) then hp, maxHp = spGetUnitHealth(unitID)
	elseif def then hp, maxHp = def.health or 1000, def.health or 1000 end
	hp = math.max(0, hp or 100)
	maxHp = math.max(1, maxHp or 100)
	local hpFrac = hp / maxHp

	glText(string.format("\255\205\224\242HP: %d/%d (%.0f%%)", math.floor(hp), math.floor(maxHp), hpFrac * 100), tx, iy + ih - S(69), SF(8.0), "o")
	drawSleekBar(tx, iy + ih - S(80), tw, S(7), hpFrac,
		hpFrac < 0.35 and 0.96 or (hpFrac < 0.65 and 0.96 or 0.20),
		hpFrac < 0.35 and 0.24 or (hpFrac < 0.65 and 0.76 or 0.86), 0.42, true)

	local hasLive = (unitID ~= nil and spValidUnitID(unitID))
	local morale = hasLive and spGetUnitRulesParam(unitID, "zdef_morale") or nil
	local aiState = hasLive and spGetUnitRulesParam(unitID, "zdef_state") or nil

	if not isZombie then
		local mVal = morale or 100
		local sVal = aiState or "READY"
		glText(string.format("\255\200\220\240SĨ KHÍ: %d  \255\140\225\255[%s]", mVal, sVal), tx, iy + ih - S(97), SF(7.9), "o")
		drawSleekBar(tx, iy + ih - S(107), tw, S(6), mVal / 100.0, 0.22, 0.76, 0.98, false)
	else
		local threat = (def and def.customParams and def.customParams.zdef_threat) or "10"
		glText(string.format("\255\255\145\145ĐE DỌA: %s • THÙ ĐỊCH", tostring(threat)), tx, iy + ih - S(97), SF(7.9), "o")
		drawSleekBar(tx, iy + ih - S(107), tw, S(6), 1.0, 0.90, 0.26, 0.26, false)
	end

	glText("\255\152\188\218VK: \255\234\242\250" .. meta.weapon, tx, iy + ih - S(123), SF(7.7), "o")
	glText("\255\152\188\218ĐT: \255\218\228\238" .. meta.special, tx, iy + ih - S(136), SF(7.5), "o")
	glText("\255\135\165\195Click: Nhảy tới • [T]: TPS 360°", tx, iy + ih - S(149), SF(7.1), "o")
end

--------------------------------------------------------------------------------
-- TAB 2: Unified Display, Output Resolution Lock & Graphics Debug Workbench
--------------------------------------------------------------------------------
local function drawTab2Workbench()
	local p = RECTS.pWorkbench
	local px, py, pw, ph = p.x, p.y, p.w, p.h
	local inL = px + ((px <= 2) and S(8) or math.max(UI.mmPad, S(8)))
	local inR = px + pw - math.max(UI.mmPad, S(8))
	local mx, my = spGetMouseState()
	local onCount, totCount = countActiveGfxLayers()
	local _, monW, monH = detectActiveDisplayIdx()
	local curVx, curVy = UI.vsx or 1920, UI.vsy or 1080
	local isHeavy4K = (curVy > 1500)

	drawFlowPanel(px, py, pw, ph, false, "zdef_rail_wb")

	-- Section 1: Output Resolution & Display Mode (Strictly Locked — Anti-4K)
	glText("\255\215\232\248HIỂN THỊ & ĐỘ PHÂN GIẢI OUTPUT", inL + S(2), py + ph - S(16.5), SF(8.2), "o")
	local gpuCol = isHeavy4K and "\255\255\115\115" or "\255\135\245\180"
	glText(string.format("%sGPU:%dx%d \255\150\172\195(Màn:%dx%d)", gpuCol, curVx, curVy, monW, monH),
		inR - S(2), py + ph - S(16.5), SF(7.4), "ro")

	local resLabels = {}
	for i = 1, #RESOLUTIONS do resLabels[i] = RESOLUTIONS[i].label end
	drawSegmentedBar(RECTS.outResBtns, resLabels, UI.curResIdx, mx, my, 0.22, 0.78, 0.98, 7.5)

	local modeLabels = {}
	for i = 1, #SCREEN_MODES do modeLabels[i] = SCREEN_MODES[i].short end
	drawSegmentedBar(RECTS.outModeBtns, modeLabels, UI.curScreenModeIdx, mx, my, 0.18, 0.86, 0.56, 7.3)

	-- UI Scale Row (Label left + 6-segment bar right)
	if RECTS.uiScaleBtns[1] then
		local syMid = RECTS.uiScaleBtns[1].y1 + (RECTS.uiScaleBtns[1].y2 - RECTS.uiScaleBtns[1].y1) * 0.5 - SF(7.5) * 0.34
		glText("\255\165\188\212TỈ LỆ HUD:", inL + S(2), syMid, SF(7.5), "o")
		local scLabels = {}
		for i = 1, #SCALE_STEPS do scLabels[i] = SCALE_STEPS[i].label end
		drawSegmentedBar(RECTS.uiScaleBtns, scLabels, UI.scaleModeIdx, mx, my, 0.22, 0.78, 0.98, 7.1)
	end

	-- Section 2 & 3 Headings + 16 Uniform Hardware-Style Toggle Switches
	if RECTS.gfxBtns[1] then
		drawDivider(inL, inR, RECTS.gfxBtns[1].y2 + S(16))
		glText("\255\205\224\242LỚP ĐỒ HỌA CHIẾN THUẬT (MOD)", inL + S(2), RECTS.gfxBtns[1].y2 + S(4.5), SF(7.6), "o")
		glText(string.format("\255\145\230\185%d/%d BẬT", onCount, totCount), inR - S(2), RECTS.gfxBtns[1].y2 + S(4.5), SF(7.4), "ro")
	end
	if RECTS.gfxBtns[9] then
		glText("\255\205\224\242ENGINE & BAR SHADERS", inL + S(2), RECTS.gfxBtns[9].y2 + S(4.5), SF(7.6), "o")
	end

	for i = 1, #GFX_ITEMS do
		local item = GFX_ITEMS[i]
		local r = RECTS.gfxBtns[i]
		if r then
			drawGfxSwitchTile(r, item.label, GFX[item.key] == true, mx and my and inRect(mx, my, r))
		end
	end

	-- Bottom 3-Segment Quick Preset & Terrain Debug Strip
	local tLbl = (GFX.terrainMode == "height") and "ĐỊA HÌNH: CAO"
		or ((GFX.terrainMode == "path") and "ĐỊA HÌNH: ĐƯỜNG" or "ĐỊA HÌNH: THƯỜNG")
	local actPreset = (GFX.terrainMode ~= "normal") and 3 or ((onCount == totCount) and 1 or ((onCount <= 6) and 2 or 0))
	drawSegmentedBar(RECTS.presetBtns, { "BẬT TẤT CẢ", "TỐI GIẢN FPS", tLbl }, actPreset, mx, my, 0.22, 0.78, 0.98, 7.2)
end

--------------------------------------------------------------------------------
-- Transient Top-Center Radio Alert Toast & TPS Orbit Control Strip
--------------------------------------------------------------------------------
local function drawTransientTopStrips()
	local vx, vy = UI.vsx or 1920, UI.vsy or 1080
	local railRight = RECTS.rail.x2 or 0
	local cx = math.floor(railRight + (vx - railRight) * 0.5)
	local curY = vy - S(10)

	local alertText = spGetGameRulesParam("zdef_alert_text")
	local alertFrame = spGetGameRulesParam("zdef_alert_frame") or -9999
	local alertType = spGetGameRulesParam("zdef_alert_type") or "info"
	local frame = Spring.GetGameFrame() or 0
	local age = frame - alertFrame
	if alertText and alertText ~= "" and age >= 0 and age <= 125 then
		local fade = 1.0
		if age < 8 then fade = age / 8.0
		elseif age > 95 then fade = math.max(0.0, (125 - age) / 30.0) end
		local tw, th = S(440), S(24)
		local tx, ty = cx - math.floor(tw * 0.5), curY - th
		local ar, ag, ab = 0.22, 0.78, 0.98
		if alertType == "danger" then ar, ag, ab = 1.0, 0.24, 0.24
		elseif alertType == "warn" then ar, ag, ab = 1.0, 0.65, 0.16
		elseif alertType == "good" then ar, ag, ab = 0.18, 0.88, 0.54
		elseif alertType == "air" then ar, ag, ab = 1.0, 0.44, 0.18 end

		drawRoundedRect(tx, ty, tx + tw, ty + th, S(4), { 0.03, 0.045, 0.07, 0.84 * fade }, { 0.055, 0.08, 0.12, 0.88 * fade })
		drawRoundedOutline(tx, ty, tx + tw, ty + th, S(4), 1.0, { ar, ag, ab, 0.78 * fade })
		glColor(ar, ag, ab, 0.95 * fade)
		glRect(tx + S(2), ty + S(3), tx + S(4.5), ty + th - S(3))
		glColor(1, 1, 1, fade)
		glText("\255\242\248\255" .. tostring(alertText), cx, ty + S(6.5), SF(8.8), "co")
		curY = ty - S(5)
	end

	if TPS.active then
		local uid = TPS.uid
		local uDefID = (uid and spValidUnitID(uid)) and spGetUnitDefID(uid) or nil
		local uName = (uDefID and UnitDefs[uDefID] and UnitDefs[uDefID].humanName) or "Đơn vị"
		local bw, bh = S(640), S(24)
		local bx, by = cx - math.floor(bw * 0.5), curY - bh
		drawRoundedRect(bx, by, bx + bw, by + bh, S(4), { 0.03, 0.06, 0.10, 0.88 }, { 0.05, 0.10, 0.16, 0.92 })
		drawRoundedOutline(bx, by, bx + bw, by + bh, S(4), 1.0, { 0.22, 0.78, 0.98, 0.76 })
		glText(
			string.format("\255\115\225\255[TPS ORBIT: %s]  \255\235\245\255Giữ Chuột Phải/Giữa (hoặc WASD): Xoay 360°  •  Lăn chuột: Zoom  •  T / ESC: Thoát", tostring(uName)),
			cx, by + S(6.5), SF(8.4), "co"
		)
	end
end

--------------------------------------------------------------------------------
-- Mission Defeat / Operation Debrief Overlay
--------------------------------------------------------------------------------
local function drawDefeatOverlay()
	if (spGetGameRulesParam("zdef_game_over") or 0) ~= 1 or UI.dismissedDefeat then return end
	local vx, vy = UI.vsx or 1920, UI.vsy or 1080
	local cx, cy = math.floor(vx * 0.5), math.floor(vy * 0.5)
	local ow, oh = S(430), S(264)
	local ox, oy = cx - math.floor(ow * 0.5), cy - math.floor(oh * 0.5)
	local mx, my = spGetMouseState()

	glColor(0.02, 0.01, 0.02, 0.54)
	glRect(0, 0, vx, vy)

	drawFlowPanel(ox, oy, ow, oh, true, nil)
	glText("\255\255\095\095CĂN CỨ HQ ĐÃ THẤT THỦ", cx, oy + oh - S(38), SF(15.0), "co")
	glText("\255\220\205\205CHIẾN DỊCH PHÒNG THỦ KẾT THÚC — BÁO CÁO TỔNG KẾT", cx, oy + oh - S(58), SF(8.8), "co")

	local frame = Spring.GetGameFrame() or 0
	local sec = math.max(0, math.floor(frame / 30))
	local waveNum = spGetGameRulesParam("zdef_wave_num") or 1
	local zKilled = spGetGameRulesParam("zdef_zombies_killed") or 0
	local sInf = spGetGameRulesParam("zdef_soldiers_infected") or 0
	local airS = spGetGameRulesParam("zdef_air_sorties") or 0

	local sy = oy + oh - S(92)
	glText(string.format("\255\255\225\115THỜI GIAN TRỤ VỮNG:  \255\245\250\255%02d:%02d   (WAVE %d)", math.floor(sec / 60), sec % 60, waveNum), cx, sy, SF(10.2), "co")
	glText(string.format("\255\130\245\175ZOMBIE ĐÃ TIÊU DIỆT:  \255\245\250\255%d", zKilled), cx, sy - S(24), SF(10.2), "co")
	glText(string.format("\255\255\140\140BỘ BINH LÂY NHIỄM:  \255\245\250\255%d   •   \255\145\218\255KHÔNG QUÂN: \255\245\250\255%d", sInf, airS), cx, sy - S(48), SF(9.8), "co")

	drawUniformActionBtn(RECTS.restartBtn, "\255\145\255\185KHỞI ĐỘNG LẠI CHIẾN DỊCH", true, mx and inRect(mx, my, RECTS.restartBtn), 0.18, 0.86, 0.52, 9.0)
	drawUniformActionBtn(RECTS.spectateBtn, "\255\215\232\250TIẾP TỤC QUAN SÁT", false, mx and inRect(mx, my, RECTS.spectateBtn), 0.22, 0.78, 0.98, 9.0)
end

local function safeHudCall(tag, fn)
	local ok, err = pcall(fn)
	if not ok and not UI.loggedErr[tag] then
		UI.loggedErr[tag] = true
		Spring.Echo("[ZOMBIE DEFENSE HUD ERROR in " .. tostring(tag) .. "]: " .. tostring(err))
	end
end

function widget:DrawScreen()
	if not UI.mmMax then
		safeHudCall("TopCommandCard", drawTopCommandCard)
		if UI.activeTab == 1 then
			safeHudCall("Tab1Support", drawTab1Support)
			safeHudCall("Tab1Scanner", drawTab1Scanner)
		else
			safeHudCall("Tab2Workbench", drawTab2Workbench)
		end
	end
	safeHudCall("TopStrips", drawTransientTopStrips)
	safeHudCall("DefeatOverlay", drawDefeatOverlay)
	glColor(1, 1, 1, 1)
end

--------------------------------------------------------------------------------
-- Input Handling (Unified 2-Tab Rail + Targeting + 360° TPS + Zero Unit Control)
--------------------------------------------------------------------------------
function widget:MousePress(mx, my, button)
	if TPS.active and button == 2 then
		TPS.isDragging = true
		TPS.dragLastX, TPS.dragLastY = mx, my
		return true
	end
	if button ~= 1 and button ~= 3 then return false end

	-- 1. Defeat Overlay
	if (spGetGameRulesParam("zdef_game_over") or 0) == 1 and not UI.dismissedDefeat then
		if inRect(mx, my, RECTS.restartBtn) then
			spSendLuaRulesMsg("zdef_restart_op")
			UI.dismissedDefeat = true
			return true
		elseif inRect(mx, my, RECTS.spectateBtn) then
			UI.dismissedDefeat = true
			return true
		end
	end

	-- 2. Unified Minimap-Aligned Vertical Rail
	if not UI.mmMax then
		-- Top Command Card (2-Tab Switcher + 3 Tactical Quick Buttons)
		if inBox(mx, my, RECTS.pCommand) then
			for t = 1, 2 do
				if inRect(mx, my, RECTS.tabBtns[t]) then
					switchRailTab(t)
					return true
				end
			end
			if inRect(mx, my, RECTS.autoBtn) then spSendLuaRulesMsg("zdef_toggle_auto"); return true end
			if inRect(mx, my, RECTS.sightBtn) then spSendLuaRulesMsg("zdef_toggle_sight"); return true end
			if inRect(mx, my, RECTS.camBtn) then cycleCameraMode(button == 3 and -1 or 1); return true end
			return true
		end

		if UI.activeTab == 1 then
			-- Tab 1 Module A: Air Support Rows
			if inBox(mx, my, RECTS.pSupport) then
				for i = 1, #SUPPORT_CARDS do
					if inRect(mx, my, RECTS.cards[i]) then
						local c = SUPPORT_CARDS[i]
						if button == 3 or UI.pendingTargetPkg == c.pkg then
							UI.pendingTargetPkg = nil
							spSendLuaRulesMsg(c.id)
						else
							UI.pendingTargetPkg = c.pkg
						end
						return true
					end
				end
				return true
			end

			-- Tab 1 Module B: 3D Unit Inspector
			if inBox(mx, my, RECTS.pScanner) then
				if inRect(mx, my, RECTS.scanNavBtns[1]) then cycleShowcaseUnit(-1); return true
				elseif inRect(mx, my, RECTS.scanNavBtns[3]) then cycleShowcaseUnit(1); return true
				elseif inRect(mx, my, RECTS.scanNavBtns[2]) then
					if UI.manualPreviewUnitName then UI.manualPreviewUnitName = nil else cycleShowcaseUnit(1) end
					return true
				end
				local b3 = RECTS.box3D
				if mx >= b3.x and mx <= b3.x + b3.w and my >= b3.y and my <= b3.y + b3.h then
					if button == 3 then
						UI.previewYawOffset, UI.previewPitchOffset = 0.0, 0.0
					else
						UI.isDragging3D = true
						UI.dragLastX, UI.dragLastY = mx, my
					end
					return true
				end
				local unitID = resolveInspectedUnit()
				if unitID and spValidUnitID(unitID) and spGetUnitPosition and Spring.SetCameraTarget then
					local ux, uy, uz = spGetUnitPosition(unitID)
					if ux then Spring.SetCameraTarget(ux, uy, uz, 0.45) end
				else
					local hqx, hqz = spGetGameRulesParam("zdef_hq_x"), spGetGameRulesParam("zdef_hq_z")
					if hqx and hqz and Spring.SetCameraTarget then
						Spring.SetCameraTarget(hqx, (spGetGroundHeight and spGetGroundHeight(hqx, hqz)) or 100, hqz, 0.45)
					end
				end
				return true
			end
		else
			-- Tab 2: Display, Output Resolution & Graphics Debug Workbench
			if inBox(mx, my, RECTS.pWorkbench) then
				for i = 1, #RESOLUTIONS do
					if inRect(mx, my, RECTS.outResBtns[i]) then setOutputResolutionIdx(i); return true end
				end
				for i = 1, #SCREEN_MODES do
					if inRect(mx, my, RECTS.outModeBtns[i]) then setScreenModeIdx(i); return true end
				end
				for i = 1, #SCALE_STEPS do
					if inRect(mx, my, RECTS.uiScaleBtns[i]) then setScaleModeIdx(i); return true end
				end
				for i = 1, #GFX_ITEMS do
					if inRect(mx, my, RECTS.gfxBtns[i]) then
						local item = GFX_ITEMS[i]
						applyGfxItemState(item, not GFX[item.key])
						return true
					end
				end
				if inRect(mx, my, RECTS.presetBtns[1]) then applyGfxPreset("all_on"); return true end
				if inRect(mx, my, RECTS.presetBtns[2]) then applyGfxPreset("perf");   return true end
				if inRect(mx, my, RECTS.presetBtns[3]) then cycleTerrainDebugMode();  return true end
				return true
			end
		end
	end

	-- 3. Interactive 3D Map Targeting Mode
	if UI.pendingTargetPkg then
		if button == 3 then
			UI.pendingTargetPkg = nil
			return true
		elseif button == 1 then
			local _, pos = spTraceScreenRay(mx, my, true)
			if type(pos) == "table" and pos[1] and pos[3] then
				spSendLuaRulesMsg(string.format("zdef_call_%s:%.0f:%.0f", UI.pendingTargetPkg, pos[1], pos[3]))
				UI.pendingTargetPkg = nil
				return true
			end
		end
	end

	-- 4. TPS 3rd-Person Orbit Camera mouse controls
	if TPS.active then
		if button == 3 then
			TPS.isDragging = true
			TPS.dragLastX, TPS.dragLastY = mx, my
			return true
		elseif button == 1 then
			local rType, rData = spTraceScreenRay(mx, my)
			if rType == "unit" and rData and spValidUnitID(rData) then TPS.uid = rData end
		end
	end

	-- 5. Zero-Manual-Control Guarantee: swallow right-clicks on world
	if button == 3 then return true end
	return false
end

function widget:MouseMove(mx, my)
	if UI.isDragging3D then
		UI.previewYawOffset = (UI.previewYawOffset + (mx - UI.dragLastX) * 1.45) % 360.0
		UI.previewPitchOffset = math.max(-35.0, math.min(45.0, UI.previewPitchOffset - (my - UI.dragLastY) * 0.85))
		UI.dragLastX, UI.dragLastY = mx, my
		return true
	elseif TPS.active and TPS.isDragging then
		local dmx, dmy = mx - TPS.dragLastX, my - TPS.dragLastY
		TPS.yaw = (TPS.yaw + dmx * 0.0065) % (math.pi * 2.0)
		TPS.pitchRx = math.max(1.25, math.min(2.78, TPS.pitchRx - dmy * 0.0055))
		TPS.dragLastX, TPS.dragLastY = mx, my
		return true
	end
	return false
end

function widget:MouseRelease()
	if UI.isDragging3D then UI.isDragging3D = false; return true end
	if TPS.isDragging then TPS.isDragging = false; return true end
	return false
end

function widget:MouseWheel(up)
	if TPS.followModeActive then
		TPS.followHeight = math.max(240.0, math.min(3400.0, TPS.followHeight + (up and -75.0 or 75.0)))
		return true
	elseif TPS.active then
		TPS.targetZoomMult = up and math.max(0.45, TPS.targetZoomMult * 0.85) or math.min(5.50, TPS.targetZoomMult * 1.17)
		return true
	end
	return false
end

function widget:KeyPress(key, mods)
	if mods and mods.ctrl then
		if key == 282 or key == 283 then applyCameraModeByIndex(1); return true
		elseif key == 284 then applyCameraModeByIndex(3); return true
		elseif key == 285 then applyCameraModeByIndex(2); return true
		elseif key == 286 then applyCameraModeByIndex(5); return true end
	end

	if TPS.active then
		if key == 27 and not UI.pendingTargetPkg then applyCameraModeByIndex(1); return true
		elseif key == 119 or key == 97 or key == 115 or key == 100
			or key == 273 or key == 274 or key == 275 or key == 276 then return true end
	end

	if key == 289 then toggleDebugTab(); return true -- F8: Switch between Combat & Display/Debug tabs
	elseif key == 116 then applyCameraModeByIndex(TPS.active and 1 or 4); return true -- 'T': TPS Orbit
	elseif key == 27 and UI.pendingTargetPkg then UI.pendingTargetPkg = nil; return true -- ESC
	elseif key == 292 then cycleScreenMode(1); return true -- F11
	elseif key == 91 then cycleScaleMode(-1); return true  -- '['
	elseif key == 93 then cycleScaleMode(1); return true   -- ']'
	elseif key == 48 then spSendLuaRulesMsg("zdef_toggle_auto"); return true -- '0'
	elseif key == 49 then UI.pendingTargetPkg = nil; spSendLuaRulesMsg("zdef_call_armor"); return true -- '1'
	elseif key == 50 then UI.pendingTargetPkg = nil; spSendLuaRulesMsg("zdef_call_a10"); return true   -- '2'
	elseif key == 51 then UI.pendingTargetPkg = nil; spSendLuaRulesMsg("zdef_call_ac130"); return true -- '3'
	elseif key == 53 then spSendLuaRulesMsg("zdef_toggle_sight"); return true -- '5'
	end
	return false
end
