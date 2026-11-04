local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Map Editor Session",
		desc = "Opens the terraformer when the session was launched to edit a map",
		author = "Robert Burnham",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 1000001,
		enabled = true,
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

local opened = false

-- The game's own interface stays: units keep their build and order menus. While an editor tool
-- is in use the suite's key gate keeps game hotkeys out of its way, and the pause button on the
-- panel hands them back.
function widget:Update()
	if opened then
		return
	end
	opened = true
	-- Cheat is deliberately not sent here: engaging a terrain mode already nudges it on, and
	-- the command toggles, so a second sender racing the first turns cheats back off.
	-- terraformbrush is one of the suite launcher's entry commands: it loads the whole suite on
	-- first use and re-dispatches, so the editor needs no widget wrangling from here.
	Spring.SendCommands("terraformbrush")
end
