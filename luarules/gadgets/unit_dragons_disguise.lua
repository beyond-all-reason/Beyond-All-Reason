local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Dragons Disguise",
		desc = "Sets Dragons claw & dragons maw to Neutral when closed",
		author = "TheFatController",
		date = "25 Nov 2008",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local GetUnitCOBValue = Spring.GetUnitCOBValue
local SetUnitNeutral = Engine.Synced.SetUnitNeutral
local ValidUnitID = Engine.Shared.ValidUnitID
local neutralUnits = {}
local armourTurrets = {}
for udid, ud in ipairs(UnitDefs) do
	if ud.customParams then
		if ud.customParams.neutral_when_closed then
			armourTurrets[udid] = true
		end
	end
end
local UPDATE = 30
local timeCounter = 15

function gadget:Initialize()
	for _, unitID in ipairs(Engine.Shared.GetAllUnits()) do
		if not Engine.Shared.GetUnitIsBeingBuilt(unitID) then
			---@diagnostic disable-next-line: missing-parameter, param-type-mismatch -- OK
			gadget:UnitFinished(unitID, Engine.Shared.GetUnitDefID(unitID))
		end
	end
end

function gadget:GameFrame(n)
	if n >= timeCounter then
		timeCounter = (n + UPDATE)
		for unitID, neutral in pairs(neutralUnits) do
			if not ValidUnitID(unitID) then
				neutralUnits[unitID] = nil
			else
				local cobValue = GetUnitCOBValue(unitID, 20)
				if cobValue then
					local armoured = (cobValue > 0)
					if neutral and not armoured then
						SetUnitNeutral(unitID, false)
						neutralUnits[unitID] = false
					elseif (not neutral) and armoured then
						SetUnitNeutral(unitID, true)
						neutralUnits[unitID] = true
					end
				end
			end
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	neutralUnits[unitID] = nil
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if armourTurrets[unitDefID] then
		if GetUnitCOBValue(unitID, 20) == 1 then
			SetUnitNeutral(unitID, true)
			neutralUnits[unitID] = true
		else
			neutralUnits[unitID] = false
		end
	end
end
