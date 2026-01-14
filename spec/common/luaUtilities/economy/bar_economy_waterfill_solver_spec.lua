local Builders = VFS.Include("spec/builders/index.lua")
local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")
local ResourceShared = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_shared.lua")
local BarEconomy = VFS.Include("common/luaUtilities/economy/economy_waterfill_solver.lua")
local SharedConfig = VFS.Include("common/luaUtilities/economy/shared_config.lua")

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

local function buildTeams(builders)
  local teams = {}
  for i = 1, #builders do
    local built = builders[i]:Build()
    teams[built.id] = built
  end
  return teams
end

local function flowFor(flows, teamId, resourceType)
  local perTeam = flows[teamId]
  assert(perTeam, string.format("missing flow summary for team %s", tostring(teamId)))
  local summary = perTeam[resourceType]
  assert(summary, string.format("missing flow summary for team %s resource %s", tostring(teamId), tostring(resourceType)))
  return summary
end

local function modOptions(opts)
  return {
    [SharedEnums.ModOptions.TaxResourceSharingAmount] = opts.taxRate or 0,
    [SharedEnums.ModOptions.PlayerMetalSendThreshold] = opts.metalThreshold or 0,
    [SharedEnums.ModOptions.PlayerEnergySendThreshold] = opts.energyThreshold or 0,
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

describe("Bar economy ProcessEconomy", function()
  before_each(function()
    SharedConfig.resetCache()
  end)

  it("balances overflow without tax #focus", function()
    local teamA = Builders.Team:new()
      :WithMetal(800)
      :WithMetalStorage(1000)
      :WithMetalShareSlider(50)
    local teamB = Builders.Team:new()
      :WithMetal(700)
      :WithMetalStorage(1000)
      :WithMetalShareSlider(50)
    local teamC = Builders.Team:new()
      :WithMetal(200)
      :WithMetalStorage(1000)
      :WithMetalShareSlider(50)

    normalizeAllies({ teamA, teamB, teamC }, teamA.allyTeam)

    local spring = buildSpring({
      taxRate = 0,
      metalThreshold = 0,
      energyThreshold = 0,
    }, { teamA, teamB, teamC })

    local teamsList = buildTeams({ teamA, teamB, teamC })
    local _, flows = BarEconomy.Solve(spring, teamsList)

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

    local aFlow = flowFor(flows, teamA.id, SharedEnums.ResourceType.METAL)
    local bFlow = flowFor(flows, teamB.id, SharedEnums.ResourceType.METAL)
    local cFlow = flowFor(flows, teamC.id, SharedEnums.ResourceType.METAL)
    assert.is_near(233.33, aFlow.taxed, 0.02)
    assert.is_near(133.33, bFlow.taxed, 0.02)
    assert.is_near(0, cFlow.taxed, 1e-6)

    local cumulativeKey = ResourceShared.GetPassiveCumulativeParam(SharedEnums.ResourceType.METAL)
    assert.is_near(a.sent, spring.GetTeamRulesParam(teamA.id, cumulativeKey) or 0, 0.02)
    assert.is_near(b.sent, spring.GetTeamRulesParam(teamB.id, cumulativeKey) or 0, 0.02)
    assert.equal(teamsList[teamC.id].metal.sent, spring.GetTeamRulesParam(teamC.id, cumulativeKey) or 0)
  end)

  it("shares taxed overflow and burns the remainder", function()
    local teamA = Builders.Team:new()
      :WithMetal(800)
      :WithMetalStorage(1000)
      :WithMetalShareSlider(50)
    local teamB = Builders.Team:new()
      :WithMetal(700)
      :WithMetalStorage(1000)
      :WithMetalShareSlider(50)

    normalizeAllies({ teamA, teamB }, teamA.allyTeam)

    local spring = buildSpring({
      taxRate = 0.5,
      metalThreshold = 0,
      energyThreshold = 0,
    }, { teamA, teamB })

    local teamsList = buildTeams({ teamA, teamB })
    local _, flows = BarEconomy.Solve(spring, teamsList)

    local a = teamsList[teamA.id].metal
    local b = teamsList[teamB.id].metal

    assert.is_near(733.33, a.current, 0.02)
    assert.is_near(733.33, b.current, 0.02)

    assert.is_near(66.67, a.sent, 0.02)
    assert.is_near(0, a.received, 1e-6)
    assert.is_near(0, b.sent, 1e-6)
    assert.is_near(33.33, b.received, 0.02)
    assert.is_near(a.sent - b.received, 33.33, 0.05)

    local aFlow = flowFor(flows, teamA.id, SharedEnums.ResourceType.METAL)
    local bFlow = flowFor(flows, teamB.id, SharedEnums.ResourceType.METAL)
    assert.is_near(33.33, aFlow.taxed, 0.05)
    assert.is_near(0, aFlow.untaxed, 1e-6)
    assert.is_near(0, bFlow.taxed, 1e-6)
    assert.is_near(33.33, bFlow.received, 0.05)

    local cumulativeKey = ResourceShared.GetPassiveCumulativeParam(SharedEnums.ResourceType.METAL)
    assert.is_near(a.sent, spring.GetTeamRulesParam(teamA.id, cumulativeKey) or 0, 0.02)
    assert.equal(0, spring.GetTeamRulesParam(teamB.id, cumulativeKey) or 0)
  end)

  it("stops at the untaxed allowance when tax rate is 100 percent", function()
    local teamA = Builders.Team:new()
      :WithMetal(800)
      :WithMetalStorage(1000)
      :WithMetalShareSlider(50)
    local teamB = Builders.Team:new()
      :WithMetal(300)
      :WithMetalStorage(1000)
      :WithMetalShareSlider(50)

    normalizeAllies({ teamA, teamB }, teamA.allyTeam)

    local spring = buildSpring({
      taxRate = 1,
      metalThreshold = 100,
      energyThreshold = 0,
    }, { teamA, teamB })

    local teamsList = buildTeams({ teamA, teamB })
    local _, flows = BarEconomy.Solve(spring, teamsList)

    local a = teamsList[teamA.id].metal
    local b = teamsList[teamB.id].metal

    assert.is_near(700, a.current, 0.01)
    assert.is_near(400, b.current, 0.01)

    assert.is_near(100, a.sent, 0.01)
    assert.is_near(0, a.received, 1e-6)
    assert.is_near(0, b.sent, 1e-6)
    assert.is_near(100, b.received, 0.01)

    local aFlow = flowFor(flows, teamA.id, SharedEnums.ResourceType.METAL)
    local bFlow = flowFor(flows, teamB.id, SharedEnums.ResourceType.METAL)
    assert.is_near(0, aFlow.taxed, 1e-6)
    assert.is_near(100, aFlow.untaxed, 0.01)
    assert.is_near(100, bFlow.received, 0.01)

    local cumulativeKey = ResourceShared.GetPassiveCumulativeParam(SharedEnums.ResourceType.METAL)
    assert.is_near(100, spring.GetTeamRulesParam(teamA.id, cumulativeKey) or 0, 0.01)
    assert.equal(0, spring.GetTeamRulesParam(teamB.id, cumulativeKey) or 0)
  end)
end)

