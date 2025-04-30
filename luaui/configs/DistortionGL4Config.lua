-- This file contains all the unit-attached distortions
-- Including cob-animated distortions, like thruster attached ones, and fusion glows
-- Searchdistortions also go here
-- As well as muzzle glow should also go here
-- nanolasers should also be here
-- (c) Beherith (mysterme@gmail.com)


local exampleDistortion = {
	distortionType = 'point', -- or cone or beam
	-- if pieceName == nil then the distortion is treated as WORLD-SPACE
	-- if pieceName == valid piecename, then the distortion is attached to that piece
	-- if pieceName == invalid piecename, then the distortion is attached to base of unit
	pieceName = nil,
	-- If you want to make the distortion be offset from the top of the unit, specify how many elmos above it should be!
	aboveUnit = nil,
	-- Distortions that should spawn even if they are outside of view need this set:
	alwaysVisible = nil,
	distortionConfig = {
		posx = 0, posy = 0, posz = 0, radius = 100,
		-- cone distortions only, specify direction and half-angle in radians:
			dirx = 0, diry = 0, dirz = 1, theta = 0.5,
		-- beam distortions only, specifies the endpoint of the beam:
			pos2x = 100, pos2y = 100, pos2z = 100,
		lifeTime = 0, sustain = 1, 	selfshadowing = 0 
	},
}
 
-- multiple distortions per unitdef/piece are possible, as the distortions are keyed by distortionname

