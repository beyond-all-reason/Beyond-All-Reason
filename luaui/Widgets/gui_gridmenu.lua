--
-- Actions exposed:
--
-- gridmenu_key 1 1 <-- Sets the first grid key
-- gridmenu_next_page <-- Go to next page
-- gridmenu_prev_page <-- Go to previous page
-- gridmenu_cycle_builder <-- Go to next selected builder menu

-- PERF: refreshCommands does not need to fetch activecmddescs every time, e.g. setCurrentCategory
-- PERF: updateGrid should be replaced by a method that only updates prices on cells on places where setLabBuildMode is used followed by updateGrid
local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Grid menu",
		desc = "Build menu with grid hotkeys",
		author = "Floris, grid by badosu and resopmok",
		date = "October 2021",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
		handler = true,
	}
end

local useRenderToTexture = Spring.GetConfigFloat("ui_rendertotexture", 1) == 1		-- much faster than drawing via DisplayLists only

-------------------------------------------------------------------------------
--- CACHED VALUES
-------------------------------------------------------------------------------
local spGetCmdDescIndex = Spring.GetCmdDescIndex
local spGetActiveCommand = Spring.GetActiveCommand
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local spGetUnitIsBuilding = Spring.GetUnitIsBuilding
local spGetSelectedUnitsSorted = Spring.GetSelectedUnitsSorted
local spGiveOrderToUnit = Spring.GiveOrderToUnit

local math_floor = math.floor
local math_ceil = math.ceil
local math_max = math.max
local math_min = math.min
local math_clamp = math.clamp
local math_bit_and = math.bit_and

local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_ONE = GL.ONE
local GL_ONE_MINUS_SRC_COLOR = GL.ONE_MINUS_SRC_COLOR

local CMD_STOP_PRODUCTION = GameCMD.STOP_PRODUCTION
local CMD_INSERT = CMD.INSERT
local CMD_OPT_CTRL = CMD.OPT_CTRL
local CMD_OPT_SHIFT = CMD.OPT_SHIFT
local CMD_OPT_RIGHT = CMD.OPT_RIGHT

-------------------------------------------------------------------------------
--- STATIC VALUES
-------------------------------------------------------------------------------

local BUILDCAT_ECONOMY = Spring.I18N("ui.buildMenu.category_econ")
local BUILDCAT_COMBAT = Spring.I18N("ui.buildMenu.category_combat")
local BUILDCAT_UTILITY = Spring.I18N("ui.buildMenu.category_utility")
local BUILDCAT_PRODUCTION = Spring.I18N("ui.buildMenu.category_production")
local categoryTooltips = {
	[BUILDCAT_ECONOMY] = Spring.I18N("ui.buildMenu.category_econ_descr"),
	[BUILDCAT_COMBAT] = Spring.I18N("ui.buildMenu.category_combat_descr"),
	[BUILDCAT_UTILITY] = Spring.I18N("ui.buildMenu.category_utility_descr"),
	[BUILDCAT_PRODUCTION] = Spring.I18N("ui.buildMenu.category_production_descr"),
}

local folder = "LuaUI/Images/groupicons/"
local groups = {
	energy = folder .. "energy.png",
	metal = folder .. "metal.png",
	builder = folder .. "builder.png",
	buildert2 = folder .. "buildert2.png",
	buildert3 = folder .. "buildert3.png",
	buildert4 = folder .. "buildert4.png",
	util = folder .. "util.png",
	weapon = folder .. "weapon.png",
	explo = folder .. "weaponexplo.png",
	weaponaa = folder .. "weaponaa.png",
	weaponsub = folder .. "weaponsub.png",
	aa = folder .. "aa.png",
	emp = folder .. "emp.png",
	sub = folder .. "sub.png",
	nuke = folder .. "nuke.png",
	antinuke = folder .. "antinuke.png",
}

local CONFIG = {
	disableInputWhenSpec = false, -- disable specs selecting buildoptions
	cellPadding = 0.007,
	iconPadding = 0.015, -- space between icons
	iconCornerSize = 0.025,
	priceFontSize = 0.16,
	activeAreaMargin = 0.1, -- (# * bgpadding) space between the background border and active area
	sound_queue_add = "LuaUI/Sounds/buildbar_add.wav",
	sound_queue_rem = "LuaUI/Sounds/buildbar_rem.wav",

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
		BUILDCAT_PRODUCTION,
	},
}

local modKeyMultiplier = {
	click = {
		ctrl = 20,
		shift = 5,
		right = -1
	},
	keyPress = {
		ctrl = -1,
		shift = 5
	}
}

-------------------------------------------------------------------------------

local isSpec
local myTeamID
local startDefID

-- Configurable values
local stickToBottom = false
local alwaysReturn = false
local autoSelectFirst = true
local alwaysShow = false
local useLabBuildMode = false
local showPrice = false -- false will still show hover
local showRadarIcon = true -- false will still show hover
local showGroupIcon = true -- false will still show hover
local showBuildProgress = true

local defaultCategoryOpts = {}

local activeCmd
local gridOpts

local categories = {}
local currentlyBuildingRectID
local currentCategory
local labBuildModeActive = false

local activeBuilder, activeBuilderID, builderIsFactory
local buildmenuShows = false
local hoveredRect = false

-------------------------------------------------------------------------------
--- KEYBIND VALUES
-------------------------------------------------------------------------------

include("keysym.h.lua")

local keyConfig = VFS.Include("luaui/configs/keyboard_layouts.lua")
local currentLayout = Spring.GetConfigString("KeyboardLayout", "qwerty")
local categoryKeys = {}
local keyLayout = {}
local nextPageKey

-------------------------------------------------------------------------------
--- RECT HELPER
-------------------------------------------------------------------------------

local Rect = {}
function Rect:new(x1, y1, x2, y2, opts)
	local this = {
		x = x1,
		y = y1,
		xEnd = x2,
		yEnd = y2,
		opts = opts or {},
	}

	function this:contains(x, y)
		return x >= self.x and x <= self.xEnd and y >= self.y and y <= self.yEnd
	end

	function this:set(newX1, newY1, newX2, newY2, newOpts)
		this.x = newX1
		this.y = newY1
		this.xEnd = newX2
		this.yEnd = newY2

		if newOpts then
			this.opts = newOpts
		end
	end

	function this:getWidth()
		return self.xEnd - self.x
	end

	function this:getHeight()
		return self.yEnd - self.y
	end

	return this
end

-------------------------------------------------------------------------------
--- INTERFACE VALUES
-------------------------------------------------------------------------------

-- Get from FlowUI
local RectRound, RectRoundProgress, UiUnit, UiElement, UiButton, elementCorner, TexRectRound
local ui_opacity, ui_scale

local vsx, vsy = Spring.GetViewGeometry()

local ordermenuLeft = math.floor(vsx / 5)
local advplayerlistLeft = vsx * 0.8

local zoomMult = 1.5
local defaultCellZoom = 0.025 * zoomMult

local hoverCellZoom = 0.1 * zoomMult
local selectedCellZoom = 0.135 * zoomMult
local clickCellZoom = 0.125 * zoomMult

local hoverCellColor = { 0.63, 0.63, 0.63, 0 }
local selectedCellColor = { 1, 0.85, 0.2, 0.25 }
local clickCellColor = { 0.3, 0.8, 0.25, 0.2 }

local sec = 0
local bgpadding, iconMargin, activeAreaMargin
local dlistGuishader, dlistGuishaderBuilders, dlistGuishaderBuildersNext, dlistBuildmenu, dlistProgress, font2
local redraw, redrawProgress, ordermenuHeight, prevAdvplayerlistLeft
local doUpdate, doUpdateClock

local cellPadding, iconPadding, cornerSize, cellInnerSize, cellSize
local categoryFontSize, categoryButtonHeight, hotkeyFontSize, priceFontSize, pageFontSize
local builderButtonSize
local disableInput = CONFIG.disableInputWhenSpec and isSpec

local columns = 4
local rows = 3
local cellCount = rows * columns
local pages = 1
local currentPage = 1
local minimapHeight = 0.235

local selectedBuilders = {}
local prevSelectedBuilders = {}
local selectedBuildersCount = 0
local prevSelectedBuildersCount = 0

local cellRects = {}
for i = 1, cellCount do
	cellRects[i] = Rect:new(0, 0, 0, 0)
end
local uDefCellIds = {}

local catRects = {}
catRects[BUILDCAT_ECONOMY] = Rect:new(0, 0, 0, 0)
catRects[BUILDCAT_COMBAT] = Rect:new(0, 0, 0, 0)
catRects[BUILDCAT_UTILITY] = Rect:new(0, 0, 0, 0)
catRects[BUILDCAT_PRODUCTION] = Rect:new(0, 0, 0, 0)
local currentCategoryRect = Rect:new(0, 0, 0, 0)

local maxBuilderRects = 5
local nextBuilderRect = Rect:new(0, 0, 0, 0, {
	name = "›",
})
local builderRects = {}
for i = 1, maxBuilderRects do
	builderRects[i] = Rect:new(0, 0, 0, 0)
end

local backgroundRect = Rect:new(0, 0, 0, 0)
local backRect = Rect:new(0, 0, 0, 0, {
	name = "Back",
	keyText = "Shift",
})
local nextPageRect = Rect:new(0, 0, 0, 0)
local categoriesRect = Rect:new(0, 0, 0, 0)
local labBuildModeRect = Rect:new(0, 0, 0, 0)
local buildpicsRect = Rect:new(0, 0, 0, 0)
local buildersRect = Rect:new(0, 0, 0, 0)
local isPregame

-------------------------------------------------------------------------------
--- Unit prep
-------------------------------------------------------------------------------

local units = VFS.Include("luaui/configs/unit_buildmenu_config.lua")
local grid = VFS.Include("luaui/configs/gridmenu_config.lua")

local showWaterUnits = false
units.restrictWaterUnits(true)

local unitBuildOptions = {}
local unitMetal_extractor = {}
local unitTranslatedHumanName = {}
local unitTranslatedTooltip = {}
local iconTypes = {}

local function refreshUnitDefs()
	unitBuildOptions = {}
	unitMetal_extractor = {}
	unitTranslatedHumanName = {}
	unitTranslatedTooltip = {}
	iconTypes = {}
	local orgIconTypes = VFS.Include("gamedata/icontypes.lua")

	-- unit names and icons
	for udid, ud in pairs(UnitDefs) do
		unitBuildOptions[udid] = ud.buildOptions
		unitTranslatedHumanName[udid] = ud.translatedHumanName
		unitTranslatedTooltip[udid] = ud.translatedTooltip

		if ud.customParams.metal_extractor then
			unitMetal_extractor[udid] = ud.customParams.metal_extractor
		end
		if ud.iconType and orgIconTypes[ud.iconType] and orgIconTypes[ud.iconType].bitmap then
			iconTypes[ud.name] = orgIconTypes[ud.iconType].bitmap
		end
	end
end

