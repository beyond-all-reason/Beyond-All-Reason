BomberHST = class(Module)

function BomberHST:Name()
	return "BomberHST"
end

function BomberHST:internalName()
	return "bomberhst"
end

function BomberHST:Init()
	self.DebugEnabled = false
	self.recruits = {}
	self.squads = {}
	self.squadID = 1
end

function BomberHST:Update()
	if self.ai.schedulerhst.moduleTeam ~= self.ai.id or self.ai.schedulerhst.moduleUpdate ~= self:Name() then return end
	self:SetMassLimit()
	self:DraftBomberSquads()
	for index,squad in pairs(self.squads) do
		if self:SquadsIntegrityCheck(squad) then
			self:SquadPosition(squad)
			self:SquadMass(squad)
			self:SquadsTargetUpdate(squad)
		end
	end
end

function BomberHST:IsRecruit(bmbrbehaviour)
	if self.recruits[bmbrbehaviour].id then
		return true
	end
end

function BomberHST:AddRecruit(bmbrbehaviour)
	self.recruits[bmbrbehaviour.id] = bmbrbehaviour
end

function BomberHST:RemoveRecruit(bmbrbehaviour)
	self.recruits[bmbrbehaviour.id] = nil
end

function BomberHST:SetMassLimit()
	self.squadMassLimit = 0 + (math.max(self.ai.ecohst.Metal.income * 20, 4000))
	self:EchoDebug('squadmasslimit',self.squadMassLimit)
end

function BomberHST:SquadsIntegrityCheck(squad)
	self:EchoDebug('integrity',squad.squadID)
	for id,member in pairs(squad.members) do
		if not self.ai.tool:UnitPos(member) then
			squad.members[id] = nil
			self:RemoveRecruit(member)
		end
	end

	for id,_ in pairs(squad.members) do
		return true
	end

	self:SquadDisband(squad, squad.squadID)
end

function BomberHST:SquadDisband(squad)
	self:EchoDebug("disband squad")
	self.squads[squad.squadID] = nil
end

function BomberHST:DraftBomberSquads()
	local f = self.game:Frame()
	for id, bomber in pairs(self.recruits) do
		if not bomber.squad then
			for index,squad in pairs(self.squads) do
				if not squad.lock and squad.layer == bomber.layer then
					squad.members[id] = bomber
					bomber.squad = index
					squad.counter = squad.counter + 1
					if (squad.mass > self.squadMassLimit or #squad.members > 10) or (squad.mass > 2000)then
						squad.lock = true
					end
				end
			end
			if not bomber.squad then
				self.squadID = self.squadID + 1
				self.squads[self.squadID] = {}
				local squad = self.squads[self.squadID]
				squad.members = {}
				squad.squadID = self.squadID
				squad.members[bomber.id] = bomber
				squad.counter = 1
				squad.layer = bomber.layer
				squad.mass = 0
				bomber.squad = self.squadID
				squad.colour = {0,math.random(),math.random(),1}
				if (squad.mass > self.squadMassLimit ) or (squad.mass > 2000)then
					squad.lock = true
				end
			end
		end
	end
end

function BomberHST:SquadPosition(squad)
	local p = {x=0,z=0}
	squad.counter = 0
	for i,member in pairs(squad.members) do
		local uPos = self.ai.tool:UnitPos(member)
		p.x = p.x + uPos.x
		p.z = p.z + uPos.z
		squad.counter = squad.counter + 1
	end
	p.x = p.x / squad.counter
	p.z = p.z / squad.counter
	p.y = map:GetGroundHeight(p.x,p.z)
	squad.position = p
	self:EchoDebug('squad position',p.x,p.z)
end

function BomberHST:SquadMass(squad)
	squad.mass = 0
	for i,bmbrbehaviour in pairs(squad.members) do
		local mass = bmbrbehaviour.mass
		squad.mass = squad.mass + mass
	end
	if (squad.mass > self.squadMassLimit or #squad.members >= 20)then
		squad.lock = true
	end
	self:EchoDebug('squad mass',squad.mass)
end

function BomberHST:SquadsTargetUpdate(squad)
	self:EchoDebug(squad.lock , squad.target ,self:SquadTargetExist(squad))
	if squad.lock and (not squad.target or not self:SquadTargetExist(squad)) then
		self:GetTarget(squad)
	end
end

function BomberHST:SquadTargetExist(squad)
	if squad.target then --maybe the target is already nil if the cell is destroied??
		if not self.ai.loshst.ENEMY[squad.target.X] or not self.ai.loshst.ENEMY[squad.target.X][squad.target.Z] then
			self:EchoDebug('squad' ,squad.squadID,'target',X,Z,'no more available, Reset!')
			squad.target = nil
			squad.targetUnit = nil
			return false
		end
	end
	return true
end

function BomberHST:GetTarget(squad)
	self:EchoDebug('squad ',squad.squadID,'get new target')
	local bestCell = nil
	local bestValue = 0
	for X,cells in pairs(self.ai.loshst.ENEMY) do
		for Z,cell in pairs(cells) do
			if squad.layer == 'S' then
				if cell.POS.y < 5 then
					if cell.BUILDINGS > bestValue then
						bestValue = cell.BUILDINGS
						bestCell = cell
					end
				end
			else
				if cell.POS.y > -5 then
					if cell.BUILDINGS > bestValue then
						bestValue = cell.BUILDINGS
						bestCell = cell
					end
				end
			end
		end
	end
	if bestCell then
		self:EchoDebug('get a valuable target')
		squad.target = bestCell
		local bu
		local bv = 0
		for id,M in pairs(bestCell.units) do
			local unit = game:GetUnitByID(id)
			local uName = unit:Name()
			local ut = self.ai.armyhst.unitTable[uName]
			self:EchoDebug(id,uName,ut.metalCost)
			if ut.metalCost > bv then
				bv = ut.metalCost
				bu = id
			end
		end
		if bu then
			self:EchoDebug('get a unit to bomb')
			squad.targetUnit = bu
		end
	end
end
