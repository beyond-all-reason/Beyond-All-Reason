-- UNITDEF -- CORSEAL --
--------------------------------------------------------------------------------

local unitName = "corseal"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.0462,
  amphibious         = 1,
  badTargetCategory  = [[VTOL]],
  bmcode             = 1,
  brakeRate          = 0.0209,
  buildCostEnergy    = 7208,
  buildCostMetal     = 450,
  builder            = false,
  buildPic           = [[CORSEAL.DDS]],
  buildTime          = 7010,
  canAttack          = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL TANK MOBILE WEAPON NOTSUB NOTSHIP NOTAIR]],
  corpse             = [[DEAD]],
  defaultmissiontype = [[Standby]],
  description        = [[Medium Amphibious Tank]],
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
  maxDamage          = 2340,
  maxSlope           = 12,
  maxVelocity        = 2.645,
  maxWaterDepth      = 255,
  metalStorage       = 0,
  mobilestandorders  = 1,
  movementClass      = [[ATANK3]],
  name               = [[Croc]],
  noAutoFire         = false,
  noChaseCategory    = [[VTOL]],
  objectName         = [[CORSEAL]],
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[CORE]],
  sightDistance      = 399,
  smoothAnim         = true,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[TANK]],
  trackOffset        = 6,
  trackStrength      = 5,
  trackStretch       = 1,
  trackType          = [[StdTank]],
  trackWidth         = 30,
  turnRate           = 487,
  unitname           = [[corseal]],
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
      [[tcormove]],
    },
    select = {
      [[tcorsel]],
    },
  },
  weapons = {
    [1]  = {
      badTargetCategory  = [[VTOL]],
      def                = [[CORE_CROC]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  CORE_CROC = {
    areaOfEffect       = 64,
    ballistic          = true,
    craterBoost        = 0,
    craterMult         = 0,
    explosionGenerator = [[custom:FLASH64]],
    gravityaffected    = [[true]],
    impulseBoost       = 0.123,
    impulseFactor      = 0.123,
    name               = [[PlasmaCannon]],
    noSelfDamage       = true,
    range              = 440,
    reloadtime         = 0.9,
    renderType         = 4,
    soundHit           = [[xplomed4]],
    soundStart         = [[cannon2]],
    turret             = true,
    weaponType         = [[Cannon]],
    weaponVelocity     = 260,
    damage = {
      default            = 116,
      gunships           = 29,
      hgunships          = 29,
      l1bombers          = 29,
      l1fighters         = 29,
      l1subs             = 5,
      l2bombers          = 29,
      l2fighters         = 29,
      l2subs             = 5,
      l3subs             = 5,
      vradar             = 29,
      vtol               = 29,
      vtrans             = 29,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = false,
    category           = [[corpses]],
    damage             = 915,
    description        = [[Croc Wreckage]],
    featureDead        = [[HEAP]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 20,
    hitdensity         = 100,
    metal              = 236,
    object             = [[CORSEAL_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 915,
    description        = [[Croc Heap]],
    energy             = 0,
    footprintX         = 2,
    footprintZ         = 2,
    height             = 4,
    hitdensity         = 100,
    metal              = 118,
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
