-- UNITDEF -- CORFUS --
--------------------------------------------------------------------------------

local unitName = "corfus"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0,
  activateWhenBuilt  = true,
  bmcode             = 0,
  brakeRate          = 0,
  buildAngle         = 16384,
  buildCostEnergy    = 25292,
  buildCostMetal     = 4203,
  builder            = false,
  buildingGroundDecalDecaySpeed = 30,
  buildingGroundDecalSizeX = 8,
  buildingGroundDecalSizeY = 8,
  buildingGroundDecalType = [[corfus_aoplane.dds]],
  buildPic           = [[CORFUS.DDS]],
  buildTime          = 75424,
  category           = [[ALL NOTLAND NOTSUB NOWEAPON NOTSHIP NOTAIR]],
  corpse             = [[DEAD]],
  description        = [[Produces Energy / Storage]],
  energyMake         = 1100,
  energyStorage      = 2500,
  energyUse          = 0,
  explodeAs          = [[ATOMIC_BLAST]],
  footprintX         = 5,
  footprintZ         = 5,
  hideDamage         = true,
  iconType           = [[building]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maxDamage          = 4500,
  maxSlope           = 10,
  maxVelocity        = 0,
  maxWaterDepth      = 1,
  metalStorage       = 0,
  name               = [[Fusion Reactor]],
  noAutoFire         = false,
  objectName         = [[CORFUS]],
  seismicSignature   = 0,
  selfDestructAs     = [[MINE_NUKE]],
  side               = [[CORE]],
  sightDistance      = 273,
  smoothAnim         = true,
  TEDClass           = [[ENERGY]],
  turnRate           = 0,
  unitname           = [[corfus]],
  useBuildingGroundDecal = true,
  workerTime         = 0,
  yardMap            = [[ooooooooooooooooooooooooo]],
  sounds = {
    canceldestruct     = [[cancel2]],
    underattack        = [[warning1]],
    count = {
      [[count6]],
      [[count5]],
      [[count4]],
      [[count3]],
      [[count2]],
      [[count1]],
    },
    select = {
      [[fusion2]],
    },
  },
}


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 5100,
    description        = [[Fusion Reactor Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 5,
    footprintZ         = 5,
    height             = 20,
    hitdensity         = 100,
    metal              = 2927,
    object             = [[CORFUS_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 2550,
    description        = [[Fusion Reactor Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 5,
    footprintZ         = 5,
    height             = 4,
    hitdensity         = 100,
    metal              = 1171,
    object             = [[5X5D]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
