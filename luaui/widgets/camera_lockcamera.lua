local versionNumber = "v2.91"

function widget:GetInfo()
	return {
		name = "LockCamera",
		desc = versionNumber .. " Allows you to lock your camera to another player's camera.\n"
				.. "/luaui lockcamera_interval to set broadcast interval (minimum 0.25 s).",
		author = "Evil4Zerggin",
		date = "16 January 2009",
		license = "GNU LGPL, v2.1 or later",
		layer = -5,
		enabled = true
	}
end

------------------------------------------------
--debug
------------------------------------------------
local totalCharsSent = 0
local totalCharsRecv = 0

------------------------------------------------
--config
------------------------------------------------

--recieve
local transitionTime = 1.5 --how long it takes the camera to move
local listTime = 30 --how long back to look for recent broadcasters

--GUI
local show
local mainSize = 16
--relative to mainSize
local textSize = 0.75
local textMargin = 0.125
local lineWidth = 0.0625
--position
local posX, posY = 0.2, 0

function widget:GetConfigData(data)
	return {
		posX = posX,
		posY = posY,
	}
end

function widget:SetConfigData(data)
	posX = data.posX or posX
	posY = data.posY or posY
end

------------------------------------------------
--vars
------------------------------------------------
local myPlayerID = Spring.GetMyPlayerID()
local lockPlayerID
--playerID = {time, state}
local lastBroadcasts = {}
local recentBroadcasters = {}
local newBroadcaster = false
local totalTime = 0

local showList, titleList

local activeClick
local isSpectator
local myTeamID

local myLastCameraState

local vsx,vsy = widgetHandler:GetViewSizes()

------------------------------------------------
--speedups
------------------------------------------------
local GetCameraState = Spring.GetCameraState
local SetCameraState = Spring.SetCameraState
local GetCameraNames = Spring.GetCameraNames
local IsGUIHidden = Spring.IsGUIHidden
local GetMouseState = Spring.GetMouseState
local GetSpectatingState = Spring.GetSpectatingState
local GetGameFrame = Spring.GetGameFrame

local GetMyPlayerID = Spring.GetMyPlayerID
local GetMyTeamID = Spring.GetMyTeamID
local GetPlayerList = Spring.GetPlayerList
local GetPlayerInfo = Spring.GetPlayerInfo
local GetTeamColor = Spring.GetTeamColor

local SendCommands = Spring.SendCommands

local Echo = Spring.Echo
local strGMatch = string.gmatch
local strSub = string.sub
local strLen = string.len
local strByte = string.byte
local strChar = string.char

local floor = math.floor
local ceil = math.ceil
local max = math.max
local min = math.min

local glColor = gl.Color
local glLineWidth = gl.LineWidth
local glPolygonMode = gl.PolygonMode
local glRect = gl.Rect
local glText = gl.Text
local glShape = gl.Shape

local glCreateList = gl.CreateList
local glCallList = gl.CallList
local glDeleteList = gl.DeleteList

local glPopMatrix = gl.PopMatrix
local glPushMatrix = gl.PushMatrix
local glTranslate = gl.Translate
local glScale = gl.Scale

local GL_FILL = GL.FILL
local GL_FRONT_AND_BACK = GL.FRONT_AND_BACK
local GL_LINE_STRIP = GL.LINE_STRIP

local vfsPackU8 = VFS.PackU8
local vfsPackF32 = VFS.PackF32
local vfsUnpackU8 = VFS.UnpackU8
local vfsUnpackF32 = VFS.UnpackF32

------------------------------------------------
--const
------------------------------------------------
local PACKET_HEADER = "="
local PACKET_HEADER_LENGTH = strLen(PACKET_HEADER)

------------------------------------------------
--H4X
------------------------------------------------
--[0, 254] -> char
local function CustomPackU8(num)
	return strChar(num + 1)
end

local function CustomUnpackU8(s, offset)
	local byte = strByte(s, offset)
	if byte then
		return strByte(s, offset) - 1
	else
		return nil
	end
end