local unitDistortions = {

	-- ['armsolar'] = {
	-- 	distortion = {
	-- 		distortionType = 'point',
	-- 		pieceName = 'emit',
	-- 		distortionConfig = { posx = 0, posy = 2, posz = 0, radius = 33,
	-- 						noiseStrength = 0.5, noiseScaleSpace = 1.5, distanceFalloff = 2.0,
	-- 						lifeTime = 0,  rampUp = 300, decay = -2.0,
	-- 						effectType = 0},
	-- 	},
	-- },

	['armcom'] = {
		distortion = {
			distortionType = 'point',
			pieceName = 'biggun',
			distortionConfig = { posx = 0, posy = -12, posz = -1, radius = 4.3,
							noiseStrength = 0.8, noiseScaleSpace = 1.8, distanceFalloff = 0.5,
							lifeTime = 0, rampUp = 30, decay = -1.2,
							effectType = 0},
		},
	},
	['corcom'] = {
		distortion = {
			distortionType = 'point',
			pieceName = 'biggun',
			distortionConfig = { posx = 0, posy = -4.9, posz = 16, radius = 2.7,
							noiseStrength = 2, noiseScaleSpace = -1.6, distanceFalloff = 0.5,
							windAffected = -0.5, onlyModelMap = -1,
							lifeTime = 0,  effectType = 0},
		},
	},
	['armmakr'] = {
		distortion = {
			distortionType = 'point',
			pieceName = 'light',
			distortionConfig = { posx = 0, posy = -2, posz = 0, radius = 18,
							noiseStrength = 0.6, noiseScaleSpace = 1.5, distanceFalloff = 0.5,
							lifeTime = 0, rampUp = 30, decay = -1.2,
							effectType = 0},
		},
	},
	['cormakr'] = {
		distortion = {
			distortionType = 'point',
			pieceName = 'light',
			distortionConfig = { posx = 0, posy = 3, posz = 0, radius = 16,
							noiseStrength = 0.6, noiseScaleSpace = 1.5, distanceFalloff = 0.5,
							lifeTime = 0, rampUp = 30, decay = -1.2,
							effectType = 0},
		},
	},
	['armmmkr'] = {
		distortion = {
			distortionType = 'point',
			pieceName = 'light',
			distortionConfig = { posx = 0, posy = -3, posz = 0, radius = 24,
							noiseStrength = 0.5, noiseScaleSpace = 1.4, distanceFalloff = 0.5,
							lifeTime = 0, rampUp = 30, decay = -1.2,
							effectType = 0},
		},
	},
	['cormmkr'] = {
		distortion = {
			distortionType = 'point',
			pieceName = 'light',
			distortionConfig = { posx = 0, posy = -1, posz = 0, radius = 18,
							noiseStrength = 0.5, noiseScaleSpace = 1.4, distanceFalloff = 0.5,
							lifeTime = 0, rampUp = 30, decay = -1.2,
							effectType = 0},
		},
	},
	['armestor'] = {
		distortion = {
			distortionType = 'beam',
			pieceName = 'base',
			distortionConfig = { posx = 0, posy = -6.5, posz = 0.01, radius = 23,
								pos2x = 0, pos2y = 15, pos2z = 0, radius2 = 23, 
								noiseStrength = 0.5, noiseScaleSpace = -1, distanceFalloff = 0.8,
								rampUp = 30, decay = -1.2,
								lifeTime = 0,  effectType = 0},
		},
	},
	['armvang'] = {
		distortion = {
			distortionType = 'beam',
			pieceName = 'base',
			distortionConfig = { posx = 2.0, posy = 5, posz = -12, radius = 2.4,
								pos2x = -2.0, pos2y = 5, pos2z = -12, radius2 = 23, 
								noiseStrength = 0.7, noiseScaleSpace = -2, distanceFalloff = 0.8,
								rampUp = 30, decay = 0,
								lifeTime = 0,  effectType = 0},
		},
	},
	['corcat'] = {
		distortionl = {
			distortionType = 'point',
			pieceName = 'lturret',
			distortionConfig = { posx = 14, posy = 13, posz = 3, radius = 5,
								noiseStrength = 0.7, noiseScaleSpace = -2, distanceFalloff = 0.8,
								rampUp = 30, decay = 0,
								lifeTime = 0,  effectType = 0},
		},
		distortionr = {
			distortionType = 'point',
			pieceName = 'rturret',
			distortionConfig = { posx = -14, posy = 13, posz = 3, radius = 5,
								noiseStrength = 0.7, noiseScaleSpace = -2, distanceFalloff = 0.8,
								rampUp = 30, decay = 0,
								lifeTime = 0,  effectType = 0},
		},
	},
	['armthor'] = {
		distortionbackenergy = {
			distortionType = 'beam',
			pieceName = 'base',
			distortionConfig = { posx = -4, posy = 14, posz = -25, radius = 9,
								pos2x = 4, pos2y = 14, pos2z = -25,
								noiseStrength = 0.5, noiseScaleSpace = -1.5, distanceFalloff = 0.8,
								rampUp = 30, decay = 5,
								lifeTime = 0,  effectType = 0},
		},
		distortionbarrell = {
			distortionType = 'beam',
			pieceName = 'ltbarrel',
			distortionConfig = { posx = 0, posy = 0, posz = -8, radius = 6,
								pos2x = 0, pos2y = 0, pos2z = -9,
								noiseStrength = 0.7, noiseScaleSpace = -2.5, distanceFalloff = 0.8,
								rampUp = 0, decay = 0,
								lifeTime = 0,  effectType = 0},
		},
		distortionbarrelr = {
			distortionType = 'beam',
			pieceName = 'rtbarrel',
			distortionConfig = { posx = 0, posy = 0, posz = -8, radius = 6,
								pos2x = 0, pos2y = 0, pos2z = -9,
								noiseStrength = 0.7, noiseScaleSpace = -2.5, distanceFalloff = 0.8,
								rampUp = 0, decay = 0,
								lifeTime = 0,  effectType = 0},
		},
	},
	['armlship'] = {
		distortion1 = {
			distortionType = 'beam',
			pieceName = 'turret',
			distortionConfig = { posx = 3, posy = 9.0, posz = 0, radius = 2,4,
								pos2x = 3, pos2y = 9.0, pos2z = -5,
								noiseStrength = 0.5, noiseScaleSpace = -2, distanceFalloff = 0.8,
								rampUp = 30, decay = -1.2,
								lifeTime = 0,  effectType = 0},
		},
		distortion2 = {
			distortionType = 'beam',
			pieceName = 'turret',
			distortionConfig = { posx = -3, posy = 9.0, posz = 0, radius = 2.4,
								pos2x = -3, pos2y = 9.0, pos2z = -5,
								noiseStrength = 0.5, noiseScaleSpace = -2, distanceFalloff = 0.8,
								rampUp = 30, decay = -1.2,
								lifeTime = 0,  effectType = 0},
		},
	},
	['corfship'] = {
		distortionflame = {
			distortionType = 'beam',
			pieceName = 'sleeve',
			distortionConfig = { posx = 0, posy = 0, posz = 22, radius = 4,
								pos2x = 0, pos2y = 0, pos2z = 19,
								noiseStrength = 0.5, noiseScaleSpace = -2, distanceFalloff = 0.8,
								rampUp = 0, decay = -1.5,
								lifeTime = 0,  effectType = 0},
		},
	},
	['armantiship'] = {
		distortionback1 = {
			distortionType = 'beam',
			pieceName = 'base',
			distortionConfig = { posx = -10, posy = 10, posz = -50, radius = 13,
								pos2x = 10, pos2y = 10, pos2z = -50.1, radius2 = 23, 
								noiseStrength = 0.5, noiseScaleSpace = -1, distanceFalloff = 0.8,
								rampUp = 30, decay = -1.2,
								lifeTime = 0,  effectType = 0},
		},
		distortionback2 = {
			distortionType = 'beam',
			pieceName = 'base',
			distortionConfig = { posx = -10, posy = 10, posz = -33, radius = 13,
								pos2x = 10, pos2y = 10, pos2z = -33, radius2 = 23, 
								noiseStrength = 0.5, noiseScaleSpace = -1, distanceFalloff = 0.8,
								rampUp = 30, decay = -1.2,
								lifeTime = 0,  effectType = 0},
		},
	},

	['armuwadves'] = {
		distortion1 = {
			distortionType = 'beam',
			pieceName = 'emit1',
			distortionConfig = { posx = 0, posy = -20, posz = 0.01, radius = 20,
								pos2x = 0, pos2y = -5, pos2z = 0,
								noiseStrength = 0.5, noiseScaleSpace = -1, distanceFalloff = 0.8,
								rampUp = 30, decay = -1.2,
								lifeTime = 0,  effectType = 0},
		},
		distortion2 = {
			distortionType = 'beam',
			pieceName = 'emit2',
			distortionConfig = { posx = 0, posy = -20, posz = 0.01, radius = 20,
								pos2x = 0, pos2y = -5, pos2z = 0,
								noiseStrength = 0.5, noiseScaleSpace = -1, distanceFalloff = 0.8,
								rampUp = 30, decay = -1.2,
								lifeTime = 0,  effectType = 0},
		},
	},

	['corestor'] = {
		distortion = {
			distortionType = 'beam',
			pieceName = 'base',
			distortionConfig = { posx = 0, posy = 0, posz = 0.01, radius = 28,
								pos2x = 0, pos2y = 20, pos2z = 0, radius2 = 28, 
								noiseStrength = 0.7, noiseScaleSpace = -1.3, distanceFalloff = 0.8,
								rampUp = 30, decay = -1.2,
								lifeTime = 0,  effectType = 0},

		},
	},

	['coruwadves'] = {
		distortion = {
			distortionType = 'beam',
			pieceName = 'base',
			distortionConfig = { posx = 0, posy = 0, posz = 0.01, radius = 40,
								pos2x = 0, pos2y = 25, pos2z = 0, radius2 = 40, 
								noiseStrength = 0.5, noiseScaleSpace = -1.4, distanceFalloff = 0.8,
								rampUp = 30, decay = -1.3,
								lifeTime = 0,  effectType = 0},

		},
	},

	['armguard'] = {
		sleeve1 = {
			distortionType = 'beam',
			pieceName = 'sleeves',
			distortionConfig = { posx = 3.5, posy = 2, posz = 16.3, radius = 5,
								pos2x = 3.5, pos2y = 2, pos2z = 9,
								noiseStrength = 0.5, noiseScaleSpace = -1, distanceFalloff = 0.8,
								rampUp = 30, decay = -2,
								lifeTime = 0,  effectType = 0},
		},
		sleeve2 = {
			distortionType = 'beam',
			pieceName = 'sleeves',
			distortionConfig = { posx = -3.5, posy = 2, posz = 16.3, radius = 5,
								pos2x = -3.5, pos2y = 2, pos2z = 9,
								noiseStrength = 0.5, noiseScaleSpace = -1, distanceFalloff = 0.8,
								rampUp = 30, decay = -2,
								lifeTime = 0,  effectType = 0},
		},
	},

	['armbull'] = {
		distortion = {
			distortionType = 'point',
			pieceName = 'base',
			distortionConfig = { posx = 0, posy = 20, posz = -10, radius = 20,
							noiseStrength = 0.3, noiseScaleSpace = -2, distanceFalloff = 1.4,
							lifeTime = 0,  effectType = 'heatDistortion'},
		},
	},

	['armvp'] = {
		heatvent1 = {
			distortionType = 'beam',
			pieceName = 'base',
			distortionConfig = { posx = -32,  posy = 26,  posz = -11.5, radius = 5,
							    pos2x = -32, pos2y = 32, pos2z = -11.4,
							noiseStrength = 0.4, noiseScaleSpace = -3, distanceFalloff = 1.4,
							windAffected = -1, riseRate = 1,
							lifeTime = 0, effectType = 'heatDistortion'},
		},
		heatvent2 = {
			distortionType = 'beam',
			pieceName = 'base',
			distortionConfig = { posx = -32,  posy = 26,  posz = -35.5, radius = 5,
							    pos2x = -32, pos2y = 32, pos2z = -35.4,
							noiseStrength = 0.4, noiseScaleSpace = -3, distanceFalloff = 1.4,
							windAffected = -1, riseRate = 1,
							lifeTime = 0, effectType = 'heatDistortion'},
		},
		heatvent3 = {
			distortionType = 'beam',
			pieceName = 'base',
			distortionConfig = { posx = 32,  posy = 26,  posz = -11.5, radius = 5,
							    pos2x = 32, pos2y = 32, pos2z = -11.4,
							noiseStrength = 0.4, noiseScaleSpace = -3, distanceFalloff = 1.4,
							windAffected = -1, riseRate = 1,
							lifeTime = 0, effectType = 'heatDistortion'},
		},
		heatvent4 = {
			distortionType = 'beam',
			pieceName = 'base',
			distortionConfig = { posx = 32,  posy = 26,  posz = -35.5, radius = 5,
							    pos2x = 32, pos2y = 32, pos2z = -35.4,
							noiseStrength = 0.4, noiseScaleSpace = -3, distanceFalloff = 1.4,
							windAffected = -1, riseRate = 1,
							lifeTime = 0, effectType = 'heatDistortion'},
		},
	},

	['corhal'] = {
		heatventfront1 = {
			distortionType = 'beam',
			pieceName = 'base',
			distortionConfig = { posx = -13,  posy = -3,  posz = 12, radius = 7,
							    pos2x = -13, pos2y = 4, pos2z = 12.1,
							noiseStrength = 0.4, noiseScaleSpace = -2, distanceFalloff = 1.4,
							windAffected = -1, riseRate = 1,
							lifeTime = 0, effectType = 'heatDistortion'},
		},
		heatventfront2 = {
			distortionType = 'beam',
			pieceName = 'base',
			distortionConfig = { posx = 13,  posy = -3,  posz = 12, radius = 7,
							    pos2x = 13, pos2y = 4, pos2z = 12.1,
							noiseStrength = 0.4, noiseScaleSpace = -2, distanceFalloff = 1.4,
							windAffected = -1, riseRate = 1,
							lifeTime = 0, effectType = 'heatDistortion'},
		},
	},

	['corvp'] = {
		heatvent1 = {
			distortionType = 'beam',
			pieceName = 'base',
			distortionConfig = { posx = -7,  posy = 30,  posz = -32.5, radius = 12,
							    pos2x = 7, pos2y = 30, pos2z = -32.4,
							noiseStrength = 0.5, noiseScaleSpace = -2, distanceFalloff = 1.4,
							windAffected = -1, riseRate = 1,
							lifeTime = 0, effectType = 'heatDistortion'},
		},
		heatventfront1 = {
			distortionType = 'beam',
			pieceName = 'base',
			distortionConfig = { posx = -25.5,  posy = 15,  posz = 46.5, radius = 5,
							    pos2x = -25.5, pos2y = 24, pos2z = 51.4,
							noiseStrength = 0.4, noiseScaleSpace = -3, distanceFalloff = 1.4,
							windAffected = -1, riseRate = 1,
							lifeTime = 0, effectType = 'heatDistortion'},
		},
		heatventfront2 = {
			distortionType = 'beam',
			pieceName = 'base',
			distortionConfig = { posx = 25.5,  posy = 15,  posz = 46.5, radius = 5,
							    pos2x = 25.5, pos2y = 24, pos2z = 51.4,
							noiseStrength = 0.4, noiseScaleSpace = -3, distanceFalloff = 1.4,
							windAffected = -1, riseRate = 1,
							lifeTime = 0, effectType = 'heatDistortion'},
		},
		-- heatvent3 = {
		-- 	distortionType = 'beam',
		-- 	pieceName = 'base',
		-- 	distortionConfig = { posx = 32,  posy = 26,  posz = -11.5, radius = 5,
		-- 					    pos2x = 32, pos2y = 32, pos2z = -11.4,
		-- 					noiseStrength = 0.4, noiseScaleSpace = -3, distanceFalloff = 1.4,
		-- 					windAffected = -1, riseRate = 1,
		-- 					lifeTime = 0, effectType = 'heatDistortion'},
		-- },
		-- heatvent4 = {
		-- 	distortionType = 'beam',
		-- 	pieceName = 'base',
		-- 	distortionConfig = { posx = 32,  posy = 26,  posz = -35.5, radius = 5,
		-- 					    pos2x = 32, pos2y = 32, pos2z = -35.4,
		-- 					noiseStrength = 0.4, noiseScaleSpace = -3, distanceFalloff = 1.4,
		-- 					windAffected = -1, riseRate = 1,
		-- 					lifeTime = 0, effectType = 'heatDistortion'},
		-- },
	},

	['armsd'] = {
		distortion = {
			distortionType = 'point',
			pieceName = 'base',
			distortionConfig = { posx = 0, posy = 18, posz = -24.5, radius = 9,
							noiseStrength = 0.6, noiseScaleSpace = -2, distanceFalloff = 1,
							windAffected = -1, riseRate = 1,
							lifeTime = 0,  effectType = 'heatDistortion'},
		},
	},

	['armanac'] = {
		fanheat1 = {
			distortionType = 'point',
			pieceName = 'base',
			distortionConfig = { posx = -8, posy = 6.5, posz = -5, radius = 2.3,
							noiseStrength = 0.4, noiseScaleSpace = -8, distanceFalloff = 1,
							windAffected = -1, riseRate = 1,
							lifeTime = 0,  effectType = 'heatDistortion'},
		},
		fanheat2 = {
			distortionType = 'point',
			pieceName = 'base',
			distortionConfig = { posx = 8, posy = 6.5, posz = -5, radius = 2.3,
							noiseStrength = 0.4, noiseScaleSpace = -8, distanceFalloff = 1,
							windAffected = -1, riseRate = 1,
							lifeTime = 0,  effectType = 'heatDistortion'},
		},
		fanheat3 = {
			distortionType = 'point',
			pieceName = 'base',
			distortionConfig = { posx = -8, posy = 6.5, posz = 4, radius = 2.3,
							noiseStrength = 0.4, noiseScaleSpace = -8, distanceFalloff = 1,
							windAffected = -1, riseRate = 1,
							lifeTime = 0,  effectType = 'heatDistortion'},
		},
		fanheat4 = {
			distortionType = 'point',
			pieceName = 'base',
			distortionConfig = { posx = 8, posy = 6.5, posz = 4, radius = 2.3,
							noiseStrength = 0.4, noiseScaleSpace = -8, distanceFalloff = 1,
							windAffected = -1, riseRate = 1,
							lifeTime = 0,  effectType = 'heatDistortion'},
		},
	},

	['armgeo'] = {
		fanheat = {
			distortionType = 'point',
			pieceName = 'base',
			distortionConfig = { posx = 0, posy = 50, posz = -5, radius = 20,
							noiseStrength = 0.5, noiseScaleSpace = -2, distanceFalloff = 1.4,
							lifeTime = 0,  effectType = 'heatDistortion'},
		},
		barrell = {
			distortionType = 'point',
			pieceName = 'hotl',
			distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 6,
							noiseStrength = 0.9, noiseScaleSpace = -1.7, distanceFalloff = 1.4,
							lifeTime = 0,  effectType = 'heatDistortion'},
		},
		barrelr = {
			distortionType = 'point',
			pieceName = 'hotr',
			distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 6,
							noiseStrength = 0.9, noiseScaleSpace = -1.7, distanceFalloff = 1.4,
							lifeTime = 0,  effectType = 'heatDistortion'},
		},
	},
	['armgmm'] = {
		fanheat = {
			distortionType = 'point',
			pieceName = 'base',
			distortionConfig = { posx = 0, posy = 30, posz = 0, radius = 16,
							noiseStrength = 0.5, noiseScaleSpace = -2, distanceFalloff = 1.4,
							lifeTime = 0,  effectType = 'heatDistortion'},
		},
	},
	['armageo'] = {
		storageheatcenter = {
			distortionType = 'beam',
			pieceName = 'base',
			distortionConfig = { posx = 0, posy = 30, posz = 0, radius = 12,
								pos2x = 0, pos2y = 45, pos2z = 0.1, 
								noiseStrength = 0.5, noiseScaleSpace = -1.4, distanceFalloff = 0.8,
								rampUp = 30, decay = 0,
								lifeTime = 0,  effectType = 0},
		},
		storageheat1 = {
			distortionType = 'beam',
			pieceName = 'base',
			distortionConfig = { posx = 0, posy = 5, posz = 34, radius = 17,
								pos2x = 0, pos2y = 35, pos2z = 34.1, 
								noiseStrength = 0.6, noiseScaleSpace = -1.4, distanceFalloff = 0.8,
								rampUp = 30, decay = -1.2,
								lifeTime = 0,  effectType = 0},
		},
		storageheat2 = {
			distortionType = 'beam',
			pieceName = 'base',
			distortionConfig = { posx = -29, posy = 5, posz = -16, radius = 17,
								pos2x = -29, pos2y = 35, pos2z = -16.1, 
								noiseStrength = 0.6, noiseScaleSpace = -1.4, distanceFalloff = 0.8,
								rampUp = 30, decay = -1.2,
								lifeTime = 0,  effectType = 0},
		},
		storageheat3 = {
			distortionType = 'beam',
			pieceName = 'base',
			distortionConfig = { posx = 29, posy = 5, posz = -16, radius = 17,
								pos2x = 29, pos2y = 35, pos2z = -16.1, 
								noiseStrength = 0.6, noiseScaleSpace = -1.4, distanceFalloff = 0.8,
								rampUp = 30, decay = -1.2,
								lifeTime = 0,  effectType = 0},
		},
	},
	['corkarg'] = {
		engineheatr = {
			distortionType = 'point',
			pieceName = 'turret',
			distortionConfig = { posx = -24.4, posy = 13, posz = 10.5, radius = 4,
							noiseStrength = 0.5, noiseScaleSpace = 2, distanceFalloff = 0.8,
							windAffected = -0.5, riseRate = -2,
							lifeTime = 0,  effectType = 'heatDistortion'},
		},
		engineheatl = {
			distortionType = 'point',
			pieceName = 'turret',
			distortionConfig = { posx = 24.4, posy = 13, posz = 10.5, radius = 4,
							noiseStrength = 0.5, noiseScaleSpace = 2, distanceFalloff = 0.8,
							windAffected = -0.5, riseRate = -2,
							lifeTime = 0,  effectType = 'heatDistortion'},
		},
	},

	['corkorg'] = {
		engineheatr = {
			distortionType = 'point',
			pieceName = 'ruparm',
			distortionConfig = { posx = -10, posy = -2, posz = -17, radius = 10,
							noiseStrength = 0.7, noiseScaleSpace = 2, distanceFalloff = 0.8,
							windAffected = -0.5, riseRate = -2,
							lifeTime = 0,  effectType = 'heatDistortion'},
		},
		engineheatl = {
			distortionType = 'point',
			pieceName = 'luparm',
			distortionConfig = { posx = 10, posy = -2, posz = -17, radius = 10,
							noiseStrength = 0.7, noiseScaleSpace = 2, distanceFalloff = 0.8,
							windAffected = -0.5, riseRate = -2,
							lifeTime = 0,  effectType = 'heatDistortion'},
		},
	},
	['armadvsol'] = {
		-- magnifier = {
		-- 	distortionType = 'point',
		-- 	pieceName = 'base',
		-- 	distortionConfig = { posx = 0, posy = 25, posz = 0, radius = 20,
		-- 					lifeTime = 0,  
		-- 					magnificationRate = 4.0, effectType = "magnifier"}, 
		-- },
	},

	['armhawk'] = {
		thrust = {
			distortionType = 'cone',
			pieceName = 'thrust',
			distortionConfig = { posx = 0, posy = -1, posz = 20, radius = 120,
							dirx =  0, diry = -0, dirz = -1.0, theta = 0.05,
							noiseStrength = 2, noiseScaleSpace = 0.85, distanceFalloff = 2.0,
							effectStrength = 15.0,
							lifeTime = 0,  effectType = 0},
		},
	},

	['armblade'] = {
		thrustdown = {
			distortionType = 'cone',
			pieceName = 'trust',
			distortionConfig = { posx = 0, posy = 4, posz = 4, radius = 40,
							dirx = 0, diry = -1, dirz = 0.1, theta = 0.8,
							noiseStrength = 0.7, noiseScaleSpace = 1.45, distanceFalloff = 1.0,
							effectStrength = 1.5,
							riseRate = -8, lifeTime = 0,  effectType = 0},
		},
	},

	['armbrawl'] = {
		thrustdown = {
			distortionType = 'point',
			pieceName = 'fan',
			distortionConfig = { posx = 0, posy = -11, posz = 0, radius = 10,
							noiseStrength = 0.7, noiseScaleSpace = -1.45, distanceFalloff = 1.2,
							effectStrength = 1.5,
							riseRate = -6, lifeTime = 0,  effectType = 0},
		},
	},

	['armstil'] = {
		thrusta = {
			distortionType = 'cone',
			pieceName = 'thrusta',
			distortionConfig = { posx = 0, posy = -1, posz = 20, radius = 120,
							dirx =  0, diry = -0, dirz = -1.0, theta = 0.05,
							noiseStrength = 2, noiseScaleSpace = 0.85, distanceFalloff = 2.0,
							effectStrength = 3.0,
							lifeTime = 0,  effectType = 0},
		},
		thrustb = {
			distortionType = 'cone',
			pieceName = 'thrustb',
			distortionConfig = { posx = 0, posy = -1, posz = 20, radius = 120,
							dirx =  0, diry = -0, dirz = -1.0, theta = 0.05,
							noiseStrength = 2, noiseScaleSpace = 0.85, distanceFalloff = 2.0,
							effectStrength = 3.0,
							lifeTime = 0,  effectType = 0},
		},
	},

	['armdfly'] = {
		thrust1 = {
			distortionType = 'cone',
			pieceName = 'thrustb',
			distortionConfig = { posx = -19.8, posy = 5, posz = 64.3, radius = 40,
							dirx = 0, diry = -1, dirz = 0.1, theta = 0.8,
							noiseStrength = 1, noiseScaleSpace = 0.65, distanceFalloff = 1.0,
							effectStrength = 1.2,
							riseRate = -8, lifeTime = 0,  effectType = 0},
		},
		thrust2 = {
			distortionType = 'cone',
			pieceName = 'thrusta',
			distortionConfig = { posx = 19.8, posy = 5, posz = 64.3, radius = 40,
							dirx = 0, diry = -1, dirz = 0.1, theta = 0.8,
							noiseStrength = 1, noiseScaleSpace = 0.65, distanceFalloff = 1.0,
							effectStrength = 1.2,
							riseRate = -8, lifeTime = 0,  effectType = 0},
		},
		thrust3 = {
			distortionType = 'cone',
			pieceName = 'thrustb',
			distortionConfig = { posx = -19.8, posy = 5, posz = 34, radius = 40,
							dirx = 0, diry = -1, dirz = 0.1, theta = 0.8,
							noiseStrength = 1, noiseScaleSpace = 0.65, distanceFalloff = 1.0,
							effectStrength = 1.2,
							riseRate = -8, lifeTime = 0,  effectType = 0},
		},
		thrust4 = {
			distortionType = 'cone',
			pieceName = 'thrusta',
			distortionConfig = { posx = 19.8, posy = 5, posz = 34, radius = 40,
							dirx = 0, diry = -1, dirz = 0.1, theta = 0.8,
							noiseStrength = 1, noiseScaleSpace = 0.65, distanceFalloff = 1.0,
							effectStrength = 1.2,
							riseRate = -8, lifeTime = 0,  effectType = 0},
		},
	},

	['armawac'] = {
		thrust = {
			distortionType = 'cone',
			pieceName = 'thrust',
			distortionConfig = { posx = 0, posy = -1, posz = 20, radius = 120,
							dirx =  0, diry = -0, dirz = -1.0, theta = 0.05,
							noiseStrength = 2, noiseScaleSpace = 0.85, distanceFalloff = 2.0,
							effectStrength = 3.0,
							lifeTime = 0,  effectType = 0},
		},
	},

	['armpnix'] = {
		thrusta = {
			distortionType = 'cone',
			pieceName = 'thrusta',
			distortionConfig = { posx = 0, posy = -1, posz = 20, radius = 130,
							dirx =  0, diry = -0, dirz = -1.0, theta = 0.06,
							noiseStrength = 2, noiseScaleSpace = 0.85, distanceFalloff = 2.0,
							effectStrength = 10.0,
							lifeTime = 0,  effectType = 0},
		},
		thrustb = {
			distortionType = 'cone',
			pieceName = 'thrustb',
			distortionConfig = { posx = 0, posy = -1, posz = 20, radius = 130,
							dirx =  0, diry = -0, dirz = -1.0, theta = 0.06,
							noiseStrength = 2, noiseScaleSpace = 0.85, distanceFalloff = 2.0,
							effectStrength = 10.0,
							lifeTime = 0,  effectType = 0},
		},
	},

	['armliche'] = {
		engineheata = {
			distortionType = 'point',
			pieceName = 'wing1',
			distortionConfig = { posx = 0, posy = 0, posz = -24, radius = 3.5,
							noiseStrength = 0.8, noiseScaleSpace = 3, distanceFalloff = 0.8,
							windAffected = 1, riseRate = 0.5,
							lifeTime = 0,  effectType = 'heatDistortion'},
		},
		engineheatb = {
			distortionType = 'point',
			pieceName = 'wing2',
			distortionConfig = { posx = 0, posy = 0, posz = -24, radius = 3.5,
							noiseStrength = 0.8, noiseScaleSpace = 3, distanceFalloff = 0.8,
							windAffected = 1, riseRate = 0.5,
							lifeTime = 0,  effectType = 'heatDistortion'},
		},
		engineheatc = {
			distortionType = 'point',
			pieceName = 'base',
			distortionConfig = { posx = 0, posy = 9, posz = -21, radius = 3.5,
							noiseStrength = 0.8, noiseScaleSpace = 3, distanceFalloff = 0.8,
							windAffected = 1, riseRate = 0.5,
							lifeTime = 0,  effectType = 'heatDistortion'},
		},
		thrusta = {
			distortionType = 'cone',
			pieceName = 'thrusta',
			distortionConfig = { posx = 0, posy = -1, posz = -25, radius = 120,
							dirx =  0, diry = -0, dirz = -1.0, theta = 0.09,
							noiseStrength = 2, noiseScaleSpace = 0.85, distanceFalloff = 2.0,
							effectStrength = 3.0,
							lifeTime = 0,  effectType = 0},
		},
		thrustb = {
			distortionType = 'cone',
			pieceName = 'thrustb',
			distortionConfig = { posx = 0, posy = -1, posz = -25, radius = 120,
							dirx =  0, diry = -0, dirz = -1.0, theta = 0.09,
							noiseStrength = 2, noiseScaleSpace = 0.85, distanceFalloff = 2.0,
							effectStrength = 3.0,
							lifeTime = 0,  effectType = 0},
		},
		thrustc = {
			distortionType = 'cone',
			pieceName = 'thrustc',
			distortionConfig = { posx = 0, posy = -1, posz = 0, radius = 100,
							dirx =  0, diry = -0, dirz = -1.0, theta = 0.09,
							noiseStrength = 2, noiseScaleSpace = 0.85, distanceFalloff = 2.0,
							effectStrength = 3.0,
							lifeTime = 0,  effectType = 0},
		},
	},

	['armtide'] = {
		waterflow = {
			distortionType = 'beam',
			pieceName = 'wheel',
			distortionConfig = { posx = 0, posy = -2.2, posz = -18, radius = 12,
								pos2x = 0, pos2y = -2.2, pos2z = 18, radius2 = 12, 
								noiseStrength = 2.5, noiseScaleSpace = 0.7, distanceFalloff = 0.75,
								rampUp = 0, decay = 0,
								windAffected = -1, riseRate = 1,
								lifeTime = 0,  effectType = 0},

		},
	},

	['cortide'] = {
		waterflow = {
			distortionType = 'beam',
			pieceName = 'wheel',
			distortionConfig = { posx = 0, posy = -2.2, posz = -10, radius = 22,
								pos2x = 0, pos2y = -2.2, pos2z = 10, 
								noiseStrength = 2.5, noiseScaleSpace = 0.7, distanceFalloff = 0.75,
								rampUp = 0, decay = 0,
								windAffected = -1, riseRate = 1,
								lifeTime = 0,  effectType = 0},

		},
	},

	['corvamp'] = {
		thrust = {
			distortionType = 'cone',
			pieceName = 'thrust',
			distortionConfig = { posx = 0, posy = 0, posz = 20, radius = 100,
							dirx =  0, diry = -0, dirz = -1.0, theta = 0.15,
							noiseStrength = 2, noiseScaleSpace = 0.75,
							lifeTime = 0,  effectType = 0},
		},
	},

	['armpeep'] = {
		thrust1 = {
			distortionType = 'cone',
			pieceName = 'jet1',
			distortionConfig = { posx = 0, posy = 0, posz = 5, radius = 130,
							dirx =  0, diry = -0, dirz = -1.0, theta = 0.08,
							noiseStrength = 3, noiseScaleSpace = 0.85, distanceFalloff = 1.9,
							effectStrength = 3.0,
							lifeTime = 0,  effectType = 0},
		},
		thrust2 = {
			distortionType = 'cone',
			pieceName = 'jet2',
			distortionConfig = { posx = 0, posy = 0, posz = 5, radius = 130,
							dirx =  0, diry = -0, dirz = -1.0, theta = 0.08,
							noiseStrength = 2, noiseScaleSpace = 0.85, distanceFalloff = 1.9,
							effectStrength = 3.0,
							lifeTime = 0,  effectType = 0},
		},
	},

	-- ['armpeep'] = {
	-- 	motionBlur = {
	-- 		distortionType = 'point',
	-- 		pieceName = 'base',
	-- 		distortionConfig = { posx = 0, posy = 7.5, posz = 0.01, radius = 23,
	-- 						pos2x = 0, pos2y = 100, pos2z = 0,
	-- 						noiseScaleSpace = 1, onlyModelMap = -1,
	-- 						lifeTime = 0,  effectType = 11},
	-- 	},
	-- },

	-- ['armck'] = {
	-- 	beamDistortion = {
	-- 		distortionType = 'beam',
	-- 		pieceName = 'base',
	-- 		distortionConfig = { posx = 0, posy = 7.5, posz = 0.01, radius = 23,
	-- 						pos2x = 0, pos2y = 100, pos2z = 0, radius2 = 23, 
	-- 						noiseScaleSpace = 1,
	-- 						lifeTime = 0,  effectType = 0},
	-- 	},
	-- },
	-- ['corck'] = {
	-- 	beamDistortion = {
	-- 		distortionType = 'beam',
	-- 		pieceName = 'base',
	-- 		distortionConfig = { posx = 0, posy = 7.5, posz = 0.01, radius = 23,
	-- 						pos2x = 0, pos2y = 100, pos2z = 0, radius2 = 23, 
	-- 						noiseScaleSpace = -1,
	-- 						lifeTime = 0,  effectType = 0},
	-- 	},
	-- },

	['armsnipe'] = {
		-- snipecloakbeam = {
		-- 	distortionType = 'point',
		-- 	pieceName = 'head',
		-- 	distortionConfig = { posx = 0, posy = 0, posz = 3, radius = 5,
		-- 					--pos2x = 0, pos2y = 30, pos2z = 0, radius2 = 15, 
							
		-- 					noiseStrength = 3, noiseScaleSpace = -1.5, distanceFalloff = 0.75, onlyModelMap = -1,
		-- 					lifeTime = 0,  effectType = 0},
		-- },
	},

	['armamex'] = {
		cloakbeam = {
			distortionType = 'beam',
			pieceName = 'base',
			distortionConfig = { posx = 0, posy = 34, posz = 0.01, radius = 20,
							pos2x = 0, pos2y = 35, pos2z = 0,
							windAffected = -1, riseRate = -0.5,
							noiseStrength = 2, noiseScaleSpace = 1, distanceFalloff = 0.25, onlyModelMap = -1,
							lifeTime = 0,  effectType = 0},
		},
	},

	['corvroc'] = {
		cloakblobf = {
			distortionType = 'point',
			pieceName = 'base',
			distortionConfig = { posx = 5.5, posy = 20.6, posz = 22.7, radius = 2.0,
							lifeTime = 0,  
							magnificationRate = 1.2, effectType = "magnifier"}, 
		},
		cloakmodule1 = {
			distortionType = 'point',
			pieceName = 'base',
			distortionConfig = { posx = 5, posy = 18.5, posz = -10.2, radius = 6.0,
							noiseStrength = 3, noiseScaleSpace = 1.5, distanceFalloff = 0.75, onlyModelMap = -1,
							lifeTime = 0,  effectType = 0},
		},
		-- cloakmodule2 = {
		-- 	distortionType = 'point',
		-- 	pieceName = 'base',
		-- 	distortionConfig = { posx = -16, posy = 14.5, posz = 10.7, radius = 5.0,
		-- 					noiseStrength = 3, noiseScaleSpace = 1.5, distanceFalloff = 0.75, onlyModelMap = -1,
		-- 					lifeTime = 0,  effectType = 0},
		-- },
		-- cloakmodule3 = {
		-- 	distortionType = 'point',
		-- 	pieceName = 'base',
		-- 	distortionConfig = { posx = 16, posy = 14.5, posz = -10.7, radius = 5.0,
		-- 					noiseStrength = 3, noiseScaleSpace = 1.5, distanceFalloff = 0.75, onlyModelMap = -1,
		-- 					lifeTime = 0,  effectType = 0},
		-- },
		-- cloakmodule4 = {
		-- 	distortionType = 'point',
		-- 	pieceName = 'base',
		-- 	distortionConfig = { posx = -16, posy = 14.5, posz = -10.7, radius = 5.0,
		-- 					noiseStrength = 3, noiseScaleSpace = 1.5, distanceFalloff = 0.75, onlyModelMap = -1,
		-- 					lifeTime = 0,  effectType = 0},
		-- },
	},

	['armrectr'] = {
		cloakmodule = {
			distortionType = 'point',
			pieceName = 'base',
			distortionConfig = { posx = 0, posy = 27.0, posz = -6.7, radius = 3.3,
							noiseStrength = 3, noiseScaleSpace = 2.5, distanceFalloff = 0.75, onlyModelMap = -1,
							lifeTime = 0,  effectType = 0},
		},
	},

	['cornecro'] = {
		cloakmodule = {
			distortionType = 'point',
			pieceName = 'base',
			distortionConfig = { posx = 0, posy = 18.4, posz = -4.2, radius = 3.0,
							noiseStrength = 3, noiseScaleSpace = 2.5, distanceFalloff = 0.75, onlyModelMap = -1,
							lifeTime = 0,  effectType = 0},
		},
	},

	['armmerl'] = {
		cloakblobf = {
			distortionType = 'point',
			pieceName = 'base',
			distortionConfig = { posx = 6.5, posy = 16.2, posz = 23.7, radius = 2.0,
							lifeTime = 0,  
							magnificationRate = 1.2, effectType = "magnifier"}, 
		},
		-- cloakblobb = {
		-- 	distortionType = 'point',
		-- 	pieceName = 'base',
		-- 	distortionConfig = { posx = 6.5, posy = 16.2, posz = -23.7, radius = 2.0,
		-- 					lifeTime = 0,  
		-- 					magnificationRate = 1.6, effectType = "magnifier"}, 
		-- },
		cloakmodule1 = {
			distortionType = 'point',
			pieceName = 'base',
			distortionConfig = { posx = 16, posy = 14.5, posz = 10.7, radius = 5.0,
							noiseStrength = 3, noiseScaleSpace = 1.5, distanceFalloff = 0.75, onlyModelMap = -1,
							lifeTime = 0,  effectType = 0},
		},
		cloakmodule2 = {
			distortionType = 'point',
			pieceName = 'base',
			distortionConfig = { posx = -16, posy = 14.5, posz = 10.7, radius = 5.0,
							noiseStrength = 3, noiseScaleSpace = 1.5, distanceFalloff = 0.75, onlyModelMap = -1,
							lifeTime = 0,  effectType = 0},
		},
		cloakmodule3 = {
			distortionType = 'point',
			pieceName = 'base',
			distortionConfig = { posx = 16, posy = 14.5, posz = -10.7, radius = 5.0,
							noiseStrength = 3, noiseScaleSpace = 1.5, distanceFalloff = 0.75, onlyModelMap = -1,
							lifeTime = 0,  effectType = 0},
		},
		cloakmodule4 = {
			distortionType = 'point',
			pieceName = 'base',
			distortionConfig = { posx = -16, posy = 14.5, posz = -10.7, radius = 5.0,
							noiseStrength = 3, noiseScaleSpace = 1.5, distanceFalloff = 0.75, onlyModelMap = -1,
							lifeTime = 0,  effectType = 0},
		},
	},

	['armmlv'] = {
		cloakblob = {
			distortionType = 'point',
			pieceName = 'turret',
			distortionConfig = { posx = 0, posy = 3, posz = 15, radius = 1.8,
							lifeTime = 0,  
							magnificationRate = 0.6, effectType = "magnifier"}, 
		},
		cloakblobdistort = {
			distortionType = 'point',
			pieceName = 'turret',
			distortionConfig = { posx = 0, posy = 3, posz = 15, radius = 1.9,
							noiseStrength = 3, noiseScaleSpace = 1.5, distanceFalloff = 0.75,
							lifeTime = 0,  effectType = 0},
		},

	},

	['armgremlin'] = {
		cloakblobf = {
			distortionType = 'point',
			pieceName = 'base',
			distortionConfig = { posx = 0, posy = 2.8, posz = 10.2, radius = 1.8,
							lifeTime = 0,  
							magnificationRate = 0.6, effectType = "magnifier"}, 
		},
		cloakblobb = {
			distortionType = 'point',
			pieceName = 'base',
			distortionConfig = { posx = 0, posy = 2.8, posz = -10.2, radius = 1.8,
							lifeTime = 0,  
							magnificationRate = 1.6, effectType = "magnifier"}, 
		},
		-- cloakblobsleeve = {
		-- 	distortionType = 'point',
		-- 	pieceName = 'sleeve',
		-- 	distortionConfig = { posx = 0, posy = 2.8, posz = 0, radius = 2.8,
		-- 					lifeTime = 0,  
		-- 					magnificationRate = 1.6, effectType = "magnifier"}, 
		-- },
		-- cloakblobfdistort = { 
		-- 	distortionType = 'point',
		-- 	pieceName = 'base',
		-- 	distortionConfig = { posx = 0, posy = 2.8, posz = 10.2, radius = 2.5,
		-- 					noiseStrength = 3, noiseScaleSpace = 1.5, distanceFalloff = 0.75,
		-- 					lifeTime = 0,  effectType = 0},
		-- },
		-- cloakblobbdistort = {
		-- 	distortionType = 'point',
		-- 	pieceName = 'base',
		-- 	distortionConfig = { posx = 0, posy = 2.8, posz = -10.2, radius = 2.5,
		-- 					noiseStrength = 3, noiseScaleSpace = 1.5, distanceFalloff = 0.75,
		-- 					lifeTime = 0,  effectType = 0},
		-- },
		-- cloakblobsleevedistort = {
		-- 	distortionType = 'point',
		-- 	pieceName = 'sleeve',
		-- 	distortionConfig = { posx = 0, posy = 2.8, posz = 0, radius = 2.8,
		-- 					noiseStrength = 3, noiseScaleSpace = 1.5, distanceFalloff = 0.75,
		-- 					lifeTime = 0,  effectType = 0},
		-- },
		cloakmodule1 = {
			distortionType = 'point',
			pieceName = 'blleg',
			distortionConfig = { posx = 2.5, posy = 4.5, posz = -3.7, radius = 4.0,
							noiseStrength = 3, noiseScaleSpace = -1.5, distanceFalloff = 0.75, onlyModelMap = -1,
							windAffected = -1, riseRate = -0.5,
							lifeTime = 0,  effectType = 0},
		},
		cloakmodule2 = {
			distortionType = 'point',
			pieceName = 'frleg',
			distortionConfig = { posx = -5.0, posy = 4.5, posz = 3.7, radius = 4.0,
							noiseStrength = 3, noiseScaleSpace = -1.5, distanceFalloff = 0.75, onlyModelMap = -1,
							windAffected = -1, riseRate = -0.5,
							lifeTime = 0,  effectType = 0},
		},
		cloakmodule3 = {
			distortionType = 'point',
			pieceName = 'brleg',
			distortionConfig = { posx = -5.0, posy = 4.5, posz = -3.7, radius = 4.0,
							noiseStrength = 3, noiseScaleSpace = -1.5, distanceFalloff = 0.75, onlyModelMap = -1,
							windAffected = -1, riseRate = -0.5,
							lifeTime = 0,  effectType = 0},
		},
		cloakmodule4 = {
			distortionType = 'point',
			pieceName = 'flleg',
			distortionConfig = { posx = 5.0, posy = 4.5, posz = 3.7, radius = 4.0,
							noiseStrength = 3, noiseScaleSpace = -1.5, distanceFalloff = 0.75, onlyModelMap = -1,
							windAffected = -1, riseRate = -0.5,
							lifeTime = 0,  effectType = 0},
		},
	},

	['armspy'] = {
		-- fullstealth = {
		-- 	distortionType = 'point',
		-- 	pieceName = 'body',
		-- 	distortionConfig = { posx = 0, posy = -10, posz = 0, radius = 20,
		-- 					noiseStrength = 3, noiseScaleSpace = -1.7, distanceFalloff = 0.5, onlyModelMap = -1,
		-- 					windAffected = -1, riseRate = -1.2,
		-- 					lifeTime = 0,  effectType = 0},
		-- },
		spycloakhead = {
			distortionType = 'point',
			pieceName = 'body',
			distortionConfig = { posx = -0.3, posy = 5.7, posz = 13, radius = 4.4,
							noiseStrength = 12, noiseScaleSpace = -1.7, distanceFalloff = 0.75, onlyModelMap = -1,
							windAffected = -1, riseRate = -0.5,
							lifeTime = 0,  effectType = 0},
		},
		spycloakpelvisr = {
			distortionType = 'point',
			pieceName = 'pelvis',
			distortionConfig = { posx = -6.0, posy = 0, posz = 0, radius = 3.0,
							noiseStrength = 24, noiseScaleSpace = -1.5, distanceFalloff = 0.75, onlyModelMap = -1,
							windAffected = -1, riseRate = -0.5,
							lifeTime = 0,  effectType = 0},
		},
		spycloakpelvisl = {
			distortionType = 'point',
			pieceName = 'pelvis',
			distortionConfig = { posx = 5.0, posy = 0, posz = 0, radius = 3.0,
							noiseStrength = 24, noiseScaleSpace = -1.5, distanceFalloff = 0.75, onlyModelMap = -1,
							windAffected = -1, riseRate = -0.5,
							lifeTime = 0,  effectType = 0},
		},
	},

	['corspy'] = {
		-- spycloakhead = {
		-- 	distortionType = 'point',
		-- 	pieceName = 'body',
		-- 	distortionConfig = { posx = 0, posy = 5.5, posz = 13, radius = 4.5,
		-- 					noiseStrength = 3, noiseScaleSpace = -1.7, distanceFalloff = 0.75, onlyModelMap = -1,
		-- 					windAffected = -1, riseRate = -0.5,
		-- 					lifeTime = 0,  effectType = 0},
		-- },
		spycloakl = {
			distortionType = 'point',
			pieceName = 'head',
			distortionConfig = { posx = -7.5, posy = 4.8, posz = 0, radius = 5.5,
							noiseStrength = 24, noiseScaleSpace = -1.5, distanceFalloff = 0.9, onlyModelMap = -1,
							windAffected = -1, riseRate = -0.5,
							lifeTime = 0,  effectType = 0},
		},
		spycloakr = {
			distortionType = 'point',
			pieceName = 'head',
			distortionConfig = { posx = 7.5, posy = 4.8, posz = 0, radius = 5.5,
							noiseStrength = 24, noiseScaleSpace = -1.5, distanceFalloff = 0.9, onlyModelMap = -1,
							windAffected = -1, riseRate = -0.5,
							lifeTime = 0,  effectType = 0},
		},
	},

	['armveil'] = {
		-- magnifier = {
		-- 	distortionType = 'point',
		-- 	pieceName = 'base',
		-- 	distortionConfig = { posx = 0, posy = 90, posz = 0, radius = 20,
		-- 					lifeTime = 0,  
		-- 					magnificationRate = 10.0, effectType = "magnifier"}, 
		-- },
		jamdistortion = {
			distortionType = 'point',
			pieceName = 'jam',
			distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 18,
							noiseStrength = 10, noiseScaleSpace = 0.4, distanceFalloff = 1.5,
							windAffected = -1,
							lifeTime = 0,  effectType = 0},
		},
	}, 

	['armjam'] = {
		jamdistortion = {
			distortionType = 'point',
			pieceName = 'jam',
			distortionConfig = { posx = 0, posy = -12, posz = 0, radius = 10,
							noiseStrength = 20, noiseScaleSpace = 0.4, distanceFalloff = 1.5,
							windAffected = -1,
							lifeTime = 0,  effectType = 0},
		},
	},

	['coreter'] = {
		jamdistortion = {
			distortionType = 'point',
			pieceName = 'jam',
			distortionConfig = { posx = 0, posy = 0, posz = -3, radius = 11,
							noiseStrength = 10, noiseScaleSpace = 0.4, distanceFalloff = 1.2,
							windAffected = -1,
							lifeTime = 0,  effectType = 0},
		},
	},

	['corshroud'] = {
		jamdistortion = {
			distortionType = 'point',
			pieceName = 'jam',
			distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 18,
							noiseStrength = 10, noiseScaleSpace = 0.4, distanceFalloff = 1.5,
							windAffected = -1,
							lifeTime = 0,  effectType = 0},
		},
	}, 

	['corap'] = {
		heatvent1 = {
			distortionType = 'beam',
			pieceName = 'base',
			distortionConfig = { posx = -43,  posy = 28,  posz = 16.5, radius = 8,
							    pos2x = -43, pos2y = 35, pos2z = 16.4,
							noiseStrength = 0.5, noiseScaleSpace = -2, distanceFalloff = 1.4,
							windAffected = -1, riseRate = 1,
							lifeTime = 0, effectType = 'heatDistortion'},
		},
	},

	['corpyro'] = {
		flameheat = {
			distortionType = 'beam',
			pieceName = 'lloarm',
			distortionConfig = { posx = 0,  posy = -0.4,  posz = 17, radius = 5.5,
							    pos2x = 0, pos2y = -0.4, pos2z = 18,
							noiseStrength = 1.0, noiseScaleSpace = -2.0, distanceFalloff = 1.5,
							effectStrength = 1.0,
							windAffected = 0.5, riseRate = 1.2,
							lifeTime = 0, effectType = 'heatDistortion'},
		},
	},

	['cordemon'] = {
		flameheatl = {
			distortionType = 'beam',
			pieceName = 'lfbarrel1',
			distortionConfig = { posx = -2,  posy = -0.4,  posz = 5, radius = 8.5,
							    pos2x = -2, pos2y = -0.4, pos2z = 6,
							noiseStrength = 1.0, noiseScaleSpace = -2.0, distanceFalloff = 1.5,
							effectStrength = 1.0,
							windAffected = 0.5, riseRate = 1.2,
							lifeTime = 0, effectType = 'heatDistortion'},
		},
		flameheatr = {
			distortionType = 'beam',
			pieceName = 'rfbarrel1',
			distortionConfig = { posx = -2,  posy = -0.4,  posz = 5, radius = 8.5,
							    pos2x = -2, pos2y = -0.4, pos2z = 6,
							noiseStrength = 1.0, noiseScaleSpace = -2.0, distanceFalloff = 1.5,
							effectStrength = 1.0,
							windAffected = 0.5, riseRate = 1.2,
							lifeTime = 0, effectType = 'heatDistortion'},
		},
	},

	['corint'] = {
		heatvent1 = {
			distortionType = 'beam',
			pieceName = 'gun',
			distortionConfig = { posx = 0,  posy = 20,  posz = -14.5, radius = 8,
							    pos2x = 0, pos2y = 26, pos2z = -14.4,
							noiseStrength = 0.5, noiseScaleSpace = -2, distanceFalloff = 1.4,
							windAffected = -1, riseRate = 1,
							lifeTime = 0, effectType = 'heatDistortion'},
		},
	},

	['coravp'] = {
		factoryheat = {
			distortionType = 'point',
			pieceName = 'base',
			distortionConfig = { posx = -7, posy = 40, posz = -35, radius = 12,
							noiseStrength = 0.5, noiseScaleSpace = -2, distanceFalloff = 1.4,
							windAffected = -1,
							lifeTime = 0,  effectType = 'heatDistortion'},
		},
		factoryheat2 = {
			distortionType = 'point',
			pieceName = 'base',
			distortionConfig = { posx = 7, posy = 40, posz = -35, radius = 12,
							noiseStrength = 0.6, noiseScaleSpace = -1.9, distanceFalloff = 1.4,
							lifeTime = 0,  effectType = 'heatDistortion'},
		},
		factoryheatback1 = {
			distortionType = 'point',
			pieceName = 'base',
			distortionConfig = { posx = -55, posy = 12, posz = -42, radius = 9,
							noiseStrength = 0.9, noiseScaleSpace = -2.9, distanceFalloff = 1.4,
							lifeTime = 0,  effectType = 'heatDistortion'},
		},
		factoryheatback2 = {
			distortionType = 'point',
			pieceName = 'base',
			distortionConfig = { posx = 55, posy = 12, posz = -42, radius = 9,
							noiseStrength = 0.9, noiseScaleSpace = -2.9, distanceFalloff = 1.4,
							lifeTime = 0,  effectType = 'heatDistortion'},
		},
	},

	['corgant'] = {
		factoryheat1 = {
			distortionType = 'point',
			pieceName = 'base',
			distortionConfig = { posx = -60, posy = 55, posz = -51, radius = 20,
							noiseStrength = 0.6, noiseScaleSpace = -2, distanceFalloff = 1.4,
							windAffected = -1,
							lifeTime = 0,  effectType = 'heatDistortion'},
		},
		factoryheat2 = {
			distortionType = 'point',
			pieceName = 'base',
			distortionConfig = { posx = 60, posy = 55, posz = -51, radius = 20,
							noiseStrength = 0.6, noiseScaleSpace = -1.9, distanceFalloff = 1.4,
							lifeTime = 0,  effectType = 'heatDistortion'},
		},
		heatventfront1 = {
			distortionType = 'beam',
			pieceName = 'base',
			distortionConfig = { posx = 54,  posy = 60,  posz = 5.5, radius = 10,
							    pos2x = 54, pos2y = 60, pos2z = 22.4,
							noiseStrength = 0.5, noiseScaleSpace = -2, distanceFalloff = 1.4,
							windAffected = -1, riseRate = 1,
							lifeTime = 0, effectType = 'heatDistortion'},
		},
		heatventfront1B = {
			distortionType = 'beam',
			pieceName = 'base',
			distortionConfig = { posx = 83,  posy = 60,  posz = 5.5, radius = 10,
							    pos2x = 83, pos2y = 60, pos2z = 22.4,
							noiseStrength = 0.5, noiseScaleSpace = -2, distanceFalloff = 1.4,
							windAffected = -1, riseRate = 1,
							lifeTime = 0, effectType = 'heatDistortion'},
		},
		heatventfront2 = {
			distortionType = 'beam',
			pieceName = 'base',
			distortionConfig = { posx = -54,  posy = 60,  posz = 5.5, radius = 10,
							    pos2x = -54, pos2y = 60, pos2z = 22.4,
							noiseStrength = 0.5, noiseScaleSpace = -2, distanceFalloff = 1.4,
							windAffected = -1, riseRate = 1,
							lifeTime = 0, effectType = 'heatDistortion'},
		},
		heatventfront2B = {
			distortionType = 'beam',
			pieceName = 'base',
			distortionConfig = { posx = -83,  posy = 60,  posz = 5.5, radius = 10,
							    pos2x = -83, pos2y = 60, pos2z = 22.4,
							noiseStrength = 0.5, noiseScaleSpace = -2, distanceFalloff = 1.4,
							windAffected = -1, riseRate = 1,
							lifeTime = 0, effectType = 'heatDistortion'},
		},
	},
	
	['corfus'] = {
		distortion = {
			distortionType = 'point',
			pieceName = 'emit',
			distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 25,
							noiseStrength = 1.2, noiseScaleSpace = 1.3, distanceFalloff = 0.5,
							windAffected = -0.5, riseRate = -0.7,
							lifeTime = 0,  effectType = 0},
		},
	},
	
	['corafus'] = {
		distortion = {
			distortionType = 'point',
			pieceName = 'emit',
			distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 38,
							noiseStrength = 1.5, noiseScaleSpace = 1.4, distanceFalloff = 0.5,
							windAffected = -0.5, riseRate = -0.7,
							lifeTime = 0,  effectType = 0},
		},
	},

	['corafust3'] = {
		distortion = {
			distortionType = 'point',
			pieceName = 'emit',
			distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 72,
							noiseStrength = 1.5, noiseScaleSpace = 1.4, distanceFalloff = 0.5,
							windAffected = -0.5, riseRate = -0.7,
							lifeTime = 0,  effectType = 0},
		},
	},

	['legfus'] = {
		distortion = {
			distortionType = 'point',
			pieceName = 'emit',
			distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 25,
							noiseStrength = 1.5, noiseScaleSpace = 1.4, distanceFalloff = 0.5,
							windAffected = -0.5, riseRate = -0.7,
							lifeTime = 0,  effectType = 0},
		},
	},

	['legafus'] = {
		distortion = {
			distortionType = 'point',
			pieceName = 'emit',
			distortionConfig = { posx = 0, posy = 5, posz = 0, radius = 40,
							noiseStrength = 1.5, noiseScaleSpace = 1.4, distanceFalloff = 0.5,
							windAffected = -0.5, riseRate = -0.7,
							lifeTime = 0,  effectType = 0},
		},
	},

	['armfus'] = {
		distortion1 = {
			distortionType = 'point',
			pieceName = 'emit1',
			distortionConfig = { posx = 0, posy = -2, posz = 0, radius = 15,
							noiseStrength = 2, noiseScaleSpace = -1.2, distanceFalloff = 0.9,
							windAffected = -0.5, riseRate = -2, decay = -1.3,
							lifeTime = 0,  effectType = 0},
		},
		distortion2 = {
			distortionType = 'point',
			pieceName = 'emit2',
			distortionConfig = { posx = 0, posy = -2, posz = 0, radius = 15,
							noiseStrength = 2, noiseScaleSpace = -1.2, distanceFalloff = 0.9,
							windAffected = -0.5, riseRate = -2, decay = -1.3,
							lifeTime = 0,  effectType = 0},
		},
	},
	
	['armafus'] = {
		distortion = {
			distortionType = 'point',
			pieceName = 'emit',
			distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 32,
							noiseStrength = 1.5, noiseScaleSpace = 1.4, distanceFalloff = 0.6,
							windAffected = -0.5, riseRate = -0.7,
							lifeTime = 0,  effectType = 0},
		},
		-- distortion-old-ugly-icexuick = {
		-- 	distortionType = 'point',
		-- 	pieceName = 'emit',
		-- 	distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 37,
		-- 	noiseStrength = 1, noiseScaleSpace = 2, distanceFalloff = 1.2,
		-- 					--riseRate = 2, windAffected = -1,
		-- 					--decay = 3.5,
		-- 					lifeTime = 0,  effectType = 0},
		-- },
		-- magnifier = {
		-- 	distortionType = 'point',
		-- 	pieceName = 'emit',
		-- 	distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 32,
		-- 					lifeTime = 0,  
		-- 					magnificationRate = 1.5, effectType = "magnifier"}, 
		-- },
	},

	['armafust3'] = {
		distortion = {
			distortionType = 'point',
			pieceName = 'emit',
			distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 62,
							noiseStrength = 1.8, noiseScaleSpace = 1.0, distanceFalloff = 0.6,
							windAffected = -0.5, riseRate = -0.7,
							effectStrength = 2.0,
							lifeTime = 0,  effectType = 0},
		},
	},

	['legafust3'] = {
		distortion = {
			distortionType = 'point',
			pieceName = 'emit',
			distortionConfig = { posx = 0, posy = 10, posz = 0, radius = 76,
							noiseStrength = 1.8, noiseScaleSpace = 1.0, distanceFalloff = 0.6,
							windAffected = -0.5, riseRate = -0.7,
							effectStrength = 2.0,
							lifeTime = 0,  effectType = 0},
		},
	},

	['armgate'] = {
		distortion = {
			distortionType = 'point',
			pieceName = 'none',
			distortionConfig = { posx = 0, posy = 24, posz = -5, radius = 14,
							noiseStrength = 1, noiseScaleSpace = 0.5, distanceFalloff = 0.3,
							windAffected = -0.5,
							lifeTime = 0,  effectType = 0},
		},
		-- cloakblob = {
		-- 	distortionType = 'point',
		-- 	pieceName = 'turret',
		-- 	distortionConfig = { posx = 0, posy = 24, posz = -5, radius = 14,
		-- 					lifeTime = 0,  
		-- 					magnificationRate = 1.5, effectType = "magnifier"}, 
		-- },
		shielddistortion = {
			distortionType = 'point',
			pieceName = 'base',
			distortionConfig = { posx = 0, posy = -6.5, posz = 0.01, radius = 552,
								pos2x = 0, pos2y = 20, pos2z = 0, radius2 = 20, 
								noiseStrength = 5.5, noiseScaleSpace = -0.15, distanceFalloff = -0.5,
								rampUp = 0, decay = 0,
								--magnificationRate = -8.0,
								lifeTime = 0, windAffected = -1, riseRate = -0.6,
								effectType = 7},

		},
	},

	['armfgate'] = {
		distortion = {
			distortionType = 'point',
			pieceName = 'none',
			distortionConfig = { posx = 0, posy = 25, posz = 0, radius = 16,
							noiseStrength = 1, noiseScaleSpace = 1.5, distanceFalloff = 0.5,
							windAffected = -0.5,
							lifeTime = 0,  effectType = 0},
		},
	},

	['corgate'] = {
		distortion = {
			distortionType = 'point',
			pieceName = 'none',
			distortionConfig = { posx = 0, posy = 40, posz = 0, radius = 12,
							noiseStrength = 1, noiseScaleSpace = 0.5, distanceFalloff = 0.3,
							windAffected = -0.5,
							lifeTime = 0,  effectType = 0},
		},
		-- distortionold = {
		-- 	distortionType = 'point',
		-- 	pieceName = 'none',
		-- 	distortionConfig = { posx = 0, posy = 40, posz = 0, radius = 16,
		-- 					noiseStrength = 1, noiseScaleSpace = 1.5, distanceFalloff = 0.5,
		-- 					windAffected = -0.5,
		-- 					lifeTime = 0,  effectType = 0},
		-- },
	},

	['corfgate'] = {
		distortion = {
			distortionType = 'point',
			pieceName = 'none',
			distortionConfig = { posx = 0, posy = 42, posz = 0, radius = 16,
							noiseStrength = 1, noiseScaleSpace = 1.5, distanceFalloff = 0.5,
							windAffected = -0.5,
							lifeTime = 0,  effectType = 0},
		},
	},

	['corjamt'] = {
		distortion = {
			distortionType = 'point',
			pieceName = 'jam',
			distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 12,
							noiseStrength = 10, noiseScaleSpace = 0.4, distanceFalloff = 1.5,
							windAffected = -1,
							lifeTime = 0,  effectType = 0},
		},
	},

	['armjamt'] = {
		jamdistortion = {
			distortionType = 'point',
			pieceName = 'jam',
			distortionConfig = { posx = 0, posy = 15, posz = 0, radius = 12,
							noiseStrength = 10, noiseScaleSpace = 0.4, distanceFalloff = 1.5,
							windAffected = -1, riseRate = -0.5,
							lifeTime = 0,  effectType = 0},
		},
	},

	['corsjam'] = {
		distortionbeam = {
			distortionType = 'beam',
			pieceName = 'jam',
			distortionConfig = { posx = 0, posy = 0, posz = -4, radius = 4.5,
								pos2x = 0, pos2y = 0, pos2z = 4, 
								noiseStrength = 10, noiseScaleSpace = 0.4, distanceFalloff = 1.5,
								windAffected = -1,
								lifeTime = 0,  effectType = 0},
		},
	},

	['cormando'] = {
		distortionbeam = {
			distortionType = 'beam',
			pieceName = 'turret',
			distortionConfig = { posx = 0, posy = 7, posz = 0, radius = 3.5,
								pos2x = 0, pos2y = 6, pos2z = 0.1, 
								noiseStrength = 2, noiseScaleSpace = -1.8, distanceFalloff = 1.5,
								windAffected = -1,
								lifeTime = 0,  effectType = 0},
		},
		cloakblob = {
			distortionType = 'point',
			pieceName = 'turret',
			distortionConfig = { posx = 0, posy = 6.5, posz = 0, radius = 3,
							lifeTime = 0,  
							magnificationRate = 0.6, effectType = "magnifier"}, 
		},
		-- magnifier = {
		-- 	distortionType = 'point',
		-- 	pieceName = 'turret',
		-- 	distortionConfig = { posx = -8, posy = 10, posz = -3, radius = 4,
		-- 					lifeTime = 0,  
		-- 					magnificationRate = 4.0, effectType = "magnifier"}, 
		-- },
	},

	['armsjam'] = {
		distortionbeam1 = {
			distortionType = 'beam',
			pieceName = 'jam',
			distortionConfig = { posx = 0, posy = 0, posz = -15, radius = 4.5,
								pos2x = 0, pos2y = 0, pos2z = -22, 
								noiseStrength = 10, noiseScaleSpace = 0.4, distanceFalloff = 1.5,
								windAffected = -1,
								lifeTime = 0,  effectType = 0},
		},
		distortionbeam2 = {
			distortionType = 'beam',
			pieceName = 'jam',
			distortionConfig = { posx = 0, posy = 0, posz = 15, radius = 4.5,
								pos2x = 0, pos2y = 0, pos2z = 22, 
								noiseStrength = 10, noiseScaleSpace = 0.4, distanceFalloff = 1.5,
								windAffected = -1,
								lifeTime = 0,  effectType = 0},
		},
	},

	['armmark'] = {
		-- radarring = {
		-- 	distortionType = 'point',
		-- 	pieceName = 'none',
		-- 	distortionConfig = { posx = 0, posy = 58, posz = 0, radius = 12,
		-- 					noiseStrength = 10, noiseScaleSpace = 0.4, distanceFalloff = 1.5,
		-- 					windAffected = -1,
		-- 					lifeTime = 50,  effectType = 'airShockwave'},
		-- },
	},

	['armaser'] = {
		distortionbeam = {
			distortionType = 'beam',
			pieceName = 'jam',
			distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 6.5,
								pos2x = -9, pos2y = 0, pos2z = 0.1, 
								noiseStrength = 10, noiseScaleSpace = 0.4, distanceFalloff = 1.5,
								windAffected = -1,
								lifeTime = 0,  effectType = 0},
		},
	},

	['corspec'] = {
		distortionbeam = {
			distortionType = 'beam',
			pieceName = 'jam',
			distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 6.5,
								pos2x = 0, pos2y = 0, pos2z = 2, 
								noiseStrength = 10, noiseScaleSpace = 0.4, distanceFalloff = 1.5,
								windAffected = -1,
								lifeTime = 0,  effectType = 0},
		},
	},

	['corjuno'] = {
		distortion = {
			distortionType = 'point',
			pieceName = 'none',
			distortionConfig = { posx = 0, posy = 72, posz = 0, radius = 11,
							noiseStrength = 3, noiseScaleSpace = -0.2, distanceFalloff = 0.5,
							windAffected = -0.5,
							lifeTime = 0,  effectType = 0},
		},
	},

	['corjugg'] = {
		distortion = {
			distortionType = 'point',
			pieceName = 'mainbarrel',
			distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 3.6,
							noiseStrength = 3, noiseScaleSpace = -1.6, distanceFalloff = 0.5,
							windAffected = -0.5,
							lifeTime = 0,  effectType = 0},
		},
		cloakblob = {
			distortionType = 'point',
			pieceName = 'mainbarrel',
			distortionConfig = { posx = 0, posy = 0, posz = 2, radius = 4.5,
							lifeTime = 0,  
							magnificationRate = -0.2, effectType = "magnifier"}, 
		},
	},

	
	['armjuno'] = {
		distortion = {
			distortionType = 'point',
			pieceName = 'none',
			distortionConfig = { posx = 0, posy = 72, posz = 0, radius = 11,
							noiseStrength = 3, noiseScaleSpace = -0.2, distanceFalloff = 0.5,
							windAffected = -0.5, --riseRate = -0.9,
							lifeTime = 0,  effectType = 0},
		},
	},
	
	['lootboxbronze'] = {
		distortion = {
			distortionType = 'point',
			pieceName = 'none',
			distortionConfig = { posx = 0, posy = 34, posz = 0, radius = 14,
							noiseStrength = 1, noiseScaleSpace = 1.5, distanceFalloff = 0.5,
							windAffected = -0.5,
							lifeTime = 0,  effectType = 0},
		},
	},
	
	['lootboxsilver'] = {
		distortion = {
			distortionType = 'point',
			pieceName = 'none',
			distortionConfig = { posx = 0, posy = 52, posz = 0, radius = 18,
							noiseStrength = 1, noiseScaleSpace = 1.5, distanceFalloff = 0.5,
							windAffected = -0.5,
							lifeTime = 0,  effectType = 0},
		},
	},
	
	['lootboxgold'] = {
		distortion = {
			distortionType = 'point',
			pieceName = 'none',
			distortionConfig = { posx = 0, posy = 69, posz = 0, radius = 23,
							noiseStrength = 1, noiseScaleSpace = 1.5, distanceFalloff = 0.5,
							windAffected = -0.5,
							lifeTime = 0,  effectType = 0},
		},
	},
	
	['lootboxplatinum'] = {
		distortion = {
			distortionType = 'point',
			pieceName = 'none',
			distortionConfig = { posx = 0, posy = 87, posz = 0, radius = 30,
							noiseStrength = 1, noiseScaleSpace = 1.5, distanceFalloff = 0.5,
							windAffected = -0.5,
							lifeTime = 0,  effectType = 0},
		},
	},


	['corcrwh'] = {

		thrust1 = {
			distortionType = 'cone',
			pieceName = 'thrustrra',
			distortionConfig = { posx = -2, posy = 0, posz = -2, radius = 80,
							dirx = 0, diry = 0, dirz = -1, theta = 0.4,
							noiseStrength = 1, noiseScaleSpace = 0.65,
							riseRate = -8, lifeTime = 0,  effectType = 0},
		},

		thrust2 = {
			distortionType = 'cone',
			pieceName = 'thrustrla',
			distortionConfig = { posx = -2, posy = 0, posz = -2, radius = 80,
							dirx = 0, diry = 0, dirz = -1, theta = 0.4,
							noiseStrength = 1, noiseScaleSpace = 0.65,
							riseRate = -8, lifeTime = 0,  effectType = 0},
		},
		thrust3 = {
			distortionType = 'cone',
			pieceName = 'thrustfla',
			distortionConfig = { posx = -2, posy = 0, posz = -2, radius = 80,
							dirx = 0, diry = 0, dirz = -1, theta = 0.4,
							noiseStrength = 1, noiseScaleSpace = 0.65,
							riseRate = -8, lifeTime = 0,  effectType = 0},
		},
		thrust4 = {
			distortionType = 'cone',
			pieceName = 'thrustfra',
			distortionConfig = { posx = -2, posy = 0, posz = -2, radius = 80,
							dirx = 0, diry = 0, dirz = -1, theta = 0.4,
							noiseStrength = 1, noiseScaleSpace = 0.65,
							riseRate = -8, lifeTime = 0,  effectType = 0},
		},
		distortionleft = {
			distortionType = 'beam',
			pieceName = 'base',
			distortionConfig = { posx = 15, posy = 32, posz = -21, radius = 8,
								pos2x = 15, pos2y = 32, pos2z = 7, radius2 = 28, 
								noiseStrength = 0.2, noiseScaleSpace = -2.1, distanceFalloff = 0.8,
								rampUp = 30, decay = -1.5,
								lifeTime = 0,  effectType = 0},
		},
		distortionright = {
			distortionType = 'beam',
			pieceName = 'base',
			distortionConfig = { posx = -15, posy = 32, posz = -21, radius = 8,
								pos2x = -15, pos2y = 32, pos2z = 7, radius2 = 28, 
								noiseStrength = 0.2, noiseScaleSpace = -2.1, distanceFalloff = 0.8,
								rampUp = 30, decay = -1.5,
								lifeTime = 0,  effectType = 0},
		},
	},
}


