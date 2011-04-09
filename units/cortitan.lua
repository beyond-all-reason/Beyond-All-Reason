-- UNITDEF -- CORTITAN --
--------------------------------------------------------------------------------

local unitName = "cortitan"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.18,
  badTargetCategory  = [[NOTSHIP]],
  bankscale          = 1,
  bmcode             = 1,
  brakeRate          = 7.25,
  buildCostEnergy    = 6788,
  buildCostMetal     = 318,
  builder            = false,
  buildPic           = [[CORTITAN.DDS]],
  buildTime          = 14722,
  canAttack          = true,
  canFly             = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL NOTLAND MOBILE WEAPON ANTIGATOR VTOL ANTIFLAME ANTIEMG ANTILASER NOTSUB NOTSHIP]],
  collide            = false,
  cruiseAlt          = 120,
  defaultmissiontype = [[VTOL_standby]],
  description        = [[Torpedo Bomber]],
  energyMake         = 1.5,
  energyStorage      = 0,
  energyUse          = 1.5,
  explodeAs          = [[BIG_UNITEX]],
  firestandorders    = 1,
  footprintX         = 3,
  footprintZ         = 3,
  iconType           = [[air]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 1280,
  maxDamage          = 1760,
  maxSlope           = 10,
  maxVelocity        = 10.58,
  maxWaterDepth      = 255,
  metalStorage       = 0,
  mobilestandorders  = 1,
  moverate1          = 8,
  name               = [[Titan]],
  noAutoFire         = false,
  noChaseCategory    = [[VTOL]],
  objectName         = [[CORTITAN]],
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[CORE]],
  sightDistance      = 455,
  smoothAnim         = false,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[VTOL]],
  turnRate           = 450,
  unitname           = [[cortitan]],
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
      badTargetCategory  = [[NOTSHIP]],
      def                = [[ARMAIR_TORPEDO]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  ARMAIR_TORPEDO = {
    areaOfEffect       = 16,
    avoidFriendly      = false,
    burnblow           = true,
    collideFriendly    = false,
    craterBoost        = 0,
    craterMult         = 0,
    explosionGenerator = [[custom:FLASH2]],
    guidance           = true,
    impulseBoost       = 0.123,
    impulseFactor      = 0.123,
    lineOfSight        = true,
    model              = [[torpedo]],
    name               = [[TorpedoLauncher]],
    noSelfDamage       = true,
    propeller          = 1,
    range              = 500,
    reloadtime         = 8,
    renderType         = 1,
    selfprop           = true,
    soundHit           = [[xplodep2]],
    soundStart         = [[bombrel]],
    startVelocity      = 100,
    tolerance          = 6000,
    tracks             = true,
    turnRate           = 15000,
    turret             = false,
    waterWeapon        = true,
    weaponAcceleration = 15,
    weaponTimer        = 5,
    weaponType         = [[TorpedoLauncher]],
    weaponVelocity     = 100,
    damage = {
      default            = 1500,
      krogoth            = 3000,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
