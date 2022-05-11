function widget:GetInfo()
	return {
		name = "Vote interface",
		desc = "",
		author = "Floris",
		date = "July 2018",
		license = "",
		layer = -2000,
		enabled = true,
	}
end

-- dont show vote buttons for specs when containing the following keywords (use lowercase)
local globalVoteWords =  { 'forcestart', 'stop', 'joinas' }

local vsx, vsy = Spring.GetViewGeometry()
local widgetScale = (0.5 + (vsx * vsy / 5700000)) * 1.55

local ui_opacity = tonumber(Spring.GetConfigFloat("ui_opacity", 0.6) or 0.66)
local ui_scale = tonumber(Spring.GetConfigFloat("ui_scale", 1) or 1)

local fontfile2 = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")

local myPlayerID = Spring.GetMyPlayerID()
local myPlayerName, _, mySpec, myTeamID, myAllyTeamID = Spring.GetPlayerInfo(myPlayerID, false)

local math_isInRect = math.isInRect

local RectRound, UiElement, UiButton, bgpadding, elementCorner, widgetSpaceMargin
local voteDlist, chobbyInterface, font, font2, gameStarted, dlistGuishader
local weAreVoteOwner, hovered, voteName, windowArea, closeButtonArea, yesButtonArea, noButtonArea
local uiOpacitySec = 0
local eligibleToVote = false

local eligiblePlayers = {}
local votesRequired, votesEligible
local votesCountYes = 0
local votesCountNo = 0
local votesCountB = 0
local minimized = false

local function isTeamPlayer(playerName)
	local players = Spring.GetPlayerList()
	for _, pID in ipairs(players) do
		local name, _, spec, teamID, allyTeamID = Spring.GetPlayerInfo(pID, false)
		if name == playerName then
			if allyTeamID == myAllyTeamID then
				return true
			end
		end
	end
	return false
end

