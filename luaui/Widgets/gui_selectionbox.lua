local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Selectionbox",
		desc = "Customizes the appearance of the selection box rectangle" ,
		author = "Floris",
		date = "September 2024",
		license = "GNU GPL, v2 or later",
		layer = 999999,
		enabled = true
	}
end

local lineWidth = 1.5

function widget:ViewResize(vsx, vsy)
	lineWidth = math.max(1.5, vsy / 1080)
end

function widget:Initialize()
	widget:ViewResize(Spring.GetViewGeometry())
	Spring.LoadCmdColorsConfig('mouseBoxLineWidth 0')
end

function widget:Shutdown()
	Spring.LoadCmdColorsConfig('mouseBoxLineWidth 1.5')
end

function widget:DrawScreen() -- This blurs the UI elements obscured by other UI elements (only unit stats so far!)
	local x1, y1, x2, y2 = Spring.GetSelectionBox()
	if y2 then
		gl.PushMatrix()
		-- selection box background
		gl.Color(1,1,1,0.025)
		gl.Rect(x1, y1, x2, y2)
		-- selection box background vignette
		gl.Color(1,1,1,0.03)
		gl.Texture(":n:"..LUAUI_DIRNAME.."Images/vignette.dds")
		gl.TexRect(x1, y1, x2, y2)
		gl.Texture(false)

		-- black selection outline
		gl.PolygonMode(GL.FRONT_AND_BACK, GL.LINE)
		gl.LineWidth(lineWidth + 2.5)
		gl.Color(0,0,0,0.12)
		gl.Rect(x1, y1, x2, y2)

		-- white selection outline
		gl.LineStipple(true)	-- animated stipplelines!
		gl.LineWidth(lineWidth)
		gl.Color(1,1,1,1)
		gl.Rect(x1, y1, x2, y2)
		gl.PolygonMode(GL.FRONT_AND_BACK, GL.FILL)
		gl.LineStipple(false)

		gl.PopMatrix()
	end
end
