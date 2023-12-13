EcoHST = class(Module)

function EcoHST:Name()
	return "EcoHST"
end

function EcoHST:internalName()
	return "ecohst"
end


local framesPerAvg = 20


function EcoHST:Init()
	self.DebugEnabled = false
	self.hasData = false -- so that it gets data immediately
	self.resourceNames = { "Energy", "Metal" }
	self.resources = {}
	self.samples = {}
	self.sample = {}


	for i ,name in pairs(self.resourceNames) do
		self.sample[name] = self.game:GetResourceByName(name)
		self.resources[name] = self.game:GetResourceByName(name)
	end
	for name, properties  in pairs(self.resources) do
		for property, value in pairs(properties) do
			self.resources[name][property] = 0
			self.sample[name][property] = 0
			--Spring.Echo(self.resources[name][property])
		end
	end
	self.Energy = {}
	self.Metal = {}
	self:Update()
end

function EcoHST:Update()
	--if self.ai.schedulerhst.moduleTeam ~= self.ai.id or self.ai.schedulerhst.moduleUpdate ~= self:Name() then return end
	-- because resource data is stored as userdata
		local currentLevel, storage, pull, income, expense, share, sent, received = Spring.GetTeamResources(self.ai.id, 'metal')
		local M = self.sample.Metal

		M.reserves = currentLevel
		M.capacity = storage
		M.pull = pull
		M.income = income
		M.usage = expense
		M.share = share
		M.sent = sent
		M.received = received

		currentLevel, storage, pull, income, expense, share, sent, received = Spring.GetTeamResources(self.ai.id, 'energy')
		self.sample.Energy.reserves = currentLevel
		self.sample.Energy.capacity = storage
		self.sample.Energy.pull = pull
		self.sample.Energy.income = income
		self.sample.Energy.usage = expense
		self.sample.Energy.share = share
		self.sample.Energy.sent = sent
		self.sample.Energy.received = received

	self.samples[#self.samples + 1] = self.sample
	if not self.hasData or #self.samples == framesPerAvg then
-- 		Spring.Echo('#self.samples',#self.samples,self.samples[#self.samples].Metal.capacity)
		self:Average()
	end

end

function EcoHST:Average()
	local resources = self.resources
	-- get sum of samples
	local samples = self.samples
	for i ,sample in pairs(samples) do
		for name, resource in pairs(sample) do
			for property, value in pairs(resource) do
				resources[name] = resources[name] or {}
				resources[name][property] = (resources[name][property]) + value
			end
		end
	end
	for name, properties  in pairs(self.resources) do
		for property, value in pairs(properties) do
			resources[name][property] = 0
		end
	end
	-- get averages
	local totalSamples = #self.samples
	for i,sample in pairs(self.samples) do
		for name, properties in pairs(sample) do
			for property, value in pairs(properties) do
				self[name][property] = resources[name][property] / totalSamples
			end
			if self[name].capacity == 0 then
				self[name].full = math.huge
			else
				self[name].full = self[name].reserves / self[name].capacity
			end
		end
	end
	self.hasData = true

	table.remove(self.samples,1)
	self:DebugAll()
end

function EcoHST:DebugAll()
	if DebugEnabled then
		for i, name in pairs(resourceNames) do
			local resource = self[name]
			for property, value in pairs(resource) do
				self:EchoDebug(name .. "." .. property .. ": " .. value)
			end
		end
	end
end

