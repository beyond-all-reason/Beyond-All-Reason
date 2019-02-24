function widget:GetInfo()
	return {
		name      = "Vote interface",
		desc      = "",
		author    = "Floris",
		date      = "July 2018",
		license   = "",
		layer     = -2000,
		enabled   = true,
	}
end

local vsx, vsy = gl.GetViewSizes()
local customScale = 1.5
local widgetScale = (0.5 + (vsx*vsy / 5700000)) * customScale

local bgcorner = "LuaUI/Images/bgcorner.png"

-- being set at gamestart again:
local myPlayerID = Spring.GetMyPlayerID()
local myName,_,mySpec,myTeamID,myAllyTeamID = Spring.GetPlayerInfo(myPlayerID)
local startedAsPlayer = not mySpec

local function DrawRectRound(px,py,sx,sy,cs)

	local csx = cs
	local csy = cs
	if sx-px < (cs*2) then
		csx = (sx-px)/2
		if csx < 0 then csx = 0 end
	end
	if sy-py < (cs*2) then
		csy = (sy-py)/2
		if csy < 0 then csy = 0 end
	end
	cs = math.min(csx, csy)

	gl.TexCoord(0.8,0.8)
	gl.Vertex(px+cs, py, 0)
	gl.Vertex(sx-cs, py, 0)
	gl.Vertex(sx-cs, sy, 0)
	gl.Vertex(px+cs, sy, 0)

	gl.Vertex(px, py+cs, 0)
	gl.Vertex(px+cs, py+cs, 0)
	gl.Vertex(px+cs, sy-cs, 0)
	gl.Vertex(px, sy-cs, 0)

	gl.Vertex(sx, py+cs, 0)
	gl.Vertex(sx-cs, py+cs, 0)
	gl.Vertex(sx-cs, sy-cs, 0)
	gl.Vertex(sx, sy-cs, 0)

	local offset = 0.05		-- texture offset, because else gaps could show
	local o = offset

	-- top left
	if py <= 0 or px <= 0 then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(px, py, 0)
	gl.TexCoord(o,1-offset)
	gl.Vertex(px+cs, py, 0)
	gl.TexCoord(1-offset,1-offset)
	gl.Vertex(px+cs, py+cs, 0)
	gl.TexCoord(1-offset,o)
	gl.Vertex(px, py+cs, 0)
	-- top right
	if py <= 0 or sx >= vsx then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(sx, py, 0)
	gl.TexCoord(o,1-offset)
	gl.Vertex(sx-cs, py, 0)
	gl.TexCoord(1-offset,1-offset)
	gl.Vertex(sx-cs, py+cs, 0)
	gl.TexCoord(1-offset,o)
	gl.Vertex(sx, py+cs, 0)
	-- bottom left
	if sy >= vsy or px <= 0 then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(px, sy, 0)
	gl.TexCoord(o,1-offset)
	gl.Vertex(px+cs, sy, 0)
	gl.TexCoord(1-offset,1-offset)
	gl.Vertex(px+cs, sy-cs, 0)
	gl.TexCoord(1-offset,o)
	gl.Vertex(px, sy-cs, 0)
	-- bottom right
	if sy >= vsy or sx >= vsx then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(sx, sy, 0)
	gl.TexCoord(o,1-offset)
	gl.Vertex(sx-cs, sy, 0)
	gl.TexCoord(1-offset,1-offset)
	gl.Vertex(sx-cs, sy-cs, 0)
	gl.TexCoord(1-offset,o)
	gl.Vertex(sx, sy-cs, 0)
end

function RectRound(px,py,sx,sy,cs)
	local px,py,sx,sy,cs = math.floor(px),math.floor(py),math.ceil(sx),math.ceil(sy),math.floor(cs)

	gl.Texture(bgcorner)
	gl.BeginEnd(GL.QUADS, DrawRectRound, px,py,sx,sy,cs)
	gl.Texture(false)
end

function IsOnRect(x, y, BLcornerX, BLcornerY,TRcornerX,TRcornerY)
	return x >= BLcornerX and x <= TRcornerX and y >= BLcornerY and y <= TRcornerY
