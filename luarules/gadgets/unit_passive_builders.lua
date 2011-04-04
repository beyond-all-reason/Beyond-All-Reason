function gadget:GetInfo()
  return {
    name      = "PassiveBuilders",
    desc      = "Adds passive option to some builders",
    author    = "TheFatController",
    date      = "24th May 2009",
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

local EditUnitCmdDesc = Spring.EditUnitCmdDesc
local FindUnitCmdDesc = Spring.FindUnitCmdDesc
local InsertUnitCmdDesc = Spring.InsertUnitCmdDesc
local GetTeamResources = Spring.GetTeamResources
local GetTeamList = Spring.GetTeamList
local min = math.min
local max = math.max

local NANOTURRET = {
  [UnitDefNames["cornanotc"].id] = true,
  [UnitDefNames["armnanotc"].id] = true,
  [UnitDefNames["cormlv"].id] = true,
  [UnitDefNames["armmlv"].id] = true,
}

local IGNORE_METAL_STALL = {
  [UnitDefNames["armmakr"].id] = true,
  [UnitDefNames["cormakr"].id] = true,
  [UnitDefNames["corfmkr"].id] = true,
  [UnitDefNames["armfmkr"].id] = true,
  [UnitDefNames["cormine1"].id] = true,
  [UnitDefNames["cormine2"].id] = true,
  [UnitDefNames["cormine3"].id] = true,
  [UnitDefNames["armmine1"].id] = true,
  [UnitDefNames["armmine2"].id] = true,
  [UnitDefNames["armmine3"].id] = true,
}

local IGNORE_ENERGY_STALL = {
  [UnitDefNames["corsolar"].id] = true,
  [UnitDefNames["armsolar"].id] = true,
}

local isNano = {}
local isStalling = {}
local nanoTeams = {}

local ntPassiveMode = {
      id      = 34571,
      name    = "ntPassiveMode",
      action  = "ntPassiveMode",
      type    = CMDTYPE.ICON_MODE,
      tooltip = "Building Mode: Passive wont build when stalling",
      params  = { '0', 'Active', 'Passive'}
}

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
  if NANOTURRET[unitDefID] then
    InsertUnitCmdDesc(unitID, 500, ntPassiveMode)
    isNano[unitID] = 0
  end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
  if isNano[unitID] == 1 then
    if nanoTeams[unitTeam] then
      nanoTeams[unitTeam] = nanoTeams[unitTeam] - 1
    else
      nanoTeams[unitTeam] = 0
    end
    isNano[unitID] = nil
  end
end

function gadget:UnitTaken(unitID, unitDefID, unitTeam, newTeam) 
  if isNano[unitID] == 1 then
    if nanoTeams[unitTeam] then
      nanoTeams[unitTeam] = nanoTeams[unitTeam] - 1
    else
      nanoTeams[unitTeam] = 0
    end
    if nanoTeams[newTeam] then
      nanoTeams[newTeam] = nanoTeams[newTeam] + 1
    else
      nanoTeams[newTeam] = 1
    end
  end  
end 

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
  if NANOTURRET[unitDefID] and (cmdID == 34571) then
    local cmdDescID = FindUnitCmdDesc(unitID, 34571)
    ntPassiveMode.params[1] = cmdParams[1]
    EditUnitCmdDesc(unitID, cmdDescID, ntPassiveMode)
    ntPassiveMode.params[1] = 0
    if (cmdParams[1] == 1) and (isNano[unitID] == 0) then
      if nanoTeams[teamID] then
        nanoTeams[teamID] = nanoTeams[teamID] + 1
      else
        nanoTeams[teamID] = 1
      end
    end
    if (cmdParams[1] == 0) and (isNano[unitID] == 1) then
      if nanoTeams[teamID] then
        nanoTeams[teamID] = nanoTeams[teamID] - 1
      else
        nanoTeams[teamID] = 0
      end
    end
    isNano[unitID] = cmdParams[1]
    return false
  end
  return true
end

function gadget:TeamDied(teamID)
  nanoTeams[teamID] = nil
end

function gadget:Initialize()
  for _, teamID in ipairs(GetTeamList()) do
    isStalling[teamID] = { energy = false, metal = false }
  end
end

function gadget:GameFrame(n)
  for teamID, count in pairs(nanoTeams) do
    if (count > 0) then
      if (isStalling[teamID].energy == false) or (isStalling[teamID].metal == false) or ((n % 17) == 0) then
        local energy, menergy, _, einc = GetTeamResources(teamID, "energy")
        if (energy < min(menergy/2, max(500,einc))) then
          isStalling[teamID].energy = true
        else
          isStalling[teamID].energy = false
        end
        local metal, mmetal, _, minc = GetTeamResources(teamID, "metal")
        if (metal < min(min(mmetal/2, (minc*1.5)), 10)) then
          isStalling[teamID].metal = true
        else
          isStalling[teamID].metal = false
        end
      end
    end
  end
end

function gadget:AllowUnitBuildStep(builderID, teamID, unitID, unitDefID, step)
  if (isNano[builderID] == 1) and step > 0 then
    if isStalling[teamID].metal and (not IGNORE_METAL_STALL[unitDefID]) then
      return false
    elseif isStalling[teamID].energy and (not IGNORE_ENERGY_STALL[unitDefID]) then
      return false
    end
  end
  return true
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------