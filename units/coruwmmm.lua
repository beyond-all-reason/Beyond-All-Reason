-- UNITDEF -- CORUWMMM --
--------------------------------------------------------------------------------

local unitName = "coruwmmm"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0,
  activateWhenBuilt  = true,
  bmcode             = 0,
  brakeRate          = 0,
  buildAngle         = 8192,
  buildCostEnergy    = 23551,
  buildCostMetal     = 373,
  builder            = false,
  buildingGroundDecalDecaySpeed = 30,
  buildingGroundDecalSizeX = 8,
  buildingGroundDecalSizeY = 8,
  buildingGroundDecalType = [[coruwmmm_aoplane.dds]],
  buildPic           = [[CORUWMMM.DDS]],
  buildTime          = 44623,
  category           = [[ALL NOTLAND NOTSUB NOWEAPON NOTSHIP NOTAIR]],
  corpse             = [[DEAD]],
  damageModifier     = 0.275,
  description        = [[Converts Energy to Metal]],
  energyStorage      = 0,
  energyUse          = 600,
  explodeAs          = [[ATOMIC_BLASTSML]],
  footprintX         = 5,
  footprintZ         = 5,
  iconType           = [[building]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  makesMetal         = 13,
  maxDamage          = 500,
  maxSlope           = 16,
  maxVelocity        = 0,
  metalStorage       = 0,
  minWaterDepth      = 15,
  name               = [[Underwater Moho Metal Maker]],
  noAutoFire         = false,
  objectName         = [[CORUWMMM]],
  onoffable          = true,
  seismicSignature   = 0,
  selfDestructAs     = [[ATOMIC_BLAST]],
  side               = [[CORE]],
  sightDistance      = 143,
  smoothAnim         = true,
  TEDClass           = [[METAL]],
  turnRate           = 0,
  unitname           = [[coruwmmm]],
  useBuildingGroundDecal = true,
  workerTime         = 0,
  yardMap            = [[ooooooooooooooooooooooooo]],
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

local featureDefs = {
  DEAD = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 300,
    description        = [[Underwater Moho Metal Maker Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 5,
    footprintZ         = 5,
    height             = 20,
    hitdensity         = 100,
    metal              = 242,
    object             = [[CORUWMMM_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 150,
    description        = [[Underwater Moho Metal Maker Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 5,
    footprintZ         = 5,
    height             = 4,
    hitdensity         = 100,
    metal              = 97,
    object             = [[5X5A]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
