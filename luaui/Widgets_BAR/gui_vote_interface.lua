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

local texts = {        -- fallback (if you want to change this, also update: language/en.lua, or it will be overwritten)
	no = 'NO',
	yes = 'YES',
	endvote = 'End Vote',
	esc = 'ESC',
}

-- dont show vote interface for specs for the following keywords (use lowercase)
local specBadKeywords = { 'forcestart', 'stop' }

local vsx, vsy = Spring.GetViewGeometry()
local widgetScale = (0.5 + (vsx * vsy / 5700000)) * 1.55

local ui_opacity = tonumber(Spring.GetConfigFloat("ui_opacity", 0.6) or 0.66)
local ui_scale = tonumber(Spring.GetConfigFloat("ui_scale", 1) or 1)
local glossMult = 1 + (2 - (ui_opacity * 2))    -- increase gloss/highlight so when ui is transparant, you can still make out its boundaries and make it less flat

local widgetSpaceMargin = math.floor((0.0045 * (vsy / vsx)) * vsx * ui_scale)
local bgpadding = math.ceil(widgetSpaceMargin * 0.66)

local fontfile2 = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")

-- being set at gamestart again:
local myPlayerID = Spring.GetMyPlayerID()
local myName, _, mySpec, myTeamID, myAllyTeamID = Spring.GetPlayerInfo(myPlayerID, false)
local startedAsPlayer = not mycSpec

local glBlending = gl.Blending
local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_ONE = GL.ONE

local voteDlist, chobbyInterface, font, font2, gameStarted, height, dlistGuishader
local voteOwner, hovered, voteName, windowArea, closeButtonArea, yesButtonArea, noButtonArea


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

function IsOnRect(x, y, BLcornerX, BLcornerY, TRcornerX, TRcornerY)
	return x >= BLcornerX and x <= TRcornerX and y >= BLcornerY and y <= TRcornerY
end

function widget:ViewResize()
	vsx, vsy = Spring.GetViewGeometry()
	widgetScale = (0.5 + (vsx * vsy / 5700000)) * 1.55

	widgetSpaceMargin = math.floor((0.0045 * (vsy / vsx)) * vsx * ui_scale)
	bgpadding = math.ceil(widgetSpaceMargin * 0.66)

	font, loadedFontSize = WG['fonts'].getFont()
	font2 = WG['fonts'].getFont(fontfile2)
end

function widget:PlayerChanged(playerID)
	mySpec = Spring.GetSpectatingState()
end

--local sec = 0
local uiOpacitySec = 0
function widget:Update(dt)
	--myName,_,mySpec,myTeamID,myAllyTeamID = Spring.GetPlayerInfo(1,false)
	--sec = sec + dt
	--if sec > 2 and not voteDlist then
	--	StartVote('testvote yeah!', 'somebody')
	--end

	uiOpacitySec = uiOpacitySec + dt
	if uiOpacitySec > 0.5 then
		uiOpacitySec = 0
		if ui_opacity ~= Spring.GetConfigFloat("ui_opacity", 0.6) then
			ui_opacity = Spring.GetConfigFloat("ui_opacity", 0.6)
			glossMult = 1 + (2.5 - (ui_opacity * 2.5))
		end
		if ui_scale ~= Spring.GetConfigFloat("ui_scale", 1) then
			ui_scale = Spring.GetConfigFloat("ui_scale", 1)
			height = orgHeight * (1 + (ui_scale - 1) / 1.7)
			widget:ViewResize()
		end
	end
end

function widget:Initialize()
	if WG['lang'] then
		texts = WG['lang'].getText('voteinterface')
	end
	widget:ViewResize()
	if Spring.IsReplay() then
		widgetHandler:RemoveWidget(self)
	end
end

function widget:GameFrame(n)
	if n > 0 and not gameStarted then
		gameStarted = true
		myPlayerID = Spring.GetMyPlayerID()
		myName, _, mySpec, myTeamID, myAllyTeamID = Spring.GetPlayerInfo(myPlayerID, false)
		startedAsPlayer = not mySpec
	end
end

function isTeamPlayer(playerName)
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

