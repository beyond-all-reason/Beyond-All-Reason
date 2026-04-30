local function processRaptorUnitDef(uDef)
	local customparams = uDef.customparams
	local raptorHealth = uDef.health
	uDef.activatewhenbuilt = true
	uDef.metalcost = raptorHealth * 0.5
	uDef.energycost = math.min(raptorHealth * 5, 16000000)
	uDef.buildtime = math.min(raptorHealth * 10, 16000000)
	uDef.hidedamage = true
	uDef.mass = raptorHealth
	uDef.canhover = true
	uDef.autoheal = math.ceil(math.sqrt(raptorHealth * 0.8))
	customparams.paralyzemultiplier = customparams.paralyzemultiplier or 0.2
	customparams.areadamageresistance = "_RAPTORACID_"
	uDef.upright = false
	uDef.floater = true
	uDef.turninplace = true
	uDef.turninplaceanglelimit = 360
	uDef.capturable = false
	uDef.leavetracks = false
	uDef.maxwaterdepth = 0

	if uDef.cancloak then
		uDef.cloakcost = 0
		uDef.cloakcostmoving = 0
		uDef.mincloakdistance = 100
		uDef.seismicsignature = 3
		uDef.initcloaked = 1
	else
		uDef.seismicsignature = 0
	end

	if uDef.sightdistance then
		uDef.sonardistance = uDef.sightdistance * 2
		uDef.radardistance = uDef.sightdistance * 2
		uDef.airsightdistance = uDef.sightdistance * 2
	end

	if (not uDef.canfly) and uDef.speed then
		uDef.rspeed = uDef.speed * 0.65
		uDef.turnrate = uDef.speed * 10
		uDef.maxacc = uDef.speed * 0.00166
		uDef.maxdec = uDef.speed * 0.00166
	elseif uDef.canfly then
		uDef.maxacc = 1
		uDef.maxdec = 0.25
		uDef.usesmoothmesh = true

		-- flightmodel
		uDef.maxaileron = 0.025
		uDef.maxbank = 0.8
		uDef.maxelevator = 0.025
		uDef.maxpitch = 0.75
		uDef.maxrudder = 0.025
		uDef.wingangle = 0.06593
		uDef.wingdrag = 0.835
		uDef.turnradius = 64
		uDef.turnrate = 1600
		uDef.speedtofront = 0.01
		--uDef.attackrunlength = 32
	end
end

return {
	Tweaks = processRaptorUnitDef,
}
