local OverlapLines = {}

---Returns the intersection points of two circles
---@param centerX0 number
---@param centerZ0 number
---@param centerX1 number
---@param centerZ1 number
---@param radius number
---@return table|nil intersection1 {x: number, z: number}
---@return table|nil intersection2 {x: number, z: number}
local function getCircleIntersections(centerX0, centerZ0, centerX1, centerZ1, radius)
    local distanceSquared = math.distance2dSquared(centerX0, centerZ0, centerX1, centerZ1)
    
    if distanceSquared > (2 * radius) ^ 2 or distanceSquared == 0 then
        return nil, nil
    end

    local distance = math.sqrt(distanceSquared)
    local deltaX = centerX1 - centerX0
    local deltaZ = centerZ1 - centerZ0

    local distToChord = distance / 2
    local height = math.sqrt(math.max(0, radius * radius - distToChord * distToChord))

    local midX = centerX0 + distToChord * (deltaX / distance)
    local midZ = centerZ0 + distToChord * (deltaZ / distance)

    local intersection1X = midX + height * (deltaZ / distance)
    local intersection1Z = midZ - height * (deltaX / distance)

    local intersection2X = midX - height * (deltaZ / distance)
    local intersection2Z = midZ + height * (deltaX / distance)

    return {x = intersection1X, z = intersection1Z}, {x = intersection2X, z = intersection2Z}
end

---Generate lines for a commander against a list of neighbors
---@param originX number
---@param originZ number
---@param neighbors table[] List of tables with .x and .z
---@param range number
---@return table[] lines
function OverlapLines.getOverlapLines(originX, originZ, neighbors, range)
    local lines = {
        originX = originX,
        originZ = originZ,
    }
    for i = 1, #neighbors do
        local neighbor = neighbors[i]
        local point1, point2 = getCircleIntersections(originX, originZ, neighbor.x, neighbor.z, range)
        if point1 and point2 then
            local deltaX = point2.x - point1.x
            local deltaZ = point2.z - point1.z
            
            local lineCoeffA = -deltaZ
            local lineCoeffB = deltaX
            local lineCoeffC = -(lineCoeffA * point1.x + lineCoeffB * point1.z)
            
            local originSideValue = lineCoeffA * originX + lineCoeffB * originZ + lineCoeffC
            
            table.insert(lines, {
                p1 = point1, 
                p2 = point2, 
                neighbor = neighbor,
                A = lineCoeffA,
                B = lineCoeffB,
                C = lineCoeffC,
                originVal = originSideValue
            })
        end
    end
    return lines
end

---Check if point is "past" any of the lines relative to origin.
---@param pointX number
---@param pointZ number
---@param originX number
---@param originZ number
---@param lines table[]
---@return boolean isPast
function OverlapLines.isPointPastLines(pointX, pointZ, originX, originZ, lines)
    if not lines or #lines == 0 then
        return false
    end
    
    if lines.originX and lines.originZ then
        local TOLERANCE = 0.1
        if math.abs(originX - lines.originX) > TOLERANCE or math.abs(originZ - lines.originZ) > TOLERANCE then
            -- Origin mismatch detected but no warning needed
        end
    end
    
    for i = 1, #lines do
        local line = lines[i]
        
        local pointSideValue = line.A * pointX + line.B * pointZ + line.C
        
        if pointSideValue * line.originVal < 0 then
            return true
        end
    end
    return false
end

---Calculate intersection of two lines
---@param p1 table First point of first line {x: number, z: number}
---@param p2 table Second point of first line {x: number, z: number}
---@param p3 table First point of second line {x: number, z: number}
---@param p4 table Second point of second line {x: number, z: number}
---@return table|nil intersection Point of intersection {x: number, z: number, t: number} or nil if no intersection
local function findLineIntersection(p1, p2, p3, p4)
    local x1, z1 = p1.x, p1.z
    local x2, z2 = p2.x, p2.z
    local x3, z3 = p3.x, p3.z
    local x4, z4 = p4.x, p4.z
    
    local denom = (x1 - x2) * (z3 - z4) - (z1 - z2) * (x3 - x4)
    if math.abs(denom) < 0.0001 then return nil end
    
    local t = ((x1 - x3) * (z3 - z4) - (z1 - z3) * (x3 - x4)) / denom
    local u = -((x1 - x2) * (z1 - z3) - (z1 - z2) * (x1 - x3)) / denom
    
    if t >= 0 and t <= 1 and u >= 0 and u <= 1 then
        return {
            x = x1 + t * (x2 - x1),
            z = z1 + t * (z2 - z1),
            t = t
        }
    end
    return nil
