local Builders = VFS.Include("spec/builders/index.lua")
local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")
local SharedConfig = VFS.Include("common/luaUtilities/economy/shared_config.lua")
local WaterfillSolver = VFS.Include("common/luaUtilities/economy/economy_waterfill_solver.lua")

local ResourceType = SharedEnums.ResourceType

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
  builder:WithModOption(SharedEnums.ModOptions.TaxResourceSharingAmount, opts.taxRate or 0)
  builder:WithModOption(SharedEnums.ModOptions.PlayerMetalSendThreshold, opts.metalThreshold or 0)
  builder:WithModOption(SharedEnums.ModOptions.PlayerEnergySendThreshold, opts.energyThreshold or 0)
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
      assert.is_number(result.current)
      assert.is_number(result.sent)
      assert.is_number(result.received)
      if result.resourceType == ResourceType.METAL then
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
      if result.resourceType == ResourceType.METAL then
        if result.teamId == teamA.id then
          teamAMetal = result
        elseif result.teamId == teamB.id then
          teamBMetal = result
        end
      end
    end
    
    assert.is_near(500, teamAMetal.current, 0.1)
    assert.is_near(500, teamBMetal.current, 0.1)
    assert.is_near(300, teamAMetal.sent, 0.1)
    assert.is_near(300, teamBMetal.received, 0.1)
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
      if result.resourceType == ResourceType.METAL then
        if result.teamId == teamA.id then
          teamAMetal = result
        elseif result.teamId == teamB.id then
          teamBMetal = result
        end
      end
    end
    
    assert.is_near(733.33, teamAMetal.current, 0.1)
    assert.is_near(733.33, teamBMetal.current, 0.1)
    assert.is_true(teamAMetal.sent > teamBMetal.received)
  end)
end)

describe("ResourceExcess integration", function()
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
      if result.resourceType == ResourceType.METAL then
        metalResults = metalResults + 1
      elseif result.resourceType == ResourceType.ENERGY then
        energyResults = energyResults + 1
      end
    end
    
    assert.equal(2, metalResults)
    assert.equal(2, energyResults)
  end)
end)
