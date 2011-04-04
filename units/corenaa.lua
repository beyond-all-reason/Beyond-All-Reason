-- UNITDEF -- CORENAA --
--------------------------------------------------------------------------------

local unitName = "corenaa"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0,
  activateWhenBuilt  = true,
  airSightDistance   = 1000,
  badTargetCategory  = [[NOTAIR]],
  bmcode             = 0,
  brakeRate          = 0,
  buildAngle         = 16384,
  buildCostEnergy    = 23744,
  buildCostMetal     = 832,
  builder            = false,
  buildPic           = [[CORENAA.DDS]],
  buildTime          = 23129,
  canAttack          = true,
  canstop            = 1,
  category           = [[ALL WEAPON NOTSUB SPECIAL NOTAIR]],
  corpse             = [[DEAD]],
  defaultmissiontype = [[GUARD_NOMOVE]],
  description        = [[Anti-Air Flak Gun - Naval Series]],
  energyStorage      = 0,
  energyUse          = 0.1,
  explodeAs          = [[BIG_UNITEX]],
  firestandorders    = 1,
  footprintX         = 4,
  footprintZ         = 4,
  iconType           = [[building]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maxDamage          = 1820,
  maxVelocity        = 0,
  metalStorage       = 0,
  minWaterDepth      = 2,
  name               = [[Cobra - NS]],
  noAutoFire         = false,
  objectName         = [[CORENAA]],
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[CORE]],
  sightDistance      = 550,
  smoothAnim         = true,
  standingfireorder  = 2,
  TEDClass           = [[WATER]],
  turnRate           = 0,
  unitname           = [[corenaa]],
  waterline          = 0.3,
  workerTime         = 0,
  yardMap            = [[wwwwwwwwwwwwwwww]],
  sounds = {
    canceldestruct     = [[cancel2]],
    cloak              = [[kloak1]],
    uncloak            = [[kloak1un]],
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
      [[twrturn3]],
    },
    select = {
      [[twrturn3]],
    },
  },
  weapons = {
    [1]  = {
      badTargetCategory  = [[NOTAIR]],
      def                = [[ARMFLAK_GUN]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  ARMFLAK_GUN = {
    accuracy           = 1000,
    areaOfEffect       = 192,
    avoidFriendly      = false,
    ballistic          = true,
    burnblow           = true,
    canattackground    = false,
    collideFriendly    = false,
    color              = 1,
    craterBoost        = 0,
    craterMult         = 0,
    cylinderTargetting = 1,
    edgeEffectiveness  = 0.85,
    explosionGenerator = [[custom:FLASH3]],
    gravityaffected    = [[true]],
    impulseBoost       = 0,
    impulseFactor      = 0,
    minbarrelangle     = -24,
    name               = [[FlakCannon]],
    noSelfDamage       = true,
    predictBoost       = 1,
    range              = 775,
    reloadtime         = 0.55,
    renderType         = 4,
    soundHit           = [[flakhit]],
    soundStart         = [[flakfire]],
    startsmoke         = 1,
    toAirWeapon        = true,
    turret             = true,
    unitsonly          = 1,
    weaponTimer        = 1,
    weaponType         = [[Cannon]],
    weaponVelocity     = 2450,
    damage = {
      amphibious         = 10,
      anniddm            = 10,
      antibomber         = 10,
      antifighter        = 10,
      antiraider         = 10,
      atl                = 10,
      blackhydra         = 10,
      commanders         = 10,
      crawlingbombs      = 10,
      default            = 1000,
      dl                 = 10,
      ["else"]           = 10,
      flakboats          = 10,
      flaks              = 10,
      flamethrowers      = 10,
      gunships           = 200,
      heavyunits         = 10,
      hgunships          = 100,
      jammerboats        = 10,
      krogoth            = 10,
      l1bombers          = 250,
      l1fighters         = 500,
      l1subs             = 10,
      l2bombers          = 250,
      l2fighters         = 500,
      l2subs             = 10,
      l3subs             = 10,
      mechs              = 10,
      mines              = 10,
      nanos              = 10,
      otherboats         = 10,
      plasmaguns         = 10,
      radar              = 10,
      seadragon          = 10,
      spies              = 10,
      tl                 = 10,
      vradar             = 250,
      vtol               = 250,
      vtrans             = 200,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 1092,
    description        = [[Cobra - NS Wreckage]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 1,
    footprintZ         = 1,
    height             = 20,
    hitdensity         = 100,
    metal              = 541,
    object             = [[CORENAA_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
