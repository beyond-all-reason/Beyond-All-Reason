local DebugEnabled = false


local function EchoDebug(inStr)
	if DebugEnabled then
		game:SendToConsole("AssistHandler: " .. inStr)
	end
end

AssistHandler = class(Module)

function AssistHandler:Name()
	return "AssistHandler"
end

function AssistHandler:internalName()
	return "assisthandler"
end

function AssistHandler:Init()
	self.free = {}
	self.working = {}
	self.totalAssignments = 0
	self.magnets = {}
	self.ai.IDByName = {}
	self.IDByNameTaken = {}
	self.lastAllocation = game:Frame()
	self.ai.nonAssistantsPerName = 2
	self.ai.nonAssistant = {}
end

function AssistHandler:Update()
	local f = game:Frame()
	if f > self.lastAllocation + 1800 then
		self.lastAllocation = f
		if self.ai.Metal.full > 0.33 then
			self.ai.nonAssistantsPerName = math.max(self.ai.nonAssistantsPerName - 1, 2)
		elseif self.ai.Metal.tics < 2 or self.ai.Metal.full < 0.1 then
			self.ai.nonAssistantsPerName = math.min(self.ai.nonAssistantsPerName + 1, self.ai.conUnitPerTypeLimit)
			for fi = #self.free, 1, -1 do
				local asstbehaviour = self.free[fi]
				if self.ai.IDByName[asstbehaviour.id] == nil then self:AssignIDByName(asstbehaviour) end
				if self.ai.IDByName[asstbehaviour.id] <= self.ai.nonAssistantsPerName then
					self.ai.nonAssistant[asstbehaviour.id] = true
					asstbehaviour.unit:ElectBehaviour()
					table.remove(self.free, fi)
				end
			end
		end
		EchoDebug("nonassistants per name: " .. self.ai.nonAssistantsPerName)
	end
end

-- checks whether the assistant can help the builder
function AssistHandler:IsLocal(asstbehaviour, position)
	local aunit = asstbehaviour.unit:Internal()
	local apos = aunit:GetPosition()
	local dist = Distance(position, apos)
	if asstbehaviour.isNanoTurret then
		if dist > 390 then
			return false
		end
	else
		if not ai.maphandler:UnitCanGoHere(aunit, position) then
			return false
		end
	end
	return dist
end

