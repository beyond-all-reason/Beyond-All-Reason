-- tf_scenery.lua: SCENE > SCENERY, one window for what surrounds the map: the mirrored
-- border, the rings around it, the backdrop below it (WG.MapBelow), the sky and the
-- water plane. Presets set all of them at once.
local M = {}

-- RmlUi listener closures can run outside the widget env: keep what they use as upvalues
local math, tonumber, tostring, ipairs, pairs = math, tonumber, tostring, ipairs, pairs
local Spring, gl = Spring, gl

local CHECK_ON = "/luaui/images/terraform_brush/check_on.png"
local CHECK_OFF = "/luaui/images/terraform_brush/check_off.png"

-- slider id suffix -> field, nudge step, slider value <-> field value
local SLIDERS = {
	{ id = "depth", field = "depth", step = 500, scale = 1 },
	{ id = "size", field = "size", step = 1, scale = 1 },
	{ id = "yaw", field = "yaw", step = 5, scale = 1, wrap = 360 },
	{ id = "spin", field = "spin", step = 1, scale = 1 },
	{ id = "bright", field = "brightness", step = 5, scale = 0.01 },
}

-- water = the map keeps its water plane, border = mirrored border, kind = backdrop below
M.PRESETS = {
	standard = { water = true, border = true, kind = "" },
	void = { water = false, border = false, kind = "" },
	floating = { water = false, border = false, kind = "planet" },
	clouds = { water = false, border = false, kind = "clouds" },
}

