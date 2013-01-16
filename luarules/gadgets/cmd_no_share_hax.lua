function gadget:GetInfo()
	return {
		name      = "NoShareHax",
		desc      = "Prevents negative res transfer",
		author    = "doesntmatter",
		date      = "Jan 2013",
		license   = "WTFPL",
		layer     = 0,
		enabled   = true  --  loaded by default?
	}
end

if (gadgetHandler:IsSyncedCode()) then
	function gadget:AllowResourceTransfer(oldTeam, newTeam, restype, amount)
		if(amount < 0) then return end
	end
end
