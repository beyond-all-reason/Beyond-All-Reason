-- tf_guide.lua: extracted tool module for gui_terraform_brush
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
	local populateKeybindList = ctx.populateKeybindList
	local updateAllKeybindBadges = ctx.updateAllKeybindBadges
	local g3ElemGroup = ctx.g3ElemGroup
	local g3TipGroups = ctx.g3TipGroups
	-- Widget table for inline RML handler registration (onclick="widget:guideFoo()")
	local w = ctx.widget
	assert(w, "tf_guide: ctx.widget required for inline RML handlers")

		widgetState.floatingTipEl = doc:GetElementById("tf-guide-floating-tip")

		local guideBtnEl = doc:GetElementById("btn-guide")
		-- onclick="widget:guideToggle()"
		w.guideToggle = function(self, element)
			widgetState.guideMode = not widgetState.guideMode
			if element then element:SetClass("active", widgetState.guideMode) end
			if not widgetState.guideMode then
				widgetState.currentHint = nil
				widgetState.lastRenderedHint = nil
				if widgetState.floatingTipEl then widgetState.floatingTipEl.inner_rml = "" end
				widgetState.g3Toast.text   = nil
				widgetState.g3Toast.expiry = 0
			end
		end

		local soundBtnEl = doc:GetElementById("btn-sound")
		-- onclick="widget:guideToggleSound()"
		w.guideToggleSound = function(self, element)
			widgetState.soundMuted = not widgetState.soundMuted
			if element then element:SetClass("muted", widgetState.soundMuted) end
		end

		do
			local ptBtn = doc:GetElementById("btn-passthrough")
			local ptIconPause = doc:GetElementById("passthrough-icon-pause")
			local ptIconPlay = doc:GetElementById("passthrough-icon-play")
			-- onclick="widget:guideTogglePassthrough()"
			w.guideTogglePassthrough = function(self)
				if not ptBtn then return end
					if not widgetState.passthroughMode then
						-- Enter passthrough: save current tool, deactivate everything
						local saved = nil
						local tfSt = WG.TerraformBrush and WG.TerraformBrush.getState()
						local fpSt = WG.FeaturePlacer and WG.FeaturePlacer.getState()
						local wbSt = WG.WeatherBrush and WG.WeatherBrush.getState()
						local spSt = WG.SplatPainter and WG.SplatPainter.getState()
						local mbSt = WG.MetalBrush and WG.MetalBrush.getState()
						local gbSt = WG.GrassBrush and WG.GrassBrush.getState()
						local lpSt = WG.LightPlacer and WG.LightPlacer.getState()
						local stSt = WG.StartPosTool and WG.StartPosTool.getState()
						local clSt = WG.CloneTool and WG.CloneTool.getState()
						if tfSt and tfSt.active then
							saved = { tool = "terraform", mode = tfSt.mode }
						elseif fpSt and fpSt.active then
							saved = { tool = "features", mode = fpSt.mode }
						elseif wbSt and wbSt.active then
							saved = { tool = "weather", mode = wbSt.mode }
						elseif spSt and spSt.active then
							saved = { tool = "splat" }
						elseif mbSt and mbSt.active then
							saved = { tool = "metal", mode = mbSt.subMode }
						elseif gbSt and gbSt.active then
							saved = { tool = "grass", mode = gbSt.subMode }
						elseif widgetState.envActive then
							saved = { tool = "environment" }
						elseif widgetState.lightActive and lpSt and lpSt.active then
							saved = { tool = "lights" }
						elseif widgetState.startposActive and stSt and stSt.active then
							saved = { tool = "startpos", mode = stSt.mode }
						elseif widgetState.cloneActive and clSt and clSt.active then
							saved = { tool = "clone" }
						end
						-- Deactivate all tools
						if WG.TerraformBrush then WG.TerraformBrush.deactivate() end
						if WG.FeaturePlacer then WG.FeaturePlacer.deactivate() end
						if WG.WeatherBrush then WG.WeatherBrush.deactivate() end
						if WG.SplatPainter then WG.SplatPainter.deactivate() end
						if WG.MetalBrush then WG.MetalBrush.deactivate() end
						if WG.GrassBrush then WG.GrassBrush.deactivate() end
						if WG.LightPlacer then WG.LightPlacer.deactivate() end
						if WG.StartPosTool then WG.StartPosTool.deactivate() end
						if WG.CloneTool then WG.CloneTool.deactivate() end
						widgetState.envActive = false
						widgetState.lightActive = false
						widgetState.startposActive = false
						widgetState.cloneActive = false
						widgetState.passthroughSaved = saved
						widgetState.passthroughMode = true
						ptBtn:SetClass("active", true)
						if ptIconPause then ptIconPause:SetClass("hidden", true) end
						if ptIconPlay then ptIconPlay:SetClass("hidden", false) end
						if widgetState.rootElement then
							widgetState.rootElement:SetClass("passthrough-dimmed", true)
						end
						playSound("modeSwitch")
					else
						-- Exit passthrough: restore saved tool
						widgetState.passthroughMode = false
						ptBtn:SetClass("active", false)
						if ptIconPause then ptIconPause:SetClass("hidden", false) end
						if ptIconPlay then ptIconPlay:SetClass("hidden", true) end
						if widgetState.rootElement then
							widgetState.rootElement:SetClass("passthrough-dimmed", false)
						end
						local s = widgetState.passthroughSaved
						widgetState.passthroughSaved = nil
						if s then
							if s.tool == "terraform" and WG.TerraformBrush then
								WG.TerraformBrush.setMode(s.mode or "raise")
							elseif s.tool == "features" and WG.FeaturePlacer then
								WG.FeaturePlacer.setMode(s.mode or "scatter")
							elseif s.tool == "weather" and WG.WeatherBrush then
								WG.WeatherBrush.setMode(s.mode or "place")
							elseif s.tool == "splat" and WG.SplatPainter then
								WG.SplatPainter.setMode("paint")
							elseif s.tool == "metal" and WG.MetalBrush then
								WG.MetalBrush.setMode(s.mode or "add")
							elseif s.tool == "grass" and WG.GrassBrush then
								WG.GrassBrush.setMode(s.mode or "add")
							elseif s.tool == "environment" then
								widgetState.envActive = true
							elseif s.tool == "lights" and WG.LightPlacer then
								widgetState.lightActive = true
								WG.LightPlacer.setMode("scatter")
							elseif s.tool == "startpos" and WG.StartPosTool then
								widgetState.startposActive = true
								WG.StartPosTool.setMode(s.mode or "express")
							elseif s.tool == "clone" and WG.CloneTool then
								widgetState.cloneActive = true
								WG.CloneTool.activate()
							end
						end
					playSound("modeSwitch")
				end
			end
		end

		-- ============ Settings window (gear button) ============
		do
			widgetState.settingsRootEl = doc:GetElementById("tf-settings-root")
			local settingsBtn = doc:GetElementById("btn-settings")
			local settingsCloseBtn = doc:GetElementById("btn-settings-close")

			local function toggleSettings()
				widgetState.settingsOpen = not widgetState.settingsOpen
				if widgetState.settingsRootEl then
					widgetState.settingsRootEl:SetClass("hidden", not widgetState.settingsOpen)
				end
				if settingsBtn then
					settingsBtn:SetClass("active", widgetState.settingsOpen)
				end
				if widgetState.settingsOpen then
					-- Snapshot current keybinds for editing
					if WG.TerraformBrush and WG.TerraformBrush.getKeybinds then
						widgetState.settingsPendingBinds = WG.TerraformBrush.getKeybinds()
					end
					widgetState.settingsCapturing = nil
					widgetState.settingsCaptureField = nil
					widgetState.settingsCaptureEl = nil
					populateKeybindList(doc)
				end
			end

			w.guideToggleSettings = function(self)
				toggleSettings()
			end

			w.guideCloseSettings = function(self)
				widgetState.settingsOpen = false
				widgetState.settingsCapturing = nil
				widgetState.settingsCaptureField = nil
				widgetState.settingsCaptureEl = nil
				if widgetState.settingsRootEl then
					widgetState.settingsRootEl:SetClass("hidden", true)
				end
				if settingsBtn then settingsBtn:SetClass("active", false) end
			end

			w.guideKbSave = function(self)
				if WG.TerraformBrush and widgetState.settingsPendingBinds then
					WG.TerraformBrush.applyKeybinds(widgetState.settingsPendingBinds)
					WG.TerraformBrush.saveKeybinds()
					updateAllKeybindBadges()
					Spring.Echo("[Terraform Brush] Keybinds saved.")
				end
			end

			w.guideKbApply = function(self)
				if WG.TerraformBrush and widgetState.settingsPendingBinds then
					WG.TerraformBrush.applyKeybinds(widgetState.settingsPendingBinds)
					updateAllKeybindBadges()
					Spring.Echo("[Terraform Brush] Keybinds applied.")
				end
			end

			w.guideKbDefaults = function(self)
				if WG.TerraformBrush and WG.TerraformBrush.getDefaultKeybinds then
					widgetState.settingsPendingBinds = WG.TerraformBrush.getDefaultKeybinds()
					widgetState.settingsCapturing = nil
					widgetState.settingsCaptureField = nil
					widgetState.settingsCaptureEl = nil
					populateKeybindList(doc)
				end
			end

			w.guideKbCancel = function(self)
				widgetState.settingsOpen = false
				widgetState.settingsCapturing = nil
				widgetState.settingsCaptureField = nil
				widgetState.settingsCaptureEl = nil
				widgetState.settingsPendingBinds = nil
				if widgetState.settingsRootEl then
					widgetState.settingsRootEl:SetClass("hidden", true)
				end
				if settingsBtn then settingsBtn:SetClass("active", false) end
			end
		end

		-- ============ Settings: tab switching (Keybinds / DJ Mode / Stroke / General) ============
		do
			local tabKeybindsBtn = doc:GetElementById("btn-settings-tab-keybinds")
			local tabDJBtn       = doc:GetElementById("btn-settings-tab-dj")
			local tabStrokeBtn   = doc:GetElementById("btn-settings-tab-stroke")
			local tabGeneralBtn  = doc:GetElementById("btn-settings-tab-general")
			local tabKeybinds    = doc:GetElementById("settings-tab-keybinds")
			local tabDJ          = doc:GetElementById("settings-tab-dj")
			local tabStroke      = doc:GetElementById("settings-tab-stroke")
			local tabGeneral     = doc:GetElementById("settings-tab-general")

			local function switchSettingsTab(tab)
				if tabKeybindsBtn then tabKeybindsBtn:SetClass("active", tab == "keybinds") end
				if tabDJBtn       then tabDJBtn:SetClass("active", tab == "dj") end
				if tabStrokeBtn   then tabStrokeBtn:SetClass("active", tab == "stroke") end
				if tabGeneralBtn  then tabGeneralBtn:SetClass("active", tab == "general") end
				if tabKeybinds    then tabKeybinds:SetClass("hidden", tab ~= "keybinds") end
				if tabDJ          then tabDJ:SetClass("hidden", tab ~= "dj") end
				if tabStroke      then tabStroke:SetClass("hidden", tab ~= "stroke") end
				if tabGeneral     then tabGeneral:SetClass("hidden", tab ~= "general") end
			end

			if tabKeybindsBtn then
				-- onclick="widget:guideTab('keybinds')"
			end
			w.guideTab = function(self, name)
				switchSettingsTab(name)
			end
		end

		-- ============ Settings: General tab — Disable tips/tool recommendations ============
		do
			local btn = doc:GetElementById("btn-ui-disable-tips")
			local pill = doc:GetElementById("pill-ui-disable-tips")
			local function syncPill()
				local on = widgetState.uiPrefs and widgetState.uiPrefs.disableTips
				if pill then pill.inner_rml = on and "ON" or "OFF" end
				if btn then btn:SetClass("active", on and true or false) end
			end
			syncPill()
			widgetState.syncDisableTipsPill = syncPill
			if btn then
				-- onclick="widget:guideToggleDisableTips()"
			end
			w.guideToggleDisableTips = function(self)
				widgetState.uiPrefs = widgetState.uiPrefs or {}
				local newVal = not widgetState.uiPrefs.disableTips
				widgetState.uiPrefs.disableTips = newVal
				playSound(newVal and "toggleOn" or "toggleOff")
				syncPill()
				if widgetState.saveUiPrefs then widgetState.saveUiPrefs() end
				if newVal then
					widgetState.instrumentsHintActive = false
					local measureImg = doc:GetElementById("btn-measure")
					if measureImg then measureImg:SetClass("tf-chip-2pulse", false) end
					local splatChip = doc:GetElementById("btn-sp-splat-overlay")
					if splatChip then splatChip:SetClass("tf-chip-2pulse", false) end
				end
			end
		end

		-- ============ DJ Mode: Master Activate Toggle ============
		do
			local activateBtn = doc:GetElementById("btn-dj-activate")
			-- onclick="widget:guideToggleDjActivate()"
			w.guideToggleDjActivate = function(self)
				if not activateBtn then return end
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					local newVal = not (state and state.djMode)
					playSound(newVal and "toggleOn" or "toggleOff")
					WG.TerraformBrush.setDjMode(newVal)
					activateBtn:SetClass("active", newVal)
					local pill = doc:GetElementById("pill-dj-activate")
					if pill then pill.inner_rml = newVal and "ON" or "OFF" end
					local subSettings = doc:GetElementById("dj-sub-settings")
					if subSettings then subSettings:SetClass("dj-disabled", not newVal) end
				end
			end
		end

		-- ============ DJ Mode: Dust Visual Effects ============
		do
			local dustBtn = doc:GetElementById("btn-dust-effects")
			-- onclick="widget:guideToggleDust()"
			w.guideToggleDust = function(self)
				if not dustBtn then return end
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					local newVal = not (state and state.dustEffects)
					playSound(newVal and "toggleOn" or "toggleOff")
					WG.TerraformBrush.setDustEffects(newVal)
					dustBtn:SetClass("active", newVal)
					local pill = doc:GetElementById("pill-dust-effects")
					if pill then pill.inner_rml = newVal and "ON" or "OFF" end
				end
			end
		end

		-- ============ DJ Mode: Seismic Sound Effects ============
		do
			local seismicBtn = doc:GetElementById("btn-seismic-effects")
			-- onclick="widget:guideToggleSeismic()"
			w.guideToggleSeismic = function(self)
				if not seismicBtn then return end
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					local newVal = not (state and state.seismicEffects)
					playSound(newVal and "toggleOn" or "toggleOff")
					WG.TerraformBrush.setSeismicEffects(newVal)
					seismicBtn:SetClass("active", newVal)
					local pill = doc:GetElementById("pill-seismic-effects")
					if pill then pill.inner_rml = newVal and "ON" or "OFF" end
				end
			end
		end

		-- ============ Stroke: Pen Pressure ============
		do
			local penToggleBtn = doc:GetElementById("btn-pen-pressure-toggle")
			local penSub = doc:GetElementById("pen-pressure-sub")
			-- onclick="widget:guideTogglePenPressure()"
			w.guideTogglePenPressure = function(self)
				if not penToggleBtn then return end
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					local newVal = not (state and state.penPressureEnabled)
					playSound(newVal and "toggleOn" or "toggleOff")
					WG.TerraformBrush.setPenPressure(newVal)
					penToggleBtn:SetClass("active", newVal)
					local pill = doc:GetElementById("pill-pen-pressure")
					if pill then pill.inner_rml = newVal and "ON" or "OFF" end
					if penSub then penSub:SetClass("dj-disabled", not newVal) end
				end
			end
			local modIntBtn = doc:GetElementById("btn-pen-mod-intensity")
			-- onclick="widget:guideTogglePenModInt()"
			w.guideTogglePenModInt = function(self)
				if not modIntBtn then return end
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					local newVal = not (state and state.penPressureModulateIntensity)
					WG.TerraformBrush.setPenPressureModulateIntensity(newVal)
					modIntBtn:SetAttribute("src", newVal and "/luaui/images/terraform_brush/check_on.png" or "/luaui/images/terraform_brush/check_off.png")
				end
			end
			local modSizeBtn = doc:GetElementById("btn-pen-mod-size")
			-- onclick="widget:guideTogglePenModSize()"
			w.guideTogglePenModSize = function(self)
				if not modSizeBtn then return end
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					local newVal = not (state and state.penPressureModulateSize)
					WG.TerraformBrush.setPenPressureModulateSize(newVal)
					modSizeBtn:SetAttribute("src", newVal and "/luaui/images/terraform_brush/check_on.png" or "/luaui/images/terraform_brush/check_off.png")
				end
			end
			local sensSlider = doc:GetElementById("slider-pen-sensitivity")
			-- onchange="widget:guidePenSensitivityChange(element); event:StopPropagation()"
			w.guidePenSensitivityChange = function(self, element)
				if uiState.updatingFromCode then return end
				if WG.TerraformBrush and element then
					local val = tonumber(element:GetAttribute("value")) or 100
					WG.TerraformBrush.setPenPressureSensitivity(val / 100)
					local lbl = doc:GetElementById("pen-sensitivity-label")
					if lbl then lbl.inner_rml = tostring(math.floor(val)) end
				end
			end
			local curveIds = {
				["btn-curve-linear"] = 1, ["btn-curve-quad"] = 2, ["btn-curve-cubic"] = 3,
				["btn-curve-scurve"] = 4, ["btn-curve-log"] = 5,
			}
			local curveIdsByN = {}
			for id, n in pairs(curveIds) do curveIdsByN[n] = id end
			-- onclick="widget:guideSetCurve(N)" with N in 1..5
			w.guideSetCurve = function(self, n)
				if not WG.TerraformBrush then return end
				WG.TerraformBrush.setPenPressureCurve(n)
				local activeId = curveIdsByN[n]
				for cid, _ in pairs(curveIds) do
					local el = doc:GetElementById(cid)
					if el then el:SetClass("active", cid == activeId) end
				end
			end
		end

		-- ============ Stroke: Brush Wiggle ============
		do
			local wiggleBtn = doc:GetElementById("btn-wiggle-toggle")
			local wiggleSub = doc:GetElementById("wiggle-sub")
			local function refreshWiggleChips(ampIdx, spdIdx)
				for i = 1, 4 do
					local a = doc:GetElementById("btn-wiggle-amp-" .. i)
					local s = doc:GetElementById("btn-wiggle-spd-" .. i)
					if a then a:SetClass("active", i == ampIdx) end
					if s then s:SetClass("active", i == spdIdx) end
				end
			end
			-- onclick="widget:guideToggleWiggle()"
			w.guideToggleWiggle = function(self)
				if not wiggleBtn then return end
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					local newVal = not (state and state.wiggleEnabled)
					playSound(newVal and "toggleOn" or "toggleOff")
					WG.TerraformBrush.setWiggle(newVal, state and state.wiggleAmpIdx or 1, state and state.wiggleSpdIdx or 1)
					wiggleBtn:SetClass("active", newVal)
					local pill = doc:GetElementById("pill-wiggle-toggle")
					if pill then pill.inner_rml = newVal and "ON" or "OFF" end
					if wiggleSub then wiggleSub:SetClass("dj-disabled", not newVal) end
				end
			end
			-- onclick="widget:guideWiggleAmp(N)" with N in 1..4
			w.guideWiggleAmp = function(self, i)
				if not WG.TerraformBrush then return end
				local state = WG.TerraformBrush.getState()
				WG.TerraformBrush.setWiggle(state and state.wiggleEnabled, i, state and state.wiggleSpdIdx or 1)
				refreshWiggleChips(i, state and state.wiggleSpdIdx or 1)
			end
			-- onclick="widget:guideWiggleSpd(N)" with N in 1..4
			w.guideWiggleSpd = function(self, i)
				if not WG.TerraformBrush then return end
				local state = WG.TerraformBrush.getState()
				WG.TerraformBrush.setWiggle(state and state.wiggleEnabled, state and state.wiggleAmpIdx or 1, i)
				refreshWiggleChips(state and state.wiggleAmpIdx or 1, i)
			end
		end

		for elemId, hint in pairs(guideHints) do
			local el = doc:GetElementById(elemId)
			if el then
				el:AddEventListener("mouseover", function(event)
					if widgetState.guideMode then widgetState.currentHint = hint end
				end, false)
				el:AddEventListener("mouseout", function(event)
					if widgetState.guideMode then widgetState.currentHint = nil end
				end, false)
			end
		end

		-- G3: Shortcut discovery tips — fire near cursor after 3 interactions (guide mode only)
		for elemId, group in pairs(g3ElemGroup) do
			local el = doc:GetElementById(elemId)
			if el then
				el:AddEventListener("mousedown", function(event)
					if not widgetState.guideMode then return end
					local cnt = (widgetState.g3GroupCounts[group] or 0) + 1
					widgetState.g3GroupCounts[group] = cnt
					if cnt >= 3 and not widgetState.g3GroupShown[group] then
						widgetState.g3GroupShown[group] = true
						widgetState.g3Toast.text   = g3TipGroups[group]
						widgetState.g3Toast.expiry = (Spring.GetGameSeconds() or 0) + 5
					end
				end, false)
			end
		end
end

return M
