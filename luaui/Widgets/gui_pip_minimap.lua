-- This widget replaces the standard minimap with a PIP-style minimap
-- It uses pipNumber = 0 to trigger minimap replacement mode in gui_pip.lua
-- Features:
--   - Positioned at top-left like standard minimap
--   - No screen margin restrictions (edge-to-edge)
--   - No minimize button (always visible)
--   - Calls DrawInMiniMap overlays from other widgets during R2T rendering
--   - In a VR headset it also shows in a panel at the top left of the view

pipNumber = 0 -- Triggers minimap mode in gui_pip.lua

require("luaui/Widgets/gui_pip")

-- Override GetInfo to change the name and layer
widget.GetInfo = function()
	return {
		name = "Picture-in-Picture Minimap",
		desc = "Replaces minimap with an interactive PIP-style map view. Supports panning, zooming, and unit tracking.",
		author = "Floris",
		version = "1.0",
		date = "January 2026",
		license = "GNU GPL, v2 or later",
		layer = -99000,
		enabled = true,
		handler = true,
	}
end

-- VR headset panel: the map is copied from where it was drawn in the window into a
-- panel in front of the head, and the headset's pointer over the panel is mapped back
-- to the window position over the map, for hovering and clicking
local xrPanel = Spring.XRSetPanel
	and VFS.Include(LUAUI_DIRNAME .. "Include/xr_panel.lua").New("pip_minimap", {
		mode = "head",
		x = -0.9,
		y = 0.1,
		z = 1.2,
		width = 0.45,
	})
local copyTex, copyW, copyH
local rect

local function mapMouse(x, y)
	return xrPanel:MapMouse(x, y)
end

local function drawCopy()
	gl.Blending(false)
	gl.Color(1, 1, 1, 1)
	gl.Texture(0, copyTex)
	gl.TexRect(rect[1], rect[2], rect[3], rect[4], 0, 0, 1, 1)
	gl.Texture(0, false)
	-- the window's alpha is not meaningful: make the panel opaque
	gl.ColorMask(false, false, false, true)
	gl.Color(0, 0, 0, 1)
	gl.Rect(rect[1], rect[2], rect[3], rect[4])
	gl.ColorMask(true, true, true, true)
	gl.Blending(true)
end

local function releaseCopy()
	if copyTex then
		gl.DeleteTexture(copyTex)
		copyTex = nil
	end
end

if xrPanel then
	local origDrawScreen = widget.DrawScreen
	local origIsAbove = widget.IsAbove
	local origMousePress = widget.MousePress
	local origMouseMove = widget.MouseMove
	local origMouseRelease = widget.MouseRelease
	local origMouseWheel = widget.MouseWheel
	local origInitialize = widget.Initialize
	local origShutdown = widget.Shutdown

	local function hasHeadset()
		return Spring.XRGetHeadPose and Spring.XRGetHeadPose() ~= nil
	end

	function widget:Initialize()
		WG["pipXRMapMouse0"] = mapMouse
		return origInitialize(self)
	end

	function widget:Shutdown()
		WG["pipXRMapMouse0"] = nil
		xrPanel:Destroy()
		releaseCopy()
		return origShutdown(self)
	end

	function widget:DrawScreen()
		origDrawScreen(self)

		local bounds = WG.pip0 and WG.pip0.GetScreenBounds
		if not hasHeadset() or not bounds then
			xrPanel:Hide()
			return
		end

		local vsx, vsy = Spring.GetViewGeometry()
		local l, r, b, t = bounds()
		if not (l and r and b and t) then
			return
		end
		local pad = WG.FlowUI and WG.FlowUI.elementPadding or 0
		l = math.max(0, math.floor(l - pad))
		b = math.max(0, math.floor(b - pad))
		r = math.min(vsx, math.ceil(r + pad))
		t = math.min(vsy, math.ceil(t + pad))
		local w, h = r - l, t - b
		if w < 4 or h < 4 then
			xrPanel:Hide()
			return
		end

		if copyTex and (copyW ~= w or copyH ~= h) then
			releaseCopy()
		end
		if not copyTex then
			copyTex = gl.CreateTexture(w, h, {
				target = GL.TEXTURE_2D,
				format = GL.RGBA,
				min_filter = GL.LINEAR,
				mag_filter = GL.LINEAR,
				wrap_s = GL.CLAMP_TO_EDGE,
				wrap_t = GL.CLAMP_TO_EDGE,
			})
			copyW, copyH = w, h
			if not copyTex then
				return
			end
		end

		gl.CopyToTexture(copyTex, 0, 0, l, b, w, h)

		rect = { l, b, r, t }
		xrPanel:Mirror(drawCopy, rect, 1)
	end

	-- the pointer is on the map only through the panel
	function widget:IsAbove(x, y)
		x, y = xrPanel:MapMouse(x, y)
		return origIsAbove(self, x, y)
	end

	function widget:MousePress(x, y, button)
		x, y = xrPanel:MapMouse(x, y)
		return origMousePress(self, x, y, button)
	end

	function widget:MouseMove(x, y, dx, dy, button)
		x, y = xrPanel:MapMouse(x, y)
		return origMouseMove(self, x, y, dx, dy, button)
	end

	function widget:MouseRelease(x, y, button)
		x, y = xrPanel:MapMouse(x, y)
		return origMouseRelease(self, x, y, button)
	end

	function widget:MouseWheel(up, value)
		-- the wheel has no position: only while the pointer is on the map
		if hasHeadset() and not xrPanel:GetHit() then
			return false
		end
		return origMouseWheel(self, up, value)
	end
end

return widget
