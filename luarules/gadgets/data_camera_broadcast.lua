local gadget = gadget ---@type Gadget

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

local minBroadcastPeriod = 0.1
local maxBroadcastPeriod = 0.35
local broadcastPeriod = minBroadcastPeriod	-- will send packet in this interval (s) for non-spectators
local spectatorBroadcastPeriod = maxBroadcastPeriod	-- will send packet in this interval (s) for spectators
local broadcastPeriodScalingStart = 8	-- when still minBroadcastPeriod
local broadcastPeriodScalingEnd = 32	-- when reaches maxBroadcastPeriod

local PACKET_HEADER = "="

if gadgetHandler:IsSyncedCode() then

	local strSub = string.sub

	local validation = string.randomString(2)
	_G.validationCam = validation

	local SendToUnsynced = SendToUnsynced
	local expectedPrefix = PACKET_HEADER .. validation
	local expectedPrefixLen = #expectedPrefix

	-- Cache prefix bytes to avoid string allocations in the hot path
	local ep1, ep2, ep3 = string.byte(expectedPrefix, 1, 3)

	function gadget:RecvLuaMsg(msg, playerID)
		if #msg < expectedPrefixLen then return end
		local b1, b2, b3 = string.byte(msg, 1, 3)
		if b1 ~= ep1 or b2 ~= ep2 or b3 ~= ep3 then return end
		SendToUnsynced("cameraBroadcast",playerID,msg)
		return true
	end


