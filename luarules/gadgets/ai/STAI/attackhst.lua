AttackHST = class(Module)

function AttackHST:Name()
	return "AttackHST"
end

function AttackHST:internalName()
	return "attackhst"
end

local floor = math.floor
local ceil = math.ceil

function AttackHST:Init()
	self.DebugEnabled = false
	self.visualdbg = true
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
	self.minAttackCounter = 4
	self.maxAttackCounter = 12
	self.baseAttackCounter = 8
	self.idleTimeMult = 45  --originally set to 3 * 30
	self.squadID = 1
end

function AttackHST:Update()
	local f = self.game:Frame()
	if f % 17 ~= 0 then
		return
	end
	self:DraftSquads()
	for index , squad in pairs(self.squads) do
		self:visualDBG(squad)
		if not squad.arrived and squad.idleTimeout and f >= squad.idleTimeout then
			squad.arrived = true
			squad.idleTimeout = nil
		end
		if squad.arrived then
			squad.arrived = nil
			if squad.pathStep < #squad.path - 1 then
				local value = self.ai.targethst:ValueHere(squad.targetPos, squad.members[1].name)
				local threat = self.ai.targethst:ThreatHere(squad.targetPos, squad.members[1].name)
				if (value == 0 and threat == 0) or threat > squad.totalThreat * 0.67 then
					self:SquadReTarget(squad) -- get a new target, this one isn't valuable
				else
					self:SquadNewPath(squad) -- see if there's a better way from the point we're going to
				end
			end
			self:SquadAdvance(squad)
		end
	end
	if not self.squads or #self.squads < 1 then--TEST how to a squad is deleted during update?
		return
	end
	local index = (self.lastSquadPathfind or 0) + 1
	if index > #self.squads then index = 1 end
	local squad = self.squads[index]
	self:EchoDebug(index,self.squads[index],#self.squads)
	self:SquadPathfind(squad, index)
	self.lastSquadPathfind = index
end

function AttackHST:visualDBG(squad)
	if not self.visualdbg  then
		return
	end
	self.map:EraseAll(6)
	for i,member in pairs(squad.members) do
		member.unit:Internal():EraseHighlight(nil, nil, 6 )
		member.unit:Internal():DrawHighlight(squad.colour ,nil , 6 )
	end
	if squad.path then
		for i , p in pairs(squad.path) do
			self.map:DrawPoint(p.position, squad.colour, i, 6)
		end
	end
	if squad.targetPos then
		self.map:DrawCircle(squad.targetPos,100, squad.colour, 'target ',true, 6)
	end
end

function AttackHST:DraftSquads()
	-- if self.ai.incomingThreat > 0 then game:SendToConsole(self.ai.incomingThreat .. " " .. (self.ai.tool:countMyUnit({'battles'}) + self.ai.tool:countMyUnit({'breaks'})) * 75) end
	-- if self.ai.incomingThreat > (self.ai.tool:countMyUnit({'battles'}) + self.ai.tool:countMyUnit({'breaks'})) * 75 then
	-- do not attack if we're in trouble
	-- self:EchoDebug("not a good time to attack " .. tostring(self.ai.tool:countMyUnit({'battles'}) + self.ai.tool:countMyUnit({'breaks'})) .. " " .. self.ai.incomingThreat .. " > " .. tostring((self.ai.tool:countMyUnit({'battles'}) + self.ai.tool:countMyUnit({'breaks'}))*75))
	-- return
	-- end
	local needtarget = {}
	local f = self.game:Frame()
	-- find which mtypes need targets
	for mtype, count in pairs(self.count) do
		if (f > (self.attackCountReached[mtype] or 0) + 150 or f > (self.attackSent[mtype] or 0) + 1200) and count >= self.counter[mtype] then
			self:EchoDebug(mtype, "needs target with", count, "units of", self.counter[mtype], "needed")
			self.attackCountReached[mtype] = f
			table.insert(needtarget, mtype)
		end
	end
	for index, mtype in pairs(needtarget) do
		-- prepare a squad
		local squad = { members = {}, mtype = mtype }
		local representative, representativeBehaviour
		self:EchoDebug(mtype, #self.recruits[mtype], "recruits")
		for i, attkbhvr in pairs(self.recruits[mtype]) do
			if attkbhvr and attkbhvr.unit then
				representativeBehaviour = representativeBehaviour or attkbhvr
				representative = representative or attkbhvr.unit:Internal()
				table.insert(squad.members, attkbhvr)
				attkbhvr.squad = squad
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
			local bestCell = self.ai.targethst:GetBestAttackCell(representative) or self.ai.targethst:GetNearestAttackCell(representative)
			if bestCell ~= nil then
				self:EchoDebug(mtype, "has target, recruiting squad...")
				squad.targetCell = bestCell
				squad.targetPos = bestCell.pos
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
				self.counter[mtype] = math.min(self.maxAttackCounter, self.counter[mtype] + 1)
				squad.colour = {0,math.random(),math.random(),1}
			end
		end
	end
end


function AttackHST:SquadReTarget(squad, squadIndex)
	local f = self.game:Frame()
	local representativeBehaviour
	local representative
	for iu, member in pairs(squad.members) do
		if member and member.unit then
			representativeBehaviour = member
			representative = member.unit:Internal()
			if representative ~= nil then
				break
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
		local bestCell =  self:targetCell(representative, position, squad.totalThreat) or self.ai.targethst:GetNearestAttackCell(representative, position, squad.totalThreat) or self.ai.targethst:GetBestAttackCell(representative, position, squad.totalThreat)
		if bestCell then
			squad.targetPos = bestCell.pos
			squad.targetCell = bestCell
			self.attackSent[squad.mtype] = f
			self:IDsWeAreAttacking(bestCell.buildingIDs, squad.mtype)
			squad.buildingIDs = bestCell.buildingIDs
			squad.reachedTarget = nil
			self:SquadFormation(squad)
			self:SquadNewPath(squad, representativeBehaviour)
		else
			self:EchoDebug("no target found on retarget")
			self:SquadDisband(squad, squadIndex)
		end
	end
end

function AttackHST:targetCell(representative, position, ourThreat)
	if not representative then return end
	position = position or representative:GetPosition()
	local aName = representative:Name()
	local targets = {}
	local maxdist = 0
	for i, cell in pairs(self.ai.targethst.cellList) do
		for squadIndex,squad in pairs(self.squads) do
			if squad.targetCell == cell or not cell.pos then return end
		end
		if self.ai.maphst:UnitCanGoHere(representative, cell.pos) then
			local value, threat = self.ai.targethst:CellValueThreat(aName, cell)

			if value > 50 then
				local dist = self.ai.tool:Distance(position, cell.pos)

				local rank =  value - threat
				maxdist = math.max(dist,maxdist)
				table.insert(targets, { cell = cell, value = value, threat = threat, dist = dist ,rank = rank})
				self.map:DrawCircle(cell.pos,100, {0,1,0,1}, value,true, 6)
				self:EchoDebug('is possible attack',cell.pos.x,cell.pos.z,value,threat,dist,rank)
			end
		end

	end
	local TG = nil
	local distancedtarget = 0
	for i, target in pairs(targets) do
		if (1 - (target.dist / maxdist)) * target.rank > distancedtarget then
			TG = target
			distancedtarget = (1 - (target.dist / maxdist)) * target.rank
		end
	end
	if TG then
		self.lastAttackCell = TG.cell
		return TG.cell
	end
	self:EchoDebug('no target found for attackhst')
end

function AttackHST:SquadDisband(squad, squadIndex)
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

function AttackHST:SquadFormation(squad)
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
	local backsCount = 0
	local forwards = {}
	local forwardsCount = 0
	for i = 1, #members do
		local member = members[i]
		if member.sturdy then
			forwardsCount = forwardsCount + 1
			forwards[forwardsCount] = member
		else
			backsCount = backsCount + 1
			backs[backsCount] = member
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

function AttackHST:SquadNewPath(squad, representativeBehaviour)
	if not squad.targetPos then return end
	representativeBehaviour = representativeBehaviour or squad.members[#squad.members]
	local representative = representativeBehaviour.unit:Internal()
	local startPos
	if squad.pathStep then
		local step = math.min(squad.pathStep+1, #squad.path)
		startPos = squad.path[step].position
	elseif not squad.hasGottenPathOnce then
		startPos = self.ai.frontPosition[representativeBehaviour.hits]
		if startPos then
			local angle = self.ai.tool:AnglePosPos(startPos, squad.targetPos)
			startPos = self.ai.tool:RandomAway( startPos, 150, nil, angle)
		else
			startPos = representative:GetPosition()
		end
	else
		startPos = representative:GetPosition()
	end
	squad.modifierFunc = squad.modifierFunc or self.ai.targethst:GetPathModifierFunc(representative:Name(), true)
	local targetModFunc = self.ai.targethst:GetPathModifierFunc(representative:Name(), true)
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
squad.graph = squad.graph or self.ai.maphst:GetPathGraph(squad.mtype)
squad.pathfinder = squad.graph:PathfinderPosPos(startPos, squad.targetPos, nil, nil, nil, squad.modifierFunc)
end

function AttackHST:SquadPathfind(squad, squadIndex)
	if not squad.pathfinder then return end
	local path, remaining, maxInvalid = squad.pathfinder:Find(2)
	if path then
		-- path = self.ai.tool:SimplifyPath(path)
		--table.insert(path,squad.targetPos)--TEST
		squad.path = path
		squad.pathStep = 1
		squad.targetNode = squad.path[1]
		squad.hasMovedOnce = nil
		squad.pathfinder = nil
		squad.hasGottenPathOnce = true
		self:SquadAdvance(squad)
	elseif remaining == 0 then
		squad.pathfinder = nil
		self:SquadReTarget(squad, squadIndex)
	end
end

function AttackHST:MemberIdle(attkbhvr, squad)
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

function AttackHST:SquadAdvance(squad)
	self:EchoDebug("advance")
	squad.idleCount = 0
	self:EchoDebug('squad.pathStep',squad.pathStep,'#squad.path',#squad.path)
	if squad.pathStep == #squad.path then
		self:EchoDebug('advance retarget')
		self:SquadReTarget(squad)
		return
	end
	if squad.hasMovedOnce then
		self:EchoDebug('advance hasmovedonce')
		squad.pathStep = squad.pathStep + 1
		squad.targetNode = squad.path[squad.pathStep]
	end
	local members = squad.members
	local nextPos
	local nextAngle
	if squad.pathStep == #squad.path then
		self:EchoDebug('advance nextangle')
		nextPos = squad.targetPos
		nextAngle = self.ai.tool:AnglePosPos(squad.path[squad.pathStep-1].position, nextPos)
	else
		self:EchoDebug('nextposanglepospos')
		nextPos = squad.targetNode.position

		nextAngle = self.ai.tool:AnglePosPos(nextPos, squad.path[squad.pathStep+1].position)
	end
	local nextPerpendicularAngle = self.ai.tool:AngleAdd(nextAngle, halfPi)
	squad.lastValidMove = nextPos -- attackers use this to correct bad move orders
	self:EchoDebug('advance before attackers members move')
	self:EchoDebug('advance #members',#members)
	for i,member in pairs(members) do
		local pos = nextPos
		if member.formationBack and squad.pathStep ~= #squad.path then
			pos = self.ai.tool:RandomAway( nextPos, -member.formationBack, nil, nextAngle)
		end
		local reverseAttackAngle
		if squad.pathStep == #squad.path then
			reverseAttackAngle = self.ai.tool:AngleAdd(nextAngle, pi)
		end
		self:EchoDebug('advance',pos,nextPerpendicularAngle,reverseAttackAngle)
		member:Advance(pos, nextPerpendicularAngle, reverseAttackAngle)
	end
	self:EchoDebug('advance after members move')
	if squad.hasMovedOnce then
		self:EchoDebug('advance hasmovedonce 2')
		local distToNext = self.ai.tool:Distance(squad.path[squad.pathStep-1].position, nextPos)
		squad.idleTimeout = self.game:Frame() + (self.idleTimeMult * (distToNext / squad.lowestSpeed))
	end
	squad.hasMovedOnce = true
end


function AttackHST:IDsWeAreAttacking(unitIDs, mtype)
	for i, unitID in pairs(unitIDs) do
		self.ai.IDsWeAreAttacking[unitID] = mtype
	end
end

function AttackHST:IDsWeAreNotAttacking(unitIDs)
	for i, unitID in pairs(unitIDs) do
		self.ai.IDsWeAreAttacking[unitID] = nil
	end
end

function AttackHST:TargetDied(mtype)
	self:EchoDebug("target died")
end

function AttackHST:RemoveMember(attkbhvr)
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

function AttackHST:IsRecruit(attkbhvr)
	if attkbhvr.unit == nil then return false end
	local mtype = self.ai.maphst:MobilityOfUnit(attkbhvr.unit:Internal())
	if self.recruits[mtype] ~= nil then
		for i,v in pairs(self.recruits[mtype]) do
			if v == attkbhvr then
				return true
			end
		end
	end
	return false
end

function AttackHST:AddRecruit(attkbhvr)
	if not self:IsRecruit(attkbhvr) then
		if attkbhvr.unit ~= nil then
			-- self:EchoDebug("adding attack recruit")
			local mtype = self.ai.maphst:MobilityOfUnit(attkbhvr.unit:Internal())
			if self.recruits[mtype] == nil then self.recruits[mtype] = {} end
			if self.counter[mtype] == nil then self.counter[mtype] = self.baseAttackCounter end
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

function AttackHST:RemoveRecruit(attkbhvr)
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

function AttackHST:GetCounter(mtype)
	if mtype == nil then
		local highestCounter = 0
		for mtype, counter in pairs(self.counter) do
			if counter > highestCounter then highestCounter = counter end
		end
		return highestCounter
	end
	if self.counter[mtype] == nil then
		return self.baseAttackCounter
	else
		return self.counter[mtype]
	end
end

--[[



]]
