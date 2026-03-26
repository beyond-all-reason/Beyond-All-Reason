if not RmlUi then
	return
end

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Terraform Brush UI",
		desc = "RmlUI panel for terraform brush shape, mode, and rotation controls",
		author = "BARb",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true,
	}
end

local MODEL_NAME = "terraform_brush_model"
local RML_PATH = "luaui/RmlWidgets/gui_terraform_brush/gui_terraform_brush.rml"

local ROTATION_STEP = 3
local CURVE_STEP = 0.1
local LENGTH_SCALE_STEP = 0.1
local RADIUS_STEP = 8
local HEIGHT_CAP_STEP = 8
local HEIGHT_STEP = 8
local DEFAULT_MAX_INTENSITY = 10.0

local INTENSITY_LOG_MIN = 0.1
local INTENSITY_LOG_MAX = 100.0
local INTENSITY_SLIDER_MAX = 1000
local INTENSITY_LOG_RANGE = math.log(INTENSITY_LOG_MAX / INTENSITY_LOG_MIN)

local function sliderToIntensity(v)
	return INTENSITY_LOG_MIN * math.exp(v / INTENSITY_SLIDER_MAX * INTENSITY_LOG_RANGE)
end

local function intensityToSlider(intensity)
	if intensity <= INTENSITY_LOG_MIN then return 0 end
	return math.floor(INTENSITY_SLIDER_MAX * math.log(intensity / INTENSITY_LOG_MIN) / INTENSITY_LOG_RANGE + 0.5)
end
local WG = WG
local GetViewGeometry = Spring.GetViewGeometry

local INITIAL_LEFT_VW = 78
local INITIAL_TOP_VH = 25
local BASE_WIDTH_DP = 162
local BASE_RESOLUTION = 1920

local updatingFromCode = false

local widgetState = {
	rmlContext = nil,
	document = nil,
	dmHandle = nil,
	rootElement = nil,
	modeButtons = {},
	shapeButtons = {},
	panelWidthDp = BASE_WIDTH_DP,
}

local function buildRootStyle()
	return string.format("left: %.2fvw; top: %.2fvh; width: %ddp;",
		INITIAL_LEFT_VW, INITIAL_TOP_VH, widgetState.panelWidthDp)
end

local initialModel = {
	radius = 100,
	shapeName = "Circle",
	rotationDeg = 0,
	curve = "1.0",
	intensity = "1.0",
	lengthScale = "1.0",
	heightCapMinStr = "--",
	heightCapMaxStr = "--",
}

local shapeNames = {
	circle = "Circle",
	square = "Square",
	hexagon = "Hexagon",
	octagon = "Octagon",
	ring = "Ring",
}

local function setActiveClass(buttons, activeKey)
	for key, element in pairs(buttons) do
		if element then
			element:SetClass("active", key == activeKey)
		end
	end
end

local function onModeClick(mode)
	return function(event)
		if WG.TerraformBrush then
			WG.TerraformBrush.setMode(mode)
		end

		setActiveClass(widgetState.modeButtons, mode)
		event:StopPropagation()
	end
end

local function onShapeClick(shape)
	return function(event)
		if WG.TerraformBrush then
			local state = WG.TerraformBrush.getState()
			if state and state.mode == "ramp" and shape ~= "circle" and shape ~= "square" then
				event:StopPropagation()
				return
			end
			if state and state.mode == "level" and shape == "ring" then
				event:StopPropagation()
				return
			end
			WG.TerraformBrush.setShape(shape)
		end

		setActiveClass(widgetState.shapeButtons, shape)

		if widgetState.dmHandle then
			widgetState.dmHandle.shapeName = shapeNames[shape]
		end

		event:StopPropagation()
	end
end

local function onRotateCW(event)
	if WG.TerraformBrush then
		WG.TerraformBrush.rotate(ROTATION_STEP)
	end

	event:StopPropagation()
end

local function onRotateCCW(event)
	if WG.TerraformBrush then
		WG.TerraformBrush.rotate(-ROTATION_STEP)
	end

	event:StopPropagation()
end

