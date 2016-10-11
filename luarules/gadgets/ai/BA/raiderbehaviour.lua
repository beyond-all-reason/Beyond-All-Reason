function IsRaider(unit)
	return raiderList[unit:Internal():Name()] or false
end

RaiderBehaviour = class(Behaviour)

function RaiderBehaviour:Name()
	return "RaiderBehaviour"
end

local CMD_IDLEMODE = 145
local CMD_MOVE_STATE = 50
local MOVESTATE_HOLDPOS = 0
local MOVESTATE_MANEUVER = 1
local MOVESTATE_ROAM = 2
local IDLEMODE_LAND = 1
local IDLEMODE_FLY = 0

function RaiderBehaviour:Init()
	self.DebugEnabled = false

	self:EchoDebug("init")
	local mtype, network = self.ai.maphandler:MobilityOfUnit(self.unit:Internal())
	self.mtype = mtype
	self.name = self.unit:Internal():Name()
	local utable = unitTable[self.name]
	if self.mtype == "sub" then
		self.range = utable.submergedRange
	else
		self.range = utable.groundRange
	end
	self.groundAirSubmerged = 'ground'
	if self.mtype == 'sub' then
		self.groundAirSubmerged = 'submerged'
	elseif self.mtype == 'air' then
		self.groundAirSubmerged = 'air'
	end
	self.hurtsList = UnitWeaponLayerList(self.name)
	self.sightRange = utable.losRadius

	-- for pathfinding
	self.graph = self.ai.maphandler:GetPathGraph(self.mtype)
	self.validFunc = self.ai.raidhandler:GetPathValidFunc(self.name)
	self.modifierFunc = self.ai.targethandler:GetPathModifierFunc(self.name)
	local nodeSize = self.graph.positionUnitsPerNodeUnits
	self.nearDistance = nodeSize * 0.1 -- move this far away from path nodes
	self.nearAttackDistance = nodeSize * 0.3 -- move this far away from targets before arriving
	self.attackDistance = nodeSize * 0.6 -- move this far away from targets once arrived
	self.pathingDistance = nodeSize * 0.67 -- how far away from a node means you've arrived there
	self.minPathfinderDistance = nodeSize * 3 -- closer than this and i don't pathfind
	self.id = self.unit:Internal():ID()
	self.disarmer = raiderDisarms[self.name]
	self.ai.raiderCount[mtype] = (self.ai.raiderCount[mtype] or 0) + 1
	self.lastGetTargetFrame = 0
	self.lastMovementFrame = 0
	self.lastPathCheckFrame = 0
end

function RaiderBehaviour:OwnerDead()
	-- game:SendToConsole("raider " .. self.name .. " died")
	if self.DebugEnabled then
		self.map:EraseLine(nil, nil, nil, self.unit:Internal():ID(), nil, 8)
	end
	if self.target then
		self.ai.targethandler:AddBadPosition(self.target, self.mtype)
	end
	self.ai.raidhandler:NeedLess(self.mtype)
	self.ai.raiderCount[self.mtype] = self.ai.raiderCount[self.mtype] - 1
end

function RaiderBehaviour:OwnerIdle()
	-- does recursion, which is bad
	-- if self.active then
	-- 	self:ResumeCourse()
	-- end
end

function RaiderBehaviour:Priority()
	if self.path then
		return 100
	else
		return 0
	end
end

function RaiderBehaviour:Activate()
	self:EchoDebug("activate")
	self.active = true
	self:SetMoveState()
end

function RaiderBehaviour:Deactivate()
	self:EchoDebug("deactivate")
	self.active = false
	if self.DebugEnabled then
		self.map:EraseLine(nil, nil, nil, self.unit:Internal():ID(), nil, 8)
	end
end

function RaiderBehaviour:Update()
	local f = game:Frame()
	if self.active then
		if self.path and f > self.lastPathCheckFrame + 90 then
			self.lastPathCheckFrame = f
			self:CheckPath()
		end
		if self.moveNextUpdate then
			self.unit:Internal():Move(self.moveNextUpdate)
			self.moveNextUpdate = nil
		elseif f > self.lastMovementFrame + 30 then
			self.ai.targethandler:RaiderHere(self)
			self.lastMovementFrame = f
			-- attack nearby targets immediately
			local attackThisUnit = self:GetImmediateTargetUnit()
			if self.arrived and not attackThisUnit then
				self:GetTarget()
			end
			if attackThisUnit then
				self.offPath = true
				CustomCommand(self.unit:Internal(), CMD_ATTACK, {attackThisUnit:ID()})
			elseif self.offPath then
				self.offPath = false
				self:ResumeCourse()
			else
				self:ArrivalCheck()
				if not self.arrived then
					self:UpdatePathProgress()
				end
			end
		end
	else
		if f > self.lastGetTargetFrame + 90 then
			self.lastGetTargetFrame = f
			self:GetTarget()
		elseif not self.path and self.pathfinder then
			self:FindPath()
		end
	end
