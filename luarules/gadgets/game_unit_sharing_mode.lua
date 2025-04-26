local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = 'Unit Sharing Control',
		desc    = 'Controls unit sharing based on modoption settings',
		author  = 'Rimilel',
		date    = 'May 2024 / April 2025',
		license = 'GNU GPL, v2 or later',
		layer   = 0,
		enabled = true
	}
end

----------------------------------------------------------------
-- Synced only
----------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then
	return false
end

---@type UnitSharing
local sharing = VFS.Include("common/unit_sharing.lua")
local unitSharingMode = sharing.getUnitSharingMode()
local unitMarketEnabled = Spring.GetModOptions().unit_market or false

-- Disable the gadget only if unit sharing is fully enabled
if unitSharingMode == "enabled" then
	return false
end

-- Handles the specific condition for allowing /take transfers
-- Returns true if the transfer should be allowed due to being a /take, false otherwise.
local function CheckTakeCondition(fromTeamID, toTeamID)
	-- Check if sender is allied
	if Spring.AreTeamsAllied(fromTeamID, toTeamID) then
		-- If fromTeamID has no active players, it's a /take situation from a dead team.
		-- In this case, we bypass sharing rules by returning true here.
		local teamPlayers = Spring.GetPlayerList(fromTeamID, true) -- excludes inactive and spectators
		if next(teamPlayers) == nil then
			return true
		end
	end
	-- Teams are not allied, not a /take condition.
	return false
end

--[[ Determines if *this gadget* allows a unit transfer based on current rules.
     Engine Behavior: The engine blocks the transfer if *any* gadget returns false.
     Return Value: Returning true here only means *this* gadget doesn't object;
       other gadgets might still block the transfer. Returning false blocks immediately.
]]
function gadget:AllowUnitTransfer(unitID, unitDefID, fromTeamID, toTeamID, capture)
	if capture then
		return true
	end

	-- 2. Check for /take command condition (Allied sender, no active players)
	if CheckTakeCondition(fromTeamID, toTeamID) then
		return true
	end

	-- 3. Delegate to shared rules for final decision
	return sharing.isUnitShareAllowedByMode(unitDefID)
end
