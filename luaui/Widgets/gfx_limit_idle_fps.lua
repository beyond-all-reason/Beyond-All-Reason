
function widget:GetInfo()
	return {
		name = "Limit idle FPS",
		desc = "Reduces FPS when being offscreen or idle (by setting vsync to a high number)" ,
		author = "Floris",
		date = "february 2020",
		license = "",
		layer = -99999999999,
		enabled = true
	}
end

local offscreenDelay = 3
local idleTime = 60
local vsyncValueActive = Spring.GetConfigInt("VSyncGame", 0)
local vsyncValueIdle = Spring.GetConfigInt("IdleFpsDivider", 4)    -- sometimes vsync > 4 doesnt work at all

local isIdle = false
local lastUserInputTime = os.clock()
local lastMouseX, lastMouseY = Spring.GetMouseState()
local prevCamX, prevCamY, prevCamZ = Spring.GetCameraPosition()
local lastMouseOffScreen = false
local chobbyInterface = false

-- disabled code below because it did work on my separate 144hz monitor, not on my laptop 144hz monitor somehow (then 6 results in more fps than even 4)
--
-- detect display frequency > 60 and set vsyncValueIdle to 6
--local infolog = VFS.LoadFile("infolog.txt")
--if infolog then
--
--	-- store changelog into table
--	local fileLines = string.lines(infolog)
--
--	for i, line in ipairs(fileLines) do
--		if string.sub(line, 1, 3) == '[F='  then
--			break
--		end
--
--		if line:find('(display%-mode set to )') then
--			local s_displaymode = line:sub( line:find('(display%-mode set to )') + 20)
--			if s_displaymode:find('%@') then
--				local frequency = s_displaymode:sub(s_displaymode:find('%@')+1, s_displaymode:find('Hz ')-1)
--				if tonumber(frequency) > 60 then
--					vsyncValueIdle = 6
--				end
--			end
--		end
--	end
--end


function widget:Shutdown()
	Spring.SetConfigInt("VSync", vsyncValueActive)
	WG['limitidlefps'] = nil
end

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

function widget:Initialize()
	WG['limitidlefps'] = {}
	WG['limitidlefps'].isIdle = function()
		return isIdle
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
		vsyncValueActive = Spring.GetConfigInt("VSyncGame", 0)
	end
	-- detect change by user
	local curVsync = Spring.GetConfigInt("VSync",1)
	if curVsync ~= vsyncValueIdle and curVsync ~= vsyncValueActive then
		vsyncValueActive = curVsync
	end

	if not chobbyInterface then
		local prevIsIdle = isIdle
		local mouseX, mouseY, lmb, mmb, rmb, mouseOffScreen, cameraPanMode  = Spring.GetMouseState()
		if mouseX ~= lastMouseX or mouseY ~= lastMouseY or lmb or mmb or rmb  then
			lastMouseX, lastMouseY = mouseX, mouseY
			lastUserInputTime = os.clock()
		end

		local camX, camY, camZ = Spring.GetCameraPosition()
		if camX ~= prevCamX or  camY ~= prevCamY or  camZ ~= prevCamZ  then
			prevCamX, prevCamY, prevCamZ = camX, camY, camZ
			lastUserInputTime = os.clock()
		end
		if cameraPanMode then	-- when camera panning
			lastUserInputTime = os.clock()
		end
		if lastMouseOffScreen ~= mouseOffScreen then
			lastUserInputTime = os.clock() - idleTime-0.01+offscreenDelay
		end
		lastMouseOffScreen = mouseOffScreen
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

function widget:TextInput(char)	-- seems not being triggered when actual chat input so chat widget will do WG['limitidlefps'].update()
	lastUserInputTime = os.clock()
end
