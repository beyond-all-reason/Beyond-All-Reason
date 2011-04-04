-- UNITDEF -- CORPYRO --
--------------------------------------------------------------------------------

local unitName = "corpyro"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.45,
  bmcode             = 1,
  brakeRate          = 0.65,
  buildCostEnergy    = 2783,
  buildCostMetal     = 189,
  builder            = false,
  buildPic           = [[CORPYRO.DDS]],
  buildTime          = 5027,
  canAttack          = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[KBOT MOBILE WEAPON ALL ANTIFLAME NOTSUB NOTSHIP NOTAIR]],
  corpse             = [[HEAP]],
  defaultmissiontype = [[Standby]],
  description        = [[Fast Assault Kbot]],
  energyMake         = 1.1,
  energyStorage      = 0,
  energyUse          = 1.1,
  explodeAs          = [[BIG_UNITEX]],
  firestandorders    = 1,
  footprintX         = 2,
  footprintZ         = 2,
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 640,
  maxDamage          = 1000,
  maxSlope           = 17,
  maxVelocity        = 2.75,
  maxWaterDepth      = 25,
  metalStorage       = 0,
  mobilestandorders  = 1,
  movementClass      = [[KBOT2]],
  name               = [[Pyro]],
  noAutoFire         = false,
  noChaseCategory    = [[VTOL]],
  objectName         = [[CORPYRO]],
  seismicSignature   = 0,
  selfDestructAs     = [[CORPYRO_BLAST]],
  selfDestructCountdown = 1,
  side               = [[CORE]],
  sightDistance      = 318,
  smoothAnim         = true,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 2,
  TEDClass           = [[KBOT]],
  turnRate           = 1145,
  unitname           = [[corpyro]],
  upright            = true,
  workerTime         = 0,
  sfxtypes = {
    explosiongenerators = {
      [[custom:PILOT]],
    },
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
      [[kbcormov]],
    },
    select = {
      [[kbcorsel]],
    },
  },
  weapons = {
    [1]  = {
      def                = [[FLAMETHROWER]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  FLAMETHROWER = {
    areaOfEffect       = 48,
    avoidFeature       = false,
    burst              = 22,
    burstrate          = 0.01,
    craterBoost        = 0,
    craterMult         = 0,
    endsmoke           = 1,
    fireStarter        = 100,
    flameGfxTime       = 1.9,
    groundbounce       = true,
    impulseBoost       = 0.123,
    impulseFactor      = 0.123,
    intensity          = 0.6,
    lineOfSight        = true,
    name               = [[FlameThrower]],
    noSelfDamage       = true,
    range              = 230,
    reloadtime         = 1.1,
    renderType         = 5,
    rgbColor           = [[1 0.95 0.9]],
    rgbColor2          = [[0.9 0.85 0.8]],
    sizeGrowth         = 1.1,
    soundStart         = [[Flamhvy1]],
    soundTrigger       = false,
    sprayAngle         = 1500,
    tolerance          = 2500,
    turret             = true,
    weaponTimer        = 1.5,
    weaponType         = [[Flame]],
    weaponVelocity     = 265,
    damage = {
      default            = 12,
      flamethrowers      = 5,
      gunships           = 1,
      hgunships          = 1,
      l1subs             = 1,
      l2subs             = 1,
      l3subs             = 1,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

local featureDefs = {
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 560,
    description        = [[Pyro Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 4,
    hitdensity         = 100,
    metal              = 124,
    object             = [[2X2C]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
