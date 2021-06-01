AssistHST = class(Module)

function AssistHST:Name()
	return "AssistHST"
end

function AssistHST:internalName()
	return "assisthst"
end

function AssistHST:Init()
	AssistHST.DebugEnabled = false
	self.free = {}
	self.working = {}
	self.totalAssignments = 0
	self.magnets = {}
	self.ai.IDByName = {}
	self.IDByNameTaken = {}
	self.lastAllocation = self.game:Frame()
	self.ai.nonAssistant = {}
	self.ai.dontAssist={}
end

function AssistHST:Update()
	local f = self.game:Frame()
	if f > self.lastAllocation + 1800 then
		local assistcentile = 0.75
		if self.ai.haveAdvFactory then
			assistcentile = 0.5
		end
		self.lastAllocation = f
		for fi = #self.free, 1, -1 do
			local assistbst = self.free[fi]
			local unitDef = UnitDefNames[assistbst.name]
			local counter = Spring.GetTeamUnitDefCount(self.game:GetTeamID(),unitDef.id)
			self.ai.dontAssist[assistbst.name] = math.ceil(math.max(2,counter * assistcentile))
			if self.ai.IDByName[assistbst.id] == nil then
				self:EchoDebug('warning ass id by name failed')
				self:AssignIDByName(assistbst)
			end
			if self.ai.IDByName[assistbst.id] <= self.ai.dontAssist[assistbst.name] then
				self.ai.nonAssistant[assistbst.id] = true
				table.remove(self.free, fi)
				assistbst.unit:ElectBehaviour()
			end
			self:EchoDebug("do not assist count " .. assistbst.name .. ' = '.. self.ai.dontAssist[assistbst.name])
		end
	end
end

-- checks whether the assistant can help the builder
function AssistHST:IsLocal(assistbst, position)
	local aunit = assistbst.unit:Internal()
	local apos = aunit:GetPosition()
	local dist = self.ai.tool:Distance(position, apos)
	if assistbst.isNanoTurret then
		if dist > 390 then
			return false
		end
	else
		if not self.ai.maphst:UnitCanGoHere(aunit, position) then
			return false
		end
	end
	return dist
end

function AssistHST:IsFree(assistbst)
	for i, ab in pairs(self.free) do
		if ab == assistbst then return true end
	end
	return false
end

function AssistHST:AddFree(assistbst)
	if not self:IsFree(assistbst) then
		table.insert(self.free, assistbst)
		self:EchoDebug(assistbst.name .. " added to available assistants")
	end
	if self.lastPullPosition then
		assistbst:SetFallback(self.lastPullPosition)
	end
	self:DoMagnets()
end

function AssistHST:RemoveFree(assistbst)
	for i, ab in pairs(self.free) do
		if ab == assistbst then
			table.remove(self.free, i)
			self:EchoDebug(assistbst.name .. " removed from available assistants")
			return true
		end
	end
	return false
end

function AssistHST:RemoveWorking(assistbst)
	if assistbst.target == nil then return false end
	local targetID = assistbst.target
	for bid, workers in pairs(self.working) do
		if bid == targetID then
			for i, ab in pairs(workers) do
				if ab == assistbst then
					table.remove(workers, i)
					if #workers == 0 then
						self.working[bid] = nil
						self.totalAssignments = self.totalAssignments - 1
					end
					self:EchoDebug(assistbst.name .. " removed from working assistants")
					return true
				end
			end
		end
	end
	return false
end

