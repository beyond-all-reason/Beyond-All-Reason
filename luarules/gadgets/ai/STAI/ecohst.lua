EcoHST = class(Module)

function EcoHST:Name()
	return "EcoHST"
end

function EcoHST:internalName()
	return "ecohst"
end


local framesPerAvg = 20
local resourceNames = { "Energy", "Metal" }
local resourceCount = #resourceNames

function EcoHST:Init()
	self.DebugEnabled = false
	self.hasData = false -- so that it gets data immediately
	self.samples = {}
	self.ai.Energy = {}
	self.ai.Metal = {}
	self:Update()
end

function EcoHST:Update()
	--if self.ai.schedulerhst.moduleTeam ~= self.ai.id or self.ai.schedulerhst.moduleUpdate ~= self:Name() then return end
	local sample = {}
	-- because resource data is stored as userdata
	for i = 1, resourceCount do
		local name = resourceNames[i]
		local udata = self.game:GetResourceByName(name)
		sample[name] = { income = udata.income, usage = udata.usage, reserves = udata.reserves }
		self.ai[name].capacity = udata.capacity -- capacity is not something that fluctuates wildly
	end
	self.samples[#self.samples+1] = sample
	if not self.hasData or #self.samples == framesPerAvg then
		self:Average()
		self.ai.realMetal = self.ai.Metal.income / self.ai.Metal.usage
		self.ai.realEnergy = self.ai.Energy.income / self.ai.Energy.usage
		self.ai.scaledMetal = self.ai.Metal.reserves * self.ai.realMetal
		self.ai.scaledEnergy = self.ai.Energy.reserves * self.ai.realEnergy
		self.extraEnergy = self.ai.Energy.income - self.ai.Energy.usage
		self.extraMetal = self.ai.Metal.income - self.ai.Metal.usage
	end
end

function EcoHST:Average()
	local resources = {}
	-- get sum of samples
	local samples = self.samples
	for i = 1, #samples do
		local sample = samples[i]
		for name, resource in pairs(sample) do
			for property, value in pairs(resource) do
				resources[name] = resources[name] or {}
				resources[name][property] = (resources[name][property] or 0) + value
			end
		end
	end
	-- get averages
	local totalSamples = #self.samples
	for name, resource in pairs(self.samples[1]) do
		for property, value in pairs(resource) do
			self.ai[name][property] = resources[name][property] / totalSamples
		end
		self.ai[name].extra = self.ai[name].income - self.ai[name].usage
		self.ai[name].effective = self.ai[name].extra / self.ai[name].income
		if self.ai[name].capacity == 0 then
			self.ai[name].full = math.huge
		else
			self.ai[name].full = self.ai[name].reserves / self.ai[name].capacity
		end
		if self.ai[name].income == 0 then
			self.ai[name].tics = math.huge
		else
			self.ai[name].tics = self.ai[name].reserves / self.ai[name].income
		end
	end
	self.hasData = true
	self.samples = {}
	self:DebugAll()
end

function EcoHST:DebugAll()
	if DebugEnabled then
		for i, name in pairs(resourceNames) do
			local resource = self.ai[name]
			for property, value in pairs(resource) do
				self:EchoDebug(name .. "." .. property .. ": " .. value)
			end
		end
	end
end

