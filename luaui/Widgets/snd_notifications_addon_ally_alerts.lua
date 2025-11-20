function widget:GetInfo()
  return {
    name    = "Ally Request Listener",
    desc    = "Listens for resource requests and triggers notifications.",
    author  = "Inimitable_Wolf",
    version = "1.0",
    date    = "2025-11-18",
    license = "GPLv2",
    layer   = 0,
    enabled = true
  }
end

function widget:RecvLuaMsg(msg, playerID)
    -- Check for message types
    if msg ~= 'alert:allyRequest:energy' and msg ~= 'alert:allyRequest:metal' then
        return
    end

    -- Check sender is ally
    local myAllyTeamID = Spring.GetLocalAllyTeamID()
    local _, _, _, _, senderAllyTeamID = Spring.GetPlayerInfo(playerID, false)

    -- Ignore if not an ally
    if myAllyTeamID ~= senderAllyTeamID then
        return
    end
        
    if WG['notifications'] and WG['notifications'].queueNotification then
        
        -- Check which resource is being requested
        if msg == 'alert:allyRequest:energy' then
            WG['notifications'].queueNotification("AllyRequestEnergy")
            return true
            
        elseif msg == 'alert:allyRequest:metal' then
            WG['notifications'].queueNotification("AllyRequestMetal")
            return true
        end

    end
end