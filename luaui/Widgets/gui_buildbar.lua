local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "BuildBar",
		desc = "An extended buildbar to access the BuildOptions of factories\neverywhere on the map without selecting them before",
		author = "jK",
		date = "Jul 11, 2007",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = false
	}
end

local minimapUtils = VFS.Include("luaui/Include/minimap_utils.lua")
local getCurrentMiniMapRotationOption = minimapUtils.getCurrentMiniMapRotationOption
local ROTATION = minimapUtils.ROTATION

local vsx, vsy = Spring.GetViewGeometry()
local ui_scale = tonumber(Spring.GetConfigFloat("ui_scale", 1) or 1)

-- saved values
local bar_side = 1     --left:0,top:2,right:1,bottom:3
local bar_horizontal = false --(not saved) if sides==top v bottom -> horizontal:=true  else-> horizontal:=false
local bar_offset = 0     --relative offset side middle (i.e., bar_pos := vsx*0.5+bar_offset)
local bar_align = 1     --aligns icons to bar_pos: center=0; left/top=+1; right/bottom=-1

-- list and interface vars
local facs = {}
local unfinished_facs = {}
local openedMenu = -1 --Last non -1 hoveredFac value
local hoveredFac = -1 --Number of factory icon with mouse over it(starts at 0)
local hoveredBOpt = -1
local pressedFac = -1
local pressedBOpt = -1

local dlists = {}

-- factory icon rectangle
local facRect = { -1, -1, -1, -1 }

-- build options rectangle
local boptRect = { -1, -1, -1, -1 }

-- the following vars make it very easy to use the same code to render the menus, whatever side they are
-- cause we simple take topleft_startcorner and add recursivly *_inext to it to access they next icon pos
local fac_inext = { 0, 0 }
local bopt_inext = { 0, 0 }

local myTeamID = 0

local orgIconTypes = VFS.Include("gamedata/icontypes.lua")
local unitIcon = {}
local unitBuildOptions = {}
for udid, unitDef in pairs(UnitDefs) do
	if unitDef.isFactory and #unitDef.buildOptions > 0 then
		unitBuildOptions[udid] = unitDef.buildOptions
	end
	if unitDef.iconType and orgIconTypes[unitDef.iconType] and orgIconTypes[unitDef.iconType].bitmap then
		unitIcon[udid] = ':l:'..orgIconTypes[unitDef.iconType].bitmap
	end
end
orgIconTypes = nil

local repeatPic = ":l:LuaUI/Images/repeat.png"

local iconSizeY = 65		-- reset in ViewResize
local iconSizeX = iconSizeY
local repIcoSize = math.floor(iconSizeY * 0.6)   --repeat iconsize
local fontSize = iconSizeY * 0.31
local maxVisibleBuilds = 3

local msx = Game.mapX * 512
local msz = Game.mapY * 512

local groups, unitGroup = {}, {}	-- retrieves from buildmenu in initialize
local unitOrder = {}	-- retrieves from buildmenu in initialize

local bgpadding, font, backgroundRect, backgroundOptionsRect, buildoptionsArea, dlistGuishader, dlistGuishader2, forceGuishader
local factoriesArea, cornerSize, setInfoDisplayUnitID, setInfoDisplayUnitDefID, factoriesAreaHovered

-------------------------------------------------------------------------------
-- Speed Up
-------------------------------------------------------------------------------

local GL_ONE = GL.ONE
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_SRC_ALPHA = GL.SRC_ALPHA
local glBlending = gl.Blending
local math_floor = math.floor
local GetUnitDefID = Spring.GetUnitDefID
local GetMouseState = Spring.GetMouseState
local GetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local GetUnitStates = Spring.GetUnitStates
local DrawUnitCommands = Spring.DrawUnitCommands
local GetFullBuildQueue = Spring.GetFullBuildQueue
local GetUnitIsBuilding = Spring.GetUnitIsBuilding
local glColor = gl.Color
local glTexture = gl.Texture
local glTexRect = gl.TexRect

local RectRound, RectRoundProgress, UiElement, UiUnit, elementCorner

local anonymousMode = Spring.GetModOptions().teamcolors_anonymous_mode
local anonymousTeamColor = {Spring.GetConfigInt("anonymousColorR", 255)/255, Spring.GetConfigInt("anonymousColorG", 0)/255, Spring.GetConfigInt("anonymousColorB", 0)/255}

-------------------------------------------------------------------------------
-- SOUNDS
-------------------------------------------------------------------------------

local sound_click = 'LuaUI/Sounds/buildbar_click.wav'
local sound_hover = 'LuaUI/Sounds/buildbar_hover.wav'
local sound_queue_add = 'LuaUI/Sounds/buildbar_add.wav'
local sound_queue_rem = 'LuaUI/Sounds/buildbar_rem.wav'

