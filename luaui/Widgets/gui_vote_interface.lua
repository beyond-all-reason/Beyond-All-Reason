local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Vote interface",
		desc = "",
		author = "Floris",
		date = "July 2018",
		license = "GNU GPL, v2 or later",
		layer = -985000,
		enabled = true,
	}
end

local L_DEPRECATED = LOG.DEPRECATED

local titlecolor = "\255\190\190\190"

-- dont show vote buttons for specs when containing the following keywords (use lowercase)
local globalVoteWords =  { 'forcestart', 'stop', 'joinas', 'kickban', 'gkick', 'bkick', 'nospecchat' }

local INDIVIDUAL_RESIGN_VOTE_PATTERN = "called a vote for command \"resign ([^%s]+)\""
local TEAM_RESIGN_VOTE_PATTERN = "called a vote for command \"resign ([^%s]+) TEAM\""

local voteEndDelay = 4
local voteTimeout = 75	-- fallback timeout in case vote is aborted undetected

local vsx, vsy = Spring.GetViewGeometry()

local ui_scale = tonumber(Spring.GetConfigFloat("ui_scale", 1) or 1)

local myPlayerID = Spring.GetMyPlayerID()
local myPlayerName, _, mySpec, myTeamID, myAllyTeamID = Spring.GetPlayerInfo(myPlayerID, false)

local isreplay = Spring.IsReplay()

local ColorString = Spring.Utilities.Color.ToString
local math_isInRect = math.isInRect
local sfind = string.find
local ssub = string.sub
local slower = string.lower

local RectRound, UiElement, UiButton, bgpadding, elementCorner, widgetSpaceMargin
local voteDlist, font, font2, gameStarted, dlistGuishader
local weAreVoteOwner, hovered, voteName, windowArea, closeButtonArea, yesButtonArea, noButtonArea
local voteEndTime, voteEndText

local eligibleToVote = false
local teamResignMode = Spring.GetModOptions().team_resign

local votesRequired, votesEligible
local votesCountYes = 0
local votesCountNo = 0
local minimized = false
local voteStartTime

local function isTeamPlayer(playerName)
	local players = Spring.GetPlayerList()
	for _, pID in ipairs(players) do
		local name, _, _, _, allyTeamID = Spring.GetPlayerInfo(pID, false)
		if name == playerName then
			if allyTeamID == myAllyTeamID then
				return true
			end
		end
	end
	return false
end

local function CloseVote()
	voteEndTime = nil
	voteEndText = nil
	voteStartTime = nil
	if voteDlist then
		votesRequired = nil
		votesEligible = nil
		votesCountYes = 0
		votesCountNo = 0
		minimized = false
		voteDlist = nil
		voteName = nil
		weAreVoteOwner = nil
		eligibleToVote = false
		if WG['guishader'] then
			WG['guishader'].DeleteDlist('voteinterface')
		end
		gl.DeleteList(voteDlist)
	end
end

