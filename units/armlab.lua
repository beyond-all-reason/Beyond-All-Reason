-- UNITDEF -- ARMLAB --
--------------------------------------------------------------------------------

local unitName = "armlab"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0,
  bmcode             = 0,
  brakeRate          = 0,
  buildAngle         = 1024,
  buildCostEnergy    = 1130,
  buildCostMetal     = 605,
  builder            = true,
  buildingGroundDecalDecaySpeed = 30,
  buildingGroundDecalSizeX = 7,
  buildingGroundDecalSizeY = 7,
  buildingGroundDecalType = [[armlab_aoplane.dds]],
  buildPic           = [[ARMLAB.DDS]],
  buildTime          = 6760,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL PLANT NOTLAND NOTSUB NOWEAPON NOTSHIP NOTAIR]],
  collisionVolumeType = [[Box]],
  collisionVolumeScales = [[95 22 95]],
  collisionVolumeOffsets= [[0 -1 0]],
  collisionVolumeTest = 1,
  corpse             = [[DEAD]],
  description        = [[Produces Level 1 Kbots]],
  energyStorage      = 100,
  energyUse          = 0,
  explodeAs          = [[LARGE_BUILDINGEX]],
  firestandorders    = 1,
  footprintX         = 6,
  footprintZ         = 6,
  iconType           = [[building]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maxDamage          = 2690,
  maxSlope           = 15,
  maxVelocity        = 0,
  maxWaterDepth      = 0,
  metalStorage       = 100,
  mobilestandorders  = 1,
  name               = [[Kbot Lab]],
  noAutoFire         = false,
  objectName         = [[ARMLAB]],
  radarDistance      = 50,
  seismicSignature   = 0,
  selfDestructAs     = [[LARGE_BUILDING]],
  side               = [[ARM]],
  sightDistance      = 289,
  smoothAnim         = true,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  TEDClass           = [[PLANT]],
  turnRate           = 0,
  unitname           = [[armlab]],
  useBuildingGroundDecal = true,
  workerTime         = 100,
  yardMap            = [[occccooccccooccccooccccooccccoocccco]],
  buildoptions = {
    [[armck]],
    [[armpw]],
    [[armrectr]],
    [[armrock]],
    [[armham]],
    [[armjeth]],
    [[armwar]],
    [[armflea]],
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
    damage             = 1614,
    description        = [[Kbot Lab Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 5,
    footprintZ         = 6,
    height             = 40,
    hitdensity         = 100,
    metal              = 458,
    object             = [[ARMLAB_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 807,
    description        = [[Kbot Lab Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 5,
    footprintZ         = 5,
    height             = 4,
    hitdensity         = 100,
    metal              = 183,
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
