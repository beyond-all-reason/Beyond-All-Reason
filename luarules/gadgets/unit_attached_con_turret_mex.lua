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

local spGetUnitHealth = Spring.GetUnitHealth
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local SendToUnsynced = SendToUnsynced

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
	local extractionRate = Spring.GetUnitMetalExtraction(mexID)
	Spring.CallCOBScript(conID, "SetSpeed", 0, (extractionRate or 0) * 1000) -- COB is scaled for integer-only
end

local function doSwapMex(unitID, unitTeam, unitData)
	local Spring = Spring

	local isUnitNeutral = Spring.GetUnitNeutral(unitID)
	local unitHealth = spGetUnitHealth(unitID)

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
	SendToUnsynced("setUnitNoGroup", mexID, true)
	Spring.SetUnitStealth(mexID, true)

	local conID = Spring.CreateUnit(unitData.swapDefs.con, ux, uy, uz, unitFacing, unitTeam)
	if not conID then
		Spring.DestroyUnit(mexID, false, true)
		Spring.AddTeamResource(unitTeam, "m", unitData.metal)
		Spring.AddTeamResource(unitTeam, "e", unitData.energy)
		return
	end
	Spring.SetUnitHealth(conID, unitHealth)

	-- TODO: Get attachment piece by customparam.
	Spring.UnitAttach(mexID, conID, 6, true)
	Spring.SetUnitRulesParam(conID, "pairedUnitID", mexID)
	Spring.SetUnitRulesParam(mexID, "pairedUnitID", conID)
	pairedUnits[conID] = mexID
	pairedUnits[mexID] = conID
	setMexSpeed[conID] = mexID

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

	for conID, mexID in pairs(setMexSpeed) do
		setExtractionRate(conID, mexID) -- used in unit animations
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if fakeBuildDefID[unitDefID] then
		local swapDefs = fakeBuildDefID[unitDefID]
		local ux, uy, uz = Spring.GetUnitPosition(unitID)
		local _, metalCost, energyCost = Spring.GetUnitCosts(unitID)

		mexesToSwap[unitID] = {
			swapDefs = swapDefs,
			x = ux,
			y = uy,
			z = uz,
			facing = Spring.GetUnitBuildFacing(unitID),
			metal = metalCost,
			energy = energyCost,
			frame = Spring.GetGameFrame() + 1,
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

-- Remains are derived from its base build def, created manually on death.
local recentDamage = {} -- con turret unitID -> summed damage taken this frame
local recentDamageFrame = {} -- con turret unitID -> frame of that damage
local deathDamage = {} -- con turret unitID -> recent damage that proved lethal

local function createRemains(unitID, unitDefID, unitTeam)
	local buildAsUnitName = mexTurretDefID[unitDefID]
	if not buildAsUnitName then
		return
	end

	-- only damage kills leave remains; reclaim, self-destruct and pair-removal don't
	local damage = deathDamage[unitID]
	if not damage then
		return
	end

	local xx, yy, zz = Spring.GetUnitPosition(unitID)
	if not xx then
		return
	end

	-- killing-blow severity picks between wreck, heap and nothing
	local maxHealth = UnitDefs[unitDefID].health
	local facing = Spring.GetUnitBuildFacing(unitID)

	if damage > maxHealth * 0.5 then
		return -- obliterated: nothing left to salvage
	elseif damage <= maxHealth * 0.25 then
		local featureID = Spring.CreateFeature(buildAsUnitName .. "_dead", xx, yy, zz, facing, unitTeam)
		if featureID then
			Spring.SetFeatureResurrect(featureID, buildAsUnitName, facing, 0)
		end
	else
		Spring.CreateFeature(buildAsUnitName .. "_heap", xx, yy, zz, facing, unitTeam)
	end
end

function gadget:UnitDamaged(
	unitID,
	unitDefID,
	unitTeam,
	damage,
	paralyzer,
	weaponDefID,
	projectileID,
	attackerID,
	attackerDefID,
	attackerTeam
)
	if mexTurretDefID[unitDefID] and not paralyzer then
		local frame = Spring.GetGameFrame()
		if recentDamageFrame[unitID] == frame then
			recentDamage[unitID] = recentDamage[unitID] + damage
		else
			recentDamage[unitID] = damage
			recentDamageFrame[unitID] = frame
		end

		local health = spGetUnitHealth(unitID) -- post-damage; at or below zero this hit is lethal
		if health and health <= 0 then
			deathDamage[unitID] = recentDamage[unitID]
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	mexesToSwap[unitID] = nil

	if mexTurretDefID[unitDefID] then
		createRemains(unitID, unitDefID, unitTeam)
		recentDamage[unitID] = nil
		recentDamageFrame[unitID] = nil
		deathDamage[unitID] = nil
	end

	if mexActualDefID[unitDefID] or mexTurretDefID[unitDefID] then
		local pairedUnitID = pairedUnits[unitID]
		if pairedUnitID then
			pairedUnits[unitID] = nil
			pairedUnits[pairedUnitID] = nil
			Spring.DestroyUnit(pairedUnitID, false, true)
		end
	end
end

function gadget:AllowCommand(
	unitID,
	unitDefID,
	unitTeam,
	cmdID,
	cmdParams,
	cmdOptions,
	cmdTag,
	playerID,
	fromSynced,
	fromLua,
	fromInsert
)
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

	for _, unitID in pairs(Spring.GetAllUnits()) do
		if not Spring.GetUnitIsBeingBuilt(unitID) then
			local unitDefID = Spring.GetUnitDefID(unitID)
			gadget:UnitFinished(unitID, unitDefID)

			if mexActualDefID[unitDefID] then
				local pairedUnitID = Spring.GetUnitRulesParam(unitID, "pairedUnitID")
				if pairedUnitID then
					pairedUnits[unitID] = pairedUnitID
					pairedUnits[pairedUnitID] = unitID
					setMexSpeed[pairedUnitID] = unitID
				end
			end
		end
	end
end
