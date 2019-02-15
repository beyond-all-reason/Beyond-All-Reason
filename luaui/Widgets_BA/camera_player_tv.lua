function widget:GetInfo()
	return {
		name		= "Player-TV",
		desc		= "Automaticly tracks players camera, (shows player-switch countdown on top of advplayerlist)",
		author		= "Floris",
		date		= "January 2018",
		license		= "GNU GPL, v2 or later",
		layer		= -2,
		enabled		= true,
	}
end

local displayPlayername = true

local playerChangeDelay = 40

local parentPos = {}
local prevPos = {}
local drawlistsCountdown = {}
local drawlistsPlayername = {}
local fontSize = 14	-- 14 to be alike with advplayerslist_lockcamera widget
local top, left, bottom, right, widgetScale = 0,0,0,0,1
local rejoining = false
local initGameframe = Spring.GetGameFrame()
local prevOrderID = 1

local currentTrackedPlayer
local playersTS = {}
local nextTrackingPlayerChange = os.clock()

local tsOrderedPlayerCount = 0
local tsOrderedPlayers = {}

local isSpec = Spring.GetSpectatingState()
local vsx, vsy = Spring.GetViewGeometry()
local widgetScale = (0.7 + (vsx*vsy / 5000000))

local toggled = false

local bgcorner = ":n:LuaUI/Images/bgcorner.png"

local drawlist = {}
local widgetHeight = 23

---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------

function deepcopy(orig)
	local orig_type = type(orig)
	local copy
	if orig_type == 'table' then
		copy = {}
		for orig_key, orig_value in next, orig, nil do
			copy[deepcopy(orig_key)] = deepcopy(orig_value)
		end
		setmetatable(copy, deepcopy(getmetatable(orig)))
	else -- number, string, boolean, etc
		copy = orig
	end
	return copy
end

function addPlayerTsOrdered(ts, playerID, teamID, spec)
	local inserted = false
	local newTsOrderedPlayers = {}
	tsOrderedPlayerCount = 0
	for _,params in ipairs(tsOrderedPlayers) do
		if not inserted and ts > params[1] then
			tsOrderedPlayerCount = tsOrderedPlayerCount + 1
			newTsOrderedPlayers[tsOrderedPlayerCount] = {ts, playerID, teamID, spec}
			inserted = true
		end
		tsOrderedPlayerCount = tsOrderedPlayerCount + 1
		newTsOrderedPlayers[tsOrderedPlayerCount] = params
	end
	if not inserted then
		tsOrderedPlayerCount = tsOrderedPlayerCount + 1
		newTsOrderedPlayers[tsOrderedPlayerCount] = {ts, playerID, teamID, spec }
	end
	tsOrderedPlayers = deepcopy(newTsOrderedPlayers)
end

function tsOrderPlayers()
	local playersList = Spring.GetPlayerList()
	for _,playerID in ipairs(playersList) do
		local _,_,spec,teamID = Spring.GetPlayerInfo(playerID)
		if playersTS[playerID] ~= nil then
			addPlayerTsOrdered(playersTS[playerID], playerID, teamID, spec)
		end
	end
end

function GetSkill(playerID)
	local customtable = select(11,Spring.GetPlayerInfo(playerID)) -- player custom table
	local tsMu = customtable.skill
	local tskill = ""
	if tsMu then
		tskill = tsMu and tonumber(tsMu:match("%d+%.?%d*")) or 0
	end
	return tskill
end


function SelectTrackingPlayer(playerID)
	local newTrackedPlayer
	if playerID then
		newTrackedPlayer = playerID
	else
		local highestTs = 0
		local playersList = Spring.GetPlayerList()
		for _,playerID in ipairs(playersList) do
			local _,active,spec = Spring.GetPlayerInfo(playerID)
			if not spec and active then
				if playersTS[playerID] ~= nil and playersTS[playerID] > highestTs then
					highestTs = playersTS[playerID]
					newTrackedPlayer = playerID
				end
			end
		end
	end
	if newTrackedPlayer ~= nil and newTrackedPlayer ~= currentTrackedPlayer then
		currentTrackedPlayer = newTrackedPlayer

		if WG['advplayerlist_api'] ~= nil and WG['advplayerlist_api'].SetLockPlayerID ~= nil then
			WG['advplayerlist_api'].SetLockPlayerID(currentTrackedPlayer)
		end
	end
end

