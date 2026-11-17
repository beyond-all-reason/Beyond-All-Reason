local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Terraform Brush Cinematic Cam",
		desc = "A free camera for framing views of a map: fly, orbit, lens, saved views, photo of the view. Console: /tfcinecam",
		author = "PtaQ",
		date = "2026",
		license = "GPL-2.0+",
		-- Before the brush tools, so its drags and wheel come here first.
		layer = -1000,
		-- Off by default like the rest of the suite: cmd_terraform_suite.lua enables it.
		enabled = false,
	}
end

local Cam = VFS.Include("luaui/Include/cinematic_cam.lua")
local CameraMath = VFS.Include("common/camera_math.lua")

local Echo = Spring.Echo

local OUT_ROOT = "Terraform Brush/Captures/Views/"
local SPACE_SCAN, LEVEL_SCAN, HOME_SCAN = 44, 21, 11
local ESCAPE_KEY = 27
-- SDL scancodes of the number row: 1..9.
---@type table<integer, integer>
local VIEW_SCANS = { [30] = 1, [31] = 2, [32] = 3, [33] = 4, [34] = 5, [35] = 6, [36] = 7, [37] = 8, [38] = 9 }
-- A second press of a view's key within this many seconds lands at once.
local SNAP_SECONDS = 1.5
local SHOT_SETTLE_FRAMES = 2
local MIN_SPEED_PCT, MAX_SPEED_PCT = 25, 400
local CLAMP_CONFIG, TRANSITION_CONFIG = "FPSClampPos", "CamTransitionMode"
local WHEEL_CONFIG, MOUSE_CONFIG, MIDDLE_SPEED_CONFIG = "ScrollWheelSpeed", "InvertMouse", "MiddleClickScrollSpeed"

---@class TerraformCineCamSettings
---@field flySpeed integer percent, 25..400
---@field lookSpeed integer percent, 25..400
---@field middle string "orbit" | "pan"
---@field invertDrag boolean
---@field scheme string "wasd" | "arrows" | "numpad"
---@field guides boolean
local settings = {
	flySpeed = 100,
	lookSpeed = 100,
	middle = "orbit",
	invertDrag = false,
	scheme = "wasd",
	guides = false,
}

-- Saved views per map name.
local views = {} ---@type table<string, table<integer, CinematicCamPose>>

---@class TerraformCineCamStatus
---@field lastPath string where the last photo went
---@field error string empty unless the last photo failed
local status = { lastPath = "", error = "" }

---@class TerraformCineCamLive
---@field state CinematicCamState
---@field saved table the player's camera state before
---@field look { x: number, y: number }
---@field scheme table
---@field held table<integer, integer>
---@field codes table<integer, integer>
---@field drag string? "look" | "orbit" | "pan"
---@field pivot table?
---@field panScale number?
---@field middleTurn number?
---@field lastView integer?
---@field lastViewAt any
---@field overlay { clampPos: integer, transitionMode: integer? }
---@field fed table?

local on ---@type TerraformCineCamLive?
local shot ---@type { path: string, settle: integer, hidGui: boolean? }?

local function speedFactor(pct)
	return math.max(MIN_SPEED_PCT, math.min(MAX_SPEED_PCT, tonumber(pct) or 100)) / 100
end

local function useScheme()
	if not on then
		return
	end
	local scheme = Cam.keyScheme(settings.scheme)
	on.scheme, on.held, on.codes = scheme, {}, {}
	for scan, key in pairs(scheme.keys) do
		local ok, code = pcall(Spring.GetKeyFromScanSymbol, key.symbol)
		on.codes[scan] = (ok and tonumber(code) and code > 0) and code or key.code
	end
end

local function applySettings()
	if not on then
		return
	end
	on.state.flyScale, on.state.lookScale = speedFactor(settings.flySpeed), speedFactor(settings.lookSpeed)
	if Cam.keyScheme(settings.scheme) ~= on.scheme then
		useScheme()
	end
end

local function poseCamera()
	if on then
		Spring.SetCameraState(Cam.cameraState(on.state.pose), 0)
	end
end

local function captureBusy()
	local capture = WG.TerraformCapture
	return (capture and capture.isBusy and capture.isBusy()) == true
end

