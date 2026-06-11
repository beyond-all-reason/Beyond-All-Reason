local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Ally Selected Units",
		desc = "sends your selected units to others",
		author = "very_bad_soldier",
		date = "August 1, 2008",
		license = "GNU GPL v2",
		layer = 0,
		enabled = true,
	}
end

local updateDelay = 0.25
local unitLimitPerFrame = 400 -- controls how many units will be send per frame
local fullSelectionUpdateInt = 0 -- refresh full selection info once in n seconds, 0 = disabled
local minZlibSize = 130 --minimum size threshold of msg to use zlib (msg smaller than this will not be compressed before sending)

local HEADER_SEL_UNCOMPRESSED = "cosu"
local HEADER_SEL_COMPRESSED = "cosc"
local HEADER_LENGTH = string.len(HEADER_SEL_UNCOMPRESSED)

if gadgetHandler:IsSyncedCode() then
	local validation = string.randomString(2)
	_G.validationSelunits = validation

	function gadget:RecvLuaMsg(inMsg, playerID)
		if inMsg:sub(1, 2) == validation and (inMsg:sub(3, HEADER_LENGTH + 2) == HEADER_SEL_UNCOMPRESSED or inMsg:sub(3, HEADER_LENGTH + 2) == HEADER_SEL_COMPRESSED) then
			SendToUnsynced("selectionUpdate", playerID, inMsg:sub(7), inMsg:sub(6, 6) == "c")
			return true
		end
	end
