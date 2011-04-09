-- UNITDEF -- TAWF009 --
--------------------------------------------------------------------------------

local unitName = "tawf009"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.08,
  activateWhenBuilt  = true,
  badTargetCategory  = [[HOVER NOTSHIP]],
  bmcode             = 1,
  brakeRate          = 0.3,
  buildCostEnergy    = 11702,
  buildCostMetal     = 1686,
  builder            = false,
  buildPic           = [[TAWF009.DDS]],
  buildTime          = 21087,
  canAttack          = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[UNDERWATER ALL WEAPON NOTAIR]],
  collisionVolumeType = [[Ell]],
  collisionVolumeScales = [[45 19 57]],
  collisionVolumeOffsets = [[0 -2 0]],
  collisionVolumeTest =1;
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
  maxDamage          = 2190,
  maxVelocity        = 2.65,
  metalStorage       = 0,
  minWaterDepth      = 20,
  mobilestandorders  = 1,
  movementClass      = [[UBOAT3]],
  name               = [[Serpent]],
  noAutoFire         = false,
  noChaseCategory    = [[VTOL]],
  objectName         = [[TAWF009]],
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[ARM]],
  sightDistance      = 468,
  smoothAnim         = false,
  sonarDistance      = 550,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[WATER]],
  turnRate           = 404,
  unitname           = [[tawf009]],
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
      [[suarmmov]],
    },
    select = {
      [[suarmsel]],
    },
  },
  weapons = {
    [1]  = {
      badTargetCategory  = [[HOVER NOTSHIP]],
      def                = [[TAWF009_WEAPON]],
      mainDir            = [[0 0 1]],
      maxAngleDif        = 75,
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  TAWF009_WEAPON = {
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
    name               = [[AdvTorpedo]],
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
    turnRate           = 1750,
    turret             = false,
    waterWeapon        = true,
    weaponAcceleration = 25,
    weaponTimer        = 3,
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
    damage             = 2100,
    description        = [[Serpent Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 6,
    footprintZ         = 6,
    height             = 10,
    hitdensity         = 100,
    metal              = 1332,
    object             = [[TAWF009_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 1050,
    description        = [[Serpent Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 6,
    footprintZ         = 6,
    height             = 4,
    hitdensity         = 100,
    metal              = 513,
    object             = [[3X3F]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
