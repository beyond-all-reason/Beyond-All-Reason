-- UNITDEF -- BLADE --
--------------------------------------------------------------------------------

local unitName = "blade"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.6,
  badTargetCategory  = [[VTOL]],
  bankscale          = 1,
  bmcode             = 1,
  brakeRate          = 3.5,
  buildCostEnergy    = 20315,
  buildCostMetal     = 1192,
  builder            = false,
  buildPic           = [[BLADE.DDS]],
  buildTime          = 23964,
  canAttack          = true,
  canFly             = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL WEAPON NOTSUB VTOL]],
  collide            = false,
  cruiseAlt          = 110,
  defaultmissiontype = [[VTOL_standby]],
  description        = [[Rapid Assault Flak-Resistant Gunship]],
  energyMake         = 0.8,
  energyStorage      = 0,
  energyUse          = 0.9,
  explodeAs          = [[GUNSHIPEX]],
  firestandorders    = 1,
  footprintX         = 2,
  footprintZ         = 2,
  hoverAttack        = true,
  iconType           = [[air]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 2350,
  maxDamage          = 1800,
  maxSlope           = 10,
  maxVelocity        = 8,
  maxWaterDepth      = 0,
  metalStorage       = 0,
  mobilestandorders  = 1,
  name               = [[Blade]],
  noAutoFire         = false,
  noChaseCategory    = [[VTOL]],
  objectName         = [[BLADE]],
  scale              = 1,
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[ARM]],
  sightDistance      = 624,
  smoothAnim         = true,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[VTOL]],
  turnRate           = 720,
  unitname           = [[blade]],
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
      def                = [[VTOL_SABOT]],
      onlyTargetCategory = [[NOTAIR]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  VTOL_SABOT = {
    areaOfEffect       = 32,
    burnblow           = true,
    collideFriendly    = false,
    craterBoost        = 0,
    craterMult         = 0,
    explosionGenerator = [[custom:FLASH2]],
    fireStarter        = 70,
    impulseBoost       = 1,
    impulseFactor      = 0.123,
    lineOfSight        = true,
    model              = [[missile]],
    name               = [[Sabotrocket]],
    noSelfDamage       = true,
    pitchtolerance     = 18000,
    range              = 420,
    reloadtime         = 1.7,
    renderType         = 1,
    smokedelay         = 0.1,
    smokeTrail         = true,
    soundHit           = [[SabotHit]],
    soundStart         = [[SabotFire]],
    soundTrigger       = true,
    startsmoke         = 1,
    startVelocity      = 700,
    texture2           = [[armsmoketrail]],
    tolerance          = 8000,
    turnRate           = 18000,
    turret             = false,
    weaponAcceleration = 300,
    weaponTimer        = 3,
    weaponType         = [[MissileLauncher]],
    weaponVelocity     = 1000,
    damage = {
      commanders         = 140,
      default            = 280,
      flakboats          = 140,
      flaks              = 140,
      gunships           = 45,
      hgunships          = 45,
      l1bombers          = 45,
      l1fighters         = 45,
      l1subs             = 5,
      l2bombers          = 45,
      l2fighters         = 45,
      l2subs             = 5,
      l3subs             = 5,
      vradar             = 45,
      vtol               = 45,
      vtrans             = 45,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