--1 sign bit, 7 exponent bits, 8 mantissa bits, -64 bias, denorm, no infinities or NaNs, avoid zero bytes, big-Endian
local function CustomPackF16(num)
	--vfsPack is little-Endian
	local floatChars = vfsPackF32(num)
	if not floatChars then return nil end

	local sign = 0
	local exponent = strByte(floatChars, 4) * 2
	local mantissa = strByte(floatChars, 3) * 2

	local negative = exponent >= 256
	local exponentLSB = mantissa >= 256
	local mantissaLSB = strByte(floatChars, 2) >= 128

	if negative then
		sign = 128
		exponent = exponent - 256
	end

	if exponentLSB then
		exponent = exponent - 126
		mantissa = mantissa - 256
	else
		exponent = exponent - 127
	end

	if mantissaLSB then
		mantissa = mantissa + 1
	end

	if exponent > 63 then
		exponent = 63
		--largest representable number
		mantissa = 255
	elseif exponent < -62 then
		--denorm
		mantissa = floor((256 + mantissa) * 2^(exponent + 62))
		--preserve zero-ness
		if mantissa == 0 and num ~= 0 then
			mantissa = 1
		end
		exponent = -63
	end

	if mantissa ~= 255 then
		mantissa = mantissa + 1
	end

	local byte1 = sign + exponent + 64
	local byte2 = mantissa

	return strChar(byte1, byte2)
end

local function CustomUnpackF16(s, offset)
	offset = offset or 1
	local byte1, byte2 = strByte(s, offset, offset + 1)

	if not (byte1 and byte2) then return nil end

	local sign = 1
	local exponent = byte1
	local mantissa = byte2 - 1
	local norm = 1

	local negative = (byte1 >= 128)

	if negative then
		exponent = exponent - 128
		sign = -1
	end

	if exponent == 1 then
		exponent = 2
		norm = 0
	end

	local order = 2^(exponent - 64)

	return sign * order * (norm + mantissa / 256)
end

------------------------------------------------
--packets
------------------------------------------------

local CAMERA_IDS = GetCameraNames()
local CAMERA_NAMES = {}
local CAMERA_STATE_FORMATS = {}

Echo("<LockCamera>: Sorry for the camera switch spam, but this is the only reliable way to list camera states other than hardcoding them")
local prevCameraState = GetCameraState()
for name, num in pairs(CAMERA_IDS) do
	CAMERA_NAMES[num] = name
	SetCameraState({name=name,mode=num},0)
	local packetFormat = {}
	for stateindex in pairs(GetCameraState()) do
		if stateindex ~= "mode" and stateindex ~= "name" then
			table.insert(packetFormat,stateindex)
		end
	end
	CAMERA_STATE_FORMATS[name] = packetFormat
end
SetCameraState(prevCameraState,0)
--workaround a bug where minimap remains minimized because we switched to overview cam
SendCommands("minimap minimize")

--does not allow spaces in keys; values are numbers
local function CameraStateToPacket(s)

	local name = s.name
	local stateFormat = CAMERA_STATE_FORMATS[name]
	local cameraID = CAMERA_IDS[name]

	if not stateFormat or not cameraID then return nil end

	local result = PACKET_HEADER .. CustomPackU8(cameraID) .. CustomPackU8(s.mode)

	for i=1, #stateFormat do
		local num = s[stateFormat[i]]
		if not num then return nil end
		result = result .. CustomPackF16(num)
	end

	return result
end

local function PacketToCameraState(p)
	local offset = PACKET_HEADER_LENGTH + 1
	local cameraID = CustomUnpackU8(p, offset)
	local mode = CustomUnpackU8(p, offset + 1)
	local name = CAMERA_NAMES[cameraID]
	local stateFormat = CAMERA_STATE_FORMATS[name]
	if not (cameraID and mode and name and stateFormat) then
		return nil
	end

	local result = {
		name = name,
		mode = mode,
	}

	offset = offset + 2

	for i=1, #stateFormat do
		local num = CustomUnpackF16(p, offset)

		if not num then return nil end

		result[stateFormat[i]] = num
		offset = offset + 2
	end

	return result
end

------------------------------------------------
--helpers
------------------------------------------------

