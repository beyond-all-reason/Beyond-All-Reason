local Policy = require("modules/policy")

---@class RegionDescription what the module that owns a type says of one of its regions; nothing for a type nobody owns

---@class RegionDescribeContext<R>
---@field type RegionType
---@field region R
---@field map RegionMap

---@class RegionDescribePolicy: PolicySteps<RegionDescribeContext<Region>, RegionDescription|nil>
---@field Nobody "Nobody"

---@type RegionDescribePolicy
local Describe = {
	Nobody = "Nobody",
}
Policy.Single(Describe)

Policies.On(Describe).Answer(Describe.Nobody, function()
	return nil
end)

---@class (partial) RegionsContract
local Contract = {}
Contract.Describe = Describe

return Contract
