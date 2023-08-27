if not gadgetHandler:IsSyncedCode() then
	return false
end
local gadgetEnabled = false
if Spring.GetModOptions().mexsharing then
	gadgetEnabled = true
end

function gadget:GetInfo()
	return {
		name = 'MexSharing',
		desc = 'Divides metal income from metal extractors evenly with the team',
		author = 'lov',
		version = '1.0',
		date = 'August 2023',
		license = 'GNU GPL, v2 or later',
		layer = 0,
		enabled = gadgetEnabled
	}
end

local mexDefs = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.extractsMetal > 0 then
		mexDefs[unitDefID] = unitDef
	end
end

local teamList = {}
local allyTeamMap = {}
local allyCounts = {}
local allyTeamIncome = {}
local mexInfo = {}
local teamMexIncomes = {}


local spGetUnitHealth = Spring.GetUnitHealth
local spGetTeamList = Spring.GetTeamList
local spGetUnitMetalExtraction = Spring.GetUnitMetalExtraction
local spShareTeamResource = Spring.ShareTeamResource
local spGetTeamInfo = Spring.GetTeamInfo
local abs = math.abs
local min = math.min

local function dumptable(o)
	if type(o) == 'table' then
		local s = '{ '
		for k, v in pairs(o) do
			if type(k) ~= 'number' then k = '"' .. k .. '"' end
			s = s .. '[' .. k .. '] = ' .. dumptable(v) .. ','
		end
		return s .. '} '
	else
		return tostring(o)
	end
end

local function updateAllyMap()
	teamList = spGetTeamList()
	for index, _ in pairs(allyCounts) do
		allyCounts[index] = 0
	end

	local i
	for i = 1, #teamList do
		local tID = teamList[i]
		local teamID, _, _, _, _, allyTeamID = spGetTeamInfo(tID)
		-- Spring.Echo(spGetTeamInfo(tID))
		allyTeamMap[tID] = allyTeamID
		if not allyCounts[allyTeamID] then allyCounts[allyTeamID] = 0 end
		allyCounts[allyTeamID] = allyCounts[allyTeamID] + 1
		if not allyTeamIncome[allyTeamID] then
			allyTeamIncome[allyTeamID] = 0
		end
	end
	-- Spring.Echo("teams")
	-- Spring.Echo(dumptable(teamList))
	-- Spring.Echo("allycount")
	-- Spring.Echo(dumptable(allyCounts))
	-- Spring.Echo("allyTeamMap")
	-- Spring.Echo(dumptable(allyTeamMap))
	-- Spring.Echo("allyTeamIncome")
	-- Spring.Echo(dumptable(allyTeamIncome))
end

----------------------------------------------------------------
-- Callins
----------------------------------------------------------------
function gadget:Initialize()
	local i
	updateAllyMap()
	for i = 1, #teamList do
		local tID = teamList[i]
		teamMexIncomes[tID] = 0
	end
	local units = Spring.GetAllUnits()
	for i = 1, #units do
		local uID = units[i]
		local defid = Spring.GetUnitDefID(uID)
		local uTeam = Spring.GetUnitTeam(uID)
		if mexDefs[defid] then
			local teamID, leader, isDead, isAiTeam, side, allyTeamID = spGetTeamInfo(uTeam)
			local mexi = spGetUnitMetalExtraction(uID)
			-- Spring.Echo("EXTRACTION", mexi, allyTeamID)
			mexInfo[uID] = mexi
			teamMexIncomes[uTeam] = teamMexIncomes[uTeam] + mexi
			allyTeamIncome[allyTeamID] = allyTeamIncome[allyTeamID] + mexi
		end
	end
end

-- local empedMexes = {}
-- local empCount = 0
-- local function checkEmps()
-- 	if empCount == 0 then return end
-- 	for uID, uTeam in pairs(empedMexes) do
-- 		local _, maxHealth, paralyzeDamage, _, _ = spGetUnitHealth(uID)
-- 		local relativeParDmg = paralyzeDamage - maxHealth
-- 		if relativeParDmg < 0 then
-- 			local mexi = spGetUnitMetalExtraction(uID)
-- 			local allyTeamID = allyTeamMap[uTeam]
-- 			mexInfo[uID] = mexi
-- 			teamMexIncomes[uTeam] = teamMexIncomes[uTeam] + mexi
-- 			allyTeamIncome[allyTeamID] = allyTeamIncome[allyTeamID] + mexi
-- 			empedMexes[uID] = nil
-- 			empCount = empCount - 1
-- 		end
-- 	end
-- end

-- local function unitIsEmped(uID, teamID)
-- 	local allyTeamID = allyTeamMap[teamID]
-- 	empCount = empCount + 1
-- 	empedMexes[uID] = teamID
-- 	teamMexIncomes[teamID] = teamMexIncomes[teamID] - mexInfo[uID]
-- 	allyTeamIncome[allyTeamID] = allyTeamIncome[allyTeamID] - mexInfo[uID]
-- 	mexInfo[uID] = nil
-- end

