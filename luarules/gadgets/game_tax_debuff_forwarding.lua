local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = 'Tax Debuff Forwarding',
		desc    = 'Forwards buildspeed debuff events from synced to LuaUI for the easytax bar.',
		author  = 'RebelNode',
		date    = 'March 2026',
		license = 'GNU GPL, v2 or later',
		layer   = 0,
		enabled = true
	}
end

if gadgetHandler:IsSyncedCode() then
	return false
end

if not Spring.GetModOptions().easytax then
	return false
end

local function unitBuildspeedDebuff(cmd, unitID, startFrame, expireFrame)
	if Script.LuaUI("UnitBuildspeedDebuffHealthbars") then
		Script.LuaUI.UnitBuildspeedDebuffHealthbars(unitID, startFrame, expireFrame)
	end
end

local function unitBuildspeedDebuffEnd(cmd, unitID)
	if Script.LuaUI("UnitBuildspeedDebuffEndHealthbars") then
		Script.LuaUI.UnitBuildspeedDebuffEndHealthbars(unitID)
	end
end

function gadget:Initialize()
	gadgetHandler:AddSyncAction("unitBuildspeedDebuff",    unitBuildspeedDebuff)
	gadgetHandler:AddSyncAction("unitBuildspeedDebuffEnd", unitBuildspeedDebuffEnd)
end

function gadget:ShutDown()
	gadgetHandler:RemoveSyncAction("unitBuildspeedDebuff")
	gadgetHandler:RemoveSyncAction("unitBuildspeedDebuffEnd")
end
