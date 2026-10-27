local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Permissions",
		desc = "provides a list of user permissions to other gadgets and widgets",
		author = "Floris",
		date = "February 2021",
		license = "GNU GPL, v2 or later",
		layer = -999000,
		enabled = true,
	}
end

local powerusers = include("LuaRules/configs/powerusers.lua")
local singleplayerPermissions = powerusers[-1]
local isSinglePlayer = false

local numPlayers = BAR.Utilities.GetPlayerCount()

powerusers[-1] = nil -- Remove any grants to late joiners who get accountID -1.

-- give permissions when in singleplayer
if numPlayers <= 1 then
	for _, playerID in ipairs(Spring.GetPlayerList()) do
		local accountID = BAR.Utilities.GetAccountID(playerID)
		local _, _, spec = Spring.GetPlayerInfo(playerID)

		-- dont give permissions to the spectators when there is a player is playing
		if not spec or numPlayers == 0 then
			isSinglePlayer = true
			powerusers[accountID] = singleplayerPermissions
		end
	end
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

--------------------------------------------------------------------------------
-- Resigning or rejoining must not make the player into an ordinary spectator --

if gadgetHandler:IsSyncedCode() then
	local spGetPlayerInfo = Spring.GetPlayerInfo
	local spGetPlayerList = Spring.GetPlayerList
	local spSetGameRulesParam = Spring.SetGameRulesParam
	local getAccountID = BAR.Utilities.GetAccountID

	local gameRulesParam = "IsPlayerAccount"
	local gameStarted = Spring.GetGameFrame() > 0 -- handle reloads

	local function markPlayer(playerID)
		local _, _, spectator = spGetPlayerInfo(playerID, false)
		if spectator == false then
			local accountID = getAccountID(playerID)
			if accountID and accountID > 0 then
				spSetGameRulesParam(gameRulesParam .. accountID, true)
			end
		end
	end

	local function markPlayers()
		for _, playerID in ipairs(spGetPlayerList()) do
			markPlayer(playerID)
		end
	end

	function gadget:GameStart()
		gameStarted = true
		markPlayers()
	end

	function gadget:PlayerAdded(playerID)
		if gameStarted then
			markPlayer(playerID)
		end
	end
	gadget.PlayerChanged = gadget.PlayerAdded

	function gadget:Initialize()
		if gameStarted then
			markPlayers()
		end
	end
end
