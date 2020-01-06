-- you only need to put the things you want changed in comparison with the regular unitdef. (use the same table structure)
-- (note that alldefs_post.lua is still ran afterwards if you change anything there)
-- since you cant actually remove parameters normally, it will do it when you set string: 'nil' as value
customDefs = {}
local buildlists = {}


customDefs.corcom = {		
	buildoptions = buildlists,
	customparams = {
		iscommander = 'nil',      -- since you cant actually remove parameters normally, it will do it when you set string: 'nil' as value
	},
	featuredefs = {
		dead = {
			resurrectable = 0,
		},
	},
}

customDefs.armcom = {		
	buildoptions = buildlists,
	customparams = {
		iscommander = 'nil',      -- since you cant actually remove parameters normally, it will do it when you set string: 'nil' as value
	},
	featuredefs = {
		dead = {
			resurrectable = 0,
		},
	},
}


