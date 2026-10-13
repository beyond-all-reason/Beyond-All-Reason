-- Mirrors a widget's cached UI textures into a floating panel in the VR headset
-- (Spring.XRSetPanel). The widget keeps drawing to the window as before and hands
-- its textures over after they were (re)rendered.
--
-- local xrPanel = XRPanel.New("gridmenu", { mode = "head", x = 0.5, y = -0.25, z = 1.2, width = 0.7 })
-- xrPanel:Update({ backgroundTex, contentTex }, texWidth, texHeight, dirty, rect) -- every frame it is shown
-- xrPanel:MapMouse(x, y) -- the mouse position the widget should use, see below
-- The pointer (the mouse, mapped through the headset view) is drawn as a dot on the panel
-- where it points; xrPanel:GetHit() gives that position as 0..1 from the bottom left.
-- xrPanel:Hide()    -- when it is not shown
-- xrPanel:Destroy() -- in widget:Shutdown
--
-- The textures must have been rendered with gl.R2tHelper.RenderToTexture (premultiplied
-- alpha), they are layered on top of each other in the order given.

local XRPanel = {}
XRPanel.__index = XRPanel

local CURSOR_RADIUS = 9 -- pixels of the panel texture
-- the headset runtime refuses very large images
local MAX_TEXTURE_SIZE = 4096

-- floors the size and scales it down to fit the largest allowed texture
local function fitSize(w, h)
	local scale = math.min(1, MAX_TEXTURE_SIZE / math.max(w, h, 1))
	return math.floor(w * scale), math.floor(h * scale)
end

local function drawDisc(cx, cy, rx, ry)
	gl.BeginEnd(GL.TRIANGLE_FAN, function()
		gl.Vertex(cx, cy)
		for i = 0, 20 do
			local a = i / 20 * 2 * math.pi
			gl.Vertex(cx + math.cos(a) * rx, cy + math.sin(a) * ry)
		end
	end)
end

local function hasHeadset()
	return Spring.XRGetHeadPose and Spring.XRGetHeadPose() ~= nil
end

function XRPanel.New(id, params)
	if not Spring.XRSetPanel then
		return nil
	end
	return setmetatable({ id = id, params = params }, XRPanel)
end

function XRPanel:Release()
	if self.tex then
		Spring.XRRemovePanel(self.id)
		gl.DeleteTexture(self.tex)
		self.tex = nil
	end
	self.panelSet = false
	self.hitU, self.hitV = nil, nil
end

function XRPanel:Hide()
	if self.panelSet then
		Spring.XRRemovePanel(self.id)
		self.panelSet = false
		self.hitU, self.hitV = nil, nil
	end
end

-- The mouse position a widget should use for hovering and clicking. With a headset the
-- real mouse is not over the window's menu, the pointer is: this gives the window position
-- that matches where the pointer is on the panel, and a position far outside the menu
-- when it is not on the panel. Without a headset it is the position given.
function XRPanel:MapMouse(x, y)
	if not hasHeadset() then
		return x, y
	end
	local rect = self.rect
	if not (rect and self.panelSet) then
		return -100000, -100000
	end
	local u, v = Spring.XRPanelHit(self.id)
	if not u then
		return -100000, -100000
	end
	return rect[1] + u * (rect[3] - rect[1]), rect[2] + v * (rect[4] - rect[2])
end

-- where the pointer is on the panel (0..1 from the bottom left), nil when it is not on it
function XRPanel:GetHit()
	return self.hitU, self.hitV
end

function XRPanel:Destroy()
	self:Release()
end

-- (re)creates the panel texture when its size changed; returns whether it was created
-- (nil if it could not be), and the size
function XRPanel:EnsureTexture(w, h)
	local created = false
	if self.tex and (self.w ~= w or self.h ~= h) then
		self:Release()
	end
	if not self.tex then
		self.tex = gl.CreateTexture(w, h, {
			target = GL.TEXTURE_2D,
			format = GL.RGBA,
			fbo = true,
			min_filter = GL.LINEAR,
			mag_filter = GL.LINEAR,
			wrap_s = GL.CLAMP_TO_EDGE,
			wrap_t = GL.CLAMP_TO_EDGE,
		})
		if not self.tex then
			return nil, w, h
		end
		self.w, self.h = w, h
		created = true
	end
	return created, w, h