else
	local tConcat = table.concat
	local ZlibCompress = Spring.ZlibCompress
	local ZlibDeCompress = Spring.ZlibDeCompress
	local SendLuaRulesMsg = Spring.SendLuaRulesMsg
	local GetSelectedUnits = Spring.GetSelectedUnits
	local GetSpectatingState = Spring.GetSpectatingState
	local GetLastUpdateSeconds = Spring.GetLastUpdateSeconds
	local GetPlayerInfo = Spring.GetPlayerInfo
	local PackU16 = VFS.PackU16
	local UnpackU16 = VFS.UnpackU16
	local LuaUICallIn = Script.LuaUI
	local LuaUI = Script.LuaUI

	local myPlayerID = Spring.GetMyPlayerID()
	local myAllyTeamID = select(5, GetPlayerInfo(myPlayerID, false))
	local PACK_FFFF = PackU16(0xffff)
	local CLEAR_ALL_MSG = PACK_FFFF .. PACK_FFFF

	local time = 0
	local timeSeconds = 0
	local myLastSelectedUnits = {}
	local nextFullSelectionUpdateAt = fullSelectionUpdateInt
	local packedUnitIDCache = {}
	local addPackedBuffer = {}
	local remPackedBuffer = {}
	local remUnitIDsBuffer = {}
	local selectedNowMap = {}
	local validation = SYNCED.validationSelunits

	local function PackUnitIDCached(unitID)
		local packed = packedUnitIDCache[unitID]
		if packed == nil then
			packed = PackU16(unitID)
			packedUnitIDCache[unitID] = packed
		end
		return packed
	end

	function gadget:Initialize()
		myAllyTeamID = select(5, GetPlayerInfo(myPlayerID, false))
		gadgetHandler:AddSyncAction("selectionUpdate", handleSelectionUpdateEvent)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction("selectionUpdate")
	end

	function gadget:PlayerChanged(playerID)
		if playerID == myPlayerID then
			myAllyTeamID = select(5, GetPlayerInfo(myPlayerID, false))
		end
	end

	function handleSelectionUpdateEvent(_, playerID, msg, compressed)
		local spec = GetSpectatingState()
		if not spec then
			local _, _, targetSpec, _, allyTeamID = GetPlayerInfo(playerID, false)
			if targetSpec or allyTeamID ~= myAllyTeamID then
				return
			end
		end

		if compressed then -- we have a compressed msg here
			msg = ZlibDeCompress(msg)
		end

		local counts = UnpackU16(msg, 1, 2)
		if counts[1] == counts[2] and counts[1] == 0xffff then
			--clear all
			if LuaUICallIn("selectedUnitsClear") then
				LuaUI.selectedUnitsClear(playerID)
			end
		else
			local addCount = counts[1]
			local removeCount = counts[2]
			local addUnits
			local remUnits

			if addCount > 0 then
				addUnits = UnpackU16(msg, 5, addCount)
			end

			if removeCount > 0 then
				remUnits = UnpackU16(msg, 5 + addCount * 2, removeCount)
			end

			if LuaUICallIn("selectedUnitsBatchUpdate") then
				LuaUI.selectedUnitsBatchUpdate(playerID, addUnits, addCount, remUnits, removeCount)
				return
			end

			if removeCount > 0 and LuaUICallIn("selectedUnitsRemove") then
				for i = 1, removeCount do
					LuaUI.selectedUnitsRemove(playerID, remUnits[i])
				end
			end

			if addCount > 0 and LuaUICallIn("selectedUnitsAdd") then
				for i = 1, addCount do
					LuaUI.selectedUnitsAdd(playerID, addUnits[i])
				end
			end
		end
	end

	function gadget:CommandsChanged(id, params, options)
		sendSelectedUnits()
	end

	function gadget:UnitDestroyed(unitID, attacker)
		myLastSelectedUnits[unitID] = nil
	end

	function gadget:Update()
		local deltaTime = GetLastUpdateSeconds()
		if time + deltaTime == time then
			time = 0 --prevent floating point errors
		end
		time = time + deltaTime
		timeSeconds = timeSeconds + deltaTime

		if time < updateDelay then
			return
		end
		time = 0

		if fullSelectionUpdateInt ~= 0 and timeSeconds >= nextFullSelectionUpdateAt then
			--its time for a full update
			sendUnitsMsg(CLEAR_ALL_MSG)
			myLastSelectedUnits = {}
			repeat
				nextFullSelectionUpdateAt = nextFullSelectionUpdateAt + fullSelectionUpdateInt
			until nextFullSelectionUpdateAt > timeSeconds
		end

		sendSelectedUnits()
	end

	--all values are 16bit
	--FORMAT: uncompressed msg "cosu[addCount][removeCount]([unitIdToAdd]*)([unitIdToRemove]*)"
	--FORMAT: compressed msg "cosc{[addCount][removeCount]([unitIdToAdd]*)([unitIdToRemove]*)}"  the part in curly braces has to be zlib compressed
	--FORMAT clear all: "cosu[0xffffff][0xffffff]"  --magic value. impossible to have as normal message

	function sendUnitsMsg(msg)
		local finalMsg = msg
		local header = HEADER_SEL_UNCOMPRESSED
		if ZlibCompress and msg:len() >= minZlibSize then
			finalMsg = ZlibCompress(finalMsg)
			header = HEADER_SEL_COMPRESSED
		end

		SendLuaRulesMsg(validation .. header .. finalMsg)
	end

	function sendSelectedUnits()
		local units = GetSelectedUnits()
		local unitCount = #units

		if unitCount == 0 then
			if next(myLastSelectedUnits) ~= nil then
				sendUnitsMsg(CLEAR_ALL_MSG)
				myLastSelectedUnits = {}
			end
			return
		end

		for i = 1, unitCount do
			selectedNowMap[units[i]] = true
		end

		local addPacked = addPackedBuffer
		local addCount = 0
		for i = 1, unitCount do
			local unitId = units[i]
			--check if unit is new this time
			if not myLastSelectedUnits[unitId] then
				addCount = addCount + 1
				addPacked[addCount] = PackUnitIDCached(unitId)
				myLastSelectedUnits[unitId] = true

				if addCount >= unitLimitPerFrame then
					break
				end
			end
		end

		local remPacked = remPackedBuffer
		local remUnitIDs = remUnitIDsBuffer
		local remCount = 0
		for unitId, unit in pairs(myLastSelectedUnits) do
			--check if unit is still selected
			if not selectedNowMap[unitId] then
				remCount = remCount + 1
				remPacked[remCount] = PackUnitIDCached(unitId)
				remUnitIDs[remCount] = unitId

				if (addCount + remCount) >= unitLimitPerFrame then
					break
				end
			end
		end

		--remove not anymore selected units
		for i = 1, remCount do
			myLastSelectedUnits[remUnitIDs[i]] = nil
			remUnitIDs[i] = nil
		end

		for i = 1, unitCount do
			selectedNowMap[units[i]] = nil
		end

		if addCount == 0 and remCount == 0 then
			return
		end

		if (addCount + remCount) > unitCount then
			-- More efficient to rebase state than send many removals.
			sendUnitsMsg(CLEAR_ALL_MSG)
			myLastSelectedUnits = {}
			for i = 1, unitCount do
				local unitId = units[i]
				myLastSelectedUnits[unitId] = true
			end

			addCount = unitCount
			for i = 1, unitCount do
				addPacked[i] = PackUnitIDCached(units[i])
			end
			remCount = 0
		end

		local msg = PackU16(addCount) .. PackU16(remCount) .. tConcat(addPacked, "", 1, addCount) .. tConcat(remPacked, "", 1, remCount)
		sendUnitsMsg(msg)
	end
end
