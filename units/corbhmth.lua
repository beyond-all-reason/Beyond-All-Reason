-- UNITDEF -- CORBHMTH --
--------------------------------------------------------------------------------

local unitName = "corbhmth"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0,
  activateWhenBuilt  = true,
  badTargetCategory  = [[VTOL]],
  bmcode             = 0,
  brakeRate          = 0,
  buildAngle         = 8192,
  buildCostEnergy    = 32428,
  buildCostMetal     = 2949,
  builder            = false,
  buildingGroundDecalDecaySpeed = 30,
  buildingGroundDecalSizeX = 8,
  buildingGroundDecalSizeY = 8,
  buildingGroundDecalType = [[corbhmth_aoplane.dds]],
  buildPic           = [[CORBHMTH.DDS]],
  buildTime          = 59640,
  canAttack          = true,
  canstop            = 1,
  category           = [[ALL NOTLAND NOTSUB WEAPON NOTSHIP NOTAIR]],
  corpse             = [[dead]],
  defaultmissiontype = [[GUARD_NOMOVE]],
  description        = [[Geothermal Plasma Battery]],
  energyMake         = 450,
  energyStorage      = 500,
  explodeAs          = [[LARGE_BUILDINGEX]],
  firestandorders    = 1,
  footprintX         = 5,
  footprintZ         = 5,
  iconType           = [[building]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maxDamage          = 7500,
  maxSlope           = 10,
  maxVelocity        = 0,
  maxWaterDepth      = 0,
  metalStorage       = 0,
  name               = [[Behemoth]],
  noAutoFire         = false,
  noChaseCategory    = [[MOBILE]],
  objectName         = [[CORBHMTH]],
  onoffable          = false,
  seismicSignature   = 0,
  selfDestructAs     = [[ESTOR_BUILDING]],
  side               = [[CORE]],
  sightDistance      = 650,
  smoothAnim         = true,
  standingfireorder  = 2,
  TEDClass           = [[FORT]],
  turnRate           = 0,
  unitname           = [[corbhmth]],
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
      [[geothrm2]],
    },
  },
  weapons = {
    [1]  = {
      badTargetCategory  = [[VTOL]],
      def                = [[CORBHMTH_WEAPON]],
      onlyTargetCategory = [[NOTAIR]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  CORBHMTH_WEAPON = {
    accuracy           = 780,
    areaOfEffect       = 192,
    ballistic          = true,
    craterBoost        = 0,
    craterMult         = 0,
    edgeEffectiveness  = 0.7,
    energypershot      = 150,
    explosionGenerator = [[custom:FLASHSMALLBUILDINGEX]],
    fireStarter        = 99,
    gravityaffected    = [[true]],
    impulseBoost       = 0.123,
    impulseFactor      = 0.123,
    name               = [[PlasmaBattery]],
    noSelfDamage       = true,
    range              = 1650,
    reloadtime         = 0.5,
    renderType         = 4,
    soundHit           = [[xplolrg3]],
    soundStart         = [[xplonuk3]],
    startsmoke         = 1,
    turret             = true,
    weaponType         = [[Cannon]],
    weaponVelocity     = 620,
    damage = {
      blackhydra         = 1350,
      commanders         = 900,
      default            = 450,
      flakboats          = 1350,
      gunships           = 110,
      hgunships          = 110,
      jammerboats        = 1350,
      l1bombers          = 110,
      l1fighters         = 110,
      l1subs             = 5,
      l2bombers          = 110,
      l2fighters         = 110,
      l2subs             = 5,
      l3subs             = 5,
      otherboats         = 1350,
      seadragon          = 1350,
      vradar             = 110,
      vtol               = 110,
      vtrans             = 110,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

local featureDefs = {
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 2250,
    description        = [[Behemoth Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 5,
    footprintZ         = 5,
    height             = 4,
    hitdensity         = 100,
    metal              = 767,
    object             = [[5X5C]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  dead = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 4500,
    description        = [[Behemoth Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 5,
    footprintZ         = 5,
    height             = 20,
    hitdensity         = 100,
    metal              = 1917,
    object             = [[CORBHMTH_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
