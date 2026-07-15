local Builders = VFS.Include("spec/builders/index.lua")
local ModeEnums = VFS.Include("modes/sharing_mode_enums.lua")
local TransferEnums = VFS.Include("modules/sharing/enums.lua")
local BarEconomy = VFS.Include("modules/economy/waterfill_solver.lua")
local SharedConfig = VFS.Include("modules/sharing/config.lua")

local function normalizeAllies(teams, allyTeamId)
	for i = 1, #teams do
		teams[i].allyTeam = allyTeamId
	end
end

local function allyAll(teams, springBuilder)
	for i = 1, #teams do
		for j = i, #teams do
			springBuilder:WithAlliance(teams[i].id, teams[j].id, true)
		end
	end
end

---@param builders TeamBuilder[]
---@return table<integer, TeamDataMock>
local function buildTeams(builders)
	local teams = {} ---@type table<integer, TeamDataMock>
	for i = 1, #builders do
		local built = builders[i]:Build()
		teams[built.id] = built
	end
	return teams
end

---@param flows EconomyFlowSummary
---@param teamId integer
---@param resourceType ResourceName
---@return EconomyFlowLedger
local function flowFor(flows, teamId, resourceType)
	local perTeam = flows[teamId] ---@type table<ResourceName, EconomyFlowLedger>?
	assert(perTeam, string.format("missing flow summary for team %s", tostring(teamId)))
	local summary = perTeam[resourceType] ---@type EconomyFlowLedger?
	assert(summary, string.format("missing flow summary for team %s resource %s", tostring(teamId), tostring(resourceType)))
	return summary
end

local function modOptions(opts)
	return {
		[ModeEnums.ModOptions.TaxResourceSharingAmount] = opts.taxRate or 0,
	}
end

local function buildSpring(opts, teams)
	local builder = Builders.Spring.new()
	for key, value in pairs(modOptions(opts)) do
		builder:WithModOption(key, value)
	end
	for i = 1, #teams do
		builder:WithTeam(teams[i])
	end
	allyAll(teams, builder)
	return builder:Build()
end