local function GetPlayerName(playerID)
	if not playerID then return "" end
	local name = GetPlayerInfo(playerID)
	return name or ""
end

------------------------------------------------
--mouse
------------------------------------------------

local function TransformMain(x, y)
	return (x - posX*vsx) / mainSize, (y - posY*vsy) / mainSize
end

local function GetComponent(tx, ty)
	if tx < 0 or tx > 8 or ty < 0 then return nil end
	if ty < 1 then
		return "title"
	elseif not show then
		return nil
	elseif ty < 2 then
		if tx < 4 then
			return "refresh"
		else
			return "move"
		end
	else
		local result = floor(ty - 1)
		if result > #recentBroadcasters then
			return
		else
			return result
		end
	end
end

------------------------------------------------
--drawing
------------------------------------------------
local function GetPlayerColor(playerID)
	local _, _, _, teamID = GetPlayerInfo(playerID)
	if not teamID then return end
	return GetTeamColor(teamID)
end

local function DrawL()
	local vertices = {
		{v = {0, 1, 0}},
		{v = {0, 0, 0}},
		{v = {1, 0, 0}},
	}
	glShape(GL_LINE_STRIP, vertices)
end


local function convertColor(colorarray)
	local red = ceil(colorarray[1]*255)
	local green = ceil(colorarray[2]*255)
	local blue = ceil(colorarray[3]*255)
	red = max( red, 1 )
	green = max( green, 1 )
	blue = max( blue, 1 )
	red = min( red, 255 )
	green = min( green, 255 )
	blue = min( blue, 255 )
	return strChar(255,red,green,blue)
end

