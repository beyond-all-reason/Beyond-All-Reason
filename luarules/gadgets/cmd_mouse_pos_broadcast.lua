--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--	Copyright (C) 2007.
--	Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name	= "Cursor Broadcast",
		desc	= "Shows the mouse pos of allied players",
		author	= "jK,TheFatController",
		date	= "Apr,2009",
		license	= "GNU GPL, v2 or later",
		layer	= 0,
		enabled = true,
	}
end

--------------------------------------------------------------------------------

local numMousePos		= 1 	-- num mouse pos in 1 packet
local sendPacketEveryMin	= 0.12
local sendPacketEveryMax	= 0.35
local sendPacketEveryWhenSpec = 0.5
local playerCountScalingStart = 8
local playerCountScalingEnd = 64

--------------------------------------------------------------------------------

local PackU16			= VFS.PackU16
local MOUSE_POS_BYTES	= numMousePos * 4
local MSG_PAYLOAD_BYTES	= MOUSE_POS_BYTES + 1


if gadgetHandler:IsSyncedCode() then
	local validation = string.randomString(2)
	_G.validationMouse = validation

	local SendToUnsynced = SendToUnsynced
	local strSub = string.sub
	local strByte = string.byte
	local expectedPrefix = "£" .. validation
	local EXPECTED_PREFIX_LEN = #expectedPrefix
	local EXPECTED_MSG_LEN = EXPECTED_PREFIX_LEN + MSG_PAYLOAD_BYTES

	-- Cache prefix bytes to avoid string allocations in the hot path
	-- Note: "£" is 2 UTF-8 bytes (0xC2, 0xA3 = 194, 163)
	local ep1, ep2, ep3, ep4 = strByte(expectedPrefix, 1, 4)
	local paused = false

	function gadget:RecvLuaMsg(msg, playerID)
		if #msg ~= EXPECTED_MSG_LEN then return end
		local b1, b2, b3, b4 = strByte(msg, 1, 4)
		if b1 ~= ep1 or b2 ~= ep2 or b3 ~= ep3 or b4 ~= ep4 then return end
		if paused then return end

		SendToUnsynced("mouseBroadcast", playerID, strSub(msg, EXPECTED_PREFIX_LEN + 1, EXPECTED_MSG_LEN))
		return true
	end

	function gadget:GamePaused(_, isPaused)
		paused = isPaused
	end