local function onCurveUp(event)
	if WG.TerraformBrush then
		local state = WG.TerraformBrush.getState()
		WG.TerraformBrush.setCurve(state.curve + CURVE_STEP)
	end

	event:StopPropagation()
end

local function onCurveDown(event)
	if WG.TerraformBrush then
		local state = WG.TerraformBrush.getState()
		WG.TerraformBrush.setCurve(state.curve - CURVE_STEP)
	end

	event:StopPropagation()
end

local function onIntensityUp(event)
	if WG.TerraformBrush then
		local state = WG.TerraformBrush.getState()
		local newI = state.intensity * 1.15
		if newI < state.intensity + 0.1 then newI = state.intensity + 0.1 end
		WG.TerraformBrush.setIntensity(newI)
	end

	event:StopPropagation()
end

local function onIntensityDown(event)
	if WG.TerraformBrush then
		local state = WG.TerraformBrush.getState()
		local newI = state.intensity / 1.15
		if newI > state.intensity - 0.1 then newI = state.intensity - 0.1 end
		WG.TerraformBrush.setIntensity(newI)
	end

	event:StopPropagation()
end

local capMinValue = 0
local capMaxValue = 0
local capAbsolute = false

local function applyCap(which, value)
	if not WG.TerraformBrush then return end
	if which == "max" then
		WG.TerraformBrush.setHeightCapMax(value ~= 0 and value or nil)
	else
		WG.TerraformBrush.setHeightCapMin(value ~= 0 and value or nil)
	end
end

local function getEffectiveMaxIntensity()
	if capMaxValue ~= 0 or capMinValue ~= 0 then
		local maxCap = math.max(math.abs(capMaxValue), math.abs(capMinValue))
		return math.max(1.0, maxCap / HEIGHT_STEP)
	end
	return DEFAULT_MAX_INTENSITY
end

