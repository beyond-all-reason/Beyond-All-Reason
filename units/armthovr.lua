-- UNITDEF -- ARMTHOVR --
--------------------------------------------------------------------------------

local unitName = "armthovr"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.043,
  badTargetCategory  = [[VTOL]],
  bmcode             = 1,
  brakeRate          = 0.062,
  buildAngle         = 16384,
  buildCostEnergy    = 7938,
  buildCostMetal     = 665,
  builder            = false,
  buildPic           = [[ARMTHOVR.DDS]],
  buildTime          = 20341,
  canAttack          = true,
  canGuard           = true,
  canHover           = true,
  canload            = 1,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  cantBeTransported  = true,
  category           = [[ALL HOVER MOBILE WEAPON NOTSUB NOTSHIP NOTAIR]],
  corpse             = [[DEAD]],
  defaultmissiontype = [[Standby]],
  description        = [[Transport Hovercraft]],
  energyMake         = 2.4,
  energyStorage      = 0,
  energyUse          = 2.4,
  explodeAs          = [[BIG_UNITEX]],
  firestandorders    = 1,
  footprintX         = 4,
  footprintZ         = 4,
  iconType           = [[armthovr]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 640,
  maxDamage          = 5160,
  maxVelocity        = 2.07,
  metalStorage       = 0,
  minWaterDepth      = 12,
  mobilestandorders  = 1,
  movementClass      = [[HOVER4]],
  name               = [[Bear]],
  noAutoFire         = false,
  noChaseCategory    = [[ALL]],
  objectName         = [[ARMTHOVR]],
  scale              = 0.5,
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[ARM]],
  sightDistance      = 325,
  smoothAnim         = true,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[TANK]],
  transportCapacity  = 20,
  transportmaxunits  = 8,
  transportSize      = 3,
  turnRate           = 395,
  unitname           = [[armthovr]],
  waterline          = 4,
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
      [[hovlgok1]],
    },
    select = {
      [[hovlgsl1]],
    },
  },
  weapons = {
    [1]  = {
      badTargetCategory  = [[VTOL]],
      def                = [[CORFAST_WEAPON]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  CORFAST_WEAPON = {
    areaOfEffect       = 8,
    beamlaser          = 1,
    beamTime           = 0.1,
    coreThickness      = 0.5,
    craterBoost        = 0,
    craterMult         = 0,
    energypershot      = 10,
    explosionGenerator = [[custom:SMALL_RED_BURN]],
    fireStarter        = 30,
    impactonly         = 1,
    impulseBoost       = 0.123,
    impulseFactor      = 0.123,
    laserFlareSize     = 9,
    lineOfSight        = true,
    name               = [[L1DeckLaser]],
    noSelfDamage       = true,
    range              = 400,
    reloadtime         = 0.8,
    renderType         = 0,
    rgbColor           = [[1 0.2 0.2]],
    soundHit           = [[lasrhit2]],
    soundStart         = [[lasrfir3]],
    soundTrigger       = true,
    targetMoveError    = 0.1,
    thickness          = 1.25,
    tolerance          = 10000,
    turret             = true,
    weaponType         = [[BeamLaser]],
    weaponVelocity     = 800,
    damage = {
      default            = 60,
      gunships           = 15,
      hgunships          = 15,
      l1bombers          = 15,
      l1fighters         = 15,
      l1subs             = 5,
      l2bombers          = 15,
      l2fighters         = 15,
      l2subs             = 5,
      l3subs             = 5,
      vradar             = 15,
      vtol               = 15,
      vtrans             = 15,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = false,
    category           = [[corpses]],
    damage             = 3096,
    description        = [[Bear Wreckage]],
    energy             = 0,
    footprintX         = 4,
    footprintZ         = 4,
    height             = 20,
    hitdensity         = 100,
    metal              = 432,
    object             = [[ARMTHOVR_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
