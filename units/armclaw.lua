-- UNITDEF -- ARMCLAW --
--------------------------------------------------------------------------------

local unitName = "armclaw"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 1e-13,
  bmcode             = 1,
  buildAngle         = 8192,
  buildCostEnergy    = 1546,
  buildCostMetal     = 315,
  builder            = false,
  buildingGroundDecalDecaySpeed = 30,
  buildingGroundDecalSizeX = 4,
  buildingGroundDecalSizeY = 4,
  buildingGroundDecalType = [[armclaw_aoplane.dds]],
  buildPic           = [[ARMCLAW.DDS]],
  buildTime          = 4638,
  canAttack          = true,
  canstop            = 1,
  category           = [[ALL NOTLAND WEAPON NOTSUB NOTSHIP NOTAIR]],
  corpse             = [[DEAD]],
  damageModifier     = 0.15,
  defaultmissiontype = [[GUARD_NOMOVE]],
  description        = [[Pop-up Lightning Turret]],
  designation        = [[A-DC]],
  digger             = 1,
  downloadable       = 1,
  energyMake         = 0,
  energyStorage      = 15,
  energyUse          = 0,
  explodeAs          = [[MEDIUM_BUILDINGEX]],
  firestandorders    = 1,
  footprintX         = 2,
  footprintZ         = 2,
  hideDamage         = true,
  iconType           = [[building]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  mass               = 1e+10,
  maxDamage          = 1200,
  maxSlope           = 10,
  maxWaterDepth      = 0,
  metalStorage       = 0,
  name               = [[Dragon's Claw]],
  noAutoFire         = false,
  noChaseCategory    = [[MOBILE]],
  objectName         = [[ARMCLAW]],
  radarDistanceJam   = 8,
  seismicSignature   = 0,
  selfDestructAs     = [[MEDIUM_BUILDING]],
  side               = [[ARM]],
  sightDistance      = 440,
  smoothAnim         = true,
  standingfireorder  = 2,
  stealth            = true,
  TEDClass           = [[FORT]],
  threed             = 1,
  turnRate           = 1e-13,
  unitname           = [[armclaw]],
  upright            = true,
  useBuildingGroundDecal = true,
  version            = 1,
  workerTime         = 0,
  zbuffer            = 1,
  sounds = {
    canceldestruct     = [[cancel2]],
    cloak              = [[kloak1]],
    uncloak            = [[kloak1un]],
    underattack        = [[warning1]],
    cant = {
      [[cantdo4]],
    },
    count = {
      [[count6]],
      [[count5]],
      [[count4]],
      [[count3]],
      [[count2]],
      [[count1]],
    },
    ok = {
      [[servmed2]],
    },
    select = {
      [[servmed2]],
    },
  },
  weapons = {
    [1]  = {
      def                = [[DCLAW]],
      onlyTargetCategory = [[NOTAIR]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  DCLAW = {
    areaOfEffect       = 8,
    beamWeapon         = true,
    color              = 128,
    color2             = 130,
    craterBoost        = 0,
    craterMult         = 0,
    duration           = 8,
    explosionGenerator = [[custom:LIGHTNING_FLASH]],
    fireStarter        = 50,
    impactonly         = 1,
    impulseBoost       = 0.123,
    impulseFactor      = 0.123,
    lineOfSight        = true,
    name               = [[LightningGun]],
    noSelfDamage       = true,
    range              = 440,
    reloadtime         = 1.15,
    renderType         = 7,
    soundHit           = [[lashit]],
    soundStart         = [[lghthvy1]],
    soundTrigger       = true,
    startsmoke         = 1,
    turret             = true,
    weaponType         = [[LightningCannon]],
    weaponVelocity     = 450,
    damage = {
      commanders         = 390,
      default            = 210,
      gunships           = 23,
      hgunships          = 23,
      l1bombers          = 25,
      l1fighters         = 25,
      l1subs             = 3,
      l2bombers          = 25,
      l2fighters         = 25,
      l2subs             = 3,
      l3subs             = 3,
      vradar             = 25,
      vtol               = 25,
      vtrans             = 25,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    autoreclaimable    = 0,
    blocking           = true,
    category           = [[corpses]],
    damage             = 540,
    description        = [[Dragon's Claw Wreckage]],
    energy             = 0,
    featureDead        = [[ROCKTEETH]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 20,
    hitdensity         = 100,
    metal              = 205,
    nodrawundergray    = true,
    object             = [[ARMDRAG]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  ROCKTEETH = {
    animating          = 0,
    animtrans          = 0,
    blocking           = false,
    category           = [[rocks]],
    damage             = 500,
    description        = [[Rubble]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 20,
    hitdensity         = 100,
    metal              = 2,
    object             = [[2X2A]],
    reclaimable        = true,
    shadtrans          = 1,
    world              = [[greenworld]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
