-- tf_noise.lua: extracted tool module for gui_terraform_brush
local M = {}

function M.attach(doc, ctx)
	local widgetState = ctx.widgetState
	local uiState = ctx.uiState
	local WG = ctx.WG
	local playSound = ctx.playSound
	local trackSliderDrag = ctx.trackSliderDrag
	-- ============ Noise Brush controls ============

	widgetState.noiseRootEl = doc:GetElementById("tf-noise-root")

	-- Slider drag tracking (legitimate imperative: slider-specific drag state).
	-- Slider change events are wired declaratively via onchange= in RML.
	for _, sid in ipairs({ "noise-scale", "noise-octaves", "noise-persistence", "noise-lacunarity", "noise-seed" }) do
		local sl = doc:GetElementById("slider-" .. sid)
		if sl then trackSliderDrag(sl, sid) end
	end

	-- Register widget methods for inline onclick/onchange handlers in RML.
	local w = ctx.widget
	if not w then return end

	local function setLabel(id, text)
		local el = doc:GetElementById(id)
		if el then el.inner_rml = text end
	end

	local function sliderVal(id, default)
		local sl = doc:GetElementById("slider-" .. id)
		if not sl then return default end
		return tonumber(sl:GetAttribute("value")) or default
	end

	local function setSliderVal(id, v)
		local sl = doc:GetElementById("slider-" .. id)
		if sl then sl:SetAttribute("value", tostring(v)) end
	end

	w.noClose = function(self)
		playSound("click")
		widgetState.noiseManuallyHidden = true
		if widgetState.dmHandle then
			widgetState.dmHandle.noiseWindowVisible = false
		end
	end

	w.noSetType = function(self, ntype)
		playSound("modeSwitch")
		if WG.TerraformBrush then WG.TerraformBrush.setNoiseType(ntype) end
		if widgetState.dmHandle then widgetState.dmHandle.noiseType = ntype end
	end

	-- Scale
	w.noOnScaleChange = function(self, element)
		if uiState.updatingFromCode or not WG.TerraformBrush then return end
		local val = element and tonumber(element:GetAttribute("value")) or 64
		WG.TerraformBrush.setNoiseScale(val)
		setLabel("noise-scale-label", tostring(val))
	end
	w.noScaleUp = function(self)
		if not WG.TerraformBrush then return end
		local val = math.min(512, sliderVal("noise-scale", 64) + 8)
		WG.TerraformBrush.setNoiseScale(val)
		setSliderVal("noise-scale", val)
		setLabel("noise-scale-label", tostring(val))
	end
	w.noScaleDown = function(self)
		if not WG.TerraformBrush then return end
		local val = math.max(8, sliderVal("noise-scale", 64) - 8)
		WG.TerraformBrush.setNoiseScale(val)
		setSliderVal("noise-scale", val)
		setLabel("noise-scale-label", tostring(val))
	end

	-- Octaves
	w.noOnOctavesChange = function(self, element)
		if uiState.updatingFromCode or not WG.TerraformBrush then return end
		local val = element and tonumber(element:GetAttribute("value")) or 4
		WG.TerraformBrush.setNoiseOctaves(val)
		setLabel("noise-octaves-label", tostring(val))
	end
	w.noOctavesUp = function(self)
		if not WG.TerraformBrush then return end
		local val = math.min(8, sliderVal("noise-octaves", 4) + 1)
		WG.TerraformBrush.setNoiseOctaves(val)
		setSliderVal("noise-octaves", val)
		setLabel("noise-octaves-label", tostring(val))
	end
	w.noOctavesDown = function(self)
		if not WG.TerraformBrush then return end
		local val = math.max(1, sliderVal("noise-octaves", 4) - 1)
		WG.TerraformBrush.setNoiseOctaves(val)
		setSliderVal("noise-octaves", val)
		setLabel("noise-octaves-label", tostring(val))
	end

	-- Persistence
	w.noOnPersistChange = function(self, element)
		if uiState.updatingFromCode or not WG.TerraformBrush then return end
		local val = element and tonumber(element:GetAttribute("value")) or 50
		WG.TerraformBrush.setNoisePersistence(val / 100)
		setLabel("noise-persistence-label", string.format("%.2f", val / 100))
	end
	w.noPersistUp = function(self)
		if not WG.TerraformBrush then return end
		local val = math.min(90, sliderVal("noise-persistence", 50) + 5)
		WG.TerraformBrush.setNoisePersistence(val / 100)
		setSliderVal("noise-persistence", val)
		setLabel("noise-persistence-label", string.format("%.2f", val / 100))
	end
	w.noPersistDown = function(self)
		if not WG.TerraformBrush then return end
		local val = math.max(10, sliderVal("noise-persistence", 50) - 5)
		WG.TerraformBrush.setNoisePersistence(val / 100)
		setSliderVal("noise-persistence", val)
		setLabel("noise-persistence-label", string.format("%.2f", val / 100))
	end

	-- Lacunarity
	w.noOnLacunChange = function(self, element)
		if uiState.updatingFromCode or not WG.TerraformBrush then return end
		local val = element and tonumber(element:GetAttribute("value")) or 20
		WG.TerraformBrush.setNoiseLacunarity(val / 10)
		setLabel("noise-lacunarity-label", string.format("%.1f", val / 10))
	end
	w.noLacunUp = function(self)
		if not WG.TerraformBrush then return end
		local val = math.min(40, sliderVal("noise-lacunarity", 20) + 1)
		WG.TerraformBrush.setNoiseLacunarity(val / 10)
		setSliderVal("noise-lacunarity", val)
		setLabel("noise-lacunarity-label", string.format("%.1f", val / 10))
	end
	w.noLacunDown = function(self)
		if not WG.TerraformBrush then return end
		local val = math.max(10, sliderVal("noise-lacunarity", 20) - 1)
		WG.TerraformBrush.setNoiseLacunarity(val / 10)
		setSliderVal("noise-lacunarity", val)
		setLabel("noise-lacunarity-label", string.format("%.1f", val / 10))
	end

	-- Seed
	w.noOnSeedChange = function(self, element)
		if uiState.updatingFromCode or not WG.TerraformBrush then return end
		local val = element and tonumber(element:GetAttribute("value")) or 0
		WG.TerraformBrush.setNoiseSeed(val)
		setLabel("noise-seed-label", tostring(val))
	end
	w.noReseed = function(self)
		local newSeed = math.floor(math.random() * 9999)
		if WG.TerraformBrush then WG.TerraformBrush.setNoiseSeed(newSeed) end
		setSliderVal("noise-seed", newSeed)
		setLabel("noise-seed-label", tostring(newSeed))
	end
	w.noSeedUp = function(self)
		if not WG.TerraformBrush then return end
		local st = WG.TerraformBrush.getState()
		local cur = (st and st.noiseSeed) or 0
		local newVal = math.min(9999, cur + 1)
		WG.TerraformBrush.setNoiseSeed(newVal)
		setSliderVal("noise-seed", newVal)
		setLabel("noise-seed-label", tostring(newVal))
	end
	w.noSeedDown = function(self)
		if not WG.TerraformBrush then return end
		local st = WG.TerraformBrush.getState()
		local cur = (st and st.noiseSeed) or 0
		local newVal = math.max(0, cur - 1)
		WG.TerraformBrush.setNoiseSeed(newVal)
		setSliderVal("noise-seed", newVal)
		setLabel("noise-seed-label", tostring(newVal))
	end
end

return M
