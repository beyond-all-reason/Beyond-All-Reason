-- UNITDEF -- ARMFIDO --
--------------------------------------------------------------------------------

local unitName = "armfido"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.12,
  activateWhenBuilt  = false,
  badTargetCategory  = [[VTOL]],
  bmcode             = 1,
  brakeRate          = 0.375,
  buildCostEnergy    = 5264,
  buildCostMetal     = 253,
  builder            = false,
  buildPic           = [[ARMFIDO.DDS]],
  buildTime          = 6924,
  canAttack          = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[KBOT MOBILE WEAPON ALL NOTSUB NOTSHIP NOTAIR]],
  corpse             = [[DEAD]],
  defaultmissiontype = [[Standby]],
  description        = [[Mortar/Skirmish Kbot]],
  energyMake         = 0.8,
  energyStorage      = 0,
  energyUse          = 0.8,
  explodeAs          = [[BIG_UNITEX]],
  firestandorders    = 1,
  footprintX         = 2,
  footprintZ         = 2,
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 640,
  maxDamage          = 1150,
  maxSlope           = 14,
  maxVelocity        = 2.3,
  maxWaterDepth      = 12,
  metalStorage       = 0,
  mobilestandorders  = 1,
  movementClass      = [[KBOT2]],
  name               = [[Fido]],
  noAutoFire         = false,
  noChaseCategory    = [[VTOL]],
  objectName         = [[ARMFIDO]],
  onoffable          = true,
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[ARM]],
  sightDistance      = 400,
  smoothAnim         = true,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 2,
  TEDClass           = [[KBOT]],
  turnRate           = 990,
  unitname           = [[armfido]],
  upright            = false,
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
      badTargetCategory  = [[VTOL]],
      def                = [[GAUSS]],
    },
    [2]  = {
      def                = [[BFIDO]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  BFIDO = {
    areaOfEffect       = 48,
    ballistic          = true,
    craterBoost        = 0,
    craterMult         = 0,
    explosionGenerator = [[custom:FLASH2]],
    gravityaffected    = [[true]],
    impulseBoost       = 0.123,
    impulseFactor      = 0.123,
    minbarrelangle     = -15,
    name               = [[BallisticCannon]],
    noSelfDamage       = true,
    range              = 650,
    reloadtime         = 3.186,
    renderType         = 4,
    soundHit           = [[xplomed2]],
    soundStart         = [[cannon1]],
    startsmoke         = 1,
    turret             = true,
    weaponType         = [[Cannon]],
    weaponVelocity     = 291.63333129883,
    damage = {
      default            = 255,
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
  GAUSS = {
    areaOfEffect       = 8,
    craterBoost        = 0,
    craterMult         = 0,
    explosionGenerator = [[custom:FLASH1nd]],
    impulseBoost       = 0.123,
    impulseFactor      = 0.123,
    lineOfSight        = true,
    minbarrelangle     = -15,
    name               = [[GaussCannon]],
    noSelfDamage       = true,
    range              = 650,
    reloadtime         = 1.79,
    renderType         = 4,
    soundHit           = [[xplomed2]],
    soundStart         = [[cannhvy1]],
    startsmoke         = 1,
    turret             = true,
    weaponType         = [[Cannon]],
    weaponVelocity     = 550,
    damage = {
      default            = 170,
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
    damage             = 690,
    description        = [[Fido Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 20,
    hitdensity         = 100,
    metal              = 164,
    object             = [[ARMFIDO_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 345,
    description        = [[Fido Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 4,
    hitdensity         = 100,
    metal              = 66,
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
