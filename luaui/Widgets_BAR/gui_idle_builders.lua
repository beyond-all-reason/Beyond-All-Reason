function widget:GetInfo()
	return {
		name = "Idle Builders",
		desc = "Idle Indicator",
		author = "Floris (original by Ray)",
		date = "15 april 2015",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true  --  loaded by default?
	}
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local vsx, vsy = Spring.GetViewGeometry()

local enabledAsSpec = false

local MAX_ICONS = 14
local iconsize = 35
local CONDENSE = true -- show one icon for all builders of same type
local POSITION_X = 0.5 -- horizontal centre of screen
local POSITION_Y = 0.178 -- near bottom
local NEAR_IDLE = 0 -- this means that factories with only X build items left will be shown as idle

local ui_opacity = tonumber(Spring.GetConfigFloat("ui_opacity", 0.6) or 0.66)
local ui_scale = tonumber(Spring.GetConfigFloat("ui_scale", 1) or 1)

local ICON_SIZE = iconsize * (1 + (ui_scale - 1) / 1.5)
ICON_SIZE = math.floor(ICON_SIZE/2) * 2	-- make sure it's divisible by 2

local texts = {
	idle = 'Idle',
}

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local cornerSize = 7
local bgcornerSize = cornerSize

local playSounds = true
local leftclick = 'LuaUI/Sounds/buildbar_add.wav'
local rightclick = 'LuaUI/Sounds/buildbar_click.wav'

local fontFile = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")
local chobbyInterface, font

local X_MIN = 0
local X_MAX = 0
local Y_MIN = 0
local Y_MAX = 0
local drawTable = {}
local IdleList = {}
local activePress = false
local QCount = {}
local noOfIcons = 0
local displayList = {}

local spGetSpectatingState = Spring.GetSpectatingState
local enabled = true

local isBuilder = {}
local isFactory = {}
local unitBuildPic = {}
local unitHumanName = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.buildSpeed > 0 then --and unitDef.buildOptions[1] then
		isBuilder[unitDefID] = true
	end
	if unitDef.isFactory then
		isFactory[unitDefID] = true
	end
	if unitDef.buildpicname then
		unitBuildPic[unitDefID] = unitDef.buildpicname
	end
	if unitDef.humanName then
		unitHumanName[unitDefID] = unitDef.humanName
	end
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local glColor = gl.Color
local glShape = gl.Shape
local glBlending = gl.Blending
local glMaterial = gl.Material
local glTranslate = gl.Translate
local glTexture = gl.Texture
local glPushMatrix = gl.PushMatrix
local glPopMatrix = gl.PopMatrix
local glClear = gl.Clear
local glText = gl.Text
local glUnit = gl.Unit
local glRotate = gl.Rotate
local glRect = gl.Rect
local glCallList = gl.CallList
local glCreateList = gl.CreateList
local glDeleteList = gl.DeleteList
local glBeginEnd = gl.BeginEnd
local glTexCoord = gl.TexCoord
local glVertex = gl.Vertex
local glGetScreenViewTrans = gl.GetScreenViewTrans

local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_LINE_LOOP = GL.LINE_LOOP
local GL_FRONT = GL.FRONT
local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE = GL.ONE
local GL_QUADS = GL.QUADS
local GL_DEPTH_BUFFER_BIT = GL.DEPTH_BUFFER_BIT

local GetUnitDefID = Spring.GetUnitDefID
local GetFullBuildQueue = Spring.GetFullBuildQueue
local GetUnitHealth = Spring.GetUnitHealth
local GetCommandQueue = Spring.GetCommandQueue
local GetMyTeamID = Spring.GetMyTeamID
local GetTeamUnitsSorted = Spring.GetTeamUnitsSorted
local GetMouseState = Spring.GetMouseState
local GetUnitPosition = Spring.GetUnitPosition
local SendCommands = Spring.SendCommands
local SelectUnitArray = Spring.SelectUnitArray
local GetModKeyState = Spring.GetModKeyState
local GetUnitDefDimensions = Spring.GetUnitDefDimensions

