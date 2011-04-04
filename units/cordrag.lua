-- UNITDEF -- CORDRAG --
--------------------------------------------------------------------------------

local unitName = "cordrag"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0,
  bmcode             = 0,
  brakeRate          = 0,
  buildAngle         = 8192,
  buildCostEnergy    = 150,
  buildCostMetal     = 10,
  builder            = false,
  buildingGroundDecalDecaySpeed = 30,
  buildingGroundDecalSizeX = 4,
  buildingGroundDecalSizeY = 4,
  buildingGroundDecalType = [[cordrag_aoplane.dds]],
  buildPic           = [[CORDRAG.DDS]],
  buildTime          = 255,
  category           = [[ALL NOTLAND NOTSUB NOWEAPON NOTSHIP NOTAIR]],
  corpse             = [[DRAGONSTEETH_CORE]],
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
  maxSlope           = 64,
  maxVelocity        = 0,
  maxWaterDepth      = 0,
  metalStorage       = 0,
  name               = [[Dragon's Teeth]],
  noAutoFire         = false,
  objectName         = [[CORDRAG]],
  seismicSignature   = 0,
  side               = [[CORE]],
  sightDistance      = 130,
  smoothAnim         = true,
  TEDClass           = [[FORT]],
  turnRate           = 0,
  unitname           = [[cordrag]],
  useBuildingGroundDecal = true,
  workerTime         = 0,
  yardMap            = [[ffff]],
}


--------------------------------------------------------------------------------

local featureDefs = {
  DRAGONSTEETH_CORE = {
    autoreclaimable    = 0,
    blocking           = true,
    category           = [[dragonteeth]],
    damage             = 2500,
    description        = [[Dragon's Teeth]],
    featureDead        = [[RockTeeth]],
    featurereclamate   = [[smudge01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 20,
    hitdensity         = 100,
    metal              = 5,
    nodrawundergray    = true,
    object             = [[cordrag]],
    reclaimable        = true,
    seqnamereclamate   = [[tree1reclamate]],
    world              = [[allworld]],
  },
  RockTeeth = {
    animating          = 0,
    animtrans          = 0,
    blocking           = false,
    category           = [[rocks]],
    damage             = 500,
    description        = [[Rubble]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 20,
    hitdensity         = 100,
    metal              = 2,
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
