-- UNITDEF -- ARMASON --
--------------------------------------------------------------------------------

local unitName = "armason"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0,
  activateWhenBuilt  = true,
  bmcode             = 0,
  brakeRate          = 0,
  buildAngle         = 8192,
  buildCostEnergy    = 2469,
  buildCostMetal     = 163,
  builder            = false,
  buildingGroundDecalDecaySpeed = 30,
  buildingGroundDecalSizeX = 6,
  buildingGroundDecalSizeY = 6,
  buildingGroundDecalType = [[armason_aoplane.dds]],
  buildPic           = [[ARMASON.DDS]],
  buildTime          = 6152,
  canAttack          = false,
  category           = [[ALL NOTLAND NOTSUB NOWEAPON NOTSHIP NOTAIR]],
  corpse             = [[DEAD]],
  damageModifier     = 0.46,
  description        = [[Extended Sonar]],
  energyMake         = 22,
  energyStorage      = 0,
  energyUse          = 22,
  explodeAs          = [[SMALL_BUILDINGEX]],
  footprintX         = 4,
  footprintZ         = 4,
  iconType           = [[building]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maxangledif1       = 1,
  maxDamage          = 2120,
  maxSlope           = 10,
  maxVelocity        = 0,
  metalStorage       = 0,
  minWaterDepth      = 24,
  name               = [[Advanced Sonar Station]],
  noAutoFire         = false,
  objectName         = [[ARMASON]],
  onoffable          = true,
  seismicSignature   = 0,
  selfDestructAs     = [[SMALL_BUILDING]],
  side               = [[ARM]],
  sightDistance      = 215,
  smoothAnim         = true,
  sonarDistance      = 2400,
  TEDClass           = [[WATER]],
  turnRate           = 0,
  unitname           = [[armason]],
  useBuildingGroundDecal = true,
  workerTime         = 0,
  yardMap            = [[yooy oooo oooo yooy]],
  sounds = {
    activate           = [[sonar1]],
    canceldestruct     = [[cancel2]],
    deactivate         = [[sonarde1]],
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
      [[sonar1]],
    },
  },
}


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = false,
    category           = [[corpses]],
    damage             = 1272,
    description        = [[Advanced Sonar Station Wreckage]],
    energy             = 0,
    footprintX         = 4,
    footprintZ         = 4,
    height             = 40,
    hitdensity         = 100,
    metal              = 106,
    object             = [[ARMASON_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
