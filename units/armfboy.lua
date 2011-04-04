-- UNITDEF -- ARMFBOY --
--------------------------------------------------------------------------------

local unitName = "armfboy"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.12,
  bmcode             = 1,
  brakeRate          = 0.125,
  buildCostEnergy    = 11193,
  buildCostMetal     = 1418,
  builder            = false,
  buildPic           = [[ARMFBOY.DDS]],
  buildTime          = 22397,
  canAttack          = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[KBOT WEAPON ALL NOTSUB NOTAIR]],
  corpse             = [[DEAD]],
  defaultmissiontype = [[Standby]],
  description        = [[Heavy Plasma Kbot]],
  energyMake         = 5.1,
  energyStorage      = 0,
  energyUse          = 5,
  explodeAs          = [[BIG_UNITEX]],
  firestandorders    = 1,
  footprintX         = 4,
  footprintZ         = 4,
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 640,
  maxDamage          = 7000,
  maxSlope           = 20,
  maxVelocity        = 1,
  maxWaterDepth      = 25,
  metalStorage       = 0,
  mobilestandorders  = 1,
  movementClass      = [[HKBOT4]],
  name               = [[Fatboy]],
  noAutoFire         = false,
  noChaseCategory    = [[VTOL]],
  objectName         = [[ARMFBOY]],
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[ARM]],
  sightDistance      = 510,
  smoothAnim         = true,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 2,
  TEDClass           = [[KBOT]],
  turnRate           = 320,
  unitname           = [[armfboy]],
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
      [[mavbot1]],
    },
    select = {
      [[capture2]],
    },
  },
  weapons = {
    [1]  = {
      badTargetCategory  = [[VTOL]],
      def                = [[ARM_FATBOY_NOTALASER]],
      onlyTargetCategory = [[NOTAIR]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  ARM_FATBOY_NOTALASER = {
    areaOfEffect       = 240,
    ballistic          = true,
    craterBoost        = 0,
    craterMult         = 0,
    edgeEffectiveness  = 0.7,
    energypershot      = 0,
    explosionGenerator = [[custom:FLASH224]],
    gravityaffected    = [[true]],
    impulseBoost       = 0.4,
    impulseFactor      = 0.4,
    minbarrelangle     = -20,
    name               = [[HeavyPlasma]],
    noSelfDamage       = true,
    range              = 700,
    reloadtime         = 6.75,
    renderType         = 4,
    shakeduration      = 1,
    shakemagnitude     = 4,
    soundHit           = [[bertha6]],
    soundStart         = [[BERTHA1]],
    turret             = true,
    weaponType         = [[Cannon]],
    weaponVelocity     = 307.40850830078,
    damage = {
      default            = 800,
      gunships           = 111,
      hgunships          = 111,
      l1bombers          = 111,
      l1fighters         = 111,
      l1subs             = 5,
      l2bombers          = 111,
      l2fighters         = 111,
      l2subs             = 5,
      l3subs             = 5,
      vradar             = 111,
      vtol               = 111,
      vtrans             = 111,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 4200,
    description        = [[Fatboy Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 9,
    hitdensity         = 100,
    metal              = 1008,
    object             = [[ARMFBOY_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[all]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 2100,
    description        = [[Fatboy Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 2,
    footprintZ         = 2,
    hitdensity         = 100,
    metal              = 403,
    object             = [[2X2A]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[all]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