local function attachEventListeners()
	local doc = widgetState.document
	if not doc then
		return
	end

	widgetState.modeButtons.raise = doc:GetElementById("btn-raise")
	widgetState.modeButtons.lower = doc:GetElementById("btn-lower")
	widgetState.modeButtons.level = doc:GetElementById("btn-level")
	widgetState.modeButtons.ramp = doc:GetElementById("btn-ramp")
	widgetState.modeButtons.restore = doc:GetElementById("btn-restore")

	widgetState.shapeButtons.circle = doc:GetElementById("btn-circle")
	widgetState.shapeButtons.square = doc:GetElementById("btn-square")
	widgetState.shapeButtons.hexagon = doc:GetElementById("btn-hexagon")
	widgetState.shapeButtons.octagon = doc:GetElementById("btn-octagon")
	widgetState.shapeButtons.ring = doc:GetElementById("btn-ring")

	for mode, element in pairs(widgetState.modeButtons) do
		if element then
			element:AddEventListener("click", onModeClick(mode), false)
		end
	end

	for shape, element in pairs(widgetState.shapeButtons) do
		if element then
			element:AddEventListener("click", onShapeClick(shape), false)
		end
	end

	local undoBtn = doc:GetElementById("btn-undo")
	if undoBtn then
		undoBtn:AddEventListener("click", function(event)
			if WG.TerraformBrush then
				WG.TerraformBrush.undo()
			end
			event:StopPropagation()
		end, false)
	end

	local redoBtn = doc:GetElementById("btn-redo")
	if redoBtn then
		redoBtn:AddEventListener("click", function(event)
			if WG.TerraformBrush then
				WG.TerraformBrush.redo()
			end
			event:StopPropagation()
		end, false)
	end

	local sliderHistory = doc:GetElementById("slider-history")
	if sliderHistory then
		sliderHistory:AddEventListener("change", function(event)
			if updatingFromCode then event:StopPropagation(); return end
			if not WG.TerraformBrush then event:StopPropagation(); return end
			local val = tonumber(sliderHistory:GetAttribute("value")) or 0
			local state = WG.TerraformBrush.getState()
			if not state then event:StopPropagation(); return end
			-- Slider: max (right) = present, 0 (left) = furthest into past
			-- value = undoCount (how many steps can still be undone = closeness to present)
			local currentUndoCount = state.undoCount or 0
			local diff = val - currentUndoCount
			if diff > 0 then
				-- Moved right towards present: redo
				for i = 1, diff do
					WG.TerraformBrush.redo()
				end
			elseif diff < 0 then
				-- Moved left towards past: undo
				for i = 1, -diff do
					WG.TerraformBrush.undo()
				end
			end
			event:StopPropagation()
		end, false)
	end

	local rotCW = doc:GetElementById("btn-rot-cw")
	local rotCCW = doc:GetElementById("btn-rot-ccw")

	if rotCW then
		rotCW:AddEventListener("click", onRotateCW, false)
	end

	if rotCCW then
		rotCCW:AddEventListener("click", onRotateCCW, false)
	end

	local sliderRotation = doc:GetElementById("slider-rotation")
	if sliderRotation then
		sliderRotation:AddEventListener("change", function(event)
			if not updatingFromCode and WG.TerraformBrush then
				local val = tonumber(sliderRotation:GetAttribute("value")) or 0
				WG.TerraformBrush.setRotation(val)
			end
			event:StopPropagation()
		end, false)
	end

	local curveUpBtn = doc:GetElementById("btn-curve-up")
	local curveDownBtn = doc:GetElementById("btn-curve-down")

	if curveUpBtn then
		curveUpBtn:AddEventListener("click", onCurveUp, false)
	end

	if curveDownBtn then
		curveDownBtn:AddEventListener("click", onCurveDown, false)
	end

	local intensityUpBtn = doc:GetElementById("btn-intensity-up")
	local intensityDownBtn = doc:GetElementById("btn-intensity-down")

	if intensityUpBtn then
		intensityUpBtn:AddEventListener("click", onIntensityUp, false)
	end

	if intensityDownBtn then
		intensityDownBtn:AddEventListener("click", onIntensityDown, false)
	end

	local sliderCurve = doc:GetElementById("slider-curve")
	if sliderCurve then
		sliderCurve:AddEventListener("change", function(event)
			if not updatingFromCode and WG.TerraformBrush then
				local val = tonumber(sliderCurve:GetAttribute("value")) or 10
				WG.TerraformBrush.setCurve(val / 10)
			end
			event:StopPropagation()
		end, false)
	end

	local sliderIntensity = doc:GetElementById("slider-intensity")
	if sliderIntensity then
		sliderIntensity:AddEventListener("change", function(event)
			if not updatingFromCode and WG.TerraformBrush then
				local val = tonumber(sliderIntensity:GetAttribute("value")) or 0
				WG.TerraformBrush.setIntensity(sliderToIntensity(val))
			end
			event:StopPropagation()
		end, false)
	end

	local sliderLength = doc:GetElementById("slider-length")
	if sliderLength then
		sliderLength:AddEventListener("change", function(event)
			if not updatingFromCode and WG.TerraformBrush then
				local val = tonumber(sliderLength:GetAttribute("value")) or 20
				WG.TerraformBrush.setLengthScale(val / 10)
			end
			event:StopPropagation()
		end, false)
	end

	local lengthUpBtn = doc:GetElementById("btn-length-up")
	if lengthUpBtn then
		lengthUpBtn:AddEventListener("click", function(event)
			if WG.TerraformBrush then
				local state = WG.TerraformBrush.getState()
				WG.TerraformBrush.setLengthScale(state.lengthScale + LENGTH_SCALE_STEP)
			end
			event:StopPropagation()
		end, false)
	end

	local lengthDownBtn = doc:GetElementById("btn-length-down")
	if lengthDownBtn then
		lengthDownBtn:AddEventListener("click", function(event)
			if WG.TerraformBrush then
				local state = WG.TerraformBrush.getState()
				WG.TerraformBrush.setLengthScale(state.lengthScale - LENGTH_SCALE_STEP)
			end
			event:StopPropagation()
		end, false)
	end

	local sliderSize = doc:GetElementById("slider-size")
	if sliderSize then
		sliderSize:AddEventListener("change", function(event)
			if not updatingFromCode and WG.TerraformBrush then
				local val = tonumber(sliderSize:GetAttribute("value")) or 100
				WG.TerraformBrush.setRadius(val)
			end
			event:StopPropagation()
		end, false)
	end

	local sizeUpBtn = doc:GetElementById("btn-size-up")
	if sizeUpBtn then
		sizeUpBtn:AddEventListener("click", function(event)
			if WG.TerraformBrush then
				local state = WG.TerraformBrush.getState()
				WG.TerraformBrush.setRadius(state.radius + RADIUS_STEP)
			end
			event:StopPropagation()
		end, false)
	end

	local sizeDownBtn = doc:GetElementById("btn-size-down")
	if sizeDownBtn then
		sizeDownBtn:AddEventListener("click", function(event)
			if WG.TerraformBrush then
				local state = WG.TerraformBrush.getState()
				WG.TerraformBrush.setRadius(state.radius - RADIUS_STEP)
			end
			event:StopPropagation()
		end, false)
	end

	local sliderCapMax = doc:GetElementById("slider-cap-max")
	if sliderCapMax then
		sliderCapMax:AddEventListener("change", function(event)
			if updatingFromCode then event:StopPropagation(); return end
			local val = tonumber(sliderCapMax:GetAttribute("value")) or 0
			capMaxValue = val
			if capMinValue > capMaxValue then
				capMinValue = capMaxValue
				applyCap("min", capMinValue)
			end
			applyCap("max", capMaxValue)
			event:StopPropagation()
		end, false)
	end

	local sliderCapMin = doc:GetElementById("slider-cap-min")
	if sliderCapMin then
		sliderCapMin:AddEventListener("change", function(event)
			if updatingFromCode then event:StopPropagation(); return end
			local val = tonumber(sliderCapMin:GetAttribute("value")) or 0
			capMinValue = val
			if capMaxValue < capMinValue then
				capMaxValue = capMinValue
				applyCap("max", capMaxValue)
			end
			applyCap("min", capMinValue)
			event:StopPropagation()
		end, false)
	end

	local capAbsoluteBtn = doc:GetElementById("btn-cap-absolute")
	if capAbsoluteBtn then
		capAbsoluteBtn:AddEventListener("click", function(event)
			capAbsolute = not capAbsolute
			if capAbsolute then
				capAbsoluteBtn:SetAttribute("src", "/luaui/images/terraform_brush/check_on.png")
			else
				capAbsoluteBtn:SetAttribute("src", "/luaui/images/terraform_brush/check_off.png")
			end
			if WG.TerraformBrush then
				WG.TerraformBrush.setHeightCapAbsolute(capAbsolute)
			end
			event:StopPropagation()
		end, false)
	end

	local clayBtn = doc:GetElementById("btn-clay-mode")
	if clayBtn then
		clayBtn:AddEventListener("click", function(event)
			if WG.TerraformBrush then
				local state = WG.TerraformBrush.getState()
				local newVal = not (state and state.clayMode)
				WG.TerraformBrush.setClayMode(newVal)
				clayBtn:SetAttribute("src", newVal
					and "/luaui/images/terraform_brush/check_on.png"
					or "/luaui/images/terraform_brush/check_off.png")
			end
			event:StopPropagation()
		end, false)
	end

	local gridBtn = doc:GetElementById("btn-grid-overlay")
	if gridBtn then
		gridBtn:AddEventListener("click", function(event)
			if WG.TerraformBrush then
				local state = WG.TerraformBrush.getState()
				local newVal = not (state and state.gridOverlay)
				WG.TerraformBrush.setGridOverlay(newVal)
				gridBtn:SetAttribute("src", newVal
					and "/luaui/images/terraform_brush/check_on.png"
					or "/luaui/images/terraform_brush/check_off.png")
			end
			event:StopPropagation()
		end, false)
	end

	local dustBtn = doc:GetElementById("btn-dust-effects")
	if dustBtn then
		dustBtn:AddEventListener("click", function(event)
			if WG.TerraformBrush then
				local state = WG.TerraformBrush.getState()
				local newVal = not (state and state.dustEffects)
				WG.TerraformBrush.setDustEffects(newVal)
				dustBtn:SetAttribute("src", newVal
					and "/luaui/images/terraform_brush/check_on.png"
					or "/luaui/images/terraform_brush/check_off.png")
			end
			event:StopPropagation()
		end, false)
	end

	local exportBtn = doc:GetElementById("btn-export")
	if exportBtn then
		exportBtn:AddEventListener("click", function(event)
			Spring.SendCommands("terraformexport")
			event:StopPropagation()
		end, false)
	end

	local importBtn = doc:GetElementById("btn-import")
	local tooltipLoad = doc:GetElementById("tooltip-load")
	if importBtn and tooltipLoad then
		importBtn:AddEventListener("mouseover", function(event)
			tooltipLoad:SetClass("hidden", false)
			event:StopPropagation()
		end, false)
		importBtn:AddEventListener("mouseout", function(event)
			tooltipLoad:SetClass("hidden", true)
			event:StopPropagation()
		end, false)
	end

	local quitBtn = doc:GetElementById("btn-quit")
	if quitBtn then
		quitBtn:AddEventListener("click", function(event)
			if WG.TerraformBrush then
				WG.TerraformBrush.deactivate()
			end
			event:StopPropagation()
		end, false)
	end

	local defaultsBtn = doc:GetElementById("btn-defaults")
	if defaultsBtn then
		defaultsBtn:AddEventListener("click", function(event)
			if WG.TerraformBrush then
				WG.TerraformBrush.setRadius(100)
				WG.TerraformBrush.setRotation(0)
				WG.TerraformBrush.setCurve(1.0)
				WG.TerraformBrush.setIntensity(1.0)
				WG.TerraformBrush.setLengthScale(1.0)
				WG.TerraformBrush.setShape("circle")
				WG.TerraformBrush.setHeightCapMin(nil)
				WG.TerraformBrush.setHeightCapMax(nil)
				WG.TerraformBrush.setHeightCapAbsolute(false)
				WG.TerraformBrush.setClayMode(false)
				WG.TerraformBrush.setGridOverlay(false)
				WG.TerraformBrush.setDustEffects(true)
			end
			capMinValue = 0
			capMaxValue = 0
			capAbsolute = false
			local absImg = doc:GetElementById("btn-cap-absolute")
			if absImg then
				absImg:SetAttribute("src", "/luaui/images/terraform_brush/check_off.png")
			end
			local clayImg = doc:GetElementById("btn-clay-mode")
			if clayImg then
				clayImg:SetAttribute("src", "/luaui/images/terraform_brush/check_off.png")
			end
			local gridImg = doc:GetElementById("btn-grid-overlay")
			if gridImg then
				gridImg:SetAttribute("src", "/luaui/images/terraform_brush/check_off.png")
			end
			local dustImg = doc:GetElementById("btn-dust-effects")
			if dustImg then
				dustImg:SetAttribute("src", "/luaui/images/terraform_brush/check_on.png")
			end
			event:StopPropagation()
		end, false)
	end
