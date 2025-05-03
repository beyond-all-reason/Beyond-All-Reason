-- This configures all the distortions weapon effects, including:
	-- Projectile attached distortions
	-- Muzzle flashes
	-- Explosion distortions
	-- Pieceprojectiles (gibs on death) distortions
-- note that weapondef customparams need to be moved out of unitdefs, for ease of configability.
	-- customparams= {
		-- expl_distortion_skip = bool , -- no explosion on projectile death
		-- expl_distortion_color = {rgba} , -- color of the explosion distortion at peak?
		-- expl_distortion_opacity = a, -- alpha or power of the distortion
		-- expl_distortion_mult = ,-- fuck if i know?
		-- expl_distortion_radius = , -- radius
		-- expl_distortion_radius_mult = , -- why?
		-- expl_distortion_life = , life of the expl distortion?
-- concept is:
	-- Make a few base classes of distortions
	-- auto-assign the majority
	-- offer overrideability
-- note that Y offset will be very different for points and for beams!
-- (c) Beherith (mysterme@gmail.com)

local exampleDistortion = {
	distortionType = 'point', -- or cone or beam
	pieceName = nil, -- optional
	yOffset = 10, -- optional, gives extra Y height
	fraction = 3, -- optional, only every nth projectile gets the effect (randomly)
	distortionConfig = {
		posx = 0, posy = 0, posz = 0, radius = 0,
		r = 1, g = 1, b = 1, a = 1,
		color2r = 1, color2g = 1, color2b = 1, colortime = 15, -- point distortions only, colortime in seconds for unit-attached
		dirx = 0, diry = 0, dirz = 1, theta = 0.5,  -- cone distortions only, specify direction and half-angle in radians
		pos2x = 100, pos2y = 100, pos2z = 100, -- beam distortions only, specifies the endpoint of the beam
		modelfactor = 1, specular = 1, scattering = 1, lensflare = 1,
		lifeTime = 0, sustain = 1, 	effectType = 0,
	},
}


local exampleDistortionBeamShockwave = {
	distortionType = 'point', -- or cone or beam
	pieceName = nil, -- optional
	distortionConfig = {
			posx = 0, posy = 10, posz = 0, radius = 150,
			r = 1, g = 1, b = 1, a = 0.075,
			pos2x = 100, pos2y = 1000, pos2z = 100, -- beam distortions only, specifies the endpoint of the beam
			modelfactor = 1, specular = 0.5, scattering = 0.1, lensflare = 1,
			lifeTime = 10, sustain = 1, 	effectType = 'groundShockwave',
	},
}


-- Local Variables

--------------------------------------------------------------------------------
-- Config

-- Config order is:
-- Auto-assign a distortionclass to each weaponDefID
-- Override on a per-weaponDefID basis, and copy table before overriding

--------------------------------General Base Distortion Classes for further useage --------
local BaseClasses = {
	NoEffect = {
		distortionType = 'point', -- or cone or beam
		distortionConfig = {
			posx = 0, posy = 0, posz = 0, radius = 0,
			lifeTime = 0, sustain = 0, 	effectType = 0,
		},
	},
	
	LaserProjectile = {
		distortionType = 'beam', -- or cone or beam
		distortionConfig = {
			posx = 0, posy = 10, posz = 0, radius = 100,
			pos2x = 100, pos2y = 1000, pos2z = 100, -- beam distortions only, specifies the endpoint of the beam
			lifeTime = 0, sustain = 1, 	effectType = 0,
		},
	},

	CannonProjectile = {
		distortionType = 'point', -- or cone or beam
		distortionConfig = {
			posx = 0, posy = 10, posz = 0, radius = 125,
			lifeTime = 0, sustain = 0, 	effectType = 0,
		},
	},

	PlasmaTrailProjectile = {
		distortionType = 'cone',
		distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 100,
						dirx =  0, diry = 1, dirz = 1.0, theta = 0.09,
						noiseStrength = 6, noiseScaleSpace = 0.25, distanceFalloff = 1.5, onlyModelMap = 1,
						windAffected = -1, riseRate = 0, yoffset = 5,
						lifeTime = 0, rampUp = 30, decay = 5, effectType = 0},
	},

	LaserBeamShockWaveProjectile = {
		distortionType = 'beam', -- or cone or beam
		distortionConfig = {
				posx = 0, posy = 10, posz = 0, radius = 150,
				pos2x = 100, pos2y = 1000, pos2z = 100, -- beam distortions only, specifies the endpoint of the beam
				lifeTime = 10, sustain = 1, effectType = 'groundShockwave',
		},
	},

	LaserBeamHeat = {
		distortionType = 'beam', -- or cone or beam
		distortionConfig = {
				posx = 0, posy = 10, posz = 0, radius = 10,
				noiseStrength = 0.3, noiseScaleSpace = 0.3, effectStrength = 0.5,
				pos2x = 100, pos2y = 1000, pos2z = 100, -- beam distortions only, specifies the endpoint of the beam
				lifeTime = 0, rampUp = 2, decay = 0, effectType = 0,
		},
	},

	HeatRayHeat = {
		distortionType = 'beam', -- or cone or beam
		distortionConfig = {
				posx = 0, posy = 10, posz = 0, radius = 10,
				noiseStrength = 0.75, noiseScaleSpace = 0.15, distanceFalloff = 1.5,
				windAffected = -1, riseRate = 0.2,
				pos2x = 100, pos2y = 1000, pos2z = 100, -- beam distortions only, specifies the endpoint of the beam
				lifeTime = 3, rampUp = 3, decay = 0, effectType = 0,
		},
	},
	HeatRayHeatXL = { --heaviest laserbeam (corkorg)
		distortionType = 'beam', -- or cone or beam
		distortionConfig = {
				posx = 0, posy = 10, posz = 0, radius = 10,
				pos2x = 0, pos2y = 0, pos2z = 0, radius2 = 1,
				noiseStrength = 1.2, noiseScaleSpace = 0.022, distanceFalloff = 0.2,
				effectStrength = 1.0,
				windAffected = -1, riseRate = 4.2, onlyModelMap = 0,
				--refractiveIndex = 1.15,
				lifeTime = 0, rampUp = 0, decay = 0, effectType = 7,
		},
	},

	TachyonBeam = { --original for armbanth
		distortionType = 'beam', -- or cone or beam
		distortionConfig = {
				posx = 0, posy = 0, posz = 0, radius = 10,
				noiseStrength = 2.2, noiseScaleSpace = 0.03,
				windAffected = -1, riseRate = 2.6, onlyModelMap = 0,
				pos2x = 100, pos2y = 500, pos2z = 100, -- beam distortions only, specifies the endpoint of the beam
				lifeTime = 10, sustain = 1, rampUp = 0, decay = 3, effectType = 7,
		},
	},

	TachyonBeam2 = {
		distortionType = 'beam', -- or cone or beam
		distortionConfig = {
				posx = 0, posy = 0, posz = 0, radius = 10,
				noiseStrength = 0.3, noiseScaleSpace = 0.025, distanceFalloff = -1,
				windAffected = -0.8, riseRate = -0.2, effectStrength = 0.5,
				pos2x = 100, pos2y = 500, pos2z = 100, -- beam distortions only, specifies the endpoint of the beam
				lifeTime = 0, sustain = 0, rampUp = 0, decay = 3, effectType = 0,
		},
	},

	TachyonBeam3 = {
		distortionType = 'beam', -- or cone or beam
		distortionConfig = {
				posx = 0, posy = 0, posz = 0, radius = 10,
				noiseStrength = 1.0, noiseScaleSpace = 0.020,
				windAffected = -0.5, riseRate = 0.3, effectStrength = 1,
				pos2x = 0, pos2y = 0, pos2z = 0, -- beam distortions only, specifies the endpoint of the beam
				lifeTime = 0, sustain = 0, rampUp = 0, decay = 0, effectType = 12,
		},
	},

	LightningBeam = {
		distortionType = 'beam', -- or cone or beam
		distortionConfig = {
				posx = 0, posy = 10, posz = 0, radius = 10,
				noiseStrength = 0.7, noiseScaleSpace = 0.07, distanceFalloff = 2.5,
				effectStrength = 4.0,
				--windAffected = 2, riseRate = 2,
				windAffected = -1, riseRate = -0.6,
				pos2x = 100, pos2y = 1000, pos2z = 100, -- beam distortions only, specifies the endpoint of the beam
				lifeTime = 0, rampUp = 0, decay = 0, effectType = 0,
		},
	},

	EMPBeam = {
		distortionType = 'beam', -- or cone or beam
		distortionConfig = {
				posx = 0, posy = 10, posz = 0, radius = 10,
				noiseStrength = 1.0, noiseScaleSpace = 0.16, distanceFalloff = 1.0,
				effectStrength = 2.5,
				--onlyModelMap = 1,
				--windAffected = 2, riseRate = 2,
				windAffected = -1, riseRate = -3.2,
				pos2x = 100, pos2y = 100, pos2z = 100, -- beam distortions only, specifies the endpoint of the beam
				lifeTime = 0, rampUp = 0, decay = 2, effectType = 0,
		},
	},
	EMPBeamXL = {
		distortionType = 'beam', -- or cone or beam
		distortionConfig = {
				posx = 0, posy = 10, posz = 0, radius = 10,
				noiseStrength = 1.0, noiseScaleSpace = 0.12, distanceFalloff = 0.5,
				effectStrength = 3.0,
				--onlyModelMap = 1,
				--windAffected = 2, riseRate = 2,
				windAffected = -1, riseRate = -2.2,
				pos2x = 100, pos2y = 100, pos2z = 100, -- beam distortions only, specifies the endpoint of the beam
				lifeTime = 0, rampUp = 0, decay = 1, effectType = 0,
		},
	},

	AirBombProjectile = {
		distortionType = 'cone',
		distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 70,
						dirx =  0, diry = 1, dirz = 1.0, theta = 0.2,
						startRadius = 0.5, onlyModelMap = 1,
						noiseStrength = 1.45, noiseScaleSpace = 0.75, distanceFalloff = 1.8,
						onlyModelMap = 0, yoffset = 8,
						effectStrength = 2.0, windAffected = -1, riseRate = -0.3,
						rampUp = 15, lifeTime = 0, sustain = 0, effectType = 0},
	},

	MissileProjectile = {
		distortionType = 'cone',
		distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 100,
						dirx =  0, diry = 1, dirz = 1.0, theta = 0.1,
						startRadius = 0.5, onlyModelMap = 1,
						noiseStrength = 1.45, noiseScaleSpace = 0.75, distanceFalloff = 1.8,
						onlyModelMap = 0, yoffset = 8,
						effectStrength = 1.0, windAffected = -1, riseRate = -0.3,
						rampUp = 15, lifeTime = 0, sustain = 0, effectType = 0},
	},

	MissileProjectileXL = {
		distortionType = 'cone',
		distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 130,
						startRadius = 0.5, onlyModelMap = 1,
						dirx =  0, diry = 1, dirz = 1.0, theta = 0.08,
						noiseStrength = 4, noiseScaleSpace = 0.37, distanceFalloff = 1.8,
						onlyModelMap = 0, yoffset = 10,
						effectStrength = 1.2, windAffected = -1, riseRate = -0.3,
						rampUp = 4, lifeTime = 0, sustain = 0, effectType = 0},
	},

	MissileNukeProjectile = {
		distortionType = 'cone',
		distortionConfig = { posx = 0, posy = 0, posz = 00, radius = 200,
						dirx =  0, diry = 1, dirz = 1.0, theta = 0.3,
						noiseStrength = 4, noiseScaleSpace = 0.3, distanceFalloff = 1.0, onlyModelMap = 0,
						rampUp = 30, yoffset = 8,
						lifeTime = 0, sustain = 0, effectType = 0},
	},


	LaserAimProjectile = {
		distortionType = 'cone', -- or cone or beam
		distortionConfig = {
			posx = 0, posy = 0, posz = 0, radius = 500,
			dirx = 1, diry = 0, dirz = 1, theta = 0.02,  -- cone distortions only, specify direction and half-angle in radians
			lifeTime = 0, sustain = 1, 	effectType = 0,
		},
	},

	GroundShockWaveXS = {
		distortionType = 'point', -- or cone or beam
		alwaysVisible = false,
		distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 200,
						distanceFalloff = 0.6, noiseStrength = 0.35, noiseScaleSpace = 0.8,
						lifeTime = 12, decay = 8, rampUp = 4,
						effectStrength = 1.2, --needed for shockwaves
						shockWidth = 1, refractiveIndex = 1.1, startRadius = 0.24,
						effectType = 'groundShockwave'},
	},

	GroundShockWave = {
		distortionType = 'point', -- or cone or beam
		alwaysVisible = false,
		distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 200,
						distanceFalloff = 0.1, noiseStrength = 0.5, noiseScaleSpace = 0.8,
						lifeTime = 21, decay = 16, rampUp = 4,
						effectStrength = 1.5, --needed for shockwaves
						shockWidth = 1.2, refractiveIndex = -1.2, startRadius = 0.24,
						effectType = 'groundShockwave'},
	},

	GroundShockWaveNuke = {
		distortionType = 'point', -- or cone or beam
		alwaysVisible = false,
		distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 200,
						noiseStrength = 2, noiseScaleSpace = 0.10,
						effectStrength = 1.0, --needed for shockwaves
						lifeTime = 100, decay = 25, rampUp = 5,
						shockWidth = 16, refractiveIndex = -1.1,
						startRadius = 0.24,
						effectType = 'groundShockwave'},
	},

	GroundShockWaveFuzzy = {
		distortionType = 'point', -- or cone or beam
		alwaysVisible = false,
		distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 200,
						distanceFalloff = 1.0, onlyModelMap = 0,
						effectStrength = 1.2, --needed for shockwaves
						shockWidth = 3, startRadius = 0.24,
						lifeTime = 25,  effectType = 'groundShockwave'},
	},

	GroundAcidExplo = {
		distortionType = 'point', -- or cone or beam
		alwaysVisible = false,
		distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 200,
						distanceFalloff = 0.9, noiseStrength = 0.5, noiseScaleSpace = 0.7,
						lifeTime = 200, decay = 150, rampUp = 50,
						effectStrength = 1.2, --needed for shockwaves
						windAffected = -0.5, riseRate = 6, --used for width of shockwave
						shockWidth = 6, refractiveIndex = -1.2, startRadius = 0.5,
						onlyModelMap = 1,
						effectType = 'groundShockwave'},
	},

	ExploUnitAirShockWave = {
		distortionType = 'point', -- or cone or beam
		distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 150,
			noiseScaleSpace = 0.15, noiseStrength = 0.3, onlyModelMap = 0,
			lifeTime = 12, refractiveIndex = 1.04, decay = 5, rampUp = 1,
			effectStrength = 5.0, startRadius = 0.3, shockWidth = -0.70,
			effectType = "airShockwave", },

	},

	AirShockWaveXS = {
		distortionType = 'point', -- or cone or beam
		distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 150,
			noiseScaleSpace = 1.1, noiseStrength = 0.01, onlyModelMap = 1,
			lifeTime = 7, refractiveIndex = 1.03, decay = 4, rampUp = 3,
			effectStrength = 2.0, startRadius = 0.20, shockWidth = -0.60, --needed for all distortions
			effectType = "airShockwave", },
	},
	AirShockWave = {
		distortionType = 'point', -- or cone or beam
		distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 150,
			noiseScaleSpace = 0.1, noiseStrength = 0.2, onlyModelMap = 0,
			lifeTime = 11, refractiveIndex = 1.04, decay = 4, rampUp = 2,
			effectStrength = 2.8, startRadius = 0.25, shockWidth = -0.80,
			effectType = "airShockwave", },

	},
	AirShockWaveDgun = {
		distortionType = 'point', -- or cone or beam
		distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 150,
			noiseScaleSpace = 0.5, noiseStrength = 1, onlyModelMap = 0,
			lifeTime = 35, refractiveIndex = 1.05, decay = 3, rampUp = 5,
			startRadius = 0.1, shockWidth = 1.9,
			effectStrength = 4.5, --needed for airshockwaves
			effectType = "airShockwave", },

	},
	AirShockWaveNuke = {
		distortionType = 'point', -- or cone or beam
		distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 150,
			noiseScaleSpace = 0.05, noiseStrength = 0.2, onlyModelMap = 0,
			lifeTime = 25, refractiveIndex = 1.1, decay = 20, rampUp = 1,
			effectStrength = 20.0, startRadius = 0.2, shockWidth = -0.70,--needed for airshockwaves
			effectType = "airShockwave", },

	},
	AirShockWaveNukeBlast = {
		distortionType = 'point', -- or cone or beam
		distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 225,
			noiseScaleSpace = 0.3, noiseStrength = 0.5, onlyModelMap = 1,
			lifeTime = 150, refractiveIndex = 1.5, decay = 60, rampUp = 40,
			effectStrength = 1.0, startRadius = 0.05, shockWidth = 0.25,
			windAffected = 3,
			effectType = "airShockwave", },

	},
	TorpedoShockWave = {
		distortionType = 'point', -- or cone or beam
		distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 150,
			noiseScaleSpace = 1.2, noiseStrength = 0.8, onlyModelMap = 0,
			lifeTime = 10, refractiveIndex = 1.2, decay = 3, rampUp = 3,
			effectStrength = 2.2, startRadius = 0.25, shockWidth = -0.95,
			effectType = "airShockwave", },
	},

	-- ALL CANNON explosion Classes

	ExploShockWaveXS = {
		distortionType = 'point', -- or cone or beam
		distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 100,
			noiseScaleSpace = 0.1, noiseStrength = 0.2, onlyModelMap = 0,
			lifeTime = 4, refractiveIndex = 1.04, decay = 2, rampUp = 0,
			effectStrength = 4.0, startRadius = 0.4, shockWidth = -1.2,
			effectType = "airShockwave", },
	},
	ExploShockWaveS = {
		distortionType = 'point', -- or cone or beam
		distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 150,
			noiseScaleSpace = 0.1, noiseStrength = 0.2, onlyModelMap = 0,
			lifeTime = 4.5, refractiveIndex = 1.04, decay = 3, rampUp = 1,
			effectStrength = 4.0, startRadius = 0.39, shockWidth = -1.1,
			effectType = "airShockwave", },
	},
	ExploShockWaveM = {
		distortionType = 'point', -- or cone or beam
		distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 200,
			noiseScaleSpace = 0.3, noiseStrength = 0.2, onlyModelMap = 0,
			lifeTime = 5.5, refractiveIndex = 1.09, decay = 3, rampUp = 1,
			effectStrength = 3.5, startRadius = 0.39, shockWidth = -0.99,
			effectType = "airShockwave", },
	},
	ExploShockWaveL = {
		distortionType = 'point', -- or cone or beam
		distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 380,
			noiseScaleSpace = 0.1, noiseStrength = 0.2, onlyModelMap = 0,
			lifeTime = 11, refractiveIndex = 1.03, decay = 4, rampUp = 6,
			effectStrength = 4.1, startRadius = 0.33, shockWidth = -0.50,
			effectType = "airShockwave", },
	},
	ExploShockWaveXL = {
		distortionType = 'point', -- or cone or beam
		distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 480,
			noiseScaleSpace = 0.1, noiseStrength = 0.2, onlyModelMap = 0,
			lifeTime = 24, refractiveIndex = 1.02, decay = 4, rampUp = 4,
			effectStrength = 4, startRadius = 0.28, shockWidth = -0.50,
			effectType = "airShockwave", },
	},

	-- ALL UNIT Explosion Classes

	UnitExploShockWaveXS = {
		distortionType = 'point', -- or cone or beam
		distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 100,
			noiseScaleSpace = 0.1, noiseStrength = 0.2, onlyModelMap = 0,
			lifeTime = 5, refractiveIndex = 1.08, decay = 4, rampUp = 1,
			effectStrength = 5.5, startRadius = 0.45, shockWidth = -0.50,
			effectType = "airShockwave", },
	},
	UnitExploShockWaveS = {
		distortionType = 'point', -- or cone or beam
		distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 150,
			noiseScaleSpace = 0.1, noiseStrength = 0.2, onlyModelMap = 0,
			lifeTime = 6, refractiveIndex = 1.06, decay = 5, rampUp = 4,
			effectStrength = 4.75, startRadius = 0.41, shockWidth = -0.50,
			effectType = "airShockwave", },
	},
	UnitExploShockWaveM = {
		distortionType = 'point', -- or cone or beam
		distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 200,
			noiseScaleSpace = 0.1, noiseStrength = 0.2, onlyModelMap = 0,
			lifeTime = 9, refractiveIndex = 1.05, decay = 5, rampUp = 4,
			effectStrength = 5.0, startRadius = 0.38, shockWidth = -0.50,
			effectType = "airShockwave", },
	},
	UnitExploShockWaveL = {
		distortionType = 'point', -- or cone or beam
		distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 380,
			noiseScaleSpace = 0.1, noiseStrength = 0.2, onlyModelMap = 0,
			lifeTime = 13, refractiveIndex = 1.04, decay = 4, rampUp = 4,
			effectStrength = 4.5, startRadius = 0.33, shockWidth = -0.50,
			effectType = "airShockwave", },
	},
	UnitExploShockWaveXL = {
		distortionType = 'point', -- or cone or beam
		distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 480,
			noiseScaleSpace = 0.1, noiseStrength = 0.2, onlyModelMap = 0,
			lifeTime = 18, refractiveIndex = 1.02, decay = 4, rampUp = 4,
			effectStrength = 4, startRadius = 0.28, shockWidth = -0.50,
			effectType = "airShockwave", },
	},

	UnitGroundShockWave = {
		distortionType = 'point', -- or cone or beam
		alwaysVisible = false,
		distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 200,
						distanceFalloff = 0.5, noiseStrength = 0.5, noiseScaleSpace = 0.8,
						lifeTime = 25, decay = 25, rampUp = 15,
						effectStrength = 1.5, --needed for shockwaves
						shockWidth = 3, refractiveIndex = -1.2, startRadius = 0.24,
						effectType = 'groundShockwave'},
	},
	UnitGroundShockWaveXL = {
		distortionType = 'point', -- or cone or beam
		alwaysVisible = false,
		distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 200,
						distanceFalloff = 0.5, noiseStrength = 0.5, noiseScaleSpace = 0.8,
						lifeTime = 25, decay = 25, rampUp = 15,
						effectStrength = 1.5, --needed for shockwaves
						shockWidth = 3, refractiveIndex = -1.2, startRadius = 0.24,
						effectType = 'groundShockwave'},
	},

	BuildingGroundShockWave = {
		distortionType = 'point', -- or cone or beam
		alwaysVisible = false,
		distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 200,
						distanceFalloff = 0.5, noiseStrength = 0.5, noiseScaleSpace = 0.8,
						lifeTime = 25, decay = 25, rampUp = 15,
						effectStrength = 1.5, --needed for shockwaves
						shockWidth = 3, refractiveIndex = -1.2, startRadius = 0.24,
						effectType = 'groundShockwave'},
	},
	BuildingGroundShockWaveXL = {
		distortionType = 'point', -- or cone or beam
		alwaysVisible = false,
		distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 200,
						distanceFalloff = 0.5, noiseStrength = 0.5, noiseScaleSpace = 0.8,
						lifeTime = 25, decay = 25, rampUp = 15,
						effectStrength = 1.5, --needed for shockwaves
						shockWidth = 3, refractiveIndex = -1.2, startRadius = 0.24,
						effectType = 'groundShockwave'},
	},
	BuildingExploEnergy = {
		distortionType = 'point', -- or cone or beam
		yOffset = 0, -- Y offsets are only ever used for explosions!
		distortionConfig = {
			posx = 0, posy = 0, posz = 0, radius = 10,
			noiseStrength = 2, noiseScaleSpace = 0.95, distanceFalloff = 1.5,
			onlyModelMap = 0, startRadius = 0.3,
			lifeTime = 20, rampUp = 7, decay = 13, effectType = 0,
		},
	},

	MuzzleShockWaveXS = {
		distortionType = 'point', -- or cone or beam
		distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 150,
			noiseScaleSpace = 0.2, noiseStrength = 0.3, onlyModelMap = 0,
			lifeTime = 7, refractiveIndex = 1.03, decay = 3, rampUp = 1,
			effectStrength = 1.9, startRadius = 0.2, shockWidth = -0.80,
			effectType = "airShockwave", },

	},
	MuzzleShockWave = {
		distortionType = 'point', -- or cone or beam
		distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 150,
			noiseScaleSpace = 0.2, noiseStrength = 0.3, onlyModelMap = 0,
			lifeTime = 9, refractiveIndex = 1.03, decay = 6, rampUp = 2,
			effectStrength = 2.2, startRadius = 0.6, shockWidth = -0.80,
			effectType = "airShockwave", },

	},
	MuzzleShockWaveXL = {
		distortionType = 'point', -- or cone or beam
		distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 150,
			noiseScaleSpace = 0.1, noiseStrength = 0.2, onlyModelMap = 0,
			lifeTime = 11, refractiveIndex = 1.02, decay = 7, rampUp = 3,
			effectStrength = 4.0, startRadius = 0.5, shockWidth = -0.75,
			effectType = "airShockwave", },

	},


	AirShockWaveBeam = {
		distortionType = 'beam', -- or cone or beam
		distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 150,
			noiseScaleSpace = 0.5, noiseStrength = 1.0,
			lifeTime = 15,  refractiveIndex = 1.05,
			--windAffected = 0.5,  riseRate = 1,
			effectStrength = 1.0, --needed for irshockwaves
			effectType = 'airShockwave', },

	},

	TorpedoProjectile = {
		distortionType = 'cone', -- or cone or beam
		distortionConfig = {
			posx = 0, posy = 0, posz = 0, radius = 300,
			dirx = 1, diry = 0, dirz = 1, theta = 0.10,  -- cone distortions only, specify direction and half-angle in radians
			noiseStrength = 2, noiseScaleSpace = 0.90, distanceFalloff = 0.9, onlyModelMap = 0,
			lifeTime = 0, sustain = 1, 	effectType = 0,
		},
	},

	FlameProjectile = {
		distortionType = 'point', -- or cone or beam
		fraction = 5, -- only spawn every nth distortion
		distortionConfig = {
			posx = 0, posy = 15, posz = 0, radius = 25,
			noiseStrength = 8, noiseScaleSpace = -0.30, distanceFalloff = 0.9, onlyModelMap = 0,
			windAffected = 0.2, riseRate = -0.5,
			lifeTime = 29, rampUp = 15, decay = 10, effectType = 0,
		},
	},
	FlameProjectileXL = {
		distortionType = 'point', -- or cone or beam
		fraction = 3, -- only spawn every nth distortion
		distortionConfig = {
			posx = 0, posy = 45, posz = 0, radius = 25,
			noiseStrength = 4, noiseScaleSpace = -0.45, distanceFalloff = 1.6, onlyModelMap = 0,
			windAffected = 0.1, riseRate = -0.5,
			lifeTime = 40, rampUp = 30, decay = 30, effectType = 0,
		},
	},
	FireHeat = { -- spawned on explosions
		distortionType = 'point', -- or cone or beam
		yOffset = 0, -- Y offsets are only ever used for explosions!
		distortionConfig = {
			posx = 0, posy = 0, posz = 0, radius = 10,
			noiseStrength = 1.3, noiseScaleSpace = 0.60, distanceFalloff = 0.5,
			startRadius = 0.3, onlyModelMap = 0, refractiveIndex = 0.9,
			windAffected = 1.3, riseRate = 1.5,
			lifeTime = 20, rampUp = 10, decay = 10, effectType = 0,
		},
	},

	ExplosionDistort = { -- spawned on explosions
		distortionType = 'point', -- or cone or beam
		yOffset = 0, -- Y offsets are only ever used for explosions!
		distortionConfig = {
			posx = 0, posy = 0, posz = 0, radius = 10,
			noiseStrength = 2, noiseScaleSpace = 0.95, distanceFalloff = 1.5,
			onlyModelMap = 0, startRadius = 0.3,
			lifeTime = 20, rampUp = 7, decay = 13, effectType = 0,
		},
	},

	ExplosionHeatXS = { -- spawned on explosions
		distortionType = 'point', -- or cone or beam
		yOffset = 0, -- Y offsets are only ever used for explosions!
		distortionConfig = {
			posx = 0, posy = 0, posz = 0, radius = 10,
			noiseStrength = 1, noiseScaleSpace = 0.75, distanceFalloff = 0.5, onlyModelMap = 0,
			lifeTime = 30, rampUp = 15, decay = 20, effectType = 0,
		},
	},
	ExplosionHeat = { -- spawned on explosions
		distortionType = 'point', -- or cone or beam
		yOffset = 0, -- Y offsets are only ever used for explosions!
		distortionConfig = {
			posx = 0, posy = 0, posz = 0, radius = 10,
			noiseStrength = 1, noiseScaleSpace = 0.75, distanceFalloff = 0.5,
			startRadius = 0.3, onlyModelMap = 0,
			lifeTime = 60, rampUp = 30, decay = 30, effectType = 0,
		},
	},
	ExplosionHeatNuke = { -- spawned on explosions
		distortionType = 'point', -- or cone or beam
		yOffset = 0, -- Y offsets are only ever used for explosions!
		distortionConfig = {
			posx = 0, posy = 0, posz = 0, radius = 10,
			noiseStrength = 75, noiseScaleSpace = 0.034, distanceFalloff = 0.5, onlyModelMap = 0,
			windAffected = -1,  riseRate = 0.3, startRadius = 0.4,
			lifeTime = 12, rampUp = 2, decay = 10, effectType = 0,
		},
	},
	ExplosionRadiationNuke = { -- spawned on explosions
		distortionType = 'point', -- or cone or beam
		yOffset = 0, -- Y offsets are only ever used for explosions!
		distortionConfig = {
			posx = 0, posy = 0, posz = 0, radius = 10,
			noiseStrength = 20, noiseScaleSpace = 0.1, distanceFalloff = 0.5, onlyModelMap = 0,
			windAffected = -1,  riseRate = -0.5,
			lifeTime = 200, rampUp = 100, decay = 100, effectType = 0,
		},
	},
	ExplosionRadiationDgun = { -- spawned on explosions
		distortionType = 'point', -- or cone or beam
		yOffset = 0, -- Y offsets are only ever used for explosions!
		fraction = 6,
		distortionConfig = {
			posx = 0, posy = 0, posz = 0, radius = 10,
			noiseStrength = 6, noiseScaleSpace = 0.55, distanceFalloff = 1.2, onlyModelMap = 1,
			windAffected = -1,  riseRate = -0.5,
			lifeTime = 50, rampUp = 20, decay = 25, effectType = 0,
		},
	},

	JunoHeat = { -- unused
		distortionType = 'point', -- or cone or beam
		yOffset = 0, -- Y offsets are only ever used for explosions!
		distortionConfig = {
			posx = 0, posy = 0, posz = 0, radius = 10,
			noiseStrength = 1, noiseScaleSpace = 0.75, distanceFalloff = 0.5, onlyModelMap = 0,
			lifeTime = 60, rampUp = 30, decay = 30, effectType = 7,
		},
	},

	EMPShockWave = { -- Short distortion wave for EMP
		distortionType = 'point', 
		yOffset = 0, -- Y offsets are only ever used for explosions!
		distortionConfig = {
			posx = 0, posy = 0, posz = 0, radius = 200,
			noiseStrength = 2.5, noiseScaleSpace = 0.13, distanceFalloff = 0.1, onlyModelMap = 1,
			lifeTime = 20, effectStrength = -1.5, startRadius = 0.4,
			rampUp = 5, decay = 15, shockWidth = 8, effectType = 2,
		},
	},

	EMPNoise = { -- Circle area-distortion-effect for EMP
		distortionType = 'point',
		yOffset = 0, -- Y offsets are only ever used for explosions!
		distortionConfig = {
			posx = 0, posy = 0, posz = 0, radius = 200,
			noiseStrength = 0.85, noiseScaleSpace = 0.1, distanceFalloff = 0.1, onlyModelMap = 1,
			startRadius = 0.60, shockWidth = 20, refractiveIndex = -1.2,
			effectStrength = 0.7,
			windAffected = -0.95, riseRate = -0.95,
			lifeTime = 80, rampUp = 10, decay = 30, effectType = 13,
		},
	},
	EMPRipples = { -- Circle area-distortion-effect for EMP
		distortionType = 'point',
		yOffset = 0, -- Y offsets are only ever used for explosions!
		distortionConfig = {
			posx = 0, posy = 0, posz = 0, radius = 200,
			noiseStrength = 6.0, noiseScaleSpace = 0.38, distanceFalloff = 0.1, onlyModelMap = -1,
			startRadius = 0.5, shockWidth = 1.05, refractiveIndex = -1.2,
			effectStrength = 5,
			windAffected = -1, riseRate = -1,
			lifeTime = 59, rampUp = 19, decay = 40, effectType = 'groundShockwave',
		},
	},

	AirShockWaveEMP = { -- Noised/electric Shockwave ripple on units
		distortionType = 'point', -- or cone or beam
		distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 150,
			noiseScaleSpace = 0.15, noiseStrength = 0.8, onlyModelMap = 0,
			lifeTime = 12, refractiveIndex = 1.03, decay = 4, rampUp = 8,
			effectStrength = 1.75, shockWidth = -0.30, --needed for airshockwaves
			effectType = "airShockwave", },

	},

	JunoShockWave = { -- big distorted shockwave
		distortionType = 'point', -- or cone or beam
		yOffset = 0, -- Y offsets are only ever used for explosions!
		distortionConfig = {
			posx = 0, posy = 0, posz = 0, radius = 10,
			noiseStrength = 2.5, noiseScaleSpace = 0.13, distanceFalloff = 0.1, onlyModelMap = 1,
			lifeTime = 40, effectStrength = -11, startRadius = 0.2,
			rampUp = 10, decay = 30,  shockWidth = 14, effectType = 2,
		},
	},

	JunoNoise = { -- spawned on explosions
		distortionType = 'point', -- or cone or beam
		yOffset = 0, -- Y offsets are only ever used for explosions!
		distortionConfig = {
			posx = 0, posy = 0, posz = 0, radius = 600,
			noiseStrength = 0.45, noiseScaleSpace = 1.5, distanceFalloff = 0.1, onlyModelMap = 1,
			startRadius = 0.90, shockWidth = 20, refractiveIndex = -1.2,
			effectStrength = 0.7,
			windAffected = -0.5,  riseRate = 2,
			lifeTime = 675, rampUp = 100, decay = 500, effectType = 13,
		},
	},

	ProjectileDgun = { -- spawned on explosions
		distortionType = 'point', -- or cone or beam
		yOffset = 0, -- Y offsets are only ever used for explosions!
		distortionConfig = {
			posx = 0, posy = 0, posz = 0, radius = 10,
			noiseStrength = 20, noiseScaleSpace = -0.1, distanceFalloff = 0.5, onlyModelMap = 0,
			windAffected = -1,  riseRate = 0,
			--magnificationRate = 8.0,
			lifeTime = 75, rampUp = 50, decay = 25, effectType = 0,
		},
	},

	MuzzleFlash = { -- spawned on projectilecreated
		distortionType = 'point', -- or cone or beam
		distortionConfig = {
			posx = 0, posy = 0, posz = 0, radius = 150,
			lifeTime = 6, sustain = 0.0035, effectType = 0,
		},
	},
}


