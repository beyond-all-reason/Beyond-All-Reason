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


-- Localized functions for performance
local mathFloor = math.floor
local mathMax = math.max
local mathMin = math.min
local mathPi = math.pi

-- Localized Spring API for performance
local spGetViewGeometry = Spring.GetViewGeometry

WG.FlowUI = WG.FlowUI or {}
WG.FlowUI.version = 1
WG.FlowUI.initialized = false

WG.FlowUI.opacity = Spring.GetConfigFloat("ui_opacity", 0.7)
WG.FlowUI.clampedOpacity = mathMax(0.75, WG.FlowUI.opacity)
WG.FlowUI.scale = Spring.GetConfigFloat("ui_scale", 1)
WG.FlowUI.tileOpacity = Spring.GetConfigFloat("ui_tileopacity", 0.014)
WG.FlowUI.tileScale = Spring.GetConfigFloat("ui_tilescale", 7)
WG.FlowUI.tileSize = WG.FlowUI.tileScale

-- Guishader display list lifecycle helpers
WG.FlowUI.guishaderCheckDlist = function(currentDlist, name, drawFn, force)
	if WG['guishader'] then
		if force and currentDlist then
			currentDlist = gl.DeleteList(currentDlist)
		end
		if not currentDlist then
			currentDlist = gl.CreateList(drawFn)
			WG['guishader'].InsertDlist(currentDlist, name)
		end
		return currentDlist
	elseif currentDlist then
		return gl.DeleteList(currentDlist)
	end
	return nil
end

WG.FlowUI.guishaderRemoveDlist = function(currentDlist, name)
	if WG['guishader'] then
		WG['guishader'].RemoveDlist(name)
	end
	if currentDlist then
		gl.DeleteList(currentDlist)
	end
	return nil
end

WG.FlowUI.guishaderDeleteDlist = function(name)
	if WG['guishader'] then
		WG['guishader'].DeleteDlist(name)
	end
end

local function ViewResize(vsx, vsy)
	if not vsy then
		vsx, vsy = spGetViewGeometry()
	end
	if WG.FlowUI.vsx and (WG.FlowUI.vsx == vsx and WG.FlowUI.vsy == vsy) then
		return
	end
	WG.FlowUI.vsx = vsx
	WG.FlowUI.vsy = vsy
	-- elementMargin: number of px between each separated ui element
	WG.FlowUI.elementMargin = mathFloor(0.0045 * vsy * WG.FlowUI.scale)
	-- elementCorner: element cutoff corner size
	WG.FlowUI.elementCorner = WG.FlowUI.elementMargin * 0.9
	-- elementPadding: element inner (background) border/outline size
	WG.FlowUI.elementPadding = mathFloor(0.003 * vsy * WG.FlowUI.scale)
	-- buttonPadding: button inner (background) border/outline size
	WG.FlowUI.buttonPadding = mathFloor(0.002 * vsy * WG.FlowUI.scale)

	WG.FlowUI.tileSize = WG.FlowUI.tileScale * 0.003 * vsy * WG.FlowUI.scale
end

