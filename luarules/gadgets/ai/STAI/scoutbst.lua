ScoutBST = class(Behaviour)

function ScoutBST:Name()
	return "ScoutBST"
end

function ScoutBST:Init()
	self.id = self.unit:Internal():ID()
	self.DebugEnabled = false
	self.target = nil
	self.attacking = nil
	self.evading = nil
	self.active = false
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

function ScoutBST:Priority()
	return 100
end

function ScoutBST:Activate()
	self:EchoDebug("activated on " .. self.name)
	self.active = true
end

function ScoutBST:Deactivate()
	self:EchoDebug("deactivated on " .. self.name)
	self.active = false
	self.target = nil
	self.evading = nil
	self.attacking = nil
end


function ScoutBST:OwnerDead()
	self.ai.scouthst.scouts[self.id] = nil
end

function ScoutBST:Evading()
	self:EchoDebug('evading')
	self.target = nil
	self.evading = true
	self.attacking = nil
	local home = self.ai.labshst:ClosestHighestLevelFactory(self.unit:Internal())
	if home then
		home = home.position
	else
		home = self.position
	end

	home = self.ai.tool:RandomAway2(home,300)
	if home then
		self.unit:Internal():Move(home)
	end
end

function ScoutBST:Attacking()
	self:EchoDebug('attacking')
	if not self.attacking then return end
	if not self.ai.loshst.losEnemy[self.attacking] then
		self.attacking = nil
		return
	end
	self.target = nil
	self:AttackMove( self.attacking.POS )
end

function ScoutBST:Scouting()
	self:EchoDebug('scouting')
	local randomAway = self.ai.tool:RandomAway2(self.target,128)
	self.unit:Internal():Move(randomAway)
end

function ScoutBST:ImmediateTarget()
	self:EchoDebug('immediate targeting')
	local scoutPos = self.position
	local bestDist = math.huge
	if self.target then
		bestDist = self.ai.tool:distance(scoutPos,self.target)
	end
	local attack
	for Z,cells in pairs(self.ai.loshst.ENEMY) do
		for X, cell in pairs(cells) do
			--local danger,subValues, targetCells = self.ai.maphst:getCellsFields(cell.POS,{'ARMED'},1,self.ai.loshst.ENEMY)
			if self.ai.maphst:UnitCanGoHere(self.unit:Internal(),cell.POS) then
				local danger = cell.ENEMY_BALANCE
				local unarm = cell.UNARM
				if danger == 0 and unarm > 0 then
					local d = self.ai.tool:DISTANCE(scoutPos,cell.POS)
					if d < bestDist then
						bestDist = d
						attack = cell
					end
				end
			end
		end
	end
	self:EchoDebug('attack target' ,attack)
	return attack
end




function ScoutBST:Update()
	if self.ai.schedulerhst.behaviourTeam ~= self.ai.id or self.ai.schedulerhst.behaviourUpdate ~= 'ScoutBST' then
		return
	end
	if self.active then
		local unit = self.unit:Internal()
		self.position.x, self.position.y ,self.position.z = unit:GetRawPos()
		local X,Z = self.ai.maphst:PosToGrid(self.position)
		self.ai.scouthst.SCOUTED[X] = self.ai.scouthst.SCOUTED[X] or {}
		self.ai.scouthst.SCOUTED[X][Z] = game:Frame()
		self:EchoDebug('scout',self.id,'scoutCell',X,Z,game:Frame())
		local health,maxHealth,paralyzeDamage, captureProgress, buildProgress,relativeHealth = unit:GetHealtsParams()
		if 	relativeHealth < 0.99 and buildProgress == 1 and not self.attacking then
			self:Evading()
			return
		else
			self.evading = nil
		end
		if not self.evading and self.isWeapon then
			--self.attacking = self:bestAdjacentPos(self.unit:Internal(),nil)
			self.attacking = self:ImmediateTarget()
		end
		if self.attacking then
			self:Attacking()
			return
		end
		if not self.target  and not self.attacking and not self.evading  then
			self.target = self.ai.scouthst:ClosestSpot2(self)
			if self.target then
				self:Scouting()
			end

		end
		if self.target then
			self:EchoDebug('check',self.id)
			local X,Z = self.ai.maphst:PosToGrid(self.target)
			if not self.ai.scouthst:TargetAvailable(X,Z,self.id) then
				self.target = nil
			end
		end
	end
	self.unit:ElectBehaviour()
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
	for index, cell in pairs(areacells) do
		if cell.ARMED < 1 and cell.UNARM > 0 then
			table.insert(greedy,cell)
		elseif cell.ARMED > 0 and cell.UNARM > 0 then
			table.insert(risky,cell)
		else
			table.insert(neutral,cell)
		end
	end
	for index,cell in pairs(greedy)do
		if cell.UNARM > gluttony then
			gluttony = cell.UNARM
			tg = cell
		end
	end
	if tg then return tg.pos end
	for index,cell in pairs(neutral)do
		if cell.UNARM > gluttony then
			gluttony = cell.UNARM
			tg = cell
		end
	end
	if tg then return tg.pos end
	for index,cell in pairs(risky)do
		if cell.UNARM > gluttony then
			gluttony = cell.UNARM
			tg = cell
		end
	end
	if tg then return tg.pos end
end
