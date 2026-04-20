-- tf_noise.lua: extracted tool module for gui_terraform_brush
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
	-- ============ Noise Brush controls ============

	widgetState.noiseRootEl = doc:GetElementById("tf-noise-root")

	-- Noise close button
	local noiseCloseBtn = doc:GetElementById("btn-noise-close")
	if noiseCloseBtn then
		noiseCloseBtn:AddEventListener("click", function(event)
			playSound("click")
			widgetState.noiseManuallyHidden = true
			if widgetState.noiseRootEl then
				widgetState.noiseRootEl:SetClass("hidden", true)
			end
			event:StopPropagation()
		end, false)
	end

	-- Noise type buttons
	widgetState.noiseTypeButtons.perlin = doc:GetElementById("btn-noise-perlin")
	widgetState.noiseTypeButtons.voronoi = doc:GetElementById("btn-noise-voronoi")
	widgetState.noiseTypeButtons.fbm = doc:GetElementById("btn-noise-fbm")
	widgetState.noiseTypeButtons.billow = doc:GetElementById("btn-noise-billow")

	for ntype, element in pairs(widgetState.noiseTypeButtons) do
		if element then
			element:AddEventListener("click", function(event)
				playSound("modeSwitch")
				if WG.TerraformBrush then WG.TerraformBrush.setNoiseType(ntype) end
				setActiveClass(widgetState.noiseTypeButtons, ntype)
				event:StopPropagation()
			end, false)
		end
	end

	-- Noise scale slider + buttons
	local noiseSliderScale = doc:GetElementById("slider-noise-scale")
	if noiseSliderScale then
		trackSliderDrag(noiseSliderScale, "noise-scale")
		noiseSliderScale:AddEventListener("change", function(event)
			if not uiState.updatingFromCode and WG.TerraformBrush then
				local val = tonumber(noiseSliderScale:GetAttribute("value")) or 64
				WG.TerraformBrush.setNoiseScale(val)
				local label = doc:GetElementById("noise-scale-label")
				if label then label.inner_rml = tostring(val) end
			end
			event:StopPropagation()
		end, false)
	end

	local noiseBtn = doc:GetElementById("btn-noise-scale-up")
	if noiseBtn then
		noiseBtn:AddEventListener("click", function(event)
			if WG.TerraformBrush and noiseSliderScale then
				local val = math.min(512, (tonumber(noiseSliderScale:GetAttribute("value")) or 64) + 8)
				WG.TerraformBrush.setNoiseScale(val)
				noiseSliderScale:SetAttribute("value", tostring(val))
				local label = doc:GetElementById("noise-scale-label")
				if label then label.inner_rml = tostring(val) end
			end
			event:StopPropagation()
		end, false)
	end

	noiseBtn = doc:GetElementById("btn-noise-scale-down")
	if noiseBtn then
		noiseBtn:AddEventListener("click", function(event)
			if WG.TerraformBrush and noiseSliderScale then
				local val = math.max(8, (tonumber(noiseSliderScale:GetAttribute("value")) or 64) - 8)
				WG.TerraformBrush.setNoiseScale(val)
				noiseSliderScale:SetAttribute("value", tostring(val))
				local label = doc:GetElementById("noise-scale-label")
				if label then label.inner_rml = tostring(val) end
			end
			event:StopPropagation()
		end, false)
	end

	-- Noise octaves slider + buttons
	local noiseSliderOctaves = doc:GetElementById("slider-noise-octaves")
	if noiseSliderOctaves then
		trackSliderDrag(noiseSliderOctaves, "noise-octaves")
		noiseSliderOctaves:AddEventListener("change", function(event)
			if not uiState.updatingFromCode and WG.TerraformBrush then
				local val = tonumber(noiseSliderOctaves:GetAttribute("value")) or 4
				WG.TerraformBrush.setNoiseOctaves(val)
				local label = doc:GetElementById("noise-octaves-label")
				if label then label.inner_rml = tostring(val) end
			end
			event:StopPropagation()
		end, false)
	end

	noiseBtn = doc:GetElementById("btn-noise-octaves-up")
	if noiseBtn then
		noiseBtn:AddEventListener("click", function(event)
			if WG.TerraformBrush and noiseSliderOctaves then
				local val = math.min(8, (tonumber(noiseSliderOctaves:GetAttribute("value")) or 4) + 1)
				WG.TerraformBrush.setNoiseOctaves(val)
				noiseSliderOctaves:SetAttribute("value", tostring(val))
				local label = doc:GetElementById("noise-octaves-label")
				if label then label.inner_rml = tostring(val) end
			end
			event:StopPropagation()
		end, false)
	end

	noiseBtn = doc:GetElementById("btn-noise-octaves-down")
	if noiseBtn then
		noiseBtn:AddEventListener("click", function(event)
			if WG.TerraformBrush and noiseSliderOctaves then
				local val = math.max(1, (tonumber(noiseSliderOctaves:GetAttribute("value")) or 4) - 1)
				WG.TerraformBrush.setNoiseOctaves(val)
				noiseSliderOctaves:SetAttribute("value", tostring(val))
				local label = doc:GetElementById("noise-octaves-label")
				if label then label.inner_rml = tostring(val) end
			end
			event:StopPropagation()
		end, false)
	end

	-- Noise persistence slider + buttons
	local noiseSliderPersist = doc:GetElementById("slider-noise-persistence")
	if noiseSliderPersist then
		trackSliderDrag(noiseSliderPersist, "noise-persistence")
		noiseSliderPersist:AddEventListener("change", function(event)
			if not uiState.updatingFromCode and WG.TerraformBrush then
				local val = tonumber(noiseSliderPersist:GetAttribute("value")) or 50
				WG.TerraformBrush.setNoisePersistence(val / 100)
				local label = doc:GetElementById("noise-persistence-label")
				if label then label.inner_rml = string.format("%.2f", val / 100) end
			end
			event:StopPropagation()
		end, false)
	end

	noiseBtn = doc:GetElementById("btn-noise-persist-up")
	if noiseBtn then
		noiseBtn:AddEventListener("click", function(event)
			if WG.TerraformBrush and noiseSliderPersist then
				local val = math.min(90, (tonumber(noiseSliderPersist:GetAttribute("value")) or 50) + 5)
				WG.TerraformBrush.setNoisePersistence(val / 100)
				noiseSliderPersist:SetAttribute("value", tostring(val))
				local label = doc:GetElementById("noise-persistence-label")
				if label then label.inner_rml = string.format("%.2f", val / 100) end
			end
			event:StopPropagation()
		end, false)
	end

	noiseBtn = doc:GetElementById("btn-noise-persist-down")
	if noiseBtn then
		noiseBtn:AddEventListener("click", function(event)
			if WG.TerraformBrush and noiseSliderPersist then
				local val = math.max(10, (tonumber(noiseSliderPersist:GetAttribute("value")) or 50) - 5)
				WG.TerraformBrush.setNoisePersistence(val / 100)
				noiseSliderPersist:SetAttribute("value", tostring(val))
				local label = doc:GetElementById("noise-persistence-label")
				if label then label.inner_rml = string.format("%.2f", val / 100) end
			end
			event:StopPropagation()
		end, false)
	end

	-- Noise lacunarity slider + buttons
	local noiseSliderLacun = doc:GetElementById("slider-noise-lacunarity")
	if noiseSliderLacun then
		trackSliderDrag(noiseSliderLacun, "noise-lacunarity")
		noiseSliderLacun:AddEventListener("change", function(event)
			if not uiState.updatingFromCode and WG.TerraformBrush then
				local val = tonumber(noiseSliderLacun:GetAttribute("value")) or 20
				WG.TerraformBrush.setNoiseLacunarity(val / 10)
				local label = doc:GetElementById("noise-lacunarity-label")
				if label then label.inner_rml = string.format("%.1f", val / 10) end
			end
			event:StopPropagation()
		end, false)
	end

	noiseBtn = doc:GetElementById("btn-noise-lacun-up")
	if noiseBtn then
		noiseBtn:AddEventListener("click", function(event)
			if WG.TerraformBrush and noiseSliderLacun then
				local val = math.min(40, (tonumber(noiseSliderLacun:GetAttribute("value")) or 20) + 1)
				WG.TerraformBrush.setNoiseLacunarity(val / 10)
				noiseSliderLacun:SetAttribute("value", tostring(val))
				local label = doc:GetElementById("noise-lacunarity-label")
				if label then label.inner_rml = string.format("%.1f", val / 10) end
			end
			event:StopPropagation()
		end, false)
	end

	noiseBtn = doc:GetElementById("btn-noise-lacun-down")
	if noiseBtn then
		noiseBtn:AddEventListener("click", function(event)
			if WG.TerraformBrush and noiseSliderLacun then
				local val = math.max(10, (tonumber(noiseSliderLacun:GetAttribute("value")) or 20) - 1)
				WG.TerraformBrush.setNoiseLacunarity(val / 10)
				noiseSliderLacun:SetAttribute("value", tostring(val))
				local label = doc:GetElementById("noise-lacunarity-label")
				if label then label.inner_rml = string.format("%.1f", val / 10) end
			end
			event:StopPropagation()
		end, false)
	end

	-- Noise seed slider + reseed button
	local noiseSliderSeed = doc:GetElementById("slider-noise-seed")
	if noiseSliderSeed then
		trackSliderDrag(noiseSliderSeed, "noise-seed")
		noiseSliderSeed:AddEventListener("change", function(event)
			if not uiState.updatingFromCode and WG.TerraformBrush then
				local val = tonumber(noiseSliderSeed:GetAttribute("value")) or 0
				WG.TerraformBrush.setNoiseSeed(val)
				local label = doc:GetElementById("noise-seed-label")
				if label then label.inner_rml = tostring(val) end
			end
			event:StopPropagation()
		end, false)
	end

	local noiseReseed = doc:GetElementById("btn-noise-reseed")
	if noiseReseed then
		noiseReseed:AddEventListener("click", function(event)
			local newSeed = math.floor(math.random() * 9999)
			if WG.TerraformBrush then WG.TerraformBrush.setNoiseSeed(newSeed) end
			if noiseSliderSeed then noiseSliderSeed:SetAttribute("value", tostring(newSeed)) end
			local label = doc:GetElementById("noise-seed-label")
			if label then label.inner_rml = tostring(newSeed) end
			event:StopPropagation()
		end, false)
	end

	local noiseSeedDown = doc:GetElementById("btn-noise-seed-down")
	if noiseSeedDown then
		noiseSeedDown:AddEventListener("click", function(event)
			if WG.TerraformBrush then
				local st = WG.TerraformBrush.getState()
				local cur = (st and st.noiseSeed) or 0
				local newVal = math.max(0, cur - 1)
				WG.TerraformBrush.setNoiseSeed(newVal)
				if noiseSliderSeed then noiseSliderSeed:SetAttribute("value", tostring(newVal)) end
				local label = doc:GetElementById("noise-seed-label")
				if label then label.inner_rml = tostring(newVal) end
			end
			event:StopPropagation()
		end, false)
	end

	local noiseSeedUp = doc:GetElementById("btn-noise-seed-up")
	if noiseSeedUp then
		noiseSeedUp:AddEventListener("click", function(event)
			if WG.TerraformBrush then
				local st = WG.TerraformBrush.getState()
				local cur = (st and st.noiseSeed) or 0
				local newVal = math.min(9999, cur + 1)
				WG.TerraformBrush.setNoiseSeed(newVal)
				if noiseSliderSeed then noiseSliderSeed:SetAttribute("value", tostring(newVal)) end
				local label = doc:GetElementById("noise-seed-label")
				if label then label.inner_rml = tostring(newVal) end
			end
			event:StopPropagation()
		end, false)
	end

end

return M
