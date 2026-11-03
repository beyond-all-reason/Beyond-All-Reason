-- Ends a pause started by the Pause action. Does nothing for a player pause.
local function unpause()
	GG.GamePause.Unpause("mission")
end

return {
	{
		type = 'Unpause',
		parameters = {},
		actionFunction = unpause,
	}
}
