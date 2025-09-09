----------------------------------------------------------------------------------
-- README
-- 1. Format all movedefs consistently, as below, including a list of unit names.
-- 2. Strongly prefer reference values, or reference values with offsets (+/-X).
-- 3. Use consistent moveDef names, as below:
--  > DEFNAME := [Special][Weight class][Mobility]Category[Footprint]
--  > Special := COMMANDER: Commanders | EPIC: T4+ | (RAPTOR|SCAV): Non-player faction
--  > Weight class := S: Small | M: Medium | H: Heavy
--  > Mobility := A: Amphibious | T: All-Terrain | U: Underwater | V: Upright
--  > Category :=  BOT: Bots | BOAT: Ships | HOVER: Hovers | TANK: Vehicles
--  > Footprint := 1–10: Footprint size

----------------------------------------------------------------------------------
-- REFERENCE VALUES
-- These are for readability more than correctness, really.

local SPEED_CLASS = Game.speedModClasses

local CRUSH = {
	NONE    = 0,
	TINY    = 5,
	LIGHT   = 10, -- default
	SMALL   = 18,
	MEDIUM  = 25,
	LARGE   = 50,
	HEAVY   = 250,
	HUGE    = 1400,
	MASSIVE = 9999,
	MAXIMUM = 99999, -- arbitrary limit
}

local DEPTH = {
	NONE       = 0,
	SHALLOW    = 10, -- add unit size tolerances to this value
	SUBMERGED  = 15,
	AMPHIBIOUS = 5000,
	MAXIMUM    = 9999, -- aribitrary limit
	DEFAULT    = 1000000,
}

local SLOPE = {
	NONE      = 0,
	MINIMUM   = 27,
	MODERATE  = 33, -- just below angle of repose
	DIFFICULT = 54,
	EXTREME   = 75,
	MAXIMUM   = 90,
}

local SLOPE_MOD = {
	MINIMUM   = 4,
	MODERATE  = 18,
	SLOW      = 25,
	VERY_SLOW = 36,
	GLACIAL   = 42,
	MAXIMUM   = 4000,
}

----------------------------------------------------------------------------------
-- MOVE DEFS

---See MoveDef::GetDepthMod
---@class DepthModParams
---@field minHeight number? (default = `0`)
---@field maxScale number? [0.01, float::max) (default = `float::max`)
---@field constantCoeff number? (default = `1`)
---@field linearCoeff number? (default = `depthMod` or `0.1`)
---@field quadraticCoeff number? (default = `0`)

---@type DepthModParams
local depthModGeneric = {
	minHeight   = 4,
	linearCoeff = 0.03,
	maxValue    = 0.7, -- TODO: Should be "maxScale" and should be > 1.
}

---@type DepthModParams
local depthModCommanders = {
	maxScale       = 1.5,
	quadraticCoeff = (9.9 / 22090) / 2,
	linearCoeff    = (0.1 / 470) / 2,
}

---@type DepthModParams
local depthModCrawlingBombs = {
	constantCoeff = 1.5,
	linearCoeff = 0,
}

-- TODO: Random capitalization. Pick one and use it.
---@class MoveDefData
---@field footprint integer equal to both `footprintx` and `footprintz`
---@field crushstrength integer [0, 1e6) mass equivalent for crushing and collisions
---@field maxslope number? [0, 90] degrees
---@field slopeMod number? [4, 4000] unitless
---@field minwaterdepth integer? [-1e6, 1e6]
---@field maxwaterdepth integer? [0, 1e6]
---@field subMarine boolean?
---@field maxwaterslope integer? [0, 90] degrees; does nothing
---@field badwaterslope integer? [0, 90] degrees; does nothing
---@field depthMod number? shorthand for DepthModParams.linearCoeff
---@field depthModParams DepthModParams? used by Tank and KBot only
---@field speedModClass integer?

