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
	self.squadID = 1
	self.squadMassLimit = 0
	self.countLimit = 4
	self.squadFreezedTime = 300
end


function AttackHST:SetMassLimit()
	self.squadMassLimit = math.ceil(100 + self.ai.ecohst.Metal.income * 100)
	self:EchoDebug('squad mass limit',self.squadMassLimit)
end

function AttackHST:Watchdog(squad)
	local f = game:Frame()
	squad.watchdogCell = squad.watchdogCell or self.ai.maphst:GetCell(squad.position,self.ai.maphst.GRID)
	local watchdogCell = self.ai.maphst:GetCell(squad.position,self.ai.maphst.GRID)
	if not watchdogCell then
		self:EchoDebug('no watchdog cell')
		return
	end
	if squad.watchdogCell and squad.watchdogCell.X == watchdogCell.X and squad.watchdogCell.Z == watchdogCell.Z then
		if f > squad.watchdogTimer + self.squadFreezedTime then
			self:SquadResetTarget(squad)
		else
			squad.watchdogTimer = f
		end
	end
	squad.watchdogCell = watchdogCell
end

function AttackHST:Update()
	if self.ai.schedulerhst.moduleTeam ~= self.ai.id or self.ai.schedulerhst.moduleUpdate ~= self:Name() then return end
	local f = self.game:Frame()
	self:DraftAttackSquads()
	for index , squad in pairs(self.squads) do
		if self:SquadCheck(squad) then
			self:Watchdog(squad)
			if not self:SquadAttack(squad) then
				self:SquadAdvance(squad)
			end
		end
	end
	self:SquadsTargetUpdate2()
	self:visualDBG(squad)
end

