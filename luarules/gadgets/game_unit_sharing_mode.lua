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

local unitSharingMode = Spring.GetModOptions().unit_sharing_mode or "enabled"
local unitMarketEnabled = Spring.GetModOptions().unit_market or false

-- Disable the gadget only if unit sharing is fully enabled
if unitSharingMode == "enabled" then
	return false
end

-- Flags for specific transfer types initiated by *other Lua gadgets* (like Unit Market)
-- that should cleanly bypass this gadget's sharing mode restrictions.
-- Other gadgets initiating transfers that need to bypass sharing rules should:
-- 1. Choose a unique, descriptive flag name (string) using snake_case.
-- 2. Add the name to this table.
-- 3. Call Spring.SetUnitRulesParam(unitID, flagName, 1) BEFORE calling TransferUnit.
-- This gadget will detect the flag, allow the transfer, and clear the flag by setting it to nil.
local transferOverrideFlags = {
	"transfer_override_market",
	-- Note: takeCommand logic uses a separate check function due to engine limitations.
}

local function isT2Constructor(unitDef)
	if not unitDef then return false end

	return not unitDef.isFactory
			and #(unitDef.buildOptions or {}) > 0
			and unitDef.customParams.techlevel == "2"
end

-- Handles the specific condition for allowing /take transfers
-- Returns true if the transfer should be allowed due to being a /take, false otherwise.
local function CheckTakeCondition(fromTeamID, toTeamID)
	-- Check if sender is allied
	if Spring.AreTeamsAllied(fromTeamID, toTeamID) then
		-- Loop to see if sender has any active human players
		for _, playerID in ipairs(Spring.GetPlayerList()) do
			local _, active, spectator, teamID = Spring.GetPlayerInfo(playerID)
			if active and not spectator and teamID == fromTeamID then
				-- Found an active player, so this is NOT the /take condition.
				-- AllowUnitTransfer should proceed to check sharing rules.
				return false
			end
		end
		-- If loop finished without finding an active player, it matches the /take condition.
		-- Allow the transfer, bypassing sharing rules.
		return true
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
	-- 1. Check for clean override flags (e.g., Market)
	for _, flagName in ipairs(transferOverrideFlags) do
		local flagValue = Spring.GetUnitRulesParam(unitID, flagName)
		if flagValue and flagValue == 1 then
			-- Clear the flag after checking
			Spring.SetUnitRulesParam(unitID, flagName, nil)
			return true
		end
	end

	-- 2. Check for /take command condition (Allied sender, no active players)
	if CheckTakeCondition(fromTeamID, toTeamID) then
		return true
	end

	-- 3. Allow engine-managed transfers (where capture=true is set by engine)
	if capture then
		return true
	end

	-- 4. Check sharing mode if none of the above bypass conditions were met
	if unitSharingMode == "disabled" then
		return false
	elseif unitSharingMode == "t2cons" then
		local allow = isT2Constructor(UnitDefs[unitDefID])
		return allow
	end

	-- Fallback: Allow if mode is 'enabled' (though gadget disables itself) or unknown
	return true
end