---@type table<string, MoveDefData>
local moveDatas = {
	--all arm and core commanders and their decoys
	COMMANDERBOT = {
		crushstrength = CRUSH.LARGE,
		depthModParams = depthModCommanders,
		footprint = 3,
		maxslope = SLOPE.DIFFICULT,
		maxwaterdepth = DEPTH.AMPHIBIOUS,
		maxwaterslope = SLOPE.EXTREME,
	},

	--corroach corsktl armvader
	ABOTBOMB2 = {
		crushstrength = CRUSH.LARGE,
		footprint = 2,
		maxslope = SLOPE.DIFFICULT,
		maxwaterdepth = DEPTH.AMPHIBIOUS,
		maxwaterslope = SLOPE.EXTREME,
		depthModParams = depthModCrawlingBombs,
	},

	--critter_crab raptor_land_spiker_basic_t2_v1 cormando raptor_land_spiker_basic_t4_v1 armaak corcrash raptorems2_spectre armjeth coramph coraak
	ABOT3 = {
		crushstrength = CRUSH.LARGE,
		depthmod = 0,
		footprint = 3,
		maxslope = SLOPE.DIFFICULT,
		maxwaterdepth = DEPTH.AMPHIBIOUS,
		maxwaterslope = SLOPE.EXTREME,
	},

	-- corgarp armbeaver armmar corparrow armprow corseal corsala cormuskrat armcroc armpincer corintr legassistdrone_land corassistdrone armassistdrone legotter corphantom
	ATANK3 = {
		crushstrength = CRUSH.MEDIUM + 5,
		depthmod = 0,
		footprint = 3,
		maxslope = SLOPE.DIFFICULT,
		slopeMod = SLOPE_MOD.MODERATE,
		maxwaterdepth = DEPTH.AMPHIBIOUS,
		maxwaterslope = SLOPE.MAXIMUM,
	},

	-- corcs armsjam corpt armdecade armtorps corshark critter_goldfish armcs correcl armrecl  corsupp  corsjam cormls armpt
	BOAT3 = {
		crushstrength = CRUSH.LIGHT - 1,
		footprint = 3,
		minwaterdepth = DEPTH.SHALLOW - 2,
	},
	--armmls armroy armaas corrsub corroy armship coracsub armserp  corpship  corarch
	BOAT4 = {
		crushstrength = CRUSH.LIGHT - 1,
		footprint = 4,
		minwaterdepth = DEPTH.SHALLOW - 2,
	},
	-- cruisers / missile ships / transport ships
	-- armtship cormship corcrus armmship cortship armcrus
	BOAT5 = {
		crushstrength = CRUSH.SMALL - 2,
		footprint = 5,
		minwaterdepth = DEPTH.SHALLOW,
	},
	-- armcarry armdronecarry armepoch corblackhy armbats corbats corcarry cordronecarry corsentinel armtrident coresuppt3
	BOAT9 = {
		crushstrength = CRUSH.HEAVY + 2,
		footprint = 9,
		minwaterdepth = DEPTH.SUBMERGED,
	},

	--critter_goldfish coracsub armacsub armserp corrsub armsubk correcl corshark corsub
	UBOAT4 = {
		footprint = 4,
		minwaterdepth = DEPTH.SUBMERGED,
		crushstrength = CRUSH.TINY,
		subMarine = true,
	},

	--corsh armah armch armsh
	HOVER2 = {
		badslope = SLOPE.MODERATE,
		badwaterslope = SLOPE.MAXIMUM,
		crushstrength = CRUSH.MEDIUM,
		footprint = 2,
		maxslope = SLOPE.MODERATE,
		slopeMod = SLOPE_MOD.SLOW,
		maxwaterslope = SLOPE.MAXIMUM,
	},
	--OMG WE HAVE LOOT BOXES! BLAME DAMGAM NOW! damgam dm me with this message !
	-- corch cormh armmh corah corsnap armanac corhal lootboxsilver lootboxbronze legfloat
	HOVER3 = {
		badslope = SLOPE.MODERATE,
		badwaterslope = SLOPE.MAXIMUM,
		crushstrength = CRUSH.MEDIUM,
		footprint = 3,
		maxslope = SLOPE.MODERATE,
		slopeMod = SLOPE_MOD.SLOW,
		maxwaterslope = SLOPE.MAXIMUM,
	},
	-- armlun corsok armthover corthovr lootboxgold lootboxplatinum
	HHOVER4 = {
		badslope = SLOPE.MODERATE,
		badwaterslope = SLOPE.MAXIMUM,
		crushstrength = CRUSH.HEAVY + 2,
		footprint = 4,
		maxslope = SLOPE.MODERATE,
		slopeMod = SLOPE_MOD.MODERATE,
		maxwaterslope = SLOPE.MAXIMUM,
	},
	-- armamph
	AHOVER2 = {
		badslope = SLOPE.DIFFICULT,
		badwaterslope = SLOPE.MAXIMUM,
		crushstrength = CRUSH.MEDIUM,
		footprint = 2,
		maxslope = SLOPE.DIFFICULT,
		slopeMod = SLOPE_MOD.MODERATE,
		maxwaterslope = SLOPE.MAXIMUM,
	},

	-- cormlv armmflash corgator legmrv  leghades leghelops armfav corfav armconsul armlatnk cortorch legmrrv
	TANK2 = {
		crushstrength = CRUSH.SMALL,
		footprint = 2,
		maxslope = SLOPE.MINIMUM,
		slopeMod = SLOPE_MOD.MODERATE,
		maxwaterdepth = DEPTH.SHALLOW + 12,
		depthModParams = depthModGeneric,
	},
	-- armjam corraid armjanus armsam armstump corwolv legcv corsent coreter corcv  cormist legrail legacv armacv armgremlin armmlv
	--armcv armart coracv corlevlr leggat legbar armseer armmart armyork corforge cormabm legvcarry corvrad cormart
	TANK3 = {
		crushstrength = CRUSH.MEDIUM + 5,
		footprint = 3,
		maxslope = SLOPE.MINIMUM,
		slopeMod = SLOPE_MOD.MODERATE,
		maxwaterdepth = DEPTH.SHALLOW + 12,
		depthModParams = depthModGeneric,
	},

	--corprinter corvac corvacct correap corftiger armbull legsco corvoc armmerl
	MTANK3 = {
		crushstrength = CRUSH.HEAVY,
		footprint = 3,
		maxslope = SLOPE.MINIMUM,
		slopeMod = SLOPE_MOD.SLOW,
		maxwaterdepth = DEPTH.SHALLOW + 12,
		depthModParams = depthModGeneric,
	},
	-- corgol leginf corban cortrem armmanni armmerl legkeres legmed corsiegebreaker
	HTANK4 = {
		crushstrength = CRUSH.HEAVY + 2,
		footprint = 4,
		maxslope = SLOPE.MINIMUM,
		slopeMod = SLOPE_MOD.VERY_SLOW,
		maxwaterdepth = DEPTH.SHALLOW + 12,
		depthModParams = depthModGeneric,
	},
	-- armthor
	HTANK7 = {
		crushstrength = CRUSH.HUGE,
		footprint = 7,
		maxslope = SLOPE.MODERATE,
		slopeMod = SLOPE_MOD.GLACIAL,
		maxwaterdepth = DEPTH.SHALLOW + 14,
		depthModParams = depthModGeneric,
	},

	--armflea critter_ant dice critter_penguinbro critter_penguin critter_duck xmasballs chip
	-- make a suggestion thread critterh
	SBOT2 = {
		crushstrength = CRUSH.TINY,
		footprint = 2,
		maxslope = SLOPE.DIFFICULT,
		maxwaterdepth = DEPTH.SHALLOW * 0.5,
		depthModParams = depthModGeneric,
	},
	--cornecro leggob legkark armpw armfark armrectr corak corfast corspy leglob armspy
	BOT2 = {
		crushstrength = CRUSH.SMALL - 3,
		footprint = 2,
		maxslope = SLOPE.DIFFICULT,
		maxwaterdepth = DEPTH.SHALLOW + 12,
		depthModParams = depthModGeneric,
	},
	--  armfido leggstr corhrk armmav armfast armzeus
	BOT3 = {
		crushstrength = CRUSH.MEDIUM,
		footprint = 3,
		maxslope = SLOPE.DIFFICULT,
		maxwaterdepth = DEPTH.SHALLOW + 12,
		depthModParams = depthModGeneric,
	},

	-- armraz legpede corcat leginc armfboy corsumo legmech cordemon
	HBOT4 = {
		crushstrength = CRUSH.HEAVY + 2,
		footprint = 4,
		maxslope = SLOPE.DIFFICULT,
		maxwaterdepth = DEPTH.SHALLOW + 16,
		depthModParams = depthModGeneric,
	},
	-- corshiva armmar armbanth legjav
	HABOT5 = {
		crushstrength = CRUSH.HEAVY + 2,
		depthmod = 0,
		footprint = 5,
		maxslope = SLOPE.DIFFICULT,
		maxwaterdepth = DEPTH.AMPHIBIOUS,
		maxwaterslope = SLOPE.MAXIMUM,
	},
	-- armvang corkarg corthermite
	HTBOT6 = {
		crushstrength = CRUSH.HEAVY + 2,
		footprint = 6,
		maxslope = SLOPE.MAXIMUM,
		maxwaterdepth = DEPTH.SHALLOW + 12,
		depthModParams = depthModGeneric,
	},
	-- corkorg legeheatraymech
	VBOT6 = {
		crushstrength = CRUSH.HUGE,
		depthmod = 0,
		footprint = 6,
		maxslope = SLOPE.DIFFICULT,
		maxwaterdepth = DEPTH.AMPHIBIOUS,
		maxwaterslope = SLOPE.DIFFICULT,
	},
	-- corjugg
	HBOT7 = {
		crushstrength = CRUSH.HUGE,
		footprint = 7,
		maxslope = SLOPE.DIFFICULT,
		maxwaterdepth = DEPTH.SHALLOW + 20,
		depthModParams = depthModGeneric,
	},
	-- legsrail armscab armsptk cortermite armspid pbr_cube  dbg_sphere_fullmetal _dbgsphere leginfestor
	TBOT3 = {
		crushstrength = CRUSH.SMALL - 3,
		footprint = 3,
		maxwaterdepth = DEPTH.SHALLOW + 12,
		depthModParams = depthModGeneric,
	},

	--Raptor Movedefs
	--raptor_queen_easy raptor_queen_normal raptor_queen_hard vc_raptorq raptor_queen_veryhard raptor_queen_epic raptor_matriarch_fire raptor_matriarch_acid raptor_matriarch_basic raptor_matriarch_healer
	--raptor_matriarch_spectre raptor_matriarch_electric
	RAPTORQUEENHOVER = {
		badslope = SLOPE.MODERATE,
		badwaterslope = SLOPE.MAXIMUM,
		crushstrength = CRUSH.MAXIMUM,
		footprint = 4,
		maxslope = SLOPE.MAXIMUM,
		maxwaterslope = SLOPE.MAXIMUM,
		speedModClass = SPEED_CLASS.Hover,
	},
	-- raptor_land_swarmer_heal_t1_v1 raptor_land_swarmer_basic_t4_v2 raptor_land_swarmer_spectre_t4_v1 raptor_land_swarmer_basic_t4_v1 raptor_land_swarmer_emp_t2_v1 raptor_land_swarmer_basic_t1_v1 raptor_land_kamikaze_emp_t2_v1 raptor_land_spiker_basic_t4_v1
	--raptor_land_kamikaze_emp_t4_v1 raptor_land_spiker_basic_t2_v1 raptor_land_swarmer_basic_t3_v2 raptor_land_swarmer_basic_t3_v1 raptor_land_swarmer_basic_t3_v3 raptor_land_swarmer_basic_t2_v4 raptor_land_swarmer_basic_t2_v3 raptor_land_swarmer_basic_t2_v2 raptor_land_swarmer_basic_t2_v1 raptor_land_swarmer_brood_t3_v1 raptor_land_swarmer_brood_t4_v1
	--raptor_land_swarmer_brood_t2_v1 raptor_land_kamikaze_basic_t2_v1 raptor_land_kamikaze_basic_t4_v1  raptor_land_swarmer_fire_t4_v1 raptor_land_swarmer_acids_t2_v1 raptor_land_swarmer_spectre_t3_v1 raptor_land_swarmer_fire_t2_v1 raptorh5 raptor_land_spiker_spectre_t4_v1
	-- raptorh1b
	RAPTORSMALLHOVER = {
		badslope = SLOPE.MODERATE,
		badwaterslope = SLOPE.MAXIMUM,
		crushstrength = CRUSH.MEDIUM,
		footprint = 2,
		maxslope = SLOPE.DIFFICULT,
		slopeMod = SLOPE_MOD.MODERATE,
		maxwaterslope = SLOPE.MAXIMUM,
		speedModClass = SPEED_CLASS.Hover,
	},
	-- raptor_land_assault_emp_t2_v1 raptoracidassualt raptor_land_assault_basic_t2_v1 raptor_land_assault_basic_t2_v3 raptor_land_swarmer_basic_t2_v2 raptor_land_assault_spectre_t2_v1
	RAPTORBIGHOVER = {
		badslope = SLOPE.MODERATE,
		badwaterslope = SLOPE.MAXIMUM,
		crushstrength = CRUSH.HEAVY,
		footprint = 3,
		maxslope = SLOPE.DIFFICULT,
		slopeMod = SLOPE_MOD.MODERATE,
		maxwaterslope = SLOPE.MAXIMUM,
		speedModClass = SPEED_CLASS.Hover,
	},
	-- raptor_land_assault_spectre_t4_v1 raptora2 raptor_land_assault_basic_t4_v2
	RAPTORBIG2HOVER = {
		badslope = SLOPE.MODERATE,
		badwaterslope = SLOPE.MAXIMUM,
		crushstrength = CRUSH.HUGE + 100,
		footprint = 4,
		maxslope = SLOPE.DIFFICULT,
		slopeMod = SLOPE_MOD.MODERATE,
		maxwaterslope = SLOPE.MAXIMUM,
		speedModClass = SPEED_CLASS.Hover,
	},
	-- raptor_allterrain_swarmer_basic_t2_v1 raptor_allterrain_swarmer_basic_t4_v1 raptor_allterrain_swarmer_basic_t3_v1 raptor_allterrain_swarmer_acid_t2_v1 raptor_allterrain_swarmer_fire_t2_v1 raptor_6legged_I raptoreletricalallterrain
	RAPTORALLTERRAINHOVER = {
		crushstrength = CRUSH.LARGE,
		footprint = 2,
		maxslope = SLOPE.MAXIMUM,
		maxwaterdepth = DEPTH.AMPHIBIOUS,
		maxwaterslope = SLOPE.EXTREME,
		speedModClass = SPEED_CLASS.Hover,
	},
	-- raptor_allterrain_arty_basic_t2_v1 raptor_allterrain_arty_acid_t2_v1 raptor_allterrain_arty_acid_t4_v1 raptor_allterrain_arty_emp_t2_v1 raptor_allterrain_arty_emp_t4_v1 raptor_allterrain_arty_brood_t2_v1 raptoracidalllterrrainassual
	--raptor_allterrain_swarmer_emp_t2_v1assualt raptor_allterrain_assault_basic_t2_v1 raptoraallterraina1 raptoraallterrain1c raptoraallterrain1b
	RAPTORALLTERRAINBIGHOVER = {
		crushstrength = CRUSH.HEAVY,
		footprint = 3,
		maxslope = SLOPE.MAXIMUM,
		maxwaterdepth = DEPTH.AMPHIBIOUS,
		maxwaterslope = SLOPE.EXTREME,
		speedModClass = SPEED_CLASS.Hover,
	},
	-- raptor_allterrain_arty_basic_t4_v1 raptor_allterrain_arty_brood_t4_v1 raptorapexallterrainassualt raptorapexallterrainassualtb
	RAPTORALLTERRAINBIG2HOVER = {
		crushstrength = CRUSH.HEAVY,
		footprint = 4,
		maxslope = SLOPE.MAXIMUM,
		maxwaterdepth = DEPTH.AMPHIBIOUS,
		maxwaterslope = SLOPE.EXTREME,
		speedModClass = SPEED_CLASS.Hover,
	},

	-- leghive armnanotc cornanotc cornanotcplat  raptor_worm_green raptor_turret_acid_t2_v1 raptor_turret_meteor_t4_v1
	NANO = {
		crushstrength = CRUSH.NONE,
		footprint = 3,
		maxslope = SLOPE.MINIMUM,
		maxwaterdepth = DEPTH.NONE,
	},

	-- armcomboss corcomboss
	SCAVCOMMANDERBOT = {
		crushstrength = CRUSH.LARGE,
		depthModParams = depthModCommanders,
		footprint = 8,
		maxslope = SLOPE.MAXIMUM,
		maxwaterdepth = DEPTH.MAXIMUM,
		maxwaterslope = SLOPE.MAXIMUM,
	},
	-- scavmist  scavmistxl scavmisstxxl
	SCAVMIST = {
		badwaterslope = SLOPE.MAXIMUM,
		maxslope = SLOPE.MAXIMUM,
		crushstrength = CRUSH.NONE,
		footprint = 2,
		maxwaterslope = SLOPE.MAXIMUM,
		speedModClass = SPEED_CLASS.Hover,
	},

	-- armpwt4 corakt4 armmeatball armassimilator armlunchbox
	EPICBOT = {
		crushstrength = CRUSH.MASSIVE,
		depthmod = 0,
		footprint = 4,
		maxslope = SLOPE.DIFFICULT,
		maxwaterdepth = DEPTH.MAXIMUM,
		maxwaterslope = SLOPE.EXTREME,
		speedModClass = SPEED_CLASS.KBot,
	},
	-- corgolt4 armrattet4
	EPICVEH = {
		crushstrength = CRUSH.MASSIVE,
		depthmod = 0,
		footprint = 5,
		maxslope = SLOPE.DIFFICULT,
		slopeMod = SLOPE_MOD.MODERATE,
		maxwaterdepth = DEPTH.MAXIMUM,
		maxwaterslope = SLOPE.EXTREME,
		speedModClass = SPEED_CLASS.Tank,
	},
	-- corslrpc armdecadet3 armptt2 armpshipt3
	EPICSHIP = {
		crushstrength = CRUSH.MASSIVE,
		footprint = 5,
		maxslope = SLOPE.MAXIMUM,
		minwaterdepth = DEPTH.SHALLOW + 2,
		maxwaterdepth = DEPTH.MAXIMUM,
		maxwaterslope = SLOPE.MAXIMUM,
		speedModClass = SPEED_CLASS.Ship,
	},
	-- armvadert4 armsptkt4 corkargenetht4
	EPICALLTERRAIN = {
		crushstrength = CRUSH.MASSIVE,
		depthmod = 0,
		footprint = 5,
		maxslope = SLOPE.MAXIMUM,
		maxwaterdepth = DEPTH.MAXIMUM,
		maxwaterslope = SLOPE.MAXIMUM,
		speedModClass = SPEED_CLASS.KBot,
	},
	-- armserpt3
	EPICSUBMARINE = {
		footprint = 5,
		minwaterdepth = DEPTH.SUBMERGED,
		maxwaterdepth = DEPTH.MAXIMUM,
		crushstrength = CRUSH.MASSIVE,
		subMarine = true,
		speedModClass = SPEED_CLASS.Ship,
	},
}

