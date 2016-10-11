local DebugEnabled = false


local function EchoDebug(inStr)
	if DebugEnabled then
		game:SendToConsole("EconHandler: " .. inStr)
	end
end

EconHandler = class(Module)

function EconHandler:Name()
	return "EconHandler"
end

function EconHandler:internalName()
	return "econhandler"
end

local framesPerAvg = 20
local resourceNames = { "Energy", "Metal" }
local resourceCount = #resourceNames

function EconHandler:Init()
	self.hasData = false -- so that it gets data immediately
	self.samples = {}
	self.ai.Energy = {}
	self.ai.Metal = {}
	self:Update()
end

function EconHandler:Update()
	local sample = {}
	-- because resource data is stored as userdata
	for i = 1, resourceCount do
		local name = resourceNames[i]
		local udata = game:GetResourceByName(name)
		sample[name] = { income = udata.income, usage = udata.usage, reserves = udata.reserves }
		self.ai[name].capacity = udata.capacity -- capacity is not something that fluctuates wildly
	end
	self.samples[#self.samples+1] = sample
	if not self.hasData or #self.samples == framesPerAvg then self:Average() end
end

function EconHandler:Average()
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
		if self.ai[name].capacity == 0 then
			self.ai[name].full = math.inf
		else
			self.ai[name].full = self.ai[name].reserves / self.ai[name].capacity
		end
		if self.ai[name].income == 0 then
			self.ai[name].tics = math.inf
		else
			self.ai[name].tics = self.ai[name].reserves / self.ai[name].income
		end
	end
	self.hasData = true
	self.samples = {}
	self:DebugAll()
end

function EconHandler:DebugAll()
	if DebugEnabled then
		for i, name in pairs(resourceNames) do
			local resource = self.ai[name]
			for property, value in pairs(resource) do
				EchoDebug(name .. "." .. property .. ": " .. value)
			end
		end
	end
end

