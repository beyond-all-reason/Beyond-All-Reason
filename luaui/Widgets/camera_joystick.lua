local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name			= "Camera Joystick",
		desc			= "Control Rotateable overhead (CTRL+F4) camera with a joystick via joystick server from https://github.com/Beherith/camera_joystick_springrts",
		author		= "Beherith",
		date			= "2021.04.06",
		license   = "GNU GPL, v2 or later",
		layer		 = 1,		 --	after the normal widgets
		enabled	 = false
	}
end
---------------------INFO------------------------
-- 1. Start your joystick server: https://github.com/Beherith/camera_joystick_springrts
-- 2. Set your controller type with /luaui joystick

-- https://www.pygame.org/docs/ref/joystick.html
-- Use AntiMicro to configure commands for OBS, and to get button/axis numbers in 1-based Lua form:
-- https://github.com/AntiMicro/antimicro/releases/tag/2.23
--   Y
-- X   B
--   A

-- A button pause
-- B button hide interface
-- X toggle los
-- Y debug, bound via antimicro to F9 (obs start recording button)
-- See default bindings as they are for xbox

local LeftXAxis 		= {'axes',1,1} -- move left-right
local LeftYAxis 		= {'axes',2,1} -- move forward-backward
local RightXAxis 		= {'axes',3,1} --turn left-right
local RightYAxis 		= {'axes',4,1} --turn up-down
local RightTrigger 		= {'axes',6,1} -- move up
local LeftTrigger 		= {'axes',5, 1} --move down
local DpadUp 			= {'hats',1,1} -- increase speed
local DpadDown 			= {'hats',1,-1} -- decrease speed
local DpadRight 		= {'hats',2,1} -- increase smoothing
local DpadLeft 			= {'hats',2,-1} -- decrease smoothing
local Abutton 			= {'buttons',1,1} -- cross button, pause game
local Bbutton 			= {'buttons',2,1} -- circle button, hide interface
local Xbutton 			= {'buttons',3,1} -- square button, toggle los
local Ybutton 			= {'buttons',4,1} -- triangle button, print joystick status
local LShoulderbutton 	= {'buttons',5,1} -- decrease game speed
local RShoulderbutton 	= {'buttons',6,1} -- increase game speed
local StartButton 		= {'buttons',7,1}
local SelectButton 		= {'buttons',8,1}
local RStickButton 		= {'buttons',10,1} -- select unit nearest to center of screen? TODO
local LStickButton 		= {'buttons',9,1} -- delect all? TODO
local DeadZone 			= 0.10

---------------------Xiaomi Wireless----------------------------------------
local function XiaomiWireless()
	-- Each input is a table of {'axes'|'buttons'|'hats', index (lua 1-based), direction (1 | -1)}
	LeftXAxis = {'axes',1,1} -- move left-right
	LeftYAxis = {'axes',2,1} -- move forward-backward
	RightXAxis = {'axes',3,1} --turn left-right
	RightYAxis = {'axes',6,1} --turn up-down
	RightTrigger = {'axes',8,1} -- move up
	LeftTrigger = {'buttons',9, 1} --move down
	DpadUp = {'hats',1,1} -- increase speed
	DpadDown = {'hats',1,-1} -- decrease speed
	DpadRight = {'hats',2,1} -- increase smoothing
	DpadLeft = {'hats',2,-1} -- decrease smoothing
	Abutton = {'buttons',1,1} -- pause game
	Bbutton = {'buttons',2,1} -- hide interface
	Xbutton = {'buttons',4,1} -- toggle los
	Ybutton = {'buttons',5,1} -- print joystick status
	LShoulderbutton = {'buttons',7,1} -- decrease game speed
	RShoulderbutton = {'buttons',8,1} -- increase game speed
	StartButton = {'buttons',10,1}
	SelectButton = {'buttons',11,1}
	RStickButton = {'buttons',14,1} -- select unit nearest to center of screen? TODO
	LStickButton = {'buttons',15,1} -- delect all? TODO
	DeadZone = 0
