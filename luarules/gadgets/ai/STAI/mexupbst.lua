MexUpBST = class(Behaviour)

function MexUpBST:Name()
	return "MexUpBST"
end

function MexUpBST:Init()
	self.DebugEnabled = false
	self.active = false
	self.mohoStarted = false
	self.released = false
	self.mexPos = nil
	self.lastFrame = self.game:Frame()
	self.name = self.unit:Internal():Name()
	self.id = self.unit:Internal():ID()
	self:EchoDebug("MexUpBST: added to unit "..self.name)
end

function MexUpBST:OwnerIdle()
	if self:IsActive() then
		local builder = self.unit:Internal()
		self:EchoDebug("MexUpBST: unit ".. self.name .." is idle")
		-- maybe we've just finished a moho?
		if self.mohoStarted then
			self.mohoStarted = false
			self.mexPos = nil
		end
		-- maybe we've just finished reclaiming?
		if self.mexPos  and not self.mohoStarted then
			--builder:Build(self.upType:Name(), self.mexPos)
			self.ai.tool:GiveOrderToUnit(builder, game:GetTypeByName(self.upType:Name())*-1,self.mexPos , 0,'1-1')

			self.active = true
			self.mohoStarted = true
			self.mexPos = nil
			self:EchoDebug("MexUpBST: unit ".. self.name .." starts building a Moho")
		end
		if not self.mohoStarted and (self.mexPos == nil) then
			self:EchoDebug("MexUpBST: unit ".. self.name .." restarts mex upgrade routine")
			self:StartUpgradeProcess()
		end
	end
end

function MexUpBST:Update()
	--self.uFrame = self.uFrame or 0
	if not self.active then
		local f = self.game:Frame()
		if self.ai.schedulerhst.behaviourTeam ~= self.ai.id or self.ai.schedulerhst.behaviourUpdate ~= 'MexUpBST' then return end
		self:StartUpgradeProcess()
	end
end

function MexUpBST:Activate()
	self:EchoDebug("MexUpBST: active on unit ".. self.name)
	self:StartUpgradeProcess()
end

function MexUpBST:Deactivate()
	self.active = false
	self.mexPos = nil
	self.mohoStarted = false
	self.upType = nil
	self.mexUnit = nil
end

function MexUpBST:Priority()
	if self.upType  and self.ai.tool:listHasValue(self.ai.armyhst.buildersRole.expand[self.name]  , self.id) then
		return 99
	elseif
	self.upType  and self.ai.tool:listHasValue(self.ai.armyhst.buildersRole.eco[self.name]  , self.id) and self.ai.tool:countMyUnit({self.ai.armyhst._mex_}) < 3 and self.ai.ecohst.Metal.full < 0.3 then
		return 150
	else
		return 0
	end
end



function MexUpBST:StartUpgradeProcess()
	-- try to find nearest mex
	local selfUnit = self.unit:Internal()
	local selfPos = selfUnit:GetPosition()
	local mexUnit = nil
	local upType = nil
	local closestDistance = math.huge
	local ownUnits = self.ai.tool:getTeamUnitsByClass({'mexUpgrade'})
	for _, unit in pairs(ownUnits) do
		local un = unit:Name()
		self:EchoDebug(un , self.ai.armyhst.mexUpgrade[un])
		-- make sure you can build the upgrade
		local upgradetype = game:GetTypeByName(self.ai.armyhst.mexUpgrade[un])
		--dont touch metal under 100% HP
		if selfUnit:CanBuild(upgradetype) and unit:GetHealth() == unit:GetMaxHealth() then
			-- make sure you can reach it
			if self.ai.maphst:UnitCanGetToUnit(selfUnit, unit)   then
				local pos = unit:GetPosition()
				if self.ai.targethst:IsSafeCell(pos, selfUnit) then
					if map:CanBuildHere(upgradetype, mexUnit:GetPosition()) then
						local dist = self.ai.tool:distance(pos, selfPos)
						if dist < closestDistance then
							mexUnit = unit
							closestDistance = dist
							upType = upgradetype
						end
					end
				end
			end
		end
	end
	if mexUnit then
		--self.unit:Internal():Reclaim(mexUnit)
		self.ai.tool:GiveOrderToUnit(selfUnit, CMD.RECLAIM, mexUnit:ID(), 0,'1-1')
		self.mexPos = mexUnit:GetPosition()
		self.upType = upType
	end
	self.active = true
	self:EchoDebug("MexUpBST: unit ".. self.name .." goes to reclaim a mex")
end
