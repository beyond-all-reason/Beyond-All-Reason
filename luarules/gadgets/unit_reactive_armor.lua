function gadget:GetInfo()
	return {
		name    = "Reactive Armor",
		desc    = "Units get armor when not damaged for a while",
		author  = "Sprung",
		date    = "2025-11-13",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true,
	}
end

local spGetUnitDefID = Spring.GetUnitDefID

local reactiveDefs = {}

for unitDefID, unitDef in pairs(UnitDefs) do
	local cp = unitDef.customParams
	if  cp.reactive_armor_health
	and cp.reactive_armor_restore_duration
	and cp.reactive_armor_restore_delay then
		reactiveDefs[unitDefID] = {
			health = tonumber(cp.reactive_armor_health),
			restore_delay = tonumber(cp.reactive_armor_restore_delay),
			restore_duration = tonumber(cp.reactive_armor_restore_duration) * Game.gameSpeed,
		}
	end
end

local reactiveUnits = {} -- [unitID] = { broken = bool, damage = number accumulator, restore_start = frame?, restore_end = frame? }
local startRestoreByFrame = {} -- [n] = { [unitID] = true, [unitID] = true, ... }
local endRestoreByFrame   = {} -- [n] = { [unitID] = true, [unitID] = true, ... }

function gadget:UnitDamaged(unitID, unitDefID, teamID, damage, paralyzer)
	local unitData = reactiveUnits[unitID]
	if not unitData then
		return
	end

	if unitData.restore_start then
		startRestoreByFrame[unitData.restore_start][unitID] = nil
		unitData.restore_start = nil
	elseif unitData.restore_end then
		endRestoreByFrame[unitData.restore_end][unitID] = nil
		unitData.restore_end = nil
	end

	local delay = reactiveDef.restore_delay
	local frame = Spring.GetGameFrame() + delay * Game.gameSpeed
	data.restore_start = frame
	local frameData = startRestoreByFrame[frame] or {}
	frameData[unitID] = true
	startRestoreByFrame[frame] = frameData

	unitData.damage = unitData.damage + damage
	if unitData.damage > reactiveDef.health and not unitData.broken then
		unitData.broken = true
		Spring.SetUnitArmored(unitID, false) -- TODO should rather be an attribute eventually
		Spring.CallCOBScript(unitID, "ReactiveArmorBroken", 0, delay) -- TODO support lus
	end
end

function gadget:GameFramePost(n)
	for unitID in pairs(startRestoreByFrame[n]) do
		local unitData = reactiveUnits[unitID]
		unitData.restore_start = nil
		local duration = reactiveDefs[spGetUnitDefID(unitID)].restore_duration
		unitData.restore_end = n + duration * Game.gameSpeed
		Spring.CallCOBScript(unitID, "ReactiveArmorRestoring", 0, duration)
	end
	startRestoreByFrame[n] = nil

	for unitID in pairs(endRestoreByFrame[n]) do
		local unitData = reactiveUnits[unitID]
		unitData.damage = 0
		unitData.restore_end = nil
		unitData.broken = false
		Spring.CallCOBScript(unitID, "ReactiveArmorRestored", 0, reactiveDefs[spGetUnitDefID(unitID)].health)
		Spring.SetUnitArmored(unitID, true)
	end
	endRestoreByFrame[n] = nil
end

function gadget:UnitCreated(unitID, unitDefID)
	local reactiveDef = reactiveDefs[unitDefID]
	if not reactiveDef then
		return
	end

	reactiveUnits[unitID] = { damage = 0, broken = false }
	Spring.SetUnitArmored(unitID, true)
	Spring.CallCOBScript(unitID, "ReactiveArmorInit", 0, reactiveDef.health)
end

function gadget:Initialize()
	local units = Spring.GetAllUnits()
	for i = 1, #units do
		local unitID = units[i]
		gadget:UnitCreated(unitID, spGetUnitDefID(unitID))
	end
end
