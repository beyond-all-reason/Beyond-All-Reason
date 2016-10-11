function IsReclaimer(unit)
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
	self.lastCheckFrame = 0
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

function ReclaimBehaviour:OwnerIdle()
	if self.active then
		if self.myFeature then
			self.ai.targethandler:RemoveFeature(self.myFeature, self.myFeaturePos)
			self.myFeature = nil
			self.myFeaturePos = nil
		end
		self:EraseTargets()
		self.unit:ElectBehaviour()
	end
	self.idle = game:Frame()
end

function ReclaimBehaviour:Update()
	if self.active then return end
	local f = game:Frame()
	if (self.idle and f > self.idle) or (self.dedicated and f > self.lastCheckFrame + 150) or (f > self.lastCheckFrame + 500) then
		if self.idle then self:EchoDebug(f - self.idle) end
		self.idle = nil
		self.lastCheckFrame = f
		self:Check()
	end
end

function ReclaimBehaviour:Priority()
	if self.targetCell or self.targetUnit then
		return 101
	else
		-- self:EchoDebug("priority 0")
		return 0
	end
end

function ReclaimBehaviour:Activate()
	self:EchoDebug("activate")
	self.active = true
	if not self:Act() then
		self:EraseTargets()
		self.unit:ElectBehaviour()
	end
end

function ReclaimBehaviour:Deactivate()
	self:EchoDebug("deactivate")
	self.active = false
	self:ResurrectionComplete() -- so we don't get stuck
end

function ReclaimBehaviour:EraseTargets()
	self.target = nil
	self.targetResurrection = nil
	self.targetUnit = nil
	self.targetCell = nil
	self.targetRepair = nil
end

function ReclaimBehaviour:Check()
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
	elseif self.extraReclaimer then
		self.ai.haveExtraReclaimer = false
		self.extraReclaimer = false
		self:EraseTargets()
		self.unit:ElectBehaviour()
	end
	if doreclaim then
		self:Retarget()
		self.unit:ElectBehaviour()
	end
end

function ReclaimBehaviour:Retarget()
	self:EchoDebug("needs target")
	self:EraseTargets()
	local unit = self.unit:Internal()
	local tcell, tunit = self.ai.targethandler:GetBestReclaimCell(unit)
	self:EchoDebug(tcell, tunit)
	if tunit then
		self:EchoDebug("got unit to reclaim from GetBestReclaimCell")
		self.targetUnit = tunit.unit
	end
	if not self.targetUnit and self.dedicated and self.ai.Metal.full > 0.5 and self.ai.Energy.full > 0.75 then
		local bestThing, bestCell = self.ai.targethandler:WreckToResurrect(unit, true)
		if bestThing then
			if bestThing.className == 'unit' then
				self:EchoDebug("got damaged to repair from WreckToResurect cell")
				self.targetRepair = bestThing
			elseif bestThing.className == 'feature' then
				self:EchoDebug("got resurrectable from WreckToResurect cell")
				self.targetResurrection = bestThing
			end
		end
		self.targetCell = bestCell
	end
	if not self.targetResurrection and not self.targetUnit then
		if tcell and (self.ai.Metal.full < 0.75 or tcell.metal > 1000) then
			self:EchoDebug("got cell for reclaim")
			self.targetCell = tcell
		end
		if not self.targetCell and self.ai.Metal.full < 0.75 then
			self:EchoDebug("looking for closest cleanable to reclaim")
			self.targetUnit = self.ai.cleanhandler:ClosestCleanable(unit)
		end
	end
	self.unit:ElectBehaviour()
end

function ReclaimBehaviour:Act()
	if not self.active then
		return
	end
	if self.targetRepair then
		self:EchoDebug("repair unit", self.targetRepair, self.targetRepair:ID())
		self.target = self.targetRepair:GetPosition()
		self.unit:Internal():Repair(self.targetRepair)
		return true
	elseif self.targetUnit then
		self:EchoDebug("reclaim unit", self.targetUnit, self.targetUnit:ID())
		self.target = self.targetUnit:GetPosition()
		self.unit:Internal():Reclaim(self.targetUnit)
		-- CustomCommand(self.unit:Internal(), CMD_RECLAIM, {self.targetUnit:ID()})
		return true
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
			return true
		else
			-- self:EchoDebug("reclaiming area...")
			-- self.unit:Internal():AreaReclaim(self.target, 200)
			local reclaimables = cell.reclaimables
			for i = #reclaimables, 1, -1 do
				local reclaimFeature = reclaimables[i].feature
				local rfpos = reclaimFeature:GetPosition()
				if rfpos and rfpos.x then
					local unitName = reclaimables[i].unitName
					if self.dedicated and unitName and unitTable[unitName] and unitTable[unitName].extractsMetal > 0 then
						-- always resurrect metal extractors
						self:EchoDebug("resurrect mex", reclaimFeature, reclaimFeature:ID())
						CustomCommand(self.unit:Internal(), CMD_RESURRECT, {rfpos.x, rfpos.y, rfpos.z, 15})
						self.resurrecting = true
						self.myFeature = reclaimFeature
						self.myFeaturePos = reclaimFeature:GetPosition()
						table.remove(cell.reclaimables, i)
						return true
					else
						self:EchoDebug("reclaim feature", reclaimFeature, reclaimFeature:ID())
						self.unit:Internal():Reclaim(reclaimFeature)
						-- CustomCommand(self.unit:Internal(), CMD_RECLAIM, {reclaimFeature:ID()})
						self.myFeature = reclaimFeature
						self.myFeaturePos = reclaimFeature:GetPosition()
						table.remove(cell.reclaimables, i)
						return true
					end
				else
					table.remove(cell.reclaimables, i)
				end
			end
		end
	end
end

function ReclaimBehaviour:ResurrectionComplete()
	self.resurrecting = false
	self.ai.buildsitehandler:ClearMyPlans(self)
end