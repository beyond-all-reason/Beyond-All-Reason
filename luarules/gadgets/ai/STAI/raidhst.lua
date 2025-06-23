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
	self.countLimit = 1
	self.squadFreezedTime = 300
	self.debugChannel = 6	
end


function RaidHST:SetMassLimit()
	self.squadMassLimit = math.ceil(60 + self.ai.ecohst.Metal.income * 60)
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
		if not member.unit or not member.unit:Internal():GetPosition()	then
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
	self:EchoDebug('step complete',squad.step,squad.position.x,squad.position.z,squad.path[squad.step].x,squad.path[squad.step].z)
	if self.ai.tool:RawDistance(squad.position.x,0,squad.position.z,squad.path[squad.step].x,0,squad.path[squad.step].z) < 256 then
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
	
	if not squad.target or not squad.path then
		return
	end
	squad.lastAdvance = game:Frame()
	squad.idleCount = 0
	squad.cmdUnitId = self.ai.tool:ResetTable(squad.cmdUnitId)
	if type(squad.role ) == 'number'  and game:GetUnitByID(squad.role):GetPosition()then
		self:EchoDebug(squad.squadID,'prevent',squad.role)
		local preventThreat = nil
		local targetPos = game:GetUnitByID(squad.role):GetPosition()
		for i,blob in pairs(self.ai.targethst.MOBILE_BLOBS) do
			
			if self.ai.tool:distance(blob.position,targetPos) < self.ai.maphst.gridSizeDouble then
				preventThreat = blob.position
				break
			end
		
		end
		if preventThreat then
			for i,member in pairs(squad.members) do
				squad.cmdUnitId[i] = member.unit:Internal():ID()
			end
			self.ai.tool:GiveOrder(squad.cmdUnitId,CMD.FIGHT ,preventThreat,0,'1-2')
			self:EchoDebug('preventThreat',preventThreat)
			return
		end

		for i,member in pairs(squad.members) do
			local lastCommand,lastTarget = member:GetLastCommandReceived()
			self:EchoDebug('lastCommand,lastTarget',lastCommand,lastTarget)
			if lastCommand ~= CMD.GUARD or lastTarget ~= squad.target then
				squad.cmdUnitId[i] = member.unit:Internal():ID()
				member:SetLastCommandReceived(CMD.GUARD,squad.role)
			end
		end
		if #squad.cmdUnitId > 0 then
			self.ai.tool:GiveOrder(squad.cmdUnitId,CMD.GUARD ,squad.role,0,'1-2')
			self:EchoDebug('prevent normal guard')
		end
		return
	end
	self:SquadStepComplete(squad)
	self:EchoDebug('advance #members',#squad.members,'path lenght',#squad.path)
	
	for i,member in pairs(squad.members) do
		squad.cmdUnitId[i] = member.unit:Internal():ID()
	end
	self.ai.tool:GiveOrder(squad.cmdUnitId,CMD.MOVE ,squad.path[squad.step],0,'1-2')
	self:EchoDebug('advance after members move')
end



function RaidHST:SquadsTargetUpdate()
	self:EchoDebug('SquadsTargetUpdate')
	for id,squad in pairs(self.squads) do
		if squad.target and squad.role == 'offense' and self.ai.maphst:GetCell(squad.target.X,squad.target.Z,self.ai.loshst.ENEMY) then
			self:EchoDebug('squadID',squad.squadID, 'have offense cell', squad.target.X,squad.target.Z)
		elseif squad.target and type(squad.role) == 'number' and game:GetUnitByID(squad.role):GetPosition() then
			self:EchoDebug('squad' , squad.squadID, 'guard ', squad.role)
		else
			self:SquadResetTarget(squad)
			if self.ai.armyhst.unitTable[ game:GetUnitByID(squad.leader):Name()].techLevel <= 2 then
				local prevent, targetID = self:SquadsTargetPrevent(squad)
				if prevent then
					self:EchoDebug('prevent set for ',squad.squadID,targetID)
					squad.target = prevent
					squad.role = targetID
					squad.step = 1
					squad.path = {}
					squad.path[1] = {}
					squad.path[1].x,squad.path[1].y,squad.path[1].z = self.ai.maphst:GridToRawPos(squad.target.X,squad.target.Z)
					self:EchoDebug('set preventive target for',squad.squadID,squad.target.X,squad.target.Z)
				end
			end
			
			if squad.lock then
				local offense = self:SquadsTargetAttack(squad)
				if offense then
					local path, step = self:SquadFindPath(squad,offense)
					if path and step then
						squad.target = offense
						squad.role = 'offense'
						squad.path = path
						squad.step = step
						self:EchoDebug('set offensive target for',squad.squadID,squad.target.X,squad.target.Z)
					end
				end
			end
			--[[if not squad.target then
				
				local defense = self:SquadsTargetDefense(squad)
				if defense then
					squad.target = defense
					squad.role = 'defense'
					squad.step = 1
					squad.path = {}
					squad.path[1] = {}
					squad.path[1].x,squad.path[1].y,squad.path[1].z = self.ai.maphst:GridToRawPos(squad.target.X,squad.target.Z)
					self:EchoDebug('set defensive target for',squad.squadID,squad.target.X,squad.target.Z)
				end
			end]]
			if not squad.target then
				self:EchoDebug("can't assign target to squad", squad.squadID)
			end
			--end
		end
	end
end

function RaidHST:SquadsTargetHandled(target,role)
	if role then
		for squadID,squad in pairs(self.squads) do
			if squad.role and squad.role == role  then
				self:EchoDebug(role,'handled by squad',squad.squadID)
				return squad.squadID
				
			end
		end
	end
	if target then
		for squadID,squad in pairs(self.squads) do
			if squad.target and squad.target.X == target.targetCell.X and squad.target.Z == target.targetCell.Z then
				self:EchoDebug(target.X,target.Z,'handled by squad',squad.squadID)
				return squad.squadID
			end
		end
	end
end

function RaidHST:SquadsTargetPrevent(squad)
	local frontDist = math.huge
	local preventCell = nil
	local targetID = nil
	self:EchoDebug('set target prevent for', squad.squadID)
	for id,role in pairs(self.ai.buildingshst.roles) do
		if role.role == 'expand' or role.role == 'support' or role.role == 'default' then
			local builder = game:GetUnitByID(id)
			self:EchoDebug('try to prevent for',id)
			if not self:SquadsTargetHandled(nil,id)  then
				self:EchoDebug('prevent not handled', id)
				local builderPos = builder:GetPosition()
				local cell = self.ai.maphst:GetCell(builderPos,self.ai.maphst.GRID)
				local dist = self.ai.tool:distance(cell.POS,squad.position)
				if dist < frontDist then
					preventCell = {X=cell.X,Z = cell.Z}
					targetID = id
				end
			end
		end
	end
	return preventCell, targetID
end

function RaidHST:SquadsTargetDefense(squad)
	self:EchoDebug('defensive target')
	local targetDist = math.huge
	local targetCell
	for index,blob in pairs(self.ai.targethst.MOBILE_BLOBS)do
		if self.ai.loshst.ENEMY[blob.targetCell.X][blob.targetCell.Z] then
			if self.ai.maphst:UnitCanGoHere(game:GetUnitByID(squad.leader), blob.position) then
				
				
				local dist = self.ai.tool:distance(blob.position,self.ai.loshst.CENTER)
				if dist < targetDist then
					targetDist = dist
					targetCell = {X = blob.targetCell.X,Z = blob.targetCell.Z}
				end
			end
		end
	end
	return  targetCell
end

function RaidHST:SquadsTargetAttack(squad)
	self:EchoDebug('set target attack for', squad.squadID)
	local bestTarget = nil
	local worstDist = -1
	for ref, blob in pairs(self.ai.targethst.IMMOBILE_BLOBS) do
		if not self:SquadsTargetHandled(blob) then
			if self.ai.loshst.ENEMY[blob.targetCell.X][blob.targetCell.Z] then
				if self.ai.maphst:UnitCanGoHere(game:GetUnitByID(squad.leader), blob.position) then
					local dist = self.ai.tool:distance(blob.position,self.ai.targethst.enemyCenter)
					if dist > worstDist then
						worstDist = dist
						bestTarget = {X = blob.targetCell.X,Z = blob.targetCell.Z}
					end
				end
			end
		end
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
			table.remove(rdbhvr.squad.members, index)
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

function RaidHST:AddRecruit(raider)
	
	--[[if not self:IsRecruit(rdbhvr) then
		local scoutMtypeCount = 0
		for scoutID, scout in pairs(self.ai.scouthst.scouts) do
			if scout.mtype == rdbhvr.mtype then
				scoutMtypeCount = scoutMtypeCount + 1
			end
		end
		if scoutMtypeCount > 3 and rdbhvr.unit ~= nil then
			--local mtype = self.ai.maphst:MobilityOfUnit(rdbhvr.unit:Internal())
			if self.recruits[rdbhvr.mtype] == nil then self.recruits[rdbhvr.mtype] = self.ai.tool:ResetTable(self.recruits[mtype]) end
			table.insert(self.recruits[rdbhvr.mtype], rdbhvr)
			rdbhvr:Free()
			self.ai.scouthst.scouts[rdbhvr.id] = nil
		else
			self:EchoDebug("unit is nil!")
		end
	end]]
	if not self:IsRecruit(raider) then
		if raider.unit ~= nil then
			local mtype = self.ai.maphst:MobilityOfUnit(raider.unit:Internal())
			if self.recruits[mtype] == nil then self.recruits[mtype] = {} end
			table.insert(self.recruits[mtype], raider)
			raider:Free()
		else
			self:EchoDebug("unit is nil!")
		end
	end
end

function RaidHST:SquadHaveTarget(raiderSquad)
	if raiderSquad and self.squads[raiderSquad].target then
		return true
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

function RaidHST:IsSoldier(raiderBehaviour)
	for index, squad in pairs(self.squads) do
		for i,member in pairs(squad.members) do
			if member.unit and member.unit:Internal():ID() == raiderBehaviour then
				return true
			end
		end
	end
end

function RaidHST:RaiderHaveTarget(raiderID)
	for index, squad in pairs(self.squads) do
		for i,member in pairs(squad.members) do
			
			if member.unit and member.unit:Internal():ID() == raiderID then
				if squad.target then
					return true
				end
				
			end
		end
	end
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