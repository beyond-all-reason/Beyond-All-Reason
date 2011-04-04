-- UNITDEF -- CORVAMP --
--------------------------------------------------------------------------------

local unitName = "corvamp"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.492,
  airSightDistance   = 600,
  badTargetCategory  = [[NOTAIR]],
  bankscale          = 1,
  bmcode             = 1,
  brakeRate          = 8.75,
  buildCostEnergy    = 3448,
  buildCostMetal     = 98,
  buildPic           = [[CORVAMP.DDS]],
  buildTime          = 6554,
  canAttack          = true,
  canFly             = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL NOTLAND MOBILE WEAPON ANTIGATOR VTOL ANTIFLAME ANTIEMG ANTILASER NOTSUB NOTSHIP]],
  collide            = false,
  cruiseAlt          = 160,
  defaultmissiontype = [[VTOL_standby]],
  description        = [[Stealth Fighter]],
  energyMake         = 15,
  energyUse          = 15,
  explodeAs          = [[BIG_UNITEX]],
  firestandorders    = 1,
  footprintX         = 2,
  footprintZ         = 2,
  iconType           = [[air]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 1280,
  maxDamage          = 260,
  maxSlope           = 10,
  maxVelocity        = 12.65,
  maxWaterDepth      = 0,
  mobilestandorders  = 1,
  moverate1          = 8,
  name               = [[Vamp]],
  noChaseCategory    = [[NOTAIR]],
  objectName         = [[CORVAMP]],
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[CORE]],
  sightDistance      = 300,
  smoothAnim         = true,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  stealth            = true,
  steeringmode       = 1,
  TEDClass           = [[VTOL]],
  turnRate           = 1337,
  unitname           = [[corvamp]],
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
      badTargetCategory  = [[NOTAIR]],
      def                = [[CORVTOL_ADVMISSILE]],
    },
    [2]  = {
      def                = [[CORVTOL_ADVMISSILE]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  CORVTOL_ADVMISSILE = {
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
    range              = 550,
    reloadtime         = 0.5,
    renderType         = 1,
    selfprop           = true,
    smokedelay         = 0.1,
    smokeTrail         = true,
    soundHit           = [[xplosml2]],
    soundStart         = [[Rocklit3]],
    startsmoke         = 1,
    startVelocity      = 650,
    texture2           = [[coresmoketrail]],
    tolerance          = 8000,
    tracks             = true,
    turnRate           = 36000,
    weaponAcceleration = 250,
    weaponTimer        = 7,
    weaponType         = [[MissileLauncher]],
    weaponVelocity     = 850,
    damage = {
      commanders         = 5,
      default            = 12,
      gunships           = 120,
      hgunships          = 120,
      l1bombers          = 206,
      l1fighters         = 116,
      l1subs             = 3,
      l2bombers          = 265,
      l2fighters         = 86,
      l2subs             = 3,
      l3subs             = 3,
      vradar             = 80,
      vtol               = 80,
      vtrans             = 80,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