local function start()
	if on then
		return true
	end
	if captureBusy() then
		return false
	end
	local px, py, pz = Spring.GetCameraPosition()
	local dx, dy, dz = Spring.GetCameraDirection()
	local pose = Cam.poseFrom(px, py, pz, dx, dy, dz, Spring.GetCameraFOV())
	-- No map clamp, and a zero-time pose shows the frame it is set.
	local overlay = { clampPos = Spring.GetConfigInt(CLAMP_CONFIG, 1) }
	Spring.SetConfigInt(CLAMP_CONFIG, 0, true)
	if Spring.GetConfigInt(TRANSITION_CONFIG, 0) == 0 then
		overlay.transitionMode = 0
		Spring.SetConfigInt(TRANSITION_CONFIG, 1, true)
	end
	on = {
		state = Cam.new(pose),
		saved = Spring.GetCameraState(),
		look = { x = 0, y = 0 },
		scheme = Cam.keyScheme(settings.scheme),
		held = {},
		codes = {},
		overlay = overlay,
	}
	useScheme()
	Cam.setBounds(Game.mapSizeX, Game.mapSizeZ)
	applySettings()
	poseCamera()
	widgetHandler:OwnText()
	Echo(
		"[Cinematic Cam] on: "
			.. on.scheme.help
			.. ", right-drag looks, wheel dollies, Space takes a photo, Escape leaves"
	)
	return true
end

local function stop()
	local was = on
	if not was then
		return false
	end
	on = nil
	widgetHandler:DisownText()
	if widgetHandler:IsMouseOwner() then
		widgetHandler:DisownMouse()
	end
	-- Back to the player's camera mode, as near this view as it allows.
	local limits = {
		mapX = Game.mapSizeX,
		mapZ = Game.mapSizeZ,
		groundHeight = Spring.GetGroundHeight,
		cardinalLock = Spring.GetConfigInt("CamSpringLockCardinalDirections", 1) == 1,
		springMinDistance = Spring.GetConfigFloat("CamSpringMinZoomDistance", 20),
		taMinHeight = Spring.GetConfigFloat("OverheadMinZoomDistance", 60),
		taMaxHeightFactor = Spring.GetConfigFloat("OverheadMaxHeightFactor", 1),
	}
	Spring.SetCameraState(CameraMath.StateFromPose(was.state.pose, was.saved, limits) or was.saved, 0)
	Spring.SetConfigInt(CLAMP_CONFIG, was.overlay.clampPos, true)
	if was.overlay.transitionMode and Spring.GetConfigInt(TRANSITION_CONFIG, 0) == 1 then
		Spring.SetConfigInt(TRANSITION_CONFIG, was.overlay.transitionMode, true)
	end
	Echo("[Cinematic Cam] off")
	return true
end

local function toggle()
	if on then
		return stop()
	end
	return start()
end

local function toggleHold()
	if not on then
		return false
	end
	Cam.setHold(on.state, on.state.hold == nil, Spring.GetGroundHeight)
	return true
end

local function level()
	if not on then
		return false
	end
	Cam.level(on.state)
	return true
end

local function home()
	if not on then
		return false
	end
	Cam.home(on.state, Spring.GetGroundHeight)
	return true
end

local function mapViews()
	local name = Game.mapName or "map"
	views[name] = views[name] or {}
	return views[name]
end

local function saveView(n)
	if not on then
		return false
	end
	mapViews()[n] = Cam.viewOf(on.state.target)
	Echo(string.format("[Cinematic Cam] view %d saved (%d flies back to it)", n, n))
	return true
end

local function goView(n)
	if not on then
		return false
	end
	local view = mapViews()[n]
	if not view then
		Echo(string.format("[Cinematic Cam] no view %d yet (Ctrl+%d saves one)", n, n))
		return false
	end
	local now = Spring.GetTimer()
	local again = on.lastView == n and on.lastViewAt ~= nil and Spring.DiffTimers(now, on.lastViewAt) < SNAP_SECONDS
	Cam.jump(on.state, view, again)
	on.lastView, on.lastViewAt = n, now
	return true
end

--- A photo of the view as it is, without the interface or the editor's overlays.
local function shoot()
	if shot or captureBusy() then
		return false
	end
	local map = tostring(Game.mapName or "map"):gsub("[^%w%-_ ]", "_")
	Spring.CreateDir(OUT_ROOT)
	shot = { path = OUT_ROOT .. map .. "_" .. os.date("%Y-%m-%d_%H-%M-%S") .. ".png", settle = SHOT_SETTLE_FRAMES }
	if not Spring.IsGUIHidden() then
		shot.hidGui = true
		Spring.SendCommands("hideinterface 1")
	end
	return true
end