end

function widget:ViewResize()
	vsx,vsy = Spring.GetViewGeometry()
	widgetScale = (0.5 + (vsx*vsy / 5700000)) * customScale
end

function widget:PlayerChanged(playerID)
	mySpec = Spring.GetSpectatingState()
end

--local sec = 0
--function widget:Update(dt)
--	myName,_,mySpec,myTeamID,myAllyTeamID = Spring.GetPlayerInfo(1)
--	sec = sec + dt
--	if sec > 2 and not voteDlist then
--		StartVote('testvote yeah!', 'somebody')
--	end
--end

function widget:Initialize()
	if Spring.IsReplay() then
		widgetHandler:RemoveWidget(self)
	end
end

function widget:GameFrame(n)
	if n > 0 and not gameStarted then
		gameStarted = true
		myPlayerID = Spring.GetMyPlayerID()
		myName,_,mySpec,myTeamID,myAllyTeamID = Spring.GetPlayerInfo(myPlayerID)
		startedAsPlayer = not mySpec
	end
end

function isTeamPlayer(playerName)
	local players = Spring.GetPlayerList()
	for _,pID in ipairs(players) do
		local name,_,spec,teamID,allyTeamID = Spring.GetPlayerInfo(pID)
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
			if (string.sub(line,1,1) == ">" and string.sub(line,3,3) ~= "<") then	-- system message
				if string.find(line," called a vote ") then	-- vote called
					local title = string.sub(line,string.find(line,' "')+2, string.find(line,'" ')-1)..'?'
					title = title:sub(1,1):upper()..title:sub(2)
					if not string.find(line,"\"resign ") or isTeamPlayer(string.sub(line,string.find(line,'"resign ')+8, string.find(line,' TEAM')-1)) then
						StartVote(title, string.find(line, string.gsub(myName, "%p", "%%%1").." called a vote "))
					end
				elseif voteDlist and (string.find(line," passed.") or string.find(line," failed") or string.find(line,"Vote cancelled") or  string.find(line," cancelling \"")) then
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
		if (WG['guishader_api'] ~= nil) then
			WG['guishader_api'].RemoveRect('voteinterface')
		end
	end
end

