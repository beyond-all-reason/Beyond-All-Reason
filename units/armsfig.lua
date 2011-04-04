-- UNITDEF -- ARMSFIG --
--------------------------------------------------------------------------------

local unitName = "armsfig"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.48,
  amphibious         = 1,
  badTargetCategory  = [[NOTAIR]],
  bmcode             = 1,
  brakeRate          = 10,
  buildCostEnergy    = 4274,
  buildCostMetal     = 72,
  builder            = false,
  buildPic           = [[ARMSFIG.DDS]],
  buildTime          = 7279,
  canAttack          = true,
  canFly             = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  canSubmerge        = true,
  category           = [[ALL NOTLAND MOBILE WEAPON ANTIGATOR NOTSUB ANTIFLAME ANTIEMG ANTILASER VTOL NOTSHIP]],
  collide            = false,
  cruiseAlt          = 80,
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
  maxDamage          = 255,
  maxSlope           = 10,
  maxVelocity        = 10.36,
  maxWaterDepth      = 255,
  metalStorage       = 0,
  mobilestandorders  = 1,
  moverate1          = 8,
  name               = [[Tornado]],
  noAutoFire         = false,
  noChaseCategory    = [[NOTAIR]],
  objectName         = [[ARMSFIG]],
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[ARM]],
  sightDistance      = 550,
  smoothAnim         = true,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[VTOL]],
  turnRate           = 1625,
  unitname           = [[armsfig]],
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
      badTargetCategory  = [[NOTAIR]],
      def                = [[ARMSFIG_WEAPON]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  ARMSFIG_WEAPON = {
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
    range              = 550,
    reloadtime         = 0.85,
    renderType         = 1,
    selfprop           = true,
    smokedelay         = 0.1,
    smokeTrail         = true,
    soundHit           = [[xplosml2]],
    soundStart         = [[Rocklit3]],
    startsmoke         = 1,
    startVelocity      = 420,
    texture2           = [[armsmoketrail]],
    tolerance          = 8000,
    tracks             = true,
    turnRate           = 19384,
    weaponAcceleration = 146,
    weaponTimer        = 6,
    weaponType         = [[MissileLauncher]],
    weaponVelocity     = 522,
    damage = {
      commanders         = 5,
      default            = 12,
      gunships           = 150,
      hgunships          = 200,
      l1bombers          = 210,
      l1fighters         = 120,
      l1subs             = 3,
      l2bombers          = 210,
      l2fighters         = 90,
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
