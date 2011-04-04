
function gadget:GetInfo()
	return {
		name = "Start Point Remover Gadget",
		desc = "Deletes start points once the game begins",
		author = "zwzsg",
		date = "October 8th, 2009",
		license = "Free",
		layer = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	function gadget:DrawScreen()
		local frame=Spring.GetGameFrame()
		if frame>=2 then
			for _,team in ipairs(Spring.GetTeamList()) do
				local x,y,z = Spring.GetTeamStartPosition(team)
				Spring.MarkerErasePosition(x or 0, y or 0, z or 0)
			end
		end
		if frame>=2 then
			gadgetHandler:RemoveGadget()
		end
	end
end