function M.attach(doc, ctx)
	local widgetState = ctx.widgetState
	local uiState = ctx.uiState
	local playSound = ctx.playSound
	local trackSliderDrag = ctx.trackSliderDrag
	local WG = ctx.WG

	local root = doc:GetElementById("tf-env-scenery-root")
	widgetState.envSceneryRootEl = root
	local S = {}
	widgetState.scenery = S

	local function below()
		return WG.MapBelow
	end
	local function border()
		return WG.mapedgeextension
	end

	local function setCheck(id, on)
		local el = doc:GetElementById(id)
		if el then
			el:SetAttribute("src", on and CHECK_ON or CHECK_OFF)
		end
	end

	-- what the scene is now, in preset terms
	function S.getState()
		local ee = border()
		local A = below()
		return {
			water = not gl.GetMapRendering("voidWater"),
			ground = not gl.GetMapRendering("voidGround"),
			border = ee ~= nil and ee.getHidden ~= nil and not ee.getHidden(),
			kind = A and A.getState().kind or "",
		}
	end

	function S.setBorder(on)
		local ee = border()
		if ee and ee.setHidden then
			ee.setHidden(not on)
		end
	end

	function S.sync()
		local A = below()
		-- the Map Below widget may load after this panel: hook its change event on first use
		if A and not S.hooked then
			S.hooked = true
			A.onChange("tf_scenery", S.sync)
		end
		local now = S.getState()
		setCheck("btn-scenery-border", now.border)
		setCheck("btn-scenery-water", now.water)
		setCheck("btn-scenery-ground", now.ground)
		setCheck("btn-env-voidwater", not now.water)
		setCheck("btn-env-voidground", not now.ground)
		local st = A and A.getState() or { kind = "", look = "" }
		for _, k in ipairs({ "none", "planet", "clouds" }) do
			local el = doc:GetElementById("btn-scenery-kind-" .. k)
			if el then
				el:SetClass("active", (k == "none" and "" or k) == st.kind)
				el:SetClass("disabled", A == nil)
			end
		end
		for _, l in ipairs(A and A.getLooks() or {}) do
			local el = doc:GetElementById("btn-scenery-look-" .. l.name)
			if el then
				el:SetClass("active", l.name == st.look)
			end
		end
		local rings = doc:GetElementById("btn-scenery-open-blockout")
		local B = widgetState.blockout
		if rings then
			rings:SetClass("disabled", not (B and B.available and B.available()))
		end
		local looks = doc:GetElementById("scenery-looks-row")
		if looks then
			looks:SetClass("hidden", st.kind ~= "planet")
		end
		local controls = doc:GetElementById("scenery-below-controls")
		if controls then
			controls:SetClass("hidden", st.kind == "")
		end
		for name in pairs(M.PRESETS) do
			local el = doc:GetElementById("btn-scenery-preset-" .. name)
			if el then
				local p = M.PRESETS[name]
				el:SetClass(
					"active",
					p.water == now.water and p.border == now.border and p.kind == now.kind and now.ground
				)
			end
		end
		uiState.updatingFromCode = true
		for _, s in ipairs(SLIDERS) do
			local id = "slider-scenery-" .. s.id
			local v = math.floor((st[s.field] or 0) / s.scale + 0.5)
			local sl = doc:GetElementById(id)
			if sl and uiState.draggingSlider ~= id then
				sl:SetAttribute("value", tostring(v))
			end
			local box = doc:GetElementById(id .. "-numbox")
			if box then
				box:SetAttribute("value", tostring(v))
			end
		end
		uiState.updatingFromCode = false
	end

	function S.applyPreset(name)
		local p = M.PRESETS[name]
		if not p then
			return false
		end
		Spring.SetMapRenderingParams({ voidWater = not p.water, voidGround = false })
		S.setBorder(p.border)
		local A = below()
		if A then
			A.set({ kind = p.kind })
		end
		S.sync()
		return true
	end

	local function setOpen(open)
		widgetState.envSceneryOpen = open
		if root then
			root:SetClass("hidden", not open)
		end
		if widgetState.dmHandle then
			widgetState.dmHandle.envSceneryVisible = open
		end
		local btn = doc:GetElementById("btn-env-scenery")
		if btn then
			btn:SetClass("env-open", open)
		end
		if open then
			S.sync()
		end
	end
	S.setOpen = setOpen

	local function onDown(id, fn)
		local el = doc:GetElementById(id)
		if el then
			el:AddEventListener("mousedown", function(event)
				fn(el)
				event:StopPropagation()
			end, false)
		end
	end

	onDown("btn-env-scenery", function()
		setOpen(not widgetState.envSceneryOpen)
		playSound(widgetState.envSceneryOpen and "panelOpen" or "click")
	end)
	onDown("btn-env-scenery-close", function()
		playSound("click")
		setOpen(false)
	end)

	for name in pairs(M.PRESETS) do
		onDown("btn-scenery-preset-" .. name, function()
			S.applyPreset(name)
			playSound("click")
		end)
	end

	onDown("btn-scenery-border", function()
		S.setBorder(not S.getState().border)
		playSound("click")
		S.sync()
	end)
	onDown("btn-scenery-water", function()
		Spring.SetMapRenderingParams({ voidWater = not gl.GetMapRendering("voidWater") })
		playSound("click")
		S.sync()
	end)
	onDown("btn-scenery-ground", function()
		Spring.SetMapRenderingParams({ voidGround = not gl.GetMapRendering("voidGround") })
		playSound("click")
		S.sync()
	end)
	onDown("btn-scenery-open-blockout", function()
		local B = widgetState.blockout
		if B and B.setOpen and B.available() then
			B.setOpen(true)
			playSound("panelOpen")
		end
	end)

	for _, k in ipairs({ "none", "planet", "clouds" }) do
		onDown("btn-scenery-kind-" .. k, function()
			local A = below()
			if A then
				A.set({ kind = k == "none" and "" or k })
				playSound("click")
			end
		end)
	end
	for _, name in ipairs({ "terran", "desert", "ice", "lava", "gas" }) do
		onDown("btn-scenery-look-" .. name, function()
			local A = below()
			if A then
				A.set({ look = name })
				playSound("click")
			end
		end)
	end

	local function setField(s, sliderValue)
		local A = below()
		if A then
			A.set({ [s.field] = sliderValue * s.scale })
		end
	end
	for _, s in ipairs(SLIDERS) do
		local id = "slider-scenery-" .. s.id
		local sl = doc:GetElementById(id)
		if sl then
			trackSliderDrag(sl, id)
			sl:AddEventListener("change", function(event)
				if uiState.updatingFromCode then
					return
				end
				setField(s, tonumber(sl:GetAttribute("value")) or 0)
				event:StopPropagation()
			end, false)
			for dir, suffix in ipairs({ "down", "up" }) do
				onDown("btn-scenery-" .. s.id .. "-" .. suffix, function()
					local v = (tonumber(sl:GetAttribute("value")) or 0) + (dir == 1 and -1 or 1) * s.step
					local lo, hi = tonumber(sl:GetAttribute("min")) or 0, tonumber(sl:GetAttribute("max")) or 100
					if s.wrap then
						v = v % s.wrap
					else
						v = math.max(lo, math.min(hi, v))
					end
					setField(s, v)
					playSound("click")
				end)
			end
			local box = doc:GetElementById(id .. "-numbox")
			if box then
				box:AddEventListener("change", function(event)
					if uiState.updatingFromCode then
						return
					end
					local v = tonumber(box:GetAttribute("value"))
					if v then
						setField(s, v)
					end
					event:StopPropagation()
				end, false)
			end
		end
	end

	S.sync()
	if root then
		root:SetClass("hidden", not widgetState.envSceneryOpen)
	end
end

return M
