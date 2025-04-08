local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "ReloadCob",
		desc = "Devmode: press CTRL+R to reload the cob scripts of all selected unitDefs",
		author = "Beherith",
		date = "2024.03.12",
		license = "GNU GPL v2",
		layer = 0,
		enabled = false --  loaded by default?
	}
end

include("keysym.h.lua")

------------------------------------------------
-- Press Handling
------------------------------------------------
local doReload = false

function widget:KeyPress(key, modifier, isRepeat)
	if modifier.ctrl then
		if key == KEYSYMS.R then
			doReload = true
		end
	end
end

function widget:Initialize()
	if not Spring.Utilities.IsDevMode() then
		Spring.Echo("ReloadCob widget requires devmode")
		widgetHandler:RemoveWidget()
		return
	end
end

function widget:Update()
	if doReload then
		local reloadedCobDefs = {}
		local selection = Spring.GetSelectedUnits()
		for i, unitID in ipairs(selection) do 
			local unitDefID = Spring.GetUnitDefID(unitID)
			if not reloadedCobDefs[unitDefID] then 
				local unitDefName = UnitDefs[unitDefID].name
				Spring.SendCommands('reloadcob ' .. unitDefName)
				Spring.Echo("Reloaded COB: ".. unitDefName .. " from " .. UnitDefs[unitDefID].scriptName)
				reloadedCobDefs[unitDefID] = true
			end
		end
		doReload = false
	end
end