local GetViewGeometry = Spring.GetViewGeometry
local ValidUnitID = Spring.ValidUnitID
local GetGameFrame = Spring.GetGameFrame

local math_sin = math.sin
local math_pi = math.pi

local getn = table.getn

local RectRound = Spring.FlowUI.Draw.RectRound
local UiUnit = Spring.FlowUI.Draw.Unit
local bgpadding = Spring.FlowUI.elementPadding

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local sizeMultiplier = 1
local function init()
	vsx, vsy = GetViewGeometry()
	sizeMultiplier = (((vsy) / 750) * 1) * (1 + (ui_scale - 1) / 1.5)

	ICON_SIZE = iconsize * sizeMultiplier
	ICON_SIZE = math.floor(ICON_SIZE/2) * 2	-- make sure it's divisible by 2

	bgcornerSize = cornerSize * (sizeMultiplier - 1)
	noOfIcons = 0   -- this fixes positioning when resolution change
end

function widget:ViewResize()
	vsx, vsy = Spring.GetViewGeometry()
	font = WG['fonts'].getFont(fontFile, 1, 0.2, 1.3)
	bgpadding = Spring.FlowUI.elementPadding
	init()
end

function widget:PlayerChanged(playerID)
	if enabledAsSpec == false and Spring.GetGameFrame() > 0 and Spring.GetSpectatingState() then
		widgetHandler:RemoveWidget(self)
	end
end

function widget:Initialize()

	if WG['lang'] then
		texts = WG['lang'].getText('idlebuilders')
	end

	widget:ViewResize()
	widget:PlayerChanged()
	enabled = true
	if not enabledAsSpec then
		enabled = not spGetSpectatingState()
	end
	init()
end

function widget:GameOver()
	widgetHandler:RemoveWidget(self)
end

local function IsIdleBuilder(unitID)
	local udef = GetUnitDefID(unitID)
	local qCount = 0
	if isBuilder[udef] then
		--- can build
		local bQueue = GetFullBuildQueue(unitID)
		if not bQueue[1] then
			--- has no build queue
			local _, _, _, _, buildProg = GetUnitHealth(unitID)
			if buildProg == 1 then
				--- isnt under construction
				if isFactory[udef] then
					return true
				else
					if GetCommandQueue(unitID, 0) == 0 then
						return true
					end
				end
			end
		elseif isFactory[udef] then
			for _, thing in ipairs(bQueue) do
				for _, count in pairs(thing) do
					qCount = qCount + count
				end
			end
			if qCount <= NEAR_IDLE then
				QCount[unitID] = qCount
				return true
			end
		end
	end
	return false
end

local function DrawBoxes(number)
	glColor({ 0, 0, 0, 0.85 })
	local X1 = X_MIN
	local ct = 0
	while (ct < number) do
		ct = ct + 1
		local X2 = X1 + ICON_SIZE

		if widgetHandler:InTweakMode() then
			glShape(GL_LINE_LOOP, {
				{ v = { X1, Y_MIN } },
				{ v = { X2, Y_MIN } },
				{ v = { X2, Y_MAX } },
				{ v = { X1, Y_MAX } },
			})
			X1 = X2
		else
			--DrawIconQuad((ct-1), { 0, 0, 0, 0.4 }, 1.2)
		end
	end
	--Spring.Echo(X2)
end--]]


local function MouseOverIcon(x, y)
	if not drawTable then
		return -1
	end

	local NumOfIcons = table.getn(drawTable)
	if x < X_MIN then
		return -1
	end
	if x > X_MAX then
		return -1
	end
	if y < Y_MIN then
		return -1
	end
	if y > Y_MAX then
		return -1
	end

	local icon = math.floor((x - X_MIN) / ICON_SIZE)
	if icon < 0 then
		icon = 0
	end
	if icon >= NumOfIcons then
		icon = (NumOfIcons - 1)
	end
	return icon
end

