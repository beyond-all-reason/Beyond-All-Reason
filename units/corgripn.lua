-- UNITDEF -- CORGRIPN --
--------------------------------------------------------------------------------

local unitName = "corgripn"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.48,
  attackrunlength    = 180,
  badTargetCategory  = [[NOWEAPON]],
  bankscale          = 1,
  bmcode             = 1,
  brakeRate          = 2.5,
  buildCostEnergy    = 16366,
  buildCostMetal     = 162,
  buildPic           = [[CORGRIPN.DDS]],
  buildTime          = 21522,
  canAttack          = true,
  canFly             = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL MOBILE WEAPON VTOL NOTSUB]],
  collide            = false,
  cruiseAlt          = 220,
  defaultmissiontype = [[VTOL_standby]],
  description        = [[EMP Bomber]],
  energyMake         = 15,
  energyUse          = 15,
  explodeAs          = [[BIG_UNIT]],
  firestandorders    = 1,
  footprintX         = 3,
  footprintZ         = 3,
  iconType           = [[air]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  immunetoparalyzer  = 1,
  maneuverleashlength = 1380,
  maxDamage          = 1300,
  maxSlope           = 15,
  maxVelocity        = 12.08,
  maxWaterDepth      = 0,
  mobilestandorders  = 1,
  name               = [[Stiletto]],
  noChaseCategory    = [[VTOL]],
  objectName         = [[CORGRIPN]],
  seismicSignature   = 0,
  selfDestructAs     = [[ESTOR_BUILDINGEX]],
  side               = [[ARM]],
  sightDistance      = 390,
  smoothAnim         = true,
  standingfireorder  = 2,
  standingmoveorder  = 2,
  stealth            = true,
  steeringmode       = 1,
  TEDClass           = [[VTOL]],
  turnRate           = 396,
  unitname           = [[corgripn]],
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
      badTargetCategory  = [[VTOL]],
      def                = [[CORGRIPN_BOMB]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  CORGRIPN_BOMB = {
    areaOfEffect       = 240,
    collideFriendly    = false,
    commandfire        = true,
    craterBoost        = 0,
    craterMult         = 0,
    dropped            = true,
    edgeEffectiveness  = 0.75,
    explosionGenerator = [[custom:EMPFLASH240]],
    fireStarter        = 90,
    gravityaffected    = [[true]],
    impulseBoost       = 0,
    impulseFactor      = 0,
    model              = [[bomb]],
    name               = [[EMPbomb]],
    noSelfDamage       = true,
    paralyzer          = true,
    paralyzeTime       = 15,
    range              = 1280,
    reloadtime         = 0.3,
    renderType         = 6,
    soundHit           = [[EMGPULS1]],
    soundStart         = [[bombrel]],
    tolerance          = 7000,
    weaponType         = [[AircraftBomb]],
    damage = {
      blackhydra         = 30,
      commanders         = 30,
      default            = 4000,
      krogoth            = 30,
      seadragon          = 30,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
