-- Hides the interface but for the menu buttons and blocks all input but Esc, until UnlockPlayerInput.
-- The Player Input Lock widget follows this game rules param on every client.
local function lockPlayerInput()
	Spring.SetGameRulesParam('playerInputLock', 1)
end

return {
	{
		type = 'LockPlayerInput',
		parameters = {},
		actionFunction = lockPlayerInput,
	}
}