local function DrawUnitIcons(number)
	if not drawTable then
		return -1
	end
	local ct = 0
	local X1, X2

	local iconNum = MouseOverIcon(GetMouseState())

	while ct < number do
		ct = ct + 1
		local unitID = drawTable[ct][2]

		if (type(unitID) == 'number' and ValidUnitID(unitID)) or type(unitID) == 'table' then

			if type(unitID) == 'table' then
				unitID = unitID[1]
			end

			local unitDefID = GetUnitDefID(unitID)
			if unitBuildPic[unitDefID] then
				local iconPadding = math.floor(ICON_SIZE*0.05)
				if ct-1 == iconNum then
					iconPadding = math.floor(ICON_SIZE*0.02)
				end

				X1 = math.floor(X_MIN + (ICON_SIZE * (ct - 1)))
				X2 = math.floor(X1 + ICON_SIZE)

				local bordersize = math.max(1, math.floor(ICON_SIZE*0.02))
				glColor(0,0,0,0.12)
				RectRound(X1+iconPadding - bordersize, Y_MIN+iconPadding - bordersize, X2-iconPadding + bordersize, Y_MAX-iconPadding + bordersize, bgcornerSize*0.3)

				glColor(1,1,1,1)
				UiUnit(X1+iconPadding, Y_MIN+iconPadding, X2-iconPadding, Y_MAX-iconPadding,
					math.ceil(bgpadding*0.5), 1,1,1,1,
					0.05,
					nil, nil,
					':lr'..math.floor(ICON_SIZE*1.5)..','..math.floor(ICON_SIZE*1.5)..':unitpics/'..unitBuildPic[unitDefID]
				)

				if CONDENSE then
					local NumberCondensed = table.getn(drawTable[ct][2])
					if NumberCondensed > 1 then
						font:Begin()
						font:Print(NumberCondensed, X1+math.floor(ICON_SIZE*0.1), Y_MIN+math.floor(ICON_SIZE*0.13), 12 * sizeMultiplier, "o")
						font:End()
					end
				end

				if ValidUnitID(unitID) and QCount[unitID] then
					font:Begin()
					font:Print(QCount[unitID], X1 + (0.5 * ICON_SIZE), Y_MIN, 14 * sizeMultiplier, "ocn")
					font:End()
				end
			end
		end
	end
	glTexture(false)
end


function DrawIconQuad(iconPos, color, size)
	local X1 =  math.floor(X_MIN + (ICON_SIZE * iconPos))
	local X2 =  math.floor(X1 + ICON_SIZE)

	local bordersize = math.max(1, math.floor(size*0.6))

	glColor(color)
	RectRound(X1 - bordersize, Y_MIN - bordersize, X2 + bordersize, Y_MAX + bordersize, bgcornerSize/2)

	if WG['guishader'] then
		WG['guishader'].InsertDlist(glCreateList(function()
			RectRound(X1 - bordersize, Y_MIN - bordersize, X2 + bordersize, Y_MAX + bordersize, bgcornerSize)
		end), 'idlebuilders')
	end

end


------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------
local Clicks = {}
local mouseOnUnitID = nil

function widget:GetConfigData(data)
	return {
		position_x = POSITION_X,
		pposition_y = POSITION_Y,
		--max_icons = MAX_ICONS
	}
end

function widget:SetConfigData(data)
	POSITION_X = data.position_x or POSITION_X
	POSITION_Y = data.pposition_y or POSITION_Y
	--MAX_ICONS = data.max_icons or MAX_ICONS
end