local SizeRadius = {
	Quaco = 		2.5,
	Zetto = 		5,
	Atto =			10,
	Banthlaser =	13,
	Femto = 		16,
	KorgLaser = 	19,
	Pico = 			26,
	Nano = 			34,
	Micro = 		44,
	Tiniest = 		56,
	Tiny = 			72,
	Smallest = 		90,
	Smaller = 		115,
	Small = 		140,
	Smallish = 		165,
	SmallMedium = 	190,
	Medium = 		220,
	Mediumer = 		260,
	MediumLarge = 	300,
	Large = 		400,
	Juno =			450,
	Larger = 		500,
	Largest = 		650,
	Mega = 			800,
	MegaXL = 		1000,
	Armnuke =		1280,
	MegaXXL = 		1500,
	Cornuke = 		1920,
	Giga = 			2000,
	Tera = 			3500,
	Planetary = 	5000,
}


local globalDamageMult = Spring.GetModOptions().multiplier_weapondamage or 1

local function GetClosestSizeClass(desiredsize)
	local delta = math.huge
	local best = nil
	for classname, size in pairs(SizeRadius) do
		if math.abs(size-desiredsize) < delta then
			delta = math.abs(size-desiredsize)
			best = classname
		end
	end
	return best, SizeRadius[best]
