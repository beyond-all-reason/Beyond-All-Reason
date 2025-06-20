local function proposed_unit_reworksTweaks(name, uDef)
	if name == "armsam" then
		uDef.weapondefs.armtruck_missile.tracking = true
		uDef.weapondefs.armtruck_missile.range = 525
		uDef.weapondefs.armtruck_missile.turnrate = 63000
		uDef.weapondefs.armtruck_missile.damage.default = 55
		uDef.collisionvolumetype = "ellipsoid"
		uDef.collisionvolumescales = "29 31 41"
		uDef.collisionvolumeoffsets = "0 3 -1"
	end
	if name == "cormist" then
		uDef.weapondefs.cortruck_missile.tracking = true
		uDef.weapondefs.cortruck_missile.range = 550
		uDef.weapondefs.cortruck_missile.turnrate = 63000
		uDef.weapondefs.cortruck_missile.damage.default = 40
		uDef.collisionvolumetype = "ellipsoid"
		uDef.collisionvolumescales = "32 31 43"
		uDef.collisionvolumeoffsets = "0 0 -2"
	end
	if name == "corstorm" then
		uDef.speed = math.ceil(uDef.speed + 3)
		uDef.turnrate = 1150
		uDef.weapondefs.cor_bot_rocket.predictboost = 0.4
	end
	if name == "armrock" then
		uDef.speed = math.ceil(uDef.speed + 3)
		uDef.turnrate = 1150
		uDef.weapondefs.arm_bot_rocket.predictboost = 0.4
	end
	if name == "corthud" or name == "armham" then
		uDef.speed = math.ceil(uDef.speed + 3)
		uDef.weapondefs.arm_ham.predictboost = 0.8
		uDef.turnrate = 1150
	end
	if name == "armwar" then
		uDef.speed = uDef.speed + 3
		uDef.turnrate = 750
	end
	if name == "armstump" or name == "corraid" then
		uDef.weapondefs.arm_lightcannon.predictboost = 0.4
	end

	if name == "armmex" or name == "cormex" then
		uDef.health = uDef.health + 61
	end
	if name == "armck" or name == "corck" then
		uDef.health = uDef.health + 90
	end
	if name == "armllt" or name == "corllt" or name == "armbeamer" or name == "corhllt" or name == "corhlt" or name == "armhlt" or name == "armguard" or name == "corpun" or name == "armdl" or name == "cordl" then
		uDef.buildtime = math.ceil(uDef.buildtime * 0.009) * 100	-- 0.9x buildtime
	end
	if uDef.customparams.subfolder and uDef.buildtime and (uDef.customparams.subfolder == "CorShips" or uDef.customparams.subfolder == "ArmShips") then
		uDef.buildtime = math.ceil(uDef.buildtime * 0.015) * 100	-- 1.5x buildtime
	end

	if name == "armfast" then
		uDef.metalcost = math.floor(uDef.metalcost *0.9)
		uDef.energycost = math.floor(uDef.energycost *0.9)
		uDef.buildtime = math.floor(uDef.buildtime *0.9)
	end
	if name == "corcan" then
		uDef.speed = 39
	end
	if name == "cortermite" then
		uDef.metalcost = math.floor(uDef.metalcost *0.9)
		uDef.energycost = math.floor(uDef.energycost *0.9)
		uDef.buildtime = math.floor(uDef.buildtime *0.9)
		uDef.speed = 50
	end

	if name == "armepoch" then
		uDef.weapondefs.heavyplasma.reloadtime = 5
		uDef.weapondefs.heavyplasma.areaofeffect = 160
		uDef.weapondefs.heavyplasma.burstrate = 0.8
		uDef.weapondefs.heavyplasma.explosiongenerator = "custom:genericshellexplosion-large-aoe"
		uDef.weapondefs.heavyplasma.impulsefactor = 1
	end
	if name == "corblackhy" then
		uDef.weapondefs.heavyplasma.reloadtime = 7
		uDef.weapondefs.heavyplasma.areaofeffect = 240
		uDef.weapondefs.heavyplasma.burstrate = 0.8
		uDef.weapondefs.heavyplasma.explosiongenerator = "custom:genericshellexplosion-large-aoe"
		uDef.weapondefs.heavyplasma.impulsefactor = 1
	end
	if name == "corkorg" then
		uDef.speed = 37
	end

	if name == "armrectr" or name == "cornecro" then
		uDef.metalcost = 140
		uDef.energycost = 1500
		uDef.buildtime = 3000
	end
	if name == "armrecl" or name == "correcl" then
		uDef.metalcost = 230
		uDef.energycost = 3500
		uDef.buildtime = 6500
		uDef.speed = 60
	end



	--if name == "armvp" or name == "corvp" then
	--	uDef.metalcost = uDef.metalcost - 30
	--end
	if name == "corgator" then
		uDef.speed = 84
	end
	if name == "armpw" then
		uDef.speed = 85
	end
	if name == "armmanni" then
		uDef.energycost = 17000
	end
	if name == "armbull" then
		uDef.speed = 61
	end
	if name == "armlatnk" then
		uDef.weapondefs.lightning.damage.default = 21
	end
	if name == "armmart" then
		uDef.energycost = 6000
	end
		if name == "cormart" then
		uDef.energycost = 5500
		uDef.buildtime = 8000
	end

	if name == "corspy" then
		uDef.buildtime = 15000
		uDef.energycost = 10000
	end

	if name == "armspy" then
	uDef.script = "Units/ARMSPY2.cob"
	uDef.selfdestructas = "smallExplosionGeneric"
	uDef.weapondefs.crawl_dummy = {
		areaofeffect = 32,
		avoidfeature = false,
		beamdecay = 0.5,
		beamtime = 1,
		beamttl = 1,
		collidefriendly = false,
		corethickness = 0.4,
		craterareaofeffect = 0,
		craterboost = 0,
		cratermult = 0,
		duration = 0.01,
		edgeeffectiveness = 0.15,
		energypershot = 500,
		explosiongenerator = "custom:laserhit-emp",
		impulsefactor = 0,
		laserflaresize = 6.05,
		name = "Heavy EMP beam",
		noselfdamage = true,
		paralyzer = true,
		paralyzetime = 10,
		range = 210,
		reloadtime = 20,
		rgbcolor = "0.7 0.7 1",
		soundhitdry = "",
		soundhitwet = "sizzle",
		soundstart = "hackshotxl3",
		soundtrigger = 1,
		thickness = 3.5,
		tolerance = 6000,
		turret = false,
		weapontype = "BeamLaser",
		weaponvelocity = 1000,
		damage = {
			default = 18000,
		},
		}
	end

	return uDef
end

return {
	proposed_unit_reworksTweaks = proposed_unit_reworksTweaks,
}
