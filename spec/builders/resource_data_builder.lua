local defaults = {
	current = 0,
	storage = 0,
	pull = 0,
	income = 0,
	expense = 0,
	shareSlider = 0,
	sent = 0,
	received = 0,
	excess = 0,
	resourceType = nil,
}

local function clone(tableValue)
	local copy = {}
	for key, value in pairs(tableValue) do
		if type(value) == "table" then
			copy[key] = clone(value)
		else
			copy[key] = value
		end
	end
	return copy
end

---@class ResourceDataBuilder
---@field data ResourceData
local ResourceDataBuilder = {}
ResourceDataBuilder.__index = ResourceDataBuilder

function ResourceDataBuilder.new()
	return setmetatable({ data = clone(defaults) }, ResourceDataBuilder)
end

function ResourceDataBuilder.from(existing)
	local builder = ResourceDataBuilder.new()
	for key, value in pairs(existing or {}) do
		builder.data[key] = value
	end
	return builder
end

function ResourceDataBuilder:WithField(fieldName, value)
	self.data[fieldName] = value
	return self
end

function ResourceDataBuilder:WithCurrent(value) return self:WithField("current", value) end
function ResourceDataBuilder:WithStorage(value) return self:WithField("storage", value) end
function ResourceDataBuilder:WithPull(value) return self:WithField("pull", value) end
function ResourceDataBuilder:WithIncome(value) return self:WithField("income", value) end
function ResourceDataBuilder:WithExpense(value) return self:WithField("expense", value) end
function ResourceDataBuilder:WithShareSlider(value) return self:WithField("shareSlider", value) end
function ResourceDataBuilder:WithSent(value) return self:WithField("sent", value) end
function ResourceDataBuilder:WithReceived(value) return self:WithField("received", value) end
function ResourceDataBuilder:WithExcess(value) return self:WithField("excess", value) end
function ResourceDataBuilder:WithResourceType(value) return self:WithField("resourceType", value) end

function ResourceDataBuilder:Build()
	return clone(self.data)
end

return ResourceDataBuilder

