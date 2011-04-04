-- UNITDEF -- CORUWMME --
--------------------------------------------------------------------------------

local unitName = "coruwmme"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0,
  activateWhenBuilt  = true,
  bmcode             = 0,
  brakeRate          = 0,
  buildAngle         = 32768,
  buildCostEnergy    = 10076,
  buildCostMetal     = 846,
  builder            = false,
  buildingGroundDecalDecaySpeed = 30,
  buildingGroundDecalSizeX = 8,
  buildingGroundDecalSizeY = 8,
  buildingGroundDecalType = [[coruwmme_aoplane.dds]],
  buildPic           = [[CORUWMME.DDS]],
  buildTime          = 34783,
  category           = [[ALL NOTLAND NOTSUB NOWEAPON NOTSHIP NOTAIR]],
  corpse             = [[DEAD]],
  damageModifier     = 0.35,
  description        = [[Advanced Metal Extractor / Storage]],
  energyStorage      = 0,
  energyUse          = 25,
  explodeAs          = [[SMALL_BUILDINGEX]],
  extractsMetal      = 0.004,
  footprintX         = 5,
  footprintZ         = 5,
  iconType           = [[building]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maxDamage          = 2072,
  maxSlope           = 24,
  maxVelocity        = 0,
  metalStorage       = 1000,
  minWaterDepth      = 15,
  name               = [[Underwater Moho Mine]],
  noAutoFire         = false,
  objectName         = [[CORUWMME]],
  onoffable          = true,
  seismicSignature   = 0,
  selfDestructAs     = [[SMALL_BUILDING]],
  side               = [[CORE]],
  sightDistance      = 169,
  smoothAnim         = true,
  TEDClass           = [[METAL]],
  turnRate           = 0,
  unitname           = [[coruwmme]],
  useBuildingGroundDecal = true,
  workerTime         = 0,
  yardMap            = [[ooooooooooooooooooooooooo]],
  sounds = {
    activate           = [[waterex2]],
    canceldestruct     = [[cancel2]],
    deactivate         = [[waterex2]],
    underattack        = [[warning1]],
    working            = [[waterex2]],
    count = {
      [[count6]],
      [[count5]],
      [[count4]],
      [[count3]],
      [[count2]],
      [[count1]],
    },
    select = {
      [[waterex2]],
    },
  },
}


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 1243,
    description        = [[Underwater Moho Mine Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 5,
    footprintZ         = 5,
    height             = 150,
    hitdensity         = 100,
    metal              = 550,
    object             = [[CORUWMME_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 622,
    description        = [[Underwater Moho Mine Heap]],
    energy             = 0,
    footprintX         = 5,
    footprintZ         = 5,
    height             = 5,
    hitdensity         = 100,
    metal              = 220,
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
