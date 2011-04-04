-- UNITDEF -- ARMUWADVES --
--------------------------------------------------------------------------------

local unitName = "armuwadves"

--------------------------------------------------------------------------------

local unitDef = {
  bmcode             = 0,
  buildAngle         = 8192,
  buildCostEnergy    = 10094,
  buildCostMetal     = 773,
  builder            = false,
  buildingGroundDecalDecaySpeed = 30,
  buildingGroundDecalSizeX = 6,
  buildingGroundDecalSizeY = 6,
  buildingGroundDecalType = [[armuwadves_aoplane.dds]],
  buildPic           = [[ARMUWADVES.DDS]],
  buildTime          = 20302,
  category           = [[ALL NOTSUB NOWEAPON NOTAIR]],
  corpse             = [[DEAD]],
  description        = [[Increases Energy Storage (40000)]],
  designation        = [[CP-AES]],
  downloadable       = 1,
  energyStorage      = 40000,
  energyUse          = 0,
  explodeAs          = [[ATOMIC_BLAST]],
  footprintX         = 4,
  footprintZ         = 4,
  iconType           = [[building]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maxDamage          = 10500,
  maxSlope           = 20,
  maxWaterDepth      = 9999,
  metalStorage       = 0,
  name               = [[Hardened Energy Storage]],
  noAutoFire         = false,
  noshadow           = 1,
  objectName         = [[ARMUWADVES]],
  seismicSignature   = 0,
  selfDestructAs     = [[MINE_NUKE]],
  side               = [[ARM]],
  sightDistance      = 169,
  smoothAnim         = true,
  TEDClass           = [[ENERGY]],
  threed             = 1,
  unitname           = [[armuwadves]],
  useBuildingGroundDecal = true,
  version            = 1.2,
  workerTime         = 0,
  yardMap            = [[oooooooooooooooo]],
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
      [[storngy1]],
    },
  },
}


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 4200,
    description        = [[Advanced Energy Storage Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 4,
    footprintZ         = 4,
    height             = 9,
    hitdensity         = 100,
    metal              = 502,
    object             = [[ARMUWADVES_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[all]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 2100,
    description        = [[Advanced Energy Storage Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 4,
    footprintZ         = 4,
    hitdensity         = 100,
    metal              = 201,
    object             = [[4X4A]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[all]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