--------------------------------------------------------------------------------
-- Final processing / array format
--------------------------------------------------------------------------------

---@class MoveDefCreate
---@field name string
---@field heatmapping boolean
---@field allowRawMovement boolean
---@field allowTerrainCollisions boolean
---@field footprintx integer
---@field footprintz integer
---@field crushstrength integer [0, 1e6) mass equivalence for crushing and collisions
---@field maxslope number? [0, 90] degrees
---@field slopeMod number? [4, 4000] unitless, derived
---@field minwaterdepth integer? [-1e6, 1e6]
---@field maxwaterdepth integer? [0, 1e6]
---@field maxwaterslope integer? [0, 90] degrees; does nothing
---@field depthMod number?
---@field depthModParams table?
---@field speedModClass integer?

---@param moveDef MoveDefCreate
local function setMaxSlope(moveDef)
	if moveDef.maxslope then
		if type(moveDef.name) == "string" and moveDef.name:find("BOT") then
			moveDef.slopeMod = SLOPE_MOD.MINIMUM
		end
		---`maxSlope` is multiplied by 1.5 at load, so 60 degrees is its actual "maximum",
		-- so has default value 15 * 1.5 = 22.5 for hovers and 90 for bots/vehicles/ships.
		moveDef.maxslope = moveDef.maxslope / 1.5
	end
