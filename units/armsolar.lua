-- UNITDEF -- ARMSOLAR --
--------------------------------------------------------------------------------

local unitName = "armsolar"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0,
  activateWhenBuilt  = true,
  bmcode             = 0,
  brakeRate          = 0,
  buildAngle         = 4096,
  buildCostEnergy    = 0,
  buildCostMetal     = 145,
  builder            = false,
  buildingGroundDecalDecaySpeed = 30,
  buildingGroundDecalSizeX = 8,
  buildingGroundDecalSizeY = 8,
  buildingGroundDecalType = [[armsolar_aoplane.dds]],
  buildPic           = [[ARMSOLAR.DDS]],
  buildTime          = 2845,
  category           = [[ALL NOTLAND NOTSUB NOWEAPON NOTSHIP NOTAIR]],
  collisionSphereScale = 0.5,
  collisionvolumeoffsets = [[0.0 -18.0 1.0]]; 
  collisionvolumescales = [[50.0 76.0 50.0]];
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
  maxDamage          = 306,
  maxSlope           = 10,
  maxVelocity        = 0,
  maxWaterDepth      = 0,
  metalStorage       = 0,
  name               = [[Solar Collector]],
  noAutoFire         = false,
  objectName         = [[ARMSOLAR]],
  onoffable          = true,
  seismicSignature   = 0,
  selfDestructAs     = [[SMALL_BUILDING]],
  side               = [[ARM]],
  sightDistance      = 273,
  smoothAnim         = false,
  TEDClass           = [[ENERGY]],
  turnRate           = 0,
  unitname           = [[armsolar]],
  useBuildingGroundDecal = true,
  workerTime         = 0,
  yardMap            = [[yycyy yoooy coooc yoooy yycyy]],
  sounds = {
    activate           = [[solar1]],
    canceldestruct     = [[cancel2]],
    deactivate         = [[solar1]],
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
      [[solar1]],
    },
  },
}


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 184,
    description        = [[Solar Collector Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 5,
    footprintZ         = 5,
    height             = 20,
    hitdensity         = 100,
    metal              = 75,
    object             = [[ARMSOLAR_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 92,
    description        = [[Solar Collector Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 5,
    footprintZ         = 5,
    height             = 4,
    hitdensity         = 100,
    metal              = 30,
    object             = [[5X5B]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
