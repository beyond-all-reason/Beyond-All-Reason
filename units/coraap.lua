-- UNITDEF -- CORAAP --
--------------------------------------------------------------------------------

local unitName = "coraap"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0,
  bmcode             = 0,
  brakeRate          = 0,
  buildCostEnergy    = 26571,
  buildCostMetal     = 2979,
  builder            = true,
  buildingGroundDecalDecaySpeed = 30,
  buildingGroundDecalSizeX = 9,
  buildingGroundDecalSizeY = 7,
  buildingGroundDecalType = [[coraap_aoplane.dds]],
  buildPic           = [[CORAAP.DDS]],
  buildTime          = 20678,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL PLANT NOTLAND NOWEAPON NOTSUB NOTSHIP NOTAIR]],
  collisionVolumeType = [[Box]],
  collisionVolumeScales = [[104 32 52]],
  collisionVolumeOffsets = [[0 -12 -22]],
  collisionVolumeTest = 1,
  corpse             = [[DEAD]],
  description        = [[Produces Level 2 Aircraft]],
  energyStorage      = 200,
  energyUse          = 0,
  explodeAs          = [[LARGE_BUILDINGEX]],
  firestandorders    = 1,
  footprintX         = 8,
  footprintZ         = 6,
  iconType           = [[building]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maxDamage          = 3520,
  maxSlope           = 15,
  maxVelocity        = 0,
  maxWaterDepth      = 0,
  metalStorage       = 200,
  mobilestandorders  = 1,
  name               = [[Advanced Aircraft Plant]],
  noAutoFire         = false,
  objectName         = [[CORAAP]],
  seismicSignature   = 0,
  selfDestructAs     = [[LARGE_BUILDING]],
  side               = [[CORE]],
  sightDistance      = 305.5,
  smoothAnim         = true,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  TEDClass           = [[PLANT]],
  turnRate           = 0,
  unitname           = [[coraap]],
  useBuildingGroundDecal = true,
  workerTime         = 200,
  yardMap            = [[oooooooooooooooooooooooooooooooooooooooooooooooo]],
  buildoptions = {
    [[coraca]],
    [[corape]],
    [[corhurc]],
    [[cortitan]],
    [[corvamp]],
    [[corawac]],
    [[armsl]],
    [[corcrw]],
  },
  sfxtypes = {
    explosiongenerators = {
      [[custom:WhiteLight]],
    },
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
      [[pairactv]],
    },
  },
}


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 2112,
    description        = [[Advanced Aircraft Plant Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 7,
    footprintZ         = 6,
    height             = 20,
    hitdensity         = 100,
    metal              = 1936,
    object             = [[CORAAP_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 1056,
    description        = [[Advanced Aircraft Plant Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 6,
    footprintZ         = 6,
    height             = 4,
    hitdensity         = 100,
    metal              = 968,
    object             = [[6X6A]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
