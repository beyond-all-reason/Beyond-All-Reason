-- UNITDEF -- ARMPW --
--------------------------------------------------------------------------------

local unitName = "armpw"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.36,
  badTargetCategory  = [[VTOL]],
  bmcode             = 1,
  brakeRate          = 0.2,
  buildCostEnergy    = 897,
  buildCostMetal     = 45,
  builder            = false,
  buildPic           = [[ARMPW.DDS]],
  buildTime          = 1420,
  canAttack          = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[KBOT MOBILE WEAPON ALL NOTSUB NOTSHIP NOTAIR]],
  corpse             = [[DEAD]],
  defaultmissiontype = [[Standby]],
  description        = [[Infantry Kbot]],
  energyMake         = 0.3,
  energyStorage      = 0,
  energyUse          = 0.3,
  explodeAs          = [[SMALL_UNITEX]],
  firestandorders    = 1,
  footprintX         = 2,
  footprintZ         = 2,
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 640,
  maxDamage          = 300,
  maxSlope           = 17,
  maxVelocity        = 2.8,
  maxWaterDepth      = 12,
  metalStorage       = 0,
  mobilestandorders  = 1,
  movementClass      = [[KBOT2]],
  name               = [[Peewee]],
  noAutoFire         = false,
  noChaseCategory    = [[VTOL]],
  objectName         = [[ARMPW]],
  seismicSignature   = 0,
  selfDestructAs     = [[SMALL_UNIT]],
  side               = [[ARM]],
  sightDistance      = 429,
  smoothAnim         = true,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 2,
  TEDClass           = [[KBOT]],
  turnRate           = 1056,
  unitname           = [[armpw]],
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
      [[servtny2]],
    },
    select = {
      [[servtny2]],
    },
  },
  weapons = {
    [1]  = {
      badTargetCategory  = [[VTOL]],
      def                = [[EMG]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  EMG = {
    areaOfEffect       = 8,
    avoidFeature       = false,
    burst              = 3,
    burstrate          = 0.1,
    craterBoost        = 0,
    craterMult         = 0,
    endsmoke           = 0,
    explosionGenerator = [[custom:EMG_HIT]],
    fireStarter        = 100,
    impulseBoost       = 0.123,
    impulseFactor      = 0.123,
    intensity          = 0.7,
    lineOfSight        = true,
    name               = [[peewee]],
    noSelfDamage       = true,
    range              = 180,
    reloadtime         = 0.31,
    renderType         = 4,
    rgbColor           = [[1 0.95 0.4]],
    size               = 1.75,
    soundStart         = [[flashemg]],
    sprayAngle         = 1180,
    startsmoke         = 0,
    tolerance          = 5000,
    turret             = true,
    weaponTimer        = 0.1,
    weaponType         = [[Cannon]],
    weaponVelocity     = 500,
    damage = {
      default            = 11,
      gunships           = 3,
      hgunships          = 3,
      l1bombers          = 3,
      l1fighters         = 3,
      l1subs             = 1,
      l2bombers          = 3,
      l2fighters         = 3,
      l2subs             = 1,
      l3subs             = 1,
      vradar             = 3,
      vtol               = 3,
      vtrans             = 3,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = false,
    category           = [[corpses]],
    damage             = 192,
    description        = [[Peewee Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 40,
    hitdensity         = 100,
    metal              = 29,
    object             = [[ARMPW_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 96,
    description        = [[Peewee Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 4,
    hitdensity         = 100,
    metal              = 12,
    object             = [[2X2F]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