-- starting units
local startUnits = { UnitDefNames.armcom.id, UnitDefNames.corcom.id }
if Spring.GetModOptions().experimentallegionfaction then
	startUnits[#startUnits + 1] = UnitDefNames.legcom.id
end
local startBuildOptions = {}
for _, uDefID in pairs(startUnits) do
	startBuildOptions[#startBuildOptions + 1] = uDefID
	for _, buildoptionDefID in pairs(UnitDefs[uDefID].buildOptions) do
		startBuildOptions[#startBuildOptions + 1] = buildoptionDefID
	end
end
startUnits = nil

-------------------------------------------------------------------------------
--- STATE MANAGEMENT
-------------------------------------------------------------------------------

local function resetHovered()
	for _, rects in ipairs({ catRects, builderRects }) do
		for _, rect in pairs(rects) do
			rect.opts.hovered = false
		end
	end

	for _, rect in pairs(cellRects) do
		rect.opts.hovered = false
	end

	WG["buildmenu"].hoverID = nil
	labBuildModeRect.opts.hovered = false
	nextBuilderRect.opts.hovered = false
	backRect.opts.hovered = false
	nextPageRect.opts.hovered = false
	hoveredRect = false
	redraw = true
end

local function setHoveredRect(rect, clicked)
	clicked = clicked or nil

	if rect.opts.clicked ~= clicked then
		for _, cellRect in pairs(cellRects) do
			cellRect.opts.clicked = nil
		end

		rect.opts.clicked = clicked
		redraw = true
	end

	if rect.opts.hovered and hoveredRect then
		return
	end

	resetHovered()

	hoveredRect = true
	rect.opts.hovered = true
end

local function setHoveredRectTooltip(rect, text, title, clicked)
	setHoveredRect(rect, clicked)

	if WG["tooltip"] then
		WG["tooltip"].ShowTooltip("buildmenu", text, nil, nil, title)
	end
end

local function updateHoverState()
	local x, y, left, _, right = Spring.GetMouseState()
	local isAboveBg = backgroundRect:contains(x, y)
	local isAboveBuilders = not isAboveBg
		and selectedBuildersCount > 1
		and (buildersRect:contains(x, y) or nextBuilderRect:contains(x, y))

	if isAboveBuilders then
		Spring.SetMouseCursor("cursornormal")

		-- builder buttons
		if nextBuilderRect:contains(x, y) then
			setHoveredRectTooltip(nextBuilderRect, "\255\240\240\240" .. Spring.I18N("ui.buildMenu.nextBuilder"))

			return
		end

		for _, rect in pairs(builderRects) do
			if rect:contains(x, y) then
				-- if we reached the first inactive builderRect we stop checking
				if not rect.opts.uDefID then
					break
				end

				setHoveredRectTooltip(
					rect,
					unitTranslatedTooltip[rect.opts.uDefID],
					unitTranslatedHumanName[rect.opts.uDefID]
				)

				return
			end
		end

		if hoveredRect then
			resetHovered()
		end

		return
	end

	if not isAboveBg then
		if hoveredRect then
			resetHovered()
		end

		return
	end

	Spring.SetMouseCursor("cursornormal")

	for _, cellRect in pairs(cellRects) do
		if cellRect:contains(x, y) then
			if not cellRect.opts.uDefID then
				if hoveredRect then
					resetHovered()
				end

				return
			end

			local uDefID = cellRect.opts.uDefID

			local text
			local textColor = "\255\215\255\215"
			if cellRect.opts.disabled then
				text = Spring.I18N("ui.buildMenu.disabled", {
					unit = unitTranslatedHumanName[uDefID],
					textColor = textColor,
					warnColor = "\255\166\166\166",
				})
			else
				text = unitTranslatedHumanName[uDefID]
			end
			local tooltip = unitTranslatedTooltip[uDefID]
			if unitMetal_extractor[uDefID] then
				tooltip = tooltip .. "\n" .. Spring.I18N("ui.buildMenu.areamex_tooltip")
			end

			setHoveredRectTooltip(cellRect, "\255\240\240\240" .. tooltip, text, left or right)
			WG["buildmenu"].hoverID = uDefID

			return
		end
	end

	-- category buttons
	if not currentCategory and not builderIsFactory then
		for cat, catRect in pairs(catRects) do
			if catRect:contains(x, y) then
				local text = categoryTooltips[cat]
					.. "\255\240\240\240 - Hotkey: \255\215\255\215["
					.. catRect.opts.keyText
					.. "]"

				setHoveredRectTooltip(catRect, text, cat)

				return
			end
		end
	end

	-- build mode button
	if builderIsFactory and (useLabBuildMode and not labBuildModeActive) and labBuildModeRect:contains(x, y) then
		setHoveredRectTooltip(labBuildModeRect, "\255\240\240\240" .. Spring.I18N("ui.buildMenu.buildmode_descr"))

		return
	end

	if currentCategory or labBuildModeActive then
		-- back button
		if backRect and backRect:contains(x, y) then
			setHoveredRectTooltip(backRect, "\255\240\240\240" .. Spring.I18N("ui.buildMenu.homePage"))

			return
		end
	end

	-- paginator buttons
	if pages > 1 and nextPageRect and nextPageRect:contains(x, y) then
		setHoveredRectTooltip(nextPageRect, "\255\240\240\240" .. Spring.I18N("ui.buildMenu.nextPage"))

		return
	end

	if hoveredRect then
		resetHovered()
	end
end

local function getCodedOptState(cmdOptsCoded, cmdOpt)
	return math_bit_and(cmdOptsCoded, cmdOpt) == cmdOpt
end

-- Retrieve from buildunit_ cmdOpts on factories the number of de/enqueued units
-- Reference should be FactoryCAI GetCountMultiplierFromOptions in engine
local function cmdOptsToFactoryQueueChange(cmdOpts)
	local optTable = {}
	if type(cmdOpts) == "number" then
		optTable.ctrl = getCodedOptState(cmdOpts, CMD_OPT_CTRL)
		optTable.shift = getCodedOptState(cmdOpts, CMD_OPT_SHIFT)
		optTable.right = getCodedOptState(cmdOpts, CMD_OPT_RIGHT)
	else
		optTable = cmdOpts
	end
	local count = optTable.right and modKeyMultiplier.click.right or 1

	if optTable.shift then
		count = count * modKeyMultiplier.click.shift
	end

	if optTable.ctrl then
		count = count * modKeyMultiplier.click.ctrl
	end

	return count
end

local function updateQuotaNumber(unitDefID, quantity)
	local cellId = uDefCellIds[unitDefID]
	if not cellId then
		return
	end
	local cellRect = cellRects[cellId]
	if WG.Quotas then
		for _, builderID in ipairs(Spring.GetSelectedUnitsSorted()[activeBuilder]) do
			local quotas = WG.Quotas.getQuotas()
			quotas[builderID] = quotas[builderID] or {}
			quotas[builderID][unitDefID] = quotas[builderID][unitDefID] or 0
			quotas[builderID][unitDefID] = math.max(quotas[builderID][unitDefID] + (quantity or 0), 0)
			cellRect.opts.quotanumber = quotas[builderID][unitDefID]
		end
		if quantity > 0 then
			Spring.PlaySoundFile(CONFIG.sound_queue_add, 0.75, "ui")
		else
			Spring.PlaySoundFile(CONFIG.sound_queue_rem, 0.75, "ui")
		end
	end
	redraw = true
end

local function updateQueueNr(unitDefID, count)
	-- if current grid has no option for currently built unit (e.g. pages) return
	local cellId = uDefCellIds[unitDefID]
	if not cellId then
		return
	end

	local cellRect = cellRects[cellId]
	local previousQueuenr = cellRect.opts.queuenr
	local queuenr = math_max((previousQueuenr or 0) + count, 0)

	if queuenr < 1 then
		queuenr = nil
	end

	if previousQueuenr == queuenr then
		return
	end

	cellRect.opts.queuenr = queuenr
	redraw = true
end

local function formatPrice(price)
	if price >= 1000 then
		return string.format("%s %03d", formatPrice(math_floor(price / 1000)), price % 1000)
	end
	return price
end

local function updateBuildProgress()
	currentlyBuildingRectID = nil

	if not showBuildProgress or not activeBuilderID then
		return
	end

	local unitBuildID = spGetUnitIsBuilding(activeBuilderID)
	local unitBuildDefID = unitBuildID and spGetUnitDefID(unitBuildID)

	currentlyBuildingRectID = uDefCellIds[unitBuildDefID]

	if not currentlyBuildingRectID then
		return
	end

	local rect = cellRects[currentlyBuildingRectID]

	rect.opts.progress = select(2, spGetUnitIsBeingBuilt(unitBuildID))

	redrawProgress = true
end

local function updateSelectedCell()
	for i = 1, cellCount do
		local cellRect = cellRects[i]
		cellRect.opts.selected = cellRect.opts.uDefID and activeCmd == -cellRect.opts.uDefID
	end

	redraw = true
end

local function updateGrid()
	if not gridOpts then
		return
	end

	-- update page data
	local gridOptsCount = table.count(gridOpts)

	if gridOptsCount > cellCount then
		pages = math_ceil(gridOptsCount / cellCount)

		if currentPage > pages then
			currentPage = pages
		end
	else
		currentPage = 1
		pages = 1
	end

	-- update cells data
	local cellRectID = 0

	-- well reindex the cellsidsperudef
	uDefCellIds = {}

	local showHotkeys = (builderIsFactory and not useLabBuildMode)
		or (builderIsFactory and useLabBuildMode and labBuildModeActive)
		or (activeBuilder and currentCategory)

	local offset = (currentPage - 1) * cellCount

	for row = 1, 3 do
		for col = 1, 4 do
			cellRectID = cellRectID + 1

			-- offset for pages
			local index = cellRectID + offset

			local uDefID
			local cmd = gridOpts[index]
			if cmd then
				uDefID = -cmd.id
			end

			local rect = cellRects[cellRectID]
			rect.opts.uDefID = uDefID

			if uDefID then
				uDefCellIds[uDefID] = cellRectID

				rect.opts.disabled = units.unitRestricted[uDefID]

				if showHotkeys then
					local hotkey = string.gsub(string.upper(keyLayout[row][col]), "ANY%+", "")
					rect.opts.hotkey = keyConfig.sanitizeKey(hotkey, currentLayout)
				else
					rect.opts.hotkey = nil
				end

				rect.opts.groupIcon = showRadarIcon and iconTypes[units.unitIconType[uDefID]]
				rect.opts.unitGroup = showGroupIcon and groups[units.unitGroup[uDefID]]

				rect.opts.metalCost = units.unitMetalCost[uDefID]
				rect.opts.energyCost = units.unitEnergyCost[uDefID]

				rect.opts.metalPrice = showPrice and formatPrice(rect.opts.metalCost)
				rect.opts.energyPrice = showPrice and formatPrice(rect.opts.energyCost)

				rect.opts.queuenr = cmd.params[1]

				-- reset progress, we'll update buildprogress later
				rect.opts.progress = nil
			end

			rect.opts.selected = uDefID and activeCmd == -uDefID
		end
	end

	updateBuildProgress()

	redraw = true
end

local function setupBuilderRects()
	local currentX = buildersRect.xEnd
	local y = buildersRect.y + iconMargin
	local yEnd = buildersRect.yEnd + iconMargin

	for i = 1, maxBuilderRects do
		currentX = currentX + bgpadding + iconMargin + builderButtonSize
		builderRects[i]:set(currentX - builderButtonSize, y, currentX, yEnd)
	end

	-- draw hint
	nextBuilderRect:set(
		0, -- We set x and xEnd dynamically depending on amount of selected builders
		y + buildersRect:getHeight() * 0.2,
		0,
		-- We set x and xEnd dynamically depending on amount of selected builders
		yEnd - buildersRect:getHeight() * 0.2
	)
	nextBuilderRect.opts.nameHeight = font2:GetTextHeight(nextBuilderRect.opts.name)
end

local function setupCells()
	local cellRectID = 0

	for row = 1, 3 do
		for col = 1, 4 do
			cellRectID = cellRectID + 1

			-- if gridmenu is on bottom, we need to remap positions from 2x6 -> 3x4 grid
			-- 3,1 -> 2,5
			-- 3,2 -> 2,6
			-- 3,3 -> 1,5
			-- 3,4 -> 1,6
			local acol = col
			local arow = row
			if row > 2 and stickToBottom then
				arow = col < 3 and 2 or 1
				acol = 6 - col % 2
			end
			cellRects[cellRectID]:set(
				buildpicsRect.x + (acol - 1) * cellSize,
				buildpicsRect.yEnd - (rows - arow + 1) * cellSize,
				buildpicsRect.x + acol * cellSize,
				buildpicsRect.yEnd - (rows - arow) * cellSize
			)
		end
	end
end

local function setupCategoryRects()
	-- set up rects
	if stickToBottom then
		local x1 = categoriesRect.x
		local contentHeight = (categoriesRect.yEnd - categoriesRect.y) / #CONFIG.buildCategories
		local contentWidth = categoriesRect.xEnd - categoriesRect.x

		for i, cat in ipairs(CONFIG.buildCategories) do
			local y1 = categoriesRect.yEnd - i * contentHeight + 2
			catRects[cat]:set(
				x1,
				y1,
				x1 + contentWidth - activeAreaMargin,
				y1 + contentHeight - 2,
				defaultCategoryOpts[i]
			)
		end

		local y1 = ((categoriesRect.yEnd - categoriesRect.y) / 2) - (contentHeight / 2)

		currentCategoryRect:set(x1, y1, x1 + contentWidth - activeAreaMargin, y1 + contentHeight - 2)
	else
		local buttonWidth = math.round(((categoriesRect.xEnd - categoriesRect.x) / #CONFIG.buildCategories))
		local padding = math_max(1, math_floor(bgpadding * 0.52))
		local y2 = categoriesRect.yEnd
		for i, cat in ipairs(CONFIG.buildCategories) do
			local x1 = categoriesRect.x + (i - 1) * buttonWidth

			catRects[cat]:set(
				x1,
				y2 - categoryButtonHeight + padding,
				x1 + buttonWidth,
				y2 - activeAreaMargin - padding,
				defaultCategoryOpts[i]
			)
		end
		local x1 = (math.round(categoriesRect.xEnd - categoriesRect.x) / 2) - (buttonWidth / 2)
		currentCategoryRect:set(
			x1,
			y2 - categoryButtonHeight + padding,
			x1 + buttonWidth,
			y2 - activeAreaMargin - padding
		)
	end
end

local function updateCategories(newCategories)
	categories = newCategories

	for _, cat in pairs(categories) do
		local rect = catRects[cat]

		rect.opts.current = cat == currentCategory
	end
end

local function updateBuilders()
	local builderTypes = 0

	for unitDefID, count in pairsByKeys(selectedBuilders) do
		builderTypes = builderTypes + 1

		builderRects[builderTypes].opts.uDefID = unitDefID
		builderRects[builderTypes].opts.count = count

		if builderTypes == maxBuilderRects then
			break
		end
	end

	if builderTypes == 0 then
		return
	end

	-- check if builder type selection actually differs from previous selection
	local changes = false
	if #selectedBuilders ~= #prevSelectedBuilders then
		changes = true
	else
		for unitDefID, count in pairs(prevSelectedBuilders) do
			if not selectedBuilders[unitDefID] then
				changes = true
				break
			end
		end
		if not changes then
			for unitDefID, count in pairs(selectedBuilders) do
				if not prevSelectedBuilders[unitDefID] then
					changes = true
					break
				end
			end
		end
	end
	if not changes then
		return
	end

	-- grow buildersRect according to current number of selected builders
	buildersRect.xEnd = builderRects[builderTypes].xEnd

	local keyText = nextBuilderRect.opts.keyText

	-- PERF: Move to a more static place, we only need to set this when viewresize or reloadbindings
	local hotkeyWidth = keyText and (font2:GetTextWidth(keyText) * hotkeyFontSize) + (bgpadding * 2) or 0

	nextBuilderRect.x = buildersRect.xEnd + (bgpadding * 3)
	nextBuilderRect.xEnd = buildersRect.xEnd + (builderButtonSize * 0.45) + hotkeyWidth + (bgpadding * 3)

	-- PERF: Move to a more static place, we only need to set this when viewresize or reloadbindings
	nextBuilderRect.opts.keyTextHeight = font2:GetTextHeight(keyText)

	redraw = true
end

-------------------------------------------------------------------------------
--- HOTKEY AND ACTION HANDLING
-------------------------------------------------------------------------------

local function refreshCommands()
	gridOpts = nil

	if isPregame and startDefID then
		activeBuilder = startDefID
	end

	if not activeBuilder then
		if alwaysShow then
			gridOpts = {}
		else
			return
		end
	elseif builderIsFactory then
		local activeCmdDescs = Spring.GetUnitCmdDescs(activeBuilderID)

		if activeCmdDescs then
			gridOpts = grid.getSortedGridForLab(activeBuilder, activeCmdDescs)
		end
	else
		updateCategories(CONFIG.buildCategories)

		local buildOptions = unitBuildOptions[activeBuilder]
		gridOpts = grid.getSortedGridForBuilder(activeBuilder, buildOptions, currentCategory)
	end

	updateGrid()
end

local function getActionHotkey(action)
	local key
	for _, keybinding in pairs(Spring.GetActionHotKeys(action)) do
		if (not key) or keybinding:len() < key:len() then
			key = keybinding
		end

		if key:len() == 1 then
			break
		end
	end

	return key
end

-- Helper function for iterating over the actions with builder and factory tags,
-- with GetActionHotKeys those tags will be missed and the hotkey wont work
local function getGridKey(action)
	local key = getActionHotkey(action)
		or getActionHotkey(action .. " builder")
		or getActionHotkey(action .. " factory")
	return key
end

local function reloadBindings()
	currentLayout = Spring.GetConfigString("KeyboardLayout", "qwerty")

	keyLayout = { {}, {}, {} }

	for c = 1, 4 do
		local categoryAction = "gridmenu_category " .. c
		local cKey = getActionHotkey(categoryAction)

		if not cKey then
			cKey = ""
		end

		categoryKeys[c] = cKey

		for r = 1, 3 do
			local keyAction = "gridmenu_key " .. r .. " " .. c
			local key = getGridKey(keyAction)

			if not key then
				key = ""
			end

			keyLayout[r][c] = key
		end
	end

	local key = getActionHotkey("gridmenu_next_page")

	nextPageKey = key

	key = getActionHotkey("gridmenu_cycle_builder")

	nextBuilderRect.opts.keyText = keyConfig.sanitizeKey(key, currentLayout) or nil
end

local function setLabBuildMode(value)
	labBuildModeActive = value
	redraw = true
end

local function setActiveCommand(cmd, button, leftClick, rightClick)
	local didChangeCmd = button and Spring.SetActiveCommand(cmd, button, leftClick, rightClick, Spring.GetModKeyState())
		or Spring.SetActiveCommand(cmd)

	if not didChangeCmd then
		Spring.Echo("<Grid menu> Unable to change active command", cmd)
		return
	end

	activeCmd = select(2, spGetActiveCommand())

	updateSelectedCell()
end

local function pickBlueprint(uDefID)
	local isRepeatMex = unitMetal_extractor[uDefID] and -uDefID == activeCmd
	local cmd = (WG["areamex"] and isRepeatMex and "areamex") or spGetCmdDescIndex(-uDefID)
	if isRepeatMex and WG["areamex"] then
		WG["areamex"].setAreaMexType(-uDefID)
	end
	setActiveCommand(cmd)
end

local function setCurrentCategory(category)
	local changedCategory = category and currentCategory ~= category

	currentCategory = category

	if category then
		currentCategoryRect.opts = catRects[category].opts
	end

	updateCategories(categories)
	refreshCommands()

	-- handle selecting first option when switching category
	if changedCategory and autoSelectFirst and activeBuilder then
		local offset = (currentPage - 1) * cellCount

		local firstCmd

		-- Get first available cell command
		for i = offset + 1, offset + cellCount do
			local cellCmdOpt = gridOpts[i]
			local cellCmd = cellCmdOpt and cellCmdOpt.id

			if cellCmd and not units.unitRestricted[-cellCmd] then
				firstCmd = cellCmd
				break
			end
		end

		if not firstCmd then
			return
		end

		if isPregame then
			-- here we repeat setPregameBlueprint, but we can't have circular dependencies
			activeCmd = firstCmd

			if WG["pregame-build"] and WG["pregame-build"].setPreGamestartDefID then
				WG["pregame-build"].setPreGamestartDefID(-firstCmd)
			end

			updateSelectedCell()
		else
			pickBlueprint(-firstCmd)
		end
	end
end

local function setPregameBlueprint(uDefID)
	if not isPregame then
		return
	end

	activeCmd = uDefID and -uDefID
	if WG["pregame-build"] and WG["pregame-build"].setPreGamestartDefID then
		WG["pregame-build"].setPreGamestartDefID(uDefID)
	end

	if not uDefID then
		setCurrentCategory(nil)
	end
end

local function queueUnit(uDefID, opts, quantity)
	local sel = spGetSelectedUnitsSorted()
	for unitDefID, unitIds in pairs(sel) do
		if units.isFactory[unitDefID] then
			for _, uid in ipairs(unitIds) do
				for _ = 1,quantity,1 do
					spGiveOrderToUnit(uid, -uDefID, {}, opts)
				end
			end
		end
	end
end

local function clearCategory()
	setLabBuildMode(false)

	if isPregame then
		setPregameBlueprint(nil)
	else
		setCurrentCategory(nil)
		setActiveCommand(0)
	end
end

local function gridmenuCategoryHandler(_, _, args)
	local cIndex = args and tonumber(args[1])
	if not cIndex or cIndex < 1 or cIndex > 4 then
		return
	end
	if builderIsFactory and useLabBuildMode and not labBuildModeActive then
		Spring.PlaySoundFile(CONFIG.sound_queue_add, 0.75, "ui")
		setLabBuildMode(true)
		updateGrid()
		return true
	end

	if not activeBuilder or builderIsFactory or (currentCategory and cellRects[cIndex]) then
		return
	end

	local alt, ctrl, meta, _ = Spring.GetModKeyState()
	if alt or ctrl or meta then
		return
	end

	setCurrentCategory(categories[cIndex])

	return true
end

local function gridmenuKeyHandler(_, _, args, _, isRepeat)
	if builderIsFactory and useLabBuildMode and not labBuildModeActive then
		return
	end
	-- validate args
	local row = args and tonumber(args[1])
	local col = args and tonumber(args[2])

	if (not row or row < 1 or row > 3) or (not col or col < 1 or col > 4) then
		return
	end

	local uDefID = cellRects[(row - 1) * 4 + col].opts.uDefID -- cellRects iterate row then column
	if not uDefID or units.unitRestricted[uDefID] then
		return
	end

	if isRepeat and activeBuilder then
		return currentCategory and true or false
	end

	local alt, ctrl, meta, shift = Spring.GetModKeyState()

	if builderIsFactory then
		local quantity = 1
		if shift then
			quantity = modKeyMultiplier.keyPress.shift
		end

		if ctrl then
			quantity = quantity * modKeyMultiplier.keyPress.ctrl
		end

		if WG.Quotas and WG.Quotas.isOnQuotaMode(activeBuilderID) and not alt then
			updateQuotaNumber(uDefID,quantity)
			return true
		else
			if args[3] and args[3] == "builder" then
				return false
			end

			local opts

			if quantity < 0 then
				quantity = quantity * -1
				opts = { "right" }
				Spring.PlaySoundFile(CONFIG.sound_queue_rem, 0.75, "ui")
			else
				opts = { "left" }
				Spring.PlaySoundFile(CONFIG.sound_queue_add, 0.75, "ui")

				--if quantity is divisible by 20 or 5 like most sane people will set it as then use engine logic for better performance
				if opts ~= { "right" } and math.fmod(quantity,20) == 0 then
					opts = { "left","ctrl" }
					quantity = quantity / 20
				elseif opts ~= { "right" } and math.fmod(quantity,5) == 0 then
					opts = { "left","shift" }
					quantity = quantity / 5
				end
			end
			if alt then
				table.insert(opts, "alt")
			end

			queueUnit(uDefID, opts, quantity)

			return true
		end
	elseif isPregame and currentCategory then
		if alt or ctrl or meta then
			return
		end
		if args[3] and args[3] == "factory" then
			return false
		end

		setPregameBlueprint(uDefID)
		updateGrid()
		return true
	elseif activeBuilder and currentCategory then
		if args[3] and args[3] == "factory" then
			return false
		end
		if alt or ctrl or meta then
			return
		end

		pickBlueprint(uDefID)
		return true
	end

	return false
end

local function nextPageHandler()
	if pages < 2 or not activeBuilder then
		return
	end
	currentPage = currentPage == pages and 1 or currentPage + 1

	updateGrid()
end

---Set active builder based on index in selectedBuilders
---@param index number
---@return nil
local function setActiveBuilder(index, selectedUnitsSorted)
	selectedUnitsSorted = selectedUnitsSorted or spGetSelectedUnitsSorted()

	for i = 1, maxBuilderRects do
		local rect = builderRects[i]

		builderRects[i].opts.current = nil

		if i == index then
			local unitDefID = rect.opts.uDefID
			local unitID = selectedUnitsSorted[unitDefID][1]

			if unitID then
				activeBuilder = unitDefID
				activeBuilderID = unitID

				builderIsFactory = units.isFactory[unitDefID]

				builderRects[i].opts.current = true
			end
		end
	end
end

---Switch to next builder type out of selected builders
local function cycleBuilder()
	if selectedBuildersCount < 2 then
		return
	end

	-- find the index we want to switch to
	local index = nil
	for i = 1, selectedBuildersCount do
		if activeBuilder == builderRects[i].opts.uDefID then
			index = i % selectedBuildersCount
			break
		end
	end

	if not index then
		return
	end

	setActiveBuilder(index + 1)

	refreshCommands()
end

function widget:Initialize()
	refreshUnitDefs()

	if widgetHandler:IsWidgetKnown("Build menu") then
		-- Build menu needs to be disabled right now and before we recreate
		-- WG['buildmenu'] since its Shutdown will destroy it.
		widgetHandler:DisableWidgetRaw("Build menu")
	end

	myTeamID = Spring.GetMyTeamID()
	isSpec = Spring.GetSpectatingState()
	isPregame = Spring.GetGameFrame() == 0 and not isSpec

	WG["gridmenu"] = {}
	WG["buildmenu"] = {}

	doUpdateClock = os.clock()

	units.checkGeothermalFeatures()

	widgetHandler.actionHandler:AddAction(self, "gridmenu_key", gridmenuKeyHandler, nil, "pR")
	widgetHandler.actionHandler:AddAction(self, "gridmenu_category", gridmenuCategoryHandler, nil, "p")
	widgetHandler.actionHandler:AddAction(self, "gridmenu_next_page", nextPageHandler, nil, "p")
	widgetHandler.actionHandler:AddAction(self, "gridmenu_cycle_builder", cycleBuilder, nil, "p")

	reloadBindings()

	-- Setup some semi-static data so we don't need to perform in-game
	for catIndex, cat in pairs(CONFIG.buildCategories) do
		local keyText = keyConfig.sanitizeKey(categoryKeys[catIndex], currentLayout)

		defaultCategoryOpts[catIndex] = {
			name = cat,
			icon = CONFIG.categoryIcons[catIndex],
			keyText = keyText,
		}
	end

	ui_opacity = WG.FlowUI.opacity
	ui_scale = WG.FlowUI.scale

	-- Get our starting unit
	if isPregame then
		startDefID = Spring.GetTeamRulesParam(myTeamID, "startUnit")
	end

	widget:ViewResize()

	if isPregame then
		refreshCommands()
	else
		widget:SelectionChanged(Spring.GetSelectedUnits())
	end

	WG["gridmenu"].getAlwaysReturn = function()
		return alwaysReturn
	end
	WG["gridmenu"].setAlwaysReturn = function(value)
		alwaysReturn = value
	end
	WG["gridmenu"].getAutoSelectFirst = function()
		return autoSelectFirst
	end
	WG["gridmenu"].setAutoSelectFirst = function(value)
		autoSelectFirst = value
	end
	WG["gridmenu"].getUseLabBuildMode = function()
		return useLabBuildMode
	end
	WG["gridmenu"].setUseLabBuildMode = function(value)
		useLabBuildMode = value
		updateGrid()
	end
	WG["gridmenu"].setCurrentCategory = function(category)
		setCurrentCategory(category)
	end
	WG["gridmenu"].clearCategory = function()
		clearCategory()
	end

	WG["gridmenu"].getCtrlClickModifier = function()
		return modKeyMultiplier.click.ctrl
	end
	WG["gridmenu"].setCtrlClickModifier = function(value)
		modKeyMultiplier.click.ctrl = value
	end
	WG["gridmenu"].getShiftClickModifier = function()
		return modKeyMultiplier.click.shift
	end
	WG["gridmenu"].setShiftClickModifier = function(value)
		modKeyMultiplier.click.shift = value
	end

	WG["gridmenu"].getCtrlKeyModifier = function()
		return modKeyMultiplier.keyPress.ctrl
	end
	WG["gridmenu"].setCtrlKeyModifier = function(value)
		modKeyMultiplier.keyPress.ctrl = value
	end
	WG["gridmenu"].getShiftKeyModifier = function()
		return modKeyMultiplier.keyPress.shift
	end
	WG["gridmenu"].setShiftKeyModifier = function(value)
		modKeyMultiplier.keyPress.shift = value
	end

	WG["buildmenu"].getGroups = function()
		return groups, units.unitGroup
	end
	WG["buildmenu"].getOrder = function()
		return units.unitOrder
	end
	WG["buildmenu"].getShowPrice = function()
		return showPrice
	end
	WG["buildmenu"].setShowPrice = function(value)
		showPrice = value
		updateGrid()
	end
	WG["buildmenu"].getAlwaysShow = function()
		return alwaysShow
	end
	WG["buildmenu"].setAlwaysShow = function(value)
		alwaysShow = value
		refreshCommands()
	end
	WG["buildmenu"].getShowRadarIcon = function()
		return showRadarIcon
	end
	WG["buildmenu"].setShowRadarIcon = function(value)
		showRadarIcon = value
		updateGrid()
	end
	WG["buildmenu"].getShowGroupIcon = function()
		return showGroupIcon
	end
	WG["buildmenu"].setShowGroupIcon = function(value)
		showGroupIcon = value
		updateGrid()
	end
	WG["buildmenu"].getBottomPosition = function()
		return stickToBottom
	end
	WG["buildmenu"].setBottomPosition = function(value)
		stickToBottom = value
		widget:ViewResize()
	end
	WG["buildmenu"].getSize = function()
		return backgroundRect.y, backgroundRect.yEnd
	end
	WG["buildmenu"].reloadBindings = function()
		reloadBindings()
		refreshCommands()
	end
	WG["buildmenu"].getIsShowing = function()
		return buildmenuShows
	end
end

-------------------------------------------------------------------------------
--- INTERFACE SETUP
-------------------------------------------------------------------------------

local function checkGuishader(force)
	if WG["guishader"] then
		if force and dlistGuishader then
			dlistGuishader = gl.DeleteList(dlistGuishader)
		end
		if not dlistGuishader then
			dlistGuishader = gl.CreateList(function()
				RectRound(backgroundRect.x, backgroundRect.y, backgroundRect.xEnd, backgroundRect.yEnd, elementCorner)
			end)
			if activeBuilder then
				WG["guishader"].InsertDlist(dlistGuishader, "buildmenu")
			end
		end
	elseif dlistGuishader then
		dlistGuishader = gl.DeleteList(dlistGuishader)
	end
end

-- Set up all of the UI positioning
function widget:ViewResize()
	vsx, vsy = Spring.GetViewGeometry()

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
	categoryFontSize = 0.013 * ui_scale * vsy
	hotkeyFontSize = categoryFontSize + 5
	pageFontSize = categoryFontSize
	categoryButtonHeight = math_floor(2.3 * categoryFontSize * ui_scale)
	builderButtonSize = categoryButtonHeight * 2

	activeAreaMargin = math_ceil(bgpadding * CONFIG.activeAreaMargin)

	font2 = WG['fonts'].getFont(2)

	for i, rectOpts in ipairs(defaultCategoryOpts) do
		defaultCategoryOpts[i].nameHeight = font2:GetTextHeight(rectOpts.name)
		defaultCategoryOpts[i].keyTextHeight = font2:GetTextHeight(rectOpts.keyText)
	end

	backRect.opts.keyTextHeight = font2:GetTextHeight(backRect.opts.name)

	if WG["minimap"] then
		minimapHeight = WG["minimap"].getHeight()
	end

	-- if stick to bottom we know cells are 2 row by 6 column
	if stickToBottom then
		local posY = math_floor(0.14 * ui_scale * vsy)
		local posYEnd = 0
		local posX = ordermenuLeft + widgetSpaceMargin
		local height = posY
		builderButtonSize = math_floor(categoryButtonHeight * 1.75)

		rows = 2
		columns = 6
		cellSize = math_floor((height - bgpadding) / rows)

		local categoryWidth = 10 * categoryFontSize * ui_scale

		-- assemble rects left to right
		categoriesRect:set(posX + bgpadding, posYEnd, posX + categoryWidth, posY - bgpadding)

		buildpicsRect:set(
			categoriesRect.xEnd + bgpadding,
			posYEnd,
			categoriesRect.xEnd + (cellSize * columns) + bgpadding,
			posY - bgpadding
		)

		backgroundRect:set(posX, posYEnd, buildpicsRect.xEnd + bgpadding, posY)

		local buttonHeight = categoriesRect:getHeight() / 4
		backRect:set(
			categoriesRect.x,
			categoriesRect.yEnd - buttonHeight + bgpadding,
			categoriesRect.xEnd,
			categoriesRect.yEnd
		)

		nextPageRect:set(
			categoriesRect.x,
			categoriesRect.y + bgpadding,
			categoriesRect.xEnd,
			categoriesRect.y + buttonHeight - bgpadding
		)

		labBuildModeRect:set(
			categoriesRect.x,
			categoriesRect.y + buttonHeight + bgpadding,
			categoriesRect.xEnd,
			categoriesRect.yEnd - bgpadding
		)

		-- start with no width and grow dynamically
		buildersRect:set(posX, backgroundRect.yEnd, posX, backgroundRect.yEnd + builderButtonSize)
	else -- if stick to side we know cells are 3 row by 4 column
		local width = 0.2125 -- hardcoded width to match bottom element
		width = width / (vsx / vsy) * 1.78 -- make smaller for ultrawide screens
		width = width * ui_scale

		-- 0.14 is the space required to put this above the bottom-left UI element
		local posYEnd = math_floor(0.14 * ui_scale * vsy) + widgetSpaceMargin
		local posY = math_floor(posYEnd + ((0.74 * vsx) * width)) / vsy
		local posX = 0

		if WG["ordermenu"] and not WG["ordermenu"].getBottomPosition() then
			local _, oposY, _, oheight = WG["ordermenu"].getPosition()
			if posY > oposY then
				posY = (oposY - oheight - (widgetSpaceMargin / vsy))
			end
		end

		local posXEnd = math_floor(width * vsx)

		-- make pixel aligned
		width = posXEnd - posX

		categoryButtonHeight = categoryButtonHeight * 1.4

		-- assemble rects, bottom to top
		categoriesRect:set(
			posX + bgpadding,
			posYEnd + bgpadding,
			posXEnd - bgpadding,
			posYEnd + categoryButtonHeight + bgpadding
		)

		rows = 3
		columns = 4
		cellSize = math_floor((width - (bgpadding * 2)) / columns)

		buildpicsRect:set(
			posX + bgpadding,
			categoriesRect.yEnd,
			posXEnd - bgpadding,
			categoriesRect.yEnd + (cellSize * rows)
		)

		backgroundRect:set(posX, posYEnd, posXEnd, math_floor(buildpicsRect.yEnd + (bgpadding * 1.5)))

		local buttonWidth = (categoriesRect.xEnd - categoriesRect.x) / 3
		local padding = math_max(1, math_floor(bgpadding * 0.52))
		backRect:set(
			categoriesRect.x,
			categoriesRect.y + padding,
			categoriesRect.x + buttonWidth - (bgpadding * 2),
			categoriesRect.yEnd - padding
		)

		nextPageRect:set(
			categoriesRect.xEnd - buttonWidth + (2 * bgpadding),
			categoriesRect.y + padding,
			categoriesRect.xEnd,
			categoriesRect.yEnd - padding
		)

		labBuildModeRect:set(
			categoriesRect.x,
			categoriesRect.y + padding,
			nextPageRect.x - (2 * bgpadding),
			categoriesRect.yEnd - padding
		)

		-- start with no width and grow dynamically
		buildersRect:set(posX, backgroundRect.yEnd, posX, backgroundRect.yEnd + builderButtonSize)
	end

	cellPadding = math_floor(cellSize * CONFIG.cellPadding)
	iconPadding = math_max(1, math_floor(cellSize * CONFIG.iconPadding))
	cornerSize = math_floor(cellSize * CONFIG.iconCornerSize)
	cellInnerSize = cellSize - cellPadding - cellPadding
	priceFontSize = math_floor((cellInnerSize * CONFIG.priceFontSize) + 0.5)

	setupCategoryRects()
	setupCells()
	setupBuilderRects()

	checkGuishader(true)

	redraw = true

	if buildmenuTex then
		gl.DeleteTexture(buildmenuBgTex)
		buildmenuBgTex = nil
		gl.DeleteTexture(buildmenuTex)
		buildmenuTex = nil
	end
	updateGrid()
end

-- PERF: It seems we get i18n resources inside draw functions, we should do that in state instead
function widget:LanguageChanged()
	refreshUnitDefs()
	redraw = true
end

function widget:GameFrame()
	-- build progress updates every sym frame
	updateBuildProgress()
end

-- Sometimes we issue commands the game state hasn't changed yet, to actually
-- sync state we need to do it a while later.
--
-- Unfortunately some callins like UnitCommand are invoked
-- without having actually updated the internal state of the factory. So they
-- only schedule a resync instead of syncing state.
function widget:Update(dt)
	sec = sec + dt
	if sec > 0.33 then
		sec = 0
		checkGuishader()
		if WG["minimap"] and minimapHeight ~= WG["minimap"].getHeight() then
			widget:ViewResize()

			if not isPregame then
				updateBuilders() -- builder rects are defined dynamically
			end
		end

		local _, _, mapMinWater, _ = Spring.GetGroundExtremes()
		if mapMinWater <= units.minWaterUnitDepth and not showWaterUnits then
			showWaterUnits = true
			units.restrictWaterUnits(false)
		end

		local prevOrdermenuLeft = ordermenuLeft
		local prevOrdermenuHeight = ordermenuHeight
		if WG["ordermenu"] then
			local oposX, _, owidth, oheight = WG["ordermenu"].getPosition()
			ordermenuLeft = math_floor((oposX + owidth) * vsx)
			ordermenuHeight = oheight
		end
		if
			not prevAdvplayerlistLeft
			or advplayerlistLeft ~= prevAdvplayerlistLeft
			or not prevOrdermenuLeft
			or ordermenuLeft ~= prevOrdermenuLeft
			or not prevOrdermenuHeight
			or ordermenuHeight ~= prevOrdermenuHeight
		then
			widget:ViewResize()
			if not isPregame then
				updateBuilders() -- builder rects are defined dynamically
			end
			prevAdvplayerlistLeft = advplayerlistLeft
		end

		disableInput = CONFIG.disableInputWhenSpec and isSpec
		if Spring.IsGodModeEnabled() then
			disableInput = false
		end
	end

	local prevBuildmenuShows = buildmenuShows
	if not (isPregame or activeBuilder or alwaysShow) then
		buildmenuShows = false
	else
		buildmenuShows = true
	end

	if WG['guishader'] and prevBuildmenuShows ~= buildmenuShows and dlistGuishader then
		if buildmenuShows then
			WG['guishader'].InsertDlist(dlistGuishader, 'buildmenu')
		else
			WG['guishader'].RemoveDlist('buildmenu')
		end
	end

	if not buildmenuShows then
		return
	end

	if activeBuilder then
		updateHoverState()
	end

	local prevActiveCmd = activeCmd

	-- PERF: Maybe make this slow-ish-update?
	if isPregame then
		local previousStartDefID = startDefID
		startDefID = Spring.GetTeamRulesParam(myTeamID, "startUnit")

		-- Don't update unless defid has changed
		doUpdate = previousStartDefID ~= startDefID
	else
		activeCmd = select(2, spGetActiveCommand())

		if activeCmd ~= prevActiveCmd then
			doUpdate = true
		end
	end

	if doUpdate or (doUpdateClock and doUpdateClock > os.clock()) then
		refreshCommands()

		doUpdateClock = nil
		doUpdate = nil
	end
end

-------------------------------------------------------------------------------
--- INTERFACE DRAWING
-------------------------------------------------------------------------------

local function drawBuildMenuBg()
	local height = backgroundRect.yEnd - backgroundRect.y
	local posY = backgroundRect.y
	UiElement(
		backgroundRect.x,
		backgroundRect.y,
		backgroundRect.xEnd,
		backgroundRect.yEnd,
		(backgroundRect.x > 0 and (#builderRects > 1 and 0 or 1) or 0),
		1,
		((posY - height > 0 or backgroundRect.x <= 0) and 1 or 0),
		0
	)

	if selectedBuildersCount > 1 and activeBuilder then
		height = backgroundRect:getHeight()
		UiElement(
			buildersRect.x,
			buildersRect.y,
			buildersRect.xEnd + bgpadding * 2,
			buildersRect.yEnd + bgpadding + (iconMargin * 2),
			(backgroundRect.x > 0 and 1 or 0),
			1,
			((posY - height > 0 or backgroundRect.x <= 0) and 1 or 0),
			0,
			1,
			1,
			0
		)
	end
end

local function drawButton(rect)
	local disabled = false
	local highlight = rect.opts.current
	local hovered = rect.opts.hovered

	local padding = math_max(1, math_floor(bgpadding * 0.52))

	local color = highlight and 0.2 or 0

	local color1 = { color, color, color, math_clamp(ui_opacity * 1.25, 0.55, 0.95) } -- bottom
	local color2 = { color, color, color, math_clamp(ui_opacity * 1.25, 0.55, 0.95) } -- top

	if highlight then
		gl.Blending(GL_SRC_ALPHA, GL_ONE)
		gl.Color(0, 0, 0, 0.1)
	end

	UiButton(rect.x, rect.y, rect.xEnd, rect.yEnd, 1, 1, 1, 1, 1, 1, 1, 1, nil, color1, color2, padding)

	local dim = disabled and 0.4 or 1.0

	if rect.opts.icon then
		local iconSize = math.min(math.floor(rect:getHeight() * 1.1), categoryButtonHeight)
		local icon = ":l:" .. rect.opts.icon
		gl.Color(dim, dim, dim, 0.9)
		gl.Texture(icon)
		gl.BeginEnd(
			GL.QUADS,
			TexRectRound,
			rect.x + (bgpadding / 2),
			rect.yEnd - iconSize,
			rect.x + iconSize,
			rect.yEnd - (bgpadding / 2),
			0,
			0,
			0,
			0,
			0,
			0.05
		) -- this method with a lil zoom prevents faint edges aroudn the image
		--	gl.TexRect(px, sy - iconSize, px + iconSize, sy)
		gl.Texture(false)
	end

	if highlight then
		gl.Blending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	end

	if hovered then
		-- gloss highlight
		gl.Blending(GL_SRC_ALPHA, GL_ONE)
		RectRound(
			rect.x,
			rect.yEnd - ((rect.yEnd - rect.y) * 0.42),
			rect.xEnd,
			rect.yEnd,
			padding * 1.5,
			2,
			2,
			0,
			0,
			{ 1, 1, 1, 0.035 },
			{ 1, 1, 1, (disableInput and 0.11 or 0.24) }
		)
		RectRound(
			rect.x,
			rect.y,
			rect.xEnd,
			rect.y + ((rect.yEnd - rect.y) * 0.5),
			padding * 1.5,
			0,
			0,
			2,
			2,
			{ 1, 1, 1, (disableInput and 0.035 or 0.075) },
			{ 1, 1, 1, 0 }
		)
		gl.Blending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	end
end

local function drawCell(rect)
	-- empty cell
	if not rect.opts.uDefID then
		local color = { 0.1, 0.1, 0.1, 0.7 }
		local pad = cellPadding + iconPadding
		RectRound(rect.x + pad, rect.y + pad, rect.xEnd - pad, rect.yEnd - pad, cornerSize, 1, 1, 1, 1, color, color)
		return
	end

	local uid = rect.opts.uDefID
	local disabled = rect.opts.disabled
	local queuenr = rect.opts.queuenr
	local quotaNumber
	if WG.Quotas and WG.Quotas.getQuotas()[activeBuilderID] and WG.Quotas.getQuotas()[activeBuilderID][uid] then
		quotaNumber = WG.Quotas.getQuotas()[activeBuilderID][uid]
	end

	local cellColor
	local usedZoom = defaultCellZoom

	local metalPrice = rect.opts.metalPrice
	local energyPrice = rect.opts.energyPrice

	if not metalPrice and rect.opts.hovered then
		-- When hovered we always show prices
		metalPrice = formatPrice(rect.opts.metalCost)
		energyPrice = formatPrice(rect.opts.energyCost)
	end

	if disabled then
	elseif rect.opts.clicked then
		cellColor = clickCellColor
		usedZoom = clickCellZoom
	elseif rect.opts.selected then
		cellColor = selectedCellColor
		usedZoom = selectedCellZoom
	elseif rect.opts.hovered then
		cellColor = hoverCellColor
		usedZoom = hoverCellZoom
	end

	-- unit icon
	if disabled then
		gl.Color(0.4, 0.4, 0.4, 1)
	else
		gl.Color(1, 1, 1, 1)
	end

	local groupIcon = rect.opts.groupIcon
	local unitGroup = rect.opts.unitGroup

	UiUnit(
		rect.x + cellPadding + iconPadding,
		rect.y + cellPadding + iconPadding,
		rect.xEnd - cellPadding - iconPadding,
		rect.yEnd - cellPadding - iconPadding,
		cornerSize,
		1,
		1,
		1,
		1,
		usedZoom,
		nil,
		disabled and 0 or nil,
		"#" .. uid,
		groupIcon and (groupIcon and ":l" .. (disabled and "t0.3,0.3,0.3" or "") .. ":" .. groupIcon or nil) or nil,
		unitGroup and (unitGroup and ":l" .. (disabled and "t0.3,0.3,0.3:" or ":") .. unitGroup or nil) or nil,
		{ rect.opts.metalCost, rect.opts.energyCost },
		tonumber(queuenr)
	)

	-- colorize/highlight unit icon
	if cellColor then
		gl.Blending(GL.DST_ALPHA, GL_ONE_MINUS_SRC_COLOR)
		gl.Color(cellColor[1], cellColor[2], cellColor[3], cellColor[4])
		gl.Texture("#" .. uid)
		UiUnit(
			rect.x + cellPadding + iconPadding,
			rect.y + cellPadding + iconPadding,
			rect.xEnd - cellPadding - iconPadding,
			rect.yEnd - cellPadding - iconPadding,
			cornerSize,
			1,
			1,
			1,
			1,
			usedZoom
		)
		if cellColor[4] > 0 then
			gl.Blending(GL_SRC_ALPHA, GL_ONE)
			UiUnit(
				rect.x + cellPadding + iconPadding,
				rect.y + cellPadding + iconPadding,
				rect.xEnd - cellPadding - iconPadding,
				rect.yEnd - cellPadding - iconPadding,
				cornerSize,
				1,
				1,
				1,
				1,
				usedZoom
			)
		end
		gl.Blending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	end
	gl.Texture(false)

	-- price
	if metalPrice then
		local metalColor = disabled and "\255\125\125\125" or "\255\245\245\245"
		local energyColor = disabled and "\255\135\135\135" or "\255\255\255\000"
		local metalPriceText = metalColor .. metalPrice
		local energyPriceText = energyColor .. energyPrice
		font2:Print(
			metalPriceText,
			rect.xEnd - cellPadding - (cellInnerSize * 0.048),
			rect.y + cellPadding + (priceFontSize * 1.35),
			priceFontSize,
			"ro"
		)
		font2:Print(
			energyPriceText,
			rect.xEnd - cellPadding - (cellInnerSize * 0.048),
			rect.y + cellPadding + (priceFontSize * 0.35),
			priceFontSize,
			"ro"
		)
	end

	-- hotkey draw
	local hotkeyText = rect.opts.hotkey

	if hotkeyText then
		local keyFontSize = priceFontSize * 1.1
		local hotkeyColor = disabled and "\255\100\100\100" or "\255\215\255\215"
		font2:Print(
			hotkeyColor .. hotkeyText,
			rect.xEnd - cellPadding - (cellInnerSize * 0.048),
			rect.yEnd - cellPadding - keyFontSize,
			keyFontSize,
			"ro"
		)
	end

	-- factory queue number
	if queuenr then
		local queueFontSize = cellInnerSize * 0.29
		local textPad = math_floor(cellInnerSize * 0.1)
		local textWidth = font2:GetTextWidth(queuenr) * queueFontSize
		RectRound(
			rect.x,
			rect.yEnd - cellPadding - iconPadding - math_floor(cellInnerSize * 0.365),
			rect.x + textWidth + (textPad * 2), -- double pad, for a pad at the start and end
			rect.yEnd - cellPadding - iconPadding,
			cornerSize * 3.3,
			0,
			0,
			1,
			0,
			{ 0.15, 0.15, 0.15, 0.95 },
			{ 0.25, 0.25, 0.25, 0.95 }
		)
		font2:Print(
			"\255\190\255\190" .. queuenr,
			rect.x + cellPadding + textPad,
			rect.y + cellPadding + math_floor(cellInnerSize * 0.735),
			queueFontSize,
			"o"
		)
	end

	if quotaNumber and quotaNumber ~= 0 then
		local quotaText = WG.Quotas.getUnitAmount(activeBuilderID, uid) .. "/" .. quotaNumber
		local queueFontSize = cellInnerSize * 0.29
		local textPad = math_floor(cellInnerSize * 0.1)
		local textWidth = font2:GetTextWidth(quotaText) * queueFontSize
		if textWidth > 0.75 * cellInnerSize then
			local newFontSize = queueFontSize * 0.75 * cellInnerSize / textWidth
			textPad = textPad * newFontSize/queueFontSize
			textWidth = font2:GetTextWidth(quotaText) * newFontSize
			queueFontSize = newFontSize
		end
		RectRound(
			rect.x,
			rect.y + cellPadding + iconPadding,
			rect.x + textWidth + (textPad * 2), -- double pad, for a pad at the start and end
			rect.y + cellPadding + iconPadding + math_floor(cellInnerSize * 0.365),
			cornerSize * 3.3,
			0,
			1,
			0,
			0,
			{ 0.15, 0.15, 0.15, 0.95 },
			{ 0.25, 0.25, 0.25, 0.95 }
		)
		font2:Print(
			"\255\255\130\190" .. quotaText,
			rect.x + cellPadding + textPad,
			rect.y + cellPadding + (math_floor(cellInnerSize * 0.365) - font2:GetTextHeight(quotaNumber)*queueFontSize)/2,
			queueFontSize,
			"o"
		)
	end
end

local function drawButtonHotkey(rect)
	if not rect or not rect.opts.keyText then
		return
	end

	local keyFontHeight = rect.opts.keyTextHeight * hotkeyFontSize
	local keyFontHeightOffset = keyFontHeight * 0.34

	local textPadding = bgpadding * 2

	local text = "\255\215\255\215" .. rect.opts.keyText
	font2:Print(
		text,
		rect.xEnd - textPadding,
		(rect.y - (rect.y - rect.yEnd) / 2) - keyFontHeightOffset,
		hotkeyFontSize,
		"ro"
	)
end

local function drawCategories()
	if currentCategory then
		local rect = currentCategoryRect

		local fontHeight = rect.opts.nameHeight * categoryFontSize
		local fontHeightOffset = fontHeight * 0.34

		font2:Print(
			rect.opts.name,
			rect.x + (bgpadding * 7),
			(rect.y + rect:getHeight() / 2) - fontHeightOffset,
			categoryFontSize,
			"o"
		)

		drawButton(rect)

		return
	end

	for _, cat in pairs(categories) do
		local rect = catRects[cat]

		local fontHeight = rect.opts.nameHeight * categoryFontSize
		local fontHeightOffset = fontHeight * 0.34
		font2:Print(
			rect.opts.name,
			rect.x + (bgpadding * 7),
			(rect.y + rect:getHeight() / 2) - fontHeightOffset,
			categoryFontSize,
			"o"
		)

		if not rect.current then
			drawButtonHotkey(rect)
		end

		drawButton(rect)
	end
end

local function drawBackButtons()
	-- Back button
	local backText = backRect.opts.name
	local buttonWidth = backRect:getWidth()
	local buttonHeight = backRect:getHeight()
	local heightOffset = backRect.yEnd - font2:GetTextHeight(backText) * pageFontSize * 0.35 - buttonHeight / 2
	font2:Print(backText, backRect.x + (buttonWidth * 0.25), heightOffset, pageFontSize, "co")
	if not stickToBottom then
		font2:Print("⟵", backRect.x + (bgpadding * 2), heightOffset, pageFontSize, "o")
	end

	drawButtonHotkey(backRect)
	drawButton(backRect)
end

local function drawPageButtons()
	-- Page button
	local nextKeyText = keyConfig.sanitizeKey(nextPageKey, currentLayout)
	local nextPageText = "\255\245\245\245" .. "Page " .. currentPage .. "/" .. pages .. "  🠚"

	-- PERF: Move to a more static place, we only need to set this when viewresize or reloadbindings
	nextPageRect.opts.keyText = nextKeyText
	nextPageRect.opts.keyTextHeight = font2:GetTextHeight(nextKeyText)

	local buttonHeight = nextPageRect:getHeight()
	local fontHeight = font2:GetTextHeight(nextPageText) * pageFontSize
	local fontHeightOffset = fontHeight * 0.34

	font2:Print(
		nextPageText,
		nextPageRect.x + (bgpadding * 3),
		(nextPageRect.y + (buttonHeight / 2)) - fontHeightOffset,
		pageFontSize,
		"o"
	)

	drawButtonHotkey(nextPageRect)
	drawButton(nextPageRect)
end

local function drawBuildModeButtons()
	if labBuildModeActive then
		local fontSize = pageFontSize * 1.2
		local buildModeText = "\255\245\245\245" .. "Build Mode"
		local containerHeight = categoriesRect:getHeight()
		local fontHeight = font2:GetTextHeight(buildModeText) * fontSize
		local fontWidth = font2:GetTextWidth(buildModeText) * fontSize
		local center = (categoriesRect:getWidth() / 2) + categoriesRect.x
		local left = center - (fontWidth / 2)
		local fontHeightOffset = fontHeight * 0.3
		font2:Print(buildModeText, left, (categoriesRect.y + (containerHeight / 2)) - fontHeightOffset, fontSize, "o")

		return
	end

	local hotkeys = ""
	for i = 1, #categoryKeys do
		hotkeys = hotkeys .. keyConfig.sanitizeKey(categoryKeys[i], currentLayout)
	end

	if stickToBottom then
		local rect = labBuildModeRect
		local fullText = "\255\245\245\245" .. "Enable Build Mode"
		local buildModeText, _ =
			font2:WrapText(fullText, categoriesRect:getWidth() - (bgpadding * 2), nil, pageFontSize * 1.1)
		local buttonHeight = rect:getHeight()
		local fontHeight = font2:GetTextHeight(buildModeText) * pageFontSize
		local fontHeightOffset = fontHeight * 0.24
		font2:Print(
			buildModeText,
			rect.x + (bgpadding * 3),
			(rect.y + (buttonHeight / 2)) - fontHeightOffset,
			pageFontSize,
			"n"
		)

		-- draw hotkeys differently for this button
		local keyFontHeight = font2:GetTextHeight(hotkeys) * hotkeyFontSize
		local keyFontWidth = font2:GetTextWidth(hotkeys) * hotkeyFontSize
		local center = (categoriesRect:getWidth() / 2) + categoriesRect.x
		local left = center - (keyFontWidth / 2)

		local text = "\255\215\255\215" .. hotkeys
		font2:Print(text, left, rect.y + (keyFontHeight * 0.8), hotkeyFontSize, "o")
		drawButton(labBuildModeRect)
	else
		local buildModeText = "\255\245\245\245" .. "Enable Build Mode"
		local buttonHeight = labBuildModeRect:getHeight()
		local fontHeight = font2:GetTextHeight(buildModeText) * pageFontSize
		local fontHeightOffset = fontHeight * 0.24
		font2:Print(
			buildModeText,
			labBuildModeRect.x + (bgpadding * 3),
			(labBuildModeRect.y + (buttonHeight / 2)) - fontHeightOffset,
			pageFontSize,
			"o"
		)

		labBuildModeRect.opts.keyText = hotkeys
		labBuildModeRect.opts.keyTextHeight = font2:GetTextHeight(hotkeys)

		drawButtonHotkey(labBuildModeRect)
		drawButton(labBuildModeRect)
	end
end

local function drawBuilder(rect)
	local zoom = 0.05
	local highlightOpacity = 0
	local hovered = rect.opts.hovered
	local count = rect.opts.count
	local unitDefID = rect.opts.uDefID
	local lightness = rect.opts.current and 1.0 or 0.5

	-- draw button

	lightness = hovered and lightness + 0.25 or lightness
	zoom = hovered and zoom + 0.1 or zoom
	local rectSize = rect.xEnd - rect.x

	gl.Color(lightness, lightness, lightness, 1)
	UiUnit(
		rect.x,
		rect.y,
		rect.xEnd,
		rect.yEnd,
		math.ceil(bgpadding * 0.5),
		1,
		1,
		1,
		1,
		zoom,
		nil,
		math_max(0.1, highlightOpacity or 0.1),
		"#" .. unitDefID,
		nil,
		nil,
		nil,
		nil
	)

	-- builder count number
	if count > 1 then
		local countFontSize = rectSize * 0.3
		local pad = math_floor(rectSize * 0.03)
		font2:Print(
			"\255\240\240\240" .. count,
			rect.x + (pad * 2),
			rect.y + pad + math_floor(countFontSize * 2.2),
			countFontSize,
			"o"
		)
	end

	if highlightOpacity then
		gl.Blending(GL_SRC_ALPHA, GL_ONE)
		gl.Color(1, 1, 1, highlightOpacity)
		RectRound(
			rect.x,
			rect.y,
			rect.xEnd,
			rect.yEnd,
			math_min(math_max(1, math_floor((rect.xEnd - rect.x) * 0.024)), math_floor((vsy * 0.0015) + 0.5))
		)
		gl.Blending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	end
end

local function drawBuilders()

	-- draw builders
	for i = 1, selectedBuildersCount do
		drawBuilder(builderRects[i])
	end

	-- draw next builder button
	local rectHeight = nextBuilderRect:getHeight()
	local fontSize = rectHeight * 1.2
	local textHeight = nextBuilderRect.opts.nameHeight * fontSize

	font2:Print(
		"\255\255\255\255" .. nextBuilderRect.opts.name,
		nextBuilderRect.x + math_floor(rectHeight * 0.2),
		nextBuilderRect.y + (rectHeight / 2) - math_floor(textHeight / 2),
		fontSize,
		"o"
	)

	drawButton(nextBuilderRect)
	drawButtonHotkey(nextBuilderRect)
end

local function drawGrid()
	for _, cellRect in ipairs(cellRects) do
		drawCell(cellRect)
	end
end

local function drawBuildMenu()
	font2:Begin(useRenderToTexture)
	font2:SetTextColor(1,1,1,1)

	local drawBackScreen = (currentCategory and not builderIsFactory)
		or (builderIsFactory and useLabBuildMode and labBuildModeActive)

	if activeBuilder and not builderIsFactory then
		drawCategories()
	end

	drawGrid()

	if drawBackScreen then
		drawBackButtons()
	end

	if pages > 1 then
		drawPageButtons()
	end

	if selectedBuildersCount > 1 and activeBuilder then
		drawBuilders()
	end

	-- lab build mode button
	if builderIsFactory and useLabBuildMode then
		drawBuildModeButtons()
	end

	font2:End()
end

local function drawBuildProgress(cellRect)
	if not cellRect.opts.progress then
		return
	end

	RectRoundProgress(
		cellRect.x + cellPadding + iconPadding,
		cellRect.y + cellPadding + iconPadding,
		cellRect.xEnd - cellPadding - iconPadding,
		cellRect.yEnd - cellPadding - iconPadding,
		cellSize * 0.03,
		1 - cellRect.opts.progress, -- make the effect wind counter-clockwise
		{ 0.08, 0.08, 0.08, 0.6 }
	)
end

-------------------------------------------------------------------------------
--- INPUT HANDLING
-------------------------------------------------------------------------------

function widget:KeyPress(key, modifier, isRepeat)
	if key == KEYSYMS.ESCAPE then
		if currentCategory then
			clearCategory()
			return true
		elseif useLabBuildMode and labBuildModeActive then
			setLabBuildMode(false)
			updateGrid()
			return true
		end
	end
end

function widget:KeyRelease(key)
	if key ~= KEYSYMS.LSHIFT then
		return
	end

	clearCategory()
end

function widget:MousePress(x, y, button)
	if Spring.IsGUIHidden() then
		return
	end
	if WG["topbar"] and WG["topbar"].showingQuit() then
		return
	end

	if
		(buildmenuShows and backgroundRect:contains(x, y))
		or (selectedBuildersCount > 1 and (buildersRect:contains(x, y) or nextBuilderRect:contains(x, y)))
	then
		if activeBuilder then
			if pages > 1 then
				if nextPageRect and nextPageRect:contains(x, y) then
					Spring.PlaySoundFile(CONFIG.sound_queue_add, 0.75, "ui")
					nextPageHandler()
					return true
				end
			end

			if currentCategory or labBuildModeActive then
				if backRect and backRect:contains(x, y) then
					Spring.PlaySoundFile(CONFIG.sound_queue_add, 0.75, "ui")
					clearCategory()
					return true
				end
			end

			if useLabBuildMode and builderIsFactory and not labBuildModeActive then
				if labBuildModeRect:contains(x, y) then
					Spring.PlaySoundFile(CONFIG.sound_queue_add, 0.75, "ui")
					setLabBuildMode(true)
					updateGrid()
					return true
				end
			end

			for i = 1, selectedBuildersCount do
				local rect = builderRects[i]

				if rect:contains(x, y) then
					setActiveBuilder(i)
					refreshCommands()
					return true
				end
			end

			if nextBuilderRect:contains(x, y) then
				cycleBuilder()
				refreshCommands()
				return true
			end

			if not disableInput then
				if not currentCategory and not builderIsFactory then
					for cat, catRect in pairs(catRects) do
						if catRect:contains(x, y) then
							setCurrentCategory(cat)
							Spring.PlaySoundFile(CONFIG.sound_queue_add, 0.75, "ui")
							return true
						end
					end
				end

				for _, cellRect in pairs(cellRects) do
					local unitDefID = cellRect.opts.uDefID
					if
						unitDefID
						and unitTranslatedHumanName[unitDefID]
						and cellRect:contains(x, y)
						and not cellRect.opts.disabled
					then
						local alt, ctrl, meta, shift = Spring.GetModKeyState()
						if button ~= 3 then
							if builderIsFactory and WG.Quotas and WG.Quotas.isOnQuotaMode(activeBuilderID) and not alt then
								local amount = 1
								if ctrl then
									amount = amount * modKeyMultiplier.click.ctrl
								end
								if shift then
									amount = amount * modKeyMultiplier.click.shift
								end
								updateQuotaNumber(unitDefID, amount)
								return true
							end
							Spring.PlaySoundFile(CONFIG.sound_queue_add, 0.75, "ui")

							if isPregame then
								setPregameBlueprint(unitDefID)
							elseif spGetCmdDescIndex(-unitDefID) then
								pickBlueprint(unitDefID)
							end
						elseif builderIsFactory and spGetCmdDescIndex(-unitDefID) then
							if not (WG.Quotas and WG.Quotas.isOnQuotaMode(activeBuilderID) and not alt) then
								Spring.PlaySoundFile(CONFIG.sound_queue_rem, 0.75, "ui")
								setActiveCommand(spGetCmdDescIndex(-unitDefID), 3, false, true)
							else
								local amount = modKeyMultiplier.click.right
								if ctrl then
									amount = amount * modKeyMultiplier.click.ctrl
								end
								if shift then
									amount = amount * modKeyMultiplier.click.shift
								end
								updateQuotaNumber(unitDefID, amount)
							end
						end

						return true
					end
				end
			end
			return true
		elseif alwaysShow then
			return true
		end
	elseif activeBuilder and currentCategory and button == 3 then
		clearCategory()
		return true
	end
end

-------------------------------------------------------------------------------
--- DRAW LISTS
-------------------------------------------------------------------------------

local function checkGuishaderBuilders()
	if selectedBuildersCount > 1 and activeBuilder then
		if prevSelectedBuildersCount ~= selectedBuildersCount then
			prevSelectedBuildersCount = selectedBuildersCount
			if dlistGuishaderBuilders then
				dlistGuishaderBuilders = gl.DeleteList(dlistGuishaderBuilders)
				dlistGuishaderBuildersNext = gl.DeleteList(dlistGuishaderBuildersNext)
			end
			dlistGuishaderBuilders = gl.CreateList(function()
				RectRound(
						buildersRect.x,
						buildersRect.y,
						buildersRect.xEnd + (bgpadding * 2),
						buildersRect.yEnd + bgpadding + (iconMargin * 2),
						elementCorner
				)
			end)
			WG["guishader"].InsertDlist(dlistGuishaderBuilders, "buildmenubuilders")
			dlistGuishaderBuildersNext = gl.CreateList(function()
				RectRound(
						nextBuilderRect.x,
						nextBuilderRect.y,
						nextBuilderRect.xEnd,
						nextBuilderRect.yEnd,
						elementCorner * 0.5
				)
			end)
			WG["guishader"].InsertDlist(dlistGuishaderBuildersNext, "buildmenubuildersnext")
		end
	elseif dlistGuishaderBuilders then
		prevSelectedBuildersCount = 0
		WG["guishader"].DeleteDlist("buildmenubuilders")
		WG["guishader"].DeleteDlist("buildmenubuildersNext")
		dlistGuishaderBuilders = nil
		dlistGuishaderBuildersNext = nil
	end
end

-------------------------------------------------------------------------------
--- DRAW EVENTS
-------------------------------------------------------------------------------

function widget:DrawScreen()
	if not (activeBuilder or alwaysShow) then
		if WG["guishader"] and dlistGuishader then
			if dlistGuishader then
				WG["guishader"].RemoveDlist("buildmenu")
			end
			if dlistGuishaderBuilders then
				WG["guishader"].RemoveDlist("buildmenubuilders")
				WG["guishader"].RemoveDlist("buildmenubuildersnext")
			end
		end
	else

		if WG["guishader"] then
			if dlistGuishader then
				WG["guishader"].InsertDlist(dlistGuishader, "buildmenu")
			end
			checkGuishaderBuilders()
		end

		local buildersRectYend = math_ceil((buildersRect.yEnd + bgpadding + (iconMargin * 2)))
		if redraw then
			redraw = nil
			if useRenderToTexture then
				if not buildmenuBgTex then
					buildmenuBgTex = gl.CreateTexture(math_floor(backgroundRect.xEnd-backgroundRect.x), math_floor(buildersRectYend-backgroundRect.y), {
						target = GL.TEXTURE_2D,
						format = GL.RGBA,
						fbo = true,
					})
				end
				if buildmenuBgTex then
					gl.R2tHelper.RenderToTexture(buildmenuBgTex,
						function()
							gl.Translate(-1, -1, 0)
							gl.Scale(2 / math_floor(backgroundRect.xEnd-backgroundRect.x), 2 / math_floor(buildersRectYend-backgroundRect.y), 0)
							gl.Translate(-backgroundRect.x, -backgroundRect.y, 0)
							drawBuildMenuBg()
						end,
						useRenderToTexture
					)
				end
				if not buildmenuTex then
					buildmenuTex = gl.CreateTexture(math_floor(backgroundRect.xEnd-backgroundRect.x)*2, math_floor(buildersRectYend-backgroundRect.y)*2, {	--*(vsy<1400 and 2 or 2)
						target = GL.TEXTURE_2D,
						format = GL.RGBA,
						fbo = true,
					})
				end
				if buildmenuTex then
					gl.R2tHelper.RenderToTexture(buildmenuTex,
						function()
							gl.Translate(-1, -1, 0)
							gl.Scale(2 / math_floor(backgroundRect.xEnd-backgroundRect.x), 2 / math_floor(buildersRectYend-backgroundRect.y), 0)
							gl.Translate(-backgroundRect.x, -backgroundRect.y, 0)
							drawBuildMenu()
						end,
						useRenderToTexture
					)
				end
			else
				gl.DeleteList(dlistBuildmenu)
				dlistBuildmenu = gl.CreateList(function()
					drawBuildMenuBg()
					drawBuildMenu()
				end)
			end
		end
		if useRenderToTexture then
			if buildmenuBgTex then
				-- background element
				gl.R2tHelper.BlendTexRect(buildmenuBgTex, backgroundRect.x, backgroundRect.y, backgroundRect.xEnd, buildersRectYend, useRenderToTexture)
			end
		end
		if useRenderToTexture then
			if buildmenuTex then
				-- content
				gl.R2tHelper.BlendTexRect(buildmenuTex, backgroundRect.x, backgroundRect.y, backgroundRect.xEnd, buildersRectYend, useRenderToTexture)
			end
		else
			if dlistBuildmenu then
				gl.CallList(dlistBuildmenu)
			end
		end

		if redrawProgress then
			dlistProgress = gl.DeleteList(dlistProgress)
			redrawProgress = nil
		end

		if currentlyBuildingRectID then
			if not dlistProgress then
				dlistProgress = gl.CreateList(function()
					drawBuildProgress(cellRects[currentlyBuildingRectID])
				end)
			end

			gl.CallList(dlistProgress)
		end
	end
end

-------------------------------------------------------------------------------
--- CHANGE EVENTS
-------------------------------------------------------------------------------

function widget:CommandNotify(cmdID, _, cmdOpts)
	if cmdID >= 0 then
		return
	end

	if alwaysReturn or not cmdOpts.shift then
		setCurrentCategory(nil)
	end
end

function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	-- if theres no factory as active builder, cmd is not build return or cmd
	-- is not to build a unit: nothing to do
	if cmdID == CMD_STOP_PRODUCTION then
		if WG.Quotas then
			local quotas = WG.Quotas.getQuotas()
			quotas[unitID] = nil
			redraw = true
		end
	end
	if cmdID == CMD_INSERT then
		if cmdParams[2] then
			cmdID = cmdParams[2]
			cmdOpts = cmdParams[3]
		end
	end

	if not builderIsFactory or cmdID >= 0 or activeBuilderID ~= unitID then
		return
	end

	local queueCount = cmdOptsToFactoryQueueChange(cmdOpts)
	updateQueueNr(-cmdID, queueCount)

	-- the command queue of the factory hasn't updated yet
	-- ugly hack to schedule an update if our prediction fails
	-- 500ms is our heuristic for a really bad scenario
	-- doUpdateClock = os.clock() + 0.5
	-- Actually lets comment this and see if we really need it
end

function widget:UnitCreated(_, unitDefID, _, builderID) -- to handle insert commands with quotas
	if builderID == activeBuilderID and WG.Quotas then
		local quotas = WG.Quotas.getQuotas()
		if quotas[builderID] and quotas[builderID][unitDefID] then
			redraw = true
		end
	end
end

-- update queue number
function widget:UnitCmdDone(unitID, unitDefID, unitTeam, cmdID, cmdParams, options, cmdTag)
	-- if factory is not current active builder return
	if unitID ~= activeBuilderID then
		return
	end

	-- If factory is in repeat, queue does not change, except if it is alt-queued
	local factoryRepeat = select(4, Spring.GetUnitStates(unitID, false, true))

	if factoryRepeat and not options.alt then
		return
	end

	updateQueueNr(-cmdID, -1)
end

-- PERF: Fix convoluted setActiveBuilder and multiple calls to getselectedsorted
function widget:SelectionChanged(newSel)
	local prevActiveBuilderDefID = activeBuilder
	local prevActiveBuilderID = activeBuilderID

	activeBuilder = nil
	activeBuilderID = nil
	builderIsFactory = false
	labBuildModeActive = false
	prevSelectedBuilders = selectedBuilders
	selectedBuilders = {}
	selectedBuildersCount = 0
	currentPage = 1

	if #newSel == 0 then
		-- If no selection, we still have to draw empty cells
		if alwaysShow then
			refreshCommands()
		else
			WG["buildmenu"].hoverID = nil
		end

		return
	end

	-- Here we do selected sorted to save the GetUnitDefIDs we would have to do
	-- if we used the newSel
	local selectedUnitsSorted = spGetSelectedUnitsSorted()
	for unitDefID, unitIDs in pairs(selectedUnitsSorted) do
		if units.isBuilder[unitDefID] then
			selectedBuilders[unitDefID] = #unitIDs
			selectedBuildersCount = selectedBuildersCount + 1
		end

		if selectedBuildersCount == maxBuilderRects then
			break
		end
	end

	-- if no builders are selected, there's nothing to do
	if selectedBuildersCount == 0 then
		-- If no selection, we still have to draw empty cells
		if alwaysShow then
			refreshCommands()
		else
			WG["buildmenu"].hoverID = nil
		end

		return
	end

	-- set active builder to first index after updating selection
	updateBuilders()
	setActiveBuilder(1, selectedUnitsSorted)

	if activeBuilder and not builderIsFactory then
		updateCategories(CONFIG.buildCategories)
	else
		updateCategories({})
	end

	-- If the defid of the builder has changed, or if it is a factory and the
	-- unit has changed (due to having to update queue): refresh everything
	if activeBuilder ~= prevActiveBuilderDefID or (builderIsFactory and activeBuilderID ~= prevActiveBuilderID) then
		refreshCommands()
	end
end

function widget:GameStart()
	isPregame = false
	units.checkGeothermalFeatures()
end

function widget:PlayerChanged()
	isSpec = Spring.GetSpectatingState()
	myTeamID = Spring.GetMyTeamID()
end

function widget:GetConfigData()
	return {
		alwaysReturn = alwaysReturn,
		autoSelectFirst = autoSelectFirst,
		useLabBuildMode = useLabBuildMode,
		showPrice = showPrice,
		showRadarIcon = showRadarIcon,
		showGroupIcon = showGroupIcon,
		stickToBottom = stickToBottom,
		gameID = Game.gameID and Game.gameID or Spring.GetGameRulesParam("GameID"),
		alwaysShow = alwaysShow,
		ctrlClickModifier = modKeyMultiplier.click.ctrl,
		shiftClickModifier = modKeyMultiplier.click.shift,
		ctrlKeyModifier = modKeyMultiplier.keyPress.ctrl,
		shiftKeyModifier = modKeyMultiplier.keyPress.shift,
	}
end

function widget:SetConfigData(data)
	if data.alwaysReturn ~= nil then
		alwaysReturn = data.alwaysReturn
	end
	if data.autoSelectFirst ~= nil then
		autoSelectFirst = data.autoSelectFirst
	end
	if data.useLabBuildMode ~= nil then
		useLabBuildMode = data.useLabBuildMode
	end
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
	if data.ctrlClickModifier ~= nil then
		modKeyMultiplier.click.ctrl = data.ctrlClickModifier
	end
	if data.shiftClickModifier ~= nil then
		modKeyMultiplier.click.shift = data.shiftClickModifier
	end
	if data.ctrlKeyModifier ~= nil then
		modKeyMultiplier.keyPress.ctrl = data.ctrlKeyModifier
	end
	if data.shiftKeyModifier ~= nil then
		modKeyMultiplier.keyPress.shift = data.shiftKeyModifier
	end
end

function widget:Shutdown()
	dlistBuildmenu = gl.DeleteList(dlistBuildmenu)
	dlistProgress = gl.DeleteList(dlistProgress)
	if buildmenuTex then
		gl.DeleteTexture(buildmenuBgTex)
		buildmenuBgTex = nil
		gl.DeleteTexture(buildmenuTex)
		buildmenuTex = nil
	end
	if WG["guishader"] and dlistGuishader then
		WG["guishader"].DeleteDlist("buildmenu")
		WG["guishader"].DeleteDlist("buildmenubuilders")
		WG["guishader"].DeleteDlist("buildmenubuildersnext")
		dlistGuishader = nil
	end
	WG["buildmenu"] = nil
end
