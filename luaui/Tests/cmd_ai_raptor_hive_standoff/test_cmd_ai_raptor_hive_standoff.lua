local AI_ATTACKER_DEF = "armham"
local HUMAN_ATTACKER_DEF = "armham"
local HIVE_DEF = "raptor_hive"
local NON_HIVE_TARGET_DEF = "armmex"

local STANDOFF_MIN_DISTANCE = 72

local function mapCenter()
	local x = Game.mapSizeX * 0.5
	local z = Game.mapSizeZ * 0.5
	local y = Spring.GetGroundHeight(x, z)
	return x, y, z
end

local function getTestTeams()
	local result = {
		aiTeamID = nil,
		humanTeamID = nil,
		raptorTeamID = nil,
	}

	local gaiaTeamID = Spring.GetGaiaTeamID()
	for _, teamID in ipairs(Spring.GetTeamList()) do
		if teamID ~= gaiaTeamID then
			local luaAI = Spring.GetTeamLuaAI(teamID) or ""
			local _, _, _, isAI = Spring.GetTeamInfo(teamID, false)

			if string.find(luaAI, "Raptor") then
				result.raptorTeamID = teamID
			elseif isAI or luaAI ~= "" then
				result.aiTeamID = result.aiTeamID or teamID
			else
				result.humanTeamID = result.humanTeamID or teamID
			end
		end
	end

	return result
end

local function createUnit(unitDefName, x, z, teamID, facing)
	local y = SyncedProxy.Spring.GetGroundHeight(x, z)
	local unitID = SyncedProxy.Spring.CreateUnit(unitDefName, x, y, z, facing, teamID)
	assert(unitID, "failed to create unit: " .. tostring(unitDefName))
	return unitID
end

local function issueAttackAndReadQueue(unitID, targetID)
	SyncedProxy.Spring.GiveOrderToUnit(unitID, CMD.ATTACK, { targetID }, {})
	return SyncedProxy.Spring.GetUnitCommands(unitID, 20)
end

local function assertDirectAttackQueue(queue, targetID, context)
	assert(queue and #queue >= 1, context .. ": expected at least one command")
	assert(queue[1].id == CMD.ATTACK, context .. ": expected first command ATTACK")
	assert(queue[1].params and queue[1].params[1] == targetID, context .. ": expected ATTACK target to match")
	assert(#queue == 1, context .. ": expected exactly one queued command")
end

local function assertStandoffQueue(queue, hiveID, hiveX, hiveZ)
	assert(queue and #queue >= 2, "AI vs hive: expected MOVE + ATTACK queue")
	assert(queue[1].id == CMD.MOVE, "AI vs hive: expected first queued command MOVE")
	assert(queue[2].id == CMD.ATTACK, "AI vs hive: expected second queued command ATTACK")
	assert(queue[2].params and queue[2].params[1] == hiveID, "AI vs hive: expected ATTACK target to be hive")

	local mx = queue[1].params and queue[1].params[1]
	local mz = queue[1].params and queue[1].params[3]
	assert(mx and mz, "AI vs hive: MOVE command missing target position")

	local dx = mx - hiveX
	local dz = mz - hiveZ
	local dist = math.sqrt(dx * dx + dz * dz)
	assert(dist >= STANDOFF_MIN_DISTANCE, "AI vs hive: MOVE position is too close to hive center")
end

local function runAIHiveRewriteCase(teams)
	Test.clearMap()

	local x, _, z = mapCenter()
	local hiveID = createUnit(HIVE_DEF, x, z, teams.raptorTeamID, 0)
	local aiUnitID = createUnit(AI_ATTACKER_DEF, x - 600, z, teams.aiTeamID, 0)

	local queue = issueAttackAndReadQueue(aiUnitID, hiveID)
	assertStandoffQueue(queue, hiveID, x, z)
end

local function runHumanHiveNonRegressionCase(teams)
	Test.clearMap()

	local x, _, z = mapCenter()
	local hiveID = createUnit(HIVE_DEF, x, z, teams.raptorTeamID, 0)
	local humanUnitID = createUnit(HUMAN_ATTACKER_DEF, x - 600, z, teams.humanTeamID, 0)

	local queue = issueAttackAndReadQueue(humanUnitID, hiveID)
	assertDirectAttackQueue(queue, hiveID, "human vs hive")
end

local function runAINonHiveNonRegressionCase(teams)
	Test.clearMap()

	local x, _, z = mapCenter()
	local targetID = createUnit(NON_HIVE_TARGET_DEF, x, z, teams.raptorTeamID, 0)
	local aiUnitID = createUnit(AI_ATTACKER_DEF, x - 600, z, teams.aiTeamID, 0)

	local queue = issueAttackAndReadQueue(aiUnitID, targetID)
	assertDirectAttackQueue(queue, targetID, "AI vs non-hive")
end

function skip()
	if Spring.GetGameFrame() <= 0 then
		return true
	end

	local teams = getTestTeams()
	return teams.aiTeamID == nil or teams.humanTeamID == nil or teams.raptorTeamID == nil
end

function setup()
	assert(UnitDefNames[HIVE_DEF], "raptor_hive UnitDef is required for this test")
	Test.clearMap()
end

function cleanup()
	Test.clearMap()
end

function test()
	local teams = getTestTeams()
	assert(teams.aiTeamID ~= nil, "test requires at least one non-raptor AI team")
	assert(teams.humanTeamID ~= nil, "test requires one human team")
	assert(teams.raptorTeamID ~= nil, "test requires one Raptors team")

	runAIHiveRewriteCase(teams)
	runHumanHiveNonRegressionCase(teams)
	runAINonHiveNonRegressionCase(teams)
end
