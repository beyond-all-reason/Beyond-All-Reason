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


customDefs.corcom = {		
	hidedamage = false,
	explodeas = "hugeexplosiongeneric",
	mincloakdistance = 20,
	buildoptions = scavUnit,
	workertime = 500,
	customparams = {
		iscommander = 'nil',      -- since you cant actually remove parameters normally, it will do it when you set string: 'nil' as value
	},
	featuredefs = {
		dead = {
			resurrectable = 0,
		},
	},
	weapondefs = {
		disintegrator = {
			commandfire = false,
			damage = {
				default = 150,
			},
		},
	},
}

customDefs.armcom = {		
	hidedamage = false,
	explodeas = "hugeexplosiongeneric",
	mincloakdistance = 20,
	buildoptions = scavUnit,
	workertime = 500,
	customparams = {
		iscommander = 'nil',      -- since you cant actually remove parameters normally, it will do it when you set string: 'nil' as value
	},
	featuredefs = {
		dead = {
			resurrectable = 0,
		},
	},
	weapondefs = {
		disintegrator = {
			commandfire = false,
			damage = {
				default = 150,
			},
		},
	},
}


