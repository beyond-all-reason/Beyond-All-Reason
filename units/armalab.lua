-- UNITDEF -- ARMALAB --
--------------------------------------------------------------------------------

local unitName = "armalab"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0,
  bmcode             = 0,
  brakeRate          = 0,
  buildAngle         = 1024,
  buildCostEnergy    = 13761,
  buildCostMetal     = 2729,
  builder            = true,
  buildingGroundDecalDecaySpeed = 30,
  buildingGroundDecalSizeX = 7,
  buildingGroundDecalSizeY = 7,
  buildingGroundDecalType = [[armalab_aoplane.dds]],
  buildPic           = [[ARMALAB.DDS]],
  buildTime          = 16224,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL NOTLAND PLANT NOTSUB NOWEAPON NOTSHIP NOTAIR]],
  collisionVolumeType = [[Box]],
  collisionVolumeScales = [[75 32 91]],
  collisionVolumeTest = 1,
  corpse             = [[DEAD]],
  description        = [[Produces Level 2 Kbots]],
  energyStorage      = 200,
  energyUse          = 0,
  explodeAs          = [[LARGE_BUILDINGEX]],
  firestandorders    = 1,
  footprintX         = 6,
  footprintZ         = 6,
  iconType           = [[building]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maxDamage          = 3808,
  maxSlope           = 15,
  maxVelocity        = 0,
  maxWaterDepth      = 0,
  metalStorage       = 200,
  mobilestandorders  = 1,
  name               = [[Advanced Kbot Lab]],
  noAutoFire         = false,
  objectName         = [[ARMALAB]],
  radarDistance      = 50,
  seismicSignature   = 0,
  selfDestructAs     = [[LARGE_BUILDING]],
  side               = [[ARM]],
  sightDistance      = 286,
  smoothAnim         = true,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  TEDClass           = [[PLANT]],
  turnRate           = 0,
  unitname           = [[armalab]],
  useBuildingGroundDecal = true,
  workerTime         = 200,
  yardMap            = [[occccooccccooccccooccccooccccoocccco]],
  buildoptions = {
    [[armack]],
    [[armfark]],
    [[armfast]],
    [[armamph]],
    [[armzeus]],
    [[armmav]],
    [[armsptk]],
    [[armfido]],
    [[armsnipe]],
    [[armfboy]],
    [[armspid]],
    [[armaak]],
    [[armvader]],
    [[armdecom]],
    [[armscab]],
    [[armaser]],
    [[armspy]],
    [[armmark]],
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
      [[plabactv]],
    },
  },
}


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 2285,
    description        = [[Advanced Kbot Lab Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 5,
    footprintZ         = 6,
    height             = 20,
    hitdensity         = 100,
    metal              = 1773,
    object             = [[ARMALAB_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 1143,
    description        = [[Advanced Kbot Lab Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 5,
    footprintZ         = 5,
    height             = 4,
    hitdensity         = 100,
    metal              = 887,
    object             = [[5X5A]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
