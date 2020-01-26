
local minMaxparticles = 12000
local turnVsyncOff = true       -- because vsync results in considerable amount of lagginess

function widget:GetInfo()
  return {
    name      = "First launch setup",
    desc      = "Turns Vsync off and sets a minimum amount of maxparticles of: "..minMaxparticles,
    author    = "Floris",
    date      = "GPL v3 or later",
    license   = "August 2017",
    layer     = 0,
    enabled   = true  
  }
end



local firstlaunchsetupDone = false
function widget:GetConfigData()
    savedTable = {}
    savedTable.firsttimesetupDone = firstlaunchsetupDone
    return savedTable
end

function widget:SetConfigData(data)
    if data.firsttimesetupDone ~= nil then
        firstlaunchsetupDone = data.firsttimesetupDone
    end
end

function widget:Initialize()
    if firstlaunchsetupDone == false then
        if turnVsyncOff and tonumber(Spring.GetConfigInt("Vsync",1) or 1) == 1 then
            Spring.SendCommands("Vsync 0")
            Spring.SetConfigInt("Vsync",0)
            Spring.Echo('First time setup widget:  disabling Vsync')
        end
        if tonumber(Spring.GetConfigInt("MaxParticles",1) or 0) < minMaxparticles then
            Spring.SetConfigInt("MaxParticles", minMaxparticles)
            Spring.Echo('First time setup widget:  setting MaxParticles config value to '..minMaxparticles)
        end
        firstlaunchsetupDone = true
    end
    widgetHandler:RemoveWidget(self)
end