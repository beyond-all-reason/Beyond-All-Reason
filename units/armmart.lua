-- UNITDEF -- ARMMART --
--------------------------------------------------------------------------------

local unitName = "armmart"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.0184,
  badTargetCategory  = [[VTOL]],
  bmcode             = 1,
  brakeRate          = 0.1232,
  buildCostEnergy    = 3840,
  buildCostMetal     = 254,
  builder            = false,
  buildPic           = [[ARMMART.DDS]],
  buildTime          = 5530,
  canAttack          = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL TANK MOBILE WEAPON NOTSUB NOTSHIP NOTAIR]],
  corpse             = [[DEAD]],
  defaultmissiontype = [[Standby]],
  description        = [[Mobile Artillery]],
  energyMake         = 0.4,
  energyStorage      = 0,
  energyUse          = 0.4,
  explodeAs          = [[BIG_UNITEX]],
  firestandorders    = 1,
  footprintX         = 3,
  footprintZ         = 3,
  idleAutoHeal       = 5,
  idleTime           = 1800,
  leaveTracks        = true,
  maneuverleashlength = 640,
  maxDamage          = 600,
  maxSlope           = 12,
  maxVelocity        = 1.81,
  maxWaterDepth      = 0,
  metalStorage       = 0,
  mobilestandorders  = 1,
  movementClass      = [[TANK3]],
  name               = [[Luger]],
  noAutoFire         = false,
  noChaseCategory    = [[NOTLAND VTOL]],
  objectName         = [[ARMMART]],
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[ARM]],
  sightDistance      = 286,
  smoothAnim         = true,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[TANK]],
  trackOffset        = -8,
  trackStrength      = 8,
  trackStretch       = 1,
  trackType          = [[StdTank]],
  trackWidth         = 35,
  turnRate           = 402,
  unitname           = [[armmart]],
  workerTime         = 0,
  customparams = {
    canareaattack      = 1,
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
      [[tarmmove]],
    },
    select = {
      [[tarmsel]],
    },
  },
  weapons = {
    [1]  = {
      badTargetCategory  = [[VTOL]],
      def                = [[ARM_ARTILLERY]],
      mainDir            = [[0 0 1]],
      maxAngleDif        = 180,
      onlyTargetCategory = [[NOTAIR]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  ARM_ARTILLERY = {
    accuracy           = 900,
    areaOfEffect       = 120,
    ballistic          = true,
    craterBoost        = 0,
    craterMult         = 0,
    edgeEffectiveness  = 0.5,
    explosionGenerator = [[custom:FLASH4]],
    gravityaffected    = [[true]],
    impulseBoost       = 0.123,
    impulseFactor      = 0.123,
    minbarrelangle     = -10,
    name               = [[PlasmaCannon]],
    noSelfDamage       = true,
    range              = 935,
    reloadtime         = 2.25,
    renderType         = 4,
    soundHit           = [[xplomed4]],
    soundStart         = [[cannhvy2]],
    startsmoke         = 1,
    turret             = true,
    weaponType         = [[Cannon]],
    weaponVelocity     = 355.28158569336,
    damage = {
      default            = 165,
      gunships           = 15,
      hgunships          = 15,
      l1bombers          = 15,
      l1fighters         = 15,
      l1subs             = 5,
      l2bombers          = 15,
      l2fighters         = 15,
      l2subs             = 5,
      l3subs             = 5,
      vradar             = 15,
      vtol               = 15,
      vtrans             = 15,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 360,
    description        = [[Luger Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 3,
    footprintZ         = 3,
    height             = 20,
    hitdensity         = 100,
    metal              = 198,
    object             = [[ARMMART_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 180,
    description        = [[Luger Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 4,
    hitdensity         = 100,
    metal              = 79,
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
