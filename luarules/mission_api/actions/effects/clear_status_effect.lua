local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function clearStatusEffect(effectName)
	GG['MissionAPI'].Modules.Effects.ClearEffect(effectName)
end

return {
	{
		type = 'ClearStatusEffect',
		parameters = {
			{ name = 'effectName', required = true, type = ParameterTypes.String },
		},
		actionFunction = clearStatusEffect,
	}
}
