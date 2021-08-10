ScoutHST = class(Module)

function ScoutHST:Name()
	return "ScoutHST"
end

function ScoutHST:internalName()
	return "scouthst"
end

ScoutHST.DebugEnabled = false

function ScoutHST:Init()
	self.spotsToScout = {}
	self.lastCount = {}
	self.sameCount = {}
	self.usingStarts = {}
end

function ScoutHST:ScoutLos(scoutbst, position)
	local los
	if self.ai.maphst:IsUnderWater(position) and self.ai.armyhst.unitTable[scoutbst.name].sonarRadius == 0 then
		-- treat underwater spots as surface spots if the scout has no sonar, so that it moves on
		local lt = self.ai.loshst:AllLos(position)
		if lt[2] then
			los = 2
		else
			los = 0
		end
	else
		los = self.ai.loshst:GroundLos(position)
	end
	return los
end

function ScoutHST:ClosestSpot(scoutbst)
	local unit = scoutbst.unit:Internal()
	local position = unit:GetPosition()
	local mtype = scoutbst.mtype
	local network --TODO this maybe is to verify
	if mtype == nil then mtype = "air" end
	if network == nil then network = 1 end
	-- initializing the necessary tables if they're not yet
	if self.spotsToScout[mtype] == nil then self.spotsToScout[mtype] = {} end
	if self.spotsToScout[mtype][network] == nil then self.spotsToScout[mtype][network] = {} end
	if self.usingStarts[mtype] == nil then self.usingStarts[mtype] = {} end
	if self.usingStarts[mtype][network] == nil then self.usingStarts[mtype][network] = false end
	if self.lastCount[mtype] == nil then self.lastCount[mtype] = {} end
	if self.lastCount[mtype][network] == nil then self.lastCount[mtype][network] = 0 end
	if self.sameCount[mtype] == nil then self.sameCount[mtype] = {} end
	if self.sameCount[mtype][network] == nil then self.sameCount[mtype][network] = 0 end
	-- filling table of spots to scout if empty
	if #self.spotsToScout[mtype][network] == 0 then
		if not self.usingStarts[mtype][network] then
			if self.ai.startLocations[mtype] ~= nil then
				if self.ai.startLocations[mtype][network] ~= nil then
					-- scout all probable start locations first
					self:EchoDebug(unit:Name() .. " got starts")
					for i, p in pairs(self.ai.startLocations[mtype][network]) do
						table.insert(self.spotsToScout[mtype][network], p)
					end
				end
			end
			-- true even if no start locations were in network, so that it moves onto using metals/geos next
			self.usingStarts[mtype][network] = true
		elseif self.usingStarts[mtype][network] then
			-- then use metal and geo spots
			self:EchoDebug(unit:Name() .. " got metals and geos")
			for i, p in pairs(self.ai.scoutSpots[mtype][network]) do
				table.insert(self.spotsToScout[mtype][network], p)
			end
			self.usingStarts[mtype][network] = false
		end
	end
	self:EchoDebug(mtype .. " " .. network .. " has " .. #self.spotsToScout[mtype][network] .. " spots")

	-- find the closest spot
	local pos = nil
	local index = nil
	local bestDistance = 10000
	for i = #self.spotsToScout[mtype][network], 1, -1 do
		local p = self.spotsToScout[mtype][network][i]
		local los
		if self.ai.maphst:IsUnderWater(p) and self.ai.armyhst.unitTable[scoutbst.name].sonarRadius == 0 then
			-- treat underwater spots as surface spots if the scout has no sonar, so that it moves on
			local lt = self.ai.loshst:AllLos(p)
			if lt[2] then
				los = 2
			else
				los = 0
			end
		else
			los = self.ai.loshst:GroundLos(p)
		end
		if los == 2 or los == 3 or not self.ai.targethst:IsSafePosition(p, unit, 1) then
			table.remove(self.spotsToScout[mtype][network], i)
		else
			local dist = self.ai.tool:Distance(position, p)
			if dist < bestDistance then
				bestDistance = dist
				pos = p
				index = i
			end
		end
	end
	-- make sure we're not getting quixotic
	if #self.spotsToScout[mtype][network] == self.lastCount[mtype][network] then
		self.sameCount[mtype][network] = self.sameCount[mtype][network] + 1
		if self.sameCount[mtype][network] > 15 then
			-- if the last spots can't be scouted for some reason, just clear the list to repopulate it
			self.spotsToScout[mtype][network] = {}
		end
	else
		self.sameCount[mtype][network] = 0
	end
	self.lastCount[mtype][network] = #self.spotsToScout[mtype][network]
	if pos ~= nil then
		self:EchoDebug("and spot found")
		pos.y = 0
	else
		self:EchoDebug("but NO spot found")
	end
	return pos
end
