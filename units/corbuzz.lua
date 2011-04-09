-- UNITDEF -- CORBUZZ --
--------------------------------------------------------------------------------

local unitName = "corbuzz"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0,
  antiweapons        = 1,
  badTargetCategory  = [[MOBILE]],
  bmcode             = 0,
  brakeRate          = 0,
  buildAngle         = 29096,
  buildCostEnergy    = 481404,
  buildCostMetal     = 32460,
  builder            = false,
  buildingGroundDecalDecaySpeed = 30,
  buildingGroundDecalSizeX = 11,
  buildingGroundDecalSizeY = 11,
  buildingGroundDecalType = [[corbuzz_aoplane.dds]],
  buildPic           = [[CORBUZZ.DDS]],
  buildTime          = 680630,
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
  firestandorders    = 3,
  footprintX         = 8,
  footprintZ         = 8,
  iconType           = [[building]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maxDamage          = 34960,
  maxSlope           = 13,
  maxVelocity        = 0,
  maxWaterDepth      = 0,
  metalStorage       = 0,
  name               = [[Buzzsaw]],
  objectName         = [[CORBUZZ]],
  seismicSignature   = 0,
  selfDestructAs     = [[ATOMIC_BLAST]],
  side               = [[CORE]],
  sightDistance      = 273,
  smoothAnim         = false,
  standingfireorder  = 3,
  TEDClass           = [[FORT]],
  turnRate           = 0,
  unitname           = [[corbuzz]],
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
      [[servlrg4]],
    },
    select = {
      [[servlrg4]],
    },
  },
  weapons = {
    [1]  = {
      badTargetCategory  = [[MOBILE]],
      def                = [[CORBUZZ_WEAPON]],
      onlyTargetCategory = [[NOTAIR]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  CORBUZZ_WEAPON = {
    accuracy           = 750,
    areaOfEffect       = 256,
    ballistic          = true,
    color              = 2,
    craterBoost        = 0.25,
    craterMult         = 0.25,
    edgeEffectiveness  = 0.8,
    energypershot      = 10500,
    explosionGenerator = [[custom:FLASHBIGBUILDING]],
    gravityaffected    = [[true]],
    impulseBoost       = 0.5,
    impulseFactor      = 0.5,
    name               = [[RapidfireLRPC]],
    noSelfDamage       = true,
    randomdecay        = 11,
    range              = 6100,
    reloadtime         = 0.5,
    renderType         = 4,
    soundHit           = [[rflrpc3]],
    soundStart         = [[XPLONUK4]],
    startsmoke         = 1,
    turret             = true,
    weaponTimer        = 14,
    weaponType         = [[Cannon]],
    weaponVelocity     = 1150,
    damage = {
      blackhydra         = 3000,
      default            = 1900,
      flakboats          = 3000,
      jammerboats        = 3000,
      l1subs             = 5,
      l2subs             = 5,
      l3subs             = 5,
      otherboats         = 3000,
      seadragon          = 3000,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 20976,
    description        = [[Buzzsaw Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 7,
    footprintZ         = 7,
    height             = 20,
    hitdensity         = 100,
    metal              = 21099,
    object             = [[CORBUZZ_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 10488,
    description        = [[Buzzsaw Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 7,
    footprintZ         = 7,
    height             = 4,
    hitdensity         = 100,
    metal              = 8440,
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
