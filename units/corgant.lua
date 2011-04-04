-- UNITDEF -- CORGANT --
--------------------------------------------------------------------------------

local unitName = "corgant"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0,
  bmcode             = 0,
  brakeRate          = 0,
  buildCostEnergy    = 58524,
  buildCostMetal     = 7848,
  builder            = true,
  buildingGroundDecalDecaySpeed = 30,
  buildingGroundDecalSizeX = 10,
  buildingGroundDecalSizeY = 10,
  buildingGroundDecalType = [[corgant_aoplane.dds]],
  buildPic           = [[CORGANT.DDS]],
  buildTime          = 67321,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL PLANT NOTLAND NOWEAPON NOTSUB NOTSHIP NOTAIR]],
  collisionVolumeType = [[Box]],
  collisionVolumeScales = [[110 63 135]],
  collisionVolumeOffsets = [[0 0 0]],
  collisionVolumeTest = 1,
  corpse             = [[DEAD]],
  description        = [[Produces Level 3 Units]],
  energyStorage      = 1400,
  energyUse          = 0,
  explodeAs          = [[LARGE_BUILDINGEX]],
  firestandorders    = 1,
  footprintX         = 9,
  footprintZ         = 9,
  iconType           = [[building]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maxDamage          = 16000,
  maxSlope           = 18,
  maxVelocity        = 0,
  maxWaterDepth      = 0,
  metalStorage       = 800,
  mobilestandorders  = 1,
  name               = [[Experimental Gantry]],
  noAutoFire         = false,
  objectName         = [[CORGANT]],
  radarDistance      = 50,
  seismicSignature   = 0,
  selfDestructAs     = [[LARGE_BUILDING]],
  side               = [[CORE]],
  sightDistance      = 273,
  smoothAnim         = true,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  TEDClass           = [[PLANT]],
  turnRate           = 0,
  unitname           = [[corgant]],
  useBuildingGroundDecal = true,
  workerTime         = 600,
  yardMap            = [[oooooooooooooooooooocccccoooocccccoooocccccoooocccccoooocccccoooocccccoooocccccoo]],
  buildoptions = {
    [[corkrog]],
    [[corkarg]],
    [[gorg]],
    [[shiva]],
    [[armraven]],
  },
  sfxtypes = {
    explosiongenerators = {
      [[custom:GantWhiteLight]],
      [[custom:YellowLight]],
      [[custom:WhiteLight]],
    },
  },
  sounds = {
    activate           = [[gantok2]],
    build              = [[gantok2]],
    canceldestruct     = [[cancel2]],
    deactivate         = [[gantok2]],
    repair             = [[lathelrg]],
    underattack        = [[warning1]],
    unitcomplete       = [[gantok1]],
    working            = [[build]],
    count = {
      [[count6]],
      [[count5]],
      [[count4]],
      [[count3]],
      [[count2]],
      [[count1]],
    },
    select = {
      [[gantsel1]],
    },
  },
}


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 9600,
    description        = [[Experimental Gantry Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 9,
    footprintZ         = 9,
    height             = 20,
    hitdensity         = 100,
    metal              = 5101,
    object             = [[CORGANT_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 4800,
    description        = [[Experimental Gantry Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 9,
    footprintZ         = 9,
    height             = 4,
    hitdensity         = 100,
    metal              = 2040,
    object             = [[7X7B]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
