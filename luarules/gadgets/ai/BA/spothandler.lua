MetalSpotHandler = class(Module)


function MetalSpotHandler:Name()
	return "MetalSpotHandler"
end

function MetalSpotHandler:internalName()
	return "metalspothandler"
end

function MetalSpotHandler:Init()
	self.spots = self.game.map:GetMetalSpots()
end

function distance(pos1,pos2)
	local xd = pos1.x-pos2.x
	local zd = pos1.z-pos2.z
	local yd = pos1.y-pos2.y
	if yd < 0 then
		yd = -yd
	end
	dist = math.sqrt(xd*xd + zd*zd + yd*yd*yd)
	return dist
end

function MetalSpotHandler:ClosestFreeSpot(unittype,position)
    local pos = nil
    local bestDistance = 10000

    spotCount = self.game.map:SpotCount()
    for i,v in ipairs(self.spots) do
        local p = v
        local dist = distance(position,p)
        if dist < bestDistance then
                --checking for unit positions
                local spGetUnitsInRectangle = Spring.GetUnitsInRectangle
                local radius = extractorRadius + 32
                local units_found = spGetUnitsInCylinder(p.x, p.z, radius)
                if #units_found == 0 then
                    bestDistance = dist
                    pos = p
                elseif #units_found > 1 then
                    for ct, id in pairs(units_found) do
                        if UnitDefs[Spring.GetUnitDefID(id)].extractsMetal >= UnitDefs[unittype.id].extractsMetal then
                            break
						end
						if ct == #units_found then
                            bestDistance = dist
                            pos = p
						end
                        end
                    end
                end
        end
    return pos
end
		end
	end
	return pos
end
