if not gadgetHandler:IsSyncedCode() then
	return false
end

local gadgetEnabled = false
if Engine.Shared.GetModOptions().disable_fogofwar then
	gadgetEnabled = true
end

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "FogOfWarRemover",
		desc = "123",
		author = "Damgam",
		date = "2021",
		license = "GNU GPL, v2 or later",
		layer = -100,
		enabled = gadgetEnabled,
	}
end

local spGetAllyTeamList = Engine.Shared.GetAllyTeamList

function gadget:GameFrame(n)
	if n % 1800 == 10 then
		local allyteams = spGetAllyTeamList()
		for i = 1, #allyteams do
			local allyTeamID = allyteams[i]
			Engine.Synced.SetGlobalLos(allyTeamID, true)
		end
	end
end
