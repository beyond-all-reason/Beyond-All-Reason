local ContextFactoryModule = VFS.Include("common/luaUtilities/team_transfer/context_factory.lua")
local ResourceTransfer = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_synced.lua")

local M = {}

function M.modeModOpts(modeConfig)
  local opts = {}
  for key, entry in pairs(modeConfig.modOptions) do
    local value = entry.value
    if type(value) == "boolean" then
      opts[key] = value and "1" or "0"
    else
      opts[key] = tostring(value)
    end
  end
  return opts
end

function M.buildModeResult(spring, modeConfig, sender, receiver, resourceType, enricherFn)
  local springApi = spring:Build()
  springApi.GetModOptions = function() return M.modeModOpts(modeConfig) end

  local saved = ContextFactoryModule.getEnrichers()
  ContextFactoryModule.setEnrichers(enricherFn and { enricherFn } or {})

  local ctx = ContextFactoryModule.create(springApi).policy(sender.id, receiver.id)
  local result = ResourceTransfer.CalcResourcePolicy(ctx, resourceType)

  ContextFactoryModule.setEnrichers(saved)
  return result
end

function M.snapshotResult(result)
  local snap = {}
  for k, v in pairs(result) do
    if type(v) == "table" then
      local copy = {}
      for k2, v2 in pairs(v) do copy[k2] = v2 end
      snap[k] = copy
    else
      snap[k] = v
    end
  end
  return snap
end

function M.buildModeTransfer(spring, modeConfig, sender, receiver, resourceType, desiredAmount, enricherFn)
  local springApi = spring:Build()
  springApi.GetModOptions = function() return M.modeModOpts(modeConfig) end

  local saved = ContextFactoryModule.getEnrichers()
  ContextFactoryModule.setEnrichers(enricherFn and { enricherFn } or {})

  local policyCtx = ContextFactoryModule.create(springApi).policy(sender.id, receiver.id)
  local policyResult = M.snapshotResult(ResourceTransfer.CalcResourcePolicy(policyCtx, resourceType))

  local transferCtx = ContextFactoryModule.create(springApi).resourceTransfer(
    sender.id, receiver.id, resourceType, desiredAmount, policyResult)
  local result = ResourceTransfer.ResourceTransfer(transferCtx)

  ContextFactoryModule.setEnrichers(saved)
  return result, policyResult
end

return M
