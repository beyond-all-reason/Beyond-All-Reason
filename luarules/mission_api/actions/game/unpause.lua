-- Ends a pause started by the Pause action. Does nothing for a player pause.
local function unpause()
	GG.ScriptedPause.Unpause()
end

return {
	{
		type = 'Unpause',
		parameters = {},
		actionFunction = unpause,
	}
}
