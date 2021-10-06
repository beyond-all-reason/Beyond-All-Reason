local chicken_egg =  {
	description = "Egg",
	blocking = 0,
	category = "corpses",
	damage = 2000,
	energy = 250,
	featurereclamate = "SMUDGE01",
	footprintx = 1,
	footprintz = 1,
	height = 15,
	hitdensity = 999999,
	metal = 25,
	reclaimable = 1,
	resurrectable = 0,
	world = "All Worlds",
	smokeTime = 0,
	customparams = {
		model_author = "KDR11k, Beherith",
		normalmaps = "yes",
		normaltex = "unittextures/chicken_s_normals.png",
		treeshader = "yes",
		i18nfromfeature = 'chicken_egg'
	},
}

local eggs = {}
local sizes = {"s","m","l",}
local colors = {"pink","white","red",}

for _, size in pairs(sizes) do
	for _, color in pairs(colors) do
		local name = "chicken_egg_"..size.."_"..color
		local def = table.copy(chicken_egg)
		def.name = name
		def.object =  "Chickens/chickenegg_"..size.."_"..color .. ".s3o"
		eggs[name] = def
	end
end

return eggs
