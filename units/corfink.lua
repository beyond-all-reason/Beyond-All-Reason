-- UNITDEF -- CORFINK --
--------------------------------------------------------------------------------

local unitName = "corfink"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.48,
  bankscale          = 1,
  bmcode             = 1,
  brakeRate          = 12.5,
  buildCostEnergy    = 1369,
  buildCostMetal     = 26,
  builder            = false,
  buildPic           = [[CORFINK.DDS]],
  buildTime          = 2156,
  canFly             = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL MOBILE NOTLAND ANTIGATOR NOTSUB ANTIFLAME ANTIEMG ANTILASER VTOL NOWEAPON NOTSHIP]],
  collide            = false,
  cruiseAlt          = 200,
  defaultmissiontype = [[VTOL_standby]],
  description        = [[Scout Plane]],
  energyMake         = 0.2,
  energyStorage      = 0,
  energyUse          = 0.2,
  explodeAs          = [[SMALL_UNITEX]],
  footprintX         = 2,
  footprintZ         = 2,
  iconType           = [[air]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 1280,
  maxDamage          = 90,
  maxSlope           = 10,
  maxVelocity        = 12.65,
  maxWaterDepth      = 0,
  metalStorage       = 0,
  mobilestandorders  = 1,
  name               = [[Fink]],
  noAutoFire         = false,
  objectName         = [[CORFINK]],
  radarDistance      = 1120,
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  selfDestructCountdown = 1,
  side               = [[CORE]],
  sightDistance      = 835,
  smoothAnim         = false,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[VTOL]],
  turnRate           = 770,
  unitname           = [[corfink]],
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
}


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
