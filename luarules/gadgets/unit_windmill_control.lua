local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Windmill Control",
		desc = "Controls windmill helix",
		author = "quantum (modified by Krogoth86)",
		date = "June 29, 2007",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

 -- Only apply these when resource multipliers are active, to save performance
local energyMultActive = false
if Spring.GetModOptions().multiplier_energyproduction * Spring.GetModOptions().multiplier_resourceincome ~= 1 then
	energyMultActive = true
end

local windDefs = {}
local unitEnergyMultiplier = {}
for udid, ud in pairs(UnitDefs) do
	if ud.windGenerator > 0 then
		if energyMultActive then
			windDefs[udid] = true
		end
		if ud.customParams.energymultiplier then
			unitEnergyMultiplier[udid] = tonumber(ud.customParams.energymultiplier)
			windDefs[udid] = true
		end
	end
end

local windmills = {}

local GetCOBScriptID = Spring.GetCOBScriptID
local AddUnitResource = Spring.AddUnitResource
local GetUnitIsStunned = Spring.GetUnitIsStunned
--local CallCOBScript = Spring.CallCOBScript
--local GetHeadingFromVector = Spring.GetHeadingFromVector

function gadget:GameFrame(n)
	if (n + 15) % 30 < 0.1 then
		local _, _, _, strength, x, _, z = Spring.GetWind()
		for unitID, scriptIDs in pairs(windmills) do
			if not GetUnitIsStunned(unitID) then
				AddUnitResource(unitID, "e", strength * (scriptIDs.mult - 1))
			end
			--CallCOBScript(unitID, scriptIDs.speed, 0, strength * scriptIDs.mult * COBSCALE * 0.010)
			--CallCOBScript(unitID, scriptIDs.dir,   0, GetHeadingFromVector(-x, -z))
		end
	end
end

local function SetupUnit(unitID, unitDefID)
	windmills[unitID] = {
		speed = GetCOBScriptID(unitID, "LuaSetSpeed"),
		dir = GetCOBScriptID(unitID, "LuaSetDirection"),
		mult = unitEnergyMultiplier[unitDefID] or 1,
	}
end

function gadget:Initialize()
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		local unitDefID = Spring.GetUnitDefID(unitID)
		if windDefs[unitDefID] then
			SetupUnit(unitID, unitDefID)
		end
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if windDefs[unitDefID] then
		SetupUnit(unitID, unitDefID)
	end
end

function gadget:UnitTaken(unitID, unitDefID, unitTeam)
	if windDefs[unitDefID] then
		SetupUnit(unitID, unitDefID)
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	if windDefs[unitDefID] then
		windmills[unitID] = nil
	end
end
