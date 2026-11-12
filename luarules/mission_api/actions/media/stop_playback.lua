local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function stopPlayback(soundfile)
	GG['MissionAPI'].Modules.Sounds.StopSound(soundfile)
end

return {
	{
		type = 'StopPlayback',
		parameters = {
			{ name = 'soundfile', required = true, type = ParameterTypes.SoundFile },
		},
		actionFunction = stopPlayback,
	}
}
