local function formatTimestamp(ts)
	return os.date("%Y-%m-%dT%H:%M:%S", ts)
end

local MochaJSONReporter = {}

function MochaJSONReporter:new()
	local obj = {
		totalTests = 0,
		totalPasses = 0,
		totalFailures = 0,
		startTime = nil,
		endTime = nil,
		duration = nil,
		tests = {}
	}
	setmetatable(obj, self)
	self.__index = self
	return obj
end

function MochaJSONReporter:startTests()
	self.startTime = os.time()
end

function MochaJSONReporter:endTests(duration)
	self.endTime = os.time()
	self.duration = duration
end

function MochaJSONReporter:testResult(label, filePath, success, duration, errorMessage)
	local result = {
		title = label,
		fullTitle = label,
		file = filePath,
		duration = duration,
	}
	if success then
		self.totalPasses = self.totalPasses + 1
		result.err = {}
	else
		self.totalFailures = self.totalFailures + 1
		if errorMessage ~= nil then
			result.err = {
				message = errorMessage,
				stack = errorMessage
			}
		else
			result.err = {
				message = "<unknown error>",
			}
		end
	end

	self.totalTests = self.totalTests + 1
	self.tests[#(self.tests) + 1] = result
end

function MochaJSONReporter:report(filePath)
	local output = {
		["stats"] = {
			["suites"] = 1,
			["tests"] = self.totalTests,
			["passes"] = self.totalPasses,
			["pending"] = 0,
			["failures"] = self.totalFailures,
			["start"] = formatTimestamp(self.startTime),
			["end"] = formatTimestamp(self.endTime),
			["duration"] = self.duration
		},
		["tests"] = self.tests
	}

	local encoded = Json.encode(output)

	local file = io.open(filePath, "w")
	file:write(encoded)
	file:close()
end

return MochaJSONReporter
