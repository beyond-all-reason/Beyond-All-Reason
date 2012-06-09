local modrules  = {

  reclaim = {
    multiReclaim  = 1;
    reclaimMethod = 0;
  },


  sensors = {   
    los = {
      losMipLevel = 2, 
      losMul      = 1,
      airMipLevel = 4,
      airMul      = 1,
    },
  },

  fireAtDead = {
    fireAtKilled   = false;
    fireAtCrashing = false;
  },

  nanospray = {
    allow_team_colors = true;
  },
  
  featureLOS = { featureVisibility = 2; },

  system = {
        pathFinderSystem = (Spring.GetModOptions() and (Spring.GetModOptions().pathfinder == "qtpfs") and 1) or 0,
	    luaThreadingModel = 4,
  },

}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

return modrules