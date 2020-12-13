function widget:GetInfo()
	return {
		name = "Build power",
		desc = "Displays build power usage",
		author = "Floris",
		date = "May 2020",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = false,
	}
end

local texts = {        -- fallback (if you want to change this, also update: language/en.lua, or it will be overwritten)
	usedbuildpower = 'Used buildpower',
	buildpower = 'buildpower',
	builders = 'builders',
	tip = 'Increase efficiency -> put idle worker units to work! (have enough resources too!)\n\255\240\240\240High buildpower usage -> make more workers',
}

local vsx, vsy = Spring.GetViewGeometry()

local ui_opacity = tonumber(Spring.GetConfigFloat("ui_opacity", 0.6) or 0.66)
local ui_scale = tonumber(Spring.GetConfigFloat("ui_scale", 1) or 1)
local glossMult = 1 + (2 - (ui_opacity * 2))    -- increase gloss/highlight so when ui is transparant, you can still make out its boundaries and make it less flat

local backgroundRect = { 0, 0, 0, 0 }

local bgBorderOrg = 0.0025
local bgBorder = bgBorderOrg
local bgMargin = 0.005

local avgFrames = 7     -- to smooth out changes
local avgBuildPower = 0

local widthMult = 0.05   -- multiplication of info widget width

local glBlending = gl.Blending
local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_ONE = GL.ONE

local isSpec = Spring.GetSpectatingState()
local myTeamID = Spring.GetMyTeamID()

local spGetTeamUnits = Spring.GetTeamUnits
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitCurrentBuildPower = Spring.GetUnitCurrentBuildPower

local totalBuilders = 0
local builders = {}
local totalBuildpower = 0

local isBuilder = {}
--local isWorker = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.buildSpeed > 0 and unitDef.canAssist then
		--if unitDef.buildOptions[1] then
		isBuilder[unitDefID] = unitDef.buildSpeed
		--else
		--    isWorker[unitDefID] = unitDef.buildSpeed
		--end
	end
end

local gamestarted, dlistGuishader, bgpadding, chobbyInterface, contentMargin, dlistBuildpower, dlistBuildpower2
local posX, posY, width, height

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

function getUsedBuildpower()
	local usedBuildpower = 0
	for unitID, unitDefID in pairs(builders) do
		local currentUnitBp = spGetUnitCurrentBuildPower(unitID)
		if currentUnitBp then
			usedBuildpower = usedBuildpower + (currentUnitBp * isBuilder[unitDefID])
		end
	end
	return usedBuildpower / totalBuildpower
end

local function initiateTeamBuildPower(teamID)
	local units = spGetTeamUnits(teamID)
	builders = {}
	totalBuilders = 0
	totalBuildpower = 0
	for _, unitID in pairs(units) do
		if isBuilder[spGetUnitDefID(unitID)] then
			builders[unitID] = spGetUnitDefID(unitID)
			totalBuilders = totalBuilders + 1
			totalBuildpower = totalBuildpower + isBuilder[spGetUnitDefID(unitID)]
		end
	end

	if gamestarted or Spring.GetGameFrame() > 0 then
		gamestarted = true
		avgBuildPower = getUsedBuildpower()
	else
		avgBuildPower = 0
	end
end

local function checkGuishader(force)
	if WG['guishader'] then
		if force and dlistGuishader then
			dlistGuishader = gl.DeleteList(dlistGuishader)
		end
		if not dlistGuishader then
			dlistGuishader = gl.CreateList(function()
				RectRound(backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4], bgpadding * 1.6, 1, 1, 0, 0)
			end)
			WG['guishader'].InsertDlist(dlistGuishader, 'buildpower')
		end
	elseif dlistGuishader then
		dlistGuishader = gl.DeleteList(dlistGuishader)
	end
end

function widget:ViewResize()
	vsx, vsy = Spring.GetViewGeometry()
	if posX then
		backgroundRect = { (width - (width * widthMult)) * vsx, 0, width * vsx, height * vsy }
		checkGuishader(true)
		clear()
	end
	local widgetSpaceMargin = math.floor(0.0045 * vsy * ui_scale) / vsy
	bgpadding = math.ceil(widgetSpaceMargin * 0.66 * vsy)
