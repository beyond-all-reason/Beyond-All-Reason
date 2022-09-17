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
	self.recruits = {}
	self.squads = {}
	self.idleTimeMult = 45  --originally set to 3 * 30
	self.squadID = 1
	self.fearFactor = 0.66
	self.squadMassLimit = 0
	self.squadFreezedTime = 1800 -- if a squad is stopped in one point from a while then try a random move foreach unit
end


function AttackHST:SetMassLimit()
	self.squadMassLimit = 0 + (self.ai.Metal.income * 100)
	self:EchoDebug('squadmasslimit',self.squadMassLimit)
end

function AttackHST:Update()
	if self.ai.schedulerhst.moduleTeam ~= self.ai.id or self.ai.schedulerhst.moduleUpdate ~= self:Name() then return end
	local f = self.game:Frame()
	self:DraftAttackSquads()
	self:SetMassLimit()
	for index , squad in pairs(self.squads) do
		if self:SquadsIntegrityCheck(squad) then
			self:SquadPosition(squad)
			self:SquadSetLeader(squad)
			self:SquadMass(squad)
			if not self:SquadAttack(squad) then
				self:SquadAdvance(squad)
			end

		end
	end
	self:SquadsTargetUpdate()
	self:visualDBG(squad)
end

function AttackHST:DraftAttackSquads()
	local f = self.game:Frame()
	for mtype,soldiers in pairs(self.recruits) do
		for index,soldier in pairs(soldiers) do
			if soldier and soldier.unit and not soldier.squad then
				for index,squad in pairs(self.squads) do
					if not squad.lock and squad.mtype == mtype  then
						table.insert(squad.members , soldier)
						soldier.squad = squad
						self:SquadFormation(squad)
						if (squad.mass > self.squadMassLimit or #squad.members > 10) or (squad.mass > 15000)then
							squad.lock = true
						end
					end
				end
				if not soldier.squad then
					self.squadID = self.squadID + 1
					self.squads[self.squadID] = {}
					local squad = self.squads[self.squadID]
					squad.members = {}
					squad.squadID = self.squadID
					table.insert(squad.members , soldier)
					squad.mtype = mtype
					squad.mass = 0
					soldier.squad = squad
					squad.colour = {0,math.random(),math.random(),1}
					self:SquadFormation(squad)
					squad.graph = self.ai.maphst:GetPathGraph(squad.mtype)
					if (squad.mass > self.squadMassLimit or #squad.members > 10) or (squad.mass > 15000)then
						squad.lock = true
					end
				end
			end
		end
	end
end

function AttackHST:SquadsIntegrityCheck(squad)
		self:EchoDebug('integrity',squad.squadID,#squad.members)
		for i,member in pairs(squad.members) do
			if not member.unit or not member.unit:Internal() or not member.unit:Internal():GetPosition() then
				table.remove(squad.members,i)
				self:RemoveRecruit(member)
			end
		end
		if #squad.members < 1 then
			self:SquadDisband(squad, squad.squadID)
			return false
		end
		return true
end

function AttackHST:SquadDisband(squad)
	self:EchoDebug("disband squad")
	for iu, member in pairs(squad.members) do
		self:AddRecruit(member)
		member.squad = nil
	end
	self.squads[squad.squadID] = nil
end

function AttackHST:SquadFormation(squad)
	self:EchoDebug('squadformation')
	local members = squad.members
	if #squad.members < 1 then
		return
	end
	local maxMemberSize
	local lowestSpeed
	local totalThreat = 0
	for i, member in pairs(members) do
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
	for i, member in pairs(members) do
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

function AttackHST:SquadMass(squad)
	squad.mass = 0
	for i,member in pairs(squad.members) do
		local mass = member.mass
		squad.mass = squad.mass + mass
	end
	self:EchoDebug('squad mass',squad.mass)
end

function AttackHST:SquadPosition(squad)
	local p = {x=0,z=0}
	for i,member in pairs(squad.members) do
		local uPos = member.unit:Internal():GetPosition()
		p.x = p.x + uPos.x
		p.z = p.z + uPos.z
	end
	p.x = p.x / #squad.members
	p.z = p.z / #squad.members
	p.y = map:GetGroundHeight(p.x,p.z)
	squad.position = p
	self:EchoDebug('squad position',p.x,p.z)
end

function AttackHST:SquadAttack(squad)
	if not squad.target then
		self:EchoDebug('squad',squad.squadID,'no target to attack')
		return
	end
	local attack = false
	if squad.target and self.ai.loshst.OWN[squad.target.X] and self.ai.loshst.OWN[squad.target.X][squad.target.Z] then
		self:EchoDebug('squad',squad.squadID,'attack a defensive position',squad.target.X,squad.target.Z)
		attack = true
	end
	if self.ai.tool:distance(squad.position,squad.target.POS) < 256 then
		self:EchoDebug('squad',squad.squadID,'are near to offensive target, do attack')
		attack = true
	end
	if attack then
		for i,member in pairs(squad.members) do
			member:MoveRandom(squad.target.POS,128)
		end
		self:EchoDebug('squad',squad.squadID,'execute attack')
		return true
	end
	return false
end

function AttackHST:MemberIdle(attkbhvr, squad)
	if attkbhvr then
		squad = attkbhvr.squad
		squad.idleCount = (squad.idleCount or 0) + 1
	end
end

function AttackHST:SquadSetLeader(squad)
	local memberDist = math.huge
	local leader = nil
	local leaderPos = nil
	for i,member in pairs(squad.members) do
		local m = member.unit:Internal()
		local p = m:GetPosition()
		local d = self.ai.tool:distance(m:GetPosition(),squad.position)
		if d < memberDist then
			memberDist = d
			leader = m
			leaderPos = p
		end
	end
	self:EchoDebug('set Leader',leader,leaderPos.x,leaderPos.z)
	squad.leader = leader
	squad.leaderPos = leaderPos
	--return leader,leaderPos
end

function AttackHST:SquadNewPath(squad,target)
	self:EchoDebug('search new pathfinder')
	if not target then
		self:EchoDebug('no target for pathfinder')
		return
	end
-- 	local leader,leaderPos = self:SquadSetLeader(squad)
	if not squad.leader then
		self:EchoDebug('no leader for pathfinder')
		return
	end
	local leaderName = squad.leader:Name()
	squad.modifierFunc = self.ai.targethst:GetPathModifierFunc(leaderName, true)
	squad.pathfinder = squad.graph:PathfinderPosPos(squad.leaderPos, target.POS, nil, nil, nil, squad.modifierFunc)
	self:EchoDebug('new pathfinder = ', squad.pathfinder)
end

function AttackHST:SquadStepComplete(squad)
	self:EchoDebug('step complete',squad.step,squad.position.x,squad.position.z,squad.path[squad.step].x,squad.path[squad.step].z)
	if self.ai.tool:distance(squad.position,squad.path[squad.step]) < 256 then
		squad.step = squad.step + 1
	elseif squad.idleCount > floor(#squad.members * 0.85) then
		squad.step = squad.step + 1
	end
	squad.step = math.min(#squad.path,squad.step)
end

function AttackHST:SquadFindPath(squad,target)
	if not target  then
		self:Warn('no target to search path')
		return
	end
	self:EchoDebug('search a path for ',squad.squadID,target.POS.x,target.POS.z)
	self:SquadNewPath(squad,target)

	if not squad.pathfinder then
		self:Warn('no pathfinder')
		return
	end
	local path, remaining, maxInvalid = squad.pathfinder:Find(25)
	if path then
	local pt = {}
 		self:EchoDebug("got path of", #path, "nodes", maxInvalid, "maximum invalid neighbors!!!!!!!!!!!!!!!!!!")
  		for index,cell in pairs(path) do
 			table.insert(pt,cell.position)
--   			self:EchoDebug('path','index',index,'pos',cell.position.x,cell.position.z)
  		end

		step = 1
		squad.pathfinder = nil
		return pt,step
	end
	self:EchoDebug('path not found')
end

function AttackHST:SquadAdvance(squad)
	self:EchoDebug("advance",squad.squadID)
	squad.idleCount = 0
	if not squad.target or not squad.path then
		return
	end
	self:EchoDebug('squad.pathStep',squad.step,'#squad.path',#squad.path)
	self:SquadStepComplete(squad)
	local members = squad.members
	local nextPos = squad.path[squad.step]
	local angle = math.min (squad.step + 1,#squad.path)
	local nextAngle = self.ai.tool:AnglePosPos(nextPos, squad.path[angle])
	local nextPerpendicularAngle = self.ai.tool:AngleAdd(nextAngle, halfPi)
 	squad.lastValidMove = nextPos -- attackers use this to correct bad move orders
	self:EchoDebug('advance #members',#members)
	for i,member in pairs(members) do
		local pos = nextPos
 		if member.formationBack and squad.step ~= #squad.path then
 			pos = self.ai.tool:RandomAway( nextPos, -member.formationBack, nil, nextAngle)
 		end
 		local reverseAttackAngle
 		if squad.step == #squad.path then
 			reverseAttackAngle = self.ai.tool:AngleAdd(nextAngle, pi)
 		end
 		self:EchoDebug('advance',pos,nextPerpendicularAngle,reverseAttackAngle)
		member:Advance(pos, nextPerpendicularAngle, reverseAttackAngle)
	end
	self:EchoDebug('advance after members move')
end

function AttackHST:SquadsTargetUpdate()


	for i,blob in pairs(self.ai.targethst.BLOBS) do
		local targetDist = math.huge
		local targetCell = nil
		local targetSquad = nil
		for id,squad in pairs(self.squads) do
			local dist = self.ai.tool:distance(blob.defend.POS,squad.position)
			if dist < targetDist then
				targetCell = blob.defend
				targetDist = dist
				targetSquad = squad.squadID
			end
		end
		if targetSquad then
			self:SquadResetTarget(self.squads[targetSquad])
			self.squads[targetSquad].target = targetCell
		end
	end
	for id,squad in pairs(self.squads) do
		if not squad.target then
			squad.target = self:SquadsTargetAttack(squad)
		end
	end
	for id,squad in pairs(self.squads) do
		if not squad.target then
			local preventDist = 0
			local preventCell = nil
			local preventSquad = nil
			for X,cells in pairs(self.ai.loshst.OWN) do
				for Z, cell in pairs(cells) do
					local dist = self.ai.tool:distance(cell.POS,self.ai.loshst.CENTER)
					if dist > preventDist then
						preventDist = dist
						preventCell = cell
						preventSquad = squad.squadID
					end
				end
			end
		end
	end
end

function AttackHST:SquadTargetExist(squad,grid)
	if not self.ai.loshst[grid][squad.target.X] or not self.ai.loshst[grid][squad.target.X][squad.target.Z] then
		self:EchoDebug('squad' ,squad.squadID,'target',X,Z,'no more available')

		return false
	end
	return true
end

function AttackHST:SquadResetTarget(squad)
	squad.target = nil
	squad.path = nil
	squad.pathfinder = nil
	squad.step = nil
	squad.idleCount = 0
end

function AttackHST:SquadsTargetDefense(squad)
	local targetDist = math.huge
	local targetCell
	for index,blob in pairs(self.ai.targethst.BLOBS)do
		for id,__Squad in pairs(self.squads) do
			if __squad.target.X == blob.defend.X and __squad.target.Z == blob.defend.Z then
				if __squad.squadID == squad.squadID then
					return blob.defend
				else

					self:EchoDebug('defend target alredy in use of',__squad.squadID,blob.defend.X,blob.defend.Z)
					return nil
				end
			end
			local dist = self.ai.tool:distance(blob.defend.POS,squad.position)
			if dist < targetDist then
				targetDist = dist
				targetCell = blob.defend
			end
		end
	end
	return  targetCell
end

function AttackHST:SquadsTargetAttack(squad)
	self:EchoDebug('targeting')
	local targets = {}
	local bestValue = math.huge
	local bestTarget = nil
	local topDist = self.ai.tool:DistanceXZ(0,0, Game.mapSizeX, Game.mapSizeZ)
	local first = self:getFrontCell(squad,representative)
	if first then
		return first
	end
	for X, cells in pairs(self.ai.loshst.ENEMY) do
		for Z, cell in pairs(cells) do
			for squadIndex,squad in pairs(self.squads) do
				if squad.target and squad.target.X == cell.X and squad.target.Z == cell.Z then return end
			end
			if cell.IMMOBILE > 0   then
				if self.ai.maphst:UnitCanGoHere(squad.leader, cell.POS) then
					self:EchoDebug('cangohere')
					local Rdist = self.ai.tool:Distance(cell.POS,squad.position)/topDist
					local Rvalue = Rdist * cell.ENEMY
					if Rvalue < bestValue then
						self:EchoDebug('val',Rvalue)
						bestTarget = cell
						bestValue = Rvalue
					end
				end
			end
		end
	end
	if bestTarget then
		return bestTarget
	end
	self:EchoDebug('no target found for attackhst')
end


function AttackHST:getFrontCell(squad,representative)
	if not squad then return end
	if not self.ai.targethst.distals then return end
	local bestDist = math.huge
	local bestTarget = nil
	for i, cell in pairs(self.ai.targethst.enemyFrontList) do
		if self.ai.maphst:UnitCanGoHere(representative, cell.POS) then
			local dist = self.ai.tool:Distance(cell.POS,representative:GetPosition())
			if dist < bestDist  then
				bestTarget = cell
				bestDist = dist
			end
		end
	end
	self:EchoDebug('best frontal Target',bestTarget)
	return bestTarget
end


function AttackHST:RemoveMember(attkbhvr)
	if attkbhvr == nil then return end
	if not attkbhvr.squad then return end
	local squad = attkbhvr.squad
	for index,member in pairs(squad.members)do
		if member == attkbhvr then
			table.remove(squad.members, iu)
			if #squad.members == 0 then
				self:SquadDisband(squad)
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


function AttackHST:visualDBG()
	local ch = 6
	self.map:EraseAll(ch)
	if not self.ai.drawDebug then
		return
	end
	for index , squad in pairs(self.squads) do
		self.map:DrawCircle(squad.position,100, squad.colour, squad.squadID ..' : '.. squad.mass,squad.lock, ch)
		for i,member in pairs(squad.members) do
			member.unit:Internal():EraseHighlight(nil, nil, ch )
			member.unit:Internal():DrawHighlight(squad.colour ,nil , ch )
		end
		if squad.path then
			for i , p in pairs(squad.path) do
				self.map:DrawPoint(p, squad.colour, i, ch)
			end
		end
		if squad.target then
			self.map:DrawCircle(squad.target.POS,100, squad.colour, 'target ',true, ch)
		end
	end
end

--[[
function AttackHST:SquadMove(squad)
	squad.formation = {}
	local pos = squad.path[squad.step]
	local X
	local Z
	local range = #squad.members*10
	for index,member in pairs(squad.members) do
		ref = index/10

		if squad.position.x < pos.x then
			X = range * math.sin(ref) * -1
		else
			X = (range * math.sin(ref))
		end
		if squad.position.z < pos.z then
			Z = range * math.cos(ref) * -1
		else
			Z = (range * math.cos(ref))
		end

		local unit = member.unit:Internal()

		local arch = api.Position()
		arch.x = pos.x + X
		arch.z = pos.z + Z
		arch.y = Spring.GetGroundHeight(arch.x,arch.z)
		self:EchoDebug('arch',arch.x,arch.z)
		self:EchoDebug('go to next node',index,arch.x,arch.z)
		squad.formation[index] = arch
		unit:AttackMove(arch)

	end
end


function AttackHST:getDistCell(squad,representative)
	if not squad then return end
	if not self.ai.targethst.distals then return end
	local bestDist = math.huge
	local bestTarget = nil
	for i, cell in pairs(self.ai.targethst.distals) do
		if self.ai.maphst:UnitCanGoHere(representative, cell.POS) then
			local dist = self.ai.tool:Distance(cell.POS,representative:GetPosition())
			if dist < bestDist  then
				bestTarget = cell
				bestDist = dist
			end
		end
	end
	self:EchoDebug('best distals Target',bestTarget)
	return bestTarget
end

]]
