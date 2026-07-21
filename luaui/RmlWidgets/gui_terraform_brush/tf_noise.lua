-- tf_noise.lua: extracted tool module for gui_terraform_brush
local M = {}

function M.attach(doc, ctx)
	local widgetState = ctx.widgetState
	local trackSliderDrag = ctx.trackSliderDrag
	-- ============ Noise Brush controls ============

	widgetState.noiseRootEl = doc:GetElementById("tf-noise-root")

	-- Slider drag tracking (legitimate imperative: slider-specific drag state).
	-- Slider change events are wired declaratively via onchange= in RML.
	for _, sid in ipairs({ "noise-scale", "noise-octaves", "noise-persistence", "noise-lacunarity", "noise-seed" }) do
		local sl = doc:GetElementById("slider-" .. sid)
		if sl then trackSliderDrag(sl, sid) end
	end
	-- All data-event-click/change handlers (onNoXxx) are defined in initialModel
	-- in gui_terraform_brush.lua — Recoil forbids adding or replacing function
	-- keys in a DataModel after OpenDataModel.
end

return M
