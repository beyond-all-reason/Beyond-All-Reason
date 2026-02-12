local gadget = gadget ---@class Gadget

function gadget:GetInfo()
    return {
        name      = 'Legion Con Turret Metal Extractor',
        desc      = 'Allows the mex to function as a con turret by replacing it with a fake mex with a con turret attached',
        author    = 'EnderRobo',
        version   = 'v2',
        date      = 'September 2024',
        license   = 'GNU GPL, v2 or later',
        layer     = 12, -- TODO: Why?
        enabled   = true, -- auto-disables
    }
end

if not gadgetHandler:IsSyncedCode() then
    return false
end

local spGetUnitHealth = Spring.GetUnitHealth

-- TODO: do not use hardcoded unit names
local unitDefData = {
	legmohocon = { mex = "legmohoconin", con = "legmohoconct" },
}
for unitName, unitPair in pairs(unitDefData) do
	if not unitName:find("_scav") then
		unitDefData[unitName .. "_scav"] = {
			mex = unitPair.mex .. "_scav",
			con = unitPair.con .. "_scav",
		}
	end
end

local fakeBuildDefID = {} -- combined mex + con unit model used while constructing
local mexActualDefID = {} -- the mex, which is non-interactive, but extracts metal
local mexTurretDefID = {} -- the con, which is interactive and shows in GUI, etc.

for unitName, unitPair in pairs(unitDefData) do
	local buildDef = UnitDefNames[unitName]
	local conDef = UnitDefNames[unitPair.mex]
	local mexDef = UnitDefNames[unitPair.con]

	if buildDef and conDef and mexDef then
		fakeBuildDefID[buildDef.id] = { mex = conDef.id, con = mexDef.id }
		mexActualDefID[mexDef.id] = true
		mexTurretDefID[conDef.id] = unitName -- for heaps/wrecks
	end
end

local isExtractor = {}
for unitDefID, unitDef in ipairs(UnitDefs) do
	if unitDef.extractsMetal > 0 then
		isExtractor[unitDefID] = true
	end
end

if not next(fakeBuildDefID) or not next(isExtractor) then
	return false
end

local mexesToSwap = {}
local pairedUnits = {}

local function doSwapMex(unitID, unitTeam, unitData)
	local Spring = Spring

	local isUnitNeutral = Spring.GetUnitNeutral(unitID)
	local unitHealth = spGetUnitHealth(unitID)
	--local unitExtraction = Spring.GetUnitMetalExtraction(unitID) or 0

	Spring.DestroyUnit(unitID, false, true) -- clears unitID from mexesToSwap in g:UnitDestroyed

	local ux, uy, uz, unitFacing = unitData.x, unitData.y, unitData.z, unitData.facing

	local mexID = Spring.CreateUnit(unitData.swapDefs.mex, ux, uy, uz, unitFacing, unitTeam)
	if not mexID then
		Spring.AddTeamResource(unitTeam, "m", unitData.metal)
		Spring.AddTeamResource(unitTeam, "e", unitData.energy)
		return
	end
	Spring.SetUnitBlocking(mexID, true, true, false)
	Spring.SetUnitNoSelect(mexID, true)

	local conID = Spring.CreateUnit(unitData.swapDefs.con, ux, uy, uz, unitFacing, unitTeam)
	if not conID then
		Spring.DestroyUnit(mexID, false, true)
		Spring.AddTeamResource(unitTeam, "m", unitData.metal)
		Spring.AddTeamResource(unitTeam, "e", unitData.energy)
		return
	end
	-- TODO: Get attachment piece by customparam.
	Spring.UnitAttach(mexID, conID, 6)
	Spring.SetUnitRulesParam(conID, "pairedUnitID", mexID)
	Spring.SetUnitRulesParam(mexID, "pairedUnitID", conID)
	pairedUnits[conID] = mexID
	pairedUnits[mexID] = conID

	Spring.SetUnitHealth(conID, unitHealth)
	Spring.SetUnitStealth(conID, true)

	if isUnitNeutral then
		Spring.SetUnitNeutral(mexID, true)
		Spring.SetUnitNeutral(conID, true)
	end
end

local function trySwapMex(unitID, unitData)
	if Spring.GetUnitIsDead(unitID) ~= false then
		return
	end

	local unitTeam = Spring.GetUnitTeam(unitID)
	local unitMax, unitCount = Spring.GetTeamMaxUnits(unitTeam)

	if not unitCount or unitMax < unitCount + 2 then
		return
	end

	doSwapMex(unitID, unitTeam, unitData)
end

function gadget:GameFrame(frame)
	for unitID, unitData in pairs(mexesToSwap) do
		-- TODO: WTF:
		if frame > unitData.frame then
			trySwapMex(unitID, unitData)
		end
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if fakeBuildDefID[unitDefID] then
		local swapDefs = fakeBuildDefID[unitDefID]
		local ux, uy, uz = Spring.GetUnitPosition(unitID)
		local _, metalCost, energyCost = Spring.GetUnitCosts(unitID)

		mexesToSwap[unitID] = {
			swapDefs = swapDefs,
			x        = ux,
			y        = uy,
			z        = uz,
			facing   = Spring.GetUnitBuildFacing(unitID),
			metal    = metalCost,
			energy   = energyCost,
			frame    = Spring.GetGameFrame() + 1,
		}
    end
end

function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	if mexTurretDefID[unitDefID] then
		local pairedID = pairedUnits[unitID]
		if not pairedID and Spring.GetUnitRulesParam then
			pairedID = Spring.GetUnitRulesParam(unitID, "pairedUnitID")
		end
		if pairedID and pairedID ~= 0 then
			Spring.TransferUnit(pairedID, newTeam)
		end
    end
end

local function doUnitDamaged(unitID, unitDefID, unitTeam, damage)
	local health, maxHealth = spGetUnitHealth(unitID)

	if health - damage < 0 and damage < maxHealth * 0.5 then
		local buildAsUnitName = mexTurretDefID[unitDefID]
		local xx, yy, zz = Spring.GetUnitPosition(unitID)
		local facing = Spring.GetUnitBuildFacing(unitID)

		-- todo: "damage" is not "recent damage" is not "damage severity"
		if damage < maxHealth * 0.25 then
			local featureID = Spring.CreateFeature(buildAsUnitName .. "_dead" , xx, yy, zz, facing, unitTeam)
			if featureID then
				Spring.SetFeatureResurrect(featureID, buildAsUnitName, facing, 0)
			end
		else
			Spring.CreateFeature(buildAsUnitName .. "_heap", xx, yy, zz, facing, unitTeam)
		end
	end
end
function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	if mexTurretDefID[unitDefID] and not paralyzer then
        doUnitDamaged(unitID, unitDefID, unitTeam, damage)
    end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	mexesToSwap[unitID] = nil

	if mexActualDefID[unitDefID] or mexTurretDefID[unitDefID] then
		local pairedUnitID = pairedUnits[unitID]
		if pairedUnitID then
			pairedUnits[pairedUnitID] = nil
			Spring.DestroyUnit(pairedUnitID, false, true)
		end
    end
end

function gadget:Initialize()
	for _, unitID in pairs(Spring.GetAllUnits()) do
		if not Spring.GetUnitIsBeingBuilt(unitID) then
			gadget:UnitFinished(unitID, Spring.GetUnitDefID(unitID), Spring.GetUnitTeam(unitID))
		end
	end
end
