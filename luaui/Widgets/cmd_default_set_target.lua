local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name	= "Set target default",
		desc	= "replaces default click from attack to set target",
		author	= "BrainDamage",
		date	= "-",
		license	= "WTFPL",
		layer	= -999999,
		enabled	= false,
	}
end

local rebindKeys = false

local CMD_UNIT_SET_TARGET = 34923

local IsUnitAllied = Spring.IsUnitAllied
local GetSelectedUnitsCounts = Spring.GetSelectedUnitsCounts
local GetActionHotKeys = Spring.GetActionHotKeys
local SendCommmands = Spring.SendCommands

local hotKeys = {}
local gameStarted

local hasSetTarget = {}
for udid, ud in pairs(UnitDefs) do
	if ( ud.canMove and ud.speed > 0 and not ud.canFly and ud.canAttack and ud.maxWeaponRange and ud.maxWeaponRange > 0 ) or ud.isFactory then
		hasSetTarget[udid] = true
	end
end

local function maybeRemoveSelf()
	if Spring.GetSpectatingState() and (Spring.GetGameFrame() > 0 or gameStarted) then
		widgetHandler:RemoveWidget()
		return true
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
		if maybeRemoveSelf() then return end
	end

	if rebindKeys then
		for _, keycombo in ipairs(GetActionHotKeys("attack")) do
			hotKeys[keycombo] = true
			SendCommmands({"unbind " .. keycombo .. " attack","bind " .. keycombo .. " settarget"})
		end
	end
end

function widget:Shutdown()
	for keycombo in pairs(hotKeys) do
		SendCommmands({"unbind " .. keycombo .. " settarget","bind " .. keycombo .. " attack"})
	end
end

function widget:DefaultCommand(type, id, cmd)
	if type ~= "unit" or IsUnitAllied(id) then
		return
	end
	for unitDefID in pairs(GetSelectedUnitsCounts()) do
		if hasSetTarget[unitDefID] then
			return CMD_UNIT_SET_TARGET
		end
	end
end
