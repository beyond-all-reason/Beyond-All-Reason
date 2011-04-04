-- UNITDEF -- ARMFAST --
--------------------------------------------------------------------------------

local unitName = "armfast"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.36,
  badTargetCategory  = [[VTOL]],
  bmcode             = 1,
  brakeRate          = 0.375,
  buildCostEnergy    = 4382,
  buildCostMetal     = 177,
  builder            = false,
  buildPic           = [[ARMFAST.DDS]],
  buildTime          = 3960,
  canAttack          = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[KBOT MOBILE WEAPON ALL NOTSUB NOTSHIP NOTAIR]],
  corpse             = [[DEAD]],
  defaultmissiontype = [[Standby]],
  description        = [[Fast Raider Kbot]],
  energyMake         = 0.4,
  energyStorage      = 0,
  explodeAs          = [[SMALL_UNITEX]],
  firestandorders    = 1,
  footprintX         = 2,
  footprintZ         = 2,
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 640,
  maxDamage          = 620,
  maxSlope           = 17,
  maxVelocity        = 3.71,
  maxWaterDepth      = 12,
  metalStorage       = 0,
  mobilestandorders  = 1,
  movementClass      = [[KBOT2]],
  name               = [[Zipper]],
  noAutoFire         = false,
  noChaseCategory    = [[VTOL]],
  objectName         = [[ARMFAST]],
  seismicSignature   = 0,
  selfDestructAs     = [[SMALL_UNIT]],
  side               = [[ARM]],
  sightDistance      = 351,
  smoothAnim         = true,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 2,
  TEDClass           = [[KBOT]],
  turnRate           = 1430,
  unitname           = [[armfast]],
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
      [[kbarmmov]],
    },
    select = {
      [[kbarmsel]],
    },
  },
  weapons = {
    [1]  = {
      badTargetCategory  = [[VTOL]],
      def                = [[ARM_FAST]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  ARM_FAST = {
    areaOfEffect       = 16,
    burst              = 5,
    burstrate          = 0.1,
    craterBoost        = 0,
    craterMult         = 0,
    endsmoke           = 0,
    explosionGenerator = [[custom:EMG_HIT]],
    impulseBoost       = 0.123,
    impulseFactor      = 0.123,
    intensity          = 0.7,
    lineOfSight        = true,
    name               = [[EMGBurst]],
    noSelfDamage       = true,
    range              = 220,
    reloadtime         = 0.5,
    renderType         = 4,
    rgbColor           = [[1 0.95 0.4]],
    size               = 1.5,
    soundStart         = [[fastemg]],
    startsmoke         = 0,
    turret             = true,
    weaponTimer        = 0.6,
    weaponType         = [[Cannon]],
    weaponVelocity     = 500,
    damage = {
      default            = 12,
      gunships           = 1,
      hgunships          = 1,
      l1bombers          = 1,
      l1fighters         = 1,
      l1subs             = 1,
      l2bombers          = 1,
      l2fighters         = 1,
      l2subs             = 1,
      l3subs             = 1,
      vradar             = 1,
      vtol               = 1,
      vtrans             = 1,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 240,
    description        = [[Zipper Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 20,
    hitdensity         = 100,
    metal              = 105,
    object             = [[ARMFAST_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 120,
    description        = [[Zipper Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 4,
    hitdensity         = 100,
    metal              = 42,
    object             = [[2X2E]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
