-- UNITDEF -- ARMGMM --
--------------------------------------------------------------------------------

local unitName = "armgmm"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0,
  activateWhenBuilt  = true,
  bmcode             = 0,
  brakeRate          = 0,
  buildAngle         = 16384,
  buildCostEnergy    = 24230,
  buildCostMetal     = 1058,
  builder            = false,
  buildingGroundDecalDecaySpeed = 30,
  buildingGroundDecalSizeX = 8,
  buildingGroundDecalSizeY = 8,
  buildingGroundDecalType = [[armgmm_aoplane.dds]],
  buildPic           = [[ARMGMM.DDS]],
  buildTime          = 41347,
  category           = [[ALL NOTLAND NOTSUB NOWEAPON NOTSHIP NOTAIR]],
  description        = [[Safe Geothermal Powerplant]],
  digger             = 1,
  energyMake         = 750,
  energyStorage      = 1500,
  explodeAs          = [[BIG_BUILDINGEX]],
  footprintX         = 5,
  footprintZ         = 5,
  iconType           = [[building]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maxDamage          = 12500,
  maxSlope           = 10,
  maxVelocity        = 0,
  maxWaterDepth      = 0,
  name               = [[Prude]],
  noAutoFire         = false,
  objectName         = [[ARMGMM]],
  seismicSignature   = 0,
  selfDestructAs     = [[LARGE_BUILDING]],
  side               = [[ARM]],
  sightDistance      = 273,
  smoothAnim         = true,
  TEDClass           = [[METAL]],
  turnRate           = 0,
  unitname           = [[armgmm]],
  useBuildingGroundDecal = true,
  workerTime         = 0,
  yardMap            = [[ooooo ooooo ooGoo ooooo ooooo]],
  sounds = {
    canceldestruct     = [[cancel2]],
    underattack        = [[warning1]],
    count = {
      [[count6]],
      [[count5]],
      [[count4]],
      [[count3]],
      [[count2]],
      [[count1]],
    },
    select = {
      [[geothrm1]],
    },
  },
}


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
