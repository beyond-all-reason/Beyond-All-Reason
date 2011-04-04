-- UNITDEF -- ARMSONAR --
--------------------------------------------------------------------------------

local unitName = "armsonar"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0,
  activateWhenBuilt  = true,
  bmcode             = 0,
  brakeRate          = 0,
  buildAngle         = 8192,
  buildCostEnergy    = 403,
  buildCostMetal     = 20,
  builder            = false,
  buildingGroundDecalDecaySpeed = 30,
  buildingGroundDecalSizeX = 4,
  buildingGroundDecalSizeY = 4,
  buildingGroundDecalType = [[armsonar_aoplane.dds]],
  buildPic           = [[ARMSONAR.DDS]],
  buildTime          = 912,
  canAttack          = false,
  category           = [[ALL NOTLAND NOTSUB NOWEAPON NOTSHIP NOTAIR]],
  corpse             = [[DEAD]],
  description        = [[Locates Water Units]],
  energyMake         = 1,
  energyStorage      = 0,
  energyUse          = 1,
  explodeAs          = [[SMALL_BUILDINGEX]],
  footprintX         = 2,
  footprintZ         = 2,
  iconType           = [[building]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maxangledif1       = 1,
  maxDamage          = 50,
  maxSlope           = 10,
  maxVelocity        = 0,
  metalStorage       = 0,
  minWaterDepth      = 10,
  name               = [[Sonar Station]],
  noAutoFire         = false,
  objectName         = [[ARMSONAR]],
  onoffable          = true,
  seismicSignature   = 0,
  selfDestructAs     = [[SMALL_BUILDING]],
  side               = [[ARM]],
  sightDistance      = 515,
  smoothAnim         = true,
  sonarDistance      = 1200,
  TEDClass           = [[WATER]],
  turnRate           = 0,
  unitname           = [[armsonar]],
  useBuildingGroundDecal = true,
  workerTime         = 0,
  yardMap            = [[oooo]],
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
    damage             = 30,
    description        = [[Sonar Station Wreckage]],
    energy             = 0,
    footprintX         = 2,
    footprintZ         = 2,
    height             = 4,
    hitdensity         = 100,
    metal              = 13,
    object             = [[ARMSONAR_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
