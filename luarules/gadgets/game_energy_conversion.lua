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
local eSteps = {}
local teamActiveMM = {}
local splitMMPointer = 1

local paralysisRelRate = 75 -- unit HP / paralysisRelRate = paralysis dmg drop rate per slowupdate

----------------------------------------------------------------
-- Speedups
----------------------------------------------------------------

local spGetPlayerInfo = Spring.GetPlayerInfo
local spGetTeamRulesParam = Spring.GetTeamRulesParam
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

local function prototype(t)
	local u = { }
	for k, v in pairs(t) do
		u[k] = v
	end
	return setmetatable(u, getmetatable(t))
end

local function AdjustTeamCapacity(teamID, adjustment, e)
	local newCapacity = teamCapacities[teamID][e] + adjustment
	teamCapacities[teamID][e] = newCapacity

	local totalCapacity = 0
	local eStepsCount = #eSteps
	for j = 1, eStepsCount do
		totalCapacity = totalCapacity + teamCapacities[teamID][eSteps[j]]
	end
	spSetTeamRulesParam(teamID, mmCapacityParamName, totalCapacity)
end

local function updateUnitConversion(unitID, amount, e)
	spSetUnitResourcing(unitID, "umm", amount * e)
	spSetUnitResourcing(unitID, "uue", amount)
end

local function UpdateMetalMakers(teamID, energyUse)
	-- Only skip if there are no converters at all (nothing to turn on or off)
	-- We need to process even when energyUse <= 0 to turn off active converters
	if teamActiveMM[teamID] == 0 and energyUse <= 0 then
		return
	end
	
	local eStepsCount = #eSteps
	for j = 1, eStepsCount do
		local eStep = eSteps[j]
		local teamMMUnits = teamMMList[teamID][eStep]
		for unitID, defs in pairs(teamMMUnits) do
			if defs.built then
				if not defs.emped and energyUse > 0 then
					local amount = (energyUse < defs.capacity and energyUse or defs.capacity)    -- alternative math.min method
					if amount < 0 then
						amount = 0
					end
					energyUse = (energyUse - defs.capacity)
					updateUnitConversion(unitID, amount, eStep)

					if defs.status == 0 then
						spCallCOBScript(unitID, "MMStatus", 0, 1)
						defs.status = 1
						teamActiveMM[teamID] = (teamActiveMM[teamID] + 1)
					end
				else
					if defs.status == 1 then
						updateUnitConversion(unitID, 0, 0)
						spCallCOBScript(unitID, "MMStatus", 0, 0)
						defs.status = 0
						teamActiveMM[teamID] = (teamActiveMM[teamID] - 1)
					end
				end
			end
		end
	end
end

----------------------------------------------------------------
-- Pseudo Callins
----------------------------------------------------------------

local function UnitParalysed(uID, uDefID, uTeam)
	if convertCapacities[uDefID] then
		local cDefs = convertCapacities[uDefID]
		if teamMMList[uTeam][cDefs.e][uID].built then
			teamMMList[uTeam][cDefs.e][uID].emped = true
			AdjustTeamCapacity(uTeam, -cDefs.c, cDefs.e)
		end
	end
end

local function UnitParalysisOver(uID, uDefID, uTeam)
	if convertCapacities[uDefID] then
		local cDefs = convertCapacities[uDefID]
		if teamMMList[uTeam][cDefs.e][uID] and teamMMList[uTeam][cDefs.e][uID].built then
			teamMMList[uTeam][cDefs.e][uID].emped = false
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
local Efficiencies = { size = 4, buffer = {}, pointer = 0, tID = -1 }

function Efficiencies:avg()
	local sumE = 0
	local sumM = 0
	local nonZeroCount = 0
	for j = 1, self.size do
		if not (self.buffer[j] == nil) then
			sumM = sumM + self.buffer[j].m
			sumE = sumE + self.buffer[j].e
			nonZeroCount = nonZeroCount + 1
		end
	end
	if nonZeroCount > 0 and sumE > 0 then
		return sumM / sumE
	end
	return 0
end

function Efficiencies:push(o)
	self.buffer[self.pointer + 1] = o
	self.pointer = (self.pointer + 1) % self.size
end

function Efficiencies:init(tID)
	for j = 1, self.size do
		self.buffer[j] = nil
	end
	self.tID = tID
end

