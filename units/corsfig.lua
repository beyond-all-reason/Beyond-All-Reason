-- UNITDEF -- CORSFIG --
--------------------------------------------------------------------------------

local unitName = "corsfig"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.456,
  amphibious         = 1,
  badTargetCategory  = [[NOTAIR]],
  bmcode             = 1,
  brakeRate          = 7.5,
  buildCostEnergy    = 3558,
  buildCostMetal     = 64,
  builder            = false,
  buildPic           = [[CORSFIG.DDS]],
  buildTime          = 6915,
  canAttack          = true,
  canFly             = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  canSubmerge        = true,
  category           = [[ALL NOTLAND MOBILE WEAPON ANTIGATOR VTOL ANTIFLAME ANTIEMG ANTILASER NOTSUB NOTSHIP]],
  collide            = false,
  cruiseAlt          = 70,
  defaultmissiontype = [[VTOL_standby]],
  description        = [[Seaplane Swarmer]],
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
  maxDamage          = 181,
  maxSlope           = 10,
  maxVelocity        = 10.52,
  maxWaterDepth      = 255,
  metalStorage       = 0,
  mobilestandorders  = 1,
  moverate1          = 8,
  name               = [[Voodoo]],
  noAutoFire         = false,
  noChaseCategory    = [[NOTAIR]],
  objectName         = [[CORSFIG]],
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[CORE]],
  sightDistance      = 550,
  smoothAnim         = false,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[VTOL]],
  turnRate           = 1547,
  unitname           = [[corsfig]],
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
      [[seapsel2]],
    },
  },
  weapons = {
    [1]  = {
      badTargetCategory  = [[NOTAIR]],
      def                = [[CORSFIG_WEAPON]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  CORSFIG_WEAPON = {
    areaOfEffect       = 48,
    craterBoost        = 0,
    craterMult         = 0,
    explosionGenerator = [[custom:FLASH2]],
    fireStarter        = 70,
    guidance           = true,
    impulseBoost       = 0.123,
    impulseFactor      = 0.123,
    lineOfSight        = true,
    metalpershot       = 0,
    model              = [[missile]],
    name               = [[GuidedMissiles]],
    noSelfDamage       = true,
    range              = 520,
    reloadtime         = 0.85,
    renderType         = 1,
    selfprop           = true,
    smokedelay         = 0.1,
    smokeTrail         = true,
    soundHit           = [[xplosml2]],
    soundStart         = [[Rocklit3]],
    startsmoke         = 1,
    startVelocity      = 420,
    tolerance          = 8000,
    tracks             = true,
    turnRate           = 19384,
    weaponAcceleration = 146,
    weaponTimer        = 6,
    weaponType         = [[MissileLauncher]],
    weaponVelocity     = 522,
    damage = {
      commanders         = 5,
      default            = 11,
      gunships           = 140,
      hgunships          = 190,
      l1bombers          = 200,
      l1fighters         = 110,
      l1subs             = 3,
      l2bombers          = 200,
      l2fighters         = 80,
      l2subs             = 3,
      l3subs             = 3,
      vradar             = 100,
      vtol               = 100,
      vtrans             = 100,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