-- tries to get a certain number of assistants to help a builder
-- if there aren't enough available, returns false
function AssistHandler:Summon(builder, position, number, force)
	if number == nil or number == 0 then number = #self.free end
	EchoDebug(#self.free .. " assistants free")
	if #self.free < number then 
		-- EchoDebug("total assignments: " .. self.totalAssignments)
		EchoDebug("less than " .. number .. " assistants free")
		if not force then return false end
	end
	local bid = builder:ID()
	if #self.free >= number or (force and #self.free > 0) then
		-- get the closest ones first
		-- order by distance
		local bydistance = {}
		local returnToFree = {}
		local count = 0
		while #self.free > 0 do
			local asstbehaviour = table.remove(self.free)
			local skip = false
			if asstbehaviour.unit == nil then
				skip = true
			elseif asstbehaviour.unit:Internal() == nil then
				skip = true
			end
			if not skip then
				local dist = self:IsLocal(asstbehaviour, position)
				if dist then
					bydistance[dist] = asstbehaviour
					count = count + 1
				else
					table.insert(returnToFree, asstbehaviour)
				end
			end
		end
		-- return those that didn't make it to free
		for i, asstbehaviour in pairs(returnToFree) do
			table.insert(self.free, asstbehaviour)
		end
		if count < number and not force then
			-- return everything to free if there aren't enough
			for dist, asstbehaviour in pairs(bydistance) do
				table.insert(self.free, asstbehaviour)
			end
			return false
		elseif count == 0 and force then
			return 0
		else
			if self.working[bid] == nil then
				self.totalAssignments = self.totalAssignments + 1
				self.working[bid] = {}
			end
			-- summon in order of distance and return the rest to free
			local n = 0
			for dist, asstbehaviour in pairsByKeys(bydistance) do
				if n == number then
					-- add any unused back into free
					table.insert(self.free, asstbehaviour)
				else
					table.insert(self.working[bid], asstbehaviour)
					asstbehaviour:Assign(bid)
					n = n + 1
				end
			end
			EchoDebug(n .. " assistants summoned to " .. bid .. "now " .. #self.free .. " assistants free")
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
function AssistHandler:Magnetize(builder, position, number)
	if number == nil or number == 0 then number = -1 end
	table.insert(self.magnets, {bid = builder:ID(), pos = position, number = number})
end

-- summons and magnetizes until released
function AssistHandler:PersistantSummon(builder, position, maxNumber, minNumber)
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
function AssistHandler:TakeUpSlack(builder)
	if #self.free == 0 then return end
	self:DoMagnets()
	if #self.free == 0 then return end
	local builderPos = builder:GetPosition()
	self.lastPullPosition = builderPos -- so that any newly free assistants can be sent to a non-dumb place
	for i = #self.free, 1, -1 do
		local asstbehaviour = self.free[i]
		if not asstbehaviour.unit or not asstbehaviour.unit:Internal() then
			table.remove(self.free, i)
		else
			if self:IsLocal(asstbehaviour, builderPos) then
				asstbehaviour:SoftAssign(builder:ID())
			end
		end
	end
end

-- assign any free assistants to really important ongoing projects
function AssistHandler:DoMagnets()
	for fi = #self.free, 1, -1 do
		local asstbehaviour = self.free[fi]
		if #self.magnets == 0 then break end
		local skip = false
		if asstbehaviour.unit == nil then
			table.remove(self.free, fi)
			skip = true
		elseif asstbehaviour.unit:Internal() == nil then
			table.remove(self.free, fi)
			skip = true
		end
		if not skip then
			local aunit = asstbehaviour.unit:Internal()
			local apos = aunit:GetPosition()
			local bestDist = 10000
			local best
			for mi, magnet in pairs(self.magnets) do
				local dist = self:IsLocal(asstbehaviour, magnet.pos)
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
				table.insert(self.working[magnet.bid], asstbehaviour)
				asstbehaviour:Assign(magnet.bid)
				table.remove(self.free, fi)
				if magnet.number ~= -1 then magnet.number = magnet.number - 1 end
				EchoDebug("one assistant magnetted to " .. magnet.bid .. " magnet has " .. magnet.number .. " left to get from " .. #self.free .. " available")
				if magnet.number == 0 then
					table.remove(self.magnets, 1)
				end
			end
		end
	end
end

-- returns any assistants assigned to a builder to being available
function AssistHandler:Release(builder, bid, dead)
	if bid == nil then 
		bid = builder:ID()
	end
	if self.working[bid] == nil then return false end
	if #self.working[bid] == 0 then
		self.working[bid] = nil
		return false
	end
	EchoDebug("releasing " .. #self.working[bid] .. " from " .. bid)
	while #self.working[bid] > 0 do
		local asstbehaviour = table.remove(self.working[bid])
		if dead then asstbehaviour:Assign(nil) end
		table.insert(self.free, asstbehaviour)
		if self.ai.IDByName[asstbehaviour.id] ~= nil then
			if self.ai.IDByName[asstbehaviour.id] <= self.ai.nonAssistantsPerName then
				self.ai.nonAssistant[asstbehaviour.id] = true
			end
		end
		-- self.ai:UnitIdle(asstbehaviour.unit:Internal())
		EchoDebug(asstbehaviour.name .. " released to available assistants")
	end
	self.working[bid] = nil
	self.totalAssignments = self.totalAssignments - 1
	EchoDebug("demagnetizing " .. bid)
	for i = #self.magnets, 1, -1 do
		local magnet = self.magnets[i]
		if magnet.bid == bid then
			EchoDebug("removing a magnet")
			table.remove(self.magnets, i)
		end
	end
	-- EchoDebug("resetting magnets...")
	self:DoMagnets()
	-- EchoDebug("magnets reset")
	return true
end

function AssistHandler:IsFree(asstbehaviour)
	for i, ab in pairs(self.free) do
		if ab == asstbehaviour then return true end
	end
	return false
end

function AssistHandler:AddFree(asstbehaviour)
	if not self:IsFree(asstbehaviour) then
		table.insert(self.free, asstbehaviour)
		EchoDebug(asstbehaviour.name .. " added to available assistants")
	end
	if self.lastPullPosition then
		asstbehaviour:SetFallback(self.lastPullPosition)
	end
	self:DoMagnets()
end

function AssistHandler:RemoveFree(asstbehaviour)
	for i, ab in pairs(self.free) do
		if ab == asstbehaviour then
			table.remove(self.free, i)
			EchoDebug(asstbehaviour.name .. " removed from available assistants")
			return true
		end
	end
	return false
end

function AssistHandler:RemoveWorking(asstbehaviour)
	if asstbehaviour.target == nil then return false end
	local targetID = asstbehaviour.target
	for bid, workers in pairs(self.working) do
		if bid == targetID then
			for i, ab in pairs(workers) do
				if ab == asstbehaviour then
					table.remove(workers, i)
					if #workers == 0 then
						self.working[bid] = nil
						self.totalAssignments = self.totalAssignments - 1
					end
					EchoDebug(asstbehaviour.name .. " removed from working assistants")
					return true
				end
			end
		end
	end
	return false
end

function AssistHandler:AssignIDByName(asstbehaviour)
	-- game:SendToConsole("assisthandler:assignidbyname", ai, ai.id, self.ai, self.ai.id)
	local uname = asstbehaviour.name
	if self.IDByNameTaken[uname] == nil then
		asstbehaviour.IDByName = 1
		self.ai.IDByName[asstbehaviour.id] = 1
		self.IDByNameTaken[uname] = {}
		self.IDByNameTaken[uname][1] = asstbehaviour.id
	else
		if asstbehaviour.IDByName ~= nil then
			self.IDByNameTaken[uname][asstbehaviour.IDByName] = nil
		end
		local id = 1
		while id <= self.ai.nameCount[uname] do
			id = id + 1
			if not self.IDByNameTaken[uname][id] then break end
		end
		asstbehaviour.IDByName = id
		self.ai.IDByName[asstbehaviour.id] = id
		self.IDByNameTaken[uname][id] = asstbehaviour.id
	end
	if self.ai.IDByName[asstbehaviour.id] > self.ai.nonAssistantsPerName then
		self.ai.nonAssistant[asstbehaviour.id] = nil
	else
		self.ai.nonAssistant[asstbehaviour.id] = true
	end
	if asstbehaviour.active then
		if asstbehaviour:DoIAssist() then
			self:AddFree(asstbehaviour)
		end
	end
end

function AssistHandler:RemoveAssistant(asstbehaviour)
	self:RemoveWorking(asstbehaviour)
	self:RemoveFree(asstbehaviour)
	local uname = asstbehaviour.name
	local uid = asstbehaviour.id
	-- game:SendToConsole("assistant " .. uname .. " died")
	if self.IDByNameTaken[uname] ~= nil then self.IDByNameTaken[uname][self.ai.IDByName[uid]] = nil end
	self.ai.IDByName[uid] = nil
end