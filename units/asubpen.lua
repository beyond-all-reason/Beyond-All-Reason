-- UNITDEF -- ASUBPEN --
--------------------------------------------------------------------------------

local unitName = "asubpen"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0,
  bmcode             = 0,
  brakeRate          = 0,
  buildCostEnergy    = 5144,
  buildCostMetal     = 860,
  builder            = true,
  buildingGroundDecalDecaySpeed = 30,
  buildingGroundDecalSizeX = 11,
  buildingGroundDecalSizeY = 11,
  buildingGroundDecalType = [[asubpen_aoplane.dds]],
  buildPic           = [[ASUBPEN.DDS]],
  buildTime          = 11112,
  canPatrol          = true,
  category           = [[ALL PLANT NOTSUB NOWEAPON NOTAIR]],
  collisionVolumeScales = [[118 40 119]],
  collisionVolumeOffsets = [[0 0 0]],
  collisionVolumeTest = 1,
  collisionVolumeType = [[Box]],
  corpse             = [[DEAD]],
  description        = [[Produces Amphibious/Underwater Units]],
  energyStorage      = 150,
  energyUse          = 0,
  explodeAs          = [[LARGE_BUILDINGEX]],
  firestandorders    = 1,
  footprintX         = 8,
  footprintZ         = 8,
  iconType           = [[building]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maxDamage          = 2400,
  maxSlope           = 10,
  maxVelocity        = 0,
  metalMake          = 1,
  metalStorage       = 150,
  minWaterDepth      = 25,
  mobilestandorders  = 1,
  name               = [[Amphibious Complex]],
  noAutoFire         = false,
  objectName         = [[ASUBPEN]],
  seismicSignature   = 0,
  selfDestructAs     = [[LARGE_BUILDING]],
  side               = [[ARM]],
  sightDistance      = 234,
  smoothAnim         = false,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  TEDClass           = [[PLANT]],
  turnRate           = 0,
  unitname           = [[asubpen]],
  useBuildingGroundDecal = true,
  workerTime         = 150,
  yardMap            = [[oooooooooCCCCCCooCCCCCCooCCCCCCooCCCCCCooCCCCCCooCCCCCCooCCCCCCo]],
  buildoptions = {
    [[armbeaver]],
    [[armpincer]],
    [[armcroc]],
    [[armjeth]],
    [[armaak]],
    [[armdecom]],
    [[armsub]],
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
    damage             = 1440,
    description        = [[Amphibious Complex Wreckage]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 7,
    footprintZ         = 7,
    height             = 5,
    hitdensity         = 100,
    metal              = 559,
    object             = [[ASUBPEN_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