local sec = 0
local doUpdate = true
local uiOpacitySec = 0.5
function widget:Update(dt)

	if chobbyInterface then
		return
	end

	if not enabled then
		return
	end

	uiOpacitySec = uiOpacitySec + dt
	if uiOpacitySec > 0.5 then
		uiOpacitySec = 0
		if ui_scale ~= Spring.GetConfigFloat("ui_scale", 1) then
			ui_scale = Spring.GetConfigFloat("ui_scale", 1)
			widget:ViewResize(Spring.GetViewGeometry())
		end
		uiOpacitySec = 0
		if ui_opacity ~= Spring.GetConfigFloat("ui_opacity", 0.6) then
			ui_opacity = Spring.GetConfigFloat("ui_opacity", 0.6)
		end
	end

	local iconNum = MouseOverIcon(GetMouseState())
	if iconNum < 0 then
		mouseOnUnitID = nil
	else
		local unitID = drawTable[iconNum + 1][2]
		local unitDefID = drawTable[iconNum + 1][1]
		if not Clicks[unitDefID] then
			Clicks[unitDefID] = 1
		end
		if type(unitID) == 'table' then
			unitID = unitID[(Clicks[unitDefID] + 1) % getn(unitID) + 1]
		end
		mouseOnUnitID = unitID
	end

	sec = sec + dt

	if GetGameFrame() % 31 == 0 or doUpdate then
		doUpdate = false
		IdleList = {}
		QCount = {}
		local myUnits = GetTeamUnitsSorted(GetMyTeamID())
		local unitCount = 0
		for unitDefID, unitTable in pairs(myUnits) do
			if type(unitTable) == 'table' then
				for count, unitID in pairs(unitTable) do
					if count ~= 'n' and IsIdleBuilder(unitID) then
						unitCount = unitCount + 1
						if IdleList[unitDefID] then
							IdleList[unitDefID][#IdleList[unitDefID] + 1] = unitID
						else
							IdleList[unitDefID] = { unitID }
						end
					end
				end
			end
		end

		if unitCount >= MAX_ICONS then
			CONDENSE = true
		else
			CONDENSE = false
		end

		local oldNoOfIcons = noOfIcons
		noOfIcons = 0
		drawTable = {}
		local drawTableCount = 0
		for unitDefID, units in pairs(IdleList) do
			if CONDENSE then
				drawTableCount = drawTableCount + 1
				drawTable[drawTableCount] = { unitDefID, units }
				noOfIcons = noOfIcons + 1
			else
				for _, unitID in pairs(units) do
					drawTableCount = drawTableCount + 1
					drawTable[drawTableCount] = { unitDefID, unitID }
				end
				noOfIcons = noOfIcons + table.getn(units)
			end
		end
		if noOfIcons > MAX_ICONS then
			noOfIcons = MAX_ICONS
		end
		if noOfIcons ~= oldNoOfIcons then
			calcSizes(noOfIcons)
		end
	end
end

function calcSizes(numIcons)
	X_MIN = math.floor(POSITION_X * vsx - 0.5 * numIcons * ICON_SIZE)
	X_MAX = math.floor(POSITION_X * vsx + 0.5 * numIcons * ICON_SIZE)
	Y_MIN = math.floor(POSITION_Y * vsy - 0.5 * ICON_SIZE)
	Y_MAX = math.floor(POSITION_Y * vsy + 0.5 * ICON_SIZE)
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

	if widgetHandler:InTweakMode() then
		calcSizes(MAX_ICONS)
		DrawBoxes(MAX_ICONS)
		calcSizes(noOfIcons)
		local line1 = "Idle cons tweak mode"
		local line2 = "Click and drag here to move icons around, hover over icons and move mouse wheel to change max number of icons"
		font:Begin()
		font:Print(line1, POSITION_X * vsx, POSITION_Y * vsy, 16, "c")
		font:Print(line2, POSITION_X * vsx, (POSITION_Y * vsy) - 10, 12, "c")
		font:End()
		return
	end

	if WG['guishader'] then
		WG['guishader'].DeleteDlist('idlebuilders')
	end

	if enabled and noOfIcons > 0 then
		local x, y, lb, mb, rb = GetMouseState()

		if not WG['topbar'] or not WG['topbar'].showingQuit() then
			local icon = MouseOverIcon(x, y)
			if icon >= 0 then
				if WG['tooltip'] then
					local unitDefID = drawTable[icon + 1][1]
					WG['tooltip'].ShowTooltip('idlebuilders', texts.idle..' '..unitHumanName[unitDefID])
				end
				if lb then
					DrawIconQuad(icon, { 1, 1, 1, 0.85 }, 1.1)
				elseif rb then
					DrawIconQuad(icon, { 0.4, 0.6, 0, 0.75 }, 1.1)
				else
					DrawIconQuad(icon, { 0, 0, 0.1, 0.45 }, 1.1)
				end
			end
		end
		glClear(GL_DEPTH_BUFFER_BIT)
		DrawUnitIcons(noOfIcons)
	end
end

function widget:TweakMouseMove(x, y, dx, dy, button)
	local right = (x + (0.5 * MAX_ICONS * ICON_SIZE)) / vsx
	local left = (x - (0.5 * MAX_ICONS * ICON_SIZE)) / vsx
	local top = (y + (0.5 * ICON_SIZE)) / vsy
	local bottom = (y - (0.5 * ICON_SIZE)) / vsy
	if right > 1 then
		right = 1
		left = 1 - (MAX_ICONS * ICON_SIZE) / vsx
	end
	if left < 0 then
		left = 0
		right = (MAX_ICONS * ICON_SIZE) / vsx
	end
	if top > 1 then
		top = 1
		bottom = 1 - ICON_SIZE / vsy
	end
	if bottom < 0 then
		bottom = 0
		top = ICON_SIZE / vsy
	end

	POSITION_X = 0.5 * (right + left)
	POSITION_Y = 0.5 * (top + bottom)
end

function widget:TweakMousePress(x, y, button)
	local iconNum = MouseOverIcon(x, y)
	if iconNum >= 0 then
		return true
	end
end

function widget:MouseWheel(up, value)
	if not widgetHandler:InTweakMode() then
		return false
	end

	local x, y, _, _, _ = GetMouseState()
	local iconNum = MouseOverIcon(x, y)
	if iconNum < 0 then
		return false
	end

	if up then
		MAX_ICONS = MAX_ICONS + 1
	else
		MAX_ICONS = MAX_ICONS - 1
		if MAX_ICONS < 1 then
			MAX_ICONS = 1
		end
	end
	return true
end

function widget:DrawInMiniMap(sx, sz)
	if not mouseOnUnitID then
		return -1
	end

	local ux, uy, uz = GetUnitPosition(mouseOnUnitID)
	if not ux or not uy or not uz then
		return
	end
	local xr = ux / (Game.mapSizeX)
	local yr = 1 - uz / (Game.mapSizeZ)
	glColor(1, 0, 0)
	glRect(xr * sx, yr * sz, (xr * sx) + 5, (yr * sz) + 5)
end

function widget:MousePress(x, y, button)
	local icon = MouseOverIcon(x, y)
	activePress = (icon >= 0)
	return activePress
end

function widget:MouseRelease(x, y, button)
	if not activePress then
		return -1
	end
	activePress = false

	local iconNum = MouseOverIcon(x, y)
	if iconNum < 0 then
		return -1
	end

	local unitID = drawTable[iconNum + 1][2]
	local unitDefID = drawTable[iconNum + 1][1]

	if type(unitID) == 'table' then
		if Clicks[unitDefID] then
			Clicks[unitDefID] = Clicks[unitDefID] + 1
		else
			Clicks[unitDefID] = 1
		end
		unitID = unitID[(Clicks[unitDefID]) % getn(unitID) + 1]
	end

	local alt, ctrl, meta, shift = GetModKeyState()

	if button == 1 then
		-- left mouse
		SelectUnitArray({ unitID })
		if playSounds then
			Spring.PlaySoundFile(leftclick, 0.75, 'ui')
		end
	elseif button == 3 then
		-- right mouse
		SelectUnitArray({ unitID })
		SendCommands({ "viewselection" })
		if playSounds then
			Spring.PlaySoundFile(rightclick, 0.75, 'ui')
		end
	end

	return -1
end

function widget:DrawWorld()
	if chobbyInterface then
		return
	end
	if mouseOnUnitID and (not WG['topbar'] or not WG['topbar'].showingQuit()) then
		if widgetHandler:InTweakMode() then
			return -1
		end
		glColor(1, 1, 1, 0.22)
		glUnit(mouseOnUnitID, true)
	end
end

function widget:Shutdown()
	if WG['guishader'] then
		WG['guishader'].DeleteDlist('idlebuilders')
	end
end
