-- tf_weather.lua: weather tool wiring for the gui_terraform_brush panel
local M = {}

function M.attach(doc, ctx)
	local trackSliderDrag = ctx.trackSliderDrag

	-- Drag IDs match the element IDs so the Update sync skips a slider being dragged.
	for _, sid in ipairs({ "size", "length", "rotation", "count", "cadence", "persist" }) do
		local sl = doc:GetElementById("wb-slider-" .. sid)
		if sl then
			trackSliderDrag(sl, "wb-slider-" .. sid)
		end
	end
	-- The onWbXxx handlers live in initialModel (gui_terraform_brush.lua): Recoil
	-- forbids adding function keys to a DataModel after OpenDataModel.
end

return M
