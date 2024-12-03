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
	['corafus'] = {
		fusionglow = {
			distortionType = 'point',
			pieceName = 'emit',
			distortionConfig = { posx = 0, posy = 0, posz = 0, radius = 150,
							lifeTime = 0,  effectType = 1},
		},
	},
	['armsolar'] = {
		distortion = {
			distortionType = 'point',
			pieceName = 'emit',
			distortionConfig = { posx = 0, posy = 2, posz = 0, radius = 33,
							noiseStrength = 0.5, noiseScaleSpace = 1.5, distanceFalloff = 2.0,
							lifeTime = 0,  rampUp = 300, decay = -2.0,
							effectType = 0},
		},
	},

	
	['armmakr'] = {
		distortion = {
			distortionType = 'point',
			pieceName = 'base',
			distortionConfig = { posx = 0, posy = 2, posz = 0, radius = 20,
							noiseStrength = 0.5, noiseScaleSpace = 1.5, distanceFalloff = 0.5,
							lifeTime = 0, rampUp = 30, decay = -2.0,
							effectType = 0},
		},
	},
	['armestor'] = {
		distortion = {
			distortionType = 'beam',
			pieceName = 'base',
			distortionConfig = { posx = 0, posy = -6.5, posz = 0.01, radius = 23,
								pos2x = 0, pos2y = 20, pos2z = 0, radius2 = 23, 
								noiseStrength = 0.5, noiseScaleSpace = -1, distanceFalloff = 0.5,
								rampUp = 30, decay = -1.3,
								lifeTime = 0,  effectType = 0},

		},
	},

	['armbull'] = {
		distortion = {
			distortionType = 'point',
			pieceName = 'base',
			distortionConfig = { posx = 0, posy = 20, posz = -10, radius = 20,
							noiseStrength = 0.3, noiseScaleSpace = -3.1, distanceFalloff = 1.5,
							lifeTime = 0,  effectType = 'heatDistortion'},
		},
	},
	['armadvsol'] = {
		magnifier = {
			distortionType = 'point',
			pieceName = 'base',
			distortionConfig = { posx = 0, posy = 100, posz = 0, radius = 50,
							lifeTime = 0,  effectType = "magnifier"}, 
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

	['corvamp'] = {
		thrust = {
			distortionType = 'cone',
			pieceName = 'thrust',
			distortionConfig = { posx = 0, posy = 0, posz = 20, radius = 100,
							dirx =  0, diry = -0, dirz = -1.0, theta = 0.2,
							noiseStrength = 1, noiseScaleSpace = -1,
							lifeTime = 0,  effectType = 0},
		},
	},

	['armpeep'] = {
		motionBlur = {
			distortionType = 'point',
			pieceName = 'base',
			distortionConfig = { posx = 0, posy = 7.5, posz = 0.01, radius = 23,
							pos2x = 0, pos2y = 100, pos2z = 0, radius2 = 23, 
							noiseScaleSpace = 1,onlyModelMap = -1,
							lifeTime = 0,  effectType = 11},
		},
	},

	['armck'] = {
		beamDistortion = {
			distortionType = 'beam',
			pieceName = 'base',
			distortionConfig = { posx = 0, posy = 7.5, posz = 0.01, radius = 23,
							pos2x = 0, pos2y = 100, pos2z = 0, radius2 = 23, 
							noiseScaleSpace = 1,
							lifeTime = 0,  effectType = 0},
		},
	},
	['corck'] = {
		beamDistortion = {
			distortionType = 'beam',
			pieceName = 'base',
			distortionConfig = { posx = 0, posy = 7.5, posz = 0.01, radius = 23,
							pos2x = 0, pos2y = 100, pos2z = 0, radius2 = 23, 
							noiseScaleSpace = -1,
							lifeTime = 0,  effectType = 0},
		},
	},

	['armsnipe'] = {
		snipecloakbeam = {
			distortionType = 'beam',
			pieceName = 'base',
			distortionConfig = { posx = 0, posy = 7.5, posz = 0.01, radius = 15,
							pos2x = 0, pos2y = 30, pos2z = 0, radius2 = 15, 
							
							noiseStrength = 1, noiseScaleSpace = -1.5, distanceFalloff = 0.25, onlyModelMap = -1,
							lifeTime = 0,  effectType = 0},
		},
	},

	['armspy'] = {
		spycloakbeam = {
			distortionType = 'beam',
			pieceName = 'base',
			distortionConfig = { posx = 0, posy = 2.5, posz = 0.01, radius = 15,
							pos2x = 0, pos2y = 30, pos2z = 0, radius2 = 15, 
							
							noiseStrength = 1, noiseScaleSpace = 1.5, distanceFalloff = 0.25, onlyModelMap = -1,
							lifeTime = 0,  effectType = 0},
		},
	},

	
	['corfus'] = {
		distortion = {
			distortionType = 'point',
			pieceName = 'emit',
			distortionConfig = { posx = 0, posy = 2, posz = 0, radius = 30,
							noiseStrength = 1, noiseScaleSpace = 1.5, distanceFalloff = 0.5,
							lifeTime = 0,  effectType = 0},
		},
	},


	['corcrwh'] = {

		thrust1 = {
			distortionType = 'cone',
			pieceName = 'thrustrra',
			distortionConfig = { posx = -2, posy = 0, posz = -2, radius = 120,
							dirx = 0, diry = 0, dirz = -1, theta = 0.74,
							noiseStrength = 1,
							lifeTime = 0,  effectType = 0},
		},

		thrust2 = {
			distortionType = 'cone',
			pieceName = 'thrustrla',
			distortionConfig = { posx = -2, posy = 0, posz = -2, radius = 120,
							dirx = 0, diry = 0, dirz = -1, theta = 0.74,
							noiseStrength = 1,
							lifeTime = 0,  effectType = 0},
		},
		thrust3 = {
			distortionType = 'cone',
			pieceName = 'thrustfla',
			distortionConfig = { posx = -2, posy = 0, posz = -2, radius = 120,
							dirx = 0, diry = 0, dirz = -1, theta = 0.74,
							noiseStrength = 1,
							lifeTime = 0,  effectType = 0},
		},
		thrust4 = {
			distortionType = 'cone',
			pieceName = 'thrustfra',
			distortionConfig = { posx = -2, posy = 0, posz = -2, radius = 120,
							dirx = 0, diry = 0, dirz = -1, theta = 0.74,
							noiseStrength = 1,
							lifeTime = 0,  effectType = 0},
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
				distortionConfig = { posx = 0, posy = 0, posz = 8, radius = 200,
								lifeTime = 25,  effectType = 2},
	
			},
		},
	},




	------------------------------- Put additional distortions tied to events here! --------------------------------
	UnitIdle =  {
		['armcom'] = {
			idleBlink = {
				distortionType = 'point',
				pieceName = 'head',
				distortionConfig = { posx = 0, posy = 22, posz = 12, radius = 90,
					lifeTime = 12,  effectType = 0},
			},
		},
	},

	UnitFinished = {
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
	},

	UnitCreated = {
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
	},

	UnitCloaked = {
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
					lifeTime = 15, sustain = 2, effectType = 0},
			},
		},
	},

	UnitDecloaked = {
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
					lifeTime = 15, sustain = 2, effectType = 0},
			},
		},
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
		default = {
			default = {
				distortionType = 'cone',
				pieceName = '',
				aboveUnit = 100,
				distortionConfig = { posx = 0, posy = 32, posz = 0, radius = 200,
					dirx = 0, diry = -0.99, dirz = 0.02, theta = 0.4,
					lifeTime = 15, sustain = 2, effectType = 0},
			},
		},
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
			distortionConfig = { posx = 0, posy = 12, posz = 0, radius = 72,
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


