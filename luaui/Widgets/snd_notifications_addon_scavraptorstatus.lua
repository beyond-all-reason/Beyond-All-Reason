function widget:GetInfo()
    return {
    name      = "PvE Status Notifications",
    desc      = "Sends PvE status events to the Notification Widget",
    author    = "Damgam",
    date      = "2025",
    layer     = 5,
    enabled   = true  --  loaded by default?
    }
end

if not (Spring.Utilities.Gametype.IsRaptors() and not Spring.Utilities.Gametype.IsScavengers()) then
	return false
end

local PlayedMessages = {}

UpdateTimer = 0
function widget:Update(dt)
    UpdateTimer = UpdateTimer+dt
    if UpdateTimer >= 1 then
        UpdateTimer = UpdateTimer - 1

        if Spring.Utilities.Gametype.IsRaptors() then
            FinalBossProgress = Spring.GetGameRulesParam("raptorQueenAnger")
            FinalBossHealth = Spring.GetGameRulesParam("raptorQueenHealth")
            TechProgress = Spring.GetGameRulesParam("raptorTechAnger")

            if TechProgress and TechProgress >= 50 and not PlayedMessages["AntiNukeReminder1"] then
                WG['notifications'].queueNotification("PvE/AntiNukeReminder")
                PlayedMessages["AntiNukeReminder1"] = true
            end
            if TechProgress and TechProgress >= 60 and not PlayedMessages["AntiNukeReminder2"] then
                WG['notifications'].queueNotification("PvE/AntiNukeReminder")
                PlayedMessages["AntiNukeReminder2"] = true
            end
            if TechProgress and TechProgress >= 65 and not PlayedMessages["AntiNukeReminder3"] then
                WG['notifications'].queueNotification("PvE/AntiNukeReminder")
                PlayedMessages["AntiNukeReminder3"] = true
            end

            if FinalBossProgress ~= nil and FinalBossHealth ~= nil and FinalBossProgress < 100 then
                if FinalBossProgress >= 50 and not PlayedMessages["FinalBossProgress50"] then
                    WG['notifications'].queueNotification("PvE/Raptor_Queen50Ready")
                    PlayedMessages["FinalBossProgress50"] = true
                end
                if FinalBossProgress >= 75 and not PlayedMessages["FinalBossProgress75"] then
                    WG['notifications'].queueNotification("PvE/Raptor_Queen75Ready")
                    PlayedMessages["FinalBossProgress75"] = true
                end
                if FinalBossProgress >= 90 and not PlayedMessages["FinalBossProgress90"] then
                    WG['notifications'].queueNotification("PvE/Raptor_Queen90Ready")
                    PlayedMessages["FinalBossProgress90"] = true
                end
                if FinalBossProgress >= 95 and not PlayedMessages["FinalBossProgress95"] then
                    WG['notifications'].queueNotification("PvE/Raptor_Queen95Ready")
                    PlayedMessages["FinalBossProgress95"] = true
                end
                if FinalBossProgress >= 98 and not PlayedMessages["FinalBossProgress98"] then
                    WG['notifications'].queueNotification("PvE/Raptor_Queen98Ready")
                    PlayedMessages["FinalBossProgress98"] = true
                end

                if FinalBossIsAlive and FinalBossHealth <= 0 and not PlayedMessages["FinalBossIsDestroyed"] then
                    WG['notifications'].queueNotification("PvE/Raptor_QueenIsDestroyed")
                    PlayedMessages["FinalBossIsDestroyed"] = true
                    if Spring.GetModOptions().scav_endless then
                        FinalBossIsAlive = false
                        PlayedMessages = {}
                    end
                end
            end

            if FinalBossHealth ~= nil and FinalBossProgress ~= nil and FinalBossHealth > 0 then
                FinalBossIsAlive = true
                if FinalBossProgress >= 100 and not PlayedMessages["FinalBossProgress100"] then
                    WG['notifications'].queueNotification("PvE/Raptor_QueenIsReady")
                    PlayedMessages["FinalBossProgress100"] = true
                end
                if FinalBossHealth <= 50 and not PlayedMessages["FinalBossHealth50"] then
                    WG['notifications'].queueNotification("PvE/Raptor_Queen50HealthLeft")
                    PlayedMessages["FinalBossHealth50"] = true
                end
                if FinalBossHealth <= 25 and not PlayedMessages["FinalBossHealth25"] then
                    WG['notifications'].queueNotification("PvE/Raptor_Queen25HealthLeft")
                    PlayedMessages["FinalBossHealth25"] = true
                end
                if FinalBossHealth <= 10 and not PlayedMessages["FinalBossHealth10"] then
                    WG['notifications'].queueNotification("PvE/Raptor_Queen10HealthLeft")
                    PlayedMessages["FinalBossHealth10"] = true
                end
                if FinalBossHealth <= 5 and not PlayedMessages["FinalBossHealth5"] then
                    WG['notifications'].queueNotification("PvE/Raptor_Queen5HealthLeft")
                    PlayedMessages["FinalBossHealth5"] = true
                end
                if FinalBossHealth <= 2 and not PlayedMessages["FinalBossHealth2"] then
                    WG['notifications'].queueNotification("PvE/Raptor_Queen2HealthLeft")
                    PlayedMessages["FinalBossHealth2"] = true
                end
            end




        elseif Spring.Utilities.Gametype.IsScavengers() then
            FinalBossProgress = Spring.GetGameRulesParam("scavBossAnger")
            FinalBossHealth = Spring.GetGameRulesParam("scavBossHealth")
            TechProgress = Spring.GetGameRulesParam("scavTechAnger")

            if TechProgress and TechProgress >= 50 and not PlayedMessages["AntiNukeReminder1"] then
                WG['notifications'].queueNotification("PvE/AntiNukeReminder")
                PlayedMessages["AntiNukeReminder1"] = true
            end
            if TechProgress and TechProgress >= 60 and not PlayedMessages["AntiNukeReminder2"] then
                WG['notifications'].queueNotification("PvE/AntiNukeReminder")
                PlayedMessages["AntiNukeReminder2"] = true
            end
            if TechProgress and TechProgress >= 65 and not PlayedMessages["AntiNukeReminder3"] then
                WG['notifications'].queueNotification("PvE/AntiNukeReminder")
                PlayedMessages["AntiNukeReminder3"] = true
            end


            if FinalBossProgress ~= nil and FinalBossHealth ~= nil and FinalBossProgress < 100 then
                if FinalBossProgress >= 50 and not PlayedMessages["FinalBossProgress50"] then
                    WG['notifications'].queueNotification("PvE/Scav_Boss50Ready")
                    PlayedMessages["FinalBossProgress50"] = true
                end
                if FinalBossProgress >= 75 and not PlayedMessages["FinalBossProgress75"] then
                    WG['notifications'].queueNotification("PvE/Scav_Boss75Ready")
                    PlayedMessages["FinalBossProgress75"] = true
                end
                if FinalBossProgress >= 90 and not PlayedMessages["FinalBossProgress90"] then
                    WG['notifications'].queueNotification("PvE/Scav_Boss90Ready")
                    PlayedMessages["FinalBossProgress90"] = true
                end
                if FinalBossProgress >= 95 and not PlayedMessages["FinalBossProgress95"] then
                    WG['notifications'].queueNotification("PvE/Scav_Boss95Ready")
                    PlayedMessages["FinalBossProgress95"] = true
                end
                if FinalBossProgress >= 98 and not PlayedMessages["FinalBossProgress98"] then
                    WG['notifications'].queueNotification("PvE/Scav_Boss98Ready")
                    PlayedMessages["FinalBossProgress98"] = true
                end

                if FinalBossIsAlive and FinalBossHealth <= 0 and not PlayedMessages["FinalBossIsDestroyed"] then
                    WG['notifications'].queueNotification("PvE/Scav_BossIsDestroyed")
                    PlayedMessages["FinalBossIsDestroyed"] = true
                    if Spring.GetModOptions().scav_endless then
                        FinalBossIsAlive = false
                        PlayedMessages = {}
                    end
                end
            end


            if FinalBossHealth ~= nil and FinalBossProgress ~= nil and FinalBossHealth > 0 then
                FinalBossIsAlive = true
                if FinalBossProgress >= 100 and not PlayedMessages["FinalBossProgress100"] then
                    WG['notifications'].queueNotification("PvE/Scav_BossIsReady")
                    PlayedMessages["FinalBossProgress100"] = true
                end
                if FinalBossHealth <= 50 and not PlayedMessages["FinalBossHealth50"] then
                    WG['notifications'].queueNotification("PvE/Scav_Boss50HealthLeft")
                    PlayedMessages["FinalBossHealth50"] = true
                end
                if FinalBossHealth <= 25 and not PlayedMessages["FinalBossHealth25"] then
                    WG['notifications'].queueNotification("PvE/Scav_Boss25HealthLeft")
                    PlayedMessages["FinalBossHealth25"] = true
                end
                if FinalBossHealth <= 10 and not PlayedMessages["FinalBossHealth10"] then
                    WG['notifications'].queueNotification("PvE/Scav_Boss10HealthLeft")
                    PlayedMessages["FinalBossHealth10"] = true
                end
                if FinalBossHealth <= 5 and not PlayedMessages["FinalBossHealth5"] then
                    WG['notifications'].queueNotification("PvE/Scav_Boss5HealthLeft")
                    PlayedMessages["FinalBossHealth5"] = true
                end
                if FinalBossHealth <= 2 and not PlayedMessages["FinalBossHealth2"] then
                    WG['notifications'].queueNotification("PvE/Scav_Boss2HealthLeft")
                    PlayedMessages["FinalBossHealth2"] = true
                end
            end
        end
    end
end