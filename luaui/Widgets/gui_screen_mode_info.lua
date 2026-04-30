local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Screen Mode Info",
		desc = "Displays what kind of screen mode you see",
		author = "Floris",
		date = "November 2020",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

local keyConfig = VFS.Include("luaui/configs/keyboard_layouts.lua")

local spGetActionHotkeys = Spring.GetActionHotKeys
local spGetCameraState = Spring.GetCameraState
local spGetMapDrawMode = Spring.GetMapDrawMode
local spGetConfigString = Spring.GetConfigString
local spGetViewGeometry = Spring.GetViewGeometry
local i18n = I18N

local glPopMatrix = gl.PopMatrix
local glPushMatrix = gl.PushMatrix
local glTranslate = gl.Translate

local vsx, vsy = spGetViewGeometry()
local widgetScale = (0.80 + (vsx * vsy / 6000000))

local font
local currentLayout
local screenmode

local heightKey, metalKey, pathKey

local screenModeOverviewTable = { highlightColor = "\255\255\255\255", textColor = "\255\215\215\215", keyset = "" }
local screenModeTitleTable = { screenMode = "", highlightColor = "\255\255\255\255" }

-- Pre-allocated i18n parameter tables to avoid per-frame allocation
local heightParams = { keyset = "" }
local pathParams = { keyset = "" }
local metalParams = { keyset = "" }

local cachedCameraName = spGetCameraState().name or ""
local cachedTitleText = ""
local cachedDescText = ""
local needsTextRebuild = true
local framecount = 0

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function getActionHotkey(action)
	local key = spGetActionHotkeys(action)[1]

	if not key then
		return "none"
	end

	return keyConfig.sanitizeKey(key, currentLayout)
end

local function updateKeys()
	currentLayout = spGetConfigString("KeyboardLayout", "qwerty")
	screenModeOverviewTable.keyset = getActionHotkey("toggleoverview")
	metalKey = getActionHotkey("showmetalmap")
	heightKey = getActionHotkey("showelevation")
	pathKey = getActionHotkey("showpathtraversability")
end

function widget:ViewResize()
	vsx, vsy = spGetViewGeometry()
	widgetScale = (0.80 + (vsx * vsy / 6000000))

	font = WG["fonts"].getFont(1, 1.5)
end

function widget:Initialize()
	widget:ViewResize()
end

function widget:DrawScreen()
	if WG["topbar"] and WG["topbar"].showingQuit() then
		return
	end

	framecount = framecount + 1

	if framecount % 30 == 0 then
		local name = spGetCameraState().name
		if name ~= cachedCameraName then
			cachedCameraName = name
			needsTextRebuild = true
		end
	end

	local newScreenmode = spGetMapDrawMode()
	if newScreenmode ~= screenmode then
		screenmode = newScreenmode
		needsTextRebuild = true
	end

	local isOverview = cachedCameraName == "ov"
	if (screenmode == "normal" or screenmode == "los") and not isOverview then
		return
	end

	if needsTextRebuild then
		needsTextRebuild = false
		updateKeys()

		local description, title = "", ""
		local effectiveMode = screenmode

		if isOverview then
			effectiveMode = ""
			description = i18n("ui.screenMode.overview", screenModeOverviewTable)
		elseif screenmode == "height" then
			title = i18n("ui.screenMode.heightTitle")
			heightParams.keyset = heightKey
			description = i18n("ui.screenMode.heightmap", heightParams)
		elseif screenmode == "pathTraversability" then
			title = i18n("ui.screenMode.pathingTitle")
			pathParams.keyset = pathKey
			description = i18n("ui.screenMode.pathing", pathParams)
		elseif screenmode == "metal" then
			title = i18n("ui.screenMode.resourcesTitle")
			metalParams.keyset = metalKey
			description = i18n("ui.screenMode.resources", metalParams)
		end

		if effectiveMode ~= "" and title ~= "" then
			screenModeTitleTable.screenMode = title
			cachedTitleText = "\255\233\233\233" .. i18n("ui.screenMode.title", screenModeTitleTable)
		else
			cachedTitleText = ""
		end
		cachedDescText = description ~= "" and ("\255\215\215\215" .. description) or ""
	end

	if cachedTitleText == "" and cachedDescText == "" then
		return
	end

	glPushMatrix()
	glTranslate((vsx * 0.5), (vsy * 0.21), 0) --has to be below where newbie info appears!

	font:Begin()
	if cachedTitleText ~= "" then
		font:Print(cachedTitleText, 0, 15 * widgetScale, 20 * widgetScale, "oc")
	end
	if cachedDescText ~= "" then
		font:Print(cachedDescText, 0, -10 * widgetScale, 17 * widgetScale, "oc")
	end
	font:End()
	glPopMatrix()
end

function widget:GameOver()
	widgetHandler:RemoveWidget()
end
