-- UNITDEF -- ARMANNI --
--------------------------------------------------------------------------------

local unitName = "armanni"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0,
  activateWhenBuilt  = true,
  badTargetCategory  = [[VTOL]],
  bmcode             = 0,
  brakeRate          = 0,
  buildAngle         = 4096,
  buildCostEnergy    = 62563,
  buildCostMetal     = 2985,
  builder            = false,
  buildingGroundDecalDecaySpeed = 30,
  buildingGroundDecalSizeX = 6,
  buildingGroundDecalSizeY = 6,
  buildingGroundDecalType = [[armanni_aoplane.dds]],
  buildPic           = [[ARMANNI.DDS]],
  buildTime          = 52071,
  canAttack          = true,
  canstop            = 1,
  category           = [[ALL NOTLAND WEAPON NOTSUB NOTSHIP NOTAIR]],
  corpse             = [[DEAD]],
  damageModifier     = 0.25,
  defaultmissiontype = [[GUARD_NOMOVE]],
  description        = [[Tachyon Accelerator]],
  energyStorage      = 1500,
  energyUse          = 0,
  explodeAs          = [[CRAWL_BLASTSML]],
  firestandorders    = 1,
  footprintX         = 4,
  footprintZ         = 4,
  iconType           = [[building]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maxDamage          = 5500,
  maxSlope           = 10,
  maxVelocity        = 0,
  maxWaterDepth      = 0,
  metalStorage       = 0,
  name               = [[Annihilator]],
  noChaseCategory    = [[MOBILE]],
  objectName         = [[ARMANNI]],
  onoffable          = true,
  radarDistance      = 1500,
  seismicSignature   = 0,
  selfDestructAs     = [[ATOMIC_BLAST]],
  side               = [[ARM]],
  sightDistance      = 780,
  smoothAnim         = true,
  standingfireorder  = 2,
  TEDClass           = [[FORT]],
  turnRate           = 0,
  unitname           = [[armanni]],
  useBuildingGroundDecal = true,
  workerTime         = 0,
  yardMap            = [[oooooooooooooooo]],
  sounds = {
    canceldestruct     = [[cancel2]],
    underattack        = [[warning1]],
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
      [[anni]],
    },
    select = {
      [[anni]],
    },
  },
  weapons = {
    [1]  = {
      badTargetCategory  = [[VTOL]],
      def                = [[ATA]],
      onlyTargetCategory = [[NOTAIR]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  ATA = {
    areaOfEffect       = 16,
    beamlaser          = 1,
    beamTime           = 1.5,
    coreThickness      = 0.2,
    craterBoost        = 0,
    craterMult         = 0,
    energypershot      = 1500,
    explosionGenerator = [[custom:BURN_WHITE]],
    fireStarter        = 90,
    impulseBoost       = 0.123,
    impulseFactor      = 0.123,
    laserFlareSize     = 20,
    lineOfSight        = true,
    name               = [[ATA]],
    noSelfDamage       = true,
    range              = 1400,
    reloadtime         = 9.9,
    renderType         = 0,
    rgbColor           = [[0 0 1]],
    soundHit           = [[xplolrg1]],
    soundStart         = [[annigun1]],
    targetMoveError    = 0.3,
    thickness          = 7,
    tolerance          = 10000,
    turret             = true,
    weaponType         = [[BeamLaser]],
    weaponVelocity     = 1400,
    damage = {
      commanders         = 2400,
      default            = 9000,
      l1subs             = 5,
      l2subs             = 5,
      l3subs             = 5,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 1800,
    description        = [[Annihilator Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 3,
    footprintZ         = 3,
    height             = 20,
    hitdensity         = 100,
    metal              = 1940,
    object             = [[ARMANNI_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 900,
    description        = [[Annihilator Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 3,
    footprintZ         = 3,
    height             = 4,
    hitdensity         = 100,
    metal              = 776,
    object             = [[3X3B]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
