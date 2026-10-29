---
--- Where each unit of a group goes in a formation move, on plain { x = number, z = number } tables.
--- Headings are radians as Spring.GetUnitHeading(unitID, true) returns them: 0 faces +z, pi / 2 faces +x.
---

-- The Hungarian method is O(n^3). Above this many units, a greedy match is used instead.
local EXACT_MATCHING_LIMIT = 40

local function distanceSquared(a, b)
	return math.distance2dSquared(a.x, a.z, b.x, b.z)
end

local function distance(a, b)
	return math.sqrt(distanceSquared(a, b))
end

local function center(points)
	local sx, sz = 0, 0
	for _, point in ipairs(points) do
		sx, sz = sx + point.x, sz + point.z
	end
	return { x = sx / #points, z = sz / #points }
end

local function lineLength(line)
	local length = 0.0
	for i = 2, #line do
		length = length + distance(line[i - 1], line[i])
	end
	return length
end

-- n points evenly spaced along the line, both ends included. One point goes to the middle.
local function lineNodes(line, n)
	local length = lineLength(line)
	local spacing = n > 1 and length / (n - 1) or 0.0
	local wanted = n > 1 and 0.0 or length / 2
	local nodes = {}
	local segment, walked = 2, 0.0
	for i = 1, n do
		while segment < #line and walked + distance(line[segment - 1], line[segment]) < wanted do
			walked = walked + distance(line[segment - 1], line[segment])
			segment = segment + 1
		end
		local a, b = line[segment - 1], line[segment]
		local span = distance(a, b)
		local t = span > 0 and math.min(1, math.max(0, (wanted - walked) / span)) or 0
		nodes[i] = { x = a.x + (b.x - a.x) * t, z = a.z + (b.z - a.z) * t }
		wanted = wanted + spacing
	end
	return nodes
end

local function turned(x, z, turn)
	local c, s = math.cos(turn), math.sin(turn)
	return x * c + z * s, z * c - x * s
end

local function keepShape(starts, destination, turn)
	local middle = center(starts)
	local targets = {}
	for i, point in ipairs(starts) do
		local x, z = turned(point.x - middle.x, point.z - middle.z, turn)
		targets[i] = { x = destination.x + x, z = destination.z + z }
	end
	return targets
end

-- The Hungarian method with potentials, minimising the total squared distance.
local function hungarian(starts, targets)
	local n = #starts
	local u, v, p, way = {}, {}, {}, {}
	for i = 0, n do
		u[i], v[i], p[i], way[i] = 0, 0, 0, 0
	end
	for i = 1, n do
		p[0] = i
		local j0 = 0
		local minv, used = {}, {}
		for j = 0, n do
			minv[j], used[j] = math.huge, false
		end
		repeat
			used[j0] = true
			local i0, delta, j1 = p[j0], math.huge, 0
			for j = 1, n do
				if not used[j] then
					local cur = distanceSquared(starts[i0], targets[j]) - u[i0] - v[j]
					if cur < minv[j] then
						minv[j], way[j] = cur, j0
					end
					if minv[j] < delta then
						delta, j1 = minv[j], j
					end
				end
			end
			for j = 0, n do
				if used[j] then
					u[p[j]] = u[p[j]] + delta
					v[j] = v[j] - delta
				else
					minv[j] = minv[j] - delta
				end
			end
			j0 = j1
		until p[j0] == 0
		repeat
			local j1 = way[j0]
			p[j0] = p[j1]
			j0 = j1
		until j0 == 0
	end
	local assignment = {}
	for j = 1, n do
		if p[j] > 0 then
			assignment[p[j]] = j
		end
	end
	return assignment
end

-- The units farthest out pick first.
local function greedy(starts, targets)
	local middle = center(targets)
	local order = {}
	for i = 1, #starts do
		order[i] = i
	end
	table.sort(order, function(a, b)
		return distanceSquared(starts[a], middle) > distanceSquared(starts[b], middle)
	end)
	local taken, assignment = {}, {}
	for _, i in ipairs(order) do
		local best, bestDistance = nil, math.huge
		for j = 1, #targets do
			if not taken[j] then
				local d = distanceSquared(starts[i], targets[j])
				if d < bestDistance then
					best, bestDistance = j, d
				end
			end
		end
		taken[best] = true
		assignment[i] = best
	end
	return assignment
end

local function assigned(starts, spots)
	local assignment = #starts <= EXACT_MATCHING_LIMIT and hungarian(starts, spots) or greedy(starts, spots)
	local targets = {}
	for i = 1, #starts do
		targets[i] = spots[assignment[i]]
	end
	return targets
end

--- Spreads the units evenly along the line, each matched to a spot. Targets are in the order of starts.
local function alongLine(starts, line)
	return assigned(starts, lineNodes(line, #starts))
end

--- Keeps the shape around destination, turned by turn radians. Targets are in the order of starts.
local function aroundPoint(starts, destination, turn)
	local spots = keepShape(starts, destination, turn)
	if turn == 0 then
		return spots
	end
	-- Turned, each unit keeping its own spot would cross the others' paths.
	return assigned(starts, spots)
end

--- The mean of headings, or nil when they cancel out.
local function meanHeading(headings)
	local sx, sz = 0.0, 0.0
	for _, angle in ipairs(headings) do
		sx, sz = sx + math.sin(angle), sz + math.cos(angle)
	end
	if sx * sx + sz * sz < 1e-6 then
		return nil
	end
	return math.atan2(sx, sz)
end

return {
	Center = center,
	Distance = distance,
	MeanHeading = meanHeading,
	AlongLine = alongLine,
	AroundPoint = aroundPoint,
}
