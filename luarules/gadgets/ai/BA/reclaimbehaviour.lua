ion IsReclaimer(unit)
	local tmpName = unit:Internal():Name()
	return (reclaimerList[tmpName] or 0) > 0
end

ReclaimBehaviour = class(Behaviour)

function ReclaimBehaviour:Name()
	return "ReclaimBehaviour"
end

local CMD_RESURRECT = 125

function ReclaimBehaviour:Init()
	self.DebugEnabled = false

	local mtype, network = self.ai.maphandler:MobilityOfUnit(self.unit:Internal())
	self.mtype = mtype
	self.canReclaimGAS = {}
	if self.mtype == "veh" or self.mtype == "bot" or self.mtype == "amp" or self.mtype == "hov" then
		table.insert(self.canReclaimGAS, "ground")
	end
	if self.mtype == "sub" or self.mtype == "amp" or self.mtype == "shp" or self.mtype == "hov" then
		table.insert(self.canReclaimGAS, "submerged")
	end
	if self.mtype == "air" then
		table.insert(self.canReclaimGAS, "air")
	end
	self.name = self.unit:Internal():Name()
	self.dedicated = reclaimerList[self.name]
	self.id = self.unit:Internal():ID()
end

function ReclaimBehaviour:OwnerBuilt()
	self:EchoDebug("got new reclaimer")
end

function ReclaimBehaviour:OwnerDead()
	-- notify the command that area is too hot
	-- self:EchoDebug("reclaimer " .. self.name .. " died")
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
	self:EchoDebug("needs target")
	local unit = self.unit:Internal()
	self.targetResurrection = nil
	self.targetUnit = nil
	self.targetCell = nil
	self.targetRepair = nil
	local tcell, tunit = self.ai.targethandler:GetBestReclaimCell(unit)
	self:EchoDebug(tcell, tunit)
	if tunit then
		self.targetUnit = tunit.unit
	end
	if not self.targetUnit and self.dedicated and self.ai.Metal.full > 0.5 then
		self.targetResurrection, self.targetCell = self.ai.targethandler:WreckToResurrect(unit)
	end
	if not self.targetResurrection then
		if not self.targetUnit and self.ai.Metal.full < 0.75 then
			self.targetCell = tcell
			if not self.targetCell then
				self.targetUnit = self.ai.cleanhandler:ClosestCleanable(unit)
			end
		end
		if not self.targetCell and not self.targetUnit then
			self:EchoDebug("get nearest damaged to repair")
			self.targetRepair = self:NearestDamaged()
		end
	end
	self.unit:ElectBehaviour()
end

function ReclaimBehaviour:Priority()
	if self.targetCell or self.targetUnit then
		return 101
	else
		-- self:EchoDebug("priority 0")
		return 0
	end
end

function ReclaimBehaviour:Reclaim()
	if self.active then
		if self.targetRepair then
			self:EchoDebug("repair unit", self.targetRepair, self.targetRepair:ID())
			self.target = self.targetRepair:GetPosition()
			self.unit:Internal():Repair(self.targetRepair)
		elseif self.targetUnit then
			self:EchoDebug("reclaim unit", self.targetUnit, self.targetUnit:ID())
			self.target = self.targetUnit:GetPosition()
			self.unit:Internal():Reclaim(self.targetUnit)
			-- CustomCommand(self.unit:Internal(), CMD_RECLAIM, {self.targetUnit:ID()})
		elseif self.targetCell then
			local cell = self.targetCell
			self.target = cell.pos
			self:EchoDebug("cell at" .. self.target.x .. " " .. self.target.z)
			if self.targetResurrection ~= nil and not self.resurrecting then
				self:EchoDebug("resurrecting...")
				local resPosition = self.targetResurrection.position
				local unitName = featureTable[self.targetResurrection.featureName].unitName
				self:EchoDebug(unitName)
				CustomCommand(self.unit:Internal(), CMD_RESURRECT, {resPosition.x, resPosition.y, resPosition.z, 15})
				self.ai.buildsitehandler:NewPlan(unitName, resPosition, self, true)
				self.resurrecting = true
			else
				-- self:EchoDebug("reclaiming area...")
				-- self.unit:Internal():AreaReclaim(self.target, 200)
				local reclaimables = cell.reclaimables
				for i = 1, #reclaimables do
					local reclaimFeature = reclaimables[i].feature
					local rfpos = reclaimFeature:GetPosition()
					if rfpos and rfpos.x then
						local unitName = reclaimables[i].unitName
						if self.dedicated and unitName and unitTable[unitName] and unitTable[unitName].extractsMetal > 0 then
							-- always resurrect metal extractors
							self:EchoDebug("resurrect mex", reclaimFeature, reclaimFeature:ID())
							CustomCommand(self.unit:Internal(), CMD_RESURRECT, {rfpos.x, rfpos.y, rfpos.z, 15})
							self.ai.buildsitehandler:NewPlan(unitName, rfpos, self, true)
							self.resurrecting = true
						else
							self:EchoDebug("relcaim feature", reclaimFeature, reclaimFeature:ID())
							self.unit:Internal():Reclaim(reclaimFeature)
							-- CustomCommand(self.unit:Internal(), CMD_RECLAIM, {reclaimFeature:ID()})
						end
					end
				end
			end
		end
	end
end

function ReclaimBehaviour:Activate()
	self:EchoDebug("activate")
	self.active = true
end

function ReclaimBehaviour:Deactivate()
	self:EchoDebug("deactivate")
	self.active = false
	self:ResurrectionComplete() -- so we don't get stuck
end

function ReclaimBehaviour:ResurrectionComplete()
	self.resurrecting = false
	self.ai.buildsitehandler:ClearMyPlans(self)
end

function ReclaimBehaviour:NearestDamaged()
	local damaged = self.ai.damagehandler:GetDamagedUnits()
	local bestDistance
	local bestUnit
	local upos = self.unit:Internal():GetPosition()
	for unitID, engineUnit in pairs(damaged) do
		local pos = engineUnit:GetPosition()
		local dist = Distance(upos, pos)
		if not bestDistance or dist < bestDistance then
			bestDistance = dist
			bestUnit = engineUnit
		end
	end
	return bestUnit
end