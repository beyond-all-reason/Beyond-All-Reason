 DebugEnabled = false


local function EchoDebug(inStr)
	if DebugEnabled then
		game:SendToConsole("ReclaimBehaviour: " .. inStr)
	end
end

local CMD_RESURRECT = 125

function IsReclaimer(unit)
	local tmpName = unit:Internal():Name()
	return (reclaimerList[tmpName] or 0) > 0
end

ReclaimBehaviour = class(Behaviour)

function ReclaimBehaviour:Init()
	local mtype, network = self.ai.maphandler:MobilityOfUnit(self.unit:Internal())
	self.mtype = mtype
	self.layers = {}
	if self.mtype == "veh" or self.mtype == "bot" or self.mtype == "amp" or self.mtype == "hov" then
		table.insert(self.layers, "ground")
	end
	if self.mtype == "sub" or self.mtype == "amp" or self.mtype == "shp" or self.mtype == "hov" then
		table.insert(self.layers, "submerged")
	end
	if self.mtype == "air" then
		table.insert(self.layers, "air")
	end
	self.name = self.unit:Internal():Name()
	if reclaimerList[self.name] then self.dedicated = true end
	self.id = self.unit:Internal():ID()
end

function ReclaimBehaviour:OwnerBuilt()
	EchoDebug("got new reclaimer")
end

function ReclaimBehaviour:OwnerDead()
	-- notify the command that area is too hot
	-- game:SendToConsole("reclaimer " .. self.name .. " died")
	if self.target then
		self.ai.targethandler:AddBadPosition(self.target, self.mtype)
	end
	self.ai.buildsitehandler:ClearMyPlans(self)
end

function ReclaimBehaviour:Update()
	local f = game:Frame()
	if f % 120 == 0 then
		local doreclaim = false
		if self.dedicated and not self.resurrecting then
			doreclaim = true
		elseif self.ai.conCount > 2 and self.ai.needToReclaim and self.ai.reclaimerCount == 0 and self.ai.IDByName[self.id] ~= 1 and self.ai.IDByName[self.id] == self.ai.nameCount[self.name] then
			if not self.ai.haveExtraReclaimer then
				self.ai.haveExtraReclaimer = true
				self.extraReclaimer = true
				doreclaim = true
			elseif self.extraReclaimer then
				doreclaim = true
			end
		else
			if self.extraReclaimer then
				self.ai.haveExtraReclaimer = false
				self.extraReclaimer = false
				self.targetCell = nil
				self.targetUnit = nil
				self.target = nil
				self.unit:ElectBehaviour()
			end
		end
		if doreclaim then
			self:Retarget()
			self.unit:ElectBehaviour()
			self:Reclaim()
		end
	end
end

function ReclaimBehaviour:Retarget()
	EchoDebug("needs target")
	local unit = self.unit:Internal()
	self.targetResurrection = nil
	self.targetUnit = nil
	self.targetCell = nil
	if self.ai.Metal.full > 0.5 and self.dedicated then
		self.targetResurrection, self.targetCell = self.ai.targethandler:WreckToResurrect(unit)
	end
	if not self.targetResurrection and self.ai.Metal.full < 0.75 then
		self.targetUnit = self.ai.cleanhandler:ClosestCleanable(unit)
		if not self.targetUnit then
			self.targetCell = self.ai.targethandler:GetBestReclaimCell(unit)
		end
	end
	self.unit:ElectBehaviour()
end

function ReclaimBehaviour:Priority()
	if self.targetCell or self.targetUnit then
		return 101
	else
		-- EchoDebug("priority 0")
		return 0
	end
end

function ReclaimBehaviour:Reclaim()
	if self.active then
		if self.targetCell then
			local cell = self.targetCell
			self.target = cell.pos
			EchoDebug("cell at" .. self.target.x .. " " .. self.target.z)
			-- find an enemy unit to reclaim if there is one
			local vulnerable
			for i, layer in pairs(self.layers) do
				local vLayer = layer .. "Vulnerable"
				vulnerable = cell[vLayer]
				if vulnerable ~= nil then break end
			end
			if vulnerable ~= nil then
				EchoDebug("reclaiming enemy...")
				CustomCommand(self.unit:Internal(), CMD_RECLAIM, {vulnerable.unitID})
			elseif self.targetResurrection ~= nil and not self.resurrecting then
				EchoDebug("resurrecting...")
				local resPosition = self.targetResurrection.position
				local unitName = featureTable[self.targetResurrection.featureName].unitName
				EchoDebug(unitName)
				CustomCommand(self.unit:Internal(), CMD_RESURRECT, {resPosition.x, resPosition.y, resPosition.z, 15})
				self.ai.buildsitehandler:NewPlan(unitName, resPosition, self, true)
				self.resurrecting = true
			else
				EchoDebug("reclaiming area...")
				self.unit:Internal():AreaReclaim(self.target, 200)
			end
		elseif self.targetUnit then
			self.target = self.targetUnit:GetPosition()
			CustomCommand(self.unit:Internal(), CMD_RECLAIM, {self.targetUnit:ID()})
		end
	end
end

function ReclaimBehaviour:Activate()
	EchoDebug("activate")
	self.active = true
end

function ReclaimBehaviour:Deactivate()
	EchoDebug("deactivate")
	self.active = false
	self:ResurrectionComplete() -- so we don't get stuck
end

function ReclaimBehaviour:ResurrectionComplete()
	self.resurrecting = false
	self.ai.buildsitehandler:ClearMyPlans(self)
end