-- Effect duplications:
unitDistortions['armdecom'] = unitDistortions['armcom']
unitDistortions['corgantuw'] = unitDistortions['corgant']

local unitEventDistortionsNames = {
	------------------------------------ Put distortions that are slaved to ProjectileCreated here! ---------------------------------
	-- WeaponBarrelGlow =  {
	-- 	['corint'] = {
	-- 		barrelglow1 = {
	-- 			distortionType = 'point',
	-- 			pieceName = 'distortion',
	-- 			distortionConfig = { posx = -7, posy = 8, posz = 5, radius = 30,
	-- 				color2r = 0, color2g = 0, color2b = 0, colortime = 300,
	-- 				r = 1, g = 1, b = 1, a = 0.69999999,
	-- 				modelfactor = 2, specular = 1, scattering = 0, lensflare = 0,
	-- 				lifeTime = 300, sustain = 1, effectType = 0},
	-- 		},
	-- 	},
	-- 	['corint'] = {
	-- 		barrelglow2 = {
	-- 			distortionType = 'point',
	-- 			pieceName = 'distortion',
	-- 			distortionConfig = { posx = 7, posy = 8, posz = 5, radius = 30,
	-- 				color2r = 0, color2g = 0, color2b = 0, colortime = 300,
	-- 				r = 1, g = 1, b = 1, a = 0.69999999,
	-- 				modelfactor = 2, specular = 1, scattering = 0, lensflare = 0,
	-- 				lifeTime = 300, sustain = 1, effectType = 0},
	-- 		},
	-- 	},
	-- },
	--------------------------------- Put distortions that are spawned from COB/LUS here ! ---------------------------------
	-- These distortions _must_ be indexed by numbers! As these will be the ones triggered by the
	-- The COB lua_UnitScriptDistortion(distortionIndex, count) call does this job!
	-- to make the distortion EXACTLY color2 at the end of the lifeTime, make colortime = 2 * lifeTime

	--corint disabled for now since it has static positioning - now only 'working' when shooting to east:

	UnitScriptDistortions = {
		
		['corkorg'] = {
			[1] = {
				-- Footstep shockwave
				alwaysVisible = false,
				distortionType = 'point',
				distortionName = 'corkorgfootstep',
				pieceName = 'none',
				distortionConfig = { posx = 0, posy = 0, posz = 8, radius = 120,
								noiseStrength = 1.2, noiseScaleSpace = 0.5, distanceFalloff = 0.4, onlyModelMap = 1, 
								effectStrength = 1.0, --needed for shockwave
								lifeTime = 25, rampUp = 3, decay = 15, startRadius = 0.3,
								shockWidth = 5, effectType = 'groundShockwave'},
	
			},
		},

		['corsumo'] = {
			[1] = {
				-- Footstep shockwave
				alwaysVisible = false,
				distortionType = 'point',
				distortionName = 'corsumofootstepfl',
				pieceName = 'footfl',
				distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 25,
								noiseStrength = 0.5, noiseScaleSpace = 0.5, distanceFalloff = 0.4, onlyModelMap = 1, 
								effectStrength = 1.0, --needed for shockwave
								lifeTime = 18, rampUp = 3, decay = 15, startRadius = 0.3,
								shockWidth = 1, effectType = 'groundShockwave'},
	
			},
			[2] = {
				-- Footstep shockwave
				alwaysVisible = false,
				distortionType = 'point',
				distortionName = 'corsumofootstepbr',
				pieceName = 'footbr',
				distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 25,
								noiseStrength = 0.5, noiseScaleSpace = 0.5, distanceFalloff = 0.4, onlyModelMap = 1, 
								effectStrength = 1.0, --needed for shockwave
								lifeTime = 18, rampUp = 3, decay = 15, startRadius = 0.3,
								shockWidth = 1, effectType = 'groundShockwave'},
	
			},
			[3] = {
				-- Footstep shockwave
				alwaysVisible = false,
				distortionType = 'point',
				distortionName = 'corsumofootstepfr',
				pieceName = 'footfr',
				distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 25,
								noiseStrength = 0.5, noiseScaleSpace = 0.5, distanceFalloff = 0.4, onlyModelMap = 1, 
								effectStrength = 1.0, --needed for shockwave
								lifeTime = 18, rampUp = 3, decay = 15, startRadius = 0.3,
								shockWidth = 1, effectType = 'groundShockwave'},
	
			},
			[4] = {
				-- Footstep shockwave
				alwaysVisible = false,
				distortionType = 'point',
				distortionName = 'corsumofootstepbl',
				pieceName = 'footbl',
				distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 25,
								noiseStrength = 0.5, noiseScaleSpace = 0.5, distanceFalloff = 0.4, onlyModelMap = 1, 
								effectStrength = 1.0, --needed for shockwave
								lifeTime = 18, rampUp = 3, decay = 15, startRadius = 0.3,
								shockWidth = 1, effectType = 'groundShockwave'},
	
			},
		},

		['corjugg'] = {
			[1] = {
				-- Footstep shockwave
				alwaysVisible = false,
				distortionType = 'point',
				distortionName = 'bigassfootstep',
				pieceName = 'lfootstepf',
				distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 60,
								noiseStrength = 1.1, noiseScaleSpace = 0.6, distanceFalloff = 0.4, onlyModelMap = 1, 
								effectStrength = 1.2, --needed for shockwave
								lifeTime = 18, rampUp = 10, decay = 10,
								shockWidth = 1.5, startRadius = 0.1, effectType = 'groundShockwave'},
	
			},
			[2] = {
				-- Footstep shockwave
				alwaysVisible = false,
				distortionType = 'point',
				distortionName = 'bigassfootstep2',
				pieceName = 'rfootstepf',
				distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 60,
								noiseStrength = 1.1, noiseScaleSpace = 0.6, distanceFalloff = 0.4, onlyModelMap = 1, 
								effectStrength = 1.2, --needed for shockwave
								lifeTime = 18, rampUp = 10, decay = 10,
								shockWidth = 1.5, startRadius = 0.1, effectType = 'groundShockwave'},
			},
			[3] = {
				-- Footstep shockwave
				alwaysVisible = false,
				distortionType = 'point',
				distortionName = 'bigassfootstep3',
				pieceName = 'lfootstepb',
				distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 52,
								noiseStrength = 1.1, noiseScaleSpace = 0.6, distanceFalloff = 0.4, onlyModelMap = 1, 
								effectStrength = 1.2, --needed for shockwave
								lifeTime = 18, rampUp = 10, decay = 10,
								shockWidth = 1.5, startRadius = 0.1, effectType = 'groundShockwave'},
	
			},
			[4] = {
				-- Footstep shockwave
				alwaysVisible = false,
				distortionType = 'point',
				distortionName = 'bigassfootstep4',
				pieceName = 'rfootstepb',
				distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 52,
								noiseStrength = 1.1, noiseScaleSpace = 0.6, distanceFalloff = 0.4, onlyModelMap = 1, 
								effectStrength = 1.2, --needed for shockwave
								lifeTime = 18, rampUp = 10, decay = 10,
								shockWidth = 1.5, startRadius = 0.1, effectType = 'groundShockwave'},
	
			},
		},


		['armmark'] = {
			[1] = {
				-- radarwave
				alwaysVisible = false,
				distortionType = 'point',
				distortionName = 'radarwave',
				pieceName = 'none',
				distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 60,
								noiseStrength = 0.2, noiseScaleSpace = 0.8, distanceFalloff = 0.1, onlyModelMap = 1, 
								effectStrength = -1.5, --needed for shockwave
								lifeTime = 60, rampUp = 20, decay = 15,
								shockWidth = 0.7, startRadius = 0.1, effectType = 'groundShockwave'},
	
			},
		},

		['cordemon'] = {
			[1] = {
				-- Barrel Heat
				alwaysVisible = false,
				distortionType = 'point',
				distortionName = 'flameheat1',
				pieceName = 'lfbarrel2',
				distortionConfig = { posx = 0, posy = 5, posz = 0, radius = 11,
								noiseStrength = 0.4, noiseScaleSpace = 1.8, distanceFalloff = 1.1,
								onlyModelMap = 0, 
								effectStrength = 1.0, --needed for heat
								riseRate = 1.2, windAffected = 0.3,
								lifeTime = 250, rampUp = 40, decay = 120,
								effectType = 0},
			},
			[2] = {
				-- Barrel Heat
				alwaysVisible = false,
				distortionType = 'point',
				distortionName = 'flameheat2',
				pieceName = 'rfbarrel2',
				distortionConfig = { posx = 0, posy = 5, posz = 0, radius = 11,
								noiseStrength = 0.4, noiseScaleSpace = 1.8, distanceFalloff = 1.1,
								onlyModelMap = 0, 
								effectStrength = 1.0, --needed for heat
								riseRate = 1.2, windAffected = 0.3,
								lifeTime = 250, rampUp = 40, decay = 120,
								effectType = 0},
			},
			-- [3] = {
			-- 	-- Flame distort
			-- 	alwaysVisible = false,
			-- 	distortionType = 'beam',
			-- 	distortionName = 'flamedistort',
			-- 	pieceName = 'rfbarrel2',
			-- 	distortionConfig = { posx = 0, posy = 5, posz = 25, radius = 35,
			-- 					pos2x = 0, pos2y = 5, pos2z = 185,
			-- 					noiseStrength = 4, noiseScaleSpace = -0.3, distanceFalloff = 3.5,
			-- 					onlyModelMap = 0, 
			-- 					effectStrength = 3.0, --needed for heat
			-- 					windAffected = 0.1, riseRate = -0.5,
			-- 					lifeTime = 15, rampUp = 0, decay = 0,
			-- 					effectType = 0},
			-- },
			[3] = {
				-- Flame distort
				alwaysVisible = false,
				distortionType = 'cone',
				distortionName = 'flamedistort',
				pieceName = 'rfbarrel2',
				distortionConfig = { posx = 0, posy = 5, posz = 0, radius = 350,
								dirx =  0, diry = 0, dirz = 1.0, theta = 0.3,
								noiseStrength = 4, noiseScaleSpace = -0.2, distanceFalloff = 3.5,
								onlyModelMap = 0, 
								effectStrength = 3.0, --needed for heat
								windAffected = 0.1, riseRate = -0.5,
								lifeTime = 15, rampUp = 25, decay = 0,
								effectType = 0},
			},
			[4] = {
				-- Flame distort
				alwaysVisible = false,
				distortionType = 'cone',
				distortionName = 'flamedistort',
				pieceName = 'lfbarrel2',
				distortionConfig = { posx = 0, posy = 5, posz = 0, radius = 350,
								dirx =  0, diry = 0, dirz = 1.0, theta = 0.4,
								noiseStrength = 4, noiseScaleSpace = 0.12, distanceFalloff = 3.5,
								onlyModelMap = 0, 
								effectStrength = 2.0, --needed for heat
								windAffected = 0.1, riseRate = -0.5,
								lifeTime = 15, rampUp = 25, decay = 0,
								effectType = 0},
			},
		},

		['armraz'] = {
			[1] = {
				-- Barrel Heat
				alwaysVisible = false,
				distortionType = 'point',
				distortionName = 'barrelheatl',
				pieceName = 'lcannon',
				distortionConfig = { posx = 0, posy = 5, posz = 23.5, radius = 8,
								noiseStrength = 0.3, noiseScaleSpace = -1.8, distanceFalloff = 0.8,
								onlyModelMap = 0, 
								effectStrength = 0.5, --needed for heat
								lifeTime = 160, rampUp = 25, decay = 25,
								riseRate = 0.2, windAffected = -0.3,
								effectType = 0},
			},
			[2] = {
				-- Barrel Heat
				alwaysVisible = false,
				distortionType = 'point',
				distortionName = 'barrelheatr',
				pieceName = 'rcannon',
				distortionConfig = { posx = 0, posy = 5, posz = 23.5, radius = 8,
								noiseStrength = 0.3, noiseScaleSpace = -1.8, distanceFalloff = 0.8,
								onlyModelMap = 0, 
								effectStrength = 0.5, --needed for heat
								lifeTime = 160, rampUp = 25, decay = 25,
								riseRate = 0.2, windAffected = -0.3,
								effectType = 0},
			},
		},

				
		['armbrtha'] = {
			[1] = {
				-- Barrel Heat after shot
				alwaysVisible = false,
				distortionType = 'beam',
				distortionName = 'brthabarrelheat',
				pieceName = 'flare',
				distortionConfig = { posx = 0, posy = 4, posz = 4, radius = 10,
									pos2x = 0, pos2y = 4, pos2z = -16,
								onlyModelMap = 0,
								riseRate = 0.5, windAffected = -0.5,
								noiseStrength = 0.3, noiseScaleSpace = 1.0, distanceFalloff = 1.0,
								rampUp = 5, decay = 200, 
								lifeTime = 240,  effectType = 0},
	
			},
		},

		['corint'] = {
			[1] = {
				-- Barrel Heat after shot
				alwaysVisible = false,
				distortionType = 'beam',
				distortionName = 'corintbarrelheat',
				pieceName = 'heat',
				distortionConfig = { posx = 0, posy = 4, posz = 4, radius = 10,
									pos2x = 0, pos2y = 4, pos2z = -16,
								onlyModelMap = 0,
								riseRate = 0.5, windAffected = -0.5,
								noiseStrength = 0.3, noiseScaleSpace = 1.0, distanceFalloff = 1.0,
								rampUp = 5, decay = 200, 
								lifeTime = 240,  effectType = 0},
	
			},
		},
	},




	------------------------------- Put additional distortions tied to events here! --------------------------------
	UnitIdle =  {
		--[[
		['armcom'] = {
			idleBlink = {
				distortionType = 'point',
				pieceName = 'head',
				distortionConfig = { posx = 0, posy = 22, posz = 12, radius = 90,
					lifeTime = 12,  effectType = 0},
			},
		},
		]]--
	},

	UnitFinished = {
		--[[ 
		default = {
			default = {
				distortionType = 'cone',
				--pieceName = 'base',
				aboveUnit = 100,
				distortionConfig = { posx = 0, posy = 32, posz = 0, radius = 160,
					dirx = 0, diry = -0.99, dirz = 0.02, theta = 0.4,
					lifeTime = 20, sustain = 2, effectType = 0},
			},
		},
		]]--
	},

	UnitCreated = {
		--[[
		default = {
			default = {
				distortionType = 'cone',
				pieceName = 'base',
				aboveUnit = 100,
				distortionConfig = { posx = 0, posy = 32, posz = 0, radius = 200,
					dirx = 0, diry = -0.99, dirz = 0.02, theta = 0.4,
					lifeTime = 15, sustain = 2, effectType = 0},
			},
		},
		]]--
	},

	UnitCloaked = {
		--[[
		['armcom'] = {
			cloakBlink = {
				distortionType = 'point',
				pieceName = 'head',
				distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 100,
					lifeTime = 30,  effectType = 0},
			},
			-- cloakFlash = {
			-- 	distortionType = 'point',
			-- 	pieceName = 'head',
			-- 	distortionConfig = { posx = 0, posy = -10, posz = 0, radius = 70,
			-- 		color2r = 1, color2g = 1, color2b = 1, colortime = 5,
			-- 		r = 0, g = 0, b = 0, a = 0.45,
			-- 		modelfactor = 0.2, specular = 0.4, scattering = 1.5, lensflare = 0,
			-- 		lifeTime = 5,  effectType = 0},
			-- },
		},
		default = {
			default = {
				distortionType = 'cone',
				pieceName = 'base',
				aboveUnit = 100,
				distortionConfig = { posx = 0, posy = 32, posz = 0, radius = 200,
					dirx = 0, diry = -0.99, dirz = 0.02, theta = 0.4,
					lifeTime = 15,  effectType = 0},
			},
		},
		]]--
	},

	UnitDecloaked = {
		--[[
		['armcom'] = {
			cloakBlink = {
				distortionType = 'point',
				pieceName = 'head',
				distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 100,
					lifeTime = 30,  effectType = 0},
			},
		},
		default = {
			default = {
				distortionType = 'cone',
				pieceName = 'base',
				aboveUnit = 100,
				distortionConfig = { posx = 0, posy = 32, posz = 0, radius = 200,
					dirx = 0, diry = -0.99, dirz = 0.02, theta = 0.4,
					lifeTime = 15,  effectType = 0},
			},
		},
		]]--
	},

	StockpileChanged = {
	},
	UnitMoveFailed = {
	},

	UnitGiven = {
	},
	UnitTaken = {
	},
	UnitDestroyed = { -- note: dont do piece-attached distortions here!
		--[[
		default = {
			default = {
				distortionType = 'cone',
				pieceName = '',
				aboveUnit = 100,
				distortionConfig = { posx = 0, posy = 32, posz = 0, radius = 200,
					dirx = 0, diry = -0.99, dirz = 0.02, theta = 0.4,
					lifeTime = 15, effectType = 0},
			},
		},
		]]--
	},
}

