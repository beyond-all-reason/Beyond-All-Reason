--- Deliberately NOT math.randomseed: busted shares one global generator across files, and a spec
--- that reseeded it would make its neighbours' results depend on run order.

local SeededRng = {}

---@param seed integer
---@return WaveRng
function SeededRng.New(seed)
	local state = seed % 2147483647
	if state <= 0 then
		state = state + 2147483646
	end
	---Park-Miller: enough for fixtures, and identical on every platform.
	local function nextFloat()
		state = (state * 16807) % 2147483647
		return (state - 1) / 2147483646
	end
	---@param m number|nil
	---@param n number|nil
	---@return number
	return function(m, n)
		local value = nextFloat()
		if m == nil then
			return value
		end
		if n == nil then
			return math.floor(value * m) + 1
		end
		return m + math.floor(value * (n - m + 1))
	end
end

---@param values number[]
---@return WaveRng
function SeededRng.Scripted(values)
	local index = 0
	return function(m, n)
		index = index + 1
		local value = values[math.min(index, #values)] or 0
		if m == nil then
			return value
		end
		if n == nil then
			return math.max(1, math.min(m, math.floor(value)))
		end
		return math.max(m, math.min(n, math.floor(value)))
	end
end

return SeededRng
