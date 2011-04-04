-- UNITDEF -- CORCSA --
--------------------------------------------------------------------------------

local unitName = "corcsa"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.072,
  amphibious         = 1,
  bankscale          = 1.5,
  bmcode             = 1,
  brakeRate          = 1.875,
  buildCostEnergy    = 7047,
  buildCostMetal     = 156,
  buildDistance      = 128,
  builder            = true,
  buildPic           = [[CORCSA.DDS]],
  buildTime          = 14904,
  canFly             = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canreclamate       = 1,
  canstop            = 1,
  canSubmerge        = true,
  category           = [[ALL NOTLAND MOBILE ANTIGATOR NOTSUB ANTIFLAME ANTIEMG ANTILASER VTOL NOWEAPON NOTSHIP]],
  collide            = false,
  cruiseAlt          = 75,
  defaultmissiontype = [[VTOL_Standby]],
  description        = [[Tech Level 2]],
  energyMake         = 20,
  energyStorage      = 75,
  energyUse          = 20,
  explodeAs          = [[CA_EX]],
  footprintX         = 2,
  footprintZ         = 2,
  iconType           = [[air]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 1280,
  maxDamage          = 140,
  maxSlope           = 10,
  maxVelocity        = 8.51,
  maxWaterDepth      = 255,
  metalMake          = 0.2,
  metalStorage       = 75,
  mobilestandorders  = 1,
  name               = [[Construction Seaplane]],
  noAutoFire         = false,
  objectName         = [[CORCSA]],
  radarDistance      = 50,
  scale              = 0.8,
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[core]],
  sightDistance      = 351,
  smoothAnim         = true,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[VTOL]],
  terraformSpeed     = 180,
  turnRate           = 132,
  unitname           = [[corcsa]],
  workerTime         = 60,
  buildoptions = {
    [[coruwfus]],
    [[coruwmme]],
    [[coruwmmm]],
    [[corfatf]],
    [[corap]],
    [[coraap]],
    [[corplat]],
    [[corsy]],
    [[corasy]],
    [[corason]],
    [[corenaa]],
    [[coratl]],
    [[corfmine3]],
    [[coruwadves]],
    [[coruwadvms]],
  },
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
      [[seapsel2]],
    },
  },
}


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