local function StartVote(name)	-- when called without params its just to refresh (when hovering over buttons)
	if name then
		CloseVote()
	end
	if voteDlist then
		gl.DeleteList(voteDlist)
	end
	voteStartTime = os.clock()
	voteDlist = gl.CreateList(function()
		if name then
			voteName = name
		end

		local color1, color2, w
		local x, y, b = Spring.GetMouseState()

		local width = math.floor((vsy / 6) * ui_scale) * 2	-- *2 so it ensures number can be divided cleanly by 2
		local height = math.floor((vsy / 23) * ui_scale) * 2		-- *2 so it ensures number can be divided cleanly by 2

		local progressbarHeight = math.ceil(height * 0.055)

		local fontSize = height / 5    -- title only
		local minWidth = font:GetTextWidth('  ' .. voteName .. '  ') * fontSize
		if width < minWidth then
			width = minWidth
		end

		local buttonMargin = math.floor(width / 32)
		local buttonHeight = math.floor(height * 0.55)
		if not eligibleToVote or minimized then
			height = height - buttonHeight
		end
		-- make sure height is dividable by 2
		if height % 2 == 1 then
			height = height + 1
		end

		local xpos = math.floor(width / 2)
		local ypos = math.floor(vsy - (height / 2))

		if WG['topbar'] ~= nil then
			local topbarArea = WG['topbar'].GetPosition()
			xpos = math.floor(topbarArea[1] + (width/2) + widgetSpaceMargin + ((topbarArea[3] - topbarArea[1])/2))
			ypos = math.floor(topbarArea[2] - widgetSpaceMargin - (height / 2))
		end

		hovered = nil

		windowArea = { xpos - (width / 2), ypos - (height / 2), xpos + (width / 2), ypos + (height / 2) }
		closeButtonArea = { (xpos + (width / 2)) - (height / 2), ypos + math.floor(height / 6), xpos + (width / 2), ypos + (height / 2)}
		yesButtonArea = { xpos - (width / 2) + buttonMargin, ypos - (height / 2) + buttonMargin + progressbarHeight, xpos - (buttonMargin / 2), ypos - (height / 2) + buttonHeight - buttonMargin + progressbarHeight }
		noButtonArea = { xpos + (buttonMargin / 2), ypos - (height / 2) + buttonMargin + progressbarHeight, xpos + (width / 2) - buttonMargin, ypos - (height / 2) + buttonHeight - buttonMargin + progressbarHeight}

		if not voteEndText then
			UiElement(windowArea[1], windowArea[2], windowArea[3], windowArea[4], 1,1,1,1, 1,1,1,1, math.max(0.75, Spring.GetConfigFloat("ui_opacity", 0.7)))
		end

		-- progress bar
		if votesEligible then
			if votesRequired then
				-- progress bar: required for
				w = math.floor(((windowArea[3] - windowArea[1] - bgpadding - bgpadding) / votesEligible) * votesRequired)
				color1 = { 0, 0.6, 0, 0.1 }
				color2 = { 0, 1, 0, 0.1 }
				RectRound(windowArea[1] + bgpadding, windowArea[2] + bgpadding, windowArea[1] + bgpadding + w, windowArea[2] + bgpadding + progressbarHeight, elementCorner*0.6, 0, 0, 0, 1, color1, color2)
				if votesEligible ~= votesRequired then
					-- progress bar: required minority against
					color1 = { 0.6, 0, 0, 0.1 }
					color2 = { 1, 0, 0, 0.1 }
					RectRound(windowArea[1] + bgpadding + w, windowArea[2] + bgpadding, windowArea[3] - bgpadding, windowArea[2] + bgpadding + progressbarHeight, elementCorner*0.6, 0, 0, 1, 0, color1, color2)
				end
			end

			-- progress bar: for
			if votesCountYes > 0 then
				w = math.floor(((windowArea[3] - windowArea[1] - bgpadding - bgpadding) / votesEligible) * votesCountYes)
				color1 = { 0, 0.33, 0, 1 }
				color2 = { 0, 0.6, 0, 1 }
				RectRound(windowArea[1] + bgpadding, windowArea[2] + bgpadding, windowArea[1] + bgpadding + w, windowArea[2] + bgpadding + progressbarHeight, elementCorner*0.6, 0, 0, 0, 1, color1, color2)
				-- highlight
				color1 = { 1, 1, 1, 0 }
				color2 = { 1, 1, 1, 0.15 }
				RectRound(windowArea[1] + bgpadding, windowArea[2] + bgpadding + (progressbarHeight/2), windowArea[1] + bgpadding + w, windowArea[2] + bgpadding + progressbarHeight, 0, 0, 0, 0, 1, color1, color2)
				color1 = { 1, 1, 1, 0.08 }
				color2 = { 1, 1, 1, 0 }
				RectRound(windowArea[1] + bgpadding, windowArea[2] + bgpadding, windowArea[1] + bgpadding + w, windowArea[2] + bgpadding + (progressbarHeight/2), 0, 0, 0, 0, 1, color1, color2)
			end
			-- progress bar: against
			if votesCountNo > 0 then
				w = math.floor(((windowArea[3] - windowArea[1] - bgpadding - bgpadding) / votesEligible) * votesCountNo)
				color1 = { 0.33, 0, 0, 1 }
				color2 = { 0.6, 0, 0, 1 }
				RectRound(windowArea[3] - bgpadding - w, windowArea[2] + bgpadding, windowArea[3] - bgpadding, windowArea[2] + bgpadding + progressbarHeight, elementCorner*0.6, 0, 0, 1, 0, color1, color2)
				-- highlight
				color1 = { 1, 1, 1, 0 }
				color2 = { 1, 1, 1, 0.15 }
				RectRound(windowArea[3] - bgpadding - w, windowArea[2] + bgpadding + (progressbarHeight/2), windowArea[3] - bgpadding, windowArea[2] + bgpadding + progressbarHeight, 0, 0, 0, 1, 0, color1, color2)
				color1 = { 1, 1, 1, 0.08 }
				color2 = { 1, 1, 1, 0 }
				RectRound(windowArea[3] - bgpadding - w, windowArea[2] + bgpadding, windowArea[3] - bgpadding, windowArea[2] + bgpadding + (progressbarHeight/2), 0, 0, 0, 1, 0, color1, color2)
			end

			-- progress bar: highlight
			color1 = { 1, 1, 1, 0 }
			color2 = { 1, 1, 1, 0.085 }
			RectRound(windowArea[1] + bgpadding, windowArea[2] + bgpadding + (progressbarHeight/2), windowArea[3] - bgpadding, windowArea[2] + bgpadding + progressbarHeight, 0, 0, 0, 0, 0, color1, color2)
			color1 = { 1, 1, 1, 0.023 }
			color2 = { 1, 1, 1, 0 }
			RectRound(windowArea[1] + bgpadding, windowArea[2] + bgpadding, windowArea[3] - bgpadding, windowArea[2] + bgpadding + (progressbarHeight/2), 0, 0, 0, 0, 0, color1, color2)
		end

		fontSize = fontSize * 0.85
		gl.Color(0, 0, 0, 1)

		-- vote name
		font:Begin()
		font:Print(titlecolor .. voteName, windowArea[1] + ((windowArea[3] - windowArea[1]) / 2), windowArea[4] - bgpadding - bgpadding - bgpadding - fontSize, fontSize, "con")
		font:End()

		if eligibleToVote and not minimized and not voteEndText then

			-- ESC
			local color1, color2
			if math_isInRect(x, y, closeButtonArea[1], closeButtonArea[2], closeButtonArea[3], closeButtonArea[4]) then
				hovered = 'esc'
				color1 = { 0.6, 0.6, 0.6, 0.6 }
				color2 = { 1, 1, 1, 0.6 }
			else
				color1 = { 0.6, 0.6, 0.6, 0.08 }
				color2 = { 1, 1, 1, 0.08 }
			end
			RectRound(closeButtonArea[1] + bgpadding, closeButtonArea[2] + bgpadding, closeButtonArea[3] - bgpadding, closeButtonArea[4] - bgpadding, elementCorner*0.66, 0, 1, 0, 1, color1, color2)
			font2:Begin()
			font2:SetOutlineColor(1, 1, 1, 0.2)
			font2:SetTextColor(0, 0, 0, 0.7)
			font2:Print("\255\000\000\000" .. Spring.I18N('ui.voting.cancel'), closeButtonArea[1] + ((closeButtonArea[3] - closeButtonArea[1]) / 2), closeButtonArea[2] + ((closeButtonArea[4] - closeButtonArea[2]) / 2) - (fontSize / 3), fontSize, "cn")

			-- NO / End Vote
			local color1, color2, mult
			if math_isInRect(x, y, noButtonArea[1], noButtonArea[2], noButtonArea[3], noButtonArea[4]) then
				hovered = 'n'
				color1 = { 0.5, 0.07, 0.07, 0.8 }
				color2 = { 0.7, 0.1, 0.1, 0.8 }
				mult = 1.15
			else
				color1 = { 0.4, 0, 0, 0.75 }
				color2 = { 0.5, 0, 0, 0.75 }
				mult = 1
			end
			UiButton(noButtonArea[1], noButtonArea[2], noButtonArea[3], noButtonArea[4], 1,1,1,1, 1,1,1,1, nil, color1, color2, elementCorner*0.4)

			fontSize = fontSize * 0.85
			font2:SetOutlineColor(0, 0, 0, 0.4)
			font2:SetTextColor(1, 1, 1, 1)
			font2:Print((weAreVoteOwner and Spring.I18N('ui.voting.endVote') or Spring.I18N('ui.voting.no')), noButtonArea[1] + ((noButtonArea[3] - noButtonArea[1]) / 2), noButtonArea[2] + ((noButtonArea[4] - noButtonArea[2]) / 2) - (fontSize / 3), fontSize, "con")

			-- YES
			if not weAreVoteOwner then
				if math_isInRect(x, y, yesButtonArea[1], yesButtonArea[2], yesButtonArea[3], yesButtonArea[4]) then
					hovered = 'y'
					color1 = { 0.035, 0.4, 0.035, 0.8 }
					color2 = { 0.05, 0.6, 0.5, 0.8 }
					mult = 1.15
				else
					color1 = { 0, 0.4, 0, 0.38 }
					color2 = { 0, 0.5, 0, 0.38 }
					mult = 1
				end
				UiButton(yesButtonArea[1], yesButtonArea[2], yesButtonArea[3], yesButtonArea[4], 1,1,1,1, 1,1,1,1, nil, color1, color2, elementCorner*0.4)
				font2:Print(Spring.I18N('ui.voting.yes'), yesButtonArea[1] + ((yesButtonArea[3] - yesButtonArea[1]) / 2), yesButtonArea[2] + ((yesButtonArea[4] - yesButtonArea[2]) / 2) - (fontSize / 3), fontSize, "con")
			end
			font2:End()
		end

		if voteEndText then
			UiElement(windowArea[1], windowArea[2], windowArea[3], windowArea[4], 1,1,1,1, 1,1,1,1, math.max(0.75, Spring.GetConfigFloat("ui_opacity", 0.7)))
			font:Begin()
			font:Print(titlecolor .. voteEndText, windowArea[1] + ((windowArea[3] - windowArea[1]) / 2), windowArea[2] + ((windowArea[4] - windowArea[2]) / 2)-(fontSize*0.3), fontSize*1.1, "con")
			font:End()
		end

		gl.Color(1, 1, 1, 1)
	end)

	-- background blur
	if WG['guishader'] then
		dlistGuishader = gl.CreateList(function()
			RectRound(windowArea[1], windowArea[2], windowArea[3], windowArea[4], elementCorner)
		end)
		WG['guishader'].InsertDlist(dlistGuishader, 'voteinterface')
	end