function AssistHST:AssignIDByName(assistbst)
	-- game:SendToConsole("assisthst:assignidbyname", ai, self.ai.id, self.ai, self.ai.id)

	local uname = assistbst.name
	if not self.ai.dontAssist[uname] then
		self.ai.dontAssist[uname] = 2
	end
	if self.IDByNameTaken[uname] == nil then
		assistbst.IDByName = 1
		self.ai.IDByName[assistbst.id] = 1
		self.IDByNameTaken[uname] = {}
		self.IDByNameTaken[uname][1] = assistbst.id
	else
		if assistbst.IDByName ~= nil then
			self.IDByNameTaken[uname][assistbst.IDByName] = nil
		end
		local id = 1
		while id <= self.ai.tool:countMyUnit({uname}) do
			id = id + 1
			if not self.IDByNameTaken[uname][id] then break end
		end
		assistbst.IDByName = id
		self.ai.IDByName[assistbst.id] = id
		self.IDByNameTaken[uname][id] = assistbst.id
	end
	if self.ai.IDByName[assistbst.id] > self.ai.dontAssist[assistbst.name] then
		self.ai.nonAssistant[assistbst.id] = nil
	else
		self.ai.nonAssistant[assistbst.id] = true
	end
	if assistbst.active then
		if assistbst:DoIAssist() then
			self:AddFree(assistbst)
		end
	end
end

function AssistHST:RemoveAssistant(assistbst)
	self:RemoveWorking(assistbst)
	self:RemoveFree(assistbst)
	local uname = assistbst.name
	local uid = assistbst.id
	-- game:SendToConsole("assistant " .. uname .. " died")
	if self.IDByNameTaken[uname] ~= nil then self.IDByNameTaken[uname][self.ai.IDByName[uid]] = nil end
	self.ai.IDByName[uid] = nil
end

