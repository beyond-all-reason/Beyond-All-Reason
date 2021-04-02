-- See: https://springrts.com/wiki/Modrules.lua
local xpmultiplier = tonumber(Spring.GetModOptions().experimentalxpgain) or 1
local gadgetXPEnabled = Spring.GetModOptions().experimentalxpsystem or "disabled" == "disabled"
if gadgetXPEnabled == "disabled" then
  gadgetXPEnabled = false
elseif gadgetXPEnabled == "enabled" then
  gadgetXPEnabled = true
else
  gadgetXPEnabled = false
end

if gadgetXPEnabled == true then
  XPValues = {
    experienceMult = 50,
    powerScale     = 0, -- keep it at 0
    healthScale    = 0, -- keep it at 0
    reloadScale    = 0, -- keep it at 0
  }
else
  XPValues = {
    experienceMult = 0.3,
    powerScale     = 0,
    healthScale    = 2.5,
    reloadScale    = 1.25,
  }
end









local modrules  = {

  construction = {
    constructionDecay      = true,  -- Do uncompleted building frames begin to decay if no builder is working on them?
    constructionDecayTime  = 9,     -- The time in seconds before abandoned building frames begin to decay.
    constructionDecaySpeed = 0.03,  -- How fast build progress decays for abandoned building frames. Note that the rate is inversely proportional to the buildtime i.e. a building with a larger buildtime will decay more slowly for a given value of this tag than a building with a shorter buildtime.
  },

  reclaim = {
    multiReclaim  = 1,    -- Can multiple units reclaim a feature or only one? 0 implies the latter, all other values the former.
    reclaimMethod = 0,    -- Controls how features are reclaimed. Can be 0 - gradual reclaim, 1 - all reclaimed at end, any other positive value n - reclaim in n chunks.
    unitMethod    = 1,    -- Controls how units are reclaimed. Can be 0 - gradual reclaim, 1 - all reclaimed at end, any other positive value n - reclaim in n chunks.

    unitEnergyCostFactor    = 0,    -- How much energy should reclaiming a unit cost? Multiplier against the fraction of the unit's buildCostEnergy reclaimed.
    unitEfficiency          = 1,    -- How much metal should reclaiming a unit return? Multiplier against the unit's buildCostMetal.
    featureEnergyCostFactor = 0,    -- How much energy should reclaiming a feature cost? Multiplier against the fraction of the features' metal content reclaimed.

    allowEnemies = true,    -- Can enemy units be reclaimed?
    allowAllies  = true,    -- Can allied units be reclaimed?
  },

  repair = {
    energyCostFactor = 0,   -- How much of the original energy cost it requires to resurrect something.
  },

  resurrect = {
    energyCostFactor = 0.5,   -- How much of the original energy cost it requires to resurrect something.
  },

  capture = {
    energyCostFactor = 0,  -- How much of the original energy cost it requires to capture something.
  },

  flankingBonus = {
    defaultMode = 1,  -- default: 1.  The default flankingBonusMode for units. Can be 0 - No flanking bonus. Mode 1 builds up the ability to move over time, and swings to face attacks, but does not respect the way the unit is facing. Mode 2 also can swing, but moves with the unit as it turns. Mode 3 stays with the unit as it turns and otherwise doesn't move, the ideal mode to simulate something such as tank armour.
  },

  sensors = {
    separateJammers = true,  -- When true each allyTeam only jams their own units.
    requireSonarUnderWater = true,  -- If true then when underwater, units only get LOS if they also have sonar.
    alwaysVisibleOverridesCloaked = false,  -- If true then units will be visible even when cloaked (probably?).

    los = {
      losMipLevel   = 4,  -- Controls the resolution of the LOS calculations. A higher value means lower resolution but increased performance. An increase by one level means half the resolution of the LOS map in both x and y direction. Must be between 0 and 6 inclusive.
      airMipLevel   = 4,  -- Controls the resolution of the LOS vs. aircraft calculations. A higher value means lower resolution but increased performance. An increase by one level means half the resolution of the air-LOS map in both x and y direction. Must be between 0 and 30 inclusive. [1] - jK describe for you what the value means.
      radarMipLevel = 3,  -- Controls the resolution of the radar. See description of airMipLevel for details.
    },
  },

  fireAtDead = {
    fireAtKilled   = false,   -- Will units continue to target and fire on enemies which are running their Killed() animation?
    fireAtCrashing = false,   -- Will units continue to target and fire on enemy aircraft which are in the 'crashing' state?
  },

  movement = {
	allowUnitCollisionDamage  = false,  -- default: true if using QTPFS pathfinder.  Do unit-unit (skidding) collisions cause damage?
	allowUnitCollisionOverlap = false,  -- can mobile units collision volumes overlap one another? Allows unit movement like this (video http://www.youtube.com/watch?v=mRtePUdVk2o ) at the cost of more 'clumping'.
    allowCrushingAlliedUnits  = true,   -- default: false.  Can allied ground units crush each other during collisions? Units still have to be explicitly set as crushable using the crushable parameter of Spring.SetUnitBlocking.
	allowGroundUnitGravity    = true,	-- default: true.   Allows fast moving mobile units to 'catch air' as they move over terrain.
	--NOTE: allowGroundUnitGravity was set to false to "Fix units flying over hills and bumps", but this came at a cost for unit impulse which was a desired trait

    allowAirPlanesToLeaveMap  = true,   -- Are (gunship) aircraft allowed to fly outside the bounds of the map?
    allowAircraftToHitGround  = true,   -- Are aircraft allowed to hit the ground whilst manoeuvring?
    allowPushingEnemyUnits    = false,  -- Can enemy ground units push each other during collisions?
    allowHoverUnitStrafing    = true,   -- Allows hovercraft units to slide in turns.
  },

  featureLOS = {
    featureVisibility = 3,    -- Can be 0 - no default LOS for features, 1 - Gaia features always visible, 2 - allyteam & Gaia features always visible, or 3 - all features always visible.
  },

  system = {
  	pathFinderSystem = 0,           -- Which pathfinder does the game use? Can be 0 - The legacy default pathfinder, 1 - Quad-Tree Pathfinder System (QTPFS) or -1 - disabled.
    pathFinderUpdateRate =  0.002, --0.007,   -- Controls how often the pathfinder updates; larger values means more rapid updates.
    allowTake = true,               -- Enables and disables the /take UI command.
  },

  transportability = {
    transportAir    = false,    -- Can aircraft be transported?
    transportShip   = false,    -- Can ships be transported?
    transportHover  = true,     -- Can hovercraft be transported?
    transportGround = true,     -- Can ground units be transported?
    targetableTransportedUnits = false,   -- Can transported units be targeted by weapons? true allows both manual and automatic targeting.
  },

  paralyze = {
    paralyzeOnMaxHealth = true,    -- Are units paralyzed when the level of emp is greater than their current health or their maximum health?
  },

  experience = {
    experienceMult = XPValues.experienceMult*xpmultiplier,    -- Controls the amount of experience gained by units engaging in combat. The formulae used are: xp for damage = 0.1 * experienceMult * damage / target_HP * target_power / attacker_power.  xp for kill = 0.1 * experienceMult * target_power / attacker_power. Where power can be set by the UnitDef tag.
    powerScale     = XPValues.powerScale,    -- Controls how gaining experience changes the relative power of the unit. The formula used is Power multiplier = powerScale * (1 + xp / (xp + 1)).
    healthScale    = XPValues.healthScale,  -- Controls how gaining experience increases the maxDamage (total hitpoints) of the unit. The formula used is Health multiplier = healthScale * (1 + xp / (xp + 1)).
    reloadScale    = XPValues.reloadScale,  -- Controls how gaining experience decreases the reloadTime of the unit's weapons. The formula used is Rate of fire multiplier = reloadScale * (1 + xp / (xp + 1)).
  },
}

return modrules
