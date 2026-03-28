
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

function gadget:PlayerChanged(playerID)
	if not trustedNames then return end
	local name = Spring.GetPlayerInfo(playerID)
	if not name or not trustedNames[name] then return end
	local accountID = Spring.Utilities.GetAccountID(playerID)
	if powerusers[accountID] then return end
	powerusers[accountID] = trustedNames[name]
	for permission, value in pairs(trustedNames[name]) do
		if not permissions[permission] then
			permissions[permission] = {}
		end
		permissions[permission][accountID] = value
	end
end
