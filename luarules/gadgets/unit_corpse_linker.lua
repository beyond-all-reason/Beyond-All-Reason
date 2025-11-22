function gadget:GetInfo()
	return {
		name      = "Frame Logger",
		desc      = "Logs frames for unit destruction, feature creation, and synced XP reporting for render destruction (using SendLuaRulesMsg)",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local TIMEOUT = Game.gameSpeed * 3
local NOT_REZZING = -1 --not a positive number
local CMD_RESURRECT = CMD.RESURRECT

local gameFrame = Spring.GetGameFrame()

local unitDefLinks = {}
local rezUnitDefs = {}
local rezzingUnits = {}

for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.canResurrect then
		rezUnitDefs[unitDefID] = true
	end
end

if not GG then GG = {} end
GG.CorpseToUnitLink = GG.CorpseToUnitLink or {}

local function getPositionHash(x, z)
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
	local corpseLinkFeatureID = rezzingUnits[builderID]
	if corpseLinkFeatureID then
		if GG.CorpseToUnitLink[corpseLinkFeatureID] then
			Spring.SetUnitExperience(unitID, GG.CorpseToUnitLink[corpseLinkFeatureID].xp)
		end
	end
end

function gadget:unitDestroyed(unitID, unitDefID, unitTeam)
	rezzingUnits[unitID] = nil
end

function gadget:GameFrame(frame)
	gameFrame = frame

	if frame % 10 == 0 then
		for unitDefID, unitDefLink in pairs(unitDefLinks) do
			for positionHash, corpseLink in pairs(unitDefLink) do
				if corpseLink.timeout < frame then
					unitDefLink[positionHash] = nil
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
