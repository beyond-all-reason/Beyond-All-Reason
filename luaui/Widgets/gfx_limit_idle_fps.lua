
local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Limit idle FPS",
		desc = "Reduces FPS when being offscreen or idle (by setting vsync to a high number)" ,
		author = "Floris",
		date = "february 2020",
		license = "GNU GPL, v2 or later",
		layer = -999999,
		enabled = true
	}
end


-- Localized Spring API for performance
local spGetMouseState = Spring.GetMouseState
local spGetCameraPosition = Spring.GetCameraPosition

local offscreenDelay = 3
local idleDelay = Spring.GetConfigInt("LimitIdleFpsDelay", 60)
local vsyncValueActive = Spring.GetConfigInt("VSyncGame", -1) * Spring.GetConfigInt("VSyncFraction", 1)
local vsyncValueIdle = Spring.GetConfigInt("IdleFpsDivider", 4)    -- sometimes vsync > 4 doesnt work at all

local limitFpsWhenIdle = Spring.GetConfigInt("LimitIdleFps", 0) == 1

local restrictFps = false
local lastUserInputTime = os.clock()
local lastMouseX, lastMouseY = spGetMouseState()
local prevCamX, prevCamY, prevCamZ = spGetCameraPosition()
local lastMouseOffScreen = false
local chobbyInterface = false


function widget:Shutdown()
	Spring.SetConfigInt("VSync", vsyncValueActive)
	WG['limitidlefps'] = nil
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
		lastUserInputTime = os.clock()
		if chobbyInterface then
			restrictFps = false
			Spring.SetConfigInt("VSync", (restrictFps and vsyncValueIdle or vsyncValueActive))
		end
	end
end

function widget:Initialize()
	WG['limitidlefps'] = {}
	WG['limitidlefps'].restrictFps = function()
		return restrictFps
	end
	WG['limitidlefps'].update = function()
		lastUserInputTime = os.clock()
	end
end

local sec = 0
function widget:Update(dt)
	sec = sec + dt
	if sec > 2 then
		sec = 0
		vsyncValueActive = Spring.GetConfigInt("VSyncGame", -1) * Spring.GetConfigInt("VSyncFraction", 1)
		limitFpsWhenIdle = Spring.GetConfigInt("LimitIdleFps", 0) == 1
		idleDelay = Spring.GetConfigInt("LimitIdleFpsDelay", 40)
	end
	-- detect change by user
	local curVsync = Spring.GetConfigInt("VSync",1)
	if curVsync ~= vsyncValueIdle and curVsync ~= vsyncValueActive then
		vsyncValueActive = curVsync
	end

	if not chobbyInterface then
		local prevRestrictFps = restrictFps
		local mouseX, mouseY, lmb, mmb, rmb, mouseOffScreen, cameraPanMode  = spGetMouseState()
		if mouseX ~= lastMouseX or mouseY ~= lastMouseY or lmb or mmb or rmb  then
			lastMouseX, lastMouseY = mouseX, mouseY
			lastUserInputTime = os.clock()
		end

		local camX, camY, camZ = spGetCameraPosition()
		if camX ~= prevCamX or  camY ~= prevCamY or  camZ ~= prevCamZ  then
			prevCamX, prevCamY, prevCamZ = camX, camY, camZ
			lastUserInputTime = os.clock()
		end
		if cameraPanMode then	-- when camera panning
			lastUserInputTime = os.clock()
		end
		if lastMouseOffScreen ~= mouseOffScreen then
			lastUserInputTime = os.clock() - idleDelay-0.01+offscreenDelay
		end
		lastMouseOffScreen = mouseOffScreen
		if (limitFpsWhenIdle or mouseOffScreen) and lastUserInputTime < os.clock() - idleDelay then
			restrictFps = true
		else
			restrictFps = false
		end
		if restrictFps ~= prevRestrictFps then
			Spring.SetConfigInt("VSync", (restrictFps and vsyncValueIdle or vsyncValueActive))
		end
	end
end

function widget:MousePress()
	lastUserInputTime = os.clock()
end

function widget:MouseWheel()
	lastUserInputTime = os.clock()
end

function widget:KeyPress()
	lastUserInputTime = os.clock()
end

function widget:TextInput(char)	-- seems not being triggered when actual chat input so chat widget will do WG['limitidlefps'].update()
	lastUserInputTime = os.clock()
end
