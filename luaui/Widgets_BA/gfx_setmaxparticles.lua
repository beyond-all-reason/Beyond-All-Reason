
local minMaxparticles = 10000

function widget:GetInfo()
  return {
    name      = "MaxParticles",
    desc      = "sets a minimum amount of maxparticles of: "..minMaxparticles,
    author    = "Floris",
    date      = "GPL v3 or later",
    license   = "August 2017",
    layer     = 0,
    enabled   = true  
  }
end

function widget:Initialize()
    if tonumber(Spring.GetConfigInt("MaxParticles",1) or 0) < minMaxparticles then
        Spring.SetConfigInt("MaxParticles", minMaxparticles)
        Spring.Echo('MaxParticles widget:  setting MaxParticles config value to '..minMaxparticles)
    end
    widgetHandler:RemoveWidget()
end