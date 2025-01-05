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
		lifeTime = 0, sustain = 1, 	aninmtype = 0 -- unused
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

	
	['armmakr'] = {
		distortion = {
			distortionType = 'point',
			pieceName = 'base',
			distortionConfig = { posx = 0, posy = 2, posz = 0, radius = 20,
							noiseStrength = 0.6, noiseScaleSpace = 1.5, distanceFalloff = 0.5,
							lifeTime = 0, rampUp = 30, decay = -1.5,
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

	['corkorg'] = {
		engineheatr = {
			distortionType = 'point',
			pieceName = 'ruparm',
			distortionConfig = { posx = -10, posy = -5, posz = -16, radius = 22,
							noiseStrength = 0.5, noiseScaleSpace = 2, distanceFalloff = 0.8,
							windAffected = -0.5, riseRate = -2,
							lifeTime = 0,  effectType = 'heatDistortion'},
		},
		engineheatl = {
			distortionType = 'point',
			pieceName = 'luparm',
			distortionConfig = { posx = 10, posy = -5, posz = -16, radius = 22,
							noiseStrength = 0.5, noiseScaleSpace = 2, distanceFalloff = 0.8,
							windAffected = -0.5, riseRate = -2,
							lifeTime = 0,  effectType = 'heatDistortion'},
		},
	},
	['armadvsol'] = {
		magnifier = {
			distortionType = 'point',
			pieceName = 'base',
			distortionConfig = { posx = 0, posy = 100, posz = 0, radius = 50,
							lifeTime = 0,  
							magnificationRate = 4.0, effectType = "magnifier"}, 
		},
	},

	['armhawk'] = {
		thrust = {
			distortionType = 'cone',
			pieceName = 'thrust',
			distortionConfig = { posx = 0, posy = 0, posz = 20, radius = 100,
							dirx =  0, diry = -0, dirz = -1.0, theta = 0.2,
							noiseStrength = 1, noiseScaleSpace = 1,
							lifeTime = 0,  effectType = 0},
		},
	},

	['armtide'] = {
		waterflow = {
			distortionType = 'beam',
			pieceName = 'wheel',
			distortionConfig = { posx = 0, posy = -2.2, posz = -18, radius = 12,
								pos2x = 0, pos2y = -2.2, pos2z = 18, radius2 = 12, 
								noiseStrength = 2.5, noiseScaleSpace = 0.7, distanceFalloff = 0.5,
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
		motionBlur = {
			distortionType = 'point',
			pieceName = 'base',
			distortionConfig = { posx = 0, posy = 7.5, posz = 0.01, radius = 23,
							pos2x = 0, pos2y = 100, pos2z = 0, radius2 = 23, 
							noiseScaleSpace = 1, onlyModelMap = -1,
							lifeTime = 0,  effectType = 11},
		},
	},

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
		snipecloakbeam = {
			distortionType = 'beam',
			pieceName = 'base',
			distortionConfig = { posx = 0, posy = 7.5, posz = 0.01, radius = 15,
							pos2x = 0, pos2y = 30, pos2z = 0, radius2 = 15, 
							
							noiseStrength = 3, noiseScaleSpace = -1.5, distanceFalloff = 0.25, onlyModelMap = -1,
							lifeTime = 0,  effectType = 0},
		},
	},

	['armspy'] = {
		spycloakbeam = {
			distortionType = 'beam',
			pieceName = 'base',
			distortionConfig = { posx = 0, posy = 2.5, posz = 0.01, radius = 15,
							pos2x = 0, pos2y = 30, pos2z = 0, radius2 = 15, 
							
							noiseStrength = 3, noiseScaleSpace = 1.5, distanceFalloff = 0.25, onlyModelMap = -1,
							lifeTime = 0,  effectType = 0},
		},
	},

	['armveil'] = {
		magnifier = {
			distortionType = 'point',
			pieceName = 'base',
			distortionConfig = { posx = 0, posy = 90, posz = 0, radius = 20,
							lifeTime = 0,  
							magnificationRate = 10.0, effectType = "magnifier"}, 
		},
	}, 

	
	['corfus'] = {
		distortion = {
			distortionType = 'point',
			pieceName = 'emit',
			distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 22,
							noiseStrength = 1.5, noiseScaleSpace = 2.0, distanceFalloff = 0.5,
							windAffected =0.21, riseRate = -2,
							lifeTime = 0,  effectType = 0},
		},
	},
	
	['corafus'] = {
		distortion = {
			distortionType = 'point',
			pieceName = 'emit',
			distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 36,
							noiseStrength = 1, noiseScaleSpace = 2.0, distanceFalloff = 0.5,
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
			distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 30,
							noiseStrength = 0.7, noiseScaleSpace = 1.0, distanceFalloff = 0.5,
							riseRate = -2,
							--decay = 3.5,
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
			distortionConfig = { posx = 0, posy = 40, posz = 0, radius = 16,
							noiseStrength = 1, noiseScaleSpace = 1.5, distanceFalloff = 0.5,
							windAffected = -0.5,
							lifeTime = 0,  effectType = 0},
		},
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
			pieceName = 'none',
			distortionConfig = { posx = 0, posy = 46, posz = 0, radius = 12,
							noiseStrength = 10, noiseScaleSpace = 0.4, distanceFalloff = 1.5,
							windAffected = -1,
							lifeTime = 0,  effectType = 0},
		},
	},

	['armjamt'] = {
		distortion = {
			distortionType = 'point',
			pieceName = 'none',
			distortionConfig = { posx = 0, posy = 58, posz = 0, radius = 12,
							noiseStrength = 10, noiseScaleSpace = 0.4, distanceFalloff = 1.5,
							windAffected = -1,
							lifeTime = 0,  effectType = 0},
		},
	},

	['corjuno'] = {
		distortion = {
			distortionType = 'point',
			pieceName = 'none',
			distortionConfig = { posx = 0, posy = 72, posz = 0, radius = 16,
							noiseStrength = 1, noiseScaleSpace = 1.5, distanceFalloff = 0.5,
							windAffected = -0.5,
							lifeTime = 0,  effectType = 0},
		},
	},

	
	['armjuno'] = {
		distortion = {
			distortionType = 'point',
			pieceName = 'none',
			distortionConfig = { posx = 0, posy = 72, posz = 0, radius = 16,
							noiseStrength = 1, noiseScaleSpace = 1.5, distanceFalloff = 0.5,
							windAffected = -0.5,
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
							riseRate = 4, lifeTime = 0,  effectType = 0},
		},

		thrust2 = {
			distortionType = 'cone',
			pieceName = 'thrustrla',
			distortionConfig = { posx = -2, posy = 0, posz = -2, radius = 80,
							dirx = 0, diry = 0, dirz = -1, theta = 0.4,
							noiseStrength = 1, noiseScaleSpace = 0.65,
							riseRate = 4, lifeTime = 0,  effectType = 0},
		},
		thrust3 = {
			distortionType = 'cone',
			pieceName = 'thrustfla',
			distortionConfig = { posx = -2, posy = 0, posz = -2, radius = 80,
							dirx = 0, diry = 0, dirz = -1, theta = 0.4,
							noiseStrength = 1, noiseScaleSpace = 0.65,
							riseRate = 4, lifeTime = 0,  effectType = 0},
		},
		thrust4 = {
			distortionType = 'cone',
			pieceName = 'thrustfra',
			distortionConfig = { posx = -2, posy = 0, posz = -2, radius = 80,
							dirx = 0, diry = 0, dirz = -1, theta = 0.4,
							noiseStrength = 1, noiseScaleSpace = 0.65,
							riseRate = 4, lifeTime = 0,  effectType = 0},
		},
	},
}


-- Effect duplications:
unitDistortions['armdecom'] = unitDistortions['armcom']

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
								noiseStrength = 1.2, noiseScaleSpace = 0.5, distanceFalloff = 0.2, onlyModelMap = 1, 
								distortionMultiplier = 1.0, --needed for shockwave
								lifeTime = 25, rampUp = 0, decay = 15,
								shockWidth = 5, effectType = 2},
	
			},
		},

				
		['armbrtha'] = {
			[1] = {
				-- Footstep shockwave
				alwaysVisible = false,
				distortionType = 'beam',
				distortionName = 'armbrthabarrelheat',
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
	lifeTime = 18, sustain = 19, effectType = 20 -- unused
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


