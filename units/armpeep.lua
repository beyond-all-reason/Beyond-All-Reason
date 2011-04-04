-- UNITDEF -- ARMPEEP --
--------------------------------------------------------------------------------

local unitName = "armpeep"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.6,
  bankscale          = 1,
  bmcode             = 1,
  brakeRate          = 11.25,
  buildCostEnergy    = 1475,
  buildCostMetal     = 30,
  builder            = false,
  buildPic           = [[ARMPEEP.DDS]],
  buildTime          = 2585,
  canFly             = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL MOBILE NOTLAND NOTSUB ANTIFLAME ANTIGATOR ANTIEMG ANTILASER VTOL NOWEAPON NOTSHIP]],
  collide            = false,
  cruiseAlt          = 180,
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
  maxDamage          = 80,
  maxSlope           = 10,
  maxVelocity        = 13.8,
  maxWaterDepth      = 0,
  metalStorage       = 0,
  mobilestandorders  = 1,
  name               = [[Peeper]],
  noAutoFire         = false,
  objectName         = [[ARMPEEP]],
  radarDistance      = 1140,
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  selfDestructCountdown = 1,
  side               = [[ARM]],
  sightDistance      = 865,
  smoothAnim         = true,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[VTOL]],
  turnRate           = 880,
  unitname           = [[armpeep]],
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
}


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
