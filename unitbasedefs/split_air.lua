local function splitAirTweaks(name, uDef)
    if name == "armhawk" then
		uDef.metalcost = 1000
		uDef.energycost = 30000
		uDef.buildtime = uDef.buildtime * 2
		uDef.maxacc = 0.8
		uDef.maxdec = 0.2
		uDef.speed = 750
		uDef.maxrudder = 0.014
		uDef.maxbank = 0.8
        uDef.maxaileron = 0.1
		uDef.health = 1800
		uDef.sightdistance = 750
		uDef.cruisealtitude = 240
		uDef.weapondefs.armvtol_advmissile.proximitypriority = 0
		uDef.weapondefs.armvtol_advmissile.areaofeffect = 45
		uDef.weapondefs.armvtol_advmissile.impactonly = 0
		uDef.weapondefs.armvtol_advmissile.flighttime = 0.75
		uDef.weapondefs.armvtol_advmissile.range = 850
        uDef.weapondefs.armvtol_advmissile.burst = 4
        uDef.weapondefs.armvtol_advmissile.burstrate = 0.1
		uDef.weapondefs.armvtol_advmissile.reloadtime = 0.8
		uDef.weapondefs.armvtol_advmissile.startvelocity = 750
        uDef.weapondefs.armvtol_advmissile.weaponvelocity = 1750
        uDef.weapondefs.armvtol_advmissile.weapontimer = 0.8
		uDef.weapondefs.armvtol_advmissile.tolerance = 4000
		uDef.weapondefs.armvtol_advmissile.turnrate = 22000
		uDef.weapondefs.armvtol_advmissile.weaponacceleration = 1000
		uDef.weapondefs.armvtol_advmissile.smoketrail = true
		uDef.weapondefs.armvtol_advmissile.smokePeriod = 12
		uDef.weapondefs.armvtol_advmissile.smoketime = 24
		uDef.weapondefs.armvtol_advmissile.smokesize = 6
        uDef.weapondefs.armvtol_advmissile.soundtrigger = false
		uDef.weapondefs.armvtol_advmissile.cegtag = "missiletrailaa"
		uDef.weapondefs.armvtol_advmissile.explosiongenerator = "custom:genericshellexplosion-medium-bomb"
		uDef.weapondefs.armvtol_advmissile.damage = {
			default = 40,
			vtol = 160,
		}
        uDef.weapons[1].maindir = "0 0 1"
        uDef.weapons[1].maxangledif = 20
        uDef.weapons[1].fastautoretargeting = true
        uDef.weapons[1].fastquerypointupdate = true
	end

    if name == "corvamp" then
		uDef.metalcost = 960
		uDef.energycost = 29200
		uDef.buildtime = uDef.buildtime * 2
		uDef.maxaileron = 0.1
		uDef.maxacc = 0.8
		uDef.maxdec = 0.2
		uDef.speed = 700
		uDef.maxrudder = 0.014
		uDef.maxbank = 0.8
		uDef.health = 2320
		uDef.sightdistance = 550
		uDef.cruisealtitude = 240
		uDef.weapondefs.corvtol_advmissile.impactonly = 0
        uDef.weapondefs.corvtol_advmissile.projectiles = 8
		uDef.weapondefs.corvtol_advmissile.proximitypriority = 0
		uDef.weapondefs.corvtol_advmissile.areaofeffect = 32
		uDef.weapondefs.corvtol_advmissile.flighttime = 0.55
		uDef.weapondefs.corvtol_advmissile.range = 650
		uDef.weapondefs.corvtol_advmissile.reloadtime = 3.4
        uDef.weapondefs.corvtol_advmissile.burst = 2
        uDef.weapondefs.corvtol_advmissile.burstrate = 0.4
		uDef.weapondefs.corvtol_advmissile.tolerance = 4000
		uDef.weapondefs.corvtol_advmissile.turnrate = 11000
		uDef.weapondefs.corvtol_advmissile.weaponacceleration = 1000
        uDef.weapondefs.corvtol_advmissile.startvelocity = 700
        uDef.weapondefs.corvtol_advmissile.weaponvelocity = 1500
		uDef.weapondefs.corvtol_advmissile.smoketrail = true
		uDef.weapondefs.corvtol_advmissile.smokePeriod = 12
		uDef.weapondefs.corvtol_advmissile.smoketime = 24
		uDef.weapondefs.corvtol_advmissile.smokesize = 6
        uDef.weapondefs.corvtol_advmissile.smoketime = 24
		uDef.weapondefs.corvtol_advmissile.soundtrigger = false
		uDef.weapondefs.corvtol_advmissile.cegtag = "missiletrailaa"
		uDef.weapondefs.corvtol_advmissile.explosiongenerator = "custom:genericshellexplosion-medium-bomb"
		uDef.weapondefs.corvtol_advmissile.damage = {
			default = 200,
			vtol = 800,
		}
        uDef.weapons[1].maindir = "0 0 1"
        uDef.weapons[1].maxangledif = 20
        uDef.weapons[1].fastautoretargeting = true
        uDef.weapons[1].fastquerypointupdate = true
	end

    return uDef
end

return {
    splitAirTweaks = splitAirTweaks,
}