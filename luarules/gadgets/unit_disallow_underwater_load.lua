
function gadget:GetInfo()
   return {
	  name = "UnderwaterPickup",
	  desc = "Disallow loading of underwater units",
	  author = "Doo",
	  date = "2018",
	  license = "PD",
	  layer = 0,
	  enabled = true,
   }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
if (gadgetHandler:IsSyncedCode()) then
	function gadget:AllowUnitTransport(transporterID, transporterUnitDefID, transporterTeam, transporteeID, transporteeUnitDefID, transporteeTeam)
		local _,y,_ = Spring.GetUnitPosition(transporteeID)
		local height = Spring.GetUnitHeight(transporteeID)
		if y + height < 0 then
			return false
		else
			return true
		end
		return true
	end
end