function gadget:GetInfo()
	return {
		name = "Reclaim Stats",
		desc = "Collect reclaim and resurrect stats for widgets to use",
		author = "CMDR*Zod",
		date = "2024",
		license = "GNU GPL v3, or later",
		layer = -1,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then return end

local spGetTeamRulesParam = Spring.GetTeamRulesParam
local spSetTeamRulesParam = Spring.SetTeamRulesParam
local spGetFeatureResources = Spring.GetFeatureResources
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitHealth = Spring.GetUnitHealth
local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local spGetFeatureResurrect = Spring.GetFeatureResurrect
local spGetTeamResources = Spring.GetTeamResources

local incomeUpdateRate = 30
local resurrectEnergyCostFactor = Game.resurrectEnergyCostFactor

local paramNamePrefix = "metric_"

local metalReclaimIncomeParamName = paramNamePrefix .. "metalReclaimIncome"
local energyReclaimIncomeParamName = paramNamePrefix .. "energyReclaimIncome"

local metalReclaimParamName = paramNamePrefix .. "metalReclaim"
local energyReclaimParamName = paramNamePrefix .. "energyReclaim"

local metalResurrectParamName = paramNamePrefix .. "metalResurrect"
local energyResurrectParamName = paramNamePrefix .. "energyResurrect"

local allUnitReclaimMetalParamName = paramNamePrefix .. "allUnitReclaimMetal"
local labUnitReclaimMetalParamName = paramNamePrefix .. "labUnitReclaimMetal"
local eprodUnitReclaimMetalParamName = paramNamePrefix .. "eprodUnitReclaimMetal"

local teamData = {}

local isFactory = {}
local isEProd = {}
local featureListMaxResource = {}
local featureListReclaimTime = {}
local unitListReclaimSpeed = {}

local function isEnergyProductionUnit(unitDef)
	return unitDef.customParams and unitDef.customParams.unitgroup and unitDef.customParams.unitgroup == "energy"
end

for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.reclaimSpeed > 0 then
		unitListReclaimSpeed[unitDefID] = unitDef.reclaimSpeed / 30
	end

	if unitDef.isFactory then
		isFactory[unitDefID] = true
	end

	if isEnergyProductionUnit(unitDef) then
		isEProd[unitDefID] = true
	end
end

for featureDefID, fdefs in pairs(FeatureDefs) do
	local maxResource = math.max(fdefs.metal, fdefs.energy)

	if maxResource > 0 then
		featureListMaxResource[featureDefID] = maxResource
		featureListReclaimTime[featureDefID] = fdefs.reclaimTime
	end
end

local function buildTeamData()
	for _, allyID in ipairs(Spring.GetAllyTeamList()) do
		if allyID ~= gaiaAllyID then
			local teamList = Spring.GetTeamList(allyID)
			for _,teamID in ipairs(teamList) do
				teamData[teamID] = {}

				teamData[teamID].metalReclaimIncome = 0
				spSetTeamRulesParam(teamID, metalReclaimIncomeParamName, 0)
				teamData[teamID].energyReclaimIncome = 0
				spSetTeamRulesParam(teamID, energyReclaimIncomeParamName, 0)

				teamData[teamID].metalReclaim = 0
				spSetTeamRulesParam(teamID, metalReclaimParamName, 0)
				teamData[teamID].energyReclaim = 0
				spSetTeamRulesParam(teamID, energyReclaimParamName, 0)

				teamData[teamID].metalResurrect = 0
				spSetTeamRulesParam(teamID, metalResurrectParamName, 0)
				teamData[teamID].energyResurrect = 0
				spSetTeamRulesParam(teamID, energyResurrectParamName, 0)

				teamData[teamID].allUnitReclaimMetal = 0
				spSetTeamRulesParam(teamID, allUnitReclaimMetalParamName, 0)
				teamData[teamID].labUnitReclaimMetal = 0
				spSetTeamRulesParam(teamID, labUnitReclaimMetalParamName, 0)
				teamData[teamID].eprodUnitReclaimMetal = 0
				spSetTeamRulesParam(teamID, eprodUnitReclaimMetalParamName, 0)
			end
		end
	end
end

local function updateIncome()
	for teamID,currTeamData in pairs(teamData) do
		spSetTeamRulesParam(teamID, metalReclaimIncomeParamName, currTeamData.metalReclaimIncome)
		currTeamData.metalReclaimIncome = 0
		spSetTeamRulesParam(teamID, energyReclaimIncomeParamName, currTeamData.energyReclaimIncome)
		currTeamData.energyReclaimIncome = 0
	end
end

function gadget:AllowFeatureBuildStep(builderID, builderTeam, featureID, featureDefID, step)
	-- metal, defMetal, energy, defEnergy, reclaimLeft, reclaimTime
	local featureMetal, featureDefMetal, featureEnergy, featureDefEnergy, reclaimLeft = spGetFeatureResources(featureID)

	local stepMetal = step * featureDefMetal
	local stepEnergy = step * featureDefEnergy

	if step < 0 then
		local unitDefID = spGetUnitDefID(builderID)
		local maxResource = featureListMaxResource[featureDefID]
		local reclaimTime = featureListReclaimTime[featureDefID]
		local reclaimSpeed = unitListReclaimSpeed[unitDefID]
		if maxResource and reclaimTime and reclaimSpeed then
			local oldformula = -1 * (reclaimSpeed*0.70 + 10*0.30) * 1.5  / reclaimTime
			stepMetal = oldformula * featureDefMetal
			stepEnergy = oldformula * featureDefEnergy
		end
	end

	-- Note: if steps are negative then it means it's reclaim. Positive values for step means feature is being
	-- resurrected or being fed back metal for resurrection.

	if step < 0 then
		-- only update non-zero changes. for example, trees have only energy, rocks only metal etc.
		if stepMetal < 0 then
			teamData[builderTeam].metalReclaim = teamData[builderTeam].metalReclaim - stepMetal
			spSetTeamRulesParam(builderTeam, metalReclaimParamName, teamData[builderTeam].metalReclaim)

			teamData[builderTeam].metalReclaimIncome = teamData[builderTeam].metalReclaimIncome - stepMetal
		end
		if stepEnergy < 0 then
			teamData[builderTeam].energyReclaim = teamData[builderTeam].energyReclaim - stepEnergy
			spSetTeamRulesParam(builderTeam, energyReclaimParamName, teamData[builderTeam].energyReclaim)

			teamData[builderTeam].energyReclaimIncome = teamData[builderTeam].energyReclaimIncome - stepEnergy
		end
	else  -- step > 0
		if reclaimLeft < 1 then
			-- feature is being fed metal to reach full reclaim
			teamData[builderTeam].metalResurrect = teamData[builderTeam].metalResurrect + stepMetal
			spSetTeamRulesParam(builderTeam, metalResurrectParamName, teamData[builderTeam].metalResurrect)
		else
			-- feature is being fed energy to be resurrected
			local unitDefName = spGetFeatureResurrect(featureID)
			if unitDefName then
				local unitEnergyCost = UnitDefNames[unitDefName].energyCost
				local resurrectEnergyCostStep = unitEnergyCost * step * resurrectEnergyCostFactor

				-- can they afford it?
				local energyCurrentLevel = spGetTeamResources(builderTeam, "e")
				if energyCurrentLevel and (energyCurrentLevel >= resurrectEnergyCostStep) then
					teamData[builderTeam].energyResurrect = teamData[builderTeam].energyResurrect + resurrectEnergyCostStep
					spSetTeamRulesParam(builderTeam, energyResurrectParamName, teamData[builderTeam].energyResurrect)
				end
			end
		end
	end

	return true
end

function gadget:AllowUnitBuildStep(builderID, builderTeam, unitID, unitDefID, step)
	-- make sure it's reclaim, ignore build and repair
	if step >= 0 then
		return true
	end

	local health, maxHealth = spGetUnitHealth(unitID)
	local postHealth = health + maxHealth * step
	if postHealth <= 0 then
		local beingBuilt, buildProgress = spGetUnitIsBeingBuilt(unitID)
		local unitMetalCost = UnitDefs[unitDefID].metalCost

		local metalReceived
		if beingBuilt then
			metalReceived = unitMetalCost * buildProgress
		else
			metalReceived = unitMetalCost
		end

		teamData[builderTeam].allUnitReclaimMetal = teamData[builderTeam].allUnitReclaimMetal + metalReceived
		spSetTeamRulesParam(builderTeam, allUnitReclaimMetalParamName, teamData[builderTeam].allUnitReclaimMetal)

		teamData[builderTeam].metalReclaimIncome = teamData[builderTeam].metalReclaimIncome + metalReceived

		if isFactory[unitDefID] then
			teamData[builderTeam].labUnitReclaimMetal = teamData[builderTeam].labUnitReclaimMetal + metalReceived
			spSetTeamRulesParam(builderTeam, labUnitReclaimMetalParamName, teamData[builderTeam].labUnitReclaimMetal)
		end

		if isEProd[unitDefID] then
			teamData[builderTeam].eprodUnitReclaimMetal = teamData[builderTeam].eprodUnitReclaimMetal + metalReceived
			spSetTeamRulesParam(builderTeam, eprodUnitReclaimMetalParamName, teamData[builderTeam].eprodUnitReclaimMetal)
		end
	end

	return true
end

function gadget:GameFrame(frame)
	if (frame % incomeUpdateRate ~= 0) then
		return
	end

	updateIncome()
end

function gadget:Initialize()
	buildTeamData()
end
