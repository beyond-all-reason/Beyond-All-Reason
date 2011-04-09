-- UNITDEF -- CORAWAC --
--------------------------------------------------------------------------------

local unitName = "corawac"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.096,
  altfromsealevel    = 1,
  bankscale          = 1,
  bmcode             = 1,
  brakeRate          = 3.75,
  buildCostEnergy    = 7824,
  buildCostMetal     = 169,
  builder            = false,
  buildPic           = [[CORAWAC.DDS]],
  buildTime          = 13264,
  canFly             = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL ANTIEMG NOTLAND MOBILE ANTIGATOR NOTSUB ANTIFLAME ANTILASER VTOL NOWEAPON NOTSHIP]],
  collide            = false,
  cruiseAlt          = 210,
  defaultmissiontype = [[VTOL_standby]],
  description        = [[Radar/Sonar Plane]],
  energyMake         = 20,
  energyStorage      = 0,
  energyUse          = 20,
  explodeAs          = [[BIG_UNITEX]],
  footprintX         = 3,
  footprintZ         = 3,
  iconType           = [[air]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 1280,
  maxDamage          = 890,
  maxSlope           = 10,
  maxVelocity        = 10.7,
  maxWaterDepth      = 0,
  metalStorage       = 0,
  mobilestandorders  = 1,
  name               = [[Vulture]],
  noAutoFire         = false,
  objectName         = [[CORAWAC]],
  radarDistance      = 2400,
  scale              = 1,
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[CORE]],
  sightDistance      = 1250,
  smoothAnim         = false,
  sonarDistance      = 1200,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[VTOL]],
  turnRate           = 402,
  unitname           = [[corawac]],
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
      [[caradsel]],
    },
  },
}


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
