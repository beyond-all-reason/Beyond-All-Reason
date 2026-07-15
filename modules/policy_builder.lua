--- Fluent builder for PolicyDescriptors — the modder-facing sugar layer.
---
--- The canonical policy format is the descriptor file (see modules/types/modules.lua):
--- a pure typed evaluate function in its own file. This builder only *emits* that
--- format; it adds no runtime of its own and BAR's built-in policies don't use it.
---
---   return PolicyBuilder.new("NoEnemyMetal")
---       :Category("metal_transfer")
---       :Enemy()
---       :Returns(function(ctx) return MyDenyResult(ctx) end)
---       :Build()
---
--- is byte-for-byte equivalent (as a descriptor) to writing the table by hand.

---@class PolicyBuilder
---@field name string
---@field categoryName string|nil
---@field predicates (fun(...): boolean)[]
local PolicyBuilder = {}
PolicyBuilder.__index = PolicyBuilder

---@param name string
---@return PolicyBuilder
function PolicyBuilder.new(name)
	return setmetatable({
		name = name,
		categoryName = nil,
		predicates = {},
	}, PolicyBuilder)
end

---@param category string
---@return PolicyBuilder
function PolicyBuilder:Category(category)
	self.categoryName = category
	return self
end

---Add a predicate; evaluate returns nil (pass) unless every predicate holds.
---@param predicate fun(...): boolean receives evaluate's arguments (ctx, ...)
---@return PolicyBuilder
function PolicyBuilder:When(predicate)
	self.predicates[#self.predicates + 1] = predicate
	return self
end

---Sugar: only when sender and receiver are allied (ctx.areAlliedTeams).
---@return PolicyBuilder
function PolicyBuilder:Allied()
	return self:When(function(ctx)
		return ctx.areAlliedTeams == true
	end)
end

---Sugar: only when sender and receiver are enemies.
---@return PolicyBuilder
function PolicyBuilder:Enemy()
	return self:When(function(ctx)
		return ctx.areAlliedTeams == false
	end)
end

---Terminal: when all predicates hold, evaluation ends with handler's result.
---@param handler fun(...): any pure function producing the policy result
---@return PolicyBuilder
function PolicyBuilder:Returns(handler)
	self.handler = handler
	return self
end

---Terminal alias for deny-gates: reads as intent at the call site.
---@param makeDenyResult fun(...): any pure function producing the deny result
---@return PolicyBuilder
function PolicyBuilder:Deny(makeDenyResult)
	return self:Returns(makeDenyResult)
end

---@return PolicyDescriptor
function PolicyBuilder:Build()
	assert(self.handler, "PolicyBuilder: Returns()/Deny() must be set before Build()")
	local predicates = self.predicates
	local handler = self.handler
	---@type PolicyDescriptor
	return {
		name = self.name,
		category = self.categoryName,
		evaluate = function(...)
			for _, predicate in ipairs(predicates) do
				if not predicate(...) then
					return nil
				end
			end
			return handler(...)
		end,
	}
end

return PolicyBuilder