function StartVote(name, owner)
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

		local x,y,b = Spring.GetMouseState()

		local width = vsx/6.2
		local height = vsy/13

		local fontSize = height/5	-- title only
		local minWidth = gl.GetTextWidth('  '..voteName..'  ')*fontSize
		if width < minWidth then
			width = minWidth
		end

		local padding = width/70
		local buttonPadding = width/100
		local buttonMargin = width/32
		local buttonHeight = height*0.55

		local xpos = width/2
		local ypos = vsy-(height/2)

		if WG['topbar'] ~= nil then
			local topbarArea = WG['topbar'].GetPosition()
			--xpos = vsx-(width/2)
			xpos = topbarArea[1] + (width/2) + ((vsx-topbarArea[1])/1.95)
			ypos = topbarArea[6]-(5*topbarArea[5])-(height/2)
		end

		hovered = nil

		windowArea = {xpos-(width/2), ypos-(height/2), xpos+(width/2), ypos+(height/2) }
		closeButtonArea = {(xpos+(width/2))-(height/1.9), ypos+(height/5.5), xpos+(width/2), ypos+(height/2) }
		yesButtonArea = {xpos-(width/2)+buttonMargin, ypos-(height/2)+buttonMargin, xpos-(buttonMargin/2), ypos-(height/2)+buttonHeight-buttonMargin }
		noButtonArea = {xpos+(buttonMargin/2), ypos-(height/2)+buttonMargin, xpos+(width/2)-buttonMargin, ypos-(height/2)+buttonHeight-buttonMargin}

		-- background blur
		if (WG['guishader_api'] ~= nil) then
			WG['guishader_api'].InsertRect(windowArea[1],windowArea[2],windowArea[3],windowArea[4], 'voteinterface')
		end

		-- window
		gl.Color(0,0,0,0.82)
		RectRound(windowArea[1], windowArea[2], windowArea[3], windowArea[4], 5.5*widgetScale)
		gl.Color(1,1,1,0.05)
		RectRound(windowArea[1]+padding, windowArea[2]+padding, windowArea[3]-padding, windowArea[4]-padding, 5*widgetScale)

		-- close
		--gl.Color(0.1,0.1,0.1,0.55+(0.36))
		--RectRound(closeButtonArea[1], closeButtonArea[2], closeButtonArea[3], closeButtonArea[4], 3.5*widgetScale)
		if IsOnRect(x, y, closeButtonArea[1], closeButtonArea[2], closeButtonArea[3], closeButtonArea[4]) then
			hovered = 'esc'
			gl.Color(1,1,1,0.55)
		else
			gl.Color(1,1,1,0.027)
		end
		RectRound(closeButtonArea[1]+padding, closeButtonArea[2]+padding, closeButtonArea[3]-padding, closeButtonArea[4]-padding, 3*widgetScale)

		fontSize = fontSize*0.85
		gl.Color(0,0,0,1)
		gl.Text("ESC", closeButtonArea[1]+((closeButtonArea[3]-closeButtonArea[1])/2), closeButtonArea[2]+((closeButtonArea[4]-closeButtonArea[2])/2)-(fontSize/3), fontSize, "cn")

		-- vote name
		gl.Text("\255\190\190\190"..voteName, windowArea[1]+((windowArea[3]-windowArea[1])/2), windowArea[4]-padding-padding-padding-fontSize, fontSize, "con")

		-- NO
		if IsOnRect(x, y, noButtonArea[1], noButtonArea[2], noButtonArea[3], noButtonArea[4]) then
			hovered = 'n'
			gl.Color(0.7,0.1,0.1,0.8)
		else
			gl.Color(0.5,0,0,0.7)
		end
		RectRound(noButtonArea[1], noButtonArea[2], noButtonArea[3], noButtonArea[4], 5*widgetScale)
		gl.Color(0,0,0,0.075)
		RectRound(noButtonArea[1]+buttonPadding, noButtonArea[2]+buttonPadding, noButtonArea[3]-buttonPadding, noButtonArea[4]-buttonPadding, 4*widgetScale)

		fontSize = fontSize*0.85
		local noText = 'NO'
		if voteOwner then
			noText = 'End Vote'
		end
		gl.Text("\255\255\255\255"..noText, noButtonArea[1]+((noButtonArea[3]-noButtonArea[1])/2), noButtonArea[2]+((noButtonArea[4]-noButtonArea[2])/2)-(fontSize/3), fontSize, "con")

		-- YES
		if not voteOwner then
			if IsOnRect(x, y, yesButtonArea[1], yesButtonArea[2], yesButtonArea[3], yesButtonArea[4]) then
				hovered = 'y'
				gl.Color(0.05,0.6,0.05,0.8)
			else
				gl.Color(0,0.5,0,0.35)
			end
			RectRound(yesButtonArea[1], yesButtonArea[2], yesButtonArea[3], yesButtonArea[4], 5*widgetScale)
			gl.Color(0,0,0,0.075)
			RectRound(yesButtonArea[1]+buttonPadding, yesButtonArea[2]+buttonPadding, yesButtonArea[3]-buttonPadding, yesButtonArea[4]-buttonPadding, 4*widgetScale)

			gl.Text("\255\255\255\255YES", yesButtonArea[1]+((yesButtonArea[3]-yesButtonArea[1])/2), yesButtonArea[2]+((yesButtonArea[4]-yesButtonArea[2])/2)-(fontSize/3), fontSize, "con")
		end
	end)
end

function widget:KeyPress(key)
	if key == 27 and voteDlist then	-- ESC
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

function widget:DrawScreen()
	if voteDlist then
		local x,y,b = Spring.GetMouseState()
		if IsOnRect(x, y, windowArea[1], windowArea[2], windowArea[3], windowArea[4]) then
			if (not voteOwner and IsOnRect(x, y, yesButtonArea[1], yesButtonArea[2], yesButtonArea[3], yesButtonArea[4])) or
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
		gl.CallList(voteDlist)
	end
end