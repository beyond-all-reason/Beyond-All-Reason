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
		name = "Cursor Broadcast",
		desc = "Shows the mouse pos of allied players",
		author = "jK,TheFatController",
		date = "Apr,2009",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

--------------------------------------------------------------------------------

local numMousePos = 1 -- num mouse pos in 1 packet
local sendPacketEvery = 0.12
local sendPacketEveryWhenSpec = 0.35

--------------------------------------------------------------------------------

local PackU16 = VFS.PackU16
local UnpackU16 = VFS.UnpackU16

if gadgetHandler:IsSyncedCode() then
	local validation = string.randomString(2)
	_G.validationMouse = validation

	local SendToUnsynced = SendToUnsynced
	local strSub = string.sub
	local expectedPrefix = "£" .. validation
	local EXPECTED_PREFIX_LEN = #expectedPrefix

	-- Cache prefix bytes to avoid string allocations in the hot path
	-- Note: "£" is 2 UTF-8 bytes (0xC2, 0xA3 = 194, 163)
	local ep1, ep2, ep3, ep4 = string.byte(expectedPrefix, 1, 4)

	function gadget:RecvLuaMsg(msg, playerID)
		if #msg < EXPECTED_PREFIX_LEN then
			return
		end
		local b1, b2, b3, b4 = string.byte(msg, 1, 4)
		if b1 ~= ep1 or b2 ~= ep2 or b3 ~= ep3 or b4 ~= ep4 then
			return
		end
		local xz = strSub(msg, EXPECTED_PREFIX_LEN + 2)
		if #xz ~= numMousePos * 4 then
			return
		end
		local click = strSub(msg, EXPECTED_PREFIX_LEN + 1, EXPECTED_PREFIX_LEN + 1) == "1"
		local x1 = UnpackU16(strSub(xz, 1, 2))
		local z1 = UnpackU16(strSub(xz, 3, 4))
		local x2 = UnpackU16(strSub(xz, 5, 6))
		local z2 = UnpackU16(strSub(xz, 7, 8))
		SendToUnsynced("mouseBroadcast", playerID, x1, z1, x2, z2, click)
		return true
	end
else
	--------------------------------------------------------------------------------

	--------------------------------------------------------------------------------

	local GetMouseState = Spring.GetMouseState
	local TraceScreenRay = Spring.TraceScreenRay
	local SendLuaRulesMsg = Spring.SendLuaRulesMsg
	local GetSpectatingState = Spring.GetSpectatingState
	local GetPlayerInfo = Spring.GetPlayerInfo
	local GetLastUpdateSeconds = Spring.GetLastUpdateSeconds

	local floor = math.floor
	local abs = math.abs

	local validation = SYNCED.validationMouse
	local msgPrefix = "£" .. validation

	local myPlayerID = Spring.GetLocalPlayerID()
	local spec, _ = GetSpectatingState()
	local myAllyTeamID = select(5, GetPlayerInfo(myPlayerID, false))

	local saveEach = (spec and sendPacketEveryWhenSpec or sendPacketEvery) / numMousePos
	local updateTick = saveEach

	local updateTimer = 0
	local poshistory = {}

	local lastx, lastz = 0, 0
	local n = 0

	local tableConcat = table.concat
	local sendParts = { msgPrefix, false, false, false, false, false }

	local function sendPositionPacket(clickChar)
		sendParts[2] = clickChar
		local pn = 2
		for i = numMousePos, 1, -1 do
			local xStr = poshistory[i * 2]
			local zStr = poshistory[i * 2 + 1]
			if xStr and zStr then
				pn = pn + 1
				sendParts[pn] = xStr
				pn = pn + 1
				sendParts[pn] = zStr
			end
		end
		SendLuaRulesMsg(tableConcat(sendParts, "", 1, pn))
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("mouseBroadcast", handleMousePosEvent)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction("mouseBroadcast")
	end

	function gadget:PlayerChanged(playerID)
		if playerID == myPlayerID then
			spec, _ = Spring.GetSpectatingState()
			myAllyTeamID = select(5, GetPlayerInfo(myPlayerID, false))
			if spec then
				saveEach = sendPacketEveryWhenSpec / numMousePos
				updateTick = saveEach
			end
		end
	end

	function handleMousePosEvent(_, playerID, x1, z1, x2, z2, click)
		if not spec then
			local _, _, targetSpec, _, allyTeamID = GetPlayerInfo(playerID, false)
			if targetSpec or allyTeamID ~= myAllyTeamID then
				return
			end
		end
		if Script.LuaUI("MouseCursorEvent") then
			Script.LuaUI.MouseCursorEvent(playerID, x1, z1, x2, z2, click)
		end
	end

	function gadget:Update()
		updateTimer = updateTimer + GetLastUpdateSeconds()

		if updateTimer > updateTick then
			local mx, my = GetMouseState()
			local _, pos = TraceScreenRay(mx, my, true)

			if pos and (n == 1 or pos[1] ~= lastx or pos[3] ~= lastz) then -- only record change in position unless packet is already being instigated previous update tick
				local historyIdx = (n + 1) * 2
				poshistory[historyIdx] = PackU16(floor(pos[1]))
				poshistory[historyIdx + 1] = PackU16(floor(pos[3]))
				lastx, lastz = pos[1], pos[3]
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

	function gadget:MousePress(x, y, button)
		if button == 2 then
			return
		end
		local mx, my = GetMouseState()
		local _, pos = TraceScreenRay(mx, my, true)

		if not pos then
			return
		end
		if abs(pos[1] - lastx) > 300 or abs(pos[3] - lastz) > 300 then
			for i = 0, 5 do
				local posindex = i % 2 == 0 and 1 or 3
				poshistory[i] = PackU16(floor(pos[posindex]))
			end
			lastx, lastz = pos[1], pos[3]
			updateTick = saveEach
			updateTimer = 0
			n = 0
			sendPositionPacket("0")
		end
	end
end
