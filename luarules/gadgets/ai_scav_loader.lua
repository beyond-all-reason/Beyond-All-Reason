function gadget:GetInfo()
  return {
    name      = "loader for Scavenger mod",
    desc      = "123",
    author    = "Damgam",
    date      = "2019",
    layer     = -100,
    enabled   = true,
	}
end

if (not gadgetHandler:IsSyncedCode()) then

	function SendMessage(_,msg)
		if tonumber(Spring.GetConfigInt("scavmessages",1) or 1) == 1 then
			if Script.LuaUI("GadgetAddMessage") then
				Script.LuaUI.GadgetAddMessage(msg)
			end
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("SendMessage", SendMessage)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction("SendMessage")
	end

else

	scavengersEnabled = false
	if Spring.GetModOptions and (tonumber(Spring.GetModOptions().scavengers) or 0) ~= 0 then
		local teams = Spring.GetTeamList()

		for i = 1,#teams do
			local luaAI = Spring.GetTeamLuaAI(teams[i])
			if luaAI and luaAI ~= "" and string.sub(luaAI, 1, 12) == 'ScavengersAI' then
				scavengersEnabled = true
				scavengerAITeamID = i - 1
				break
			end
		end
		VFS.Include('luarules/gadgets/scavengers/boot.lua')
	end

end