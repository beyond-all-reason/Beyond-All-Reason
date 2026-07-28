local ModuleHandler = require("modules/module_handler")
local Modules = require("modules/enums").Modules
local Pairing = require("modules/transfer/lib/pairing")
local ResourceTransfer = require("modules/transfer/resource/synced")

local M = {}

function M.modeModOpts(modeConfig)
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

-- The terms under the mode, isolated: the context is formed with a hand-built enricher list (none when nil) in place
-- of the discovered providers, then the policy evaluated, outside the frame memo.
---@param springApi SpringBoth a built mock
---@param sender table a team builder
---@param receiver table a team builder
---@param resourceType ResourceName
---@param enrichers PolicyProvision[]|nil
---@return ResourceTransferTerms
local function isolatedTerms(springApi, sender, receiver, resourceType, enrichers)
	---@type TransferContract
	local Transfer = ModuleHandler.Contract(Modules.Transfer)
	local ctx = Pairing.Isolated(enrichers or {}).ForResource(springApi, sender.id, receiver.id, resourceType)
	return ModuleHandler.Evaluate(Transfer.ResourceTransfer, ctx)
end

function M.buildModeResult(spring, modeConfig, sender, receiver, resourceType, enrichers)
	local springApi = spring:Build()
	springApi.GetModOptions = function()
		return M.modeModOpts(modeConfig)
	end
	return isolatedTerms(springApi, sender, receiver, resourceType, enrichers)
end

---@generic T: table
---@param result T
---@return T a shallow copy, one level deep
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
	local terms = M.snapshotResult(isolatedTerms(springApi, sender, receiver, resourceType, enrichers))

	local transferCtx =
		Pairing.Request(springApi, sender.id, receiver.id, resourceType, desiredAmount, terms, enrichers or {})
	local result = ResourceTransfer.Transfer(transferCtx)
	return result, terms
end

return M
