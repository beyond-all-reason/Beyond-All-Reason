-- UNITDEF -- ARMSL --
--------------------------------------------------------------------------------

local unitName = "armsl"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.15,
  bankscale          = 1,
  bmcode             = 1,
  brakeRate          = 5,
  buildCostEnergy    = 6091,
  buildCostMetal     = 344,
  builder            = false,
  buildPic           = [[ARMSL.DDS]],
  buildTime          = 15289,
  canFly             = true,
  canGuard           = true,
  canload            = 1,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL TPORT NOTSUB VTOL NOWEAPON]],
  collide            = false,
  cruiseAlt          = 150,
  defaultmissiontype = [[VTOL_standby]],
  description        = [[Assault Transport]],
  energyMake         = 3,
  energyStorage      = 0,
  energyUse          = 16,
  explodeAs          = [[BIG_UNITEX]],
  firestandorders    = 0,
  footprintX         = 4,
  footprintZ         = 4,
  iconType           = [[air]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 1280,
  maxDamage          = 1800,
  maxSlope           = 10,
  maxVelocity        = 7,
  maxWaterDepth      = 0,
  metalStorage       = 0,
  mobilestandorders  = 0,
  moverate1          = 1,
  moverate2          = 2,
  name               = [[Seahook]],
  noAutoFire         = false,
  objectName         = [[ARMSL]],
  pitchscale         = 1,
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[CORE]],
  sightDistance      = 260,
  smoothAnim         = false,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[VTOL]],
  transmaxunits      = 1,
  transportCapacity  = 30,
  transportmaxunits  = 1,
  transportSize      = 15,
  turnRate           = 380,
  unitname           = [[armsl]],
  upright            = true,
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
