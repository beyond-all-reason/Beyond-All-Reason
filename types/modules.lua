---@meta

---@class ModuleManifestFile
---@field name string Module name; must match its directory under modules/
---@field version string|nil Semver-ish version string
---@field description string|nil One-line description
---@field requires string[]|nil Names of modules this module depends on

---@class ModuleManifest : ModuleManifestFile
---@field dir string Module directory with trailing slash (loader-stamped)
