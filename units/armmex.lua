-- UNITDEF -- ARMMEX --
--------------------------------------------------------------------------------

local unitName = "armmex"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0,
  activateWhenBuilt  = true,
  bmcode             = 0,
  brakeRate          = 0,
  buildAngle         = 8192,
  buildCostEnergy    = 521,
  buildCostMetal     = 50,
  builder            = false,
  buildingGroundDecalDecaySpeed = 30,
  buildingGroundDecalSizeX = 5,
  buildingGroundDecalSizeY = 5,
  buildingGroundDecalType = [[armmex_aoplane.dds]],
  buildPic           = [[ARMMEX.DDS]],
  buildTime          = 1800,
  category           = [[ALL NOTLAND NOTSUB NOWEAPON NOTSHIP NOTAIR]],
  corpse             = [[DEAD]],
  description        = [[Extracts Metal]],
  energyStorage      = 0,
  energyUse          = 3,
  explodeAs          = [[TINY_BUILDINGEX]],
  extractsMetal      = 0.001,
  footprintX         = 3,
  footprintZ         = 3,
  iconType           = [[building]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maxDamage          = 170,
  maxSlope           = 20,
  maxVelocity        = 0,
  maxWaterDepth      = 20,
  metalStorage       = 50,
  name               = [[Metal Extractor]],
  noAutoFire         = false,
  objectName         = [[ARMMEX]],
  onoffable          = true,
  seismicSignature   = 0,
  selfDestructAs     = [[TINY_BUILDINGEX]],
  selfDestructCountdown = 1,
  side               = [[ARM]],
  sightDistance      = 273,
  smoothAnim         = true,
  TEDClass           = [[METAL]],
  turnRate           = 0,
  unitname           = [[armmex]],
  useBuildingGroundDecal = true,
  workerTime         = 0,
  yardMap            = [[ooooooooo]],
  sounds = {
    activate           = [[mexrun1]],
    canceldestruct     = [[cancel2]],
    deactivate         = [[mexoff1]],
    underattack        = [[warning1]],
    working            = [[mexrun1]],
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
      [[mexon1]],
    },
  },
}


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 102,
    description        = [[Metal Extractor Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 3,
    footprintZ         = 3,
    height             = 20,
    hitdensity         = 100,
    metal              = 33,
    object             = [[ARMMEX_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 51,
    description        = [[Metal Extractor Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 3,
    footprintZ         = 3,
    height             = 4,
    hitdensity         = 100,
    metal              = 13,
    object             = [[3X3B]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