-- called at the bottom of this file
local function Initialize()
	ViewResize(spGetViewGeometry())
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
		cs = mathMax(cs, 1)

		-- Pre-calculate gradient colors if needed (avoids redundant calculations)
		local hasGradient = c2 ~= nil
		local edgeColor, midColor
		if hasGradient then
			local csyMult = 1 / mathMax(((sy - py) / cs), 1)
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
	RectRoundQuad
		draw a (possibly trapezoidal/skewed) quadrilateral with chamfered corners
		generalization of RectRound supporting per-corner x/y offsets
	params
		px, py, sx, sy = left, bottom, right, top (base rectangle)
		cs = corner chamfer size
		tl, tr, br, bl = enable corner chamfer (1 = chamfered, 0 = square)
		c1, c2 = bottom color, top color (gradient)
		skew = table of per-corner pixel offsets from base rectangle corners:
		       {tlx, tly, trx, try, brx, bry, blx, bly} (all default to 0)
		       positive x = shift right, positive y = shift up
		       example: skew = {tlx = -20}  makes top-left 20 px wider to the left
]]
WG.FlowUI.Draw.RectRoundQuad = function(px, py, sx, sy,  cs,  tl, tr, br, bl,  c1, c2,  skew)
	local function DrawRectRoundQuad(px, py, sx, sy, cs, tl, tr, br, bl, c1, c2, skew)
		cs = mathMax(cs, 1)

		-- Per-corner offsets from base rectangle corners (default 0)
		local tlx = skew.tlx or 0;  local tly = skew.tly or 0
		local trx = skew.trx or 0;  local try = skew.try or 0
		local brx = skew.brx or 0;  local bry = skew.bry or 0
		local blx = skew.blx or 0;  local bly = skew.bly or 0

		-- Actual 4 corner positions
		local BLx, BLy = px + blx, py + bly
		local BRx, BRy = sx + brx, py + bry
		local TRx, TRy = sx + trx, sy + try
		local TLx, TLy = px + tlx, sy + tly

		-- Normalize 2D vector
		local function n2(x, y)
			local len = math.sqrt(x*x + y*y)
			if len < 0.001 then return 0, 1 end
			return x/len, y/len
		end

		-- Edge unit directions, CCW: BL -> BR -> TR -> TL -> BL
		local bdx, bdy = n2(BRx-BLx, BRy-BLy)  -- bottom (BL->BR)
		local rdx, rdy = n2(TRx-BRx, TRy-BRy)  -- right  (BR->TR)
		local tdx, tdy = n2(TLx-TRx, TLy-TRy)  -- top    (TR->TL)
		local ldx, ldy = n2(BLx-TLx, BLy-TLy)  -- left   (TL->BL)

		-- 8 chamfer cut points at distance cs from each corner along both adjacent edges
		-- BL: along bottom edge and towards TL (= -(TL->BL) direction)
		local blb_x, blb_y = BLx + cs*bdx,  BLy + cs*bdy
		local bll_x, bll_y = BLx - cs*ldx,  BLy - cs*ldy
		-- BR: back along bottom and along right edge
		local brb_x, brb_y = BRx - cs*bdx,  BRy - cs*bdy
		local brr_x, brr_y = BRx + cs*rdx,  BRy + cs*rdy
		-- TR: back along right and along top edge
		local trr_x, trr_y = TRx - cs*rdx,  TRy - cs*rdy
		local trt_x, trt_y = TRx + cs*tdx,  TRy + cs*tdy
		-- TL: back along top and towards BL along left edge
		local tlt_x, tlt_y = TLx - cs*tdx,  TLy - cs*tdy
		local tll_x, tll_y = TLx + cs*ldx,  TLy + cs*ldy

		-- 4 inner corners: cs inward from each actual corner along both adjacent edges
		local iblx = BLx + cs*(bdx - ldx);  local ibly = BLy + cs*(bdy - ldy)
		local ibrx = BRx + cs*(-bdx + rdx); local ibry = BRy + cs*(-bdy + rdy)
		local itrx = TRx + cs*(-rdx + tdx); local itry = TRy + cs*(-rdy + tdy)
		local itlx = TLx + cs*(-tdx + ldx); local itly = TLy + cs*(-tdy + ldy)

		-- Per-vertex color: linear gradient from c1 (bottom) to c2 (top)
		local hasGradient = c1 ~= nil and c2 ~= nil
		local spanY = mathMax(TLy - BLy, 1)
		local function setColorY(y)
			if not c1 then return end
			if hasGradient then
				local t = mathMax(0, mathMin(1, (y - BLy) / spanY))
				gl.Color(c1[1]+(c2[1]-c1[1])*t, c1[2]+(c2[2]-c1[2])*t,
				         c1[3]+(c2[3]-c1[3])*t, c1[4]+(c2[4]-c1[4])*t)
			else
				gl.Color(c1[1], c1[2], c1[3], c1[4])
			end
		end

		-- 9-quad tessellation covering the full shape without gaps or overlaps
		-- 1. Center (inner quadrilateral)
		setColorY(ibly);  gl.Vertex(iblx, ibly, 0)
		setColorY(ibry);  gl.Vertex(ibrx, ibry, 0)
		setColorY(itry);  gl.Vertex(itrx, itry, 0)
		setColorY(itly);  gl.Vertex(itlx, itly, 0)

		-- 2. Bottom strip
		setColorY(blb_y); gl.Vertex(blb_x, blb_y, 0)
		setColorY(brb_y); gl.Vertex(brb_x, brb_y, 0)
		setColorY(ibry);  gl.Vertex(ibrx, ibry, 0)
		setColorY(ibly);  gl.Vertex(iblx, ibly, 0)

		-- 3. Left strip
		setColorY(bll_y); gl.Vertex(bll_x, bll_y, 0)
		setColorY(ibly);  gl.Vertex(iblx, ibly, 0)
		setColorY(itly);  gl.Vertex(itlx, itly, 0)
		setColorY(tll_y); gl.Vertex(tll_x, tll_y, 0)

		-- 4. Right strip
		setColorY(ibry);  gl.Vertex(ibrx, ibry, 0)
		setColorY(brr_y); gl.Vertex(brr_x, brr_y, 0)
		setColorY(trr_y); gl.Vertex(trr_x, trr_y, 0)
		setColorY(itry);  gl.Vertex(itrx, itry, 0)

		-- 5. Top strip
		setColorY(itly);  gl.Vertex(itlx, itly, 0)
		setColorY(itry);  gl.Vertex(itrx, itry, 0)
		setColorY(trt_y); gl.Vertex(trt_x, trt_y, 0)
		setColorY(tlt_y); gl.Vertex(tlt_x, tlt_y, 0)

		-- 6. BL corner (square when bl=0, degenerate triangle when bl=1)
		setColorY(BLy)
		if bl ~= nil and bl == 0 then
			gl.Vertex(BLx, BLy, 0)
		else
			gl.Vertex(blb_x, blb_y, 0)
		end
		gl.Vertex(blb_x, blb_y, 0)
		setColorY(ibly);  gl.Vertex(iblx, ibly, 0)
		setColorY(bll_y); gl.Vertex(bll_x, bll_y, 0)

		-- 7. BR corner
		setColorY(brb_y); gl.Vertex(brb_x, brb_y, 0)
		setColorY(BRy)
		if br ~= nil and br == 0 then
			gl.Vertex(BRx, BRy, 0)
		else
			gl.Vertex(brb_x, brb_y, 0)
		end
		setColorY(brr_y); gl.Vertex(brr_x, brr_y, 0)
		setColorY(ibry);  gl.Vertex(ibrx, ibry, 0)

		-- 8. TL corner
		setColorY(tll_y); gl.Vertex(tll_x, tll_y, 0)
		setColorY(itly);  gl.Vertex(itlx, itly, 0)
		setColorY(tlt_y); gl.Vertex(tlt_x, tlt_y, 0)
		setColorY(TLy)
		if tl ~= nil and tl == 0 then
			gl.Vertex(TLx, TLy, 0)
		else
			gl.Vertex(tlt_x, tlt_y, 0)
		end

		-- 9. TR corner
		setColorY(itry);  gl.Vertex(itrx, itry, 0)
		setColorY(trr_y); gl.Vertex(trr_x, trr_y, 0)
		setColorY(TRy)
		if tr ~= nil and tr == 0 then
			gl.Vertex(TRx, TRy, 0)
		else
			gl.Vertex(trt_x, trt_y, 0)
		end
		setColorY(trt_y); gl.Vertex(trt_x, trt_y, 0)
	end
	gl.BeginEnd(GL.QUADS, DrawRectRoundQuad, px, py, sx, sy, cs, tl, tr, br, bl, c1, c2, skew)
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
	local beta_rad = mathPi / 2 - alpha_rad

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
		if width <= 0 or height <= 0 then return end
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
	TexturedRectRoundQuad
		same as TexturedRectRound but supports a skew table for trapezoidal shapes
	params
		px, py, sx, sy = left, bottom, right, top
	optional
		tl, tr, br, bl = enable/disable corners
		size, offset, offsetY = texture tiling params
		texture = file location
		skew = table with optional tlx, tly, trx, try, brx, bry, blx, bly corner offsets
]]
WG.FlowUI.Draw.TexturedRectRoundQuad = function(px, py, sx, sy,  cs,  tl, tr, br, bl,  size, offset, offsetY,  texture, skew)
	local function DrawTexturedRectRoundQuad(px, py, sx, sy, cs, tl, tr, br, bl, size, offset, offsetY, skew)
		cs = mathMax(cs, 1)

		-- UV parameters (based on original bounding box)
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

		-- Per-corner skew offsets
		local tlx = skew.tlx or 0;  local tly = skew.tly or 0
		local trx = skew.trx or 0;  local try = skew.try or 0
		local brx = skew.brx or 0;  local bry = skew.bry or 0
		local blx = skew.blx or 0;  local bly = skew.bly or 0

		-- Actual 4 corner positions
		local BLx, BLy = px + blx, py + bly
		local BRx, BRy = sx + brx, py + bry
		local TRx, TRy = sx + trx, sy + try
		local TLx, TLy = px + tlx, sy + tly

		-- Normalize 2D vector
		local function n2(x, y)
			local len = math.sqrt(x*x + y*y)
			if len < 0.001 then return 0, 1 end
			return x/len, y/len
		end

		-- Edge unit directions CCW: BL->BR->TR->TL->BL
		local bdx, bdy = n2(BRx-BLx, BRy-BLy)  -- bottom
		local rdx, rdy = n2(TRx-BRx, TRy-BRy)  -- right
		local tdx, tdy = n2(TLx-TRx, TLy-TRy)  -- top
		local ldx, ldy = n2(BLx-TLx, BLy-TLy)  -- left

		-- Chamfer cut points at cs from each corner along adjacent edges
		local blb_x, blb_y = BLx + cs*bdx, BLy + cs*bdy
		local bll_x, bll_y = BLx - cs*ldx, BLy - cs*ldy
		local brb_x, brb_y = BRx - cs*bdx, BRy - cs*bdy
		local brr_x, brr_y = BRx + cs*rdx, BRy + cs*rdy
		local trr_x, trr_y = TRx - cs*rdx, TRy - cs*rdy
		local trt_x, trt_y = TRx + cs*tdx, TRy + cs*tdy
		local tlt_x, tlt_y = TLx - cs*tdx, TLy - cs*tdy
		local tll_x, tll_y = TLx + cs*ldx, TLy + cs*ldy

		-- Inner corners: cs inward from each actual corner along both adjacent edges
		local iblx = BLx + cs*(bdx - ldx);  local ibly = BLy + cs*(bdy - ldy)
		local ibrx = BRx + cs*(-bdx + rdx); local ibry = BRy + cs*(-bdy + rdy)
		local itrx = TRx + cs*(-rdx + tdx); local itry = TRy + cs*(-rdy + tdy)
		local itlx = TLx + cs*(-tdx + ldx); local itly = TLy + cs*(-tdy + ldy)

		-- 9-quad tessellation
		-- 1. Center
		drawTexCoordVertex(iblx, ibly)
		drawTexCoordVertex(ibrx, ibry)
		drawTexCoordVertex(itrx, itry)
		drawTexCoordVertex(itlx, itly)

		-- 2. Bottom strip
		drawTexCoordVertex(blb_x, blb_y)
		drawTexCoordVertex(brb_x, brb_y)
		drawTexCoordVertex(ibrx, ibry)
		drawTexCoordVertex(iblx, ibly)

		-- 3. Left strip
		drawTexCoordVertex(bll_x, bll_y)
		drawTexCoordVertex(iblx, ibly)
		drawTexCoordVertex(itlx, itly)
		drawTexCoordVertex(tll_x, tll_y)

		-- 4. Right strip
		drawTexCoordVertex(ibrx, ibry)
		drawTexCoordVertex(brr_x, brr_y)
		drawTexCoordVertex(trr_x, trr_y)
		drawTexCoordVertex(itrx, itry)

		-- 5. Top strip
		drawTexCoordVertex(itlx, itly)
		drawTexCoordVertex(itrx, itry)
		drawTexCoordVertex(trt_x, trt_y)
		drawTexCoordVertex(tlt_x, tlt_y)

		-- 6. BL corner
		if bl ~= nil and bl == 0 then
			drawTexCoordVertex(BLx, BLy)
		else
			drawTexCoordVertex(blb_x, blb_y)
		end
		drawTexCoordVertex(blb_x, blb_y)
		drawTexCoordVertex(iblx, ibly)
		drawTexCoordVertex(bll_x, bll_y)

		-- 7. BR corner
		drawTexCoordVertex(brb_x, brb_y)
		if br ~= nil and br == 0 then
			drawTexCoordVertex(BRx, BRy)
		else
			drawTexCoordVertex(brb_x, brb_y)
		end
		drawTexCoordVertex(brr_x, brr_y)
		drawTexCoordVertex(ibrx, ibry)

		-- 8. TL corner
		drawTexCoordVertex(tll_x, tll_y)
		drawTexCoordVertex(itlx, itly)
		drawTexCoordVertex(tlt_x, tlt_y)
		if tl ~= nil and tl == 0 then
			drawTexCoordVertex(TLx, TLy)
		else
			drawTexCoordVertex(tlt_x, tlt_y)
		end

		-- 9. TR corner
		drawTexCoordVertex(itrx, itry)
		drawTexCoordVertex(trr_x, trr_y)
		if tr ~= nil and tr == 0 then
			drawTexCoordVertex(TRx, TRy)
		else
			drawTexCoordVertex(trt_x, trt_y)
		end
		drawTexCoordVertex(trt_x, trt_y)
	end
	if texture then
		gl.Texture(texture)
	end
	gl.BeginEnd(GL.QUADS, DrawTexturedRectRoundQuad, px, py, sx, sy, cs, tl, tr, br, bl, size, offset, offsetY, skew)
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
		local sideAngle = (mathPi * 2) / sides

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
		skew = optional table of per-corner pixel offsets {tlx, tly, trx, try, brx, bry, blx, bly}
		       shifts each corner of the element independently from the base rectangle
		       example: skew = {tlx = -20, blx = -20}  slants the entire left side outward by 20px
		                skew = {tlx = -20}  makes only the top-left corner 20px wider
]]
WG.FlowUI.Draw.Element = function(px, py, sx, sy,  tl, tr, br, bl,  ptl, ptr, pbr, pbl,  opacity, color1, color2, bgpadding, opaque,  skew)
	local opacity = mathMin(1, opacity or WG.FlowUI.opacity)
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

	local glossHeight = mathFloor(0.02 * WG.FlowUI.vsy * ui_scale)
	local doBottomFx = (sy-py-syPad-syPad) > (glossHeight*2.3)

	-- Use RectRoundQuad (supports trapezoidal skew) when skew is provided, else RectRound.
	-- Each sub-layer follows the outer trapezoid's edge slope by computing corner offsets
	-- from the sub-layer's absolute y-position within the outer element:
	--   tlx = (sy - lsy) * slopeL   (horizontal shift at sub-layer top)
	--   blx = (sy - lpy) * slopeL   (horizontal shift at sub-layer bottom)
	-- This keeps every sub-layer's sides parallel to and inset from the outer trapezoid.
	local drawR, paddingSkew
	if skew then
		local H = sy - py
		local slopeL = ((skew.blx or 0) - (skew.tlx or 0)) / H
		local slopeR = ((skew.brx or 0) - (skew.trx or 0)) / H
		-- Pre-compute skew for the padded inner sub-rect used by layers 9-11:
		--   inner rect top y = sy - syPad  →  tlx = syPad * slopeL
		--   inner rect bottom y = py + pyPad  →  blx = (H - pyPad) * slopeL
		paddingSkew = {
			tlx = syPad * slopeL,         blx = (H - pyPad) * slopeL,
			trx = syPad * slopeR,         brx = (H - pyPad) * slopeR,
		}
		drawR = function(lpx, lpy, lsx, lsy, cSize, ctL, ctR, cbR, cbL, col1, col2)
			WG.FlowUI.Draw.RectRoundQuad(lpx, lpy, lsx, lsy, cSize, ctL, ctR, cbR, cbL, col1, col2, {
				tlx = (sy - lsy) * slopeL,   blx = (sy - lpy) * slopeL,
				trx = (sy - lsy) * slopeR,   brx = (sy - lpy) * slopeR,
			})
		end
	else
		drawR = WG.FlowUI.Draw.RectRound
	end

	gl.Texture(false)

	-- Layer 1: Outer border (background)
	drawR(px, py, sx, sy, cs, tl, tr, br, bl,
		{ color1[1], color1[2], color1[3], opaque and 1 or color1[4] },
		{ color1[1], color1[2], color1[3], opaque and 1 or color1[4] })

	-- Layer 2: Main element with gradient (replaces the old "element" layer)
	cs = cs * 0.6
	local elemAlpha = opaque and opacity or color2[4] * 1.25
	drawR(px + pxPad, py + pyPad, sx - sxPad, sy - syPad, cs, tl, tr, br, bl,
		{ color2[1]*0.33, color2[2]*0.33, color2[3]*0.33, elemAlpha },
		{ color2[1], color2[2], color2[3], elemAlpha })

	-- Layer 3: Single combined inner layer (merges the two overlapping "inner darkening" layers)
	-- This creates the subtle inner border effect more efficiently
	local innerPad = 1.5  -- averaged from the old pad2 values
	local innerAlpha = opaque and 1 or color1[4] * 0.13
	local innerBrightness = opaque and 0.10 or 0
	drawR(px + pxPad + innerPad, py + pyPad + innerPad, sx - sxPad - innerPad, sy - syPad - innerPad,
		cs*0.5, tl, tr, br, bl,
		{ color1[1]+(innerBrightness*0.7), color1[2]+(innerBrightness*0.7), color1[3]+(innerBrightness*0.7), innerAlpha},
		{ color1[1]+innerBrightness, color1[2]+innerBrightness, color1[3]+innerBrightness, innerAlpha })

	-- Layer 4: Bottom darkening gradient (only if element is tall enough)
	if doBottomFx then
		local c = opaque and 0.06 or 0
		local c2 = opaque and 0.12 or 0
		drawR(px + pxPad + 2, py + 2, sx - sxPad - 2, py + ((sy-py)*0.75), cs*1.66, 0, 0, br, bl,
			{ c, c, c, opaque and 1 or 0.05 * glossMult },
			{ c2, c2, c2, opaque and 1 or 0 })
	end

	-- Layer 5: Top gloss highlight
	local glossTopAlpha = opaque and 1 or 0.07 * glossMult
	local glossTopC = opaque and 0.12 * glossMult or 1
	drawR(px + pxPad + 1, sy - syPad - 1 - glossHeight, sx - sxPad - 1, sy - syPad - 1,
		cs*0.5, tl, tr, 0, 0,
		{ 0.12, 0.12, 0.12, opaque and 1 or 0 },
		{ glossTopC, glossTopC, glossTopC, glossTopAlpha })

	-- Layer 6: Bottom gloss highlight (only if element is tall enough)
	if doBottomFx then
		local glossBotAlpha = opaque and 1 or 0.03 * glossMult
		local glossBotC = opaque and 0.05 * glossMult or 1
		drawR(px + pxPad + 1, py + pyPad + 1, sx - sxPad - 1, py + pyPad + glossHeight,
			cs, 0, 0, br, bl,
			{ glossBotC, glossBotC, glossBotC, glossBotAlpha },
			{ 0.06, 0.06, 0.06, opaque and 1 or 0 })
	end

	-- Layer 7: Top edge highlight (only if there's padding)
	if syPad > 0 then
		local edgeTopAlpha = opaque and 1 or 0.04 * glossMult
		local edgeTopC = opaque and 0.33 or 1
		drawR(px + pxPad + 1, sy - syPad - (cs*2.5), sx - sxPad - 1, sy - syPad - 1,
			cs, tl, tr, 0, 0,
			{ 0.24, 0.24, 0.24, opaque and 1 or 0 },
			{ edgeTopC, edgeTopC, edgeTopC, edgeTopAlpha })
	end

	-- Layer 8: Bottom edge highlight (only if there's padding)
	if pyPad > 0 then
		local edgeBotAlpha = opaque and 1 or 0.02 * glossMult
		local edgeBotC = opaque and 0.15 or 1
		drawR(px + pxPad + 1, py + pyPad + 1, sx - sxPad - 1, py + pyPad + (cs*2),
			cs, 0, 0, br, bl,
			{ edgeBotC, edgeBotC, edgeBotC, edgeBotAlpha },
			{ 0.13, 0.13, 0.13, opaque and 1 or 0 })
	end

	-- Layer 9: Background tile texture
	if tileopacity > 0 then
		gl.Color(1, 1, 1, tileopacity * (opaque and 1.33 or 1))
		if skew then
			WG.FlowUI.Draw.TexturedRectRoundQuad(px + pxPad, py + pyPad, sx - sxPad, sy - syPad, cs, tl, tr, br, bl, bgtexSize, (px+pxPad)/WG.FlowUI.vsx/bgtexSize, (py+pyPad)/WG.FlowUI.vsy/bgtexSize, "luaui/images/backgroundtile.png", paddingSkew)
		else
			WG.FlowUI.Draw.TexturedRectRound(px + pxPad, py + pyPad, sx - sxPad, sy - syPad, cs, tl, tr, br, bl, bgtexSize, (px+pxPad)/WG.FlowUI.vsx/bgtexSize, (py+pyPad)/WG.FlowUI.vsy/bgtexSize, "luaui/images/backgroundtile.png")
		end
	end

	-- Layers 10 & 11: White feathered inner outline
	-- Layer 10: White feathered inner outline
	local outlineWidth10 = 2
	local outlineAlpha10 = opaque and 0.2 or 0.11
	if skew then
		WG.FlowUI.Draw.RectRoundOutlineQuad(
			px + pxPad, py + pyPad, sx - sxPad, sy - syPad,
			cs, outlineWidth10,
			tl, tr, br, bl,
			{ 1, 1, 1, outlineAlpha10 }, { 1, 1, 1, 0 },
			paddingSkew
		)
	else
		WG.FlowUI.Draw.RectRoundOutline(
			px + pxPad, py + pyPad, sx - sxPad, sy - syPad,
			cs, outlineWidth10,
			tl, tr, br, bl,
			{ 1, 1, 1, outlineAlpha10 }, { 1, 1, 1, 0 }
		)
	end

	-- Layer 11: White feathered inner outline glow
	local outlineWidth11 = 16
	local outlineAlpha11 = opaque and 0.08 or 0.04
	if skew then
		WG.FlowUI.Draw.RectRoundOutlineQuad(
			px + pxPad, py + pyPad, sx - sxPad, sy - syPad,
			cs, outlineWidth11,
			tl, tr, br, bl,
			{ 1, 1, 1, outlineAlpha11 }, { 1, 1, 1, 0 },
			paddingSkew
		)
	else
		WG.FlowUI.Draw.RectRoundOutline(
			px + pxPad, py + pyPad, sx - sxPad, sy - syPad,
			cs, outlineWidth11,
			tl, tr, br, bl,
			{ 1, 1, 1, outlineAlpha11 }, { 1, 1, 1, 0 }
		)
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
	local bgpadding = mathFloor(bgpadding or WG.FlowUI.buttonPadding*0.5)
	glossMult = (1 + (2 - (opacity * 1.5))) * (glossMult and glossMult or 1)

	local tl = tl or 1
	local tr = tr or 1
	local br = br or 1
	local bl = bl or 1

	local pxPad = bgpadding * (px > 0 and 1 or 0) * (pbl or 1)
	local pyPad = bgpadding * (py > 0 and 1 or 0) * (pbr or 1)
	local sxPad = bgpadding * (sx < WG.FlowUI.vsx and 1 or 0) * (ptr or 1)
	local syPad = bgpadding * (sy < WG.FlowUI.vsy and 1 or 0) * (ptl or 1)

	local glossHeight = mathFloor((sy-py)*0.4)
	local cs = bgpadding * 1.6

	-- Layer 1: Background with gradient
	WG.FlowUI.Draw.RectRound(px, py, sx, sy, cs, tl, tr, br, bl, color1, color2)

	-- Layer 2: Combined top gloss (merges the old top edge highlight + top half gloss + top extended gloss)
	-- Alpha values tuned to match original brightness from overlapping layers
	local topGlossAlpha = 0.18 * glossMult
	WG.FlowUI.Draw.RectRound(px + pxPad, sy - syPad - glossHeight, sx - sxPad, sy - syPad, bgpadding, tl, tr, 0, 0,
		{ 1, 1, 1, 0 },
		{ 1, 1, 1, topGlossAlpha })

	-- -- Layer 3: Enhanced top edge highlight (thin bright edge at the very top)
	-- WG.FlowUI.Draw.RectRound(px + pxPad, sy - syPad - (bgpadding*2.5), sx - sxPad, sy - syPad, bgpadding, tl, tr, 0, 0,
	-- 	{ 1, 1, 1, 0 },
	-- 	{ 1, 1, 1, 0.08 * glossMult })

	-- Layer 4: Combined bottom gloss (merges the three overlapping bottom gloss layers)
	-- Alpha values tuned to match original brightness from overlapping layers
	local bottomGlossAlpha = 0.075 * glossMult
	WG.FlowUI.Draw.RectRound(px + pxPad, py + pyPad, sx - sxPad, py + pyPad + glossHeight, bgpadding, 0, 0, br, bl,
		{ 1, 1, 1, bottomGlossAlpha },
		{ 1, 1, 1, 0 })

	-- -- Layer 5: Bottom edge highlight (thin edge at the very bottom)
	-- WG.FlowUI.Draw.RectRound(px + pxPad, py + pyPad, sx - sxPad, py + pyPad + (bgpadding*2), bgpadding, 0, 0, br, bl,
	-- 	{ 1, 1, 1, 0.04 * glossMult },
	-- 	{ 1, 1, 1, 0 })

	-- Layer 6: White feathered inner outline glow
	local outlineWidth = 7
	local outlineAlpha = opaque and 0.12 or 0.06
	WG.FlowUI.Draw.RectRoundOutline(
		px + pxPad, py + pyPad, sx - sxPad, sy - syPad,
		cs, outlineWidth,
		tl, tr, br, bl,
		{ 1, 1, 1, outlineAlpha }, { 1, 1, 1, 0 }
	)
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
	RectRoundOutline
		draw a rectangular outline with feathered edges and proper corner cutoffs
	params
		px, py, sx, sy = left, bottom, right, top
		cs = corner size
		outlineWidth = width of the outline/feather
		tl, tr, br, bl = enable/disable corners for TopLeft, TopRight, BottomRight, BottomLeft (default: 1)
		outerColor = color for the outside edge
		innerColor = color for the inside edge (for feathering)
]]
WG.FlowUI.Draw.RectRoundOutline = function(px, py, sx, sy, cs, outlineWidth, tl, tr, br, bl, outerColor, innerColor)
	local function DrawRectRoundOutline(px, py, sx, sy, cs, outlineWidth, tl, tr, br, bl, outerColor, innerColor)
		local tl = tl or 1
		local tr = tr or 1
		local br = br or 1
		local bl = bl or 1

		-- Outer rectangle coordinates
		local ox1, oy1, ox2, oy2 = px, py, sx, sy
		-- Inner rectangle coordinates
		local ix1, iy1, ix2, iy2 = px + outlineWidth, py + outlineWidth, sx - outlineWidth, sy - outlineWidth

		-- Ensure inner rectangle is valid
		if ix1 >= ix2 or iy1 >= iy2 then
			-- If outline is too wide, just draw a solid rectangle
			WG.FlowUI.Draw.RectRound(px, py, sx, sy, cs, tl, tr, br, bl, outerColor)
			return
		end

		local innerCs = mathMax(0, cs - outlineWidth)

		-- Draw the outline by drawing quads between outer and inner rectangles

		-- Mid section (top and bottom strips)
		-- Top strip
		gl.Color(outerColor)
		gl.Vertex(ox1 + cs, oy2, 0)
		gl.Vertex(ox2 - cs, oy2, 0)
		gl.Color(innerColor)
		gl.Vertex(ix2 - innerCs, iy2, 0)
		gl.Vertex(ix1 + innerCs, iy2, 0)

		-- Bottom strip
		gl.Color(innerColor)
		gl.Vertex(ix1 + innerCs, iy1, 0)
		gl.Vertex(ix2 - innerCs, iy1, 0)
		gl.Color(outerColor)
		gl.Vertex(ox2 - cs, oy1, 0)
		gl.Vertex(ox1 + cs, oy1, 0)

		-- Left and right strips
		-- Left strip
		gl.Color(outerColor)
		gl.Vertex(ox1, oy1 + cs, 0)
		gl.Vertex(ox1, oy2 - cs, 0)
		gl.Color(innerColor)
		gl.Vertex(ix1, iy2 - innerCs, 0)
		gl.Vertex(ix1, iy1 + innerCs, 0)

		-- Right strip
		gl.Color(innerColor)
		gl.Vertex(ix2, iy1 + innerCs, 0)
		gl.Vertex(ix2, iy2 - innerCs, 0)
		gl.Color(outerColor)
		gl.Vertex(ox2, oy2 - cs, 0)
		gl.Vertex(ox2, oy1 + cs, 0)

		-- Corner pieces
		-- Bottom left corner
		if bl == 1 then
			gl.Color(outerColor)
			gl.Vertex(ox1 + cs, oy1, 0)
			gl.Vertex(ox1, oy1 + cs, 0)
			gl.Color(innerColor)
			gl.Vertex(ix1, iy1 + innerCs, 0)
			gl.Vertex(ix1 + innerCs, iy1, 0)
		else
			gl.Color(outerColor)
			gl.Vertex(ox1, oy1, 0)
			gl.Vertex(ox1, oy1 + cs, 0)
			gl.Color(innerColor)
			gl.Vertex(ix1, iy1 + innerCs, 0)
			gl.Vertex(ix1, iy1, 0)
		end

		-- Bottom right corner
		if br == 1 then
			gl.Color(innerColor)
			gl.Vertex(ix2 - innerCs, iy1, 0)
			gl.Vertex(ix2, iy1 + innerCs, 0)
			gl.Color(outerColor)
			gl.Vertex(ox2, oy1 + cs, 0)
			gl.Vertex(ox2 - cs, oy1, 0)
		else
			gl.Color(innerColor)
			gl.Vertex(ix2, iy1, 0)
			gl.Vertex(ix2, iy1 + innerCs, 0)
			gl.Color(outerColor)
			gl.Vertex(ox2, oy1 + cs, 0)
			gl.Vertex(ox2, oy1, 0)
		end

		-- Top left corner
		if tl == 1 then
			gl.Color(innerColor)
			gl.Vertex(ix1, iy2 - innerCs, 0)
			gl.Vertex(ix1 + innerCs, iy2, 0)
			gl.Color(outerColor)
			gl.Vertex(ox1 + cs, oy2, 0)
			gl.Vertex(ox1, oy2 - cs, 0)
		else
			gl.Color(innerColor)
			gl.Vertex(ix1, iy2, 0)
			gl.Vertex(ix1, iy2 - innerCs, 0)
			gl.Color(outerColor)
			gl.Vertex(ox1, oy2 - cs, 0)
			gl.Vertex(ox1, oy2, 0)
		end

		-- Top right corner
		if tr == 1 then
			gl.Color(outerColor)
			gl.Vertex(ox2 - cs, oy2, 0)
			gl.Vertex(ox2, oy2 - cs, 0)
			gl.Color(innerColor)
			gl.Vertex(ix2, iy2 - innerCs, 0)
			gl.Vertex(ix2 - innerCs, iy2, 0)
		else
			gl.Color(outerColor)
			gl.Vertex(ox2, oy2, 0)
			gl.Vertex(ox2, oy2 - cs, 0)
			gl.Color(innerColor)
			gl.Vertex(ix2, iy2 - innerCs, 0)
			gl.Vertex(ix2, iy2, 0)
		end
	end
	gl.BeginEnd(GL.QUADS, DrawRectRoundOutline, px, py, sx, sy, cs, outlineWidth, tl, tr, br, bl, outerColor, innerColor)
