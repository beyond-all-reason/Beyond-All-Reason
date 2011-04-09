-- UNITDEF -- CORMAKR --
--------------------------------------------------------------------------------

local unitName = "cormakr"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0,
  activateWhenBuilt  = true,
  bmcode             = 0,
  brakeRate          = 0,
  buildAngle         = 8192,
  buildCostEnergy    = 1156,
  buildCostMetal     = 1,
  builder            = false,
  buildingGroundDecalDecaySpeed = 30,
  buildingGroundDecalSizeX = 5,
  buildingGroundDecalSizeY = 5,
  buildingGroundDecalType = [[cormakr_aoplane.dds]],
  buildPic           = [[CORMAKR.DDS]],
  buildTime          = 2682,
  category           = [[ALL NOTLAND NOTSUB NOWEAPON NOTSHIP NOTAIR]],
  collisionvolumeoffsets = [[0 -1 0]],
  collisionvolumescales = [[46 22 35]],
  collisionvolumetest = 1,
  collisionvolumetype = [[Box]],
  description        = [[Converts upto 60 energy/second into metal]],
  energyStorage      = 0,
  explodeAs          = [[ARMESTOR_BUILDINGEX]],
  footprintX         = 4,
  footprintZ         = 3,
  iconType           = [[building]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maxDamage          = 150,
  maxSlope           = 10,
  maxVelocity        = 0,
  maxWaterDepth      = 0,
  metalStorage       = 0,
  name               = [[Energy Converter]],
  noAutoFire         = false,
  objectName         = [[CORMAKR]],
  seismicSignature   = 0,
  selfDestructAs     = [[ARMESTOR_BUILDING]],
  side               = [[CORE]],
  sightDistance      = 273,
  smoothAnim         = false,
  TEDClass           = [[METAL]],
  turnRate           = 0,
  unitname           = [[cormakr]],
  useBuildingGroundDecal = true,
  workerTime         = 0,
  yardMap            = [[oooooooooooo]],
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
