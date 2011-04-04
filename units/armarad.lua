-- UNITDEF -- ARMARAD --
--------------------------------------------------------------------------------

local unitName = "armarad"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0,
  activateWhenBuilt  = true,
  bmcode             = 0,
  brakeRate          = 0,
  buildAngle         = 8192,
  buildCostEnergy    = 17830,
  buildCostMetal     = 525,
  builder            = false,
  buildingGroundDecalDecaySpeed = 30,
  buildingGroundDecalSizeX = 4,
  buildingGroundDecalSizeY = 4,
  buildingGroundDecalType = [[armarad_aoplane.dds]],
  buildPic           = [[ARMARAD.DDS]],
  buildTime          = 11800,
  canAttack          = false,
  category           = [[ALL NOTLAND NOTSUB NOWEAPON NOTSHIP NOTAIR]],
  corpse             = [[DEAD]],
  description        = [[Long-Range Radar]],
  energyMake         = 18,
  energyStorage      = 0,
  energyUse          = 18,
  explodeAs          = [[SMALL_BUILDINGEX]],
  footprintX         = 2,
  footprintZ         = 2,
  iconType           = [[building]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maxangledif1       = 1,
  maxDamage          = 320,
  maxSlope           = 10,
  maxVelocity        = 0,
  maxWaterDepth      = 0,
  metalStorage       = 0,
  name               = [[Advanced Radar Tower]],
  noAutoFire         = false,
  objectName         = [[ARMARAD]],
  onoffable          = true,
  radarDistance      = 3500,
  seismicSignature   = 0,
  selfDestructAs     = [[SMALL_BUILDING]],
  side               = [[ARM]],
  sightDistance      = 820,
  smoothAnim         = true,
  TEDClass           = [[SPECIAL]],
  turnRate           = 0,
  unitname           = [[armarad]],
  useBuildingGroundDecal = true,
  workerTime         = 0,
  yardMap            = [[oooo]],
  sounds = {
    activate           = [[radadvn1]],
    canceldestruct     = [[cancel2]],
    deactivate         = [[radadde1]],
    underattack        = [[warning1]],
    working            = [[radar2]],
    count = {
      [[count6]],
      [[count5]],
      [[count4]],
      [[count3]],
      [[count2]],
      [[count1]],
    },
    select = {
      [[radadvn1]],
    },
  },
}


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 192,
    description        = [[Advanced Radar Tower Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 40,
    hitdensity         = 100,
    metal              = 341,
    object             = [[ARMARAD_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 96,
    description        = [[Advanced Radar Tower Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 4,
    hitdensity         = 100,
    metal              = 136,
    object             = [[2X2C]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
