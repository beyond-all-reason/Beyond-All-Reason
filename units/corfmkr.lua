-- UNITDEF -- CORFMKR --
--------------------------------------------------------------------------------

local unitName = "corfmkr"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0,
  activateWhenBuilt  = true,
  bmcode             = 0,
  brakeRate          = 0,
  buildAngle         = 8192,
  buildCostEnergy    = 2530,
  buildCostMetal     = 1,
  builder            = false,
  buildPic           = [[CORFMKR.DDS]],
  buildTime          = 2682,
  category           = [[ALL NOTLAND NOTSUB NOWEAPON NOTSHIP NOTAIR]],
  description        = [[Converts Energy to Metal]],
  energyStorage      = 0,
  energyUse          = 60,
  explodeAs          = [[ARMESTOR_BUILDINGEX]],
  footprintX         = 3,
  footprintZ         = 3,
  iconType           = [[building]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  makesMetal         = 1.1,
  maxDamage          = 120,
  maxSlope           = 10,
  maxVelocity        = 0,
  maxWaterDepth      = 0,
  metalStorage       = 0,
  minWaterDepth      = 11,
  name               = [[Floating Metal Maker]],
  noAutoFire         = false,
  objectName         = [[CORFMKR]],
  onoffable          = true,
  seismicSignature   = 0,
  selfDestructAs     = [[ARMESTOR_BUILDING]],
  side               = [[CORE]],
  sightDistance      = 273,
  smoothAnim         = true,
  TEDClass           = [[METAL]],
  turnRate           = 0,
  unitname           = [[corfmkr]],
  waterline          = 22,
  workerTime         = 0,
  yardMap            = [[wwwwwwwww]],
  sounds = {
    activate           = [[metlon2]],
    canceldestruct     = [[cancel2]],
    deactivate         = [[metloff2]],
    underattack        = [[warning1]],
    working            = [[metlrun2]],
    count = {
      [[count6]],
      [[count5]],
      [[count4]],
      [[count3]],
      [[count2]],
      [[count1]],
    },
    select = {
      [[metlon2]],
    },
  },
}


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
