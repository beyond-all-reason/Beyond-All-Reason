function widget:GetInfo()
    return {
      name = "Mapmark Ping",
      desc = "Plays a sound when a point mapmark is placed by an allied player.",
      author = "hihoman23",
      date = "Jun 2024",
      license = "GNU GPL, v2 or later",
      layer = 0,
      enabled = true
    }
end

local mapmarkFile = "sounds/ui/mappoint2.wav"
local volume = 0.5

local PlaySoundFile = Spring.PlaySoundFile

function widget:MapDrawCmd(playerID, cmdType, x, y, z, a, b, c)
    if cmdType == "point" then
        PlaySoundFile( mapmarkFile, volume, x, y, z, nil, nil, nil, "ui")
    end
end