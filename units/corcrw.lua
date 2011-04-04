-- UNITDEF -- CORCRW --
--------------------------------------------------------------------------------

local unitName = "corcrw"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.154,
  activateWhenBuilt  = true,
  bankscale          = 0.5,
  bmcode             = 1,
  brakeRate          = 3.75,
  buildCostEnergy    = 68088,
  buildCostMetal     = 4758,
  builder            = false,
  buildPic           = [[CORCRW.DDS]],
  buildTime          = 84229,
  canAttack          = true,
  canFly             = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL WEAPON VTOL NOTSUB]],
  collide            = false,
  cruiseAlt          = 80,
  defaultmissiontype = [[VTOL_standby]],
  description        = [[Flying Fortress]],
  energyStorage      = 0,
  explodeAs          = [[SMALL_BUILDING]],
  firestandorders    = 1,
  footprintX         = 3,
  footprintZ         = 3,
  hoverAttack        = true,
  iconType           = [[air]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 500,
  maxDamage          = 14000,
  maxSlope           = 10,
  maxVelocity        = 3.83,
  maxWaterDepth      = 0,
  metalStorage       = 0,
  mobilestandorders  = 1,
  name               = [[Krow]],
  noAutoFire         = false,
  noChaseCategory    = [[VTOL]],
  objectName         = [[CORCRW]],
  scale              = 1,
  seismicSignature   = 0,
  selfDestructAs     = [[LARGE_BUILDING]],
  side               = [[CORE]],
  sightDistance      = 494,
  smoothAnim         = true,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[VTOL]],
  turnRate           = 297,
  unitname           = [[corcrw]],
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
      [[vtolcrmv]],
    },
    select = {
      [[vtolcrac]],
    },
  },
  weapons = {
    [1]  = {
      def                = [[KROWLASER2]],
      onlyTargetCategory = [[NOTAIR]],
    },
    [2]  = {
      def                = [[KROWLASER]],
      onlyTargetCategory = [[NOTAIR]],
    },
    [3]  = {
      def                = [[KROWLASER]],
      onlyTargetCategory = [[NOTAIR]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  KROWLASER = {
    areaOfEffect       = 8,
    beamlaser          = 1,
    beamTime           = 0.1,
    coreThickness      = 0.15,
    craterBoost        = 0,
    craterMult         = 0,
    energypershot      = 50,
    explosionGenerator = [[custom:SMALL_GREEN_LASER_BURN]],
    fireStarter        = 90,
    impulseBoost       = 0.123,
    impulseFactor      = 0.123,
    laserFlareSize     = 8,
    lineOfSight        = true,
    name               = [[HighEnergyLaser]],
    noSelfDamage       = true,
    proximityPriority  = 1,
    range              = 575,
    reloadtime         = 0.65,
    renderType         = 0,
    rgbColor           = [[0 1 0]],
    soundHit           = [[lasrhit1]],
    soundStart         = [[Lasrmas2]],
    targetMoveError    = 0.3,
    thickness          = 2.75,
    tolerance          = 10000,
    turret             = true,
    weaponType         = [[BeamLaser]],
    weaponVelocity     = 800,
    damage = {
      default            = 90,
      l1subs             = 5,
      l2subs             = 5,
      l3subs             = 5,
    },
  },
  KROWLASER2 = {
    areaOfEffect       = 32,
    beamlaser          = 1,
    beamTime           = 0.25,
    coreThickness      = 0.2,
    craterBoost        = 0,
    craterMult         = 0,
    energypershot      = 100,
    explosionGenerator = [[custom:LARGE_GREEN_LASER_BURN]],
    fireStarter        = 90,
    impulseBoost       = 0.123,
    impulseFactor      = 0.123,
    laserFlareSize     = 10,
    lineOfSight        = true,
    name               = [[HighEnergyLaser]],
    noSelfDamage       = true,
    range              = 525,
    reloadtime         = 1.3,
    renderType         = 0,
    rgbColor           = [[0 1 0]],
    soundHit           = [[lasrhit1]],
    soundStart         = [[Lasrmas2]],
    targetMoveError    = 0.15,
    thickness          = 3,
    tolerance          = 10000,
    turret             = true,
    weaponType         = [[BeamLaser]],
    weaponVelocity     = 800,
    damage = {
      default            = 250,
      l1subs             = 5,
      l2subs             = 5,
      l3subs             = 5,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
