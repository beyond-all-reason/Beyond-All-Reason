local widget = widget ---@type Widget

function widget:GetInfo()
    return {
      name = "Mapmark Ping",
      desc = "Plays a sound when a point mapmark is placed by an allied player.",
      author = "hihoman23",
      date = "June 2024",
      license = "GNU GPL, v2 or later",
      layer = 0,
      enabled = true
    }
end

local mapmarkFile = "sounds/ui/mappoint2.wav"
local volume = 0.6

function widget:Initialize()
	WG['mapmarkping'] = {}
	WG['mapmarkping'].getMapmarkVolume = function()
		return volume
	end
	WG['mapmarkping'].setMapmarkVolume = function(value)
		volume = value
	end
end

function widget:MapDrawCmd(playerID, cmdType, x, y, z, a, b, c)
    if cmdType == "point" then
		Spring.PlaySoundFile( mapmarkFile, volume*20, x, y, z, nil, nil, nil, "ui")
		Spring.PlaySoundFile( mapmarkFile, volume*0.3, nil, "ui" )	-- to make sure it's still somewhat audible when far away
    end
end

function widget:GetConfigData(data)
	return {
		volume = volume,
	}
end

function widget:SetConfigData(data)
	if data.volume ~= nil then
		volume = data.volume
	end
end