function AttackHST:DraftAttackSquads()
	local f = self.game:Frame()
	for mtype,soldiers in pairs(self.recruits) do
		for index,soldier in pairs(soldiers) do
		--self:EchoDebug(index,mtype,soldier.squad)--TODO fix thes fucking debug trouble
			if soldier and soldier.unit and not soldier.squad then
				for idx,squad in pairs(self.squads) do
					self:EchoDebug(idx,squad.squadID,squad.lock,squad.mtype)
					if not squad.lock and squad.mtype == mtype  then
						table.insert(squad.members , soldier)
						soldier.squad = squad
						self:SquadFormation(squad)
						self:EchoDebug('insert' ,index , 'in squad',squad.squadID)
						if (squad.mass > self.squadMassLimit or #squad.members > self.countLimit) or (squad.mass > 15000)then
							squad.lock = true
							self:EchoDebug('squad',squad.squadID, 'full' ,squad.mass > self.squadMassLimit,#squad.members > self.countLimit,squad.mass > 15000)
							self.countLimit = math.min(20,self.countLimit + self.ai.labshst.ECONOMY)
						end
					end
				end
				if not soldier.squad then
					self:EchoDebug('init a new squad')
					self:SetMassLimit()
					self.squadID = self.squadID + 1
					self.squads[self.squadID] = {}
					local squad = self.squads[self.squadID]
					squad.members = {}
					squad.squadID = self.squadID
					table.insert(squad.members , soldier)
					squad.mtype = mtype
					squad.mass = 0
					squad.role = nil
					squad.watchdogTimer = game:Frame()
					soldier.squad = squad

					squad.colour = {0,math.random(),math.random(),1}
					self:SquadFormation(squad)
					--squad.graph = self.ai.maphst:GetPathGraph(squad.mtype)

					if (squad.mass > self.squadMassLimit or #squad.members > 5 + self.ai.labshst.ECONOMY) or (squad.mass > 15000)then
						squad.lock = true

					end
				end
			end
		end
	end
end

function AttackHST:SquadCheck(squad)
	self:EchoDebug('integrity',squad.squadID,#squad.members)
	local check = nil
	local x,y,z = 0,0,0
	local mass = 0
	local memberCount = 0
	for i,member in pairs(squad.members) do


-- 		local uPos = self.ai.tool:UnitPos(member)

		if not member.unit 	then

			table.remove(squad.members,i)
			self:RemoveRecruit(member)
		else
			local ux,uy,uz = member.unit:Internal():GetRawPos()
			if ux then
				check = true
				x = x + ux--member.unit.x
				z = z + uz--member.unit.z
				memberCount = memberCount + 1
				mass = mass + member.mass
			end
		end
	end
	if not check then
		self:SquadDisband(squad, squad.squadID)
		return
	end
	squad.position = squad.position or {}
	squad.position.x = x / memberCount
	squad.position.z = z / memberCount
	squad.position.y = map:GetGroundHeight(squad.position.x,squad.position.x)
	squad.mass = mass
	local memberDist = math.huge
	local leader = nil
	local leaderPos = nil
	squad.leaderPos = squad.leaderPos or {}
	for i,member in pairs(squad.members) do

		if member.unit then
			squad.leader = member.unit:Internal()
			squad.leaderPos.x,squad.leaderPos.y,squad.leaderPos.z = member.unit:Internal():GetRawPos()
			break
		end
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
	self:EchoDebug('squad formation')
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

function AttackHST:SquadAttack(squad)
	if not squad.target then
		self:EchoDebug('squad',squad.squadID,'no target to attack')
		return
	end
	if self.ai.loshst.OWN[squad.target.X] and self.ai.loshst.OWN[squad.target.X][squad.target.Z] then
		self:EchoDebug('squad',squad.squadID,'attack a defensive position',squad.target.X,squad.target.Z)
		for i,member in pairs(squad.members) do
			member:MoveRandom(squad.target.POS,128)
		end
		self:EchoDebug('squad',squad.squadID,'execute defense')
		return true
	end
	if self.ai.loshst.ENEMY[squad.target.X] and self.ai.loshst.ENEMY[squad.target.X][squad.target.Z]  and self.ai.tool:distance(squad.position,squad.target.POS) < 256 then
		self:EchoDebug('squad',squad.squadID,'are near to offensive target, do attack')
		for i,member in pairs(squad.members) do
			if not squad.target.units then
				self:EchoDebug('squad',squad.squadID,'no target units')
				return
			end
			for id,_ in pairs(squad.target.units) do
				member.unit:Internal():Attack(id)
			end
			
		end
		return true
	end
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
	local path = self.ai.maphst:getPath(squad.leader:Name(),squad.leaderPos,target.POS,true)
	if path then
		table.insert(path,#path,target.POS)
 		self:EchoDebug("got path of", #path, "nodes", maxInvalid, "maximum invalid neighbors!!!!!!!!!!!!!!!!!!")
		step = 1
		squad.pathfinder = nil
		return path,step
	end
	self:EchoDebug('path not found')
end

function AttackHST:SquadAdvance(squad)
	self:EchoDebug("advance",squad.squadID)
	squad.idleCount = 0
	if not squad.target or not squad.path then
		return
	end
	local x,y,z
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
		local pos
 		if member.formationBack and squad.step ~= #squad.path then
 			pos = self.ai.tool:RandomAway( nextPos, -member.formationBack, nil, nextAngle)
 		end
 		local reverseAttackAngle
 		if squad.step == #squad.path then
 			reverseAttackAngle = self.ai.tool:AngleAdd(nextAngle, pi)
 		end
		member:Advance(pos or nextPos, nextPerpendicularAngle, reverseAttackAngle)
	end
	self:EchoDebug('advance after members move')
end

function AttackHST:SquadsTargetHandled(target)
	if not target then
		self:EchoDebug('no target to handle')
		return
	end
	for squadID,squad in pairs(self.squads) do
		if squad.target and squad.target.X == target.X and squad.target.Z == target.Z then
			return squad.squadID
		end
	end
end

function AttackHST:SquadsTargetUpdate2()
	for id,squad in pairs(self.squads) do
		if squad.target and squad.role == 'offense' and self.ai.maphst:GetCell(squad.target.X,squad.target.Z,self.ai.loshst.ENEMY) then
			self:EchoDebug('squadID',squadID, 'offense cell', squad.target.X,squad.target.Z)
		else
			self:SquadResetTarget(squad)
			--local defense = self:SquadsTargetDefense(squad)
-- 			if defense then
-- 				squad.target = defense
-- 				squad.role = 'defense'
-- 				self:EchoDebug('set defensive target for',squad.squadID,squad.target.X,squad.target.Z)
-- 			else
				local offense,setPath = self:SquadsTargetAttack2(squad)
				if offense and squad.lock then
					path, step = self:SquadFindPath(squad,offense)
					if path and step then
						squad.target = offense
						squad.role = 'offense'
						squad.path = path
						squad.step = step
						self:EchoDebug('set offensive target for',squad.squadID,squad.target.X,squad.target.Z)
					end
				end
				if not squad.target then
					local prevent = self:SquadsTargetPrevent2(squad)
					if prevent then
						squad.target = prevent
						squad.role = 'prevent'
						self:EchoDebug('set preventive target for',squad.squadID,squad.target.X,squad.target.Z)
					else
						self:EchoDebug('squad', squadID, 'have no target')
					end
				end
			--end
		end
	end
end

function AttackHST:SquadsTargetPrevent2(squad)
	local frontDist = math.huge
	local preventDist = 0
	local preventCell = nil
	local preventSquad = nil
	for id,role in pairs(self.ai.buildingshst.roles) do
		if role.role == 'expand' then
			local builder = game:GetUnitByID(id)
			local builderPos = builder:GetPosition()
			local cell = self.ai.maphst:GetCell(builderPos,self.ai.maphst.GRID)
			local targetHandled = self:SquadsTargetHandled(cell)
			if not targetHandled or targetHandled == squad.squadID then
				local dist = self.ai.tool:distance(cell.POS,squad.position)
				if dist < frontDist then
					preventDist = dist
					preventCell = cell
					preventSquad = squad.squadID
				end
			end
		end
	end
	return preventCell
end

function AttackHST:SquadsTargetDefense(squad)
	local targetDist = math.huge
	local targetCell
	for index,blob in pairs(self.ai.targethst.MOBILE_BLOBS)do
		local targetHandled = self:SquadsTargetHandled(blob.defend)
		if not targetHandled or targetHandled == squad.squadID then
			local dist = self.ai.tool:distance(blob.position,self.ai.loshst.CENTER)
			if dist < targetDist then
				targetDist = dist
				if blob.metal > squad.mass then
					targetCell = blob.defend
				else
					targetCell = blob.refCell
				end
			end
		end
	end
	return  targetCell
end

function AttackHST:SquadsTargetAttack2(squad)
	local bestValue = 0
	local bestTarget = nil
	local bestDist = math.huge
	local worstDist = 0
	
	for ref, blob in pairs(self.ai.targethst.IMMOBILE_BLOBS) do
		if not self:SquadsTargetHandled(blob) then
			local mclass = squad.leader:Name()
			local path = self.ai.maphst:getPath(mclass,squad.leaderPos,blob.position)
			
			if path then
				local dist = self.ai.tool:distance(blob.position,self.ai.targethst.enemyCenter)
				if dist > worstDist then
					worstDist = dist
					bestTarget = blob.refCell
				end
			end
		end
	end
	return bestTarget
end

function AttackHST:SquadResetTarget(squad)
	squad.target = nil
	squad.path = nil
	squad.pathfinder = nil
	squad.step = nil
	squad.idleCount = 0
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

function AttackHST:MemberIdle(attkbhvr)
	if attkbhvr and attkbhvr.squad then
		squad = attkbhvr.squad
		squad.idleCount = (squad.idleCount or 0) + 1
	end
end

function AttackHST:visualDBG()
	local ch = 6

	if not self.ai.drawDebug then
		return
	end
	self.map:EraseAll(ch)
	for index , squad in pairs(self.squads) do
		self.map:DrawCircle(squad.position,100, squad.colour, squad.squadID,squad.lock, ch)
		for i,member in pairs(squad.members) do
			if member.unit then
				member.unit:Internal():EraseHighlight(nil, nil, ch )
				member.unit:Internal():DrawHighlight(squad.colour ,nil , ch )
			end
		end
		if squad.path then
			for i , p in pairs(squad.path) do
				self.map:DrawPoint(p, squad.colour, i, ch)
			end
		end
		if squad.target then
			self.map:DrawPoint(squad.target.POS, squad.colour, squad.role .. squad.squadID, ch)
			map:DrawLine(squad.position,squad.target.POS,squad.colour,nil,nil,ch)
		end
	end
end



--[[
function AttackHST:SquadMass(squad)
	squad.mass = 0
	for i,member in pairs(squad.members) do
		local mass = member.mass
		squad.mass = squad.mass + mass
	end
	self:EchoDebug('squad mass',squad.mass)
end

function AttackHST:SquadPosition(squad)
	local p = api.Position()
	local check
	for i,member in pairs(squad.members) do
		local uPos = self.ai.tool:UnitPos()
		if uPos then
			p.x = p.x + uPos.x
			p.z = p.z + uPos.z
			check = true
		end
	end
	p.x = p.x / #squad.members
	p.z = p.z / #squad.members
	p.y = map:GetGroundHeight(p.x,p.z)
	if check then
		squad.position = p
		self:EchoDebug('squad position',p.x,p.z)
	else
		self:SquadDisband(squad, squad.squadID)
	end
end
]]


--[[
function AttackHST:SquadNewPath(squad,target)
	self:EchoDebug('search new pathfinder')
	if not target then
		self:EchoDebug('no target for pathfinder')
		return
	end
	if not squad.leader then
		self:EchoDebug('no leader for pathfinder')
		return
	end
	local leaderName = squad.leader:Name()
	squad.modifierFunc = self.ai.targethst:GetPathModifierFunc(leaderName, true)
	squad.pathfinder = squad.graph:PathfinderPosPos(squad.leaderPos, target.POS, nil, nil, nil, squad.modifierFunc)
	self:EchoDebug('new pathfinder = ', squad.pathfinder)
end
]]

--[[
function AttackHST:SquadTargetExist(squad,grid)
	if not squad.target or not grid[squad.target.X] or not grid[squad.target.X][squad.target.Z] then
		self:EchoDebug('squad' ,squad.squadID,'target',X,Z,'no more available')
		return false
	end
	return true
end
]]
--[[
function AttackHST:SquadsTargetPrevent(squad)
	local frontDist = math.huge
	local preventDist = 0
	local preventCell = nil
	local preventSquad = nil
	for X,cells in pairs(self.ai.loshst.OWN) do
		for Z, cell in pairs(cells) do
			local targetHandled = self:SquadsTargetHandled(cell)
			if not targetHandled or targetHandled == squad.squadID then
				local dist = self.ai.tool:distance(cell.POS,self.ai.targethst.enemyCenter)
				if dist < frontDist then
					preventDist = dist
					preventCell = cell
					preventSquad = squad.squadID
				end
			end
		end
	end
	return preventCell
end
]]

--[[
function AttackHST:SquadsTargetAttack(squad)
	local bestValue = math.huge
	local bestTarget = nil
	local bestDist = math.huge
	local worstDist = 0
	for X, cells in pairs(self.ai.loshst.ENEMY) do
		for Z, cell in pairs(cells) do
			if not self:SquadsTargetHandled(cell) then
				if cell.IMMOBILE > 0   then
					if self.ai.maphst:UnitCanGoHere(squad.leader, cell.POS) then
						local dist = self.ai.tool:distance(cell.POS,self.ai.targethst.enemyCenter)
						--local dist = self.ai.tool:distance(cell.POS,squad.position)
						if dist > worstDist then
							worstDist = dist
							bestDist = dist
							bestTarget = cell
							bestValue = cell.IMMOBILE
						end
					end
				end
			end
		end
	end
	return bestTarget
end
]]
