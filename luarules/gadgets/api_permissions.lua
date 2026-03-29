
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

-- Pending trusted name resolutions: playerIDs whose accountID was -1 when they joined
local pendingTrustedNames = {}

local function ResolveTrustedName(playerID)
	local name = Spring.GetPlayerInfo(playerID)
	if not name or not trustedNames[name] then return false end
	local accountID = Spring.Utilities.GetAccountID(playerID)
	if accountID == -1 then return false end -- still unavailable
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

function gadget:PlayerChanged(playerID)
	if not trustedNames then return end
	local name = Spring.GetPlayerInfo(playerID)
	if not name or not trustedNames[name] then return end
	if not ResolveTrustedName(playerID) then
		-- accountID not yet available, schedule retry
		pendingTrustedNames[playerID] = true
	end
end

function gadget:GameFrame(frame)
	if not next(pendingTrustedNames) then return end
	-- Retry every 30 frames (~1 second)
	if frame % 30 ~= 0 then return end
	for playerID in pairs(pendingTrustedNames) do
		if ResolveTrustedName(playerID) then
			pendingTrustedNames[playerID] = nil
		end
	end
end