-- Copy all distortions from source unitname to array of target unitnames
local function DuplicateDistortions(source, targets)
	for i, target in pairs(targets) do 
		if UnitDefNames[source] and UnitDefNames[target] then 
			if unitDistortions[source]  then 
				unitDistortions[target] = table.copy(unitDistortions[source])
			end

			for eventName, distortions in pairs(unitEventDistortionsNames) do
				if unitEventDistortionsNames[eventName][source] then
					unitEventDistortionsNames[eventName][target] = table.copy(unitEventDistortionsNames[eventName][source])
				end
			end
		end
	end
end


--duplicate distortions from armcom for Armada Evocom
local armComTable = {'armcomlvl2', 'armcomlvl4', 'armcomlvl5', 'armcomlvl6', 'armcomlvl7', 'armcomlvl8', 'armcomlvl9', 'armcomlvl10'}
DuplicateDistortions('armcom', armComTable)


--duplicate distortions from corcom for Cortex Evocom
local corComTable = {'corcomlvl2', 'corcomlvl3', 'corcomlvl4', 'corcomlvl5', 'corcomlvl6', 'corcomlvl7', 'corcomlvl8', 'corcomlvl9', 'corcomlvl10'}
DuplicateDistortions('corcom', corComTable)



--duplicate distortions from legcom for Legion Evocom
local legComTable = {'legcomlvl2', 'legcomlvl3', 'legcomlvl4', 'legcomlvl5', 'legcomlvl6', 'legcomlvl7', 'legcomlvl8', 'legcomlvl9', 'legcomlvl10', 'legdecomlvl3', 'legdecomlvl6', 'legdecomlvl10'}
DuplicateDistortions('legcom', legComTable)


