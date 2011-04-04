-- UNITDEF -- COREXP --
--------------------------------------------------------------------------------

local unitName = "corexp"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0,
  activateWhenBuilt  = true,
  bmcode             = 0,
  brakeRate          = 0,
  buildAngle         = 32768,
  buildCostEnergy    = 1811,
  buildCostMetal     = 220,
  builder            = false,
  buildingGroundDecalDecaySpeed = 30,
  buildingGroundDecalSizeX = 5,
  buildingGroundDecalSizeY = 5,
  buildingGroundDecalType = [[corexp_aoplane.dds]],
  buildPic           = [[COREXP.DDS]],
  buildTime          = 2724,
  canAttack          = true,
  canstop            = 1,
  category           = [[ALL NOTLAND ANTIGATOR NOTSUB ANTIEMG NOWEAPON NOTSHIP NOTAIR]],
  corpse             = [[DEAD]],
  defaultmissiontype = [[GUARD_NOMOVE]],
  description        = [[Armed Metal Extractor]],
  energyStorage      = 0,
  energyUse          = 5,
  explodeAs          = [[MEDIUM_BUILDINGEX]],
  extractsMetal      = 0.001,
  firestandorders    = 1,
  footprintX         = 3,
  footprintZ         = 3,
  healtime           = 12,
  iconType           = [[building]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maxDamage          = 1300,
  maxSlope           = 20,
  maxVelocity        = 0,
  maxWaterDepth      = 0,
  metalStorage       = 75,
  name               = [[Exploiter]],
  noAutoFire         = false,
  noChaseCategory    = [[MOBILE]],
  objectName         = [[COREXP]],
  onoffable          = true,
  seismicSignature   = 0,
  selfDestructCountdown = 1,
  side               = [[CORE]],
  sightDistance      = 455,
  smoothAnim         = true,
  standingfireorder  = 2,
  TEDClass           = [[METAL]],
  turnRate           = 0,
  unitname           = [[corexp]],
  useBuildingGroundDecal = true,
  workerTime         = 0,
  yardMap            = [[ooooooooo]],
  sounds = {
    activate           = [[mexrun2]],
    canceldestruct     = [[cancel2]],
    deactivate         = [[mexoff2]],
    underattack        = [[warning1]],
    working            = [[mexrun2]],
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
      [[servmed2]],
    },
    select = {
      [[mexon2]],
    },
  },
  weapons = {
    [1]  = {
      badTargetCategory  = [[VTOL]],
      def                = [[HLLT_BOTTOM]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  HLLT_BOTTOM = {
    areaOfEffect       = 12,
    avoidFeature       = false,
    beamlaser          = 1,
    beamTime           = 0.12,
    coreThickness      = 0.175,
    craterBoost        = 0,
    craterMult         = 0,
    energypershot      = 15,
    explosionGenerator = [[custom:SMALL_RED_BURN]],
    fireStarter        = 100,
    impactonly         = 1,
    impulseBoost       = 0.123,
    impulseFactor      = 0.123,
    laserFlareSize     = 10,
    lineOfSight        = true,
    name               = [[LightLaser]],
    noSelfDamage       = true,
    proximityPriority  = 3,
    range              = 430,
    reloadtime         = 0.48,
    renderType         = 0,
    rgbColor           = [[1 0 0]],
    soundHit           = [[lasrhit2]],
    soundStart         = [[lasrfir3]],
    soundTrigger       = true,
    targetMoveError    = 0.1,
    thickness          = 2.5,
    tolerance          = 10000,
    turret             = true,
    weaponType         = [[BeamLaser]],
    weaponVelocity     = 2250,
    damage = {
      commanders         = 140,
      default            = 75,
      gunships           = 3,
      hgunships          = 3,
      l1bombers          = 5,
      l1fighters         = 5,
      l1subs             = 2,
      l2bombers          = 5,
      l2fighters         = 5,
      l2subs             = 2,
      l3subs             = 2,
      vradar             = 5,
      vtol               = 5,
      vtrans             = 5,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 780,
    description        = [[Exploiter Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 3,
    footprintZ         = 3,
    height             = 20,
    hitdensity         = 100,
    metal              = 122,
    object             = [[COREXP_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 390,
    description        = [[Exploiter Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 3,
    footprintZ         = 3,
    height             = 4,
    hitdensity         = 100,
    metal              = 49,
    object             = [[3X3A]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
