--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name = "Screen Mode Info",
		desc = "Displays what kind of screen mode you see",
		author = "Floris",
		date = "November 2020",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true  --  loaded by default?
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local texts = {        -- fallback (if you want to change this, also update: language/en.lua, or it will be overwritten)
	screenmode = 'Screen mode',
	overviewmode = 'press \255\255\255\255[TAB]\255\215\215\215 to zoom onto mouse position',
	heightmapmode = '[F1] displays a different color for every height level',
	pathingmode = '[F2] shows where the selected unit can path/move, Green: OK, Red: problematic, Purple: Cant path',
	metalmapmode = '[F4] shows green areas on the map than contain metal',
}

local vsx, vsy = Spring.GetViewGeometry()
local widgetScale = (0.80 + (vsx * vsy / 6000000))

local glPopMatrix = gl.PopMatrix
local glPushMatrix = gl.PushMatrix
local glText = gl.Text
local glTranslate = gl.Translate

local font, chobbyInterface

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:ViewResize()
	vsx, vsy = Spring.GetViewGeometry()
	widgetScale = (0.80 + (vsx * vsy / 6000000))

	font = WG['fonts'].getFont(nil, 1, 0.2, 1.3)
end

function widget:Initialize()
	if WG['lang'] then
		texts = WG['lang'].getText('screenmodeinfo')
	end
	widget:ViewResize()
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
	if WG['topbar'] and WG['topbar'].showingQuit() then
		return
	end

	local st = Spring.GetCameraState()
	local screenmode = Spring.GetMapDrawMode()
	if (screenmode ~= 'normal' and screenmode ~= 'los') or st.name == 'ov' then
		local description = ''
		glPushMatrix()
		glTranslate((vsx * 0.5), (vsy * 0.21), 0) --has to be below where newbie info appears!
		--glScale(1.5, 1.5, 1)
		font:Begin()
		if st.name == 'ov' then
			screenmode = ''
		end
		if screenmode ~= '' then
			font:Print('\255\233\233\233' .. texts.screenmode..':  \255\255\255\255'..screenmode, 0, 15 * widgetScale, 20 * widgetScale, "oc")
		end
		if st.name == 'ov' then
			description = texts.overviewmode
		elseif screenmode == 'height' then
			description = texts.heightmapmode
		elseif screenmode == 'pathTraversability' then
			description = texts.pathingmode
		elseif screenmode == 'metal' then
			description = texts.metalmapmode
		end
		if description ~= '' then
			font:Print('\255\215\215\215' .. description, 0, -10 * widgetScale, 17 * widgetScale, "oc")
		end
		--font:Print(msg2, 0, -35 * widgetScale, 12.5 * widgetScale, "oc")
		font:End()
		glPopMatrix()
	end
	--prevScreenmode = screenmode
end

function widget:GameOver()
	widgetHandler:RemoveWidget(self)
end
