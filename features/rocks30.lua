-----------------------------------------------------------------------------
--  rocks30_*_*
-----------------------------------------------------------------------------
local Base	=	{
	blocking			= true,
	category			= "rocks",
	description			= "Rock",
	energy				= 0,
	flammable			= false,
	footprintX			= 1,
	footprintZ			= 1,
	height				= 16,
	hitdensity			= 0,
	reclaimable			= true,
	autoreclaimable		= true, 	
	upright 			= false,
	world				= "All Worlds",
	customparams = { -- this will be customParams (note capital P) ingame
		author = "Beherith",
		category = "rocks",
		set = "rocks30",
		normalmaps = "yes",
		normaltex = "unittextures/",
		treeshader = "no",
		randomrotate = "true",
		cuspbr = "yes",
	}, 
}

local biomes = { def="", snow = "Snowy ", moss = "Mossy " , desert = "Barren ", map = ""}

local rocks = {}
for biome, descname in pairs(biomes) do 
	for i = 1, 30 do  -- increase if you have more than 3!
		local name = string.format('rocks30_%s_%02d', biome, i)
		local def = {}
		for k, v in pairs(Base) do
			if k == 'customparams' then 
				def[k] = {}
				for k2, v2 in pairs(v) do def[k][k2] = v2 end 
			else
				def[k] = v
			end
		end
		def.name = name
		def.object =  string.format('rocks30/rocks30_%s_%02d.s3o', biome, i)
		def.description = descname .. "Rock"
		
		def.metal = 9 + i
		def.damage = 100 + i * 50
		
		def.customparams.decalinfo_texfile =  string.format('rocks30_def_%02d_aoplane.tga',  i)
		def.customparams.decalinfo_sizex = tostring(math.floor(i/5) + 5) 
		def.customparams.decalinfo_sizez = tostring(math.floor(i/5) + 5) 
		def.footprintX = tostring(math.floor(i/8) + 1) 
		def.footprintZ = tostring(math.floor(i/8) + 1) 
		
		def.customparams.decalinfo_alpha = "0.9"
		def.customparams.normaltex = string.format('unittextures/rocks30_%s_normal.dds', biome)

		rocks[name] = def
	end
end

return rocks