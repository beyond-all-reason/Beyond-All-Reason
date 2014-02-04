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

function GetTeamIsTakeable(teamID)
	local players = GetPlayerList(teamID)
	for _, playerID in pairs(players) do
		local _, active, spec = GetPlayerInfo(playerID)
		if active and not spec then
			return false
		end
	end
	return true
end

function gadget:TeamDied(teamID)
	deadTeam[teamID] = true
end

local function destroyTeam(teamID, nowrecks)
	local teamUnits = GetTeamUnits(teamID)
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
		Spring.Echo("No Owner Mode: Removing Team " .. teamID)
	else
		Spring.Echo("No Owner Mode: Destroying Team " .. teamID)
	end
	deadTeam[teamID] = true
end

function gadget:GameFrame(n)
	if ((n % 30) < 1) then
		for _, teamID in ipairs(GetTeamList()) do
			Spring.Echo(not deadTeam[teamID], GetTeamIsTakeable(teamID), not spGetAIInfo(teamID))
			if (not deadTeam[teamID]) and GetTeamIsTakeable(teamID) and (not spGetAIInfo(teamID)) then
				if (not droppedTeam[teamID]) then
					if n<30*120 then
						Spring.Echo("No Owner Mode: Team " .. teamID .. " has 1 minute to reconnect")
					else 
						Spring.Echo("No Owner Mode: Team " .. teamID .. " has 3 minutes to reconnect")
					end
					droppedTeam[teamID] = n
				end
			elseif droppedTeam[teamID] then
				Spring.Echo("No Owner Mode: Team " .. teamID .. " reconnected")
				droppedTeam[teamID] = nil
			end
		end
		for teamID,time in pairs(droppedTeam) do
			local graceperiod = 5400 --3 minute grace period
			if time < 30*120 then
				graceperiod = 1800 --1 minute grace period for early droppers
			end
			if (n - time) > graceperiod then  
				if time < 30*120 then 
					destroyTeam(teamID,true) --nowrecks=true
				else
					destroyTeam(teamID,false) --nowrecks=false
				end
				droppedTeam[teamID] = nil
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