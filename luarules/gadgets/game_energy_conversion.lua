local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = 'Energy Conversion',
		desc = 'Handles converting energy to metal',
		author = 'Niobium(modified by TheFatController, Finkky)',
		version = 'v2.3',
		date = 'May 2011',
		license = 'GNU GPL, v2 or later',
		layer = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

-- gather all metalmaker units
local convertCapacities = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.customParams.energyconv_capacity and unitDef.customParams.energyconv_efficiency then
		convertCapacities[unitDefID] = { c = tonumber(unitDef.customParams.energyconv_capacity), e = tonumber(unitDef.customParams.energyconv_efficiency) }
	end
end

local alterLevelRegex = '^' .. string.char(137) .. '(%d+)$'
local mmLevelParamName = 'mmLevel'
local mmCapacityParamName = 'mmCapacity'
local mmUseParamName = 'mmUse'
local mmAvgEffiParamName = 'mmAvgEffi'
local function SetMMRulesParams()
	-- make convertCapacities accessible to all
	for uDID, conv in pairs(convertCapacities) do
		local unitName = UnitDefs[uDID].name or ""
		local capacity = conv.c
		local ratio = conv.e
		Spring.SetGameRulesParam(unitName .. "_mm_capacity", capacity)
		Spring.SetGameRulesParam(unitName .. "_mm_ratio", ratio)
	end
end

local frameRate = 30
local resourceRefreshRate = 15 -- In Frames
local resourceFraction = resourceRefreshRate / frameRate
local resourceUpdatesPerGameSec = frameRate / resourceRefreshRate

local currentFrameStamp = 0

local teamList = {}
local teamCapacities = {}
local teamMMList = {}
local teamEfficiencies = {}
local teamMMLevels = {}
local teamTotalCapacities = {}
local teamUsages = {}
local teamAverageEfficiencies = {}
local eSteps = {}
local eStepsCount = 0
local teamActiveMM = {}

local paralysisRelRate = 75 -- unit HP / paralysisRelRate = paralysis dmg drop rate per slowupdate

----------------------------------------------------------------
-- Speedups
----------------------------------------------------------------

local spGetPlayerInfo = Spring.GetPlayerInfo
local spSetTeamRulesParam = Spring.SetTeamRulesParam
local spGetTeamResources = Spring.GetTeamResources
local spGetUnitHealth = Spring.GetUnitHealth
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitDefID = Spring.GetUnitDefID
local spSetUnitResourcing = Spring.SetUnitResourcing
local spCallCOBScript = Spring.CallCOBScript
local spGetTeamList = Spring.GetTeamList
local mathCeil = math.ceil
local tableSort = table.sort

----------------------------------------------------------------
-- Functions
----------------------------------------------------------------

local function AdjustTeamCapacity(teamID, adjustment, e)
	local teamCaps = teamCapacities[teamID]
	teamCaps[e] = teamCaps[e] + adjustment
	local totalCapacity = teamTotalCapacities[teamID] + adjustment
	teamTotalCapacities[teamID] = totalCapacity
	spSetTeamRulesParam(teamID, mmCapacityParamName, totalCapacity)
end

local function updateUnitConversion(unitID, unitData, amount, e)
	if unitData.energyUse == amount then
		return
	end
	unitData.energyUse = amount
	spSetUnitResourcing(unitID, "umm", amount * e)
	spSetUnitResourcing(unitID, "uue", amount)
end

local function UpdateMetalMakers(teamID, energyUse)
	-- Only skip if there are no converters at all (nothing to turn on or off)
	-- We need to process even when energyUse <= 0 to turn off active converters
	local activeCount = teamActiveMM[teamID]
	if activeCount == 0 and energyUse <= 0 then
		return
	end

	local teamMM = teamMMList[teamID]
	for j = 1, eStepsCount do
		local eStep = eSteps[j]
		local teamMMUnits = teamMM[eStep]
		for unitID, defs in pairs(teamMMUnits) do
			if defs.built then
				if not defs.emped and energyUse > 0 then
					local cap = defs.capacity
					local amount = energyUse < cap and energyUse or cap
					if amount < 0 then
						amount = 0
					end
					energyUse = energyUse - cap
					updateUnitConversion(unitID, defs, amount, eStep)

					if defs.status == 0 then
						spCallCOBScript(unitID, "MMStatus", 0, 1)
						defs.status = 1
						activeCount = activeCount + 1
					end
				else
					if defs.status == 1 then
						updateUnitConversion(unitID, defs, 0, 0)
						spCallCOBScript(unitID, "MMStatus", 0, 0)
						defs.status = 0
						activeCount = activeCount - 1
					end
				end
			end
		end
	end
	teamActiveMM[teamID] = activeCount
end

----------------------------------------------------------------
-- Pseudo Callins
----------------------------------------------------------------

local function UnitParalysed(uID, uDefID, uTeam)
	local cDefs = convertCapacities[uDefID]
	if cDefs then
		local unitData = teamMMList[uTeam][cDefs.e][uID]
		if unitData and unitData.built then
			unitData.emped = true
			AdjustTeamCapacity(uTeam, -cDefs.c, cDefs.e)
		end
	end
