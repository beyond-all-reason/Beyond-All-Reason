-- UNITDEF -- CMGEO --
--------------------------------------------------------------------------------

local unitName = "cmgeo"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0,
  activateWhenBuilt  = true,
  bmcode             = 0,
  brakeRate          = 0,
  buildAngle         = 0,
  buildCostEnergy    = 24568,
  buildCostMetal     = 1420,
  builder            = false,
  buildingGroundDecalDecaySpeed = 30,
  buildingGroundDecalSizeX = 8,
  buildingGroundDecalSizeY = 8,
  buildingGroundDecalType = [[cmgeo_aoplane.dds]],
  buildPic           = [[CMGEO.DDS]],
  buildTime          = 32078,
  category           = [[ALL NOTSUB NOWEAPON NOTAIR]],
  description        = [[Hazardous Energy Source]],
  energyMake         = 1250,
  energyStorage      = 12000,
  energyUse          = 0,
  explodeAs          = [[NUCLEAR_MISSILE]],
  footprintX         = 7,
  footprintZ         = 5,
  iconType           = [[building]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maxDamage          = 3720,
  maxSlope           = 20,
  maxVelocity        = 0,
  maxWaterDepth      = 0,
  metalStorage       = 0,
  name               = [[Moho Geothermal Powerplant]],
  noAutoFire         = false,
  objectName         = [[CMGEO]],
  seismicSignature   = 0,
  selfDestructAs     = [[NUCLEAR_MISSILE]],
  side               = [[CORE]],
  sightDistance      = 273,
  smoothAnim         = true,
  TEDClass           = [[ENERGY]],
  turnRate           = 0,
  unitname           = [[cmgeo]],
  useBuildingGroundDecal = true,
  workerTime         = 0,
  yardMap            = [[ooooooo ooooooo oGGoooo oGGoooo ooooooo]],
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
      [[geothrm2]],
    },
  },
}


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
