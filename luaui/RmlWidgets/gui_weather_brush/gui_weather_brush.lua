if not RmlUi then
	return
end

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Weather Brush UI",
		desc = "RmlUI panel for weather brush library and CEG selection",
		author = "BARb",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true,
	}
end

local MODEL_NAME = "weather_brush_model"
local RML_PATH = "luaui/RmlWidgets/gui_weather_brush/gui_weather_brush.rml"

local WG = WG
local GetViewGeometry = Spring.GetViewGeometry

local INITIAL_LEFT_VW = 60
local INITIAL_TOP_VH = 25

local widgetState = {
	rmlContext = nil,
	document = nil,
	dmHandle = nil,
	rootElement = nil,
	libraryBuilt = false,
	cegListFilter = "",
	cegListBuilt = false,
}

local manuallyHidden = false
local lastActive = false
local userDragged = false  -- once user drags, stop auto-positioning

-- Window drag state (module-level for widget:MouseMove/MouseRelease)
local SNAP_THRESHOLD = 30
local dragState = {
	active = false,
	rootEl = nil,
	offsetX = 0, offsetY = 0,
	ew = 0, eh = 0,
	vsx = 0, vsy = 0,
	lastX = -1, lastY = -1,
}

local function buildRootStyle()
	-- Width lives in RCSS (.wb-root) so it scales with dp_ratio and stays
	-- readable via `min-width: Npx`. We only emit position here.
	return string.format("left: %.2fvw; top: %.2fvh;",
		INITIAL_LEFT_VW, INITIAL_TOP_VH)
end

local initialModel = {}

-- Icon map for weather conditions (unicode weather symbols)
local iconMap = {
	-- Precipitation
	rain_light      = "&#x1F327;",
	rain_heavy      = "&#x26C8;",
	storm           = "&#x26A1;",
	rain_acid       = "&#x2623;",
	snow_light      = "&#x2744;",
	blizzard        = "&#x1F328;",
	hail            = "&#x1F327;",
	-- Wind & Sand
	sandstorm       = "&#x1F32A;",
	dust_devil      = "&#x1F300;",
	-- Fog & Atmosphere
	fog             = "&#x1F32B;",
	mist            = "&#x1F32B;",
	overcast        = "&#x2601;",
	toxic           = "&#x2623;",
	mist_purple     = "&#x1F52E;",
	-- Fire & Volcanic
	volcanic        = "&#x1F30B;",
	embers          = "&#x1F525;",
	lava            = "&#x1F525;",
	steam           = "&#x2668;",
	-- Ambient & Magical
	fireflies       = "&#x2728;",
	fireflies_green = "&#x2728;",
	fireflies_purple= "&#x2728;",
	pollen          = "&#x1F33C;",
	dust_motes      = "&#x2727;",
	-- Storm & Energy
	lightning       = "&#x26A1;",
	lightning_green = "&#x26A1;",
	-- Smoke & Industrial
	smoke           = "&#x1F4A8;",
	nuke            = "&#x2622;",
	-- Special
	meteor          = "&#x2604;",
}

-- Category groups: { label, startIndex, endIndex }
-- These insert visual headers into the library grid to organize presets
local categoryGroups = {
	{ label = "PRECIPITATION", startIdx = 1 },
	{ label = "WIND &amp; SAND", startIdx = 8 },
	{ label = "FOG &amp; ATMOSPHERE", startIdx = 10 },
	{ label = "FIRE &amp; VOLCANIC", startIdx = 15 },
	{ label = "AMBIENT &amp; MAGICAL", startIdx = 19 },
	{ label = "STORM &amp; ENERGY", startIdx = 25 },
	{ label = "SMOKE &amp; INDUSTRIAL", startIdx = 27 },
	{ label = "SPECIAL", startIdx = 29 },
}

-- ===========================================================================
-- Event Listeners
-- ===========================================================================
local function attachEventListeners()
	local doc = widgetState.document
	if not doc then return end

	-- Close button
	local quitBtn = doc:GetElementById("btn-wb-quit")
	if quitBtn then
		quitBtn:AddEventListener("click", function(event)
			manuallyHidden = true
			if widgetState.rootElement then
				widgetState.rootElement:SetClass("hidden", true)
			end
			event:StopPropagation()
		end, false)
	end

	-- CEG filter input
	local cegFilter = doc:GetElementById("wb-ceg-filter")
	if cegFilter then
		cegFilter:AddEventListener("focus", function(event)
			WG.WeatherBrushInputFocused = true
			Spring.SDLStartTextInput()
		end, false)
		cegFilter:AddEventListener("blur", function(event)
			WG.WeatherBrushInputFocused = false
			Spring.SDLStopTextInput()
		end, false)
	end

	local cegClearBtn = doc:GetElementById("btn-wb-ceg-clear")
	if cegClearBtn then
		cegClearBtn:AddEventListener("click", function(event)
			if WG.WeatherBrush then WG.WeatherBrush.clearSelectedCegs() end
			if cegFilter then cegFilter:SetAttribute("value", "") end
			event:StopPropagation()
		end, false)
	end

	-- Drag handle
	local handleEl = doc:GetElementById("wb-handle")
	if handleEl and widgetState.rootElement then
		local rootEl = widgetState.rootElement
		local ds = dragState

		handleEl:AddEventListener("mousedown", function(event)
			local p = event.parameters
			if not p or (p.button and p.button ~= 0) then return end
			local mx, my = Spring.GetMouseState()
			local vsx, vsy = GetViewGeometry()
			ds.active = true
			userDragged = true
			ds.rootEl = rootEl
			ds.offsetX = mx - rootEl.offset_left
			ds.offsetY = (vsx > 0 and vsy > 0) and ((vsy - my) - rootEl.offset_top) or 0
			ds.ew = rootEl.offset_width
			ds.eh = rootEl.offset_height
			ds.vsx = vsx
			ds.vsy = vsy
			ds.lastX = -1
			ds.lastY = -1
			event:StopPropagation()
		end, false)

		doc:AddEventListener("mouseup", function(event)
			if ds.active then
				ds.active = false
				ds.rootEl = nil
			end
		end, false)
	end
