local ContextFactoryModule = VFS.Include("modules/transfer/context_factory.lua")
local ResourceTransfer = VFS.Include("modules/transfer/resource/synced.lua")
local SharedConfig = VFS.Include("modules/transfer/economy/shared_config.lua")

local M = {}

function M.modeModOpts(modeConfig)
	-- the lobby sends the selector with the preset; the live set reads it
	local opts = { [modeConfig.category .. "_mode"] = modeConfig.key }
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

function M.buildModeResult(spring, modeConfig, sender, receiver, resourceType, enrichers)
	local springApi = spring:Build()
	springApi.GetModOptions = function()
		return M.modeModOpts(modeConfig)
	end
	SharedConfig.resetCache()

	local ctx = ContextFactoryModule.create(springApi, enrichers or {}).policy(sender.id, receiver.id)
	return ResourceTransfer.CalcResourcePolicy(ctx, resourceType)
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

function M.buildModeTransfer(spring, modeConfig, sender, receiver, resourceType, desiredAmount, enrichers)
	local springApi = spring:Build()
	springApi.GetModOptions = function()
		return M.modeModOpts(modeConfig)
	end
	SharedConfig.resetCache()

	local policyCtx = ContextFactoryModule.create(springApi, enrichers or {}).policy(sender.id, receiver.id)
	local policyResult = M.snapshotResult(ResourceTransfer.CalcResourcePolicy(policyCtx, resourceType))

	local transferCtx = ContextFactoryModule.create(springApi, enrichers or {})
		.resourceTransfer(sender.id, receiver.id, resourceType, desiredAmount, policyResult)
	local result = ResourceTransfer.ResourceTransfer(transferCtx)
	return result, policyResult
end

return M
