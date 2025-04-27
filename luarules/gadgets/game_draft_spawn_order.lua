-- 2024-04-15: Draft Spawn Order mod by Tom Fyuri.
-- Since we have multiple discord suggestions asking for more spawn position options, here we go.
-- original PR: https://github.com/beyond-all-reason/Beyond-All-Reason/pull/2845

-- The reason it's not its own gadget is that its just a mod for game_initail_spawn.
-- And its only meant to work if Game.startPosType is 2.

local draftMode = Spring.GetModOptions().draft_mode

local spGetPlayerInfo = Spring.GetPlayerInfo
local spGetTeamInfo = Spring.GetTeamInfo

local allyTeamSpawnOrder = {} -- [allyTeam] = [teamID,teamID,...] - used for random/skill draft - placement order
local allyTeamSpawnOrderPlaced = {} -- [allyTeam] = 1,..,#TeamsinAllyTeam - whose order to place right now
local teamPlayerData = {} -- [teamID] = {id, name, skill} of that team's player
local allyTeamIsInGame = {} -- [allyTeam] = true/false - fully joined ally teams
local votedToForceSkipTurn = {} -- [allyTeam][teamID] - if more than 50% vote for it, the current player turn is force-skipped
local votedToForceStartDraft = {} -- [allyTeam][teamID] - if more than 50% vote for it, the draft will be initiated early, all late-joiners get last spots
local VOTE_QUORUM = 2 -- if there is less than 2 players in the game - the votes don't count -- TODO consider making it 3, can't have proper quorum with just two nodes, but it might be ok for now.
local VOTE_YES_PRCTN_REQ = 51 -- default: 51
local announceVoteResults = false -- "secret" voting
local gaiaAllyTeamID = select(6, spGetTeamInfo(Spring.GetGaiaTeamID(), false))
local waitIsMandatory = false -- if true - you will wait for late-joiners, and conneectionTimeOut timer won't be shown
local canVoteSkipTurn = false
local canVoteForceStartDraft = false

local function FindPlayerID(teamID)
	if teamPlayerData and teamPlayerData[teamID] and teamPlayerData[teamID].id then
		return teamPlayerData[teamID].id
	else
		-- Fallback: Search for player ID using Spring functions (no skill data available)
		local players = Spring.GetPlayerList()
		for _, playerID in ipairs(players) do
			local playerTeamID = select(4,spGetPlayerInfo(playerID, false))
			if playerTeamID == teamID then
				return playerID
			end
		end
		return nil
	end
end

local function FindPlayerName(teamID)
	if teamPlayerData and teamPlayerData[teamID] and teamPlayerData[teamID].name then
		return teamPlayerData[teamID].name
	else
		local players = Spring.GetPlayerList()
		for _, playerID in ipairs(players) do
			local name,_,_,playerTeamID = spGetPlayerInfo(playerID, false)
			if playerTeamID == teamID and name then
				return name
			end
		end
		return nil
	end
end

