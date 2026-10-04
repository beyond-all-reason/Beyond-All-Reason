-----------------------------------------------------------------------------
--  pilha_crystal_*
-----------------------------------------------------------------------------
local Base	=	{
	blocking			= true,
	category			= "crystals",
	damage				= 100,
	description			= "Crystal",
	energy				= 200,
	flammable			= false,
	footprintX			= 1,
	footprintZ			= 1,
	height				= 16,
	hitdensity			= 0,
	metal				= 10,
	reclaimable			= true,
	autoreclaimable		= true,
	upright 			= false,
	customparams = { -- this will be customParams (note capital P) ingame
		author = "Beherith",
		category = "crystals",
		set = "Crystals",
		normalmaps = "yes",
		normaltex = "unittextures/pilha_crystal_normal.png",
		treeshader = "no",
		randomrotate = "true",
	},
}

local colormetal = {
	[""] = 5,
	_violet = 5,
	_blue = 5,
	_green = 5,
	_lime = 5,
	_obsidian = 5,
	_quartz = 5,
	_orange = 5 ,
	_red = 5 ,
	_teal = 5,
	_team = 5
	}
local colorenergy = {
	[""] = 100,
	_violet = 100,
	_blue = 100,
	_green = 100,
	_lime = 100,
	_obsidian = 100,
	_quartz = 100,
	_orange = 100 ,
	_red = 100 ,
	_teal = 100,
	_team = 100,
	}

local crystals = {}
for color, _ in pairs(colormetal) do
	for i = 1, 3 do  -- increase if you have more than 3!
		local name = 'pilha_crystal' .. color .. i
		--local name = 'pilha_crystal' .. i
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
		def.object =  'pilha_crystal' .. color .. "_" ..  i .. ".s3o"

		if i == 1 then
			def.description = "Small Crystal"
			def.damage = 100
			def.metal = 1 * colormetal[color]
			def.energy = 1 * colorenergy[color]
			def.customparams.decalinfo_texfile = "pilha_crystal".. color .."_1_aoplane.tga"
			def.customparams.decalinfo_sizex = "3"
			def.customparams.decalinfo_sizez = "3"
			def.customparams.decalinfo_alpha = "1.0"
		elseif i == 2 then
			def.description = "Medium Crystal"
			def.damage = 300
			def.metal = 2 * colormetal[color]
			def.energy = 2 * colorenergy[color]
			def.customparams.decalinfo_texfile = "pilha_crystal".. color .."_2_aoplane.tga"
			def.customparams.decalinfo_sizex = "5"
			def.customparams.decalinfo_sizez = "5"
			def.customparams.decalinfo_alpha = "1.0"
			def.collisionvolumescales = "0 32 0"
			def.collisionvolumeoffsets = "14 0 0"

		elseif i == 3 then
			def.description = "Large Crystal"
			def.damage = 500
			def.metal = 5 * colormetal[color]
			def.energy = 5 * colorenergy[color]
			def.footprintX = 2
			def.footprintZ = 2
			def.customparams.decalinfo_texfile = "pilha_crystal".. color .."_3_aoplane.tga"
			def.customparams.decalinfo_sizex = "7"
			def.customparams.decalinfo_sizez = "7"
			def.customparams.decalinfo_alpha = "1.0"
		end

		crystals[name] = def
	end
end


return crystals
