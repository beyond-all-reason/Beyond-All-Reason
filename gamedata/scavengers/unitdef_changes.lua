-- you only need to put the things you want changed in comparison with the regular unitdef. (use the same table structure)
-- (note that alldefs_post.lua is still ran afterwards if you change anything there)
customDefs = {}
local buildlists = {}



-- example:
--customDefs.armcom = {		-- (automatically becomes armcom_scav)
--	energymake = 9999,
--	weapondefs = {
--		armcomlaser = {
--			range = 999,
--		},
--	},
--}

customDefs.corcom = {		
	buildoptions = buildlists,
	customparams = {
		iscommander = false,
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
		iscommander = false,
	},
	featuredefs = {
		dead = {
			resurrectable = 0,
		},
	},
}


