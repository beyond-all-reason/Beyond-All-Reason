-- UNITDEF -- CORHUNT --
--------------------------------------------------------------------------------

local unitName = "corhunt"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.06,
  altfromsealevel    = 1,
  amphibious         = 1,
  bankscale          = 1,
  bmcode             = 1,
  brakeRate          = 3.75,
  buildCostEnergy    = 6421,
  buildCostMetal     = 122,
  builder            = false,
  buildPic           = [[CORHUNT.DDS]],
  buildTime          = 9512,
  canFly             = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  canSubmerge        = true,
  category           = [[ALL ANTIEMG NOTLAND MOBILE ANTIGATOR NOTSUB ANTIFLAME ANTILASER VTOL NOWEAPON NOTSHIP]],
  collide            = false,
  cruiseAlt          = 190,
  defaultmissiontype = [[VTOL_standby]],
  description        = [[Advanced Radar/Sonar Plane]],
  energyMake         = 15,
  energyStorage      = 0,
  energyUse          = 15,
  explodeAs          = [[BIG_UNITEX]],
  firestandorders    = 1,
  footprintX         = 3,
  footprintZ         = 3,
  iconType           = [[air]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 1280,
  maxDamage          = 660,
  maxSlope           = 10,
  maxVelocity        = 10.81,
  maxWaterDepth      = 255,
  metalStorage       = 0,
  mobilestandorders  = 1,
  moverate1          = 8,
  name               = [[Hunter]],
  noAutoFire         = false,
  objectName         = [[CORHUNT]],
  radarDistance      = 2200,
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[CORE]],
  sightDistance      = 1130,
  smoothAnim         = false,
  sonarDistance      = 900,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[VTOL]],
  turnRate           = 450,
  unitname           = [[corhunt]],
  workerTime         = 0,
  sounds = {
    build              = [[nanlath1]],
    canceldestruct     = [[cancel2]],
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
      [[vtolcrmv]],
    },
    select = {
      [[seasonr2]],
    },
  },
}


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
