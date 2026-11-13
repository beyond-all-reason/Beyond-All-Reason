local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function stopPlayback(soundFile)
	GG['MissionAPI'].Modules.Sounds.StopSound(soundFile)
end

return {
	{
		type = 'StopPlayback',
		parameters = {
			{ name = 'soundFile', required = true, type = ParameterTypes.SoundFile },
		},
		actionFunction = stopPlayback,
	}
}
