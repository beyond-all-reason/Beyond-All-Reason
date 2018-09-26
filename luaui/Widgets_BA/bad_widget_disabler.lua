function widget:GetInfo()
	return {
		name      = "Disable Bad Widgets",
		desc      = "Disables broken widgets based on config.",
		author    = "_Shaman",
		date      = "09/24/18",
		license   = "CC0",
		layer     = 5,
		enabled   = true,
		alwaysStart = true,
		handler = true,
	}
end

--[[Documentation:
The table below here controls what widgets are disabled. To add new widgets to it, simply add the line [2] = "widget human name"
(NOT the file name! It's the string in the name field of the widget!).

When the widget is loaded, it sees if widgets included in the table are loaded, and disables them if they are.
After this is completed, the widget removes itself.

Please also include the reason in the reason table.]]

-- Speed ups --
local spEcho = Spring.Echo

-- config --
local badwidgets = {
	"*Mearth Location Tags*1.0", -- Map: Mearth_v4.
	"Ambient Player", -- Map: DeltaSiegeDry v8.
}

local reason = {
	"Causes black ground on some graphics cards, possible copyright issues.",
	"Ambient bird sounds are highly disliked"
}

-- callins --
function widget:Initialize()
	for i=1, #badwidgets do
		if widgetHandler:IsWidgetKnown(badwidgets[i]) then -- If this widget is loaded, unload it and echo a reason.
			spEcho("Disabled '" .. badwidgets[i] .. "' (Reason: " .. tostring(reason[i]) .. ")")
			widgetHandler:DisableWidget(badwidgets[i])
		end
	end
	widgetHandler:RemoveWidget(widget)
end
