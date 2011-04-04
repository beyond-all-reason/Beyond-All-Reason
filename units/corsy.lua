-- UNITDEF -- CORSY --
--------------------------------------------------------------------------------

local unitName = "corsy"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0,
  bmcode             = 0,
  brakeRate          = 0,
  buildCostEnergy    = 750,
  buildCostMetal     = 600,
  builder            = true,
  buildPic           = [[CORSY.DDS]],
  buildTime          = 6000,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL PLANT NOTSUB NOWEAPON NOTAIR]],
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
  objectName         = [[CORSY]],
  seismicSignature   = 0,
  selfDestructAs     = [[LARGE_BUILDING]],
  side               = [[CORE]],
  sightDistance      = 276.9,
  smoothAnim         = true,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  TEDClass           = [[PLANT]],
  turnRate           = 0,
  unitname           = [[corsy]],
  waterline          = 22,
  workerTime         = 100,
  yardMap            = [[wCCCCCCwCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCwCCCCCCw]],
  buildoptions = {
    [[corcs]],
    [[corsub]],
    [[corpt]],
    [[coresupp]],
    [[corroy]],
    [[cortship]],
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
    damage             = 1794,
    description        = [[Shipyard Wreckage]],
    energy             = 0,
    footprintX         = 7,
    footprintZ         = 7,
    height             = 4,
    hitdensity         = 100,
    metal              = 390,
    object             = [[CORSY_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
