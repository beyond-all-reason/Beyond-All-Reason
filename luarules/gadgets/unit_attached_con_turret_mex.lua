local gadget = gadget ---@class Gadget

function gadget:GetInfo()
	return {
		name = "Legion Con Turret Metal Extractor",
		desc = "Allows the mex to function as a con turret by replacing it with a fake mex with a con turret attached",
		author = "EnderRobo",
		version = "v2",
		date = "September 2024",
		license = "GNU GPL, v2 or later",
		layer = 12, -- TODO: Why?
		enabled = true, -- auto-disables
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local spGetUnitHealth = Engine.Shared.GetUnitHealth
local spGiveOrderToUnit = Engine.Shared.GiveOrderToUnit

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
	local conDef = UnitDefNames[unitPair.con]
	local mexDef = UnitDefNames[unitPair.mex]

	if buildDef and conDef and mexDef then
		fakeBuildDefID[buildDef.id] = { con = conDef.id, mex = mexDef.id }
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
local setMexSpeed = {}

local function setExtractionRate(conID, mexID)
	local extractionRate = Engine.Shared.GetUnitMetalExtraction(mexID)
	Engine.Synced.CallCOBScript(conID, "SetSpeed", 0, (extractionRate or 0) * 1000) -- COB is scaled for integer-only
end

local function doSwapMex(unitID, unitTeam, unitData)
	local Spring = Spring

	local isUnitNeutral = Engine.Shared.GetUnitNeutral(unitID)
	local unitHealth = spGetUnitHealth(unitID)

	Engine.Synced.DestroyUnit(unitID, false, true) -- clears unitID from mexesToSwap in g:UnitDestroyed

	local ux, uy, uz, unitFacing = unitData.x, unitData.y, unitData.z, unitData.facing

	local mexID = Engine.Synced.CreateUnit(unitData.swapDefs.mex, ux, uy, uz, unitFacing, unitTeam)
	if not mexID then
		Engine.Synced.AddTeamResource(unitTeam, "m", unitData.metal)
		Engine.Synced.AddTeamResource(unitTeam, "e", unitData.energy)
		return
	end
	Engine.Synced.SetUnitBlocking(mexID, true, true, false)
	Engine.Unsynced.SetUnitNoSelect(mexID, true)
	Engine.Synced.SetUnitStealth(mexID, true)

	local conID = Engine.Synced.CreateUnit(unitData.swapDefs.con, ux, uy, uz, unitFacing, unitTeam)
	if not conID then
		Engine.Synced.DestroyUnit(mexID, false, true)
		Engine.Synced.AddTeamResource(unitTeam, "m", unitData.metal)
		Engine.Synced.AddTeamResource(unitTeam, "e", unitData.energy)
		return
	end
	Engine.Synced.SetUnitHealth(conID, unitHealth)

	-- TODO: Get attachment piece by customparam.
	Engine.Synced.UnitAttach(mexID, conID, 6, true)
	Engine.Synced.SetUnitRulesParam(conID, "pairedUnitID", mexID)
	Engine.Synced.SetUnitRulesParam(mexID, "pairedUnitID", conID)
	pairedUnits[conID] = mexID
	pairedUnits[mexID] = conID
	setMexSpeed[conID] = mexID

	if isUnitNeutral then
		Engine.Synced.SetUnitNeutral(mexID, true)
		Engine.Synced.SetUnitNeutral(conID, true)
	end
end

local function trySwapMex(unitID, unitData)
	if Engine.Shared.GetUnitIsDead(unitID) ~= false then
		return
	end

	local unitTeam = Engine.Shared.GetUnitTeam(unitID)
	local unitMax, unitCount = Engine.Shared.GetTeamMaxUnits(unitTeam)

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

	for conID, mexID in pairs(setMexSpeed) do
		setExtractionRate(conID, mexID) -- used in unit animations
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if fakeBuildDefID[unitDefID] then
		local swapDefs = fakeBuildDefID[unitDefID]
		local ux, uy, uz = Engine.Shared.GetUnitPosition(unitID)
		local _, metalCost, energyCost = Engine.Shared.GetUnitCosts(unitID)

		mexesToSwap[unitID] = {
			swapDefs = swapDefs,
			x = ux,
			y = uy,
			z = uz,
			facing = Engine.Shared.GetUnitBuildFacing(unitID),
			metal = metalCost,
			energy = energyCost,
			frame = Engine.Shared.GetGameFrame() + 1,
		}
	end
end

function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	if mexTurretDefID[unitDefID] then
		local pairedID = pairedUnits[unitID]
		if not pairedID and Engine.Shared.GetUnitRulesParam then
			pairedID = Engine.Shared.GetUnitRulesParam(unitID, "pairedUnitID")
		end
		if pairedID and pairedID ~= 0 then
			Engine.Synced.TransferUnit(pairedID, newTeam)
		end
	end
end

local function doUnitDamaged(unitID, unitDefID, unitTeam, damage)
	local health, maxHealth = spGetUnitHealth(unitID)

	if health - damage < 0 and damage < maxHealth * 0.5 then
		local buildAsUnitName = mexTurretDefID[unitDefID]
		local xx, yy, zz = Engine.Shared.GetUnitPosition(unitID)
		local facing = Engine.Shared.GetUnitBuildFacing(unitID)

		-- todo: "damage" is not "recent damage" is not "damage severity"
		if damage < maxHealth * 0.25 then
			local featureID = Engine.Synced.CreateFeature(buildAsUnitName .. "_dead", xx, yy, zz, facing, unitTeam)
			if featureID then
				Engine.Synced.SetFeatureResurrect(featureID, buildAsUnitName, facing, 0)
			end
		else
			Engine.Synced.CreateFeature(buildAsUnitName .. "_heap", xx, yy, zz, facing, unitTeam)
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
			pairedUnits[unitID] = nil
			pairedUnits[pairedUnitID] = nil
			Engine.Synced.DestroyUnit(pairedUnitID, false, true)
		end
	end
end

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua, fromInsert)
	-- accepts CMD.ONOFF:
	if mexTurretDefID[unitDefID] then
		local mexID = pairedUnits[unitID]
		if mexID then
			spGiveOrderToUnit(mexID, cmdID, cmdParams, cmdOptions)
			setMexSpeed[unitID] = mexID
		end
	end
	return true
end

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD.ONOFF)

	for _, unitID in pairs(Engine.Shared.GetAllUnits()) do
		if not Engine.Shared.GetUnitIsBeingBuilt(unitID) then
			local unitDefID = Engine.Shared.GetUnitDefID(unitID)
			gadget:UnitFinished(unitID, unitDefID)

			if mexActualDefID[unitDefID] then
				local pairedUnitID = Engine.Shared.GetUnitRulesParam(unitID, "pairedUnitID")
				if pairedUnitID then
					pairedUnits[unitID] = pairedUnitID
					pairedUnits[pairedUnitID] = unitID
					setMexSpeed[pairedUnitID] = unitID
				end
			end
		end
	end
end
