if SendToUnsynced then
	return
end

--[[
	FlowUI
	created by: Floris, january 2021

	Draw functions made available for use within gadgets and widgets.

	Installation notes:
	- add this file in your widget/gadget handler via VFS.Include("LuaUI/flowui.lua")
	- add function calls to the various "Spring triggered callins (widget/gadget)" (like: Spring.FlowUI.ViewResize(vsx, vsy))
]]

-- Setup
Spring.FlowUI = Spring.FlowUI or {}
Spring.FlowUI.version = 1
Spring.FlowUI.initialized = false

Spring.FlowUI.Initialize = function()	-- (gets executed at the end of this file)
	Spring.FlowUI.ViewResize(Spring.GetViewGeometry())
	--Spring.FlowUI.initialized = true	-- disable to debug and start fresh every luaui reload
end

-- Spring triggered callins (widget/gadget)
Spring.FlowUI.ViewResize = function(vsx, vsy)
	if Spring.FlowUI.vsx and (Spring.FlowUI.vsx == vsx and Spring.FlowUI.vsy == vsy) then
		return
	end
	Spring.FlowUI.vsx = vsx
	Spring.FlowUI.vsy = vsy
	Spring.FlowUI.elementMargin = math.floor(0.0045 * vsy * Spring.GetConfigFloat("ui_scale", 1))
	Spring.FlowUI.elementCorner = Spring.FlowUI.elementMargin
	Spring.FlowUI.elementPadding = math.ceil(Spring.FlowUI.elementMargin * 0.66)		-- elementPadding * 1.6
	Spring.FlowUI.buttonPadding = math.ceil(Spring.FlowUI.elementMargin * 0.44)
end

Spring.FlowUI.Update = function(dt)

end

Spring.FlowUI.DrawScreen = function()

end

