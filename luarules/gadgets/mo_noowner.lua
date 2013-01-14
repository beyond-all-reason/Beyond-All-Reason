function gadget:GetInfo()
	return {
		name			= "mo_noowner",
		desc			= "Noowner code for FFA games. Removes abandoned teams",
		author		= "TheFatController",
		date			= "19 Jan 2008",
		license	 = "GNU GPL, v2 or later",
		layer		 = 0,
		enabled	 = true	--	loaded by default?
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if (not gadgetHandler:IsSyncedCode()) then
	return
end

local enabled = tonumber(Spring.GetModOptions().mo_noowner) or 0

if (enabled == 0) then 
	return false
end

local GetPlayerInfo = Spring.GetPlayerInfo
local GetPlayerList = Spring.GetPlayerList
local GetTeamList = Spring.GetTeamList
local GetTeamUnits = Spring.GetTeamUnits
local DestroyUnit = Spring.DestroyUnit
local GetUnitTransporter = Spring.GetUnitTransporter
local spGetAIInfo = Spring.GetAIInfo
local deadTeam = {}
local droppedTeam = {}
deadTeam[Spring.GetGaiaTeamID()] = true

function GetTeamIsTakeable(team)
	local players = GetPlayerList(true)
	for _, player in ipairs(players) do
		local _, _, _, playerTeam = GetPlayerInfo(player)
		if (playerTeam == team) then
			return false
		end
	end
	return true
end

function gadget:TeamDied(teamID)
	deadTeam[teamID] = true
end

local function destroyTeam(team, nowrecks)
	local teamUnits = GetTeamUnits(team)
	frame=Spring.GetGameFrame()
	for _, unitID in pairs(teamUnits) do
		if not GetUnitTransporter(unitID) then
			if nowrecks then --teams dying before 2 minutes dont leave wrecks
				DestroyUnit(unitID,false, true)
			else
				DestroyUnit(unitID)
			end
		end
	end
	if nowrecks then
		Spring.Echo("No Owner Mode: Removing Team " .. team)
	else
		Spring.Echo("No Owner Mode: Destroying Team " .. team)
	end
	deadTeam[team] = true
end

function gadget:GameFrame(n)
	if ((n % 30) < 1) then
		for _, team in ipairs(GetTeamList()) do
			if (not deadTeam[team]) and GetTeamIsTakeable(team) and (not spGetAIInfo(team)) then
				if (not droppedTeam[team]) then
					if n<30*120 then
						Spring.Echo("No Owner Mode: Team " .. team .. " has 1 minute to reconnect")
					else 
						Spring.Echo("No Owner Mode: Team " .. team .. " has 3 minutes to reconnect")
					end
					droppedTeam[team] = n
				end
			elseif droppedTeam[team] then
				Spring.Echo("No Owner Mode: Team " .. team .. " reconnected")
				droppedTeam[team] = nil
			end
		end
		for team,time in pairs(droppedTeam) do
			local graceperiod = 5400 --3 minute grace period
			if time < 30*120 then
				graceperiod = 1800 --1 minute grace period for early droppers
			end
			if (n - time) > graceperiod then  
				if time < 30*120 then 
					destroyTeam(team,true) --nowrecks=true
				else
					destroyTeam(team,false) --nowrecks=false
				end
				droppedTeam[team] = nil
			end
		end
	end
end

function gadget:AllowUnitTransfer(unitID, unitDefID, oldTeam, newTeam, capture)
	if deadTeam[newTeam] then
		return false
	else
		return true
	end
end
 
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------