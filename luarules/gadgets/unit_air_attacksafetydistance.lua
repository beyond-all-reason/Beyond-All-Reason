local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name      = "Air AttackSafetyDistance",
		desc      = "sets attackSafetyDistance for fighters",
		author    = "Doo, Floris",
		date      = "Sept 19th 2017",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true
	}
end

--[[
	Wiki: "attackSafetyDistance" movetypedata: Fighters abort dive toward target if within attackSafetyDistance and
	try to climb back to normal altitude while still moving toward target.	It's disabled by default. Set to half of
	the minimum weapon range to avoid collisions, enemy fire, AOE damage. If set to greater than the weapon range,
	the unit will fly over the target like a bomber.
]]--

if not gadgetHandler:IsSyncedCode() then
	return
end

local isFighter = {}
for udid, ud in pairs(UnitDefs) do
	if ud.canFly and ud.customParams.fighter then
		isFighter[udid] = true
	end
end

function gadget:Initialize()
	for ct, unitID in pairs(Spring.GetAllUnits()) do
		gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID))
	end
end

function gadget:UnitCreated(unitID, unitDefID)
	if isFighter[unitDefID] then
		local curMoveCtrl = Spring.MoveCtrl.IsEnabled(unitID)
		if curMoveCtrl then
			Spring.MoveCtrl.Disable(unitID)
		end
		Spring.MoveCtrl.SetAirMoveTypeData(unitID, "attackSafetyDistance", 300)
		if curMoveCtrl then
			Spring.MoveCtrl.Enable(unitID)
		end
	end
end
