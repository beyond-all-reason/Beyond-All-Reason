local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = "GeoVent Sounds",
        desc      = "Plays sound effect over geovents",
        author    = "Damgam",
        date      = "2023",
        license   = "GNU GPL, v2 or later",
        version   = 1,
        layer     = 5,
        enabled   = true
    }
end

if gadgetHandler:IsSyncedCode() then
	return false
end

local data = {
    map_sizeX = Game.mapSizeX,  -- no touchies
    map_sizeZ = Game.mapSizeZ,  -- no touchies
    map_minHeight = Spring.GetGroundExtremes(),  -- no touchies
    map_maxHeight = select(2, Spring.GetGroundExtremes()),  -- no touchies
    map_voidWater = false,  -- no touchies

    geo_ventPositions = {},  -- no touchies
    geo_currentGeoVentID = 1,   -- no touchies
    geo_numberOfGeoVentPositions = 0,  -- no touchies
    geo_soundDelay = 125,

    wind_lastSoundFrame = 0, -- no touchies
    wind_soundDelay = 60,
    wind_minHeight = select(2, Spring.GetGroundExtremes())*0.6,
    wind_maxHeight = select(2, Spring.GetGroundExtremes()),
    wind_soundBank = {"windy1", "windy2", "windy3", "windy4", "windy5", },
    wind_rareSoundBank = {"windy1", "windy2", "windy3", "windy4", "windy5", },

    sea_lastSoundFrame = 0, -- no touchies
    sea_soundDelay = 60,
    sea_minDepth = -23,
    sea_soundBank = {"beach1", "beach2", "beach3", "beach4", "beach5", "beach6", },
    sea_rareSoundBank = {"beach1", "beach2", "beach3", "beach4", "beach5", "beach6", },

    beach_lastSoundFrame = 0, -- no touchies
    beach_soundDelay = 60,
    beach_maxDepth = -19,
    beach_soundBank = {"ocean1", "ocean2", "ocean3", "ocean4", "ocean5", "ocean6", },
    beach_rareSoundBank = {"ocean1", "ocean2", "ocean3", "ocean4", "ocean5", "ocean6", },
}





function UpdateAllData()
    data.map_voidWater = gl.GetMapRendering("voidWater")
end

