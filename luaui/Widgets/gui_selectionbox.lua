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

local backgroundOpacity = 0.03

function widget:Initialize()
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
		gl.Color(1,1,1,backgroundOpacity)
		gl.Rect(x1, y1, x2, y2)

		-- black selection outline
		gl.PolygonMode(GL.FRONT_AND_BACK, GL.LINE)
		gl.LineWidth(4.5)
		gl.Color(0,0,0,0.25)
		gl.Rect(x1, y1, x2, y2)

		-- white selection outline
		gl.LineWidth(1.5)
		gl.Color(1,1,1,1)
		gl.Rect(x1, y1, x2, y2)
		gl.PolygonMode(GL.FRONT_AND_BACK, GL.FILL)

		gl.PopMatrix()
	end
end
