-- (note that alldefs_post.lua is still ran afterwards if you change anything there)

-- Special rules:
-- you only need to put the things you want changed in comparison with the regular unitdef. (use the same table structure)
-- since you cant actually remove parameters normally, it will do it when you set string: 'nil' as value
-- normally an empty table as value will be ignored when merging, but not here, it will overwrite what it had with an empty table

customDefs = {}


local scavUnit = {}
for name,uDef in pairs(UnitDefs) do
    scavUnit[#scavUnit+1] = name..'_scav'
end

-- Scav Commanders

customDefs.corcom = {		
	autoheal = 15,
	buildoptions = scavUnit,
	cloakcost = 50,
	cloakcostmoving = 100,
	explodeas = "bantha",
	hidedamage = true,
	idleautoheal = 20,
	maxdamage = 4500,
	mincloakdistance = 20,
	showplayername = false,
	stealth = true,
	workertime = 600,				-- can get multiplied in unitdef_post 
	customparams = {
		iscommander = 'nil',		-- since you cant actually remove parameters normally, it will do it when you set string: 'nil' as value
	},
	featuredefs = {
		dead = {
			resurrectable = 0,
			metal = 1500,
		},
		heap = {
			resurrectable = 0,
			metal = 750,
		},
	},
	weapondefs = {
		disintegrator = {
			commandfire = false,
			reloadtime = 10,
			weaponvelocity = 350,
			damage = {
				default = 2500,
				commanders = 1500,
			},
		},
	},
	-- Extra Shield
	-- weapons = {
	-- 		[4] = {
	-- 			def = "REPULSOR1",
	-- 		},
	-- 	},
}

customDefs.armcom = {		
	autoheal = 15,
	buildoptions = scavUnit,
	cloakcost = 50,
	cloakcostmoving = 100,
	explodeas = "bantha",
	hidedamage = true,
	idleautoheal = 20,
	maxdamage = 4500,
	mincloakdistance = 20,
	showplayername = false,
	stealth = true,
	workertime = 600,				-- can get multiplied in unitdef_post 
	customparams = {
		iscommander = 'nil',		-- since you cant actually remove parameters normally, it will do it when you set string: 'nil' as value
	},
	featuredefs = {
		dead = {
			resurrectable = 0,
			metal = 1500,
		},
		heap = {
			resurrectable = 0,
			metal = 750,
		},
	},
	weapondefs = {
		disintegrator = {
			commandfire = false,
			reloadtime = 10,
			weaponvelocity = 350,
			damage = {
				default = 2500,
				commanders = 1500,
			},
		},
	},
	-- Extra Shield
	--weapons = {
	--		[4] = {
	--			def = "REPULSOR1",
	--		},
	--	},
}

-- Cloaked Radar

customDefs.armrad = {
	cloakcost = 6,
	mincloakdistance = 72,
}

customDefs.armarad = {
	cloakcost = 12,
	mincloakdistance = 144,
}

customDefs.corrad = {
	cloakcost = 6,
	mincloakdistance = 72,
}

customDefs.corarad = {
	cloakcost = 12,
	mincloakdistance = 144,
}


-- Cloaked Jammers

customDefs.armjamt = {
	cloakcost = 10,
	mincloakdistance = 144,
--	radardistancejam = 700,
	sightdistance = 250,
}

customDefs.armveil = {
	cloakcost = 25,
	mincloakdistance = 288,
--	radardistancejam = 900,
	sightdistance = 310,
}

customDefs.corjamt = {
	cloakcost = 10,
	mincloakdistance = 144,
--	radardistancejam = 700,
	sightdistance = 250,
}

customDefs.corshroud = {
	cloakcost = 25,
	mincloakdistance = 288,
--	radardistancejam = 900,
	sightdistance = 310,
}

-- Cloaked Constructors

customDefs.correcl = {
	cloakcost = 3,
	mincloakdistance = 72,
}

customDefs.armrecl = {
	cloakcost = 3,
	mincloakdistance = 72,
}

customDefs.corck = {
	cloakcost = 3,
	mincloakdistance = 72,
}

customDefs.corcv = {
	cloakcost = 3,
	mincloakdistance = 72,
}

customDefs.cormuskrat = {
	cloakcost = 3,
	mincloakdistance = 72,
}

customDefs.corack = {
	cloakcost = 3,
	mincloakdistance = 72,
}

customDefs.coracv = {
	cloakcost = 3,
	mincloakdistance = 72,
}

customDefs.corca = {
	cloakcost = 3,
	mincloakdistance = 72,
}

customDefs.coraca = {
	cloakcost = 3,
	mincloakdistance = 72,
}

customDefs.armck = {
	cloakcost = 3,
	mincloakdistance = 72,
}

customDefs.armcv = {
	cloakcost = 3,
	mincloakdistance = 72,
}

customDefs.armbeaver = {
	cloakcost = 3,
	mincloakdistance = 72,
}

customDefs.armack = {
	cloakcost = 3,
	mincloakdistance = 72,
}

customDefs.armacv = {
	cloakcost = 3,
	mincloakdistance = 72,
}

customDefs.armca = {
	cloakcost = 3,
	mincloakdistance = 72,
}

customDefs.armaca = {
	cloakcost = 3,
	mincloakdistance = 72,
}

-- Cloaked Radar/Jammer Units

customDefs.armaser = {
	cloakcost = 3,
	mincloakdistance = 72,
}

customDefs.armmark = {
	cloakcost = 3,
	mincloakdistance = 72,
}

customDefs.armjam = {
	cloakcost = 3,
	mincloakdistance = 72,
}

customDefs.armseer = {
	cloakcost = 3,
	mincloakdistance = 72,
}

customDefs.corspec = {
	cloakcost = 3,
	mincloakdistance = 72,
}

customDefs.corvoyr = {
	cloakcost = 3,
	mincloakdistance = 72,
}

customDefs.coreter = {
	cloakcost = 3,
	mincloakdistance = 72,
}

customDefs.corvrad = {
	cloakcost = 3,
	mincloakdistance = 72,
}


-- Cloaked Combat Units

customDefs.corak = {
	cloakcost = 3,
	mincloakdistance = 72,
}

customDefs.corcrash = {
	cloakcost = 3,
	mincloakdistance = 72,
}

customDefs.coraak = {
	cloakcost = 6,
	mincloakdistance = 144,
}

customDefs.armjeth = {
	cloakcost = 3,
	mincloakdistance = 72,
}

customDefs.armaak = {
	cloakcost = 6,
	mincloakdistance = 144,
}

customDefs.corgator = {
	cloakcost = 6,
	mincloakdistance = 144,
}

customDefs.cortermite = {
	cloakcost = 12,
	mincloakdistance = 144,
}

customDefs.cormando = {
	cloakcost = 12,
	mincloakdistance = 144,
}

customDefs.corhrk = {
	cloakcost = 12,
	mincloakdistance = 160,
}

customDefs.armzeus = {
	cloakcost = 12,
	mincloakdistance = 144,
}

customDefs.corroach = {
	cloakcost = 3,
	mincloakdistance = 72,
}

customDefs.armvader = {
	cloakcost = 3,
	mincloakdistance = 72,
}

-- Cloaked + Stealh Units

customDefs.corkarg = {
	cloakcost = 24,
	stealth = true,
	mincloakdistance = 144,
}

customDefs.corroach = {
	cloakcost = 3,
	mincloakdistance = 72,
}

customDefs.corsktl = {
	cloakcost = 6,
	stealth = true,
	mincloakdistance = 72,
}

-- Cloaked Defenses

customDefs.corllt = {
	cloakcost = 6,
	mincloakdistance = 144,
}

customDefs.corhllt = {
 	cloakcost = 9,
 	mincloakdistance = 144,
 }

customDefs.corhlt = {
	cloakcost = 18,
	mincloakdistance = 288,
}

customDefs.armhlt = {
	cloakcost = 18,
	mincloakdistance = 288,
}

customDefs.armllt = {
	cloakcost = 6,
	mincloakdistance = 144,
}

customDefs.armnanotc = {
	cloakcost = 6,
	mincloakdistance = 72,
}

customDefs.cornanotc = {
	cloakcost = 6,
	mincloakdistance = 72,
}

customDefs.corsilo = {
	cloakcost = 100,
	mincloakdistance = 144,
}

customDefs.armsilo = {
	cloakcost = 100,
	mincloakdistance = 144,
}

-- customDefs.armbeamer = {
-- 	cloakcost = 6,
-- 	mincloakdistance = 144,
-- }

customDefs.corvipe = {
	cloakcost = 20,
	mincloakdistance = 288,
}

customDefs.cortoast = {
	cloakcost = 20,
	mincloakdistance = 288,
}

customDefs.corint = {
	cloakcost = 75,
	mincloakdistance = 432,
}

customDefs.cordoom = {
	cloakcost = 50,
	mincloakdistance = 432,
}

customDefs.armrectr = {
	workertime = 400, 	-- can get multiplied in unitdef_post 
}

customDefs.cornecro = {
	workertime = 400,		-- can get multiplied in unitdef_post 
}