function widget:DrawScreenEffects(vsx, vsy)
	local taking = shot
	if not taking then
		return
	end
	-- The hidden interface takes a frame to leave the picture.
	if taking.settle > 0 then
		taking.settle = taking.settle - 1
		return
	end
	shot = nil
	local ok, saved = pcall(gl.SaveImage, 0, 0, vsx, vsy, taking.path, { yflip = true, alpha = false })
	if taking.hidGui then
		Spring.SendCommands("hideinterface 0")
	end
	if ok and saved ~= false then
		status.lastPath, status.error = taking.path, ""
		Echo("[Cinematic Cam] photo saved: " .. taking.path)
	else
		status.lastPath, status.error = "", "could not write " .. taking.path
		Echo("[Cinematic Cam] " .. status.error)
	end
end

local guideBox, guideCache = { 0, 0 }, nil

local function rect(x0, y0, x1, y1)
	gl.Rect(math.floor(x0), math.floor(y0), math.floor(x1), math.floor(y1))
end

function widget:DrawScreen()
	if not (on and settings.guides) then
		return
	end
	local vsx, vsy = Spring.GetViewGeometry()
	if not (guideCache and guideBox[1] == vsx and guideBox[2] == vsy) then
		guideBox[1], guideBox[2] = vsx, vsy
		guideCache = Cam.guides(vsx, vsy, 0, 0)
	end
	gl.Color(1, 1, 1, 0.3)
	for _, l in ipairs(guideCache.lines) do
		if l[1] == l[3] then
			rect(l[1], l[2], l[1] + 1, l[4])
		else
			rect(l[1], l[2], l[3], l[2] + 1)
		end
	end
	local f = guideCache.frame
	gl.Color(1, 0.8, 0.25, 0.6)
	rect(f[1], f[2], f[3], f[2] + 2)
	rect(f[1], f[4] - 2, f[3], f[4])
	rect(f[1], f[2], f[1] + 2, f[4])
	rect(f[3] - 2, f[2], f[3], f[4])
	gl.Color(1, 1, 1, 1)
end

function widget:KeyPress(key, _mods, isRepeat, _label, _unicode, scanCode)
	if not on then
		return false
	end
	if on.scheme.keys[scanCode] then
		on.held[scanCode] = key
		on.codes[scanCode] = key
		return true
	end
	if isRepeat then
		return scanCode == LEVEL_SCAN or scanCode == HOME_SCAN or scanCode == SPACE_SCAN or VIEW_SCANS[scanCode] ~= nil
	end
	if scanCode == LEVEL_SCAN then
		return level()
	elseif scanCode == HOME_SCAN then
		return home()
	elseif scanCode == SPACE_SCAN then
		shoot()
		return true
	elseif key == ESCAPE_KEY then
		return stop()
	end
	local view = VIEW_SCANS[scanCode]
	if view then
		local _, ctrl = Spring.GetModKeyState()
		if ctrl then
			saveView(view)
		else
			goView(view)
		end
		return true
	end
	return false
end

function widget:KeyRelease(_key, _mods, _label, _unicode, scanCode)
	if on and on.held[scanCode] then
		on.held[scanCode] = nil
		return true
	end
	return false
end

--- The way the game camera's middle-drag goes: "invert mouse" and a pan speed above 0 each turn it.
local function gameMiddleTurn()
	local turn = Spring.GetConfigInt(MOUSE_CONFIG, 0) ~= 0 and -1 or 1
	return Spring.GetConfigFloat(MIDDLE_SPEED_CONFIG, -0.001) > 0 and -turn or turn
end

function widget:MousePress(_x, _y, button)
	if not on or not (button == 2 or button == 3) or captureBusy() then
		return false
	end
	on.pivot, on.panScale = nil, nil
	on.middleTurn = gameMiddleTurn()
	if button == 3 then
		on.drag = "look"
	elseif settings.middle == "pan" then
		on.drag = "pan"
		Cam.pivot(on.state, Spring.GetGroundHeight)
		local _, vsy = Spring.GetViewGeometry()
		on.panScale = Cam.panScale(on.state.pivotDistance, on.state.target.fov, vsy)
	else
		on.drag = "orbit"
		on.pivot = Cam.pivot(on.state, Spring.GetGroundHeight)
	end
	return true
end

function widget:MouseMove(_x, _y, dx, dy)
	if not (on and on.drag) then
		return
	end
	local _, ctrl = Spring.GetModKeyState()
	local turn = (settings.invertDrag and -1 or 1) * (on.middleTurn or 1)
	if on.drag == "pan" then
		Cam.pan(on.state, dx * turn, dy * turn, (on.panScale or 1) * (ctrl and Cam.SLOW or 1), Spring.GetGroundHeight)
	elseif on.drag == "orbit" then
		Cam.orbit(on.state, on.pivot, dx * turn, dy * turn, Spring.GetGroundHeight, ctrl)
	else
		local inverted = Spring.GetConfigInt(MOUSE_CONFIG, 0) ~= 0
		on.look.x, on.look.y = on.look.x + dx, on.look.y + (inverted and -dy or dy)
	end