function CollectGeoVentPositions()
    local allFeatures = Spring.GetAllFeatures()
    for i = 1,#allFeatures do -- loop through all features on the map
        if FeatureDefs[Spring.GetFeatureDefID(allFeatures[i])].geoThermal then -- isGeoSpot
            local x,y,z = Spring.GetFeaturePosition(allFeatures[i])
            local allowGeo = true
            for i = 1,#data.geo_ventPositions do -- Check for duplicate geo vent spots, we don't want that.
                local posx = data.geo_ventPositions[i].x
                local posz = data.geo_ventPositions[i].z
                if (x > posx-64 and x < posx+64) and (z > posz-64 and z < posz+64) then
                    allowGeo = false
                end
            end
            if allowGeo then -- it's not a duplicate, let's add it to the list
                data.geo_ventPositions[#data.geo_ventPositions+1] = {x = x, y = y, z = z}
                data.geo_numberOfGeoVentPositions = data.geo_numberOfGeoVentPositions + 1
            end
        end
    end
    if data.geo_numberOfGeoVentPositions > 0 then -- avoid dividing by zero
        data.geo_soundDelay = math.ceil(data.geo_soundDelay/data.geo_numberOfGeoVentPositions)
    end
end

function PlayGeoVentSound()
    local randomposx = data.geo_ventPositions[data.geo_currentGeoVentID].x
    local randomposz = data.geo_ventPositions[data.geo_currentGeoVentID].z
    local randomposy = data.geo_ventPositions[data.geo_currentGeoVentID].y
    if Spring.IsSphereInView(randomposx,randomposy,randomposz) then
        Spring.PlaySoundFile("geoventshort", 0.25, randomposx, randomposy, randomposz, 'sfx')
    end
    data.geo_currentGeoVentID = data.geo_currentGeoVentID + 1
    if data.geo_currentGeoVentID > data.geo_numberOfGeoVentPositions then -- we've played sound for all of them, repeat the loop.
        data.geo_currentGeoVentID = 1
    end
end

function PlayWindSound(n) -- We want wind to play at volume depending on wind speed and height.
    local randomposx = math.random(0, data.map_sizeX)
    local randomposz = math.random(0, data.map_sizeZ)
    local randomposy = Spring.GetGroundHeight(randomposx, randomposz)
    if randomposy >= data.wind_minHeight and Spring.IsSphereInView(randomposx,randomposy + 400,randomposz) then
        local windSpeed = select(4, Spring.GetWind())/25
        if math.random() > 0.1 then
            Spring.PlaySoundFile(data.wind_soundBank[math.random(1,#data.wind_soundBank)], windSpeed*0.6, randomposx, (randomposy + 400), randomposz, 'sfx')
        else
            Spring.PlaySoundFile(data.wind_rareSoundBank[math.random(1,#data.wind_rareSoundBank)], windSpeed*0.6, randomposx, (randomposy + 400), randomposz, 'sfx')
        end
        data.wind_lastSoundFrame = n
    end
end

function PlaySeaSound(n) -- We want wind to play at volume depending on wind speed and height.
    local randomposx = math.random(0, data.map_sizeX)
    local randomposz = math.random(0, data.map_sizeZ)
    local randomposy = Spring.GetGroundHeight(randomposx, randomposz) 
    if randomposy <= data.sea_minDepth and Spring.IsSphereInView(randomposx,randomposy + 400,randomposz) then
        local windSpeed = select(4, Spring.GetWind())/25 
        if math.random() > 0.1 then
            Spring.PlaySoundFile(data.sea_soundBank[math.random(1,#data.sea_soundBank)], (0.10 + (windSpeed*0.75)), randomposx, (randomposy + 400), randomposz, 'sfx')
        else
            Spring.PlaySoundFile(data.sea_rareSoundBank[math.random(1,#data.sea_rareSoundBank)], (0.10 + (windSpeed*0.75)), randomposx, (randomposy + 400), randomposz, 'sfx')
        end
        data.sea_lastSoundFrame = n
    end
end

function PlayBeachSound(n) -- We want wind to play at volume depending on wind speed and height.
    local randomposx = math.random(0, data.map_sizeX)
    local randomposz = math.random(0, data.map_sizeZ)
    local randomposy = Spring.GetGroundHeight(randomposx, randomposz)
    if randomposy < 0 and randomposy >= data.beach_maxDepth and Spring.IsSphereInView(randomposx,randomposy,randomposz) then
        local windSpeed = select(4, Spring.GetWind())/25 
        if math.random() > 0.1 then
            Spring.PlaySoundFile(data.beach_soundBank[math.random(1,#data.beach_soundBank)], (0.20 + (windSpeed*0.6)), randomposx, (randomposy + 400), randomposz, 'sfx')
        else
            Spring.PlaySoundFile(data.beach_rareSoundBank[math.random(1,#data.beach_rareSoundBank)], (0.20 + (windSpeed*0.6)), randomposx, (randomposy + 400), randomposz, 'sfx')
        end
        data.beach_lastSoundFrame = n
    end
end








function gadget:GameFrame(n)
    -- Collect data for sounds.
    if n == 90 then 
        CollectGeoVentPositions()
        UpdateAllData()
    end

    if n > 90 then

        if data.geo_numberOfGeoVentPositions > 0 then
            if n%data.geo_soundDelay == 0 then -- play sound
                PlayGeoVentSound()
            end
        end

        if n >= data.wind_lastSoundFrame+data.wind_soundDelay then
            PlayWindSound(n)
        end

        if not data.map_voidWater then -- Only play water sounds on maps with water

            if n >= data.sea_lastSoundFrame+data.sea_soundDelay then
                PlaySeaSound(n)
            end

            if n >= data.beach_lastSoundFrame+data.beach_soundDelay then
                PlayBeachSound(n)
            end

        end

    end

end