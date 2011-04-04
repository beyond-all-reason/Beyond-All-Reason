-- UNITDEF -- TREM --
--------------------------------------------------------------------------------

local unitName = "trem"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.0528,
  badTargetCategory  = [[VTOL]],
  bmcode             = 1,
  brakeRate          = 0.11,
  buildCostEnergy    = 45350,
  buildCostMetal     = 1951,
  builder            = false,
  buildPic           = [[TREM.DDS]],
  buildTime          = 31103,
  canAttack          = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL WEAPON NOTSUB NOTAIR]],
  corpse             = [[DEAD]],
  defaultmissiontype = [[Standby]],
  description        = [[Heavy Artillery Vehicle]],
  energyMake         = 2.1,
  energyStorage      = 0,
  energyUse          = 2.1,
  explodeAs          = [[BIG_UNIT]],
  firestandorders    = 1,
  footprintX         = 4,
  footprintZ         = 4,
  highTrajectory     = 1,
  idleAutoHeal       = 5,
  idleTime           = 1800,
  leaveTracks        = true,
  maneuverleashlength = 640,
  maxDamage          = 2045,
  maxSlope           = 14,
  maxVelocity        = 1.452,
  maxWaterDepth      = 15,
  metalStorage       = 0,
  mobilestandorders  = 1,
  movementClass      = [[HTANK4]],
  name               = [[Tremor]],
  noAutoFire         = false,
  noChaseCategory    = [[VTOL]],
  objectName         = [[TREM]],
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[CORE]],
  sightDistance      = 351,
  smoothAnim         = true,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[TANK]],
  trackOffset        = -8,
  trackStrength      = 8,
  trackStretch       = 1,
  trackType          = [[StdTank]],
  trackWidth         = 28,
  turnRate           = 169.4,
  unitname           = [[trem]],
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
      def                = [[TREM1]],
      mainDir            = [[0 0 1]],
      maxAngleDif        = 270,
      onlyTargetCategory = [[NOTAIR]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  TREM1 = {
    accuracy           = 1400,
    areaOfEffect       = 160,
    ballistic          = true,
    craterBoost        = 0,
    craterMult         = 0,
    explosionGenerator = [[custom:FLASH4]],
    gravityaffected    = [[true]],
    impulseBoost       = 0.123,
    impulseFactor      = 0.123,
    minbarrelangle     = -35,
    name               = [[RapidArtillery]],
    noSelfDamage       = true,
    proximityPriority  = -3,
    range              = 1275,
    reloadtime         = 0.4,
    renderType         = 4,
    soundHit           = [[xplomed4]],
    soundStart         = [[cannhvy2]],
    turret             = true,
    weaponType         = [[Cannon]],
    weaponVelocity     = 414.87948608398,
    damage = {
      default            = 295,
      gunships           = 19,
      hgunships          = 19,
      l1bombers          = 19,
      l1fighters         = 19,
      l1subs             = 5,
      l2bombers          = 19,
      l2fighters         = 19,
      l2subs             = 5,
      l3subs             = 5,
      vradar             = 19,
      vtol               = 19,
      vtrans             = 19,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 1827,
    description        = [[Tremor Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 8,
    hitdensity         = 100,
    metal              = 1118,
    object             = [[TREM_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 914,
    description        = [[Tremor Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 2,
    hitdensity         = 100,
    metal              = 527,
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
