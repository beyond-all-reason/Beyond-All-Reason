--special unit variations used for scavengerbossv4.lua
local unitsTable = {}
--Epic Pawn Squad
unitsTable['squadarmpwt4'] = VFS.Include('units/Scavengers/Bots/armpwt4.lua').armpwt4 --if this filepath is changed, the unit will no longer work!
unitsTable['squadarmpwt4'].selfdestructas = ""
unitsTable['squadarmpwt4'].movestate = 2
unitsTable['squadarmpwt4'].customparams.i18nfromunit = 'armpwt4'
unitsTable['squadarmpwt4'].customparams.inheritxpratemultiplier = 1
unitsTable['squadarmpwt4'].customparams.childreninheritxp = "DRONE"
unitsTable['squadarmpwt4'].customparams.parentsinheritxp = "DRONE"
unitsTable['squadarmpwt4'].weapondefs.dronespawner = {
    areaofeffect = 4,
    avoidfeature = false,
    craterareaofeffect = 0,
    craterboost = 0,
    cratermult = 0,
    edgeeffectiveness = 0.15,
    explosiongenerator = "",
    gravityaffected = "true",
    hightrajectory = 1,
    impulsefactor = 0.123,
    name = "HeavyCannon",
    noselfdamage = true,
    range = 1200,
    reloadtime = 2.5,
    size = 0,
    soundhit = "",
    soundhitwet = "",
    soundstart = "",
    turret = true,
    weapontype = "Cannon",
    weaponvelocity = 360,
    damage = {
        default = 0,
    },
    customparams = {
        carried_unit = "squadarmpw",
        engagementrange = 1200,
        spawns_surface = "LAND",
        spawnrate = 0.5,
        maxunits = 20,
        controlradius = 1300,			
        carrierdeaththroe = "death",
        dockingarmor = 0.001,
        dockinghealrate = 1000,
        docktohealthreshold = 0,
        dockingHelperSpeed = 5,
        dockingpieces = "5 7 9 11",
        dockingradius = 120,	
        holdfireradius = 300
    }
}
unitsTable['squadarmpwt4'].weapons[2] = {
    badtargetcategory = "VTOL",
    def = "dronespawner",
    onlytargetcategory = "NOTSUB",
}

--Epic Pawn's Babies
unitsTable['squadarmpw'] = VFS.Include('units/ArmBots/armpw.lua').armpw --if this filepath is changed, the unit will no longer work!
unitsTable['squadarmpw'].corpse = ""
unitsTable['squadarmpw'].energycost = 1
unitsTable['squadarmpw'].metalcost = 1
unitsTable['squadarmpw'].movestate = 2
unitsTable['squadarmpw'].power = 50
unitsTable['squadarmpw'].mass = 50
unitsTable['squadarmpw'].speed = unitsTable['squadarmpw'].speed*1.5
unitsTable['squadarmpw'].customparams.i18nfromunit = 'armpw'

--Epic Recluse Squad
unitsTable['squadarmsptkt4'] = VFS.Include('units/Scavengers/Bots/armsptkt4.lua').armsptkt4 --if this filepath is changed, the unit will no longer work!
unitsTable['squadarmsptkt4'].selfdestructas = ""
unitsTable['squadarmsptkt4'].movestate = 2
unitsTable['squadarmsptkt4'].customparams.i18nfromunit = 'armsptkt4'
unitsTable['squadarmsptkt4'].customparams.inheritxpratemultiplier = 1
unitsTable['squadarmsptkt4'].customparams.childreninheritxp = "DRONE"
unitsTable['squadarmsptkt4'].customparams.parentsinheritxp = "DRONE"
unitsTable['squadarmsptkt4'].weapondefs.dronespawner = {
    areaofeffect = 4,
    avoidfeature = false,
    craterareaofeffect = 0,
    craterboost = 0,
    cratermult = 0,
    edgeeffectiveness = 0.15,
    explosiongenerator = "",
    gravityaffected = "true",
    hightrajectory = 1,
    impulsefactor = 0.123,
    name = "HeavyCannon",
    noselfdamage = true,
    range = 1200,
    reloadtime = 2.5,
    size = 0,
    soundhit = "",
    soundhitwet = "",
    soundstart = "",
    turret = true,
    weapontype = "Cannon",
    weaponvelocity = 360,
    damage = {
        default = 0,
    },
    customparams = {
        carried_unit = "squadarmsptk",
        engagementrange = 1200,
        spawns_surface = "LAND",
        spawnrate = 3,
        maxunits = 20,
        controlradius = 1300,
        decayrate = 0,
        carrierdeaththroe = "death",
        dockingarmor = 0.001,
        dockinghealrate = 100,
        docktohealthreshold = 0,
        dockingHelperSpeed = 5,
        dockingpieces = "5 7 9 11",
        dockingradius = 120,
        holdfireradius = 300
    }
}
unitsTable['squadarmsptkt4'].weapons[2] = {
    badtargetcategory = "VTOL",
    def = "dronespawner",
    onlytargetcategory = "NOTSUB",
}

--Epic Recluse's Babies
unitsTable['squadarmsptk'] = VFS.Include('units/ArmBots/T2/armsptk.lua').armsptk --if this filepath is changed, the unit will no longer work!
unitsTable['squadarmsptk'].corpse = ""
unitsTable['squadarmsptk'].energycost = 1
unitsTable['squadarmsptk'].metalcost = 1
unitsTable['squadarmsptk'].movestate = 2
unitsTable['squadarmsptk'].power = 500
unitsTable['squadarmsptk'].mass = 500
unitsTable['squadarmsptk'].speed = unitsTable['squadarmsptk'].speed*1.5
unitsTable['squadarmsptk'].customparams.i18nfromunit = 'armsptk'

