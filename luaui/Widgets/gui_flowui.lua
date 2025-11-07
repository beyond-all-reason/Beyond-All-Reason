local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name      = "FlowUI",
		desc      = "GUI Framework",
		author    = "Floris",
		date      = "January 2021",
		license   = "GNU GPL, v2 or later",
		layer     = 1000000,
		enabled   = true
	}
end

WG.FlowUI = WG.FlowUI or {}
WG.FlowUI.version = 1
WG.FlowUI.initialized = false

WG.FlowUI.opacity = Spring.GetConfigFloat("ui_opacity", 0.7)
WG.FlowUI.scale = Spring.GetConfigFloat("ui_scale", 1)
WG.FlowUI.tileOpacity = Spring.GetConfigFloat("ui_tileopacity", 0.014)
WG.FlowUI.tileScale = Spring.GetConfigFloat("ui_tilescale", 7)
WG.FlowUI.tileSize = WG.FlowUI.tileScale

local function ViewResize(vsx, vsy)
	if not vsy then
		vsx, vsy = Spring.GetViewGeometry()
	end
	if WG.FlowUI.vsx and (WG.FlowUI.vsx == vsx and WG.FlowUI.vsy == vsy) then
		return
	end
	WG.FlowUI.vsx = vsx
	WG.FlowUI.vsy = vsy
	-- elementMargin: number of px between each separated ui element
	WG.FlowUI.elementMargin = math.floor(0.0045 * vsy * WG.FlowUI.scale)
	-- elementCorner: element cutoff corner size
	WG.FlowUI.elementCorner = WG.FlowUI.elementMargin * 0.9
	-- elementPadding: element inner (background) border/outline size
	WG.FlowUI.elementPadding = math.floor(0.003 * vsy * WG.FlowUI.scale)
	-- buttonPadding: button inner (background) border/outline size
	WG.FlowUI.buttonPadding = math.floor(0.002 * vsy * WG.FlowUI.scale)

	WG.FlowUI.tileSize = WG.FlowUI.tileScale * 0.003 * vsy * WG.FlowUI.scale
end

-- called at the bottom of this file
local function Initialize()
	ViewResize(Spring.GetViewGeometry())
	WG.FlowUI.initialized = true
	WG.FlowUI.shutdown = false
end

---------------------------------------------------------------------------------------
-- Widget callins  (layer = math.huge)
---------------------------------------------------------------------------------------

-- handling this in WG.FlowUI.Callin.ViewResize1 instead, so it gets executed before all other widgets
--function widget:ViewResize(vsx, vsy)
--end

function widget:Shutdown()
	WG.FlowUI.shutdown = true
	--WG.FlowUI = nil	-- commented out so it keeps at least working somewhat after an error
end

function widget:DrawScreenEffects()
	if Spring.IsGUIHidden() then
		return
	end
end

---------------------------------------------------------------------------------------
-- Custom widgethandler callins   (layer = -math.huge)
---------------------------------------------------------------------------------------

WG.FlowUI.Callin = {}

WG.FlowUI.Callin.ViewResize1 = function(vsx, vsy)
	ViewResize(vsx, vsy)
end

---------------------------------------------------------------------------------------
-- Draw functions
---------------------------------------------------------------------------------------

WG.FlowUI.Draw = {}

