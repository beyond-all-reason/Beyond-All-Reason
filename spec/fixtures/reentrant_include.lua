-- Includes itself once, under a different environment, and reads its own global
-- again afterwards. A shared compiled chunk would have had its environment
-- retargeted by the nested call, so the second read would come back "inner".
---@diagnostic disable-next-line: undefined-global
local before = marker

---@diagnostic disable-next-line: undefined-global
if not alreadyNested then
	local nested = setmetatable({ marker = "inner", alreadyNested = true }, { __index = _G })
	require("spec/fixtures/reentrant_include", nested)
end

return {
	before = before,
	---@diagnostic disable-next-line: undefined-global
	after = marker,
}
