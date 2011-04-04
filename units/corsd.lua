-- UNITDEF -- CORSD --
--------------------------------------------------------------------------------

local unitName = "corsd"

--------------------------------------------------------------------------------

local unitDef = {
  activateWhenBuilt  = true,
  bmcode             = 0,
  buildAngle         = 4096,
  buildCostEnergy    = 6363,
  buildCostMetal     = 698,
  buildingGroundDecalDecaySpeed = 30,
  buildingGroundDecalSizeX = 6,
  buildingGroundDecalSizeY = 6,
  buildingGroundDecalType = [[corsd_aoplane.dds]],
  buildPic           = [[CORSD.DDS]],
  buildTime          = 11955,
  category           = [[ALL NOTLAND NOTSUB NOWEAPON NOTSHIP NOTAIR]],
  corpse             = [[DEAD]],
  description        = [[Intrusion Countermeasure System]],
  energyUse          = 125,
  explodeAs          = [[LARGE_BUILDINGEX]],
  footprintX         = 4,
  footprintZ         = 4,
  iconType           = [[building]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  levelGround        = false,
  maxDamage          = 2500,
  maxSlope           = 36,
  maxWaterDepth      = 0,
  name               = [[Nemesis]],
  objectName         = [[CORSD]],
  onoffable          = true,
  seismicDistance    = 2000,
  seismicSignature   = 0,
  selfDestructAs     = [[LARGE_BUILDING]],
  side               = [[CORE]],
  sightDistance      = 225,
  TEDClass           = [[SPECIAL]],
  unitname           = [[corsd]],
  useBuildingGroundDecal = true,
  yardMap            = [[oooooooooooooooo]],
  sounds = {
    activate           = [[targon2]],
    canceldestruct     = [[cancel2]],
    deactivate         = [[targoff2]],
    underattack        = [[warning1]],
    working            = [[targsel2]],
    count = {
      [[count6]],
      [[count5]],
      [[count4]],
      [[count3]],
      [[count2]],
      [[count1]],
    },
    select = {
      [[targsel2]],
    },
  },
}


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 1500,
    description        = [[Nemesis Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 4,
    footprintZ         = 4,
    height             = 15,
    hitdensity         = 100,
    metal              = 584,
    object             = [[CORSD_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 750,
    description        = [[Nemesis Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 4,
    footprintZ         = 4,
    height             = 4,
    hitdensity         = 100,
    metal              = 234,
    object             = [[4X4A]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
