-- Author: Beherith (mysterme@gmail.com)

-- A quick rundown on what this algorithm does
-- It takes the map and splits it up into resolution sized squares
-- Then for each square, it will lazily initialize a list of all other map squares
-- and sorts those in order of distance from the current square
-- To get then Nth closest other square from the current position, simply call:
-- HashPosTable:GetNthCenter(x,z,N)



local function MakeHashedPosTable(resolution)
	-- hashes into 1000*z + x
	resolution = resolution or 512
	local mx = Game and Game.mapSizeX or 8192
	local mz = Game and Game.mapSizeZ or 8192

	local HashPos = {
		resolution = resolution,
		mx = mx,
		mz = mz,
		numPos = mx*mz/(resolution*resolution)
	}
	function HashPos:hashPos(px,pz)
		return math.floor(pz/self.resolution) * 1000 + math.floor(px/self.resolution)
	end

	-- return x,y
	function HashPos:unhash(h)
		local z = math.floor(h/1000)
		return h - 1000*z, z
	end
	function HashPos:hashtopos(h)
		local z = math.floor(h/1000)
		local cx = (h - 1000*z) * self.resolution + self.resolution/2
		local cz = z*self.resolution + self.resolution/2
		return cx,cz
	end

	function HashPos:distancesqr(hp1, hp2)
		local x1, z1 = self:unhash(hp1)
		local x2, z2 = self:unhash(hp2)
		x1 = x1 - x2
		z1 = z1 - z2
		return x1*x1 + z1*z1
	end
	local hashIDs = {}

	for x=1, mx, resolution do
		for z = 1, mz, resolution do
			local hp = HashPos:hashPos(x,z)
			hashIDs[#hashIDs+1] = hp
		end
	end
	HashPos.hashIDs = hashIDs
	-- returns the center of the Nth closest tile

	HashPos.sortedPositions = {}
	local sortedRegions = {}

	function HashPos:SortNewRegion(hp)
		local thispos = {}
		for j,hp2 in ipairs(hashIDs) do
			thispos[j] = hp2
		end
		local function comparetome(a,b)
			return HashPos:distancesqr(hp,a) < HashPos:distancesqr(hp,b)
		end
		table.sort(thispos, comparetome)
		self.sortedPositions[hp] = thispos
	end

	function HashPos:GetNthCenter(px,pz, n)
		local hp = self:hashPos(px,pz)
		local sorted = self.sortedPositions[hp]
		if sorted == nil then
			self:SortNewRegion(hp)
			sorted = self.sortedPositions[hp]
		end
		n = math.clamp(n, 1, #sorted)
		local hpn = sorted[n]
		return self:hashtopos(hpn)
	end

	return HashPos
end

-- Look a unit test!
--[[
local Game = {mapSizeX = 16384, mapSizeZ = 8192}
local hpt = MakeHashedPosTable(512)
for i = 1, 50 do
	print (hpt:GetNthCenter(256,4000, i))
end
]]--

return MakeHashedPosTable
