local candyCane = {
	description = "CandyCane",
	blocking = 0,
	category = "corpses",
	damage = 30,
	energy = 5,
	footprintx = 1,
	footprintz = 1,
	height = 30,
	hitdensity = 999999,
	metal = 0,
	reclaimable = 0,
	customparams = {
		i18nfrom = 'candycane'
	}
}

local candyCaneDefs = {}
for i = 1, 7 do
	local name = 'candycane' .. i
	local object = 'candycane' .. i .. '.s3o'
	if object == 'candycane1.s3o' then object = 'candycane.s3o' end

	local def = table.copy(candyCane)
	def.name = name
	def.object = object
	candyCaneDefs[name] = def
end

return candyCaneDefs