end

function RaiderBehaviour:GetImmediateTargetUnit()
	if self.arrived and self.unitTarget then
		local utpos = self.unitTarget:GetPosition()
		if utpos and utpos.x then
			return self.unitTarget
		end
	end
	local unit = self.unit:Internal()
	local position
	if self.arrived then position = self.target end
	local safeCell = self.ai.targethandler:RaidableCell(unit, position)
	if safeCell then
		if self.disarmer then
			if safeCell.disarmTarget then
				return safeCell.disarmTarget.unit
			end
		end
		local mobTargets = safeCell.targets[self.groundAirSubmerged]
		if mobTargets then
			for i = 1, #self.hurtsList do
				local groundAirSubmerged = self.hurtsList[i]
				if mobTargets[groundAirSubmerged] then
					return mobTargets[groundAirSubmerged].unit
				end
			end
		end
		local vulnerable = self.ai.targethandler:NearbyVulnerable(unit)
		if vulnerable then
			return vulnerable.unit
		end
	end
end

function RaiderBehaviour:RaidCell(cell)
	self:EchoDebug(self.name .. " raiding cell...")
	if self.unit == nil then
		self:EchoDebug("no raider unit to raid cell with!")
		-- self.ai.raidhandler:RemoveRecruit(self)
	elseif self.unit:Internal() == nil then 
		self:EchoDebug("no raider unit internal to raid cell with!")
		-- self.ai.raidhandler:RemoveRecruit(self)
	else
		if self.buildingIDs ~= nil then
			self.ai.raidhandler:IDsWeAreNotRaiding(self.buildingIDs)
		end
		self.ai.raidhandler:IDsWeAreRaiding(cell.buildingIDs, self.mtype)
		self.buildingIDs = cell.buildingIDs
		self.target = cell.pos
		self:BeginPath(self.target)
		if self.mtype == "air" then
			if self.disarmer and cell.disarmTarget then
				self.unitTarget = cell.disarmTarget.unit
			elseif cell.targets.air.ground then
				self.unitTarget = cell.targets.air.ground.unit
			end
			if self.unitTarget then
				self:EchoDebug("air raid target: " .. self.unitTarget:Name())
			end
		end
		self.unit:ElectBehaviour()
	end
end

function RaiderBehaviour:MoveNear(position, distance)
	distance = distance or self.nearDistance
	self.unit:Internal():Move(RandomAway(position, distance))
end

function RaiderBehaviour:GetTarget()
	self.target = nil
	self.unitTarget = nil
	self.pathfinder = nil
	self.path = nil
	self.pathStep = nil
	self.targetNode = nil
	self.clearShot = nil
	self.offPath = nil
	self.arrived = nil
	if self.DebugEnabled then
		self.map:EraseLine(nil, nil, nil, self.unit:Internal():ID(), nil, 8)
	end
	local unit = self.unit:Internal()
	local bestCell = self.ai.targethandler:GetBestRaidCell(unit)
	self.ai.targethandler:RaiderHere(self)
	if bestCell then
		self:EchoDebug("got target")
		self:RaidCell(bestCell)
	else
		self.unit:ElectBehaviour()
	end
end

function RaiderBehaviour:ArrivalCheck()
	if not self.target then return end
	if Distance(self.unit:Internal():GetPosition(), self.target) < self.pathingDistance then
		self:EchoDebug("arrived at target")
		self:AttackTarget(self.attackDistance)
		self.arrived = true
	end
end

-- set all raiders to roam
function RaiderBehaviour:SetMoveState()
	local thisUnit = self.unit
	if thisUnit then
		local floats = api.vectorFloat()
		floats:push_back(MOVESTATE_ROAM)
		thisUnit:Internal():ExecuteCustomCommand(CMD_MOVE_STATE, floats)
		if self.mtype == "air" then
			local floats = api.vectorFloat()
			floats:push_back(IDLEMODE_FLY)
			thisUnit:Internal():ExecuteCustomCommand(CMD_IDLEMODE, floats)
		end
	end
end

function RaiderBehaviour:BeginPath(position)
	if Distance(position, self.unit:Internal():GetPosition()) < self.minPathfinderDistance then
		self:EchoDebug("target is too close to unit to bother pathfinding, going straight to target")
		self.path = true
		self.clearShot = true
		return
	end
	self:EchoDebug("getting new path")
	local upos = self.unit:Internal():GetPosition()
	self.graph = self.graph or self.ai.maphandler:GetPathGraph(self.mtype)
	self.pathfinder = self.graph:PathfinderPosPos(upos, position, nil, self.validFunc, nil, self.modifierFunc)
	self:FindPath() -- try once
end

