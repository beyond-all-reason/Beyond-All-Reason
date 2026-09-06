local function airReworkUnitTweaks(name, uDef)

	if uDef.fronttospeed == nil then
		uDef.fronttospeed = 0.05
	end

	if uDef.mygravity == nil then
		uDef.mygravity = 0.25
	end

	if name == "armhawk" then
		uDef.metalcost = 250
		uDef.energycost = 7600
		uDef.buildtime = 12000
		uDef.maxaileron = 0.02
		uDef.maxacc = 0.21
		uDef.maxdec = 0.1
		uDef.speed = 320
		uDef.maxrudder = 0.011
		uDef.maxbank = 0.65
		uDef.health = 740
		uDef.sightdistance = 550
		uDef.cruisealtitude = 240

		uDef.weapondefs.armvtol_advmissile.proximitypriority = 0
		uDef.weapondefs.armvtol_advmissile.areaofeffect = 45
		uDef.weapondefs.armvtol_advmissile.impactonly = 0
		uDef.weapondefs.armvtol_advmissile.flighttime = 2.3
		uDef.weapondefs.armvtol_advmissile.range = 780
		uDef.weapondefs.armvtol_advmissile.reloadtime = 3.2
		uDef.weapondefs.armvtol_advmissile.startvelocity = 100
		uDef.weapondefs.armvtol_advmissile.tolerance = 100000
		uDef.weapondefs.armvtol_advmissile.turnrate = 37000
		uDef.weapondefs.armvtol_advmissile.weaponacceleration = 310
		uDef.weapondefs.armvtol_advmissile.smoketrail = true
		uDef.weapondefs.armvtol_advmissile.smokePeriod = 12
		uDef.weapondefs.armvtol_advmissile.smoketime = 24
		uDef.weapondefs.armvtol_advmissile.smokesize = 6
		uDef.weapondefs.armvtol_advmissile.cegtag = "missiletrailaa"
		uDef.weapondefs.armvtol_advmissile.explosiongenerator = "custom:genericshellexplosion-medium-bomb"
		uDef.weapondefs.armvtol_advmissile.damage = {
			default = 1,
			vtol = 500,
		}
	end

	if name == "armfig" then
		uDef.metalcost = 150
		uDef.energycost = 4500
		uDef.buildtime = 5000
		uDef.speed = 270
		uDef.maxacc = 0.15
		uDef.maxdec = 0.1
		uDef.maxrudder = 0.01
		uDef.maxbank = 0.65
		uDef.health = 460
		uDef.sightdistance = 460
		uDef.cruisealtitude = 160
		uDef.turnradius = 64
		--uDef.speedtofront = 0.025
		--uDef.weapondefs.armvtol_missile.explosiongenerator = "custom:genericshellexplosion-tiny"
		--uDef.weapondefs.armvtol_missile.smokePeriod = 8
		--uDef.weapondefs.armvtol_missile.smoketime = 14
		--uDef.weapondefs.armvtol_missile.smokesize = 5.0
		--uDef.weapondefs.armvtol_missile.smokecolor = 0.66
		--uDef.weapondefs.armvtol_missile.cegtag = "missiletrailtiny"
		uDef.weapondefs.armvtol_missile.proximitypriority = 0
		uDef.weapondefs.armvtol_missile.flighttime = 1.7
		uDef.weapondefs.armvtol_missile.range = 550
		uDef.weapondefs.armvtol_missile.reloadtime = 1.3
		uDef.weapondefs.armvtol_missile.startvelocity = 110
		uDef.weapondefs.armvtol_missile.tolerance = 10000
		uDef.weapondefs.armvtol_missile.turnrate = 23000
		--uDef.weapondefs.armvtol_missile.name = "Light guided a2a/a2g missile launcher"
		uDef.weapondefs.armvtol_missile.weaponacceleration = 310
		--uDef.weapondefs.armvtol_missile.canattackground = true
		uDef.weapondefs.armvtol_missile.damage = {
			--default = 64,
			vtol = 200,
		}
		--uDef.weapons[1].onlytargetcategory = "NOTSUB"
	end
	if name == "armsfig2" then
		uDef.metalcost = 450
		uDef.energycost = 6500
		uDef.buildtime = 14000
		uDef.speed = 200
		uDef.maxacc = 0.13
		uDef.maxrudder = 0.016
		uDef.maxbank = 0.5
		--uDef.maxpitch = 0.02
		--uDef.maxelevator = 0.02
		uDef.health = 2700
		uDef.sightdistance = 460
		uDef.cruisealtitude = 160
		--uDef.turnradius = 128
		uDef.weapondefs.armsfig_weapon.proximitypriority = 0
		uDef.weapondefs.armsfig_weapon.flighttime = 1.4
		uDef.weapondefs.armsfig_weapon.range = 650
		uDef.weapondefs.armsfig_weapon.burst = 2
		uDef.weapondefs.armsfig_weapon.burstrate = 0.15
		uDef.weapondefs.armsfig_weapon.explosiongenerator = "custom:genericshellexplosion-medium-bomb"
		uDef.weapondefs.armsfig_weapon.smokePeriod = 7
		uDef.weapondefs.armsfig_weapon.smoketime = 48
		uDef.weapondefs.armsfig_weapon.smokesize = 10
		uDef.weapondefs.armsfig_weapon.smoketrail = true
		uDef.weapondefs.armsfig_weapon.areaofeffect = 245
		uDef.weapondefs.armsfig_weapon.reloadtime = 1.5
		uDef.weapondefs.armsfig_weapon.startvelocity = 100
		uDef.weapondefs.armsfig_weapon.tolerance = 1000
		uDef.weapondefs.armsfig_weapon.turnrate = 8000
		uDef.weapondefs.armsfig_weapon.weaponacceleration = 300
		uDef.weapondefs.armsfig_weapon.weaponvelocity = 1000
		uDef.weapondefs.armsfig_weapon.wobble = 3
		uDef.weapondefs.armsfig_weapon.dance = 20
		uDef.weapondefs.armsfig_weapon.damage = {
			default = 1,
			vtol = 180,
		}
	end
	if name == "corvamp" then
		uDef.metalcost = 240
		uDef.energycost = 7300
		uDef.buildtime = uDef.buildtime * 1.35
		uDef.maxaileron = 0.02
		uDef.maxacc = 0.21
		uDef.maxdec = 0.1
		uDef.speed = 340
		uDef.maxrudder = 0.014
		uDef.maxbank = 0.65
		uDef.health = 580
		uDef.sightdistance = 550
		uDef.cruisealtitude = 240
		uDef.weapondefs.corvtol_advmissile.impactonly = 0
		uDef.weapondefs.corvtol_advmissile.proximitypriority = 0
		uDef.weapondefs.corvtol_advmissile.areaofeffect = 32
		uDef.weapondefs.corvtol_advmissile.flighttime = 2.2
		uDef.weapondefs.corvtol_advmissile.range = 710
		uDef.weapondefs.corvtol_advmissile.reloadtime = 1.7
		uDef.weapondefs.corvtol_advmissile.startvelocity = 100
		uDef.weapondefs.corvtol_advmissile.tolerance = 100000
		uDef.weapondefs.corvtol_advmissile.turnrate = 37000
		uDef.weapondefs.corvtol_advmissile.weaponacceleration = 310
		uDef.weapondefs.corvtol_advmissile.smoketrail = true
		uDef.weapondefs.corvtol_advmissile.smokePeriod = 12
		uDef.weapondefs.corvtol_advmissile.smoketime = 24
		uDef.weapondefs.corvtol_advmissile.smokesize = 6
		uDef.weapondefs.corvtol_advmissile.cegtag = "missiletrailaa"
		uDef.weapondefs.corvtol_advmissile.explosiongenerator = "custom:genericshellexplosion-medium-bomb"
		uDef.weapondefs.corvtol_advmissile.damage = {
			default = 1,
			vtol = 300,
		}
	end
	if name == "corveng" then
		uDef.metalcost = 150
		uDef.energycost = 4500
		uDef.buildtime = 5000
		uDef.speed = 270
		uDef.maxacc = 0.15
		uDef.maxdec = 0.1
		uDef.maxrudder = 0.012
		uDef.maxbank = 0.65
		uDef.health = 460
		uDef.sightdistance = 460
		uDef.cruisealtitude = 160
		uDef.turnradius = 64
		--uDef.speedtofront = 0.025
		--uDef.weapondefs.corvtol_missile.explosiongenerator = "custom:genericshellexplosion-tiny"
		--uDef.weapondefs.corvtol_missile.smokePeriod = 8
		--uDef.weapondefs.corvtol_missile.smoketime = 14
		--uDef.weapondefs.corvtol_missile.smokesize = 5.0
		--uDef.weapondefs.corvtol_missile.smokecolor = 0.66
		--uDef.weapondefs.corvtol_missile.cegtag = "missiletrailtiny"
		uDef.weapondefs.corvtol_missile.proximitypriority = 0
		uDef.weapondefs.corvtol_missile.flighttime = 1.7
		uDef.weapondefs.corvtol_missile.range = 550
		uDef.weapondefs.corvtol_missile.reloadtime = 1.3
		uDef.weapondefs.corvtol_missile.startvelocity = 110
		uDef.weapondefs.corvtol_missile.tolerance = 10000
		uDef.weapondefs.corvtol_missile.turnrate = 23000
		uDef.weapondefs.corvtol_missile.weaponacceleration = 350
		--uDef.weapondefs.corvtol_missile.canattackground = true
		--uDef.weapondefs.corvtol_missile.name = "Light guided a2a/a2g missile launcher"
		uDef.weapondefs.corvtol_missile.damage = {
			--default = 64,
			vtol = 200,
		}
		--uDef.weapons[1].onlytargetcategory = "NOTSUB"
	end
	if name == "corsfig2" then
		uDef.metalcost = 520
		uDef.energycost = 8000
		uDef.buildtime = 11000
		uDef.speed = 200
		uDef.maxacc = 0.12
		uDef.maxrudder = 0.016
		uDef.maxbank = 0.5
		--uDef.maxpitch = 0.02
		--uDef.maxelevator = 0.02
		uDef.health = 3000
		uDef.sightdistance = 460
		uDef.cruisealtitude = 160
		uDef.turnradius = 128
		uDef.weapondefs.corsfig_weapon.proximitypriority = -1
		uDef.weapondefs.corsfig_weapon.flighttime = 1.7
		uDef.weapondefs.corsfig_weapon.range = 680
		uDef.weapondefs.corsfig_weapon.areaofeffect = 220
		uDef.weapondefs.corsfig_weapon.edgeeffectiveness = 0.55
		uDef.weapondefs.corsfig_weapon.reloadtime = 6.1
		uDef.weapondefs.corsfig_weapon.startvelocity = 100
		uDef.weapondefs.corsfig_weapon.tolerance = 12500
		uDef.weapondefs.corsfig_weapon.turnrate = 19000
		uDef.weapondefs.corsfig_weapon.weaponacceleration = 250
		uDef.weapondefs.corsfig_weapon.cegtag = "missiletraillarge-red"
		uDef.weapondefs.corsfig_weapon.explosiongenerator = "custom:genericshellexplosion-large-bomb"
		uDef.weapondefs.corsfig_weapon.model = "banishermissile.s3o"
		uDef.weapondefs.corsfig_weapon.smoketrail = true
		uDef.weapondefs.corsfig_weapon.smokePeriod = 7
		uDef.weapondefs.corsfig_weapon.smoketime = 48
		uDef.weapondefs.corsfig_weapon.smokesize = 11.3
		uDef.weapondefs.corsfig_weapon.smokecolor = 0.82
		uDef.weapondefs.corsfig_weapon.soundhit = "corban_b"
		uDef.weapondefs.corsfig_weapon.soundhitwet = "splsmed"
		uDef.weapondefs.corsfig_weapon.soundstart = "corban_a"
		uDef.weapondefs.corsfig_weapon.texture1 = "null"
		uDef.weapondefs.corsfig_weapon.texture2 = "railguntrail"
		uDef.weapondefs.corsfig_weapon.weaponvelocity = 650
		uDef.weapondefs.corsfig_weapon.damage = {
			default = 1,
			vtol = 1000,
		}
	end


	if name == "corshad" or name == "armthund" then
		uDef.metalcost = uDef.metalcost * 1.2
		uDef.health = uDef.health * 1.25
		uDef.speed = uDef.speed * 0.9
		uDef.maxbank = 0.65
		uDef.maxrudder = 0.01
		uDef.maxacc = 0.13
		uDef.maxdec = 0.08
	end

	if name == "corhurc" or name == "armpnix" then
		uDef.metalcost = uDef.metalcost * 2
		uDef.speed = uDef.speed * 0.75
		uDef.health = uDef.health * 2
		uDef.maxrudder = 0.0085
		uDef.maxbank = 0.5
		uDef.maxacc = 0.1
		uDef.maxdec = 0.08
	end

	if name == "corhurc" then
		uDef.weapondefs.coradvbomb.burstrate = 0.26
		uDef.weapondefs.coradvbomb.mygravity = nil
		uDef.weapondefs.coradvbomb.damage = {
			default = 500
		}
	end
	if name == "armpnix" then
		uDef.weapondefs.armadvbomb.burstrate = 0.3
		uDef.weapondefs.armadvbomb.burst = 6
		uDef.weapondefs.armadvbomb.areaofeffect = 200
		uDef.weapondefs.armadvbomb.mygravity = nil
		uDef.weapondefs.armadvbomb.damage= {
			default = 330
		}
	end

	if name == "armpeep" or name == "corfink" or name == "corhunt" or name == "armsehak" then
		uDef.hoverattack = true
		uDef.turnrate = 900
		uDef.maxdec = 0.5
		uDef.turninplaceanglelimit = 360

	end

	if name == "armaap" then
		local numBuildoptions = #uDef.buildoptions
		uDef.buildoptions[numBuildoptions + 1] = "armsfig2"
	end
	if name == "coraap" then
		local numBuildoptions = #uDef.buildoptions
		uDef.buildoptions[numBuildoptions + 1] = "corsfig2"
	end
	

	return uDef
end

local function airReworkWeaponTweaks(weaponDef)
	--[[local damage = weaponDef.damage
	if weaponDef.weapontype == "BeamLaser" then
		damage.vtol = damage.default * 0.25
	end
	if weaponDef.range == 300 and weaponDef.reloadtime == 0.4 then
		--comm lasers
		damage.vtol = damage.default
	end
	if weaponDef.weapontype == "Cannon" and damage.default then
		damage.vtol = damage.default * 0.35
	end]]--
end

return {
	UnitTweaks = airReworkUnitTweaks,
	WeaponTweaks = airReworkWeaponTweaks,
}