end

-- For a widget that draws without cached textures: calls drawFn, which draws in window
-- coordinates (as in widget:DrawScreen), into the panel, showing the window rectangle
-- rect = { x, y, xEnd, yEnd } at scale times its size in pixels. Call it as often as the
-- panel should refresh.
function XRPanel:Mirror(drawFn, rect, scale)
	if not hasHeadset() then
		self:Hide()
		return
	end

	local rw, rh = rect[3] - rect[1], rect[4] - rect[2]
	local w, h = fitSize(rw * scale, rh * scale)
	if w <= 0 or h <= 0 then
		return
	end
	if self:EnsureTexture(w, h) == nil then
		return
	end
	self.rect = rect

	local hitU, hitV
	if self.panelSet then
		hitU, hitV = Spring.XRPanelHit(self.id)
	end
	self.hitU, self.hitV = hitU, hitV

	gl.R2tHelper.RenderToTexture(self.tex, function()
		gl.Translate(-1, -1, 0)
		gl.Scale(2 / rw, 2 / rh, 0)
		gl.Translate(-rect[1], -rect[2], 0)
		drawFn()
		if hitU then
			-- the pointer, in window coordinates here
			local k = 1 / scale
			local cx, cy = rect[1] + hitU * rw, rect[2] + hitV * rh
			gl.Texture(false)
			gl.Blending(GL.ONE, GL.ONE_MINUS_SRC_ALPHA)
			gl.Color(0, 0, 0, 1)
			drawDisc(cx, cy, CURSOR_RADIUS * k, CURSOR_RADIUS * k)
			gl.Color(1, 1, 1, 1)
			drawDisc(cx, cy, CURSOR_RADIUS * 0.65 * k, CURSOR_RADIUS * 0.65 * k)
		end
	end, true)

	if not self.panelSet then
		self.panelSet = Spring.XRSetPanel(self.id, self.tex, self.params) and true or false
	end
end

-- layers: textures to layer in order, w, h: size of the panel texture in pixels,
-- dirty: the layers were rendered again since the last call,
-- rect: where the panel shows in the window, { x, y, xEnd, yEnd } in the widget's coordinates
function XRPanel:Update(layers, w, h, dirty, rect)
	self.rect = rect
	if not hasHeadset() then
		self:Hide()
		return
	end

	w, h = fitSize(w, h)
	if w <= 0 or h <= 0 then
		return
	end

	local created
	created, w, h = self:EnsureTexture(w, h)
	if created == nil then
		return
	end
	dirty = dirty or created

	local hitU, hitV
	if self.panelSet then
		hitU, hitV = Spring.XRPanelHit(self.id)
	end
	local cursorMoved = (hitU ~= self.hitU) or (hitV ~= self.hitV)
	self.hitU, self.hitV = hitU, hitV

	if dirty or cursorMoved or not self.panelSet then
		gl.R2tHelper.RenderToTexture(self.tex, function()
			for _, layer in ipairs(layers) do
				gl.R2tHelper.BlendTexRect(layer, -1, -1, 1, 1, true)
			end
			if hitU then
				local cx, cy = hitU * 2 - 1, hitV * 2 - 1
				local rx, ry = CURSOR_RADIUS * 2 / w, CURSOR_RADIUS * 2 / h
				gl.Texture(false)
				gl.Blending(GL.ONE, GL.ONE_MINUS_SRC_ALPHA)
				gl.Color(0, 0, 0, 1)
				drawDisc(cx, cy, rx, ry)
				gl.Color(1, 1, 1, 1)
				drawDisc(cx, cy, rx * 0.65, ry * 0.65)
			end
		end, true)
	end

	if not self.panelSet then
		self.panelSet = Spring.XRSetPanel(self.id, self.tex, self.params) and true or false
	end
end

return XRPanel