-------------------------------------------------------------------------------
-- SOME THINGS NEEDED IN DRAWINMINIMAP
-------------------------------------------------------------------------------

local function checkGuishader(force)
	if WG['guishader'] and backgroundRect then
		if force then
			if dlistGuishader then
				dlistGuishader = gl.DeleteList(dlistGuishader)
			end
			if dlistGuishader2 then
				dlistGuishader2 = gl.DeleteList(dlistGuishader2)
			end
		end
		if not dlistGuishader and backgroundRect then
			dlistGuishader = gl.CreateList( function()
				RectRound(backgroundRect[1],backgroundRect[2],backgroundRect[3],backgroundRect[4], elementCorner * ui_scale, 1,0,0,1)
			end)
		end
		if not dlistGuishader2 and backgroundOptionsRect then
			dlistGuishader2 = gl.CreateList( function()
				RectRound(backgroundOptionsRect[1],backgroundOptionsRect[2],backgroundOptionsRect[3],backgroundOptionsRect[4], elementCorner * ui_scale)
			end)
		end
	else
		if dlistGuishader then
			dlistGuishader = gl.DeleteList(dlistGuishader)
		end
		if dlistGuishader2 then
			dlistGuishader2 = gl.DeleteList(dlistGuishader2)
		end
	end
end

-------------------------------------------------------------------------------
-- SCREENSIZE FUNCTIONS
-------------------------------------------------------------------------------

function widget:ViewResize()
	vsx, vsy = Spring.GetViewGeometry()

	bgpadding = WG.FlowUI.elementPadding
	elementCorner = WG.FlowUI.elementCorner

	RectRound = WG.FlowUI.Draw.RectRound
	RectRoundProgress = WG.FlowUI.Draw.RectRoundProgress
	UiElement = WG.FlowUI.Draw.Element
	UiUnit = WG.FlowUI.Draw.Unit

	font = WG['fonts'].getFont(2)

	iconSizeY = math.floor((vsy / 19) * (1 + (ui_scale - 1) / 1.5))
	iconSizeX = iconSizeY
	fontSize = iconSizeY * 0.31
	repIcoSize = math.floor(iconSizeY * 0.4)

	-- Setup New Screen Alignment
	bar_horizontal = (bar_side > 1)
	if bar_side == 0 then
		-- left
		fac_inext = { 0, -iconSizeY }
		bopt_inext = { iconSizeX, 0 }
	elseif bar_side == 2 then
		-- top
		fac_inext = { iconSizeX, 0 }
		bopt_inext = { 0, -iconSizeY }
	elseif bar_side == 1 then
		-- right
		fac_inext = { 0, -iconSizeY }
		bopt_inext = { -iconSizeX, 0 }
	else
		--bar_side==3       -- bottom
		fac_inext = { iconSizeX, 0 }
		bopt_inext = { 0, iconSizeY }
	end

	forceGuishader = true
end

-------------------------------------------------------------------------------
-- GEOMETRIC FUNCTIONS
-------------------------------------------------------------------------------

local function clampScreen(mid, half, vsd)
	if mid - half < 0 then
		return 0, half * 2
	elseif mid + half > vsd then
		return vsd - half * 2, vsd
	else
		local val = math.floor(mid - half)
		return val, val + half * 2
	end
end

local function adjustSecondaryAxis(bar_side, vsd, iconSizeD)
	-- bar_side is 0 for left and top, and 1 for right and bottom
	local val = bar_side * (vsd - iconSizeD)
	return val, iconSizeD + val
end

local function setupDimensions(count)
	local length, mid, iconSizeA, iconSizeB, vsa, vsb
	if bar_horizontal then
		-- horizontal (top or bottom bar)
		vsa, iconSizeA, vsb, iconSizeB = vsx, iconSizeX, vsy, iconSizeY
	else
		-- vertical (left or right bar)
		vsa, iconSizeA, vsb, iconSizeB = vsy, iconSizeY, vsx, iconSizeX
	end
	length = math.floor(iconSizeA * count)
	mid = vsa * 0.5 + bar_offset

	-- setup expanding direction
	mid = mid + bar_align * length * 0.5

	-- clamp screen
	local v1, v2 = clampScreen(mid, length * 0.5, vsa)

	-- adjust SecondaryAxis
	local v3, v4 = adjustSecondaryAxis(bar_side % 2, vsb, iconSizeB)

	-- assign rect
	if bar_horizontal then
		facRect[1], facRect[3], facRect[4], facRect[2] = v1, v2, v3, v4
	else
		facRect[4], facRect[2], facRect[1], facRect[3] = v1, v2, v3, v4
	end
