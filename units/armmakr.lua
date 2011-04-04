-- UNITDEF -- ARMMAKR --
--------------------------------------------------------------------------------

local unitName = "armmakr"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0,
  activateWhenBuilt  = true,
  bmcode             = 0,
  brakeRate          = 0,
  buildAngle         = 8192,
  buildCostEnergy    = 1087,
  buildCostMetal     = 1,
  builder            = false,
  buildingGroundDecalDecaySpeed = 30,
  buildingGroundDecalSizeX = 5,
  buildingGroundDecalSizeY = 5,
  buildingGroundDecalType = [[armmakr_aoplane.dds]],
  buildPic           = [[ARMMAKR.DDS]],
  buildTime          = 2605,
  category           = [[ALL NOTLAND NOTSUB NOWEAPON NOTSHIP NOTAIR]],
  collisionvolumeoffsets = [[-2 0 0]],
  collisionvolumescales = [[50 23 50]],
  collisionvolumetype = [[CylY]],
  damageModifier     = 0.3,
  description        = [[Converts Energy to Metal]],
  energyStorage      = 0,
  energyUse          = 60,
  explodeAs          = [[ARMESTOR_BUILDINGEX]],
  footprintX         = 3,
  footprintZ         = 3,
  iconType           = [[building]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  makesMetal         = 1,
  maxDamage          = 150,
  maxSlope           = 10,
  maxVelocity        = 0,
  maxWaterDepth      = 0,
  metalStorage       = 0,
  name               = [[Metal Maker]],
  noAutoFire         = false,
  objectName         = [[ARMMAKR]],
  onoffable          = true,
  seismicSignature   = 0,
  selfDestructAs     = [[ARMESTOR_BUILDING]],
  side               = [[ARM]],
  sightDistance      = 273,
  smoothAnim         = true,
  TEDClass           = [[METAL]],
  turnRate           = 0,
  unitname           = [[armmakr]],
  useBuildingGroundDecal = true,
  workerTime         = 0,
  yardMap            = [[ooooooooo]],
  sounds = {
    activate           = [[metlon1]],
    canceldestruct     = [[cancel2]],
    deactivate         = [[metloff1]],
    underattack        = [[warning1]],
    working            = [[metlrun1]],
    count = {
      [[count6]],
      [[count5]],
      [[count4]],
      [[count3]],
      [[count2]],
      [[count1]],
    },
    select = {
      [[metlon1]],
    },
  },
}


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
