function gadget:GetInfo()
  return {
    name      = "Version Warning",
    desc      = "Prints a warning if engine version is too low",
    author    = "Bluestone",
    date      = "Horses",
    license   = "",
    layer     = math.huge,
    enabled   = true  --  loaded by default?
  }
end

if (gadgetHandler:IsSyncedCode()) then
	return
end

local minEngineVersion = 99 -- major engine version as number
local maxEngineVersion = 100 -- don't forget to update it!

local red = "\255\255\1\1"

function gadget:GameStart()
    local reportedMajorVersion = string.sub(Game.version,1,3)
    if reportedMajorVersion and tonumber(reportedMajorVersion) then
        if tonumber(reportedMajorVersion)<minEngineVersion then
            Spring.Echo(red .. "WARNING: YOU ARE USING SPRING " .. Game.version .. " WHICH IS TOO OLD FOR THIS GAME.")
            Spring.Echo(red .. "PLEASE UPDATE YOUR ENGINE TO SPRING " .. tostring(minEngineVersion) .. " - " .. tostring(maxEngineVersion) .. ".")
        elseif tonumber(reportedMajorVersion)>maxEngineVersion then
            Spring.Echo(red .. "WARNING: YOU ARE USING SPRING " .. Game.version .. " WHICH IS TOO RECENT FOR THIS GAME.")
            Spring.Echo(red .. "PLEASE DOWNGRADE YOUR ENGINE TO SPRING " .. tostring(minEngineVersion) .. " - " .. tostring(maxEngineVersion) .. ".")
        end           
    end
end




--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
