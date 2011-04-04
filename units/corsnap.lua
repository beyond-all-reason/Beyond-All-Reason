-- UNITDEF -- CORSNAP --
--------------------------------------------------------------------------------

local unitName = "corsnap"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.078,
  badTargetCategory  = [[VTOL]],
  bmcode             = 1,
  brakeRate          = 0.1,
  buildCostEnergy    = 3106,
  buildCostMetal     = 296,
  builder            = false,
  buildPic           = [[CORSNAP.DDS]],
  buildTime          = 3791,
  canAttack          = true,
  canGuard           = true,
  canHover           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL HOVER MOBILE WEAPON NOTSUB NOTSHIP NOTAIR]],
  corpse             = [[DEAD]],
  defaultmissiontype = [[Standby]],
  description        = [[Hovertank]],
  energyMake         = 2.1,
  energyStorage      = 0,
  energyUse          = 2.1,
  explodeAs          = [[BIG_UNITEX]],
  firestandorders    = 1,
  footprintX         = 3,
  footprintZ         = 3,
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 640,
  maxDamage          = 1462,
  maxSlope           = 16,
  maxVelocity        = 2.3,
  maxWaterDepth      = 0,
  metalStorage       = 0,
  mobilestandorders  = 1,
  movementClass      = [[HOVER3]],
  name               = [[Snapper]],
  noAutoFire         = false,
  noChaseCategory    = [[VTOL]],
  objectName         = [[CORSNAP]],
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[CORE]],
  sightDistance      = 491,
  smoothAnim         = true,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[TANK]],
  turnRate           = 500,
  unitname           = [[corsnap]],
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
      [[hovmdok2]],
    },
    select = {
      [[hovmdsl2]],
    },
  },
  weapons = {
    [1]  = {
      badTargetCategory  = [[VTOL]],
      def                = [[ARMANAC_WEAPON]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  ARMANAC_WEAPON = {
    areaOfEffect       = 32,
    ballistic          = true,
    craterBoost        = 0,
    craterMult         = 0,
    explosionGenerator = [[custom:FLASH2]],
    gravityaffected    = [[true]],
    impulseBoost       = 0.123,
    impulseFactor      = 0.123,
    name               = [[MediumPlasmaCannon]],
    noSelfDamage       = true,
    range              = 320,
    reloadtime         = 1.4,
    renderType         = 4,
    soundHit           = [[xplosml3]],
    soundStart         = [[canlite3]],
    startsmoke         = 1,
    turret             = true,
    weaponType         = [[Cannon]],
    weaponVelocity     = 260,
    damage = {
      default            = 98,
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
    damage             = 877,
    description        = [[Snapper Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    footprintX         = 3,
    footprintZ         = 3,
    height             = 20,
    hitdensity         = 100,
    metal              = 192,
    object             = [[CORSNAP_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 439,
    description        = [[Snapper Heap]],
    energy             = 0,
    footprintX         = 3,
    footprintZ         = 3,
    height             = 4,
    hitdensity         = 100,
    metal              = 77,
    object             = [[3X3D]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
