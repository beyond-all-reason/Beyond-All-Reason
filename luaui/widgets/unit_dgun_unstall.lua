--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    unit_dgun_unstall.lua
--  brief:   disable energy drains while stalling and trying to dgun
--  author:  Masure
--  version: 1.00
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "D-Gun unstall",
    desc      = "Disable energy drains while you try to dgun and stalling E",
    author    = "BD",
    date      = "Oct 17, 2007",
    license   = "GNU GPL, v2 or later",
    layer     = -3,
    enabled   = false  --  loaded by default?
  }
end

--params
local dGunCost = 500
local energyAim = 2*dGunCost
local energyAimFraction = 0.25
local unstallHysteresis = 0 -- how long to keep the unstall enabled even after you reached target energy

local Echo = Spring.Echo
local SetShareLevel = Spring.SetShareLevel
local GetTeamRulesParam = Spring.GetTeamRulesParam
local SendLuaRulesMsg = Spring.SendLuaRulesMsg
local SendCommands = Spring.SendCommands
local GiveOrderToUnit = Spring.GiveOrderToUnit
local GetTeamUnits = Spring.GetTeamUnits
local GetTeamResources = Spring.GetTeamResources
local GetPlayerInfo = Spring.GetPlayerInfo
local GetUnitDefID = Spring.GetUnitDefID
local GetCommandQueue = Spring.GetCommandQueue
local GetUnitResources = Spring.GetUnitResources
local GetUnitStates = Spring.GetUnitStates
local GetSpectatingState= Spring.GetSpectatingState
local echo = Spring.Echo
local ceil = math.ceil
local floor = math.floor
local min = math.min
local format = string.format

local alterLevelFormat = string.char(137) .. '%i'
local disabledUnits = {}
local unstallTime = 0
local coms = {}
local MyTeamId = Spring.GetMyTeamID()
local units
local forcestop = false
local commanderschecked = false
local lastMMHoverPerc
local lastESharePerc


local function DisableMetalMakers()
	lastMMHoverPerc = GetTeamRulesParam(MyTeamId, 'mmLevel')
	SendLuaRulesMsg(format(alterLevelFormat, 1*100))
end

local function ReEnableMetalMakers()
	SendLuaRulesMsg(format(alterLevelFormat, lastMMHoverPerc*100))
	lastMMHoverPerc = nil
end

local function DisableEnergyShare()
	_, _, _, _, _, lastESharePerc = GetTeamResources(MyTeamId, "energy")
	SetShareLevel("energy",1)
end

local function ReEnableEnergyShare()
	SetShareLevel("energy",lastESharePerc)
	lastESharePerc = nil
end

function widget:PlayerChanged(playerID)
	local MyTeamId = Spring.GetMyTeamID()
	if GetSpectatingState() then
		widgetHandler:RemoveWidget()
		return
	end
end

function widget:Initialize()
	if GetSpectatingState() then
		widgetHandler:RemoveWidget()
		return
	end
	units = GetTeamUnits(MyTeamId)
	for _,unitID in ipairs(units) do
		local unitDefID = GetUnitDefID(unitID)
		local unitDef = UnitDefs[unitDefID]

		if (unitDef == nil) then
			break
		end
		if unitDef.canManualFire then
			coms[unitID] = true
		end
	end
end


function widget:UnitCreated(unitID, unitDefID, unitTeam)
  if ( unitTeam == MyTeamId ) then
	  if UnitDefs[unitDefID].canManualFire then
		coms[unitID] = true
	  end
  end
end

function widget:UnitGiven(unitID, unitDefID, unitTeam)
	UnitCreated(unitID, unitDefID, unitTeam)
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
	if ( unitTeam == MyTeamId ) then
		coms[unitID] = nil
		disabledUnits[unitID] = nil
	end
end

function widget:UnitTaken(unitID, unitDefID, unitTeam)
	UnitTaken(unitID, unitDefID, unitTeam)
end

------------------------------------------------------------------------------

------------------------------------------------------------------------------

function widget:GameFrame(currentframe)

	local bDgunOrder = false
	if ( unstallTime > 0 ) then
		unstallTime = unstallTime - 1
	end
	-- try to find a dgun order
	--------------------------------------
	--com parsing
	for comID in pairs(coms) do
		bDgunOrder = findCmdId(comID, CMD.MANUALFIRE)
		if bDgunOrder == true then
			break
		end
		local unitstates = GetUnitStates(comID) -- search also if cloacked
		if unitstates and unitstates.cloak then
			bDgunOrder = true
			break
		end
	end

	-- DGUN ORDER GIVEN ?
	if bDgunOrder then
		local eCur, eMax, ePull, eInc, eExp, _, _, eRec = GetTeamResources(MyTeamId, "energy")
		local tempEAim = min(energyAim,eMax)
		if eMax < dGunCost then -- no point disabling stuff, we cannot dgun anyway
			return
		end
		if ( eMax * energyAimFraction > tempEAim ) then
			tempEAim = eMax * energyAimFraction
		end
		local minTimeToRecover = (energyAim - eCur) / ( eInc + eRec - eExp )
		if minTimeToRecover < 0 then
			minTimeToRecover = 0
		end
		minTimeToRecover = floor( minTimeToRecover + 0.5 ) -- non biased round to integer
		unstallTime = ( minTimeToRecover + unstallHysteresis ) * 30
		-- NEED TO DISABLE UNITS ???
		if eMax >= tempEAim and eCur < tempEAim then
			Echo("dgun unstall enabled")
			units = GetTeamUnits(MyTeamId)
			for _,unitID in ipairs(units) do
				if disabledUnits[unitID] == nil then
					local UDID = GetUnitDefID(unitID)
					local UD = UnitDefs[UDID]
					local _,_,energyMake,energyUse = GetUnitResources(unitID)
					if energyMake < energyUse and not UD.canManualFire then
						if findCmdId(unitID, CMD.WAIT) == false then
							GiveOrderToUnit(unitID, CMD.WAIT, {}, {})
							disabledUnits[unitID] = true
						end
					end
				end
				if forcestop == false then
					DisableMetalMakers() --send order to the metal maker widget to shut down all metal makers
					DisableEnergyShare()
					forcestop = true
				end
			end
		end --need to disable unit

	-- NO DGUN ORDER QUEUED
	else
		-- Hysteresis ended ?
		if  ( unstallTime == 0 ) then
			unstallTime = -1
			-- disabled units parsing
			for unitID,_ in pairs(disabledUnits) do
				GiveOrderToUnit(unitID, CMD.WAIT, {}, {})
				disabledUnits[unitID] = nil
			end -- disabled units parsing
			if forcestop == true then
				Echo("dgun unstall disabled")
				ReEnableMetalMakers() --send order to the metal maker widget to resume to normal operation
				ReEnableEnergyShare()
				forcestop = false
			end
		else
			--echo("Hysteresis time left " .. unstallTime / 30)
		end -- Hysteresis ended ?
	end -- DGUN ORDER GIVEN ?
end -- function update



function findCmdId(pUnitID, pCmdID)
	local cQueue = GetCommandQueue(pUnitID)
	if cQueue ~= nil then
		for _, cmdOrder in ipairs(cQueue) do
			if cmdOrder.id == pCmdID then
				return true
			end
		end --queue parsing
	end
	return false
end


