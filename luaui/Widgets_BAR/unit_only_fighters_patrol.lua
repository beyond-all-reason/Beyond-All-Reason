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

local opts={
stop_builders=true -- Whever to stop builders or not. Set to true if you dont use factory guard widget.
--,FactoryGuard_workaround=true
}

local OrderUnit = Spring.GiveOrderToUnit
local GetMyTeamID = Spring.GetMyTeamID
local GetCommandQueue = Spring.GetCommandQueue
local GetUnitBuildFacing = Spring.GetUnitBuildFacing
local GetUnitPosition = Spring.GetUnitPosition

--[[
local function WeaponCanTargetAir(weapon)
	local wd = WeaponDefs[ weapon.weaponDef ]
	for name,param in wd:pairs() do
		Spring.Echo("wd:",name,param)
	end
	categories=wd.onlyTargetCategories
	if categories then
		for name,value in pairs(categories) do
			Spring.Echo("wdtc:",name,value)
		end
	end
end

local function UnitCanTargetAir(unitDefID)
	local ud=UnitDefs[unitDefID]
	for i=1,table.getn(ud.weapons) do
		if WeaponCanTargetAir(ud.weapons[i]) then
			return true
		end
	end
	return false
end
]]--
local function UnitHasPatrolOrder(unitID)
	local queue=GetCommandQueue(unitID,20)
	for i=1,#queue do
		local cmd = queue[i]
		if cmd.id == CMD.PATROL then
			return true
		end
	end
	return false
end

local isFactory = {}
local isBuilder = {}
local checkMustStop = {}
for udid, ud in pairs(UnitDefs) do
	if ud.isFactory then
		isFactory[udid] = true
	end
	if ud.isBuilder then
		isBuilder[udid] = true
	end
	if ud.canFly and (ud.weaponCount==0 or (not (ud.isFighterAirUnit or ud.isFighter)) or (ud.humanName=="Liche") or ud.noAutoFire) then
		checkMustStop[udid] = true
	end
end

local function MustStop(unitID, unitDefID)
	if checkMustStop[unitDefID] and UnitHasPatrolOrder(unitID) then --isFighter kept for 94 compat only, remove after
		if not opts.stop_builders and isBuilder[unitDefID] then
			return false
		end
		return true
	end
	return false
end

function widget:UnitFromFactory(unitID, unitDefID, unitTeam, factID, factDefID, userOrders)
	if unitTeam ~= GetMyTeamID() then
		return
	elseif (userOrders) then
		return
	end
	if not isFactory[factDefID] then
		return
	end
	--- liche: workaround for BAR (liche is fighter)
	if MustStop(unitID, unitDefID) then
		Spring.GiveOrderToUnit(unitID,CMD.STOP,{},{})
	end
end

function maybeRemoveSelf()
    if Spring.GetSpectatingState() and (Spring.GetGameFrame() > 0 or gameStarted) then
        widgetHandler:RemoveWidget(self)
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
    if Spring.IsReplay() or Spring.GetGameFrame() > 0 then
        maybeRemoveSelf()
    end
end