end

-- Skip other moveDef validation for special names that ignore the footprint requirement.
local validName = { "^COMMANDER", "^NANO$", "^EPIC", "^RAPTOR", "^SCAV" }

---@param moveDef MoveDefCreate
local function validate(moveDef)
	local name = moveDef.name
	if type(name) ~= "string" then
		return false
	elseif table.any(validName, function(v) return name:match(v) end) then
		return true
	elseif name:gmatch("%d+$") ~= tostring(moveDef.footprintx) then
		return false
	end
	return false
end

local defs = {}

for moveName, moveData in pairs(moveDatas) do
	---@type MoveDefCreate
	local moveDef = {
		name                   = moveName,
		crushstrength          = moveData.crushstrength,
		footprintx             = moveData.footprint,
		footprintz             = moveData.footprint,
		allowRawMovement       = true,
		allowTerrainCollisions = false,
		heatmapping            = true,
		--
		depthMod               = moveData.depthMod,
		depthModParams         = moveData.depthModParams,
		maxslope               = moveData.maxslope,
		maxwaterdepth          = moveData.maxwaterdepth,
		maxwaterslope          = moveData.maxwaterslope,
		minwaterdepth          = moveData.minwaterdepth,
		slopeMod               = moveData.slopeMod,
		speedModClass          = moveData.speedModClass,
	}

	setMaxSlope(moveDef)

	if validate(moveDef) then
		defs[#defs + 1] = moveDef
	end
end

return defs
