-- UNITDEF -- CORAPE --
--------------------------------------------------------------------------------

local unitName = "corape"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.152,
  badTargetCategory  = [[VTOL]],
  bankscale          = 1,
  bmcode             = 1,
  brakeRate          = 3.563,
  buildCostEnergy    = 6467,
  buildCostMetal     = 345,
  builder            = false,
  buildPic           = [[CORAPE.DDS]],
  buildTime          = 14500,
  canAttack          = true,
  canFly             = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL MOBILE WEAPON NOTLAND ANTIGATOR VTOL ANTIFLAME ANTIEMG ANTILASER NOTSUB NOTSHIP]],
  collide            = false,
  cruiseAlt          = 100,
  defaultmissiontype = [[VTOL_standby]],
  description        = [[Gunship]],
  energyMake         = 0.6,
  energyStorage      = 0,
  energyUse          = 0.6,
  explodeAs          = [[GUNSHIPEX]],
  firestandorders    = 1,
  footprintX         = 3,
  footprintZ         = 3,
  hoverAttack        = true,
  iconType           = [[air]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 1280,
  maxDamage          = 1000,
  maxSlope           = 10,
  maxVelocity        = 5.19,
  maxWaterDepth      = 0,
  metalStorage       = 0,
  mobilestandorders  = 1,
  name               = [[Rapier]],
  noAutoFire         = false,
  noChaseCategory    = [[VTOL]],
  objectName         = [[CORAPE]],
  scale              = 1,
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[CORE]],
  sightDistance      = 550,
  smoothAnim         = true,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[VTOL]],
  turnRate           = 594,
  unitname           = [[corape]],
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
      badTargetCategory  = [[VTOL]],
      def                = [[VTOL_ROCKET]],
      onlyTargetCategory = [[NOTAIR]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  VTOL_ROCKET = {
    areaOfEffect       = 128,
    burnblow           = true,
    craterBoost        = 0,
    craterMult         = 0,
    explosionGenerator = [[custom:KARGMISSILE_EXPLOSION]],
    fireStarter        = 70,
    impulseBoost       = 0.123,
    impulseFactor      = 0.123,
    lineOfSight        = true,
    model              = [[missile]],
    name               = [[RiotRocket]],
    noSelfDamage       = true,
    pitchtolerance     = 18000,
    range              = 410,
    reloadtime         = 1.1,
    renderType         = 1,
    selfprop           = true,
    smokedelay         = 0.1,
    smokeTrail         = true,
    soundHit           = [[explode]],
    soundStart         = [[rocklit3]],
    soundTrigger       = true,
    startsmoke         = 1,
    startVelocity      = 300,
    texture2           = [[coresmoketrail]],
    tolerance          = 8000,
    turnRate           = 9000,
    turret             = false,
    weaponAcceleration = 200,
    weaponTimer        = 5,
    weaponType         = [[MissileLauncher]],
    weaponVelocity     = 700,
    wobble             = 2500,
    damage = {
      commanders         = 61,
      default            = 122,
      flakboats          = 61,
      flaks              = 61,
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

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
