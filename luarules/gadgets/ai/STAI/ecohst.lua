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
	self.Energy = {}
	self.Metal = {}
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
		self[name].capacity = udata.capacity -- capacity is not something that fluctuates wildly
	end
	self.samples[#self.samples+1] = sample
	if not self.hasData or #self.samples == framesPerAvg then
		self:Average()
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
			self[name][property] = resources[name][property] / totalSamples
		end
		if self[name].capacity == 0 then
			self[name].full = math.huge
		else
			self[name].full = self[name].reserves / self[name].capacity
		end
	end
	self.hasData = true
	self.samples = {}
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

