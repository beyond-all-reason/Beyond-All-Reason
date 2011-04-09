-- UNITDEF -- ARMASY --
--------------------------------------------------------------------------------

local unitName = "armasy"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0,
  bmcode             = 0,
  brakeRate          = 0,
  buildCostEnergy    = 10096,
  buildCostMetal     = 3432,
  builder            = true,
  buildPic           = [[ARMASY.DDS]],
  buildTime          = 15972,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL NOTLAND PLANT NOTSUB NOWEAPON NOTSHIP NOTAIR]],
  collisionVolumeType= [[Box]],
  collisionVolumeScales = [[180 60 176]],
  collisionVolumeOffsets = [[0 -9 -2]],
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
  maxDamage          = 4512,
  maxVelocity        = 0,
  metalMake          = 1,
  metalStorage       = 200,
  minWaterDepth      = 30,
  mobilestandorders  = 1,
  name               = [[Advanced Shipyard]],
  noAutoFire         = false,
  objectName         = [[ARMASY]],
  radarDistance      = 50,
  seismicSignature   = 0,
  selfDestructAs     = [[LARGE_BUILDING]],
  side               = [[ARM]],
  sightDistance      = 299,
  smoothAnim         = false,
  standingfireorder  = 2,
  standingmoveorder  = 0,
  TEDClass           = [[PLANT]],
  turnRate           = 0,
  unitname           = [[armasy]],
  waterline          = 26,
  workerTime         = 200,
  yardMap            = [[wCCCCCCCCCCwCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCwCCCCCCCCCCw]],
  buildoptions = {
    [[armacsub]],
    [[armmls]],
    [[armrecl]],
    [[armsubk]],
    [[tawf009]],
    [[armaas]],
    [[armcrus]],
    [[armbats]],
    [[armmship]],
    [[aseadragon]],
    [[armcarry]],
    [[armsjam]],
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
    damage             = 2707,
    description        = [[Advanced Shipyard Wreckage]],
    energy             = 0,
    footprintX         = 12,
    footprintZ         = 12,
    height             = 4,
    hitdensity         = 100,
    metal              = 2232,
    object             = [[ARMASY_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
