-- UNITDEF -- CORASON --
--------------------------------------------------------------------------------

local unitName = "corason"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0,
  activateWhenBuilt  = true,
  bmcode             = 0,
  brakeRate          = 0,
  buildAngle         = 8192,
  buildCostEnergy    = 2257,
  buildCostMetal     = 152,
  builder            = false,
  buildingGroundDecalDecaySpeed = 30,
  buildingGroundDecalSizeX = 5,
  buildingGroundDecalSizeY = 5,
  buildingGroundDecalType = [[corason_aoplane.dds]],
  buildPic           = [[CORASON.DDS]],
  buildTime          = 6096,
  canAttack          = false,
  category           = [[ALL NOTLAND NOTSUB NOWEAPON NOTSHIP NOTAIR]],
  corpse             = [[DEAD]],
  description        = [[Extended Sonar]],
  energyMake         = 18,
  energyStorage      = 0,
  energyUse          = 18,
  explodeAs          = [[SMALL_BUILDINGEX]],
  footprintX         = 3,
  footprintZ         = 3,
  iconType           = [[building]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maxangledif1       = 1,
  maxDamage          = 2140,
  maxSlope           = 10,
  maxVelocity        = 0,
  metalStorage       = 0,
  minWaterDepth      = 24,
  name               = [[Advanced Sonar Station]],
  noAutoFire         = false,
  objectName         = [[CORASON]],
  onoffable          = true,
  seismicSignature   = 0,
  selfDestructAs     = [[SMALL_BUILDING]],
  side               = [[CORE]],
  sightDistance      = 210,
  smoothAnim         = true,
  sonarDistance      = 2400,
  TEDClass           = [[WATER]],
  turnRate           = 0,
  unitname           = [[corason]],
  useBuildingGroundDecal = true,
  workerTime         = 0,
  yardMap            = [[ooooooooo]],
  sounds = {
    activate           = [[radar1]],
    canceldestruct     = [[cancel2]],
    deactivate         = [[sonarde2]],
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
      [[sonar2]],
    },
  },
}


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = false,
    category           = [[corpses]],
    damage             = 1284,
    description        = [[Advanced Sonar Station Wreckage]],
    energy             = 0,
    footprintX         = 3,
    footprintZ         = 3,
    height             = 20,
    hitdensity         = 100,
    metal              = 99,
    object             = [[CORASON_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
