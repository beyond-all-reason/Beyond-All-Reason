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

return OverlapLines
