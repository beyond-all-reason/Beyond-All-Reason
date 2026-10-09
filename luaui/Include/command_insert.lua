-- Queue planning shared by live commands and the pregame build queue.
-- Positions are {x, y, z}; an empty table represents a non-positional command.
local M = {}

function M.GetMode(modifiers, shift, meta)
	if modifiers.prepend_between or modifiers.prepend_queue then
		if not shift then
			return "front"
		end
		return modifiers.prepend_queue and "prepend" or "between"
	end
	if meta then
		return "front"
	end
end

local function distance(a, b)
	return math.sqrt((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2 + (a[3] - b[3]) ^ 2)
end

-- Keep a batch in its given order. Its internal travel cost is the same at
-- every insertion point, so only the first and last positions are needed.
-- Returns a Lua index; #queue + 1 means append. Ties favor the earlier gap.
function M.FindPosition(start, queue, first, last)
	if not start[1] or start[1] < 0 or not first[1] or not last[1] then
		return #queue + 1
	end
	local previous = start
	local best, cost = #queue + 1, math.huge
	for i, position in ipairs(queue) do
		if position[1] and position[1] >= 0 then
			local extra = distance(previous, first) + distance(last, position) - distance(previous, position)
			if extra < cost then
				best, cost = i, extra
			end
			previous = position
		end
	end
	if distance(previous, first) < cost then
		best = #queue + 1
	end
	return best
end

return M
