local function unlockPlayerInput()
	SendToUnsynced('MissionUnlockPlayerInput')
end

return {
	{
		type = 'UnlockPlayerInput',
		parameters = {},
		actionFunction = unlockPlayerInput,
	}
}