--duplicate distortions from scavengerbossv4_normal for all scavengerbossv4 variants
local scavengerBossV4Table = {'scavengerbossv4_veryeasy', 'scavengerbossv4_easy', 'scavengerbossv4_hard', 'scavengerbossv4_veryhard', 'scavengerbossv4_epic'}
DuplicateDistortions('scavengerbossv4_normal', scavengerBossV4Table)


--AND THE REST
---unitEventDistortionsNames -> unitEventDistortions
local unitEventDistortions = {}
for key, subtables in pairs(unitEventDistortionsNames) do
		unitEventDistortions[key] = {}
		for subKey, distortions in pairs(subtables) do
			if UnitDefNames[subKey] then
				unitEventDistortions[key][UnitDefNames[subKey].id] = distortions
			else
				unitEventDistortions[key][subKey] = distortions --preserve defaults etc
			end
		end
end
unitEventDistortionsNames = nil


-- convert unitname -> unitDefID
local unitDefDistortions = {}
for unitName, distortions in pairs(unitDistortions) do
	if UnitDefNames[unitName] then
		unitDefDistortions[UnitDefNames[unitName].id] = distortions
	end
end
unitDistortions = nil

-- oof this should not be a GetConfigInt :/
if not (Spring.GetConfigInt("headdistortions", 1) == 1) then
	for unitDefID, distortions in pairs(unitDefDistortions) do
		for name, params in pairs(distortions) do
			if string.find(name, "headdistortion") or string.find(name, "searchdistortion") then
				unitDefDistortions[unitDefID][name] = nil
			end
		end
	end