end

--[[
	RectRoundOutlineQuad
		same as RectRoundOutline but supports a skew table for trapezoidal (non-rectangular) shapes
	params
		px, py, sx, sy = left, bottom, right, top
		cs = corner size
		outlineWidth = width of the outline/feather
		tl, tr, br, bl = enable/disable corners
		outerColor = color for the outside edge
		innerColor = color for the inside edge
		skew = table with optional tlx, tly, trx, try, brx, bry, blx, bly corner offsets
]]
WG.FlowUI.Draw.RectRoundOutlineQuad = function(px, py, sx, sy, cs, outlineWidth, tl, tr, br, bl, outerColor, innerColor, skew)
	local function DrawRectRoundOutlineQuad(px, py, sx, sy, cs, outlineWidth, tl, tr, br, bl, outerColor, innerColor, skew)
		local tl = tl or 1
		local tr = tr or 1
		local br = br or 1
		local bl = bl or 1

		-- Per-corner skew offsets
		local tlx = skew.tlx or 0;  local tly = skew.tly or 0
		local trx = skew.trx or 0;  local try = skew.try or 0
		local brx = skew.brx or 0;  local bry = skew.bry or 0
		local blx = skew.blx or 0;  local bly = skew.bly or 0

		-- Outer quadrilateral corners
		local oBLx, oBLy = px + blx, py + bly
		local oBRx, oBRy = sx + brx, py + bry
		local oTRx, oTRy = sx + trx, sy + try
		local oTLx, oTLy = px + tlx, sy + tly

		-- Normalize 2D vector
		local function n2(x, y)
			local len = math.sqrt(x*x + y*y)
			if len < 0.001 then return 0, 1 end
			return x/len, y/len
		end

		-- Outer edge unit directions CCW: BL->BR->TR->TL->BL
		local bdx, bdy = n2(oBRx-oBLx, oBRy-oBLy)  -- bottom
		local rdx, rdy = n2(oTRx-oBRx, oTRy-oBRy)  -- right
		local tdx, tdy = n2(oTLx-oTRx, oTLy-oTRy)  -- top
		local ldx, ldy = n2(oBLx-oTLx, oBLy-oTLy)  -- left

		-- Inward normals for each edge (rotate edge dir 90° inward, into the shape)
		-- For CCW winding with y-up, inward normal = rotate edge dir 90° CCW (left perp) = (-dy, dx)
		local binx, biny = -bdy,  bdx  -- bottom inward normal
		local rinx, riny = -rdy,  rdx  -- right inward normal
		local tinx, tiny = -tdy,  tdx  -- top inward normal
		local linx, liny = -ldy,  ldx  -- left inward normal

		-- Inner quadrilateral corners: each outer corner offset inward by outlineWidth
		-- along the sum of the two adjacent edge inward normals
		local iBLx = oBLx + outlineWidth * (binx + linx)
		local iBLy = oBLy + outlineWidth * (biny + liny)
		local iBRx = oBRx + outlineWidth * (binx + rinx)
		local iBRy = oBRy + outlineWidth * (biny + riny)
		local iTRx = oTRx + outlineWidth * (tinx + rinx)
		local iTRy = oTRy + outlineWidth * (tiny + riny)
		local iTLx = oTLx + outlineWidth * (tinx + linx)
		local iTLy = oTLy + outlineWidth * (tiny + liny)

		-- Inner edge directions (recompute for inner quad)
		local ibdx, ibdy = n2(iBRx-iBLx, iBRy-iBLy)
		local irdx, irdy = n2(iTRx-iBRx, iTRy-iBRy)
		local itdx, itdy = n2(iTLx-iTRx, iTLy-iTRy)
		local ildx, ildy = n2(iBLx-iTLx, iBLy-iTLy)

		local innerCs = mathMax(0, cs - outlineWidth)

		-- Outer chamfer cut points at distance cs from each outer corner along adjacent edges
		local oblb_x, oblb_y = oBLx + cs*bdx,  oBLy + cs*bdy
		local obll_x, obll_y = oBLx - cs*ldx,  oBLy - cs*ldy
		local obrb_x, obrb_y = oBRx - cs*bdx,  oBRy - cs*bdy
		local obrr_x, obrr_y = oBRx + cs*rdx,  oBRy + cs*rdy
		local otrr_x, otrr_y = oTRx - cs*rdx,  oTRy - cs*rdy
		local otrt_x, otrt_y = oTRx + cs*tdx,  oTRy + cs*tdy
		local otlt_x, otlt_y = oTLx - cs*tdx,  oTLy - cs*tdy
		local otll_x, otll_y = oTLx + cs*ldx,  oTLy + cs*ldy

		-- Inner chamfer cut points at distance innerCs from each inner corner along adjacent inner edges
		local iblb_x, iblb_y = iBLx + innerCs*ibdx, iBLy + innerCs*ibdy
		local ibll_x, ibll_y = iBLx - innerCs*ildx, iBLy - innerCs*ildy
		local ibrb_x, ibrb_y = iBRx - innerCs*ibdx, iBRy - innerCs*ibdy
		local ibrr_x, ibrr_y = iBRx + innerCs*irdx, iBRy + innerCs*irdy
		local itrr_x, itrr_y = iTRx - innerCs*irdx, iTRy - innerCs*irdy
		local itrt_x, itrt_y = iTRx + innerCs*itdx, iTRy + innerCs*itdy
		local itlt_x, itlt_y = iTLx - innerCs*itdx, iTLy - innerCs*itdy
		local itll_x, itll_y = iTLx + innerCs*ildx, iTLy + innerCs*ildy

		-- Draw 12 quads: 4 edge strips + 4 corners + 4 degenerate/square corner fills
		-- Top strip (otlt = TL top-edge chamfer, otrt = TR top-edge chamfer)
		gl.Color(outerColor)
		gl.Vertex(otlt_x, otlt_y, 0)
		gl.Vertex(otrt_x, otrt_y, 0)
		gl.Color(innerColor)
		gl.Vertex(itrt_x, itrt_y, 0)
		gl.Vertex(itlt_x, itlt_y, 0)

		-- Bottom strip
		gl.Color(innerColor)
		gl.Vertex(iblb_x, iblb_y, 0)
		gl.Vertex(ibrb_x, ibrb_y, 0)
		gl.Color(outerColor)
		gl.Vertex(obrb_x, obrb_y, 0)
		gl.Vertex(oblb_x, oblb_y, 0)

		-- Left strip
		gl.Color(outerColor)
		gl.Vertex(obll_x, obll_y, 0)
		gl.Vertex(otll_x, otll_y, 0)
		gl.Color(innerColor)
		gl.Vertex(itll_x, itll_y, 0)
		gl.Vertex(ibll_x, ibll_y, 0)

		-- Right strip
		gl.Color(innerColor)
		gl.Vertex(ibrr_x, ibrr_y, 0)
		gl.Vertex(itrr_x, itrr_y, 0)
		gl.Color(outerColor)
		gl.Vertex(otrr_x, otrr_y, 0)
		gl.Vertex(obrr_x, obrr_y, 0)

		-- BL corner
		if bl == 1 then
			gl.Color(outerColor)
			gl.Vertex(oblb_x, oblb_y, 0)
			gl.Vertex(obll_x, obll_y, 0)
			gl.Color(innerColor)
			gl.Vertex(ibll_x, ibll_y, 0)
			gl.Vertex(iblb_x, iblb_y, 0)
		else
			-- Bottom-edge gap: from bottom strip end (oblb) to actual BL corner
			gl.Color(outerColor)
			gl.Vertex(oblb_x, oblb_y, 0)
			gl.Vertex(oBLx, oBLy, 0)
			gl.Color(innerColor)
			gl.Vertex(iBLx, iBLy, 0)
			gl.Vertex(iblb_x, iblb_y, 0)
			-- Left-edge gap: from BL corner up to left strip start (obll)
			gl.Color(outerColor)
			gl.Vertex(oBLx, oBLy, 0)
			gl.Vertex(obll_x, obll_y, 0)
			gl.Color(innerColor)
			gl.Vertex(ibll_x, ibll_y, 0)
			gl.Vertex(iBLx, iBLy, 0)
		end

		-- BR corner
		if br == 1 then
			gl.Color(innerColor)
			gl.Vertex(ibrb_x, ibrb_y, 0)
			gl.Vertex(ibrr_x, ibrr_y, 0)
			gl.Color(outerColor)
			gl.Vertex(obrr_x, obrr_y, 0)
			gl.Vertex(obrb_x, obrb_y, 0)
		else
			-- Bottom-edge gap: from bottom strip end (obrb) to actual BR corner
			gl.Color(innerColor)
			gl.Vertex(ibrb_x, ibrb_y, 0)
			gl.Vertex(iBRx, iBRy, 0)
			gl.Color(outerColor)
			gl.Vertex(oBRx, oBRy, 0)
			gl.Vertex(obrb_x, obrb_y, 0)
			-- Right-edge gap: from BR corner up to right strip start (obrr)
			gl.Color(innerColor)
			gl.Vertex(iBRx, iBRy, 0)
			gl.Vertex(ibrr_x, ibrr_y, 0)
			gl.Color(outerColor)
			gl.Vertex(obrr_x, obrr_y, 0)
			gl.Vertex(oBRx, oBRy, 0)
		end

		-- TL corner
		if tl == 1 then
			gl.Color(innerColor)
			gl.Vertex(itll_x, itll_y, 0)
			gl.Vertex(itlt_x, itlt_y, 0)
			gl.Color(outerColor)
			gl.Vertex(otlt_x, otlt_y, 0)
			gl.Vertex(otll_x, otll_y, 0)
		else
			-- Left-edge gap: from left strip end (otll) up to actual TL corner
			gl.Color(outerColor)
			gl.Vertex(otll_x, otll_y, 0)
			gl.Vertex(oTLx, oTLy, 0)
			gl.Color(innerColor)
			gl.Vertex(iTLx, iTLy, 0)
			gl.Vertex(itll_x, itll_y, 0)
			-- Top-edge gap: from TL corner to top strip start (otlt)
			gl.Color(innerColor)
			gl.Vertex(iTLx, iTLy, 0)
			gl.Vertex(itlt_x, itlt_y, 0)
			gl.Color(outerColor)
			gl.Vertex(otlt_x, otlt_y, 0)
			gl.Vertex(oTLx, oTLy, 0)
		end

		-- TR corner
		if tr == 1 then
			gl.Color(outerColor)
			gl.Vertex(otrt_x, otrt_y, 0)
			gl.Vertex(otrr_x, otrr_y, 0)
			gl.Color(innerColor)
			gl.Vertex(itrr_x, itrr_y, 0)
			gl.Vertex(itrt_x, itrt_y, 0)
		else
			-- Top-edge gap: from top strip end (otrt) to actual TR corner
			gl.Color(outerColor)
			gl.Vertex(otrt_x, otrt_y, 0)
			gl.Vertex(oTRx, oTRy, 0)
			gl.Color(innerColor)
			gl.Vertex(iTRx, iTRy, 0)
			gl.Vertex(itrt_x, itrt_y, 0)
			-- Right-edge gap: from TR corner down to right strip start (otrr)
			gl.Color(outerColor)
			gl.Vertex(oTRx, oTRy, 0)
			gl.Vertex(otrr_x, otrr_y, 0)
			gl.Color(innerColor)
			gl.Vertex(itrr_x, itrr_y, 0)
			gl.Vertex(iTRx, iTRy, 0)
		end
	end
	gl.BeginEnd(GL.QUADS, DrawRectRoundOutlineQuad, px, py, sx, sy, cs, outlineWidth, tl, tr, br, bl, outerColor, innerColor, skew)
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
	local borderSize = borderSize~=nil and borderSize or mathMin(mathMax(1, mathFloor((sx-px) * 0.024)), mathFloor((WG.FlowUI.vsy*0.0015)+0.5))	-- set default with upper limit
	local cs = cs~=nil and cs or mathMax(1, mathFloor((sx-px) * 0.024))
	borderOpacity = borderOpacity or 0.1

	-- Layer 1: Draw unit texture
	if texture then
		gl.Texture(texture)
	end
	gl.BeginEnd(GL.QUADS, WG.FlowUI.Draw.TexRectRound, px, py, sx, sy,  cs,  tl, tr, br, bl,  zoom+0.02)
	if texture then
		gl.Texture(false)
	end

	-- Layer 1.1: background base outline (feathered)
	local baseOutlineWidth = mathMax(1, mathFloor(((sx-px) + (sy-py)) * 0.022))
	WG.FlowUI.Draw.RectRoundOutline(
		px-baseOutlineWidth, py-baseOutlineWidth, sx+baseOutlineWidth, sy+baseOutlineWidth, cs*2, baseOutlineWidth,
		tl, tr, br, bl,
		{ 0, 0, 0, 0 }, { 0, 0, 0, 0.22 }
	)

	-- Layer 2: Darken bottom gradient (creates depth)
	WG.FlowUI.Draw.RectRound(px, py, sx, sy, cs, 0, 0, 1, 1, { 0, 0, 0, 0.2 }, { 0, 0, 0, 0 })

	-- Layers 3-4: Combined shine and edge effects (using additive blending)
	gl.Blending(GL.SRC_ALPHA, GL.ONE)

	-- Top shine gradient
	WG.FlowUI.Draw.RectRound(px, sy-((sy-py)*0.4), sx, sy, cs, 1, 1, 0, 0, {1, 1, 1, 0}, {1, 1, 1, 0.06})

	-- Feathered edge highlight using rectangular outline
	if borderSize > 0 then
		-- Combined feather edge and border into single call
		WG.FlowUI.Draw.RectRoundOutline(
			px, py, sx, sy, cs*0.7, borderSize,
			tl, tr, br, bl,
			{ 1, 1, 1, borderOpacity + 0.04 }, { 1, 1, 1, borderOpacity }
		)
	else
		-- Just the feather edge when no border
		local featherWidth = mathMax(1, mathFloor(((sx-px) + (sy-py)) * 0.015))
		WG.FlowUI.Draw.RectRoundOutline(
			px, py, sx, sy, cs*0.7, featherWidth,
			tl, tr, br, bl,
			{ 1, 1, 1, 0.04 }, { 1, 1, 1, 0 }
		)
	end

	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)

	-- Layer 5: Group texture icon (if present)
	if groupTexture then
		local iconSize = mathFloor((sx - px) * 0.3)
		gl.Color(1, 1, 1, 1)
		gl.Texture(groupTexture)
		gl.BeginEnd(GL.QUADS, WG.FlowUI.Draw.TexRectRound, px, sy - iconSize, px + iconSize, sy,  0,  0,0,0,0,  0.05)
		gl.Texture(false)
	end

	-- Layer 6: Radar texture icon (if present)
	if radarTexture then
		local iconSize = mathFloor((sx - px) * 0.25)
		local iconPadding = mathFloor((sx - px) * 0.03)
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
	local padding = mathFloor((width * 0.25) + 0.5)
	local sliderAreaHeight = height - padding - padding
	local sliderHeight = sliderAreaHeight / contentHeight

	if sliderHeight < 1 then
		position = position or 0
		sliderHeight = mathFloor((sliderHeight * sliderAreaHeight) + 0.5)
		local sliderPos = sy - padding - mathFloor((sliderAreaHeight * (position / contentHeight)) + 0.5)

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
	local edgeWidth = mathMax(1, mathFloor(height * 0.1))

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
	local padding = mathFloor(height * 0.2)
	local radius = mathFloor(height * 0.5) - padding
	local y = mathFloor(py + (height * 0.5))
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
		x = mathFloor(px + (width * 0.42))
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
	local cs = mathMax(1.1, radius*0.15)

	-- faint dark outline edge
	local edgeWidth = mathMax(1, mathFloor(radius * 0.05))
	WG.FlowUI.Draw.RectRound(x-radius-edgeWidth, y-radius-edgeWidth, x+radius+edgeWidth, y+radius+edgeWidth, cs, 1,1,1,1, {0,0,0,0.12})
	local edgeWidth = mathMax(2, mathFloor(radius * 0.3))
	WG.FlowUI.Draw.RectRoundOutline(x-radius-edgeWidth, y-radius-edgeWidth, x+radius+edgeWidth, y+radius+edgeWidth, cs, edgeWidth, 1, 1, 1, 1, {0,0,0,0}, {0,0,0,0.17})
	-- knob
	WG.FlowUI.Draw.RectRound(x-radius, y-radius, x+radius, y+radius, cs, 1,1,1,1, color1, color)

	-- lighten knob inside edges
	gl.Blending(GL.SRC_ALPHA, GL.ONE)
	local innerOutlineWidth = radius * 0.17
	WG.FlowUI.Draw.RectRoundOutline(x-radius, y-radius, x+radius, y+radius, cs, innerOutlineWidth, 1, 1, 1, 1, {1,1,1,0.22}, {1,1,1,0})
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)

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
	local edgeWidth = mathMax(1, mathFloor(height * 0.1))

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
				processedSteps[#processedSteps + 1] = mathFloor((px + (width * ((value - min) / (max - min)))) + 0.5)
			end
			-- remove first step at the bar start
			processedSteps[1] = nil
		elseif min and max then
			numSteps = (max - min) / steps
			for i = 1, numSteps do
				processedSteps[#processedSteps + 1] = mathFloor((px + (width / numSteps) * (#processedSteps + 1)) + 0.5)
				i = i + 1
			end
		end
		-- remove last step at the bar end
		processedSteps[#processedSteps] = nil

		-- dont bother when steps too small
		if numSteps and numSteps < (width / 7) then
			local stepSizeLeft = mathMax(1, mathFloor(width * 0.01))
			local stepSizeRight = mathFloor(width * 0.005)
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
	local edgeWidth = mathMax(1, mathFloor(height * 0.1))

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
	local edgeWidth = mathMax(1, mathFloor((WG.FlowUI.vsy * 0.001)))
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