end

local function getSide(p, lineP1, lineP2)
    return (lineP2.x - lineP1.x) * (p.z - lineP1.z) - (lineP2.z - lineP1.z) * (p.x - lineP1.x)
end

local CIRCLE_SEGMENT_COUNT = 128

---Get segments for drawing the overlap lines and circle boundary
---@param lines table[] The cached overlap lines
---@param originX number The origin X coordinate (usually commander)
---@param originZ number The origin Z coordinate (usually commander)
---@param radius number The radius of the build circle
---@return table[] segments List of segments to draw, each segment is {p1={x,z}, p2={x,z}}
function OverlapLines.getDrawingSegments(lines, originX, originZ, radius)
    local segments = {}
    
    local originPos = {x = originX, z = originZ}
    local lineValidSides = {}
    
    if lines and #lines > 0 then
        for i, line in ipairs(lines) do
            lineValidSides[i] = getSide(originPos, line.p1, line.p2)
        end

        for i, line in ipairs(lines) do
            local intersections = {}
            table.insert(intersections, {x = line.p1.x, z = line.p1.z, t = 0})
            table.insert(intersections, {x = line.p2.x, z = line.p2.z, t = 1})
            
            for j, otherLine in ipairs(lines) do
                if i ~= j then
                    local intersection = findLineIntersection(line.p1, line.p2, otherLine.p1, otherLine.p2)
                    if intersection then
                        table.insert(intersections, intersection)
                    end
                end
            end
            
            table.sort(intersections, function(a, b) return a.t < b.t end)
            
            for k = 1, #intersections - 1 do
                local pA = intersections[k]
                local pB = intersections[k + 1]
                local mid = {x = (pA.x + pB.x) / 2, z = (pA.z + pB.z) / 2}
                
                local valid = true
                for j, otherLine in ipairs(lines) do
                    if i ~= j then
                        local side = getSide(mid, otherLine.p1, otherLine.p2)
                        if lineValidSides[j] * side < -0.01 then
                            valid = false
                            break
                        end
                    end
                end
                
                if valid then
                    table.insert(segments, {p1 = pA, p2 = pB})
                end
            end
        end
    end
    
    if radius and radius > 0 then
        local angleStep = (2 * math.pi) / CIRCLE_SEGMENT_COUNT
        local circleSegmentsAdded = 0
        
        for i = 0, CIRCLE_SEGMENT_COUNT - 1 do
            local angle1 = i * angleStep
            local angle2 = (i + 1) * angleStep
            
            local p1 = {
                x = originX + radius * math.cos(angle1),
                z = originZ + radius * math.sin(angle1)
            }
            local p2 = {
                x = originX + radius * math.cos(angle2),
                z = originZ + radius * math.sin(angle2)
            }
            
            local midAngle = (angle1 + angle2) / 2
            local mid = {
                x = originX + radius * math.cos(midAngle),
                z = originZ + radius * math.sin(midAngle)
            }
            
            local valid = true
            if lines and #lines > 0 then
                for j, line in ipairs(lines) do
                    local side = getSide(mid, line.p1, line.p2)
                    if lineValidSides[j] * side < -0.01 then
                        valid = false
                        break
                    end
                end
            end
            
            if valid then
                table.insert(segments, {p1 = p1, p2 = p2})
                circleSegmentsAdded = circleSegmentsAdded + 1
            end
        end
    end
    
    return segments
end

return OverlapLines
