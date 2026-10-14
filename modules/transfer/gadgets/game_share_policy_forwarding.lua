local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Share Policy Forwarding",
		desc = "Forwards the constructor build delay's start and end from synced to LuaUI widgets.",
		author = "Attean",
		date = "June 2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if gadgetHandler:IsSyncedCode() then
	return false
end

local function unitBuildspeedDebuff(_, unitID, startFrame, expireFrame)
	if Script.LuaUI("UnitBuildspeedDebuffHealthbars") then
		Script.LuaUI.UnitBuildspeedDebuffHealthbars(unitID, startFrame, expireFrame)
	end
end

local function unitBuildspeedDebuffEnd(_, unitID)
	if Script.LuaUI("UnitBuildspeedDebuffEndHealthbars") then
		Script.LuaUI.UnitBuildspeedDebuffEndHealthbars(unitID)
	end
end

function gadget:Initialize()
	gadgetHandler:AddSyncAction("UnitBuildDelayStarted", unitBuildspeedDebuff)
	gadgetHandler:AddSyncAction("UnitBuildDelayEnded", unitBuildspeedDebuffEnd)
end

function gadget:ShutDown()
	gadgetHandler:RemoveSyncAction("UnitBuildDelayStarted")
	gadgetHandler:RemoveSyncAction("UnitBuildDelayEnded")
end
