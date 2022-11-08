-- This file contains all the unit-attached lights
-- Including cob-animated lights, like thruster attached ones, and fusion glows
-- Searchlights also go here
-- As well as muzzle glow should also go here
-- nanolasers should also be here
-- (c) Beherith (mysterme@gmail.com)


local exampleLight = {
	lightType = 'point', -- or cone or beam
	-- if pieceName == nil then the light is treated as WORLD-SPACE
	-- if pieceName == valid piecename, then the light is attached to that piece
	-- if pieceName == invalid piecename, then the light is attached to base of unit
	pieceName = nil,
	-- If you want to make the light be offset from the top of the unit, specify how many elmos above it should be!
	aboveUnit = nil,
	-- Lights that should spawn even if they are outside of view need this set:
	alwaysVisible = nil,
	lightConfig = {
		posx = 0, posy = 0, posz = 0, radius = 100,
		r = 1, g = 1, b = 1, a = 1,
		-- point lights only, colortime in seconds for unit-attached:
			color2r = 1, color2g = 1, color2b = 1, colortime = 15,
		-- cone lights only, specify direction and half-angle in radians:
			dirx = 0, diry = 0, dirz = 1, theta = 0.5,
		-- beam lights only, specifies the endpoint of the beam:
			pos2x = 100, pos2y = 100, pos2z = 100,
		modelfactor = 1, specular = 1, scattering = 1, lensflare = 1,
		lifetime = 0, sustain = 1, 	aninmtype = 0 -- unused
	},
}

-- multiple lights per unitdef/piece are possible, as the lights are keyed by lightname

