-- UNITDEF -- ARMRECL --
--------------------------------------------------------------------------------

local unitName = "armrecl"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.048,
  bmcode             = 1,
  brakeRate          = 0.25,
  buildCostEnergy    = 6911,
  buildCostMetal     = 413,
  buildDistance      = 128,
  builder            = true,
  buildPic           = [[ARMRECL.DDS]],
  buildTime          = 9259,
  canAssist          = false,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canreclamate       = 1,
  canResurrect       = true,
  canstop            = 1,
  category           = [[ALL UNDERWATER CONSTR NOWEAPON NOTAIR]],
  collisionVolumeType = [[Ell]],
  collisionVolumeScales = [[49 11 78]],
  collisionVolumeOffsets = [[0 0 2]],
  collisionVolumeTest = 1,
  defaultmissiontype = [[Standby]],
  description        = [[Ressurection Sub]],
  energyMake         = 2,
  energyStorage      = 0,
  energyUse          = 2,
  explodeAs          = [[SMALL_UNITEX]],
  footprintX         = 3,
  footprintZ         = 3,
  iconType           = [[sea]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 640,
  maxDamage          = 670,
  maxVelocity        = 2.36,
  metalStorage       = 0,
  minWaterDepth      = 20,
  mobilestandorders  = 1,
  movementClass      = [[UBOAT3]],
  name               = [[Grim Reaper]],
  noAutoFire         = false,
  objectName         = [[ARMRECL]],
  resurrect          = 1,
  seismicSignature   = 0,
  selfDestructAs     = [[SMALL_UNIT]],
  side               = [[ARM]],
  sightDistance      = 156,
  smoothAnim         = true,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[SHIP]],
  turnRate           = 282,
  unitname           = [[armrecl]],
  waterline          = 30,
  workerTime         = 450,
  sounds = {
    build              = [[nanlath1]],
    canceldestruct     = [[cancel2]],
    capture            = [[capture1]],
    repair             = [[repair1]],
    underattack        = [[warning1]],
    working            = [[reclaim1]],
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
      [[sucormov]],
    },
    select = {
      [[sucorsel]],
    },
  },
}


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