function createCountdownLists()
	--if parentPos ~= nil then
		for i=1,#drawlistsCountdown do
			gl.DeleteList(drawlistsCountdown[i])
		end
		drawlistsCountdown = {}
		local i = 0
		local leftPadding = 7.5*widgetScale
		while i < playerChangeDelay do
			drawlistsCountdown[i] = gl.CreateList(function()
				gl.Color(0,0,0,0.6)
				gl.Text(i, leftPadding+left-(0.7*widgetScale), bottom+(7*widgetScale), fontSize*widgetScale, 'n')
				gl.Text(i, leftPadding+left+(0.7*widgetScale), bottom+(7*widgetScale), fontSize*widgetScale, 'n')
				gl.Color(0.8,0.8,0.8,1)
				gl.Text(i, leftPadding+left, bottom+(8*widgetScale), fontSize*widgetScale, 'n')
			end)
			i = i + 1
		end
	--end
end

local function DrawRectRound(px,py,sx,sy,cs)
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

local function createList()
	for i=1,#drawlist do
		gl.DeleteList(drawlist[i])
	end
	drawlist[1] = gl.CreateList( function()
		--glColor(0, 0, 0, 0.66)
		--RectRound(left, bottom, right, top, 5.5*widgetScale)
		--
		--local borderPadding = 2.75*widgetScale
		--glColor(1,1,1,0.025)
		--RectRound(left+borderPadding, bottom+borderPadding, right-borderPadding, top-borderPadding, 4.4*widgetScale)
		local fontSize = (widgetHeight*widgetScale) * 0.5
		local text = '   cancel camera   '
		local color = '\255\255\222\222'
		if not toggled and not lockPlayerID then
			text = '   Player TV   '
			color = '\255\222\255\222'
			gl.Color(0, 0.5, 0, 0.66)
		else
			gl.Color(0.66, 0, 0, 0.66)
		end
		local textWidth = gl.GetTextWidth(text) * fontSize
		RectRound(right-textWidth, bottom, right, top, 5.5*widgetScale)
		toggleButton = {right-textWidth, bottom, right, top }

		local borderPadding = 2.75*widgetScale
		gl.Color(0,0,0,0.18)
		RectRound(right-textWidth+borderPadding, bottom+borderPadding, right-borderPadding, top-borderPadding, 4.4*widgetScale)

		gl.Text(color..text, right-(textWidth/2), bottom+(8*widgetScale), fontSize, 'oc')

		if (WG['guishader_api'] ~= nil and isSpec) then
			WG['guishader_api'].InsertRect(toggleButton[1], toggleButton[2], toggleButton[3], toggleButton[4], 'playertv')
		end

		if toggled then
			local name = 'Player TV  '
			local fontSize = (widgetHeight*widgetScale) * 0.6
			local vpos = bottom+(5.5*widgetScale)
			gl.Color(0,0,0,0.6)
			gl.Text(name, right-textWidth-(0.7*widgetScale), vpos, fontSize, 'rn')
			gl.Text(name, right-textWidth+(0.7*widgetScale), vpos, fontSize, 'rn')
			gl.Color(1,1,1,1)
			gl.Text(name, right-textWidth, vpos+(1*widgetScale), fontSize, 'rn')
		end
	end)
	drawlist[2] = gl.CreateList( function()
		if toggled or lockPlayerID  then
			gl.Color(1, 0.2, 0.2, 0.4)
		else
			gl.Color(0.2, 1, 0.2, 0.4)
		end
		RectRound(toggleButton[1], toggleButton[2], toggleButton[3], toggleButton[4], 5.5*widgetScale)

		local borderPadding = 2.75*widgetScale
		gl.Color(0,0,0,0.14)
		RectRound(toggleButton[1]+borderPadding, toggleButton[2]+borderPadding, toggleButton[3]-borderPadding, toggleButton[4]-borderPadding, 4.4*widgetScale)

		local text = '   cancel camera   '
		local color = '\255\255\222\222'
		if not toggled and not lockPlayerID then
			text = '   Player TV   '
			color = '\255\222\255\222'
		end
		local fontSize = (widgetHeight*widgetScale) * 0.5
		local textWidth = gl.GetTextWidth(text) * fontSize
		gl.Text(color..text, toggleButton[3]-(textWidth/2), toggleButton[2]+(8*widgetScale), fontSize, 'oc')
	end)
end



function updatePosition(force)
	prevPos = parentPos
	if (WG['advplayerlist_api'] ~= nil) then
		if WG['displayinfo'] ~= nil then
			parentPos = WG['displayinfo'].GetPosition()		-- returns {top,left,bottom,right,widgetScale}
		elseif WG['music'] ~= nil then
			parentPos = WG['music'].GetPosition()		-- returns {top,left,bottom,right,widgetScale}
		else
			parentPos = WG['advplayerlist_api'].GetPosition()		-- returns {top,left,bottom,right,widgetScale}
		end
	end

	if parentPos[1] then
		left = parentPos[2]
		bottom = parentPos[1]
		right = parentPos[4]
		top = parentPos[1]+(widgetHeight*parentPos[5])
		widgetScale = parentPos[5]

		if (prevPos[1] == nil or prevPos[1] ~= parentPos[1] or prevPos[2] ~= parentPos[2] or prevPos[5] ~= parentPos[5]) or force then
			createCountdownLists()
			createList()
		end
	end
