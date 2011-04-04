-- UNITDEF -- ARMHAWK --
--------------------------------------------------------------------------------

local unitName = "armhawk"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.48,
  airSightDistance   = 600,
  badTargetCategory  = [[NOTAIR]],
  bankscale          = 1,
  bmcode             = 1,
  brakeRate          = 11.25,
  buildCostEnergy    = 4593,
  buildCostMetal     = 114,
  buildPic           = [[ARMHAWK.DDS]],
  buildTime          = 7685,
  canAttack          = true,
  canFly             = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL NOTLAND MOBILE WEAPON ANTIGATOR NOTSUB ANTIFLAME ANTIEMG ANTILASER VTOL NOTSHIP]],
  collide            = false,
  cruiseAlt          = 160,
  defaultmissiontype = [[VTOL_standby]],
  description        = [[Stealth Fighter]],
  energyMake         = 20,
  energyUse          = 20,
  explodeAs          = [[BIG_UNITEX]],
  firestandorders    = 1,
  footprintX         = 2,
  footprintZ         = 2,
  iconType           = [[air]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 1280,
  maxDamage          = 335,
  maxSlope           = 10,
  maxVelocity        = 11.96,
  maxWaterDepth      = 0,
  mobilestandorders  = 1,
  moverate1          = 8,
  name               = [[Hawk]],
  noChaseCategory    = [[NOTAIR]],
  objectName         = [[ARMHAWK]],
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[ARM]],
  sightDistance      = 300,
  smoothAnim         = true,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  stealth            = true,
  steeringmode       = 1,
  TEDClass           = [[VTOL]],
  turnRate           = 1425,
  unitname           = [[armhawk]],
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
      [[vtolarmv]],
    },
    select = {
      [[vtolarac]],
    },
  },
  weapons = {
    [1]  = {
      badTargetCategory  = [[NOTAIR]],
      def                = [[ARMVTOL_ADVMISSILE]],
    },
    [2]  = {
      def                = [[ARMVTOL_ADVMISSILE]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  ARMVTOL_ADVMISSILE = {
    areaOfEffect       = 8,
    collideFriendly    = false,
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
    range              = 562,
    reloadtime         = 0.85,
    renderType         = 1,
    selfprop           = true,
    smokedelay         = 0.1,
    smokeTrail         = true,
    soundHit           = [[xplosml2]],
    soundStart         = [[Rocklit3]],
    startsmoke         = 1,
    startVelocity      = 650,
    texture2           = [[armsmoketrail]],
    tolerance          = 8000,
    tracks             = true,
    turnRate           = 36000,
    weaponAcceleration = 250,
    weaponTimer        = 7,
    weaponType         = [[MissileLauncher]],
    weaponVelocity     = 850,
    damage = {
      commanders         = 5,
      default            = 15,
      gunships           = 150,
      hgunships          = 150,
      l1bombers          = 350,
      l1fighters         = 160,
      l1subs             = 3,
      l2bombers          = 450,
      l2fighters         = 110,
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
