local function unlockPlayerInput()
	Spring.SetGameRulesParam('playerInputLock', 0)
end

return {
	{
		type = 'UnlockPlayerInput',
		parameters = {},
		actionFunction = unlockPlayerInput,
	}
}
