-- UNITDEF -- CORSHARK --
--------------------------------------------------------------------------------

local unitName = "corshark"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.048,
  activateWhenBuilt  = true,
  badTargetCategory  = [[HOVER NOTSHIP]],
  bmcode             = 1,
  brakeRate          = 0.25,
  buildCostEnergy    = 9245,
  buildCostMetal     = 956,
  builder            = false,
  buildPic           = [[CORSHARK.DDS]],
  buildTime          = 15529,
  canAttack          = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL UNDERWATER MOBILE WEAPON NOTLAND NOTAIR]],
  collisionVolumeType = [[Ell]],
  collisionVolumeScales = [[28 16 57]],
  collisionVolumeOffsets = [[0 0 -1]],
  collisionVolumeTest = 1,
  corpse             = [[DEAD]],
  defaultmissiontype = [[Standby]],
  description        = [[Submarine Killer]],
  energyMake         = 0.5,
  energyStorage      = 0,
  energyUse          = 0.5,
  explodeAs          = [[SMALL_UNITEX]],
  firestandorders    = 1,
  footprintX         = 3,
  footprintZ         = 3,
  iconType           = [[sea]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 640,
  maxDamage          = 835,
  maxVelocity        = 3.04,
  metalStorage       = 0,
  minWaterDepth      = 20,
  mobilestandorders  = 1,
  movementClass      = [[UBOAT3]],
  name               = [[Shark]],
  noAutoFire         = false,
  noChaseCategory    = [[VTOL]],
  objectName         = [[CORSHARK]],
  seismicSignature   = 0,
  selfDestructAs     = [[SMALL_UNIT]],
  side               = [[CORE]],
  sightDistance      = 390,
  smoothAnim         = true,
  sonarDistance      = 525,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[SHIP]],
  turnRate           = 289,
  unitname           = [[corshark]],
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
      def                = [[ARMSMART_TORPEDO]],
      mainDir            = [[0 0 1]],
      maxAngleDif        = 150,
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  ARMSMART_TORPEDO = {
    areaOfEffect       = 16,
    avoidFriendly      = false,
    burnblow           = true,
    collideFriendly    = false,
    craterBoost        = 0,
    craterMult         = 0,
    explosionGenerator = [[custom:FLASH2]],
    guidance           = true,
    impulseBoost       = 0.123,
    impulseFactor      = 0.123,
    lineOfSight        = true,
    model              = [[torpedo]],
    name               = [[AdvancedTorpedo]],
    noSelfDamage       = true,
    propeller          = 1,
    range              = 600,
    reloadtime         = 2,
    renderType         = 1,
    selfprop           = true,
    soundHit           = [[xplodep1]],
    soundStart         = [[torpedo1]],
    startVelocity      = 120,
    tolerance          = 32767,
    tracks             = true,
    turnRate           = 12000,
    turret             = false,
    waterWeapon        = true,
    weaponAcceleration = 20,
    weaponTimer        = 3,
    weaponType         = [[TorpedoLauncher]],
    weaponVelocity     = 200,
    damage = {
      atl                = 375,
      default            = 250,
      krogoth            = 1000,
      l1subs             = 400,
      l2subs             = 400,
      l3subs             = 500,
      tl                 = 375,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = false,
    category           = [[corpses]],
    damage             = 681,
    description        = [[Shark Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    footprintX         = 6,
    footprintZ         = 6,
    height             = 4,
    hitdensity         = 100,
    metal              = 321,
    object             = [[CORSHARK_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 2016,
    description        = [[Shark Heap]],
    energy             = 0,
    footprintX         = 2,
    footprintZ         = 2,
    height             = 4,
    hitdensity         = 100,
    metal              = 127,
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
