local Types = GG['MissionAPI'].Modules.ParameterTypes.Types

local function playSound(soundfile, volume, position, enqueue)
	local sounds = GG['MissionAPI'].Modules.Sounds
	if enqueue then
		sounds.EnqueueSound(soundfile, volume, position)
	else
		sounds.PlaySound(soundfile, volume, position)
	end
end

return {
	type = 'PlaySound',
	parameters = {
		{ name = 'soundfile', required = true, type = Types.SoundFile },
		{ name = 'volume', required = false, type = Types.Number },
		{ name = 'position', required = false, type = Types.Position },
		{ name = 'enqueue', required = false, type = Types.Boolean },
	},
	actionFunction = playSound,
}
