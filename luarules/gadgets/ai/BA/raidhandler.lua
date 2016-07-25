andler = class(Module)

function RaidHandler:Name()
	return "RaidHandler"
end

function RaidHandler:internalName()
	return "raidhandler"
end

local mCeil = math.ceil

-- these local variables are the same for all AI teams, in fact having them the same saves memory and processing

local nodeSize = 256
local halfNodeSize = nodeSize / 2
local testSize = nodeSize / 6

local pathGraphs = {}
local pathValidFuncs = {}

function RaidHandler:Init()
	self.DebugEnabled = false

	self.counter = {}
	self.ai.raiderCount = {}
	self.ai.IDsWeAreRaiding = {}
end

function RaidHandler:NeedMore(mtype, add)
	if add == nil then add = 0.1 end
	if mtype == nil then
		for mtype, count in pairs(self.counter) do
			if self.counter[mtype] == nil then self.counter[mtype] = baseRaidCounter end
			self.counter[mtype] = self.counter[mtype] + add
			self.counter[mtype] = math.min(self.counter[mtype], maxRaidCounter)
			self:EchoDebug(mtype .. " raid counter: " .. self.counter[mtype])
		end
	else
		if self.counter[mtype] == nil then self.counter[mtype] = baseRaidCounter end
		self.counter[mtype] = self.counter[mtype] + add
		self.counter[mtype] = math.min(self.counter[mtype], maxRaidCounter)
		self:EchoDebug(mtype .. " raid counter: " .. self.counter[mtype])
	end
end

function RaidHandler:NeedLess(mtype)
	if mtype == nil then
		for mtype, count in pairs(self.counter) do
			if self.counter[mtype] == nil then self.counter[mtype] = baseRaidCounter end
			self.counter[mtype] = self.counter[mtype] - 0.5
			self.counter[mtype] = math.max(self.counter[mtype], minRaidCounter)
			self:EchoDebug(mtype .. " raid counter: " .. self.counter[mtype])
		end
	else
		if self.counter[mtype] == nil then self.counter[mtype] = baseRaidCounter end
		self.counter[mtype] = self.counter[mtype] - 0.5
		self.counter[mtype] = math.max(self.counter[mtype], minRaidCounter)
		self:EchoDebug(mtype .. " raid counter: " .. self.counter[mtype])
	end
end

function RaidHandler:GetCounter(mtype)
	if mtype == nil then
		local highestCounter = 0
		for mtype, counter in pairs(self.counter) do
			if counter > highestCounter then highestCounter = counter end
		end
		return highestCounter
	end
	if self.counter[mtype] == nil then
		return baseRaidCounter
	else
		return self.counter[mtype]
	end
end

function RaidHandler:IDsWeAreRaiding(unitIDs, mtype)
	for i, unitID in pairs(unitIDs) do
		self.ai.IDsWeAreRaiding[unitID] = mtype
	end
end

function RaidHandler:IDsWeAreNotRaiding(unitIDs)
	for i, unitID in pairs(unitIDs) do
		self.ai.IDsWeAreRaiding[unitID] = nil
	end
end

function RaidHandler:TargetDied(mtype)
	self:EchoDebug("target died")
	self:NeedMore(mtype, 0.35)
end

function RaidHandler:GetPathGraph(mtype)
	if pathGraphs[mtype] then
		return pathGraphs[mtype]
	end
	local graph = {}
	local id = 1
	local sizeX = self.ai.elmoMapSizeX
	local sizeZ = self.ai.elmoMapSizeZ
	local maphand = self.ai.maphandler
	for cx = 0, sizeX-nodeSize, nodeSize do
		local x = cx + halfNodeSize
		for cz = 0, sizeZ-nodeSize, nodeSize do
			local z = cz + halfNodeSize
			local canGo = true
			for tx = cx, cx+nodeSize, testSize do
				for tz = cz, cz+nodeSize, testSize do
					if not maphand:MobilityNetworkHere(mtype, {x=tx, z=tz}) then
						canGo = false
						break
					end
				end
				if not canGo then break end
			end
			if canGo then
				local position = api.Position()
				position.x = x
				position.z = z
				position.y = 0
				if ShardSpringLua then
					position.y = Spring.GetGroundHeight(x, z)
				end
				local node = { x = x, y = z, id = id, position = position }
				graph[id] = node
				id = id + 1
			end
		end
	end
	local aGraph = GraphAStar()
	aGraph:Init(graph)
	aGraph:SetOctoGridSize(nodeSize)
	pathGraphs[mtype] = aGraph
	return aGraph
end

function RaidHandler:GetPathValidFunc(unitName)
	if pathValidFuncs[unitName] then
		return pathValidFuncs[unitName]
	end
	local valid_node_func = function ( node )
		return ai.targethandler:IsSafePosition({x=node.x, z=node.y}, unitName, 1)
	end
	pathValidFuncs[unitName] = valid_node_func
	return valid_node_func
end

function RaidHandler:GetPathNodeSize()
	return nodeSize
end