local versionNumber = "v2.91"

function gadget:GetInfo()
	return {
		name = "CameraBroadcast",
		desc = "sends your camera to others",
		author = "Evil4Zerggin",
		date = "16 January 2009",
		license = "GNU LGPL, v2.1 or later",
		layer = -5,
		enabled = true
	}
end

if gadgetHandler:IsSyncedCode() then
	return
end

------------------------------------------------
--debug
------------------------------------------------
local totalCharsSent = 0
local totalCharsRecv = 0

------------------------------------------------
--config
------------------------------------------------

--broadcast
local broadcastPeriod = 1 --will send packet in this interval (s)

------------------------------------------------
--vars
------------------------------------------------
local totalTime = 0
local timeSinceBroadcast = 0

local lastPacketSent

------------------------------------------------
--speedups
------------------------------------------------
local GetCameraState = Spring.GetCameraState
local SetCameraState = Spring.SetCameraState
local GetCameraNames = Spring.GetCameraNames
local GetMouseState = Spring.GetMouseState
local GetLastUpdateSeconds = Spring.GetLastUpdateSeconds

local SendLuaUIMsg = Spring.SendLuaUIMsg

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
	local packetFormatIndex = 1
	for stateindex in pairs(GetCameraState()) do
		if stateindex ~= "mode" and stateindex ~= "name" then
			packetFormat[packetFormatIndex] = stateindex
			packetFormatIndex = packetFormatIndex +1
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
		if not num then return end
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
--callins
------------------------------------------------

function gadget:RecvLuaMsg(msg, playerID)
	--check header
	if strSub(msg, 1, PACKET_HEADER_LENGTH) ~= PACKET_HEADER then return end

	Spring.Echo("received message")
end

function gadget:Initialize()
	gadgetHandler:AddChatAction("fetchlockcamerapacketformat", onFetchCameraPacketformat,"sends to LuaUI lock camera packet format")
end

function gadget:Shutdown()
	SendLuaUIMsg(PACKET_HEADER, "a")
end

function onFetchCameraPacketformat()
	Script.LuaUI.LockCameraPacketFormat(CAMERA_STATE_FORMATS)
end

function gadget:Update()
	local dt = GetLastUpdateSeconds()
	totalTime = totalTime + dt 
	timeSinceBroadcast = timeSinceBroadcast + dt
	if timeSinceBroadcast < broadcastPeriod then
		return
	end
	
	local state = GetCameraState()
	local msg = CameraStateToPacket(state)

	if not msg then
		Echo("<LockCamera>: Error creating packet!")
		return
	end
	
	--don't send duplicates
	if msg ~= lastPacketSent then
		SendLuaUIMsg(msg, "a") -- a sends the message so it's received by either allies or specs
		totalCharsSent = totalCharsSent + strLen(msg)
		lastPacketSent = msg
	end

	timeSinceBroadcast = timeSinceBroadcast - broadcastPeriod
end

