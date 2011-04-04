-- UNITDEF -- ARMPB --
--------------------------------------------------------------------------------

local unitName = "armpb"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0,
  badTargetCategory  = [[VTOL]],
  bmcode             = 0,
  brakeRate          = 0,
  buildCostEnergy    = 12896,
  buildCostMetal     = 638,
  builder            = false,
  buildingGroundDecalDecaySpeed = 30,
  buildingGroundDecalSizeX = 5,
  buildingGroundDecalSizeY = 5,
  buildingGroundDecalType = [[armpb_aoplane.dds]],
  buildPic           = [[ARMPB.DDS]],
  buildTime          = 14961,
  canAttack          = true,
  canstop            = 1,
  category           = [[ALL NOTLAND WEAPON NOTSUB NOTSHIP NOTAIR]],
  cloakCost          = 16,
  corpse             = [[DEAD]],
  damageModifier     = 0.5,
  defaultmissiontype = [[GUARD_NOMOVE]],
  description        = [[Pop-up Gauss Cannon]],
  digger             = 1,
  energyMake         = 0,
  energyStorage      = 25,
  energyUse          = 0,
  explodeAs          = [[SMALL_BUILDINGEX]],
  firestandorders    = 1,
  footprintX         = 3,
  footprintZ         = 3,
  iconType           = [[building]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  initCloaked        = false,
  maxDamage          = 2531,
  maxSlope           = 10,
  maxVelocity        = 0,
  maxWaterDepth      = 0,
  metalStorage       = 0,
  minCloakDistance   = 55,
  name               = [[Pit Bull]],
  noAutoFire         = false,
  noChaseCategory    = [[MOBILE]],
  objectName         = [[ARMPB]],
  seismicSignature   = 0,
  selfDestructAs     = [[SMALL_BUILDING]],
  side               = [[ARM]],
  sightDistance      = 598,
  smoothAnim         = true,
  standingfireorder  = 2,
  TEDClass           = [[FORT]],
  turnRate           = 0,
  unitname           = [[armpb]],
  useBuildingGroundDecal = true,
  yardMap            = [[ooooooooo]],
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
      badTargetCategory  = [[VTOL]],
      def                = [[ARMPB_WEAPON]],
      onlyTargetCategory = [[NOTAIR]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  ARMPB_WEAPON = {
    areaOfEffect       = 24,
    burnblow           = true,
    craterBoost        = 0,
    craterMult         = 0,
    explosionGenerator = [[custom:FLASH2nd]],
    impulseBoost       = 0.123,
    impulseFactor      = 0.123,
    lineOfSight        = true,
    name               = [[GaussCannon]],
    noSelfDamage       = true,
    range              = 730,
    reloadtime         = 1.625,
    renderType         = 4,
    soundHit           = [[xplomed2]],
    soundStart         = [[cannhvy1]],
    startsmoke         = 0,
    targetMoveError    = 0.2,
    tolerance          = 8000,
    turret             = true,
    weaponType         = [[Cannon]],
    weaponVelocity     = 800,
    damage = {
      default            = 675,
      gunships           = 26,
      hgunships          = 26,
      l1bombers          = 26,
      l1fighters         = 26,
      l1subs             = 5,
      l2bombers          = 26,
      l2fighters         = 26,
      l2subs             = 5,
      l3subs             = 5,
      vradar             = 26,
      vtol               = 26,
      vtrans             = 26,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 1519,
    description        = [[Pit Bull Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 3,
    footprintZ         = 3,
    height             = 15,
    hitdensity         = 100,
    metal              = 350,
    object             = [[ARMPB_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 760,
    description        = [[Pit Bull Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 3,
    footprintZ         = 3,
    height             = 4,
    hitdensity         = 100,
    metal              = 140,
    object             = [[3X3D]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
