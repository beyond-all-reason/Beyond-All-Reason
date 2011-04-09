-- UNITDEF -- ARMPNIX --
--------------------------------------------------------------------------------

local unitName = "armpnix"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.072,
  altfromsealevel    = 1,
  attackrunlength    = 300,
  badTargetCategory  = [[MOBILE]],
  bankscale          = 1,
  bmcode             = 1,
  brakeRate          = 5,
  buildCostEnergy    = 10624,
  buildCostMetal     = 229,
  builder            = false,
  buildPic           = [[ARMPNIX.DDS]],
  buildTime          = 22064,
  canAttack          = true,
  canFly             = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL NOTLAND MOBILE WEAPON ANTIGATOR NOTSUB ANTIFLAME ANTIEMG ANTILASER VTOL NOTSHIP]],
  collide            = false,
  cruiseAlt          = 220,
  defaultmissiontype = [[VTOL_standby]],
  description        = [[Strategic Bomber]],
  energyMake         = 1.8,
  energyUse          = 1.8,
  explodeAs          = [[BIG_UNITEX]],
  firestandorders    = 1,
  footprintX         = 3,
  footprintZ         = 3,
  iconType           = [[air]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 1380,
  maxDamage          = 1020,
  maxSlope           = 10,
  maxVelocity        = 9.37,
  maxWaterDepth      = 0,
  mobilestandorders  = 1,
  name               = [[Phoenix]],
  noAutoFire         = true,
  noChaseCategory    = [[VTOL]],
  objectName         = [[ARMPNIX]],
  scale              = 1,
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[ARM]],
  sightDistance      = 260,
  smoothAnim         = false,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[VTOL]],
  turnRate           = 402,
  unitname           = [[armpnix]],
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
      def                = [[ARMADVBOMB]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  ARMADVBOMB = {
    areaOfEffect       = 144,
    burst              = 8,
    burstrate          = 0.14,
    collideFriendly    = false,
    commandfire        = true,
    craterBoost        = 0,
    craterMult         = 0,
    dropped            = true,
    edgeEffectiveness  = 0.7,
    explosionGenerator = [[custom:ARM_BIGBOMB_EXPLOSION]],
    gravityaffected    = [[true]],
    impulseBoost       = 0.123,
    impulseFactor      = 0.123,
    manualBombSettings = true,
    model              = [[bomb]],
    name               = [[AdvancedBombs]],
    noSelfDamage       = true,
    range              = 1280,
    reloadtime         = 9,
    renderType         = 6,
    soundHit           = [[xplomed2]],
    soundStart         = [[bombrel]],
    weaponType         = [[AircraftBomb]],
    damage = {
      antibomber         = 100,
      default            = 210,
      l1bombers          = 5,
      l1subs             = 5,
      l2bombers          = 5,
      l2subs             = 5,
      l3subs             = 5,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
