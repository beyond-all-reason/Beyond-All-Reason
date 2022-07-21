-- multiple lights per unitdef/piece are possible, as the lights are keyed by lightname

local unitDefLights = {
	[UnitDefNames['armpw'].id] = {
		headlightpw = { -- this is the lightname
			lighttype = 'cone',
			pieceName = 'justattachtobase', -- invalid ones will attack to the worldpos of the unit
			lightParamTable = {0,23,7,150, --pos + height
								0,-0.07,1, 0.30, -- dir + angle
								1,1,0.9,0.6, -- RGBA
								-0.33,1,1.5,0.6, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
		-- dicklight = {
		-- 	lighttype = 'point',
		-- 	pieceName = 'pelvis',
		-- 	lightParamTable = {50,10,4,100, --pos + radius
		-- 						0,0,0, 0, -- color2
		-- 						1,1,1,0, -- RGBA
		-- 						1,1,1,1, -- modelfactor_specular_scattering_lensflare
		-- 						0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
		--						0,0,0,0, -- color2
		-- 						0, -- pieceIndex
		-- 						0,0,0,0 -- instData always 0!
		-- 						},
		-- 	--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		-- },
		-- gunlight = {
		-- 	lighttype = 'beam',
		-- 	pieceName = 'lthigh',
		-- 	lightParamTable = {0,0,0,150, --pos + radius
		-- 						150,150,150, 0, -- endpos
		-- 						1,1,1,1, -- RGBA
		-- 						1,1,1,1, -- modelfactor_specular_scattering_lensflare
		-- 						0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
		--						0,0,0,0, -- color2
		-- 						0, -- pieceIndex
		-- 						0,0,0,0 -- instData always 0!
		-- 						},
		-- 	--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		-- },
	},
	[UnitDefNames['armrad'].id] = {
		-- searchlight = {
		-- 	lighttype = 'cone',
		-- 	pieceName = 'dish',
		-- 	lightParamTable = {0,0,0,70, --pos + radius
		-- 						0,0,-1, 0.2, -- dir + angle
		-- 						0.5,3,0.5,1, -- RGBA
		-- 						0.5,1,2,0, -- modelfactor_specular_scattering_lensflare
		-- 						0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
		--						0,0,0,0, -- color2
		-- 						0, -- pieceIndex
		-- 						0,0,0,0 -- instData always 0!
		-- 						},
		-- 	--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		-- },
		greenblob = {
				lighttype = 'point',
				pieceName = 'turret',
				lightParamTable = {0,72,0,20, --pos + radius
								0,0,0,0, -- color2
								0,1,0,0.6, -- RGBA
								0.8,0.9,1.0,10, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['corrad'].id] = {
		greenblob = {
				lighttype = 'point',
				pieceName = 'turret',
				lightParamTable = {0,82,0,20, --pos + radius
								0,0,0,0, -- color2
								0,1,0,0.6, -- RGBA
								0.8,0.9,1.0,10, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},

	[UnitDefNames['armllt'].id] = {
		searchlightllt = {
			lighttype = 'cone',
			pieceName = 'sleeve',
			lightParamTable = {0,5,5.8,450, --pos + radius
								0,0,1,0.25, -- dir + angle
								1,1,1,0.5, -- RGBA
								0.2,1,1,1, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['corllt'].id] = {
		searchlightllt = {
			lighttype = 'cone',
			pieceName = 'turret',
			lightParamTable = {0,5,5.8,450, --pos + radius
								0,0,1,0.25, -- dir + angle
								1,1,1,0.5, -- RGBA
								0.2,1,1,1, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['armrl'].id] = {
		searchlightrl = {
			lighttype = 'cone',
			pieceName = 'sleeve',
			lightParamTable = {0,0,7,450, --pos + radius
								0,0,1,0.20, -- dir + angle
								1,1,1,1, -- RGBA
								1,1,1,1, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['armjamt'].id] = {
		-- searchlight = {
		-- 	lighttype = 'cone',
		-- 	pieceName = 'turret',
		-- 	lightParamTable = {0,0,3,65, --pos + radius
		-- 						0,-0.4,1, 1, -- dir + angle
		-- 						1.2,0.1,0.1,1.2, -- RGBA
		-- 						1,1,1,1, -- modelfactor_specular_scattering_lensflare
		-- 						0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
		--						0,0,0,0, -- color2
		-- 						0, -- pieceIndex
		-- 						0,0,0,0 -- instData always 0!
		-- 						},
		-- 	--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		-- },
		cloaklightred = {
				lighttype = 'point',
				pieceName = 'turret',
				lightParamTable = {0,30,0,35, --pos + radius
								0,0,1,0, -- unused
								1,0,0,0.5, -- RGBA
								0.5,0.5,1.5,10, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['armack'].id] = {
		beacon1 = { -- this is the lightname
			lighttype = 'cone',
			pieceName = 'beacon1',
			lightParamTable = {0,0,0,21, --pos + radius
								1,0,0, 0.99, -- dir + angle
								1.3,0.9,0.1,2, -- RGBA
								0.1,0.2,1.5,10, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
		beacon2 = {
			lighttype = 'cone',
			pieceName = 'beacon2',
			lightParamTable = {0,0,0,21, --pos + radius
								-1,0,0, 0.99, -- dir + angle
								1.3,0.9,0.1,2, -- RGBA
								0.1,0.2,1.5,10, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['armstump'].id] = {
		searchlightstump = {
			lighttype = 'cone',
			pieceName = 'base',
			lightParamTable = {0,0,10,100, --pos + radius
								0,-0.08,1, 0.26, -- dir + angle
								1,1,1,1.2, -- RGBA
								1,1,1,1, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['armbanth'].id] = {
		searchlightbanth = {
			lighttype = 'cone',
			pieceName = 'turret',
			lightParamTable = {0,2,18,520, --pos + radius
								0,-0.12,1, 0.26, -- dir + angle
								1,1,1,1, -- RGBA
								0.1,1,1,1, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},	
	[UnitDefNames['armcom'].id] = {
		headlightarmcom = {
			lighttype = 'cone',
			pieceName = 'head',
			lightParamTable = {0,0,10,420, --pos + radius
								0,-0.25,1, 0.26, -- dir + angle
								-1,1,1,1, -- RGBA
								0.2,2,3,1, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
		-- lightsaber = {
		-- 	lighttype = 'beam',
		-- 	pieceName = 'dish',
		-- 	lightParamTable = {0,0,4,80, --pos + radius
		-- 						0,0, 300 , 40, -- pos2
		-- 						1,0,0,1, -- RGBA
		-- 						1,1,0.3,1, -- modelfactor_specular_scattering_lensflare
		-- 						0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
		--						0,0,0,0, -- color2
		-- 						0, -- pieceIndex
		-- 						0,0,0,0 -- instData always 0!
		-- 						},
		-- 	--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		-- },
	},
	[UnitDefNames['corcom'].id] = {
		headlightarmcom = {
			lighttype = 'cone',
			pieceName = 'head',
			lightParamTable = {0,1,9,420, --pos + radius
								0,-0.17,1, 0.26, -- dir + angle
								-1,1,1,1, -- RGBA
								1,2,3,1, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['armcv'].id] = {
		nanolightarmcv = {
			lighttype = 'cone',
			pieceName = 'nano1',
			lightParamTable = {3,0,-4,120, --pos + radius
								0,0,1, 0.3, -- pos2
								-1,0,0,1, -- RGBA
								0,1,3,0, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['armca'].id] = {
		nanolightarmca = {
			lighttype = 'cone',
			pieceName = 'nano',
			lightParamTable = {0,0,0,120, --pos + radius
								0,0,-1, 0.3, -- pos2
								-1,0,0,1, -- RGBA
								0,1,3,0, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['armamd'].id] = {
		readylightamd = {
				lighttype = 'point',
				pieceName = 'antenna',
				lightParamTable = {0,1,0,21, --pos + radius
								0,0.5,0,15, -- color2
								0,2,0,1, -- RGBA
								1,1,1,6, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['armaap'].id] = {
		blinkaap = {
				lighttype = 'point',
				pieceName = 'base',
				lightParamTable = {-86,91,3,75, --pos + radius
								0,0,0,0, -- color2
								-1,1,1,0.5, -- RGBA
								0.2,0.5,1,10, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['armatlas'].id] = {
		jetr = {
			lighttype = 'cone',
			pieceName = 'thrustr',
			lightParamTable = {-2,0,-2,140, --pos + radius
								0,0,-1, 0.8, -- pos2
								1,0.98,0.85,0.4, -- RGBA
								0,1,0.5,1, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
		jetl = {
				lighttype = 'cone',
			pieceName = 'thrustl',
			lightParamTable = {2,0,-2,140, --pos + radius
								0,0,-1, 0.8, -- pos2
								1,0.98,0.85,0.4, -- RGBA
								0,1,0.5,1, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['armeyes'].id] = {
		eyeglow = {
				lighttype = 'point',
				pieceName = 'base',
				lightParamTable = {0,10,0,300, --pos + radius
								0,0,0,0, -- unused
								1,1,1,0.3, -- RGBA
								0.1,0.5,1,2, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['armanni'].id] = {
		annilight = {
			lighttype = 'cone',
			pieceName = 'light',
			lightParamTable = {0,0,0,950, --pos + radius
								0,0,1, 0.07, -- pos2
								1,1,1,0.5, -- RGBA
								0,1,2,0, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['armafus'].id] = {
		controllight = {
			lighttype = 'cone',
			pieceName = 'collar1',
			lightParamTable = {-25,38,-25,100, --pos + radius
								1,0,1, 0.5, -- pos2
								-1,1,1,5, -- RGBA
								0.1,1,2,2, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
		fusionglow = {
				lighttype = 'point',
				pieceName = 'base',
				lightParamTable = {0,45,0,90, --pos + radius
								0,0,0,0, -- color2 + colortime
								-1,1,1,0.9, -- RGBA
								0.1,0.5,1,5, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['armzeus'].id] = {
		weaponglow = {
			lighttype = 'point',
			pieceName = 'gun_emit',
			lightParamTable = {0,0,0,10, --pos + radius
							0.4,0.7,1.2,30, -- color2 + colortime
							0.2,0.5,1.0,0.8, -- RGBA
							0.1,0.75,2,7, -- modelfactor_specular_scattering_lensflare
							0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
							0,0,0,0, -- color2
							0, -- pieceIndex
							0,0,0,0 -- instData always 0!
							},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
		weaponspark = {
			lighttype = 'point',
			pieceName = 'spark_emit',
			lightParamTable = {0,1,0,55, --pos + radius
							0,0,0,2, -- color2
							1,1,1,0.85, -- RGBA
							0.1,0.75,0.2,7, -- modelfactor_specular_scattering_lensflare
							0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
							0,0,0,0, -- color2
							0, -- pieceIndex
							0,0,0,0 -- instData always 0!
							},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
		backpackglow = {
			lighttype = 'point',
			pieceName = 'static_emit',
			lightParamTable = {0,0,0,10, --pos + radius
							0.4,0.7,1.2,30, -- color2 + colortime
							0.2,0.5,1.0,0.8, -- RGBA
							0.1,0.75,2,10, -- modelfactor_specular_scattering_lensflare
							0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
							0,0,0,0, -- color2
							0, -- pieceIndex
							0,0,0,0 -- instData always 0!
							},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['corpyro'].id] = {
		flamelight = {
			lighttype = 'point',
			pieceName = 'lloarm',
			lightParamTable = {0,-1.4,15,24, --pos + radius
							0.9,0.5,0.05,10, -- unused
							0.95,0.66,0.07,0.56, -- RGBA
							0.1,1.5,0.35,0, -- modelfactor_specular_scattering_lensflare
							0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
							0,0,0,0, -- color2
							0, -- pieceIndex
							0,0,0,0 -- instData always 0!
							},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['armsnipe'].id] = {
		sniperreddot = {
			lighttype = 'cone',
			pieceName = 'laser',
			lightParamTable = {0,0,0,700, --pos + radius
								0,1,0.0001, 0.006, -- pos2
								2,0,0,0.85, -- RGBA
								0.1,4,2,4, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['cormakr'].id] = {
		flamelight = {
			lighttype = 'point',
			pieceName = 'light',
			lightParamTable = {0,10,0,50, --pos + radius
							0,0,0,0, -- color2 + colortime
							0.9,0.7,0.45,0.58, -- RGBA
							0.1,1.5,0.35,0, -- modelfactor_specular_scattering_lensflare
							0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
							0,0,0,0, -- color2
							0, -- pieceIndex
							0,0,0,0 -- instData always 0!
							},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['lootboxbronze'].id] = {
		blinka = {
				lighttype = 'point',
				pieceName = 'blinka',
				lightParamTable = {0,1,0,25, --pos + radius
								0,0,0,0, -- color2
								-1,1,1,0.85, -- RGBA
								1,1,1,10, -- modelfactor_specular_scattering_lensflare
								1,120,0,1, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
		blinkb = {
				lighttype = 'point',
				pieceName = 'blinkb',
				lightParamTable = {0,1,0,25, --pos + radius
								0,0,0,0, -- color2
								-1,1,1,0.85, -- RGBA
								1,1,1,10, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
		blinkc = {
				lighttype = 'point',
				pieceName = 'blinkc',
				lightParamTable = {0,1,0,25, --pos + radius
								0,0,0,0, -- color2
								-1,1,1,0.85, -- RGBA
								1,1,1,10, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
		blinkd = {
				lighttype = 'point',
				pieceName = 'blinkd',
				lightParamTable = {0,1,0,25, --pos + radius
								0,0,0,0, -- color2
								-1,1,1,0.85, -- RGBA
								1,1,1,10, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['armaap'].id] = {
		blinka = {
				lighttype = 'point',
				pieceName = 'blinka',
				lightParamTable = {0,1,0,20, --pos + radius
								0,0,0,0, -- color2
								-1,1,1,1, -- RGBA
								0.2,0.5,2,7, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
		dishlight = {
				lighttype = 'point',
				pieceName = 'dish',
				lightParamTable = {0,8,0,20, --pos + radius
								-1,-1,-1,30, -- color2
								-1,1,1,1, -- RGBA
								0.2,0.5,2,7, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
		blinkb = {
				lighttype = 'point',
				pieceName = 'blinkb',
				lightParamTable = {0,1,0,20, --pos + radius
								0,0,0,0, -- color2
								-1,1,1,1, -- RGBA
								0.2,0.5,2,7, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['corsilo'].id] = {
		launchlight1 = { -- this is the lightname
			lighttype = 'cone',
			pieceName = 'cagelight_emit1',
			lightParamTable = {0,0,0,30, --pos + radius
								1,0,0, 0.99, -- dir + angle
								1.3,0.1,0,2, -- RGBA
								0.1,0.2,1,2, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
		launchlight2 = { -- this is the lightname
			lighttype = 'cone',
			pieceName = 'cagelight_emit2',
			lightParamTable = {0,0,0,30, --pos + radius
								1,0,0, 0.99, -- dir + angle
								1.3,0.1,0,2, -- RGBA
								0.1,0.2,1,2, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
		launchlight3 = { -- this is the lightname
			lighttype = 'cone',
			pieceName = 'cagelight_emit3',
			lightParamTable = {0,0,0,30, --pos + radius
								1,0,0, 0.99, -- dir + angle
								1.3,0.1,0,2, -- RGBA
								0.1,0.2,1,2, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
		launchlight4 = { -- this is the lightname
			lighttype = 'cone',
			pieceName = 'cagelight_emit4',
			lightParamTable = {0,0,0,30, --pos + radius
								1,0,0, 0.99, -- dir + angle
								1.3,0.1,0,2, -- RGBA
								0.1,0.2,1,2, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['corint'].id] = {
		hotbarrel1 = {
				lighttype = 'point',
				pieceName = 'light',
				lightParamTable = {-7,8,5,30, --pos + radius
								0,0,1,0, -- unused
								1,0.2,0,0.7, -- RGBA
								2,1,0,0, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
		hotbarrel2 = {
				lighttype = 'point',
				pieceName = 'light',
				lightParamTable = {7,8,5,30, --pos + radius
								0,0,1,0, -- unused
								1,0.2,0,0.7, -- RGBA
								2,1,0,0, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['corlab'].id] = {
		buildlight = { -- this is the lightname
			lighttype = 'cone',
			pieceName = 'cagelight_emit',
			lightParamTable = {0,0,0,17, --pos + radius
								1,0,0, 0.99, -- dir + angle
								1.3,0.9,0.1,2, -- RGBA
								0.1,0.2,1.5,10, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
		buildlight2 = { -- this is the lightname
			lighttype = 'cone',
			pieceName = 'cagelight_emit',
			lightParamTable = {0,0,0,17, --pos + radius
								-1,0,0, 0.99, -- dir + angle
								1.3,0.9,0.1,2, -- RGBA
								0.1,0.2,1.5,10, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['corck'].id] = {
		buildlight = { -- this is the lightname
			lighttype = 'cone',
			pieceName = 'cagelight_emit',
			lightParamTable = {0,0,0,17, --pos + radius
								1,0,0, 0.99, -- dir + angle
								1.3,0.9,0.1,2, -- RGBA
								0.1,0.2,2,10, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
		buildlight2 = { -- this is the lightname
			lighttype = 'cone',
			pieceName = 'cagelight_emit',
			lightParamTable = {0,0,0,17, --pos + radius
								-1,0,0, 0.99, -- dir + angle
								1.3,0.9,0.1,2, -- RGBA
								0.1,0.2,2,10, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
}

local unitEventLights = {
	[UnitDefNames['armcom'].id] = {
		idleBlink = {
			lighttype = 'point',
			pieceName = 'head',
			lightParamTable = {0,16,0,420, --pos + radius
								1,1,1, 15, -- color2
								-1,1,1,1, -- RGBA
								0.2,1,1,1, -- modelfactor_specular_scattering_lensflare
								0,50,20,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	}
}
