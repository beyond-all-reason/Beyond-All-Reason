--
-- Actions exposed:
--
-- bind z gridmenu_key 1 1 <-- Sets the first grid key, useful for german keyboard layout. Unnecessary if using the Bar Swap Y Z widget
-- bind alt+x gridmenu_next_page <-- Go to next page
-- bind alt+z gridmenu_prev_page <-- Go to previous page
function widget:GetInfo()
	return {
		name = "Grid menu",
		desc = "Build menu with grid hotkeys",
		author = "Floris, grid by badosu and resopmok",
		date = "October 2021",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = false,
		handler = true,
	}
end

include("keysym.h.lua")
VFS.Include('luarules/configs/customcmds.h.lua')

SYMKEYS = table.invert(KEYSYMS)

local returnToCategoriesOnPick = true

local keyConfig = VFS.Include("luaui/configs/keyboard_layouts.lua")
local currentLayout = Spring.GetConfigString("KeyboardLayout", "qwerty")

local prevHoveredCellID, hoverDlist, hoverUdefID, hoverCellSelected
local prevQueueNr, prevB, prevB3

local cachedUnitIcons

local BUILDCAT_ECONOMY = "Economy"
local BUILDCAT_COMBAT = "Combat"
local BUILDCAT_UTILITY = "Utility"
local BUILDCAT_PRODUCTION = "Build"
local categoryFontSize, hotkeyFontSize, pageButtonHeight

local folder = 'LuaUI/Images/groupicons/'
local groups = {
	energy = folder..'energy.png',
	metal = folder..'metal.png',
	builder = folder..'builder.png',
	buildert2 = folder..'buildert2.png',
	buildert3 = folder..'buildert3.png',
	buildert4 = folder..'buildert4.png',
	util = folder..'util.png',
	weapon = folder..'weapon.png',
	explo = folder..'weaponexplo.png',
	weaponaa = folder..'weaponaa.png',
	weaponsub = folder..'weaponsub.png',
	aa = folder..'aa.png',
	emp = folder..'emp.png',
	sub = folder..'sub.png',
	nuke = folder..'nuke.png',
	antinuke = folder..'antinuke.png',
}

