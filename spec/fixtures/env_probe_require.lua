-- Requires a path that is not on disk, for spec_env_spec to stub.

---@diagnostic disable: unresolved-require

local stubbed = require("spec/fixtures/not_on_disk")

return stubbed