end
--XiaomiWireless()

---------------------X-Box 360 Controller ----------------------------------------
local function XBox360()
	-- Each input is a table of {'axes'|'buttons'|'hats', index (lua 1-based), direction (1 | -1)}
	LeftXAxis = {'axes',1,1} -- move left-right
	LeftYAxis = {'axes',2,1} -- move forward-backward
	RightXAxis = {'axes',3,1} --turn left-right
	RightYAxis = {'axes',4,1} --turn up-down
	RightTrigger = {'axes',6,1} -- move up
	LeftTrigger = {'axes',5, 1} --move down
	DpadUp = {'hats',1,1} -- increase speed
	DpadDown = {'hats',1,-1} -- decrease speed
	DpadRight = {'hats',2,1} -- increase smoothing
	DpadLeft = {'hats',2,-1} -- decrease smoothing
	Abutton = {'buttons',1,1} -- pause game
	Bbutton = {'buttons',2,1} -- hide interface
	Xbutton = {'buttons',3,1} -- toggle los
	Ybutton = {'buttons',4,1} -- print joystick status
	LShoulderbutton = {'buttons',5,1} -- decrease game speed
	RShoulderbutton = {'buttons',6,1} -- increase game speed
	StartButton = {'buttons',7,1}
	SelectButton = {'buttons',8,1}
	RStickButton = {'buttons',10,1} -- select unit nearest to center of screen? TODO
	LStickButton = {'buttons',9,1} -- delect all? TODO
	DeadZone = 0.05
end

---------------------X-Box Series S Controller ----------------------------------------
local function XBoxSeriesS()
-- Each input is a table of {'axes'|'buttons'|'hats', index (lua 1-based), direction (1 | -1)}
	LeftXAxis = {'axes',1,1} -- move left-right
	LeftYAxis = {'axes',2,1} -- move forward-backward
	RightXAxis = {'axes',3,1} --turn left-right
	RightYAxis = {'axes',4,1} --turn up-down
	RightTrigger = {'axes',6,1} -- move up
	LeftTrigger = {'axes',5, 1} --move down
	DpadUp = {'hats',1,1} -- increase speed
	DpadDown = {'hats',1,-1} -- decrease speed
	DpadRight = {'hats',2,1} -- increase smoothing
	DpadLeft = {'hats',2,-1} -- decrease smoothing
	Abutton = {'buttons',1,1} -- pause game
	Bbutton = {'buttons',2,1} -- hide interface
	Xbutton = {'buttons',3,1} -- toggle los
	Ybutton = {'buttons',4,1} -- print joystick status
	LShoulderbutton = {'buttons',5,1} -- decrease game speed
	RShoulderbutton = {'buttons',6,1} -- increase game speed
	StartButton = {'buttons',7,1}
	SelectButton = {'buttons',8,1}
	RStickButton = {'buttons',10,1} -- select unit nearest to center of screen? TODO
	LStickButton = {'buttons',9,1} -- delect all? TODO
	DeadZone = 0.10
end


---------------------Playstation 4 Controller ---------------------------------------
local function PS4()
-- Each input is a table of {'axes'|'buttons'|'hats', index (lua 1-based), direction (1 | -1)}
	LeftXAxis = {'axes',1,1} -- move left-right
	LeftYAxis = {'axes',2,1} -- move forward-backward
	RightXAxis = {'axes',3,1} --turn left-right
	RightYAxis = {'axes',4,1} --turn up-down
	RightTrigger = {'axes',6,1} -- move up
	LeftTrigger = {'axes',5, 1} --move down
	DpadUp = {'buttons',12,1} -- increase speed
	DpadDown = {'buttons',13,1} -- decrease speed
	DpadRight = {'buttons',15,1} -- increase smoothing
	DpadLeft = {'buttons',14,1} -- decrease smoothing
	Abutton = {'buttons',1,1} -- cross button, pause game
	Bbutton = {'buttons',2,1} -- circle button, hide interface
	Xbutton = {'buttons',3,1} -- square button, toggle los
	Ybutton = {'buttons',4,1} -- triangle button, print joystick status
	LShoulderbutton = {'buttons',10,1} -- decrease game speed
	RShoulderbutton = {'buttons',11,1} -- increase game speed
	StartButton = {'buttons',6,1}
	SelectButton = {'buttons',7,1}
	RStickButton = {'buttons',9,1} -- select unit nearest to center of screen? TODO
	LStickButton = {'buttons',8,1} -- delect all? TODO
	DeadZone = 0.10
