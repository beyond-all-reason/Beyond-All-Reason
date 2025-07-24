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
	for j = 1, #eSteps do
		totalCapacity = totalCapacity + teamCapacities[teamID][eSteps[j]]
	end
	spSetTeamRulesParam(teamID, mmCapacityParamName, totalCapacity)
end

local function updateUnitConversion(unitID, amount, e)
	spSetUnitResourcing(unitID, "umm", amount * e)
	spSetUnitResourcing(unitID, "uue", amount)
end

local function UpdateMetalMakers(teamID, energyUse)
	for j = 1, #eSteps do
		for unitID, defs in pairs(teamMMList[teamID][eSteps[j]]) do
			if defs.built then
				if not defs.emped and energyUse > 0 then
					local amount = (energyUse < defs.capacity and energyUse or defs.capacity)    -- alternative math.min method
					if amount < 0 then
						amount = 0
					end
					energyUse = (energyUse - defs.capacity)
					updateUnitConversion(unitID, amount, eSteps[j])

					if defs.status == 0 then
						Spring.CallCOBScript(unitID, "MMStatus", 0, 1)
						defs.status = 1
						teamActiveMM[teamID] = (teamActiveMM[teamID] + 1)
					end
				else
					if teamActiveMM[teamID] == 0 then
						break
					end
					if defs.status == 1 then
						updateUnitConversion(unitID, 0, 0)
						Spring.CallCOBScript(unitID, "MMStatus", 0, 0)
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
	teamList = Spring.GetTeamList()
	for i = 1, #teamList do
		local tID = teamList[i]
		teamCapacities[tID] = {}
		teamEfficiencies[tID] = prototype(Efficiencies)
		teamEfficiencies[tID]:init(tID)
		teamMMList[tID] = {}
		teamActiveMM[tID] = 0
		for j = 1, #eSteps do
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
		for _, e in ipairs(eSteps) do
			if (e == defs.e) then
				inTable = true
			end
		end
		if (inTable == false) then
			eSteps[i] = defs.e
			i = (i + 1)
		end
	end
	table.sort(eSteps, function(m1, m2)
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
		for i = 0, math.ceil(#teamList / resourceRefreshRate) - 1 do
			local tID
			local tpos = (splitMMPointer + (i * resourceRefreshRate))
			if tpos < #teamList then
				tID = teamList[tpos]

				local eCur, eStor = spGetTeamResources(tID, 'energy')
				local convertAmount = eCur - eStor * spGetTeamRulesParam(tID, mmLevelParamName)
				local _, _, eConverted, mConverted, teamUsages = 0, 0, 0, 0, 0

				for j = 1, #eSteps do
					if teamCapacities[tID][eSteps[j]] > 1 then
						if convertAmount > 1 then
							local convertStep = teamCapacities[tID][eSteps[j]] * resourceFraction
							if convertStep > convertAmount then
								convertStep = convertAmount
							end
							eConverted = convertStep + eConverted
							mConverted = convertStep * eSteps[j] + mConverted
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
	if convertCapacities[uDefID] then
		local cDefs = convertCapacities[uDefID]
		if not teamMMList[uTeam][cDefs.e][uID] then
			teamMMList[uTeam][cDefs.e][uID] = { capacity = 0, status = 0, built = false, emped = false }
		end
		teamMMList[uTeam][cDefs.e][uID].capacity = cDefs.c
		teamMMList[uTeam][cDefs.e][uID].built = true
		if not teamMMList[uTeam][cDefs.e][uID].emped then
			teamMMList[uTeam][cDefs.e][uID].status = 1
			teamActiveMM[uTeam] = teamActiveMM[uTeam] + 1
			Spring.CallCOBScript(uID, "MMStatus", 0, 1)
			AdjustTeamCapacity(uTeam, cDefs.c, cDefs.e)
		end
	end
end

function gadget:UnitDamaged(uID, uDefID, uTeam, damage, paralyzer)
	if paralyzer and convertCapacities[uDefID] then
		local _, maxHealth, paralyzeDamage, _, _ = spGetUnitHealth(uID)
		local relativeParDmg = paralyzeDamage - maxHealth
		if relativeParDmg > 0 then
			EmpedVector:push(uID, currentFrameStamp + math.ceil(relativeParDmg / (maxHealth / paralysisRelRate)))
		end
	end
end

function gadget:UnitDestroyed(uID, uDefID, uTeam)
	if convertCapacities[uDefID] then
		local cDefs = convertCapacities[uDefID]
		if teamMMList[uTeam][cDefs.e][uID] then
			if teamMMList[uTeam][cDefs.e][uID].built then
				if teamMMList[uTeam][cDefs.e][uID].status == 1 then
					teamActiveMM[uTeam] = teamActiveMM[uTeam] - 1
				end

				if not teamMMList[uTeam][cDefs.e][uID].emped then
					AdjustTeamCapacity(uTeam, -cDefs.c, cDefs.e)
				end
			end
			teamMMList[uTeam][cDefs.e][uID] = nil
		end
	end
end

function gadget:UnitGiven(uID, uDefID, newTeam, oldTeam)
	if convertCapacities[uDefID] then
		local cDefs = convertCapacities[uDefID]
		if teamMMList[oldTeam][cDefs.e][uID] then
			if teamMMList[oldTeam][cDefs.e][uID].built then

				if not teamMMList[oldTeam][cDefs.e][uID].emped then
					AdjustTeamCapacity(oldTeam, -cDefs.c, cDefs.e)
					AdjustTeamCapacity(newTeam, cDefs.c, cDefs.e)
				end
				if teamMMList[oldTeam][cDefs.e][uID].status == 1 then
					teamActiveMM[oldTeam] = teamActiveMM[oldTeam] - 1
					teamActiveMM[newTeam] = teamActiveMM[newTeam] + 1
				end
			end

			teamMMList[newTeam][cDefs.e][uID] = {}
			teamMMList[newTeam][cDefs.e][uID].capacity = teamMMList[oldTeam][cDefs.e][uID].capacity
			teamMMList[newTeam][cDefs.e][uID].status = teamMMList[oldTeam][cDefs.e][uID].status
			teamMMList[newTeam][cDefs.e][uID].emped = teamMMList[oldTeam][cDefs.e][uID].emped
			teamMMList[newTeam][cDefs.e][uID].built = teamMMList[oldTeam][cDefs.e][uID].built

			teamMMList[oldTeam][cDefs.e][uID] = nil
		end
	end
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
