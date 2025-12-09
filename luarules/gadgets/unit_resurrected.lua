local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = "Resurrection Behavior",
        desc      = "Handles starting health, wait until repair, and transferring oldUnit > corpse > newUnit data.",
        author    = "Floris, Chronographer, SethDGamre",
        date      = "4 November 2025",
        license   = "GNU GPL, v2 or later",
        layer     = 5,
        enabled   = true
    }
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local TIMEOUT = Game.gameSpeed * 3
local CMD_RESURRECT = CMD.RESURRECT
local CMD_WAIT = CMD.WAIT
local UPDATE_INTERVAL = Game.gameSpeed

local spGetGameFrame = Spring.GetGameFrame
local spGetUnitHealth = Spring.GetUnitHealth
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
local spGetFeatureRulesParam = Spring.GetFeatureRulesParam
local spSetUnitRulesParam = Spring.SetUnitRulesParam
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitWorkerTask = Spring.GetUnitWorkerTask
local spSetUnitHealth = Spring.SetUnitHealth
local spSetUnitExperience = Spring.SetUnitExperience
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitExperience = Spring.GetUnitExperience
local spGetFeaturePosition = Spring.GetFeaturePosition
local spGetFeatureResurrect = Spring.GetFeatureResurrect
local spSetFeatureRulesParam = Spring.SetFeatureRulesParam
local spGetUnitTeam = Spring.GetUnitTeam
local spGetAllUnits = Spring.GetAllUnits
local spGetUnitRulesParam = Spring.GetUnitRulesParam

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
	local x, y, z = spGetUnitPosition(unitID)
	if not x then
		return
	end
	local xp = spGetUnitExperience(unitID)
	local positionHash = getPositionHash(x, z)
	unitDefLink[positionHash] = {
		deadUnitID = unitID,
		unitTeam = unitTeam,
		xp = xp,
		attackerID = attackerID,
		attackerDefID = attackerDefID,
		attackerTeam = attackerTeam,
		attackerWeaponDefID = weaponDefID,
		timeout = gameFrame + TIMEOUT
	}
end

function gadget:FeatureCreated(featureID, allyTeam)
	local resurrectData = spGetFeatureResurrect(featureID)
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

		local x, y, z = spGetFeaturePosition(featureID)
		local unitDefLink = corpseRegistryByDefID[resurrectUnitDefID]
		if unitDefLink and x then
			local positionHash = getPositionHash(x, z)
			local corpseLink = unitDefLink[positionHash]
			if corpseLink then
				spSetFeatureRulesParam(featureID, "corpse_deadUnitID", corpseLink.deadUnitID)
				spSetFeatureRulesParam(featureID, "corpse_unitTeam", corpseLink.unitTeam)
				spSetFeatureRulesParam(featureID, "corpse_xp", corpseLink.xp)
				spSetFeatureRulesParam(featureID, "killerID", corpseLink.attackerID)
				spSetFeatureRulesParam(featureID, "killerTeam", corpseLink.attackerTeam)
				unitDefLink[positionHash] = nil
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

		local cmdID, targetID = spGetUnitWorkerTask(builderID)
		if cmdID == CMD_RESURRECT and targetID then
			local corpseLinkFeatureID = targetID - Game.maxUnits
			if corpseLinkFeatureID then
				local rezRulesParam = spGetUnitRulesParam(unitID, "resurrected")
				if rezRulesParam == nil then
					spSetUnitRulesParam(unitID, "resurrected", 1, {inlos=true})
					spSetUnitHealth(unitID, spGetUnitHealth(unitID) * 0.05)
				end

				spSetUnitRulesParam(unitID, "priorlife_deadUnitID", spGetFeatureRulesParam(corpseLinkFeatureID, "corpse_deadUnitID"), {inlos=true})
				spSetUnitRulesParam(unitID, "priorlife_unitTeam", spGetFeatureRulesParam(corpseLinkFeatureID, "corpse_unitTeam"), {inlos=true})
				local xp = spGetFeatureRulesParam(corpseLinkFeatureID, "corpse_xp")
				spSetUnitRulesParam(unitID, "priorlife_xp", xp, {inlos=true})
				spSetUnitRulesParam(unitID, "priorlife_killerID", spGetFeatureRulesParam(corpseLinkFeatureID, "killerID"), {inlos=true})
				spSetUnitRulesParam(unitID, "priorlife_killerTeam", spGetFeatureRulesParam(corpseLinkFeatureID, "killerTeam"), {inlos=true})
				if xp then
					spSetUnitExperience(unitID, tonumber(xp))
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

function gadget:Initialize()
	local allUnits = spGetAllUnits()
	for i = 1, #allUnits do
		local unitID = allUnits[i]
		gadget:UnitCreated(unitID, spGetUnitDefID(unitID), spGetUnitTeam(unitID))
	end
end

