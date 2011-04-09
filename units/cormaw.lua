-- UNITDEF -- CORMAW --
--------------------------------------------------------------------------------

local unitName = "cormaw"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 1e-13,
  bmcode             = 1,
  buildAngle         = 8192,
  buildCostEnergy    = 1412,
  buildCostMetal     = 273,
  builder            = false,
  buildingGroundDecalDecaySpeed = 30,
  buildingGroundDecalSizeX = 4,
  buildingGroundDecalSizeY = 4,
  buildingGroundDecalType = [[cormaw_aoplane.dds]],
  buildPic           = [[CORMAW.DDS]],
  buildTime          = 4419,
  canAttack          = true,
  canstop            = 1,
  category           = [[ALL NOTLAND WEAPON NOTSUB NOTSHIP NOTAIR]],
  corpse             = [[DEAD]],
  damageModifier     = 0.15,
  defaultmissiontype = [[GUARD_NOMOVE]],
  description        = [[Pop-up Flamethrower Turret]],
  designation        = [[C-DM]],
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
  maxDamage          = 1450,
  maxSlope           = 10,
  maxWaterDepth      = 0,
  metalStorage       = 0,
  name               = [[Dragon's Maw]],
  noAutoFire         = false,
  noChaseCategory    = [[MOBILE]],
  objectName         = [[CORMAW]],
  radarDistanceJam   = 8,
  seismicSignature   = 0,
  selfDestructAs     = [[MEDIUM_BUILDING]],
  side               = [[CORE]],
  sightDistance      = 422,
  smoothAnim         = false,
  standingfireorder  = 2,
  stealth            = true,
  TEDClass           = [[FORT]],
  threed             = 1,
  turnRate           = 1e-13,
  unitname           = [[cormaw]],
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
      def                = [[DMAW]],
      onlyTargetCategory = [[NOTAIR]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  DMAW = {
    areaOfEffect       = 64,
    burst              = 12,
    burstrate          = 0.01,
    craterBoost        = 0,
    craterMult         = 0,
    endsmoke           = 0,
    fireStarter        = 100,
    flameGfxTime       = 1.9,
    groundbounce       = true,
    impulseBoost       = 0.123,
    impulseFactor      = 0.123,
    intensity          = 0.9,
    lineOfSight        = true,
    name               = [[FlameThrower]],
    noSelfDamage       = true,
    proximityPriority  = 3,
    randomdecay        = 0.2,
    range              = 410,
    reloadtime         = 0.7,
    renderType         = 5,
    rgbColor           = [[1 0.95 0.9]],
    rgbColor2          = [[0.9 0.85 0.8]],
    sizeGrowth         = 1.2,
    smokedelay         = 1,
    soundStart         = [[Flamhvy1]],
    soundTrigger       = false,
    sprayAngle         = 9600,
    startsmoke         = 0,
    targetMoveError    = 0.001,
    tolerance          = 2500,
    turret             = true,
    weaponTimer        = 1,
    weaponType         = [[Flame]],
    weaponVelocity     = 300,
    damage = {
      commanders         = 20,
      default            = 25,
      gunships           = 4,
      hgunships          = 4,
      l1subs             = 5,
      l2subs             = 5,
      l3subs             = 5,
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
    damage             = 600,
    description        = [[Dragon's Maw Wreckage]],
    energy             = 0,
    featureDead        = [[ROCKTEETH]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 20,
    hitdensity         = 100,
    metal              = 177,
    nodrawundergray    = true,
    object             = [[CORDRAG]],
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
