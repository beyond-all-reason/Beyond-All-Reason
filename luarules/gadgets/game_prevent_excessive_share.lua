local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = 'Prevent Excessive Share',
		desc    = 'Prevents sharing more resources or units than the receiver can hold',
		author  = 'Niobium',
		date    = 'April 2012',
		license = 'GNU GPL, v2 or later',
		layer   = 2, -- after 'Tax Resource Sharing'
		enabled = true
	}
end

----------------------------------------------------------------
-- Synced only
----------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then
	return false
end

local spIsCheatingEnabled = Spring.IsCheatingEnabled
local spGetTeamUnitCount = Spring.GetTeamUnitCount

----------------------------------------------------------------
-- Callins
----------------------------------------------------------------
---@deprecated
--- game_tax_resource_sharing.lua is now the undivided emporer of economic policy.
--- It always prevents out of bounds transfers. It sometimes has a tax rate of 0.
-- function gadget:AllowResourceTransfer(senderTeamId, receiverTeamId, resourceType, amount)

--TODO: This should probably be moved somewhere that is named correctly: game_unit_sharing_mode?
function gadget:AllowUnitTransfer(unitID, unitDefID, oldTeam, newTeam, capture)
	local unitCount = spGetTeamUnitCount(newTeam)
	if capture or spIsCheatingEnabled() or unitCount < Spring.GetTeamMaxUnits(newTeam) then
		return true
	end
	return false
end