end

local function setupSubDimensions()
	if openedMenu < 0 then
		boptRect = { -1, -1, -1, -1 }
		return
	end

	local buildListn = #facs[openedMenu + 1].buildList
	if bar_horizontal then
		--please note the factorylist is horizontal not the buildlist!!!

		boptRect[1] = math.floor(facRect[1] + iconSizeX * openedMenu)
		boptRect[3] = boptRect[1] + iconSizeX
		if bar_side == 2 then
			--top
			boptRect[2] = vsy - iconSizeY
			boptRect[4] = boptRect[2] - math.floor(iconSizeY * buildListn)
		else
			--bottom
			boptRect[4] = iconSizeY
			boptRect[2] = iconSizeY + math.floor(iconSizeY * buildListn)
		end
	else
		boptRect[2] = math.floor(facRect[2] - iconSizeY * openedMenu)
		boptRect[4] = boptRect[2] - iconSizeY
		if bar_side == 0 then
			--left
			boptRect[1] = iconSizeX
			boptRect[3] = iconSizeX + math.floor(iconSizeX * buildListn)
		else
			--right
			boptRect[3] = vsx - iconSizeX
			boptRect[1] = boptRect[3] - math.floor(iconSizeX * buildListn)
		end
	end
end

-------------------------------------------------------------------------------
-- UNIT INITIALIZATION FUNCTIONS
-------------------------------------------------------------------------------

