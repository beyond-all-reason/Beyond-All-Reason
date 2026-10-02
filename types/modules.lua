---@meta

---@class ModuleManifestFile
---@field name string Module name; must match its directory under modules/
---@field version string|nil Semver-ish version string
---@field description string|nil One-line description
---@field requires string[]|nil Names of modules this module depends on

---@class ModuleManifest : ModuleManifestFile
---@field dir string Module directory with trailing slash (loader-stamped)

---@class ActionRegistrar
---@field RegisterValidate fun(fn: function)
---@field RegisterExecute fun(fn: function)

---@class PoliciesRegistrar
Policies = {}

---@generic C, T
---@param steps PolicySteps<C, T>
---@return PolicyChain<C, T>
---@overload fun(facts: PolicyFacts<C>): PolicyEnrichment<C>
function Policies.On(steps) end

---@param moduleName string a Modules entry
---@return table that module's contract: what its contract.lua declares and what its policy files return; annotate with the module's contract class
function Policies.Contract(moduleName) end

---@class PolicyStep
---@field name string
---@field kind "if"|"unless"|"answer"|"factor"|"apply"
---@field category string|nil Loader-stamped from the policy's identity
---@field evaluate function fun(...): result|nil
