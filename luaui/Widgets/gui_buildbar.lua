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
local useRenderToTexture = false  -- Disabled for now due to issues

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
local buildOptionsDlist = nil  -- Display list for build options menu
local lastBuildOptionsMenu = -1  -- Track which factory's menu we cached
local lastBuildQueue = {}  -- Track build queue state to detect changes
local lastGuishaderMenu = -1  -- Track which menu guishader was created for

-- render-to-texture state
local factoryTex, buildOptionsTex
local updateFactoryTex = true
local updateBuildOptionsTex = true
local lastHoveredFac = -1
local lastOpenedMenu = -1

-- Track what each factory is building to detect changes
local factoryBuildingUnit = {}  -- factoryUnitID -> unitDefID being built
local factoryListChanged = true  -- Flag to trigger display list rebuild

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
local math_ceil = math.ceil
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
	repIcoSize = math.floor(iconSizeY * 0.4)

	-- Invalidate textures on resize
	if factoryTex then
		gl.DeleteTexture(factoryTex)
		factoryTex = nil
	end
	if buildOptionsTex then
		gl.DeleteTexture(buildOptionsTex)
		buildOptionsTex = nil
	end
	updateFactoryTex = true
	updateBuildOptionsTex = true

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
	factoryListChanged = true
end

function widget:UnitCreated(unitID, unitDefID, unitTeam)
	if unitTeam ~= myTeamID then
		return
	end

	if unitBuildOptions[unitDefID] then
		facs[#facs + 1] = { unitID = unitID, unitDefID = unitDefID, buildList = unitBuildOptions[unitDefID] }
		factoryListChanged = true
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
				factoryListChanged = true
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
	
	-- Clean up render-to-texture resources
	if factoryTex then
		gl.DeleteTexture(factoryTex)
		factoryTex = nil
	end
	if buildOptionsTex then
		gl.DeleteTexture(buildOptionsTex)
		buildOptionsTex = nil
	end
	
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
	drawIcon(unitDefID, {imgRect[1], imgRect[4], imgRect[3], imgRect[2]}, '#' ..unitDefID , {1, 1, 1, iconAlpha}, zoom, (unitBuildOptions[unitDefID]~=nil), options.amount)

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

	-- amount is now handled by UiUnit internally with proper background
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
	elseif not (openedMenu >= 0 and (isInRect(mx, my, boptRect) or (buildoptionsArea and isInRect(mx, my, buildoptionsArea)))) then
		openedMenu = -1
	end

	sec = sec + dt
	local doupdate = false
	
	-- Check if factory list changed (factories created/destroyed)
	if factoryListChanged then
		factoryListChanged = false
		doupdate = true
		updateFactoryTex = true
	end
	
	-- Check if hover state changed
	if hoveredFac ~= lastHoveredFac or openedMenu ~= lastOpenedMenu then
		doupdate = true
		lastHoveredFac = hoveredFac
		lastOpenedMenu = openedMenu
		updateFactoryTex = true
		if openedMenu ~= lastOpenedMenu then
			updateBuildOptionsTex = true
		end
	end
	
	-- Only check for building unit changes less frequently to save performance
	if sec > 0.5 then
		sec = 0
		
		-- Check if any factory changed what it's building
		local buildingChanged = false
		for i, facInfo in ipairs(facs) do
			local unitBuildID = GetUnitIsBuilding(facInfo.unitID)
			local currentBuildDefID = nil
			if unitBuildID then
				currentBuildDefID = GetUnitDefID(unitBuildID)
			end
			
			-- Compare with previously tracked value
			if factoryBuildingUnit[facInfo.unitID] ~= currentBuildDefID then
				factoryBuildingUnit[facInfo.unitID] = currentBuildDefID
				buildingChanged = true
			end
		end
		
		if buildingChanged then
			doupdate = true
			updateFactoryTex = true
		end
	end
	
	if factoriesArea ~= nil then
		if not moffscreen then
			if isInRect(mx, my, { factoriesArea[1], factoriesArea[2], factoriesArea[3], factoriesArea[4] }) then
				if not factoriesAreaHovered then
					factoriesAreaHovered = true
					doupdate = true
					updateFactoryTex = true
				end
			elseif factoriesAreaHovered then
				factoriesAreaHovered = nil
				doupdate = true
				updateFactoryTex = true
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
		
		-- If no factories, just clear and return
		if #facs == 0 then
			factoriesArea = nil
			return
		end
		
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
			-- Check if building something - show the unit being built
			unitBuildID = GetUnitIsBuilding(facInfo.unitID)
			if unitBuildID then
				unitBuildDefID = GetUnitDefID(unitBuildID)
				-- Show the unit being built instead of factory icon
				unitDefID = unitBuildDefID
				-- Progress will be drawn separately every frame
			elseif (unfinished_facs[facInfo.unitID]) then
				local isBeingBuilt, progress = GetUnitIsBeingBuilt(facInfo.unitID)
				-- Keep showing factory icon when it's being built
				-- Progress for unfinished factory will be drawn separately
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

local function renderFactoryList()
	-- Render factory icons and background from display lists
	if #dlists > 0 then
		for i = 1, #dlists do
			gl.CallList(dlists[i])
		end
	end
end

local function renderFactoryProgressOverlays()
	-- Draw progress overlays on top (needs to update every frame)
	if factoriesArea and #facs > 0 then
		local fac_rec = rectWH(math_floor(facRect[1]), math_floor(facRect[2]), iconSizeX, iconSizeY)
		local hoverPadding = bgpadding*0.5
		local cornerSize = (fac_rec[3] - fac_rec[1]) * 0.03
		
		for i, facInfo in ipairs(facs) do
			local progress = nil
			local unitBuildID = GetUnitIsBuilding(facInfo.unitID)
			
			if unitBuildID then
				-- Factory is building a unit
				local _, prog = GetUnitIsBeingBuilt(unitBuildID)
				if prog then
					progress = prog
				end
			elseif unfinished_facs[facInfo.unitID] then
				-- Factory itself is being built
				local isBeingBuilt, prog = GetUnitIsBeingBuilt(facInfo.unitID)
				if isBeingBuilt and prog then
					progress = prog
				end
			end
			
			-- Draw progress overlay if building (always draw if we have progress, even if it's 1.0 briefly)
			if progress then
				local imgRect = { fac_rec[1] + (hoverPadding*1), fac_rec[2] - hoverPadding, fac_rec[3] - (hoverPadding*1), fac_rec[4] + hoverPadding }
				-- Use normal alpha blending to avoid brightening the icon
				RectRoundProgress(imgRect[1], imgRect[4], imgRect[3], imgRect[2], cornerSize, progress, { 1, 1, 1, 0.6 })
			end
			
			-- setup next icon pos
			offsetRect(fac_rec, fac_inext[1], fac_inext[2])
		end
	end
end

local function renderBuildOptions(mx, my, lb, mb, rb, moffscreen)
	-- Render build options menu when hovering a factory
	if not factoriesArea then
		return
	end
	
	-- Check if we should draw build options at all
	-- Draw if: hovering factory area, hovering build options area, OR a menu is opened
	local shouldDraw = isInRect(mx, my, { factoriesArea[1], factoriesArea[2], factoriesArea[3], factoriesArea[4] })
	if not shouldDraw and buildoptionsArea then
		shouldDraw = isInRect(mx, my, { buildoptionsArea[1], buildoptionsArea[2], buildoptionsArea[3], buildoptionsArea[4] })
	end
	if not shouldDraw and openedMenu >= 0 then
		-- Keep menu visible even if mouse temporarily outside (until Update closes it)
		shouldDraw = true
	end
	
	if not shouldDraw then
		buildoptionsArea = nil
		if buildOptionsDlist then
			gl.DeleteList(buildOptionsDlist)
			buildOptionsDlist = nil
			lastBuildOptionsMenu = -1
		end
		return
	end
	
	-- Recalculate which build option is hovered (needs to be every frame)
	local hoveredBOptNow = mouseOverSubIcon(mx, my)
	
	-- Check if we need to rebuild the build options display list
	local needsRebuild = (openedMenu ~= lastBuildOptionsMenu)
	
	-- Check if build queue changed (need to rebuild for queue numbers and progress)
	if not needsRebuild and openedMenu >= 0 then
		local facInfo = facs[openedMenu + 1]
		if facInfo then
			local buildQueue = getBuildQueue(facInfo.unitID)
			local unitBuildID = GetUnitIsBuilding(facInfo.unitID)
			local unitBuildDefID
			if unitBuildID then
				unitBuildDefID = GetUnitDefID(unitBuildID)
			end
			
			-- Check if the build queue changed
			local queueChanged = false
			if lastBuildQueue[facInfo.unitID] then
				-- Compare build queue
				for unitDefID, count in pairs(buildQueue) do
					if lastBuildQueue[facInfo.unitID][unitDefID] ~= count then
						queueChanged = true
						break
					end
				end
				-- Check if any units were removed from queue
				if not queueChanged then
					for unitDefID, count in pairs(lastBuildQueue[facInfo.unitID]) do
						if buildQueue[unitDefID] ~= count then
							queueChanged = true
							break
						end
					end
				end
			else
				queueChanged = true
			end
			
			-- Check if what's being built changed (for progress bar)
			if factoryBuildingUnit[facInfo.unitID] ~= unitBuildDefID then
				queueChanged = true
			end
			
			if queueChanged then
				needsRebuild = true
			end
		end
	end
	
	if needsRebuild then
		-- Rebuild display list for new menu
		if buildOptionsDlist then
			gl.DeleteList(buildOptionsDlist)
		end
		lastBuildOptionsMenu = openedMenu
		
		local fac_rec = rectWH(math_floor(facRect[1]), math_floor(facRect[2]), iconSizeX, iconSizeY)
		
		-- Calculate buildoptionsArea outside display list so it's accessible
		buildoptionsArea = nil
		for i, facInfo in ipairs(facs) do
			if i == openedMenu + 1 then
				local bopt_rec = rectWH(fac_rec[1] + bopt_inext[1], fac_rec[2] + bopt_inext[2], iconSizeX, iconSizeY)
				local buildList = facInfo.buildList
				for j = 1, #buildList do
					if buildoptionsArea == nil then
						buildoptionsArea = { bopt_rec[1], bopt_rec[2], bopt_rec[3], bopt_rec[4] }
					else
						buildoptionsArea[1] = bopt_rec[1]  -- Update left edge to extend menu area
					end
					offsetRect(bopt_rec, bopt_inext[1], bopt_inext[2])
				end
				break
			end
			offsetRect(fac_rec, fac_inext[1], fac_inext[2])
		end
		
		-- Reset position for display list
		fac_rec = rectWH(math_floor(facRect[1]), math_floor(facRect[2]), iconSizeX, iconSizeY)
		
		buildOptionsDlist = gl.CreateList(function()
			for i, facInfo in ipairs(facs) do
				-- draw build list
				if i == openedMenu + 1 then
					-- draw buildoptions
					local bopt_rec = rectWH(fac_rec[1] + bopt_inext[1],fac_rec[2] + bopt_inext[2], iconSizeX, iconSizeY)

					-- Draw background for build options first
					if boptRect then
						local addDist = math_floor(bgpadding*0.5)
						backgroundOptionsRect = {boptRect[1]-addDist, boptRect[4]-addDist, boptRect[3] - math.floor(bgpadding/2), boptRect[2]+addDist}
						UiElement(backgroundOptionsRect[1],backgroundOptionsRect[2],backgroundOptionsRect[3],backgroundOptionsRect[4], 1,1,1,1)
					end

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
						-- Don't include progress or amount in cached display list - they will be drawn separately
						-- No hover state in cached display list
						options.alpha = 0.85

						drawButton(bopt_rec, unitDefID, options)
						-- setup next icon pos
						offsetRect(bopt_rec, bopt_inext[1], bopt_inext[2])
					end
				end
				
				-- setup next icon pos
				offsetRect(fac_rec, fac_inext[1], fac_inext[2])
			end
		end)
		
		-- Save current build queue state and building unit for this factory
		if openedMenu >= 0 then
			local facInfo = facs[openedMenu + 1]
			if facInfo then
				local buildQueue = getBuildQueue(facInfo.unitID)
				-- Deep copy the build queue
				lastBuildQueue[facInfo.unitID] = {}
				for unitDefID, count in pairs(buildQueue) do
					lastBuildQueue[facInfo.unitID][unitDefID] = count
				end
				
				-- Save what unit is being built
				local unitBuildID = GetUnitIsBuilding(facInfo.unitID)
				if unitBuildID then
					factoryBuildingUnit[facInfo.unitID] = GetUnitDefID(unitBuildID)
				else
					factoryBuildingUnit[facInfo.unitID] = nil
				end
			end
		end
	end
	
	-- Draw cached display list
	if buildOptionsDlist then
		gl.CallList(buildOptionsDlist)
	end
	
	-- Draw progress overlays and queue amounts on top (updates every frame)
	if openedMenu >= 0 then
		local facInfo = facs[openedMenu + 1]
		if facInfo then
			local fac_rec = rectWH(math_floor(facRect[1]), math_floor(facRect[2]), iconSizeX, iconSizeY)
			-- Offset to correct factory
			offsetRect(fac_rec, fac_inext[1] * openedMenu, fac_inext[2] * openedMenu)
			
			local bopt_rec = rectWH(fac_rec[1] + bopt_inext[1], fac_rec[2] + bopt_inext[2], iconSizeX, iconSizeY)
			
			local unitBuildID = GetUnitIsBuilding(facInfo.unitID)
			local unitBuildDefID
			if unitBuildID then
				unitBuildDefID = GetUnitDefID(unitBuildID)
			end
			
			local buildQueue = getBuildQueue(facInfo.unitID)
			local buildList = facInfo.buildList
			
			-- First pass: Draw queue numbers
			for j, unitDefID in ipairs(buildList) do
				local queueAmount = buildQueue[unitDefID]
				if queueAmount and queueAmount > 0 then
					local hoverPadding = bgpadding*0.5
					local imgRect = { bopt_rec[1] + (hoverPadding*1), bopt_rec[2] - hoverPadding, bopt_rec[3] - (hoverPadding*1), bopt_rec[4] + hoverPadding }
					local cellInnerSize = imgRect[3] - imgRect[1]
					
					-- Draw queue number (matching buildmenu style, scaled 1.26x - which is 1.5 * 0.84)
					-- imgRect: [1]=left, [2]=top-padding (higher Y), [3]=right, [4]=bottom+padding (lower Y)
					-- So imgRect[2] is actually the top edge in screen coords
					local scaleMult = 1.26
					local pad = math_floor(cellInnerSize * 0.03 * scaleMult)
					local textWidth = math_floor(font:GetTextWidth(queueAmount .. '  ') * cellInnerSize * 0.285 * scaleMult)
					local pad2 = 0
					
					-- Pre-calculate pixel-aligned coordinates: floor left/bottom, ceil top/right for sharp edges
					local rectLeft = math_floor(imgRect[3] - textWidth - pad2)
					local rectTop = math_ceil(imgRect[2])
					local rectRight = math_ceil(imgRect[3])
					local rectHeight1 = math_floor(cellInnerSize * 0.365 * scaleMult)
					local rectHeight2 = math_floor(cellInnerSize * 0.15 * scaleMult)
					
					-- Main background (dark)
					RectRound(rectLeft, rectTop - rectHeight1, rectRight, rectTop, cornerSize * 3.3, 0, 0, 0, 1, { 0.15, 0.15, 0.15, 0.95 }, { 0.25, 0.25, 0.25, 0.95 })
					-- Top highlight
					RectRound(rectLeft, rectTop - rectHeight2, rectRight, rectTop, 0, 0, 0, 0, 0, { 1, 1, 1, 0 }, { 1, 1, 1, 0.05 })
					-- Inner border
					RectRound(rectLeft + pad, rectTop - rectHeight1 + pad, rectRight, rectTop, cornerSize * 2.6, 0, 0, 0, 1, { 0.7, 0.7, 0.7, 0.1 }, { 1, 1, 1, 0.1 })
					
					-- Text
					font:Begin()
					font:Print("\255\190\255\190" .. queueAmount,
						imgRect[1] + math_floor(cellInnerSize * 0.96) - pad2,
						imgRect[2] - math_floor(cellInnerSize * 0.265 * scaleMult) - pad2,
						cellInnerSize * 0.29 * scaleMult, "ro"
					)
					font:End()
					glColor(1, 1, 1, 1)
				end
				
				-- Move to next icon position
				offsetRect(bopt_rec, bopt_inext[1], bopt_inext[2])
			end
			
			-- Second pass: Draw progress overlays on top of queue numbers
			bopt_rec = rectWH(fac_rec[1] + bopt_inext[1], fac_rec[2] + bopt_inext[2], iconSizeX, iconSizeY)
			for j, unitDefID in ipairs(buildList) do
				-- Check if this unit is currently being built
				if unitDefID == unitBuildDefID and unitBuildID then
					local _, progress = GetUnitIsBeingBuilt(unitBuildID)
					if progress then
						local hoverPadding = bgpadding*0.5
						local imgRect = { bopt_rec[1] + (hoverPadding*1), bopt_rec[2] - hoverPadding, bopt_rec[3] - (hoverPadding*1), bopt_rec[4] + hoverPadding }
						local cornerSize = (bopt_rec[3] - bopt_rec[1]) * 0.03
						
						-- Draw progress overlay
						RectRoundProgress(imgRect[1], imgRect[4], imgRect[3], imgRect[2], cornerSize, progress, { 1, 1, 1, 0.6 })
					end
				end
				
				-- Move to next icon position
				offsetRect(bopt_rec, bopt_inext[1], bopt_inext[2])
			end
		end
	end
	
	-- Draw hover highlights on top (cheap overlay)
	if hoveredBOptNow >= 0 and openedMenu >= 0 then
		local facInfo = facs[openedMenu + 1]
		if facInfo then
			local fac_rec = rectWH(math_floor(facRect[1]), math_floor(facRect[2]), iconSizeX, iconSizeY)
			-- Offset to correct factory
			offsetRect(fac_rec, fac_inext[1] * openedMenu, fac_inext[2] * openedMenu)
			
			local bopt_rec = rectWH(fac_rec[1] + bopt_inext[1], fac_rec[2] + bopt_inext[2], iconSizeX, iconSizeY)
			-- Offset to hovered option
			offsetRect(bopt_rec, bopt_inext[1] * hoveredBOptNow, bopt_inext[2] * hoveredBOptNow)
			
			-- Draw hover highlight (just a subtle overlay)
			local hoverPadding = bgpadding*0.5
			local imgRect = { bopt_rec[1] + (hoverPadding*1), bopt_rec[2] - hoverPadding, bopt_rec[3] - (hoverPadding*1), bopt_rec[4] + hoverPadding }
			local cornerSize = (bopt_rec[3] - bopt_rec[1]) * 0.03
			
			-- Draw subtle highlight border
			glColor(1, 1, 1, 0.3)
			RectRound(imgRect[1], imgRect[4], imgRect[3], imgRect[2], cornerSize)
			glColor(1, 1, 1, 1)
			
			-- Set tooltip
			local unitDefID = facInfo.buildList[hoveredBOptNow + 1]
			if unitDefID and WG.tooltip then
				WG.tooltip.ShowTooltip('buildbar', UnitDefs[unitDefID].translatedTooltip, nil, nil, UnitDefs[unitDefID].translatedHumanName)
			end
		end
	end
	
	-- Set factory tooltip if hovering factory (not build option)
	if hoveredBOptNow < 0 and hoveredFac >= 0 then
		local facInfo = facs[hoveredFac + 1]
		if facInfo then
			local unitDefID = facInfo.unitDefID
			local unitBuildID = GetUnitIsBuilding(facInfo.unitID)
			if unitBuildID then
				unitDefID = GetUnitDefID(unitBuildID)
			end
			if unitDefID and WG.tooltip then
				WG.tooltip.ShowTooltip('buildbar', UnitDefs[unitDefID].translatedTooltip, nil, nil, UnitDefs[unitDefID].translatedHumanName)
			end
		end
	end
end

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

	-- Check if we have anything to draw
	if #dlists == 0 then
		return
	end

	-- Use render-to-texture for better performance
	if useRenderToTexture and factoriesArea and #dlists > 0 then
		-- Create/update factory texture if needed
		if updateFactoryTex then
			local width = math.abs(factoriesArea[3] - factoriesArea[1])
			local height = math.abs(factoriesArea[4] - factoriesArea[2])
			
			if not factoryTex and width > 0 and height > 0 then
				factoryTex = gl.CreateTexture(math_floor(width), math_floor(height), {
					target = GL.TEXTURE_2D,
					format = GL.RGBA,
					fbo = true,
				})
			end
			
			if factoryTex then
				gl.R2tHelper.RenderToTexture(factoryTex,
					function()
						gl.Translate(-1, -1, 0)
						gl.Scale(2 / math.abs(factoriesArea[3] - factoriesArea[1]), 2 / math.abs(factoriesArea[4] - factoriesArea[2]), 0)
						gl.Translate(-factoriesArea[1], -factoriesArea[2], 0)
						renderFactoryList()
					end,
					useRenderToTexture
				)
				updateFactoryTex = false
			end
		end
		
		-- Draw factory texture
		if factoryTex then
			gl.R2tHelper.BlendTexRect(factoryTex, factoriesArea[1], factoriesArea[2], factoriesArea[3], factoriesArea[4], useRenderToTexture)
		end
		
		-- Draw build options (not cached since it changes often with mouse hover)
		if (isInRect(mx, my, { factoriesArea[1], factoriesArea[2], factoriesArea[3], factoriesArea[4] })) or
			(buildoptionsArea ~= nil and isInRect(mx, my, { buildoptionsArea[1], buildoptionsArea[2], buildoptionsArea[3], buildoptionsArea[4] })) then
			renderBuildOptions(mx, my, lb, mb, rb, moffscreen)
		else
			buildoptionsArea = nil
		end
	else
		-- Fallback to display lists (when R2T disabled or not ready yet)
		-- Draw display lists (factory icons and background)
		renderFactoryList()
		
		-- Draw progress overlays on top (updates every frame)
		renderFactoryProgressOverlays()

		-- draw build options menu
		if (factoriesArea ~= nil and isInRect(mx, my, { factoriesArea[1], factoriesArea[2], factoriesArea[3], factoriesArea[4] })) or
			(buildoptionsArea ~= nil and isInRect(mx, my, { buildoptionsArea[1], buildoptionsArea[2], buildoptionsArea[3], buildoptionsArea[4] })) or
			(openedMenu >= 0) then
			renderBuildOptions(mx, my, lb, mb, rb, moffscreen)
			
			-- Update guishader for build options background only when menu changes
			if WG['guishader'] and backgroundOptionsRect and openedMenu >= 0 and lastGuishaderMenu ~= openedMenu then
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
				lastGuishaderMenu = openedMenu
			end
		else
			buildoptionsArea = nil
			backgroundOptionsRect = nil
			if WG['guishader'] then
				WG['guishader'].RemoveDlist('buildbar2')
			end
			lastGuishaderMenu = -1
		end
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