end


function widget:Initialize()
	isSpec = Spring.GetSpectatingState()
	if WG['advplayerlist_api'] == nil then
		Spring.Echo("Top TS camera tracker: AdvPlayerlist not found! ...exiting")
		widgetHandler:RemoveWidget(self)
	end
	local playersList = Spring.GetPlayerList()
	for _,playerID in ipairs(playersList) do
		local _,active,spec = Spring.GetPlayerInfo(playerID)
		if not spec then
			playersTS[playerID] = GetSkill(playerID)
		end
	end
	tsOrderPlayers()

	updatePosition()
	WG['playertv'] = {}
	WG['playertv'].GetPosition = function()
		return {top,left,bottom,right,widgetScale}
	end
	WG['playertv'].isActive = function()
		return (toggled and isSpec)
	end
	WG['playertv'].GetPlayerChangeDelay = function()
		return playerChangeDelay
	end
	WG['playertv'].SetPlayerChangeDelay = function(value)
		playerChangeDelay = value
		createCountdownLists()
	end
end


function widget:GameStart()
	isSpec = Spring.GetSpectatingState()
	nextTrackingPlayerChange = os.clock()
	tsOrderPlayers()
	if isSpec and not rejoining and toggled then
		SelectTrackingPlayer()
	end
end


function widget:PlayerChanged(playerID)
	isSpec = Spring.GetSpectatingState()
	tsOrderPlayers()
	if not rejoining then
		if playerID == currentTrackedPlayer then
			SelectTrackingPlayer()
		end
	end
end

local passedTime = 1
function widget:Update(dt)
	passedTime = passedTime + dt
	if passedTime > 0.1 then
		passedTime = 0
		updatePosition()
	end
	if isSpec and Spring.GetGameFrame() > 0 and not rejoining then
		if WG['tooltip'] and not toggled and not lockPlayerID then
			mx,my,mb = Spring.GetMouseState()
			if toggleButton ~= nil and isInBox(mx, my, toggleButton) then
				WG['tooltip'].ShowTooltip('playertv', 'Auto camera-track of mostly top TS players\n(switches player every '..playerChangeDelay..' seconds)')
			end
		end
		if (not rejoining and toggled) then
			if Spring.GetGameFrame() > initGameframe+70 and os.clock() > nextTrackingPlayerChange then	--delay some gameframes so we know if we're rejoining or not
				nextTrackingPlayerChange = os.clock() + playerChangeDelay
				local scope = 1 + math.floor(1 + tsOrderedPlayerCount/2)
				if tsOrderedPlayerCount <= 2 then
					scope = 2
				elseif tsOrderedPlayerCount <= 6 then
					scope = 1 + math.floor(1 + tsOrderedPlayerCount/1.5)
				elseif tsOrderedPlayerCount <= 10 then
					scope = 1 + math.floor(1 + tsOrderedPlayerCount/1.75)
				end
				local orderID = math.random(1,scope)

				local r = math.random()
				orderID = 1 + math.floor((r * (r*r)) * scope)
				if orderID == prevOrderID then	-- prevent same player POV again
					orderID = orderID - 1
					if orderID < 1 then
						orderID = 2
					end
				end
				prevorderID = orderID
				if tsOrderedPlayers[orderID] then
					SelectTrackingPlayer(tsOrderedPlayers[orderID][2])
				end
			end
		end
	end
end

function widget:GameFrame(n)
	if WG['topbar'] then
		local prevRejoining = rejoining
		rejoining = WG['topbar'].showingRejoining()
	end
	if isSpec and toggled and n % 30 == 5 then
		if rejoining and prevRejoining ~= rejoining then
			SelectTrackingPlayer()
		elseif rejoining and WG['advplayerlist_api'].GetLockPlayerID() ~= nil then
			WG['advplayerlist_api'].SetLockPlayerID()
		end
		prevGameframeClock = os.clock()

		if currentTrackedPlayer ~= nil and not rejoining then
			local _,active,spec = Spring.GetPlayerInfo(currentTrackedPlayer)
			if not active or spec then
				SelectTrackingPlayer()
			end
		end
	end
end

