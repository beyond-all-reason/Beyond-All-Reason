-- UNITDEF -- ARMDFLY --
--------------------------------------------------------------------------------

local unitName = "armdfly"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.2,
  badTargetCategory  = [[VTOL]],
  bankscale          = 1,
  bmcode             = 1,
  brakeRate          = 6.25,
  buildCostEnergy    = 6250,
  buildCostMetal     = 298,
  builder            = false,
  buildPic           = [[ARMDFLY.DDS]],
  buildTime          = 16022,
  canAttack          = true,
  canFly             = true,
  canGuard           = true,
  canload            = 1,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL NOTLAND MOBILE NOTSUB VTOL NOWEAPON NOTSHIP]],
  collide            = false,
  cruiseAlt          = 150,
  defaultmissiontype = [[VTOL_standby]],
  description        = [[Stealthy Armed Transport]],
  energyMake         = 0.6,
  energyStorage      = 0,
  energyUse          = 0.6,
  explodeAs          = [[SMALL_UNITEX]],
  firestandorders    = 1,
  footprintX         = 4,
  footprintZ         = 4,
  hoverAttack        = true,
  iconType           = [[air]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 1280,
  maxDamage          = 1050,
  maxSlope           = 15,
  maxVelocity        = 8.05,
  maxWaterDepth      = 0,
  metalStorage       = 0,
  mobilestandorders  = 1,
  name               = [[Dragonfly]],
  noAutoFire         = false,
  noChaseCategory    = [[VTOL]],
  objectName         = [[ARMDFLY]],
  scale              = 1,
  seismicSignature   = 0,
  selfDestructAs     = [[SMALL_UNIT]],
  side               = [[ARM]],
  sightDistance      = 318,
  smoothAnim         = false,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  stealth            = true,
  steeringmode       = 1,
  TEDClass           = [[VTOL]],
  transmaxunits      = 1,
  transportCapacity  = 30,
  transportmaxunits  = 1,
  transportSize      = 15,
  turnRate           = 420,
  unitname           = [[armdfly]],
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
      [[vtolarmv]],
    },
    select = {
      [[vtolarac]],
    },
  },
  weapons = {
    [1]  = {
      badTargetCategory  = [[VTOL]],
      def                = [[ARMDFLY_PARALYZER]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  ARMDFLY_PARALYZER = {
    areaOfEffect       = 32,
    beamlaser          = 1,
    beamTime           = 0.5,
    collideFriendly    = false,
    craterBoost        = 0,
    craterMult         = 0,
    duration           = 0.01,
    endsmoke           = 0,
    explosionGenerator = [[custom:EMPFLASH20]],
    impulseBoost       = 0.123,
    impulseFactor      = 0.123,
    lineOfSight        = true,
    minbarrelangle     = 0,
    name               = [[Paralyzer]],
    noSelfDamage       = true,
    paralyzer          = true,
    paralyzeTime       = 15,
    pitchtolerance     = 12000,
    range              = 520,
    reloadtime         = 8,
    renderType         = 0,
    rgbColor           = [[0.9 0.9 0]],
    soundHit           = [[lashit]],
    soundStart         = [[hackshot]],
    soundTrigger       = true,
    startsmoke         = 0,
    targetMoveError    = 0.3,
    thickness          = 1.25,
    tolerance          = 6000,
    turret             = false,
    weaponType         = [[BeamLaser]],
    weaponVelocity     = 1000,
    damage = {
      blackhydra         = 30,
      commanders         = 30,
      default            = 15000,
      krogoth            = 30,
      seadragon          = 30,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
