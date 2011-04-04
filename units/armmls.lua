-- UNITDEF -- ARMMLS --
--------------------------------------------------------------------------------

local unitName = "armmls"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.05,
  bmcode             = 1,
  brakeRate          = 0.07,
  buildCostEnergy    = 3725,
  buildCostMetal     = 213,
  buildDistance      = 200,
  builder            = true,
  buildPic           = [[ARMMLS.DDS]],
  buildTime          = 5247,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL NOTSUB MINELAYER SHIP NOWEAPON NOTAIR]],
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
  maxDamage          = 1314,
  maxVelocity        = 2.4,
  metalStorage       = 0,
  minWaterDepth      = 15,
  mobilestandorders  = 1,
  movementClass      = [[BOAT4]],
  name               = [[Valiant]],
  noAutoFire         = false,
  objectName         = [[ARMMLS]],
  seismicSignature   = 0,
  selfDestructAs     = [[SMALL_UNIT]],
  side               = [[arm]],
  sightDistance      = 260,
  smoothAnim         = true,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[SHIP]],
  terraformSpeed     = 1200,
  turnRate           = 388,
  unitname           = [[armmls]],
  workerTime         = 400,
  buildoptions = {
    [[armtide]],
    [[armuwmex]],
    [[armsy]],
    [[asubpen]],
    [[armfhp]],
    [[armeyes]],
    [[armfrad]],
    [[armsonar]],
    [[armfmine3]],
    [[armfhlt]],
    [[armtl]],
    [[armfrt]],
    [[armcs]],
    [[armpt]],
    [[decade]],
    [[armroy]],
    [[armsub]],
    [[armbeaver]],
    [[armcroc]],
    [[armamph]],
  },
  sounds = {
    build              = [[nanlath1]],
    canceldestruct     = [[cancel2]],
    repair             = [[repair1]],
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
      [[sharmmov]],
    },
    select = {
      [[sharmsel]],
    },
  },
}


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 788,
    description        = [[Valiant Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 4,
    footprintZ         = 4,
    height             = 20,
    hitdensity         = 100,
    metal              = 138,
    object             = [[ARMMLS_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 2016,
    description        = [[Valiant Heap]],
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