end

local function UnitParalysisOver(uID, uDefID, uTeam)
	local cDefs = convertCapacities[uDefID]
	if cDefs then
		local unitData = teamMMList[uTeam][cDefs.e][uID]
		if unitData and unitData.built then
			unitData.emped = false
			AdjustTeamCapacity(uTeam, cDefs.c, cDefs.e)
		end
	end
end

----------------------------------------------------------------
-- EmpedVector Methods
----------------------------------------------------------------
local EmpedVector = { unitBuffer = {} }

function EmpedVector:push(uID, frameID)
	if self.unitBuffer[uID] then
		self.unitBuffer[uID] = frameID
	else
		self.unitBuffer[uID] = frameID
		UnitParalysed(uID, spGetUnitDefID(uID), spGetUnitTeam(uID))
	end
end

function EmpedVector:process(currentFrame)
	for uID, frameID in pairs(self.unitBuffer) do
		if currentFrame >= frameID then
			UnitParalysisOver(uID, spGetUnitDefID(uID), spGetUnitTeam(uID))
			self.unitBuffer[uID] = nil
		end
	end
end

----------------------------------------------------------------
-- Efficiencies Methods
----------------------------------------------------------------
local efficiencySampleCount = 4

local function NewEfficiencyTracker()
	return { pointer = 0, activeSamples = 0, sumM = 0, sumE = 0 }
end

local function PushEfficiency(tracker, metal, energy)
	local sampleIndex = tracker.pointer + 1
	local metalIndex = sampleIndex * 2 - 1
	local energyIndex = metalIndex + 1
	local oldEnergy = tracker[energyIndex] or 0
	local activeSamples = tracker.activeSamples
	if oldEnergy > 0 then
		activeSamples = activeSamples - 1
	end
	if energy > 0 then
		activeSamples = activeSamples + 1
	end
	local sumM = tracker.sumM - (tracker[metalIndex] or 0) + metal
	local sumE = tracker.sumE - oldEnergy + energy
	if activeSamples == 0 then
		sumM = 0
		sumE = 0
	end

	tracker[metalIndex] = metal
	tracker[energyIndex] = energy
	tracker.activeSamples = activeSamples
	tracker.sumM = sumM
	tracker.sumE = sumE
	tracker.pointer = sampleIndex % efficiencySampleCount

	if sumE > 0 then
		return sumM / sumE
	end
	return 0
end

