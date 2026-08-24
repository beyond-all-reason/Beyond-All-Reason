-- CI fixture. Deliberately broken; delete ci_test/ before merging.

---@param n number
---@return number
local function double(n)
	return n * 2
end

---@class CiFixtureBox
---@field count number
local box = { count = 0 }

---@return string
local function wrongReturn()
	return 42
end

---@type number
local notANumber = "definitely a string"

---@type string[]
local names = { 1, 2, 3 }

local results = {}
results[#results + 1] = double("one")
results[#results + 1] = double(true)
results[#results + 1] = double({})
results[#results + 1] = double(nil)
results[#results + 1] = box.missingField
results[#results + 1] = box.count .. "concatenated"
results[#results + 1] = NotARealGlobalAnywhere.doThing()

return {
	double = double,
	box = box,
	wrongReturn = wrongReturn,
	notANumber = notANumber,
	names = names,
	results = results,
}