end

if not (Spring.GetConfigInt("builddistortions", 1) == 1) then
	for unitDefID, distortions in pairs(unitDefDistortions) do
		for name, params in pairs(distortions) do
			if string.find(name, "builddistortion") then
				unitDefDistortions[unitDefID][name] = nil
			end
		end
	end
end

-- add scavenger equivalents
local scavUnitDefDistortions = {}
for unitDefID, distortions in pairs(unitDefDistortions) do
	if UnitDefNames[UnitDefs[unitDefID].name..'_scav'] then
		scavUnitDefDistortions[UnitDefNames[UnitDefs[unitDefID].name..'_scav'].id] = distortions
	end
end
unitDefDistortions = table.merge(unitDefDistortions, scavUnitDefDistortions)
scavUnitDefDistortions = nil

local featureDefDistortions = {
	
}

local crystalDistortionBase =  {
			distortionType = 'point',
			distortionConfig = { posx = 0, posy = 8, posz = 0, radius = 20,
							onlyModelMap = 0,
							riseRate = 0.5, windAffected = -0.5,
							
							noiseStrength = 0.4, noiseScaleSpace = 2.2, distanceFalloff = 1.2,
							lifeTime = 0,  effectType = 0},
		}

local crystalColors = { -- note that the underscores are needed here
	[""] = {0.78,0.46,0.94,0.11}, -- same as violet
	_violet = {0.8,0.5,0.95,0.33},
	_blue = {0,0,1,0.33},
	_green = {0,1,0,0.15},
	_lime = {0.4,1,0.2,0.15},
	_obsidian = {0.3,0.2,0.2,0.33},
	_quartz = {0.3,0.3,0.5,0.33},
	_orange = {1,0.5,0,0.11},
	_red = {1,0.2,0.2,0.067},
	_teal = {0,1,1,0.15},
	_team = {1,1,1,0.15},
	}

