function ComUpdate_Post(name)
	local lowername = string.lower(name)
	local uppername = string.upper(name)
	local tablecom = table.copy(UnitDefs[name])
	tablecom.objectname = "Units/"..uppername..".S3O"
	tablecom.featuredefs.dead.metal = 1250
	tablecom.featuredefs.heap.metal = 500
	tablecom.maxdamage = 4500
	tablecom.autoheal = 0
	if tablecom.weapondefs.disintegrator then
		tablecom.weapondefs.disintegrator.interceptedbyshieldtype = 8
		tablecom.weapondefs.disintegrator.damage = {
			default = 98999,
			scavboss = 1000,
			commanders = 1,
			}
	end
	--[[if tablecom.weapondefs.repulsor1 then
		tablecom.weapondefs.repulsor1.shield.intercepttype = 8
		tablecom.weapondefs.repulsor1.shield.startingpower = 99999
		tablecom.weapondefs.repulsor1.shield.visiblehitframes = 60
		tablecom.weapondefs.repulsor1.shield.power = 99999
		tablecom.weapondefs.repulsor1.shield.powerregen = 99999
	end

	tablecom.weapons[4] = {
		def = "REPULSOR1",
		}
]]
	UnitDefs[name] = tablecom
end