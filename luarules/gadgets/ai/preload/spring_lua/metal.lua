local elmosPerMetal = 16
local metalmapSizeX = Game.mapSizeX / elmosPerMetal
local metalmapSizeZ = Game.mapSizeZ / elmosPerMetal
local extractorRadiusMetal = math.ceil( Game.extractorRadius / elmosPerMetal )
local maxSpotArea = math.ceil( (extractorRadiusMetal*extractorRadiusMetal) * 2 * math.pi )
local minSpotArea = math.ceil( maxSpotArea * 0.25 )
local sqRootThree = math.sqrt(3)
local halfHexHeight = math.ceil( (sqRootThree * extractorRadiusMetal) / 2 )
local halfExtractorRadiusMetal = math.ceil( extractorRadiusMetal / 2 )

Spring.Echo(metalmapSizeX, metalmapSizeZ, metalmapSizeX*metalmapSizeZ, extractorRadiusMetal, maxSpotArea, minSpotArea, halfHexHeight, halfExtractorRadiusMetal)

local mCeil = math.ceil

local spGetMetalAmount = Spring.GetMetalAmount
local spGetGroundHeight = Spring.GetGroundHeight

local isInBlob = {}
local blobs = {}
local hexes = {}
local spotsInBlob = {}

local function Flood4Metal(x, z, id)
	if x > metalmapSizeX or x < 1 or z > metalmapSizeZ or z < 1 then return end
	if isInBlob[x] and isInBlob[x][z] then return end
	local metalAmount = spGetMetalAmount(x, z)
	if metalAmount and metalAmount > 0 then
		if not isInBlob[x] then isInBlob[x] = {} end
		if not blobs[id] then blobs[id] = {} end
		blobs[id][#blobs[id]+1] = {x=x, z=z}
		isInBlob[x][z] = id
		Flood4Metal(x+1,z,id)
		Flood4Metal(x-1,z,id)
		Flood4Metal(x,z+1,id)
		Flood4Metal(x,z-1,id)
		return true
	end
end

local function Flood1Metal(x, z, id)
	if x > metalmapSizeX or x < 1 or z > metalmapSizeZ or z < 1 then return end
	if isInBlob[x] and isInBlob[x][z] then return end
	local metalAmount = spGetMetalAmount(x, z)
	if metalAmount and metalAmount > 0 then
		if not isInBlob[x] then isInBlob[x] = {} end
		if not blobs[id] then blobs[id] = {} end
		blobs[id][#blobs[id]+1] = {x=x, z=z}
		isInBlob[x][z] = id
		return true
	end
end

local function FloodBufferMetal(x, z, id)
	local buffer = { {x=x, z=z} }
	local firstokay = false
	repeat
		local newBuff = {}
		for i = 1, #buffer do
			local buff = buffer[i]
			local bx, bz = buff.x, buff.z
			if Flood1Metal(bx, bz, id) then
				firstokay = true
				newBuff[#newBuff+1] = {x=bx+1, z=bz}
				newBuff[#newBuff+1] = {x=bx-1, z=bz}
				newBuff[#newBuff+1] = {x=bx, z=bz+1}
				newBuff[#newBuff+1] = {x=bx, z=bz-1}
			end
		end
		buffer = newBuff
	until #buffer == 0
	return firstokay
end

local function CheckHorizontalLineBlob(x, z, tx, id)
	local area = 0
	for ix = x, tx do
		if isInBlob[x] and isInBlob[x][z] == id then
		-- if spGetMetalAmount(x, z) > 0 then
			area = area + 1
		end
	end
	return area
end

local function Check4Blob(cx, cz, x, z, id)
	local area = 0
	area = area + CheckHorizontalLineBlob(cx - x, cz + z, cx + x, id)
	if x ~= 0 and z ~= 0 then
        area = area + CheckHorizontalLineBlob(cx - x, cz - z, cx + x, id)
    end
    return area
end

local function CheckCircle(cx, cz, radius, id)
	local area = 0
	if radius > 0 then
		local err = -radius
		local x = radius
		local z = 0
		while x >= z do
	        local lastZ = z
	        err = err + z
	        z = z + 1
	        err = err + z
	        area = area + Check4Blob(cx, cz, x, lastZ, id)
	        if err >= 0 then
	            if x ~= lastZ then
	            	area = area + Check4Blob(cx, cz, lastZ, x, id)
	            end
	            err = err - x
	            x = x - 1
	            err = err - x
	        end
	    end
	end
	return area
end

local function FloodHexBlob(x, z, id)
	if x > metalmapSizeX or x < 1 or z > metalmapSizeZ or z < 1 then return end
	if not hexes[id] then hexes[id] = {} end
	if not hexes[id][x] then hexes[id][x] = {} end
	-- if hexes[id][x][z] or spGetMetalAmount(x,z) == 0 then return end
	if hexes[id][x][z] or not isInBlob[x] or isInBlob[x][z] ~= id then return end
	local blobArea = CheckCircle(x, z, extractorRadiusMetal, id)
	-- Spring.Echo(x, z, id, blobArea, minSpotArea)
	if blobArea > minSpotArea then
		local sx = x*elmosPerMetal
		local sz = z*elmosPerMetal
		spotsInBlob[id][#spotsInBlob[id]+1] = {x=sx, z=sz, y=spGetGroundHeight(sx,sz)}
		hexes[id][x][z] = true
		FloodHexBlob(x + extractorRadiusMetal, z, id)
		FloodHexBlob(x + halfExtractorRadiusMetal, z - halfHexHeight, id)
		FloodHexBlob(x - halfExtractorRadiusMetal, z - halfHexHeight, id)
		FloodHexBlob(x - extractorRadiusMetal, z, id)
		FloodHexBlob(x - halfExtractorRadiusMetal, z + halfHexHeight, id)
		FloodHexBlob(x + halfExtractorRadiusMetal, z + halfHexHeight, id)
		return true
	end
end

local function Flood1HexBlob(x, z, id)
	if x > metalmapSizeX or x < 1 or z > metalmapSizeZ or z < 1 then return end
	if not hexes[id] then hexes[id] = {} end
	if not hexes[id][x] then hexes[id][x] = {} end
	if hexes[id][x][z] or spGetMetalAmount(x,z) == 0 then return end
	local blobArea = CheckCircle(x, z, extractorRadiusMetal, id)
	-- Spring.Echo(x, z, id, blobArea, minSpotArea)
	if blobArea > minSpotArea then
		local sx = x*elmosPerMetal
		local sz = z*elmosPerMetal
		spotsInBlob[id][#spotsInBlob[id]+1] = {x=sx, z=sz, y=spGetGroundHeight(sx,sz)}
		hexes[id][x][z] = true
		return true
	end
end

local function FloodBufferHexBlob(x, z, id)
	local hhh = halfHexHeight
	local erm = extractorRadiusMetal
	local herm = halfExtractorRadiusMetal
	local buffer = { {x=x, z=z} }
	local firstokay = false
	repeat
		local newBuff = {}
		for i = 1, #buffer do
			local buff = buffer[i]
			local bx, bz = buff.x, buff.z
			if Flood1HexBlob(bx, bz, id) then
				firstokay = true
				newBuff[#newBuff+1] = { x = bx + extractorRadiusMetal, z = bz }
				newBuff[#newBuff+1] = { x = bx + halfExtractorRadiusMetal, z = bz - halfHexHeight }
				newBuff[#newBuff+1] = { x = bx - halfExtractorRadiusMetal, z = bz - halfHexHeight }
				newBuff[#newBuff+1] = { x = bx - extractorRadiusMetal, z = bz }
				newBuff[#newBuff+1] = { x = bx - halfExtractorRadiusMetal, z = bz + halfHexHeight }
				newBuff[#newBuff+1] = { x = bx + halfExtractorRadiusMetal, z = bz + halfHexHeight }
			end
		end
		buffer = newBuff
	until #buffer == 0
	return firstokay
end

local function CirclePack(x, z, id)
	spotsInBlob[id] = {}
	FloodBufferHexBlob(x, z, id)
	hexes[id] = nil
end

local function GetSpots()
	local id = 1
	for x = 1, metalmapSizeX do
		for z = 1, metalmapSizeZ do
			local tharBeMetal = FloodBufferMetal(x, z, id)
			if tharBeMetal then id = id + 1 end
		end
	end
	Spring.Echo(#blobs, "blobs")
	-- isInBlob = {}
	local spots = {}
	for id = 1, #blobs do
		local blob = blobs[id]
		local x, z = 0, 0
		for p = 1, #blob do
			local pixel = blob[p]
			x = x + pixel.x
			z = z + pixel.z
		end
		x = x / #blob
		z = z / #blob
		local blobArea = #blob
		blob = nil
		blobs[id] = nil
		if blobArea < maxSpotArea then
			local sx = x * elmosPerMetal
			local sz = z * elmosPerMetal
			spots[#spots+1] = {x=sx, z=sz, y=spGetGroundHeight(sx,sz)}
		else
			x = mCeil(x)
			z = mCeil(z)
			CirclePack(x, z, id)
			local blobSpots = spotsInBlob[id]
			Spring.Echo(#blobSpots, "spots in blob", id)
			for i = 1, #blobSpots do
				local spot = blobSpots[i]
				spots[#spots+1] = spot
			end
			spotsInBlob[id] = nil
		end
	end
	-- for i = 1, #spots do
	-- 	local spot = spots[i]
	-- 	if not spot.y then
	-- 		Spring.MarkerAddPoint(spot.x, spGetGroundHeight(spot.x, spot.z), spot.z, "bad")
	-- 	end
	-- end
	return spots
end

local spots = GetSpots()

return spots