local function BuildESteps()
	local seenEfficiencies = {}
	for _, defs in pairs(convertCapacities) do
		if not seenEfficiencies[defs.e] then
			seenEfficiencies[defs.e] = true
			eSteps[#eSteps + 1] = defs.e
		end
	end
	tableSort(eSteps, function(m1, m2)
		return m1 > m2
	end)
	eStepsCount = #eSteps
end

----------------------------------------------------------------
-- Callins
----------------------------------------------------------------
function gadget:Initialize()
	SetMMRulesParams()
	BuildESteps()
	teamList = spGetTeamList()
	local teamListCount = #teamList
	for i = 1, teamListCount do
		local tID = teamList[i]
		teamCapacities[tID] = {}
		teamEfficiencies[tID] = NewEfficiencyTracker()
		teamMMLevels[tID] = 0.75
		teamTotalCapacities[tID] = 0
		teamUsages[tID] = 0
		teamAverageEfficiencies[tID] = 0
		teamMMList[tID] = {}
		teamActiveMM[tID] = 0
		for j = 1, eStepsCount do
			teamCapacities[tID][eSteps[j]] = 0
			teamMMList[tID][eSteps[j]] = {}
		end
		spSetTeamRulesParam(tID, mmLevelParamName, 0.75)
		spSetTeamRulesParam(tID, mmCapacityParamName, 0)
		spSetTeamRulesParam(tID, mmUseParamName, 0)
		spSetTeamRulesParam(tID, mmAvgEffiParamName, 0)

	end
end

function gadget:GameFrame(n)
	local frameOffset = n % resourceRefreshRate
	-- process emped in the least likely used frame by the actual per team maker computations
	if frameOffset == resourceRefreshRate - 1 then
		currentFrameStamp = currentFrameStamp + 1
		EmpedVector:process(currentFrameStamp)
	end

	-- process a team in each gameframe so that all teams are process exactly once in every 15 gameframes
	-- in case of more than 15 teams ingame, two or more teams are processed in one gameframe
	local teamListCount = #teamList
	for tpos = frameOffset + 1, teamListCount, resourceRefreshRate do
		local tID = teamList[tpos]
		local efficiencyTracker = teamEfficiencies[tID]
		if teamTotalCapacities[tID] ~= 0 or teamActiveMM[tID] ~= 0 or efficiencyTracker.activeSamples ~= 0 then
			local eCur, eStor = spGetTeamResources(tID, 'energy')
			local mmLevel = teamMMLevels[tID]
			local convertAmount = eCur - eStor * mmLevel
			local eConverted, mConverted = 0, 0

			local teamCaps = teamCapacities[tID]
			for j = 1, eStepsCount do
				local eStep = eSteps[j]
				local teamCapacity = teamCaps[eStep]
				if teamCapacity > 1 then
					if convertAmount > 1 then
						local convertStep = teamCapacity * resourceFraction
						if convertStep > convertAmount then
							convertStep = convertAmount
					end
						eConverted = convertStep + eConverted
						mConverted = convertStep * eStep + mConverted
						convertAmount = convertAmount - convertStep
					else
						break
				end
				end
			end

			local avgEfficiency = PushEfficiency(efficiencyTracker, mConverted, eConverted)
			local tUsage = resourceUpdatesPerGameSec * eConverted
			UpdateMetalMakers(tID, tUsage)
			if teamUsages[tID] ~= tUsage then
				teamUsages[tID] = tUsage
				spSetTeamRulesParam(tID, mmUseParamName, tUsage)
			end
			if teamAverageEfficiencies[tID] ~= avgEfficiency then
				teamAverageEfficiencies[tID] = avgEfficiency
				spSetTeamRulesParam(tID, mmAvgEffiParamName, avgEfficiency)
			end
		end
	end
end

function gadget:UnitCreated(uID, uDefID, uTeam, builderID)
	if convertCapacities[uDefID] then
		teamMMList[uTeam][convertCapacities[uDefID].e][uID] = { capacity = 0, status = 0, built = false, emped = false, energyUse = false }
	end
end

function gadget:UnitFinished(uID, uDefID, uTeam)
	local cDefs = convertCapacities[uDefID]
	if not cDefs then
		return
	end

	local teamMM = teamMMList[uTeam][cDefs.e]
	if not teamMM[uID] then
		teamMM[uID] = { capacity = 0, status = 0, built = false, emped = false, energyUse = false }
	end

	local unitData = teamMM[uID]
	unitData.capacity = cDefs.c
	unitData.built = true

	if not unitData.emped then
		unitData.status = 1
		teamActiveMM[uTeam] = teamActiveMM[uTeam] + 1
		spCallCOBScript(uID, "MMStatus", 0, 1)
		AdjustTeamCapacity(uTeam, cDefs.c, cDefs.e)
	end
end

function gadget:UnitDamaged(uID, uDefID, uTeam, damage, paralyzer)
	if paralyzer and convertCapacities[uDefID] then
		local _, maxHealth, paralyzeDamage, _, _ = spGetUnitHealth(uID)
		local relativeParDmg = paralyzeDamage - maxHealth
		if relativeParDmg > 0 then
			EmpedVector:push(uID, currentFrameStamp + mathCeil(relativeParDmg / (maxHealth / paralysisRelRate)))
		end
	end
end

function gadget:UnitDestroyed(uID, uDefID, uTeam)
	local cDefs = convertCapacities[uDefID]
	if not cDefs then
		return
	end

	local teamMM = teamMMList[uTeam][cDefs.e]
	local unitData = teamMM[uID]
	if not unitData then
		return
	end

	if unitData.built then
		if unitData.status == 1 then
			teamActiveMM[uTeam] = teamActiveMM[uTeam] - 1
		end

		if not unitData.emped then
			AdjustTeamCapacity(uTeam, -cDefs.c, cDefs.e)
		end
	end
	teamMM[uID] = nil
end

function gadget:UnitGiven(uID, uDefID, newTeam, oldTeam)
	local cDefs = convertCapacities[uDefID]
	if not cDefs then
		return
	end

	local oldTeamMM = teamMMList[oldTeam][cDefs.e]
	local oldUnitData = oldTeamMM[uID]
	if not oldUnitData then
		return
	end

	if oldUnitData.built then
		if not oldUnitData.emped then
			AdjustTeamCapacity(oldTeam, -cDefs.c, cDefs.e)
			AdjustTeamCapacity(newTeam, cDefs.c, cDefs.e)
		end
		if oldUnitData.status == 1 then
			teamActiveMM[oldTeam] = teamActiveMM[oldTeam] - 1
			teamActiveMM[newTeam] = teamActiveMM[newTeam] + 1
		end
	end

	teamMMList[newTeam][cDefs.e][uID] = {
		capacity = oldUnitData.capacity,
		status = oldUnitData.status,
		emped = oldUnitData.emped,
		built = oldUnitData.built,
		energyUse = false,
	}

	oldTeamMM[uID] = nil
end

function gadget:RecvLuaMsg(msg, playerID)
	if string.byte(msg, 1) ~= 137 then return end -- fast guard: first byte must be char(137)
	local newLevel = tonumber(msg:match(alterLevelRegex))
	if newLevel and newLevel >= 0 and newLevel <= 100 then
		local _, _, playerIsSpec, playerTeam = spGetPlayerInfo(playerID, false)
		if playerTeam and not playerIsSpec then -- NB: playerTeam is nil for replay-watching specs
			local mmLevel = newLevel / 100
			if teamMMLevels[playerTeam] ~= mmLevel then
				teamMMLevels[playerTeam] = mmLevel
				spSetTeamRulesParam(playerTeam, mmLevelParamName, mmLevel)
			end
			return true
		end
	end
end