--Epic Grunt Squad
unitsTable['squadcorakt4'] = VFS.Include('units/Scavengers/Bots/corakt4.lua').corakt4 --if this filepath is changed, the unit will no longer work!
unitsTable['squadcorakt4'].corpse = ""
unitsTable['squadcorakt4'].selfdestructas = ""
unitsTable['squadcorakt4'].movestate = 2
unitsTable['squadcorakt4'].customparams.i18nfromunit = 'corakt4'
unitsTable['squadcorakt4'].customparams.inheritxpratemultiplier = 1
unitsTable['squadcorakt4'].customparams.childreninheritxp = "DRONE"
unitsTable['squadcorakt4'].customparams.parentsinheritxp = "DRONE"
unitsTable['squadcorakt4'].weapondefs.dronespawner = {
    areaofeffect = 4,
    avoidfeature = false,
    craterareaofeffect = 0,
    craterboost = 0,
    cratermult = 0,
    edgeeffectiveness = 0.15,
    explosiongenerator = "",
    gravityaffected = "true",
    hightrajectory = 1,
    impulsefactor = 0.123,
    name = "HeavyCannon",
    noselfdamage = true,
    range = 1200,
    reloadtime = 2.5,
    size = 0,
    soundhit = "",
    soundhitwet = "",
    soundstart = "",
    turret = true,
    weapontype = "Cannon",
    weaponvelocity = 360,
    damage = {
        default = 0,
    },
    customparams = {
        carried_unit = "squadcorak",
        engagementrange = 1200,
        spawns_surface = "LAND",
        spawnrate = 0.5,
        maxunits = 15,
        controlradius = 1300,			
        carrierdeaththroe = "death",
        dockingarmor = 0.001,
        dockinghealrate = 1000,
        docktohealthreshold = 0,
        dockingHelperSpeed = 5,
        dockingpieces = "5 7 9 11",
        dockingradius = 120,	
        holdfireradius = 300
    }
}
unitsTable['squadcorakt4'].weapons[2] = {
    badtargetcategory = "VTOL",
    def = "dronespawner",
    onlytargetcategory = "NOTSUB",
}

--Epic Grunt's Babies
unitsTable['squadcorak'] = VFS.Include('units/CorBots/corak.lua').corak --if this filepath is changed, the unit will no longer work!
unitsTable['squadcorak'].corpse = ""
unitsTable['squadcorak'].energycost = 1
unitsTable['squadcorak'].metalcost = 1
unitsTable['squadcorak'].movestate = 2
unitsTable['squadcorak'].power = 50
unitsTable['squadcorak'].mass = 50
unitsTable['squadcorak'].speed = unitsTable['squadcorak'].speed*1.5
unitsTable['squadcorak'].customparams.i18nfromunit = 'corak'

--Epic Karganeth Squad
unitsTable['squadcorkarganetht4'] = VFS.Include('units/Scavengers/Bots/corkarganetht4.lua').corkarganetht4 --if this filepath is changed, the unit will no longer work!
unitsTable['squadcorkarganetht4'].selfdestructas = ""
unitsTable['squadcorkarganetht4'].movestate = 2
unitsTable['squadcorkarganetht4'].customparams.i18nfromunit = 'corkarganetht4'
unitsTable['squadcorkarganetht4'].customparams.inheritxpratemultiplier = 1
unitsTable['squadcorkarganetht4'].customparams.childreninheritxp = "DRONE"
unitsTable['squadcorkarganetht4'].customparams.parentsinheritxp = "DRONE"
unitsTable['squadcorkarganetht4'].weapondefs.dronespawner = {
    areaofeffect = 4,
    avoidfeature = false,
    craterareaofeffect = 0,
    craterboost = 0,
    cratermult = 0,
    edgeeffectiveness = 0.15,
    explosiongenerator = "",
    gravityaffected = "true",
    hightrajectory = 1,
    impulsefactor = 0.123,
    name = "HeavyCannon",
    noselfdamage = true,
    range = 1200,
    reloadtime = 2.5,
    size = 0,
    soundhit = "",
    soundhitwet = "",
    soundstart = "",
    turret = true,
    weapontype = "Cannon",
    weaponvelocity = 360,
    damage = {
        default = 0,
    },
    customparams = {
        carried_unit = "squadcorkarg",
        engagementrange = 1200,
        spawns_surface = "LAND",
        spawnrate = 8,
        maxunits = 10,
        controlradius = 1300,
        decayrate = 0,
        carrierdeaththroe = "death",
        dockingarmor = 0.001,
        dockinghealrate = 100,
        docktohealthreshold = 0,
        dockingHelperSpeed = 5,
        dockingpieces = "5 7 9 11",
        dockingradius = 120,
        holdfireradius = 300
    }
}
unitsTable['squadcorkarganetht4'].weapons[4] = {
    badtargetcategory = "VTOL",
    def = "dronespawner",
    onlytargetcategory = "NOTSUB",
}

--Epic Tzar's Babies
unitsTable['squadcorkarg'] = VFS.Include('units/CorGantry/corkarg.lua').corkarg --if this filepath is changed, the unit will no longer work!
unitsTable['squadcorkarg'].corpse = ""
unitsTable['squadcorkarg'].energycost = 1
unitsTable['squadcorkarg'].metalcost = 1
unitsTable['squadcorkarg'].movestate = 2
unitsTable['squadcorkarg'].power = 1800
unitsTable['squadcorkarg'].mass = 500
unitsTable['squadcorkarg'].speed = unitsTable['squadcorkarg'].speed*1.5
unitsTable['squadcorkarg'].customparams.i18nfromunit = 'corkarg'


return unitsTable
