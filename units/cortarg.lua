-- UNITDEF -- CORTARG --
--------------------------------------------------------------------------------

local unitName = "cortarg"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0,
  activateWhenBuilt  = true,
  bmcode             = 0,
  brakeRate          = 0,
  buildAngle         = 4096,
  buildCostEnergy    = 7058,
  buildCostMetal     = 749,
  builder            = false,
  buildingGroundDecalDecaySpeed = 30,
  buildingGroundDecalSizeX = 6,
  buildingGroundDecalSizeY = 6,
  buildingGroundDecalType = [[cortarg_aoplane.dds]],
  buildPic           = [[CORTARG.DDS]],
  buildTime          = 10898,
  category           = [[ALL NOTLAND NOTSUB NOWEAPON NOTSHIP NOTAIR]],
  corpse             = [[DEAD]],
  description        = [[Enhanced Radar Targeting, more facilities enhance accuracy]],
  energyStorage      = 0,
  energyUse          = 150,
  explodeAs          = [[LARGE_BUILDINGEX]],
  footprintX         = 5,
  footprintZ         = 4,
  iconType           = [[building]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  isTargetingUpgrade = true,
  maxDamage          = 1800,
  maxSlope           = 10,
  maxVelocity        = 0,
  maxWaterDepth      = 0,
  metalStorage       = 0,
  name               = [[Targeting Facility]],
  noAutoFire         = false,
  objectName         = [[CORTARG]],
  onoffable          = true,
  seismicSignature   = 0,
  selfDestructAs     = [[LARGE_BUILDING]],
  side               = [[CORE]],
  sightDistance      = 273,
  smoothAnim         = true,
  TEDClass           = [[SPECIAL]],
  turnRate           = 0,
  unitname           = [[cortarg]],
  useBuildingGroundDecal = true,
  workerTime         = 0,
  yardMap            = [[oooooooooooooooooooo]],
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
    damage             = 1080,
    description        = [[Targeting Facility Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 5,
    footprintZ         = 4,
    height             = 20,
    hitdensity         = 100,
    metal              = 487,
    object             = [[CORTARG_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 540,
    description        = [[Targeting Facility Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 5,
    footprintZ         = 4,
    height             = 4,
    hitdensity         = 100,
    metal              = 195,
    object             = [[4X4D]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
