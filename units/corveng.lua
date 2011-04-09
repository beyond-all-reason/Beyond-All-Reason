-- UNITDEF -- CORVENG --
--------------------------------------------------------------------------------

local unitName = "corveng"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 2.5,
  airSightDistance   = 550,
  badTargetCategory  = [[NOTAIR]],
  bankscale          = 1,
  bmcode             = 1,
  brakeRate          = 2.5,
  buildCostEnergy    = 2636,
  buildCostMetal     = 68,
  buildPic           = [[CORVENG.DDS]],
  buildTime          = 3333,
  canAttack          = true,
  canFly             = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL MOBILE WEAPON ANTIGATOR VTOL ANTIFLAME ANTIEMG ANTILASER NOTLAND NOTSUB NOTSHIP]],
  collide            = false,
  cruiseAlt          = 110,
  defaultmissiontype = [[VTOL_standby]],
  description        = [[Fighter]],
  energyMake         = 0.08,
  energyStorage      = 0,
  energyUse          = 0.8,
  explodeAs          = [[SMALL_UNITEX]],
  firestandorders    = 1,
  footprintX         = 2,
  footprintZ         = 2,
  iconType           = [[air]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 1280,
  maxDamage          = 140,
  maxSlope           = 10,
  maxVelocity        = 9.92,
  maxWaterDepth      = 255,
  metalStorage       = 0,
  mobilestandorders  = 1,
  moverate1          = 8,
  name               = [[Avenger]],
  noAutoFire         = false,
  noChaseCategory    = [[NOTAIR]],
  objectName         = [[CORVENG]],
  seismicSignature   = 0,
  selfDestructAs     = [[SMALL_UNIT]],
  side               = [[CORE]],
  sightDistance      = 275,
  smoothAnim         = false,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[VTOL]],
  turnRate           = 839,
  unitname           = [[corveng]],
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
      def                = [[CORVTOL_MISSILE_A2A]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  CORVTOL_MISSILE_A2A = {
    areaOfEffect       = 48,
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
    range              = 502,
    reloadtime         = 0.6,
    renderType         = 1,
    selfprop           = true,
    smokedelay         = 0.1,
    smokeTrail         = true,
    soundHit           = [[xplosml2]],
    soundStart         = [[Rocklit3]],
    startsmoke         = 1,
    startVelocity      = 600,
    texture2           = [[coresmoketrail]],
    tolerance          = 8000,
    tracks             = true,
    turnRate           = 24000,
    weaponAcceleration = 150,
    weaponTimer        = 5,
    weaponType         = [[MissileLauncher]],
    weaponVelocity     = 750,
    damage = {
      commanders         = 5,
      default            = 23,
      gunships           = 90,
      hgunships          = 80,
      l1bombers          = 196,
      l1fighters         = 87,
      l1subs             = 5,
      l2bombers          = 100,
      l2fighters         = 50,
      l2subs             = 5,
      l3subs             = 5,
      vradar             = 50,
      vtol               = 50,
      vtrans             = 70,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
