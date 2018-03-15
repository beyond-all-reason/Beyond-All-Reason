
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

local unitLimitPerFrame = 300 -- controls how many units will be send per frame
local fullSelectionUpdateInt = 0 -- refresh full selection info once in n seconds, 0 = disabled
local minZlibSize = 130  --minimum size threshold of msg to use zlib (msg smaller than this will not be compressed before sending)

local HEADER_SEL_UNCOMPRESSED = "cosu"
local HEADER_SEL_COMPRESSED = "cosc"
local HEADER_LENGHT = string.len(HEADER_SEL_UNCOMPRESSED)



if gadgetHandler:IsSyncedCode() then
	local charset = {}  do -- [0-9a-zA-Z]
		for c = 48, 57  do table.insert(charset, string.char(c)) end
		for c = 65, 90  do table.insert(charset, string.char(c)) end
		for c = 97, 122 do table.insert(charset, string.char(c)) end
	end
	local function randomString(length)
		if not length or length <= 0 then return '' end
		--math.randomseed(os.clock()^5)
		return randomString(length - 1) .. charset[math.random(1, #charset)]
	end

	local validation = randomString(2)
	_G.validationSelunits = validation

	function gadget:RecvLuaMsg(inMsg, playerID)
		if inMsg:sub(1,2)==validation and (inMsg:sub(3,HEADER_LENGHT+2)==HEADER_SEL_UNCOMPRESSED or inMsg:sub(3,HEADER_LENGHT+2)==HEADER_SEL_COMPRESSED) then
			SendToUnsynced("selectionUpdate",playerID,inMsg:sub(7),inMsg:sub(6,6) == "c")
			return true
		end
	end
else
	local floor = math.floor
	local ZlibCompress = Spring.ZlibCompress
	local ZlibDeCompress = Spring.ZlibDeCompress
	local SendLuaRulesMsg = Spring.SendLuaRulesMsg
	local GetSelectedUnits = Spring.GetSelectedUnits
	local IsUnitSelected = Spring.IsUnitSelected
	local GetSpectatingState = Spring.GetSpectatingState
	local GetLastUpdateSeconds = Spring.GetLastUpdateSeconds
	local GetPlayerInfo = Spring.GetPlayerInfo
	local PackU16 = VFS.PackU16
	local UnpackU16 = VFS.UnpackU16

	local myPlayerID = Spring.GetMyPlayerID()

	local time = 0
	local timeSeconds = 0
	local myLastSelectedUnits = {}
	local validation = SYNCED.validationSelunits

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("selectionUpdate", handleSelectionUpdateEvent)
	end
	
	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction("selectionUpdate")
	end

	function handleSelectionUpdateEvent(_,playerID,msg,compressed)
		local spec, fullView = GetSpectatingState()
		if not spec or not fullView then
			local _,_,_,_,myAllyTeamID = GetPlayerInfo(myPlayerID)
			local _,_,targetSpec,_,allyTeamID = GetPlayerInfo(playerID)
			if targetSpec or allyTeamID ~= myAllyTeamID then
				return
			end
		end
			
		if compressed then		--we have a compressed msg here
			msg = ZlibDecompress( msg )
		end
		
		local counts = UnpackU16( msg, 1, 2 )
		if counts[1] == counts[2] and counts[1] == 0xffff then
			--clear all
			if Script.LuaUI("selectedUnitsClear") then
				Script.LuaUI.selectedUnitsClear(playerID)
			end
		else
			local addCount = counts[1]
			local removeCount = counts[2]

			if removeCount > 0 and Script.LuaUI("selectedUnitsRemove") then
				local remUnits = UnpackU16( msg, 5 + addCount * 2, removeCount )
				for i=1,removeCount do
					Script.LuaUI.selectedUnitsRemove(playerID,remUnits[i])
				end
			end

			if addCount > 0 and Script.LuaUI("selectedUnitsAdd") then
				local addUnits = UnpackU16( msg, 5, addCount )
				for i=1,addCount do
					Script.LuaUI.selectedUnitsAdd(playerID,addUnits[i])
				end
			end
		end
	end

	function gadget:CommandsChanged( id, params, options )
		sendSelectedUnits()
	end

	function gadget:UnitDestroyed(unitID, attacker )
		myLastSelectedUnits[ unitID ] = nil
	end

	function gadget:Update()
		local deltaTime = GetLastUpdateSeconds()
		if time+deltaTime == time then
			time = 0 --prevent floating point errors
		end
		time = time + deltaTime

		if timeSeconds == floor(time) then
			return --only run on whole seconds
		end

		timeSeconds = floor(time)
		
		if fullSelectionUpdateInt ~= 0 and timeSeconds%fullSelectionUpdateInt == 0 then
			--its time for a full update
			sendUnitsMsg(PackU16(0xffff) .. PackU16(0xffff))
			myLastSelectedUnits = {}
		end

		sendSelectedUnits()
	end

	--all values are 16bit
	--FORMAT: uncompressed msg "cosu[addCount][removeCount]([unitIdToAdd]*)([unitIdToRemove]*)"
	--FORMAT: compressed msg "cosc{[addCount][removeCount]([unitIdToAdd]*)([unitIdToRemove]*)}"  the part in curly braces has to be zlib compressed 
	--FORMAT clear all: "cosu[0xffffff][0xffffff]"  --magic value. impossible to have as normal message

	function sendFullRefresh()

	end

	function sendUnitsMsg( msg )
		local finalMsg = msg
		local header = HEADER_SEL_UNCOMPRESSED
		if ZlibCompress and msg:len() >= minZlibSize then
			finalMsg = ZlibCompress( finalMsg ) 
			header = HEADER_SEL_COMPRESSED
		end
		
		SendLuaRulesMsg(validation .. header .. finalMsg)
	end

	function sendSelectedUnits()
		local units = GetSelectedUnits()
		
		local partAdd = ""
		local addCount = 0
		for i, unitId in pairs(units) do
			--check if unit is new this time
			if not myLastSelectedUnits[unitId] then
				partAdd = partAdd .. PackU16(unitId)
				myLastSelectedUnits[unitId] = true
				addCount = addCount + 1
				
				if addCount > unitLimitPerFrame then
					break
				end
			end
		end

		local remTab = {} --these units will be removed in the next step
		local partRemove = ""
		local remCount = 0
		for unitId, unit in pairs(myLastSelectedUnits) do
			--check if unit is still selected
			if not IsUnitSelected(unitId) then
				partRemove = partRemove .. PackU16(unitId)
				remTab[unitId] = true
				remCount = remCount + 1
				
				if (addCount + remCount) > unitLimitPerFrame then
					break
				end
			end
		end
		
		--remove not anymore selected units
		for unitId, b in pairs(remTab) do
			myLastSelectedUnits[unitId] = nil
		end
		
		local msg = partAdd .. partRemove
		if msg:len() > 1 then
			local msgToSend = ""
			if #units > 0 and ( addCount + remCount) > #units then
				--its more efficient to clear all and then start from zero
				--so: 1. Clear All
				msgToSend = PackU16(0xffff) .. PackU16(0xffff)
				sendUnitsMsg( msgToSend)
				myLastSelectedUnits = {}
				--2. do normal send
				sendSelectedUnits()
			else
				if #units == 0 then
					--send clear all message
					msgToSend = PackU16(0xffff) .. PackU16(0xffff)
					myLastSelectedUnits = {}
				else
					--send standard message
					msgToSend = PackU16(addCount) .. PackU16(remCount) .. msg
					
				end
				
				sendUnitsMsg( msgToSend)
			end
		end
	end
end