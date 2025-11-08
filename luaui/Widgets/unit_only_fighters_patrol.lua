--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    unit_only_fighters_patrol.lua
--  brief:   Only fighters go on factory's patrol route after leaving airlab. Reduces lag.
--  author:  dizekat
--  based on Factory Kickstart by OWen Martindell aka TheFatController
--
--  Copyright (C) 2008
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name	= "OnlyFightersPatrol",
		desc	= "Only fighters go on factory's patrol route after leaving airlab. Reduces lag.",
		author	= "dizekat",
		date	= "2008-04-22",
		license	= "GNU GPL, v2 or later",
		layer	= 0,
		enabled	= false,
	}
end


-- Localized functions for performance

-- Localized Spring API for performance
local spGetGameFrame = Spring.GetGameFrame
local spGetMyTeamID = Spring.GetMyTeamID

local stop_builders = true -- Whever to stop builders or not. Set to true if you dont use factory guard widget.

local GetUnitCommands = Spring.GetUnitCommands
local myTeamID = spGetMyTeamID()

local gameStarted

local isFactory = {}
local isBuilder = {}
local checkMustStop = {}

local function UnitHasPatrolOrder(unitID)
	local queue=GetUnitCommands(unitID,20)
	for i=1,#queue do
		local cmd = queue[i]
		if cmd.id == CMD.PATROL then
			return true
		end
	end
	return false
end

for udid, ud in pairs(UnitDefs) do
	if ud.isFactory then
		isFactory[udid] = true
	end
	if ud.isBuilder then
		isBuilder[udid] = true
	end
	if ud.canFly and (ud.weaponCount==0 or not ud.isFighterAirUnit or string.find(ud.name,"liche") or ud.noAutoFire) then      -- liche is classified as one somehow
		checkMustStop[udid] = true
	end
end

local function MustStop(unitID, unitDefID)
	if checkMustStop[unitDefID] and UnitHasPatrolOrder(unitID) then --isFighter kept for 94 compat only, remove after
		if not stop_builders and isBuilder[unitDefID] then
			return false
		end
		return true
	end
	return false
end

function widget:UnitFromFactory(unitID, unitDefID, unitTeam, factID, factDefID, userOrders)
	if unitTeam ~= myTeamID then
		return
	elseif (userOrders) then
		return
	end
	if not isFactory[factDefID] then
		return
	end
	if MustStop(unitID, unitDefID) then
		Spring.GiveOrderToUnit(unitID,CMD.STOP,{},0)
	end
end

function maybeRemoveSelf()
    if Spring.GetSpectatingState() and (spGetGameFrame() > 0 or gameStarted) then
        widgetHandler:RemoveWidget()
    end
end

function widget:GameStart()
    gameStarted = true
    maybeRemoveSelf()
end

function widget:PlayerChanged(playerID)
	myTeamID = spGetMyTeamID()
    maybeRemoveSelf()
end

function widget:Initialize()
    if Spring.IsReplay() or spGetGameFrame() > 0 then
        maybeRemoveSelf()
    end
end