function widget:AddConsoleLine(lines, priority)
	if startedAsPlayer and (not WG['topbar'] or (WG['topbar'] and WG['topbar'].showingRejoining and not WG['topbar'].showingRejoining())) then
		lines = lines:match('^\[f=[0-9]+\] (.*)$') or lines
		for line in lines:gmatch("[^\n]+") do
			if string.sub(line, 1, 1) == ">" and string.sub(line, 3, 3) ~= "<" then
				-- system message
				if string.find(line, " called a vote ", nil, true) then
					-- vote called
					local title = string.sub(line, string.find(line, ' "') + 2, string.find(line, '" ', nil, true) - 1) .. '?'
					title = title:sub(1, 1):upper() .. title:sub(2)
					if not string.find(line, '"resign ', nil, true) or isTeamPlayer(string.sub(line, string.find(line, '"resign ', nil, true) + 8, string.find(line, ' TEAM', nil, true) - 1)) then
						StartVote(title, string.find(line, string.gsub(myName, "%p", "%%%1") .. " called a vote ", nil, true))
					end
				elseif voteDlist and (string.find(string.lower(line), " passed.", nil, true) or string.find(string.lower(line), " failed", nil, true) or string.find(string.lower(line), "Vote cancelled", nil, true) or string.find(string.lower(line), ' cancelling "', nil, true)) then
					EndVote()
				end
			end
		end
	end
end

function EndVote()
	if voteDlist then
		gl.DeleteList(voteDlist)
		voteDlist = nil
		voteName = nil
		voteOwner = nil
		if WG['guishader'] then
			WG['guishader'].DeleteDlist('voteinterface')
		end
	end
end

