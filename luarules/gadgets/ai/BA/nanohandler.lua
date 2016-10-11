NanoHandler = class(Module)

function NanoHandler:Name()
	return "NanoHandler"
end

function NanoHandler:internalName()
	return "nanohandler"
end

local tInsert = table.insert

local cellSize = 100
local halfCellSize = cellSize / 2
local hotBuildRadius = math.floor(math.sqrt(halfCellSize * halfCellSize * 2))

function NanoHandler:Init()
	self.DebugEnabled = false
	self.densityMap = {}
end

function NanoHandler:UnitBuilt(engineUnit)
	local ut = unitTable[engineUnit:Name()]
	if not ut then return end
	if nanoTurretList[engineUnit:Name()] then
		self:AddNano(engineUnit)
	end
end

function NanoHandler:UnitDead(engineUnit)
	local ut = unitTable[engineUnit:Name()]
	if not ut then return end
	if nanoTurretList[engineUnit:Name()] then
		self:RemoveNano(engineUnit)
	end
end

function NanoHandler:DrawDebug()
	if not self.DebugEnabled then return end
	self.map:EraseAll(2)
	local highestCount = 0
	for cx, czz in pairs(self.densityMap) do
		for cz, count in pairs(czz) do
			if count > highestCount then
				highestCount = count
			end
		end
	end
	for cx, czz in pairs(self.densityMap) do
		for cz, count in pairs(czz) do
			local x = cx * cellSize
			local z = cz * cellSize
			local cellPosMin = api.Position()
			cellPosMin.x = x - cellSize
			cellPosMin.z = z - cellSize
			local cellPosMax = api.Position()
			cellPosMax.x = x
			cellPosMax.z = z
			local green = count / highestCount
			local blue = 1 - green
			self.map:DrawRectangle(cellPosMin, cellPosMax, {0,green,blue}, count, true, 2)
		end
	end
end

function NanoHandler:AddNano(engineUnit)
	self.densityMap = FillCircle(self.densityMap, cellSize, engineUnit:GetPosition(), 400, nil, 1)
	self.cellsNeedSorting = true
	self:DrawDebug()
end

function NanoHandler:RemoveNano(engineUnit)
	self.densityMap = FillCircle(self.densityMap, cellSize, engineUnit:GetPosition(), 400, nil, -1)
	self.cellsNeedSorting = true
	self:DrawDebug()
end

function NanoHandler:SortCells()
	if not self.cellsNeedSorting then return end
	local posByCounts = {}
	for cx, czz in pairs(self.densityMap) do
		for cz, count in pairs(czz) do
			if count > 1 then
				local cellPos = api.Position()
				cellPos.x = (cx * cellSize) - halfCellSize
				cellPos.z = (cz * cellSize) - halfCellSize
				posByCounts[-count] = posByCounts[-count] or {}
				tInsert(posByCounts[-count], cellPos)
			end
		end
	end
	self.sortedCells = {}
	for negCount, posList in pairsByKeys(posByCounts) do
		for i = 1, #posList do
			local position = posList[i]
			self:EchoDebug(-negCount, "nanos", "overlap at", position.x, position.z)
			self.sortedCells[#self.sortedCells+1] = position
		end
	end
	self.cellsNeedSorting = false
end

function NanoHandler:GetHotSpots()
	self:SortCells()
	return self.sortedCells
end

function NanoHandler:HotBuildRadius()
	self:EchoDebug("hotBuildRadius", hotBuildRadius)
	return hotBuildRadius
end