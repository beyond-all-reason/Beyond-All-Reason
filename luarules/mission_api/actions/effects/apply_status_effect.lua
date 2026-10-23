local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function applyStatusEffect(effectID, effectName, area, duration, strength)
	GG['MissionAPI'].Modules.Effects.ApplyEffect(effectID, effectName, area, duration, strength or 1)
end

return {
	{
		type = 'ApplyStatusEffect',
		parameters = {
			{ name = 'effectID',   required = true,  type = ParameterTypes.EffectID },
			{ name = 'effectName', required = true,  type = ParameterTypes.String },
			{ name = 'area',       required = false, type = ParameterTypes.Area }, -- default := the whole map
			{ name = 'duration',   required = false, type = ParameterTypes.Quantity }, -- default := until cleared
			{ name = 'strength',   required = false, type = ParameterTypes.PositiveInteger }, -- default := 1
		},
		actionFunction = applyStatusEffect,
	}
}