end

local function MinimizeVote()
	minimized = true
	StartVote()
end

function widget:ViewResize()
	vsx, vsy = Spring.GetViewGeometry()

	widgetSpaceMargin = WG.FlowUI.elementMargin
	bgpadding = WG.FlowUI.elementPadding
	elementCorner = WG.FlowUI.elementCorner

	RectRound = WG.FlowUI.Draw.RectRound
	UiElement = WG.FlowUI.Draw.Element
	UiButton = WG.FlowUI.Draw.Button

	font = WG['fonts'].getFont()
	font2 = WG['fonts'].getFont(2)
end

function widget:PlayerChanged(playerID)
	mySpec = Spring.GetSpectatingState()
	myPlayerName, _, mySpec, myTeamID, myAllyTeamID = Spring.GetPlayerInfo(myPlayerID, false)
end

local debug = false
local debugSec = 0
local debugStep = 0
function widget:Update(dt)
	if debug then
		debugSec = debugSec + dt
		if debugSec > 1 and debugStep < 1 then
			debugStep = 1
			widget:AddConsoleLine("> [teh]cluster1[00] * [teh]N0by called a vote for command \"stop\" [!vote y, !vote n, !vote b]", false)
			widget:AddConsoleLine("> [teh]cluster1[00] * 8 users allowed to vote.", false)
		end
		if debugSec > 2 and debugStep < 2 then
			debugStep = 2
			--widget:AddConsoleLine("> [teh]cluster1[00] * Vote in progress: \"stop\" [y:1/4, n:1/3] (43s remaining)", false)
			widget:AddConsoleLine("> [teh]cluster2[00] * Vote in progress: \"resign PyroTech TEAM\" [y:1/1(4), n:0/1(3), votes:1/3] (40s remaining)", false)
		end
		if debugSec > 2.75 and debugStep < 3 then
			debugStep = 3
			widget:AddConsoleLine("> [teh]cluster1[00] * Vote in progress: \"stop\" [y:2/4, n:1/3] (42s remaining)", false)
		end
		if debugSec > 3.3 and debugStep < 4 then
			debugStep = 4
			widget:AddConsoleLine("> [teh]cluster1[00] * Vote in progress: \"stop\" [y:3/4, n:1/3] (41s remaining)", false)
		end
		if debugSec > 4.2 and debugStep < 5 then
			debugStep = 5
			widget:AddConsoleLine("> [teh]cluster1[00] * Vote in progress: \"stop\" [y:3/4, n:2/3] (41s remaining)", false)
		end
		if debugSec > 5.5 and debugStep < 6 then
			debugStep = 6
			widget:AddConsoleLine("> [teh]cluster1[00] * Vote for command \"stop\" passed.", false)
		end
	end

	if not voteEndTime and voteStartTime and (voteStartTime + voteTimeout < os.clock()) then
		voteEndTime = os.clock() + (voteEndDelay*0.5)
		voteEndText = "-----"
		MinimizeVote()
		--CloseVote()
	end

	if voteEndTime and os.clock() > voteEndTime then
		CloseVote()
	end
