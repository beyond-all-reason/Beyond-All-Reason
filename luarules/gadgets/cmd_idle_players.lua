if BAR.Utilities.Gametype.IsSinglePlayer() then
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
		enabled = true,
	}
end

local maxIdleTreshold = 80 --in seconds
local warningPeriod = 15
local maxPing = 33 -- in seconds
local finishedResumingPing = 2 --in seconds
local maxInitialQueueSlack = 150 -- in seconds
local takeCommand = "take2"
local giveBackCommand = "giveback"
local originRule = "takenFromTeam"
local availableRule = "givebackUnits"
local minTimeToTake = 12 -- in seconds
local checkQueueTime = 25 -- in seconds
-- in chose ingame startpostype, players must place beforehand, so take an action, grace period can be shorter
minTimeToTake = Spring.GetModOptions().startpostype == 2 and 1 or minTimeToTake

local AFKMessage = "idleplayers "
local AFKMessageSize = #AFKMessage

local errorKeys = {
	shareAFK = "shareAFK",
	takeEnemies = "takeEnemies",
	nothingToTake = "nothingToTake",
}

if gadgetHandler:IsSyncedCode() then
	local playerInfoTable = {}
	local currentGameFrame = 0
	local givingBackFrom, givingBackTo
	local pendingCaptures = {}
	local trackedUnits, availableUnits = {}, {}

	local GetUnitTeam = Spring.GetUnitTeam
	local GetPlayerList = Spring.GetPlayerList
	local ShareTeamResource = Spring.ShareTeamResource
	local GetTeamResources = Spring.GetTeamResources
	local GetPlayerInfo = Spring.GetPlayerInfo
	local GetTeamLuaAI = Spring.GetTeamLuaAI
	local GetAIInfo = Spring.GetAIInfo
	local SetTeamRulesParam = Spring.SetTeamRulesParam
	local GetTeamRulesParam = Spring.GetTeamRulesParam
	local GetTeamUnits = Spring.GetTeamUnits
	local GetTeamInfo = Spring.GetTeamInfo
	local GetTeamList = Spring.GetTeamList
	local IsCheatingEnabled = Spring.IsCheatingEnabled

	local resourceList = { "metal", "energy" }
	local gaiaTeamID = Spring.GetGaiaTeamID()
	local gameSpeed = Game.gameSpeed

	local validation = string.randomString(2)
	_G.validationIdle = validation

	-- Cache prefix bytes for allocation-free hot-path check
	local vb1, vb2 = string.byte(validation, 1, 2)
	local afk_b1 = string.byte(AFKMessage, 1) -- first byte of "idleplayers "

	local function changeAvailable(teamID, origin, delta)
		local counts = availableUnits[teamID] or {}
		availableUnits[teamID] = counts
		counts[origin] = (counts[origin] or 0) + delta
		SetTeamRulesParam(teamID, availableRule .. origin, counts[origin], { allied = true })
	end

	local function trackUnit(unitID, owner, origin)
		if not origin or origin < 0 or owner == origin then
			origin = nil
		end
		local previous = trackedUnits[unitID]
		if previous and previous.owner == owner and previous.origin == origin then
			return
		end
		if previous then
			changeAvailable(previous.owner, previous.origin, -1)
			trackedUnits[unitID] = nil
		end
		if owner and origin then
			trackedUnits[unitID] = { owner = owner, origin = origin }
			changeAvailable(owner, origin, 1)
		end
	end

	-- Inseparable helpers and replacement parts retain their taken chassis's origin.
	local function setTakenUnitOrigin(unitID, origin)
		if origin and origin >= 0 then
			Spring.SetUnitRulesParam(unitID, originRule, origin, { private = true })
			trackUnit(unitID, GetUnitTeam(unitID), origin)
		end
	end

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
		for _, teamID in ipairs(GetTeamList()) do --initialize team count
			if select(4, GetTeamInfo(teamID, false)) then
				-- store who hosts that engine ai, team will be controlled if player is present
				local aiHost = select(3, GetAIInfo(teamID))
				local hostedAis = aiOwners[aiHost] or {}
				hostedAis[#hostedAis + 1] = teamID
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
		for _, playerID in ipairs(GetPlayerList()) do -- update player infos
			local name, active, spectator, teamID, allyTeamID, ping = GetPlayerInfo(playerID, false)
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
				if playerInfoTableEntry.connected and playerInfoTableEntry.pingOK then
					for _, aiTeamID in ipairs(hostedAis) do
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
			SetTeamRulesParam(teamID, "numActivePlayers", teamCount)
		end
	end

	local function takeTeam(cmd, line, words, playerID)
		if not CheckPlayerState(playerID) then
			SendToUnsynced("NotifyError", playerID, errorKeys.shareAFK)
			return -- exclude taking rights from lagged players, etc
		end
		local targetTeam = tonumber(words[1])
		local _, _, _, takerID, allyTeamID = GetPlayerInfo(playerID, false)
		local teamList = GetTeamList(allyTeamID)
		if targetTeam then
			if select(6, GetTeamInfo(targetTeam, false)) ~= allyTeamID then
				-- don't let enemies take
				SendToUnsynced("NotifyError", playerID, errorKeys.takeEnemies)
				return
			end
			teamList = { targetTeam }
		end
		local numTaken = 0
		for _, teamID in ipairs(teamList) do
			local luaAI = GetTeamLuaAI(teamID)
			local isAiTeam = select(4, GetTeamInfo(teamID, false))
			if
				teamID ~= takerID
				and not isAiTeam
				and (not luaAI or luaAI == "")
				and GetTeamRulesParam(teamID, "numActivePlayers") == 0
			then
				-- transfer all units
				local teamUnits = GetTeamUnits(teamID)
				local origins = {}
				for i = 1, #teamUnits do
					local previous = Spring.GetUnitRulesParam(teamUnits[i], originRule)
					origins[teamUnits[i]] = previous and previous >= 0 and previous or teamID
				end
				local unitsTaken = 0
				for i = 1, #teamUnits do
					if GetUnitTeam(teamUnits[i]) == teamID then
						if GG.ForceUnitTransfer(teamUnits[i], takerID) then
							SetTeamRulesParam(teamID, "unitCapRestorePending", 1)
						end
					end
				end
				for i = 1, #teamUnits do
					if GetUnitTeam(teamUnits[i]) == takerID then
						unitsTaken = unitsTaken + 1
						Spring.SetUnitRulesParam(teamUnits[i], originRule, origins[teamUnits[i]], { private = true })
						trackUnit(teamUnits[i], takerID, origins[teamUnits[i]])
					end
				end
				-- Keep slots for units whose transfer was rejected by another gadget.
				local remainingCap = Spring.GetTeamMaxUnits(teamID) - assert(Spring.GetTeamUnitCount(teamID)) ---@as integer
				local capTaken = remainingCap > 0 and Spring.TransferTeamMaxUnits(teamID, takerID, remainingCap)
				if capTaken then
					SetTeamRulesParam(teamID, "unitCapRestorePending", 1)
				end
				-- send all resources en-block to the taker
				local taken = {}
				for _, resourceName in ipairs(resourceList) do
					local shareAmount = GetTeamResources(teamID, resourceName)
					local current, storage, _, _, _, shareSlider = GetTeamResources(takerID, resourceName)
					-- a taker above their share slider has no room: a negative amount would send resources back
					shareAmount = math.max(0, math.min(shareAmount, shareSlider * storage - current))
					ShareTeamResource(teamID, takerID, resourceName, shareAmount)
					taken[resourceName] = math.floor(shareAmount)
				end
				if unitsTaken > 0 or capTaken or taken.metal > 0 or taken.energy > 0 then
					numTaken = numTaken + 1
					SendToUnsynced("TeamTaken", playerID, teamID, unitsTaken, taken.energy, taken.metal)
				end
			end
		end
		if numTaken == 0 then
			SendToUnsynced("NotifyError", playerID, errorKeys.nothingToTake)
		end
	end

	local function giveBackTeam(cmd, line, words, playerID)
		local targetTeam = tonumber(words[1])
		local _, active, spectator, fromTeam, allyTeam = GetPlayerInfo(playerID, false)
		if not active or spectator or not CheckPlayerState(playerID) then
			SendToUnsynced("NotifyError", playerID, "giveBackUnavailable")
			return
		end
		local validTarget = false
		for _, teamID in ipairs(GetTeamList(allyTeam)) do
			if teamID == targetTeam and teamID ~= fromTeam and teamID ~= gaiaTeamID then
				local _, _, dead, isAI = GetTeamInfo(teamID, false)
				local luaAI = GetTeamLuaAI(teamID)
				validTarget = not dead
					and not isAI
					and (not luaAI or luaAI == "")
					and (GetTeamRulesParam(teamID, "numActivePlayers") or 0) > 0
			end
		end
		if not validTarget or words[2] then
			SendToUnsynced("NotifyError", playerID, "giveBackUsage")
			return
		end
		local units = {}
		for _, unitID in ipairs(GetTeamUnits(fromTeam)) do
			if Spring.GetUnitRulesParam(unitID, originRule) == targetTeam then
				units[#units + 1] = unitID
			end
		end
		if #units == 0 then
			SendToUnsynced("NotifyError", playerID, "nothingToGiveBack")
			return
		end
		table.sort(units)
		givingBackFrom, givingBackTo = fromTeam, targetTeam
		local ok, err = pcall(function()
			for _, unitID in ipairs(units) do
				if GetUnitTeam(unitID) == fromTeam then
					GG.ForceUnitTransfer(unitID, targetTeam)
				end
			end
		end)
		givingBackFrom, givingBackTo = nil, nil
		if not ok then
			error(err)
		end
		local returned = 0
		for _, unitID in ipairs(units) do
			if GetUnitTeam(unitID) == targetTeam then
				returned = returned + 1
			end
		end
		if returned > 0 then
			SendToUnsynced("TeamGivenBack", playerID, returned)
		else
			SendToUnsynced("NotifyError", playerID, "giveBackBlocked")
		end
	end

	function gadget:Initialize()
		GG.SetTakenUnitOrigin = setTakenUnitOrigin
		-- Rebuild live availability after a reload; historical takes alone do not offer giveback.
		trackedUnits, availableUnits = {}, {}
		local teams = GetTeamList()
		for _, owner in ipairs(teams) do
			for _, origin in ipairs(teams) do
				SetTeamRulesParam(owner, availableRule .. origin, 0, { allied = true })
			end
			for _, unitID in ipairs(GetTeamUnits(owner)) do
				trackUnit(unitID, owner, Spring.GetUnitRulesParam(unitID, originRule))
			end
		end
		gadgetHandler:AddChatAction(takeCommand, takeTeam, "Take control of units and resources from inactive players")
		gadgetHandler:AddChatAction(
			giveBackCommand,
			giveBackTeam,
			"giveback <teamID>: return previously taken units to an active ally"
		)
		updatePlayersInfo()
	end

	function gadget:Shutdown()
		GG.SetTakenUnitOrigin = nil
		gadgetHandler:RemoveChatAction(takeCommand)
		gadgetHandler:RemoveChatAction(giveBackCommand)
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
		if #msg < 2 + AFKMessageSize then
			return
		end
		local b1, b2, b3 = string.byte(msg, 1, 3)
		if b1 ~= vb1 or b2 ~= vb2 or b3 ~= afk_b1 then
			return
		end -- invalid message
		if msg:sub(3, 2 + AFKMessageSize) ~= AFKMessage then
			return
		end
		local afk = tonumber(msg:sub(2 + AFKMessageSize + 1))
		local playerInfoTableEntry = playerInfoTable[playerID] or {}
		local previousPresent = playerInfoTableEntry.present
		playerInfoTableEntry.present = afk == 0
		playerInfoTable[playerID] = playerInfoTableEntry
		local name, _, spectator, _, allyTeamID, _ = GetPlayerInfo(playerID, false)
		if not spectator and name ~= nil then
			if currentGameFrame > minTimeToTake * gameSpeed then
				if previousPresent and not playerInfoTableEntry.present then
					SendToUnsynced("PlayerAFK", allyTeamID, name)
				elseif not previousPresent and playerInfoTableEntry.present then
					SendToUnsynced("PlayerReturned", allyTeamID, name)
				end
			end
		end
	end

	function gadget:AllowResourceTransfer(fromTeamID, toTeamID, restype, level)
		-- prevent resources to leak to uncontrolled teams
		return GetTeamRulesParam(toTeamID, "numActivePlayers") ~= 0 or IsCheatingEnabled()
	end

	function gadget:AllowUnitTransfer(unitID, unitDefID, fromTeamID, toTeamID, capture)
		pendingCaptures[unitID] = capture and { fromTeamID, toTeamID } or nil
		-- A carrier/factory callback must not give away units produced after the take.
		if
			givingBackTo
			and (
				fromTeamID ~= givingBackFrom
				or toTeamID ~= givingBackTo
				or Spring.GetUnitRulesParam(unitID, originRule) ~= givingBackTo
			)
		then
			return false
		end
		-- prevent units to be shared to uncontrolled teams
		return capture or GetTeamRulesParam(toTeamID, "numActivePlayers") ~= 0 or IsCheatingEnabled()
	end

	function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
		local capture = pendingCaptures[unitID]
		pendingCaptures[unitID] = nil
		local origin = Spring.GetUnitRulesParam(unitID, originRule)
		if givingBackFrom == oldTeam and givingBackTo == newTeam and origin == newTeam then
			-- Only an actual return unlocks restoration, even if a later transfer fails.
			SetTeamRulesParam(newTeam, "unitCapRestorePending", 0)
		end
		if (capture and capture[1] == oldTeam and capture[2] == newTeam) or origin == newTeam then
			origin = -1
			Spring.SetUnitRulesParam(unitID, originRule, origin, { private = true })
		end
		trackUnit(unitID, newTeam, origin)
	end

	function gadget:UnitDestroyed(unitID)
		pendingCaptures[unitID] = nil
		trackUnit(unitID, nil, nil)
	end
else -- UNSYNCED
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
	local mx, my = GetMouseState()
	local validation = SYNCED.validationIdle
	local warningGiven = false
	local myTeamID = Spring.GetLocalTeamID()
	local myAllyTeamID = Spring.GetLocalAllyTeamID()
	local gaiaTeamID = Spring.GetGaiaTeamID()

	local isBuilder = {}
	local unitBuildSpeedTime = {}

	for unitDefID, unitDef in pairs(UnitDefs) do
		if unitDef.isBuilder then
			isBuilder[unitDefID] = true
		end
		unitBuildSpeedTime[unitDefID] = unitDef.buildTime / unitDef.buildSpeed
	end

	local function onInitialQueueTime(_, _, words)
		initialQueueTime = tonumber(words[1])
		if initialQueueTime then
			initialQueueTime = min(initialQueueTime, maxInitialQueueSlack)
		end
		return true
	end

	local function notIdle()
		lastActionTime = max(timer, lastActionTime)
		warningGiven = false
		if isIdle then
			SendLuaRulesMsg(validation .. AFKMessage .. "0")
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
			SendLuaRulesMsg(validation .. AFKMessage .. "1")
			isIdle = true
		end
	end

	local function notifyError(_, playerID, errorKey)
		if Script.LuaUI("GadgetMessageProxy") then
			local translationKey = "ui.idlePlayers." .. errorKey
			Spring.SendMessageToPlayer(playerID, Script.LuaUI.GadgetMessageProxy(translationKey))
		end
	end

	local function teamGivenBack(_, playerID, units)
		if Script.LuaUI("GadgetMessageProxy") then
			Spring.SendMessageToPlayer(
				playerID,
				Script.LuaUI.GadgetMessageProxy("ui.idlePlayers.givenBack", { units = units })
			)
		end
	end

	local function playerLagging(_, playerName)
		if Script.LuaUI("GadgetMessageProxy") then
			Spring.Echo(Script.LuaUI.GadgetMessageProxy("ui.idlePlayers.lagging", { name = playerName }))
		end
	end

	local function playerResumed(_, playerName)
		if Script.LuaUI("GadgetMessageProxy") then
			Spring.Echo(Script.LuaUI.GadgetMessageProxy("ui.idlePlayers.resumed", { name = playerName }))
		end
	end

	-- same "<name> Allies: > key:params" line as game_message, so gui_chat translates it for each reader
	local function teamTaken(_, playerID, teamID, units, energy, metal)
		local takerName, _, _, _, takerAllyTeamID = Spring.GetPlayerInfo(playerID, false)
		local leaderID = select(2, Spring.GetTeamInfo(teamID, false))
		local takenName = leaderID and leaderID >= 0 and Spring.GetPlayerInfo(leaderID, false)
		if not takerName or not takenName then
			return
		end
		if takerAllyTeamID == Spring.GetLocalAllyTeamID() or Spring.GetSpectatingState() then
			Spring.SendMessageToPlayer(
				Spring.GetLocalPlayerID(),
				"<"
					.. takerName
					.. "> Allies: > ui.playersList.chat.takeTeamAmount:name="
					.. takenName
					.. ":units="
					.. units
					.. ":energy="
					.. energy
					.. ":metal="
					.. metal
			)
		end
	end

	local function playerAFK(_, allyTeamID, playerName)
		if Script.LuaUI("GadgetMessageProxy") then
			local message = Script.LuaUI.GadgetMessageProxy("ui.idlePlayers.afk", { name = playerName })
			Spring.SendMessageToAllyTeam(allyTeamID, message)
		end
	end

	local function playerReturned(_, allyTeamID, playerName)
		if Script.LuaUI("GadgetMessageProxy") then
			local message = Script.LuaUI.GadgetMessageProxy("ui.idlePlayers.returned", { name = playerName })
			Spring.SendMessageToAllyTeam(allyTeamID, message)
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("OnGameStart", onGameStart)
		gadgetHandler:AddSyncAction("NotifyError", notifyError)
		gadgetHandler:AddSyncAction("TeamGivenBack", teamGivenBack)
		gadgetHandler:AddSyncAction("PlayerLagging", playerLagging)
		gadgetHandler:AddSyncAction("PlayerResumed", playerResumed)
		gadgetHandler:AddSyncAction("PlayerAFK", playerAFK)
		gadgetHandler:AddSyncAction("PlayerReturned", playerReturned)
		gadgetHandler:AddSyncAction("TeamTaken", teamTaken)
		gadgetHandler:AddChatAction("initialQueueTime", onInitialQueueTime)
		notIdle()
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveChatAction("initialQueueTime")
		gadgetHandler:RemoveSyncAction("OnGameStart")
		gadgetHandler:RemoveSyncAction("TeamTaken")
		gadgetHandler:RemoveSyncAction("TeamGivenBack")
	end

	function gadget:Update()
		local dt = GetLastUpdateSeconds()
		timer = timer + dt
		updateTimer = updateTimer + dt
		if updateTimer < updateRefreshTime then
			return
		end
		updateTimer = 0

		if checkQueueTime and GetGameSeconds() > checkQueueTime then
			local teamID = Spring.GetLocalTeamID()
			local myUnits = Spring.GetTeamUnits(teamID)
			local queueTime = 0
			for i = 1, #myUnits do
				local unitID = myUnits[i]
				local thisQueueTime = 0
				if isBuilder[GetUnitDefID(unitID)] then
					local buildQueue = GetRealBuildQueue(unitID)
					if buildQueue then
						for uDID, _ in pairs(buildQueue) do
							thisQueueTime = thisQueueTime + unitBuildSpeedTime[uDID]
						end
					end
				end
				if queueTime < thisQueueTime then
					queueTime = thisQueueTime
				end
			end
			lastActionTime = min(max(lastActionTime, timer + queueTime), gameStartTime + maxInitialQueueSlack) --treat this queue as though is was an initial queue
			checkQueueTime = nil
		end

		-- check if the mouse moved
		local x, y = GetMouseState()
		if mx ~= x or my ~= y then
			notIdle()
		end
		my = y
		mx = x

		if timer - lastActionTime > maxIdleTreshold - warningPeriod then
			if not warningGiven then
				warningGiven = true
				local spectator = Spring.GetSpectatingState()
				if not spectator then
					-- check first if user has team players... that could possibly take... and then give warning
					local teamList = Spring.GetTeamList(myAllyTeamID)
					for _, teamID in ipairs(teamList) do
						local luaAI = Spring.GetTeamLuaAI(teamID)
						local _, leader, isDead, isAiTeam, side, allyTeamID, incomeMultiplier, customTeamKeys =
							Spring.GetTeamInfo(teamID, false)
						if
							Script.LuaUI("GadgetMessageProxy")
							and teamID ~= myTeamID
							and teamID ~= gaiaTeamID
							and not isDead
							and not isAiTeam
							and (not luaAI or luaAI == "")
							and Spring.GetTeamRulesParam(teamID, "numActivePlayers") > 0
						then
							Spring.Echo("\255\255\166\166" .. Script.LuaUI.GadgetMessageProxy("ui.idlePlayers.warning"))
							break
						end
					end
				end
			elseif timer - lastActionTime > maxIdleTreshold then
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
