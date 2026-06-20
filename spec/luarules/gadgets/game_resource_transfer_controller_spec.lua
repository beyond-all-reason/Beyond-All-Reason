local Builders = VFS.Include("spec/builders/index.lua")
local ModeEnums = VFS.Include("modes/sharing_mode_enums.lua")
local ResourceTypes = VFS.Include("gamedata/resource_types.lua")
local SharedConfig = VFS.Include("common/luaUtilities/economy/shared_config.lua")
local WaterfillSolver = VFS.Include("common/luaUtilities/economy/economy_waterfill_solver.lua")

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

local function buildTeamsTable(builders)
  local teams = {}
  for i = 1, #builders do
    local built = builders[i]:Build()
    teams[built.id] = built
  end
  return teams
end

local function buildSpring(opts, teams)
  local builder = Builders.Spring.new()
  builder:WithModOption(ModeEnums.ModOptions.TaxResourceSharingAmount, opts.taxRate or 0)
  for i = 1, #teams do
    builder:WithTeam(teams[i])
  end
  allyAll(teams, builder)
  return builder:Build()
end

describe("WaterfillSolver.SolveToResults", function()
  before_each(function()
    SharedConfig.resetCache()
  end)

  it("returns EconomyTeamResult[] with correct structure", function()
    local teamA = Builders.Team:new()
      :WithMetal(800)
      :WithMetalStorage(1000)
      :WithMetalShareSlider(50)
    local teamB = Builders.Team:new()
      :WithMetal(200)
      :WithMetalStorage(1000)
      :WithMetalShareSlider(50)

    normalizeAllies({ teamA, teamB }, teamA.allyTeam)

    local spring = buildSpring({ taxRate = 0 }, { teamA, teamB })
    local teamsList = buildTeamsTable({ teamA, teamB })
    
    local results = WaterfillSolver.SolveToResults(spring, teamsList)
    
    assert.is_table(results)
    assert.is_true(#results >= 2)
    
    local foundMetal = false
    for _, result in ipairs(results) do
      assert.is_number(result.teamId)
      assert.is_not_nil(result.resourceType)
      assert.is_number(result.delta)
      assert.is_number(result.excess)
      assert.is_number(result.sent)
      assert.is_number(result.received)
      if result.resourceType == ResourceTypes.METAL then
        foundMetal = true
      end
    end
    assert.is_true(foundMetal)
  end)

  it("balances metal between teams without tax", function()
    local teamA = Builders.Team:new()
      :WithMetal(800)
      :WithMetalStorage(1000)
      :WithMetalShareSlider(50)
    local teamB = Builders.Team:new()
      :WithMetal(200)
      :WithMetalStorage(1000)
      :WithMetalShareSlider(50)

    normalizeAllies({ teamA, teamB }, teamA.allyTeam)

    local spring = buildSpring({ taxRate = 0 }, { teamA, teamB })
    local teamsList = buildTeamsTable({ teamA, teamB })
    
    local results = WaterfillSolver.SolveToResults(spring, teamsList)
    
    local teamAMetal, teamBMetal
    for _, result in ipairs(results) do
      if result.resourceType == ResourceTypes.METAL then
        if result.teamId == teamA.id then
          teamAMetal = result
        elseif result.teamId == teamB.id then
          teamBMetal = result
        end
      end
    end
    
    assert.is_near(-300, teamAMetal.delta, 0.1)
    assert.is_near(300, teamBMetal.delta, 0.1)
    assert.is_near(300, teamAMetal.sent, 0.1)
    assert.is_near(300, teamBMetal.received, 0.1)
    assert.is_near(0, teamAMetal.delta + teamBMetal.delta, 0.1)
  end)

  it("applies tax correctly in results", function()
    local teamA = Builders.Team:new()
      :WithMetal(800)
      :WithMetalStorage(1000)
      :WithMetalShareSlider(50)
    local teamB = Builders.Team:new()
      :WithMetal(700)
      :WithMetalStorage(1000)
      :WithMetalShareSlider(50)

    normalizeAllies({ teamA, teamB }, teamA.allyTeam)

    local spring = buildSpring({ taxRate = 0.5 }, { teamA, teamB })
    local teamsList = buildTeamsTable({ teamA, teamB })
    
    local results = WaterfillSolver.SolveToResults(spring, teamsList)
    
    local teamAMetal, teamBMetal
    for _, result in ipairs(results) do
      if result.resourceType == ResourceTypes.METAL then
        if result.teamId == teamA.id then
          teamAMetal = result
        elseif result.teamId == teamB.id then
          teamBMetal = result
        end
      end
    end
    
    assert.is_near(-66.67, teamAMetal.delta, 0.1)
    assert.is_near(33.33, teamBMetal.delta, 0.1)
    assert.is_true(teamAMetal.sent > teamBMetal.received)
    -- the tax burn is the net loss across the group
    assert.is_near(-33.33, teamAMetal.delta + teamBMetal.delta, 0.1)
  end)
end)

describe("ResourceExcess redistribution", function()
  before_each(function()
    SharedConfig.resetCache()
  end)

  it("processes excesses and returns results", function()
    local teamA = Builders.Team:new()
      :WithMetal(800)
      :WithMetalStorage(1000)
      :WithMetalShareSlider(50)
      :WithEnergy(500)
      :WithEnergyStorage(1000)
      :WithEnergyShareSlider(50)
    local teamB = Builders.Team:new()
      :WithMetal(200)
      :WithMetalStorage(1000)
      :WithMetalShareSlider(50)
      :WithEnergy(500)
      :WithEnergyStorage(1000)
      :WithEnergyShareSlider(50)

    normalizeAllies({ teamA, teamB }, teamA.allyTeam)

    local spring = buildSpring({ taxRate = 0 }, { teamA, teamB })
    local teamsList = buildTeamsTable({ teamA, teamB })
    
    local results = WaterfillSolver.SolveToResults(spring, teamsList)
    
    assert.is_table(results)
    assert.is_true(#results >= 4)
    
    local metalResults = 0
    local energyResults = 0
    for _, result in ipairs(results) do
      if result.resourceType == ResourceTypes.METAL then
        metalResults = metalResults + 1
      elseif result.resourceType == ResourceTypes.ENERGY then
        energyResults = energyResults + 1
      end
    end
    
    assert.equal(2, metalResults)
    assert.equal(2, energyResults)
  end)
end)

describe("ManualShareLedger", function()
  local ManualShareLedger = VFS.Include("common/luaUtilities/economy/manual_share_ledger.lua")

  before_each(function()
    ManualShareLedger.Clear()
  end)

  local function makeResults()
    return {
      { teamId = 0, resourceType = ResourceTypes.METAL, delta = 0, sent = 10, received = 0, excess = 0 },
      { teamId = 1, resourceType = ResourceTypes.METAL, delta = 0, sent = 0, received = 5, excess = 0 },
    }
  end

  it("folds recorded transfers into result entries", function()
    ManualShareLedger.Record(0, 1, ResourceTypes.METAL, 100, 70)
    ManualShareLedger.Record(0, 1, ResourceTypes.METAL, 50, 35)

    local results = ManualShareLedger.FoldInto(makeResults())

    assert.is_near(160, results[1].sent, 1e-6)
    assert.is_near(0, results[1].received, 1e-6)
    assert.is_near(5 + 105, results[2].received, 1e-6)
  end)

  it("clears folded amounts so the next tick gets none", function()
    ManualShareLedger.Record(0, 1, ResourceTypes.METAL, 100, 70)
    ManualShareLedger.FoldInto(makeResults())

    local results = ManualShareLedger.FoldInto(makeResults())
    assert.is_near(10, results[1].sent, 1e-6)
    assert.is_near(5, results[2].received, 1e-6)
  end)

  it("does not touch deltas", function()
    ManualShareLedger.Record(0, 1, ResourceTypes.METAL, 100, 70)
    local results = ManualShareLedger.FoldInto(makeResults())
    assert.equal(0, results[1].delta)
    assert.equal(0, results[2].delta)
  end)
end)
