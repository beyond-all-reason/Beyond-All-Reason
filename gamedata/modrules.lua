local modrules  = {

  construction = {
    constructionDecay      = true, -- defaults to true
    constructionDecayTime  = 10,  -- defaults to 6.66
    constructionDecaySpeed = 1,  -- defaults to 0.03
  },

  reclaim = {
    multiReclaim  = 1,
    reclaimMethod = 0,
	unitMethod = 1,
	
    unitEnergyCostFactor    = 0.15,  -- defaults to 0
    unitEfficiency          = 1,  -- defaults to 1
    featureEnergyCostFactor = 0.15,  -- defaults to 0
	
    allowEnemies  = true,  -- defaults to true
    allowAllies   = true,  -- defaults to true
  },

  sensors = {   
    los = {
      losMipLevel = 3,
      airMipLevel = 3,
      radarMipLevel = 3,
    },
  },

  fireAtDead = {
    fireAtKilled   = false,
    fireAtCrashing = false,
  },

  movement = {
	allowUnitCollisionDamage = false, -- defaults to false, Do unit-unit (skidding) collisions cause damage? 
	allowUnitCollisionOverlap = false,-- can mobile units collision volumes overlap one another? Allows unit movement like this (video http://www.youtube.com/watch?v=mRtePUdVk2o ) at the cost of more 'clumping'. 
    allowCrushingAlliedUnits = true,
  },
  
  featureLOS = { 
    featureVisibility = 3, -- Can be 0 - no default LOS for features, 1 - Gaia features always visible, 2 - allyteam & Gaia features always visible, or 3 - all features always visible.
  },

  system = {
  	pathFinderSystem = (Spring.GetModOptions() and (Spring.GetModOptions().pathfinder == "qtpfs") and 1) or 0,
  },

}


return modrules
