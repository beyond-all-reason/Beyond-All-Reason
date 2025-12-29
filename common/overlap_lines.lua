local OverlapLines = {}

-- Returns the intersection points of two circles
-- P0: center of first circle (x, z)
-- P1: center of second circle (x, z)
-- r: radius (same for both)
-- Returns: p1, p2 (tables with x, z) or nil if no intersection
local function getCircleIntersections(x0, z0, x1, z1, r)
    local dx = x1 - x0
    local dz = z1 - z0
    local d2 = dx*dx + dz*dz
    local d = math.sqrt(d2)

    if d > 2 * r or d == 0 then
        return nil, nil
    end

    -- a is the distance from P0 to the chord
    local a = d / 2
    local h = math.sqrt(math.max(0, r*r - a*a))

    local x2 = x0 + a * (dx / d)
    local z2 = z0 + a * (dz / d)

    local x3_1 = x2 + h * (dz / d)
    local z3_1 = z2 - h * (dx / d)

    local x3_2 = x2 - h * (dz / d)
    local z3_2 = z2 + h * (dx / d)

    return {x = x3_1, z = z3_1}, {x = x3_2, z = z3_2}
end

-- Generate lines for a commander against a list of neighbors
-- originX, originZ: coordinates of the central point
-- neighbors: list of tables {x=..., z=...}
-- range: radius of circles
function OverlapLines.getOverlapLines(originX, originZ, neighbors, range)
    local lines = {}
    for i = 1, #neighbors do
        local n = neighbors[i]
        local p1, p2 = getCircleIntersections(originX, originZ, n.x, n.z, range)
        if p1 and p2 then
            table.insert(lines, {p1 = p1, p2 = p2, neighbor = n})
        end
    end
    return lines
end

-- Check if point is "past" any of the lines relative to origin.
-- "Past" means on the opposite side of the line from the origin.
-- Returns true if past any line, false otherwise.
function OverlapLines.isPointPastLines(pointX, pointZ, originX, originZ, lines)
    for i = 1, #lines do
        local line = lines[i]
        local p1 = line.p1
        local p2 = line.p2
        
        -- Line defined by p1 -> p2.
        -- We check the sign of the cross product (2D determinant) for Origin and Point.
        -- D = (x2-x1)(z-z1) - (z2-z1)(x-x1)
        
        local dx = p2.x - p1.x
        local dz = p2.z - p1.z
        
        local valOrigin = dx * (originZ - p1.z) - dz * (originX - p1.x)
        local valPoint = dx * (pointZ - p1.z) - dz * (pointX - p1.x)
        
        -- If signs are different (product < 0), point is on opposite side.
        if valOrigin * valPoint < 0 then
            return true
        end
    end
    return false
end

return OverlapLines

