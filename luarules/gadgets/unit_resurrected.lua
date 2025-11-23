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
local NOT_REZZING = -1 --not a positive number
local CMD_RESURRECT = CMD.RESURRECT
local CMD_WAIT = CMD.WAIT
local MODULO = Game.gameSpeed

local gameFrame = Spring.GetGameFrame()

local spGetUnitHealth = Spring.GetUnitHealth
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand

local unitDefLinks = {}
local rezUnitDefs = {}
local rezzingUnits = {}
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

GG.CorpseToUnitLink = GG.CorpseToUnitLink or {}

local function getPositionHash(x, z) -- we use hashing as a bridge between UnitDestroyed and FeatureCreated which are separated by their death animation duration.
	x = math.floor(x)
	z = math.floor(z)
	return string.format("%f:%f", x, z)
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	local unitDefLink = unitDefLinks[unitDefID]
	if not unitDefLink then
		unitDefLink = {}
		unitDefLinks[unitDefID] = unitDefLink
	end
	local x, y, z = Spring.GetUnitPosition(unitID)
	if not x then
		return
	end
	local xp = Spring.GetUnitExperience(unitID)
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
		local unitDefLink = unitDefLinks[resurrectUnitDefID]
		if unitDefLink and x then
			local positionHash = getPositionHash(x, z)
			local corpseLink = unitDefLink[positionHash]
			if corpseLink then
				GG.CorpseToUnitLink[featureID] = {
					deadUnitID = corpseLink.deadUnitID,
					unitTeam = corpseLink.unitTeam,
					xp = corpseLink.xp,
					attackerID = corpseLink.attackerID,
					attackerDefID = corpseLink.attackerDefID,
					attackerTeam = corpseLink.attackerTeam,
					attackerWeaponDefID = corpseLink.attackerWeaponDefID,
				}
				unitDefLink[positionHash] = nil
			end
		end
	end
end

function gadget:FeatureDestroyed(featureID, allyTeam)
	GG.CorpseToUnitLink[featureID] = nil
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if rezUnitDefs[unitDefID] then
		rezzingUnits[unitID] = NOT_REZZING
	end
	if builderID and rezUnitDefs[Spring.GetUnitDefID(builderID)] then
		if (not isBuilding[unitDefID]) and (not isBuilder[unitDefID]) then
			toBeUnWaited[unitID] = true
			prevHealth[unitID] = 0
			spGiveOrderToUnit(unitID, CMD_WAIT, {}, 0)
		end
	end
	local corpseLinkFeatureID = rezzingUnits[builderID]
	if corpseLinkFeatureID then
		if GG.CorpseToUnitLink[corpseLinkFeatureID] then
			local rezRulesParam = Spring.GetUnitRulesParam(unitID, "resurrected")
			if rezRulesParam == nil then
				Spring.SetUnitRulesParam(unitID, "resurrected", 1, {inlos=true})
				Spring.SetUnitHealth(unitID, Spring.GetUnitHealth(unitID) * 0.05)
			end
			Spring.SetUnitExperience(unitID, GG.CorpseToUnitLink[corpseLinkFeatureID].xp)
		end
	end
end

function gadget:unitDestroyed(unitID, unitDefID, unitTeam)
	rezzingUnits[unitID] = nil
	toBeUnWaited[unitID] = nil
	prevHealth[unitID] = nil
end

function gadget:GameFrame(frame)
	gameFrame = frame

	if frame % MODULO == 0 then
		for unitDefID, unitDefLink in pairs(unitDefLinks) do
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

	for unitID, rezzing in pairs(rezzingUnits) do
		local currentTask, targetID = Spring.GetUnitWorkerTask(unitID)
		if currentTask == CMD_RESURRECT and targetID then
			local featureID = targetID - Game.maxUnits
			rezzingUnits[unitID] = featureID
		end
	end
end

function gadget:Initialize()
	local allUnits = Spring.GetAllUnits()
	for i = 1, #allUnits do
		local unitID = allUnits[i]
		gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID), Spring.GetUnitTeam(unitID))
	end
end