end

local lifeTimes = {Fast = 5, Quick = 10, Moderate = 30, Long = 90, Glacial = 270}

local distortionClasses = {}

local function deepcopy(orig)
	local orig_type = type(orig)
	local copy
	if orig_type == 'table' then
		copy = {}
		for orig_key, orig_value in next, orig, nil do
			copy[deepcopy(orig_key)] = deepcopy(orig_value)
		end
		--setmetatable(copy, deepcopy(getmetatable(orig)))
	else -- number, string, boolean, etc
		copy = orig
	end
	return copy
end
local usedclasses = 0
local function GetDistortionClass(baseClassname, sizekey, additionaloverrides)
	local distortionClassKey = baseClassname  .. (sizekey or "")
	if additionaloverrides and type(additionaloverrides) == 'table' then
		for k,v in pairs(additionaloverrides) do
			distortionClassKey = distortionClassKey .. "_" .. tostring(k) .. "=" .. tostring(v)
		end
	end

	if distortionClasses[distortionClassKey] then
		return distortionClasses[distortionClassKey]
	else
		if not BaseClasses[baseClassname] then
			error("BaseClasses[" .. tostring(baseClassname) .. "] is nil!")
		end
			distortionClasses[distortionClassKey] = deepcopy(BaseClasses[baseClassname])
			distortionClasses[distortionClassKey].distortionClassName = distortionClassKey
			usedclasses = usedclasses + 1
			local distortionConfig = distortionClasses[distortionClassKey].distortionConfig or {}

    		if sizekey and SizeRadius[sizekey] then
       		 distortionConfig.radius = SizeRadius[sizekey]
				if additionaloverrides then
					for k,v in pairs(additionaloverrides) do
						distortionConfig[k] = v
					end
				end
   		 else
        	print("Warning: sizekey or SizeRadius[sizekey] is nil!")
    	end
	end
	return distortionClasses[distortionClassKey]
