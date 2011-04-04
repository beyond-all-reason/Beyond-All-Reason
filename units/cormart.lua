-- UNITDEF -- CORMART --
--------------------------------------------------------------------------------

local unitName = "cormart"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.0204,
  badTargetCategory  = [[NOTLAND]],
  bmcode             = 1,
  brakeRate          = 0.1232,
  buildCostEnergy    = 3005,
  buildCostMetal     = 263,
  builder            = false,
  buildPic           = [[CORMART.DDS]],
  buildTime          = 4270,
  canAttack          = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL TANK MOBILE WEAPON NOTSUB NOTSHIP NOTAIR]],
  corpse             = [[DEAD]],
  defaultmissiontype = [[Standby]],
  description        = [[Mobile Artillery]],
  energyMake         = 0.5,
  energyStorage      = 0,
  energyUse          = 0.5,
  explodeAs          = [[BIG_UNITEX]],
  firestandorders    = 1,
  footprintX         = 3,
  footprintZ         = 3,
  idleAutoHeal       = 5,
  idleTime           = 1800,
  leaveTracks        = true,
  maneuverleashlength = 640,
  maxDamage          = 560,
  maxSlope           = 12,
  maxVelocity        = 1.95,
  maxWaterDepth      = 0,
  metalStorage       = 0,
  mobilestandorders  = 1,
  movementClass      = [[TANK3]],
  name               = [[Pillager]],
  noAutoFire         = false,
  noChaseCategory    = [[NOTLAND VTOL]],
  objectName         = [[CORMART]],
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[CORE]],
  sightDistance      = 299,
  smoothAnim         = true,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[TANK]],
  trackOffset        = 8,
  trackStrength      = 8,
  trackStretch       = 1,
  trackType          = [[StdTank]],
  trackWidth         = 31,
  turnRate           = 445,
  unitname           = [[cormart]],
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
      [[tcormove]],
    },
    select = {
      [[tcorsel]],
    },
  },
  weapons = {
    [1]  = {
      badTargetCategory  = [[NOTLAND]],
      def                = [[CORE_ARTILLERY]],
      mainDir            = [[0 0 1]],
      maxAngleDif        = 180,
      onlyTargetCategory = [[NOTAIR]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  CORE_ARTILLERY = {
    accuracy           = 960,
    areaOfEffect       = 129,
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
    range              = 905,
    reloadtime         = 3,
    renderType         = 4,
    soundHit           = [[xplomed4]],
    soundStart         = [[cannhvy2]],
    startsmoke         = 1,
    turret             = true,
    weaponType         = [[Cannon]],
    weaponVelocity     = 349.53540039063,
    damage = {
      default            = 190,
      gunships           = 17,
      hgunships          = 17,
      l1bombers          = 17,
      l1fighters         = 17,
      l1subs             = 5,
      l2bombers          = 17,
      l2fighters         = 17,
      l2subs             = 5,
      l3subs             = 5,
      vradar             = 17,
      vtol               = 17,
      vtrans             = 17,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 336,
    description        = [[Pillager Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 20,
    hitdensity         = 100,
    metal              = 138,
    object             = [[CORMART_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 168,
    description        = [[Pillager Heap]],
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
