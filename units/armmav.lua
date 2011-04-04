-- UNITDEF -- ARMMAV --
--------------------------------------------------------------------------------

local unitName = "armmav"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.12,
  autoHeal           = 50,
  badTargetCategory  = [[VTOL]],
  bmcode             = 1,
  brakeRate          = 0.125,
  buildCostEnergy    = 12180,
  buildCostMetal     = 655,
  builder            = false,
  buildPic           = [[ARMMAV.DDS]],
  buildTime          = 18384,
  canAttack          = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[KBOT MOBILE WEAPON ALL NOTSUB NOTSHIP NOTAIR]],
  corpse             = [[DEAD]],
  defaultmissiontype = [[Standby]],
  description        = [[Skirmish Kbot (Combat Auto-Repair)]],
  energyMake         = 0.4,
  energyStorage      = 0,
  energyUse          = 0.4,
  explodeAs          = [[BIG_UNITEX]],
  firestandorders    = 1,
  footprintX         = 2,
  footprintZ         = 2,
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 640,
  maxDamage          = 1120,
  maxSlope           = 14,
  maxVelocity        = 1.65,
  maxWaterDepth      = 0,
  metalStorage       = 0,
  mobilestandorders  = 1,
  movementClass      = [[KBOT2]],
  name               = [[Maverick]],
  noAutoFire         = false,
  noChaseCategory    = [[VTOL]],
  objectName         = [[ARMMAV]],
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[ARM]],
  sightDistance      = 550,
  smoothAnim         = true,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 2,
  TEDClass           = [[KBOT]],
  turnRate           = 1118,
  unitname           = [[armmav]],
  upright            = true,
  workerTime         = 0,
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
      [[mavbok1]],
    },
    select = {
      [[mavbsel1]],
    },
  },
  weapons = {
    [1]  = {
      badTargetCategory  = [[VTOL]],
      def                = [[ARMMAV_WEAPON]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  ARMMAV_WEAPON = {
    areaOfEffect       = 8,
    explosionGenerator = [[custom:FLASH1]],
    impactonly         = 1,
    lineOfSight        = true,
    minbarrelangle     = -15,
    name               = [[GaussCannon]],
    noSelfDamage       = true,
    range              = 365,
    reloadtime         = 0.945,
    renderType         = 4,
    soundHit           = [[xplomed2]],
    soundStart         = [[Mavgun2]],
    startsmoke         = 1,
    tolerance          = 4000,
    turret             = true,
    weaponType         = [[Cannon]],
    weaponVelocity     = 500,
    damage = {
      default            = 280,
      gunships           = 70,
      hgunships          = 70,
      l1bombers          = 70,
      l1fighters         = 70,
      l1subs             = 5,
      l2bombers          = 70,
      l2fighters         = 70,
      l2subs             = 5,
      l3subs             = 5,
      vradar             = 70,
      vtol               = 70,
      vtrans             = 70,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = true,
    category           = [[arm_corpses]],
    damage             = 696,
    description        = [[Maverick Heap]],
    featureDead        = [[heap]],
    featurereclamate   = [[smudge01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 20,
    hitdensity         = 100,
    metal              = 394,
    object             = [[armmav_dead]],
    reclaimable        = true,
    seqnamereclamate   = [[tree1reclamate]],
    world              = [[All Worlds]],
  },
  heap = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 696,
    description        = [[Maverick Heap]],
    featurereclamate   = [[smudge01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 4,
    hitdensity         = 100,
    metal              = 196,
    object             = [[2x2e]],
    reclaimable        = true,
    seqnamereclamate   = [[tree1reclamate]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
