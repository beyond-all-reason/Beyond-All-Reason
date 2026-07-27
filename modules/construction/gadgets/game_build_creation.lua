
function gadget:GetInfo()
	return {
		name = "Construction Creation",
		desc = "Applies construction's creation decision: which defs each team may build at all",
		author = "BAR modules",
		layer = 1, -- after api_build_blocking has set up GG.BuildBlocking
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local Creation = VFS.Include("modules/construction/lib/creation.lua")

function gadget:GameStart()
	for _, teamID in ipairs(Spring.GetTeamList()) do
		Creation.Refresh(teamID, Spring)
	end
end
