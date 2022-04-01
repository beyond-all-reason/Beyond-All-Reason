-----------------------------------------------------------------------------
--  pilha_crystal_*
-----------------------------------------------------------------------------
local Base	=	{
	blocking			= true,
	category			= "crystals",
	damage				= 100,
	description			= "Crystal",
	energy				= 200,
	blocking 			= true,
	flammable			= false,
	footprintX			= 1,
	footprintZ			= 1,
	height				= 16,
	hitdensity			= 0,
	metal				= 10,
	reclaimable			= true,
	autoreclaimable		= true, 	
	upright 			= false,
	world				= "All Worlds",
	customparams = { 
		author = "Beherith",
		category = "crystals",
		set = "Crystals",
		normalmaps = "yes",
		normaltex = "unittextures/pilha_crystal_normal.png",
		treeshader = "no",
		randomrotate = "true",
	}, 
}

local crystals = {}
for i = 1, 3 do  -- increase if you have more than 3!
	local name = 'pilha_crystal' .. i
	local def = {}
	for k, v in pairs(Base) do
		def[k] = v
	end
	def.name = name
	def.object =  'pilha_crystal_' .. i .. ".s3o"

	if i == 1 then
		def.description = "Small Crystal" 
		def.damage = 100
		def.metal = 5
		def.energy = 100
	elseif i == 2 then
		def.description = "Medium Crystal"
		def.damage = 300
		def.metal = 10
		def.energy = 300
	elseif i == 3 then
		def.description = "Large Crystal" 
		def.damage = 500
		def.metal = 25
		def.energy = 500
		def.footprintX = 2
		def.footprintZ = 2
	end

	crystals[name] = def
end


return crystals