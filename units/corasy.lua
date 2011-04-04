-- UNITDEF -- CORASY --
--------------------------------------------------------------------------------

local unitName = "corasy"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0,
  bmcode             = 0,
  brakeRate          = 0,
  buildCostEnergy    = 10763,
  buildCostMetal     = 3345,
  builder            = true,
  buildPic           = [[CORASY.DDS]],
  buildTime          = 15696,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL PLANT NOTLAND NOWEAPON NOTSUB NOTSHIP NOTAIR]],
  collisionVolumeType= [[Box]],
  collisionVolumeScales= [[192 61 180]],
  collisionVolumeOffsets= [[0 -13 -3]],
  collisionVolumeTest = 1,
  corpse             = [[DEAD]],
  description        = [[Produces Level 2 Ships]],
  energyStorage      = 200,
  energyUse          = 0,
  explodeAs          = [[LARGE_BUILDINGEX]],
  firestandorders    = 1,
  footprintX         = 12,
  footprintZ         = 12,
  iconType           = [[building]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maxDamage          = 4416,
  maxVelocity        = 0,
  metalMake          = 1,
  metalStorage       = 200,
  minWaterDepth      = 30,
  mobilestandorders  = 1,
  name               = [[Advanced Shipyard]],
  noAutoFire         = false,
  objectName         = [[CORASY]],
  radarDistance      = 50,
  seismicSignature   = 0,
  selfDestructAs     = [[LARGE_BUILDING]],
  side               = [[CORE]],
  sightDistance      = 301.6,
  smoothAnim         = true,
  standingfireorder  = 2,
  standingmoveorder  = 0,
  TEDClass           = [[PLANT]],
  turnRate           = 0,
  unitname           = [[corasy]],
  waterline          = 32,
  workerTime         = 200,
  yardMap            = [[wCCCCCCCCCCwCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCwCCCCCCCCCCw]],
  buildoptions = {
    [[coracsub]],
    [[cormls]],
    [[correcl]],
    [[corshark]],
    [[corssub]],
    [[corarch]],
    [[corcrus]],
    [[corbats]],
    [[cormship]],
    [[corblackhy]],
    [[corcarry]],
    [[corsjam]],
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
      [[pshpactv]],
    },
  },
}


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = false,
    category           = [[corpses]],
    damage             = 2650,
    description        = [[Advanced Shipyard Wreckage]],
    energy             = 0,
    footprintX         = 12,
    footprintZ         = 12,
    height             = 4,
    hitdensity         = 100,
    metal              = 2174,
    object             = [[CORASY_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
