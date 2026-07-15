---@class ModuleManifest
---@field name string Module name; must match its directory under modules/
---@field dir string Module directory with trailing slash (set by the loader)
---@field version string|nil Semver-ish version string
---@field description string|nil One-line description
---@field requires string[]|nil Names of modules this module depends on
---@field provides string|nil Path to the module's public contract (default: <dir>/api.lua)

---@class ActionParameter
---@field name string
---@field required boolean|nil
---@field type string Lua type name, or "any"

--- One file per action under modules/<name>/actions/. The only effectful layer:
--- actions perform engine mutations; policies stay pure.
---@class ActionDescriptor
---@field name string
---@field parameters ActionParameter[]|nil Declared call schema, prevalidated by ModuleHandler.ValidateActionArgs
---@field execute function Performs the action

--- One file per policy under modules/<name>/policies/<category>/. Pure function
--- constrained by types: no engine mutation inside evaluate. Files evaluate in
--- filename order (numeric prefixes); returning nil passes to the next policy,
--- returning a result ends evaluation (first result wins). By convention the
--- final 1xx_compute_* policy always returns.
---@class PolicyDescriptor
---@field name string
---@field category string|nil Defaults to the policies/ subdirectory name
---@field evaluate function fun(...): result|nil
