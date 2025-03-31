
local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "UnderwaterPickup",
		desc = "Disallow loading/unloading of underwater units",
		author = "Doo",
		date = "2018",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if gadgetHandler:IsSyncedCode() then
	function gadget:AllowUnitTransport(transporterID, transporterUnitDefID, transporterTeam, transporteeID, transporteeUnitDefID, transporteeTeam)
		local _,y,_ = Spring.GetUnitPosition(transporteeID)
		local height = Spring.GetUnitHeight(transporteeID)
		if not height or y + height < 0 then
			return false
		else
			return true
		end
	end

	function gadget:AllowUnitTransportUnload(transporterID, transporterUnitDefID, transporterTeam, transporteeID, transporteeUnitDefID, transporteeTeam, x, y, z) -- disallow unloading underwater
		local height = Spring.GetUnitHeight(transporteeID)
		if not height or y + height < 0 then
			return false
		else
			return true
		end
	end

	function gadget:AllowUnitTransportLoad(transporterID, transporterUnitDefID, transporterTeam, transporteeID, transporteeUnitDefID, transporteeTeam, x, y, z) -- disallow unloading underwater
		local height = Spring.GetUnitHeight(transporteeID)
		if not height or y + height < 0 then
			return false
		else
			return true
		end
	end
end
