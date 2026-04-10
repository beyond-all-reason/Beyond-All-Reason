
if Spring.Utilities.Gametype.IsSinglePlayer() then
	return
end

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name = "Take Manager",
        desc = "Handles players AFK and drops",
        author = "BrainDamage",
        date = "2012",
        license = "WTFPL",
        layer = 1,
        enabled = true
    }
end

local maxIdleTreshold = 80 --in seconds
local warningPeriod = 15
local maxPing = 33 -- in seconds
local finishedResumingPing = 2 --in seconds
local maxInitialQueueSlack = 150 -- in seconds
local takeCommand = "take2"
local minTimeToTake = 12 -- in seconds
local checkQueueTime = 25 -- in seconds
-- in chose ingame startpostype, players must place beforehand, so take an action, grace period can be shorter
minTimeToTake = Spring.GetModOptions().startpostype == 2 and 1 or minTimeToTake

local AFKMessage = 'idleplayers '
local AFKMessageSize = #AFKMessage

local errorKeys = {
	shareAFK = 'shareAFK',
	takeEnemies = 'takeEnemies',
	nothingToTake = 'nothingToTake',
}

if gadgetHandler:IsSyncedCode() then

	local ModeEnums = VFS.Include("modes/sharing_mode_enums.lua")
	local Shared = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_shared.lua")
	local TakeComms = VFS.Include("common/luaUtilities/team_transfer/take_comms.lua")

	local playerInfoTable = {}
	local currentGameFrame = 0

	local TransferUnit = Spring.TransferUnit
	local GetPlayerList = Spring.GetPlayerList
	local GetPlayerInfo = Spring.GetPlayerInfo
	local GetTeamLuaAI = Spring.GetTeamLuaAI
	local GetAIInfo = Spring.GetAIInfo
	local SetTeamRulesParam = Spring.SetTeamRulesParam
	local GetTeamRulesParam = Spring.GetTeamRulesParam
	local GetTeamUnits = Spring.GetTeamUnits
	local GetTeamInfo = Spring.GetTeamInfo
	local GetTeamList = Spring.GetTeamList
	local IsCheatingEnabled = Spring.IsCheatingEnabled

	local resourceList = {"metal","energy"}
	local gaiaTeamID = Spring.GetGaiaTeamID()
	local gameSpeed = Game.gameSpeed

	local modOptions = Spring.GetModOptions()
	local takeMode = modOptions[ModeEnums.ModOptions.TakeMode] or ModeEnums.TakeMode.Enabled
	local takeDelaySeconds = tonumber(modOptions[ModeEnums.ModOptions.TakeDelaySeconds]) or 30
	local takeDelayCategory = modOptions[ModeEnums.ModOptions.TakeDelayCategory] or ModeEnums.UnitCategory.Resource
	local pendingDelayedTakes = {}

	local function matchesCategory(unitDefID, category)
		if category == ModeEnums.UnitFilterCategory.All then
			return true
		end
		return Shared.IsShareableDef(unitDefID, category, UnitDefs)
	end

	local function stunUnit(unitID, seconds)
		local _, maxHealth = Spring.GetUnitHealth(unitID)
		if maxHealth and maxHealth > 0 then
			Spring.AddUnitDamage(unitID, maxHealth * 5, seconds * 30)
		end
	end

	local charset = {}  do -- [0-9a-zA-Z]
		for c = 48, 57  do table.insert(charset, string.char(c)) end
		for c = 65, 90  do table.insert(charset, string.char(c)) end
		for c = 97, 122 do table.insert(charset, string.char(c)) end
	end

	local function randomString(length)
		if not length or length <= 0 then return '' end
		return randomString(length - 1) .. charset[math.random(1, #charset)]
	end

	local validation = randomString(2)
	_G.validationIdle = validation

	local function CheckPlayerState(playerID)
		local newval = playerInfoTable[playerID]
		if not newval then
			return false
		end
		local ok = true
		ok = ok and newval.connected
		ok = ok and newval.player
		ok = ok and newval.pingOK
		ok = ok and newval.present
		return ok
	end

	local function updatePlayersInfo()
		local TeamToRemainingPlayers = {}
		local aiOwners = {}
		for _,teamID in ipairs(GetTeamList()) do --initialize team count
			if select(4,GetTeamInfo(teamID,false)) then
				-- store who hosts that engine ai, team will be controlled if player is present
				local aiHost = select(3,GetAIInfo(teamID))
				local hostedAis = aiOwners[aiHost] or {}
				hostedAis[#hostedAis+1] = teamID
				aiOwners[aiHost] = hostedAis
			end
			-- lua ai and gaia are always controlled
			local luaAI = GetTeamLuaAI(teamID)
			if teamID == gaiaTeamID or (luaAI and luaAI ~= "") then
				TeamToRemainingPlayers[teamID] = 1
			else
				TeamToRemainingPlayers[teamID] = 0
			end
		end
		for _,playerID in ipairs(GetPlayerList()) do -- update player infos
			local name,active,spectator,teamID,allyTeamID,ping = GetPlayerInfo(playerID,false)
			local playerInfoTableEntry = playerInfoTable[playerID] or {}
			playerInfoTableEntry.connected = active
			playerInfoTableEntry.player = not spectator
			local pingTreshold = maxPing
			local oldPingOk = playerInfoTableEntry.pingOK
			if oldPingOk == false then
				pingTreshold = finishedResumingPing -- use smaller threshold to determine finished resuming
			end
			playerInfoTableEntry.pingOK = ping < pingTreshold
			if not spectator then
				if oldPingOk and not playerInfoTableEntry.pingOK then
					SendToUnsynced("PlayerLagging", name)
				elseif oldPingOk == false and playerInfoTableEntry.pingOK and playerInfoTableEntry.connected then
					SendToUnsynced("PlayerResumed", name)
				end
			end
			if playerInfoTableEntry.present == nil then
				playerInfoTableEntry.present = false -- initialize to afk
			end
			playerInfoTable[playerID] = playerInfoTableEntry

			-- mark hosted ais as controlled
			local hostedAis = aiOwners[playerID]
			if hostedAis then
				-- a player only needs to be connected and low enough ping to host an ai
				if playerInfoTableEntry.connected  and playerInfoTableEntry.pingOK then
					for _,aiTeamID in ipairs(hostedAis) do
						TeamToRemainingPlayers[aiTeamID] = TeamToRemainingPlayers[aiTeamID] + 1
					end
				end
			end

			if CheckPlayerState(playerID) then -- bump amount of active players in a team
				TeamToRemainingPlayers[teamID] = TeamToRemainingPlayers[teamID] + 1
			end
		end

		for teamID, teamCount in pairs(TeamToRemainingPlayers) do
			-- set to a public readable value that there's nobody controlling the team
			SetTeamRulesParam(teamID, "numActivePlayers", teamCount )
		end
	end

	local function transferResources(fromTeamID, toTeamID)
		for _, resourceName in ipairs(resourceList) do
			local shareAmount = GG.GetTeamResources(fromTeamID, resourceName)
			local current,storage,_,_,_,shareSlider = GG.GetTeamResources(toTeamID, resourceName)
			shareAmount = math.min(shareAmount, shareSlider * storage - current)
			GG.ShareTeamResource(fromTeamID, toTeamID, resourceName, shareAmount)
		end
	end

	local function getPlayerName(pID)
		local name = GetPlayerInfo(pID, false)
		return name or ("Player " .. pID)
	end

	local function getTeamLeaderName(tID)
		local _, leaderID = GetTeamInfo(tID, false)
		if leaderID then
			return getPlayerName(leaderID)
		end
		return "Team " .. tID
	end

	local function notifyTake(playerID, result)
		local msg = TakeComms.FormatMessage(result)
		if msg and msg ~= "" then
			SendToUnsynced("TakeNotify", playerID, msg)
		end
	end

	local function takeTeam(cmd, line, words, playerID)
		if not CheckPlayerState(playerID) then
			SendToUnsynced("NotifyError", playerID, errorKeys.shareAFK)
			return
		end

		local takerName = getPlayerName(playerID)

		if takeMode == ModeEnums.TakeMode.Disabled then
			notifyTake(playerID, { mode = takeMode, takerName = takerName, sourceName = "", transferred = 0, stunned = 0, delayed = 0, total = 0, category = takeDelayCategory, delaySeconds = takeDelaySeconds })
			return
		end

		Spring.SetGameRulesParam("isTakeInProgress", 1)
		local targetTeam = tonumber(words[1])
		local _,_,_,takerID,allyTeamID = GetPlayerInfo(playerID,false)
		local teamList = GetTeamList(allyTeamID)
		if targetTeam then
			if select(6, GetTeamInfo(targetTeam, false)) ~= allyTeamID then
				SendToUnsynced("NotifyError", playerID, errorKeys.takeEnemies)
				return
			end
			teamList = {targetTeam}
		end
		local numToTake = 0
		for _,teamID in ipairs(teamList) do
			if GetTeamRulesParam(teamID,"numActivePlayers") == 0 then
				numToTake = numToTake + 1
				local sourceName = getTeamLeaderName(teamID)

				if takeMode == ModeEnums.TakeMode.Enabled then
					local teamUnits = GetTeamUnits(teamID)
					local transferred = #teamUnits
					for i=1, #teamUnits do
						TransferUnit(teamUnits[i], takerID)
					end
					transferResources(teamID, takerID)
					notifyTake(playerID, { mode = takeMode, takerName = takerName, sourceName = sourceName, transferred = transferred, stunned = 0, delayed = 0, total = transferred, category = takeDelayCategory, delaySeconds = 0 })

				elseif takeMode == ModeEnums.TakeMode.StunDelay then
					local teamUnits = GetTeamUnits(teamID)
					local transferred = #teamUnits
					for i=1, #teamUnits do
						TransferUnit(teamUnits[i], takerID)
					end
					local stunned = 0
					if takeDelaySeconds > 0 then
						for _, unitID in ipairs(GetTeamUnits(takerID)) do
							local unitDefID = Spring.GetUnitDefID(unitID)
							if unitDefID and matchesCategory(unitDefID, takeDelayCategory) then
								stunUnit(unitID, takeDelaySeconds)
								stunned = stunned + 1
							end
						end
					end
					transferResources(teamID, takerID)
					notifyTake(playerID, { mode = takeMode, takerName = takerName, sourceName = sourceName, transferred = transferred, stunned = stunned, delayed = 0, total = transferred, category = takeDelayCategory, delaySeconds = takeDelaySeconds })

				elseif takeMode == ModeEnums.TakeMode.TakeDelay then
					local pending = pendingDelayedTakes[teamID]
					local delayFrames = takeDelaySeconds * 30

					if pending and pending.takerTeamID == takerID then
						if currentGameFrame >= pending.expiryFrame then
							local units = GetTeamUnits(teamID)
							local transferred = #units
							for _, unitID in ipairs(units) do
								TransferUnit(unitID, takerID)
							end
							transferResources(teamID, takerID)
							pendingDelayedTakes[teamID] = nil
							notifyTake(playerID, { mode = takeMode, takerName = takerName, sourceName = sourceName, transferred = transferred, stunned = 0, delayed = 0, total = transferred, category = takeDelayCategory, delaySeconds = takeDelaySeconds, isSecondPass = true })
						else
							local remaining = math.ceil((pending.expiryFrame - currentGameFrame) / 30)
							notifyTake(playerID, { mode = takeMode, takerName = takerName, sourceName = sourceName, transferred = 0, stunned = 0, delayed = 0, total = 0, category = takeDelayCategory, delaySeconds = takeDelaySeconds, remainingSeconds = remaining })
						end
					else
						local units = GetTeamUnits(teamID)
						local total = #units
						local transferred = 0
						local delayed = 0
						for _, unitID in ipairs(units) do
							local unitDefID = Spring.GetUnitDefID(unitID)
							if unitDefID and not matchesCategory(unitDefID, takeDelayCategory) then
								TransferUnit(unitID, takerID)
								transferred = transferred + 1
							else
								delayed = delayed + 1
							end
						end
						pendingDelayedTakes[teamID] = {
							takerTeamID = takerID,
							expiryFrame = currentGameFrame + delayFrames,
						}
						notifyTake(playerID, { mode = takeMode, takerName = takerName, sourceName = sourceName, transferred = transferred, stunned = 0, delayed = delayed, total = total, category = takeDelayCategory, delaySeconds = takeDelaySeconds })
					end
				end
			end
		end
		Spring.SetGameRulesParam("isTakeInProgress", 0)
		if numToTake == 0 then
			SendToUnsynced("NotifyError", playerID, errorKeys.nothingToTake)
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddChatAction(takeCommand, takeTeam, "Take control of units and resources from inactive players")
		updatePlayersInfo()
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveChatAction(takeCommand)
	end


	function gadget:GameFrame(currentFrame)
		currentGameFrame = currentFrame
		if currentFrame == 10 then
			SendToUnsynced("OnGameStart")
		end
		if currentFrame % 15 ~= 0 then
			return
		end
		updatePlayersInfo()
	end

	function gadget:RecvLuaMsg(msg, playerID)
		if msg:sub(1,2)~=validation or msg:sub(3,2+AFKMessageSize) ~= AFKMessage then --invalid message
			return
		end
		local afk = tonumber(msg:sub(2+AFKMessageSize+1))
		local playerInfoTableEntry = playerInfoTable[playerID] or {}
		local previousPresent = playerInfoTableEntry.present
		playerInfoTableEntry.present = afk == 0
		playerInfoTable[playerID] = playerInfoTableEntry
		local name,active,spectator,teamID,allyTeamID,ping = GetPlayerInfo(playerID, false)
		if not spectator and name ~= nil then
			if currentGameFrame > minTimeToTake*gameSpeed then
				if previousPresent and not playerInfoTableEntry.present then
					SendToUnsynced("PlayerAFK", allyTeamID, name)
				elseif not previousPresent and playerInfoTableEntry.present then
					SendToUnsynced("PlayerReturned", allyTeamID, name)
				end
			end
		end
	end

else	-- UNSYNCED


	local GetLastUpdateSeconds = Spring.GetLastUpdateSeconds
	local SendLuaRulesMsg = Spring.SendLuaRulesMsg
	local GetMouseState = Spring.GetMouseState
	local GetGameSeconds = Spring.GetGameSeconds
	local GetUnitDefID = Spring.GetUnitDefID
	local GetRealBuildQueue = Spring.GetRealBuildQueue

	local min = math.min
	local max = math.max

	local lastActionTime = 0
	local timer = 0
	local updateTimer = 0
	local gameStartTime = 0
	local isIdle = true
	local updateRefreshTime = 1 --in seconds
	local initialQueueTime
	local mx,my = GetMouseState()
	local validation = SYNCED.validationIdle
	local warningGiven = false
	local myTeamID = Spring.GetMyTeamID()
	local myAllyTeamID = Spring.GetMyAllyTeamID()
	local gaiaTeamID = Spring.GetGaiaTeamID()

	local isBuilder = {}
	local unitBuildSpeedTime = {}

	for unitDefID, unitDef in pairs(UnitDefs) do
		if unitDef.isBuilder then
			isBuilder[unitDefID] = true
		end
		unitBuildSpeedTime[unitDefID] = unitDef.buildTime / unitDef.buildSpeed
	end

	local function onInitialQueueTime(_,_,words)
		initialQueueTime = tonumber(words[1])
		if initialQueueTime then
			initialQueueTime = min(initialQueueTime,maxInitialQueueSlack)
		end
		return true
	end

	local function notIdle()
		lastActionTime = max(timer,lastActionTime)
		warningGiven = false
		if isIdle then
			SendLuaRulesMsg(validation..AFKMessage.. "0")
			isIdle = false
		end
	end

	local function onGameStart()
		if initialQueueTime then
			notIdle()
			-- allow the user to slack while initial queue is unrolling
			lastActionTime = timer + initialQueueTime
		end
		gameStartTime = timer
	end

	local function wentIdle()
		if not isIdle then
			SendLuaRulesMsg(validation..AFKMessage.. "1")
			isIdle = true
		end
	end

	local function takeNotify(_, playerID, message)
		Spring.SendMessageToPlayer(playerID, message)
	end

	local function notifyError(_, playerID, errorKey)
		if Script.LuaUI('GadgetMessageProxy') then
			local translationKey = 'ui.idlePlayers.' .. errorKey
			Spring.SendMessageToPlayer(playerID, Script.LuaUI.GadgetMessageProxy(translationKey))
		end
	end

	local function playerLagging(_, playerName)
		if Script.LuaUI('GadgetMessageProxy') then
			Spring.Echo( Script.LuaUI.GadgetMessageProxy('ui.idlePlayers.lagging', { name = playerName }) )
		end
	end

	local function playerResumed(_, playerName)
		if Script.LuaUI('GadgetMessageProxy') then
			Spring.Echo( Script.LuaUI.GadgetMessageProxy('ui.idlePlayers.resumed', { name = playerName }) )
		end
	end

	local function playerAFK(_, allyTeamID, playerName)
		if Script.LuaUI('GadgetMessageProxy') then
			local message = Script.LuaUI.GadgetMessageProxy('ui.idlePlayers.afk', { name = playerName })
			Spring.SendMessageToAllyTeam(allyTeamID, message)
		end
	end

	local function playerReturned(_, allyTeamID, playerName)
		if Script.LuaUI('GadgetMessageProxy') then
			local message = Script.LuaUI.GadgetMessageProxy('ui.idlePlayers.returned', { name = playerName })
			Spring.SendMessageToAllyTeam(allyTeamID, message)
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("OnGameStart", onGameStart)
		gadgetHandler:AddSyncAction("NotifyError", notifyError)
		gadgetHandler:AddSyncAction("TakeNotify", takeNotify)
		gadgetHandler:AddSyncAction("PlayerLagging", playerLagging)
		gadgetHandler:AddSyncAction("PlayerResumed", playerResumed)
		gadgetHandler:AddSyncAction("PlayerAFK", playerAFK)
		gadgetHandler:AddSyncAction("PlayerReturned", playerReturned)
		gadgetHandler:AddChatAction("initialQueueTime",onInitialQueueTime)
		notIdle()
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveChatAction("initialQueueTime")
		gadgetHandler:RemoveSyncAction("OnGameStart")
	end

	function gadget:Update()
		local dt = GetLastUpdateSeconds()
		timer = timer+dt
		updateTimer = updateTimer + dt
		if updateTimer < updateRefreshTime then
			return
		end
		updateTimer = 0

		if checkQueueTime and GetGameSeconds() > checkQueueTime then
			local teamID = Spring.GetMyTeamID()
			local myUnits = Spring.GetTeamUnits(teamID)
			local queueTime = 0
			for i=1, #myUnits do
				local unitID = myUnits[i]
				local thisQueueTime = 0
				if isBuilder[GetUnitDefID(unitID)] then
					local buildQueue = GetRealBuildQueue(unitID)
					if buildQueue then
						for uDID,_ in pairs(buildQueue) do
							thisQueueTime = thisQueueTime + unitBuildSpeedTime[uDID]
						end
					end
				end
				if queueTime < thisQueueTime then
					queueTime = thisQueueTime
				end
			end
			lastActionTime = min(max(lastActionTime, timer+queueTime),gameStartTime+maxInitialQueueSlack) --treat this queue as though is was an initial queue
			checkQueueTime = nil
		end

		-- check if the mouse moved
		local x,y = GetMouseState()
		if mx ~= x or my ~= y then
			notIdle()
		end
		my = y
		mx = x

		if timer-lastActionTime > maxIdleTreshold-warningPeriod then
			if not warningGiven then
				warningGiven = true
				local spectator = Spring.GetSpectatingState()
				if not spectator then
					-- check first if user has team players... that could possibly take... and then give warning
					local teamList = Spring.GetTeamList(myAllyTeamID)
					for _,teamID in ipairs(teamList) do
						local luaAI = Spring.GetTeamLuaAI(teamID)
						local _, leader, isDead, isAiTeam, side, allyTeamID, incomeMultiplier, customTeamKeys = Spring.GetTeamInfo(teamID, false)
						if Script.LuaUI('GadgetMessageProxy') and teamID ~= myTeamID and teamID ~= gaiaTeamID and not isDead and not isAiTeam and (not luaAI or luaAI == "") and Spring.GetTeamRulesParam(teamID, "numActivePlayers") > 0 then
							Spring.Echo("\255\255\166\166" .. Script.LuaUI.GadgetMessageProxy('ui.idlePlayers.warning'))
							break
						end
					end
				end
			elseif timer-lastActionTime > maxIdleTreshold then
				wentIdle()
			end
		end
	end

	function gadget:MousePress()
		notIdle()
	end

	function gadget:MouseWheel()
		notIdle()
	end

	function gadget:KeyPress()
		notIdle()
	end

end
