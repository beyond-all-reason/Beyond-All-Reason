
local currentMapname = Game.mapName:lower()

local mapSunLighting = {
	['eye of horus v13'] = {
		groundDiffuseColor = { 0.7, 0.56, 0.54 },
		unitAmbientColor = {0.86, 0.7, 0.5},
		unitSpecularColor = {1.1, 0.88, 0.77},
		modelShadowDensity = 0.33,
	},
	['tabula-v4'] = {
		groundDiffuseColor = { 0.9, 0.51, 0.38 },
		unitAmbientColor = {0.8, 0.72, 0.64},
		unitDiffuseColor = {0.93, 0.78, 0.5},
		unitSpecularColor = {0.8, 0.6, 0.5},
		modelShadowDensity = 0.65,
	},
	['tumult'] = {
		groundDiffuseColor = { 0.77, 0.6, 0.44 },
	},
	['valles_marineris_v2'] = {
		groundAmbientColor = { 0.4, 0.55, 0.55 },
		groundDiffuseColor = { 0.92, 0.58, 0.45 },
	},
	['titan v3.1'] = {
		groundAmbientColor = { 0.52, 0.48, 0.48 },
		groundDiffuseColor = { 0.65, 0.58, 0.55 },
		modelShadowDensity = 0.5,
		unitAmbientColor = {0.83, 0.73, 0.63},
	},
	['tempest'] = {
		groundDiffuseColor = { 0.32, 0.28, 0.34 },
		unitAmbientColor = {0.8, 0.77, 0.77},
		unitDiffuseColor = {0.66, 0.65, 0.63},
		unitSpecularColor = {0.5, 0.5, 0.5},
		modelShadowDensity = 0.65,
	},
	['tempest dry'] = {
		groundDiffuseColor = { 0.32, 0.28, 0.34 },
		unitAmbientColor = {0.8, 0.77, 0.77},
		unitDiffuseColor = {0.66, 0.65, 0.63},
		unitSpecularColor = {0.5, 0.5, 0.5},
		modelShadowDensity = 0.65,
	},
	['seths_ravine_v4'] = {
		unitAmbientColor = {0.36, 0.36, 0.36},
		unitDiffuseColor = {0.88, 0.78, 0.68},
		unitSpecularColor = {0.88, 0.78, 0.68},
		modelShadowDensity = 0.66,
	},
}

local mapSun = {
	['eye of horus v13'] = {0.23, 0.62, 0.6},
	['titan v3.1'] = { 0.6, 0.82, -0.33 },
	['tempest'] = { -0.35, 0.83, 0.47 },
	['tempest dry'] = { -0.35, 0.83, 0.47 },
	['seths_ravine_v4'] = { -0.6, 0.63, 0.43 },
}

if not mapSunLighting[currentMapname] and not mapSun[currentMapname] then return end

function widget:GetInfo()
	return {
		name      = "Map Lighting Adjuster",
		desc      = "Adjusts map lighting on various maps (pre game-start)",
		author    = "Floris",
		date      = "August 2021",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true
	}
end

function widget:Initialize()
	--if Spring.GetGameFrame() == 0 then
		if mapSun[currentMapname] then
			Spring.SetSunDirection(mapSun[currentMapname][1], mapSun[currentMapname][2], mapSun[currentMapname][3])
			Spring.SetSunLighting({ groundShadowDensity = gl.GetSun("shadowDensity"), modelShadowDensity = gl.GetSun("shadowDensity") })
			--Spring.SendCommands("luarules updatesun")
		end
		if mapSunLighting[currentMapname] then
			Spring.SetSunLighting(mapSunLighting[currentMapname])
			Spring.SendCommands("luarules updatesun")
		end
	--end
	widgetHandler:RemoveWidget()
end
