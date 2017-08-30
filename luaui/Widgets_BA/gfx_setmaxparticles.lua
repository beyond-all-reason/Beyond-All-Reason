
local minMaxparticles = 12000

function widget:GetInfo()
  return {
    name      = "Set MaxParticles",
    desc      = "Sets a minimum amount of maxparticles of: "..minMaxparticles.." (only once)",
    author    = "Floris",
    date      = "GPL v3 or later",
    license   = "August 2017",
    layer     = 0,
    enabled   = true  
  }
end

local hasSetMaxparticles = false


function widget:GetConfigData()
    savedTable = {}
    savedTable.hasSetMaxparticles = hasSetMaxparticles
    return savedTable
end

function widget:SetConfigData(data)
    if data.hasSetMaxparticles ~= nil then
        hasSetMaxparticles = data.hasSetMaxparticles
    end
end

function widget:Initialize()
    if hasSetMaxparticles == false then
        if tonumber(Spring.GetConfigInt("MaxParticles",1) or 0) < minMaxparticles then
            hasSetMaxparticles = true
            Spring.SetConfigInt("MaxParticles", minMaxparticles)
            Spring.Echo('MaxParticles widget:  setting MaxParticles config value to '..minMaxparticles)
        end
    end
    widgetHandler:RemoveWidget()
end