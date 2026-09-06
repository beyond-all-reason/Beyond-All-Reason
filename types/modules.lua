---@meta

---@class ModuleManifestFile
---@field name string Module name; must match its directory under modules/
---@field version string|nil Semver-ish version string
---@field description string|nil One-line description
---@field requires string[]|nil Names of modules this module depends on

---@class ModuleManifest : ModuleManifestFile
---@field dir string Module directory with trailing slash (loader-stamped)

---@class ActionDescriptor
---@field name string From the filename; loader-stamped
---@field validate function|nil Pure precondition check over the action's inputs (no mutation)
---@field execute function Performs the action

---@class ActionRegistrar
---@field RegisterValidate fun(fn: function)
---@field RegisterExecute fun(fn: function)

---The facade a policy file's sandbox provides. One chain of stages for the
---identified pipeline, the owner's and contributors' alike; the stages'
---context type flows into every predicate.
---@class PoliciesRegistrar
Policies = {}

---The one way in. Hand it a pipeline's stages and the chain takes guards and
---Answers; hand it a contract's facts and it takes Provide and Default.
---@generic C, T
---@param stages PolicyStages<C, T>
---@return PolicyPipeline<C, T>
---@overload fun(facts: PolicyFacts<C>): PolicyEnrichment<C>
function Policies.On(stages) end

---@class PolicyDescriptor
---@field name string
---@field kind "if"|"unless"|"answer"
---@field category string|nil Loader-stamped from the pipeline's identity
---@field evaluate function fun(...): result|nil
