-- UNITDEF -- CONSUL --
--------------------------------------------------------------------------------

local unitName = "consul"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.0825,
  bmcode             = 1,
  brakeRate          = 0.1375,
  buildCostEnergy    = 4028,
  buildCostMetal     = 236,
  buildDistance      = 128,
  builder            = true,
  buildPic           = [[CONSUL.DDS]],
  buildTime          = 6793,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canreclamate       = 1,
  canstop            = 1,
  category           = [[ALL TANK MOBILE NOTSUB NOWEAPON NOTSHIP NOTAIR]],
  corpse             = [[DEAD]],
  defaultmissiontype = [[Standby]],
  description        = [[Combat Engineer]],
  energyMake         = 15,
  energyStorage      = 100,
  energyUse          = 15,
  explodeAs          = [[BIG_UNITEX]],
  footprintX         = 3,
  footprintZ         = 3,
  idleAutoHeal       = 5,
  idleTime           = 1800,
  leaveTracks        = true,
  maneuverleashlength = 640,
  maxDamage          = 975,
  maxSlope           = 18,
  maxVelocity        = 2.783,
  maxWaterDepth      = 18,
  metalMake          = 0.15,
  metalStorage       = 100,
  mobilestandorders  = 1,
  movementClass      = [[TANK3]],
  name               = [[Consul]],
  noAutoFire         = false,
  objectName         = [[CONSUL]],
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[arm]],
  sightDistance      = 500,
  smoothAnim         = false,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[CNSTR]],
  terraformSpeed     = 450,
  trackOffset        = 6,
  trackStrength      = 5,
  trackStretch       = 1,
  trackType          = [[StdTank]],
  trackWidth         = 31,
  turnRate           = 635,
  unitname           = [[consul]],
  workerTime         = 150,
  buildoptions = {
    [[armsolar]],
    [[armmex]],
    [[armvp]],
    [[armnanotc]],
    [[armeyes]],
    [[armveil]],
    [[armfort]],
    [[armarad]],
    [[armmine2]],
    [[tawf001]],
    [[armpb]],
    [[armamb]],
    [[packo]],
    [[armflak]],
    [[armdl]],
    [[armcv]],
    [[armpw]],
    [[armstump]],
    [[armjeth]],
    [[armlatnk]],
    [[armfboy]],
  },
  sounds = {
    canceldestruct     = [[cancel2]],
    underattack        = [[warning1]],
    cant = {
      [[cantdo4]],
    },
    count = {
      [[count6]],
      [[count5]],
      [[count4]],
      [[count3]],
      [[count2]],
      [[count1]],
    },
    ok = {
      [[tarmmove]],
    },
    select = {
      [[tarmsel]],
    },
  },
}


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 585,
    description        = [[Consul Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 3,
    footprintZ         = 3,
    height             = 20,
    hitdensity         = 100,
    metal              = 153,
    object             = [[CONSUL_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 293,
    description        = [[Consul Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 3,
    footprintZ         = 3,
    height             = 4,
    hitdensity         = 100,
    metal              = 61,
    object             = [[3X3A]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
