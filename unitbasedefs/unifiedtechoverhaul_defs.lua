local function unifiedtechoverhaulTweaks(name, uDef)
    -- Split T2
        if name == "corlab" then
        uDef.buildoptions = {
			[1] = "corck",
			[2] = "corak",
			[3] = "cornecro",
			[4] = "corstorm",
			[5] = "corthud",
			[6] = "corcrash",
            [7] = "corroach"
		}
    end

    if name == "coralab" then
        uDef.buildoptions = {
			[1] = "corack",
			[2] = "corsumo",
			[3] = "cortermite",
			[4] = "corhrk",
			[5] = "cordecom",
			[6] = "corvoyr",
			[7] = "corspy",
			[8] = "corspec"
		},
    end

    if name == "armalab" then
        uDef.buildoptions = {
            [1] = "armack",
            [2] = "armsnipe",
            [3] = "armfboy",
            [4] = "armspid",
            [5] = "armmark",
            [6] = "armaser",
            [7] = "armspy",
            [8] = "armdecom",
            [9] = "armscab",
            [10] = "armsptk"
        }
    end

    if name == "legalab" then
        uDef.buildoptions = {
			[1] = "legack",
			[3] = "legstr",
			[6] = "leginc",
			[7] = "legsrail",
			[10] = "leghrk",
			[13] = "legaradk",
			[14] = "legaspy",
			[15] = "legajamk",
			[16] = "legdecom",
		},
    end

    
    -- Commanders reduced cloak cost, increased speed
    if name == "armcom" or name == "corcom" or name == "legcom" then
        uDef.cloakCost = 70
        uDef.cloakCostMoving = 700
        uDef.speed = 40
    end

    -- T1 Economy 1.15x HP
    if name == "armwin" or name == "corwin" or name == "legwin"
    or name == "armsolar" or name == "corsolar" or name == "legsolar" 
    or name == "armtide" or name == "cortide" or name == "legtide" 
    or name == "armmakr" or name == "cormakr" or name == "legeconv"
    or name == "corfmkr" or name == "armfmkr" or name == "legfeconv"
    or name == "cornanotc" or name == "armnanotc" or name == "legnanotc"
    or name == "armnanotcplat" or name == "cornanotcplat" or name == "legnanotcplat"
    then
        uDef.health = math.ceil(uDef.health * 0.115) * 10
    end

    -- T1 Mex Hp buff
    if name == "armmex" or name == "cormex" or name == "legmex"
    then
       uDef.health = math.ceil(uDef.health * 0.15) * 10
    end

    -- Advanced Solar Buff - makes Asolar around the efficiency of constant 9 wind
    if name == "armadvsol"
    then
        uDef.metalcost = 330
        uDef.energycost = 2860
    end

    if name == "coradvsol"
    then
        uDef.metalcost = 360
        uDef.energycost = 1460
    end 

    if name == "legadvsol"
    then
        uDef.metalcost = 440
        uDef.energycost = 1940
        uDef.health = 1200
    end

    -- rezbots - 25% less BP in favor of more HP
    if name == "cornecro" or name == "armrectr" or name == "legrezbot"
    then
        uDef.workertime = 150
        uDef.health = math.ceil(uDef.health * 0.125) * 10
    end

    -- Bedbug T1 Rework

    if name == "corroach" then
        uDef.metalcost = 30
        uDef.energycost = 600
        uDef.buildtime = 800
        uDef.health = 120,
        uDef.maxwaterdepth = 16
        uDef.movementclass = "BOT1"
        uDef.radardistance = 700
        uDef.radaremitheight = 18
        uDef.speed = 100
        uDef.explodeas = "mediumExplosionGenericSelfd"
        uDef.selfdestructas = "fb_blastsml"
        uDef.customparams.techlevel = 1
    end

    -- Lab Cost Rework

    -- T1
    if (uDef.customparams.subfolder == "ArmBuildings/LandFactories" or
    uDef.customparams.subfolder == "CorBuildings/LandFactories" or
    uDef.customparams.subfolder == "Legion/Labs"
    uDef.customparams.subfolder == "ArmBuildings/SeaFactories" or
    uDef.customparams.subfolder == "CorBuildings/SeaFactories") 
    and uDef.customparams.techlevel == 1 then
        uDef.metalcost = math.ceil(uDef.metalcost * 0.8)
        uDef.energycost = math.ceil(uDef.energycost * 0.8)
        uDef.buildtime = math.ceil(uDef.buildtime * 0.8)
        uDef.workertime = uDef.workertime * 2
    end 

    -- T2
    if (uDef.customparams.subfolder == "ArmBuildings/LandFactories" or
    uDef.customparams.subfolder == "CorBuildings/LandFactories" or
    uDef.customparams.subfolder == "Legion/Labs"
    uDef.customparams.subfolder == "ArmBuildings/SeaFactories" or
    uDef.customparams.subfolder == "CorBuildings/SeaFactories") 
    and uDef.customparams.techlevel == 2 then
        uDef.metalcost = uDef.metalcost - 1000
        uDef.energycost = uDef.energycost + 2000
        uDef.buildtime = math.ceil(uDef.buildtime * .01333) * 100
        uDef.workertime = uDef.workertime * 4
    end

    if uDef.customparams.techlevel == 2 then 
        uDef.buildtime = math.ceil(uDef.buildtime * 0.015) * 100
    end

    -- T3
    if name == "corgant" or name == "corgantuw" 
    or name == "leggant" or name == "leggantuw" 
    or name == "armshltx" or name == "armshltxuw" then
        uDef.workertime = uDef.workertime * 6
    end

    -- Cortex T1 Reworks
    if name == "corthud" then
        uDef.speed = 55
        uDef.turnrate = 1200
        uDef.turninplacespeedlimit = 1.8
        uDef.sightdistance = 420
        uDef.weapondefs.arm_ham.predictboost = 0.8
        uDef.weapondefs.arm_ham.range = 340
        uDef.weapondefs.arm_ham.damage = {
            default = 52,
            vtol = 11,
        }
        uDef.weapondefs.arm_ham.burst = 2
        uDef.weapondefs.arm_ham.burstrate = 0.2
    end

    if name == "corstorm" then
        uDef.weapondefs.cor_bot_rocket.name = "Light Solid-Fuel Rocket"
        uDef.weapondefs.cor_bot_rocket.range = 500
        uDef.weapondefs.cor_bot_rocket.burst = 3
        uDef.weapondefs.cor_bot_rocket.burstrate = 0.05
        uDef.weapondefs.cor_bot_rocket.mygravity = 0
        uDef.weapondefs.cor_bot_rocket.model = "legsmallrocket.s3o"
        uDef.weapondefs.cor_bot_rocket.damage = {
            default = 52,
        }
        uDef.weapondefs.cor_bot_rocket.trajectoryheight = 0.25
        uDef.weapondefs.cor_bot_rocket.startvelocity = 49
        uDef.weapondefs.cor_bot_rocket.weaponvelocity = 285
        uDef.weapondefs.cor_bot_rocket.weaponacceleration = weaponDef.weaponvelocity - weaponDef.startvelocity
        uDef.weapondefs.cor_bot_rocket.flighttime = 2.05
        uDef.weapondefs.cor_bot_rocket.wobble = 200
        uDef.weapondefs.cor_bot_rocket.smokesize = 2.2
        uDef.weapondefs.cor_bot_rocket.customparams.overrange_distance = 525
        uDef.weapondefs.cor_bot_rocket.customparams.projectile_destruction_method = "descend"
        uDef.weapondefs.cor_bot_rocket.customparams.place_target_on_ground = true
    end

    if name == "corak" then
        uDef.metalcost = math.ceil(uDef.metalcost * 0.85)
        uDef.energycost = math.ceil(uDef.energycost * 0.085) * 10
        uDef.health = math.ceil(uDef.health * 0.09) * 10
        uDef.buildtime = math.ceil(uDef.buildtime * 0.085) * 10
        uDef.weapondefs.gator_laser.range = 210
    end

    if name == "corlevlr" then
        uDef.metalcost = 180
        uDef.energycost = 1800
        uDef.buildtime = math.ceil(uDef.buildtime * 0.0081) * 100
        uDef.health = 1220
        uDef.speed = 51
        uDef.weapondef.corlevlr_weapon.range = 300
    end

    if name == "cormist" then
        uDef.speed = math.ceil(uDef.speed * 0.97)
        uDef.weapondefs.cortruck_missile.range = 590
        uDef.weapondefs.cortruck_missile.areaofeffect = 62
        uDef.weapondefs.cortruck_missile.edgeeffectiveness = 0.85
        uDef.weapondefs.cortruck_missile.burst = 2
        uDef.weapondefs.cortruck_missile.burstrate = 0.2
        uDef.weapondefs.cortruck_missile.reloadtime = 5
        uDef.weapondefs.cortruck_missile.model = "legsmallrocket.s3o" 
        uDef.weapondefs.cortruck_aa.burst = 2
        uDef.weapondefs.cortruck_aa.burstrate = 0.2
        uDef.weapondefs.cortruck_aa.damage = {
            default = 0.5,
            vtol = 60
        }
    end

    -- Armada T1 Reworks
    if name == "armwar" then
        uDef.speed = 61
        uDef.health = math.ceil(uDef.health * 0.08) * 10
        uDef.weapondefs.armwar_laser.name = "Close-Range g2g Burst Laser"
        uDef.weapondefs.armwar_laser.range = 280
        uDef.weapondefs.armwar_laser.rgbcolor = "0.2 0.1 1.0"
        uDef.weapondefs.armwar_laser.burst = 3
        uDef.weapondefs.armwar_laser.burstrate = 0.175
        uDef.weapondefs.armwar_laser.thickness = 3
        uDef.weapondefs.armwar_laser.reloadtime = weaponDef.reloadtime * 1.2
        uDef.weapondefs.armwar_laser.beamtime = 0.04
        uDef.weapondefs.armwar_laser.soudstart = "lasrlit3"
        uDef.weapondefs.armwar_laser.soundtrigger = false
        uDef.weapondefs.armwar_laser.damage = {
           default = 28,
           vtol = 5
        }
    end

    if name == "armham" then
       uDef.weapondefs.arm_ham.name = "Light Gauss Cannon"
       uDef.weapondefs.arm_ham.reloadtime = 0.87
       uDef.weapondefs.arm_ham.weaponvelocity = 572
       uDef.weapoondefs.arm_ham.damage = {
            default = 52,
            vtol = 11
       }
    end





	return uDef
end

return {
	unifiedtechoverhaulTweaks = unifiedtechoverhaulTweaks,
}