--[[
	RectRound
		draw rectangle with chopped off corners
	params
		px, py, sx, sy = left, bottom, right, top
	optional
		cs = corner size
		tl, tr, br, bl = enable/disable corners for TopLeft, TopRight, BottomRight, BottomLeft (default: 1)
		c1, c2 = top color, bottom color
]]
WG.FlowUI.Draw.RectRound = function(px, py, sx, sy,  cs,   tl, tr, br, bl,   c1, c2)
	-- RectRound(px,py,sx,sy,cs, tl,tr,br,bl, c1,c2): Draw a rectangular shape with cut off edges
	--  optional: tl,tr,br,bl  0 = no corner (1 = always)
	--  optional: c1,c2 for top-down color gradients
	local function DrawRectRound(px, py, sx, sy, cs, tl, tr, br, bl, c1, c2)
		cs = math.max(cs, 1)

		-- Pre-calculate gradient colors if needed (avoids redundant calculations)
		local hasGradient = c2 ~= nil
		local edgeColor, midColor
		if hasGradient then
			local csyMult = 1 / math.max(((sy - py) / cs), 1)
			-- Bottom edge color (blend from c1 towards c2)
			edgeColor = {
				c1[1] * (1 - csyMult) + (c2[1] * csyMult),
				c1[2] * (1 - csyMult) + (c2[2] * csyMult),
				c1[3] * (1 - csyMult) + (c2[3] * csyMult),
				c1[4] * (1 - csyMult) + (c2[4] * csyMult)
			}
			-- Top edge color (blend from c2 towards c1)
			midColor = {
				c2[1] * (1 - csyMult) + (c1[1] * csyMult),
				c2[2] * (1 - csyMult) + (c1[2] * csyMult),
				c2[3] * (1 - csyMult) + (c1[3] * csyMult),
				c2[4] * (1 - csyMult) + (c1[4] * csyMult)
			}
		end

		-- Mid section
		if c1 then
			gl.Color(c1[1], c1[2], c1[3], c1[4])
		end
		gl.Vertex(px + cs, py, 0)
		gl.Vertex(sx - cs, py, 0)
		if hasGradient then
			gl.Color(c2[1], c2[2], c2[3], c2[4])
		end
		gl.Vertex(sx - cs, sy, 0)
		gl.Vertex(px + cs, sy, 0)

		-- Left side
		if hasGradient then
			gl.Color(edgeColor[1], edgeColor[2], edgeColor[3], edgeColor[4])
		end
		gl.Vertex(px, py + cs, 0)
		gl.Vertex(px + cs, py + cs, 0)
		if hasGradient then
			gl.Color(midColor[1], midColor[2], midColor[3], midColor[4])
		end
		gl.Vertex(px + cs, sy - cs, 0)
		gl.Vertex(px, sy - cs, 0)

		-- Right side
		if hasGradient then
			gl.Color(edgeColor[1], edgeColor[2], edgeColor[3], edgeColor[4])
		end
		gl.Vertex(sx, py + cs, 0)
		gl.Vertex(sx - cs, py + cs, 0)
		if hasGradient then
			gl.Color(midColor[1], midColor[2], midColor[3], midColor[4])
		end
		gl.Vertex(sx - cs, sy - cs, 0)
		gl.Vertex(sx, sy - cs, 0)

		-- Bottom left corner
		if hasGradient then
			gl.Color(c1[1], c1[2], c1[3], c1[4])
		end
		if bl ~= nil and bl == 0 then
			gl.Vertex(px, py, 0)
		else
			gl.Vertex(px + cs, py, 0)
		end
		gl.Vertex(px + cs, py, 0)
		if hasGradient then
			gl.Color(edgeColor[1], edgeColor[2], edgeColor[3], edgeColor[4])
		end
		gl.Vertex(px + cs, py + cs, 0)
		gl.Vertex(px, py + cs, 0)

		-- Bottom right corner
		if hasGradient then
			gl.Color(c1[1], c1[2], c1[3], c1[4])
		end
		if br ~= nil and br == 0 then
			gl.Vertex(sx, py, 0)
		else
			gl.Vertex(sx - cs, py, 0)
		end
		gl.Vertex(sx - cs, py, 0)
		if hasGradient then
			gl.Color(edgeColor[1], edgeColor[2], edgeColor[3], edgeColor[4])
		end
		gl.Vertex(sx - cs, py + cs, 0)
		gl.Vertex(sx, py + cs, 0)

		-- Top left corner
		if hasGradient then
			gl.Color(c2[1], c2[2], c2[3], c2[4])
		end
		if tl ~= nil and tl == 0 then
			gl.Vertex(px, sy, 0)
		else
			gl.Vertex(px + cs, sy, 0)
		end
		gl.Vertex(px + cs, sy, 0)
		if hasGradient then
			gl.Color(midColor[1], midColor[2], midColor[3], midColor[4])
		end
		gl.Vertex(px + cs, sy - cs, 0)
		gl.Vertex(px, sy - cs, 0)

		-- Top right corner
		if hasGradient then
			gl.Color(c2[1], c2[2], c2[3], c2[4])
		end
		if tr ~= nil and tr == 0 then
			gl.Vertex(sx, sy, 0)
		else
			gl.Vertex(sx - cs, sy, 0)
		end
		gl.Vertex(sx - cs, sy, 0)
		if hasGradient then
			gl.Color(midColor[1], midColor[2], midColor[3], midColor[4])
		end
		gl.Vertex(sx - cs, sy - cs, 0)
		gl.Vertex(sx, sy - cs, 0)
	end
	gl.BeginEnd(GL.QUADS, DrawRectRound, px, py, sx, sy, cs, tl, tr, br, bl, c1, c2)
end

--[[
	RectRoundProgress
		draw rectangle pie (TODO: not with actual chopped off corners yet)
	params
		px, py, sx, sy = left, bottom, right, top
	optional
		cs = corner size
		progress
		color
]]
WG.FlowUI.Draw.RectRoundProgress = function(left, bottom, right, top, cs, progress, color)
	gl.PushMatrix()
	gl.Translate(left, bottom, 0)

	-- Pre-calculate dimensions (avoids redundant subtractions)
	local width = right - left
	local height = top - bottom
	right, top = width, height
	left, bottom = 0, 0

	local xcen = width * 0.5
	local ycen = height * 0.5
	local alpha = 360 * progress
	local alpha_rad = math.rad(alpha)
	local beta_rad = math.pi / 2 - alpha_rad

	-- Pre-calculate frequently used values
	local topMinusYcen = height - ycen  -- (top - ycen)
	local rightMinusXcen = width - xcen -- (right - xcen)

	local list = {}
	list[1] = { v = { xcen, ycen } }
	list[2] = { v = { xcen, height } }

	local x, y
	x = topMinusYcen * math.tan(alpha_rad) + xcen
	if alpha < 90 and x < width then
		-- < 25%
		list[3] = { v = { x, height } }
	else
		list[3] = { v = { width, height } }
		y = rightMinusXcen * math.tan(beta_rad) + ycen
		if alpha < 180 and y > 0 then
			-- < 50%
			list[4] = { v = { width, y } }
		else
			list[4] = { v = { width, 0 } }
			x = topMinusYcen * math.tan(-alpha_rad) + xcen
			if alpha < 270 and x > 0 then
				-- < 75%
				list[5] = { v = { x, 0 } }
			else
				list[5] = { v = { 0, 0 } }
				y = rightMinusXcen * math.tan(-beta_rad) + ycen
				if alpha < 350 and y < height then
					-- < 97%
					list[6] = { v = { 0, y } }
				else
					list[6] = { v = { 0, height } }
					x = topMinusYcen * math.tan(alpha_rad) + xcen
					list[7] = { v = { x, height } }
				end
			end
		end
	end

	gl.Color(color[1], color[2], color[3], color[4])
	gl.Translate(xcen, ycen, 0)
	gl.Scale(-1, 1, 1)	-- flip direction horizontally
	gl.Translate(-xcen, -ycen, 0)
	gl.Shape(GL.TRIANGLE_FAN, list)
	gl.Color(1, 1, 1, 1)
	gl.PopMatrix()
end

