
local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Ally Selected Units",
		desc = "sends your selected units to others",
		author    = "very_bad_soldier",
		date      = "August 1, 2008",
		license   = "GNU GPL v2",
		layer     = 0,
		enabled = true
	}
end

local SelectionProtocol = assert(VFS.Include("common/selected_units_protocol.lua"))

local baseUpdateDelay = 0.1	-- start with 4 players
local maxUpdateDelay = 0.4	-- (0.4 currently reached when 128 players)
local updateDelayScalingStart = 4
local updateDelayPlayerScale = -math.log(0.6) / 12
local updateDelay = baseUpdateDelay
local deltaUnitLimitPerMessage = 400
local semanticSelectionMinChanges = 16
local semanticConfirmationDelay = 1
local maxSelectionPayloadSize = 2048
local fullSelectionUpdateInt = 0 -- refresh full selection info once in n seconds, 0 = disabled
local minZlibSize = 130  --minimum size threshold of msg to use zlib (msg smaller than this will not be compressed before sending)
local sendSpectatorSelections = false
local spectatorUpdateDelay = 1
local spectatorSelectionLimit = 400

local HEADER_SEL_UNCOMPRESSED = "cos2"
local HEADER_SEL_COMPRESSED = "cosz"
local HEADER_LENGTH = string.len(HEADER_SEL_UNCOMPRESSED)


if gadgetHandler:IsSyncedCode() then
	local validation = string.randomString(2)
	_G.validationSelunits = validation

	local vb1, vb2 = string.byte(validation, 1, 2)
	local h3, h4, h5 = string.byte(HEADER_SEL_UNCOMPRESSED, 1, 3)
	local uncompressedHeaderByte = string.byte(HEADER_SEL_UNCOMPRESSED, 4)
	local compressedHeaderByte = string.byte(HEADER_SEL_COMPRESSED, 4)
	local strSub = string.sub

	function gadget:RecvLuaMsg(inMsg, playerID)
		if #inMsg < HEADER_LENGTH + 2 or #inMsg > maxSelectionPayloadSize + HEADER_LENGTH + 2 then return end
		local b1, b2, b3, b4, b5, b6 = string.byte(inMsg, 1, 6)
		if b1 ~= vb1 or b2 ~= vb2 or b3 ~= h3 or b4 ~= h4 or b5 ~= h5 then return end

		local compressed
		if b6 == uncompressedHeaderByte or b6 == compressedHeaderByte then
			compressed = b6 == compressedHeaderByte
		else
			return
		end

		-- Replayed messages retain demo player IDs, whose spectator state cannot identify live spectators.
		local payload = strSub(inMsg, 7)
		SendToUnsynced("selectionUpdate", playerID, payload, compressed)
		return true
	end

