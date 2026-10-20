local widget = widget ---@type Widget

local customPresetOptions -- forward-decl: read in options export

function widget:GetInfo()
	return {
		name = "Options",
		desc = "",
		author = "Floris",
		date = "September 2016",
		license = "GNU GPL, v2 or later",
		layer = -99990,
		enabled = true,
		handler = true,
	}
end

Spring.SendCommands("resbar 0")

-- Add new options at: function init

local types = {
	basic = 1,
	advanced = 2,
	dev = 3,
}

local version = 1.5 -- used to toggle previously default enabled/disabled widgets to the newer default in widget:initialize()
local newerVersion = false -- configdata will set this true if it's a newer version

local keyLayouts = require("luaui/configs/keyboard_layouts")

local languageCodes = { "en", "fr", "ru", "es" }
languageCodes = table.merge(languageCodes, table.invert(languageCodes))

local languageNames = {}
for key, code in ipairs(languageCodes) do
	languageNames[key] = BAR.I18N.languages[code]
end

local devLanguageCodes = { "en", "fr", "de", "ru", "zh", "es", "test_unicode" }
devLanguageCodes = table.merge(devLanguageCodes, table.invert(devLanguageCodes))

local devLanguageNames = {}
for key, code in ipairs(devLanguageCodes) do
	devLanguageNames[key] = BAR.I18N.languages[code]
end

-- detect potatoes
local isPotatoCpu = false
local isPotatoGpu = false
local gpuMem = (Platform.gpuMemorySize or 0) / 1000 -- gpuMemorySize is in KB (only Nvidia reports nonzero), /1000 ≈ MB
local glRendererLower = Platform.glRenderer and string.lower(Platform.glRenderer) or ""

if not Platform.glHaveGL4 then
	-- No GL4 support means the engine can't use modern rendering paths
	isPotatoGpu = true
elseif Platform.glHaveNVidia then
	-- Nvidia reliably reports gpuMemorySize; < ~2.5 GB VRAM = low-end
	if gpuMem > 0 and gpuMem < 2500 then
		isPotatoGpu = true
	end
elseif Platform.glHaveIntel then
	-- All Intel GPUs are integrated except the Arc series (discrete)
	-- Integrated: "Intel(R) HD Graphics ...", "Intel(R) UHD Graphics ...", "Intel(R) Iris ..."
	-- Discrete:   "Intel(R) Arc(TM) A770", "Intel(R) Arc(TM) B580", etc.
	if not string.find(glRendererLower, "arc") then
		isPotatoGpu = true
	end
elseif Platform.glHaveAMD then
	-- AMD discrete GPUs contain "RX" (modern, 2016+) or "R9" (older high-end) in their name
	-- Integrated: "AMD Radeon(TM) Graphics", "AMD Radeon Vega 8", "AMD Radeon 780M", etc.
	-- gpuMemorySize is 0 for AMD so we can't use VRAM size
	if not (string.find(glRendererLower, "rx") or string.find(glRendererLower, "r9 ")) then
		isPotatoGpu = true
		gpuMem = 0 -- AMD integrated can report incorrect gpuMemorySize, so set to 0 to avoid false positives for low VRAM
	end
elseif string.find(glRendererLower, "apple m") then
	-- Apple Silicon via zink reports vendor Mesa: "zink Vulkan 1.3(Apple M3 Max (MESA_KOSMICKRISP))"
else
	-- Unknown/Mesa vendor without specific detection — assume low-end
	isPotatoGpu = true
end

local devMode = BAR.Utilities.IsDevMode()
local devUI = BAR.Utilities.ShowDevUI()

local advSettings = false
local initialized = false

local cameraTransitionTime = 0.18
local cameraPanTransitionTime = 0.03

local optionColor = "\255\255\255\255"
local widgetOptionColor = "\255\160\160\160"
local advOptionColor = "\255\180\160\140"
local advMainOptionColor = "\255\255\235\200"
local devOptionColor = "\255\200\110\100"
local devMainOptionColor = "\255\245\166\140"

local firstlaunchsetupDone = false

local playSounds = true
local sounds = {
	buttonClick = "LuaUI/Sounds/tock.wav",
	paginatorClick = "LuaUI/Sounds/buildbar_waypoint.wav",
	sliderDrag = "LuaUI/Sounds/buildbar_rem.wav",
	selectClick = "LuaUI/Sounds/buildbar_click.wav",
	selectUnfoldClick = "LuaUI/Sounds/buildbar_hover.wav",
	selectHoverClick = "LuaUI/Sounds/hover.wav",
	toggleOnClick = "LuaUI/Sounds/switchon.wav",
	toggleOffClick = "LuaUI/Sounds/switchoff.wav",
}

local continuouslyClean = Spring.GetConfigInt("ContinuouslyClearMapmarks", 0) == 1

local anonymousMode = Spring.GetModOptions().teamcolors_anonymous_mode
--local anonymousTeamColor = {Spring.GetConfigInt("anonymousColorR", 255)/255, Spring.GetConfigInt("anonymousColorG", 0)/255, Spring.GetConfigInt("anonymousColorB", 0)/255}

local vsx, vsy = Spring.GetViewGeometry()
local fontfileScale = (0.5 + (vsx * vsy / 5700000))
local fontfileSize = 36
local fontfileOutlineSize = 7

local screenHeightOrg = 610
local screenWidthOrg = 950
-- the window's sizes in pixels at 1080p, and how its list is laid out
local tuning = {
	controlsWidth = 200, -- the column the controls share; sliders and dropdowns span it
	controlsAlignLeft = true, -- toggles at the left edge of that column, else at its right end
	compactColumns = 2, -- toggles per line in grids: notifications, playlist tracks, auto cloak units
	rowHeight = 25, -- a setting's row; its controls scale with it, and section headings are 1.35x
	fontSize = 14, -- setting names and values; the switch captions scale with it
	controlFontSize = 12.5, -- the text in the controls: a dropdown's choice and a slider's value
	dropdownFontSize = 12.5, -- the entries of an open dropdown
	headingFontSize = 14, -- section headings in the list
	categoryHeight = 29, -- a tab's row in the column
	categoryFontSize = 14, -- the tabs in the column; a tab's name over its search results is 1.25x
	subcategoryHeight = 25, -- a section's row under the open tab in the column
	subcategoryFontSize = 14, -- the sections under the open tab in the column
	descriptionLines = 3, -- lines under the setting's name in the strip below the list
	rowHighlight = true, -- light up the row under the mouse (what folds a family always lights up)
}
local screenHeight = screenHeightOrg
local screenWidth = screenWidthOrg

local centerPosX = 0.5
local centerPosY = 0.5
local screenX = math.floor((vsx * centerPosX) - (screenWidth / 2))
local screenY = math.floor((vsy * centerPosY) + (screenHeight / 2))

local changesRequireRestart = false
local useNetworkSmoothing = false

local show = false
local manualChange = true

local spGetGroundHeight = Spring.GetGroundHeight

local os_clock = os.clock
local math_isInRect = math.isInRect

local chobbyInterface, backgroundGuishader, currentGroupTab, windowList
---@type LuaFont, LuaFont
local font, font2
local sceduleOptionApply, checkedForWaterAfterGamestart, checkedWidgetDataChanges
local forceUpdate, sliderValueChanged, selectOptionsList, prevSelectHover, scheduleInit
local fontOption, lastSliderSound, selectClickAllowHide, selectScrollOffset
-- the option whose dropdown is open, and the slider being dragged
---@type table?
local openSelect
---@type table?
local draggingSlider
local guishaderWasActive = false

local glColor = gl.Color
local glTexRect = gl.TexRect
local glTexture = gl.Texture
local glCreateList = gl.CreateList
local glCallList = gl.CallList
local glDeleteList = gl.DeleteList
local glBlending = gl.Blending
local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_ONE = GL.ONE

local RectRound, elementCorner, elementMargin, elementPadding, UiElement, UiSlider, UiSliderKnob, UiToggle, UiSelector, UiSelectHighlight, bgpadding
local UiScroller, UiScrollerAt

local isSinglePlayer = BAR.Utilities.Gametype.IsSinglePlayer()
local isReplay = Spring.IsReplay()

local desiredWaterValue = 4
local waterDetected = false
if select(3, Spring.GetGroundExtremes()) < 0 then
	waterDetected = true
end
local heightmapChangeBuffer = {}

local widgetScale = (vsy / 1080)

local edgeMoveWidth = tonumber(Spring.GetConfigFloat("EdgeMoveWidth", 1) or 0.02)

local defaultMapSunPos = { gl.GetSun("pos") }
local defaultSunLighting = {
	groundAmbientColor = { gl.GetSun("ambient") },
	unitAmbientColor = { gl.GetSun("ambient", "unit") },
	groundDiffuseColor = { gl.GetSun("diffuse") },
	unitDiffuseColor = { gl.GetSun("diffuse", "unit") },
	groundSpecularColor = { gl.GetSun("specular") },
	unitSpecularColor = { gl.GetSun("specular", "unit") },
}

local defaultSkyAxisAngle = {
	gl.GetAtmosphere("skyAxisAngle"),
}

-- Correct some maps fog
if Game.mapName == "Nine_Metal_Islands_V1" then
	Spring.SetAtmosphere({ fogStart = 999990, fogEnd = 9999999 })
end
local defaultMapFog = {
	fogStart = gl.GetAtmosphere("fogStart"),
	fogEnd = gl.GetAtmosphere("fogEnd"),
	fogColor = { gl.GetAtmosphere("fogColor") },
}

local options = {}
local unfilteredOptions = {}
local customOptions = {}
local optionGroups = {}

-- The window, in the shape of the game info panel: the tabs and the open tab's sections in a
-- column on the left, that tab's settings in one list that scrolls, the search field and the
-- advanced switch above it, and below it a strip with the hovered setting's description.
-- look: its colors. metrics: its sizes, set from the screen size in view.setLayout. layout: where
-- the last DrawWindow put everything, read back by hover and clicks. view: what the list shows.
local look = {
	sidebarFill = { 0, 0, 0, 0.24 },
	sidebarFillTop = { 0, 0, 0, 0.16 },
	selectedFill = { 1, 1, 1, 0.13 },
	-- the section the list is showing, marked down its left edge
	sectionAccent = { 1, 0.78, 0.35, 0.7 },
	white = { 1, 1, 1 },
	hoverOpacity = 0.14,
	headingSheen = { 1, 1, 1, 0.05 },
	headingLine = { 1, 0.78, 0.51, 0.4 },
	headingLineFade = { 1, 0.78, 0.51, 0 },
	stripFill = { 0, 0, 0, 0.18 },
	stripFillTop = { 0, 0, 0, 0.12 },
	-- a row that does something when clicked lights up green
	clickRow = { 0.5, 1, 0.25 },
	controlHover = { 0.5, 0.5, 0.5, 0.22 },
	controlHoverTop = { 1, 1, 1, 0.22 },
	presetRow = { 0, 0, 0, 0.15 },
	presetRowTop = { 1, 1, 1, 0.15 },
	selectBorder = { 0, 0, 0, 0.25 },
	selectBack = { 0.3, 0.3, 0.3, 0.84 },
	selectBackTop = { 0.35, 0.35, 0.35, 0.84 },
	selectBackSolid = { 0.3, 0.3, 0.3, 0.94 },
	selectBackSolidTop = { 0.35, 0.35, 0.35, 0.94 },
	selectCurrent = { 1, 1, 1, 0.08 },
	scrollTrack = { 0.15, 0.15, 0.15, 0.85 },
	scrollThumb = { 0.65, 0.65, 0.65, 0.9 },
	chevron = { 1, 1, 1, 0.5 },
	chevronLit = { 1, 1, 1, 1 },
	-- the row picked by a click or the arrow keys
	selectedRow = { 1, 1, 1, 0.06 },
	title = "\255\235\235\235",
	heading = "\255\255\200\130",
	group = "\255\175\175\175",
	groupSelected = "\255\245\245\245",
	section = "\255\140\140\140",
	sectionLit = "\255\235\215\185",
	count = "\255\120\120\120",
	caption = "\255\160\160\160",
	captionOn = "\255\210\210\205",
	value = "\255\200\200\200",
	description = "\255\170\170\170",
	command = "\255\060\060\060",
	commandLit = "\255\200\200\200",
	restart = "\255\255\120\120",
	restartMark = "\255\255\090\090*",
	-- the sub-options of a widget that is switched off
	inactive = "\255\105\105\105",
}

local metrics = { wheelRows = 3 }

local layout = {
	window = { 0, 0, 0, 0 },
	area = { 0, 0, 0, 0 },
	rows = {} --[[@as table<integer, table>]],
	rowOf = {} --[[@as table<table, table>]],
	sidebar = {},
	selectItems = {},
	switch = { 0, 0, 0, 0 },
	switchHit = { 0, 0, 0, 0 },
	unfoldSwitch = { 0, 0, 0, 0 },
	unfoldSwitchHit = { 0, 0, 0, 0 },
	totalH = 0,
	-- the strip's /option command where a click copies it, with the command as [5]
	stripCommand = false --[[@as table|false]],
}

-- lines: what the list shows. scroll: the first line shown. scrollOf: where each tab was left.
-- folded: families folded or opened by hand; it and unfoldAll are kept in the config.
-- childCount: rows under each parent. startsOpen: the parents with a basic row that is not a cell.
-- matches/headingOf: per tab under a search, how many rows matched and where they start.
local view = {
	lines = {} --[[@as table<integer, table>]],
	scroll = 0,
	scrollOf = {},
	folded = {} --[[@as table<string, boolean>]],
	unfoldAll = false --[[@as boolean]],
	childCount = {} --[[@as table<table, integer>]],
	startsOpen = {} --[[@as table<table, boolean>]],
	matches = {},
	headingOf = {},
	dragging = false,
	dragGrab = 0,
	-- the heading last jumped to from the column, marked there until the list is scrolled otherwise
	litPin = false --[[@as table|false]],
	-- the row a click or the arrow keys picked, and the one the strip shows: that or the last hovered
	selected = false --[[@as table|false]],
	stripOption = false --[[@as table|false]],
	-- the open dropdown's entry the arrow keys are on
	selectKey = false --[[@as number|false]],
	-- a slider dragged with shift held, and where that started
	fineDrag = false --[[@as table|false]],
	-- when the strip's /option command was last copied
	copiedAt = -10 --[[@as number]],
	-- the open color picker: its option, FlowUI's picker and the value it opened on
	picker = false --[[@as table|false]],
	-- a press went to the picker, so its release does nothing else
	pickerHeld = false --[[@as boolean]],
}

-- the parts of the window, each drawing itself and recording in layout where it went
local draw = {}
-- per option type: draws the control at the right end of a row and returns where it starts
local drawControl = {}

-- Shared with the keybind editor and the game info panel.
local Editbox = require("luaui/Include/keybind_editbox")
local text = require("luaui/Include/keybind_text")
---@type table
local searchBox
-- the search, kept in step with searchBox for applyFilter
local inputText = ""

-- a slider's range: its lowest and highest step, or min and max
local function sliderRange(option)
	if option.steps then
		local min, max = option.steps[1], option.steps[1]
		for _, v in ipairs(option.steps) do
			if v > max then
				max = v
			end
			if v < min then
				min = v
			end
		end
		return min, max
	end
	return option.min, option.max
end

local showOnceMore = false -- used because of GUI shader delay
local resettedTonemapDefault = false
local heightmapChangeClock
local requireRestartDefaults = {}
local gameOver = false
local presets = {}

local reclaimFieldHighlightOptions = {
	BAR.I18N("ui.settings.option.reclaimfieldhighlight_always"),
	BAR.I18N("ui.settings.option.reclaimfieldhighlight_resource"),
	BAR.I18N("ui.settings.option.reclaimfieldhighlight_reclaimer"),
	BAR.I18N("ui.settings.option.reclaimfieldhighlight_resbot"),
	BAR.I18N("ui.settings.option.reclaimfieldhighlight_order"),
	BAR.I18N("ui.settings.option.reclaimfieldhighlight_disabled"),
}

local spectatorHUDConfigOptions = {
	BAR.I18N("ui.settings.option.spectator_hud_config_basic"),
	BAR.I18N("ui.settings.option.spectator_hud_config_advanced"),
	BAR.I18N("ui.settings.option.spectator_hud_config_expert"),
	BAR.I18N("ui.settings.option.spectator_hud_config_custom"),
}

local startScript = VFS.LoadFile("_script.txt")
local rwsBuffer = nil -- reassembly buffer for restart-with-state chunks (save path)
local rwsRestoreData = nil -- serialised state to send to gadget after restart (restore path)
local RWS_MSG_CHUNK = 4000

local function getRestartWithStateScript()
	local startPosTypePattern = "([Ss][Tt][Aa][Rr][Tt][Pp][Oo][Ss][Tt][Yy][Pp][Ee]%s*=%s*)%d+(%s*;)"
	local script, replacements = startScript:gsub(startPosTypePattern, function(prefix, suffix)
		return prefix .. "0" .. suffix
	end, 1)
	if replacements == 0 then
		Spring.Echo("[Restart With State] Could not set fixed start-position mode; using the original start script.")
	end
	return script
end

if not startScript then
	local modoptions = ""
	for key, value in pairs(BAR.GetModOptionsCopy()) do
		local v = value
		if type(v) == "boolean" then
			v = (v and "1" or "0")
		end
		modoptions = modoptions .. key .. "=" .. v .. ";"
	end

	startScript = [[[game]
	{
		[allyteam1]
		{
			numallies=0;
		}
		[team1]
		{
			teamleader=0;
			allyteam=1;
		}
		[ai0]
		{
			shortname=Null AI;
			name=AI: Null AI;
			team=1;
			host=0;
		}
		[modoptions]
		{
			]] .. modoptions .. [[
		}
		[allyteam0]
		{
			numallies=0;
		}
		[team0]
		{
			teamleader=0;
			allyteam=0;
		}
		[player0]
		{
			team=0;
			name=]] .. select(1, Spring.GetPlayerInfo(Spring.GetLocalPlayerID())) .. [[;
		}
		mapname=]] .. Game.mapName .. [[;
		myplayername=]] .. select(1, Spring.GetPlayerInfo(Spring.GetLocalPlayerID())) .. [[;
		ishost=1;
		gametype=]] .. Game.gameName .. " " .. Game.gameVersion .. [[;
		nohelperais=0;
	}
	]]
end

local function setEngineFont()
	local relativesize = 1
	--"fonts/FreeSansBold.otf"
	Spring.SetConfigInt("SmallFontSize", fontfileSize * fontfileScale * relativesize)
	Spring.SetConfigInt("SmallFontOutlineWidth", fontfileOutlineSize * fontfileScale * relativesize * 0.85)
	Spring.SetConfigInt("SmallFontOutlineWeight", 2)

	Spring.SetConfigInt("FontSize", fontfileSize * fontfileScale * relativesize)
	Spring.SetConfigInt("FontOutlineWidth", fontfileOutlineSize * fontfileScale * relativesize * 0.85)
	Spring.SetConfigInt("FontOutlineWeight", 2)

	Spring.SendCommands("font " .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf"))

	-- set spring engine default font cause it can't thee game archive fonts on launch
	Spring.SetConfigString("SmallFontFile", "FreeSansBold.otf")
	Spring.SetConfigString("FontFile", "FreeSansBold.otf")
end
setEngineFont()

local function showOption(option)
	if
		not option.category
		or option.category == types.basic
		or (advSettings and option.category == types.advanced)
		or (devMode or devUI)
	then
		return true
	end
	return false
end

local function adjustShadowQuality()
	local quality = Spring.GetConfigInt("ShadowQuality", 3)
	local shadowMapSize = 600 + math.min(10240, (vsy + vsx) * 0.37) * (quality * 0.5)
	Spring.SetConfigInt("Shadows", (quality == 0 and 0 or 1))
	Spring.SetConfigInt("ShadowMapSize", shadowMapSize)
	Spring.SendCommands("shadows " .. (quality == 0 and 0 or 1) .. " " .. shadowMapSize)
end

function widget:ViewResize()
	vsx, vsy = Spring.GetViewGeometry()

	widgetScale = (vsy / 1080)

	screenHeight = math.floor(screenHeightOrg * widgetScale)
	screenWidth = math.floor(screenWidthOrg * widgetScale)
	screenX = math.floor((vsx * centerPosX) - (screenWidth / 2))
	screenY = math.floor((vsy * centerPosY) + (screenHeight / 2))

	bgpadding = WG.FlowUI.elementPadding
	elementCorner = WG.FlowUI.elementCorner
	elementMargin = WG.FlowUI.elementMargin
	elementPadding = WG.FlowUI.elementPadding

	RectRound = WG.FlowUI.Draw.RectRound
	UiElement = WG.FlowUI.Draw.Element
	UiSlider = WG.FlowUI.Draw.Slider
	UiSliderKnob = WG.FlowUI.Draw.SliderKnob
	UiToggle = WG.FlowUI.Draw.Toggle
	UiSelector = WG.FlowUI.Draw.Selector
	UiSelectHighlight = WG.FlowUI.Draw.SelectHighlight
	UiScroller = WG.FlowUI.Draw.Scroller
	UiScrollerAt = WG.FlowUI.Draw.ScrollerGeometry

	font = WG.fonts.getFont()
	font2 = WG.fonts.getFont(2)

	if not searchBox then
		view.makeSearchBox()
	end
	view.setLayout()

	local newFontfileScale = (0.5 + (vsx * vsy / 5700000))
	if fontfileScale ~= newFontfileScale then
		fontfileScale = newFontfileScale
		setEngineFont()
	end

	backgroundGuishader = glDeleteList(backgroundGuishader)
	view.build()
	view.refresh()

	adjustShadowQuality()
end

local function detectWater()
	local _, _, mapMinHeight, _ = Spring.GetGroundExtremes()
	if mapMinHeight <= -2 then
		waterDetected = true
		Spring.SendCommands("water " .. desiredWaterValue)
	end
end

local Search = require("luaui/Include/search")

function widget:TextInput(char) -- if it isn't working: chobby probably hijacked it
	if not chobbyInterface and not Spring.IsGUIHidden() and show then
		-- typing searches straight away; until then the field shows what it is for
		searchBox:focus()
		searchBox:textInput(char)
		if WG.limitidlefps and WG.limitidlefps.update then
			WG.limitidlefps.update()
		end
		return true
	end
end

-- the search field, kept in step with inputText; made again when the language changes
function view.makeSearchBox()
	searchBox = Editbox.new({
		placeholder = BAR.I18N("ui.gameInfo.search"),
		clearable = true,
		text = inputText,
		onChange = function(value)
			inputText = value
			view.scroll = 0
			applyFilter()
		end,
	})
end

-- Opening takes text input for the search field, so typing searches straight away; closing gives
-- it back. The search itself is kept for the next time.
function view.open()
	if not show and WG.topbar then
		WG.topbar.hideWindows()
	end
	show = true
	widgetHandler.textOwner = widget --widgetHandler:OwnText()
	Spring.SDLStartTextInput() -- because: touch chobby's text edit field once and widget:TextInput is gone for the game, so we make sure its started!
	if searchBox then
		-- other widgets may have changed settings while it was closed
		view.build()
		view.refresh()
	end
	forceUpdate = true -- Update reads again what can change elsewhere, like the window's size
end

function view.close()
	show = false
	openSelect = nil
	draggingSlider = nil
	view.closePicker()
	view.dragging = false
	backgroundGuishader = glDeleteList(backgroundGuishader)
	if WG.guishader then
		WG.guishader.RemoveDlist("options")
		if selectOptionsList then
			WG.guishader.RemoveScreenRect("options_select")
			WG.guishader.RemoveScreenRect("options_select_options")
			WG.guishader.removeRenderDlist(selectOptionsList)
		end
	end
	if selectOptionsList then
		selectOptionsList = glDeleteList(selectOptionsList)
	end
	Spring.SDLStopTextInput()
	widgetHandler.textOwner = nil --widgetHandler:DisownText()
	if searchBox then
		searchBox:blur()
	end
end

-- every option by id. During init() this is the list being built, afterwards the full list
-- (the search filter only changes what is shown).
local optionsById = {}
local function indexOptions()
	optionsById = {}
	for _, option in ipairs(options) do
		if option.id and not optionsById[option.id] then
			optionsById[option.id] = option
		end
	end
end
local function getOption(id)
	return optionsById[id]
end

-- Main name color, and the one for sub-options and for what follows a prefix. Labels get one color.
local function getNameColors(option)
	if option.dimmed then
		return "\255\100\100\100", "\255\100\100\100"
	elseif option.category == types.dev then
		return devMainOptionColor, devOptionColor
	elseif option.category == types.advanced and (devMode or devUI) then
		return advMainOptionColor, advOptionColor
	elseif option.type == nil then
		return "\255\255\200\130"
	end
	return "\255\225\225\225", widgetOptionColor
end

local function getOptionLabel(option)
	return option.prefix and (option.prefix .. "  " .. option.name) or option.name
end

-- what a line takes up in the list, with the gap a section leaves before the next heading
local function lineHeight(line)
	return line.h
end

-- what a line draws in, at the top of what it takes up
local function contentHeight(line)
	return line.kind == "heading" and metrics.headingHeight or metrics.rowHeight
end

-- r is { x1, y1, x2, y2 }; its edges count as inside
local function inRect(r, mx, my)
	return r ~= nil and math_isInRect(mx, my, r[1], r[2], r[3], r[4])
end

-- Decimals a number needs, up to 4. Counted, not read off tostring: Lua numbers are 32-bit floats in
-- the engine, which writes 0.15 as "0.15000001".
local function decimalsOf(x)
	for d = 0, 3 do
		local scaled = x * 10 ^ d
		if math.abs(scaled - math.floor(scaled + 0.5)) <= 0.00001 * math.max(1, math.abs(scaled)) then
			return d
		end
	end
	return 4
end

-- the value a slider shows, rounded to its step
local function sliderValueText(option)
	if option.steps then
		local value = NearestValue(option.steps, option.value)
		return string.format("%." .. decimalsOf(value) .. "f", value)
	end
	return string.format("%." .. decimalsOf(option.step or 1) .. "f", option.value)
end

-- A color option's value is { r, g, b }, each from 0 to max on its step. White is what shows as full
-- color (max when not given); up to max a channel goes brighter than the screen can show.
function view.shownColor(option)
	local white, value = option.white or option.max, option.value
	return { value[1] / white, value[2] / white, value[3] / white }
end

-- a channel of a color option, rounded to its step
function view.channelText(option, value)
	return string.format("%." .. decimalsOf(option.step or 1) .. "f", value)
end

function view.sameColor(a, b)
	return a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
end

-- whitespace alone is not a search
function view.searching()
	return string.find(inputText, "%S") ~= nil
end

-- The header switch is the advanced one, or the developer UI's while that is on: it shows every
-- setting, so advanced does nothing then. A dev build shows everything and has no switch.
function view.switchCaption()
	if devUI and not devMode then
		return BAR.I18N("ui.settings.option.devmode")
	end
	return BAR.I18N("ui.settings.advanced")
end

-- indent levels: the rows under a section heading do not step in
local function indentOf(option)
	local n, parent = 0, option.parentOption
	while parent do
		if parent.type then
			n = n + 1
		end
		parent = parent.parentOption
	end
	return n
end

-- a sub-option of a widget that is switched off does nothing for now
local function inactive(option)
	local parent = option.parentOption
	while parent do
		if parent.type == "bool" and parent.widget and not parent.value then
			return true
		end
		parent = parent.parentOption
	end
	return false
end

-- draws the window again into its display list
function view.refresh()
	if windowList then
		gl.DeleteList(windowList)
	end
	windowList = gl.CreateList(DrawWindow)
end

-- Whole pixels throughout, so edges and glyphs do not land between pixels.
function view.setLayout()
	local s = widgetScale
	local pad = math.floor(8 * s)
	layout.window = { screenX, screenY - screenHeight, screenX + screenWidth, screenY }
	local a = { screenX + pad, screenY - screenHeight + pad, screenX + screenWidth - pad, screenY - pad }
	layout.area = a

	metrics.rowHeight = math.floor(tuning.rowHeight * s)
	metrics.rowFs = math.floor(tuning.fontSize * s)
	metrics.dropdownFs = math.floor(tuning.dropdownFontSize * s)
	metrics.headingHeight = math.floor(metrics.rowHeight * 1.35)
	metrics.headingFs = math.floor(tuning.headingFontSize * s)
	metrics.sectionGap = math.floor(10 * s)
	metrics.tabHeadingFs = math.floor(tuning.categoryFontSize * s * 1.25)
	metrics.groupHeight = math.floor(tuning.categoryHeight * s)
	metrics.groupFs = math.floor(tuning.categoryFontSize * s)
	metrics.sectionHeight = math.floor(tuning.subcategoryHeight * s)
	metrics.sectionFs = math.floor(tuning.subcategoryFontSize * s)
	metrics.rowPad = math.floor(6 * s)
	metrics.sidePad = math.floor(12 * s)
	metrics.inset = math.floor(4 * s)
	metrics.headerH = math.floor(34 * s)
	metrics.gap = math.floor(12 * s)
	metrics.cardLip = math.floor(5 * s)
	metrics.titleY = math.floor(17 * s)
	metrics.titleFs = math.floor(tuning.fontSize * s * 1.55)
	metrics.sidebarW = math.floor(230 * s)
	metrics.barW = math.floor(14 * s)
	metrics.accentW = math.max(2, math.floor(3 * s))
	metrics.underlineH = math.max(1, math.floor(2 * s))
	metrics.indent = math.floor(18 * s)
	metrics.chevron = math.floor(8 * s)
	metrics.toggleW = math.floor(36 * s)
	metrics.toggleH = math.floor(metrics.rowHeight * 0.6)
	-- the text inside the controls, and the room a slider's value takes after its track
	metrics.controlFs = math.floor(tuning.controlFontSize * s)
	metrics.valueW = math.floor(tuning.controlFontSize * s * 4)
	metrics.stripLineH = math.floor(metrics.rowFs * 1.45)
	metrics.stripH = metrics.stripLineH * (1 + tuning.descriptionLines) + math.floor(10 * s)
	metrics.captionFs = math.floor(metrics.rowFs * 1.05)
	metrics.csPanel = math.floor(elementCorner)
	metrics.csSmall = math.floor(elementCorner * 0.66)
	metrics.selectPadding = math.floor(4 * s)
	metrics.selectScrollbar = math.max(3, math.floor(4 * s))
	metrics.selectBorder = math.max(1, math.floor(vsy / 900))
	-- the color picker, a little wider than it is tall for its square field
	metrics.pickerH = math.floor(metrics.rowHeight * 9.5)
	metrics.pickerW = math.floor(metrics.pickerH * 1.06)

	layout.sidebarTop = a[4] - metrics.headerH - metrics.inset - math.floor(8 * s)
	-- the column and the strip are cards side by side, as far apart as they are from the window edge
	layout.listX1 = a[1] + metrics.sidebarW + pad
	layout.listTop = a[4] - metrics.headerH - metrics.inset
	layout.stripTop = a[2] + metrics.stripH
	layout.listBottom = layout.stripTop + metrics.inset
	layout.barX1 = a[3] - metrics.inset - metrics.barW
	layout.listRight = layout.barX1 - metrics.gap
	-- the controls share a column, all starting on one line, with sliders and dropdowns across it
	metrics.controlW = math.floor(tuning.controlsWidth * s)

	-- the header band: the search field, then the unfold all and advanced switches, each with its caption
	local rowTop = a[4] - math.floor(4 * s)
	local rowBottom = a[4] - metrics.headerH + math.floor(4 * s)
	local togH = math.floor((rowTop - rowBottom) * 0.62)
	local togY1 = math.floor((rowTop + rowBottom) * 0.5) - math.floor(togH * 0.5)
	local togW = math.floor(38 * s)
	-- a click on a switch or its caption flips it
	local function hitArea(switch, caption)
		local captionW = math.floor(font:GetTextWidth(caption) * metrics.captionFs)
		return { switch[1] - metrics.rowPad * 2 - captionW, rowBottom, switch[3] + metrics.rowPad, rowTop }
	end
	local x2 = a[3] - metrics.inset
	layout.switch = { x2 - togW, togY1, x2, togY1 + togH }
	layout.switchHit = hitArea(layout.switch, view.switchCaption())
	local unfoldX2 = math.floor(layout.switchHit[1] - 16 * s)
	layout.unfoldSwitch = { unfoldX2 - togW, togY1, unfoldX2, togY1 + togH }
	layout.unfoldSwitchHit = hitArea(layout.unfoldSwitch, BAR.I18N("ui.settings.unfoldall"))
	searchBox:setRect(
		layout.listX1,
		rowBottom,
		layout.unfoldSwitchHit[1] - math.floor(28 * s),
		rowTop,
		math.floor((rowTop - rowBottom) * 0.5)
	)
end

-- A family is folded or opened by hand, or all open under "unfold all". Otherwise it starts folded
-- while its widget is off, and when it holds only advanced rows or a grid of toggles.
function view.isFolded(option)
	if not option.type then
		return false -- section headings do not fold
	end
	local folded = option.id and view.folded[option.id]
	if folded ~= nil then
		return folded
	end
	if view.unfoldAll then
		return false
	end
	if option.type == "bool" and option.widget ~= nil and not option.value then
		return true
	end
	return not view.startsOpen[option]
end

-- The list: section headings and the rows of the open tab, without the rows of folded families;
-- compact toggles share lines. Under a search, the matches of every tab, under a heading per tab.
function view.build()
	local lines, childCount, startsOpen = {}, {}, {}
	local searching = view.searching()
	-- only rows the list can show: a family of advanced rows has nothing to unfold in basic mode
	for _, option in ipairs(options) do
		local parent = option.parentOption
		if parent and option.name and showOption(option) then
			childCount[parent] = (childCount[parent] or 0) + 1
			if not option.compact and (not option.category or option.category == types.basic) then
				startsOpen[parent] = true
			end
		end
	end
	view.childCount, view.startsOpen = childCount, startsOpen
	view.matches, view.headingOf = {}, {}

	-- the open tab has to be one the column shows
	local valid
	for _, group in ipairs(optionGroups) do
		if group.id == currentGroupTab and group.numOptions > 0 and (devMode or devUI or group.id ~= "dev") then
			valid = true
		end
	end
	if not valid and optionGroups[1] then
		currentGroupTab = optionGroups[1].id
	end

	local cells
	local function add(option)
		if option.type == nil then
			if option.name then
				lines[#lines + 1] = { kind = "heading", option = option, text = option.name }
			end
			cells = nil
		elseif option.compact then
			if cells and #cells.cells < tuning.compactColumns and cells.parent == option.parentOption then
				cells.cells[#cells.cells + 1] = option
			else
				cells = { kind = "cells", cells = { option }, parent = option.parentOption, depth = indentOf(option) }
				lines[#lines + 1] = cells
			end
		else
			lines[#lines + 1] = { kind = "row", option = option }
			cells = nil
		end
	end
	local function folded(option)
		local parent = option.parentOption
		while parent do
			if childCount[parent] and view.isFolded(parent) then
				return true
			end
			parent = parent.parentOption
		end
		return false
	end

	if searching then
		for _, group in ipairs(optionGroups) do
			for _, option in ipairs(options) do
				if option.group == group.id and option.name and showOption(option) then
					if not view.headingOf[group] then
						lines[#lines + 1] = { kind = "heading", group = group, text = group.name }
						view.headingOf[group] = #lines
						view.matches[group] = 0
						cells = nil
					end
					if option.type then
						view.matches[group] = view.matches[group] + 1
					end
					add(option)
				end
			end
		end
	else
		for _, option in ipairs(options) do
			if option.group == currentGroupTab and showOption(option) and not folded(option) then
				add(option)
			end
		end
	end

	-- a section leaves some room before the next heading, a tab's results more before the next tab's
	local off = 0
	for i, line in ipairs(lines) do
		local nextLine = lines[i + 1]
		line.h = contentHeight(line)
		if nextLine and nextLine.kind == "heading" and line.kind ~= "heading" then
			line.h = line.h + (nextLine.group and metrics.sectionGap * 2 or metrics.sectionGap)
		end
		line.off = off
		off = off + line.h
	end
	view.lines, layout.totalH = lines, off
	view.setScroll(view.scroll)
end

-- the furthest the first line can go with the band still full
function view.maxScroll()
	local band = (layout.listTop or 0) - (layout.listBottom or 0)
	local used, i = 0, #view.lines
	while i > 0 do
		local h = lineHeight(view.lines[i])
		if used + h > band then
			break
		end
		used = used + h
		i = i - 1
	end
	return i
end

function view.setScroll(n)
	view.scroll = math.max(0, math.min(n, view.maxScroll()))
end

-- pixels of the list above the first line shown
function view.offset()
	local first = view.lines[view.scroll + 1]
	return first and first.off or 0
end

-- how many lines the band holds from where the list is now, or going up, the page that ends there
function view.pageLines(up)
	local band, used, n = layout.listTop - layout.listBottom, 0, 0
	local from, to, dir = view.scroll + 1, #view.lines, 1
	if up then
		from, to, dir = view.scroll, 1, -1
	end
	for i = from, to, dir do
		used = used + lineHeight(view.lines[i])
		if used > band then
			break
		end
		n = n + 1
	end
	return math.max(1, n)
end

function view.scrollBy(n)
	local before = view.scroll
	view.setScroll(view.scroll + n)
	if view.scroll ~= before then
		view.litPin = false
		view.refresh()
	end
end

-- The heading the column marks (a tab heading under a search): the one last jumped to from the
-- column, as the list may not scroll far enough to bring it to the top; else at the end of the list
-- the last one, and otherwise the last one at or above the first line shown.
function view.litLine(tabsOnly)
	local lit, pinned
	local atEnd = view.scroll > 0 and view.scroll >= view.maxScroll()
	for i, line in ipairs(view.lines) do
		if line.kind == "heading" and (line.group or not tabsOnly) then
			if view.litPin and (line.option or line.group) == view.litPin then
				pinned = i
			end
			if atEnd or i <= view.scroll + 1 then
				lit = i
			end
		end
	end
	return pinned or lit
end

-- one of the window's sounds, unless they are off
function view.sound(name, volume)
	if playSounds then
		Spring.PlaySoundFile(sounds[name], volume, "ui")
	end
end

-- What the arrow keys go through, in order: each row, and each cell of a line of cells.
function view.selectable()
	local items = {} --[[@as table<integer, table>]]
	for i, line in ipairs(view.lines) do
		if line.kind == "row" then
			items[#items + 1] = { option = line.option, line = i }
		elseif line.kind == "cells" then
			for c, option in ipairs(line.cells) do
				items[#items + 1] = { option = option, line = i, cell = c }
			end
		end
	end
	return items
end

-- Scrolls as little as it takes to show line i whole, with the heading right above it going up.
---@param i integer
function view.scrollTo(i)
	local line = view.lines[i]
	if not line then
		return
	end
	local target = view.scroll
	if i <= view.scroll then
		target = i - 1
		if view.lines[i - 1] and view.lines[i - 1].kind == "heading" then
			target = i - 2
		end
	else
		local band = layout.listTop - layout.listBottom
		while target < i - 1 and line.off + contentHeight(line) - view.lines[target + 1].off > band do
			target = target + 1
		end
	end
	view.scrollBy(math.max(0, target) - view.scroll)
end

-- selects a row, shown in the strip, and scrolls it into view
function view.select(option, lineIndex)
	view.selected, view.stripOption = option, option
	if lineIndex then
		view.scrollTo(lineIndex)
	end
end

-- init() makes the options and tabs anew: what the window holds on to becomes the new one of its id
function view.rebind()
	local function same(item)
		if item and item.numOptions then
			for _, group in ipairs(optionGroups) do
				if group.id == item.id then
					return group
				end
			end
		end
		return item and item.id and getOption(item.id) or false
	end
	view.selected, view.stripOption, view.litPin = same(view.selected), same(view.stripOption), same(view.litPin)
	openSelect, draggingSlider = same(openSelect) or nil, same(draggingSlider) or nil
	if view.picker then
		local option = same(view.picker.option)
		if option and option.type == "color" then
			view.picker.option = option
		else
			view.closePicker()
		end
	end
end

-- Up and down go a line along, in lines of cells to the same column; across goes a cell along. With
-- nothing selected yet, it starts at the first line shown, or going up the last one.
function view.moveSelection(dir, across)
	local items = view.selectable()
	local at = 0
	for i, item in ipairs(items) do
		if item.option == view.selected then
			at = i
		end
	end
	local target
	if at == 0 then
		local first, last
		for i, item in ipairs(items) do
			if item.line > view.scroll then
				first = first or i
				last = layout.rowOf[item.option] and i or last
			end
		end
		target = items[dir > 0 and (first or 1) or (last or first or #items)]
	elseif across then
		target = items[at + dir]
	else
		local from, i = items[at], at
		repeat
			i = i + dir
		until not items[i] or items[i].line ~= from.line
		if items[i] then
			local same = {}
			for _, item in ipairs(items) do
				if item.line == items[i].line then
					same[#same + 1] = item
				end
			end
			target = same[math.min(from.cell or 1, #same)]
		end
	end
	if target then
		view.select(target.option, target.line)
	end
end

-- moves a slider n steps along, or to the n-th next of its listed steps
function view.stepSlider(option, n)
	local min, max = sliderRange(option)
	local value
	if option.steps then
		local index = 1
		for i, v in ipairs(option.steps) do
			if math.abs(v - option.value) < math.abs(option.steps[index] - option.value) then
				index = i
			end
		end
		value = option.steps[math.max(1, math.min(#option.steps, index + n))]
	else
		local step = option.step or (max - min) / 100
		value = math.max(min, math.min(max, math.floor((option.value + n * step) / step + 0.5) * step))
	end
	if value ~= option.value then
		applyOptionValue(option, value)
		view.sound("sliderDrag", 0.3)
	end
end

-- Left and right on the selected row: a family folds or unfolds as in a tree (on a slider's row, which
-- they step, with ctrl), a slider steps (ten at a time with ctrl), a toggle goes off or on, and along
-- a line of cells the selection moves.
function view.adjustSelected(dir, ctrl)
	local option = view.selected
	if not (option and layout.rowOf[option]) then
		return
	end
	if option.compact then
		view.moveSelection(dir, true)
	elseif view.childCount[option] and not view.searching() and (ctrl or option.type ~= "slider") then
		view.folded[option.id] = dir < 0
		view.build()
		view.refresh()
	elseif option.type == "slider" then
		view.stepSlider(option, ctrl and dir * 10 or dir)
	elseif option.type == "bool" and option.value ~= (dir > 0) then
		applyOptionValue(option, dir > 0)
		view.sound(dir > 0 and "toggleOnClick" or "toggleOffClick", 0.75)
	end
end

-- Enter on the selected row: flips a toggle, opens a dropdown or a color picker, runs a row's click,
-- or folds a row with no control.
function view.activateSelected()
	local option = view.selected
	if not (option and layout.rowOf[option]) then
		return
	end
	if option.type == "bool" then
		applyOptionValue(option, not option.value)
		view.sound(option.value and "toggleOnClick" or "toggleOffClick", 0.75)
	elseif option.type == "select" then
		openSelect = option
		view.selectKey = tonumber(option.value) or 1
		selectScrollOffset = math.max(0, view.selectKey - 8)
		view.sound("selectUnfoldClick", 0.6)
	elseif option.type == "color" then
		view.openPicker(option)
	elseif option.onclick then
		option.onclick(option)
	elseif view.childCount[option] and not view.searching() then
		view.adjustSelected(view.isFolded(option) and 1 or -1, true)
	end
end

-- Tab and shift-tab: the next tab in the column, or the one before, round the end
function view.cycleTab(dir)
	local tabs, at = {}, 1
	for _, group in ipairs(optionGroups) do
		if group.numOptions > 0 and (devMode or devUI or group.id ~= "dev") then
			tabs[#tabs + 1] = group
			if group.id == currentGroupTab then
				at = #tabs
			end
		end
	end
	if #tabs > 0 then
		view.openTab(tabs[(at - 1 + dir) % #tabs + 1])
	end
end

-- a small triangle: pointing right while its family is folded, down while it is open
local chevron = { x = 0, y = 0, h = 0, folded = false }
local function chevronVertices()
	local x, y, h = chevron.x, chevron.y, chevron.h
	if chevron.folded then
		gl.Vertex(x, y + h)
		gl.Vertex(x, y - h)
		gl.Vertex(x + math.floor(h * 1.3), y)
	else
		gl.Vertex(x - math.floor(h * 0.2), y + math.floor(h * 0.65))
		gl.Vertex(x + math.floor(h * 1.5), y + math.floor(h * 0.65))
		gl.Vertex(x + math.floor(h * 0.65), y - math.floor(h * 0.65))
	end
end
function draw.chevron(x, cy, size, folded, color)
	color = color or look.chevron
	chevron.x, chevron.y, chevron.h, chevron.folded = x, cy, math.floor(size * 0.5), folded
	gl.Color(color[1], color[2], color[3], color[4])
	gl.BeginEnd(GL.TRIANGLES, chevronVertices)
	gl.Color(1, 1, 1, 1)
end

-- The column: the title, then the tabs, with the open one's sections under it and the section the
-- list is showing marked. Under a search, the tabs with matches and how many.
function draw.sidebar()
	local a = layout.area
	local x1, x2 = a[1], a[1] + metrics.sidebarW
	RectRound(
		x1,
		a[2],
		x2,
		layout.sidebarTop + metrics.cardLip,
		metrics.csPanel,
		1,
		1,
		1,
		1,
		look.sidebarFill,
		look.sidebarFillTop
	)
	font:Print(
		look.title .. BAR.I18N("ui.topbar.button.settings"),
		x1 + metrics.sidePad,
		a[4] - metrics.titleY,
		metrics.titleFs,
		"ov"
	)

	-- made changes that wait for a restart: said at the foot of the column, where it stays in sight
	local bottom = a[2]
	if changesRequireRestart then
		local note =
			text.wrap(font, BAR.I18N("ui.settings.madechanges"), x2 - x1 - metrics.sidePad * 2, metrics.sectionFs)
		for i = #note, 1, -1 do
			font:Print(
				look.restart .. note[i],
				x1 + metrics.sidePad,
				bottom + math.floor(metrics.sectionHeight * 0.5),
				metrics.sectionFs,
				"ov"
			)
			bottom = bottom + math.floor(metrics.sectionFs * 1.3)
		end
		bottom = bottom + metrics.inset * 2
	end

	layout.sidebar = {}
	local searching = view.searching()
	local lit = view.litLine(searching)
	local litGroup = searching and lit and view.lines[lit].group
	local y = layout.sidebarTop
	for _, group in ipairs(optionGroups) do
		if
			group.numOptions > 0
			and (devMode or devUI or group.id ~= "dev")
			and (not searching or view.matches[group])
			and y - metrics.groupHeight >= bottom
		then
			local r = { x1, y - metrics.groupHeight, x2, y }
			local open = not searching and group.id == currentGroupTab
			local selected = open or group == litGroup
			if selected then
				RectRound(
					r[1] + metrics.inset,
					r[2],
					r[3] - metrics.inset,
					r[4],
					metrics.csSmall,
					1,
					1,
					1,
					1,
					look.selectedFill
				)
			end
			local ty = math.floor((r[2] + r[4]) * 0.5)
			font:Print(
				(selected and look.groupSelected or look.group) .. group.name,
				x1 + metrics.sidePad,
				ty,
				metrics.groupFs,
				"ov"
			)
			if searching then
				font:Print(look.count .. view.matches[group], x2 - metrics.sidePad, ty, metrics.groupFs, "rov")
			end
			layout.sidebar[#layout.sidebar + 1] = { rect = r, group = group, line = view.headingOf[group] }
			y = r[2]

			if open then
				for i, line in ipairs(view.lines) do
					if line.kind == "heading" and y - metrics.sectionHeight >= bottom then
						local sr = { x1, y - metrics.sectionHeight, x2, y }
						local isLit = i == lit
						if isLit then
							RectRound(
								x1 + metrics.sidePad,
								sr[2] + metrics.inset,
								x1 + metrics.sidePad + metrics.accentW,
								sr[4] - metrics.inset,
								0,
								0,
								0,
								0,
								0,
								look.sectionAccent
							)
						end
						local caption = text.fit(font, line.text, x2 - x1 - metrics.sidePad * 3, metrics.sectionFs)
						font:Print(
							(isLit and look.sectionLit or look.section) .. caption,
							x1 + metrics.sidePad * 2,
							math.floor((sr[2] + sr[4]) * 0.5),
							metrics.sectionFs,
							"ov"
						)
						layout.sidebar[#layout.sidebar + 1] = { rect = sr, line = i }
						y = sr[2]
					end
				end
			end
		end
	end
end

-- A section heading on a sheen band, with a line closing it off underneath. Under a search, a tab's
-- results start with its name on a band like the open tab's in the column, set apart from the
-- section headings among them, with how many rows it found.
function draw.heading(line, top, bottom)
	local x1, x2 = layout.listX1, layout.listRight
	local cy = math.floor((top + bottom) * 0.5)
	if line.group then
		RectRound(x1, bottom, x2, top, metrics.csSmall, 1, 1, 1, 1, look.selectedFill)
		font:Print(look.groupSelected .. line.text, x1 + metrics.rowPad, cy, metrics.tabHeadingFs, "ov")
		font:Print(look.count .. view.matches[line.group], x2 - metrics.rowPad, cy, metrics.rowFs, "rov")
		return
	end
	RectRound(x1, bottom, x2, top - metrics.csSmall, metrics.csSmall, 1, 1, 0, 0, look.headingSheen, look.headingSheen)
	RectRound(x1, bottom, x2, bottom + metrics.underlineH, 0, 0, 0, 0, 0, look.headingLine, look.headingLineFade)
	font:Print(look.heading .. line.text, x1 + metrics.rowPad, cy, metrics.headingFs, "ov")
end

-- Each draws its control in the column from x1 to right and returns where it starts.

function drawControl.bool(row, x1, right, cy)
	local half = math.floor(metrics.toggleH * 0.5)
	local tx1 = tuning.controlsAlignLeft and x1 or right - metrics.toggleW
	local r = { tx1, cy - half, tx1 + metrics.toggleW, cy - half + metrics.toggleH }
	row.control = r
	UiToggle(r[1], r[2], r[3], r[4], row.option.value)
	return tx1
end

-- the track with the value printed after it; the knob is the control, row.track the line it runs along
function drawControl.slider(row, x1, right, cy)
	local option = row.option
	if type(option.value) ~= "number" then -- just to be safe
		return right
	end
	local min, max = sliderRange(option)
	-- a value from outside the range (set by a widget or the config) keeps the knob at an end
	local pos = (option.value - min) / (max - min)
	if pos ~= pos then -- a range of one value
		pos = 0
	end
	pos = math.max(0, math.min(1, pos))
	local knob = math.floor(metrics.rowHeight * 0.26)
	local tx1, tx2 = x1 + knob, right - metrics.valueW
	local trackH = math.max(2, math.floor(metrics.rowHeight * 0.16))
	local trackY = cy - math.floor(trackH * 0.5)
	UiSlider(tx1, trackY, tx2, trackY + trackH, option.steps and option.steps or option.step, option.min, option.max)
	local kx = math.floor(tx1 + (tx2 - tx1) * pos)
	UiSliderKnob(kx, cy, knob)
	row.control = { kx - knob, cy - knob, kx + knob, cy + knob }
	row.track = { tx1, tx2 }
	row.knob = knob
	font:Print(look.value .. sliderValueText(option), right, cy, metrics.controlFs, "rov")
	return x1
end

-- the chosen entry inside the button, cut short of the square FlowUI draws at its right end
function drawControl.select(row, x1, right, cy, top, bottom)
	local option = row.option
	local inset = math.floor(metrics.rowHeight * 0.12)
	local r = { x1, bottom + inset, right, top - inset }
	local square = r[4] - r[2]
	row.control = r
	UiSelector(r[1], r[2], r[3], r[4])
	local h = math.floor(metrics.chevron * 0.5)
	draw.chevron(r[3] - math.floor(square * 0.5) - math.floor(h * 0.65), cy, metrics.chevron, false)
	local value = option.options[tonumber(option.value)]
	if value ~= nil then
		value = tostring(value)
		local shown = text.fit(font, value, r[3] - r[1] - square - metrics.rowPad * 2, metrics.controlFs)
		row.cutValue = shown ~= value and value or nil
		if option.id == "font2" then
			-- the second font's dropdown shows its value in that font
			font:End()
			font2:Begin()
			font2:SetOutlineColor(0, 0, 0, 0.4)
			font2:Print(look.value .. shown, r[1] + metrics.rowPad, cy, metrics.controlFs, "ov")
			font2:End()
			font:Begin()
			font:SetOutlineColor(0, 0, 0, 0.4)
		else
			font:Print(look.value .. shown, r[1] + metrics.rowPad, cy, metrics.controlFs, "ov")
		end
	end
	return r[1]
end

-- a swatch of the color, where a toggle would sit; a press opens the picker
function drawControl.color(row, x1, right, _, top, bottom)
	local option = row.option
	if type(option.value) ~= "table" then -- just to be safe
		return right
	end
	local inset = math.floor(metrics.rowHeight * 0.12)
	local sx1 = tuning.controlsAlignLeft and x1 or right - metrics.toggleW
	local r = { sx1, bottom + inset, sx1 + metrics.toggleW, top - inset }
	row.control = r
	WG.FlowUI.Draw.ColorSwatch(r[1], r[2], r[3], r[4], view.shownColor(option))
	return sx1
end

-- a row that does something when clicked is a button across its whole width
function drawControl.click(row, _, right)
	row.control = row.hover
	return right
end

-- One setting: its name, indented under its parent with a fold arrow when it has sub-options (and how
-- many while folded), and its control in the column at the right. Its hover, fold and control areas
-- go into layout for clicks to find.
function draw.row(option, top, bottom)
	local cy = math.floor((top + bottom) * 0.5)
	local depth = indentOf(option)
	local x = layout.listX1 + metrics.rowPad * 2 + metrics.chevron + depth * metrics.indent
	local right = layout.listRight - metrics.rowPad
	local row = { option = option, hover = { layout.listX1, bottom, layout.listRight, top } }
	layout.rows[#layout.rows + 1] = row
	layout.rowOf[option] = row

	local drawIt = drawControl[option.type]
	local left = drawIt and drawIt(row, right - metrics.controlW, right, cy, top, bottom) or right

	local family = view.childCount[option] and not view.searching()
	local folded = family and view.isFolded(option)
	local count = folded and "(" .. view.childCount[option] .. ")" or ""
	local countW = folded and math.floor(font:GetTextWidth(count) * metrics.rowFs) + metrics.rowPad or 0
	local markW = option.restart and math.floor(font:GetTextWidth("*") * metrics.rowFs) + metrics.inset or 0

	local label = getOptionLabel(option)
	local shown = text.fit(font, label, left - metrics.rowPad * 2 - x - markW - countW, metrics.rowFs)
	row.cut = shown ~= label
	local nameW = math.floor(font:GetTextWidth(shown) * metrics.rowFs)
	if family then
		row.chevronX = x - metrics.rowPad - metrics.chevron
		draw.chevron(row.chevronX, cy, metrics.chevron, folded)
		if folded then
			font:Print(look.count .. count, x + nameW + markW + metrics.rowPad, cy, metrics.rowFs, "ov")
		end
		-- everything left of the control folds it, or the whole row when it has none
		row.fold = { layout.listX1, bottom, left < right and left - metrics.rowPad or layout.listRight, top }
	end

	local mainColor, subColor = getNameColors(option)
	if inactive(option) then
		mainColor, subColor = look.inactive, look.inactive
	end
	if option.prefix and string.sub(shown, 1, string.len(option.prefix)) == option.prefix then
		shown = mainColor
			.. option.prefix
			.. (subColor or mainColor)
			.. string.sub(shown, string.len(option.prefix) + 1)
	else
		shown = (depth > 0 and subColor or mainColor) .. shown
	end
	font:Print(shown, x, cy, metrics.rowFs, "ov")
	if option.restart then
		font:Print(look.restartMark, x + nameW + metrics.inset, cy, metrics.rowFs, "ov")
	end
end

-- a line of compact toggles, a switch and a name each, in columns
function draw.cells(line, top, bottom)
	local cy = math.floor((top + bottom) * 0.5)
	local x0 = layout.listX1 + metrics.rowPad * 2 + metrics.chevron + line.depth * metrics.indent
	local cellW = math.floor((layout.listRight - x0) / tuning.compactColumns)
	local half = math.floor(metrics.toggleH * 0.5)
	for i, option in ipairs(line.cells) do
		local x1 = x0 + (i - 1) * cellW
		local x2 = x1 + cellW - metrics.rowPad
		local r = { x1, cy - half, x1 + metrics.toggleW, cy - half + metrics.toggleH }
		local row = { option = option, hover = { x1 - metrics.inset, bottom, x2, top }, control = r }
		layout.rows[#layout.rows + 1] = row
		layout.rowOf[option] = row
		UiToggle(r[1], r[2], r[3], r[4], option.value)
		local label = getOptionLabel(option)
		local shown = text.fit(font, label, x2 - r[3] - metrics.rowPad, metrics.rowFs)
		row.cut = shown ~= label
		local mainColor, subColor = getNameColors(option)
		if inactive(option) then
			mainColor, subColor = look.inactive, look.inactive
		end
		font:Print((line.depth > 0 and subColor or mainColor) .. shown, r[3] + metrics.rowPad, cy, metrics.rowFs, "ov")
	end
end

-- whole lines only, from the first one scrolled to; the band can end mid-line
function draw.lines()
	layout.rows, layout.rowOf = {}, {}
	local base = view.offset()
	for i = view.scroll + 1, #view.lines do
		local line = view.lines[i]
		local top = layout.listTop - (line.off - base)
		local bottom = top - contentHeight(line)
		if bottom < layout.listBottom then
			break
		end
		if line.kind == "heading" then
			draw.heading(line, top, bottom)
		elseif line.kind == "cells" then
			draw.cells(line, top, bottom)
		else
			draw.row(line.option, top, bottom)
		end
	end
end

-- Draws the window into its display list and records in layout where everything went. The search
-- field, the switch, the scrollbar, hover and the strip's text are drawn live in DrawScreen.
function DrawWindow()
	glTexture(false)
	local w, a = layout.window, layout.area
	UiElement(w[1], w[2], w[3], w[4], 1, 1, 1, 1, 1, 1, 1, 1, WG.FlowUI.clampedOpacity)
	RectRound(
		layout.listX1,
		a[2],
		a[3],
		layout.stripTop,
		metrics.csSmall,
		1,
		1,
		1,
		1,
		look.stripFill,
		look.stripFillTop
	)
	font:Begin()
	font:SetOutlineColor(0, 0, 0, 0.4)
	draw.sidebar()
	draw.lines()
	font:End()
	glColor(1, 1, 1, 1)
end

local function updateGrabinput()
	-- grabinput makes alt-tabbing harder, so loosen grip a bit when in lobby would be wise
	if Spring.GetConfigInt("grabinput", 1) == 1 and not gameOver then
		if chobbyInterface then
			if enabledGrabinput then
				enabledGrabinput = false
				Spring.SendCommands("grabinput 0")
			end
		else
			if not enabledGrabinput then
				enabledGrabinput = true
				Spring.SendCommands("grabinput 1")
			end
		end
	else
		enabledGrabinput = false
		Spring.SendCommands("grabinput 0")
	end
end

local sec = 0
local sec2 = 0
local lastUpdate = 0
local ambientplayerCheck = false
local muteFadeTime = 0.35
local isOffscreen = false
local isOffscreenTime
local prevOffscreenVolume
local apiUnitTrackerEnabledCount = 0
local cachedMuteOffscreen = Spring.GetConfigInt("muteOffscreen", 0) == 1
local offscreenCheckTimer = 0

function resetUserVolume()
	if prevOffscreenVolume then
		Spring.SetConfigInt("snd_volmaster", prevOffscreenVolume)
		prevOffscreenVolume = nil
	end
end

function widget:Update(dt)
	local now = os_clock()

	-- throttle offscreen detection to ~4x/sec (unless actively fading)
	local checkOffscreen = isOffscreenTime ~= nil
	if not checkOffscreen then
		offscreenCheckTimer = offscreenCheckTimer + dt
		if offscreenCheckTimer > 0.25 then
			offscreenCheckTimer = 0
			checkOffscreen = true
		end
	end
	if checkOffscreen then
		local prevIsOffscreen = isOffscreen
		isOffscreen = select(6, Spring.GetMouseState())
		if isOffscreen and enabledGrabinput then
			enabledGrabinput = false
		end
		if cachedMuteOffscreen then
			if isOffscreen ~= prevIsOffscreen then
				local prevIsOffscreenTime = isOffscreenTime
				isOffscreenTime = now
				if isOffscreen and not prevIsOffscreenTime then
					prevOffscreenVolume = tonumber(Spring.GetConfigInt("snd_volmaster", 40) or 40)
				end
			end
			if isOffscreenTime then
				if isOffscreenTime + muteFadeTime > now then
					if isOffscreen then
						Spring.SetConfigInt(
							"snd_volmaster",
							prevOffscreenVolume * (1 - ((now - isOffscreenTime) / muteFadeTime))
						)
					else
						Spring.SetConfigInt(
							"snd_volmaster",
							prevOffscreenVolume * ((now - isOffscreenTime) / muteFadeTime)
						)
					end
				else
					isOffscreenTime = nil
					if isOffscreen then
						Spring.SetConfigInt("snd_volmaster", 0)
					else
						resetUserVolume()
					end
				end
			end
		end
	end

	if not initialized then
		return
	end

	-- widgetHandler:EnableWidget/DisableWidget are deferred but are used to change displayed options. This is a solution to update the options list after next frame.
	if scheduleInit then
		scheduleInit = nil
		init()
	end

	-- disable ambient player widget, also doing this on initialize but hell... players somehow still have this enabled
	if not ambientplayerCheck then
		ambientplayerCheck = true
		if widgetHandler:IsWidgetKnown("Ambient Player") then
			widgetHandler:DisableWidget("Ambient Player")
		end
	end

	if sceduleOptionApply then
		-- waits while its color is still being picked
		local picking = view.picker and view.picker.option.id == sceduleOptionApply[2]
		if sceduleOptionApply[1] <= now and not picking then
			applyOptionValueByID(sceduleOptionApply[2], nil, true, true)
			sceduleOptionApply = nil
		end
	end

	--if tonumber(Spring.GetConfigInt("CameraSmoothing", 0)) == 1 then
	--	Spring.SetCameraState(nil, 1)
	--else
	if WG.lockcamera and not WG.lockcamera.GetPlayerID() and WG.setcamera_bugfix == true then
		Spring.SetCameraState(nil, cameraTransitionTime)
	end
	--end

	-- check if there is water shown 	(we do this because basic water 0 saves perf when no water is rendered)
	if not waterDetected then
		-- in case of modoption waterlevel has been made to show water
		if not checkedForWaterAfterGamestart and Spring.GetGameFrame() <= 30 then
			detectWater()
			checkedForWaterAfterGamestart = true
		end
		if heightmapChangeClock and heightmapChangeClock + 1 < now then
			for k, coords in pairs(heightmapChangeBuffer) do
				local x = coords[1]
				local z = coords[2]
				while x <= coords[3] do
					z = coords[2]
					while z <= coords[4] do
						if spGetGroundHeight(x, z) <= 0 then
							waterDetected = true
							Spring.SendCommands("water " .. desiredWaterValue)
							break
						end
						z = z + 8
					end
					if waterDetected then
						break
					end
					x = x + 8
				end
			end
			heightmapChangeClock = nil
			heightmapChangeBuffer = {}
		end
	end

	sec2 = sec2 + dt
	if sec2 > 0.5 then
		sec2 = 0
		continuouslyClean = Spring.GetConfigInt("ContinuouslyClearMapmarks", 0) == 1
		cachedMuteOffscreen = Spring.GetConfigInt("muteOffscreen", 0) == 1

		-- detect guishader toggle: force refresh when it comes back on
		local guishaderActive = WG.guishader ~= nil
		if guishaderActive and not guishaderWasActive then
			if backgroundGuishader then
				backgroundGuishader = glDeleteList(backgroundGuishader)
			end
		end
		guishaderWasActive = guishaderActive

		-- make sure widget is enabled
		if
			apiUnitTrackerEnabledCount < 10
			and widgetHandler.orderList["API Unit Tracker DEVMODE GL4"]
			and widgetHandler.orderList["API Unit Tracker DEVMODE GL4"] < 0.5
		then
			apiUnitTrackerEnabledCount = apiUnitTrackerEnabledCount + 1
			widgetHandler:EnableWidget("API Unit Tracker DEVMODE GL4")
		end

		updateGrabinput()
	end

	sec = sec + dt
	if show and (sec > lastUpdate + 0.5 or forceUpdate) then
		sec = 0
		forceUpdate = nil
		lastUpdate = sec

		local changes = false
		-- Sync widget toggle values in unfilteredOptions (the authoritative list)
		-- so changes persist across filter apply/clear cycles.
		for i, option in ipairs(unfilteredOptions) do
			if
				option.widget ~= nil
				and option.type == "bool"
				and option.value ~= GetWidgetToggleValue(option.widget)
			then
				option.value = GetWidgetToggleValue(option.widget)
				changes = true
			end
		end
		local resolution = getOption("resolution")
		if resolution and resolution.onload then
			local before = resolution.options[resolution.value]
			resolution.onload(resolution)
			changes = changes or resolution.options[resolution.value] ~= before
		end
		if view.rereadBound() then
			changes = true
		end
		local masterVolume, musicVolume = getOption("sndvolmaster"), getOption("sndvolmusic")
		if masterVolume then
			local value = tonumber(Spring.GetConfigInt("snd_volmaster", 40) or 40) -- update value because other widgets can adjust this too
			changes = changes or value ~= masterVolume.value
			masterVolume.value = value
		end
		if musicVolume then
			local value
			if WG.music and WG.music.GetMusicVolume then
				value = WG.music.GetMusicVolume()
			else
				value = tonumber(Spring.GetConfigInt("snd_volmusic", 50) or 50)
			end
			changes = changes or value ~= musicVolume.value
			musicVolume.value = value
		end
		if changes then
			applyFilter()
		end
	end
end

function widget:CommandNotify(cmdID, cmdParams, cmdOptions)
	if show then
		local mx, my = Spring.GetMouseState()
		if inRect(layout.window, mx, my) then
			return true
		end
	end
end

function widget:RecvLuaMsg(msg, playerID)
	-- restart-with-state: receive serialised unit state from the gadget and write it to disk
	-- Every player's widgets receive these, and the gadget only sends them in single player.
	if msg:sub(1, 4) == "rws:" and (not isSinglePlayer or playerID ~= Spring.GetMyPlayerID()) then
		return true -- Fake and maybe malicious
	end
	if msg == "rws:begin" then
		rwsBuffer = {}
		return true
	end
	local rwsChunk = msg:match("^rws:chunk:(.*)")
	if rwsChunk then
		if rwsBuffer then
			rwsBuffer[#rwsBuffer + 1] = rwsChunk
		end
		return true
	end
	if msg == "rws:commit" then
		if not rwsBuffer then
			return true
		end
		local data = table.concat(rwsBuffer)
		rwsBuffer = nil
		Spring.CreateDir("LuaUI/Config")
		local f, err = io.open("LuaUI/Config/restart_state.lua", "w")
		if not f then
			Spring.Echo("[Restart With State] Could not write state file: " .. tostring(err))
			return true
		end
		f:write(data)
		f:close()
		Spring.Echo("[Restart With State] State saved (" .. tostring(#data) .. " bytes). Restarting...")
		Spring.Restart("", getRestartWithStateScript())
		return true
	end
	if msg == "rws:clear" then
		local f = io.open("LuaUI/Config/restart_state.lua", "w")
		if f then
			f:close()
		end
		return true
	end
	if msg:sub(1, 18) == "LobbyOverlayActive" then
		chobbyInterface = (msg:sub(1, 19) == "LobbyOverlayActive1")
		updateGrabinput()
		if (isSinglePlayer or isReplay) and not chobbyInterface then
			Spring.SetConfigInt("VSync", Spring.GetConfigInt("VSyncGame", -1) * Spring.GetConfigInt("VSyncFraction", 1))
		end
	end
end

-- the thumb, where it is now; nil when the list fits and no bar is drawn
function view.thumb()
	return UiScrollerAt(
		layout.barX1,
		layout.listBottom,
		layout.barX1 + metrics.barW,
		layout.listTop,
		layout.totalH,
		view.offset()
	)
end

function draw.scrollbar(mx, my)
	local top, height = view.thumb()
	if top then
		local x1, x2 = layout.barX1, layout.barX1 + metrics.barW
		local over = mx >= x1 and mx <= x2 and my <= top and my >= top - height
		UiScroller(x1, layout.listBottom, x2, layout.listTop, layout.totalH, view.offset(), over, view.dragging)
	end
end

-- a switch with its caption on its left, lit while hovered
function draw.switch(switch, hit, on, caption, mx, my)
	local hovered = inRect(hit, mx, my)
	if hovered then
		UiSelectHighlight(hit[1], hit[2], hit[3], hit[4], metrics.csSmall, look.hoverOpacity, look.white)
	end
	UiToggle(switch[1], switch[2], switch[3], switch[4], on, hovered)
	font:Print(caption, switch[1] - metrics.rowPad, math.floor((hit[2] + hit[4]) * 0.5), metrics.captionFs, "rov")
end

-- beside the search field: unfold all, then the switch from view.switchCaption, or in a dev build a
-- note that it shows all
function draw.header(mx, my)
	local unfold = view.unfoldAll
	local caption = (unfold and look.captionOn or look.caption) .. BAR.I18N("ui.settings.unfoldall")
	draw.switch(layout.unfoldSwitch, layout.unfoldSwitchHit, unfold, caption, mx, my)
	if devMode then
		local hit = layout.switchHit
		local cy = math.floor((hit[2] + hit[4]) * 0.5)
		font:Print(
			devOptionColor .. BAR.I18N("ui.settings.option.devmode"),
			layout.switch[3],
			cy,
			metrics.captionFs,
			"rov"
		)
		return
	end
	local on = devUI or advSettings
	caption = (devUI and devOptionColor or on and look.captionOn or look.caption) .. view.switchCaption()
	draw.switch(layout.switch, layout.switchHit, on, caption, mx, my)
end

-- The selected row is marked, and what the mouse is over lights up: a tab or section in the column, the
-- part of a row that folds its family, or a row (green when clicking it does something) and its
-- control. Returns the hovered row, for the strip.
function draw.hover(mx, my, ml)
	-- the selected row: a faint band, with the accent the column marks its section with
	local selected = view.selected and layout.rowOf[view.selected]
	if selected then
		local h = selected.hover
		RectRound(h[1], h[2], h[3], h[4], metrics.csSmall, 1, 1, 1, 1, look.selectedRow)
		RectRound(
			h[1],
			h[2] + metrics.inset,
			h[1] + metrics.accentW,
			h[4] - metrics.inset,
			0,
			0,
			0,
			0,
			0,
			look.sectionAccent
		)
	end
	if openSelect then
		return layout.rowOf[openSelect]
	end
	if view.picker then
		return layout.rowOf[view.picker.option]
	end
	for _, entry in ipairs(layout.sidebar) do
		local r = entry.rect
		if inRect(r, mx, my) then
			if not (entry.group and entry.group.id == currentGroupTab and not view.searching()) then
				UiSelectHighlight(
					r[1] + metrics.inset,
					r[2],
					r[3] - metrics.inset,
					r[4],
					metrics.csSmall,
					look.hoverOpacity,
					look.white
				)
			end
			return nil
		end
	end
	if my < layout.listBottom or my > layout.listTop then
		return nil
	end
	for _, row in ipairs(layout.rows) do
		local h, o, option = row.hover, row.control, row.option
		if inRect(h, mx, my) then
			local f = row.fold
			if f and inRect(f, mx, my) then
				-- a button of its own, with its arrow lit
				UiSelectHighlight(f[1], f[2], f[3], f[4], metrics.csSmall, ml and 0.3 or 0.2, look.white)
				local cy = math.floor((h[2] + h[4]) * 0.5)
				draw.chevron(row.chevronX, cy, metrics.chevron, view.isFolded(option), look.chevronLit)
				return row
			end
			if o and option.onclick == nil and option.type ~= "click" and inRect(o, mx, my) then
				RectRound(o[1], o[2], o[3], o[4], 1, 2, 2, 2, 2, look.controlHover, look.controlHoverTop)
			end
			-- tuning can leave the row dark; one that does something when clicked still lights up
			if (option.type ~= "text" or row.fold) and (tuning.rowHighlight or option.onclick) then
				UiSelectHighlight(
					h[1],
					h[2],
					h[3],
					h[4],
					metrics.csSmall,
					option.onclick and (ml and 0.35 or 0.22) or look.hoverOpacity,
					option.onclick and look.clickRow or look.white
				)
			end
			return row
		end
	end
end

-- The strip under the list: the name of the setting last hovered or selected, what it does, and a last
-- line with its restart note and /option command, which a click copies. A description longer than
-- its lines also goes to the tooltip, while the row or the strip is under the mouse. Laid out again
-- only when the setting changes.
local strip = {}
function draw.strip(hovered, mx, my)
	if hovered then
		view.stripOption = hovered.option
	end
	local option = view.stripOption or nil
	local row = option and layout.rowOf[option]
	local cutValue = row and row.cutValue
	local width = layout.area[3] - layout.listX1 - metrics.sidePad * 2
	if option ~= strip.option or cutValue ~= strip.cutValue or width ~= strip.width then
		strip.option, strip.cutValue, strip.width = option, cutValue, width
		strip.title, strip.restart, strip.command, strip.lines, strip.tooltip = nil, nil, nil, {}, nil
		if option and option.name then
			local fs = metrics.rowFs
			if option.restart then
				strip.restart = look.restart .. BAR.I18N("ui.settings.changesrequirerestart")
			end
			if
				option.id
				and (advSettings or devMode or devUI)
				and (option.onchange or option.widget or option.widgetConfig or option.configInt or option.configFloat)
			then
				strip.command = "/option " .. option.id
			end
			local title = getOptionLabel(option)
			if cutValue then
				title = title .. ":  " .. cutValue
			end
			strip.title = look.title .. text.fit(font, title, width, fs)
			local description = option.description
			if type(description) == "string" and description:find("%S") and description ~= option.name then
				-- the last line is the restart note's and the command's when there are any
				local room = tuning.descriptionLines - ((strip.restart or strip.command) and 1 or 0)
				local lines = text.wrap(font, description, width, fs)
				for i = 1, math.min(room, #lines) do
					strip.lines[i] = look.description .. lines[i]
				end
				if room > 0 and lines[room + 1] then
					strip.lines[room] = look.description
						.. text.fit(font, lines[room] .. " " .. lines[room + 1], width, fs)
					strip.tooltip = description
				end
			end
		end
	end

	layout.stripCommand = false
	if not strip.title then
		return
	end
	local x1, x2 = layout.listX1 + metrics.sidePad, layout.area[3] - metrics.sidePad
	local lh = metrics.stripLineH
	local y = layout.stripTop - math.floor(metrics.inset * 1.5) - math.floor(lh * 0.5)
	font:Print(strip.title, x1, y, metrics.rowFs, "ov")
	for i, line in ipairs(strip.lines) do
		font:Print(line, x1, y - lh * i, metrics.rowFs, "ov")
	end
	local footY = y - lh * tuning.descriptionLines
	if strip.restart then
		font:Print(strip.restart, x1, footY, metrics.rowFs, "ov")
	end
	if strip.command then
		local w = math.floor(font:GetTextWidth(strip.command) * metrics.rowFs)
		local half = math.floor(lh * 0.5)
		local r = { x2 - w, footY - half, x2, footY + half, strip.command }
		layout.stripCommand = r
		-- lit while it can be clicked, and for a moment once copied
		local lit = inRect(r, mx, my) or os_clock() - view.copiedAt < 1
		font:Print((lit and look.commandLit or look.command) .. strip.command, x2, footY, metrics.rowFs, "rov")
	end
	local overStrip = mx >= layout.listX1 and mx <= layout.area[3] and my >= layout.area[2] and my <= layout.stripTop
	if strip.tooltip and WG.tooltip and (hovered or overStrip) then
		WG.tooltip.ShowTooltip("options_description", font:WrapText(strip.tooltip, WG.tooltip.getFontsize() * 90))
	end
end

-- The open dropdown's entries under its button, or above it when they would run off the screen;
-- at most 16 at a time, with a scrollbar beyond that. The graphics preset's dropdown also marks
-- the rows the presets set. Its display list is made again only when what it shows changed.
local popup = {}
function draw.selectPopup(mx, my)
	local option = openSelect
	local row = option and layout.rowOf[option]
	if not (option and row and row.control) then
		openSelect = nil
		return
	end
	if option.id == "preset" then
		for optionID, _ in pairs(presets.lowest) do
			local presetRow = layout.rowOf[getOption(optionID)]
			if presetRow ~= nil then
				local h = presetRow.hover
				RectRound(h[1], h[2] + 1, h[3], h[4] - 1, 1, 2, 2, 2, 2, look.presetRow, look.presetRowTop)
			end
		end
	end

	local button = row.control
	local itemH = button[4] - button[2]
	local pad = metrics.selectPadding
	local step = itemH + pad * 2
	local fontSize = metrics.dropdownFs
	local numItems = 0
	local width = button[3] - button[1]
	for _, value in pairs(option.options) do
		numItems = numItems + 1
		width = math.max(width, math.floor(font:GetTextWidth(tostring(value)) * fontSize) + pad * 6)
	end
	local maxVisible = math.min(numItems, 16)
	selectScrollOffset = math.max(0, math.min(selectScrollOffset or 0, numItems - maxVisible))
	local height = step * maxVisible
	local top = button[2]
	if button[2] - height < 0 and vsy - button[4] > button[2] then
		top = button[4] + height
	end

	layout.selectItems = {}
	local hovered
	local i = 0
	for k, _ in pairs(option.options) do
		i = i + 1
		local vi = i - selectScrollOffset
		if vi >= 1 and vi <= maxVisible then
			local item = { button[1], top - step * vi, button[1] + width, top - step * (vi - 1), k }
			layout.selectItems[vi] = item
			if inRect(item, mx, my) then
				hovered = k
			end
		end
	end
	-- the mouse moves the entry the arrow keys go from
	if hovered ~= nil then
		view.selectKey = hovered --[[@as number]]
	end
	if hovered ~= nil and hovered ~= prevSelectHover and playSounds then
		Spring.PlaySoundFile(sounds.selectHoverClick, 0.04, "ui")
	end
	prevSelectHover = hovered

	local sig = table.concat({
		option.id or "",
		selectScrollOffset,
		tostring(view.selectKey),
		tostring(option.value),
		button[1],
		top,
		width,
		WG.guishader and 1 or 0,
	}, "|")
	if sig ~= popup.sig or not selectOptionsList then
		popup.sig = sig
		if selectOptionsList then
			if WG.guishader then
				WG.guishader.removeRenderDlist(selectOptionsList)
			end
			glDeleteList(selectOptionsList)
		end
		local items = layout.selectItems
		selectOptionsList = glCreateList(function()
			local border = metrics.selectBorder
			local cs = math.floor(itemH * 0.1)
			RectRound(
				button[1] - border,
				top - height - border,
				button[1] + width + border,
				top + border,
				cs,
				1,
				1,
				1,
				1,
				look.selectBorder,
				look.selectBorder
			)
			RectRound(
				button[1],
				top - height,
				button[1] + width,
				top,
				cs,
				1,
				1,
				1,
				1,
				WG.guishader and look.selectBack or look.selectBackSolid,
				WG.guishader and look.selectBackTop or look.selectBackSolidTop
			)
			UiSelector(button[1], button[2], button[3], button[4])
			for _, item in ipairs(items) do
				local k = item[5]
				if k == option.value then
					RectRound(item[1], item[2], item[3], item[4], cs, 1, 1, 1, 1, look.selectCurrent)
				end
				if k == view.selectKey then
					UiSelectHighlight(item[1], item[2], item[3], item[4])
				end
				local itemFont = (option.optionsFont and fontOption and fontOption[k]) or font
				itemFont:Begin()
				itemFont:SetOutlineColor(0, 0, 0, 0.4)
				itemFont:Print(
					optionColor .. tostring(option.options[k]),
					item[1] + pad * 2,
					text.baseline(itemFont, item[2], item[4], fontSize),
					fontSize,
					"o"
				)
				itemFont:End()
			end
			if numItems > maxVisible then
				local x2 = button[1] + width
				local x1 = x2 - metrics.selectScrollbar
				local y1, y2 = top - height, top
				local thumbH = math.max((y2 - y1) * maxVisible / numItems, metrics.selectScrollbar * 2)
				local thumbY2 = y2 - (selectScrollOffset / (numItems - maxVisible)) * ((y2 - y1) - thumbH)
				gl.Color(look.scrollTrack[1], look.scrollTrack[2], look.scrollTrack[3], look.scrollTrack[4])
				gl.Rect(x1, y1, x2, y2)
				gl.Color(look.scrollThumb[1], look.scrollThumb[2], look.scrollThumb[3], look.scrollThumb[4])
				gl.Rect(x1, thumbY2 - thumbH, x2, thumbY2)
				gl.Color(1, 1, 1, 1)
			end
		end)
		if WG.guishader then
			WG.guishader.InsertScreenRect(button[1], button[2], button[3], button[4], "options_select", widget)
			WG.guishader.InsertScreenRect(
				button[1],
				top - height,
				button[1] + width,
				top,
				"options_select_options",
				widget
			)
			WG.guishader.insertRenderDlist(selectOptionsList)
		end
	end
	if not WG.guishader then
		glCallList(selectOptionsList)
	end
end

-- Opens FlowUI's color picker on a color option. Its changes apply as it goes; ESC puts back the
-- color it opened on, and a click anywhere off it closes it.
function view.openPicker(option)
	view.closePicker()
	local white, value = option.white or option.max, option.value
	view.picker = {
		option = option,
		original = { value[1], value[2], value[3] },
		ui = WG.FlowUI.ColorPicker.new({ value[1] / white, value[2] / white, value[3] / white }, option.max / white),
	}
	view.sound("selectUnfoldClick", 0.6)
end

function view.dropPickerList()
	local picker = view.picker
	local guishader = WG.guishader ---@type table?
	if picker and picker.list then
		if guishader then
			guishader.removeRenderDlist(picker.list)
		end
		picker.list = glDeleteList(picker.list)
	end
end

function view.closePicker()
	local guishader = WG.guishader ---@type table?
	if view.picker then
		view.dropPickerList()
		if guishader then
			guishader.RemoveScreenRect("options_color")
		end
		view.picker = false
	end
end

-- the picker's color in its option's units, each channel on its step
function view.pickerValue(picker)
	local option, color = picker.option, picker.ui.color
	local white, step = option.white or option.max, option.step
	local value = {}
	for i = 1, 3 do
		local v = color[i] * white
		if step then
			v = math.floor(v / step + 0.5) * step
		end
		value[i] = math.max(0, math.min(option.max, v))
	end
	return value
end

-- Hands the picker's color to its option when that changed it. While a drag goes on the list is not
-- built again (the next frame draws the swatch anew); at its end it is.
function view.applyPicked(final)
	local picker = view.picker
	if not picker then
		return
	end
	local value = view.pickerValue(picker)
	if not view.sameColor(value, picker.option.value) then
		if final then
			applyOptionValue(picker.option, value)
		else
			sliderValueChanged = true
			applyOptionValue(picker.option, value, true)
			if lastSliderSound == nil or os_clock() - lastSliderSound > 0.04 then
				lastSliderSound = os_clock()
				view.sound("sliderDrag", 0.3)
			end
		end
	end
end

-- puts back the color the picker opened on
function view.revertPicked()
	local picker = view.picker
	if picker and not view.sameColor(picker.original, picker.option.value) then
		local original = picker.original
		picker.ui:setColor(picker.ui.previous)
		applyOptionValue(picker.option, { original[1], original[2], original[3] })
	end
end

-- the wheel over a bar: a step of its channel, or ten
function view.stepPickerChannel(channel, n)
	local picker = view.picker
	local option = picker.option
	local value = { option.value[1], option.value[2], option.value[3] }
	local step = option.step or option.max / 100
	value[channel] = math.max(0, math.min(option.max, math.floor((value[channel] + n * step) / step + 0.5) * step))
	if not view.sameColor(value, option.value) then
		local white = option.white or option.max
		picker.ui:setColor({ value[1] / white, value[2] / white, value[3] / white })
		applyOptionValue(option, value)
		view.sound("sliderDrag", 0.3)
	end
end

-- While the picker is open a press is its own: on it, it picks or puts back the color it opened on;
-- anywhere else, its own swatch too, it closes it. The release that follows does nothing else.
function view.pickerMouse(mx, my, release)
	local picker = view.picker
	if release then
		if not view.pickerHeld then
			return false
		end
		view.pickerHeld = false
		if picker and picker.ui.dragging then
			picker.ui:release()
			view.applyPicked(true)
		end
		return true
	end
	if not picker then
		return false
	end
	view.pickerHeld = true
	view.pressedInside = true
	local changed, part = picker.ui:press(mx, my)
	if part == "previous" then
		view.revertPicked()
	elseif changed then
		view.applyPicked()
	elseif part == nil then
		view.closePicker()
	end
	return true
end

-- The open color picker under its swatch, or above it where it would run off the screen, with each
-- channel's letter and value beside its bar. Like the dropdown it is drawn after guishader's blur,
-- and its display list is made again only when what it shows changed.
function draw.picker(mx, my)
	local picker = view.picker
	local row = layout.rowOf[picker.option]
	if not (row and row.control) then
		view.closePicker()
		return
	end
	local control, w, h = row.control, metrics.pickerW, metrics.pickerH
	local x1 = math.max(0, math.min(control[3] - w, vsx - w))
	local top = control[2] - metrics.selectPadding
	if top - h < 0 and vsy - control[4] > control[2] then
		top = control[4] + metrics.selectPadding + h
	end
	local ui, option = picker.ui, picker.option
	local guishader = WG.guishader ---@type table?
	ui:setRect(x1, top - h, x1 + w, top)
	local hovered = ui.dragging or ui:partAt(mx, my)
	local value, c = option.value, ui.color
	local sig = table.concat({
		x1,
		top,
		ui.h,
		ui.s,
		ui.v,
		c[1],
		c[2],
		c[3],
		value[1],
		value[2],
		value[3],
		tostring(hovered),
		guishader and 1 or 0,
	}, "|")
	if sig ~= picker.sig or not picker.list then
		picker.sig = sig
		view.dropPickerList()
		picker.list = glCreateList(function()
			ui:draw(hovered, guishader and look.selectBack[4] or look.selectBackSolid[4])
			font:Begin()
			font:SetOutlineColor(0, 0, 0, 0.4)
			for i, channel in ipairs(ui.parts.channels) do
				font:Print(look.caption .. channel.letter, channel.labelX, channel.y, metrics.controlFs, "ov")
				local shown = view.channelText(option, value[i])
				font:Print(look.value .. shown, channel.valueX, channel.y, metrics.controlFs, "rov")
			end
			font:End()
		end)
		if guishader then
			guishader.InsertScreenRect(x1, top - h, x1 + w, top, "options_color", widget)
			guishader.insertRenderDlist(picker.list)
		end
	end
	if not guishader then
		glCallList(picker.list)
	end
end

function widget:DrawScreen()
	-- doing it here so other widgets having higher layer number value are also loaded
	if not initialized then
		init()
		initialized = true
	else
		-- a slider moved
		if sliderValueChanged then
			view.refresh()
			sliderValueChanged = nil
		end

		if not openSelect and selectOptionsList then
			if WG.guishader then
				WG.guishader.RemoveScreenRect("options_select")
				WG.guishader.RemoveScreenRect("options_select_options")
				WG.guishader.removeRenderDlist(selectOptionsList)
			end
			selectOptionsList = glDeleteList(selectOptionsList)
			popup.sig = nil
		end

		if (show or showOnceMore) and windowList then
			local mx, my, ml = Spring.GetMouseState()
			if view.dragging then
				if ml then
					view.scrollFromY(my)
				else
					view.dragging = false
				end
			end
			if inRect(layout.window, mx, my) then
				Spring.SetMouseCursor("cursornormal")
			end

			glCallList(windowList)
			if WG.guishader and not backgroundGuishader then
				backgroundGuishader = glCreateList(function()
					local w = layout.window
					RectRound(w[1], w[2], w[3], w[4], elementCorner, 1, 1, 1, 1)
				end)
				WG.guishader.InsertDlist(backgroundGuishader, "options", nil, self)
			end
			showOnceMore = false

			searchBox:draw()
			font:Begin()
			font:SetOutlineColor(0, 0, 0, 0.4)
			draw.header(mx, my)
			draw.scrollbar(mx, my)
			draw.strip(draw.hover(mx, my, ml), mx, my)
			font:End()
			if openSelect ~= nil then
				draw.selectPopup(mx, my)
			elseif prevSelectHover ~= nil then
				prevSelectHover = nil
			end
			if view.picker then
				draw.picker(mx, my)
			end
			glColor(1, 1, 1, 1)
		elseif WG.guishader and backgroundGuishader then
			WG.guishader.RemoveDlist("options")
			backgroundGuishader = glDeleteList(backgroundGuishader)
		end
		if checkedWidgetDataChanges == nil then
			checkedWidgetDataChanges = true
			loadAllWidgetData()
		end
	end
end

function saveOptionValue(widgetName, widgetApiName, widgetApiFunction, configVar, configValue, widgetApiFunctionParam)
	-- if widgetApiFunctionParam not defined then it uses configValue
	if widgetHandler.configData[widgetName] == nil then
		widgetHandler.configData[widgetName] = {}
	end
	if widgetHandler.configData[widgetName][configVar[1]] == nil then
		widgetHandler.configData[widgetName][configVar[1]] = {}
	end
	if configVar[2] ~= nil and widgetHandler.configData[widgetName][configVar[1]][configVar[2]] == nil then
		widgetHandler.configData[widgetName][configVar[1]][configVar[2]] = {}
	end
	if configVar[2] ~= nil then
		if configVar[3] ~= nil then
			widgetHandler.configData[widgetName][configVar[1]][configVar[2]][configVar[3]] = configValue
		else
			widgetHandler.configData[widgetName][configVar[1]][configVar[2]] = configValue
		end
	else
		widgetHandler.configData[widgetName][configVar[1]] = configValue
	end
	if widgetApiName ~= nil and WG[widgetApiName] ~= nil and WG[widgetApiName][widgetApiFunction] ~= nil then
		if widgetApiFunctionParam ~= nil then
			WG[widgetApiName][widgetApiFunction](widgetApiFunctionParam)
		else
			WG[widgetApiName][widgetApiFunction](configValue)
		end
	end
end

function widget:KeyRelease()
	-- Since we grab the keyboard, we need to specify a KeyRelease to make sure other release actions can be triggered
	return false
end

-- ESC closes the open dropdown or color picker first (the picker puts back the color it opened on,
-- where Enter keeps the new one), then clears the search, then closes the window. The arrow keys,
-- Enter, Tab, Home and End work the rows (view.moveSelection and the ones after it), the arrows and
-- Enter an open dropdown too; while the search field is typed in, it keeps left, right, Enter, Home
-- and End. Every other key goes to the search field, and none reach the game while the window is open.
function widget:KeyPress(key, mods)
	if not show then
		return false
	end
	if view.picker and (key == 27 or key == 13 or key == 271) then
		if key == 27 then
			view.revertPicked()
		end
		view.closePicker()
		return true
	end
	if key == 27 then
		if openSelect then
			openSelect = nil
		elseif searchBox:getText() ~= "" then
			searchBox:setText("")
			searchBox:blur()
		else
			view.close()
		end
		return true
	end

	if key >= 282 and key <= 293 then -- Function keys
		return false
	end

	if key == 280 then -- PGUP
		view.scrollBy(-view.pageLines(true))
		return true
	elseif key == 281 then -- PGDN
		view.scrollBy(view.pageLines())
		return true
	end

	local enter = key == 13 or key == 271
	if openSelect then
		if key == 273 or key == 274 then -- up, down: the entry before or after, kept among those shown
			local k = (view.selectKey or tonumber(openSelect.value) or 0) + (key == 274 and 1 or -1)
			view.selectKey = math.max(1, math.min(#openSelect.options, k))
			selectScrollOffset = math.max(view.selectKey - 16, math.min(view.selectKey - 1, selectScrollOffset or 0))
			return true
		elseif enter then
			if view.selectKey then
				applyOptionValue(openSelect, view.selectKey)
				view.sound("selectClick", 0.5)
			end
			openSelect = nil
			return true
		end
	end
	if key == 273 or key == 274 then -- up, down
		view.moveSelection(key == 274 and 1 or -1)
		return true
	end
	if not searchBox:isFocused() then
		if key == 275 or key == 276 then -- right, left
			view.adjustSelected(key == 275 and 1 or -1, mods and mods.ctrl)
			return true
		elseif enter then
			view.activateSelected()
			return true
		elseif key == 9 and not view.searching() then -- tab, back with shift
			view.cycleTab(mods and mods.shift and -1 or 1)
			return true
		elseif key == 278 or key == 279 then -- home, end
			local items = view.selectable()
			if #items > 0 then
				local item = items[key == 278 and 1 or #items]
				view.select(item.option, item.line)
			end
			return true
		end
	end

	-- editing keys work on a search kept from before without clicking into it first
	if searchBox:getText() ~= "" then
		searchBox:focus()
	end
	searchBox:keyPress(key)
	return true
end

function NearestValue(table, number)
	local smallestSoFar, smallestIndex
	for i, y in ipairs(table) do
		if not smallestSoFar or (math.abs(number - y) < smallestSoFar) then
			smallestSoFar = math.abs(number - y)
			smallestIndex = i
		end
	end
	return table[smallestIndex]
end

-- the value a slider takes with the mouse at mx, clamped and snapped to its step
local function sliderValueAt(option, mx)
	local row = layout.rowOf[option]
	if not (row and row.track) then
		return option.value
	end
	local track = row.track
	local min, max = sliderRange(option)
	local value
	local fine = view.fineDrag
	if fine and fine.option == option then
		-- dragged with shift held: a fifth of the speed, from where the drag started
		value = fine.value + (max - min) * 0.2 * (mx - fine.x) / (track[2] - track[1])
	else
		value = min + (max - min) * (mx - track[1]) / (track[2] - track[1])
	end
	if value < min then
		value = min
	end
	if value > max then
		value = max
	end
	if option.steps ~= nil then
		value = NearestValue(option.steps, value)
	elseif option.step ~= nil then
		value = math.floor((value + (option.step / 2)) / option.step) * option.step
	end
	return value
end

-- scrolls so the thumb's top sits where the cursor has dragged it
function view.scrollFromY(y)
	local _, _, trackTop, travel = view.thumb()
	if not travel or travel <= 0 then
		return
	end
	local f = math.max(0, math.min(1, (trackTop - (y - view.dragGrab)) / travel))
	view.scrollBy(math.floor(f * view.maxScroll() + 0.5) - view.scroll)
end

-- Takes hold of the bar: on the thumb that is a grab and the list stays put, on the track the
-- thumb jumps to the cursor first and is dragged from its middle.
function view.grabScroller(y)
	local top, height = view.thumb()
	if not top then
		return
	end
	view.dragging = true
	if y <= top and y >= top - height then
		view.dragGrab = y - top
	else
		view.dragGrab = -math.floor(height * 0.5)
		view.scrollFromY(y)
	end
end

-- each tab keeps where its list was left
function view.openTab(group)
	view.scrollOf[currentGroupTab] = view.scroll
	currentGroupTab = group.id
	openSelect = nil
	view.closePicker()
	selectClickAllowHide = nil
	view.litPin = false
	view.selected, view.stripOption = false, false
	view.scroll = view.scrollOf[group.id] or 0
	view.build()
	view.refresh()
end

-- opens the tab an option is on, unfolds its family and scrolls its row into view
function view.reveal(option)
	if searchBox and searchBox:getText() ~= "" then
		searchBox:setText("")
	end
	view.litPin = false
	if option.group ~= currentGroupTab then
		view.scrollOf[currentGroupTab] = view.scroll
		currentGroupTab = option.group
	end
	local parent = option.parentOption
	while parent do
		if parent.id and view.isFolded(parent) then
			view.folded[parent.id] = false
		end
		parent = parent.parentOption
	end
	view.build()
	for i, line in ipairs(view.lines) do
		local found = line.option == option
		for _, cell in ipairs(line.cells or {}) do
			found = found or cell == option
		end
		if found then
			view.setScroll(i - 3)
			break
		end
	end
	view.refresh()
end

-- The wheel scrolls the open dropdown, steps a channel over the color picker's bars (ten steps with
-- ctrl), or else scrolls the list: three lines, nine with ctrl, a page with shift. Nothing gets past
-- the window while it is open.
function widget:MouseWheel(up, value)
	if not show then
		return
	end
	local mx, my = Spring.GetMouseState()
	-- on the color picker the list stays put
	local part = view.picker and view.picker.ui:partAt(mx, my)
	if type(part) == "number" then
		local _, ctrl = Spring.GetModKeyState()
		view.stepPickerChannel(part, (up and 1 or -1) * (ctrl and 10 or 1))
	end
	if openSelect ~= nil then
		local numItems = 0
		for _ in pairs(openSelect.options) do
			numItems = numItems + 1
		end
		local maxVisible = math.min(numItems, 16)
		if up then
			selectScrollOffset = math.max(0, (selectScrollOffset or 0) - 1)
		else
			selectScrollOffset = math.min(numItems - maxVisible, (selectScrollOffset or 0) + 1)
		end
		return true
	end
	if not part and inRect(layout.window, mx, my) then
		local _, ctrl, _, shift = Spring.GetModKeyState()
		-- over the selected slider the wheel steps it (ten steps with ctrl); not over others, which a
		-- list scrolled past would change
		local row = view.selected and layout.rowOf[view.selected]
		if
			row
			and row.track
			and math_isInRect(mx, my, row.track[1] - row.knob, row.hover[2], row.track[2] + row.knob, row.hover[4])
		then
			view.stepSlider(view.selected, (up and 1 or -1) * (ctrl and 10 or 1))
			return true
		end
		local step = ctrl and metrics.wheelRows * 3 or metrics.wheelRows
		if shift then
			step = view.pageLines(up)
		end
		view.scrollBy(up and -step or step)
	end
	return true
end

function widget:MouseMove(mx, my)
	if view.picker and view.picker.ui:drag(mx, my) then
		view.applyPicked()
	end
	if draggingSlider ~= nil then
		local newValue = sliderValueAt(draggingSlider, mx)
		if draggingSlider.value ~= newValue then
			sliderValueChanged = true
			applyOptionValue(draggingSlider, newValue, true) -- the window is drawn again next frame
			if playSounds and (lastSliderSound == nil or os_clock() - lastSliderSound > 0.04) then
				lastSliderSound = os_clock()
				Spring.PlaySoundFile(sounds.sliderDrag, 0.4, "ui")
			end
		end
	end
end

function widget:MousePress(x, y, button)
	return mouseEvent(x, y, button, false)
end

function widget:MouseRelease(x, y, button)
	return mouseEvent(x, y, button, true)
end

-- a release on a row: fold or unfold a family, flip a toggle, or run the row's click action
local function releaseOnRows(mx, my)
	for _, row in ipairs(layout.rows) do
		local o, option = row.control, row.option
		if row.fold and inRect(row.fold, mx, my) then
			view.folded[option.id] = not view.isFolded(option)
			view.build()
			if playSounds then
				Spring.PlaySoundFile(sounds.buttonClick, 0.5, "ui")
			end
			return
		elseif o then
			if option.type == "bool" and inRect(o, mx, my) then
				applyOptionValue(option, not option.value)
				if playSounds then
					if option.value then
						Spring.PlaySoundFile(sounds.toggleOnClick, 0.75, "ui")
					else
						Spring.PlaySoundFile(sounds.toggleOffClick, 0.75, "ui")
					end
				end
				return
			elseif
				(option.type == "slider" or option.type == "select" or option.type == "color") and inRect(o, mx, my)
			then
				-- handled on press
				return
			elseif option.onclick ~= nil and inRect(row.hover, mx, my) then
				option.onclick(option)
				return
			end
		end
	end
end

-- A press on a row selects it, and grabs a slider anywhere along its track (with shift held, where
-- the knob is, to drag it finely) or opens a dropdown or a color picker.
local function pressOnRows(mx, my)
	for _, row in ipairs(layout.rows) do
		if inRect(row.hover, mx, my) then
			view.selected, view.stripOption = row.option, row.option
		end
	end
	for _, row in ipairs(layout.rows) do
		local o, option = row.control, row.option
		if o and option.type == "slider" and row.track then
			local h = row.hover
			if math_isInRect(mx, my, row.track[1] - row.knob, h[2], row.track[2] + row.knob, h[4]) then
				draggingSlider = option
				local _, _, _, shift = Spring.GetModKeyState()
				view.fineDrag = shift and { option = option, x = mx, value = option.value } or false
				local newValue = sliderValueAt(option, mx)
				if option.value ~= newValue then
					sliderValueChanged = true
					applyOptionValue(option, newValue, true)
					if playSounds then
						Spring.PlaySoundFile(sounds.sliderDrag, 0.3, "ui")
					end
				end
				return
			end
		elseif o and option.type == "select" and inRect(o, mx, my) then
			if playSounds then
				Spring.PlaySoundFile(sounds.selectUnfoldClick, 0.6, "ui")
			end
			openSelect = option
			selectScrollOffset = 0
			view.selectKey = false
			return
		elseif o and option.type == "color" and inRect(o, mx, my) then
			view.openPicker(option)
			return
		end
	end
end

-- a press on a header switch: unfold all, or advanced (the developer UI's while that is on)
local function pressOnHeader(mx, my)
	if inRect(layout.unfoldSwitchHit, mx, my) then
		-- every family follows the switch, so what was folded or opened by hand is let go
		view.unfoldAll = not view.unfoldAll
		view.folded = {}
		view.build()
		view.refresh()
	elseif not devMode and inRect(layout.switchHit, mx, my) then
		if devUI then
			-- the way its own row turns it off: reloads the UI
			applyOptionValueByID("devmode", false)
		else
			advSettings = not advSettings
			view.build()
			view.refresh()
		end
	else
		return false
	end
	if playSounds then
		Spring.PlaySoundFile(sounds.buttonClick, 0.6, "ui")
	end
	return true
end

-- a press in the column: open a tab, or scroll to a section (or a tab's search results)
local function pressOnSidebar(mx, my)
	for _, entry in ipairs(layout.sidebar) do
		if inRect(entry.rect, mx, my) then
			if entry.group and not view.searching() then
				if entry.group.id == currentGroupTab then
					view.scrollBy(-view.scroll)
					view.litPin = false
					view.refresh()
				else
					view.openTab(entry.group)
				end
			elseif entry.line then
				view.scrollBy(entry.line - 1 - view.scroll)
				local line = view.lines[entry.line]
				view.litPin = line and (line.option or line.group) or false
				view.refresh()
			end
			if playSounds then
				Spring.PlaySoundFile(sounds.paginatorClick, 0.9, "ui")
			end
			return true
		end
	end
end

-- A press in the window goes to the search field, a header switch, the column, the scrollbar or a
-- row; a release outside closes the window, unless it ends something that started inside.
function mouseEvent(mx, my, button, release)
	if Spring.IsGUIHidden() then
		return false
	end
	if not show then
		return
	end

	-- A press on a top bar button is the top bar's to handle: it closes the open windows
	-- and opens the one that was clicked. Closing (and consuming) here would swallow it.
	if WG.topbar and WG.topbar.buttonAt and WG.topbar.buttonAt(mx, my) then
		return false
	end

	local inWindow = inRect(layout.window, mx, my)
	local pressedInside = view.pressedInside
	if release then
		view.pressedInside = nil
	end

	if button == 1 and view.pickerMouse(mx, my, release) then
		return true
	end

	if button == 1 then
		if release then
			if view.dragging then
				view.dragging = false
				return true
			end

			-- apply new slider value
			if draggingSlider ~= nil then
				applyOptionValue(draggingSlider, sliderValueAt(draggingSlider, mx))
				draggingSlider = nil
				view.fineDrag = false
				return true
			end

			-- select option
			if openSelect ~= nil then
				for _, item in ipairs(layout.selectItems) do
					if inRect(item, mx, my) then
						applyOptionValue(openSelect, item[5])
						if playSounds then
							Spring.PlaySoundFile(sounds.selectClick, 0.5, "ui")
						end
					end
				end
				local row = layout.rowOf[openSelect]
				if selectClickAllowHide ~= nil or not (row and inRect(row.control, mx, my)) then
					openSelect = nil
					selectClickAllowHide = nil
				else
					selectClickAllowHide = true
				end
				return true
			end

			if inWindow then
				releaseOnRows(mx, my)
				view.refresh()
			end
		elseif inWindow and not openSelect then
			view.pressedInside = true
			if searchBox:mousePress(mx, my) then
				return true
			end
			if not pressOnHeader(mx, my) and not pressOnSidebar(mx, my) then
				if mx >= layout.barX1 and my >= layout.listBottom and my <= layout.listTop then
					view.grabScroller(my)
				elseif layout.stripCommand and inRect(layout.stripCommand, mx, my) then
					-- the /option command in the strip, to paste in the chat or a key bind
					Spring.SetClipboard(layout.stripCommand[5])
					view.copiedAt = os_clock()
				else
					pressOnRows(mx, my)
				end
			end
		end
	elseif inWindow and not release then
		view.pressedInside = true
	end

	if inWindow then
		return true
	end
	if release and not pressedInside and draggingSlider == nil then
		showOnceMore = true -- show once more because the guishader lags behind, though this will not fully fix it
		view.close()
	end
	return true
end

function GetWidgetToggleValue(widgetname)
	if widgetHandler.orderList[widgetname] == nil or widgetHandler.orderList[widgetname] == 0 then
		return false
	elseif
		widgetHandler.orderList[widgetname] >= 1
		and widgetHandler.knownWidgets ~= nil
		and widgetHandler.knownWidgets[widgetname] ~= nil
	then
		if widgetHandler.knownWidgets[widgetname].active then
			return true
		else
			return 0.5
		end
	end
end

-- the value at a path in a widget's saved config data, e.g. {'Config','console','maxlines'}; nil when it is missing
local function widgetConfigValue(widgetName, path)
	local value = widgetHandler.configData[widgetName]
	for _, key in ipairs(path) do
		if type(value) ~= "table" then
			return nil
		end
		value = value[key]
	end
	return value
end

-- the option keeps its value when the path is missing
function loadWidgetData(widgetName, optionId, configVar)
	local option = getOption(optionId)
	local value = widgetConfigValue(widgetName, configVar)
	if option and value ~= nil then
		option.value = value
	end
end

-- Most options only mirror one value, and declare where it lives instead of handling it:
--   widgetConfig = { widget name, config key or path, api = WG table, get = getter, set = setter, key = ... }
--     read from the API when the list is built, loaded from the widget's saved config, and on
--     change saved there and handed to the setter; with key, the getter gets key and the setter { key, value }
--   configInt / configFloat = engine config key; a toggle stores 1 or 0, a color has a key per channel
local function boundPath(config)
	return type(config[2]) == "table" and config[2] or { config[2] }
end

local function readBoundValue(option)
	local config = option.widgetConfig
	if config then
		local api = config.api and WG[config.api]
		if config.get and api and api[config.get] then
			local value = api[config.get](config.key)
			if value ~= nil then
				option.value = value
			end
		end
	elseif option.configInt then
		if option.type == "bool" then
			option.value = Spring.GetConfigInt(option.configInt, option.value and 1 or 0) == 1
		elseif option.type == "color" then
			-- a new table only when it changed, so a read that finds the same color changes nothing
			local value = {}
			for i, key in ipairs(option.configInt) do
				value[i] = Spring.GetConfigInt(key, option.value[i])
			end
			if not view.sameColor(value, option.value) then
				option.value = value
			end
		else
			option.value = Spring.GetConfigInt(option.configInt, option.value)
		end
	elseif option.configFloat then
		option.value = Spring.GetConfigFloat(option.configFloat, option.value)
	end
end

local function loadBoundValue(option)
	local config = option.widgetConfig
	local value = widgetConfigValue(config[1], boundPath(config))
	if value ~= nil then
		option.value = value
	end
end

-- Reads the bound settings again, as their widget or the engine config can change them by other means
-- while the window is open; not the one being dragged or picked from. Returns whether any changed.
function view.rereadBound()
	local changed = false --[[@as boolean]]
	local picking = view.picker and view.picker.option
	for _, option in ipairs(unfilteredOptions) do
		if
			(option.widgetConfig or option.configInt or option.configFloat)
			and option ~= draggingSlider
			and option ~= openSelect
			and option ~= picking
		then
			local before = option.value
			readBoundValue(option)
			changed = changed or option.value ~= before
		end
	end
	return changed
end

local function saveBoundValue(option)
	local config = option.widgetConfig
	if config then
		local param = config.key and { config.key, option.value } or nil
		saveOptionValue(config[1], config.api, config.set, boundPath(config), option.value, param)
	elseif option.configInt and option.type == "color" then
		for i, key in ipairs(option.configInt) do
			Spring.SetConfigInt(key, option.value[i])
		end
	elseif option.configInt then
		Spring.SetConfigInt(option.configInt, option.type == "bool" and (option.value and 1 or 0) or option.value)
	elseif option.configFloat then
		Spring.SetConfigFloat(option.configFloat, option.value)
	end
end

-- dev mode, once: a binding to a widget the handler does not know, or to an API its running widget lacks
local bindingsChecked = false
local function checkBindings()
	bindingsChecked = true
	for _, option in ipairs(options) do
		local config = option.widgetConfig
		local known = config and widgetHandler.knownWidgets[config[1]]
		local api = config and config.api and WG[config.api]
		local problem
		if config and not known then
			problem = "unknown widget " .. config[1]
		elseif config and known.active and config.api then
			if not api then
				problem = "WG." .. config.api .. " missing"
			elseif config.get and not api[config.get] then
				problem = "WG." .. config.api .. "." .. config.get .. " missing"
			elseif config.set and not api[config.set] then
				problem = "WG." .. config.api .. "." .. config.set .. " missing"
			end
		end
		if problem then
			Spring.Echo("Options: '" .. option.id .. "' widgetConfig: " .. problem)
		end
	end
end

function checkRequireRestart()
	changesRequireRestart = false
	for id, value in pairs(requireRestartDefaults) do
		local option = getOption(id)
		if option and option.value ~= value then
			changesRequireRestart = true
		end
	end
end

function applyOptionValueByID(id, newValue, skipRedrawWindow, force)
	applyOptionValue(getOption(id), newValue, skipRedrawWindow, force)
end

function applyOptionValue(option, newValue, skipRedrawWindow, force)
	if option == nil then
		return
	end

	local id = option.id

	if newValue ~= nil then
		option.value = newValue
	end

	if option.restart and requireRestartDefaults[id] ~= nil then
		checkRequireRestart()
	end

	if id ~= "preset" and presets.lowest[id] ~= nil and manualChange then
		local preset = getOption("preset")
		if preset then
			preset.value = #preset.options -- custom
			Spring.SetConfigString("graphicsPreset", "custom")
		end
	end

	-- a toggle turns its widget on and off; other options only name the widget they belong to
	if option.widget ~= nil and option.type == "bool" and widgetHandler.orderList[option.widget] ~= nil then
		if option.value then
			if widgetHandler.orderList[option.widget] < 0.5 then
				widgetHandler:EnableWidget(option.widget)
			end
		else
			if widgetHandler.orderList[option.widget] > 0 then
				widgetHandler:DisableWidget(option.widget)
			end
		end
		forceUpdate = true
		scheduleInit = true
		if id == "teamcolors" then
			Spring.SendCommands("luarules reloadluaui") -- cause several widgets are still using old colors
		end
	end

	saveBoundValue(option)
	if option.onchange then
		option.onchange(option, option.value, force)
	end

	if skipRedrawWindow == nil then
		-- also keeps the search results up to date
		applyFilter()
	end
end

-- loads values via stored game config in luaui/configs
function loadAllWidgetData()
	for _, option in ipairs(options) do
		if option.widgetConfig then
			loadBoundValue(option)
		end
		if option.onload then
			option.onload(option)
		end
	end
end

-- Ranks the options against the search text: exact substring > multi-word AND > fuzzy subsequence.
-- A match is shown below its parents, and the rows of one family stay together, ranked by their
-- best match.
function applyFilter()
	if inputText ~= "" then
		local query = Search.query(inputText)
		-- Nothing but whitespace is not something anyone is searching for.
		if query.empty then
			options = unfilteredOptions
			view.build()
			view.refresh()
			return
		end

		local matched = {}
		-- Filled once and rewritten per option rather than allocated for each of them: a
		-- keystroke walks every setting there is.
		local primary, secondary = { "", "" }, { "", "" }

		for i, option in ipairs(unfilteredOptions) do
			if option.name and option.name ~= "" and option.type then
				local lowerId = string.lower(option.id)
				local lowerDesc = option.description and option.description ~= "" and string.lower(option.description)
					or ""

				-- Named by what it is called and by its id; found, but not on their own, by its
				-- description and again its id.
				primary[1], primary[2] = Search.normalize(getOptionLabel(option)), lowerId
				secondary[1], secondary[2] = lowerDesc, lowerId
				local score = Search.score(query, primary, secondary)
				if score > 0 then
					matched[#matched + 1] = { option = option, score = score, index = i }
				end
			end
		end

		table.sortStable(matched, function(a, b)
			if a.score ~= b.score then
				return a.score > b.score
			end
		end)

		local families, familyOf = {}, {}
		for _, entry in ipairs(matched) do
			local root = entry.option
			while root.parentOption do
				root = root.parentOption
			end
			local family = familyOf[root]
			if not family then
				family = {}
				familyOf[root] = family
				families[#families + 1] = family
			end
			family[#family + 1] = entry
		end

		local shown = {}
		local result = {}
		local function show(option)
			if not shown[option] then
				shown[option] = true
				if option.parentOption then
					show(option.parentOption)
				end
				result[#result + 1] = option
				if option.spacer then
					result[#result + 1] = option.spacer
				end
			end
		end
		for _, family in ipairs(families) do
			table.sort(family, function(a, b)
				return a.index < b.index
			end)
			for _, entry in ipairs(family) do
				show(entry.option)
			end
		end

		options = result
	else
		-- No filter, use the cached unfiltered options
		options = unfilteredOptions
	end
	view.build()
	view.refresh()
end

-- Lookups for the squad selects that merge several widget settings into select inputs.
squadSelectValue = {}

function squadSelectValue.get(getterName)
	local api = WG["squadselection"]
	if api == nil or api[getterName] == nil then
		return nil
	end
	return api[getterName]()
end

function squadSelectValue.hullDisplayMode()
	if squadSelectValue.get("getVisualizationMode") ~= "convexHull" then
		return 1
	end
	if squadSelectValue.get("getShowReserveSquads") then
		return 2
	end
	return 3
end

function squadSelectValue.squadColorMode()
	local mode = squadSelectValue.get("getSquadColorMode")
	if mode == "custom" then
		return 2
	end
	if mode == "squad" then
		return 3
	end
	return 1
end

function squadSelectValue.squadCreateMethod()
	if squadSelectValue.get("getRightClickSquadCreate") then
		return 2
	end
	if squadSelectValue.get("getCtrlRightClickCreatesSquad") then
		return 3
	end
	if squadSelectValue.get("getCtrlRightClickDragCreatesSquad") then
		return 4
	end
	return 1
end

-- the custom squad color, from the widget's three channels
function squadSelectValue.customColor()
	local color = { 0, 0.3, 0.7 }
	for i, channel in ipairs({ "R", "G", "B" }) do
		local value = squadSelectValue.get("getSquadCustomColor" .. channel)
		if type(value) == "number" then
			color[i] = value
		end
	end
	return color
end

function squadSelectValue.rightClickMoveControlsReserves()
	if squadSelectValue.get("getRightClickMoveControlsReserves") then
		return 2
	end
	return 1
end

-------------------------------------------------------------------------------
-- Squad selection presets
--
-- The Squad Selection widget supports several playstyles, and each one wants a different set of its switches. Rather than show every switch to everyone, the panel offers a playstyle preset: picking one writes the settings that preset owns and hides their rows. Custom owns nothing and shows the full list.

squadPreset = {
	-- The playstyle definitions, shared with the widget.
	definitions = VFS.Include("luaui/Include/squad_selection_presets.lua"),

	-- Rows for settings a preset owns; hidden unless the preset is Custom.
	ownedOptions = {
		"squad_cyclingToNextSquad",
		"squad_leftClickAlternativeSelection",
		"squad_squadCreateMethod",
		"squad_rightClickMoveControlsReserves",
		"squad_mergeIntoReserves",
	},

	allOptions = {
		"squad_cyclingToNextSquad",
		"squad_leftClickSelectsSquad",
		"squad_leftClickAlternativeSelection",
		"squad_squadCreateMethod",
		"squad_rightClickMovesSquad",
		"squad_rightClickMoveControlsReserves",
		"squad_mergeIntoReserves",
		"squad_mruSize",
		"squad_excludeConstructors",
		"squad_excludeResurrectionUnits",
		"squad_excludeCombatEngineers",
		"label_squad_hulls",
		"squad_hullDisplayMode",
		"squad_convexHullPadding",
		"squad_convexHullArcResolution",
		"squad_convexHullFillOpacity",
		"squad_convexHullBorderOpacity",
		"squad_convexHullBorderThickness",
		"squad_convexHullColorMode",
		"squad_convexHullCustomColor",
	},

	-- Rows that only make sense while the hull widget itself is running.
	hullOptions = {
		"squad_convexHullPadding",
		"squad_convexHullArcResolution",
		"squad_convexHullFillOpacity",
		"squad_convexHullBorderOpacity",
		"squad_convexHullBorderThickness",
		"squad_convexHullColorMode",
		"squad_convexHullCustomColor",
	},
}
-- Index-aligned with the squad_preset select's option labels. 'off' is not a preset but the widget being disabled, so it leads the shared list.
squadPreset.names = { "off" }
for _, name in ipairs(squadPreset.definitions.names) do
	squadPreset.names[#squadPreset.names + 1] = name
end
squadPreset.index = table.invert(squadPreset.names)

-- The widget is unloaded while the preset is Off
function squadPreset.get()
	if not GetWidgetToggleValue("Squad Selection") then
		return "off"
	end
	local preset = squadSelectValue.get("getPreset")
	if preset ~= nil then
		return preset
	end
	local data = widgetHandler.configData["Squad Selection"]
	return (data and data.preset) or "custom"
end

function squadPreset.apply(name)
	if name == "off" then
		if GetWidgetToggleValue("Squad Selection Hull") then
			widgetHandler:DisableWidget("Squad Selection Hull")
		end
		if GetWidgetToggleValue("Squad Selection") then
			widgetHandler:DisableWidget("Squad Selection")
		end
		scheduleInit = true
		return
	end

	-- The two widgets are a pair: the hull widget only draws state the main one owns, so a preset enables and disables both.
	if not GetWidgetToggleValue("Squad Selection") then
		widgetHandler:EnableWidget("Squad Selection")
	end
	if not GetWidgetToggleValue("Squad Selection Hull") then
		widgetHandler:EnableWidget("Squad Selection Hull")
	end

	for key, value in pairs(squadPreset.definitions.values[name] or {}) do
		saveOptionValue(
			"Squad Selection",
			"squadselection",
			"set" .. key:sub(1, 1):upper() .. key:sub(2),
			{ key },
			value
		)
	end
	saveOptionValue("Squad Selection", nil, nil, { "preset" }, name)

	local api = WG["squadselection"]
	if api ~= nil and api.applyPreset ~= nil then
		api.applyPreset(name)
	end

	scheduleInit = true
end

local soundDevices, soundDevicesByName

function init()
	presets = {
		lowest = {
			bloomdeferred = false,
			bloomdeferred_quality = 1,
			ssao = false,
			ssao_quality = 1,
			mapedgeextension = false,
			lighteffects = false,
			lighteffects_additionalflashes = false,
			lighteffects_screenspaceshadows = 0,
			lighteffects_nanoparticlelights = false,
			distortioneffects = false,
			snow = false,
			particles = 10000,
			guishader = false,
			decalsgl4 = false,
			decals = false,
			shadowslider = 1,
			grass = false,
			losrange = false,
			attackrange_numrangesmult = 0.3,
			cusgl4 = false,
			water = 1,
			advmapshading = false,
		},
		low = {
			bloomdeferred = true,
			bloomdeferred_quality = 1,
			ssao = false,
			ssao_quality = 1,
			mapedgeextension = false,
			lighteffects = true,
			lighteffects_additionalflashes = false,
			lighteffects_screenspaceshadows = 1,
			lighteffects_nanoparticlelights = false,
			distortioneffects = true,
			snow = false,
			particles = 15000,
			guishader = false,
			decalsgl4 = true,
			decals = true,
			shadowslider = 3,
			grass = false,
			losrange = false,
			attackrange_numrangesmult = 0.5,
			cusgl4 = true,
			water = 2,
			advmapshading = true,
		},
		medium = {
			bloomdeferred = true,
			bloomdeferred_quality = 1,
			ssao = true,
			ssao_quality = 2,
			mapedgeextension = true,
			lighteffects = true,
			lighteffects_additionalflashes = true,
			lighteffects_screenspaceshadows = 2,
			lighteffects_nanoparticlelights = true,
			distortioneffects = true,
			snow = true,
			particles = 20000,
			decalsgl4 = true,
			decals = true,
			shadowslider = 4,
			grass = true,
			losrange = true,
			attackrange_numrangesmult = 0.7,
			cusgl4 = true,
			water = 2,
			advmapshading = true,
		},
		high = {
			bloomdeferred = true,
			bloomdeferred_quality = 2,
			ssao = true,
			ssao_quality = 2,
			mapedgeextension = true,
			lighteffects = true,
			lighteffects_additionalflashes = true,
			lighteffects_screenspaceshadows = 3,
			lighteffects_nanoparticlelights = true,
			distortioneffects = true,
			snow = true,
			particles = 30000,
			decalsgl4 = true,
			decals = true,
			shadowslider = 5,
			grass = true,
			losrange = true,
			attackrange_numrangesmult = 0.9,
			cusgl4 = true,
			water = 2,
			advmapshading = true,
		},
		ultra = {
			bloomdeferred = true,
			bloomdeferred_quality = 3,
			ssao = true,
			ssao_quality = 3,
			mapedgeextension = true,
			lighteffects = true,
			lighteffects_additionalflashes = true,
			lighteffects_screenspaceshadows = 4,
			lighteffects_nanoparticlelights = true,
			distortioneffects = true,
			snow = true,
			particles = 40000,
			decalsgl4 = true,
			decals = true,
			shadowslider = 6,
			grass = true,
			losrange = true,
			attackrange_numrangesmult = 1,
			cusgl4 = true,
			water = 2,
			advmapshading = true,
		},
		custom = {},
	}

	local screenModes = WG.screenMode and WG.screenMode.GetScreenModes() or {}
	local displays = WG.screenMode and WG.screenMode.GetDisplays() or {}

	local currentDisplay = 1
	local v_sx, v_sy, v_px, v_py = Spring.GetViewGeometry()
	local displayNames = {}
	for index, display in ipairs(displays) do
		if display.width > 0 then
			displayNames[index] = index
				.. ":  "
				.. display.name
				.. " "
				.. display.width
				.. " × "
				.. display.height
				.. "  ("
				.. display.hz
				.. "hz)"
			if
				v_px >= display.x
				and v_px < display.x + display.width
				and v_py >= display.y
				and v_py < display.y + display.height
			then
				currentDisplay = index
			end
		elseif devMode or devUI then -- advSettings
			displayNames[index] = display.name
		end
	end
	local selectedDisplay = currentDisplay

	local resolutionNames = {}
	local screenmodeOffset = 0
	for _, screenMode in ipairs(screenModes) do
		if screenMode.display == currentDisplay then
			resolutionNames[#resolutionNames + 1] = screenMode.name
		elseif #resolutionNames == 0 then
			screenmodeOffset = screenmodeOffset + 1
		end
	end

	-- The entry the window is in now, if one is: fullscreen or borderless (the switcher's mode types 1 and
	-- 2), or the windowed mode of its size, borders included as the switcher sets it.
	local function currentResolution()
		local fullscreen = Spring.GetConfigInt("Fullscreen", 0) == 1
		local borderless = Spring.GetConfigInt("WindowBorderless", 0) == 1
		local w, h, _, _, top, left, bottom, right = Spring.GetWindowGeometry()
		for i = 1, #resolutionNames do
			local mode = screenModes[i + screenmodeOffset]
			if not mode then
				break
			elseif fullscreen and mode.type == (borderless and 2 or 1) then
				return i
			elseif
				not fullscreen
				and not borderless
				and mode.type == 3
				and mode.width == w + left + right
				and mode.height == h + top + bottom
			then
				return i
			end
		end
	end

	-- only allow dualscreen-mode on single displays when super ultrawide screen or Multi Display option shows
	local dualScreen = not (
		(#displayNames <= 1 and vsx / vsy < 2.5) or (#displayNames > 1 and #displayNames == Spring.GetNumDisplays())
	)
	if not dualScreen and Spring.GetConfigInt("DualScreenMode", 0) ~= 0 then
		Spring.SetConfigInt("DualScreenMode", 0)
	end

	-- the start of infolog.txt, which this reads, does not change while the game runs
	if not soundDevices then
		soundDevices = { "default" }
		soundDevicesByName = { [""] = 1 }
		-- SDL plays the sound by default and only opens its own names, which older engines list with OpenAL's prefix
		local sdlAudio = Spring.GetConfigInt("UseSDLAudio", 1) ~= 0
		for _, device in ipairs(Spring.GetSoundDevices()) do
			local name = sdlAudio and device.name:gsub("^OpenAL Soft on ", "") or device.name
			if not soundDevicesByName[name] then
				soundDevices[#soundDevices + 1] = name
				soundDevicesByName[name] = #soundDevices
			end
		end
		-- a device saved with that prefix still shows as selected
		local savedDevice = Spring.GetConfigString("snd_device", "") or ""
		soundDevicesByName[savedDevice] = soundDevicesByName[savedDevice]
			or soundDevicesByName[(savedDevice:gsub("^OpenAL Soft on ", ""))]
		local infolog = VFS.LoadFile("infolog.txt")
		if infolog then
			local fileLines = string.lines(infolog)
			for i, line in ipairs(fileLines) do
				-- scan for shader version error
				if string.find(line, "error: GLSL 1.50 is not supported", nil, true) then
					Spring.SetConfigInt("LuaShaders", 0)
				end

				-- look for system hardware
				if string.find(line, "Physical CPU Cores", nil, true) then
					if tonumber(string.match(line, "([0-9].*)")) and tonumber(string.match(line, "([0-9].*)")) <= 2 then
						isPotatoCpu = true
					end
				end

				if string.find(line, "Logical CPU Cores", nil, true) then
					if tonumber(string.match(line, "([0-9].*)")) and tonumber(string.match(line, "([0-9].*)")) <= 2 then
						isPotatoCpu = true
					end
				end

				if string.find(line:lower(), "hardware config: ", nil, true) then
					local s_ram = string.match(line, "([0-9]*MB RAM)")
					if s_ram ~= nil then
						s_ram = string.gsub(s_ram, " RAM", "")
						if tonumber(s_ram) and tonumber(s_ram) > 0 and tonumber(s_ram) < 6500 then
							isPotatoCpu = true
						end
					end
				end

				if string.find(line, "Loading widget:", nil, true) then
					break
				end
			end
		end
	end

	-- restrict options for potato systems
	if isPotatoCpu or isPotatoGpu then
		if isPotatoCpu then
			Spring.Echo("potato CPU detected")
		end
		if isPotatoGpu then
			Spring.Echo("potato Graphics Card detected")
		end
	end
	-- restric gfx preset options for potato gpu, lowest preset is added and high preset is removed
	-- custom has to stay last: changing a preset's setting by hand selects the last entry
	local presetKeys
	if devMode or devUI then
		-- dev mode: show all presets so every quality level can be tested
		presetKeys = { "lowest", "low", "medium", "high", "ultra", "custom" }
	elseif isPotatoGpu then
		presetKeys = { "lowest", "low", "medium", "custom" }
	else
		presetKeys = { "low", "medium", "high", "ultra", "custom" }
	end
	local presetNames = {}
	for i, key in ipairs(presetKeys) do
		presetNames[i] = BAR.I18N("ui.settings.option.select_" .. key)
	end

	optionGroups = {
		{ id = "gfx", name = BAR.I18N("ui.settings.group.graphics"), numOptions = 0 },
		{ id = "ui", name = BAR.I18N("ui.settings.group.interface"), numOptions = 0 },
		{ id = "game", name = BAR.I18N("ui.settings.group.game"), numOptions = 0 },
		{ id = "control", name = BAR.I18N("ui.settings.group.control"), numOptions = 0 },
		{ id = "sound", name = BAR.I18N("ui.settings.group.audio"), numOptions = 0 },
		{ id = "notif", name = BAR.I18N("ui.settings.group.notifications"), numOptions = 0 },
		{ id = "accessibility", name = BAR.I18N("ui.settings.group.accessibility"), numOptions = 0 },
		{ id = "custom", name = BAR.I18N("ui.settings.group.custom"), numOptions = 0 },
		{ id = "dev", name = BAR.I18N("ui.settings.group.dev"), numOptions = 0 },
	}

	if not currentGroupTab then
		currentGroupTab = optionGroups[1].id
	else
		-- check if group exists
		local found = false
		for id, group in pairs(optionGroups) do
			if group.id == currentGroupTab then
				found = true
				break
			end
		end
		if not found then
			currentGroupTab = optionGroups[1].id
		end
	end

	local oldValues = {}
	for _, option in ipairs(unfilteredOptions) do
		if option.id ~= nil then -- labels from other widgets may have none
			oldValues[option.id] = option.value
		end
	end

	local hasUserWidgets = false
	for _, data in pairs(widgetHandler.knownWidgets) do
		if not data.fromZip then
			hasUserWidgets = true
		end
	end
	local aiDetected = false
	for _, teamID in ipairs(Spring.GetTeamList()) do
		if select(4, Spring.GetTeamInfo(teamID, false)) then
			aiDetected = true
		end
	end
	local gridMenuOn = GetWidgetToggleValue("Grid menu") and true or false
	local holidays = BAR.Utilities.Gametype.GetCurrentHolidays()
	local camMode = Spring.GetConfigInt("CamMode", 2)

	-- Rows show in this order within their tab; one without a type is a section label.
	-- parent: id of the option this sub-option belongs to (indented below it, found along with it)
	-- prefix: shown ahead of the name, which then takes the sub-option color
	-- compact: a plain toggle that shares a line with the ones beside it
	-- available: false leaves the row out
	-- widgetConfig, configInt, configFloat: where the value lives, see readBoundValue
	options = {
		--GFX
		{
			id = "preset",
			group = "gfx",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.preset"),
			type = "select",
			options = presetNames,
			onload = function(option)
				local preset = Spring.GetConfigString("graphicsPreset", "custom")
				option.value = table.getKeyOf(presetKeys, preset) or #presetKeys
			end,
			onchange = function(option, value)
				local configSetting = presetKeys[value]
				Spring.SetConfigString("graphicsPreset", configSetting)
				if configSetting == "custom" then
					return
				end

				Spring.Echo("Loading preset:   " .. option.options[value])
				manualChange = false
				for optionID, value in pairs(presets[configSetting]) do
					local presetOption = getOption(optionID)
					if presetOption ~= nil then
						applyOptionValue(presetOption, value, true)
					end
				end

				view.build()
				view.refresh()
				manualChange = true
			end,
		},
		{
			id = "label_gfx_screen",
			group = "gfx",
			name = BAR.I18N("ui.settings.option.label_screen"),
			category = types.basic,
		},
		{
			id = "display",
			group = "gfx",
			category = types.basic,
			available = #displayNames > 1, -- without it, resolution moves up a level
			name = BAR.I18N("ui.settings.option.display"),
			type = "select",
			options = displayNames,
			value = currentDisplay,
			onchange = function(option, value)
				--currentDisplay = value
				selectedDisplay = value
				Spring.SetConfigInt("SelectedDisplay", value)
				resolutionNames = {}
				screenmodeOffset = 0
				for _, screenMode in ipairs(screenModes) do
					if screenMode.display == selectedDisplay then
						resolutionNames[#resolutionNames + 1] = screenMode.name
					elseif #resolutionNames == 0 then
						screenmodeOffset = screenmodeOffset + 1
					end
				end
				getOption("resolution").options = resolutionNames
				if selectedDisplay == currentDisplay then
					getOption("resolution").value = Spring.GetConfigInt("SelectedScreenMode", 1)
				else
					getOption("resolution").value = 0
				end
				forceUpdate = true
			end,
		},
		{
			id = "resolution",
			parent = "display",
			group = "gfx",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.resolution"),
			type = "select",
			options = resolutionNames,
			value = Spring.GetConfigInt("SelectedScreenMode", 1),
			description = BAR.I18N("ui.settings.option.resolution_descr"),
			-- also run while the window is open, as the game window can be resized meanwhile
			onload = function(option)
				-- FIXME: disabled for now due to "Now whenever i do fullscreen or borderless the game will go to monitor 2 regardless of the chosen option. (I want the game on monitor 1)."
				--if Spring.GetConfigInt('SelectedScreenMode', -1) >= 1 then		-- chobby sets SelectedScreenMode to -1 when it changes game window mode
				--	WG['screenMode'].SetScreenMode(Spring.GetConfigInt('SelectedScreenMode', 1))
				--end

				-- the mode the window is in, not the last one picked
				if selectedDisplay ~= currentDisplay then
					return -- another display's modes are listed
				end
				local current = currentResolution()
				option.options = resolutionNames
				if current then
					option.value = current
				else
					local w, h = Spring.GetWindowGeometry()
					local names = {}
					for i, name in ipairs(resolutionNames) do
						names[i] = name
					end
					names[#names + 1] = BAR.I18N("ui.resolutionswitcher.window") .. " " .. w .. " × " .. h
					option.options = names
					option.value = #names
				end
			end,
			onchange = function(option, value)
				if value > #resolutionNames then
					return -- the size the window has now
				end
				Spring.SetConfigInt("SelectedScreenMode", value)

				if WG.screenMode then
					WG.screenMode.SetScreenMode(value + screenmodeOffset)
					currentDisplay = 1
					local v_sx, v_sy, v_px, v_py = Spring.GetViewGeometry()
					for index, display in ipairs(displays) do
						if
							v_px >= display.x
							and v_px < display.x + display.width
							and v_py >= display.y
							and v_py < display.y + display.height
						then
							currentDisplay = index
						end
					end
				end
			end,
		},
		{
			id = "dualmode_enabled",
			group = "gfx",
			category = types.dev,
			available = dualScreen,
			name = BAR.I18N("ui.settings.option.dualmode"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.dualmode_enabled_descr"),
			configInt = "DualScreenMode",
		},
		{
			id = "dualmode_left",
			parent = "dualmode_enabled",
			group = "gfx",
			category = types.dev,
			available = dualScreen,
			name = BAR.I18N("ui.settings.option.dualmode_left"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.dualmode_left_descr"),
			configInt = "DualScreenMiniMapOnLeft",
		},
		{
			id = "dualmode_minimap_aspectratio",
			parent = "dualmode_enabled",
			group = "gfx",
			category = types.dev,
			available = dualScreen,
			name = BAR.I18N("ui.settings.option.dualmode_minimap_aspectratio"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.dualmode_minimap_aspectratio_descr"),
			configInt = "DualScreenMiniMapAspectRatio",
		},
		{
			id = "vsync",
			group = "gfx",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.vsync"),
			type = "select",
			options = {
				BAR.I18N("ui.settings.option.select_off"),
				BAR.I18N("ui.settings.option.select_enabled"),
				BAR.I18N("ui.settings.option.select_adaptive"),
			},
			value = 2,
			description = BAR.I18N("ui.settings.option.vsync_descr"),
			onload = function(option)
				local vsync = Spring.GetConfigInt("VSyncGame", -1)
				if vsync > 0 then
					option.value = 2
				elseif vsync < 0 then
					option.value = 3
				else
					option.value = 1
				end
			end,
			onchange = function(option, value)
				-- VSyncGame is the mode (1 on, -1 adaptive, 0 off), times VSyncFraction here and in the lobby
				local mode = 0
				if value == 2 then
					mode = 1
				elseif value == 3 then
					mode = -1
				end
				Spring.SetConfigInt("VSync", mode * Spring.GetConfigInt("VSyncFraction", 1))
				Spring.SetConfigInt("VSyncGame", mode) -- stored here as assurance cause lobby/game also changes vsync when idle and lobby could think game has set vsync 4 after a hard crash
			end,
		},
		{
			id = "vsync_fraction",
			parent = "vsync",
			group = "gfx",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.vsync_fraction"),
			min = 1,
			max = 4,
			step = 1,
			type = "slider",
			value = Spring.GetConfigInt("VSyncFraction", 1),
			description = BAR.I18N("ui.settings.option.vsync_fraction_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("VSyncFraction", value)
				local vsync = Spring.GetConfigInt("VSyncGame", -1)
				if vsync ~= 0 then
					Spring.SetConfigInt("VSync", vsync * value)
				end
			end,
		},

		{
			id = "limitoffscreenfps",
			group = "gfx",
			category = types.advanced,
			widget = "Limit idle FPS",
			name = BAR.I18N("ui.settings.option.limitoffscreenfps"),
			type = "bool",
			value = GetWidgetToggleValue("Limit idle FPS"),
			description = BAR.I18N("ui.settings.option.limitoffscreenfps_descr"),
		},
		{
			id = "limitidlefps",
			parent = "limitoffscreenfps",
			group = "gfx",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.limitidlefps"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.limitidlefps_descr"),
			configInt = "LimitIdleFps",
		},

		{
			id = "msaa",
			group = "gfx",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.msaa"),
			type = "select",
			options = { BAR.I18N("ui.settings.option.select_off"), "x2", "x4", "x8" },
			restart = true,
			value = tonumber(Spring.GetConfigInt("MSAALevel", 0) or 0),
			description = BAR.I18N("ui.settings.option.msaa_descr"),
			onload = function(option)
				local msaa = tonumber(Spring.GetConfigInt("MSAALevel", 0) or 0)
				if msaa <= 0 then
					option.value = 1
				else
					for k, v in ipairs(option.options) do
						if v == "x" .. msaa then
							option.value = k
							break
						end
					end
				end
			end,
			onchange = function(option, value)
				if value == 1 then
					Spring.SetConfigInt("MSAA", 0)
					Spring.SetConfigInt("MSAALevel", -1) -- setting 0 will reset it to default x4 :(
				else
					Spring.SetConfigInt("MSAA", 1)
					Spring.SetConfigInt("MSAALevel", tonumber(string.sub(option.options[value], 2)))
				end
			end,
		},

		{
			id = "supersampling",
			parent = "msaa",
			group = "gfx",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.supersampling"),
			type = "bool",
			restart = false,
			value = (Spring.GetConfigFloat("MinSampleShadingRate", 0.0) == 1.0),
			description = BAR.I18N("ui.settings.option.supersampling_descr"),
			onchange = function(option, value)
				Spring.SetConfigFloat("MinSampleShadingRate", (value and 1.0 or 0.0))
			end,
		},

		{
			id = "cas_sharpness",
			group = "gfx",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.cas_sharpness"),
			min = 0.5,
			max = 1.1,
			step = 0.01,
			type = "slider",
			value = 1.0,
			description = BAR.I18N("ui.settings.option.cas_sharpness_descr"),
			onload = function(option)
				loadWidgetData("Contrast Adaptive Sharpen", "cas_sharpness", { "SHARPNESS" })
			end,
			onchange = function(option, value)
				if not GetWidgetToggleValue("Contrast Adaptive Sharpen") then
					widgetHandler:EnableWidget("Contrast Adaptive Sharpen")
				end
				saveOptionValue("Contrast Adaptive Sharpen", "cas", "setSharpness", { "SHARPNESS" }, option.value)
			end,
		},

		{
			id = "sepiatone",
			group = "gfx",
			category = types.advanced,
			widget = "Sepia Tone",
			name = BAR.I18N("ui.settings.option.sepiatone"),
			type = "bool",
			value = GetWidgetToggleValue("Sepia Tone"),
		},
		{
			id = "sepiatone_gamma",
			parent = "sepiatone",
			group = "gfx",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.sepiatone_gamma"),
			min = 0.1,
			max = 0.9,
			step = 0.02,
			type = "slider",
			value = 0.5,
			widgetConfig = { "Sepia Tone", "gamma", api = "sepia", set = "setGamma" },
		},
		{
			id = "sepiatone_saturation",
			parent = "sepiatone",
			group = "gfx",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.sepiatone_saturation"),
			min = 0,
			max = 1,
			step = 0.02,
			type = "slider",
			value = 0.5,
			widgetConfig = { "Sepia Tone", "saturation", api = "sepia", set = "setSaturation" },
		},
		{
			id = "sepiatone_contrast",
			parent = "sepiatone",
			group = "gfx",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.sepiatone_contrast"),
			min = 0.1,
			max = 0.9,
			step = 0.02,
			type = "slider",
			value = 0.5,
			widgetConfig = { "Sepia Tone", "contrast", api = "sepia", set = "setContrast" },
		},
		{
			id = "sepiatone_sepia",
			parent = "sepiatone",
			group = "gfx",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.sepiatone_sepia"),
			min = 0,
			max = 0.5,
			step = 0.02,
			type = "slider",
			value = 0.5,
			description = BAR.I18N("ui.settings.option.sepiatone_sepia_descr"),
			widgetConfig = { "Sepia Tone", "sepia", api = "sepia", set = "setSepia" },
		},
		{
			id = "sepiatone_shadeui",
			parent = "sepiatone",
			group = "gfx",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.sepiatone_shadeui"),
			type = "bool",
			value = false,
			widgetConfig = { "Sepia Tone", "shadeUI", api = "sepia", set = "setShadeUI" },
		},

		{
			id = "label_gfx_lighting",
			group = "gfx",
			name = BAR.I18N("ui.settings.option.label_lighting"),
			category = types.basic,
		},

		{
			id = "advmapshading",
			group = "gfx",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.advmapshading"),
			type = "bool",
			value = (Spring.GetConfigInt("AdvMapShading", 1) == 1),
			description = BAR.I18N("ui.settings.option.advmapshading_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("AdvMapShading", (value and 1 or 0))
				Spring.SendCommands("advmapshading " .. (value and "1" or "0"))
			end,
		},

		{
			id = "cusgl4",
			group = "gfx",
			name = BAR.I18N("ui.settings.option.cus"),
			category = types.basic,
			type = "bool",
			value = (Spring.GetConfigInt("cus2", 1) == 1),
			description = BAR.I18N("ui.settings.option.cus_descr"),
			onchange = function(option, value)
				if value == 0.5 then
					Spring.SendCommands("luarules disablecusgl4")
				else
					Spring.SetConfigInt("cus2", (value and 1 or 0))
					Spring.SendCommands("luarules " .. (value and "reloadcusgl4" or "disablecusgl4"))
				end
			end,
		},

		{
			id = "shadowslider",
			group = "gfx",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.shadowslider"),
			type = "select",
			options = {
				BAR.I18N("ui.settings.option.select_off"),
				BAR.I18N("ui.settings.option.select_lowest"),
				BAR.I18N("ui.settings.option.select_low"),
				BAR.I18N("ui.settings.option.select_medium"),
				BAR.I18N("ui.settings.option.select_high"),
				BAR.I18N("ui.settings.option.select_ultra"),
			},
			value = Spring.GetConfigInt("ShadowQuality", 3) + 1,
			description = BAR.I18N("ui.settings.option.shadowslider_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("ShadowQuality", value - 1)
				adjustShadowQuality()
			end,
		},

		{
			id = "shadows_opacity",
			parent = "shadowslider",
			group = "gfx",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.shadows_opacity"),
			type = "slider",
			min = 0.3,
			max = 1,
			step = 0.01,
			value = gl.GetSun("shadowDensity"),
			description = "",
			onchange = function(option, value)
				Spring.SetSunLighting({ groundShadowDensity = value, modelShadowDensity = value })
			end,
		},

		{
			id = "ssao",
			group = "gfx",
			category = types.basic,
			widget = "SSAO",
			name = BAR.I18N("ui.settings.option.ssao"),
			type = "bool",
			value = GetWidgetToggleValue("SSAO"),
			description = BAR.I18N("ui.settings.option.ssao_descr"),
		},
		{
			id = "ssao_strength",
			parent = "ssao",
			group = "gfx",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.ssao_strength"),
			type = "slider",
			min = 5,
			max = 15,
			step = 1,
			value = 10,
			description = "",
			widgetConfig = { "SSAO", "strength", api = "ssao", set = "setStrength" },
		},
		{
			id = "ssao_quality",
			parent = "ssao",
			group = "gfx",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.ssao_quality"),
			type = "select",
			options = {
				BAR.I18N("ui.settings.option.select_low"),
				BAR.I18N("ui.settings.option.select_medium"),
				BAR.I18N("ui.settings.option.select_high"),
			},
			value = (WG.ssao ~= nil and WG.ssao.getPreset() or 2),
			description = BAR.I18N("ui.settings.option.ssao_quality_descr"),
			onload = function(option)
				if widgetHandler.configData.SSAO ~= nil and widgetHandler.configData.SSAO.preset ~= nil then
					option.value = widgetHandler.configData.SSAO.preset
				end
			end,
			onchange = function(option, value)
				saveOptionValue("SSAO", "ssao", "setPreset", { "preset" }, value)
			end,
		},

		{
			id = "bloomdeferred",
			group = "gfx",
			category = types.basic,
			widget = "Bloom Shader Deferred",
			name = BAR.I18N("ui.settings.option.bloomdeferred"),
			type = "bool",
			value = GetWidgetToggleValue("Bloom Shader Deferred"),
			description = BAR.I18N("ui.settings.option.bloomdeferred_descr"),
		},
		{
			id = "bloomdeferredbrightness",
			parent = "bloomdeferred",
			group = "gfx",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.bloomdeferredbrightness"),
			type = "slider",
			min = 0.5,
			max = 2.0,
			step = 0.05,
			value = 1.0,
			description = "",
			widgetConfig = { "Bloom Shader Deferred", "glowAmplifier", api = "bloomdeferred", set = "setBrightness" },
		},
		{
			id = "bloomdeferred_quality",
			parent = "bloomdeferred",
			group = "gfx",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.bloomdeferred_quality"),
			type = "select",
			options = {
				BAR.I18N("ui.settings.option.select_low"),
				BAR.I18N("ui.settings.option.select_medium"),
				BAR.I18N("ui.settings.option.select_high"),
			},
			value = (WG.bloomdeferred ~= nil and WG.bloomdeferred.getPreset() or 2),
			description = BAR.I18N("ui.settings.option.bloomdeferred_quality_descr"),
			onload = function(option)
				if
					widgetHandler.configData["Bloom Shader Deferred"] ~= nil
					and widgetHandler.configData["Bloom Shader Deferred"].preset ~= nil
				then
					option.value = widgetHandler.configData["Bloom Shader Deferred"].preset
				end
			end,
			onchange = function(option, value)
				saveOptionValue("Bloom Shader Deferred", "bloomdeferred", "setPreset", { "preset" }, value)
			end,
		},

		{
			id = "lighteffects",
			group = "gfx",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.lighteffects"),
			type = "bool",
			value = GetWidgetToggleValue("Deferred rendering GL4"),
			description = BAR.I18N("ui.settings.option.lighteffects_descr"),
			onchange = function(option, value)
				if value then
					widgetHandler:EnableWidget("Deferred rendering GL4")
				else
					widgetHandler:DisableWidget("Deferred rendering GL4")
				end
			end,
		},
		{
			id = "lighteffects_headlights",
			parent = "lighteffects",
			group = "gfx",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.lighteffects_headlights"),
			type = "bool",
			value = Spring.GetConfigInt("headlights", 1) == 1,
			description = BAR.I18N("ui.settings.option.lighteffects_headlights_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("headlights", value and 1 or 0)
				if widgetHandler.orderList["Deferred rendering GL4"] ~= nil then
					widgetHandler:DisableWidget("Deferred rendering GL4")
					widgetHandler:EnableWidget("Deferred rendering GL4")
				end
			end,
		},
		{
			id = "lighteffects_buildlights",
			parent = "lighteffects",
			group = "gfx",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.lighteffects_buildlights"),
			type = "bool",
			value = Spring.GetConfigInt("buildlights", 1) == 1,
			description = BAR.I18N("ui.settings.option.lighteffects_buildlights_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("buildlights", value and 1 or 0)
				if widgetHandler.orderList["Deferred rendering GL4"] ~= nil then
					widgetHandler:DisableWidget("Deferred rendering GL4")
					widgetHandler:EnableWidget("Deferred rendering GL4")
				end
			end,
		},
		{
			id = "lighteffects_brightness",
			parent = "lighteffects",
			group = "gfx",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.lighteffects_brightness"),
			min = 0.4,
			max = 1.5,
			step = 0.05,
			type = "slider",
			value = 1,
			description = BAR.I18N("ui.settings.option.lighteffects_brightness_descr"),
			widgetConfig = {
				"Deferred rendering GL4",
				"intensityMultiplier",
				api = "lightsgl4",
				set = "IntensityMultiplier",
			},
		},
		{
			id = "lighteffects_radius",
			parent = "lighteffects",
			group = "gfx",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.lighteffects_radius"),
			min = 0.4,
			max = 1.2,
			step = 0.05,
			type = "slider",
			value = 1,
			description = BAR.I18N("ui.settings.option.lighteffects_radius_descr"),
			widgetConfig = { "Deferred rendering GL4", "radiusMultiplier", api = "lightsgl4", set = "RadiusMultiplier" },
		},

		{
			id = "lighteffects_screenspaceshadows",
			parent = "lighteffects",
			group = "gfx",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.lighteffects_screenspaceshadows"),
			min = 0,
			max = 4,
			step = 1,
			type = "slider",
			value = 2,
			description = BAR.I18N("ui.settings.option.lighteffects_screenspaceshadows_descr"),
			widgetConfig = {
				"Deferred rendering GL4",
				"screenSpaceShadows",
				api = "lightsgl4",
				set = "ScreenSpaceShadows",
			},
		},

		{
			id = "lighteffects_nanoparticlelights",
			parent = "lighteffects",
			group = "gfx",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.nanoparticlelights"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.nanoparticlelights_descr"),
			configInt = "NanoParticlesUpdateLuaUI",
		},

		{
			id = "distortioneffects",
			group = "gfx",
			category = types.basic,
			widget = "Distortion GL4",
			name = BAR.I18N("ui.settings.option.distortioneffects"),
			type = "bool",
			value = GetWidgetToggleValue("Distortion GL4"),
			description = BAR.I18N("ui.settings.option.distortioneffects_descr"),
		},

		{
			id = "darkenmap",
			group = "gfx",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.darkenmap"),
			min = 0,
			max = 0.33,
			step = 0.01,
			type = "slider",
			value = 0,
			description = BAR.I18N("ui.settings.option.darkenmap_descr"),
			widgetConfig = { "Darken map", "darknessvalue", api = "darkenmap", set = "setMapDarkness" },
		},

		{
			id = "label_gfx_environment",
			group = "gfx",
			name = BAR.I18N("ui.settings.option.label_environment"),
			category = types.basic,
		},

		{
			id = "featuredrawdist",
			group = "gfx",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.featuredrawdist"),
			type = "slider",
			min = 2500,
			max = 40000,
			step = 500,
			value = tonumber(Spring.GetConfigInt("FeatureDrawDistance", 10000)),
			description = BAR.I18N("ui.settings.option.featuredrawdist_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("FeatureFadeDistance", math.floor(value * 0.8))
				Spring.SetConfigInt("FeatureDrawDistance", value)
			end,
		},

		{
			id = "losopacity",
			group = "gfx",
			category = types.advanced,
			prefix = BAR.I18N("ui.settings.option.lineofsight"),
			name = BAR.I18N("ui.settings.option.losopacity"),
			type = "slider",
			min = 0.01,
			max = 1,
			step = 0.01,
			value = 0.66,
			description = "",
			widgetConfig = { "LOS colors", "opacity", api = "los", get = "getOpacity", set = "setOpacity" },
		},

		{
			id = "fogdiaglines",
			group = "gfx",
			category = types.advanced,
			prefix = BAR.I18N("ui.settings.option.lineofsight"),
			name = BAR.I18N("ui.settings.option.fogdiaglines"),
			type = "slider",
			min = 0,
			max = 1,
			step = 0.01,
			value = 0.30,
			description = "",
			widgetConfig = {
				"Fog Diagonal Lines GL4",
				"strength",
				api = "fogdiaglines",
				get = "getStrength",
				set = "setStrength",
			},
		},

		{
			id = "fogdiaglines_blur",
			group = "gfx",
			category = types.advanced,
			prefix = BAR.I18N("ui.settings.option.lineofsight"),
			name = BAR.I18N("ui.settings.option.fogdiaglines_blur"),
			type = "slider",
			min = 0,
			max = 1,
			step = 0.01,
			value = 0.187,
			description = "",
			widgetConfig = {
				"Fog Diagonal Lines GL4",
				"blurriness",
				api = "fogdiaglines",
				get = "getBlurriness",
				set = "setBlurriness",
			},
		},

		{
			id = "dominion_height_opacity",
			group = "gfx",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.dominion_height_opacity"),
			type = "slider",
			min = 0.5,
			max = 2.0,
			step = 0.05,
			value = 1.0,
			description = BAR.I18N("ui.settings.option.dominion_height_opacity_descr"),
			configFloat = "dominion_height_opacity",
		},

		{
			id = "water",
			group = "gfx",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.water"),
			type = "select",
			options = { BAR.I18N("ui.settings.option.select_low"), BAR.I18N("ui.settings.option.select_high") },
			value = desiredWaterValue == 4 and 2 or 1,
			onchange = function(option, value)
				desiredWaterValue = value > 1 and 4 or 0
				if waterDetected then
					if desiredWaterValue > 0 then
						desiredWaterValue = 4
					end
					Spring.SendCommands("water " .. desiredWaterValue)
					Spring.SetConfigInt("water", 4)
				end
			end,
		},

		{
			id = "mapedgeextension",
			group = "gfx",
			category = types.advanced,
			widget = "Map Edge Extension",
			name = BAR.I18N("ui.settings.option.mapedgeextension"),
			type = "bool",
			value = GetWidgetToggleValue("Map Edge Extension"),
			description = BAR.I18N("ui.settings.option.mapedgeextension_descr"),
		},

		{
			id = "mapedgeextension_brightness",
			parent = "mapedgeextension",
			group = "gfx",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.mapedgeextension_brightness"),
			min = 0.2,
			max = 1,
			step = 0.01,
			type = "slider",
			value = 0.3,
			description = "",
			widgetConfig = { "Map Edge Extension", "brightness", api = "mapedgeextension", set = "setBrightness" },
		},
		{
			id = "mapedgeextension_curvature",
			parent = "mapedgeextension",
			category = types.dev,
			group = "gfx",
			name = BAR.I18N("ui.settings.option.mapedgeextension_curvature"),
			type = "bool",
			value = true,
			description = BAR.I18N("ui.settings.option.mapedgeextension_curvature_descr"),
			widgetConfig = { "Map Edge Extension", "curvature", api = "mapedgeextension", set = "setCurvature" },
		},

		{
			id = "decalsgl4",
			group = "gfx",
			category = types.basic,
			widget = "Decals GL4",
			name = BAR.I18N("ui.settings.option.decalsgl4"),
			type = "bool",
			value = GetWidgetToggleValue("Decals GL4"),
		},
		{
			id = "decalsgl4_lifetime",
			parent = "decalsgl4",
			group = "gfx",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.decalsgl4_lifetime"),
			min = 0.5,
			max = 8,
			step = 0.1,
			type = "slider",
			value = 1,
			description = BAR.I18N("ui.settings.option.decalsgl4_lifetime_descr"),
			widgetConfig = { "Decals GL4", "lifeTimeMult", api = "decalsgl4", set = "SetLifeTimeMult" },
		},
		{
			id = "decals",
			group = "gfx",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.decals"),
			type = "bool",
			value = Spring.GetConfigInt("GroundDecals", 1) > 0,
			description = BAR.I18N("ui.settings.option.decals_descr"),
			onchange = function(option, value)
				-- the engine draws ground decals or not, it has no levels
				Spring.SetConfigInt("GroundDecals", value and 1 or 0)
				Spring.SendCommands("GroundDecals " .. (value and 1 or 0))
			end,
		},

		{
			id = "grass",
			group = "gfx",
			category = types.basic,
			widget = "Map Grass GL4",
			name = BAR.I18N("ui.settings.option.grass"),
			type = "bool",
			value = GetWidgetToggleValue("Map Grass GL4"),
			description = BAR.I18N("ui.settings.option.grass_desc"),
		},
		{
			id = "grassdistance",
			parent = "grass",
			group = "gfx",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.grassdistance"),
			type = "slider",
			min = 0.3,
			max = 1,
			step = 0.01,
			value = 1,
			description = BAR.I18N("ui.settings.option.grassdistance_desc"),
			widgetConfig = { "Map Grass GL4", "distanceMult", api = "grassgl4", set = "setDistanceMult" },
		},

		{
			id = "treewind",
			group = "gfx",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.treewind"),
			type = "bool",
			value = tonumber(Spring.GetConfigInt("TreeWind", 1) or 1) == 1,
			description = BAR.I18N("ui.settings.option.treewind_descr"),
			onchange = function(option, value)
				Spring.SendCommands("luarules treewind " .. (value and 1 or 0))
				Spring.SetConfigInt("TreeWind", (value and 1 or 0))
			end,
		},

		{
			id = "snow",
			group = "gfx",
			category = types.basic,
			widget = "Snow",
			name = BAR.I18N("ui.settings.option.snow"),
			type = "bool",
			value = GetWidgetToggleValue("Snow"),
			description = BAR.I18N("ui.settings.option.snow_descr"),
		},
		{
			id = "snowmap",
			parent = "snow",
			group = "gfx",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.snowmap"),
			type = "bool",
			value = true,
			description = BAR.I18N("ui.settings.option.snowmap_descr"),
			onload = function(option)
				loadWidgetData("Snow", "snowmap", { "snowMaps", Game.mapName:lower() })
			end,
			onchange = function(option, value)
				saveOptionValue("Snow", "snow", "setSnowMap", { "snowMaps", Game.mapName:lower() }, value)
			end,
		},
		{
			id = "snowautoreduce",
			parent = "snow",
			group = "gfx",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.snowautoreduce"),
			type = "bool",
			value = true,
			description = BAR.I18N("ui.settings.option.snowautoreduce_descr"),
			widgetConfig = { "Snow", "autoReduce", api = "snow", set = "setAutoReduce" },
		},
		{
			id = "snowamount",
			parent = "snow",
			group = "gfx",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.snowamount"),
			type = "slider",
			min = 0.2,
			max = 3,
			step = 0.2,
			value = 1,
			description = BAR.I18N("ui.settings.option.snowamount_descr"),
			widgetConfig = { "Snow", "customParticleMultiplier", api = "snow", set = "setMultiplier" },
		},

		{
			id = "clouds",
			group = "gfx",
			category = types.advanced,
			widget = "Volumetric Clouds",
			name = BAR.I18N("ui.settings.option.clouds"),
			type = "bool",
			value = GetWidgetToggleValue("Volumetric Clouds"),
			description = "",
		},
		{
			id = "clouds_opacity",
			parent = "clouds",
			group = "gfx",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.clouds_opacity"),
			type = "slider",
			min = 0.2,
			max = 1.4,
			step = 0.05,
			value = 1,
			description = "",
			widgetConfig = { "Volumetric Clouds", "opacityMult", api = "clouds", set = "setOpacity" },
		},
		{
			id = "fogmult",
			group = "gfx",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.fog"),
			type = "slider",
			min = 0,
			max = 1,
			step = 0.01,
			value = Spring.GetConfigFloat("FogMult", 1),
			description = BAR.I18N("ui.settings.option.fogmult_descr"),
			onload = function(option)
				option.onchange(option, option.value)
			end,
			onchange = function(option, value)
				Spring.SetConfigFloat("FogMult", value)
				value = 1 / value -- inverse
				local newFogStart = math.min(9, (defaultMapFog.fogStart * ((value + 4) * 0.2)))
				local newFogEnd = math.min(9, defaultMapFog.fogEnd * ((value + 1) * 0.5))
				if newFogStart >= newFogEnd then
					newFogStart = newFogEnd - 0.01
				end
				Spring.SetAtmosphere({ fogStart = newFogStart, fogEnd = newFogEnd })
			end,
		},

		{
			id = "label_gfx_effects",
			group = "gfx",
			name = BAR.I18N("ui.settings.option.label_effects"),
			category = types.basic,
		},

		{
			id = "particles",
			group = "gfx",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.particles"),
			type = "slider",
			min = 10000,
			max = 40000,
			step = 1000,
			value = tonumber(Spring.GetConfigInt("MaxParticles", 1) or 15000),
			description = BAR.I18N("ui.settings.option.particles_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("MaxParticles", value)
				-- Keep the engine nano-spray budget in sync when the gadget is
				-- handing particles back to the engine (NanoParticleMode 0).
				if Spring.GetConfigInt("NanoParticleMode", 1) == 0 then
					Spring.SetConfigInt("MaxNanoParticles", math.floor(value * 0.34))
					if Spring.GetConfigInt("NanoParticleMode", 1) == 0 then
						Spring.SetConfigInt(
							"MaxNanoParticles",
							math.floor(Spring.GetConfigInt("MaxParticles", 15000) * 0.34)
						)
					else
						Spring.SetConfigInt("MaxNanoParticles", 0)
					end
				end
			end,
		},

		{
			id = "dof",
			group = "gfx",
			category = types.advanced,
			widget = "Depth of Field",
			name = BAR.I18N("ui.settings.option.dof"),
			type = "bool",
			value = GetWidgetToggleValue("Depth of Field"),
			description = BAR.I18N("ui.settings.option.dof_descr"),
		},
		{
			id = "dof_autofocus",
			parent = "dof",
			group = "gfx",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.dof_autofocus"),
			type = "bool",
			value = true,
			description = BAR.I18N("ui.settings.option.dof_autofocus_descr"),
			widgetConfig = { "Depth of Field", "autofocus", api = "dof", set = "setAutofocus" },
		},
		{
			id = "dof_fstop",
			parent = "dof",
			group = "gfx",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.dof_fstop"),
			type = "slider",
			min = 1,
			max = 6,
			step = 0.1,
			value = 2,
			description = BAR.I18N("ui.settings.option.dof_fstop_descr"),
			widgetConfig = { "Depth of Field", "fStop", api = "dof", set = "setFstop" },
		},

		-- SOUND
		{
			id = "snddevice",
			group = "sound",
			category = types.advanced,
			available = soundDevices[2] ~= nil,
			name = BAR.I18N("ui.settings.option.snddevice"),
			type = "select",
			-- the engine switches the device in game while SDL plays the sound
			restart = not (Engine.FeatureSupport.liveConfigChanges and Spring.GetConfigInt("UseSDLAudio", 1) ~= 0),
			options = soundDevices,
			value = soundDevicesByName[Spring.GetConfigString("snd_device")],
			description = BAR.I18N("ui.settings.option.snddevice_descr"),
			onchange = function(option, value)
				if option.options[option.value] == "default" then
					Spring.SetConfigString("snd_device", "")
				else
					Spring.SetConfigString("snd_device", option.options[option.value])
				end
			end,
		},

		{
			id = "sndvolmaster",
			group = "sound",
			category = types.basic,
			prefix = BAR.I18N("ui.settings.option.volume"),
			name = BAR.I18N("ui.settings.option.sndvolmaster"),
			type = "slider",
			min = 0,
			max = 80,
			step = 2,
			value = 1,
			configInt = "snd_volmaster",
		},
		{
			id = "sndvolgeneral",
			parent = "sndvolmaster",
			group = "sound",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.sndvolgeneral"),
			type = "slider",
			min = 0,
			max = 100,
			step = 2,
			value = 1,
			configInt = "snd_volgeneral",
		},
		{
			id = "sndvolbattle",
			parent = "sndvolmaster",
			group = "sound",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.sndvolbattle"),
			type = "slider",
			min = 0,
			max = 100,
			step = 2,
			value = 100,
			configInt = "snd_volbattle_options",
		},
		{
			id = "sndvolui",
			parent = "sndvolmaster",
			group = "sound",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.sndvolui"),
			type = "slider",
			min = 0,
			max = 100,
			step = 2,
			value = 1,
			configInt = "snd_volui",
		},
		--{ id = "sndambient", group = "sound", category = types.basic, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.sndvolambient'), type = "slider", min = 0, max = 100, step = 2, value = tonumber(Spring.GetConfigInt("snd_volambient", 1) or 100),
		--  onload = function(option)
		--  end,
		--  onchange = function(option, value)
		--	  Spring.SetConfigInt("snd_volambient", value)
		--  end,
		--},
		--{ id = "sndvolunitreply", group = "sound", category = types.basic, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.sndvolunitreply'), type = "slider", min = 0, max = 100, step = 2, value = tonumber(Spring.GetConfigInt("snd_volunitreply", 1) or 100),
		--  onload = function(option)
		--  end,
		--  onchange = function(option, value)
		--	  Spring.SetConfigInt("snd_volunitreply", value)
		--  end,
		--},
		{
			id = "console_chatvolume",
			parent = "sndvolmaster",
			group = "sound",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.console_chatvolume"),
			type = "slider",
			min = 0,
			max = 1,
			step = 0.01,
			value = 0,
			description = BAR.I18N("ui.settings.option.console_chatvolume_descr"),
			widgetConfig = { "Chat", "sndChatFileVolume", api = "chat", get = "getChatVolume", set = "setChatVolume" },
		},
		{
			id = "mapmarkvolume",
			parent = "sndvolmaster",
			group = "sound",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.console_mapmarkvolume"),
			type = "slider",
			min = 0,
			max = 1,
			step = 0.01,
			value = 0.6,
			description = BAR.I18N("ui.settings.option.console_mapmarkvolume_descr"),
			widgetConfig = {
				"Mapmark Ping",
				"volume",
				api = "mapmarkping",
				get = "getMapmarkVolume",
				set = "setMapmarkVolume",
			},
		},
		{
			id = "sndvolmusic",
			parent = "sndvolmaster",
			group = "sound",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.sndvolmusic"),
			type = "slider",
			min = 0,
			max = 99,
			step = 1,
			value = tonumber(Spring.GetConfigInt("snd_volmusic", 50) or 50),
			onchange = function(option, value)
				if WG.music and WG.music.SetMusicVolume then
					WG.music.SetMusicVolume(value)
				else
					Spring.SetConfigInt("snd_volmusic", value)
				end
			end,
		},

		{
			id = "sndunitsound",
			group = "sound",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.sndunitsound"),
			type = "bool",
			value = true,
			description = BAR.I18N("ui.settings.option.sndunitsound_desc"),
			configInt = "snd_unitsound",
		},

		{
			id = "sndairabsorption",
			group = "sound",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.sndairabsorption"),
			type = "slider",
			min = 0,
			max = 0.4,
			step = 0.01,
			value = 0.35,
			description = BAR.I18N("ui.settings.option.sndairabsorption_descr"),
			configFloat = "snd_airAbsorption",
		},

		{
			id = "sndzoomvolume",
			group = "sound",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.sndzoomvolume"),
			type = "slider",
			min = 0,
			max = 3,
			step = 0.01,
			value = 1.00,
			description = BAR.I18N("ui.settings.option.sndzoomvolume_descr"),
			configFloat = "snd_zoomVolume",
		},

		{
			id = "muteoffscreen",
			group = "sound",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.muteoffscreen"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.muteoffscreen_descr"),
			configInt = "muteOffscreen",
		},

		{
			id = "soundtrack",
			group = "sound",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.label_soundtrack"),
		},

		{
			id = "soundtrackNew",
			group = "sound",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.soundtracknew"),
			type = "bool",
			value = Spring.GetConfigInt("UseSoundtrackNew", 1) == 1,
			description = BAR.I18N("ui.settings.option.soundtracknew_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("UseSoundtrackNew", value and 1 or 0)
				if WG.music and WG.music.RefreshTrackList then
					WG.music.RefreshTrackList()
					init()
				end
			end,
		},
		{
			id = "soundtrackRaptors",
			parent = "soundtrackNew",
			group = "sound",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.soundtrackraptors"),
			type = "bool",
			value = Spring.GetConfigInt("UseSoundtrackRaptors", 0) == 1,
			description = BAR.I18N("ui.settings.option.soundtrackraptors_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("UseSoundtrackRaptors", value and 1 or 0)
				if WG.music and WG.music.RefreshTrackList then
					WG.music.RefreshTrackList()
					init()
				end
			end,
		},
		{
			id = "soundtrackScavengers",
			parent = "soundtrackNew",
			group = "sound",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.soundtrackscavengers"),
			type = "bool",
			value = Spring.GetConfigInt("UseSoundtrackScavengers", 0) == 1,
			description = BAR.I18N("ui.settings.option.soundtrackscavengers_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("UseSoundtrackScavengers", value and 1 or 0)
				if WG.music and WG.music.RefreshTrackList then
					WG.music.RefreshTrackList()
					init()
				end
			end,
		},
		{
			id = "soundtrackAprilFools",
			parent = "soundtrackNew",
			group = "sound",
			category = types.basic,
			available = holidays.aprilfools == true,
			name = BAR.I18N("ui.settings.option.soundtrackaprilfools"),
			type = "bool",
			value = Spring.GetConfigInt("UseSoundtrackAprilFools", 1) == 1,
			description = BAR.I18N("ui.settings.option.soundtrackaprilfools_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("UseSoundtrackAprilFools", value and 1 or 0)
				if WG.music and WG.music.RefreshTrackList then
					WG.music.RefreshTrackList()
					init()
				end
			end,
		},
		{
			id = "soundtrackAprilFoolsPostEvent",
			parent = "soundtrackNew",
			group = "sound",
			category = types.basic,
			available = not holidays.aprilfools,
			name = BAR.I18N("ui.settings.option.soundtrackaprilfoolspostevent"),
			type = "bool",
			value = Spring.GetConfigInt("UseSoundtrackAprilFoolsPostEvent", 0) == 1,
			description = BAR.I18N("ui.settings.option.soundtrackaprilfoolspostevent_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("UseSoundtrackAprilFoolsPostEvent", value and 1 or 0)
				if WG.music and WG.music.RefreshTrackList then
					WG.music.RefreshTrackList()
					init()
				end
			end,
		},
		{
			id = "soundtrackHalloween",
			parent = "soundtrackNew",
			group = "sound",
			category = types.basic,
			available = holidays.halloween == true,
			name = BAR.I18N("ui.settings.option.soundtrackhalloween"),
			type = "bool",
			value = Spring.GetConfigInt("UseSoundtrackHalloween", 1) == 1,
			description = BAR.I18N("ui.settings.option.soundtrackhalloween_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("UseSoundtrackHalloween", value and 1 or 0)
				if WG.music and WG.music.RefreshTrackList then
					WG.music.RefreshTrackList()
					init()
				end
			end,
		},
		{
			id = "soundtrackHalloweenPostEvent",
			parent = "soundtrackNew",
			group = "sound",
			category = types.basic,
			available = not holidays.halloween,
			name = BAR.I18N("ui.settings.option.soundtrackhalloweenpostevent"),
			type = "bool",
			value = Spring.GetConfigInt("UseSoundtrackHalloweenPostEvent", 0) == 1,
			description = BAR.I18N("ui.settings.option.soundtrackhalloweenpostevent_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("UseSoundtrackHalloweenPostEvent", value and 1 or 0)
				if WG.music and WG.music.RefreshTrackList then
					WG.music.RefreshTrackList()
					init()
				end
			end,
		},
		{
			id = "soundtrackXmas",
			parent = "soundtrackNew",
			group = "sound",
			category = types.basic,
			available = holidays.xmas == true,
			name = BAR.I18N("ui.settings.option.soundtrackxmas"),
			type = "bool",
			value = Spring.GetConfigInt("UseSoundtrackXmas", 1) == 1,
			description = BAR.I18N("ui.settings.option.soundtrackxmas_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("UseSoundtrackXmas", value and 1 or 0)
				if WG.music and WG.music.RefreshTrackList then
					WG.music.RefreshTrackList()
					init()
				end
			end,
		},
		{
			id = "soundtrackXmasPostEvent",
			parent = "soundtrackNew",
			group = "sound",
			category = types.basic,
			available = not holidays.xmas,
			name = BAR.I18N("ui.settings.option.soundtrackxmaspostevent"),
			type = "bool",
			value = Spring.GetConfigInt("UseSoundtrackXmasPostEvent", 0) == 1,
			description = BAR.I18N("ui.settings.option.soundtrackxmaspostevent_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("UseSoundtrackXmasPostEvent", value and 1 or 0)
				if WG.music and WG.music.RefreshTrackList then
					WG.music.RefreshTrackList()
					init()
				end
			end,
		},
		{
			id = "soundtrackCustom",
			group = "sound",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.soundtrackcustom"),
			type = "bool",
			value = Spring.GetConfigInt("UseSoundtrackCustom", 1) == 1,
			description = BAR.I18N("ui.settings.option.soundtrackcustom_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("UseSoundtrackCustom", value and 1 or 0)
				if WG.music and WG.music.RefreshTrackList then
					WG.music.RefreshTrackList()
					init()
				end
			end,
		},
		{
			id = "soundtrackInterruption",
			group = "sound",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.soundtrackinterruption"),
			type = "bool",
			value = Spring.GetConfigInt("UseSoundtrackInterruption", 1) == 1,
			description = BAR.I18N("ui.settings.option.soundtrackinterruption_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("UseSoundtrackInterruption", value and 1 or 0)
				if WG.music and WG.music.RefreshSettings then
					WG.music.RefreshSettings()
				end
			end,
		},
		{
			id = "soundtrackFades",
			group = "sound",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.soundtrackfades"),
			type = "bool",
			value = Spring.GetConfigInt("UseSoundtrackFades", 1) == 1,
			description = BAR.I18N("ui.settings.option.soundtrackfades_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("UseSoundtrackFades", value and 1 or 0)
				if WG.music and WG.music.RefreshSettings then
					WG.music.RefreshSettings()
				end
			end,
		},

		--{ id = "loadscreen_music", group = "sound", category = types.basic, name = Spring.I18N('ui.settings.option.loadscreen_music'), type = "bool", value = (Spring.GetConfigInt("music_loadscreen", 1) == 1), description = Spring.I18N('ui.settings.option.loadscreen_music_descr'),
		--  onchange = function(option, value)
		--	  Spring.SetConfigInt("music_loadscreen", (value and 1 or 0))
		--  end,
		--},

		{
			id = "notifications_set",
			group = "notif",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.notifications_set"),
			type = "select",
			options = {},
			value = 1,
			onchange = function(option, value)
				Spring.SetConfigString("voiceset", option.options[option.value])
				if widgetHandler.orderList.Notifications ~= nil then
					widgetHandler:DisableWidget("Notifications")
					widgetHandler:EnableWidget("Notifications")
					init()
				end
			end,
		},

		--{ id = "notifications_tutorial", group = "notif", name = Spring.I18N('ui.settings.option.notifications_tutorial'), category = types.basic, type = "bool", value = (WG['notifications'] ~= nil and WG['notifications'].getTutorial()), description = Spring.I18N('ui.settings.option.notifications_tutorial_descr'),
		--  onload = function(option)
		--	  loadWidgetData("Notifications", "notifications_tutorial", { 'tutorialMode' })
		--  end,
		--  onchange = function(option, value)
		--	  saveOptionValue('Notifications', 'notifications', 'setTutorial', { 'tutorialMode' }, value)
		--  end,
		--},
		{
			id = "notifications_messages",
			group = "notif",
			name = BAR.I18N("ui.settings.option.notifications_messages"),
			category = types.basic,
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.notifications_messages_descr"),
			widgetConfig = {
				"Notifications",
				"displayMessages",
				api = "notifications",
				get = "getMessages",
				set = "setMessages",
			},
		},
		{
			id = "notifications_spoken",
			group = "notif",
			name = BAR.I18N("ui.settings.option.notifications_spoken"),
			category = types.basic,
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.notifications_spoken_descr"),
			widgetConfig = { "Notifications", "spoken", api = "notifications", get = "getSpoken", set = "setSpoken" },
		},
		{
			id = "notifications_volume",
			group = "notif",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.notifications_volume"),
			type = "slider",
			min = 0.05,
			max = 1,
			step = 0.05,
			value = 0.7,
			description = BAR.I18N("ui.settings.option.notifications_volume_descr"),
			widgetConfig = { "Notifications", "globalVolume", api = "notifications", set = "setVolume" },
		},
		{
			id = "notifications_substitute",
			group = "notif",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.notifications_substitute"),
			type = "bool",
			value = Spring.GetConfigInt("NotificationsSubstitute", 0) == 1,
			description = BAR.I18N("ui.settings.option.notifications_substitute_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("NotificationsSubstitute", value and 1 or 0)
				widgetHandler:DisableWidget("Notifications")
				widgetHandler:EnableWidget("Notifications")
				init()
			end,
		},
		{
			id = "notifications_refresh",
			group = "notif",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.notifications_refresh"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.notifications_refresh_descr"),
			onchange = function(option, value)
				widgetHandler:DisableWidget("Notifications")
				widgetHandler:EnableWidget("Notifications")
				init()
			end,
		},

		{
			id = "label_notif_messages",
			group = "notif",
			name = BAR.I18N("ui.settings.option.label_messages"),
			category = types.basic,
		},

		-- CONTROL
		{
			id = "label_ui_hotkeys",
			group = "control",
			name = BAR.I18N("ui.settings.option.label_hotkeys"),
			category = types.basic,
		},

		{
			id = "keylayout",
			group = "control",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.keylayout"),
			type = "select",
			options = keyLayouts.layouts,
			value = 1,
			description = BAR.I18N("ui.settings.option.keylayout_descr"),
			onload = function(option)
				local keyLayout = Spring.GetConfigString("KeyboardLayout")

				if not keyLayout or keyLayout == "" then
					keyLayout = keyLayouts.layouts[1]
					Spring.SetConfigString("KeyboardLayout", keyLayouts.layouts[1])
				end

				local value = 1
				for i, v in ipairs(keyLayouts.layouts) do
					if v == keyLayout then
						value = i
						break
					end
				end

				option.value = value
			end,
			onchange = function(_, value)
				Spring.SetConfigString("KeyboardLayout", keyLayouts.layouts[value])
				if WG.bar_hotkeys and WG.bar_hotkeys.reloadBindings then
					WG.bar_hotkeys.reloadBindings()
				end
			end,
		},

		{
			id = "gridmenu",
			group = "control",
			category = types.basic,
			available = Spring.GetConfigString("KeybindingFile") == "uikeys.txt",
			name = BAR.I18N("ui.settings.option.gridmenu"),
			type = "bool",
			value = GetWidgetToggleValue("Grid menu"),
			description = BAR.I18N("ui.settings.option.gridmenu_descr"),
			onchange = function(option, value)
				if value then
					widgetHandler:DisableWidget("Build menu")
					widgetHandler:EnableWidget("Grid menu")
				else
					widgetHandler:DisableWidget("Grid menu")
					widgetHandler:EnableWidget("Build menu")
				end
				scheduleInit = true
			end,
		},
		{
			id = "gridmenu_alwaysreturn",
			group = "control",
			category = types.advanced,
			available = gridMenuOn,
			name = BAR.I18N("ui.settings.option.gridmenu_alwaysreturn"),
			type = "bool",
			value = (WG.gridmenu ~= nil and WG.gridmenu.getAlwaysReturn ~= nil and WG.gridmenu.getAlwaysReturn()),
			description = BAR.I18N("ui.settings.option.gridmenu_alwaysreturn_descr"),
			onchange = function(_, value)
				saveOptionValue("Grid menu", "gridmenu", "setAlwaysReturn", { "alwaysReturn" }, value)
			end,
		},
		{
			id = "gridmenu_autoselectfirst",
			group = "control",
			category = types.advanced,
			available = gridMenuOn,
			name = BAR.I18N("ui.settings.option.gridmenu_autoselectfirst"),
			type = "bool",
			value = (WG.gridmenu ~= nil and WG.gridmenu.getAutoSelectFirst ~= nil and WG.gridmenu.getAutoSelectFirst()),
			description = BAR.I18N("ui.settings.option.gridmenu_autoselectfirst_descr"),
			onchange = function(_, value)
				saveOptionValue("Grid menu", "gridmenu", "setAutoSelectFirst", { "autoSelectFirst" }, value)
			end,
		},
		{
			id = "gridmenu_labbuildmode",
			group = "control",
			category = types.advanced,
			available = gridMenuOn,
			name = BAR.I18N("ui.settings.option.gridmenu_labbuildmode"),
			type = "bool",
			value = (WG.gridmenu ~= nil and WG.gridmenu.getUseLabBuildMode ~= nil and WG.gridmenu.getUseLabBuildMode()),
			description = BAR.I18N("ui.settings.option.gridmenu_labbuildmode_descr"),
			onchange = function(_, value)
				saveOptionValue("Grid menu", "gridmenu", "setUseLabBuildMode", { "useLabBuildMode" }, value)
			end,
		},

		{
			id = "gridmenu_ctrlkeymodifier",
			group = "control",
			category = types.advanced,
			available = gridMenuOn,
			name = BAR.I18N("ui.settings.option.gridmenu_ctrlkeymodifier"),
			type = "slider",
			min = -20,
			max = 100,
			step = 1,
			value = (WG.gridmenu ~= nil and WG.gridmenu.getCtrlKeyModifier ~= nil and WG.gridmenu.getCtrlKeyModifier()),
			description = BAR.I18N("ui.settings.option.gridmenu_ctrlkeymodifier_descr"),
			onchange = function(_, value)
				saveOptionValue("Grid menu", "gridmenu", "setCtrlKeyModifier", { "ctrlKeyModifier" }, value)
			end,
		},
		{
			id = "gridmenu_shiftkeymodifier",
			group = "control",
			category = types.advanced,
			available = gridMenuOn,
			name = BAR.I18N("ui.settings.option.gridmenu_shiftkeymodifier"),
			type = "slider",
			min = -20,
			max = 100,
			step = 1,
			value = (
				WG.gridmenu ~= nil
				and WG.gridmenu.getShiftKeyModifier ~= nil
				and WG.gridmenu.getShiftKeyModifier()
			),
			description = BAR.I18N("ui.settings.option.gridmenu_shiftkeymodifier_descr"),
			onchange = function(_, value)
				saveOptionValue("Grid menu", "gridmenu", "setShiftKeyModifier", { "shiftKeyModifier" }, value)
			end,
		},

		{
			id = "label_ui_cursor",
			group = "control",
			name = BAR.I18N("ui.settings.option.label_cursor"),
			category = types.basic,
		},

		{
			id = "hwcursor",
			group = "control",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.hwcursor"),
			type = "bool",
			value = tonumber(Spring.GetConfigInt("HardwareCursor", 0) or 0) == 1,
			description = BAR.I18N("ui.settings.option.hwcursor_descr"),
			onchange = function(option, value)
				Spring.SendCommands("HardwareCursor " .. (value and 1 or 0))
				Spring.SetConfigInt("HardwareCursor", (value and 1 or 0))
			end,
		},
		{
			id = "setcamera_bugfix",
			group = "control",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.setcamera_bugfix"),
			type = "bool",
			value = Spring.GetConfigInt("SetCameraEveryFrame", 1) == 1,
			description = BAR.I18N("ui.settings.option.setcamera_bugfix_descr"),
			onload = function(option)
				WG.setcamera_bugfix = option.value
			end,
			onchange = function(option, value)
				WG.setcamera_bugfix = value
				Spring.SetConfigInt("SetCameraEveryFrame", value and 1 or 0)
			end,
		},
		{
			id = "cursorsize",
			group = "control",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.cursorsize"),
			type = "slider",
			min = 0.3,
			max = 1.7,
			step = 0.1,
			value = 1,
			description = BAR.I18N("ui.settings.option.cursorsize_descr"),
			onchange = function(option, value)
				if WG.cursors then
					WG.cursors.setsizemult(value)
				end
			end,
		},

		{
			id = "containmouse",
			group = "control",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.containmouse"),
			type = "bool",
			value = Spring.GetConfigInt("grabinput", 1) == 1,
			description = BAR.I18N("ui.settings.option.containmouse_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("grabinput", (value and 1 or 0))
				updateGrabinput()
			end,
		},

		{
			id = "doubleclicktime",
			group = "control",
			category = types.advanced,
			restart = not Engine.FeatureSupport.liveConfigChanges,
			name = BAR.I18N("ui.settings.option.doubleclicktime"),
			type = "slider",
			min = 150,
			max = 400,
			step = 10,
			value = 200,
			description = BAR.I18N("ui.settings.option.doubleclicktime_descr"),
			configInt = "DoubleClickTime",
		},

		{
			id = "dragthreshold",
			group = "control",
			category = types.advanced,
			restart = false,
			name = BAR.I18N("ui.settings.option.dragthreshold"),
			type = "slider",
			min = 4,
			max = 50,
			step = 1,
			value = Spring.GetConfigInt("MouseDragSelectionThreshold", 4),
			description = BAR.I18N("ui.settings.option.dragthreshold_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("MouseDragSelectionThreshold", value)
				Spring.SetConfigInt("MouseDragCircleCommandThreshold", value)
				Spring.SetConfigInt("MouseDragBoxCommandThreshold", value + 12)
				Spring.SetConfigInt("MouseDragFrontCommandThreshold", value + 26)
			end,
		},

		{
			id = "label_ui_camera",
			group = "control",
			name = BAR.I18N("ui.settings.option.label_camera"),
			category = types.basic,
		},

		{
			id = "middleclicktoggle",
			group = "control",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.middleclicktoggle"),
			type = "bool",
			value = (Spring.GetConfigFloat("MouseDragScrollThreshold", 0.3) ~= 0),
			description = BAR.I18N("ui.settings.option.middleclicktoggle_descr"),
			onchange = function(option, value)
				Spring.SetConfigFloat("MouseDragScrollThreshold", (value and 0.3 or 0))
			end,
		},

		{
			id = "screenedgemove",
			group = "control",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.screenedgemove"),
			type = "bool",
			value = tonumber(Spring.GetConfigInt("FullscreenEdgeMove", 1) or 1) == 1,
			description = BAR.I18N("ui.settings.option.screenedgemove_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("FullscreenEdgeMove", (value and 1 or 0))
				Spring.SetConfigInt("WindowedEdgeMove", (value and 1 or 0))
				if value then
					Spring.SetConfigFloat("EdgeMoveWidth", edgeMoveWidth)
				else
					Spring.SetConfigFloat("EdgeMoveWidth", 0)
				end
			end,
		},
		{
			id = "screenedgemovewidth",
			parent = "screenedgemove",
			group = "control",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.screenedgemovewidth"),
			type = "slider",
			min = 0,
			max = 0.1,
			step = 0.01,
			value = edgeMoveWidth,
			description = BAR.I18N("ui.settings.option.screenedgemovewidth_descr"),
			onchange = function(option, value)
				edgeMoveWidth = value
				Spring.SetConfigFloat("EdgeMoveWidth", value)
			end,
		},
		{
			id = "screenedgemovedynamic",
			parent = "screenedgemove",
			group = "control",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.screenedgemovedynamic"),
			type = "bool",
			value = true,
			description = BAR.I18N("ui.settings.option.screenedgemovedynamic_descr"),
			configInt = "EdgeMoveDynamic",
		},

		{
			id = "camera",
			group = "control",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.camera"),
			type = "select",
			options = {
				BAR.I18N("ui.settings.option.select_firstperson"),
				BAR.I18N("ui.settings.option.select_overhead"),
				BAR.I18N("ui.settings.option.select_springcam"),
				BAR.I18N("ui.settings.option.select_rotoverhead"),
				BAR.I18N("ui.settings.option.select_free"),
			},
			value = (tonumber((Spring.GetConfigInt("CamMode", 1) + 1) or 2)),
			onchange = function(option, value)
				Spring.SetConfigInt("CamMode", (value - 1))
				if value == 1 then
					Spring.SendCommands("viewfps")
				elseif value == 2 then
					Spring.SendCommands("viewta")
				elseif value == 3 then
					Spring.SendCommands("viewspring")
				elseif value == 4 then
					Spring.SendCommands("viewrot")
				elseif value == 5 then
					Spring.SendCommands("viewfree")
				end
				init()
			end,
		},
		{
			id = "springcamheightmode",
			parent = "camera",
			group = "control",
			category = types.advanced,
			available = camMode == 2,
			name = BAR.I18N("ui.settings.option.springcamheightmode"),
			type = "select",
			options = {
				BAR.I18N("ui.settings.option.select_constant"),
				BAR.I18N("ui.settings.option.select_terrain"),
				BAR.I18N("ui.settings.option.select_smooth"),
			},
			value = Spring.GetConfigInt("CamSpringTrackMapHeightMode", 0) + 1,
			description = BAR.I18N("ui.settings.option.springcamheightmode_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("CamSpringTrackMapHeightMode", value - 1)
			end,
		},
		{
			id = "mincamheight",
			parent = "camera",
			group = "control",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.mincamheight"),
			type = "slider",
			min = 0,
			max = 1500,
			step = 1,
			value = Spring.GetConfigInt("CamSpringMinZoomDistance", 0),
			description = BAR.I18N("ui.settings.option.mincamheight_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("CamSpringMinZoomDistance", value)
				Spring.SetConfigInt("OverheadMinZoomDistance", value)
			end,
		},
		{
			id = "camerashake",
			parent = "camera",
			group = "control",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.camerashake"),
			type = "slider",
			min = 0,
			max = 200,
			step = 10,
			value = 80,
			description = BAR.I18N("ui.settings.option.camerashake_descr"),
			onload = function(option)
				loadWidgetData("CameraShake", "camerashake", { "powerScale" })
				if option.value > 0 then
					widgetHandler:EnableWidget("CameraShake")
				end
			end,
			onchange = function(option, value)
				saveOptionValue("CameraShake", "camerashake", "setStrength", { "powerScale" }, value)
				if value > 0 then
					widgetHandler:EnableWidget("CameraShake")
				end
			end,
		},
		--{ id = "camerasmoothing", group = "control", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.camerasmoothing'), type = "bool", value = (tonumber(Spring.GetConfigInt("CameraSmoothing", 0)) == 1), description = "",
		--  onload = function(option)
		--  end,
		--  onchange = function(option, value)
		--	  Spring.SetConfigInt("CameraSmoothing", (value and 1 or 0))
		--	  if value then
		--		  Spring.SendCommands("set CamFrameTimeCorrection 1")
		--		  Spring.SendCommands("set SmoothTimeOffset 2")
		--		else
		--		  Spring.SendCommands("set CamFrameTimeCorrection 0")
		--		  Spring.SendCommands("set SmoothTimeOffset 0")
		--	  end
		--  end,
		--},
		{
			id = "smoothingmode",
			parent = "camera",
			group = "control",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.smoothingmode"),
			type = "select",
			options = {
				BAR.I18N("ui.settings.option.smoothing_exponential"),
				BAR.I18N("ui.settings.option.smoothing_spring"),
			},
			value = (Spring.GetConfigInt("CamTransitionMode", 1) + 1),
			onchange = function(option, value)
				Spring.SetConfigInt("CamTransitionMode", (value - 1))
			end,
		},
		{
			id = "camerasmoothness",
			parent = "camera",
			group = "control",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.camerasmoothness"),
			type = "slider",
			min = 0.04,
			max = 2,
			step = 0.01,
			value = cameraTransitionTime,
			description = BAR.I18N("ui.settings.option.camerasmoothness_descr"),
			onchange = function(option, value)
				cameraTransitionTime = value
				local halfLife = value
				if halfLife <= 1 then
					halfLife = halfLife * 200
				else
					halfLife = halfLife * 600 - 400
				end
				Spring.SetConfigFloat("CamSpringHalflife", halfLife)
			end,
		},
		{
			id = "camerapanspeed",
			parent = "camera",
			group = "control",
			category = types.basic,
			available = camMode == 1, -- only the overhead camera reads MiddleClickScrollSpeed
			name = BAR.I18N("ui.settings.option.camerapanspeed"),
			type = "slider",
			min = -0.01,
			max = -0.00195,
			step = 0.0001,
			value = 0.0035,
			description = BAR.I18N("ui.settings.option.camerapanspeed_descr"),
			configFloat = "MiddleClickScrollSpeed",
		},
		{
			id = "cameramovespeed",
			parent = "camera",
			group = "control",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.cameramovespeed"),
			type = "slider",
			min = 0,
			max = 100,
			step = 1,
			value = Spring.GetConfigInt("CamSpringScrollSpeed", 10),
			description = BAR.I18N("ui.settings.option.cameramovespeed_descr"),
			onchange = function(option, value)
				--cameraPanTransitionTime = value
				Spring.SetConfigInt("FPSScrollSpeed", value) -- spring default: 10
				Spring.SetConfigInt("OverheadScrollSpeed", value) -- spring default: 10
				Spring.SetConfigInt("RotOverheadScrollSpeed", value) -- spring default: 10
				Spring.SetConfigFloat("CamFreeScrollSpeed", value * 50) -- spring default: 500
				Spring.SetConfigInt("CamSpringScrollSpeed", value) -- spring default: 10
			end,
		},
		{
			id = "scrollspeed",
			parent = "camera",
			group = "control",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.scrollspeed"),
			type = "slider",
			min = 1,
			max = 50,
			step = 1,
			value = math.abs(tonumber(Spring.GetConfigInt("ScrollWheelSpeed", 1) or 25)),
			description = "",
			onchange = function(option, value)
				if getOption("scrollinverse") and getOption("scrollinverse").value then
					Spring.SetConfigInt("ScrollWheelSpeed", -value)
				else
					Spring.SetConfigInt("ScrollWheelSpeed", value)
				end
			end,
		},
		{
			id = "scrollinverse",
			parent = "camera",
			group = "control",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.scrollinverse"),
			type = "bool",
			value = (tonumber(Spring.GetConfigInt("ScrollWheelSpeed", 1) or 25) < 0),
			description = "",
			onchange = function(option, value)
				if getOption("scrollspeed") then
					if value then
						Spring.SetConfigInt("ScrollWheelSpeed", -getOption("scrollspeed").value)
					else
						Spring.SetConfigInt("ScrollWheelSpeed", getOption("scrollspeed").value)
					end
				end
			end,
		},
		{
			id = "zoomtocursor",
			parent = "camera",
			group = "control",
			category = types.advanced,
			available = camMode == 2,
			name = BAR.I18N("ui.settings.option.zoomtocursor"),
			type = "bool",
			value = true,
			description = "",
			configInt = "CamSpringZoomInToMousePos",
		},
		{
			id = "zoomfromcursor",
			parent = "camera",
			group = "control",
			category = types.advanced,
			available = camMode == 2,
			name = BAR.I18N("ui.settings.option.zoomfromcursor"),
			type = "bool",
			value = false,
			description = "",
			configInt = "CamSpringZoomOutFromMousePos",
		},
		{
			id = "invertmouse",
			parent = "camera",
			group = "control",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.invertmouse"),
			type = "bool",
			value = false,
			description = "",
			configInt = "InvertMouse",
		},
		{
			id = "scrolltoggleoverview",
			parent = "camera",
			group = "control",
			category = types.advanced,
			widget = "Scrolldown Toggleoverview",
			name = BAR.I18N("ui.settings.option.scrolltoggleoverview"),
			type = "bool",
			value = GetWidgetToggleValue("Scrolldown Toggleoverview"),
			description = BAR.I18N("ui.settings.option.scrolltoggleoverview_descr"),
		},

		{
			id = "camoverviewrestore",
			parent = "camera",
			group = "control",
			category = types.advanced,
			widget = "Overview Camera Keep Position",
			name = BAR.I18N("ui.settings.option.camoverviewrestore"),
			type = "bool",
			value = GetWidgetToggleValue("Overview Camera Keep Position"),
			description = BAR.I18N("ui.settings.option.camoverviewrestore_descr"),
		},

		{
			id = "lockcamera_transitiontime",
			group = "control",
			category = types.advanced,
			available = WG.lockcamera ~= nil, -- these act while watching a player's camera
			prefix = BAR.I18N("ui.settings.option.lockcamera"),
			name = BAR.I18N("ui.settings.option.lockcamera_transitiontime"),
			type = "slider",
			min = 0.5,
			max = 1.7,
			step = 0.01,
			description = BAR.I18N("ui.settings.option.lockcamera_transitiontime_descr"),
			widgetConfig = {
				"Lockcamera",
				"transitionTime",
				api = "lockcamera",
				get = "GetTransitionTime",
				set = "SetTransitionTime",
			},
		},

		{
			id = "allyselunits_select",
			parent = "lockcamera_transitiontime",
			group = "control",
			category = types.advanced,
			available = WG.lockcamera ~= nil, -- these act while watching a player's camera
			name = BAR.I18N("ui.settings.option.allyselunits_select"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.allyselunits_select_descr"),
			widgetConfig = {
				"Ally Selected Units",
				"selectPlayerUnits",
				api = "allyselectedunits",
				get = "getSelectPlayerUnits",
				set = "setSelectPlayerUnits",
			},
		},
		{
			id = "lockcamera_hideenemies",
			parent = "lockcamera_transitiontime",
			group = "control",
			category = types.advanced,
			available = WG.lockcamera ~= nil, -- these act while watching a player's camera
			name = BAR.I18N("ui.settings.option.lockcamera_hideenemies"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.lockcamera_hideenemies_descr"),
			widgetConfig = {
				"Lockcamera",
				"lockcameraHideEnemies",
				api = "lockcamera",
				get = "GetHideEnemies",
				set = "SetHideEnemies",
			},
		},
		{
			id = "lockcamera_los",
			parent = "lockcamera_transitiontime",
			group = "control",
			category = types.advanced,
			available = WG.lockcamera ~= nil, -- these act while watching a player's camera
			name = BAR.I18N("ui.settings.option.lockcamera_los"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.lockcamera_los_descr"),
			widgetConfig = { "Lockcamera", "lockcameraLos", api = "lockcamera", get = "GetLos", set = "SetLos" },
		},

		{
			id = "label_ui_command",
			group = "control",
			name = BAR.I18N("ui.settings.option.label_commands"),
			category = types.advanced,
		},
		{
			id = "drag_multicommand_shift",
			parent = "label_ui_command",
			group = "control",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.drag_multicommand_shift"),
			type = "bool",
			value = (WG.customformations ~= nil and WG.customformations.getRepeatForSingleUnit()),
			description = BAR.I18N("ui.settings.option.drag_multicommand_shift_descr"),
			onchange = function(option, value)
				saveOptionValue(
					"CustomFormations2",
					"customformations",
					"setRepeatForSingleUnit",
					{ "repeatForSingleUnit" },
					value
				)
			end,
		},

		-- INTERFACE
		{
			id = "label_ui_interface",
			group = "ui",
			name = BAR.I18N("ui.settings.option.label_interface"),
			category = types.basic,
		},
		{
			id = "language",
			group = "ui",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.language"),
			type = "select",
			options = languageNames,
			value = languageCodes[BAR.I18N.getLocale()],
			onchange = function(option, value)
				local language = languageCodes[value]
				WG.language.setLanguage(language)
				if widgetHandler.orderList.Notifications ~= nil then
					widgetHandler:DisableWidget("Notifications")
					widgetHandler:EnableWidget("Notifications")
					init()
				end
			end,
		},
		{
			id = "language_english_unit_names",
			parent = "language",
			group = "ui",
			category = types.basic,
			available = BAR.I18N.getLocale() ~= "en",
			name = BAR.I18N("ui.settings.option.language_english_unit_names"),
			type = "bool",
			value = Spring.GetConfigInt("language_english_unit_names", 0) == 1,
			onchange = function(option, value)
				WG.language.setEnglishUnitNames(value)
			end,
		},
		{
			id = "uiscale",
			group = "ui",
			category = types.basic,
			prefix = BAR.I18N("ui.settings.option.interface"),
			name = BAR.I18N("ui.settings.option.uiscale"),
			type = "slider",
			min = 0.8,
			max = 1.3,
			step = 0.01,
			value = Spring.GetConfigFloat("ui_scale", 1),
			description = "",
			onchange = function(option, value, force)
				if force then
					Spring.SetConfigFloat("ui_scale", value)
					Spring.SendCommands("luarules reloadluaui")
				else
					sceduleOptionApply = { os.clock() + 1.5, "uiscale" }
				end
			end,
		},
		{
			id = "guiopacity",
			parent = "uiscale",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.guiopacity"),
			type = "slider",
			min = 0.3,
			max = 1,
			step = 0.01,
			value = Spring.GetConfigFloat("ui_opacity", 0.7),
			description = "",
			onchange = function(option, value, force)
				Spring.SetConfigFloat("ui_opacity", value)
				ui_opacity = Spring.GetConfigFloat("ui_opacity", 0.7)
				forceUpdate = true

				if force then
					Spring.SetConfigFloat("ui_opacity", value)
					Spring.SendCommands("luarules reloadluaui")
				else
					sceduleOptionApply = { os.clock() + 1.5, "guiopacity" }
				end
			end,
		},
		{
			id = "guitilescale",
			parent = "uiscale",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.guitilescale"),
			type = "slider",
			min = 4,
			max = 40,
			step = 1,
			value = Spring.GetConfigFloat("ui_tilescale", 7),
			description = "",
			onchange = function(option, value, force)
				if force then
					Spring.SetConfigFloat("ui_tilescale", value)
					Spring.SendCommands("luarules reloadluaui")
				else
					sceduleOptionApply = { os.clock() + 1.5, "guitilescale" }
				end
			end,
		},
		{
			id = "guitileopacity",
			parent = "guitilescale",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.guitileopacity"),
			type = "slider",
			min = 0,
			max = 0.03,
			step = 0.001,
			value = Spring.GetConfigFloat("ui_tileopacity", 0.014),
			description = "",
			onchange = function(option, value, force)
				if force then
					Spring.SetConfigFloat("ui_tileopacity", value)
					Spring.SendCommands("luarules reloadluaui")
				else
					sceduleOptionApply = { os.clock() + 1.5, "guitileopacity" }
				end
			end,
		},

		{
			id = "guishader",
			parent = "uiscale",
			group = "ui",
			category = types.basic,
			widget = "GUI Shader",
			name = BAR.I18N("ui.settings.option.guishader"),
			type = "bool",
			value = GetWidgetToggleValue("GUI Shader"),
		},

		{
			id = "minimap_maxheight",
			group = "ui",
			category = types.advanced,
			prefix = BAR.I18N("ui.settings.option.minimap"),
			name = BAR.I18N("ui.settings.option.minimap_maxheight"),
			type = "slider",
			min = 0.2,
			max = 0.4,
			step = 0.01,
			value = Spring.GetConfigFloat("MinimapMaxHeight", 0.32),
			description = BAR.I18N("ui.settings.option.minimap_maxheight_descr"),
			onchange = function(option, value)
				Spring.SetConfigFloat("MinimapMaxHeight", value)
				if WG.minimap and WG.minimap.setMaxHeight then
					WG.minimap.setMaxHeight(value)
				end
			end,
		},
		{
			id = "minimapleftclick",
			parent = "minimap_maxheight",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.minimapleftclick"),
			type = "bool",
			value = Spring.GetConfigInt("MinimapLeftClickMove", 1) == 1,
			description = BAR.I18N("ui.settings.option.minimapleftclick_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("MinimapLeftClickMove", value and 1 or 0)
				if WG.minimap and WG.minimap.setLeftClickMove then
					WG.minimap.setLeftClickMove(value)
				end
			end,
		},
		{
			id = "minimapiconsize",
			parent = "minimap_maxheight",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.minimapiconsize"),
			type = "slider",
			min = 2,
			max = 5,
			step = 0.25,
			value = tonumber(Spring.GetConfigFloat("MinimapIconScale", 3.5) or 1),
			description = "",
			onchange = function(option, value)
				Spring.SetConfigFloat("MinimapIconScale", value)
				Spring.SendCommands("minimap unitsize " .. value) -- spring won't remember what you set with '/minimap iconssize #'
				if WG.minimap and WG.minimap.setBaseIconScale then
					WG.minimap.setBaseIconScale(value)
				end
			end,
		},
		{
			id = "minimap_minimized",
			parent = "minimap_maxheight",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.minimapminimized"),
			type = "bool",
			value = Spring.GetConfigInt("MinimapMinimize", 0) == 1,
			description = BAR.I18N("ui.settings.option.minimapminimized_descr"),
			onchange = function(option, value)
				Spring.SendCommands("minimap minimize " .. (value and "1" or "0"))
				Spring.SetConfigInt("MinimapMinimize", (value and "1" or "0"))
			end,
		},
		{
			id = "minimaprotation",
			parent = "minimap_maxheight",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.minimaprotation"),
			type = "select",
			options = {
				BAR.I18N("ui.settings.option.minimaprotation_none"),
				BAR.I18N("ui.settings.option.minimaprotation_autoflip"),
				BAR.I18N("ui.settings.option.minimaprotation_autorotate"),
				BAR.I18N("ui.settings.option.minimaprotation_autolandscape"),
			},
			description = BAR.I18N("ui.settings.option.minimaprotation_descr"),
			onload = function(option)
				loadWidgetData("Minimap Rotation Manager", "minimaprotation", { "mode" })
				if option.value == nil then -- first load to migrate from old behavior smoothly, might wanna remove it later
					option.value = Spring.GetConfigInt("MiniMapCanFlip", 0) + 1
				end
			end,
			onchange = function(option, value)
				if WG.minimaprotationmanager ~= nil and WG.minimaprotationmanager.setMode ~= nil then
					saveOptionValue("Minimap Rotation Manager", "minimaprotationmanager", "setMode", { "mode" }, value)
				else
					widgetHandler:EnableWidget("Minimap Rotation Manager") -- Widget has auto sync
				end
			end,
		},
		{
			id = "minimappip",
			parent = "minimap_maxheight",
			group = "ui",
			category = types.advanced,
			widget = "Picture-in-Picture Minimap",
			name = BAR.I18N("ui.settings.option.minimappip"),
			type = "bool",
			value = GetWidgetToggleValue("Picture-in-Picture Minimap"),
			description = BAR.I18N("ui.settings.option.minimappip_descr"),
		},
		{
			id = "pip_altkeyzoom",
			parent = "minimappip",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.pip_altkeyzoom"),
			type = "bool",
			value = Spring.GetConfigInt("PipAltKeyRequiredForZoom", 1) == 1,
			description = BAR.I18N("ui.settings.option.pip_altkeyzoom_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("PipAltKeyRequiredForZoom", value and 1 or 0)
				for _, n in ipairs({ 0, 1, 2, 3, 4 }) do
					if WG["pip" .. n] and WG["pip" .. n].setAltKeyRequiredForZoom then
						WG["pip" .. n].setAltKeyRequiredForZoom(value)
					end
				end
			end,
		},

		{
			id = "pip_commandfx",
			parent = "minimappip",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.pip_commandfx"),
			type = "bool",
			value = Spring.GetConfigInt("PipDrawCommandFX", 1) == 1,
			description = BAR.I18N("ui.settings.option.pip_commandfx_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("PipDrawCommandFX", value and 1 or 0)
				for _, n in ipairs({ 0, 1, 2, 3, 4 }) do
					if WG["pip" .. n] and WG["pip" .. n].setDrawCommandFX then
						WG["pip" .. n].setDrawCommandFX(value)
					end
				end
			end,
		},
		{
			id = "pip_nanostreams",
			parent = "minimappip",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.pip_nanostreams"),
			type = "bool",
			value = Spring.GetConfigInt("PipDrawNanoStreams", 1) == 1,
			description = BAR.I18N("ui.settings.option.pip_nanostreams_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("PipDrawNanoStreams", value and 1 or 0)
				for _, n in ipairs({ 0, 1, 2, 3, 4 }) do
					if WG["pip" .. n] and WG["pip" .. n].setDrawNanoStreams then
						WG["pip" .. n].setDrawNanoStreams(value)
					end
				end
			end,
		},
		{
			id = "pip_nanostream_usage",
			parent = "minimappip",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.pip_nanostream_usage"),
			type = "bool",
			value = Spring.GetConfigInt("PipNanoStreamReflectUsage", 1) == 1,
			description = BAR.I18N("ui.settings.option.pip_nanostream_usage_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("PipNanoStreamReflectUsage", value and 1 or 0)
				for _, n in ipairs({ 0, 1, 2, 3, 4 }) do
					if WG["pip" .. n] and WG["pip" .. n].setNanoStreamReflectUsage then
						WG["pip" .. n].setNanoStreamReflectUsage(value)
					end
				end
			end,
		},
		{
			id = "pip_mapdrawings",
			parent = "minimappip",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.pip_mapdrawings"),
			type = "bool",
			value = Spring.GetConfigInt("PipShowMapDrawings", 1) == 1,
			description = BAR.I18N("ui.settings.option.pip_mapdrawings_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("PipShowMapDrawings", value and 1 or 0)
				for _, n in ipairs({ 0, 1, 2, 3, 4 }) do
					if WG["pip" .. n] and WG["pip" .. n].setShowMapDrawings then
						WG["pip" .. n].setShowMapDrawings(value)
					end
				end
			end,
		},
		{
			id = "pip_mapdrawing_duration",
			parent = "minimappip",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.pip_mapdrawing_duration"),
			type = "slider",
			min = 1,
			max = 60,
			step = 1,
			value = Spring.GetConfigFloat("PipMapDrawingDuration", 15),
			description = BAR.I18N("ui.settings.option.pip_mapdrawing_duration_descr"),
			onchange = function(option, value)
				Spring.SetConfigFloat("PipMapDrawingDuration", value)
				for _, n in ipairs({ 0, 1, 2, 3, 4 }) do
					if WG["pip" .. n] and WG["pip" .. n].setMapDrawingDuration then
						WG["pip" .. n].setMapDrawingDuration(value)
					end
				end
			end,
		},
		{
			id = "pip_history",
			parent = "minimappip",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.pip_history"),
			type = "bool",
			value = true,
			description = BAR.I18N("ui.settings.option.pip_history_descr"),
			onload = function(option)
				for _, n in ipairs({ 0, 1, 2, 3, 4 }) do
					if WG["pip" .. n] and WG["pip" .. n].getHistoryEnabled then
						option.value = WG["pip" .. n].getHistoryEnabled()
						break
					end
				end
			end,
			onchange = function(option, value)
				for _, n in ipairs({ 0, 1, 2, 3, 4 }) do
					if WG["pip" .. n] and WG["pip" .. n].setHistoryEnabled then
						WG["pip" .. n].setHistoryEnabled(value)
					end
				end
			end,
		},
		-- { id = "minimap_engine_fallback", group = "ui", category = types.advanced, name = widgetOptionColor .. "      " .. Spring.I18N('ui.settings.option.pip_minimap_engine_fallback'), type = "bool", value = false, description = Spring.I18N('ui.settings.option.pip_minimap_engine_fallback_descr'),
		--   onload = function(option)
		-- 	  if WG['minimap'] and WG['minimap'].getEngineMinimapFallback then
		-- 		  getOption('minimap_engine_fallback').value = WG['minimap'].getEngineMinimapFallback()
		-- 	  end
		--   end,
		--   onchange = function(option, value)
		-- 	  if WG['minimap'] and WG['minimap'].setEngineMinimapFallback then
		-- 		  WG['minimap'].setEngineMinimapFallback(value)
		-- 	  end
		--   end,
		-- },
		{
			id = "pip_engine_fallback_threshold",
			parent = "minimappip",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.pip_engine_fallback_threshold"),
			type = "slider",
			min = 1500,
			max = 5000,
			step = 100,
			value = 4000,
			description = BAR.I18N("ui.settings.option.pip_engine_fallback_threshold_descr"),
			onload = function(option)
				if WG.minimap and WG.minimap.getEngineMinimapFallbackThreshold then
					option.value = WG.minimap.getEngineMinimapFallbackThreshold()
				end
			end,
			onchange = function(option, value)
				if WG.minimap and WG.minimap.setEngineMinimapFallbackThreshold then
					WG.minimap.setEngineMinimapFallbackThreshold(value)
				end
			end,
		},

		{
			id = "pip",
			group = "ui",
			category = types.advanced,
			widget = "Picture-in-Picture",
			name = BAR.I18N("ui.settings.option.pip"),
			type = "bool",
			value = GetWidgetToggleValue("Picture-in-Picture"),
			description = BAR.I18N("ui.settings.option.pip_descr"),
		},
		{
			id = "pip2",
			group = "ui",
			category = types.advanced,
			widget = "Picture-in-Picture 2",
			name = BAR.I18N("ui.settings.option.pip2"),
			type = "bool",
			value = GetWidgetToggleValue("Picture-in-Picture 2"),
			description = BAR.I18N("ui.settings.option.pip2_descr"),
		},

		{
			id = "buildmenu_bottom",
			group = "ui",
			category = types.basic,
			prefix = BAR.I18N("ui.settings.option.buildmenu"),
			name = BAR.I18N("ui.settings.option.buildmenu_bottom"),
			type = "bool",
			value = (
				WG.buildmenu ~= nil
				and WG.buildmenu.getBottomPosition ~= nil
				and WG.buildmenu.getBottomPosition()
			),
			description = BAR.I18N("ui.settings.option.buildmenu_bottom_descr"),
			onchange = function(option, value)
				saveOptionValue("Build menu", "buildmenu", "setBottomPosition", { "stickToBottom" }, value)
				saveOptionValue("Grid menu", "buildmenu", "setBottomPosition", { "stickToBottom" }, value)
			end,
		},
		{
			id = "buildmenu_maxposy",
			parent = "buildmenu_bottom",
			group = "ui",
			category = types.advanced,
			available = not gridMenuOn, -- the grid menu has a fixed height
			name = BAR.I18N("ui.settings.option.buildmenu_maxposy"),
			type = "slider",
			min = 0.66,
			max = 0.88,
			step = 0.01,
			value = 0.74,
			description = BAR.I18N("ui.settings.option.buildmenu_maxposy_descr"),
			widgetConfig = { "Build menu", "maxPosY", api = "buildmenu", set = "setMaxPosY" },
		},
		{
			id = "buildmenu_alwaysshow",
			parent = "buildmenu_bottom",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.buildmenu_alwaysshow"),
			type = "bool",
			value = (WG.buildmenu ~= nil and WG.buildmenu.getAlwaysShow ~= nil and WG.buildmenu.getAlwaysShow()),
			description = BAR.I18N("ui.settings.option.buildmenu_alwaysshow_descr"),
			onchange = function(option, value)
				saveOptionValue("Build menu", "buildmenu", "setAlwaysShow", { "alwaysShow" }, value)
				saveOptionValue("Grid menu", "buildmenu", "setAlwaysShow", { "alwaysShow" }, value)
			end,
		},
		{
			id = "buildmenu_prices",
			parent = "buildmenu_bottom",
			group = "ui",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.buildmenu_prices"),
			type = "bool",
			value = (WG.buildmenu ~= nil and WG.buildmenu.getShowPrice ~= nil and WG.buildmenu.getShowPrice()),
			description = BAR.I18N("ui.settings.option.buildmenu_prices_descr"),
			onchange = function(option, value)
				saveOptionValue("Build menu", "buildmenu", "setShowPrice", { "showPrice" }, value)
				saveOptionValue("Grid menu", "buildmenu", "setShowPrice", { "showPrice" }, value)
			end,
		},
		{
			id = "buildmenu_groupicon",
			parent = "buildmenu_bottom",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.buildmenu_groupicon"),
			type = "bool",
			value = (WG.buildmenu ~= nil and WG.buildmenu.getShowGroupIcon ~= nil and WG.buildmenu.getShowGroupIcon()),
			description = BAR.I18N("ui.settings.option.buildmenu_groupicon_descr"),
			onchange = function(option, value)
				saveOptionValue("Build menu", "buildmenu", "setShowGroupIcon", { "showGroupIcon" }, value)
				saveOptionValue("Grid menu", "buildmenu", "setShowGroupIcon", { "showGroupIcon" }, value)
			end,
		},
		{
			id = "buildmenu_radaricon",
			parent = "buildmenu_bottom",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.buildmenu_radaricon"),
			type = "bool",
			value = (WG.buildmenu ~= nil and WG.buildmenu.getShowRadarIcon ~= nil and WG.buildmenu.getShowRadarIcon()),
			description = BAR.I18N("ui.settings.option.buildmenu_radaricon_descr"),
			onchange = function(option, value)
				saveOptionValue("Build menu", "buildmenu", "setShowRadarIcon", { "showRadarIcon" }, value)
				saveOptionValue("Grid menu", "buildmenu", "setShowRadarIcon", { "showRadarIcon" }, value)
			end,
		},

		{
			id = "ordermenu_bottompos",
			group = "ui",
			category = types.basic,
			prefix = BAR.I18N("ui.settings.option.ordermenu"),
			name = BAR.I18N("ui.settings.option.ordermenu_bottompos"),
			type = "bool",
			value = (
				WG.ordermenu ~= nil
				and WG.ordermenu.getBottomPosition ~= nil
				and WG.ordermenu.getBottomPosition()
			),
			description = BAR.I18N("ui.settings.option.ordermenu_bottompos_descr"),
			onchange = function(option, value)
				saveOptionValue("Order menu", "ordermenu", "setBottomPosition", { "stickToBottom" }, value)
			end,
		},
		{
			id = "ordermenu_colorize",
			parent = "ordermenu_bottompos",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.ordermenu_colorize"),
			type = "slider",
			min = 0,
			max = 1,
			step = 0.1,
			value = 0.5,
			description = "",
			widgetConfig = { "Order menu", "colorize", api = "ordermenu", set = "setColorize" },
		},
		{
			id = "ordermenu_alwaysshow",
			parent = "ordermenu_bottompos",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.ordermenu_alwaysshow"),
			type = "bool",
			value = (WG.ordermenu ~= nil and WG.ordermenu.getAlwaysShow ~= nil and WG.ordermenu.getAlwaysShow()),
			description = BAR.I18N("ui.settings.option.ordermenu_alwaysshow_descr"),
			onchange = function(option, value)
				saveOptionValue("Order menu", "ordermenu", "setAlwaysShow", { "alwaysShow" }, value)
			end,
		},
		{
			id = "ordermenu_hideset",
			parent = "ordermenu_bottompos",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.ordermenu_hideset"),
			type = "bool",
			value = (
				WG.ordermenu ~= nil
				and WG.ordermenu.getDisabledCmd ~= nil
				and WG.ordermenu.getDisabledCmd("Move")
			),
			description = BAR.I18N("ui.settings.option.ordermenu_hideset_descr"),
			onchange = function(option, value)
				local cmds =
					{ "Move", "Stop", "Attack", "Patrol", "Fight", "Wait", "Guard", "Reclaim", "Repair", "ManualFire" }
				for k, cmd in pairs(cmds) do
					saveOptionValue(
						"Order menu",
						"ordermenu",
						"setDisabledCmd",
						{ "disabledCmd", cmd },
						value,
						{ cmd, value }
					)
				end
			end,
		},

		{
			id = "info_buildlist",
			group = "ui",
			category = types.advanced,
			prefix = BAR.I18N("ui.settings.option.info"),
			name = BAR.I18N("ui.settings.option.info_buildlist"),
			type = "bool",
			value = (WG.info and WG.info.getShowBuilderBuildlist ~= nil and WG.info.getShowBuilderBuildlist()),
			description = BAR.I18N("ui.settings.option.info_buildlist_descr"),
			onchange = function(option, value)
				saveOptionValue("Info", "info", "setShowBuilderBuildlist", { "showBuilderBuildlist" }, value)
			end,
		},
		{
			id = "info_mappos",
			parent = "info_buildlist",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.info_mappos"),
			type = "bool",
			value = (WG.info and WG.info.getDisplayMapPosition ~= nil and WG.info.getDisplayMapPosition()),
			description = BAR.I18N("ui.settings.option.info_mappos_descr"),
			onchange = function(option, value)
				saveOptionValue("Info", "info", "setDisplayMapPosition", { "displayMapPosition" }, value)
			end,
		},
		{
			id = "info_alwaysshow",
			parent = "info_buildlist",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.info_alwaysshow"),
			type = "bool",
			value = (WG.info ~= nil and WG.info.getAlwaysShow ~= nil and WG.info.getAlwaysShow()),
			onchange = function(option, value)
				saveOptionValue("Info", "info", "setAlwaysShow", { "alwaysShow" }, value)
			end,
		},

		{
			id = "advplayerlist_country",
			group = "ui",
			category = types.basic,
			prefix = BAR.I18N("ui.settings.option.advplayerlist"),
			name = BAR.I18N("ui.settings.option.advplayerlist_country"),
			type = "bool",
			value = true,
			description = BAR.I18N("ui.settings.option.advplayerlist_country_descr"),
			widgetConfig = {
				"AdvPlayersList",
				{ "m_active_Table", "country" },
				api = "advplayerlist_api",
				set = "SetModuleActive",
				key = "country",
			},
		},
		{
			id = "advplayerlist_scale",
			parent = "advplayerlist_country",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.advplayerlist_scale"),
			min = 0.85,
			max = 1.2,
			step = 0.01,
			type = "slider",
			value = 1,
			description = BAR.I18N("ui.settings.option.advplayerlist_scale_descr"),
			widgetConfig = { "AdvPlayersList", "customScale", api = "advplayerlist_api", set = "SetScale" },
		},
		{
			id = "advplayerlist_showallyid",
			parent = "advplayerlist_country",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.advplayerlist_showallyid"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.advplayerlist_showallyid_descr"),
			widgetConfig = {
				"AdvPlayersList",
				{ "m_active_Table", "allyid" },
				api = "advplayerlist_api",
				set = "SetModuleActive",
				key = "allyid",
			},
		},
		{
			id = "advplayerlist_showid",
			parent = "advplayerlist_country",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.advplayerlist_showid"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.advplayerlist_showid_descr"),
			widgetConfig = {
				"AdvPlayersList",
				{ "m_active_Table", "id" },
				api = "advplayerlist_api",
				set = "SetModuleActive",
				key = "id",
			},
		},
		{
			id = "advplayerlist_showplayerid",
			parent = "advplayerlist_country",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.advplayerlist_showplayerid"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.advplayerlist_showplayerid_descr"),
			widgetConfig = {
				"AdvPlayersList",
				{ "m_active_Table", "playerid" },
				api = "advplayerlist_api",
				set = "SetModuleActive",
				key = "playerid",
			},
		},
		{
			id = "advplayerlist_rank",
			parent = "advplayerlist_country",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.advplayerlist_rank"),
			type = "bool",
			value = true,
			description = BAR.I18N("ui.settings.option.advplayerlist_rank_descr"),
			widgetConfig = {
				"AdvPlayersList",
				{ "m_active_Table", "rank" },
				api = "advplayerlist_api",
				set = "SetModuleActive",
				key = "rank",
			},
		},
		--{ id = "advplayerlist_side", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.advplayerlist_side'), type = "bool", value = true, description = Spring.I18N('ui.settings.option.advplayerlist_side_descr'),
		--  onload = function(option)
		--	  loadWidgetData("AdvPlayersList", "advplayerlist_side", { 'm_active_Table', 'side' })
		--  end,
		--  onchange = function(option, value)
		--	  saveOptionValue('AdvPlayersList', 'advplayerlist_api', 'SetModuleActive', { 'm_active_Table', 'side' }, value, { 'side', value })
		--  end,
		--},
		{
			id = "advplayerlist_skill",
			parent = "advplayerlist_country",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.advplayerlist_skill"),
			type = "bool",
			value = true,
			description = BAR.I18N("ui.settings.option.advplayerlist_skill_descr"),
			widgetConfig = {
				"AdvPlayersList",
				{ "m_active_Table", "skill" },
				api = "advplayerlist_api",
				set = "SetModuleActive",
				key = "skill",
			},
		},
		{
			id = "advplayerlist_cpuping",
			parent = "advplayerlist_country",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.advplayerlist_cpuping"),
			type = "bool",
			value = true,
			description = BAR.I18N("ui.settings.option.advplayerlist_cpuping_descr"),
			widgetConfig = {
				"AdvPlayersList",
				{ "m_active_Table", "cpuping" },
				api = "advplayerlist_api",
				set = "SetModuleActive",
				key = "cpuping",
			},
		},
		{
			id = "advplayerlist_resources",
			parent = "advplayerlist_country",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.advplayerlist_resources"),
			type = "bool",
			value = true,
			description = BAR.I18N("ui.settings.option.advplayerlist_resources_descr"),
			widgetConfig = {
				"AdvPlayersList",
				{ "m_active_Table", "resources" },
				api = "advplayerlist_api",
				set = "SetModuleActive",
				key = "resources",
			},
		},
		{
			id = "advplayerlist_income",
			parent = "advplayerlist_country",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.advplayerlist_income"),
			type = "bool",
			value = true,
			description = BAR.I18N("ui.settings.option.advplayerlist_income_descr"),
			widgetConfig = {
				"AdvPlayersList",
				{ "m_active_Table", "income" },
				api = "advplayerlist_api",
				set = "SetModuleActive",
				key = "income",
			},
		},
		{
			id = "advplayerlist_absresbars",
			parent = "advplayerlist_country",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.advplayerlist_absresbars"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.advplayerlist_absresbars_descr"),
			widgetConfig = {
				"AdvPlayersList",
				"absoluteResbarValues",
				api = "advplayerlist_api",
				set = "SetAbsoluteResbars",
			},
		},
		{
			id = "advplayerlist_share",
			parent = "advplayerlist_country",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.advplayerlist_share"),
			type = "bool",
			value = true,
			description = BAR.I18N("ui.settings.option.advplayerlist_share_descr"),
			widgetConfig = {
				"AdvPlayersList",
				{ "m_active_Table", "share" },
				api = "advplayerlist_api",
				set = "SetModuleActive",
				key = "share",
			},
		},
		{
			id = "advplayerlist_hidespecs",
			parent = "advplayerlist_country",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.advplayerlist_hidespecs"),
			type = "bool",
			value = true,
			description = BAR.I18N("ui.settings.option.advplayerlist_hidespecs_descr"),
			widgetConfig = {
				"AdvPlayersList",
				"alwaysHideSpecs",
				api = "advplayerlist_api",
				set = "SetAlwaysHideSpecs",
			},
		},
		{
			id = "unittotals",
			parent = "advplayerlist_country",
			group = "ui",
			category = types.advanced,
			widget = "AdvPlayersList Unit Totals",
			name = BAR.I18N("ui.settings.option.unittotals"),
			type = "bool",
			value = GetWidgetToggleValue("AdvPlayersList Unit Totals"),
			description = BAR.I18N("ui.settings.option.unittotals_descr"),
		},
		{
			id = "musicplayer",
			parent = "advplayerlist_country",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.musicplayer"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.musicplayer_descr"),
			widgetConfig = {
				"AdvPlayersList Music Player New",
				"showGUI",
				api = "music",
				get = "GetShowGui",
				set = "SetShowGui",
			},
		},
		{
			id = "mascot",
			parent = "advplayerlist_country",
			group = "ui",
			category = types.advanced,
			widget = "AdvPlayersList Mascot",
			name = BAR.I18N("ui.settings.option.mascot"),
			type = "bool",
			value = GetWidgetToggleValue("AdvPlayersList Mascot"),
			description = BAR.I18N("ui.settings.option.mascot_descr"),
		},

		{
			id = "displayselectedname",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.displayselectedname"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.displayselectedname_descr"),
			widgetConfig = {
				"Player-TV",
				"alwaysDisplayName",
				api = "playertv",
				get = "GetAlwaysDisplayName",
				set = "SetAlwaysDisplayName",
			},
		},

		{
			id = "console_fontsize",
			group = "ui",
			category = types.basic,
			prefix = BAR.I18N("ui.settings.option.console"),
			name = BAR.I18N("ui.settings.option.console_fontsize"),
			type = "slider",
			min = 0.92,
			max = 1.12,
			step = 0.02,
			value = 1,
			description = "",
			widgetConfig = { "Chat", "fontsizeMult", api = "chat", get = "getFontsize", set = "setFontsize" },
		},
		{
			id = "console_backgroundopacity",
			parent = "console_fontsize",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.console_backgroundopacity"),
			type = "slider",
			min = 0,
			max = 0.45,
			step = 0.01,
			value = 0,
			description = BAR.I18N("ui.settings.option.console_backgroundopacity_descr"),
			widgetConfig = {
				"Chat",
				"chatBackgroundOpacity",
				api = "chat",
				get = "getBackgroundOpacity",
				set = "setBackgroundOpacity",
			},
		},
		{
			id = "console_hidespecchat",
			parent = "console_fontsize",
			group = "ui",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.console_hidespecchat"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.console_hidespecchat_descr"),
			configInt = "HideSpecChat",
		},
		{
			id = "console_hidespecchatplayer",
			parent = "console_hidespecchat",
			group = "ui",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.console_hidespecchatplayer"),
			type = "bool",
			value = true,
			description = BAR.I18N("ui.settings.option.console_hidespecchatplayer_descr"),
			configInt = "HideSpecChatPlayer",
		},
		{
			id = "console_hide",
			parent = "console_fontsize",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.console_hide"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.console_hide_descr"),
			widgetConfig = { "Chat", "hide", api = "chat", get = "getHide", set = "setHide" },
		},
		{
			id = "console_maxlines",
			parent = "console_fontsize",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.console_maxlines"),
			type = "slider",
			min = 3,
			max = 7,
			step = 1,
			value = 5,
			description = "",
			widgetConfig = { "Chat", "maxLines", api = "chat", get = "getMaxLines", set = "setMaxLines" },
		},
		{
			id = "console_maxconsolelines",
			parent = "console_fontsize",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.console_maxconsolelines"),
			type = "slider",
			min = 2,
			max = 12,
			step = 1,
			value = 2,
			description = "",
			widgetConfig = {
				"Chat",
				"maxConsoleLines",
				api = "chat",
				get = "getMaxConsoleLines",
				set = "setMaxConsoleLines",
			},
		},
		--{ id = "console_handleinput", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.console_handleinput'), type = "bool", value = (WG['chat'] ~= nil and WG['chat'].getHandleInput() or 0), description = Spring.I18N('ui.settings.option.console_handleinput_descr'),
		--  onload = function(option)
		--	  loadWidgetData("Chat", "console_handleinput", { 'handleTextInput' })
		--  end,
		--  onchange = function(option, value)
		--	  saveOptionValue('Chat', 'chat', 'setHandleInput', { 'handleTextInput' }, value)
		--  end,
		--},
		--{ id = "console_inputbutton", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.console_inputbutton'), type = "bool", value = (WG['chat'] ~= nil and WG['chat'].getInputButton() or 0), description = Spring.I18N('ui.settings.option.console_inputbutton_descr'),
		--  onload = function(option)
		--	  loadWidgetData("Chat", "console_inputbutton", { 'inputButton' })
		--  end,
		--  onchange = function(option, value)
		--	  saveOptionValue('Chat', 'chat', 'setInputButton', { 'inputButton' }, value)
		--  end,
		--},
		{
			id = "autoeraser",
			group = "ui",
			category = types.basic,
			widget = "Auto mapmark eraser",
			name = BAR.I18N("ui.settings.option.autoeraser"),
			type = "bool",
			value = GetWidgetToggleValue("Auto mapmark eraser"),
			description = BAR.I18N("ui.settings.option.autoeraser_descr"),
		},
		{
			id = "autoeraser_erasetime",
			parent = "autoeraser",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.autoeraser_erasetime"),
			type = "slider",
			min = 5,
			max = 600,
			step = 5,
			value = 60,
			description = BAR.I18N("ui.settings.option.autoeraser_erasetime_descr"),
			widgetConfig = { "Auto mapmark eraser", "eraseTime", api = "autoeraser", set = "setEraseTime" },
		},

		{
			id = "topbar_hidebuttons",
			group = "ui",
			category = types.advanced,
			prefix = BAR.I18N("ui.settings.option.topbar"),
			name = BAR.I18N("ui.settings.option.topbar_hidebuttons"),
			type = "bool",
			value = false,
			widgetConfig = {
				"Top Bar Buttons",
				"autoHideButtons",
				api = "topbar",
				get = "getAutoHideButtons",
				set = "setAutoHideButtons",
			},
		},

		{
			id = "continuouslyclearmapmarks",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.continuouslyclearmapmarks"),
			type = "bool",
			value = Spring.GetConfigInt("ContinuouslyClearMapmarks", 0) == 1,
			description = BAR.I18N("ui.settings.option.continuouslyclearmapmarks_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("ContinuouslyClearMapmarks", (value and 1 or 0))
				if value then
					Spring.SendCommands({ "clearmapmarks" })
				end
			end,
		},

		{
			id = "unitgroups",
			group = "ui",
			category = types.basic,
			widget = "Unit Groups",
			name = BAR.I18N("ui.settings.option.unitgroups"),
			type = "bool",
			value = GetWidgetToggleValue("Unit Groups"),
			description = BAR.I18N("ui.settings.option.unitgroups_descr"),
		},
		{
			id = "idlebuilders",
			group = "ui",
			category = types.basic,
			widget = "Idle Builders",
			name = BAR.I18N("ui.settings.option.idlebuilders"),
			type = "bool",
			value = GetWidgetToggleValue("Idle Builders"),
			description = BAR.I18N("ui.settings.option.idlebuilders_descr"),
		},
		{
			id = "buildbar",
			group = "ui",
			category = types.basic,
			widget = "BuildBar",
			name = BAR.I18N("ui.settings.option.buildbar"),
			type = "bool",
			value = GetWidgetToggleValue("BuildBar"),
			description = BAR.I18N("ui.settings.option.buildbar_descr"),
		},

		{
			id = "converterusage",
			group = "ui",
			category = types.advanced,
			widget = "Converter Usage",
			name = BAR.I18N("ui.settings.option.converterusage"),
			type = "bool",
			value = GetWidgetToggleValue("Converter Usage"),
			description = BAR.I18N("ui.settings.option.converterusage_descr"),
		},

		{
			id = "widgetselector",
			group = "ui",
			category = types.advanced,
			available = not (devMode or devUI) and hasUserWidgets,
			name = BAR.I18N("ui.settings.option.widgetselector"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.widgetselector_descr"),
			configInt = "widgetselector",
		},

		{
			id = "windows_hideinterface",
			group = "ui",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.windows_hideinterface"),
			type = "bool",
			value = Spring.GetConfigInt("WindowsHideInterface", 0) == 1,
			description = BAR.I18N("ui.settings.option.windows_hideinterface_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("WindowsHideInterface", (value and 1 or 0))
				-- pushed through as well so it takes effect now instead of at the next poll
				widgetHandler:SetWindowsHideInterface(value)
			end,
		},

		{
			id = "label_ui_visuals",
			group = "ui",
			name = BAR.I18N("ui.settings.option.label_visuals"),
			category = types.basic,
		},

		{
			id = "uniticon_scaleui",
			group = "ui",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.uniticonscaleui"),
			type = "slider",
			min = 0.85,
			max = 3,
			step = 0.05,
			value = tonumber(Spring.GetConfigFloat("UnitIconScaleUI", 1) or 1),
			description = BAR.I18N("ui.settings.option.uniticonscaleui_descr"),
			onchange = function(option, value)
				Spring.SendCommands("iconscaleui " .. value)
				Spring.SetConfigFloat("UnitIconScaleUI", value)
			end,
		},
		{
			id = "uniticon_distance",
			parent = "uniticon_scaleui",
			group = "ui",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.uniticondistance"),
			type = "slider",
			min = 1,
			max = 12000,
			step = 50,
			value = tonumber(Spring.GetConfigInt("UnitIconFadeVanish", 2700) or 1),
			description = BAR.I18N("ui.settings.option.uniticondistance_descr"),
			onchange = function(option, value)
				Spring.SendCommands("iconfadestart " .. value)
				Spring.SetConfigInt("UnitIconFadeStart", value)
				-- update UnitIconFadeVanish too
				Spring.SendCommands("iconfadevanish " .. value)
				Spring.SetConfigInt("UnitIconFadeVanish", value)
			end,
		},
		{
			id = "uniticon_hidewithui",
			parent = "uniticon_scaleui",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.uniticonhidewithui"),
			type = "bool",
			value = (Spring.GetConfigInt("UnitIconsHideWithUI", 0) == 1),
			description = BAR.I18N("ui.settings.option.uniticonhidewithui_descr"),
			onchange = function(option, value)
				Spring.SendCommands("iconshidewithui " .. (value and 1 or 0))
				Spring.SetConfigInt("UnitIconsHideWithUI", (value and 1 or 0))
			end,
		},

		-- { id = "teamcolors", group = "ui", category = types.basic, widget = "Player Color Palette", name = Spring.I18N('ui.settings.option.teamcolors'), type = "bool", value = GetWidgetToggleValue("Player Color Palette"), description = Spring.I18N('ui.settings.option.teamcolors_descr') },
		-- { id = "sameteamcolors", group = "ui", category = types.basic, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.sameteamcolors'), type = "bool", value = (WG['playercolorpalette'] ~= nil and WG['playercolorpalette'].getSameTeamColors ~= nil and WG['playercolorpalette'].getSameTeamColors()), description = Spring.I18N('ui.settings.option.sameteamcolors_descr'),
		--   onchange = function(option, value)
		-- 	  saveOptionValue('Player Color Palette', 'playercolorpalette', 'setSameTeamColors', { 'useSameTeamColors' }, value)
		--   end,
		-- },

		{
			id = "teamplatter",
			group = "ui",
			category = types.basic,
			widget = "TeamPlatter",
			name = BAR.I18N("ui.settings.option.teamplatter"),
			type = "bool",
			value = GetWidgetToggleValue("TeamPlatter"),
			description = BAR.I18N("ui.settings.option.teamplatter_descr"),
		},
		{
			id = "teamplatter_opacity",
			parent = "teamplatter",
			category = types.advanced,
			group = "ui",
			name = BAR.I18N("ui.settings.option.teamplatter_opacity"),
			min = 0.05,
			max = 0.4,
			step = 0.01,
			type = "slider",
			value = 0.25,
			description = BAR.I18N("ui.settings.option.teamplatter_opacity_descr"),
			widgetConfig = { "TeamPlatter", "opacity", api = "teamplatter", set = "setOpacity" },
		},
		{
			id = "teamplatter_skipownteam",
			parent = "teamplatter",
			category = types.advanced,
			group = "ui",
			name = BAR.I18N("ui.settings.option.teamplatter_skipownteam"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.teamplatter_skipownteam_descr"),
			widgetConfig = { "TeamPlatter", "skipOwnTeam", api = "teamplatter", set = "setSkipOwnTeam" },
		},

		{
			id = "enemyspotter",
			group = "ui",
			category = types.basic,
			widget = "EnemySpotter",
			name = BAR.I18N("ui.settings.option.enemyspotter"),
			type = "bool",
			value = GetWidgetToggleValue("EnemySpotter"),
			description = BAR.I18N("ui.settings.option.enemyspotter_descr"),
		},
		{
			id = "enemyspotter_opacity",
			parent = "enemyspotter",
			category = types.advanced,
			group = "ui",
			name = BAR.I18N("ui.settings.option.enemyspotter_opacity"),
			min = 0.12,
			max = 0.4,
			step = 0.01,
			type = "slider",
			value = 0.15,
			description = BAR.I18N("ui.settings.option.enemyspotter_opacity_descr"),
			widgetConfig = { "EnemySpotter", "opacity", api = "enemyspotter", set = "setOpacity" },
		},

		--{ id = "selectedunits", group = "ui", category = types.basic, widget = "Selected Units GL4", name = "Selection", type = "bool", value = GetWidgetToggleValue("Selected Units GL4"), description = Spring.I18N('ui.settings.option.selectedunits_descr') },
		{
			id = "selectedunits_opacity",
			group = "ui",
			category = types.advanced,
			prefix = BAR.I18N("ui.settings.option.selectedunits"),
			name = BAR.I18N("ui.settings.option.selectedunits_opacity"),
			min = 0,
			max = 0.5,
			step = 0.01,
			type = "slider",
			value = 0.19,
			description = BAR.I18N("ui.settings.option.selectedunits_opacity_descr"),
			widgetConfig = { "Selected Units GL4", "opacity", api = "selectedunits", set = "setOpacity" },
		},
		{
			id = "selectedunits_teamcoloropacity",
			parent = "selectedunits_opacity",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.selectedunits_teamcoloropacity"),
			min = 0,
			max = 1,
			step = 0.01,
			type = "slider",
			value = 0.6,
			description = BAR.I18N("ui.settings.option.selectedunits_teamcoloropacity_descr"),
			widgetConfig = {
				"Selected Units GL4",
				"teamcolorOpacity",
				api = "selectedunits",
				set = "setTeamcolorOpacity",
			},
		},

		--{ id = "highlightselunits", group = "ui", category = types.basic, widget = "Highlight Selected Units GL4", name = Spring.I18N('ui.settings.option.highlightselunits'), type = "bool", value = GetWidgetToggleValue("Highlight Selected Units GL4"), description = Spring.I18N('ui.settings.option.highlightselunits_descr') },

		{
			id = "highlightselunits",
			parent = "selectedunits_opacity",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.highlightselunits"),
			type = "bool",
			value = true,
			description = BAR.I18N("ui.settings.option.highlightselunits_descr"),
			widgetConfig = {
				"Selected Units GL4",
				"selectionHighlight",
				api = "selectedunits",
				set = "setSelectionHighlight",
			},
		},
		--{ id = "highlightselunits_opacity", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.highlightselunits_opacity'), min = 0.02, max = 0.12, step = 0.01, type = "slider", value = 0.05, description = Spring.I18N('ui.settings.option.highlightselunits_opacity_descr'),
		--  onload = function(option)
		--	  loadWidgetData("Highlight Selected Units GL4", "highlightselunits_opacity", { 'highlightAlpha' })
		--  end,
		--  onchange = function(option, value)
		--	  saveOptionValue('Highlight Selected Units GL4', 'highlightselunits', 'setOpacity', { 'highlightAlpha' }, value)
		--  end,
		--},
		--{ id = "highlightselunits_teamcolor", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.highlightselunits_teamcolor'), type = "bool", value = false, description = Spring.I18N('ui.settings.option.highlightselunits_teamcolor_descr'),
		--  onload = function(option)
		--	  loadWidgetData("Highlight Selected Units GL4", "highlightselunits_teamcolor", { 'useTeamcolor' })
		--  end,
		--  onchange = function(option, value)
		--	  saveOptionValue('Highlight Selected Units GL4', 'highlightselunits', 'setTeamcolor', { 'useTeamcolor' }, value)
		--  end,
		--},

		-- { id = "highlightunit", group = "ui", category = types.advanced, widget = "Highlight Unit GL4", name = Spring.I18N('ui.settings.option.highlightunit'), type = "bool", value = GetWidgetToggleValue("Highlight Unit GL4"), description = Spring.I18N('ui.settings.option.highlightunit_descr') },

		{
			id = "highlightunit",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.highlightunit"),
			type = "bool",
			value = true,
			description = BAR.I18N("ui.settings.option.highlightunit_descr"),
			widgetConfig = {
				"Selected Units GL4",
				"mouseoverHighlight",
				api = "selectedunits",
				set = "setMouseoverHighlight",
			},
		},

		-- Jammed units highlight
		{
			id = "jammedunits",
			group = "ui",
			category = types.advanced,
			widget = "Jammed Units Highlight",
			name = BAR.I18N("ui.settings.option.jammedunits"),
			type = "bool",
			value = GetWidgetToggleValue("Jammed Units Highlight"),
			description = BAR.I18N("ui.settings.option.jammedunits_descr"),
		},
		{
			id = "ghosticons_brightness",
			group = "ui",
			category = types.dev,
			prefix = BAR.I18N("ui.settings.option.ghosticons"),
			name = BAR.I18N("ui.settings.option.ghosticons_brightness"),
			min = 0,
			max = 1.0,
			step = 0.15,
			type = "slider",
			value = 0.8,
			description = BAR.I18N("ui.settings.option.ghosticons_brightness_descr"),
			configFloat = "UnitGhostIconsDimming",
		},

		{
			id = "cursorlight",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.cursorlight"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.cursorlight_descr"),
			widgetConfig = {
				"Deferred rendering GL4",
				"showPlayerCursorLight",
				api = "lightsgl4",
				set = "ShowPlayerCursorLight",
			},
		},
		{
			id = "cursorlight_lightradius",
			parent = "cursorlight",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.cursorlight_lightradius"),
			type = "slider",
			min = 0.3,
			max = 2,
			step = 0.05,
			value = 1,
			description = "",
			widgetConfig = {
				"Deferred rendering GL4",
				"playerCursorLightRadius",
				api = "lightsgl4",
				set = "PlayerCursorLightRadius",
			},
		},
		{
			id = "cursorlight_lightstrength",
			parent = "cursorlight",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.cursorlight_lightstrength"),
			type = "slider",
			min = 0.3,
			max = 2,
			step = 0.05,
			value = 1,
			description = "",
			widgetConfig = {
				"Deferred rendering GL4",
				"playerCursorLightBrightness",
				api = "lightsgl4",
				set = "PlayerCursorLightBrightness",
			},
		},

		{
			id = "label_ui_info",
			group = "ui",
			name = BAR.I18N("ui.settings.option.label_info"),
			category = types.basic,
		},

		{
			id = "metalspots_values",
			group = "ui",
			category = types.advanced,
			prefix = BAR.I18N("ui.settings.option.metalspots"),
			name = BAR.I18N("ui.settings.option.metalspots_values"),
			type = "bool",
			value = (WG.metalspots ~= nil and WG.metalspots.getShowValue()),
			description = BAR.I18N("ui.settings.option.metalspots_values_descr"),
			onload = function(option)
				loadWidgetData("Metalspots", "metalspots_values", { "showValue" })
			end,
			onchange = function(option, value)
				if WG.metalspots then
					WG.metalspots.setShowValue(value)
				end
				saveOptionValue("Metalspots", "metalspots", "setShowValue", { "showValue" }, option.value)
			end,
		},
		{
			id = "metalspots_metalviewonly",
			parent = "metalspots_values",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.metalspots_metalviewonly"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.metalspots_metalviewonly_descr"),
			widgetConfig = { "Metalspots", "metalViewOnly", api = "metalspots", set = "setMetalViewOnly" },
		},

		{
			id = "geospots",
			group = "ui",
			category = types.dev,
			widget = "Geothermalspots",
			name = BAR.I18N("ui.settings.option.geospots"),
			type = "bool",
			value = GetWidgetToggleValue("Geothermalspots"),
			description = BAR.I18N("ui.settings.option.geospots_descr"),
		},

		{
			id = "healthbarsscale",
			group = "ui",
			category = types.advanced,
			prefix = BAR.I18N("ui.settings.option.healthbars"),
			name = BAR.I18N("ui.settings.option.healthbarsscale"),
			type = "slider",
			min = 0.6,
			max = 2.0,
			step = 0.1,
			value = 1,
			description = "",
			widgetConfig = { "Health Bars GL4", "barScale", api = "healthbars", set = "setScale" },
		},
		{
			id = "healthbarsheight",
			parent = "healthbarsscale",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.healthbarsheight"),
			type = "slider",
			min = 0.7,
			max = 2,
			step = 0.1,
			value = (WG.healthbars ~= nil and WG.healthbars.getHeight() or 0.9),
			description = "",
			onload = function(option)
				loadWidgetData("Health Bars GL4", "healthbarsheight", { "barHeight" })
			end,
			onchange = function(option, value)
				saveOptionValue("Health Bars GL4", "healthbars", "setHeight", { "barHeight" }, value)
				widgetHandler:DisableWidget("Health Bars GL4")
				widgetHandler:EnableWidget("Health Bars GL4")
			end,
		},
		{
			id = "healthbarsvariable",
			parent = "healthbarsscale",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.healthbarsvariable"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.healthbarsvariable_descr"),
			widgetConfig = {
				"Health Bars GL4",
				"variableBarSizes",
				api = "healthbars",
				get = "getVariableSizes",
				set = "setVariableSizes",
			},
		},
		{
			id = "healthbarswhenguihidden",
			parent = "healthbarsscale",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.healthbarswhenguihidden"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.healthbarswhenguihidden_descr"),
			widgetConfig = {
				"Health Bars GL4",
				"drawWhenGuiHidden",
				api = "healthbars",
				get = "getDrawWhenGuiHidden",
				set = "setDrawWhenGuiHidden",
			},
		},
		{
			id = "rankicons",
			group = "ui",
			category = types.advanced,
			widget = "Rank Icons GL4",
			name = BAR.I18N("ui.settings.option.rankicons"),
			type = "bool",
			value = GetWidgetToggleValue("Rank Icons GL4"),
			description = BAR.I18N("ui.settings.option.rankicons_descr"),
		},
		{
			id = "rankicons_distance",
			parent = "rankicons",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.rankicons_distance"),
			type = "slider",
			min = 0.1,
			max = 1.5,
			step = 0.05,
			value = (WG.rankicons ~= nil and WG.rankicons.getDrawDistance ~= nil and WG.rankicons.getDrawDistance()),
			description = "",
			onchange = function(option, value)
				saveOptionValue("Rank Icons GL4", "rankicons", "setDrawDistance", { "distanceMult" }, value)
			end,
		},
		{
			id = "rankicons_scale",
			parent = "rankicons",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.rankicons_scale"),
			type = "slider",
			min = 0.5,
			max = 2,
			step = 0.1,
			value = (WG.rankicons ~= nil and WG.rankicons.getScale ~= nil and WG.rankicons.getScale()),
			description = "",
			onchange = function(option, value)
				saveOptionValue("Rank Icons GL4", "rankicons", "setScale", { "iconsizeMult" }, value)
			end,
		},

		{
			id = "allycursors",
			group = "ui",
			category = types.basic,
			widget = "AllyCursors",
			name = BAR.I18N("ui.settings.option.allycursors"),
			type = "bool",
			value = GetWidgetToggleValue("AllyCursors"),
			description = BAR.I18N("ui.settings.option.allycursors_descr"),
		},
		{
			id = "allycursors_playername",
			parent = "allycursors",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.allycursors_playername"),
			type = "bool",
			value = true,
			description = BAR.I18N("ui.settings.option.allycursors_playername_descr"),
			widgetConfig = { "AllyCursors", "showPlayerName", api = "allycursors", set = "setPlayerNames" },
		},
		{
			id = "allycursors_showdot",
			parent = "allycursors",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.allycursors_showdot"),
			type = "bool",
			value = true,
			description = BAR.I18N("ui.settings.option.allycursors_showdot_descr"),
			widgetConfig = { "AllyCursors", "showCursorDot", api = "allycursors", set = "setCursorDot" },
		},
		{
			id = "allycursors_spectatorname",
			parent = "allycursors",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.allycursors_spectatorname"),
			type = "bool",
			value = true,
			description = BAR.I18N("ui.settings.option.allycursors_spectatorname_descr"),
			widgetConfig = { "AllyCursors", "showSpectatorName", api = "allycursors", set = "setSpectatorNames" },
		},
		{
			id = "allycursors_lights",
			parent = "allycursors",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.allycursors_lights"),
			type = "bool",
			value = true,
			description = BAR.I18N("ui.settings.option.allycursors_lights_descr"),
			widgetConfig = { "AllyCursors", "addLights", api = "allycursors", set = "setLights" },
		},
		{
			id = "allycursors_lightradius",
			parent = "allycursors_lights",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.allycursors_lightradius"),
			type = "slider",
			min = 0.15,
			max = 1,
			step = 0.05,
			value = 0.5,
			description = "",
			widgetConfig = { "AllyCursors", "lightRadiusMult", api = "allycursors", set = "setLightRadius" },
		},
		{
			id = "allycursors_lightstrength",
			parent = "allycursors_lights",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.allycursors_lightstrength"),
			type = "slider",
			min = 0.1,
			max = 1.2,
			step = 0.05,
			value = 0.85,
			description = "",
			widgetConfig = { "AllyCursors", "lightStrengthMult", api = "allycursors", set = "setLightStrength" },
		},
		{
			id = "allycursors_selfshadowing",
			parent = "allycursors_lights",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.allycursors_selfshadowing"),
			type = "bool",
			value = false,
			description = "",
			widgetConfig = { "AllyCursors", "lightSelfShadowing", api = "allycursors", set = "setLightSelfShadowing" },
		},

		{
			id = "showbuilderqueue",
			group = "ui",
			category = types.advanced,
			widget = "Show Builder Queue",
			name = BAR.I18N("ui.settings.option.showbuilderqueue"),
			type = "bool",
			value = GetWidgetToggleValue("Show Builder Queue"),
			description = BAR.I18N("ui.settings.option.showbuilderqueue_descr"),
		},

		{
			id = "unitenergyicons",
			group = "ui",
			category = types.advanced,
			widget = "Unit Energy Icons",
			name = BAR.I18N("ui.settings.option.unitenergyicons"),
			type = "bool",
			value = GetWidgetToggleValue("Unit Energy Icons"),
			description = BAR.I18N("ui.settings.option.unitenergyicons_descr"),
		},

		{
			id = "unitidlebuildericons",
			group = "ui",
			category = types.advanced,
			widget = "Unit Idle Builder Icons",
			name = BAR.I18N("ui.settings.option.unitidlebuildericons"),
			type = "bool",
			value = GetWidgetToggleValue("Unit Idle Builder Icons"),
			description = BAR.I18N("ui.settings.option.unitidlebuildericons_descr"),
		},

		{
			id = "unitfirestateicons",
			group = "ui",
			category = types.advanced,
			widget = "Unit Fire State Icons",
			name = BAR.I18N("ui.settings.option.unitfirestateicons"),
			type = "bool",
			value = GetWidgetToggleValue("Unit Fire State Icons"),
			description = BAR.I18N("ui.settings.option.unitfirestateicons_descr"),
		},

		{
			id = "resurrectionhalos",
			group = "ui",
			category = types.advanced,
			widget = "Resurrection Halos GL4",
			name = BAR.I18N("ui.settings.option.resurrectionhalos"),
			type = "bool",
			value = GetWidgetToggleValue("Resurrection Halos GL4"),
			description = BAR.I18N("ui.settings.option.resurrectionhalos_descr"),
		},

		{
			id = "nametags_rank",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.nametags_rank"),
			type = "bool",
			value = true,
			description = BAR.I18N("ui.settings.option.nametags_rank_descr"),
			widgetConfig = { "Commander Name Tags", "showPlayerRank", api = "nametags", set = "SetShowPlayerRank" },
		},

		{
			id = "commandsfx",
			group = "ui",
			category = types.basic,
			widget = "Commands FX",
			name = BAR.I18N("ui.settings.option.commandsfx"),
			type = "bool",
			value = GetWidgetToggleValue("Commands FX"),
			description = BAR.I18N("ui.settings.option.commandsfx_descr"),
		},

		{
			id = "commandsfxopacity",
			parent = "commandsfx",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.commandsfxopacity"),
			type = "slider",
			min = 0.25,
			max = 1,
			step = 0.1,
			value = 1,
			description = "",
			widgetConfig = { "Commands FX", "opacity", api = "commandsfx", set = "setOpacity" },
		},
		{
			id = "commandsfxduration",
			parent = "commandsfx",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.commandsfxduration"),
			type = "slider",
			min = 0.5,
			max = 2,
			step = 0.01,
			value = 1,
			description = "",
			widgetConfig = { "Commands FX", "duration", api = "commandsfx", set = "setDuration" },
		},
		{
			id = "commandsfxfilterai",
			parent = "commandsfx",
			group = "ui",
			category = types.dev,
			available = aiDetected,
			name = BAR.I18N("ui.settings.option.commandsfxfilterai"),
			type = "bool",
			value = true,
			description = BAR.I18N("ui.settings.option.commandsfxfilterai_descr"),
			widgetConfig = { "Commands FX", "filterAIteams", api = "commandsfx", set = "setFilterAI" },
		},
		{
			id = "commandsfxuseteamcolors",
			parent = "commandsfx",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.commandsfxuseteamcolors"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.commandsfxuseteamcolors_descr"),
			widgetConfig = { "Commands FX", "useTeamColors", api = "commandsfx", set = "setUseTeamColors" },
		},
		{
			id = "commandsfxuseteamcolorswhenspec",
			parent = "commandsfx",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.commandsfxuseteamcolorswhenspec"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.commandsfxuseteamcolorswhenspec_descr"),
			widgetConfig = {
				"Commands FX",
				"useTeamColorsWhenSpec",
				api = "commandsfx",
				get = "getUseTeamColorsWhenSpec",
				set = "setUseTeamColorsWhenSpec",
			},
		},

		{
			id = "flankingicons",
			group = "ui",
			category = types.advanced,
			widget = "Flanking Icons GL4",
			name = BAR.I18N("ui.settings.option.flankingicons"),
			type = "bool",
			value = GetWidgetToggleValue("Flanking Icons GL4"),
			description = BAR.I18N("ui.settings.option.flankingicons_descr"),
		},

		{
			id = "displaydps",
			group = "ui",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.displaydps"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.displaydps_descr"),
			configInt = "DisplayDPS",
		},

		{
			id = "givenunits",
			group = "ui",
			category = types.advanced,
			widget = "Given Units",
			name = BAR.I18N("ui.settings.option.givenunits"),
			type = "bool",
			value = GetWidgetToggleValue("Given Units"),
			description = BAR.I18N("ui.settings.option.givenunits_descr"),
		},

		{
			id = "reclaimfieldhighlight",
			group = "ui",
			category = types.advanced,
			widget = "Reclaim Field Highlight",
			name = BAR.I18N("ui.settings.option.reclaimfieldhighlight"),
			type = "bool",
			description = BAR.I18N("ui.settings.option.reclaimfieldhighlight_descr"),
		},

		{
			id = "reclaimfieldhighlight_metal",
			parent = "reclaimfieldhighlight",
			group = "ui",
			category = types.advanced,
			widget = "Reclaim Field Highlight",
			name = BAR.I18N("ui.settings.option.reclaimfieldhighlight_metal"),
			type = "select",
			options = reclaimFieldHighlightOptions,
			value = 3,
			description = BAR.I18N("ui.settings.option.reclaimfieldhighlight_metal_descr"),
			widgetConfig = {
				"Reclaim Field Highlight",
				"showOption",
				api = "reclaimfieldhighlight",
				set = "setShowOption",
			},
		},

		{
			id = "reclaimfieldhighlight_energy",
			parent = "reclaimfieldhighlight",
			group = "ui",
			category = types.advanced,
			widget = "Reclaim Field Highlight",
			name = BAR.I18N("ui.settings.option.reclaimfieldhighlight_energy"),
			type = "select",
			options = reclaimFieldHighlightOptions,
			value = 3,
			description = BAR.I18N("ui.settings.option.reclaimfieldhighlight_energy_descr"),
			widgetConfig = {
				"Reclaim Field Highlight",
				"showEnergyOption",
				api = "reclaimfieldhighlight",
				set = "setShowEnergyOption",
			},
		},

		{
			id = "highlightcomwrecks",
			group = "ui",
			category = types.advanced,
			widget = "Highlight Commander Wrecks",
			name = BAR.I18N("ui.settings.option.highlightcomwrecks"),
			type = "bool",
			value = GetWidgetToggleValue("Highlight Commander Wrecks"),
			description = BAR.I18N("ui.settings.option.highlightcomwrecks_descr"),
		},
		{
			id = "highlightcomwrecks_teamcolor",
			parent = "highlightcomwrecks",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.highlightcomwrecks_teamcolor"),
			type = "bool",
			value = true,
			description = BAR.I18N("ui.settings.option.highlightcomwrecks_teamcolor_descr"),
			widgetConfig = {
				"Highlight Commander Wrecks",
				"useTeamColor",
				api = "highlightcomwrecks",
				set = "setUseTeamColor",
			},
		},

		{
			id = "buildinggrid",
			group = "ui",
			category = types.basic,
			widget = "Building Grid GL4",
			name = BAR.I18N("ui.settings.option.buildinggrid"),
			type = "bool",
			value = GetWidgetToggleValue("Building Grid GL4"),
			description = BAR.I18N("ui.settings.option.buildinggrid_descr"),
		},
		{
			id = "buildinggridopacity",
			parent = "buildinggrid",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.buildinggridopacity"),
			type = "slider",
			min = 0.3,
			max = 1,
			step = 0.05,
			value = 1,
			description = "",
			widgetConfig = {
				"Building Grid GL4",
				"opacity",
				api = "buildinggrid",
				get = "getOpacity",
				set = "setOpacity",
			},
		},
		{
			id = "startpositionsuggestions",
			group = "ui",
			category = types.basic,
			widget = "Start Position Suggestions",
			name = BAR.I18N("ui.settings.option.startpositionsuggestions"),
			type = "bool",
			value = GetWidgetToggleValue("Start Position Suggestions"),
			description = BAR.I18N("ui.settings.option.startpositionsuggestions_descr"),
		},

		{
			id = "label_ui_ranges",
			group = "ui",
			name = BAR.I18N("ui.settings.option.label_ranges"),
			category = types.basic,
		},

		-- read by the radar and jammer preview widgets
		{
			id = "sensorpreviewcircles",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.sensorpreviewcircles"),
			type = "bool",
			value = Spring.GetConfigInt("SensorPreviewCircles", 1) ~= 0,
			description = BAR.I18N("ui.settings.option.sensorpreviewcircles_descr"),
			onchange = function(_, value)
				Spring.SetConfigInt("SensorPreviewCircles", value and 1 or 0)
			end,
		},

		-- Radar range rings:
		{
			id = "radarrange",
			group = "ui",
			category = types.advanced,
			widget = "Sensor Ranges Radar",
			name = BAR.I18N("ui.settings.option.radarrange"),
			type = "bool",
			value = GetWidgetToggleValue("Sensor Ranges Radar"),
			description = BAR.I18N("ui.settings.option.radarrange_descr"),
		},

		{
			id = "radarrangeopacity",
			parent = "radarrange",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.radarrangeopacity"),
			type = "slider",
			min = 0.01,
			max = 0.33,
			step = 0.01,
			value = 0.08,
			description = "",
			widgetConfig = {
				"Sensor Ranges Radar",
				"opacity",
				api = "radarrange",
				get = "getOpacity",
				set = "setOpacity",
			},
		},
		-- Sonar range
		{
			id = "sonarrange",
			group = "ui",
			category = types.advanced,
			widget = "Sensor Ranges Sonar",
			name = BAR.I18N("ui.settings.option.sonarrange"),
			type = "bool",
			value = GetWidgetToggleValue("Sensor Ranges Sonar"),
			description = BAR.I18N("ui.settings.option.sonarrange_descr"),
		},

		{
			id = "sonarrangeopacity",
			parent = "sonarrange",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.sonarrangeopacity"),
			type = "slider",
			min = 0.01,
			max = 0.33,
			step = 0.01,
			value = 0.08,
			description = "",
			widgetConfig = {
				"Sensor Ranges Sonar",
				"opacity",
				api = "sonarrange",
				get = "getOpacity",
				set = "setOpacity",
			},
		},
		-- Jammer range

		-- LOS Range:
		{
			id = "losrange",
			group = "ui",
			category = types.advanced,
			widget = "Sensor Ranges LOS",
			name = BAR.I18N("ui.settings.option.losrange"),
			type = "bool",
			value = GetWidgetToggleValue("Sensor Ranges LOS"),
			description = BAR.I18N("ui.settings.option.losrange_descr"),
		},

		{
			id = "losrangeopacity",
			parent = "losrange",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.losrangeopacity"),
			type = "slider",
			min = 0.01,
			max = 0.33,
			step = 0.01,
			value = 0.08,
			description = "",
			widgetConfig = { "Sensor Ranges LOS", "opacity", api = "losrange", get = "getOpacity", set = "setOpacity" },
		},
		{
			id = "losrangeteamcolors",
			parent = "losrange",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.losrangeteamcolors"),
			type = "bool",
			value = false,
			description = "",
			widgetConfig = {
				"Sensor Ranges LOS",
				"useteamcolors",
				api = "losrange",
				get = "getUseTeamColors",
				set = "setUseTeamColors",
			},
		},

		{
			id = "attackrange",
			group = "ui",
			category = types.basic,
			widget = "Attack Range GL4",
			name = BAR.I18N("ui.settings.option.attackrange"),
			type = "bool",
			value = GetWidgetToggleValue("Attack Range GL4"),
			description = BAR.I18N("ui.settings.option.attackrange_descr"),
		},
		{
			id = "attackrange_shiftonly",
			parent = "attackrange",
			category = types.dev,
			group = "ui",
			name = BAR.I18N("ui.settings.option.attackrange_shiftonly"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.attackrange_shiftonly_descr"),
			widgetConfig = {
				"Attack Range GL4",
				"shift_only",
				api = "attackrange",
				get = "getShiftOnly",
				set = "setShiftOnly",
			},
		},
		{
			id = "attackrange_cursorunitrange",
			parent = "attackrange",
			category = types.dev,
			group = "ui",
			name = BAR.I18N("ui.settings.option.attackrange_cursorunitrange"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.attackrange_cursorunitrange_descr"),
			widgetConfig = {
				"Attack Range GL4",
				"cursor_unit_range",
				api = "attackrange",
				get = "getCursorUnitRange",
				set = "setCursorUnitRange",
			},
		},
		{
			id = "attackrange_numrangesmult",
			parent = "attackrange",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.attackrange_numrangesmult"),
			type = "slider",
			min = 0.3,
			max = 1,
			step = 0.1,
			value = 1,
			description = BAR.I18N("ui.settings.option.attackrange_numrangesmult_descr"),
			widgetConfig = {
				"Attack Range GL4",
				"selectionDisableThresholdMult",
				api = "attackrange",
				get = "getNumRangesMult",
				set = "setNumRangesMult",
			},
		},

		{
			id = "defrange",
			group = "ui",
			category = types.basic,
			widget = "Defense Range GL4",
			name = BAR.I18N("ui.settings.option.defrange"),
			type = "bool",
			value = GetWidgetToggleValue("Defense Range GL4"),
			description = BAR.I18N("ui.settings.option.defrange_descr"),
		},

		{
			id = "defrange_allyair",
			parent = "defrange",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.defrange_allyair"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.defrange_allyair_descr"),
			widgetConfig = {
				"Defense Range GL4",
				{ "enabled", "ally", "air" },
				api = "defrange",
				get = "getAllyAir",
				set = "setAllyAir",
			},
		},
		{
			id = "defrange_allyground",
			parent = "defrange",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.defrange_allyground"),
			type = "bool",
			value = (WG.defrange ~= nil and WG.defrange.getAllyGround ~= nil and WG.defrange.getAllyGround()),
			description = BAR.I18N("ui.settings.option.defrange_allyground_descr"),
			onload = function(option)
				loadWidgetData("Defense Range GL4", "defrange_allyground", { "enabled", "ally", "ground" })
			end,
			onchange = function(option, value)
				--saveOptionValue('Defense Range', 'defrange', 'setAllyGround', { 'enabled', 'ally', 'ground' }, value)
				saveOptionValue(
					"Defense Range GL4",
					"defrange",
					"setAllyGround",
					{ "enabled", "ally", "ground" },
					value
				)
				saveOptionValue(
					"Defense Range GL4",
					"defrange",
					"setAllyGround",
					{ "enabled", "ally", "cannon" },
					value
				)
			end,
		},
		{
			id = "defrange_allynuke",
			parent = "defrange",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.defrange_allynuke"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.defrange_allynuke_descr"),
			widgetConfig = {
				"Defense Range GL4",
				{ "enabled", "ally", "nuke" },
				api = "defrange",
				get = "getAllyNuke",
				set = "setAllyNuke",
			},
		},
		{
			id = "defrange_allylrpc",
			parent = "defrange",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.defrange_allylrpc"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.defrange_allylrpc_descr"),
			widgetConfig = {
				"Defense Range GL4",
				{ "enabled", "ally", "lrpc" },
				api = "defrange",
				get = "getAllyLRPC",
				set = "setAllyLRPC",
			},
		},
		{
			id = "defrange_enemyair",
			parent = "defrange",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.defrange_enemyair"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.defrange_enemyair_descr"),
			widgetConfig = {
				"Defense Range GL4",
				{ "enabled", "enemy", "air" },
				api = "defrange",
				get = "getEnemyAir",
				set = "setEnemyAir",
			},
		},
		{
			id = "defrange_enemyground",
			parent = "defrange",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.defrange_enemyground"),
			type = "bool",
			value = (WG.defrange ~= nil and WG.defrange.getEnemyGround ~= nil and WG.defrange.getEnemyGround()),
			description = BAR.I18N("ui.settings.option.defrange_enemyground_descr"),
			onload = function(option)
				loadWidgetData("Defense Range GL4", "defrange_enemyground", { "enabled", "enemy", "ground" })
			end,
			onchange = function(option, value)
				--saveOptionValue('Defense Range', 'defrange', 'setEnemyGround', { 'enabled', 'enemy', 'ground' }, value)
				saveOptionValue(
					"Defense Range GL4",
					"defrange",
					"setEnemyGround",
					{ "enabled", "enemy", "ground" },
					value
				)
				saveOptionValue(
					"Defense Range GL4",
					"defrange",
					"setEnemyGround",
					{ "enabled", "enemy", "cannon" },
					value
				)
			end,
		},
		{
			id = "defrange_enemynuke",
			parent = "defrange",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.defrange_enemynuke"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.defrange_enemynuke_descr"),
			widgetConfig = {
				"Defense Range GL4",
				{ "enabled", "enemy", "nuke" },
				api = "defrange",
				get = "getEnemyNuke",
				set = "setEnemyNuke",
			},
		},
		{
			id = "defrange_enemylrpc",
			parent = "defrange",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.defrange_enemylrpc"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.defrange_enemylrpc_descr"),
			widgetConfig = {
				"Defense Range GL4",
				{ "enabled", "enemy", "lrpc" },
				api = "defrange",
				get = "getEnemyLRPC",
				set = "setEnemyLRPC",
			},
		},

		{
			id = "label_ui_spectator",
			group = "ui",
			name = BAR.I18N("ui.settings.option.label_spectator"),
			category = types.basic,
		},

		{
			id = "spectator_hud",
			group = "ui",
			category = types.basic,
			widget = "Spectator HUD",
			name = BAR.I18N("ui.settings.option.spectator_hud"),
			type = "bool",
			value = GetWidgetToggleValue("Spectator HUD"),
			description = BAR.I18N("ui.settings.option.spectator_hud_descr"),
		},
		{
			id = "spectator_hud_size",
			parent = "spectator_hud",
			group = "ui",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.spectator_hud_size"),
			type = "slider",
			min = 0.1,
			max = 2,
			step = 0.1,
			value = 0.8,
			description = "",
			widgetConfig = {
				"Spectator HUD",
				"widgetScale",
				api = "spectator_hud",
				get = "getWidgetSize",
				set = "setWidgetSize",
			},
		},

		{
			id = "spectator_hud_config",
			parent = "spectator_hud",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.spectator_hud_config"),
			type = "select",
			options = spectatorHUDConfigOptions,
			value = (WG.spectator_hud ~= nil and WG.spectator_hud.getConfig ~= nil and WG.spectator_hud.getConfig())
				or 1,
			description = BAR.I18N("ui.settings.option.spectator_hud_config_descr"),
			onload = function(option)
				loadWidgetData("Spectator HUD", "spectator_hud_config", { "widgetConfig" })
			end,
			onchange = function(option, value)
				saveOptionValue("Spectator HUD", "spectator_hud", "setConfig", { "widgetConfig" }, value)
				init()
			end,
		},

		{
			id = "spectator_hud_metric_metalIncome",
			parent = "spectator_hud",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.spectator_hud.metalIncome_title"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.spectator_hud.metalIncome_tooltip"),
			widgetConfig = {
				"Spectator HUD",
				{ "metricsEnabled", "metalIncome" },
				api = "spectator_hud",
				get = "getMetricEnabled",
				set = "setMetricEnabled",
				key = "metalIncome",
			},
		},
		{
			id = "spectator_hud_metric_energyIncome",
			parent = "spectator_hud",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.spectator_hud.energyIncome_title"),
			type = "bool",
			value = (
				WG.spectator_hud ~= nil
				and WG.spectator_hud.getMetricEnabled ~= nil
				and WG.spectator_hud.getMetricEnabled("energyIncome")
			) or false,
			description = BAR.I18N("ui.spectator_hud.energyIncome_tooltip"),
			onload = function(option)
				loadWidgetData(
					"Spectator HUD",
					"spectator_hud_metric_energyIncome",
					{ "metricsEnabled", "energyIncome" }
				)
			end,
			onchange = function(option, value)
				saveOptionValue(
					"Spectator HUD",
					"spectator_hud",
					"setMetricEnabled",
					{ "metricsEnabled", "energyIncome" },
					value,
					{ "energyIncome", value }
				)
			end,
		},
		{
			id = "spectator_hud_metric_buildPower",
			parent = "spectator_hud",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.spectator_hud.buildPower_title"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.spectator_hud.buildPower_tooltip"),
			widgetConfig = {
				"Spectator HUD",
				{ "metricsEnabled", "buildPower" },
				api = "spectator_hud",
				get = "getMetricEnabled",
				set = "setMetricEnabled",
				key = "buildPower",
			},
		},
		{
			id = "spectator_hud_metric_metalProduced",
			parent = "spectator_hud",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.spectator_hud.metalProduced_title"),
			type = "bool",
			value = (
				WG.spectator_hud ~= nil
				and WG.spectator_hud.getMetricEnabled ~= nil
				and WG.spectator_hud.getMetricEnabled("metalProduced")
			) or false,
			description = BAR.I18N("ui.spectator_hud.metalProduced_tooltip"),
			onload = function(option)
				loadWidgetData(
					"Spectator HUD",
					"spectator_hud_metric_metalProduced",
					{ "metricsEnabled", "metalProduced" }
				)
			end,
			onchange = function(option, value)
				saveOptionValue(
					"Spectator HUD",
					"spectator_hud",
					"setMetricEnabled",
					{ "metricsEnabled", "metalProduced" },
					value,
					{ "metalProduced", value }
				)
			end,
		},
		{
			id = "spectator_hud_metric_energyProduced",
			parent = "spectator_hud",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.spectator_hud.energyProduced_title"),
			type = "bool",
			value = (
				WG.spectator_hud ~= nil
				and WG.spectator_hud.getMetricEnabled ~= nil
				and WG.spectator_hud.getMetricEnabled("energyProduced")
			) or false,
			description = BAR.I18N("ui.spectator_hud.energyProduced_tooltip"),
			onload = function(option)
				loadWidgetData(
					"Spectator HUD",
					"spectator_hud_metric_energyProduced",
					{ "metricsEnabled", "energyProduced" }
				)
			end,
			onchange = function(option, value)
				saveOptionValue(
					"Spectator HUD",
					"spectator_hud",
					"setMetricEnabled",
					{ "metricsEnabled", "energyProduced" },
					value,
					{ "energyProduced", value }
				)
			end,
		},
		{
			id = "spectator_hud_metric_metalExcess",
			parent = "spectator_hud",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.spectator_hud.metalExcess_title"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.spectator_hud.metalExcess_tooltip"),
			widgetConfig = {
				"Spectator HUD",
				{ "metricsEnabled", "metalExcess" },
				api = "spectator_hud",
				get = "getMetricEnabled",
				set = "setMetricEnabled",
				key = "metalExcess",
			},
		},
		{
			id = "spectator_hud_metric_energyExcess",
			parent = "spectator_hud",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.spectator_hud.energyExcess_title"),
			type = "bool",
			value = (
				WG.spectator_hud ~= nil
				and WG.spectator_hud.getMetricEnabled ~= nil
				and WG.spectator_hud.getMetricEnabled("energyExcess")
			) or false,
			description = BAR.I18N("ui.spectator_hud.energyExcess_tooltip"),
			onload = function(option)
				loadWidgetData(
					"Spectator HUD",
					"spectator_hud_metric_energyExcess",
					{ "metricsEnabled", "energyExcess" }
				)
			end,
			onchange = function(option, value)
				saveOptionValue(
					"Spectator HUD",
					"spectator_hud",
					"setMetricEnabled",
					{ "metricsEnabled", "energyExcess" },
					value,
					{ "energyExcess", value }
				)
			end,
		},
		{
			id = "spectator_hud_metric_armyValue",
			parent = "spectator_hud",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.spectator_hud.armyValue_title"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.spectator_hud.armyValue_tooltip"),
			widgetConfig = {
				"Spectator HUD",
				{ "metricsEnabled", "armyValue" },
				api = "spectator_hud",
				get = "getMetricEnabled",
				set = "setMetricEnabled",
				key = "armyValue",
			},
		},
		{
			id = "spectator_hud_metric_defenseValue",
			parent = "spectator_hud",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.spectator_hud.defenseValue_title"),
			type = "bool",
			value = (
				WG.spectator_hud ~= nil
				and WG.spectator_hud.getMetricEnabled ~= nil
				and WG.spectator_hud.getMetricEnabled("defenseValue")
			) or false,
			description = BAR.I18N("ui.spectator_hud.defenseValue_tooltip"),
			onload = function(option)
				loadWidgetData(
					"Spectator HUD",
					"spectator_hud_metric_defenseValue",
					{ "metricsEnabled", "defenseValue" }
				)
			end,
			onchange = function(option, value)
				saveOptionValue(
					"Spectator HUD",
					"spectator_hud",
					"setMetricEnabled",
					{ "metricsEnabled", "defenseValue" },
					value,
					{ "defenseValue", value }
				)
			end,
		},
		{
			id = "spectator_hud_metric_utilityValue",
			parent = "spectator_hud",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.spectator_hud.utilityValue_title"),
			type = "bool",
			value = (
				WG.spectator_hud ~= nil
				and WG.spectator_hud.getMetricEnabled ~= nil
				and WG.spectator_hud.getMetricEnabled("utilityValue")
			) or false,
			description = BAR.I18N("ui.spectator_hud.utilityValue_tooltip"),
			onload = function(option)
				loadWidgetData(
					"Spectator HUD",
					"spectator_hud_metric_utilityValue",
					{ "metricsEnabled", "utilityValue" }
				)
			end,
			onchange = function(option, value)
				saveOptionValue(
					"Spectator HUD",
					"spectator_hud",
					"setMetricEnabled",
					{ "metricsEnabled", "utilityValue" },
					value,
					{ "utilityValue", value }
				)
			end,
		},
		{
			id = "spectator_hud_metric_economyValue",
			parent = "spectator_hud",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.spectator_hud.economyValue_title"),
			type = "bool",
			value = (
				WG.spectator_hud ~= nil
				and WG.spectator_hud.getMetricEnabled ~= nil
				and WG.spectator_hud.getMetricEnabled("economyValue")
			) or false,
			description = BAR.I18N("ui.spectator_hud.economyValue_tooltip"),
			onload = function(option)
				loadWidgetData(
					"Spectator HUD",
					"spectator_hud_metric_economyValue",
					{ "metricsEnabled", "economyValue" }
				)
			end,
			onchange = function(option, value)
				saveOptionValue(
					"Spectator HUD",
					"spectator_hud",
					"setMetricEnabled",
					{ "metricsEnabled", "economyValue" },
					value,
					{ "economyValue", value }
				)
			end,
		},
		{
			id = "spectator_hud_metric_damageDealt",
			parent = "spectator_hud",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.spectator_hud.damageDealt_title"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.spectator_hud.damageDealt_tooltip"),
			widgetConfig = {
				"Spectator HUD",
				{ "metricsEnabled", "damageDealt" },
				api = "spectator_hud",
				get = "getMetricEnabled",
				set = "setMetricEnabled",
				key = "damageDealt",
			},
		},

		-- SQUAD HULLS (widget: "Squad Selection", WG['squadselection']).
		{
			id = "label_squad_hulls",
			group = "ui",
			name = BAR.I18N("ui.settings.option.squadSelection_header_hulls"),
			category = types.basic,
		},
		{
			id = "squad_hullDisplayMode",
			group = "ui",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.squadSelection_hullDisplayMode"),
			type = "select",
			options = {
				BAR.I18N("ui.settings.option.squadSelection_hullDisplayMode_opt1"),
				BAR.I18N("ui.settings.option.squadSelection_hullDisplayMode_opt2"),
				BAR.I18N("ui.settings.option.squadSelection_hullDisplayMode_opt3"),
			},
			value = squadSelectValue.hullDisplayMode(),
			description = BAR.I18N("ui.settings.option.squadSelection_hullDisplayMode_descr"),
			onload = function(option)
				option.value = squadSelectValue.hullDisplayMode()
			end,
			onchange = function(_, value)
				saveOptionValue(
					"Squad Selection",
					"squadselection",
					"setVisualizationMode",
					{ "visualizationMode" },
					value == 1 and "none" or "convexHull"
				)
				saveOptionValue(
					"Squad Selection",
					"squadselection",
					"setShowReserveSquads",
					{ "showReserveSquads" },
					value == 2
				)
				if widgetHandler:IsWidgetKnown("Squad Selection Hull") then
					if value == 1 then
						widgetHandler:DisableWidget("Squad Selection Hull")
					else
						widgetHandler:EnableWidget("Squad Selection Hull")
					end
				end
				scheduleInit = true
			end,
		},

		{
			id = "squad_convexHullPadding",
			parent = "squad_hullDisplayMode",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.squadSelectionHull_Padding"),
			type = "slider",
			min = 0,
			max = 200,
			step = 5,
			value = 60,
			description = BAR.I18N("ui.settings.option.squadSelectionHull_Padding_descr"),
			widgetConfig = {
				"Squad Selection Hull",
				"convexHullPadding",
				api = "squadselectionhull",
				get = "getConvexHullPadding",
				set = "setConvexHullPadding",
			},
		},

		{
			id = "squad_convexHullArcResolution",
			parent = "squad_hullDisplayMode",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.squadSelectionHull_ArcResolution"),
			type = "slider",
			min = 0.05,
			max = 1.0,
			step = 0.05,
			value = 0.4,
			description = BAR.I18N("ui.settings.option.squadSelectionHull_ArcResolution_descr"),
			widgetConfig = {
				"Squad Selection Hull",
				"convexHullArcResolution",
				api = "squadselectionhull",
				get = "getConvexHullArcResolution",
				set = "setConvexHullArcResolution",
			},
		},

		{
			id = "squad_convexHullFillOpacity",
			parent = "squad_hullDisplayMode",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.squadSelectionHull_FillOpacity"),
			type = "slider",
			min = 0,
			max = 1,
			step = 0.05,
			value = 0.25,
			description = BAR.I18N("ui.settings.option.squadSelectionHull_FillOpacity_descr"),
			widgetConfig = {
				"Squad Selection Hull",
				"convexHullFillOpacity",
				api = "squadselectionhull",
				get = "getConvexHullFillOpacity",
				set = "setConvexHullFillOpacity",
			},
		},

		{
			id = "squad_convexHullBorderOpacity",
			parent = "squad_hullDisplayMode",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.squadSelectionHull_BorderOpacity"),
			type = "slider",
			min = 0,
			max = 1,
			step = 0.05,
			value = 0.3,
			widgetConfig = {
				"Squad Selection Hull",
				"convexHullBorderOpacity",
				api = "squadselectionhull",
				get = "getConvexHullBorderOpacity",
				set = "setConvexHullBorderOpacity",
			},
		},

		{
			id = "squad_convexHullBorderThickness",
			parent = "squad_hullDisplayMode",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.squadSelectionHull_BorderThickness"),
			type = "slider",
			min = 0.5,
			max = 5,
			step = 0.5,
			value = (
				WG["squadselectionhull"] ~= nil
				and WG["squadselectionhull"].getConvexHullBorderThickness ~= nil
				and WG["squadselectionhull"].getConvexHullBorderThickness()
			) or 2,
			onload = function(option)
				loadWidgetData(
					"Squad Selection Hull",
					"squad_convexHullBorderThickness",
					{ "convexHullBorderThickness" }
				)
			end,
			onchange = function(_, value)
				saveOptionValue(
					"Squad Selection Hull",
					"squadselectionhull",
					"setConvexHullBorderThickness",
					{ "convexHullBorderThickness" },
					value
				)
			end,
		},
		{
			id = "squad_convexHullColorMode",
			parent = "squad_hullDisplayMode",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.squadSelection_squadColorMode"),
			type = "select",
			options = {
				BAR.I18N("ui.settings.option.squadSelection_squadColorMode_opt1"),
				BAR.I18N("ui.settings.option.squadSelection_squadColorMode_opt2"),
				BAR.I18N("ui.settings.option.squadSelection_squadColorMode_opt3"),
			},
			value = squadSelectValue.squadColorMode(),
			description = BAR.I18N("ui.settings.option.squadSelection_squadColorMode_descr"),
			onload = function(option)
				option.value = squadSelectValue.squadColorMode()
			end,
			onchange = function(_, value)
				local modes = { "player", "custom", "squad" }
				saveOptionValue(
					"Squad Selection",
					"squadselection",
					"setSquadColorMode",
					{ "squadColorMode" },
					modes[value] or "player"
				)
			end,
		},

		{
			id = "squad_convexHullCustomColor",
			parent = "squad_hullDisplayMode",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.squadSelection_squadCustomColor"),
			type = "color",
			max = 1,
			step = 0.01,
			value = squadSelectValue.customColor(),
			description = BAR.I18N("ui.settings.option.squadSelection_squadCustomColor_descr"),
			onchange = function(_, value)
				for i, channel in ipairs({ "R", "G", "B" }) do
					saveOptionValue(
						"Squad Selection",
						"squadselection",
						"setSquadCustomColor" .. channel,
						{ "squadCustomColor" .. channel },
						value[i]
					)
				end
			end,
		},

		{
			id = "label_ui_developer",
			group = "ui",
			available = not devMode,
			name = BAR.I18N("ui.settings.option.label_developer"),
			category = types.advanced,
		},

		{
			id = "devmode",
			group = "ui",
			category = types.advanced,
			available = not devMode,
			name = BAR.I18N("ui.settings.option.devmode"),
			type = "bool",
			value = devUI,
			description = BAR.I18N("ui.settings.option.devmode_descr"),
			onchange = function(option, value)
				devUI = value
				Spring.SetConfigInt("DevUI", value and 1 or 0)
				Spring.SendCommands("luaui reload")
			end,
		},

		-- GAME
		{
			id = "networksmoothing",
			restart = not Engine.FeatureSupport.liveConfigChanges,
			category = types.basic,
			group = "game",
			name = BAR.I18N("ui.settings.option.networksmoothing"),
			type = "bool",
			value = useNetworkSmoothing,
			description = BAR.I18N("ui.settings.option.networksmoothing_descr"),
			onload = function(option)
				option.onchange(option, option.value)
			end,
			onchange = function(option, value)
				useNetworkSmoothing = value
				if useNetworkSmoothing then
					Spring.SetConfigInt("UseNetMessageSmoothingBuffer", 1)
					Spring.SetConfigInt("NetworkLossFactor", 0)
					Spring.SetConfigInt("LinkOutgoingBandwidth", 196608)
					Spring.SetConfigInt("LinkIncomingSustainedBandwidth", 196608)
					Spring.SetConfigInt("LinkIncomingPeakBandwidth", 196608)
					Spring.SetConfigInt("LinkIncomingMaxPacketRate", 1024)
				else
					Spring.SetConfigInt("UseNetMessageSmoothingBuffer", 0)
					Spring.SetConfigInt("NetworkLossFactor", 2)
					Spring.SetConfigInt("LinkOutgoingBandwidth", 196608)
					Spring.SetConfigInt("LinkIncomingSustainedBandwidth", 1048576)
					Spring.SetConfigInt("LinkIncomingPeakBandwidth", 1048576)
					Spring.SetConfigInt("LinkIncomingMaxPacketRate", 2048)
				end
			end,
		},
		{
			id = "autoquit",
			group = "game",
			category = types.basic,
			widget = "Autoquit",
			name = BAR.I18N("ui.settings.option.autoquit"),
			type = "bool",
			value = GetWidgetToggleValue("Autoquit"),
			description = BAR.I18N("ui.settings.option.autoquit_descr"),
		},

		{
			id = "singleplayerpause",
			group = "game",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.singleplayerpause"),
			type = "bool",
			value = Spring.GetConfigInt("WindowsPauseGame", 1) == 1,
			description = BAR.I18N("ui.settings.option.singleplayerpause_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("WindowsPauseGame", (value and 1 or 0))
				-- pushed through as well so it takes effect now instead of at the next poll
				widgetHandler:SetWindowsPauseGame(value)
			end,
		},

		{
			id = "catchupsmoothness",
			group = "game",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.catchupsmoothness"),
			restart = not Engine.FeatureSupport.liveConfigChanges,
			type = "slider",
			min = 0.05,
			max = 0.3,
			step = 0.01,
			value = 0.15,
			description = BAR.I18N("ui.settings.option.catchupsmoothness_descr"),
			configFloat = "MinSimDrawBalance",
		},
		{
			id = "catchupminfps",
			group = "game",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.catchupminfps"),
			restart = not Engine.FeatureSupport.liveConfigChanges,
			type = "slider",
			min = 2,
			max = 15,
			step = 1,
			value = 2,
			description = BAR.I18N("ui.settings.option.catchupminfps_descr"),
			configInt = "MinDrawFPS",
		},

		{
			id = "label_ui_behavior",
			group = "game",
			name = BAR.I18N("ui.settings.option.label_behavior"),
			category = types.basic,
		},

		{
			id = "smartselect_includebuildings",
			group = "game",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.smartselect_includebuildings"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.smartselect_includebuildings_descr"),
			onchange = function(option, value)
				saveOptionValue(
					"SmartSelect",
					"smartselect",
					"setIncludeBuildings",
					{ "selectBuildingsWithMobile" },
					value
				)
			end,
		},
		{
			id = "smartselect_includebuilders",
			parent = "smartselect_includebuildings",
			group = "game",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.smartselect_includebuilders"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.smartselect_includebuilders_descr"),
			onchange = function(option, value)
				saveOptionValue("SmartSelect", "smartselect", "setIncludeBuilders", { "includeBuilders" }, value)
			end,
		},
		{
			id = "smartselect_includeresurrectors",
			parent = "smartselect_includebuildings",
			group = "game",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.smartselect_includeresurrectors"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.smartselect_includeresurrectors_descr"),
			onchange = function(option, value)
				saveOptionValue(
					"SmartSelect",
					"smartselect",
					"setIncludeResurrectors",
					{ "includeResurrectors" },
					value
				)
			end,
		},
		{
			id = "smartselect_includeantinuke",
			parent = "smartselect_includebuildings",
			group = "game",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.smartselect_includeantinuke"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.smartselect_includeantinuke_descr"),
			onchange = function(option, value)
				saveOptionValue("SmartSelect", "smartselect", "setIncludeAntinuke", { "includeAntinuke" }, value)
			end,
		},
		{
			id = "smartselect_includeradar",
			parent = "smartselect_includebuildings",
			group = "game",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.smartselect_includeradar"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.smartselect_includeradar_descr"),
			onchange = function(option, value)
				saveOptionValue("SmartSelect", "smartselect", "setIncludeRadar", { "includeRadar" }, value)
			end,
		},
		{
			id = "smartselect_includejammer",
			parent = "smartselect_includebuildings",
			group = "game",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.smartselect_includejammer"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.smartselect_includejammer_descr"),
			onchange = function(option, value)
				saveOptionValue("SmartSelect", "smartselect", "setIncludeJammer", { "includeJammer" }, value)
			end,
		},

		{
			id = "prioconturrets",
			group = "game",
			category = types.basic,
			widget = "Priority Construction Turrets",
			name = BAR.I18N("ui.settings.option.prioconturrets"),
			type = "bool",
			value = GetWidgetToggleValue("Priority Construction Turrets"),
			description = BAR.I18N("ui.settings.option.prioconturrets_descr"),
		},

		{
			id = "builderpriority",
			group = "game",
			category = types.basic,
			widget = "Builder Priority",
			name = BAR.I18N("ui.settings.option.builderpriority"),
			type = "bool",
			value = GetWidgetToggleValue("Builder Priority"),
			description = BAR.I18N("ui.settings.option.builderpriority_descr"),
		},

		{
			id = "builderpriority_nanos",
			parent = "builderpriority",
			group = "game",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.builderpriority_nanos"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.builderpriority_nanos_descr"),
			widgetConfig = {
				"Builder Priority",
				"lowpriorityNanos",
				api = "builderpriority",
				get = "getLowPriorityNanos",
				set = "setLowPriorityNanos",
			},
		},

		{
			id = "builderpriority_cons",
			parent = "builderpriority",
			group = "game",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.builderpriority_cons"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.builderpriority_cons_descr"),
			widgetConfig = {
				"Builder Priority",
				"lowpriorityCons",
				api = "builderpriority",
				get = "getLowPriorityCons",
				set = "setLowPriorityCons",
			},
		},

		{
			id = "builderpriority_labs",
			parent = "builderpriority",
			group = "game",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.builderpriority_labs"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.builderpriority_labs_descr"),
			widgetConfig = {
				"Builder Priority",
				"lowpriorityLabs",
				api = "builderpriority",
				get = "getLowPriorityLabs",
				set = "setLowPriorityLabs",
			},
		},

		{
			id = "factoryguard",
			group = "game",
			category = types.basic,
			widget = "Factory Guard Default On",
			prefix = BAR.I18N("ui.settings.option.factory"),
			name = BAR.I18N("ui.settings.option.factoryguard"),
			type = "bool",
			value = GetWidgetToggleValue("Factory Guard Default On"),
			description = BAR.I18N("ui.settings.option.factoryguard_descr"),
		},
		{
			id = "factoryholdpos",
			parent = "factoryguard",
			group = "game",
			category = types.basic,
			widget = "Factory hold position",
			name = BAR.I18N("ui.settings.option.factoryholdpos"),
			type = "bool",
			value = GetWidgetToggleValue("Factory hold position"),
			description = BAR.I18N("ui.settings.option.factoryholdpos_descr"),
		},
		{
			id = "factoryrepeat",
			parent = "factoryguard",
			group = "game",
			category = types.basic,
			widget = "Factory Auto-Repeat",
			name = BAR.I18N("ui.settings.option.factoryrepeat"),
			type = "bool",
			value = GetWidgetToggleValue("Factory Auto-Repeat"),
			description = BAR.I18N("ui.settings.option.factoryrepeat_descr"),
		},
		{
			id = "factorypreset",
			group = "game",
			category = types.basic,
			widget = "FactoryQ Manager",
			name = BAR.I18N("ui.settings.option.factorypreset"),
			type = "bool",
			value = GetWidgetToggleValue("FactoryQ Manager"),
			description = BAR.I18N("ui.settings.option.factorypreset_descr"),
		},

		{
			id = "transportOrderedUnits",
			group = "game",
			category = types.basic,
			name = "Ferry ignores units with manual orders",
			type = "bool",
			value = (
				WG.transportFactoryGuard ~= nil
				and WG.transportFactoryGuard.getBlacklistOrderedUnits ~= nil
				and WG.transportFactoryGuard.getBlacklistOrderedUnits()
			),
			description = "If enabled, transports guarding factories will not transport units that were given explicit orders during construction to their move waypoint.",
			onload = function(option)
				loadWidgetData("Transport Factory Guard", "transportOrderedUnits", { "blacklistOrderedUnits" })
			end,
			onchange = function(_, value)
				saveOptionValue(
					"Transport Factory Guard",
					"transportFactoryGuard",
					"setBlacklistOrderedUnits",
					{ "blacklistOrderedUnits" },
					value
				)
				if WG.transportFactoryGuard and WG.transportFactoryGuard.setBlacklistOrderedUnits then
					WG.transportFactoryGuard.setBlacklistOrderedUnits(value)
				end
			end,
		},

		{
			id = "onlyfighterspatrol",
			group = "game",
			category = types.basic,
			widget = "OnlyFightersPatrol",
			name = BAR.I18N("ui.settings.option.onlyfighterspatrol"),
			type = "bool",
			value = GetWidgetToggleValue("OnlyFightersPatrol"),
			description = BAR.I18N("ui.settings.option.onlyfighterspatrol_descr"),
		},
		{
			id = "bombers_default_hold_fire",
			group = "game",
			category = types.basic,
			widget = "BombersDefaultHoldFire",
			name = BAR.I18N("ui.settings.option.bombers_default_hold_fire"),
			type = "bool",
			value = GetWidgetToggleValue("BombersDefaultHoldFire"),
			description = BAR.I18N("ui.settings.option.bombers_default_hold_fire_descr"),
		},
		{
			id = "fightersfly",
			group = "game",
			category = types.basic,
			widget = "Set fighters on Fly mode",
			name = BAR.I18N("ui.settings.option.fightersfly"),
			type = "bool",
			value = GetWidgetToggleValue("Set fighters on Fly mode"),
			description = BAR.I18N("ui.settings.option.fightersfly_descr"),
		},

		{
			id = "settargetdefault",
			group = "game",
			category = types.basic,
			widget = "Set target default",
			name = BAR.I18N("ui.settings.option.settargetdefault"),
			type = "bool",
			value = GetWidgetToggleValue("Set target default"),
			description = BAR.I18N("ui.settings.option.settargetdefault_descr"),
		},
		{
			id = "dgunnogroundenemies",
			group = "game",
			category = types.advanced,
			widget = "DGun no ground enemies",
			name = BAR.I18N("ui.settings.option.dgunnogroundenemies"),
			type = "bool",
			value = GetWidgetToggleValue("DGun no ground enemies"),
			description = BAR.I18N("ui.settings.option.dgunnogroundenemies_descr"),
		},
		{
			id = "dgunstallassist",
			group = "game",
			category = types.advanced,
			widget = "DGun Stall Assist",
			name = BAR.I18N("ui.settings.option.dgunstallassist"),
			type = "bool",
			value = GetWidgetToggleValue("DGun Stall Assist"),
			description = BAR.I18N("ui.settings.option.dgunstallassist_descr"),
		},

		{
			id = "autogroup_immediate",
			group = "game",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.autogroup_immediate"),
			type = "bool",
			value = (WG.autogroup ~= nil and WG.autogroup.getImmediate ~= nil and WG.autogroup.getImmediate()),
			description = BAR.I18N("ui.settings.option.autogroup_immediate_descr"),
			onload = function(option)
				loadWidgetData("Auto Group", "autogroup_immediate", { "immediate" })
			end,
			onchange = function(option, value)
				if widgetHandler.configData["Auto Group"] == nil then
					widgetHandler.configData["Auto Group"] = {}
				end
				widgetHandler.configData["Auto Group"].immediate = value
				saveOptionValue("Auto Group", "autogroup", "setImmediate", { "immediate" }, value)
			end,
		},

		{
			id = "autogroup_persist",
			group = "game",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.autogroup_persist"),
			type = "bool",
			value = (WG.autogroup ~= nil and WG.autogroup.getPersist ~= nil and WG.autogroup.getPersist()),
			description = BAR.I18N("ui.settings.option.autogroup_persist_descr"),
			onload = function(option)
				loadWidgetData("Auto Group", "autogroup_persist", { "persist" })
			end,
			onchange = function(option, value)
				if widgetHandler.configData["Auto Group"] == nil then
					widgetHandler.configData["Auto Group"] = {}
				end
				widgetHandler.configData["Auto Group"].persist = value
				saveOptionValue("Auto Group", "autogroup", "setPersist", { "persist" }, value)
			end,
		},
		{
			id = "quickstartsuggestions",
			group = "game",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.quickstartsuggestions"),
			type = "bool",
			value = Spring.GetConfigInt("QuickStartSuggestions", 1) == 1,
			description = BAR.I18N("ui.settings.option.quickstartsuggestions_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("QuickStartSuggestions", value and 1 or 0)
				if WG.quickStart and WG.quickStart.setAutoGenerateSuggestions then
					WG.quickStart.setAutoGenerateSuggestions(value)
				end
			end,
		},

		{
			id = "label_ui_cloak",
			group = "game",
			name = BAR.I18N("ui.settings.option.label_cloak"),
			category = types.basic,
		},

		{
			id = "autocloak",
			group = "game",
			category = types.basic,
			widget = "Auto Cloak Units",
			name = BAR.I18N("ui.settings.option.autocloak"),
			type = "bool",
			value = GetWidgetToggleValue("Auto Cloak Units"),
		},

		-- SQUAD SELECTION (widget: "Squad Selection", WG['squadselection'])
		{
			id = "label_squad",
			group = "game",
			name = BAR.I18N("ui.settings.option.squadSelection_header"),
			category = types.basic,
		},

		-- Playstyle preset. Off disables the widgets entirely (the default), every other value enables them and writes the settings it owns.
		{
			id = "squad_preset",
			group = "game",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.squadSelection_preset"),
			type = "select",
			options = {
				BAR.I18N("ui.settings.option.squadSelection_preset_opt1"),
				BAR.I18N("ui.settings.option.squadSelection_preset_opt2"),
				BAR.I18N("ui.settings.option.squadSelection_preset_opt3"),
				BAR.I18N("ui.settings.option.squadSelection_preset_opt4"),
				BAR.I18N("ui.settings.option.squadSelection_preset_opt5"),
			},
			value = squadPreset.index[squadPreset.get()] or 1,
			description = BAR.I18N("ui.settings.option.squadSelection_preset_descr"),
			onload = function(option)
				option.value = squadPreset.index[squadPreset.get()] or 1
			end,
			onchange = function(_, value)
				-- Toggles widgets, so it schedules the rebuild for next frame rather than rebuilding here. See squadPreset.apply().
				squadPreset.apply(squadPreset.names[value] or "off")
			end,
		},

		{
			id = "squad_cyclingToNextSquad",
			group = "game",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.squadSelection_cyclingToNextSquad"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.squadSelection_cyclingToNextSquad_descr"),
			widgetConfig = {
				"Squad Selection",
				"cyclingToNextSquad",
				api = "squadselection",
				get = "getCyclingToNextSquad",
				set = "setCyclingToNextSquad",
			},
		},

		{
			id = "squad_leftClickSelectsSquad",
			group = "game",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.squadSelection_leftClickSelectsSquad"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.squadSelection_leftClickSelectsSquad_descr"),
			widgetConfig = {
				"Squad Selection",
				"leftClickSelectsSquad",
				api = "squadselection",
				get = "getLeftClickSelectsSquad",
				set = "setLeftClickSelectsSquad",
			},
		},

		{
			id = "squad_leftClickAlternativeSelection",
			parent = "squad_leftClickSelectsSquad",
			group = "game",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.squadSelection_leftClickAlternativeSelection"),
			type = "bool",
			value = squadSelectValue.get("getLeftClickAlternativeSelection") or false,
			description = BAR.I18N("ui.settings.option.squadSelection_leftClickAlternativeSelection_descr"),
			onload = function(option)
				loadWidgetData(
					"Squad Selection",
					"squad_leftClickAlternativeSelection",
					{ "leftClickAlternativeSelection" }
				)
			end,
			onchange = function(_, value)
				saveOptionValue(
					"Squad Selection",
					"squadselection",
					"setLeftClickAlternativeSelection",
					{ "leftClickAlternativeSelection" },
					value
				)
			end,
		},

		-- Synthetic select owning the three mutually-exclusive rightClick* booleans.
		{
			id = "squad_squadCreateMethod",
			group = "game",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.squadSelection_squadCreateMethod"),
			type = "select",
			options = {
				BAR.I18N("ui.settings.option.squadSelection_squadCreateMethod_opt1"),
				BAR.I18N("ui.settings.option.squadSelection_squadCreateMethod_opt2"),
				BAR.I18N("ui.settings.option.squadSelection_squadCreateMethod_opt3"),
				BAR.I18N("ui.settings.option.squadSelection_squadCreateMethod_opt4"),
			},
			value = squadSelectValue.squadCreateMethod(),
			description = BAR.I18N("ui.settings.option.squadSelection_squadCreateMethod_descr"),
			onload = function(option)
				option.value = squadSelectValue.squadCreateMethod()
			end,
			onchange = function(_, value)
				saveOptionValue(
					"Squad Selection",
					"squadselection",
					"setRightClickSquadCreate",
					{ "rightClickSquadCreate" },
					value == 2
				)
				saveOptionValue(
					"Squad Selection",
					"squadselection",
					"setCtrlRightClickCreatesSquad",
					{ "ctrlRightClickCreatesSquad" },
					value == 3
				)
				saveOptionValue(
					"Squad Selection",
					"squadselection",
					"setCtrlRightClickDragCreatesSquad",
					{ "ctrlRightClickDragCreatesSquad" },
					value == 4
				)
			end,
		},

		{
			id = "squad_rightClickMovesSquad",
			group = "game",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.squadSelection_rightClickMovesSquad"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.squadSelection_rightClickMovesSquad_descr"),
			widgetConfig = {
				"Squad Selection",
				"rightClickMovesSquad",
				api = "squadselection",
				get = "getRightClickMovesSquad",
				set = "setRightClickMovesSquad",
			},
		},

		-- Synthetic select owning the rightClickMoveControlsReserves boolean.
		{
			id = "squad_rightClickMoveControlsReserves",
			parent = "squad_rightClickMovesSquad",
			group = "game",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.squadSelection_rightClickMoveControlsReserves"),
			type = "select",
			options = {
				BAR.I18N("ui.settings.option.squadSelection_rightClickMoveControlsReserves_opt1"),
				BAR.I18N("ui.settings.option.squadSelection_rightClickMoveControlsReserves_opt2"),
			},
			value = squadSelectValue.rightClickMoveControlsReserves(),
			description = BAR.I18N("ui.settings.option.squadSelection_rightClickMoveControlsReserves_descr"),
			onload = function(option)
				option.value = squadSelectValue.rightClickMoveControlsReserves()
			end,
			onchange = function(_, value)
				saveOptionValue(
					"Squad Selection",
					"squadselection",
					"setRightClickMoveControlsReserves",
					{ "rightClickMoveControlsReserves" },
					value == 2
				)
			end,
		},

		{
			id = "squad_mergeIntoReserves",
			group = "game",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.squadSelection_mergeIntoReserves"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.squadSelection_mergeIntoReserves_descr"),
			widgetConfig = {
				"Squad Selection",
				"mergeIntoReserves",
				api = "squadselection",
				get = "getMergeIntoReserves",
				set = "setMergeIntoReserves",
			},
		},

		{
			id = "squad_mruSize",
			group = "game",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.squadSelection_mruSize"),
			type = "slider",
			min = 1,
			max = 9,
			step = 1,
			value = 3,
			description = BAR.I18N("ui.settings.option.squadSelection_mruSize_descr"),
			widgetConfig = {
				"Squad Selection",
				"mruSize",
				api = "squadselection",
				get = "getMruSize",
				set = "setMruSize",
			},
		},

		{
			id = "squad_excludeConstructors",
			group = "game",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.squadSelection_excludeConstructors"),
			type = "bool",
			value = squadSelectValue.get("getExcludeConstructors") or false,
			description = BAR.I18N("ui.settings.option.squadSelection_excludeConstructors_descr"),
			onload = function(option)
				loadWidgetData("Squad Selection", "squad_excludeConstructors", { "excludeConstructors" })
			end,
			onchange = function(_, value)
				saveOptionValue(
					"Squad Selection",
					"squadselection",
					"setExcludeConstructors",
					{ "excludeConstructors" },
					value
				)
				if WG["squadselection"] ~= nil and WG["squadselection"].rebuildTracking ~= nil then
					WG["squadselection"].rebuildTracking()
				end
			end,
		},

		{
			id = "squad_excludeResurrectionUnits",
			group = "game",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.squadSelection_excludeResurrectionUnits"),
			type = "bool",
			value = squadSelectValue.get("getExcludeResurrectionUnits") or false,
			description = BAR.I18N("ui.settings.option.squadSelection_excludeResurrectionUnits_descr"),
			onload = function(option)
				loadWidgetData("Squad Selection", "squad_excludeResurrectionUnits", { "excludeResurrectionUnits" })
			end,
			onchange = function(_, value)
				saveOptionValue(
					"Squad Selection",
					"squadselection",
					"setExcludeResurrectionUnits",
					{ "excludeResurrectionUnits" },
					value
				)
				if WG["squadselection"] ~= nil and WG["squadselection"].rebuildTracking ~= nil then
					WG["squadselection"].rebuildTracking()
				end
			end,
		},

		{
			id = "squad_excludeCombatEngineers",
			group = "game",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.squadSelection_excludeCombatEngineers"),
			type = "bool",
			value = squadSelectValue.get("getExcludeCombatEngineers") or false,
			description = BAR.I18N("ui.settings.option.squadSelection_excludeCombatEngineers_descr"),
			onload = function(option)
				loadWidgetData("Squad Selection", "squad_excludeCombatEngineers", { "excludeCombatEngineers" })
			end,
			onchange = function(_, value)
				saveOptionValue(
					"Squad Selection",
					"squadselection",
					"setExcludeCombatEngineers",
					{ "excludeCombatEngineers" },
					value
				)
				if WG["squadselection"] ~= nil and WG["squadselection"].rebuildTracking ~= nil then
					WG["squadselection"].rebuildTracking()
				end
			end,
		},

		-- ACCESSIBILITY

		{
			id = "label_teamcolors",
			group = "accessibility",
			name = BAR.I18N("ui.settings.option.label_teamcolors"),
			category = types.basic,
		},

		{
			id = "anonymous_color",
			parent = "label_teamcolors",
			group = "accessibility",
			category = types.basic,
			available = anonymousMode ~= "disabled",
			name = BAR.I18N("ui.settings.option.anonymous_color"),
			type = "color",
			max = 255,
			step = 1,
			value = { 255, 0, 0 },
			configInt = { "anonymousColorR", "anonymousColorG", "anonymousColorB" },
			description = BAR.I18N("ui.settings.option.anonymous_descr"),
			onchange = function(option, value, force)
				if force then
					Spring.SendCommands("luarules reloadluaui")
				else
					sceduleOptionApply = { os.clock() + 1.5, "anonymous_color" }
				end
			end,
		},

		{
			id = "simpleteamcolors",
			group = "accessibility",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.playercolors"),
			type = "bool",
			value = tonumber(Spring.GetConfigInt("SimpleTeamColors", 0) or 0) == 1,
			description = BAR.I18N("ui.settings.option.simpleteamcolors_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("SimpleTeamColors", (value and 1 or 0))
				Spring.SetConfigInt("UpdateTeamColors", 1)
			end,
		},

		{
			id = "simpleteamcolors_reset",
			parent = "simpleteamcolors",
			group = "accessibility",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.simpleteamcolors_reset"),
			type = "bool",
			value = false,
			onchange = function(option, value)
				Spring.SetConfigInt("SimpleTeamColorsUseGradient", 0)
				getOption("simpleteamcolors_use_gradient").value = false
				for id, default in pairs({
					simpleteamcolors_player = { 0, 77, 255 },
					simpleteamcolors_ally = { 0, 255, 0 },
					simpleteamcolors_enemy = { 255, 16, 5 },
				}) do
					local color = getOption(id)
					for i, key in ipairs(color.configInt) do
						Spring.SetConfigInt(key, default[i])
					end
					color.value = default
				end
				option.value = false -- a button, not a setting
				Spring.SetConfigInt("UpdateTeamColors", 1)
			end,
		},
		{
			id = "simpleteamcolors_use_gradient",
			parent = "simpleteamcolors",
			group = "accessibility",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.simpleteamcolors_use_gradient"),
			type = "bool",
			value = tonumber(Spring.GetConfigInt("SimpleTeamColorsUseGradient", 0) or 0) == 1,
			onchange = function(option, value)
				Spring.SetConfigInt("SimpleTeamColorsUseGradient", (value and 1 or 0))
				Spring.SetConfigInt("UpdateTeamColors", 1)
			end,
		},
		{
			id = "simpleteamcolorsfactionspecific",
			parent = "simpleteamcolors",
			group = "accessibility",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.simpleteamcolorsfactionspecific"),
			type = "bool",
			value = tonumber(Spring.GetConfigInt("SimpleTeamColorsFactionSpecific", 0) or 0) == 1,
			description = BAR.I18N("ui.settings.option.simpleteamcolorsfactionspecific_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("SimpleTeamColorsFactionSpecific", (value and 1 or 0))
				Spring.SetConfigInt("UpdateTeamColors", 1)
			end,
		},
		{
			id = "simpleteamcolors_player",
			parent = "simpleteamcolors",
			group = "accessibility",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.simpleteamcolors_player"),
			type = "color",
			max = 255,
			step = 1,
			value = { 0, 77, 255 },
			configInt = { "SimpleTeamColorsPlayerR", "SimpleTeamColorsPlayerG", "SimpleTeamColorsPlayerB" },
			onchange = function()
				Spring.SetConfigInt("UpdateTeamColors", 1)
			end,
		},
		{
			id = "simpleteamcolors_ally",
			parent = "simpleteamcolors",
			group = "accessibility",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.simpleteamcolors_ally"),
			type = "color",
			max = 255,
			step = 1,
			value = { 0, 255, 0 },
			configInt = { "SimpleTeamColorsAllyR", "SimpleTeamColorsAllyG", "SimpleTeamColorsAllyB" },
			onchange = function()
				Spring.SetConfigInt("UpdateTeamColors", 1)
			end,
		},
		{
			id = "simpleteamcolors_enemy",
			parent = "simpleteamcolors",
			group = "accessibility",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.simpleteamcolors_enemy"),
			type = "color",
			max = 255,
			step = 1,
			value = { 255, 16, 5 },
			configInt = { "SimpleTeamColorsEnemyR", "SimpleTeamColorsEnemyG", "SimpleTeamColorsEnemyB" },
			onchange = function()
				Spring.SetConfigInt("UpdateTeamColors", 1)
			end,
		},

		-- DEV
		{
			id = "customwidgets",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.customwidgets"),
			type = "bool",
			value = widgetHandler.allowUserWidgets,
			description = BAR.I18N("ui.settings.option.customwidgets_descr"),
			onchange = function(option, value)
				widgetHandler.__allowUserWidgets = value
				Spring.SendCommands("luarules reloadluaui")
			end,
		},

		{
			id = "autocheat",
			group = "dev",
			category = types.dev,
			widget = "Dev Auto cheat",
			name = BAR.I18N("ui.settings.option.autocheat"),
			type = "bool",
			value = GetWidgetToggleValue("Dev Auto cheat"),
			description = BAR.I18N("ui.settings.option.autocheat_descr"),
		},
		{
			id = "restart",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.restart"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.restart_descr"),
			onchange = function(option, value)
				option.value = false
				Spring.Restart("", startScript)
			end,
		},
		{
			id = "restart_with_state",
			group = "dev",
			category = types.dev,
			available = isSinglePlayer,
			name = BAR.I18N("ui.settings.option.restart_with_state"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.restart_with_state_descr"),
			onchange = function(option, value)
				option.value = false
				Spring.SendLuaRulesMsg("restart_with_state")
			end,
		},

		{
			id = "label_dev_debug",
			group = "dev",
			name = BAR.I18N("ui.settings.option.label_debug"),
			category = types.dev,
		},

		{
			id = "profiler_widget",
			group = "dev",
			category = types.dev,
			widget = "Widget Profiler",
			prefix = BAR.I18N("ui.settings.option.profiler"),
			name = BAR.I18N("ui.settings.option.profiler_widget"),
			type = "bool",
			value = GetWidgetToggleValue("Widget Profiler"),
		},
		{
			id = "profiler_gadget",
			parent = "profiler_widget",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.profiler_gadget"),
			type = "bool",
			value = false,
			onchange = function(option, value)
				Spring.SendCommands("luarules profile")
			end,
		},
		{
			id = "profiler_sort_by_load",
			parent = "profiler_widget",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.profiler_sort_by_load"),
			type = "bool",
			value = true,
			description = BAR.I18N("ui.settings.option.profiler_sort_by_load_descr"),
			configInt = "profiler_sort_by_load",
		},
		{
			id = "profiler_averagetime",
			parent = "profiler_widget",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.profiler_averagetime"),
			type = "slider",
			min = 0.1,
			max = 10,
			step = 0.1,
			value = 2,
			description = BAR.I18N("ui.settings.option.profiler_averagetime_descr"),
			configFloat = "profiler_averagetime",
		},
		{
			id = "framegrapher",
			group = "dev",
			category = types.dev,
			widget = "Frame Grapher",
			name = BAR.I18N("ui.settings.option.framegrapher"),
			type = "bool",
			value = GetWidgetToggleValue("Frame Grapher"),
			description = "",
		},

		{
			id = "debugcolvol",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.debugcolvol"),
			type = "bool",
			value = false,
			description = "",
			onchange = function(option, value)
				Spring.SendCommands("DebugColVol " .. (value and "1" or "0"))
			end,
		},
		{
			id = "echocamerastate",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.echocamerastate"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.echocamerastate_descr"),
			onchange = function(option, value)
				option.value = false
				Spring.Echo(Spring.GetCameraState())
			end,
		},

		{
			id = "label_dev_other",
			group = "dev",
			name = BAR.I18N("ui.settings.option.label_other"),
			category = types.dev,
		},

		{
			id = "storedefaultsettings",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.storedefaultsettings"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.storedefaultsettings_descr"),
			configInt = "StoreDefaultSettings",
		},

		{
			id = "cegbrowser",
			group = "dev",
			category = types.dev,
			widget = "CEG Effects Browser",
			name = BAR.I18N("ui.settings.option.cegbrowser"),
			type = "bool",
			value = GetWidgetToggleValue("CEG Effects Browser"),
			description = BAR.I18N("ui.settings.option.cegbrowser_descr"),
		},

		{
			id = "startboxeditor",
			group = "dev",
			category = types.dev,
			widget = "Startbox Editor",
			name = BAR.I18N("ui.settings.option.startboxeditor"),
			type = "bool",
			value = GetWidgetToggleValue("Startbox Editor"),
			description = BAR.I18N("ui.settings.option.startboxeditor_descr"),
		},

		{
			id = "language_dev",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.language"),
			type = "select",
			options = devLanguageNames,
			value = devLanguageCodes[BAR.I18N.getLocale()],
			onchange = function(option, value)
				local devLanguage = devLanguageCodes[value]
				WG.language.setLanguage(devLanguage)
			end,
		},
		{
			id = "font",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.font"),
			type = "select",
			options = {},
			value = 1,
			description = BAR.I18N("ui.settings.option.font_descr"),
			onchange = function(option, value)
				if VFS.FileExists("fonts/" .. option.optionsFont[value]) then
					Spring.SetConfigString("bar_font", option.optionsFont[value])
					Spring.SendCommands("luarules reloadluaui")
				end
			end,
		},
		{
			id = "font2",
			--parent = "font",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.font2"),
			type = "select",
			options = {},
			value = 1,
			description = BAR.I18N("ui.settings.option.font2_descr"),
			onchange = function(option, value)
				if VFS.FileExists("fonts/" .. option.optionsFont[value]) then
					Spring.SetConfigString("bar_font2", option.optionsFont[value])
					Spring.SendCommands("luarules reloadluaui")
				end
			end,
		},

		--{ id = "label_dev_unit", group = "dev", name = Spring.I18N('ui.settings.option.label_unit'), category = types.dev },
		--{ id = "label_dev_unit_spacer", group = "dev", category = types.dev },
		--
		--{ id = "tonemapA", group = "dev", category = types.dev, name = Spring.I18N('ui.settings.option.tonemap') .. widgetOptionColor .. "  1", type = "slider", min = 0, max = 7, step = 0.01, value = Spring.GetConfigFloat("tonemapA", 4.8), description = "",
		--  onchange = function(option, value)
		--	  Spring.SetConfigFloat("tonemapA", value)
		--	  Spring.SendCommands("luarules updatesun")
		--	  Spring.SendCommands("luarules GlassUpdateSun")
		--  end,
		--},
		--{ id = "tonemapB", group = "dev", category = types.dev, name = widgetOptionColor .. "   2", type = "slider", min = 0, max = 2, step = 0.01, value = Spring.GetConfigFloat("tonemapB", 0.75), description = "",
		--  onchange = function(option, value)
		--	  Spring.SetConfigFloat("tonemapB", value)
		--	  Spring.SendCommands("luarules updatesun")
		--	  Spring.SendCommands("luarules GlassUpdateSun")
		--  end,
		--},
		--{ id = "tonemapC", group = "dev", category = types.dev, name = widgetOptionColor .. "   3", type = "slider", min = 0, max = 5, step = 0.01, value = Spring.GetConfigFloat("tonemapC", 3.5), description = "",
		--  onchange = function(option, value)
		--	  Spring.SetConfigFloat("tonemapC", value)
		--	  Spring.SendCommands("luarules updatesun")
		--	  Spring.SendCommands("luarules GlassUpdateSun")
		--  end,
		--},
		--{ id = "tonemapD", group = "dev", category = types.dev, name = widgetOptionColor .. "   4", type = "slider", min = 0, max = 3, step = 0.01, value = Spring.GetConfigFloat("tonemapD", 0.85), description = "",
		--  onchange = function(option, value)
		--	  Spring.SetConfigFloat("tonemapD", value)
		--	  Spring.SendCommands("luarules updatesun")
		--	  Spring.SendCommands("luarules GlassUpdateSun")
		--  end,
		--},
		--{ id = "tonemapE", group = "dev", category = types.dev, name = widgetOptionColor .. "   5", type = "slider", min = 0.75, max = 1.5, step = 0.01, value = Spring.GetConfigFloat("tonemapE", 1.0), description = "",
		--  onchange = function(option, value)
		--	  Spring.SetConfigFloat("tonemapE", value)
		--	  Spring.SendCommands("luarules updatesun")
		--	  Spring.SendCommands("luarules GlassUpdateSun")
		--  end,
		--},
		--{ id = "envAmbient", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.envAmbient'), type = "slider", min = 0, max = 1, step = 0.01, value = Spring.GetConfigFloat("envAmbient", 0.25), description = "",
		--  onchange = function(option, value)
		--	  Spring.SetConfigFloat("envAmbient", value)
		--	  Spring.SendCommands("luarules updatesun")
		--	  Spring.SendCommands("luarules GlassUpdateSun")
		--  end,
		--},
		--{ id = "unitSunMult", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.unitSunMult'), type = "slider", min = 0.7, max = 1.6, step = 0.01, value = Spring.GetConfigFloat("unitSunMult", 1.0), description = "",
		--  onchange = function(option, value)
		--	  Spring.SetConfigFloat("unitSunMult", value)
		--	  Spring.SendCommands("luarules updatesun")
		--	  Spring.SendCommands("luarules GlassUpdateSun")
		--  end,
		--},
		--{ id = "unitExposureMult", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.unitExposureMult'), type = "slider", min = 0.6, max = 1.25, step = 0.01, value = Spring.GetConfigFloat("unitExposureMult", 1.0), description = "",
		--  onchange = function(option, value)
		--	  Spring.SetConfigFloat("unitExposureMult", value)
		--	  Spring.SendCommands("luarules updatesun")
		--	  Spring.SendCommands("luarules GlassUpdateSun")
		--  end,
		--},
		--{ id = "modelGamma", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.modelGamma'), type = "slider", min = 0.7, max = 1.7, step = 0.01, value = Spring.GetConfigFloat("modelGamma", 1.0), description = "",
		--  onchange = function(option, value)
		--	  Spring.SetConfigFloat("modelGamma", value)
		--	  Spring.SendCommands("luarules updatesun")
		--	  Spring.SendCommands("luarules GlassUpdateSun")
		--  end,
		--},
		--{ id = "tonemapDefaults", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.tonemapDefaults'), type = "bool", value = GetWidgetToggleValue("Unit Reclaimer"), description = "",
		--  onchange = function(option, value)
		--	  Spring.SetConfigFloat("tonemapA", 4.75)
		--	  Spring.SetConfigFloat("tonemapB", 0.75)
		--	  Spring.SetConfigFloat("tonemapC", 3.5)
		--	  Spring.SetConfigFloat("tonemapD", 0.85)
		--	  Spring.SetConfigFloat("tonemapE", 1.0)
		--	  Spring.SetConfigFloat("envAmbient", 0.25)
		--	  Spring.SetConfigFloat("unitSunMult", 1.0)
		--	  Spring.SetConfigFloat("unitExposureMult", 1.0)
		--	  Spring.SetConfigFloat("modelGamma", 1.0)
		--	  getOption('tonemapA').value = Spring.GetConfigFloat("tonemapA")
		--	  getOption('tonemapB').value = Spring.GetConfigFloat("tonemapB")
		--	  getOption('tonemapC').value = Spring.GetConfigFloat("tonemapC")
		--	  getOption('tonemapD').value = Spring.GetConfigFloat("tonemapD")
		--	  getOption('tonemapE').value = Spring.GetConfigFloat("tonemapE")
		--	  getOption('envAmbient').value = Spring.GetConfigFloat("envAmbient")
		--	  getOption('unitSunMult').value = Spring.GetConfigFloat("unitSunMult")
		--	  getOption('unitExposureMult').value = Spring.GetConfigFloat("unitExposureMult")
		--	  getOption('modelGamma').value = Spring.GetConfigFloat("modelGamma")
		--	  Spring.SendCommands("luarules updatesun")
		--	  Spring.SendCommands("luarules GlassUpdateSun")
		--	  getOption('tonemapDefaults').value = false
		--  end,
		--},

		{
			id = "label_dev_map",
			group = "dev",
			name = BAR.I18N("ui.settings.option.label_map"),
			category = types.dev,
		},

		{
			id = "sun_y",
			group = "dev",
			category = types.dev,
			prefix = BAR.I18N("ui.settings.option.sun"),
			name = BAR.I18N("ui.settings.option.sun_y"),
			type = "slider",
			min = 0.05,
			max = 0.9999,
			step = 0.0001,
			value = select(2, gl.GetSun("pos")),
			onchange = function(option, value)
				local sunX, sunY, sunZ = gl.GetSun("pos")
				sunY = value
				if sunY < option.min then
					sunY = option.min
				end
				if sunY > option.max then
					sunY = option.max
				end
				option.value = sunY
				Spring.SetSunDirection(sunX, sunY, sunZ)
				-- just so that map/model lighting gets updated
				Spring.SetSunLighting({
					groundShadowDensity = gl.GetSun("shadowDensity"),
					modelShadowDensity = gl.GetSun("shadowDensity"),
				})
				Spring.Echo(gl.GetSun())
			end,
		},
		{
			id = "sun_x",
			parent = "sun_y",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.sun_x"),
			type = "slider",
			min = -0.9999,
			max = 0.9999,
			step = 0.0001,
			value = select(1, gl.GetSun("pos")),
			onchange = function(option, value)
				local sunX, sunY, sunZ = gl.GetSun("pos")
				sunX = value
				if sunX < option.min then
					sunX = option.min
				end
				if sunX > option.max then
					sunX = option.max
				end
				option.value = sunX
				Spring.SetSunDirection(sunX, sunY, sunZ)
				-- just so that map/model lighting gets updated
				Spring.SetSunLighting({
					groundShadowDensity = gl.GetSun("shadowDensity"),
					modelShadowDensity = gl.GetSun("shadowDensity"),
				})
				Spring.Echo(gl.GetSun())
			end,
		},
		{
			id = "sun_z",
			parent = "sun_y",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.sun_z"),
			type = "slider",
			min = -0.9999,
			max = 0.9999,
			step = 0.0001,
			value = select(3, gl.GetSun("pos")),
			onchange = function(option, value)
				local sunX, sunY, sunZ = gl.GetSun("pos")
				sunZ = value
				if sunZ < option.min then
					sunZ = option.min
				end
				if sunZ > option.max then
					sunZ = option.max
				end
				option.value = sunZ
				Spring.SetSunDirection(sunX, sunY, sunZ)
				-- just so that map/model lighting gets updated
				Spring.SetSunLighting({
					groundShadowDensity = gl.GetSun("shadowDensity"),
					modelShadowDensity = gl.GetSun("shadowDensity"),
				})
				Spring.Echo(gl.GetSun())
			end,
		},
		{
			id = "sun_reset",
			parent = "sun_y",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.sun_reset"),
			type = "bool",
			value = false,
			onchange = function(option, value)
				getOption("sun_x").value = defaultMapSunPos[1]
				getOption("sun_y").value = defaultMapSunPos[2]
				getOption("sun_z").value = defaultMapSunPos[3]
				option.value = false
				Spring.SetSunDirection(defaultMapSunPos[1], defaultMapSunPos[2], defaultMapSunPos[3])
				-- just so that map/model lighting gets updated
				Spring.SetSunLighting({
					groundShadowDensity = gl.GetSun("shadowDensity"),
					modelShadowDensity = gl.GetSun("shadowDensity"),
				})
				Spring.Echo(gl.GetSun())
			end,
		},

		{
			id = "fog_start",
			group = "dev",
			category = types.dev,
			prefix = BAR.I18N("ui.settings.option.fog"),
			name = BAR.I18N("ui.settings.option.fog_start"),
			type = "slider",
			min = 0,
			max = 1.99,
			step = 0.01,
			value = gl.GetAtmosphere("fogStart"),
			onchange = function(option, value)
				if getOption("fog_end") and value >= getOption("fog_end").value then
					applyOptionValue(getOption("fog_end"), value + 0.01)
				end
				Spring.SetAtmosphere({ fogStart = value })
			end,
		},
		{
			id = "fog_end",
			parent = "fog_start",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.fog_end"),
			type = "slider",
			min = 0.5,
			max = 2,
			step = 0.01,
			value = gl.GetAtmosphere("fogEnd"),
			onchange = function(option, value)
				if getOption("fog_start") and value <= getOption("fog_start").value then
					applyOptionValue(getOption("fog_start"), value - 0.01)
				end
				Spring.SetAtmosphere({ fogEnd = value })
			end,
		},
		{
			id = "fog_reset",
			parent = "fog_start",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.fog_reset"),
			type = "bool",
			value = false,
			description = "",
			onchange = function(option, value)
				if getOption("fog_start") then
					getOption("fog_start").value = defaultMapFog.fogStart
					getOption("fog_end").value = defaultMapFog.fogEnd
					option.value = false
				end
				Spring.SetAtmosphere({ fogStart = defaultMapFog.fogStart, fogEnd = defaultMapFog.fogEnd })
			end,
		},

		{
			id = "fog_color",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.fog_color"),
			type = "color",
			max = 1,
			step = 0.01,
			value = { gl.GetAtmosphere("fogColor") },
			description = "",
			onchange = function(option, value)
				local alpha = select(4, gl.GetAtmosphere("fogColor"))
				Spring.SetAtmosphere({ fogColor = { value[1], value[2], value[3], alpha } })
			end,
		},
		{
			id = "fog_color_reset",
			parent = "fog_color",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.fog_color_reset"),
			type = "bool",
			value = false,
			description = "",
			onchange = function(option, value)
				local fogColor = defaultMapFog.fogColor
				getOption("fog_color").value = { fogColor[1], fogColor[2], fogColor[3] }
				option.value = false
				Spring.SetAtmosphere({ fogColor = defaultMapFog.fogColor })
				Spring.Echo("reset map fog color defaults")
			end,
		},

		{
			id = "map_voidwater",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.map_voidwater"),
			type = "bool",
			value = false,
			description = "",
			onload = function(option)
				option.value = gl.GetMapRendering("voidWater")
			end,
			onchange = function(option, value)
				Spring.SetMapRenderingParams({ voidWater = value })
			end,
		},
		{
			id = "map_voidground",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.map_voidground"),
			type = "bool",
			value = false,
			description = "",
			onload = function(option)
				option.value = gl.GetMapRendering("voidGround")
			end,
			onchange = function(option, value)
				Spring.SetMapRenderingParams({ voidGround = value })
			end,
		},

		{
			id = "map_splatdetailnormaldiffusealpha",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.map_splatdetailnormaldiffusealpha"),
			type = "bool",
			value = false,
			description = "",
			onload = function(option)
				option.value = gl.GetMapRendering("splatDetailNormalDiffuseAlpha")
			end,
			onchange = function(option, value)
				Spring.SetMapRenderingParams({ splatDetailNormalDiffuseAlpha = value })
			end,
		},

		{
			id = "map_splattexmults_r",
			group = "dev",
			category = types.dev,
			prefix = BAR.I18N("ui.settings.option.map_splattexmults"),
			name = "0",
			type = "slider",
			min = 0,
			max = 1.5,
			step = 0.001,
			value = 0,
			description = "",
			onload = function(option)
				local r, _, _, _ = gl.GetMapRendering("splatTexMults")
				option.value = r
			end,
			onchange = function(option, value)
				local r, g, b, a = gl.GetMapRendering("splatTexMults")
				Spring.SetMapRenderingParams({ splatTexMults = { value, g, b, a } })
			end,
		},
		{
			id = "map_splattexmults_g",
			parent = "map_splattexmults_r",
			group = "dev",
			category = types.dev,
			name = "1",
			type = "slider",
			min = 0,
			max = 1.5,
			step = 0.001,
			value = 0,
			description = "",
			onload = function(option)
				local _, g, _, _ = gl.GetMapRendering("splatTexMults")
				option.value = g
			end,
			onchange = function(option, value)
				local r, g, b, a = gl.GetMapRendering("splatTexMults")
				Spring.SetMapRenderingParams({ splatTexMults = { r, value, b, a } })
			end,
		},
		{
			id = "map_splattexmults_b",
			parent = "map_splattexmults_r",
			group = "dev",
			category = types.dev,
			name = "2",
			type = "slider",
			min = 0,
			max = 1.5,
			step = 0.001,
			value = 0,
			description = "",
			onload = function(option)
				local _, _, b, _ = gl.GetMapRendering("splatTexMults")
				option.value = b
			end,
			onchange = function(option, value)
				local r, g, b, a = gl.GetMapRendering("splatTexMults")
				Spring.SetMapRenderingParams({ splatTexMults = { r, g, value, a } })
			end,
		},
		{
			id = "map_splattexmults_a",
			parent = "map_splattexmults_r",
			group = "dev",
			category = types.dev,
			name = "3",
			type = "slider",
			min = 0,
			max = 1.5,
			step = 0.001,
			value = 0,
			description = "",
			onload = function(option)
				local r, g, b, a = gl.GetMapRendering("splatTexMults")
				option.value = a
			end,
			onchange = function(option, value)
				local r, g, b, _ = gl.GetMapRendering("splatTexMults")
				Spring.SetMapRenderingParams({ splatTexMults = { r, g, b, value } })
			end,
		},

		{
			id = "map_splattexacales_r",
			group = "dev",
			category = types.dev,
			prefix = BAR.I18N("ui.settings.option.map_splattexacales"),
			name = "0",
			type = "slider",
			min = 0,
			max = 0.02,
			step = 0.0001,
			value = 0,
			description = "",
			onload = function(option)
				local r, _, _, _ = gl.GetMapRendering("splatTexScales")
				option.value = r
			end,
			onchange = function(option, value)
				local r, g, b, a = gl.GetMapRendering("splatTexScales")
				Spring.SetMapRenderingParams({ splatTexScales = { value, g, b, a } })
			end,
		},
		{
			id = "map_splattexacales_g",
			parent = "map_splattexacales_r",
			group = "dev",
			category = types.dev,
			name = "1",
			type = "slider",
			min = 0,
			max = 0.02,
			step = 0.0001,
			value = 0,
			description = "",
			onload = function(option)
				local _, g, _, _ = gl.GetMapRendering("splatTexScales")
				option.value = g
			end,
			onchange = function(option, value)
				local r, g, b, a = gl.GetMapRendering("splatTexScales")
				Spring.SetMapRenderingParams({ splatTexScales = { r, value, b, a } })
			end,
		},
		{
			id = "map_splattexacales_b",
			parent = "map_splattexacales_r",
			group = "dev",
			category = types.dev,
			name = "2",
			type = "slider",
			min = 0,
			max = 0.02,
			step = 0.0001,
			value = 0,
			description = "",
			onload = function(option)
				local _, _, b, _ = gl.GetMapRendering("splatTexScales")
				option.value = b
			end,
			onchange = function(option, value)
				local r, g, b, a = gl.GetMapRendering("splatTexScales")
				Spring.SetMapRenderingParams({ splatTexScales = { r, g, value, a } })
			end,
		},
		{
			id = "map_splattexacales_a",
			parent = "map_splattexacales_r",
			group = "dev",
			category = types.dev,
			name = "3",
			type = "slider",
			min = 0,
			max = 0.02,
			step = 0.0001,
			value = 0,
			description = "",
			onload = function(option)
				local r, g, b, a = gl.GetMapRendering("splatTexScales")
				option.value = a
			end,
			onchange = function(option, value)
				local r, g, b, _ = gl.GetMapRendering("splatTexScales")
				Spring.SetMapRenderingParams({ splatTexScales = { r, g, b, value } })
			end,
		},

		{
			id = "GroundShadowDensity",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.GroundShadowDensity"),
			type = "slider",
			min = 0,
			max = 1.5,
			step = 0.001,
			value = 0,
			description = "",
			onload = function(option)
				local groundshadowDensity = gl.GetSun("shadowDensity", "ground")
				option.value = groundshadowDensity
			end,
			onchange = function(option, value)
				Spring.SetSunLighting({ groundShadowDensity = value })
				Spring.SendCommands("luarules updatesun")
			end,
		},

		{
			id = "UnitShadowDensity",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.UnitShadowDensity"),
			type = "slider",
			min = 0,
			max = 1.5,
			step = 0.001,
			value = 0,
			description = "",
			onload = function(option)
				local groundshadowDensity = gl.GetSun("shadowDensity", "unit")
				option.value = groundshadowDensity
			end,
			onchange = function(option, value)
				Spring.SetSunLighting({ modelShadowDensity = value })
				Spring.SendCommands("luarules updatesun")
			end,
		},

		{
			id = "color_groundambient",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.color_groundambient"),
			type = "color",
			max = 2,
			white = 1,
			step = 0.001,
			value = { 0, 0, 0 },
			description = "",
			onload = function(option)
				option.value = { gl.GetSun("ambient") }
			end,
			onchange = function(option, value)
				Spring.SetSunLighting({ groundAmbientColor = { value[1], value[2], value[3] } })
				Spring.SendCommands("luarules updatesun")
			end,
		},

		{
			id = "color_grounddiffuse",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.color_grounddiffuse"),
			type = "color",
			max = 2,
			white = 1,
			step = 0.001,
			value = { 0, 0, 0 },
			description = "",
			onload = function(option)
				option.value = { gl.GetSun("diffuse") }
			end,
			onchange = function(option, value)
				Spring.SetSunLighting({ groundDiffuseColor = { value[1], value[2], value[3] } })
				Spring.SendCommands("luarules updatesun")
			end,
		},

		{
			id = "color_groundspecular",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.color_groundspecular"),
			type = "color",
			max = 2,
			white = 1,
			step = 0.001,
			value = { 0, 0, 0 },
			description = "",
			onload = function(option)
				option.value = { gl.GetSun("specular") }
			end,
			onchange = function(option, value)
				Spring.SetSunLighting({ groundSpecularColor = { value[1], value[2], value[3] } })
				Spring.SendCommands("luarules updatesun")
			end,
		},

		{
			id = "color_unitambient",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.color_unitambient"),
			type = "color",
			max = 2,
			white = 1,
			step = 0.001,
			value = { 0, 0, 0 },
			description = "",
			onload = function(option)
				option.value = { gl.GetSun("ambient", "unit") }
			end,
			onchange = function(option, value)
				Spring.SetSunLighting({ unitAmbientColor = { value[1], value[2], value[3] } })
				Spring.SendCommands("luarules updatesun")
			end,
		},

		{
			id = "color_unitdiffuse",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.color_unitdiffuse"),
			type = "color",
			max = 2,
			white = 1,
			step = 0.001,
			value = { 0, 0, 0 },
			description = "",
			onload = function(option)
				option.value = { gl.GetSun("diffuse", "unit") }
			end,
			onchange = function(option, value)
				Spring.SetSunLighting({ unitDiffuseColor = { value[1], value[2], value[3] } })
				Spring.SendCommands("luarules updatesun")
			end,
		},

		{
			id = "color_unitspecular",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.color_unitspecular"),
			type = "color",
			max = 2,
			white = 1,
			step = 0.001,
			value = { 0, 0, 0 },
			description = "",
			onload = function(option)
				option.value = { gl.GetSun("specular", "unit") }
			end,
			onchange = function(option, value)
				Spring.SetSunLighting({ unitSpecularColor = { value[1], value[2], value[3] } })
				Spring.SendCommands("luarules updatesun")
			end,
		},

		{
			id = "suncolor",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.suncolor"),
			type = "color",
			max = 1,
			step = 0.001,
			value = { 0, 0, 0 },
			description = "",
			onload = function(option)
				option.value = { gl.GetAtmosphere("sunColor") }
			end,
			onchange = function(option, value)
				Spring.SetAtmosphere({ sunColor = { value[1], value[2], value[3] } })
				Spring.SendCommands("luarules updatesun")
			end,
		},

		{
			id = "skycolor",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.skycolor"),
			type = "color",
			max = 1,
			step = 0.001,
			value = { 0, 0, 0 },
			description = "",
			onload = function(option)
				option.value = { gl.GetAtmosphere("skyColor") }
			end,
			onchange = function(option, value)
				Spring.SetAtmosphere({ skyColor = { value[1], value[2], value[3] } })
				Spring.SendCommands("luarules updatesun")
			end,
		},

		{
			id = "sunlighting_reset",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.sunlighting_reset"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.sunlighting_reset_descr"),
			onchange = function(option, value)
				option.value = false
				-- just so that map/model lighting gets updated
				Spring.SetSunLighting(defaultSunLighting)
				Spring.Echo("reset ground/unit coloring")
				init()
			end,
		},

		{
			id = "skyaxisangle_angle",
			group = "dev",
			category = types.dev,
			prefix = BAR.I18N("ui.settings.option.skybox"),
			name = BAR.I18N("ui.settings.option.angle"),
			type = "slider",
			min = -3.14,
			max = 3.14,
			step = 0.01,
			value = 0,
			description = "",
			onload = function(option)
				local x, y, z, angle = gl.GetAtmosphere("skyAxisAngle")
				option.value = angle
			end,
			onchange = function(option, value)
				local x, y, z, angle = gl.GetAtmosphere("skyAxisAngle")
				angle = value
				Spring.SetAtmosphere({ skyAxisAngle = { x, y, z, angle } })
			end,
		},
		{
			id = "skyaxisangle_x",
			parent = "skyaxisangle_angle",
			group = "dev",
			category = types.dev,
			name = "x",
			type = "slider",
			min = -1,
			max = 1,
			step = 0.01,
			value = 0,
			description = "",
			onload = function(option)
				local x, _, _, _ = gl.GetAtmosphere("skyAxisAngle")
				option.value = x
			end,
			onchange = function(option, value)
				local x, y, z, angle = gl.GetAtmosphere("skyAxisAngle")
				x = value
				Spring.SetAtmosphere({ skyAxisAngle = { x, y, z, angle } })
			end,
		},
		{
			id = "skyaxisangle_y",
			parent = "skyaxisangle_angle",
			group = "dev",
			category = types.dev,
			name = "y",
			type = "slider",
			min = -1,
			max = 1,
			step = 0.01,
			value = 0,
			description = "",
			onload = function(option)
				local _, y, _, _ = gl.GetAtmosphere("skyAxisAngle")
				option.value = y
			end,
			onchange = function(option, value)
				local x, y, z, angle = gl.GetAtmosphere("skyAxisAngle")
				y = value
				Spring.SetAtmosphere({ skyAxisAngle = { x, y, z, angle } })
			end,
		},
		{
			id = "skyaxisangle_z",
			parent = "skyaxisangle_angle",
			group = "dev",
			category = types.dev,
			name = "z",
			type = "slider",
			min = -1,
			max = 1,
			step = 0.01,
			value = 0,
			description = "",
			onload = function(option)
				local _, _, z, _ = gl.GetAtmosphere("skyAxisAngle")
				option.value = z
			end,
			onchange = function(option, value)
				local x, y, z, angle = gl.GetAtmosphere("skyAxisAngle")
				z = value
				Spring.SetAtmosphere({ skyAxisAngle = { x, y, z, angle } })
			end,
		},

		{
			id = "skyaxisangle_reset",
			parent = "skyaxisangle_angle",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.reset"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.sunlighting_reset_descr"),
			onchange = function(option, value)
				option.value = false
				Spring.SetAtmosphere({ skyAxisAngle = defaultSkyAxisAngle })
				Spring.Echo("reset skyAxisAngle atmosphere")
				init()
			end,
		},
		{
			id = "label_dev_water",
			group = "dev",
			name = BAR.I18N("ui.settings.option.label_water"),
			category = types.dev,
		},

		-- springsettings water params
		{
			id = "waterconfig_shorewaves",
			group = "dev",
			category = types.dev,
			prefix = "Bumpwater settings",
			name = "shorewaves",
			type = "bool",
			value = Spring.GetConfigInt("BumpWaterShoreWaves", 1) == 1,
			description = "",
			onchange = function(option, value)
				Spring.SetConfigInt("BumpWaterShoreWaves", (value and 1 or 0))
				-- rebuilds the water from the config; /water 4 does nothing while it is already 4
				Spring.SetWaterParams({})
			end,
		},
		{
			id = "waterconfig_dynamicwaves",
			parent = "waterconfig_shorewaves",
			group = "dev",
			category = types.dev,
			name = "dynamic waves",
			type = "bool",
			value = Spring.GetConfigInt("BumpWaterDynamicWaves", 1) == 1,
			description = "Springsettings.cfg config",
			onchange = function(option, value)
				Spring.SetConfigInt("BumpWaterDynamicWaves", (value and 1 or 0))
				Spring.SetWaterParams({})
			end,
		},
		{
			id = "waterconfig_endless",
			parent = "waterconfig_shorewaves",
			group = "dev",
			category = types.dev,
			name = "endless",
			type = "bool",
			value = Spring.GetConfigInt("BumpWaterEndlessOcean", 1) == 1,
			description = "Springsettings.cfg config",
			onchange = function(option, value)
				Spring.SetConfigInt("BumpWaterEndlessOcean", (value and 1 or 0))
				Spring.SetWaterParams({})
			end,
		},
		{
			id = "waterconfig_occlusionquery",
			parent = "waterconfig_shorewaves",
			group = "dev",
			category = types.dev,
			name = "occlusion query",
			type = "bool",
			value = Spring.GetConfigInt("BumpWaterOcclusionQuery", 1) == 1,
			description = "Springsettings.cfg config",
			onchange = function(option, value)
				Spring.SetConfigInt("BumpWaterOcclusionQuery", (value and 1 or 0))
				Spring.SetWaterParams({})
			end,
		},
		{
			id = "waterconfig_blurreflection",
			parent = "waterconfig_shorewaves",
			group = "dev",
			category = types.dev,
			name = "blur reflection",
			type = "bool",
			value = Spring.GetConfigInt("BumpWaterBlurReflection", 1) == 1,
			description = "Springsettings.cfg config",
			onchange = function(option, value)
				Spring.SetConfigInt("BumpWaterBlurReflection", (value and 1 or 0))
				Spring.SetWaterParams({})
			end,
		},
		{
			id = "waterconfig_anisotropy",
			parent = "waterconfig_shorewaves",
			group = "dev",
			category = types.dev,
			name = "anisotropy",
			type = "slider",
			min = 0,
			max = 16,
			step = 1,
			value = Spring.GetConfigFloat("BumpWaterAnisotropy", 0),
			description = "Springsettings.cfg config",
			onchange = function(option, value)
				Spring.SetConfigFloat("BumpWaterAnisotropy", value)
				Spring.SetWaterParams({})
			end,
		},
		{
			id = "wateconfigr_usedepthtexture",
			parent = "waterconfig_shorewaves",
			group = "dev",
			category = types.dev,
			name = "use depth texture",
			type = "bool",
			value = Spring.GetConfigInt("BumpWaterUseDepthTexture", 1) == 1,
			description = "Springsettings.cfg config",
			onchange = function(option, value)
				Spring.SetConfigInt("BumpWaterUseDepthTexture", (value and 1 or 0))
				Spring.SetWaterParams({})
			end,
		},
		{
			id = "waterconfig_useuniforms",
			parent = "waterconfig_shorewaves",
			group = "dev",
			category = types.dev,
			name = "use uniforms",
			type = "bool",
			value = Spring.GetConfigInt("BumpWaterUseUniforms", 1) == 1,
			description = "Springsettings.cfg config",
			onchange = function(option, value)
				Spring.SetConfigInt("BumpWaterUseUniforms", (value and 1 or 0))
				Spring.SetWaterParams({})
			end,
		},

		-- GL water params
		{
			id = "water_shorewaves",
			group = "dev",
			category = types.dev,
			prefix = "Bumpwater GL params",
			name = "shorewaves",
			type = "bool",
			value = gl.GetWaterRendering("shoreWaves"),
			description = "",
			onchange = function(option, value)
				Spring.SetWaterParams({ shoreWaves = value })
				Spring.SendCommands("water 4")
			end,
		},
		{
			id = "water_haswaterplane",
			parent = "water_shorewaves",
			group = "dev",
			category = types.dev,
			name = "has waterplane",
			type = "bool",
			value = gl.GetWaterRendering("hasWaterPlane"),
			description = "The WaterPlane is a single Quad beneath the map.\nIt should have the same color as the ocean floor to hide the map -> background boundary. Specifying waterPlaneColor in mapinfo.lua will turn this on.",
			onchange = function(option, value)
				Spring.SetWaterParams({ hasWaterPlane = value })
				Spring.SendCommands("water 4")
			end,
		},
		{
			id = "water_forcerendering",
			parent = "water_shorewaves",
			group = "dev",
			category = types.dev,
			name = "force rendering",
			type = "bool",
			value = gl.GetWaterRendering("forceRendering"),
			description = "Should the water be rendered even when minMapHeight>0.\nUse it to avoid the jumping of the outside-map water rendering (BumpWater: endlessOcean option) when combat explosions reach groundwater.",
			onchange = function(option, value)
				Spring.SetWaterParams({ forceRendering = value })
				Spring.SendCommands("water 4")
			end,
		},
		{
			id = "water_repeatx",
			parent = "water_shorewaves",
			group = "dev",
			category = types.dev,
			name = "repeat X",
			type = "slider",
			min = 0,
			max = 20,
			step = 1,
			value = gl.GetWaterRendering("repeatX"),
			description = "water 0 texture repeat horizontal",
			onchange = function(option, value)
				Spring.SetWaterParams({ repeatX = value })
				Spring.SendCommands("water 4")
			end,
		},
		{
			id = "water_repeaty",
			parent = "water_shorewaves",
			group = "dev",
			category = types.dev,
			name = "repeat Y",
			type = "slider",
			min = 0,
			max = 20,
			step = 1,
			value = gl.GetWaterRendering("repeatY"),
			description = "water 0 texture repeat vertical",
			onchange = function(option, value)
				Spring.SetWaterParams({ repeatY = value })
				Spring.SendCommands("water 4")
			end,
		},
		{
			id = "water_surfacealpha",
			parent = "water_shorewaves",
			group = "dev",
			category = types.dev,
			name = "surface alpha",
			type = "slider",
			min = 0,
			max = 1,
			step = 0.001,
			value = gl.GetWaterRendering("surfaceAlpha"),
			description = "",
			onchange = function(option, value)
				Spring.SetWaterParams({ surfaceAlpha = value })
				Spring.SendCommands("water 4")
			end,
		},
		-- gl.GetWaterRendering("windSpeed") seems to not exist
		--{ id = "water_windspeed", group = "dev", category = types.dev, name = widgetOptionColor .. "   windspeed", type = "slider", min = 0.0, max = 2.0, step = 0.01, value = gl.GetWaterRendering("windSpeed"), description = "The speed of bumpwater tiles moving",
		--  onload = function(option)
		--  end,
		--  onchange = function(option, value)
		--	  Spring.SetWaterParams({ windSpeed = value })
		--	  Spring.SendCommands("water 4")
		--  end,
		--},
		{
			id = "water_ambientfactor",
			parent = "water_shorewaves",
			group = "dev",
			category = types.dev,
			name = "ambient factor",
			type = "slider",
			min = 0,
			max = 2,
			step = 0.001,
			value = gl.GetWaterRendering("ambientFactor"),
			description = "How much ambient lighting the water surface gets (ideally very little)",
			onchange = function(option, value)
				Spring.SetWaterParams({ ambientFactor = value })
				Spring.SendCommands("water 4")
			end,
		},
		{
			id = "water_diffusefactor",
			parent = "water_shorewaves",
			group = "dev",
			category = types.dev,
			name = "diffuse factor",
			type = "slider",
			min = 0,
			max = 5,
			step = 0.001,
			value = gl.GetWaterRendering("diffuseFactor"),
			description = "How strong the diffuse lighting should be on the water",
			onchange = function(option, value)
				Spring.SetWaterParams({ diffuseFactor = value })
				Spring.SendCommands("water 4")
			end,
		},
		{
			id = "water_specularfactor",
			parent = "water_shorewaves",
			group = "dev",
			category = types.dev,
			name = "specular factor",
			type = "slider",
			min = 0,
			max = 5,
			step = 0.01,
			value = gl.GetWaterRendering("specularFactor"),
			description = "How much light should be reflected straight from the sun",
			onchange = function(option, value)
				Spring.SetWaterParams({ specularFactor = value })
				Spring.SendCommands("water 4")
			end,
		},
		{
			id = "water_specularpower",
			parent = "water_shorewaves",
			group = "dev",
			category = types.dev,
			name = "specular power",
			type = "slider",
			min = 0,
			max = 100,
			step = 0.1,
			value = gl.GetWaterRendering("specularPower"),
			description = "How polished the surface of the water is",
			onchange = function(option, value)
				Spring.SetWaterParams({ specularPower = value })
				Spring.SendCommands("water 4")
			end,
		},
		{
			id = "water_perlinstartfreq",
			parent = "water_shorewaves",
			group = "dev",
			category = types.dev,
			name = "perlin start freq",
			type = "slider",
			min = 10,
			max = 50,
			step = 1,
			value = gl.GetWaterRendering("perlinStartFreq"),
			description = "The initial frequency of the bump map repetition rate. Larger numbers mean more tiles",
			onchange = function(option, value)
				Spring.SetWaterParams({ perlinStartFreq = value })
				Spring.SendCommands("water 4")
			end,
		},
		{
			id = "water_perlinlacunarity",
			parent = "water_shorewaves",
			group = "dev",
			category = types.dev,
			name = "perlin lacunarity",
			type = "slider",
			min = 0.1,
			max = 4,
			step = 0.01,
			value = gl.GetWaterRendering("perlinLacunarity"),
			description = "How much smaller each additional repetition of the normal map should be. Larger numbers mean smaller",
			onchange = function(option, value)
				Spring.SetWaterParams({ perlinLacunarity = value })
				Spring.SendCommands("water 4")
			end,
		},
		{
			id = "water_perlinlamplitude",
			parent = "water_shorewaves",
			group = "dev",
			category = types.dev,
			name = "perlin amplitude",
			type = "slider",
			min = 0.1,
			max = 4,
			step = 0.01,
			value = gl.GetWaterRendering("perlinAmplitude"),
			description = "How strong each additional repetition of the normal map should be",
			onchange = function(option, value)
				Spring.SetWaterParams({ perlinAmplitude = value })
				Spring.SendCommands("water 4")
			end,
		},
		{
			id = "water_fresnelmin",
			parent = "water_shorewaves",
			group = "dev",
			category = types.dev,
			name = "fresnel min",
			type = "slider",
			min = 0,
			max = 2,
			step = 0.01,
			value = gl.GetWaterRendering("fresnelMin"),
			description = "Minimum reflection strength, e.g. the reflectivity of the water when looking straight down on it",
			onchange = function(option, value)
				Spring.SetWaterParams({ fresnelMin = value })
				Spring.SendCommands("water 4")
			end,
		},
		{
			id = "water_fresnelmax",
			parent = "water_shorewaves",
			group = "dev",
			category = types.dev,
			name = "fresnel max",
			type = "slider",
			min = 0,
			max = 2,
			step = 0.01,
			value = gl.GetWaterRendering("fresnelMax"),
			description = "Maximum reflection strength, the reflectivity of the water when looking parallel to the water plane",
			onchange = function(option, value)
				Spring.SetWaterParams({ fresnelMax = value })
				Spring.SendCommands("water 4")
			end,
		},
		{
			id = "water_fresnelpower",
			parent = "water_shorewaves",
			group = "dev",
			category = types.dev,
			name = "fresnel power",
			type = "slider",
			min = 0,
			max = 16,
			step = 0.1,
			value = gl.GetWaterRendering("fresnelPower"),
			description = "Determines how fast the reflection increases when going from straight down view to parallel.",
			onchange = function(option, value)
				Spring.SetWaterParams({ fresnelPower = value })
				Spring.SendCommands("water 4")
			end,
		},
		{
			id = "water_numtiles",
			parent = "water_shorewaves",
			group = "dev",
			category = types.dev,
			name = "num tiles",
			type = "slider",
			min = 1.0,
			max = 8,
			step = 1.0,
			value = gl.GetWaterRendering("numTiles"),
			description = "How many (squared) Tiles does the `normalTexture` have?\nSuch Tiles are used when DynamicWaves are enabled in BumpWater, the more the better.\nCheck the example php script to generate such tiled bumpmaps.",
			onchange = function(option, value)
				Spring.SetWaterParams({ numTiles = value })
				Spring.SendCommands("water 4")
			end,
		},
		{
			id = "water_blurbase",
			parent = "water_shorewaves",
			group = "dev",
			category = types.dev,
			name = "blur base",
			type = "slider",
			min = 0,
			max = 3,
			step = 0.01,
			value = gl.GetWaterRendering("blurBase"),
			description = "How much should the reflection be blurred",
			onchange = function(option, value)
				Spring.SetWaterParams({ blurBase = value })
				Spring.SendCommands("water 4")
			end,
		},
		{
			id = "water_blurexponent",
			parent = "water_shorewaves",
			group = "dev",
			category = types.dev,
			name = "blur exponent",
			type = "slider",
			min = 0,
			max = 3,
			step = 0.01,
			value = gl.GetWaterRendering("blurExponent"),
			description = "How much should the reflection be blurred",
			onchange = function(option, value)
				Spring.SetWaterParams({ blurExponent = value })
				Spring.SendCommands("water 4")
			end,
		},
		{
			id = "water_reflectiondistortion",
			parent = "water_shorewaves",
			group = "dev",
			category = types.dev,
			name = "reflection distortion",
			type = "slider",
			min = 0,
			max = 5,
			step = 0.01,
			value = gl.GetWaterRendering("reflectionDistortion"),
			description = "",
			onchange = function(option, value)
				Spring.SetWaterParams({ reflectionDistortion = value })
				Spring.SendCommands("water 4")
			end,
		},
		-- new water 4 params since engine 105BAR 582
		{
			id = "water_waveoffsetfactor",
			parent = "water_shorewaves",
			group = "dev",
			category = types.dev,
			name = "waveoffsetfactor",
			type = "slider",
			min = 0.0,
			max = 2.0,
			step = 0.01,
			value = gl.GetWaterRendering("waveOffsetFactor"),
			description = "Set this to 0.1 to make waves break shores not all at the same time",
			onchange = function(option, value)
				Spring.SetWaterParams({ waveOffsetFactor = value })
				Spring.SendCommands("water 4")
			end,
		},
		{
			id = "water_wavelength",
			parent = "water_shorewaves",
			group = "dev",
			category = types.dev,
			name = "waveLength",
			type = "slider",
			min = 0.0,
			max = 1.0,
			step = 0.01,
			value = gl.GetWaterRendering("waveLength"),
			description = "How long the waves are",
			onchange = function(option, value)
				Spring.SetWaterParams({ waveLength = value })
				Spring.SendCommands("water 4")
			end,
		},
		{
			id = "water_wavefoamdistortion",
			parent = "water_shorewaves",
			group = "dev",
			category = types.dev,
			name = "waveFoamDistortion",
			type = "slider",
			min = 0.0,
			max = 0.5,
			step = 0.01,
			value = gl.GetWaterRendering("waveFoamDistortion"),
			description = "How much the waters movement distorts the foam texture",
			onchange = function(option, value)
				Spring.SetWaterParams({ waveFoamDistortion = value })
				Spring.SendCommands("water 4")
			end,
		},
		{
			id = "water_wavefoamintensity",
			parent = "water_shorewaves",
			group = "dev",
			category = types.dev,
			name = "waveFoamIntensity",
			type = "slider",
			min = 0.0,
			max = 2.0,
			step = 0.01,
			value = gl.GetWaterRendering("waveFoamIntensity"),
			description = "How strong the foam texture is",
			onchange = function(option, value)
				Spring.SetWaterParams({ waveFoamIntensity = value })
				Spring.SendCommands("water 4")
			end,
		},
		{
			id = "water_causticsresolution",
			parent = "water_shorewaves",
			group = "dev",
			category = types.dev,
			name = "causticsResolution",
			type = "slider",
			min = 10.0,
			max = 300.0,
			step = 1.0,
			value = gl.GetWaterRendering("causticsResolution"),
			description = "The tiling rate of the caustics texture",
			onchange = function(option, value)
				Spring.SetWaterParams({ causticsResolution = value })
				Spring.SendCommands("water 4")
			end,
		},
		{
			id = "water_causticsstrength",
			parent = "water_shorewaves",
			group = "dev",
			category = types.dev,
			name = "causticsStrength",
			type = "slider",
			min = 0.0,
			max = 0.5,
			step = 0.01,
			value = gl.GetWaterRendering("causticsStrength"),
			description = "How intense the caustics effects are",
			onchange = function(option, value)
				Spring.SetWaterParams({ causticsStrength = value })
				Spring.SendCommands("water 4")
			end,
		},
		-- TODO add SetWaterParams:
		--absorb = {number r, number g, number b},
		--baseColor = {number r, number g, number b},
		--minColor = {number r, number g, number b},
		--surfaceColor = {number r, number g, number b},
		--diffuseColor = {number r, number g, number b},
		--specularColor = {number r, number g, number b},
		--planeColor = {number r, number g, number b},
	}

	options = table.filterArray(options, function(option)
		return option.available ~= false
	end)
	indexOptions()
	for _, option in ipairs(options) do
		readBoundValue(option)
	end
	if devMode and not bindingsChecked then
		checkBindings()
	end

	-- keeps the list without holes, so it stays in order and # and ipairs work on it
	local function removeOptions(ids)
		local remove = table.invert(ids)
		options = table.filterArray(options, function(option)
			return not remove[option.id]
		end)
		indexOptions()
	end

	if not isPotatoGpu and not devMode and not devUI then
		removeOptions({ "advmapshading" })
		Spring.SetConfigInt("AdvMapShading", 1)
		Spring.SendCommands("advmapshading 1")
	end

	-- reset tonemap defaults (only once)
	if not resettedTonemapDefault then
		local tonemapDefaults = getOption("tonemapDefaults")
		if tonemapDefaults then
			applyOptionValue(tonemapDefaults, true, true)
			resettedTonemapDefault = true
		end
	end

	-- Squad selection: the playstyle preset decides how much of the section is drawn. Off leaves just the preset select, Custom shows everything, and any other preset hides the rows it owns because it writes them itself.
	if not widgetHandler.knownWidgets["Squad Selection"] then
		removeOptions(squadPreset.allOptions)
		removeOptions({ "squad_preset", "label_squad" })
	else
		local activePreset = squadPreset.get()
		if activePreset == "off" then
			removeOptions(squadPreset.allOptions)
		else
			if activePreset ~= "custom" then
				removeOptions(squadPreset.ownedOptions)
			end
			if not GetWidgetToggleValue("Squad Selection Hull") then
				removeOptions(squadPreset.hullOptions)
			end
		end
	end

	if
		spectatorHUDConfigOptions[getOption("spectator_hud_config").value]
		~= BAR.I18N("ui.settings.option.spectator_hud_config_custom")
	then
		removeOptions({
			"spectator_hud_metric_metalIncome",
			"spectator_hud_metric_energyIncome",
			"spectator_hud_metric_buildPower",
			"spectator_hud_metric_metalProduced",
			"spectator_hud_metric_energyProduced",
			"spectator_hud_metric_metalExcess",
			"spectator_hud_metric_energyExcess",
			"spectator_hud_metric_armyValue",
			"spectator_hud_metric_defenseValue",
			"spectator_hud_metric_utilityValue",
			"spectator_hud_metric_economyValue",
			"spectator_hud_metric_damageDealt",
		})
	end

	-- outside its event, an event soundtrack is switched back on
	if not holidays.aprilfools then
		Spring.SetConfigInt("UseSoundtrackAprilFools", 1)
	end
	if not holidays.halloween then
		Spring.SetConfigInt("UseSoundtrackHalloween", 1)
	end
	if not holidays.xmas then
		Spring.SetConfigInt("UseSoundtrackXmas", 1)
	end

	-- add fonts
	if getOption("font") then
		local fonts = {}
		local fontsFull = {}
		local fontsn = {}
		local files = VFS.DirList("fonts", "*")
		-- previews for the font dropdowns, which only dev mode shows; loaded once
		local loadPreviews = (devMode or devUI) and not fontOption
		if loadPreviews then
			fontOption = {}
		end
		for k, file in ipairs(files) do
			local name = string.sub(file, 7)
			local ext = string.sub(name, string.len(name) - 2)
			if ext == "otf" or ext == "ttf" or ext == "ttc" then
				name = string.sub(name, 1, string.len(name) - 4)
				if not fontsn[name:lower()] then
					fonts[#fonts + 1] = name
					fontsFull[#fontsFull + 1] = string.sub(file, 7)
					fontsn[name:lower()] = true
					if loadPreviews then
						local fontScale = (0.5 + (vsx * vsy / 5700000))
						fontOption[#fonts] =
							gl.LoadFont("fonts/" .. fontsFull[#fontsFull], 20 * fontScale, 5 * fontScale, 1.5)
					end
				end
			end
		end

		getOption("font").options = fonts
		getOption("font").optionsFont = fontsFull
		local fname = Spring.GetConfigString("bar_font", "Poppins-Regular.otf"):lower()
		getOption("font").value = getSelectKey(getOption("font"), string.sub(fname, 1, string.len(fname) - 4))

		getOption("font2").options = fonts
		getOption("font2").optionsFont = fontsFull
		local fname = Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf"):lower()
		getOption("font2").value = getSelectKey(getOption("font2"), string.sub(fname, 1, string.len(fname) - 4))
	end

	-- check if cus is disabled by auto disable cus widget (in case options widget has been reloaded)
	if getOption("sun_y") then
		local sunX, sunY, sunZ = gl.GetSun("pos")
		if sunY < getOption("sun_y").min then
			Spring.SetSunDirection(sunX, getOption("sun_y").min, sunZ)
		end
	end

	-- set minimal shadow opacity
	if getOption("shadows_opacity") then
		if gl.GetSun("shadowDensity") < getOption("shadows_opacity").min then
			Spring.SetSunLighting({
				groundShadowDensity = getOption("shadows_opacity").min,
				modelShadowDensity = getOption("shadows_opacity").min,
			})
		end
	end

	if Spring.GetGameFrame() == 0 then
		detectWater()

		-- set vsync
		Spring.SetConfigInt("VSync", Spring.GetConfigInt("VSyncGame", -1) * Spring.GetConfigInt("VSyncFraction", 1))
	end
	if not waterDetected then
		Spring.SendCommands("water 0")
	end

	-- reduce options for potatoes (skip in dev mode to keep all options available)
	if (isPotatoGpu or isPotatoCpu) and not devMode and not devUI then
		--local id = getOption('shadowslider')
		--options[id].options = { 1, 2, 3 }
		--if options[id].value > 3 then
		--	options[id].value = 3
		--	options[id].onchange(id, options[id].value)
		--end

		-- disable engine decals (footprints)
		removeOptions({ "decals" })
		if Spring.GetConfigInt("GroundDecals", 3) > 0 then
			Spring.SendCommands("GroundDecals 0")
			Spring.SetConfigInt("GroundDecals", 0)
		end

		if isPotatoGpu then
			-- limit available msaa levels to 'off' and 'x2'
			if getOption("msaa") then
				for k, v in pairs(getOption("msaa").options) do
					if k >= 3 then
						getOption("msaa").options[k] = nil
					end
				end
			end

			-- turn off and drop these effects with their sub-options
			for _, ids in ipairs({ { "ssao", "ssao_strength", "ssao_quality" }, { "clouds", "clouds_opacity" } }) do
				local effect = getOption(ids[1])
				if effect and GetWidgetToggleValue(effect.widget) then
					widgetHandler:DisableWidget(effect.widget)
				end
				removeOptions(ids)
			end

			-- set lowest quality shadows for Intel GPU (they eat fps but dont show)
			--if Platform ~= nil and Platform.gpuVendor == 'Intel' and gpuMem < 2500 then
			--	Spring.SendCommands("advmapshading 0")
			--end
		end
	elseif gpuMem >= 3000 then
		if Spring.GetConfigInt("cus2", 1) ~= 1 then
			local cus = getOption("cusgl4")
			cus.onchange(cus, 1)
		end

		--local id = getOption('shadowslider')
		--options[id].options[1] = nil
		--if options[id].value == 1 then
		--	options[id].value = 2
		--	options[id].onchange(id, options[id].value)
		--end

		if not devMode and not devUI then
			removeOptions({ "cusgl4", "water" })
		else
			if Spring.GetConfigInt("Water", 0) ~= 4 then
				Spring.SendCommands("water 4")
				Spring.SetConfigInt("Water", 4)
			end
		end
	end

	if not isPotatoGpu and not devMode and not devUI then
		removeOptions({ "cusgl4" })
	end

	-- loads values via stored game config in luaui/configs
	loadAllWidgetData()

	-- remove widget-options that are unknown widgets
	local unknownWidgetOptions = {}
	for _, option in ipairs(options) do
		if option.widget and not widgetHandler.knownWidgets[option.widget] then
			unknownWidgetOptions[#unknownWidgetOptions + 1] = option.id
		end
	end
	removeOptions(unknownWidgetOptions)

	-- add music tracks options
	local trackList
	if WG.music ~= nil then
		trackList = WG.music.getTracksConfig()
	end
	if type(trackList) == "table" then
		local newOptions = {}
		local count = 0
		local prevCategory = ""
		local categoryID
		local categories = 0
		for i, option in ipairs(options) do
			count = count + 1
			newOptions[count] = option
			if option.id == "soundtrackFades" then
				count = count + 1
				newOptions[count] = {
					id = "label_sound_music",
					group = "sound",
					name = BAR.I18N("ui.settings.option.label_playlist"),
					category = types.basic,
				}

				for k, v in pairs(trackList) do
					if prevCategory ~= v[1] then
						prevCategory = v[1]
						categories = categories + 1
						categoryID = "music_category_" .. categories
						count = count + 1
						newOptions[count] =
							{ id = categoryID, group = "sound", category = types.basic, name = v[1], type = "text" }
					end
					count = count + 1
					newOptions[count] = {
						id = "music_track_" .. count,
						parent = categoryID,
						compact = true,
						group = "sound",
						category = types.basic,
						name = v[2],
						type = "bool",
						value = Spring.GetConfigInt("MusicSwitch " .. v[2], 1) == 1, --..'\n'..v[4],
						onclick = function()
							if WG.music ~= nil and WG.music.playTrack then
								WG.music.playTrack(v[3])
							end
						end,
						onchange = function(_, value)
							Spring.SetConfigInt("MusicSwitch " .. v[2], value and 1 or 0)
							--Spring.Echo(value, v[1], v[2], v[3], Spring.GetConfigInt("MusicSwitch " .. v[2], 1))
						end,
					}
				end
			end
		end
		options = newOptions
		indexOptions()
	end

	-- add sound notification sets
	if getOption("notifications_set") then
		local voiceset = Spring.GetConfigString("voiceset", "en/cephis")
		local currentVoiceSetOption
		local sets = {}
		local languageDirs = VFS.SubDirs("sounds/voice", "*")
		local setCount = 0
		for k, f in ipairs(languageDirs) do
			local langDir = string.gsub(string.sub(f, 14, string.len(f) - 1), "\\", "/")
			local files = VFS.SubDirs("sounds/voice/" .. langDir, "*")
			for k, file in ipairs(files) do
				local dirname = string.gsub(string.sub(file, 14, string.len(file) - 1), "\\", "/")
				local setAlreadyIn = false
				for i = 1, #sets do
					if dirname == sets[i] then
						setAlreadyIn = true
						break
					end
				end
				if not setAlreadyIn then
					sets[#sets + 1] = dirname
					setCount = setCount + 1
					if dirname == voiceset then
						currentVoiceSetOption = #sets
					end
				end
			end
		end
		if setCount == 0 then
			removeOptions({ "notifications_set", "notifications_spoken", "notifications_volume" })
		else
			getOption("notifications_set").options = sets
			if currentVoiceSetOption then
				getOption("notifications_set").value = currentVoiceSetOption
			end
		end
	end

	-- add sound notification widget sound toggle options
	local notificationList
	if WG.notifications ~= nil then
		notificationList = WG.notifications.getNotificationList()
	elseif
		widgetHandler.configData.Notifications ~= nil
		and widgetHandler.configData.Notifications.notificationList ~= nil
	then
		notificationList = widgetHandler.configData.Notifications.notificationList
	end
	if type(notificationList) == "table" then
		local newOptions = {}
		local count = 0
		for i, option in ipairs(options) do
			count = count + 1
			newOptions[count] = option
			if option.id == "label_notif_messages" then
				for k, v in pairs(notificationList) do
					if type(v) == "table" then
						count = count + 1
						newOptions[count] = {
							id = "notifications_notif_" .. v[1],
							parent = "label_notif_messages",
							compact = true,
							group = "notif",
							category = types.basic,
							name = BAR.I18N(v[3]),
							dimmed = v[4] == 0, -- no voice lines in this set
							type = "bool",
							value = v[2], --description = v[3] and Spring.I18N(v[3]) or "",
							onchange = function(_, value)
								saveOptionValue(
									"Notifications",
									"notifications",
									"setNotification" .. v[1],
									{ "notificationList", v[1] },
									value
								)
							end,
							onclick = function()
								if WG.notifications ~= nil and WG.notifications.playNotification then
									WG.notifications.playNotification(v[1])
								end
							end,
						}
					end
				end
			end
		end
		options = newOptions
		indexOptions()
	end

	-- add auto cloak toggles
	local defaultUnitdefConfig = { -- copy pasted defaults from the widget
		[UnitDefNames.armdecom and UnitDefNames.armdecom.id or -1] = false,
		[UnitDefNames.cordecom and UnitDefNames.cordecom.id or -1] = false,
		[UnitDefNames.armferret and UnitDefNames.armferret.id or -1] = false,
		[UnitDefNames.armamb and UnitDefNames.armamb.id or -1] = false,
		[UnitDefNames.armpb and UnitDefNames.armpb.id or -1] = false,
		[UnitDefNames.armsnipe and UnitDefNames.armsnipe.id or -1] = false,
		[UnitDefNames.corsktl and UnitDefNames.corsktl.id or -1] = false,
		[UnitDefNames.armgremlin and UnitDefNames.armgremlin.id or -1] = true,
		[UnitDefNames.armamex and UnitDefNames.armamex.id or -1] = true,
		[UnitDefNames.armshockwave and UnitDefNames.armshockwave.id or -1] = true,
		[UnitDefNames.armckfus and UnitDefNames.armckfus.id or -1] = true,
		[UnitDefNames.armspy and UnitDefNames.armspy.id or -1] = true,
		[UnitDefNames.corspy and UnitDefNames.corspy.id or -1] = true,
		[UnitDefNames.corphantom and UnitDefNames.corphantom.id or -1] = true,
		[UnitDefNames.legaspy and UnitDefNames.legaspy.id or -1] = true,
	}
	local unitdefConfig = {}
	if WG.autocloak ~= nil then
		unitdefConfig = WG.autocloak.getUnitdefConfig()
	elseif
		widgetHandler.configData["Auto Cloak Units"] ~= nil
		and widgetHandler.configData["Auto Cloak Units"].unitdefConfig ~= nil
	then
		for unitName, value in pairs(widgetHandler.configData["Auto Cloak Units"].unitdefConfig) do
			if UnitDefNames[unitName] then
				local unitDefID = UnitDefNames[unitName].id
				unitdefConfig[unitDefID] = value
			end
		end
	end
	unitdefConfig = table.merge(defaultUnitdefConfig, unitdefConfig)
	if type(unitdefConfig) == "table" then
		local newOptions = {}
		local count = 0
		for i, option in ipairs(options) do
			count = count + 1
			newOptions[count] = option
			if option.id == "autocloak" then
				for k, v in pairs(unitdefConfig) do
					if UnitDefs[k] then
						local faction = BAR.I18N("units.factions." .. string.sub(UnitDefs[k].name, 1, 3))
						if faction then
							count = count + 1
							newOptions[count] = {
								id = "autocloak_" .. k,
								parent = "autocloak",
								compact = true,
								group = "game",
								category = types.basic,
								name = UnitDefs[k].translatedHumanName .. "  (" .. faction .. ")",
								type = "bool",
								value = v,
								description = UnitDefs[k].translatedTooltip,
								onchange = function(_, value)
									saveOptionValue(
										"Auto Cloak Units",
										"autocloak",
										"setUnitdefConfig",
										{ "unitdefConfig", UnitDefs[k].name },
										value,
										{ k, value }
									)
								end,
							}
						end
					end
				end
			end
		end
		options = newOptions
		indexOptions()
	end

	-- cursors
	if WG.cursors ~= nil and WG.cursors.getsizemult then
		getOption("cursorsize").value = WG.cursors.getsizemult()
	else
		removeOptions({ "cursorsize" })
	end

	if WG.smartselect == nil then
		removeOptions({
			"smartselect_includebuildings",
			"smartselect_includebuilders",
			"smartselect_includeresurrectors",
			"smartselect_includeantinuke",
			"smartselect_includeradar",
			"smartselect_includejammer",
		})
	else
		getOption("smartselect_includebuildings").value = WG.smartselect.getIncludeBuildings()
		getOption("smartselect_includebuilders").value = WG.smartselect.getIncludeBuilders()
		getOption("smartselect_includeresurrectors").value = WG.smartselect.getIncludeResurrectors()
		getOption("smartselect_includeantinuke").value = WG.smartselect.getIncludeAntinuke()
		getOption("smartselect_includeradar").value = WG.smartselect.getIncludeRadar()
		getOption("smartselect_includejammer").value = WG.smartselect.getIncludeJammer()
	end

	if WG.snow ~= nil and WG.snow.getSnowMap ~= nil then
		getOption("snowmap").value = WG.snow.getSnowMap()
	end

	-- doing this in order to detect if vsync is actually on due to the only when spectator setting
	local vsync = getOption("vsync")
	vsync.onchange(vsync, vsync.value)

	-- add user widgets

	-- look for custom widget options
	local userwidgetOptions = {}
	local usedCustomOptions = {}
	for k, option in ipairs(customOptions) do
		if not getOption(option.id) and option.widgetname then -- prevent adding duplicate
			if not userwidgetOptions[option.widgetname] then
				userwidgetOptions[option.widgetname] = {}
			end
			userwidgetOptions[option.widgetname][#userwidgetOptions[option.widgetname] + 1] = k
		end
	end
	local userwidgetsDetected = false
	for name, data in pairs(widgetHandler.knownWidgets) do
		if not data.fromZip then
			if not userwidgetsDetected then
				userwidgetsDetected = true
				options[#options + 1] = {
					id = "label_custom_widgets",
					group = "custom",
					name = BAR.I18N("ui.settings.option.label_widgets"),
					category = types.basic,
				}
			end
			local desc = data.desc or ""
			if desc ~= "" and WG.tooltip then
				local maxWidth = WG.tooltip.getFontsize() * 90
				local textLines, _ = font:WrapText(desc, maxWidth)
				desc = string.gsub(textLines, "[\n]", "\n")
			end
			if data.author and data.author ~= "" then
				desc = desc
					.. (desc ~= "" and "\n" or "")
					.. widgetOptionColor
					.. BAR.I18N("ui.settings.option.author")
					.. ": "
					.. data.author
			end
			local widgetOptionID = "widget_" .. string.gsub(data.basename, ".lua", "")
			options[#options + 1] = {
				id = widgetOptionID,
				group = "custom",
				category = types.basic,
				widget = name,
				name = name,
				type = "bool",
				value = GetWidgetToggleValue(name),
				description = desc,
			}
			if userwidgetOptions[name] then
				for k, customOption in pairs(userwidgetOptions[name]) do
					local option = table.copy(customOptions[customOption])
					if oldValues[option.id] ~= nil then
						option.value = oldValues[option.id]
					end
					option.parent = option.parent or widgetOptionID
					options[#options + 1] = option
					usedCustomOptions[customOption] = true
				end
			end
		end
	end

	indexOptions()

	-- add custom added options (done via WG.options.addOption)
	local otherCustomOptions, otherCustomIDs = {}, {}
	for k, option in ipairs(customOptions) do
		-- prevent adding duplicate (a label may come without an id)
		local duplicate = option.id ~= nil and (otherCustomIDs[option.id] or getOption(option.id))
		if not usedCustomOptions[k] and not duplicate then
			if option.id ~= nil then
				otherCustomIDs[option.id] = true
			end
			otherCustomOptions[#otherCustomOptions + 1] = option
		end
	end
	if otherCustomOptions[1] then
		options[#options + 1] = {
			id = "label_custom_options",
			group = "custom",
			name = BAR.I18N("ui.settings.option.label_options"),
			category = types.basic,
		}
		table.append(options, otherCustomOptions)
	end

	-- The full list in tab order. A sub-option sits one level below its parent, or moves up when the
	-- parent was removed, and every label gets an empty row below it for its text to run into.
	local groupRows = {}
	for _, group in ipairs(optionGroups) do
		groupRows[group.id] = {}
	end
	local placed = {}
	for _, option in ipairs(options) do
		local rows = groupRows[option.group]
		-- rows with neither type nor name are spacers, which the labels bring along now
		if rows and (option.type or option.name) then
			-- keep slider knobs within their slider
			if option.type == "slider" and not option.steps then
				if type(option.value) ~= "number" then
					option.value = option.min
				end
				option.value = math.max(option.min, math.min(option.max, option.value))
			end
			option.parentOption = option.parent and placed[option.parent]
			option.depth = option.parentOption and option.parentOption.depth + 1 or 0
			-- depth does the indenting; some translations still start with the old indent spaces
			if type(option.name) == "string" then
				option.name = option.name:gsub("^%s+", "")
			end
			if option.id and not placed[option.id] then
				placed[option.id] = option
			end
			rows[#rows + 1] = option
			if not option.type then
				option.spacer =
					{ id = option.id and option.id .. "_spacer", group = option.group, category = option.category }
				rows[#rows + 1] = option.spacer
			end
		end
	end
	unfilteredOptions = {}
	for _, group in ipairs(optionGroups) do
		group.numOptions = #groupRows[group.id]
		table.append(unfilteredOptions, groupRows[group.id])
	end
	options = unfilteredOptions
	indexOptions()

	if not requireRestartDefaultsInit then
		requireRestartDefaultsInit = true
		for i, option in pairs(options) do
			if option.restart and requireRestartDefaults[option.id] == nil then
				requireRestartDefaults[option.id] = option.value
			end
		end
	end

	changesRequireRestart = false
	for id, value in pairs(requireRestartDefaults) do
		if getOption(id) and getOption(id).value ~= value then
			changesRequireRestart = true
		end
	end

	view.rebind()
	-- Filter last, the checks above need every option. Also rebuilds the window.
	applyFilter()
end

function widget:MapDrawCmd(playerID, cmdType, startx, starty, startz, a, b, c)
	if continuouslyClean then
		return true
	end
end

function widget:UnsyncedHeightMapUpdate(x1, z1, x2, z2)
	if not waterDetected and Spring.GetGameFrame() > 30 then
		if heightmapChangeClock == nil then
			heightmapChangeClock = os_clock()
		end
		heightmapChangeBuffer[#heightmapChangeBuffer + 1] = { x1 * 8, z1 * 8, x2 * 8, z2 * 8 }
	end
end

function widget:GameOver()
	gameOver = true
	updateGrabinput()
end

local function optionsCmd(_, _, params)
	if show then
		view.close()
	else
		view.open()
	end
end

local function optionCmd(_, _, params)
	if not params[1] then
		return
	end

	local option = getOption(params[1])
	if not option then
		return
	end

	if not params[2] then
		if option.type == "bool" then
			applyOptionValueByID(option.id, not option.value)
		else
			view.open()
			view.reveal(option)
		end
	else
		if option.type == "select" then
			local selectKey = getSelectKey(option, params[2])
			if selectKey then
				applyOptionValueByID(option.id, selectKey)
			end
		elseif option.type == "bool" then
			local value
			if params[2] == "0" then
				value = false
			elseif params[2] == "0.5" then
				value = 0.5
			else
				value = true
			end
			applyOptionValueByID(option.id, value)
		elseif option.type == "color" then
			-- the three channels, as the strip shows them
			local value = {}
			for i = 1, 3 do
				local channel = tonumber(params[i + 1])
				if not channel then
					return
				end
				value[i] = math.max(0, math.min(option.max, channel))
			end
			applyOptionValueByID(option.id, value)
		else
			applyOptionValueByID(option.id, tonumber(params[2]))
		end
	end
end

local function devmodeCmd(_, _, params)
	Spring.SendCommands("option devmode")
end

local function profileCmd(_, _, params)
	if widgetHandler:IsWidgetKnown("Widget Profiler") then
		widgetHandler:ToggleWidget("Widget Profiler")
	end
end

local function grapherCmd(_, _, params)
	if widgetHandler:IsWidgetKnown("Frame Grapher") then
		widgetHandler:ToggleWidget("Frame Grapher")
	end
end

function widget:Initialize()
	-- Restart-with-state restore: if a saved state file exists from a previous
	-- restart-with-state trigger, read it now (io is available in LuaUI) and
	-- schedule it to be forwarded to the gadget on the first game frame.
	local RWS_FILE = "LuaUI/Config/restart_state.lua"
	local f = io.open(RWS_FILE, "r")
	if f then
		local content = f:read("*all")
		f:close()
		if content and content ~= "" then
			rwsRestoreData = content
		end
		-- Clear the file immediately so we don't restore again on the next restart
		local fc = io.open(RWS_FILE, "w")
		if fc then
			fc:close()
		end
	end

	-- disable ambient player widget
	if widgetHandler:IsWidgetKnown("Ambient Player") then
		widgetHandler:DisableWidget("Ambient Player")
	end
	if widgetHandler:IsWidgetKnown("Fog Volumes Old GL4") then
		widgetHandler:DisableWidget("Fog Volumes Old GL4")
	end
	if widgetHandler.orderList.FlowUI and widgetHandler.orderList.FlowUI < 0.5 then
		widgetHandler:EnableWidget("FlowUI")
	end
	if widgetHandler.orderList.Language and widgetHandler.orderList.Language < 0.5 then
		widgetHandler:EnableWidget("Language")
	end

	if widgetHandler.orderList["Infolos API"] and widgetHandler.orderList["Infolos API"] < 0.5 then
		widgetHandler:EnableWidget("Infolos API")
	end

	if widgetHandler.orderList["Mex Snap"] and widgetHandler.orderList["Mex Snap"] < 0.5 then
		widgetHandler:EnableWidget("Mex Snap")
	end
	-- set nano particle rotation: rotValue, rotVelocity, rotAcceleration, rotValueRNG, rotVelocityRNG, rotAccelerationRNG (in degrees)
	Spring.SetNanoProjectileParams(-180, -50, -50, 360, 100, 100)

	-- just making sure
	if widgetHandler.orderList["Pregame UI"] < 0.5 then
		widgetHandler:EnableWidget("Pregame UI")
	end
	if widgetHandler.orderList["Pregame Queue"] < 0.5 then
		widgetHandler:EnableWidget("Pregame Queue")
	end
	if widgetHandler.orderList["Screen Mode/Resolution Switcher"] < 0.5 then
		widgetHandler:EnableWidget("Screen Mode/Resolution Switcher")
	end

	-- enable GL4 unit rendering api's
	if widgetHandler.orderList["DrawUnitShape GL4"] < 0.5 then
		widgetHandler:EnableWidget("DrawUnitShape GL4")
	end
	if widgetHandler.orderList["HighlightUnit API GL4"] < 0.5 then
		widgetHandler:EnableWidget("HighlightUnit API GL4")
	end

	if newerVersion then
		if widgetHandler.orderList["Defense Range GL4"] < 0.5 then
			widgetHandler:EnableWidget("Defense Range GL4")
		end
	end

	updateGrabinput()
	widget:ViewResize()

	--if tonumber(Spring.GetConfigInt("CameraSmoothing", 0)) == 1 then
	--	Spring.SendCommands("set CamFrameTimeCorrection 1")
	--	Spring.SendCommands("set SmoothTimeOffset 2")
	--else
	--	Spring.SendCommands("set CamFrameTimeCorrection 0")
	--	Spring.SendCommands("set SmoothTimeOffset 0")
	--end

	-- make sure new icon system is used
	if Spring.GetConfigInt("UnitIconsAsUI", 0) == 0 then
		Spring.SendCommands("iconsasui 1")
		Spring.SetConfigInt("UnitIconsAsUI", 1)
	end

	if firstlaunchsetupDone == false then
		firstlaunchsetupDone = true

		Spring.Echo("First time setup:  done")
		Spring.SetConfigFloat("snd_airAbsorption", 0.35)

		-- Set lower defaults for lower end/potato systems
		if gpuMem < 3300 then
			if Spring.GetConfigInt("MSAALevel", 2) > 2 then
				Spring.SetConfigInt("MSAALevel", 2)
			end
		end
		if isPotatoGpu then
			Spring.SendCommands("water 0")
			Spring.SetConfigInt("Water", 0)

			--Spring.SetConfigInt("AdvMapShading", 0)
			--Spring.SendCommands("advmapshading 0")
			Spring.SendCommands("Shadows 0 1024")
			Spring.SetConfigInt("Shadows", 0)
			Spring.GetConfigInt("ShadowQuality", 0)
			Spring.SetConfigInt("ShadowMapSize", 1024)
			Spring.SetConfigInt("Shadows", 0)
			Spring.SetConfigInt("MSAALevel", 0)
			Spring.SetConfigFloat("ui_opacity", 0.7) -- set to be more opaque cause guishader isn't available
		else
			Spring.SendCommands("water 4")
			Spring.SetConfigInt("Water", 4)
		end

		local minMaxparticles = 12000
		if tonumber(Spring.GetConfigInt("MaxParticles", 1) or 0) < minMaxparticles then
			Spring.SetConfigInt("MaxParticles", minMaxparticles)
			Spring.Echo("First time setup:  setting MaxParticles config value to " .. minMaxparticles)
		end

		Spring.SetConfigInt("CamMode", 3)
		Spring.SendCommands("viewspring")
	end

	Spring.SetConfigFloat("CamTimeFactor", 1)
	Spring.SetConfigString("InputTextGeo", "0.35 0.72 0.03 0.04") -- input chat position posX, posY, ?, ?

	if Spring.GetGameFrame() == 0 then
		-- set minimum particle amount
		if tonumber(Spring.GetConfigInt("MaxParticles", 1) or 10000) <= 10000 then
			Spring.SetConfigInt("MaxParticles", 10000)
		end

		if Spring.GetConfigInt("MaxSounds", 128) < 128 then
			Spring.SetConfigInt("MaxSounds", 128)
		end

		-- limit MSAA
		if Spring.GetConfigInt("MSAALevel", 0) > 8 then
			Spring.SetConfigInt("MSAALevel", 8)
		end
	end

	-- make sure vertical angle is proper (not horizontal view)
	if
		Spring.GetGameFrame() == 0
		and (Spring.GetConfigInt("CamMode", 2) == 2 or Spring.GetConfigInt("CamMode", 2) == 3)
	then
		local cameraState = Spring.GetCameraState()
		cameraState.rx = 2.6
		Spring.SetCameraState(cameraState, 0.1)
	end

	-- make sure fog-start is smaller than fog-end in case maps have configured it this way
	if gl.GetAtmosphere("fogEnd") <= gl.GetAtmosphere("fogStart") then
		Spring.SetAtmosphere({ fogEnd = gl.GetAtmosphere("fogStart") + 0.01 })
	end

	Spring.SendCommands("minimap unitsize " .. (Spring.GetConfigFloat("MinimapIconScale", 3.5))) -- spring won't remember what you set with '/minimap iconssize #'

	-- lets the handler hide the rest of the interface while the window is open
	-- (this widget holds the real widgetHandler, so it passes itself)
	widgetHandler:RegisterModalWindow(widget, function()
		return show == true
	end)

	WG.options = {}
	WG.options.toggle = function(state)
		if state == nil then
			state = not show
		end
		if state then
			view.open()
		else
			view.close()
		end
	end
	WG.options.getOptionsList = function()
		local optionList = {}
		for i, option in pairs(unfilteredOptions) do
			optionList[#optionList + 1] = option.id
		end
		return optionList
	end
	WG.options.isvisible = function()
		return show
	end
	WG.options.getOptionValue = function(id)
		local option = getOption(id)
		if option then
			return option.value
		end
	end
	WG.options.getCameraSmoothness = function()
		return cameraTransitionTime
	end
	WG.options.disallowEsc = function()
		if openSelect or view.picker then
			--or draggingSlider then
			return true
		else
			return false
		end
	end
	WG.options.addOptions = function(newOptions)
		for _, option in ipairs(newOptions) do
			option.group = "custom"
			-- FIXME: Applying an option with a widget enables or disables that widget. Remove from user widgets.
			option.widget = nil
			customOptions[#customOptions + 1] = option
		end

		init()
	end
	WG.options.removeOptions = function(names)
		local remove = table.invert(names)
		customOptions = table.filterArray(customOptions, function(option)
			return not remove[option.id]
		end)

		init()
	end
	WG.options.addOption = function(option)
		return WG.options.addOptions({ option })
	end
	WG.options.removeOption = function(name)
		return WG.options.removeOptions({ name })
	end
	WG.options.applyOptionValue = function(id, value)
		local option = getOption(id)
		if not option then
			Spring.Echo("Options widget: applyOptionValue: option '" .. id .. "' not found")
			return
		end
		if option.widget then
			Spring.Echo("Options widget: applyOptionValue: option '" .. id .. "' denied by sandboxing")
			return
		end
		if option.type == "color" then
			if type(value) == "table" and tonumber(value[1]) and tonumber(value[2]) and tonumber(value[3]) then
				applyOptionValueByID(id, { tonumber(value[1]), tonumber(value[2]), tonumber(value[3]) })
			end
			return
		end
		applyOptionValueByID(id, tonumber(value))
	end

	widgetHandler.actionHandler:AddAction(self, "options", optionsCmd, nil, "t")
	widgetHandler.actionHandler:AddAction(self, "option", optionCmd, nil, "t")
	widgetHandler.actionHandler:AddAction(self, "devmode", devmodeCmd, nil, "t")
	widgetHandler.actionHandler:AddAction(self, "profile", profileCmd, nil, "t")
	widgetHandler.actionHandler:AddAction(self, "grapher", grapherCmd, nil, "t")
end

function widget:GameFrame(n)
	-- Send the saved restore state to the gadget on the very first frame.
	-- We wait until frame 1 so that all gadgets are fully initialised.
	if rwsRestoreData and n == 1 then
		local data = rwsRestoreData
		rwsRestoreData = nil
		Spring.SendLuaRulesMsg("rws_restore_begin")
		for i = 1, #data, RWS_MSG_CHUNK do
			Spring.SendLuaRulesMsg("rws_restore_chunk:" .. data:sub(i, i + RWS_MSG_CHUNK - 1))
		end
		Spring.SendLuaRulesMsg("rws_restore_commit")
	end
end

function widget:Shutdown()
	view.close()
	if windowList then
		glDeleteList(windowList)
		glDeleteList(backgroundGuishader)
	end
	if fontOption then
		for i, font in pairs(fontOption) do
			gl.DeleteFont(fontOption[i])
		end
	end
	if WG.guishader then
		WG.guishader.RemoveDlist("options")
		WG.guishader.RemoveScreenRect("options_select")
		WG.guishader.RemoveScreenRect("options_select_options")
		if selectOptionsList then
			WG.guishader.removeRenderDlist(selectOptionsList)
		end
	end
	if selectOptionsList then
		glDeleteList(selectOptionsList)
	end
	WG.options = nil

	resetUserVolume()
	Spring.SendCommands("grabinput 0")

	widgetHandler.actionHandler:RemoveAction(self, "options")
	widgetHandler.actionHandler:RemoveAction(self, "option")
	widgetHandler.actionHandler:RemoveAction(self, "devmode")
	widgetHandler.actionHandler:RemoveAction(self, "profile")
	widgetHandler.actionHandler:RemoveAction(self, "grapher")
end

function getSelectKey(option, value)
	for k, v in pairs(option.options) do
		if v == value then
			return k
		end
	end
	return false
end

function widget:GetConfigData()
	return {
		-- these could be re-implemented as custom springsetting configint/float
		cameraTransitionTime = cameraTransitionTime,
		cameraPanTransitionTime = cameraPanTransitionTime,
		useNetworkSmoothing = useNetworkSmoothing,
		desiredWaterValue = desiredWaterValue, -- configint water can't be used since we will set water 0 when no water is present

		-- options widget settings
		firsttimesetupDone = firstlaunchsetupDone,
		advSettings = advSettings,
		folded = view.folded,
		unfoldAll = view.unfoldAll,
		currentGroupTab = currentGroupTab,
		show = show,
		waterDetected = waterDetected,
		customPresets = customPresetOptions,
		changesRequireRestart = changesRequireRestart,
		requireRestartDefaults = requireRestartDefaults,

		-- to restore init defaults
		mapChecksum = Game.mapChecksum,
		defaultMapFog = defaultMapFog,
		defaultMapSunPos = defaultMapSunPos,
		defaultSkyAxisAngle = defaultSkyAxisAngle,
		defaultSunLighting = defaultSunLighting,
		resettedTonemapDefault = resettedTonemapDefault,
		version = version,
		edgeMoveWidth = edgeMoveWidth,
	}
end

function widget:SetConfigData(data)
	if data.version ~= nil then
		if data.version < version then
			newerVersion = true
		end
	else
		newerVersion = true
	end
	if data.desiredWaterValue ~= nil then
		desiredWaterValue = data.desiredWaterValue
	end
	if data.firsttimesetupDone ~= nil then
		firstlaunchsetupDone = data.firsttimesetupDone
	end
	if data.resettedTonemapDefault ~= nil then
		resettedTonemapDefault = data.resettedTonemapDefault
	end
	if data.cameraTransitionTime ~= nil then
		cameraTransitionTime = data.cameraTransitionTime
	end
	if data.cameraPanTransitionTime ~= nil then
		cameraPanTransitionTime = data.cameraPanTransitionTime
	end
	if data.edgeMoveWidth then
		edgeMoveWidth = data.edgeMoveWidth
	end
	if Spring.GetGameFrame() > 0 then
		if data.requireRestartDefaults then
			requireRestartDefaults = data.requireRestartDefaults
		end
		if data.changesRequireRestart then
			changesRequireRestart = data.changesRequireRestart
		end
		if data.currentGroupTab ~= nil then
			currentGroupTab = data.currentGroupTab
		end
		if data.show ~= nil then
			show = data.show
			if show then
				widgetHandler.textOwner = widget --widgetHandler:OwnText()
				Spring.SDLStartTextInput() -- because: touch chobby's text edit field once and widget:TextInput is gone for the game, so we make sure its started!
			end
		end
	end
	if data.advSettings ~= nil then
		advSettings = data.advSettings
	end
	if type(data.folded) == "table" then
		for id, folded in pairs(data.folded) do
			if type(folded) == "boolean" then
				view.folded[id] = folded
			end
		end
	end
	view.unfoldAll = data.unfoldAll == true
	if data.mapChecksum and data.mapChecksum == Game.mapChecksum then
		if data.defaultMapSunPos ~= nil then
			defaultMapSunPos = data.defaultMapSunPos
		end
		if data.defaultSunLighting ~= nil then
			defaultSunLighting = data.defaultSunLighting
		end
		if data.defaultMapFog ~= nil then
			defaultMapFog = data.defaultMapFog
		end
		if data.defaultSkyAxisAngle ~= nil then
			defaultSkyAxisAngle = data.defaultSkyAxisAngle
		end
	end
	if data.useNetworkSmoothing then
		useNetworkSmoothing = data.useNetworkSmoothing
	end
	if data.customOptions then
		--customOptions = data.customOptions
	end
	-- this setting moved to the springsetting WindowsPauseGame; carry a switched off one over
	if data.pauseGameWhenSingleplayer == false then
		Spring.SetConfigInt("WindowsPauseGame", 0)
	end
end

function widget:LanguageChanged()
	view.makeSearchBox()
	view.setLayout()
	init()
end
