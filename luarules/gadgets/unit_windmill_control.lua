local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Windmill Control",
		desc = "Controls windmill helix",
		author = "quantum (modified by Krogoth86)",
		date = "June 29, 2007",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

-- Energy paid per wind strength on top of the engine's own; AddUnitResource ignores negative amounts
local windBonus = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	local multiplier = unitDef.windGenerator > 0 and tonumber(unitDef.customParams.energymultiplier)
	if multiplier and multiplier > 1 then
		windBonus[unitDefID] = multiplier - 1
	end
end

if not next(windBonus) then
	return false
end

local AddUnitResource = Spring.AddUnitResource
local GetUnitIsStunned = Spring.GetUnitIsStunned
local GetWind = Spring.GetWind

-- Each windmill is paid once per second, on the frame picked by its unitID
local PAY_INTERVAL = Game.gameSpeed
local windmills = {} -- [frame % PAY_INTERVAL][unitID] = bonus
for phase = 0, PAY_INTERVAL - 1 do
	windmills[phase] = {}
end
local windmillCount = 0

local function addWindmill(unitID, unitDefID)
	local bucket = windmills[unitID % PAY_INTERVAL]
	if bucket[unitID] then
		return
	end
	bucket[unitID] = windBonus[unitDefID]
	windmillCount = windmillCount + 1
	if windmillCount == 1 then
		gadgetHandler:UpdateCallIn("GameFrame")
	end
end

local function removeWindmill(unitID)
	local bucket = windmills[unitID % PAY_INTERVAL]
	if not bucket[unitID] then
		return
	end
	bucket[unitID] = nil
	windmillCount = windmillCount - 1
	if windmillCount == 0 then
		gadgetHandler:RemoveCallIn("GameFrame")
	end
end

function gadget:GameFrame(n)
	local bucket = windmills[n % PAY_INTERVAL]
	if next(bucket) then
		local _, _, _, strength = GetWind()
		for unitID, bonus in pairs(bucket) do
			if not GetUnitIsStunned(unitID) then
				AddUnitResource(unitID, "e", strength * bonus)
			end
		end
	end
end

function gadget:Initialize()
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		local unitDefID = Spring.GetUnitDefID(unitID)
		if windBonus[unitDefID] then
			addWindmill(unitID, unitDefID)
		end
	end
	if windmillCount == 0 then
		gadgetHandler:RemoveCallIn("GameFrame")
	end
end

function gadget:UnitFinished(unitID, unitDefID)
	if windBonus[unitDefID] then
		addWindmill(unitID, unitDefID)
	end
end

function gadget:UnitDestroyed(unitID, unitDefID)
	if windBonus[unitDefID] then
		removeWindmill(unitID)
	end
end
