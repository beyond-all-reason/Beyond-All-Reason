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
local GetGameFrame = Spring.GetGameFrame
local Echo = Spring.Echo
local deadTeam = {}
local droppedTeam = {}
deadTeam[Spring.GetGaiaTeamID()] = true

function GetTeamIsTakeable(teamID)
	local players = GetPlayerList(teamID)
	local allResigned = true
	local noneControlling = true
	for _, playerID in pairs(players) do
		local name, active, spec = GetPlayerInfo(playerID)
		allResigned = allResigned and spec
		noneControlling = noneControlling and not active and spec
	end
	return noneControlling, allResigned
end

function gadget:TeamDied(teamID)
	deadTeam[teamID] = true
end

local function destroyTeam(teamID)
	local teamUnits = GetTeamUnits(teamID)
	local frame = GetGameFrame()
	local nowrecks = false
	if frame < 30*120 then
		nowrecks=true
	end
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
		for _, teamID in pairs(GetTeamList()) do
			local noneControlling, allResigned = GetTeamIsTakeable(teamID)
			if not deadTeam[teamID] and noneControlling and not spGetAIInfo(teamID) then
				if not droppedTeam[teamID] then
					if allResigned then
						destroyTeam(teamID) -- destroy the team immediately if all players in it resigned
					elseif n<30*120 then
						Echo("No Owner Mode: Team " .. teamID .. " has 1 minute to reconnect")
					else
						Echo("No Owner Mode: Team " .. teamID .. " has 3 minutes to reconnect")
					end
					droppedTeam[teamID] = n
				end
			elseif droppedTeam[teamID] then
				Echo("No Owner Mode: Team " .. teamID .. " reconnected")
				droppedTeam[teamID] = nil
			end
		end
		for teamID,time in pairs(droppedTeam) do
			local graceperiod = 5400 --3 minute grace period
			if time < 30*120 then
				graceperiod = 1800 --1 minute grace period for early droppers
			end
			if (n - time) > graceperiod then
				destroyTeam(teamID)
				droppedTeam[teamID] = nil
			end
		end
	end
end

function gadget:AllowUnitTransfer(unitID, unitDefID, oldTeam, newTeam, capture)
	return not deadTeam[newTeam]
end

function gadget:GameOver()
	gadgetHandler:RemoveGadget()
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------