local function DrawShow()
	glPolygonMode(GL_FRONT_AND_BACK, GL_FILL)
	glColor(0, 0, 0, 0.2)
	glRect(0, 1, 8, 2 + #recentBroadcasters)

	--buttons
	glColor(1, 1, 1, 1)
	glPushMatrix()
		glTranslate(0, 1, 0)
		glText("Refresh", textMargin, textMargin, textSize, "no")
		DrawL()
		glTranslate(4, 0, 0)
		glText("Move", textMargin, textMargin, textSize, "no")
		DrawL()
	glPopMatrix()

	--player list
	glPushMatrix()
		glTranslate(0, 2, 0)
		for _, playerInfo in pairs(recentBroadcasters) do
			local playerID = playerInfo[1]
			local playerName = playerInfo[2]
			local color = {GetPlayerColor(playerID)}
			glText(convertColor(color) .. playerID .. ": " .. playerName, textMargin, textMargin, textSize, "on")
			if lockPlayerID == playerID then
				DrawL()
			end
			glTranslate(0, 1, 0)
		end
	glPopMatrix()
end

--0, 0 to 1, 8
local function DrawTitle()
	glPolygonMode(GL_FRONT_AND_BACK, GL_FILL)
	glColor(0, 0, 0, 0.2)
	glRect(0, 0, 8, 1)
	DrawL()
	glText(convertColor({1, 1, 1, 1}) .. "LockCamera", textMargin, textMargin, textSize, "no")
end

function widget:IsAbove(x,y)
	local tx, ty = TransformMain(x, y)
	return GetComponent(tx, ty)
end

function widget:GetTooltip(x,y)
	local tx, ty = TransformMain(x, y)
	local component = GetComponent(tx, ty)

	if not component then return end

	if component == "title" then
		return "Open/close"
	elseif component == "refresh" then
		return "Refresh broadcaster list"
	elseif component == "move" then
		return "Drag to move"
	else
		local playerInfo = recentBroadcasters[component]
		if playerInfo then
			local playerID = playerInfo[1]
			if playerID and playerID ~= myPlayerID and playerID ~= lockPlayerID then
				return "Lock camera"
			else
				return "Unlock camera"
			end
		end
	end
end


local function CreateLists()
	showList = glCreateList(DrawShow)
	titleList = glCreateList(DrawTitle)
end

local function DeleteLists()
	glDeleteList(showList)
	glDeleteList(titleList)
end

------------------------------------------------
--update
------------------------------------------------
local function UpdateShowList()
	glDeleteList(showList)
	showList = glCreateList(DrawShow)
	newBroadcaster = false
end

local function UpdateRecentBroadcasters()
	recentBroadcasters = {}
	local i = 1
	for playerID, info in pairs(lastBroadcasts) do
		lastTime = info[1]
		if (totalTime - lastTime <= listTime or playerID == lockPlayerID) then
			recentBroadcasters[i] = {playerID, GetPlayerName(playerID)}
			i = i + 1
		end
	end

	if show then
		UpdateShowList()
	end
end

local function LockCamera(playerID)
	if playerID and playerID ~= myPlayerID and playerID ~= lockPlayerID then
		lockPlayerID = playerID
		myLastCameraState = myLastCameraState or GetCameraState()
		local info = lastBroadcasts[lockPlayerID]
		if info then
			SetCameraState(info[2], transitionTime)
		end
	else
		if myLastCameraState then
			SetCameraState(myLastCameraState, transitionTime)
			myLastCameraState = nil
		end
		lockPlayerID = nil
	end
	UpdateRecentBroadcasters()
end


------------------------------------------------
--callins
------------------------------------------------

function widget:Update(dt)
	totalTime = totalTime + dt
end

function widget:RecvLuaMsg(msg, playerID)
	--check header
	if strSub(msg, 1, PACKET_HEADER_LENGTH) ~= PACKET_HEADER then return end

	totalCharsRecv = totalCharsRecv + strLen(msg)

	--a packet consisting only of the header indicated that transmission has stopped
	if msg == PACKET_HEADER then
		if lastBroadcasts[playerID] then
			lastBroadcasts[playerID] = nil
			newBroadcaster = true
		end
		if lockPlayerID == playerID then
			LockCamera()
		end
		return
	end

	local cameraState = PacketToCameraState(msg)

	if not cameraState then
		Echo("<LockCamera>: Bad packet recieved.")
		return
	end

	if not lastBroadcasts[playerID] and not newBroadcaster then
		newBroadcaster = true
	end

	lastBroadcasts[playerID] = {totalTime, cameraState}

	if playerID == lockPlayerID then
		 SetCameraState(cameraState, transitionTime)
	end

end


function widget:Initialize()
	--Spring.SendCommands("fetchlockcamerapacketformat")
	UpdateRecentBroadcasters()
	CreateLists()
end

function widget:LockCameraPacketFormat()
end

function widget:Shutdown()
	DeleteLists()
end

function widget:GameStart()
	UpdateRecentBroadcasters()
end

function widget:ViewResize(viewSizeX, viewSizeY)
	vsx = viewSizeX
	vsy = viewSizeY
end

function widget:DrawScreen()
	if IsGUIHidden() and not activeClick then return end

	glLineWidth(lineWidth)

	glPushMatrix()
		glTranslate(posX*vsx, posY*vsy, 0)
		glScale(mainSize, mainSize, 1)
		glCallList(titleList)
		if show then
			glCallList(showList)
		end
	glPopMatrix()

	glColor(1, 1, 1, 1)
	glLineWidth(1)
end

function widget:MousePress(x, y, button)
	if (IsGUIHidden()) then return false end
	local tx, ty = TransformMain(x, y)
	local component = GetComponent(tx, ty)

	if not component then return false end

	if component == "title" then
		show = not show
		if show then
			UpdateRecentBroadcasters()
		end
	elseif component == "refresh" then
		UpdateRecentBroadcasters()
	elseif component == "move" then
		activeClick = "move"
	else
		local playerInfo = recentBroadcasters[component]

		if playerInfo then
			local playerID = playerInfo[1]
			LockCamera(playerID)
		end
	end

	return true

end

function widget:MouseMove(x, y, dx, dy, button)
	if activeClick == "move" then
		posX = posX + dx/vsx
		posY = posY + dy/vsy
	end
end

local function ReleaseActiveClick(x, y)
	local viewSizeX, viewSizeY = widgetHandler:GetViewSizes()
	widget:ViewResize(viewSizeX, viewSizeY)
	activeClick = nil
end

function widget:MouseRelease(x, y, button)
	if activeClick then
		ReleaseActiveClick(x, y)
	end
	return activeClick
end
