local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Prevent Excessive Share",
		desc = "Prevents sharing more resources or units than the receiver can hold",
		author = "Niobium",
		date = "April 2012",
		license = "GNU GPL, v2 or later",
		layer = 2, -- after 'Tax Resource Sharing'
		enabled = true,
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
local pendingUnitCaps = {} ---@type table<UnitID, TeamID[]>

----------------------------------------------------------------
-- Callins
----------------------------------------------------------------
function gadget:AllowResourceTransfer(senderTeamId, receiverTeamId, resourceType, amount)
	-- Spring uses 'm' and 'e' instead of the full names that we need, so we need to convert the resourceType
	-- We also check for 'metal' or 'energy' in case Spring decides to use those in a later version
	local resourceName
	if (resourceType == "m") or (resourceType == "metal") then
		resourceName = "metal"
	elseif (resourceType == "e") or (resourceType == "energy") then
		resourceName = "energy"
	else
		-- We don't handle whatever this resource is, allow it
		return true
	end

	-- Calculate the maximum amount the receiver can receive
	local rCur, rStor, rPull, rInc, rExp, rShare = Spring.GetTeamResources(receiverTeamId, resourceName)
	local maxShare = rStor * rShare - rCur

	-- Is the sender trying to send more than the maximum? Block it, possibly sending a reduced amount instead
	if amount > maxShare then
		if maxShare > 0 then
			Spring.ShareTeamResource(senderTeamId, receiverTeamId, resourceName, maxShare)
		end
		return false
	end

	-- Allow anything we don't explicitly block
	return true
end

function gadget:AllowUnitTransfer(unitID, unitDefID, oldTeam, newTeam, capture)
	pendingUnitCaps[unitID] = nil
	local unitCount = spGetTeamUnitCount(newTeam)
	if
		capture
		or spIsCheatingEnabled()
		or unitCount < Spring.GetTeamMaxUnits(newTeam)
		or (GG.IsTakingTeam and GG.IsTakingTeam(oldTeam, newTeam))
	then
		return true
	end
	if unitCount == Spring.GetTeamMaxUnits(newTeam) and GG.CanShareUnitCap and GG.CanShareUnitCap(oldTeam, newTeam) then
		pendingUnitCaps[unitID] = { oldTeam, newTeam }
		return true
	end
	return false
end

function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	local pending = pendingUnitCaps[unitID]
	pendingUnitCaps[unitID] = nil
	if pending and pending[1] == oldTeam and pending[2] == newTeam then
		-- The unit has left the donor, so even a previously full team can give up its slot.
		Spring.TransferTeamMaxUnits(oldTeam, newTeam, 1)
	end
end

function gadget:UnitDestroyed(unitID)
	pendingUnitCaps[unitID] = nil
end
