-- UNITDEF -- ARMST --
--------------------------------------------------------------------------------

local unitName = "armst"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.0264,
  badTargetCategory  = [[VTOL]],
  bmcode             = 1,
  brakeRate          = 0.055,
  buildCostEnergy    = 3480,
  buildCostMetal     = 212,
  builder            = false,
  buildPic           = [[ARMST.DDS]],
  buildTime          = 6704,
  canAttack          = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL TANK MOBILE WEAPON NOTSUB NOTSHIP NOTAIR]],
  cloakCost          = 5,
  cloakCostMoving    = 20,
  corpse             = [[DEAD]],
  defaultmissiontype = [[Standby]],
  description        = [[Stealth Tank]],
  energyMake         = 0.9,
  energyStorage      = 0,
  energyUse          = 0.9,
  explodeAs          = [[BIG_UNITEX]],
  firestandorders    = 1,
  footprintX         = 2,
  footprintZ         = 2,
  idleAutoHeal       = 5,
  idleTime           = 1800,
  initCloaked        = false,
  leaveTracks        = true,
  maneuverleashlength = 640,
  maxDamage          = 950,
  maxSlope           = 12,
  maxVelocity        = 2.497,
  maxWaterDepth      = 0,
  metalStorage       = 0,
  minCloakDistance   = 65,
  mobilestandorders  = 1,
  movementClass      = [[TANK2]],
  name               = [[Gremlin]],
  noAutoFire         = false,
  noChaseCategory    = [[VTOL]],
  objectName         = [[ARMST]],
  seismicSignature   = 4,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[ARM]],
  sightDistance      = 494,
  smoothAnim         = false,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  stealth            = true,
  steeringmode       = 1,
  TEDClass           = [[TANK]],
  trackOffset        = 0,
  trackStrength      = 6,
  trackStretch       = 1,
  trackType          = [[StdTank]],
  trackWidth         = 29,
  turnRate           = 701.8,
  unitname           = [[armst]],
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
      def                = [[ARMST_GAUSS]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  ARMST_GAUSS = {
    areaOfEffect       = 8,
    craterBoost        = 0,
    craterMult         = 0,
    explosionGenerator = [[custom:LIGHT_PLASMA]],
    impulseBoost       = 0.123,
    impulseFactor      = 0.123,
    lineOfSight        = true,
    minbarrelangle     = -15,
    name               = [[Gauss]],
    noSelfDamage       = true,
    range              = 220,
    reloadtime         = 3,
    renderType         = 4,
    soundHit           = [[xplomed2]],
    soundStart         = [[cannhvy1]],
    startsmoke         = 1,
    turret             = true,
    weaponType         = [[Cannon]],
    weaponVelocity     = 450,
    damage = {
      default            = 262.5,
      gunships           = 24,
      hgunships          = 24,
      l1bombers          = 24,
      l1fighters         = 24,
      l1subs             = 5,
      l2bombers          = 24,
      l2fighters         = 24,
      l2subs             = 5,
      l3subs             = 5,
      vradar             = 24,
      vtol               = 24,
      vtrans             = 24,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 570,
    description        = [[Gremlin Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 15,
    hitdensity         = 100,
    metal              = 138,
    object             = [[ARMST_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 285,
    description        = [[Gremlin Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 4,
    hitdensity         = 100,
    metal              = 55,
    object             = [[2X2B]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
