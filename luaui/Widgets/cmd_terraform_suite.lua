local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name    = "Terraform Suite Launcher",
		desc    = "Loads the map editor suite on demand (/terraformbrush, /terraformpanel, /terraformsuite)",
		author  = "PtaQQ",
		date    = "July 2026",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true,
		handler = true,
	}
end

-- The editor widgets ship enabled = false so players who never open the editor
-- pay nothing for the suite: no Lua parse, no RML documents, no callins.
-- This launcher is the only always-on piece. It owns the suite entry commands,
-- enables the suite widgets on first use, then passes every later invocation
-- through to the real handlers (they sort after us in the action list).
local SUITE_WIDGETS = {
	"Terraform Brush",
	"Terraform Brush UI",
	"Clone Tool",
	"Decal Capture",
	"Decal Placer",
	"Decal Placer UI",
	"Diffuse Painter",
	"Diffuse Library UI",
	"Feature Placer",
	"Feature Placer UI",
	"Grass Brush",
	"Light Placer",
	"Metal Brush",
	"Splat Painter",
	"Start Positions Tool",
	"Weather Brush",
	"Weather Brush UI",
	"Water Type Overlay GL4",
}

-- Entry commands that must work before the suite is loaded. Sub-tool actions
-- (/diffusepaint, /grassbrush, ...) become available once the suite is up.
local ENTRY_ACTIONS = {
	"terraformbrush", "terraformup", "terraformdown", "terraformlevel",
	"terraformsmooth", "terraformerode", "terraformramp", "terraformrestore",
	"terraformexport", "terraformimport", "terraformpanel",
}

local suiteEnabled = false

local function enableSuite()
	if suiteEnabled then return false end
	suiteEnabled = true
	Spring.Echo("[Terraform Suite] Loading map editor widgets...")
	for i = 1, #SUITE_WIDGETS do
		widgetHandler:EnableWidget(SUITE_WIDGETS[i])
	end
	return true
end

function widget:Initialize()
	-- EnableWidget persists enablement through SaveConfigData. If a crash
	-- skipped our Shutdown cleanup the suite comes back enabled next game;
	-- adopt it so entry commands pass through and Shutdown disables it again.
	local order = widgetHandler.orderList and widgetHandler.orderList["Terraform Brush"]
	if order and order > 0 then
		suiteEnabled = true
	end

	widgetHandler:AddAction("terraformsuite", function()
		if not enableSuite() then
			Spring.Echo("[Terraform Suite] Already loaded")
		end
		return true
	end, nil, "t")

	for i = 1, #ENTRY_ACTIONS do
		local cmd = ENTRY_ACTIONS[i]
		widgetHandler:AddAction(cmd, function(_, optLine)
			if suiteEnabled then
				return false -- suite widgets own this command now
			end
			enableSuite()
			-- Re-dispatch so the real handler, registered while enabling,
			-- receives the original command with its arguments.
			Spring.SendCommands(cmd .. ((optLine and optLine ~= "") and (" " .. optLine) or ""))
			return true
		end, nil, "t")
	end
end

function widget:Shutdown()
	-- Leave the widget config the way we found it, otherwise SaveConfigData
	-- keeps the whole suite enabled for all of this player's future games.
	-- Direct orderList write instead of DisableWidgetRaw: removing widgets
	-- while the handler iterates its shutdown list is not safe.
	if suiteEnabled and widgetHandler.orderList then
		for i = 1, #SUITE_WIDGETS do
			if (widgetHandler.orderList[SUITE_WIDGETS[i]] or 0) > 0 then
				widgetHandler.orderList[SUITE_WIDGETS[i]] = 0
			end
		end
		widgetHandler:SaveConfigData()
	end
end