describe("Bar economy waterfill", function()
	before_each(function()
		SharedConfig.resetCache()
	end)

	it("balances overflow without tax", function()
		local teamA = Builders.Team:new():WithMetal(800):WithMetalStorage(1000):WithMetalShareSlider(50)
		local teamB = Builders.Team:new():WithMetal(700):WithMetalStorage(1000):WithMetalShareSlider(50)
		local teamC = Builders.Team:new():WithMetal(200):WithMetalStorage(1000):WithMetalShareSlider(50)

		normalizeAllies({ teamA, teamB, teamC }, teamA.allyTeam)

		local spring = buildSpring({
			taxRate = 0,
		}, { teamA, teamB, teamC })

		local teamsList = buildTeams({ teamA, teamB, teamC })
		local _, flows = BarEconomy.Solve(spring, teamsList, SharedConfig.getTeamTaxRate)

		local a = teamsList[teamA.id].metal
		local b = teamsList[teamB.id].metal
		local c = teamsList[teamC.id].metal

		assert.is_near(566.67, a.current, 0.02)
		assert.is_near(566.67, b.current, 0.02)
		assert.is_near(566.67, c.current, 0.02)

		assert.is_near(233.33, a.sent, 0.02)
		assert.is_near(133.33, b.sent, 0.02)
		assert.is_near(0, c.sent, 1e-6)

		assert.is_near(0, a.received, 1e-6)
		assert.is_near(0, b.received, 1e-6)
		assert.is_near(366.67, c.received, 0.02)

		local aFlow = flowFor(flows, teamA.id, TransferEnums.ResourceType.METAL)
		local bFlow = flowFor(flows, teamB.id, TransferEnums.ResourceType.METAL)
		local cFlow = flowFor(flows, teamC.id, TransferEnums.ResourceType.METAL)
		assert.is_near(233.33, aFlow.taxed, 0.02)
		assert.is_near(133.33, bFlow.taxed, 0.02)
		assert.is_near(0, cFlow.taxed, 1e-6)
	end)

	it("shares taxed overflow and burns the remainder", function()
		local teamA = Builders.Team:new():WithMetal(800):WithMetalStorage(1000):WithMetalShareSlider(50)
		local teamB = Builders.Team:new():WithMetal(700):WithMetalStorage(1000):WithMetalShareSlider(50)

		normalizeAllies({ teamA, teamB }, teamA.allyTeam)

		local spring = buildSpring({
			taxRate = 0.5,
		}, { teamA, teamB })

		local teamsList = buildTeams({ teamA, teamB })
		local _, flows = BarEconomy.Solve(spring, teamsList, SharedConfig.getTeamTaxRate)

		local a = teamsList[teamA.id].metal
		local b = teamsList[teamB.id].metal

		assert.is_near(733.33, a.current, 0.02)
		assert.is_near(733.33, b.current, 0.02)

		assert.is_near(66.67, a.sent, 0.02)
		assert.is_near(0, a.received, 1e-6)
		assert.is_near(0, b.sent, 1e-6)
		assert.is_near(33.33, b.received, 0.02)
		assert.is_near(a.sent - b.received, 33.33, 0.05)

		local aFlow = flowFor(flows, teamA.id, TransferEnums.ResourceType.METAL)
		local bFlow = flowFor(flows, teamB.id, TransferEnums.ResourceType.METAL)
		assert.is_near(33.33, aFlow.taxed, 0.05)
		assert.is_near(0, bFlow.taxed, 1e-6)
		assert.is_near(33.33, bFlow.received, 0.05)
	end)

	it("transfers nothing when tax rate is 100 percent", function()
		local teamA = Builders.Team:new():WithMetal(800):WithMetalStorage(1000):WithMetalShareSlider(50)
		local teamB = Builders.Team:new():WithMetal(300):WithMetalStorage(1000):WithMetalShareSlider(50)

		normalizeAllies({ teamA, teamB }, teamA.allyTeam)

		local spring = buildSpring({
			taxRate = 1,
		}, { teamA, teamB })

		local teamsList = buildTeams({ teamA, teamB })
		local _, flows = BarEconomy.Solve(spring, teamsList, SharedConfig.getTeamTaxRate)

		local a = teamsList[teamA.id].metal
		local b = teamsList[teamB.id].metal

		-- 100% tax makes every send infinitely expensive, so nothing moves
		assert.is_near(800, a.current, 0.01)
		assert.is_near(300, b.current, 0.01)

		assert.is_near(0, a.sent, 1e-6)
		assert.is_near(0, a.received, 1e-6)
		assert.is_near(0, b.sent, 1e-6)
		assert.is_near(0, b.received, 1e-6)

		local aFlow = flowFor(flows, teamA.id, TransferEnums.ResourceType.METAL)
		local bFlow = flowFor(flows, teamB.id, TransferEnums.ResourceType.METAL)
		assert.is_near(0, aFlow.taxed, 1e-6)
		assert.is_near(0, bFlow.received, 1e-6)
	end)

	local function metalResult(results, teamId)
		for _, result in ipairs(results) do
			if result.teamId == teamId and result.resourceType == TransferEnums.ResourceType.METAL then
				return result
			end
		end
		error("missing metal result for team " .. tostring(teamId))
	end

	it("emits deltas that conserve flows across the group", function()
		local teamA = Builders.Team:new():WithMetal(800):WithMetalStorage(1000):WithMetalShareSlider(50)
		local teamB = Builders.Team:new():WithMetal(700):WithMetalStorage(1000):WithMetalShareSlider(50)
		local teamC = Builders.Team:new():WithMetal(200):WithMetalStorage(1000):WithMetalShareSlider(50)

		normalizeAllies({ teamA, teamB, teamC }, teamA.allyTeam)

		local spring = buildSpring({ taxRate = 0 }, { teamA, teamB, teamC })
		local teamsList = buildTeams({ teamA, teamB, teamC })
		local results = BarEconomy.SolveToResults(spring, teamsList)

		local a = metalResult(results, teamA.id)
		local b = metalResult(results, teamB.id)
		local c = metalResult(results, teamC.id)

		assert.is_near(-233.33, a.delta, 0.02)
		assert.is_near(-133.33, b.delta, 0.02)
		assert.is_near(366.67, c.delta, 0.02)
		assert.is_near(0, a.delta + b.delta + c.delta, 0.05)
		assert.is_near(0, a.excess + b.excess + c.excess, 1e-6)
	end)

	it("retains accumulated excess for a neutral team with storage headroom", function()
		local teamA = Builders.Team:new():WithMetal(500):WithMetalStorage(1000):WithMetalShareSlider(50):WithMetalExcess(300)

		local spring = buildSpring({ taxRate = 0 }, { teamA })
		local teamsList = buildTeams({ teamA })
		local results = BarEconomy.SolveToResults(spring, teamsList)

		local a = metalResult(results, teamA.id)
		assert.is_near(300, a.delta, 0.01)
		assert.is_near(0, a.excess, 1e-6)
		assert.is_near(0, a.sent, 1e-6)
		assert.is_near(800, teamsList[teamA.id].metal.current, 0.01)
	end)

	it("wastes excess beyond storage headroom without phantom sends", function()
		local teamA = Builders.Team:new():WithMetal(900):WithMetalStorage(1000):WithMetalShareSlider(50):WithMetalExcess(300)

		local spring = buildSpring({ taxRate = 0 }, { teamA })
		local teamsList = buildTeams({ teamA })
		local results = BarEconomy.SolveToResults(spring, teamsList)

		local a = metalResult(results, teamA.id)
		assert.is_near(100, a.delta, 0.01)
		assert.is_near(200, a.excess, 0.01)
		assert.is_near(0, a.sent, 1e-6)
		-- conservation: injected excess = retained delta + wasted
		assert.is_near(300, a.delta + a.excess, 0.01)
		assert.is_near(1000, teamsList[teamA.id].metal.current, 0.01)
	end)
end)