-- Draw functions
Spring.FlowUI.Draw = {}

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
Spring.FlowUI.Draw.RectRound = function(px, py, sx, sy,  cs,   tl, tr, br, bl,   c1, c2)
	-- RectRound(px,py,sx,sy,cs, tl,tr,br,bl, c1,c2): Draw a rectangular shape with cut off edges
	--  optional: tl,tr,br,bl  0 = no corner (1 = always)
	--  optional: c1,c2 for top-down color gradients
	local function DrawRectRound(px, py, sx, sy, cs, tl, tr, br, bl, c1, c2)
		local csyMult = 1 / ((sy - py) / cs)

		if c1 then
			gl.Color(c1[1], c1[2], c1[3], c1[4])
		end
		gl.Vertex(px + cs, py, 0)
		gl.Vertex(sx - cs, py, 0)
		if c2 then
			gl.Color(c2[1], c2[2], c2[3], c2[4])
		end
		gl.Vertex(sx - cs, sy, 0)
		gl.Vertex(px + cs, sy, 0)

		-- left side
		if c2 then
			gl.Color(c1[1] * (1 - csyMult) + (c2[1] * csyMult), c1[2] * (1 - csyMult) + (c2[2] * csyMult), c1[3] * (1 - csyMult) + (c2[3] * csyMult), c1[4] * (1 - csyMult) + (c2[4] * csyMult))
		end
		gl.Vertex(px, py + cs, 0)
		gl.Vertex(px + cs, py + cs, 0)
		if c2 then
			gl.Color(c2[1] * (1 - csyMult) + (c1[1] * csyMult), c2[2] * (1 - csyMult) + (c1[2] * csyMult), c2[3] * (1 - csyMult) + (c1[3] * csyMult), c2[4] * (1 - csyMult) + (c1[4] * csyMult))
		end
		gl.Vertex(px + cs, sy - cs, 0)
		gl.Vertex(px, sy - cs, 0)

		-- right side
		if c2 then
			gl.Color(c1[1] * (1 - csyMult) + (c2[1] * csyMult), c1[2] * (1 - csyMult) + (c2[2] * csyMult), c1[3] * (1 - csyMult) + (c2[3] * csyMult), c1[4] * (1 - csyMult) + (c2[4] * csyMult))
		end
		gl.Vertex(sx, py + cs, 0)
		gl.Vertex(sx - cs, py + cs, 0)
		if c2 then
			gl.Color(c2[1] * (1 - csyMult) + (c1[1] * csyMult), c2[2] * (1 - csyMult) + (c1[2] * csyMult), c2[3] * (1 - csyMult) + (c1[3] * csyMult), c2[4] * (1 - csyMult) + (c1[4] * csyMult))
		end
		gl.Vertex(sx - cs, sy - cs, 0)
		gl.Vertex(sx, sy - cs, 0)

		-- bottom left corner
		if c2 then
			gl.Color(c1[1], c1[2], c1[3], c1[4])
		end
		if bl ~= nil and bl == 0 then
			gl.Vertex(px, py, 0)
		else
			gl.Vertex(px + cs, py, 0)
		end
		gl.Vertex(px + cs, py, 0)
		if c2 then
			gl.Color(c1[1] * (1 - csyMult) + (c2[1] * csyMult), c1[2] * (1 - csyMult) + (c2[2] * csyMult), c1[3] * (1 - csyMult) + (c2[3] * csyMult), c1[4] * (1 - csyMult) + (c2[4] * csyMult))
		end
		gl.Vertex(px + cs, py + cs, 0)
		gl.Vertex(px, py + cs, 0)

		-- bottom right corner
		if c2 then
			gl.Color(c1[1], c1[2], c1[3], c1[4])
		end
		if br ~= nil and br == 0 then
			gl.Vertex(sx, py, 0)
		else
			gl.Vertex(sx - cs, py, 0)
		end
		gl.Vertex(sx - cs, py, 0)
		if c2 then
			gl.Color(c1[1] * (1 - csyMult) + (c2[1] * csyMult), c1[2] * (1 - csyMult) + (c2[2] * csyMult), c1[3] * (1 - csyMult) + (c2[3] * csyMult), c1[4] * (1 - csyMult) + (c2[4] * csyMult))
		end
		gl.Vertex(sx - cs, py + cs, 0)
		gl.Vertex(sx, py + cs, 0)

		-- top left corner
		if c2 then
			gl.Color(c2[1], c2[2], c2[3], c2[4])
		end
		if tl ~= nil and tl == 0 then
			gl.Vertex(px, sy, 0)
		else
			gl.Vertex(px + cs, sy, 0)
		end
		gl.Vertex(px + cs, sy, 0)
		if c2 then
			gl.Color(c2[1] * (1 - csyMult) + (c1[1] * csyMult), c2[2] * (1 - csyMult) + (c1[2] * csyMult), c2[3] * (1 - csyMult) + (c1[3] * csyMult), c2[4] * (1 - csyMult) + (c1[4] * csyMult))
		end
		gl.Vertex(px + cs, sy - cs, 0)
		gl.Vertex(px, sy - cs, 0)

		-- top right corner
		if c2 then
			gl.Color(c2[1], c2[2], c2[3], c2[4])
		end
		if tr ~= nil and tr == 0 then
			gl.Vertex(sx, sy, 0)
		else
			gl.Vertex(sx - cs, sy, 0)
		end
		gl.Vertex(sx - cs, sy, 0)
		if c2 then
			gl.Color(c2[1] * (1 - csyMult) + (c1[1] * csyMult), c2[2] * (1 - csyMult) + (c1[2] * csyMult), c2[3] * (1 - csyMult) + (c1[3] * csyMult), c2[4] * (1 - csyMult) + (c1[4] * csyMult))
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
Spring.FlowUI.Draw.RectRoundProgress = function(left, bottom, right, top, cs, progress, color)
	local xcen = (left + right) / 2
	local ycen = (top + bottom) / 2
	local alpha = 360 * progress
	local alpha_rad = math.rad(alpha)
	local beta_rad = math.pi / 2 - alpha_rad
	local list = {}
	local listCount = 1
	list[listCount] = { v = { xcen, ycen } }
	listCount = listCount + 1
	list[#list + 1] = { v = { xcen, top } }

	local x, y
	x = (top - ycen) * math.tan(alpha_rad) + xcen
	if alpha < 90 and x < right then
		-- < 25%
		listCount = listCount + 1
		list[listCount] = { v = { x, top } }
	else
		listCount = listCount + 1
		list[listCount] = { v = { right, top } }
		y = (right - xcen) * math.tan(beta_rad) + ycen
		if alpha < 180 and y > bottom then
			-- < 50%
			listCount = listCount + 1
			list[listCount] = { v = { right, y } }
		else
			listCount = listCount + 1
			list[listCount] = { v = { right, bottom } }
			x = (top - ycen) * math.tan(-alpha_rad) + xcen
			if alpha < 270 and x > left then
				-- < 75%
				listCount = listCount + 1
				list[listCount] = { v = { x, bottom } }
			else
				listCount = listCount + 1
				list[listCount] = { v = { left, bottom } }
				y = (right - xcen) * math.tan(-beta_rad) + ycen
				if alpha < 350 and y < top then
					-- < 97%
					listCount = listCount + 1
					list[listCount] = { v = { left, y } }
				else
					listCount = listCount + 1
					list[listCount] = { v = { left, top } }
					x = (top - ycen) * math.tan(alpha_rad) + xcen
					listCount = listCount + 1
					list[listCount] = { v = { x, top } }
				end
			end
		end
	end

	gl.Color(color[1], color[2], color[3], color[4])
	gl.Shape(GL.TRIANGLE_FAN, list)
	gl.Color(1, 1, 1, 1)
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
Spring.FlowUI.Draw.TexturedRectRound = function(px, py, sx, sy,  cs,  tl, tr, br, bl,  size, offset, offsetY,  texture)
	local function DrawTexturedRectRound(px, py, sx, sy, cs, tl, tr, br, bl, size, offset, offsetY)
		local scale = size and (size / (sx-px)) or 1
		local offset = offset or 0
		local csyMult = 1 / ((sy - py) / cs)
		local ycMult = (sy-py) / (sx-px)

		local function drawTexCoordVertex(x, y)
			local yc = 1 - ((y - py) / (sy - py))
			local xc = ((x - px) / (sx - px))
			yc = 1 - ((y - py) / (sy - py))
			gl.TexCoord((xc/scale)+offset, ((yc*ycMult)/scale)+(offsetY or offset))
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
Spring.FlowUI.Draw.RectRoundCircle = function(x, y, radius, cs, centerOffset, color1, color2)
	local function DrawRectRoundCircle(x, y, radius, cs, centerOffset, color1, color2)
		if not color2 then
			color2 = color1
		end
		--centerOffset = 0
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
		local cs2 = cs * (centerOffset / radius)
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
		for i = 1, 8 do
			local i2 = (i >= 8 and 1 or i + 1)
			gl.Color(color2)
			gl.Vertex(coords[i][1], coords[i][2], 0)
			gl.Vertex(coords[i2][1], coords[i2][2], 0)
			gl.Color(color1)
			gl.Vertex(coords2[i2][1], coords2[i2][2], 0)
			gl.Vertex(coords2[i][1], coords2[i][2], 0)
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
Spring.FlowUI.Draw.Circle = function(x, z, radius, sides, color1, color2)
	local function DrawCircle(x, z, radius, sides, color1, color2)
		if not color2 then
			color2 = color1
		end
		local sideAngle = (math.pi * 2) / sides
		gl.Color(color1)
		gl.Vertex(x, z, 0)
		if color2 then
			gl.Color(color2)
		end
		for i = 1, sides + 1 do
			local cx = x + (radius * math.cos(i * sideAngle))
			local cz = z + (radius * math.sin(i * sideAngle))
			gl.Vertex(cx, cz, 0)
		end
	end
	gl.BeginEnd(GL.TRIANGLE_FAN, DrawCircle, x, 0, z, radius, sides, color1, color2)
end

--[[
	UiElement
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
Spring.FlowUI.Draw.Element = function(px, py, sx, sy,  tl, tr, br, bl,  ptl, ptr, pbr, pbl,  opacity, color1, color2, bgpadding)
	local opacity = opacity or Spring.GetConfigFloat("ui_opacity", 0.6)
	local color1 = color1 or { 0, 0, 0, opacity}
	local color2 = color2 or { 1, 1, 1, opacity * 0.1}
	local ui_scale = Spring.GetConfigFloat("ui_scale", 1)
	local bgpadding = bgpadding or Spring.FlowUI.elementPadding
	local cs = Spring.FlowUI.elementCorner * (bgpadding/Spring.FlowUI.elementPadding)
	local glossMult = 1 + (2 - (opacity * 1.5))
	local tileopacity = Spring.GetConfigFloat("ui_tileopacity", 0.012)
	local bgtexScale = Spring.GetConfigFloat("ui_tilescale", 7)
	local bgtexSize = math.floor(Spring.FlowUI.elementPadding * bgtexScale)

	local tl = tl or 1
	local tr = tr or 1
	local br = br or 1
	local bl = bl or 1

	local pxPad = bgpadding * (px > 0 and 1 or 0) * (pbl or 1)
	local pyPad = bgpadding * (py > 0 and 1 or 0) * (pbr or 1)
	local sxPad = bgpadding * (sx < Spring.FlowUI.vsx and 1 or 0) * (ptr or 1)
	local syPad = bgpadding * (sy < Spring.FlowUI.vsy and 1 or 0) * (ptl or 1)

	-- background
	gl.Texture(false)
	Spring.FlowUI.Draw.RectRound(px, py, sx, sy, cs, tl, tr, br, bl, { color1[1], color1[2], color1[3], color1[4] }, { color1[1], color1[2], color1[3], color1[4] })

	cs = cs * 0.6
	Spring.FlowUI.Draw.RectRound(px + pxPad, py + pyPad, sx - sxPad, sy - syPad, cs, tl, tr, br, bl, { color2[1]*0.33, color2[2]*0.33, color2[3]*0.33, color2[4] }, { color2[1], color2[2], color2[3], color2[4] })

	-- gloss
	gl.Blending(GL.SRC_ALPHA, GL.ONE)
	local glossHeight = math.floor(0.02 * Spring.FlowUI.vsy * ui_scale)
	-- top
	Spring.FlowUI.Draw.RectRound(px + pxPad, sy - syPad - glossHeight, sx - sxPad, sy - syPad, cs, tl, tr, 0, 0, { 1, 1, 1, 0 }, { 1, 1, 1, 0.07 * glossMult })
	-- bottom
	Spring.FlowUI.Draw.RectRound(px + pxPad, py + pyPad, sx - sxPad, py + pyPad + glossHeight, cs, 0, 0, br, bl, { 1, 1, 1, 0.03 * glossMult }, { 1 ,1 ,1 , 0 })

	-- highlight edges thinly
	-- top
	Spring.FlowUI.Draw.RectRound(px + pxPad, sy - syPad - (cs*2.5), sx - sxPad, sy - syPad, cs, tl, tr, 0, 0, { 1, 1, 1, 0 }, { 1, 1, 1, 0.04 * glossMult })
	-- bottom
	Spring.FlowUI.Draw.RectRound(px + pxPad, py + pyPad, sx - sxPad, py + pyPad + (cs*2), cs, 0, 0, br, bl, { 1, 1, 1, 0.02 * glossMult }, { 1 ,1 ,1 , 0 })
	-- left
	--Spring.FlowUI.Draw.RectRound(px + pxPad, py + syPad, px + pxPad + (cs*2), sy - syPad, cs, tl, tr, 0, 0, { 1, 1, 1, 0.02 * glossMult }, { 1, 1, 1, 0 })
	-- right
	--Spring.FlowUI.Draw.RectRound(sx - sxPad - (cs*2), py + syPad, sx - sxPad, sy - syPad, cs, tl, tr, 0, 0, { 1, 1, 1, 0.02 * glossMult }, { 1, 1, 1, 0 })

	--Spring.FlowUI.Draw.RectRound(px + (pxPad*1.6), sy - syPad - math.ceil(bgpadding*0.25), sx - (sxPad*1.6), sy - syPad, 0, tl, tr, 0, 0, { 1, 1, 1, 0.012 }, { 1, 1, 1, 0.07 * glossMult })
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)

	-- darkening bottom
	Spring.FlowUI.Draw.RectRound(px, py, sx, py + ((sy-py)*0.75), cs*1.66, 0, 0, br, bl, { 0,0,0, 0.05 * glossMult }, { 0,0,0, 0 })

	-- tile
	if tileopacity > 0 then
		gl.Color(1,1,1, tileopacity)
		Spring.FlowUI.Draw.TexturedRectRound(px + pxPad, py + pyPad, sx - sxPad, sy - syPad, cs, tl, tr, br, bl, bgtexSize, (px+pxPad)/Spring.FlowUI.vsx/bgtexSize, (py+pyPad)/Spring.FlowUI.vsy/bgtexSize, "modules/flowui/images/backgroundtile.png")
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
Spring.FlowUI.Draw.Button = function(px, py, sx, sy,  tl, tr, br, bl,  ptl, ptr, pbr, pbl,  opacity, color1, color2, bgpadding)
	local opacity = opacity or 1
	local color1 = color1 or { 0, 0, 0, opacity}
	local color2 = color2 or { 1, 1, 1, opacity * 0.1}
	local bgpadding = math.floor(bgpadding or Spring.FlowUI.buttonPadding*0.5)
	local glossMult = 1 + (2 - (opacity * 1.5))

	local tl = tl or 1
	local tr = tr or 1
	local br = br or 1
	local bl = bl or 1

	local pxPad = bgpadding * (px > 0 and 1 or 0) * (pbl or 1)
	local pyPad = bgpadding * (py > 0 and 1 or 0) * (pbr or 1)
	local sxPad = bgpadding * (sx < Spring.FlowUI.vsx and 1 or 0) * (ptr or 1)
	local syPad = bgpadding * (sy < Spring.FlowUI.vsy and 1 or 0) * (ptl or 1)

	-- background
	gl.Texture(false)
	Spring.FlowUI.Draw.RectRound(px, py, sx, sy, bgpadding * 1.6, tl, tr, br, bl, { color1[1], color1[2], color1[3], color1[4] }, { color2[1], color2[2], color2[3], color2[4] })
	--Spring.FlowUI.Draw.RectRound(px + pxPad, py + pyPad, sx - sxPad, sy - syPad, bgpadding, tl, tr, br, bl, { color2[1]*0.33, color2[2]*0.33, color2[3]*0.33, color2[4] }, { color2[1], color2[2], color2[3], color2[4] })

	-- highlight edges thinly
	-- top
	Spring.FlowUI.Draw.RectRound(px + pxPad, sy - syPad - (bgpadding*2.5), sx - sxPad, sy - syPad, bgpadding, tl, tr, 0, 0, { 1, 1, 1, 0 }, { 1, 1, 1, 0.04 * glossMult })
	-- bottom
	Spring.FlowUI.Draw.RectRound(px + pxPad, py + pyPad, sx - sxPad, py + pyPad + (bgpadding*2), bgpadding, 0, 0, br, bl, { 1, 1, 1, 0.02 * glossMult }, { 1 ,1 ,1 , 0 })

	-- gloss
	gl.Blending(GL.SRC_ALPHA, GL.ONE)
	local glossHeight = math.floor((sy-py)*0.5)
	Spring.FlowUI.Draw.RectRound(px + pxPad, sy - syPad - math.floor((sy-py)*0.5), sx - sxPad, sy - syPad, bgpadding, tl, tr, 0, 0, { 1, 1, 1, 0.03 }, { 1, 1, 1, 0.1 * glossMult })
	Spring.FlowUI.Draw.RectRound(px + pxPad, py + pyPad, sx - sxPad, py + pyPad + glossHeight, bgpadding, 0, 0, br, bl, { 1, 1, 1, 0.03 * glossMult }, { 1 ,1 ,1 , 0 })
	Spring.FlowUI.Draw.RectRound(px + pxPad, py + pyPad, sx - sxPad, py + pyPad + ((sy-py)*0.2), bgpadding, 0, 0, br, bl, { 1,1,1, 0.02 * glossMult }, { 1,1,1, 0 })
	Spring.FlowUI.Draw.RectRound(px + pxPad, sy- ((sy-py)*0.5), sx - sxPad, sy, bgpadding, tl, tr, 0, 0, { 1,1,1, 0 }, { 1,1,1, 0.07 * glossMult })
	Spring.FlowUI.Draw.RectRound(px + pxPad, py + pyPad, sx - sxPad, py + pyPad + ((sy-py)*0.5), bgpadding, 0, 0, br, bl, { 1,1,1, 0.05 * glossMult }, { 1,1,1, 0 })
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
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
Spring.FlowUI.Draw.Unit = function(px, py, sx, sy,  cs,  tl, tr, br, bl,  zoom,  borderSize, borderOpacity,  texture, radarTexture, groupTexture, price, queueCount)
	local borderSize = borderSize~=nil and borderSize or math.min(math.max(1, math.floor((sx-px) * 0.024)), math.floor((Spring.FlowUI.vsy*0.0015)+0.5))	-- set default with upper limit
	local cs = cs~=nil and cs or math.max(1, math.floor((sx-px) * 0.024))

	local function DrawTexRectRound(px, py, sx, sy,  cs,  tl, tr, br, bl,  offset)
		local csyMult = 1 / ((sy - py) / cs)

		local function drawTexCoordVertex(x, y)
			local yc = 1 - ((y - py) / (sy - py))
			local xc = (offset * 0.5) + ((x - px) / (sx - px)) + (-offset * ((x - px) / (sx - px)))
			yc = 1 - (offset * 0.5) - ((y - py) / (sy - py)) + (offset * ((y - py) / (sy - py)))
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

	-- draw unit
	if texture then
		gl.Texture(texture)
	end
	gl.BeginEnd(GL.QUADS, DrawTexRectRound, px, py, sx, sy,  cs,  tl, tr, br, bl,  zoom)
	if texture then
		gl.Texture(false)
	end

	-- darken gradually
	Spring.FlowUI.Draw.RectRound(px, py, sx, sy, cs, 0, 0, 1, 1, { 0, 0, 0, 0.2 }, { 0, 0, 0, 0 })

	-- make shiny
	gl.Blending(GL.SRC_ALPHA, GL.ONE)
	Spring.FlowUI.Draw.RectRound(px, sy-((sy-py)*0.4), sx, sy, cs, 1,1,0,0,{1,1,1,0}, {1,1,1,0.06})

	-- lighten feather edges
	local borderOpacity = 0.1
	local halfSize = ((sx-px) * 0.5)
	Spring.FlowUI.Draw.RectRoundCircle(
		px + halfSize,
		py + halfSize,
		halfSize, cs*0.7, halfSize*0.82,
		{ 1, 1, 1, 0 }, { 1, 1, 1, 0.04 }
	)

	-- border
	if borderSize > 0 then
		Spring.FlowUI.Draw.RectRoundCircle(
			px + halfSize,
			py + halfSize,
			halfSize, cs*0.7, halfSize - borderSize,
			{ 1, 1, 1, borderOpacity }, { 1, 1, 1, borderOpacity }
		)
	end
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)

	if groupTexture then
		local iconSize = math.floor((sx - px) * 0.3)
		gl.Color(1, 1, 1, 0.9)
		gl.Texture(groupTexture)
		gl.TexRect(px, sy - iconSize, px + iconSize, sy)
		gl.Texture(false)
	end
	if radarTexture then
		local iconSize = math.floor((sx - px) * 0.25)
		local iconPadding = math.floor((sx - px) * 0.03)
		gl.Color(1, 1, 1, 0.9)
		gl.Texture(radarTexture)
		gl.TexRect(sx - iconPadding - iconSize, py + iconPadding, sx - iconPadding, py + iconPadding + iconSize)
		gl.Texture(false)
	end
	if price then
		local priceSize = math.floor((sx - px) * 0.15)
		local iconPadding = math.floor((sx - px) * 0.03)
		--font2:Print("\255\245\245\245" .. price[1] .. "\n\255\255\255\000" .. price[2], px + iconPadding, py + iconPadding + (priceSize * 1.35), priceSize, "o")
	end
	if queueCount then
		local pad = math.floor(halfSize * 0.06)
		--local textWidth = math.floor(font2:GetTextWidth(cmds[cellRectID].params[1] .. '  ') * halfSize * 0.57)
		--local pad2 = 0
		--Spring.FlowUI.Draw.RectRound(cellRects[cellRectID][3] - cellPadding - iconPadding - textWidth - pad2, cellRects[cellRectID][4] - cellPadding - iconPadding - (cellInnerSize * 0.365) - pad2, cellRects[cellRectID][3] - cellPadding - iconPadding, cellRects[cellRectID][4] - cellPadding - iconPadding, cs * 3.3, 0, 0, 0, 1, { 0.15, 0.15, 0.15, 0.95 }, { 0.25, 0.25, 0.25, 0.95 })
		--Spring.FlowUI.Draw.RectRound(cellRects[cellRectID][3] - cellPadding - iconPadding - textWidth - pad2, cellRects[cellRectID][4] - cellPadding - iconPadding - (cellInnerSize * 0.15) - pad2, cellRects[cellRectID][3] - cellPadding - iconPadding, cellRects[cellRectID][4] - cellPadding - iconPadding, 0, 0, 0, 0, 0, { 1, 1, 1, 0 }, { 1, 1, 1, 0.05 })
		--Spring.FlowUI.Draw.RectRound(cellRects[cellRectID][3] - cellPadding - iconPadding - textWidth - pad2 + pad, cellRects[cellRectID][4] - cellPadding - iconPadding - (cellInnerSize * 0.365) - pad2 + pad, cellRects[cellRectID][3] - cellPadding - iconPadding - pad2, cellRects[cellRectID][4] - cellPadding - iconPadding - pad2, cs * 2.6, 0, 0, 0, 1, { 0.7, 0.7, 0.7, 0.1 }, { 1, 1, 1, 0.1 })
		--font2:Print("\255\190\255\190" .. cmds[cellRectID].params[1],
		--	cellRects[cellRectID][1] + cellPadding + (halfSize * 1.88) - pad2,
		--	cellRects[cellRectID][2] + cellPadding + (halfSize * 1.43) - pad2,
		--	(sx - px) * 0.29, "ro"
		--)
	end
end

--[[
	Scroller
		draw a slider
	params
		px, py, sx, sy = left, bottom, right, top
		contentHeight = height
	optional
		position = (default: 0)
]]
Spring.FlowUI.Draw.Scroller = function(px, py, sx, sy, contentHeight, position)

end

--[[
	Toggle
		draw a toggle
	params
		px, py, sx, sy = left, bottom, right, top
	optional
		state = (default: 0) 0 / 0.5 / 1
]]
Spring.FlowUI.Draw.Toggle = function(px, py, sx, sy, state)
	local cs = (sy-py)*0.1
	local edgeWidth = math.max(1, math.floor((sy-py) * 0.1))

	-- faint dark outline edge
	Spring.FlowUI.Draw.RectRound(px-edgeWidth, py-edgeWidth, sx+edgeWidth, sy+edgeWidth, cs*1.5, 1,1,1,1, { 0,0,0,0.05 })
	-- top
	Spring.FlowUI.Draw.RectRound(px, py, sx, sy, cs, 1,1,1,1, { 0.5, 0.5, 0.5, 0.12 }, { 1, 1, 1, 0.12 })

	-- highlight
	gl.Blending(GL.SRC_ALPHA, GL.ONE)
	-- top
	Spring.FlowUI.Draw.RectRound(px, sy-(edgeWidth*3), sx, sy, edgeWidth, 1,1,1,1, { 1,1,1,0 }, { 1,1,1,0.035 })
	-- bottom
	Spring.FlowUI.Draw.RectRound(px, py, sx, py+(edgeWidth*3), edgeWidth, 1,1,1,1, { 1,1,1,0.025 }, { 1,1,1,0  })
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)

	-- draw state
	local padding = math.floor((sy-py)*0.2)
	local radius = math.floor((sy-py)/2) - padding
	local y = math.floor(py + ((sy-py)/2))
	local x, color, glowMult
	if state == true or state == 1 then		-- on
		x = sx - padding - radius
		color = {0.8,1,0.8,1}
		glowMult = 1
	elseif not state or state == 0 then		-- off
		x = px + padding + radius
		color = {0.95,0.66,0.66,1}
		glowMult = 0.3
	else		-- in between
		x = math.floor(px + ((sx-px)*0.42))
		color = {1,0.9,0.7,1}
		glowMult = 0.6
	end
	Spring.FlowUI.Draw.SliderKnob(x, y, radius, color)

	if glowMult > 0 then
		local boolGlow = radius * 1.75
		gl.Blending(GL.SRC_ALPHA, GL.ONE)
		gl.Color(color[1], color[2], color[3], 0.33 * glowMult)
		gl.Texture(":l:LuaUI/Images/glow.dds")
		gl.TexRect(x-boolGlow, y-boolGlow, x+boolGlow, y+boolGlow)
		boolGlow = boolGlow * 2.2
		gl.Color(0.55, 1, 0.55, 0.1 * glowMult)
		gl.TexRect(x-boolGlow, y-boolGlow, x+boolGlow, y+boolGlow)
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
Spring.FlowUI.Draw.SliderKnob = function(x, y, radius, color)
	local color = color or {0.95,0.95,0.95,1}
	local color1 = {color[1]*0.55, color[2]*0.55, color[3]*0.55, color[4]}
	local edgeWidth = math.max(1, math.floor(radius * 0.05))
	local cs = math.max(1.1, radius*0.15)

	-- faint dark outline edge
	Spring.FlowUI.Draw.RectRound(x-radius-edgeWidth, y-radius-edgeWidth, x+radius+edgeWidth, y+radius+edgeWidth, cs, 1,1,1,1, {0,0,0,0.1})
	-- knob
	Spring.FlowUI.Draw.RectRound(x-radius, y-radius, x+radius, y+radius, cs, 1,1,1,1, color1, color)
	-- lighten knob inside edges
	Spring.FlowUI.Draw.RectRoundCircle(x, y, radius, cs*0.5, radius*0.85, {1,1,1,0.1})
