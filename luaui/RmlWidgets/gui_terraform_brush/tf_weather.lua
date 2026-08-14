-- tf_weather.lua: extracted tool module for gui_terraform_brush
local M = {}

function M.attach(doc, ctx)
	if ctx.attachTBMirrorControls then ctx.attachTBMirrorControls(doc, "wb") end
	local trackSliderDrag = ctx.trackSliderDrag

	-- Slider drag tracking (legitimate imperative: slider-specific drag state).
	-- drag ID must match the element ID so the Update sync can guard against
	-- overwriting a slider the user is actively dragging.
	for _, sid in ipairs({ "size", "length", "rotation", "count", "cadence", "frequency", "persist" }) do
		local sl = doc:GetElementById("wb-slider-" .. sid)
		if sl then trackSliderDrag(sl, "wb-slider-" .. sid) end
	end
	-- All data-event-click/change handlers (onWbXxx) are defined in initialModel
	-- in gui_terraform_brush.lua — Recoil forbids adding or replacing function
	-- keys in a DataModel after OpenDataModel.
end

return M
