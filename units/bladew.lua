-- UNITDEF -- BLADEW --
--------------------------------------------------------------------------------

local unitName = "bladew"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.264,
  airStrafe          = true,
  altfromsealevel    = 56,
  bankscale          = 1.64,
  bmcode             = 1,
  brakeRate          = 5.5,
  buildCostEnergy    = 1200,
  buildCostMetal     = 54,
  builder            = false,
  buildPic           = [[BLADEW.DDS]],
  buildTime          = 2073,
  canAttack          = true,
  canFly             = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL WEAPON VTOL NOTSUB]],
  collide            = false,
  cruiseAlt          = 78,
  defaultmissiontype = [[VTOL_standby]],
  description        = [[Light Paralyzer Drone]],
  energyMake         = 2,
  energyStorage      = 0,
  energyUse          = 0,
  explodeAs          = [[TINY_BUILDINGEX]],
  firestandorders    = 1,
  footprintX         = 2,
  footprintZ         = 2,
  hoverAttack        = true,
  iconType           = [[air]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 640,
  maxDamage          = 60,
  maxSlope           = 10,
  maxVelocity        = 10.35,
  maxWaterDepth      = 0,
  metalStorage       = 0,
  mobilestandorders  = 1,
  name               = [[Bladewing]],
  noAutoFire         = false,
  noChaseCategory    = [[COMMANDERS VTOL]],
  objectName         = [[BLADEW]],
  scale              = 1,
  seismicSignature   = 0,
  selfDestructAs     = [[TINY_BUILDINGEX]],
  side               = [[CORE]],
  sightDistance      = 364,
  smoothAnim         = true,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[VTOL]],
  turnRate           = 1144,
  unitname           = [[bladew]],
  upright            = true,
  usesmoothmesh      = 0,
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
      [[vtolcrmv]],
    },
    select = {
      [[vtolcrac]],
    },
  },
  weapons = {
    [1]  = {
      def                = [[BLADEWING_LYZER]],
      mainDir            = [[0 0 1]],
      maxAngleDif        = 90,
      onlyTargetCategory = [[NOTAIR]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  BLADEWING_LYZER = {
    areaOfEffect       = 8,
    avoidFriendly      = false,
    beamlaser          = 1,
    beamTime           = 0.1,
    collideFriendly    = false,
    coreThickness      = 0.1,
    craterBoost        = 0,
    craterMult         = 0,
    cylinderTargetting = 1,
    duration           = 0.01,
    explosionGenerator = [[custom:EMPFLASH20]],
    impactonly         = 1,
    impulseBoost       = 0,
    impulseFactor      = 0,
    laserFlareSize     = 5,
    lineOfSight        = true,
    name               = [[Paralyzer]],
    noSelfDamage       = true,
    paralyzer          = true,
    paralyzeTime       = 7,
    range              = 220,
    reloadtime         = 1.2,
    renderType         = 0,
    rgbColor           = [[1 1 0]],
    soundHit           = [[lashit]],
    soundStart         = [[hackshot]],
    soundTrigger       = true,
    targetMoveError    = 0.3,
    thickness          = 1.2,
    tolerance          = 10000,
    turret             = true,
    weaponType         = [[BeamLaser]],
    weaponVelocity     = 800,
    damage = {
      blackhydra         = 20,
      commanders         = 20,
      default            = 800,
      krogoth            = 20,
      seadragon          = 20,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
