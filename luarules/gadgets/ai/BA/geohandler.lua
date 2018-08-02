GeoSpotHandler = class(Module)


function GeoSpotHandler:Name()
	return "GeoSpotHandler"
end

function GeoSpotHandler:internalName()
	return "geospothandler"
end

function GeoSpotHandler:Init()
	self.geos = self.game.map:GetGeoSpots()
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

function GeoSpotHandler:ClosestFreeGeo(unittype,position, maxdis)
	local pos = nil
	local bestDistance = maxdis or 10000
	geoCount = self.game.map:GeoCount()
	for i,v in ipairs(self.geos) do
		local p = v
		local dist = distance(position,p)
		if dist < bestDistance then
			if self.game.map:CanBuildHere(unittype,p) then
				--checking for unit positions
				local spGetUnitsInRectangle = Spring.GetUnitsInRectangle
				local radius = 100
				local units_found = spGetUnitsInRectangle(p.x - radius, p.z - radius, p.x + radius, p.z + radius)
				if #units_found == 0 then
					bestDistance = dist
					pos = p
				end					
			end
		end
	end
	return pos
end
