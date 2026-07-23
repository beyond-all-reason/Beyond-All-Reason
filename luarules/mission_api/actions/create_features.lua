local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function createFeatures(featureLoadout)
	GG['MissionAPI'].Modules.Loadout.SpawnFeatureLoadout(featureLoadout)
end

return {
	type = 'CreateFeatures',
	parameters = {
		{ name = 'featureLoadout', required = true, type = ParameterTypes.FeatureLoadout },
	},
	actionFunction = createFeatures,
}
