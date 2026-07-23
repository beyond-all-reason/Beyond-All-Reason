--- What a module author writes in modules/<name>/module.lua.
---@class ModuleManifestFile
---@field name string Module name; must match its directory under modules/
---@field version string|nil Semver-ish version string
---@field description string|nil One-line description
---@field requires string[]|nil Names of modules this module depends on
---@field provides string|table|nil Public contract: a path (state-agnostic, default <dir>/api.lua) or an explicit partition { shared = path, synced = path, unsynced = path }; ModuleHandler.Get merges shared + current state into one flat api

--- A discovered manifest, enriched by the loader.
---@class ModuleManifest : ModuleManifestFile
---@field dir string Module directory with trailing slash (loader-stamped)

--- The runtime registry entry for an action — assembled by the LOADER, never
--- hand-authored. Action files register via the injected `Actions` registrar
--- (`local Actions = Actions`, the widget-handler idiom: explicit named calls
--- on an explicit local, not anonymous setfenv globals): RegisterValidate
--- (optional, first) then RegisterExecute (required, exactly one); files
--- return nothing, and identity is the filename (actions/unit_transfer.lua →
--- "unit_transfer"). Actions are the only effectful layer; validate stays pure.
--- NOTE: no hand-written parameter schema — controllers are statically typed
--- (LuaCATS + emmylua). A DERIVED schema (generated from the annotations, e.g.
--- lua-doc-extractor) returns if/when a data-driven dispatcher (mission_api,
--- CampaignAPI) creates a runtime boundary the type checker cannot see.
---@class ActionDescriptor
---@field name string From the filename; loader-stamped
---@field validate function|nil Pure precondition check over the action's inputs (no mutation)
---@field execute function Performs the action

---@class ActionRegistrar
---@field RegisterValidate fun(fn: function)
---@field RegisterExecute fun(fn: function)

---@class PoliciesRegistrar
---@field Pipeline fun(): PolicyPipeline

--- One pipeline per category: modules/<name>/policies/<category>.lua registers
--- an ordered PolicyDescriptor[] via the injected `Policies` facade —
--- Policies.Pipeline():Gate(...):Compute(...):Register(); files return nothing. Pure functions constrained by types: no engine mutation in
--- evaluate. Stages run in declaration order; returning nil passes to the next
--- stage, returning a result ends evaluation (first result wins). The terminal
--- Compute stage always returns.
---@class PolicyDescriptor
---@field name string
---@field category string|nil Defaults to the policies/<category>.lua filename
---@field evaluate function fun(...): result|nil
