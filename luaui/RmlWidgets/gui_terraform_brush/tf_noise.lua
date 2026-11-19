-- tf_noise.lua: NOISE tool controls of the terraform brush panel.
local M = {}

function M.attach(doc, ctx)
	local widgetState = ctx.widgetState
	local trackSliderDrag = ctx.trackSliderDrag

	widgetState.noiseRootEl = doc:GetElementById("tf-noise-root")

	-- Drag state needs a listener per slider; value changes come from onchange= in the RML.
	for _, sid in ipairs({ "noise-scale", "noise-octaves", "noise-persistence", "noise-lacunarity", "noise-seed" }) do
		local sl = doc:GetElementById("slider-" .. sid)
		if sl then
			trackSliderDrag(sl, sid)
		end
	end
	-- The onNoXxx event handlers live in initialModel in gui_terraform_brush.lua:
	-- Recoil forbids adding or replacing function keys after OpenDataModel.
end

return M