end

function widget:Initialize()
	if WG['lang'] then
		texts = WG['lang'].getText('buildpower')
	end
	widget:ViewResize()

	WG['buildpower'] = {}
	WG['buildpower'].getPosition = function()
		if posX then
			return width, height
		else
			return nil
		end
	end
	WG['buildpower'].getSize = function()
		if posX then
			return (width * widthMult), height
		else
			return nil
		end
	end

	initiateTeamBuildPower(myTeamID)
end

function widget:GameStart()
	widget:ViewResize()
end

function clear()
	dlistBuildpower = gl.DeleteList(dlistBuildpower)
end
function clear2()
	dlistBuildpower2 = gl.DeleteList(dlistBuildpower2)
end

function widget:Shutdown()
	clear()
	clear2()
	if WG['guishader'] and dlistGuishader then
		WG['guishader'].DeleteDlist('buildpower')
		dlistGuishader = nil
	end
	WG['buildpower'] = nil
end

local sec = 0
local uiOpacitySec = 0
function widget:Update(dt)

	uiOpacitySec = uiOpacitySec + dt
	if uiOpacitySec > 0.5 then
		if WG['info'] then
			local newWidth, newHeight = WG['info'].getPosition()
			if posX == nil or (newWidth ~= width or newHeight ~= height) then
				width, height = newWidth, newHeight
				posX, posY = width - (width * widthMult), 0
				widget:ViewResize()
			end
		end

		uiOpacitySec = 0
		checkGuishader()
		if ui_scale ~= Spring.GetConfigFloat("ui_scale", 1) then
			ui_scale = Spring.GetConfigFloat("ui_scale", 1)
			widget:ViewResize()
		end
		if ui_opacity ~= Spring.GetConfigFloat("ui_opacity", 0.6) then
			ui_opacity = Spring.GetConfigFloat("ui_opacity", 0.6)
			glossMult = 1 + (2 - (ui_opacity * 2))
			clear()
		end
	end

	sec = sec + dt
	if sec > 0.032 then
		sec = 0
		clear2()
	end
end

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

function IsOnRect(x, y, BLcornerX, BLcornerY, TRcornerX, TRcornerY)
	return x >= BLcornerX and x <= TRcornerX and y >= BLcornerY and y <= TRcornerY
end

function drawBuildpower()
	RectRound(backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4], bgpadding * 1.6, 0, 1, 0, 0, { 0.05, 0.05, 0.05, ui_opacity }, { 0, 0, 0, ui_opacity })
	RectRound(backgroundRect[1], backgroundRect[2] + bgpadding, backgroundRect[3] - bgpadding, backgroundRect[4] - bgpadding, bgpadding, 0, 1, 0, 0, { 0.3, 0.3, 0.3, ui_opacity * 0.1 }, { 1, 1, 1, ui_opacity * 0.1 })

	-- gloss
	glBlending(GL_SRC_ALPHA, GL_ONE)
	RectRound(backgroundRect[1], backgroundRect[4] - ((backgroundRect[4] - backgroundRect[2]) * 0.16), backgroundRect[3] - bgpadding, backgroundRect[4] - bgpadding, bgpadding, 0, 1, 0, 0, { 1, 1, 1, 0.006 * glossMult }, { 1, 1, 1, 0.055 * glossMult })
	RectRound(backgroundRect[1], backgroundRect[2], backgroundRect[3] - bgpadding, backgroundRect[2] + ((backgroundRect[4] - backgroundRect[2]) * 0.15), bgpadding, 0, 0, 0, 0, { 1, 1, 1, 0.02 * glossMult }, { 1, 1, 1, 0 })
	glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

	RectRound(backgroundRect[1], backgroundRect[4] - ((backgroundRect[4] - backgroundRect[2]) * 0.4), backgroundRect[3] - bgpadding, backgroundRect[4] - bgpadding, bgpadding, 0, 1, 0, 0, { 1, 1, 1, 0 }, { 1, 1, 1, 0.1 })
	--RectRound(backgroundRect[1],backgroundRect[2],backgroundRect[3]-bgpadding,backgroundRect[4]-((backgroundRect[4]-backgroundRect[2])*0.75), bgpadding, 0,0,0,0, {1,1,1,0.08}, {1,1,1,0})

	-- bar background
	contentMargin = math.ceil((backgroundRect[3] - backgroundRect[1]) * 0.2)
	RectRound(backgroundRect[1] + contentMargin, backgroundRect[2] + contentMargin, backgroundRect[3] - bgpadding - contentMargin, backgroundRect[4] - bgpadding - contentMargin, bgpadding * 0.5, 1, 1, 1, 1, { 0.04, 0.04, 0.04, 0.1 }, { 0.09, 0.09, 0.09, 0.1 })
