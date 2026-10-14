-- Hides the interface but for the menu buttons and blocks all input but Esc, until UnlockPlayerInput.
local function lockPlayerInput()
	SendToUnsynced('MissionLockPlayerInput')
end

return {
	{
		type = 'LockPlayerInput',
		parameters = {},
		actionFunction = lockPlayerInput,
	}
}
