
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

if (engineVersion < 1000 and engineVersion >= 105) or engineVersion >= 10401327 then

	function gadget:GetInfo()
	   return {
		  name = "UnderwaterPickup",
		  desc = "Disallow loading of underwater units",
		  author = "Doo",
		  date = "2018",
		  license = "PD",
		  layer = 0,
		  enabled = true,
	   }
	end

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	if (gadgetHandler:IsSyncedCode()) then
		function gadget:AllowUnitTransport(transporterID, transporterUnitDefID, transporterTeam, transporteeID, transporteeUnitDefID, transporteeTeam)
			local _,y,_ = Spring.GetUnitPosition(transporteeID)
			local height = Spring.GetUnitHeight(transporteeID)
			if y + height < 0 then	
				return false
			else
				return true
			end
			return true
		end
	end
	
end

