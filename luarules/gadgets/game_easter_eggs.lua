local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = "Easter Eggs Spawner",
        desc      = "Spawns Easter Eggs around metal deposits",
        author    = "Damgam",
        date      = "2024",
        license   = "GNU GPL, v2 or later",
        layer     = 0,
        enabled   = true
    }
end

if Spring.GetModOptions().easter_egg_hunt ~= true then
	return false
end

if not gadgetHandler:IsSyncedCode() then
    return false
end

local colors = {"pink","white","red", "blue", "darkgreen", "purple", "green", "yellow", "darkred", "acidgreen"}

function spawnRandomEggField(x,y,z, spread)

    local featureValueMetal = 4
    local featureValueEnergy = 40
    local size
    local color

    for i = 1,8 do
        if i <= 1 then
            size = "l"
            color = colors[math.random(#colors)]
        elseif i <= 3 then
            size = "m"
            color = colors[math.random(#colors)]
        else
            size = "s"
            color = colors[math.random(#colors)]
        end
        x = x+math.random(-spread,spread)
        y = y + 20
        z = z+math.random(-spread,spread)
        if x > 0 and x < Game.mapSizeX and z > 0 and z < Game.mapSizeZ then
            local egg = Spring.CreateFeature("raptor_egg_"..size.."_"..color, x, y, z, math.random(-999999,999999), Spring.GetGaiaTeamID())
            if egg then
                Spring.SetFeatureMoveCtrl(egg, false,1,1,1,1,1,1,1,1,1)
                Spring.SetFeatureResources(egg, featureValueMetal, featureValueEnergy, featureValueMetal*10, 1.0, featureValueMetal, featureValueEnergy)
            end
        end

    end
end

function gadget:GameFrame(frame)

    if frame == 7 then
        local metalSpots = GG["resource_spot_finder"] and GG["resource_spot_finder"].metalSpotsList or nil
        if metalSpots then
            for i = 1, #metalSpots do
                local spot = metalSpots[i]
                if spot then
                    spawnRandomEggField(spot.x, Spring.GetGroundHeight(spot.x, spot.z), spot.z, 600)
                end
            end
        else
            for i = 1,100 do
                local x = math.random(0, Game.mapSizeX)
                local z = math.random(0, Game.mapSizeZ)
                local y = Spring.GetGroundHeight(x, z)
                spawnRandomEggField(x, y, z, 1000)
            end
        end
    end
end
