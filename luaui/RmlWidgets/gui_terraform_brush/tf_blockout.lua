-- tf_blockout.lua: SCENE > BLOCKOUT, the floating window that sets the map's backdrop
-- layers (WG.Blockout, drawn by the Map Blockout widget). One row group per layer: a
-- model dropdown (None + every blockout model), rotation and scale.
local M = {}

-- RmlUi listener closures can run outside the widget env: keep what they use as upvalues
local math, tonumber, tostring, ipairs, pairs = math, tonumber, tostring, ipairs, pairs

local LAYERS = 3
local YAW_STEP, SCALE_STEP = 5, 5

function M.attach(doc, ctx)
	local widgetState = ctx.widgetState
	local uiState = ctx.uiState
	local playSound = ctx.playSound
	local trackSliderDrag = ctx.trackSliderDrag
	local WG = ctx.WG

	local root = doc:GetElementById("tf-env-blockout-root")
	widgetState.envBlockoutRootEl = root
	local B = { dropdownOpen = {} }
	widgetState.blockout = B

	local function api()
		return WG.Blockout
	end

	local function setOpen(open)
		widgetState.envBlockoutOpen = open
		if root then
			root:SetClass("hidden", not open)
		end
		if widgetState.dmHandle then
			widgetState.dmHandle.envBlockoutVisible = open
		end
		local btn = doc:GetElementById("btn-env-blockout")
		if btn then
			btn:SetClass("env-open", open)
		end
		if open and B.sync then
			B.sync()
		end
	end

	-- The ring models ship in a separate asset pack (customparams.blockout features). Without it the
	-- window has nothing to offer, so the button greys out and says why.
	local openBtn = doc:GetElementById("btn-env-blockout")
	local function available()
		local A = api()
		local ok = A ~= nil and A.getCatalog ~= nil and #A.getCatalog() > 0
		if openBtn then
			openBtn:SetClass("disabled", not ok)
			local label = openBtn:QuerySelector(".tf-env-btn-text")
			if label then
				label.inner_rml = ok and "BLOCKOUT" or "BLOCKOUT (no assets)"
			end
		end
		return ok
	end
	B.available = available
	available()
	if openBtn then
		openBtn:AddEventListener("mousedown", function(event)
			if not available() then
				event:StopPropagation()
				return
			end
			setOpen(not widgetState.envBlockoutOpen)
			playSound(widgetState.envBlockoutOpen and "panelOpen" or "click")
			event:StopPropagation()
		end, false)
	end
	local closeBtn = doc:GetElementById("btn-env-blockout-close")
	if closeBtn then
		closeBtn:AddEventListener("mousedown", function(event)
			playSound("click")
			setOpen(false)
			event:StopPropagation()
		end, false)
	end

	-- collapsible layer sections (same classes as the env windows)
	for i = 1, LAYERS do
		local btn = doc:GetElementById("btn-env-toggle-blockout-" .. i)
		local img = doc:GetElementById("img-env-toggle-blockout-" .. i)
		local sec = doc:GetElementById("env-section-blockout-" .. i)
		local frame = doc:GetElementById("env-frame-blockout-" .. i)
		if btn and sec then
			btn:AddEventListener("click", function(event)
				local hide = not sec:IsClassSet("hidden")
				sec:SetClass("hidden", hide)
				if frame then
					frame:SetClass("tf-collapsed", hide)
				end
				if img then
					img:SetAttribute("src", "/luaui/images/terraform_brush/" .. (hide and "plus.png" or "minus.png"))
				end
				playSound("click")
				event:StopPropagation()
			end, false)
		end
	end

	local function labelFor(defName)
		if not defName then
			return "None"
		end
		local A = api()
		for _, e in ipairs(A and A.getCatalog() or {}) do
			if e.name == defName then
				return e.label
			end
		end
		return defName
	end

	local function setDropdownOpen(i, open)
		B.dropdownOpen[i] = open
		local dd = doc:GetElementById("blockout-dropdown-" .. i)
		if dd then
			dd:SetClass("hidden", not open)
		end
		local btn = doc:GetElementById("btn-blockout-pick-" .. i)
		if btn then
			btn:SetClass("open", open)
		end
	end

	local function rebuildDropdown(i)
		local dd = doc:GetElementById("blockout-dropdown-" .. i)
		local A = api()
		if not (dd and A) then
			return
		end
		dd.inner_rml = ""
		local current = (A.getLayer(i) or {}).def
		local rows = { { name = false, label = "None" } }
		for _, e in ipairs(A.getCatalog()) do
			rows[#rows + 1] = e
		end
		for _, e in ipairs(rows) do
			local row = doc:CreateElement("div")
			row:SetClass("tf-preset-row", true)
			row:SetClass("selected", (e.name or nil) == current)
			local name = doc:CreateElement("div")
			name:SetClass("tf-preset-name", true)
			name.inner_rml = e.label
			row:AppendChild(name)
			row:AddEventListener("click", function(event)
				A.setLayer(i, { def = e.name })
				setDropdownOpen(i, false)
				playSound("click")
				event:StopPropagation()
			end, false)
			dd:AppendChild(row)
		end
	end

	-- write one layer field, then let WG.Blockout's change listener resync the window
	local function setField(i, key, value)
		local A = api()
		if A then
			A.setLayer(i, { [key] = value })
		end
	end

	local function wireSlider(i, key, step, toValue)
		local id = "slider-blockout-" .. key .. "-" .. i
		local sl = doc:GetElementById(id)
		if not sl then
			return
		end
		trackSliderDrag(sl, id)
		sl:AddEventListener("change", function(event)
			if uiState.updatingFromCode then
				return
			end
			setField(i, key, toValue(tonumber(sl:GetAttribute("value")) or 0))
			event:StopPropagation()
		end, false)
		local function nudge(dir)
			local v = (tonumber(sl:GetAttribute("value")) or 0) + dir * step
			local lo, hi = tonumber(sl:GetAttribute("min")) or 0, tonumber(sl:GetAttribute("max")) or 100
			if key == "yaw" then
				v = v % 360
			else
				v = math.max(lo, math.min(hi, v))
			end
			setField(i, key, toValue(v))
			playSound("click")
		end
		for dir, suffix in ipairs({ "down", "up" }) do
			local b = doc:GetElementById("btn-blockout-" .. key .. "-" .. i .. "-" .. suffix)
			if b then
				b:AddEventListener("mousedown", function(event)
					nudge(dir == 1 and -1 or 1)
					event:StopPropagation()
				end, false)
			end
		end
		local box = doc:GetElementById(id .. "-numbox")
		if box then
			box:AddEventListener("change", function(event)
				if uiState.updatingFromCode then
					return
				end
				local v = tonumber(box:GetAttribute("value"))
				if v then
					setField(i, key, toValue(v))
				end
				event:StopPropagation()
			end, false)
		end
	end

	for i = 1, LAYERS do
		local pick = doc:GetElementById("btn-blockout-pick-" .. i)
		if pick then
			pick:AddEventListener("mousedown", function(event)
				local open = not B.dropdownOpen[i]
				if open then
					rebuildDropdown(i)
				end
				setDropdownOpen(i, open)
				playSound("dropdown")
				event:StopPropagation()
			end, false)
		end
		wireSlider(i, "yaw", YAW_STEP, function(v)
			return v
		end)
		wireSlider(i, "scale", SCALE_STEP, function(v)
			return v / 100
		end)
	end

	-- window <- WG.Blockout (open, project load, any setLayer); skips a slider being dragged
	B.sync = function()
		local A = api()
		available()
		if not A then
			return
		end
		-- the Map Blockout widget may load after this panel: hook its change event on first use
		if not B.hooked then
			B.hooked = true
			A.onChange("tf_blockout", B.sync)
		end
		uiState.updatingFromCode = true
		for i = 1, LAYERS do
			local l = A.getLayer(i) or {}
			local lbl = doc:GetElementById("lbl-blockout-pick-" .. i)
			if lbl then
				lbl.inner_rml = labelFor(l.def)
			end
			for key, value in pairs({
				yaw = math.floor((l.yaw or 0) + 0.5),
				scale = math.floor((l.scale or 1) * 100 + 0.5),
			}) do
				local id = "slider-blockout-" .. key .. "-" .. i
				local sl = doc:GetElementById(id)
				if sl and uiState.draggingSlider ~= id then
					sl:SetAttribute("value", tostring(value))
				end
				local box = doc:GetElementById(id .. "-numbox")
				if box then
					box:SetAttribute("value", tostring(value))
				end
			end
			if B.dropdownOpen[i] then
				rebuildDropdown(i)
			end
		end
		uiState.updatingFromCode = false
	end

	B.sync()
	if root then
		root:SetClass("hidden", not widgetState.envBlockoutOpen)
	end
end

return M
