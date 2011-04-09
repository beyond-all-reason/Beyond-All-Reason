-- UNITDEF -- CORUWADVES --
--------------------------------------------------------------------------------

local unitName = "coruwadves"

--------------------------------------------------------------------------------

local unitDef = {
  bmcode             = 0,
  buildAngle         = 7822,
  buildCostEnergy    = 10032,
  buildCostMetal     = 790,
  builder            = false,
  buildingGroundDecalDecaySpeed = 30,
  buildingGroundDecalSizeX = 8,
  buildingGroundDecalSizeY = 8,
  buildingGroundDecalType = [[coruwadves_aoplane.dds]],
  buildPic           = [[CORUWADVES.DDS]],
  buildTime          = 20416,
  category           = [[ALL NOTSUB NOWEAPON NOTAIR]],
  corpse             = [[DEAD]],
  description        = [[Increases Energy Storage (40000)]],
  designation        = [[CP-CAES]],
  downloadable       = 1,
  energyStorage      = 40000,
  energyUse          = 0,
  explodeAs          = [[ATOMIC_BLAST]],
  footprintX         = 5,
  footprintZ         = 5,
  iconType           = [[building]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maxDamage          = 11400,
  maxSlope           = 20,
  maxWaterDepth      = 9999,
  metalStorage       = 0,
  name               = [[Hardened Energy Storage]],
  noAutoFire         = false,
  noshadow           = 1,
  objectName         = [[CORUWADVES]],
  seismicSignature   = 0,
  selfDestructAs     = [[MINE_NUKE]],
  side               = [[CORE]],
  sightDistance      = 192,
  smoothAnim         = false,
  TEDClass           = [[ENERGY]],
  threed             = 1,
  unitname           = [[coruwadves]],
  useBuildingGroundDecal = true,
  version            = 1.2,
  workerTime         = 0,
  yardMap            = [[ooooooooooooooooooooooooo]],
  zbuffer            = 1,
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
      [[storngy2]],
    },
  },
}


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 4560,
    description        = [[Advanced Energy Storage Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 5,
    footprintZ         = 5,
    height             = 9,
    hitdensity         = 100,
    metal              = 514,
    object             = [[CORUWADVES_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[all]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 2280,
    description        = [[Advanced Energy Storage Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 5,
    footprintZ         = 5,
    hitdensity         = 100,
    metal              = 206,
    object             = [[5X5A]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[all]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
