-- UNITDEF -- CORSPEC --
--------------------------------------------------------------------------------

local unitName = "corspec"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.1,
  activateWhenBuilt  = true,
  badTargetCategory  = [[MOBILE]],
  bmcode             = 1,
  brakeRate          = 0.12,
  buildCostEnergy    = 1453,
  buildCostMetal     = 70,
  builder            = false,
  buildPic           = [[corspec.jpg]],
  buildTime          = 5439,
  canAttack          = false,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[KBOT MOBILE ALL NOTSUB NOWEAPON NOTSHIP NOTAIR]],
  corpse             = [[dead]],
  defaultmissiontype = [[Standby]],
  description        = [[Radar Jammer Kbot]],
  energyMake         = 8,
  energyStorage      = 0,
  energyUse          = 100,
  explodeAs          = [[BIG_UNITEX]],
  footprintX         = 2,
  footprintZ         = 2,
  maneuverleashlength = 640,
  maxDamage          = 310,
  maxSlope           = 32,
  maxVelocity        = 1.3,
  maxWaterDepth      = 112,
  metalStorage       = 0,
  mobilestandorders  = 1,
  movementClass      = [[KBOT2]],
  name               = [[Spectre]],
  noAutoFire         = false,
  noChaseCategory    = [[MOBILE]],
  objectName         = [[CORSPEC]],
  onoffable          = true,
  radarDistance      = 0,
  radarDistanceJam   = 450,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[CORE]],
  sightDistance      = 250,
  smoothAnim         = true,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[KBOT]],
  turnRate           = 945,
  unitname           = [[corspec]],
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
      [[kbcormov]],
    },
    select = {
      [[radjam2]],
    },
  },
  weapons = {
    [1]  = {
      badTargetCategory  = [[MOBILE]],
      def                = [[BOGUS_GROUND_MISSILE]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  BOGUS_GROUND_MISSILE = {
    areaOfEffect       = 48,
    craterBoost        = 0,
    craterMult         = 0,
    impulseBoost       = 0,
    impulseFactor      = 0,
    lineOfSight        = true,
    metalpershot       = 0,
    name               = [[Missiles]],
    range              = 800,
    reloadtime         = 0.5,
    renderType         = 1,
    startVelocity      = 450,
    tolerance          = 9000,
    turnRate           = 33000,
    turret             = true,
    weaponAcceleration = 101,
    weaponTimer        = 0.1,
    weaponType         = [[Cannon]],
    weaponVelocity     = 650,
    damage = {
      default            = 0,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

local featureDefs = {
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 248,
    description        = [[Spectre Heap]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 4,
    hitdensity         = 100,
    metal              = 28,
    object             = [[2X2B]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  dead = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 248,
    description        = [[Spectre Wreckage]],
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 20,
    hitdensity         = 100,
    metal              = 56,
    object             = [[CORSPEC_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
