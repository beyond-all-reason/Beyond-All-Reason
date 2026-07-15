local ContextFactoryModule = VFS.Include("modules/sharing/context_factory.lua")
local PolicyEvaluation = VFS.Include("modules/sharing/policy_evaluation.lua")
local ResourceTransferAction = VFS.Include("modules/sharing/actions/resource_transfer.lua")
local SharedConfig = VFS.Include("modules/sharing/config.lua")

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
	springApi.GetModOptions = function()
		return M.modeModOpts(modeConfig)
	end
	SharedConfig.resetCache()

	local saved = ContextFactoryModule.getEnrichers()
	ContextFactoryModule.setEnrichers(enricherFn and { enricherFn } or {})

	local ctx = ContextFactoryModule.create(springApi).policy(sender.id, receiver.id)
	local result = PolicyEvaluation.CalcResourcePolicy(ctx, resourceType)

	ContextFactoryModule.setEnrichers(saved)
	return result
end

function M.snapshotResult(result)
	local snap = {}
	for k, v in pairs(result) do
		if type(v) == "table" then
			local copy = {}
			for k2, v2 in pairs(v) do
				copy[k2] = v2
			end
			snap[k] = copy
		else
			snap[k] = v
		end
	end
	return snap
end

function M.buildModeTransfer(spring, modeConfig, sender, receiver, resourceType, desiredAmount, enricherFn)
	local springApi = spring:Build()
	springApi.GetModOptions = function()
		return M.modeModOpts(modeConfig)
	end
	SharedConfig.resetCache()

	local saved = ContextFactoryModule.getEnrichers()
	ContextFactoryModule.setEnrichers(enricherFn and { enricherFn } or {})

	local policyCtx = ContextFactoryModule.create(springApi).policy(sender.id, receiver.id)
	local policyResult = M.snapshotResult(PolicyEvaluation.CalcResourcePolicy(policyCtx, resourceType))

	local transferCtx = ContextFactoryModule.create(springApi).resourceTransfer(sender.id, receiver.id, resourceType, desiredAmount, policyResult)
	local result = ResourceTransferAction.execute(transferCtx)

	ContextFactoryModule.setEnrichers(saved)
	return result, policyResult
end

return M