end

--[[
	Slider
		draw a slider
	params
		px, py, sx, sy = left, bottom, right, top
		steps = either a table of values or a number of smallest step size
		min, max = when steps is number: min/max scope of steps
]]
Spring.FlowUI.Draw.Slider = function(px, py, sx, sy, steps, min, max)
	local cs = (sy-py)*0.25
	local edgeWidth = math.max(1, math.floor((sy-py) * 0.1))
	-- faint dark outline edge
	Spring.FlowUI.Draw.RectRound(px-edgeWidth, py-edgeWidth, sx+edgeWidth, sy+edgeWidth, cs*1.5, 1,1,1,1, { 0,0,0,0.05 })
	-- top
	Spring.FlowUI.Draw.RectRound(px, py, sx, sy, cs, 1,1,1,1, { 0.1, 0.1, 0.1, 0.22 }, { 0.9,0.9,0.9, 0.22 })
	-- bottom
	Spring.FlowUI.Draw.RectRound(px, py, sx, sy, cs, 1,1,1,1, { 1, 1, 1, 0.1 }, { 1, 1, 1, 0 })

	-- steps
	if steps then
		local numSteps = 0
		local sliderWidth = sx-px
		local processedSteps = {}
		if type(steps) == 'table' then
			min = steps[1]
			max = steps[#steps]
			numSteps = #steps
			for _,value in pairs(steps) do
				processedSteps[#processedSteps+1] = math.floor((px + (sliderWidth*((value-min)/(max-min)))) + 0.5)
			end
			-- remove first step at the bar start
			processedSteps[1] = nil
		elseif min and max then
			numSteps = (max-min)/steps
			for i=1, numSteps do
				processedSteps[#processedSteps+1] = math.floor((px + (sliderWidth/numSteps) * (#processedSteps+1)) + 0.5)
				i = i + 1
			end
		end
		-- remove last step at the bar end
		processedSteps[#processedSteps] = nil

		-- dont bother when steps too small
		if numSteps and numSteps < (sliderWidth/7) then
			local stepSizeLeft = math.max(1, math.floor(sliderWidth*0.01))
			local stepSizeRight = math.floor(sliderWidth*0.005)
			for _,posX in pairs(processedSteps) do
				Spring.FlowUI.Draw.RectRound(posX-stepSizeLeft, py+1, posX+stepSizeRight, sy-1, stepSizeLeft, 1,1,1,1, { 0.12,0.12,0.12,0.22 }, { 0,0,0,0.22 })
			end
		end
	end

	-- add highlight
	gl.Blending(GL.SRC_ALPHA, GL.ONE)
	-- top
	Spring.FlowUI.Draw.RectRound(px, sy-edgeWidth-edgeWidth, sx, sy, edgeWidth, 1,1,1,1, { 1,1,1,0 }, { 1,1,1,0.06 })
	-- bottom
	Spring.FlowUI.Draw.RectRound(px, py, sx, py+edgeWidth+edgeWidth, edgeWidth, 1,1,1,1, { 1,1,1,0 }, { 1,1,1,0.04 })
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
end

--[[
	Selector
		draw a selector (drop-down menu)
	params
		px, py, sx, sy = left, bottom, right, top
]]
Spring.FlowUI.Draw.Selector = function(px, py, sx, sy)
	local cs = (sy-py)*0.1
	local edgeWidth = math.max(1, math.floor((sy-py) * 0.1))

	-- faint dark outline edge
	Spring.FlowUI.Draw.RectRound(px-edgeWidth, py-edgeWidth, sx+edgeWidth, sy+edgeWidth, cs*1.5, 1,1,1,1, { 0,0,0,0.05 })
	-- body
	Spring.FlowUI.Draw.RectRound(px, py, sx, sy, cs, 1,1,1,1, { 0.5, 0.5, 0.5, 0.12 }, { 1, 1, 1, 0.12 })

	-- highlight
	gl.Blending(GL.SRC_ALPHA, GL.ONE)
	-- top
	Spring.FlowUI.Draw.RectRound(px, sy-(edgeWidth*3), sx, sy, edgeWidth, 1,1,1,1, { 1,1,1,0 }, { 1,1,1,0.035 })
	-- bottom
	Spring.FlowUI.Draw.RectRound(px, py, sx, py+(edgeWidth*3), edgeWidth, 1,1,1,1, { 1,1,1,0.025 }, { 1,1,1,0  })
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)

	-- button
	Spring.FlowUI.Draw.RectRound(sx-(sy-py), py, sx, sy, cs, 1, 1, 1, 1, { 1, 1, 1, 0.06 }, { 1, 1, 1, 0.14 })
	--Spring.FlowUI.Draw.Button(sx-(sy-py), py, sx, sy, 1, 1, 1, 1, 1,1,1,1, nil, { 1, 1, 1, 0.1 }, nil, cs)
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
Spring.FlowUI.Draw.SelectHighlight = function(px, py, sx, sy,  cs, opacity, color)
	local cs = cs or (sy-py)*0.08
	local edgeWidth = math.max(1, math.floor((Spring.FlowUI.vsy*0.001)))
	local opacity = opacity or 0.35
	local color = color or {1,1,1}

	-- faint dark outline edge
	Spring.FlowUI.Draw.RectRound(px-edgeWidth, py-edgeWidth, sx+edgeWidth, sy+edgeWidth, cs*1.5, 1,1,1,1, { 0,0,0,0.05 })
	-- body
	Spring.FlowUI.Draw.RectRound(px, py, sx, sy, cs, 1,1,1,1, { color[1]*0.5, color[2]*0.5, color[3]*0.5, opacity }, { color[1], color[2], color[3], opacity })

	-- highlight
	gl.Blending(GL.SRC_ALPHA, GL.ONE)
	-- top
	Spring.FlowUI.Draw.RectRound(px, sy-(edgeWidth*3), sx, sy, edgeWidth, 1,1,1,1, { 1,1,1,0 }, { 1,1,1,0.03 + (0.18*opacity) })
	-- bottom
	Spring.FlowUI.Draw.RectRound(px, py, sx, py+(edgeWidth*3), edgeWidth, 1,1,1,1, { 1,1,1,0.015 + (0.06*opacity) }, { 1,1,1,0  })
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
end


-- Execute initialize
if not Spring.FlowUI.initialized then
	Spring.FlowUI.Initialize()
end