function gadget:GameFrame(n)
	if n % 15 ~= 3 then return end
	local i
	local j
	local frameIncome = {}
	-- checkEmps()
	for i = 1, #teamList do
		local tID = teamList[i]
		frameIncome[tID] = teamMexIncomes[tID]
	end
	-- Spring.Echo("mexinfo", dumptable(mexInfo))
	-- Spring.Echo(dumptable(teamMexIncomes))
	-- Spring.Echo(dumptable(allyTeamIncome))
	for i = 1, #teamList do
		local tID = teamList[i]
		local atID = allyTeamMap[tID]

		local fairIncome = allyTeamIncome[atID] / allyCounts[atID]
		local incomeDiff = fairIncome - frameIncome[tID]
		local distributeMetal = incomeDiff < 0
		incomeDiff = abs(incomeDiff)

		-- Spring.Echo("incomediff", tID, allyTeamIncome[atID], fairIncome, incomeDiff)
		local j = i
		while incomeDiff ~= 0 and j < #teamList do
			j = j + 1
			local otherID = teamList[j]
			local oatID = allyTeamMap[otherID]
			if oatID == atID then
				local otherTeamIncome = frameIncome[otherID]
				if otherTeamIncome > fairIncome and not distributeMetal then
					-- Spring.Echo("take", otherID, fairIncome, otherTeamIncome)
					-- take: we are looking for metal and the ally has more than their share
					local takeAmount = min(incomeDiff, otherTeamIncome - fairIncome)
					spShareTeamResource(otherID, tID, "metal", takeAmount)
					frameIncome[otherID] = otherTeamIncome - takeAmount
					incomeDiff = incomeDiff - takeAmount
				elseif otherTeamIncome < fairIncome and distributeMetal then
					-- Spring.Echo("give", otherID, fairIncome, otherTeamIncome)
					-- give: we are giving metal and the ally has less than their share
					local giveAmount = min(incomeDiff, fairIncome - otherTeamIncome)
					spShareTeamResource(tID, otherID, "metal", giveAmount)
					frameIncome[otherID] = otherTeamIncome + giveAmount
					incomeDiff = incomeDiff - giveAmount
				end
			end
		end
	end
end

function gadget:UnitFinished(uID, uDefID, uTeam)
	if mexDefs[uDefID] and not mexInfo[uID] then
		local allyTeamID = allyTeamMap[uTeam]
		local mexi = spGetUnitMetalExtraction(uID)
		mexInfo[uID] = mexi
		teamMexIncomes[uTeam] = teamMexIncomes[uTeam] + mexi
		allyTeamIncome[allyTeamID] = allyTeamIncome[allyTeamID] + mexi
	end
end

function gadget:UnitStunned(uID, uDefID, uTeam, stunned)
	if mexDefs[uDefID] then
		local allyTeamID = allyTeamMap[uTeam]
		if stunned then
			teamMexIncomes[uTeam] = teamMexIncomes[uTeam] - mexInfo[uID]
			allyTeamIncome[allyTeamID] = allyTeamIncome[allyTeamID] - mexInfo[uID]
			mexInfo[uID] = nil
		else
			local mexi = spGetUnitMetalExtraction(uID)
			mexInfo[uID] = mexi
			teamMexIncomes[uTeam] = teamMexIncomes[uTeam] + mexi
			allyTeamIncome[allyTeamID] = allyTeamIncome[allyTeamID] + mexi
		end
	end
end

function gadget:UnitDamaged(uID, uDefID, uTeam, damage, paralyzer)
	-- TODO: emp stuff
	-- if paralyzer and mexDefs[uDefID] then
	-- 	local _, maxHealth, paralyzeDamage, _, _ = spGetUnitHealth(uID)
	-- 	local relativeParDmg = paralyzeDamage - maxHealth
	-- 	if relativeParDmg > 0 then
	-- 		unitIsEmped(uID, uTeam)
	-- 	end
	-- end
end

function gadget:UnitDestroyed(uID, uDefID, uTeam)
	if mexDefs[uDefID] then
		local allyTeamID = allyTeamMap[uTeam]
		teamMexIncomes[uTeam] = teamMexIncomes[uTeam] - mexInfo[uID]
		allyTeamIncome[allyTeamID] = allyTeamIncome[allyTeamID] - mexInfo[uID]
		mexInfo[uID] = nil
	end
end

function gadget:UnitGiven(uID, uDefID, newTeam, oldTeam)
	if mexDefs[uDefID] then
		teamMexIncomes[newTeam] = teamMexIncomes[newTeam] + mexInfo[uID]
		teamMexIncomes[oldTeam] = teamMexIncomes[oldTeam] - mexInfo[uID]
	end
end

function gadget:PlayerChanged(uID)
	updateAllyMap()
end
