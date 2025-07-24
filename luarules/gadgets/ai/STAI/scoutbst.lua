ScoutBST = class(Behaviour)

function ScoutBST:Name()
	return "ScoutBST"
end

function ScoutBST:Init()
	self.id = self.unit:Internal():ID()
	self.name = self.unit:Internal():Name()
	self.DebugEnabled = false
	self.target = nil
	self.attacking = nil
	self.evading = nil
	self.position = self.unit:Internal():GetPosition()
	self.mtype, self.network = self.ai.maphst:MobilityOfUnit(self.unit:Internal())
	self.name = self.unit:Internal():Name()
	self.isWeapon = self.ai.armyhst.unitTable[self.name].isWeapon
	self.keepYourDistance = self.ai.armyhst.unitTable[self.name].sightDistance * 0.5
	if self.mtype == "air" then
		self.airDistance = self.ai.armyhst.unitTable[self.name].sightDistance * 1.5
		self.lastCircleFrame = self.game:Frame()
	end
	self.lastUpdateFrame = self.game:Frame()
	self.ai.scouthst.scouts[self.id] = self

end

function ScoutBST:Update()
	if self.ai.schedulerhst.behaviourTeam ~= self.ai.id or self.ai.schedulerhst.behaviourUpdate ~= 'ScoutBST' then
		return
	end
	if game:Frame() < self.lastUpdateFrame + 30 then
		return
	end
	if self.ai.raidhst:RaiderHaveTarget(self.id) then
		return
	end
	
	self.position.x, self.position.y ,self.position.z = self.unit:Internal():GetRawPos()
	local X,Z = self.ai.maphst:PosToGrid(self.position)
	self.ai.scouthst.SCOUTED[X] = self.ai.scouthst.SCOUTED[X] or {}
	self.ai.scouthst.SCOUTED[X][Z] = game:Frame()
	self:EchoDebug('scout',self.id,'scoutCell',X,Z,game:Frame())
	local _,_,_,_, buildProgress,relativeHealth = self.unit:Internal():GetHealtsParams()
	if 	relativeHealth < 0.90 and buildProgress == 1 and not self.attacking then
		self:Evading()
		return
	else
		self.evading = nil
	end
	if self:ImmediateEnemy() then
		if self.attacking then
			self:Attacking()
		elseif self.avoiding then
			self:Avoid()
		end
		return
	end
	if not self.target  and not self.attacking and not self.avoiding  then
		self:EchoDebug('no scout target for:', self.id)
		self.target = self.ai.scouthst:ClosestSpot2(self)
	end
	if self.target then
		local X,Z = self.ai.maphst:PosToGrid(self.target)
		self:EchoDebug(self.id,'target:',self.target,X,Z)
		if not self.ai.scouthst:TargetAvailable(X,Z,self.id) then
			self.target = nil
			return
		end
		--if self.target then
		self:Scouting()
		--end
	end
	self.unit:ElectBehaviour()
end

function ScoutBST:Priority()
	return 100
end

function ScoutBST:Activate()
	self:EchoDebug("activated on " .. self.name)
end

function ScoutBST:Deactivate()
	self:EchoDebug("deactivated on " .. self.name)
	self.target = nil
	self.evading = nil
	self.attacking = nil
end

function ScoutBST:OwnerDead()
	self.ai.scouthst.scouts[self.id] = nil
end

function ScoutBST:Evading()
	self:EchoDebug('evading')
	if self.evading and game:GetUnitByID(self.evading) and game:GetUnitByID(self.evading):GetPosition() then
		return
	end
	self.target = nil
	self.attacking = nil

	local home = self.ai.labshst:ClosestHighestLevelFactory(self.unit:Internal())
	if home then
		self.ai.tool:GiveOrder(self.id,CMD.MOVE, self.ai.tool:RandomAway2(home.position,300), 0,'1-1')
		self.evading = home.id
	end
end

function ScoutBST:Avoid()
	self:EchoDebug('avoid')
	if self.avoiding and game:GetUnitByID(self.avoiding) then
		local enemyPos = game:GetUnitByID(self.avoiding):GetPosition()
		local avoidingX = 1
		local avoidingZ = 1
		if self.position.x - enemyPos.x < 0 then
			avoidingX = -1

		end
		if self.position.z - enemyPos.z < 0 then
			avoidingZ = -1	
		end
		avoidingX = self.position.x + ( self.keepYourDistance * avoidingX )
		avoidingZ = self.position.z + ( self.keepYourDistance * avoidingZ )
		enemyPos.x = avoidingX
		enemyPos.z = avoidingZ
		self.ai.tool:GiveOrder(self.id,CMD.MOVE, enemyPos, 0,'1-1')
	end
