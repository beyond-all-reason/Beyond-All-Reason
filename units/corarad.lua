-- UNITDEF -- CORARAD --
--------------------------------------------------------------------------------

local unitName = "corarad"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0,
  activateWhenBuilt  = true,
  bmcode             = 0,
  brakeRate          = 0,
  buildAngle         = 8192,
  buildCostEnergy    = 17920,
  buildCostMetal     = 522,
  builder            = false,
  buildingGroundDecalDecaySpeed = 30,
  buildingGroundDecalSizeX = 4,
  buildingGroundDecalSizeY = 4,
  buildingGroundDecalType = [[corarad_aoplane.dds]],
  buildPic           = [[CORARAD.DDS]],
  buildTime          = 11960,
  canAttack          = false,
  category           = [[ALL NOTLAND NOTSUB NOWEAPON NOTSHIP NOTAIR]],
  corpse             = [[DEAD]],
  description        = [[Long-Range Radar]],
  energyMake         = 17,
  energyStorage      = 0,
  energyUse          = 17,
  explodeAs          = [[SMALL_BUILDINGEX]],
  footprintX         = 2,
  footprintZ         = 2,
  iconType           = [[building]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maxangledif1       = 1,
  maxDamage          = 330,
  maxSlope           = 10,
  maxVelocity        = 0,
  maxWaterDepth      = 0,
  metalStorage       = 0,
  name               = [[Advanced Radar Tower]],
  noAutoFire         = false,
  objectName         = [[CORARAD]],
  onoffable          = true,
  radarDistance      = 3500,
  seismicSignature   = 0,
  selfDestructAs     = [[SMALL_BUILDING]],
  side               = [[CORE]],
  sightDistance      = 780,
  smoothAnim         = true,
  TEDClass           = [[SPECIAL]],
  turnRate           = 0,
  unitname           = [[corarad]],
  useBuildingGroundDecal = true,
  workerTime         = 0,
  yardMap            = [[oooo]],
  sounds = {
    activate           = [[radadvn2]],
    canceldestruct     = [[cancel2]],
    deactivate         = [[radadde2]],
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
      [[radadvn2]],
    },
  },
}


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 198,
    description        = [[Advanced Radar Tower Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 3,
    footprintZ         = 3,
    height             = 20,
    hitdensity         = 100,
    metal              = 339,
    object             = [[CORARAD_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 99,
    description        = [[Advanced Radar Tower Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 3,
    footprintZ         = 3,
    height             = 4,
    hitdensity         = 100,
    metal              = 136,
    object             = [[3X3C]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
