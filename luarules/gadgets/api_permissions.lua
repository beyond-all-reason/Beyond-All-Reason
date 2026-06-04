
local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = "Permissions",
		desc	= 'provides a list of user permissions to other gadgets',
		author	= 'Floris',
		date	= 'February 2021',
		license	= 'GNU GPL, v2 or later',
		layer	= -999000,
		enabled	= true
	}
end


local powerusers = include("LuaRules/configs/powerusers.lua")
local singleplayerPermissions = powerusers[-1]
local isSinglePlayer = false

-- resolve trusted playernames (fallback when accountID is unavailable)
local trustedNames = powerusers.trustedNames
powerusers.trustedNames = nil
if trustedNames then
	for _, playerID in ipairs(Spring.GetPlayerList()) do
		local accountID = Spring.Utilities.GetAccountID(playerID)
		local name = Spring.GetPlayerInfo(playerID)
		if name and trustedNames[name] then
			-- Register under accountID for synced gadgets
			if not powerusers[accountID] then
				powerusers[accountID] = trustedNames[name]
			end
			-- Also register under player name so unsynced gadgets can look up by name
			if not powerusers[name] then
				powerusers[name] = trustedNames[name]
			end
		end
	end
end

local numPlayers = Spring.Utilities.GetPlayerCount()

-- give permissions when in singleplayer
if numPlayers <= 1 then
	for _, playerID in ipairs(Spring.GetPlayerList()) do
		local accountID = Spring.Utilities.GetAccountID(playerID)
		local _, _, spec = Spring.GetPlayerInfo(playerID)

		-- dont give permissions to the spectators when there is a player is playing
		if not spec or numPlayers == 0 then
			isSinglePlayer = true
			powerusers[accountID] = singleplayerPermissions
		end
	end
else
	powerusers[-1] = nil
end

-- order by permission instead of playername
local permissions = {}
for permission, _ in pairs(singleplayerPermissions) do
	permissions[permission] = {}
end
for user, perms in pairs(powerusers) do
	for permission, value in pairs(perms) do
		if not permissions[permission] then
			permissions[permission] = {}
		end
		permissions[permission][user] = value
	end
end

_G.powerusers = powerusers
_G.permissions = permissions
_G.isSinglePlayer = isSinglePlayer

-- Synthetic accountID for late joiners whose real accountID is not yet in customKeys.
-- The patched GetAccountID is used by synced gadgets. Unsynced gadgets use name-based lookup.
local trustedNameAccountIDs = {}
local nextSyntheticAccountID = -1000
local originalGetAccountID = Spring.Utilities.GetAccountID
Spring.Utilities.GetAccountID = function(playerID)
	local syntheticID = trustedNameAccountIDs[playerID]
	if syntheticID then
		return syntheticID
	end
	return originalGetAccountID(playerID)
end

local function ResolveTrustedName(playerID)
	local name = Spring.GetPlayerInfo(playerID)
	if not name or not trustedNames[name] then return false end
	local accountID = originalGetAccountID(playerID)
	if accountID == -1 then
		-- Late joiner: assign/reuse a synthetic accountID for synced gadget compatibility
		if not trustedNameAccountIDs[playerID] then
			nextSyntheticAccountID = nextSyntheticAccountID - 1
			trustedNameAccountIDs[playerID] = nextSyntheticAccountID
		end
		accountID = trustedNameAccountIDs[playerID]
	end
	-- Register under accountID (synced gadgets call patched GetAccountID and find this)
	if not powerusers[accountID] then
		powerusers[accountID] = trustedNames[name]
	end
	-- Register under player name string (unsynced gadgets check SYNCED.permissions[perm][name])
	if not powerusers[name] then
		powerusers[name] = trustedNames[name]
	end
	for permission, value in pairs(trustedNames[name]) do
		if not permissions[permission] then
			permissions[permission] = {}
		end
		permissions[permission][accountID] = value
		permissions[permission][name] = value
	end
	Spring.Log("Permissions", LOG.INFO, "Granted permissions to '" .. name .. "' (accountID: " .. accountID .. ")")
	return true
end

-- Track playerIDs and their real accountID at the time of last resolution
local resolvedAccountIDs = {}

function gadget:PlayerChanged(playerID)
	if not trustedNames then return end
	local name = Spring.GetPlayerInfo(playerID)
	if not name or not trustedNames[name] then return end
	local currentAccountID = originalGetAccountID(playerID)
	local prevAccountID = resolvedAccountIDs[playerID]
	-- Re-resolve if never seen, or if a real accountID became available (was <0, now >=0)
	if prevAccountID == nil or (currentAccountID >= 0 and currentAccountID ~= prevAccountID) then
		if ResolveTrustedName(playerID) then
			resolvedAccountIDs[playerID] = currentAccountID
		end
	end
end

function gadget:GameFrame(frame)
	-- Poll periodically in case PlayerChanged did not fire for a late joiner.
	if not trustedNames then return end
	if frame % 150 ~= 0 then return end
	for _, playerID in ipairs(Spring.GetPlayerList()) do
		local name = Spring.GetPlayerInfo(playerID)
		if name and trustedNames[name] then
			local currentAccountID = originalGetAccountID(playerID)
			local prevAccountID = resolvedAccountIDs[playerID]
			-- Re-resolve if never seen, or if real accountID became available after being absent
			if prevAccountID == nil or (currentAccountID >= 0 and currentAccountID ~= prevAccountID) then
				if ResolveTrustedName(playerID) then
					resolvedAccountIDs[playerID] = currentAccountID
				end
			end
		end
	end
end
