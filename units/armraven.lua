-- UNITDEF -- ARMRAVEN --
--------------------------------------------------------------------------------

local unitName = "armraven"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.108,
  bmcode             = 1,
  brakeRate          = 0.188,
  buildCostEnergy    = 75625,
  buildCostMetal     = 4551,
  builder            = false,
  buildPic           = [[ARMRAVEN.DDS]],
  buildTime          = 126522,
  canAttack          = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[WEAPON NOTSUB NOTAIR]],
  collisionvolumeoffsets = [[0 0 2]],
  collisionvolumescales = [[60 53 30]],
  collisionvolumetest = 1,
  collisionvolumetype = [[box]],
  corpse             = [[DEAD]],
  defaultmissiontype = [[Standby]],
  description        = [[Heavy Rocket Kbot]],
  explodeAs          = [[MECH_BLAST]],
  firestandorders    = 1,
  footprintX         = 4,
  footprintZ         = 4,
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 640,
  mass               = 200000,
  maxDamage          = 5500,
  maxSlope           = 20,
  maxVelocity        = 1.6,
  maxWaterDepth      = 12,
  mobilestandorders  = 1,
  movementClass      = [[HKBOT4]],
  name               = [[Catapult]],
  noAutoFire         = false,
  noChaseCategory    = [[VTOL]],
  objectName         = [[ARMRAVEN]],
  seismicSignature   = 0,
  selfDestructAs     = [[MECH_BLAST]],
  side               = [[CORE]],
  sightDistance      = 700,
  smoothAnim         = true,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 2,
  TEDClass           = [[KBOT]],
  turnRate           = 979,
  unitname           = [[armraven]],
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
      [[mavbok1]],
    },
    select = {
      [[mavbsel1]],
    },
  },
  weapons = {
    [1]  = {
      badTargetCategory  = [[VTOL]],
      def                = [[EXP_HEAVYROCKET]],
      onlyTargetCategory = [[NOTAIR]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  EXP_HEAVYROCKET = {
    accuracy           = 300,
    areaOfEffect       = 96,
    avoidFeature       = false,
    burst              = 20,
    burstrate          = 0.12,
    craterBoost        = 0,
    craterMult         = 0,
    edgeEffectiveness  = 0.5,
    explosionGenerator = [[custom:MEDMISSILE_EXPLOSION]],
    fireStarter        = 70,
    flightTime         = 3,
    impulseBoost       = 0.123,
    impulseFactor      = 0.123,
    lineOfSight        = true,
    metalpershot       = 0,
    model              = [[exphvyrock]],
    movingAccuracy     = 600,
    name               = [[RavenCatapultRockets]],
    noSelfDamage       = true,
    proximityPriority  = -1,
    range              = 1350,
    reloadtime         = 15,
    renderType         = 1,
    selfprop           = true,
    smokedelay         = 0.1,
    smokeTrail         = true,
    soundHit           = [[rockhit]],
    soundStart         = [[rapidrocket3]],
    sprayAngle         = 1200,
    startsmoke         = 1,
    startVelocity      = 200,
    texture2           = [[coresmoketrail]],
    trajectoryHeight   = 1,
    turnRate           = 0,
    turret             = true,
    weaponAcceleration = 120,
    weaponTimer        = 6,
    weaponType         = [[MissileLauncher]],
    weaponVelocity     = 510,
    wobble             = 1800,
    damage = {
      default            = 450,
      l1subs             = 5,
      l2subs             = 5,
      l3subs             = 5,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 3300,
    description        = [[Catapult Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 3,
    footprintZ         = 3,
    height             = 40,
    hitdensity         = 100,
    metal              = 2958,
    object             = [[ARMRAVEN_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 1650,
    description        = [[Catapult Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 3,
    footprintZ         = 3,
    height             = 4,
    hitdensity         = 100,
    metal              = 1183,
    object             = [[3X3C]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