else


	--------------------------------------------------------------------------------

	--------------------------------------------------------------------------------

	local GetMouseState			= Spring.GetMouseState
	local TraceScreenRay		= Spring.TraceScreenRay
	local SendLuaRulesMsg		= Spring.SendLuaRulesMsg
	local GetSpectatingState	= Spring.GetSpectatingState
	local GetPlayerInfo			= Spring.GetPlayerInfo
	local GetPlayerList			= Spring.GetPlayerList
	local GetTeamInfo			= Spring.GetTeamInfo
	local GetLastUpdateSeconds	= Spring.GetLastUpdateSeconds
	local GetGameSpeed			= Spring.GetGameSpeed
	local LuaUICallIn			= Script.LuaUI
	local LuaUI					= Script.LuaUI

	local floor				= math.floor
	local abs				= math.abs
	local strByte			= string.byte
	local CLICK_BYTE		= string.byte("1")

	local validation = SYNCED.validationMouse
	local msgPrefix = "£" .. validation

	local myPlayerID = Spring.GetMyPlayerID()
	local spec, _ = GetSpectatingState()
	local myAllyTeamID = select(5, GetPlayerInfo(myPlayerID, false))

	local playerBroadcastPeriod = sendPacketEveryMin
	local saveEach = playerBroadcastPeriod / numMousePos
	local updateTick = saveEach

	local updateTimer = 0
	local poshistory = {}

	local lastx,lastz = 0,0
	local n = 0
	local wasBroadcastActive = false

	local tableConcat = table.concat
	local sendParts = {msgPrefix, false, false, false, false, false}

	local function ResetCursorBroadcastState()
		for i = 0, numMousePos * 2 + 1 do
			poshistory[i] = nil
		end
		lastx,lastz = 0,0
		n = 0
		updateTimer = 0
		updateTick = saveEach
	end

	local function IsCursorBroadcastActive()
		local _, _, paused = GetGameSpeed()
		return not paused
	end

	local function RefreshSendInterval()
		local humanPlayerCount = 0
		local playerList = GetPlayerList() or {}
		for _, playerID in ipairs(playerList) do
			local _, _, isSpec, teamID = GetPlayerInfo(playerID, false)
			if not isSpec and not select(4, GetTeamInfo(teamID, false)) then
				humanPlayerCount = humanPlayerCount + 1
			end
		end

		if humanPlayerCount <= playerCountScalingStart then
			playerBroadcastPeriod = sendPacketEveryMin
		elseif humanPlayerCount >= playerCountScalingEnd then
			playerBroadcastPeriod = sendPacketEveryMax
		else
			playerBroadcastPeriod = sendPacketEveryMin
				+ (sendPacketEveryMax - sendPacketEveryMin)
					* (humanPlayerCount - playerCountScalingStart)
					/ (playerCountScalingEnd - playerCountScalingStart)
		end

		saveEach = (spec and sendPacketEveryWhenSpec or playerBroadcastPeriod) / numMousePos
		updateTick = updateTimer + saveEach
	end

	local function sendPositionPacket(clickChar)
		sendParts[2] = clickChar
		local pn = 2
		for i = numMousePos, 1, -1 do
			local xStr = poshistory[i * 2]
			local zStr = poshistory[i * 2 + 1]
			if xStr and zStr then
				pn = pn + 1; sendParts[pn] = xStr
				pn = pn + 1; sendParts[pn] = zStr
			end
		end
		SendLuaRulesMsg(tableConcat(sendParts, "", 1, pn))
	end

	function gadget:Initialize()
		RefreshSendInterval()
		gadgetHandler:AddSyncAction("mouseBroadcast", handleMouseBroadcastEvent)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction("mouseBroadcast")
	end

	function gadget:PlayerChanged(playerID)
		if playerID == myPlayerID then
			spec, _ = Spring.GetSpectatingState()
			myAllyTeamID = select(5, GetPlayerInfo(myPlayerID, false))
		end
		RefreshSendInterval()
	end

	function gadget:PlayerAdded()
		RefreshSendInterval()
	end

	function gadget:PlayerRemoved()
		RefreshSendInterval()
	end

	function handleMousePosEvent(_,playerID,x1,z1,x2,z2,click)
		if not spec then
			local _,_,targetSpec,_,allyTeamID = GetPlayerInfo(playerID,false)
			if targetSpec or allyTeamID ~= myAllyTeamID then
				return
			end
		end
		if LuaUICallIn("MouseCursorEvent") then
			LuaUI.MouseCursorEvent(playerID,x1,z1,x2,z2,click)
		end
	end

	function handleMouseBroadcastEvent(_, playerID, payload)
		if not payload or #payload ~= MSG_PAYLOAD_BYTES then
			return
		end
		if not LuaUICallIn("MouseCursorEvent") then
			return
		end

		local clickByte, x1b1, x1b2, z1b1, z1b2 = strByte(payload, 1, MSG_PAYLOAD_BYTES)
		local x1 = x1b1 + x1b2 * 256
		local z1 = z1b1 + z1b2 * 256
		if spec then
			LuaUI.MouseCursorEvent(playerID, x1, z1, x1, z1, clickByte == CLICK_BYTE)
		else
			local _,_,targetSpec,_,allyTeamID = GetPlayerInfo(playerID,false)
			if not targetSpec and allyTeamID == myAllyTeamID then
				LuaUI.MouseCursorEvent(playerID, x1, z1, x1, z1, clickByte == CLICK_BYTE)
			end
		end
	end

	function gadget:Update()
		if not IsCursorBroadcastActive() then
			if wasBroadcastActive then
				ResetCursorBroadcastState()
			end
			wasBroadcastActive = false
			return
		end
		if not wasBroadcastActive then
			ResetCursorBroadcastState()
			wasBroadcastActive = true
		end

		updateTimer = updateTimer + GetLastUpdateSeconds()

		if updateTimer > updateTick then
			local mx,my = GetMouseState()
			local _,pos = TraceScreenRay(mx,my,true)

			if pos and (n == 1 or pos[1] ~= lastx or pos[3] ~= lastz) then	-- only record change in position unless packet is already being instigated previous update tick
				local historyIdx = (n + 1) * 2
				poshistory[historyIdx]	 = PackU16(floor(pos[1]))
				poshistory[historyIdx + 1] = PackU16(floor(pos[3]))
				lastx,lastz = pos[1],pos[3]
				n = n + 1
			end
			updateTick = updateTimer + saveEach
		end

		if n >= numMousePos then
			n = 0
			updateTimer = 0
			updateTick = saveEach
			sendPositionPacket("0")
		end
	end


	function gadget:MousePress(x,y,button)
		if button == 2 then
			return
		end
		if not IsCursorBroadcastActive() then
			return
		end
		local mx,my = GetMouseState()
		local _,pos = TraceScreenRay(mx,my,true)

		if not pos then
			return
		end
		if abs(pos[1] - lastx) > 300 or abs(pos[3] - lastz) > 300 then
			for i=0,5 do
				local posindex = i%2 == 0 and 1 or 3
				poshistory[i] = PackU16(floor(pos[posindex]))
			end
			lastx,lastz = pos[1],pos[3]
			updateTick = saveEach
			updateTimer = 0
			n = 0
			sendPositionPacket("0")
		end
	end

end

