function gadget:GetInfo()
  return {
    name      = "mo_noowner",
    desc      = "mo_noowner",
    author    = "TheFatController",
    date      = "19 Jan 2008",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
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

local function destroyTeam(team)
	local teamUnits = GetTeamUnits(team)
	frame=Spring.GetGameFrame()
	for _, unitID in pairs(teamUnits) do
		if not GetUnitTransporter(unitID) then
			if frame < 30*120 then --teams dying before 2 minutes dont leave wrecks
				DestroyUnit(unitID,false, true)
			else
				DestroyUnit(unitID)
			end
		end
	end
	Spring.Echo("No Owner Mode: Destroying Team " .. team)
	deadTeam[team] = true
end

function gadget:GameFrame(n)
  if ((n % 30) < 1) then
    for _, team in ipairs(GetTeamList()) do
      if (not deadTeam[team]) and GetTeamIsTakeable(team) then
        if (n < 1800) then
          local teamUnits = GetTeamUnits(team)
          for _, unitID in pairs(teamUnits) do
            DestroyUnit(unitID, false, true)
          end
          Spring.Echo("No Owner Mode: Removing Team " .. team)
          deadTeam[team] = true
        else
          if (n < 14400) then
            destroyTeam(team)
          elseif (not droppedTeam[team]) then
            Spring.Echo("No Owner Mode: Team " .. team .. " has 3 minutes to reconnect")
            droppedTeam[team] = n
          end
        end        
      elseif droppedTeam[team] then
        Spring.Echo("No Owner Mode: Team " .. team .. " reconnected")
        droppedTeam[team] = nil
      end
    end
    for team,time in pairs(droppedTeam) do
      if (n - time) > 5400 then
        destroyTeam(team)
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