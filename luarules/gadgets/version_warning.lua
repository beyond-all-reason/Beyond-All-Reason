function gadget:GetInfo()
  return {
    name      = "Version Warning",
    desc      = "Prints a warning if engine version is too low/high",
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

local minEngineVersion = 103 -- major engine version as number
local maxEngineVersion = 104 -- don't forget to update it!

local red = "\255\255\1\1"

local version = ""
if (Game and Game.version) then
    version = Game.version
elseif (Engine and Engine.version) then
    version = Engine.version
end

function gadget:GameStart()
    local n = string.find(version,".",1,true) or string.len(version) -- see http://stackoverflow.com/questions/15258313/finding-with-string-find, lua is so *** stupid
    local reportedMajorVersion = string.sub(version,1,n+1)
    if reportedMajorVersion and tonumber(reportedMajorVersion) then
        if tonumber(reportedMajorVersion)<minEngineVersion then
            Spring.Echo(red .. "WARNING: YOU ARE USING SPRING " .. version .. " WHICH IS TOO OLD FOR THIS GAME.")
            Spring.Echo(red .. "PLEASE UPDATE YOUR ENGINE TO SPRING " .. tostring(minEngineVersion) .. " - " .. tostring(maxEngineVersion) .. ".")
        elseif tonumber(reportedMajorVersion)>maxEngineVersion then
            Spring.Echo(red .. "WARNING: YOU ARE USING SPRING " .. version .. " WHICH IS TOO RECENT FOR THIS GAME.")
            Spring.Echo(red .. "PLEASE DOWNGRADE YOUR ENGINE TO SPRING " .. tostring(minEngineVersion) .. " - " .. tostring(maxEngineVersion) .. ".")
        end           
    end
end




--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
