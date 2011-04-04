-- UNITDEF -- ARMBATS --
--------------------------------------------------------------------------------

local unitName = "armbats"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.036,
  badTargetCategory  = [[VTOL]],
  bmcode             = 1,
  brakeRate          = 0.031,
  buildAngle         = 16384,
  buildCostEnergy    = 20731,
  buildCostMetal     = 5181,
  builder            = false,
  buildPic           = [[ARMBATS.DDS]],
  buildTime          = 58730,
  canAttack          = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL NOTLAND MOBILE WEAPON NOTSUB SHIP NOTAIR]],
  corpse             = [[DEAD]],
  defaultmissiontype = [[Standby]],
  description        = [[Battleship]],
  energyMake         = 100,
  energyStorage      = 0,
  energyUse          = 48,
  explodeAs          = [[BIG_UNITEX]],
  firestandorders    = 1,
  floater            = true,
  footprintX         = 6,
  footprintZ         = 6,
  iconType           = [[sea]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 640,
  maxDamage          = 15810,
  maxVelocity        = 2.88,
  metalStorage       = 0,
  minWaterDepth      = 15,
  mobilestandorders  = 1,
  movementClass      = [[DBOAT6]],
  name               = [[Millennium]],
  noAutoFire         = false,
  noChaseCategory    = [[VTOL]],
  objectName         = [[ARMBATS]],
  scale              = 0.6,
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[ARM]],
  sightDistance      = 455,
  smoothAnim         = true,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[SHIP]],
  turnRate           = 310,
  unitname           = [[armbats]],
  waterline          = 12,
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
      [[sharmmov]],
    },
    select = {
      [[sharmsel]],
    },
  },
  weapons = {
    [1]  = {
      badTargetCategory  = [[VTOL]],
      def                = [[ARM_BATS]],
      mainDir            = [[0 0 1]],
      maxAngleDif        = 330,
      onlyTargetCategory = [[NOTAIR]],
    },
    [2]  = {
      def                = [[ARM_BATS]],
      mainDir            = [[0 0 1]],
      maxAngleDif        = 270,
      onlyTargetCategory = [[NOTAIR]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  ARM_BATS = {
    accuracy           = 350,
    areaOfEffect       = 96,
    ballistic          = true,
    craterBoost        = 0,
    craterMult         = 0,
    explosionGenerator = [[custom:FLASH96]],
    gravityaffected    = [[true]],
    impulseBoost       = 0.123,
    impulseFactor      = 0.123,
    minbarrelangle     = -25,
    name               = [[BattleshipCannon]],
    noSelfDamage       = true,
    range              = 1240,
    reloadtime         = 0.4,
    renderType         = 4,
    soundHit           = [[xplomed2]],
    soundStart         = [[cannhvy1]],
    startsmoke         = 1,
    tolerance          = 5000,
    turret             = true,
    weaponType         = [[Cannon]],
    weaponVelocity     = 470,
    damage = {
      default            = 300,
      gunships           = 65,
      hgunships          = 65,
      l1bombers          = 65,
      l1fighters         = 65,
      l1subs             = 5,
      l2bombers          = 65,
      l2fighters         = 65,
      l2subs             = 5,
      l3subs             = 5,
      vradar             = 65,
      vtol               = 65,
      vtrans             = 65,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = false,
    category           = [[corpses]],
    damage             = 6486,
    description        = [[Millennium Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    footprintX         = 6,
    footprintZ         = 6,
    height             = 4,
    hitdensity         = 100,
    metal              = 3368,
    object             = [[ARMBATS_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 2016,
    description        = [[Millennium Heap]],
    energy             = 0,
    footprintX         = 2,
    footprintZ         = 2,
    height             = 4,
    hitdensity         = 100,
    metal              = 1066,
    object             = [[6X6D]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
