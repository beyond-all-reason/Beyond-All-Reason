
local gadgetEnabled = false
local teams = Spring.GetTeamList()

for i = 1,#teams do
	local luaAI = Spring.GetTeamLuaAI(teams[i])
	if luaAI and luaAI ~= "" and string.sub(luaAI, 1, 12) == 'ScavReduxAI' then
		gadgetEnabled = true
        ScavTeamID = teams[i]
        _,_,_,_,_,ScavAllyTeamID = Spring.GetTeamInfo(ScavTeamID)
        break
	end
end

function gadget:GetInfo()
    return {
      name      = "Scavengers Redux",
      desc      = "123",
      author    = "Damgam",
      date      = "2022",
	    license   = "GNU GPL, v2 or later",
      layer     = -100,
      enabled   = gadgetEnabled,
    }
end

if gadgetHandler:IsSyncedCode() then
	if gadgetEnabled then
		VFS.Include('luarules/gadgets/scavredux/main.lua')
	end
end
