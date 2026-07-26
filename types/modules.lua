---@class ModuleManifestFile
---@field name string Module name; must match its directory under modules/
---@field version string|nil Semver-ish version string
---@field description string|nil One-line description
---@field requires string[]|nil Names of modules this module depends on
---@field provides string|table|nil Public contract: a path (state-agnostic, default <dir>/api.lua) or an explicit partition { shared = path, synced = path, unsynced = path }; ModuleHandler.Get merges shared + current state into one flat api

---@class ModuleManifest : ModuleManifestFile
---@field dir string Module directory with trailing slash (loader-stamped)

--- Assembled by the LOADER, never hand-authored. Action files register on an explicit
--- local (`local Actions = Actions`), not anonymous setfenv globals — the fragility
--- dbg_test_runner migrated away from. No hand-written parameter schema: controllers are
--- statically typed; a DERIVED schema only returns if a data-driven dispatcher needs it.
---@class ActionDescriptor
---@field name string From the filename; loader-stamped
---@field validate function|nil Pure precondition check over the action's inputs (no mutation)
---@field execute function Performs the action

---@class ActionRegistrar
---@field RegisterValidate fun(fn: function)
---@field RegisterExecute fun(fn: function)

---@class PoliciesRegistrar
---@field Pipeline fun(): PolicyPipeline

--- No engine mutation in evaluate. First non-nil result wins; the terminal Compute
--- stage always returns.
---@class PolicyDescriptor
---@field name string
---@field category string|nil Defaults to the policies/<category>.lua filename
---@field evaluate function fun(...): result|nil