local function StartVote(name)	-- when called without params its just to refresh (when hovering over buttons)
	if voteDlist then
		gl.DeleteList(voteDlist)
	end
	voteDlist = gl.CreateList(function()
		if name then
			voteName = name
		end

		local color1, color2, w
		local x, y, b = Spring.GetMouseState()

		local width = math.floor((vsy / 6) * ui_scale) * 2	-- *2 so it ensures number can be divided cleanly by 2
		local height = math.floor((vsy / 23) * ui_scale) * 2		-- *2 so it ensures number can be divided cleanly by 2

		local progressbarHeight = math.ceil(height * 0.05)

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

		UiElement(windowArea[1], windowArea[2], windowArea[3], windowArea[4], 1,1,1,1, 1,1,1,1, Spring.GetConfigFloat("ui_opacity", 0.6) + 0.2)

		-- progress bar
		if votesEligible then
			-- progress bar: required for
			if votesRequired then
				w = math.floor(((windowArea[3] - windowArea[1]) / votesEligible) * votesRequired)
				color1 = { 0, 0.6, 0, 0.08 }
				color2 = { 0, 1, 0, 0.08 }
				RectRound(windowArea[1] + bgpadding, windowArea[2] + bgpadding, windowArea[1] + bgpadding + w, windowArea[2] + bgpadding + progressbarHeight, elementCorner*0.6, 0, 0, 0, 1, color1, color2)
				-- progress bar: required minority against
				color1 = { 0.6, 0, 0, 0.08 }
				color2 = { 1, 0, 0, 0.08 }
				RectRound(windowArea[1] + bgpadding + w, windowArea[2] + bgpadding, windowArea[3] - bgpadding, windowArea[2] + bgpadding + progressbarHeight, elementCorner*0.6, 0, 0, 1, 0, color1, color2)
			end

			-- progress bar: for
			if votesCountYes > 0 then
				w = math.floor(((windowArea[3] - windowArea[1]) / votesEligible) * votesCountYes)
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
				w = math.floor(((windowArea[3] - windowArea[1]) / votesEligible) * votesCountNo)
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
			color2 = { 1, 1, 1, 0.08 }
			RectRound(windowArea[1] + bgpadding, windowArea[2] + bgpadding + (progressbarHeight/2), windowArea[3] - bgpadding, windowArea[2] + bgpadding + progressbarHeight, 0, 0, 0, 0, 0, color1, color2)
			color1 = { 1, 1, 1, 0.02 }
			color2 = { 1, 1, 1, 0 }
			RectRound(windowArea[1] + bgpadding, windowArea[2] + bgpadding, windowArea[3] - bgpadding, windowArea[2] + bgpadding + (progressbarHeight/2), 0, 0, 0, 0, 0, color1, color2)
		end

		fontSize = fontSize * 0.85
		gl.Color(0, 0, 0, 1)

		-- vote name
		font:Begin()
		font:Print("\255\190\190\190" .. voteName, windowArea[1] + ((windowArea[3] - windowArea[1]) / 2), windowArea[4] - bgpadding - bgpadding - bgpadding - fontSize, fontSize, "con")
		font:End()

		if eligibleToVote and not minimized  then

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
			font2:Print("\255\0\0\0" .. Spring.I18N('ui.voting.cancel'), closeButtonArea[1] + ((closeButtonArea[3] - closeButtonArea[1]) / 2), closeButtonArea[2] + ((closeButtonArea[4] - closeButtonArea[2]) / 2) - (fontSize / 3), fontSize, "cn")

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

local function CloseVote()
	if voteDlist then
		eligiblePlayers = {}
		votesRequired = nil
		votesEligible = nil
		votesCountYes = 0
		votesCountNo = 0
		votesCountB = 0
		minimized = false
		gl.DeleteList(voteDlist)
		voteDlist = nil
		voteName = nil
		weAreVoteOwner = nil
		eligibleToVote = false
		if WG['guishader'] then
			WG['guishader'].DeleteDlist('voteinterface')
		end
	end
end

function widget:ViewResize()
	vsx, vsy = Spring.GetViewGeometry()
	widgetScale = (0.5 + (vsx * vsy / 5700000)) * 1.55

	widgetSpaceMargin = WG.FlowUI.elementMargin
	bgpadding = WG.FlowUI.elementPadding
	elementCorner = WG.FlowUI.elementCorner

	RectRound = WG.FlowUI.Draw.RectRound
	UiElement = WG.FlowUI.Draw.Element
	UiButton = WG.FlowUI.Draw.Button

	font = WG['fonts'].getFont()
	font2 = WG['fonts'].getFont(fontfile2)
end

function widget:PlayerChanged(playerID)
	mySpec = Spring.GetSpectatingState()
	myPlayerName, _, mySpec, myTeamID, myAllyTeamID = Spring.GetPlayerInfo(myPlayerID, false)
end

local debug = false
local sec = 0
function widget:Update(dt)
	-- Uncomment for testing
	if debug then
		sec = sec + dt
		if sec > 1 and not voteDlist then
			votesEligible = 8
			votesRequired = 5
			votesCountYes = 2
			votesCountNo = 1
			votesCountB = 0
			minimized = false
			eligibleToVote = true
			StartVote('forcestart')
		end
	end

	uiOpacitySec = uiOpacitySec + dt
	if uiOpacitySec > 0.5 then
		uiOpacitySec = 0
		if ui_opacity ~= Spring.GetConfigFloat("ui_opacity", 0.6) then
			ui_opacity = Spring.GetConfigFloat("ui_opacity", 0.6)
			widget:ViewResize()
		end
		if ui_scale ~= Spring.GetConfigFloat("ui_scale", 1) then
			ui_scale = Spring.GetConfigFloat("ui_scale", 1)
			widget:ViewResize()
		end
	end
end

function widget:Initialize()
	widget:ViewResize()
	if Spring.IsReplay() then
		widgetHandler:RemoveWidget()
	end
end

function widget:GameFrame(n)
	if n > 0 and not gameStarted then
		gameStarted = true
		myPlayerID = Spring.GetMyPlayerID()
		myPlayerName, _, mySpec, myTeamID, myAllyTeamID = Spring.GetPlayerInfo(myPlayerID, false)
	end
end

function widget:AddConsoleLine(lines, priority)

	if not WG['topbar'] or not WG['topbar'].showingRejoining() then

		lines = lines:match('^\[f=[0-9]+\] (.*)$') or lines
		for line in lines:gmatch("[^\n]+") do

			-- system message
			if string.sub(line, 1, 1) == ">" and string.sub(line, 3, 3) ~= "<" then

				-- vote called
				if string.find(line, " called a vote ", nil, true) then

					-- find who started the vote, and see if we're allied
					local ownerPlayername = false
					local alliedWithVoteOwner = false
					local players = Spring.GetPlayerList()
					for _, playerID in ipairs(players) do
						local playerName, _, spec, teamID, allyTeamID = Spring.GetPlayerInfo(playerID, false)
						if string.find(line, string.gsub(playerName, "%p", "%%%1") .. " called a vote ", nil, true) then
							ownerPlayername = playerName
							if allyTeamID == myAllyTeamID then
								alliedWithVoteOwner = true
							end
							break
						end
					end
					weAreVoteOwner = (ownerPlayername == myPlayerName)
					--Spring.Echo('--====--  vote owner:'..(ownerPlayername and ownerPlayername or '')..'   allied = '..(alliedWithVoteOwner and 'yes' or 'no'))

					local title = string.sub(line, string.find(line, ' "') + 2, string.find(line, '" ', nil, true) - 1) .. '?'
					title = title:sub(1, 1):upper() .. title:sub(2)

					eligibleToVote = alliedWithVoteOwner
					if not eligibleToVote then
						for _, keyword in pairs(globalVoteWords) do
							if string.find(string.lower(title), keyword, nil, true) then
								eligibleToVote = true
								break
							end
						end
					end
					if mySpec then
						eligibleToVote = false
					end

					if not string.find(line, '"resign ', nil, true) or isTeamPlayer(string.sub(line, string.find(line, '"resign ', nil, true) + 8, string.find(line, ' TEAM', nil, true) - 1)) then
						eligiblePlayers = {}
						votesRequired = nil
						votesEligible = nil
						votesCountYes = 0
						votesCountNo = 0
						votesCountB = 0
						minimized = false
						StartVote(title)
					end
				elseif voteDlist and (string.find(string.lower(line), " passed.", nil, true) or string.find(string.lower(line), " failed", nil, true) or string.find(string.lower(line), "vote cancelled", nil, true) or string.find(string.lower(line), ' cancelling "', nil, true)) then
					CloseVote()
				end

			else	-- non system message

				-- command
				if voteDlist and string.find(string.lower(line), " !", nil, true) then

					local playerName = string.sub(line,2,(string.find(line,"> ", nil, true) or 1)-1)

					--Spring.Echo('a vote by   '..playerName)
					if eligiblePlayers[playerName] ~= nil then
						local voted = false
						if string.find(string.lower(line), " !vote y", nil, true) or string.find(string.lower(line), " !y", nil, true) then
							eligiblePlayers[playerName] = 'y'
							voted = true
						elseif string.find(string.lower(line), " !vote n", nil, true) or string.find(string.lower(line), " !n", nil, true) then
							eligiblePlayers[playerName] = 'n'
							voted = true
						elseif string.find(string.lower(line), " !vote b", nil, true) or string.find(string.lower(line), " !b", nil, true) then
							eligiblePlayers[playerName] = 'b'
							voted = true
						end
						if voted then
							votesCountYes, votesCountNo, votesCountB = 0, 0, 0
							for k,v in pairs(eligiblePlayers) do
								if v == 'y' then
									votesCountYes = votesCountYes + 1
								elseif v == 'n' then
									votesCountNo = votesCountNo + 1
								else
									votesCountB = votesCountB + 1
								end
							end
						end
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
	if voteDlist and eligibleToVote and button == 1 then
		if math_isInRect(x, y, windowArea[1], windowArea[2], windowArea[3], windowArea[4]) then
			if not weAreVoteOwner and math_isInRect(x, y, yesButtonArea[1], yesButtonArea[2], yesButtonArea[3], yesButtonArea[4]) then
				Spring.SendCommands("say !vote y")
				MinimizeVote()
			elseif math_isInRect(x, y, noButtonArea[1], noButtonArea[2], noButtonArea[3], noButtonArea[4]) then
				if weAreVoteOwner then
					Spring.SendCommands("say !endvote")
					CloseVote()
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

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1, 19) == 'LobbyOverlayActive1')
	end
end

function widget:DrawScreen()
	if chobbyInterface then
		return
	end
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