function StartVote(name, owner)
	local show = true
	if mySpec and name then
		for k, keyword in pairs(specBadKeywords) do
			if string.find(string.lower(name), keyword, nil, true) then
				show = false
				break
			end
		end
	end
	if show then
		if voteDlist then
			gl.DeleteList(voteDlist)
		end
		if owner then
			voteOwner = owner
		end
		voteDlist = gl.CreateList(function()
			if name then
				voteName = name
			end

			local x, y, b = Spring.GetMouseState()

			local width = math.floor((vsy / 6) * ui_scale) * 2	-- *2 so it ensures number can be divided cleanly by 2
			local height = math.floor((vsy / 24) * ui_scale) * 2		-- *2 so it ensures number can be divided cleanly by 2

			local fontSize = height / 5    -- title only
			local minWidth = font:GetTextWidth('  ' .. voteName .. '  ') * fontSize
			if width < minWidth then
				width = minWidth
			end

			local buttonMargin = math.floor(width / 32)
			local buttonHeight = math.floor(height * 0.55)

			local xpos = math.floor(width / 2)
			local ypos = math.floor(vsy - (height / 2))

			if WG['topbar'] ~= nil then
				local topbarArea = WG['topbar'].GetPosition()
				--xpos = vsx-(width/2)
				xpos = math.floor(topbarArea[1] + (width / 2) + widgetSpaceMargin)
				ypos = math.floor(topbarArea[2] - (5 * topbarArea[5]) - (height / 2))
			end

			hovered = nil

			windowArea = { xpos - (width / 2), ypos - (height / 2), xpos + (width / 2), ypos + (height / 2) }
			closeButtonArea = { (xpos + (width / 2)) - (height / 2), ypos + math.floor(height / 6), xpos + (width / 2), ypos + (height / 2)}
			yesButtonArea = { xpos - (width / 2) + buttonMargin, ypos - (height / 2) + buttonMargin, xpos - (buttonMargin / 2), ypos - (height / 2) + buttonHeight - buttonMargin }
			noButtonArea = { xpos + (buttonMargin / 2), ypos - (height / 2) + buttonMargin, xpos + (width / 2) - buttonMargin, ypos - (height / 2) + buttonHeight - buttonMargin }

			-- window
			RectRound(windowArea[1], windowArea[2], windowArea[3], windowArea[4], bgpadding * 1.6, 1, 1, 1, 1, { 0.05, 0.05, 0.05, WG['guishader'] and 0.8 or 0.88 }, { 0, 0, 0, WG['guishader'] and 0.8 or 0.88 })
			RectRound(windowArea[1] + bgpadding, windowArea[2] + bgpadding, windowArea[3] - bgpadding, windowArea[4] - bgpadding, bgpadding * 1.25, 1, 1, 1, 1, { 0.25, 0.25, 0.25, 0.2 }, { 0.5, 0.5, 0.5, 0.2 })

			-- gloss
			glBlending(GL_SRC_ALPHA, GL_ONE)
			RectRound(windowArea[1] + bgpadding, windowArea[2] + bgpadding, windowArea[3] - bgpadding, windowArea[4] - bgpadding, bgpadding * 1.25, 0, 0, 0, 0, { 1, 1, 1, 0.006 * glossMult }, { 1, 1, 1, 0.055 * glossMult })
			glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

			-- close
			--gl.Color(0.1,0.1,0.1,0.55+(0.36))
			--RectRound(closeButtonArea[1], closeButtonArea[2], closeButtonArea[3], closeButtonArea[4], 3.5*widgetScale)
			local color1, color2
			if IsOnRect(x, y, closeButtonArea[1], closeButtonArea[2], closeButtonArea[3], closeButtonArea[4]) then
				hovered = 'esc'
				--gl.Color(1,1,1,0.55)
				color1 = { 0.6, 0.6, 0.6, 0.6 }
				color2 = { 1, 1, 1, 0.6 }
			else
				--gl.Color(1,1,1,0.027)
				color1 = { 0.6, 0.6, 0.6, 0.08 }
				color2 = { 1, 1, 1, 0.08 }
			end
			RectRound(closeButtonArea[1] + bgpadding, closeButtonArea[2] + bgpadding, closeButtonArea[3] - bgpadding, closeButtonArea[4] - bgpadding, bgpadding * 1.25, 0, 1, 0, 1, color1, color2)

			fontSize = fontSize * 0.85
			gl.Color(0, 0, 0, 1)

			-- vote name
			font:Begin()
			font:Print("\255\190\190\190" .. voteName, windowArea[1] + ((windowArea[3] - windowArea[1]) / 2), windowArea[4] - bgpadding - bgpadding - bgpadding - fontSize, fontSize, "con")
			font:End()

			font2:Begin()
			-- ESC
			font2:Print("\255\0\0\0"..texts.esc, closeButtonArea[1] + ((closeButtonArea[3] - closeButtonArea[1]) / 2), closeButtonArea[2] + ((closeButtonArea[4] - closeButtonArea[2]) / 2) - (fontSize / 3), fontSize, "cn")

			-- NO
			local color1, color2, mult
			if IsOnRect(x, y, noButtonArea[1], noButtonArea[2], noButtonArea[3], noButtonArea[4]) then
				hovered = 'n'
				--gl.Color(0.7,0.1,0.1,0.8)
				color1 = { 0.5, 0.07, 0.07, 0.8 }
				color2 = { 0.7, 0.1, 0.1, 0.8 }
				mult = 1.15
			else
				--gl.Color(0.5,0,0,0.7)
				color1 = { 0.4, 0, 0, 0.75 }
				color2 = { 0.5, 0, 0, 0.75 }
				mult = 1
			end
			RectRound(noButtonArea[1], noButtonArea[2], noButtonArea[3], noButtonArea[4], bgpadding * 0.7, 1, 1, 1, 1, color1, color2)

			-- gloss
			glBlending(GL_SRC_ALPHA, GL_ONE)
			RectRound(noButtonArea[1], noButtonArea[4] - ((noButtonArea[4] - noButtonArea[2]) * 0.5), noButtonArea[3], noButtonArea[4], bgpadding * 0.7, 2, 2, 0, 0, { 1, 1, 1, 0.035 * mult }, { 1, 1, 1, 0.2 * mult })
			RectRound(noButtonArea[1], noButtonArea[2], noButtonArea[3], noButtonArea[2] + ((noButtonArea[4] - noButtonArea[2]) * 0.35), bgpadding * 0.7, 0, 0, 2, 2, { 1, 1, 1, 0.11 * mult }, { 1, 1, 1, 0 })
			glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

			fontSize = fontSize * 0.85
			local noText = texts.no
			if voteOwner then
				noText = texts.endvote
			end
			font2:SetOutlineColor(0, 0, 0, 0.4)
			font2:Print(noText, noButtonArea[1] + ((noButtonArea[3] - noButtonArea[1]) / 2), noButtonArea[2] + ((noButtonArea[4] - noButtonArea[2]) / 2) - (fontSize / 3), fontSize, "con")

			-- YES
			if not voteOwner then
				if IsOnRect(x, y, yesButtonArea[1], yesButtonArea[2], yesButtonArea[3], yesButtonArea[4]) then
					hovered = 'y'
					--gl.Color(0.05,0.6,0.05,0.8)
					color1 = { 0.035, 0.4, 0.035, 0.8 }
					color2 = { 0.05, 0.6, 0.5, 0.8 }
					mult = 1.15
				else
					--gl.Color(0,0.5,0,0.35)
					color1 = { 0, 0.4, 0, 0.38 }
					color2 = { 0, 0.5, 0, 0.38 }
					mult = 1
				end
				RectRound(yesButtonArea[1], yesButtonArea[2], yesButtonArea[3], yesButtonArea[4], bgpadding * 0.7, 1, 1, 1, 1, color1, color2)

				-- gloss
				glBlending(GL_SRC_ALPHA, GL_ONE)
				RectRound(yesButtonArea[1], yesButtonArea[4] - ((yesButtonArea[4] - yesButtonArea[2]) * 0.5), yesButtonArea[3], yesButtonArea[4], bgpadding * 0.7, 2, 2, 0, 0, { 1, 1, 1, 0.035 * mult }, { 1, 1, 1, 0.2 * mult })
				RectRound(yesButtonArea[1], yesButtonArea[2], yesButtonArea[3], yesButtonArea[2] + ((yesButtonArea[4] - yesButtonArea[2]) * 0.35), bgpadding * 0.7, 0, 0, 2, 2, { 1, 1, 1, 0.11 * mult }, { 1, 1, 1, 0 })
				glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

				font2:Print(texts.yes, yesButtonArea[1] + ((yesButtonArea[3] - yesButtonArea[1]) / 2), yesButtonArea[2] + ((yesButtonArea[4] - yesButtonArea[2]) / 2) - (fontSize / 3), fontSize, "con")
			end
			font2:End()
		end)
		-- background blur
		if WG['guishader'] then
			dlistGuishader = gl.CreateList(function()
				RectRound(windowArea[1], windowArea[2], windowArea[3], windowArea[4], bgpadding * 1.6)
			end)
			WG['guishader'].InsertDlist(dlistGuishader, 'voteinterface')
		end
	end
