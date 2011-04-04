-- UNITDEF -- ARMUWMEX --
--------------------------------------------------------------------------------

local unitName = "armuwmex"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0,
  activateWhenBuilt  = true,
  bmcode             = 0,
  brakeRate          = 0,
  buildAngle         = 8192,
  buildCostEnergy    = 674,
  buildCostMetal     = 55,
  builder            = false,
  buildingGroundDecalDecaySpeed = 30,
  buildingGroundDecalSizeX = 5,
  buildingGroundDecalSizeY = 5,
  buildingGroundDecalType = [[armuwmex_aoplane.dds]],
  buildPic           = [[ARMUWMEX.DDS]],
  buildTime          = 1875,
  category           = [[ALL NOTLAND NOTSUB NOWEAPON NOTSHIP NOTAIR]],
  corpse             = [[DEAD]],
  description        = [[Extracts Metal]],
  energyStorage      = 0,
  energyUse          = 2,
  explodeAs          = [[SMALL_BUILDINGEX]],
  extractsMetal      = 0.001,
  footprintX         = 3,
  footprintZ         = 3,
  iconType           = [[building]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maxDamage          = 180,
  maxSlope           = 24,
  maxVelocity        = 0,
  metalStorage       = 50,
  minWaterDepth      = 15,
  name               = [[Underwater Metal Extractor]],
  noAutoFire         = false,
  objectName         = [[ARMUWMEX]],
  onoffable          = true,
  seismicSignature   = 0,
  selfDestructCountdown = 1,
  side               = [[ARM]],
  sightDistance      = 182,
  smoothAnim         = true,
  TEDClass           = [[METAL]],
  turnRate           = 0,
  unitname           = [[armuwmex]],
  useBuildingGroundDecal = true,
  workerTime         = 0,
  yardMap            = [[ooooooooo]],
  sounds = {
    activate           = [[waterex1]],
    canceldestruct     = [[cancel2]],
    deactivate         = [[waterex1]],
    underattack        = [[warning1]],
    working            = [[waterex1]],
    count = {
      [[count6]],
      [[count5]],
      [[count4]],
      [[count3]],
      [[count2]],
      [[count1]],
    },
    select = {
      [[waterex1]],
    },
  },
}


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 108,
    description        = [[Underwater Metal Extractor Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    footprintX         = 3,
    footprintZ         = 3,
    height             = 20,
    hitdensity         = 100,
    metal              = 36,
    object             = [[ARMUWMEX_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 54,
    description        = [[Underwater Metal Extractor Heap]],
    energy             = 0,
    footprintX         = 3,
    footprintZ         = 3,
    height             = 4,
    hitdensity         = 100,
    metal              = 14,
    object             = [[3X3D]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
