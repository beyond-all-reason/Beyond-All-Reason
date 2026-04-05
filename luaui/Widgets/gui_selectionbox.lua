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

local mapSizeX = Game.mapSizeX
local mapSizeZ = Game.mapSizeZ

-- Track minimap selection
local minimapSelectionActive = false
local minimapSelectionStart = {x = 0, y = 0}
local minimapSelectionEnd = {x = 0, y = 0}
local minimapGeometryCache = {x = 0, y = 0, w = 0, h = 0}

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

function widget:MousePress(x, y, button)
	if button ~= 1 then return false end

	-- Don't track selection if minimap left-click-move is enabled
	if WG['minimap'] and WG['minimap'].getLeftClickMove and WG['minimap'].getLeftClickMove() then
		return false
	end

	-- Check if click is on minimap
	local mmX, mmY, mmW, mmH, minimized, maximized = Spring.GetMiniMapGeometry()
	if not mmX or minimized or maximized then return false end

	-- mmY is bottom edge, top edge is mmY + mmH
	local minimapBottom = mmY
	local minimapTop = mmY + mmH

	if x >= mmX and x <= mmX + mmW and y >= minimapBottom and y <= minimapTop then
		-- Click is on minimap, start tracking selection
		minimapSelectionActive = true
		minimapSelectionStart.x = x
		minimapSelectionStart.y = y
		minimapSelectionEnd.x = x
		minimapSelectionEnd.y = y
		-- Cache the geometry
		minimapGeometryCache.x = mmX
		minimapGeometryCache.y = mmY
		minimapGeometryCache.w = mmW
		minimapGeometryCache.h = mmH
	end

	return false
end

function widget:Update()
	-- Check if mouse is pressed and on minimap
	local mx, my, leftPressed = Spring.GetMouseState()

	if leftPressed then
		-- Don't track selection if minimap left-click-move is enabled
		if WG['minimap'] and WG['minimap'].getLeftClickMove and WG['minimap'].getLeftClickMove() then
			if minimapSelectionActive then
				minimapSelectionActive = false
			end
			return
		end

		local mmX, mmY, mmW, mmH, minimized, maximized = Spring.GetMiniMapGeometry()
		local vsx, vsy = Spring.GetViewGeometry()
		if mmX and not minimized and not maximized then
			-- mmY is the bottom edge of the minimap (distance from screen bottom)
			-- Top edge is at mmY + mmH
			local minimapBottom = mmY
			local minimapTop = mmY + mmH

			-- Check if mouse is within minimap bounds
			local onMinimap = (mx >= mmX and mx <= mmX + mmW and my >= minimapBottom and my <= minimapTop)

			if onMinimap then
				if not minimapSelectionActive then
					-- Start new selection
					minimapSelectionActive = true
					minimapSelectionStart.x = mx
					minimapSelectionStart.y = my
					-- Cache the geometry
					minimapGeometryCache.x = mmX
					minimapGeometryCache.y = mmY
					minimapGeometryCache.w = mmW
					minimapGeometryCache.h = mmH
				end
				-- Update end position (not clamped yet, will clamp in Draw)
				minimapSelectionEnd.x = mx
				minimapSelectionEnd.y = my
			elseif minimapSelectionActive then
				-- Mouse left minimap while dragging, clamp to minimap bounds
				minimapSelectionEnd.x = math.max(mmX, math.min(mmX + mmW, mx))
				minimapSelectionEnd.y = math.max(minimapBottom, math.min(minimapTop, my))
			end
		end
	else
		-- Mouse released
		if minimapSelectionActive then
			minimapSelectionActive = false
		end
	end
end

function widget:MouseMove(x, y, dx, dy, button)
	if minimapSelectionActive then
		minimapSelectionEnd.x = x
		minimapSelectionEnd.y = y
	end
	return false
end
function widget:DrawInMiniMap(minimapWidth, minimapHeight)
	-- Skip if PIP minimap replacement is active (it handles its own selection box)
	if WG['minimap'] and WG['minimap'].isPipMinimapActive and WG['minimap'].isPipMinimapActive() then
		return
	end

	-- Draw selection for minimap-tracked selection
	if not minimapSelectionActive then return end

	-- Don't draw if minimap left-click-move is enabled
	if WG['minimap'] and WG['minimap'].getLeftClickMove and WG['minimap'].getLeftClickMove() then
		return
	end

	-- Use cached geometry from when selection started
	local mmX = minimapGeometryCache.x
	local mmY = minimapGeometryCache.y
	local mmW = minimapGeometryCache.w
	local mmH = minimapGeometryCache.h

	if mmW == 0 or mmH == 0 then
		return
	end

	-- Get modifier key states
	local alt, ctrl, meta, shift = Spring.GetModKeyState()

	-- Validate that both start and end are within minimap bounds
	local x1, y1 = minimapSelectionStart.x, minimapSelectionStart.y
	local x2, y2 = minimapSelectionEnd.x, minimapSelectionEnd.y

	-- mmY is bottom edge, top edge is mmY + mmH
	local minimapBottom = mmY
	local minimapTop = mmY + mmH

	-- Clamp coordinates to minimap bounds (in case mouse went outside)
	x1 = math.max(mmX, math.min(mmX + mmW, x1))
	y1 = math.max(minimapBottom, math.min(minimapTop, y1))
	x2 = math.max(mmX, math.min(mmX + mmW, x2))
	y2 = math.max(minimapBottom, math.min(minimapTop, y2))	-- Convert screen coordinates to minimap pixel coordinates
	local mx1 = ((x1 - mmX) / mmW) * minimapWidth
	local my1 = ((y1 - mmY) / mmH) * minimapHeight
	local mx2 = ((x2 - mmX) / mmW) * minimapWidth
	local my2 = ((y2 - mmY) / mmH) * minimapHeight

	-- Ensure proper ordering (x1 < x2, y1 < y2)
	if mx1 > mx2 then mx1, mx2 = mx2, mx1 end
	if my1 > my2 then my1, my2 = my2, my1 end

	local width = mx2 - mx1
	local height = my2 - my1

	-- Skip if box is too small
	if width < 1 or height < 1 then
		return
	end	-- Draw filled rectangle with transparency
	local a = 0.08
	if ctrl then
		gl.Color(1, 0.25, 0.25, a)
	elseif shift then
		gl.Color(0.45, 1, 0.45, a)
	else
		gl.Color(1, 1, 1, a*0.8)
	end
	gl.BeginEnd(GL.QUADS, function()
		gl.Vertex(mx1, my1)
		gl.Vertex(mx2, my1)
		gl.Vertex(mx2, my2)
		gl.Vertex(mx1, my2)
	end)

	-- Draw stippled outline
	gl.LineStipple(true)
	gl.LineWidth(2.0)
	if ctrl then
		gl.Color(1, 0.82, 0.82, 1)
	elseif shift then
		gl.Color(0.92, 1, 0.92, 1)
	else
		gl.Color(1, 1, 1, 1)
	end
	gl.BeginEnd(GL.LINE_LOOP, function()
		gl.Vertex(mx1, my1)
		gl.Vertex(mx2, my1)
		gl.Vertex(mx2, my2)
		gl.Vertex(mx1, my2)
	end)
	gl.LineStipple(false)

	gl.LineWidth(1.0)
	gl.Color(1, 1, 1, 1)
end
