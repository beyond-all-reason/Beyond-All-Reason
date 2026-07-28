local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Share Policy Forwarding",
		desc = "Forwards sharing-policy events from synced (transfer controllers) to LuaUI widgets.",
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

local function sharePolicyChanged(_, teamId, domain)
	if Script.LuaUI("SharePolicyChanged") then
		Script.LuaUI.SharePolicyChanged(tonumber(teamId), domain)
	end
end

-- Per-unit manifestations of the constructor-build-delay policy.
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
	gadgetHandler:AddSyncAction("SharePolicyChanged", sharePolicyChanged)
	gadgetHandler:AddSyncAction("UnitBuildDelayStarted", unitBuildspeedDebuff)
	gadgetHandler:AddSyncAction("UnitBuildDelayEnded", unitBuildspeedDebuffEnd)
end

function gadget:ShutDown()
	gadgetHandler:RemoveSyncAction("SharePolicyChanged")
	gadgetHandler:RemoveSyncAction("UnitBuildDelayStarted")
	gadgetHandler:RemoveSyncAction("UnitBuildDelayEnded")
end