function isInBox(mx, my, box)
	return mx > box[1] and my > box[2] and mx < box[3] and my < box[4]
end

function widget:MousePress(mx, my, mb)
	if isSpec and mb == 1 and (Spring.GetGameFrame() > 0 or lockPlayerID) then
		if toggleButton ~= nil and isInBox(mx, my, toggleButton) then
			prevorderID = nil
			currentTrackedPlayer = nil
			if toggled or lockPlayerID then
				toggled = false
				WG['advplayerlist_api'].SetLockPlayerID()
				lockPlayerID = nil
				prevLockPlayerID = nil
				createList()
			elseif not rejoining then
				toggled = true
				nextTrackingPlayerChange = os.clock()-1
				createList()
			end
		end
	end
end

function widget:ViewResize(newX,newY)
	vsx, vsy = Spring.GetViewGeometry()
	widgetScale = (0.7 + (vsx*vsy / 5000000))
	createCountdownLists()
end


local font = gl.LoadFont("LuaUI/Fonts/FreeSansBold.otf", 64, 15,1.18)

function widget:DrawScreen()
	if not isSpec then return end

	local gameFrame = Spring.GetGameFrame()

	if (rejoining or gameFrame == 0) and not lockPlayerID then
		if (WG['guishader_api'] ~= nil) then
			WG['guishader_api'].RemoveRect('playertv')
		end
		--return
	end

	if gameFrame > 0 or lockPlayerID then
		if drawlist[1] then
			gl.PushMatrix()
			gl.CallList(drawlist[1])
			gl.PopMatrix()
			mx,my,mb = Spring.GetMouseState()
			if toggleButton ~= nil and isInBox(mx, my, toggleButton) then
				gl.CallList(drawlist[2])
			end
		end
	end

	if toggled and not rejoining and gameFrame > 0 then
		local countDown = math.floor(nextTrackingPlayerChange - os.clock())
		if drawlistsCountdown[countDown] ~= nil then
			gl.PushMatrix()
			gl.CallList(drawlistsCountdown[countDown])
			gl.PopMatrix()
		end
	end
	if displayPlayername then
		if WG['advplayerlist_api'] then
			if lockPlayerID == nil or lockPlayerID ~= WG['advplayerlist_api'].GetLockPlayerID() then
				lockPlayerID = WG['advplayerlist_api'].GetLockPlayerID()
				if not toggled and prevLockPlayerID ~= lockPlayerID then
					createList()
					prevLockPlayerID = lockPlayerID
				end
				if lockPlayerID and not drawlistsPlayername[lockPlayerID] then
					drawlistsPlayername[lockPlayerID] = gl.CreateList( function()
						local name,_,spec,teamID,_,_,_,_,_ = Spring.GetPlayerInfo(lockPlayerID)
						local fontSize = 31 * widgetScale
						local nameColourR,nameColourG,nameColourB = 1,1,1
						if not spec then
							nameColourR,nameColourG,nameColourB,_ = Spring.GetTeamColor(teamID)
						end
						local posX = vsx * 0.5
						local posY = vsy * 0.095

						font:Begin()
						font:SetTextColor(nameColourR,nameColourG,nameColourB,1)
						if (nameColourR + nameColourG*1.2 + nameColourB*0.4) < 0.8 then
							font:SetOutlineColor(1,1,1,1)
						else
							font:SetOutlineColor(0,0,0,1)
						end
						font:Print(name, posX, posY, fontSize, "con")
						font:End()
					end)
				end
			end
		end
		if lockPlayerID and drawlistsPlayername[lockPlayerID] then
			gl.PushMatrix()
			gl.CallList(drawlistsPlayername[lockPlayerID])
			gl.PopMatrix()
		end
	end
end


function widget:Shutdown()
	for i=1,#drawlistsCountdown do
		gl.DeleteList(drawlistsCountdown[i])
	end
	for i,v in pairs(drawlistsPlayername) do
		gl.DeleteList(drawlistsPlayername[i])
	end
	if (WG['guishader_api'] ~= nil) then
		WG['guishader_api'].RemoveRect('playertv')
	end
	for i=1,#drawlist do
		gl.DeleteList(drawlist[i])
	end
	if toggled then
		WG['advplayerlist_api'].SetLockPlayerID()
	end
end


function widget:GetConfigData(data)
	savedTable = {}
	savedTable.toggled = toggled
	savedTable.playerChangeDelay = playerChangeDelay
	return savedTable
end

function widget:SetConfigData(data)
	if Spring.GetGameFrame() > 0 and data.toggled ~= nil then
		toggled = data.toggled
	end
	if data.playerChangeDelay then
		playerChangeDelay = data.playerChangeDelay
	end
end