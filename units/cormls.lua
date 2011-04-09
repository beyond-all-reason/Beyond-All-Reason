-- UNITDEF -- CORMLS --
--------------------------------------------------------------------------------

local unitName = "cormls"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.046,
  bmcode             = 1,
  brakeRate          = 0.06,
  buildCostEnergy    = 3902,
  buildCostMetal     = 241,
  buildDistance      = 200,
  builder            = true,
  buildPic           = [[CORMLS.DDS]],
  buildTime          = 5352,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL NOWEAPON MINELAYER SHIP NOTSUB NOTAIR]],
  corpse             = [[DEAD]],
  defaultmissiontype = [[Standby]],
  description        = [[Naval Engineer]],
  energyMake         = 0.5,
  energyStorage      = 0,
  energyUse          = 0.5,
  explodeAs          = [[SMALL_UNITEX]],
  floater            = true,
  footprintX         = 4,
  footprintZ         = 4,
  iconType           = [[sea]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 640,
  maxDamage          = 1438,
  maxVelocity        = 2.1,
  metalStorage       = 0,
  minWaterDepth      = 15,
  mobilestandorders  = 1,
  movementClass      = [[BOAT4]],
  name               = [[Pathfinder]],
  noAutoFire         = false,
  objectName         = [[CORMLS]],
  seismicSignature   = 0,
  selfDestructAs     = [[SMALL_UNIT]],
  side               = [[core]],
  sightDistance      = 260,
  smoothAnim         = false,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[SHIP]],
  terraformSpeed     = 1200,
  turnRate           = 377,
  unitname           = [[cormls]],
  waterline          = 3,
  workerTime         = 400,
  buildoptions = {
    [[cortide]],
    [[coruwmex]],
    [[corsy]],
    [[csubpen]],
    [[corfhp]],
    [[coreyes]],
    [[corfrad]],
    [[corsonar]],
    [[corfmine3]],
    [[corfhlt]],
    [[cortl]],
    [[corfrt]],
    [[corcs]],
    [[corpt]],
    [[coresupp]],
    [[corroy]],
    [[corsub]],
    [[cormuskrat]],
    [[corseal]],
    [[coramph]],
  },
  sounds = {
    build              = [[nanlath2]],
    canceldestruct     = [[cancel2]],
    repair             = [[repair2]],
    underattack        = [[warning1]],
    working            = [[reclaim1]],
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
      [[shcormov]],
    },
    select = {
      [[shcorsel]],
    },
  },
}


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 863,
    description        = [[Pathfinder Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 4,
    footprintZ         = 4,
    height             = 20,
    hitdensity         = 100,
    metal              = 157,
    object             = [[CORMLS_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 2016,
    description        = [[Pathfinder Heap]],
    energy             = 0,
    footprintX         = 2,
    footprintZ         = 2,
    height             = 4,
    hitdensity         = 100,
    metal              = 66,
    object             = [[4X4A]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
