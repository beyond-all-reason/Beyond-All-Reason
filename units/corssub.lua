-- UNITDEF -- CORSSUB --
--------------------------------------------------------------------------------

local unitName = "corssub"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.028,
  activateWhenBuilt  = true,
  badTargetCategory  = [[HOVER NOTSHIP]],
  bmcode             = 1,
  brakeRate          = 0.188,
  buildCostEnergy    = 11940,
  buildCostMetal     = 1757,
  builder            = false,
  buildPic           = [[CORSSUB.DDS]],
  buildTime          = 23007,
  canAttack          = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL UNDERWATER MOBILE WEAPON NOTLAND NOTAIR]],
  collisionVolumeType = [[Ell]],
  collisionVolumeScales = [[52 16 67]],
  collisionVolumeOffsets = [[0 -2 0]],
  collisionVolumeTest = 1,
  corpse             = [[DEAD]],
  defaultmissiontype = [[Standby]],
  description        = [[Battle Submarine]],
  energyMake         = 15,
  energyStorage      = 0,
  energyUse          = 15,
  explodeAs          = [[BIG_UNITEX]],
  firestandorders    = 1,
  footprintX         = 3,
  footprintZ         = 3,
  iconType           = [[sea]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 640,
  maxDamage          = 2320,
  maxVelocity        = 2.59,
  metalStorage       = 0,
  minWaterDepth      = 20,
  mobilestandorders  = 1,
  movementClass      = [[UBOAT3]],
  name               = [[Leviathan]],
  noAutoFire         = false,
  noChaseCategory    = [[VTOL]],
  objectName         = [[CORSSUB]],
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[CORE]],
  sightDistance      = 520,
  smoothAnim         = true,
  sonarDistance      = 550,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[WATER]],
  turnRate           = 395,
  unitname           = [[corssub]],
  upright            = true,
  waterline          = 30,
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
      [[sucormov]],
    },
    select = {
      [[sucorsel]],
    },
  },
  weapons = {
    [1]  = {
      badTargetCategory  = [[HOVER NOTSHIP]],
      def                = [[CORSSUB_WEAPON]],
      mainDir            = [[0 0 1]],
      maxAngleDif        = 75,
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  CORSSUB_WEAPON = {
    areaOfEffect       = 16,
    avoidFriendly      = false,
    burnblow           = true,
    collideFriendly    = false,
    craterBoost        = 0,
    craterMult         = 0,
    explosionGenerator = [[custom:FLASH3]],
    guidance           = true,
    impulseBoost       = 0.123,
    impulseFactor      = 0.123,
    lineOfSight        = true,
    model              = [[advtorpedo]],
    name               = [[advTorpedo]],
    noSelfDamage       = true,
    propeller          = 1,
    range              = 690,
    reloadtime         = 1.5,
    renderType         = 1,
    selfprop           = true,
    soundHit           = [[xplodep1]],
    soundStart         = [[torpedo1]],
    startVelocity      = 150,
    tolerance          = 32767,
    tracks             = true,
    turnRate           = 1500,
    turret             = true,
    waterWeapon        = true,
    weaponAcceleration = 25,
    weaponTimer        = 4,
    weaponType         = [[TorpedoLauncher]],
    weaponVelocity     = 220,
    damage = {
      atl                = 750,
      default            = 500,
      krogoth            = 1500,
      l1subs             = 250,
      l2subs             = 150,
      l3subs             = 250,
      tl                 = 750,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = false,
    category           = [[corpses]],
    damage             = 1172,
    description        = [[Leviathan Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    footprintX         = 3,
    footprintZ         = 3,
    height             = 4,
    hitdensity         = 100,
    metal              = 1202,
    object             = [[CORSSUB_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 2016,
    description        = [[Leviathan Heap]],
    energy             = 0,
    footprintX         = 2,
    footprintZ         = 2,
    height             = 4,
    hitdensity         = 100,
    metal              = 376,
    object             = [[2X2A]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
