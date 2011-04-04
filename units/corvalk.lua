-- UNITDEF -- CORVALK --
--------------------------------------------------------------------------------

local unitName = "corvalk"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.09,
  bankscale          = 1,
  bmcode             = 1,
  brakeRate          = 7.5,
  buildCostEnergy    = 1347,
  buildCostMetal     = 69,
  builder            = false,
  buildPic           = [[CORVALK.DDS]],
  buildTime          = 4122,
  canFly             = true,
  canGuard           = true,
  canload            = 1,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL MOBILE WEAPON NOTLAND ANTIGATOR VTOL ANTIFLAME ANTIEMG ANTILASER NOTSUB NOTSHIP]],
  collide            = false,
  cruiseAlt          = 70,
  defaultmissiontype = [[VTOL_standby]],
  description        = [[Air Transport]],
  energyMake         = 0.7,
  energyStorage      = 0,
  energyUse          = 0.7,
  explodeAs          = [[BIG_UNITEX]],
  firestandorders    = 0,
  footprintX         = 2,
  footprintZ         = 3,
  iconType           = [[air]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 1280,
  maxDamage          = 250,
  maxSlope           = 10,
  maxVelocity        = 8,
  maxWaterDepth      = 0,
  metalStorage       = 0,
  mobilestandorders  = 0,
  moverate1          = 1,
  moverate2          = 2,
  name               = [[Valkyrie]],
  noAutoFire         = false,
  objectName         = [[CORVALK]],
  pitchscale         = 1,
  releaseHeld        = true,
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[CORE]],
  sightDistance      = 125,
  smoothAnim         = true,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[VTOL]],
  transportCapacity  = 1,
  transportSize      = 3,
  turnRate           = 550,
  unitname           = [[corvalk]],
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
