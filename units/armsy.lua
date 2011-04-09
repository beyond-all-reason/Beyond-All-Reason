-- UNITDEF -- ARMSY --
--------------------------------------------------------------------------------

local unitName = "armsy"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0,
  bmcode             = 0,
  brakeRate          = 0,
  buildCostEnergy    = 775,
  buildCostMetal     = 615,
  builder            = true,
  buildPic           = [[ARMSY.DDS]],
  buildTime          = 6050,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL PLANT NOTLAND NOTSUB NOWEAPON NOTSHIP NOTAIR]],
  collisionVolumeType = [[Box]],
  collisionVolumeScales = [[116 60 116]],
  collisionVolumeOffsets = [[-2 0 -3]],
  collisionVolumeTest = 1,
  corpse             = [[DEAD]],
  description        = [[Produces Level 1 Ships]],
  energyStorage      = 100,
  energyUse          = 0,
  explodeAs          = [[LARGE_BUILDINGEX]],
  firestandorders    = 1,
  footprintX         = 8,
  footprintZ         = 8,
  iconType           = [[building]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maxDamage          = 2990,
  maxVelocity        = 0,
  metalMake          = 0.5,
  metalStorage       = 100,
  minWaterDepth      = 30,
  mobilestandorders  = 1,
  name               = [[Shipyard]],
  noAutoFire         = false,
  objectName         = [[ARMSY]],
  radarDistance      = 50,
  seismicSignature   = 0,
  selfDestructAs     = [[LARGE_BUILDING]],
  side               = [[ARM]],
  sightDistance      = 275.6,
  smoothAnim         = false,
  standingfireorder  = 2,
  standingmoveorder  = 0,
  TEDClass           = [[PLANT]],
  turnRate           = 0,
  unitname           = [[armsy]],
  waterline          = 26,
  workerTime         = 100,
  yardMap            = [[wCCCCCCwCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCwCCCCCCw]],
  buildoptions = {
    [[armcs]],
    [[armsub]],
    [[armpt]],
    [[decade]],
    [[armroy]],
    [[armtship]],
  },
  sfxtypes = {
    explosiongenerators = {
      [[custom:YellowLight]],
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
    damage             = 1794,
    description        = [[Shipyard Wreckage]],
    energy             = 0,
    footprintX         = 7,
    footprintZ         = 7,
    height             = 4,
    hitdensity         = 100,
    metal              = 400,
    object             = [[ARMSY_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
