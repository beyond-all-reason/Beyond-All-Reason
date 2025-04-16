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

--[[ Engine Callin Note: AllowUnitTransfer blocks if *any* gadget returns false.
     This gadget must therefore explicitly check for and allow certain transfer types
     (Market, /take, Capture) to prevent this gadget's rules (disabled/t2cons)
     from blocking valid engine or other gadget actions.
]]

-- Flags for specific transfer types that should cleanly bypass this gadget's sharing rules.
local transferOverrideFlags = {
	"marketTransferInProgress",
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
	-- Check if sender is allied and has no active human players
	if Spring.AreTeamsAllied(fromTeamID, toTeamID) then
		local senderHasActivePlayer = false
		for _, playerID in ipairs(Spring.GetPlayerList()) do
			local _, active, spectator, teamID = Spring.GetPlayerInfo(playerID)
			if active and not spectator and teamID == fromTeamID then
				senderHasActivePlayer = true
				break
			end
		end
		if not senderHasActivePlayer then
			-- This matches the condition where the engine's /take command would trigger GiveEverythingTo
			return true
		end
	end
	return false -- Not a /take condition
end

function gadget:AllowUnitTransfer(unitID, unitDefID, fromTeamID, toTeamID, capture)
	-- 1. Check for clean override flags (e.g., Market)
	for _, flagName in ipairs(transferOverrideFlags) do
		local flagValue = Spring.GetUnitRulesParam(unitID, flagName)
		if flagValue and flagValue == 1 then
			-- Clear the flag after checking
			Spring.SetUnitRulesParam(unitID, flagName, 0, {private=true})
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

	return true
end
