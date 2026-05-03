-- tf_guide.lua: extracted tool module for gui_terraform_brush
local M = {}

function M.attach(doc, ctx)
	local widgetState = ctx.widgetState
	local trackSliderDrag = ctx.trackSliderDrag
	local guideHints = ctx.guideHints
	local g3ElemGroup = ctx.g3ElemGroup
	local g3TipGroups = ctx.g3TipGroups

	widgetState.floatingTipEl  = doc:GetElementById("tf-guide-floating-tip")
	widgetState.settingsRootEl = doc:GetElementById("tf-settings-root")  -- used by makeWindowDraggable

	-- Pen sensitivity slider drag tracking
	local sliderPen = doc:GetElementById("slider-pen-sensitivity")
	if sliderPen then trackSliderDrag(sliderPen, "pen-sensitivity") end

	-- Guide hint mouseover/mouseout listeners (justified: dynamic loop over hints table)
	for elemId, hint in pairs(guideHints) do
		local el = doc:GetElementById(elemId)
		if el then
			el:AddEventListener("mouseover", function(event)
				if widgetState.guideMode then widgetState.currentHint = hint end
			end, false)
			el:AddEventListener("mouseout", function(event)
				if widgetState.guideMode then widgetState.currentHint = nil end
			end, false)
		end
	end

	-- G3: Shortcut discovery tips â€” fire near cursor after 3 interactions (guide mode only)
	for elemId, group in pairs(g3ElemGroup) do
		local el = doc:GetElementById(elemId)
		if el then
			el:AddEventListener("mousedown", function(event)
				if not widgetState.guideMode then return end
				local cnt = (widgetState.g3GroupCounts[group] or 0) + 1
				widgetState.g3GroupCounts[group] = cnt
				if cnt >= 3 and not widgetState.g3GroupShown[group] then
					widgetState.g3GroupShown[group] = true
					widgetState.g3Toast.text   = g3TipGroups[group]
					widgetState.g3Toast.expiry = (Spring.GetGameSeconds() or 0) + 5
				end
			end, false)
		end
	end

	-- All data-event-click/change handlers (onGuideXxx) are defined in initialModel
	-- in gui_terraform_brush.lua â€” Recoil forbids adding or replacing function
	-- keys in a DataModel after OpenDataModel.
end

return M
