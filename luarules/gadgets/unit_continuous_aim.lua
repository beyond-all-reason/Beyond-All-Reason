
local engineVersion = 100 -- just filled this in here incorrectly but old engines arent used anyway
if Engine and Engine.version then
    local function Split(s, separator)
        local results = {}
        for part in s:gmatch("[^"..separator.."]+") do
            results[#results + 1] = part
        end
        return results
    end
    engineVersion = Split(Engine.version, '-')
    if engineVersion[2] ~= nil and engineVersion[3] ~= nil then
        engineVersion = tonumber(string.gsub(engineVersion[1], '%.', '')..engineVersion[2])
    else
        engineVersion = tonumber(Engine.version)
    end
elseif Game and Game.version then
    engineVersion = tonumber(Game.version)
end

if (engineVersion < 1000 and engineVersion >= 105) or engineVersion >= 10401354 then

    function gadget:GetInfo()
      return {
        name      = "Continuous Aim",
        desc      = "Applies lower 'reaimTime for continuous aim'",
        author    = "Doo",
        date      = "April 2018",
        license   = "Whatever works",
        layer     = 0,
        enabled   = true, -- When we will move on 105 :)
      }
    end

    if (not gadgetHandler:IsSyncedCode()) then return end

    function gadget:UnitCreated(unitID)
        for id, table in pairs(UnitDefs[Spring.GetUnitDefID(unitID)].weapons) do
            Spring.SetUnitWeaponState(unitID, id, "reaimTime", 3)
        end
    end
end