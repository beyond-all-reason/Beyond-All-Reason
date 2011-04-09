-- UNITDEF -- ARMVULC --
--------------------------------------------------------------------------------

local unitName = "armvulc"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0,
  antiweapons        = 1,
  badTargetCategory  = [[MOBILE]],
  bmcode             = 0,
  brakeRate          = 0,
  buildAngle         = 29096,
  buildCostEnergy    = 503644,
  buildCostMetal     = 33890,
  builder            = false,
  buildingGroundDecalDecaySpeed = 30,
  buildingGroundDecalSizeX = 11,
  buildingGroundDecalSizeY = 11,
  buildingGroundDecalType = [[armvulc_aoplane.dds]],
  buildPic           = [[ARMVULC.DDS]],
  buildTime          = 672961,
  canAttack          = true,
  canstop            = 1,
  category           = [[ALL NOTLAND WEAPON NOTSUB NOTSHIP NOTAIR]],
  corpse             = [[DEAD]],
  defaultmissiontype = [[GUARD_NOMOVE]],
  description        = [[Rapid-Fire Long-Range Plasma Cannon]],
  energyMake         = 0,
  energyStorage      = 0,
  energyUse          = 0,
  explodeAs          = [[ATOMIC_BLAST]],
  firestandorders    = 1,
  footprintX         = 8,
  footprintZ         = 8,
  iconType           = [[building]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maxDamage          = 34440,
  maxSlope           = 13,
  maxVelocity        = 0,
  maxWaterDepth      = 0,
  metalStorage       = 0,
  name               = [[Vulcan]],
  objectName         = [[ARMVULC]],
  seismicSignature   = 0,
  selfDestructAs     = [[ATOMIC_BLAST]],
  side               = [[ARM]],
  sightDistance      = 273,
  smoothAnim         = false,
  standingfireorder  = 1,
  TEDClass           = [[FORT]],
  turnRate           = 0,
  unitname           = [[armvulc]],
  useBuildingGroundDecal = true,
  workerTime         = 0,
  yardMap            = [[oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo]],
  sfxtypes = {
    explosiongenerators = {
      [[custom:vulcanflare]],
    },
  },
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
      [[servlrg3]],
    },
    select = {
      [[servlrg3]],
    },
  },
  weapons = {
    [1]  = {
      badTargetCategory  = [[MOBILE]],
      def                = [[ARMVULC_WEAPON]],
      onlyTargetCategory = [[NOTAIR]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  ARMVULC_WEAPON = {
    accuracy           = 700,
    areaOfEffect       = 224,
    ballistic          = true,
    color              = 2,
    craterBoost        = 0.25,
    craterMult         = 0.25,
    edgeEffectiveness  = 0.75,
    energypershot      = 9000,
    explosionGenerator = [[custom:FLASHBIGBUILDING]],
    gravityaffected    = [[true]],
    impulseBoost       = 0.5,
    impulseFactor      = 0.5,
    name               = [[RapidfireLRPC]],
    noSelfDamage       = true,
    randomdecay        = 11,
    range              = 5750,
    reloadtime         = 0.4,
    renderType         = 4,
    soundHit           = [[rflrpc3]],
    soundStart         = [[XPLONUK4]],
    startsmoke         = 1,
    turret             = true,
    weaponTimer        = 14,
    weaponType         = [[Cannon]],
    weaponVelocity     = 1100,
    damage = {
      blackhydra         = 2500,
      default            = 1500,
      flakboats          = 2500,
      jammerboats        = 2500,
      l1subs             = 5,
      l2subs             = 5,
      l3subs             = 5,
      otherboats         = 2500,
      seadragon          = 2500,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 20664,
    description        = [[Vulcan Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 7,
    footprintZ         = 7,
    height             = 20,
    hitdensity         = 100,
    metal              = 22029,
    object             = [[ARMVULC_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 10332,
    description        = [[Vulcan Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 7,
    footprintZ         = 7,
    height             = 4,
    hitdensity         = 100,
    metal              = 8812,
    object             = [[7X7A]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