else	-- UNSYNCED


	local GetCameraState = Spring.GetCameraState
	local SetCameraState = Spring.SetCameraState
	local GetLastUpdateSeconds = Spring.GetLastUpdateSeconds
	local GetMyAllyTeamID = Spring.GetMyAllyTeamID
	local GetSpectatingState = Spring.GetSpectatingState
	local GetPlayerInfo = Spring.GetPlayerInfo
	local GetPlayerList = Spring.GetPlayerList
	local SendLuaRulesMsg = Spring.SendLuaRulesMsg
	local SendCommands = Spring.SendCommands

	local strByte = string.byte
	local strChar = string.char
	local tableUnpack = unpack

	local floor = math.floor
	local math_frexp = math.frexp
	local math_ldexp = math.ldexp
	local FLOAT_BITS = 14
	local FLOAT_RANGE = 16384
	local MANTISSA_RANGE = 64
	local POW2 = {
		[0] = 1, 2, 4, 8, 16, 32, 64, 128,
		256, 512, 1024, 2048, 4096, 8192,
	}

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
	local function CustomUnpackU8(s, offset)
		local byte = strByte(s, offset)
		if byte then
			return byte - 1
		end
	end

	-- 1 sign bit, 7 exponent bits, 6 mantissa bits, -64 bias, denorm, no infinities or NaNs
	local function CustomPackF14(num)
		if num == 0 then
			return MANTISSA_RANGE
		end

		local m, e = math_frexp(num)
		local sign = 0
		if m < 0 then
			sign = 8192
			m = -m
		end

		local exp = e - 1
		local mantissa = floor((2 * m - 1) * MANTISSA_RANGE + 0.5)

		if exp > 63 then
			exp = 63
			mantissa = MANTISSA_RANGE - 1
		elseif exp < -62 then
			mantissa = floor(math_ldexp(m, e + 68) + 0.5)
			if mantissa == 0 then
				return MANTISSA_RANGE
			elseif mantissa == MANTISSA_RANGE then
				exp = -62
				mantissa = 0
			else
				exp = -63
			end
		elseif mantissa == MANTISSA_RANGE then
			exp = exp + 1
			mantissa = 0
			if exp > 63 then
				exp = 63
				mantissa = MANTISSA_RANGE - 1
			end
		end

		return sign + (exp + 64) * MANTISSA_RANGE + mantissa
	end

	local function CustomUnpackF14(code)
		local sign = 1
		local exponent = floor(code / MANTISSA_RANGE)
		local mantissa = code - exponent * MANTISSA_RANGE
		local norm = 1

		if exponent >= 128 then
			exponent = exponent - 128
			sign = -1
		end
		if exponent == 0 then return nil end

		if exponent == 1 then
			exponent = 2
			norm = 0
		end

		return sign * math_ldexp(norm + mantissa / MANTISSA_RANGE, exponent - 64)
	end

	------------------------------------------------
	-- packets
	------------------------------------------------

	local packedCameraBytes = {}

	local function PackCameraValues(state, stateFormat)
		local bitBuffer = 0
		local bitCount = 0
		local byteCount = 0
		for i=1, #stateFormat do
			local num = state[stateFormat[i]]
			if not num then return nil end

			bitBuffer = bitBuffer * FLOAT_RANGE + CustomPackF14(num)
			bitCount = bitCount + FLOAT_BITS
			while bitCount >= 8 do
				bitCount = bitCount - 8
				local divisor = POW2[bitCount]
				local byte = floor(bitBuffer / divisor)
				bitBuffer = bitBuffer - byte * divisor
				byteCount = byteCount + 1
				packedCameraBytes[byteCount] = byte
			end
		end
		if bitCount > 0 then
			byteCount = byteCount + 1
			packedCameraBytes[byteCount] = bitBuffer * POW2[8 - bitCount]
		end
		return byteCount
	end

	-- does not allow spaces in keys; values are numbers
	local function CameraStateToPacket(s)
		local name = s.name
		local stateFormat = CAMERA_STATE_FORMATS[name]
		local cameraID = CAMERA_IDS[name]

		if not stateFormat or not cameraID then return nil end

		local byteCount = PackCameraValues(s, stateFormat)
		if not byteCount then return nil end

		return msgPrefix .. strChar(cameraID + 1, tableUnpack(packedCameraBytes, 1, byteCount))
	end

	local function PacketToCameraState(p)
		local offset = msgPrefixLen + 1
		local cameraID = CustomUnpackU8(p, offset)
		local name = CAMERA_NAMES[cameraID]
		local stateFormat = CAMERA_STATE_FORMATS[name]
		if not (cameraID and name and stateFormat) then
			return nil
		end
		local packedStateBytes = floor((#stateFormat * FLOAT_BITS + 7) / 8)
		if #p ~= msgPrefixLen + 1 + packedStateBytes then return nil end
		local result = {
			name = name,
			mode = cameraID,
		}

		offset = offset + 1
		local bitBuffer = 0
		local bitCount = 0

		for i=1, #stateFormat do
			while bitCount < FLOAT_BITS do
				local byte = strByte(p, offset)
				if not byte then return nil end
				bitBuffer = bitBuffer * 256 + byte
				bitCount = bitCount + 8
				offset = offset + 1
			end
			bitCount = bitCount - FLOAT_BITS
			local divisor = POW2[bitCount]
			local code = floor(bitBuffer / divisor)
			bitBuffer = bitBuffer - code * divisor
			local num = CustomUnpackF14(code)
			if not num then return nil end

			result[stateFormat[i]] = num
		end
		if bitBuffer ~= 0 then return nil end

		return result
	end


	Spring.Echo("<LockCamera>: Sorry for the camera switch spam, but this is the only reliable way to list camera states other than hardcoding them")
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
		table.sort(packetFormat)
		CAMERA_STATE_FORMATS[name] = packetFormat
	end
	SetCameraState(prevCameraState,0)
	-- workaround a bug where minimap remains minimized because we switched to overview cam
	SendCommands("minimap minimize")

	local function RefreshBroadcastPeriod()
		local humanPlayerCount = 0
		local playerList = GetPlayerList() or {}
		for _, playerID in ipairs(playerList) do
			local _, _, isSpec = GetPlayerInfo(playerID, false)
			if isSpec == false then
				humanPlayerCount = humanPlayerCount + 1
			end
		end

		if humanPlayerCount <= broadcastPeriodScalingStart then
			broadcastPeriod = minBroadcastPeriod
		elseif humanPlayerCount >= broadcastPeriodScalingEnd then
			broadcastPeriod = maxBroadcastPeriod
		else
			broadcastPeriod = minBroadcastPeriod
				+ (maxBroadcastPeriod - minBroadcastPeriod)
					* (humanPlayerCount - broadcastPeriodScalingStart)
					/ (broadcastPeriodScalingEnd - broadcastPeriodScalingStart)
		end
	end

	function gadget:Initialize()
		RefreshBroadcastPeriod()
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
		RefreshBroadcastPeriod()
	end

	function gadget:PlayerAdded()
		RefreshBroadcastPeriod()
	end

	function gadget:PlayerRemoved()
		RefreshBroadcastPeriod()
	end

	function handleCameraBroadcastEvent(_,playerID,msg)
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
			local _,_,targetSpec,_,allyTeamID = GetPlayerInfo(playerID,false)
			if targetSpec or allyTeamID ~= myAllyTeamID then
				return
			end
		end
		if Script.LuaUI("CameraBroadcastEvent") then
			Script.LuaUI.CameraBroadcastEvent(playerID,cameraState)
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
					local key = stateFormat[i]
					lastCameraValues[key] = CustomPackF14(state[key])
				end
			end
			return true
		end
		local stateFormat = CAMERA_STATE_FORMATS[name]
		if not stateFormat then return false end
		for i = 1, #stateFormat do
			local key = stateFormat[i]
			local packedValue = CustomPackF14(state[key])
			if packedValue ~= lastCameraValues[key] then
				lastCameraValues[key] = packedValue
				for j = i + 1, #stateFormat do
					local k2 = stateFormat[j]
					lastCameraValues[k2] = CustomPackF14(state[k2])
				end
				return true
			end
		end
		return false
	end

	function gadget:Update()
		local dt = GetLastUpdateSeconds()
		timeSinceBroadcast = timeSinceBroadcast + dt
		local activeBroadcastPeriod = spec and spectatorBroadcastPeriod or broadcastPeriod
		if timeSinceBroadcast < activeBroadcastPeriod then
			return
		end
		timeSinceBroadcast = timeSinceBroadcast - activeBroadcastPeriod

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

