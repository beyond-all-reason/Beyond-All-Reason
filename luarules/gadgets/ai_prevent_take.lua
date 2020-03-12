function gadget:GetInfo()
	return {
		name = "AI Prevent Take",
		desc = "Prevent players from taking AI team units with /take",
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
	if select(4,Spring.GetTeamInfo(teamID,false)) then	-- is AI?
		aiCount = aiCount + 1
		aiTeams[teamID] = true
	end
end
if aiCount == 0 then
	return
end

function gadget:AllowUnitTransfer(unitID, unitDefID, oldTeam, newTeam, capture)
    local UnitName = UnitDefs[unitDefID].name
	if (aiTeams[oldTeam] and not string.find(UnitName, "_scav")) or aiTeams[newTeam] then
		return false
	else
		return true
	end
end