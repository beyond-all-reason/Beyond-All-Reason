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

if true then
    return -- kill it for now
end

if not gadgetHandler:IsSyncedCode() then
    return
end

local colors = {"pink","white","red", "blue", "darkgreen", "purple", "green", "yellow", "darkred", "acidgreen"}

function spawnRandomEggField(x,y,z)

    local featureValueMetal = 5
    local featureValueEnergy = 50
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

        local egg = Spring.CreateFeature("raptor_egg_"..size.."_"..color, x+math.random(-600,600), y + 20, z+math.random(-600,600), math.random(-999999,999999), Spring.GetGaiaTeamID())
        if egg then
            Spring.SetFeatureMoveCtrl(egg, false,1,1,1,1,1,1,1,1,1)
            --Spring.SetFeatureVelocity(egg, math.random(-600,600)*0.01, math.random(200,400)*0.01, math.random(-600,600)*0.01)
            Spring.SetFeatureResources(egg, featureValueMetal, featureValueEnergy, featureValueMetal*10, 1.0, featureValueMetal, featureValueEnergy)
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
                    spawnRandomEggField(spot.x, Spring.GetGroundHeight(spot.x, spot.z), spot.z)
                end
            end
        end
    end
end