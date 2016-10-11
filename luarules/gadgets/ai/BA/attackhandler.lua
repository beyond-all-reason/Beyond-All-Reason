AttackHandler = class(Module)

function AttackHandler:Name()
	return "AttackHandler"
end

function AttackHandler:internalName()
	return "attackhandler"
end

local floor = math.floor
local ceil = math.ceil

function AttackHandler:Init()
	self.DebugEnabled = false

	self.recruits = {}
	self.count = {}
	self.squads = {}
	self.counter = {}
	self.attackSent = {}
	self.attackCountReached = {}
	self.potentialAttackCounted = {}
	self.ai.hasAttacked = 0
	self.ai.couldAttack = 0
	self.ai.IDsWeAreAttacking = {}
end

function AttackHandler:Update()
	local f = game:Frame()
	if f % 150 == 0 then
		self:DraftSquads()
	end
	if #self.squads > 0 then
		for is = 1, #self.squads do
			local squad = self.squads[is]
			if not squad.arrived and squad.idleTimeout and f >= squad.idleTimeout then
				squad.arrived = true
				squad.idleTimeout = nil
			end
			if squad.arrived then
				squad.arrived = nil
				if squad.pathStep < #squad.path - 1 then
					local value = self.ai.targethandler:ValueHere(squad.target, squad.members[1].name)
					local threat = self.ai.targethandler:ThreatHere(squad.target, squad.members[1].name)
					if (value == 0 and threat == 0) or threat > squad.totalThreat * 0.67 then
						self:SquadReTarget(squad) -- get a new target, this one isn't valuable
					else
						self:SquadNewPath(squad) -- see if there's a better way from the point we're going to
					end
				end
				self:SquadAdvance(squad)
			end
		end
		local is = (self.lastSquadPathfind or 0) + 1
		if is > #self.squads then is = 1 end
		local squad = self.squads[is]
		self:SquadPathfind(squad, is)
		self.lastSquadPathfind = is
	end
end