--[[
	TexturedRectRound
		draw rectangle with chopped off corners and a textured background tile
	params
		px, py, sx, sy = left, bottom, right, top
	optional
		tl, tr, br, bl = enable/disable corners for TopLeft, TopRight, BottomRight, BottomLeft (default: 1)
		size = texture tile size
		offset, offsetY = texture offset coordinates (offsetY=offset when offsetY isnt defined)
		texture = file location
]]
WG.FlowUI.Draw.TexturedRectRound = function(px, py, sx, sy,  cs,  tl, tr, br, bl,  size, offset, offsetY,  texture)
	local function DrawTexturedRectRound(px, py, sx, sy, cs, tl, tr, br, bl, size, offset, offsetY)
		-- Pre-calculate invariant values (avoids redundant per-vertex calculations)
		local width = sx - px
		local height = sy - py
		local invWidth = 1 / width
		local invHeight = 1 / height

		local scale = size and (size / width) or 1
		if scale == 0 then scale = 0.001 end
		local invScale = 1 / scale

		local offset = offset or 0
		local offsetY = offsetY or offset
		local ycMult = height / width

		local function drawTexCoordVertex(x, y)
			local xNorm = (x - px) * invWidth
			local yNorm = (y - py) * invHeight
			local yc = 1 - yNorm
			gl.TexCoord((xNorm * invScale) + offset, ((yc * ycMult) * invScale) + offsetY)
			gl.Vertex(x, y, 0)
		end

		-- mid section
		drawTexCoordVertex(px + cs, py)
		drawTexCoordVertex(sx - cs, py)
		drawTexCoordVertex(sx - cs, sy)
		drawTexCoordVertex(px + cs, sy)

		-- left side
		drawTexCoordVertex(px, py + cs)
		drawTexCoordVertex(px + cs, py + cs)
		drawTexCoordVertex(px + cs, sy - cs)
		drawTexCoordVertex(px, sy - cs)

		-- right side
		drawTexCoordVertex(sx, py + cs)
		drawTexCoordVertex(sx - cs, py + cs)
		drawTexCoordVertex(sx - cs, sy - cs)
		drawTexCoordVertex(sx, sy - cs)

		-- bottom left
		if bl ~= nil and bl == 0 then
			drawTexCoordVertex(px, py)
		else
			drawTexCoordVertex(px + cs, py)
		end
		drawTexCoordVertex(px + cs, py)
		drawTexCoordVertex(px + cs, py + cs)
		drawTexCoordVertex(px, py + cs)
		-- bottom right
		if br ~= nil and br == 0 then
			drawTexCoordVertex(sx, py)
		else
			drawTexCoordVertex(sx - cs, py)
		end
		drawTexCoordVertex(sx - cs, py)
		drawTexCoordVertex(sx - cs, py + cs)
		drawTexCoordVertex(sx, py + cs)
		-- top left
		if tl ~= nil and tl == 0 then
			drawTexCoordVertex(px, sy)
		else
			drawTexCoordVertex(px + cs, sy)
		end
		drawTexCoordVertex(px + cs, sy)
		drawTexCoordVertex(px + cs, sy - cs)
		drawTexCoordVertex(px, sy - cs)
		-- top right
		if tr ~= nil and tr == 0 then
			drawTexCoordVertex(sx, sy)
		else
			drawTexCoordVertex(sx - cs, sy)
		end
		drawTexCoordVertex(sx - cs, sy)
		drawTexCoordVertex(sx - cs, sy - cs)
		drawTexCoordVertex(sx, sy - cs)
	end

	if texture then
		gl.Texture(texture)
	end
	gl.BeginEnd(GL.QUADS, DrawTexturedRectRound, px, py, sx, sy, cs, tl, tr, br, bl, size, offset, offsetY)
	if texture then
		gl.Texture(false)
	end
end

--[[
	RectRoundCircle
		draw a square with border edge/fade
	params
		x,y,z, radius
	optional

]]
WG.FlowUI.Draw.RectRoundCircle = function(x, y, radius, cs, centerOffset, color1, color2)
	local function DrawRectRoundCircle(x, y, radius, cs, centerOffset, color1, color2)
		if not color2 then
			color2 = color1
		end

		-- Pre-calculate corner size ratio for inner octagon
		local cs2 = cs * (centerOffset / radius)

		-- Pre-calculate all 8 outer vertices (octagon corners)
		local coords = {
			{ x - radius + cs, y + radius }, -- top left
			{ x + radius - cs, y + radius }, -- top right
			{ x + radius, y + radius - cs }, -- right top
			{ x + radius, y - radius + cs }, -- right bottom
			{ x + radius - cs, y - radius }, -- bottom right
			{ x - radius + cs, y - radius }, -- bottom left
			{ x - radius, y - radius + cs }, -- left bottom
			{ x - radius, y + radius - cs }, -- left top
		}

		-- Pre-calculate all 8 inner vertices (octagon corners)
		local coords2 = {
			{ x - centerOffset + cs2, y + centerOffset }, -- top left
			{ x + centerOffset - cs2, y + centerOffset }, -- top right
			{ x + centerOffset, y + centerOffset - cs2 }, -- right top
			{ x + centerOffset, y - centerOffset + cs2 }, -- right bottom
			{ x + centerOffset - cs2, y - centerOffset }, -- bottom right
			{ x - centerOffset + cs2, y - centerOffset }, -- bottom left
			{ x - centerOffset, y - centerOffset + cs2 }, -- left bottom
			{ x - centerOffset, y + centerOffset - cs2 }, -- left top
		}

		-- Draw 8 quads connecting outer to inner octagon
		for i = 1, 8 do
			local i2 = (i >= 8 and 1 or i + 1)
			local outer1, outer2 = coords[i], coords[i2]
			local inner1, inner2 = coords2[i], coords2[i2]

			gl.Color(color2)
			gl.Vertex(outer1[1], outer1[2], 0)
			gl.Vertex(outer2[1], outer2[2], 0)
			gl.Color(color1)
			gl.Vertex(inner2[1], inner2[2], 0)
			gl.Vertex(inner1[1], inner1[2], 0)
		end
	end
	gl.BeginEnd(GL.QUADS, DrawRectRoundCircle, x, y, radius, cs, centerOffset, color1, color2)
end