local function shuffleArray(array)
	local n = (array and #array) or 0
	if n <= 1 then return array end
	local random = math.random
	for i = 1, n do
		local j = random(i, n)
		array[i], array[j] = array[j], array[i]
	end
end

local function GetSkillByTeam(teamID)
	if teamPlayerData and teamPlayerData[teamID] and teamPlayerData[teamID].skill then
		return teamPlayerData[teamID].skill
	else
		return 0
	end
end

local function GetSkillByPlayer(playerID)
	if playerID == nil then return 0 end -- uhh
	local customtable = select(11, spGetPlayerInfo(playerID))
	if type(customtable) == 'table' then
		local tsMu = customtable.skill
		local ts = tsMu and tonumber(tsMu:match("%d+%.?%d*"))
		if (ts == nil) then return 0 else return ts end
	end
	return 0
end

local function compareSkills(teamA, teamB)
	local skillA = GetSkillByTeam(teamA)
	local skillB = GetSkillByTeam(teamB)
	return skillA > skillB  -- Sort in descending order of skill
end

local function isAllyTeamSkillZero(allyTeamID)
	local tteams = Spring.GetTeamList(allyTeamID)
	for _, teamID in ipairs(tteams) do
		local _, _, _, isAiTeam = spGetTeamInfo(teamID)
		if not isAiTeam and gaiaAllyTeamID ~= allyTeamID then
			local skill = GetSkillByTeam(teamID)
			if skill ~= 0 then
				return false
			end
		end
	end
	return true
end

local function sendTeamOrder(teamOrder, allyTeamID_ready, log)
	if (teamOrder == nil or #teamOrder <= 0) then return end -- do not send empty order ever
	-- we send to allyTeamID Turn1 Turn2 Turn3 {...}
	local orderMsg = ""
	local orderIds = ""
	local alone = true
	for i, teamID in ipairs(teamOrder) do
		local playerID = FindPlayerID(teamID)
		local tname = FindPlayerName(teamID) or "unknown" -- "unknown" should not happen if we create the order after everyone connects, so we are good in the most cases
		if (playerID) then
			if i == 1 then
				orderMsg = tname
				orderIds = playerID
			else
				if alone then alone = false end
				orderMsg = orderMsg .. ", " .. tname
				orderIds = orderIds .. " " .. playerID
			end
		end
	end
	if log and not alone then
		Spring.Log(gadget:GetInfo().name, LOG.INFO, "Order [id:"..allyTeamID_ready.."]: "..orderMsg)
	end
	Spring.SendLuaUIMsg("DraftOrderPlayersOrder " .. allyTeamID_ready .. " " .. orderIds)
end

local function calculateVotedPercentage(allyTeamID, votesArray)
	local totalPlayers = 0
	local votedPlayers = 0
	for teamID, _ in pairs(votesArray[allyTeamID]) do
		if teamPlayerData[teamID] ~= nil then -- because if not connected = can't vote
			totalPlayers = totalPlayers + 1
		end
		if votesArray[allyTeamID][teamID] then
			votedPlayers = votedPlayers + 1
		end
	end
	if totalPlayers < VOTE_QUORUM or (totalPlayers == 0) then return 0 end -- auto-fail
	return (votedPlayers / totalPlayers) * 100
end

local function SendDraftMessageToPlayer(allyTeamID, target_num)
	-- technically do not care if it overflows here, on the clientside there just won't be anyone in the queue left
	Spring.SendLuaUIMsg("DraftOrderPlayerTurn " .. allyTeamID .. " " .. target_num) -- we send allyTeamID orderIndex
end

local function checkVotesAndAdvanceTurn(allyTeamID)
	if allyTeamSpawnOrderPlaced[allyTeamID] > #allyTeamSpawnOrder[allyTeamID] then return end -- allow skip last one, but no more
	local votedPercentage = calculateVotedPercentage(allyTeamID, votedToForceSkipTurn)
	if votedPercentage >= VOTE_YES_PRCTN_REQ then
		if announceVoteResults then
			Spring.Echo(""..votedPercentage.."% (req: "..VOTE_YES_PRCTN_REQ.."%) of players on ally team " .. allyTeamID .. " have voted to skip current player turn.")
		end
		for teamID, _ in pairs(votedToForceSkipTurn[allyTeamID]) do
			votedToForceSkipTurn[allyTeamID][teamID] = false -- reset vote
		end -- and advance turn
		allyTeamSpawnOrderPlaced[allyTeamID] = allyTeamSpawnOrderPlaced[allyTeamID]+1
		SendDraftMessageToPlayer(allyTeamID, allyTeamSpawnOrderPlaced[allyTeamID])
	end
end

local function isTurnToPlace(allyTeamID, teamID)
	-- Returns:
	-- 0 - Can't place yet
	-- 1 - Your turn
	-- 2 - Your turn has passed
	local teamOrder = allyTeamSpawnOrder[allyTeamID]
	if not teamOrder then
		return 2  -- No spawn order defined for this team; you can place whenever then
	end
	local placedIndex = allyTeamSpawnOrderPlaced[allyTeamID]
	if placedIndex <= 0 then
		return 2 -- Cannot figure out whose turn; you can place then
	end
	local teamIndex = nil
	-- Find the index of the team within the spawn order
	for i, id in ipairs(teamOrder) do
		if id == teamID then
			teamIndex = i
			break
		end
	end
	if not teamIndex then return 2 end -- The team is not in the spawn order; you can place whenever then
	if teamIndex == placedIndex then -- Your turn
		return 1
	elseif teamIndex < placedIndex then -- Skipped your turn?
		return 2
	else
		return 0 -- Your turn is yet to be
	end
end

-- Tom: order is generated after the entire ally team is in game,
-- now we can force it to generate before everyone connects too! (late-joiners get last spots)
local function PreInitDraftOrderData()
	local tteams = Spring.GetTeamList()
	for _, teamID in ipairs(tteams) do
		local _, _, _, isAiTeam, _, allyTeamID = spGetTeamInfo(teamID, false)
		if not isAiTeam and gaiaAllyTeamID ~= allyTeamID then
			teamPlayerData[teamID] = nil
			if allyTeamIsInGame[allyTeamID] == nil then
				allyTeamSpawnOrder[allyTeamID] = {} -- won't be used in fair mode
				allyTeamIsInGame[allyTeamID] = false
			end
		end
		if not votedToForceStartDraft[allyTeamID] then
			votedToForceStartDraft[allyTeamID] = {}
		end
		votedToForceStartDraft[allyTeamID][teamID] = false
	end
	if draftMode == "random" or draftMode == "skill" or draftMode == "captain" then
		for _, teamID in ipairs(tteams) do
			local _, _, _, isAiTeam, _, allyTeamID = spGetTeamInfo(teamID, false)
			if not votedToForceSkipTurn[allyTeamID] then
				votedToForceSkipTurn[allyTeamID] = {}
			end
			votedToForceSkipTurn[allyTeamID][teamID] = false
		end
	end
	canVoteForceStartDraft = true
end

local function putLateJoinersLast(array)
	if not array then return end
	local lateJoiners = false
	for _, teamID in ipairs(array) do
		if not teamPlayerData[teamID] then
			lateJoiners = true
			break
		end
	end
	if not lateJoiners then return end

	local teamsWithPlayerData = {}
	local teamsWithoutPlayerData = {}
	for _, teamID in ipairs(array) do
		if teamPlayerData[teamID] then
			table.insert(teamsWithPlayerData, teamID)
		else
			table.insert(teamsWithoutPlayerData, teamID)
		end
	end
	local newOrder = {}
	for _, teamID in ipairs(teamsWithPlayerData) do
		table.insert(newOrder, teamID)
	end
	for _, teamID in ipairs(teamsWithoutPlayerData) do
		table.insert(newOrder, teamID)
	end

	for i = 1, #array do
		array[i] = newOrder[i]
	end
end

local function InitDraftOrderData(allyTeamID_ready)
	if not allyTeamID_ready or allyTeamIsInGame[allyTeamID_ready] == true then return end -- already started
	allyTeamIsInGame[allyTeamID_ready] = true
	if draftMode == "random" or draftMode == "captain" then
		local tteams = Spring.GetTeamList()
		for _, teamID in ipairs(tteams) do
			local _, _, _, isAiTeam, _, allyTeamID = spGetTeamInfo(teamID, false)
			if not isAiTeam and allyTeamID_ready == allyTeamID and gaiaAllyTeamID ~= allyTeamID then
				table.insert(allyTeamSpawnOrder[allyTeamID], teamID)
			end
		end
		shuffleArray(allyTeamSpawnOrder[allyTeamID_ready])
		-- Try to put 'captain' first
		if draftMode == "captain" and (#allyTeamSpawnOrder[allyTeamID_ready] > 1) then
			local highestSkill = 0
			local captainTeamIDindex = nil
			for index, teamID in ipairs(allyTeamSpawnOrder[allyTeamID_ready]) do
				if teamPlayerData[teamID] and teamPlayerData[teamID].skill > highestSkill then
					highestSkill = teamPlayerData[teamID].skill
					captainTeamIDindex = index
				end
			end
			if captainTeamIDindex and highestSkill > 0 and captainTeamIDindex ~= 1 then
				allyTeamSpawnOrder[allyTeamID_ready][1], allyTeamSpawnOrder[allyTeamID_ready][captainTeamIDindex] = allyTeamSpawnOrder[allyTeamID_ready][captainTeamIDindex], allyTeamSpawnOrder[allyTeamID_ready][1]
			end
		end
		putLateJoinersLast(allyTeamSpawnOrder[allyTeamID_ready])
	elseif draftMode == "skill" then
		local tteams = Spring.GetTeamList()
		table.sort(tteams, compareSkills) -- Sort teams based on skill
		-- Assign sorted teams to allyTeamSpawnOrder
		for _, teamID in ipairs(tteams) do
			local _, _, _, isAiTeam, _, allyTeamID = spGetTeamInfo(teamID, false)
			if not isAiTeam and allyTeamID_ready == allyTeamID and gaiaAllyTeamID ~= allyTeamID then
				table.insert(allyTeamSpawnOrder[allyTeamID], teamID)
			end
		end
		-- If the entire ally team has zero skill players, random shuffle then
		if isAllyTeamSkillZero(allyTeamID_ready) then
			shuffleArray(allyTeamSpawnOrder[allyTeamID_ready])
		else -- If two players have same skill, do a coin flip
			function randomlySwap(array, i, j)
				if math.random(2) == 1 then
					array[i], array[j] = array[j], array[i]
				end
			end
			for i = 1, #allyTeamSpawnOrder[allyTeamID_ready] - 1 do
				if GetSkillByTeam(allyTeamSpawnOrder[allyTeamID_ready][i]) <= 0 then break end
				if GetSkillByTeam(allyTeamSpawnOrder[allyTeamID_ready][i]) == GetSkillByTeam(allyTeamSpawnOrder[allyTeamID_ready][i+1]) then
					randomlySwap(allyTeamSpawnOrder[allyTeamID_ready], i, i+1)
				end
			end
		end
		putLateJoinersLast(allyTeamSpawnOrder[allyTeamID_ready])
	end
	Spring.SendLuaUIMsg("DraftOrderAllyTeamJoined "..allyTeamID_ready)
	if draftMode == "skill" or draftMode == "random" or draftMode == "captain" then
		canVoteSkipTurn = true
		allyTeamSpawnOrderPlaced[allyTeamID_ready] = 1 -- First team in the order queue must place now
		sendTeamOrder(allyTeamSpawnOrder[allyTeamID_ready], allyTeamID_ready, true) -- Send order FIRST
		SendDraftMessageToPlayer(allyTeamID_ready, 1) -- We send the team a message notifying them it's their turn to place
	end
end

local function checkVotesAndStartDraft(allyTeamID)
	local votedPercentage = calculateVotedPercentage(allyTeamID, votedToForceStartDraft)
	if votedPercentage >= VOTE_YES_PRCTN_REQ then
		if announceVoteResults then
			Spring.Echo(""..votedPercentage.."% (req: "..VOTE_YES_PRCTN_REQ.."%) of players on ally team " .. allyTeamID .. " have voted to skip wait for late-joiners.")
		end
		for teamID, _ in pairs(votedToForceStartDraft[allyTeamID]) do
			votedToForceStartDraft[allyTeamID][teamID] = false -- reset vote
		end -- and force start draft queue
		InitDraftOrderData(allyTeamID)
	end
end

-- globals

function draftModeInitialize()
	PreInitDraftOrderData()
	if draftMode == "random" then -- Random draft
		Spring.SendLuaUIMsg("DraftOrder_Random") -- Discord: https://discord.com/channels/549281623154229250/1163844303735500860
	elseif draftMode == "captain" then -- Fair mod
		Spring.SendLuaUIMsg("DraftOrder_Captain") -- Discord: https://discord.com/channels/549281623154229250/1163844303735500860
	elseif draftMode == "skill" then -- Skill-based placement order
		Spring.SendLuaUIMsg("DraftOrder_Skill") -- Discord: https://discord.com/channels/549281623154229250/1134886429361713252
	elseif draftMode == "fair" then -- Fair mod
		Spring.SendLuaUIMsg("DraftOrder_Fair") -- Discord: https://discord.com/channels/549281623154229250/1123310748236529715
	end
end

function Draft_PreAllowStartPosition(teamID, allyTeamID)
	local myTurn = false
	local _, _, _, isAI = spGetTeamInfo(teamID, false)
	if not isAI then
		if allyTeamIsInGame[allyTeamID] == false then
			return false, false
		end -- Wait for everyone
		if draftMode == "skill" or draftMode == "random" or draftMode == "captain" then
			local turnCheck = isTurnToPlace(allyTeamID, teamID) -- Check if it's your turn
			if turnCheck == 0 then
				return false, false
			elseif turnCheck == 1 then
				myTurn = true
			end
		end
	end
	return myTurn, true
end

function Draft_PostAllowStartPosition(myTurn, allyTeamID)
	if myTurn then
		allyTeamSpawnOrderPlaced[allyTeamID] = allyTeamSpawnOrderPlaced[allyTeamID]+1
		SendDraftMessageToPlayer(allyTeamID, allyTeamSpawnOrderPlaced[allyTeamID])
	end
end

function DraftRecvLuaMsg(msg, playerID, playerIsSpec, playerTeam, allyTeamID)
	if not waitIsMandatory and canVoteForceStartDraft and msg == "vote_wait_too_long" and votedToForceStartDraft[allyTeamID][playerTeam] ~= nil then
		votedToForceStartDraft[allyTeamID][playerTeam] = true
		checkVotesAndStartDraft(allyTeamID) -- in fair mode it simply unlocks placing after latejoin timeout
	end
	if (draftMode == "skill" or draftMode == "random" or draftMode == "captain") then
		if allyTeamSpawnOrderPlaced[allyTeamID] and allyTeamSpawnOrderPlaced[allyTeamID] > 0 then
			if msg == "skip_my_turn" then
				if allyTeamIsInGame[allyTeamID] and playerTeam and allyTeamID then
					local turnCheck = isTurnToPlace(allyTeamID, playerTeam)
					if turnCheck == 1 then -- your turn and you skip? sure thing then!
						allyTeamSpawnOrderPlaced[allyTeamID] = allyTeamSpawnOrderPlaced[allyTeamID]+1 -- if it "overflows", that means all teams inside the allyteam can place, which is OK
						SendDraftMessageToPlayer(allyTeamID, allyTeamSpawnOrderPlaced[allyTeamID])
					end
				end
			elseif canVoteSkipTurn and msg == "vote_skip_turn" and votedToForceSkipTurn[allyTeamID][playerTeam] ~= nil then
				votedToForceSkipTurn[allyTeamID][playerTeam] = true
				checkVotesAndAdvanceTurn(allyTeamID)
			end
		end
	end
	if msg == "i_have_joined_fair" then
		local playerName = select(1,spGetPlayerInfo(playerID, false))
		if playerID > -1 and playerName ~= nil then
			teamPlayerData[playerTeam] = {id = playerID, name = playerName, skill = GetSkillByPlayer(playerID)} -- Save data
		end
		-- Check if all allies have joined and start the draft automatically
		if allyTeamIsInGame[allyTeamID] ~= true then
			local allAlliesJoined = true
			local teamList = Spring.GetTeamList(allyTeamID)
			local count = 0
			local tcount = 0
			for _, team in ipairs(teamList) do
				local _, _, _, isAI = spGetTeamInfo(team, false)
				if not isAI and gaiaAllyTeamID ~= allyTeamID then
					tcount = tcount + 1
					if teamPlayerData[team] == nil then
						allAlliesJoined = false
					else
						count = count + 1
					end
				end
			end
			if allAlliesJoined then
				InitDraftOrderData(allyTeamID)
			end
			if not waitIsMandatory and tcount >= VOTE_QUORUM and count > 0 and tcount > 0 and (((count / tcount) * 100) >= VOTE_YES_PRCTN_REQ) then
				Spring.SendLuaUIMsg("DraftOrderShowCountdown "..allyTeamID)
			end
		end
	elseif msg == "send_me_the_info_again" then -- someone luaui /reload'ed, send them the queue and index again
		if allyTeamIsInGame[allyTeamID] then
			Spring.SendLuaUIMsg("DraftOrderAllyTeamJoined "..allyTeamID)
			if draftMode ~= "fair" and allyTeamSpawnOrderPlaced[allyTeamID] then
				sendTeamOrder(allyTeamSpawnOrder[allyTeamID], allyTeamID, false) -- Send order FIRST
				SendDraftMessageToPlayer(allyTeamID, allyTeamSpawnOrderPlaced[allyTeamID])
			end
		end
	end
end
