function widget:GetInfo()
	return {
		name		= "Player TV",
		desc		= "Automaticly tracks players camera, (shows player-switch countdown on top of advplayerlist)",
		author		= "Floris",
		date		= "January 2018",
		license		= "GNU GPL, v2 or later",
		layer		= -4,
		enabled		= false,
		handler = true,
	}
end

local displayPlayername = true

local playerChangeDelay = 40

local parentPos = {}
local prevPos = {}
local drawlists = {}
local fontSize = 18	-- 14 to be aliek with advplayerslist_lockcamera widget
local top, left, bottom, right, widgetScale = 0,0,0,0,1
local rejoining = false
local initGameframe = Spring.GetGameFrame()
local prevOrderID = 1

local currentTrackedPlayer
local playersTS = {}
local nextTrackingPlayerChange = os.clock()

local tsOrderedPlayerCount = 0
local tsOrderedPlayers = {}

local enabled = Spring.GetSpectatingState()
local vsx, vsy = Spring.GetViewGeometry()
local widgetScale = (0.7 + (vsx*vsy / 5000000))

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


function updatePosition(force)
	prevPos = parentPos
	if (WG['advplayerlist_api'] ~= nil) then
		if WG['displayinfo'] ~= nil then
			if widgetHandler.orderList["AdvPlayersList info"] ~= nil and (widgetHandler.orderList["AdvPlayersList info"] > 0) then
				parentPos = WG['displayinfo'].GetPosition()		-- returns {top,left,bottom,right,widgetScale}
			end
		elseif WG['music'] ~= nil then
			if widgetHandler.orderList["Music Player"] ~= nil and (widgetHandler.orderList["Music Player"] > 0) then
				parentPos = WG['music'].GetPosition()		-- returns {top,left,bottom,right,widgetScale}
			end
		else
			parentPos = WG['advplayerlist_api'].GetPosition()		-- returns {top,left,bottom,right,widgetScale}
		end
	end

	left = parentPos[2]
	bottom = parentPos[1]
	right = parentPos[4]
	top = parentPos[1]
	widgetScale = parentPos[5]

	if (prevPos[1] == nil or prevPos[1] ~= parentPos[1] or prevPos[2] ~= parentPos[2] or prevPos[5] ~= parentPos[5]) or force then
		createLists()
	end
end

function createLists()
	if parentPos ~= nil then
		local i = 0
		local leftPadding = 7.5*widgetScale
		while i < playerChangeDelay do
			drawlists[i] = gl.CreateList(function()
				gl.Color(0,0,0,0.6)
				gl.Text(i, leftPadding+left-(0.7*widgetScale), bottom+(7*widgetScale), fontSize*widgetScale, 'n')
				gl.Text(i, leftPadding+left+(0.7*widgetScale), bottom+(7*widgetScale), fontSize*widgetScale, 'n')
				gl.Color(0.8,0.8,0.8,1)
				gl.Text(i, leftPadding+left, bottom+(8*widgetScale), fontSize*widgetScale, 'n')
			end)
			i = i + 1
		end
	end
end


function widget:Initialize()
	if not Spring.GetSpectatingState() then
		widgetHandler:RemoveWidget()
	end
	if WG['advplayerlist_api'] == nil then
		Spring.Echo("Top TS camera tracker: AdvPlayerlist not found! ...exiting")
		widgetHandler:RemoveWidget()
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
end


function widget:GameStart()
	enabled = Spring.GetSpectatingState()
	nextTrackingPlayerChange = os.clock()
	if enabled and not rejoining then
		SelectTrackingPlayer()
	end
end


function widget:PlayerChanged(playerID)
	if not rejoining then
		tsOrderPlayers()
		if playerID == currentTrackedPlayer then
			SelectTrackingPlayer()
		end
	end

end

local passedTime = 0
function widget:Update(dt)
	if enabled then
		passedTime = passedTime + dt
		if passedTime > 0.1 then
			passedTime = passedTime - 0.1
			updatePosition()
		end
		if (not rejoining) then
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
			--Spring.Echo('orderid: '..orderID)
				if tsOrderedPlayers[orderID] then
					SelectTrackingPlayer(tsOrderedPlayers[orderID][2])
				end
			end
		elseif WG['advplayerlist_api'].GetLockPlayerID() ~= nil then
			WG['advplayerlist_api'].SetLockPlayerID()
		end
	end
end

function widget:GameFrame(n)
	if enabled and n % 30 == 5 then
		if prevGameframeClock ~= nil and (os.clock() - prevGameframeClock) < 0.8 then
			rejoining = true
			if rejoining and WG['advplayerlist_api'].GetLockPlayerID() ~= nil then
				WG['advplayerlist_api'].SetLockPlayerID()
			end
		elseif rejoining then
			rejoining = false
			SelectTrackingPlayer()
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


function widget:ViewResize(newX,newY)
	vsx, vsy = Spring.GetViewGeometry()
	widgetScale = (0.7 + (vsx*vsy / 5000000))
	for i=1,#drawlists do
		gl.DeleteList(drawlists[i])
	end
	drawlists = {}
end


local font = gl.LoadFont("LuaUI/Fonts/FreeSansBold.otf", 64, 15,1.18)

function widget:DrawScreen()
	if enabled and not rejoining and Spring.GetGameFrame() > 0 then
		local countDown = math.floor(nextTrackingPlayerChange - os.clock())
		if drawlists[countDown] ~= nil then
			gl.PushMatrix()
			gl.CallList(drawlists[countDown])
			gl.PopMatrix()
		end
	end
	if displayPlayername then
		if WG['advplayerlist_api'] then
			if lockPlayerID == nil or lockPlayerID ~= WG['advplayerlist_api'].GetLockPlayerID() then
				lockPlayerID = WG['advplayerlist_api'].GetLockPlayerID()
				if lockPlayerID and not drawlists['p'..lockPlayerID] then
					drawlists['p'..lockPlayerID] = gl.CreateList( function()
						local name,_,_,teamID,_,_,_,_,_ = Spring.GetPlayerInfo(lockPlayerID)
						local fontSize = 31 * widgetScale
						local nameColourR,nameColourG,nameColourB,_ = Spring.GetTeamColor(teamID)
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
		if lockPlayerID then
			gl.PushMatrix()
			gl.CallList(drawlists['p'..lockPlayerID])
			gl.PopMatrix()
		end
	end
end


function widget:Shutdown()
	for i=1,#drawlists do
		gl.DeleteList(drawlists[i])
	end
end