end


----------------------------------- Playstation 3 Controller -----------------------------------------
local function PS3()
	----Combined with ScpToolikit https://www.lifewire.com/how-to-connect-ps3-controller-to-pc-4589297----
	-- Each input is a table of {'axes'|'buttons'|'hats', index (lua 1-based), direction (1 | -1)}
	LeftXAxis = {'axes',1,1} -- move left-right
	LeftYAxis = {'axes',2,1} -- move forward-backward
	RightXAxis = {'axes',3,1} --turn left-right
	RightYAxis = {'axes',4,1} --turn up-down
	RightTrigger = {'axes',6,1} -- move up
	LeftTrigger = {'axes',5, 1} --move down
	DpadUp = {'hats',1,1} -- increase speed
	DpadDown = {'hats',1,-1} -- decrease speed
	DpadRight = {'hats',2,1} -- increase smoothing
	DpadLeft = {'hats',2,-1} -- decrease smoothing
	Abutton = {'buttons',1,1} -- cross button, pause game
	Bbutton = {'buttons',2,1} -- circle button, hide interface
	Xbutton = {'buttons',3,1} -- square button, toggle los
	Ybutton = {'buttons',4,1} -- triangle button, print joystick status
	LShoulderbutton = {'buttons',5,1} -- decrease game speed
	RShoulderbutton = {'buttons',6,1} -- increase game speed
	RStickButton = {'buttons',10,1} -- Toggle maximum minimap
	LStickButton = {'buttons',9,1} -- Toggle defense ranges GL4
	SelectButton = {'buttons',7,1} -- specfullview
	StartButton = {'buttons',8,1} -- DOF toggle
	DeadZone = 0.01
end

local function toggleRecording() end
local function togglePlayback() end

------------- BIND COMMANDS TO BUTTONS DEBOUNCED! -------------------------------
local buttonCommands = { -- key is button number, value is command like you would type into console without the beginning /
	[Abutton[2]] = function() Spring.SendCommands("pause") end,
	[Bbutton[2]] = function() Spring.SendCommands("hideinterface") end,
	[Xbutton[2]] = function() Spring.SendCommands("togglelos") end,
	[LShoulderbutton[2]] = function() Spring.SendCommands("slowdown") end,
	[RShoulderbutton[2]] = function() Spring.SendCommands("speedup") end,
	--[RStickButton[2]] = function() Spring.SendCommands("MiniMap Maximize") end,
	--[LStickButton[2]] = function() Spring.SendCommands("luaui togglewidget Defense Range GL4") end,
	--[SelectButton[2]] = function() Spring.SendCommands("SpecFullView") end,
	--[StartButton[2]] = function() Spring.SendCommands("option dof") end,
	[SelectButton[2]] = function() toggleRecording() end,
	[StartButton[2]] = function() togglePlayback() end,
}


--------------------------------------------------------------------------------
local spGetCameraState	 = Spring.GetCameraState
local spSetCameraState	 = Spring.SetCameraState

