-- tf_metal.lua — Metal Brush attach + sync (extracted from gui_terraform_brush.lua)
local M = {}

function M.attach(doc, ctx)
	local widgetState = ctx.widgetState
	local uiState = ctx.uiState
	local playSound = ctx.playSound
	local setActiveClass = ctx.setActiveClass
	local trackSliderDrag = ctx.trackSliderDrag
	local WG = ctx.WG
	local RADIUS_STEP = ctx.RADIUS_STEP
	local ROTATION_STEP = ctx.ROTATION_STEP
	local LENGTH_SCALE_STEP = ctx.LENGTH_SCALE_STEP
	local CURVE_STEP = ctx.CURVE_STEP

	widgetState.mbSubmodesEl = doc:GetElementById("tf-metal-submodes")
	widgetState.mbControlsEl = doc:GetElementById("tf-metal-controls")

	widgetState.mbSubModeButtons = {}
	widgetState.mbSubModeButtons.paint = doc:GetElementById("btn-mb-paint")
	widgetState.mbSubModeButtons.stamp = doc:GetElementById("btn-mb-stamp")
	widgetState.mbSubModeButtons.remove = doc:GetElementById("btn-mb-remove")

	for mbMode, element in pairs(widgetState.mbSubModeButtons) do
		if element then
			element:AddEventListener("click", function(event)
				playSound("modeSwitch")
				if WG.MetalBrush then WG.MetalBrush.setSubMode(mbMode) end
				setActiveClass(widgetState.mbSubModeButtons, mbMode)
				event:StopPropagation()
			end, false)
		end
	end

	local mbSliderValue = doc:GetElementById("slider-metal-value")
	if mbSliderValue then
		trackSliderDrag(mbSliderValue, "mb-value")
		mbSliderValue:AddEventListener("change", function(event)
			if uiState.updatingFromCode then event:StopPropagation(); return end
			local v = tonumber(mbSliderValue:GetAttribute("value")) or 0
			-- Logarithmic mapping: 0.01 .. 50.0
			local mv = 0.01 * math.exp(v / 1000 * math.log(50.0 / 0.01))
			if WG.MetalBrush then WG.MetalBrush.setMetalValue(mv) end
			local mbLabel = doc:GetElementById("mb-value-label")
			if mbLabel then mbLabel.inner_rml = string.format("%.1f", mv) end
			event:StopPropagation()
		end, false)
	end

	do
		local valUp = doc:GetElementById("btn-metal-value-up")
		if valUp then
			valUp:AddEventListener("click", function(event)
				if WG.MetalBrush then
					local s = WG.MetalBrush.getState()
					local cur = s and s.metalValue or 2.0
					WG.MetalBrush.setMetalValue(cur * 1.1)
				end
				event:StopPropagation()
			end, false)
		end
		local valDn = doc:GetElementById("btn-metal-value-down")
		if valDn then
			valDn:AddEventListener("click", function(event)
				if WG.MetalBrush then
					local s = WG.MetalBrush.getState()
					local cur = s and s.metalValue or 2.0
					WG.MetalBrush.setMetalValue(cur / 1.1)
				end
				event:StopPropagation()
			end, false)
		end
	end

	local mbSaveBtn = doc:GetElementById("btn-metal-save")
	if mbSaveBtn then
		mbSaveBtn:AddEventListener("click", function(event)
			playSound("save")
			if WG.MetalBrush then WG.MetalBrush.saveMetalMap() end
			event:StopPropagation()
		end, false)
	end

	local mbLoadBtn = doc:GetElementById("btn-metal-load")
	if mbLoadBtn then
		mbLoadBtn:AddEventListener("click", function(event)
			playSound("apply")
			if WG.MetalBrush then WG.MetalBrush.loadMetalMap() end
			event:StopPropagation()
		end, false)
	end

	local mbCleanBtn = doc:GetElementById("btn-metal-clean")
	local mbCleanLabel = doc:GetElementById("metal-clean-label")
	if mbCleanBtn then
		mbCleanBtn:AddEventListener("click", function(event)
			if widgetState.metalCleanConfirmExpiry > 0 then
				-- Second click: confirmed
				widgetState.metalCleanConfirmExpiry = 0
				mbCleanBtn:SetClass("confirming", false)
				if mbCleanLabel then mbCleanLabel.inner_rml = "CLEAN" end
				playSound("reset")
				if WG.MetalBrush then WG.MetalBrush.clearMetalMap() end
			else
				-- First click: ask for confirmation
				widgetState.metalCleanConfirmExpiry = (Spring.GetGameSeconds() or 0) + 3
				mbCleanBtn:SetClass("confirming", true)
				if mbCleanLabel then mbCleanLabel.inner_rml = "ARE YOU SURE?" end
				playSound("toggleOn")
			end
			event:StopPropagation()
		end, false)
	end

	-- Metal shape buttons (removed; metal now uses the shared tf-shape-row)
	widgetState.mbShapeButtons = {}

	-- Metal size slider
	do
		local sl = doc:GetElementById("slider-mb-size")
		if sl then
			trackSliderDrag(sl, "mb-size")
			sl:AddEventListener("change", function(event)
				if not uiState.updatingFromCode and WG.TerraformBrush then
					local val = tonumber(sl:GetAttribute("value")) or 100
					WG.TerraformBrush.setRadius(val)
				end
				event:StopPropagation()
			end, false)
		end
		local up = doc:GetElementById("btn-mb-size-up")
		if up then
			up:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					WG.TerraformBrush.setRadius(state.radius + RADIUS_STEP)
				end
				event:StopPropagation()
			end, false)
		end
		local dn = doc:GetElementById("btn-mb-size-down")
		if dn then
			dn:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					WG.TerraformBrush.setRadius(state.radius - RADIUS_STEP)
				end
				event:StopPropagation()
			end, false)
		end
	end

	-- Metal rotation slider
	do
		local sl = doc:GetElementById("slider-mb-rotation")
		if sl then
			trackSliderDrag(sl, "mb-rotation")
			sl:AddEventListener("change", function(event)
				if not uiState.updatingFromCode and WG.TerraformBrush then
					local val = tonumber(sl:GetAttribute("value")) or 0
					WG.TerraformBrush.setRotation(val)
				end
				event:StopPropagation()
			end, false)
		end
		local cw = doc:GetElementById("btn-mb-rot-cw")
		if cw then
			cw:AddEventListener("click", function(event)
				if WG.TerraformBrush then WG.TerraformBrush.rotate(ROTATION_STEP) end
				event:StopPropagation()
			end, false)
		end
		local ccw = doc:GetElementById("btn-mb-rot-ccw")
		if ccw then
			ccw:AddEventListener("click", function(event)
				if WG.TerraformBrush then WG.TerraformBrush.rotate(-ROTATION_STEP) end
				event:StopPropagation()
			end, false)
		end
	end

	-- Metal length slider
	do
		local sl = doc:GetElementById("slider-mb-length")
		if sl then
			trackSliderDrag(sl, "mb-length")
			sl:AddEventListener("change", function(event)
				if not uiState.updatingFromCode and WG.TerraformBrush then
					local val = tonumber(sl:GetAttribute("value")) or 10
					WG.TerraformBrush.setLengthScale(val / 10)
				end
				event:StopPropagation()
			end, false)
		end
		local up = doc:GetElementById("btn-mb-length-up")
		if up then
			up:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					WG.TerraformBrush.setLengthScale(state.lengthScale + LENGTH_SCALE_STEP)
				end
				event:StopPropagation()
			end, false)
		end
		local dn = doc:GetElementById("btn-mb-length-down")
		if dn then
			dn:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					WG.TerraformBrush.setLengthScale(state.lengthScale - LENGTH_SCALE_STEP)
				end
				event:StopPropagation()
			end, false)
		end
	end

	-- Metal curve/falloff slider
	do
		local sl = doc:GetElementById("slider-mb-curve")
		if sl then
			trackSliderDrag(sl, "mb-curve")
			sl:AddEventListener("change", function(event)
				if not uiState.updatingFromCode and WG.TerraformBrush then
					local val = tonumber(sl:GetAttribute("value")) or 10
					WG.TerraformBrush.setCurve(val / 10)
				end
				event:StopPropagation()
			end, false)
		end
		local up = doc:GetElementById("btn-mb-curve-up")
		if up then
			up:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					WG.TerraformBrush.setCurve(state.curve + CURVE_STEP)
				end
				event:StopPropagation()
			end, false)
		end
		local dn = doc:GetElementById("btn-mb-curve-down")
		if dn then
			dn:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					WG.TerraformBrush.setCurve(state.curve - CURVE_STEP)
				end
				event:StopPropagation()
			end, false)
		end
	end
