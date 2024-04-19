function widget:GetInfo()
	return {
		name      = "DGun Stall Assist v2",
		desc      = "Waits cons/facs when trying to dgun and stalling",
		author    = "zombean",
		date      = "2 April 2024",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true
	}
end

local millis_start_timer = Spring.GetTimer()
local function millis()
  return math.ceil(Spring.DiffTimers(Spring.GetTimer(), millis_start_timer) * 1000)
end

local target_energy = 1000
local dgun_cost = 500
local time_in_ms_befor_unwaiting = 250 --how many fast we can unwait units after waiting them
local gameStarted = false
local DGUN_OUT = false
local UNITS_WAITING = false
local waitableUnits = {}
local waitingUnits = {}

local function getWaitAbleUnits()
  local myWaitableUnits = {}
  local myUnits = Spring.GetTeamUnits(Spring.GetMyTeamID())
  for i=1, #myUnits do
    local unitCmd = Spring.GetUnitCurrentCommand(myUnits[i])
    local isEnergyConsumingCommand = not (unitCmd == CMD.WAIT or unitCmd == CMD.MOVE or unitCmd == CMD.RECLAIM)
    if isEnergyConsumingCommand then
      local unitDefId = Spring.GetUnitDefID(myUnits[i])
      if waitableUnits[unitDefId] then myWaitableUnits[#myWaitableUnits + 1] = myUnits[i] end
    end
  end
  return myWaitableUnits
end

local function doWeHaveLowEnergy()
  local currentEnergy, energyStorage = Spring.GetTeamResources(Spring.GetMyTeamID(), "energy")
  if energyStorage < dgun_cost then return false end
  if currentEnergy < target_energy then return true end
  return false
end

local next_call_when = 0
local function wait_units()
  local time_now = millis()
  if next_call_when > time_now then return end
  next_call_when = time_now + time_in_ms_befor_unwaiting
  UNITS_WAITING = true
  for _, unitID in pairs(getWaitAbleUnits()) do
    waitingUnits[#waitingUnits +1] = unitID
  end
  Spring.GiveOrderToUnitArray(waitingUnits, CMD.WAIT, {}, 0)
end

local function unwait_units()
  Spring.GiveOrderToUnitArray(waitingUnits, CMD.WAIT, {}, 0)
  UNITS_WAITING = false
  waitingUnits = {}
end

local function buildWaitableUnitsTable()
  for uDefID, uDef in pairs(UnitDefs) do
		if (uDef.buildSpeed > 0) and uDef.canAssist and (not uDef.canManualFire) then
			waitableUnits[uDefID] = true
		end
	end
end

function widget:GameFrame()
  local lowEnergy = doWeHaveLowEnergy()
  local _, activeCmdID = Spring.GetActiveCommand()
  DGUN_OUT = activeCmdID == CMD.DGUN

  if DGUN_OUT and not UNITS_WAITING and lowEnergy then wait_units() return end 
  if UNITS_WAITING and not DGUN_OUT then unwait_units() return end --when we stow dgun, just undo all the waiting stuff always
  if UNITS_WAITING and not lowEnergy then unwait_units() return end

end

local function maybeRemoveSelf()
    if Spring.GetSpectatingState() and (Spring.GetGameFrame() > 0 or gameStarted) then
        widgetHandler:RemoveWidget()
    end
end

function widget:GameStart()
    gameStarted = true
    maybeRemoveSelf()
end

function widget:PlayerChanged(playerID)
    maybeRemoveSelf()
end

function widget:Initialize()
    if Spring.IsReplay() then widgetHandler:RemoveWidget() end
    buildWaitableUnitsTable()
end