local Cfgs = {
	disableInputWhenSpec = false, -- disable specs selecting buildoptions
	cfgCellPadding = 0.007,
	cfgIconPadding = 0.015, -- space between icons
	cfgIconCornerSize = 0.025,
	cfgPriceFontSize = 0.19,
	cfgActiveAreaMargin = 0.1, -- (# * bgpadding) space between the background border and active area
	sound_queue_add = 'LuaUI/Sounds/buildbar_add.wav',
	sound_queue_rem = 'LuaUI/Sounds/buildbar_rem.wav',
	fontFile = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf"),
	categoryTooltips = {
		[BUILDCAT_ECONOMY] = "Filter economy buildings",
		[BUILDCAT_COMBAT] = "Filter combat buildings",
		[BUILDCAT_UTILITY] = "Filter utility buildings",
		[BUILDCAT_PRODUCTION] = "Filter production buildings",
	},
	categoryIcons = {
		groups.energy,
		groups.weapon,
		groups.util,
		groups.builder,
	},
	buildCategories = {
		BUILDCAT_ECONOMY,
		BUILDCAT_COMBAT,
		BUILDCAT_UTILITY,
		BUILDCAT_PRODUCTION
	},
	categoryKeys = {},
	vKeyLayout = {},
	keyLayout = {},
}


local hotkeyActions = {}
local hoveredButton, drawnHoveredButton
local selBuildQueueDefID

local stickToBottom = false
local alwaysShow = false

local showPrice = false		-- false will still show hover
local showRadarIcon = true		-- false will still show hover
local showGroupIcon = true		-- false will still show hover
local showBuildProgress = true

local activeCmd
local priceFontSize

local zoomMult = 1.5
local defaultCellZoom = 0.025 * zoomMult
local rightclickCellZoom = 0.033 * zoomMult
local clickCellZoom = 0.07 * zoomMult
local hoverCellZoom = 0.05 * zoomMult
local clickSelectedCellZoom = 0.125 * zoomMult
local selectedCellZoom = 0.135 * zoomMult

local bgpadding, iconMargin, activeAreaMargin, iconTypesMap
local dlistGuishader, dlistGuishaderBuilders, dlistBuildmenuBg, dlistBuildmenu, font2
local doUpdate, doUpdateClock, ordermenuHeight, prevAdvplayerlistLeft
local cellPadding, iconPadding, cornerSize, cellInnerSize, cellSize

local activeBuilder, activeBuilderID, builderIsFactory, selectedFactoryUID
local prevBuildRectsCount = 0
local buildmenuShows = false

-- Helper types to make the code more readable and easy to work with
Rect = {}
function Rect:new(x1, y1, x2, y2)
	local this = {
		x = x1,
		y = y1,
		xEnd = x2,
		yEnd = y2
	}

	function this:contains(x, y)
		return x >= self.x and x <= self.xEnd and y >= self.y and y <= self.yEnd
	end

	function this:getId()
		return self.x .. self.y .. self.yEnd .. self.xEnd
	end

	return this
end

local function pairsByKeys (t, f)
	local a = {}
	for n in pairs(t) do table.insert(a, n) end
	table.sort(a, f)
	local i = 0      -- iterator variable
	local iter = function ()   -- iterator function
		i = i + 1
		if a[i] == nil then return nil
		else return a[i], t[a[i]]
		end
	end
	return iter
end


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local vsx, vsy = Spring.GetViewGeometry()

local ordermenuLeft = vsx / 5
local advplayerlistLeft = vsx * 0.8

local isSpec = Spring.GetSpectatingState()
local myTeamID = Spring.GetMyTeamID()

local startDefID = Spring.GetTeamRulesParam(myTeamID, 'startUnit')

local disableInput = Cfgs.disableInputWhenSpec and isSpec
local backgroundRect = Rect:new(0, 0, 0, 0)
local columns = 4
local rows = 3
local minimapHeight = 0.235
local selectedBuilders = {}
local selectedBuildersCount = 0
local cellRects = {}
local cellcmds = {}
local gridOpts = {}
local gridOptsCount
local categories = {}
local catRects = {}
local builderRects = {}
local currentCategory
local currentPage = 1
local pages = 1
local backRect = Rect:new(0, 0, 0, 0)
local nextPageRect = Rect:new(0, 0, 0, 0)
local categoriesRect = Rect:new(0, 0, 0, 0)
local buildpicsRect = Rect:new(0, 0, 0 ,0)
local paginatorsRect = Rect:new(0, 0, 0, 0)
local buildersRect = Rect:new(0, 0, 0, 0)
local nextBuilderRect = Rect:new(0, 0, 0, 0)
local isPregame = Spring.GetGameFrame() == 0 and not isSpec

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local spGetCmdDescIndex = Spring.GetCmdDescIndex
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitHealth = Spring.GetUnitHealth
local spGetUnitIsBuilding = Spring.GetUnitIsBuilding
local SelectedUnitsCount = Spring.GetSelectedUnitsCount()

local math_floor = math.floor
local math_ceil = math.ceil
local math_max = math.max
local math_min = math.min

local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_ONE = GL.ONE
local GL_ONE_MINUS_SRC_COLOR = GL.ONE_MINUS_SRC_COLOR

-- Get from FlowUI
local RectRound, RectRoundProgress, UiUnit, UiElement, UiButton, elementCorner, TexRectRound
local ui_opacity, ui_scale


local selectNextFrame, switchedCategory
local units = VFS.Include("luaui/configs/unit_buildmenu_config.lua")
local grid = VFS.Include("luaui/configs/gridmenu_config.lua")

local showWaterUnits = false
units.restrictWaterUnits(true)


local function checkGuishader(force)
	if WG['guishader'] then
		if force and dlistGuishader then
			dlistGuishader = gl.DeleteList(dlistGuishader)
		end
		if not dlistGuishader then
			dlistGuishader = gl.CreateList(function()
				RectRound(backgroundRect.x, backgroundRect.y, backgroundRect.xEnd, backgroundRect.yEnd, elementCorner)
			end)
			if activeBuilder then
				WG['guishader'].InsertDlist(dlistGuishader, 'buildmenu')
			end
		end
	elseif dlistGuishader then
		dlistGuishader = gl.DeleteList(dlistGuishader)
	end
end

local function checkGuishaderBuilders(force)
	if WG['guishader'] and #builderRects > 1 then
		if prevBuildRectsCount ~= #builderRects then
			prevBuildRectsCount = #builderRects
			if dlistGuishaderBuilders then
				dlistGuishaderBuilders = gl.DeleteList(dlistGuishaderBuilders)
			end
			dlistGuishaderBuilders = gl.CreateList(function()
				RectRound(buildersRect.x, buildersRect.y, buildersRect.xEnd+(bgpadding*2), buildersRect.yEnd+bgpadding+(iconMargin*2), elementCorner)
			end)
			WG['guishader'].InsertDlist(dlistGuishaderBuilders, 'buildmenubuilders')
		end
	elseif dlistGuishaderBuilders then
		prevBuildRectsCount = 0
		WG['guishader'].DeleteDlist('buildmenubuilders')
		dlistGuishaderBuilders = nil
	end
end

function widget:PlayerChanged()
	isSpec = Spring.GetSpectatingState()
	myTeamID = Spring.GetMyTeamID()
end

local function RefreshCommands()

	if isPregame and startDefID then
		activeBuilder = startDefID
	end

	gridOpts = {}
	gridOptsCount = 0

	function tablelength(T)
		local count = 0
		for _ in pairs(T) do count = count + 1 end
		return count
	end

	if activeBuilder then
		if builderIsFactory then
			local activeCmdDescs = Spring.GetUnitCmdDescs(selectedFactoryUID)
			gridOpts = grid.getSortedGridForLab(activeBuilder, activeCmdDescs)
		else
			categories = Cfgs.buildCategories
			local buildOptions = UnitDefs[activeBuilder].buildOptions
			if isPregame and units.unbaStartBuildoptions then
				buildOptions = units.unbaStartBuildoptions
			end
			gridOpts = grid.getSortedGridForBuilder(activeBuilder, buildOptions, currentCategory)
		end
	end

	gridOptsCount = tablelength(gridOpts)
end


local function getActionHotkey(action)
	local key
	for _, keybinding in pairs(Spring.GetActionHotKeys(action)) do
		if (not key) or keybinding:len() < key:len() then
			key = keybinding
		end

		if key:len() == 1 then break end
	end

	return key
end

-- Helper function for iterating over the actions with builder and factory tags,
-- with GetActionHotKeys those tags will be missed and the hotkey wont work
local function getGridKey(action)
	local key = getActionHotkey(action)
		or getActionHotkey(action .. ' builder')
		or getActionHotkey(action .. ' factory')
	return key
end

local function reloadBindings()
	currentLayout = Spring.GetConfigString("KeyboardLayout", 'qwerty')

	Cfgs.keyLayout = {{}, {}, {}}

	for c=1,4 do
		local categoryAction = 'gridmenu_category ' .. c
		local cKey = getActionHotkey(categoryAction)

		if not cKey then
			cKey = ''
		end

		Cfgs.categoryKeys[c] = cKey

		for r=1,3 do
			local keyAction = 'gridmenu_key ' .. r .. ' ' .. c
			local key = getGridKey(keyAction)

			if not key then
				key = ''
			end

			Cfgs.keyLayout[r][c] = key
		end
	end

	local key = getActionHotkey('gridmenu_next_page')
	if not key then
	end

	Cfgs.NEXT_PAGE_KEY = key

	key = getActionHotkey('gridmenu_cycle_builder')
	Cfgs.CYCLE_BUILDER_KEY = key

	-- Autogenerate bottom layout keys
	Cfgs.vKeyLayout = {}

	-- For bottom layout, 1-2 row x 1-4 col positions remain the same
	for r=1,2 do
		Cfgs.vKeyLayout[r] = {}
		for c=1,4 do
			Cfgs.vKeyLayout[r][c] = Cfgs.keyLayout[r][c]
		end
	end

	Cfgs.vKeyLayout[1][5] = Cfgs.keyLayout[3][3]
	Cfgs.vKeyLayout[1][6] = Cfgs.keyLayout[3][4]
	Cfgs.vKeyLayout[2][5] = Cfgs.keyLayout[3][1]
	Cfgs.vKeyLayout[2][6] = Cfgs.keyLayout[3][2]

	doUpdate = true
end

local function setPreGamestartDefID(uDefID)
	selBuildQueueDefID = uDefID
	WG['pregame-build'].setPreGamestartDefID(uDefID)
	if not uDefID then
		currentCategory = nil
		doUpdate = true
	end

end

local function gridmenuCategoryHandler(_, _, args)
	local cIndex = args and tonumber(args[1])

	if not cIndex or cIndex < 1 or cIndex > 4 then
		return
	end

	if not activeBuilder or builderIsFactory or (currentCategory and hotkeyActions['1' .. cIndex]) then
		return
	end

	local alt, ctrl, meta, _ = Spring.GetModKeyState()

	if alt or ctrl or meta then return end

	currentCategory = categories[cIndex]
	switchedCategory = os.clock()
	doUpdate = true

	return true
end

local function enqueueUnit(uDefID, opts)
	local udTable = Spring.GetSelectedUnitsSorted()
	for udidFac, uTable in pairs(udTable) do
		if units.isFactory[udidFac] then
			for _, uid in ipairs(uTable) do
				Spring.GiveOrderToUnit(uid, uDefID, {}, opts)
			end
		end
	end
end

local function gridmenuKeyHandler(_, _, args, _, isRepeat)
	-- validate args
	local row = args and tonumber(args[1])
	local col = args and tonumber(args[2])

	if (not row or row < 1 or row > 3) or (not col or col < 1 or col > 4) then
		return
	end

	local uDefID = hotkeyActions[tostring(row) .. tostring(col)]

	if not uDefID or units.unitRestricted[-uDefID] then
		return
	end

	if isRepeat and activeBuilder then
		return currentCategory and true or false
	end

	local alt, ctrl, meta, shift = Spring.GetModKeyState()

	if builderIsFactory then
		if args[3] and args[3] == 'builder' then return false end
		if meta then return end

		local opts

		if ctrl then
			opts = { "right" }
			Spring.PlaySoundFile(Cfgs.sound_queue_rem, 0.75, 'ui')
		else
			opts = { "left" }
			Spring.PlaySoundFile(Cfgs.sound_queue_add, 0.75, 'ui')
		end

		if alt then table.insert(opts, 'alt') end
		if shift then table.insert(opts, 'shift') end

		enqueueUnit(uDefID, opts)

		return true
	elseif isPregame and currentCategory then
		if alt or ctrl or meta then return end
		if args[3] and args[3] == 'factory' then return false end

		setPreGamestartDefID(-uDefID)

		doUpdate = true

		return true
	elseif activeBuilder and currentCategory then
		if args[3] and args[3] == 'factory' then return false end
		if alt or ctrl or meta then return end

		local uDef = UnitDefs[-uDefID]
		local isRepeatMex = uDef.customParams.metal_extractor and uDef.name == activeCmd and not (uDef.stealth or #uDef.weapons > 0)
		local cmd = isRepeatMex and 'areamex' or spGetCmdDescIndex(uDefID)
		Spring.SetActiveCommand(cmd, 3, false, true, alt, ctrl, meta, shift)

		return true
	end

	return false
end

function widget:CommandNotify(cmdID, _, cmdOpts)
	if cmdID >= 0 then
		return
	end

	if returnToCategoriesOnPick or not cmdOpts.shift then
		currentCategory = nil
		doUpdate = true
	end
end


local function addBuilderToSelection(unitID, incrementCount)
	local unitDefID = spGetUnitDefID(unitID)

	if units.isBuilder[unitDefID] then
		doUpdate = true
		builderIsFactory = false

		if not selectedBuilders[unitDefID] then
			selectedBuildersCount = selectedBuildersCount + 1
		end

		if incrementCount then
			local count = selectedBuilders[unitDefID] and selectedBuilders[unitDefID] or 0
			selectedBuilders[unitDefID] = count + 1
		end

		activeBuilder = unitDefID
		activeBuilderID = unitID
	end

	if units.isFactory[unitDefID] then
		doUpdate = true

		builderIsFactory = true
		selectedFactoryUID = unitID
		activeBuilder = unitDefID
	end
end

---Set active builder based on index in selectedBuilders
---@param index number
---@return nil
---
local function setActiveBuilder(index)
	local i = 0
	for builder, _ in pairsByKeys(selectedBuilders) do
		i = i + 1
		if i == index then
			local sel = Spring.GetSelectedUnits()
			for _, unitID in pairs(sel) do
				local unitDefID = spGetUnitDefID(unitID)
				if builder == unitDefID then
					addBuilderToSelection(unitID, false)
					break
				end
			end
		end
	end
end


local function cycleBuilder()
	if selectedBuildersCount <= 1 then
		return
	end
	-- find the index that is currently active
	local index = 0
	for unitDefID, _ in pairsByKeys(selectedBuilders) do
		index = index + 1
		if unitDefID == activeBuilder then
			if index == selectedBuildersCount then -- loop back to start
				setActiveBuilder(1)
			else
				setActiveBuilder(index + 1)
			end
			break
		end
	end
end

local function nextPageHandler()
	if not activeBuilder then return end
	if pages < 2 then return end

	currentPage =  currentPage + 1
	if(currentPage > pages) then
		currentPage = 1
	end
	doUpdate = true

	return true
end

function widget:Initialize()
	if widgetHandler:IsWidgetKnown("Build menu") then
		widgetHandler:DisableWidget("Build menu")
	end

	units.checkGeothermalFeatures()

	-- For some reason when handler = true widgetHandler:AddAction is not available
	widgetHandler.actionHandler:AddAction(self, "gridmenu_next_page", nextPageHandler, nil, "p")
	widgetHandler.actionHandler:AddAction(self, "gridmenu_cycle_builder", cycleBuilder, nil, "p")
	widgetHandler.actionHandler:AddAction(self, "gridmenu_key", gridmenuKeyHandler, nil, "pR")
	widgetHandler.actionHandler:AddAction(self, "gridmenu_category", gridmenuCategoryHandler, nil, "p")

	reloadBindings()

	ui_opacity = WG.FlowUI.opacity
	ui_scale = WG.FlowUI.scale

	iconTypesMap = {}
	if Script.LuaRules('GetIconTypes') then
		iconTypesMap = Script.LuaRules.GetIconTypes()
	end

	-- Get our starting unit
	if isPregame then
		if not startDefID or startDefID ~= Spring.GetTeamRulesParam(myTeamID, 'startUnit') then
			startDefID = Spring.GetTeamRulesParam(myTeamID, 'startUnit')
			doUpdate = true
		end
	end

	widget:ViewResize()
	widget:SelectionChanged(Spring.GetSelectedUnits())

	WG['buildmenu'] = {}
	WG['buildmenu'].getGroups = function()
		return groups, units.unitGroup
	end
	WG['buildmenu'].getOrder = function()
		return units.unitOrder
	end
	WG['buildmenu'].getShowPrice = function()
		return showPrice
	end
	WG['buildmenu'].setShowPrice = function(value)
		showPrice = value
		doUpdate = true
	end
	WG['buildmenu'].getAlwaysShow = function()
		return alwaysShow
	end
	WG['buildmenu'].setAlwaysShow = function(value)
		alwaysShow = value
		doUpdate = true
	end
	WG['buildmenu'].getShowRadarIcon = function()
		return showRadarIcon
	end
	WG['buildmenu'].setShowRadarIcon = function(value)
		showRadarIcon = value
		doUpdate = true
	end
	WG['buildmenu'].getShowGroupIcon = function()
		return showGroupIcon
	end
	WG['buildmenu'].setShowGroupIcon = function(value)
		showGroupIcon = value
		doUpdate = true
	end
	WG['buildmenu'].getBottomPosition = function()
		return stickToBottom
	end
	WG['buildmenu'].setBottomPosition = function(value)
		stickToBottom = value
		widget:Update(1000)
		widget:ViewResize()
		doUpdate = true
	end
	WG['buildmenu'].getSize = function()
		return backgroundRect.y, backgroundRect.yEnd
	end
	WG['buildmenu'].reloadBindings = reloadBindings
	WG['buildmenu'].getIsShowing = function()
		return buildmenuShows
	end
end

-- update queue number
function widget:UnitFromFactory(_, _, _, factID)
	if Spring.IsUnitSelected(factID) then
		doUpdateClock = os.clock() + 0.01
	end
end

--------------------
-- DRAW FUNCTIONS --
--------------------

local function clear()
	dlistBuildmenu = gl.DeleteList(dlistBuildmenu)
	dlistBuildmenuBg = gl.DeleteList(dlistBuildmenuBg)
end

function widget:ViewResize()
	local widgetSpaceMargin = WG.FlowUI.elementMargin
	bgpadding = WG.FlowUI.elementPadding
	iconMargin = math.floor((bgpadding * 0.5) + 0.5)
	elementCorner = WG.FlowUI.elementCorner
	RectRound = WG.FlowUI.Draw.RectRound
	RectRoundProgress = WG.FlowUI.Draw.RectRoundProgress
	UiUnit = WG.FlowUI.Draw.Unit
	TexRectRound = WG.FlowUI.Draw.TexRectRound
	UiElement = WG.FlowUI.Draw.Element
	UiButton = WG.FlowUI.Draw.Button
	categoryFontSize = 0.0115 * ui_scale * vsy
	hotkeyFontSize = categoryFontSize + 5
	pageFontSize = categoryFontSize
	pageButtonHeight = math_floor(2.3 * categoryFontSize * ui_scale)
	categoryButtonHeight = pageButtonHeight
	builderButtonSize = pageButtonHeight * 2

	activeAreaMargin = math_ceil(bgpadding * Cfgs.cfgActiveAreaMargin)

	vsx, vsy = Spring.GetViewGeometry()

	font2 = WG['fonts'].getFont(Cfgs.fontFile, 1.2, 0.28, 1.6)

	if WG['minimap'] then
		minimapHeight = WG['minimap'].getHeight()
	end

	-- if stick to bottom we know cells are 2 row by 6 column
	if stickToBottom then

		local posY = math_floor(0.14 * ui_scale * vsy)
		local posYEnd = 0
		local posX = math_floor(ordermenuLeft*vsx) + widgetSpaceMargin
		local height = posY
		builderButtonSize = pageButtonHeight * 1.75

		rows = 2
		columns = 6
		cellSize = math_floor(((height) - bgpadding) / rows)

		local categoryWidth = 8 * categoryFontSize * ui_scale

		-- assemble rects left to right
		categoriesRect = Rect:new(
			posX + bgpadding,
			posYEnd + pageButtonHeight + bgpadding,
			posX + categoryWidth,
			posY - bgpadding
		)

		paginatorsRect = Rect:new(
			posX + bgpadding,
			posYEnd + bgpadding,
			posX + categoryWidth,
			categoriesRect.y
		)

		buildpicsRect = Rect:new(
			categoriesRect.xEnd + bgpadding,
			posYEnd,
			categoriesRect.xEnd + (cellSize * columns) + bgpadding,
			posY - bgpadding
		)

		backgroundRect = Rect:new(
			posX,
			posYEnd,
			buildpicsRect.xEnd + bgpadding,
			posY
		)

		-- start with no width and grow dynamically
		buildersRect = Rect:new(
			posX,
			backgroundRect.yEnd,
			posX,
			backgroundRect.yEnd + builderButtonSize
		)

	else -- if stick to side we know cells are 3 row by 4 column
		local width = 0.212 	-- hardcoded width to match bottom element
		width = width / (vsx / vsy) * 1.78	-- make smaller for ultrawide screens
		width = width * ui_scale

		-- 0.14 is the space required to put this above the bottom-left UI element
		local posYEnd = math_floor(0.14 * ui_scale * vsy) + widgetSpaceMargin
		local posY = math_floor(posYEnd + ((0.74 * vsx) * width + pageButtonHeight))/vsy
		local posX = 0

		if WG['ordermenu'] and not WG['ordermenu'].getBottomPosition() then
			local _, oposY, _, oheight = WG['ordermenu'].getPosition()
			if posY > oposY then
				posY = (oposY - oheight - ((widgetSpaceMargin)/vsy))
			end
		end

		local posXEnd = math_floor(width * vsx)

		-- make pixel aligned
		width = posXEnd - posX

		categoryButtonHeight = pageButtonHeight * 1.4

		-- assemble rects, bottom to top
		categoriesRect = Rect:new(
			posX + bgpadding,
			posYEnd + bgpadding,
			posXEnd - bgpadding,
			posYEnd + categoryButtonHeight + bgpadding
		)

		rows = 3
		columns = 4
		cellSize = math_floor((width - (bgpadding * 2)) / columns)
		pageButtonHeight = cellSize / 3

		buildpicsRect = Rect:new(
			posX + bgpadding,
			categoriesRect.yEnd,
			posXEnd - bgpadding,
			categoriesRect.yEnd + (cellSize * rows)
		)

		paginatorsRect = Rect:new(
			posX + bgpadding,
			buildpicsRect.yEnd + bgpadding,
			posXEnd - bgpadding,
			buildpicsRect.yEnd + pageButtonHeight
		)

		backgroundRect = Rect:new(
			posX,
			posYEnd,
			posXEnd,
			paginatorsRect.yEnd + (bgpadding * 1.5)
		)

		-- start with no width and grow dynamically
		buildersRect = Rect:new(
			posX,
			backgroundRect.yEnd,
			posX,
			backgroundRect.yEnd + builderButtonSize
		)
	end

	checkGuishader(true)
	clear()
	doUpdate = true
end


local sec = 0
local updateSelection = true
function widget:Update(dt)
	if updateSelection then
		updateSelection = false
		SelectedUnitsCount = Spring.GetSelectedUnitsCount()

		activeBuilder = nil
		activeBuilderID = nil
		builderIsFactory = false
		currentCategory = nil
		selectedBuilders = {}
		selectedBuildersCount = 0
		currentPage = 1

		if SelectedUnitsCount > 0 then
			local sel = Spring.GetSelectedUnits()
			for _, unitID in pairs(sel) do
				addBuilderToSelection(unitID, true)
			end

			if activeBuilder and not builderIsFactory then
				categories = Cfgs.buildCategories
			else
				categories = {}
			end

			-- set active builder to first index after updating selection
			setActiveBuilder(1)
		end
	end

	sec = sec + dt
	if sec > 0.33 then
		sec = 0
		checkGuishader()
		if WG['minimap'] and minimapHeight ~= WG['minimap'].getHeight() then
			widget:ViewResize()
			doUpdate = true
		end

		local _, _, mapMinWater, _ = Spring.GetGroundExtremes()
		if not voidWater and mapMinWater <= units.minWaterUnitDepth and not showWaterUnits then
			showWaterUnits = true
			units.restrictWaterUnits(false)
		end

		local prevOrdermenuLeft = ordermenuLeft
		local prevOrdermenuHeight = ordermenuHeight
		if WG['ordermenu'] then
			local oposX, _, owidth, oheight = WG['ordermenu'].getPosition()
			ordermenuLeft = oposX + owidth
			ordermenuHeight = oheight
		end
		if not prevAdvplayerlistLeft or advplayerlistLeft ~= prevAdvplayerlistLeft or not prevOrdermenuLeft or ordermenuLeft ~= prevOrdermenuLeft  or not prevOrdermenuHeight or ordermenuHeight ~= prevOrdermenuHeight then
			widget:ViewResize()
		end

		disableInput = Cfgs.disableInputWhenSpec and isSpec
		if Spring.IsGodModeEnabled() then
			disableInput = false
		end
	end

	if selectNextFrame and not isPregame then
		local cmdIndex = spGetCmdDescIndex(selectNextFrame)
		if cmdIndex then
			Spring.SetActiveCommand(cmdIndex, 1, true, false, Spring.GetModKeyState())
		end
		selectNextFrame = nil
		switchedCategory = nil

		doUpdate = true
	else
		-- refresh buildmenu if active cmd changed
		local prevActiveCmd = activeCmd

		if Spring.GetGameFrame() == 0 and WG['pregame-build'] then
			activeCmd = WG['pregame-build'].selectedID
			if activeCmd then
				activeCmd = units.unitName[activeCmd]
			end
		else
			activeCmd = select(4, Spring.GetActiveCommand())
		end

		if activeCmd ~= prevActiveCmd then doUpdate = true end
	end

	if not (isPregame or activeBuilder or alwaysShow) then
		buildmenuShows = false
	else
		buildmenuShows = true
	end
end


local function drawBuildMenuBg()
	local height = backgroundRect.yEnd - backgroundRect.y
	local posY = backgroundRect.y
	UiElement(backgroundRect.x, backgroundRect.y, backgroundRect.xEnd, backgroundRect.yEnd, (backgroundRect.x > 0 and (#builderRects > 1 and 0 or 1) or 0), 1, ((posY-height > 0 or backgroundRect.x <= 0) and 1 or 0), 0)
end


local function drawButton(rect, opts, icon)
	opts = opts or {}
	local disabled = opts.disabled or false
	local highlight = opts.highlight
	local hovered = opts.hovered

	local padding = math_max(1, math_floor(bgpadding * 0.52))

	local color = highlight and 0.2 or 0

	local color1 = { color, color, color, math_max(0.55, math_min(0.95, ui_opacity * 1.25)) }	-- bottom
	local color2 = { color, color, color, math_max(0.55, math_min(0.95, ui_opacity * 1.25)) }	-- top

	if highlight then
		gl.Blending(GL_SRC_ALPHA, GL_ONE)
		gl.Color(0, 0, 0, 0.1)
	end

	UiButton(rect.x, rect.y, rect.xEnd, rect.yEnd, 1,1,1,1, 1,1,1,1, nil, color1, color2, padding)

	local dim = disabled and 0.4 or 1.0

	if icon then
		local iconSize = math.min(math.floor((rect.yEnd - rect.y) * 1.1), pageButtonHeight)
		icon = ":l:" .. icon
		gl.Color(dim, dim, dim, 0.9)
		gl.Texture(icon)
		gl.BeginEnd(GL.QUADS, TexRectRound, rect.x + (bgpadding / 2), rect.yEnd - iconSize, rect.x + iconSize, rect.yEnd - (bgpadding / 2),  0,  0,0,0,0,  0.05)	-- this method with a lil zoom prevents faint edges aroudn the image
		--	gl.TexRect(px, sy - iconSize, px + iconSize, sy)
		gl.Texture(false)
	end

	if highlight then
		gl.Blending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	end

	if hovered then
		-- gloss highlight
		gl.Blending(GL_SRC_ALPHA, GL_ONE)
		RectRound(rect.x, rect.yEnd - ((rect.yEnd - rect.y) * 0.42), rect.xEnd, (rect.yEnd), padding * 1.5, 2, 2, 0, 0, { 1, 1, 1, 0.035 }, { 1, 1, 1, (disableInput and 0.11 or 0.24) })
		RectRound(rect.x, rect.y, rect.xEnd, (rect.y) + ((rect.yEnd - rect.y) * 0.5), padding * 1.5, 0, 0, 2, 2, { 1, 1, 1, (disableInput and 0.035 or 0.075) }, { 1, 1, 1, 0 })
		gl.Blending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	end

	if opts.hovered then
		drawnHoveredButton = rect:getId()
	end
end

local function drawCell(rect, cmd, usedZoom, cellColor, disabled)
	local uid = cmd.id * -1
	-- unit icon
	if disabled then
		gl.Color(0.4, 0.4, 0.4, 1)
	else
		gl.Color(1, 1, 1, 1)
	end

	local showIcon = showGroupIcon

	UiUnit(
		rect.x + cellPadding + iconPadding,
		rect.y + cellPadding + iconPadding,
		rect.xEnd - cellPadding - iconPadding,
		rect.yEnd - cellPadding - iconPadding,
		cornerSize, 1,1,1,1,
		usedZoom,
		nil,
		disabled and 0 or nil,
		'#' .. uid,
		showRadarIcon and (((units.unitIconType[uid] and iconTypesMap[units.unitIconType[uid]]) and ':l' .. (disabled and 't0.3,0.3,0.3' or '') ..':' .. iconTypesMap[units.unitIconType[uid]] or nil)) or nil,
		showIcon and (groups[units.unitGroup[uid]] and ':l' .. (disabled and 't0.3,0.3,0.3:' or ':') ..groups[units.unitGroup[uid]] or nil) or nil,
		{units.unitMetalCost[uid], units.unitEnergyCost[uid]},
		tonumber(cmd.params[1])
	)

	-- colorize/highlight unit icon
	if cellColor then
		gl.Blending(GL.DST_ALPHA, GL_ONE_MINUS_SRC_COLOR)
		gl.Color(cellColor[1], cellColor[2], cellColor[3], cellColor[4])
		gl.Texture('#' .. uid)
		UiUnit(
			rect.x + cellPadding + iconPadding,
			rect.y + cellPadding + iconPadding,
			rect.xEnd - cellPadding - iconPadding,
			rect.yEnd - cellPadding - iconPadding,
			cornerSize, 1,1,1,1,
			usedZoom
		)
		if cellColor[4] > 0 then
			gl.Blending(GL_SRC_ALPHA, GL_ONE)
			UiUnit(
				rect.x + cellPadding + iconPadding,
				rect.y + cellPadding + iconPadding,
				rect.xEnd - cellPadding - iconPadding,
				rect.yEnd - cellPadding - iconPadding,
				cornerSize, 1,1,1,1,
				usedZoom
			)
		end
		gl.Blending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	end
	gl.Texture(false)

	-- price
	if showPrice then
		local metalColor = disabled and "\255\125\125\125" or "\255\245\245\245"
		local energyColor = disabled and "\n\255\135\135\135" or "\n\255\255\255\000"
		local text = metalColor .. units.unitMetalCost[uid] .. energyColor
		font2:Print(text .. units.unitEnergyCost[uid], rect.x + cellPadding + (cellInnerSize * 0.048), rect.y + cellPadding + (priceFontSize * 1.35), priceFontSize, "o")
	end

	-- hotkey draw
	if cmd.hotkey and (builderIsFactory or (activeBuilder and currentCategory)) then
		local hotkeyText = keyConfig.sanitizeKey(cmd.hotkey, currentLayout)

		local keyFontSize = priceFontSize * 1.1
		local hotkeyColor = disabled and "\255\100\100\100" or "\255\215\255\215"
		font2:Print(hotkeyColor .. hotkeyText, rect.xEnd - cellPadding - (cellInnerSize * 0.048), rect.yEnd - cellPadding - keyFontSize, keyFontSize, "ro")
	end

	-- factory queue number
	if cmd.params[1] then
		local queueFontSize = cellInnerSize * 0.29
		local pad = math_floor(cellInnerSize * 0.03)
		local textWidth = font2:GetTextWidth(cmd.params[1] .. '	') * queueFontSize
		RectRound(rect.x, rect.yEnd - cellPadding - iconPadding - math_floor(cellInnerSize * 0.365), rect.x + textWidth, rect.yEnd - cellPadding - iconPadding, cornerSize * 3.3, 0, 0, 1, 0, { 0.15, 0.15, 0.15, 0.95 }, { 0.25, 0.25, 0.25, 0.95 })
		font2:Print("\255\190\255\190" .. cmd.params[1],
			rect.x + cellPadding + (pad * 3.5),
			rect.y + cellPadding + math_floor(cellInnerSize * 0.735),
			queueFontSize, "o"
		)
	end
end


local function drawEmptyCell(rect)
	local color = { 0.1, 0.1, 0.1, 0.7 }
	local pad = cellPadding + iconPadding
	RectRound(rect.x + pad, rect.y + pad, rect.xEnd - pad, rect.yEnd - pad, cornerSize, 1, 1, 1, 1, color, color)
end


local function drawButtonHotkey(rect, keyText)
	if not rect or not keyText then return end
	local keyFontHeight = font2:GetTextHeight(keyText) * hotkeyFontSize
	local keyFontHeightOffset = keyFontHeight * 0.34

	local textPadding = bgpadding * 2

	local text = "\255\215\255\215" .. keyText
	font2:Print(text, rect.xEnd - textPadding, (rect.y - (rect.y - rect.yEnd) / 2) - keyFontHeightOffset, hotkeyFontSize, "ro")
end


local function drawCategories()
	local numCats = #categories

	-- set up rects
	if stickToBottom then
		local x1 = categoriesRect.x

		local contentHeight = (categoriesRect.yEnd - categoriesRect.y) / numCats
		local contentWidth = categoriesRect.xEnd - categoriesRect.x

		for i, cat in ipairs(categories) do
			local y1 = categoriesRect.yEnd - i * contentHeight + 2
			catRects[cat] = Rect:new(
				x1,
				y1,
				x1 + contentWidth - activeAreaMargin,
				y1 + contentHeight - 2
			)
		end
	else
		local y2 = categoriesRect.yEnd

		local buttonWidth = math.round(((categoriesRect.xEnd - categoriesRect.x) / numCats))
		local padding = math_max(1, math_floor(bgpadding * 0.52))

		for i, cat in ipairs(categories) do
			local x1 = categoriesRect.x + (i - 1) * buttonWidth
			catRects[cat] = Rect:new(
				x1,
				y2 - categoryButtonHeight + padding,
				x1 + buttonWidth,
				y2 - activeAreaMargin - padding
			)
		end
	end

	-- set up buttons
	for catIndex, cat in pairs(categories) do
		local catText = cat
		local catIcon = Cfgs.categoryIcons[catIndex]
		local keyText = keyConfig.sanitizeKey(Cfgs.categoryKeys[catIndex], currentLayout)
		local rect = catRects[cat]

		local disabled = (currentCategory and cat ~= currentCategory) and true or false

		local opts = {
			disabled = disabled,
			highlight = (cat == currentCategory),
			hovered = (hoveredButton == rect:getId()),
		}



		local textPadding = bgpadding * 2

		local fontSize = categoryFontSize
		local fontHeight = font2:GetTextHeight(catText) * categoryFontSize
		local fontHeightOffset = fontHeight * 0.34
		local fontColor = disabled and "\255\100\100\100" or ""
		font2:Print(fontColor .. catText, rect.x + (textPadding * 3), (rect.y - (rect.y - rect.yEnd) / 2) - fontHeightOffset, fontSize, "o")

		if not currentCategory then
			drawButtonHotkey(rect, keyText)
		end

		drawButton(rect, opts, catIcon)
	end

	-- back button
	if currentCategory and not stickToBottom then
		local backText = "Back"
		local width = (paginatorsRect.xEnd - paginatorsRect.x) / 2
		backRect = Rect:new(paginatorsRect.x, paginatorsRect.y, paginatorsRect.xEnd - width - bgpadding, paginatorsRect.yEnd)
		local buttonWidth = backRect.xEnd - backRect.x
		local buttonHeight = backRect.yEnd - backRect.y
		local heightOffset = backRect.yEnd - font2:GetTextHeight(backText) * pageFontSize * 0.35 - buttonHeight/2
		font2:Print("⟵", backRect.x + (bgpadding * 3), heightOffset, pageFontSize, "o")
		font2:Print(backText, backRect.x + (buttonWidth * 0.5), heightOffset, pageFontSize * 1.1, "co")

		local opts = {
			highlight = false,
			hovered = hoveredButton == backRect:getId()
		}

		drawButtonHotkey(backRect, "Shift")
		drawButton(backRect, opts)
	end
end


local function drawPaginators()
	if pages == 1 then
		return
	end

	local nextKeyText = keyConfig.sanitizeKey(Cfgs.NEXT_PAGE_KEY, currentLayout)
	local nextPageText = "\255\245\245\245" .. "Next Page    ⟶"
	local pagesText = "\255\245\245\245" .. currentPage .. " / " .. pages

	local opts = {
		highlight = false,
		hovered = false,
	}

	local buttonHeight = nextPageRect.yEnd - nextPageRect.y
	local buttonWidth = nextPageRect.xEnd - nextPageRect.x
	local heightOffset = nextPageRect.yEnd - font2:GetTextHeight(pagesText) * pageFontSize * 0.2 - buttonHeight/2

	if stickToBottom then
		nextPageRect = Rect:new(paginatorsRect.x, paginatorsRect.y, paginatorsRect.xEnd, paginatorsRect.yEnd)
		nextPageText = "\255\245\245\245" .. "Page " .. currentPage .. "/" .. pages .. " 🠚"
		font2:Print(nextPageText, nextPageRect.x + (bgpadding * 2), heightOffset, pageFontSize, "o")
	else
		local width = paginatorsRect.xEnd - paginatorsRect.x
		nextPageRect = Rect:new(paginatorsRect.x + (width / 2) + bgpadding, paginatorsRect.y, paginatorsRect.xEnd, paginatorsRect.yEnd)
		font2:Print(pagesText, nextPageRect.x + (bgpadding * 2), heightOffset, pageFontSize, "o")
		font2:Print(nextPageText, nextPageRect.x + (buttonWidth * 0.55), heightOffset, pageFontSize, "co")
	end

	drawButtonHotkey(nextPageRect, nextKeyText)

	opts.hovered = hoveredButton and nextPageRect:getId() == hoveredButton
	drawButton(nextPageRect, opts)
end


local function drawBuilderIcon(unitDefID, rect, count, lightness, zoom, highlightOpacity)
	local hovered = hoveredButton == rect:getId()
	lightness = hovered and lightness + 0.25 or lightness
	zoom = hovered and zoom + 0.1 or zoom
	local rectSize = rect.xEnd - rect.x

	gl.Color(lightness,lightness,lightness,1)
	UiUnit(
		rect.x, rect.y, rect.xEnd, rect.yEnd,
		math.ceil(bgpadding*0.5), 1,1,1,1,
		zoom,
		nil, math_max(0.1, highlightOpacity or 0.1),
		'#'..unitDefID,
		nil, nil, nil, nil
	)

	-- builder count number
	if count > 1 then
		local countFontSize = rectSize * 0.3
		local pad = math_floor(rectSize * 0.03)
		font2:Print("\255\240\240\240" .. count,
			rect.x + (pad * 2),
			rect.y + pad + math_floor(countFontSize * 2.2),
			countFontSize, "o"
		)
	end

	if highlightOpacity then
		gl.Blending(GL_SRC_ALPHA, GL_ONE)
		gl.Color(1,1,1,highlightOpacity)
		RectRound(rect.x, rect.y, rect.xEnd, rect.yEnd, math_min(math_max(1, math_floor((rect.xEnd-rect.x) * 0.024)), math_floor((vsy*0.0015)+0.5)))
		gl.Blending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	end
end


local function drawBuilders()
	if not activeBuilder or selectedBuildersCount <= 1 then
		return
	end
	builderRects = {}

	-- reset builders rect to fix placement issues
	buildersRect.xEnd = buildersRect.x

	local padding = math_floor(builderButtonSize / 12)
	local builderTypes = 0
	local builderButtons = {}
	for unitDefID, count in pairsByKeys(selectedBuilders) do
		builderTypes = builderTypes + 1

		-- place at the end of the bounds of the container
		local rect = Rect:new(
			buildersRect.xEnd,
			buildersRect.y,
			buildersRect.xEnd + (builderButtonSize),
			buildersRect.yEnd
		)

		-- grow container
		buildersRect = Rect:new(
			buildersRect.x,
			buildersRect.y,
			rect.xEnd + padding,
			buildersRect.yEnd
		)
		builderRects[builderTypes] = rect
		builderButtons[builderTypes] = { unitDefID, count, rect }

		-- avoid overflow
		if builderTypes > 5 then
			break
		end
	end

	-- draw background
	local height = backgroundRect.yEnd - backgroundRect.y
	local posY = backgroundRect.y
	UiElement(buildersRect.x, buildersRect.y, buildersRect.xEnd+(bgpadding*2), buildersRect.yEnd+bgpadding+(iconMargin*2), (backgroundRect.x > 0 and 1 or 0), 1, ((posY-height > 0 or backgroundRect.x <= 0) and 1 or 0), 0, 1,1,0,1)

	-- draw buttons
	for builderType, params in pairsByKeys(builderButtons) do
		-- correct position so its withing the background
		builderRects[builderType].x = builderRects[builderType].x+bgpadding+iconMargin
		builderRects[builderType].y = builderRects[builderType].y+iconMargin
		builderRects[builderType].xEnd = builderRects[builderType].xEnd+bgpadding+iconMargin
		builderRects[builderType].yEnd = builderRects[builderType].yEnd+iconMargin

		drawBuilderIcon(params[1], builderRects[builderType], params[2], activeBuilder == params[1] and 1.0 or 0.5, 0.05, 0)
	end

	local hotkey = keyConfig.sanitizeKey(Cfgs.CYCLE_BUILDER_KEY, currentLayout) or nil
	local hotkeyWidth = hotkey and (font2:GetTextWidth(hotkey) * hotkeyFontSize) + (bgpadding * 2) or 0

	-- draw hint
	local rect = Rect:new(
		buildersRect.xEnd+(bgpadding*3),
		buildersRect.y + ((buildersRect.yEnd - buildersRect.y) * 0.2)+iconMargin,
		buildersRect.xEnd + (builderButtonSize * 0.45) + hotkeyWidth+(bgpadding*3),
		buildersRect.yEnd - ((buildersRect.yEnd - buildersRect.y) * 0.2)+iconMargin
	)

	local text = "›"
	local rectSize = rect.yEnd - rect.y
	local fontSize = rectSize * 1.2
	local textHeight = font2:GetTextHeight(text) * fontSize
	font2:Print("\255\255\255\255" .. text,
		rect.x + math_floor(rectSize * 0.2),
		rect.y + ((rect.yEnd - rect.y) / 2) - math_floor(textHeight / 2),
		fontSize, "o"
	)

	local opts = {
		hovered = (hoveredButton == rect:getId()),
	}

	drawButton(rect, opts)
	drawButtonHotkey(rect, hotkey)
	nextBuilderRect = rect
end


local function drawGrid()
	local numCellsPerPage = rows * columns
	local cellRectID = 0

	cellcmds = {}

	for row = 1, 3 do
		for col = 1, 4 do
			cellRectID = cellRectID + 1

			local uDefID

			-- offset for pages
			local index = cellRectID + ((currentPage - 1) * numCellsPerPage)

			if gridOpts[index] then
				uDefID = -gridOpts[index].id
			end

			-- if gridmenu is on bottom, we need to remap positions from 2x6 -> 3x4 grid
			-- 3,1 -> 2,5
			-- 3,2 -> 2,6
			-- 3,3 -> 1,5
			-- 3,4 -> 1,6
			local rect
			local acol = col
			local arow = row
			if row > 2 and stickToBottom then
				arow = col < 3 and 2 or 1
				acol = 6 - col % 2
			end
			rect = Rect:new(
				buildpicsRect.x + (acol - 1) * cellSize,
				buildpicsRect.yEnd - (rows - arow + 1) * cellSize,
				buildpicsRect.x + (acol) * cellSize,
				buildpicsRect.yEnd - (rows - arow) * cellSize
			)

			if uDefID and gridOpts[index] then
				cellcmds[cellRectID] = gridOpts[index]

				gridOpts[index].hotkey = string.gsub(string.upper(Cfgs.keyLayout[row][col]), "ANY%+", '')
				hotkeyActions[tostring(row) .. tostring(col)] = -uDefID

				local udef = gridOpts[index]

				cellRects[cellRectID] = rect

				local cellIsSelected = (activeCmd and udef and activeCmd == udef.name) or
					(isPregame and selBuildQueueDefID == uDefID)
				local usedZoom = (cellIsSelected and selectedCellZoom or defaultCellZoom)

				drawCell(rect, gridOpts[index], usedZoom, cellIsSelected and { 1, 0.85, 0.2, 0.25 } or nil, units.unitRestricted[uDefID])
			else
				drawEmptyCell(rect)
				hotkeyActions[tostring(row) .. tostring(col)] = nil
			end
		end
	end

	if cellcmds[1] and (activeBuilder or isPregame) and switchedCategory then
		selectNextFrame = cellcmds[1].id
	end
end


local function drawBuildMenu()
	catRects = {}
	font2:Begin()

	if activeBuilder and not builderIsFactory then
		drawCategories()
	end

	-- adjust grid size when pages are needed
	if gridOptsCount > columns * rows then
		pages = math_ceil(gridOptsCount / (rows * columns))

		if currentPage > pages then
			currentPage = pages
		end
	else
		currentPage = 1
		pages = 1
	end

	-- these are globals so it can be re-used (hover highlight)
	cellPadding = math_floor(cellSize * Cfgs.cfgCellPadding)
	iconPadding = math_max(1, math_floor(cellSize * Cfgs.cfgIconPadding))
	cornerSize = math_floor(cellSize * Cfgs.cfgIconCornerSize)
	cellInnerSize = cellSize - cellPadding - cellPadding
	priceFontSize = math_floor((cellInnerSize * Cfgs.cfgPriceFontSize) + 0.5)

	cellRects = {}
	hotkeyActions = {}

	drawGrid()
	drawPaginators()
	drawBuilders()

	font2:End()
end


-- load all icons to prevent briefly showing white unit icons (will happen due to the custom texture filtering options)
local function cacheUnitIcons()
	local excludeScavs = not (Spring.Utilities.Gametype.IsScavengers() or Spring.GetModOptions().experimentalextraunits)
	local excludeChickens = not Spring.Utilities.Gametype.IsChickens()
	gl.Translate(-vsx,0,0)
	gl.Color(1, 1, 1, 0.001)
	for id, unit in pairs(UnitDefs) do
		if not excludeScavs or not string.find(unit.name,'_scav') then
			if not excludeChickens or not string.find(unit.name,'chicken') then
				gl.Texture('#'..id)
				gl.TexRect(-1, -1, 0, 0)
				if units.unitIconType[id] and iconTypesMap[units.unitIconType[id]] then
					gl.Texture(':l:' .. iconTypesMap[units.unitIconType[id]])
					gl.TexRect(-1, -1, 0, 0)
				end
			end
		end
	end
	gl.Color(1, 1, 1, 1)
	gl.Translate(vsx,0,0)
end

local function drawBuildProgress()
	local numCellsPerPage = rows * columns
	local maxCellRectID = numCellsPerPage * currentPage
	if maxCellRectID > gridOptsCount then
		maxCellRectID = gridOptsCount
	end

	local drawncellRectIDs = {}
	if activeBuilderID then
		local unitBuildID = spGetUnitIsBuilding(activeBuilderID)
		if unitBuildID then
			local unitBuildDefID = spGetUnitDefID(unitBuildID)
			if unitBuildDefID then
				-- loop all shown cells
				for cellRectID, cellRect in pairs(cellRects) do
					if not drawncellRectIDs[cellRectID] then
						if cellRectID > maxCellRectID then
							break
						end
						local cellUnitDefID = cellcmds[cellRectID].id * -1
						if unitBuildDefID == cellUnitDefID then
							drawncellRectIDs[cellRectID] = true
							local progress = 1 - select(5, spGetUnitHealth(unitBuildID))
							RectRoundProgress(cellRect.x + cellPadding + iconPadding, cellRect.y + cellPadding + iconPadding, cellRect.xEnd - cellPadding - iconPadding, cellRect.yEnd - cellPadding - iconPadding, cellSize * 0.03, progress, { 0.08, 0.08, 0.08, 0.6 })
						end
					end
				end
			end
		end
	end
end

function widget:DrawScreen()
	if (not cachedUnitIcons) and Spring.GetGameFrame() == 0 then
		cachedUnitIcons = true
		cacheUnitIcons()
	end

	if WG['buildmenu'] then
		WG['buildmenu'].hoverID = nil
	end
	if not (isPregame or activeBuilder or alwaysShow) then
		if WG['guishader'] and dlistGuishader then
			if dlistGuishader then
				WG['guishader'].RemoveDlist('buildmenu')
			end
			if dlistGuishaderBuilders then
				WG['guishader'].RemoveDlist('buildmenubuilders')
			end
		end
	else
		local x, y, b, b2, b3 = Spring.GetMouseState()
		local now = os.clock()
		if doUpdate or (doUpdateClock and now >= doUpdateClock) then
			if doUpdateClock and now >= doUpdateClock then
				doUpdateClock = nil
			end
			clear()
			RefreshCommands()
			doUpdate = nil
		end

		-- create buildmenu drawlists
		if WG['guishader'] and dlistGuishader then
			WG['guishader'].InsertDlist(dlistGuishader, 'buildmenu')
		end
		if not dlistBuildmenu then
			dlistBuildmenuBg = gl.CreateList(function()
				drawBuildMenuBg()
			end)
			dlistBuildmenu = gl.CreateList(function()
				drawBuildMenu()
			end)
		end

		checkGuishaderBuilders()

		local hovering = false
		if backgroundRect:contains(x, y) or buildersRect:contains(x, y) or nextBuilderRect:contains(x, y) then
			Spring.SetMouseCursor('cursornormal')
			hovering = true
		end

		-- draw buildmenu background
		gl.CallList(dlistBuildmenuBg)
		if isPregame or activeBuilder then
			-- pre process + 'highlight' under the icons
			local hoveredCellID
			local hoveredButtonNotFound = true
			if not WG['topbar'] or not WG['topbar'].showingQuit() then
				if hovering then
					for cellRectID, cellRect in pairs(cellRects) do
						if cellRect:contains(x, y) then
							hoveredCellID = cellRectID
							local cmd = cellcmds[cellRectID]
							local uDefID = cmd.id * -1
							WG['buildmenu'].hoverID = uDefID
							gl.Color(1, 1, 1, 1)
							local _, _, meta, _ = Spring.GetModKeyState()
							if WG['tooltip'] and not meta then
								-- when meta: unitstats does the tooltip
								local text
								local textColor = "\255\215\255\215"
								if units.unitRestricted[uDefID] then
									text = Spring.I18N('ui.buildMenu.disabled', { unit = UnitDefs[uDefID].translatedHumanName, textColor = textColor, warnColor = "\255\166\166\166" })
								else
									text = UnitDefs[uDefID].translatedHumanName
								end
								WG['tooltip'].ShowTooltip('buildmenu', "\255\240\240\240"..UnitDefs[uDefID].translatedTooltip, nil, nil, text)
							end

							-- highlight --if b and not disableInput then
							gl.Blending(GL_SRC_ALPHA, GL_ONE)
							RectRound(cellRect.x + cellPadding, cellRect.y + cellPadding, cellRect.xEnd - cellPadding, cellRect.yEnd - cellPadding, cellSize * 0.03, 1, 1, 1, 1, { 0, 0, 0, 0.1 * ui_opacity }, { 0, 0, 0, 0.1 * ui_opacity })
							gl.Blending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
							break
						end
					end

					-- category buttons
					for cat, catRect in pairs(catRects) do
						if catRect:contains(x, y) then
							hoveredButton = catRect:getId()

							if hoveredButton ~= drawnHoveredButton then
								doUpdate = true
							end


							if WG['tooltip'] then
								-- when meta: unitstats does the tooltip
								local textColor = "\255\215\255\215"

								local text =  Cfgs.categoryTooltips[cat]
								local index=0
								for k,v in pairs(categories) do
									if v == cat then
										index = k
									end
								end

								local catKey = keyConfig.sanitizeKey(Cfgs.keyLayout[1][index], currentLayout)
								text = text .. "\255\240\240\240 - Hotkey: " .. textColor .. "[" .. catKey .. "]"

								WG['tooltip'].ShowTooltip('buildmenu', text, nil, nil, cat)
							end

							hoveredButtonNotFound = false
							break
						end
					end

					-- paginator buttons
					if nextPageRect.y and nextPageRect:contains(x, y) then
						hoveredButton = nextPageRect:getId()
						hoveredButtonNotFound = false
						if WG['tooltip'] then
							local text = "\255\240\240\240" .. Spring.I18N('ui.buildMenu.nextPage')
							WG['tooltip'].ShowTooltip('buildmenu', text)
						end
					end

					if backRect.y and backRect:contains(x, y) then
						hoveredButton = backRect:getId()
						hoveredButtonNotFound = false
						if WG['tooltip'] then
							local text = "\255\240\240\240" .. Spring.I18N('ui.buildMenu.homePage')
							WG['tooltip'].ShowTooltip('buildmenu', text)
						end
					end

					-- builder buttons
					for i, rect in pairs(builderRects) do
						if rect:contains(x,y) then
							hoveredButton = rect:getId()
							hovering = true
							hoveredButtonNotFound = false

							local index = 0
							for unitDefID, _ in pairsByKeys(selectedBuilders) do
								index = index + 1
								if index == i then
									if WG['tooltip'] then
										name = UnitDefs[unitDefID].translatedHumanName
										WG['tooltip'].ShowTooltip('buildmenu', "\255\240\240\240" .. name)
									end
								end
							end
							break
						end
					end
					if nextBuilderRect:contains(x, y) then
						hoveredButton = nextBuilderRect:getId()
						hovering = true
						hoveredButtonNotFound = false
						if WG['tooltip'] then
							local text = "\255\240\240\240" .. Spring.I18N('ui.buildMenu.nextBuilder')
							WG['tooltip'].ShowTooltip('buildmenu', text)
						end
					end

					if hoveredButton ~= drawnHoveredButton then
						doUpdate = true
					end
				end
			end

			if (not hovering) or (activeBuilder and hoveredButtonNotFound) then
				if drawnHoveredButton then
					doUpdate = true
				end

				hoveredButton = nil
				drawnHoveredButton = nil
			end

			-- draw buildmenu content
			gl.CallList(dlistBuildmenu)

			-- draw highlight
			local usedZoom
			local cellColor
			if not WG['topbar'] or not WG['topbar'].showingQuit() then
				if hovering then

					-- cells
					if hoveredCellID then
						local uDefID = cellcmds[hoveredCellID].id * -1
						local cellIsSelected = (activeCmd and cellcmds[hoveredCellID] and activeCmd == cellcmds[hoveredCellID].name)
						if not prevHoveredCellID or hoveredCellID ~= prevHoveredCellID or uDefID ~= hoverUdefID or cellIsSelected ~= hoverCellSelected or b ~= prevB or b3 ~= prevB3 or cellcmds[hoveredCellID].params[1] ~= prevQueueNr then
							prevQueueNr = cellcmds[hoveredCellID].params[1]
							prevB = b
							prevB3 = b3
							prevHoveredCellID = hoveredCellID
							hoverUdefID = uDefID
							hoverCellSelected = cellIsSelected
							if hoverDlist then
								hoverDlist = gl.DeleteList(hoverDlist)
							end
							hoverDlist = gl.CreateList(function()

								-- determine zoom amount and cell color
								usedZoom = hoverCellZoom
								if not cellIsSelected then
									if (b or b2) and cellIsSelected then
										usedZoom = clickSelectedCellZoom
									elseif cellIsSelected then
										usedZoom = selectedCellZoom
									elseif (b or b2) and not disableInput then
										usedZoom = clickCellZoom
									elseif b3 and not disableInput and cellcmds[hoveredCellID].params[1] then
										-- has queue
										usedZoom = rightclickCellZoom
									end
									-- determine color
									if (b or b2) and not disableInput then
										cellColor = { 0.3, 0.8, 0.25, 0.2 }
									elseif b3 and not disableInput then
										cellColor = { 1, 0.35, 0.3, 0.2 }
									else
										cellColor = { 0.63, 0.63, 0.63, 0 }
									end
								else
									-- selected cell
									if (b or b2 or b3) then
										usedZoom = clickSelectedCellZoom
									else
										usedZoom = selectedCellZoom
									end
									cellColor = { 1, 0.85, 0.2, 0.25 }
								end
								if not units.unitRestricted[uDefID] then

									local unsetShowPrice
									if not showPrice then
										unsetShowPrice = true
										showPrice = true
									end

									drawCell(cellRects[hoveredCellID], cellcmds[hoveredCellID], usedZoom, cellColor, units.unitRestricted[uDefID])

									if unsetShowPrice then
										showPrice = false
										unsetShowPrice = nil
									end
								end
							end)
						end
						if hoverDlist then
							gl.CallList(hoverDlist)
						end
					end
				end
			end

			-- draw builders buildoption progress
			if showBuildProgress then
				drawBuildProgress()
			end
		end
	end
end

function widget:DrawWorld()
	-- Avoid unnecessary overhead after buildqueue has been setup in early frames
	if Spring.GetGameFrame() > 0 then
		widgetHandler:RemoveWidgetCallIn('DrawWorld', self)
		return
	end

	if not isPregame then return end

	if startDefID ~= Spring.GetTeamRulesParam(myTeamID, 'startUnit') then
		startDefID = Spring.GetTeamRulesParam(myTeamID, 'startUnit')
		doUpdate = true
	end

	if switchedCategory and selectNextFrame then
		setPreGamestartDefID(-selectNextFrame)
		switchedCategory = nil
		selectNextFrame = nil

		doUpdate = true
	end
end

function widget:UnitCommand(_, unitDefID, _, cmdID)
	if units.isFactory[unitDefID] and cmdID < 0 then
		-- filter away non build cmd's
		if doUpdateClock == nil then
			doUpdateClock = os.clock() + 0.01
		end
	end
end

function widget:SelectionChanged()
	updateSelection = true
end

function widget:GameStart()
	isPregame = false
	units.checkGeothermalFeatures()
end

function widget:KeyPress(key, modifier, isRepeat)
	if currentCategory and key == KEYSYMS.ESCAPE then
		currentCategory = nil
		doUpdate = true
	end
end

function clearCategory()
	currentCategory = nil
	Spring.SetActiveCommand(0, 0, false, false, Spring.GetModKeyState())
	doUpdate = true
end

function widget:KeyRelease(key)
	if key ~= KEYSYMS.LSHIFT then return end

	if isPregame then
		setPreGamestartDefID(nil)
	else
		clearCategory()
	end
end

function widget:MousePress(x, y, button)
	if Spring.IsGUIHidden() then
		return
	end
	if WG['topbar'] and WG['topbar'].showingQuit() then
		return
	end

	if buildmenuShows and (backgroundRect:contains(x, y) or buildersRect:contains(x, y) or nextBuilderRect:contains(x, y)) then
		if activeBuilder or (isPregame and startDefID) then
			if nextPageRect and nextPageRect:contains(x, y) then
				Spring.PlaySoundFile(Cfgs.sound_queue_add, 0.75, 'ui')
				nextPageHandler()
				return true
			end

			if backRect and backRect:contains(x, y) then
				Spring.PlaySoundFile(Cfgs.sound_queue_add, 0.75, 'ui')
				clearCategory()
			end

			for i, rect in pairs(builderRects) do
				if rect:contains(x,y) then
					setActiveBuilder(i)
					doUpdate = true
					return true
				end
			end
			if nextBuilderRect:contains(x, y) then
				cycleBuilder()
				doUpdate = true
				return true
			end

			if not disableInput then
				for cat, catRect in pairs(catRects) do
					if catRect:contains(x, y) then
						currentCategory = cat
						Spring.PlaySoundFile(Cfgs.sound_queue_add, 0.75, 'ui')

						doUpdate = true
						return true
					end
				end

				for cellRectID, cellRect in pairs(cellRects) do
					if cellcmds[cellRectID].id and UnitDefs[-cellcmds[cellRectID].id].translatedHumanName and cellRect:contains(x, y) and not units.unitRestricted[-cellcmds[cellRectID].id] then
						if button ~= 3 then
							Spring.PlaySoundFile(Cfgs.sound_queue_add, 0.75, 'ui')

							if isPregame then
								setPreGamestartDefID(cellcmds[cellRectID].id * -1)
							elseif spGetCmdDescIndex(cellcmds[cellRectID].id) then
								Spring.SetActiveCommand(spGetCmdDescIndex(cellcmds[cellRectID].id), 1, true, false, Spring.GetModKeyState())
							end
						elseif builderIsFactory and spGetCmdDescIndex(cellcmds[cellRectID].id) then
							Spring.PlaySoundFile(Cfgs.sound_queue_rem, 0.75, 'ui')
							Spring.SetActiveCommand(spGetCmdDescIndex(cellcmds[cellRectID].id), 3, false, true, Spring.GetModKeyState())
						end
						doUpdateClock = os.clock() + 0.01
						return true
					end
				end
			end
			return true
		elseif alwaysShow then
			return true
		end
	elseif activeBuilder and button == 3 then
		currentCategory = nil
		doUpdate = true
	end
end

function widget:Shutdown()
	clear()
	hoverDlist = gl.DeleteList(hoverDlist)
	if WG['guishader'] and dlistGuishader then
		WG['guishader'].DeleteDlist('buildmenu')
		WG['guishader'].DeleteDlist('buildmenubuilders')
		dlistGuishader = nil
	end
	WG['buildmenu'] = nil
end

function widget:GetConfigData()
	return {
		showPrice = showPrice,
		showRadarIcon = showRadarIcon,
		showGroupIcon = showGroupIcon,
		stickToBottom = stickToBottom,
		gameID = Game.gameID,
		alwaysShow = alwaysShow,
	}
end

function widget:SetConfigData(data)
	if data.showPrice ~= nil then
		showPrice = data.showPrice
	end
	if data.showRadarIcon ~= nil then
		showRadarIcon = data.showRadarIcon
	end
	if data.showGroupIcon ~= nil then
		showGroupIcon = data.showGroupIcon
	end
	if data.stickToBottom ~= nil then
		stickToBottom = data.stickToBottom
	end
	if data.alwaysShow ~= nil then
		alwaysShow = data.alwaysShow
	end
end
