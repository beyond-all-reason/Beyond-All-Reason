local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = "Resurrection Behavior",
        desc      = "Handles starting health, wait until repair, and transferring oldUnit > corpse > newUnit data.",
        author    = "Floris, Chronographer, SethDGamre",
        date      = "4 November 2025",
        license   = "GNU GPL, v2 or later",
        layer     = 5,
        handler   = true,
        enabled   = true
    }
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local TIMEOUT = Game.gameSpeed * 3
local CMD_RESURRECT = CMD.RESURRECT
local CMD_WAIT = CMD.WAIT
local CMD_FIRE_STATE = CMD.FIRE_STATE
local CMD_MOVE_STATE = CMD.MOVE_STATE
local UPDATE_INTERVAL = Game.gameSpeed

local spGetGameFrame = Spring.GetGameFrame
local spGetUnitHealth = Spring.GetUnitHealth
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
local spGetFeatureRulesParam = Spring.GetFeatureRulesParam
local spSetUnitRulesParam = Spring.SetUnitRulesParam
local spGetUnitDefID = Spring.GetUnitDefID
local spSetFeatureRulesParam = Spring.SetFeatureRulesParam
local spGetUnitTeam = Spring.GetUnitTeam

local gameFrame = spGetGameFrame()

local corpseRegistryByDefID = {}
local rezUnitDefs = {}
local isBuilding = {}
local isBuilder = {}
local toBeUnWaited = {}
local prevHealth = {}
local currentCmd = {}

for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.canResurrect then
		rezUnitDefs[unitDefID] = true
	end
	if unitDef.isBuilding then
		isBuilding[unitDefID] = true
	end
	if unitDef.isBuilder then
		isBuilder[unitDefID] = true
	end
end


local function getPositionHash(x, z) -- we use hashing as a bridge between UnitDestroyed and FeatureCreated which are separated by their death animation duration.
	x = math.floor(x)
	z = math.floor(z)
	return string.format("%f:%f", x, z)
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	local unitDefLink = corpseRegistryByDefID[unitDefID]
	if not unitDefLink then
		unitDefLink = {}
		corpseRegistryByDefID[unitDefID] = unitDefLink
	end
	local x, y, z = Spring.GetUnitPosition(unitID)
	if not x then
		return
	end
	local xp = Spring.GetUnitExperience(unitID)
	local unitStates = Spring.GetUnitStates(unitID)
	local positionHash = getPositionHash(x, z)
	unitDefLink[positionHash] = {
		deadUnitID = unitID,
		unitTeam = unitTeam,
		xp = xp,
		attackerID = attackerID,
		attackerDefID = attackerDefID,
		attackerTeam = attackerTeam,
		attackerWeaponDefID = weaponDefID,
		firestate = unitStates.firestate,
		movestate = unitStates.movestate,
		timeout = gameFrame + TIMEOUT
	}
end


local function GetPriorUnitID(featureID)
	local resurrectData = Spring.GetFeatureResurrect(featureID)
	if resurrectData then
		local resurrectUnitName = resurrectData
		local resurrectUnitDefID
		if resurrectUnitName then
			local nameDef = UnitDefNames[resurrectUnitName]
			if nameDef then
				resurrectUnitDefID = nameDef.id
			else
				return -- Invalid unit name
			end
		end

		local x, y, z = Spring.GetFeaturePosition(featureID)
		local unitDefLink = corpseRegistryByDefID[resurrectUnitDefID]
		if unitDefLink and x then
			local positionHash = getPositionHash(x, z)
			local corpseLink = unitDefLink[positionHash]
			if corpseLink then
				spSetFeatureRulesParam(featureID, "corpse_deadUnitID", corpseLink.deadUnitID)
				spSetFeatureRulesParam(featureID, "corpse_xp", corpseLink.xp)
				spSetFeatureRulesParam(featureID, "restored_firestate", corpseLink.firestate)
				spSetFeatureRulesParam(featureID, "restored_movestate", corpseLink.movestate)
				unitDefLink[positionHash] = nil
				return corpseLink.deadUnitID
			end
		end
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if builderID then
		if rezUnitDefs[spGetUnitDefID(builderID)] then
			if (not isBuilding[unitDefID]) and (not isBuilder[unitDefID]) then
				toBeUnWaited[unitID] = true
				prevHealth[unitID] = 0
				spGiveOrderToUnit(unitID, CMD_WAIT, {}, 0)
			end
		end

		local cmdID, targetID = Spring.GetUnitWorkerTask(builderID)
		if cmdID == CMD_RESURRECT and targetID then
			local corpseLinkFeatureID = targetID - Game.maxUnits
			if corpseLinkFeatureID then
				local rezRulesParam = Spring.GetUnitRulesParam(unitID, "resurrected")
				if rezRulesParam == nil then
					spSetUnitRulesParam(unitID, "resurrected", 1, {inlos=true})
					Spring.SetUnitHealth(unitID, spGetUnitHealth(unitID) * 0.05)
				end

				spSetUnitRulesParam(unitID, "priorlife_deadUnitID", spGetFeatureRulesParam(corpseLinkFeatureID, "corpse_deadUnitID"), {inlos=true})
				local xp = spGetFeatureRulesParam(corpseLinkFeatureID, "corpse_xp")
				local firestate = spGetFeatureRulesParam(corpseLinkFeatureID, "restored_firestate")
				local movestate = spGetFeatureRulesParam(corpseLinkFeatureID, "restored_movestate")
				if firestate then
					spGiveOrderToUnit(unitID, CMD_FIRE_STATE, {tonumber(firestate)}, 0)
				end
				if movestate then
					spGiveOrderToUnit(unitID, CMD_MOVE_STATE, {tonumber(movestate)}, 0)
				end
				if xp then
					Spring.SetUnitExperience(unitID, tonumber(xp))
				end
			end
		end
	end
end


function gadget:GameFrame(frame)
	gameFrame = frame

	if frame % UPDATE_INTERVAL == 0 then
		for unitDefID, unitDefLink in pairs(corpseRegistryByDefID) do
			for positionHash, corpseLink in pairs(unitDefLink) do
				if corpseLink.timeout < frame then
					unitDefLink[positionHash] = nil
				end
			end
		end
		if next(toBeUnWaited) ~= nil then
			for unitID, check in pairs(toBeUnWaited) do
				local health = spGetUnitHealth(unitID)
				if not health then
					toBeUnWaited[unitID] = nil
					prevHealth[unitID] = nil
				elseif health <= prevHealth[unitID] then -- stopped healing
					toBeUnWaited[unitID] = nil
					prevHealth[unitID] = nil
					currentCmd = spGetUnitCurrentCommand(unitID, 1)
					if currentCmd and currentCmd == CMD_WAIT then
						spGiveOrderToUnit(unitID, CMD_WAIT, {}, 0)
					end
				else
					prevHealth[unitID] = health
				end
			end
		end
	end
end

local originalFeatureCreated

function gadget:Initialize()
	local allUnits = Spring.GetAllUnits()
	for i = 1, #allUnits do
		local unitID = allUnits[i]
		gadget:UnitCreated(unitID, spGetUnitDefID(unitID), spGetUnitTeam(unitID))
	end

	originalFeatureCreated = gadgetHandler.FeatureCreated
	gadgetHandler.FeatureCreated = function(self, featureID, allyTeam, sourceID)
		local priorUnitID = sourceID or GetPriorUnitID(featureID)
		originalFeatureCreated(self, featureID, allyTeam, priorUnitID)
	end
end

function gadget:Shutdown()
	gadgetHandler.FeatureCreated = originalFeatureCreated
end