--------------------------------------------------------------------------------
local host = "127.0.0.1"
local port = "51234"
local client
local set
local mincameraheight = 32 -- min camera Y in elmos
local movemult = 3.0 -- move speed multiplier
local rotmult = 0.2	-- rotation speed multiplier
local movechangefactor = 1.01
local smoothchangefactor = 0.01
local joystate = {}
local smoothing = 0.97	--amount of smoothing
local analogexponent = 1.4 -- amount of analog stick exponentiation
local debugMode = false

local isrecording = false
local isplayingback = false
local playbackpos = 1
local storedCameraSequence = {}
local joystickCamFile = "Joystick_Camera_Recordings.lua"

local function strtable(t)
	local res = '{'
	for k,v in pairs(t) do
		--if k == 'oldHeight' or k == 'name' or k == 'mode' then
			-- dont save these
		--else
			res = res .. tostring(k) .. '=' .. tostring(v) ..', '
		--end
	end
	return res .. '}'
end

local function SaveRecording()
	local jcf = io.open(joystickCamFile,'a')
	jcf:write(string.format("local recordingID_%s = {\n",tostring(os.date("%Y%m%d_%H%M%S"))))
	for i=1, #storedCameraSequence do
		jcf:write(string.format("    [%d] = %s ,\n", i, strtable(storedCameraSequence[i])))
	end
	jcf:write(string.format("}\n"))
	jcf:close()
end

toggleRecording = function ()
	if isplayingback then
		Spring.Echo("Cant start playback while recording")
		return
	end
	isrecording = not isrecording
	Spring.Echo("Camera joystick recording toggled to", isrecording)
	if isrecording then
		storedCameraSequence = {}
	else
		SaveRecording()
	end
end

togglePlayback = function()
	if isrecording then
		Spring.Echo("Cant start playback while recording")
		return
	end
	isplayingback = not isplayingback
	Spring.Echo("Camera joystick playback toggled to", isrecording)

	if isplayingback then
		playbackpos = 1
	end
end
--------------------------------------------------------------------------------

local function dumpConfig()
	-- dump all luasocket related config settings to console
	for _, conf in ipairs({"TCPAllowConnect", "TCPAllowListen", "UDPAllowConnect", "UDPAllowListen"	}) do
		Spring.Echo(conf .. " = " .. Spring.GetConfigString(conf, ""))
	end
end

local function newset()
	local reverse = {}
	local set = {}
	return setmetatable(set, {__index = {
		insert = function(set, value)
			if not reverse[value] then
				table.insert(set, value)
				reverse[value] = table.getn(set)
			end
		end,
		remove = function(set, value)
			local index = reverse[value]
			if index then
				reverse[value] = nil
				local top = table.remove(set)
				if top ~= value then
					reverse[top] = index
					set[index] = top
				end
			end
		end
	}})
end

local function SocketConnect(host, port)
	client=socket.tcp()
	client:settimeout(0)
	res, err = client:connect(host, port)
	if not res and err ~= "timeout" then
		client:close()
		Spring.Echo("Unable to connect to joystick server: ",res, err, "Restart widget after server is started")
		return false
	end
	set = newset()
	set:insert(client)

	Spring.Echo("Connected to joystick server", res, err)
	return true
end

function widget:TextCommand(command)
	if string.find(command, "joystick", nil, true) then
		command = string.lower(command)
		if string.find(command, "ps3", nil, true) then
			Spring.Echo("Enabling PS3 controller layout")
			PS3()
		elseif string.find(command, "ps4",nil, true) then
			Spring.Echo("Enabling PS4 controller layout")
			PS4()
		elseif string.find(command, "xbox", nil, true) then
			Spring.Echo("Enabling XBox Series S controller layout")
			XBoxSeriesS()
		elseif string.find(command, "xbox360", nil, true) then
			Spring.Echo("Enabling XBox 360 controller layout")
			XBox360()
		elseif string.find(command, "xiaomi", nil, true) then
			Spring.Echo("Enabling Xiaomi wireless controller layout")
			XiaomiWireless()
		else
			Spring.Echo("Could not find a matching controller type for command", command)
		end
		return true
	end
	return false
