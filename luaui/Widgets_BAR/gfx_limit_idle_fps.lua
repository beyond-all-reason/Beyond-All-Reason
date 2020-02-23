
function widget:GetInfo()
	return {
		name = "Limit idle FPS",
		desc = "Reduces FPS when being idle (by setting vsync to a high number)" ,
		author = "Floris",
		date = "february 2020",
		license = "",
		layer = 0,
		enabled = false
	}
end

local idleTime = 6
local vsyncValueActive = 1		--Spring.GetConfigInt("VSync",1)
local vsyncValueIdle = 6

local isIdle = false
local lastUserInputTime = os.clock()
local lastMouseX, lastMouseY = Spring.GetMouseState()
local prevCamX, prevCamY, prevCamZ = Spring.GetCameraPosition()
local chobbyInterface = false

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
		lastUserInputTime = os.clock()
		if chobbyInterface then
			isIdle = false
			Spring.SetConfigInt("VSync", (isIdle and vsyncValueIdle or vsyncValueActive))
		end
	end
end

function widget:Update()
	if not chobbyInterface then
		local prevIsIdle = isIdle

		local mouseX, mouseY = Spring.GetMouseState()
		if mouseX ~= lastMouseX or mouseY ~= lastMouseY then
			lastMouseX, lastMouseY = mouseX, mouseY
			lastUserInputTime = os.clock()
		end

		local camX, camY, camZ = Spring.GetCameraPosition()
		if camX ~= prevCamX or  camY ~= prevCamY or  camZ ~= prevCamZ  then
			prevCamX, prevCamY, prevCamZ = camX, camY, camZ
			lastUserInputTime = os.clock()
		end

		if lastUserInputTime < os.clock() - idleTime then
			isIdle = true
		else
			isIdle = false
		end
		if isIdle ~= prevIsIdle then
			Spring.SetConfigInt("VSync", (isIdle and vsyncValueIdle or vsyncValueActive))
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