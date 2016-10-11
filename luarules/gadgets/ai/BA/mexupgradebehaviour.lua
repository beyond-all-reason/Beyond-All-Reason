local DebugEnabled = false


local function EchoDebug(inStr)
	if DebugEnabled then
		game:SendToConsole("MexUpgradeBehaviour: " .. inStr)
	end
end

MexUpgradeBehaviour = class(Behaviour)

function MexUpgradeBehaviour:Init()
	self.active = false
	self.mohoStarted = false
	self.released = false
	self.mexPos = nil
	self.lastFrame = game:Frame()
	self.name = self.unit:Internal():Name()
	EchoDebug("MexUpgradeBehaviour: added to unit "..self.name)
end

function MexUpgradeBehaviour:OwnerIdle()
	if self:IsActive() then
		local builder = self.unit:Internal()
		EchoDebug("MexUpgradeBehaviour: unit ".. self.name .." is idle")
		-- release assistants
		if not self.released then
			self.ai.assisthandler:Release(builder)
			self.released = true
		end
		-- maybe we've just finished a moho?
		if self.mohoStarted then
			self.mohoStarted = false
			self.mexPos = nil
		end
		-- maybe we've just finished reclaiming?
		if self.mexPos ~= nil and not self.mohoStarted then
			-- maybe we're ARM and not CORE?
			local mohoName = "cormoho"
			tmpType = game:GetTypeByName("armmoho")
			if builder:CanBuild(tmpType) then
				mohoName = "armmoho"
			end
			-- maybe we're underwater?
			tmpType = game:GetTypeByName("coruwmme")
			if builder:CanBuild(tmpType) then
				mohoName = "coruwmme"
			end
			tmpType = game:GetTypeByName("armuwmme")
			if builder:CanBuild(tmpType) then
				mohoName = "armuwmme"
			end
			tmpType = game:GetTypeByName(mohoName)
			-- check if the moho can be built there at all
			local s = map:CanBuildHere(tmpType, self.mexPos)
			if s then
				s = builder:Build(mohoName, self.mexPos)
			end
			if s then
				-- get assistance and magnetize
				self.ai.assisthandler:PersistantSummon(builder, self.mexPos, helpList[mohoName])
				self.released = false
				self.active = true
				self.mohoStarted = true
				self.mexPos = nil
				EchoDebug("MexUpgradeBehaviour: unit ".. self.name .." starts building a Moho")
			else
				self.mexPos = nil
				self.mohoStarted = false
				self.active = false
				EchoDebug("MexUpgradeBehaviour: unit ".. self.name .." failed to start building a Moho")
			end
		end

		if not self.mohoStarted and (self.mexPos == nil) then
			EchoDebug("MexUpgradeBehaviour: unit ".. self.name .." restarts mex upgrade routine")
			self:StartUpgradeProcess()
		end
	end
end

function MexUpgradeBehaviour:Update()
	if not self.active then
		if (self.lastFrame or 0) + 30 < game:Frame() then
			self:StartUpgradeProcess()
		end
	end
end

function MexUpgradeBehaviour:Activate()
	EchoDebug("MexUpgradeBehaviour: active on unit ".. self.name)
	
	self:StartUpgradeProcess()
end

function MexUpgradeBehaviour:Deactivate()
	self.active = false
	self.mexPos = nil
	self.mohoStarted = false
end

function MexUpgradeBehaviour:Priority()
	if self.ai.lvl1Mexes > 0 then
		return 101
	else
		return 0
	end
end

function MexUpgradeBehaviour:StartUpgradeProcess()
	-- try to find nearest mex
	local ownUnits = game:GetFriendlies()
	local selfUnit = self.unit:Internal()
	local selfPos = selfUnit:GetPosition()
	local mexUnit = nil
	local closestDistance = 999999
	
	local mexCount = 0
	for _, unit in pairs(ownUnits) do
		local un = unit:Name()	
		if mexUpgrade[un] then
			EchoDebug(un .. " " .. mexUpgrade[un])
			-- make sure you can build the upgrade
			local upgradetype = game:GetTypeByName(mexUpgrade[un])
			if selfUnit:CanBuild(upgradetype) then
				-- make sure you can reach it
				if self.ai.maphandler:UnitCanGetToUnit(selfUnit, unit) then
					local distMod = 0
					-- if it's not 100% HP, then don't touch it (unless there's REALLY no better choice)
					-- this prevents a situation when engineer reclaims a mex that is still being built by someone else
					if unit:GetHealth() < unit:GetMaxHealth() then
						distMod = distMod + 9000
					end
					local pos = unit:GetPosition()
					-- if there are enemies nearby, don't go there as well
					if self.ai.targethandler:IsSafePosition(pos, selfUnit) then
						-- if mod number by itself is too high, don't compute the distance at all
						if distMod < closestDistance then
							local dist = Distance(pos, selfPos) + distMod
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
		s = self.unit:Internal():Reclaim(mexUnit)
		if s then
			-- we'll build the moho here
			self.mexPos = mexUnit:GetPosition()
		end
	end
	
	if s then
		self.active = true
		EchoDebug("MexUpgradeBehaviour: unit ".. self.name .." goes to reclaim a mex")
	else
		mexUnit = nil
		self.active = false
		self.lastFrame = game:Frame()
		EchoDebug("MexUpgradeBehaviour: unit ".. self.name .." failed to start reclaiming")
	end
end
