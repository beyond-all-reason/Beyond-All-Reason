-- UNITDEF -- CORGATE --
--------------------------------------------------------------------------------

local unitName = "corgate"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0,
  activateWhenBuilt  = true,
  bmcode             = 0,
  brakeRate          = 0,
  buildAngle         = 2048,
  buildCostEnergy    = 63833,
  buildCostMetal     = 3736,
  builder            = false,
  buildingGroundDecalDecaySpeed = 30,
  buildingGroundDecalSizeX = 6,
  buildingGroundDecalSizeY = 6,
  buildingGroundDecalType = [[corgate_aoplane.dds]],
  buildPic           = [[CORGATE.DDS]],
  buildTime          = 57166,
  category           = [[ALL NOTLAND NOTSUB NOWEAPON NOTSHIP NOTAIR]],
  corpse             = [[DEAD]],
  description        = [[Plasma Deflector]],
  energyStorage      = 1500,
  energyUse          = 0,
  explodeAs          = [[CRAWL_BLAST]],
  footprintX         = 4,
  footprintZ         = 4,
  iconType           = [[building]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maxDamage          = 3200,
  maxSlope           = 10,
  maxVelocity        = 0,
  maxWaterDepth      = 0,
  metalStorage       = 0,
  name               = [[Overseer]],
  noAutoFire         = false,
  norestrict         = 1,
  objectName         = [[CORGATE]],
  onoffable          = true,
  seismicSignature   = 0,
  selfDestructAs     = [[MINE_NUKE]],
  side               = [[CORE]],
  sightDistance      = 273,
  smoothAnim         = true,
  TEDClass           = [[SPECIAL]],
  turnRate           = 0,
  unitname           = [[corgate]],
  useBuildingGroundDecal = true,
  workerTime         = 0,
  yardMap            = [[oooooooooooooooo]],
  sounds = {
    canceldestruct     = [[cancel2]],
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
      [[drone1]],
    },
    select = {
      [[drone1]],
    },
  },
  weapons = {
    [1]  = {
      def                = [[REPULSOR]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  REPULSOR = {
    isShield           = true,
    name               = [[PlasmaRepulsor]],
    range              = 400,
    shieldAlpha        = 0.4,
    shieldBadColor     = [[1 0.2 0.2]],
    shieldEnergyUse    = 600,
    shieldForce        = 7,
    shieldGoodColor    = [[0.2 1 0.2]],
    shieldInterceptType = 1,
    shieldMaxSpeed     = 3500,
    shieldPower        = 7500,
    shieldPowerRegen   = 150,
    shieldPowerRegenEnergy = 562.5,
    shieldRadius       = 400,
    shieldRepulser     = true,
    smartShield        = true,
    visibleShield      = true,
    visibleShieldHitFrames = 70,
    visibleShieldRepulse = true,
    weaponType         = [[Shield]],
    damage = {
      default            = 100,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 1920,
    description        = [[Overseer Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 20,
    hitdensity         = 100,
    metal              = 2428,
    object             = [[CORGATE_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 960,
    description        = [[Overseer Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 4,
    hitdensity         = 100,
    metal              = 971,
    object             = [[2X2E]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
