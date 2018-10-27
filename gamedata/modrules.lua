local modrules  = {

  construction = {
    constructionDecay      = true,  -- defaults to true
    constructionDecayTime  = 9,     -- defaults to 6.66
    constructionDecaySpeed = 0.03,  -- defaults to 0.03
  },

  reclaim = {
    multiReclaim  = 1,
    reclaimMethod = 0,
    unitMethod    = 1,

    unitEnergyCostFactor    = 0,  -- defaults to 0
    unitEfficiency          = 1,  -- defaults to 1
    featureEnergyCostFactor = 0,  -- defaults to 0
	
    allowEnemies = true,  -- defaults to true
    allowAllies  = true,  -- defaults to true
  },

  repair = {
    energyCostFactor = 0,   -- default: 0
  },

  resurrect = {
    energyCostFactor = 0.5,   -- default: 0.5
  },

  capture = {
    energyCostFactor = 0,  -- default: 0.  How much of the original energy cost it requires to capture something.
  },

  flankingBonus = {
    defaultMode = 0,  -- default: 1.  The default flankingBonusMode for units. Can be 0 - No flanking bonus. Mode 1 builds up the ability to move over time, and swings to face attacks, but does not respect the way the unit is facing. Mode 2 also can swing, but moves with the unit as it turns. Mode 3 stays with the unit as it turns and otherwise doesn't move, the ideal mode to simulate something such as tank armour.
  },

  sensors = {
    separateJammers = true,  -- default: true
    requireSonarUnderWater = true,  -- default: tru.e If true then when underwater, units only get LOS if they also have sonar.
    alwaysVisibleOverridesCloaked = false,  -- default: false.  If true then units will be visible even when cloaked (probably?).

    los = {
      losMipLevel   = 3,  -- default: 1.  Controls the resolution of the LOS calculations. A higher value means lower resolution but increased performance. An increase by one level means half the resolution of the LOS map in both x and y direction. Must be between 0 and 6 inclusive.
      airMipLevel   = 3,  -- default: 1.  Controls the resolution of the LOS vs. aircraft calculations. A higher value means lower resolution but increased performance. An increase by one level means half the resolution of the air-LOS map in both x and y direction. Must be between 0 and 30 inclusive. [1] - jK describe for you what the value means.
      radarMipLevel = 3,  -- default: 2.  Controls the resolution of the radar. See description of airMipLevel for details.
    },
  },

  fireAtDead = {
    fireAtKilled   = false,
    fireAtCrashing = false,
  },

  movement = {
	allowUnitCollisionDamage  = false,  -- default: true if using QTPFS pathfinder.  Do unit-unit (skidding) collisions cause damage?
	allowUnitCollisionOverlap = false,   -- can mobile units collision volumes overlap one another? Allows unit movement like this (video http://www.youtube.com/watch?v=mRtePUdVk2o ) at the cost of more 'clumping'.
    allowCrushingAlliedUnits  = true,   -- default: false.  Can allied ground units crush each other during collisions? Units still have to be explicitly set as crushable using the crushable parameter of Spring.SetUnitBlocking.
	allowGroundUnitGravity    = false,

    allowAirPlanesToLeaveMap  = true,   -- default: true.  Are (gunship) aircraft allowed to fly outside the bounds of the map?
    allowAircraftToHitGround  = true,   -- default: true.  Are aircraft allowed to hit the ground whilst manoeuvring?
    allowPushingEnemyUnits    = false,  -- default: false.  Can enemy ground units push each other during collisions?
    allowHoverUnitStrafing    = true,   -- default: true.  Allows hovercraft units to slide in turns.
  },
  
  featureLOS = { 
    featureVisibility = 3, -- Can be 0 - no default LOS for features, 1 - Gaia features always visible, 2 - allyteam & Gaia features always visible, or 3 - all features always visible.
  },

  system = {
  	pathFinderSystem = (Spring.GetModOptions and (Spring.GetModOptions().pathfinder == "qtpfs") and 1) or 0,
    pathFinderUpdateRate = 0.007,   -- default 0.007, higher means more updates
  },

  transportability = {
    transportAir    = false,    -- default: false
    transportShip   = false,    -- default: false
    transportHover  = true,    -- default: false
    transportGround = true,     -- default: true
    targetableTransportedUnits = false, -- Can transported units be targeted by weapons? true allows both manual and automatic targeting.
  },

  paralyze = {
    paralyzeOnMaxHealth = true,    -- default: true. Are units paralyzed when the level of emp is greater than their current health or their maximum health?
  },

  experience = {
    experienceMult = 1,    -- Controls the amount of experience gained by units engaging in combat. The formulae used are: xp for damage = 0.1 * experienceMult * damage / target_HP * target_power / attacker_power.  xp for kill = 0.1 * experienceMult * target_power / attacker_power. Where power can be set by the UnitDef tag.
    powerScale     = 1,    -- Controls how gaining experience changes the relative power of the unit. The formula used is Power multiplier = powerScale * (1 + xp / (xp + 1)).
    healthScale    = 0.7,  -- Controls how gaining experience increases the maxDamage (total hitpoints) of the unit. The formula used is Health multiplier = healthScale * (1 + xp / (xp + 1)).
    reloadScale    = 0.4,  -- Controls how gaining experience decreases the reloadTime of the unit's weapons. The formula used is Rate of fire multiplier = reloadScale * (1 + xp / (xp + 1)).
  },
}

if (Spring.GetModOptions) and Spring.GetModOptions().unba and (Spring.GetModOptions().unba == "enabled" or Spring.GetModOptions().unba == "exponly") then
  modrules.experience.powerScale = 3
  modrules.experience.healthScale = 1.4
  modrules.experience.reloadScale = 0.8
end

return modrules