for colorname, colorvalues in pairs(crystalColors) do
	for size = 1,3 do
		local crystaldefname = 'pilha_crystal' .. colorname .. tostring(size)
		if FeatureDefNames[crystaldefname] then
			local crystalDistortion = table.copy(crystalDistortionBase)
			crystalDistortion.distortionConfig.r = colorvalues[1]
			crystalDistortion.distortionConfig.g = colorvalues[2]
			crystalDistortion.distortionConfig.b = colorvalues[3]
			crystalDistortion.distortionConfig.a = colorvalues[4]

			crystalDistortion.distortionConfig.color2r   = colorvalues[1] * 0.6
			crystalDistortion.distortionConfig.color2g   = colorvalues[2] * 0.6
			crystalDistortion.distortionConfig.color2b   = colorvalues[3] * 0.6
			crystalDistortion.distortionConfig.colortime = 0.002 + 0.01 / size


			crystalDistortion.distortionConfig.radius = (size + 0.2) * (crystalDistortion.distortionConfig.radius * 0.6)
			crystalDistortion.distortionConfig.posy = (size + 1.5) * crystalDistortion.distortionConfig.posy
			featureDefDistortions[FeatureDefNames[crystaldefname].id] = {crystalDistortion = crystalDistortion}
		end
	end