end

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

	widgetState.rootElement = document:GetElementById("tf-root")

	local vsx = GetViewGeometry()
	local scaleFactor = math.max(1.0, vsx / BASE_RESOLUTION)
	widgetState.panelWidthDp = math.floor(BASE_WIDTH_DP * scaleFactor)
	widgetState.rootElement:SetAttribute("style", buildRootStyle())

	attachEventListeners()
end

function widget:Update()
	if not WG.TerraformBrush then
		if widgetState.rootElement then
			widgetState.rootElement:SetClass("hidden", true)
		end

		return
	end

	local state = WG.TerraformBrush.getState()
	if not state then
		if widgetState.rootElement then
			widgetState.rootElement:SetClass("hidden", true)
		end

		return
	end

	local isActive = state.active
	if widgetState.rootElement then
		widgetState.rootElement:SetClass("hidden", not isActive)
	end

	if not isActive then
		return
	end

	local effectiveMaxIntensity = getEffectiveMaxIntensity()
	if state.intensity > effectiveMaxIntensity then
		WG.TerraformBrush.setIntensity(effectiveMaxIntensity)
		state = WG.TerraformBrush.getState()
	end

	if widgetState.dmHandle then
		widgetState.dmHandle.radius = state.radius
		widgetState.dmHandle.shapeName = shapeNames[state.shape] or "Circle"
		widgetState.dmHandle.rotationDeg = state.rotationDeg
		widgetState.dmHandle.curve = string.format("%.1f", state.curve)
		widgetState.dmHandle.intensity = string.format("%.1f", state.intensity)
		widgetState.dmHandle.lengthScale = string.format("%.1f", state.lengthScale)
		widgetState.dmHandle.heightCapMaxStr = capMaxValue ~= 0 and tostring(capMaxValue) or "--"
		widgetState.dmHandle.heightCapMinStr = capMinValue ~= 0 and tostring(capMinValue) or "--"
	end

	local doc = widgetState.document
	if doc then
		updatingFromCode = true

		local sliderRotation = doc:GetElementById("slider-rotation")
		if sliderRotation then
			sliderRotation:SetAttribute("value", tostring(state.rotationDeg))
		end

		local sliderCurve = doc:GetElementById("slider-curve")
		if sliderCurve then
			sliderCurve:SetAttribute("value", tostring(math.floor(state.curve * 10 + 0.5)))
		end

		local sliderIntensity = doc:GetElementById("slider-intensity")
		if sliderIntensity then
			sliderIntensity:SetAttribute("max", tostring(intensityToSlider(effectiveMaxIntensity)))
			sliderIntensity:SetAttribute("value", tostring(intensityToSlider(state.intensity)))
		end

		local sliderLength = doc:GetElementById("slider-length")
		if sliderLength then
			sliderLength:SetAttribute("value", tostring(math.floor(state.lengthScale * 10 + 0.5)))
		end

		local sliderSize = doc:GetElementById("slider-size")
		if sliderSize then
			sliderSize:SetAttribute("value", tostring(state.radius))
		end

		local sliderCapMax = doc:GetElementById("slider-cap-max")
		if sliderCapMax then
			sliderCapMax:SetAttribute("value", tostring(capMaxValue))
		end

		local sliderCapMin = doc:GetElementById("slider-cap-min")
		if sliderCapMin then
			sliderCapMin:SetAttribute("value", tostring(capMinValue))
		end

		local sliderHistory = doc:GetElementById("slider-history")
		if sliderHistory then
			local totalSteps = (state.undoCount or 0) + (state.redoCount or 0)
			local maxVal = math.min(totalSteps, 100)
			if maxVal < 1 then maxVal = 1 end
			sliderHistory:SetAttribute("max", tostring(maxVal))
			sliderHistory:SetAttribute("value", tostring(state.undoCount or 0))
		end

		local clayImg = doc:GetElementById("btn-clay-mode")
		if clayImg then
			clayImg:SetAttribute("src", state.clayMode
				and "/luaui/images/terraform_brush/check_on.png"
				or "/luaui/images/terraform_brush/check_off.png")
		end

		local gridImg = doc:GetElementById("btn-grid-overlay")
		if gridImg then
			gridImg:SetAttribute("src", state.gridOverlay
				and "/luaui/images/terraform_brush/check_on.png"
				or "/luaui/images/terraform_brush/check_off.png")
		end

		local dustImg = doc:GetElementById("btn-dust-effects")
		if dustImg then
			dustImg:SetAttribute("src", state.dustEffects
				and "/luaui/images/terraform_brush/check_on.png"
				or "/luaui/images/terraform_brush/check_off.png")
		end

		updatingFromCode = false
	end

	setActiveClass(widgetState.modeButtons, state.mode)
	setActiveClass(widgetState.shapeButtons, state.shape)

	-- Gray out unsupported shapes per mode
	local isRamp = state.mode == "ramp"
	local isLevel = state.mode == "level"
	local rampDisabled = { hexagon = true, octagon = true, ring = true }
	for shape, element in pairs(widgetState.shapeButtons) do
		if element then
			local disabled = (isRamp and rampDisabled[shape]) or (isLevel and shape == "ring")
			element:SetClass("disabled", disabled or false)
		end
	end
end

function widget:Shutdown()
	if widgetState.document then
		widgetState.document:Close()
		widgetState.document = nil
	end

	if widgetState.rmlContext then
		widgetState.rmlContext:RemoveDataModel(MODEL_NAME)
	end

	widgetState.dmHandle = nil
	widgetState.rootElement = nil
	widgetState.modeButtons = {}
	widgetState.shapeButtons = {}
end