local unitDefLights = {
	[UnitDefNames['armpw'].id] = {
		headlightpw = { -- this is the lightname
			lightType = 'cone',
			pieceName = 'justattachtobase', -- invalid ones will attach to the worldpos of the unit
			lightConfig = { posx = 0, posy = 23, posz = 7, radius = 150,
				dirx = 0, diry = -0.07, dirz = 1, theta = 0.3,
				r = 1, g = 1, b = 0.89999998, a = 0.5,
				modelfactor = -0.5, specular = 0.5, scattering = 1.5, lensflare = 0.60000002,
				lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['armrad'].id] = {
		-- searchlight = {
		-- 	lightType = 'cone',
		-- 	pieceName = 'dish',
		-- 	lightConfig = { posx = 0, posy = 0, posz = 0, radius = 70,
		-- 		dirx = 0, diry = 0, dirz = -1, theta = 0.2,
		-- 		r = 0.5, g = 3, b = 0.5, a = 1,
		-- 		modelfactor = 0.5, specular = 1, scattering = 2, lensflare = 0,
		-- 		lifetime = 0, sustain = 0, animtype = 0},
		-- },
		greenblob = {
			lightType = 'point',
			pieceName = 'turret',
			lightConfig = { posx = 0, posy = 72, posz = 0, radius = 20,
				color2r = 0, color2g = 0, color2b = 0, colortime = 0,
				r = 0, g = 1, b = 0, a = 0.60000002,
				modelfactor = 0.80000001, specular = 0.89999998, scattering = 1, lensflare = 10,
				lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['corrad'].id] = {
		greenblob = {
			lightType = 'point',
			pieceName = 'turret',
			lightConfig = { posx = 0, posy = 82, posz = 0, radius = 20,
				color2r = 0, color2g = 0, color2b = 0, colortime = 0,
				r = 0, g = 1, b = 0, a = 0.60000002,
				modelfactor = 0.80000001, specular = 0.89999998, scattering = 1, lensflare = 10,
				lifetime = 0, sustain = 0, animtype = 0},
		},
	},

	[UnitDefNames['armarad'].id] = {
		greenblob = {
			lightType = 'point',
			pieceName = 'base',
			lightConfig = { posx = 0, posy = 64, posz = 0, radius = 24,
				color2r = 0, color2g = 2, color2b = 0, colortime = 40,
				r = 0, g = 1, b = 0, a = 0.60000002,
				modelfactor = 0.80000001, specular = 0.89999998, scattering = 1, lensflare = 10,
				lifetime = 0, sustain = 0, animtype = 0},
		},
	},

	[UnitDefNames['corarad'].id] = {
		greenblob = {
			lightType = 'point',
			pieceName = 'base',
			lightConfig = { posx = 0, posy = 90, posz = 0, radius = 20,
				color2r = 0, color2g = 2, color2b = 0, colortime = 40,
				r = 0, g = 1, b = 0, a = 0.60000002,
				modelfactor = 0.80000001, specular = 0.89999998, scattering = 1, lensflare = 10,
				lifetime = 0, sustain = 0, animtype = 0},
		},
	},

	[UnitDefNames['armtarg'].id] = {
		greenblob = {
			lightType = 'point',
			pieceName = 'base',
			lightConfig = { posx = 10, posy = 108, posz = -10, radius = 17,
				color2r = 0, color2g = 0, color2b = 0, colortime = 12,
				r = 0, g = 1.5, b = 0, a = 0.8,
				modelfactor = 0.8, specular = 0.9, scattering = 1, lensflare = 10,
				lifetime = 0, sustain = 20, animtype = 0},
		},
	},

	[UnitDefNames['armllt'].id] = {
		searchlightllt = {
			lightType = 'cone',
			pieceName = 'sleeve',
			lightConfig = { posx = 0, posy = 5, posz = 5.80000019, radius = 450,
				dirx = 0, diry = 0, dirz = 1, theta = 0.25,
				r = 1, g = 1, b = 1, a = 0.5,
				modelfactor = 0.2, specular = 1, scattering = 1, lensflare = 1,
				lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['corllt'].id] = {
		searchlightllt = {
			lightType = 'cone',
			pieceName = 'turret',
			lightConfig = { posx = 0, posy = 5, posz = 5.80000019, radius = 450,
				dirx = 0, diry = 0, dirz = 1, theta = 0.25,
				r = 1, g = 1, b = 1, a = 0.5,
				modelfactor = 0.2, specular = 1, scattering = 1, lensflare = 1,
				lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['armbeamer'].id] = {
		searchlightllt = {
			lightType = 'point',
				pieceName = 'barrel',
				lightConfig = { posx = 0, posy = 0, posz = 6, radius = 16,
				color2r = 0, color2g = 0.07, color2b = 0.65, colortime = 45,
				r = 0, g = 0.15, b = 1.5, a = 1,
				modelfactor = 1, specular = 1, scattering = 1.4, lensflare = 10,
				lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['armnanotc'].id] = {
		nanolight = {
			lightType = 'point',
			pieceName = 'emitnano',
			lightConfig = { posx = 0, posy = 0, posz = 1, radius = 20,
							color2r = 0, color2g = 0, color2b = 0, colortime = 0,
							r = -1, g = 1, b = 1, a = 0.3,
							modelfactor = 0.5, specular = 0.5, scattering = 1.5, lensflare = 10,
							lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['cornanotc'].id] = {
		nanolight = {
			lightType = 'point',
			pieceName = 'emitnano',
			lightConfig = { posx = 0, posy = 0, posz = 1, radius = 20,
							color2r = 0, color2g = 0, color2b = 0, colortime = 0,
							r = -1, g = 1, b = 1, a = 0.3,
							modelfactor = 0.5, specular = 0.5, scattering = 1.5, lensflare = 10,
							lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['armrl'].id] = {
		searchlightrl = {
			lightType = 'cone',
			pieceName = 'sleeve',
			lightConfig = { posx = 0, posy = 0, posz = 7, radius = 450,
				dirx = 0, diry = 0, dirz = 1, theta = 0.2,
				r = 1, g = 1, b = 1, a = 0.5,
				modelfactor = 0.2, specular = 0.2, scattering = 2, lensflare = 0,
				lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['corrl'].id] = {
		searchlightrl = {
			lightType = 'cone',
			pieceName = 'turret',
			lightConfig = { posx = 0, posy = 2, posz = 7, radius = 450,
				dirx = 0, diry = 0, dirz = 1, theta = 0.2,
				r = 1, g = 1, b = 1, a = 0.5,
				modelfactor = 0.2, specular = 0.2, scattering = 2, lensflare = 0,
				lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['armjamt'].id] = {
		cloaklightred = {
				lightType = 'point',
				pieceName = 'turret',
				lightConfig = { posx = 0, posy = 30, posz = 0, radius = 28,
				color2r = 0, color2g = 0, color2b = 1, colortime = 0,
				r = 1, g = 0, b = 0, a = 0.5,
				modelfactor = 0.5, specular = 0.5, scattering = 1.5, lensflare = 10,
				lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['corjamt'].id] = {
		cloaklightred = {
				lightType = 'point',
				pieceName = 'base',
				lightConfig = { posx = 0, posy = 44, posz = 0, radius = 28,
				color2r = 0, color2g = 0, color2b = 1, colortime = 0,
				r = 1, g = 0, b = 0, a = 0.5,
				modelfactor = 0.5, specular = 0.5, scattering = 1.5, lensflare = 10,
				lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['armveil'].id] = {
		cloaklightred = {
				lightType = 'point',
				pieceName = 'turret',
				lightConfig = { posx = 0, posy = 42, posz = 0, radius = 35,
				color2r = 0, color2g = 0, color2b = 1, colortime = 0,
				r = 1, g = 0, b = 0, a = 0.5,
				modelfactor = 0.5, specular = 0.5, scattering = 1.5, lensflare = 10,
				lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['armack'].id] = {
		beacon1 = { -- this is the lightname
			lightType = 'cone',
			pieceName = 'beacon1',
			lightConfig = { posx = 0, posy = 0, posz = 0, radius = 21,
				dirx = 1, diry = 0, dirz = 0, theta = 0.99000001,
				r = 1.29999995, g = 0.89999998, b = 0.1, a = 2,
				modelfactor = 0.1, specular = 0.2, scattering = 1.5, lensflare = 10,
				lifetime = 0, sustain = 0, animtype = 0},
		},
		beacon2 = {
			lightType = 'cone',
			pieceName = 'beacon2',
			lightConfig = { posx = 0, posy = 0, posz = 0, radius = 21,
				dirx = -1, diry = 0, dirz = 0, theta = 0.99000001,
				r = 1.29999995, g = 0.89999998, b = 0.1, a = 2,
				modelfactor = 0.1, specular = 0.2, scattering = 1.5, lensflare = 10,
				lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['armstump'].id] = {
		searchlightstump = {
			lightType = 'cone',
			pieceName = 'base',
			lightConfig = { posx = 0, posy = 0, posz = 10, radius = 100,
				dirx = 0, diry = -0.08, dirz = 1, theta = 0.25999999,
				r = 1, g = 1, b = 0.89999998, a = 0.5,
				modelfactor = -0.5, specular = 0.5, scattering = 1.5, lensflare = 0.60000002,
				lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['armbanth'].id] = {
		searchlightbanth = {
			lightType = 'cone',
			pieceName = 'turret',
			lightConfig = { posx = 0, posy = 2, posz = 18, radius = 470,
				dirx = 0, diry = -0.12, dirz = 1, theta = 0.18,
				r = 1, g = 1, b = 1, a = 0.5,
				modelfactor = -0.1, specular = 0.15, scattering = 3.4, lensflare = 1,
				lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['corkorg'].id] = {
		headlightkorg = {
			lightType = 'point',
			pieceName = 'head',
			lightConfig = { posx = 0, posy = 28, posz = 12, radius = 34,
				color2r = 0.4, color2g = 0, color2b = 0, colortime = 50,
				r = 2, g = 0.2, b = 0, a = 1,
				modelfactor = 0.2, specular = 0.2, scattering = 0, lensflare = 0,
				lifetime = 0, sustain = 0, animtype = 0},
		},
		shoulderlightkorgleft = {
			lightType = 'point',
			pieceName = 'luparm',
			lightConfig = { posx = 14, posy = 20, posz = 0, radius = 26,
				color2r = 1.6, color2g = 0.2, color2b = 0, colortime = 50,
				r = 0.4, g = 0.0, b = 0, a = 0.8,
				modelfactor = 0.2, specular = 0.2, scattering = 0, lensflare = 0,
				lifetime = 0, sustain = 0, animtype = 0},
		},
		shoulderlightkorgright = {
			lightType = 'point',
			pieceName = 'ruparm',
			lightConfig = { posx = -14, posy = 20, posz = 0, radius = 26,
				color2r = 1.6, color2g = 0.2, color2b = 0, colortime = 50,
				r = 0.4, g = 0.0, b = 0, a = 0.8,
				modelfactor = 0.2, specular = 0.2, scattering = 0, lensflare = 0,
				lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['armcom'].id] = {
		headlightarmcom = {
			lightType = 'cone',
			pieceName = 'head',
			lightConfig = { posx = 0, posy = 0, posz = 10, radius = 420,
				dirx = 0, diry = -0.25, dirz = 1, theta = 0.25999999,
				r = -1, g = 1, b = 1, a = 0.75,
				modelfactor = 0.15, specular = 0.7, scattering = 3.5, lensflare = 1,
				lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['corcom'].id] = {
		headlightcorcom = {
			lightType = 'cone',
			pieceName = 'head',
			lightConfig = { posx = 0, posy = 1, posz = 9, radius = 420,
				dirx = 0, diry = -0.17, dirz = 1, theta = 0.25999999,
				r = -1, g = 1, b = 1, a = 0.75,
				modelfactor = 0.15, specular = 0.7, scattering = 3.5, lensflare = 1,
				lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['armcv'].id] = {
		nanolightarmcv = {
			lightType = 'cone',
			pieceName = 'nano1',
			lightConfig = { posx = 3, posy = 0, posz = -4, radius = 120,
				dirx = 0, diry = 0, dirz = 1, theta = 0.30000001,
				r = -1, g = 0, b = 0, a = 1,
				modelfactor = 0, specular = 1, scattering = 3, lensflare = 0,
				lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['armca'].id] = {
		nanolightarmca = {
			lightType = 'cone',
			pieceName = 'nano',
			lightConfig = { posx = 0, posy = 0, posz = 0, radius = 120,
				dirx = 0, diry = 0, dirz = -1, theta = 0.30000001,
				r = -1, g = 0, b = 0, a = 1,
				modelfactor = 0, specular = 1, scattering = 3, lensflare = 0,
				lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['armamd'].id] = {
		readylightamd = {
			lightType = 'point',
			pieceName = 'antenna',
			lightConfig = { posx = 0, posy = 1, posz = 0, radius = 22,
				color2r = 0, color2g = 0, color2b = 0, colortime = 15,
				r = 2, g = 1, b = 0, a = 1,
				modelfactor = 0.1, specular = 0.5, scattering = 0.66, lensflare = 6,
				lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['armatlas'].id] = {
		jetr = {
			lightType = 'cone',
			pieceName = 'thrustr',
			lightConfig = { posx = -2, posy = 0, posz = -2, radius = 140,
				dirx = 0, diry = 0, dirz = -1, theta = 0.8,
				r = 1, g = 0.98, b = 0.85, a = 0.4,
				modelfactor = 0, specular = 1, scattering = 0.5, lensflare = 1,
				lifetime = 0, sustain = 0, animtype = 0},
		},
		jetl = {
			lightType = 'cone',
			pieceName = 'thrustl',
			lightConfig = { posx = 2, posy = 0, posz = -2, radius = 140,
				dirx = 0, diry = 0, dirz = -1, theta = 0.80000001,
				r = 1, g = 0.98000002, b = 0.85000002, a = 0.40000001,
				modelfactor = 0, specular = 1, scattering = 0.5, lensflare = 1,
				lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['armeyes'].id] = {
		eyeglow = {
			lightType = 'point',
			pieceName = 'base',
			lightConfig = { posx = 0, posy = 12, posz = 0, radius = 300,
				color2r = 0, color2g = 0, color2b = 0, colortime = 0,
				r = 0.8, g = 0.8, b = 0.8, a = 0.20,
				modelfactor = 0.1, specular = 0.1, scattering = 0.8, lensflare = 1,
				lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['coreyes'].id] = {
		eyeglow = {
			lightType = 'point',
			pieceName = 'base',
			lightConfig = { posx = 0, posy = 12, posz = 0, radius = 300,
				color2r = 0, color2g = 0, color2b = 0, colortime = 0,
				r = 0.8, g = 0.8, b = 0.8, a = 0.20,
				modelfactor = 0.1, specular = 0.1, scattering = 0.8, lensflare = 1,
				lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['armanni'].id] = {
		annilight = {
			lightType = 'cone',
			pieceName = 'light',
			lightConfig = { posx = 0, posy = 0, posz = 0, radius = 950,
				dirx = 0, diry = 0, dirz = 1, theta = 0.07,
				r = 1, g = 1, b = 1, a = 0.5,
				modelfactor = 0, specular = 1, scattering = 2, lensflare = 0,
				lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['armfus'].id] = {
		fusionglow1 = {
			lightType = 'point',
			pieceName = 'emit1',
			lightConfig = { posx = 0, posy = 19, posz = 0, radius = 40,
							color2r = 0, color2g = 0, color2b = 0, colortime = 0,
							r = -1, g = 1, b = 1, a = 1,
							modelfactor = 0.3, specular = 0.66, scattering = 0.4, lensflare = 5,
							lifetime = 0, sustain = 0, animtype = 0},
		},
		fusionglow2 = {
			lightType = 'point',
			pieceName = 'emit2',
			lightConfig = { posx = 0, posy = 19, posz = 0, radius = 40,
							color2r = 0, color2g = 0, color2b = 0, colortime = 0,
							r = -1, g = 1, b = 1, a = 1,
							modelfactor = 0.3, specular = 0.66, scattering = 0.4, lensflare = 5,
							lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['corfus'].id] = {
		fusionglow = {
			lightType = 'point',
			pieceName = 'emit',
			lightConfig = { posx = 0, posy = 0, posz = 0, radius = 70,
							color2r = 0, color2g = 0, color2b = 0, colortime = 0,
							r = -1, g = 1, b = 1, a = 0.55,
							modelfactor = 0.1, specular = 0.66, scattering = 1, lensflare = 5,
							lifetime = 0, sustain = 0, animtype = 0},
		},
		fusionorb = {
			lightType = 'point',
			pieceName = 'emit',
			lightConfig = { posx = 0, posy = 0, posz = 0, radius = 23,
							color2r = 0, color2g = 0, color2b = 0, colortime = 0,
							r = 1, g = 1, b = 1, a = 0.3,
							modelfactor = 0.1, specular = 0.66, scattering = 5, lensflare = 5,
							lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['corafus'].id] = {
		fusionglow = {
			lightType = 'point',
			pieceName = 'emit',
			lightConfig = { posx = 0, posy = 0, posz = 0, radius = 90,
							color2r = 0, color2g = 0, color2b = 0, colortime = 0,
							r = -1, g = 1, b = 1, a = 0.66,
							modelfactor = 0.1, specular = 0.66, scattering = 1, lensflare = 5,
							lifetime = 0, sustain = 0, animtype = 0},
		},
		fusionorb = {
			lightType = 'point',
			pieceName = 'emit',
			lightConfig = { posx = 0, posy = 0, posz = 0, radius = 32,
							color2r = 0, color2g = 0, color2b = 0, colortime = 0,
							r = 1, g = 1, b = 1, a = 0.4,
							modelfactor = 0.1, specular = 1, scattering = 5, lensflare = 10,
							lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['armafus'].id] = {
		fusionglow = {
			lightType = 'point',
			pieceName = 'emit',
			lightConfig = { posx = 0, posy = 0, posz = 0, radius = 90,
							color2r = 0, color2g = 0, color2b = 0, colortime = 0,
							r = -1, g = 1, b = 1, a = 0.66,
							modelfactor = 0.1, specular = 0.66, scattering = 1, lensflare = 5,
							lifetime = 0, sustain = 0, animtype = 0},
		},
		fusionorb = {
			lightType = 'point',
			pieceName = 'emit',
			lightConfig = { posx = 0, posy = 0, posz = 0, radius = 28,
							color2r = 0, color2g = 0, color2b = 0, colortime = 0,
							r = 1, g = 1, b = 1, a = 0.4,
							modelfactor = 0.1, specular = 1, scattering = 5, lensflare = 10,
							lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['resourcecheat'].id] = {
		fusionglow = {
			lightType = 'point',
			pieceName = 'emit',
			lightConfig = { posx = 0, posy = 0, posz = 0, radius = 220,
							color2r = 0, color2g = 0, color2b = 0, colortime = 0,
							r = -1, g = 1, b = 1, a = 0.9,
							modelfactor = 0.1, specular = 0.66, scattering = 1, lensflare = 5,
							lifetime = 0, sustain = 0, animtype = 0},
		},
		fusionorb = {
			lightType = 'point',
			pieceName = 'emit',
			lightConfig = { posx = 0, posy = 0, posz = 0, radius = 28,
							color2r = 0, color2g = 0, color2b = 0, colortime = 0,
							r = 1, g = 1, b = 1, a = 0.4,
							modelfactor = 0.1, specular = 1, scattering = 9, lensflare = 10,
							lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['armzeus'].id] = {
		weaponglow = {
			lightType = 'point',
			pieceName = 'gun_emit',
			lightConfig = { posx = 0, posy = 0, posz = 0, radius = 10,
				color2r = 0.40000001, color2g = 0.69999999, color2b = 1.20000005, colortime = 30,
				r = 0.2, g = 0.5, b = 1, a = 0.65000001,
				modelfactor = 0.1, specular = 0.75, scattering = 2, lensflare = 7,
				lifetime = 0, sustain = 0, animtype = 0},
		},
		weaponspark = {
			lightType = 'point',
			pieceName = 'spark_emit',
			lightConfig = { posx = 0, posy = 1, posz = 0, radius = 55,
				color2r = 0, color2g = 0, color2b = 0, colortime = 2,
				r = 1, g = 1, b = 1, a = 0.85000002,
				modelfactor = 0.1, specular = 0.75, scattering = 0.2, lensflare = 7,
				lifetime = 0, sustain = 0, animtype = 0},
		},
		backpackglow = {
			lightType = 'point',
			pieceName = 'static_emit',
			lightConfig = { posx = 0, posy = 0, posz = 0, radius = 10,
				color2r = 0.40000001, color2g = 0.69999999, color2b = 1.20000005, colortime = 30,
				r = 0.2, g = 0.5, b = 1, a = 0.65000001,
				modelfactor = 0.1, specular = 0.75, scattering = 2, lensflare = 10,
				lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['corpyro'].id] = {
		flamelight = {
			lightType = 'point',
			pieceName = 'lloarm',
			lightConfig = { posx = 0, posy = -1.4, posz = 15, radius = 30,
				color2r = 0.89999998, color2g = 0.5, color2b = 0.05, colortime = 5,
				r = 0.94999999, g = 0.66000003, b = 0.07, a = 0.18,
				modelfactor = 0.1, specular = 0.8, scattering = 0.35, lensflare = 0,
				lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['armthor'].id] = {
		weaponglowrt = {
			lightType = 'point',
			pieceName = 'rtbarrel',
			lightConfig = { posx = 0, posy = 0, posz = 12, radius = 14,
				color2r = 0.40000001, color2g = 0.69999999, color2b = 1.20000005, colortime = 30,
				r = 0.2, g = 0.5, b = 1, a = 1,
				modelfactor = 0.1, specular = 0.75, scattering = 1.5, lensflare = 7,
				lifetime = 0, sustain = 0, animtype = 0},
		},
		weaponglowlt = {
			lightType = 'point',
			pieceName = 'ltbarrel',
			lightConfig = { posx = 0, posy = 0, posz = 12, radius = 14,
				color2r = 0.40000001, color2g = 0.69999999, color2b = 1.20000005, colortime = 30,
				r = 0.2, g = 0.5, b = 1, a = 0.8,
				modelfactor = 0.1, specular = 0.75, scattering = 1.5, lensflare = 7,
				lifetime = 0, sustain = 0, animtype = 0},
		},
		weaponspark1 = {
			lightType = 'point',
			pieceName = 'spark_emit1',
			lightConfig = { posx = 0, posy = 6, posz = 0, radius = 100,
				color2r = 0.1, color2g = 0.1, color2b = 0.3, colortime = 2,
				r = 0.9, g = 0.9, b = 1, a = 0.75,
				modelfactor = 0.4, specular = 0.2, scattering = 0.1, lensflare = 10,
				lifetime = 0, sustain = 0, animtype = 0},
		},
		weaponspark2 = {
			lightType = 'point',
			pieceName = 'spark_emit2',
			lightConfig = { posx = 0, posy = 6, posz = 0, radius = 100,
				color2r = 0.1, color2g = 0.1, color2b = 0.3, colortime = 2,
				r = 0.9, g = 0.9, b = 1, a = 0.75,
				modelfactor = 0.4, specular = 0.2, scattering = 0.1, lensflare = 10,
				lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['armthundt4'].id] = {
		tipleft = {
			lightType = 'point',
			pieceName = 'blinka',
			lightConfig = { posx = 0, posy = 0, posz = 0, radius = 20,
				color2r = 0, color2g = 0, color2b = 0, colortime = 5,
				r = -1, g = 1, b = 1, a = 1,
				modelfactor = 0.2, specular = 0.5, scattering = 1.2, lensflare = 10,
				lifetime = 0, sustain = 0, animtype = 1},
		},
		tipright = {
			lightType = 'point',
			pieceName = 'blinkb',
			lightConfig = { posx = 0, posy = 0, posz = 0, radius = 20,
				color2r = 0, color2g = 0, color2b = 0, colortime = 5,
				r = -1, g = 1, b = 1, a = 1,
				modelfactor = 0.2, specular = 0.5, scattering = 1.2, lensflare = 10,
				lifetime = 0, sustain = 0, animtype = 1},
		},
	},
	[UnitDefNames['armsnipe'].id] = {
		sniperreddot = {
			lightType = 'cone',
			pieceName = 'laser',
			lightConfig = { posx = 0, posy = 0, posz = 0, radius = 700,
				dirx = 0, diry = 1, dirz = 0.0001, theta = 0.006,
				r = 2, g = 0, b = 0, a = 0.85000002,
				modelfactor = 0.1, specular = 4, scattering = 2, lensflare = 4,
				lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['armwin'].id] = {
		light = {
			lightType = 'point',
			pieceName = 'emit',
			lightConfig = { posx = 0, posy = 0, posz = 0, radius = 17,
							color2r = 1, color2g = 1, color2b = 0, colortime = 0,
							r = 1, g = 1, b = 0.2, a = 0.55,
							modelfactor = 0.3, specular = 0.5, scattering = 0.4, lensflare = 0,
							lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['corestor'].id] = {
		light = {
			lightType = 'point',
			pieceName = 'emit',
			lightConfig = { posx = 0, posy = -12, posz = 0, radius = 48,
							color2r = 1, color2g = 0.7, color2b = 0.15, colortime = 75,
							r = 1, g = 0.86, b = 0.25, a = 0.5,
							modelfactor = 0.11, specular = 0.7, scattering = 0.7, lensflare = 0,
							lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['coruwes'].id] = {
		light = {
			lightType = 'point',
			pieceName = 'emit',
			lightConfig = { posx = 0, posy = 0, posz = 0, radius = 47,
							color2r = 1, color2g = 0.7, color2b = 0.15, colortime = 75,
							r = 1, g = 0.86, b = 0.25, a = 0.5,
							modelfactor = 0.1, specular = 0.5, scattering = 0.7, lensflare = 0,
							lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['coruwadves'].id] = {
		light = {
			lightType = 'point',
			pieceName = 'emit',
			lightConfig = { posx = 0, posy = 0, posz = 0, radius = 64,
							color2r = 1, color2g = 0.7, color2b = 0.15, colortime = 75,
							r = 1, g = 0.86, b = 0.25, a = 0.5,
							modelfactor = 0.1, specular = 0.5, scattering = 0.7, lensflare = 0,
							lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['armestor'].id] = {
		light = {
			lightType = 'point',
			pieceName = 'emit',
			lightConfig = { posx = 0, posy = 0, posz = 0, radius = 44,
							color2r = 1, color2g = 0.7, color2b = 0.15, colortime = 75,
							r = 1, g = 0.86, b = 0.25, a = 0.5,
							modelfactor = 0.1, specular = 0.5, scattering = 0.7, lensflare = 0,
							lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['armuwes'].id] = {
		light = {
			lightType = 'point',
			pieceName = 'emit',
			lightConfig = { posx = 0, posy = 0, posz = 0, radius = 47,
							color2r = 1, color2g = 0.7, color2b = 0.15, colortime = 75,
							r = 1, g = 0.86, b = 0.25, a = 0.5,
							modelfactor = 0.1, specular = 0.5, scattering = 0.7, lensflare = 0,
							lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['armuwadves'].id] = {
		light1 = {
			lightType = 'point',
			pieceName = 'emit1',
			lightConfig = { posx = 0, posy = 0, posz = 0, radius = 52,
							color2r = 1, color2g = 0.7, color2b = 0.15, colortime = 75,
							r = 1, g = 0.86, b = 0.25, a = 0.5,
							modelfactor = 0.1, specular = 0.5, scattering = 0.7, lensflare = 0,
							lifetime = 0, sustain = 0, animtype = 0},
		},
		light2 = {
			lightType = 'point',
			pieceName = 'emit2',
			lightConfig = { posx = 0, posy = 0, posz = 0, radius = 52,
							color2r = 1, color2g = 0.7, color2b = 0.15, colortime = 75,
							r = 1, g = 0.86, b = 0.25, a = 0.5,
							modelfactor = 0.1, specular = 0.5, scattering = 0.3, lensflare = 0,
							lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['armgmm'].id] = {
		light = {
			lightType = 'point',
			pieceName = 'base',
			lightConfig = { posx = 0, posy = 30, posz = 0, radius = 55,
							color2r = 1, color2g = 0.7, color2b = 0.15, colortime = 75,
							r = 1, g = 0.86, b = 0.25, a = 0.5,
							modelfactor = 0.1, specular = 0.5, scattering = 0.7, lensflare = 0,
							lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['armageo'].id] = {
		light = {
			lightType = 'point',
			pieceName = 'base',
			lightConfig = { posx = 0, posy = 30, posz = 0, radius = 78,
							color2r = 1, color2g = 0.7, color2b = 0.15, colortime = 75,
							r = 0.6, g = 0.42, b = 0.05, a = 0.5,
							modelfactor = 0.1, specular = 0.5, scattering = 0.7, lensflare = 0,
							lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['armsolar'].id] = {
		light = {
			lightType = 'point',
			pieceName = 'emit',
			lightConfig = { posx = 0, posy = 2, posz = 0, radius = 33,
							color2r = 1, color2g = 1, color2b = 0, colortime = 0,
							r = 1, g = 1, b = 0.3, a = 0.6,
							modelfactor = 0.3, specular = 0.5, scattering = 0.35, lensflare = 0,
							lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['coradvsol'].id] = {
		light = {
			lightType = 'point',
			pieceName = 'emit',
			lightConfig = { posx = 0, posy = 5, posz = 0, radius = 36,
							color2r = 0, color2g = 0, color2b = 0, colortime = 0,
							r = 1, g = 1, b = 0.7, a = 0.1,
							modelfactor = 0.2, specular = 0.35, scattering = 1.8, lensflare = 0,
							lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['cormakr'].id] = {
		flamelight = {
			lightType = 'point',
			pieceName = 'light',
			lightConfig = { posx = 0, posy = 18, posz = 0, radius = 45,
							color2r = 0.8, color2g = 0.6, color2b = 0.10, colortime = 75,
							r = 1, g = 0.75, b = 0.25, a = 0.17,
							modelfactor = 0.25, specular = 1.5, scattering = 0.5, lensflare = 0,
							lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['corfmkr'].id] = {
		flamelight = {
			lightType = 'point',
			pieceName = 'light',
			lightConfig = { posx = 0, posy = 18, posz = 0, radius = 50,
							color2r = 0, color2g = 0, color2b = 0, colortime = 0,
							r = 0.89999998, g = 0.69999999, b = 0.44999999, a = 0.17,
							modelfactor = 0.25, specular = 1.5, scattering = 0.5, lensflare = 0,
							lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['armmakr'].id] = {
		flamelight = {
			lightType = 'point',
			pieceName = 'light',
			lightConfig = { posx = 0, posy = 16, posz = 0, radius = 50,
							color2r = 0, color2g = 0, color2b = 0, colortime = 0,
							r = 0.89999998, g = 0.69999999, b = 0.44999999, a = 0.15,
							modelfactor = 0.25, specular = 1.5, scattering = 0.5, lensflare = 0,
							lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['armfmkr'].id] = {
		flamelight = {
			lightType = 'point',
			pieceName = 'light',
			lightConfig = { posx = 0, posy = 16, posz = 0, radius = 50,
							color2r = 0, color2g = 0, color2b = 0, colortime = 0,
							r = 0.89999998, g = 0.69999999, b = 0.44999999, a = 0.15,
							modelfactor = 0.25, specular = 1.5, scattering = 0.5, lensflare = 0,
							lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['cormmkr'].id] = {
		flamelight = {
			lightType = 'point',
			pieceName = 'light',
			lightConfig = { posx = 0, posy = 15, posz = 0, radius = 70,
			color2r = 0, color2g = 0, color2b = 0, colortime = 0,
			r = 0.89999998, g = 0.69999999, b = 0.44999999, a = 0.16,
			modelfactor = 0.25, specular = 1.5, scattering = 0.5, lensflare = 0,
			lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['armmmkr'].id] = {
		flamelight = {
			lightType = 'point',
			pieceName = 'light',
			lightConfig = { posx = 0, posy = 10, posz = 0, radius = 70,
			color2r = 0, color2g = 0, color2b = 0, colortime = 0,
			r = 0.89999998, g = 0.69999999, b = 0.44999999, a = 0.16,
			modelfactor = 0.25, specular = 1.5, scattering = 0.5, lensflare = 0,
			lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['lootboxbronze'].id] = {
		blinka = {
			lightType = 'point',
			pieceName = 'blinka',
			lightConfig = { posx = 0, posy = 1, posz = 0, radius = 25,
				color2r = 0, color2g = 0, color2b = 0, colortime = 0,
				r = -1, g = 1, b = 1, a = 0.85000002,
				modelfactor = 1, specular = 1, scattering = 1, lensflare = 10,
				lifetime = 0, sustain = 0, animtype = 1},
		},
		blinkb = {
			lightType = 'point',
			pieceName = 'blinkb',
			lightConfig = { posx = 0, posy = 1, posz = 0, radius = 25,
				color2r = 0, color2g = 0, color2b = 0, colortime = 0,
				r = -1, g = 1, b = 1, a = 0.85000002,
				modelfactor = 1, specular = 1, scattering = 1, lensflare = 10,
				lifetime = 0, sustain = 0, animtype = 0},
		},
		blinkc = {
			lightType = 'point',
			pieceName = 'blinkc',
			lightConfig = { posx = 0, posy = 1, posz = 0, radius = 25,
				color2r = 0, color2g = 0, color2b = 0, colortime = 0,
				r = -1, g = 1, b = 1, a = 0.85000002,
				modelfactor = 1, specular = 1, scattering = 1, lensflare = 10,
				lifetime = 0, sustain = 0, animtype = 0},
		},
		blinkd = {
			lightType = 'point',
			pieceName = 'blinkd',
			lightConfig = { posx = 0, posy = 1, posz = 0, radius = 25,
				color2r = 0, color2g = 0, color2b = 0, colortime = 0,
				r = -1, g = 1, b = 1, a = 0.85000002,
				modelfactor = 1, specular = 1, scattering = 1, lensflare = 10,
				lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['armaap'].id] = {
		blinka = {
			lightType = 'point',
			pieceName = 'blinka',
			lightConfig = { posx = -1, posy = 1, posz = 0, radius = 20,
				color2r = 0, color2g = 0, color2b = 0, colortime = 20,
				r = -1, g = 1, b = 1, a = 1,
				modelfactor = 0.2, specular = 0.5, scattering = 2, lensflare = 7,
				lifetime = 0, sustain = 0, animtype = 0},
		},
		-- dishlight = {
		-- 	lightType = 'point',
		-- 	pieceName = 'dish',
		-- 	lightConfig = { posx = 0, posy = 5, posz = 0, radius = 10,
		-- 		color2r = 0, color2g = 0, color2b = 0, colortime = 30,
		-- 		r = 0, g = 1, b = 0, a = 0.6,
		-- 		modelfactor = 0.01, specular = 0.5, scattering = 0.5, lensflare = 10,
		-- 		lifetime = 0, sustain = 0, animtype = 0},
		-- },
		blinkb = {
			lightType = 'point',
			pieceName = 'blinkb',
			lightConfig = { posx = -1, posy = 1, posz = 0, radius = 20,
				color2r = 0, color2g = 0, color2b = 0, colortime = 20,
				r = -1, g = 1, b = 1, a = 1,
				modelfactor = 0.2, specular = 0.5, scattering = 2, lensflare = 7,
				lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['armshltx'].id] = {
		blink1a = {
			lightType = 'point',
			pieceName = 'blink1a',
			lightConfig = { posx = -1, posy = 1, posz = 0, radius = 18,
				color2r = 0, color2g = 0, color2b = 0, colortime = 60,
				r = -1, g = 1, b = 1, a = 0.8,
				modelfactor = 0.2, specular = 0.5, scattering = 2, lensflare = 10,
				lifetime = 0, sustain = 0, animtype = 0},
		},
		blink1b = {
			lightType = 'point',
			pieceName = 'blink1b',
			lightConfig = { posx = -1, posy = 1, posz = 0, radius = 18,
				color2r = 0, color2g = 0, color2b = 0, colortime = 60,
				r = -1, g = 1, b = 1, a = 0.8,
				modelfactor = 0.2, specular = 0.5, scattering = 2, lensflare = 10,
				lifetime = 0, sustain = 0, animtype = 0},
		},
		blink1c = {
			lightType = 'point',
			pieceName = 'blink1c',
			lightConfig = { posx = -1, posy = 1, posz = 0, radius = 18,
				color2r = 0, color2g = 0, color2b = 0, colortime = 60,
				r = -1, g = 1, b = 1, a = 0.8,
				modelfactor = 0.2, specular = 0.5, scattering = 2, lensflare = 10,
				lifetime = 0, sustain = 0, animtype = 0},
		},
		blink2a = {
			lightType = 'point',
			pieceName = 'blink2a',
			lightConfig = { posx = -1, posy = 1, posz = 0, radius = 18,
				color2r = 0, color2g = 0, color2b = 0, colortime = 60,
				r = -1, g = 1, b = 1, a = 0.8,
				modelfactor = 0.2, specular = 0.5, scattering = 2, lensflare = 10,
				lifetime = 0, sustain = 0, animtype = 0},
		},
		blink2b = {
			lightType = 'point',
			pieceName = 'blink2b',
			lightConfig = { posx = -1, posy = 1, posz = 0, radius = 18,
				color2r = 0, color2g = 0, color2b = 0, colortime = 60,
				r = -1, g = 1, b = 1, a = 0.8,
				modelfactor = 0.2, specular = 0.5, scattering = 2, lensflare = 10,
				lifetime = 0, sustain = 0, animtype = 0},
		},
		blink2c = {
			lightType = 'point',
			pieceName = 'blink2c',
			lightConfig = { posx = -1, posy = 1, posz = 0, radius = 18,
				color2r = 0, color2g = 0, color2b = 0, colortime = 60,
				r = -1, g = 1, b = 1, a = 0.8,
				modelfactor = 0.2, specular = 0.5, scattering = 2, lensflare = 10,
				lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['corsilo'].id] = {
		launchlight1 = { -- this is the lightname
			lightType = 'cone',
			pieceName = 'cagelight_emit1',
			lightConfig = { posx = 0, posy = 0, posz = 0, radius = 30,
				dirx = 1, diry = 0, dirz = 0, theta = 0.99000001,
				r = 1.29999995, g = 0.1, b = 0, a = 2,
				modelfactor = 0.1, specular = 0.2, scattering = 1, lensflare = 2,
				lifetime = 0, sustain = 0, animtype = 0},
		},
		launchlight2 = { -- this is the lightname
			lightType = 'cone',
			pieceName = 'cagelight_emit2',
			lightConfig = { posx = 0, posy = 0, posz = 0, radius = 30,
				dirx = 1, diry = 0, dirz = 0, theta = 0.99000001,
				r = 1.29999995, g = 0.1, b = 0, a = 2,
				modelfactor = 0.1, specular = 0.2, scattering = 1, lensflare = 2,
				lifetime = 0, sustain = 0, animtype = 0},
		},
		launchlight3 = { -- this is the lightname
			lightType = 'cone',
			pieceName = 'cagelight_emit3',
			lightConfig = { posx = 0, posy = 0, posz = 0, radius = 30,
				dirx = 1, diry = 0, dirz = 0, theta = 0.99000001,
				r = 1.29999995, g = 0.1, b = 0, a = 2,
				modelfactor = 0.1, specular = 0.2, scattering = 1, lensflare = 2,
				lifetime = 0, sustain = 0, animtype = 0},
		},
		launchlight4 = { -- this is the lightname
			lightType = 'cone',
			pieceName = 'cagelight_emit4',
			lightConfig = { posx = 0, posy = 0, posz = 0, radius = 30,
				dirx = 1, diry = 0, dirz = 0, theta = 0.99000001,
				r = 1.29999995, g = 0.1, b = 0, a = 2,
				modelfactor = 0.1, specular = 0.2, scattering = 1, lensflare = 2,
				lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	-- [UnitDefNames['corint'].id] = {
	-- 	hotbarrel1 = {
	-- 		lightType = 'point',
	-- 		pieceName = 'light',
	-- 		lightConfig = { posx = -7, posy = 8, posz = 5, radius = 30,
	-- 			color2r = 0, color2g = 0, color2b = 0, colortime = 300,
	-- 			r = 1, g = 0.2, b = 0, a = 0.69999999,
	-- 			modelfactor = 2, specular = 1, scattering = 0, lensflare = 0,
	-- 			lifetime = 300, sustain = 1, animtype = 0},
	-- 	},
	-- 	hotbarrel2 = {
	-- 		lightType = 'point',
	-- 		pieceName = 'light',
	-- 		lightConfig = { posx = 7, posy = 8, posz = 5, radius = 30,
	-- 			color2r = 0, color2g = 0, color2b = 0, colortime = 300,
	-- 			r = 1, g = 0.2, b = 0, a = 0.69999999,
	-- 			modelfactor = 2, specular = 1, scattering = 0, lensflare = 0,
	-- 			lifetime = 300, sustain = 1, animtype = 0},
	-- 	},
	-- },
	[UnitDefNames['corlab'].id] = {
		buildlight = { -- this is the lightname
			lightType = 'cone',
			pieceName = 'cagelight_emit',
			lightConfig = { posx = 0, posy = 0, posz = 0, radius = 17,
				dirx = 1, diry = 0, dirz = 0, theta = 0.99000001,
				r = 1.29999995, g = 0.89999998, b = 0.1, a = 2,
				modelfactor = 0.1, specular = 0.2, scattering = 1.5, lensflare = 10,
				lifetime = 0, sustain = 0, animtype = 0},
		},
		buildlight2 = { -- this is the lightname
			lightType = 'cone',
			pieceName = 'cagelight_emit',
			lightConfig = { posx = 0, posy = 0, posz = 0, radius = 17,
				dirx = -1, diry = 0, dirz = 0, theta = 0.99000001,
				r = 1.29999995, g = 0.89999998, b = 0.1, a = 2,
				modelfactor = 0.1, specular = 0.2, scattering = 1.5, lensflare = 10,
				lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['corck'].id] = {
		buildlight = { -- this is the lightname
			lightType = 'cone',
			pieceName = 'cagelight_emit',
			lightConfig = { posx = 0, posy = 0, posz = 0, radius = 17,
				dirx = 1, diry = 0, dirz = 0, theta = 0.99000001,
				r = 1.29999995, g = 0.89999998, b = 0.1, a = 2,
				modelfactor = 0.1, specular = 0.2, scattering = 2, lensflare = 10,
				lifetime = 0, sustain = 0, animtype = 0},
		},
		buildlight2 = { -- this is the lightname
			lightType = 'cone',
			pieceName = 'cagelight_emit',
			lightConfig = { posx = 0, posy = 0, posz = 0, radius = 17,
				dirx = -1, diry = 0, dirz = 0, theta = 0.99000001,
				r = 1.29999995, g = 0.89999998, b = 0.1, a = 2,
				modelfactor = 0.1, specular = 0.2, scattering = 2, lensflare = 10,
				lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['armgate'].id] = {
		shieldglow = {
			lightType = 'point',
			pieceName = 'base',
			lightConfig = { posx = 0, posy = 32, posz = 0, radius = 130,
				color2r = 0, color2g = 0, color2b = 0, colortime = 70,
				r = 0.2, g = 0.9, b = 0.3, a = 0.2,
				modelfactor = 0.1, specular = 1.0, scattering = 0.35, lensflare = 0,
				lifetime = 0, sustain = 0, animtype = 0},
		},
	},
	[UnitDefNames['corgate'].id] = {
		shieldglow = {
			lightType = 'point',
			pieceName = 'base',
			lightConfig = { posx = 0, posy = 40, posz = 0, radius = 130,
				color2r = 0, color2g = 0, color2b = 0, colortime = 70,
				r = 0.2, g = 0.9, b = 0.3, a = 0.2,
				modelfactor = 0.1, specular = 1.0, scattering = 0.35, lensflare = 0,
				lifetime = 0, sustain = 0, animtype = 0},
		},
	},
}
unitDefLights[UnitDefNames['armshltxuw'].id] = unitDefLights[UnitDefNames['armshltx'].id]

local unitEventLights = {
	------------------------------------ Put lights that are slaved to ProjectileCreated here! ---------------------------------
	-- WeaponBarrelGlow =  {
	-- 	[UnitDefNames['corint'].id] = {
	-- 		barrelglow1 = {
	-- 			lightType = 'point',
	-- 			pieceName = 'light',
	-- 			lightConfig = { posx = -7, posy = 8, posz = 5, radius = 30,
	-- 				color2r = 0, color2g = 0, color2b = 0, colortime = 300,
	-- 				r = 1, g = 1, b = 1, a = 0.69999999,
	-- 				modelfactor = 2, specular = 1, scattering = 0, lensflare = 0,
	-- 				lifetime = 300, sustain = 1, animtype = 0},
	-- 		},
	-- 	},
	-- 	[UnitDefNames['corint'].id] = {
	-- 		barrelglow2 = {
	-- 			lightType = 'point',
	-- 			pieceName = 'light',
	-- 			lightConfig = { posx = 7, posy = 8, posz = 5, radius = 30,
	-- 				color2r = 0, color2g = 0, color2b = 0, colortime = 300,
	-- 				r = 1, g = 1, b = 1, a = 0.69999999,
	-- 				modelfactor = 2, specular = 1, scattering = 0, lensflare = 0,
	-- 				lifetime = 300, sustain = 1, animtype = 0},
	-- 		},
	-- 	},
	-- },
	--------------------------------- Put lights that are spawned from COB/LUS here ! ---------------------------------
	-- These lights _must_ be indexed by numbers! As these will be the ones triggered by the
	-- The COB lua_UnitScriptLight(lightIndex, count) call does this job!

	--corint disabled for now since it has static positioning - now only 'working' when shooting to east:

	UnitScriptLights = {
	-- 	[UnitDefNames['corint'].id] = {
	-- 		[1] = { --lightIndex as above, MUST BE AN INTEGER, Give it a nice name in a comment,
	-- 			lightType = 'point',
	-- 			pieceName = 'light', --seems it spawns not from this piece, but from center of model/unit.
	-- 			lightName = 'corintbarrelglow',
	-- 			lightConfig = { posx = 64, posy = 88, posz = -24, radius = 30,
	-- 				color2r = 0.5, color2g = 0.1, color2b = 0, colortime = 300,
	-- 				r = 1, g = 0.2, b = 0, a = 0.6,
	-- 				modelfactor = 2, specular = 1, scattering = 0, lensflare = 0,
	-- 				lifetime = 400, sustain = 2},
	-- 		},
	-- 		[2] = { --lightIndex as above, MUST BE AN INTEGER, Give it a nice name in a comment,
	-- 			lightType = 'point',
	-- 			pieceName = 'light', --seems it spawns not from this piece, but from center of model/unit.
	-- 			lightName = 'corintbarrelglow',
	-- 			lightConfig = { posx = 72, posy = 88, posz = 0, radius = 30,
	-- 				color2r = 0.5, color2g = 0.1, color2b = 0, colortime = 300,
	-- 				r = 1, g = 0.2, b = 0, a = 0.6,
	-- 				modelfactor = 2, specular = 1, scattering = 0, lensflare = 0,
	-- 				lifetime = 400, sustain = 2},
	-- 		},
	-- 	},
	},

	------------------------------- Put additional lights tied to events here! --------------------------------
	UnitIdle =  {
		[UnitDefNames['armcom'].id] = {
			idleBlink = {
				lightType = 'point',
				pieceName = 'head',
				lightConfig = { posx = 0, posy = 20, posz = 0, radius = 110,
					color2r = 0, color2g = 0, color2b = 0, colortime = 6,
					r = -1, g = 1, b = 1, a = 0.25,
					modelfactor = 0.2, specular = 0.6, scattering = 0.7, lensflare = 1,
					lifetime = 12, sustain = 0, animtype = 0},
			},
		},
		--[[
		[UnitDefNames['armstump'].id] = { -- BLINK BLINK
			idleBlink = {
				lightType = 'point',
				pieceName = 'justatthebase',
				lightConfig = { posx = 0, posy = 30, posz = 0, radius = 80,
					color2r = 0, color2g = 0, color2b = 0, colortime = 6,
					r = -1, g = 1, b = 1, a = 0.25,
					modelfactor = 0.2, specular = 0.7, scattering = 0.7, lensflare = 1,
					lifetime = 12, sustain = 0, animtype = 0},
			},
		}
		]]--
	},

	UnitFinished = {
		default = {
			default = {
				lightType = 'cone',
				pieceName = 'base',
				aboveUnit = 100,
				lightConfig = { posx = 0, posy = 32, posz = 0, radius = 160,
					dirx = 0, diry = -0.99, dirz = 0.02, theta = 0.4,
					r = -1, g = 1, b = 1, a = 0.18,
					modelfactor = 0.2, specular = 1, scattering = 0.7, lensflare = 0,
					lifetime = 20, sustain = 2, animtype = 0},
			},
		},
	},

	UnitCreated = {
		default = {
			default = {
				lightType = 'cone',
				pieceName = 'base',
				aboveUnit = 100,
				lightConfig = { posx = 0, posy = 32, posz = 0, radius = 200,
					dirx = 0, diry = -0.99, dirz = 0.02, theta = 0.4,
					r = -1, g = 1, b = 1, a = 0.16,
					modelfactor = 0.2, specular = 1, scattering = 0.7, lensflare = 0,
					lifetime = 15, sustain = 2, animtype = 0},
			},
		},
	},

	UnitCloaked = {
		default = {
			default = {
				lightType = 'cone',
				pieceName = 'base',
				aboveUnit = 100,
				lightConfig = { posx = 0, posy = 32, posz = 0, radius = 200,
					dirx = 0, diry = -0.99, dirz = 0.02, theta = 0.4,
					r = -1, g = 1, b = 1, a = 0.16,
					modelfactor = 0.2, specular = 1, scattering = 0.7, lensflare = 0,
					lifetime = 15, sustain = 2, animtype = 0},
			},
		},
	},

	UnitDecloaked = {
		default = {
			default = {
				lightType = 'cone',
				pieceName = 'base',
				aboveUnit = 100,
				lightConfig = { posx = 0, posy = 32, posz = 0, radius = 200,
					dirx = 0, diry = -0.99, dirz = 0.02, theta = 0.4,
					r = -1, g = 1, b = 1, a = 0.16,
					modelfactor = 0.2, specular = 1, scattering = 0.7, lensflare = 0,
					lifetime = 15, sustain = 2, animtype = 0},
			},
		},
	},

	StockpileChanged = {
		default = {
			default = {
				lightType = 'cone',
				pieceName = 'base',
				aboveUnit = 100,
				lightConfig = { posx = 0, posy = 32, posz = 0, radius = 200,
					dirx = 0, diry = -0.99, dirz = 0.02, theta = 0.4,
					r = 1, g = 0, b = 0, a = 0.5,
					modelfactor = 0.2, specular = 1, scattering = 0.7, lensflare = 0,
					lifetime = 15, sustain = 2, animtype = 0},
			},
		},
	},
	UnitMoveFailed = {
		default = {
			default = {
				lightType = 'cone',
				pieceName = 'base',
				aboveUnit = 100,
				lightConfig = { posx = 0, posy = 32, posz = 0, radius = 200,
					dirx = 0, diry = -0.99, dirz = 0.02, theta = 0.4,
					r = 1, g = 0, b = 0, a = 0.16,
					modelfactor = 0.2, specular = 1, scattering = 0.7, lensflare = 0,
					lifetime = 15, sustain = 2, animtype = 0},
			},
		},
	},

	UnitGiven = {
		default = {
			default = {
				lightType = 'cone',
				pieceName = 'base',
				aboveUnit = 100,
				lightConfig = { posx = 0, posy = 32, posz = 0, radius = 200,
					dirx = 0, diry = -0.99, dirz = 0.02, theta = 0.4,
					r = -1, g = 1, b = 1, a = 0.5,
					modelfactor = 0.2, specular = 1, scattering = 0.7, lensflare = 0,
					lifetime = 15, sustain = 2, animtype = 0},
			},
		},
	},
	UnitTaken = {
		default = {
			default = {
				lightType = 'cone',
				pieceName = 'base',
				aboveUnit = 100,
				lightConfig = { posx = 0, posy = 32, posz = 0, radius = 200,
					dirx = 0, diry = -0.99, dirz = 0.02, theta = 0.4,
					r = -1, g = 1, b = 1, a = 0.5,
					modelfactor = 0.2, specular = 1, scattering = 0.7, lensflare = 0,
					lifetime = 15, sustain = 2, animtype = 0},
			},
		},
	},
	UnitDestroyed = { -- note: dont do piece-attached lights here!
		default = {
			default = {
				lightType = 'cone',
				pieceName = '',
				aboveUnit = 100,
				lightConfig = { posx = 0, posy = 32, posz = 0, radius = 200,
					dirx = 0, diry = -0.99, dirz = 0.02, theta = 0.4,
					r = 1, g = 0, b = 0, a = 0.26,
					modelfactor = 0.2, specular = 1, scattering = 0.7, lensflare = 0,
					lifetime = 15, sustain = 2, animtype = 0},
			},
		},
	},
}

local headlights = Spring.GetConfigInt("headlights", 1) == 1
if not headlights then
	for unitDefID, lights in pairs(unitDefLights) do
		for name, params in pairs(lights) do
			if string.find(name, "headlight") then
				unitDefLights[unitDefID][name] = nil
			end
		end
	end
end

local allLights = {unitEventLights = unitEventLights, unitDefLights = unitDefLights, }

----------------- Debugging code to do the reverse dump ---------------
--[[
local lightParamKeyOrder = {	posx = 1, posy = 2, posz = 3, radius = 4,
	r = 9, g = 10, b = 11, a = 12,
	color2r = 5, color2g = 6, color2b = 7, colortime = 8, -- point lights only, colortime in seconds for unit-attached
	dirx = 5, diry = 6, dirz = 7, theta = 8,  -- cone lights only, specify direction and half-angle in radians
	pos2x = 5, pos2y = 6, pos2z = 7, -- beam lights only, specifies the endpoint of the beam
	modelfactor = 13, specular = 14, scattering = 15, lensflare = 16,
	lifetime = 18, sustain = 19, animtype = 20 -- unused
}

for typename, typetable in pairs(allLights) do
	Spring.Echo(typename)
	for lightunitclass, classinfo in pairs(typetable) do
		if type(lightunitclass) == type(1) then
			Spring.Echo(UnitDefs[lightunitclass].name)
		else
			Spring.Echo(lightunitclass)
		end
		for lightname, lightinfo in pairs(classinfo) do
			Spring.Echo(lightname)
			local lightParamTable = lightinfo.lightParamTable
			Spring.Echo(string.format("			lightConfig = { posx = %f, posy = %f, posz = %f, radius = %f,", lightinfo.lightParamTable[1], lightParamTable[2],lightParamTable[3],lightParamTable[4] ))
			if lightinfo.lightType == 'point' then
				Spring.Echo(string.format("				color2r = %f, color2g = %f, color2b = %f, colortime = %f,", lightinfo.lightParamTable[5], lightParamTable[6],lightParamTable[7],lightParamTable[8] ))

			elseif lightinfo.lightType == 'beam' then
				Spring.Echo(string.format("				pos2x = %f, pos2y = %f, pos2z = %f,", lightinfo.lightParamTable[5], lightParamTable[6],lightParamTable[7]))
			elseif lightinfo.lightType == 'cone' then
				Spring.Echo(string.format("				dirx = %f, diry = %f, dirz = %f, theta = %f,", lightinfo.lightParamTable[5], lightParamTable[6],lightParamTable[7],lightParamTable[8] ))

			end
			Spring.Echo(string.format("				r = %f, g = %f, b = %f, a = %f,", lightinfo.lightParamTable[9], lightParamTable[10],lightParamTable[11],lightParamTable[12] ))
			Spring.Echo(string.format("				modelfactor = %f, specular = %f, scattering = %f, lensflare = %f,", lightinfo.lightParamTable[13], lightParamTable[14],lightParamTable[15],lightParamTable[16] ))
			Spring.Echo(string.format("				lifetime = %f, sustain = %f, animtype = %f},", lightinfo.lightParamTable[18], lightParamTable[19],lightParamTable[20]))

		end
	end
end
]]--

-- Icexuick Check-list

-- 1.	seems that unitEventLights do not attach to proper piecename (see corint) they spawn on unit-center instead of the piece

return allLights


