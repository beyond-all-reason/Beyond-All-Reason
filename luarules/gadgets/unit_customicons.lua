
function gadget:GetInfo()
	return {
		name = "CustomIcons",
		desc = "Sets custom unit icons",
		author = "trepan,BrainDamage,TheFatController,Floris,tovernaar123",
		date = "dec 31, 2020",
		license = "GNU GPL, v2 or later",
		layer = -100,
		enabled = true
	}
end

if gadgetHandler:IsSyncedCode() then
	return false
end

local iconTypes, iconSizes = include("LuaRules/configs/uniticons.lua")

local spSetUnitDefIcon = Spring.SetUnitDefIcon
local spFreeUnitIcon = Spring.FreeUnitIcon
local spAddUnitIcon = Spring.AddUnitIcon

function gadget:Initialize()
	for name, path in pairs(iconTypes) do
		spFreeUnitIcon(name)
		spAddUnitIcon(name, path, iconSizes[name])
		spSetUnitDefIcon(UnitDefNames[name].id, name)
	end
end
