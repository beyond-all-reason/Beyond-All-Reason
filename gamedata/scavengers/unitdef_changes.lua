-- you only need to put the things you want changed in comparison with the regular unitdef. (use the same table structure)
-- (note that alldefs_post.lua is still ran afterwards if you change anything there)
-- since you cant actually remove parameters normally, it will do it when you set string: 'nil' as value
customDefs = {}


local scavArm = {}
local scavCor = {}
for name,uDef in pairs(UnitDefs) do
    local faction = string.sub(name, 1, 3)
    if faction == 'arm' then
        scavArm[#scavArm+1] = name..'_scav'
    end
    if faction == 'cor' then
        scavCor[#scavCor+1] = name..'_scav'
    end
end


customDefs.corcom = {		
	buildoptions = scavCor,
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
	buildoptions = scavArm,
	customparams = {
		iscommander = 'nil',      -- since you cant actually remove parameters normally, it will do it when you set string: 'nil' as value
	},
	featuredefs = {
		dead = {
			resurrectable = 0,
		},
	},
}


