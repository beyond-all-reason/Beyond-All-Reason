function gadget:GetInfo()
    return {
        name      = 'Merc/Scr stockpile control',
        desc      = 'Limits Mercury/Screamer stockpile to 5 missiles at any time',
        author    = 'Bluestone',
        version   = 'v1.0',
        date      = '23/04/2013',
        license   = 'WTFPL',
        layer     = 0,
        enabled   = true
    }
end

local mercDefID = UnitDefNames.mercury.id
local scrDefID = UnitDefNames.screamer.id

local CMD_STOCKPILE = CMD.STOCKPILE
local SpGiveOrderToUnit = Spring.GiveOrderToUnit

local pilelimit = 5

function gadget:AllowCommand(UnitID, UnitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, synced) -- Can't use StockPileChanged because that doesn't get called when the stockpile queue changes
	if UnitID and (UnitDefID == mercDefID or UnitDefID == scrDefID) then
		if cmdID == CMD_STOCKPILE then
			local pile,pileQ = Spring.GetUnitStockpile(UnitID)
			local addQ = 1
			if cmdOptions.shift then
				if cmdOptions.ctrl then
					addQ = 100
				else
					addQ = 5
				end
			elseif cmdOptions.ctrl then 
				addQ = 20
			end
			if cmdOptions.right then addQ = -addQ end

			if pile+pileQ == pilelimit and (not cmdOptions.right) then Spring.Echo("Stockpile queue is already full (max " .. tostring(pilelimit) .. ").") end
			
			if pile+pileQ+addQ <= pilelimit then 
				return true
			else
				if pile+pileQ <= pilelimit then 
					local added = 0
					local needed = pilelimit - pile - pileQ
					while added < needed do
					SpGiveOrderToUnit(UnitID, CMD_STOCKPILE, {}, { "" }) -- because SetUnitStockpile can't set the queue!
					added = added + 1
					end
					return false
				else
					return false
				end		
			end
		end
	end
	return true 
end


