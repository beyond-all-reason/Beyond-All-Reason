-- UNITDEF -- CORAMPH --
--------------------------------------------------------------------------------

local unitName = "coramph"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.09,
  activateWhenBuilt  = true,
  amphibious         = 1,
  badTargetCategory  = [[VTOL]],
  bmcode             = 1,
  brakeRate          = 0.188,
  buildCostEnergy    = 8935,
  buildCostMetal     = 305,
  builder            = false,
  buildPic           = [[CORAMPH.DDS]],
  buildTime          = 9650,
  canAttack          = true,
  canDGun            = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[KBOT MOBILE WEAPON ALL NOTSHIP NOTAIR]],
  corpse             = [[HEAP]],
  defaultmissiontype = [[Standby]],
  description        = [[Amphibious Kbot]],
  energyMake         = 0.4,
  energyStorage      = 0,
  energyUse          = 0.4,
  explodeAs          = [[BIG_UNITEX]],
  firestandorders    = 1,
  footprintX         = 2,
  footprintZ         = 2,
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 640,
  maxDamage          = 2100,
  maxSlope           = 14,
  maxVelocity        = 1.85,
  metalStorage       = 0,
  mobilestandorders  = 1,
  movementClass      = [[AKBOT2]],
  name               = [[Gimp]],
  noAutoFire         = false,
  noChaseCategory    = [[VTOL]],
  objectName         = [[CORAMPH]],
  radarDistance      = 300,
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[CORE]],
  sightDistance      = 400,
  smoothAnim         = true,
  sonarDistance      = 300,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 2,
  TEDClass           = [[KBOT]],
  turnRate           = 998,
  unitname           = [[coramph]],
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
      def                = [[CORAMPH_WEAPON2]],
    },
    [3]  = {
      def                = [[CORAMPH_WEAPON1]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  CORAMPH_WEAPON1 = {
    areaOfEffect       = 16,
    avoidFriendly      = false,
    burnblow           = true,
    collideFriendly    = false,
    craterBoost        = 0,
    craterMult         = 0,
    explosionGenerator = [[custom:FLASH2]],
    impulseBoost       = 0.123,
    impulseFactor      = 0.123,
    lineOfSight        = true,
    model              = [[torpedo]],
    name               = [[Torpedo]],
    noSelfDamage       = true,
    predictBoost       = 0,
    propeller          = 1,
    range              = 400,
    reloadtime         = 8,
    renderType         = 1,
    selfprop           = true,
    soundHit           = [[xplodep2]],
    soundStart         = [[torpedo1]],
    startVelocity      = 75,
    turret             = true,
    waterWeapon        = true,
    weaponAcceleration = 5,
    weaponTimer        = 3,
    weaponType         = [[TorpedoLauncher]],
    weaponVelocity     = 100,
    damage = {
      default            = 200,
    },
  },
  CORAMPH_WEAPON2 = {
    areaOfEffect       = 12,
    beamlaser          = 1,
    beamTime           = 0.15,
    coreThickness      = 0.2,
    craterBoost        = 0,
    craterMult         = 0,
    energypershot      = 35,
    explosionGenerator = [[custom:SMALL_GREEN_LASER_BURN]],
    fireStarter        = 90,
    impactonly         = 1,
    impulseBoost       = 0.123,
    impulseFactor      = 0.123,
    laserFlareSize     = 10,
    lineOfSight        = true,
    name               = [[HighEnergyLaser]],
    noSelfDamage       = true,
    range              = 300,
    reloadtime         = 1.15,
    renderType         = 0,
    rgbColor           = [[0 1 0]],
    soundHit           = [[lasrhit1]],
    soundStart         = [[lasrhvy3]],
    targetMoveError    = 0.25,
    thickness          = 3,
    tolerance          = 10000,
    turret             = true,
    weaponType         = [[BeamLaser]],
    weaponVelocity     = 700,
    damage = {
      default            = 150,
      gunships           = 38,
      hgunships          = 38,
      l1bombers          = 38,
      l1fighters         = 38,
      l1subs             = 5,
      l2bombers          = 38,
      l2fighters         = 38,
      l2subs             = 5,
      l3subs             = 5,
      vradar             = 38,
      vtol               = 38,
      vtrans             = 38,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

local featureDefs = {
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 920,
    description        = [[Gimp Heap]],
    energy             = 0,
    footprintX         = 2,
    footprintZ         = 2,
    height             = 4,
    hitdensity         = 100,
    metal              = 114,
    object             = [[2X2D]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