end

--------------------------------------------------------------------------------

local gibDistortion = {
	distortionType = 'point', -- or cone or beam
	pieceName = nil, -- optional
	distortionConfig = {
		posx = 0, posy = 0, posz = 0, radius = 12,
		lifeTime = 75, decay = 75, effectType = 0
	},
}

--------------------------------------------------------------------------------

local muzzleFlashDistortions = {}
local explosionDistortions = {}
local projectileDefDistortions  = {
	['default'] = {
		distortionType = 'point',
		distortionConfig = { posx = 0, posy = 16, posz = 0, radius = 420,
			lifeTime = 50, sustain = 20, effectType = 0},
	}
}

-----------------------------------

-- This function automatically assigns distortions to weapons for their 3 main events:
-- It first checks for various things among the different categories of weapons, which identify if the weapon
-- should have a muzzleFlash, projectileDistortion, or an explosionDistortion.
-- See https://docs.google.com/document/d/16mvYJX8WJ8cNjGe_3zhrymTOzPoSkFprr78i_vpH7yA/edit?tab=overrideTable.0#heading=h.qx93abxpcjjo for details


-- 1. explosionDistortion - Weapon explosions based on damage and type
	-- Note that this must be a table of distortions, as an explosion can consist of multiple effects, e.g.:
	-- explosionDistortions[weaponID] = {GetDistortionClass("ExplosionHeat"), GetDistortionClass("GroundShockWave"), GetDistortionClass("AirShockWave")}

-- 2. muzzleFlash
	-- Note that this must be a table of distortions, as a muzzle flash can consist of multiple effects, e.g.:
	-- muzzleFlashDistortions[weaponID] = {GetDistortionClass("GroundShockWave"), GetDistortionClass("AirShockWave")}

-- 3. Weapon Projectiles, projectileDistortion
	-- NOTE THAT ONLY A SINGLE DISTORTION CAN BE ASSIGNED TO A FLYING PROJECTILE!, e.g.:
	-- projectileDefDistortions[weaponID] = GetDistortionClass("CannonProjectile")

