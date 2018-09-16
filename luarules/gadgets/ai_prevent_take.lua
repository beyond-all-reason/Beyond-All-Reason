function gadget:GetInfo()
	return {
		name = "AI Prevent Take",
		desc = "Prevent players from taking AI tema units with /take",
		author = "Floris",
		date = "September 2018",
		license = "GPL",
		layer = 1,
		enabled = true
	}
end

if (not gadgetHandler:IsSyncedCode()) then
	return -- No Unsynced
end

local aiTeams = {}
local aiCount = 0
for _,teamID in ipairs(Spring.GetTeamList()) do
	if select(4,Spring.GetTeamInfo(teamID)) then	-- is AI?
		aiCount = aiCount + 1
		aiTeams[teamID] = true
	end
end
if aiCount == 0 then
	return
end

function gadget:AllowUnitTransfer(unitID, unitDefID, oldTeam, newTeam, capture)
	if aiTeams[oldTeam] then
		return false
	else
		return true
	end
end