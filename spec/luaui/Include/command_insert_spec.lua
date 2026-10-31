local Insert = require("luaui/Include/command_insert")
local function distance(a, b)
	return math.sqrt((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2 + (a[3] - b[3]) ^ 2)
end
local function length(start, queue)
	local result = 0
	for _, p in ipairs(queue) do
		result = result + distance(start, p)
		start = p
	end
	return result
end

describe("shared queue insertion planner", function()
	it("minimizes total route length without splitting an ordered batch", function()
		-- Compare to enumerating every complete candidate route, including the
		-- batch's internal legs. This is independent of the endpoint shortcut.
		for seed = 1, 60 do
			local start = { 0, 0, 0 }
			local queue = { { 40, 0, 80 }, { 100, 20, 0 }, { 200, 0, 50 } }
			local batch = { { seed * 4, seed % 7, seed % 11 * 12 }, { seed * 3, 0, 70 }, { seed * 5, 20, 120 } }
			local best, minimum = 1, math.huge
			for gap = 1, #queue + 1 do
				local route = {}
				for i = 1, #queue + 1 do
					if i == gap then
						for _, p in ipairs(batch) do
							route[#route + 1] = p
						end
					end
					if queue[i] then
						route[#route + 1] = queue[i]
					end
				end
				local cost = length(start, route)
				if cost < minimum - 0.000001 then
					minimum = cost
					best = gap
				end
			end
			local position = Insert.FindPosition(start, queue, batch[1], batch[#batch])
			assert(position == best, "wrong gap for case " .. seed)
		end
	end)
	it("appends if the pregame start point is unknown", function()
		assert(Insert.FindPosition({ -100, 0, -100 }, { { 100, 0, 0 } }, { 50, 0, 0 }, { 60, 0, 0 }) == 2)
	end)
	it("keeps insertion action precedence over Meta", function()
		assert(Insert.GetMode({ prepend_between = true }, true, true) == "between")
		assert(Insert.GetMode({ prepend_between = true, prepend_queue = true }, true, true) == "prepend")
		assert(Insert.GetMode({ prepend_between = true }, false, false) == "front")
		assert(Insert.GetMode({}, true, true) == "front")
		assert(Insert.GetMode({}, true, false) == nil)
	end)
end)
