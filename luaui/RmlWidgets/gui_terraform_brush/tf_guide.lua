-- tf_guide.lua: guide mode and settings window wiring for the gui_terraform_brush panel
local M = {}

-- RmlUi listener closures can run outside the widget env, where bare globals
-- are nil: capture what they use as upvalues.
local WG = WG
local Spring = Spring

function M.attach(doc, ctx)
	local widgetState = ctx.widgetState
	local trackSliderDrag = ctx.trackSliderDrag
	local guideHints = ctx.guideHints
	local g3ElemGroup = ctx.g3ElemGroup
	local g3TipGroups = ctx.g3TipGroups

	widgetState.floatingTipEl = doc:GetElementById("tf-guide-floating-tip")
	widgetState.settingsRootEl = doc:GetElementById("tf-settings-root") -- used by makeWindowDraggable

	-- Pen sensitivity slider drag tracking
	local sliderPen = doc:GetElementById("slider-pen-sensitivity")
	if sliderPen then
		trackSliderDrag(sliderPen, "pen-sensitivity")
	end

	-- Hints are looked up at hover time, not captured: contextual hints (btn-splat
	-- under the tileset shader) replace guideHints entries at runtime.
	for elemId, hint in pairs(guideHints) do
		local el = doc:GetElementById(elemId)
		if el then
			el:AddEventListener("mouseover", function(event)
				if widgetState.guideMode then
					widgetState.currentHint = guideHints[elemId]
				end
			end, false)
			el:AddEventListener("mouseout", function(event)
				if widgetState.guideMode then
					widgetState.currentHint = nil
				end
			end, false)
		end
	end

	-- Shortcut discovery tips: a toast near the cursor after 3 clicks in a group (guide mode only)
	for elemId, group in pairs(g3ElemGroup) do
		local el = doc:GetElementById(elemId)
		if el then
			el:AddEventListener("mousedown", function(event)
				if not widgetState.guideMode then
					return
				end
				local cnt = (widgetState.g3GroupCounts[group] or 0) + 1
				widgetState.g3GroupCounts[group] = cnt
				if cnt >= 3 and not widgetState.g3GroupShown[group] then
					widgetState.g3GroupShown[group] = true
					widgetState.g3Toast.text = g3TipGroups[group]
					widgetState.g3Toast.expiry = (Spring.GetGameSeconds() or 0) + 5
				end
			end, false)
		end
	end

	-- The onGuideXxx handlers live in initialModel (gui_terraform_brush.lua): Recoil
	-- forbids adding function keys to a DataModel after OpenDataModel.
end

return M