local function updateFactoryList()
	facs = {}
	local count = 0

	local teamUnits = Spring.GetTeamUnits(myTeamID)
	for num = 1, #teamUnits do
		local unitID = teamUnits[num]
		local unitDefID = GetUnitDefID(unitID)
		if unitBuildOptions[unitDefID] then
			count = count + 1
			facs[count] = { unitID = unitID, unitDefID = unitDefID, buildList = unitBuildOptions[unitDefID] }
			if GetUnitIsBeingBuilt(unitID) then
				unfinished_facs[unitID] = true
			end
		end
	end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam)
	if unitTeam ~= myTeamID then
		return
	end

	if unitBuildOptions[unitDefID] then
		facs[#facs + 1] = { unitID = unitID, unitDefID = unitDefID, buildList = unitBuildOptions[unitDefID] }
	end
	unfinished_facs[unitID] = true
end

function widget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
	widget:UnitCreated(unitID, unitDefID, unitTeam)
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	if unitTeam ~= myTeamID then
		return
	end

	if unitBuildOptions[unitDefID] then
		for i, facInfo in ipairs(facs) do
			if unitID == facInfo.unitID then
				if openedMenu + 1 == i and openedMenu > #facs - 2 then
					openedMenu = openedMenu - 1
				end
				table.remove(facs, i)
				unfinished_facs[unitID] = nil
				return
			end
		end
	end
end

function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	widget:UnitDestroyed(unitID, unitDefID, unitTeam)
end

function widget:PlayerChanged()
	if Spring.GetSpectatingState() then
		widgetHandler:RemoveWidget()
	end
end

-------------------------------------------------------------------------------
-- INITIALIZTION FUNCTIONS
-------------------------------------------------------------------------------

function widget:Initialize()
	if WG['buildmenu'] then
		if WG['buildmenu'].getGroups then
			groups, unitGroup = WG['buildmenu'].getGroups()
		end
		if WG['buildmenu'].getOrder then
			unitOrder = WG['buildmenu'].getOrder()

			-- order buildoptions
			for uDefID, def in pairs(unitBuildOptions) do
				local temp = {}
				for i, udid in pairs(def) do
					temp[udid] = i
				end
				local newBuildOptions = {}
				local newBuildOptionsCount = 0
				for k, orderUDefID in pairs(unitOrder) do
					if temp[orderUDefID] then
						newBuildOptionsCount = newBuildOptionsCount + 1
						newBuildOptions[newBuildOptionsCount] = orderUDefID
					end
				end
				unitBuildOptions[uDefID] = newBuildOptions
			end
		end
	end

	widget:ViewResize()

	myTeamID = Spring.GetMyTeamID()

	updateFactoryList()

	if Spring.GetGameFrame() > 0 and Spring.GetSpectatingState() then
		widgetHandler:RemoveWidget()
	end
end

function widget:GameStart()
	if Spring.GetSpectatingState() then
		widgetHandler:RemoveWidget()
	end
end

function widget:Shutdown()
	for i = 1, #dlists do
		gl.DeleteList(dlists[i])
	end
	dlists = {}
	if WG['guishader'] then
		WG['guishader'].RemoveDlist('buildbar')
		WG['guishader'].RemoveDlist('buildbar2')
		if dlistGuishader then
			dlistGuishader = gl.DeleteList(dlistGuishader)
		end
		if dlistGuishader2 then
			dlistGuishader2 = gl.DeleteList(dlistGuishader2)
		end
	end
end

function widget:GetConfigData()
	return {
		side = bar_side,
		offset = bar_offset,
		align = bar_align,
	}
end

function widget:SetConfigData(data)
	bar_side = data.side or 2
	bar_offset = data.offset or 0
	bar_align = data.align or 0
	bar_side = math.clamp(bar_side, 0, 3)
	bar_align = math.clamp(bar_align, -1, 1)
end

-------------------------------------------------------------------------------
-- RECTANGLE FUNCTIONS
-------------------------------------------------------------------------------

local function offsetRect(rect, x_offset, y_offset)
	rect[3], rect[1] = rect[3] + x_offset, rect[1] + x_offset
	rect[2], rect[4] = rect[2] + y_offset, rect[4] + y_offset
end

local function rectWH(left, top, width, height)
	local rect = { left, top }
	rect[3] = rect[1] + width
	rect[4] = rect[2] - height
	return rect
end

local function getFacIconRect(i)
	local xmin = facRect[1] + i * fac_inext[1]
	local ymax = facRect[2] + i * fac_inext[2]
	return xmin, ymax, xmin + iconSizeX, ymax - iconSizeY
end

local function isInRect(left, top, rect)
	return left >= rect[1] and left <= rect[3] and top <= rect[2] and top >= rect[4]
end

-------------------------------------------------------------------------------
-- DRAW FUNCTIONS
-------------------------------------------------------------------------------

local function drawTexRect(rect, texture, color)
	if color ~= nil then
		glColor(color)
	else
		glColor(1, 1, 1, 1)
	end
	glTexture(texture)
	glTexRect(rect[1], rect[4], rect[3], rect[2])
	glColor(1, 1, 1, 1)
	glTexture(false)
end

local function drawIcon(udid, rect, tex, color, zoom, isfactory, amount)
	glColor(1,1,1,1)
	UiUnit(
		rect[1], rect[2], rect[3], rect[4],
		cornerSize,
		1,1,1,1,
		zoom,
		nil, nil,
		tex,
		(not isfactory and unitIcon[udid] or nil),
		groups[unitGroup[udid]],
		nil,
		amount
	)
end

local function drawOptionsBackground()
	local addDist = math_floor(bgpadding*0.5)
	backgroundOptionsRect = {boptRect[1]-addDist, boptRect[4]-addDist, boptRect[3] - math.floor(bgpadding/2), boptRect[2]+addDist}
	UiElement(backgroundOptionsRect[1],backgroundOptionsRect[2],backgroundOptionsRect[3],backgroundOptionsRect[4], 1,1,1,1)
end

local function drawBackground()
	local addDist = math_floor(bgpadding*0.5)
	backgroundRect = {factoriesArea[1]-addDist, factoriesArea[4]-addDist, factoriesArea[3], factoriesArea[2]+addDist}
	UiElement(backgroundRect[1],backgroundRect[2],backgroundRect[3],backgroundRect[4], 1,0,0,1)
end

local function drawButton(rect, unitDefID, options, isFac)	-- options = {pressed,hovered,selected,repeat,hovered_repeat,progress,amount,alpha}
	cornerSize = (rect[3] - rect[1]) * 0.03

	-- hover or pressed?
	local zoom = 0.04
	local hoverPadding = bgpadding*0.5
	local iconAlpha = (options.alpha or 1)
	if options.pressed then
		iconAlpha = 1
		zoom = 0.17
	elseif options.hovered then
		iconAlpha = 1
		zoom = 0.12
		if WG.tooltip then
			WG.tooltip.ShowTooltip('buildbar', UnitDefs[unitDefID].translatedTooltip, nil, nil, UnitDefs[unitDefID].translatedHumanName)
		end
	end

	-- draw icon
	local imgRect = { rect[1] + (hoverPadding*1), rect[2] - hoverPadding, rect[3] - (hoverPadding*1), rect[4] + hoverPadding }
	drawIcon(unitDefID, {imgRect[1], imgRect[4], imgRect[3], imgRect[2]}, '#' ..unitDefID , {1, 1, 1, iconAlpha}, zoom, (unitBuildOptions[unitDefID]~=nil), options.amount or 0)

	-- Progress
	if (options.progress and options.progress < 1) then
		glBlending(GL_SRC_ALPHA, GL_ONE)
		RectRoundProgress(imgRect[1], imgRect[4], imgRect[3], imgRect[2], cornerSize, options.progress, { 1, 1, 1, 0.22 })
		glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	end

	-- loop status?
	if options['repeat'] then
		local color = { 1, 1, 1, 0.8 }
		if options.hovered_repeat then
			color = { 1, 1, 1, 0.65 }
		end
		glTexture(repeatPic)
		glColor(1, 1, 1, 0.65)
		drawTexRect({imgRect[3]-repIcoSize-4,imgRect[2]-4,imgRect[3]-4,imgRect[2]-repIcoSize-4}, repeatPic, color)
	elseif isFac then
		local color = { 1, 1, 1, 0.35 }
		if options.hovered_repeat then
			color = { 1, 1, 1, 0.5 }
		end
		glTexture(repeatPic)
		glColor(1, 1, 1, 0.5)
		drawTexRect({imgRect[3]-repIcoSize-4,imgRect[2]-4,imgRect[3]-4,imgRect[2]-repIcoSize-4}, repeatPic, color)
	end

	-- amount
	if (options.amount or 0) > 0 then
		font:Begin()
		font:Print(options.amount, rect[1] + ((rect[3] - rect[1]) * 0.22), rect[4] - ((rect[4] - rect[2]) * 0.22), fontSize, "o")
		font:End()
	end
	glTexture(false)
	glColor(1,1,1,1)
end



local function mouseOverIcon(x, y)
	if x >= facRect[1] and x <= facRect[3] and y >= facRect[4] and y <= facRect[2] then
		local icon
		if bar_horizontal then
			icon = math.floor((x - facRect[1]) / fac_inext[1])
		else
			icon = math.floor((y - facRect[2]) / fac_inext[2])
		end

		if icon >= #facs then
			icon = (#facs - 1)
		elseif icon < 0 then
			icon = 0
		end

		return icon
	end
	return -1
end

local function mouseOverSubIcon(x, y)
	if openedMenu >= 0 and x >= boptRect[1] and x <= boptRect[3] and y >= boptRect[4] and y <= boptRect[2] then
		local icon
		if bar_side == 0 then
			icon = math.floor((x - boptRect[1]) / bopt_inext[1])
		elseif bar_side == 2 then
			icon = math.floor((y - boptRect[2]) / bopt_inext[2])
		elseif bar_side == 1 then
			icon = math.floor((x - boptRect[3]) / bopt_inext[1])
		else
			--bar_side==3
			icon = math.floor((y - boptRect[4]) / bopt_inext[2])
		end

		if facs[openedMenu + 1] and icon > #facs[openedMenu + 1].buildList - 1 then
			icon = #facs[openedMenu + 1].buildList - 1
		elseif icon < 0 then
			icon = 0
		end
		return icon
	end
	return -1
end

local sec = 0
function widget:Update(dt)

	if Spring.GetGameFrame() > 0 and Spring.GetSpectatingState() then
		widgetHandler:RemoveWidget()
	end
	if myTeamID ~= Spring.GetMyTeamID() then
		myTeamID = Spring.GetMyTeamID()
		updateFactoryList()
	end
	if WG['topbar'] and WG['topbar'].showingQuit() then
		openedMenu = -1
		return false
	end

	local mx, my, lb, mb, rb, moffscreen = GetMouseState()
	if ((lb or mb or rb) and openedMenu == -1) then
		return false
	end

	hoveredFac = mouseOverIcon(mx, my)
	hoveredBOpt = mouseOverSubIcon(mx, my)
	-- set hover unitdef id for buildmenu so info widget can show it
	if WG['info'] then
		if hoveredFac >= 0 then
			if(not setInfoDisplayUnitID or (hoveredBOpt < 0 and setInfoDisplayUnitID ~= facs[hoveredFac + 1].unitID))then
				Spring.PlaySoundFile(sound_hover, 0.8, 'ui')
				setInfoDisplayUnitID = facs[hoveredFac + 1].unitID
				WG['info'].displayUnitID(setInfoDisplayUnitID)
			end
		elseif hoveredBOpt >= 0 then
			if(setInfoDisplayUnitID and setInfoDisplayUnitDefID ~= facs[openedMenu + 1].buildList[hoveredBOpt + 1])then
				Spring.PlaySoundFile(sound_hover, 0.8, 'ui')
				setInfoDisplayUnitDefID = facs[openedMenu + 1].buildList[hoveredBOpt + 1]
				WG['info'].displayUnitDefID(setInfoDisplayUnitDefID)
			end
		else
			if setInfoDisplayUnitID then
				setInfoDisplayUnitID = nil
				WG['info'].clearDisplayUnitID()
			end
			if setInfoDisplayUnitDefID then
				setInfoDisplayUnitDefID = nil
				WG['info'].clearDisplayUnitDefID()
			end
		end
	end

	if hoveredFac >= 0 then
		--factory icon
		if not moffscreen then
			openedMenu = hoveredFac
		end
	elseif not (openedMenu >= 0 and isInRect(mx, my, boptRect)) then
		openedMenu = -1
	end

	sec = sec + dt
	local doupdate = false
	if sec > 0.1 then
		doupdate = true
	end
	if factoriesArea ~= nil then
		if not moffscreen then
			if isInRect(mx, my, { factoriesArea[1], factoriesArea[2], factoriesArea[3], factoriesArea[4] }) then
				doupdate = true
				factoriesAreaHovered = true
			elseif factoriesAreaHovered then
				factoriesAreaHovered = nil
				doupdate = true
			end
		end
	end

	if doupdate then
		sec = 0
		setupDimensions(#facs)
		setupSubDimensions()
		for i = 1, #dlists do
			gl.DeleteList(dlists[i])
		end
		dlists = {}
		local dlistsCount = 1
		factoriesArea = nil

		-- draw factory list
		local fac_rec = rectWH(math_floor(facRect[1]), math_floor(facRect[2]), iconSizeX, iconSizeY)
		for i, facInfo in ipairs(facs) do

			local unitDefID = facInfo.unitDefID
			local options = {}

			local unitBuildDefID = -1
			local unitBuildID = -1

			-- determine options -------------------------------------------------------------------
			-- building?
			unitBuildID = GetUnitIsBuilding(facInfo.unitID)
			if unitBuildID then
				unitBuildDefID = GetUnitDefID(unitBuildID)
				local _, progress = GetUnitIsBeingBuilt(unitBuildID)
				options.progress = progress
				unitDefID = unitBuildDefID
			elseif (unfinished_facs[facInfo.unitID]) then
				local isBeingBuilt, progress = GetUnitIsBeingBuilt(facInfo.unitID)
				options.progress = progress
				if not isBeingBuilt then
					unfinished_facs[facInfo.unitID] = nil
				end
			end
			-- repeat mode?
			if select(4, GetUnitStates(facInfo.unitID, false, true)) then
				options['repeat'] = true
			else
				options['repeat'] = false
			end
			-- hover or pressed?
			if not moffscreen and i == hoveredFac + 1 then
				options.hovered_repeat = isInRect(mx, my, { fac_rec[3] - repIcoSize, fac_rec[2], fac_rec[3], fac_rec[2] - repIcoSize })
				options.pressed = (lb or mb or rb) or (options.hovered_repeat)
				options.hovered = true
			end
			-- border
			options.selected = (i == hoveredFac + 1)

			dlistsCount = dlistsCount + 1
			dlists[dlistsCount] = gl.CreateList(drawButton, fac_rec, unitDefID, options, true)
			if factoriesArea == nil then
				factoriesArea = { fac_rec[1], fac_rec[2], fac_rec[3], fac_rec[4] }
			else
				factoriesArea[4] = fac_rec[4]
			end

			-- setup next icon pos
			offsetRect(fac_rec, fac_inext[1], fac_inext[2])
		end

		if factoriesArea then
			dlists[1] = gl.CreateList(drawBackground)
			if WG['guishader'] then
				if hoveredFac >= 0 then
					dlists[dlistsCount+1] = gl.CreateList(drawOptionsBackground)

					if dlistGuishader2 then
						dlistGuishader2 = gl.DeleteList(dlistGuishader2)
					end
					dlistGuishader2 = gl.CreateList( function()
						RectRound(backgroundOptionsRect[1],backgroundOptionsRect[2],backgroundOptionsRect[3],backgroundOptionsRect[4], elementCorner * ui_scale)
					end)

					if dlistGuishader2 then
						WG['guishader'].RemoveDlist('buildbar2')
						WG['guishader'].InsertDlist(dlistGuishader2, 'buildbar2')
					end
				else
					backgroundOptionsRect = nil
					WG['guishader'].RemoveDlist('buildbar2')
				end
			end
		end

		checkGuishader(forceGuishader)
		forceGuishader = nil
	end
end

-------------------------------------------------------------------------------
-- UNIT FUNCTIONS
-------------------------------------------------------------------------------

local function getBuildQueue(unitID)
	local result = {}
	local queue = GetFullBuildQueue(unitID)
	if queue ~= nil then
		for _, buildPair in ipairs(queue) do
			local udef, count = next(buildPair, nil)
			if result[udef] ~= nil then
				result[udef] = result[udef] + count
			else
				result[udef] = count
			end
		end
	end
	return result
end

-------------------------------------------------------------------------------
-- DRAWSCREEN
-------------------------------------------------------------------------------



function widget:DrawScreen()

	local mx, my, lb, mb, rb, moffscreen = GetMouseState()

	if WG['guishader'] then
		if #dlists == 0 then
			if dlistGuishader then
				WG['guishader'].RemoveDlist('buildbar')
			end
		else
			if dlistGuishader then
				WG['guishader'].InsertDlist(dlistGuishader, 'buildbar')
			end
		end
	end

	for i = 1, #dlists do
		gl.CallList(dlists[i])
	end

	-- draw factory list
	if (factoriesArea ~= nil and isInRect(mx, my, { factoriesArea[1], factoriesArea[2], factoriesArea[3], factoriesArea[4] })) or
		(buildoptionsArea ~= nil and isInRect(mx, my, { buildoptionsArea[1], buildoptionsArea[2], buildoptionsArea[3], buildoptionsArea[4] })) then
		local fac_rec = rectWH(math_floor(facRect[1]), math_floor(facRect[2]), iconSizeX, iconSizeY)
		buildoptionsArea = nil

		for i, facInfo in ipairs(facs) do
			-- draw build list
			if i == openedMenu + 1 then
				-- draw buildoptions
				local bopt_rec = rectWH(fac_rec[1] + bopt_inext[1],fac_rec[2] + bopt_inext[2], iconSizeX, iconSizeY)

				local buildList = facInfo.buildList
				local buildQueue = getBuildQueue(facInfo.unitID)
				local unitBuildID = GetUnitIsBuilding(facInfo.unitID)
				local unitBuildDefID
				if unitBuildID then
					unitBuildDefID = GetUnitDefID(unitBuildID)
				end
				for j, unitDefID in ipairs(buildList) do
					local unitDefID = unitDefID
					local options = {}
					-- determine options -------------------------------------------------------------------
					-- building?

					if unitDefID == unitBuildDefID then
						local _, progress = GetUnitIsBeingBuilt(unitBuildID)
						options.progress = progress
					end
					-- amount
					options.amount = buildQueue[unitDefID]
					-- hover or pressed?
					if not moffscreen and j == hoveredBOpt + 1 then
						options.pressed = (lb or mb or rb)
						options.hovered = true
					end
					options.alpha = 0.85

					drawButton(bopt_rec, unitDefID, options)
					if buildoptionsArea == nil then
						buildoptionsArea = { bopt_rec[1], bopt_rec[2], bopt_rec[3], bopt_rec[4] }
					else
						buildoptionsArea[1] = bopt_rec[1]
					end
					-- setup next icon pos
					offsetRect(bopt_rec, bopt_inext[1], bopt_inext[2])
				end
			else
				-- draw buildqueue
				local buildQueue = Spring.GetFullBuildQueue(facInfo.unitID, maxVisibleBuilds + 1)
				if buildQueue ~= nil then
					local bopt_rec = rectWH(fac_rec[1] + bopt_inext[1], fac_rec[2] + bopt_inext[2], iconSizeX, iconSizeY)

					local n, j = 1, maxVisibleBuilds
					while buildQueue[n] do
						local unitBuildDefID, count = next(buildQueue[n], nil)
						if n == 1 then
							count = count - 1
						end -- cause we show the actual in building unit instead of the factory icon

						if count > 0 then
							local yPad = math_floor(iconSizeY * 0.88)
							local xPad = yPad
							local zoom = 0.04
							drawIcon(unitBuildDefID, {bopt_rec[3] - xPad, bopt_rec[2] - yPad, bopt_rec[1] + xPad, bopt_rec[4] + yPad}, "#" .. unitBuildDefID, {1, 1, 1, 0.5}, zoom)
							if count > 1 then
								font:Begin()
								font:SetTextColor(1, 1, 1, 0.66)
								font:Print(count, bopt_rec[1] + ((bopt_rec[3] - bopt_rec[1]) * 0.22), bopt_rec[4] - ((bopt_rec[4] - bopt_rec[2]) * 0.22), fontSize, "o")
								font:End()
							end

							offsetRect(bopt_rec, bopt_inext[1], bopt_inext[2])
							j = j - 1
							if j == 0 then
								break
							end
						end
						n = n + 1
					end
				end
			end

			-- setup next icon pos
			offsetRect(fac_rec, fac_inext[1], fac_inext[2])
		end
	else
		buildoptionsArea = nil
	end
end

function widget:DrawWorld()

	-- Draw factories command lines
	if openedMenu >= 0 then
		local fac = facs[openedMenu + 1]

		if fac ~= nil then
			DrawUnitCommands(fac.unitID)
		end
	end
end

function widget:DrawInMiniMap(sx, sy)
	if openedMenu > -1 then
		gl.PushMatrix()
		local pt = math.min(sx, sy)

		gl.LoadIdentity()

		local currRot = getCurrentMiniMapRotationOption()
		if currRot == ROTATION.DEG_0 then
			gl.Translate(0, 1, 0)
			gl.Scale(1 / msx, -1 / msz, 1)
		elseif currRot == ROTATION.DEG_90 then
			gl.Scale(-1 / msz, 1 / msx, 1)
			gl.Rotate(90, 0, 0, 1)
		elseif currRot == ROTATION.DEG_180 then
			gl.Translate(1, 0, 0)
			gl.Scale(1 / msx, 1 / msz, 1)
			gl.Rotate(180, 0, 1, 0)
		elseif currRot == ROTATION.DEG_270 then
			gl.Translate(1, 1, 0)
			gl.Scale(-1 / msz, 1 / msx, 1)
			gl.Rotate(-90, 0, 0, 1)
		end

		local r, g, b
		if anonymousMode ~= "disabled" then
			r, g, b = anonymousTeamColor[1], anonymousTeamColor[2], anonymousTeamColor[3]
		else
			r, g, b = Spring.GetTeamColor(myTeamID)
		end
		local alpha = 0.5 + math.abs((Spring.GetGameSeconds() % 0.25) * 4 - 0.5)
		local x, _, z = Spring.GetUnitBasePosition(facs[openedMenu + 1].unitID)

		if x ~= nil then
			gl.PointSize(pt * 0.066)
			gl.Color(0, 0, 0)
			gl.BeginEnd(GL.POINTS, function()
				gl.Vertex(x, z)
			end)
			gl.PointSize(pt * 0.051)
			gl.Color(r, g, b, alpha)
			gl.BeginEnd(GL.POINTS, function()
				gl.Vertex(x, z)
			end)
			gl.PointSize(1)
			gl.Color(1, 1, 1, 1)
		end
		gl.PopMatrix()
	end
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local function menuHandler(x, y, button)
	local factoryUnitID = facs[pressedFac + 1].unitID

	if button == 1 then
		local icoRect = {}
		_, icoRect[2], icoRect[3], _ = getFacIconRect(pressedFac)
		icoRect[1], icoRect[4] = icoRect[3] - repIcoSize, icoRect[2] - repIcoSize
		if isInRect(x, y, icoRect) then
			--repeat icon clicked
			local onoff = { 1 }
			if select(4, GetUnitStates(factoryUnitID, false, true)) then
				onoff = { 0 }
			end
			Spring.GiveOrderToUnit(factoryUnitID, CMD.REPEAT, onoff, 0)
			Spring.PlaySoundFile(sound_click, 0.8, 'ui')
		else
			Spring.SelectUnitArray({ factoryUnitID })
		end
	elseif button == 3 then
		Spring.SelectUnitArray({ factoryUnitID })
		Spring.SetCameraTarget( Spring.GetUnitPosition(factoryUnitID) )
	end

	return
end

local function buildHandler(button)
	local alt, ctrl, meta, shift = Spring.GetModKeyState()
	local opt = {}
	if alt then
		opt[#opt + 1] = "alt"
	end
	if ctrl then
		opt[#opt + 1] = "ctrl"
	end
	if meta then
		opt[#opt + 1] = "meta"
	end
	if shift then
		opt[#opt + 1] = "shift"
	end

	if button == 1 then
		Spring.GiveOrderToUnit(facs[openedMenu + 1].unitID, -(facs[openedMenu + 1].buildList[pressedBOpt + 1]), {}, opt)
		Spring.PlaySoundFile(sound_queue_add, 0.75, 'ui')
	elseif button == 3 then
		opt[#opt + 1] = "right"
		Spring.GiveOrderToUnit(facs[openedMenu + 1].unitID, -(facs[openedMenu + 1].buildList[pressedBOpt + 1]), {}, opt)
		Spring.PlaySoundFile(sound_queue_rem, 0.75, 'ui')
	end
end

-------------------------------------------------------------------------------
-- MOUSE PRESS FUNCTIONS
-------------------------------------------------------------------------------

function widget:MousePress(x, y, button)
	pressedFac = hoveredFac
	pressedBOpt = hoveredBOpt

	if hoveredFac + hoveredBOpt < -1 then
		if button ~= 2 then
			openedMenu = -1
		end

		return false
	end

	return true
end

function widget:MouseRelease(x, y, button)
	if pressedFac == hoveredFac and pressedBOpt == hoveredBOpt then
		if hoveredFac >= 0 then
			menuHandler(x, y, button)
		else
			buildHandler(button)
		end
	end

	return -1
end
