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
	self.squads = {}
	self.ai.IDsWeAreAttacking = {}
	self.minAttackCounter = 4
	self.maxAttackCounter = 4
	self.baseAttackCounter = 4
	self.idleTimeMult = 45  --originally set to 3 * 30
	self.squadID = 1
	self.fearFactor = 0.66
	self.defensive = nil
end


function AttackHST:Update()
 	local f = self.game:Frame()
-- 	if f % 17 ~= 0 then
-- 		return
-- 	end
	if self.ai.schedulerhst.moduleTeam ~= self.ai.id or self.ai.schedulerhst.moduleUpdate ~= self:Name() then return end
	self:DraftSquads()
	self:squadsIntegrityCheck()
	self:squadsTargetCheck()
	self:squadsRoleCheck()
	for index , squad in pairs(self.squads) do
		self:visualDBG(squad)
		if not squad.arrived and squad.idleTimeout and f >= squad.idleTimeout then
			squad.arrived = true
			squad.idleTimeout = nil
		end
		if squad.arrived then
			squad.arrived = nil
			if squad.pathStep < #squad.path - 1 then
				local gridX,gridZ = self.ai.targethst:PosToGrid(squad.targetPos)
				local cell = self.ai.targethst.CELLS[gridX][gridZ]
				local value = cell.ENEMY
				local threat = cell.armed
				if (value == 0 and threat == 0) or threat > squad.totalThreat * self.fearFactor then
					self:SquadReTarget(squad,1) -- get a new target, this one isn't valuable
				else
					self:SquadNewPath(squad) -- see if there's a better way from the point we're going to
				end
			end
			self:SquadAdvance(squad)
		end
	end
	for index, squad in pairs(self.squads) do
		self:SquadPathfind(squad, index)
	end
