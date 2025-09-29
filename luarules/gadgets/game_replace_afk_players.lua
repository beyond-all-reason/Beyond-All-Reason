--[[
disabled because of these problems:
 * the original afk player can still return
 * openskill value will still change for the afk player and not for the replacement player
 * replacement player cant resign
 * replacement player cant give units/resources
]]

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Substitution",
		desc = "Allows players absent at gamestart to be replaced by specs\nPrevents joinas to non-empty teams",
		author = "Bluestone",
		date = "June 2014",
		license = "GNU GPL, v2 or later",
		layer = 2, --run after game initial spawn and coop (because we use readyStates)
		enabled = false
	}
end

local numPlayers = Spring.Utilities.GetPlayerCount()

if numPlayers <= 4 then
	-- not needed to show sub button for small games where restarting one the better option
	return
end

if gadgetHandler:IsSyncedCode() then

	-- TS difference required for substitutions
	-- idealDiff is used if possible, validDiff as fall-back, otherwise no
	local validDiff = 6
	local idealDiff = 3

	local substitutes = {}
	local players = {}
	local absent = {}
	local replaced = false
	local gameStarted = false

	local gaiaTeamID = Spring.GetGaiaTeamID()
	local SpGetPlayerList = Spring.GetPlayerList
	local SpIsCheatingEnabled = Spring.IsCheatingEnabled

	function gadget:RecvLuaMsg(msg, playerID)
		local checkChange = (msg == '\144' or msg == '\145')

		if msg == '\145' then
			substitutes[playerID] = nil
		end
		if msg == '\144' then
			-- do the same eligibility check as in unsynced
			local customtable = select(11, Spring.GetPlayerInfo(playerID))
			if type(customtable) == 'table' then
				local tsMu = customtable.skill
				local tsSigma = customtable.skilluncertainty
				local ts = tsMu and tonumber(tsMu:match("%d+%.?%d*"))
				tsSigma = tonumber(tsSigma)
				local eligible = tsMu and tsSigma and (tsSigma <= 2) and (not string.find(tsMu, ")", nil, true)) and (not players[playerID])
				if eligible then
					substitutes[playerID] = ts
				end
			end
		end

		if checkChange then
			FindSubs(false)
		end
	end

	function gadget:AllowStartPosition(playerID, teamID, readyState, x, y, z)
		FindSubs(false)
		return true
	end

	function gadget:Initialize()
		-- record a list of which playersIDs are players on which teamID
		local teamList = Spring.GetTeamList()
		for _, teamID in pairs(teamList) do
			if teamID ~= gaiaTeamID then
				local playerList = Spring.GetPlayerList(teamID)
				for _, playerID in pairs(playerList) do
					if not select(3, Spring.GetPlayerInfo(playerID, false)) then
						players[playerID] = teamID
					end
				end
			end
		end
	end

	function FindSubs(real)
		-- make a copy of the substitutes table
		local substitutesLocal = {}
		local i = 0
		for pID, ts in pairs(substitutes) do
			substitutesLocal[pID] = ts
			i = i + 1
		end
		absent = {}

		-- make a list of absent players (only ones with valid ts)
		for playerID, _ in pairs(players) do
			local _, active, spec = Spring.GetPlayerInfo(playerID, false)
			local readyState = Spring.GetGameRulesParam("player_" .. playerID .. "_readyState")
			local noStartPoint = (readyState == 3) or (readyState == 0)
			local present = active and (not spec) and (not noStartPoint)
			if not present then
				local customtable = select(11, Spring.GetPlayerInfo(playerID)) or {}
				local tsMu = customtable.skill
				local ts = tsMu and tonumber(tsMu:match("%d+%.?%d*"))
				if ts then
					absent[playerID] = ts
				end
			end
			-- if present, tell LuaUI that won't be substituted
			if not absent[playerID] then
				Spring.SetGameRulesParam("Player" .. playerID .. "willSub", 0)
			end
		end

		-- for each one, try and find a suitable replacement & substitute if so
		for playerID, ts in pairs(absent) do
			-- construct a table of who is ideal/valid
			local idealSubs = {}
			local validSubs = {}
			for subID, subts in pairs(substitutesLocal) do
				local _, active, spec = Spring.GetPlayerInfo(subID, false)
				if active and spec then
					if math.abs(ts - subts) <= validDiff then
						validSubs[#validSubs + 1] = subID
					end
					if math.abs(ts - subts) <= idealDiff then
						idealSubs[#idealSubs + 1] = subID
					end
				end
			end

			local wouldSub = false -- would we substitute this player if the game started now
			if #validSubs > 0 then
				-- choose who
				local sID
				if #idealSubs > 0 then
					sID = (#idealSubs > 1) and idealSubs[math.random(1, #idealSubs)] or idealSubs[1]
				else
					sID = (#validSubs > 1) and validSubs[math.random(1, #validSubs)] or validSubs[1]
				end

				if real then
					-- do the replacement
					local teamID = players[playerID]
					Spring.AssignPlayerToTeam(sID, teamID)
					players[sID] = teamID
					replaced = true

					local incoming, _ = Spring.GetPlayerInfo(sID, false)
					local outgoing, _ = Spring.GetPlayerInfo(playerID, false)
					SendToUnsynced("SubstitutionOccurred", incoming, outgoing)
				end
				substitutesLocal[sID] = nil
				wouldSub = true
			end

			-- tell luaui that if would substitute if the game started now
			Spring.SetGameRulesParam("Player" .. playerID .. "willSub", wouldSub and 1 or 0)
		end

	end

	function gadget:GameStart()
		gameStarted = true
		FindSubs(true)
	end

	function gadget:GameFrame(n)
		if n == 1 and replaced then
			-- if at least one player was replaced, reveal startpoints to all
			local coopStartPoints = GG.coopStartPoints or {}
			local revealed = {}
			for pID, p in pairs(coopStartPoints) do
				--first do the coop starts
				local name, _, _, tID = Spring.GetPlayerInfo(pID, false)
				SendToUnsynced("MarkStartPoint", p[1], p[2], p[3], name, tID)
				revealed[pID] = true
			end

			local teamStartPoints = GG.teamStartPoints or {}
			for tID, p in pairs(teamStartPoints) do
				p = teamStartPoints[tID]
				local playerList = Spring.GetPlayerList(tID)
				local name = ""
				for _, pID in pairs(playerList) do
					--now do all pIDs for this team which were not coop starts
					if not revealed[pID] then
						local pName, active, spec = Spring.GetPlayerInfo(pID, false)
						if pName and absent[pID] == nil and active and not spec then
							--AIs might not have a name, don't write the name of the dropped player
							name = name .. pName .. ", "
							revealed[pID] = true
						end
					end
				end
				if name ~= "" then
					name = string.sub(name, 1, math.max(string.len(name) - 2, 1)) --remove final ", "
				end
				SendToUnsynced("MarkStartPoint", p[1], p[2], p[3], name, tID)
			end
		end

		if n % 5 == 0 then
			CheckJoined() -- there is no PlayerChanged or PlayerAdded in synced code
		end
	end

	function CheckJoined()
		local pList = SpGetPlayerList(true)
		local cheatsOn = SpIsCheatingEnabled()
		if cheatsOn then
			return
		end

		for _, pID in ipairs(pList) do
			if not players[pID] then
				local _, active, spec, _, aID = Spring.GetPlayerInfo(pID, false)
				if active and not spec then
					--Spring.Echo("handle join", pID, active, spec)
					HandleJoinedPlayer(pID, aID)
				end
			end
		end
	end

	function HandleJoinedPlayer(jID, aID)
		-- ForceSpec(jID)
		-- currently this is no use, because players who joinas see themselves as always having been present, so it doesn't get called...
	end

else
	-----------------------------
	-- UNSYNCED
	-----------------------------

	local myPlayerID = Spring.GetMyPlayerID()
	local spec, _ = Spring.GetSpectatingState()
	local isReplay = Spring.IsReplay()
	local ColorString = Spring.Utilities.Color.ToString

	local revealed = false

	local function colourNames(teamID)
		local nameColourR, nameColourG, nameColourB, nameColourA = Spring.GetTeamColor(teamID)
		return ColorString(nameColourR, nameColourG, nameColourB)
	end

	local function MarkStartPoint(_, x, y, z, name, teamID)
		local _, _, spec = Spring.GetPlayerInfo(myPlayerID)
		if not spec then
			Spring.MarkerAddPoint(x, y, z, colourNames(teamID) .. name, true)
			revealed = true
		end
	end

	local function substitutionOccurred(_, incoming, outgoing)
		if Script.LuaUI('GadgetMessageProxy') then
			Spring.Echo( Script.LuaUI.GadgetMessageProxy('ui.substitutePlayers.substitutedPlayers', { incoming = incoming, outgoing = outgoing }) )
		end
	end

	function gadget:Initialize()
		if isReplay or Spring.Utilities.Gametype.IsFFA() or Spring.GetGameFrame() > 6 then
			gadgetHandler:RemoveGadget() -- don't run in FFA mode
			return
		end

		gadgetHandler:AddSyncAction("MarkStartPoint", MarkStartPoint)
		gadgetHandler:AddSyncAction("SubstitutionOccurred", substitutionOccurred)
		--gadgetHandler:AddSyncAction("ForceSpec", ForceSpec)
	end

	function gadget:GameFrame(n)
		if n < 5 then
			return
		end
		if revealed and Script.LuaUI('GadgetMessageProxy') then
			Spring.Echo( Script.LuaUI.GadgetMessageProxy('ui.substitutePlayers.substituted') )
		end
		gadgetHandler:RemoveGadget()
	end

	--[[function ForceSpec(_,pID)
		local myID = Spring.GetMyPlayerID()
		if pID==myID then
			Spring.Echo("You have been made a spectator - adding players is only allowed before the game starts!")
			Spring.SendCommands("spectator")
		end
	end]]

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction("MarkStartPoint")
		gadgetHandler:RemoveSyncAction("SubstitutionOccurred")
		--gadgetHandler:RemoveSyncAction("ForceSpec")
	end

end