function RaiderBehaviour:FindPath()
	if not self.pathfinder then return end
	local path, remaining, maxInvalid = self.pathfinder:Find(2)
	-- self:EchoDebug(tostring(remaining) .. " remaining to find path")
	if path then
		self:EchoDebug("got path of", #path, "nodes", maxInvalid, "maximum invalid neighbors")
		if maxInvalid == 0 then
			self:EchoDebug("path is entirely clear of danger, not using")
			self.path = path
			self.pathStep = 1
			self.clearShot = true
		else
			self:ReceivePath(path)
		end
		self.pathfinder = nil
		self.unit:ElectBehaviour()
	elseif remaining == 0 then
		self:EchoDebug("no path found")
		self.pathfinder = nil
	end
end

function RaiderBehaviour:ReceivePath(path)
	if not path then return end
	-- if self.DebugEnabled then
	-- 	self.map:EraseLine(nil, nil, {0,0,1}, self.unit:Internal():ID(), nil, 8)
	-- 	for i = 2, #path do
	-- 		local pos1 = path[i-1].position
	-- 		local pos2 = path[i].position
	-- 		local arrow = i == #path
	-- 		self.map:DrawLine(pos1, pos2, {0,0,1}, self.unit:Internal():ID(), arrow, 8)
	-- 	end
	-- end
	-- path = SimplifyPathByAngle(path)
	self.path = path
	if not self.path[2] then
		self.pathStep = 1
	else
		self.pathStep = 2
	end
	self.targetNode = self.path[self.pathStep]
	self:ResumeCourse()
	if self.DebugEnabled then
		self.map:EraseLine(nil, nil, {0,1,1}, self.unit:Internal():ID(), nil, 8)
		for i = 2, #self.path do
			local pos1 = self.path[i-1].position
			local pos2 = self.path[i].position
			local arrow = i == #self.path
			self.map:DrawLine(pos1, pos2, {0,1,1}, self.unit:Internal():ID(), arrow, 8)
		end
	end
end

function RaiderBehaviour:UpdatePathProgress()
	if self.targetNode and not self.clearShot then
		-- have a path and it's not clear
		local myPos = self.unit:Internal():GetPosition()
		local x = myPos.x
		local z = myPos.z
		local r = self.pathingDistance
		local nx, nz = self.targetNode.position.x, self.targetNode.position.z
		if nx < x + r and nx > x - r and nz < z + r and nz > z - r and self.pathStep < #self.path then
			-- we're at the targetNode and it's not the last node
			self.pathStep = self.pathStep + 1
			self:EchoDebug("advancing to next step of path " .. self.pathStep)
			self.targetNode = self.path[self.pathStep]
			if self.pathStep == #self.path then
				self:AttackTarget()
			else
				self:MoveToNode(self.targetNode)
			end
		end
	elseif self.target then
		self:AttackTarget()
	end
end

function RaiderBehaviour:ResumeCourse()
	if not self.path then return end
	self:EchoDebug("resuming course on path")
	if self.clearShot then
		self:AttackTarget()
		return
	end
	local upos = self.unit:Internal():GetPosition()
	local lowestDist
	local nearestNode
	local nearestStep
	for i = 1, #self.path do
		local node = self.path[i]
		local dx = upos.x - node.position.x
		local dz = upos.z - node.position.z
		local distSq = dx*dx + dz*dz
		if not lowestDist or distSq < lowestDist then
			lowestDist = distSq
			nearestNode = node
			nearestStep = i
		end
	end
	if nearestNode then
		self.targetNode = nearestNode
		self.pathStep = nearestStep
		if self.pathStep == #self.path then
			self:AttackTarget()
		else
			self:MoveToNode(self.targetNode)
		end
	end
end

function RaiderBehaviour:AttackTarget(distance)
	distance = distance or self.nearAttackDistance
	if self.unitTarget ~= nil then
		local utpos = self.unitTarget:GetPosition()
		if utpos and utpos.x then
			CustomCommand(self.unit:Internal(), CMD_ATTACK, {self.unitTarget:ID()})
			return
		end
	end
	self:MoveNear(self.target, distance)
end

function RaiderBehaviour:MoveToNode(node)
	self:EchoDebug("moving to node")
	self:MoveNear(node.position)
end

function RaiderBehaviour:CheckPath()
	if not self.path then return end
	if type(self.path) == 'boolean' then return end
	for i = self.pathStep, #self.path do
		local node = self.path[i]
		if not self.ai.targethandler:IsSafePosition(node.position, self.name, 1) then
			self:EchoDebug("unsafe path, get a new one")
			self:GetTarget()
			self:MoveToSafety()
			return
		end
	end
end

function RaiderBehaviour:MoveToSafety()
	local upos = self.unit:Internal():GetPosition()
	self.graph = self.graph or self.ai.maphandler:GetPathGraph(self.mtype)
	local node = self.graph:NearestNodePosition(upos, self.validFunc)
	if node then
		self:MoveNear(node.position)
	end
end