local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Screen Mode Info",
		desc = "Displays what kind of screen mode you see",
		author = "Floris",
		date = "November 2020",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

local keyConfig = VFS.Include("luaui/configs/keyboard_layouts.lua")

local spGetActionHotkeys = Spring.GetActionHotKeys
local spGetCameraState = Spring.GetCameraState
local spGetMapDrawMode = Spring.GetMapDrawMode
local spGetConfigString = Spring.GetConfigString
local spGetViewGeometry = Spring.GetViewGeometry
local i18n = Spring.I18N

local glPopMatrix = gl.PopMatrix
local glPushMatrix = gl.PushMatrix
local glTranslate = gl.Translate

local vsx, vsy = spGetViewGeometry()
local widgetScale = (0.80 + (vsx * vsy / 6000000))

local font
local currentLayout
local screenmode

local heightKey, metalKey, pathKey

local screenModeOverviewTable = { highlightColor = '\255\255\255\255', textColor = '\255\215\215\215', keyset = '' }
local screenModeTitleTable = { screenMode = "", highlightColor = "\255\255\255\255" }

local st = spGetCameraState() -- reduce the usage of callins that create tables
local framecount = 0

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function getActionHotkey(action)
	local key = spGetActionHotkeys(action)[1]

	if not key then return "none" end

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

	font = WG['fonts'].getFont(1, 1.5)
end

function widget:Initialize()
	widget:ViewResize()
end

function widget:DrawScreen()
	if WG['topbar'] and WG['topbar'].showingQuit() then return end

	framecount = framecount + 1

	if framecount % 10 == 0 then
		st = spGetCameraState()
	end

	local newScreenmode = spGetMapDrawMode()
	local screenmodeChanged = newScreenmode ~= screenmode
	screenmode = newScreenmode

	if (screenmode ~= 'normal' and screenmode ~= 'los') or st.name == 'ov' then
		if (screenmodeChanged) then updateKeys() end

		local description, title = '', ''

		if st.name == 'ov' then
			screenmode = ''
		end

		if st.name == 'ov' then
			description = i18n('ui.screenMode.overview', screenModeOverviewTable)
		elseif screenmode == 'height' then
			title = i18n('ui.screenMode.heightTitle')
			description = i18n('ui.screenMode.heightmap', { keyset = heightKey })
		elseif screenmode == 'pathTraversability' then
			title = i18n('ui.screenMode.pathingTitle')
			description = i18n('ui.screenMode.pathing', { keyset = pathKey })
		elseif screenmode == 'metal' then
			title = i18n('ui.screenMode.resourcesTitle')
			description = i18n('ui.screenMode.resources', { keyset = metalKey })
		end

		if screenmode ~= '' or description ~= '' then
			glPushMatrix()
			glTranslate((vsx * 0.5), (vsy * 0.21), 0) --has to be below where newbie info appears!

			font:Begin()
			if screenmode ~= '' then
				screenModeTitleTable.screenMode = title
				font:Print('\255\233\233\233' .. i18n('ui.screenMode.title', screenModeTitleTable), 0, 15 * widgetScale,
					20 * widgetScale, "oc") -- these are still extremely slow btw
			end

			if description ~= '' then
				font:Print('\255\215\215\215' .. description, 0, -10 * widgetScale, 17 * widgetScale, "oc") -- these are still extremely slow btw
			end
			font:End()
			glPopMatrix()
		end
	end
end

function widget:GameOver()
	widgetHandler:RemoveWidget()
end
