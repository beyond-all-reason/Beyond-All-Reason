local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "CameraBroadcast",
		desc = "sends your camera to others",
		author = "Evil4Zerggin",
		date = "16 January 2009",
		license = "GNU LGPL, v2.1 or later",
		layer = -5,
		enabled = true,
	}
end

local broadcastPeriod = 0.12 -- will send packet in this interval (s)

local PACKET_HEADER = "="
local PACKET_HEADER_LENGTH = #PACKET_HEADER

if gadgetHandler:IsSyncedCode() then
	local strSub = string.sub

	local validation = string.randomString(2)
	_G.validationCam = validation

	local SendToUnsynced = SendToUnsynced
	local expectedPrefix = PACKET_HEADER .. validation
	local expectedPrefixLen = #expectedPrefix

	function gadget:RecvLuaMsg(msg, playerID)
		if strSub(msg, 1, expectedPrefixLen) ~= expectedPrefix then
			return
		end
		SendToUnsynced("cameraBroadcast", playerID, msg)
		return true
	end
else -- UNSYNCED
	local GetCameraState = Spring.GetCameraState
	local SetCameraState = Spring.SetCameraState
	local GetLastUpdateSeconds = Spring.GetLastUpdateSeconds
	local GetMyAllyTeamID = Spring.GetLocalAllyTeamID
	local GetSpectatingState = Spring.GetSpectatingState
	local GetPlayerInfo = Spring.GetPlayerInfo
	local SendLuaRulesMsg = Spring.SendLuaRulesMsg
	local SendCommands = Spring.SendCommands

	local strByte = string.byte
	local strChar = string.char

	local floor = math.floor
	local math_frexp = math.frexp
	local math_ldexp = math.ldexp

	local timeSinceBroadcast = 0

	local CAMERA_IDS = Spring.GetCameraNames()
	local CAMERA_NAMES = {}
	local CAMERA_STATE_FORMATS = {}

	local validation = SYNCED.validationCam
	local msgPrefix = PACKET_HEADER .. validation
	local msgPrefixLen = #msgPrefix

	------------------------------------------------
	-- H4X
	------------------------------------------------
	-- [0, 254] -> char
	local function CustomPackU8(num)
		return strChar(num + 1)
	end

	local function CustomUnpackU8(s, offset)
		local byte = strByte(s, offset)
		if byte then
			return byte - 1
		end
	end

	-- 1 sign bit, 7 exponent bits, 8 mantissa bits, -64 bias, denorm, no infinities or NaNs, avoid zero bytes, big-Endian
	local function CustomPackF16(num)
		if num == 0 then
			return strChar(1, 1)
		end

		local m, e = math_frexp(num)
		local sign = 0
		if m < 0 then
			sign = 128
			m = -m
		end

		local exp = e - 1
		local mantissa = floor((2 * m - 1) * 256)

		if exp > 63 then
			exp = 63
			mantissa = 255
		elseif exp < -62 then
			--denorm
			mantissa = floor(math_ldexp(m, e + 70))
			if mantissa == 0 then
				mantissa = 1
			end
			exp = -63
		end

		if mantissa ~= 255 then
			mantissa = mantissa + 1
		end

		return strChar(sign + exp + 64, mantissa)
	end

	local function CustomUnpackF16(s, offset)
		offset = offset or 1
		local byte1, byte2 = strByte(s, offset, offset + 1)

		if not (byte1 and byte2) then
			return nil
		end

		local sign = 1
		local exponent = byte1
		local mantissa = byte2 - 1
		local norm = 1

		if byte1 >= 128 then
			exponent = exponent - 128
			sign = -1
		end

		if exponent == 1 then
			exponent = 2
			norm = 0
		end

		return sign * math_ldexp(norm + mantissa / 256, exponent - 64)
	end

	------------------------------------------------
	-- packets
	------------------------------------------------

	local tableConcat = table.concat

	-- does not allow spaces in keys; values are numbers
	local function CameraStateToPacket(s)
		local name = s.name
		local stateFormat = CAMERA_STATE_FORMATS[name]
		local cameraID = CAMERA_IDS[name]

		if not stateFormat or not cameraID then
			return nil
		end

		local parts = { msgPrefix, CustomPackU8(cameraID), CustomPackU8(s.mode) }
		local n = 3

		for i = 1, #stateFormat do
			local num = s[stateFormat[i]]
			if not num then
				return
			end
			n = n + 1
			parts[n] = CustomPackF16(num)
		end

		return tableConcat(parts)
	end

	local function PacketToCameraState(p)
		local offset = msgPrefixLen + 1
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

		for i = 1, #stateFormat do
			local num = CustomUnpackF16(p, offset)

			if not num then
				return nil
			end

			result[stateFormat[i]] = num
			offset = offset + 2
		end

		return result
	end

	Spring.Echo("<LockCamera>: Sorry for the camera switch spam, but this is the only reliable way to list camera states other than hardcoding them")
	local prevCameraState = GetCameraState()
	for name, num in pairs(CAMERA_IDS) do
		CAMERA_NAMES[num] = name
		SetCameraState({ name = name, mode = num }, 0)
		local packetFormat = {}
		local packetFormatIndex = 1
		for stateindex in pairs(GetCameraState()) do
			if stateindex ~= "mode" and stateindex ~= "name" then
				packetFormat[packetFormatIndex] = stateindex
				packetFormatIndex = packetFormatIndex + 1
			end
		end
		table.sort(packetFormat)
		CAMERA_STATE_FORMATS[name] = packetFormat
	end
	SetCameraState(prevCameraState, 0)
	-- workaround a bug where minimap remains minimized because we switched to overview cam
	SendCommands("minimap minimize")

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("cameraBroadcast", handleCameraBroadcastEvent)
	end

	local spec, fullView = GetSpectatingState()
	local myAllyTeamID = GetMyAllyTeamID()

	function gadget:Shutdown()
		SendLuaRulesMsg(PACKET_HEADER)
		gadgetHandler:RemoveSyncAction("cameraBroadcast")
	end

	function gadget:PlayerChanged(playerID)
		spec, fullView = GetSpectatingState()
		myAllyTeamID = GetMyAllyTeamID()
	end

	function handleCameraBroadcastEvent(_, playerID, msg)
		local cameraState
		-- a packet consisting only of the header indicates that transmission has stopped
		if msg ~= PACKET_HEADER then
			cameraState = PacketToCameraState(msg)
			if not cameraState then
				Spring.Echo("<LockCamera>: Bad packet recieved.")
				return
			end
		end
		if not spec or not fullView then
			local _, _, targetSpec, _, allyTeamID = GetPlayerInfo(playerID, false)
			if targetSpec or allyTeamID ~= myAllyTeamID then
				return
			end
		end
		if Script.LuaUI("CameraBroadcastEvent") then
			Script.LuaUI.CameraBroadcastEvent(playerID, cameraState)
		end
	end

	local lastCameraName
	local lastCameraValues = {}

	local function CameraStateChanged(state)
		local name = state.name
		if name ~= lastCameraName then
			lastCameraName = name
			-- Camera type changed — must rebuild cache
			local stateFormat = CAMERA_STATE_FORMATS[name]
			if stateFormat then
				for i = 1, #stateFormat do
					lastCameraValues[stateFormat[i]] = state[stateFormat[i]]
				end
			end
			return true
		end
		local stateFormat = CAMERA_STATE_FORMATS[name]
		if not stateFormat then
			return false
		end
		for i = 1, #stateFormat do
			local key = stateFormat[i]
			if state[key] ~= lastCameraValues[key] then
				for j = i, #stateFormat do
					local k2 = stateFormat[j]
					lastCameraValues[k2] = state[k2]
				end
				return true
			end
		end
		return false
	end

	function gadget:Update()
		local dt = GetLastUpdateSeconds()
		timeSinceBroadcast = timeSinceBroadcast + dt
		if timeSinceBroadcast < broadcastPeriod then
			return
		end
		timeSinceBroadcast = timeSinceBroadcast - broadcastPeriod

		local state = GetCameraState()
		if not CameraStateChanged(state) then
			return
		end

		local msg = CameraStateToPacket(state)

		if not msg then
			Spring.Echo("<LockCamera>: Error creating packet!")
			return
		end

		SendLuaRulesMsg(msg)
	end
end
