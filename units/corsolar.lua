-- UNITDEF -- CORSOLAR --
--------------------------------------------------------------------------------

local unitName = "corsolar"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0,
  activateWhenBuilt  = true,
  bmcode             = 0,
  brakeRate          = 0,
  buildAngle         = 32768,
  buildCostEnergy    = 0,
  buildCostMetal     = 141,
  builder            = false,
  buildingGroundDecalDecaySpeed = 30,
  buildingGroundDecalSizeX = 8,
  buildingGroundDecalSizeY = 8,
  buildingGroundDecalType = [[corsolar_aoplane.dds]],
  buildPic           = [[CORSOLAR.DDS]],
  buildTime          = 2766,
  category           = [[ALL NOTLAND NOTSUB NOWEAPON NOTSHIP NOTAIR]],
  collisionvolumeoffsets = [[0.0 -35.0 0.0]]; 
  collisionvolumescales = [[77.0 78.0 77.0]];
  collisionvolumetype = [[Ell]];
  corpse             = [[DEAD]],
  damageModifier     = 0.5,
  description        = [[Produces Energy]],
  energyMake         = 0,
  energyStorage      = 50,
  energyUse          = -20,
  explodeAs          = [[SMALL_BUILDINGEX]],
  footprintX         = 5,
  footprintZ         = 5,
  iconType           = [[building]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maxDamage          = 320,
  maxSlope           = 10,
  maxVelocity        = 0,
  maxWaterDepth      = 0,
  metalStorage       = 0,
  name               = [[Solar Collector]],
  noAutoFire         = false,
  objectName         = [[CORSOLAR]],
  onoffable          = true,
  seismicSignature   = 0,
  selfDestructAs     = [[SMALL_BUILDING]],
  side               = [[CORE]],
  sightDistance      = 273,
  smoothAnim         = false,
  TEDClass           = [[ENERGY]],
  turnRate           = 0,
  unitname           = [[corsolar]],
  useBuildingGroundDecal = true,
  workerTime         = 0,
  yardMap            = [[ooooo ooooo ooooo ooooo ooooo]],
  sounds = {
    activate           = [[solar2]],
    canceldestruct     = [[cancel2]],
    deactivate         = [[solar2]],
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
      [[solar2]],
    },
  },
}


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 192,
    description        = [[Solar Collector Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 4,
    footprintZ         = 4,
    height             = 20,
    hitdensity         = 100,
    metal              = 72,
    object             = [[CORSOLAR_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 96,
    description        = [[Solar Collector Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 5,
    footprintZ         = 5,
    height             = 4,
    hitdensity         = 100,
    metal              = 29,
    object             = [[5X5C]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