-- tries to get a certain number of assistants to help a builder
-- if there aren't enough available, returns false
function AssistHST:Summon(builder, position, number, force)
	if number == nil or number == 0 then number = #self.free end
	self:EchoDebug(#self.free .. " assistants free")
	if #self.free < number then
		-- self:EchoDebug("total assignments: " .. self.totalAssignments)
		self:EchoDebug("less than " .. number .. " assistants free")
		if not force then return false end
	end
	local bid = builder:ID()
	if #self.free >= number or (force and #self.free > 0) then
		-- get the closest ones first
		-- order by self.ai.tool:distance
		local byselfdistance = {}
		local returnToFree = {}
		local count = 0
		while #self.free > 0 do
			local assistbst = table.remove(self.free)
			local skip = false
			if assistbst.unit == nil then
				skip = true
			elseif assistbst.unit:Internal() == nil then
				skip = true
			end
			if not skip then
				local dist = self:IsLocal(assistbst, position)
				if dist then
					byselfdistance[dist] = assistbst
					count = count + 1
				else
					table.insert(returnToFree, assistbst)
				end
			end
		end
		-- return those that didn't make it to free
		for i, assistbst in pairs(returnToFree) do
			table.insert(self.free, assistbst)
		end
		if count < number and not force then
			-- return everything to free if there aren't enough
			for dist, assistbst in pairs(byselfdistance) do
				table.insert(self.free, assistbst)
			end
			return false
		elseif count == 0 and force then
			return 0
		else
			if self.working[bid] == nil then
				self.totalAssignments = self.totalAssignments + 1
				self.working[bid] = {}
			end
			-- summon in order of self.ai.tool:distance and return the rest to free
			local n = 0
			for dist, assistbst in self.ai.tool:pairsByKeys(byselfdistance) do
				if n == number then
					-- add any unused back into free
					table.insert(self.free, assistbst)
				else
					table.insert(self.working[bid], assistbst)
					assistbst:Assign(bid)
					n = n + 1
				end
			end
			self:EchoDebug(n .. " assistants summoned to " .. bid .. "now " .. #self.free .. " assistants free")
			return n
		end
	end
	if force then
		return 0
	else
		return false
	end
end

-- assistants that become free before this magnet is released will get assigned to this builder
function AssistHST:Magnetize(builder, position, number)
	if number == nil or number == 0 then number = -1 end
	table.insert(self.magnets, {bid = builder:ID(), pos = position, number = number})
end

-- summons and magnetizes until released
function AssistHST:PersistantSummon(builder, position, maxNumber, minNumber)
	if minNumber == nil then minNumber = 0 end
	if maxNumber == 0 then
		-- get every free assistant until it's done building
		local hashelp = self:Summon(builder, position, 0, true)
		if hashelp >= minNumber then
			self:Magnetize(builder, position)
			return hashelp
		end
	else
		-- get enough assistants
		local hashelp = self:Summon(builder, position, maxNumber, true)
		if hashelp >= minNumber then
			if hashelp < maxNumber then
				self:Magnetize(builder, position, maxNumber - hashelp)
			end
			return hashelp
		end
	end
	return false
end

-- assigns any free assistants (but keeps them free for summoning or magnetism)
function AssistHST:TakeUpSlack(builder)
	if #self.free == 0 then return end
	self:DoMagnets()
	if #self.free == 0 then return end
	local builderPos = builder:GetPosition()
	self.lastPullPosition = builderPos -- so that any newly free assistants can be sent to a non-dumb place
	for i = #self.free, 1, -1 do
		local assistbst = self.free[i]
		if not assistbst.unit or not assistbst.unit:Internal() then
			table.remove(self.free, i)
		else
			if self:IsLocal(assistbst, builderPos) then
				assistbst:SoftAssign(builder:ID())
			end
		end
	end
end

-- assign any free assistants to really important ongoing projects
function AssistHST:DoMagnets()
	for fi = #self.free, 1, -1 do
		local assistbst = self.free[fi]
		if #self.magnets == 0 then break end
		local skip = false
		if assistbst.unit == nil then
			table.remove(self.free, fi)
			skip = true
		elseif assistbst.unit:Internal() == nil then
			table.remove(self.free, fi)
			skip = true
		end
		if not skip then
			local aunit = assistbst.unit:Internal()
			local apos = aunit:GetPosition()
			local bestDist = 10000
			local best
			for mi, magnet in pairs(self.magnets) do
				local dist = self:IsLocal(assistbst, magnet.pos)
				if dist then
					if dist < bestDist then
						bestDist = dist
						best = mi
					end
				end
			end
			if best then
				local magnet = self.magnets[best]
				if self.working[magnet.bid] == nil then
					self.working[magnet.bid] = {}
					self.totalAssignments = self.totalAssignments + 1
				end
				table.insert(self.working[magnet.bid], assistbst)
				assistbst:Assign(magnet.bid)
				table.remove(self.free, fi)
				if magnet.number ~= -1 then magnet.number = magnet.number - 1 end
				self:EchoDebug("one assistant magnetted to " .. magnet.bid .. " magnet has " .. magnet.number .. " left to get from " .. #self.free .. " available")
				if magnet.number == 0 then
					table.remove(self.magnets, 1)
				end
			end
		end
	end
end

-- returns any assistants assigned to a builder to being available
function AssistHST:Release(builder, bid, dead)
	if bid == nil then
		bid = builder:ID()
	end
	if self.working[bid] == nil then return false end
	if #self.working[bid] == 0 then
		self.working[bid] = nil
		return false
	end
	self:EchoDebug("releasing " .. #self.working[bid] .. " from " .. bid)
	while #self.working[bid] > 0 do
		local assistbst = table.remove(self.working[bid])
		if dead then assistbst:Assign(nil) end
		table.insert(self.free, assistbst)
		if self.ai.IDByName[assistbst.id] ~= nil then
			if self.ai.IDByName[assistbst.id] <= self.ai.dontAssist[assistbst.name] then
				self.ai.nonAssistant[assistbst.id] = true
			end
		end
		-- self.ai:UnitIdle(assistbst.unit:Internal())
		self:EchoDebug(assistbst.name .. " released to available assistants")
	end
	self.working[bid] = nil
	self.totalAssignments = self.totalAssignments - 1
	self:EchoDebug("demagnetizing " .. bid)
	for i = #self.magnets, 1, -1 do
		local magnet = self.magnets[i]
		if magnet.bid == bid then
			self:EchoDebug("removing a magnet")
			table.remove(self.magnets, i)
		end
	end
	-- self:EchoDebug("resetting magnets...")
	self:DoMagnets()
	-- self:EchoDebug("magnets reset")
	return true
end