--[[
	Circle
		draw a circle
	params
		x,z, radius
		sides = number outside vertexes
		color1 = (center) color
	optional
		color2 = edge color
]]
WG.FlowUI.Draw.Circle = function(x, z, radius, sides, color1, color2)
	local function DrawCircle(x, z, radius, sides, color1, color2)
		if not color2 then
			color2 = color1
		end

		-- Pre-calculate the angle increment between vertices
		local sideAngle = (math.pi * 2) / sides

		gl.Color(color1)
		gl.Vertex(x, z, 0)
		if color2 then
			gl.Color(color2)
		end

		-- Pre-calculate all vertex positions to avoid redundant trig in loop
		for i = 1, sides + 1 do
			local angle = i * sideAngle
			local cx = x + (radius * math.cos(angle))
			local cz = z + (radius * math.sin(angle))
			gl.Vertex(cx, cz, 0)
		end
	end
	gl.BeginEnd(GL.TRIANGLE_FAN, DrawCircle, x, 0, z, radius, sides, color1, color2)
end

--[[
	Element
		draw a complete standardized ui element having: border, tiled background, gloss on top and bottom
	params
		px, py, sx, sy = left, bottom, right, top
	optional
		tl, tr, br, bl = enable/disable corners for TopLeft, TopRight, BottomRight, BottomLeft (default: 1)
		ptl, ptr, pbr, pbl = inner border padding/size multiplier (default: 1) (set to 0 when you want to attach this ui element to another element so there is only padding done by one of the 2 elements)
		opacity = (default: ui_opacity springsetting)
		color1, color2 = (color1[4 value overrides the opacity param defined above)
		bgpadding = custom border size
]]
WG.FlowUI.Draw.Element = function(px, py, sx, sy,  tl, tr, br, bl,  ptl, ptr, pbr, pbl,  opacity, color1, color2, bgpadding, opaque)
	local opacity = math.min(1, opacity or WG.FlowUI.opacity)
	local color1 = color1 or { 0.04, 0.04, 0.04, opacity}
	local color2 = color2 or { 1, 1, 1, opacity * 0.1 }
	if opaque then
		color2 = { 0.12, 0.12, 0.12, 1 }
	end
	local ui_scale = WG.FlowUI.scale
	local bgpadding = bgpadding or WG.FlowUI.elementPadding
	local cs = WG.FlowUI.elementCorner * (bgpadding/WG.FlowUI.elementPadding)
	local glossMult = 2.3
	local tileopacity = WG.FlowUI.tileOpacity
	local bgtexSize = WG.FlowUI.tileSize

	local tl = tl or 1
	local tr = tr or 1
	local br = br or 1
	local bl = bl or 1

	local pxPad = bgpadding * (px > 0 and 1 or 0) * (pbl or 1)
	local pyPad = bgpadding * (py > 0 and 1 or 0) * (pbr or 1)
	local sxPad = bgpadding * (sx < WG.FlowUI.vsx and 1 or 0) * (ptr or 1)
	local syPad = bgpadding * (sy < WG.FlowUI.vsy and 1 or 0) * (ptl or 1)

	local glossHeight = math.floor(0.02 * WG.FlowUI.vsy * ui_scale)
	local doBottomFx = (sy-py-syPad-syPad) > (glossHeight*2.3)

	gl.Texture(false)

	-- Layer 1: Outer border (background)
	WG.FlowUI.Draw.RectRound(px, py, sx, sy, cs, tl, tr, br, bl,
		{ color1[1], color1[2], color1[3], opaque and 1 or color1[4] },
		{ color1[1], color1[2], color1[3], opaque and 1 or color1[4] })

	-- Layer 2: Main element with gradient (replaces the old "element" layer)
	cs = cs * 0.6
	local elemAlpha = opaque and opacity or color2[4] * 1.25
	WG.FlowUI.Draw.RectRound(px + pxPad, py + pyPad, sx - sxPad, sy - syPad, cs, tl, tr, br, bl,
		{ color2[1]*0.33, color2[2]*0.33, color2[3]*0.33, elemAlpha },
		{ color2[1], color2[2], color2[3], elemAlpha })

	-- Layer 3: Single combined inner layer (merges the two overlapping "inner darkening" layers)
	-- This creates the subtle inner border effect more efficiently
	local innerPad = 1.5  -- averaged from the old pad2 values
	local innerAlpha = opaque and 1 or color1[4] * 0.13
	local innerBrightness = opaque and 0.10 or 0
	WG.FlowUI.Draw.RectRound(px + pxPad + innerPad, py + pyPad + innerPad, sx - sxPad - innerPad, sy - syPad - innerPad,
		cs*0.5, tl, tr, br, bl,
		{ color1[1]+(innerBrightness*0.7), color1[2]+(innerBrightness*0.7), color1[3]+(innerBrightness*0.7), innerAlpha},
		{ color1[1]+innerBrightness, color1[2]+innerBrightness, color1[3]+innerBrightness, innerAlpha })

	-- Layer 4: Bottom darkening gradient (only if element is tall enough)
	if doBottomFx then
		local c = opaque and 0.06 or 0
		local c2 = opaque and 0.12 or 0
		WG.FlowUI.Draw.RectRound(px + pxPad + 2, py + 2, sx - sxPad - 2, py + ((sy-py)*0.75), cs*1.66, 0, 0, br, bl,
			{ c, c, c, opaque and 1 or 0.05 * glossMult },
			{ c2, c2, c2, opaque and 1 or 0 })
	end

	-- Layer 5: Top gloss highlight
	local glossTopAlpha = opaque and 1 or 0.07 * glossMult
	local glossTopC = opaque and 0.12 * glossMult or 1
	WG.FlowUI.Draw.RectRound(px + pxPad + 1, sy - syPad - 1 - glossHeight, sx - sxPad - 1, sy - syPad - 1,
		cs*0.5, tl, tr, 0, 0,
		{ 0.12, 0.12, 0.12, opaque and 1 or 0 },
		{ glossTopC, glossTopC, glossTopC, glossTopAlpha })

	-- Layer 6: Bottom gloss highlight (only if element is tall enough)
	if doBottomFx then
		local glossBotAlpha = opaque and 1 or 0.03 * glossMult
		local glossBotC = opaque and 0.05 * glossMult or 1
		WG.FlowUI.Draw.RectRound(px + pxPad + 1, py + pyPad + 1, sx - sxPad - 1, py + pyPad + glossHeight,
			cs, 0, 0, br, bl,
			{ glossBotC, glossBotC, glossBotC, glossBotAlpha },
			{ 0.06, 0.06, 0.06, opaque and 1 or 0 })
	end

	-- Layer 7: Top edge highlight (only if there's padding)
	if syPad > 0 then
		local edgeTopAlpha = opaque and 1 or 0.04 * glossMult
		local edgeTopC = opaque and 0.33 or 1
		WG.FlowUI.Draw.RectRound(px + pxPad + 1, sy - syPad - (cs*2.5), sx - sxPad - 1, sy - syPad - 1,
			cs, tl, tr, 0, 0,
			{ 0.24, 0.24, 0.24, opaque and 1 or 0 },
			{ edgeTopC, edgeTopC, edgeTopC, edgeTopAlpha })
	end

	-- Layer 8: Bottom edge highlight (only if there's padding)
	if pyPad > 0 then
		local edgeBotAlpha = opaque and 1 or 0.02 * glossMult
		local edgeBotC = opaque and 0.15 or 1
		WG.FlowUI.Draw.RectRound(px + pxPad + 1, py + pyPad + 1, sx - sxPad - 1, py + pyPad + (cs*2),
			cs, 0, 0, br, bl,
			{ edgeBotC, edgeBotC, edgeBotC, edgeBotAlpha },
			{ 0.13, 0.13, 0.13, opaque and 1 or 0 })
	end

	-- Layer 9: Background tile texture
	if tileopacity > 0 then
		gl.Color(1, 1, 1, tileopacity * (opaque and 1.33 or 1))
		WG.FlowUI.Draw.TexturedRectRound(px + pxPad, py + pyPad, sx - sxPad, sy - syPad, cs, tl, tr, br, bl, bgtexSize, (px+pxPad)/WG.FlowUI.vsx/bgtexSize, (py+pyPad)/WG.FlowUI.vsy/bgtexSize, "luaui/images/backgroundtile.png")
	end
end

--[[
	Button
		draw a complete standardized ui element having: border, tiled background, gloss on top and bottom
	params
		px, py, sx, sy = left, bottom, right, top
	optional
		tl, tr, br, bl = enable/disable corners for TopLeft, TopRight, BottomRight, BottomLeft (default: 1)
		ptl, ptr, pbr, pbl = inner padding multiplier (default: 1) (set to 0 when you want to attach this ui element to another element so there is only padding done by one of the 2 elements)
		opacity = (default: ui_opacity springsetting)
		color1, color2 = (color1[4] alpha value overrides opacity define above)
		bgpadding = custom border size
]]
WG.FlowUI.Draw.Button = function(px, py, sx, sy,  tl, tr, br, bl,  ptl, ptr, pbr, pbl,  opacity, color1, color2, bgpadding, glossMult)
	local opacity = opacity or 1
	local color1 = color1 or { 0, 0, 0, opacity}
	local color2 = color2 or { 1, 1, 1, opacity * 0.1}
	local bgpadding = math.floor(bgpadding or WG.FlowUI.buttonPadding*0.5)
	glossMult = (1 + (2 - (opacity * 1.5))) * (glossMult and glossMult or 1)

	local tl = tl or 1
	local tr = tr or 1
	local br = br or 1
	local bl = bl or 1

	local pxPad = bgpadding * (px > 0 and 1 or 0) * (pbl or 1)
	local pyPad = bgpadding * (py > 0 and 1 or 0) * (pbr or 1)
	local sxPad = bgpadding * (sx < WG.FlowUI.vsx and 1 or 0) * (ptr or 1)
	local syPad = bgpadding * (sy < WG.FlowUI.vsy and 1 or 0) * (ptl or 1)

	local glossHeight = math.floor((sy-py)*0.5)
	local cs = bgpadding * 1.6

	-- Layer 1: Background with gradient
	WG.FlowUI.Draw.RectRound(px, py, sx, sy, cs, tl, tr, br, bl, color1, color2)

	-- Layer 2: Combined top gloss (merges the old top edge highlight + top half gloss + top extended gloss)
	-- Alpha values tuned to match original brightness from overlapping layers
	local topGlossAlpha = 0.2 * glossMult
	WG.FlowUI.Draw.RectRound(px + pxPad, sy - syPad - glossHeight, sx - sxPad, sy - syPad, bgpadding, tl, tr, 0, 0,
		{ 1, 1, 1, 0 },
		{ 1, 1, 1, topGlossAlpha })

	-- Layer 3: Enhanced top edge highlight (thin bright edge at the very top)
	WG.FlowUI.Draw.RectRound(px + pxPad, sy - syPad - (bgpadding*2.5), sx - sxPad, sy - syPad, bgpadding, tl, tr, 0, 0,
		{ 1, 1, 1, 0 },
		{ 1, 1, 1, 0.08 * glossMult })

	-- Layer 4: Combined bottom gloss (merges the three overlapping bottom gloss layers)
	-- Alpha values tuned to match original brightness from overlapping layers
	local bottomGlossAlpha = 0.1 * glossMult
	WG.FlowUI.Draw.RectRound(px + pxPad, py + pyPad, sx - sxPad, py + pyPad + glossHeight, bgpadding, 0, 0, br, bl,
		{ 1, 1, 1, bottomGlossAlpha },
		{ 1, 1, 1, 0 })

	-- Layer 5: Bottom edge highlight (thin edge at the very bottom)
	WG.FlowUI.Draw.RectRound(px + pxPad, py + pyPad, sx - sxPad, py + pyPad + (bgpadding*2), bgpadding, 0, 0, br, bl,
		{ 1, 1, 1, 0.04 * glossMult },
		{ 1, 1, 1, 0 })
end

-- This was broken out from an internal "Unit" function, to allow drawing similar style icons in other places
WG.FlowUI.Draw.TexRectRound = function(px, py, sx, sy,  cs,  tl, tr, br, bl,  offset)

	-- Pre-calculate invariant values (avoids redundant per-vertex calculations)
	local height = sy - py
	local width = sx - px
	local invHeight = 1 / height
	local invWidth = 1 / width
	local offsetHalf = offset * 0.5
	local offsetScale = 1 - offset

	local function drawTexCoordVertex(x, y)
		local xNorm = (x - px) * invWidth  -- Normalized x position [0,1]
		local yNorm = (y - py) * invHeight -- Normalized y position [0,1]
		local xc = offsetHalf + xNorm * offsetScale
		local yc = 1 - offsetHalf - yNorm * offsetScale
		gl.TexCoord(xc, yc)
		gl.Vertex(x, y, 0)
	end

	-- mid section
	drawTexCoordVertex(px + cs, py)
	drawTexCoordVertex(sx - cs, py)
	drawTexCoordVertex(sx - cs, sy)
	drawTexCoordVertex(px + cs, sy)

	-- left side
	drawTexCoordVertex(px, py + cs)
	drawTexCoordVertex(px + cs, py + cs)
	drawTexCoordVertex(px + cs, sy - cs)
	drawTexCoordVertex(px, sy - cs)

	-- right side
	drawTexCoordVertex(sx, py + cs)
	drawTexCoordVertex(sx - cs, py + cs)
	drawTexCoordVertex(sx - cs, sy - cs)
	drawTexCoordVertex(sx, sy - cs)

	-- bottom left
	if bl ~= nil and bl == 0 then
		drawTexCoordVertex(px, py)
	else
		drawTexCoordVertex(px + cs, py)
	end
	drawTexCoordVertex(px + cs, py)
	drawTexCoordVertex(px + cs, py + cs)
	drawTexCoordVertex(px, py + cs)
	-- bottom right
	if br ~= nil and br == 0 then
		drawTexCoordVertex(sx, py)
	else
		drawTexCoordVertex(sx - cs, py)
	end
	drawTexCoordVertex(sx - cs, py)
	drawTexCoordVertex(sx - cs, py + cs)
	drawTexCoordVertex(sx, py + cs)
	-- top left
	if tl ~= nil and tl == 0 then
		drawTexCoordVertex(px, sy)
	else
		drawTexCoordVertex(px + cs, sy)
	end
	drawTexCoordVertex(px + cs, sy)
	drawTexCoordVertex(px + cs, sy - cs)
	drawTexCoordVertex(px, sy - cs)
	-- top right
	if tr ~= nil and tr == 0 then
		drawTexCoordVertex(sx, sy)
	else
		drawTexCoordVertex(sx - cs, sy)
	end
	drawTexCoordVertex(sx - cs, sy)
	drawTexCoordVertex(sx - cs, sy - cs)
	drawTexCoordVertex(sx, sy - cs)
end

--[[
	Unit
		draw a unit buildpic
	params
		px, py, sx, sy = left, bottom, right, top
	optional
		cs = corner size
		tl, tr, br, bl = enable/disable corners for TopLeft, TopRight, BottomRight, BottomLeft (default: 1)
		zoom = how much to enlarge/zoom into the buildpic (default:  0)
		borderSize, borderOpacity,
		texture, radarTexture, groupTexture,
		price = {metal, energy}
		queueCount
]]
WG.FlowUI.Draw.Unit = function(px, py, sx, sy,  cs,  tl, tr, br, bl,  zoom,  borderSize, borderOpacity,  texture, radarTexture, groupTexture, price, queueCount)
	local borderSize = borderSize~=nil and borderSize or math.min(math.max(1, math.floor((sx-px) * 0.024)), math.floor((WG.FlowUI.vsy*0.0015)+0.5))	-- set default with upper limit
	local cs = cs~=nil and cs or math.max(1, math.floor((sx-px) * 0.024))
	local halfSize = ((sx-px) * 0.5)
	borderOpacity = borderOpacity or 0.1

	-- Layer 1: Draw unit texture
	if texture then
		gl.Texture(texture)
	end
	gl.BeginEnd(GL.QUADS, WG.FlowUI.Draw.TexRectRound, px, py, sx, sy,  cs,  tl, tr, br, bl,  zoom+0.02)
	if texture then
		gl.Texture(false)
	end

	-- Layer 2: Darken bottom gradient (creates depth)
	WG.FlowUI.Draw.RectRound(px, py, sx, sy, cs, 0, 0, 1, 1, { 0, 0, 0, 0.2 }, { 0, 0, 0, 0 })

	-- Layers 3-4: Combined shine and edge effects (using additive blending)
	gl.Blending(GL.SRC_ALPHA, GL.ONE)

	-- Top shine gradient
	WG.FlowUI.Draw.RectRound(px, sy-((sy-py)*0.4), sx, sy, cs, 1, 1, 0, 0, {1, 1, 1, 0}, {1, 1, 1, 0.06})

	-- Feathered edge highlight (merged with border when borderSize > 0)
	if borderSize > 0 then
		-- Combined feather edge and border into single call
		WG.FlowUI.Draw.RectRoundCircle(
			px + halfSize,
			py + halfSize,
			halfSize, cs*0.7, halfSize - borderSize,
			{ 1, 1, 1, borderOpacity }, { 1, 1, 1, borderOpacity + 0.04 }
		)
	else
		-- Just the feather edge when no border
		WG.FlowUI.Draw.RectRoundCircle(
			px + halfSize,
			py + halfSize,
			halfSize, cs*0.7, halfSize*0.82,
			{ 1, 1, 1, 0 }, { 1, 1, 1, 0.04 }
		)
	end

	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)

	-- Layer 5: Group texture icon (if present)
	if groupTexture then
		local iconSize = math.floor((sx - px) * 0.3)
		gl.Color(1, 1, 1, 1)
		gl.Texture(groupTexture)
		gl.BeginEnd(GL.QUADS, WG.FlowUI.Draw.TexRectRound, px, sy - iconSize, px + iconSize, sy,  0,  0,0,0,0,  0.05)
		gl.Texture(false)
	end

	-- Layer 6: Radar texture icon (if present)
	if radarTexture then
		local iconSize = math.floor((sx - px) * 0.25)
		local iconPadding = math.floor((sx - px) * 0.03)
		gl.Color(0.88, 0.88, 0.88, 1)
		gl.Texture(radarTexture)
		gl.BeginEnd(GL.QUADS, WG.FlowUI.Draw.TexRectRound, px + iconPadding, py + iconPadding, px + iconPadding + iconSize, py + iconPadding + iconSize,  0,  0,0,0,0,  0.05)
		gl.Texture(false)
	end
end

--[[
	Scroller
		draw a slider (vertical)
	params
		px, py, sx, sy = left, bottom, right, top
		contentHeight = content height px
	optional
		position = (default: 0) current content height position
]]
WG.FlowUI.Draw.Scroller = function(px, py, sx, sy, contentHeight, position)
	local width = sx - px
	local height = sy - py
	local padding = math.floor((width * 0.25) + 0.5)
	local sliderAreaHeight = height - padding - padding
	local sliderHeight = sliderAreaHeight / contentHeight

	if sliderHeight < 1 then
		position = position or 0
		sliderHeight = math.floor((sliderHeight * sliderAreaHeight) + 0.5)
		local sliderPos = sy - padding - math.floor((sliderAreaHeight * (position / contentHeight)) + 0.5)

		-- background
		WG.FlowUI.Draw.RectRound(px, py, sx, sy, width * 0.2, 1, 1, 1, 1, { 0, 0, 0, 0.2 })

		-- slider
		local cs = (width - padding - padding) * 0.2
		if cs > sliderHeight * 0.5 then
			cs = sliderHeight * 0.5
		end
		WG.FlowUI.Draw.RectRound(px + padding, sliderPos - sliderHeight, sx - padding, sliderPos, cs, 1, 1, 1, 1, { 1, 1, 1, 0.16 })
	end
end

--[[
	Toggle
		draw a toggle
	params
		px, py, sx, sy = left, bottom, right, top
	optional
		state = (default: 0) 0 / 0.5 / 1
]]
WG.FlowUI.Draw.Toggle = function(px, py, sx, sy, state)
	local height = sy - py
	local width = sx - px
	local cs = height * 0.1
	local edgeWidth = math.max(1, math.floor(height * 0.1))

	-- faint dark outline edge
	WG.FlowUI.Draw.RectRound(px - edgeWidth, py - edgeWidth, sx + edgeWidth, sy + edgeWidth, cs * 1.5, 1, 1, 1, 1, { 0, 0, 0, 0.05 })
	-- top
	WG.FlowUI.Draw.RectRound(px, py, sx, sy, cs, 1, 1, 1, 1, { 0.5, 0.5, 0.5, 0.12 }, { 1, 1, 1, 0.12 })

	-- highlight
	gl.Blending(GL.SRC_ALPHA, GL.ONE)
	-- top
	WG.FlowUI.Draw.RectRound(px, sy - (edgeWidth * 3), sx, sy, edgeWidth, 1, 1, 1, 1, { 1, 1, 1, 0 }, { 1, 1, 1, 0.035 })
	-- bottom
	WG.FlowUI.Draw.RectRound(px, py, sx, py + (edgeWidth * 3), edgeWidth, 1, 1, 1, 1, { 1, 1, 1, 0.025 }, { 1, 1, 1, 0  })
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)

	-- draw state
	local padding = math.floor(height * 0.2)
	local radius = math.floor(height * 0.5) - padding
	local y = math.floor(py + (height * 0.5))
	local x, color, glowMult
	if state == true or state == 1 then		-- on
		x = sx - padding - radius
		color = {0.8, 1, 0.8, 1}
		glowMult = 1
	elseif not state or state == 0 then		-- off
		x = px + padding + radius
		color = {0.95, 0.66, 0.66, 1}
		glowMult = 0.3
	else		-- in between
		x = math.floor(px + (width * 0.42))
		color = {1, 0.9, 0.7, 1}
		glowMult = 0.6
	end
	WG.FlowUI.Draw.SliderKnob(x, y, radius, color)

	if glowMult > 0 then
		local boolGlow = radius * 1.75
		gl.Blending(GL.SRC_ALPHA, GL.ONE)
		gl.Color(color[1], color[2], color[3], 0.33 * glowMult)
		gl.Texture("LuaUI/Images/glow.dds")
		gl.TexRect(x - boolGlow, y - boolGlow, x + boolGlow, y + boolGlow)
		boolGlow = boolGlow * 2.2
		gl.Color(0.55, 1, 0.55, 0.1 * glowMult)
		gl.TexRect(x - boolGlow, y - boolGlow, x + boolGlow, y + boolGlow)
		gl.Texture(false)
		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	end
end

--[[
	Slider
		draw a slider knob
	params
		x, y, radius
	optional
		color
]]
WG.FlowUI.Draw.SliderKnob = function(x, y, radius, color)
	local color = color or {0.95,0.95,0.95,1}
	local color1 = {color[1]*0.55, color[2]*0.55, color[3]*0.55, color[4]}
	local edgeWidth = math.max(1, math.floor(radius * 0.05))
	local cs = math.max(1.1, radius*0.15)

	-- faint dark outline edge
	WG.FlowUI.Draw.RectRound(x-radius-edgeWidth, y-radius-edgeWidth, x+radius+edgeWidth, y+radius+edgeWidth, cs, 1,1,1,1, {0,0,0,0.1})
	-- knob
	WG.FlowUI.Draw.RectRound(x-radius, y-radius, x+radius, y+radius, cs, 1,1,1,1, color1, color)
	-- lighten knob inside edges
	WG.FlowUI.Draw.RectRoundCircle(x, y, radius, cs*0.5, radius*0.85, {1,1,1,0.1})
end

--[[
	Slider
		draw a slider
	params
		px, py, sx, sy = left, bottom, right, top
		steps = either a table of values or a number of smallest step size
		min, max = when steps is number: min/max scope of steps
]]
WG.FlowUI.Draw.Slider = function(px, py, sx, sy, steps, min, max)
	local height = sy - py
	local width = sx - px
	local cs = height * 0.25
	local edgeWidth = math.max(1, math.floor(height * 0.1))

	-- faint dark outline edge
	WG.FlowUI.Draw.RectRound(px - edgeWidth, py - edgeWidth, sx + edgeWidth, sy + edgeWidth, cs * 1.5, 1, 1, 1, 1, { 0, 0, 0, 0.05 })
	-- top
	WG.FlowUI.Draw.RectRound(px, py, sx, sy, cs, 1, 1, 1, 1, { 0.1, 0.1, 0.1, 0.22 }, { 0.9, 0.9, 0.9, 0.22 })
	-- bottom
	WG.FlowUI.Draw.RectRound(px, py, sx, sy, cs, 1, 1, 1, 1, { 1, 1, 1, 0.1 }, { 1, 1, 1, 0 })

	-- steps
	if steps then
		local numSteps = 0
		local processedSteps = {}
		if type(steps) == 'table' then
			min = steps[1]
			max = steps[#steps]
			numSteps = #steps
			for _, value in pairs(steps) do
				processedSteps[#processedSteps + 1] = math.floor((px + (width * ((value - min) / (max - min)))) + 0.5)
			end
			-- remove first step at the bar start
			processedSteps[1] = nil
		elseif min and max then
			numSteps = (max - min) / steps
			for i = 1, numSteps do
				processedSteps[#processedSteps + 1] = math.floor((px + (width / numSteps) * (#processedSteps + 1)) + 0.5)
				i = i + 1
			end
		end
		-- remove last step at the bar end
		processedSteps[#processedSteps] = nil

		-- dont bother when steps too small
		if numSteps and numSteps < (width / 7) then
			local stepSizeLeft = math.max(1, math.floor(width * 0.01))
			local stepSizeRight = math.floor(width * 0.005)
			for _, posX in pairs(processedSteps) do
				WG.FlowUI.Draw.RectRound(posX - stepSizeLeft, py + 1, posX + stepSizeRight, sy - 1, stepSizeLeft, 1, 1, 1, 1, { 0.12, 0.12, 0.12, 0.22 }, { 0, 0, 0, 0.22 })
			end
		end
	end

	-- add highlight
	local edgeWidth2 = edgeWidth * 2
	-- top
	WG.FlowUI.Draw.RectRound(px, sy - edgeWidth2, sx, sy, edgeWidth, 1, 1, 1, 1, { 1, 1, 1, 0 }, { 1, 1, 1, 0.07 })
	-- bottom
	WG.FlowUI.Draw.RectRound(px, py, sx, py + edgeWidth2, edgeWidth, 1, 1, 1, 1, { 1, 1, 1, 0 }, { 1, 1, 1, 0.045 })
end

--[[
	Selector
		draw a selector (drop-down menu)
	params
		px, py, sx, sy = left, bottom, right, top
]]
WG.FlowUI.Draw.Selector = function(px, py, sx, sy)
	local height = sy - py
	local cs = height * 0.1
	local edgeWidth = math.max(1, math.floor(height * 0.1))

	-- faint dark outline edge
	WG.FlowUI.Draw.RectRound(px - edgeWidth, py - edgeWidth, sx + edgeWidth, sy + edgeWidth, cs * 1.5, 1, 1, 1, 1, { 0, 0, 0, 0.05 })
	-- body
	WG.FlowUI.Draw.RectRound(px, py, sx, sy, cs, 1, 1, 1, 1, { 0.5, 0.5, 0.5, 0.12 }, { 1, 1, 1, 0.12 })

	-- highlight
	gl.Blending(GL.SRC_ALPHA, GL.ONE)
	-- top
	WG.FlowUI.Draw.RectRound(px, sy - (edgeWidth * 3), sx, sy, edgeWidth, 1, 1, 1, 1, { 1, 1, 1, 0 }, { 1, 1, 1, 0.035 })
	-- bottom
	WG.FlowUI.Draw.RectRound(px, py, sx, py + (edgeWidth * 3), edgeWidth, 1, 1, 1, 1, { 1, 1, 1, 0.025 }, { 1, 1, 1, 0  })
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)

	-- button
	WG.FlowUI.Draw.RectRound(sx - height, py, sx, sy, cs, 1, 1, 1, 1, { 1, 1, 1, 0.06 }, { 1, 1, 1, 0.14 })
	--WG.FlowUI.Draw.Button(sx-(sy-py), py, sx, sy, 1, 1, 1, 1, 1,1,1,1, nil, { 1, 1, 1, 0.1 }, nil, cs)
end

--[[
	SelectHighlight
		draw a highlighted area in a selector (drop-down menu)
		(also usable to highlight some other generic area)
	params
		px, py, sx, sy = left, bottom, right, top
		cs = corner size
		opacity
		color = {1,1,1}
]]
WG.FlowUI.Draw.SelectHighlight = function(px, py, sx, sy,  cs, opacity, color)
	local height = sy - py
	cs = cs or (height * 0.08)
	local edgeWidth = math.max(1, math.floor((WG.FlowUI.vsy * 0.001)))
	local opacity = opacity or 0.35
	local color = color or {1, 1, 1}

	-- faint dark outline edge
	WG.FlowUI.Draw.RectRound(px - edgeWidth, py - edgeWidth, sx + edgeWidth, sy + edgeWidth, cs * 1.5, 1, 1, 1, 1, { 0, 0, 0, 0.05 })
	-- body
	WG.FlowUI.Draw.RectRound(px, py, sx, sy, cs, 1, 1, 1, 1, { color[1] * 0.5, color[2] * 0.5, color[3] * 0.5, opacity }, { color[1], color[2], color[3], opacity })

	-- highlight
	gl.Blending(GL.SRC_ALPHA, GL.ONE)
	-- top
	WG.FlowUI.Draw.RectRound(px, sy - (edgeWidth * 3), sx, sy, edgeWidth, 1, 1, 1, 1, { 1, 1, 1, 0 }, { 1, 1, 1, 0.03 + (0.18 * opacity) })
	-- bottom
	WG.FlowUI.Draw.RectRound(px, py, sx, py + (edgeWidth * 3), edgeWidth, 1, 1, 1, 1, { 1, 1, 1, 0.015 + (0.06 * opacity) }, { 1, 1, 1, 0  })
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
end

Initialize()
