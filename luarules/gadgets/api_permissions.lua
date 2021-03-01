
function gadget:GetInfo()
	return {
		name    = "Permissions",
		desc	= 'provides a list of user permissions to other gadgets',
		author	= 'Floris',
		date	= 'February 2021',
		license	= 'GNU GPL, v2 or later',
		layer	= -math.huge,
		enabled	= true
	}
end

-- (include all permissions used in codebase)
local singleplayerPermissions = {
	give = true,
	undo = true,
	cmd = true,
	devhelpers = true,
	waterlevel = true,
	playerdata = false,
}
local powerusers = include("LuaRules/configs/powerusers.lua")

local numPlayers = 0
local teams = Spring.GetTeamList()
for i = 1, #teams do
	local _, _, _, isAiTeam = Spring.GetTeamInfo(teams[i], false)
	local luaAI = Spring.GetTeamLuaAI(teams[i])
	if (not luaAI or luaAI == '') and not isAiTeam and teams[i] ~= Spring.GetGaiaTeamID() then
		numPlayers = numPlayers + 1
	end
end
teams = nil

-- give permissions when in singleplayer
if numPlayers <= 1 then

	for _,playerID in ipairs(Spring.GetPlayerList()) do
		local name, _, spec, teamID, allyTeamID = Spring.GetPlayerInfo(playerID)

		-- dont give permissions to the spectators when there is a player is playing
		if not spec or numPlayers == 0 then
			powerusers[name] = singleplayerPermissions
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
		permissions[permission][user] = value
	end
end

_G.powerusers = powerusers
_G.permissions = permissions