end

function widget:KeyPress(key)
	if key == 27 and voteDlist then
		-- ESC
		if not voteOwner then
			Spring.SendCommands("say !vote b")
		end
		EndVote()
	end
end

function widget:MousePress(x, y, button)
	if voteDlist and button == 1 then
		if IsOnRect(x, y, windowArea[1], windowArea[2], windowArea[3], windowArea[4]) then
			if not voteOwner and IsOnRect(x, y, yesButtonArea[1], yesButtonArea[2], yesButtonArea[3], yesButtonArea[4]) then
				Spring.SendCommands("say !vote y")
				EndVote()
			elseif IsOnRect(x, y, noButtonArea[1], noButtonArea[2], noButtonArea[3], noButtonArea[4]) then
				if voteOwner then
					Spring.SendCommands("say !endvote")
				else
					Spring.SendCommands("say !vote n")
				end
				EndVote()
			elseif IsOnRect(x, y, closeButtonArea[1], closeButtonArea[2], closeButtonArea[3], closeButtonArea[4]) then
				Spring.SendCommands("say !vote b")
				EndVote()
			end
			return true
		end
	end
end

function widget:Shutdown()
	EndVote()
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
			local x, y, b = Spring.GetMouseState()
			if windowArea and IsOnRect(x, y, windowArea[1], windowArea[2], windowArea[3], windowArea[4]) then
				if not voteOwner and IsOnRect(x, y, yesButtonArea[1], yesButtonArea[2], yesButtonArea[3], yesButtonArea[4]) or
					IsOnRect(x, y, noButtonArea[1], noButtonArea[2], noButtonArea[3], noButtonArea[4]) or
					IsOnRect(x, y, closeButtonArea[1], closeButtonArea[2], closeButtonArea[3], closeButtonArea[4])
				then
					StartVote()
				elseif hovered then
					StartVote()
				end
			elseif hovered then
				StartVote()
			end
		end
		gl.CallList(voteDlist)
	end
end
