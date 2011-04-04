-- UNITDEF -- ARMSEAP --
--------------------------------------------------------------------------------

local unitName = "armseap"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.324,
  amphibious         = 1,
  attackrunlength    = 100,
  badTargetCategory  = [[NOTAIR]],
  bankscale          = 1,
  bmcode             = 1,
  brakeRate          = 5,
  buildCostEnergy    = 6619,
  buildCostMetal     = 243,
  builder            = false,
  buildPic           = [[ARMSEAP.DDS]],
  buildTime          = 13825,
  canAttack          = true,
  canFly             = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  canSubmerge        = true,
  category           = [[ALL NOTLAND MOBILE WEAPON ANTIGATOR NOTSUB ANTIFLAME ANTIEMG ANTILASER VTOL NOTSHIP]],
  collide            = false,
  cruiseAlt          = 100,
  defaultmissiontype = [[VTOL_standby]],
  description        = [[Torpedo Seaplane]],
  energyMake         = 0.7,
  energyStorage      = 0,
  energyUse          = 0.7,
  explodeAs          = [[BIG_UNITEX]],
  firestandorders    = 1,
  footprintX         = 3,
  footprintZ         = 3,
  iconType           = [[air]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 1280,
  maxDamage          = 1646,
  maxSlope           = 10,
  maxVelocity        = 9.04,
  maxWaterDepth      = 255,
  metalStorage       = 0,
  mobilestandorders  = 1,
  moverate1          = 8,
  name               = [[Albatross]],
  noAutoFire         = false,
  noChaseCategory    = [[VTOL]],
  objectName         = [[ARMSEAP]],
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[ARM]],
  sightDistance      = 455,
  smoothAnim         = true,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[VTOL]],
  turnRate           = 597,
  unitname           = [[armseap]],
  workerTime         = 0,
  sounds = {
    build              = [[nanlath1]],
    canceldestruct     = [[cancel2]],
    repair             = [[repair1]],
    underattack        = [[warning1]],
    working            = [[reclaim1]],
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
      [[seapsel1]],
    },
  },
  weapons = {
    [1]  = {
      badTargetCategory  = [[NOTSHIP]],
      def                = [[ARMSEAP_WEAPON1]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  ARMSEAP_WEAPON1 = {
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
    tolerance          = 12000,
    tracks             = true,
    turnRate           = 25000,
    turret             = false,
    waterWeapon        = true,
    weaponAcceleration = 15,
    weaponTimer        = 5,
    weaponType         = [[TorpedoLauncher]],
    weaponVelocity     = 100,
    damage = {
      default            = 960,
      krogoth            = 1750,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
