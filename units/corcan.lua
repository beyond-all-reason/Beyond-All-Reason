-- UNITDEF -- CORCAN --
--------------------------------------------------------------------------------

local unitName = "corcan"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.12,
  badTargetCategory  = [[VTOL]],
  bmcode             = 1,
  brakeRate          = 0.188,
  buildCostEnergy    = 8722,
  buildCostMetal     = 522,
  builder            = false,
  buildPic           = [[CORCAN.DDS]],
  buildTime          = 11734,
  canAttack          = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[KBOT MOBILE WEAPON ALL NOTSUB NOTSHIP NOTAIR]],
  collisionvolumeoffsets = [[0.0 0.0 0.0]],
  collisionvolumescales = [[28.0 27.0 25.0]],
  collisionvolumetype = [[box]],
  corpse             = [[DEAD]],
  defaultmissiontype = [[Standby]],
  description        = [[Armored Assault Kbot]],
  energyMake         = 7.5,
  energyStorage      = 25,
  explodeAs          = [[BIG_UNITEX]],
  firestandorders    = 1,
  footprintX         = 2,
  footprintZ         = 2,
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 640,
  maxDamage          = 4350,
  maxSlope           = 14,
  maxVelocity        = 1.35,
  maxWaterDepth      = 21,
  metalStorage       = 0,
  mobilestandorders  = 1,
  movementClass      = [[KBOT2]],
  name               = [[Can]],
  noAutoFire         = false,
  noChaseCategory    = [[VTOL]],
  objectName         = [[CORCAN]],
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[CORE]],
  sightDistance      = 350,
  smoothAnim         = true,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 2,
  TEDClass           = [[KBOT]],
  turnRate           = 970,
  unitname           = [[corcan]],
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
      [[kbcormov]],
    },
    select = {
      [[kbcorsel]],
    },
  },
  weapons = {
    [1]  = {
      badTargetCategory  = [[VTOL]],
      def                = [[CORE_CANLASER]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  CORE_CANLASER = {
    areaOfEffect       = 8,
    beamlaser          = 1,
    beamTime           = 0.15,
    coreThickness      = 0.2,
    craterBoost        = 0,
    craterMult         = 0,
    energypershot      = 75,
    explosionGenerator = [[custom:SMALL_GREEN_LASER_BURN]],
    fireStarter        = 90,
    impactonly         = 1,
    impulseBoost       = 0.123,
    impulseFactor      = 0.123,
    laserFlareSize     = 10,
    lineOfSight        = true,
    name               = [[HighEnergyLaser]],
    noSelfDamage       = true,
    range              = 275,
    reloadtime         = 0.8,
    renderType         = 0,
    rgbColor           = [[0 1 0]],
    soundHit           = [[lasrhit1]],
    soundStart         = [[lasrhvy3]],
    targetMoveError    = 0.2,
    thickness          = 3,
    tolerance          = 10000,
    turret             = true,
    weaponType         = [[BeamLaser]],
    weaponVelocity     = 700,
    damage = {
      default            = 275,
      gunships           = 55,
      hgunships          = 55,
      l1bombers          = 55,
      l1fighters         = 55,
      l1subs             = 5,
      l2bombers          = 55,
      l2fighters         = 55,
      l2subs             = 5,
      l3subs             = 5,
      vradar             = 55,
      vtol               = 55,
      vtrans             = 55,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 2310,
    description        = [[Can Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 20,
    hitdensity         = 100,
    metal              = 339,
    object             = [[CORCAN_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 1155,
    description        = [[Can Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 4,
    hitdensity         = 100,
    metal              = 136,
    object             = [[2X2F]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
