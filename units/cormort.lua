-- UNITDEF -- CORMORT --
--------------------------------------------------------------------------------

local unitName = "cormort"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.132,
  badTargetCategory  = [[VTOL]],
  bmcode             = 1,
  brakeRate          = 0.225,
  buildCostEnergy    = 2065,
  buildCostMetal     = 382,
  builder            = false,
  buildPic           = [[CORMORT.DDS]],
  buildTime          = 5139,
  canAttack          = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[KBOT MOBILE WEAPON ALL NOTSUB NOTSHIP NOTAIR]],
  corpse             = [[DEAD]],
  defaultmissiontype = [[Standby]],
  description        = [[Mobile Mortar Kbot]],
  energyMake         = 1,
  energyStorage      = 0,
  energyUse          = 1,
  explodeAs          = [[BIG_UNITEX]],
  firestandorders    = 1,
  footprintX         = 2,
  footprintZ         = 2,
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 640,
  maxDamage          = 850,
  maxSlope           = 14,
  maxVelocity        = 2.15,
  maxWaterDepth      = 12,
  metalStorage       = 0,
  mobilestandorders  = 1,
  movementClass      = [[KBOT2]],
  name               = [[Morty]],
  noAutoFire         = false,
  noChaseCategory    = [[VTOL]],
  objectName         = [[CORMORT]],
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[CORE]],
  sightDistance      = 300,
  smoothAnim         = true,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 2,
  TEDClass           = [[KBOT]],
  turnRate           = 1099,
  unitname           = [[cormort]],
  upright            = true,
  workerTime         = 0,
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
      [[kbcormov]],
    },
    select = {
      [[kbcorsel]],
    },
  },
  weapons = {
    [1]  = {
      badTargetCategory  = [[VTOL]],
      def                = [[CORE_MORT]],
      onlyTargetCategory = [[NOTAIR]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  CORE_MORT = {
    areaOfEffect       = 36,
    ballistic          = true,
    craterBoost        = 0,
    craterMult         = 0,
    explosionGenerator = [[custom:CORE_FIRE_SMALL]],
    gravityaffected    = [[true]],
    impulseBoost       = 0.123,
    impulseFactor      = 0.123,
    minbarrelangle     = -35,
    name               = [[PlasmaCannon]],
    noSelfDamage       = true,
    range              = 850,
    reloadtime         = 1.6,
    renderType         = 4,
    soundHit           = [[xplomed3]],
    soundStart         = [[cannon1]],
    startsmoke         = 1,
    turret             = true,
    weaponType         = [[Cannon]],
    weaponVelocity     = 450,
    damage = {
      default            = 105,
      gunships           = 14,
      hgunships          = 14,
      l1bombers          = 14,
      l1fighters         = 14,
      l1subs             = 5,
      l2bombers          = 14,
      l2fighters         = 14,
      l2subs             = 5,
      l3subs             = 5,
      vradar             = 14,
      vtol               = 14,
      vtrans             = 14,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 510,
    description        = [[Morty Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 20,
    hitdensity         = 100,
    metal              = 118,
    object             = [[CORMORT_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 255,
    description        = [[Morty Heap]],
    energy             = 0,
    footprintX         = 2,
    footprintZ         = 2,
    height             = 4,
    hitdensity         = 100,
    metal              = 47,
    object             = [[2X2A]],
    reclaimable        = true,
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