function AttackHandler:DraftSquads()
	-- if self.ai.incomingThreat > 0 then game:SendToConsole(self.ai.incomingThreat .. " " .. (self.ai.battleCount + self.ai.breakthroughCount) * 75) end
	-- if self.ai.incomingThreat > (self.ai.battleCount + self.ai.breakthroughCount) * 75 then
		-- do not attack if we're in trouble
		-- self:EchoDebug("not a good time to attack " .. tostring(self.ai.battleCount+self.ai.breakthroughCount) .. " " .. self.ai.incomingThreat .. " > " .. tostring((self.ai.battleCount+self.ai.breakthroughCount)*75))
		-- return
	-- end
	local needtarget = {}
	local f = game:Frame()
	-- find which mtypes need targets
	for mtype, count in pairs(self.count) do
		if (f > (self.attackCountReached[mtype] or 0) + 150 or f > (self.attackSent[mtype] or 0) + 1200) and count >= self.counter[mtype] then
			self:EchoDebug(mtype, "needs target with", count, "units of", self.counter[mtype], "needed")
			self.attackCountReached[mtype] = f
			table.insert(needtarget, mtype)
		end
	end
	for nothing, mtype in pairs(needtarget) do
		-- prepare a squad
		local squad = { members = {}, mtype = mtype }
		local representative, representativeBehaviour
		self:EchoDebug(mtype, #self.recruits[mtype], "recruits")
		for _, attkbhvr in pairs(self.recruits[mtype]) do
			if attkbhvr ~= nil then
				if attkbhvr.unit ~= nil then
					representativeBehaviour = representativeBehaviour or attkbhvr
					representative = representative or attkbhvr.unit:Internal()
					table.insert(squad.members, attkbhvr)
					attkbhvr.squad = squad
				end
			end
		end
		if representative ~= nil then
			self:EchoDebug(mtype, "has representative")
			if not self.potentialAttackCounted[mtype] then
				-- only count once per attack
				self.ai.couldAttack = self.ai.couldAttack + 1
				self.potentialAttackCounted[mtype] = true
			end
			-- don't actually draft the squad unless there's something to attack
			local bestCell = self.ai.targethandler:GetNearestAttackCell(representative) or self.ai.targethandler:GetBestAttackCell(representative)
			if bestCell ~= nil then
				self:EchoDebug(mtype, "has target, recruiting squad...")
				squad.target = bestCell.pos
				self:IDsWeAreAttacking(bestCell.buildingIDs, squad.mtype)
				squad.buildingIDs = bestCell.buildingIDs
				self.attackSent[mtype] = f
				table.insert(self.squads, squad)
				self:SquadFormation(squad)
				self:SquadNewPath(squad, representativeBehaviour)
				-- clear recruits
				self.count[mtype] = 0
				self.recruits[mtype] = {}
				self.ai.hasAttacked = self.ai.hasAttacked + 1
				self.potentialAttackCounted[mtype] = false
				self.counter[mtype] = math.min(maxAttackCounter, self.counter[mtype] + 1)
			end
		end
	end
end

function AttackHandler:SquadReTarget(squad, squadIndex)
	local f = game:Frame()
	local representativeBehaviour
	local representative
	for iu, member in pairs(squad.members) do
		if member ~= nil then
			if member.unit ~= nil then
				representativeBehaviour = member
				representative = member.unit:Internal()
				if representative ~= nil then
					break
				end
			end
		end
	end
	if squad.buildingIDs ~= nil then
		self:IDsWeAreNotAttacking(squad.buildingIDs)
	end
	if representative == nil then
		self:SquadDisband(squad)
	else
		-- find a target
		local position
		if squad.pathStep then
			local step = math.min(squad.pathStep+1, #squad.path)
			position = squad.path[step].position
		end
		local bestCell = self.ai.targethandler:GetNearestAttackCell(representative, position, squad.totalThreat) or self.ai.targethandler:GetBestAttackCell(representative, position, squad.totalThreat)
		if bestCell then
			squad.target = bestCell.pos
			self:IDsWeAreAttacking(bestCell.buildingIDs, squad.mtype)
			squad.buildingIDs = bestCell.buildingIDs
			squad.reachedTarget = nil
			self:SquadNewPath(squad, representativeBehaviour)
		else
			self:EchoDebug("no target found on retarget")
			self:SquadDisband(squad, squadIndex)
		end
	end
end

function AttackHandler:SquadDisband(squad, squadIndex)
	self:EchoDebug("disband squad")
	squad.disbanding = true
	for iu, member in pairs(squad.members) do
		self:AddRecruit(member)
	end
	self.attackSent[squad.mtype] = 0
	if not squadIndex then
		for is, sq in pairs(self.squads) do
			if sq == squad then
				squadIndex = is
				break
			end
		end
	end
	table.remove(self.squads, squadIndex)
end

function AttackHandler:SquadFormation(squad)
	local members = squad.members
	local maxMemberSize
	local lowestSpeed
	local totalThreat = 0
	for i = 1, #members do
		local member = members[i]
		if not maxMemberSize or member.congSize > maxMemberSize then
			maxMemberSize = member.congSize
		end
		if not lowestSpeed or member.speed < lowestSpeed then
			lowestSpeed = member.speed
		end
		totalThreat = totalThreat + member.threat
	end
	local backDist = maxMemberSize * 3
	local backs = {}
	local forwards = {}
	for i = 1, #members do
		local member = members[i]
		if member.sturdy then
			forwards[#forwards+1] = member
		else
			backs[#backs+1] = member
			member.formationBack = backDist
		end
	end
	local half = floor(#forwards / 2)
	local anglePerMember = halfPi / #forwards
	for i = 1, #forwards do
		local member = forwards[i]
		member.formationDist = (half - i) * maxMemberSize
		member.formationAngle = (i - half) * anglePerMember
	end
	half = floor(#backs / 2)
	anglePerMember = #backs / halfPi
	for i = 1, #backs do
		local member = backs[i]
		member.formationDist = (half - i) * maxMemberSize
		member.formationAngle = (i - half) * anglePerMember
	end
	squad.lowestSpeed = lowestSpeed
	squad.totalThreat = totalThreat
end

function AttackHandler:SquadNewPath(squad, representativeBehaviour)
	if not squad.target then return end
	representativeBehaviour = representativeBehaviour or squad.members[#squad.members]
	local representative = representativeBehaviour.unit:Internal()
	if self.DebugEnabled then
		self.map:EraseLine(nil, nil, {1,1,0}, squad.mtype, nil, 8)
	end
	local startPos
	if squad.pathStep then
		local step = math.min(squad.pathStep+1, #squad.path)
		startPos = squad.path[step].position
	elseif not squad.hasGottenPathOnce then
		startPos = self.ai.frontPosition[representativeBehaviour.hits]
		if startPos then
			local angle = AnglePosPos(startPos, squad.target)
			startPos = RandomAway(startPos, 150, nil, angle)
		else
			startPos = representative:GetPosition()
		end
	else
		startPos = representative:GetPosition()
	end
	squad.modifierFunc = squad.modifierFunc or self.ai.targethandler:GetPathModifierFunc(representative:Name(), true)
	if ShardSpringLua then
		local targetModFunc = self.ai.targethandler:GetPathModifierFunc(representative:Name(), true)
		local startHeight = Spring.GetGroundHeight(startPos.x, startPos.z)
		squad.modifierFunc = function(node, distanceToGoal, distanceStartToGoal)
			local hMod = math.max(0, Spring.GetGroundHeight(node.position.x, node.position.z) - startHeight) / 100
			if distanceToGoal then
				local dMod = math.min(1, (distanceToGoal - 500) / 500)
				return targetModFunc(node, distanceToGoal, distanceStartToGoal) + (dMod * hMod)
			else
				return targetModFunc(node, distanceToGoal, distanceStartToGoal) + hMod
			end
		end
	end
	squad.graph = squad.graph or self.ai.maphandler:GetPathGraph(squad.mtype)
	squad.pathfinder = squad.graph:PathfinderPosPos(startPos, squad.target, nil, nil, nil, squad.modifierFunc)
end

function AttackHandler:SquadPathfind(squad, squadIndex)
	if not squad.pathfinder then return end
	local path, remaining, maxInvalid = squad.pathfinder:Find(2)
	if path then
		-- path = SimplifyPath(path)
		squad.path = path
		squad.pathStep = 1
		squad.targetNode = squad.path[1]
		squad.hasMovedOnce = nil
		squad.pathfinder = nil
		squad.hasGottenPathOnce = true
		self:SquadAdvance(squad)
		if self.DebugEnabled then
			self.map:EraseLine(nil, nil, {1,1,0}, squad.mtype, nil, 8)
			for i = 2, #path do
				local pos1 = path[i-1].position
				local pos2 = path[i].position
				local arrow = i == #path
				self.map:DrawLine(pos1, pos2, {1,1,0}, squad.mtype, arrow, 8)
			end
		end
	elseif remaining == 0 then
		squad.pathfinder = nil
		self:SquadReTarget(squad, squadIndex)
	end
end

function AttackHandler:MemberIdle(attkbhvr, squad)
	if attkbhvr then
		squad = attkbhvr.squad
		if not squad then return end
		squad.idleCount = (squad.idleCount or 0) + 1
		-- self:EchoDebug(squad.idleCount)
	end
	if not squad.arrived and squad.pathStep and squad.idleCount > floor(#squad.members * 0.85) then
		squad.arrived = true
	end
end

function AttackHandler:SquadAdvance(squad)
	self:EchoDebug("advance")
	squad.idleCount = 0
	if squad.pathStep == #squad.path then
		self:SquadReTarget(squad)
		return
	end
	if squad.hasMovedOnce then
		squad.pathStep = squad.pathStep + 1
		squad.targetNode = squad.path[squad.pathStep]
	end
	local members = squad.members
	local nextPos
	local nextAngle
	if squad.pathStep == #squad.path then
		nextPos = squad.target
		nextAngle = AnglePosPos(squad.path[squad.pathStep-1].position, nextPos)
	else
		nextPos = squad.targetNode.position
		nextAngle = AnglePosPos(nextPos, squad.path[squad.pathStep+1].position)
	end
	local nextPerpendicularAngle = AngleAdd(nextAngle, halfPi)
	squad.lastValidMove = nextPos -- attackers use this to correct bad move orders
	for i = #members, 1, -1 do
		local member = members[i]
		local pos = nextPos
		if member.formationBack and squad.pathStep ~= #squad.path then
			pos = RandomAway(nextPos, -member.formationBack, nil, nextAngle)
		end
		local reverseAttackAngle
		if squad.pathStep == #squad.path then
			reverseAttackAngle = AngleAdd(nextAngle, pi)
		end
		member:Advance(pos, nextPerpendicularAngle, reverseAttackAngle)
	end
	if squad.hasMovedOnce then
		local distToNext = Distance(squad.path[squad.pathStep-1].position, nextPos)
		squad.idleTimeout = game:Frame() + (3 * 30 * (distToNext / squad.lowestSpeed))
	end
	squad.hasMovedOnce = true
end

function AttackHandler:IDsWeAreAttacking(unitIDs, mtype)
	for i, unitID in pairs(unitIDs) do
		self.ai.IDsWeAreAttacking[unitID] = mtype
	end
end

function AttackHandler:IDsWeAreNotAttacking(unitIDs)
	for i, unitID in pairs(unitIDs) do
		self.ai.IDsWeAreAttacking[unitID] = nil
	end
end

function AttackHandler:TargetDied(mtype)
	self:EchoDebug("target died")
	self:NeedLess(mtype, 0.75)
end

function AttackHandler:RemoveMember(attkbhvr)
	if attkbhvr == nil then return end
	if not attkbhvr.squad then return end
	local squad = attkbhvr.squad
	for iu = #squad.members, 1, -1 do
		local member = squad.members[iu]
		if member == attkbhvr then
			table.remove(squad.members, iu)
			if #squad.members == 0 then
				self:SquadDisband(squad)
			else
				self:SquadFormation(squad)
				self:MemberIdle(nil, squad)
			end
			attkbhvr.squad = nil
			return true
		end
	end
end

function AttackHandler:IsRecruit(attkbhvr)
	if attkbhvr.unit == nil then return false end
	local mtype = self.ai.maphandler:MobilityOfUnit(attkbhvr.unit:Internal())
	if self.recruits[mtype] ~= nil then
		for i,v in pairs(self.recruits[mtype]) do
			if v == attkbhvr then
				return true
			end
		end
	end
	return false
end

function AttackHandler:AddRecruit(attkbhvr)
	if not self:IsRecruit(attkbhvr) then
		if attkbhvr.unit ~= nil then
			-- self:EchoDebug("adding attack recruit")
			local mtype = self.ai.maphandler:MobilityOfUnit(attkbhvr.unit:Internal())
			if self.recruits[mtype] == nil then self.recruits[mtype] = {} end
			if self.counter[mtype] == nil then self.counter[mtype] = baseAttackCounter end
			if self.attackSent[mtype] == nil then self.attackSent[mtype] = 0 end
			if self.count[mtype] == nil then self.count[mtype] = 0 end
			local level = attkbhvr.level
			self.count[mtype] = self.count[mtype] + level
			table.insert(self.recruits[mtype], attkbhvr)
			attkbhvr:SetMoveState()
			attkbhvr:Free()
		else
			self:EchoDebug("unit is nil!")
		end
	end
end

function AttackHandler:RemoveRecruit(attkbhvr)
	for mtype, recruits in pairs(self.recruits) do
		for i,v in ipairs(recruits) do
			if v == attkbhvr then
				local level = attkbhvr.level
				self.count[mtype] = self.count[mtype] - level
				table.remove(self.recruits[mtype], i)
				return true
			end
		end
	end
	return false
end

function AttackHandler:NeedMore(attkbhvr)
	local mtype = attkbhvr.mtype
	local level = attkbhvr.level
	self.counter[mtype] = math.min(maxAttackCounter, self.counter[mtype] + (level * 0.7) ) -- 0.75
	self:EchoDebug(mtype .. " attack counter: " .. self.counter[mtype])
end

function AttackHandler:NeedLess(mtype, subtract)
	if subtract == nil then subtract = 0.1 end
	if mtype == nil then
		for mtype, count in pairs(self.counter) do
			if self.counter[mtype] == nil then self.counter[mtype] = baseAttackCounter end
			self.counter[mtype] = math.max(self.counter[mtype] - subtract, minAttackCounter)
			self:EchoDebug(mtype .. " attack counter: " .. self.counter[mtype])
		end
	else
		if self.counter[mtype] == nil then self.counter[mtype] = baseAttackCounter end
		self.counter[mtype] = math.max(self.counter[mtype] - subtract, minAttackCounter)
		self:EchoDebug(mtype .. " attack counter: " .. self.counter[mtype])
	end
end

function AttackHandler:GetCounter(mtype)
	if mtype == nil then
		local highestCounter = 0
		for mtype, counter in pairs(self.counter) do
			if counter > highestCounter then highestCounter = counter end
		end
		return highestCounter
	end
	if self.counter[mtype] == nil then
		return baseAttackCounter
	else
		return self.counter[mtype]
	end
end