end

function drawBuildpower2()
	if gamestarted or Spring.GetGameFrame() > 0 then
		gamestarted = true
		local buildpower = getUsedBuildpower()
		avgBuildPower = (buildpower + (avgBuildPower * (avgFrames - 1))) / avgFrames
		if avgBuildPower > 1 then
			-- can happen due to the averaging
			avgBuildPower = 1
		end

		local contentMargin2 = math.ceil(contentMargin * 1.3)
		local barHeight = math.ceil(((backgroundRect[4] - bgpadding - contentMargin2) - (backgroundRect[2] + contentMargin2)) * avgBuildPower)
		if barHeight > bgpadding * 2 then
			-- prevent artifacts
			RectRound(backgroundRect[1] + contentMargin2, backgroundRect[2] + contentMargin2, backgroundRect[3] - bgpadding - contentMargin2, backgroundRect[2] + contentMargin + barHeight, bgpadding * 0.4, 1, 1, 1, 1, { 0.6, 0.6, 0.6, 0.35 }, { 0.8, 0.8, 0.8, 0.35 }) --{0.2,0.6,0.2,0.45}, {0.5,1,0.5,0.45})
		end
	end
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1, 19) == 'LobbyOverlayActive1')
	end
end

function widget:PlayerChanged(playerID)
	isSpec = Spring.GetSpectatingState()
	local prevMyTeamID = Spring.GetMyTeamID()
	if prevMyTeamID ~= myTeamID then
		myTeamID = prevMyTeamID
		initiateTeamBuildPower(myTeamID)
	end
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if isBuilder[unitDefID] then
		builders[unitID] = unitDefID
		totalBuilders = totalBuilders + 1
		totalBuildpower = totalBuildpower + isBuilder[unitDefID]
	end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
	if isBuilder[unitDefID] then
		builders[unitID] = nil
		totalBuilders = totalBuilders - 1
		totalBuildpower = totalBuildpower - isBuilder[unitDefID]
	end
end

function widget:DrawScreen()
	if chobbyInterface then
		return
	end
	local x, y, b = Spring.GetMouseState()
	if WG['tooltip'] and IsOnRect(x, y, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4]) then
		Spring.SetMouseCursor('cursornormal')
		WG['tooltip'].ShowTooltip('buildpower', '\255\215\255\215'..texts.usedbuildpower': \255\255\255\200' .. math.ceil(avgBuildPower * 100) .. '% \255\180\180\180   '..texts.buildpower..': \255\255\255\200' .. totalBuildpower .. ' \255\180\180\180   '..texts.builders..': \255\255\255\200' .. totalBuilders .. '\n\255\240\240\240'..texts.tip)
		--Spring.SetMouseCursor('cursornormal')
	end

	if dlistGuishader and WG['guishader'] then
		WG['guishader'].InsertDlist(dlistGuishader, 'buildpower')
	end

	if posX then
		if not dlistBuildpower then
			dlistBuildpower = gl.CreateList(function()
				drawBuildpower()
			end)
		end
		if not dlistBuildpower2 then
			dlistBuildpower2 = gl.CreateList(function()
				drawBuildpower2()
			end)
		end
		gl.CallList(dlistBuildpower)
		gl.CallList(dlistBuildpower2)
	end
end

function IsOnRect(x, y, BLcornerX, BLcornerY, TRcornerX, TRcornerY)
	return x >= BLcornerX and x <= TRcornerX and y >= BLcornerY and y <= TRcornerY
end

function widget:MousePress(x, y, button)
	if Spring.IsGUIHidden() then
		return
	end
	if IsOnRect(x, y, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4]) then
		return true
	end
end