end
 

local allDistortions = {unitEventDistortions = unitEventDistortions, unitDefDistortions = unitDefDistortions, featureDefDistortions = featureDefDistortions}

----------------- Debugging code to do the reverse dump ---------------
--[[
local distortionParamKeyOrder = {	posx = 1, posy = 2, posz = 3, radius = 4,
	r = 9, g = 10, b = 11, a = 12,
	color2r = 5, color2g = 6, color2b = 7, colortime = 8, -- point distortions only, colortime in seconds for unit-attached
	dirx = 5, diry = 6, dirz = 7, theta = 8,  -- cone distortions only, specify direction and half-angle in radians
	pos2x = 5, pos2y = 6, pos2z = 7, -- beam distortions only, specifies the endpoint of the beam
	modelfactor = 13, specular = 14, scattering = 15, lensflare = 16,
	lifeTime = 18, sustain = 19, effectType = 20 
}

for typename, typetable in pairs(allDistortions) do
	Spring.Echo(typename)
	for distortionunitclass, classinfo in pairs(typetable) do
		if type(distortionunitclass) == type(1) then
			Spring.Echo(UnitDefs[distortionunitclass].name)
		else
			Spring.Echo(distortionunitclass)
		end
		for distortionname, distortioninfo in pairs(classinfo) do
			Spring.Echo(distortionname)
			local distortionParamTable = distortioninfo.distortionParamTable
			Spring.Echo(string.format("			distortionConfig = { posx = %f, posy = %f, posz = %f, radius = %f,", distortioninfo.distortionParamTable[1], distortionParamTable[2],distortionParamTable[3],distortionParamTable[4] ))
			if distortioninfo.distortionType == 'point' then
				Spring.Echo(string.format("				color2r = %f, color2g = %f, color2b = %f, colortime = %f,", distortioninfo.distortionParamTable[5], distortionParamTable[6],distortionParamTable[7],distortionParamTable[8] ))

			elseif distortioninfo.distortionType == 'beam' then
				Spring.Echo(string.format("				pos2x = %f, pos2y = %f, pos2z = %f,", distortioninfo.distortionParamTable[5], distortionParamTable[6],distortionParamTable[7]))
			elseif distortioninfo.distortionType == 'cone' then
				Spring.Echo(string.format("				dirx = %f, diry = %f, dirz = %f, theta = %f,", distortioninfo.distortionParamTable[5], distortionParamTable[6],distortionParamTable[7],distortionParamTable[8] ))

			end
			Spring.Echo(string.format("				r = %f, g = %f, b = %f, a = %f,", distortioninfo.distortionParamTable[9], distortionParamTable[10],distortionParamTable[11],distortionParamTable[12] ))
			Spring.Echo(string.format("				modelfactor = %f, specular = %f, scattering = %f, lensflare = %f,", distortioninfo.distortionParamTable[13], distortionParamTable[14],distortionParamTable[15],distortionParamTable[16] ))
			Spring.Echo(string.format("				lifeTime = %f, sustain = %f, effectType = %f},", distortioninfo.distortionParamTable[18], distortionParamTable[19],distortionParamTable[20]))

		end
	end
end
]]--

-- Icexuick Check-list


return allDistortions


