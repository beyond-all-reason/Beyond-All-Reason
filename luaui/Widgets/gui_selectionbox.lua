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

-- Optional: Enable colored selection box based on modifier keys
local coloredModifierKeys = true  -- Set to false to always use white selection box

function widget:ViewResize(vsx, vsy)
	lineWidth = math.max(1.5, vsy / 1080)
end

function widget:Initialize()
	widget:ViewResize(Spring.GetViewGeometry())
	-- Disable engine's selection box rendering completely by setting line width to 0
	-- and making the color transparent

	Spring.LoadCmdColorsConfig('mouseBoxLineWidth 0')
end

function widget:Shutdown()
	-- Restore engine's default selection box
	Spring.LoadCmdColorsConfig('mouseBoxLineWidth 1.5')
end

function widget:DrawScreen() -- This blurs the UI elements obscured by other UI elements (only unit stats so far!)
	local x1, y1, x2, y2 = Spring.GetSelectionBox()
	if y2 then
		-- Get modifier key states
		local alt, ctrl, meta, shift = Spring.GetModKeyState()
		
		-- Don't draw selection box when holding alt, but only if smart select widget is enabled
		-- Suppress engine's box by returning true (consumes the draw event)
		if alt and WG.smartselect then
			return true
		end
		
		gl.PushMatrix()
		
		local a = 0.03
		-- Determine color based on modifier keys (if enabled)
		if coloredModifierKeys and ctrl then
			-- Brighter red when ctrl is held (with or without other keys)
			gl.Color(1, 0.25, 0.25, a)
		elseif coloredModifierKeys and shift then
			-- Bright green when only shift is held
			gl.Color(0.45, 1, 0.45, a)
		else
			-- White for normal selection
			gl.Color(1, 1, 1, a*0.8)
		end
		-- selection box background
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

		-- colored selection outline based on modifier keys
		gl.LineStipple(true)	-- animated stipplelines!
		gl.LineWidth(lineWidth)
		
		-- Determine color based on modifier keys (if enabled)
		if coloredModifierKeys and ctrl then
			-- Brighter red when ctrl is held (with or without other keys)
			gl.Color(1, 0.82, 0.82, 1)
		elseif coloredModifierKeys and shift then
			-- Bright green when only shift is held
			gl.Color(0.92, 1, 0.92, 1)
		else
			-- White for normal selection
			gl.Color(1, 1, 1, 1)
		end
		
		gl.Rect(x1, y1, x2, y2)
		gl.PolygonMode(GL.FRONT_AND_BACK, GL.FILL)
		gl.LineStipple(false)

		gl.PopMatrix()
	end
end