end

-- ===========================================================================
-- Initialize / Shutdown
-- ===========================================================================
function widget:Initialize()
	widgetState.rmlContext = RmlUi.GetContext("shared")
	if not widgetState.rmlContext then
		return false
	end

	local dm = widgetState.rmlContext:OpenDataModel(MODEL_NAME, initialModel, self)
	if not dm then
		return false
	end
	widgetState.dmHandle = dm

	local document = widgetState.rmlContext:LoadDocument(RML_PATH)
	if not document then
		widget:Shutdown()
		return false
	end
	widgetState.document = document
	document:Show()

	if WG.RmlContextManager and WG.RmlContextManager.registerDocument then
		WG.RmlContextManager.registerDocument("weather_brush", document)
	end

	widgetState.rootElement = document:GetElementById("wb-root")
	widgetState.rootElement:SetAttribute("style", buildRootStyle())

	attachEventListeners()
end

-- ===========================================================================
-- Update: sync widget state to UI
-- ===========================================================================
function widget:Update()
	-- Poll-based window drag (position only — mouseup ends drag via doc listener)
	local ds = dragState
	if ds.active and ds.rootEl then
		local mx, my = Spring.GetMouseState()
		local vsx, vsy = ds.vsx, ds.vsy
		local ew, eh = ds.ew, ds.eh
		local T = SNAP_THRESHOLD
		local rmlY = vsy - my
		local newX = mx - ds.offsetX
		local newY = rmlY - ds.offsetY

		if newX < 0 then newX = 0
		elseif newX + ew > vsx then newX = vsx - ew end
		if newY < 0 then newY = 0
		elseif newY + eh > vsy then newY = vsy - eh end

		if newX < T then newX = 0
		elseif vsx - newX - ew < T then newX = vsx - ew end
		if newY < T then newY = 0
		elseif vsy - newY - eh < T then newY = vsy - eh end

		-- Snap to terraform main panel
		local mainPanel = WG.RmlContextManager and WG.RmlContextManager.getElementRect
			and WG.RmlContextManager.getElementRect("terraform_brush", "tf-root")
		if mainPanel then
			local ox, oy = mainPanel.left, mainPanel.top
			local oR = ox + (mainPanel.width or 0)
			local oB = oy + (mainPanel.height or 0)
			local newR, newB = newX + ew, newY + eh
			if newY < oB and newB > oy then
				local d = newX - oR
				if d > -T and d < T then newX = oR
				else d = newR - ox
					if d > -T and d < T then newX = ox - ew end
				end
			end
			if newX < oR and newR > ox then
				local d = newY - oB
				if d > -T and d < T then newY = oB
				else d = newB - oy
					if d > -T and d < T then newY = oy - eh end
				end
			end
		end

		local ix = math.floor(newX)
		local iy = math.floor(newY)
		if ix ~= ds.lastX or iy ~= ds.lastY then
			ds.lastX = ix
			ds.lastY = iy
			ds.rootEl.style.left = ix .. "px"
			ds.rootEl.style.top  = iy .. "px"
		end
	end

	local wbState = WG.WeatherBrush and WG.WeatherBrush.getState()
	local wbActive = wbState and wbState.active

	-- Show/hide entire panel
	if wbActive and not lastActive then
		manuallyHidden = false
	end
	lastActive = wbActive
	if widgetState.rootElement then
		widgetState.rootElement:SetClass("hidden", not wbActive or manuallyHidden)
	end
	if not wbActive then return end

	-- Align to the left of the main terraform panel (only if not user-dragged)
	local mainPanel = WG.RmlContextManager and WG.RmlContextManager.getElementRect
		and WG.RmlContextManager.getElementRect("terraform_brush", "tf-root")
	if not userDragged and mainPanel and widgetState.rootElement then
		local myWidth = widgetState.rootElement.offset_width
		if myWidth and myWidth > 0 then
			local gap = 8
			widgetState.rootElement:SetAttribute("style",
				string.format("left: %dpx; top: %dpx;",
					mainPanel.left - myWidth - gap, mainPanel.top))
		end
	end

	local doc = widgetState.document
	if not doc then return end

	-- Selected CEGs label
	local selectedLabel = doc:GetElementById("wb-selected-cegs-label")
	if selectedLabel then
		if #wbState.selectedCegs == 0 then
			selectedLabel.inner_rml = '<span style="color: #6b7280;">none</span>'
		else
			local display = table.concat(wbState.selectedCegs, ", ")
			if #display > 50 then display = display:sub(1, 47) .. "..." end
			selectedLabel.inner_rml = display
		end
	end

	-- Build library grid if not yet done
	if not widgetState.libraryBuilt then
		local libraryGrid = doc:GetElementById("wb-library-grid")
		if libraryGrid and WG.WeatherBrush then
			libraryGrid.inner_rml = ""
			local library = WG.WeatherBrush.getWeatherLibrary()

			-- Build a lookup: presetIndex -> category label
			local categoryAtIdx = {}
			for _, cat in ipairs(categoryGroups) do
				categoryAtIdx[cat.startIdx] = cat.label
			end

			for idx, preset in ipairs(library) do
				-- Insert category header if this index starts a new group
				if categoryAtIdx[idx] then
					local headerEl = doc:CreateElement("div")
					headerEl:SetClass("wb-category-header", true)
					headerEl.inner_rml = categoryAtIdx[idx]
					libraryGrid:AppendChild(headerEl)
				end

				local item = doc:CreateElement("div")
				item:SetClass("wb-library-item", true)

				local iconEl = doc:CreateElement("div")
				iconEl:SetClass("wb-library-item-icon", true)
				iconEl.inner_rml = iconMap[preset.icon] or "&#x2601;"

				local infoEl = doc:CreateElement("div")
				infoEl:SetClass("wb-library-item-info", true)

				local nameEl = doc:CreateElement("div")
				nameEl:SetClass("wb-library-item-name", true)
				nameEl.inner_rml = preset.name

				local descEl = doc:CreateElement("div")
				descEl:SetClass("wb-library-item-desc", true)
				descEl.inner_rml = preset.description

				infoEl:AppendChild(nameEl)
				infoEl:AppendChild(descEl)
				item:AppendChild(iconEl)
				item:AppendChild(infoEl)

				local capturedIdx = idx
				item:AddEventListener("click", function(ev)
					if WG.WeatherBrush then
						WG.WeatherBrush.applyWeatherPreset(capturedIdx)
					end
					ev:StopPropagation()
				end, false)

				libraryGrid:AppendChild(item)
			end
			widgetState.libraryBuilt = true
		end
	end

	-- CEG list: rebuild when filter changes
	local cegFilter = doc:GetElementById("wb-ceg-filter")
	local filter = cegFilter and cegFilter:GetAttribute("value") or ""
	if filter ~= widgetState.cegListFilter or not widgetState.cegListBuilt then
		widgetState.cegListFilter = filter
		widgetState.cegListBuilt = true
		local listEl = doc:GetElementById("wb-ceg-list")
		if listEl and WG.WeatherBrush then
			listEl.inner_rml = ""
			local cegNames = WG.WeatherBrush.getCegNames()
			local filterLower = filter:lower()
			local shown = 0
			local maxShow = 50
			for _, name in ipairs(cegNames) do
				if filterLower == "" or name:lower():find(filterLower, 1, true) then
					shown = shown + 1
					if shown > maxShow then break end
					local item = doc:CreateElement("div")
					item:SetClass("wb-ceg-item", true)
					local isSelected = false
					for _, sel in ipairs(wbState.selectedCegs) do
						if sel == name then isSelected = true; break end
					end
					item:SetClass("selected", isSelected)
					item.inner_rml = name

					local capturedName = name
					item:AddEventListener("click", function(ev)
						if WG.WeatherBrush then
							local alt = Spring.GetModKeyState and select(1, Spring.GetModKeyState()) or false
							if alt then
								WG.WeatherBrush.toggleCeg(capturedName)
							else
								WG.WeatherBrush.selectCeg(capturedName)
							end
							widgetState.cegListBuilt = false
						end
						ev:StopPropagation()
					end, false)
					listEl:AppendChild(item)
				end
			end
			if shown == 0 then
				listEl.inner_rml = '<div style="padding: 4dp 6dp; font-size: 0.9rem; color: #6b7280;">No matching CEGs</div>'
			end
		end
	end
end

function widget:Shutdown()
	WG.WeatherBrushInputFocused = nil

	if WG.RmlContextManager and WG.RmlContextManager.unregisterDocument then
		WG.RmlContextManager.unregisterDocument("weather_brush")
	end

	if widgetState.document then
		widgetState.document:Close()
		widgetState.document = nil
	end

	if widgetState.rmlContext then
		widgetState.rmlContext:RemoveDataModel(MODEL_NAME)
	end

	widgetState.dmHandle = nil
	widgetState.rootElement = nil
	widgetState.libraryBuilt = false
	widgetState.cegListFilter = ""
	widgetState.cegListBuilt = false
end
