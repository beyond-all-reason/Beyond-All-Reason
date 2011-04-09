-- UNITDEF -- ARMATLAS --
--------------------------------------------------------------------------------

local unitName = "armatlas"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.09,
  bankscale          = 1,
  bmcode             = 1,
  brakeRate          = 7.5,
  buildCostEnergy    = 1239,
  buildCostMetal     = 64,
  builder            = false,
  buildPic           = [[ARMATLAS.DDS]],
  buildTime          = 3850,
  canFly             = true,
  canGuard           = true,
  canload            = 1,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL MOBILE WEAPON NOTLAND ANTIGATOR NOTSUB ANTIFLAME ANTIEMG ANTILASER VTOL NOTSHIP]],
  collide            = false,
  cruiseAlt          = 70,
  defaultmissiontype = [[VTOL_standby]],
  description        = [[Air Transport]],
  energyMake         = 0.6,
  energyStorage      = 0,
  energyUse          = 0.6,
  explodeAs          = [[SMALL_UNITEX]],
  firestandorders    = 0,
  footprintX         = 2,
  footprintZ         = 3,
  iconType           = [[air]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 1280,
  maxDamage          = 240,
  maxSlope           = 10,
  maxVelocity        = 8.25,
  maxWaterDepth      = 0,
  metalStorage       = 0,
  mobilestandorders  = 0,
  name               = [[Atlas]],
  noAutoFire         = false,
  objectName         = [[ARMATLAS]],
  releaseHeld        = true,
  scale              = 0.8,
  seismicSignature   = 0,
  selfDestructAs     = [[SMALL_UNIT]],
  side               = [[ARM]],
  sightDistance      = 125,
  smoothAnim         = false,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[VTOL]],
  transmaxunits      = 1,
  transportCapacity  = 1,
  transportSize      = 3,
  turnRate           = 550,
  unitname           = [[armatlas]],
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