-- 4-5. Unit/building Explosions, these also go into explosionDistortions, as tables.
	-- Note that the weapons that define these explosions are in weapons/Unit_Explosions.lua,
	-- and the weaponDef.customParams.unitexplosion is set to 1.
	-- Unit / building explosions are not differentiated, they could easily be, by adding a customParam to the weaponDef, such as
	-- weaponDef.customParams.buildingexplosion = 1
	-- In this case, also also edit DeferredLightsGL4Config to ensure that both unitexplosions and weaponexplosions are handled correctly.
	-- (search for weaponDef.customParams.unitexplosion)



	local function AssignDistortionsToAllWeapons()
		for weaponID=1, #WeaponDefs do
			local weaponDef = WeaponDefs[weaponID]
			local damage = 100
			for cat=0, #weaponDef.damages do
				if Game.armorTypes[cat] and Game.armorTypes[cat] == 'default' then
					damage = weaponDef.damages[cat]
					break
				end
			end

			-- Start by collecting some common parameters of the weapon
			damage = (damage / globalDamageMult) + ((damage * (globalDamageMult-1))*0.25)

			local projectileSpeed = weaponDef.weaponVelocity or 10
			local weaponRange = weaponDef.range or 0
			local areaofeffect = weaponDef.damageAreaOfEffect or 0
			--local weaponImpulse = weaponDef.impulseFactor or 0 (doesn't seem to work)
			local life = 12
			local radius = ((areaofeffect*0.7) + (areaofeffect * weaponDef.edgeEffectiveness * 1.1))
			local muzzleflashRadius = radius^0.75 + (weaponRange * 0.015) + (projectileSpeed * 0.045) --for muzzleflashes
			--local effectiveRangeExplo = ((areaofeffect * 1.2) - ((1 - weaponDef.edgeEffectiveness) * areaofeffect * 0.5)) --+ (weaponImpulse * 1000)
			local effectiveRangeExplo = areaofeffect * (0.75 + (0.4 * math.sqrt(weaponDef.edgeEffectiveness)))
			--local effectiveUnitRangeExplo = areaofeffect * 2


			--local radius = (weaponDef.damageAreaOfEffect * weaponDef.edgeEffectiveness * 1.55)

			local muzzleFlash = true -- by default add muzzleflash to weapon being fired
			local explosionDistortion = true -- by default, add explosion distortion to weapon on explosion
			local sizeclass = GetClosestSizeClass(radius)
			local t = {}
			local overrideTable = {}
			local antiair = string.find(weaponDef.cegTag, 'aa') or false
			local paralyzer = (weaponDef.paralyzer) or false
			local scavenger = string.find(weaponDef.name, '_scav') or false
			local juno = string.find(weaponDef.name, 'juno') or false
			--local isBuilding =
			local isUnitExplosion = string.find(weaponDef.name, 'explosion') or false
			local isBuildingExplosion = string.find(weaponDef.name, 'buildingexplosion') or false

			-- Assign projectileDistortions based on type, and decide weather muzzleflashes or explosiondistortions are needed
			if weaponDef.type == 'BeamLaser' then
				muzzleFlash = false


				radius = (1.5 * (weaponDef.size * weaponDef.size * weaponDef.size)) + (5 * radius)
				--t.a = (damage * 0.1) / (0.2 + weaponDef.beamtime)
				--projectileDefDistortions[weaponID].yOffset = 64

				if not weaponDef.paralyzer then
				end

				if weaponDef.paralyzer then
					radius = radius * 0.5
				end

				sizeclass = GetClosestSizeClass(radius)
				--projectileDefDistortions[weaponID] = GetDistortionClass("LaserProjectile", sizeclass, overrideTable)

				if not weaponDef.paralyzer then
					sizeclass = GetClosestSizeClass(radius)
				end

				if string.find(weaponDef.name, 'heat') then
					sizeclass = GetClosestSizeClass(radius * 0.25)
					projectileDefDistortions[weaponID] = GetDistortionClass("HeatRayHeat", sizeclass, overrideTable)
				end

			elseif weaponDef.type == 'LaserCannon' then

				sizeclass = GetClosestSizeClass(radius)
				projectileDefDistortions[weaponID] = GetDistortionClass("CannonProjectile", sizeclass, overrideTable)

			elseif weaponDef.type == 'DistortionningCannon' then
				--sizeclass = GetClosestSizeClass(33 + (radius*2.5))
				projectileDefDistortions[weaponID] = GetDistortionClass("LaserProjectile", sizeclass, overrideTable)

			elseif weaponDef.type == 'MissileLauncher'then
				projectileDefDistortions[weaponID] = GetDistortionClass("MissileProjectile", sizeclass, overrideTable)

			elseif weaponDef.type == 'StarburstLauncher' then
				projectileDefDistortions[weaponID] = GetDistortionClass("MissileProjectile", sizeclass, overrideTable)
				sizeclass = GetClosestSizeClass(radius)


			elseif weaponDef.type == 'Cannon' then

				-- if string.find(weaponDef.name, 'flak') then
				-- 	sizeclass = 0
				-- 	life = 0
				-- end
				--muzzleFlash = true
				sizeclass = GetClosestSizeClass(radius)
				--projectileDefDistortions[weaponID] = GetDistortionClass("CannonProjectile", sizeclass, overrideTable)
				
				


			elseif weaponDef.type == 'DGun' then
				muzzleFlash = true --doesnt work
				sizeclass = "Medium"

				projectileDefDistortions[weaponID] = GetDistortionClass("CannonProjectile", sizeclass, overrideTable)
				projectileDefDistortions[weaponID].yOffset = 32

			elseif weaponDef.type == 'TorpedoLauncher' then
				sizeclass = "Small"
				projectileDefDistortions[weaponID] = GetDistortionClass("TorpedoProjectile", sizeclass, overrideTable)

			elseif weaponDef.type == 'Shield' then
				sizeclass = "Large"
				projectileDefDistortions[weaponID] = GetDistortionClass("CannonProjectile", sizeclass, overrideTable)

			elseif weaponDef.type == 'AircraftBomb' then
				projectileDefDistortions[weaponID] = GetDistortionClass("AirBombProjectile", "Warm", sizeclass, overrideTable)

			elseif weaponDef.type == 'Flame' then
				--sizeclass = "Small"
				--sizeclass = GetClosestSizeClass(radius*3)
				projectileDefDistortions[weaponID] = GetDistortionClass("FlameProjectile", sizeclass, overrideTable)
			end

			-- Add a muzzle flash if needed:
			if muzzleFlash then
				local mymuzzleFlash

				if damage < 100 then
					--Spring.Echo("Skipping muzzle flash for low damage:", damage)
				elseif damage < 275 then
					mymuzzleFlash = GetDistortionClass("MuzzleShockWaveXS", GetClosestSizeClass(muzzleflashRadius * 0.7), overrideTable)
					--mymuzzleflash.yOffset = 10 --This does not seem to work
					--mymuzzleflash.distortionConfig.radius = radius * 0.6 --What does this do?
				elseif damage <= 500 then
					mymuzzleFlash = GetDistortionClass("MuzzleShockWave", GetClosestSizeClass(muzzleflashRadius ), overrideTable)
				else
					mymuzzleFlash = GetDistortionClass("MuzzleShockWaveXL", GetClosestSizeClass(muzzleflashRadius * 0.6), overrideTable)

				end
					muzzleFlashDistortions[weaponID] = { mymuzzleFlash } -- note that multiple distortions can be added
			end


			-- Add explosiondistortions if needed:
			if explosionDistortion then

				if weaponDef.type == 'DGun' then

				elseif weaponDef.type == 'Flame' then
					explosionDistortions[weaponID] = {GetDistortionClass("FireHeat", GetClosestSizeClass(radius), overrideTable)}
				
				elseif weaponDef.type == 'TorpedoLauncher' then
					explosionDistortions[weaponID] = {GetDistortionClass("TorpedoShockWave", GetClosestSizeClass(radius), overrideTable)}
		
				elseif weaponDef.type == 'BeamLaser' then
					sizeclass = GetClosestSizeClass(radius*0.15) -- works
					overrideTable = {lifeTime = 2} -- doesnt work

				elseif weaponDef.type == 'DistortionningCannon' then
					sizeclass = GetClosestSizeClass(radius*1.2)

				else
					if weaponDef.type == 'AircraftBomb' then
						if weaponDef.paralyzer then

						else
							explosionDistortions[weaponID] = {GetDistortionClass("AirShockWave", GetClosestSizeClass(radius), overrideTable)}
							explosionDistortions[weaponID] = {GetDistortionClass("GroundShockWave", GetClosestSizeClass(radius), overrideTable)}
							explosionDistortions[weaponID] = {GetDistortionClass("ExplosionHeat", GetClosestSizeClass(radius), overrideTable)}
						end
					end

					-- radius = ((weaponDef.damageAreaOfEffect*1.9) + (weaponDef.damageAreaOfEffect * weaponDef.edgeEffectiveness * 1.35))
					-- if string.find(weaponDef.name, 'juno') then
					-- 	radius = 675
					-- end

					-- UNIT explosions
					if weaponDef.customParams.unitexplosion then
						effectiveRangeExplo = effectiveRangeExplo * 2
						if effectiveRangeExplo < 24 then
							distortionClass = "UnitExploShockWaveXS"
						elseif effectiveRangeExplo < 48 then
							distortionClass = "UnitExploShockWaveS"
						elseif effectiveRangeExplo < 92 then
							distortionClass = "UnitExploShockWaveM"
						elseif effectiveRangeExplo < 184 then
							distortionClass = "UnitExploShockWaveL"
						else --
							distortionClass = "UnitExploShockWaveXL"
						end

						if string.find(weaponDef.name, 'wind') then
							effectiveRangeExplo = effectiveRangeExplo * 0.6
						end

					else	-- regular CANNON explosions
						if effectiveRangeExplo < 24 then
							distortionClass = "ExploShockWaveXS"
						elseif effectiveRangeExplo < 48 then
							distortionClass = "ExploShockWaveS"
						elseif effectiveRangeExplo < 92 then
							distortionClass = "ExploShockWaveM"
						elseif effectiveRangeExplo < 184 then
							distortionClass = "ExploShockWaveL"
						else --
							distortionClass = "ExploShockWaveXL"
						end
					end

					if string.find(weaponDef.name, 'flak') then
						areaofeffect = 0
					end
					
					-- Check weapon distortion class assignment (enter weapon name here)
					-- if string.find(weaponDef.name, 'cortruck_missile') then
					-- 	Spring.Echo('-==--===-', weaponDef.customParams.unitexplosion, distortionClass, effectiveRangeExplo, GetClosestSizeClass(effectiveRangeExplo), GetDistortionClass(distortionClass, GetClosestSizeClass(effectiveRangeExplo), overrideTable))
					-- end
					
					if not weaponDef.customParams.noexplosionlight and areaofeffect > 15 then --need to add noexplosiondistortion to units - now used same as lights
						explosionDistortions[weaponID] = {GetDistortionClass(distortionClass, GetClosestSizeClass(effectiveRangeExplo), overrideTable)}
					end

				end
			end
		end
		Spring.Echo(Spring.GetGameFrame(),"DLGL4 weapons conf using",usedclasses,"distortion types")
	end
	AssignDistortionsToAllWeapons() -- disable this if it doest work


-----------------Manual Overrides--------------------
local explosionDistortionsNames = {}
local muzzleFlashDistortionsNames = {}
local projectileDefDistortionsNames = {}


projectileDefDistortionsNames["armcom_disintegrator"] =
	--GetDistortionClass("ProjectileDgun", "Micro")
	GetDistortionClass("AirShockWaveDgun", "Micro")

projectileDefDistortionsNames["corjugg_juggernaut_fire"] =
	GetDistortionClass("AirShockWaveDgun", "Nano", {
		lifeTime = 40,
	})

explosionDistortionsNames['corjugg_juggernaut_fire'] = {
	--GetDistortionClass("GroundShockWave", "Smaller", {
	--	lifeTime = 24, }),
	--GetDistortionClass("AirShockWaveDgun", "Smaller"),
	GetDistortionClass("ExplosionRadiationDgun", "Micro"),
}

projectileDefDistortionsNames["cormort_cor_mort"] =
	GetDistortionClass("PlasmaTrailProjectile", "Small", {
		theta = 0.08, noiseStrength = 5, noiseScaleSpace = 0.88, distanceFalloff = 1.5,
		lifeTime = 60, rampUp = 15, decay = 0, effectStrength = 1.5,
		radius = 170, startRadius = 0.1, yoffset = 8,
	})
explosionDistortionsNames['cormort_cor_mort'] = {
	-- GetDistortionClass("GroundShockWave", "Pico", {
	-- 	lifeTime = 18, }),
	GetDistortionClass("AirShockWaveXS", "Femto", {
		lifeTime = 6, effectStrength = 4.5, }),
}

projectileDefDistortionsNames["armmav_armmav_weapon"] =
	GetDistortionClass("PlasmaTrailProjectile", "Smaller", {
	theta = 0.11, noiseStrength = 15, noiseScaleSpace = 0.55,
	lifeTime = 60, rampUp = 20, decay = 0, radius = 40,
})
explosionDistortionsNames['armmav_armmav_weapon'] = {
	GetDistortionClass("GroundShockWave", "Micro", {
		lifeTime = 19, effectStrength = 1.0,
	}),
}

explosionDistortionsNames['armemp_armemp_weapon'] = {
	GetDistortionClass("EMPShockWave", "Medium", {
	effectStrength = -2.5,
	}),
	GetDistortionClass("EMPNoise", "SmallMedium", {
	}),	
 	GetDistortionClass("EMPRipples", "Medium", {
	}),
	GetDistortionClass("AirShockWaveEMP", "Tiny", {
	}),
}

explosionDistortionsNames['armthor_empmissile'] = {
	GetDistortionClass("EMPShockWave", "Small", {
	effectStrength = -2.5,
	}),
	GetDistortionClass("EMPNoise", "Smallest", {
	}),	
 	GetDistortionClass("EMPRipples", "Small", {
	}),
	GetDistortionClass("AirShockWaveEMP", "Nano", {
	}),
}

explosionDistortionsNames['spybombx'] = {
	GetDistortionClass("EMPShockWave", "Medium", {
	effectStrength = -2.5,
	}),
	GetDistortionClass("EMPNoise", "SmallMedium", {
	}),	
 	GetDistortionClass("EMPRipples", "Medium", {
	}),
	GetDistortionClass("AirShockWaveEMP", "Tiny", {
	}),
}

explosionDistortionsNames['armstil_stiletto_bomb'] = {
	GetDistortionClass("EMPShockWave", "Smaller", {
	}),
	GetDistortionClass("EMPNoise", "Smaller", {
	}),	
 	GetDistortionClass("EMPRipples", "SmallMedium", {
	}),
	GetDistortionClass("AirShockWaveEMP", "Micro", {
	}),
}



-- OLD ACIDBOMB EXPLOSION DISTORTIONS
-- explosionDistortionsNames['raptor_air_bomber_acid_t2_v1_acidbomb'] = {
-- 	GetDistortionClass("GroundShockWave", "Smallish", {
-- 		noiseStrength = 15.0, noiseScaleSpace = 0.20, distanceFalloff = 0.9, onlyModelMap = 1,
-- 		lifeTime = 190, effectStrength = 2,
-- 		windAffected = -1, riseRate = 6,
-- 		rampUp = 20, decay = 15, shockWidth = 10,
-- 	}),
-- }

explosionDistortionsNames['raptor_air_bomber_acid_t2_v1_acidbomb'] = {
	GetDistortionClass("GroundAcidExplo", "SmallMedium", {
		-- noiseStrength = 15.0, noiseScaleSpace = 0.90, distanceFalloff = 0.9, onlyModelMap = 1,
		-- lifeTime = 190, effectStrength = 2,
		-- windAffected = -1, riseRate = 6,
		-- rampUp = 20, decay = 15, shockWidth = 10,
	}),
	GetDistortionClass("AirShockWave", "Smaller"),
}

explosionDistortionsNames['raptor_land_assault_acid_t2_v1_acidspit'] = {
	GetDistortionClass("GroundAcidExplo", "Medium", {
		-- noiseStrength = 15.0, noiseScaleSpace = 0.90, distanceFalloff = 0.9, onlyModelMap = 1,
		-- lifeTime = 190, effectStrength = 2,
		-- windAffected = -1, riseRate = 6,
		-- rampUp = 20, decay = 15, shockWidth = 10,
	}),
	--GetDistortionClass("AirShockWave", "Smaller"),
}

explosionDistortionsNames['raptor_allterrain_arty_acid_t2_v1_acidspit'] = {
	GetDistortionClass("GroundAcidExplo", "Medium", {
		noiseStrength = 0.9, noiseScaleSpace = 0.50, distanceFalloff = 0.9, 
		effectStrength = 1.7,
		--onlyModelMap = 1,
		-- lifeTime = 190, effectStrength = 2,
		-- windAffected = -1, riseRate = 6,
		-- rampUp = 20, decay = 15, shockWidth = 10,
	}),
	--GetDistortionClass("AirShockWave", "Smaller"),
}

explosionDistortionsNames['armjuno_juno_pulse'] = {
	-- GetDistortionClass("JunoHeat", "Juno", {
	-- 	pos2x = 0, pos2y = 0, pos2z = 0,
	-- 	noiseStrength = 6.5, noiseScaleSpace = 0.5, distanceFalloff = -0.1,
	-- 	lifeTime = 900, rampUp = 0, decay = 0, onlyModelMap = 0,
	-- }),
	GetDistortionClass("JunoShockWave", "Juno", {
	}),
	GetDistortionClass("JunoNoise", "Juno", {
	}),
	-- GetDistortionClass("GroundShockWave", "Larger", {
	-- 	noiseStrength = 5.0, noiseScaleSpace = 0.13, distanceFalloff = 0.1, onlyModelMap = 0,
	-- 	lifeTime = 35, effectStrength = -20,
	-- 	rampUp = 30, decay = 35, shockWidth = 14,
	-- }),
	-- GetDistortionClass("ExplosionHeat", "Juno", {
	-- 	noiseStrength = -1.5, noiseScaleSpace = 0.95, distanceFalloff = -0.05,
	-- 	effectStrength = 3.0, -- don't use, doesn't fade out correct
	-- 	windAffected = -1, riseRate = 9,
	-- 	lifeTime = 900, rampUp = 100, decay = 150, onlyModelMap = 1,
	-- }),

}

explosionDistortionsNames['corjuno_juno_pulse'] = {
	GetDistortionClass("JunoShockWave", "Juno", {
	}),
	GetDistortionClass("JunoNoise", "Juno", {
	}),
}

-- corlevlr
projectileDefDistortionsNames["corlevlr_corlevlr_weapon"] =
	GetDistortionClass("PlasmaTrailProjectile", "Smaller", {
	theta = 0.11, noiseStrength = 24, noiseScaleSpace = 0.55,
	lifeTime = 60, rampUp = 20, decay = 0, radius = 40, yoffset = 8,
})


explosionDistortionsNames["corlevlr_corlevlr_weapon"] = {
	GetDistortionClass("GroundShockWave", "Tiny", {
		lifeTime = 12, effectStrength = 1.5, startRadius = 0.40, shockWidth = 0.5,
	}),
	GetDistortionClass("AirShockWave", "Micro", {
		lifeTime = 14,
		effectStrength = 3.5,
	}),
	--GetDistortionClass("ExplosionHeatXS", "Nano"),
}

-- muzzleFlashDistortionsNames['corlevlr_corlevlr_weapon'] = {
-- 	GetDistortionClass("MuzzleShockWave", "Pico")
-- }

-- projectileDefDistortionsNames["armpw_emg"] =
-- 	GetDistortionClass("PlasmaTrailProjectile", "Smallest", {
-- 	theta = 0.11,noiseStrength = 4, noiseScaleSpace = 0.55,
-- 	lifeTime = 30, rampUp = 2, decay = 0, radius = 40, yoffset = 5,
-- })

-- projectileDefDistortionsNames["armpw_emg"] =
-- 	GetDistortionClass("CannonProjectile", "Zetto", {
-- 	noiseStrength = 1, noiseScaleSpace = 0.22,
-- 	effectStrength = 0.8,
-- 	lifeTime = 0, rampUp = 0, decay = 0, radius = 3, yoffset = 5,
-- })

muzzleFlashDistortionsNames['armguard_plasma'] = {
	GetDistortionClass("MuzzleShockWave", "Nano", {
		lifeTime = 8, effectStrength = 1.2,
	}),
}
muzzleFlashDistortionsNames['armguard_plasma_high'] = {
	GetDistortionClass("MuzzleShockWave", "Tiny")
}

-- muzzleFlashDistortionsNames['armepoch_mediumplasma'] = {
-- 	GetDistortionClass("MuzzleShockWave", "Micro")
-- }
-- muzzleFlashDistortionsNames['armepoch_heavyplasma'] = {
-- 	GetDistortionClass("MuzzleShockWaveXL", "Tiniest")
-- }
explosionDistortionsNames['armepoch_heavyplasma'] = {
	GetDistortionClass("AirShockWave", "Tiny"),
	GetDistortionClass("ExplosionHeat", "Micro"),
}

muzzleFlashDistortionsNames['corblackhy_heavyplasma'] = {
	GetDistortionClass("MuzzleShockWave", "Tiny")
}
explosionDistortionsNames['corblackhy_heavyplasma'] = {
	GetDistortionClass("AirShockWave", "Tiny"),
	GetDistortionClass("ExplosionHeat", "Micro"),
}

projectileDefDistortionsNames["cormaw_dmaw"] =
	GetDistortionClass("FlameProjectile", "Micro", {
		lifeTime = 42, rampUp = 30,
	})

projectileDefDistortionsNames["corpyro_flamethrower"] =
	GetDistortionClass("FlameProjectile", "Micro")

projectileDefDistortionsNames["cordemon_newdmaw"] =
	GetDistortionClass("FlameProjectileXL", "Smaller", {
		noiseStrength = 11, startRadius = 0.4, --noiseScaleSpace = 0.20,
		lifeTime = 55, rampUp = 15, decay = 60,
	})

projectileDefDistortionsNames["corcrwh_dragonmawh"] =
	GetDistortionClass("FlameProjectileXL", "Smaller", {
		noiseStrength = 11, startRadius = 0.4, --noiseScaleSpace = -0.20,
		lifeTime = 50, rampUp = 15, decay = 70,
	})

projectileDefDistortionsNames["corfship_dmaw"] =
	GetDistortionClass("FlameProjectile", "Tiny")

projectileDefDistortionsNames["corvipe_vipersabot"] =
GetDistortionClass("PlasmaTrailProjectile", "Smaller", {
	theta = 0.07, noiseStrength = 10, noiseScaleSpace = 0.35,
	lifeTime = 30, rampUp = 10, decay = 5, radius = 120,
	yoffset = 18,
})
explosionDistortionsNames['corvipe_vipersabot'] = {
	GetDistortionClass("GroundShockWaveXS", "Micro", {
		startRadius = 0.50, }),
	GetDistortionClass("AirShockWaveXS", "Pico", {
		lifeTime = 9, effectStrength = 0.8, }),
	GetDistortionClass("ExplosionHeatXS", "Nano"),
}

projectileDefDistortionsNames["armmship_rocket"] =
	GetDistortionClass("MissileProjectile", "Medium", {
		theta = 0.16, noiseStrength = 5, noiseScaleSpace = 0.35,
		windAffected = -1, riseRate = -0.5,
		lifeTime = 110, rampUp = 20, decay = 40, radius = 200, yoffset = 4,
	})



-- projectileDefDistortionsNames["armblade_vtol_sabot"] =
-- 	GetDistortionClass("MissileProjectile", "Smaller", {
-- 	theta = 0.07, noiseStrength = 3, noiseScaleSpace = 0.35,
-- 	lifeTime = 27, rampUp = 10, decay = 10, radius = 150,
-- })



projectileDefDistortionsNames["corkarg_super_missile"] =
	GetDistortionClass("MissileProjectile", "Smaller", {
	theta = 0.08, noiseStrength = 4, noiseScaleSpace = 0.37,
	lifeTime = 46, rampUp = 4, decay = 15, radius = 130, yoffset = 18,
	effectStrength = 1.2,
	startRadius = 0.5, onlyModelMap = 1,
})
explosionDistortionsNames['corkarg_super_missile'] = {
	GetDistortionClass("GroundShockWave", "Micro", {
		lifeTime = 24, }),
	GetDistortionClass("AirShockWaveXS", "Pico", {
		lifeTime = 16, effectStrength = 0.5, }),
}

projectileDefDistortionsNames["corhrk_corhrk_rocket"] =
	GetDistortionClass("MissileProjectile", "Smallest", {
	theta = 0.19, noiseStrength = 2, noiseScaleSpace = 0.47,
	lifeTime = 120, rampUp = 50, decay = 30, radius = 130, yoffset = 10,
	effectStrength = 1.3,
	startRadius = 0.5, onlyModelMap = 1,
})

projectileDefDistortionsNames["corstorm_cor_bot_rocket"] =
	GetDistortionClass("MissileProjectile", "Smallest")

projectileDefDistortionsNames["corban_banisher"] =
	GetDistortionClass("MissileProjectile", "Medium")

projectileDefDistortionsNames["armsubk_armsmart_torpedo"] =
	GetDistortionClass("TorpedoProjectile", "SmallMedium")

explosionDistortionsNames["armsubk_armsmart_torpedo"] = {
	GetDistortionClass("TorpedoShockWave", "Nano")}

-- projectileDefDistortionsNames['armmanni_atam'] =
-- 	GetDistortionClass("AirShockWaveBeam", "Small")

projectileDefDistortionsNames['armmanni_atam'] =
	GetDistortionClass("TachyonBeam", "Femto", {
		noiseStrength = 1, noiseScaleSpace = 0.03,
		windAffected = -0.8, riseRate = -0.2,
	})

projectileDefDistortionsNames['armanni_ata'] =
	GetDistortionClass("TachyonBeam", "Femto", {
		noiseStrength = 1.0, noiseScaleSpace = 0.04,
		windAffected = -0.9, riseRate = -0.2,
		--lifeTime = 0, rampUp = 20, decay = 0,
	})

projectileDefDistortionsNames['cordoom_atadr'] =
	GetDistortionClass("TachyonBeam", "Femto", {
		noiseStrength = 1.0, noiseScaleSpace = 0.04,
		windAffected = -0.9, riseRate = -0.2,
		--lifeTime = 0, rampUp = 20, decay = 0,
	})

-- original shield beam
	-- projectileDefDistortionsNames['armbanth_tehlazerofdewm'] =
	-- GetDistortionClass("TachyonBeam", "Femto", {
	-- 	noiseStrength = 1.5, noiseScaleSpace = 0.025,
	-- 	windAffected = -0.8, riseRate = -0.2,
	-- })

-- new concept armbanth
-- projectileDefDistortionsNames['armbanth_tehlazerofdewm'] =
-- 	GetDistortionClass("TachyonBeam2", "Atto", {
-- 	})

projectileDefDistortionsNames['armbanth_tehlazerofdewm'] =
GetDistortionClass("TachyonBeam3", "Banthlaser", {
})

projectileDefDistortionsNames["corhlt_cor_laserh1"] =
	GetDistortionClass("LaserBeamHeat", "Atto")

-- Heatrays should all get this class
projectileDefDistortionsNames["corsala_cor_heat_laser"] =
	GetDistortionClass("HeatRayHeat", "Atto")

projectileDefDistortionsNames["corkorg_corkorg_laser"] =
	GetDistortionClass("HeatRayHeatXL", "KorgLaser")

projectileDefDistortionsNames["armspid_spider"] = --doesnt work on lightning cannon
	GetDistortionClass("EMPBeam", "Quaco")

projectileDefDistortionsNames["armdfly_armdfly_paralyzer"] = --doesnt work on lightning cannon
	GetDistortionClass("EMPBeamXL", "Zetto")

projectileDefDistortionsNames["corbw_bladewing_lyzer"] = --doesnt work on lightning cannon
	GetDistortionClass("EMPBeam", "Quaco")

projectileDefDistortionsNames["armclaw_dclaw"] = --doesnt work on lightning cannon
	GetDistortionClass("LightningBeam", "Femto")

projectileDefDistortionsNames["armthor_emp"] = --doesnt work on lightning cannon
	GetDistortionClass("EMPBeam", "Quaco")

-- projectileDefDistortionsNames["armzeus_lightning"] = --doesnt work on lightning cannon
-- 	GetDistortionClass("LightningBeam", "Atto")

-- projectileDefDistortionsNames["armlship_lightning"] = --doesnt work on lightning cannon
-- 	GetDistortionClass("LightningBeam", "Femto")

projectileDefDistortionsNames["armthor_thunder"] = --doesnt work on lightning cannon
	GetDistortionClass("LightningBeam", "Pico")

muzzleFlashDistortionsNames['armthor_thunder'] = {
	GetDistortionClass("MuzzleShockWave", "Micro")
}

-- explosionDistortionsNames['armbull_arm_bull'] = {
-- 	--GetDistortionClass("GroundShockWave", "Smallest"),
-- 	GetDistortionClass("AirShockWave", "Tiny") --original is Tiny
-- 	--GetDistortionClass("ExplosionHeatXS", "Nano"),
-- }

muzzleFlashDistortionsNames['armbull_arm_bull'] = {
	GetDistortionClass("MuzzleShockWave", "Femto")
}

explosionDistortionsNames['cortrem_tremor_spread_fire'] = {
	GetDistortionClass("AirShockWaveXS", "Micro", {
		lifeTime = 6, effectStrength = 2.5,
		decay = 4, rampUp = 1,
		shockWidth = -0.60,
		startRadius = 0.66, }),
	-- GetDistortionClass("GroundShockWave", "Tiny", {
	-- 	lifeTime = 12, }),
	--GetDistortionClass("ExplosionHeat", "Pico"),
}

-- explosionDistortionsNames['unitDeaths_windboom'] = {
-- 	--GetDistortionClass("GroundShockWave", "Smallest"),
-- 	GetDistortionClass("AirShockWaveXS", "Tiny"),
-- 	GetDistortionClass("ExplosionHeatXS", "Nano"),
-- }

explosionDistortionsNames['armthund_armbomb'] = {
	GetDistortionClass("AirShockWave", "Nano", {
		lifeTime = 15, effectStrength = 1.6, }),
	GetDistortionClass("GroundShockWave", "Tiny", {
		lifeTime = 12, }),
	GetDistortionClass("ExplosionHeat", "Pico"),
}

explosionDistortionsNames['legphoenix_skybeam'] = {
	--GetDistortionClass("AirShockWave", "Small"),
	GetDistortionClass("GroundShockWave", "Smallest"),
	--GetDistortionClass("ExplosionHeat", "Tiniest"),
}

explosionDistortionsNames['legphoenix_legphtarg'] = {
	--GetDistortionClass("AirShockWave", "Small"),
}

explosionDistortionsNames['corscreamer_cor_advsam'] = {
	GetDistortionClass("AirShockWave", "Small"),
}

explosionDistortionsNames['armmercury_arm_advsam'] = {
	GetDistortionClass("AirShockWave", "Small"),
}

projectileDefDistortionsNames["legphoenix_legphtarg"] = 
	GetDistortionClass("NoEffect", 0)

explosionDistortionsNames['armfboy_arm_fatboy_notalaser'] = {
	GetDistortionClass("AirShockWave", "Small"),
	--GetDistortionClass("GroundShockWave", "SmallMedium"),
	GetDistortionClass("ExplosionHeat", "Tiniest"),
}

explosionDistortionsNames['armliche_arm_pidr'] = {
	GetDistortionClass("GroundShockWaveNuke", "Larger", {
		shockWidth = 8,
	}),
	-- GetDistortionClass("AirShockWaveNukeBlast", "Mediumer", {
	-- 	lifeTime = 25, effectStrength = 1.2,
	-- 	refractiveIndex = -1.03, }),
	GetDistortionClass("AirShockWave", "Medium", {
		lifeTime = 15, effectStrength = 16.0,
		refractiveIndex = 1.1, }),
	GetDistortionClass("ExplosionHeatNuke", "Medium", {
		noiseScaleSpace = 0.1, noiseStrength = 9,
		lifeTime = 80, decay = 25, rampUp = 50,
		}),
}

explosionDistortionsNames['armlichet4_nuclear_missile'] = {
	GetDistortionClass("ExplosionHeatNuke", "Larger"),
	GetDistortionClass("AirShockWaveNuke", "Armnuke"),
	GetDistortionClass("GroundShockWaveNuke", "Armnuke"),
}

explosionDistortionsNames['commanderexplosion'] = {
	GetDistortionClass("ExplosionHeatNuke", "Large"),
	GetDistortionClass("AirShockWaveNuke", "Large", {
		lifeTime = 80, decay = 25, rampUp = 50,
		effectStrength = 10.0,
		refractiveIndex = 1.25, shockWidth = -0.5,
		}),
	GetDistortionClass("GroundShockWaveNuke", "Mega"),
}

explosionDistortionsNames['armsilo_nuclear_missile'] = {
	GetDistortionClass("ExplosionHeatNuke", "Larger"),
	GetDistortionClass("AirShockWaveNuke", "Armnuke"),
	GetDistortionClass("GroundShockWaveNuke", "Armnuke"),
	-- GetDistortionClass("GroundShockWaveNuke", "Giga"),
	-- GetDistortionClass("AirShockWaveNukeBlast", "MegaXXL"),
	-- GetDistortionClass("AirShockWaveNuke", "MegaXL"),
	-- GetDistortionClass("ExplosionHeatNuke", "Larger"),
}

projectileDefDistortionsNames["armsilo_nuclear_missile"] = --armnuke
	GetDistortionClass("MissileNukeProjectile", "Large")

explosionDistortionsNames['customfusionexplo'] = {
	GetDistortionClass("ExplosionHeatNuke", "Larger"),
	GetDistortionClass("AirShockWaveNuke", "Armnuke", {
		lifeTime = 20, decay = 15, rampUp = 5,
		effectStrength = 10.0,
		}),
	GetDistortionClass("GroundShockWaveNuke", "Armnuke", {
		lifeTime = 50, decay = 40, rampUp = 10,
		}),
}

explosionDistortionsNames['crawl_blastsmlscavboss'] = {
	GetDistortionClass("ExplosionHeatNuke", "MegaXL", {
		lifeTime = 30, decay = 20, rampUp = 10,
		--effectStrength = 1.0,
		--refractiveIndex = 1.25,
		}),
	GetDistortionClass("AirShockWaveNuke", "Cornuke", {
		lifeTime = 120, decay = 25, rampUp = 10,
		effectStrength = 15.0,
		refractiveIndex = 1.25,
		}),
	GetDistortionClass("GroundShockWaveNuke", "Planetary", {
		lifeTime = 220, decay = 100, rampUp = 50,
		effectStrength = 3.0, startRadius = 0.10,
		shockWidth = 32,
		}),
}

explosionDistortionsNames['korgexplosion'] = {
	GetDistortionClass("ExplosionHeatNuke", "Larger"),
	GetDistortionClass("AirShockWaveNuke", "Armnuke"),
	GetDistortionClass("GroundShockWaveNuke", "Armnuke"),
}

explosionDistortionsNames['korgexplosionselfd'] = {
	GetDistortionClass("ExplosionHeatNuke", "Mega"),
	GetDistortionClass("AirShockWaveNuke", "Cornuke"),
	GetDistortionClass("GroundShockWaveNuke", "Cornuke"),
}	

explosionDistortionsNames['advancedfusionexplosionselfd'] = {
	GetDistortionClass("ExplosionHeatNuke", "Mega"),
	GetDistortionClass("AirShockWaveNuke", "Cornuke"),
	GetDistortionClass("GroundShockWaveNuke", "Cornuke"),
}	

explosionDistortionsNames['corsilo_crblmssl'] = {
	GetDistortionClass("ExplosionHeatNuke", "Mega"),
	GetDistortionClass("AirShockWaveNuke", "Cornuke"),
	GetDistortionClass("GroundShockWaveNuke", "Cornuke"),
	-- GetDistortionClass("GroundShockWaveNuke", "Giga"),
	-- GetDistortionClass("AirShockWaveNukeBlast", "MegaXXL"),
	-- GetDistortionClass("AirShockWaveNuke", "MegaXL"),
	-- GetDistortionClass("ExplosionHeatNuke", "Larger"),
}

projectileDefDistortionsNames["corsilo_crblmssl"] = --armnuke
	GetDistortionClass("MissileNukeProjectile", "Large")

-- RAPTOR meteor Nuke Tentacle
explosionDistortionsNames['raptor_turret_meteor_t4_v1_weapon'] = {
		GetDistortionClass("ExplosionHeatNuke", "Mega"),
		GetDistortionClass("AirShockWaveNuke", "Cornuke"),
		GetDistortionClass("GroundShockWaveNuke", "Cornuke"),
	}

explosionDistortionsNames['nuketest_nuketest'] = {
	GetDistortionClass("ExplosionHeatNuke", "Larger"),
	GetDistortionClass("AirShockWaveNuke", "Armnuke"),
	GetDistortionClass("GroundShockWaveNuke", "Armnuke"),
}

explosionDistortionsNames['nuketestcor_nuketestcor'] = {
	GetDistortionClass("ExplosionHeatNuke", "Mega"),
	GetDistortionClass("AirShockWaveNuke", "Cornuke"),
	GetDistortionClass("GroundShockWaveNuke", "Cornuke"),
}

explosionDistortionsNames['armguardnuke_plasma'] = {
	GetDistortionClass("ExplosionHeatNuke", "Larger"),
	GetDistortionClass("AirShockWaveNuke", "Armnuke"),
	GetDistortionClass("GroundShockWaveNuke", "Armnuke"),
	--GetDistortionClass("ExplosionRadiationNuke", "Larger"), --no use yet
	--GetDistortionClass("AirShockWaveNukeBlast", "MegaXXL"),

}
projectileDefDistortionsNames["armguardnuke_plasma"] = --armnuke
	GetDistortionClass("MissileNukeProjectile", "Large")

projectileDefDistortionsNames["armguardnuke_plasma_high"] = --armnuke
	GetDistortionClass("MissileNukeProjectile", "Large")

explosionDistortionsNames['armguardnuke_plasma_high'] = { --cornuke
	GetDistortionClass("ExplosionHeatNuke", "Mega"),
	--GetDistortionClass("GroundShockWave", "Medium"),
	GetDistortionClass("AirShockWaveNuke", "Cornuke"),
	GetDistortionClass("GroundShockWaveNuke", "Cornuke"),
	--GetDistortionClass("ExplosionHeat", "Smallest"),
}

explosionDistortionsNames['cortron_cortron_weapon'] = {
	GetDistortionClass("GroundShockWaveNuke", "MediumLarge"),
	GetDistortionClass("AirShockWaveNuke", "SmallMedium"),
	GetDistortionClass("ExplosionHeatNuke", "Medium"),
}

-- muzzleFlashDistortionsNames['armstump_arm_lightcannon'] = {
-- 	GetDistortionClass("MuzzleShockWaveXS", "Atto", {

-- 	})
--}
-- explosionDistortionsNames['armstump_arm_lightcannon'] = {
-- 	GetDistortionClass("AirShockWaveXS", "Atto", {
-- 		lifeTime = 14, refractiveIndex = 1.03, decay = 3,
-- 		shockWidth = -0.5, effectStrength = 1.5,
-- 		startRadius = 0.3,}),
	-- GetDistortionClass("GroundShockWave", "Atto", {
	-- 	shockWidth = 2.5, startRadius = 0.2,
	-- }),
	-- GetDistortionClass("ExplosionHeat", "Atto"),
	--GetDistortionClass("ExplosionDistort", "Atto"),
--}

explosionDistortionsNames['corgol_cor_gol'] = {
	GetDistortionClass("AirShockWave", "Small"),
	--GetDistortionClass("GroundShockWave", "SmallMedium"),
	GetDistortionClass("ExplosionHeat", "Tiniest"),
}

-- explosionDistortionsNames['corgol_cor_gol'] = {
-- 	GetDistortionClass("AirShockWave", "Small", {
-- 		lifeTime = 14, refractiveIndex = 1.03, decay = 3,
-- 		shockWidth = -0.5, effectStrength = 2.5,
-- 		startRadius = 0.3,}),
-- 	GetDistortionClass("GroundShockWave", "Smallish", {
-- 		shockWidth = 2.5, startRadius = 0.2,
-- 	}),
-- 	--GetDistortionClass("ExplosionHeat", "Tiniest"),
-- }
-- muzzleFlashDistortionsNames['corgol_cor_gol'] = {
-- 	GetDistortionClass("MuzzleShockWave", "Nano", {
-- 		lifeTime = 12
-- 	})
-- }

-- explosionDistortionsNames['corshiva_shiva_gun'] = {
-- 	GetDistortionClass("AirShockWave", "Smallish", {
-- 		lifeTime = 25, refractiveIndex = 1.1, decay = 3,
-- 		shockWidth = 0.5, effectStrength =  3.0, startRadius = 0.3}),
-- 	GetDistortionClass("GroundShockWave", "Smallest"),
-- 	GetDistortionClass("ExplosionHeat", "Smallest", {
-- 		lifeTime = 40, decay = 10, rampup = 5, startRadius = 50}),
-- }

explosionDistortionsNames['corcat_exp_heavyrocket'] = {
	GetDistortionClass("AirShockWave", "Smallest", {
		lifeTime = 8, effectStrength = 1.0,
		shockWidth = 0.50,
	}),
	GetDistortionClass("GroundShockWave", "Smaller", {
		lifeTime = 10, shockWidth = 1.5, startRadius = 0.2,}),
	-- GetDistortionClass("ExplosionHeat", "Micro", {
	-- 	lifeTime = 50,
	-- }),
}

muzzleFlashDistortionsNames['armmav_armmav_weapon'] = {
	GetDistortionClass("MuzzleShockWave", "Atto")
}
muzzleFlashDistortionsNames['corint_lrpc'] = {
	GetDistortionClass("MuzzleShockWaveXL", "Tiny")
}
explosionDistortionsNames['corint_lrpc'] = {
	GetDistortionClass("AirShockWave", "Smaller", {
		lifeTime = 11, refractiveIndex = -1.5, decay = 4,
		shockWidth = -0.5, effectStrength =  1.0,
		startRadius = 0.3}),
	GetDistortionClass("GroundShockWave", "Smallest"),
	GetDistortionClass("ExplosionHeat", "Smallest", {
		lifeTime = 80, decay = 40, rampup = 5}),
}
muzzleFlashDistortionsNames['armbrtha_lrpc'] = {
	GetDistortionClass("MuzzleShockWaveXL", "Tiny")
}
explosionDistortionsNames['armbrtha_lrpc'] = {
	GetDistortionClass("ExploShockWaveXL", "Smaller", {
		--lifeTime = 11, refractiveIndex = -1.5, decay = 4,
		--shockWidth = -0.5, effectStrength =  1.0,
		startRadius = 0.3}),
	GetDistortionClass("GroundShockWave", "Smallest"),
	GetDistortionClass("ExplosionHeat", "Smallest", {
		lifeTime = 80, decay = 40, rampup = 5}),
}

muzzleFlashDistortionsNames['corbuzz_rflrpc'] = {
	GetDistortionClass("MuzzleShockWaveXL", "Tiny", {
		lifeTime = 18, effectStrength = 4.0, startRadius = 0.35,
		decay = 7, rampUp = 1,
	})
}
projectileDefDistortionsNames["corbuzz_rflrpc"] =
GetDistortionClass("PlasmaTrailProjectile", "Smallish", {
	theta = 0.09, noiseStrength = 15, noiseScaleSpace = 0.12, radius = 380,
	distanceFalloff = 2.2, effectStrength = 3.8,
})
explosionDistortionsNames['corbuzz_rflrpc'] = {
	GetDistortionClass("AirShockWave", "Smaller", {
		lifeTime = 9, refractiveIndex = -1.5, decay = 4,
		shockWidth = -0.5, effectStrength =  1.0,
		startRadius = 0.3}),
	GetDistortionClass("GroundShockWave", "Smallest"),
	GetDistortionClass("ExplosionHeat", "Smallest", {
		lifeTime = 80, decay = 40, rampup = 5}),
}

-- muzzleFlashDistortionsNames['armvulc_rflrpc'] = {
-- 	GetDistortionClass("MuzzleShockWaveXL", "Tiniest", {
-- 		lifeTime = 14, effectStrength = 4.0, startRadius = 0.30,
-- 		decay = 8, rampUp = 3, shockWidth = -0.55,
-- 	})
-- }
projectileDefDistortionsNames["armvulc_rflrpc"] =
GetDistortionClass("PlasmaTrailProjectile", "Smallish", {
	theta = 0.09, noiseStrength = 5, noiseScaleSpace = 0.4, radius = 380,
	distanceFalloff = 0.9,
})
explosionDistortionsNames['armvulc_rflrpc'] = {
	GetDistortionClass("ExploShockWaveL", "Smaller", {
		--lifeTime = 9, refractiveIndex = -1.5, decay = 4,
		--shockWidth = -0.5, effectStrength =  1.0,
		startRadius = 0.1}),
	GetDistortionClass("GroundShockWave", "Smallest"),
	GetDistortionClass("ExplosionHeat", "Smallest", {
		lifeTime = 80, decay = 40, rampup = 5}),
}

local scavbosses = {
	"veryeasy",
	"easy",
	"normal",
	"hard",
	"veryhard",
	"epic",
	"veryeasy_scav",
	"easy_scav",
	"normal_scav",
	"hard_scav",
	"veryhard_scav",
	"epic_scav",
 }

for i, name in pairs(scavbosses) do
    muzzleFlashDistortionsNames['scavengerbossv4_' .. name .. '_shoulderturrets'] = {
        GetDistortionClass("MuzzleShockWave", "Nano")
    }
	muzzleFlashDistortionsNames['scavengerbossv4_' .. name .. '_turbo_shoulderturrets'] = {
        GetDistortionClass("MuzzleShockWave", "Tiny")
    }
	explosionDistortionsNames['scavengerbossv4_' .. name .. '_missilelauncher'] = {
        GetDistortionClass("AirShockWave", "Smallest")
    }
	explosionDistortionsNames['scavengerbossv4_' .. name .. '_turbo_missilelauncher'] = {
        GetDistortionClass("AirShockWave", "Smaller")
    }
end


-- convert weaponname -> weaponDefID
for name, distortionList in pairs(explosionDistortionsNames) do
	if WeaponDefNames[name] then
		explosionDistortions[WeaponDefNames[name].id] = distortionList
	end
end
explosionDistortionsNames = nil
-- convert weaponname -> weaponDefID
for name, distortionList in pairs(muzzleFlashDistortionsNames) do
	if WeaponDefNames[name] then
		muzzleFlashDistortions[WeaponDefNames[name].id] = distortionList
	end
end
muzzleFlashDistortionsNames = nil
-- convert weaponname -> weaponDefID
for name, params in pairs(projectileDefDistortionsNames) do
	if WeaponDefNames[name] then
		projectileDefDistortions[WeaponDefNames[name].id] = params
	end
end
projectileDefDistortionsNames = nil


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Projectile Collection
return {muzzleFlashDistortions = muzzleFlashDistortions, projectileDefDistortions = projectileDefDistortions, explosionDistortions = explosionDistortions, gibDistortion = gibDistortion}
