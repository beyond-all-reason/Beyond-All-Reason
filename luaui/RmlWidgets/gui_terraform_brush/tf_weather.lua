-- tf_weather.lua: extracted tool module for gui_terraform_brush
local M = {}

function M.attach(doc, ctx)
	if ctx.attachTBMirrorControls then ctx.attachTBMirrorControls(doc, "wb") end
	local widgetState = ctx.widgetState
	local uiState = ctx.uiState
	local WG = ctx.WG
	local playSound = ctx.playSound
	local trackSliderDrag = ctx.trackSliderDrag
	local ROTATION_STEP = ctx.ROTATION_STEP
	local LENGTH_SCALE_STEP = ctx.LENGTH_SCALE_STEP
	local RADIUS_STEP = ctx.RADIUS_STEP
	local sliderToCadence = ctx.sliderToCadence
	local sliderToFrequency = ctx.sliderToFrequency
	local sliderToPersist = ctx.sliderToPersist
	local PERSIST_PERMANENT_VAL = ctx.PERSIST_PERMANENT_VAL
	-- ============ Weather Brush controls ============

	widgetState.wbSubmodesEl = doc:GetElementById("tf-weather-submodes")
	widgetState.wbControlsEl = doc:GetElementById("tf-weather-controls")

	-- Slider drag tracking (legitimate imperative: slider-specific drag state).
	-- Slider change events are wired declaratively via onchange= in RML.
	for _, sid in ipairs({ "size", "length", "rotation", "count", "cadence", "frequency", "persist" }) do
		local sl = doc:GetElementById("wb-slider-" .. sid)
		if sl then trackSliderDrag(sl, "wb-" .. sid) end
	end

	-- Register widget methods for inline onclick/onchange handlers in RML.
	local w = ctx.widget
	if not w then return end

	w.wbSetMode = function(self, wmode)
		playSound("modeSwitch")
		if WG.WeatherBrush then WG.WeatherBrush.setMode(wmode) end
		if widgetState.dmHandle then widgetState.dmHandle.wbSubMode = wmode end
	end

	w.wbSetDist = function(self, dist)
		playSound("shapeSwitch")
		if WG.WeatherBrush then WG.WeatherBrush.setDistribution(dist) end
		if widgetState.dmHandle then widgetState.dmHandle.wbDistMode = dist end
	end

	-- Size
	w.wbOnSizeChange = function(self, element)
		if uiState.updatingFromCode or not WG.WeatherBrush then return end
		local val = element and tonumber(element:GetAttribute("value")) or 200
		WG.WeatherBrush.setRadius(val)
	end
	w.wbSizeUp = function(self)
		if WG.WeatherBrush then
			local st = WG.WeatherBrush.getState()
			WG.WeatherBrush.setRadius(st.radius + RADIUS_STEP * 4)
		end
	end
	w.wbSizeDown = function(self)
		if WG.WeatherBrush then
			local st = WG.WeatherBrush.getState()
			WG.WeatherBrush.setRadius(st.radius - RADIUS_STEP * 4)
		end
	end

	-- Length
	w.wbOnLengthChange = function(self, element)
		if uiState.updatingFromCode or not WG.WeatherBrush then return end
		local val = element and tonumber(element:GetAttribute("value")) or 10
		WG.WeatherBrush.setLengthScale(val / 10)
	end
	w.wbLengthUp = function(self)
		if WG.WeatherBrush then
			local st = WG.WeatherBrush.getState()
			WG.WeatherBrush.setLengthScale(st.lengthScale + LENGTH_SCALE_STEP)
		end
	end
	w.wbLengthDown = function(self)
		if WG.WeatherBrush then
			local st = WG.WeatherBrush.getState()
			WG.WeatherBrush.setLengthScale(st.lengthScale - LENGTH_SCALE_STEP)
		end
	end

	-- Rotation
	w.wbOnRotChange = function(self, element)
		if uiState.updatingFromCode or not WG.WeatherBrush then return end
		local val = element and tonumber(element:GetAttribute("value")) or 0
		WG.WeatherBrush.setRotation(val)
	end
	w.wbRotCW = function(self)
		if WG.WeatherBrush then WG.WeatherBrush.rotate(ROTATION_STEP) end
	end
	w.wbRotCCW = function(self)
		if WG.WeatherBrush then WG.WeatherBrush.rotate(-ROTATION_STEP) end
	end

	-- Count
	w.wbOnCountChange = function(self, element)
		if uiState.updatingFromCode or not WG.WeatherBrush then return end
		local val = element and tonumber(element:GetAttribute("value")) or 3
		WG.WeatherBrush.setSpawnCount(val)
	end
	w.wbCountUp = function(self)
		if WG.WeatherBrush then
			local st = WG.WeatherBrush.getState()
			WG.WeatherBrush.setSpawnCount(st.spawnCount + 1)
		end
	end
	w.wbCountDown = function(self)
		if WG.WeatherBrush then
			local st = WG.WeatherBrush.getState()
			WG.WeatherBrush.setSpawnCount(st.spawnCount - 1)
		end
	end

	-- Cadence
	w.wbOnCadenceChange = function(self, element)
		if uiState.updatingFromCode or not WG.WeatherBrush then return end
		local sliderVal = element and tonumber(element:GetAttribute("value")) or 0
		WG.WeatherBrush.setCadence(sliderToCadence(sliderVal))
	end
	w.wbCadenceUp = function(self)
		if WG.WeatherBrush then
			local st = WG.WeatherBrush.getState()
			local step = math.max(1, math.floor(st.cadence * 0.2))
			WG.WeatherBrush.setCadence(st.cadence + step)
		end
	end
	w.wbCadenceDown = function(self)
		if WG.WeatherBrush then
			local st = WG.WeatherBrush.getState()
			local step = math.max(1, math.floor(st.cadence * 0.2))
			WG.WeatherBrush.setCadence(st.cadence - step)
		end
	end

	-- Frequency
	w.wbOnFrequencyChange = function(self, element)
		if uiState.updatingFromCode or not WG.WeatherBrush then return end
		local sliderVal = element and tonumber(element:GetAttribute("value")) or 0
		WG.WeatherBrush.setFrequency(sliderToFrequency(sliderVal))
	end
	w.wbFrequencyUp = function(self)
		if WG.WeatherBrush then
			local st = WG.WeatherBrush.getState()
			local step = math.max(0.1, st.frequency * 0.2)
			WG.WeatherBrush.setFrequency(st.frequency + step)
		end
	end
	w.wbFrequencyDown = function(self)
		if WG.WeatherBrush then
			local st = WG.WeatherBrush.getState()
			local step = math.max(0.1, st.frequency * 0.2)
			WG.WeatherBrush.setFrequency(st.frequency - step)
		end
	end

	-- Persistence (piecewise log mapping)
	w.wbOnPersistChange = function(self, element)
		if uiState.updatingFromCode or not WG.WeatherBrush then return end
		local sliderVal = element and tonumber(element:GetAttribute("value")) or 0
		local seconds = sliderToPersist(sliderVal)
		WG.WeatherBrush.setPersistenceSeconds(seconds)
	end

	-- Persistent (permanent) toggle
	w.wbTogglePersistent = function(self)
		if WG.WeatherBrush then
			local wbs = WG.WeatherBrush.getState()
			local isPerm = wbs and wbs.persistenceSeconds >= PERSIST_PERMANENT_VAL
			if isPerm then
				WG.WeatherBrush.setPersistenceSeconds(0)
			else
				WG.WeatherBrush.setPersistenceSeconds(PERSIST_PERMANENT_VAL)
			end
		end
	end

	-- Clear All persistent effects
	w.wbClearAll = function(self)
		playSound("reset")
		if WG.WeatherBrush then WG.WeatherBrush.clearAllPersistent() end
	end

end

return M
