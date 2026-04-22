-- tf_environment.lua: extracted tool module for gui_terraform_brush
local M = {}

function M.attach(doc, ctx)
	local widgetState = ctx.widgetState
	local uiState = ctx.uiState
	local WG = ctx.WG
	local playSound = ctx.playSound
	local setActiveClass = ctx.setActiveClass
	local trackSliderDrag = ctx.trackSliderDrag
	local clearPassthrough = ctx.clearPassthrough
	local ROTATION_STEP = ctx.ROTATION_STEP
	local CURVE_STEP = ctx.CURVE_STEP
	local LENGTH_SCALE_STEP = ctx.LENGTH_SCALE_STEP
	local RADIUS_STEP = ctx.RADIUS_STEP
	local sliderToCadence = ctx.sliderToCadence
	local cadenceToSlider = ctx.cadenceToSlider
	local sliderToFrequency = ctx.sliderToFrequency
	local sliderToPersist = ctx.sliderToPersist
	local PERSIST_PERMANENT_VAL = ctx.PERSIST_PERMANENT_VAL
	local formatFrequency = ctx.formatFrequency
	local guideHints = ctx.guideHints
	local shapeNames = ctx.shapeNames
	local skyDynamic = ctx.skyDynamic
	local quatFromAxisAngle = ctx.quatFromAxisAngle

	widgetState.envControlsEl = doc:GetElementById("tf-environment-controls")

	-- Scan for skybox textures and build the thumbnail grid
	local SKYBOX_DIR = "luaui/RmlWidgets/gui_terraform_brush/skyboxes/"
	local skyboxFiles = VFS.DirList(SKYBOX_DIR, "*", VFS.RAW_FIRST) or {}

	-- Separate DDS skybox textures from preview images (jpg/png)
	local ddsFiles = {}      -- { {path, baseLower}, ... }
	local previewFiles = {}  -- baseLower -> path  (jpg/png only)
	for _, fp in ipairs(skyboxFiles) do
		local ext = (fp:match("%.([^%.]+)$") or ""):lower()
		local basename = fp:match("([^/\\]+)%.[^%.]+$") or ""
		local baseLower = basename:lower()
		if ext == "dds" then
			ddsFiles[#ddsFiles + 1] = { path = fp, baseLower = baseLower }
		elseif ext == "jpg" or ext == "jpeg" or ext == "png" then
			previewFiles[baseLower] = fp
		end
	end

	-- Match each DDS to its preview image using fuzzy name matching
	local function findPreview(ddsBase)
		-- Try direct match first (unlikely but cheap)
		if previewFiles[ddsBase] then return previewFiles[ddsBase] end
		-- Try common naming: "Name - Preview", "Name Reflections"
		for key, path in pairs(previewFiles) do
			local stripped = key:gsub("%s*%-%s*preview$", ""):gsub("%s*reflections$", "")
			local ddsStripped = ddsBase:gsub("_skybox", ""):gsub("skybox", "")
			-- Check if either name starts with the other's prefix (at least 6 chars)
			if #stripped >= 6 and (ddsBase:find(stripped:sub(1, math.min(#stripped, 12)), 1, true)
				or stripped:find(ddsBase:sub(1, math.min(#ddsBase, 12)), 1, true)) then
				return path
			end
			if #ddsStripped >= 4 and (key:find(ddsStripped:sub(1, math.min(#ddsStripped, 10)), 1, true)
				or ddsStripped:find(stripped:sub(1, math.min(#stripped, 10)), 1, true)) then
				return path
			end
		end
		return nil
	end

	local gridEl = doc:GetElementById("env-skybox-grid")
	if gridEl then
		-- Store DDS paths for deferred pre-loading in DrawScreen
		-- (gl.Texture cannot be called in Initialize, only in Draw call-ins)
		for _, dds in ipairs(ddsFiles) do
			widgetState.envLoadedTextures[#widgetState.envLoadedTextures + 1] = dds.path
		end
		widgetState.envTexturesPreloaded = false

		for _, dds in ipairs(ddsFiles) do
			local previewPath = findPreview(dds.baseLower)
			local ddsPath = dds.path
			local displayName = dds.path:match("([^/\\]+)%.%w+$") or dds.path

			local thumbDiv = doc:CreateElement("div")
			thumbDiv:SetClass("env-skybox-thumb", true)
			thumbDiv:SetAttribute("title", displayName)

			if previewPath then
				local img = doc:CreateElement("img")
				img:SetAttribute("src", "/" .. previewPath)
				thumbDiv:AppendChild(img)
			end

			local label = doc:CreateElement("div")
			label:SetClass("env-skybox-name", true)
			label.inner_rml = displayName
			thumbDiv:AppendChild(label)

			thumbDiv:AddEventListener("click", function(event)
				local normalized = ddsPath:gsub("\\", "/")
				widgetState.applySkybox(normalized)
				widgetState.envCurrentSkybox = normalized
				for _, t in ipairs(widgetState.envSkyboxThumbs) do
					t.element:SetClass("active", t.path == ddsPath)
				end
				event:StopPropagation()
			end, false)

			gridEl:AppendChild(thumbDiv)
			widgetState.envSkyboxThumbs[#widgetState.envSkyboxThumbs + 1] = { element = thumbDiv, path = ddsPath }
		end

		if #ddsFiles == 0 then
			gridEl.inner_rml = '<div class="text-sm text-keybind" style="padding: 16dp; text-align: center; font-size: 1rem; line-height: 1.5;">'
				.. 'No skybox textures found.<br/>'
				.. 'Get skyboxes from the Discord <span style="color: #fbbf24;">#mapping</span> channel pins and place them in:<br/>'
				.. '<span style="color: #9ca3af;">luaui/RmlWidgets/gui_terraform_brush/skyboxes/</span>'
				.. '</div>'
		end
	end

	-- Reset skybox button
	local resetSkyboxBtn = doc:GetElementById("btn-env-reset-skybox")
	if resetSkyboxBtn then
		resetSkyboxBtn:AddEventListener("click", function(event)
			local resetPath = widgetState.envDefaultSkybox or ""
			widgetState.applySkybox(resetPath)
			widgetState.envCurrentSkybox = nil
			for _, t in ipairs(widgetState.envSkyboxThumbs) do
				t.element:SetClass("active", false)
			end
			event:StopPropagation()
		end, false)
	end

	-- Fade transition toggle
	local fadeToggleBtn = doc:GetElementById("btn-env-fade-toggle")
	if fadeToggleBtn then
		fadeToggleBtn:AddEventListener("click", function(event)
			widgetState.envFadeEnabled = not widgetState.envFadeEnabled
			playSound(widgetState.envFadeEnabled and "toggleOn" or "toggleOff")
			fadeToggleBtn:SetAttribute("src",
				widgetState.envFadeEnabled
				and "/luaui/images/terraform_brush/check_on.png"
				or  "/luaui/images/terraform_brush/check_off.png")
			event:StopPropagation()
		end, false)
	end

		-- Environment sub-windows
		-- Capture map defaults at startup
		local sunX, sunY, sunZ = gl.GetSun("pos")
		sunX, sunY, sunZ = sunX or 0, sunY or 1, sunZ or 0
		local gaR, gaG, gaB = gl.GetSun("ambient")
		gaR, gaG, gaB = gaR or 0, gaG or 0, gaB or 0
		local gdR, gdG, gdB = gl.GetSun("diffuse")
		gdR, gdG, gdB = gdR or 0, gdG or 0, gdB or 0
		local gsR, gsG, gsB = gl.GetSun("specular")
		gsR, gsG, gsB = gsR or 0, gsG or 0, gsB or 0
		local uaR, uaG, uaB = gl.GetSun("ambient", "unit")
		uaR, uaG, uaB = uaR or 0, uaG or 0, uaB or 0
		local udR, udG, udB = gl.GetSun("diffuse", "unit")
		udR, udG, udB = udR or 0, udG or 0, udB or 0
		local usR, usG, usB = gl.GetSun("specular", "unit")
		usR, usG, usB = usR or 0, usG or 0, usB or 0
		local fogS = gl.GetAtmosphere("fogStart")
		local fogE = gl.GetAtmosphere("fogEnd")
		local fR, fG, fB, fA = gl.GetAtmosphere("fogColor")
		local scR, scG, scB = gl.GetAtmosphere("sunColor")
		local skR, skG, skB = gl.GetAtmosphere("skyColor")
		local saX, saY, saZ, saAngle = gl.GetAtmosphere("skyAxisAngle")
		local gsd = gl.GetSun("shadowDensity", "ground") or 0
		local usd = gl.GetSun("shadowDensity", "unit") or 0

		widgetState.envDefaults = {
			sunPos = { sunX, sunY, sunZ },
			groundAmbient = { gaR, gaG, gaB },
			groundDiffuse = { gdR, gdG, gdB },
			groundSpecular = { gsR, gsG, gsB },
			unitAmbient = { uaR, uaG, uaB },
			unitDiffuse = { udR, udG, udB },
			unitSpecular = { usR, usG, usB },
			fogStart = fogS,
			fogEnd = fogE,
			fogColor = { fR, fG, fB, fA },
			sunColor = { scR, scG, scB },
			skyColor = { skR, skG, skB },
			skyAxisAngle = { saX, saY, saZ, saAngle },
			groundShadowDensity = gsd,
			unitShadowDensity = usd,
			cloudColor = { gl.GetAtmosphere("cloudColor") },
			sunIntensity = 1.0,
			waterAbsorb = { gl.GetWaterRendering("absorb") },
			waterBaseColor = { gl.GetWaterRendering("baseColor") },
			waterMinColor = { gl.GetWaterRendering("minColor") },
			waterSurfaceColor = { gl.GetWaterRendering("surfaceColor") },
			waterPlaneColor = { gl.GetWaterRendering("planeColor") },
			waterDiffuseColor = { gl.GetWaterRendering("diffuseColor") },
			waterSpecularColor = { gl.GetWaterRendering("specularColor") },
		}

		-- Grab floating window root elements
		widgetState.envSunRootEl = doc:GetElementById("tf-env-sun-root")
		widgetState.envFogRootEl = doc:GetElementById("tf-env-fog-root")
		widgetState.envGroundLightingRootEl = doc:GetElementById("tf-env-ground-lighting-root")
		widgetState.envUnitLightingRootEl = doc:GetElementById("tf-env-unit-lighting-root")
		widgetState.envMapRootEl = doc:GetElementById("tf-env-map-root")
		widgetState.envWaterRootEl = doc:GetElementById("tf-env-water-root")
		widgetState.envDimensionsRootEl = doc:GetElementById("tf-env-dimensions-root")
		widgetState.splatTexRootEl = doc:GetElementById("tf-splattex-root")

		-- Helper: wire a slider that maps integer range to float values
		local function envSlider(sliderId, labelId, toFloat, fromFloat, onChange)
			local sl = doc:GetElementById(sliderId)
			local lb = doc:GetElementById(labelId)
			if not sl then return end
			trackSliderDrag(sl, sliderId)
			sl:AddEventListener("change", function(event)
				if uiState.updatingFromCode then return end
				local raw = tonumber(sl:GetAttribute("value")) or 0
				local val = toFloat(raw)
				if lb then lb.inner_rml = string.format("%.2f", val) end
				onChange(val)
				event:StopPropagation()
			end, false)
			-- Set initial value
			local initVal = fromFloat()
			sl:SetAttribute("value", tostring(math.floor(initVal + 0.5)))
			if lb then lb.inner_rml = string.format("%.2f", toFloat(math.floor(initVal + 0.5))) end
		end

		-- Helper: set slider + label from code
		local function envSetSlider(sliderId, labelId, intVal, displayVal)
			local sl = doc:GetElementById(sliderId)
			local lb = doc:GetElementById(labelId)
			if sl then sl:SetAttribute("value", tostring(intVal)) end
			if lb then lb.inner_rml = displayVal end
		end

		-- Helper: update a preview box's background-color from RGB (0-1 range)
		local function updatePreview(previewEl, r, g, b)
			if not previewEl then return end
			local ri = math.floor(math.min(math.max(r or 0, 0), 1) * 255 + 0.5)
			local gi = math.floor(math.min(math.max(g or 0, 0), 1) * 255 + 0.5)
			local bi = math.floor(math.min(math.max(b or 0, 0), 1) * 255 + 0.5)
			previewEl:SetAttribute("style", string.format("background-color: rgb(%d, %d, %d);", ri, gi, bi))
		end

		-- Helper: wire palette swatches + color preview for a color group
		-- cfg = { paletteId, previewId, sliderPrefix, channels, getColor, setColor }
		local function wireColorGroup(cfg)
			local previewEl = doc:GetElementById(cfg.previewId)
			local paletteEl = cfg.paletteId and doc:GetElementById(cfg.paletteId)
			local channels = cfg.channels or {"r", "g", "b"}
			local function refreshPreview()
				local c = cfg.getColor()
				updatePreview(previewEl, c[1], c[2], c[3])
			end
			for _, s in ipairs(channels) do
				local sl = doc:GetElementById("slider-env-" .. cfg.sliderPrefix .. "-" .. s)
				if sl then sl:AddEventListener("change", function() refreshPreview() end, false) end
			end
			if paletteEl then
				local idx = 0
				while true do
					local swatch = paletteEl:GetChild(idx)
					if not swatch then break end
					local style = swatch:GetAttribute("style") or ""
					local hex = style:match("#(%x%x%x%x%x%x)")
					if hex then
						local hr = tonumber(hex:sub(1, 2), 16) / 255
						local hg = tonumber(hex:sub(3, 4), 16) / 255
						local hb = tonumber(hex:sub(5, 6), 16) / 255
						swatch:AddEventListener("click", function(event)
							cfg.setColor({ hr, hg, hb })
							envSetSlider("slider-env-" .. cfg.sliderPrefix .. "-r", "lbl-env-" .. cfg.sliderPrefix .. "-r",
								math.floor(hr * 1000 + 0.5), string.format("%.2f", hr))
							envSetSlider("slider-env-" .. cfg.sliderPrefix .. "-g", "lbl-env-" .. cfg.sliderPrefix .. "-g",
								math.floor(hg * 1000 + 0.5), string.format("%.2f", hg))
							envSetSlider("slider-env-" .. cfg.sliderPrefix .. "-b", "lbl-env-" .. cfg.sliderPrefix .. "-b",
								math.floor(hb * 1000 + 0.5), string.format("%.2f", hb))
							refreshPreview()
							event:StopPropagation()
						end, false)
					end
					idx = idx + 1
				end
			end
			refreshPreview()
		end

		-- Helper: wire a checkbox toggle
		local function envCheckbox(btnId, initVal, onChange)
			local btn = doc:GetElementById(btnId)
			if not btn then return end
			local state = initVal
			btn:SetAttribute("src", state
				and "/luaui/images/terraform_brush/check_on.png"
				or  "/luaui/images/terraform_brush/check_off.png")
			btn:AddEventListener("click", function(event)
				state = not state
				btn:SetAttribute("src", state
					and "/luaui/images/terraform_brush/check_on.png"
					or  "/luaui/images/terraform_brush/check_off.png")
				onChange(state)
				event:StopPropagation()
			end, false)
		end

		-- Helper: wire a window toggle button + close button
		local function envWindowToggle(openBtnId, closeBtnId, rootEl, stateKey)
			local openBtn = doc:GetElementById(openBtnId)
			if openBtn then
				openBtn:AddEventListener("click", function(event)
					widgetState[stateKey] = not widgetState[stateKey]
					playSound(widgetState[stateKey] and "panelOpen" or "click")
					if rootEl then rootEl:SetClass("hidden", not widgetState[stateKey]) end
					openBtn:SetClass("env-open", widgetState[stateKey] == true)
					event:StopPropagation()
				end, false)
			end
			local closeBtn = doc:GetElementById(closeBtnId)
			if closeBtn then
				closeBtn:AddEventListener("click", function(event)
					playSound("click")
					widgetState[stateKey] = false
					if rootEl then rootEl:SetClass("hidden", true) end
					if openBtn then openBtn:SetClass("env-open", false) end
					event:StopPropagation()
				end, false)
			end
		end

		-- Wire toggle/close for each sub-window
		envWindowToggle("btn-env-sun-shadows", "btn-env-sun-close", widgetState.envSunRootEl, "envSunOpen")
		envWindowToggle("btn-env-fog-atmo", "btn-env-fog-close", widgetState.envFogRootEl, "envFogOpen")
		envWindowToggle("btn-env-ground-lighting", "btn-env-ground-lighting-close", widgetState.envGroundLightingRootEl, "envGroundLightingOpen")
		envWindowToggle("btn-env-unit-lighting", "btn-env-unit-lighting-close", widgetState.envUnitLightingRootEl, "envUnitLightingOpen")
		envWindowToggle("btn-env-map-render", "btn-env-map-close", widgetState.envMapRootEl, "envMapOpen")
		envWindowToggle("btn-env-water", "btn-env-water-close", widgetState.envWaterRootEl, "envWaterOpen")
		envWindowToggle("btn-env-dimensions", "btn-env-dimensions-close", widgetState.envDimensionsRootEl, "envDimensionsOpen")
		envWindowToggle("btn-sp-splattex", "btn-splattex-close", widgetState.splatTexRootEl, "splatTexOpen")

		-- Helper: wire a collapsible section toggle (click header row to expand/collapse)
		-- Returns a ctrl table with an expand() method for programmatic expansion.
		local function envSectionToggle(toggleBtnId, toggleImgId, sectionId, defaultExpanded)
			local toggleBtn = doc:GetElementById(toggleBtnId)
			local toggleImg = doc:GetElementById(toggleImgId)
			local section = doc:GetElementById(sectionId)
			if not toggleBtn or not toggleImg or not section then return {} end
			local expanded = defaultExpanded
			section:SetClass("hidden", not expanded)
			toggleImg:SetAttribute("src", expanded
				and "/luaui/images/terraform_brush/minus.png"
				or  "/luaui/images/terraform_brush/plus.png")
			toggleBtn:AddEventListener("click", function(event)
				expanded = not expanded
				playSound(expanded and "panelOpen" or "click")
				section:SetClass("hidden", not expanded)
				toggleImg:SetAttribute("src", expanded
					and "/luaui/images/terraform_brush/minus.png"
					or  "/luaui/images/terraform_brush/plus.png")
				event:StopPropagation()
			end, false)
			return {
				expand = function()
					if not expanded then
						expanded = true
						playSound("panelOpen")
						section:SetClass("hidden", false)
						toggleImg:SetAttribute("src", "/luaui/images/terraform_brush/minus.png")
					end
				end,
			}
		end

		-- Terrain panel collapsible sections (default collapsed)
		envSectionToggle("btn-toggle-terrain",  "img-toggle-terrain",  "section-terrain",  true)
		envSectionToggle("btn-toggle-tools",    "img-toggle-tools",    "section-tools",    true)
		envSectionToggle("btn-toggle-shape",    "img-toggle-shape",    "section-shape",    true)
		envSectionToggle("btn-toggle-sliders",  "img-toggle-sliders",  "section-sliders",  true)
		widgetState.heightCapSectionCtrl = envSectionToggle("btn-toggle-heightcap", "img-toggle-heightcap", "section-heightcap", false)
		envSectionToggle("btn-toggle-presets",   "img-toggle-presets",   "section-presets",   false)

		-- Tool sub-panel collapsible sections
		envSectionToggle("btn-toggle-sp-mode",      "img-toggle-sp-mode",      "section-sp-mode",      true)
		envSectionToggle("btn-toggle-mb-mode",      "img-toggle-mb-mode",      "section-mb-mode",      true)
		envSectionToggle("btn-toggle-mb-undo",      "img-toggle-mb-undo",      "section-mb-undo",      false)
		envSectionToggle("btn-toggle-gb-mode",      "img-toggle-gb-mode",      "section-gb-mode",      true)
		envSectionToggle("btn-toggle-gb-shape",     "img-toggle-gb-shape",     "section-gb-shape",     true)
		envSectionToggle("btn-toggle-gb-undo",      "img-toggle-gb-undo",      "section-gb-undo",      false)
		envSectionToggle("btn-toggle-fp-mode",      "img-toggle-fp-mode",      "section-fp-mode",      true)
		envSectionToggle("btn-toggle-smooth-mode",  "img-toggle-smooth-mode",  "section-smooth-mode",  true)
		envSectionToggle("btn-toggle-fp-undo",      "img-toggle-fp-undo",      "section-fp-undo",      false)
		envSectionToggle("btn-toggle-fp-dist",      "img-toggle-fp-dist",      "section-fp-dist",      true)
		envSectionToggle("btn-toggle-fp-save",      "img-toggle-fp-save",      "section-fp-save",      false)
		envSectionToggle("btn-toggle-ramp-type",    "img-toggle-ramp-type",    "section-ramp-type",    true)
		envSectionToggle("btn-toggle-wb-mode",      "img-toggle-wb-mode",      "section-wb-mode",      true)
		envSectionToggle("btn-toggle-wb-dist",      "img-toggle-wb-dist",      "section-wb-dist",      true)
		envSectionToggle("btn-toggle-cl-undo",      "img-toggle-cl-undo",      "section-cl-undo",      false)
		envSectionToggle("btn-toggle-tf-undo",      "img-toggle-tf-undo",      "section-tf-undo",      false)
		envSectionToggle("btn-toggle-spl-channel",  "img-toggle-spl-channel",  "section-spl-channel",  true)
		envSectionToggle("btn-toggle-dc-saveload",  "img-toggle-dc-saveload",  "section-dc-saveload",  false)
		envSectionToggle("btn-toggle-dc-dist",      "img-toggle-dc-dist",      "section-dc-dist",      true)
		envSectionToggle("btn-toggle-dc-mode",      "img-toggle-dc-mode",      "section-dc-mode",      true)
		envSectionToggle("btn-toggle-dc-undo",      "img-toggle-dc-undo",      "section-dc-undo",      false)

		-- New: DISPLAY / INSTRUMENTS / CONTROLS collapsible wrappers per panel
		envSectionToggle("btn-toggle-mb-overlays",     "img-toggle-mb-overlays",     "section-mb-overlays",     false)
		envSectionToggle("btn-toggle-mb-instruments",  "img-toggle-mb-instruments",  "section-mb-instruments",  false)
		envSectionToggle("btn-toggle-mb-controls",     "img-toggle-mb-controls",     "section-mb-controls",     true)
		envSectionToggle("btn-toggle-gb-overlays",     "img-toggle-gb-overlays",     "section-gb-overlays",     false)
		envSectionToggle("btn-toggle-gb-instruments",  "img-toggle-gb-instruments",  "section-gb-instruments",  false)
		envSectionToggle("btn-toggle-gb-controls",     "img-toggle-gb-controls",     "section-gb-controls",     true)
		envSectionToggle("btn-toggle-fp-overlays",     "img-toggle-fp-overlays",     "section-fp-overlays",     false)
		envSectionToggle("btn-toggle-fp-instruments",  "img-toggle-fp-instruments",  "section-fp-instruments",  false)
		envSectionToggle("btn-toggle-fp-controls",     "img-toggle-fp-controls",     "section-fp-controls",     true)
		envSectionToggle("btn-toggle-fp-smart",        "img-toggle-fp-smart",        "section-fp-smart",        false)
		envSectionToggle("btn-toggle-gb-smart",        "img-toggle-gb-smart",        "section-gb-smart",        false)
		envSectionToggle("btn-toggle-sp-overlays",     "img-toggle-sp-overlays",     "section-sp-overlays",     false)
		do
			local spOvBtn = doc:GetElementById("btn-toggle-sp-overlays")
			if spOvBtn then
				spOvBtn:AddEventListener("click", function()
					local sec = doc:GetElementById("section-sp-overlays")
					if sec and not sec:IsClassSet("hidden") then
						widgetState.splatDisplayPulseFrame = Spring.GetGameFrame() + 1
						if widgetState.uiPrefs and not widgetState.uiPrefs.seenSplatDisplayHint then
							widgetState.uiPrefs.seenSplatDisplayHint = true
							if widgetState.saveUiPrefs then widgetState.saveUiPrefs() end
						end
					end
				end, false)
			end
		end
		envSectionToggle("btn-toggle-sp-instruments",  "img-toggle-sp-instruments",  "section-sp-instruments",  false)
		envSectionToggle("btn-toggle-sp-controls",     "img-toggle-sp-controls",     "section-sp-controls",     true)
		envSectionToggle("btn-toggle-sp-smart",        "img-toggle-sp-smart",        "section-sp-smart",        false)

		-- Pill-button tab switching for smart filter sub-panels
		do
			-- Independent toggle pills for feature placer (both can be active)
			local function wireIndependentPills(pills, onActivate)
				for _, p in ipairs(pills) do
					local btn = doc:GetElementById(p.btnId)
					local content = doc:GetElementById(p.contentId)
					if btn and content then
						btn:AddEventListener("click", function()
							local isActive = btn:IsClassSet("active")
							btn:SetClass("active", not isActive)
							content:SetClass("hidden", isActive)
							if not isActive and onActivate then onActivate() end
						end)
					end
				end
			end
			wireIndependentPills({
				{ btnId = "fp-filter-chip-slope",    contentId = "fp-smart-slope-content" },
				{ btnId = "fp-filter-chip-altitude",  contentId = "fp-smart-altitude-content" },
			}, function()
				if WG.FeaturePlacer then WG.FeaturePlacer.setSmartEnabled(true) end
			end)
			wireIndependentPills({
				{ btnId = "sp-filter-chip-slope",    contentId = "sp-smart-slope-content" },
				{ btnId = "sp-filter-chip-altitude", contentId = "sp-smart-altitude-content" },
			}, function()
				if WG.SplatPainter then WG.SplatPainter.setSmartEnabled(true) end
			end)

			-- Exclusive tab pills for grass brush (original behavior)
			local function wirePillTabs(pills, onActivate)
				for _, p in ipairs(pills) do
					local btn = doc:GetElementById(p.btnId)
					local content = doc:GetElementById(p.contentId)
					if btn and content then
						btn:AddEventListener("click", function()
							for _, q in ipairs(pills) do
								local b2 = doc:GetElementById(q.btnId)
								local c2 = doc:GetElementById(q.contentId)
								if b2 then b2:SetClass("active", b2 == btn) end
								if c2 then c2:SetClass("hidden", c2 ~= content) end
							end
							content:SetClass("hidden", false)
							btn:SetClass("active", true)
							if onActivate then onActivate() end
						end)
					end
				end
			end
			-- Independent toggle pills for grass brush (matches FP pattern).
			-- Slope/Altitude chips enable/disable their sub-filters on toggle; Color chip = texFilterEnabled.
			do
				local function wireGbFilterChip(btnId, contentId, filterKeys, defaultKey)
					local btn = doc:GetElementById(btnId)
					local content = doc:GetElementById(contentId)
					if not btn or not content then return end
					btn:AddEventListener("click", function()
						local isActive = btn:IsClassSet("active")
						local newActive = not isActive
						btn:SetClass("active", newActive)
						content:SetClass("hidden", not newActive)
						if WG.GrassBrush then
							if newActive then
								WG.GrassBrush.setSmartEnabled(true)
								-- Enable the default sub-filter so the category is actually doing something
								if defaultKey then WG.GrassBrush.setSmartFilter(defaultKey, true) end
							else
								-- Deactivating the chip disables all sub-filters in this category
								for _, k in ipairs(filterKeys) do
									WG.GrassBrush.setSmartFilter(k, false)
								end
							end
						end
					end)
				end
				wireGbFilterChip("btn-gb-pill-slope",    "gb-smart-slope-content",
					{ "avoidCliffs", "preferSlopes" }, "avoidCliffs")
				wireGbFilterChip("btn-gb-pill-altitude", "gb-smart-altitude-content",
					{ "altMinEnable", "altMaxEnable" }, "altMinEnable")
			end
			do
				local colorChip = doc:GetElementById("btn-gb-pill-color")
				if colorChip then
					colorChip:AddEventListener("click", function()
						if WG.GrassBrush then
							local on = WG.GrassBrush.getState().texFilterEnabled
							WG.GrassBrush.setTexFilterEnabled(not on)
						end
					end)
				end
			end
		end
		envSectionToggle("btn-toggle-wb-undo",         "img-toggle-wb-undo",         "section-wb-undo",         false)
		envSectionToggle("btn-toggle-wb-overlays",     "img-toggle-wb-overlays",     "section-wb-overlays",     false)
		envSectionToggle("btn-toggle-wb-instruments",  "img-toggle-wb-instruments",  "section-wb-instruments",  false)
		envSectionToggle("btn-toggle-wb-controls",     "img-toggle-wb-controls",     "section-wb-controls",     true)
		envSectionToggle("btn-toggle-sp-undo",         "img-toggle-sp-undo",         "section-sp-undo",         false)
		envSectionToggle("btn-toggle-sp-instruments",  "img-toggle-sp-instruments",  "section-sp-instruments",  false)
		envSectionToggle("btn-toggle-sp-controls",     "img-toggle-sp-controls",     "section-sp-controls",     true)
		envSectionToggle("btn-toggle-dc-overlays",     "img-toggle-dc-overlays",     "section-dc-overlays",     false)
		envSectionToggle("btn-toggle-dc-instruments",  "img-toggle-dc-instruments",  "section-dc-instruments",  false)
		envSectionToggle("btn-toggle-dc-controls",     "img-toggle-dc-controls",     "section-dc-controls",     true)
		envSectionToggle("btn-toggle-lp-overlays",     "img-toggle-lp-overlays",     "section-lp-overlays",     false)
		envSectionToggle("btn-toggle-lp-instruments",  "img-toggle-lp-instruments",  "section-lp-instruments",  false)
		envSectionToggle("btn-toggle-lt-type",         "img-toggle-lt-type",         "section-lt-type",         true)
		envSectionToggle("btn-toggle-lt-placement",    "img-toggle-lt-placement",    "section-lt-placement",    true)
		envSectionToggle("btn-toggle-lt-dist",         "img-toggle-lt-dist",         "section-lt-dist",         true)
		envSectionToggle("btn-toggle-lp-controls",     "img-toggle-lp-controls",     "section-lp-controls",     true)
		envSectionToggle("btn-toggle-lp-undo",         "img-toggle-lp-undo",         "section-lp-undo",         false)
		envSectionToggle("btn-toggle-lp-color",        "img-toggle-lp-color",        "section-lp-color",        true)
		envSectionToggle("btn-toggle-lp-saveload",     "img-toggle-lp-saveload",     "section-lp-saveload",     false)
		envSectionToggle("btn-toggle-cl-instruments",  "img-toggle-cl-instruments",  "section-cl-instruments",  false)
		envSectionToggle("btn-toggle-cl-controls",     "img-toggle-cl-controls",     "section-cl-controls",     true)
		envSectionToggle("btn-toggle-st-overlays",     "img-toggle-st-overlays",     "section-st-overlays",     false)
		envSectionToggle("btn-toggle-st-instruments",  "img-toggle-st-instruments",  "section-st-instruments",  false)
		envSectionToggle("btn-toggle-st-controls",     "img-toggle-st-controls",     "section-st-controls",     true)
		envSectionToggle("btn-toggle-env-buttons",  "img-toggle-env-buttons",  "section-env-buttons",  true)
		envSectionToggle("btn-toggle-lt-type",      "img-toggle-lt-type",      "section-lt-type",      true)
		envSectionToggle("btn-toggle-lt-placement", "img-toggle-lt-placement", "section-lt-placement", true)
		envSectionToggle("btn-toggle-lt-dist",      "img-toggle-lt-dist",      "section-lt-dist",      true)
		envSectionToggle("btn-toggle-lp-color",     "img-toggle-lp-color",     "section-lp-color",     true)
		envSectionToggle("btn-toggle-lp-undo",      "img-toggle-lp-undo",      "section-lp-undo",      false)
		envSectionToggle("btn-toggle-noise-type",   "img-toggle-noise-type",   "section-noise-type",   true)

		-- Parameter chip toggles — toggle individual slider row visibility
		-- Uses table field instead of local function to avoid the 200-local limit
		widgetState.chipToggle = function(chipId, rowId, defaultVis)
			local chip = doc:GetElementById(chipId)
			local row  = doc:GetElementById(rowId)
			if not chip or not row then return end
			local visible = defaultVis ~= false
			chip:SetClass("active", visible)
			row:SetClass("hidden", not visible)
			chip:AddEventListener("click", function(event)
				visible = not visible
				chip:SetClass("active", visible)
				row:SetClass("hidden", not visible)
				playSound(visible and "panelOpen" or "click")
				event:StopPropagation()
			end, false)
		end
		widgetState.chipToggle("param-chip-rotation",  "param-rotation-row",  true)
		widgetState.chipToggle("param-chip-intensity", "param-intensity-row", true)
		widgetState.chipToggle("param-chip-size",      "param-size-row",      true)
		widgetState.chipToggle("param-chip-length",    "param-length-row",    true)
		widgetState.chipToggle("param-chip-falloff",   "param-falloff-row",   true)

		-- Feature placer control pill toggles
		widgetState.chipToggle("fp-param-chip-size",      "fp-param-size-row",      true)
		widgetState.chipToggle("fp-param-chip-rotation",  "fp-param-rotation-row",  true)
		widgetState.chipToggle("fp-param-chip-alignment", "fp-param-alignment-row", true)
		widgetState.chipToggle("fp-param-chip-count",     "fp-param-count-row",     true)
		widgetState.chipToggle("fp-param-chip-rate",      "fp-param-rate-row",      true)

		-- Collapsible toggle with warning chip: shown when collapsed but any listed chip is active.
		-- Uses table field to avoid the 200-local chunk limit.
		widgetState.warningToggle = function(toggleId, imgId, sectionId, warnId, activeIds, defaultExpanded)
			local toggleBtn = doc:GetElementById(toggleId)
			local toggleImg = doc:GetElementById(imgId)
			local section   = doc:GetElementById(sectionId)
			local warnChip  = doc:GetElementById(warnId)
			if not toggleBtn or not toggleImg or not section or not warnChip then return end
			local expanded = defaultExpanded ~= false
			local function refreshWarn()
				if expanded then warnChip:SetClass("hidden", true); return end
				local anyActive = false
				for i = 1, #activeIds do
					local chip = doc:GetElementById(activeIds[i])
					if chip and chip.class_name and chip.class_name:find("active") then anyActive = true; break end
				end
				warnChip:SetClass("hidden", not anyActive)
			end
			if not widgetState.warnRefreshFuncs then widgetState.warnRefreshFuncs = {} end
			widgetState.warnRefreshFuncs[#widgetState.warnRefreshFuncs + 1] = refreshWarn
			local function setExpanded(v)
				expanded = v
				section:SetClass("hidden", not expanded)
				toggleImg:SetAttribute("src", expanded
					and "/luaui/images/terraform_brush/minus.png"
					or  "/luaui/images/terraform_brush/plus.png")
				refreshWarn()
			end
			setExpanded(expanded)
			toggleBtn:AddEventListener("click", function(event)
				setExpanded(not expanded)
				playSound(expanded and "panelOpen" or "click")
				event:StopPropagation()
			end, false)
			warnChip:AddEventListener("click", function(event)
				event:StopPropagation()
			end, false)
		end
		widgetState.warningToggle("btn-toggle-overlays",    "img-toggle-overlays",    "section-overlays",    "warn-chip-overlays",    {"btn-grid-overlay","btn-height-colormap"}, false)
		widgetState.warningToggle("btn-toggle-instruments", "img-toggle-instruments", "section-instruments", "warn-chip-instruments", {"btn-grid-snap","btn-angle-snap","btn-measure","btn-symmetry"}, false)
		do
			local instBtn = doc:GetElementById("btn-toggle-instruments")
			if instBtn then
				instBtn:AddEventListener("click", function()
					local sec = doc:GetElementById("section-instruments")
					if sec and not sec:IsClassSet("hidden") then
						widgetState.instrumentsPulseFrame = Spring.GetGameFrame() + 1
						if widgetState.uiPrefs and not widgetState.uiPrefs.seenInstrumentsHint then
							widgetState.uiPrefs.seenInstrumentsHint = true
							if widgetState.saveUiPrefs then widgetState.saveUiPrefs() end
						end
					end
				end, false)
			end
		end

		-- Skybox Library collapsible sections (default collapsed)
		envSectionToggle("btn-env-toggle-skyrot",   "img-env-toggle-skyrot",   "env-section-skyrot",   false)
		envSectionToggle("btn-env-toggle-skydyn",   "img-env-toggle-skydyn",   "env-section-skydyn",   false)

		-- Sun & Shadows collapsible sections (default expanded)
		envSectionToggle("btn-env-toggle-sundir",   "img-env-toggle-sundir",   "env-section-sundir",   true)
		envSectionToggle("btn-env-toggle-sunint",   "img-env-toggle-sunint",   "env-section-sunint",   true)
		envSectionToggle("btn-env-toggle-shadow",   "img-env-toggle-shadow",   "env-section-shadow",   true)

		-- Fog & Atmosphere collapsible sections (default collapsed)
		envSectionToggle("btn-env-toggle-fogdist",  "img-env-toggle-fogdist",  "env-section-fogdist",  true)
		envSectionToggle("btn-env-toggle-fogcol",   "img-env-toggle-fogcol",   "env-section-fogcol",   true)
		envSectionToggle("btn-env-toggle-suncol",   "img-env-toggle-suncol",   "env-section-suncol",   false)
		envSectionToggle("btn-env-toggle-skycol",   "img-env-toggle-skycol",   "env-section-skycol",   false)
		envSectionToggle("btn-env-toggle-cloudcol", "img-env-toggle-cloudcol", "env-section-cloudcol", false)

		-- Ground Lighting collapsible sections (default expanded)
		envSectionToggle("btn-env-toggle-gambient",  "img-env-toggle-gambient",  "env-section-gambient",  true)
		envSectionToggle("btn-env-toggle-gdiffuse",  "img-env-toggle-gdiffuse",  "env-section-gdiffuse",  true)
		envSectionToggle("btn-env-toggle-gspecular", "img-env-toggle-gspecular", "env-section-gspecular", true)

		-- Unit Lighting collapsible sections (default expanded)
		envSectionToggle("btn-env-toggle-uambient",  "img-env-toggle-uambient",  "env-section-uambient",  true)
		envSectionToggle("btn-env-toggle-udiffuse",  "img-env-toggle-udiffuse",  "env-section-udiffuse",  true)
		envSectionToggle("btn-env-toggle-uspecular", "img-env-toggle-uspecular", "env-section-uspecular", true)

		-- Map Rendering collapsible sections (default expanded)
		envSectionToggle("btn-env-toggle-rendertoggle", "img-env-toggle-rendertoggle", "env-section-rendertoggle", true)
		envSectionToggle("btn-env-toggle-deferred",     "img-env-toggle-deferred",     "env-section-deferred",     true)
		envSectionToggle("btn-env-toggle-mapparams",    "img-env-toggle-mapparams",    "env-section-mapparams",    true)

		-- Water collapsible sections (default collapsed)
		envSectionToggle("btn-env-toggle-wtoggle",  "img-env-toggle-wtoggle",  "env-section-wtoggle",  true)
		envSectionToggle("btn-env-toggle-wcolors",  "img-env-toggle-wcolors",  "env-section-wcolors",  false)
		-- Water color sub-sections (lower level, default collapsed)
		envSectionToggle("btn-env-toggle-wc-absorb",       "img-env-toggle-wc-absorb",       "env-section-wc-absorb",       false)
		envSectionToggle("btn-env-toggle-wc-basecolor",    "img-env-toggle-wc-basecolor",    "env-section-wc-basecolor",    false)
		envSectionToggle("btn-env-toggle-wc-mincolor",     "img-env-toggle-wc-mincolor",     "env-section-wc-mincolor",     false)
		envSectionToggle("btn-env-toggle-wc-surfacecolor", "img-env-toggle-wc-surfacecolor", "env-section-wc-surfacecolor", false)
		envSectionToggle("btn-env-toggle-wc-planecolor",   "img-env-toggle-wc-planecolor",   "env-section-wc-planecolor",   false)
		envSectionToggle("btn-env-toggle-wc-diffusecolor", "img-env-toggle-wc-diffusecolor", "env-section-wc-diffusecolor", false)
		envSectionToggle("btn-env-toggle-wc-specularcolor","img-env-toggle-wc-specularcolor","env-section-wc-specularcolor",false)
		envSectionToggle("btn-env-toggle-surface",  "img-env-toggle-surface",  "env-section-surface",  false)
		envSectionToggle("btn-env-toggle-material", "img-env-toggle-material", "env-section-material", false)
		envSectionToggle("btn-env-toggle-fresnel",  "img-env-toggle-fresnel",  "env-section-fresnel",  false)
		envSectionToggle("btn-env-toggle-perlin",   "img-env-toggle-perlin",   "env-section-perlin",   false)
		envSectionToggle("btn-env-toggle-blur",     "img-env-toggle-blur",     "env-section-blur",     false)

		-- Wire ± buttons for env color RGB sliders
		do
			local colorSliders = {
				"suncol-r", "suncol-g", "suncol-b",
				"fog-r", "fog-g", "fog-b",
				"skycol-r", "skycol-g", "skycol-b",
				"cloudcol-r", "cloudcol-g", "cloudcol-b",
				"snowcol-r", "snowcol-g", "snowcol-b",
				"gambient-r", "gambient-g", "gambient-b",
				"gdiffuse-r", "gdiffuse-g", "gdiffuse-b",
				"gspecular-r", "gspecular-g", "gspecular-b",
				"uambient-r", "uambient-g", "uambient-b",
				"udiffuse-r", "udiffuse-g", "udiffuse-b",
				"uspecular-r", "uspecular-g", "uspecular-b",
				"wc-absorb-r", "wc-absorb-g", "wc-absorb-b",
				"wc-basecolor-r", "wc-basecolor-g", "wc-basecolor-b",
				"wc-mincolor-r", "wc-mincolor-g", "wc-mincolor-b",
				"wc-surfacecolor-r", "wc-surfacecolor-g", "wc-surfacecolor-b",
				"wc-planecolor-r", "wc-planecolor-g", "wc-planecolor-b",
				"wc-diffusecolor-r", "wc-diffusecolor-g", "wc-diffusecolor-b",
				"wc-specularcolor-r", "wc-specularcolor-g", "wc-specularcolor-b",
				-- non-color sliders with ± buttons
				"sun-y", "sun-x", "sun-z", "sun-intensity",
				"gshadow", "ushadow",
				"fog-start", "fog-end", "fog-a",
				"snow-density", "snow-speed", "snow-size", "snow-wind", "snow-opacity",
				"skyangle", "skyaxis-x", "skyaxis-y", "skyaxis-z",
				"skydyn-x", "skydyn-y", "skydyn-z",
				"wl",
				"w-repeatx", "w-repeaty", "w-alpha",
				"w-ambient", "w-diffuse", "w-specular", "w-specpow",
				"w-fresnelmin", "w-fresnelmax", "w-fresnelpow",
				"w-pfreq", "w-placun", "w-pamp", "w-numtiles",
				"w-blurbase", "w-blurexp", "w-refldist", "w-waveoff", "w-wavelen",
				"w-foamdist", "w-foamint", "w-caustres", "w-cauststr",
				"splatmult-0", "splatmult-1", "splatmult-2", "splatmult-3",
				"splatscale-0", "splatscale-1", "splatscale-2", "splatscale-3",
				"lava-amp", "lava-period", "lava-fogheight",
			}
			for _, suffix in ipairs(colorSliders) do
				local sl = doc:GetElementById("slider-env-" .. suffix)
				if sl then
					local mn = tonumber(sl:GetAttribute("min")) or 0
					local mx = tonumber(sl:GetAttribute("max")) or 1000
					local st = tonumber(sl:GetAttribute("step")) or 1
					local downBtn = doc:GetElementById("btn-env-" .. suffix .. "-down")
					local upBtn = doc:GetElementById("btn-env-" .. suffix .. "-up")
					if downBtn then
						downBtn:AddEventListener("click", function(event)
							local val = tonumber(sl:GetAttribute("value")) or 0
							sl:SetAttribute("value", tostring(math.max(mn, val - st)))
							event:StopPropagation()
						end, false)
					end
					if upBtn then
						upBtn:AddEventListener("click", function(event)
							local val = tonumber(sl:GetAttribute("value")) or 0
							sl:SetAttribute("value", tostring(math.min(mx, val + st)))
							event:StopPropagation()
						end, false)
					end
				end
			end
		end

		-- ---- Sun & Shadows sliders ----
		-- Cache DOM elements for live feedback from dynamic rotation
		skyDynamic.sunSliderX = doc:GetElementById("slider-env-sun-x")
		skyDynamic.sunLabelX  = doc:GetElementById("lbl-env-sun-x")
		skyDynamic.sunSliderY = doc:GetElementById("slider-env-sun-y")
		skyDynamic.sunLabelY  = doc:GetElementById("lbl-env-sun-y")
		skyDynamic.sunSliderZ = doc:GetElementById("slider-env-sun-z")
		skyDynamic.sunLabelZ  = doc:GetElementById("lbl-env-sun-z")

		envSlider("slider-env-sun-y", "lbl-env-sun-y",
			function(v) return v / 10000 end,
			function() return (select(2, gl.GetSun("pos"))) * 10000 end,
			function(val)
				local sx, sy, sz = gl.GetSun("pos")
				Spring.SetSunDirection(sx, val, sz)
				Spring.SetSunLighting({ groundShadowDensity = gl.GetSun("shadowDensity"), modelShadowDensity = gl.GetSun("shadowDensity") })
			end)
		envSlider("slider-env-sun-x", "lbl-env-sun-x",
			function(v) return v / 10000 end,
			function() return (select(1, gl.GetSun("pos"))) * 10000 end,
			function(val)
				local sx, sy, sz = gl.GetSun("pos")
				Spring.SetSunDirection(val, sy, sz)
				Spring.SetSunLighting({ groundShadowDensity = gl.GetSun("shadowDensity"), modelShadowDensity = gl.GetSun("shadowDensity") })
			end)
		envSlider("slider-env-sun-z", "lbl-env-sun-z",
			function(v) return v / 10000 end,
			function() return (select(3, gl.GetSun("pos"))) * 10000 end,
			function(val)
				local sx, sy, sz = gl.GetSun("pos")
				Spring.SetSunDirection(sx, sy, val)
				Spring.SetSunLighting({ groundShadowDensity = gl.GetSun("shadowDensity"), modelShadowDensity = gl.GetSun("shadowDensity") })
			end)
		envSlider("slider-env-gshadow", "lbl-env-gshadow",
			function(v) return v / 1000 end,
			function() return gl.GetSun("shadowDensity", "ground") * 1000 end,
			function(val) Spring.SetSunLighting({ groundShadowDensity = val }) end)
		envSlider("slider-env-ushadow", "lbl-env-ushadow",
			function(v) return v / 1000 end,
			function() return gl.GetSun("shadowDensity", "unit") * 1000 end,
			function(val) Spring.SetSunLighting({ modelShadowDensity = val }) end)

		-- Sun reset
		local resetSunBtn = doc:GetElementById("btn-env-reset-sun")
		if resetSunBtn then
			resetSunBtn:AddEventListener("click", function(event)
				local d = widgetState.envDefaults
				Spring.SetSunDirection(d.sunPos[1], d.sunPos[2], d.sunPos[3])
				Spring.SetSunLighting({ groundShadowDensity = d.groundShadowDensity, modelShadowDensity = d.unitShadowDensity })
				envSetSlider("slider-env-sun-y", "lbl-env-sun-y", math.floor(d.sunPos[2] * 10000 + 0.5), string.format("%.2f", d.sunPos[2]))
				envSetSlider("slider-env-sun-x", "lbl-env-sun-x", math.floor(d.sunPos[1] * 10000 + 0.5), string.format("%.2f", d.sunPos[1]))
				envSetSlider("slider-env-sun-z", "lbl-env-sun-z", math.floor(d.sunPos[3] * 10000 + 0.5), string.format("%.2f", d.sunPos[3]))
				envSetSlider("slider-env-gshadow", "lbl-env-gshadow", math.floor(d.groundShadowDensity * 1000 + 0.5), string.format("%.2f", d.groundShadowDensity))
				envSetSlider("slider-env-ushadow", "lbl-env-ushadow", math.floor(d.unitShadowDensity * 1000 + 0.5), string.format("%.2f", d.unitShadowDensity))
				event:StopPropagation()
			end, false)
		end

		-- Sun intensity slider
		envSlider("slider-env-sun-intensity", "lbl-env-sun-intensity",
			function(v) return v / 1000 end,
			function() return (widgetState.envSunIntensity or 1.0) * 1000 end,
			function(val)
				widgetState.envSunIntensity = val
				local sx, sy, sz = gl.GetSun("pos")
				if sx then Spring.SetSunDirection(sx, sy, sz, val) end
			end)
		widgetState.envSunIntensity = 1.0

		-- ---- Fog & Atmosphere sliders ----
		envSlider("slider-env-fog-start", "lbl-env-fog-start",
			function(v) return v / 100 end,
			function() return gl.GetAtmosphere("fogStart") * 100 end,
			function(val) Spring.SetAtmosphere({ fogStart = val }) end)
		envSlider("slider-env-fog-end", "lbl-env-fog-end",
			function(v) return v / 100 end,
			function() return gl.GetAtmosphere("fogEnd") * 100 end,
			function(val) Spring.SetAtmosphere({ fogEnd = val }) end)

		-- Fog reset
		local resetFogBtn = doc:GetElementById("btn-env-reset-fog")
		if resetFogBtn then
			resetFogBtn:AddEventListener("click", function(event)
				local d = widgetState.envDefaults
				Spring.SetAtmosphere({ fogStart = d.fogStart, fogEnd = d.fogEnd })
				envSetSlider("slider-env-fog-start", "lbl-env-fog-start", math.floor(d.fogStart * 100 + 0.5), string.format("%.2f", d.fogStart))
				envSetSlider("slider-env-fog-end", "lbl-env-fog-end", math.floor(d.fogEnd * 100 + 0.5), string.format("%.2f", d.fogEnd))
				event:StopPropagation()
			end, false)
		end

		-- Fog color
		local function fogColorSlider(suffix, idx)
			envSlider("slider-env-fog-" .. suffix, "lbl-env-fog-" .. suffix,
				function(v) return v / 1000 end,
				function()
					local c = { gl.GetAtmosphere("fogColor") }
					return (c[idx] or 0) * 1000
				end,
				function(val)
					local c = { gl.GetAtmosphere("fogColor") }
					c[idx] = val
					Spring.SetAtmosphere({ fogColor = c })
				end)
		end
		fogColorSlider("r", 1)
		fogColorSlider("g", 2)
		fogColorSlider("b", 3)
		fogColorSlider("a", 4)

		-- Fog color reset
		local resetFogColorBtn = doc:GetElementById("btn-env-reset-fogcolor")
		if resetFogColorBtn then
			resetFogColorBtn:AddEventListener("click", function(event)
				local d = widgetState.envDefaults
				Spring.SetAtmosphere({ fogColor = d.fogColor })
				for i, s in ipairs({"r", "g", "b", "a"}) do
					envSetSlider("slider-env-fog-" .. s, "lbl-env-fog-" .. s,
						math.floor((d.fogColor[i] or 0) * 1000 + 0.5),
						string.format("%.2f", d.fogColor[i] or 0))
				end
				event:StopPropagation()
			end, false)
		end

		-- Sun color sliders
		local function sunColorSlider(suffix, idx)
			envSlider("slider-env-suncol-" .. suffix, "lbl-env-suncol-" .. suffix,
				function(v) return v / 1000 end,
				function()
					local c = { gl.GetAtmosphere("sunColor") }
					return (c[idx] or 0) * 1000
				end,
				function(val)
					local c = { gl.GetAtmosphere("sunColor") }
					c[idx] = val
					Spring.SetAtmosphere({ sunColor = c })
				end)
		end
		sunColorSlider("r", 1)
		sunColorSlider("g", 2)
		sunColorSlider("b", 3)

		-- Sky color sliders
		local function skyColorSlider(suffix, idx)
			envSlider("slider-env-skycol-" .. suffix, "lbl-env-skycol-" .. suffix,
				function(v) return v / 1000 end,
				function()
					local c = { gl.GetAtmosphere("skyColor") }
					return (c[idx] or 0) * 1000
				end,
				function(val)
					local c = { gl.GetAtmosphere("skyColor") }
					c[idx] = val
					Spring.SetAtmosphere({ skyColor = c })
				end)
		end
		skyColorSlider("r", 1)
		skyColorSlider("g", 2)
		skyColorSlider("b", 3)

		-- Cloud color sliders
		local function cloudColorSlider(suffix, idx)
			envSlider("slider-env-cloudcol-" .. suffix, "lbl-env-cloudcol-" .. suffix,
				function(v) return v / 1000 end,
				function()
					local c = { gl.GetAtmosphere("cloudColor") }
					return (c[idx] or 0) * 1000
				end,
				function(val)
					local c = { gl.GetAtmosphere("cloudColor") }
					c[idx] = val
					Spring.SetAtmosphere({ cloudColor = c })
				end)
		end
		cloudColorSlider("r", 1)
		cloudColorSlider("g", 2)
		cloudColorSlider("b", 3)

		-- Wire palette + preview for fog, sun, sky, cloud colors
		wireColorGroup({
			paletteId = "env-fog-palette", previewId = "env-fog-preview", sliderPrefix = "fog",
			channels = {"r", "g", "b", "a"},
			getColor = function() return { gl.GetAtmosphere("fogColor") } end,
			setColor = function(c)
				local existing = { gl.GetAtmosphere("fogColor") }
				Spring.SetAtmosphere({ fogColor = { c[1], c[2], c[3], existing[4] or 0 } })
			end,
		})
		wireColorGroup({
			paletteId = "env-suncol-palette", previewId = "env-suncol-preview", sliderPrefix = "suncol",
			getColor = function() return { gl.GetAtmosphere("sunColor") } end,
			setColor = function(c) Spring.SetAtmosphere({ sunColor = c }) end,
		})
		wireColorGroup({
			paletteId = "env-skycol-palette", previewId = "env-skycol-preview", sliderPrefix = "skycol",
			getColor = function() return { gl.GetAtmosphere("skyColor") } end,
			setColor = function(c) Spring.SetAtmosphere({ skyColor = c }) end,
		})
		wireColorGroup({
			paletteId = "env-cloudcol-palette", previewId = "env-cloudcol-preview", sliderPrefix = "cloudcol",
			getColor = function() return { gl.GetAtmosphere("cloudColor") } end,
			setColor = function(c) Spring.SetAtmosphere({ cloudColor = c }) end,
		})

		-- Sun color reset
		do local resetBtn = doc:GetElementById("btn-env-reset-suncol")
		if resetBtn then
			resetBtn:AddEventListener("click", function(event)
				local d = widgetState.envDefaults
				Spring.SetAtmosphere({ sunColor = d.sunColor })
				for i, s in ipairs({"r", "g", "b"}) do
					envSetSlider("slider-env-suncol-" .. s, "lbl-env-suncol-" .. s,
						math.floor((d.sunColor[i] or 0) * 1000 + 0.5),
						string.format("%.2f", d.sunColor[i] or 0))
				end
				local c = d.sunColor
				updatePreview(doc:GetElementById("env-suncol-preview"), c[1], c[2], c[3])
				event:StopPropagation()
			end, false)
		end end

		-- Sky color reset
		do local resetBtn = doc:GetElementById("btn-env-reset-skycol")
		if resetBtn then
			resetBtn:AddEventListener("click", function(event)
				local d = widgetState.envDefaults
				Spring.SetAtmosphere({ skyColor = d.skyColor })
				for i, s in ipairs({"r", "g", "b"}) do
					envSetSlider("slider-env-skycol-" .. s, "lbl-env-skycol-" .. s,
						math.floor((d.skyColor[i] or 0) * 1000 + 0.5),
						string.format("%.2f", d.skyColor[i] or 0))
				end
				local c = d.skyColor
				updatePreview(doc:GetElementById("env-skycol-preview"), c[1], c[2], c[3])
				event:StopPropagation()
			end, false)
		end end

		-- Cloud color reset
		do local resetBtn = doc:GetElementById("btn-env-reset-cloudcol")
		if resetBtn then
			resetBtn:AddEventListener("click", function(event)
				local d = widgetState.envDefaults
				Spring.SetAtmosphere({ cloudColor = d.cloudColor })
				for i, s in ipairs({"r", "g", "b"}) do
					envSetSlider("slider-env-cloudcol-" .. s, "lbl-env-cloudcol-" .. s,
						math.floor((d.cloudColor[i] or 0) * 1000 + 0.5),
						string.format("%.2f", d.cloudColor[i] or 0))
				end
				local c = d.cloudColor
				updatePreview(doc:GetElementById("env-cloudcol-preview"), c[1], c[2], c[3])
				event:StopPropagation()
			end, false)
		end end

		-- ---- Snow controls ----
		envSectionToggle("btn-env-toggle-snow", "img-env-toggle-snow", "env-section-snow", false)

		-- Snow enable checkbox
		do
			local snowApi = WG['snow']
			local snowEnabled = snowApi and snowApi.getSnowMap() or false
			envCheckbox("btn-env-snow-enabled", snowEnabled,
				function(val)
					if WG['snow'] then WG['snow'].setSnowMap(val) end
				end)
		end

		-- Snow auto-reduce checkbox
		do
			local snowApi = WG['snow']
			local autoReduce = snowApi and snowApi.getAutoReduce and snowApi.getAutoReduce() or true
			envCheckbox("btn-env-snow-autoreduce", autoReduce,
				function(val)
					if WG['snow'] then WG['snow'].setAutoReduce(val) end
				end)
		end

		-- Snow density slider (multiplier 0.1 - 5.0)
		envSlider("slider-env-snow-density", "lbl-env-snow-density",
			function(v) return v / 100 end,
			function()
				local snowApi = WG['snow']
				return snowApi and snowApi.getMultiplier and snowApi.getMultiplier() * 100 or 100
			end,
			function(val)
				if WG['snow'] then WG['snow'].setMultiplier(val) end
			end)

		-- Snow speed slider (multiplier 0.1 - 3.0)
		envSlider("slider-env-snow-speed", "lbl-env-snow-speed",
			function(v) return v / 100 end,
			function()
				local snowApi = WG['snow']
				return snowApi and snowApi.getSpeedMultiplier and snowApi.getSpeedMultiplier() * 100 or 100
			end,
			function(val)
				if WG['snow'] then WG['snow'].setSpeedMultiplier(val) end
			end)

		-- Snow size slider (multiplier 0.1 - 3.0)
		envSlider("slider-env-snow-size", "lbl-env-snow-size",
			function(v) return v / 100 end,
			function()
				local snowApi = WG['snow']
				return snowApi and snowApi.getSizeMultiplier and snowApi.getSizeMultiplier() * 100 or 100
			end,
			function(val)
				if WG['snow'] then WG['snow'].setSizeMultiplier(val) end
			end)

		-- Snow wind slider (0.0 - 20.0)
		envSlider("slider-env-snow-wind", "lbl-env-snow-wind",
			function(v) return v / 10 end,
			function()
				local snowApi = WG['snow']
				return snowApi and snowApi.getWindMultiplier and snowApi.getWindMultiplier() * 10 or 45
			end,
			function(val)
				if WG['snow'] then WG['snow'].setWindMultiplier(val) end
			end)

		-- Snow opacity slider (0.0 - 1.0)
		envSlider("slider-env-snow-opacity", "lbl-env-snow-opacity",
			function(v) return v / 100 end,
			function()
				local snowApi = WG['snow']
				return snowApi and snowApi.getOpacity and snowApi.getOpacity() * 100 or 66
			end,
			function(val)
				if WG['snow'] then WG['snow'].setOpacity(val) end
			end)

		-- Snow color sliders
		local function snowColorSlider(suffix, idx)
			envSlider("slider-env-snowcol-" .. suffix, "lbl-env-snowcol-" .. suffix,
				function(v) return v / 1000 end,
				function()
					local snowApi = WG['snow']
					if snowApi and snowApi.getColor then
						local r, g, b = snowApi.getColor()
						local c = {r, g, b}
						return (c[idx] or 0) * 1000
					end
					return ({800, 800, 900})[idx]
				end,
				function(val)
					if WG['snow'] and WG['snow'].getColor and WG['snow'].setColor then
						local r, g, b = WG['snow'].getColor()
						local c = {r, g, b}
						c[idx] = val
						WG['snow'].setColor(c[1], c[2], c[3])
						updatePreview(doc:GetElementById("env-snowcol-preview"), c[1], c[2], c[3])
					end
				end)
		end
		snowColorSlider("r", 1)
		snowColorSlider("g", 2)
		snowColorSlider("b", 3)

		-- Wire snow color palette + preview
		wireColorGroup({
			paletteId = "env-snowcol-palette", previewId = "env-snowcol-preview", sliderPrefix = "snowcol",
			getColor = function()
				local snowApi = WG['snow']
				if snowApi and snowApi.getColor then
					local r, g, b = snowApi.getColor()
					return {r, g, b}
				end
				return {0.8, 0.8, 0.9}
			end,
			setColor = function(c)
				if WG['snow'] and WG['snow'].setColor then
					WG['snow'].setColor(c[1], c[2], c[3])
				end
			end,
		})

		-- Snow reset button
		do local resetBtn = doc:GetElementById("btn-env-reset-snow")
		if resetBtn then
			resetBtn:AddEventListener("click", function(event)
				if WG['snow'] then
					if WG['snow'].setMultiplier then WG['snow'].setMultiplier(1.0) end
					if WG['snow'].setSpeedMultiplier then WG['snow'].setSpeedMultiplier(1.0) end
					if WG['snow'].setSizeMultiplier then WG['snow'].setSizeMultiplier(1.0) end
					if WG['snow'].setWindMultiplier then WG['snow'].setWindMultiplier(4.5) end
					if WG['snow'].setOpacity then WG['snow'].setOpacity(0.66) end
					if WG['snow'].setColor then WG['snow'].setColor(0.8, 0.8, 0.9) end
				end
				envSetSlider("slider-env-snow-density", "lbl-env-snow-density", 100, "1.00")
				envSetSlider("slider-env-snow-speed", "lbl-env-snow-speed", 100, "1.00")
				envSetSlider("slider-env-snow-size", "lbl-env-snow-size", 100, "1.00")
				envSetSlider("slider-env-snow-wind", "lbl-env-snow-wind", 45, "4.50")
				envSetSlider("slider-env-snow-opacity", "lbl-env-snow-opacity", 66, "0.66")
				envSetSlider("slider-env-snowcol-r", "lbl-env-snowcol-r", 800, "0.80")
				envSetSlider("slider-env-snowcol-g", "lbl-env-snowcol-g", 800, "0.80")
				envSetSlider("slider-env-snowcol-b", "lbl-env-snowcol-b", 900, "0.90")
				updatePreview(doc:GetElementById("env-snowcol-preview"), 0.8, 0.8, 0.9)
				event:StopPropagation()
			end, false)
		end end

		-- ---- Lighting sliders ----
		local function lightingSlider(prefix, sunKind, sunScope, lightingKey)
			for i, suffix in ipairs({"r", "g", "b"}) do
				envSlider("slider-env-" .. prefix .. "-" .. suffix, "lbl-env-" .. prefix .. "-" .. suffix,
					function(v) return v / 1000 end,
					function()
						local r, g, b = gl.GetSun(sunKind, sunScope)
						local c = {r, g, b}
						return (c[i] or 0) * 1000
					end,
					function(val)
						local r, g, b = gl.GetSun(sunKind, sunScope)
						local c = {r or 0, g or 0, b or 0}
						c[i] = val
						Spring.SetSunLighting({ [lightingKey] = c })
						Spring.SendCommands("luarules updatesun")
					end)
			end
		end
		lightingSlider("gambient", "ambient", nil, "groundAmbientColor")
		lightingSlider("gdiffuse", "diffuse", nil, "groundDiffuseColor")
		lightingSlider("gspecular", "specular", nil, "groundSpecularColor")
		lightingSlider("uambient", "ambient", "unit", "unitAmbientColor")
		lightingSlider("udiffuse", "diffuse", "unit", "unitDiffuseColor")
		lightingSlider("uspecular", "specular", "unit", "unitSpecularColor")

		-- Ground lighting reset
		do local resetBtn = doc:GetElementById("btn-env-reset-ground-lighting")
		if resetBtn then
			resetBtn:AddEventListener("click", function(event)
				local d = widgetState.envDefaults
				Spring.SetSunLighting({
					groundAmbientColor = d.groundAmbient,
					groundDiffuseColor = d.groundDiffuse,
					groundSpecularColor = d.groundSpecular,
				})
				Spring.SendCommands("luarules updatesun")
				local map = {
					{"gambient", d.groundAmbient}, {"gdiffuse", d.groundDiffuse}, {"gspecular", d.groundSpecular},
				}
				for _, entry in ipairs(map) do
					for i, s in ipairs({"r", "g", "b"}) do
						envSetSlider("slider-env-" .. entry[1] .. "-" .. s, "lbl-env-" .. entry[1] .. "-" .. s,
							math.floor((entry[2][i] or 0) * 1000 + 0.5),
							string.format("%.2f", entry[2][i] or 0))
					end
				end
				event:StopPropagation()
			end, false)
		end end

		-- Unit lighting reset
		do local resetBtn = doc:GetElementById("btn-env-reset-unit-lighting")
		if resetBtn then
			resetBtn:AddEventListener("click", function(event)
				local d = widgetState.envDefaults
				Spring.SetSunLighting({
					unitAmbientColor = d.unitAmbient,
					unitDiffuseColor = d.unitDiffuse,
					unitSpecularColor = d.unitSpecular,
				})
				Spring.SendCommands("luarules updatesun")
				local map = {
					{"uambient", d.unitAmbient}, {"udiffuse", d.unitDiffuse}, {"uspecular", d.unitSpecular},
				}
				for _, entry in ipairs(map) do
					for i, s in ipairs({"r", "g", "b"}) do
						envSetSlider("slider-env-" .. entry[1] .. "-" .. s, "lbl-env-" .. entry[1] .. "-" .. s,
							math.floor((entry[2][i] or 0) * 1000 + 0.5),
							string.format("%.2f", entry[2][i] or 0))
					end
				end
				event:StopPropagation()
			end, false)
		end end

		-- ---- Map Rendering controls ----
		-- Render toggles (default to true; no engine getter available)
		envCheckbox("btn-env-drawsky", true,
			function(val) Spring.SetDrawSky(val) end)
		envCheckbox("btn-env-drawwater", true,
			function(val) Spring.SetDrawWater(val) end)
		envCheckbox("btn-env-drawground", true,
			function(val) Spring.SetDrawGround(val) end)

		-- Deferred rendering toggles (default to true)
		envCheckbox("btn-env-deferground", true,
			function(val) Spring.SetDrawGroundDeferred(val) end)
		envCheckbox("btn-env-defermodels", true,
			function(val) Spring.SetDrawModelsDeferred(val, val) end)

		envCheckbox("btn-env-splatdnda", gl.GetMapRendering("splatDetailNormalDiffuseAlpha"),
			function(val) Spring.SetMapRenderingParams({ splatDetailNormalDiffuseAlpha = val }) end)
		envCheckbox("btn-env-voidwater", gl.GetMapRendering("voidWater"),
			function(val) Spring.SetMapRenderingParams({ voidWater = val }) end)
		envCheckbox("btn-env-voidground", gl.GetMapRendering("voidGround"),
			function(val) Spring.SetMapRenderingParams({ voidGround = val }) end)

		-- Splat tex multipliers
		for ch = 0, 3 do
			local chIdx = ch + 1
			envSlider("slider-env-splatmult-" .. ch, "lbl-env-splatmult-" .. ch,
				function(v) return v / 1000 end,
				function()
					local r, g, b, a = gl.GetMapRendering("splatTexMults")
					local c = {r, g, b, a}
					return (c[chIdx] or 0) * 1000
				end,
				function(val)
					local r, g, b, a = gl.GetMapRendering("splatTexMults")
					local c = {r, g, b, a}
					c[chIdx] = val
					Spring.SetMapRenderingParams({ splatTexMults = c })
				end)
		end

		-- Splat tex scales
		for ch = 0, 3 do
			local chIdx = ch + 1
			envSlider("slider-env-splatscale-" .. ch, "lbl-env-splatscale-" .. ch,
				function(v) return v / 10000 end,
				function()
					local r, g, b, a = gl.GetMapRendering("splatTexScales")
					local c = {r, g, b, a}
					return (c[chIdx] or 0) * 10000
				end,
				function(val)
					local r, g, b, a = gl.GetMapRendering("splatTexScales")
					local c = {r, g, b, a}
					c[chIdx] = val
					Spring.SetMapRenderingParams({ splatTexScales = c })
				end)
			-- Override label format to 3 decimal places
			local lb = doc:GetElementById("lbl-env-splatscale-" .. ch)
			local sl = doc:GetElementById("slider-env-splatscale-" .. ch)
			if sl and lb then
				sl:AddEventListener("change", function(event)
					if uiState.updatingFromCode then return end
					local raw = tonumber(sl:GetAttribute("value")) or 0
					lb.inner_rml = string.format("%.4f", raw / 10000)
				end, false)
			end
		end

		-- ---- Skybox rotation sliders ----
		envSlider("slider-env-skyangle", "lbl-env-skyangle",
			function(v) return v / 100 end,
			function()
				local x, y, z, angle = gl.GetAtmosphere("skyAxisAngle")
				return (angle or 0) * 100
			end,
			function(val)
				local x, y, z, angle = gl.GetAtmosphere("skyAxisAngle")
				Spring.SetAtmosphere({ skyAxisAngle = { x, y, z, val } })
			end)
		local function skyAxisSlider(axis, idx)
			envSlider("slider-env-skyaxis-" .. axis, "lbl-env-skyaxis-" .. axis,
				function(v) return v / 100 end,
				function()
					local x, y, z, angle = gl.GetAtmosphere("skyAxisAngle")
					local c = {x, y, z, angle}
					return (c[idx] or 0) * 100
				end,
				function(val)
					local x, y, z, angle = gl.GetAtmosphere("skyAxisAngle")
					local c = {x, y, z, angle}
					c[idx] = val
					Spring.SetAtmosphere({ skyAxisAngle = c })
				end)
		end
		skyAxisSlider("x", 1)
		skyAxisSlider("y", 2)
		skyAxisSlider("z", 3)

		-- Sky axis reset
		local resetSkyAxisBtn = doc:GetElementById("btn-env-reset-skyaxis")
		if resetSkyAxisBtn then
			resetSkyAxisBtn:AddEventListener("click", function(event)
				local d = widgetState.envDefaults
				Spring.SetAtmosphere({ skyAxisAngle = d.skyAxisAngle })
				event:StopPropagation()
			end, false)
		end

		-- ---- Dynamic skybox rotation controls ----
		local function skyDynSlider(axis, field)
			envSlider("slider-env-skydyn-" .. axis, "lbl-env-skydyn-" .. axis,
				function(v) return v / 100 end,
				function() return skyDynamic[field] * 100 end,
				function(val) skyDynamic[field] = val end)
		end
		skyDynSlider("x", "speedX")
		skyDynSlider("y", "speedY")
		skyDynSlider("z", "speedZ")

		envCheckbox("btn-env-skydyn-sunsync", skyDynamic.sunSync,
			function(val) skyDynamic.sunSync = val end)

		local playBtn = doc:GetElementById("btn-env-skydyn-play")
		local pauseBtn = doc:GetElementById("btn-env-skydyn-pause")
		if playBtn then
			playBtn:AddEventListener("click", function(event)
				skyDynamic.playing = true
				-- Reset delta angles to zero; capture current skybox rotation as start quaternion
				skyDynamic.angleX = 0
				skyDynamic.angleY = 0
				skyDynamic.angleZ = 0
				local x, y, z, angle = gl.GetAtmosphere("skyAxisAngle")
				local sqx, sqy, sqz, sqw = quatFromAxisAngle(x or 0, y or 1, z or 0, angle or 0)
				skyDynamic.startQuat = { sqx, sqy, sqz, sqw }
				-- Capture sun direction for sun-sync
				local sx, sy, sz = gl.GetSun("pos")
				skyDynamic.origSunDir = { sx, sy, sz }
				event:StopPropagation()
			end, false)
		end
		if pauseBtn then
			pauseBtn:AddEventListener("click", function(event)
				skyDynamic.playing = false
				event:StopPropagation()
			end, false)
		end

		-- ---- Water controls ----
		envCheckbox("btn-env-w-shorewaves", gl.GetWaterRendering("shoreWaves"),
			function(val)
				Spring.SetWaterParams({ shoreWaves = val })
				Spring.SendCommands("water 4")
			end)
		envCheckbox("btn-env-w-waterplane", gl.GetWaterRendering("hasWaterPlane"),
			function(val)
				Spring.SetWaterParams({ hasWaterPlane = val })
				Spring.SendCommands("water 4")
			end)
		envCheckbox("btn-env-w-forcerender", gl.GetWaterRendering("forceRendering"),
			function(val)
				Spring.SetWaterParams({ forceRendering = val })
				Spring.SendCommands("water 4")
			end)

		-- Water sliders
		local waterSliders = {
			{ "repeatx", "repeatx", 1, "repeatX", "repeatX", 1 },
			{ "repeaty", "repeaty", 1, "repeatY", "repeatY", 1 },
			{ "alpha", "alpha", 1000, "surfaceAlpha", "surfaceAlpha", 1000 },
			{ "ambient", "ambient", 1000, "ambientFactor", "ambientFactor", 1000 },
			{ "diffuse", "diffuse", 1000, "diffuseFactor", "diffuseFactor", 1000 },
			{ "specular", "specular", 1000, "specularFactor", "specularFactor", 1000 },
			{ "specpow", "specpow", 10, "specularPower", "specularPower", 10 },
			{ "fresnelmin", "fresnelmin", 100, "fresnelMin", "fresnelMin", 100 },
			{ "fresnelmax", "fresnelmax", 100, "fresnelMax", "fresnelMax", 100 },
			{ "fresnelpow", "fresnelpow", 10, "fresnelPower", "fresnelPower", 10 },
			{ "pfreq", "pfreq", 1, "perlinStartFreq", "perlinStartFreq", 1 },
			{ "placun", "placun", 100, "perlinLacunarity", "perlinLacunarity", 100 },
			{ "pamp", "pamp", 100, "perlinAmplitude", "perlinAmplitude", 100 },
			{ "numtiles", "numtiles", 1, "numTiles", "numTiles", 1 },
			{ "blurbase", "blurbase", 100, "blurBase", "blurBase", 100 },
			{ "blurexp", "blurexp", 100, "blurExponent", "blurExponent", 100 },
			{ "refldist", "refldist", 100, "reflectionDistortion", "reflectionDistortion", 100 },
			{ "waveoff", "waveoff", 100, "waveOffsetFactor", "waveOffsetFactor", 100 },
			{ "wavelen", "wavelen", 100, "waveLength", "waveLength", 100 },
			{ "foamdist", "foamdist", 100, "waveFoamDistortion", "waveFoamDistortion", 100 },
			{ "foamint", "foamint", 100, "waveFoamIntensity", "waveFoamIntensity", 100 },
			{ "caustres", "caustres", 1, "causticsResolution", "causticsResolution", 1 },
			{ "cauststr", "cauststr", 100, "causticsStrength", "causticsStrength", 100 },
		}
		for _, ws in ipairs(waterSliders) do
			local slSuffix, lblSuffix, divisor, getParam, setParam, getScale = ws[1], ws[2], ws[3], ws[4], ws[5], ws[6]
			envSlider("slider-env-w-" .. slSuffix, "lbl-env-w-" .. lblSuffix,
				function(v) return v / divisor end,
				function() return (gl.GetWaterRendering(getParam) or 0) * getScale end,
				function(val)
					Spring.SetWaterParams({ [setParam] = val })
					Spring.SendCommands("water 4")
				end)
		end

		-- ---- Water color sliders ----
		do
			local waterColorParams = {
				{ prefix = "absorb",       param = "absorb",       paletteId = "env-wc-palette-absorb" },
				{ prefix = "basecolor",    param = "baseColor",    paletteId = "env-wc-palette-basecolor" },
				{ prefix = "mincolor",     param = "minColor" },
				{ prefix = "surfacecolor", param = "surfaceColor" },
				{ prefix = "planecolor",   param = "planeColor" },
				{ prefix = "diffusecolor", param = "diffuseColor" },
				{ prefix = "specularcolor",param = "specularColor" },
			}
			for _, wc in ipairs(waterColorParams) do
				for i, suffix in ipairs({"r", "g", "b"}) do
					envSlider("slider-env-wc-" .. wc.prefix .. "-" .. suffix, "lbl-env-wc-" .. wc.prefix .. "-" .. suffix,
						function(v) return v / 1000 end,
						function()
							local c = { gl.GetWaterRendering(wc.param) }
							return (c[i] or 0) * 1000
						end,
						function(val)
							local c = { gl.GetWaterRendering(wc.param) }
							c[i] = val
							Spring.SetWaterParams({ [wc.param] = c })
							Spring.SendCommands("water 4")
						end)
				end
				wireColorGroup({
					paletteId = wc.paletteId,
					previewId = "env-wc-preview-" .. wc.prefix,
					sliderPrefix = "wc-" .. wc.prefix,
					getColor = function() return { gl.GetWaterRendering(wc.param) } end,
					setColor = function(c)
						Spring.SetWaterParams({ [wc.param] = c })
						Spring.SendCommands("water 4")
					end,
				})
			end

			-- Water colors reset
			local resetWCBtn = doc:GetElementById("btn-env-reset-watercolors")
			if resetWCBtn then
				resetWCBtn:AddEventListener("click", function(event)
					local d = widgetState.envDefaults
					local resetMap = {
						{ "absorb", d.waterAbsorb }, { "basecolor", d.waterBaseColor },
						{ "mincolor", d.waterMinColor }, { "surfacecolor", d.waterSurfaceColor },
						{ "planecolor", d.waterPlaneColor }, { "diffusecolor", d.waterDiffuseColor },
						{ "specularcolor", d.waterSpecularColor },
					}
					local paramMap = {
						absorb = "absorb", basecolor = "baseColor", mincolor = "minColor",
						surfacecolor = "surfaceColor", planecolor = "planeColor",
						diffusecolor = "diffuseColor", specularcolor = "specularColor",
					}
					for _, entry in ipairs(resetMap) do
						local prefix, defVal = entry[1], entry[2]
						Spring.SetWaterParams({ [paramMap[prefix]] = defVal })
						for i, s in ipairs({"r", "g", "b"}) do
							envSetSlider("slider-env-wc-" .. prefix .. "-" .. s, "lbl-env-wc-" .. prefix .. "-" .. s,
								math.floor((defVal[i] or 0) * 1000 + 0.5),
								string.format("%.2f", defVal[i] or 0))
						end
						updatePreview(doc:GetElementById("env-wc-preview-" .. prefix), defVal[1], defVal[2], defVal[3])
					end
					Spring.SendCommands("water 4")
					-- Also deactivate shader overlay on color reset
					local overlay = WG.WaterTypeOverlay
					if overlay then overlay.deactivate() end
					event:StopPropagation()
				end, false)
			end
		end

		-- ---- Water Type Preset Switcher ----
		do
			local waterTypePresets = {
				ocean = {
					absorb       = {0.30, 0.04, 0.03},
					baseColor    = {0.00, 0.10, 0.30},
					minColor     = {0.00, 0.02, 0.08},
					surfaceColor = {0.60, 0.70, 0.85},
					planeColor   = {0.00, 0.15, 0.35},
					diffuseColor = {1.00, 1.00, 1.00},
					specularColor= {0.80, 0.80, 0.90},
				},
				lava = {
					absorb       = {0.00, 0.25, 0.45},
					baseColor    = {0.80, 0.20, 0.00},
					minColor     = {0.50, 0.05, 0.00},
					surfaceColor = {1.00, 0.50, 0.10},
					planeColor   = {0.60, 0.10, 0.00},
					diffuseColor = {1.00, 0.40, 0.00},
					specularColor= {1.00, 0.60, 0.20},
				},
				acid = {
					absorb       = {0.30, 0.02, 0.35},
					baseColor    = {0.10, 0.40, 0.05},
					minColor     = {0.00, 0.15, 0.00},
					surfaceColor = {0.30, 0.80, 0.20},
					planeColor   = {0.05, 0.30, 0.02},
					diffuseColor = {0.50, 1.00, 0.30},
					specularColor= {0.40, 0.90, 0.30},
				},
				swamp = {
					absorb       = {0.15, 0.08, 0.02},
					baseColor    = {0.15, 0.18, 0.05},
					minColor     = {0.03, 0.05, 0.02},
					surfaceColor = {0.25, 0.30, 0.15},
					planeColor   = {0.10, 0.12, 0.04},
					diffuseColor = {0.60, 0.70, 0.40},
					specularColor= {0.30, 0.35, 0.20},
				},
				ice = {
					absorb       = {0.15, 0.05, 0.03},
					baseColor    = {0.50, 0.65, 0.80},
					minColor     = {0.20, 0.30, 0.40},
					surfaceColor = {0.85, 0.90, 0.95},
					planeColor   = {0.40, 0.55, 0.70},
					diffuseColor = {0.90, 0.95, 1.00},
					specularColor= {1.00, 1.00, 1.00},
				},
			}

			local wtypeButtons = { "default", "ocean", "lava", "acid", "swamp", "ice" }
			local wtypeBtnEls = {}
			for _, name in ipairs(wtypeButtons) do
				wtypeBtnEls[name] = doc:GetElementById("btn-wtype-" .. name)
			end

			local function applyWaterTypePreset(colors)
				for param, c in pairs(colors) do
					Spring.SetWaterParams({ [param] = c })
				end
				Spring.SendCommands("water 4")
				-- Update all water color sliders to reflect new values
				local sliderMap = {
					{ "absorb",       "absorb" },
					{ "basecolor",    "baseColor" },
					{ "mincolor",     "minColor" },
					{ "surfacecolor", "surfaceColor" },
					{ "planecolor",   "planeColor" },
					{ "diffusecolor", "diffuseColor" },
					{ "specularcolor","specularColor" },
				}
				for _, entry in ipairs(sliderMap) do
					local prefix, param = entry[1], entry[2]
					local c = { gl.GetWaterRendering(param) }
					for i, s in ipairs({"r", "g", "b"}) do
						envSetSlider("slider-env-wc-" .. prefix .. "-" .. s, "lbl-env-wc-" .. prefix .. "-" .. s,
							math.floor((c[i] or 0) * 1000 + 0.5),
							string.format("%.2f", c[i] or 0))
					end
					updatePreview(doc:GetElementById("env-wc-preview-" .. prefix), c[1], c[2], c[3])
				end
			end

			local function setWtypeActive(activeName)
				for _, name in ipairs(wtypeButtons) do
					local el = wtypeBtnEls[name]
					if el then
						if name == activeName then
							el:SetClass("tf-wtype-active", true)
						else
							el:SetClass("tf-wtype-active", false)
						end
					end
				end
			end

			for _, name in ipairs(wtypeButtons) do
				local btn = wtypeBtnEls[name]
				if btn then
					btn:AddEventListener("click", function(event)
						if name == "default" then
							-- Reset to map defaults
							local d = widgetState.envDefaults
							local defColors = {
								absorb = d.waterAbsorb, baseColor = d.waterBaseColor,
								minColor = d.waterMinColor, surfaceColor = d.waterSurfaceColor,
								planeColor = d.waterPlaneColor, diffuseColor = d.waterDiffuseColor,
								specularColor = d.waterSpecularColor,
							}
							applyWaterTypePreset(defColors)
						else
							applyWaterTypePreset(waterTypePresets[name])
						end
						-- Activate/deactivate the shader overlay for lava/acid
						local overlay = WG.WaterTypeOverlay
						if overlay then
							if name == "lava" or name == "acid" then
								overlay.activate(name)
							else
								overlay.deactivate()
							end
						end
						setWtypeActive(name)
						-- Show/hide water sections for lava/acid types
						local stdSections = doc:GetElementById("env-water-std-sections")
						local lavaSections = doc:GetElementById("env-lava-sections")
						if stdSections and lavaSections then
							local isLavaType = name == "lava" or name == "acid"
							stdSections:SetClass("hidden", isLavaType)
							lavaSections:SetClass("hidden", not isLavaType)
						end
						event:StopPropagation()
					end, false)
				end
			end

			-- Lava / acid shader overlay sliders
			envSlider("slider-env-lava-amp", "lbl-env-lava-amp",
				function(v) return v end,
				function() return 2 end,
				function(val)
					local ov = WG.WaterTypeOverlay
					if ov and ov.setTideAmplitude then ov.setTideAmplitude(val) end
				end)
			envSlider("slider-env-lava-period", "lbl-env-lava-period",
				function(v) return v end,
				function() return 200 end,
				function(val)
					local ov = WG.WaterTypeOverlay
					if ov and ov.setTidePeriod then ov.setTidePeriod(val) end
				end)
			envSlider("slider-env-lava-fogheight", "lbl-env-lava-fogheight",
				function(v) return v end,
				function() return 20 end,
				function(val)
					local ov = WG.WaterTypeOverlay
					if ov and ov.setFogHeight then ov.setFogHeight(val) end
				end)
		end

		-- ---- Dimensions panel controls ----
		do
			-- Populate map size labels
			local lblMapX = doc:GetElementById("lbl-dim-map-x")
			local lblMapZ = doc:GetElementById("lbl-dim-map-z")
			if lblMapX then lblMapX.inner_rml = tostring(Game.mapSizeX) end
			if lblMapZ then lblMapZ.inner_rml = tostring(Game.mapSizeZ) end

			-- Height extreme labels
			local lblInitMin = doc:GetElementById("lbl-dim-init-min")
			local lblInitMax = doc:GetElementById("lbl-dim-init-max")
			local lblCurrMin = doc:GetElementById("lbl-dim-curr-min")
			local lblCurrMax = doc:GetElementById("lbl-dim-curr-max")
			local lblWaterPlane = doc:GetElementById("lbl-dim-water-plane")

			local function refreshDimExtremes()
				local initMin, initMax, currMin, currMax = Spring.GetGroundExtremes()
				if lblInitMin then lblInitMin.inner_rml = string.format("%.1f", initMin or 0) end
				if lblInitMax then lblInitMax.inner_rml = string.format("%.1f", initMax or 0) end
				if lblCurrMin then lblCurrMin.inner_rml = string.format("%.1f", currMin or 0) end
				if lblCurrMax then lblCurrMax.inner_rml = string.format("%.1f", currMax or 0) end
				local wl = Spring.GetWaterPlaneLevel and Spring.GetWaterPlaneLevel() or 0
				if lblWaterPlane then lblWaterPlane.inner_rml = string.format("%.1f", wl) end
			end

			refreshDimExtremes()

			local refreshBtn = doc:GetElementById("btn-dim-refresh-extremes")
			if refreshBtn then
				refreshBtn:AddEventListener("click", function(event)
					refreshDimExtremes()
					event:StopPropagation()
				end, false)
			end

			-- Water level input
			local wlInput = doc:GetElementById("input-dim-waterlevel")
			if wlInput then
				wlInput:AddEventListener("focus", function() Spring.SDLStartTextInput(); widgetState.focusedRmlInput = wlInput end, false)
				wlInput:AddEventListener("blur", function() Spring.SDLStopTextInput(); widgetState.focusedRmlInput = nil end, false)
			end

			local wlApplyBtn = doc:GetElementById("btn-dim-waterlevel-apply")
			if wlApplyBtn then
				wlApplyBtn:AddEventListener("click", function(event)
					local val = wlInput and tonumber(wlInput:GetAttribute("value"))
					if val and val ~= 0 then
						Spring.SendLuaRulesMsg("$wl$:" .. tostring(val))
						if wlInput then wlInput:SetAttribute("value", "0") end
						-- Refresh extremes after a short delay via next open
						refreshDimExtremes()
					end
					event:StopPropagation()
				end, false)
			end

			-- Min height input
			local minHInput = doc:GetElementById("input-dim-minheight")
			if minHInput then
				minHInput:AddEventListener("focus", function() Spring.SDLStartTextInput(); widgetState.focusedRmlInput = minHInput end, false)
				minHInput:AddEventListener("blur", function() Spring.SDLStopTextInput(); widgetState.focusedRmlInput = nil end, false)
			end

			local minHApplyBtn = doc:GetElementById("btn-dim-minheight-apply")
			if minHApplyBtn then
				minHApplyBtn:AddEventListener("click", function(event)
					local val = minHInput and tonumber(minHInput:GetAttribute("value"))
					if val then
						Spring.SendLuaRulesMsg("$hclampmin$:" .. tostring(val))
						refreshDimExtremes()
					end
					event:StopPropagation()
				end, false)
			end

			-- Max height input
			local maxHInput = doc:GetElementById("input-dim-maxheight")
			if maxHInput then
				maxHInput:AddEventListener("focus", function() Spring.SDLStartTextInput(); widgetState.focusedRmlInput = maxHInput end, false)
				maxHInput:AddEventListener("blur", function() Spring.SDLStopTextInput(); widgetState.focusedRmlInput = nil end, false)
			end

			local maxHApplyBtn = doc:GetElementById("btn-dim-maxheight-apply")
			if maxHApplyBtn then
				maxHApplyBtn:AddEventListener("click", function(event)
					local val = maxHInput and tonumber(maxHInput:GetAttribute("value"))
					if val then
						Spring.SendLuaRulesMsg("$hclampmax$:" .. tostring(val))
						refreshDimExtremes()
					end
					event:StopPropagation()
				end, false)
			end

			local wlResetBtn = doc:GetElementById("btn-dim-reset-waterlevel")
			if wlResetBtn then
				wlResetBtn:AddEventListener("click", function(event)
					if wlInput then wlInput:SetAttribute("value", "0") end
					event:StopPropagation()
				end, false)
			end

			local boundsResetBtn = doc:GetElementById("btn-dim-reset-bounds")
			if boundsResetBtn then
				boundsResetBtn:AddEventListener("click", function(event)
					if minHInput then minHInput:SetAttribute("value", "") end
					if maxHInput then maxHInput:SetAttribute("value", "") end
					event:StopPropagation()
				end, false)
			end
		end

		-- ---- Environment Save button ----
		local envSaveBtn = doc:GetElementById("btn-env-save")
		if envSaveBtn then
			envSaveBtn:AddEventListener("click", function(event)
				playSound("save")
				-- Collect all current environment settings
				local sX, sY, sZ = gl.GetSun("pos")
				local grA = { gl.GetSun("ambient") }
				local grD = { gl.GetSun("diffuse") }
				local grS = { gl.GetSun("specular") }
				local unA = { gl.GetSun("ambient", "unit") }
				local unD = { gl.GetSun("diffuse", "unit") }
				local unS = { gl.GetSun("specular", "unit") }
				local gShadow = gl.GetSun("shadowDensity", "ground")
				local uShadow = gl.GetSun("shadowDensity", "unit")
				local fgS = gl.GetAtmosphere("fogStart")
				local fgE = gl.GetAtmosphere("fogEnd")
				local fgC = { gl.GetAtmosphere("fogColor") }
				local snC = { gl.GetAtmosphere("sunColor") }
				local skC = { gl.GetAtmosphere("skyColor") }
				local skAA = { gl.GetAtmosphere("skyAxisAngle") }
				local clC = { gl.GetAtmosphere("cloudColor") }
				local sunIntensity = widgetState.envSunIntensity or 1.0

				local smR, smG, smB, smA = gl.GetMapRendering("splatTexMults")
				local ssR, ssG, ssB, ssA = gl.GetMapRendering("splatTexScales")
				local sdnda = gl.GetMapRendering("splatDetailNormalDiffuseAlpha")
				local vW = gl.GetMapRendering("voidWater")
				local vG = gl.GetMapRendering("voidGround")

				local fmt3 = function(t) return string.format("{ %.4f, %.4f, %.4f }", t[1] or 0, t[2] or 0, t[3] or 0) end
				local fmt4 = function(t) return string.format("{ %.4f, %.4f, %.4f, %.4f }", t[1] or 0, t[2] or 0, t[3] or 0, t[4] or 0) end
				local bstr = function(v) return v and "true" or "false" end

				local outLines = {
					"-- Environment config exported from BAR Terraform Brush",
					"-- Map: " .. (Game.mapName or "unknown"),
					"-- Date: " .. os.date("%Y-%m-%d %H:%M:%S"),
					"return {",
					"\tversion = 1,",
					"\tmapName = \"" .. (Game.mapName or "unknown") .. "\",",
					"",
					"\t-- Sun direction",
					"\tsunDir = " .. fmt3({sX, sY, sZ}) .. ",",
					"",
					"\t-- Shadow density",
					"\tgroundShadowDensity = " .. string.format("%.4f", gShadow) .. ",",
					"\tmodelShadowDensity = " .. string.format("%.4f", uShadow) .. ",",
					"",
					"\t-- Ground lighting",
					"\tgroundAmbientColor = " .. fmt3(grA) .. ",",
					"\tgroundDiffuseColor = " .. fmt3(grD) .. ",",
					"\tgroundSpecularColor = " .. fmt3(grS) .. ",",
					"",
					"\t-- Unit lighting",
					"\tunitAmbientColor = " .. fmt3(unA) .. ",",
					"\tunitDiffuseColor = " .. fmt3(unD) .. ",",
					"\tunitSpecularColor = " .. fmt3(unS) .. ",",
					"",
					"\t-- Fog",
					"\tfogStart = " .. string.format("%.4f", fgS) .. ",",
					"\tfogEnd = " .. string.format("%.4f", fgE) .. ",",
					"\tfogColor = " .. fmt4(fgC) .. ",",
					"",
					"\t-- Atmosphere colors",
					"\tsunColor = " .. fmt3(snC) .. ",",
					"\tskyColor = " .. fmt3(skC) .. ",",
					"\tcloudColor = " .. fmt3(clC) .. ",",
					"",
					"\t-- Sun intensity",
					"\tsunIntensity = " .. string.format("%.4f", sunIntensity) .. ",",
					"",
					"\t-- Skybox rotation",
					"\tskyAxisAngle = " .. fmt4(skAA) .. ",",
					"",
					"\t-- Map rendering",
					"\tsplatDetailNormalDiffuseAlpha = " .. bstr(sdnda) .. ",",
					"\tsplatTexMults = " .. fmt4({smR, smG, smB, smA}) .. ",",
					"\tsplatTexScales = " .. fmt4({ssR, ssG, ssB, ssA}) .. ",",
					"\tvoidWater = " .. bstr(vW) .. ",",
					"\tvoidGround = " .. bstr(vG) .. ",",
					"",
					"\t-- Water",
					"\twater = {",
				}

				-- Add all water params
				local wParams = {
					"shoreWaves", "hasWaterPlane", "forceRendering",
					"repeatX", "repeatY", "surfaceAlpha",
					"ambientFactor", "diffuseFactor", "specularFactor", "specularPower",
					"fresnelMin", "fresnelMax", "fresnelPower",
					"perlinStartFreq", "perlinLacunarity", "perlinAmplitude", "numTiles",
					"blurBase", "blurExponent", "reflectionDistortion",
					"waveOffsetFactor", "waveLength", "waveFoamDistortion", "waveFoamIntensity",
					"causticsResolution", "causticsStrength",
				}
				local boolParams = { shoreWaves = true, hasWaterPlane = true, forceRendering = true }
				for _, p in ipairs(wParams) do
					local val = gl.GetWaterRendering(p)
					if boolParams[p] then
						outLines[#outLines + 1] = "\t\t" .. p .. " = " .. bstr(val) .. ","
					else
						outLines[#outLines + 1] = "\t\t" .. p .. " = " .. string.format("%.4f", val or 0) .. ","
					end
				end
				outLines[#outLines + 1] = "\t},"
				outLines[#outLines + 1] = ""

				-- Water colors
				outLines[#outLines + 1] = "\t-- Water colors"
				local waterColorExport = {
					{"absorb", "absorb"}, {"baseColor", "baseColor"}, {"minColor", "minColor"},
					{"surfaceColor", "surfaceColor"}, {"planeColor", "planeColor"},
					{"diffuseColor", "diffuseColor"}, {"specularColor", "specularColor"},
				}
				for _, wce in ipairs(waterColorExport) do
					local c = { gl.GetWaterRendering(wce[2]) }
					outLines[#outLines + 1] = "\twaterColors_" .. wce[1] .. " = " .. fmt3(c) .. ","
				end
				outLines[#outLines + 1] = "}"
				outLines[#outLines + 1] = ""

				local content = table.concat(outLines, "\n")
				local mapSafe = (Game.mapName or "unknown"):gsub("[^%w_%-]", "_")
				local timestamp = os.date("%Y%m%d_%H%M%S")
				local LIGHTMAPS_DIR = "Terraform Brush/Lightmaps/"
				Spring.CreateDir(LIGHTMAPS_DIR)
				local filename = LIGHTMAPS_DIR .. mapSafe .. "_environ_" .. timestamp .. ".lua"

				-- Write file
				local file = io.open(filename, "w")
				if file then
					file:write(content)
					file:close()
					Spring.Echo("[Environ] Saved environment config to: " .. filename)
				else
					Spring.Echo("[Environ] ERROR: Could not write to " .. filename)
				end
				event:StopPropagation()
			end, false)
		end
	-- ============ Skybox Library floating window ============

	widgetState.skyboxLibraryRootEl = doc:GetElementById("tf-skybox-library-root")

	-- Toggle button in environment panel
	local skyboxLibBtn = doc:GetElementById("btn-env-skybox-library")
	if skyboxLibBtn then
		skyboxLibBtn:AddEventListener("click", function(event)
			playSound(widgetState.skyboxLibraryOpen and "click" or "panelOpen")
			widgetState.skyboxLibraryOpen = not widgetState.skyboxLibraryOpen
			if widgetState.skyboxLibraryRootEl then
				widgetState.skyboxLibraryRootEl:SetClass("hidden", not widgetState.skyboxLibraryOpen)
			end
			skyboxLibBtn:SetClass("env-open", widgetState.skyboxLibraryOpen == true)
			event:StopPropagation()
		end, false)
	end

	-- Close button on library window
	local skyboxLibCloseBtn = doc:GetElementById("btn-skybox-library-close")
	if skyboxLibCloseBtn then
		skyboxLibCloseBtn:AddEventListener("click", function(event)
			playSound("click")
			widgetState.skyboxLibraryOpen = false
			if widgetState.skyboxLibraryRootEl then
				widgetState.skyboxLibraryRootEl:SetClass("hidden", true)
			end
			if skyboxLibBtn then skyboxLibBtn:SetClass("env-open", false) end
			event:StopPropagation()
		end, false)
	end

	-- Blue-dot hint wiring: delegated to a module-level helper to avoid
	-- adding more locals to M.attach (which is near the Lua 5.1 200-local cap).
	M._attachHintDots(doc, widgetState)

end

-- Wires click listeners for every entry in widgetState.hintDots:
--   * Clicking any button in h.markOnClick marks the hint seen + saves prefs.
--   * If h.sectionToggleId/sectionId are set, clicking the section toggle
--     while the section becomes open schedules a chip 2-pulse (handled in
--     the main widget Update loop) and marks seen.
function M._attachHintDots(doc, widgetState)
	local hintDots = widgetState.hintDots
	if not hintDots or not doc then return end
	local function makeMarkSeen(prefKey)
		return function()
			if widgetState.uiPrefs and not widgetState.uiPrefs[prefKey] then
				widgetState.uiPrefs[prefKey] = true
				if widgetState.saveUiPrefs then widgetState.saveUiPrefs() end
			end
		end
	end
	for _, h in ipairs(hintDots) do
		local markSeen = makeMarkSeen(h.prefKey)
		if h.sectionToggleId and h.sectionId then
			local sectBtn = doc:GetElementById(h.sectionToggleId)
			if sectBtn then
				local sectionId = h.sectionId
				local pulseKey = h.pulseKey
				sectBtn:AddEventListener("click", function()
					local sec = doc:GetElementById(sectionId)
					if sec and not sec:IsClassSet("hidden") then
						if pulseKey then
							widgetState[pulseKey] = Spring.GetGameFrame() + 1
						end
						markSeen()
					end
				end, false)
			end
		end
		if h.markOnClick then
			for _, btnId in ipairs(h.markOnClick) do
				local b = doc:GetElementById(btnId)
				if b then
					b:AddEventListener("click", function() markSeen() end, false)
				end
			end
		end
	end
end

function M.sync(doc, ctx, setSummary)
	local widgetState = ctx.widgetState
	local uiState = ctx.uiState
	local WG = ctx.WG
	local setActiveClass = ctx.setActiveClass
	local syncAndFlash = ctx.syncAndFlash
	local cadenceToSlider = ctx.cadenceToSlider
	local shapeNames = ctx.shapeNames
		-- ===== Environment mode: highlight button, clear other highlights =====
		local envBtnU = doc and doc:GetElementById("btn-environment")
		if envBtnU then envBtnU:SetClass("active", true) end
		setActiveClass(widgetState.modeButtons, nil)

		setSummary("ENVIRONMENT", "#9ca3af")

end

return M
