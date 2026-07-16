---@class ModuleManifest
---@field name string Module name; must match its directory under modules/
---@field dir string Module directory with trailing slash (set by the loader)
---@field version string|nil Semver-ish version string
---@field description string|nil One-line description
---@field requires string[]|nil Names of modules this module depends on
---@field provides string|table|nil Public contract: a path (state-agnostic, default <dir>/api.lua) or an explicit partition { shared = path, synced = path, unsynced = path }; ModuleHandler.Get merges shared + current state into one flat api

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

--- One pipeline per category: modules/<name>/policies/<category>.lua returns an
--- ordered PolicyDescriptor[] — write it by hand or with PolicyBuilder.Pipeline
--- (Gate/Compute). Pure functions constrained by types: no engine mutation in
--- evaluate. Stages run in declaration order; returning nil passes to the next
--- stage, returning a result ends evaluation (first result wins). The terminal
--- Compute stage always returns.
---@class PolicyDescriptor
---@field name string
---@field category string|nil Defaults to the policies/<category>.lua filename
---@field evaluate function fun(...): result|nil