----------------------------------------------------------------
-- Callins
----------------------------------------------------------------
function gadget:Initialize()
	SetMMRulesParams()
	BuildeSteps()
	teamList = spGetTeamList()
	local teamListCount = #teamList
	local eStepsCount = #eSteps
	for i = 1, teamListCount do
		local tID = teamList[i]
		teamCapacities[tID] = {}
		teamEfficiencies[tID] = prototype(Efficiencies)
		teamEfficiencies[tID]:init(tID)
		teamMMList[tID] = {}
		teamActiveMM[tID] = 0
		for j = 1, eStepsCount do
			teamCapacities[tID][eSteps[j]] = 0
			teamMMList[tID][eSteps[j]] = {}
		end
		spSetTeamRulesParam(tID, mmLevelParamName, 0.75)
		spSetTeamRulesParam(tID, mmCapacityParamName, 0)
		spSetTeamRulesParam(tID, mmUseParamName, 0)
		spSetTeamRulesParam(tID, mmAvgEffiParamName, teamEfficiencies[tID]:avg())

	end
end

function BuildeSteps()
	local i = 1
	for defid, defs in pairs(convertCapacities) do
		local inTable = false
		for j = 1, #eSteps do
			if eSteps[j] == defs.e then
				inTable = true
			end
		end
		if inTable == false then
			eSteps[i] = defs.e
			i = i + 1
		end
	end
	tableSort(eSteps, function(m1, m2)
		return m1 > m2;
	end)
end

function gadget:GameFrame(n)

	-- process emped in the least likely used frame by the actual per team maker computations
	if n % resourceRefreshRate == resourceRefreshRate - 1 then
		currentFrameStamp = currentFrameStamp + 1
		EmpedVector:process(currentFrameStamp)
	end

	-- process a team in each gameframe so that all teams are process exactly once in every 15 gameframes
	-- in case of more than 15 teams ingame, two or more teams are processed in one gameframe

	if n % resourceRefreshRate == (splitMMPointer - 1) then
		local teamListCount = #teamList
		local ceilTeams = mathCeil(teamListCount / resourceRefreshRate)
		local eStepsCount = #eSteps
		for i = 0, ceilTeams - 1 do
			local tID
			local tpos = (splitMMPointer + (i * resourceRefreshRate))
			if tpos <= teamListCount then
				tID = teamList[tpos]

				local eCur, eStor = spGetTeamResources(tID, 'energy')
				local mmLevel = spGetTeamRulesParam(tID, mmLevelParamName)
				local convertAmount = eCur - eStor * mmLevel
				local _, _, eConverted, mConverted, teamUsages = 0, 0, 0, 0, 0

				for j = 1, eStepsCount do
					local eStep = eSteps[j]
					local teamCapacity = teamCapacities[tID][eStep]
					if teamCapacity > 1 then
						if convertAmount > 1 then
							local convertStep = teamCapacity * resourceFraction
							if convertStep > convertAmount then
								convertStep = convertAmount
							end
							eConverted = convertStep + eConverted
							mConverted = convertStep * eStep + mConverted
							teamUsages = teamUsages + convertStep
							convertAmount = convertAmount - convertStep
						else
							break
						end
					end
				end

				teamEfficiencies[tID]:push({ m = mConverted, e = eConverted })
				local tUsage = resourceUpdatesPerGameSec * teamUsages
				UpdateMetalMakers(tID, tUsage)
				spSetTeamRulesParam(tID, mmUseParamName, tUsage)
				spSetTeamRulesParam(tID, mmAvgEffiParamName, teamEfficiencies[tID]:avg())
			end
		end
		if splitMMPointer == resourceRefreshRate then
			splitMMPointer = 1
		else
			splitMMPointer = splitMMPointer + 1
		end
	end
end

function gadget:UnitCreated(uID, uDefID, uTeam, builderID)
	if convertCapacities[uDefID] then
		teamMMList[uTeam][convertCapacities[uDefID].e][uID] = { capacity = 0, status = 0, built = false, emped = false }
	end
end

function gadget:UnitFinished(uID, uDefID, uTeam)
	local cDefs = convertCapacities[uDefID]
	if not cDefs then
		return
	end
	
	local teamMM = teamMMList[uTeam][cDefs.e]
	if not teamMM[uID] then
		teamMM[uID] = { capacity = 0, status = 0, built = false, emped = false }
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
		built = oldUnitData.built
	}

	oldTeamMM[uID] = nil
end

function gadget:RecvLuaMsg(msg, playerID)
	local newLevel = tonumber(msg:match(alterLevelRegex))
	if newLevel and newLevel >= 0 and newLevel <= 100 then
		local _, _, playerIsSpec, playerTeam = spGetPlayerInfo(playerID, false)
		if playerTeam and not playerIsSpec then -- NB: playerTeam is nil for replay-watching specs
			spSetTeamRulesParam(playerTeam, mmLevelParamName, newLevel / 100)
			return true
		end
	end
end
