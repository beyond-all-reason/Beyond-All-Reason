MexUpBST = class(Behaviour)

function MexUpBST:Name()
	return "MexUpBST"
end

MexUpBST.DebugEnabled = false

function MexUpBST:Init()
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
		-- release assistants
		-- maybe we've just finished a moho?
		if self.mohoStarted then
			self.mohoStarted = false
			self.mexPos = nil
		end
		-- maybe we've just finished reclaiming?
		if self.mexPos ~= nil and not self.mohoStarted then
			-- maybe we're ARM and not CORE?
			local mohoName = "cormoho"
			local tmpType = self.game:GetTypeByName("armmoho")
			if builder:CanBuild(tmpType) then
				mohoName = "armmoho"
			end
			-- maybe we're underwater?
			tmpType = self.game:GetTypeByName("coruwmme")
			if builder:CanBuild(tmpType) then
				mohoName = "coruwmme"
			end
			tmpType = self.game:GetTypeByName("armuwmme")
			if builder:CanBuild(tmpType) then
				mohoName = "armuwmme"
			end
			tmpType = self.game:GetTypeByName(mohoName)
			-- check if the moho can be built there at all
			local s = map:CanBuildHere(tmpType, self.mexPos)
			if s then
				builder:Build(mohoName, self.mexPos)
				self.active = true
				self.mohoStarted = true
				self.mexPos = nil
				self:EchoDebug("MexUpBST: unit ".. self.name .." starts building a Moho")
			end
			--[[
			if s then

			else
				self.mexPos = nil
				self.mohoStarted = false
				self.active = false
				self:EchoDebug("MexUpBST: unit ".. self.name .." failed to start building a Moho")
			end
			]]
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
		--if f - self.uFrame < self.ai.behUp['mexupbst'] then
			--return
		--end
		--self.uFrame = f
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
end

function MexUpBST:Priority()
	if self.ai.lvl1Mexes > 0  and self.ai.tool:listHasValue(self.ai.armyhst.buildersRole.expand[self.name]  , self.id) then
		return 99
	elseif
	self.ai.lvl1Mexes > 0  and self.ai.tool:listHasValue(self.ai.armyhst.buildersRole.eco[self.name]  , self.id) and self.ai.tool:countMyUnit({self.ai.armyhst._mex_}) < 3 and self.ai.Metal.full < 0.3 then
		return 150
	else
		return 0
	end
end

function MexUpBST:StartUpgradeProcess()
	-- try to find nearest mex
	local ownUnits = self.game:GetUnits()
	local selfUnit = self.unit:Internal()
	local selfPos = selfUnit:GetPosition()
	local mexUnit = nil
	local closestDistance = 999999

	local mexCount = 0
	for _, unit in pairs(ownUnits) do
		local un = unit:Name()
		if self.ai.armyhst.mexUpgrade[un] then
			self:EchoDebug(un .. " " .. self.ai.armyhst.mexUpgrade[un])
			-- make sure you can build the upgrade
			local upgradetype = self.game:GetTypeByName(self.ai.armyhst.mexUpgrade[un])
			if selfUnit:CanBuild(upgradetype) then
				-- make sure you can reach it
				if self.ai.maphst:UnitCanGetToUnit(selfUnit, unit) then
					local distMod = 0
					-- if it's not 100% HP, then don't touch it (unless there's REALLY no better choice)
					-- this prevents a situation when engineer reclaims a mex that is still being built by someone else
					if unit:GetHealth() < unit:GetMaxHealth() then
						distMod = distMod + 9000
					end
					local pos = unit:GetPosition()
					-- if there are enemies nearby, don't go there as well
					if self.ai.targethst:IsSafePosition(pos, selfUnit) then
						-- if mod number by itself is too high, don't compute the self.ai.tool:distance at all
						if distMod < closestDistance then
							local dist = self.ai.tool:Distance(pos, selfPos) + distMod
							if dist < closestDistance then
								mexUnit = unit
								closestDistance = dist
							end
						end
					end
				end
			end
			mexCount = mexCount + 1
		end
	end
	self.ai.lvl1Mexes = mexCount

	local s = false
	if mexUnit ~= nil then
		-- command the engineer to reclaim the mex
		self.unit:Internal():Reclaim(mexUnit)
		--if s then
			-- we'll build the moho here
			self.mexPos = mexUnit:GetPosition()
		--end
	end

	--if s then
		self.active = true
		self:EchoDebug("MexUpBST: unit ".. self.name .." goes to reclaim a mex")
	--else
	--	mexUnit = nil
	--	self.active = false
	--	self.lastFrame = self.game:Frame()
	--	self:EchoDebug("MexUpBST: unit ".. self.name .." failed to start reclaiming")
	--end
end