end

function widget:MouseRelease()
	if on then
		on.drag, on.pivot, on.panScale = nil, nil, nil
	end
end

function widget:MouseWheel(up)
	if not on or captureBusy() then
		return false
	end
	local alt, ctrl, _, shift = Spring.GetModKeyState()
	local notches = Cam.wheelNotches(up, Spring.GetConfigInt(WHEEL_CONFIG, 25))
	if alt then
		Cam.lens(on.state, notches, ctrl)
	else
		Cam.dolly(on.state, notches, Spring.GetGroundHeight, shift, ctrl)
	end
	return true
end

local function input(live)
	local _, ctrl, _, shift = Spring.GetModKeyState()
	local lookX, lookY = live.look.x, -live.look.y
	live.look.x, live.look.y = 0, 0
	if live.drag then
		-- A drag holds the pointer and may hide key presses: read the fly keys straight.
		for scan, code in pairs(live.codes) do
			if not live.held[scan] and Spring.GetKeyState(code) then
				live.held[scan] = code
			end
		end
	else
		-- A release never heard (focus lost): the key is up.
		for scan, key in pairs(live.held) do
			if not Spring.GetKeyState(key) then
				live.held[scan] = nil
			end
		end
	end
	local out = Cam.keyMoves(live.scheme, live.held)
	out.fast, out.slow, out.lookX, out.lookY = shift, ctrl, lookX, lookY
	return out
end

function widget:Update(dt)
	local live = on
	if not live then
		return
	end
	-- The map capture flies the camera itself; pick up after it.
	if captureBusy() then
		return
	end
	Cam.step(live.state, live.fed or input(live), dt, Spring.GetGroundHeight)
	poseCamera()
end

local function cineCamAction()
	toggle()
	return true
end

function widget:Initialize()
	widgetHandler:AddAction("tfcinecam", cineCamAction, nil, "t")
	WG.TerraformCineCam = {
		isOn = function()
			return on ~= nil
		end,
		start = start,
		stop = stop,
		toggle = toggle,
		toggleHold = toggleHold,
		level = level,
		home = home,
		shoot = shoot,
		saveView = saveView,
		goView = goView,
		---@return TerraformCineCamSettings settings a copy
		getSettings = function()
			local copy = {}
			for k, v in pairs(settings) do
				copy[k] = v
			end
			return copy --[[@as TerraformCineCamSettings]]
		end,
		---@param key string
		---@param value string|number|boolean the kind the setting already holds
		---@return boolean set false for an unknown setting
		setSetting = function(key, value)
			if settings[key] == nil or type(settings[key]) ~= type(value) then
				return false
			end
			settings[key] = value
			applySettings()
			return true
		end,
		---The live numbers for a readout; nil while off.
		---@return { speed: integer, lens: integer, height: integer, hold: boolean, views: integer }?
		getReadout = function()
			if not on then
				return nil
			end
			local count = 0
			for _ in pairs(mapViews()) do
				count = count + 1
			end
			local read = Cam.readout(on.state.pose, Spring.GetGroundHeight)
			return {
				speed = math.floor(Cam.flySpeed(on.state) + 0.5),
				lens = read.lens,
				height = on.state.hold and math.floor(on.state.hold + 0.5) or read.height,
				hold = on.state.hold ~= nil,
				views = count,
			}
		end,
		---@return TerraformCineCamStatus status the live table; do not mutate
		getStatus = function()
			return status
		end,
		---Tests: input in place of the keys and the mouse, every frame until fed nil.
		feed = function(fed)
			if on then
				on.fed = fed
			end
		end,
		---The pose shown and its target, for tests; nil while off.
		debug = function()
			return on and { pose = on.state.pose, target = on.state.target, settled = Cam.settled(on.state) } or nil
		end,
	}
end

function widget:Shutdown()
	stop()
	if shot and shot.hidGui then
		Spring.SendCommands("hideinterface 0")
	end
	widgetHandler:RemoveAction("tfcinecam")
	WG.TerraformCineCam = nil
end

function widget:GetConfigData()
	return { settings = settings, views = views }
end

function widget:SetConfigData(data)
	if type(data) ~= "table" then
		return
	end
	if type(data.settings) == "table" then
		for k, v in pairs(data.settings) do
			if settings[k] ~= nil and type(settings[k]) == type(v) then
				settings[k] = v
			end
		end
	end
	if type(data.views) == "table" then
		views = data.views
	end
end
