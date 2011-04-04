-- UNITDEF -- ARMSNIPE --
--------------------------------------------------------------------------------

local unitName = "armsnipe"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.12,
  bmcode             = 1,
  brakeRate          = 0.188,
  buildCostEnergy    = 14727,
  buildCostMetal     = 535,
  builder            = false,
  buildPic           = [[ARMSNIPE.DDS]],
  buildTime          = 19137,
  canAttack          = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[KBOT MOBILE WEAPON ALL NOTSHIP NOTAIR]],
  cloakCost          = 75,
  cloakCostMoving    = 200,
  corpse             = [[DEAD]],
  defaultmissiontype = [[Standby]],
  description        = [[Sniper Kbot]],
  energyMake         = 0.9,
  energyStorage      = 0,
  energyUse          = 0.9,
  explodeAs          = [[BIG_UNITEX]],
  firestandorders    = 1,
  footprintX         = 2,
  footprintZ         = 2,
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 640,
  maxDamage          = 520,
  maxSlope           = 14,
  maxVelocity        = 1.26,
  maxWaterDepth      = 22,
  metalStorage       = 0,
  minCloakDistance   = 80,
  mobilestandorders  = 1,
  movementClass      = [[KBOT2]],
  name               = [[Sharpshooter]],
  noChaseCategory    = [[VTOL]],
  objectName         = [[ARMSNIPE]],
  onlyTargetCategory = [[NOTAIR]],
  radarDistanceJam   = 10,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[ARM]],
  sightDistance      = 455,
  smoothAnim         = true,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 2,
  TEDClass           = [[KBOT]],
  turnRate           = 1338,
  unitname           = [[armsnipe]],
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
      def                = [[ARMSNIPE_WEAPON]],
      onlyTargetCategory = [[NOTAIR]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  ARMSNIPE_WEAPON = {
    areaOfEffect       = 16,
    beamWeapon         = true,
    collideFriendly    = false,
    craterBoost        = 0,
    craterMult         = 0,
    duration           = 0.0025,
    energypershot      = 500,
    explosionGenerator = [[custom:FLASH1nd]],
    impulseBoost       = 0.234,
    impulseFactor      = 0.234,
    intensity          = 0.75,
    lineOfSight        = true,
    name               = [[SniperWeapon]],
    noradar            = 1,
    noSelfDamage       = true,
    range              = 900,
    reloadtime         = 10,
    renderType         = 0,
    rgbColor           = [[1 1 0]],
    soundHit           = [[xplolrg2]],
    soundHitVolume     = 4,
    soundStart         = [[sniper2]],
    soundStartVolume   = 4,
    thickness          = 0.5,
    turret             = true,
    weaponType         = [[LaserCannon]],
    weaponVelocity     = 3000,
    damage = {
      commanders         = 1025,
      default            = 2500,
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
    damage             = 240,
    description        = [[Sharpshooter Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 20,
    hitdensity         = 100,
    metal              = 322,
    object             = [[ARMSNIPE_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 120,
    description        = [[Sharpshooter Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 4,
    hitdensity         = 100,
    metal              = 129,
    object             = [[2X2D]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
