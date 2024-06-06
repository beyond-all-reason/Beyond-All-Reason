EcoHST = class(Module)

function EcoHST:Name()
	return "EcoHST"
end

function EcoHST:internalName()
	return "ecohst"
end

local average = 30

function EcoHST:Init()
	self.DebugEnabled = false
	self.resourceNames = { "Energy", "Metal" }
	self.samples = {}
	self.Index = 1

	local McurrentLevel, Mstorage, Mpull, Mincome, Mexpense, Mshare, Msent, Mreceived = Spring.GetTeamResources(self.ai.id, 'metal')
	local EcurrentLevel, Estorage, Epull, Eincome, Eexpense, Eshare, Esent, Ereceived = Spring.GetTeamResources(self.ai.id, 'energy')
	for i= 1,average do
		for idx,name in pairs(self.resourceNames) do
			self.samples[i] =  {}
			self.samples[i].Metal = {}
			self.samples[i].Energy = {}
			local M = self.samples[i]['Metal']
			M.reserves = McurrentLevel
			M.capacity = Mstorage
			M.pull = Mpull
			M.income = Mincome
			M.usage = Mexpense
			M.share = Mshare
			M.sent = Msent
			M.received = Mreceived
			M.full = 1

			local E = self.samples[i]['Energy']
			E.reserves = EcurrentLevel
			E.capacity = Estorage
			E.pull = Epull
			E.income = Eincome
			E.usage = Eexpense
			E.share = Eshare
			E.sent = Esent
			E.received = Ereceived
			E.full = 1
		end
	end
	self.Energy = {reserves = 0, capacity = 1000, pull = 0 , income = 20, usage = 0, share = 0, sent = 0, received = 0,full = 1}
	self.Metal = {reserves = 0, capacity = 1000, pull = 0 , income = 20, usage = 0, share = 0, sent = 0, received = 0,full = 1}

end

function EcoHST:Update()
	if self.ai.schedulerhst.moduleTeam ~= self.ai.id or self.ai.schedulerhst.moduleUpdate ~= self:Name() then return end
	local currentSample = self.samples[self.Index]
	local currentLevel, storage, pull, income, expense, share, sent, received = Spring.GetTeamResources(self.ai.id, 'metal')
	local M = currentSample.Metal
	M.reserves = currentLevel
	M.capacity = storage
	M.pull = pull
	M.income = income
	M.usage = expense
	M.share = share
	M.sent = sent
	M.received = received

	currentLevel, storage, pull, income, expense, share, sent, received = Spring.GetTeamResources(self.ai.id, 'energy')
	local E = currentSample.Energy
	E.reserves = currentLevel
	E.capacity = storage
	E.pull = pull
	E.income = income
	E.usage = expense
	E.share = share
	E.sent = sent
	E.received = received

	local reset = false
	for i ,sample in pairs(self.samples) do
		for name, properties in pairs(sample) do
			for property, value in pairs(properties) do
				if not reset then
					self[name][property] = 0
				end
				self[name][property] = self[name][property] + value
			end
		end
		reset = true
	end
	for i,name in pairs(self.resourceNames) do
		for property, value in pairs(self[name]) do

			self[name][property] = (self[name][property] / average)
		end
		if self[name].capacity == 0 then
			self[name].full = math.huge
		else
			self[name].full = (self[name].reserves) / self[name].capacity
		end
	end
	self.Index = self.Index + 1
	if self.Index > average then
		self.Index = 1
	end
	self:DebugAll()
end

function EcoHST:DebugAll()
	if self.DebugEnabled then
-- 		for i,sample in pairs(self.samples) do
-- 			for name, properties in pairs(sample) do
-- 				for property, value in pairs(properties) do
-- 					self:EchoDebug('sample = ',i,name,  ".",property , ": " , value)
-- 				end
-- 			end
-- 		end
		for property,value in pairs(self.Metal) do
			self:EchoDebug('average Metal',property,value)
		end
		for property,value in pairs(self.Energy) do
			self:EchoDebug('average Energy',property,value)
		end

	end

end
