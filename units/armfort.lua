-- UNITDEF -- ARMFORT --
--------------------------------------------------------------------------------

local unitName = "armfort"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0,
  bmcode             = 0,
  brakeRate          = 0,
  buildAngle         = 0,
  buildCostEnergy    = 675,
  buildCostMetal     = 27,
  builder            = false,
  buildingGroundDecalDecaySpeed = 30,
  buildingGroundDecalSizeX = 4,
  buildingGroundDecalSizeY = 4,
  buildingGroundDecalType = [[armfort_aoplane.dds]],
  buildPic           = [[ARMFORT.DDS]],
  buildTime          = 965,
  category           = [[ALL NOTLAND NOTSUB NOWEAPON NOTSHIP NOTAIR]],
  corpse             = [[FORTIFICATION]],
  description        = [[Perimeter Defense]],
  energyMake         = 0,
  energyStorage      = 0,
  energyUse          = 0,
  footprintX         = 2,
  footprintZ         = 2,
  idleAutoHeal       = 5,
  idleTime           = 1800,
  isFeature          = true,
  levelGround        = false,
  maxDamage          = 100,
  maxSlope           = 24,
  maxVelocity        = 0,
  maxWaterDepth      = 0,
  metalStorage       = 0,
  name               = [[Fortification Wall]],
  noAutoFire         = false,
  objectName         = [[ARMFORT]],
  seismicSignature   = 0,
  side               = [[ARM]],
  sightDistance      = 130,
  smoothAnim         = true,
  TEDClass           = [[FORT]],
  turnRate           = 0,
  unitname           = [[armfort]],
  useBuildingGroundDecal = true,
  workerTime         = 0,
  yardMap            = [[ffff]],
}


--------------------------------------------------------------------------------

local featureDefs = {
  FORTIFICATION = {
    autoreclaimable    = 0,
    blocking           = true,
    category           = [[dragonteeth]],
    damage             = 15000,
    description        = [[Fortification Wall]],
    featureDead        = [[RockTeethx]],
    featurereclamate   = [[smudge01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 55,
    hitdensity         = 100,
    metal              = 15,
    nodrawundergray    = true,
    object             = [[armfort]],
    reclaimable        = true,
    reclaimTime        = 800,
    seqnamereclamate   = [[tree1reclamate]],
    world              = [[allworld]],
  },
  RockTeethx = {
    animating          = 0,
    animtrans          = 0,
    blocking           = true,
    category           = [[rocks]],
    damage             = 5000,
    description        = [[Rubble]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 20,
    hitdensity         = 100,
    metal              = 7,
    object             = [[2X2A]],
    reclaimable        = true,
    shadtrans          = 1,
    world              = [[greenworld]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