end

function M.sync(doc, ctx, mbState, setSummary)
	local widgetState = ctx.widgetState
	local uiState = ctx.uiState
	local setActiveClass = ctx.setActiveClass
	local syncAndFlash = ctx.syncAndFlash
	local WG = ctx.WG

	local metalBtn = doc and doc:GetElementById("btn-metal")
	if metalBtn then metalBtn:SetClass("active", true) end
	setActiveClass(widgetState.modeButtons, nil)

	-- Metal sub-mode buttons
	setActiveClass(widgetState.mbSubModeButtons, mbState.subMode)

	-- Metal value slider & label sync
	if doc then
		uiState.updatingFromCode = true

		local mbValueLabel = doc:GetElementById("mb-value-label")
		if mbValueLabel then mbValueLabel.inner_rml = string.format("%.1f", mbState.metalValue) end

		do
			local mv = math.max(0.01, mbState.metalValue)
			local sv = math.floor(1000 * math.log(mv / 0.01) / math.log(50.0 / 0.01) + 0.5)
			syncAndFlash(doc:GetElementById("slider-metal-value"), "mb-value", tostring(sv))
		end

		-- Sync size, rotation, length, curve from shared terraform state
		local tfSt2 = WG.TerraformBrush and WG.TerraformBrush.getState()
		if tfSt2 then
			local mbSizeLabel = doc:GetElementById("mb-size-label")
			if mbSizeLabel then mbSizeLabel.inner_rml = tostring(tfSt2.radius) end
			syncAndFlash(doc:GetElementById("slider-mb-size"), "mb-size", tostring(tfSt2.radius))

			local mbRotLabel = doc:GetElementById("mb-rotation-label")
			if mbRotLabel then mbRotLabel.inner_rml = tostring(tfSt2.rotationDeg) .. "&#176;" end
			syncAndFlash(doc:GetElementById("slider-mb-rotation"), "mb-rotation", tostring(tfSt2.rotationDeg))

			local mbLenLabel = doc:GetElementById("mb-length-label")
			if mbLenLabel then mbLenLabel.inner_rml = string.format("%.1f", tfSt2.lengthScale) end
			syncAndFlash(doc:GetElementById("slider-mb-length"), "mb-length", tostring(math.floor(tfSt2.lengthScale * 10 + 0.5)))

			local mbCurveLabel = doc:GetElementById("mb-curve-label")
			if mbCurveLabel then mbCurveLabel.inner_rml = string.format("%.1f", tfSt2.curve) end
			syncAndFlash(doc:GetElementById("slider-mb-curve"), "mb-curve", tostring(math.floor(tfSt2.curve * 10 + 0.5)))
		end

		uiState.updatingFromCode = false
	end

	-- Shape: use terraform brush shape (shared)
	local tfSt = WG.TerraformBrush and WG.TerraformBrush.getState()
	if tfSt then
		setActiveClass(widgetState.shapeButtons, tfSt.shape)
	end

	do
		local tfSt2 = WG.TerraformBrush and WG.TerraformBrush.getState()
		local sm = mbState.subMode or "paint"
		setSummary("METAL", "#14b8a6",
			"", sm:upper(),
			"R ", tostring(tfSt2 and tfSt2.radius or "?"),
			"Val ", string.format("%.1f", mbState.metalValue or 0),
			"Crv ", string.format("%.1f", tfSt2 and tfSt2.curve or 0))
	end
end

return M