end

function ScoutBST:Attacking()
	self:EchoDebug('attacking')
	if not self.attacking then return end
	if not self.ai.loshst.losEnemy[self.attacking] or not game:GetUnitByID(self.attacking) or not game:GetUnitByID(self.attacking):GetPosition() then
		self.attacking = nil
		return
	end
	self.target = nil
	self.ai.tool:GiveOrder(self.id,CMD.FIGHT, game:GetUnitByID(self.attacking):GetPosition(), 0,'1-1')
	
end

function ScoutBST:Scouting()
	self:EchoDebug('scouting')
	if self.unit:Internal():CurrentCommand()  ~= CMD.MOVE then
		self.ai.tool:GiveOrder(self.id,CMD.MOVE, self.target, 0,'1-1')
	end
	
end



function ScoutBST:ImmediateEnemy()
	local nearestEnemy = Spring.GetUnitNearestEnemy(self.id,self.ai.armyhst.unitTable[self.name].sightDistance,true)
	
	if nearestEnemy then
		local enemyPos = game:GetUnitByID(nearestEnemy):GetPosition()
		local enemyIsArmed = self.ai.armyhst.unitTable[game:GetUnitByID(nearestEnemy):Name()].isWeapon
		if enemyIsArmed then
			
			if self.ai.armyhst.unitTable[game:GetUnitByID(nearestEnemy):Name()].metalCost <= self.ai.armyhst.unitTable[self.name].metalCost then
				self:EchoDebug('immediate target',nearestEnemy)
				self.attacking = nearestEnemy
				self.avoiding = nil
				return nearestEnemy
			end
			if self.ai.tool:distance(self.position,enemyPos) < self.ai.armyhst.unitTable[game:GetUnitByID(nearestEnemy):Name()].sightDistance then
				self:EchoDebug('immediate danger',nearestEnemy)
				self.avoiding = nearestEnemy
				self.attacking = nil
				return nearestEnemy
			end
		else
			self.attacking = nearestEnemy
			self.avoiding = nil
			self:EchoDebug('immediate target',nearestEnemy)
			return nearestEnemy
		end
	end
	self.avoiding = nil
	self.attacking = nil
end

function ScoutBST:bestAdjacentPos(unit,target)
	local upos = self.position
	local X, Z = self.ai.maphst:PosToGrid(upos)
	local areacells = self.ai.maphst:areaCells(X,Z,1,self.ai.loshst.ENEMY)
	local risky = {}
	local greedy = {}
	local neutral = {}
	local gluttony = 0
	local tg = nil
	for _, cell in pairs(areacells) do
		if cell.ARMED < 1 and cell.UNARM > 0 then
			table.insert(greedy,cell)
		elseif cell.ARMED > 0 and cell.UNARM > 0 then
			table.insert(risky,cell)
		else
			table.insert(neutral,cell)
		end
	end
	for _,cell in pairs(greedy)do
		if cell.UNARM > gluttony then
			gluttony = cell.UNARM
			tg = cell
		end
	end
	if tg then return tg.pos end
	for _,cell in pairs(neutral)do
		if cell.UNARM > gluttony then
			gluttony = cell.UNARM
			tg = cell
		end
	end
	if tg then return tg.pos end
	for _,cell in pairs(risky)do
		if cell.UNARM > gluttony then
			gluttony = cell.UNARM
			tg = cell
		end
	end
	if tg then return tg.pos end
end


















function ScoutBST:Draw()
	if not self.ai.scouthst.scouts[self.id] then
		return
	end
	if not self.ai.schedulerhst.behaviourTeam == self.ai.id or self.ai.schedulerhst.behaviourUpdate ~= 'ScoutBST' then
		return
	end
	if not self.target then return end
	local scoutPos = self.position
	local targetPos = self.target
	gl.PushMatrix()
	gl.Color(0,1,0,0.5)
	gl.LineWidth(2)
	gl.BeginEnd(GL.LINE_STRIP, function()
		gl.Vertex(scoutPos.x,scoutPos.y,scoutPos.z)
		gl.Vertex(targetPos.x,targetPos.y,targetPos.z)
	end)
	gl.PopMatrix()
end

function ScoutBST:OwnerMoveFailed(unit)
	self:Warn('OWNER MOVE FAILED')
	self:Evading()
end
