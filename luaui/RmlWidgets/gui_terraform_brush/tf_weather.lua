-- tf_weather.lua: extracted tool module for gui_terraform_brush
local M = {}

function M.attach(doc, ctx)
	if ctx.attachTBMirrorControls then ctx.attachTBMirrorControls(doc, "wb") end
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
	-- ============ Weather Brush controls ============

	widgetState.wbSubmodesEl = doc:GetElementById("tf-weather-submodes")
	widgetState.wbControlsEl = doc:GetElementById("tf-weather-controls")

	-- Weather sub-mode buttons
	widgetState.wbSubModeButtons.scatter = doc:GetElementById("btn-wb-scatter")
	widgetState.wbSubModeButtons.point = doc:GetElementById("btn-wb-point")
	widgetState.wbSubModeButtons.remove = doc:GetElementById("btn-wb-remove")

	for wmode, element in pairs(widgetState.wbSubModeButtons) do
		if element then
			element:AddEventListener("click", function(event)
				playSound("modeSwitch")
				if WG.WeatherBrush then WG.WeatherBrush.setMode(wmode) end
				setActiveClass(widgetState.wbSubModeButtons, wmode)
				event:StopPropagation()
			end, false)
		end
	end

	-- Weather distribution buttons
	widgetState.wbDistButtons.random = doc:GetElementById("btn-wb-dist-random")
	widgetState.wbDistButtons.regular = doc:GetElementById("btn-wb-dist-regular")
	widgetState.wbDistButtons.clustered = doc:GetElementById("btn-wb-dist-clustered")

	for dist, element in pairs(widgetState.wbDistButtons) do
		if element then
			element:AddEventListener("click", function(event)
				playSound("shapeSwitch")
				if WG.WeatherBrush then WG.WeatherBrush.setDistribution(dist) end
				setActiveClass(widgetState.wbDistButtons, dist)
				event:StopPropagation()
			end, false)
		end
	end

	-- Weather size slider + buttons
	local wbSliderSize = doc:GetElementById("wb-slider-size")
	if wbSliderSize then
		trackSliderDrag(wbSliderSize, "wb-size")
		wbSliderSize:AddEventListener("change", function(event)
			if not uiState.updatingFromCode and WG.WeatherBrush then
				local val = tonumber(wbSliderSize:GetAttribute("value")) or 200
				WG.WeatherBrush.setRadius(val)
			end
			event:StopPropagation()
		end, false)
	end

	local wbSizeUp = doc:GetElementById("btn-wb-size-up")
	if wbSizeUp then
		wbSizeUp:AddEventListener("click", function(event)
			if WG.WeatherBrush then
				local st = WG.WeatherBrush.getState()
				WG.WeatherBrush.setRadius(st.radius + RADIUS_STEP * 4)
			end
			event:StopPropagation()
		end, false)
	end

	local wbSizeDown = doc:GetElementById("btn-wb-size-down")
	if wbSizeDown then
		wbSizeDown:AddEventListener("click", function(event)
			if WG.WeatherBrush then
				local st = WG.WeatherBrush.getState()
				WG.WeatherBrush.setRadius(st.radius - RADIUS_STEP * 4)
			end
			event:StopPropagation()
		end, false)
	end

	-- Weather length slider + buttons
	local wbSliderLength = doc:GetElementById("wb-slider-length")
	if wbSliderLength then
		trackSliderDrag(wbSliderLength, "wb-length")
		wbSliderLength:AddEventListener("change", function(event)
			if not uiState.updatingFromCode and WG.WeatherBrush then
				local val = tonumber(wbSliderLength:GetAttribute("value")) or 10
				WG.WeatherBrush.setLengthScale(val / 10)
			end
			event:StopPropagation()
		end, false)
	end

	local wbLengthUp = doc:GetElementById("btn-wb-length-up")
	if wbLengthUp then
		wbLengthUp:AddEventListener("click", function(event)
			if WG.WeatherBrush then
				local st = WG.WeatherBrush.getState()
				WG.WeatherBrush.setLengthScale(st.lengthScale + LENGTH_SCALE_STEP)
			end
			event:StopPropagation()
		end, false)
	end

	local wbLengthDown = doc:GetElementById("btn-wb-length-down")
	if wbLengthDown then
		wbLengthDown:AddEventListener("click", function(event)
			if WG.WeatherBrush then
				local st = WG.WeatherBrush.getState()
				WG.WeatherBrush.setLengthScale(st.lengthScale - LENGTH_SCALE_STEP)
			end
			event:StopPropagation()
		end, false)
	end

	-- Weather rotation slider + buttons
	local wbSliderRotation = doc:GetElementById("wb-slider-rotation")
	if wbSliderRotation then
		trackSliderDrag(wbSliderRotation, "wb-rotation")
		wbSliderRotation:AddEventListener("change", function(event)
			if not uiState.updatingFromCode and WG.WeatherBrush then
				local val = tonumber(wbSliderRotation:GetAttribute("value")) or 0
				WG.WeatherBrush.setRotation(val)
			end
			event:StopPropagation()
		end, false)
	end

	local wbRotCW = doc:GetElementById("btn-wb-rot-cw")
	if wbRotCW then
		wbRotCW:AddEventListener("click", function(event)
			if WG.WeatherBrush then WG.WeatherBrush.rotate(ROTATION_STEP) end
			event:StopPropagation()
		end, false)
	end

	local wbRotCCW = doc:GetElementById("btn-wb-rot-ccw")
	if wbRotCCW then
		wbRotCCW:AddEventListener("click", function(event)
			if WG.WeatherBrush then WG.WeatherBrush.rotate(-ROTATION_STEP) end
			event:StopPropagation()
		end, false)
	end

	-- Weather count slider + buttons
	local wbSliderCount = doc:GetElementById("wb-slider-count")
	if wbSliderCount then
		trackSliderDrag(wbSliderCount, "wb-count")
		wbSliderCount:AddEventListener("change", function(event)
			if not uiState.updatingFromCode and WG.WeatherBrush then
				local val = tonumber(wbSliderCount:GetAttribute("value")) or 3
				WG.WeatherBrush.setSpawnCount(val)
			end
			event:StopPropagation()
		end, false)
	end

	local wbCountUp = doc:GetElementById("btn-wb-count-up")
	if wbCountUp then
		wbCountUp:AddEventListener("click", function(event)
			if WG.WeatherBrush then
				local st = WG.WeatherBrush.getState()
				WG.WeatherBrush.setSpawnCount(st.spawnCount + 1)
			end
			event:StopPropagation()
		end, false)
	end

	local wbCountDown = doc:GetElementById("btn-wb-count-down")
	if wbCountDown then
		wbCountDown:AddEventListener("click", function(event)
			if WG.WeatherBrush then
				local st = WG.WeatherBrush.getState()
				WG.WeatherBrush.setSpawnCount(st.spawnCount - 1)
			end
			event:StopPropagation()
		end, false)
	end

	-- Weather cadence slider + buttons
	local wbSliderCadence = doc:GetElementById("wb-slider-cadence")
	if wbSliderCadence then
		trackSliderDrag(wbSliderCadence, "wb-cadence")
		wbSliderCadence:AddEventListener("change", function(event)
			if not uiState.updatingFromCode and WG.WeatherBrush then
				local sliderVal = tonumber(wbSliderCadence:GetAttribute("value")) or 0
				WG.WeatherBrush.setCadence(sliderToCadence(sliderVal))
			end
			event:StopPropagation()
		end, false)
	end

	local wbCadenceUp = doc:GetElementById("btn-wb-cadence-up")
	if wbCadenceUp then
		wbCadenceUp:AddEventListener("click", function(event)
			if WG.WeatherBrush then
				local st = WG.WeatherBrush.getState()
				local step = math.max(1, math.floor(st.cadence * 0.2))
				WG.WeatherBrush.setCadence(st.cadence + step)
			end
			event:StopPropagation()
		end, false)
	end

	local wbCadenceDown = doc:GetElementById("btn-wb-cadence-down")
	if wbCadenceDown then
		wbCadenceDown:AddEventListener("click", function(event)
			if WG.WeatherBrush then
				local st = WG.WeatherBrush.getState()
				local step = math.max(1, math.floor(st.cadence * 0.2))
				WG.WeatherBrush.setCadence(st.cadence - step)
			end
			event:StopPropagation()
		end, false)
	end

	-- Weather frequency slider + buttons
	local wbSliderFrequency = doc:GetElementById("wb-slider-frequency")
	if wbSliderFrequency then
		trackSliderDrag(wbSliderFrequency, "wb-frequency")
		wbSliderFrequency:AddEventListener("change", function(event)
			if not uiState.updatingFromCode and WG.WeatherBrush then
				local sliderVal = tonumber(wbSliderFrequency:GetAttribute("value")) or 0
				WG.WeatherBrush.setFrequency(sliderToFrequency(sliderVal))
			end
			event:StopPropagation()
		end, false)
	end

	local wbFrequencyUp = doc:GetElementById("btn-wb-frequency-up")
	if wbFrequencyUp then
		wbFrequencyUp:AddEventListener("click", function(event)
			if WG.WeatherBrush then
				local st = WG.WeatherBrush.getState()
				local step = math.max(0.1, st.frequency * 0.2)
				WG.WeatherBrush.setFrequency(st.frequency + step)
			end
			event:StopPropagation()
		end, false)
	end

	local wbFrequencyDown = doc:GetElementById("btn-wb-frequency-down")
	if wbFrequencyDown then
		wbFrequencyDown:AddEventListener("click", function(event)
			if WG.WeatherBrush then
				local st = WG.WeatherBrush.getState()
				local step = math.max(0.1, st.frequency * 0.2)
				WG.WeatherBrush.setFrequency(st.frequency - step)
			end
			event:StopPropagation()
		end, false)
	end

	-- Weather persistence slider (piecewise log mapping)
	local wbSliderPersist = doc:GetElementById("wb-slider-persist")
	if wbSliderPersist then
		trackSliderDrag(wbSliderPersist, "wb-persist")
		wbSliderPersist:AddEventListener("change", function(event)
			if not uiState.updatingFromCode and WG.WeatherBrush then
				local sliderVal = tonumber(wbSliderPersist:GetAttribute("value")) or 0
				local seconds = sliderToPersist(sliderVal)
				WG.WeatherBrush.setPersistenceSeconds(seconds)
			end
			event:StopPropagation()
		end, false)
	end

	-- Weather persistent mode toggle
	local wbPersistToggle = doc:GetElementById("btn-wb-persistent")
	if wbPersistToggle then
		wbPersistToggle:AddEventListener("click", function(event)
			if WG.WeatherBrush then
				local wbs = WG.WeatherBrush.getState()
				local isPerm = wbs and wbs.persistenceSeconds >= PERSIST_PERMANENT_VAL
				if isPerm then
					WG.WeatherBrush.setPersistenceSeconds(0)
				else
					WG.WeatherBrush.setPersistenceSeconds(PERSIST_PERMANENT_VAL)
				end
			end
			event:StopPropagation()
		end, false)
	end

	-- Weather Clear All button
	local wbClearAllBtn = doc:GetElementById("btn-wb-clearall")
	if wbClearAllBtn then
		wbClearAllBtn:AddEventListener("click", function(event)
			playSound("reset")
			if WG.WeatherBrush then WG.WeatherBrush.clearAllPersistent() end
			event:StopPropagation()
		end, false)
	end

end

return M
