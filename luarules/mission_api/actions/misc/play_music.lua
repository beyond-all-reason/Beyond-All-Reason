local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function playMusic(soundfile)
    if GG["music"] then
        GG["music"].GadgetPlayMusicTrack(soundfile)
    end
end

return {
	{
		type = 'PlayMusic',
		parameters = {
			{ name = 'soundfile', required = true, type = ParameterTypes.String },
		},
		actionFunction = playMusic,
	}
}