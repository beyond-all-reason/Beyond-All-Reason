function gadget:GetInfo()
    return {
        name      = "GeoVent Sounds",
        desc      = "Plays sound effect over geovents",
        author    = "Damgam",
        date      = "2023",
        license   = "GNU GPL, v2 or later",
        version   = 1,
        layer     = 5,
        enabled   = true  --  loaded by default?
    }
end

local geoVentPositions = {}
local currentGeoVentID = 1
local numberOfGeoVentPositions = 0
local soundSplitTime = 120
local collectedFeatures = false
function gadget:GameFrame(n)
    if n == 90 then -- Collect all geo features, slightly delayed because of the opening animation and stuff might spawn new features at the start
        local allFeatures = Spring.GetAllFeatures()
        for i = 1,#allFeatures do -- loop through all features on the map
            if FeatureDefs[Spring.GetFeatureDefID(allFeatures[i])].geoThermal then -- isGeoSpot
                local x,y,z = Spring.GetFeaturePosition(allFeatures[i])
                local allowGeo = true
                for i = 1,#geoVentPositions do -- Check for duplicate geo vent spots, we don't want that.
                    local posx = geoVentPositions[i].x
                    local posy = geoVentPositions[i].y
                    local posz = geoVentPositions[i].z
                    if (x > posx-64 and x < posx+64) and (z > posz-64 and z < posz+64) then
                        allowGeo = false
                    end
                end
                if allowGeo then -- it's not a duplicate, let's add it to the list
                    geoVentPositions[#geoVentPositions+1] = {x = x, y = y, z = z}
                    numberOfGeoVentPositions = numberOfGeoVentPositions + 1
                end
            end
        end
        if numberOfGeoVentPositions > 0 then -- avoid dividing by zero
            soundSplitTime = math.ceil(soundSplitTime/numberOfGeoVentPositions)
        end
    end

    if n > 90 and numberOfGeoVentPositions > 0 then
        if n%soundSplitTime == 0 then -- play sound
            local posx = geoVentPositions[currentGeoVentID].x
            local posy = geoVentPositions[currentGeoVentID].y
            local posz = geoVentPositions[currentGeoVentID].z
            Spring.PlaySoundFile("geoventshort", 0.5, posx, posy, posz, 'sfx')
            currentGeoVentID = currentGeoVentID + 1
            if currentGeoVentID > numberOfGeoVentPositions then -- we've played sound for all of them, repeat the loop.
                currentGeoVentID = 1
            end
        end
    end
end