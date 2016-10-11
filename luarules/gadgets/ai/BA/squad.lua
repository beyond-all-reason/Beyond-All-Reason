Squad = class(function(a)
	--
end)

-- functions that need to be set

function Squad:GetTarget()
end

function Squad:GetPathfinder()
end

-- functions that can be set

function Squad:Init()
end

function Squad:Update()
end

function Squad:MemberIdle()
end

function Squad:Idle()
end

function Squad:MemberDead()
end

function Squad:Dead()
end

function Squad:Disbanded()
end

-- functions for the external world to use

function Squad:AddMember()
end

function Squad:RemoveMember()
end

function Squad:IsMember()
end

function Squad:Disband()
end

-- internal functions & functions for squadhandler

function Squad:GetFormation()

end

function Squad:FindPath()

end

function Squad:NewPath()

end

function Squad:ReTarget()

end


function Squad:ReTarget(squad, squadIndex)
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
		local bestCell = self.ai.targethandler:GetBestAttackCell(representative, position)
		if bestCell then
			squad.target = bestCell.pos
			self:IDsWeAreAttacking(bestCell.buildingIDs, squad.mtype)
			squad.buildingIDs = bestCell.buildingIDs
			squad.notarget = 0
			squad.reachedTarget = nil
			self:SquadNewPath(squad, representativeBehaviour)
		else
			-- squad.notarget = squad.notarget + 1
			-- if squad.target == nil or squad.notarget > 3 then
				-- if no target found initially, or no target for the last three targetting checks, disassemble and recruit the squad
				self:SquadDisband(squad, squadIndex)
			-- end
		end
	end
end

function AttackHandler:SquadDisband(squad, squadIndex)
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
	for i = 1, #members do
		local member = members[i]
		if not maxMemberSize or member.congSize > maxMemberSize then
			maxMemberSize = member.congSize
		end
		if not lowestSpeed or member.speed < lowestSpeed then
			lowestSpeed = member.speed
		end
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