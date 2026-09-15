local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function playMusic(soundfile)
    if not GG["music"] then
        error("[Mission API] Music API unavailable (api_music.lua gadget not loaded), cannot play: " .. tostring(soundfile))
    end

    GG["music"].GadgetPlayMusicTrack(soundfile)
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
