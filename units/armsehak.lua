-- UNITDEF -- ARMSEHAK --
--------------------------------------------------------------------------------

local unitName = "armsehak"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.072,
  altfromsealevel    = 1,
  amphibious         = 1,
  attackrunlength    = 120,
  bankscale          = 1,
  bmcode             = 1,
  brakeRate          = 5,
  buildCostEnergy    = 6624,
  buildCostMetal     = 119,
  builder            = false,
  buildPic           = [[ARMSEHAK.DDS]],
  buildTime          = 9064,
  canFly             = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  canSubmerge        = true,
  category           = [[ALL ANTIEMG NOTLAND MOBILE NOTSUB ANTIFLAME ANTIGATOR ANTILASER VTOL NOWEAPON NOTSHIP]],
  collide            = false,
  cruiseAlt          = 220,
  defaultmissiontype = [[VTOL_standby]],
  description        = [[Advanced Radar/Sonar Plane]],
  energyMake         = 12,
  energyStorage      = 0,
  energyUse          = 12,
  explodeAs          = [[BIG_UNITEX]],
  firestandorders    = 1,
  footprintX         = 3,
  footprintZ         = 3,
  iconType           = [[air]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 1280,
  maxDamage          = 520,
  maxSlope           = 10,
  maxVelocity        = 11.27,
  maxWaterDepth      = 255,
  metalStorage       = 0,
  mobilestandorders  = 1,
  name               = [[Seahawk]],
  noAutoFire         = false,
  objectName         = [[ARMSEHAK]],
  radarDistance      = 2250,
  scale              = 1,
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[ARM]],
  sightDistance      = 1100,
  smoothAnim         = false,
  sonarDistance      = 900,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[VTOL]],
  turnRate           = 402,
  unitname           = [[armsehak]],
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
      [[vtolarmv]],
    },
    select = {
      [[seasonr2]],
    },
  },
}


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
