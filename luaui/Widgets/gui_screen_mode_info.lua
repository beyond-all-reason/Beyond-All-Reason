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
		local description, title = '', ''
		glPushMatrix()
		glTranslate((vsx * 0.5), (vsy * 0.21), 0) --has to be below where newbie info appears!

		font:Begin()
		if st.name == 'ov' then
			screenmode = ''
		end
		
		if st.name == 'ov' then
			description = Spring.I18N('ui.screenMode.overview', { highlightColor = '\255\255\255\255', textColor = '\255\215\215\215' })
		elseif screenmode == 'height' then
			title = Spring.I18N('ui.screenMode.heightTitle')
			description = Spring.I18N('ui.screenMode.heightmap')
		elseif screenmode == 'pathTraversability' then
			title = Spring.I18N('ui.screenMode.pathingTitle')
			description = Spring.I18N('ui.screenMode.pathing')
		elseif screenmode == 'metal' then
			title = Spring.I18N('ui.screenMode.resourcesTitle')
			description = Spring.I18N('ui.screenMode.resources')
		end

		if screenmode ~= '' then
			font:Print('\255\233\233\233' .. Spring.I18N('ui.screenMode.title', { screenMode = title, highlightColor = "\255\255\255\255" }), 0, 15 * widgetScale, 20 * widgetScale, "oc")
		end

		if description ~= '' then
			font:Print('\255\215\215\215' .. description, 0, -10 * widgetScale, 17 * widgetScale, "oc")
		end

		font:End()
		glPopMatrix()
	end
end

function widget:GameOver()
	widgetHandler:RemoveWidget()
end
