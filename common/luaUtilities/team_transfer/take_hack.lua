
-- TODO: remove this function when we refactor /take out of the engine and into the game lua
return function CheckTakeCondition(senderTeamID, receiverTeamID)
  -- Check if sender is allied
  if Spring.AreTeamsAllied(senderTeamID, receiverTeamID) then
    -- Loop to see if sender has any active human players
    local playerList = Spring.GetPlayerList() or {}
    for _, playerID in ipairs(playerList) do
      local _, active, spectator, teamID = Spring.GetPlayerInfo(playerID)
      if active and not spectator and teamID == senderTeamID then
        -- Found an active player, so this is NOT the /take condition.
        return false
      end
    end
    -- If loop finished without finding an active player, it matches the /take condition.
    -- Allow the transfer, bypassing sharing rules.
    return true
  end
  return false
end