end

function widget:Initialize()
	widget:ViewResize()
end

function widget:GameFrame(n)
	if n > 0 and not gameStarted then
		gameStarted = true
		myPlayerID = Spring.GetMyPlayerID()
		myPlayerName, _, mySpec, myTeamID, myAllyTeamID = Spring.GetPlayerInfo(myPlayerID, false)
	end
end

local function colourNames(teamID)
	local nameColourR, nameColourG, nameColourB, nameColourA = Spring.GetTeamColor(teamID)
	--if (not mySpecStatus) and anonymousMode ~= "disabled" and teamID ~= myTeamID then
	--	nameColourR, nameColourG, nameColourB = anonymousTeamColor[1], anonymousTeamColor[2], anonymousTeamColor[3]
	--end
	return ColorString(nameColourR, nameColourG, nameColourB)
end

function widget:AddConsoleLine(lines, priority)
	if priority and priority == L_DEPRECATED then return end
	if not WG['rejoin'] or not WG['rejoin'].showingRejoining() then

		lines = lines:match('^%[f=[0-9]+%] (.*)$') or lines
		for line in lines:gmatch("[^\n]+") do

			-- system message
			if ssub(line, 1, 1) == ">" and ssub(line, 3, 3) ~= "<" then

				-- vote called
				-- > [teh]cluster1[00] * [teh]N0by called a vote for command "stop" [!vote y, !vote n, !vote b]
				-- > [teh]cluster2[06] * [ur]mum called a vote for command "stop please" [!vote y, !vote n, !vote b]
				if sfind(line, " called a vote ", nil, true) then

					-- find who started the vote, and see if we're allied
					local ownerPlayername = false
					local alliedWithVoteOwner = false
					local players = Spring.GetPlayerList()
					for _, playerID in ipairs(players) do
						local playerName, _, spec, teamID, allyTeamID = Spring.GetPlayerInfo(playerID, false)
						if sfind(line, string.gsub(playerName, "%p", "%%%1") .. " called a vote ") then
							ownerPlayername = playerName
							if allyTeamID == myAllyTeamID then
								alliedWithVoteOwner = true
							end
							break
						end
					end
					weAreVoteOwner = (ownerPlayername == myPlayerName)

					local title = ssub(line, sfind(line, ' "') + 2, sfind(line, '" ', nil, true) - 1) .. '?'
					title = title:sub(1, 1):upper() .. title:sub(2)

					if not isreplay then
						eligibleToVote = alliedWithVoteOwner
						if not eligibleToVote then
							for _, keyword in pairs(globalVoteWords) do
								if sfind(slower(title), keyword, nil, true) then
									eligibleToVote = true
									break
								end
							end
						end
						if mySpec then
							eligibleToVote = false
						end
					end

					local individualResignTarget = string.match(line, INDIVIDUAL_RESIGN_VOTE_PATTERN)
					local teamResignTarget = string.match(line, TEAM_RESIGN_VOTE_PATTERN)

					local isIndividualResignVote = individualResignTarget ~= nil
					if teamResignMode then
						isIndividualResignVote = nil
					end

					local isTeamResignVote = teamResignTarget ~= nil

					local isResignVote = isIndividualResignVote or isTeamResignVote
					local isResignVoteMyTeam = mySpec or (isIndividualResignVote and isTeamPlayer(individualResignTarget)) or (isTeamResignVote and isTeamPlayer(teamResignTarget))

					-- colorize playername
					if isResignVote or isResignVoteMyTeam then
						local players = Spring.GetPlayerList()
						for _, pID in ipairs(players) do
							local name, _, spec, teamID, allyTeamID = Spring.GetPlayerInfo(pID, false)
							name = ((WG.playernames and WG.playernames.getPlayername) and WG.playernames.getPlayername(pID)) or name
							local pos = sfind(title, ' '..name..' ', nil, true)
							if pos then
								title = ssub(title, 1, pos-1).. colourNames(teamID) ..' '.. name ..' '.. titlecolor .. ssub(title, pos + string.len(' '..name..' '))
								break
							end
						end
					end

					if not isResignVote or isResignVoteMyTeam then
						votesRequired = nil
						votesEligible = nil
						votesCountYes = 0
						votesCountNo = 0
						minimized = false
						StartVote(title)
					end


				elseif voteDlist and not voteEndTime then
					-- > [teh]cluster1[00] * Vote for command "stop" passed.
					-- > [teh]cluster1[01] * Vote for command "forcestart" passed (delay expired, away vote mode activated for ArkanisLupus,ROBOTRONIC,d
					if sfind(line, "* Vote for command", nil, true) then
						voteEndTime = os.clock() + voteEndDelay
						if sfind(line, " passed", nil, true) then
							voteEndText = Spring.I18N('ui.voting.votepassed')
						elseif sfind(line, " failed", nil, true) then
							voteEndText = Spring.I18N('ui.voting.votefailed')
						end
						MinimizeVote()
					end
					-- > [teh]cluster1[01] * Vote cancelled by stown13
					-- > [teh]cluster1[01] * Game starting, cancelling "forceStart" vote
					-- > [teh]cluster2[00] * Cancelling "gKick Raiser" vote (command executed directly by Flaka)
					if sfind(line, "* Vote cancelled", nil, true) or sfind(line, "* Game starting, cancelling ", nil, true) or sfind(line, " vote (command executed directly by ", nil, true) then
						voteEndTime = os.clock() + voteEndDelay
						voteEndText = Spring.I18N('ui.voting.votecancelled')
						MinimizeVote()
					end
					-- > [teh]cluster2[00] * [Z]kynet, you cannot vote currently, there is no vote in progress.
					if sfind(line, ", you cannot vote currently, there is no vote in progress.", nil, true) then
						voteEndTime = os.clock() + (voteEndDelay*0.5)
						voteEndText = "-----"
						MinimizeVote()
					end
				end

				-- > [teh]cluster1[00] * 10 users allowed to vote.
				if voteDlist and sfind(slower(line), " users allowed to vote.", nil, true) then
					local text = ssub(line, sfind(slower(line), "* ", nil, true)+2, sfind(slower(line), " users allowed to vote.", nil, true)-1)
					if text then
						votesEligible = tonumber(text)
					end
				end

				-- > [teh]cluster1[00] * Vote in progress: "stop" [y:1/4, n:1/3] (43s remaining)
				-- > [teh]cluster2[00] * Vote in progress: "resign Raghna TEAM" [y:2/4(3), n:0/2(3)] (57s remaining)
				-- > [teh]cluster2[00] * Vote in progress: "resign [teh]Teddy TEAM" [y:1/1(4), n:0/1(3), votes:1/3] (40s remaining)
				if voteDlist and sfind(slower(line), "vote in progress:", nil, true) then
					local text = ssub(line, sfind(slower(line), "vote in progress:", nil, true)+18)
					text = ssub(text, sfind(text, "\" [", nil, true)+3)
					text = ssub(text, 1,  sfind(text, "]", nil, true)-1)
					-- yes votes
					local str = ssub(text, sfind(text, "y:", nil, true)+2)
					local yesVotes = ssub(str,  1, sfind(str, "/", nil, true)-1)
					local yesVotesNeeded = ssub(str,  sfind(str, "/", nil, true)+1, sfind(str, ",", nil, true)-1)
					if yesVotesNeeded and sfind(yesVotesNeeded, "(", nil, true) then
						yesVotesNeeded = ssub(yesVotesNeeded, 1, sfind(yesVotesNeeded, "(", nil, true)-1)
					end
					-- no votes
					str = ssub(text, sfind(text, "n:", nil, true)+2)
					local noVotes = ssub(str,  1, sfind(str, "/", nil, true)-1)
					local noVotesNeeded = ssub(str,  sfind(str, "/", nil, true)+1)
					if sfind(str, ",", nil, true) then
						noVotesNeeded = ssub(noVotesNeeded,  1, sfind(str, ",", nil, true)-1)
					end
					if noVotesNeeded and sfind(noVotesNeeded, "(", nil, true) then
						noVotesNeeded = ssub(noVotesNeeded, 1, sfind(noVotesNeeded, "(", nil, true)-1)
					end
					if yesVotes and yesVotesNeeded and noVotes and noVotesNeeded then
						yesVotesNeeded = tonumber(yesVotesNeeded)
						noVotesNeeded = tonumber(noVotesNeeded)
						votesCountYes = tonumber(yesVotes)
						votesCountNo = tonumber(noVotes)
						votesRequired = yesVotesNeeded
						if not votesEligible then
							if (yesVotesNeeded + noVotesNeeded) % 2 == 1 then
								votesEligible = yesVotesNeeded + noVotesNeeded - 2
							else
								votesEligible = yesVotesNeeded + noVotesNeeded - 1
							end
						end
						StartVote()
					end
				end
			end
		end
	end
end

function widget:KeyPress(key)
	-- ESC
	if key == 27 and voteDlist and eligibleToVote then
		if not weAreVoteOwner then
			Spring.SendCommands("say !vote b")
		end
		MinimizeVote()
	end
end

function widget:MousePress(x, y, button)
	if voteDlist and eligibleToVote and not voteEndText and button == 1 then
		if math_isInRect(x, y, windowArea[1], windowArea[2], windowArea[3], windowArea[4]) then
			if not weAreVoteOwner and math_isInRect(x, y, yesButtonArea[1], yesButtonArea[2], yesButtonArea[3], yesButtonArea[4]) then
				Spring.SendCommands("say !vote y")
				MinimizeVote()
			elseif math_isInRect(x, y, noButtonArea[1], noButtonArea[2], noButtonArea[3], noButtonArea[4]) then
				if weAreVoteOwner then
					Spring.SendCommands("say !endvote")
					MinimizeVote()
				else
					Spring.SendCommands("say !vote n")
					MinimizeVote()
				end
			elseif math_isInRect(x, y, closeButtonArea[1], closeButtonArea[2], closeButtonArea[3], closeButtonArea[4]) then
				Spring.SendCommands("say !vote b")
				MinimizeVote()
			end
			return true
		end
	end
end

function widget:Shutdown()
	CloseVote()
end

function widget:DrawScreen()
	if voteDlist then
		if not WG['topbar'] or not WG['topbar'].showingQuit() then
			if eligibleToVote then
				local x, y, b = Spring.GetMouseState()
				if hovered then
					StartVote()	-- refresh
				elseif windowArea and math_isInRect(x, y, windowArea[1], windowArea[2], windowArea[3], windowArea[4]) then
					if not weAreVoteOwner and math_isInRect(x, y, yesButtonArea[1], yesButtonArea[2], yesButtonArea[3], yesButtonArea[4]) or
						math_isInRect(x, y, noButtonArea[1], noButtonArea[2], noButtonArea[3], noButtonArea[4]) or
						math_isInRect(x, y, closeButtonArea[1], closeButtonArea[2], closeButtonArea[3], closeButtonArea[4])
					then
						StartVote()	-- refresh
					end
				end
			end
			gl.CallList(voteDlist)
		end
	end
end
