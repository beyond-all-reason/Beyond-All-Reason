-- UNITDEF -- CORSHAD --
--------------------------------------------------------------------------------

local unitName = "corshad"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.084,
  altfromsealevel    = 1,
  attackrunlength    = 170,
  badTargetCategory  = [[MOBILE]],
  bmcode             = 1,
  brakeRate          = 1.5,
  buildCostEnergy    = 4595,
  buildCostMetal     = 146,
  builder            = false,
  buildPic           = [[CORSHAD.DDS]],
  buildTime          = 5054,
  canAttack          = true,
  canFly             = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL MOBILE WEAPON NOTLAND ANTIGATOR VTOL ANTIFLAME ANTIEMG ANTILASER NOTSUB NOTSHIP]],
  collide            = false,
  cruiseAlt          = 165,
  defaultmissiontype = [[VTOL_standby]],
  description        = [[Bomber]],
  energyMake         = 0.9,
  energyStorage      = 0,
  energyUse          = 0.9,
  explodeAs          = [[BIG_UNITEX]],
  firestandorders    = 1,
  footprintX         = 3,
  footprintZ         = 3,
  iconType           = [[air]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 1380,
  maxDamage          = 615,
  maxSlope           = 10,
  maxVelocity        = 8.05,
  maxWaterDepth      = 0,
  metalStorage       = 0,
  mobilestandorders  = 1,
  name               = [[Shadow]],
  noAutoFire         = true,
  noChaseCategory    = [[VTOL]],
  objectName         = [[CORSHAD]],
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[CORE]],
  sightDistance      = 169,
  smoothAnim         = true,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[VTOL]],
  turnRate           = 807,
  unitname           = [[corshad]],
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
      badTargetCategory  = [[MOBILE]],
      def                = [[COREBOMB]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  COREBOMB = {
    accuracy           = 500,
    areaOfEffect       = 168,
    avoidFeature       = false,
    burst              = 5,
    burstrate          = 0.28,
    collideFriendly    = false,
    commandfire        = true,
    craterBoost        = 0,
    craterMult         = 0,
    dropped            = true,
    edgeEffectiveness  = 0.25,
    explosionGenerator = [[custom:T1COREBOMB]],
    gravityaffected    = [[true]],
    impulseBoost       = 0.3,
    impulseFactor      = 0.3,
    manualBombSettings = true,
    model              = [[bomb]],
    name               = [[Bombs]],
    noSelfDamage       = true,
    range              = 1280,
    reloadtime         = 9,
    renderType         = 6,
    soundHit           = [[xplomed2]],
    soundStart         = [[bombrel]],
    sprayAngle         = 300,
    weaponType         = [[AircraftBomb]],
    damage = {
      antibomber         = 75,
      default            = 150,
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
