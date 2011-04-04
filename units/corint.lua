-- UNITDEF -- CORINT --
--------------------------------------------------------------------------------

local unitName = "corint"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0,
  antiweapons        = 1,
  badTargetCategory  = [[MOBILE]],
  bmcode             = 0,
  brakeRate          = 0,
  buildAngle         = 32700,
  buildCostEnergy    = 62520,
  buildCostMetal     = 4328,
  builder            = false,
  buildingGroundDecalDecaySpeed = 30,
  buildingGroundDecalSizeX = 8,
  buildingGroundDecalSizeY = 8,
  buildingGroundDecalType = [[corint_aoplane.dds]],
  buildPic           = [[CORINT.DDS]],
  buildTime          = 93237,
  canAttack          = true,
  canstop            = 1,
  category           = [[ALL NOTLAND WEAPON NOTSUB NOTSHIP NOTAIR]],
  corpse             = [[DEAD]],
  defaultmissiontype = [[GUARD_NOMOVE]],
  description        = [[Long Range Plasma Cannon]],
  energyStorage      = 0,
  energyUse          = 0,
  explodeAs          = [[ATOMIC_BLAST]],
  firestandorders    = 2,
  footprintX         = 5,
  footprintZ         = 5,
  iconType           = [[building]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maxDamage          = 4600,
  maxSlope           = 13,
  maxVelocity        = 0,
  maxWaterDepth      = 0,
  metalStorage       = 0,
  name               = [[Intimidator]],
  objectName         = [[CORINT]],
  seismicSignature   = 0,
  selfDestructAs     = [[ATOMIC_BLAST]],
  side               = [[CORE]],
  sightDistance      = 273,
  smoothAnim         = true,
  standingfireorder  = 2,
  TEDClass           = [[FORT]],
  turnRate           = 0,
  unitname           = [[corint]],
  useBuildingGroundDecal = true,
  workerTime         = 0,
  yardMap            = [[ooooooooooooooooooooooooo]],
  customparams = {
    canareaattack      = 1,
  },
  sfxtypes = {
    explosiongenerators = {
      [[custom:berthaflare]],
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
      def                = [[CORE_INTIMIDATOR]],
      onlyTargetCategory = [[NOTAIR]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  CORE_INTIMIDATOR = {
    accuracy           = 335,
    aimrate            = 2500,
    areaOfEffect       = 224,
    ballistic          = true,
    craterBoost        = 0.25,
    craterMult         = 0.25,
    energypershot      = 3000,
    explosionGenerator = [[custom:FLASHBIGBUILDING]],
    gravityaffected    = [[true]],
    holdtime           = 1,
    impulseBoost       = 0.5,
    impulseFactor      = 0.5,
    leadBonus          = 0,
    name               = [[IntimidatorCannon]],
    noSelfDamage       = true,
    range              = 6600,
    reloadtime         = 13.5,
    renderType         = 4,
    soundHit           = [[xplonuk1]],
    soundStart         = [[xplonuk3]],
    startsmoke         = 1,
    turret             = true,
    weaponType         = [[Cannon]],
    weaponVelocity     = 1150,
    damage = {
      blackhydra         = 3000,
      default            = 2000,
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
    damage             = 2760,
    description        = [[Intimidator Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 3,
    footprintZ         = 3,
    height             = 20,
    hitdensity         = 100,
    metal              = 2813,
    object             = [[CORINT_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 1380,
    description        = [[Intimidator Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 3,
    footprintZ         = 3,
    height             = 4,
    hitdensity         = 100,
    metal              = 1125,
    object             = [[3X3C]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
