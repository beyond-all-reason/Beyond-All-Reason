-- UNITDEF -- ARMJANUS --
--------------------------------------------------------------------------------

local unitName = "armjanus"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.0198,
  badTargetCategory  = [[VTOL]],
  bmcode             = 1,
  brakeRate          = 0.055,
  buildCostEnergy    = 2361,
  buildCostMetal     = 226,
  builder            = false,
  buildPic           = [[ARMJANUS.DDS]],
  buildTime          = 3545,
  canAttack          = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL TANK WEAPON NOTSUB NOTSHIP NOTAIR]],
  corpse             = [[DEAD]],
  defaultmissiontype = [[Standby]],
  description        = [[Twin Medium Rocket Launcher]],
  energyMake         = 0.5,
  energyStorage      = 0,
  energyUse          = 0.5,
  explodeAs          = [[BIG_UNITEX]],
  firestandorders    = 1,
  footprintX         = 2,
  footprintZ         = 2,
  idleAutoHeal       = 5,
  idleTime           = 1800,
  leaveTracks        = true,
  maneuverleashlength = 640,
  maxDamage          = 880,
  maxSlope           = 10,
  maxVelocity        = 1.958,
  maxWaterDepth      = 12,
  metalStorage       = 0,
  mobilestandorders  = 1,
  movementClass      = [[TANK2]],
  name               = [[Janus]],
  noAutoFire         = false,
  noChaseCategory    = [[VTOL]],
  objectName         = [[ARMJANUS]],
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[ARM]],
  sightDistance      = 325,
  smoothAnim         = false,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[TANK]],
  trackOffset        = 3,
  trackStrength      = 6,
  trackStretch       = 1,
  trackType          = [[StdTank]],
  trackWidth         = 24,
  turnRate           = 338.8,
  unitname           = [[armjanus]],
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
      [[tarmmove]],
    },
    select = {
      [[tarmsel]],
    },
  },
  weapons = {
    [1]  = {
      badTargetCategory  = [[VTOL]],
      def                = [[JANUS_ROCKET]],
      onlyTargetCategory = [[NOTAIR]],
    },
    [2]  = {
      def                = [[JANUS_ROCKET]],
      onlyTargetCategory = [[NOTAIR]],
      slaveTo            = 1,
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  JANUS_ROCKET = {
    areaOfEffect       = 128,
    craterBoost        = 0,
    craterMult         = 0,
    explosionGenerator = [[custom:VEHROCKET_EXPLOSION]],
    fireStarter        = 70,
    guidance           = true,
    impulseBoost       = 0.75,
    impulseFactor      = 0.75,
    lineOfSight        = true,
    model              = [[megamisl]],
    name               = [[HeavyRocket]],
    noSelfDamage       = true,
    range              = 380,
    reloadtime         = 7.5,
    renderType         = 1,
    selfprop           = true,
    smokedelay         = .1,
    smokeTrail         = true,
    soundHit           = [[xplosml2]],
    soundHitVolume     = 8,
    soundStart         = [[rocklit1]],
    soundStartVolume   = 7,
    startsmoke         = 1,
    startVelocity      = 190,
    texture2           = [[armsmoketrail]],
    tracks             = true,
    trajectoryHeight   = 0.4,
    turnRate           = 22000,
    turret             = true,
    weaponAcceleration = 100,
    weaponTimer        = 3,
    weaponType         = [[MissileLauncher]],
    weaponVelocity     = 190,
    damage = {
      default            = 330,
      gunships           = 35,
      hgunships          = 35,
      l1bombers          = 35,
      l1fighters         = 35,
      l1subs             = 5,
      l2bombers          = 35,
      l2fighters         = 35,
      l2subs             = 5,
      l3subs             = 5,
      vradar             = 35,
      vtol               = 35,
      vtrans             = 35,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 528,
    description        = [[Janus Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 20,
    hitdensity         = 100,
    metal              = 147,
    object             = [[ARMJANUS_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 264,
    description        = [[Janus Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 4,
    hitdensity         = 100,
    metal              = 59,
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
