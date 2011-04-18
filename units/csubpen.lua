-- UNITDEF -- CSUBPEN --
--------------------------------------------------------------------------------

local unitName = "csubpen"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0,
  bmcode             = 0,
  brakeRate          = 0,
  buildCostEnergy    = 5285,
  buildCostMetal     = 917,
  builder            = true,
  buildingGroundDecalDecaySpeed = 30,
  buildingGroundDecalSizeX = 11,
  buildingGroundDecalSizeY = 11,
  buildingGroundDecalType = [[csubpen_aoplane.dds]],
  buildPic           = [[CSUBPEN.DDS]],
  buildTime          = 11402,
  canPatrol          = true,
  category           = [[ALL PLANT NOWEAPON NOTSUB NOTAIR]],
  collisionVolumeScales = [[115 36 112]],
  collisionVolumeOffsets = [[0 0 -2]],
  collisionVolumeTest = 1,
  collisionVolumeType = [[Box]],
  corpse             = [[DEAD]],
  description        = [[Produces Amphibious/Underwater Units]],
  energyStorage      = 160,
  energyUse          = 0,
  explodeAs          = [[LARGE_BUILDINGEX]],
  firestandorders    = 1,
  footprintX         = 8,
  footprintZ         = 8,
  iconType           = [[building]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maxDamage          = 2500,
  maxSlope           = 10,
  maxVelocity        = 0,
  metalMake          = 1,
  metalStorage       = 160,
  minWaterDepth      = 25,
  mobilestandorders  = 1,
  name               = [[Amphibious Complex]],
  noAutoFire         = false,
  objectName         = [[CSUBPEN]],
  seismicSignature   = 0,
  selfDestructAs     = [[LARGE_BUILDING]],
  side               = [[CORE]],
  sightDistance      = 240,
  smoothAnim         = false,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  TEDClass           = [[PLANT]],
  turnRate           = 0,
  unitname           = [[csubpen]],
  useBuildingGroundDecal = true,
  workerTime         = 150,
  yardMap            = [[oooooooooCCCCCCooCCCCCCooCCCCCCooCCCCCCooCCCCCCooCCCCCCooCCCCCCo]],
  buildoptions = {
    [[cormuskrat]],
    [[corgarp]],
    [[corseal]],
    [[corparrow]],
    [[corcrash]],
    [[coraak]],
    [[cordecom]],
    [[intruder]],
    [[corsub]],
  },
  sounds = {
    canceldestruct     = [[cancel2]],
    underattack        = [[warning1]],
    unitcomplete       = [[untdone]],
    count = {
      [[count6]],
      [[count5]],
      [[count4]],
      [[count3]],
      [[count2]],
      [[count1]],
    },
    select = {
      [[pvehactv]],
    },
  },
}


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = false,
    category           = [[corpses]],
    damage             = 1500,
    description        = [[Amphibious Complex Wreckage]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 7,
    footprintZ         = 7,
    height             = 5,
    hitdensity         = 100,
    metal              = 596,
    object             = [[CSUBPEN_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
