----------------------------------------------------------------------------------
--README
--for organizational purposes all unit deffs must be added to thge movedeff name.
-- formatted as such
--
	-- armfav/corfav                   <-- add unitdeffname here for the below movedeff type
	--TANK1 = {
	--	crushstrength = 10,
	--	footprintx = 2,
	--	footprintz = 2,
	--	maxslope = 18,
	--	slopeMod = 18,
	--	maxwaterdepth = 22,
	--	depthModParams = {
	--		minHeight = 4,
	--		linearCoeff = 0.03,
	--		maxValue = 0.7,
	--	}
	--},

----------------------------------------------------------------------------------
local moveDatas = {
					--all arm and core commanders and their decoys
	COMMANDERBOT = {
		crushstrength = 50,
		depthModParams = {
			minHeight = 0,
			maxScale = 1.5,
			quadraticCoeff = (9.9/22090)/2,
			linearCoeff = (0.1/470)/2,
			constantCoeff = 1,
			},
		footprintx = 3,
		footprintz = 3,
		maxslope = 36,
		maxwaterdepth = 5000,
		maxwaterslope = 50,
	},

	--corroach corsktl armvader
	ABOTBOMB2 = {
	 	crushstrength = 50,
	 	depthmod = 0,
	 	footprintx = 2,
	 	footprintz = 2,
	 	maxslope = 36,
	 	maxwaterdepth = 5000,
	 	maxwaterslope = 50,
	 	depthModParams = {
	 		constantCoeff = 1.5,
	 	},
	},

	--critter_crab raptor_land_spiker_basic_t2_v1 cormando raptor_land_spiker_basic_t4_v1 armaak corcrash raptorems2_spectre armjeth coramph coraak
	ABOT2 = {
		crushstrength = 50,
		depthmod = 0,
		footprintx = 2,
		footprintz = 2,
		maxslope = 36,
		maxwaterdepth = 5000,
		maxwaterslope = 50,
	},

	-- corgarp armbeaver armmar corparrow armprow corseal corsala cormuskrat armcroc armpincer corintr legassistdrone_land corassistdrone armassistdrone legotter corphantom
	ATANK3 = {
		crushstrength = 30,
		depthmod = 0,
		footprintx = 3,
		footprintz = 3,
		maxslope = 36,
		slopeMod = 18,
		maxwaterdepth = 5000,
		maxwaterslope = 80,
	},


	-- corcs armsjam corpt armdecade armtorps corshark critter_goldfish armcs correcl armrecl  corsupp  corsjam cormls armpt
	BOAT3 = {
		crushstrength = 9,
		footprintx = 3,
		footprintz = 3,
		minwaterdepth = 8,
	},
	--armmls armroy armaas corrsub corroy armship coracsub armserp  corpship  corarch
	BOAT4 = {
		crushstrength = 9,
		footprintx = 4,
		footprintz = 4,
		minwaterdepth = 8,
	},
	-- cruisers / missile ships / transport ships
	-- armtship cormship corcrus armmship cortship armcrus
	BOAT5 = {
		crushstrength = 16,
		footprintx = 5,
		footprintz = 5,
		minwaterdepth = 10,
	},

	-- armcarry armdronecarry armepoch corblackhy armbats corbats corcarry cordronecarry corsentinel armtrident coresuppt3
	BOAT8 = {
		crushstrength = 252,
		footprintx = 8,
		footprintz = 8,
		minwaterdepth = 15,
	},


	--critter_goldfish coracsub armacsub armserp corrsub armsubk correcl corshark corsub
	UBOAT4 = {
		footprintx = 4,
		footprintz = 4,
		minwaterdepth = 15,
		crushstrength = 5,
		subMarine = 1,
	},


	--corsh armah armch armsh
	HOVER2 = {
		badslope = 22,
		badwaterslope = 255,
		crushstrength = 25,
		footprintx = 2,
		footprintz = 2,
		maxslope = 22,
		slopeMod = 25,
		maxwaterslope = 255,
	},
	--OMG WE HAVE LOOT BOXES! BLAME DAMGAM NOW! damgam dm me with this message !
	-- corch cormh armmh corah corsnap armanac corhal lootboxsilver lootboxbronze legfloat
	HOVER3 = {
		badslope = 22,
		badwaterslope = 255,
		crushstrength = 25,
		footprintx = 3,
		footprintz = 3,
		maxslope = 22,
		slopeMod = 25,
		maxwaterslope = 255,
	},

	-- armlun corsok armthover corthovr lootboxgold lootboxplatinum
	HHOVER4 = {
		badslope = 22,
		badwaterslope = 255,
		crushstrength = 252,
		footprintx = 4,
		footprintz = 4,
		maxslope = 22,
		slopeMod = 18,
		maxwaterslope = 255,
	},

	-- armamph
	HOVER5 = {
		badslope = 36,
		badwaterslope = 255,
		crushstrength = 25,
		footprintx = 2,
		footprintz = 2,
		maxslope = 36,
		slopeMod = 18,
		maxwaterslope = 255,
	},

	-- cormlv armmflash corgator legmrv  leghades leghelops armfav corfav armconsul armlatnk cortorch legmrrv
	TANK2 = {
		crushstrength = 18,
		footprintx = 2,
		footprintz = 2,
		maxslope = 18,
		slopeMod = 18,
		maxwaterdepth = 22,
		depthModParams = {
			minHeight = 4,
			linearCoeff = 0.03,
			maxValue = 0.7,
		}
	},
	-- armjam corraid armjanus armsam armstump corwolv legcv corsent coreter corcv  cormist legrail legacv armacv armgremlin armmlv
	--armcv armart coracv corlevlr leggat legbar armseer armmart armyork corforge cormabm legvcarry corvrad cormart
	TANK3 = {
		crushstrength = 30,
		footprintx = 3,
		footprintz = 3,
		maxslope = 18,
		slopeMod = 18,
		maxwaterdepth = 22,
		depthModParams = {
			minHeight = 4,
			linearCoeff = 0.03,
			maxValue = 0.7,
		}
	},

	--corprinter corvac corvacct correap corftiger armbull legsco corvoc armmerl
	MTANK3 = {
		crushstrength = 250,
		footprintx = 3,
		footprintz = 3,
		maxslope = 18,
		slopeMod = 25,
		maxwaterdepth = 22,
		depthModParams = {
			minHeight = 4,
			linearCoeff = 0.03,
			maxValue = 0.7,
		}
	},
	-- corgol leginf corban cortrem armmanni armmerl legkeres legmed corsiegebreaker
	HTANK4 = {
		crushstrength = 252,
		footprintx = 4,
		footprintz = 4,
		maxslope = 18,
		slopeMod = 36,
		maxwaterdepth = 22,
		depthModParams = {
			minHeight = 4,
			linearCoeff = 0.03,
			maxValue = 0.7,
		}
	},
	-- armthor
	HTANK5 = {
		crushstrength = 1400,
		footprintx = 7,
		footprintz = 7,
		maxslope = 22,
		slopeMod = 42,
		maxwaterdepth = 24,
		depthModParams = {
			minHeight = 4,
			linearCoeff = 0.03,
			maxValue = 0.7,
		}
	},

	--armflea critter_ant dice critter_penguinbro critter_penguin critter_duck xmasballs chip
	-- make a suggestion thread critterh
	BOT1 = {
		crushstrength = 5,
		footprintx = 2,
		footprintz = 2,
		maxslope = 36,
		maxwaterdepth = 5,
		depthModParams = {
			minHeight = 4,
			linearCoeff = 0.03,
			maxValue = 0.7,
		}
	},

	--cornecro leggob legkark armpw armfark armrectr corak corfast corspy leglob armspy 
	BOT3 = {
		crushstrength = 15,
		footprintx = 2,
		footprintz = 2,
		maxslope = 36,
		maxwaterdepth = 22,
		depthModParams = {
			minHeight = 4,
			linearCoeff = 0.03,
			maxValue = 0.7,
		}
	},
	--  armfido leggstr corhrk armmav armfast armzeus
	BOT4 = {
		crushstrength = 25,
		footprintx = 3,
		footprintz = 3,
		maxslope = 36,
		maxwaterdepth = 22,
		depthModParams = {
			minHeight = 4,
			linearCoeff = 0.03,
			maxValue = 0.7,
		}
	},
	-- this movedeff dies when seperation distance is a current feature in bar
	-- corhrk
	BOT5 = {
		crushstrength = 25,
		footprintx = 4,
		footprintz = 4,
		maxslope = 36,
		maxwaterdepth = 22,
		depthModParams = {
			minHeight = 4,
			linearCoeff = 0.03,
			maxValue = 0.7,
		}
	},

	-- armraz legpede corcat leginc armfboy corsumo legmech cordemon
	HBOT4 = {
		crushstrength = 252,
		footprintx = 4,
		footprintz = 4,
		maxslope = 36,
		maxwaterdepth = 26,
		depthModParams = {
			minHeight = 4,
			linearCoeff = 0.03,
			maxValue = 0.7,
		}
	},
	-- corshiva armmar armbanth legjav
	HABOT5 = {
		crushstrength = 252,
		depthmod = 0,
		footprintx = 5,
		footprintz = 5,
		maxslope = 36,
		maxwaterdepth = 5000,
		maxwaterslope = 80,
	},
	-- armvang corkarg corthermite
	HTBOT4 = {
		crushstrength = 252,
		footprintx = 6,
		footprintz = 6,
		maxslope = 80,
		maxwaterdepth = 22,
		depthModParams = {
			minHeight = 4,
			linearCoeff = 0.03,
			maxValue = 0.7,
		}
	},
	-- corkorg legeheatraymech
	VBOT6 = {
		crushstrength = 1400,
		depthmod = 0,
		footprintx = 6,
		footprintz = 6,
		maxslope = 36,
		maxwaterdepth = 5000,
		maxwaterslope = 30,
	},
	-- corjugg
	HBOT7 = {
		crushstrength = 1400,
		footprintx = 7,
		footprintz = 7,
		maxslope = 36,
		maxwaterdepth = 30,
		depthModParams = {
			minHeight = 4,
			linearCoeff = 0.03,
			maxValue = 0.7,
		}
	},


	-- legsrail armscab armsptk cortermite armspid pbr_cube  dbg_sphere_fullmetal _dbgsphere leginfestor
	TBOT3 = {
		crushstrength = 15,
		footprintx = 3,
		footprintz = 3,
		maxwaterdepth = 22,
		depthmod = 0,
		depthModParams = {
			minHeight = 4,
			linearCoeff = 0.03,
			maxValue = 0.7,
		}
	},

	--Raptor Movedefs
	--raptor_queen_easy raptor_queen_normal raptor_queen_hard vc_raptorq raptor_queen_veryhard raptor_queen_epic raptor_matriarch_fire raptor_matriarch_acid raptor_matriarch_basic raptor_matriarch_healer
	--raptor_matriarch_spectre raptor_matriarch_electric
	RAPTORQUEENHOVER = {
		badslope = 22,
		badwaterslope = 255,
		crushstrength = 99999,
		depthmod = 0,
		footprintx = 4,
		footprintz = 4,
		maxslope = 255,
		maxwaterslope = 255,
		speedmodclass = 2, -- hover
	},
	-- raptor_land_swarmer_heal_t1_v1 raptor_land_swarmer_basic_t4_v2 raptor_land_swarmer_spectre_t4_v1 raptor_land_swarmer_basic_t4_v1 raptor_land_swarmer_emp_t2_v1 raptor_land_swarmer_basic_t1_v1 raptor_land_kamikaze_emp_t2_v1 raptor_land_spiker_basic_t4_v1
	--raptor_land_kamikaze_emp_t4_v1 raptor_land_spiker_basic_t2_v1 raptor_land_swarmer_basic_t3_v2 raptor_land_swarmer_basic_t3_v1 raptor_land_swarmer_basic_t3_v3 raptor_land_swarmer_basic_t2_v4 raptor_land_swarmer_basic_t2_v3 raptor_land_swarmer_basic_t2_v2 raptor_land_swarmer_basic_t2_v1 raptor_land_swarmer_brood_t3_v1 raptor_land_swarmer_brood_t4_v1
	--raptor_land_swarmer_brood_t2_v1 raptor_land_kamikaze_basic_t2_v1 raptor_land_kamikaze_basic_t4_v1  raptor_land_swarmer_fire_t4_v1 raptor_land_swarmer_acids_t2_v1 raptor_land_swarmer_spectre_t3_v1 raptor_land_swarmer_fire_t2_v1 raptorh5 raptor_land_spiker_spectre_t4_v1
	-- raptorh1b
	RAPTORSMALLHOVER = {
		badslope = 22,
		badwaterslope = 255,
		crushstrength = 25,
		depthmod = 0,
		footprintx = 2,
		footprintz = 2,
		maxslope = 36,
		slopeMod = 18,
		maxwaterslope = 255,
		speedmodclass = 2, -- hover
	},
	-- raptor_land_assault_emp_t2_v1 raptoracidassualt raptor_land_assault_basic_t2_v1 raptor_land_assault_basic_t2_v3 raptor_land_swarmer_basic_t2_v2 raptor_land_assault_spectre_t2_v1
	RAPTORBIGHOVER = {
		badslope = 22,
		badwaterslope = 255,
		crushstrength = 250,
		depthmod = 0,
		footprintx = 3,
		footprintz = 3,
		maxslope = 36,
		slopeMod = 18,
		maxwaterslope = 255,
		speedmodclass = 2, -- hover
	},
	-- raptor_land_assault_spectre_t4_v1 raptora2 raptor_land_assault_basic_t4_v2
	RAPTORBIG2HOVER = {
		badslope = 22,
		badwaterslope = 255,
		crushstrength = 1500,
		depthmod = 0,
		footprintx = 4,
		footprintz = 4,
		maxslope = 36,
		slopeMod = 18,
		maxwaterslope = 255,
		speedmodclass = 2, -- hover
	},
	-- raptor_allterrain_swarmer_basic_t2_v1 raptor_allterrain_swarmer_basic_t4_v1 raptor_allterrain_swarmer_basic_t3_v1 raptor_allterrain_swarmer_acid_t2_v1 raptor_allterrain_swarmer_fire_t2_v1 raptor_6legged_I raptoreletricalallterrain
	RAPTORALLTERRAINHOVER = {
		crushstrength = 50,
		depthmod = 0,
		footprintx = 2,
		footprintz = 2,
		maxslope = 255,
		maxwaterdepth = 5000,
		maxwaterslope = 50,
		speedmodclass = 2, -- hover
	},
	-- raptor_allterrain_arty_basic_t2_v1 raptor_allterrain_arty_acid_t2_v1 raptor_allterrain_arty_acid_t4_v1 raptor_allterrain_arty_emp_t2_v1 raptor_allterrain_arty_emp_t4_v1 raptor_allterrain_arty_brood_t2_v1 raptoracidalllterrrainassual
	--raptor_allterrain_swarmer_emp_t2_v1assualt raptor_allterrain_assault_basic_t2_v1 raptoraallterraina1 raptoraallterrain1c raptoraallterrain1b
	RAPTORALLTERRAINBIGHOVER = {
		crushstrength = 250,
		depthmod = 0,
		footprintx = 3,
		footprintz = 3,
		maxslope = 255,
		maxwaterdepth = 5000,
		maxwaterslope = 50,
		speedmodclass = 2, -- hover
	},
	-- raptor_allterrain_arty_basic_t4_v1 raptor_allterrain_arty_brood_t4_v1 raptorapexallterrainassualt raptorapexallterrainassualtb
	RAPTORALLTERRAINBIG2HOVER = {
		crushstrength = 250,
		depthmod = 0,
		footprintx = 4,
		footprintz = 4,
		maxslope = 255,
		maxwaterdepth = 5000,
		maxwaterslope = 50,
		speedmodclass = 2, -- hover
	},


	-- leghive armnanotc cornanotc cornanotcplat  raptor_worm_green raptor_turret_acid_t2_v1 raptor_turret_meteor_t4_v1
	NANO = {
		crushstrength = 0,
		footprintx = 3,
		footprintz = 3,
		maxslope = 18,
		maxwaterdepth = 0,
	},

	-- armcomboss corcomboss
	SCAVCOMMANDERBOT = {
		crushstrength = 50,
		depthModParams = {
			minHeight = 0,
			maxScale = 1.5,
			quadraticCoeff = (9.9/22090)/2,
			linearCoeff = (0.1/470)/2,
			constantCoeff = 1,
			},
		footprintx = 8,
		footprintz = 8,
		maxslope = 100,
		maxwaterdepth = 99999,
		maxwaterslope = 100,
	},


	-- scavmist  scavmistxl scavmisstxxl
	SCAVMIST = {
		badwaterslope = 255,
		--badslope = 255,
		maxslope = 255,
		crushstrength = 0,
		footprintx = 2,
		footprintz = 2,
		--maxwaterdepth = 22,
		maxwaterslope = 255,
		speedModClass = 2,
	},
	-- armpwt4 corakt4 armmeatball armassimilator armlunchbox
	EPICBOT = {
		crushstrength = 9999,
		depthmod = 0,
		footprintx = 4,
		footprintz = 4,
		maxslope = 36,
		maxwaterdepth = 9999,
		maxwaterslope = 50,
		speedModClass = 1,
	},
	-- corgolt4 armrattet4
	EPICVEH = {
		crushstrength = 9999,
		depthmod = 0,
		footprintx = 5,
		footprintz = 5,
		maxslope = 36,
		slopeMod = 18,
		maxwaterdepth = 9999,
		maxwaterslope = 50,
		speedModClass = 0,
	},


	-- corslrpc armdecadet3 armptt2 armpshipt3
	EPICSHIP = {
		crushstrength = 9999,
		footprintx = 5,
		footprintz = 5,
		maxslope = 255,
		minwaterdepth = 12,
		maxwaterdepth = 9999,
		maxwaterslope = 255,
		speedModClass = 3,
	},
	-- armvadert4 armsptkt4 corkargenetht4
	EPICALLTERRAIN = {
		crushstrength = 9999,
		depthmod = 0,
		footprintx = 5,
		footprintz = 5,
		maxslope = 255,
		maxwaterdepth = 9999,
		maxwaterslope = 255,
		speedModClass = 1,
	},
	-- armserpt3
	EPICSUBMARINE = {
		footprintx = 5,
		footprintz = 5,
		minwaterdepth = 15,
		maxwaterdepth = 9999,
		crushstrength = 9999,
		subMarine = 1,
		speedModClass = 3,
	},
}

--------------------------------------------------------------------------------
-- Final processing / array format
--------------------------------------------------------------------------------
local defs = {}

for moveName, moveData in pairs(moveDatas) do
	moveData.heatmapping = true
	moveData.name = moveName
	moveData.allowRawMovement = true
	moveData.allowTerrainCollisions = false
	if moveName and string.find(moveName, "BOT") and moveData.maxslope then
		moveData.slopemod = 4
	end

	defs[#defs + 1] = moveData
end

return defs
