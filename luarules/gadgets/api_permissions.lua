
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
		if not powerusers[accountID] and trustedNames[Spring.GetPlayerInfo(playerID)] then
			powerusers[accountID] = trustedNames[Spring.GetPlayerInfo(playerID)]
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

-- When a late joiner has no accountID in customKeys, assign a synthetic one
-- and patch GetAccountID so other gadgets also see it.
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
		-- Late joiner without accountID in customKeys: assign synthetic ID
		nextSyntheticAccountID = nextSyntheticAccountID - 1
		accountID = nextSyntheticAccountID
		trustedNameAccountIDs[playerID] = accountID
	end
	if powerusers[accountID] then return true end -- already has permissions
	powerusers[accountID] = trustedNames[name]
	for permission, value in pairs(trustedNames[name]) do
		if not permissions[permission] then
			permissions[permission] = {}
		end
		permissions[permission][accountID] = value
	end
	Spring.Log("Permissions", LOG.INFO, "Granted trusted-name permissions to " .. name .. " (accountID: " .. accountID .. ")")
	return true
end

-- Track which playerIDs have been resolved so we don't re-scan them
local resolvedPlayerIDs = {}

function gadget:PlayerChanged(playerID)
	if not trustedNames then return end
	if resolvedPlayerIDs[playerID] then return end
	if ResolveTrustedName(playerID) then
		resolvedPlayerIDs[playerID] = true
	end
end

function gadget:GameFrame(frame)
	-- PlayerChanged/PlayerAdded don't fire in synced code, so we must poll.
	if not trustedNames then return end
	if frame % 200 ~= 0 then return end
	for _, playerID in ipairs(Spring.GetPlayerList()) do
		if not resolvedPlayerIDs[playerID] then
			local name = Spring.GetPlayerInfo(playerID)
			if name and trustedNames[name] then
				if ResolveTrustedName(playerID) then
					resolvedPlayerIDs[playerID] = true
				end
			end
		end
	end
end