end

function widget:Initialize()
	Spring.SendCommands({"set SmoothTimeOffset 2"})
	Spring.Echo("Started Camera Joystick, make sure you are running the joystick server, and switch camera to Ctrl+F4")
	if debugMode then dumpConfig() end
	local connected = SocketConnect(host, port)
	if connected then
		Spring.SetConfigInt("RotOverheadClampMap",0)
	else
		widgetHandler:RemoveWidget()
	end
end

local function joystatetostr(js)
	local jstr = "buttons = ["
	for i,n in ipairs(js.buttons) do
		jstr = jstr .. " " .. tostring(n)
	end
	jstr = jstr .. '] hats = ['
	for i, n in ipairs(js.hats) do
		jstr = jstr .. " "..tostring(n)
	end
	jstr = jstr .. '] axes = ['
	for i, n in ipairs(js.axes) do
		jstr = jstr .. string.format(" %.2f",n)
	end
	return jstr .. ']'
end
local Json = Json or VFS.Include('common/luaUtilities/json.lua')

local buttonorder = { LeftXAxis, LeftYAxis, RightXAxis, RightYAxis, RightTrigger, LeftTrigger, DpadUp, DpadDown, DpadRight, DpadLeft, Abutton, Bbutton, Xbutton,Ybutton, LShoulderbutton ,RShoulderbutton, RStickButton , LStickButton }
local function SocketDataReceived(sock, str)
	--Spring.Echo(str)

	local newjoystate = Json.decode(str)

	if joystate.axes == nil then
		joystate = newjoystate
	-- validate all defined controls:
	for i, but in ipairs(buttonorder) do
		if but and joystate[but[1]][but[2]] == nil then
			Spring.Echo(joystatetostr(joystate))
			Spring.Echo("Warning: control missing:",but[1],but[2])
		end
	end

	else
		for i,a in ipairs(newjoystate.axes) do
			if DeadZone and math.abs(newjoystate.axes[i] ) < DeadZone then
				newjoystate.axes[i] = 0
				a = 0
			end
			joystate.axes[i] = smoothing*joystate.axes[i] + (1-smoothing) * a
		end
	if joystate.hats then
		joystate.hats = newjoystate.hats
	else
		joystate.hats = {}
	end
		for btnindex, cmd in pairs(buttonCommands) do
			if joystate.buttons[btnindex] then
				if joystate.buttons[btnindex] == 0 and newjoystate.buttons[btnindex] == 1 then
					Spring.Echo("Button",btnindex,"pressed, sending command")
					cmd()
				end
			end
		end
		joystate.buttons = newjoystate.buttons
	end
end

local function SocketClosed(sock)
	Spring.Echo("Camera Joystick: closed connection")
end

local matrix = {}
matrix[0],matrix[1],matrix[2] = {},{},{};

local function rotateVector(vector,axis,phi)
	local rcos = math.cos(math.pi*phi/180);
	local rsin = math.sin(math.pi*phi/180);
	local u,v,w = axis[1],axis[2],axis[3];


	matrix[0][0] =		rcos + u*u*(1-rcos);
	matrix[1][0] =	w * rsin + v*u*(1-rcos);
	matrix[2][0] = -v * rsin + w*u*(1-rcos);
	matrix[0][1] = -w * rsin + u*v*(1-rcos);
	matrix[1][1] =		rcos + v*v*(1-rcos);
	matrix[2][1] =	u * rsin + w*v*(1-rcos);
	matrix[0][2] =	v * rsin + u*w*(1-rcos);
	matrix[1][2] = -u * rsin + v*w*(1-rcos);
	matrix[2][2] =		rcos + w*w*(1-rcos);

	local x,y,z = vector[1],vector[2],vector[3];

	return x * matrix[0][0] + y * matrix[0][1] + z * matrix[0][2],
	x * matrix[1][0] + y * matrix[1][1] + z * matrix[1][2],
	x * matrix[2][0] + y * matrix[2][1] + z * matrix[2][2];
