-- UNITDEF -- CORAK --
--------------------------------------------------------------------------------

local unitName = "corak"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.384,
  badTargetCategory  = [[VTOL]],
  bmcode             = 1,
  brakeRate          = 0.25,
  buildCostEnergy    = 826,
  buildCostMetal     = 34,
  builder            = false,
  buildPic           = [[CORAK.DDS]],
  buildTime          = 1279,
  canAttack          = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[KBOT MOBILE WEAPON ALL NOTSUB NOTSHIP NOTAIR]],
  corpse             = [[DEAD]],
  defaultmissiontype = [[Standby]],
  description        = [[Infantry Kbot]],
  energyMake         = 0.3,
  energyStorage      = 0,
  energyUse          = 0.3,
  explodeAs          = [[SMALL_UNITEX]],
  firestandorders    = 1,
  footprintX         = 2,
  footprintZ         = 2,
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 640,
  maxDamage          = 260,
  maxSlope           = 17,
  maxVelocity        = 2.8,
  maxWaterDepth      = 25,
  metalStorage       = 0,
  mobilestandorders  = 1,
  movementClass      = [[KBOT2]],
  name               = [[A.K.]],
  noAutoFire         = false,
  noChaseCategory    = [[VTOL]],
  objectName         = [[CORAK]],
  seismicSignature   = 0,
  selfDestructAs     = [[SMALL_UNIT]],
  side               = [[CORE]],
  sightDistance      = 500,
  smoothAnim         = true,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 2,
  TEDClass           = [[KBOT]],
  turnRate           = 1210,
  unitname           = [[corak]],
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
      [[servtny1]],
    },
    select = {
      [[servtny1]],
    },
  },
  weapons = {
    [1]  = {
      badTargetCategory  = [[VTOL]],
      def                = [[GATOR_LASER]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  GATOR_LASER = {
    areaOfEffect       = 8,
    beamlaser          = 1,
    beamTime           = 0.1,
    coreThickness      = 0.175,
    craterBoost        = 0,
    craterMult         = 0,
    energypershot      = 0,
    explosionGenerator = [[custom:SMALL_RED_BURN]],
    fireStarter        = 50,
    impactonly         = 1,
    impulseBoost       = 0.123,
    impulseFactor      = 0.123,
    laserFlareSize     = 6,
    lineOfSight        = true,
    name               = [[Laser]],
    noSelfDamage       = true,
    range              = 240,
    reloadtime         = 0.5,
    renderType         = 0,
    rgbColor           = [[1 0 0]],
    soundHit           = [[lasrhit2]],
    soundStart         = [[lasrlit3]],
    soundTrigger       = true,
    targetMoveError    = 0.15,
    thickness          = 2,
    tolerance          = 10000,
    turret             = true,
    weaponType         = [[BeamLaser]],
    weaponVelocity     = 1000,
    damage = {
      default            = 35,
      gunships           = 4,
      hgunships          = 4,
      l1bombers          = 4,
      l1fighters         = 4,
      l1subs             = 1,
      l2bombers          = 4,
      l2fighters         = 4,
      l2subs             = 1,
      l3subs             = 1,
      vradar             = 4,
      vtol               = 4,
      vtrans             = 4,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = false,
    category           = [[corpses]],
    damage             = 126,
    description        = [[A.K. Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 20,
    hitdensity         = 100,
    metal              = 22,
    object             = [[CORAK_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 63,
    description        = [[A.K. Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 4,
    hitdensity         = 100,
    metal              = 9,
    object             = [[2X2C]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
