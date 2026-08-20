-- Deliberate findings for the type check's red run. Removed before merge.

---@type string
local probe = 12345

ProbablyAnUndefinedGlobal(probe)
IShouldSaySoGoodChap[probe]