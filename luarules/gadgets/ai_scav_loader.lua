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

-- synced only
if (not gadgetHandler:IsSyncedCode()) then
	return false
end


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