end

local function norm2d(x,y)
	local l = math.sqrt(x*x+y*y)
	return x/l, y/l
end

local function axesexponent(axin)
	if axin >= 0 then
		return math.pow(axin, analogexponent)
	else
		return -1* math.pow(-1*axin, analogexponent)
	end
end

local frameSpeed = 1.0 -- this tries to work around fps dips

function widget:Update(dt) -- dt in seconds
	if isplayingback then
		playbackpos = playbackpos + 1
		if playbackpos <= #storedCameraSequence then
			spSetCameraState(storedCameraSequence[playbackpos])
		else
			playbackpos = 1
			isplayingback = false
		end
	end

	if set==nil or #set<=0 then
		return
	end
	-- get sockets ready for read
	local readable, writeable, err = socket.select(set, set, 0)
	if err~=nil then
		-- some error happened in select
		if err=="timeout" then
			-- nothing to do, return
			return
		end
		Spring.Echo("Error in select: " .. error)
	end
	for _, input in ipairs(readable) do
		local s, status, partial = input:receive('*a') --try to read all data
		if status == "timeout" or status == nil then
			SocketDataReceived(input, s or partial)
		elseif status == "closed" then
			SocketClosed(input)
			input:close()
			set:remove(input)
		end
	end

	if isplayingback then return end

	local cs = spGetCameraState()

	if cs.name == "rot" and joystate.axes then
		if joystate[Ybutton[1]][Ybutton[2]] and joystate[Ybutton[1]][Ybutton[2]] == 1 then -- A button dumps debug
			Spring.Echo(joystatetostr(joystate))
		end

		if joystate[DpadUp[1]][DpadUp[2]] and joystate[DpadUp[1]][DpadUp[2]] == DpadUp[3] then
			movemult = movemult * movechangefactor
			rotmult = rotmult * movechangefactor
			Spring.Echo("Speed increased to ",movemult)
		end

		if joystate[DpadDown[1]][DpadDown[2]] and joystate[DpadDown[1]][DpadDown[2]] == DpadDown[3] then
			movemult = movemult / movechangefactor
			rotmult = rotmult / movechangefactor
			Spring.Echo("Speed decreased to ",movemult)
		end

		if joystate[DpadRight[1]][DpadRight[2]] and joystate[DpadRight[1]][DpadRight[2]] == DpadRight[3] then
			smoothing = smoothchangefactor * 1.0 + (1.0 - smoothchangefactor ) * smoothing
			Spring.Echo("Smoothing increased to ",smoothing)
		end

		if joystate[DpadLeft[1]][DpadLeft[2]] and joystate[DpadLeft[1]][DpadLeft[2]] == DpadLeft[3] then
			smoothing = (1.0 - smoothchangefactor ) * smoothing
			Spring.Echo("Smoothing decreased to ",smoothing)
		end

		if (dt>0)	and (dt < 1.0/75 or dt > 1.0/45) then -- correct for <45 fps and >75fps as there is some jitter in frames
			--frameSpeed = 60* dt
			--frameSpeed = 1 * 0.9 + 60 * dt * 0.1 -- some exponential smoothing
			frameSpeed = 1 -- no smoothing

			if debugMode then Spring.Echo("speed correction",dt,frameSpeed) end
		end
		local ndx, ndz = norm2d(cs.dx, cs.dz)

		if debugMode and Spring.GetGameFrame() %60 ==0 then
			Spring.Echo(ndx, ndz, cs.dx, cs.dy, cs.dz)
		end

			-- Move left-right
		if joystate[LeftXAxis[1]][LeftXAxis[2]] then
			local lrmove = axesexponent(joystate[LeftXAxis[1]][LeftXAxis[2]])
			cs.px = cs.px + -1*(ndz * lrmove) * movemult * frameSpeed -- good
			cs.pz = cs.pz + (ndx * lrmove) * movemult * frameSpeed
		end

			-- Move forward-backward
		if joystate[LeftYAxis[1]][LeftYAxis[2]] then
			local fbmove = axesexponent(joystate[LeftYAxis[1]][LeftYAxis[2]])
			cs.px = cs.px + -1*(ndx * fbmove) * movemult * frameSpeed
			cs.pz = cs.pz + -1*(ndz * fbmove) * movemult * frameSpeed
		end

			-- Turn left-right
		if joystate[RightXAxis[1]][RightXAxis[2]] then
			local lrturn = axesexponent(joystate[RightXAxis[1]][RightXAxis[2]])
			local rotYx, rotYy, rotYz = rotateVector({cs.dx, cs.dy, cs.dz}, {0,1,0} , -1.0*	lrturn * rotmult * frameSpeed)
			cs.dx = rotYx
			cs.dy = rotYy
			cs.dz = rotYz
		end
			-- Turn up-down
		if joystate[RightYAxis[1]][RightYAxis[2]] then
			local turnupdown = axesexponent(joystate[RightYAxis[1]][RightYAxis[2]])
			if not((cs.dy < -0.98 and turnupdown >= 0) or (cs.dy > 0.98 and turnupdown <= 0) )	then -- gimbal lock prevention
				local rotUpx, rotUpy, rotUpz = rotateVector({cs.dx, cs.dy, cs.dz}, {ndz,0,-ndx} , turnupdown * rotmult * frameSpeed)
				cs.dx = rotUpx
				cs.dy = rotUpy
				cs.dz = rotUpz
			end
		end

			-- Move up-down
		if joystate[RightTrigger[1]][RightTrigger[2]] and joystate[LeftTrigger[1]][LeftTrigger[2]] then
			cs.py = cs.py - (1.0 + joystate[RightTrigger[1]][RightTrigger[2]]) * movemult/2 * frameSpeed
			if LeftTrigger[1] == 'axes' then
				cs.py = cs.py + (1.0 + joystate[LeftTrigger[1]][LeftTrigger[2]]) * movemult/2 * frameSpeed
			else --probably a button
				cs.py = cs.py + joystate[LeftTrigger[1]][LeftTrigger[2]] * movemult * frameSpeed
				if joystate[LeftTrigger[1]][LeftTrigger[2]] == LeftTrigger[3] then
					joystate[RightTrigger[1]][RightTrigger[2]] = -1
				end
			end
		end

		-- Prevent the camera from going too low
		local gh = Spring.GetGroundHeight(cs.px,cs.pz)
		cs.py = math.max(mincameraheight, math.max(cs.py , gh + 32))
		--if cs.py < gh + 32 then cs.py =gh + 32 end

		spSetCameraState(cs,0)
		spSetCameraState(cs,0)
		spSetCameraState(cs,0)
		if isrecording then
			storedCameraSequence[#storedCameraSequence + 1] = cs
		end
	end

end

--------------------------------------------------------------------------------

--[[
	Switching to Rotatable overhead camera
name : "rot"
[t=00:13:23.057932][f=0022976] TableEcho = {
[t=00:13:23.057932][f=0022976]		 px = 839.141724
[t=00:13:23.057932][f=0022976]		 py = 1498.34656
[t=00:13:23.057932][f=0022976]		 pz = 4248.28955
[t=00:13:23.057932][f=0022976]		 dx = 0.10883047
[t=00:13:23.057932][f=0022976]		 dy = -0.9101192
[t=00:13:23.057932][f=0022976]		 name = rot
[t=00:13:23.057932][f=0022976]		 fov = 45
[t=00:13:23.057932][f=0022976]		 mode = 3
[t=00:13:23.057932][f=0022976]		 dz = -0.3997985
[t=00:13:23.057932][f=0022976]		 oldHeight = 1155.58826
[t=00:13:23.057932][f=0022976] },
	]]--
