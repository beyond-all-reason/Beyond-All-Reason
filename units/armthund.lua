-- UNITDEF -- ARMTHUND --
--------------------------------------------------------------------------------

local unitName = "armthund"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.096,
  altfromsealevel    = 1,
  attackrunlength    = 170,
  badTargetCategory  = [[MOBILE]],
  bankscale          = 1,
  bmcode             = 1,
  brakeRate          = 0.5,
  buildCostEnergy    = 4075,
  buildCostMetal     = 145,
  builder            = false,
  buildPic           = [[ARMTHUND.DDS]],
  buildTime          = 4778,
  canAttack          = true,
  canFly             = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL MOBILE WEAPON NOTLAND ANTIGATOR NOTSUB ANTIFLAME ANTIEMG ANTILASER VTOL NOTSHIP]],
  collide            = false,
  cruiseAlt          = 165,
  defaultmissiontype = [[VTOL_standby]],
  description        = [[Bomber]],
  energyMake         = 1.1,
  energyStorage      = 0,
  energyUse          = 1.1,
  explodeAs          = [[BIG_UNITEX]],
  firestandorders    = 1,
  footprintX         = 3,
  footprintZ         = 3,
  iconType           = [[air]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 1380,
  maxDamage          = 560,
  maxSlope           = 10,
  maxVelocity        = 8.4,
  maxWaterDepth      = 0,
  metalStorage       = 0,
  mobilestandorders  = 1,
  name               = [[Thunder]],
  noAutoFire         = true,
  noChaseCategory    = [[MOBILE]],
  objectName         = [[ARMTHUND]],
  scale              = 1,
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[ARM]],
  sightDistance      = 195,
  smoothAnim         = true,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[VTOL]],
  turnRate           = 829,
  unitname           = [[armthund]],
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
      [[vtolarmv]],
    },
    select = {
      [[vtolarac]],
    },
  },
  weapons = {
    [1]  = {
      badTargetCategory  = [[MOBILE]],
      def                = [[ARMBOMB]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  ARMBOMB = {
    accuracy           = 500,
    areaOfEffect       = 168,
    avoidFeature       = false,
    burst              = 5,
    burstrate          = 0.3,
    collideFriendly    = false,
    commandfire        = true,
    craterBoost        = 0,
    craterMult         = 0,
    dropped            = true,
    edgeEffectiveness  = 0.4,
    explosionGenerator = [[custom:T1ARMBOMB]],
    gravityaffected    = [[true]],
    impulseBoost       = 0.5,
    impulseFactor      = 0.5,
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
      antibomber         = 70,
      default            = 140,
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
