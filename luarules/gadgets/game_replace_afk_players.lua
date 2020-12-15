function gadget:GetInfo()
	return {
		name = "Substitution",
		desc = "Allows players absent at gamestart to be replaced by specs\nPrevents joinas to non-empty teams",
		author = "Bluestone",
		date = "June 2014",
		license = "GNU GPL, v3 or later",
		layer = 2, --run after game initial spawn and coop (because we use readyStates)
		enabled = true
	}
end

local numPlayers = 0
local teams = Spring.GetTeamList()
for i = 1, #teams do
	local _, _, _, isAiTeam = Spring.GetTeamInfo(teams[i], false)
	local luaAI = Spring.GetTeamLuaAI(teams[i])
	if (not luaAI or luaAI == '') and not isAiTeam and teams[i] ~= Spring.GetGaiaTeamID() then
		numPlayers = numPlayers + 1
	end
end
local isSinglePlayer = numPlayers == 1
if numPlayers <= 4 then
	-- not needed to show sub button for small games where restarting one the better option
	return
end

local texts = {        -- fallback (if you want to change this, also update: language/en.lua, or it will be overwritten)
	offertoplay = 'Offer to play',
	withdrawoffer = 'Withdraw offer',
	substituteecho = 'If player(s) are afk when the game starts, you might be used as a substitute',
	substitutewithdrawn = 'Your offer to substitute has been withdrawn',
	substitutionoccurred = 'Substitution occurred, revealed start positions to all',
	wassubstitutedinfor = 'was substituted in for',
}

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
			--Spring.Echo("received removal", playerID)
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
			--Spring.Echo("received", playerID, eligible, ts)
		end

		if checkChange then
			--Spring.Echo("FindSubs", "RecvLuaMsg")
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
		--Spring.Echo("FindSubs", "real=", real)

		-- make a copy of the substitutes table
		local substitutesLocal = {}
		local i = 0
		for pID, ts in pairs(substitutes) do
			substitutesLocal[pID] = ts
			i = i + 1
		end
		absent = {}

		--local theSubs = ""
		--for k,v in pairs(substitutesLocal) do theSubs = theSubs .. tostring(k) .. "[" .. v .. "]" .. "," end
		--Spring.Echo("#subs: " .. i , theSubs)

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
					--Spring.Echo("absent:", playerID, ts)
				end
			end
			-- if present, tell LuaUI that won't be substituted
			if not absent[playerID] then
				Spring.SetGameRulesParam("Player" .. playerID .. "willSub", 0)
			end
		end
		--Spring.Echo("#absent: " .. #absent)

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
			--Spring.Echo("ideal: " .. #idealSubs .. " for pID " .. playerID)
			--Spring.Echo("valid: " .. #validSubs .. " for pID " .. playerID)

			local wouldSub = false -- would we substitute this player if the game started now
			if #validSubs > 0 then
				-- choose who
				local sID
				if #idealSubs > 0 then
					sID = (#idealSubs > 1) and idealSubs[math.random(1, #idealSubs)] or idealSubs[1]
					--Spring.Echo("picked ideal sub", sID)
				else
					sID = (#validSubs > 1) and validSubs[math.random(1, #validSubs)] or validSubs[1]
					--Spring.Echo("picked valid sub", sID)
				end

				--Spring.Echo("real", real)
				if real then
					-- do the replacement
					local teamID = players[playerID]
					Spring.AssignPlayerToTeam(sID, teamID)
					players[sID] = teamID
					replaced = true

					local incoming, _ = Spring.GetPlayerInfo(sID, false)
					local outgoing, _ = Spring.GetPlayerInfo(playerID, false)
					Spring.Echo(incoming .. ' '..texts.wassubstitutedinfor..' ' .. outgoing)
				end
				substitutesLocal[sID] = nil
				wouldSub = true
			end

			-- tell luaui that if would substitute if the game started now
			--Spring.Echo("wouldSub: " .. (sID or "-1") .. " for pID " .. playerID)
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


	---------------------------

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

	-----------------------------
else
	-- begin unsynced section
	-----------------------------

	local fontfile = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")
	local vsx, vsy = Spring.GetViewGeometry()
	local fontfileScale = (0.5 + (vsx * vsy / 5700000))
	local fontfileSize = 40
	local fontfileOutlineSize = 9
	local fontfileOutlineStrength = 1.4
	local font = gl.LoadFont(fontfile, fontfileSize * fontfileScale, fontfileOutlineSize * fontfileScale, fontfileOutlineStrength)

	local customScale = 1.15
	local uiScale = customScale
	local x = 500
	local y = 500

	local myPlayerID = Spring.GetMyPlayerID()
	local spec, _ = Spring.GetSpectatingState()
	local isReplay = Spring.IsReplay()

	local eligible, guishaderApplied

	function gadget:ViewResize(viewSizeX, viewSizeY)
		vsx, vsy = Spring.GetViewGeometry()
		local newFontfileScale = (0.5 + (vsx * vsy / 5700000))
		if (fontfileScale ~= newFontfileScale) then
			fontfileScale = newFontfileScale
			gl.DeleteFont(font)
			font = gl.LoadFont(fontfile, fontfileSize * fontfileScale, fontfileOutlineSize * fontfileScale, fontfileOutlineStrength)
		end
	end

	local subsButton, subsButtonHover
	local bX = vsx * 0.8
	local bY = vsy * 0.8
	local bH = 30
	local bW = 140
	local bgMargin = 2.5
	local offer = false

	local function DrawRectRound(px, py, sx, sy, cs, tl, tr, br, bl, c1, c2)
		local csyMult = 1 / ((sy - py) / cs)

		if c2 then
			gl.Color(c1[1], c1[2], c1[3], c1[4])
		end
		gl.Vertex(px + cs, py, 0)
		gl.Vertex(sx - cs, py, 0)
		if c2 then
			gl.Color(c2[1], c2[2], c2[3], c2[4])
		end
		gl.Vertex(sx - cs, sy, 0)
		gl.Vertex(px + cs, sy, 0)

		-- left side
		if c2 then
			gl.Color(c1[1] * (1 - csyMult) + (c2[1] * csyMult), c1[2] * (1 - csyMult) + (c2[2] * csyMult), c1[3] * (1 - csyMult) + (c2[3] * csyMult), c1[4] * (1 - csyMult) + (c2[4] * csyMult))
		end
		gl.Vertex(px, py + cs, 0)
		gl.Vertex(px + cs, py + cs, 0)
		if c2 then
			gl.Color(c2[1] * (1 - csyMult) + (c1[1] * csyMult), c2[2] * (1 - csyMult) + (c1[2] * csyMult), c2[3] * (1 - csyMult) + (c1[3] * csyMult), c2[4] * (1 - csyMult) + (c1[4] * csyMult))
		end
		gl.Vertex(px + cs, sy - cs, 0)
		gl.Vertex(px, sy - cs, 0)

		-- right side
		if c2 then
			gl.Color(c1[1] * (1 - csyMult) + (c2[1] * csyMult), c1[2] * (1 - csyMult) + (c2[2] * csyMult), c1[3] * (1 - csyMult) + (c2[3] * csyMult), c1[4] * (1 - csyMult) + (c2[4] * csyMult))
		end
		gl.Vertex(sx, py + cs, 0)
		gl.Vertex(sx - cs, py + cs, 0)
		if c2 then
			gl.Color(c2[1] * (1 - csyMult) + (c1[1] * csyMult), c2[2] * (1 - csyMult) + (c1[2] * csyMult), c2[3] * (1 - csyMult) + (c1[3] * csyMult), c2[4] * (1 - csyMult) + (c1[4] * csyMult))
		end
		gl.Vertex(sx - cs, sy - cs, 0)
		gl.Vertex(sx, sy - cs, 0)

		local offset = 0.15        -- texture offset, because else gaps could show

		-- bottom left
		if c2 then
			gl.Color(c1[1], c1[2], c1[3], c1[4])
		end
		if ((py <= 0 or px <= 0) or (bl ~= nil and bl == 0)) and bl ~= 2 then
			gl.Vertex(px, py, 0)
		else
			gl.Vertex(px + cs, py, 0)
		end
		gl.Vertex(px + cs, py, 0)
		if c2 then
			gl.Color(c1[1] * (1 - csyMult) + (c2[1] * csyMult), c1[2] * (1 - csyMult) + (c2[2] * csyMult), c1[3] * (1 - csyMult) + (c2[3] * csyMult), c1[4] * (1 - csyMult) + (c2[4] * csyMult))
		end
		gl.Vertex(px + cs, py + cs, 0)
		gl.Vertex(px, py + cs, 0)
		-- bottom right
		if c2 then
			gl.Color(c1[1], c1[2], c1[3], c1[4])
		end
		if ((py <= 0 or sx >= vsx) or (br ~= nil and br == 0)) and br ~= 2 then
			gl.Vertex(sx, py, 0)
		else
			gl.Vertex(sx - cs, py, 0)
		end
		gl.Vertex(sx - cs, py, 0)
		if c2 then
			gl.Color(c1[1] * (1 - csyMult) + (c2[1] * csyMult), c1[2] * (1 - csyMult) + (c2[2] * csyMult), c1[3] * (1 - csyMult) + (c2[3] * csyMult), c1[4] * (1 - csyMult) + (c2[4] * csyMult))
		end
		gl.Vertex(sx - cs, py + cs, 0)
		gl.Vertex(sx, py + cs, 0)
		-- top left
		if c2 then
			gl.Color(c2[1], c2[2], c2[3], c2[4])
		end
		if ((sy >= vsy or px <= 0) or (tl ~= nil and tl == 0)) and tl ~= 2 then
			gl.Vertex(px, sy, 0)
		else
			gl.Vertex(px + cs, sy, 0)
		end
		gl.Vertex(px + cs, sy, 0)
		if c2 then
			gl.Color(c2[1] * (1 - csyMult) + (c1[1] * csyMult), c2[2] * (1 - csyMult) + (c1[2] * csyMult), c2[3] * (1 - csyMult) + (c1[3] * csyMult), c2[4] * (1 - csyMult) + (c1[4] * csyMult))
		end
		gl.Vertex(px + cs, sy - cs, 0)
		gl.Vertex(px, sy - cs, 0)
		-- top right
		if c2 then
			gl.Color(c2[1], c2[2], c2[3], c2[4])
		end
		if ((sy >= vsy or sx >= vsx) or (tr ~= nil and tr == 0)) and tr ~= 2 then
			gl.Vertex(sx, sy, 0)
		else
			gl.Vertex(sx - cs, sy, 0)
		end
		gl.Vertex(sx - cs, sy, 0)
		if c2 then
			gl.Color(c2[1] * (1 - csyMult) + (c1[1] * csyMult), c2[2] * (1 - csyMult) + (c1[2] * csyMult), c2[3] * (1 - csyMult) + (c1[3] * csyMult), c2[4] * (1 - csyMult) + (c1[4] * csyMult))
		end
		gl.Vertex(sx - cs, sy - cs, 0)
		gl.Vertex(sx, sy - cs, 0)
	end
	function RectRound(px, py, sx, sy, cs, tl, tr, br, bl, c1, c2)
		-- (coordinates work differently than the RectRound func in other widgets)
		gl.Texture(false)
		gl.BeginEnd(GL.QUADS, DrawRectRound, px, py, sx, sy, cs, tl, tr, br, bl, c1, c2)
	end

	function correctMouseForScaling(x, y)
		local buttonScreenCenterPosX = (bX + (bW / 2)) / vsx
		local buttonScreenCenterPosY = (bY + (bH / 2)) / vsy
		x = x - (((x / vsx) - buttonScreenCenterPosX) * vsx) * ((uiScale - 1) / uiScale)
		y = y - (((y / vsy) - buttonScreenCenterPosY) * vsy) * ((uiScale - 1) / uiScale)
		return x, y
	end

	function MakeButton()
		subsButton = gl.CreateList(function()
			-- draws background rectangle
			gl.Color(0, 0, 0, 0.8)
			RectRound(-((bW / 2) + bgMargin), -((bH / 2) + bgMargin), ((bW / 2) + bgMargin), ((bH / 2) + bgMargin), 4, 2, 2, 2, 2)
			--gl.Color(1,1,1,0.13)
			RectRound(-bW / 2, -bH / 2, bW / 2, bH / 2, 3, 2, 2, 2, 2, { 1, 1, 1, 0 }, { 1, 1, 1, 0.1 })
			-- gloss
			gl.Blending(GL.SRC_ALPHA, GL.ONE)
			RectRound(-bW / 2, 0, bW / 2, bH / 2, 3, 2, 2, 0, 0, { 1, 1, 1, 0.035 }, { 1, 1, 1, 0.11 })
			RectRound(-bW / 2, -bH / 2, bW / 2, -bH / 4, 3, 0, 0, 2, 2, { 1, 1, 1, 0.045 }, { 1, 1, 1, 0 })
			gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
			gl.Color(1, 1, 1, 1)
		end)
		subsButtonHover = gl.CreateList(function()
			-- draws background rectangle
			gl.Color(0.15, 0.12, 0, 0.8)
			RectRound(-((bW / 2) + bgMargin), -((bH / 2) + bgMargin), ((bW / 2) + bgMargin), ((bH / 2) + bgMargin), 4, 2, 2, 2, 2)
			--gl.Color(1,0.8,0.3,0.33)
			RectRound(-bW / 2, -bH / 2, bW / 2, bH / 2, 3, 2, 2, 2, 2, { 1, 1, 1, 0 }, { 1, 1, 1, 0.22 })
			-- gloss
			gl.Blending(GL.SRC_ALPHA, GL.ONE)
			RectRound(-bW / 2, 0, bW / 2, bH / 2, 3, 2, 2, 0, 0, { 1, 1, 1, 0.05 }, { 1, 1, 1, 0.18 })
			RectRound(-bW / 2, -bH / 2, bW / 2, -bH / 4, 3, 0, 0, 2, 2, { 1, 1, 1, 0.07 }, { 1, 1, 1, 0 })
			gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
			gl.Color(1, 1, 1, 1)
		end)
	end

	function gadget:Initialize()

		if GG.lang then
			texts = GG.lang.getText('replaceafkplayers')
		end

		if isReplay or (tonumber(Spring.GetModOptions().ffa_mode) or 0) == 1 or Spring.GetGameFrame() > 6 then
			gadgetHandler:RemoveGadget() -- don't run in FFA mode
			return
		end

		gadgetHandler:AddSyncAction("MarkStartPoint", MarkStartPoint)
		--gadgetHandler:AddSyncAction("ForceSpec", ForceSpec)

		-- match the equivalent check in synced
		--local customtable = select(11,Spring.GetPlayerInfo(myPlayerID))
		local tsMu = "30"--customtable.skill
		local tsSigma = "0"--customtable.skilluncertainty
		--local ts = tsMu and tonumber(tsMu:match("%d+%.?%d*"))
		tsSigma = tonumber(tsSigma)
		eligible = tsMu and tsSigma and (tsSigma <= 2) and (not string.find(tsMu, ")")) and spec

		MakeButton()
	end

	function gadget:DrawScreen()
		if eligible then
			-- ask each spectator if they would like to replace an absent player
			uiScale = (0.75 + (vsx * vsy / 7500000)) * customScale
			gl.PushMatrix()
			gl.Translate(bX + (bW / 2), bY + (bH / 2), 0)
			gl.Scale(uiScale, uiScale, 1)

			-- draw button and its text
			local x, y = Spring.GetMouseState()
			local colorString
			x, y = correctMouseForScaling(x, y)
			if x > bX - bgMargin and x < bX + bW + bgMargin and y > bY - bgMargin and y < bY + bH + bgMargin then
				gl.CallList(subsButtonHover)
				colorString = "\255\255\222\0"
			else
				gl.CallList(subsButton)
				colorString = "\255\255\255\255"
			end
			if not guishaderApplied and Script.LuaUI("GuishaderInsertRect") then
				guishaderApplied = true
				local x1, y1 = correctMouseForScaling(bX - bgMargin, bY - bgMargin)
				local x2, y2 = correctMouseForScaling(bX + bW + bgMargin, bY + bH + bgMargin)
				Script.LuaUI.GuishaderInsertRect(x1, y1, x2, y2, 'offertoplay')
			end
			local textString
			if not offer then
				textString = texts.offertoplay
			else
				textString = texts.withdrawoffer
			end
			font:Begin()
			font:Print(colorString .. textString, -((bW / 2) - 12.5), -((bH / 2) - 9.5), 19, "o")
			font:End()
			gl.Color(1, 1, 1, 1)
			gl.PopMatrix()
		else
			if guishaderApplied and Script.LuaUI("GuishaderRemoveRect") then
				Script.LuaUI.GuishaderRemoveRect('offertoplay')
				guishaderApplied = nil
			end
			gadgetHandler:RemoveCallIn("DrawScreen") -- no need to waste cycles
		end
	end

	function gadget:MousePress(sx, sy)
		-- pressing b
		sx, sy = correctMouseForScaling(sx, sy)
		if sx > bX - bgMargin and sx < bX + bW + bgMargin and sy > bY - bgMargin and sy < bY + bH + bgMargin and eligible then
			--Spring.Echo("sent", myPlayerID, ts)
			if not offer then
				Spring.SendLuaRulesMsg('\144')
				Spring.Echo(texts.substituteecho)
				offer = true
				bW = 160
				MakeButton()
				return true
			else
				Spring.SendLuaRulesMsg('\145')
				Spring.Echo(texts.substitutewithdrawn)
				offer = false
				bW = 140
				MakeButton()
				return true
			end
		end
		return false
	end

	function gadget:MouseRelease(x, y)
	end

	function gadget:GameStart()
		eligible = false -- no substitutions after game start
	end

	local revealed = false
	function MarkStartPoint(_, x, y, z, name, tID)
		local _, _, spec = Spring.GetPlayerInfo(myPlayerID)
		if not spec then
			Spring.MarkerAddPoint(x, y, z, colourNames(tID) .. name, true)
			revealed = true
		end
	end

	function colourNames(teamID)
		local nameColourR, nameColourG, nameColourB, nameColourA = Spring.GetTeamColor(teamID)
		local R255 = math.floor(nameColourR * 255)
		local G255 = math.floor(nameColourG * 255)
		local B255 = math.floor(nameColourB * 255)
		if R255 % 10 == 0 then
			R255 = R255 + 1
		end
		if G255 % 10 == 0 then
			G255 = G255 + 1
		end
		if B255 % 10 == 0 then
			B255 = B255 + 1
		end
		return "\255" .. string.char(R255) .. string.char(G255) .. string.char(B255) --works thanks to zwzsg
	end

	function gadget:GameFrame(n)
		if n ~= 5 then
			return
		end
		if revealed then
			Spring.Echo(texts.substitutionoccurred)
		end

		gadgetHandler:RemoveCallIn("GameFrame")
	end

	--[[function ForceSpec(_,pID)
		local myID = Spring.GetMyPlayerID()
		if pID==myID then
			Spring.Echo("You have been made a spectator - adding players is only allowed before the game starts!")
			Spring.SendCommands("spectator")
		end
	end]]

	function gadget:Shutdown()
		gl.DeleteList(subsButton)
		gl.DeleteList(subsButtonHover)
		gl.DeleteFont(font)
		gadgetHandler:RemoveSyncAction("MarkStartPoint")
		--gadgetHandler:RemoveSyncAction("ForceSpec")
	end

	-----------------------------
end -- end unsynced section
-----------------------------