-- 	if not self.squads or #self.squads < 1 then--TEST how to a squad is deleted during update?
-- 		return
-- 	end
-- 	local index = (self.lastSquadPathfind or 0) + 1
-- 	if index > #self.squads then index = 1 end
-- 	local squad = self.squads[index]
-- 	self:EchoDebug(index,self.squads[index],#self.squads)
-- 	self:SquadPathfind(squad, index)
-- 	self.lastSquadPathfind = index
end

function AttackHST:DraftSquads()
	local needtarget = {}
	local f = self.game:Frame()
	-- find which mtypes need targets
	local tmpSquads = {}
	local tmpID = 1
	for mtype,soldiers in pairs(self.recruits) do
		tmpSquads[mtype] = {}
		if not tmpSquads[mtype][tmpID] then
			tmpSquads[mtype][tmpID] = {}
			tmpSquads[mtype][tmpID].members = {}
		end
		for index,soldier in pairs(soldiers) do
			if soldier and soldier.unit and not soldier.squad then
				tmpSquads[mtype][tmpID].mtype = mtype
				table.insert(tmpSquads[mtype][tmpID].members , soldier)
				self:EchoDebug('insert',soldier.unit:Internal():Name(),'in',mtype ,tmpID ,'#members',#tmpSquads[mtype][tmpID].members)
				if #tmpSquads[mtype][tmpID].members >= math.min(self.baseAttackCounter * self.ai.Metal.income / 10,25) then

					tmpID = tmpID + 1
					tmpSquads[mtype][tmpID] = {}
					tmpSquads[mtype][tmpID].members = {}
				end
			end
		end
	end
	for mtype,squads in pairs(tmpSquads) do
		for tmpID,squad in pairs(squads) do
			if #squad.members >= math.min(self.baseAttackCounter * self.ai.Metal.income / 10,25) then
				local representative, representativeBehaviour
				for i, soldier in pairs(squad.members) do
					representativeBehaviour = representativeBehaviour or soldier
					representative = representative or soldier.unit:Internal()
					soldier.squad = squad
				end
				if representative then
					self:EchoDebug(mtype,self.squadID, "has representative and ", #squad.members, ' members')
					--local bestCell = self:targetCell(representative,nil,nil,squad)
					local bestCell = self:SquadReTarget(squad,0)

					self.squads[self.squadID] = squad
					self.squads[self.squadID].squadID = self.squadID
					self.squads[self.squadID].mtype = mtype
					self.squadID = self.squadID + 1
					squad.Role = 'offensive'

					if bestCell ~= nil then
						self:EchoDebug(mtype, "has target, recruiting squad...")
						squad.targetCell = bestCell
						bestCell.buildingIDs = bestCell.enemyBuildings
						squad.targetPos = bestCell.pos
						self:IDsWeAreAttacking(bestCell.buildingIDs, squad.mtype)
						squad.buildingIDs = bestCell.buildingIDs
						self:SquadFormation(squad)
						self:SquadNewPath(squad, representativeBehaviour)
						squad.colour = {0,math.random(),math.random(),1}
					end
				end
			end
		end
	end
end

function AttackHST:squadsIntegrityCheck()
	for squadid,squad in pairs(self.squads) do
		self:EchoDebug('integrity',squadid,#squad.members)
		if #squad.members < 1 then
			self:SquadDisband(squad, squadid)
		end
	end
end

function AttackHST:squadsTargetCheck()
	for squadid,squad in pairs(self.squads) do
		self:EchoDebug('retarget',squadid,#squad.members)
		if not squad.targetCell  then
			self:SquadReTarget(squad,1)
		end
	end
end



function AttackHST:squadsRoleCheck()
	flag = false
	self:EchoDebug('self.defensive',self.defensive)
	if self.defensive and self.squads[self.defensive] and self.squads[self.defensive].Role == 'defensive' then
		return self.defensive
	elseif self.defensive and not self.squads[self.defensive]  then
			self.defensive = nil
	elseif self.defensive and self.squads[self.defensive] and  self.squads[self.defensive].Role ~= 'defensive' then
		self.squads[self.defensive].Role = 'defensive'
	elseif not self.defensive then
		for squadid,squad in pairs(self.squads) do
			squad.Role = 'defensive'
			self.defensive = squadid
			break
		end
	end
end

function AttackHST:SquadReTarget(squad,TYPE)
	self:EchoDebug('retarget' , squad.squadID,TYPE)
	local representativeBehaviour
	local representative
	for iu, member in pairs(squad.members) do
		if member and member.unit then
			representativeBehaviour = member
			representative = member.unit:Internal()
			if representative ~= nil then
				self:EchoDebug('have representative for retarget')
				break
			end
		end
	end
	if squad.buildingIDs ~= nil then
		self:IDsWeAreNotAttacking(squad.buildingIDs)
	end
	if representative == nil then
		self:EchoDebug('no rappresentative than disband')
		self:SquadDisband(squad)
	else
		self:EchoDebug('search another target')
		local position
		if squad.pathStep then
			local step = math.min(squad.pathStep+1, #squad.path)
			position = squad.path[step].position
		end
		local bestCell =  self:targetCell(representative,nil,nil,squad,TYPE)
		if bestCell then
			squad.targetPos = bestCell.pos
			squad.targetCell = bestCell
			if not bestCell.buildingIDs then
				bestCell.buildingIDs = bestCell.enemyBuildings
			end
			self:IDsWeAreAttacking(bestCell.buildingIDs, squad.mtype)
			squad.buildingIDs = bestCell.buildingIDs
			squad.reachedTarget = nil
			self:SquadFormation(squad)
			self:SquadNewPath(squad, representativeBehaviour)
		else
			self:EchoDebug('have no target ')
		end
	end
end

function AttackHST:targetCell(representative, position, ourThreat,squad)
	self:EchoDebug('targeting')
	if not representative then return end
	position = position or representative:GetPosition()
	refpos = position or self.ai.loshst.CENTER
	local aName = representative:Name()
	local targets = {}
	local maxdist = 0
	local bestValue = math.huge
	local bestTarget = nil
	local bestDefense = 0
	local bestDefCell = nil

	local topDist = self.ai.tool:DistanceXZ(0,0, Game.mapSizeX, Game.mapSizeZ)
	if TYPE == 0 then
		local first = self:getFrontCell(squad,representative)
		if first then return first end
	end

	if TYPE == 1 then
		local first = self:getFrontCell(squad,representative)
		if first then return first end
	end


	for i, G in pairs(self.ai.targethst.ENEMYCELLS) do
		local cell = self.ai.targethst.CELLS[G.x][G.z]
		for squadIndex,squad in pairs(self.squads) do
			if squad.targetCell == cell or not cell.pos then return end
		end
		self:EchoDebug('cell.IMMOBILE',cell.IMMOBILE,'cell.offense',cell.offense) --squad.Role == 'defensive' and
 		if cell.offense > 0 and cell.IMMOBILE < cell.offense / 10 then
 			if self.ai.maphst:UnitCanGoHere(representative, cell.pos) then
 				self:EchoDebug('can go to cell')
 				local Rdist = self.ai.tool:Distance(cell.pos,refpos)/topDist
 				local Rvalue = Rdist * cell.offense
 				if Rvalue > bestDefense and self.ai.tool:Distance(cell.pos,refpos) < topDist / 3 then
 					bestDefense = Rvalue
 					bestDefCell = cell
 				end
 			end
 		end
		if cell.IMMOBILE > 0   then--squad.Role ~= defensive and
			if self.ai.maphst:UnitCanGoHere(representative, cell.pos) then
				self:EchoDebug('cangohere')
				local Rdist = self.ai.tool:Distance(cell.pos,self.ai.targethst.enemyBasePosition or refpos)/topDist
				local Rvalue = Rdist * cell.ENEMY
				if Rvalue < bestValue then
					self:EchoDebug('val')
					bestTarget = cell
					bestValue = Rvalue
				end
			end
		end
	end
	if bestDefCell then
		return bestDefCell
	elseif bestTarget then
		return bestTarget
	end
	self:EchoDebug('no target found for attackhst')
end

function AttackHST:getDistCell(squad,representative)
	if not squad then return end
	if not self.ai.targethst.distals then return end
	local bestDist = math.huge
	local bestTarget = nil
	for i, cell in pairs(self.ai.targethst.distals) do
		--local cell = self.ai.targethst.CELLS[G.x][G.z]
		if self.ai.maphst:UnitCanGoHere(representative, cell.pos) then
			local dist = self.ai.tool:Distance(cell.pos,representative:GetPosition())
			if dist < bestDist  then
				bestTarget = cell
				bestDist = dist
			end
		end
	end
	self:EchoDebug('best distals Target',bestTarget)
	return bestTarget
end

function AttackHST:getFrontCell(squad,representative)
	if not squad then return end
	if not self.ai.targethst.distals then return end
	local bestDist = math.huge
	local bestTarget = nil
	for i, cell in pairs(self.ai.targethst.enemyFrontList) do
		--local cell = self.ai.targethst.CELLS[G.x][G.z]
		if self.ai.maphst:UnitCanGoHere(representative, cell.pos) then
			local dist = self.ai.tool:Distance(cell.pos,representative:GetPosition())
			if dist < bestDist  then
				bestTarget = cell
				bestDist = dist
			end
		end
	end
	self:EchoDebug('best distals Target',bestTarget)
	return bestTarget
end

function AttackHST:SquadDisband(squad, squadIndex)
	self:EchoDebug("disband squad")
	squad.disbanding = true
	for iu, member in pairs(squad.members) do
		self:AddRecruit(member)
		--member.squad = nil
	end
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
	self:EchoDebug('squadformation')
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
	self:EchoDebug('squadnewpath')
	if not squad.targetPos then return end
	representativeBehaviour = representativeBehaviour or squad.members[#squad.members]
	if not representativeBehaviour then	return end
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
	self:EchoDebug('squadpathfind')
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
		self:SquadReTarget(squad,1)
	end
end

function AttackHST:SquadPosition(squad)
	self:EchoDebug('squad position')
	local p = {x=0,z=0}
	for i,member in pairs(squad.members) do
		local uPos = member:GetPosition()
		p.x = p.x + uPos.x
		p.z = p.z + uPos.z
	end
	p.x = p.x / #squad.members
	p.z = p.z / #squad.members
	p.y = Spring.GetGroundHeight(p.x,p.z)
	squad.position = p

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
	self:EchoDebug("advance",squad.squadID)
	squad.idleCount = 0
	self:EchoDebug('squad.pathStep',squad.pathStep,'#squad.path',#squad.path)
	if squad.pathStep == #squad.path then
		self:EchoDebug('advance retarget')
		self:SquadReTarget(squad,1)
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
			local mtype = self.ai.maphst:MobilityOfUnit(attkbhvr.unit:Internal())
			if self.recruits[mtype] == nil then self.recruits[mtype] = {} end
			local level = attkbhvr.level
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
				table.remove(self.recruits[mtype], i)
				return true
			end
		end
	end
	return false
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