else

	local ZlibCompress = Spring.ZlibCompress
	local ZlibDeCompress = Spring.ZlibDeCompress
	local SendLuaRulesMsg = Spring.SendLuaRulesMsg
	local GetSelectedUnits = Spring.GetSelectedUnits
	local GetSpectatingState = Spring.GetSpectatingState
	local GetLastUpdateSeconds = Spring.GetLastUpdateSeconds
	local GetPlayerInfo = Spring.GetPlayerInfo
	local GetPlayerList = Spring.GetPlayerList
	local GetTeamUnits = Spring.GetTeamUnits
	local GetTeamUnitsByDefs = Spring.GetTeamUnitsByDefs
	local GetTeamUnitsSorted = Spring.GetTeamUnitsSorted
	local LuaUICallIn = Script.LuaUI
	local LuaUI = Script.LuaUI
	local tSort = table.sort

	local myPlayerID = Spring.GetMyPlayerID()
	local _, _, myIsSpec, myTeamID, myAllyTeamID = GetPlayerInfo(myPlayerID, false)
	local CLEAR_ALL_MSG = SelectionProtocol.EncodeClear()

	local time = 0.0
	local timeSeconds = 0.0
	local myLastSelectedUnits = {}
	local myLastSelectedCount = 0
	local nextFullSelectionUpdateAt = fullSelectionUpdateInt
	local nextSpectatorSelectionUpdateAt = 0.0
	local packedUnitIDCache = {}
	local addUnitIDsBuffer = {}
	local remUnitIDsBuffer = {}
	local selectedNowMap = {}
	local semanticConfirmationPending = false
	local nextSemanticConfirmationAt = 0.0
	local selectionUpdatePending = false
	local nextSelectionUpdateAt = 0.0
	local validation = SYNCED.validationSelunits

	local function PackUnitIDCached(unitID)
		local packed = packedUnitIDCache[unitID]
		if packed == nil then
			packed = string.char(math.floor(unitID % 256), math.floor(unitID / 256))
			packedUnitIDCache[unitID] = packed
		end
		return packed
	end

	local function replaceLastSelection(units, unitCount)
		for unitID in pairs(myLastSelectedUnits) do
			myLastSelectedUnits[unitID] = nil
		end
		for i = 1, unitCount do
			myLastSelectedUnits[units[i]] = true
		end
		myLastSelectedCount = unitCount
	end

	local function clearSelectedNowMap(units, unitCount)
		for i = 1, unitCount do
			selectedNowMap[units[i]] = nil
		end
	end

	local function dispatchBatchUpdate(playerID, addUnits, addCount, removeUnits, removeCount)
		if LuaUICallIn("SelectedUnitsBatchUpdate") then
			LuaUI.SelectedUnitsBatchUpdate(playerID, addUnits, addCount, removeUnits, removeCount)
			return
		end

		if removeCount > 0 and LuaUICallIn("SelectedUnitsRemove") then
			for i = 1, removeCount do
				LuaUI.SelectedUnitsRemove(playerID, removeUnits[i])
			end
		end
		if addCount > 0 and LuaUICallIn("SelectedUnitsAdd") then
			for i = 1, addCount do
				LuaUI.SelectedUnitsAdd(playerID, addUnits[i])
			end
		end
	end

	local function dispatchSelectionSet(playerID, units, unitCount)
		if LuaUICallIn("SelectedUnitsClear") then
			LuaUI.SelectedUnitsClear(playerID)
		end
		if unitCount > 0 then
			dispatchBatchUpdate(playerID, units, unitCount, nil, 0)
		end
	end

	local function refreshUpdateDelay()
		local humanPlayerCount = 0
		local playerList = GetPlayerList()
		for i = 1, #playerList do
			local _, _, isSpec = GetPlayerInfo(playerList[i], false)
			if isSpec == false then
				humanPlayerCount = humanPlayerCount + 1
			end
		end

		if humanPlayerCount <= updateDelayScalingStart then
			updateDelay = baseUpdateDelay
			return
		end

		local excessPlayers = humanPlayerCount - updateDelayScalingStart
		updateDelay = baseUpdateDelay
			+ (maxUpdateDelay - baseUpdateDelay) * (1 - math.exp(-updateDelayPlayerScale * excessPlayers))
	end

	function gadget:Initialize()
		_, _, myIsSpec, myTeamID, myAllyTeamID = GetPlayerInfo(myPlayerID, false)
		refreshUpdateDelay()
		gadgetHandler:AddSyncAction("selectionUpdate", handleSelectionUpdateEvent)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction("selectionUpdate")
	end

	function gadget:PlayerChanged(playerID)
		if playerID == myPlayerID then
			_, _, myIsSpec, myTeamID, myAllyTeamID = GetPlayerInfo(myPlayerID, false)
		end
		refreshUpdateDelay()
	end

	function gadget:PlayerAdded()
		refreshUpdateDelay()
	end

	function gadget:PlayerRemoved()
		refreshUpdateDelay()
	end

	function handleSelectionUpdateEvent(_, playerID, msg, compressed)
		local spec = GetSpectatingState()
		local _, _, targetSpec, targetTeamID, allyTeamID = GetPlayerInfo(playerID, false)
		if not spec then
			if targetSpec or allyTeamID ~= myAllyTeamID then
				return
			end
		end

		if compressed then
			if not ZlibDeCompress then return end
			local success, decompressed = pcall(ZlibDeCompress, msg)
			if not success then return end
			msg = decompressed
		end
		if type(msg) ~= "string" or #msg > maxSelectionPayloadSize then
			return
		end

		local decoded = SelectionProtocol.Decode(msg, targetTeamID, GetTeamUnits, GetTeamUnitsByDefs)
		if not decoded then
			return
		end
		if decoded.kind == "set" then
			dispatchSelectionSet(playerID, decoded.units, decoded.count)
		else
			dispatchBatchUpdate(playerID, decoded.addUnits, decoded.addCount, decoded.removeUnits, decoded.removeCount)
		end
	end

	function gadget:CommandsChanged( id, params, options )
		selectionUpdatePending = true
		nextSelectionUpdateAt = timeSeconds + updateDelay
		sendSelectedUnits()
	end

	function gadget:Update()
		local deltaTime = GetLastUpdateSeconds() or 0
		if time+deltaTime == time then
			time = 0 --prevent floating point errors
		end
		time = time + deltaTime
		timeSeconds = timeSeconds + deltaTime

		local periodicUpdateDue = time >= updateDelay
		local pendingUpdateDue = selectionUpdatePending and timeSeconds >= nextSelectionUpdateAt
		if not periodicUpdateDue and not pendingUpdateDue then
			return
		end
		if periodicUpdateDue then
			time = 0
		end

		if fullSelectionUpdateInt ~= 0 and timeSeconds >= nextFullSelectionUpdateAt then
			--its time for a full update
			sendUnitsMsg(CLEAR_ALL_MSG, true)
			replaceLastSelection({}, 0)
			semanticConfirmationPending = false
			repeat
				nextFullSelectionUpdateAt = nextFullSelectionUpdateAt + fullSelectionUpdateInt
			until nextFullSelectionUpdateAt > timeSeconds
		end

		local updateAccepted = sendSelectedUnits(pendingUpdateDue)
		if pendingUpdateDue then
			if updateAccepted then
				selectionUpdatePending = false
			else
				nextSelectionUpdateAt = nextSpectatorSelectionUpdateAt
			end
		end
	end

	function sendUnitsMsg(msg, allowCompression)
		local finalMsg = msg
		local header = HEADER_SEL_UNCOMPRESSED
		if allowCompression and ZlibCompress and #msg >= minZlibSize then
			finalMsg = ZlibCompress(finalMsg)
			header = HEADER_SEL_COMPRESSED
		end

		SendLuaRulesMsg(validation .. header .. finalMsg)
	end

	local function sendSpectatorSelection(units, unitCount, forceSnapshot)
		if timeSeconds < nextSpectatorSelectionUpdateAt then
			return false
		end
		nextSpectatorSelectionUpdateAt = timeSeconds + spectatorUpdateDelay

		if unitCount > spectatorSelectionLimit then
			tSort(units)
			unitCount = spectatorSelectionLimit
		end
		local changed = unitCount ~= myLastSelectedCount
		if not changed then
			for i = 1, unitCount do
				if not myLastSelectedUnits[units[i]] then
					changed = true
					break
				end
			end
		end
		if not changed and not forceSnapshot then return true end

		if unitCount == 0 then
			sendUnitsMsg(CLEAR_ALL_MSG, false)
		else
			local plan = {
				opcode = SelectionProtocol.OP_SET_EXPLICIT,
				units = units,
				unitCount = unitCount,
			}
			sendUnitsMsg(SelectionProtocol.EncodeSnapshot(plan, PackUnitIDCached), false)
		end
		replaceLastSelection(units, unitCount)
		semanticConfirmationPending = false
		return true
	end

	function sendSelectedUnits(forceSnapshot)
		local units = GetSelectedUnits()
		local unitCount = #units
		if myIsSpec then
			if not sendSpectatorSelections then
				return true
			end
			return sendSpectatorSelection(units, unitCount, forceSnapshot)
		end

		if unitCount == 0 then
			if forceSnapshot or myLastSelectedCount > 0 then
				sendUnitsMsg(CLEAR_ALL_MSG, true)
				replaceLastSelection(units, 0)
			end
			semanticConfirmationPending = false
			return true
		end

		for i=1,unitCount do
			selectedNowMap[units[i]] = true
		end

		local addUnits = addUnitIDsBuffer
		local addCount = 0
		local totalAddCount = 0
		for i = 1, unitCount do
			local unitID = units[i]
			if not myLastSelectedUnits[unitID] then
				totalAddCount = totalAddCount + 1
				if addCount < deltaUnitLimitPerMessage then
					addCount = addCount + 1
					addUnits[addCount] = unitID
				end
			end
		end

		local removeUnits = remUnitIDsBuffer
		local remCount = 0
		local totalRemCount = 0
		for unitID in pairs(myLastSelectedUnits) do
			if not selectedNowMap[unitID] then
				totalRemCount = totalRemCount + 1
				if addCount + remCount < deltaUnitLimitPerMessage then
					remCount = remCount + 1
					removeUnits[remCount] = unitID
				end
			end
		end

		local totalChanges = totalAddCount + totalRemCount
		if totalChanges == 0 and not forceSnapshot then
			if semanticConfirmationPending and timeSeconds >= nextSemanticConfirmationAt then
				local confirmationPlan = SelectionProtocol.BuildSnapshotPlan(units, unitCount, GetTeamUnitsSorted(myTeamID) or {})
				if confirmationPlan.byteLength <= maxSelectionPayloadSize then
					sendUnitsMsg(SelectionProtocol.EncodeSnapshot(confirmationPlan, PackUnitIDCached), true)
				else
					sendUnitsMsg(CLEAR_ALL_MSG, true)
					replaceLastSelection({}, 0)
				end
				semanticConfirmationPending = false
			end
			clearSelectedNowMap(units, unitCount)
			return true
		end

		local fullDeltaLength = 5 + totalChanges * 2
		local snapshotPlan
		local explicitLength = 3 + unitCount * 2
		if explicitLength <= maxSelectionPayloadSize and (forceSnapshot or explicitLength <= fullDeltaLength) then
			snapshotPlan = {
				opcode = SelectionProtocol.OP_SET_EXPLICIT,
				units = units,
				unitCount = unitCount,
				byteLength = explicitLength,
			}
		end

		if not snapshotPlan and (forceSnapshot or totalChanges >= semanticSelectionMinChanges or semanticConfirmationPending) then
			local teamUnitsByDef = GetTeamUnitsSorted(myTeamID) or {}
			local semanticPlan = SelectionProtocol.BuildSnapshotPlan(units, unitCount, teamUnitsByDef)
			if semanticPlan.byteLength <= maxSelectionPayloadSize
				and (forceSnapshot or semanticConfirmationPending or semanticPlan.byteLength < fullDeltaLength)
				and (not snapshotPlan or semanticPlan.byteLength < snapshotPlan.byteLength)
			then
				snapshotPlan = semanticPlan
			end
		end

		if snapshotPlan then
			sendUnitsMsg(SelectionProtocol.EncodeSnapshot(snapshotPlan, PackUnitIDCached), true)
			replaceLastSelection(units, unitCount)
			if snapshotPlan.opcode == SelectionProtocol.OP_SET_TEAM or snapshotPlan.opcode == SelectionProtocol.OP_SET_DEFS then
				semanticConfirmationPending = true
				nextSemanticConfirmationAt = timeSeconds + semanticConfirmationDelay
			else
				semanticConfirmationPending = false
			end
		elseif semanticConfirmationPending then
			sendUnitsMsg(CLEAR_ALL_MSG, true)
			replaceLastSelection({}, 0)
			semanticConfirmationPending = false
		else
			sendUnitsMsg(SelectionProtocol.EncodeDelta(addUnits, addCount, removeUnits, remCount, PackUnitIDCached), true)
			for i = 1, addCount do
				myLastSelectedUnits[addUnits[i]] = true
			end
			for i = 1, remCount do
				myLastSelectedUnits[removeUnits[i]] = nil
				removeUnits[i] = nil
			end
			myLastSelectedCount = myLastSelectedCount + addCount - remCount
			semanticConfirmationPending = false
		end
		clearSelectedNowMap(units, unitCount)
		return true
	end
end
