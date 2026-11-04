---@meta

-- Type extensions for classes that BAR injects fields into at runtime.
-- These prevent inject-field warnings without losing type safety on known fields.

---@class Command
---@field tx number?
---@field ty number?
---@field tz number?
---@field tag integer?
---@field [string] any

---@class BuildCommandEntry
---@field builderCount integer?
---@field [string] any
