-- UNITDEF -- CORSUMO --
--------------------------------------------------------------------------------

local unitName = "corsumo"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.048,
  bmcode             = 1,
  brakeRate          = 0.125,
  buildCostEnergy    = 33562,
  buildCostMetal     = 2020,
  builder            = false,
  buildPic           = [[CORSUMO.DDS]],
  buildTime          = 50975,
  canAttack          = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[KBOT MOBILE WEAPON ALL NOTSUB NOTSHIP NOTAIR]],
  collisionvolumeoffsets = [[0 0 -2]],
  collisionvolumescales = [[36 32 32]],
  collisionvolumetest = 1,
  collisionvolumetype = [[Box]],
  corpse             = [[DEAD]],
  defaultmissiontype = [[Standby]],
  description        = [[Heavily Armored Assault Kbot]],
  energyMake         = 17.5,
  energyStorage      = 100,
  explodeAs          = [[BIG_UNITEX]],
  firestandorders    = 1,
  footprintX         = 3,
  footprintZ         = 3,
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 640,
  maxDamage          = 14000,
  maxSlope           = 15,
  maxVelocity        = 0.75,
  maxWaterDepth      = 23,
  metalStorage       = 0,
  mobilestandorders  = 1,
  movementClass      = [[HKBOT3]],
  name               = [[Sumo]],
  noAutoFire         = false,
  noChaseCategory    = [[VTOL]],
  objectName         = [[CORSUMO]],
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[CORE]],
  sightDistance      = 510,
  smoothAnim         = true,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 2,
  TEDClass           = [[KBOT]],
  turnRate           = 320,
  unitname           = [[corsumo]],
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
      [[kbcormov]],
    },
    select = {
      [[kbcorsel]],
    },
  },
  weapons = {
    [1]  = {
      def                = [[CORSUMO_WEAPON]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  CORSUMO_WEAPON = {
    areaOfEffect       = 12,
    beamlaser          = 1,
    beamTime           = 0.15,
    coreThickness      = 0.3,
    craterBoost        = 0,
    craterMult         = 0,
    energypershot      = 75,
    explosionGenerator = [[custom:LARGE_GREEN_LASER_BURN]],
    fireStarter        = 90,
    impactonly         = 1,
    impulseBoost       = 0.123,
    impulseFactor      = 0.123,
    laserFlareSize     = 10,
    lineOfSight        = true,
    name               = [[HighEnergyLaser]],
    noSelfDamage       = true,
    range              = 650,
    reloadtime         = 0.55,
    renderType         = 0,
    rgbColor           = [[0 1 0]],
    soundHit           = [[lasrhit1]],
    soundStart         = [[lasrhvy3]],
    targetMoveError    = 0.25,
    thickness          = 3,
    tolerance          = 10000,
    turret             = true,
    weaponType         = [[BeamLaser]],
    weaponVelocity     = 800,
    damage = {
      default            = 275,
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
    blocking           = true,
    category           = [[corpses]],
    damage             = 8400,
    description        = [[Sumo Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 3,
    footprintZ         = 3,
    height             = 20,
    hitdensity         = 100,
    metal              = 1118,
    object             = [[CORSUMO_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 4200,
    description        = [[Sumo Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 3,
    footprintZ         = 3,
    height             = 4,
    hitdensity         = 100,
    metal              = 447,
    object             = [[3X3A]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
