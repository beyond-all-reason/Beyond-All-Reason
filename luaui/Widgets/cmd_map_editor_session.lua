local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Map Editor Session",
		desc = "Opens the terraformer and strips the combat UI when the session was launched to edit a map",
		author = "Robert Burnham",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 1000001,
		enabled = true,
		handler = true,
	}
end

-- The lobby marks a session with the mapeditor modoption. Stopping the file here rather than
-- checking the flag inside the callins means an ordinary game defines none of them and pays
-- nothing, and opening the terraformer in a normal game is untouched.
--
-- Not gated through the enabled field: LoadWidget only consults that when the widget has no
-- entry in the order list, and the first game without the modoption writes a zero, after which
-- the field is never read again.
if not Spring.GetModOptions().mapeditor then
	return
end

local HIDDEN_WIDGETS = {
	"AdvPlayersList",
	"Build menu",
	"Grid menu",
	"Order menu",
	"Unit Groups",
	"Idle Builders",
}

local step = 1

-- RemoveWidgetRaw rather than DisableWidgetRaw: the latter zeroes the widget's order and saves,
-- which would leave a player's next real game missing its UI.
local function hideWidget(name)
	local instance = widgetHandler:FindWidget(name)
	if instance then
		widgetHandler:RemoveWidgetRaw(instance)
	end
end

-- Both steps run from Update, not Initialize: Initialize is called while the handler is still
-- walking its load list, and removing widgets there reenters it.
function widget:Update()
	-- Cheat is deliberately not sent here: engaging a terrain mode already nudges it on, and
	-- the command toggles, so a second sender racing the first turns cheats back off.
	if step == 1 then
		step = 2
		for i = 1, #HIDDEN_WIDGETS do
			hideWidget(HIDDEN_WIDGETS[i])
		end

		-- The top bar keeps its buttons: they carry the only way back to the lobby.
		if WG.topbar then
			WG.topbar.setResourceBarsVisible(false)
			WG.topbar.setIndicatorsVisible(false)
		end

		return
	end

	-- terraformbrush is one of the suite launcher's entry commands: it loads the whole suite on
	-- first use and re-dispatches, so the editor needs no widget wrangling from here.
	if step == 2 then
		step = 3
		Spring.SendCommands("terraformbrush")
	end
end
