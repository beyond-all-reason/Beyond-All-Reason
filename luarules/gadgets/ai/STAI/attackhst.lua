AttackHST = class(Module)

function AttackHST:Name()
	return "AttackHST"
end

function AttackHST:internalName()
	return "attackhst"
end

local floor = math.floor

function AttackHST:Init()
	self.DebugEnabled = false
	self.recruits = {}
	self.squads = {}
	self.squadID = 1
	self.squadMassLimit = 0
	self.countLimit = 4
	self.squadFreezedTime = 300
	self.debugChannel = 7
end

function AttackHST:SetMassLimit()
	self.squadMassLimit = math.ceil(100 + self.ai.ecohst.Metal.income * 150)
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
			self:SquadAdvance(squad)
		end
	end
	self:SquadsTargetUpdate()
	self:visualDBG()
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
		if not member.unit or not member.unit:Internal():GetPosition()	then
			table.remove(squad.members,i)
			self:RemoveRecruit(member)
		else
			local ux,uy,uz = member.unit:Internal():GetRawPos()
			if ux then
				check = true
				x = x + ux
				z = z + uz
				memberCount = memberCount + 1
				mass = mass + member.mass
			end
		end
	end
	if not check then
		self:SquadDisband(squad)
		return
	end
	squad.position = squad.position or  self.ai.tool:RezTable()
	squad.position.x = x / memberCount
	squad.position.z = z / memberCount
	squad.position.y = map:GetGroundHeight(squad.position.x,squad.position.x)
	squad.mass = mass
	squad.lastAdvance = squad.lastAdvance or 0
	squad.leaderPos = squad.leaderPos or self.ai.tool:RezTable()
	for i,member in pairs(squad.members) do
		if member.unit then
			squad.leader = member.unit:Internal():ID()
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
	if not squad or not target  then
		self:Warn('missing parameter in find path')
		return
	end
	self:EchoDebug('search a path for ',squad.squadID,target.X,target.Z)
	local path = self.ai.maphst:getPath(game:GetUnitByID(squad.leader):Name(),squad.leaderPos,self.ai.maphst:GridToPos(target.X,target.Z),true)
	if not path then
		self:EchoDebug('no path for ', game:GetUnitByID(squad.leader):Name(),squad.leaderPos,target.X,target.Z)
	end
	self:EchoDebug("got path of", #path, "nodes")
	return path,1
end

function AttackHST:SquadAdvance(squad)
	
	if game:Frame() < squad.lastAdvance + 30 then
		return
	end
	if not squad.target then
		return
	end
	self:EchoDebug("advance squad:",squad.squadID)
	squad.lastAdvance = game:Frame()
	squad.idleCount = 0
	squad.cmdUnitId = self.ai.tool:ResetTable(squad.cmdUnitId)
	if squad.role == 'prevent' then
		for i,member in pairs(squad.members) do
			squad.cmdUnitId[i] = member.unit:Internal():ID()
		end
		self.ai.tool:GiveOrder(squad.cmdUnitId,CMD.FIGHT ,self.ai.maphst:GridToPos(squad.target.X,squad.target.Z),0,'1-2')
		return
	end
	self:SquadStepComplete(squad)
	self:EchoDebug('advance #members',#squad.members,'remaining step',#squad.path)
	for i,member in pairs(squad.members) do
		squad.cmdUnitId[i] = member.unit:Internal():ID()--:TODO unit can be nil!!
	end
	if self.ai.tool:distance(squad.position,self.ai.maphst:GridToPos(squad.target.X,squad.target.Z)) < 512 then
		self.ai.tool:GiveOrder(squad.cmdUnitId,CMD.FIGHT ,squad.path[squad.step],0,'1-2')
	else
		self.ai.tool:GiveOrder(squad.cmdUnitId,CMD.MOVE ,squad.path[squad.step],0,'1-2')
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

function AttackHST:SquadsTargetUpdate()
	for id,squad in pairs(self.squads) do
		if squad.target and squad.role == 'offense' and self.ai.maphst:GetCell(squad.target.X,squad.target.Z,self.ai.loshst.ENEMY) then
			self:EchoDebug('squadID',squad.squadID, 'offense cell', squad.target.X,squad.target.Z)
		else
			self:SquadResetTarget(squad)
			--local defense = self:SquadsTargetDefense(squad)
-- 			if defense then
-- 				squad.target = defense
-- 				squad.role = 'defense'
-- 				self:EchoDebug('set defensive target for',squad.squadID,squad.target.X,squad.target.Z)
-- 			else
			local offense = self:SquadsTargetAttack(squad)
			if offense and squad.lock then
				local path, step = self:SquadFindPath(squad,offense)
				if path and step then
					squad.firstAttack = true
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
					self:EchoDebug('squad', squad.squadID, 'have no target')
				end
			end
		end
	end
end

function AttackHST:SquadsTargetPrevent(squad)
	local frontDist = math.huge
	local preventCell = nil
	local X,Z
	for id,role in pairs(self.ai.buildingshst.roles) do
		if role.role == 'expand' then
		local builderPos = game:GetUnitByID(id):GetPosition()
			local dist = self.ai.tool:distance(builderPos,squad.position)
			if dist < frontDist then
				X,Z = self.ai.maphst:PosToGrid(builderPos)
				frontDist = dist
				preventCell = {X = X,Z = Z}
			end
		end
	end
	return preventCell
end

function AttackHST:SquadsTargetPrevent2(squad)
	local targetDist = math.huge
	local targetCell
	for index,blob in pairs(self.ai.targethst.MOBILE_BLOBS)do
		local dist = self.ai.tool:distance(blob.position,self.ai.loshst.CENTER)
		if dist < targetDist then
			targetDist = dist
			targetCell = {X = blob.targetCell.X,Z = blob.targetCell.Z}
		end
	end
	return  targetCell
end

function AttackHST:SquadsTargetAttack(squad)
	local bestTarget = nil
	local worstDist = 0
	local bestDist = math.huge
	local dist
	self:EchoDebug('search a offensive target for squad ', squad.squadID)
	for ref, blob in pairs(self.ai.targethst.IMMOBILE_BLOBS) do
		if self.ai.loshst.ENEMY[blob.targetCell.X][blob.targetCell.Z] then
			if not self:SquadsTargetHandled(self.ai.loshst.ENEMY[blob.targetCell.X][blob.targetCell.Z])  or squad.squadID == not self:SquadsTargetHandled(self.ai.loshst.ENEMY[blob.targetCell.X][blob.targetCell.Z])then
				local mclass =self.ai.armyhst.unitTable[game:GetUnitByID(squad.leader):Name()].mclass
				local path = map:PathTest(mclass,squad.leaderPos.x,squad.leaderPos.y,squad.leaderPos.z,blob.position.x,blob.position.y,blob.position.z,8)
				if path then
					if squad.firstAttack then
						dist = self.ai.tool:distance(blob.position,squad.position)
						if dist < bestDist then
							bestDist = dist
							bestTarget = {X = blob.targetCell.X, Z = blob.targetCell.Z}
						end
					else
						dist = self.ai.tool:distance(blob.position,self.ai.targethst.enemyCenter)
						if dist > worstDist then
							worstDist = dist
							bestTarget = {X = blob.targetCell.X, Z = blob.targetCell.Z}
						end
					end
					
				end
			end
		end
		--end
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
	for index,member in pairs(attkbhvr.squad.members)do
		if member == attkbhvr then
			table.remove(attkbhvr.squad.members, index)
			if #attkbhvr.squad.members == 0 then
				self:SquadDisband(attkbhvr.squad)
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
			table.insert(self.recruits[mtype], attkbhvr)
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
		attkbhvr.squad.idleCount = (attkbhvr.squad.idleCount or 0) + 1
	end
end

function AttackHST:visualDBG()
	if not self.ai.drawDebug then
		return
	end
	self.map:EraseAll(self.debugChannel)
	for index , squad in pairs(self.squads) do
		self.map:DrawCircle(squad.position,100, squad.colour, squad.squadID,squad.lock, self.debugChannel)
		for i,member in pairs(squad.members) do
			if member.unit then
				member.unit:Internal():EraseHighlight(nil, nil, self.debugChannel )
				member.unit:Internal():DrawHighlight(squad.colour ,nil , self.debugChannel )
			end
		end
		if squad.path then
			for i , p in pairs(squad.path) do
				self.map:DrawPoint(p, squad.colour, i, self.debugChannel)
			end
		end
		if squad.target then
			self.map:DrawPoint(squad.target.POS, squad.colour, squad.role .. squad.squadID, self.debugChannel)
			map:DrawLine(squad.position,squad.target.POS,squad.colour,nil,nil,self.debugChannel)
		end
	end
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




function AttackHST:SquadAttackbackup(squad)
	if not squad.target then
		self:EchoDebug('squad',squad.squadID,'no target to attack')
		return
	end
	local _ids = {}
	local _params = {}
	local _options = {}
	local _cmd = {}
	if self.ai.loshst.OWN[squad.target.X] and self.ai.loshst.OWN[squad.target.X][squad.target.Z] then
		self:EchoDebug('squad',squad.squadID,'attack a defensive position',squad.target.X,squad.target.Z)
		for i,member in pairs(squad.members) do
			
		end
		for i,member in pairs(squad.members) do
			table.insert(_ids, member.unit:Internal():ID())
			table.insert(_params, squad.target.POS)
			table.insert(_options, 0)
			table.insert(_cmd, CMD.FIGHT)
			
		end
		self.ai.tool:GiveOrder(_ids,_cmd,_params,_options,'1-2')
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
			
			table.insert(_ids, member.unit:Internal():ID())
			table.insert(_params, squad.target.POS)
			table.insert(_options, 0)
			table.insert(_cmd, CMD.FIGHT)
			
		end
		self.ai.tool:GiveOrder(_ids,_cmd,_params,_options,'1-2')
		return true
	end
end



--[[


function AttackHST:SquadAttack(squad)
	if not squad.target then
		self:EchoDebug('squad',squad.squadID,'no target to attack')
		return
	end
	local _ids = {}
	local _params = {}
	local _options = {}
	local _cmd = {}
	if self.ai.loshst.OWN[squad.target.X] and self.ai.loshst.OWN[squad.target.X][squad.target.Z] then
		self:EchoDebug('squad',squad.squadID,'attack a defensive position',squad.target.X,squad.target.Z)
		for i,member in pairs(squad.members) do
			
		end
		for i,member in pairs(squad.members) do
			table.insert(_ids, member.unit:Internal():ID())
			table.insert(_params, squad.target.POS)
			table.insert(_options, 0)
			table.insert(_cmd, CMD.FIGHT)
			
		end
		self.ai.tool:GiveOrder(_ids,_cmd,_params,_options,'1-2')
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
			
			table.insert(_ids, member.unit:Internal():ID())
			table.insert(_params, squad.target.POS)
			table.insert(_options, 0)
			table.insert(_cmd, CMD.FIGHT)
			
		end
		self.ai.tool:GiveOrder(_ids,_cmd,_params,_options,'1-2')
		return true
	end
end]]