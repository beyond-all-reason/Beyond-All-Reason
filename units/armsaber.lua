-- UNITDEF -- ARMSABER --
--------------------------------------------------------------------------------

local unitName = "armsaber"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.288,
  amphibious         = 1,
  badTargetCategory  = [[VTOL]],
  bankscale          = 1,
  bmcode             = 1,
  brakeRate          = 4.613,
  buildCostEnergy    = 5984,
  buildCostMetal     = 192,
  builder            = false,
  buildPic           = [[ARMSABER.DDS]],
  buildTime          = 11016,
  canAttack          = true,
  canFly             = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  canSubmerge        = true,
  category           = [[ALL NOTLAND MOBILE WEAPON ANTIGATOR NOTSUB ANTIFLAME ANTIEMG ANTILASER VTOL NOTSHIP]],
  collide            = false,
  cruiseAlt          = 100,
  defaultmissiontype = [[VTOL_standby]],
  description        = [[Seaplane Gunship]],
  energyMake         = 0.8,
  energyStorage      = 0,
  energyUse          = 0.8,
  explodeAs          = [[BIG_UNITEX]],
  firestandorders    = 1,
  footprintX         = 3,
  footprintZ         = 3,
  hoverAttack        = true,
  iconType           = [[air]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 1280,
  maxDamage          = 515,
  maxSlope           = 10,
  maxVelocity        = 5.23,
  maxWaterDepth      = 255,
  metalStorage       = 0,
  mobilestandorders  = 1,
  moverate1          = 10,
  name               = [[Sabre]],
  noAutoFire         = false,
  noChaseCategory    = [[VTOL]],
  objectName         = [[ARMSABER]],
  scale              = 1,
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[ARM]],
  sightDistance      = 595,
  smoothAnim         = true,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[VTOL]],
  turnRate           = 931,
  unitname           = [[armsaber]],
  workerTime         = 0,
  sounds = {
    build              = [[nanlath1]],
    canceldestruct     = [[cancel2]],
    repair             = [[repair1]],
    underattack        = [[warning1]],
    working            = [[reclaim1]],
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
      [[seapsel1]],
    },
  },
  weapons = {
    [1]  = {
      badTargetCategory  = [[VTOL]],
      def                = [[VTOL_EMG2]],
      onlyTargetCategory = [[NOTAIR]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  VTOL_EMG2 = {
    areaOfEffect       = 8,
    beamlaser          = 1,
    beamTime           = 0.1,
    coreThickness      = 0.2,
    craterBoost        = 0,
    craterMult         = 0,
    energypershot      = 35,
    explosionGenerator = [[custom:SMALL_GREEN_LASER_BURN]],
    fireStarter        = 90,
    impulseBoost       = 0.123,
    impulseFactor      = 0.123,
    lineOfSight        = true,
    name               = [[HighEnergyLaser]],
    noSelfDamage       = true,
    pitchtolerance     = 12000,
    range              = 420,
    reloadtime         = 1.05,
    renderType         = 0,
    rgbColor           = [[0 1 0]],
    soundHit           = [[lasrhit1]],
    soundStart         = [[Lasrmas2]],
    targetMoveError    = 0.3,
    thickness          = 2.9,
    turret             = false,
    weaponType         = [[BeamLaser]],
    weaponVelocity     = 800,
    damage = {
      commanders         = 35,
      default            = 70,
      flakboats          = 35,
      flaks              = 35,
      gunships           = 10,
      hgunships          = 10,
      l1bombers          = 10,
      l1fighters         = 10,
      l1subs             = 1,
      l2bombers          = 10,
      l2fighters         = 10,
      l2subs             = 1,
      l3subs             = 1,
      vradar             = 10,
      vtol               = 10,
      vtrans             = 10,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
