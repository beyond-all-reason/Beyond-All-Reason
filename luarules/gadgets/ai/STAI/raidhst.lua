RaidHST = class(Module)

function RaidHST:Name()
	return "RaidHST"
end

function RaidHST:internalName()
	return "raidhst"
end

local floor = math.floor

function RaidHST:Init()
	self.DebugEnabled = false
	self.recruits = {}
	self.squads = {}
	self.squadID = 1
	self.squadMassLimit = 0
	self.countLimit = 4
	self.squadFreezedTime = 300
	self.debugChannel = 6
end


function RaidHST:SetMassLimit()
	self.squadMassLimit = math.ceil(100 + self.ai.ecohst.Metal.income * 100)
	self:EchoDebug('squad mass limit',self.squadMassLimit)
end

function RaidHST:Watchdog(squad)
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

function RaidHST:Update()
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

function RaidHST:DraftAttackSquads()
	local f = self.game:Frame()
	for mtype,soldiers in pairs(self.recruits) do
		self:EchoDebug('soldiers',#soldiers	)
		for index,soldier in pairs(soldiers) do
			if soldier and soldier.unit and not soldier.squad then
				for idx,squad in pairs(self.squads) do
					self:EchoDebug(idx,squad.squadID,squad.lock,squad.mtype)
					if not squad.lock and squad.mtype == mtype  then
						table.insert(squad.members , soldier)
						soldier.squad = squad
						--self:SquadFormation(squad)
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
					self.squads[self.squadID] = self.ai.tool:RezTable()
					local squad = self.squads[self.squadID]
					squad.members = self.ai.tool:RezTable()
					squad.squadID = self.squadID
					table.insert(squad.members , soldier)
					squad.mtype = mtype
					squad.mass = 0
					squad.role = nil
					squad.watchdogTimer = game:Frame()
					soldier.squad = squad
					squad.colour = self.ai.tool:RezTable()
					squad.colour[1] = 0
					squad.colour[2] = math.random()
					squad.colour[3] = math.random()
					squad.colour[4] = 1
					--squad.graph = self.ai.maphst:GetPathGraph(squad.mtype)
					if (squad.mass > self.squadMassLimit or #squad.members > 5 + self.ai.labshst.ECONOMY) or (squad.mass > 15000)then
						squad.lock = true

					end
				end
			end
		end
	end
end

function RaidHST:SquadCheck(squad)
	self:EchoDebug('integrity',squad.squadID,#squad.members)
	local check = nil
	local x,y,z = 0,0,0
	local mass = 0
	local memberCount = 0
	for i,member in pairs(squad.members) do
		if not member.unit 	then
			table.remove(squad.members,i)
			self:RemoveRecruit(member)
		else
			check = true
			local ux,uy,uz = member.unit:Internal():GetRawPos()
			x = x + ux
			z = z + uz
			memberCount = memberCount + 1
			mass = mass + member.mass
		end
	end
	if not check then
		self:SquadDisband(squad)
		return
	end
	squad.position = squad.position or self.ai.tool:RezTable()
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

function RaidHST:SquadDisband(squad)
	self:EchoDebug("disband squad")
	for iu, member in pairs(squad.members) do
		self:AddRecruit(member)
		member.squad = nil
	end
	--local t = table.remove(self.squads,squad.squadID):TODO do di better
	--self.ai.tool:KillTable(squad)----:TODO NONFUNGEEEE
	self.squads[squad.squadID] = nil
end

function RaidHST:SquadStepComplete(squad)
	self:EchoDebug('step complete',squad.step,squad.position.x,squad.position.z,squad.path[squad.step].x,squad.path[squad.step].z) ::TTODDKSID fixe
	if self.ai.tool:RawDistance(squad.position.x,squad.position.y,squad.position.z,squad.path[squad.step][1],squad.path[squad.step][2],squad.path[squad.step][3]) < 256 then
		squad.step = squad.step + 1
	elseif squad.idleCount > floor(#squad.members * 0.85) then
		squad.step = squad.step + 1
	end
	squad.step = math.min(#squad.path,squad.step)
end

function RaidHST:SquadFindPath(squad,target)
	if not target  then
		self:Warn('no target to search path')
		return
	end
	self:EchoDebug('search a path for ',squad.squadID,target.X,target.Z)
	local path
	if not self.ai.armyhst['airgun'][game:GetUnitByID(squad.leader):Name()] then --TODO workaraund for airgun that do not have mclass

		path = self.ai.maphst:getPath(game:GetUnitByID(squad.leader):Name(),squad.leaderPos,self.ai.maphst:GridToPos(target.X,target.Z),true)
	end

	if path then
		--table.insert(path,#path,target.POS)
 		self:EchoDebug("got path of", #path, "nodes ")
		local step = 1
		return path,step
	end
	self:EchoDebug('path not found')
	
end

function RaidHST:SquadAdvance(squad)
	self:EchoDebug("advance squad:",squad.squadID)
	if game:Frame() < squad.lastAdvance + 30 then
		return
	end
	squad.lastAdvance = game:Frame()
	squad.idleCount = 0
	if not squad.target or not squad.path then
		return
	end
	self:SquadStepComplete(squad)
	self:EchoDebug('advance #members',#squad.members,squad.path,#squad.path)
	squad.cmdUnitId = self.ai.tool:ResetTable(squad.cmdUnitId)
	for i,member in pairs(squad.members) do
		squad.cmdUnitId[i] = member.unit:Internal():ID()
	end
	if self.ai.tool:distance(squad.position,self.ai.maphst:GridToPos(squad.target.X,squad.target.Z)) < 512 then
		self.ai.tool:GiveOrder(squad.cmdUnitId,CMD.FIGHT ,squad.path[squad.step],0,'1-2')
	else
		self.ai.tool:GiveOrder(squad.cmdUnitId,CMD.MOVE ,squad.path[squad.step],0,'1-2')
	end
	self:EchoDebug('advance after members move')
end


function RaidHST:SquadsTargetHandled(target)
	if not target then
		self:EchoDebug('target handler no target to check')
		return
	end
	for squadID,squad in pairs(self.squads) do
		if squad.target and squad.target.X == target.X and squad.target.Z == target.Z then
			return squad.squadID
		end
	end
end

function RaidHST:SquadsTargetUpdate()
	for id,squad in pairs(self.squads) do
		if squad.target and squad.role == 'offense' and self.ai.maphst:GetCell(squad.target.X,squad.target.Z,self.ai.loshst.ENEMY) then
			self:EchoDebug('squadID',squad.squadID, 'have offense cell', squad.target.X,squad.target.Z)
		elseif squad.target and type(squad.role) == 'number' and game:GetUnitByID(squad.role) then
			local targetX,targetY,targetZ = game:GetUnitByID(squad.role):GetRawPos()
			self:EchoDebug('update builder prevent pos',targetX,targetY,targetZ)
			if targetX then
				local X,Z = self.ai.maphst:RawPosToGrid(targetX,targetY,targetZ)
				squad.target = {X=X, Z=Z}--self.ai.maphst:GetCell(X,Z,self.ai.maphst.GRID)
				squad.step = 1
				squad.path[1][1] = targetX
				squad.path[1][2] = targetY
				squad.path[1][3] = targetZ
				self:EchoDebug('squadID',squad.squadID, 'have preventive cell', squad.role, squad.target.X,squad.target.Z)
			end


		else
			self:SquadResetTarget(squad)
			--local defense = self:SquadsTargetDefense(squad)
-- 			if defense then
-- 				squad.target = defense
-- 				squad.role = 'defense'
-- 				self:EchoDebug('set defensive target for',squad.squadID,squad.target.X,squad.target.Z)
-- 			else

			local prevent, targetID = self:SquadsTargetPrevent(squad)
			if prevent then
				squad.target = prevent
				squad.role = targetID
				squad.step = 1
				squad.path = {}
				squad.path[1] = {}
				squad.path[1][1],squad.path[1][2],squad.path[1][3] = self.ai.maphst:GridToRawPos(squad.target.X,squad.target.Z)
				self:EchoDebug('set preventive target for',squad.squadID,squad.target.X,squad.target.Z)
			end
			local offense = self:SquadsTargetAttack(squad)
			if squad.lock and offense then
				local path, step = self:SquadFindPath(squad,offense)
				if path and step then
					squad.target = offense
					squad.role = 'offense'
					squad.path = path
					squad.step = step
					self:EchoDebug('set offensive target for',squad.squadID,squad.target.X,squad.target.Z)
				end
			end
			if not squad.target then
				self:EchoDebug("can't assign target to squad", squad.squadID)
			end
			--end
		end
	end
end

function RaidHST:SquadsTargetPrevent(squad)
	local frontDist = math.huge
	local preventCell = nil
	local targetID = nil
	for id,role in pairs(self.ai.buildingshst.roles) do
		if role.role == 'expand' then
			local builder = game:GetUnitByID(id)
			local builderPos = builder:GetPosition()
			local cell = self.ai.maphst:GetCell(builderPos,self.ai.maphst.GRID)
			--local targetHandled = self:SquadsTargetHandled(cell)
			--if not targetHandled or targetHandled == squad.squadID then
			local dist = self.ai.tool:distance(cell.POS,squad.position)
			if dist < frontDist then
				preventCell = {X=cell.X,Z = cell.Z}
				targetID = id
			end
			--end
		end
	end
	return preventCell, targetID
end

function RaidHST:SquadsTargetDefense(squad)
	local targetDist = math.huge
	local targetCell
	for index,blob in pairs(self.ai.targethst.MOBILE_BLOBS)do
		if self.ai.loshst[blob.defendCell.X][blob.defendCell.Z] then
			local dist = self.ai.tool:distance(blob.position,self.ai.loshst.CENTER)
			if dist < targetDist then
				targetDist = dist
				targetCell = {X = blob.defendCell.X,Z = blob.defendCell.Z}--self.ai.loshst[blob.defendCell.X][blob.defendCell.Z]
			end
		end
		--end
	end
	return  targetCell
end

function RaidHST:SquadsTargetAttack(squad)
	local bestTarget = nil
	local worstDist = 0
	for ref, blob in pairs(self.ai.targethst.IMMOBILE_BLOBS) do
		if self.ai.loshst.ENEMY[blob.targetCell.X][blob.targetCell.Z] then
			if self.ai.maphst:UnitCanGoHere(game:GetUnitByID(squad.leader), blob.position) then
				local dist = self.ai.tool:distance(blob.position,self.ai.targethst.enemyCenter)
				if dist > worstDist then
					worstDist = dist
					bestTarget = {X = blob.targetCell.X,Z = blob.targetCell.Z}--self.ai.loshst.ENEMY[blob.targetCell.X][blob.targetCell.Z]
					break
				end
			end
		end
		--end
	end
	return bestTarget
end

function RaidHST:SquadResetTarget(squad)
	squad.target = nil
	squad.path = nil
	squad.step = nil
	squad.role = nil
	squad.idleCount = 0
end

function RaidHST:RemoveMember(rdbhvr)
	if rdbhvr == nil then return end
	if not rdbhvr.squad then return end
	for index,member in pairs(rdbhvr.squad.members)do
		if member == rdbhvr then
			table.remove(rdbhvr.squad.members, iu)
			if #rdbhvr.squad.members == 0 then
				self:SquadDisband(rdbhvr.squad)
			end
			rdbhvr.squad = nil
			return true
		end
	end
end

function RaidHST:IsRecruit(rdbhvr)
	if rdbhvr.unit == nil then return false end
	local mtype = self.ai.maphst:MobilityOfUnit(rdbhvr.unit:Internal())
	if self.recruits[mtype] ~= nil then
		for i,v in pairs(self.recruits[mtype]) do
			if v == rdbhvr then
				return true
			end
		end
	end
	return false
end

function RaidHST:AddRecruit(rdbhvr)
	if not self:IsRecruit(rdbhvr) then
		if rdbhvr.unit ~= nil then
			local mtype = self.ai.maphst:MobilityOfUnit(rdbhvr.unit:Internal())
			if self.recruits[mtype] == nil then self.recruits[mtype] = self.ai.tool:ResetTable(self.recruits[mtype]) end
			table.insert(self.recruits[mtype], rdbhvr)
			rdbhvr:Free()
		else
			self:EchoDebug("unit is nil!")
		end
	end
end

function RaidHST:RemoveRecruit(rdbhvr)
	for mtype, recruits in pairs(self.recruits) do
		for i,v in ipairs(recruits) do
			if v == rdbhvr then
				table.remove(self.recruits[mtype], i)
				return true
			end
		end
	end
	return false
end

function RaidHST:MemberIdle(rdbhvr, squad)
	if not squad then
		self:EchoDebug('no squad for idle member')
		return
	end
	if rdbhvr then
		rdbhvr.squad.idleCount = (rdbhvr.squad.idleCount or 0) + 1
	end
end

function RaidHST:visualDBG()
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
			self.map:DrawPoint(self.ai.maphst:GridToPos(squad.target.X,squad.target.Z), squad.colour, squad.role .. squad.squadID, self.debugChannel)
			map:DrawLine(squad.position,self.ai.maphst:GridToPos(squad.target.X,squad.target.Z),squad.colour,nil,nil,self.debugChannel)
		end
	end
end







































--[[
function RaidHST:SquadAttack(squad)
	if not squad.target then
		self:EchoDebug('squad',squad.squadID,'no target to raid')
		return
	end
	local p = {}
	local cmdUnitId = {}
	local cmdUnitCommand = {}
	local cmdUnitParams = {}
	local cmdUnitOptions = {}
	if self.ai.loshst.OWN[squad.target.X] and self.ai.loshst.OWN[squad.target.X][squad.target.Z] then
		self:EchoDebug('squad',squad.squadID,'raid a defensive position',squad.target.X,squad.target.Z)

		for i,member in pairs(squad.members) do
			table.insert(cmdUnitId, member.unit:Internal():ID())
			table.insert(cmdUnitParams, squad.target.POS)
			table.insert(cmdUnitOptions, 0)
			table.insert(cmdUnitCommand, CMD.MOVE)
			--member:MoveRandom(squad.target.POS,128)
		end
		self.ai.tool:GiveOrder(cmdUnitId,cmdUnitCommand,cmdUnitParams,cmdUnitOptions,'1-2')
		self:EchoDebug('squad',squad.squadID,'execute defense')
		return true
	end
	if self.ai.loshst.ENEMY[squad.target.X] and self.ai.loshst.ENEMY[squad.target.X][squad.target.Z]  and self.ai.tool:distance(squad.position,squad.target.POS) < 256 then
		self:EchoDebug('squad',squad.squadID,'are near to offensive target, do raid')
		for i,member in pairs(squad.members) do
			table.insert(cmdUnitId, member.unit:Internal():ID())
			table.insert(cmdUnitParams, squad.target.POS)
			table.insert(cmdUnitOptions, 0)
			table.insert(cmdUnitCommand, CMD.FIGHT)
		end
		self.ai.tool:GiveOrder(cmdUnitId,cmdUnitCommand,cmdUnitParams,cmdUnitOptions,'1-2')
		self:EchoDebug('squad',squad.squadID,'execute raid')
		return true
	end
end


function RaidHST:SquadAdvanceBackup(squad)
	self:EchoDebug("advance",squad.squadID)
	if game:Frame() < squad.lastAdvance + 30 then
		return
	end
	squad.lastAdvance = game:Frame()
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
 	squad.lastValidMove = nextPos -- raiders use this to correct bad move orders
	self:EchoDebug('advance #members',#members)
	local cmdUnitId = {}
	local pos
	for i,member in pairs(members) do
		cmdUnitId[i] = member.unit:Internal():ID()
		
 		if member.formationBack and squad.step ~= #squad.path then
 			pos = self.ai.tool:RandomAway( nextPos, -member.formationBack, nil, nextAngle)
 		end
 		local reverseAttackAngle
 		if squad.step == #squad.path then
 			reverseAttackAngle = self.ai.tool:AngleAdd(nextAngle, pi)
 		end
 		--self:EchoDebug('advance',pos,nextPerpendicularAngle,reverseAttackAngle)
	end

	local p = {}
	if pos then
		p[1] = pos.x
		p[2] = pos.y
		p[3] = pos.z
	else
		p[1] = nextPos.x
		p[2] = nextPos.y
		p[3] = nextPos.z
	end

	local command = self.ai.tool:GiveOrder(cmdUnitId,CMD.MOVE ,p,0,'1-2')
	squad.lastAdvance = game:Frame()
	self:EchoDebug('advance after members move')
end
]]




--[[function RaidHST:SquadFormation(squad)
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
end]]