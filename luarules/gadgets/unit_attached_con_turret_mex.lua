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
local spGiveOrderToUnit = Spring.GiveOrderToUnit

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

-- The con turret has no corpse of its own, so its remains are created here by
-- hand. They MUST be created when the unit actually dies, never predicted from
-- an incoming hit: UnitDamaged runs *after* the engine has already subtracted
-- the damage, so testing `health - damage` there subtracts it twice and fires a
-- hit early. That left a live, still-extracting Fortifier standing inside its
-- own blocking wreck, whose collision box is far larger than the unit's and so
-- absorbed the shots that should have finished it off.
local lastDamage = {} -- con turret unitID -> damage of its most recent hit
local lastDamageFrame = {} -- con turret unitID -> frame of that hit

local function createRemains(unitID, unitDefID, unitTeam)
	local buildAsUnitName = mexTurretDefID[unitDefID]
	if not buildAsUnitName then
		return
	end

	-- Remains are only for units killed by damage: dead at <= 0 health, with a
	-- damage event on this or the previous frame. This excludes reclaim,
	-- self-destruct and being removed because the paired unit died — none of
	-- which fire UnitDamaged, and none of which should leave remains.
	local health = spGetUnitHealth(unitID)
	if not health or health > 0 then
		return
	end
	local damageFrame = lastDamageFrame[unitID]
	if not damageFrame or Spring.GetGameFrame() - damageFrame > 1 then
		return
	end

	local xx, yy, zz = Spring.GetUnitPosition(unitID)
	if not xx then
		return
	end

	-- severity of the killing blow still picks the remains, as before
	local maxHealth = UnitDefs[unitDefID].health
	local damage = lastDamage[unitID] or 0
	local facing = Spring.GetUnitBuildFacing(unitID)

	if damage >= maxHealth * 0.5 then
		return -- obliterated outright: nothing left to salvage
	elseif damage < maxHealth * 0.25 then
		local featureID = Spring.CreateFeature(buildAsUnitName .. "_dead" , xx, yy, zz, facing, unitTeam)
		if featureID then
			Spring.SetFeatureResurrect(featureID, buildAsUnitName, facing, 0)
		end
	else
		Spring.CreateFeature(buildAsUnitName .. "_heap", xx, yy, zz, facing, unitTeam)
	end
end

function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	if mexTurretDefID[unitDefID] and not paralyzer then
		lastDamage[unitID] = damage
		lastDamageFrame[unitID] = Spring.GetGameFrame()
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	mexesToSwap[unitID] = nil

	if mexTurretDefID[unitDefID] then
		createRemains(unitID, unitDefID, unitTeam)
		lastDamage[unitID] = nil
		lastDamageFrame[unitID] = nil
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
