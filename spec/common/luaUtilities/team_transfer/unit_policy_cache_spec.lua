---@type Builders
local Builders = VFS.Include("spec/builders/index.lua")
local ModeEnums = VFS.Include("modes/sharing_mode_enums.lua")
local ContextFactoryModule = VFS.Include("common/luaUtilities/team_transfer/context_factory.lua")
local UnitTransfer = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_synced.lua")
local UnitShared = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_shared.lua")

local ALL = ModeEnums.UnitFilterCategory.All
local NONE = ModeEnums.UnitFilterCategory.None

-- The unit cache stores one factor record per team (sharing modes + active flag);
-- GetCachedPolicyResult reconstructs any pair from those plus live alliance/cheat gates.
describe("unit policy cache (per-team factors) #policy", function()
  local sender, receiver, enemy, spring

  before_each(function()
    sender = Builders.Team:new():Human()
    receiver = Builders.Team:new():Human()
    enemy = Builders.Team:new():Human()
    spring = Builders.Spring.new()
      :WithTeam(sender):WithTeam(receiver):WithTeam(enemy)
      :WithAlliance(sender.id, receiver.id, true)
      :WithAlliance(receiver.id, sender.id, true)
      :WithModOption(ModeEnums.ModOptions.UnitSharingMode, ALL)
      :WithTeamRulesParam(sender.id, "numActivePlayers", 1)
      :WithTeamRulesParam(receiver.id, "numActivePlayers", 1)
      :WithTeamRulesParam(enemy.id, "numActivePlayers", 1)
  end)

  -- Build the mock and populate each team's unit factor.
  local function populate()
    local springApi = spring:Build()
    local contextFactory = ContextFactoryModule.create(springApi)
    for _, teamId in ipairs(springApi.GetTeamList()) do
      UnitTransfer.CacheTeamFactor(springApi, teamId, contextFactory.policy(teamId, teamId))
    end
    return springApi, contextFactory
  end

  it("reconstructs an allied pair identically to a direct GetPolicy", function()
    local springApi, contextFactory = populate()
    local cached = UnitShared.GetCachedPolicyResult(sender.id, receiver.id, springApi)
    local direct = UnitTransfer.GetPolicy(contextFactory.policy(sender.id, receiver.id))
    assert.equal(direct.canShare, cached.canShare)
    assert.same(direct.sharingModes, cached.sharingModes)
  end)

  it("allows an allied pair under a shareable mode", function()
    local springApi = populate()
    assert.equal(true, UnitShared.GetCachedPolicyResult(sender.id, receiver.id, springApi).canShare)
  end)

  it("denies a cross-alliance pair", function()
    local springApi = populate()
    assert.equal(false, UnitShared.GetCachedPolicyResult(sender.id, enemy.id, springApi).canShare)
  end)

  it("denies when the sharing mode is None", function()
    spring:WithModOption(ModeEnums.ModOptions.UnitSharingMode, NONE)
    local springApi = populate()
    assert.equal(false, UnitShared.GetCachedPolicyResult(sender.id, receiver.id, springApi).canShare)
  end)

  it("denies when the receiver has no active players", function()
    spring:WithTeamRulesParam(receiver.id, "numActivePlayers", 0)
    local springApi = populate()
    assert.equal(false, UnitShared.GetCachedPolicyResult(sender.id, receiver.id, springApi).canShare)
  end)

  it("cheating bypasses the inactive-receiver gate", function()
    spring:WithTeamRulesParam(receiver.id, "numActivePlayers", 0)
    local springApi = populate()
    springApi.IsCheatingEnabled = function() return true end
    assert.equal(true, UnitShared.GetCachedPolicyResult(sender.id, receiver.id, springApi).canShare)
  end)

  it("cheating does NOT bypass the alliance gate (units, unlike resources)", function()
    local springApi = populate()
    springApi.IsCheatingEnabled = function() return true end
    assert.equal(false, UnitShared.GetCachedPolicyResult(sender.id, enemy.id, springApi).canShare)
  end)

  it("falls back to the global mode + alliance when factors are absent", function()
    local springApi = spring:Build()
    -- no populate(): allied pair under a shareable global mode is still allowed
    assert.equal(true, UnitShared.GetCachedPolicyResult(sender.id, receiver.id, springApi).canShare)
    assert.equal(false, UnitShared.GetCachedPolicyResult(sender.id, enemy.id, springApi).canShare)
  end)
end)
