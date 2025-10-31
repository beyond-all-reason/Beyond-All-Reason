local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Unit Position Logger",
		desc = "logs all unit positions in intervals",
		author = "Floris",
		date = "February 2021",
		license = "GNU GPL, v2 or later",
		layer = -999999,
		enabled = false,
	}
end

--[[
	this gadget includes unit positions at intervals within the replay using SendLuaRulesMsg
	the purpose of this is so a replay website or a game-lobby could display an overview timeline-video of the match

	every catched-up player+spectator will participate in sending a part of all units
	(parts that fail to be received are passed on to the next player/spec to re-send until everyone tried once)

	SendLuaRulesMsg format: logXX framenum ; part ; numparts ; attempts ; gzipped-json
]]

if not gadgetHandler:IsSyncedCode() then

	if Spring.IsReplay() then return end

	local DEBUG = select(1, Spring.GetPlayerInfo(Spring.GetMyPlayerID())) == '[teh]Flow'

	local gameFramesPerSecond = 30	-- engine constant
	local pingCutoff = 1500	-- players with higher ping wont participate in sending unit positions log
	local pingCutoffFrames = math.ceil((pingCutoff / 1000) * gameFramesPerSecond )

	-- based on the current number of units it will adjust the amount of gameframes between each log
	local minLogRate = math.floor(gameFramesPerSecond * 6)
	local maxLogRate = math.floor(gameFramesPerSecond * 30)
	local maxLogRateUnits = 3000	-- # of units where maxLogRate gets reached

	local maxLogMemoryDuration = gameFramesPerSecond * 60

	-- verify if every part of a log has been received every X amount of gameframes, and resend parts if not
	local verifyRate = math.floor(gameFramesPerSecond * 1) + pingCutoffFrames

	---------------------------------------------------------------------------------------

	local validation = SYNCED.validationLogger

	local spGetUnitPosition = Spring.GetUnitPosition
	local math_floor = math.floor
	local math_ceil = math.ceil

	local myPlayerID = Spring.GetMyPlayerID()
	local isSinglePlayer = Spring.Utilities.Gametype.IsSinglePlayer()

	local logRate = minLogRate
	local lastLogFrame = 30-minLogRate
	local log = {}
	local verifyQueue = {}

	local allUnits = {}
	local allUnitsTotal = 0

	function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
		allUnits[unitID] = {unitDefID, unitTeam}
		allUnitsTotal = allUnitsTotal + 1
	end

	function gadget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
		allUnits[unitID] = {unitDefID, unitTeam}
	end

	function gadget:UnitTaken(unitID, unitDefID, oldTeam, newTeam)
		allUnits[unitID] = {unitDefID, newTeam}
	end

	function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
		allUnits[unitID] = nil
		allUnitsTotal = allUnitsTotal - 1
	end

	-- remember all unit positions (in case you're designated to send a missing part later)
	local function updateLog(frame, participants)	-- participants = playerID table
		local numParticipants = #participants
		log[frame] = {
			attempts = 1,
			participants = participants,
			parts = {},
		}
		for part=1, numParticipants do
			log[frame].parts[part] = {}
		end
		local part, teamID
		local i = 0
		for unitID, params in pairs(allUnits) do
			local px, _, pz = spGetUnitPosition(unitID)
			if px then
				i = i + 1
				-- divide all units among participants/parts
				part = math.min(numParticipants, math_ceil(i / (allUnitsTotal/numParticipants)))	-- (used math.min cause sometimes the part is numParticipants+1 which will result in error)
				teamID = params[2]
				if not log[frame].parts[part][teamID] then	-- params[2] = teamID
					log[frame].parts[part][teamID] = {}
				end
				local count = #log[frame].parts[part][teamID] + 1
				log[frame].parts[part][teamID][count] = {unitID, params[1], math_floor(px), math_floor(pz)}
			end
		end
	end

	-- receiving from SYNCED
	local function receivedPart(_, frame, part, numParts, attempts)
		frame, part = tonumber(frame), tonumber(part)

		if log[frame] then
			log[frame].parts[part] = nil	-- clear received part

			-- clear frame when all parts have been received
			local noParts = true
			for k, v in pairs(log[frame].parts) do
				noParts = false
				break
			end
			if noParts then
				log[frame] = nil
				if DEBUG and (attempts ~= '1' or part > tonumber(numParts)) then
					Spring.Echo('UNITLOG: "all received": frame:'..frame..' part:'..part..' parts:'..numParts..' attempts:'..attempts)
				end
			end
		end
	end

	local function getFreeVerifyQueueKey(frame, depth)
		if verifyQueue[frame] and (not depth or depth < 10) then	-- limit recursion depth
			if not depth then depth = 1 end
			frame = getFreeVerifyQueueKey(frame + 1, depth + 1)
		end
		return frame
	end

	local function sendLog(frame, part, attempts)
		Spring.SendLuaRulesMsg('log' .. validation .. frame ..';'.. part ..';'.. (#log[frame].participants) ..';'..attempts ..';'.. VFS.ZlibCompress(Json.encode(log[frame].parts[part])))
	end

	function gadget:Initialize()
		for ct, unitID in pairs(Spring.GetAllUnits()) do
			gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID), Spring.GetUnitTeam(unitID))
		end
		gadgetHandler:AddSyncAction("receivedPart", receivedPart)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction("receivedPart")
	end

	function gadget:GameFrame(gf)
		if gf < 30 then return end

		-- check if all parts have been received, clear the logged frame if this is the case
		if verifyQueue[gf] then
			local frame = verifyQueue[gf]
			verifyQueue[gf] = nil

			if log[frame] then
				log[frame].attempts = log[frame].attempts + 1
				if log[frame].attempts > #log[frame].participants then	-- this should not happen... if so, something went wrong because we tried resending by all other participants already
					if DEBUG then
						local missingParts, missingUnits = 0, 0
						for p, part in pairs(log[frame].parts) do
							missingParts = missingParts + 1
							for teamID, units in pairs(part) do
								missingUnits = missingUnits + #units
							end
						end
						Spring.Echo('UNITLOG: "max attempts reached": frame:'..frame..' attempts:'..log[frame].attempts..'of '..(#log[frame].participants)..' missing parts:'..missingParts..' missing units:'..missingUnits)
					end
					log[frame] = nil
				else
					-- loop leftover parts
					for part, _ in pairs(log[frame].parts) do
						-- resend part if you're the designated backup sender
						local designatedBackupParticipant = myPlayerID
						if log[frame].participants[part + log[frame].attempts] then
							-- goto next participant
							designatedBackupParticipant = log[frame].participants[part + log[frame].attempts]
						else
							-- start from first participant onwards
							local numParticipants = #log[frame].participants
							designatedBackupParticipant = log[frame].participants[ log[frame].attempts - (numParticipants-part) ]
						end
						if designatedBackupParticipant == myPlayerID then
							sendLog(frame, part, log[frame].attempts)
						end
					end

					verifyQueue[ getFreeVerifyQueueKey(gf+verifyRate) ] = frame
				end
			end
		end

		-- save and send you part of all unit positions
		if gf >= lastLogFrame+logRate then
			lastLogFrame = gf

			-- cleanup incomplete old frames in case this has happened for some reason
			for frame, params in pairs(log) do
				if frame < gf-maxLogMemoryDuration then
					if DEBUG then
						local missingParts, missingUnits = 0, 0
						for p, part in pairs(log[frame].parts) do
							missingParts = missingParts + 1
							for teamID, units in pairs(part) do
								missingUnits = missingUnits + #units
							end
						end
						Spring.Echo('UNITLOG: "timeout": frame:'..frame..' attempts:'..log[frame].attempts..'of '..(#log[frame].participants)..' missing parts:'..missingParts..' missing units:'..missingUnits)
					end
					log[frame] = nil
				end
			end

			-- adjust logRate based on number of units on the map (so earlygame log can stay frequent)
			logRate = math.clamp(maxLogRate * (allUnitsTotal / maxLogRateUnits), minLogRate, maxLogRate)

			-- find out which players/specs aren't lagged behind and available to send a part of all unit position data
			local participants = {}
			local myPart
		for _,playerID in ipairs(Spring.GetPlayerList()) do
			local name,_,_,teamID,_,ping = Spring.GetPlayerInfo(playerID,false)
			-- exclude lagged out players and AI
			-- NOTE: ping is 0 when player is catching up or playing local (local can be slightly above 0 when low fps 0.033)
			local isDead = select(4, Spring.GetTeamInfo(teamID))
			if (ping > 0.01 or isSinglePlayer) and ping < pingCutoff/1000 and not Spring.GetTeamLuaAI(teamID) and not isDead then
				participants[#participants+1] = playerID
				if playerID == myPlayerID then
					myPart = #participants
				end
			end
		end			-- send log when you're included as participant
			if myPart then
				updateLog(gf, participants)
				sendLog(gf, myPart, 1)
				verifyQueue[ getFreeVerifyQueueKey(gf+verifyRate) ] = gf
			end
		end
	end


else	-- SYNCED


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
	_G.validationLogger = validation

	-- Synced code here only listens to what has been received and thus logged in the demo, notifies unsynced so that can handle re-sending if necessary
	function gadget:RecvLuaMsg(msg, playerID)
		if msg:sub(1,3)=="log" and msg:sub(4,5)==validation then
			local params = string.split(msg:sub(6, 40), ';')	-- 1=frame, 2=part, 3=numParts, 4=attempts, 5=gzipped-json
			SendToUnsynced("receivedPart", params[1], params[2], params[3], params[4])
			return true
		end
	end

end
